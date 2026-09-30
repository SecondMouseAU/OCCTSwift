#!/usr/bin/env python3
r"""Gate: type-check every fenced Swift snippet in `docs/` and in `///` doc comments.

#1683. `okf/policies/docs-current.md` asks for a runnable ```swift``` snippet on every documented
API, because context7 ranks on code-example density and a snippet is what a reader or an agent
copies. Nothing checked that any of them compile. `check-docs-existence.py` verifies that a symbol
a `docs/reference/` page documents as current still exists in `Sources/`; it never looks inside the
fences, which is how `Curve3D.arc(center:radius:startAngle:endAngle:)`, a factory that has never
existed, reached 18 call sites (#1675).

## Why this compiles instead of matching labels

#1675 holds two attempts at a regex label-matching checker and a record of how each was wrong. The
first could not read a multi-line signature and reported `Curve3D.segment(from:to:)`, a real method,
as a phantom at 39 sites. The second parsed `externalLabel internalName:` correctly, added a
subsequence rule for defaults, and still flagged two real `Wire.arc` calls: one where `...` is a
deliberate elision and one where an inline `// 500mm radius` comment sits inside the argument list.
A checker that reports real APIs as missing is worse than no checker, because the first false
positive teaches everyone to ignore it, and writing a Swift signature parser well enough to avoid
that is writing a fraction of a compiler when a compiler is already in the build. So this script
parses nothing about Swift semantics: it locates fences, hands each body to `swiftc`, and maps the
diagnostics back. Its only judgement about Swift is which *kind* of block a fence holds, below, and
that judgement is wrong only in the direction that skips a check, never in the direction that
invents a defect.

## The three kinds of fenced block

Measured over the whole tree: 8,181 ```swift``` fences, in three populations that need different
handling (`docs/CHANGELOG.md` and `docs/SEMVER.md` excluded, see `HISTORICAL` below).

1. **Signature restatements** (5,082 of them, nearly all in `docs/reference/`). A `###`
   heading for a member is followed by a fence holding the declaration verbatim:

       ```swift
       public func curvature(at u: Double) -> Double?
       ```

   These are not calls and **cannot be compiled anywhere**: a bodiless `func` is legal only in a
   protocol body. They are counted and skipped. Their defaults are already gated, by
   `check-docs-defaults.py`, which checks every default a `docs/reference/` page restates against
   the declaration it belongs to.

2. **Snippets** (3,096). Statements, the runnable examples `docs-current.md` asks for, and the
   population this script exists to check.

3. **Opt-outs** (3). A snippet that is deliberately not compilable, marked in the fence info string
   so the exemption is visible on the page rather than inferred from a list somewhere else:

       ```swift no-typecheck: `...` elides the rest of the argument list
       Wire.arc(center: ..., radius: 50, ...)
       ```

   The reason after the colon is **required**; a bare `no-typecheck` is itself reported, so an
   exemption cannot be added without saying what it is for. GitHub and Jekyll both take only the
   first word of an info string as the language, so the marker does not disturb highlighting.

A block is classified as a signature restatement when its first significant line (blank lines and
`//` comments skipped) begins with a Swift declaration modifier, declaration keyword, or `@`
attribute. That is the only classification rule, and it is deliberately inclusive: a *snippet* that
happens to open with `func` or `struct` is read as a restatement and skipped, losing a check;
a *restatement* read as a snippet would fail to compile and produce a false positive. Erring toward
the first is what keeps the failure list trustworthy. `--list` prints the census per kind so the
skipped population stays visible instead of quietly growing.

## Fragments

Many snippets open mid-flow, with a receiver the surrounding paragraph introduced:

    ```swift
    let trimmed = surf.trimmed(uMin: 0, uMax: 1, vMin: 0, vMax: 1)
    ```

`surf` is declared nowhere in the fence. Each snippet is wrapped in its own function, so an
undefined local in one cannot cascade into the next, but per-snippet wrapping does not conjure
`surf`. Those snippets are reported as **`fragment`**, a separate category from **`broken`**, and
they are not a failure. The test is mechanical and does not read the snippet: a snippet is a fragment
when **any** of its errors is `cannot find 'x' in scope` (or `cannot find type 'x' in scope`).

"Any", not "all", and the difference is 199 diagnostics. Once one name in a snippet is unresolved,
every other diagnostic in it is suspect: `if let x = surf.foo() { x.bar() }` reports the missing
`surf` and then `cannot infer contextual base` for the members reached through it, and nothing
mechanical separates that cascade from an independent defect. Counting those as `broken` would put
cascades on the failure list, and the first false positive on a failure list is what teaches everyone
to ignore it.

The cost is the deliberate blind spot: a snippet that both opens mid-flow *and* calls a phantom API
reports only the missing local. It is reported as a fragment, not as clean, so the population stays
counted and visible. Closing it means giving fragments a preamble, page by page, which is follow-up
work, not something a checker can do.

## What it runs

Two `swiftc` stages over one generated file per snippet, all in one temp directory:

1. `swiftc -parse`, no module search path, which needs no built package and separates a snippet that
   does not *parse* (an elision, a prose ellipsis, a truncated line) from one that does not
   type-check. A parse error in one file does not suppress diagnostics from the others, but a parse
   error anywhere stops the compilation before Sema, so the unparseable files are dropped before
   stage 2 rather than blinding it.
2. `swiftc -typecheck` against the built `OCCTSwift` module, with `-Xcc -fmodule-map-file` for the
   hand-written `Sources/OCCTBridge/include/module.modulemap`, since `import OCCTSwift` pulls
   `OCCTBridge` in and SwiftPM generates no module map for it.

`#expect(` is rewritten to `_ = (` before generation. 247 sites, nearly all in `///` comments,
assert with Swift Testing's macro, and the `Testing` module is not on any search path reachable
without SwiftPM's own build plan. `_ = (a == b)` type-checks the identical expression, which is the
whole content of the check; no snippet uses `#expect(throws:)` or `#require`, the two forms this
rewrite would not preserve, and `--self-test` has a case that fails if one appears.

## Where it lives, and why it is a gate

**Not in `ci.yml`'s `gate-scripts`.** That job is pure Python over the repo's own text, no OCCT and
no build, about three seconds for the lot, and this needs `OCCTSwift` built to type-check against.
It runs in `swift build + test (macOS)` instead, after the build it reuses, in about two minutes.

**The measurement** (3,105 snippets): 1,661 clean, 1,444 fragment, 0 broken, 0 unparseable. The
1,444 fragments cannot be judged until they get a preamble, which is a design question rather than
a backlog, and they do not fail the run.

**It was a census until the backlog reached zero, and the promotion is the whole point of having
measured.** It landed at 211 failures (187 broken, 24 unparseable) and gated at 0:

  - the 24 unparseable were reference pages eliding content the reader supplies, reclassified by
    #2092 (see `ELISION_FORMS`) except one real finding, a `Package.swift` manifest fragment fenced
    as `swift`, which now carries a `no-typecheck:` reason;
  - the 187 broken were fixed page by page under #2093.

A required check that is red for every PR is worse than no check
(`okf/policies/required-status-checks.md`), which is why this waited rather than gating on day one.
#1407 is the same precedent: measure the rate, then gate.

Nothing here has a measured false-positive class to discount, the way
`census-doc-occt-attribution.py` has its 41%: the compiler adjudicates, the block classifier errs
only toward skipping a check, the fragment rule errs only toward excusing one, and a canary in every
`swiftc` invocation aborts the run rather than letting a blind compiler report clean.

## The module it compiles against, and how it knows that module is current

Stage 2 needs a built `OCCTSwift.swiftmodule`, and this script does not build one. It finds whatever
`.build` holds, which is correct in CI (the build step runs immediately before it) and is a trap
locally, where branches get switched all day. A module left behind by another branch makes the
snippets look broken: an initialiser that is failable on this branch and was not on the one that
built the module reports `initializer for conditional binding must have Optional type`, on every
snippet that binds it, and the report names the snippet rather than the module. Three such false
failures were reported against correct pages on PR #2799, and `swift build` followed by an unchanged
run of this script cleared all three.

So the module is compared against its own inputs (`MODULE_INPUT_GLOBS`) before anything is compiled
against it. A module older than any input was built from different source, and the run **refuses**
rather than reporting a verdict: the type-check stage does not run, and the exit status is 2 with or
without `--require-typecheck`. That is stricter than the missing-module case, which stays a skip,
and the asymmetry is the point. A missing module is a state the person running this knows about; a
stale one is invisible, and looks exactly like a defect in the page under review.

`docs/` is deliberately not an input. Editing a snippet cannot invalidate the module, and editing a
snippet is the everyday loop here, so the refusal fires on a source edit or a branch switch and
never on a documentation change.

CI pays nothing for this: a few hundred `stat` calls, and its module is always fresh, because the
`swift build` step ahead of it recompiles the module on every run (115 to 174 s over five runs
measured 2026-09-28, `.build` cache restored each time). `--self-test`'s last stale-module case
asserts exactly that on the real tree, so a misfire shows up as a named self-test failure rather
than as a refusal on every PR.

**And "its module" has to be the module that build wrote, which is what #2867 was.** Three PRs were
blocked by this refusal, every one of them naming `Sources/OCCTSwift/ZLayerSettings.swift` and a
`.build/debug/Modules` directory, at 1925s, 3474s and 3526s. Subtract each from its own job's
checkout time and all three give the same absolute instant, 2026-09-29T06:48:12Z: one module, inside
one `actions/cache` entry, older than every job that read it. Each of those jobs *did* build and did
log `Emitting module OCCTSwift`, so nothing about the build being a no-op explains it. What explains
it is the layout: `<bin>/Modules/OCCTSwift.swiftmodule` is the llbuild path, a build on the
Swift Build backend writes the bin root instead, and a cache shared across both leaves a module at
the path the current build never rewrites. It was then the only module the search could find, so the
newest-first preference and the fall-through to another current directory had nothing to fall
through to. Reproduced here by putting a backdated bundle in `<bin>/Modules` and removing the one at
the bin root, which gives the identical message and the identical `38 passed, 1 failed`.

The remedy is upstream of this script and belongs there: `ci.yml` deletes every
`OCCTSwift.swiftmodule` under `.build` after restoring the cache and before `swift build`, so the
only module this script can find is one written during that job, after the checkout, and therefore
newer than every input by construction. That argument does not depend on which build system ran or
on what the build decided to recompile. Nothing here was weakened to accommodate it: a module older
than its inputs is still a refusal, exactly as #2816 left it, and `module_inventory_lines` now names
the module and its absolute write time on every outcome, so the next instance of this is one line in
the run that refused rather than arithmetic across three that did.

## Stage 3: running them (#2851)

Type-checking says a documented example is a legal program. It does not say the example *works*,
and the strongest available form of "does not work" is that running it takes the process down.
`docs/reference/Surface-Analysis.md`'s `extrema(to:)` example was #2840's crash reproducer,
carrying `≈ 10.0` as its expected answer, and it type-checked clean on every CI run for as long as
#2840's defect existed. This closes that, and its shape is dictated by what the costs turned out
to be. It is the **default**, off by `--no-run` rather than on by a flag CI would have to pass, so
a local run and CI cannot check different things; three runs each on one laptop measured a median
5 s for the type-check alone and 18 s with the running, of which about 6 s is the running itself:

  - **One executable, not one per snippet.** Linking a single one-statement snippet against this
    package's merged static archive takes 4.4 s measured, so 1,735 separate links is over two
    hours. Every runnable snippet becomes one top-level function in one binary instead: one
    compile, one link.
  - **The binary takes a starting index** and announces each case on stderr before running it, so
    the driver can restart it after whatever killed it. A clean corpus is one process; each defect
    costs one more. The cost is proportional to the number of failures, not to the population.
  - **A watchdog, not a per-case timeout**, for the same reason: a per-case timeout needs a
    process per case.
  - **A scratch working directory**, because a documented example that writes a STEP file writes
    it into `$PWD`, and `$PWD` in CI is the checkout.
  - **A planted case that must die.** A driver reporting every case clean is indistinguishable
    from a clean corpus, and the ways to get there are ordinary: a binary that exits early, a pump
    thread that reads nothing, a watchdog that never fires. The canary's sign is the opposite of
    the compile stages': theirs must fail to compile, this one must fail to run.

A snippet that compiles and must not be run carries its own marker, which is a different question
from `no-typecheck:` and needs a different word:

    ```swift no-run: writes a 40 MB STEP file

The reason after the colon is required, and a bare `no-run` is reported the same way a bare
`no-typecheck` is. `no-typecheck` implies `no-run`, since a fence that does not compile is never
linked into the runner.

## Usage

    python3 Scripts/check-doc-snippets.py              # extract, type-check, report; exit 1 on a failure
    python3 Scripts/check-doc-snippets.py --list       # inventory per kind, no compile
    python3 Scripts/check-doc-snippets.py --fragments  # also list the fragment sites
    python3 Scripts/check-doc-snippets.py --run        # ...and EXECUTE the ones that compile (#2851)
    python3 Scripts/check-doc-snippets.py --self-test  # prove the detector is not blind
    python3 Scripts/check-doc-snippets.py --paths docs/reference/Curve3D-Analysis.md
"""

from __future__ import annotations

import argparse
import contextlib
import io
import os
import pathlib
import re
import shutil
import platform
import subprocess
import sys
import tempfile
import threading
import time

REPO = pathlib.Path(__file__).resolve().parent.parent

DOC_GLOBS = ('docs/**/*.md',)
SOURCE_GLOBS = ('Sources/OCCTSwift/**/*.swift',)

# Documents whose snippets describe an API that no longer exists, on purpose. Excluded by default,
# with the reason here rather than in a list somewhere else, and still scanned if named explicitly
# with `--paths`. This is a short list and it stays short: "the snippet is old" is not a reason.
HISTORICAL = {
    'docs/CHANGELOG.md':
        'a release-by-release record: a v0.x entry shows the API as it was at that release, so its '
        'snippet legitimately calls a since-renamed or removed symbol, and making it compile would '
        'falsify the record (86 snippets, 16 of them non-compiling for exactly that reason)',
    'docs/SEMVER.md':
        'every entry is a before/after migration pair, and the "before" half names a symbol that no '
        'longer exists by definition',
}

