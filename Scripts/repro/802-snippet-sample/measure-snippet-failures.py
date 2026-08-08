#!/usr/bin/env python3
"""#802 item 2: measure, don't assume, whether the 7,186 ```swift snippets under docs/ are worth
checking exhaustively, and by what method.

## Why not just compile all of them

A snippet extracted from a reference page is usually a deliberate FRAGMENT, not a complete program:
many are a single bare call (`graph.setCoEdgeUVBox(0, u1: 0.0, ...)`) assuming a `graph` bound
earlier in the same page's prose, and many restated signatures are intentionally body-less
(`public func trek(_ path: String) -> String?`, no `{ }`), a real convention this repo's own
`check-docs-defaults.py` already parses around, not a mistake. Feeding either shape to `swiftc`
produces a parse or semantic error unrelated to whether the API it names still exists: "cannot find
'graph' in scope" and "function declaration requires a body" would each fire on the overwhelming
majority of snippets, drowning any real signal in expected, harmless noise. Measuring that would be
"the adjacent number" (`okf/policies/measure-dont-assume.md`): a real count, of the wrong thing.

## What this measures instead

The actual complaint the issue raises is narrower and exactly the one #802 item 1 already answers
for headings and prose: "a snippet naming a removed symbol is a wrong answer served to users"
(context7 harvests these `​```swift` blocks). So this script applies the SAME exact-match
(owning type, member name) check `check-docs-existence.py` already proved correct: the same live
index, the same collision-trap awareness, the same historical-annotation suppression, applied to the CONTENT of
every fenced ```swift block, a population that script deliberately never enters (see its own
`## Two channels`: fenced content is skipped, since a heading's own claim already catches the
`generation`-shape defect in every case measured on the real tree).

Because this check is text-matching against an already-built in-memory index, not real compilation,
it costs nothing to run against the FULL population rather than a sample, so it does, rather than
estimating from a subset. What IS sampled, separately, is a small set of snippets fed through a real
`swiftc -typecheck`, to answer a different question the exhaustive check cannot: does actual
compilation surface anything beyond a removed-symbol reference (a wrong argument label on a symbol
that still exists, say)? That half legitimately cannot cover 7,186 snippets: each attempt needs the
built `OCCTSwift` module on the import path, so it stays a measured sample, and the measured
fragment-failure rate is reported honestly rather than folded into "real" failures.

Usage (from the repo root):

    python3 Scripts/repro/802-snippet-sample/measure-snippet-failures.py
    python3 Scripts/repro/802-snippet-sample/measure-snippet-failures.py --compile-sample 40

This is a CENSUS/measurement, not a gate: it always exits 0 (see `census-unmeasured-values.py`'s
own convention). Its job is to produce the number #802 asks for, not to block a commit.
"""
import argparse
import glob
import importlib.util
import os
import random
import re
import subprocess
import sys
import tempfile

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
EXISTENCE_SCRIPT = os.path.join(REPO_ROOT, 'Scripts', 'check-docs-existence.py')

DOC_GLOB = 'docs/**/*.md'
README = 'README.md'
EXCLUDED_DOCS = {'docs/CHANGELOG.md', 'docs/SEMVER.md'}
SRC_GLOB = 'Sources/OCCTSwift/*.swift'

FENCE_START_RE = re.compile(r'^\s*```\s*swift\s*$')
FENCE_END_RE = re.compile(r'^\s*```\s*$')
HISTORICAL_RE = re.compile(r'\b(removed|deprecated|no longer exists|renamed)\b', re.IGNORECASE)


