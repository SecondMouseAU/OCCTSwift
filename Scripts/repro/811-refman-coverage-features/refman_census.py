#!/usr/bin/env python3
"""Issue #811 (Pass 4a of #807): refman coverage census for the features lane.

WHY A SCRIPT, NOT A LIST IN THE ISSUE: `docs/v2.0.0-plan.md`'s census rule, and this repo's history
of hand-built censuses that were confidently wrong differently each time (#558, #571, #573, #583,
#595, #507, #553, #562).

THE LANE WAS RE-DERIVED BY CALL, NOT BY KEYWORD, and it moved. #811's own `## Lane` names six OCCT
packages: `BRepFeat_`, `BRepFilletAPI_`, `BRepOffsetAPI_`, `ChFi2d_`/`ChFi3d_`, `LocOpe_`, 97
headers. Pass 4a (#385) separately settled a nine-file Swift lane. Resolving the two against each
other is the first thing this census does, and the derivation is in `derive_lane.py` next to this
file rather than asserted here:

  - The nine Swift files call **60** distinct bridge functions, not the 32 #385's own scope section
    claims. The count in that section was taken when `GDTInfo.swift` was 29 lines; it is now
    `GDTRead.swift` and several hundred lines longer. `derive_lane.py` prints the current
    figures and they move, so they are not repeated here.
  - Those 60 land in six `.mm` files: `OCCTBridge_Document.mm` 32 (all GD&T),
    `OCCTBridge_ProjLib_NLPlate.mm` 15 (all Plate), `OCCTBridge_Curve3D.mm` 6 (Helix),
    `OCCTBridge_Topology.mm` 4, `OCCTBridge_BRepGraph.mm` 2, and `OCCTBridge_Modeling.mm` **1**
    (`OCCTShapeBuildThreadCutter`). The inversion #385 warns about is visible in that last figure:
    `OCCTBridge_Modeling.mm`, the file its first scope pointed at, backs one of the lane's calls.
  - Four more packages are audited here, each for its own reason rather than as a block, and the
    reasons are not equally strong. `Plate_` is reached by the lane's own calls: the 15
    `OCCTPlate*` ones construct `Plate_*` and nothing else. `NLPlate_` and `GeomPlate_` are
    constructed in `OCCTBridge_ProjLib_NLPlate.mm`, the one bridge file #385 assigns to this
    lane whole, but by functions the lane's own Swift files do not call, so that is a FILE
    claim rather than a call claim and is stated as one. `BRepMAT2d_` is reached by neither: it
    sits in `OCCTBridge_Geom2d.mm` behind `MedialAxis.swift`, and is audited here because the
    medial axis is the nearest subject to this lane and no pass names it, which is a judgement
    rather than a measurement. Grepping all seventeen sub-issue bodies of #807 for the four
    prefixes returns them from **no pass at all**; the only issue that names them is #1021, a
    follow-up rather than a lane owner.

WIDER, then: ten packages, 129 classes, against #811's own six and 97. Leaving the four out would
repeat #382/#384's failure shape, which #810's review calls this programme's characteristic
defect, and the bullet above says which of the four rests on a call, which on a file, and which
on a judgement.

NARROWER, and handed off BY NAME rather than silently skipped. Fifteen further packages sit below
this lane's public API and are named by no pass either. They are the blend solver, the offset
engine, the draft engine, the medial-axis substrate and the sweep/fill family:

    package        headers  bridge-named  docs-named
    BRepBlend           43             0           1
    Blend               13             0           0
    BlendFunc           22             0           1
    ChFiDS              27             2           4
    ChFiKPart           15             0           0
    BRepOffset          18             6           6
    Draft                9             1           2
    BiTgte               4             2           2
    MAT                 18             3           3
    MAT2d               18             0           0
    Bisector            11             5           5
    BRepFill            46            12          13
    GeomFill            68            37          31
    AdvApp2Var          18             0           2
    AdvApprox            7             0           1
    TOTAL              337            68          71

copied from `derive_lane.py --substrate`'s own output rather than typed, which is not a stylistic
note: the first version of this table was typed from a scratch measurement that omitted the six
bare `<Pkg>.hxx` package headers (`Bisector`, `BlendFunc`, `BRepFill`, `BRepOffset`, `Draft`,
`GeomFill`), and read 331 where the script says 337. That is 337 headers, more than twice this
lane, and auditing them properly means auditing a different subject: the algorithms below the API
rather than the API a CAD consumer names. `BRepFill_` and `GeomFill_` in particular are heavily
wrapped (12 and 37 classes named in the bridge) and want a lane of their own rather than a corner
of this one. Filed as #1045 so the handoff is recorded rather than dropped.

TWO QUESTIONS, per #811:

  UNDER-COVERAGE: an OCCT class in the lane we neither wrap (name it on a line of
  `Sources/OCCTBridge/{src/*.mm,include/*.h}` that does not START with `#include`, `//`, `*` or
  `/*`) nor document (name it anywhere under `docs/` except `docs/CHANGELOG.md`, a historical
  record of what a past release changed rather than a claim about the current tree, and except
  `docs/occtswift-wrapping-gaps.md`, whose whole subject is what is NOT wrapped), with no reason
  recorded in that gaps file.

  The wrapped test is deliberately spelled as "does not start with" rather than "is not a
  comment": a class named in a TRAILING `//` comment, or on a `/* */` continuation line that
  does not begin with `*`, still counts as wrapped. Re-run with comments genuinely stripped,
  **zero of the 129 change verdict** and no method attribution resolves only through a comment,
  so the result stands; the looser rule is what ships because it is what #808/#810 use and a
  divergence here would make the four passes incomparable.

  Measured before this PR: 129 lane classes and 47 neither wrapped nor documented. Three of the
  129 were named in `docs/occtswift-wrapping-gaps.md`, and two of those three are genuine
  recorded omissions rather than incidental mentions: `ChFi3d_FilBuilder` and `ChFi3d_ChBuilder`
  share a bullet giving "complex stateful builders with protected virtuals" as the reason.
  (`BRepOffsetAPI_MakePipe`, the third, is named as a wrapped class.) All three classify `ok`
  anyway, because they are documented elsewhere under `docs/`, so none was ever one of the 47.
  The base verdicts are 82 ok, **0** deliberate and recorded, 47 under: of the classes that
  needed a reason, none had one. That is the single largest result of this pass and the reason
  it writes a section rather than a footnote.

  OVER-COVERAGE: something current docs assert that the pinned kernel does not support. Two
  mechanical detectors ran, and every candidate was adjudicated against the real bridge code:

    1. `Scripts/census-doc-occt-attribution.py --lane <this lane's prefixes>` (#928), the
       class-level detector. 19 candidates, 18 true, 1 false, a 5.3% false-positive rate on this
       lane against its own measured 41.0% over a uniform sample and #810's 47.1%. The single false
       positive is the cross-file shared-helper case: `occtPlateApproxSurface` is declared in
       `OCCTBridge_Internal.h` and defined in `OCCTBridge_ProjLib_NLPlate.mm`, so a caller in
       `OCCTBridge_Healing.mm` reaches `GeomPlate_MakeApprox` through it and the detector cannot
       follow.
    2. `check_method_attributions()` in this file, ported from #810's with two shapes added.
       #810's own copy still has neither and nothing there says so; that is recorded on #1044
       rather than by editing a closed pass's committed artifact. The first is a
       `using Alias = Template<...>;` header, where the members live in the template rather than
       in a base class; the second is propagating "cannot say" out of a base whose own header
       is not shipped, which the first needs to be any use. Without the pair the check reports 16
       false findings tree-wide on `BRepLProp_*` alone. 5 candidates in this lane, 5 true, 0
       false.

  Plus the claims neither detector can see, found by reading, which with 18 and 5 above make the
  total `main()` prints. The number is not stated here: this paragraph claimed eight twice and
  twelve once, and each figure was superseded by a later review round of this same pass. One is a behaviour claim settled by `probe_nlplate_parametrisation.mm` next to this file:
  `docs/reference/Surface-Advanced.md` said the NLPlate deformers preserve the input's
  parametrisation, and they do not. The rest are present-tense descriptions of a call path #783 or
  #784 replaced, spread across `FeatureRecognition.swift`, `docs/reference/FeatureRecognition.md`
  and three test files,
  all naming `OCCTFaceGetSharedEdgeCount`/`OCCTFaceGetSharedEdges`/`OCCTFacesAreAdjacent` as the
  current mechanism, or
  saying `buildGraph()` sizes a buffer at all, when it has made one
  `OCCTFaceGetSharedEdgeSummary` call since #783. Neither detector can see a tense, and neither
  looks at claims about a BRIDGE function rather than an OCCT class. The bridge header's own
  comments were correct throughout, in the past tense, which is what made the Swift-side copies
  checkable. Four came from this pass's first review round, two from its second, two from its
  third, and four more from its eighth, each of those rounds having written the set up as
  closed.

  The last four are the third group and the most useful, because each names a shape BOTH
  detectors are blind to. `withBoss` and `withPocket` carried the corrected `withPrism`
  claim in a bullet naming a class and no bridge function, which #928's walker files among
  its unresolved rather than among its findings, and which `check_method_attributions()`
  skips for want of a `::`. `nlPlateDerivative` named `NLPlate_NLPlate::Evaluate` where the
  bridge calls `EvaluateDerivative`, which the method check misses because `Evaluate` does
  exist: catching it needs a member-versus-member-called check, which nothing here has.

  Every finding is pinned below and the total is what `main()` derives from the two lists rather
  than a number written here.

  EIGHT OF THEM WERE FIXED ON `main` BY #1069 WHILE THIS BRANCH WAS IN REVIEW, all in the NLPlate
  family: the five `GeomPlate_MakeApprox` attributions, the three `NLPlate_HPGnConstraint` ones
  sharing three of those lines, the parametrisation Note and the `NLPlate_NLPlate::Evaluate`
  attribution on `nlPlateDerivative`. #1069 fixed the two underlying defects this pass filed as
  #1046 and #1049 and corrected the same doc claims in the process, more thoroughly than this pass
  had. Those eight are in `PRESENCE_EXEMPT_PINS` rather than dropped, because a regression to the
  wrong text would be as wrong tomorrow as it was when this pass found it, and the record of what
  the audit found should not shrink because someone else fixed it first.

  TWO SURVIVED #1069 AND ARE CORRECTED HERE, both self-contradictions inside entries #1069 itself
  edited: `docs/reference/Surface-Advanced.md` still called the solver's output a "displacement
  field" in two places, in the same entry whose own paragraph, added by #1069, explains that
  `NLPlate_NLPlate::Evaluate` seeds from the input surface's value and so returns the deformed point
  rather than an offset.

CLASSIFICATION RULES. Mechanical unless a class is in one of the curated tables, each entry
established during #811 by reading the pinned header and, where the contract was in question, the
refman through the `context` MCP at `occt-refman@8.0.1`. Never inferred from the class name.

  - DEPRECATED_COLLECTION_ALIASES: the header carries `Standard_HEADER_DEPRECATED` at file scope,
    saying the alias is deprecated since OCCT 8.0.0 and to use the `NCollection_*` template
    directly. 24 of the 129, and the largest single block.
  - ABSTRACT_BASES: a pure virtual, or a constructor declared only after `protected:`, in the
    pinned header. `BRepFeat_RibSlot` is the case a pure-virtual test alone misses: it has none,
    and its only constructor sits at `BRepFeat_RibSlot.hxx:113`, two lines after `protected:`.
  - ENUMS_READ_BY_VALUE: an enum the bridge reads only through its VALUES, so a test that looks
    for the type name misses it. `ChFi2d_ConstructionError` is the member:
    `builder.Status() != ChFi2d_IsDone` at ten sites, six in `OCCTBridge_Modeling.mm` and four in
    `OCCTBridge_Healing.mm`, which is why the category exists rather than the class being filed as
    an omission. The type name does occur in the bridge, in a bare `#include` the tokeniser skips
    by design; that is a different thing from not occurring, and an earlier draft of this entry
    said "appears nowhere in the bridge", which was wrong.
  - ENUMS_UNWRAPPED: an enum nothing in the tree reads, by value or by name.
  - COVERED_BY_SIBLING: the capability is reached through a different OCCT class.
    `BRepOffsetAPI_Sewing` is a one-line `typedef BRepBuilderAPI_Sewing`, and the sibling is
    wrapped.
  - PRIVATE_IMPLEMENTATION: a header that declares no class of its own name.
    `ChFi3d_Builder_0.hxx` is free helper functions for `ChFi3d_Builder.cxx`.
  - INTERNAL_HELPERS: a concrete class serving one already-wrapped entry point, with no
    independent use.
  - REACHED_UNNAMED: constructed and used, but never spelled, so a name-based wrapped test cannot
    see it. The class-level sibling of ENUMS_READ_BY_VALUE, and it exists because this pass's
    fifth review round found `Plate_LinearScalarConstraint` filed as a gap while the bridge
    loads three of them, one each from `Plate_PlaneConstraint::LSC()`,
    `Plate_LineConstraint::LSC()` and `Plate_FreeGtoCConstraint::LSC(i)`.
  - UNWRAPPED_CAPABILITY: a real gap, recorded as one. `Plate_SampledCurveConstraint` is the only
    `Plate_Plate::Load` overload no bridge function reaches by any route. Four of the nine are
    invoked directly and four more are reached by decomposition, so counting unreached overloads
    from the header alone gives five and is wrong.

The wrapped test runs BEFORE the curated tables, following #808 and #810 rather than #809: a table
entry claiming a class has no call sites must not be able to mask one that does.

ONE LIMITATION, stated rather than left to be found, and inherited from #808/#809/#810.
`deliberate, recorded` means the class NAME appears somewhere in
`docs/occtswift-wrapping-gaps.md`, not that the sentence around it is a reason. The mitigation here
is the same as #810's: every class this pass files as recorded is named in a bullet this pass
wrote, carrying its measured reason, so the name match and the reason coincide today. The test
still cannot tell the difference tomorrow.

Run from anywhere (paths derive from this file's location, not the cwd):

    python3 Scripts/repro/811-refman-coverage-features/refman_census.py
    python3 Scripts/repro/811-refman-coverage-features/refman_census.py --verbose
    python3 Scripts/repro/811-refman-coverage-features/refman_census.py --reverify-lane
    python3 Scripts/repro/811-refman-coverage-features/refman_census.py --verify-pins origin/main
    python3 Scripts/repro/811-refman-coverage-features/refman_census.py --self-test

Exits 1 on a `KNOWN_OVER_FINDINGS` regression, on a method attribution that names a member the
pinned headers do not declare, on an `under` with no `docs/occtswift-wrapping-gaps.md` line, on a
family-count drift, or on lane drift under `--reverify-lane`. Exits 0 otherwise.
"""

