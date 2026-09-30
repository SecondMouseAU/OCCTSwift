#!/usr/bin/env python3
r"""Gate: every tracked Swift file not on an exemption manifest passes `swift-format lint --strict`.

#2852. This used to be four lines of shell inline in `code-style.yml`:

    comm -23 <(find Sources/OCCTSwift -name '*.swift' | sort) \
             <(grep -v '^#' Scripts/style-manifest-swift.txt | sort) \
      | tr '\n' '\0' | xargs -0 swift-format lint --strict --configuration .swift-format

It walked one directory. Measured on `main`: 230 of the repo's 1,730 tracked `.swift` files, so
`Tests/` (1,459), `Scripts/` (35), `Sources/OCCTPlatform`, `Sources/OCCTTest`,
`Sources/WASICompat` and `Package.swift` were all outside the step, and the step was green.

Nothing said so. `Scripts/style-manifest-swift.txt` reads as the list of what is deliberately
unchecked, and it can only ever exempt a file the `find` already reached, so answering "is this
file linted?" meant reading the workflow. That is this repo's own recurring failure: a detector
reporting all clear over a population nobody stated. #2839 is what it costs in practice, a new
target (`Sources/OCCTPlatform`, every platform conditional in the package) landing unlinted for no
reason anybody chose.

## What it does instead

The population is `git ls-files '*.swift'`, the whole tracked tree, minus every entry on the
exemption manifests. A new directory, a new target or a new top-level file is in it from creation,
with nothing to remember to widen.

## The assertions it makes about its own view

`okf/policies/static-gates.md`: a `--self-test` proves the detector catches the failure modes its
author thought of, and cannot prove it looked at the real input at all. So the real run also
asserts:

  - **Accounting.** `selected + listed == tracked`, exactly, as sets. A filter that narrows the
    population back to one directory cannot pass this, which is the regression this gate is named
    for. It is an agreement between two independently derived sets rather than a floor on a count,
    so the manifests shrinking to zero (the outcome the rollout is working toward) moves both
    sides together instead of tripping it.
  - **No stale entry.** A manifest entry naming a path `git ls-files` does not return is reported.
    A renamed or deleted file left on the list exempts nothing and hides that its rule was never
    applied, and the manifest is the only place the repo states what is unchecked.
  - **A canary.** Every real invocation lints one generated file holding a violation
    `swift-format` cannot miss. If the canary comes back clean the tool ran and reported nothing,
    which is indistinguishable from a clean tree, so the run aborts (exit 2) instead of passing.
    `check-doc-snippets.py` carries the same device for the same reason, and it caught a second
    bug within the hour of being added.

## What it is not

It does not fix anything, and there is deliberately no `--fix`. `Scripts/format-bridge.sh`'s
header states the reason and it has not changed: `swift-format lint --strict` reports findings
that are not mechanically fixable (`BeginDocumentationCommentWithOneLineSummary` wants a sentence
rewritten, not a line rewrapped), so a command called "format" that silently left those behind
would be worse than none. Run `swift-format format -i --configuration .swift-format <file>` by
hand, re-lint, and expect to edit prose afterwards.

It is **not** in `ci.yml`'s `gate-scripts` and is not counted among that job's gates and censuses:
it shells out to `swift-format`, which that job (pure Python, ubuntu, no toolchain) does not have.
It runs in `code-style.yml`, which installs it, alongside the SwiftLint and clang-format steps.

## Usage

    python3 Scripts/check-swift-format.py                      # lint; exit 1 on a violation
    python3 Scripts/check-swift-format.py --list               # the population and the accounting
    python3 Scripts/check-swift-format.py --require-swift-format   # CI: a missing tool is exit 2
    python3 Scripts/check-swift-format.py --self-test
"""
from __future__ import annotations

import argparse
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

REPO = pathlib.Path(__file__).resolve().parent.parent
CONFIG = REPO / '.swift-format'

MANIFESTS = (
    'Scripts/style-manifest-swift.txt',
    'Scripts/style-manifest-swift-wave2.txt',
)

# `xargs` in the old step split the population into several `swift-format` runs on argv length.
# This does the same explicitly, because one run over 1,700 paths is not portable and the number
# where it stops working is not knowable from here.
BATCH = 200

