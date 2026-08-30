#!/usr/bin/env python3
"""Issue #816 (Pass 5b of #807/#819): refman coverage census for the Shape/Topology TEST lane.

Passes 5a-5d ask the test-side form of #807's question. Not "do we wrap and document this OCCT
class" (that is #808's, Pass 2a's, question, already answered for this lane), but "does a TEST in
this lane's five targets actually exercise it": `OCCTTopologyTests`, `OCCTModelingTests`,
`OCCTAnalysisTests`, `OCCTShapeHealingTests`, `OCCTBRepGraphTests`.

THE SUBJECT IS #808's OWN 66 `ok` CLASSES, re-verified rather than retyped: see `derive_lane.py`'s
docstring for why only `ok` (documented AND wrapped) rows are this pass's concern, and how the
class -> bridge-function -> Swift-declaration trace works. Run `derive_lane.py --reverify-808`
before trusting anything here; a drift in #808's own table changes this pass's 66-class subject.

TWO DIRECTIONS, per #816:

  UNDER-COVERAGE. A class in the 66 that NO test in the five targets exercises. The mechanical
  trace (`derive_lane.trace_lane`) finds 6 of the 66 this way on the first pass. Five turn out NOT
  to be real gaps on inspection (below); one is.

  OVER-COVERAGE. A test's `///`/`//` comment or name stating a behavioural or numeric claim about
  an OCCT class's internals -- a tolerance, an algorithm guarantee, an invariant -- that the refman
  does not actually support. `find_over_coverage_candidates()` below is the detector;
  `ADJUDICATED_CLAIMS` is the hand-read verdict on every candidate it raised, checked against the
  `occt-refman` MCP where it has the text and the pinned kernel source
  (`Libraries/occt-src/src/.../*.cxx`/`.hxx`) where the refman is silent (`occt-refman@8.0.1` has no
  entry at all for `BRepLib::ContinuityOfFaces`, `BRep_Tool::MaxTolerance` or `ShapeFix_Shape::
  FixFreeFaceMode`, three static-utility-style methods with thin or no doc text; the pinned source
  is what actually settles those three).

WHY FIVE OF THE SIX MECHANICAL "UNTESTED" HITS ARE NOT FINDINGS: each is tested, just in a
DIFFERENT domain target than this lane's five, and that placement is CORRECT per CLAUDE.md's own
Test Layout table (`Analysis, Curve, Drawing, Foundation, Geom2d, IO, Integration, Math, Mesh,
Misc, Modeling, ShapeHealing, Stress, Surface, Thread, BRepGraph, Topology, XCAF`, "add a new suite
to the domain target that best matches it"):

  - `BRepBuilderAPI_GTransform` (`Shape.gTransformed`/`Shape.nonUniformScaled`): general-affine-
    transform math, tested in `OCCTMathTests/NonUniformScaleTests.swift` and
    `TransformExpansionTests.swift`.
  - `BRepBuilderAPI_MakeEdge2d` (`Shape.edge2dFromCircle`/`edge2dFromLine`/`edge2d`): 2D curve
    construction, tested in `OCCTGeom2dTests/MakeEdge2dTests.swift`.
  - `BRepBuilderAPI_MakeShapeOnMesh` (`Shape.fromMesh`): tested in `OCCTMeshTests/
    OCCTMeshTests.swift`.
  - `BRepPrimAPI_MakeRevolution` (`Shape.revolution(meridian:...)`, a surface of revolution from a
    CURVE, not `BRepPrimAPI_MakeRevol`'s shape-of-revolution): tested in `OCCTSurfaceTests/
    SurfaceSweptTests.swift` and `RevolutionFromCurveTests.swift`.

  A stricter reading of "no test in THIS lane's targets exercises it" would flag all four as
  `under` anyway. That reading was rejected: it would manufacture four findings whose only defect
  is that #808's lane (a SOURCE-side, OCCT-class-family lane) and this project's test-domain split
  (a SEPARATE, Swift-API-shaped partition, settled independently) do not line up file-for-file, and
  filing a "missing test" issue for a capability with real, correct, on-target tests would be
  exactly the manufactured-finding failure #816's own instructions warn against. `classify()` below
  checks the WHOLE `Tests/` tree as a second pass specifically so this distinction is visible in
  the verdict rather than silently assumed.

THE SIXTH, `BRepBuilderAPI_MakeShape`, IS A MECHANICAL FALSE NEGATIVE, not a lane-placement
artifact: the class name appears in this bridge ONLY inside a constructor's PARAMETER TYPE
(`OCCTBooleanHistory(std::unique_ptr<BRepBuilderAPI_MakeShape> theOp, ...)`,
`OCCTBridge_Modeling_Boolean.mm`) and a field declaration of the same type, never inside a
function's executable BODY text, which is the only place `derive_lane`'s class-mention test looks
(by design, see its own docstring). The capability it represents -- a type-erased base letting
`OCCTBooleanUnionWithHistory`/`SubtractWithHistory`/`IntersectWithHistory`/`SplitWithHistory` and
five more report `Generated()`/`Modified()` history uniformly across four concrete boolean/
modification algorithms -- is heavily tested IN this lane: `Tests/OCCTModelingTests/
BooleanHistoryTests.swift`, `BooleanFullHistoryTests.swift`, `HistoryExtendedTests.swift` and
`Tier2HistoryTests.swift` all exercise `Shape.unionWithFullHistory`/`subtractedWithFullHistory`/
`fuseWithHistory` and siblings, which is the Swift surface over exactly this base. `NO_DIRECT_
MENTION` below is the curated override for this one shape.

THE ONE REAL FINDING: `BRepCheck_Solid`. `OCCTCheckSolid` (`OCCTBridge_Healing_Analysis.mm:1057`)
is a real, working, already-implemented bridge function -- it walks every `TopAbs_SOLID` in a
shape and runs `BRepCheck_Solid` on each, mirroring `OCCTCheckEdge`/`Wire`/`Shell`/`Vertex`
(`OCCTBridge_Healing_Fix.mm`, all four backed by the shared `checkSubShape()` helper) -- declared
in `OCCTBridge_Healing.h:631`, and NEVER CALLED from any file under `Sources/OCCTSwift`. Checked by
name across the whole tree, not just this lane: zero hits. So this is not merely untested, it is
UNTESTABLE as things stand: there is no Swift entry point for a test to call. `OCCTCheckShape`
(`OCCTBridge_Healing_Analysis.mm:1097`, backing the well-tested `Shape.checkResult`) localizes
errors by walking `TopAbs_FACE` and `TopAbs_EDGE` results from its `BRepCheck_Analyzer` only, never
`TopAbs_SOLID`, so a solid-only defect `BRepCheck_Analyzer::IsValid()` would catch could in
principle come back `isValid: false, errorCount: 0, firstError: nil`, the same internally-
contradictory shape this project's `#726`/`#609`/`#583` census entries exist to catch elsewhere --
unconfirmed on a real fixture, filed rather than asserted. See `NO_SWIFT_CALLER` below and the
README for the filed issue number.

Run from anywhere (paths derive from this file's location, not the cwd):

    python3 Scripts/repro/816-refman-coverage-tests-topology/refman_census.py
    python3 Scripts/repro/816-refman-coverage-tests-topology/refman_census.py --verbose
    python3 Scripts/repro/816-refman-coverage-tests-topology/refman_census.py --over-coverage
    python3 Scripts/repro/816-refman-coverage-tests-topology/refman_census.py --self-test

Exits 1 on an unrecorded `under`, or an over-coverage candidate matching neither `ADJUDICATED_
CLAIMS` (a real regression risk: a checked claim's text changed) nor the "new, needs review" report
path; 0 otherwise. `--self-test` proves each classification mechanism is load-bearing by disabling
it on synthetic fixtures and checking the verdict changes, per `okf/policies/prove-the-test-
fails.md`; it does not touch the real repo.
"""

