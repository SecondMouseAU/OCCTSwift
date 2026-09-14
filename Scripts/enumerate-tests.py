#!/usr/bin/env python3
"""
enumerate-tests.py — Extract all @Test functions from OCCTSwift test targets.

Outputs JSON with: target, suite, test, line, file
"""

import json
import re
import sys
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import List, Optional

@dataclass
class TestFunction:
    target: str           # e.g., "OCCTModelingTests"
    suite: str            # @Suite name (display string or struct name)
    suite_struct: str     # The actual struct name for --filter
    test: str             # @Test function name
    line: int             # Line number in file
    file: str             # Relative path from repo root
    has_prove_comment: bool = False  # Has "Prove-the-test-fails record" comment

def find_test_targets(repo_root: Path) -> List[Path]:
    """Find all Tests/OCCT*Tests directories."""
    tests_dir = repo_root / "Tests"
    if not tests_dir.exists():
        return []
    return sorted([d for d in tests_dir.iterdir() if d.is_dir() and d.name.startswith("OCCT") and d.name.endswith("Tests")])

def extract_tests_from_file(filepath: Path, target_name: str, repo_root: Path) -> List[TestFunction]:
    """Extract @Suite and @Test functions from a Swift test file."""
    content = filepath.read_text(encoding='utf-8')
    lines = content.split('\n')
    
    tests = []
    current_suite = None
    current_suite_struct = None
    in_suite = False
    
    # Pattern for @Suite("Display Name") or @Suite struct SuiteName
    suite_pattern = re.compile(r'^\s*@Suite\s*\(\s*"([^"]+)"\s*\)|^\s*@Suite\s+(?:struct\s+)?(\w+)')
    # Pattern for @Test func testName() or @Test("display name")
    test_pattern = re.compile(r'^\s*@Test\s*\(\s*"([^"]+)"\s*\)|^\s*@Test\s+(?:func\s+)?(\w+)\s*\(')
    # Pattern for Prove-the-test-fails comment
    prove_pattern = re.compile(r'Prove.the.test.fails|prove.the.test.fails|Prove.the.test.fails.record|Prove the test fails', re.IGNORECASE)
    # Pattern for struct SuiteName { (to get the actual struct name for --filter)
    struct_pattern = re.compile(r'^\s*(?:public\s+)?struct\s+(\w+)\s*\{')
    
    for i, line in enumerate(lines):
        # Check for @Suite
        suite_match = suite_pattern.search(line)
        if suite_match:
            if suite_match.group(1):  # @Suite("Display Name")
                current_suite = suite_match.group(1)
            elif suite_match.group(2):  # @Suite struct SuiteName
                current_suite = suite_match.group(2)
                current_suite_struct = suite_match.group(2)
            in_suite = True
            continue
        
        # Check for @Test
        test_match = test_pattern.search(line)
        if test_match and in_suite:
            # Group 1: @Test("display name"), Group 2: @Test func testName()
            test_name = test_match.group(1) or test_match.group(2)
            # Look for Prove-the-test-fails comment in preceding lines
            has_prove = False
            for j in range(max(0, i-10), i):
                if prove_pattern.search(lines[j]):
                    has_prove = True
                    break
            
            tests.append(TestFunction(
                target=target_name,
                suite=current_suite or "Unknown",
                suite_struct=current_suite_struct or current_suite or "Unknown",
                test=test_name,
                line=i + 1,
                file=str(filepath.relative_to(repo_root)),
                has_prove_comment=has_prove
            ))
            continue
        
        # Check for end of suite (next @Suite or end of file or struct end)
        if in_suite and line.strip().startswith('}') and not line.strip().startswith('//'):
            # Heuristic: suite ends at a closing brace at indent level 0 or 1
            # More robust: track brace depth
            pass
    
    return tests

def main():
    repo_root = Path(__file__).parent.parent.parent
    if not (repo_root / "Tests").exists():
        # Try from current dir
        repo_root = Path.cwd()
        while repo_root != repo_root.parent and not (repo_root / "Tests").exists():
            repo_root = repo_root.parent
    
    print(f"Repo root: {repo_root}", file=sys.stderr)
    
    targets = find_test_targets(repo_root)
    print(f"Found {len(targets)} test targets", file=sys.stderr)
    
    all_tests = []
    for target_dir in targets:
        target_name = target_dir.name
        swift_files = list(target_dir.rglob("*.swift"))
        for swift_file in swift_files:
            try:
                tests = extract_tests_from_file(swift_file, target_name, repo_root)
                all_tests.extend(tests)
            except Exception as e:
                print(f"Error parsing {swift_file}: {e}", file=sys.stderr)
    
    print(f"Total @Test functions found: {len(all_tests)}", file=sys.stderr)
    
    # Output JSON
    output = [asdict(t) for t in all_tests]
    json.dump(output, sys.stdout, indent=2)

if __name__ == "__main__":
    main()