# Markdown fence, with the indentation and info string captured. A closing fence carries no info
# string, which is how the two are told apart without tracking nesting.
MD_FENCE = re.compile(r'^(\s*)```(.*)$')

# A `///` doc-comment line, with the comment marker stripped.
DOC_COMMENT = re.compile(r'^(\s*)///[ \t]?(.*)$')

# Words that can open a declaration. A block whose first significant line starts with one of these
# is read as a signature restatement, not a snippet. Inclusive on purpose: see the module docstring.
DECL_OPENERS = frozenset({
    'public', 'internal', 'private', 'fileprivate', 'open', 'package',
    'extension', 'struct', 'class', 'enum', 'protocol', 'actor', 'typealias',
    'func', 'init', 'deinit', 'subscript', 'case', 'associatedtype',
    'final', 'static', 'mutating', 'nonmutating', 'consuming', 'borrowing',
    'convenience', 'override', 'required', 'dynamic', 'lazy', 'weak', 'unowned',
    'indirect', 'nonisolated', 'isolated', 'infix', 'prefix', 'postfix', 'operator',
    'import',
})

OPT_OUT = 'no-typecheck'

# #2851's marker, and it is a different question from `no-typecheck`. That one says "this fence is
# not compilable Swift". This one says "this snippet compiles, and running it is not something CI
# should do": it writes somewhere it should not, it takes minutes, it needs a file the repo does
# not ship, or it is a deliberate reproducer of a crash the kernel still has. The reason after the
# colon is required, same as the other marker and for the same reason.
#
#     ```swift no-run: writes a 40 MB STEP file
#
# `no-typecheck` implies it: a fence that does not compile is never linked into the runner.
NO_RUN = 'no-run'

# Errors that mean "this snippet opens mid-flow", not "this snippet is wrong".
MISSING_NAME = re.compile(r"cannot find (?:type )?'[^']+' in scope")

# Macro forms the `#expect(` rewrite below would not preserve. Their absence is asserted, not
# assumed, so the rewrite cannot start quietly mangling a snippet.
UNSUPPORTED_MACROS = ('#expect(throws:', '#require(')

PREAMBLE = (
    'import Foundation',
    'import simd',
    'import OCCTSwift',
    'private func __occtDocSnippet() async throws {',
)
EPILOGUE = ('}',)

# Every `swiftc` invocation carries a canary of the kind that stage checks: a file holding a defect
# the compiler cannot miss. If a canary comes back clean, that invocation dropped work and the run is
# untrustworthy, so it aborts rather than reporting a comfortable number.
#
# This is not hypothetical. The first version of this script ran `swiftc` without
# `-continue-building-after-errors`, and the driver stopped scheduling frontend jobs after the first
# batch that failed: of eight self-test fixtures, the one real defect in the first batch was caught
# and the four defects after it were all reported clean. A green run and a blind run looked
# identical. The flag is on the command line below, and the canaries are what keep it that way if a
# future toolchain changes its batching or its error recovery again.
CANARY_TYPECHECK = (
    '_ = Shape.__occtDocSnippetCanaryMemberThatCannotExist',
)
CANARY_PARSE = (
    'let x = ( ... ',
)

# Each `swiftc` gets `-wmo`, so one frontend process type-checks its whole chunk instead of the
# driver spawning a batch per handful of files. Measured on 3,200 snippets: batch mode spent over ten
# minutes in stage 1 alone on process startup, where whole-module finished it in seconds. Chunks
# below this size are not worth their own process, since each one re-imports OCCTSwift.
MIN_CHUNK = 250


class Block:
    """One fenced ```swift``` block, wherever it came from."""

    __slots__ = ('path', 'start_line', 'info', 'body', 'origin', 'kind', 'reason', 'no_run')

    def __init__(self, path, start_line, info, body, origin):
        self.path = path            # repo-relative str
        self.start_line = start_line  # 1-based line of the block's FIRST BODY line
        self.info = info            # fence info string after the language word
        self.body = body            # list of str, dedented, comment markers stripped
        self.origin = origin        # 'markdown' | 'doc-comment'
        self.kind = None            # 'declaration' | 'snippet' | 'opt-out' | 'opt-out-no-reason'
        self.reason = None          # opt-out reason
        self.no_run = None          # `no-run:` reason, '' for the marker with none, None for absent

    def __repr__(self):
        return f'<Block {self.path}:{self.start_line} {self.kind}>'


def _dedent(lines):
    """Strip the common leading whitespace, ignoring blank lines."""
    widths = [len(ln) - len(ln.lstrip()) for ln in lines if ln.strip()]
    cut = min(widths) if widths else 0
    return [ln[cut:] if len(ln) >= cut else ln.lstrip() for ln in lines]


def _info_language(info):
    """The language word of a fence info string, and the remainder."""
    stripped = info.strip()
    if not stripped:
        return '', ''
    head, _, tail = stripped.partition(' ')
    return head.lower(), tail.strip()


def extract_markdown(rel_path, text):
    """Every ```swift``` fence in a markdown file."""
    lines = text.splitlines()
    out = []
    i = 0
    while i < len(lines):
        m = MD_FENCE.match(lines[i])
        if m is None:
            i += 1
            continue
        lang, rest = _info_language(m.group(2))
        if lang != 'swift':
            # Not a Swift fence. Skip to its close so a ```swift``` inside a ```markdown``` example
            # is not harvested as real code.
            if m.group(2).strip():
                j = i + 1
                while j < len(lines):
                    m2 = MD_FENCE.match(lines[j])
                    if m2 is not None and not m2.group(2).strip():
                        break
                    j += 1
                i = j + 1
            else:
                i += 1
            continue
        start = i + 1
        j = start
        while j < len(lines):
            m2 = MD_FENCE.match(lines[j])
            if m2 is not None and not m2.group(2).strip():
                break
            j += 1
        out.append(Block(rel_path, start + 1, rest, _dedent(lines[start:j]), 'markdown'))
        i = j + 1
    return out


def extract_doc_comments(rel_path, text):
    """Every ```swift``` fence inside a `///` doc comment."""
    lines = text.splitlines()
    out = []
    i = 0
    while i < len(lines):
        m = DOC_COMMENT.match(lines[i])
        if m is None:
            i += 1
            continue
        content = m.group(2)
        cm = MD_FENCE.match(content)
        if cm is None:
            i += 1
            continue
        lang, rest = _info_language(cm.group(2))
        if lang != 'swift':
            i += 1
            continue
        start = i + 1
        body = []
        j = start
        while j < len(lines):
            m2 = DOC_COMMENT.match(lines[j])
            if m2 is None:
                break  # doc comment ended without a closing fence; take what there is
            inner = m2.group(2)
            cm2 = MD_FENCE.match(inner)
            if cm2 is not None and not cm2.group(2).strip():
                break
            body.append(inner)
            j += 1
        out.append(Block(rel_path, start + 1, rest, _dedent(body), 'doc-comment'))
        i = j + 1
    return out


def first_significant(body):
    """The first line that is neither blank nor a `//` comment."""
    for line in body:
        s = line.strip()
        if not s or s.startswith('//'):
            continue
        return s
    return ''


def classify(block):
    """Set `block.kind` (and `block.reason` for an opt-out, `block.no_run` for `no-run:`)."""
    info = block.info
    if NO_RUN in info:
        _, _, no_run_reason = info.partition(NO_RUN)
        block.no_run = no_run_reason.lstrip(': ').strip()
    if OPT_OUT in info:
        _, _, reason = info.partition(OPT_OUT)
        reason = reason.lstrip(': ').strip()
        block.reason = reason
        block.kind = 'opt-out' if reason else 'opt-out-no-reason'
        return
    head = first_significant(block.body)
    if not head:
        block.kind = 'declaration'  # nothing to compile
        return
    word = re.split(r'[\s(<:]', head, maxsplit=1)[0]
    if word in DECL_OPENERS or head.startswith('@'):
        block.kind = 'declaration'
        return
    block.kind = 'snippet'


def collect(paths=None):
    """Every block in the tree, classified.

    `HISTORICAL` documents are skipped unless `paths` names one explicitly.
    """
    blocks = []
    if paths:
        targets = [(pathlib.Path(p), pathlib.Path(p).suffix) for p in paths]
    else:
        targets = []
        for g in DOC_GLOBS:
            targets += [(p, '.md') for p in sorted(REPO.glob(g))
                        if str(p.relative_to(REPO)) not in HISTORICAL]
        for g in SOURCE_GLOBS:
            targets += [(p, '.swift') for p in sorted(REPO.glob(g))]
    for path, suffix in targets:
        path = pathlib.Path(path)
        if not path.is_absolute():
            path = REPO / path
        if not path.is_file():
            continue
        try:
            rel = str(path.resolve().relative_to(REPO))
        except ValueError:
            rel = str(path)
        text = path.read_text(encoding='utf-8', errors='replace')
        if suffix == '.md':
            blocks += extract_markdown(rel, text)
        elif suffix == '.swift':
            blocks += extract_doc_comments(rel, text)
    for b in blocks:
        classify(b)
    return blocks


def rewrite_for_compile(body):
    """The snippet body as it is handed to swiftc.

    `#expect(` becomes `_ = (`. Swift Testing's macro appears in 250 snippets, mostly in `///`
    comments, and the `Testing` module is not reachable on any search path without SwiftPM's own
    build plan. `_ = (a == b)` type-checks the identical expression.
    """
    return [line.replace('#expect(', '_ = (') for line in body]


def unsupported_macro(body):
    """The first macro form the rewrite would mangle, or None."""
    joined = '\n'.join(body)
    for form in UNSUPPORTED_MACROS:
        if form in joined:
            return form
    return None


def _write_unit(outdir, name, body):
    lines = list(PREAMBLE) + list(body) + list(EPILOGUE)
    (outdir / name).write_text('\n'.join(lines) + '\n', encoding='utf-8')


def generate(blocks, outdir):
    """Write one Swift file per snippet. Returns {generated filename: (block, body_first_line)}."""
    index = {}
    for n, block in enumerate(blocks):
        name = f's{n:05d}.swift'
        _write_unit(outdir, name, rewrite_for_compile(block.body))
        index[name] = (block, len(PREAMBLE) + 1)
    return index


