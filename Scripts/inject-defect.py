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
    # Match specific null-check patterns, not generic !=
    # Guard patterns: if (!ptr || ptr->field.IsNull()) or if (ptr == nullptr)
    # NOT: if (ptr != nullptr) which is a valid non-null check
    if stripped.startswith("if") and ("IsNull()" in stripped or "== nullptr" in stripped):
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
    """Remove try/catch wrapper around OCCT call by commenting out the entire block.
    
    Uses a character-level state machine to:
    - Track string literals, char constants, // and /* */ comments
    - Handle nested try-catch blocks
    - Handle multiple catch blocks
    - Handle blank lines and comments between try/catch
    """
    if line_idx >= len(lines):
        return lines
    
    line = lines[line_idx]
    stripped = line.strip()
    if not stripped.startswith("try"):
        return lines
    
    # Phase 1: Find the try block (from 'try' to its matching '}')
    # We need to track: brace depth, string/char/comment context
    in_string = False
    in_char = False
    in_line_comment = False
    in_block_comment = False
    escape_next = False
    
    brace_depth = 0
    try_start = line_idx
    try_brace_started = False
    try_end_idx = -1
    
    # Start scanning from the 'try' line
    for i in range(line_idx, len(lines)):
        current_line = lines[i]
        char_idx = 0
        
        while char_idx < len(current_line):
            ch = current_line[char_idx]
            
            if in_line_comment:
                break  # Rest of line is comment
            if in_block_comment:
                if ch == '*' and char_idx + 1 < len(current_line) and current_line[char_idx + 1] == '/':
                    in_block_comment = False
                    char_idx += 2
                    continue
                char_idx += 1
                continue
            if in_string:
                if escape_next:
                    escape_next = False
                elif ch == '\\':
                    escape_next = True
                elif ch == '"':
                    in_string = False
                char_idx += 1
                continue
            if in_char:
                if escape_next:
                    escape_next = False
                elif ch == '\\':
                    escape_next = True
                elif ch == "'":
                    in_char = False
                char_idx += 1
                continue
            
            # Not in string/char/comment
            if ch == '/' and char_idx + 1 < len(current_line):
                next_ch = current_line[char_idx + 1]
                if next_ch == '/':
                    in_line_comment = True
                    char_idx += 2
                    continue
                elif next_ch == '*':
                    in_block_comment = True
                    char_idx += 2
                    continue
            if ch == '"':
                in_string = True
                char_idx += 1
                continue
            if ch == "'":
                in_char = True
                char_idx += 1
                continue
            if ch == '{':
                brace_depth += 1
                if not try_brace_started:
                    try_brace_started = True
                char_idx += 1
                continue
            if ch == '}':
                brace_depth -= 1
                if try_brace_started and brace_depth == 0:
                    # Found the end of the try block
                    try_end_idx = i
                    break
                char_idx += 1
                continue
            
            char_idx += 1
        
        if try_end_idx != -1:
            break
    
    if try_end_idx == -1:
        return lines  # Couldn't find try block end
    
    # Phase 2: Find all catch blocks after the try block
    # Reset state for phase 2
    in_string = False
    in_char = False
    in_line_comment = False
    in_block_comment = False
    escape_next = False
    
    brace_depth = 0
    catch_blocks = []  # List of (start_line, end_line)
    i = try_end_idx + 1
    
    # Skip to find first catch
    while i < len(lines):
        # Check if this line starts a catch block (at brace_depth 0)
        line_stripped = lines[i].lstrip()
        if line_stripped.startswith("catch") and brace_depth == 0:
            catch_start = i
            # Find the end of this catch block
            catch_brace_depth = 0
            catch_brace_started = False
            catch_end = -1
            
            for j in range(i, len(lines)):
                current_line = lines[j]
                char_idx = 0
                
                while char_idx < len(current_line):
                    ch = current_line[char_idx]
                    
                    if in_line_comment:
                        break
                    if in_block_comment:
                        if ch == '*' and char_idx + 1 < len(current_line) and current_line[char_idx + 1] == '/':
                            in_block_comment = False
                            char_idx += 2
                            continue
                        char_idx += 1
                        continue
                    if in_string:
                        if escape_next:
                            escape_next = False
                        elif ch == '\\':
                            escape_next = True
                        elif ch == '"':
                            in_string = False
                        char_idx += 1
                        continue
                    if in_char:
                        if escape_next:
                            escape_next = False
                        elif ch == '\\':
                            escape_next = True
                        elif ch == "'":
                            in_char = False
                        char_idx += 1
                        continue
                    
                    if ch == '/' and char_idx + 1 < len(current_line):
                        next_ch = current_line[char_idx + 1]
                        if next_ch == '/':
                            in_line_comment = True
                            char_idx += 2
                            continue
                        elif next_ch == '*':
                            in_block_comment = True
                            char_idx += 2
                            continue
                    if ch == '"':
                        in_string = True
                        char_idx += 1
                        continue
                    if ch == "'":
                        in_char = True
                        char_idx += 1
                        continue
                    if ch == '{':
                        catch_brace_depth += 1
                        if not catch_brace_started:
                            catch_brace_started = True
                        char_idx += 1
                        continue
                    if ch == '}':
                        catch_brace_depth -= 1
                        if catch_brace_started and catch_brace_depth == 0:
                            catch_end = j
                            break
                        char_idx += 1
                        continue
                    
                    char_idx += 1
                
                if catch_end != -1:
                    catch_blocks.append((catch_start, catch_end))
                    i = catch_end + 1
                    break
            else:
                # No end found for this catch block
                break
        else:
            # Not a catch line at depth 0, check for braces to track nesting
            char_idx = 0
            current_line = lines[i]
            while char_idx < len(current_line):
                ch = current_line[char_idx]
                if in_line_comment:
                    break
                if in_block_comment:
                    if ch == '*' and char_idx + 1 < len(current_line) and current_line[char_idx + 1] == '/':
                        in_block_comment = False
                        char_idx += 2
                        continue
                    char_idx += 1
                    continue
                if in_string:
                    if escape_next:
                        escape_next = False
                    elif ch == '\\':
                        escape_next = True
                    elif ch == '"':
                        in_string = False
                    char_idx += 1
                    continue
                if in_char:
                    if escape_next:
                        escape_next = False
                    elif ch == '\\':
                        escape_next = True
                    elif ch == "'":
                        in_char = False
                    char_idx += 1
                    continue
                
                if ch == '/' and char_idx + 1 < len(current_line):
                    next_ch = current_line[char_idx + 1]
                    if next_ch == '/':
                        in_line_comment = True
                        char_idx += 2
                        continue
                    elif next_ch == '*':
                        in_block_comment = True
                        char_idx += 2
                        continue
                if ch == '"':
                    in_string = True
                    char_idx += 1
                    continue
                if ch == "'":
                    in_char = True
                    char_idx += 1
                    continue
                if ch == '{':
                    brace_depth += 1
                    char_idx += 1
                    continue
                if ch == '}':
                    brace_depth -= 1
                    char_idx += 1
                    continue
                char_idx += 1
            
            i += 1
    
    # Phase 3: Comment out everything from try_start to last catch end
    if catch_blocks:
        last_catch_end = catch_blocks[-1][1]
        for j in range(try_start, last_catch_end + 1):
            if not lines[j].lstrip().startswith("//"):
                lines[j] = "// INJECTED: " + lines[j]
    
    return lines


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