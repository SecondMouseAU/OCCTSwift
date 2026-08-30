#!/usr/bin/env python3
"""Issue #815 (Pass 5a of #807): refman coverage census for TESTS, geometry primitives lane.

WHY THIS PASS IS DIFFERENT FROM #808/#809/#810/#811/#812/#813. Every prior #807 pass asks whether
SOURCE (a wrapped operation, a doc claim) matches the refman. #815 and its three siblings (5b/5c/5d)
ask the same question about TESTS: for a documented, wrapped capability, does any test actually
exercise it (under-coverage), and does any test assert something the refman does not actually
promise (over-coverage)? #815's own issue body names the lane by TEST TARGET
(`OCCTCurveTests`/`OCCTGeom2dTests`/`OCCTSurfaceTests`/`OCCTMathTests`), not by OCCT package, and
says explicitly to mirror "Pass 1a's source surface" -- but #380 (Pass 1a) was a DUPLICATION audit,
not a refman-coverage one, so unlike Pass 4a-4d there is no committed "documented?/wrapped?" class
table to inherit. `derive_lane.py` next to this file IS that missing derivation, built fresh by
call rather than assumed from #380's file list (two of #380's 16 files, `BRepGraph.swift` and
`MedialAxis.swift`, measurably belong to OTHER test targets and are correctly excluded; the real
lane also reaches 30+ files #380 never named, `MathSolver.swift`/`MathLibrary.swift`/
`GeomPrimitives.swift`/`Continuity.swift`/... because #380 was never asked to be exhaustive over
"geometry primitives", only over accidental duplication in the eleven files it happened to name).

WRAPPED IS TRIVIALLY TRUE HERE, UNLIKE #808-#813. Their lane is "every class an OCCT package
declares", so most of the work is deciding whether an unwrapped class is a real gap or a recorded
one (their `CURATED` tables of `ABSTRACT_BASES`/`ENUMS_UNWRAPPED`/etc.). This lane is derived FROM
an actual bridge call a lane Swift member makes, so every entry already IS wrapped by construction.
The only two questions left are the ones #815's own issue body asks: documented? and tested?

THE CENSUS UNIT IS THE MEMBER, NOT THE CLASS, AND THAT IS A DELIBERATE DEPARTURE FROM #808-#813.
"An OCCT behaviour ... which no test exercises" is a per-CAPABILITY question. `derive_lane.py`'s
own class table (`lane_class_table`) is class-level and kept only as descriptive context: `Curve3D`
alone is reached by 832 references across `OCCTCurveTests`, so asking "is `Geom_Curve` (the class
underlying nearly every Curve3D method) tested" is true almost by definition and would hide the
real finding. `lane_members()` walks every one of the lane's ~1,290 members (including 31 nested
`NativeHandleView` property structs like `Curve2D.CircleProperties` that a file-scope-only type
scan cannot see on its own, see `derive_lane.py`'s own docstring) and asks the question at THAT
grain: does the test suite exercise THIS specific method or property.

TWO REAL, SUBSTANTIVE CORRECTIONS THIS PASS MADE TO ITS OWN FIRST DRAFT, BOTH FOUND BY MEASURING
RATHER THAN TRUSTING THE FIRST NUMBER PRINTED:

  1. `reachable()` (`check-bridge-index.py`, reused by #811/#928 for a DIFFERENT, more permissive
     question) is UNSOUND for "which OCCT class does this member represent": its own
     helper-by-bare-name expansion resolved `Curve3D.adjustEndpoints` (a five-line function that
     constructs exactly `ShapeConstruct_Curve` and `gp_Pnt`) to also include `TDocStd_Document`,
     `XCAFDoc_ShapeTool`, `TDF_Label`, because the OCCT `Handle(Geom_Curve)` macro token, present
     in nearly every function that touches a handle-based type, happens to also be the literal
     name of an unrelated OCAF helper in `OCCTBridge_Internal.h`. `derive_lane.py`'s `bridge_reach()`
     reimplements `reachable()`'s safe half (a function reaches what its own wrapper struct holds)
     and drops the unsafe half. See that function's own docstring for the full trace.
  2. The first cut of the "tested?" check only searched the FOUR lane targets' own source, and 29
     of its 42 "candidates" (as of the second correction, below) were real capabilities tested
     CORRECTLY in a different target (`OCCTAnalysisTests`'s differential-geometry batch suites,
     `OCCTShapeHealingTests`), following this repo's own Test Layout convention of filing a suite
     under "the domain target that best matches it". Reporting those as `under` would have been a
     defect IN THE CHECK, not a gap in the tree. `lane_members()` now computes both `tested` (the
     four-target question #815's own `## Lane` literally poses) and `tested_anywhere` (the actual
     under-coverage question); only the latter drives a verdict here.

THE 13 REAL FINDINGS THIS PASS MADE AND FIXED, all documented+wrapped capabilities with
`tested_anywhere=False` before this branch, now `True`, each proved to fail first (`prove-the-test-
fails.md`) by breaking the Swift wrapper, confirming the new test alone failed, and restoring:

  `Curve3D.d2`, `Curve3D.bsplineSetKnot`, `Curve2D.d2`, `Curve2D.allExtrema`,
  `Curve2D.selfIntersections`, `OCCTPrecision.infinite`, `OCCTPrecision.pConfusion`,
  `Surface.bsplineSetUKnot`, `Surface.bsplineSetVKnot`, `Surface.bsplineRemoveUKnot`,
  `Surface.bsplineIncreaseVMultiplicity`, `Surface.isUClosed`, `Surface.isVClosed`.

See the README for the full evidence per finding. `KNOWN_FIXED_MEMBERS` below pins them: the
regression check fails if any reverts to `tested_anywhere=False`.

ONE OVER-COVERAGE FINDING: `Tests/OCCTSurfaceTests/SurfaceAnalyticTests.swift`'s `sphereProperties()`
said "Sphere is U-periodic (wraps around) and V-closed (pole to pole)". The pinned kernel's own
header comment on `Geom_SphericalSurface::IsVClosed()` says "Returns False.": the poles are
DEGENERATE points, not a matching pair of points at the two ends of the V range, which is what
`IsVClosed()` actually tests for. Fixed in the same branch (a wrong comment, not a wrong
assertion: the test made no claim to correct).

Run from anywhere (paths derive from this file's location, not the cwd):

    python3 Scripts/repro/815-refman-coverage-tests-geometry/refman_census.py
    python3 Scripts/repro/815-refman-coverage-tests-geometry/refman_census.py --verbose
    python3 Scripts/repro/815-refman-coverage-tests-geometry/refman_census.py --self-test

Exits 1 on: a documented+wrapped member with `tested_anywhere=False` (a genuine `under`), a
`KNOWN_FIXED_MEMBERS` regression, or an `OVER_FINDINGS` regression. Exits 0 otherwise.
"""

