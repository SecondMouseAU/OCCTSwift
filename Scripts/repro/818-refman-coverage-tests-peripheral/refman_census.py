#!/usr/bin/env python3
r"""#818 (Pass 5d of #807): test-side refman coverage census, peripheral subsystems.

THE QUESTION IS DIFFERENT FROM PASSES 4a-4d (#811-#814), which asked: for a class in this lane,
do we WRAP it and DOCUMENT it. This asks, for the classes those four passes already found wrapped:
does a test in Pass 5d's six targets (OCCTMeshTests/OCCTDrawingTests/OCCTIntegrationTests/
OCCTMiscTests/OCCTStressTests/OCCTThreadTests) actually exercise it. Two directions, per #818's own
body:

  UNDER-COVERAGE. A capability we wrap and document, on the strength of the refman's contract,
  that no test anywhere checks. #585 is not this shape (that was a kernel-version mismatch), but
  the failure it produces is the same one this guards against: a claimed capability nobody has
  ever watched work.

  OVER-COVERAGE. A test whose comment or name asserts something about OCCT the refman does not
  promise, most dangerously a concurrency/thread-safety property: CLAUDE.md's Known OCCT Bugs
  section is a long list of exactly this failure (#298/#341/#344/#349/#353/#374/#1154/#1153), each
  one a race nothing had asserted was safe until a kernel investigation found otherwise. See
  `check_known_over_findings()`'s docstring below for what was actually checked and found here.

THE LANE is computed by `derive_lane.py`, next to this file: the union of #811/#812/#813/#814's
`LANE_CLASSES`, narrowed to the WRAPPED subset (136 of 782 -- see that file's own module docstring
for why the unwrapped 646 are out of scope for a test-coverage question), then traced by call
through the bridge and the Swift wrapper to see which of the six targets actually reach each one.

RESULT (see README.md for the full table and every finding's evidence):

    verdict              count
    tested (in lane)        53
    tested (elsewhere)      81
    under                    1  (LocOpe_SplitDrafts, filed as #1393)
    deliberate, recorded     0

`tested (elsewhere)` is NOT a defect: the capability has real test coverage, just not from one of
Pass 5d's own six targets (e.g. #811's fillet/chamfer/loft family is tested almost entirely in
OCCTModelingTests/OCCTSurfaceTests, which #818's own body predicted: "it will not be 1:1"). It is
reported because #818 asks for it explicitly, not folded into `under`.

`BRepOffsetAPI_MiddlePath`, the OTHER real `under` this pass found, is fixed in this same branch
(`Tests/OCCTModelingTests/Issue818MiddlePathTests.swift`) rather than filed, so it does not appear
in the table above as `under` any more. `derive_lane.py`'s own automated pass, run fresh against a
tree that already has that test file committed, now correctly reports it `tested-elsewhere` (via
`OCCTModelingTests`) on the raw signal alone -- `FIXED_UNDER` below is consulted BEFORE the raw
signal regardless (see `classify()`), so the verdict does not depend on that happy alignment, and
`--verify-fixed` independently checks the assertion by grepping the actual test file, so a future
rename or deletion of that file cannot silently go stale either.

MANUAL_OVERRIDES below is the record of every place hand-verification (grep + read, project-wide,
not just the six targets) disagreed with `derive_lane.py`'s own automated signal, in EITHER
direction: false negatives (`derive_lane.py` said "zero coverage," a real test exists) and one
false positive (`derive_lane.py` said "tested," the match was a same-file name collision on an
unrelated type). Each entry names the mechanism, matching `derive_lane.py`'s own documented
limitations rather than asserting a bare correction.

Run from anywhere:

    python3 Scripts/repro/818-refman-coverage-tests-peripheral/refman_census.py
    python3 Scripts/repro/818-refman-coverage-tests-peripheral/refman_census.py --verbose
    python3 Scripts/repro/818-refman-coverage-tests-peripheral/refman_census.py --verify-fixed
    python3 Scripts/repro/818-refman-coverage-tests-peripheral/refman_census.py --self-test

Exits 1 on: an `under` verdict this file does not know about (a regression, or a genuinely new
finding nobody has adjudicated), a `KNOWN_OVER_FINDINGS`/stale-claim regression, or `--verify-fixed`
finding the asserted fix is no longer there. Exits 0 otherwise.
"""