from __future__ import annotations

import argparse
import importlib.util
import os
import re
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
TESTS_DIR = os.path.join(ROOT, "Tests")
GAPS_FILE = os.path.join(ROOT, "docs", "occtswift-wrapping-gaps.md")
DERIVE_LANE_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "derive_lane.py")


def _load(path: str, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _read(path: str) -> str:
    with open(path, errors="ignore") as fh:
        return fh.read()


# -------------------------------------------------------------------------------------------
# Curated overrides, each established by reading the real bridge/Swift call sites and the real
# test files during #816, never inferred from the class name.
# -------------------------------------------------------------------------------------------

NO_DIRECT_MENTION = {
    "BRepBuilderAPI_MakeShape": (
        "named only in a constructor parameter type / field type "
        "(std::unique_ptr<BRepBuilderAPI_MakeShape>, OCCTBridge_Modeling_Boolean.mm), never in "
        "executable body text, so the mechanical trace finds no bridge function for it. The "
        "capability (type-erased boolean/modification history) is tested in-lane: "
        "Tests/OCCTModelingTests/{BooleanHistoryTests,BooleanFullHistoryTests,HistoryExtendedTests,"
        "Tier2HistoryTests}.swift exercise Shape.unionWithFullHistory/subtractedWithFullHistory/"
        "fuseWithHistory and siblings, the Swift surface over this exact base."
    ),
}

# Filled in once the follow-up issue for the one real finding is filed; see README.md.
NO_SWIFT_CALLER = {
    "BRepCheck_Solid": (
        "OCCTCheckSolid (OCCTBridge_Healing_Analysis.mm:1057) is real and working but has zero "
        "Swift callers anywhere in Sources/OCCTSwift, so nothing can test it as things stand. "
        "Filed as #1392 rather than fixed here: the missing wrapper is small, but a test proving "
        "it actually distinguishes a valid from an invalid solid needs a real invalid-solid "
        "fixture BRepCheck_Solid specifically (not BRepCheck_Face/_Edge) would flag, which is real "
        "reproduction work outside a test-coverage census, following this project's established "
        "file-and-defer practice for a finding that needs its own investigation (e.g. #905, #913)."
    ),
}

SIBLING_DOMAIN_NOTE = (
    "untested by this lane's five targets, but tested in {files}, the correct domain per "
    "CLAUDE.md's Test Layout (this capability's own family, not Shape/Topology core)"
)


def classify(cls: str, in_lane_tested: bool, whole_suite_hits: list[str], gaps_text: str) -> tuple[str, str]:
    """Returns (verdict, note). `whole_suite_hits` is the list of Tests/<Domain>/... files (outside
    the five lane targets) where the capability IS exercised, or [] if nowhere.

    Order matters and each step is proven load-bearing by --self-test:
      1. in-lane tested -> ok (the common case, 60 of 66).
      2. NO_DIRECT_MENTION curated override -> ok (the one mechanical false negative).
      3. tested elsewhere in Tests/, outside this lane -> ok, noting where and why that is correct.
      4. NO_SWIFT_CALLER curated override -> under, the one real, evidenced, filed finding.
      5. named in docs/occtswift-wrapping-gaps.md -> deliberate, recorded.
      6. otherwise -> under, an unrecorded gap this run just found.
    """
    if in_lane_tested:
        return "ok", "tested in-lane"
    if cls in NO_DIRECT_MENTION:
        return "ok", NO_DIRECT_MENTION[cls]
    if whole_suite_hits:
        return "ok", SIBLING_DOMAIN_NOTE.format(files=", ".join(whole_suite_hits))
    if cls in NO_SWIFT_CALLER:
        return "under", NO_SWIFT_CALLER[cls]
    if re.search(r"\b" + re.escape(cls) + r"\b", gaps_text):
        return "deliberate, recorded", "recorded in docs/occtswift-wrapping-gaps.md"
    return "under", "no test anywhere in Tests/ exercises this class, and no recorded reason"


def whole_suite_test_texts(exclude_targets: set[str]):
    """[(relpath, stripped_text), ...] for every *.swift file under Tests/ NOT in a lane target."""
    out = []
    for target in sorted(os.listdir(TESTS_DIR)):
        d = os.path.join(TESTS_DIR, target)
        if target in exclude_targets or not os.path.isdir(d):
            continue
        for fn in sorted(os.listdir(d)):
            if fn.endswith(".swift"):
                out.append((os.path.join(target, fn), _read(os.path.join(d, fn))))
    return out


def main_census(verbose: bool) -> int:
    dl = _load(DERIVE_LANE_PATH, "derive_lane_816")
    census808 = dl._load_census808()
    checked, msgs = census808.reverify_lane()
    if checked and msgs:
        print("#808 LANE DRIFT -- re-derive before trusting this pass's 66-class subject:")
        for m in msgs:
            print(f"  {m}")
        return 1

    test_lane, per_class = dl.trace_lane(census808)
    gaps_text = _read(GAPS_FILE)
    lane_target_set = set(dl.TEST_TARGETS)
    outside = whole_suite_test_texts(lane_target_set)

    rows = []
    for cls in test_lane:
        class_rows = per_class[cls]
        in_lane_tested = any(r["tested"] for r in class_rows)
        whole_suite_hits: list[str] = []
        if not in_lane_tested:
            # Re-derive the same (kind, name, owning_type) declarations this class's bridge
            # functions resolved to, and check them against files OUTSIDE the lane.
            seen = set()
            for r in class_rows:
                if r["no_swift_caller"] or r["decl_name"] is None:
                    continue
                key = (r["decl_kind"], r["decl_name"], r["owning_type"])
                if key in seen:
                    continue
                seen.add(key)
                tested, _amb, hits = dl.is_tested(r["decl_kind"], r["decl_name"], r["owning_type"],
                                                   outside)
                if tested:
                    whole_suite_hits.extend(hits)
        verdict, note = classify(cls, in_lane_tested, sorted(set(whole_suite_hits)), gaps_text)
        rows.append((cls, verdict, note))

    print(f"{'class':42} {'verdict':22} note")
    print("-" * 140)
    counts: dict[str, int] = {}
    exit_code = 0
    for cls, verdict, note in rows:
        counts[verdict] = counts.get(verdict, 0) + 1
        print(f"{cls:42} {verdict:22} {note}")
        if verdict == "under" and cls not in NO_SWIFT_CALLER:
            exit_code = 1

    print()
    print(f"Total classes examined: {len(rows)}")
    for v in ("ok", "deliberate, recorded", "under"):
        print(f"  {v}: {counts.get(v, 0)}")
    if exit_code:
        print("UNRECORDED under-coverage found (see rows above) -- file or fix before merging.")
    return exit_code


# -------------------------------------------------------------------------------------------
# Over-coverage sweep: a test comment/name asserting a behavioural or numeric OCCT claim.
# -------------------------------------------------------------------------------------------

CLAIM_WORDS = re.compile(
    r"\b(always|never|guarantee[sd]?|invariant|exactly|must (?:be|equal|not|match|satisfy)"
    r"|cannot|is defined as|by definition|per (?:the )?OCCT|per (?:the )?refman"
    r"|OCCT (?:guarantees|promises|documents|defines|requires)|own header documents)\b", re.I)
NUM_TOL = re.compile(r"\b\d+(?:\.\d+)?[eE][+-]?\d+\b|\b0\.0{2,}\d+\b")
OCCT_CLASS = re.compile(
    r"\b(?:TopoDS|TopExp|TopTools|TopAbs|BRepBuilderAPI|BRepPrimAPI|BRepAlgoAPI|BRepCheck"
    r"|BRepTools|BRepGProp|BRepLProp|BRepClass3d|BRepExtrema|BRepFilletAPI|BRepFeat"
    r"|BRepOffsetAPI|BRepBndLib|BRep|ShapeFix|ShapeAnalysis|ShapeUpgrade|GeomAbs|GeomAPI"
    r"|GeomLProp|GCPnts|GProp|BOPAlgo|Geom2d|Geom|Standard)_?[A-Za-z0-9]*\b")


def is_comment_line(line: str) -> bool:
    s = line.strip()
    return s.startswith("//") or s.startswith("///") or s.startswith("*")


def find_over_coverage_candidates(lane_targets=None):
    """[(target, file, lineno, text, kind)], kind in {'claim', 'numeric'}. Scans `///`/`//`
    comment lines (block-comment `*` continuations too) in the five lane targets by default; pass
    `lane_targets` = {target: {filename: text}} to scan an in-memory fixture instead (used by
    --self-test so no real file is touched)."""
    out = []
    if lane_targets is None:
        dl = _load(DERIVE_LANE_PATH, "derive_lane_816_ovc")
        lane_targets = {}
        for target in dl.TEST_TARGETS:
            d = os.path.join(TESTS_DIR, target)
            if not os.path.isdir(d):
                continue
            lane_targets[target] = {fn: _read(os.path.join(d, fn))
                                     for fn in sorted(os.listdir(d)) if fn.endswith(".swift")}
    for target, files in lane_targets.items():
        for fn, text in files.items():
            for i, line in enumerate(text.splitlines()):
                if not is_comment_line(line):
                    continue
                has_class = OCCT_CLASS.search(line) is not None
                if not has_class:
                    continue
                if CLAIM_WORDS.search(line):
                    out.append((target, fn, i + 1, line.strip(), "claim"))
                elif NUM_TOL.search(line):
                    out.append((target, fn, i + 1, line.strip(), "numeric"))
    return out


# Every candidate `find_over_coverage_candidates()` raised against the real tree on 2026-08-31,
# hand-read in full context and checked against `occt-refman@8.0.1` (via the `context` MCP) or,
# where the refman has no entry (BRepLib::ContinuityOfFaces, BRep_Tool::MaxTolerance,
# ShapeFix_Shape::FixFreeFaceMode all came back empty), the pinned kernel source
# (`Libraries/occt-src/src/.../*.cxx`/`.hxx`). Keyed by (file, line-substring) rather than a full
# line, since re-wrapping a comment shifts line numbers without changing its claim.
ADJUDICATED_CLAIMS = {
    ("OCCTTopologyTests/Issue495FaceContinuityTests.swift", "5 (C3) is a value"): (
        "confirmed, not a finding. Read BRepLib.cxx's ContinuityOfFaces (2197-2419): every "
        "explicit GeomAbs_Shape assignment in the function is C0/G1/C1/G2/C2, an elementary-seam "
        "early return is CN, and a trailing `if (isElementary && aCont == GeomAbs_C2) aCont = "
        "GeomAbs_CN;` promotion is the only other path -- C3 (ordinal 5) is never assigned "
        "anywhere. The test's own #expect is grounded in this read, not asserted from the "
        "refman (occt-refman@8.0.1 has no entry for this method at all)."),
    ("OCCTTopologyTests/Issue833MaxToleranceEncodingTests.swift", "MaxTolerance` never measures"): (
        "confirmed, not a finding. BRep_Tool.cxx's MaxTolerance(shape, subShape) (1830-1862) "
        "branches on FACE/EDGE/VERTEX only; TopAbs_SOLID (and anything else) falls through all "
        "three `if`/`else if` arms with aTol left at its initial 0.0, exactly the claimed 'returns "
        "0 for anything else'."),
    ("OCCTModelingTests/Issue639FilletDeclinedEdgeReportTests.swift", "silently does nothing"): (
        "not a refman claim: the comment says 'measured' and cites a probe "
        "(Scripts/repro/cluster-b-fillet-edge-contract/), and occt-refman@8.0.1's Add() entries "
        "document only what a call BUILDS, saying nothing about a declined edge either way, so "
        "the comment does not misattribute anything to the refman."),
    ("OCCTAnalysisTests/Issue885TotalAreaDivergenceTests.swift", "own header documents"): (
        "confirmed, verbatim. occt-refman@8.0.1's BRepGProp::SurfaceProperties entry: 'WARNING: "
        "if Eps > 0.001 algorithm performs non-adaptive integration', matching the test's quote "
        "exactly."),
    ("OCCTShapeHealingTests/Issue655FreeBoundsInternalOrientationTests.swift",
     "ShapeAnalysis_FreeBounds.hxx:98"): (
        "confirmed. Line 98 of the pinned header is exactly `const bool checkinternaledges = "
        "false);`, the default the comment cites."),
    ("OCCTShapeHealingTests/Issue837FixDetailedModeFlagsTests.swift", "always-on default"): (
        "confirmed and appropriately scoped. ShapeFix_Shape.hxx: 'Returns (modifiable) the mode "
        "for applying fixes of ShapeFix_Face, by default True.' The comment's 'always-on' is about "
        "the NOW-FIXED bridge bug (the caller's fixFace param was never forwarded, so every call "
        "silently got this default), not a claim that ShapeFix_Shape itself is unconfigurable."),
    ("OCCTAnalysisTests/AdaptorLocalPropsParityTests.swift", "ones on a literal `1e-6`"): (
        "historical, evidence-backed narrative (#494/#529, already in CLAUDE.md's Known OCCT Bugs "
        "list under neither name directly but covered by the #529 issue file), with its own probe "
        "directory (Scripts/repro/529-breplprop-resolution/); not a live claim needing re-checking "
        "here."),
    ("OCCTTopologyTests/Issue495FaceContinuityTests.swift", "it casts the GeomAbs_Shape straight through"): (
        "same #495/ContinuityOfFaces finding as the entry above (one paragraph, two flagged "
        "lines); the 'no lookup table' phrase is what the source read (2197-2419) confirms: a "
        "direct GeomAbs_Shape assignment, never a value-mapping table that could introduce C3."),
    ("OCCTModelingTests/Issue655SectionWiresOrientationTests.swift", "never hands this"): (
        "cross-references the same #655 finding as Issue655FreeBoundsInternalOrientationTests.swift "
        "(BRepBuilderAPI_Sewing::FreeEdge not handing an INTERNAL/EXTERNAL edge to the free-bounds "
        "chainage), from the sectionWiresAtZ side that IS affected rather than the freeBounds side "
        "that isn't; same investigation, not re-derived twice."),
    ("OCCTModelingTests/Issue496CylindricalHoleTests.swift", "exactly two places"): (
        "confirmed. grep of BRepFeat_MakeCylindricalHole.cxx: BRepFeat_HoleTooLong is assigned at "
        "exactly two lines, 526 and 667."),
    ("OCCTShapeHealingTests/Issue1058OuterBoundRefusalTests.swift", "A plane cannot show"): (
        "backed by its own investigation, not re-derived here: the same comment block cites "
        "Scripts/repro/1058-outer-bound-refusal/ and the file's own 'WHAT THESE TESTS ISOLATE' "
        "section immediately below states, per guard, which specific test fails when that guard "
        "alone is disabled -- a prove-the-test-fails table already in the source, not a claim "
        "resting on the refman."),
    ("OCCTShapeHealingTests/Issue655FreeBoundsInternalOrientationTests.swift", "FreeEdge` stage"): (
        "backed by its own investigation: the doc explicitly says a PRIOR round's 'unaffected on "
        "either kernel' note was 'an unmeasured extrapolation' and this suite exists to measure it "
        "directly instead, i.e. the file is itself a correction of an earlier over-claim, not a "
        "fresh one."),
    ("OCCTShapeHealingTests/Issue655FreeBoundsInternalOrientationTests.swift", "never via"): (
        "same investigation as the entry above (checkinternaledges=false at "
        "ShapeAnalysis_FreeBounds.hxx:98, confirmed against the pinned header)."),
    # The remaining candidates are historical/narrative: each describes an ALREADY-FIXED bug in
    # THIS PROJECT'S OWN bridge code, Swift struct, or test fixture (most cite their own issue
    # number and/or a Scripts/repro/ probe), not a claim that OCCT's refman promises something.
    # Read in full context, not matched by keyword: none states or implies a refman-sourced
    # guarantee, so none needs an occt-refman/source check the way the eight above did.
    ("OCCTTopologyTests/Issue1026NullShapeTypeGuardTests.swift", "gate's third walk cannot"): (
        "about this repo's own check-null-handle-guards.py gate, not OCCT."),
    ("OCCTModelingTests/BooleanExpansionTests.swift", "tolerance argument this test used to pass"): (
        "about this bridge's own historical API surface (a removed parameter), not OCCT."),
    ("OCCTModelingTests/Issue1054SelfIntersectFaultKindTests.swift", "Boolean Operations cannot use"): (
        "narrates #1054's own bridge-side fault-kind mapping, not a refman claim."),
    ("OCCTModelingTests/Issue1054SelfIntersectFaultKindTests.swift", "HasFaulty() cannot tell"): (
        "same #1054 narrative as above."),
    ("OCCTModelingTests/Issue208SelfIntersectionTests.swift", "bounded so it cannot hang"): (
        "narrates #319's already-fixed, already-documented (CLAUDE.md Known OCCT Bugs) hardTimeout "
        "fix; the CLAUDE.md entry itself is the evidence trail."),
    ("OCCTModelingTests/Issue497DefeaturingTests.swift", "BOPAlgo_Options` is stored and never read"): (
        "about this bridge's own historical option-plumbing bug (#497), not OCCT."),
    ("OCCTModelingTests/Issue733MeshTriangulationBoundsTests.swift", "always takes the exact"): (
        "describes this bridge's own triangulation-bounds formula choice, not an OCCT guarantee."),
    ("OCCTModelingTests/Issue735PocketEnclosureTests.swift", "can never contribute to this test"): (
        "test-fixture-specific reasoning about this test's own geometry, not a general OCCT claim."),
    ("OCCTModelingTests/Issue762FilletedPocketDetectionTests.swift", "exact Z by about"): (
        "a MEASURED numeric deviation from a real fillet operation, reported as an observation, "
        "not asserted as an OCCT-guaranteed tolerance."),
    ("OCCTAnalysisTests/BRepBndLibTests.swift", "measures exactly"): (
        "describes a measured value on a specific degenerate (zero-size) fixture, backed by 'live "
        "repro' cited two words earlier; not a general refman claim."),
    ("OCCTAnalysisTests/ZeroMassResultsTests.swift", "Vinert(coplanar face)"): (
        "a coplanar face contributing zero enclosed volume is a direct consequence of the "
        "divergence-theorem integration BRepGProp_Vinert documents itself as performing, not an "
        "independent claim needing separate refman verification."),
    ("OCCTAnalysisTests/ZeroMassResultsTests.swift", "throws first."): (
        "restates this project's own, already-verified #345 finding (CLAUDE.md Known OCCT Bugs: "
        "gp_Dir throws Standard_ConstructionError for a zero-length vector); not re-derived here."),
    ("OCCTShapeHealingTests/Issue1058OuterBoundRefusalTests.swift", "cannot assemble them"): (
        "BRepBuilderAPI_MakeWire requiring connected edges is the method's basic, undisputed "
        "contract (its own refman entries document Add()'s edge-connection requirement); not a "
        "risk-bearing claim."),
    ("OCCTShapeHealingTests/Issue484ConnectedFacesTests.swift", "wires them into one shell exactly"): (
        "describes this bridge's own shellFromFaces implementation choice (no sewing), not an "
        "OCCT-documented guarantee about BRep_Builder::Add."),
    ("OCCTShapeHealingTests/Issue490ContinuityDecoderTests.swift", "exactly what the advanced entry"): (
        "describes two of this bridge's own code paths being equivalent, not an OCCT claim."),
    ("OCCTShapeHealingTests/Issue702SolidDemotionTests.swift", "exactly what `Shape.solidFromShells"): (
        "describes this bridge's own solidFromShells behavior on the fixture, not an OCCT claim."),
    ("OCCTShapeHealingTests/Issue702SolidDemotionTests.swift", "cannot close"): (
        "names a ShapeFix_Solid branch by its own established nickname in this project's prior "
        "#702 investigation (already closed, see CLAUDE.md/#702), not a fresh refman claim."),
    ("OCCTShapeHealingTests/Issue702SolidDemotionTests.swift", "which does not"): (
        "same #702 fixture narrative as the two entries above."),
    ("OCCTShapeHealingTests/Issue772SelfIntersectionAnalysisTests.swift", "was always 0 and never computed"): (
        "narrates #772/#763, an already-fixed bug in this project's OWN "
        "ShapeAnalysisResult.selfIntersectionCount field, not an OCCT claim."),
    ("OCCTShapeHealingTests/Issue772SelfIntersectionAnalysisTests.swift", "never a count"): (
        "same #772 narrative as above."),
    ("OCCTShapeHealingTests/Issue837FixDetailedModeFlagsTests.swift", "never passed to the underlying"): (
        "same #837 finding as the 'always-on default' entry above (one paragraph, two flagged "
        "lines)."),
    ("OCCTShapeHealingTests/SelfIntersectingProfileGuard263.swift", "OCC_CATCH_SIGNALS` is inert"): (
        "restates CLAUDE.md's own standing note that OCC_CATCH_SIGNALS is inert in this build; not "
        "a fresh claim."),
    ("OCCTBRepGraphTests/ConstructionAxisTests.swift", "review's own cited"): (
        "explicitly self-attributed to 'the review's own cited' range (a prior PR review's "
        "heuristic), not stated as an OCCT-guaranteed bound."),
    ("OCCTBRepGraphTests/ConstructionAxisTests.swift", "well within the review's"): (
        "same self-attributed heuristic as the entry above."),
}


def check_over_coverage(verbose: bool) -> int:
    candidates = find_over_coverage_candidates()
    print(f"Over-coverage candidates (comment/name, claim-word or numeric-tolerance + OCCT class "
          f"mention): {len(candidates)}")
    unadjudicated = []
    for target, fn, lineno, text, kind in candidates:
        key_file = f"{target}/{fn}"
        matched_key = None
        for (kf, needle) in ADJUDICATED_CLAIMS:
            if kf == key_file and needle in text:
                matched_key = (kf, needle)
                break
        if matched_key:
            if verbose:
                print(f"  [{kind}] {key_file}:{lineno}: adjudicated -- "
                      f"{ADJUDICATED_CLAIMS[matched_key][:70]}...")
        else:
            unadjudicated.append((target, fn, lineno, text, kind))

    print(f"Adjudicated (checked against refman/pinned source, see ADJUDICATED_CLAIMS): "
          f"{len(candidates) - len(unadjudicated)}")
    print(f"Confirmed over-coverage (a checked claim the refman contradicts): 0")
    print(f"NEW, unadjudicated candidates needing a human read: {len(unadjudicated)}")
    for target, fn, lineno, text, kind in unadjudicated:
        print(f"  [{kind}] {target}/{fn}:{lineno}: {text}")
    # Unadjudicated candidates are reported, not gated: #816's own sweep read every candidate it
    # found on 2026-08-31 (see the README), and this list existing means the LANE'S TEXT CHANGED
    # since, which is worth a human look but is not itself evidence of a defect.
    return 0


# -------------------------------------------------------------------------------------------
# --self-test
# -------------------------------------------------------------------------------------------


def _selftest_classify() -> bool:
    """Each of classify()'s five branches, proven load-bearing: flip the ONE input that
    distinguishes it from the next branch down and confirm the verdict (or, for the curated
    branches, the note) changes. Mirrors the removal-matrix shape of okf/policies/
    prove-the-test-fails.md rather than only checking the happy path."""
    ok = True

    def check(label, got, want):
        nonlocal ok
        passed = got == want
        print(f"  {label}: {'PASS' if passed else 'FAIL'} (got {got!r}, want {want!r})")
        if not passed:
            ok = False

    gaps_with = "SomeOtherClass is deliberately unwrapped. FakeGapClass is deliberately unwrapped."
    gaps_without = "SomeOtherClass is deliberately unwrapped."

    # 1. in-lane tested -> ok, and DISABLING it (in_lane_tested=False) with every other input also
    #    false falls through to the generic 'under', proving this branch is checked FIRST and is
    #    load-bearing rather than redundant with a later one.
    v, _n = classify("FakeGapClass", True, [], gaps_without)
    check("1a. in_lane_tested=True -> ok", v, "ok")
    v, _n = classify("FakeGapClass", False, [], gaps_without)
    check("1b. in_lane_tested=False (all else false) -> under", v, "under")

    # 2. NO_DIRECT_MENTION curated override -> ok, with the curated note; disabling it (simulating
    #    the table not carrying this class) falls through to 'under' since whole_suite_hits=[] and
    #    it is not in gaps_text either.
    real_key = "BRepBuilderAPI_MakeShape"
    assert real_key in NO_DIRECT_MENTION, "fixture assumes the real curated entry exists"
    v, n = classify(real_key, False, [], gaps_without)
    check("2a. NO_DIRECT_MENTION entry present -> ok", v, "ok")
    check("2b. ...with the curated note", n == NO_DIRECT_MENTION[real_key], True)
    saved = NO_DIRECT_MENTION.pop(real_key)
    try:
        v, _n = classify(real_key, False, [], gaps_without)
        check("2c. NO_DIRECT_MENTION entry removed -> under (mechanism is load-bearing)", v,
              "under")
    finally:
        NO_DIRECT_MENTION[real_key] = saved

    # 3. tested elsewhere in Tests/ (outside the lane) -> ok, naming where; empty hits list falls
    #    through past this branch.
    v, n = classify("FakeGapClass", False, ["OCCTMathTests/Foo.swift"], gaps_without)
    check("3a. whole_suite_hits non-empty -> ok", v, "ok")
    check("3b. ...note names the file", "OCCTMathTests/Foo.swift" in n, True)
    v, _n = classify("FakeGapClass", False, [], gaps_without)
    check("3c. whole_suite_hits empty -> not ok (falls through)", v != "ok", True)

    # 4. NO_SWIFT_CALLER curated override -> under, with its specific note; disabling it still
    #    gives 'under' via the generic path (since the class is genuinely untested everywhere) but
    #    LOSES the specific note (the filed-issue pointer), which is what this checks: the
    #    mechanism's value is the note it adds, not the verdict alone.
    real_key2 = "BRepCheck_Solid"
    assert real_key2 in NO_SWIFT_CALLER, "fixture assumes the real curated entry exists"
    v, n = classify(real_key2, False, [], gaps_without)
    check("4a. NO_SWIFT_CALLER entry present -> under", v, "under")
    check("4b. ...with the curated note (not the generic one)",
          n == NO_SWIFT_CALLER[real_key2], True)
    saved2 = NO_SWIFT_CALLER.pop(real_key2)
    try:
        v, n = classify(real_key2, False, [], gaps_without)
        check("4c. entry removed -> still under, but generic note (mechanism is load-bearing)",
              (v == "under" and n != saved2), True)
    finally:
        NO_SWIFT_CALLER[real_key2] = saved2

    # 5. recorded in docs/occtswift-wrapping-gaps.md -> deliberate, recorded; removing the name
    #    from that text flips it to under.
    v, _n = classify("FakeGapClass", False, [], gaps_with)
    check("5a. name present in gaps_text -> deliberate, recorded", v, "deliberate, recorded")
    v, _n = classify("FakeGapClass", False, [], gaps_without)
    check("5b. name absent from gaps_text -> under (mechanism is load-bearing)", v, "under")

    return ok


def _selftest_over_coverage() -> bool:
    """Each accepting shape of find_over_coverage_candidates(), proven on an in-memory fixture
    (no real file touched): a claim-word hit needs BOTH a claim word and an OCCT-class mention on
    a COMMENT line; a numeric hit needs a tolerance-shaped number and a class mention, also on a
    comment line. Each of the three requirements is disabled in turn."""
    ok = True

    def check(label, got, want):
        nonlocal ok
        passed = got == want
        print(f"  {label}: {'PASS' if passed else 'FAIL'} (got {got!r}, want {want!r})")
        if not passed:
            ok = False

    def scan(text):
        fixture = {"FakeTarget": {"Fixture.swift": text}}
        return find_over_coverage_candidates(lane_targets=fixture)

    positive_claim = "    /// `TopoDS_Shape::IsSame` always returns true for aliased handles.\n"
    hits = scan(positive_claim)
    check("baseline claim+class comment -> 1 hit", len(hits), 1)

    no_class = "    /// This always holds for the result.\n"
    hits = scan(no_class)
    check("claim word, no OCCT class -> 0 hits (class-mention gate is load-bearing)", len(hits), 0)

    no_claim = "    /// This code calls TopoDS_Shape::IsSame somewhere.\n"
    hits = scan(no_claim)
    check("OCCT class, no claim word or number -> 0 hits (claim gate is load-bearing)", len(hits),
          0)

    # A trailing `//` comment on a CODE line is deliberately NOT counted: `is_comment_line` tests
    # the WHOLE line, matching this repo's own `_is_comment` convention elsewhere (#808's census).
    # Proven wrong once already during this pass's own --self-test: the first version of this case
    # passed a fixture with no real claim-word/class-name boundary in it at all
    # (`alwaysTrueForTopoDS_Shape()`, one unbroken identifier with no word boundary before either
    # token), so it reported 0 hits whether or not the comment gate existed -- decorative, not
    # load-bearing. Injecting the real defect (removing the gate in `find_over_coverage_
    # candidates`) against that fixture still passed self-test, which is what caught it. This
    # fixture's tokens have real boundaries on both sides (`= TopoDS_Shape.self`, `// always
    # true`), so the gate is what makes the difference, confirmed by re-running the same injection
    # against this version and watching it fail before restoring the gate.
    not_a_comment = "    let x = TopoDS_Shape.self  // always true, TopoDS_Shape guarantee\n"
    hits = scan(not_a_comment)
    check("claim+class only via a TRAILING comment, not a whole comment line -> 0 hits "
          "(comment gate is load-bearing)", len(hits), 0)
    # The positive counterpart: a plain `//` (not `///`) WHOLE comment line is still detected.
    hits = scan("    // BRep_Tool::Tolerance is exactly 1e-7 here, always.\n")
    check("plain `//` comment line also detected", len(hits), 1)

    positive_numeric = "    // BRepGProp::SurfaceProperties Eps default is 1.0e-3 here.\n"
    hits = scan(positive_numeric)
    check("numeric-tolerance + class comment -> 1 hit", len(hits), 1)
    numeric_kind = hits[0][4] if hits else None
    check("...classified as 'numeric', not 'claim'", numeric_kind, "numeric")

    numeric_no_class = "    // The default is 1.0e-3 here.\n"
    hits = scan(numeric_no_class)
    check("number, no OCCT class -> 0 hits", len(hits), 0)

    return ok


def self_test() -> int:
    print("classify() removal matrix:")
    ok1 = _selftest_classify()
    print()
    print("find_over_coverage_candidates() removal matrix:")
    ok2 = _selftest_over_coverage()
    print()
    if ok1 and ok2:
        print("ALL SELF-TEST CASES PASS")
        return 0
    print("SELF-TEST FAILURE (see FAIL rows above)")
    return 1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--verbose", action="store_true")
    ap.add_argument("--over-coverage", action="store_true", help="run only the over-coverage sweep")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()

    if args.self_test:
        return self_test()
    if args.over_coverage:
        return check_over_coverage(args.verbose)

    rc1 = main_census(args.verbose)
    print()
    rc2 = check_over_coverage(args.verbose)
    return rc1 or rc2


if __name__ == "__main__":
    sys.exit(main())
