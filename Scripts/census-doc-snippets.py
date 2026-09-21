#!/usr/bin/env python3
r"""CENSUS, not a gate: type-check every fenced Swift snippet in `docs/` and in `///` doc comments.

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

## Where it lives, and why it is a census

**Not in `ci.yml`'s `gate-scripts`.** That job is pure Python over the repo's own text, no OCCT and
no build, about three seconds for the lot, and this needs `OCCTSwift` built to type-check against.
It runs in `swift build + test (macOS)` instead, after the build it reuses, in about two minutes.

**The measurement, on the tree this landed in** (3,096 snippets): 1,470 clean, 1,415 fragment, 187
broken, 24 unparseable. So 211 snippets do not compile, and 1,415 more cannot be judged until they
get a preamble. That is the backlog, not a verdict on the checker.

**A census rather than a gate, on volume and not on trust.** Nothing here has a measured
false-positive class to discount, the way `census-doc-occt-attribution.py` has its 41%: the compiler
adjudicates, the block classifier errs only toward skipping a check, the fragment rule errs only
toward excusing one, and a canary in every `swiftc` invocation aborts the run rather than letting a
blind compiler report clean. What stops it gating today is that `main` carries a backlog of
non-compiling snippets, and a required check that is red for every PR is worse than no check
(`okf/policies/required-status-checks.md`). So it exits 0 and prints the count, `--strict` exits 1 for
anyone who wants the gate behaviour on their own page, and **promotion is a rename to `check-` plus
making `--strict` the default**, once the backlog is zero. #1407 is the precedent for measuring
before gating.

## Usage

    python3 Scripts/census-doc-snippets.py              # extract, type-check, report (always exits 0)
    python3 Scripts/census-doc-snippets.py --strict     # ...and exit 1 on a non-compiling snippet
    python3 Scripts/census-doc-snippets.py --list       # inventory per kind, no compile
    python3 Scripts/census-doc-snippets.py --fragments  # also list the fragment sites
    python3 Scripts/census-doc-snippets.py --self-test  # prove the detector is not blind
    python3 Scripts/census-doc-snippets.py --paths docs/reference/Curve3D-Analysis.md
"""

from __future__ import annotations

import argparse
import os
import pathlib
import re
import shutil
import platform
import subprocess
import sys
import tempfile

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

    __slots__ = ('path', 'start_line', 'info', 'body', 'origin', 'kind', 'reason')

    def __init__(self, path, start_line, info, body, origin):
        self.path = path            # repo-relative str
        self.start_line = start_line  # 1-based line of the block's FIRST BODY line
        self.info = info            # fence info string after the language word
        self.body = body            # list of str, dedented, comment markers stripped
        self.origin = origin        # 'markdown' | 'doc-comment'
        self.kind = None            # 'declaration' | 'snippet' | 'opt-out' | 'opt-out-no-reason'
        self.reason = None          # opt-out reason

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
    """Set `block.kind` (and `block.reason` for an opt-out)."""
    info = block.info
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


