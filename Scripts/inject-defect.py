#!/usr/bin/env python3
"""
inject-defect.py — Apply/remove defects for prove-the-test-fails workflow.

Reads injection spec JSON: {"file": "path", "line": 123, "defect_type": "remove_guard|revert_fix|remove_try_catch", "target": "function_name"}
Applies defect by editing the file at the line, tracks original content for rollback.
Saves state to /tmp/inject-state.json for rollback.
Has restore command to revert all changes.
"""

import json
import sys
import os
import argparse
import hashlib
from pathlib import Path
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict
from enum import Enum
from datetime import datetime

REPO_ROOT = Path(__file__).parent.parent
STATE_FILE = Path("/tmp/inject-state.json")


class DefectType(Enum):
    REMOVE_GUARD = "remove_guard"
    REVERT_FIX = "revert_fix"
    REMOVE_TRY_CATCH = "remove_try_catch"


@dataclass
class InjectionSpec:
    file: str
    line: int
    defect_type: str
    target: str = ""


@dataclass
class InjectionRecord:
    spec: InjectionSpec
    applied: bool = False
    backup_content: str = ""
    backup_hash: str = ""
    applied_at: str = ""


def load_state() -> Dict[str, InjectionRecord]:
    if STATE_FILE.exists():
        with open(STATE_FILE) as f:
            data = json.load(f)
        return {k: InjectionRecord(**v) for k, v in data.items()}
    return {}


def save_state(state: Dict[str, InjectionRecord]):
    with open(STATE_FILE, "w") as f:
        json.dump({k: asdict(v) for k, v in state.items()}, f, indent=2)


def compute_hash(content: str) -> str:
    return hashlib.sha256(content.encode()).hexdigest()[:16]


def read_file_lines(filepath: Path) -> List[str]:
    with open(filepath, "r") as f:
        return f.readlines()


def write_file_lines(filepath: Path, lines: List[str]):
    with open(filepath, "w") as f:
        f.writelines(lines)


def apply_remove_guard(lines: List[str], line_idx: int) -> List[str]:
    """Comment out a null-handle guard line (e.g., if (!x || x->field.IsNull()))"""
    line = lines[line_idx]
    stripped = line.strip()
    if stripped.startswith("if") and ("IsNull()" in stripped or "== nullptr" in stripped or "!=" in stripped):
        indent = len(line) - len(line.lstrip())
        lines[line_idx] = " " * indent + "// INJECTED: " + line.lstrip()
    return lines


def apply_revert_fix(lines: List[str], line_idx: int, target: str) -> List[str]:
    """Replace a fixed pattern with the original buggy code based on target function"""
    line = lines[line_idx]
    if target and target in line:
        if "Nullify()" in line:
            lines[line_idx] = line.replace("Nullify()", "/* INJECTED: was Nullify() */")
        elif "IsNull()" in line:
            lines[line_idx] = line.replace("IsNull()", "/* INJECTED: was IsNull() */")
        elif "throw" in line:
            lines[line_idx] = line.replace("throw", "/* INJECTED: was throw */")
        elif "return" in line and "error" in line.lower():
            lines[line_idx] = line.replace("return", "/* INJECTED: was return error */")
    return lines