from __future__ import annotations

import argparse
import collections
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import derive_lane as dl  # noqa: E402

ROOT = dl.ROOT
DOCS_DIR = os.path.join(ROOT, "docs")
GAPS_FILE = os.path.join(DOCS_DIR, "occtswift-wrapping-gaps.md")


# ------------------------------------------------------------------------------------------------
# The 13 real findings, pinned. Each is a (type, member name) pair that was `tested_anywhere=False`
# before this pass and must stay `True`. Kept as data (not just "the count is 13 in prose") so a
# regression names exactly which capability lost its test, the same shape #811's
# `KNOWN_OVER_FINDINGS` uses for the opposite direction (a wrong string that must stay absent).
# ------------------------------------------------------------------------------------------------

KNOWN_FIXED_MEMBERS: list[tuple[str, str]] = [
    ("Curve3D", "d2"),
    ("Curve3D", "bsplineSetKnot"),
    ("Curve2D", "d2"),
    ("Curve2D", "allExtrema"),
    ("Curve2D", "selfIntersections"),
    ("OCCTPrecision", "infinite"),
    ("OCCTPrecision", "pConfusion"),
    ("Surface", "bsplineSetUKnot"),
    ("Surface", "bsplineSetVKnot"),
    ("Surface", "bsplineRemoveUKnot"),
    ("Surface", "bsplineIncreaseVMultiplicity"),
    ("Surface", "isUClosed"),
    ("Surface", "isVClosed"),
]