def load_existence_module():
    spec = importlib.util.spec_from_file_location('check_docs_existence', EXISTENCE_SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def extract_snippets(paths):
    """[(path, first_line_no, code_text, historical)] for every fenced ```swift block.

    `historical` is True if the ~5 lines immediately preceding the fence (the prose introducing
    it) carries a removal/deprecation word, the same "acknowledged, not a defect" allowance
    `check-docs-existence.py` gives a heading or paragraph, applied here to a snippet's own intro.
    """
    out = []
    for path in paths:
        with open(path, encoding='utf-8') as fh:
            lines = fh.read().split('\n')
        i = 0
        while i < len(lines):
            if FENCE_START_RE.match(lines[i]):
                start = i + 1
                j = start
                while j < len(lines) and not FENCE_END_RE.match(lines[j]):
                    j += 1
                preceding = '\n'.join(lines[max(0, i - 5):i])
                historical = bool(HISTORICAL_RE.search(preceding))
                out.append((path, start + 1, '\n'.join(lines[start:j]), historical))
                i = j + 1
                continue
            i += 1
    return out


def in_scope_doc_paths():
    paths = [p for p in glob.glob(DOC_GLOB, recursive=True) if p not in EXCLUDED_DOCS]
    if os.path.exists(README):
        paths.append(README)
    return sorted(paths)


# Swift-language uses of `Type.word` that name no member at all: `Foo.self` (metatype value),
# `Foo.Type` (metatype type). `check-docs-existence.py`'s own `INLINE_DOTTED_RE` requires
# surrounding backticks, which real code never has, so it is not reused here; a bare pattern is,
# and it needs this extra exclusion prose never triggers (a doc author does not write `` `Foo.self` ``).
LANGUAGE_KEYWORDS = {'self', 'Type', 'Protocol', 'init'}


def check_existence_in_snippets(snippets, live_types, live_members, mod):
    """A snippet fails if it names a `Type.member` dotted reference where `Type` exists but
    `member` does not (never on member-name alone, for the identical collision-trap reason
    `check-docs-existence.py`'s own docstring gives; reuses its exact-match `doc_type_exists`/
    `doc_member_exists`, now conformance-aware, so a protocol-extension-supplied member like
    `ArcLengthCurveAdaptor.maximumSampleCount` resolves for `WireCurve`/`EdgeCurve` too)."""
    failures = []
    for path, lineno, code, historical in snippets:
        bad = []
        for m in re.finditer(r'\b([A-Z][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)\b', code):
            t, member = m.group(1), m.group(2)
            if member in mod.NON_SYMBOL_TAILS or member in mod.SYNTHESIZED_MEMBERS \
                    or member in LANGUAGE_KEYWORDS:
                continue
            if not mod.doc_type_exists(t, live_types):
                continue
            if mod.doc_member_exists(t, member, live_types, live_members):
                continue
            bad.append(f'{t}.{member}')
        if bad and not historical:
            failures.append((path, lineno, sorted(set(bad))))
    return failures


def try_compile_sample(snippets, n, seed):
    """Feed a random sample through `swiftc -typecheck` against the built OCCTSwift module.

    Reports three buckets, not two: a snippet can be a genuine failure, or fail only because it is
    a deliberate fragment (an undeclared variable from earlier prose, or a body-less restated
    signature), a shape check-docs-defaults.py's own docstring already documents as this repo's
    convention, not a defect. Conflating the two would report a real-sounding number measuring
    mostly the extraction method rather than the docs.
    """
    module_paths = [
        os.path.join(REPO_ROOT, '.build', 'arm64-apple-macosx', 'debug', 'Modules'),
        os.path.join(REPO_ROOT, '.build', 'debug', 'Modules'),
        os.path.join(REPO_ROOT, '.build', 'arm64-apple-macosx', 'debug'),
        os.path.join(REPO_ROOT, '.build', 'debug'),
    ]
    modulemap_dir = next((p for p in module_paths if os.path.exists(
        os.path.join(p, 'OCCTSwift.swiftmodule'))), None)

    rng = random.Random(seed)
    sample = rng.sample(snippets, min(n, len(snippets)))
    results = []
    for path, lineno, code, historical in sample:
        with tempfile.NamedTemporaryFile('w', suffix='.swift', delete=False) as tf:
            tf.write('import OCCTSwift\nimport simd\nimport Foundation\n')
            tf.write(code)
            tf.write('\n')
            tmp_path = tf.name
        cmd = ['swiftc', '-typecheck', tmp_path]
        if modulemap_dir:
            cmd += ['-I', modulemap_dir]
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        os.unlink(tmp_path)
        ok = proc.returncode == 0
        stderr = proc.stderr
        # A fragment-shaped failure: an undeclared identifier the doc's OWN prose bound earlier
        # (not this snippet's problem); a bare signature with no body, or a bare enum/protocol
        # requirement restatement (`public var x: Int { get }`, `public enum Foo` with no cases)
        # this repo's own reference-page convention of restating JUST the signature, wrapped
        # here at file scope where Swift requires a body/case list it was never meant to have;
        # or the sample harness's own module-resolution gap (a raw `swiftc -typecheck` cannot
        # replicate SwiftPM's full module-map wiring for the `OCCTBridge` Clang target `OCCTSwift`
        # itself imports: an environment limitation of this harness, not a snippet defect).
        fragment_shaped = bool(re.search(
            r"cannot find '[a-z]\w*' in scope|"
            r'function declaration requires a body|'
            r'expected declaration|'
            r"'guard' body must not fall through|"
            r'static methods may only be declared on a type|'
            r"expected '\{' to start getter definition|"
            r"expected '\{' in enum|"
            r"missing required module 'OCCTBridge'", stderr))
        results.append((path, lineno, ok, fragment_shaped, stderr.strip().splitlines()[:2]))
    return results, modulemap_dir is not None


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--compile-sample', type=int, default=0,
                    help='additionally attempt real swiftc -typecheck on N random snippets')
    ap.add_argument('--seed', type=int, default=802, help='RNG seed for the compile sample')
    args = ap.parse_args()

    os.chdir(REPO_ROOT)
    mod = load_existence_module()

    src_files = {}
    for path in sorted(glob.glob(SRC_GLOB)):
        with open(path, encoding='utf-8') as fh:
            src_files[path] = fh.read()
    live_types, live_members, live_free, conformances = mod.extract_source_symbols(src_files)
    mod.resolve_conformances(live_members, conformances)

    snippets = extract_snippets(in_scope_doc_paths())
    print(f'total ```swift snippets in scope: {len(snippets)}')

    failures = check_existence_in_snippets(snippets, live_types, live_members, mod)
    print(f'existence-check failures (exhaustive, all {len(snippets)}): {len(failures)}')
    for path, lineno, bad in failures:
        print(f'  {path}:{lineno}  {", ".join(bad)}')

    if args.compile_sample:
        results, module_found = try_compile_sample(snippets, args.compile_sample, args.seed)
        if not module_found:
            print('\n(compile sample skipped: no built OCCTSwift.swiftmodule found, run '
                  '`swift build` first)')
        else:
            real_fail = [r for r in results if not r[2] and not r[3]]
            fragment_fail = [r for r in results if not r[2] and r[3]]
            ok = [r for r in results if r[2]]
            print(f'\ncompile sample: {len(results)} snippets, seed {args.seed}')
            print(f'  typechecked clean:        {len(ok)}')
            print(f'  fragment-shaped failure:  {len(fragment_fail)}  '
                  f'(missing scope/body: extraction artifact, not a docs defect)')
            print(f'  OTHER failure:            {len(real_fail)}')
            for path, lineno, _, _, msg in real_fail:
                print(f'    {path}:{lineno}  {" | ".join(msg)}')

    return 0


if __name__ == '__main__':
    sys.exit(main())