def apply_remove_try_catch(lines: List[str], line_idx: int) -> List[str]:
    """Remove try/catch wrapper around OCCT call using a robust state machine.

    Handles:
    - Nested try-catch blocks
    - String literals (single/double quotes, with escape sequences)
    - Character constants
    - Single-line (//) and multi-line (/* */) comments
    - Multiple catch blocks
    - Whitespace/comments between try and catch
    """
    line = lines[line_idx]
    stripped = line.strip()
    if not stripped.startswith("try"):
        return lines

    n_lines = len(lines)

    # State tracking for string/comment/char context
    in_single_line_comment = False
    in_multi_line_comment = False
    in_double_quote_string = False
    in_single_quote_char = False
    escape_next = False

    # Phase 1: Find the try block
    try_brace_level = 0  # Nesting level within the try block
    found_try_opening_brace = False
    try_block_end_line = -1

    # Phase 2: After try block, track function-level scope for catch blocks
    scope_level = 0  # Brace level relative to function scope (after try block)
    in_catch_sequence = False
    catch_lines: List[int] = []

    i = line_idx
    while i < n_lines:
        line_text = lines[i]

        # Check for catch at the START of the line (using scope_level from end of previous line)
        if try_block_end_line != -1 and i > try_block_end_line and in_catch_sequence:
            if scope_level == 0 and _line_starts_with_catch(line_text):
                catch_lines.append(i)
            else:
                # Check if this line has actual code at scope level 0 (not just whitespace/comments/braces)
                # If so, we're done with the catch sequence
                # But allow comments and blank lines to not break the sequence
                stripped_line = line_text.strip()
                if scope_level == 0 and stripped_line and not stripped_line.startswith("//") and not stripped_line.startswith("/*"):
                    # Check if line only contains braces/whitespace
                    if any(c not in ' \t\r\n{}' for c in stripped_line):
                        in_catch_sequence = False

        # Now process the line character by character
        j = 0
        line_len = len(line_text)

        while j < line_len:
            ch = line_text[j]
            next_ch = line_text[j + 1] if j + 1 < line_len else '\0'

            # Handle escape sequences inside strings/chars
            if escape_next:
                escape_next = False
                j += 1
                continue

            if ch == '\\' and (in_double_quote_string or in_single_quote_char):
                escape_next = True
                j += 1
                continue

            # Handle comment start/end
            if not in_double_quote_string and not in_single_quote_char:
                if not in_multi_line_comment and not in_single_line_comment:
                    if ch == '/' and next_ch == '/':
                        in_single_line_comment = True
                        j += 2
                        continue
                    elif ch == '/' and next_ch == '*':
                        in_multi_line_comment = True
                        j += 2
                        continue
                elif in_single_line_comment:
                    if ch == '\n':
                        in_single_line_comment = False
                    j += 1
                    continue
                elif in_multi_line_comment:
                    if ch == '*' and next_ch == '/':
                        in_multi_line_comment = False
                        j += 2
                        continue
                    j += 1
                    continue

            # Handle string/char delimiters
            if not in_single_line_comment and not in_multi_line_comment:
                if ch == '"' and not in_single_quote_char:
                    in_double_quote_string = not in_double_quote_string
                    j += 1
                    continue
                elif ch == '\'' and not in_double_quote_string:
                    in_single_quote_char = not in_single_quote_char
                    j += 1
                    continue

            # Count braces
            if not in_single_line_comment and not in_multi_line_comment and not in_double_quote_string and not in_single_quote_char:
                if try_block_end_line == -1:
                    # Phase 1: Looking for try block end
                    if ch == '{':
                        if not found_try_opening_brace:
                            found_try_opening_brace = True
                        try_brace_level += 1
                    elif ch == '}':
                        if found_try_opening_brace:
                            try_brace_level -= 1
                            if try_brace_level == 0:
                                try_block_end_line = i
                                scope_level = 0  # Reset scope level after try block
                                in_catch_sequence = True
                                # Check if this same line also contains a catch block
                                if _line_starts_with_catch(line_text):
                                    catch_lines.append(i)
                else:
                    # Phase 2: After try block, track function scope level
                    if ch == '{':
                        scope_level += 1
                    elif ch == '}':
                        if scope_level > 0:
                            scope_level -= 1
                            # If scope_level returns to 0, check if rest of line has a catch
                            if scope_level == 0:
                                # Check remainder of line for catch keyword
                                remaining = line_text[j + 1:]
                                if _line_starts_with_catch(remaining):
                                    catch_lines.append(i)

            j += 1

        # Optimization: if we've found try end and at least one catch, and we're past
        # a non-catch line at scope level 0, we can stop
        if try_block_end_line != -1 and catch_lines and i > try_block_end_line:
            if not in_catch_sequence:
                break

        i += 1

    # Only apply injection if we found a try block end AND at least one catch block
    if try_block_end_line != -1 and catch_lines:
        # Inject try block end line
        lines[try_block_end_line] = "// INJECTED: " + lines[try_block_end_line]
        # Inject catch lines (skip if same as try block end line to avoid double injection)
        for catch_line_idx in catch_lines:
            if catch_line_idx != try_block_end_line:
                lines[catch_line_idx] = "// INJECTED: " + lines[catch_line_idx]

    return lines


