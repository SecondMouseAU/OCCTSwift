#!/usr/bin/env python3
"""Issue #808 (Pass 2a of #807): refman coverage census for the Shape/Topology core lane.

Lane, per #808: every OCCT class under `TopoDS_*`, `TopExp*`, `TopTools_*`, `BRep_Tool`,
`BRepBuilderAPI_*`, `BRepPrimAPI_*`, `BRepAlgoAPI_*` and `BRepCheck_*`, and the Swift surface on
`Shape`, `Face`, `Edge` and `Wire` those sit under.

TWO DELIBERATE LANE DECISIONS, both wider or narrower than a literal reading of the issue text:

  WIDER. #808 names `BRep_Tool`, one class. This census audits the whole `BRep_*` package (23
  headers). `BRep_Tool` is the read side of a package whose write side is `BRep_Builder` and whose
  storage is the `BRep_T{Edge,Face,Vertex}` / `BRep_CurveRepresentation` record hierarchy, all of
  which back the same `Shape`/`Face`/`Edge`/`Wire` surface the issue puts in the lane. Auditing one
  class of a package and calling the package covered is the failure this epic exists to catch.

  NARROWER. `TopoDSToStep_*` matches a naive `^TopoDS` glob (24 headers) and is excluded. It is a
  different package (STEP topology translation), and it is Pass 4c's lane, not this one.

  Neither `TopAbs_*` nor `BRepTools*` is in the lane. Both are adjacent and both are genuinely used
  by this Swift surface; both are named by neither #808 nor any other pass, so Phase 6's
  whole-surface pass is where they land. Recorded here rather than silently skipped.

WHY A SCRIPT, NOT A LIST IN THE ISSUE: `docs/v2.0.0-plan.md`'s census rule, and this repo's history
of hand-built censuses that were confidently wrong differently each time (#558, #571, #573, #583,
#595, #507, #553, #562, and 3/7 of one batch of auditor claims in #380).

TWO QUESTIONS, per #808:

  UNDER-COVERAGE: an OCCT class in the lane we neither wrap (name it on a line of
  `Sources/OCCTBridge/{src/*.mm,include/*.h}` that is neither a bare `#include` nor a comment) nor
  document (name it anywhere under `docs/` except `docs/CHANGELOG.md`, a historical record of what
  a past release changed rather than a claim about the current tree), with no reason recorded in
  `docs/occtswift-wrapping-gaps.md`.

  OVER-COVERAGE: something current docs assert that the pinned refman does not support. The
  mechanical scan below cannot see a WRONG attribution (a doc naming a real, wrapped class that is
  not the one backing the method it documents). That needs reading each call site, which is what
  #808's own investigation did; the 26 confirmed findings are `KNOWN_OVER_FINDINGS` below, each
  fixed in the same PR that adds this script, and each regression-checked here. One of the 26
  covers two entries that carried byte-identical wrong text, so 27 sites were corrected.

TWO RULES THAT DIVERGE FROM #809'S (Pass 2b), both because this lane forced them:

  1. A COMMENT DOES NOT COUNT AS A USE. #809 counted any non-`#include` line. In this lane that is
     wrong six times over: `BRepAlgoAPI_BooleanOperation`, `BRepBuilderAPI_EdgeError`, `BRepCheck`,
     `BRep_TEdge`, `TopTools_IndexedMapOfOrientedShape` and `TopTools_ShapeSet` appear ONLY inside
     bridge comments, and one of those comments is over-coverage finding #3 below. Counting a
     comment as a wrap would have hidden the finding behind an `ok`.

  2. A DEPRECATED ALIAS THAT IS STILL CALLED IS `ok`, NOT `deliberate, recorded`. #809 put its
     deprecated `GCE2d_*` aliases in a curated table checked before the wrapped/unwrapped test, so a
     live call site could not surface. This lane has 35 deprecated headers and five of them are
     genuinely called (measured, see DEPRECATED_ALIASES), so the tables here are consulted only
     AFTER the wrapped test, and a wrapped deprecated alias is reported `ok` with its deprecation in
     the note. Same facts, but the live ones stay visible.

CLASSIFICATION RULES (mechanical unless a class is in one of the CURATED_* tables below, each
established during #808's investigation by reading the pinned header, the refman via the `context`
MCP, and/or the real bridge call site; never inferred from the class name):

  - DEPRECATED_ALIASES: the header carries `Standard_HEADER_DEPRECATED`/`Standard_DEPRECATED` and is
    a `typedef`/`using` for an `NCollection_*` instantiation, not a distinct class.
  - EXCEPTION_TYPES: a `DEFINE_STANDARD_EXCEPTION` class, absorbed by the bridge's blanket
    `catch (...)` at every call site that could raise it.
  - ABSTRACT_BASES: a pure virtual, or a protected-only constructor, in the pinned header.
  - INTERNAL_REPRESENTATION: a concrete B-Rep storage record reached only through `BRep_Tool` /
    `BRep_Builder` / `TopoDS_Shape`, which `TopoDS_TShape`'s own header calls out: "Users have no
    direct access to the classes derived from TShape".
  - INTERNAL_HELPERS: a concrete class serving one specific already-wrapped algorithm.
  - ENUMS_MIRRORED: an enum with no wrapped type name, but whose values the Swift surface mirrors
    case for case (verified against the pinned header's own ordinals).
  - ENUMS_UNWRAPPED: an enum whose values nothing in the tree reads. A real capability gap.
  - COVERED_BY_SIBLING: the capability is wrapped through a different OCCT class.
  - Everything else: WRAPPED if named on a bridge line that is not a bare `#include` and not a
    comment; DOCUMENTED if named anywhere under `docs/` other than `docs/CHANGELOG.md`.

Run: `python3 Scripts/repro/808-refman-shape-topology/refman_census.py` from anywhere (paths derive
from this file's location, not the cwd). Exits 1 on a `KNOWN_OVER_FINDINGS` regression, on an
`under` with no `docs/occtswift-wrapping-gaps.md` line, or on lane drift under `--reverify-lane`;
0 otherwise. `--verbose` prints each class's matching files. `--reverify-lane` re-derives LANE_CLASSES
from the bundled xcframework headers and fails if the embedded list no longer matches the pin, so a
kernel bump that adds or removes a lane class is reported rather than silently audited from a stale
list; it is a no-op with a note when `Libraries/` is absent, which is the case in CI.
"""