from __future__ import annotations

import argparse
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
BRIDGE_SRC = os.path.join(ROOT, "Sources", "OCCTBridge", "src")
BRIDGE_INC = os.path.join(ROOT, "Sources", "OCCTBridge", "include")
DOCS_DIR = os.path.join(ROOT, "docs")
GAPS_FILE = os.path.join(DOCS_DIR, "occtswift-wrapping-gaps.md")
OCCT_HEADERS = os.path.join(ROOT, "Libraries", "OCCT.xcframework", "macos-arm64", "Headers")

LANE_PACKAGES = ("BRepFeat", "BRepFilletAPI", "BRepOffsetAPI", "ChFi2d", "ChFi3d", "LocOpe",
                 "Plate", "NLPlate", "GeomPlate", "BRepMAT2d")

LANE_HEADER_RE = re.compile(
    r"^(BRepFeat|BRepFilletAPI|BRepOffsetAPI|ChFi2d|ChFi3d|LocOpe|Plate|NLPlate|GeomPlate"
    r"|BRepMAT2d)(_[^.]+)?\.hxx$")

# ------------------------------------------------------------------------------------------------
# The lane: 129 classes, enumerated from the pinned kernel's own headers (OCCT 8.0.1 plus the
# carried patches) on 2026-08-21. Re-derive with:
#
#   ls Libraries/OCCT.xcframework/macos-arm64/Headers \
#     | grep -E '^(BRepFeat|BRepFilletAPI|BRepOffsetAPI|ChFi2d|ChFi3d|LocOpe|Plate|NLPlate|GeomPlate|BRepMAT2d)(_[^.]+)?\.hxx$' \
#     | sed 's/\.hxx$//' | sort
#
# `--reverify-lane` runs exactly that derivation and diffs it against this list. A header that
# appears or disappears needs a hand audit of that class, not just a re-run: its wrapped/documented
# status is not knowable from this script.
# ------------------------------------------------------------------------------------------------