def _line_starts_with_catch(line: str) -> bool:
    """Check if a line starts with 'catch' keyword (not in string/comment/char)."""
    in_single_line_comment = False
    in_multi_line_comment = False
    in_double_quote_string = False
    in_single_quote_char = False
    escape_next = False

    i = 0
    n = len(line)
    while i < n:
        ch = line[i]
        next_ch = line[i + 1] if i + 1 < n else '\0'

        if escape_next:
            escape_next = False
            i += 1
            continue

        if ch == '\\' and (in_double_quote_string or in_single_quote_char):
            escape_next = True
            i += 1
            continue

        if not in_double_quote_string and not in_single_quote_char:
            if not in_multi_line_comment and not in_single_line_comment:
                if ch == '/' and next_ch == '/':
                    in_single_line_comment = True
                    i += 2
                    continue
                elif ch == '/' and next_ch == '*':
                    in_multi_line_comment = True
                    i += 2
                    continue
            elif in_single_line_comment:
                return False  # Rest of line is comment
            elif in_multi_line_comment:
                if ch == '*' and next_ch == '/':
                    in_multi_line_comment = False
                    i += 2
                    continue
                i += 1
                continue

        if not in_single_line_comment and not in_multi_line_comment:
            if ch == '"' and not in_single_quote_char:
                in_double_quote_string = not in_double_quote_string
                i += 1
                continue
            elif ch == '\'' and not in_double_quote_string:
                in_single_quote_char = not in_single_quote_char
                i += 1
                continue

        # Check for 'catch' keyword at current position (only if not in string/comment/char)
        if not in_single_line_comment and not in_multi_line_comment and not in_double_quote_string and not in_single_quote_char:
            if line[i:].startswith("catch"):
                # Verify it's a keyword (followed by space, (, {, or end)
                after = line[i + 5:] if i + 5 <= n else ""
                if not after or after[0] in ' \t\r\n({':
                    return True

        i += 1

    return False


DEFECT_HANDLERS = {
    DefectType.REMOVE_GUARD: apply_remove_guard,
    DefectType.REVERT_FIX: apply_revert_fix,
    DefectType.REMOVE_TRY_CATCH: apply_remove_try_catch,
}


def apply_injection(spec: InjectionSpec, state: Dict[str, InjectionRecord]) -> bool:
    key = f"{spec.file}:{spec.line}:{spec.defect_type}"

    if key in state and state[key].applied:
        print(f"Injection already applied: {key}")
        return False

    filepath = REPO_ROOT / spec.file
    if not filepath.exists():
        print(f"ERROR: File not found: {filepath}")
        return False

    lines = read_file_lines(filepath)
    if spec.line < 1 or spec.line > len(lines):
        print(f"ERROR: Line {spec.line} out of range (1-{len(lines)})")
        return False

    line_idx = spec.line - 1
    backup_content = "".join(lines)
    backup_hash = compute_hash(backup_content)

    try:
        defect_type = DefectType(spec.defect_type)
    except ValueError:
        print(f"ERROR: Unknown defect type: {spec.defect_type}")
        return False

    handler = DEFECT_HANDLERS[defect_type]

    if defect_type == DefectType.REVERT_FIX:
        lines = handler(lines, line_idx, spec.target)
    else:
        lines = handler(lines, line_idx)

    write_file_lines(filepath, lines)

    record = InjectionRecord(
        spec=spec,
        applied=True,
        backup_content=backup_content,
        backup_hash=backup_hash,
        applied_at=datetime.now().isoformat()
    )
    state[key] = record
    save_state(state)

    print(f"Applied injection: {key}")
    return True