from __future__ import annotations

import argparse
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
BRIDGE_SRC = os.path.join(ROOT, "Sources", "OCCTBridge", "src")
BRIDGE_INC = os.path.join(ROOT, "Sources", "OCCTBridge", "include")
DOCS_DIR = os.path.join(ROOT, "docs")
GAPS_FILE = os.path.join(DOCS_DIR, "occtswift-wrapping-gaps.md")
OCCT_HEADERS = os.path.join(
    ROOT, "Libraries", "OCCT.xcframework", "macos-arm64", "Headers"
)

# ---------------------------------------------------------------------------------------------
# The lane: 151 classes, enumerated from the pinned kernel's own headers (OCCT 8.0.1 + the carried
# patches, `Package.swift`'s v2.0.0 asset) on 2026-08-16. Re-derive with:
#
#   ls Libraries/OCCT.xcframework/macos-arm64/Headers \
#     | grep -E '^(TopoDS(_[^.]+)?|TopExp(_[^.]+)?|TopTools_[^.]+|BRep_[^.]+|BRepBuilderAPI_[^.]+|BRepPrimAPI_[^.]+|BRepAlgoAPI_[^.]+|BRepCheck(_[^.]+)?)\.hxx$' \
#     | sed 's/\.hxx$//' | sort
#
# (`.lxx` inline files and the `TopoDSToStep_*` package are excluded; see the lane note above.)
# `--reverify-lane` runs exactly that derivation and diffs it against this list.
# ---------------------------------------------------------------------------------------------

LANE_CLASSES: dict[str, list[str]] = {
    "TopoDS_*": """TopoDS TopoDS_AlertAttribute TopoDS_AlertWithShape TopoDS_Builder
        TopoDS_CompSolid TopoDS_Compound TopoDS_Edge TopoDS_Face TopoDS_FrozenShape TopoDS_HShape
        TopoDS_Iterator TopoDS_LockedShape TopoDS_Shape TopoDS_Shell TopoDS_Solid
        TopoDS_TCompSolid TopoDS_TCompound TopoDS_TEdge TopoDS_TFace TopoDS_TShape TopoDS_TShell
        TopoDS_TSolid TopoDS_TVertex TopoDS_TWire TopoDS_UnCompatibleShapes TopoDS_Vertex
        TopoDS_Wire""".split(),
    "TopExp*": "TopExp TopExp_Explorer".split(),
    "TopTools_*": """TopTools_Array1OfListOfShape TopTools_Array1OfShape TopTools_Array2OfShape
        TopTools_DataMapOfIntegerListOfShape TopTools_DataMapOfIntegerShape
        TopTools_DataMapOfOrientedShapeInteger TopTools_DataMapOfOrientedShapeShape
        TopTools_DataMapOfShapeBox TopTools_DataMapOfShapeInteger
        TopTools_DataMapOfShapeListOfInteger TopTools_DataMapOfShapeListOfShape
        TopTools_DataMapOfShapeReal TopTools_DataMapOfShapeSequenceOfShape
        TopTools_DataMapOfShapeShape TopTools_FormatVersion TopTools_HArray1OfListOfShape
        TopTools_HArray1OfShape TopTools_HArray2OfShape TopTools_HSequenceOfShape
        TopTools_IndexedDataMapOfShapeAddress TopTools_IndexedDataMapOfShapeListOfShape
        TopTools_IndexedDataMapOfShapeReal TopTools_IndexedDataMapOfShapeShape
        TopTools_IndexedMapOfOrientedShape TopTools_IndexedMapOfShape TopTools_ListOfListOfShape
        TopTools_ListOfShape TopTools_LocationSet TopTools_LocationSetPtr
        TopTools_MapOfOrientedShape TopTools_MapOfShape TopTools_SequenceOfShape
        TopTools_ShapeMapHasher TopTools_ShapeSet""".split(),
    "BRep_*": """BRep_Builder BRep_Curve3D BRep_CurveOn2Surfaces BRep_CurveOnClosedSurface
        BRep_CurveOnSurface BRep_CurveRepresentation BRep_GCurve BRep_ListOfCurveRepresentation
        BRep_ListOfPointRepresentation BRep_PointOnCurve BRep_PointOnCurveOnSurface
        BRep_PointOnSurface BRep_PointRepresentation BRep_PointsOnSurface BRep_Polygon3D
        BRep_PolygonOnClosedSurface BRep_PolygonOnClosedTriangulation BRep_PolygonOnSurface
        BRep_PolygonOnTriangulation BRep_TEdge BRep_TFace BRep_TVertex BRep_Tool""".split(),
    "BRepBuilderAPI_*": """BRepBuilderAPI_BndBoxTreeSelector BRepBuilderAPI_CellFilter
        BRepBuilderAPI_Collect BRepBuilderAPI_Command BRepBuilderAPI_Copy BRepBuilderAPI_EdgeError
        BRepBuilderAPI_FaceError BRepBuilderAPI_FastSewing BRepBuilderAPI_FindPlane
        BRepBuilderAPI_GTransform BRepBuilderAPI_MakeEdge BRepBuilderAPI_MakeEdge2d
        BRepBuilderAPI_MakeFace BRepBuilderAPI_MakePolygon BRepBuilderAPI_MakeShape
        BRepBuilderAPI_MakeShapeOnMesh BRepBuilderAPI_MakeShell BRepBuilderAPI_MakeSolid
        BRepBuilderAPI_MakeVertex BRepBuilderAPI_MakeWire BRepBuilderAPI_ModifyShape
        BRepBuilderAPI_NurbsConvert BRepBuilderAPI_PipeError BRepBuilderAPI_Sewing
        BRepBuilderAPI_ShapeModification BRepBuilderAPI_ShellError BRepBuilderAPI_Transform
        BRepBuilderAPI_TransitionMode BRepBuilderAPI_VertexInspector
        BRepBuilderAPI_WireError""".split(),
    "BRepPrimAPI_*": """BRepPrimAPI_MakeBox BRepPrimAPI_MakeCone BRepPrimAPI_MakeCylinder
        BRepPrimAPI_MakeHalfSpace BRepPrimAPI_MakeOneAxis BRepPrimAPI_MakePrism
        BRepPrimAPI_MakeRevol BRepPrimAPI_MakeRevolution BRepPrimAPI_MakeSphere
        BRepPrimAPI_MakeSweep BRepPrimAPI_MakeTorus BRepPrimAPI_MakeWedge""".split(),
    "BRepAlgoAPI_*": """BRepAlgoAPI_Algo BRepAlgoAPI_BooleanOperation BRepAlgoAPI_BuilderAlgo
        BRepAlgoAPI_Check BRepAlgoAPI_Common BRepAlgoAPI_Cut BRepAlgoAPI_Defeaturing
        BRepAlgoAPI_Fuse BRepAlgoAPI_Section BRepAlgoAPI_Splitter""".split(),
    "BRepCheck*": """BRepCheck BRepCheck_Analyzer BRepCheck_DataMapOfShapeListOfStatus
        BRepCheck_Edge BRepCheck_Face BRepCheck_IndexedDataMapOfShapeResult BRepCheck_ListOfStatus
        BRepCheck_Result BRepCheck_Shell BRepCheck_Solid BRepCheck_Status BRepCheck_Vertex
        BRepCheck_Wire""".split(),
}