LANE_CLASSES: dict[str, list[str]] = {
    "BRepFeat": [
        "BRepFeat", "BRepFeat_Builder", "BRepFeat_Form", "BRepFeat_Gluer",
        "BRepFeat_MakeCylindricalHole", "BRepFeat_MakeDPrism", "BRepFeat_MakeLinearForm",
        "BRepFeat_MakePipe", "BRepFeat_MakePrism", "BRepFeat_MakeRevol",
        "BRepFeat_MakeRevolutionForm", "BRepFeat_PerfSelection", "BRepFeat_RibSlot",
        "BRepFeat_SplitShape", "BRepFeat_Status", "BRepFeat_StatusError",
    ],
    "BRepFilletAPI": [
        "BRepFilletAPI_LocalOperation", "BRepFilletAPI_MakeChamfer", "BRepFilletAPI_MakeFillet",
        "BRepFilletAPI_MakeFillet2d",
    ],
    "BRepMAT2d": [
        "BRepMAT2d_BisectingLocus", "BRepMAT2d_DataMapOfBasicEltShape",
        "BRepMAT2d_DataMapOfShapeSequenceOfBasicElt", "BRepMAT2d_Explorer",
        "BRepMAT2d_LinkTopoBilo",
    ],
    "BRepOffsetAPI": [
        "BRepOffsetAPI_DraftAngle", "BRepOffsetAPI_FindContigousEdges", "BRepOffsetAPI_MakeDraft",
        "BRepOffsetAPI_MakeEvolved", "BRepOffsetAPI_MakeFilling", "BRepOffsetAPI_MakeOffset",
        "BRepOffsetAPI_MakeOffsetShape", "BRepOffsetAPI_MakePipe", "BRepOffsetAPI_MakePipeShell",
        "BRepOffsetAPI_MakeThickSolid", "BRepOffsetAPI_MiddlePath",
        "BRepOffsetAPI_NormalProjection", "BRepOffsetAPI_SequenceOfSequenceOfReal",
        "BRepOffsetAPI_SequenceOfSequenceOfShape", "BRepOffsetAPI_Sewing",
        "BRepOffsetAPI_ThruSections",
    ],
    "ChFi2d": [
        "ChFi2d", "ChFi2d_AnaFilletAlgo", "ChFi2d_Builder", "ChFi2d_ChamferAPI",
        "ChFi2d_ConstructionError", "ChFi2d_FilletAPI", "ChFi2d_FilletAlgo",
    ],
    "ChFi3d": [
        "ChFi3d", "ChFi3d_Builder", "ChFi3d_Builder_0", "ChFi3d_ChBuilder", "ChFi3d_FilBuilder",
        "ChFi3d_FilletShape", "ChFi3d_SearchSing",
    ],
    "GeomPlate": [
        "GeomPlate_Aij", "GeomPlate_Array1OfHCurve", "GeomPlate_Array1OfSequenceOfReal",
        "GeomPlate_BuildAveragePlane", "GeomPlate_BuildPlateSurface", "GeomPlate_CurveConstraint",
        "GeomPlate_HArray1OfHCurve", "GeomPlate_HArray1OfSequenceOfReal",
        "GeomPlate_HSequenceOfCurveConstraint", "GeomPlate_HSequenceOfPointConstraint",
        "GeomPlate_MakeApprox", "GeomPlate_PlateG0Criterion", "GeomPlate_PlateG1Criterion",
        "GeomPlate_PointConstraint", "GeomPlate_SequenceOfAij",
        "GeomPlate_SequenceOfCurveConstraint", "GeomPlate_SequenceOfPointConstraint",
        "GeomPlate_Surface",
    ],
    "LocOpe": [
        "LocOpe", "LocOpe_BuildShape", "LocOpe_BuildWires", "LocOpe_CSIntersector",
        "LocOpe_CurveShapeIntersector", "LocOpe_DPrism", "LocOpe_DataMapOfShapePnt",
        "LocOpe_FindEdges", "LocOpe_FindEdgesInFace", "LocOpe_GeneratedShape", "LocOpe_Generator",
        "LocOpe_GluedShape", "LocOpe_Gluer", "LocOpe_LinearForm", "LocOpe_Operation",
        "LocOpe_Pipe", "LocOpe_PntFace", "LocOpe_Prism", "LocOpe_Revol", "LocOpe_RevolutionForm",
        "LocOpe_SequenceOfCirc", "LocOpe_SequenceOfLin", "LocOpe_SequenceOfPntFace",
        "LocOpe_SplitDrafts", "LocOpe_SplitShape", "LocOpe_Spliter", "LocOpe_WiresOnShape",
    ],
    "NLPlate": [
        "NLPlate_HGPPConstraint", "NLPlate_HPG0Constraint", "NLPlate_HPG0G1Constraint",
        "NLPlate_HPG0G2Constraint", "NLPlate_HPG0G3Constraint", "NLPlate_HPG1Constraint",
        "NLPlate_HPG2Constraint", "NLPlate_HPG3Constraint", "NLPlate_NLPlate",
        "NLPlate_SequenceOfHGPPConstraint", "NLPlate_StackOfPlate",
    ],
    "Plate": [
        "Plate_Array1OfPinpointConstraint", "Plate_D1", "Plate_D2", "Plate_D3",
        "Plate_FreeGtoCConstraint", "Plate_GlobalTranslationConstraint", "Plate_GtoCConstraint",
        "Plate_HArray1OfPinpointConstraint", "Plate_LineConstraint",
        "Plate_LinearScalarConstraint", "Plate_LinearXYZConstraint", "Plate_PinpointConstraint",
        "Plate_PlaneConstraint", "Plate_Plate", "Plate_SampledCurveConstraint",
        "Plate_SequenceOfLinearScalarConstraint", "Plate_SequenceOfLinearXYZConstraint",
        "Plate_SequenceOfPinpointConstraint",
    ],
}

# The docstring's per-package totals, repeated as data so `main()` can diff them against the table.
# Two of #810's six were wrong when typed by hand in a prose block read three times.
FAMILY_COUNTS = {
    "BRepFeat": 16, "BRepFilletAPI": 4, "BRepMAT2d": 5, "BRepOffsetAPI": 16, "ChFi2d": 7,
    "ChFi3d": 7, "GeomPlate": 18, "LocOpe": 27, "NLPlate": 11, "Plate": 18,
}
LANE_TOTAL = 129

# ------------------------------------------------------------------------------------------------
# Curated classification tables. Each reason was read off the pinned header during #811.
# ------------------------------------------------------------------------------------------------

DEPRECATED_COLLECTION_ALIASES = {
    c: "file-scope Standard_HEADER_DEPRECATED, deprecated since OCCT 8.0.0, use NCollection directly"
    for c in [
        "BRepMAT2d_DataMapOfBasicEltShape", "BRepMAT2d_DataMapOfShapeSequenceOfBasicElt",
        "BRepOffsetAPI_SequenceOfSequenceOfReal", "BRepOffsetAPI_SequenceOfSequenceOfShape",
        "GeomPlate_Array1OfHCurve", "GeomPlate_Array1OfSequenceOfReal",
        "GeomPlate_HArray1OfHCurve", "GeomPlate_HArray1OfSequenceOfReal",
        "GeomPlate_HSequenceOfCurveConstraint", "GeomPlate_HSequenceOfPointConstraint",
        "GeomPlate_SequenceOfAij", "GeomPlate_SequenceOfCurveConstraint",
        "GeomPlate_SequenceOfPointConstraint", "LocOpe_DataMapOfShapePnt", "LocOpe_SequenceOfCirc",
        "LocOpe_SequenceOfLin", "LocOpe_SequenceOfPntFace", "NLPlate_SequenceOfHGPPConstraint",
        "NLPlate_StackOfPlate", "Plate_Array1OfPinpointConstraint",
        "Plate_HArray1OfPinpointConstraint", "Plate_SequenceOfLinearScalarConstraint",
        "Plate_SequenceOfLinearXYZConstraint", "Plate_SequenceOfPinpointConstraint",
    ]
}

ABSTRACT_BASES = {
    "BRepFeat_Form": "pure virtual, the shared base of the BRepFeat_Make* forms",
    "BRepFeat_RibSlot": "constructor declared after protected: at BRepFeat_RibSlot.hxx:113",
    "BRepFilletAPI_LocalOperation": "pure virtual, the base MakeFillet and MakeChamfer share",
    "LocOpe_GeneratedShape": "pure virtual, protected constructor",
    "NLPlate_HGPPConstraint": "pure virtual, protected constructor, the NLPlate constraint base",
}