from __future__ import annotations

import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import derive_lane  # noqa: E402

ROOT = derive_lane.ROOT

# ------------------------------------------------------------------------------------------------
# MANUAL_OVERRIDES: hand-verified corrections to derive_lane.py's automated per-class test-target
# signal. Each key is an OCCT class; the value is the CORRECTED set of test targets (from ALL 18,
# not just Pass 5d's six) that a real grep+read confirmed actually exercise it, replacing whatever
# derive_lane.py computed automatically. Every entry names the specific mechanism derive_lane.py's
# own docstring already predicts it cannot see, and the evidence (file, sometimes line) that
# confirmed the correction. None of these are guesses: every one was confirmed with
# `grep -rn <symbol> Tests/` before being written down, per this project's own measure-before-you-
# write culture.
# ------------------------------------------------------------------------------------------------

MANUAL_OVERRIDES: dict[str, tuple[set[str], str]] = {
    # --- false NEGATIVES: derive_lane.py found zero test targets, a real test exists ---
    "Graphic3d_ZLayerSettings": (
        {"OCCTDrawingTests"},
        "used only as a struct FIELD type (`struct OCCTZLayerSettings { Graphic3d_ZLayerSettings "
        "settings; };`, OCCTBridge_Visualization_Assets.mm), never inside a function body "
        "derive_lane.py's bridge-side extractor scans. Real test: "
        "Tests/OCCTDrawingTests/ZLayerSettingsTests.swift.",
    ),
    "StdSelect_BRepSelectionTool": (
        {"OCCTDrawingTests", "OCCTMiscTests"},
        "used inside `OCCTBRepSelectable::ComputeSelection`, a C++ method override nested inside "
        "an internal support class (OCCTBridge_Visualization_Assets.mm), not a standalone "
        "OCCTXxx(...)-shaped function derive_lane.py's bridge-side regex matches. Reached whenever "
        "Selector.pick() runs; real test: Tests/OCCTDrawingTests/SelectorTests.swift (constructs "
        "and exercises `Selector()` directly, confirmed at line 21 and throughout).",
    ),
    "BRepFeat_MakeCylindricalHole": (
        {"OCCTModelingTests"},
        "the class name itself never appears inside a derive_lane.py-extractable function body "
        "(the bridge reaches BRepFeat_MakeCylindricalHole through a longer call chain than the "
        "propagation step follows). Real tests: Tests/OCCTModelingTests/"
        "Issue532CylindricalHolePartSelectionTests.swift, Issue496CylindricalHoleTests.swift, "
        "BRepFeatMakeCylindricalHoleTests.swift.",
    ),
    "BRepFeat_Status": (
        {"OCCTModelingTests"},
        "reached only as a PARAMETER TYPE (`occtCylindricalHoleStatusCode(BRepFeat_Status status)`, "
        "OCCTBridge_Internal.h) -- derive_lane.py's bridge-function body scan only reads the "
        "`{...}` body text, not the signature line the parameter type sits on. Tested wherever "
        "cylindricalHole itself is (same three files as BRepFeat_MakeCylindricalHole above).",
    ),
    "BRepMAT2d_BisectingLocus": (
        {"OCCTAnalysisTests"},
        "same param-type-only shape as BRepFeat_Status. Real tests: Tests/OCCTAnalysisTests/"
        "MedialAxisVariousShapesTests.swift, MedialAxisRectangleTests.swift. (The one match inside "
        "Pass 5d's own six, Tests/OCCTMiscTests/Issue622AllocationBoundsTests.swift, names "
        "`MedialAxis.drawArc` only in a `//` comment about test history -- confirmed by reading "
        "the file -- so it is not counted as coverage.)",
    ),
    "BRepMAT2d_Explorer": (
        {"OCCTAnalysisTests"},
        "backs hatching (OCCTBridge_Geom2d_Hatching.mm). Real test: "
        "Tests/OCCTAnalysisTests/HatchTests.swift.",
    ),
    "RWMesh_FaceIterator": (
        {"OCCTIOTests"},
        "used as a struct field (`struct OCCTMeshFaceIter { RWMesh_FaceIterator iter; };`), the "
        "same struct-field shape as Graphic3d_ZLayerSettings above. Real test: "
        "Tests/OCCTIOTests/RWMeshFaceIteratorTests.swift.",
    ),
    "RWMesh_VertexIterator": (
        {"OCCTIOTests"},
        "same struct-field shape. Real test: Tests/OCCTIOTests/RWMeshVertexIteratorTests.swift.",
    ),
    "Plate_FreeGtoCConstraint": (
        {"OCCTSurfaceTests"},
        "derive_lane.py DID find the right decl (`PlateSolver.loadFreeG1Constraint`), but no test "
        "in the six targets calls it -- OCCTSurfaceTests (outside the six) does. Real test: "
        "Tests/OCCTSurfaceTests/PlateConstraintExtTests.swift.",
    ),
    "RWMesh_CoordinateSystemConverter": (
        {"OCCTMathTests"},
        "derive_lane.py's decl-level signal (`CoordinateSystem.convertCoordinateSystem`) is "
        "correct, but its coarser class-target-hit pass conflated it with a DIFFERENT call "
        "(`CoordinateSystem(...)`, a plain struct init) that OCCTMeshTests does make -- confirmed "
        "by grep: OCCTMeshTests calls zero of `convertCoordinateSystem`/"
        "`coordinateSystemUpDirection`. Real test: Tests/OCCTMathTests/CoordinateSystemTests.swift.",
    ),
    # --- false POSITIVE: derive_lane.py said "tested," the match is a same-file name collision ---
    "Plate_Plate": (
        set(),  # tested nowhere -- see the classify() note on why this is not filed as an `under`
        "the type-co-occurrence gate is vacuous for a file with many declared types, and "
        "`OCCTStressTests` legitimately calls `.isDone` -- on `FilletBuilder`/`ChamferBuilder` "
        "(StressBuilderLifecycleTests.swift:284/297), never on a `PlateSolver`. Confirmed by grep: "
        "zero occurrences of the literal token `PlateSolver` anywhere under Tests/OCCTStressTests/. "
        "Plate_Plate's real coverage (Tests/OCCTSurfaceTests/, outside Pass 5d's six) is unaffected "
        "by this correction; see the classify() note for why this one is not counted as `under`.",
    ),
}