LANE_HEADER_RE = re.compile(
    r"^(TopoDS(_[^.]+)?|TopExp(_[^.]+)?|TopTools_[^.]+|BRep_[^.]+|BRepBuilderAPI_[^.]+"
    r"|BRepPrimAPI_[^.]+|BRepAlgoAPI_[^.]+|BRepCheck(_[^.]+)?)\.hxx$"
)

# ---------------------------------------------------------------------------------------------
# Curated classifications. Each entry's reason was read out of the pinned header, the refman, or
# the bridge call site during #808; the matching `docs/occtswift-wrapping-gaps.md` entry carries
# the long form. `note` here is the short form.
# ---------------------------------------------------------------------------------------------

# 35 headers, every one carrying BOTH `Standard_HEADER_DEPRECATED` (file scope) and
# `Standard_DEPRECATED` (on the typedef), all "deprecated since OCCT 8.0.0". Derived, not typed by
# hand: `grep -l Standard_DEPRECATED` over the lane's headers.
_DEPRECATED_NOTE = (
    "deprecated since OCCT 8.0.0; a typedef for an NCollection_* instantiation, not a distinct "
    "class."
)
DEPRECATED_ALIASES = {
    name: _DEPRECATED_NOTE
    for name in """BRepBuilderAPI_CellFilter BRepCheck_DataMapOfShapeListOfStatus
        BRepCheck_IndexedDataMapOfShapeResult BRepCheck_ListOfStatus
        BRep_ListOfCurveRepresentation BRep_ListOfPointRepresentation
        TopTools_Array1OfListOfShape TopTools_Array1OfShape TopTools_Array2OfShape
        TopTools_DataMapOfIntegerListOfShape TopTools_DataMapOfIntegerShape
        TopTools_DataMapOfOrientedShapeInteger TopTools_DataMapOfOrientedShapeShape
        TopTools_DataMapOfShapeBox TopTools_DataMapOfShapeInteger
        TopTools_DataMapOfShapeListOfInteger TopTools_DataMapOfShapeListOfShape
        TopTools_DataMapOfShapeReal TopTools_DataMapOfShapeSequenceOfShape
        TopTools_DataMapOfShapeShape TopTools_HArray1OfListOfShape TopTools_HArray1OfShape
        TopTools_HArray2OfShape TopTools_HSequenceOfShape TopTools_IndexedDataMapOfShapeAddress
        TopTools_IndexedDataMapOfShapeListOfShape TopTools_IndexedDataMapOfShapeReal
        TopTools_IndexedDataMapOfShapeShape TopTools_IndexedMapOfOrientedShape
        TopTools_IndexedMapOfShape TopTools_ListOfListOfShape TopTools_ListOfShape
        TopTools_MapOfOrientedShape TopTools_MapOfShape TopTools_SequenceOfShape""".split()
}

EXCEPTION_TYPES = {
    "TopoDS_FrozenShape": "DEFINE_STANDARD_EXCEPTION(Standard_DomainError), raised when modifying "
        "a shape that is already shared or protected; absorbed by the bridge's catch (...).",
    "TopoDS_LockedShape": "DEFINE_STANDARD_EXCEPTION(Standard_DomainError), raised when modifying "
        "the geometry of a shared or protected shape; absorbed the same way.",
    "TopoDS_UnCompatibleShapes": "DEFINE_STANDARD_EXCEPTION(Standard_DomainError), raised by "
        "TopoDS_Builder::Add for an incorrect insertion; absorbed the same way.",
}

ABSTRACT_BASES = {
    "BRepAlgoAPI_Algo": "root interface for the BRepAlgoAPI algorithms; protected constructors.",
    "BRepAlgoAPI_BooleanOperation": "the common base of BRepAlgoAPI_Common/Cut/Fuse/Section, all "
        "four wrapped; protected constructors.",
    "BRepBuilderAPI_Command": "root of every BRepBuilderAPI command (the IsDone flag); protected "
        "constructor.",
    "BRepBuilderAPI_ModifyShape": "root of BRepBuilderAPI_Copy/Transform/GTransform/NurbsConvert, "
        "all four wrapped; protected constructors.",
    "BRepPrimAPI_MakeOneAxis": "root of the rotational primitives (Cone/Cylinder/Sphere/Torus/"
        "Revolution, all wrapped); pure virtual OneAxis().",
    "BRepPrimAPI_MakeSweep": "root of the swept primitives (Prism/Revol/Pipe/PipeShell, all "
        "wrapped); pure virtual FirstShape()/LastShape().",
    "BRep_CurveRepresentation": "root of the edge curve-representation records; pure virtual "
        "Copy().",
    "BRep_GCurve": "root of the geometric curve representations; pure virtual D0().",
    "BRep_PointRepresentation": "root of the vertex point-representation records; protected "
        "constructor.",
    "BRep_PointsOnSurface": "root of the on-surface point representations; protected constructor.",
    "TopoDS_TShape": "root of the TShape hierarchy; pure virtual EmptyCopy(). Its own header: "
        "\"Users have no direct access to the classes derived from TShape\".",
    "TopoDS_TEdge": "abstract TShape subclass (protected constructor); BRep_TEdge is the concrete "
        "one.",
    "TopoDS_TVertex": "abstract TShape subclass (protected constructor, EmptyCopy left pure); "
        "BRep_TVertex is the concrete one.",
}