ENUMS_READ_BY_VALUE = {
    "ChFi2d_ConstructionError": "values read by value: ten `!= ChFi2d_IsDone` sites, six in "
                                "OCCTBridge_Modeling.mm and four in OCCTBridge_Healing.mm",
}

ENUMS_UNWRAPPED = {
    "BRepFeat_PerfSelection": "protected on both BRepFeat_Form and BRepFeat_RibSlot with no "
                              "public accessor anywhere, so genuinely unreachable rather than "
                              "merely unsurfaced, unlike the two enums beside it",
    "BRepFeat_StatusError": "BRepFeat_Form::CurrentStatusError is PUBLIC and inherited by the "
                            "three BRepFeat_Make* forms the bridge constructs; the bridge does "
                            "not read it, so this is unsurfaced rather than unreachable",
    "LocOpe_Operation": "the return type of LocOpe_Gluer::OpeType and BRepFeat_Gluer::OpeType, "
                        "both public getters on classes the bridge constructs; unsurfaced "
                        "rather than unreachable",
}

COVERED_BY_SIBLING = {
    "BRepOffsetAPI_Sewing": "one-line typedef of BRepBuilderAPI_Sewing, which is wrapped",
}

PRIVATE_IMPLEMENTATION = {
    "ChFi3d_Builder_0": "declares no class of its own name, free helpers for ChFi3d_Builder.cxx",
}

INTERNAL_HELPERS = {
    "BRepMAT2d_LinkTopoBilo": "maps BRepMAT2d_Explorer input back to MAT_BasicElt",
    "ChFi3d_SearchSing": "a math_FunctionWithDerivative ChFi3d_Builder solves internally",
    "GeomPlate_Aij": "two normal indexes and their cross product, GeomPlate_BuildAveragePlane's own record",
    "GeomPlate_PlateG0Criterion": "an AdvApp2Var_Criterion GeomPlate_MakeApprox constructs for itself",
    "GeomPlate_PlateG1Criterion": "an AdvApp2Var_Criterion GeomPlate_MakeApprox constructs for itself",
    "LocOpe_Generator": "the generator BRepFeat_Gluer drives",
    "LocOpe_GluedShape": "the LocOpe_GeneratedShape subclass BRepFeat_Gluer drives",
}

REACHED_UNNAMED = {
    "Plate_LinearScalarConstraint": "constructed and loaded, never named: Plate_PlaneConstraint, "
                                    "Plate_LineConstraint and Plate_FreeGtoCConstraint each hand "
                                    "one back from LSC(), and the bridge loads that at three "
                                    "p->Load(...LSC()) sites in OCCTBridge_ProjLib_NLPlate.mm "
                                    "(grep, not a line number: #1069 moved all three)",
}

UNWRAPPED_CAPABILITY = {
    "Plate_SampledCurveConstraint": "Plate_Plate::Load overload 7 of 9, the only one whose "
                                    "capability no bridge function reaches by any route",
    "NLPlate_HPG1Constraint": "the no-G0 tangent constraint, a different capability from the "
                              "HPG0G1Constraint the bridge builds, not a spelling of it",
    "NLPlate_HPG2Constraint": "the no-G0 curvature constraint, sibling of the above",
    "NLPlate_HPG3Constraint": "the no-G0 third-derivative constraint, sibling of the above",
}

CURATED: dict[str, tuple[str, str]] = {}
for _table, _label in (
    (DEPRECATED_COLLECTION_ALIASES, "DEPRECATED_COLLECTION_ALIASES"),
    (ABSTRACT_BASES, "ABSTRACT_BASES"),
    (ENUMS_READ_BY_VALUE, "ENUMS_READ_BY_VALUE"),
    (ENUMS_UNWRAPPED, "ENUMS_UNWRAPPED"),
    (COVERED_BY_SIBLING, "COVERED_BY_SIBLING"),
    (PRIVATE_IMPLEMENTATION, "PRIVATE_IMPLEMENTATION"),
    (INTERNAL_HELPERS, "INTERNAL_HELPERS"),
    (REACHED_UNNAMED, "REACHED_UNNAMED"),
    (UNWRAPPED_CAPABILITY, "UNWRAPPED_CAPABILITY"),
):
    for _cls, _why in _table.items():
        CURATED[_cls] = (_label, _why)

# ------------------------------------------------------------------------------------------------
# The over-coverage findings this PR fixed. The count is DERIVED below, not stated here: this
# header said "31 across 28 strings" for two rounds after the list grew past it, which is the
# same drift the derivation comment further down was added to stop. Each entry is the WRONG
# text as it stood on
# `main` before the fix; the check fails if any of them comes back. Whitespace is collapsed on
# both sides, so re-wrapping a wrong sentence across a line break still counts as a regression.
# ------------------------------------------------------------------------------------------------