# A violation of a rule this repo enables, in a form no formatter run could leave behind: a
# semicolon-terminated statement (DoNotUseSemicolons) inside a badly indented body (Indentation).
CANARY = 'struct __SwiftFormatCanary {\n  static func go() {\n      let x = 1;\n_ = x\n }\n}\n'

DIAG = re.compile(r'^(?P<path>.+?):(?P<line>\d+):(?P<col>\d+): (?P<sev>warning|error): (?P<msg>.*)$')


class BlindRun(Exception):
    """The canary came back clean, so swift-format reported nothing and the verdict means nothing."""


# --- population ---------------------------------------------------------------------------------


def tracked_swift(repo=None):
    """Every tracked `.swift` path, repo-relative, sorted."""
    repo = repo or REPO
    result = subprocess.run(['git', 'ls-files', '-z', '*.swift'], cwd=str(repo),
                            capture_output=True, text=True, check=True)
    return sorted(p for p in result.stdout.split('\0') if p)


def read_manifest(path, repo=None):
    """One manifest's entries, comments and blank lines dropped."""
    repo = repo or REPO
    try:
        text = (repo / path).read_text(encoding='utf-8')
    except FileNotFoundError:
        return set()
    return {ln.strip() for ln in text.splitlines()
            if ln.strip() and not ln.strip().startswith('#')}


def listed(repo=None):
    """Every exempt path, across all manifests."""
    out = set()
    for m in MANIFESTS:
        out |= read_manifest(m, repo)
    return out


def select(tracked, exempt):
    """The files this gate lints: tracked, minus exempt. Pure, so the self-test can drive it."""
    exempt = set(exempt)
    return [p for p in tracked if p not in exempt]


def accounting(tracked, exempt, selector=select):
    """`(selected, stale, problems)`.

    `stale` is every manifest entry `git ls-files` did not return. `problems` is the list of
    assertion failures about this run's own view, which is a refusal rather than a verdict.

    `selector` is injectable for one reason: the assertion below exists to catch a *future*
    narrowing of the population, and a self-test that cannot narrow it proves nothing about the
    assertion. The real run always passes `select`.
    """
    tracked_set = set(tracked)
    stale = sorted(p for p in exempt if p not in tracked_set)
    selected = selector(tracked, exempt)
    problems = []
    if not tracked:
        problems.append('git ls-files \'*.swift\' returned nothing. This is a Swift package; a '
                        'population of zero means the population was not read, not that the tree '
                        'has no Swift in it.')
    covered = set(selected) | (set(exempt) & tracked_set)
    if covered != tracked_set:
        missing = sorted(tracked_set - covered)
        problems.append('selected + listed does not account for every tracked .swift file. '
                        f'{len(missing)} unaccounted, first: {missing[:3]}')
    return selected, stale, problems


# --- linting ------------------------------------------------------------------------------------


def swift_format_available(tool='swift-format'):
    return shutil.which(tool) is not None


def run_lint(paths, cwd, tool='swift-format', config=None):
    """`swift-format lint --strict` over `paths`, returning the diagnostic lines."""
    config = str(config or CONFIG)
    lines = []
    for i in range(0, len(paths), BATCH):
        batch = list(paths[i:i + BATCH])
        if not batch:
            continue
        proc = subprocess.run([tool, 'lint', '--strict', '--configuration', config] + batch,
                              cwd=str(cwd), capture_output=True, text=True)
        lines += (proc.stderr + proc.stdout).splitlines()
    return [ln for ln in lines if DIAG.match(ln)]


def lint_with_canary(paths, cwd, tool='swift-format', config=None, lint=run_lint):
    """`run_lint` over `paths` plus a planted violation, which must be reported.

    Returns the diagnostics for `paths` alone. Raises `BlindRun` when the canary comes back clean:
    a `swift-format` that reports nothing looks exactly like a tree with nothing to report.
    """
    holder = pathlib.Path(tempfile.mkdtemp(prefix='swift-format-canary-'))
    try:
        canary = holder / '__SwiftFormatCanary.swift'
        canary.write_text(CANARY, encoding='utf-8')
        lines = lint(list(paths) + [str(canary)], cwd, tool=tool, config=config)
        hits = [ln for ln in lines if '__SwiftFormatCanary.swift' in ln]
        if not hits:
            raise BlindRun(
                f'the canary at {canary} holds a semicolon inside a misindented body and '
                f'{tool} reported nothing about it. The tool ran over '
                f'{len(paths)} file(s) and produced {len(lines)} diagnostic(s); a clean canary '
                'means those numbers describe nothing.')
        return [ln for ln in lines if '__SwiftFormatCanary.swift' not in ln]
    finally:
        shutil.rmtree(holder, ignore_errors=True)