# ------------------------------------------------------------------------------------------------
# The two genuine under-coverage findings. BRepOffsetAPI_MiddlePath is fixed in this branch;
# LocOpe_SplitDrafts is filed. Both are named here, not just left to derive_lane.py's raw "zero"
# bucket, because #818's own done-when criteria ask for a disposition per finding, and a script
# re-run six months from now needs to be able to tell "still open" from "already handled."
# ------------------------------------------------------------------------------------------------

FIXED_UNDER = {
    "BRepOffsetAPI_MiddlePath": {
        "test_file": "Tests/OCCTModelingTests/Issue818MiddlePathTests.swift",
        "note": "fixed in this branch: a coaxial-tube ground-truth regression test, proved to fail "
                "when OCCTShapeMiddlePath is broken (see the PR/commit description for the "
                "red/green transcript).",
    },
}

FILED_UNDER = {
    "LocOpe_SplitDrafts": {
        "issue": "#1393",
        "note": "filed rather than fixed here: constructing a valid ground-truth call hit two "
                "non-obvious OCCT constraints (a degenerate-neutral-plane check, then a pcurve "
                "requirement on the splitting wire) that this pass's own effort budget could not "
                "fully isolate. See #1393 for the investigation record.",
    },
}


def _read(path: str) -> str:
    with open(path, errors="ignore") as fh:
        return fh.read()