KNOWN_OVER_FINDINGS: list[tuple[str, str]] = [
    # (file, the wrong text)
    ("docs/reference/Document-Analysis-Builders.md",
     "- **OCCT:** `Plate_FreeGthenCConstraint` (G1) via `OCCTPlateLoadFreeG1Constraint`."),
    ("docs/reference/Document-Completions.md",
     "- **OCCT:** `BRepOffsetAPI_MakePipeShell::GetStatus`."),
    ("docs/reference/Document-Completions.md",
     "- **OCCT:** `BRepOffsetAPI_MakePipeShell::Simulate`."),
    ("docs/reference/Shape-Features.md",
     "- **OCCT:** `BRepFeat_MakePrism` + `BRepAlgoAPI_Fuse` or `BRepAlgoAPI_Cut`."),
    ("docs/reference/Shape-Features.md",
     "- **OCCT:** `GeomPlate_BuildPlateSurface` + `NLPlate_NLPlate` + `GeomPlate_MakeApprox` "
     "(via `OCCTShapePlatePointsAdvanced`)."),
    ("docs/reference/Shape-Healing.md",
     "- **OCCT:** `BRepOffsetAPI_NormalProjection` with direction (via `OCCTShapeProjectWire`)."),
    ("docs/reference/Shape-Healing.md",
     "- **OCCT:** `BRepOffsetAPI_NormalProjection` (via `OCCTShapeProjectWire`)."),
    ("docs/reference/Shape-Healing.md",
     "- **OCCT:** `BRepOffsetAPI_NormalProjection` with point source "
     "(via `OCCTShapeProjectWireConical`)."),
    ("docs/reference/Shape-Healing.md",
     "- **OCCT:** `BRepOffsetAPI_NormalProjection` (via `OCCTShapeProjectWireConical`)."),
    ("docs/reference/Shape-Measurement.md",
     "- **OCCT:** `BRepOffsetAPI_MakeThickSolid` (via `OCCTShapeOffsetPerFace`)."),
    ("docs/reference/Document-Builders-Fillet.md",
     "- **OCCT:** `BRepFilletAPI_MakeChamfer::IsDistAngle` (via `OCCTChamferBuilderIsDistAngle`)."),
    ("docs/reference/Document-Builders-Fillet.md",
     "- **OCCT:** `BRepFilletAPI_MakeChamfer::GetDists` (via `OCCTChamferBuilderGetDists`)."),
    ("docs/reference/Document-Builders-Fillet.md",
     "- **OCCT:** `BRepFilletAPI_MakeChamfer::IsSymmetric` (via `OCCTChamferBuilderIsSymmetric`)."),
    ("docs/reference/Document-Builders-Fillet.md",
     "- **OCCT:** `BRepFilletAPI_MakeChamfer::IsTwoDists` (via `OCCTChamferBuilderIsTwoDists`)."),
    ("docs/reference/Document-Builders-Fillet.md",
     "- **OCCT:** `BRepFilletAPI_MakeFillet::NbSimulatedSurf` "
     "(via `OCCTFilletBuilderNbSimulatedSurf`)."),
    # Three present-tense claims describing the pre-#783 call path. Neither detector can see a
    # tense, and neither can see a claim about a BRIDGE function rather than an OCCT class; these
    # came from reading, and are the same shape as #810's flagship finding.
    ("Sources/OCCTSwift/FeatureRecognition.swift",
     "Fixed at the root, in the SAME direct call this type already makes: a new "
     "`OCCTFaceGetSharedEdgeCount` sizes the buffer exactly before `OCCTFaceGetSharedEdges` "
     "fills it,"),
    ("Sources/OCCTSwift/FeatureRecognition.swift",
     "now sizes that buffer from `OCCTFaceGetSharedEdgeCount` instead of a fixed 10, so"),
    ("docs/reference/FeatureRecognition.md",
     "a new `OCCTFaceGetSharedEdgeCount` now sizes the buffer exactly before it is filled."),
    # Two more of the same shape, found by this pass's SECOND review round after the three above
    # had been counted as the whole set. That is the argument for pinning them rather than only
    # fixing them: the family kept producing members after it had been declared closed.
    ("Sources/OCCTSwift/FeatureRecognition.swift",
     "face-to-face incidence to query instead. `OCCTFaceGetSharedEdges` compares only the two"),
    ("Tests/OCCTModelingTests/Issue761SharedEdgeCountCapTests.swift",
     "Fixed by sizing the buffer from a new `OCCTFaceGetSharedEdgeCount` bridge call first, in "
     "`AAG.buildGraph()` itself"),
    # And two more, from the THIRD review round, both in the same test file the second round had
    # just edited. Seven members now, found across three rounds, each of which had written up the
    # set as closed. That is the whole argument for pinning a family rather than fixing its members.
    ("Tests/OCCTModelingTests/Issue761SharedEdgeCountCapTests.swift",
     "not through `AAG`, which always sizes its own buffer from the true count now, so this "
     "specific disagreement is not otherwise observable"),
    ("Tests/OCCTModelingTests/Issue761SharedEdgeCountCapTests.swift",
     "the buffer fully populated. This is what AAG.buildGraph() does today."),
    # Round eight, and the four below are the ones that say most about the detectors' shape.
    #
    # `withBoss` and `withPocket` are convenience wrappers that call `withPrism` verbatim, and
    # carried the SAME `BRepFeat_MakePrism` claim this pass corrected on `withPrism` itself, twenty
    # lines above them. Neither detector can see them: #928's walker needs a bridge function to
    # resolve and a bullet reading `- **OCCT:** \`Class\` (fuse mode).` names none, so it lands
    # among the 193 "unresolved" rather than among the findings; and `check_method_attributions()`
    # needs a `::`. A doc claim naming a class and no member and no bridge function is the shape
    # BOTH detectors are blind to, and it is not a rare shape.
    ("docs/reference/Shape-Features.md",
     "- **OCCT:** `BRepFeat_MakePrism` (fuse mode)."),
    ("docs/reference/Shape-Features.md",
     "- **OCCT:** `BRepFeat_MakePrism` (cut mode)."),
    # `nlPlateDerivative`'s own summary called the result a displacement field. Its sibling finding,
    # the `- **OCCT:** NLPlate_NLPlate::Evaluate` attribution where the bridge calls
    # `EvaluateDerivative`, is in PRESENCE_EXEMPT_PINS instead, because #1069 corrected it on `main`
    # first. That one was invisible to `check_method_attributions()` for the opposite reason to the
    # five chamfer findings: `Evaluate` IS declared, so only a member-versus-member-called check
    # would catch it, and no such check exists here.
    ("docs/reference/Surface-Advanced.md",
     "Evaluates the partial derivative of the NLPlate G0 displacement field at a UV point."),
    # Round eleven, found by diffing every removed line on the branch against this list rather than
    # by reading. Four corrections had been made and never pinned, two of them the prose half of
    # the flagship #1046 finding whose one-sentence twin WAS pinned, and two of them round ten's
    # own additions to the family this file argues hardest for pinning. A list assembled by hand
    # from what each round remembered fixing is not the same as a list of what the branch changed.
    ("docs/reference/Surface-Advanced.md",
     "computes a displacement field on the existing surface; the result preserves the original shape"),
    ("Tests/OCCTModelingTests/Issue699AAGSolidScopedAdjacencyTests.swift",
     "`OCCTEdgeGetConvexity` (`OCCTBridge_BRepGraph.mm`) test two `TopoDS_Face` values purely on "
     "their own edge geometry"),
    ("Tests/OCCTModelingTests/Issue642AAGNodeIdentityTests.swift",
     "Without the identity guard in `buildGraph()`, `OCCTFacesAreAdjacent` reports every one of a "
     "face's own boundary edges"),
    ("Tests/OCCTModelingTests/Issue761SharedEdgeCountCapTests.swift",
     "#761: investigating whether AAG's hand-rolled pairwise face/edge adjacency "
     "(`OCCTFacesAreAdjacent`/`OCCTFaceGetSharedEdges`/`OCCTEdgeGetConvexity`) duplicates"),
]

# Pins that are still worth holding but cannot be verified PRESENT at the base revision, so they are
# checked for absence exactly like `KNOWN_OVER_FINDINGS` and excluded from `--verify-pins`. Two
# reasons put an entry here, and the distinction matters:
#
#   FIXED INDEPENDENTLY. Eight of this pass's findings, all in the NLPlate family, were corrected on
#   `main` by #1069 while this branch was in review. They were real when found (the pass's own
#   `--verify-pins` run against the then-current base is what proved it), and the correct text is on
#   `main` now, so asking whether the WRONG text is still there is the wrong question. They stay
#   pinned because a regression would be as wrong tomorrow as it was then.
#
#   WRITTEN BY THIS PASS. Two claims this pass introduced and then corrected, which were never on any
#   base revision at all.
#
# The member is round one's own summary of #1049: "Any surface not through the origin is affected"
# told a caller whose surface sits at the origin that they were safe. Round twelve measured that
# the double-add is `2 * base + plate` at every sampled point, so the patch also comes back at
# twice its intended SIZE, and a plane through the origin returns 40 by 40 where 20 by 20 was
# asked for. The probe that supported the wrong version measured one off-origin fixture and printed
# no corners for the origin ones, which is the whole reason it survived four rounds.
PRESENCE_EXEMPT_PINS: list[tuple[str, str]] = [
    ("Sources/OCCTSwift/Surface.swift",
     "Uses the non-linear plate solver to compute a displacement field on"),
    ("docs/reference/Surface-Advanced.md",
     "- **OCCT:** `NLPlate_NLPlate` + `NLPlate_HPG0Constraint` + `GeomPlate_MakeApprox`."),
    ("docs/reference/Surface-Advanced.md",
     "- **OCCT:** `NLPlate_NLPlate` + `NLPlate_HPG1Constraint` + `GeomPlate_MakeApprox`."),
    ("docs/reference/Surface-Advanced.md",
     "- **OCCT:** `NLPlate_NLPlate` + `NLPlate_HPG2Constraint` + `GeomPlate_MakeApprox`."),
    ("docs/reference/Surface-Advanced.md",
     "- **OCCT:** `NLPlate_NLPlate` + `NLPlate_HPG3Constraint` + `GeomPlate_MakeApprox`."),
    ("docs/reference/Surface-Advanced.md",
     "- **OCCT:** `NLPlate_NLPlate::IncrementalSolve` + `GeomPlate_MakeApprox`."),
    ("docs/reference/Surface-Advanced.md",
     "- **Note:** Distinct from fitting a fresh surface to a point set, the existing parametrisation "
     "is preserved."),
    ("docs/reference/Surface-Advanced.md",
     "- **OCCT:** `NLPlate_NLPlate::Evaluate`."),
    ("docs/reference/Surface-Advanced.md",
     "Any surface not through the origin is affected."),
    ("Sources/OCCTSwift/Surface.swift",
     "so a surface away from the origin comes back at double its distance"),
]

# The subset of the above that this pass WROTE, as opposed to found and had fixed under it. Named
# so `main()` can derive the split instead of printing a hardcoded "eight and two" beside a derived
# total, which is the drift this file has already corrected three times in its own prose.
SELF_INTRODUCED: list[tuple[str, str]] = PRESENCE_EXEMPT_PINS[-2:]

# THREE of the Surface-Advanced entries above carry two findings each, not four: the G1, G2 and G3
# lines each name both a wrong constraint class and a wrong approximator, while the HPG0 and
# IncrementalSolve lines name only the approximator. Named rather than counted, and the total is
# DERIVED from them, because the hand-typed version of this said four and did not reconcile with the
# hand-typed total beside it. Now neither number can drift from the list.
DOUBLE_CARRIER_MARKERS = (
    "`NLPlate_HPG1Constraint`",
    "`NLPlate_HPG2Constraint`",
    "`NLPlate_HPG3Constraint`",
)