INTERNAL_REPRESENTATION = {
    name: "internal B-Rep storage record, reached only through BRep_Tool / BRep_Builder / "
        "TopoDS_Shape; never constructed by a wrapper."
    for name in """BRep_Curve3D BRep_CurveOn2Surfaces BRep_CurveOnClosedSurface BRep_CurveOnSurface
        BRep_PointOnCurve BRep_PointOnCurveOnSurface BRep_PointOnSurface BRep_Polygon3D
        BRep_PolygonOnClosedSurface BRep_PolygonOnClosedTriangulation BRep_PolygonOnSurface
        BRep_PolygonOnTriangulation BRep_TEdge BRep_TFace BRep_TVertex TopoDS_TCompSolid
        TopoDS_TCompound TopoDS_TFace TopoDS_TShell TopoDS_TSolid TopoDS_TWire""".split()
}

INTERNAL_HELPERS = {
    "BRepCheck": "the package class, two statics (Add/Print) that append a BRepCheck_Status to a "
        "result list; the checkers themselves (BRepCheck_Analyzer/_Edge/_Face/_Wire/_Shell/_Solid/"
        "_Vertex/_Result/_Status) are all wrapped.",
    "BRepBuilderAPI_BndBoxTreeSelector": "an NCollection_UBTree::Selector subclass; no other pinned "
        "header names it, so it is reachable only from OCCT's own .cxx.",
    "BRepBuilderAPI_VertexInspector": "the NCollection_CellFilter inspector behind the deprecated "
        "BRepBuilderAPI_CellFilter typedef; its only pinned-header consumer is that typedef.",
    "TopTools_LocationSet": "the relocatable location table inside TopTools_ShapeSet; reached "
        "through BRepTools::Write/Read, which the BREP serialization surface already wraps.",
    "TopTools_LocationSetPtr": "`typedef TopTools_LocationSet* TopTools_LocationSetPtr;`, a raw "
        "pointer alias for the above.",
    "TopTools_ShapeSet": "the BREP file shape table; reached through BRepTools::Write/Read. Cited "
        "by file and line in docs and in the bridge as the source of the IsSame sub-shape "
        "enumeration (#541), never constructed.",
    "TopoDS_AlertAttribute": "a Message_AttributeStream subclass carrying a TopoDS_Shape; no other "
        "pinned header names it.",
    "TopoDS_AlertWithShape": "a Message_Alert subclass carrying a TopoDS_Shape, used by "
        "BOPAlgo_Alerts; the wrapped Message_Report surface reads alert text, not attached shapes.",
}

ENUMS_MIRRORED = {
    "BRepBuilderAPI_WireError": "the Swift `WireBuilder.WireError` mirrors all four values in "
        "order (wireDone/emptyWire/disconnectedWire/nonManifoldWire); the bridge reads "
        "`maker.Error()` and compares against `BRepBuilderAPI_WireDone` without naming the type.",
    "BRepBuilderAPI_PipeError": "the Swift `PipeShellStatus` mirrors all four values in order "
        "(ok/notOk/planeNotIntersectGuide/impossibleContact) via "
        "BRepOffsetAPI_MakePipeShell::GetStatus.",
    "BRepBuilderAPI_TransitionMode": "the Swift `PipeTransitionMode` mirrors all three values in "
        "order (transformed/rightCorner/roundCorner); the header is #include'd and the ordinal is "
        "passed through.",
    "TopTools_FormatVersion": "the bridge passes `TopTools_FormatVersion_CURRENT` to "
        "BRepTools::Write without naming the type. Choosing an OLDER BREP format version is NOT "
        "exposed; see the wrapping-gaps entry.",
}

ENUMS_UNWRAPPED = {
    "BRepBuilderAPI_FaceError": "BRepBuilderAPI_MakeFace::Error()'s status, its only pinned-header "
        "consumer. The face builders report failure as a nil Shape and drop the reason.",
    "BRepBuilderAPI_ShellError": "BRepBuilderAPI_MakeShell::Error()'s status, its only "
        "pinned-header consumer. Same nil-Shape treatment.",
    "BRepBuilderAPI_EdgeError": "BRepBuilderAPI_MakeEdge/MakeEdge2d::Error()'s status, its only "
        "pinned-header consumers. Named by one bridge comment, which #808 corrected because the "
        "function under it returns a BRepCheck_Analyzer verdict rather than this enum.",
    "BRepBuilderAPI_ShapeModification": "no consumer at all: no other header in the pinned "
        "xcframework names it, so there is no OCCT 8.0.1 entry point returning it to wrap.",
}

COVERED_BY_SIBLING = {
    "BRepBuilderAPI_Collect": "history accumulation across BRepBuilderAPI_MakeShape runs; its one "
        "pinned-header consumer is BRepBuilderAPI_GTransform's private member. The same capability "
        "is wrapped through BRepTools_History (`History: merge/replaceGenerated/replaceModified/"
        "getModifiedShapes/getGeneratedShapes`).",
    "TopoDS_HShape": "a Standard_Transient handle wrapper around TopoDS_Shape. OCCTSwift's own "
        "`Shape` is already a reference-counted wrapper over the same value, so a second handle "
        "type adds a lifetime to manage and no capability.",
}

CURATED_TABLES = [
    ("deprecated alias", DEPRECATED_ALIASES),
    ("exception type", EXCEPTION_TYPES),
    ("abstract base", ABSTRACT_BASES),
    ("internal representation", INTERNAL_REPRESENTATION),
    ("internal helper", INTERNAL_HELPERS),
    ("enum, values mirrored", ENUMS_MIRRORED),
    ("enum, unwrapped", ENUMS_UNWRAPPED),
    ("covered by sibling", COVERED_BY_SIBLING),
]