# The one over-coverage finding: the WRONG text `sphereProperties()` used to carry. Checked for
# absence in the working tree, same idiom as #808/#810/#811's `KNOWN_OVER_FINDINGS`.
OVER_FINDINGS: list[tuple[str, str]] = [
    ("Tests/OCCTSurfaceTests/SurfaceAnalyticTests.swift",
     "Sphere is U-periodic (wraps around) and V-closed (pole to pole)"),
]

# `Curve3D`/`Curve2D`/`OCCTPrecision` aren't in `dl.LANE_TARGETS`'s file (`OCCTPrecision` IS a
# top-level lane member from `OCCTPrecision.swift`); `Surface` is. Nested-view compound names
# (`Curve2D.CircleProperties`) never appear in this pinned list, so no special-casing is needed
# for them here.


def _read(path: str) -> str:
    with open(path, errors="ignore") as fh:
        return fh.read()


# ------------------------------------------------------------------------------------------------
# Classification
# ------------------------------------------------------------------------------------------------

def recorded_in_gaps(name: str, gaps_text: str) -> bool:
    return bool(re.search(r"\b" + re.escape(re.split(r"\.", name)[-1]) + r"\b", gaps_text))


def classify(member: dict, gaps_text: str) -> str:
    """Verdict for one lane member. Only documented+wrapped members are asked the question at all
    (an undocumented member isn't the shape #815 defines: "documented, which we wrap AND
    document"), matching the ordering #808/#810/#811 use: wrapped is checked first (trivially true
    here, since every member is derived from a real call), then documented, then tested.
    """
    if not member["bridge_calls"]:
        return "pure-swift"  # not an OCCT behaviour at all: no bridge call in this member's body
    documented = bool(member["doc"].strip())
    if not documented:
        return "undocumented"
    if member["tested_anywhere"] is True:
        return "ok"
    if member["tested_anywhere"] is False:
        if recorded_in_gaps(f"{member['type']}.{member['name']}", gaps_text):
            return "deliberate, recorded"
        return "under"
    return "inconclusive"  # tested_anywhere is None: generic/overloaded name, needs a human


def check_known_fixed(members: list[dict]) -> list[str]:
    by_key = {(m["type"], m["name"]): m for m in members}
    msgs = []
    for ty, name in KNOWN_FIXED_MEMBERS:
        m = by_key.get((ty, name))
        if m is None:
            msgs.append(f"{ty}.{name}: no longer found in the derived lane at all "
                        "(renamed or removed?)")
            continue
        if m["tested_anywhere"] is not True:
            msgs.append(f"{ty}.{name}: REGRESSED to tested_anywhere={m['tested_anywhere']!r} "
                        "(was fixed by #815, now untested again)")
    return msgs


def check_over_findings() -> list[str]:
    msgs = []
    for rel, wrong in OVER_FINDINGS:
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            msgs.append(f"{rel}: file is gone, so its pinned finding cannot be checked")
            continue
        if wrong in _read(path):
            msgs.append(f"{rel}: {wrong}")
    return msgs


# ------------------------------------------------------------------------------------------------
# Self-test. Each accepting shape `member_test_status`/`_call_pattern` recognise gets a case
# proving it is load-bearing (okf/policies/prove-the-test-fails.md): remove the shape, the case
# must fail. `selftest_removal_matrix.py` next to this file automates switching each shape off in
# turn and printing the fallout, following #811's own precedent for a `classify()`/detector with
# more than one accepting shape.
# ------------------------------------------------------------------------------------------------

SELF_TEST_CASES: list[tuple[str, dict, str, bool | None, str]] = [
    # NOT `length`/`value`/etc: those are deliberately on GENERIC_MEMBER_NAMES (see the dedicated
    # valve case below), and using one here would silently test the wrong shape.
    ("Widget", {"name": "radius", "kind": "var", "static": False},
     "let w = Widget(); print(w.radius)", True,
     "instance property access, `.name` with no parens"),
    ("Widget", {"name": "frobnicate", "kind": "func", "static": False},
     "widget.frobnicate(x: 3)", True,
     "instance method call, `.name(`"),
    ("Widget", {"name": "make", "kind": "func", "static": True},
     "Widget.make(from: poles)", True,
     "static method call, qualified by the type name"),
    ("Widget", {"name": "maxDegree", "kind": "var", "static": True},
     "Widget.maxDegree", True,
     "static property access, qualified by the type name"),
    ("Widget", {"name": "init", "kind": "init", "static": False},
     "Widget(handle: h)", True,
     "initializer call, bare `TypeName(`"),
    ("Widget", {"name": "frobnicate", "kind": "func", "static": False},
     "widget.somethingElse(x: 3)", False,
     "the negative: searched, genuinely not present"),
]