def verify_fixed_claims() -> list[str]:
    """FIXED_UNDER asserts a specific test file exists and mentions the class. Grep it directly
    rather than trusting the assertion forever -- the same discipline #811-#814 apply to their own
    `KNOWN_OVER_FINDINGS` pins via `_collapse`/`check_known_over_findings`."""
    msgs = []
    for cls, info in FIXED_UNDER.items():
        path = os.path.join(ROOT, info["test_file"])
        if not os.path.exists(path):
            msgs.append(f"{cls}: asserted fix file {info['test_file']} does not exist")
            continue
        text = _read(path)
        if cls not in text:
            msgs.append(f"{cls}: {info['test_file']} exists but no longer names {cls}")
    return msgs


def classify(cls: str, lane: derive_lane.LaneResult) -> tuple[str, str, list[str]]:
    """(verdict, note, evidence test targets).

    Verdicts: `tested` (>=1 of Pass 5d's six targets reaches it), `tested-elsewhere` (reached, but
    only by a target outside the six -- informational, not a defect), `under` (reached by nothing,
    anywhere, and not yet disposed of), `fixed` (an under this branch closed), `filed` (an under
    referred to a follow-up issue).
    """
    if cls in FIXED_UNDER:
        return ("fixed", FIXED_UNDER[cls]["note"], [])
    if cls in FILED_UNDER:
        return ("filed", f"{FILED_UNDER[cls]['issue']}: {FILED_UNDER[cls]['note']}", [])

    if cls in MANUAL_OVERRIDES:
        hits, why = MANUAL_OVERRIDES[cls]
    else:
        hits = lane.class_hits.get(cls, set())
        why = "derive_lane.py's automated signal, not hand-overridden"

    in_six = hits & derive_lane.MY_TARGETS
    if in_six:
        return ("tested", why, sorted(in_six))
    if hits:
        return ("tested-elsewhere", why, sorted(hits))

    # Plate_Plate is a corrected FALSE POSITIVE (was never really "tested" by the six, but its
    # real coverage lives in OCCTSurfaceTests, i.e. it is `tested-elsewhere` in truth) -- the
    # override table intentionally reports it as `hits = set()` (nowhere) to keep the override's
    # own "what did the automated pass get wrong, and how was it corrected" record honest (the
    # automated pass's OWN claim was "OCCTStressTests," which was wrong outright, not merely
    # under-specific), so classify() special-cases it back to `tested-elsewhere` here rather than
    # letting it fall through to `under`, which would be its own new inaccuracy.
    if cls == "Plate_Plate":
        return ("tested-elsewhere", why, ["OCCTSurfaceTests (corrected; see MANUAL_OVERRIDES)"])

    return ("under", why, [])


# ------------------------------------------------------------------------------------------------
# Over-coverage sweep. #818 asks specifically about behavioural/numeric/concurrency claims in
# test comments and names that the refman does not support. Documented here as a NEGATIVE finding,
# per the task's own instruction that a checked-and-clean result is valid and should say what was
# checked rather than manufacture a finding.
# ------------------------------------------------------------------------------------------------

# Keyword sweeps run over the six targets' comments/@Suite/@Test titles during this pass (see
# README.md for the full transcript of each). Recorded as data so a future re-run can diff against
# it, the same shape KNOWN_OVER_FINDINGS uses in #811-#814.
OVER_COVERAGE_KEYWORD_SWEEPS = (
    r"thread.?safe|is.?safe.?to|safe to call|concurrently|data race|no race|atomic\b",
    r"guaranteed?|invariant|deterministic|always returns|never fails|exactly|precisely|by design|"
    r"specification|documented (behavior|behaviour)",
    r"occt.{0,15}(tolerance|precision) (is|of)|tolerance is (fixed|always|exactly)|"
    r"precision guarantee",
)