# ---------------------------------------------------------------------------------------------
# Confirmed over-coverage findings (#808), each fixed in the same PR that adds this script.
# `bad_phrase` is the wrong text that used to appear in `doc_file`; this script exits 1 if it ever
# reappears, and reports the finding as fixed otherwise.
#
# Twenty-six findings in four shapes.
#
# THE `TopExp_Explorer` FAMILY (5). One mistake made five times: the doc names `TopExp_Explorer`,
# which yields one entry per OCCURRENCE (24 edges on a plain box), where the implementation calls
# `TopExp::MapShapes` / `TopExp::MapShapesAndUniqueAncestors`, which key on `TopoDS_Shape::IsSame`
# and yield one entry per DISTINCT sub-shape (12). That is the exact confusion #541/#613/#638/#651
# fixed in the code and #784 removed the last API for; these five doc lines are what was left
# behind, and four of them sit on methods whose whole point is the deduplicated count.
#
# A BRIDGE HEADER COMMENT (1) naming an OCCT enum its own function cannot return.
#
# A CLASS NOWHERE IN THE CALL CHAIN (17). The doc names a real OCCT class, and a different one
# runs. Several pairs are semantically distinct rather than merely misnamed: `TopoDS_Shape::Closed()`
# reads a stored flag where `BRep_Tool::IsClosed` computes closure; `TopoDS_Shape::Moved` attaches a
# location where `BRepBuilderAPI_Transform` rebuilds geometry; `BRepTools_Quilt` requires shared
# edges where `BRepBuilderAPI_Sewing` reconciles near-coincident ones.
#
# ONE OF TWO NAMED CLASSES HOLDS (3). The entry names two classes joined by "or" or "/", one of
# which is genuinely in the chain and one of which is not.
#
# Every one was confirmed by reading the Swift method, following it to its bridge function, and
# reading that function's body, per okf/policies/measure-dont-assume.md. Five were found twice, by
# two independent sweeps, which is the only reason the overlap is stated rather than assumed.
# ---------------------------------------------------------------------------------------------