def _double_carriers() -> int:
    """Pinned strings that record two findings, not one, across BOTH lists.

    Both, because the three that carry two (the G1, G2 and G3 attributions, each naming a wrong
    constraint class AND a wrong approximator) moved to the presence-exempt list when #1069 fixed
    them on `main`. Counting only the first list would drop three real findings from the total the
    moment another PR fixed them independently, which is the wrong direction for a number that is
    meant to say what this pass found.
    """
    return sum(1 for _rel, wrong in KNOWN_OVER_FINDINGS + PRESENCE_EXEMPT_PINS
               if any(m in wrong for m in DOUBLE_CARRIER_MARKERS))


KNOWN_OVER_FINDING_COUNT = (len(KNOWN_OVER_FINDINGS) + len(PRESENCE_EXEMPT_PINS)
                            + _double_carriers())

METHOD_ATTRIBUTION_ALLOWED: set[tuple[str, str]] = set()

_ATTRIBUTION_RE = re.compile(
    r"`([A-Za-z][A-Za-z0-9]*(?:_[A-Za-z0-9]+)?)::([A-Za-z_][A-Za-z0-9_]*)"
)


# ------------------------------------------------------------------------------------------------
# Measurement
# ------------------------------------------------------------------------------------------------

def _read(path: str) -> str:
    with open(path, errors="ignore") as fh:
        return fh.read()


_COMMENT_PREFIX_RE = re.compile(r"^\s*(?:///|//!|//|\*(?!/))\s?")


def _collapse(text: str) -> str:
    """Whitespace-collapse, after stripping each line's leading comment marker.

    Collapsing whitespace alone is enough for `docs/`, and is not enough for a claim that lives in
    a `///` doc comment: the marker sits mid-string once the newlines go, so a pinned finding
    spanning two comment lines never matches its own file. Measured, not reasoned: when there were
    24 strings, 23 fired against the pre-correction tree and the one that did not was exactly that
    shape.
    """
    lines = [_COMMENT_PREFIX_RE.sub("", ln) for ln in text.splitlines()]
    return " ".join(" ".join(lines).split())


def _lane_class_names() -> set[str]:
    return {c for classes in LANE_CLASSES.values() for c in classes}


def _bridge_files() -> list[str]:
    out = []
    for d in (BRIDGE_SRC, BRIDGE_INC):
        if not os.path.isdir(d):
            continue
        for fn in sorted(os.listdir(d)):
            p = os.path.join(d, fn)
            if os.path.isfile(p) and fn.endswith((".mm", ".h")):
                out.append(p)
    return out


def _doc_files() -> list[str]:
    out = []
    for dirpath, _dirs, files in os.walk(DOCS_DIR):
        for fn in sorted(files):
            if fn.endswith(".md") and fn != "CHANGELOG.md":
                out.append(os.path.join(dirpath, fn))
    return out


_TOKEN_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def named_in_bridge(cls: str, cache) -> list[str]:
    """Named on a bridge line that is neither a bare `#include` nor a comment."""
    return sorted(cache["bridge_tokens"].get(cls, set()))


def named_in_docs(cls: str, cache) -> list[str]:
    return sorted(cache["doc_tokens"].get(cls, set()))


def build_cache():
    """Tokenise every file once.

    The direct form, one `\\bClass\\b` search per class per line, is 129 classes against ~99k
    bridge lines plus ~60k doc lines and takes minutes. Inverting it to one token pass per file,
    then a dict lookup per class, gives the identical answer in about a second: the token pattern
    `[A-Za-z_][A-Za-z0-9_]*` and a `\\b`-anchored search agree exactly on OCCT class names, which
    are themselves made only of those characters.
    """
    cache: dict = {"bridge_tokens": {}, "doc_tokens": {}, "docs": [], "bridge": []}
    for path in _bridge_files():
        rel = os.path.relpath(path, ROOT)
        for line in _read(path).splitlines():
            stripped = line.strip()
            # `#import` as well as `#include`: this bridge writes both, and a header brought
            # in by the one the skip list omitted would have counted as a wrapped mention.
            # Measured on this lane before adding it: 0 of the 129 verdicts move.
            if stripped.startswith(("#include", "#import", "//", "*", "/*")):
                continue
            for tok in _TOKEN_RE.findall(stripped):
                cache["bridge_tokens"].setdefault(tok, set()).add(rel)
    for path in _doc_files():
        rel = os.path.relpath(path, ROOT)
        text = _read(path)
        cache["docs"].append((rel, text))
        if os.path.abspath(path) == os.path.abspath(GAPS_FILE):
            # The reasons-for-not-wrapping file is not evidence that something IS wrapped or
            # documented as a capability. See classify()'s docstring.
            continue
        for tok in _TOKEN_RE.findall(text):
            cache["doc_tokens"].setdefault(tok, set()).add(rel)
    cache["gaps"] = _read(GAPS_FILE) if os.path.exists(GAPS_FILE) else ""
    return cache


def recorded_in_gaps(cls: str, cache) -> bool:
    return bool(re.search(r"\b" + re.escape(cls) + r"\b", cache["gaps"]))


def classify(cls: str, cache) -> tuple[str, str, list[str], list[str]]:
    """(verdict, note, bridge hits, docs hits).

    Order: wrapped, then the curated tables, then documented, then `under`. Both of the first two
    positions were established by measurement rather than taste.

    WRAPPED FIRST, following #808 and #810: a table entry claiming a class has no call sites must
    not be able to mask one that does.

    CURATED BEFORE DOCUMENTED, and this is the one that bit. `docs/occtswift-wrapping-gaps.md` is
    itself under `docs/`, so the moment this pass wrote a reason for all 47 of the lane's
    omissions, a plain "named anywhere under docs/" test read every one of them as DOCUMENTED and
    the table came back 129 ok, 0 under, 0 recorded. A file whose whole subject is what is NOT
    wrapped cannot also be the evidence that something IS. `named_in_docs` therefore excludes it
    outright, and the curated tables are consulted before the docs test regardless.
    """
    bridge = named_in_bridge(cls, cache)
    docs = named_in_docs(cls, cache)
    if bridge:
        note = "wrapped" if docs else "wrapped (undocumented by this exact class name)"
        return ("ok", note, bridge, docs)
    if cls in CURATED:
        label, why = CURATED[cls]
        if recorded_in_gaps(cls, cache):
            return ("deliberate, recorded", f"{label}: {why}", bridge, docs)
        return ("under", f"{label}: {why}, but no line in occtswift-wrapping-gaps.md",
                bridge, docs)
    if docs:
        return ("ok", "documented", bridge, docs)
    if recorded_in_gaps(cls, cache):
        return ("deliberate, recorded", "named in occtswift-wrapping-gaps.md, no curated table "
                "entry", bridge, docs)
    return ("under", "neither wrapped nor documented, and no reason recorded", bridge, docs)


# ------------------------------------------------------------------------------------------------
# Over-coverage checks
# ------------------------------------------------------------------------------------------------

def check_known_over_findings() -> list[str]:
    msgs = []
    for rel, wrong in KNOWN_OVER_FINDINGS + PRESENCE_EXEMPT_PINS:
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            msgs.append(f"{rel}: file is gone, so its pinned finding cannot be checked")
            continue
        if _collapse(wrong) in _collapse(_read(path)):
            msgs.append(f"{rel}: {wrong}")
    return msgs


def verify_pins(ref: str) -> tuple[bool, list[str]]:
    """Every pinned string must be PRESENT at `ref`, the revision this pass corrected.

    `check_known_over_findings` asks only that a pin is absent from the working tree, so a pin with
    a typo, or one whose text never matched the file it names, passes forever and protects nothing.
    That is not hypothetical: this pass shipped a pin spanning two lines of a `///` comment that
    matched nothing until `_collapse` learned to strip comment markers, and the only thing that
    caught it was a hand-run against `origin/main` recorded in prose. This is that run, mechanised.

    Returns (checked, messages). `checked` is always True: a file git cannot produce is reported
    as unverifiable in `messages` rather than aborting the run, so one pin on a branch-new file
    cannot hide every other pin's verdict. An earlier version returned False on the first such
    file and did exactly that.
    """
    import subprocess

    msgs = []
    by_file: dict[str, list[str]] = {}
    for rel, wrong in KNOWN_OVER_FINDINGS:
        by_file.setdefault(rel, []).append(wrong)

    # PER FILE, not first-failure-wins. The first version returned on the first `git show` error,
    # so a single pin naming a file this branch created collapsed the whole check to SKIPPED at
    # exit 0 and hid every other pin's verdict. That is the same "protects nothing" hole this
    # function was added to close, one level up, and it was caught by injecting a pin on a
    # branch-new file alongside a pin reading text that exists nowhere: the bogus one went
    # unreported.
    unreadable = []
    for rel, wrongs in sorted(by_file.items()):
        proc = subprocess.run(["git", "show", f"{ref}:{rel}"],
                              cwd=ROOT, capture_output=True, text=True)
        if proc.returncode != 0:
            unreadable.append(f"{rel}: not present at {ref} ({proc.stderr.strip()}), so its "
                              f"{len(wrongs)} pin(s) cannot be verified there")
            continue
        collapsed = _collapse(proc.stdout)
        for wrong in wrongs:
            if _collapse(wrong) not in collapsed:
                msgs.append(f"{rel}: pinned string is NOT present at {ref}, so it protects "
                            f"nothing: {wrong[:100]}")
    return (True, msgs + unreadable)


