#!/usr/bin/env python3
"""Read the swift-format / SwiftLint pins and refuse a tool that is not the pinned version.

    python3 Scripts/style_tool_pins.py --check swiftlint       # exit 2 on a mismatch
    python3 Scripts/style_tool_pins.py --check swift-format
    python3 Scripts/style_tool_pins.py --print swiftlint       # the pinned version
    python3 Scripts/style_tool_pins.py --self-test

The pins live in Scripts/swift-format-version.txt and Scripts/swiftlint-version.txt (line 1 the
version, line 2 the integrity value). Mirrors Scripts/format-bridge.sh's clang-format check: CI and
a developer machine run one comparison, and a mismatch is a one-line message with the fix.
"""

import argparse
import pathlib
import re
import shutil
import subprocess
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent

TOOLS = {
    'swift-format': {'file': 'swift-format-version.txt', 'cmd': ['swift-format', '--version']},
    'swiftlint': {'file': 'swiftlint-version.txt', 'cmd': ['swiftlint', 'version']},
}


def read_pin(tool, scripts=None):
    """Return (version, integrity) from the tool's pin file, comments and blanks ignored."""
    path = pathlib.Path(scripts or REPO / 'Scripts') / TOOLS[tool]['file']
    values = [ln.strip() for ln in path.read_text(encoding='utf-8').splitlines()
              if ln.strip() and not ln.strip().startswith('#')]
    if len(values) < 2:
        raise SystemExit(f'style_tool_pins: {path} needs a version line and an integrity line')
    return values[0], values[1]


def parse_version(text):
    match = re.search(r'\d+\.\d+\.\d+', text)
    return match.group(0) if match else None


def mismatch_message(tool, pinned, found):
    return (f'{tool} is {found or "not installed"} but the repo pins {pinned}. '
            f'Fix: python3 Scripts/install-style-tools.py --tool {tool} --dest ~/.local/bin '
            'and put that directory first on PATH.')


def _run(cmd):
    proc = subprocess.run(cmd, capture_output=True, text=True)
    return proc.stdout + proc.stderr


def check(tool, runner=None):
    """Return None when the resolved tool matches the pin, else the one-line refusal."""
    pinned, _ = read_pin(tool)
    if runner is None:
        if shutil.which(TOOLS[tool]['cmd'][0]) is None:
            return mismatch_message(tool, pinned, None)
        runner = _run
    found = parse_version(runner(TOOLS[tool]['cmd']))
    return None if found == pinned else mismatch_message(tool, pinned, found)


def self_test():
    print('style_tool_pins.py --self-test')
    failures = 0

    def case(name, ok):
        nonlocal failures
        print(f'  {"ok  " if ok else "FAIL"}  {name}')
        failures += 0 if ok else 1

    pinned, integrity = read_pin('swiftlint')
    case('the swiftlint pin is a version and a 64-hex sha256',
         bool(re.fullmatch(r'\d+\.\d+\.\d+', pinned) and re.fullmatch(r'[0-9a-f]{64}', integrity)))
    pinned_sf, commit = read_pin('swift-format')
    case('the swift-format pin is a version and a 40-hex commit',
         bool(re.fullmatch(r'\d+\.\d+\.\d+', pinned_sf) and re.fullmatch(r'[0-9a-f]{40}', commit)))
    case('a matching version passes',
         check('swiftlint', runner=lambda c: pinned + '\n') is None)
    case('swift-format prints a bare version and passes',
         check('swift-format', runner=lambda c: pinned_sf + '\n') is None)
    msg = check('swiftlint', runner=lambda c: '0.0.1\n')
    case('a different version is refused with the fix in one line',
         msg is not None and '\n' not in msg and 'install-style-tools.py' in msg and pinned in msg)
    case('unparseable output is refused', check('swiftlint', runner=lambda c: 'oops') is not None)
    print(f'\n{"all passed" if not failures else str(failures) + " failed"}')
    return 1 if failures else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--check', choices=sorted(TOOLS))
    ap.add_argument('--print', dest='show', choices=sorted(TOOLS))
    ap.add_argument('--self-test', action='store_true')
    args = ap.parse_args()
    if args.self_test:
        return self_test()
    if args.show:
        print(read_pin(args.show)[0])
        return 0
    if args.check:
        problem = check(args.check)
        if problem:
            print(f'REFUSED: {problem}')
            return 2
        print(f'{args.check} {read_pin(args.check)[0]} matches the pin')
        return 0
    ap.print_help()
    return 2


if __name__ == '__main__':
    sys.exit(main())