KNOWN_OVER_FINDINGS = [
    {
        "lane": "TopExp*",
        "subject": "Shape.uniqueEdgeCount",
        "doc_file": "docs/reference/Document-Mesh-Fixing.md",
        "bad_phrase": "- **OCCT:** `TopExp_Explorer` with `TopAbs_EDGE`, deduplicated "
            "(via `OCCTShapeUniqueEdgeCount`).",
        "correct": "TopExp::MapShapes(shape, TopAbs_EDGE) into a TopTools_IndexedMapOfShape; "
            "TopExp_Explorer is the class that does NOT deduplicate.",
    },
    {
        "lane": "TopExp*",
        "subject": "Shape.uniqueSubShapeCount(ofType:)",
        "doc_file": "docs/reference/Document-Mesh-Fixing.md",
        "bad_phrase": "- **OCCT:** `TopExp_Explorer` deduplicated "
            "(via `OCCTShapeUniqueSubShapeCount`).",
        "correct": "TopExp::MapShapes into a TopTools_IndexedMapOfShape, same as above.",
    },
    {
        "lane": "BRepBuilderAPI_*",
        "subject": "OCCTMakeEdgeError (bridge header doc)",
        "doc_file": "Sources/OCCTBridge/include/OCCTBridge_Modeling.h",
        "bad_phrase": "/// Get the BRepBuilderAPI_EdgeError for the last MakeEdge "
            "(0=done, 1=PointProjectionFailed, etc).",
        "correct": "the implementation runs BRepCheck_Analyzer on the finished edge and returns "
            "0/1/-1; BRepBuilderAPI_MakeEdge::Error() is a property of the builder and is "
            "unreachable from a TopoDS_Edge, which is why the proxy exists.",
    },
    {
        "lane": "TopExp*",
        "subject": "Shape.edgeCount",
        "doc_file": "docs/API_REFERENCE.md",
        "bad_phrase": "| `shape.edgeCount` | `TopExp_Explorer` |",
        "correct": "TopExp::MapShapes(shape, TopAbs_EDGE); `Edge.md`'s own entry for the same "
            "property already said so, and `Edge.swift`'s doc comment contrasts the two.",
    },
    {
        "lane": "TopExp*",
        "subject": "Shape.edgeFaceAdjacency()",
        "doc_file": "docs/reference/Document-Analysis-Builders.md",
        "bad_phrase": "- **OCCT:** `TopExp_Explorer` / adjacency map via `OCCTEdgeFaceAdjacency`.",
        "correct": "TopExp::MapShapesAndUniqueAncestors(shape, TopAbs_EDGE, TopAbs_FACE); no "
            "explorer is constructed.",
    },
    {
        "lane": "TopExp*",
        "subject": "Shape.vertexEdgeAdjacency()",
        "doc_file": "docs/reference/Document-Analysis-Builders.md",
        "bad_phrase": "- **OCCT:** `TopExp_Explorer` / adjacency map via "
            "`OCCTVertexEdgeAdjacency`.",
        "correct": "TopExp::MapShapesAndUniqueAncestors(shape, TopAbs_VERTEX, TopAbs_EDGE); same.",
    },

    # --- A named class that is nowhere in the call chain, and a different one runs.
    {
        "lane": "BRepPrimAPI_*",
        "subject": "Shape.extrudedSemiInfinite(direction:infinite:)",
        "doc_file": "docs/reference/Shape-Measurement.md",
        "bad_phrase": "- **OCCT:** `BRepPrimAPI_MakeHalfSpace` / `BRepBuilderAPI_MakeSolid` "
            "(via `OCCTShapeExtrudeSemiInfinite`).",
        "correct": "BRepPrimAPI_MakePrism(profile, dir, Copy = !infinite).",
    },
    {
        "lane": "BRepBuilderAPI_*",
        "subject": "Shape.quilt(_:)",
        "doc_file": "docs/reference/Shape-Healing.md",
        "bad_phrase": "- **OCCT:** `BRepBuilderAPI_Sewing` (via `OCCTShapeQuilt`).",
        "correct": "BRepTools_Quilt::Add then Shells(). Quilting joins faces that ALREADY share "
            "edges; sewing reconciles near-coincident ones within a tolerance.",
    },
    {
        "lane": "BRepAlgoAPI_*",
        "subject": "Shape.splittingFace(with:faceIndex:)",
        "doc_file": "docs/reference/Shape-Healing.md",
        "bad_phrase": "- **OCCT:** `BRepAlgoAPI_Splitter` (via `OCCTShapeSplitByWire`).",
        "correct": "BRepFeat_SplitShape::Add(wire, face) then Build().",
    },
    {
        "lane": "BRepPrimAPI_*",
        "subject": "Shape.revolution(meridian:axisOrigin:axisDirection:angle:)",
        "doc_file": "docs/reference/Shape-Healing.md",
        "bad_phrase": "- **OCCT:** `BRepPrimAPI_MakeRevol` "
            "(via `OCCTShapeCreateRevolutionFromCurve`).",
        "correct": "BRepPrimAPI_MakeRevolution, a different class in the same package: MakeRevol "
            "revolves a shape, MakeRevolution revolves a Geom_Curve meridian.",
    },
    {
        "lane": "BRepBuilderAPI_*",
        "subject": "Shape.findSurface(tolerance:)",
        "doc_file": "docs/reference/Shape-Healing.md",
        "bad_phrase": "- **OCCT:** `BRepBuilderAPI_FindPlane` / `GeomPlate` "
            "(via `OCCTShapeFindSurface`).",
        "correct": "BRepLib_FindSurface(shape, tolerance, onlyPlane = false), which fits any "
            "surface rather than only a plane, matching what the method's Returns promises.",
    },
    {
        "lane": "BRepAlgoAPI_*",
        "subject": "Shape.fuseAll(_:)",
        "doc_file": "docs/reference/Shape-Healing.md",
        "bad_phrase": "- **OCCT:** `BRepAlgoAPI_Fuse` multi-tool mode (via `OCCTShapeFuseMulti`).",
        "correct": "BRepAlgoAPI_BuilderAlgo::SetArguments then Build(); BRepAlgoAPI_Fuse is never "
            "constructed.",
    },
    {
        "lane": "BRepBuilderAPI_*",
        "subject": "Shape.convertedToBSpline()",
        "doc_file": "docs/reference/Shape-Healing.md",
        "bad_phrase": "- **OCCT:** `ShapeCustom_BSplineRestriction` / `BRepBuilderAPI_NurbsConvert` "
            "(via `OCCTShapeConvertToBSpline`).",
        "correct": "ShapeCustom::ConvertToBSpline driving ShapeCustom_ConvertToBSpline through a "
            "BRepTools_Modifier. Both named classes are wrapped, by other methods.",
    },
    {
        "lane": "BRepBuilderAPI_*",
        "subject": "Shape.removingLocations()",
        "doc_file": "docs/reference/Shape-Healing.md",
        "bad_phrase": "- **OCCT:** `BRepBuilderAPI_Copy` with location removal "
            "(via `OCCTShapeRemoveLocations`).",
        "correct": "ShapeUpgrade_RemoveLocations::Remove then GetResult().",
    },
    {
        "lane": "BRepCheck*",
        "subject": "Shape.hasFreeEdges",
        "doc_file": "docs/reference/Shape-Completions.md",
        "bad_phrase": "- **OCCT:** `ShapeAnalysis_FreeBounds` or `BRepCheck_Analyzer`.",
        "correct": "TopExp::MapShapesAndAncestors(TopAbs_EDGE, TopAbs_FACE) then a fewer-than-two "
            "incidence test; no tolerance and no wire chaining.",
    },
    {
        "lane": "BRep_*",
        "subject": "Shape.maxEdgeTolerance AND Shape.maxTolerance(subShapeType:)",
        "doc_file": "docs/reference/Shape-Completions.md",
        "bad_phrase": "- **OCCT:** `BRep_Tool::MaxTolerance` / `ShapeAnalysis_ShapeTolerance`.",
        "correct": "the identical wrong line sat on BOTH entries, with the two classes the wrong "
            "way round: maxEdgeTolerance calls ShapeAnalysis_ShapeTolerance::Tolerance(shape, 1, "
            "TopAbs_EDGE) and never BRep_Tool, while maxTolerance(subShapeType:) calls "
            "BRep_Tool::MaxTolerance and never ShapeAnalysis. Found by this script's own "
            "regression check after the first was fixed, which is the whole point of keeping it.",
    },
    {
        "lane": "BRep_*",
        "subject": "Shape.isClosedShape",
        "doc_file": "docs/reference/Document-Mesh-Fixing.md",
        "bad_phrase": "- **OCCT:** `BRep_Tool::IsClosed` (via `OCCTShapeIsClosed`).",
        "correct": "TopoDS_Shape::Closed(), the stored flag. BRep_Tool::IsClosed computes closure "
            "from the topology, so the two disagree on a shape whose flag was never set.",
    },
    {
        "lane": "TopoDS_*",
        "subject": "Shape.moved(dx:dy:dz:)",
        "doc_file": "docs/reference/Document-Completions.md",
        "bad_phrase": "- **OCCT:** `gp_Trsf` translation → `BRepBuilderAPI_Transform`.",
        "correct": "TopoDS_Shape::Moved(TopLoc_Location(trsf)), which attaches a location and "
            "leaves the geometry shared, where BRepBuilderAPI_Transform rebuilds it.",
    },
    {
        "lane": "BRep_*",
        "subject": "Shape.updateShape()",
        "doc_file": "docs/reference/Document-BSpline-Extrema.md",
        "bad_phrase": "- **OCCT:** `BRep_Builder::UpdateVertex`/`UpdateEdge` (bridge-internal).",
        "correct": "BRepTools::Update(shape).",
    },
    {
        "lane": "BRep_*",
        "subject": "Shape.dividedClosedEdges(splitPoints:)",
        "doc_file": "docs/reference/Shape-Measurement.md",
        "bad_phrase": "- **OCCT:** `ShapeUpgrade_ShapeDivideAngle` / `BRep_Builder` "
            "(via `OCCTShapeDivideClosedEdges`).",
        "correct": "ShapeUpgrade_ShapeDivideClosedEdges. ShapeDivideAngle is a different sibling "
            "of the same base, splitting by angular span.",
    },
    {
        "lane": "TopoDS_*",
        "subject": "Shape.shapeTypeString",
        "doc_file": "docs/reference/Document-Math-Solvers.md",
        "bad_phrase": "- **OCCT:** `BRep_Builder` / `TopAbs_ShapeEnum` via `OCCTShapeTypeString`.",
        "correct": "a switch on TopoDS_Shape::ShapeType()'s TopAbs_ShapeEnum. The same entry's "
            "Returns line was corrected alongside: a null handle yields \"null\", an unnamed enum "
            "value \"shape\", and \"unknown\" only when the lookup throws.",
    },
    {
        "lane": "BRep_*",
        "subject": "mergedMeshNodes(from:smoothAngle:mergeTolerance:)",
        "doc_file": "docs/reference/Shape-Recognition.md",
        "bad_phrase": "- **OCCT:** `BRep_Builder` face iteration + `Poly_Triangulation` via "
            "`OCCTPolyMergeNodes`.",
        "correct": "a per-occurrence TopExp_Explorer walk (occtForEachOrientedFace) feeding "
            "BRep_Tool::Triangulation into Poly_MergeNodesTool::AddTriangulation.",
    },
    {
        "lane": "TopoDS_*",
        "subject": "Shape.nbChildren",
        "doc_file": "docs/reference/Document-BSpline-Extrema.md",
        "bad_phrase": "- **OCCT:** `TopoDS_Iterator` child count.",
        "correct": "TopoDS_Shape::NbChildren() forwarding to TopoDS_TShape::NbChildren(); no "
            "iterator is constructed.",
    },

    # --- One of the two named classes holds and the other does not.
    {
        "lane": "BRep_*",
        "subject": "Shape.setUVPoints(edge:face:first:last:)",
        "doc_file": "docs/reference/Shape-Completions.md",
        "bad_phrase": "- **OCCT:** `BRep_Tool::UVPoints` (setter overload via `BRep_Builder`).",
        "correct": "BRep_Tool::SetUVPoints, its own static, writing through the edge's "
            "BRep_CurveOnSurface representation. There is no UVPoints setter overload, and "
            "BRep_Builder is not called.",
    },
    {
        "lane": "TopoDS_*",
        "subject": "Shape.shellFromFaces(_:)",
        "doc_file": "docs/reference/Document-Mesh-Fixing.md",
        "bad_phrase": "- **OCCT:** `BRepBuilderAPI_Sewing` or `TopoDS_Builder` "
            "(via `OCCTMakeShell`).",
        "correct": "BRep_Builder::MakeShell then Add per face. TopoDS_Builder holds by "
            "inheritance; BRepBuilderAPI_Sewing does not, and the \"or\" misleads because nothing "
            "is sewn, so the faces must already share edges.",
    },
    {
        "lane": "TopoDS_*",
        "subject": "Shape.faceWireCount",
        "doc_file": "docs/reference/Document-BSpline-Extrema.md",
        "bad_phrase": "- **OCCT:** `TopoDS_Face` wire iterator count.",
        "correct": "TopExp_Explorer(shape, TopAbs_WIRE), counted. The shape is never cast to "
            "TopoDS_Face, so the count is not restricted to a face.",
    },
]