def _header_bases(cls: str) -> list[str]:
    """Base classes, plus the `using Alias = Template<...>` shape #810's version does not handle."""
    path = os.path.join(OCCT_HEADERS, cls + ".hxx")
    if not os.path.exists(path):
        return []
    text = _read(path)
    m = re.search(r"^\s*(?:class|struct)\s+" + re.escape(cls) + r"\s*:\s*([^{]+)", text, re.M)
    if not m:
        alias = re.search(r"^\s*using\s+" + re.escape(cls) + r"\s*=\s*([A-Za-z_][A-Za-z0-9_]*)",
                          text, re.M)
        return [alias.group(1)] if alias else []
    out = []
    for part in m.group(1).split(","):
        for kw in ("public", "protected", "private", "virtual"):
            part = part.replace(kw, "")
        part = part.split("<")[0].strip()
        if part:
            out.append(part)
    return out


def declares_member(cls: str, member: str, seen: set[str] | None = None) -> bool | None:
    """Does `cls` (or an ancestor) declare `member` in the pinned headers?

    None means "cannot say": the header is absent, or an ancestor's is. The second case is what the
    `using Alias = Template<...>` shape needs, since the template's own header is not shipped under
    the alias's name and answering False there reports 16 false findings on `BRepLProp_*` alone.
    """
    seen = seen if seen is not None else set()
    if cls in seen:
        return False
    seen.add(cls)
    path = os.path.join(OCCT_HEADERS, cls + ".hxx")
    if not os.path.exists(path):
        return None
    text = _read(path)
    if re.search(r"\b" + re.escape(member) + r"\s*\(", text):
        return True
    if re.search(r"\b(?:enum|class|struct|using|typedef)\s+(?:class\s+)?" + re.escape(member)
                 + r"\b", text):
        return True
    if re.search(r"\b" + re.escape(member) + r"\s*[;=]", text):
        return True
    for base in _header_bases(cls):
        sub = declares_member(base, member, seen)
        if sub is True:
            return True
        if sub is None:
            return None
    return False


def check_method_attributions() -> tuple[bool, list[str], int]:
    """Every ``Class::Member`` attribution naming a lane class, against that class's own header."""
    if not os.path.isdir(OCCT_HEADERS):
        return (False, [f"{OCCT_HEADERS} not present, method-attribution check skipped"], 0)
    lane = _lane_class_names()
    targets = _doc_files() + _bridge_files()
    msgs, checked = [], 0
    for path in targets:
        rel = os.path.relpath(path, ROOT)
        for lineno, line in enumerate(_read(path).splitlines(), 1):
            for cls, member in _ATTRIBUTION_RE.findall(line):
                if cls not in lane or (cls, member) in METHOD_ATTRIBUTION_ALLOWED:
                    continue
                checked += 1
                if declares_member(cls, member) is False:
                    msgs.append(f"{rel}:{lineno}  {cls}::{member} is not declared by "
                                f"{cls}.hxx or any ancestor")
    return (True, msgs, checked)


def reverify_lane() -> tuple[bool, list[str]]:
    if not os.path.isdir(OCCT_HEADERS):
        return (False, [f"{OCCT_HEADERS} not present, lane re-derivation skipped"])
    derived = {fn[: -len(".hxx")] for fn in os.listdir(OCCT_HEADERS) if LANE_HEADER_RE.match(fn)}
    embedded = _lane_class_names()
    msgs = []
    for c in sorted(derived - embedded):
        msgs.append(f"in the pinned headers but NOT in LANE_CLASSES: {c}")
    for c in sorted(embedded - derived):
        msgs.append(f"in LANE_CLASSES but NOT in the pinned headers: {c}")
    return (True, msgs)


# ------------------------------------------------------------------------------------------------
# Self-test. `refman_census.py` is a repro artifact rather than a gate, but `declares_member` is a
# DETECTOR, and a detector that reports "all clear" because it is blind looks exactly like one
# reporting "all clear" because the tree is clean (okf/policies/prove-the-test-fails.md). Each of
# the four accepting shapes, and the "cannot say" answer the alias case needs, has a case that
# fails when that shape is removed.
# ------------------------------------------------------------------------------------------------

SELF_TEST_CASES = [
    ("BRepFilletAPI_MakeChamfer", "IsSymmetric", False,
     "the real finding: the pinned header declares IsSymetric, one m. Without this case nothing "
     "proves the check reports anything."),
    ("BRepFilletAPI_MakeChamfer", "IsSymetric", True,
     "the correct spelling, in the same class, so a check answering False for everything fails."),
    ("BRepFilletAPI_MakeChamfer", "IsTwoDists", False,
     "the second spelling finding: the member is IsTwoDistances."),
    ("BRepFilletAPI_MakeChamfer", "GetDists", False,
     "the third: the member is Dists. GetDist, singular, does exist, so this also proves the "
     "check is not matching on a prefix."),
    ("BRepFilletAPI_MakeChamfer", "GetDist", True,
     "the near-miss that IS declared, paired with the case above."),
    ("BRepFilletAPI_MakeFillet", "NbSimulatedSurf", False,
     "the fourth: the member is NbSurf, and NbSimulatedSurf is the BRIDGE function's own name. "
     "That is the root cause this pass names, so it gets a case of its own."),
    ("BRepFilletAPI_MakeFillet", "NbSurf", True,
     "inherited from BRepFilletAPI_LocalOperation as well as declared locally. Removing the "
     "base-class walk still passes here, which is why the next case exists."),
    ("BRepFilletAPI_MakeChamfer", "NbSurfaces", False,
     "declared on BRepFilletAPI_MakeFillet and NOT on MakeChamfer, so the base-class walk must "
     "not reach sideways into a sibling."),
    ("BRepOffsetAPI_MakeOffsetShape", "OffsetAlgo_Type", True,
     "a NESTED ENUM at BRepOffsetAPI_MakeOffsetShape.hxx:137, matched by no other shape: the only "
     "other occurrence is `OffsetAlgo_Type myLastUsedAlgo;`, where the name is followed by a space "
     "and an identifier rather than by `(`, `;` or `=`. Removing the nested-type shape turns this "
     "into a false report. This case replaced `ChFi3d_FilletShape::ChFi3d_Rational`, which the "
     "removal matrix showed was passing through the METHOD shape by accident: a `//!` comment "
     "line reads `ChFi3d_Rational (default value)`, and the space-then-paren matched."),
    ("BRepFeat_MakeDPrism", "Modified", True,
     "declared ONLY on the base BRepFeat_Form; the string does not occur in BRepFeat_MakeDPrism.hxx "
     "at all. Removing the base-class walk turns this into a false report. This case replaced "
     "`BRepOffsetAPI_ThruSections::Build`, which the removal matrix showed proved nothing: "
     "ThruSections declares its own Build at line 136."),
    ("BRepLProp_CLProps", "Value", None,
     "an ALIAS TEMPLATE: the header is `using BRepLProp_CLProps = GeomLProp_CLPropsBase<...>` and "
     "no `GeomLProp_CLPropsBase.hxx` ships, so the members cannot be resolved and the answer must "
     "be `cannot say` rather than False. Two shapes make that happen and each has this case: "
     "following the `using` alias in _header_bases, and propagating a base's None. Without either, "
     "the tree-wide run reports 16 false findings on BRepLProp_ alone."),
    ("Plate_Plate", "myConstraints", True,
     "a PRIVATE DATA MEMBER at Plate_Plate.hxx:153, matched by neither the method shape nor the "
     "nested-type one. Removing the data-member shape turns this into a false report the moment a "
     "doc or bridge comment names a kernel field, which docs/thread-safety.md already does "
     "elsewhere in the tree."),
    ("Plate_Plate", "myPlanarSurface", False,
     "a plausible-sounding field that does not exist. Written first as a data-member case and "
     "measured: the header declares myConstraints and myLXYZConstraints and no such member, so "
     "the case proved nothing until it was swapped for the pair above. Kept as the negative."),
    ("BRepFeat_MakeCylindricalHole", "PerformThruNext", True,
     "the refman-confirmed signature (occt-refman@8.0.1, class_b_rep_feat___make_cylindrical_"
     "hole.html), so the lookup path CLAUDE.md mandates is exercised by a case rather than only "
     "in prose."),
]