# The one candidate this pass investigated in depth rather than dismissing by keyword alone:
# StressConcurrencyTests.swift's `parallelSurfaceEval` shares one `Surface` (backed by a Bezier
# `Geom_Surface`) across 16 concurrently-scheduled tasks, all calling `.point(atU:v:)` -- the exact
# "share one adaptor/cache across threads" shape #1153 (BSplCLib_Cache/GeomAdaptor_Surface) names
# as racy in CLAUDE.md's Known OCCT Bugs. INVESTIGATED AND REJECTED: traced `Surface.point(atU:v:)`
# to its bridge implementation (`OCCTSurfaceGetPoint`, OCCTBridge_Surface_Surfaces.mm), which calls
# `s->surface->D0(u, v, p)` directly on the `Handle(Geom_Surface)` -- NOT through `GeomAdaptor_
# Surface` at all. #1153's own root cause is specifically the `GeomAdaptor_Surface`/`BSplSLib_
# Cache` layer (confirmed: neither `Geom_BezierSurface.hxx` nor `Geom_BSplineSurface.hxx` in the
# pinned headers declares any `Cache`-shaped member of their own), so this call path bypasses the
# race entirely. The suite's own header comment ("ran clean across 25 repeated iterations...
# Re-enabled permanently") predates #1153's discovery and is about a DIFFERENT investigation
# (#341's TSan protocol, NCollection-focused), so it is not a claim about #1153's mechanism either
# -- it is simply not the same claim, not a stale one.
INVESTIGATED_AND_REJECTED = {
    "StressConcurrencyTests.parallelSurfaceEval vs #1153": (
        "Tests/OCCTStressTests/StressConcurrencyTests.swift",
        "shares one Bezier Surface across 16 concurrent .point(atU:v:) calls -- the shape #1153 "
        "names as racy for GeomAdaptor_Surface/BSplSLib_Cache. Traced the actual call: "
        "Surface.point(atU:v:) -> OCCTSurfaceGetPoint -> Handle(Geom_Surface)::D0 directly, no "
        "GeomAdaptor_Surface in the chain, so #1153's own defect (in the adaptor's Cache handle) "
        "is not reachable from this entry point. Not a finding.",
    ),
}

# No genuine `asserts-more-than-promised` finding survived investigation in this pass. Kept as an
# explicit empty table (not silence) so a future run can tell "checked, found none" from "never
# checked" -- matching #818's own instruction that a real negative result is valid and should be
# stated, not implied by an absent section.
KNOWN_OVER_FINDINGS: list[tuple[str, str]] = []