def _read(path: str) -> str:
    with open(path, errors="ignore") as fh:
        return fh.read()


def _bridge_files() -> list[str]:
    files = []
    for d in (BRIDGE_SRC, BRIDGE_INC):
        for f in sorted(os.listdir(d)):
            if f.endswith(".mm") or f.endswith(".h"):
                files.append(os.path.join(d, f))
    return files


def _doc_files() -> list[str]:
    out = []
    for dirpath, _dirnames, filenames in os.walk(DOCS_DIR):
        for fn in filenames:
            if fn.endswith(".md") and fn != "CHANGELOG.md":
                out.append(os.path.join(dirpath, fn))
    return out


def _is_comment(line: str) -> bool:
    """A C++ line comment, or a line inside a block comment as this bridge writes them.

    Deliberately conservative: it recognises `//`, a continuation `*`, and an opening `/*`. That
    covers every comment shape in `Sources/OCCTBridge` today (checked: no lane class name appears
    after code on a trailing-comment line, and no block comment in the tree starts a line with
    anything else). A block-comment body line that begins with neither `*` nor `//` would be
    counted as code, which is the safe direction: it can only turn a `deliberate, recorded` into a
    false `ok`, never hide an `under`, and the six comment-only classes this rule exists for are
    named in the module docstring so a regression is visible.
    """
    s = line.strip()
    return s.startswith("//") or s.startswith("*") or s.startswith("/*")


def _is_wrapped(cls: str, bridge_files: list[str]) -> tuple[bool, list[str]]:
    """Wrapped means named on a bridge line that is neither a bare `#include` nor a comment."""
    pat = re.compile(r"\b" + re.escape(cls) + r"\b")
    hits = []
    for path in bridge_files:
        for line in _read(path).splitlines():
            if not pat.search(line):
                continue
            if line.strip().startswith("#include") or _is_comment(line):
                continue
            hits.append(os.path.basename(path))
            break
    return (len(hits) > 0, hits)


def _is_documented(cls: str, doc_files: list[str]) -> tuple[bool, list[str]]:
    pat = re.compile(r"\b" + re.escape(cls) + r"\b")
    hits = []
    for path in doc_files:
        if pat.search(_read(path)):
            hits.append(os.path.relpath(path, ROOT))
    return (len(hits) > 0, hits)


def _in_gaps_doc(cls: str, gaps_text: str) -> bool:
    return re.search(r"\b" + re.escape(cls) + r"\b", gaps_text) is not None


def classify(cls: str, wrapped: bool, documented: bool, gaps_text: str) -> tuple[str, str]:
    """Returns (verdict, note).

    The wrapped test runs FIRST, before the curated tables. That is the divergence from #809
    described in the module docstring: five deprecated aliases in this lane are genuinely called,
    and consulting the tables first would file them as `deliberate, recorded` and hide the live
    call sites behind a table entry saying they have none.
    """
    curated = None
    for label, table in CURATED_TABLES:
        if cls in table:
            curated = (label, table[cls])
            break

    if wrapped:
        note = "wrapped" if documented else "wrapped (undocumented by this exact class name)"
        if curated:
            note = f"{note}; {curated[0]}: {curated[1]}"
        return "ok", note

    if curated:
        label, reason = curated
        verdict = "deliberate, recorded" if _in_gaps_doc(cls, gaps_text) else "under"
        return verdict, f"{label}: {reason}"

    if _in_gaps_doc(cls, gaps_text):
        return "deliberate, recorded", "recorded in occtswift-wrapping-gaps.md"
    return "under", "neither wrapped nor documented, no recorded reason"


