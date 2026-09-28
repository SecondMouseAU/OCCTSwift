#!/usr/bin/env python3
"""CENSUS, not a gate: #766 validity-matrix rows whose `File.swift:N` anchor does not resolve.

A row in `okf/references/766-test-validity/phase*/OCCT*Tests.md` carries the assertion that went red
under the injected defect, as `SomeTests.swift:42 abs(area - 6) < 1e-9`. That anchor is the cheapest
strong evidence that a red run actually happened: a row invented from the test's name cannot say
which line failed, and a row whose line number has drifted is pointing at whatever is there now.

Two tiers, because they are different claims:

  * **TEXT** - the quoted expectation appears at the named line (or within a few lines of it). The
    strong tier.
  * **ANCHOR** - some `#expect` / `#require` / `Issue.record` sits within three lines of the named
    line. The weak tier, and the one a stale line number fails.

A row failing ANCHOR is the finding. A row passing ANCHOR but failing TEXT is usually a paraphrase
(`toAnalyticalWithGap(... inverted ...) == nil`, `Issue recorded (line not recognized)`), which is
why TEXT cannot gate.

MEASURED, so the rate is known before anyone reads the output
-------------------------------------------------------------
Over `v5.0.0-766-execution` at 2026-09-28: 1,730 anchors across eight matrices. 1,642 pass ANCHOR,
64 fail it, 24 name a file that is absent or whose basename is ambiguous. TEXT passes on 1,033
exactly and 91 within the window; the rest are paraphrases. A 28% paraphrase class is why this
reports rather than gates, per `okf/policies/static-gates.md`.

NOT FOR `gate-scripts`
----------------------
The matrices live on `v5.0.0-766-execution`, not on `main`. `--require-matrices` turns a run over an
absent population into an error rather than a clean report (#2098's mode).

    python3 Scripts/census-766-matrix-line-refs.py
    python3 Scripts/census-766-matrix-line-refs.py --matrices <dir> --tests-root <dir> --summary
    python3 Scripts/census-766-matrix-line-refs.py --self-test
"""

from __future__ import annotations

import argparse
import glob
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
DEFAULT_MATRICES = os.path.join("okf", "references", "766-test-validity")
DEFAULT_TESTS = "Tests"

ANCHOR = re.compile(r"(?P<f>[A-Za-z0-9_+]+\.swift):(?P<n>\d+)(?P<rest>[^|]*)")
TICK = re.compile(r"`([^`]+)`")
ASSERTION = re.compile(r"#expect|#require|Issue\.record|withKnownIssue|XCTAssert")
LEADER = re.compile(r"^\s*(?:Expectation failed:|Red:|Green:)\s*")
IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]{3,}")
WINDOW = 3


def norm(s: str) -> str:
    return re.sub(r"\s+", " ", s.replace("`", "")).strip()


def index_tests(tests_root: str) -> dict[str, list[str]]:
    idx: dict[str, list[str]] = {}
    for base, _dirs, files in os.walk(tests_root):
        for fn in files:
            if fn.endswith(".swift"):
                idx.setdefault(fn, []).append(os.path.join(base, fn))
    return idx


def expectation_of(rest: str) -> str:
    """The expectation text a row quotes after its anchor: the backticked span, else the cell."""
    m = TICK.search(rest)
    return norm(LEADER.sub("", m.group(1) if m else rest))


def check_anchor(paths: list[str] | None, line_no: int, frag: str):
    """(verdict, detail) for one anchor. Verdicts: TEXT, TEXT-WINDOW, ANCHOR, plus the failures."""
    if not paths:
        return "file-absent", ""
    if len(paths) > 1:
        return "file-ambiguous", f"{len(paths)} files share that basename"
    src = open(paths[0], encoding="utf-8", errors="ignore").read().split("\n")
    if not 1 <= line_no <= len(src):
        return "line-out-of-range", f"the file has {len(src)} lines"
    window = [norm(x) for x in src[max(0, line_no - 1):line_no + WINDOW + 1]]
    if frag and frag in window[0]:
        return "TEXT", ""
    if frag and any(frag in w for w in window):
        return "TEXT-WINDOW", ""
    blob = " ".join(window)
    toks = IDENT.findall(frag)
    if toks and all(t in blob for t in toks):
        return "TEXT-WINDOW", "matched on identifiers, not the whole expression"
    near = "\n".join(src[max(0, line_no - 1 - WINDOW):line_no + WINDOW])
    if ASSERTION.search(near):
        return "ANCHOR", norm(src[line_no - 1])[:70]
    return "no-assertion-near-line", norm(src[line_no - 1])[:70]