def chunk(files, jobs):
    """Split into at most `jobs` contiguous chunks, each big enough to be worth a process."""
    files = list(files)
    if jobs <= 1 or len(files) <= MIN_CHUNK:
        return [files] if files else []
    n = max(1, min(jobs, (len(files) + MIN_CHUNK - 1) // MIN_CHUNK))
    size = (len(files) + n - 1) // n
    return [files[i:i + size] for i in range(0, len(files), size)]


DIAG = re.compile(r'^(?P<path>[^\s].*?):(?P<line>\d+):(?P<col>\d+): (?P<sev>error|warning): (?P<msg>.*)$')


def run_swiftc(mode, files, extra_args, cwd, wmo=True):
    """Run swiftc over `files`, returning the raw diagnostic lines.

    `-continue-building-after-errors` is load-bearing in batch mode and redundant under `-wmo`, and
    it is passed always because those two facts are properties of a toolchain version rather than of
    this script. Without it and without `-wmo`, the driver stops scheduling frontend jobs after the
    first batch that fails, so every snippet after the first defect is never compiled and reports
    clean: that is measured, not hypothetical, and `--self-test` runs its whole compile battery a
    second time with `wmo=False` so the flag's removal still fails a case.
    """
    cmd = ['xcrun', 'swiftc', mode, '-swift-version', '6', '-continue-building-after-errors']
    if wmo:
        cmd.append('-wmo')
    cmd += extra_args
    cmd += [str(f) for f in files]
    proc = subprocess.run(cmd, cwd=str(cwd), capture_output=True, text=True)
    return (proc.stderr + proc.stdout).splitlines()


def collect_errors(lines, known):
    """Every `error:` diagnostic, keyed by the generated file that produced it.

    A `note:` pointing into `Sources/OCCTSwift` is the compiler naming the real declaration, which
    is useful to read but is not a diagnostic about the snippet; a `warning:` is not a defect. Both
    are dropped, and so is any diagnostic from a file this run did not generate.
    """
    per_file = {}
    for line in lines:
        m = DIAG.match(line)
        if m is None or m.group('sev') != 'error':
            continue
        name = os.path.basename(m.group('path'))
        if name not in known:
            continue
        per_file.setdefault(name, []).append((int(m.group('line')), m.group('msg')))
    return per_file


def map_to_source(per_file, index):
    """Translate generated line numbers into the doc/source line numbers they came from."""
    out = {}
    for name, errs in per_file.items():
        if name not in index:
            continue
        block, body_first = index[name]
        out[name] = [(block.start_line + (gen_line - body_first), msg) for gen_line, msg in errs]
    return out


def parse_diags(lines, index, outdir):
    """`collect_errors` then `map_to_source`, for the snippets only. Kept for the self-test."""
    return map_to_source(collect_errors(lines, set(index)), index)


# The deployment floor `-target` needs. SwiftPM names a built module `<arch>-apple-macos.swiftmodule`
# with no version component, and `-target arm64-apple-macos` is refused outright ("Swift requires a
# minimum deployment target of macOS 10.9.0"), so the version has to come from somewhere.
#
# Read out of Package.swift rather than mirrored by hand: a hand-copy is a second statement of the
# same fact with no update path, which is the failure mode check-inventory-prose.py exists to catch
# elsewhere in this repo. The fallback is only for a Package.swift this cannot parse.
MACOS_DEPLOYMENT_FALLBACK = '12.0'


def macos_deployment():
    """The macOS deployment floor, from `Package.swift`'s `.macOS(.vN)`."""
    try:
        text = (REPO / 'Package.swift').read_text()
    except OSError:
        return MACOS_DEPLOYMENT_FALLBACK
    m = re.search(r'\.macOS\(\.v(\d+)(?:_(\d+))?\)', text)
    if not m:
        return MACOS_DEPLOYMENT_FALLBACK
    return f'{m.group(1)}.{m.group(2) or "0"}'


def module_arch(swiftmodule_path):
    """The architecture of a built `.swiftmodule`, from the bundle's contents or from the host.

    SwiftPM names a bundle's members `<arch>-apple-macos.swiftmodule`. Derived rather than hardcoded
    because a `-target` naming an architecture the built module does not carry fails with "no such
    module", which reads as a broken script rather than a mismatched flag: `macos-15` runners are
    arm64 today and were x86_64 not long ago.

    #2098: SwiftPM emits two shapes and this script meets both. A **directory** bundle holds one
    file per architecture, which is what a local build produces here. A **plain file** is the
    single-architecture form, which is what CI produces, and it carries no name to read. The only
    architecture it can be is the host's, because SwiftPM built it on this machine. Without this
    branch CI reported `no *.swiftmodule inside .../OCCTSwift.swiftmodule` and skipped the whole
    compile stage, which is the second half of what made that step a false green.
    """
    if swiftmodule_path.is_file():
        return platform.machine()
    arches = [f.stem.split('-', 1)[0] for f in sorted(swiftmodule_path.glob('*.swiftmodule'))]
    if not arches:
        return None
    # A universal build leaves several. Prefer the host's, because that is what an unqualified
    # `swiftc` invocation targets; taking the alphabetically-first would pick arm64 on an x86_64
    # host and fail with "no such module", which reads as a broken script rather than a mismatch.
    host = platform.machine()
    return host if host in arches else arches[0]


class SkipNote:
    """Why the type-check stage cannot run, and whether that is a skip or a refusal.

    `fatal` separates "there is no build" from "the build is of different source". A missing module
    is a state the person running this already knows about, and stage 1 still reports real findings,
    so it stays a skip that `--require-typecheck` turns into a failure in CI (#2098). A module older
    than the sources is invisible, and every verdict computed from it is about an API the tree no
    longer declares, so it is a refusal wherever it is found.
    """

    def __init__(self, text, fatal=False):
        self.text = text
        self.fatal = fatal

    def __str__(self):
        return self.text


# The inputs to the `OCCTSwift` module, for the staleness comparison in `toolchain_args`. The Swift
# layer and the bridge it imports, plus the manifest, which carries the language mode and the
# settings the module is built with.
#
# `docs/` is absent on purpose: a snippet edit cannot invalidate the module, and it is the edit this
# script exists to serve. Tests are absent because `swift build` does not build them.
MODULE_INPUT_GLOBS = (
    'Sources/OCCTSwift/**/*.swift',
    'Sources/OCCTBridge/**/*.h',
    'Sources/OCCTBridge/**/*.mm',
    'Sources/OCCTBridge/**/*.modulemap',
    'Package.swift',
)


def newest_input(base=None, globs=MODULE_INPUT_GLOBS):
    """`(path, mtime)` of the most recently written input to the module, or `(None, 0.0)`.

    An input whose `stat()` fails is **named on stderr** rather than passed over in silence. It
    still does not count, and that direction is deliberate: this comparison gates a refusal, and a
    broken symlink or a file deleted between the glob and the `stat` is not evidence that the module
    needs rebuilding. What it is evidence of is that this function did not see the whole population,
    and a detector that examined less than it claims has to say so out loud (#2817 review).
    """
    root = REPO if base is None else pathlib.Path(base)
    newest_path, newest = None, 0.0
    for pattern in globs:
        for f in root.glob(pattern):
            try:
                mtime = f.stat().st_mtime
            except OSError as exc:
                print(f'  note: {f} is a module input this run could not stat ({exc}), so it did '
                      'not count toward the staleness comparison', file=sys.stderr)
                continue
            if mtime > newest:
                newest_path, newest = f, mtime
    return newest_path, newest


def module_written(module_dir):
    """When the build last wrote `module_dir/OCCTSwift.swiftmodule`, or None if it is not there.

    The newest member of the bundle rather than the bundle's own mtime, because a directory's mtime
    tracks its entries being added and removed and not their contents being rewritten. Taking the
    newest of the two errs toward calling a module current, which is the safe direction: this
    comparison gates a refusal.

    A member that cannot be `stat()`ed is named on stderr and left out of the maximum, the same as an
    unreadable input above. Note which way that errs: dropping a member can only LOWER the maximum,
    so it makes the module read as older and a refusal more likely, never less (#2817 review, which
    had this direction the other way round). A bundle whose own `stat()` fails is reported as absent,
    which is the skip channel rather than this one, and is said out loud for the same reason.
    """
    path = module_dir / 'OCCTSwift.swiftmodule'
    try:
        if path.is_file():
            return path.stat().st_mtime
        if not path.is_dir():
            return None
        times = [path.stat().st_mtime]
    except OSError as exc:
        print(f'  note: {path} could not be stat()ed ({exc}), so this run treats it as no module '
              'at all rather than as a stale one', file=sys.stderr)
        return None
    for member in path.glob('*'):
        try:
            times.append(member.stat().st_mtime)
        except OSError as exc:
            print(f'  note: {member} is a module member this run could not stat ({exc}), so the '
                  'staleness comparison used the rest of the bundle', file=sys.stderr)
            continue
    return max(times)


def stale_module_reason(module_dir, base=None, globs=MODULE_INPUT_GLOBS):
    """A sentence naming the input newer than the built module, or None if the module is current.

    An mtime comparison, because it is the only signal available: nothing records which sources a
    `.swiftmodule` was built from. It errs toward refusing over a file that was rewritten with
    identical content (a checkout of the same text, a formatter), and the remedy for that is the
    same `swift build` the real case needs.
    """
    built = module_written(module_dir)
    if built is None:
        return None
    path, mtime = newest_input(base, globs)
    if path is None or mtime <= built:
        return None
    root = REPO if base is None else pathlib.Path(base)
    try:
        name = path.relative_to(root)
    except ValueError:
        name = path
    # `less than 1s` rather than `0s`: a source written half a second after the module is the
    # ordinary case on a fast disk, and `was written 0s after` reads as no difference at all, which
    # is the one thing the sentence exists to report (#2817 review).
    delta = mtime - built
    shown = 'less than 1s' if delta < 1 else f'{delta:.0f}s'
    return (f'{name} was written {shown} after the OCCTSwift.swiftmodule in '
            f'{module_dir}, so that module was built from different source; run `swift build`')


# How deep under `.build` to look for the module. `.build/out/Products/Debug` is four, so five
# leaves room for one more nesting level without another change here.
MODULE_SEARCH_DEPTH = 5


def module_dirs(base=None):
    """Directories under `.build` holding an `OCCTSwift.swiftmodule`, most recently built first.

    #2098: the layout used to be guessed, from two hardcoded candidates plus
    `swift build --show-bin-path`. In CI every guess missed while the module was on disk, so the
    census type-checked 24 of 3,105 snippets and exited 0. SwiftPM has shipped at least three
    layouts this script has met (`.build/debug`, `.build/<triple>/debug`, and
    `.build/out/Products/Debug` under the Swift Build backend, which is what a local build produces
    here today), so a fixed list is a guess that goes stale on a toolchain bump and goes stale
    silently. Searching is not a guess.

    Newest first, because a tree can hold several: a cached `.build` restored in CI over a build
    from a different toolchain leaves both, and the one this build just wrote is the one to compile
    against.
    """
    root = REPO if base is None else pathlib.Path(base)
    hits = []
    for depth in range(1, MODULE_SEARCH_DEPTH + 1):
        pattern = '/'.join(['.build'] + ['*'] * depth + ['OCCTSwift.swiftmodule'])
        hits.extend(root.glob(pattern))
    ordered = []
    for hit in sorted(hits, key=lambda h: h.stat().st_mtime, reverse=True):
        if hit.parent not in ordered:
            ordered.append(hit.parent)
    return ordered


def module_inventory_lines(base=None, globs=MODULE_INPUT_GLOBS):
    """One line per `OCCTSwift.swiftmodule` under `.build`, saying when each was written.

    #2867: the refusal named one module directory and said nothing about where that module came
    from, and the answer was that no build in that job had written it. A cache-restored `.build`
    held a module at the llbuild layout's `<bin>/Modules/OCCTSwift.swiftmodule`, the job's own build
    writes the bin root instead, and that leftover was the only module the search could find. Three
    CI jobs' refusals reported deltas of 1925s, 3474s and 3526s against their own checkout times,
    and all three reduce to the same absolute timestamp, 06:48:12Z: one artefact inside one cache
    entry, older than every job that read it. Establishing that took arithmetic across three runs,
    because the run that refused printed none of it. These lines put it in the run.

    The write time is absolute and in UTC, so two runs are comparable without subtracting their
    checkout times. Physical duplicates are folded: `.build/debug` is a symlink to the bin
    directory under both build systems shipped here, so the same module is reachable by two paths
    and reporting it twice would read as two modules.
    """
    root = REPO if base is None else pathlib.Path(base)
    _newest_path, newest = newest_input(base, globs)
    seen = {}
    for d in module_dirs(base):
        bundle = d / 'OCCTSwift.swiftmodule'
        try:
            key = os.path.realpath(bundle)
        except OSError:
            key = str(bundle)
        seen.setdefault(key, []).append(d)
    lines = []
    for _key, dirs in seen.items():
        written = module_written(dirs[0])
        when = ('unreadable' if written is None
                else time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime(written)))
        if written is None or newest == 0.0:
            gap = ''
        elif written >= newest:
            gap = f', {written - newest:.0f}s newer than the newest module input'
        else:
            gap = f', {newest - written:.0f}s OLDER than the newest module input'
        shown = dirs[0]
        try:
            shown = shown.relative_to(root)
        except ValueError:
            pass
        alias = ''
        if len(dirs) > 1:
            others = ', '.join(str(o) for o in dirs[1:])
            alias = f' (also reachable as {others})'
        lines.append(f'  module found: {shown}{alias}: written {when}{gap}')
    if len(seen) > 1:
        lines.append('  NOTE: more than one OCCTSwift.swiftmodule under .build. One of them is '
                     'what the build just wrote and the rest are leftovers from another layout or '
                     'another toolchain, which is the shape of both #2098 and #2867.')
    return lines


def toolchain_args():
    """`(swiftc args, target triple, None)` that make `import OCCTSwift` resolve, or a reason.

    On failure returns `(None, None, reason)`.
    """
    # The usual layout first, so the common case costs no subprocess: `swift build --show-bin-path`
    # re-resolves the manifest and blocks on the package lock if another build holds it.
    candidates = [REPO / '.build' / 'debug', REPO / '.build' / 'release']
    if not any((c / 'OCCTSwift.swiftmodule').exists() for c in candidates):
        try:
            proc = subprocess.run(['swift', 'build', '--show-bin-path'], cwd=str(REPO),
                                  capture_output=True, text=True, timeout=60)
            if proc.returncode == 0 and proc.stdout.strip():
                candidates.insert(0, pathlib.Path(proc.stdout.strip().splitlines()[-1].strip()))
        except (OSError, subprocess.SubprocessError):
            pass
    module_dir = None
    for c in candidates:
        if (c / 'OCCTSwift.swiftmodule').exists():
            module_dir = c
            break
    searched = []
    if module_dir is None:
        searched = module_dirs()
        if searched:
            module_dir = searched[0]
    if module_dir is None:
        return None, None, SkipNote('OCCTSwift.swiftmodule not found; run `swift build` first '
                                    f'(looked in {", ".join(str(c) for c in candidates)}, '
                                    f'then searched {REPO / ".build"} to depth '
                                    f'{MODULE_SEARCH_DEPTH})')
    # The preference above is by layout, not by age, so a stale module in `.build/debug` wins over a
    # fresh one the search would have found. Consult the search before refusing, and refuse only
    # when nothing under `.build` is current.
    stale = stale_module_reason(module_dir)
    if stale is not None:
        for other in module_dirs():
            if other == module_dir:
                continue
            if stale_module_reason(other) is None:
                module_dir, stale = other, None
                break
    if stale is not None:
        return None, None, SkipNote(stale, fatal=True)
    arch = module_arch(module_dir / 'OCCTSwift.swiftmodule')
    if arch is None:
        return None, None, SkipNote('no *.swiftmodule inside '
                                    f'{module_dir / "OCCTSwift.swiftmodule"}')
    triple = f'{arch}-apple-macos{macos_deployment()}'
    modmap = REPO / 'Sources' / 'OCCTBridge' / 'include' / 'module.modulemap'
    if not modmap.is_file():
        return None, None, SkipNote(f'missing {modmap.relative_to(REPO)}')
    try:
        sdk = subprocess.run(['xcrun', '--show-sdk-path'], capture_output=True, text=True,
                             check=True).stdout.strip()
    except (OSError, subprocess.SubprocessError) as exc:
        return None, None, SkipNote(f'xcrun --show-sdk-path failed: {exc}')
    # Both, because the module sits directly in the bin path under one layout and in a `Modules/`
    # subdirectory under another, and when it is the latter the bin path itself still carries the
    # other targets' artefacts (#2098).
    search = [module_dir, module_dir / 'Modules']
    if module_dir.name == 'Modules':
        search.append(module_dir.parent)
    args = ['-target', triple, '-sdk', sdk]
    for d in search:
        args += ['-I', str(d)]
    args += ['-Xcc', f'-fmodule-map-file={modmap}', '-Xcc', f'-I{modmap.parent}']
    return args, triple, None


# #2092. Reference pages elide content the reader is expected to supply, which does not parse and
# is not a documentation defect. A page for `isCN` has no business constructing a curve from
# scratch, and one for `modified` has no business inventing a body for the `if let`:
#
#     let curve: Curve3D = ...                     <- the value is elided
#     if let sewn = sewer.modified(face) { ... }    <- the block body is elided
#     Curve2D.bspline(poles: [...], degree: 3)     <- the collection contents are elided
#     let sub: Shape = // an edge from the box      <- the value is elided as prose
#
# All four are the `fragment` category exactly: a name the prose introduces whose value the prose
# also supplies. #2092 proposed the first form alone, having measured 22 sites by counting every
# snippet whose errors included the parse class. Measured by reclassification the first form is
# only 6 of them, and the other three forms are the rest, so the rule covers the family the tree
# actually contains rather than the one example the issue named.
#
# Every form is anchored to the line it appears on, and `placeholder_only` requires EVERY parse
# error to sit on such a line. A stray `...` mid-expression, a truncated call, a mis-fenced
# `Package.swift` manifest fragment: all still reported. That is what keeps this from widening into
# excusing real breakage, and it is what the second self-test case below pins.
ELISION_FORMS = (
    re.compile(r'=\s*\.\.\.\s*(?://.*)?$'),   # = ...
    re.compile(r'=\s*(?://|/\*)'),               # = // prose      = /* prose */
    re.compile(r'\{\s*\.\.\.\s*\}'),        # { ... }
    re.compile(r'\{\s*/\*.*?\*/\s*\}'),      # { /* prose */ }
    re.compile(r'\[\s*\.\.\.\s*\]'),        # [...]
)


def is_elision(line_text):
    """True when this line stands in for content the reader supplies (#2092)."""
    return any(form.search(line_text) for form in ELISION_FORMS)


def placeholder_only(block, errs):
    """True when every parse error sits on an elided-placeholder line (#2092)."""
    if not errs:
        return False
    for line, _msg in errs:
        i = line - block.start_line
        if not (0 <= i < len(block.body)) or not is_elision(block.body[i]):
            return False
    return True


class BlindRun(Exception):
    """A canary came back clean, so the compiler dropped work and the numbers mean nothing."""


def run_stage(mode, files, extra_args, outdir, canary_body, canaries, jobs, label, verbose,
              wmo=True):
    """Run one stage over `files`, chunked across processes, with a canary in every chunk.

    Returns {generated filename: [(generated line, message)]}. Raises `BlindRun` if any chunk's
    canary came back clean, which means that chunk's compiler dropped work.
    """
    # Nothing to compile is a real state, not an impossible one: stage 2 gets an empty list whenever
    # every snippet in the run failed to parse. Found while writing #2092's fixtures, where a
    # one-snippet run of a placeholder-ellipsis block reached `ThreadPoolExecutor(max_workers=0)`
    # and raised ValueError. No canary is owed for a stage that had no work.
    if not files:
        return {}
    chunks = chunk(files, jobs)
    if verbose:
        print(f'{label}: {len(files)} files in {len(chunks)} chunk(s)', file=sys.stderr)

    planted = {}
    runs = []
    for i, group in enumerate(chunks):
        group = list(group)
        if canaries:
            cname = f'c{mode.lstrip("-")[0]}{i:03d}.swift'
            _write_unit(outdir, cname, canary_body)
            planted[i] = cname
            group.append(outdir / cname)
        runs.append(group)

    known = {f.name for group in runs for f in group}

    if len(runs) == 1:
        outputs = [run_swiftc(mode, runs[0], extra_args, outdir, wmo=wmo)]
    else:
        import concurrent.futures
        with concurrent.futures.ThreadPoolExecutor(max_workers=len(runs)) as pool:
            outputs = list(pool.map(
                lambda g: run_swiftc(mode, g, extra_args, outdir, wmo=wmo), runs))

    merged = {}
    for i, lines in enumerate(outputs):
        errs = collect_errors(lines, known)
        if canaries and planted[i] not in errs:
            raise BlindRun(
                f'{label}: chunk {i + 1} of {len(runs)} did not report its canary, so swiftc '
                'dropped work in that chunk and this run proves nothing about its snippets')
        merged.update(errs)
    for name in planted.values():
        merged.pop(name, None)
    return merged


def check(blocks, verbose=False, keep=None, canaries=True, jobs=None, wmo=True):
    """Type-check the snippet blocks. Returns (results, note).

    `results` is a dict: name -> ('clean' | 'fragment' | 'broken' | 'unparseable', [(line, msg)]).
    Raises `BlindRun` if a planted canary was not caught.
    """
    snippets = [b for b in blocks if b.kind == 'snippet']
    if not snippets:
        return {}, None

    if jobs is None:
        jobs = max(1, (os.cpu_count() or 2) - 1)

    tc_args, triple, why_not = toolchain_args()

    outdir = pathlib.Path(keep) if keep else pathlib.Path(tempfile.mkdtemp(prefix='occt-doc-snippets-'))
    outdir.mkdir(parents=True, exist_ok=True)
    try:
        index = generate(snippets, outdir)
        snippet_files = [outdir / n for n in sorted(index)]

        # Stage 1: parse only. Needs no built package, and separates a fence that is not Swift (a
        # prose ellipsis, a truncated line) from one that is Swift but wrong. A parse error anywhere
        # stops the compilation before Sema, so these are dropped before stage 2 rather than
        # blinding it.
        # Stage 1 needs no module, only a target, and it uses the built module's so that a snippet
        # guarded by `#if arch(...)` parses the same way in both stages.
        # Stage 1 runs even when stage 2 cannot. It needs no module, and an unparseable fence is a
        # real finding on a machine with no built package.
        #
        # Kilo suggested skipping it when the toolchain is unavailable, as wasted work before the
        # early return below, and that skip was added and then REVERTED here: the "wasted" run is
        # load-bearing. It is the only path that reaches run_swiftc when there is no built package,
        # and the canary self-test stubs run_swiftc to prove a silent compiler is refused rather
        # than believed. Skipping it made that case pass locally (where a build exists, so the skip
        # never fires) and FAIL in CI (where it does), which is the precise shape of blindness the
        # canary exists to catch. The cost being avoided is one no-op swiftc batch.

        parse_args = ['-target', triple] if triple else []
        parse_raw = run_stage('-parse', snippet_files, parse_args,
                              outdir, CANARY_PARSE, canaries, jobs, 'stage 1, parse', verbose,
                              wmo=wmo)
        results = {}
        for name, errs in map_to_source(parse_raw, index).items():
            block, _ = index[name]
            kind = 'fragment' if placeholder_only(block, errs) else 'unparseable'
            results[name] = (kind, errs)

        # Stage 2: type-check whatever parses.
        rest = [f for f in snippet_files if f.name not in results]
        if why_not is not None:
            for f in rest:
                results[f.name] = ('skipped', [])
            label = 'REFUSED' if why_not.fatal else 'SKIPPED'
            return results, SkipNote(f'type-check stage {label}: {why_not}', fatal=why_not.fatal)

        tc_raw = run_stage('-typecheck', rest, tc_args, outdir, CANARY_TYPECHECK, canaries, jobs,
                           'stage 2, type-check', verbose, wmo=wmo)
        tc_errs = map_to_source(tc_raw, index)
        for f in rest:
            errs = tc_errs.get(f.name)
            if not errs:
                results[f.name] = ('clean', [])
            elif any(MISSING_NAME.search(msg) for _, msg in errs):
                results[f.name] = ('fragment', errs)
            else:
                results[f.name] = ('broken', errs)
        return results, None
    finally:
        if keep is None:
            shutil.rmtree(outdir, ignore_errors=True)


# --------------------------------------------------------------------------------------------------
# Stage 3: execution (#2851)
# --------------------------------------------------------------------------------------------------
#
# Type-checking says a documented example is a legal program. It does not say the example works,
# and the strongest available form of "does not work" is that running it takes the process down.
# That is not hypothetical: `docs/reference/Surface-Analysis.md`'s `extrema(to:)` example was
# #2840's crash reproducer, carrying `≈ 10.0` as its expected answer, and it type-checked clean on
# every CI run for as long as #2840's defect existed.
#
# THE SHAPE, and why it is not "one process per snippet". Linking one executable per snippet costs
# a link each (4.4 s measured for a one-statement snippet against this package's merged static
# archive), so the 1,735 compiling snippets would be over two hours of linking. Instead every
# runnable snippet becomes one top-level function in ONE executable, which is one compile and one
# link, and the executable takes a starting index and runs from there to the end, announcing each
# case on stderr before it begins.
#
# THE DRIVER resumes. A snippet that dies takes the process with it, which is the point: the last
# announced index is the one that died, the driver records it and restarts the binary at the next
# one. A snippet that hangs is the same case with a watchdog instead of an exit status. So one
# clean run is one process, and each failure costs one more, which makes the cost proportional to
# the number of defects rather than to the size of the population.
#
# THE CANARY is the same device stages 1 and 2 carry, with the sign this stage needs: a planted
# case that MUST die. A driver that reports every case clean looks exactly like a clean corpus,
# and the ways to get there are not exotic (a binary that exits before running anything, a pump
# thread that reads nothing, a watchdog that never fires). If the canary survives, the run is
# refused rather than reported.
#
# THE WORKING DIRECTORY is a fresh temp directory, because a documented example that writes a STEP
# file writes it into `$PWD`, and `$PWD` in CI is the checkout.

RUN_IMPORTS = ('import Foundation', 'import simd', 'import OCCTSwift')

# The planted case. `Shape.box` with a zero dimension is not it: that returns nil, which is a
# correct refusal. An unconditional trap is, and it must be a trap rather than a `throw`, because
# the driver treats a throw as a snippet's own business.
CANARY_RUN = ('fatalError("__occtDocSnippetRunCanary")',)

# Seconds without a new case announcement before the driver calls it a hang. Generous, because a
# cookbook example that meshes a solid is slow and not wrong.
DEFAULT_STALL = 60.0


class RunOutcome:
    """What running one snippet did. `kind` is 'ok', 'threw', 'crash' or 'stall'."""

    __slots__ = ('kind', 'detail')

    def __init__(self, kind, detail=''):
        self.kind = kind
        self.detail = detail

    def __repr__(self):
        return f'<{self.kind}{" " + self.detail if self.detail else ""}>'


# The archive that has to be found, by name, because finding *an* archive is not the same thing.
# The first version took any `lib*.a` beside the module and CI had exactly one, the OCCT kernel,
# with `libOCCTSwift.a` in a different directory entirely. The link then failed on every OCCTSwift
# symbol, which is the same outcome as finding nothing and cost a CI round trip to read.
PACKAGE_ARCHIVE = 'libOCCTSwift.a'


def archive_dirs(base=None, depth=MODULE_SEARCH_DEPTH):
    """Directories under `.build` holding `libOCCTSwift.a`, most recently written first.

    `module_dirs`' argument, applied to the other artefact: SwiftPM has shipped at least three
    layouts this script has met, and the archive does not have to sit where the module sits.
    """
    root = REPO if base is None else pathlib.Path(base)
    hits = []
    for d in range(1, depth + 1):
        hits.extend(root.glob('/'.join(['.build'] + ['*'] * d + [PACKAGE_ARCHIVE])))
    ordered = []
    for hit in sorted(hits, key=lambda h: h.stat().st_mtime, reverse=True):
        if hit.parent not in ordered:
            ordered.append(hit.parent)
    return ordered


def link_args(module_dir, base=None):
    """`-L`/`-l` flags that link an executable against the built package, or None.

    The directory is the one holding `libOCCTSwift.a`, checked beside the module first (it is
    usually there, and `module_dir` may be the bin root or its `Modules/` subdirectory, #2867) and
    searched for under `.build` otherwise. Every `lib*.a` in that directory is then passed, rather
    than a fixed list of names: SwiftPM merges every target and the whole OCCT kernel into one
    archive here, and a layout that splits them still answers the glob.

    Reading a cached archive is the #2867 trap on a second artefact, and the answer is the same
    one: `ci.yml` deletes both before the build, so anything found was written by that build.
    """
    for d in (module_dir, module_dir.parent):
        if (d / PACKAGE_ARCHIVE).is_file():
            return _flags_for(d)
    for d in archive_dirs(base):
        return _flags_for(d)
    return None


def _flags_for(d):
    return ['-L', str(d)] + [f'-l{a.stem[3:]}' for a in sorted(d.glob('lib*.a'))] + ['-lc++']


def runnable(blocks, results):
    """The snippets this stage runs, in order: type-checked clean and not marked `no-run`."""
    snippets = [b for b in blocks if b.kind == 'snippet']
    out = []
    for n, b in enumerate(snippets):
        kind = results.get(f's{n:05d}.swift', ('', []))[0]
        if kind == 'clean' and b.no_run is None:
            out.append(b)
    return out


def generate_runner(cases, outdir, canary=True, imports=RUN_IMPORTS):
    """Write one Swift file per case plus the dispatcher. Returns the index of the canary, or None.

    The canary is appended last so that a driver which stops early still has to reach it: a run
    that never got there reports fewer cases than exist, which the caller checks separately.
    """
    bodies = [rewrite_for_compile(b.body) for b in cases]
    canary_at = None
    if canary:
        canary_at = len(bodies)
        bodies.append(list(CANARY_RUN))
    names = []
    for n, body in enumerate(bodies):
        name = f'__occtDocSnippetCase{n:05d}'
        names.append(name)
        lines = list(imports) + [f'func {name}() async throws {{'] + list(body) + ['}']
        (outdir / f'{name}.swift').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    table = ',\n'.join(f'            {n}' for n in names)
    (outdir / 'zzmain.swift').write_text(
        'import Foundation\n'
        '\n'
        '@main\n'
        'struct __OCCTDocSnippetRunner {\n'
        '    static func say(_ s: String) {\n'
        '        FileHandle.standardError.write((s + "\\n").data(using: .utf8)!)\n'
        '    }\n'
        '\n'
        '    // A local, not a static: a global array of async closures is not Sendable under\n'
        '    // Swift 6, and the package builds in Swift 6 language mode, so the runner must too.\n'
        '    static func main() async {\n'
        '        let cases: [() async throws -> Void] = [\n'
        f'{table}\n'
        '        ]\n'
        '        let from = Int(CommandLine.arguments.dropFirst().first ?? "0") ?? 0\n'
        '        for i in from..<cases.count {\n'
        '            say("CASE \\(i)")\n'
        '            do { try await cases[i]() } catch { say("THREW \\(i)") }\n'
        '        }\n'
        '        say("DONE")\n'
        '        exit(0)\n'
        '    }\n'
        '}\n', encoding='utf-8')
    return canary_at


def build_runner(outdir, tc_args, extra_link=(), verbose=False):
    """Compile and link the runner. Returns `(exe, seconds)` or `(None, message)`.

    `-wmo` for the same reason stages 1 and 2 use it: this is thousands of files, and batch mode
    spends its whole budget on process startup. `-num-threads` is what keeps whole-module from
    serialising the code generation it then has to do, which type-checking never reached.
    """
    exe = outdir / 'occt-doc-snippet-runner'
    cmd = (['xcrun', 'swiftc', '-swift-version', '6', '-parse-as-library', '-Onone',
            '-wmo', '-num-threads', str(max(1, (os.cpu_count() or 2)))]
           + list(tc_args) + list(extra_link) + ['-o', str(exe)]
           + [str(p) for p in sorted(outdir.glob('*.swift'))])
    if verbose:
        print(f'stage 3, link: {len(list(outdir.glob("*.swift")))} files', file=sys.stderr)
    t0 = time.time()
    proc = subprocess.run(cmd, cwd=str(outdir), capture_output=True, text=True)
    secs = time.time() - t0
    if proc.returncode != 0:
        # Both: the `error:` lines name a snippet, and the tail carries the linker's own output,
        # which has no `error:` prefix at all and is where an undefined symbol appears.
        errs = [ln for ln in (proc.stderr + proc.stdout).splitlines() if ' error:' in ln]
        tail = (proc.stderr + proc.stdout)[-4000:]
        return None, '\n'.join(errs[:20]) + '\n--- last 4000 chars ---\n' + tail
    return exe, secs


def drive_runner(exe, total, cwd, stall=DEFAULT_STALL, verbose=False):
    """Run every case, resuming past whatever kills the process. Returns `{index: RunOutcome}`."""
    outcome = {}
    start = 0
    while start < total:
        proc = subprocess.Popen([str(exe), str(start)], cwd=str(cwd),
                                stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        state = {'cur': None, 'last': time.time(), 'threw': set(), 'done': False}

        def pump(stream=proc.stderr, st=state):
            for line in stream:
                line = line.strip()
                st['last'] = time.time()
                if line.startswith('CASE '):
                    st['cur'] = int(line.split()[1])
                elif line.startswith('THREW '):
                    st['threw'].add(int(line.split()[1]))
                elif line == 'DONE':
                    st['done'] = True

        pump_thread = threading.Thread(target=pump, daemon=True)
        pump_thread.start()
        stalled = False
        while proc.poll() is None:
            time.sleep(0.2)
            if time.time() - state['last'] > stall:
                stalled = True
                proc.kill()
                break
        pump_thread.join(timeout=2)
        rc = proc.wait()
        cur = state['cur']
        settled = cur if cur is not None else start
        for i in range(start, settled):
            outcome.setdefault(i, RunOutcome('threw' if i in state['threw'] else 'ok'))
        if state['done']:
            if cur is not None:
                outcome.setdefault(cur, RunOutcome('threw' if cur in state['threw'] else 'ok'))
            break
        if cur is None:
            # The process died before announcing anything, so no case can be blamed and every
            # later one is unexamined. Reported by the count, never by a verdict on a page.
            break
        outcome[cur] = RunOutcome('stall' if stalled else 'crash',
                                  'no progress for %.0fs' % stall if stalled
                                  else f'exit {rc}' if rc >= 0 else f'signal {-rc}')
        if verbose:
            print(f'stage 3: {outcome[cur].kind} at case {cur}', file=sys.stderr)
        start = cur + 1
    return outcome


def execute_stage(cases, tc_args, stall=DEFAULT_STALL, keep=None, verbose=False, canaries=True,
                  imports=RUN_IMPORTS):
    """Compile, link and run `cases`. Returns `(outcomes, seconds, note)`.

    Raises `BlindRun` when the planted canary survives, on the same argument the compile stages
    make: a driver that reports a corpus clean because it examined none of it is indistinguishable
    from one reporting a clean corpus.
    """
    # A `run` subdirectory even under --keep: the compile stages write their own generated files
    # and their canaries into the top of that directory, and this stage globs `*.swift`, so
    # sharing it puts 3,183 uncompilable fragments into the runner. Measured, once.
    outdir = (pathlib.Path(keep) / 'run') if keep else pathlib.Path(
        tempfile.mkdtemp(prefix='occt-doc-run-'))
    outdir.mkdir(parents=True, exist_ok=True)
    sandbox = outdir / 'cwd'
    sandbox.mkdir(exist_ok=True)
    try:
        canary_at = generate_runner(cases, outdir, canary=canaries, imports=imports)
        total = len(cases) + (1 if canaries else 0)
        # The compile stages only ever type-check, so `tc_args` carries `-I` and no `-L`/`-l` at
        # all. The first `-I` is the module directory `toolchain_args` settled on, and the
        # archives sit there or one level up.
        extra_link = ()
        for i, a in enumerate(tc_args):
            if a == '-I' and i + 1 < len(tc_args):
                found = link_args(pathlib.Path(tc_args[i + 1]))
                if found:
                    extra_link = found
                    break
        if tc_args and not extra_link:
            # Name what was looked for and where, per static-gates.md: #2867's refusal named a
            # directory and left "was it this build's artefact at all" to arithmetic across three
            # jobs' logs.
            searched = [d for d in (pathlib.Path(a) for i, a in enumerate(tc_args)
                                    if i and tc_args[i - 1] == '-I')]
            found = archive_dirs()
            return {}, 0.0, SkipNote(
                f'no {PACKAGE_ARCHIVE} beside the built module, so nothing can be linked '
                'against. The type-check stage needs only a .swiftmodule; this stage needs the '
                'archive too. Looked beside '
                + ', '.join(str(d) for d in searched)
                + ' and their parents, then under '
                + str(REPO / '.build') + f' to depth {MODULE_SEARCH_DEPTH}, which holds it in '
                + (', '.join(str(d) for d in found) if found else 'no directory')
                + '. Run `swift build`.',
                fatal=True)
        exe, detail = build_runner(outdir, tc_args, extra_link=extra_link, verbose=verbose)
        if exe is None:
            return {}, 0.0, SkipNote(f'the runner did not link:\n{detail}', fatal=True)
        t0 = time.time()
        outcomes = drive_runner(exe, total, sandbox, stall=stall, verbose=verbose)
        secs = time.time() - t0
        if canaries:
            got = outcomes.get(canary_at)
            if got is None or got.kind not in ('crash', 'stall'):
                raise BlindRun(
                    'the planted run canary calls fatalError and the driver reported it as '
                    f'{got.kind if got else "never reached"}. The driver ran {len(outcomes)} of '
                    f'{total} cases; a canary that survives means those numbers describe nothing.')
            outcomes.pop(canary_at, None)
        return outcomes, secs, None
    finally:
        if keep is None:
            shutil.rmtree(outdir, ignore_errors=True)


def report(blocks, results, show_fragments=False, show_declarations=False):
    """Print the census and the failures. Returns the exit status."""
    snippets = [b for b in blocks if b.kind == 'snippet']
    index_by_block = {}
    for n, b in enumerate(snippets):
        index_by_block[f's{n:05d}.swift'] = b

    counts = {'declaration': 0, 'snippet': 0, 'opt-out': 0, 'opt-out-no-reason': 0}
    for b in blocks:
        counts[b.kind] = counts.get(b.kind, 0) + 1

    print(f'{len(blocks)} ```swift``` fences in docs/ and /// comments')
    for rel, reason in sorted(HISTORICAL.items()):
        if not any(b.path == rel for b in blocks):
            print(f'  (excluded: {rel}, {reason.split(":")[0].split("(")[0].strip()})')
    print(f'  {counts["declaration"]:5d} signature restatements (not compilable anywhere, skipped)')
    print(f'  {counts["snippet"]:5d} snippets (type-checked)')
    print(f'  {counts["opt-out"]:5d} opt-outs ({OPT_OUT}, with a reason)')
    if counts['opt-out-no-reason']:
        print(f'  {counts["opt-out-no-reason"]:5d} opt-outs WITHOUT a reason (a defect)')

    by_kind = {}
    for name, (kind, errs) in results.items():
        by_kind.setdefault(kind, []).append((name, errs))

    print()
    for kind in ('clean', 'fragment', 'broken', 'unparseable', 'skipped'):
        if kind in by_kind:
            print(f'  {len(by_kind[kind]):5d} {kind}')

    status = 0

    bad_optouts = [b for b in blocks if b.kind == 'opt-out-no-reason']
    if bad_optouts:
        status = 1
        print(f'\n{len(bad_optouts)} `{OPT_OUT}` marker(s) with no reason after the colon:')
        for b in bad_optouts:
            print(f'  {b.path}:{b.start_line}')

    bad_noruns = [b for b in blocks if b.no_run == '']
    if bad_noruns:
        status = 1
        print(f'\n{len(bad_noruns)} `{NO_RUN}` marker(s) with no reason after the colon:')
        for b in bad_noruns:
            print(f'  {b.path}:{b.start_line}')

    mangled = [b for b in blocks if b.kind == 'snippet' and unsupported_macro(b.body)]
    if mangled:
        status = 1
        print(f'\n{len(mangled)} snippet(s) use a macro form the `#expect(` rewrite cannot preserve:')
        for b in mangled:
            print(f'  {b.path}:{b.start_line}  {unsupported_macro(b.body)}')

    for kind, label in (('unparseable', 'do not parse as Swift'),
                        ('broken', 'do not type-check')):
        items = by_kind.get(kind, [])
        if not items:
            continue
        status = 1
        print(f'\n{len(items)} snippet(s) {label}:')
        for name, errs in sorted(items):
            b = index_by_block[name]
            print(f'  {b.path}:{b.start_line}')
            for line, msg in errs[:4]:
                print(f'      line {line}: {msg}')
            if len(errs) > 4:
                print(f'      ... and {len(errs) - 4} more')

    frags = by_kind.get('fragment', [])
    if frags:
        print(f'\n{len(frags)} snippet(s) open mid-flow and reference a name declared in the prose')
        print('  (reported, not a failure; see the module docstring under "Fragments")')
        if show_fragments:
            for name, errs in sorted(frags):
                b = index_by_block[name]
                names = sorted({m.group(0) for _, msg in errs
                                for m in [MISSING_NAME.search(msg)] if m})
                print(f'  {b.path}:{b.start_line}  {"; ".join(names)}')

    if show_declarations:
        print('\nsignature restatements:')
        for b in blocks:
            if b.kind == 'declaration':
                print(f'  {b.path}:{b.start_line}  {first_significant(b.body)[:100]}')

    if 'skipped' in by_kind:
        print('\ntype-check stage was skipped; this run proves nothing about the snippets')

    return status


def report_run(cases, outcomes, secs):
    """Print the execution stage's result. Returns the exit status."""
    tally = {}
    for o in outcomes.values():
        tally[o.kind] = tally.get(o.kind, 0) + 1
    print()
    print(f'  stage 3, run: {len(outcomes)} of {len(cases)} case(s) executed in {secs:.0f}s')
    for kind in ('ok', 'threw', 'crash', 'stall'):
        if kind in tally:
            print(f'      {tally[kind]:5d} {kind}')

    status = 0
    if len(outcomes) < len(cases):
        # Not a verdict on any page: the driver stopped before the corpus ended, so the rest was
        # never examined, and saying nothing about them would be the false green this whole script
        # is built against.
        status = 1
        print(f'\nFAIL: {len(cases) - len(outcomes)} case(s) were never executed. The runner died '
              'before announcing\n  a case, so nothing can be said about them.')

    bad = [(i, o) for i, o in sorted(outcomes.items()) if o.kind in ('crash', 'stall')]
    if bad:
        status = 1
        print(f'\n{len(bad)} documented example(s) took the process down or hung:')
        for i, o in bad:
            b = cases[i]
            print(f'  {b.path}:{b.start_line}  ({o.kind}, {o.detail})')
        print()
        print(f'A crashing example is the strongest form of a wrong one. Fix the example, or, if '
              f'it is\n  reproducing a defect on purpose, mark the fence '
              f'```swift {NO_RUN}: <reason>.')
    return status


# --------------------------------------------------------------------------------------------------
# Self-test
# --------------------------------------------------------------------------------------------------

# Each case: (name, filename, text, expected [(start_line, kind)] in order).
EXTRACT_CASES = [
    (
        'markdown snippet and restatement are told apart',
        'a.md',
        '# T\n'
        '\n'
        '```swift\n'
        'public func curvature(at u: Double) -> Double?\n'
        '```\n'
        '\n'
        '- **Example:**\n'
        '  ```swift\n'
        '  let b = Shape.box(width: 1, height: 1, depth: 1)\n'
        '  ```\n',
        [(4, 'declaration'), (9, 'snippet')],
    ),
    (
        'attribute opens a restatement',
        'a.md',
        '```swift\n@discardableResult\npublic func f() -> Int\n```\n',
        [(2, 'declaration')],
    ),
    (
        'opt-out with a reason is exempt',
        'a.md',
        '```swift no-typecheck: `...` elides the argument list\nWire.arc(center: ..., radius: 50)\n```\n',
        [(2, 'opt-out')],
    ),
    (
        'opt-out without a reason is itself a defect',
        'a.md',
        '```swift no-typecheck\nWire.arc(center: ...)\n```\n',
        [(2, 'opt-out-no-reason')],
    ),
    (
        'a swift fence inside a markdown fence is not harvested',
        'a.md',
        '```markdown\n### `Type.method(label:)`\n\n```swift\nlet x = Phantom.nope()\n```\n```\n',
        [],
    ),
    (
        'non-swift fences are ignored',
        'a.md',
        '```bash\nswift build\n```\n\n```cpp\nint main() {}\n```\n',
        [],
    ),
    (
        'a leading // comment does not decide the kind',
        'a.md',
        '```swift\n// a note about the call below\nlet b = Shape.box(width: 1, height: 1, depth: 1)\n```\n',
        [(2, 'snippet')],
    ),
    (
        'doc-comment fence is extracted and dedented',
        'a.swift',
        '/// Summary.\n'
        '///\n'
        '/// ```swift\n'
        '/// let b = Shape.box(width: 1, height: 1, depth: 1)\n'
        '/// ```\n'
        'public func f() {}\n',
        [(4, 'snippet')],
    ),
    (
        'two doc-comment fences in one file keep their own line numbers',
        'a.swift',
        '/// ```swift\n'
        '/// let a = 1\n'
        '/// ```\n'
        'public var x = 0\n'
        '/// ```swift\n'
        '/// let b = 2\n'
        '/// ```\n'
        'public var y = 0\n',
        [(2, 'snippet'), (6, 'snippet')],
    ),
    (
        'an indented doc comment is handled',
        'a.swift',
        'struct S {\n'
        '    /// ```swift\n'
        '    /// let b = Shape.box(width: 1, height: 1, depth: 1)\n'
        '    /// ```\n'
        '    func f() {}\n'
        '}\n',
        [(3, 'snippet')],
    ),
    (
        'an empty fence has nothing to compile',
        'a.md',
        '```swift\n\n```\n',
        [(2, 'declaration')],
    ),
    (
        'enum case listings are restatements',
        'a.md',
        '```swift\ncase g0\ncase g1\n```\n',
        [(2, 'declaration')],
    ),
]

# Each case: (name, filename, text, expected body lines). The EXTRACT_CASES above assert the line
# number and the kind, which a removal matrix showed is not enough: dropping the closing-fence check
# in `extract_doc_comments` leaves both correct and silently swallows the rest of the doc comment
# into the body. These assert the body itself.
BODY_CASES = [
    (
        'a doc-comment body stops at the closing fence',
        'a.swift',
        '/// Summary.\n'
        '/// ```swift\n'
        '/// let b = Shape.box(width: 1, height: 1, depth: 1)\n'
        '/// ```\n'
        '/// - Returns: a box.\n'
        'public func f() {}\n',
        ['let b = Shape.box(width: 1, height: 1, depth: 1)'],
    ),
    (
        'a markdown body stops at the closing fence and is dedented',
        'a.md',
        '- **Example:**\n'
        '  ```swift\n'
        '  let b = Shape.box(width: 1, height: 1, depth: 1)\n'
        '  _ = b\n'
        '  ```\n'
        '\n'
        'Prose after the fence.\n',
        ['let b = Shape.box(width: 1, height: 1, depth: 1)', '_ = b'],
    ),
    (
        'a blank line inside a doc-comment body survives',
        'a.swift',
        '/// ```swift\n'
        '/// let a = 1\n'
        '///\n'
        '/// let b = 2\n'
        '/// ```\n'
        'public var x = 0\n',
        ['let a = 1', '', 'let b = 2'],
    ),
]

# Each case: (name, snippet body, expected verdict). Requires a built package; SKIPPED without one.
COMPILE_CASES = [
    (
        'a real call type-checks',
        ['let b = Shape.box(width: 10, height: 10, depth: 10)',
         '_ = b?.volume'],
        'clean',
    ),
    (
        "#1675's phantom factory is caught",
        ['if let arc = Curve3D.arc(center: .zero, radius: 5, startAngle: 0, endAngle: .pi) {',
         '    _ = arc',
         '}'],
        'broken',
    ),
    (
        'a wrong argument label is caught',
        ['let b = Shape.box(dx: 10, dy: 10, dz: 10)',
         '_ = b'],
        'broken',
    ),
    (
        'a member that does not exist is caught',
        ['let b = Shape.box(width: 1, height: 1, depth: 1)!',
         '_ = b.definitelyNotAMember'],
        'broken',
    ),
    (
        'a name from the surrounding prose is a fragment, not a failure',
        ['let trimmed = surf.trimmed(uMin: 0, uMax: 1, vMin: 0, vMax: 1)',
         '_ = trimmed'],
        'fragment',
    ),
    (
        # The "any", not "all", rule. The two errors here are INDEPENDENT (a missing name, and a
        # wrong label on a call that has nothing to do with it), which is what makes this case
        # isolate the rule: an `all` rule calls this broken, an `any` rule calls it a fragment. A
        # first version of this case used `surf.project(...)` and then a member on the result, and
        # proved nothing: once a name is unresolved the compiler emits no further error for the
        # members reached through it, so that fixture had one error and both rules agreed on it.
        'a missing name alongside an unrelated defect is still a fragment',
        ['let a = someNameTheProseIntroduced',
         'let b = Shape.box(dx: 1, dy: 1, dz: 1)',
         '_ = (a, b)'],
        'fragment',
    ),
    (
        # And the rule does not swallow a defect that has no missing name: `Shape` resolves, so the
        # bad label is reported rather than excused.
        'a defect with every name resolved is still a failure',
        ['let b = Shape.box(wide: 1, high: 1, deep: 1)',
         '_ = b'],
        'broken',
    ),
    (
        'a prose ellipsis does not parse',
        ['if analysis.isG1 { … }'],
        'unparseable',
    ),
    (
        # Worth a case of its own because the intuition is wrong: `...` is the unbounded range
        # operator, so an elided argument list parses fine and fails in Sema instead. An elision is
        # therefore reported as `broken`, and the `no-typecheck` marker is the only way to exempt one.
        'a `...` elision parses and fails in the type-checker, not the parser',
        ['Wire.arc(center: ..., radius: 50, ...)'],
        'broken',
    ),
    (
        '#expect is rewritten rather than failing on a missing Testing module',
        ['let b = Shape.box(width: 1, height: 1, depth: 1)',
         '#expect(b != nil)'],
        'clean',
    ),
    (
        'a snippet is isolated from its neighbours (this one is clean beside broken ones)',
        ['let s = Shape.box(width: 2, height: 2, depth: 2)',
         '_ = s?.isValid'],
        'clean',
    ),
    (
        # #2092. `docs/reference/**`'s placeholder idiom. Not valid Swift, and not a doc defect:
        # see PLACEHOLDER_ELLIPSIS. 22 pages were reported as failures for writing correct
        # documentation, which is the class that would have made promotion to a gate red on merge.
        "a `= ...` placeholder is a fragment, not unparseable (#2092)",
        ['let curve: Curve3D = ...',
         '_ = curve.isCN(2)'],
        'fragment',
    ),
    (
        # The other half of the same rule, and the reason it is anchored to the placeholder's own
        # line: a real truncation elsewhere in the snippet must still be reported. Without this
        # case the rule could widen to "any snippet containing a placeholder is excused" and
        # nothing would fail.
        "a real truncation alongside a placeholder is still reported (#2092)",
        ['let curve: Curve3D = ...',
         'let p = curve.value(at:'],
        'unparseable',
    ),
]


def _self_test_extract():
    failures = 0
    for name, filename, text, expected in EXTRACT_CASES:
        if filename.endswith('.md'):
            blocks = extract_markdown(filename, text)
        else:
            blocks = extract_doc_comments(filename, text)
        for b in blocks:
            classify(b)
        got = [(b.start_line, b.kind) for b in blocks]
        if got != expected:
            failures += 1
            print(f'  FAIL  {name}\n        expected {expected}\n        got      {got}')
        else:
            print(f'  ok    {name}')
    return failures


def _self_test_bodies():
    failures = 0
    for name, filename, text, expected in BODY_CASES:
        blocks = (extract_markdown if filename.endswith('.md') else extract_doc_comments)(
            filename, text)
        got = blocks[0].body if blocks else None
        if got != expected:
            failures += 1
            print(f'  FAIL  {name}\n        expected {expected}\n        got      {got}')
        else:
            print(f'  ok    {name}')
    return failures


def _self_test_exclusions():
    """The historical documents are excluded from a default scan and reachable with `--paths`."""
    failures = 0
    for rel in sorted(HISTORICAL):
        if not (REPO / rel).is_file():
            failures += 1
            print(f'  FAIL  HISTORICAL names {rel}, which is not in the tree')
            continue
        if any(b.path == rel for b in collect()):
            failures += 1
            print(f'  FAIL  {rel} was scanned by default')
        elif not collect([rel]):
            failures += 1
            print(f'  FAIL  {rel} is unreachable even with --paths')
        else:
            print(f'  ok    {rel} is excluded by default and reachable with --paths')
    return failures


def _self_test_dedent_and_rewrite():
    failures = 0
    cases = [
        ('dedent strips the common indent',
         _dedent(['    let a = 1', '        let b = 2', '']),
         ['let a = 1', '    let b = 2', '']),
        ('#expect becomes a plain expression',
         rewrite_for_compile(['#expect(a == b)']),
         ['_ = (a == b)']),
        ('an unsupported macro form is detected',
         [unsupported_macro(['#expect(throws: Foo.self) { }'])],
         ['#expect(throws:']),
        ('a supported body reports no unsupported macro',
         [unsupported_macro(['#expect(a == b)'])],
         [None]),
    ]
    # The architecture derivation, on a synthetic bundle: a hardcoded arch fails with "no such
    # module" on a runner that is not the one it was written on.
    d = pathlib.Path(tempfile.mkdtemp(prefix='occt-doc-snippets-arch-'))
    try:
        (d / 'x86_64-apple-macos.swiftmodule').write_text('')
        cases.append(('the architecture comes from the built module, not a constant',
                      [module_arch(d)], ['x86_64']))
        cases.append(('an empty module bundle yields no architecture',
                      [module_arch(d.parent / 'nonexistent-bundle')], [None]))
        # #2098. SwiftPM's other shape: a plain file, not a bundle, which is what CI produces.
        # There is no name to read the arch from, and the host's is the only one it can be. Without
        # this branch CI skipped every compile case while printing "0 failed".
        single = d / 'OCCTSwift.swiftmodule'
        single.write_text('')
        cases.append(('a single-file .swiftmodule takes the host architecture (#2098)',
                      [module_arch(single)], [platform.machine()]))
    finally:
        shutil.rmtree(d, ignore_errors=True)
    for name, got, expected in cases:
        if got != expected:
            failures += 1
            print(f'  FAIL  {name}\n        expected {expected}\n        got      {got}')
        else:
            print(f'  ok    {name}')
    return failures


def _self_test_attribution():
    """The generated-line to doc-line map, which is what makes a report actionable."""
    failures = 0
    block = Block('docs/x.md', 100, '', ['let a = 1', 'let b = phantom()'], 'markdown')
    block.kind = 'snippet'
    outdir = pathlib.Path(tempfile.mkdtemp(prefix='occt-doc-snippets-selftest-'))
    try:
        index = generate([block], outdir)
        body_first = index['s00000.swift'][1]
        fake = f'{outdir}/s00000.swift:{body_first + 1}:9: error: cannot find \'phantom\' in scope'
        got = parse_diags([fake], index, outdir)
        expected = {'s00000.swift': [(101, "cannot find 'phantom' in scope")]}
        if got != expected:
            failures += 1
            print(f'  FAIL  a diagnostic maps back to the doc line\n'
                  f'        expected {expected}\n        got      {got}')
        else:
            print('  ok    a diagnostic maps back to the doc line')
        # A warning is not a failure, and a diagnostic from outside the generated tree is not ours.
        noise = [
            f'{outdir}/s00000.swift:{body_first}:5: warning: initialization of immutable value',
            "/Users/x/Sources/OCCTSwift/Shape.swift:10:1: error: something in the library",
        ]
        got = parse_diags(noise, index, outdir)
        if got != {}:
            failures += 1
            print(f'  FAIL  warnings and library diagnostics are ignored, got {got}')
        else:
            print('  ok    warnings and library diagnostics are ignored')
    finally:
        shutil.rmtree(outdir, ignore_errors=True)
    return failures


def _self_test_compile():
    """Compile the fixture battery, in both compiler modes. Proves the tool is not blind.

    The battery runs twice. Once under `-wmo`, which is how the real scan runs, and once in the
    driver's batch mode, which is the only mode where `-continue-building-after-errors` does anything
    and therefore the only mode in which removing that flag fails a case. Both passes must agree
    verdict for verdict: a disagreement means the compiler's own mode is deciding what this script
    reports, which is the failure the batch-mode pass exists to catch.
    """
    tc_args, triple, why_not = toolchain_args()
    if why_not is not None:
        # A fatal reason (a module older than its inputs) is a refusal, not a skip, and
        # `_self_test_staleness` has already reported it as a failure. Printing the word SKIPPED
        # over it would be this script mislabelling its own view.
        print(f'  {"REFUSED" if why_not.fatal else "SKIPPED"}  compile cases: {why_not}')
        return 0, True, str(why_not)
    print(f'  ok    target triple derived from the built module: {triple}')
    failures = 0
    verdicts = {}
    for wmo in (True, False):
        blocks = []
        for name, body, expected in COMPILE_CASES:
            b = Block(f'fixture/{name}.md', 1, '', list(body), 'markdown')
            b.kind = 'snippet'
            blocks.append(b)
        label = '-wmo' if wmo else 'batch mode'
        try:
            results, _note = check(blocks, wmo=wmo)
        except BlindRun as exc:
            failures += 1
            print(f'  FAIL  [{label}] a canary was dropped: {exc}')
            continue
        for n, (name, _body, expected) in enumerate(COMPILE_CASES):
            got = results.get(f's{n:05d}.swift', ('<missing>', []))[0]
            verdicts.setdefault(name, {})[label] = got
            if got != expected:
                failures += 1
                errs = results.get(f's{n:05d}.swift', (None, []))[1]
                print(f'  FAIL  [{label}] {name}\n        expected {expected}, got {got}')
                for line, msg in errs[:3]:
                    print(f'        line {line}: {msg}')
            elif wmo:
                print(f'  ok    {name}')
    disagree = [n for n, v in verdicts.items() if len(set(v.values())) > 1]
    if disagree:
        failures += len(disagree)
        for n in disagree:
            print(f'  FAIL  the two compiler modes disagree on: {n} ({verdicts[n]})')
    else:
        print('  ok    -wmo and batch mode agree on every case')
    return failures, False, None


def _self_test_canary():
    """Prove the canary guard is not decorative, by making swiftc report nothing at all.

    This is the case that would have caught the first version of this script, which ran without
    `-continue-building-after-errors` and silently reported every snippet after the first defect as
    clean. With `run_swiftc` stubbed to emit no diagnostics, a run with no canary guard would call
    the whole tree clean; the guard must refuse instead.
    """
    failures = 0
    block = Block('docs/x.md', 1, '', ['let b = Shape.box(width: 1, height: 1, depth: 1)'], 'markdown')
    block.kind = 'snippet'
    real = globals()['run_swiftc']
    globals()['run_swiftc'] = lambda *a, **k: []
    try:
        try:
            check([block])
        except BlindRun:
            print('  ok    a compiler that reports nothing is refused, not believed')
        else:
            failures += 1
            print('  FAIL  a compiler that reports nothing was believed')
        # And with canaries switched off, the same stubbed run reports clean: the guard, not the
        # stub, is what makes the case above fail.
        try:
            results, _ = check([block], canaries=False)
            verdicts = {v for v, _ in results.values()}
            if verdicts == {'clean'} or verdicts == {'skipped'}:
                print('  ok    the refusal above comes from the canary, not from the stub')
            else:
                failures += 1
                print(f'  FAIL  expected clean/skipped without canaries, got {verdicts}')
        except BlindRun:
            failures += 1
            print('  FAIL  BlindRun raised with canaries switched off')
    finally:
        globals()['run_swiftc'] = real
    return failures


def _self_test_run_stage():
    """#2851's stage. Returns `(failures, ran, total)`.

    The last three cases compile a real executable, so they skip where `swiftc` is absent, and the
    caller says so rather than folding the difference into one number (#2867).
    """
    failures = 0

    def case(name, ok, detail=''):
        nonlocal failures
        if ok:
            print(f'  ok    {name}')
        else:
            failures += 1
            print(f'  FAIL  {name}  {detail}')

    def mk(info, body, kind='snippet'):
        b = Block('docs/x.md', 1, info, body, 'markdown')
        classify(b)
        return b

    # The marker, and the two ways it can be written.
    b = mk(f'{NO_RUN}: writes a 40 MB STEP file', ['let s = 1'])
    case(f'`{NO_RUN}: <reason>` is read off the fence and keeps the snippet type-checked',
         b.no_run == 'writes a 40 MB STEP file' and b.kind == 'snippet', repr(b.no_run))

    bare = mk(NO_RUN, ['let s = 1'])
    case(f'a bare `{NO_RUN}` records an empty reason, which report() fails on',
         bare.no_run == '', repr(bare.no_run))

    plain = mk('', ['let s = 1'])
    case('a fence with no marker is runnable', plain.no_run is None, repr(plain.no_run))

    # `no-typecheck` implies it: an opt-out is never compiled, so it is never linked either.
    opt = mk(f'{OPT_OUT}: a listing of case spellings', ['case a'])
    results = {'s00000.swift': ('clean', []), 's00001.swift': ('clean', []),
               's00002.swift': ('broken', [(1, 'no')])}
    picked = runnable([b, plain, mk('', ['let t = 2']), opt], results)
    case('runnable() takes the clean, unmarked snippets and nothing else',
         picked == [plain], f'{[x.info for x in picked]}')

    # The link flags come from the directory holding libOCCTSwift.a, and every archive in it.
    holder = pathlib.Path(tempfile.mkdtemp(prefix='occt-doc-linkargs-'))
    try:
        bin_dir = holder / '.build' / 'debug'
        (bin_dir / 'Modules').mkdir(parents=True)
        (bin_dir / PACKAGE_ARCHIVE).write_bytes(b'!<arch>\n')
        (bin_dir / 'libZed.a').write_bytes(b'!<arch>\n')
        # `base` points at an empty tree, so only the beside-the-module path can answer and the
        # fallback below cannot stand in for it.
        nowhere = pathlib.Path(tempfile.mkdtemp(prefix='occt-doc-nobuild-'))
        try:
            got = link_args(bin_dir / 'Modules', base=nowhere)
        finally:
            shutil.rmtree(nowhere, ignore_errors=True)
        case('link_args finds the archive one level up and passes every one beside it',
             got is not None and got[:2] == ['-L', str(bin_dir)]
             and '-lOCCTSwift' in got and '-lZed' in got, repr(got))

        # CI's layout, and the reason this is not "any lib*.a beside the module": on the runner
        # the module's own directory held the OCCT kernel archive and nothing else, and taking it
        # produced a link that failed on every OCCTSwift symbol.
        elsewhere = holder / '.build' / 'other'
        (elsewhere / 'Modules').mkdir(parents=True)
        (elsewhere / 'libOCCT-macos.a').write_bytes(b'!<arch>\n')
        got = link_args(elsewhere / 'Modules', base=holder)
        case('a kernel archive beside the module is not mistaken for the package archive',
             got is not None and got[:2] == ['-L', str(bin_dir)], repr(got))
    finally:
        shutil.rmtree(holder, ignore_errors=True)

    # ...and with nothing to find anywhere, it says so rather than returning a partial link.
    empty = pathlib.Path(tempfile.mkdtemp(prefix='occt-doc-noarchive-'))
    try:
        (empty / '.build').mkdir()
        case('no archive anywhere is None, not a partial set of flags',
             link_args(empty / 'nowhere', base=empty) is None)
    finally:
        shutil.rmtree(empty, ignore_errors=True)

    fixed_cases = 7
    if shutil.which('swiftc') is None and shutil.which('xcrun') is None:
        return failures, fixed_cases, fixed_cases + 3

    # End to end, with no OCCT in it: a plain Swift runner is enough to prove the driver names the
    # right case, resumes past it, and is not fooled by a silent one.
    def blocks_for(bodies):
        out = []
        for i, body in enumerate(bodies):
            blk = Block('docs/fixture.md', i + 1, '', body, 'markdown')
            blk.kind = 'snippet'
            out.append(blk)
        return out

    plain_imports = ('import Foundation',)
    bodies = [['print("a")'],
              ['fatalError("deliberate")'],
              ['print("c")'],
              ['throw NSError(domain: "x", code: 1)'],
              ['print("e")']]
    outcomes, _, note = execute_stage(blocks_for(bodies), [], stall=20, imports=plain_imports)
    kinds = [outcomes[i].kind if i in outcomes else 'missing' for i in range(5)]
    case('the driver names the crashing case and resumes past it',
         note is None and kinds == ['ok', 'crash', 'ok', 'threw', 'ok'], f'{kinds} note={note}')

    # `Thread.sleep` is unavailable from an async context and `Task.sleep` is cancellable, so the
    # hang is written as the thing a real snippet hangs on: a loop that does not finish.
    #
    # This case's injected-failure signature is a TIMEOUT, not a red line, and that is not a
    # weakness in it. Disable the watchdog and there is nothing left to report with: the battery
    # runs forever, which is the outcome this stage exists to prevent and is what the job timeout
    # above CI catches. Measured that way when proving it fails.
    stall_bodies = [['print("a")'],
                    ['var n = 0.0', 'while true { n += 1 }', '_ = n'],
                    ['print("c")']]
    outcomes, _, note = execute_stage(blocks_for(stall_bodies), [], stall=3,
                                      imports=plain_imports)
    kinds = [outcomes[i].kind if i in outcomes else 'missing' for i in range(3)]
    case('the driver names a hanging case and resumes past it',
         note is None and kinds == ['ok', 'stall', 'ok'], f'{kinds} note={note}')

    # The canary. A driver that reports every case clean must be refused, which is the run-stage
    # form of the argument the compile stages' canaries make.
    real = globals()['drive_runner']
    globals()['drive_runner'] = lambda exe, total, cwd, **k: {
        i: RunOutcome('ok') for i in range(total)}
    try:
        raised = False
        try:
            execute_stage(blocks_for([['print("a")']]), [], imports=plain_imports)
        except BlindRun:
            raised = True
        case('a driver that reports the planted fatalError as clean is refused', raised)
    finally:
        globals()['drive_runner'] = real

    return failures, fixed_cases + 3, fixed_cases + 3


def _self_test_reporting():
    """Prove the two things a weakened or refusing run has to say out loud.

    Both are reporting rather than verdicts, and both are here because #2867's evidence was
    reconstructed from outside the runs that produced it: the case counts from a table of two jobs'
    summary lines, and the module's identity from three jobs' deltas reduced against three checkout
    times. Neither run said it. A case per sentence, so the sentence cannot quietly go.
    """
    failures = 0
    ran = 0

    ran += 1
    if weakened_run_notice(67, 67, None) is None:
        print('  ok    a run that ran every case draws no banner')
    else:
        failures += 1
        print('  FAIL  a complete run drew the weakened-run banner')

    ran += 1
    notice = weakened_run_notice(38, 67, 'no built package')
    if (notice is not None and '38' in notice and '67' in notice and '29' in notice
            and 'no built package' in notice and 'WEAKENED RUN' in notice):
        print('  ok    a weakened run names how many cases ran, how many did not, and why')
    else:
        failures += 1
        print(f'  FAIL  the weakened-run banner does not name both counts\n        got {notice!r}')

    base = pathlib.Path(tempfile.mkdtemp(prefix='occt-doc-snippets-inventory-'))
    try:
        (base / 'Sources' / 'OCCTSwift').mkdir(parents=True)
        src = base / 'Sources' / 'OCCTSwift' / 'A.swift'
        src.write_text('x\n')
        os.utime(src, (3000, 3000))

        def bundle_at(rel, when):
            b = base / '.build' / rel / 'OCCTSwift.swiftmodule'
            b.mkdir(parents=True)
            member = b / 'arm64-apple-macos.swiftmodule'
            member.write_bytes(b'')
            os.utime(member, (when, when))
            os.utime(b, (when, when))
            return b

        bundle_at('debug/Modules', 1075)
        lines = module_inventory_lines(base=base, globs=('Sources/OCCTSwift/**/*.swift',))
        ran += 1
        if (len(lines) == 1 and 'debug/Modules' in lines[0] and '1925s OLDER' in lines[0]
                and '1970-01-01T00:17:55Z' in lines[0]):
            print('  ok    a module older than its inputs is named, with an absolute write time')
        else:
            failures += 1
            print(f'  FAIL  the inventory does not name an older module as older\n        {lines}')

        bundle_at('arm64-apple-macosx/debug', 4000)
        lines = module_inventory_lines(base=base, globs=('Sources/OCCTSwift/**/*.swift',))
        ran += 1
        if (len(lines) == 3 and any('1000s newer' in ln for ln in lines)
                and 'more than one OCCTSwift.swiftmodule' in lines[-1]):
            print('  ok    two modules under one .build are both named, and the ambiguity is said')
        else:
            failures += 1
            print(f'  FAIL  two modules were not reported as two\n        {lines}')

        # `.build/debug` is a symlink to the bin directory under both build systems shipped here, so
        # the same module is reachable by two paths. Reporting it twice would read as the case above.
        alias_base = pathlib.Path(tempfile.mkdtemp(prefix='occt-doc-snippets-alias-'))
        try:
            (alias_base / 'Sources' / 'OCCTSwift').mkdir(parents=True)
            asrc = alias_base / 'Sources' / 'OCCTSwift' / 'A.swift'
            asrc.write_text('x\n')
            os.utime(asrc, (3000, 3000))
            real = alias_base / '.build' / 'out' / 'Products' / 'Debug'
            real.mkdir(parents=True)
            rb = real / 'OCCTSwift.swiftmodule'
            rb.mkdir()
            (rb / 'arm64-apple-macos.swiftmodule').write_bytes(b'')
            os.utime(rb / 'arm64-apple-macos.swiftmodule', (4000, 4000))
            os.utime(rb, (4000, 4000))
            (alias_base / '.build' / 'debug').symlink_to(real)
            lines = module_inventory_lines(alias_base,
                                          globs=('Sources/OCCTSwift/**/*.swift',))
            ran += 1
            if len(lines) == 1 and 'also reachable as' in lines[0]:
                print('  ok    one module reached by two paths is one module, with the alias named')
            else:
                failures += 1
                print(f'  FAIL  a symlinked alias was counted as a second module\n        {lines}')
        finally:
            shutil.rmtree(alias_base, ignore_errors=True)
    finally:
        shutil.rmtree(base, ignore_errors=True)
    return failures, ran


def _self_test_staleness():
    """Prove the stale-module detector fires on a module older than its inputs, and only then.

    Returns `(failures, cases run)`. Fixtures, because the property under test is a comparison of
    two mtimes and a fixture is the only way to control both sides of it. The glob tuple under test
    is the shipped `MODULE_INPUT_GLOBS`, pointed at the fixture root, so a change to that tuple is
    what these cases measure rather than a copy of it.

    The last case is the real tree, and it is the one that would catch this check misfiring in CI:
    after `swift build` the module must not read as stale, or the gate refuses on every PR. It is
    SKIPPED where there is no built module, under `--require-typecheck`'s abort like the compile
    cases.
    """
    failures = 0
    ran = 0
    base = pathlib.Path(tempfile.mkdtemp(prefix='occt-doc-snippets-stale-'))
    try:
        (base / 'Sources' / 'OCCTSwift').mkdir(parents=True)
        (base / 'Sources' / 'OCCTBridge' / 'include').mkdir(parents=True)
        (base / 'docs').mkdir()
        src = base / 'Sources' / 'OCCTSwift' / 'A.swift'
        header = base / 'Sources' / 'OCCTBridge' / 'include' / 'B.h'
        manifest = base / 'Package.swift'
        doc = base / 'docs' / 'a.md'
        for f in (src, header, manifest, doc):
            f.write_text('x\n')
        moddir = base / 'debug'
        bundle = moddir / 'OCCTSwift.swiftmodule'
        bundle.mkdir(parents=True)
        member = bundle / 'arm64-apple-macos.swiftmodule'
        member.write_bytes(b'')

        def stamp(path, when):
            os.utime(path, (when, when))

        def state(src_t, header_t, manifest_t, doc_t, bundle_t, member_t):
            stamp(src, src_t)
            stamp(header, header_t)
            stamp(manifest, manifest_t)
            stamp(doc, doc_t)
            stamp(member, member_t)
            stamp(bundle, bundle_t)

        # (name, mtimes, predicate on the reason). A reason of None means "current".
        cases = [
            ('a module written after every input is current',
             (1000, 1000, 1000, 1000, 2000, 2000),
             lambda r: r is None),
            ('a Swift source newer than the module is stale, and the reason names it',
             (3000, 1000, 1000, 1000, 2000, 2000),
             lambda r: r is not None and 'A.swift' in r),
            ('a bridge header newer than the module is stale, and the reason names it',
             (1000, 3000, 1000, 1000, 2000, 2000),
             lambda r: r is not None and 'B.h' in r),
            ('the manifest newer than the module is stale, and the reason names it',
             (1000, 1000, 3000, 1000, 2000, 2000),
             lambda r: r is not None and 'Package.swift' in r),
            ('a doc newer than the module is NOT stale, so editing a snippet never refuses',
             (1000, 1000, 1000, 9000, 2000, 2000),
             lambda r: r is None),
            ("the bundle's members are read, not the bundle's own mtime",
             (1500, 1000, 1000, 1000, 1000, 2000),
             lambda r: r is None),
        ]
        for name, mtimes, ok in cases:
            state(*mtimes)
            ran += 1
            reason = stale_module_reason(moddir, base=base)
            if ok(reason):
                print(f'  ok    {name}')
            else:
                failures += 1
                print(f'  FAIL  {name}\n        got {reason!r}')

        # A module that is not there at all belongs to the skip channel, not to this one.
        ran += 1
        if stale_module_reason(base / 'nowhere', base=base) is None:
            print('  ok    a missing module is not reported as a stale one')
        else:
            failures += 1
            print('  FAIL  a missing module was reported as a stale one')

        # A sub-second gap is reported as one. `{delta:.0f}s` printed `was written 0s after`, which
        # reads as no difference at all, and a source rewritten half a second after the module is
        # the ordinary case on a fast disk (#2817 review).
        state(2000.4, 1000, 1000, 1000, 2000, 2000)
        ran += 1
        reason = stale_module_reason(moddir, base=base)
        if reason is not None and 'less than 1s' in reason:
            print('  ok    a sub-second gap is reported as "less than 1s", never as "0s"')
        else:
            failures += 1
            print(f'  FAIL  a sub-second gap was not reported as such\n        got {reason!r}')

        # An input this run could not stat() does not count toward the comparison, and is named on
        # stderr rather than skipped in silence. A broken symlink is the reachable instance: glob
        # lists it, `stat()` follows it and raises (#2817 review).
        state(1000, 1000, 1000, 1000, 2000, 2000)
        broken = base / 'Sources' / 'OCCTSwift' / 'Gone.swift'
        broken.symlink_to(base / 'Sources' / 'OCCTSwift' / 'never-existed.swift')
        noise = io.StringIO()
        with contextlib.redirect_stderr(noise):
            reason = stale_module_reason(moddir, base=base)
        said = noise.getvalue()
        ran += 1
        if reason is None and 'Gone.swift' in said and 'could not stat' in said:
            print('  ok    an unreadable input is named on stderr and does not force a refusal')
        else:
            failures += 1
            print('  FAIL  an unreadable input was passed over in silence\n'
                  f'        reason={reason!r} stderr={said!r}')
        broken.unlink()

        # The same for a member of the module bundle, which errs the other way: dropping a member
        # lowers the maximum, so it can only make the module read as older.
        broken_member = bundle / 'gone.swiftmodule'
        broken_member.symlink_to(bundle / 'never-existed.swiftmodule')
        # Adding an entry rewrites the bundle directory's own mtime, which `module_written` includes,
        # so put it back where the fixture wants it before measuring.
        stamp(bundle, 2000)
        noise = io.StringIO()
        with contextlib.redirect_stderr(noise):
            built = module_written(moddir)
        said = noise.getvalue()
        ran += 1
        if built == 2000 and 'gone.swiftmodule' in said and 'could not stat' in said:
            print('  ok    an unreadable bundle member is named on stderr and the rest still count')
        else:
            failures += 1
            print('  FAIL  an unreadable bundle member was passed over in silence\n'
                  f'        built={built!r} stderr={said!r}')
        broken_member.unlink()
    finally:
        shutil.rmtree(base, ignore_errors=True)

    # The real tree. `swift build` must leave a module newer than every input, or this refusal
    # fires on every PR; asserting it here names the cause instead of leaving a bare red run.
    _args, _triple, why_not = toolchain_args()
    if why_not is None:
        ran += 1
        print('  ok    the built module in this tree is newer than every input')
    elif why_not.fatal:
        ran += 1
        failures += 1
        print(f'  FAIL  the built module in this tree reads as stale: {why_not}')
    else:
        print(f'  SKIPPED  real tree: {why_not}')
    # Which module this run read, on every outcome including the passing one. A refusal that names
    # the module without saying when it was written cannot be told from a refusal about a module the
    # build never wrote, and telling those apart is the whole of #2867.
    for line in module_inventory_lines():
        print(line)
    return failures, ran, ran if why_not is None or why_not.fatal else ran + 1


# How wide the weakened-run banner is drawn. Wide enough that it cannot be mistaken for one more
# `ok` line in a scroll of forty of them, which is what the parenthetical it replaces was.
NOTICE_RULE = '#' * 78


def weakened_run_notice(ran, total, reason):
    """The banner for a self-test run that could not run every case, or None when it ran them all.

    **The count, not the reason, is the headline.** A run with the compile cases out checks 38
    things where the full battery checks 67, and until #2867 it said so in five parenthesised words
    at the end of forty lines of `ok`. That is the #2098 shape exactly: a detector reporting success
    over a smaller population than its reader believes it covers. #2098 itself was 24 snippets of
    3,105 and a green step, and the lesson recorded in okf/policies/static-gates.md is that the
    report of an absent precondition has to state what was not examined, loudly enough to be read.

    Separate from `--require-typecheck`, which turns this into exit 2. That flag is for CI, where a
    weakened run is a false green; this banner is for everywhere, including the local run where
    skipping is the right behaviour and the person still has to know which half they proved.
    """
    if ran >= total:
        return None
    lines = [NOTICE_RULE,
             f'WEAKENED RUN: {total - ran} of {total} self-test cases DID NOT RUN. '
             f'{ran} of {total} ran.',
             '']
    if reason:
        lines.append(f'Why: {reason}')
        lines.append('')
    # Named rather than counted, because "28 cases" tells nobody which property went unproven. The
    # real-tree case is deliberately not in this list: it runs, and fails, when the module is stale,
    # and is skipped only when there is no module at all, so the count above carries it and this
    # sentence would be wrong half the time if it claimed it.
    lines.append('The cases that did not run are the compile battery and the target triple it')
    lines.append('derives from the built module, so this run proves NOTHING about the type-check')
    lines.append('path. Run `swift build` first. In CI, pass --require-typecheck, which makes this')
    lines.append('a refusal rather than a quieter pass.')
    lines.append(NOTICE_RULE)
    return '\n'.join(lines)


def self_test(require_typecheck=False):
    print('extraction and classification:')
    failures = _self_test_extract()
    print('extracted bodies:')
    failures += _self_test_bodies()
    print('historical-document exclusions:')
    failures += _self_test_exclusions()
    print('dedent, rewrite and macro guard:')
    failures += _self_test_dedent_and_rewrite()
    print('diagnostic attribution:')
    failures += _self_test_attribution()
    print('canary guard:')
    failures += _self_test_canary()
    print('run stage (#2851):')
    run_failures, run_ran, run_total = _self_test_run_stage()
    failures += run_failures
    print('reporting:')
    report_failures, report_cases = _self_test_reporting()
    failures += report_failures
    print('stale-module detection:')
    stale_failures, staleness_ran, staleness_total = _self_test_staleness()
    failures += stale_failures
    print('end-to-end compile:')
    compile_failures, skipped, skip_reason = _self_test_compile()
    failures += compile_failures
    # 7 is _self_test_dedent_and_rewrite's case count, 2 each for attribution and the canary guard.
    # The stale-module battery counts its own cases, because its last one is skipped where there is
    # no built module, and it reports `ran` and `total` separately so the banner below can name the
    # difference rather than leave it to be inferred from a number nobody has the other half of.
    fixed = (len(EXTRACT_CASES) + len(BODY_CASES) + len(HISTORICAL) + 7 + 2 + 2 + report_cases)
    compile_cases = 2 * len(COMPILE_CASES) + 2
    ran = fixed + staleness_ran + run_ran + (0 if skipped else compile_cases)
    total = fixed + staleness_total + run_total + compile_cases
    print(f'\nself-test: {ran - failures} passed, {failures} failed '
          f'({ran} of {total} cases ran)')
    notice = weakened_run_notice(ran, total, skip_reason)
    if notice is not None:
        print(f'\n{notice}')
    if skipped and require_typecheck:
        # #2098: in CI this skip took the battery from 51 cases to 27 and still exited 0, so the
        # step proved nothing about the compile path while looking exactly like the local pass.
        print('\nABORTED: --require-typecheck was given and the compile cases were skipped, so '
              'this run\n  proves nothing about the compile path. Build the package first.',
              file=sys.stderr)
        return 2
    return 1 if failures else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--self-test', action='store_true',
                    help='run the fixture battery instead of scanning the tree')
    ap.add_argument('--strict', action='store_true',
                    help='accepted and ignored: strict IS the default since #1683 promoted this '
                         'to a gate. Kept so existing invocations keep working')
    ap.add_argument('--require-typecheck', action='store_true',
                    help='exit 2 if the type-check stage is skipped, rather than reporting a '
                         'population that was never examined (for CI, where a skip is a false green)')
    ap.add_argument('--list', action='store_true',
                    help='census per kind, no compile')
    ap.add_argument('--fragments', action='store_true',
                    help='also list the snippets that open mid-flow')
    ap.add_argument('--declarations', action='store_true',
                    help='also list the signature restatements that were skipped')
    ap.add_argument('--paths', nargs='+', metavar='PATH',
                    help='scan only these files (default: docs/ and Sources/OCCTSwift/)')
    ap.add_argument('--keep', metavar='DIR',
                    help='write the generated Swift files here and leave them in place')
    ap.add_argument('--jobs', type=int, metavar='N',
                    help='parallel swiftc processes (default: one less than the core count)')
    # ON BY DEFAULT, measured at 5 s on top of an 18 s type-check run over 1,735 snippets, and
    # off by a flag rather than on by one so that a local run and CI cannot check different
    # things. That is the same property `format-bridge.sh` gives the bridge and the reason
    # `--strict` stopped being a flag here.
    ap.add_argument('--run', dest='run', action='store_true', default=True,
                    help='EXECUTE every snippet that type-checks and carries no `no-run:` '
                         'marker, in a scratch working directory (#2851). The default')
    ap.add_argument('--no-run', dest='run', action='store_false',
                    help='type-check only, the behaviour before #2851')
    ap.add_argument('--run-stall', type=float, metavar='SECONDS', default=DEFAULT_STALL,
                    help=f'seconds without progress before a case is called a hang '
                         f'(default: {DEFAULT_STALL:.0f})')
    ap.add_argument('--verbose', action='store_true', help='progress on stderr')
    args = ap.parse_args()

    if args.self_test:
        return self_test(require_typecheck=args.require_typecheck)

    blocks = collect(args.paths)
    if args.list:
        # --list does not compile, so it cannot judge a snippet. Inventory only, never a verdict.
        report(blocks, {}, show_fragments=args.fragments, show_declarations=args.declarations)
        return 0

    try:
        results, note = check(blocks, verbose=args.verbose, keep=args.keep,
                                  jobs=args.jobs)
    except BlindRun as exc:
        print(f'ABORTED: {exc}', file=sys.stderr)
        return 2
    if note and (note.fatal or args.require_typecheck):
        # A census exits 0 by design, because its output is a population to adjudicate. A census
        # that examined none of that population is not a census result, it is silence dressed as
        # one, and in CI that is a false green (#2098).
        print(f'ABORTED: {note}', file=sys.stderr)
        if note.fatal:
            # And a verdict reached against a module built from different source is worse than
            # silence: it names the page under review as the defect. Refuse everywhere, not only
            # under the CI flag.
            print('No snippet was judged. A module built from different source reports a correct '
                  'snippet\n  as broken, which is a finding about the module and not about the '
                  'page.', file=sys.stderr)
            # And say which module, and when it was written. #2867's refusal named a directory and
            # left "was it this build's module at all" to be answered from three jobs' logs.
            for line in module_inventory_lines():
                print(line, file=sys.stderr)
        else:
            print('--require-typecheck was given, so a skipped type-check stage is a failure '
                  'rather than a\n  census result. Build the package first.', file=sys.stderr)
        return 2
    if note:
        print(note)
    status = report(blocks, results, show_fragments=args.fragments,
                    show_declarations=args.declarations)

    if args.run and note is not None:
        # The type-check stage was skipped and `--require-typecheck` was not given, so this is a
        # machine with no built package. Stage 3 needs strictly more than stage 2 does, so it
        # skips for the same reason and says so rather than reporting a clean corpus.
        print('\n  stage 3, run: SKIPPED, because the type-check stage was')
    elif args.run:
        tc_args, _, why_not = toolchain_args()
        if tc_args is None:
            print(f'ABORTED: the run stage needs the same built module the type-check stage '
                  f'needs: {why_not}', file=sys.stderr)
            return 2
        cases = runnable(blocks, results)
        try:
            outcomes, secs, run_note = execute_stage(
                cases, tc_args, stall=args.run_stall, keep=args.keep, verbose=args.verbose)
        except BlindRun as exc:
            print(f'ABORTED: {exc}', file=sys.stderr)
            return 2
        if run_note is not None:
            print(f'ABORTED: {run_note}', file=sys.stderr)
            return 2
        status = max(status, report_run(cases, outcomes, secs))
    return status


if __name__ == '__main__':
    sys.exit(main())