def check_over_findings() -> list[dict]:
    """The subset of KNOWN_OVER_FINDINGS whose bad_phrase is STILL present (a regression)."""
    regressions = []
    cache: dict[str, str] = {}
    for finding in KNOWN_OVER_FINDINGS:
        path = os.path.join(ROOT, finding["doc_file"])
        if path not in cache:
            cache[path] = _read(path) if os.path.exists(path) else ""
        # Compare on collapsed whitespace so a re-wrap of the same wrong sentence still counts as
        # a regression rather than slipping through on a line break.
        haystack = " ".join(cache[path].split())
        needle = " ".join(finding["bad_phrase"].split())
        if needle in haystack:
            regressions.append(finding)
    return regressions


def reverify_lane() -> tuple[bool, list[str]]:
    """Re-derive the lane from the bundled headers and diff against LANE_CLASSES.

    Returns (checked, messages). `checked` is False when `Libraries/` is absent, which is the
    normal case in CI and in a fresh clone; the caller reports that rather than passing silently.
    """
    if not os.path.isdir(OCCT_HEADERS):
        return (False, [f"{OCCT_HEADERS} not present, lane re-derivation skipped"])
    derived = set()
    for fn in os.listdir(OCCT_HEADERS):
        if fn.startswith("TopoDSToStep"):
            continue
        if LANE_HEADER_RE.match(fn):
            derived.add(fn[: -len(".hxx")])
    embedded = {c for classes in LANE_CLASSES.values() for c in classes}
    msgs = []
    for c in sorted(derived - embedded):
        msgs.append(f"in the pinned headers but NOT in LANE_CLASSES: {c}")
    for c in sorted(embedded - derived):
        msgs.append(f"in LANE_CLASSES but NOT in the pinned headers: {c}")
    return (True, msgs)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument(
        "--reverify-lane",
        action="store_true",
        help="re-derive LANE_CLASSES from Libraries/OCCT.xcframework and fail on any difference",
    )
    args = parser.parse_args()

    bridge_files = _bridge_files()
    doc_files = _doc_files()
    gaps_text = _read(GAPS_FILE)

    rows = []
    for lane, classes in LANE_CLASSES.items():
        for cls in classes:
            wrapped, wrapped_files = _is_wrapped(cls, bridge_files)
            documented, doc_hits = _is_documented(cls, doc_files)
            verdict, note = classify(cls, wrapped, documented, gaps_text)
            rows.append({
                "lane": lane,
                "class": cls,
                "documented": documented,
                "wrapped": wrapped,
                "verdict": verdict,
                "note": note,
                "wrapped_files": wrapped_files,
                "doc_files": doc_hits,
            })

    print(f"{'lane':18} {'occt_class':42} {'documented?':12} {'wrapped?':9} {'verdict':22} note")
    print("-" * 150)
    for r in rows:
        print(
            f"{r['lane']:18} {r['class']:42} {str(r['documented']):12} {str(r['wrapped']):9} "
            f"{r['verdict']:22} {r['note']}"
        )
        if args.verbose:
            if r["wrapped_files"]:
                print(f"{'':18}   wrapped in: {', '.join(r['wrapped_files'])}")
            if r["doc_files"]:
                print(f"{'':18}   documented in: {', '.join(r['doc_files'])}")

    print()
    counts: dict[str, int] = {}
    for r in rows:
        counts[r["verdict"]] = counts.get(r["verdict"], 0) + 1
    print(f"Total classes in lane: {len(rows)}")
    # Only three verdicts are reachable here. `classify()` returns exactly `ok`,
    # `deliberate, recorded` or `under`; NOTHING in this script can return `over`, because
    # over-coverage is a wrong ATTRIBUTION in prose, not a property of a class's wrapped/documented
    # state. Printing `over: 0` beside the three derived counts would read as a measured all-clear
    # when it is a literal that cannot be anything else, so it is deliberately not printed. See the
    # OVER-COVERAGE paragraph in the module docstring, and #928 for the detector that makes this a
    # real verdict.
    for verdict in ("ok", "deliberate, recorded", "under"):
        print(f"  {verdict}: {counts.get(verdict, 0)}")
    assert not any(r["verdict"] == "over" for r in rows), "classify() cannot return 'over'"

    exit_code = 0

    print()
    print(f"Known over-coverage findings tracked: {len(KNOWN_OVER_FINDINGS)}")
    regressions = check_over_findings()
    if regressions:
        print("REGRESSION: the following fixed over-coverage findings have reappeared:")
        for f in regressions:
            print(f"  {f['doc_file']}: {f['subject']} -- {f['bad_phrase']!r}")
        exit_code = 1
    else:
        print("All known over-coverage findings remain fixed (bad text not found in current docs).")
        print("  NOTE: this is a regression check over the 26 findings #808's investigation found by")
        print("  reading each claim against the refman. It does NOT search for NEW over-coverage,")
        print("  and cannot: see the docstring, and #928 for the detector that will. A clean run")
        print("  here means 'the known ones stayed fixed', not 'this lane has none'.")

    unrecorded = [r for r in rows if r["verdict"] == "under"]
    if unrecorded:
        print()
        print("UNRECORDED under-coverage findings (no docs/occtswift-wrapping-gaps.md line):")
        for r in unrecorded:
            print(f"  {r['lane']} {r['class']}: {r['note']}")
        exit_code = 1

    if args.reverify_lane:
        print()
        checked, msgs = reverify_lane()
        if not checked:
            print(f"Lane re-derivation SKIPPED: {msgs[0]}")
        elif msgs:
            print("LANE DRIFT: the embedded LANE_CLASSES no longer matches the pinned headers.")
            for m in msgs:
                print(f"  {m}")
            print("  Each difference needs a hand audit; re-running this script is not enough.")
            exit_code = 1
        else:
            print(f"Lane re-derivation clean: {len(rows)} classes, matching the pinned headers.")

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
