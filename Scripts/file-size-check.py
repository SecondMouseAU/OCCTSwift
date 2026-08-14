#!/usr/bin/env python3
"""Flag Swift files at or above a line-count threshold: a signal to look, not a fail.

Enforcement companion to code-structure.md's "one type, or one tight family of types, per file"
rule; see okf/policies/code-structure.md. The default threshold, 900, is the top of that policy's
own stated normal range ("most satellite repos in this org don't [have a blob problem] (their
largest files run 300-900 lines)"), so a flagged file is already outside what this org's own data
calls normal, not an arbitrary round number.

Report-only, same shape as comment-ratio-check.py: always exits 0. Splitting a file is a judgment
call code-structure.md's own 5-step method walks through, not a mechanical threshold safe to fail
a build on -- this script surfaces the number so the backlog stays visible, it doesn't gate on it.
Tracked as #906.

Usage:
  Scripts/file-size-check.py                  # default threshold 900, Sources/OCCTSwift/*.swift
  Scripts/file-size-check.py --threshold 600
  Scripts/file-size-check.py --glob 'Sources/OCCTSwift/*.swift'
  Scripts/file-size-check.py --self-test
"""
import argparse
import glob
import sys

SRC_GLOB = 'Sources/OCCTSwift/*.swift'
DEFAULT_THRESHOLD = 900


def flagged_files(paths, threshold, read=None):
    """Files at or above `threshold` lines, longest first. `read` is injectable for the
    self-test; defaults to reading each path from disk.
    """
    read = read or (lambda p: open(p, encoding='utf-8', errors='ignore').read().splitlines())
    out = []
    for path in sorted(paths):
        n = len(read(path))
        if n >= threshold:
            out.append((path, n))
    out.sort(key=lambda t: -t[1])
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--threshold', type=int, default=DEFAULT_THRESHOLD)
    ap.add_argument('--glob', default=SRC_GLOB)
    ap.add_argument('--self-test', action='store_true')
    args = ap.parse_args()

    if args.self_test:
        return self_test()

    paths = glob.glob(args.glob, recursive=True)
    if not paths:
        print(f'FAIL: no files matched {args.glob}; run from the repo root', file=sys.stderr)
        return 1

    found = flagged_files(paths, args.threshold)
    if not found:
        print(f'file-size-check: no files at or above {args.threshold} lines ({args.glob})')
    else:
        for path, n in found:
            print(f'  {path:<55} {n} lines')
        print(f'file-size-check: {len(found)} file(s) at or above {args.threshold} lines '
              f'({args.glob}) -- not a failure, a signal for a scoped code-structure pass')
    return 0


def self_test():
    cases = [
        ('under threshold', ['x'] * 5, 10, False),
        ('exactly at threshold', ['x'] * 10, 10, True),
        ('over threshold', ['x'] * 11, 10, True),
        ('empty file', [], 10, False),
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