# --- report -------------------------------------------------------------------------------------


def describe(tracked, exempt, selected, stale):
    out = [f'{len(tracked)} tracked .swift file(s)',
           f'  {len(selected)} linted',
           f'  {len(exempt & set(tracked))} exempt, listed on {len(MANIFESTS)} manifest(s)']
    for m in MANIFESTS:
        entries = read_manifest(m)
        out.append(f'      {len(entries):5d}  {m}')
    if stale:
        out.append(f'  {len(stale)} manifest entry/entries naming no tracked file')
    by_top = {}
    for p in selected:
        by_top[p.split('/')[0] if '/' in p else '<root>'] = \
            by_top.get(p.split('/')[0] if '/' in p else '<root>', 0) + 1
    out.append('  linted population by top-level path:')
    for k, v in sorted(by_top.items()):
        out.append(f'      {v:5d}  {k}')
    return out


def main_check(args):
    tracked = tracked_swift()
    exempt = listed()
    selected, stale, problems = accounting(tracked, exempt)

    for line in describe(tracked, exempt, selected, stale):
        print(line)

    if problems:
        print()
        for p in problems:
            print(f'REFUSED: {p}')
        return 2

    if stale:
        print()
        print('FAIL: manifest entries naming no tracked .swift file. A renamed or deleted file '
              'left on the list exempts nothing, and the manifest is where this repo states what '
              'is unchecked:')
        for p in stale:
            print(f'  {p}')
        return 1

    if args.list:
        print()
        for p in selected:
            print(p)
        return 0

    if not swift_format_available():
        msg = 'swift-format not found on PATH'
        if args.require_swift_format:
            print(f'\nREFUSED: {msg}, and --require-swift-format was passed. A green step that '
                  'linted nothing is indistinguishable from a clean tree.')
            return 2
        print(f'\nSKIPPED: {msg}; nothing was linted. CI passes --require-swift-format, which '
              'turns this into a refusal.')
        return 0

    try:
        diags = lint_with_canary(selected, REPO)
    except BlindRun as exc:
        print(f'\nREFUSED: {exc}')
        return 2

    if not diags:
        print(f'\nclean: {len(selected)} file(s) pass swift-format lint --strict')
        return 0

    files = sorted({DIAG.match(ln).group('path') for ln in diags})
    print(f'\nFAIL: {len(diags)} diagnostic(s) in {len(files)} file(s):')
    for ln in diags:
        print(f'  {ln}')
    print()
    print('Fix with `swift-format format -i --configuration .swift-format <file>` and re-lint; '
          'findings like BeginDocumentationCommentWithOneLineSummary need the prose edited, not '
          'the line rewrapped.')
    return 1


# --- self-test ----------------------------------------------------------------------------------


def _case(name, ok, detail=''):
    print(f'  {"ok  " if ok else "FAIL"}  {name}{"  " + detail if detail and not ok else ""}')
    return 1 if ok else 0