def rows(matrices_dir: str):
    """Yield (matrix_basename, matrix_line, file_named, line_no, expectation) per anchor."""
    pattern = os.path.join(matrices_dir, "**", "*.md")
    for path in sorted(glob.glob(pattern, recursive=True)):
        for i, line in enumerate(open(path, encoding="utf-8", errors="ignore"), 1):
            if not line.startswith("|"):
                continue
            for m in ANCHOR.finditer(line):
                yield (os.path.basename(path), i, m.group("f"), int(m.group("n")),
                       expectation_of(m.group("rest")))


NAMES_A_FILE = re.compile(r"[A-Za-z0-9_+]+\.swift")
SEPARATOR = re.compile(r"^\|[\s:|-]+\|\s*$")


def anchorless_rows(matrices_dir: str):
    """Yield (matrix, line_no, text) for table rows that carry no resolvable anchor.

    This is the view assertion `okf/policies/static-gates.md` asks for. A row whose anchor is
    mistyped simply is not read, so the census would report a clean 9 of 9 over ten rows and the
    tenth would be invisible. Measured: PR #2629 carries
    `Issue1476CurveTypeOtherCurveFallbackTests.swiftline.curveType == 0`, a row that names a file,
    names no line, and was silently skipped.
    """
    pattern = os.path.join(matrices_dir, "**", "*.md")
    for path in sorted(glob.glob(pattern, recursive=True)):
        for i, line in enumerate(open(path, encoding="utf-8", errors="ignore"), 1):
            if not line.startswith("|") or SEPARATOR.match(line):
                continue
            if ANCHOR.search(line):
                continue
            if NAMES_A_FILE.search(line):
                yield os.path.basename(path), i, line.strip()[:120]


def census(args) -> int:
    matrices = args.matrices if os.path.isabs(args.matrices) else os.path.join(ROOT, args.matrices)
    tests = args.tests_root if os.path.isabs(args.tests_root) else os.path.join(ROOT,
                                                                               args.tests_root)
    idx = index_tests(tests)

    tally: dict[str, int] = {}
    findings = []
    for matrix, mline, fname, line_no, frag in rows(matrices):
        verdict, detail = check_anchor(idx.get(fname), line_no, frag)
        tally[verdict] = tally.get(verdict, 0) + 1
        if verdict in ("file-absent", "file-ambiguous", "line-out-of-range",
                       "no-assertion-near-line"):
            findings.append((matrix, mline, fname, line_no, frag, verdict, detail))

    anchorless = list(anchorless_rows(matrices))

    total = sum(tally.values())
    strong = tally.get("TEXT", 0) + tally.get("TEXT-WINDOW", 0)
    print("census-766-matrix-line-refs: validity-matrix anchors that resolve at the PR head")
    print(f"  test files indexed: {sum(len(v) for v in idx.values())}")
    print(f"  anchors read: {total}")
    print(f"  rows naming a .swift file with NO readable anchor: {len(anchorless)}")
    print(f"  TEXT   (expectation found at or near the named line): {strong}")
    print(f"  ANCHOR (an assertion within {WINDOW} lines, text is a paraphrase): "
          f"{tally.get('ANCHOR', 0)}")
    for k in ("no-assertion-near-line", "line-out-of-range", "file-ambiguous", "file-absent"):
        if tally.get(k):
            print(f"  {k}: {tally[k]}")

    if args.require_matrices and total == 0:
        print("  ERROR: --require-matrices and no anchor was examined. The matrices live on "
              "v5.0.0-766-execution; a clean report over an empty directory is a false green.",
              file=sys.stderr)
        return 2

    if anchorless and not args.summary:
        print()
        print("  rows naming a test file but no line, so nothing above examined them:")
        for matrix, mline, text in anchorless:
            print(f"  {matrix}:{mline}  {text}")

    if findings and not args.summary:
        print()
        for matrix, mline, fname, line_no, frag, verdict, detail in findings:
            print(f"  {matrix}:{mline}  -> {fname}:{line_no}  {verdict}")
            if frag:
                print(f"      row says: {frag[:90]}")
            if detail:
                print(f"      at head:  {detail}")
    if findings:
        print()
        print("  A row whose anchor names no assertion is not evidence that a red run happened.")
        print("  Adjudicate each: re-anchor the row, or withdraw the Red/Green claim.")
    return 0


