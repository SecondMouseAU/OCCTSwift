#!/usr/bin/env python3
"""Flag Swift files where comment lines outnumber code lines: a signal to look, not a fail.

Part of the code-style rollout (#876); see docs/code-style-policy-proposal-2026-08.md in the
`ecosystem` repo for the full rationale. A high ratio is sometimes legitimate (a small function
with several real caveats worth spelling out) and sometimes means a doc comment has drifted into
restating design rationale that belongs in docs/reference/ instead -- see the proposal's own
CurveAdaptors.md finding in OCCTSwift itself for what that looks like once it's had time to drift.
This script surfaces the number; it doesn't judge which case it is.

Report-only: always exits 0, same as check-docs-existence.py's own --coverage mode and for the
same reason -- failing every file above a threshold in a codebase nobody has swept yet punishes
the report instead of the problem.

Usage:
  Scripts/comment-ratio-check.py                # default threshold: 1.0
  Scripts/comment-ratio-check.py --threshold 1.5
  Scripts/comment-ratio-check.py --self-test
"""
import argparse
import glob
import sys

SRC_GLOB = 'Sources/OCCTSwift/*.swift'


def ratio(lines):
    """(comment_count, code_count) for a sequence of source lines."""
    comment = code = 0
    for line in lines:
        s = line.strip()
        if not s:
            continue
        if s.startswith('//'):
            comment += 1
        else:
            code += 1
    return comment, code


def flagged_files(paths, threshold, read=None):
    """Files at or above `threshold` (comment/code), sorted by path. `read` is
    injectable for the self-test; defaults to reading each path from disk.
    """
    read = read or (lambda p: open(p, encoding='utf-8', errors='ignore').read().splitlines())
    out = []
    for path in sorted(paths):
        comment, code = ratio(read(path))
        if code == 0:
            continue
        if comment / code >= threshold:
            out.append((path, comment, code, comment / code))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--threshold', type=float, default=1.0)
    ap.add_argument('--self-test', action='store_true')
    args = ap.parse_args()

    if args.self_test:
        return self_test()

    paths = glob.glob(SRC_GLOB)
    if not paths:
        print(f'FAIL: no files matched {SRC_GLOB}; run from the repo root', file=sys.stderr)
        return 1

    found = flagged_files(paths, args.threshold)
    if not found:
        print(f'comment-ratio-check: no files at or above {args.threshold}x comment:code '
              f'(Sources/OCCTSwift)')
    else:
        for path, comment, code, r in found:
            print(f'  {path:<55} comment={comment:<5} code={code:<5} ratio={r:.2f}')
        print(f'comment-ratio-check: {len(found)} file(s) at or above {args.threshold}x '
              f'comment:code (Sources/OCCTSwift) -- not a failure, a signal to look')
    return 0


def self_test():
    cases = [
        ('all code, no comments', ['let a = 1', 'let b = 2'], 0.5, False),
        ('all comments, no code', ['// a', '// b'], 0.0, False),  # code == 0 -> skipped, not flagged
        ('exactly at threshold (1.0)', ['// a', 'let b = 1'], 1.0, True),
        ('just under threshold', ['// a', 'let b = 1', 'let c = 2'], 1.0, False),
        ('blank lines ignored on both sides', ['// a', '', 'let b = 1', ''], 1.0, True),
    ]
    failed = 0
    for name, lines, threshold, want_flagged in cases:
        found = flagged_files(['fake.swift'], threshold, read=lambda p, ls=lines: ls)
        got_flagged = bool(found)
        ok = got_flagged == want_flagged
        failed += not ok
        print(f'  {"ok  " if ok else "MISS"} {name}: flagged={got_flagged}')
    print(f'{len(cases) - failed}/{len(cases)} cases correct')
    return 1 if failed else 0


if __name__ == '__main__':
    import os
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
    sys.exit(main())