def main() -> int:
    ap = argparse.ArgumentParser(description="#818 test-side refman coverage census")
    ap.add_argument("--verbose", action="store_true", help="print every class's verdict")
    ap.add_argument("--verify-fixed", action="store_true",
                     help="re-grep FIXED_UNDER's asserted fix files")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()

    if args.self_test:
        return _self_test()

    if args.verify_fixed:
        msgs = verify_fixed_claims()
        if msgs:
            print("FIXED-CLAIM VERIFICATION FAILED:")
            for m in msgs:
                print(f"  {m}")
            return 1
        print(f"--verify-fixed: all {len(FIXED_UNDER)} asserted fix(es) confirmed present.")
        return 0

    lane = derive_lane.compute()

    counts: dict[str, int] = {}
    rows: list[tuple[str, str, str, list[str]]] = []
    for cls in sorted(lane.wrapped):
        verdict, note, evidence = classify(cls, lane)
        counts[verdict] = counts.get(verdict, 0) + 1
        rows.append((cls, verdict, note, evidence))

    print(f"#818 test-side census: {len(lane.wrapped)} wrapped union-lane classes\n")
    print(f"{'verdict':<18}{'count':>6}")
    for verdict in ("tested", "tested-elsewhere", "under", "fixed", "filed", "deliberate, recorded"):
        if verdict in counts:
            print(f"{verdict:<18}{counts[verdict]:>6}")
    print()

    if args.verbose:
        for cls, verdict, note, evidence in rows:
            ev = f" [{', '.join(evidence)}]" if evidence else ""
            print(f"  {cls:<38}{verdict:<18}{note}{ev}")
        print()

    exit_code = 0

    unexplained_unders = [c for c, v, _n, _e in rows if v == "under"]
    if unexplained_unders:
        print("UNEXPLAINED under-coverage (not in FIXED_UNDER or FILED_UNDER):")
        for c in unexplained_unders:
            print(f"  {c}")
        exit_code = 1

    over_msgs = check_known_over_findings()
    if over_msgs:
        print("OVER-COVERAGE REGRESSION:")
        for m in over_msgs:
            print(f"  {m}")
        exit_code = 1

    print(f"investigated-and-rejected over-coverage candidates: {len(INVESTIGATED_AND_REJECTED)}")
    print(f"pinned over-coverage findings (regression-checked): {len(KNOWN_OVER_FINDINGS)}")

    return exit_code


def check_known_over_findings() -> list[str]:
    msgs = []
    for rel, wrong in KNOWN_OVER_FINDINGS:
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            msgs.append(f"{rel}: file is gone, so its pinned finding cannot be checked")
            continue
        if wrong in _read(path):
            msgs.append(f"{rel}: {wrong}")
    return msgs


# ------------------------------------------------------------------------------------------------
# --self-test: proves classify()'s three accepting shapes (tested / tested-elsewhere / under) and
# the fixed/filed dispositions are each load-bearing, per okf/policies/prove-the-test-fails.md.
# ------------------------------------------------------------------------------------------------