def module_arch(swiftmodule_dir):
    """The architecture of a built `.swiftmodule` bundle, from the one file inside it.

    SwiftPM names it `<arch>-apple-macos.swiftmodule`. Derived rather than hardcoded because a
    `-target` naming an architecture the built module does not carry fails with "no such module",
    which reads as a broken script rather than a mismatched flag: `macos-15` runners are arm64 today
    and were x86_64 not long ago.
    """
    arches = [f.stem.split('-', 1)[0] for f in sorted(swiftmodule_dir.glob('*.swiftmodule'))]
    if not arches:
        return None
    # A universal build leaves several. Prefer the host's, because that is what an unqualified
    # `swiftc` invocation targets; taking the alphabetically-first would pick arm64 on an x86_64
    # host and fail with "no such module", which reads as a broken script rather than a mismatch.
    host = platform.machine()
    return host if host in arches else arches[0]


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
    if module_dir is None:
        return None, None, ('OCCTSwift.swiftmodule not found; run `swift build` first '
                            f'(looked in {", ".join(str(c) for c in candidates)})')
    arch = module_arch(module_dir / 'OCCTSwift.swiftmodule')
    if arch is None:
        return None, None, f'no *.swiftmodule inside {module_dir / "OCCTSwift.swiftmodule"}'
    triple = f'{arch}-apple-macos{macos_deployment()}'
    modmap = REPO / 'Sources' / 'OCCTBridge' / 'include' / 'module.modulemap'
    if not modmap.is_file():
        return None, None, f'missing {modmap.relative_to(REPO)}'
    try:
        sdk = subprocess.run(['xcrun', '--show-sdk-path'], capture_output=True, text=True,
                             check=True).stdout.strip()
    except (OSError, subprocess.SubprocessError) as exc:
        return None, None, f'xcrun --show-sdk-path failed: {exc}'
    args = [
        '-target', triple,
        '-sdk', sdk,
        '-I', str(module_dir),
        '-I', str(module_dir / 'Modules'),
        '-Xcc', f'-fmodule-map-file={modmap}',
        '-Xcc', f'-I{modmap.parent}',
    ]
    return args, triple, None


class BlindRun(Exception):
    """A canary came back clean, so the compiler dropped work and the numbers mean nothing."""


def run_stage(mode, files, extra_args, outdir, canary_body, canaries, jobs, label, verbose,
              wmo=True):
    """Run one stage over `files`, chunked across processes, with a canary in every chunk.

    Returns {generated filename: [(generated line, message)]}. Raises `BlindRun` if any chunk's
    canary came back clean, which means that chunk's compiler dropped work.
    """
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
        results = {name: ('unparseable', errs)
                   for name, errs in map_to_source(parse_raw, index).items()}

        # Stage 2: type-check whatever parses.
        rest = [f for f in snippet_files if f.name not in results]
        if why_not is not None:
            for f in rest:
                results[f.name] = ('skipped', [])
            return results, f'type-check stage SKIPPED: {why_not}'

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
        print(f'  SKIPPED  compile cases: {why_not}')
        return 0, True
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
    return failures, False


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


def self_test():
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
    print('end-to-end compile:')
    compile_failures, skipped = _self_test_compile()
    failures += compile_failures
    total = (len(EXTRACT_CASES) + len(BODY_CASES) + len(HISTORICAL) + 6 + 2 + 2
             + (0 if skipped else 2 * len(COMPILE_CASES) + 2))
    print(f'\nself-test: {total - failures} passed, {failures} failed'
          + (' (compile cases SKIPPED: no built package)' if skipped else ''))
    return 1 if failures else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--self-test', action='store_true',
                    help='run the fixture battery instead of scanning the tree')
    ap.add_argument('--strict', action='store_true',
                    help='exit 1 on a non-compiling snippet (a census exits 0 by default)')
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
    ap.add_argument('--verbose', action='store_true', help='progress on stderr')
    args = ap.parse_args()

    if args.self_test:
        return self_test()

    blocks = collect(args.paths)
    if args.list:
        status = report(blocks, {}, show_fragments=args.fragments,
                        show_declarations=args.declarations)
        return status if args.strict else 0

    try:
        results, note = check(blocks, verbose=args.verbose, keep=args.keep,
                                  jobs=args.jobs)
    except BlindRun as exc:
        print(f'ABORTED: {exc}', file=sys.stderr)
        return 2
    if note:
        print(note)
    status = report(blocks, results, show_fragments=args.fragments,
                    show_declarations=args.declarations)
    if status and not args.strict:
        print('\nCENSUS: exiting 0. Run with --strict to fail on the above, and see this script\'s'
              '\n  docstring under "Where it lives" for what promotion to a gate needs.')
        return 0
    return status


if __name__ == '__main__':
    sys.exit(main())