GENERIC_TEST_CASE = ("Widget", {"name": "value", "kind": "var", "static": False},
                     "let w = Widget(); print(w.value)")
FANOUT_TEST_CASE = ("Odd", "Ball", {"name": "shared", "kind": "func", "static": False},
                    "odd.shared()", "ball.shared()")


def run_self_test() -> int:
    failed = 0
    total = 0
    print(f"self-test, member_test_status: {len(SELF_TEST_CASES)} cases")
    for type_name, member, text, expected, why in SELF_TEST_CASES:
        total += 1
        got = dl.member_test_status(type_name, member, text, {})
        ok = got is expected
        print(f"  {'PASS' if ok else 'FAIL'}  {type_name}.{member['name']} -> {got}: {why}")
        if not ok:
            failed += 1

    print(f"\nself-test, GENERIC_MEMBER_NAMES valve: 1 case")
    total += 1
    ty, member, text = GENERIC_TEST_CASE
    got = dl.member_test_status(ty, member, text, {})
    ok = got is None
    print(f"  {'PASS' if ok else 'FAIL'}  a call site for `value` exists, but the name is on the "
          f"generic blocklist -> {got} (must be None, not True)")
    if not ok:
        failed += 1

    print(f"\nself-test, OVERLOAD_FANOUT valve: 1 case")
    total += 1
    ty1, ty2, member, text1, text2 = FANOUT_TEST_CASE
    fanout = {"shared": dl.OVERLOAD_FANOUT + 1}
    combined = text1 + "\n" + text2
    got = dl.member_test_status(ty1, member, combined, fanout)
    ok = got is None
    print(f"  {'PASS' if ok else 'FAIL'}  a name shared by more lane types than the fanout "
          f"threshold -> {got} (must be None even though a call site exists)")
    if not ok:
        failed += 1

    print(f"\nself-test, classify(): 4 cases")
    gaps_text = "some other class, not this one"
    cases = [
        ({"bridge_calls": [], "doc": "/// doc", "tested_anywhere": True, "type": "T", "name": "n"},
         "pure-swift", "no bridge call at all -> excluded from the question entirely"),
        ({"bridge_calls": ["OCCTFoo"], "doc": "", "tested_anywhere": True, "type": "T", "name": "n"},
         "undocumented", "wrapped, tested, but has no /// doc comment -> not #815's shape"),
        ({"bridge_calls": ["OCCTFoo"], "doc": "/// doc", "tested_anywhere": False,
          "type": "T", "name": "n"},
         "under", "documented+wrapped+untested, no gaps.md reason -> the real finding shape"),
        ({"bridge_calls": ["OCCTFoo"], "doc": "/// doc", "tested_anywhere": None,
          "type": "T", "name": "n"},
         "inconclusive", "ambiguous name -> neither ok nor under, needs a human"),
    ]
    for member, expected, why in cases:
        total += 1
        got = classify(member, gaps_text)
        ok = got == expected
        print(f"  {'PASS' if ok else 'FAIL'}  {why} -> {got}")
        if not ok:
            failed += 1

    print(f"\nself-test, regression checks report the injected defect:")
    total += 1
    # A complete fake roster (all 13 pinned members present and True) with exactly ONE flipped to
    # False, so the checker's report isolates that one entry rather than also reporting the other
    # twelve as "missing" (which would be correct behaviour for a genuinely incomplete roster, but
    # proves nothing about THIS check: the point here is detecting a REGRESSION, not an absence).
    fake_members = [{"type": ty, "name": name, "tested_anywhere": True}
                    for ty, name in KNOWN_FIXED_MEMBERS]
    fake_members[0]["tested_anywhere"] = False  # ("Curve3D", "d2")
    msgs = check_known_fixed(fake_members)
    ok = len(msgs) == 1 and "Curve3D.d2" in msgs[0] and "REGRESSED" in msgs[0]
    print(f"  {'PASS' if ok else 'FAIL'}  exactly the flipped entry is reported, the other 12 "
          f"stay silent: {msgs}")
    if not ok:
        failed += 1

    print(f"\nself-test, regression check also catches a DISAPPEARED member (not just a flip):")
    total += 1
    fake_members2 = [{"type": ty, "name": name, "tested_anywhere": True}
                     for ty, name in KNOWN_FIXED_MEMBERS[1:]]  # drop the first entry entirely
    msgs2 = check_known_fixed(fake_members2)
    ok2 = len(msgs2) == 1 and "no longer found" in msgs2[0]
    print(f"  {'PASS' if ok2 else 'FAIL'}  a member removed outright (renamed, deleted) is "
          f"reported too: {msgs2}")
    if not ok2:
        failed += 1

    print(f"\nself-test, over-coverage regression check reports a reappeared wrong claim:")
    total += 1
    import tempfile
    global ROOT
    with tempfile.TemporaryDirectory() as td:
        rel = "Tests/OCCTSurfaceTests/SurfaceAnalyticTests.swift"
        full = os.path.join(td, rel)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w") as fh:
            fh.write("// " + OVER_FINDINGS[0][1] + "\n")
        saved_root = ROOT
        ROOT = td
        try:
            over_msgs = check_over_findings()
        finally:
            ROOT = saved_root
    ok = len(over_msgs) == 1
    print(f"  {'PASS' if ok else 'FAIL'}  the pinned wrong sphere comment reappearing is "
          f"reported: {over_msgs}")
    if not ok:
        failed += 1

    print(f"\n{total - failed} passed, {failed} failed")
    return 1 if failed else 0