def self_test(require_swift_format=False):
    print('check-swift-format.py --self-test')
    passed = total = 0
    ran_tool_cases = True

    # 1. select() drops exactly the exempt files.
    total += 1
    tracked = ['Package.swift', 'Sources/OCCTSwift/A.swift', 'Tests/T/B.swift']
    got = select(tracked, {'Sources/OCCTSwift/A.swift'})
    passed += _case('select() drops an exempt file and keeps the rest',
                    got == ['Package.swift', 'Tests/T/B.swift'], repr(got))

    # 2. #2852's own regression, injected. A selection narrowed back to one directory must be
    #    refused, not reported clean over the files it stopped reading.
    total += 1
    tracked = ['Package.swift', 'Sources/OCCTSwift/A.swift', 'Tests/T/B.swift',
               'Scripts/C.swift']
    def _narrowed(tr, ex):
        return [p for p in tr if p.startswith('Sources/OCCTSwift/')]
    _, _, narrow_problems = accounting(tracked, set(), selector=_narrowed)
    _, _, wide_problems = accounting(tracked, set())
    passed += _case('a selection narrowed to Sources/OCCTSwift is refused, the full one is not',
                    len(narrow_problems) == 1 and '3 unaccounted' in narrow_problems[0]
                    and not wide_problems,
                    f'narrow={narrow_problems} wide={wide_problems}')

    # 3. A manifest entry naming no tracked file is reported.
    total += 1
    _, stale, problems = accounting(['Tests/T/B.swift'], {'Tests/T/Renamed.swift'})
    passed += _case('a manifest entry naming no tracked file is reported as stale',
                    stale == ['Tests/T/Renamed.swift'] and not problems, repr(stale))

    # 4. An empty population is refused, not reported clean.
    total += 1
    _, _, problems = accounting([], set())
    passed += _case('an empty population is refused rather than reported clean',
                    len(problems) == 1 and 'returned nothing' in problems[0], repr(problems))

    # 5. The canary. A lint that reports nothing aborts the run.
    total += 1
    raised = False
    try:
        lint_with_canary(['a.swift'], REPO, lint=lambda paths, cwd, tool=None, config=None: [])
    except BlindRun:
        raised = True
    passed += _case('a swift-format that reports nothing raises BlindRun', raised)

    # 6. ...and a lint that reports only about the real files, never the canary, also aborts:
    #    the canary must be caught, not merely the run be noisy.
    total += 1
    raised = False
    try:
        lint_with_canary(['a.swift'], REPO,
                         lint=lambda paths, cwd, tool=None, config=None:
                         ['a.swift:1:1: warning: [Indentation] x'])
    except BlindRun:
        raised = True
    passed += _case('diagnostics about the real files do not excuse a clean canary', raised)

    # 7 and 8 need the real tool: that the invocation and this repo's config actually bite, and
    #    that they do not report everything.
    if swift_format_available():
        holder = pathlib.Path(tempfile.mkdtemp(prefix='swift-format-selftest-'))
        try:
            bad = holder / 'Bad.swift'
            bad.write_text('struct S {\n  static func f() {\n      let x = 1;\n_ = x\n }\n}\n',
                           encoding='utf-8')
            total += 1
            diags = run_lint([str(bad)], holder)
            passed += _case('the real swift-format reports a violation in a misformatted file',
                            bool(diags), f'{len(diags)} diagnostics')

            good = holder / 'Good.swift'
            good.write_text(bad.read_text(encoding='utf-8'), encoding='utf-8')
            subprocess.run(['swift-format', 'format', '-i', '--configuration', str(CONFIG),
                            str(good)], capture_output=True, text=True)
            total += 1
            diags = run_lint([str(good)], holder)
            passed += _case('the real swift-format reports nothing about a formatted file',
                            not diags, '; '.join(diags[:3]))
        finally:
            shutil.rmtree(holder, ignore_errors=True)
    else:
        ran_tool_cases = False

    # 9. The real tree's own accounting, which is the assertion that cannot be faked by a fixture.
    total += 1
    tracked = tracked_swift()
    _, stale, problems = accounting(tracked, listed())
    passed += _case('the real tree accounts for every tracked .swift file',
                    not problems, '; '.join(problems))

    exists = 9
    print(f'\n{passed} passed, {total - passed} failed '
          f'({total} of {exists} cases ran)')
    if not ran_tool_cases:
        print()
        print('=' * 96)
        print('WEAKENED RUN: 2 of 9 cases did not run. swift-format is not on PATH, so nothing')
        print('proved that the lint invocation and .swift-format actually report a violation.')
        print('=' * 96)
        if require_swift_format:
            print('--require-swift-format was passed: this is a refusal, not a pass.')
            return 2
    return 0 if passed == total else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--self-test', action='store_true',
                    help='prove the detector is not blind')
    ap.add_argument('--list', action='store_true',
                    help='print the population and the manifest accounting, lint nothing')
    ap.add_argument('--require-swift-format', action='store_true',
                    help='a missing swift-format is exit 2, not a skip (#2098)')
    args = ap.parse_args()

    if os.path.realpath(os.getcwd()) != os.path.realpath(REPO):
        # #625. Four other scripts do this, for the same reason: every path here is repo-relative
        # and `git ls-files` is run from the repo root.
        os.chdir(REPO)

    if args.self_test:
        return self_test(require_swift_format=args.require_swift_format)
    return main_check(args)


if __name__ == '__main__':
    sys.exit(main())