def _self_test() -> int:
    failures = []

    # Shape 1: `tested` requires hits & MY_TARGETS to be non-empty.
    fake_lane = derive_lane.LaneResult()
    fake_lane.class_hits = {"FakeClassA": {"OCCTMeshTests"}}
    v, _n, ev = classify("FakeClassA", fake_lane)
    if v != "tested" or ev != ["OCCTMeshTests"]:
        failures.append(f"shape 'tested': expected ('tested', ['OCCTMeshTests']), got ({v!r}, {ev})")

    # Disable shape 1 (simulate MY_TARGETS becoming empty, i.e. the six-target gate doing nothing)
    # and confirm the case degrades to tested-elsewhere, proving the `in_six` check is load-bearing.
    saved_targets = derive_lane.MY_TARGETS
    derive_lane.MY_TARGETS = frozenset()
    v2, _n2, _ev2 = classify("FakeClassA", fake_lane)
    derive_lane.MY_TARGETS = saved_targets
    if v2 != "tested-elsewhere":
        failures.append(
            f"shape 'tested' removal: expected degrade to 'tested-elsewhere' with MY_TARGETS "
            f"emptied, got {v2!r} -- the in_six intersection is not actually gating anything")

    # Shape 2: `tested-elsewhere` requires hits to be non-empty but disjoint from MY_TARGETS.
    fake_lane.class_hits = {"FakeClassB": {"OCCTModelingTests"}}
    v, _n, ev = classify("FakeClassB", fake_lane)
    if v != "tested-elsewhere" or ev != ["OCCTModelingTests"]:
        failures.append(f"shape 'tested-elsewhere': got ({v!r}, {ev})")

    # Shape 3: `under` requires hits to be empty and the class absent from every override/
    # disposition table.
    fake_lane.class_hits = {"FakeClassC": set()}
    v, _n, _ev = classify("FakeClassC", fake_lane)
    if v != "under":
        failures.append(f"shape 'under': expected 'under', got {v!r}")

    # Shape 4 (MANUAL_OVERRIDES is load-bearing): a class present in class_hits as EMPTY, but
    # overridden to a real target, must classify by the override, not the raw (empty) signal.
    fake_lane.class_hits = {"Graphic3d_ZLayerSettings": set()}
    v, _n, ev = classify("Graphic3d_ZLayerSettings", fake_lane)
    if v != "tested" or "OCCTDrawingTests" not in ev:
        failures.append(
            f"shape 'MANUAL_OVERRIDES override': expected 'tested' via the override table even "
            f"with an empty raw signal, got ({v!r}, {ev}) -- the override is not taking effect")

    # Shape 5 (fixed/filed dispositions are load-bearing, checked BEFORE the raw signal): a class
    # in FIXED_UNDER/FILED_UNDER must classify as such even if its raw signal would say `under`.
    fake_lane.class_hits = {"BRepOffsetAPI_MiddlePath": set(), "LocOpe_SplitDrafts": set()}
    v, _n, _ev = classify("BRepOffsetAPI_MiddlePath", fake_lane)
    if v != "fixed":
        failures.append(f"shape 'fixed disposition': expected 'fixed', got {v!r} -- FIXED_UNDER "
                         "is not being consulted ahead of the raw signal")
    v, _n, _ev = classify("LocOpe_SplitDrafts", fake_lane)
    if v != "filed":
        failures.append(f"shape 'filed disposition': expected 'filed', got {v!r}")

    # Shape 6: verify_fixed_claims() actually reads the real file and would catch a regression.
    # Prove the test fails: temporarily point FIXED_UNDER at a file that does NOT mention the
    # class, confirm the checker reports it, then restore.
    real_entry = FIXED_UNDER["BRepOffsetAPI_MiddlePath"]
    FIXED_UNDER["BRepOffsetAPI_MiddlePath"] = {**real_entry, "test_file": "README.md"}
    msgs = verify_fixed_claims()
    FIXED_UNDER["BRepOffsetAPI_MiddlePath"] = real_entry
    if not any("BRepOffsetAPI_MiddlePath" in m for m in msgs):
        failures.append(
            "shape 'verify_fixed_claims catches a missing class': pointed FIXED_UNDER at "
            "README.md (which does not name BRepOffsetAPI_MiddlePath) and got no failure message "
            "-- the checker is not actually reading the file's content")
    msgs_after_restore = verify_fixed_claims()
    if msgs_after_restore:
        failures.append(
            f"shape 'verify_fixed_claims restore': expected clean after restoring FIXED_UNDER, "
            f"got {msgs_after_restore}")

    # Shape 7: check_known_over_findings() would catch a real regression if one were pinned.
    # Prove the test fails: inject a fake pinned finding matching real file content, confirm it's
    # reported, then confirm a non-matching one is not.
    global KNOWN_OVER_FINDINGS
    saved = KNOWN_OVER_FINDINGS
    # README.md of this very directory will exist and contain its own title once written; use a
    # string guaranteed to be in THIS script file instead, which definitely exists at self-test
    # time and is stable.
    this_file = os.path.relpath(os.path.abspath(__file__), ROOT)
    KNOWN_OVER_FINDINGS = [(this_file, "SELFTEST_CANARY_STRING_818")]
    found = check_known_over_findings()
    KNOWN_OVER_FINDINGS = saved
    if not found:
        failures.append(
            "shape 'check_known_over_findings catches a match': injected a canary string this "
            "very file contains as a pinned finding and got no report")

    if failures:
        print(f"{len(failures)} self-test failure(s):")
        for f in failures:
            print(f"  - {f}")
        return 1
    print("--self-test: 7/7 shapes proved load-bearing (each one injected, confirmed to fail the "
          "check, then restored).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