def restore_injection(key: str, state: Dict[str, InjectionRecord]) -> bool:
    if key not in state:
        print(f"ERROR: No injection record for key: {key}")
        return False

    record = state[key]
    if not record.applied:
        print(f"Injection not applied: {key}")
        return False

    filepath = REPO_ROOT / record.spec.file
    if not filepath.exists():
        print(f"ERROR: File not found: {filepath}")
        return False

    current_content = filepath.read_text()
    if compute_hash(current_content) != record.backup_hash:
        print(f"WARNING: File has been modified since injection. Current hash differs from backup.")
        print(f"  Expected: {record.backup_hash}")
        print(f"  Actual:   {compute_hash(current_content)}")

    write_file_lines(filepath, list(record.backup_content))

    record.applied = False
    save_state(state)

    print(f"Restored: {key}")
    return True


def restore_all(state: Dict[str, InjectionRecord]):
    for key in list(state.keys()):
        if state[key].applied:
            restore_injection(key, state)


def list_injections(state: Dict[str, InjectionRecord]):
    if not state:
        print("No injections recorded")
        return

    print(f"{'Key':<60} {'Applied':<8} {'File:Line':<40} {'Type':<20} {'Target'}")
    print("-" * 150)
    for key, record in state.items():
        status = "YES" if record.applied else "NO"
        file_line = f"{record.spec.file}:{record.spec.line}"
        print(f"{key:<60} {status:<8} {file_line:<40} {record.spec.defect_type:<20} {record.spec.target}")


def load_spec_from_file(spec_file: Path) -> List[InjectionSpec]:
    with open(spec_file) as f:
        data = json.load(f)

    specs = []
    for item in data:
        specs.append(InjectionSpec(**item))
    return specs


def main():
    parser = argparse.ArgumentParser(description="Inject/remove defects for prove-the-test-fails")
    subparsers = parser.add_subparsers(dest="command", required=True)

    apply_parser = subparsers.add_parser("apply", help="Apply injection(s)")
    apply_parser.add_argument("--file", help="Source file path (relative to repo root)")
    apply_parser.add_argument("--line", type=int, help="Line number (1-indexed)")
    apply_parser.add_argument("--type", choices=[t.value for t in DefectType], help="Defect type")
    apply_parser.add_argument("--target", default="", help="Target function/pattern name")
    apply_parser.add_argument("--spec-file", help="JSON file with array of injection specs")

    restore_parser = subparsers.add_parser("restore", help="Restore injection(s)")
    restore_parser.add_argument("--key", help="Specific injection key to restore")
    restore_parser.add_argument("--all", action="store_true", help="Restore all applied injections")

    list_parser = subparsers.add_parser("list", help="List all injections")

    args = parser.parse_args()

    state = load_state()

    if args.command == "apply":
        if args.spec_file:
            specs = load_spec_from_file(Path(args.spec_file))
            for spec in specs:
                apply_injection(spec, state)
        elif args.file and args.line and args.type:
            spec = InjectionSpec(
                file=args.file,
                line=args.line,
                defect_type=args.type,
                target=args.target
            )
            apply_injection(spec, state)
        else:
            print("ERROR: Either --spec-file or (--file, --line, --type) required")
            sys.exit(1)

    elif args.command == "restore":
        if args.all:
            restore_all(state)
        elif args.key:
            restore_injection(args.key, state)
        else:
            print("ERROR: Either --key or --all required")
            sys.exit(1)

    elif args.command == "list":
        list_injections(state)


if __name__ == "__main__":
    main()