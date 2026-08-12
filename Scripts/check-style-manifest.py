#!/usr/bin/env python3
"""Enforce "if you touch a legacy file, you fix it" for the code-style rollout (#876).

A whole-tree zero-tolerance swift-format/SwiftLint/clang-format gate would fail every
PR against the ~11,700 pre-existing swift-format diagnostics and ~24,000-line-per-file
clang-format diff already measured across Sources/OCCTSwift and Sources/OCCTBridge
(neither has ever been run through either tool). Forcing a big-bang fix before any gate
can turn on is the outcome the ecosystem's rollout plan explicitly rejected in favor of
riding the refactor: fix what you touch, not the whole tree at once.

Two manifest files hold the exemption list, seeded once on rollout day with every file
that existed then:
  - Scripts/style-manifest-swift.txt   (Sources/OCCTSwift/*.swift)
  - Scripts/style-manifest-bridge.txt  (Sources/OCCTBridge/**/*.h, *.mm)

The rule, checked against the PR's diff relative to a base ref (`origin/main` by
default):
  1. A file NOT on either manifest must already be clean (checked separately, by the
     normal swift-format/swiftlint/clang-format gate steps -- this script doesn't
     re-run those tools, it only enforces the manifest's own bookkeeping).
  2. A file ON a manifest that appears in the diff must be REMOVED from that manifest
     in the same PR. Leaving it listed while touching it is exactly what this script
     exists to catch -- "touched a legacy file, left it on the exemption list" is a
     silent failure to comply, not a clean pass.
  3. A manifest may only shrink. Comparing HEAD's manifest against the base ref's, any
     entry present at HEAD but absent at the base is a new grandfather-listing, which
     this policy doesn't allow: everything new complies from creation.

Usage:
  Scripts/check-style-manifest.py                # compares against origin/main
  Scripts/check-style-manifest.py --base <ref>
  Scripts/check-style-manifest.py --self-test
"""
import argparse
import subprocess
import sys

MANIFESTS = [
    'Scripts/style-manifest-swift.txt',
    'Scripts/style-manifest-bridge.txt',
]


def run(args):
    return subprocess.run(args, capture_output=True, text=True, check=False)


def read_manifest_at(ref, path):
    """The manifest's contents at `ref` ('' for the working tree), as a set of paths.

    Returns an empty set for a ref/path that doesn't exist (a manifest added in this
    same PR has nothing to compare against at the base ref, which is not a violation).
    """
    if ref == '':
        try:
            with open(path, encoding='utf-8') as fh:
                lines = fh.read().splitlines()
        except FileNotFoundError:
            return set()
    else:
        result = run(['git', 'show', f'{ref}:{path}'])
        if result.returncode != 0:
            return set()
        lines = result.stdout.splitlines()
    return {line.strip() for line in lines if line.strip() and not line.strip().startswith('#')}


def diff_files(base):
    result = run(['git', 'diff', '--name-only', f'{base}...HEAD'])
    if result.returncode != 0:
        print(f'FAIL: git diff against {base} failed: {result.stderr.strip()}', file=sys.stderr)
        sys.exit(2)
    return set(result.stdout.splitlines())


def check(manifest_path, base, changed):
    """Pure logic: given one manifest's base/HEAD contents and the PR's changed-file
    set, return (touched_but_not_removed, newly_added). Both should be empty to pass.
    """
    base_entries = read_manifest_at(base, manifest_path)
    head_entries = read_manifest_at('', manifest_path)

    touched_but_not_removed = sorted(head_entries & changed)
    newly_added = sorted(head_entries - base_entries)
    return touched_but_not_removed, newly_added


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--base', default='origin/main', help='ref to diff against (default: origin/main)')
    ap.add_argument('--self-test', action='store_true')
    args = ap.parse_args()

    if args.self_test:
        return self_test()

    changed = diff_files(args.base)
    fail = False
    for manifest_path in MANIFESTS:
        touched, added = check(manifest_path, args.base, changed)
        if touched:
            fail = True
            print(f'FAIL: {manifest_path} still lists {len(touched)} file(s) this PR touches:')
            for f in touched:
                print(f'  {f}')
            print('  Bring each into compliance (swift-format/swiftlint/clang-format clean) '
                  'and remove it from the manifest in this same PR.')
        if added:
            fail = True
            print(f'FAIL: {manifest_path} grew by {len(added)} entr{"y" if len(added) == 1 else "ies"} '
                  f'not present at {args.base}:')
            for f in added:
                print(f'  {f}')
            print('  New files comply from creation; they do not get grandfathered onto the manifest.')

    if not fail:
        print(f'check-style-manifest: clean against {args.base}')
    return 1 if fail else 0


def self_test():
    """Exercise check() against synthetic manifest snapshots, no real git repo needed."""
    import unittest.mock as mock

    cases = [
        ('untouched legacy file, left alone',
         {'A.swift', 'B.swift'}, {'A.swift', 'B.swift'}, set(),
         [], []),
        ('legacy file touched and removed from the manifest (the compliant fix)',
         {'A.swift', 'B.swift'}, {'B.swift'}, {'A.swift'},
         [], []),
        ('legacy file touched, left on the manifest (the violation this script exists for)',
         {'A.swift', 'B.swift'}, {'A.swift', 'B.swift'}, {'A.swift'},
         ['A.swift'], []),
        ('new file grandfathered onto the manifest (not allowed)',
         {'A.swift'}, {'A.swift', 'C.swift'}, set(),
         [], ['C.swift']),
        ('both violations at once',
         {'A.swift', 'B.swift'}, {'A.swift', 'B.swift', 'C.swift'}, {'A.swift'},
         ['A.swift'], ['C.swift']),
    ]

    failed = 0
    for name, base_set, head_set, changed, want_touched, want_added in cases:
        with mock.patch.object(sys.modules[__name__], 'read_manifest_at',
                                side_effect=lambda ref, path, b=base_set, h=head_set:
                                h if ref == '' else b):
            touched, added = check('fake-manifest.txt', 'fake-base', changed)
        ok = touched == want_touched and added == want_added
        failed += not ok
        print(f'  {"ok  " if ok else "MISS"} {name}: touched={touched} added={added}')

    print(f'{len(cases) - failed}/{len(cases)} cases correct')
    return 1 if failed else 0


if __name__ == '__main__':
    import os
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
    sys.exit(main())