# ------------------------------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser(description="#815 refman coverage census, geometry primitives "
                                             "tests lane")
    ap.add_argument("--verbose", action="store_true", help="print every member, not just non-ok")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()

    if args.self_test:
        return run_self_test()

    exit_code = 0

    lane_types, ambiguous, all_types = dl.derive_lane_types()
    prefixes, bare = dl.load_packages()
    reach = dl.bridge_reach()
    swift_texts = dl.all_swift_texts()
    members = dl.lane_members(lane_types, reach, prefixes, bare, swift_texts)
    gaps_text = _read(GAPS_FILE) if os.path.exists(GAPS_FILE) else ""

    tally = collections.Counter()
    unders = []
    for m in members:
        verdict = classify(m, gaps_text)
        m["verdict"] = verdict
        tally[verdict] += 1
        if verdict == "under":
            unders.append(m)

    print(f"#815 geometry-primitives TEST lane: {len(members)} members across "
          f"{len(set(m['type'] for m in members))} types (including nested property views)")
    print()
    print("verdicts:")
    for k in ("ok", "under", "deliberate, recorded", "inconclusive", "undocumented", "pure-swift"):
        print(f"  {k:<22} {tally[k]}")

    if args.verbose:
        print()
        for m in sorted(members, key=lambda m: (m["verdict"], m["target"], m["type"], m["name"])):
            if m["verdict"] in ("ok", "pure-swift"):
                continue
            print(f"  {m['verdict']:<18} {m['target']:<18} {m['type']:<30} .{m['name']}")

    if unders:
        print()
        print("UNDER-COVERAGE (documented+wrapped, no test anywhere exercises it):")
        for m in unders:
            print(f"  {m['type']}.{m['name']} ({m['target']}) -> "
                  f"{', '.join(sorted(m['classes'])) or '(class unresolved)'}")
        exit_code = 1

    print()
    reg = check_known_fixed(members)
    if reg:
        print("REGRESSION in the 13 findings this pass fixed:")
        for msg in reg:
            print(f"  {msg}")
        exit_code = 1
    else:
        print(f"all {len(KNOWN_FIXED_MEMBERS)} previously-fixed findings still tested_anywhere=True")

    print()
    over = check_over_findings()
    if over:
        print("OVER-COVERAGE REGRESSION (a corrected claim has reappeared):")
        for msg in over:
            print(f"  {msg}")
        exit_code = 1
    else:
        print(f"the {len(OVER_FINDINGS)} corrected over-coverage finding has not reappeared")

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
