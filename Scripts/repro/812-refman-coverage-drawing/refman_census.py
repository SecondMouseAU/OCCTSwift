#!/usr/bin/env python3
"""Issue #812 (Pass 4b of #807): refman coverage census for the Drawing / 2D annotation lane.

WHY A SCRIPT, NOT A LIST IN THE ISSUE: `docs/v2.0.0-plan.md`'s census rule, and this repo's history
of hand-built censuses that were confidently wrong differently each time (#558, #571, #573, #583,
#595, #507, #553, #562). #811 (Pass 4a, the sibling lane) is the template this file follows.

THE LANE WAS RE-DERIVED BY CALL, and both halves of #812's own `## Lane` text moved. See
`derive_lane.py` next to this file for the walk; summarised here because a census needs to state
what it audits before it audits it.

  - `Prs3d_*` contributes ZERO classes. The only Prs3d_ construction sites in the whole bridge
    (`Prs3d_Drawer`, `Prs3d_Presentation`) sit behind `DisplayDrawer.swift`, which controls Metal
    tessellation quality for 3D display ("affect mesh generation quality", its own doc comment) --
    exactly what #812's own qualifier ("where it backs 2D output") excludes. `grep -rn TypeOfHLR
    Sources/ docs/` (the one Prs3d_ enum that sounds 2D-drawing-shaped) returns nothing either.
  - `HLRBRep_*`/`HLRAlgo_*` are real, but the Swift surface calling into them is FOUR files, not
    #386's fourteen and not the three the issue text names: `Drawing.swift`,
    `DrawingAutoCenterlines.swift`, and the HLR-relevant sections of `Shape+Topology.swift` (never
    in #386's list -- an independent `OCCTHLRGetEdgesByCategory`/`OCCTHLRPolyGetEdgesByCategory`/
    `OCCTHLRCompoundOfEdges` call path in `OCCTBridge_Modeling.mm` that #1071's bridge split, PR
    #1130, never migrated to `OCCTBridge_HLR.mm`) and `Shape+Drawing.swift` (whose OTHER half,
    `normalProjection`/`projectWire`, is #811's `BRepOffsetAPI_NormalProjection`, not this lane's).
    Ten of #386's fourteen files call zero `OCCT*` symbols at all: pure Swift ISO
    128/3098/5455 drafting-convention code, exactly what #812's own body predicts.
  - A fourth package is audited that #812's own text does not name, for the same reason #811 added
    `Plate_`/`NLPlate_`/`GeomPlate_`/`BRepMAT2d_` to its lane: `HLRAppli_ReflectLines` is
    constructed two functions below `OCCTHLRCompoundOfEdges` in the SAME `OCCTBridge_Modeling.mm`
    block, called from `Shape+Drawing.swift`'s ReflectLines half. `TopCnx_`, named in the very same
    doc section heading ("Extended HLR, ReflectLines, TopCnx, Intrv") two words later, is NOT
    added: edge-face transition classification for BOP/healing, a different capability that shipped
    in the same v0.73.0 batch, not a hidden-line-removal one.

So the audited lane is THREE packages, 93 classes: `HLRAlgo_` (29, including the bare `HLRAlgo.hxx`
package-utility header), `HLRBRep_` (63, including the bare `HLRBRep.hxx`), `HLRAppli_` (1). Zero
`Prs3d_` classes, stated rather than a silently-empty table.

TWO QUESTIONS, per #812:

  UNDER-COVERAGE: an OCCT class in the lane we neither wrap (named on a line of
  `Sources/OCCTBridge/{src/*.mm,include/*.h}` that does not START with `#include`, `//`, `*` or
  `/*`) nor document (named anywhere under `docs/` except `docs/CHANGELOG.md` and
  `docs/occtswift-wrapping-gaps.md`, whose whole subject is what is NOT wrapped -- see `classify()`
  for why the gaps file is excluded from the docs test rather than trusted), with no reason recorded
  in that gaps file.

  Measured before this PR: 93 lane classes, 7 wrapped, 86 neither wrapped nor documented, 0 of the
  93 named anywhere in `docs/occtswift-wrapping-gaps.md` (the "TKHLR: Hidden line removal (HLRBRep,
  HLRAlgo)" line in that file's summary table names the toolkit, not one class by name, so it
  matches no individual class). Base verdicts: 7 ok, 0 deliberate/recorded, 86 under.

  Unlike #811's lane, almost none of the 86 is a genuine capability gap: HLR is one nontrivial
  geometric algorithm (compute the visible/hidden silhouette of a shape from a viewpoint) with five
  public entry classes and ~60 classes of its own internal machinery (an intersection engine for
  curve/curve and curve/surface projections, a mesh-internal polygon data structure, template-policy
  "Tool" adaptors, deprecated collection typedefs, alias templates). Each of the 86 is curated below
  with the specific mechanism it serves, following #811's rule that a curated table entry needs a
  measured reason, not "internal, trust me".

  OVER-COVERAGE: something current docs assert that the pinned kernel does not support.
  `Scripts/census-doc-occt-attribution.py --lane HLRBRep_,HLRAlgo_,HLRAppli_,Prs3d_` (#928) surfaced
  5 candidates, all in `docs/reference/Drawing.md`, all the same shape and all adjudicated FALSE:
  `HLRBRep_HLRToShape`/`HLRBRep_PolyHLRToShape` attributed to `OCCTDrawingGetEdges`, which reads
  already-extracted compound fields (cached on the `OCCTDrawing` struct by a SIBLING function,
  `OCCTDrawingCreate`/`OCCTDrawingCreatePoly`) rather than constructing either class itself. The
  detector's `reachable()` walker requires the class inside the NAMED function's own body; the doc
  prose says "compound accessors ... selected via `OCCTEdgeType` in `OCCTDrawingGetEdges`", which is
  an accurate description of the real two-function mechanism, not a claim that `OCCTDrawingGetEdges`
  itself builds either HLR class. Same shape as #811's one rejected candidate (a cross-file shared
  helper the walker does not follow), and the same conclusion: read before trusting a detector hit.
  A hand read of every remaining `- **OCCT:**` bullet touching this lane (`HLRAlgo_Projector`'s two
  constructor overloads, `HLRBRep_TypeOfResultingEdge`'s six ordinals, `HLREdgeCategory`'s eleven
  cases, both `reflectLines*` descriptions) confirmed each against the pinned headers with no
  further finding. `docs/occt-upgrades.md` names no HLR class, so the 8.0.1 kernel bump did not
  touch this lane the way it touched `BRepMesh_BaseMeshAlgo` for Pass 4d's.

CLASSIFICATION RULES. Mechanical unless a class is in one of the curated tables, each entry
established during #812 by reading the pinned header and, where the contract was in question, the
refman through the `context` MCP at `occt-refman@8.0.1`. Never inferred from the class name.

  - PACKAGE_UTILITY: the bare `<Package>.hxx` header (`HLRAlgo`, `HLRBRep`), an all-static-method
    class (`DEFINE_STANDARD_ALLOC`, no instance state) serving the package's own public algorithm
    classes: packed min/max-box arithmetic for `HLRAlgo_EdgesBlock`, HLR-curve-to-`TopoDS_Edge`
    construction for `HLRBRep_Algo`. Not something a caller instantiates.
  - DEPRECATED_COLLECTION_ALIASES: the header carries `Standard_HEADER_DEPRECATED` at file scope,
    deprecated since OCCT 8.0.0, "use NCollection_X directly". 15 of the 93.
  - ALIAS_TEMPLATES: a `using X = Template<...>;` header (no `class`/`struct` of its own name),
    each one an internal local-properties or extremum/locator evaluator the HLR curve/surface-tool
    engine builds for itself; the alias-template shape #811's `declares_member` needed a `None`
    ("cannot say") answer for, here at the lane-membership level instead of the method-attribution
    one. 5 of the 93.
  - PRIVATE_IMPLEMENTATION: a header that declares no class of its own name. `HLRBRep_TypeDef` is
    two `typedef void*` aliases (`HLRBRep_CurvePtr`, `HLRBRep_SurfacePtr`), not a class.
  - ENUMS_UNWRAPPED: an enum nothing in the tree reads, by value or by name. `HLRAlgo_PolyMask`'s
    thirteen bit-flag values are packed into `HLRAlgo_EdgesBlock`'s internal state; nothing outside
    `HLRAlgo` itself reads them.
  - INTERNAL_HELPERS: a concrete class serving the algorithm engine behind an already-wrapped entry
    point, with no independent capability a CAD consumer could reach. Four measured sub-mechanisms,
    each cited by its own reason string rather than one blanket "internal": the poly-HLR engine's
    own internal mesh/triangle/edge-status data (`HLRAlgo_PolyAlgo` and 15 siblings, confirmed via
    `occt-refman@8.0.1`'s own class pages for `HLRAlgo_PolyInternalData`/`HLRBRep_Data`, both
    "to Update OutLines" / edge-hiding cursor state with no capability beyond it); the exact-HLR
    engine's own edge/face/interference state (`HLRBRep_Data` and 20 siblings); template-policy
    "Tool" adaptor classes providing static geometric evaluators to the two engines above (7); and
    the deep curve/curve and curve/surface intersection-engine template instantiations
    (`HLRBRep_The*Of*`/`HLRBRep_My*Of*`, OCCT's generic-intersection-macro naming, 18).

The wrapped test runs BEFORE the curated tables, following #808/#810/#811: a table entry claiming a
class has no call sites must not be able to mask one that does.

ONE LIMITATION, inherited from #808/#809/#810/#811 rather than rediscovered: `deliberate, recorded`
means the class NAME appears somewhere in `docs/occtswift-wrapping-gaps.md`, not that the sentence
around it is a reason. Every class this pass files as recorded is named in a bullet this pass wrote
carrying its measured reason, so the name match and the reason coincide today; the test cannot tell
the difference tomorrow.

Run from anywhere (paths derive from this file's location, not the cwd):

    python3 Scripts/repro/812-refman-coverage-drawing/refman_census.py
    python3 Scripts/repro/812-refman-coverage-drawing/refman_census.py --verbose
    python3 Scripts/repro/812-refman-coverage-drawing/refman_census.py --reverify-lane
    python3 Scripts/repro/812-refman-coverage-drawing/refman_census.py --self-test

Exits 1 on a `KNOWN_OVER_FINDINGS` regression (empty today: 0 true over-coverage findings), on a
method attribution naming a member the pinned headers do not declare, on an `under` with no
`docs/occtswift-wrapping-gaps.md` line, on a family-count drift, or on lane drift under
`--reverify-lane`. Exits 0 otherwise.
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

LANE_PACKAGES = ("HLRAlgo", "HLRBRep", "HLRAppli")

LANE_HEADER_RE = re.compile(r"^(HLRAlgo|HLRBRep|HLRAppli)(_[^.]+)?\.hxx$")

# ------------------------------------------------------------------------------------------------
# The lane: 93 classes, enumerated from the pinned kernel's own headers (OCCT 8.0.1 plus the
# carried patches) on 2026-08-27. Re-derive with:
#
#   ls Libraries/OCCT.xcframework/macos-arm64/Headers \
#     | grep -E '^(HLRAlgo|HLRBRep|HLRAppli)(_[^.]+)?\.hxx$' | sed 's/\.hxx$//' | sort
#
# `--reverify-lane` runs exactly that derivation and diffs it against this list.
# ------------------------------------------------------------------------------------------------

LANE_CLASSES: dict[str, list[str]] = {
    "HLRAlgo": [
        "HLRAlgo", "HLRAlgo_Array1OfPHDat", "HLRAlgo_Array1OfPINod", "HLRAlgo_Array1OfPISeg",
        "HLRAlgo_Array1OfTData", "HLRAlgo_BiPoint", "HLRAlgo_Coincidence", "HLRAlgo_EdgeIterator",
        "HLRAlgo_EdgeStatus", "HLRAlgo_EdgesBlock", "HLRAlgo_HArray1OfPHDat",
        "HLRAlgo_HArray1OfPINod", "HLRAlgo_HArray1OfPISeg", "HLRAlgo_HArray1OfTData",
        "HLRAlgo_Interference", "HLRAlgo_InterferenceList", "HLRAlgo_Intersection",
        "HLRAlgo_ListOfBPoint", "HLRAlgo_PolyAlgo", "HLRAlgo_PolyData", "HLRAlgo_PolyHidingData",
        "HLRAlgo_PolyInternalData", "HLRAlgo_PolyInternalNode", "HLRAlgo_PolyInternalSegment",
        "HLRAlgo_PolyMask", "HLRAlgo_PolyShellData", "HLRAlgo_Projector", "HLRAlgo_TriangleData",
        "HLRAlgo_WiresBlock",
    ],
    "HLRAppli": [
        "HLRAppli_ReflectLines",
    ],
    "HLRBRep": [
        "HLRBRep", "HLRBRep_Algo", "HLRBRep_AreaLimit", "HLRBRep_Array1OfEData",
        "HLRBRep_Array1OfFData", "HLRBRep_BCurveTool", "HLRBRep_BSurfaceTool", "HLRBRep_BiPnt2D",
        "HLRBRep_BiPoint", "HLRBRep_CInter", "HLRBRep_CLProps", "HLRBRep_CLPropsATool",
        "HLRBRep_Curve", "HLRBRep_CurveTool", "HLRBRep_Data", "HLRBRep_EdgeBuilder",
        "HLRBRep_EdgeData", "HLRBRep_EdgeFaceTool", "HLRBRep_EdgeIList",
        "HLRBRep_EdgeInterferenceTool", "HLRBRep_ExactIntersectionPointOfTheIntPCurvePCurveOfCInter",
        "HLRBRep_FaceData", "HLRBRep_FaceIterator", "HLRBRep_HLRToShape", "HLRBRep_Hider",
        "HLRBRep_IntConicCurveOfCInter", "HLRBRep_InterCSurf", "HLRBRep_InternalAlgo",
        "HLRBRep_Intersector", "HLRBRep_LineTool", "HLRBRep_ListOfBPnt2D", "HLRBRep_ListOfBPoint",
        "HLRBRep_MyImpParToolOfTheIntersectorOfTheIntConicCurveOfCInter",
        "HLRBRep_PCLocFOfTheLocateExtPCOfTheProjPCurOfCInter", "HLRBRep_PolyAlgo",
        "HLRBRep_PolyHLRToShape", "HLRBRep_SLProps", "HLRBRep_SLPropsATool",
        "HLRBRep_SeqOfShapeBounds", "HLRBRep_ShapeBounds", "HLRBRep_ShapeToHLR", "HLRBRep_Surface",
        "HLRBRep_SurfaceTool", "HLRBRep_TheCSFunctionOfInterCSurf",
        "HLRBRep_TheCurveLocatorOfTheProjPCurOfCInter",
        "HLRBRep_TheDistBetweenPCurvesOfTheIntPCurvePCurveOfCInter", "HLRBRep_TheExactInterCSurf",
        "HLRBRep_TheIntConicCurveOfCInter", "HLRBRep_TheInterferenceOfInterCSurf",
        "HLRBRep_TheIntersectorOfTheIntConicCurveOfCInter", "HLRBRep_TheIntPCurvePCurveOfCInter",
        "HLRBRep_TheLocateExtPCOfTheProjPCurOfCInter",
        "HLRBRep_ThePolygon2dOfTheIntPCurvePCurveOfCInter", "HLRBRep_ThePolygonOfInterCSurf",
        "HLRBRep_ThePolygonToolOfInterCSurf", "HLRBRep_ThePolyhedronOfInterCSurf",
        "HLRBRep_ThePolyhedronToolOfInterCSurf", "HLRBRep_TheProjPCurOfCInter",
        "HLRBRep_TheQuadCurvExactInterCSurf", "HLRBRep_TheQuadCurvFuncOfTheQuadCurvExactInterCSurf",
        "HLRBRep_TypeDef", "HLRBRep_TypeOfResultingEdge", "HLRBRep_VertexList",
    ],
}

FAMILY_COUNTS = {"HLRAlgo": 29, "HLRAppli": 1, "HLRBRep": 63}
LANE_TOTAL = 93

# ------------------------------------------------------------------------------------------------
# Curated classification tables. Each reason was read off the pinned header during #812; the two
# `occt-refman@8.0.1` class pages cited in the module docstring (`HLRAlgo_PolyInternalData`,
# `HLRBRep_Data`) confirm the "internal algorithm state, no independent capability" read rather
# than merely asserting it from the name.
# ------------------------------------------------------------------------------------------------

PACKAGE_UTILITY = {
    "HLRAlgo": "bare package header, an all-static-method class (DEFINE_STANDARD_ALLOC) of packed "
              "min/max-box arithmetic (UpdateMinMax/EnlargeMinMax/EncodeMinMax/...) for "
              "HLRAlgo_EdgesBlock's own internal state; no instance, nothing a caller constructs",
    "HLRBRep": "bare package header, an all-static-method class (DEFINE_STANDARD_ALLOC) providing "
              "MakeEdge/MakeEdge3d (HLR curve -> TopoDS_Edge) for HLRBRep_Algo's own internal use "
              "and PolyHLRAngleAndDeflection for HLRBRep_PolyAlgo's; no instance",
}

DEPRECATED_COLLECTION_ALIASES = {
    c: "file-scope Standard_HEADER_DEPRECATED, deprecated since OCCT 8.0.0, use NCollection directly"
    for c in [
        "HLRAlgo_Array1OfPHDat", "HLRAlgo_Array1OfPINod", "HLRAlgo_Array1OfPISeg",
        "HLRAlgo_Array1OfTData", "HLRAlgo_HArray1OfPHDat", "HLRAlgo_HArray1OfPINod",
        "HLRAlgo_HArray1OfPISeg", "HLRAlgo_HArray1OfTData", "HLRAlgo_InterferenceList",
        "HLRAlgo_ListOfBPoint", "HLRBRep_Array1OfEData", "HLRBRep_Array1OfFData",
        "HLRBRep_ListOfBPnt2D", "HLRBRep_ListOfBPoint", "HLRBRep_SeqOfShapeBounds",
    ]
}

ALIAS_TEMPLATES = {
    "HLRBRep_CLProps": "using X = GeomLProp_CLPropsBase<gp_Pnt2d, ..., HLRBRep_Curve, "
                       "ToolAccess<HLRBRep_CLPropsATool>>: 2D curve local-property (tangent, "
                       "curvature) evaluator the HLR curve-tool engine builds for edge sampling",
    "HLRBRep_SLProps": "using X = GeomLProp_SLPropsBase<..., HLRBRep_SurfacePtr, "
                       "ToolAccess<HLRBRep_SLPropsATool>>: surface local-property evaluator, "
                       "sibling of HLRBRep_CLProps for surfaces",
    "HLRBRep_PCLocFOfTheLocateExtPCOfTheProjPCurOfCInter": "using alias, \"2D curve extremum "
                       "function using HLRBRep_CurveTool\" per its own doc comment: internal to "
                       "HLRBRep_CInter's curve/curve intersection engine",
    "HLRBRep_TheCurveLocatorOfTheProjPCurOfCInter": "using alias, \"curve locator using "
                       "HLRBRep_CurveTool\" per its own doc comment: internal to the same engine",
    "HLRBRep_TheLocateExtPCOfTheProjPCurOfCInter": "using alias, the extremum-locator this engine "
                       "builds from the two aliases above; no doc comment of its own but same "
                       "family (HLRBRep_CInter.hxx includes all three together)",
}

PRIVATE_IMPLEMENTATION = {
    "HLRBRep_TypeDef": "declares no class of its own name: two typedef void* aliases "
                       "(HLRBRep_CurvePtr, HLRBRep_SurfacePtr) for the generic template-"
                       "instantiation interface, nothing to wrap",
}

ENUMS_UNWRAPPED = {
    "HLRAlgo_PolyMask": "13 bit-flag values (EMskOutLin1..FMskFrBack) packed into "
                        "HLRAlgo_EdgesBlock's internal per-edge state; nothing outside HLRAlgo "
                        "itself reads them, by value or by name",
}

_POLY_ENGINE_REASON = ("internal state/data of the poly (triangulation-based) HLR engine "
                       "HLRBRep_PolyAlgo drives via HLRAlgo_PolyAlgo; confirmed against "
                       "occt-refman@8.0.1's own class_h_l_r_algo___poly_internal_data.html "
                       "(\"to Update OutLines\"), no capability independent of that engine")
_EXACT_ENGINE_REASON = ("internal state/data of the exact HLR engine HLRBRep_Algo drives via "
                        "HLRBRep_Data; confirmed against occt-refman@8.0.1's own "
                        "class_h_l_r_b_rep___data.html (edge/interference/hiding-face cursor "
                        "methods: AboveInterference, HidingTheFace, InitInterference, "
                        "RejectedInterference), no capability independent of that engine")
_TOOL_REASON = ("a template-policy \"Tool\" adaptor: static geometric-evaluator methods the exact "
               "HLR engine's curve/surface/local-property machinery is instantiated over, not a "
               "class a caller constructs")
_CINTER_ENGINE_REASON = ("HLRBRep_CInter's/HLRBRep_InterCSurf's own generic-intersection-engine "
                         "template instantiation (OCCT's \"The<X>Of<Y>\"/\"My<X>Of<Y>\" naming for "
                         "this toolkit's macro-generated 2D curve/curve or curve/surface "
                         "intersection internals), no independent use outside that engine")

INTERNAL_HELPERS: dict[str, str] = {}
for _c in ("HLRAlgo_PolyAlgo", "HLRAlgo_BiPoint", "HLRAlgo_Coincidence", "HLRAlgo_EdgeIterator",
          "HLRAlgo_EdgeStatus", "HLRAlgo_EdgesBlock", "HLRAlgo_Interference",
          "HLRAlgo_Intersection", "HLRAlgo_PolyData", "HLRAlgo_PolyHidingData",
          "HLRAlgo_PolyInternalData", "HLRAlgo_PolyInternalNode", "HLRAlgo_PolyInternalSegment",
          "HLRAlgo_PolyShellData", "HLRAlgo_TriangleData", "HLRAlgo_WiresBlock"):
    INTERNAL_HELPERS[_c] = _POLY_ENGINE_REASON
for _c in ("HLRBRep_AreaLimit", "HLRBRep_BiPnt2D", "HLRBRep_BiPoint", "HLRBRep_CInter",
          "HLRBRep_Curve", "HLRBRep_Data", "HLRBRep_EdgeBuilder", "HLRBRep_EdgeData",
          "HLRBRep_EdgeFaceTool", "HLRBRep_EdgeIList", "HLRBRep_EdgeInterferenceTool",
          "HLRBRep_FaceData", "HLRBRep_FaceIterator", "HLRBRep_Hider", "HLRBRep_InterCSurf",
          "HLRBRep_InternalAlgo", "HLRBRep_Intersector", "HLRBRep_ShapeBounds",
          "HLRBRep_ShapeToHLR", "HLRBRep_Surface", "HLRBRep_VertexList"):
    INTERNAL_HELPERS[_c] = _EXACT_ENGINE_REASON
for _c in ("HLRBRep_BCurveTool", "HLRBRep_BSurfaceTool", "HLRBRep_CLPropsATool",
          "HLRBRep_CurveTool", "HLRBRep_LineTool", "HLRBRep_SLPropsATool", "HLRBRep_SurfaceTool"):
    INTERNAL_HELPERS[_c] = _TOOL_REASON
for _c in ("HLRBRep_ExactIntersectionPointOfTheIntPCurvePCurveOfCInter",
          "HLRBRep_IntConicCurveOfCInter",
          "HLRBRep_MyImpParToolOfTheIntersectorOfTheIntConicCurveOfCInter",
          "HLRBRep_TheCSFunctionOfInterCSurf",
          "HLRBRep_TheDistBetweenPCurvesOfTheIntPCurvePCurveOfCInter", "HLRBRep_TheExactInterCSurf",
          "HLRBRep_TheIntConicCurveOfCInter", "HLRBRep_TheInterferenceOfInterCSurf",
          "HLRBRep_TheIntersectorOfTheIntConicCurveOfCInter", "HLRBRep_TheIntPCurvePCurveOfCInter",
          "HLRBRep_ThePolygon2dOfTheIntPCurvePCurveOfCInter", "HLRBRep_ThePolygonOfInterCSurf",
          "HLRBRep_ThePolygonToolOfInterCSurf", "HLRBRep_ThePolyhedronOfInterCSurf",
          "HLRBRep_ThePolyhedronToolOfInterCSurf", "HLRBRep_TheProjPCurOfCInter",
          "HLRBRep_TheQuadCurvExactInterCSurf",
          "HLRBRep_TheQuadCurvFuncOfTheQuadCurvExactInterCSurf"):
    INTERNAL_HELPERS[_c] = _CINTER_ENGINE_REASON

CURATED: dict[str, tuple[str, str]] = {}
for _table, _label in (
    (PACKAGE_UTILITY, "PACKAGE_UTILITY"),
    (DEPRECATED_COLLECTION_ALIASES, "DEPRECATED_COLLECTION_ALIASES"),
    (ALIAS_TEMPLATES, "ALIAS_TEMPLATES"),
    (PRIVATE_IMPLEMENTATION, "PRIVATE_IMPLEMENTATION"),
    (ENUMS_UNWRAPPED, "ENUMS_UNWRAPPED"),
    (INTERNAL_HELPERS, "INTERNAL_HELPERS"),
):
    for _cls, _why in _table.items():
        CURATED[_cls] = (_label, _why)

# ------------------------------------------------------------------------------------------------
# Over-coverage. Empty: every candidate this pass measured (5 from #928's `--lane` detector, plus a
# hand read of every remaining `- **OCCT:**` bullet touching this lane) was a false positive or
# already correct. See the module docstring for what was checked and why each was rejected.
# ------------------------------------------------------------------------------------------------

KNOWN_OVER_FINDINGS: list[tuple[str, str]] = []
PRESENCE_EXEMPT_PINS: list[tuple[str, str]] = []
KNOWN_OVER_FINDING_COUNT = 0

# Candidates surfaced by #928's detector and rejected, kept here so a future run of this file (or
# of `census-doc-occt-attribution.py --lane ...` directly) does not have to re-derive the
# adjudication from scratch. Not enforced (there is nothing to regress-check an absence of), purely
# a record.
REJECTED_OVER_CANDIDATES: list[tuple[str, str, str]] = [
    ("docs/reference/Drawing.md:132", "HLRBRep_HLRToShape via OCCTDrawingGetEdges",
     "OCCTDrawingGetEdges reads compound fields OCCTDrawingCreate/OCCTDrawingCreatePoly already "
     "extracted (occtDrawingPopulate); the prose says \"selected via OCCTEdgeType in "
     "OCCTDrawingGetEdges\", accurate for the switch that picks among them, not a claim that "
     "OCCTDrawingGetEdges itself constructs either class"),
    ("docs/reference/Drawing.md:132", "HLRBRep_PolyHLRToShape via OCCTDrawingGetEdges",
     "same shape, same line"),
    ("docs/reference/Drawing.md:148", "HLRBRep_HLRToShape via OCCTDrawingGetEdges",
     "same shape as :132"),
    ("docs/reference/Drawing.md:148", "HLRBRep_PolyHLRToShape via OCCTDrawingGetEdges",
     "same shape as :132"),
    ("docs/reference/Drawing.md:787", "HLRBRep_HLRToShape via OCCTDrawingGetEdges",
     "same shape as :132, one class named instead of two"),
]

METHOD_ATTRIBUTION_ALLOWED: set[tuple[str, str]] = set()

_ATTRIBUTION_RE = re.compile(
    r"`([A-Za-z][A-Za-z0-9]*(?:_[A-Za-z0-9]+)?)::([A-Za-z_][A-Za-z0-9_]*)"
)

# ------------------------------------------------------------------------------------------------
# Measurement (identical shape to #811's refman_census.py; see that file for the rationale on each
# choice -- the token-cache inversion, the comment-prefix collapse, the wrapped-before-curated
# ordering, the gaps.md exclusion).
# ------------------------------------------------------------------------------------------------

def _read(path: str) -> str:
    with open(path, errors="ignore") as fh:
        return fh.read()


_COMMENT_PREFIX_RE = re.compile(r"^\s*(?:///|//!|//|\*(?!/))\s?")


def _collapse(text: str) -> str:
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
    return sorted(cache["bridge_tokens"].get(cls, set()))


def named_in_docs(cls: str, cache) -> list[str]:
    return sorted(cache["doc_tokens"].get(cls, set()))


def build_cache():
    cache: dict = {"bridge_tokens": {}, "doc_tokens": {}}
    for path in _bridge_files():
        rel = os.path.relpath(path, ROOT)
        for line in _read(path).splitlines():
            stripped = line.strip()
            if stripped.startswith(("#include", "#import", "//", "*", "/*")):
                continue
            for tok in _TOKEN_RE.findall(stripped):
                cache["bridge_tokens"].setdefault(tok, set()).add(rel)
    for path in _doc_files():
        rel = os.path.relpath(path, ROOT)
        text = _read(path)
        if os.path.abspath(path) == os.path.abspath(GAPS_FILE):
            continue
        for tok in _TOKEN_RE.findall(text):
            cache["doc_tokens"].setdefault(tok, set()).add(rel)
    cache["gaps"] = _read(GAPS_FILE) if os.path.exists(GAPS_FILE) else ""
    return cache


def recorded_in_gaps(cls: str, cache) -> bool:
    return bool(re.search(r"\b" + re.escape(cls) + r"\b", cache["gaps"]))


def classify(cls: str, cache) -> tuple[str, str, list[str], list[str]]:
    """(verdict, note, bridge hits, docs hits). See #811's refman_census.classify docstring for
    why the ordering (wrapped, then curated, then documented, then under) and the gaps.md exclusion
    are both load-bearing on their own lane; `selftest_removal_matrix.py` re-proves both here."""
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
# Over-coverage checks (structurally identical to #811's; both lists are empty here, see above)
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


def _header_bases(cls: str) -> list[str]:
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
    if not os.path.isdir(OCCT_HEADERS):
        return (False, [f"{OCCT_HEADERS} not present, method-attribution check skipped"], 0)
    targets = _doc_files() + _bridge_files()
    msgs, checked = [], 0
    for path in targets:
        rel = os.path.relpath(path, ROOT)
        for lineno, line in enumerate(_read(path).splitlines(), 1):
            for cls, member in _ATTRIBUTION_RE.findall(line):
                if cls not in _lane_class_names():
                    continue
                if (cls, member) in METHOD_ATTRIBUTION_ALLOWED:
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
# Self-test. `refman_census.py` is a repro artifact rather than a gate, but `declares_member` and
# `classify` are DETECTORS, and a detector that reports "all clear" because it is blind looks
# exactly like one reporting "all clear" because the tree is clean
# (okf/policies/prove-the-test-fails.md). `selftest_removal_matrix.py` next to this file switches
# off each accepting shape in turn and proves each case here actually needs it.
# ------------------------------------------------------------------------------------------------

SELF_TEST_CASES = [
    ("HLRAlgo_Projector", "Project", True,
     "the refman-confirmed member (occt-refman@8.0.1, class_h_l_r_algo___projector.html), so the "
     "lookup path CLAUDE.md mandates is exercised by a case rather than only in prose"),
    ("HLRAlgo_Projector", "SetFocus", False,
     "a plausible-sounding name that is not declared: HLRAlgo_Projector's focus is set only via "
     "its own constructor overload, never a setter"),
    ("HLRBRep_Algo", "Update", True,
     "a real method (Standard_EXPORT void Update()), the one OCCTDrawingCreate calls"),
    ("HLRBRep_Algo", "Refresh", False,
     "does not exist: HLRBRep_Algo has Update/Hide, not Refresh"),
    ("HLRBRep_PolyAlgo", "Load", True,
     "declared locally on HLRBRep_PolyAlgo (not inherited), the method OCCTDrawingCreatePoly calls"),
    ("HLRBRep_HLRToShape", "OutLineVCompound", True,
     "one of the six compound accessors occtDrawingPopulate reads"),
    ("HLRBRep_HLRToShape", "OutlineVCompound", False,
     "a lowercase-l near-miss of the real accessor above: proves the check is not case-"
     "insensitive"),
    ("HLRAlgo_EdgesBlock", "MinMaxIndices", True,
     "a NESTED STRUCT (HLRAlgo_EdgesBlock::MinMaxIndices), matched by no other shape: HLRAlgo's own "
     "own static helpers take it by reference, which is a method-call match on the surrounding "
     "function, not on this nested-type test, so this case is the only thing exercising it"),
    ("HLRBRep_CLProps", "Tangent", None,
     "an ALIAS TEMPLATE: HLRBRep_CLProps.hxx is `using HLRBRep_CLProps = "
     "GeomLProp_CLPropsBase<...>` and no GeomLProp_CLPropsBase.hxx ships, so the member cannot be "
     "resolved and the answer must be `cannot say` rather than False. Two shapes make that happen, "
     "each proven by its own removal-matrix variant: following the `using` alias in "
     "_header_bases, and propagating a base's None"),
    ("HLRAppli_ReflectLines", "SetAxes", True,
     "the method the bridge's OCCTHLRReflectLines calls directly"),
    ("HLRAppli_ReflectLines", "GetCompoundOf3dEdges", True,
     "declared on HLRAppli_ReflectLines itself, the method OCCTHLRReflectLinesFiltered calls"),
    ("HLRAlgo_Projector", "myPersp", True,
     "a PRIVATE DATA MEMBER at HLRAlgo_Projector.hxx:116 (bool myPersp;), matched by neither the "
     "method shape (nothing follows it with `(`) nor the nested-type one. Removing the data-member "
     "shape turns this into a false report the moment a doc or bridge comment names a kernel "
     "field, which docs/thread-safety.md already does elsewhere in the tree. The removal matrix "
     "found this shape had NO case at all in the first draft of this list, a decoration bug "
     "matching one of #811's own four."),
    ("HLRAlgo_Projector", "myPerspective", False,
     "a plausible-sounding field that does not exist: the real member is the abbreviated "
     "myPersp above. Kept as the negative, same role as #811's Plate_Plate::myPlanarSurface."),
]

PARSE_SELF_TEST_CASES = [
    ("- **OCCT:** `HLRAlgo_Projector::Project`.",
     [("HLRAlgo_Projector", "Project")],
     "the plain spelling, closing backtick straight after the member"),
    ("- **OCCT:** `HLRBRep_HLRToShape::CompoundOfEdges()` returns the compound.",
     [("HLRBRep_HLRToShape", "CompoundOfEdges")],
     "the parenthesised spelling; a pattern anchored on the closing backtick would miss this"),
    ("`HLRBRep_Algo::Update()` then `HLRBRep_Algo::Hide()`.",
     [("HLRBRep_Algo", "Update"), ("HLRBRep_Algo", "Hide")],
     "two attributions on one line, so the walk is findall rather than search"),
    ("The `HLRBRep_HLRToShape` handle is returned.", [],
     "a class named with no member, which must not produce a pair"),
    ("    hlrAlgo->Hide();", [],
     "a real line of OCCTBridge_HLR.mm using -> not ::, must not match"),
    ("Reached through HLRBRep_Algo::Update rather than named directly.", [],
     "an unbackticked mention in prose is not an attribution"),
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
        got = declares_member(cls, member)
        ok = got is expected
        print(f"  {'PASS' if ok else 'FAIL'}  {cls}::{member} -> {got}: {why}")
        if not ok:
            failed += 1

    print(f"\n{len(PARSE_SELF_TEST_CASES) + len(SELF_TEST_CASES) - failed} passed, {failed} failed")
    return 1 if failed else 0


# ------------------------------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser(description="#812 refman coverage census, Drawing/2D lane")
    ap.add_argument("--verbose", action="store_true", help="print the matching files per class")
    ap.add_argument("--reverify-lane", action="store_true",
                    help="re-derive the lane from the pinned headers and diff against LANE_CLASSES")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()

    if args.self_test:
        return run_self_test()

    exit_code = 0
    cache = build_cache()

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

    print(f"#812 Drawing/2D lane: {total} classes across {len(LANE_CLASSES)} packages "
          f"(Prs3d_: 0, see docstring)")
    print(f"{'class':<62} {'verdict':<22} note")
    print("-" * 130)

    tally = {"ok": 0, "deliberate, recorded": 0, "under": 0, "over": 0}
    unders = []
    for pkg in sorted(LANE_CLASSES):
        for cls in LANE_CLASSES[pkg]:
            verdict, note, bridge, docs = classify(cls, cache)
            tally[verdict] += 1
            if verdict == "under":
                unders.append((cls, note))
            print(f"{cls:<62} {verdict:<22} {note}")
            if args.verbose:
                if bridge:
                    print(f"{'':<62} {'':<22} bridge: {', '.join(bridge)}")
                if docs:
                    print(f"{'':<62} {'':<22} docs:   {', '.join(docs)}")

    print()
    print("verdicts:")
    for k in ("ok", "deliberate, recorded", "under"):
        print(f"  {k:<22} {tally[k]}")

    print()
    print(f"over-coverage findings tracked: {KNOWN_OVER_FINDING_COUNT} "
          f"({len(REJECTED_OVER_CANDIDATES)} candidates investigated and rejected, see docstring)")
    regressions = check_known_over_findings()
    if regressions:
        print("REGRESSION: the following fixed over-coverage findings have reappeared:")
        for m in regressions:
            print(f"  {m}")
        exit_code = 1
    else:
        print("  none tracked, none regressed")

    checked, msgs, n = check_method_attributions()
    print()
    if not checked:
        print(f"method attributions: SKIPPED ({msgs[0]})")
    else:
        print(f"method attributions checked (this lane's classes only): {n}")
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
            print("lane re-derivation: the pinned headers still give exactly these 93 classes")

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