def self_test() -> int:
    """Prove each verdict is reachable, and that a drifted line number is not read as a match."""
    import tempfile

    src = """import Testing

@Test func volumeIsRight() throws {
  let s = try #require(Shape.box(width: 2, height: 2, depth: 2))
  #expect(abs((s.volume ?? 0) - 8) < 1e-9)
}

// a comment, and nothing else, ten lines down
let filler1 = 1
let filler2 = 2
let filler3 = 3
let filler4 = 4
"""
    cases = []
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "BoxTests.swift")
        open(p, "w").write(src)
        idx = index_tests(d)
        one = idx["BoxTests.swift"]

        # 1. The expectation at the named line is the strong verdict.
        cases.append(("the quoted expectation at the named line is TEXT",
                      check_anchor(one, 5, "abs((s.volume ?? 0) - 8) < 1e-9")[0] == "TEXT"))

        # 2. A paraphrase over a real assertion is ANCHOR, not a finding.
        cases.append(("a paraphrase over a real assertion is ANCHOR",
                      check_anchor(one, 5, "volume is 8 (rounded)")[0] == "ANCHOR"))

        # 3. A line number pointing at filler is the finding. This is the drift case, and the one
        #    that matters: a stale anchor and a fabricated one look identical in the matrix.
        cases.append(("an anchor pointing at no assertion is reported",
                      check_anchor(one, 11, "abs(v - 8) < 1e-9")[0] == "no-assertion-near-line"))

        # 4. A line past the end of the file is reported rather than crashing.
        cases.append(("a line past the end of the file is reported",
                      check_anchor(one, 9999, "anything")[0] == "line-out-of-range"))

        # 5. An absent file is reported.
        cases.append(("an absent file is reported",
                      check_anchor(idx.get("NoSuchTests.swift"), 3, "x")[0] == "file-absent"))

        # 6. An ambiguous basename is reported rather than resolved to one of them. Two test
        #    targets do carry files of the same name on this branch.
        cases.append(("an ambiguous basename is reported",
                      check_anchor([p, p], 5, "x")[0] == "file-ambiguous"))

        # 7. An expectation split across lines is found in the window, not missed.
        multi = os.path.join(d, "WrapTests.swift")
        open(multi, "w").write("@Test func a() {\n  #expect(\n    abs(area - 6) < 1e-9\n  )\n}\n")
        cases.append(("an expectation wrapped onto the next line still matches",
                      check_anchor([multi], 2, "abs(area - 6) < 1e-9")[0] == "TEXT-WINDOW"))

    # 8. The row parser takes the backticked span rather than the whole cell, and strips the
    #    `Expectation failed:` leader the Stress matrix uses.
    cases.append(("the backticked span is the expectation",
                  expectation_of(" `abs(x - 1) < 1e-9` | pass |") == "abs(x - 1) < 1e-9"))
    cases.append(("the Expectation-failed leader is stripped",
                  expectation_of(" Expectation failed: abs(x - 1) < 1e-9 ") == "abs(x - 1) < 1e-9"))

    # 9. A non-table line carries no anchors, so prose mentioning a file and a line is ignored.
    with tempfile.TemporaryDirectory() as d:
        open(os.path.join(d, "m.md"), "w").write(
            "See FooTests.swift:12 for the detail.\n"
            "| a | FooTests.swift:12 `x == 1` | b |\n")
        got = list(rows(d))
        cases.append(("only table rows are read", len(got) == 1 and got[0][3] == 12))

    # 10. A row naming a file with no line is REPORTED rather than skipped. Without this the
    #     census would print `9 of 9 resolve` over ten rows and the tenth would be invisible,
    #     which is exactly the blindness static-gates.md warns about.
    with tempfile.TemporaryDirectory() as d:
        open(os.path.join(d, "m.md"), "w").write(
            "| a | b | `FooTests.swiftline.curveType == 0` | c |\n"
            "| a | b | `FooTests.swift:12 x == 1` | c |\n"
            "|---|---|---|---|\n"
            "| a | b | no file named here | c |\n")
        anchorless = list(anchorless_rows(d))
        cases.append(("a row naming a file but no line is reported",
                      len(anchorless) == 1 and "swiftline" in anchorless[0][2]))
        cases.append(("a separator row and a row naming no file are not reported",
                      all("---" not in a[2] for a in anchorless)))

    failures = 0
    for label, ok in cases:
        print(f"  {'PASS' if ok else 'FAIL'}  {label}")
        failures += 0 if ok else 1
    print(f"\n{len(cases) - failures}/{len(cases)} self-test cases pass")
    return 1 if failures else 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--matrices", default=DEFAULT_MATRICES)
    ap.add_argument("--tests-root", default=DEFAULT_TESTS)
    ap.add_argument("--summary", action="store_true")
    ap.add_argument("--require-matrices", action="store_true",
                    help="exit 2 rather than report clean when nothing was examined (#2098)")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    return self_test() if args.self_test else census(args)


if __name__ == "__main__":
    sys.exit(main())