PARSE_SELF_TEST_CASES = [
    ("- **OCCT:** `BRepFilletAPI_MakeChamfer::IsSymetric`.",
     [("BRepFilletAPI_MakeChamfer", "IsSymetric")],
     "the plain spelling, closing backtick straight after the member"),
    ("- **OCCT:** `BRepFilletAPI_MakeFillet::NbSurf()` returns the count.",
     [("BRepFilletAPI_MakeFillet", "NbSurf")],
     "the parenthesised spelling. A pattern anchored on the closing backtick sees the plain one "
     "and silently skips this, which is how #810's first draft missed a real finding."),
    ("`Plate_Plate::Load()` then `Plate_Plate::Solve()`.",
     [("Plate_Plate", "Load"), ("Plate_Plate", "Solve")],
     "two attributions on one line, so the walk is findall rather than search"),
    ("The `GeomPlate_Surface` handle is returned.", [],
     "a class named with no member, which must not produce a pair"),
    ("    return builder->chamfer.IsSymetric(contourIndex);", [],
     "a real line of OCCTBridge_Modeling.mm. The leading backtick is what keeps the walk over the "
     "bridge's own .mm files from reading every `Foo::Bar` call as a doc attribution: dropping it "
     "matches C++ scope resolution everywhere, starting with the `TopExp::MapShapes` this bridge "
     "writes hundreds of times."),
    ("Reached through TopExp::MapShapes rather than named directly.", [],
     "the same constraint in prose: an unbackticked mention is not an attribution."),
]


def run_self_test() -> int:
    print(f"self-test, parser: {len(PARSE_SELF_TEST_CASES)} cases against _ATTRIBUTION_RE")
    failed = 0
    for line, expected, why in PARSE_SELF_TEST_CASES:
        got = _ATTRIBUTION_RE.findall(line)
        ok = got == expected
        print(f"  {'PASS' if ok else 'FAIL'}  {why}")
        if not ok:
            print(f"        expected {expected}, got {got}")
            failed += 1

    if not os.path.isdir(OCCT_HEADERS):
        print(f"\nself-test, headers: SKIPPED, {OCCT_HEADERS} not present "
              "(the normal case in CI and in a fresh clone)")
        return 1 if failed else 0

    print(f"\nself-test, headers: {len(SELF_TEST_CASES)} cases against declares_member")
    for cls, member, expected, why in SELF_TEST_CASES:
        # None is an expected ANSWER here ("cannot say"), not "no expectation": the alias-template
        # case depends on it, so it is asserted like True and False rather than merely reported.
        got = declares_member(cls, member)
        ok = got is expected
        print(f"  {'PASS' if ok else 'FAIL'}  {cls}::{member} -> {got}: {why}")
        if not ok:
            failed += 1

    print(f"\n{len(PARSE_SELF_TEST_CASES) + len(SELF_TEST_CASES) - failed} passed, {failed} failed")
    return 1 if failed else 0


# ------------------------------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser(description="#811 refman coverage census, features lane")
    ap.add_argument("--verbose", action="store_true", help="print the matching files per class")
    ap.add_argument("--reverify-lane", action="store_true",
                    help="re-derive the lane from the pinned headers and diff against LANE_CLASSES")
    ap.add_argument("--verify-pins", metavar="REF", default=None,
                    help="fail unless every pinned over-coverage string is PRESENT at REF, the "
                         "revision this pass corrected (usually origin/main at the merge base)")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()

    if args.self_test:
        return run_self_test()

    exit_code = 0
    cache = build_cache()

    # Family counts, asserted rather than typed.
    table_counts = {pkg: len(cs) for pkg, cs in LANE_CLASSES.items()}
    if table_counts != FAMILY_COUNTS:
        for pkg in sorted(set(table_counts) | set(FAMILY_COUNTS)):
            if table_counts.get(pkg) != FAMILY_COUNTS.get(pkg):
                print(f"FAMILY COUNT DRIFT: {pkg}: table has {table_counts.get(pkg)}, "
                      f"FAMILY_COUNTS says {FAMILY_COUNTS.get(pkg)}")
        exit_code = 1
    total = sum(table_counts.values())
    if total != LANE_TOTAL:
        print(f"LANE TOTAL DRIFT: table has {total}, LANE_TOTAL says {LANE_TOTAL}")
        exit_code = 1

    print(f"#811 features lane: {total} classes across {len(LANE_CLASSES)} packages")
    print(f"{'class':<46} {'verdict':<22} note")
    print("-" * 118)

    tally = {"ok": 0, "deliberate, recorded": 0, "under": 0, "over": 0}
    unders = []
    for pkg in sorted(LANE_CLASSES):
        for cls in LANE_CLASSES[pkg]:
            verdict, note, bridge, docs = classify(cls, cache)
            tally[verdict] += 1
            if verdict == "under":
                unders.append((cls, note))
            print(f"{cls:<46} {verdict:<22} {note}")
            if args.verbose:
                if bridge:
                    print(f"{'':<46} {'':<22} bridge: {', '.join(bridge)}")
                if docs:
                    print(f"{'':<46} {'':<22} docs:   {', '.join(docs)}")

    print()
    print("verdicts:")
    for k in ("ok", "deliberate, recorded", "under"):
        print(f"  {k:<22} {tally[k]}")

    print()
    print(f"over-coverage findings tracked: {KNOWN_OVER_FINDING_COUNT} "
          f"({len(KNOWN_OVER_FINDINGS)} pinned strings plus {len(PRESENCE_EXEMPT_PINS)} "
          f"presence-exempt, of which {_double_carriers()} carry two findings each)")
    fixed_elsewhere = sum(1 for _rel, w in PRESENCE_EXEMPT_PINS
                          if w not in {t for _r, t in SELF_INTRODUCED})
    print(f"  of the presence-exempt, {fixed_elsewhere} were fixed on main by another PR while "
          f"this branch\n  was in review and {len(SELF_INTRODUCED)} were written by this pass "
          "and corrected")
    regressions = check_known_over_findings()
    if regressions:
        print("REGRESSION: the following fixed over-coverage findings have reappeared:")
        for m in regressions:
            print(f"  {m}")
        exit_code = 1
    else:
        print("  none has reappeared")

    checked, msgs, n = check_method_attributions()
    print()
    if not checked:
        print(f"method attributions: SKIPPED ({msgs[0]})")
    else:
        print(f"method attributions checked: {n}")
        if msgs:
            print("FINDINGS: a doc or bridge comment names a member the pinned headers do not "
                  "declare:")
            for m in msgs:
                print(f"  {m}")
            exit_code = 1
        else:
            print("  every one resolves against the pinned headers")

    if unders:
        print()
        print("UNDER-COVERAGE with no reason in docs/occtswift-wrapping-gaps.md:")
        for cls, note in unders:
            print(f"  {cls}: {note}")
        exit_code = 1

    if args.verify_pins:
        print()
        ok, msgs = verify_pins(args.verify_pins)
        if not ok:
            print(f"pin verification: SKIPPED ({msgs[0]})")
        elif msgs:
            print(f"PINS THAT PROTECT NOTHING at {args.verify_pins}:")
            for m in msgs:
                print(f"  {m}")
            exit_code = 1
        else:
            print(f"pin verification: all {len(KNOWN_OVER_FINDINGS)} pinned strings are present "
                  f"at {args.verify_pins}, so each one is a real correction")

    if args.reverify_lane:
        print()
        ok, msgs = reverify_lane()
        if not ok:
            print(f"lane re-derivation: SKIPPED ({msgs[0]})")
        elif msgs:
            print("LANE DRIFT:")
            for m in msgs:
                print(f"  {m}")
            exit_code = 1
        else:
            print("lane re-derivation: the pinned headers still give exactly these 129 classes")

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
