#!/usr/bin/env python3
"""Issue #814 (Pass 4d of #807): refman coverage census for the Mesh/presentation/misc lane.

WHY A SCRIPT, NOT A LIST IN THE ISSUE: `docs/v2.0.0-plan.md`'s census rule, and this repo's history
of hand-built censuses that were confidently wrong differently each time (#558, #571, #573, #583,
#595, #507, #553, #562). #811/#812/#982/#983 (the four sibling lanes) are the template this file
follows.

THIS IS THE LARGEST LANE IN THE WHOLE PROGRAMME: nine packages, 368 headers, more than #983's 342
(the previous largest) and about 4x #811's 93 or #812's 93. #983's own body predicted its shape
would be different from #811's/#812's ("expect this to be answered once for the whole driver family
rather than per class") and that prediction held; the same call applies here, more so. Of 368
classes, only 45 are directly wrapped or documented and 3 more are already recorded elsewhere in
`docs/occtswift-wrapping-gaps.md` for a pre-existing, unrelated reason (see CURATED below); the
remaining 320 are curated in **family-level buckets**, following #983's precedent rather than
#811's/#812's mostly-per-class tables, because at this scale a paragraph per class would be ten
times #983's own README and would not be more informative: an entire package
(`IMeshData_`/`IMeshTools_`, 23 classes together) is one coherent abstract-interface layer with one
reason, and `Graphic3d_`'s 129 unwrapped classes are overwhelmingly one mechanism (OCCT's own
OpenGl-based live-viewer pipeline, unused because this bridge renders through Metal instead, the
same fact #812's README already established for `Prs3d_` and #982's for `TPrsStd_`).

THE LANE WAS RE-DERIVED BY CALL for its SWIFT side (`derive_lane.py`, next to this file), per #814's
own explicit warning that Pass 4d's duplication work (#388) closed the same day this pass started
and changed `PresentationMesh.swift` and `OCCTBridge_Mesh.mm`. The OCCT PACKAGE side (the nine
packages, 368 headers) is not in question, #814's own body states it with per-package counts that
match the pinned kernel exactly (`--reverify-lane` below re-derives all 368 names directly).

TWO BOUNDARY QUESTIONS #814 FLAGS EXPLICITLY, both confirmed by measurement rather than trusted from
the issue text:

  - **`StdPrs_` (28 headers): confirmed zero wrapped, zero documented.** `grep -rn StdPrs
    Sources/OCCTBridge/ docs/` (excluding this pass's own new gaps.md section) returns nothing at
    all before this PR. Recorded as ONE family-level entry below, matching #983's precedent for a
    large, uniform, unwrapped family, not 28 individual reasons.
  - **`StdSelect_` (11 headers, 2 wrapped): audited for its OCCT-CLASS coverage only.**
    `StdSelect_BRepSelectionTool`/`StdSelect_BRepOwner` are both named in
    `docs/reference/Selection.md`, #809's own Swift surface; this pass does not re-derive
    `Selection.swift`'s API (that is #809's territory, and #814's own text warns re-treading it
    would be the cross-lane double-count #928/#1044 already flagged once). The other 9 StdSelect_
    classes are curated below by OCCT-class reasoning alone.
  - **`SelectMgr_` is out of scope entirely**, per #814's own text (Phase 6's, #820, unless claimed
    first) and per #973's original partition. Not one `SelectMgr_` class appears in `LANE_CLASSES`
    below; `StdSelect_ViewerSelector3d`'s own curated reason (an unused `SelectMgr_ViewerSelector`
    alias) names `SelectMgr_ViewerSelector` in prose only, to explain why the alias itself is unused,
    never as a class this census claims to audit.

THE OVER-COVERAGE LEAD #814 FLAGS (`BRepMesh_BaseMeshAlgo`'s 8.0.1 periodic-seam change, #654):
checked, not a finding. `docs/occt-upgrades.md` already carries an accurate entry ("`BRepMesh_
BaseMeshAlgo` creates seam constraints only for the current wire occurrence's pcurve | meshing at
periodic seams", citing OCCT#1338) and a `grep` for any hardcoded node/triangle count elsewhere in
this lane's docs that could have gone stale from that change (`docs/reference/Shape.md`'s own
BRepMesh section, `docs/reference/Mesh.md`) found none. Not a finding; recorded as checked so a
future pass does not re-open it.

TWO QUESTIONS, per #814:

  UNDER-COVERAGE: an OCCT class in the lane we neither wrap (named on a line of
  `Sources/OCCTBridge/{src/*.mm,include/*.h}` that does not START with `#include`, `//`, `*` or
  `/*`) nor document (named anywhere under `docs/` except `docs/CHANGELOG.md` and
  `docs/occtswift-wrapping-gaps.md`), with no reason recorded in that gaps file.

  Measured before this PR: 368 lane classes, 45 wrapped/documented directly, 3 already recorded in
  `docs/occtswift-wrapping-gaps.md` for an unrelated, pre-existing reason (`AIS_ColoredShape`,
  `AIS_InteractiveObject`, `Graphic3d_Texture2D`, all three recorded via the #810 `XCAFPrs_AISObject`/
  `XCAFPrs_Texture`/`TPrsStd_` entries), 320 neither wrapped nor documented nor previously recorded.
  Base verdicts before this PR: 45 ok, 3 deliberate/recorded, 320 under.

  OVER-COVERAGE: something current docs assert that the pinned kernel does not support, or that the
  bridge does not actually do. `Scripts/census-doc-occt-attribution.py --lane
  BRepMesh_,Poly_,IMeshData_,IMeshTools_,AIS_,Graphic3d_,Image_,StdPrs_,StdSelect_` (#928) surfaced
  11 candidates: 5 confirmed TRUE (all one shape -- a doc line citing `Poly_Triangulation` for a
  method that is actually declared and called on a DIFFERENT class the bridge reaches through it,
  `RWMesh_FaceIterator` for `MeshFaceIterator`'s six accessors and `TDataXtd_Triangulation` for
  `Document`'s five `triangulation*` accessors) and 6 confirmed FALSE (the checker's `reachable()`
  walker requiring the cited class inside the NAMED function's own body, missing a value read through
  a sibling call or a class only named in a parameter-type parenthetical, the same shape #811's and
  #812's own rejected candidates were). A twelfth, found by hand rather than by the detector
  (`docs/API_REFERENCE.md`'s `PointCloud` row, attributed to `AIS_PointCloud`) is also confirmed
  TRUE: `OCCTPointCloudCreate` builds a bridge-internal `OCCTPointCloud` struct, never touching
  `AIS_PointCloud` anywhere in the tree (`grep -rn AIS_PointCloud Sources/OCCTBridge` -- before this
  PR's docs fix -- returned nothing). All 12 confirmed findings are FIXED in this PR (docs-only, see
  `KNOWN_OVER_FINDINGS` below); the 6 rejected candidates are recorded, not fixed, in
  `REJECTED_OVER_CANDIDATES`.

CLASSIFICATION RULES. Mechanical unless a class is in one of the curated tables, each entry
established during #814 by reading the pinned header directly and, where the contract was genuinely
in question (the real-gap candidates, the over-coverage candidates), the refman through the
`context` MCP at `occt-refman@8.0.1` or a direct construction-site read. Buckets are named per
family below; see each table's own docstring/comment for the specific mechanism, matching #983's
"a family-level reason needs the same measured specificity a per-class one does" standard rather
than "internal, trust me".

The wrapped test runs BEFORE the curated tables, following #808/#810/#811/#812/#982/#983: a table
entry claiming a class has no call sites must not be able to mask one that does.

ONE LIMITATION, inherited from every prior lane pass rather than rediscovered: `deliberate,
recorded` means the class NAME appears somewhere in `docs/occtswift-wrapping-gaps.md`, not that the
sentence around it is a reason. Every class this pass files as recorded is named in a bullet this
pass wrote (or, for the 3 pre-existing ones, a bullet #810/#982 wrote) carrying its measured reason,
so the name match and the reason coincide today; the test cannot tell the difference tomorrow.

Run from anywhere (paths derive from this file's location, not the cwd):

    python3 Scripts/repro/814-refman-coverage-mesh-presentation-misc/refman_census.py
    python3 Scripts/repro/814-refman-coverage-mesh-presentation-misc/refman_census.py --verbose
    python3 Scripts/repro/814-refman-coverage-mesh-presentation-misc/refman_census.py --reverify-lane
    python3 Scripts/repro/814-refman-coverage-mesh-presentation-misc/refman_census.py --self-test

Exits 1 on a `KNOWN_OVER_FINDINGS` regression, on a method attribution naming a member the pinned
headers do not declare, on an `under` with no `docs/occtswift-wrapping-gaps.md` line, on a
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

LANE_PACKAGES = ("BRepMesh", "Poly", "IMeshData", "IMeshTools", "AIS", "Graphic3d", "Image",
                 "StdPrs", "StdSelect")

LANE_HEADER_RE = re.compile(
    r"^(BRepMesh|Poly|IMeshData|IMeshTools|AIS|Graphic3d|Image|StdPrs|StdSelect)(_[^.]+)?\.hxx$")

# ------------------------------------------------------------------------------------------------
# The lane: 368 classes, enumerated from the pinned kernel's own headers (OCCT 8.0.1 plus the
# carried patches) on 2026-08-28. Re-derive with:
#
#   ls Libraries/OCCT.xcframework/macos-arm64/Headers \
#     | grep -E '^(BRepMesh|Poly|IMeshData|IMeshTools|AIS|Graphic3d|Image|StdPrs|StdSelect)(_[^.]+)?\.hxx$' \
#     | sed 's/\.hxx$//' | sort
#
# `--reverify-lane` runs exactly that derivation and diffs it against this list.
# ------------------------------------------------------------------------------------------------

LANE_CLASSES: dict[str, list[str]] = {
    "BRepMesh": [
        "BRepMesh_BaseMeshAlgo", "BRepMesh_BoundaryParamsRangeSplitter", "BRepMesh_Circle",
        "BRepMesh_CircleInspector", "BRepMesh_CircleTool", "BRepMesh_Classifier",
        "BRepMesh_ConeRangeSplitter", "BRepMesh_ConstrainedBaseMeshAlgo", "BRepMesh_Context",
        "BRepMesh_CurveTessellator", "BRepMesh_CustomBaseMeshAlgo",
        "BRepMesh_CustomDelaunayBaseMeshAlgo", "BRepMesh_CylinderRangeSplitter",
        "BRepMesh_DataStructureOfDelaun", "BRepMesh_DefaultRangeSplitter",
        "BRepMesh_Deflection", "BRepMesh_DegreeOfFreedom", "BRepMesh_DelabellaBaseMeshAlgo",
        "BRepMesh_DelabellaMeshAlgoFactory", "BRepMesh_Delaun",
        "BRepMesh_DelaunayBaseMeshAlgo", "BRepMesh_DelaunayDeflectionControlMeshAlgo",
        "BRepMesh_DelaunayNodeInsertionMeshAlgo", "BRepMesh_DiscretAlgoFactory",
        "BRepMesh_DiscretFactory", "BRepMesh_DiscretRoot", "BRepMesh_Edge",
        "BRepMesh_EdgeDiscret", "BRepMesh_EdgeParameterProvider",
        "BRepMesh_EdgeTessellationExtractor", "BRepMesh_ExtrusionRangeSplitter",
        "BRepMesh_FaceChecker", "BRepMesh_FaceDiscret", "BRepMesh_FastDiscret",
        "BRepMesh_GeomTool", "BRepMesh_IncrementalMesh", "BRepMesh_IncrementalMeshFactory",
        "BRepMesh_MeshAlgoFactory", "BRepMesh_MeshTool", "BRepMesh_ModelBuilder",
        "BRepMesh_ModelHealer", "BRepMesh_ModelPostProcessor", "BRepMesh_ModelPreProcessor",
        "BRepMesh_NURBSRangeSplitter", "BRepMesh_NodeInsertionMeshAlgo",
        "BRepMesh_OrientedEdge", "BRepMesh_PairOfIndex",
        "BRepMesh_SelectorOfDataStructureOfDelaun", "BRepMesh_ShapeTool",
        "BRepMesh_ShapeVisitor", "BRepMesh_SphereRangeSplitter", "BRepMesh_TorusRangeSplitter",
        "BRepMesh_Triangle", "BRepMesh_Triangulator", "BRepMesh_UVParamRangeSplitter",
        "BRepMesh_UndefinedRangeSplitter", "BRepMesh_Vertex", "BRepMesh_VertexInspector",
        "BRepMesh_VertexTool",
    ],
    "Poly": [
        "Poly", "Poly_Array1OfTriangle", "Poly_ArrayOfNodes", "Poly_ArrayOfUVNodes",
        "Poly_CoherentLink", "Poly_CoherentNode", "Poly_CoherentTriPtr",
        "Poly_CoherentTriangle", "Poly_CoherentTriangulation", "Poly_Connect",
        "Poly_HArray1OfTriangle", "Poly_ListOfTriangulation", "Poly_MakeLoops",
        "Poly_MergeNodesTool", "Poly_MeshPurpose", "Poly_Polygon2D", "Poly_Polygon3D",
        "Poly_PolygonOnTriangulation", "Poly_Triangle", "Poly_Triangulation",
        "Poly_TriangulationParameters",
    ],
    "IMeshData": [
        "IMeshData_Curve", "IMeshData_Edge", "IMeshData_Face", "IMeshData_Model",
        "IMeshData_PCurve", "IMeshData_ParametersList", "IMeshData_ParametersListArrayAdaptor",
        "IMeshData_Shape", "IMeshData_Status", "IMeshData_StatusOwner",
        "IMeshData_TessellatedShape", "IMeshData_Types", "IMeshData_Wire",
    ],
    "IMeshTools": [
        "IMeshTools_Context", "IMeshTools_CurveTessellator", "IMeshTools_MeshAlgo",
        "IMeshTools_MeshAlgoFactory", "IMeshTools_MeshAlgoType", "IMeshTools_MeshBuilder",
        "IMeshTools_ModelAlgo", "IMeshTools_ModelBuilder", "IMeshTools_Parameters",
        "IMeshTools_ShapeExplorer", "IMeshTools_ShapeVisitor",
    ],
    "AIS": [
        "AIS", "AIS_Animation", "AIS_AnimationAxisRotation", "AIS_AnimationCamera",
        "AIS_AnimationObject", "AIS_AnimationTimer", "AIS_AttributeFilter", "AIS_Axis",
        "AIS_BadEdgeFilter", "AIS_BaseAnimationObject", "AIS_C0RegularityFilter",
        "AIS_CameraFrustum", "AIS_Circle", "AIS_ColorScale", "AIS_ColoredDrawer",
        "AIS_ColoredShape", "AIS_ConnectedInteractive", "AIS_DataMapOfIOStatus",
        "AIS_DataMapOfShapeDrawer", "AIS_DisplayMode", "AIS_DisplayStatus", "AIS_DragAction",
        "AIS_ExclusionFilter", "AIS_GlobalStatus", "AIS_GraphicTool", "AIS_InteractiveContext",
        "AIS_InteractiveObject", "AIS_KindOfInteractive", "AIS_LightSource", "AIS_Line",
        "AIS_ListOfInteractive", "AIS_Manipulator", "AIS_ManipulatorMode",
        "AIS_ManipulatorOwner", "AIS_MediaPlayer", "AIS_MouseGesture",
        "AIS_MultipleConnectedInteractive", "AIS_NArray1OfEntityOwner",
        "AIS_NListOfEntityOwner", "AIS_NavigationMode", "AIS_Plane", "AIS_PlaneTrihedron",
        "AIS_Point", "AIS_PointCloud", "AIS_RotationMode", "AIS_RubberBand",
        "AIS_SelectStatus", "AIS_Selection", "AIS_SelectionModesConcurrency",
        "AIS_SelectionScheme", "AIS_Shape", "AIS_SignatureFilter", "AIS_StatusOfDetection",
        "AIS_StatusOfPick", "AIS_TextLabel", "AIS_TexturedShape", "AIS_Triangulation",
        "AIS_Trihedron", "AIS_TrihedronOwner", "AIS_TrihedronSelectionMode", "AIS_TypeFilter",
        "AIS_TypeOfAttribute", "AIS_TypeOfAxis", "AIS_TypeOfIso", "AIS_TypeOfPlane",
        "AIS_ViewController", "AIS_ViewCube", "AIS_ViewInputBuffer", "AIS_WalkDelta",
        "AIS_XRTrackedDevice",
    ],
    "Graphic3d": [
        "Graphic3d_AlphaMode", "Graphic3d_ArrayFlags", "Graphic3d_ArrayOfPoints",
        "Graphic3d_ArrayOfPolygons", "Graphic3d_ArrayOfPolylines",
        "Graphic3d_ArrayOfPrimitives", "Graphic3d_ArrayOfQuadrangleStrips",
        "Graphic3d_ArrayOfQuadrangles", "Graphic3d_ArrayOfSegments",
        "Graphic3d_ArrayOfTriangleFans", "Graphic3d_ArrayOfTriangleStrips",
        "Graphic3d_ArrayOfTriangles", "Graphic3d_AspectFillArea3d", "Graphic3d_AspectLine3d",
        "Graphic3d_AspectMarker3d", "Graphic3d_AspectText3d", "Graphic3d_Aspects",
        "Graphic3d_AttribBuffer", "Graphic3d_BSDF", "Graphic3d_BndBox3d", "Graphic3d_BndBox4d",
        "Graphic3d_BndBox4f", "Graphic3d_BoundBuffer", "Graphic3d_Buffer",
        "Graphic3d_BufferRange", "Graphic3d_BufferType", "Graphic3d_BvhCStructureSet",
        "Graphic3d_BvhCStructureSetTrsfPers", "Graphic3d_CLight", "Graphic3d_CStructure",
        "Graphic3d_CView", "Graphic3d_Camera", "Graphic3d_CameraTile",
        "Graphic3d_CappingFlags", "Graphic3d_ClipPlane", "Graphic3d_CubeMap",
        "Graphic3d_CubeMapOrder", "Graphic3d_CubeMapPacked", "Graphic3d_CubeMapSeparate",
        "Graphic3d_CubeMapSide", "Graphic3d_CullingTool", "Graphic3d_DataStructureManager",
        "Graphic3d_DiagnosticInfo", "Graphic3d_DisplayPriority", "Graphic3d_Flipper",
        "Graphic3d_FrameStats", "Graphic3d_FrameStatsCounter", "Graphic3d_FrameStatsData",
        "Graphic3d_FrameStatsTimer", "Graphic3d_GraduatedTrihedron", "Graphic3d_GraphicDriver",
        "Graphic3d_GraphicDriverFactory", "Graphic3d_Group", "Graphic3d_GroupAspect",
        "Graphic3d_GroupDefinitionError", "Graphic3d_HatchStyle",
        "Graphic3d_HorizontalTextAlignment", "Graphic3d_IndexBuffer", "Graphic3d_Layer",
        "Graphic3d_LevelOfTextureAnisotropy", "Graphic3d_LightSet",
        "Graphic3d_MapIteratorOfMapOfStructure", "Graphic3d_MapOfObject",
        "Graphic3d_MarkerImage", "Graphic3d_Mat4", "Graphic3d_Mat4d",
        "Graphic3d_MaterialAspect", "Graphic3d_MaterialDefinitionError",
        "Graphic3d_MediaTexture", "Graphic3d_MediaTextureSet", "Graphic3d_MutableIndexBuffer",
        "Graphic3d_NMapOfTransient", "Graphic3d_NameOfMaterial", "Graphic3d_NameOfTexture1D",
        "Graphic3d_NameOfTexture2D", "Graphic3d_NameOfTextureEnv",
        "Graphic3d_NameOfTexturePlane", "Graphic3d_PBRMaterial", "Graphic3d_PolygonOffset",
        "Graphic3d_PresentationAttributes", "Graphic3d_PriorityDefinitionError",
        "Graphic3d_RenderTransparentMethod", "Graphic3d_RenderingMode",
        "Graphic3d_RenderingParams", "Graphic3d_SequenceOfGroup",
        "Graphic3d_SequenceOfHClipPlane", "Graphic3d_SequenceOfStructure",
        "Graphic3d_ShaderAttribute", "Graphic3d_ShaderFlags", "Graphic3d_ShaderManager",
        "Graphic3d_ShaderObject", "Graphic3d_ShaderProgram", "Graphic3d_ShaderVariable",
        "Graphic3d_StereoMode", "Graphic3d_Structure", "Graphic3d_StructureDefinitionError",
        "Graphic3d_StructureManager", "Graphic3d_Text", "Graphic3d_TextPath",
        "Graphic3d_Texture1D", "Graphic3d_Texture1Dmanual", "Graphic3d_Texture1Dsegment",
        "Graphic3d_Texture2D", "Graphic3d_Texture2Dplane", "Graphic3d_Texture3D",
        "Graphic3d_TextureEnv", "Graphic3d_TextureMap", "Graphic3d_TextureParams",
        "Graphic3d_TextureRoot", "Graphic3d_TextureSet", "Graphic3d_TextureSetBits",
        "Graphic3d_TextureUnit", "Graphic3d_ToneMappingMethod", "Graphic3d_TransModeFlags",
        "Graphic3d_TransformPers", "Graphic3d_TransformPersScaledAbove",
        "Graphic3d_TransformUtils", "Graphic3d_TypeOfAnswer",
        "Graphic3d_TypeOfBackfacingModel", "Graphic3d_TypeOfBackground",
        "Graphic3d_TypeOfConnection", "Graphic3d_TypeOfLightSource", "Graphic3d_TypeOfLimit",
        "Graphic3d_TypeOfMaterial", "Graphic3d_TypeOfPrimitiveArray",
        "Graphic3d_TypeOfReflection", "Graphic3d_TypeOfShaderObject",
        "Graphic3d_TypeOfShadingModel", "Graphic3d_TypeOfStructure", "Graphic3d_TypeOfTexture",
        "Graphic3d_TypeOfTextureFilter", "Graphic3d_TypeOfTextureMode",
        "Graphic3d_TypeOfVisualization", "Graphic3d_Vec2", "Graphic3d_Vec3", "Graphic3d_Vec4",
        "Graphic3d_Vertex", "Graphic3d_VerticalTextAlignment", "Graphic3d_ViewAffinity",
        "Graphic3d_WorldViewProjState", "Graphic3d_ZLayerId", "Graphic3d_ZLayerSettings",
    ],
    "Image": [
        "Image_AlienPixMap", "Image_Color", "Image_CompressedFormat", "Image_CompressedPixMap",
        "Image_DDSParser", "Image_Diff", "Image_Format", "Image_PixMap", "Image_PixMapData",
        "Image_PixMapTypedData", "Image_SupportedFormats", "Image_Texture",
        "Image_VideoRecorder",
    ],
    "StdPrs": [
        "StdPrs_BRepFont", "StdPrs_BRepTextBuilder", "StdPrs_BndBox", "StdPrs_Curve",
        "StdPrs_DeflectionCurve", "StdPrs_HLRPolyShape", "StdPrs_HLRShape", "StdPrs_HLRShapeI",
        "StdPrs_HLRToolShape", "StdPrs_Isolines", "StdPrs_Plane", "StdPrs_Point",
        "StdPrs_PoleCurve", "StdPrs_ShadedShape", "StdPrs_ShadedSurface", "StdPrs_ShapeTool",
        "StdPrs_ToolPoint", "StdPrs_ToolRFace", "StdPrs_ToolTriangulatedShape",
        "StdPrs_ToolVertex", "StdPrs_Vertex", "StdPrs_Volume",
        "StdPrs_WFDeflectionRestrictedFace", "StdPrs_WFDeflectionSurface",
        "StdPrs_WFPoleSurface", "StdPrs_WFRestrictedFace", "StdPrs_WFShape",
        "StdPrs_WFSurface",
    ],
    "StdSelect": [
        "StdSelect", "StdSelect_BRepOwner", "StdSelect_BRepSelectionTool",
        "StdSelect_EdgeFilter", "StdSelect_FaceFilter", "StdSelect_Shape",
        "StdSelect_ShapeTypeFilter", "StdSelect_TypeOfEdge", "StdSelect_TypeOfFace",
        "StdSelect_TypeOfSelectionImage", "StdSelect_ViewerSelector3d",
    ],
}

FAMILY_COUNTS = {"BRepMesh": 59, "Poly": 21, "IMeshData": 13, "IMeshTools": 11, "AIS": 70,
                 "Graphic3d": 142, "Image": 13, "StdPrs": 28, "StdSelect": 11}
LANE_TOTAL = 368

# ------------------------------------------------------------------------------------------------
# Curated classification tables, one dict per family bucket, each keyed by class name with a
# (label, reason) pair built up below. Every reason was read off the pinned header during #814;
# see the module docstring for the two boundary questions (StdPrs_/StdSelect_) and the real-gap
# candidate (Poly_TriangulationParameters).
# ------------------------------------------------------------------------------------------------

CURATED: dict[str, tuple[str, str]] = {}


def _add(table: dict[str, str], label: str) -> None:
    for cls, why in table.items():
        CURATED[cls] = (label, why)


# --- BRepMesh (52 curated; 7 already ok: BaseMeshAlgo/Delaun/DelaunayDeflectionControlMeshAlgo/
#     FaceDiscret documented, IncrementalMesh/ShapeTool/Deflection wrapped) -----------------------

_RANGE_SPLITTER_REASON = ("a per-surface-type UV-range-parameterization helper "
    "BRepMesh_FaceDiscret (wrapped via BRepMesh_IncrementalMesh, documented) selects internally by "
    "the face's own surface type (plane/cone/cylinder/sphere/torus/NURBS/extrusion); a caller tunes "
    "the *outcome* through IMeshTools_Parameters (wrapped: deflection, angle, minSize), never picks "
    "the range-splitter class directly")
_add({
    "BRepMesh_BoundaryParamsRangeSplitter": _RANGE_SPLITTER_REASON,
    "BRepMesh_ConeRangeSplitter": _RANGE_SPLITTER_REASON,
    "BRepMesh_CylinderRangeSplitter": _RANGE_SPLITTER_REASON,
    "BRepMesh_DefaultRangeSplitter": _RANGE_SPLITTER_REASON,
    "BRepMesh_ExtrusionRangeSplitter": _RANGE_SPLITTER_REASON,
    "BRepMesh_NURBSRangeSplitter": _RANGE_SPLITTER_REASON,
    "BRepMesh_SphereRangeSplitter": _RANGE_SPLITTER_REASON,
    "BRepMesh_TorusRangeSplitter": _RANGE_SPLITTER_REASON,
    "BRepMesh_UVParamRangeSplitter": _RANGE_SPLITTER_REASON,
    "BRepMesh_UndefinedRangeSplitter": _RANGE_SPLITTER_REASON,
}, "RANGE_SPLITTERS")

_MESH_ALGO_INFRA_REASON = ("algorithm-selection/factory machinery BRepMesh_IncrementalMesh "
    "(wrapped) drives internally to pick a meshing algorithm by surface type and complexity; "
    "IMeshTools_Parameters (wrapped) is the only tuning surface exposed, selecting a factory or "
    "algorithm class by name is not")
_add({
    "BRepMesh_ConstrainedBaseMeshAlgo": _MESH_ALGO_INFRA_REASON,
    "BRepMesh_CustomBaseMeshAlgo": _MESH_ALGO_INFRA_REASON,
    "BRepMesh_CustomDelaunayBaseMeshAlgo": _MESH_ALGO_INFRA_REASON,
    "BRepMesh_DelabellaBaseMeshAlgo": _MESH_ALGO_INFRA_REASON,
    "BRepMesh_DelabellaMeshAlgoFactory": _MESH_ALGO_INFRA_REASON,
    "BRepMesh_DelaunayBaseMeshAlgo": _MESH_ALGO_INFRA_REASON,
    "BRepMesh_DelaunayNodeInsertionMeshAlgo": _MESH_ALGO_INFRA_REASON,
    "BRepMesh_DiscretAlgoFactory": _MESH_ALGO_INFRA_REASON,
    "BRepMesh_DiscretFactory": _MESH_ALGO_INFRA_REASON,
    "BRepMesh_DiscretRoot": _MESH_ALGO_INFRA_REASON,
    "BRepMesh_IncrementalMeshFactory": _MESH_ALGO_INFRA_REASON,
    "BRepMesh_MeshAlgoFactory": _MESH_ALGO_INFRA_REASON,
    "BRepMesh_NodeInsertionMeshAlgo": _MESH_ALGO_INFRA_REASON,
}, "MESH_ALGO_INFRASTRUCTURE")

_DELAUNAY_DATA_REASON = ("a light-weight internal data structure of the Delaunay triangulation "
    "engine BRepMesh_Delaun (documented) drives; a caller reaches meshing results through "
    "Poly_Triangulation (wrapped), never through the engine's own working structures")
_add({
    "BRepMesh_Circle": _DELAUNAY_DATA_REASON,
    "BRepMesh_CircleInspector": _DELAUNAY_DATA_REASON,
    "BRepMesh_CircleTool": _DELAUNAY_DATA_REASON,
    "BRepMesh_DataStructureOfDelaun": _DELAUNAY_DATA_REASON,
    "BRepMesh_DegreeOfFreedom": _DELAUNAY_DATA_REASON,
    "BRepMesh_Edge": _DELAUNAY_DATA_REASON,
    "BRepMesh_OrientedEdge": _DELAUNAY_DATA_REASON,
    "BRepMesh_PairOfIndex": _DELAUNAY_DATA_REASON,
    "BRepMesh_SelectorOfDataStructureOfDelaun": _DELAUNAY_DATA_REASON,
    "BRepMesh_Triangle": _DELAUNAY_DATA_REASON,
    "BRepMesh_Vertex": _DELAUNAY_DATA_REASON,
    "BRepMesh_VertexInspector": _DELAUNAY_DATA_REASON,
    "BRepMesh_VertexTool": _DELAUNAY_DATA_REASON,
}, "DELAUNAY_DATA_STRUCTURES")

_TESSELLATION_PIPELINE_REASON = ("an internal pipeline stage BRepMesh_IncrementalMesh (wrapped) "
    "drives on a caller's behalf (classification, curve tessellation, edge/face discretization, "
    "model build/heal/pre-/post-process passes); none is independently constructed by this bridge, "
    "and none exposes a capability IMeshTools_Parameters doesn't already control")
_add({
    "BRepMesh_Classifier": _TESSELLATION_PIPELINE_REASON,
    "BRepMesh_Context": _TESSELLATION_PIPELINE_REASON,
    "BRepMesh_CurveTessellator": _TESSELLATION_PIPELINE_REASON,
    "BRepMesh_EdgeDiscret": _TESSELLATION_PIPELINE_REASON,
    "BRepMesh_EdgeParameterProvider": _TESSELLATION_PIPELINE_REASON,
    "BRepMesh_EdgeTessellationExtractor": _TESSELLATION_PIPELINE_REASON,
    "BRepMesh_FaceChecker": _TESSELLATION_PIPELINE_REASON,
    "BRepMesh_GeomTool": _TESSELLATION_PIPELINE_REASON,
    "BRepMesh_MeshTool": _TESSELLATION_PIPELINE_REASON,
    "BRepMesh_ModelBuilder": _TESSELLATION_PIPELINE_REASON,
    "BRepMesh_ModelHealer": _TESSELLATION_PIPELINE_REASON,
    "BRepMesh_ModelPostProcessor": _TESSELLATION_PIPELINE_REASON,
    "BRepMesh_ModelPreProcessor": _TESSELLATION_PIPELINE_REASON,
    "BRepMesh_ShapeVisitor": _TESSELLATION_PIPELINE_REASON,
    "BRepMesh_Triangulator": _TESSELLATION_PIPELINE_REASON,
}, "TESSELLATION_PIPELINE_INTERNALS")

_add({
    "BRepMesh_FastDiscret": ("file-scope Standard_HEADER_DEPRECATED compatibility header; the "
        "class it once declared is gone, superseded by BRepMesh_IncrementalMesh (wrapped)"),
}, "DEPRECATED_COMPAT_HEADER")

# --- Poly (10 curated; 11 already ok) -------------------------------------------------------------

_add({
    "Poly_HArray1OfTriangle": ("file-scope Standard_HEADER_DEPRECATED collection alias, deprecated "
        "since OCCT 8.0.0, use NCollection_Array1<Poly_Triangle> directly"),
    "Poly_ListOfTriangulation": ("file-scope Standard_HEADER_DEPRECATED collection alias, "
        "deprecated since OCCT 8.0.0, use NCollection_List<occ::handle<Poly_Triangulation>> "
        "directly"),
}, "DEPRECATED_COLLECTION_ALIASES")

_COHERENT_REASON = ("an internal link/node/pointer primitive of Poly_CoherentTriangulation "
    "(wrapped), the mesh-editing utility class Sources/OCCTSwift's MeshTypes.swift constructs via "
    "OCCTCoherentTriangulationCreate*; not separately constructed")
_add({
    "Poly_CoherentLink": _COHERENT_REASON,
    "Poly_CoherentNode": _COHERENT_REASON,
    "Poly_CoherentTriPtr": _COHERENT_REASON,
}, "COHERENT_MESH_INTERNALS")

_add({
    "Poly_ArrayOfNodes": ("Poly_Triangulation's (wrapped) own internal node-storage array "
        "(NCollection_AliasedArray-based, single/double precision configurable at construction); "
        "a caller reads nodes through Poly_Triangulation::Node/OCCTPolyTriangulationNode, never "
        "constructs this array directly"),
    "Poly_ArrayOfUVNodes": ("the 2D sibling of Poly_ArrayOfNodes, Poly_Triangulation's own "
        "internal UV-node storage array; same reason"),
}, "NODE_STORAGE_INTERNALS")

_add({
    "Poly_MakeLoops": ("a topology-reconstruction utility that assembles closed loops from a set "
        "of disconnected link indices (e.g. for cross-section/cutting-plane polygon assembly); no "
        "call site in this bridge builds one, and no Swift API exposes raw link-index loop assembly"),
    "Poly_MeshPurpose": ("a bit-flag typedef (`typedef unsigned int`) tagging a stored "
        "triangulation's purpose (calculation/presentation/LOD/active/loaded); "
        "Poly_Triangulation's own multi-purpose-triangulation storage (added the same OCCT release) "
        "is not exposed, this bridge reads a shape's single active triangulation only"),
}, "TOPOLOGY_AND_TAGGING_UTILITIES")

# ------------------------------------------------------------------------------------------------
# The one real capability gap in this lane recorded as such rather than curated away, per #983's
# own precedent (StdDrivers_/StdLDrivers_ there) that a lane audit sometimes finds a genuine,
# narrow, unwrapped capability and the honest thing is to say so rather than force it into an
# "internal machinery" bucket it does not fit.
# ------------------------------------------------------------------------------------------------

REAL_GAP: dict[str, str] = {
    "Poly_TriangulationParameters": (
        "REAL GAP, not curated away: records the deflection/angle/minSize a triangulation was "
        "built with (constructor `Poly_TriangulationParameters(deflection, angle, minSize)`, "
        "confirmed at the pinned header), so a caller could ask an already-meshed shape \"what "
        "tolerance produced this mesh\" instead of tracking it separately. Poly_Triangulation "
        "itself has a matching Parameters()/SetParameters() pair (added the same OCCT release as "
        "Poly_MeshPurpose above) that this bridge never reads or writes; every meshing entry point "
        "(OCCTShapeCreateMesh, OCCTShapeCreateMeshWithParams, OCCTMeshFaceIterCreate's RWMesh path) "
        "takes deflection/angle as bare doubles and returns nodes/triangles with no way to recover "
        "them from the result later. Narrow (nothing consumes it once meshing is done) but real."
    ),
}
_add(REAL_GAP, "REAL_GAP")

# --- IMeshData + IMeshTools (23 curated; 1 already ok: IMeshTools_Parameters) ---------------------

_IMESHDATA_REASON = ("the abstract discrete-model data interface IMeshData_'s package defines "
    "(curve/edge/face/wire/model, each mostly pure-virtual per the pinned header); "
    "BRepMesh_'s own concrete classes (wrapped via BRepMesh_IncrementalMesh) implement these "
    "interfaces internally while building a mesh, and once built, a caller reads the RESULT through "
    "Poly_Triangulation (wrapped), never through this intermediate interface layer")
_add({c: _IMESHDATA_REASON for c in LANE_CLASSES["IMeshData"]}, "IMESHDATA_INTERFACE_LAYER")

_IMESHTOOLS_REASON = ("the abstract algorithm/factory/context interface IMeshTools_'s package "
    "defines, one level above IMeshData_'s data interfaces; BRepMesh_Context/BRepMesh_ModelBuilder/"
    "BRepMesh_'s own mesh-algo classes (all curated above) implement these interfaces, and a caller "
    "configures the whole pipeline through IMeshTools_Parameters (wrapped) alone, never through "
    "this interface layer directly")
_add({c: _IMESHTOOLS_REASON for c in LANE_CLASSES["IMeshTools"] if c != "IMeshTools_Parameters"},
    "IMESHTOOLS_INTERFACE_LAYER")

# --- AIS (59 curated; 9 already ok, 2 already recorded elsewhere: ColoredShape/InteractiveObject) -

_ANIMATION_REASON = ("OCCT's own AIS_InteractiveContext-driven fly-through/object animation "
    "framework, operating on a live Graphic3d_Camera through an AIS_InteractiveContext this bridge "
    "never builds (see OPENGL_VIEWER_PIPELINE below for why); this bridge's Metal renderer drives "
    "any animation from the Swift/host side directly")
_add({c: _ANIMATION_REASON for c in [
    "AIS_Animation", "AIS_AnimationAxisRotation", "AIS_AnimationCamera", "AIS_AnimationObject",
    "AIS_AnimationTimer", "AIS_BaseAnimationObject",
]}, "AIS_ANIMATION")

_AIS_FILTER_REASON = ("a SelectMgr_Filter subclass for OCCT's own AIS_InteractiveContext-level "
    "live-viewer selection filtering (SelectMgr_ itself is out of this lane's scope per #814's own "
    "text, Phase 6's/#820); this bridge does shape/edge/vertex-type discrimination directly through "
    "StdSelect_BRepSelectionTool/StdSelect_BRepOwner (both wrapped) into Selection.swift's own "
    "model (#809), not through an AIS-level filter object")
_add({c: _AIS_FILTER_REASON for c in [
    "AIS_AttributeFilter", "AIS_BadEdgeFilter", "AIS_C0RegularityFilter", "AIS_ExclusionFilter",
    "AIS_SignatureFilter", "AIS_TypeFilter",
]}, "AIS_SELECTION_FILTERS")

_AIS_OWNER_REASON = ("a SelectMgr_EntityOwner subclass tying one AIS_InteractiveObject subclass "
    "(AIS_Manipulator/AIS_Trihedron, both curated below, neither constructed) to the same unused "
    "AIS_InteractiveContext selection pipeline as the filters above")
_add({c: _AIS_OWNER_REASON for c in ["AIS_ManipulatorOwner", "AIS_TrihedronOwner"]},
    "AIS_ENTITY_OWNERS")

_AIS_IO_REASON = ("a concrete AIS_InteractiveObject subclass for OCCT's own live 3D viewer, "
    "requiring an AIS_InteractiveContext plus a Graphic3d_GraphicDriver-backed view this bridge "
    "never builds; the sole AIS_InteractiveObject subclass this bridge DOES construct is "
    "AIS_TextLabel (wrapped, via Annotation.swift), used only as a lightweight geometry/attribute "
    "carrier read into Metal, never displayed through a live AIS_InteractiveContext")
_add({c: _AIS_IO_REASON for c in [
    "AIS_CameraFrustum", "AIS_Circle", "AIS_ColorScale", "AIS_ColoredDrawer",
    "AIS_ConnectedInteractive", "AIS_LightSource", "AIS_Line", "AIS_MediaPlayer",
    "AIS_MultipleConnectedInteractive", "AIS_PlaneTrihedron", "AIS_Point", "AIS_RubberBand",
    "AIS_TexturedShape", "AIS_Triangulation", "AIS_ViewCube", "AIS_XRTrackedDevice",
]}, "AIS_INTERACTIVE_OBJECT_SUBCLASSES")

_add({
    "AIS_DataMapOfIOStatus": ("file-scope Standard_HEADER_DEPRECATED collection alias, deprecated "
        "since OCCT 8.0.0, use NCollection_DataMap directly"),
    "AIS_DataMapOfShapeDrawer": ("file-scope Standard_HEADER_DEPRECATED collection alias, "
        "deprecated since OCCT 8.0.0"),
    "AIS_ListOfInteractive": ("file-scope Standard_HEADER_DEPRECATED collection alias, deprecated "
        "since OCCT 8.0.0, use NCollection_List directly"),
    "AIS_NArray1OfEntityOwner": ("file-scope Standard_HEADER_DEPRECATED collection alias, "
        "deprecated since OCCT 8.0.0"),
    "AIS_NListOfEntityOwner": ("file-scope Standard_HEADER_DEPRECATED collection alias, deprecated "
        "since OCCT 8.0.0"),
}, "AIS_DEPRECATED_COLLECTION_ALIASES")

_AIS_ENUM_REASON = ("a mode/status enum for the unused AIS_InteractiveContext-level "
    "interaction/selection/animation/manipulator pipeline above; nothing in this tree reads it by "
    "value or by name")
_add({c: _AIS_ENUM_REASON for c in [
    "AIS_DisplayMode", "AIS_DisplayStatus", "AIS_DragAction", "AIS_KindOfInteractive",
    "AIS_ManipulatorMode", "AIS_MouseGesture", "AIS_NavigationMode", "AIS_RotationMode",
    "AIS_SelectStatus", "AIS_SelectionModesConcurrency", "AIS_SelectionScheme",
    "AIS_StatusOfDetection", "AIS_StatusOfPick", "AIS_TrihedronSelectionMode",
    "AIS_TypeOfAttribute", "AIS_TypeOfAxis", "AIS_TypeOfIso", "AIS_TypeOfPlane",
]}, "AIS_ENUMS_UNWRAPPED")

_add({
    "AIS_GlobalStatus": ("per-object bookkeeping (display mode, active selection modes, "
        "highlight/hide state) an AIS_InteractiveContext keeps for each AIS_InteractiveObject it "
        "manages; no context, no bookkeeping to read"),
    "AIS_GraphicTool": ("a static-helper class extracting Graphic3d_ aspect values from an "
        "already-built AIS_InteractiveObject/Graphic3d_Group; nothing to extract without either"),
    "AIS_Selection": ("the list of selected owners AIS_InteractiveContext-level selection keeps; "
        "this bridge's Selection.swift (#809) implements its own selection state directly over "
        "StdSelect_'s picking primitives, not through this class"),
    "AIS_ViewController": ("auxiliary GUI/rendering-thread event-handling structure for OCCT's own "
        "windowing integration (Aspect_WindowInputListener); this project's host apps drive input "
        "through their own platform event loop into the Swift API directly"),
    "AIS_ViewInputBuffer": ("the event-queue structure AIS_ViewController (above) buffers into; "
        "same reason"),
    "AIS_WalkDelta": ("per-frame walking/movement delta values AIS_ViewController computes for "
        "first-person navigation; same unused pipeline"),
}, "AIS_LIVE_VIEWER_INFRASTRUCTURE")

# --- Graphic3d (129 curated; 12 already ok directly, 1 already recorded elsewhere: Texture2D) -----

_add({
    "Graphic3d_MapIteratorOfMapOfStructure": ("file-scope Standard_HEADER_DEPRECATED collection "
        "alias, deprecated since OCCT 8.0.0"),
    "Graphic3d_MapOfObject": ("file-scope Standard_HEADER_DEPRECATED collection alias, deprecated "
        "since OCCT 8.0.0"),
    "Graphic3d_Mat4d": ("file-scope Standard_HEADER_DEPRECATED alias (`using ... = NCollection_"
        "Mat4<double>`); the wrapped Graphic3d_Mat4 (float) is the one this bridge reads, itself "
        "also deprecated at this pin but still the one OCCTBridge_Visualization.mm constructs"),
    "Graphic3d_NMapOfTransient": ("file-scope Standard_HEADER_DEPRECATED collection alias, "
        "deprecated since OCCT 8.0.0"),
    "Graphic3d_SequenceOfGroup": ("file-scope Standard_HEADER_DEPRECATED collection alias, "
        "deprecated since OCCT 8.0.0"),
    "Graphic3d_SequenceOfStructure": ("file-scope Standard_HEADER_DEPRECATED collection alias, "
        "deprecated since OCCT 8.0.0"),
    "Graphic3d_Vec2": ("file-scope Standard_HEADER_DEPRECATED alias (`using ... = NCollection_"
        "Vec2<double>`); nothing in this bridge constructs one (2D vectors go through gp_Pnt2d/"
        "gp_Vec2d or bare doubles)"),
    "Graphic3d_Vec4": ("file-scope Standard_HEADER_DEPRECATED alias; nothing in this bridge "
        "constructs one"),
}, "GRAPHIC3D_DEPRECATED_COLLECTION_ALIASES")

_GRAPHIC3D_EXC_REASON = ("a DEFINE_STANDARD_EXCEPTION-generated exception type raised internally "
    "by the OpenGl-driver scene-graph classes in OPENGL_VIEWER_PIPELINE below; this bridge's own "
    "try/catch boundary converts every OCCT exception to a Swift-level failure without inspecting "
    "its concrete type, and the classes that would throw this one are themselves never constructed")
_add({c: _GRAPHIC3D_EXC_REASON for c in [
    "Graphic3d_GroupDefinitionError", "Graphic3d_MaterialDefinitionError",
    "Graphic3d_PriorityDefinitionError", "Graphic3d_StructureDefinitionError",
]}, "GRAPHIC3D_EXCEPTION_TYPEDEFS")

_add({
    "Graphic3d_ArrayFlags": ("a bit-flag alias (`using ... = unsigned int`) for "
        "Graphic3d_ArrayOfPrimitives' (curated below, unused) own vertex-attribute flags"),
    "Graphic3d_BndBox4d": ("a homogeneous (4-component) bounding-box alias sibling of the wrapped "
        "Graphic3d_BndBox3d; this bridge reads only the 3-component form"),
    "Graphic3d_BndBox4f": ("single-precision sibling of Graphic3d_BndBox4d; same reason"),
    "Graphic3d_TransformUtils": ("a bare, all-static matrix/transform-utility header (no instance "
        "type of its own name) serving the OpenGl-driver pipeline's own matrix math; this bridge "
        "does its own transform math over gp_Trsf/SIMD types"),
}, "GRAPHIC3D_VALUE_TYPE_ALIASES")

_GRAPHIC3D_OPENGL_REASON = ("part of OCCT's own OpenGl-based Graphic3d_GraphicDriver live-viewer "
    "pipeline (scene graph: structures/groups/layers/culling; GPU buffers; fixed-function vertex "
    "primitive arrays and aspects; the texture and shader subsystems; camera tiling and lighting; "
    "frame statistics; rendering-mode/material/texture-format enums; text layout). This bridge "
    "implements a custom Metal renderer instead, the same fact #812's README established for "
    "Prs3d_ (0 classes reached) and #982's for TPrsStd_: DisplayDrawer.swift wraps only "
    "Prs3d_Drawer's tessellation-QUALITY settings, never a Prs3d_Presentation these classes would "
    "draw into; PresentationMesh.swift builds Metal vertex buffers directly from Poly_Triangulation "
    "mesh data (BRepMesh_, wrapped) rather than through any Graphic3d_ArrayOfPrimitives/Group/"
    "Structure; and Graphic3d_GraphicDriver itself is only ever discussed in "
    "docs/visualization-research.md as a future direction (\"No standard OCCT widgets ... none of "
    "these exist as ready-made objects\"), never instantiated -- confirmed: zero call sites for "
    "GraphicDriver, CView, Structure, Group, or any class in this bucket across "
    "Sources/OCCTBridge/. The 13 value types this bridge DOES read directly (BndBox3d, Camera, "
    "ClipPlane, Mat4, MaterialAspect, NameOfMaterial, PBRMaterial, PolygonOffset, Vec3, "
    "ZLayerSettings, plus GraphicDriver/ZLayerId documented as research) are read as plain data "
    "into DisplayDrawer's own Metal-facing structures, never through this pipeline's own "
    "structure/group/buffer machinery")
_GRAPHIC3D_OPENGL_CLASSES = [
    "Graphic3d_ArrayOfPoints", "Graphic3d_ArrayOfPolygons", "Graphic3d_ArrayOfPolylines",
    "Graphic3d_ArrayOfPrimitives", "Graphic3d_ArrayOfQuadrangleStrips",
    "Graphic3d_ArrayOfQuadrangles", "Graphic3d_ArrayOfSegments", "Graphic3d_ArrayOfTriangleFans",
    "Graphic3d_ArrayOfTriangleStrips", "Graphic3d_ArrayOfTriangles", "Graphic3d_AspectFillArea3d",
    "Graphic3d_AspectLine3d", "Graphic3d_AspectMarker3d", "Graphic3d_AspectText3d",
    "Graphic3d_Aspects", "Graphic3d_AttribBuffer", "Graphic3d_BSDF", "Graphic3d_BoundBuffer",
    "Graphic3d_Buffer", "Graphic3d_BufferRange", "Graphic3d_BvhCStructureSet",
    "Graphic3d_BvhCStructureSetTrsfPers", "Graphic3d_CLight", "Graphic3d_CStructure",
    "Graphic3d_CView", "Graphic3d_CameraTile", "Graphic3d_CubeMap", "Graphic3d_CubeMapOrder",
    "Graphic3d_CubeMapPacked", "Graphic3d_CubeMapSeparate", "Graphic3d_CullingTool",
    "Graphic3d_DataStructureManager", "Graphic3d_Flipper", "Graphic3d_FrameStats",
    "Graphic3d_FrameStatsData", "Graphic3d_GraduatedTrihedron", "Graphic3d_GraphicDriverFactory",
    "Graphic3d_Group", "Graphic3d_HatchStyle", "Graphic3d_IndexBuffer", "Graphic3d_Layer",
    "Graphic3d_LightSet", "Graphic3d_MarkerImage", "Graphic3d_MediaTexture",
    "Graphic3d_MediaTextureSet", "Graphic3d_MutableIndexBuffer", "Graphic3d_PresentationAttributes",
    "Graphic3d_RenderingParams", "Graphic3d_SequenceOfHClipPlane", "Graphic3d_ShaderAttribute",
    "Graphic3d_ShaderManager", "Graphic3d_ShaderObject", "Graphic3d_ShaderProgram",
    "Graphic3d_ShaderVariable", "Graphic3d_Structure", "Graphic3d_StructureManager",
    "Graphic3d_Text", "Graphic3d_Texture1D", "Graphic3d_Texture1Dmanual",
    "Graphic3d_Texture1Dsegment", "Graphic3d_Texture2Dplane", "Graphic3d_Texture3D",
    "Graphic3d_TextureEnv", "Graphic3d_TextureMap", "Graphic3d_TextureParams",
    "Graphic3d_TextureRoot", "Graphic3d_TextureSet", "Graphic3d_TransformPers",
    "Graphic3d_TransformPersScaledAbove", "Graphic3d_Vertex", "Graphic3d_ViewAffinity",
    "Graphic3d_WorldViewProjState",
]
_add({c: _GRAPHIC3D_OPENGL_REASON for c in _GRAPHIC3D_OPENGL_CLASSES}, "GRAPHIC3D_OPENGL_VIEWER_PIPELINE")

_GRAPHIC3D_ENUM_REASON = ("a mode/format/type enum for the same unused OpenGl-driver pipeline "
    "(see GRAPHIC3D_OPENGL_VIEWER_PIPELINE); nothing in this tree reads it by value or by name")
_GRAPHIC3D_ENUM_CLASSES = [
    "Graphic3d_AlphaMode", "Graphic3d_BufferType", "Graphic3d_CappingFlags",
    "Graphic3d_CubeMapSide", "Graphic3d_DiagnosticInfo", "Graphic3d_DisplayPriority",
    "Graphic3d_FrameStatsCounter", "Graphic3d_FrameStatsTimer", "Graphic3d_GroupAspect",
    "Graphic3d_HorizontalTextAlignment", "Graphic3d_LevelOfTextureAnisotropy",
    "Graphic3d_NameOfTexture1D", "Graphic3d_NameOfTexture2D", "Graphic3d_NameOfTextureEnv",
    "Graphic3d_NameOfTexturePlane", "Graphic3d_RenderTransparentMethod", "Graphic3d_RenderingMode",
    "Graphic3d_ShaderFlags", "Graphic3d_StereoMode", "Graphic3d_TextPath",
    "Graphic3d_TextureSetBits", "Graphic3d_TextureUnit", "Graphic3d_ToneMappingMethod",
    "Graphic3d_TransModeFlags", "Graphic3d_TypeOfAnswer", "Graphic3d_TypeOfBackfacingModel",
    "Graphic3d_TypeOfBackground", "Graphic3d_TypeOfConnection", "Graphic3d_TypeOfLightSource",
    "Graphic3d_TypeOfLimit", "Graphic3d_TypeOfMaterial", "Graphic3d_TypeOfPrimitiveArray",
    "Graphic3d_TypeOfReflection", "Graphic3d_TypeOfShaderObject", "Graphic3d_TypeOfShadingModel",
    "Graphic3d_TypeOfStructure", "Graphic3d_TypeOfTexture", "Graphic3d_TypeOfTextureFilter",
    "Graphic3d_TypeOfTextureMode", "Graphic3d_TypeOfVisualization", "Graphic3d_VerticalTextAlignment",
]
_add({c: _GRAPHIC3D_ENUM_REASON for c in _GRAPHIC3D_ENUM_CLASSES}, "GRAPHIC3D_ENUMS_UNWRAPPED")

# --- Image (10 curated; 3 already ok: AlienPixMap, Format, PixMap) --------------------------------

_add({
    "Image_PixMapData": ("Image_PixMap's (wrapped) own internal pixel-buffer base class "
        "(NCollection_Buffer-derived storage); a caller reads/writes pixels through "
        "OCCTImageGetPixel/SetPixel, never this storage layer directly"),
    "Image_PixMapTypedData": ("the typed sibling of Image_PixMapData; same reason"),
}, "IMAGE_PIXMAP_STORAGE_INTERNALS")

_IMAGE_COMPRESSED_REASON = ("the compressed-texture (DXT/BC/DDS) pipeline for the unused "
    "Graphic3d_ OpenGl texture pipeline (see GRAPHIC3D_OPENGL_VIEWER_PIPELINE); this bridge's "
    "PixMap wraps only the raw, uncompressed Image_AlienPixMap/Image_PixMap path (file load/save "
    "via OCCTImageLoad/OCCTImageSave, get/set pixel via Quantity_ColorRGBA)")
_add({
    "Image_CompressedFormat": _IMAGE_COMPRESSED_REASON,
    "Image_CompressedPixMap": _IMAGE_COMPRESSED_REASON,
    "Image_DDSParser": _IMAGE_COMPRESSED_REASON,
}, "IMAGE_COMPRESSED_TEXTURE_PIPELINE")

_add({
    "Image_SupportedFormats": ("a texture-format-capability query structure for the unused "
        "Graphic3d_ texture pipeline (see GRAPHIC3D_OPENGL_VIEWER_PIPELINE)"),
    "Image_Texture": ("a texture-image descriptor (path + byte offset) for the same unused "
        "Graphic3d_ texture pipeline"),
}, "IMAGE_LIVE_VIEWER_TEXTURE_SUPPORT")

_add({
    "Image_VideoRecorder": ("an FFmpeg-based tool for capturing a LIVE OCCT 3D view "
        "(Graphic3d_CView) to video; no live OCCT view exists in this bridge's Metal-renderer "
        "architecture to capture"),
    "Image_Diff": ("OCCT's own pixel-by-pixel image-comparison tool, used internally by OCCT's "
        "Draw test harness for image regression testing; no image-diff capability is exposed by "
        "this bridge"),
    "Image_Color": ("an alternative pixel-color value type Image_PixMap could use; this bridge's "
        "OCCTImageGetPixel/SetPixel go through Quantity_ColorRGBA instead (PixelColor/"
        "SetPixelColor's actual parameter type, confirmed at the call site), never Image_Color"),
}, "IMAGE_MISC")

# --- StdPrs (ALL 28 curated, ONE family bucket per #814's own instruction) ------------------------

_STDPRS_REASON = (
    "OCCT's own default presentation-builder toolkit, the reference implementation "
    "Prs3d_Presentation/AIS_InteractiveObject::Compute() calls to build wireframe, shaded, "
    "isoline, and boundary-box presentations of shapes/curves/surfaces/planes/points for the live "
    "OCCT viewer (StdPrs_ShadedShape, StdPrs_WFShape, StdPrs_Curve, StdPrs_Isolines, StdPrs_Plane, "
    "StdPrs_HLRShape/HLRPolyShape and the rest of the Prs3d_Root-derived siblings all take a "
    "Handle(Prs3d_Presentation) and add graphic groups to it). Confirmed, not assumed from the "
    "issue text: `grep -rn StdPrs Sources/OCCTBridge/ docs/` (excluding this pass's own new gaps.md "
    "section) returned nothing at all before this PR, so all 28 are the largest single block of "
    "unrecorded omission in the lane, exactly as #814's own body says. This bridge builds a custom "
    "Metal renderer instead, the same fact established for Graphic3d_'s OPENGL_VIEWER_PIPELINE and "
    "#812's Prs3d_ finding (0 classes reached there too): DisplayDrawer.swift wraps only "
    "Prs3d_Drawer's tessellation-quality SETTINGS, never a Prs3d_Presentation object any StdPrs_ "
    "builder would draw into, and PresentationMesh.swift builds Metal vertex buffers directly from "
    "Poly_Triangulation mesh data rather than through any StdPrs_ builder. "
    "**One exception worth naming rather than folding in silently**: StdPrs_BRepFont/"
    "StdPrs_BRepTextBuilder are not presentation-pipeline glue at all, they convert a font glyph to "
    "real B-Rep face geometry (extrudable text-as-solid outlines), a capability with no "
    "Prs3d_Presentation dependency whatsoever. Nothing in this bridge builds text as geometry "
    "(AIS_TextLabel, this lane's other text-related wrap, is a flat label position/string/height "
    "carrier read into Metal, not a font-to-BRep path -- confirmed at OCCTBridge_AIS.mm's "
    "`new AIS_TextLabel()` construction, no font/glyph handling anywhere near it), so this is a "
    "real, if narrow, additional gap distinct from the rest of the family, recorded by name here "
    "rather than anonymously."
)
_add({c: _STDPRS_REASON for c in LANE_CLASSES["StdPrs"]}, "STDPRS_PRESENTATION_BUILDER_FAMILY")

# --- StdSelect (9 curated; 2 already ok: BRepOwner, BRepSelectionTool) ----------------------------

_add({
    "StdSelect": ("bare package header, an all-static-method class (DEFINE_STANDARD_ALLOC) "
        "providing StdSelect_BRepSelectionTool's own construction helpers; no instance, nothing a "
        "caller constructs directly"),
}, "STDSELECT_PACKAGE_UTILITY")

_STDSELECT_FILTER_REASON = ("a SelectMgr_Filter subclass for OCCT's own live-viewer selection "
    "filtering by edge/face type (SelectMgr_ itself is out of this lane's scope per #814's own "
    "text); this bridge discriminates shape/edge/face TYPE directly in Swift over "
    "StdSelect_BRepOwner's own owner-type accessor (wrapped), not through a filter object")
_add({
    "StdSelect_EdgeFilter": _STDSELECT_FILTER_REASON,
    "StdSelect_FaceFilter": _STDSELECT_FILTER_REASON,
    "StdSelect_ShapeTypeFilter": _STDSELECT_FILTER_REASON,
}, "STDSELECT_FILTERS")

_add({
    "StdSelect_Shape": ("a PrsMgr_PresentableObject display proxy StdSelect_BRepOwner's own "
        "sensitive-primitive presentation uses within a live AIS/SelectMgr viewer (per its own "
        "header: \"Presentable shape only for purpose of display for BRepOwner\"); this bridge's "
        "picking never displays through a live PrsMgr-managed presentation"),
    "StdSelect_TypeOfEdge": ("mode enum for StdSelect_EdgeFilter (curated above, unused)"),
    "StdSelect_TypeOfFace": ("mode enum for StdSelect_FaceFilter (curated above, unused)"),
    "StdSelect_TypeOfSelectionImage": ("mode enum for OCCT's own selection-buffer visualization "
        "debugging aid; no such debug view exists in this bridge"),
    "StdSelect_ViewerSelector3d": ("a `using StdSelect_ViewerSelector3d = SelectMgr_ViewerSelector` "
        "alias; docs/reference/Selection.md's own description confirms this bridge instead "
        "subclasses SelectMgr_ViewerSelector directly as its own OCCTHeadlessSelector "
        "(\"a subclass of OCCT's SelectMgr_ViewerSelector\"), never through this alias. Named here "
        "only to explain why the alias is unused; SelectMgr_ViewerSelector itself is out of this "
        "lane's scope per #814's own text"),
}, "STDSELECT_MISC")

# ------------------------------------------------------------------------------------------------
# Over-coverage. 12 confirmed findings, all fixed in this PR (docs-only). 6 candidates investigated
# and rejected as false positives, see the module docstring and REJECTED_OVER_CANDIDATES below.
# ------------------------------------------------------------------------------------------------

KNOWN_OVER_FINDINGS: list[tuple[str, str]] = [
    ("docs/reference/Document-Mesh-Fixing.md", "`Poly_Triangulation::NbNodes`."),
    ("docs/reference/Document-Mesh-Fixing.md", "`Poly_Triangulation::NbTriangles`."),
    ("docs/reference/Document-Mesh-Fixing.md", "`Poly_Triangulation::Node`."),
    ("docs/reference/Document-Mesh-Fixing.md", "`Poly_Triangulation::HasNormals`."),
    ("docs/reference/Document-Mesh-Fixing.md", "`Poly_Triangulation::Normal`."),
    ("docs/reference/Document-Mesh-Fixing.md", "`Poly_Triangulation::Triangle`."),
    ("docs/reference/Document.md",
     "`Poly_Triangulation::NbNodes` (via `OCCTDocumentTriangulationNbNodes`)."),
    ("docs/reference/Document.md",
     "`Poly_Triangulation::NbTriangles` (via `OCCTDocumentTriangulationNbTriangles`)."),
    ("docs/reference/Document.md", "`Poly_Triangulation::Node` (via `OCCTDocumentTriangulationNode`)."),
    ("docs/reference/Document.md",
     "`Poly_Triangulation::Normal` guarded by `HasNormals` (via `OCCTDocumentTriangulationNormal`)."),
    ("docs/reference/Document.md",
     "`Poly_Triangulation::Deflection` (via `OCCTDocumentTriangulationDeflection`)."),
    ("docs/API_REFERENCE.md", "`PointCloud(points:)` / `PointCloud(points:colors:)` | `AIS_PointCloud` |"),
]
PRESENCE_EXEMPT_PINS: list[tuple[str, str]] = []
KNOWN_OVER_FINDING_COUNT = len(KNOWN_OVER_FINDINGS)

REJECTED_OVER_CANDIDATES: list[tuple[str, str, str]] = [
    ("docs/reference/Color-Material.md:790", "Graphic3d_MaterialAspect via OCCTVisMaterialCommonDefault",
     "checker heading/subject mis-association: two different Swift structs both have an "
     "`ambientColor` field (Material.swift's PredefinedMaterial and VisMaterial.swift's own "
     "struct); the checker matched the wrong one. Confirmed: PredefinedMaterial.ambientColor is "
     "populated by OCCTMaterialFromName/FromIndex, which construct Graphic3d_MaterialAspect "
     "directly (`Graphic3d_MaterialAspect mat(nom);`), so the doc's own claim is correct"),
    ("docs/reference/Export-Vector.md:1122", "Image_PixMap via OCCTImageInitCopy",
     "false positive, not a false claim: the doc text \"Image_AlienPixMap::InitCopy(Image_PixMap)\" "
     "correctly describes InitCopy's real declared parameter type (confirmed at the pinned header, "
     "`bool InitCopy(const Image_PixMap& theCopy) override`); the checker's reachable() walker "
     "requires the class literally spelled out in the named function's own body, which "
     "OCCTImageInitCopy (typed OCCTImage*/Handle(Image_AlienPixMap)) never does for the PARAMETER "
     "type of a method it calls correctly"),
    ("docs/reference/Mesh.md:352", "BRepMesh_IncrementalMesh via OCCTMeshUnion",
     "multi-hop reachability the checker doesn't chase: OCCTMeshUnion -> occtMeshBoolean -> "
     "OCCTShapeCreateMesh, and OCCTShapeCreateMesh does construct BRepMesh_IncrementalMesh "
     "directly (confirmed at the call site); the doc's own arrow notation "
     "(\"-> BRepBuilderAPI_Sewing + BRepAlgoAPI_Fuse + BRepMesh_IncrementalMesh\") already signals "
     "a multi-step pipeline rather than one function's own body"),
    ("docs/reference/Mesh.md:381", "BRepMesh_IncrementalMesh via OCCTMeshSubtract",
     "same shape as :352, one hop through occtMeshBoolean -> OCCTShapeCreateMesh"),
    ("docs/reference/Mesh.md:404", "BRepMesh_IncrementalMesh via OCCTMeshIntersect",
     "same shape as :352"),
    ("Sources/OCCTBridge/include/OCCTBridge_Topology.h:861",
     "BRepMesh_IncrementalMesh via OCCTShapePolyhedralDistance",
     "the header comment (\"Shapes must be meshed beforehand (BRepMesh_IncrementalMesh)\") "
     "documents a PRECONDITION the caller must satisfy before calling, not a claim that this "
     "function itself calls BRepMesh_IncrementalMesh; confirmed at the implementation, which calls "
     "BRepExtrema_Poly::Distance on the shapes' EXISTING triangulation, the same rejected shape as "
     "#812's own \"prose describes a real mechanism accurately\" candidate"),
]

METHOD_ATTRIBUTION_ALLOWED: set[tuple[str, str]] = set()

_ATTRIBUTION_RE = re.compile(
    r"`([A-Za-z][A-Za-z0-9]*(?:_[A-Za-z0-9]+)?)::([A-Za-z_][A-Za-z0-9_]*)"
)

# ------------------------------------------------------------------------------------------------
# Measurement (identical shape to #811/#812/#982/#983's refman_census.py)
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
    """(verdict, note, bridge hits, docs hits). Ordering (wrapped, curated, documented, gaps.md,
    under) and the gaps.md exclusion from the docs test are both load-bearing, per every prior
    lane's own classify() docstring; `selftest_removal_matrix.py` re-proves both here."""
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
                "entry (recorded elsewhere, e.g. #810/#982's own sections)", bridge, docs)
    return ("under", "neither wrapped nor documented, and no reason recorded", bridge, docs)


# ------------------------------------------------------------------------------------------------
# Over-coverage checks (structurally identical to every prior lane's)
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


_ENUM_BLOCK_RE = re.compile(r"\benum\s+(?:class\s+)?[A-Za-z_][A-Za-z0-9_]*\s*\{([^}]*)\}", re.S)


def _is_enum_value(text: str, member: str) -> bool:
    """A lane-driven addition: `declares_member`'s original four shapes (method-call, nested-type,
    data-member, base-class-walk) all answer "is MEMBER a declared name", never "is MEMBER one of
    an enum's own VALUES" -- a real, common OCCT doc pattern this lane's own
    `Graphic3d_Camera::Projection_Perspective` citation surfaced on its first real run (not a
    contrived case): `Graphic3d_Camera::Projection` is an unscoped `enum { Projection_Orthographic,
    Projection_Perspective, ... }`, and the doc's citation is genuinely correct, but no prior shape
    matches an enumerator token sitting inside an `enum { ... }` body rather than the enum's own
    name. Fifth shape, not a rewrite of the other four."""
    for m in _ENUM_BLOCK_RE.finditer(text):
        if re.search(r"\b" + re.escape(member) + r"\b", m.group(1)):
            return True
    return False


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
    if _is_enum_value(text, member):
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
# Self-test. `declares_member` and `classify` are DETECTORS; a detector that reports "all clear"
# because it is blind looks exactly like one reporting "all clear" because the tree is clean
# (okf/policies/prove-the-test-fails.md). `selftest_removal_matrix.py` next to this file switches
# off each accepting shape in turn and proves each case here actually needs it.
# ------------------------------------------------------------------------------------------------

SELF_TEST_CASES = [
    ("BRepMesh_IncrementalMesh", "Perform", True,
     "the refman-confirmed member (occt-refman@8.0.1, class_b_rep_mesh___incremental_mesh.html), "
     "the method OCCTShapeCreateMesh calls, so the lookup path CLAUDE.md mandates is exercised by "
     "a case rather than only in prose"),
    ("BRepMesh_IncrementalMesh", "Refresh", False,
     "a plausible-sounding name that is not declared: the class has Perform/IsModified, not "
     "Refresh"),
    ("Poly_Triangulation", "NbNodes", True,
     "a real method (`int NbNodes() const`), the one the MeshFaceIterator misattribution "
     "investigation confirmed is genuinely declared on Poly_Triangulation itself, just not the one "
     "the bridge's RWMesh_FaceIterator path actually calls"),
    ("Poly_Triangulation", "NbVertices", False,
     "does not exist: Poly_Triangulation counts nodes (NbNodes), not vertices"),
    ("RWMesh_FaceIterator", "TriangleOriented", True,
     "declared locally on RWMesh_FaceIterator (not inherited), the method "
     "OCCTMeshFaceIterTriangle actually calls -- confirms the over-coverage fix's own claim"),
    ("RWMesh_FaceIterator", "NodeTransformed", True,
     "a BASE-CLASS-WALK case: declared on RWMesh_ShapeIterator, RWMesh_FaceIterator's own base, "
     "not on RWMesh_FaceIterator itself -- the method OCCTMeshFaceIterNode calls"),
    ("TDataXtd_Triangulation", "Deflection", True,
     "declared locally on TDataXtd_Triangulation (a TDF_Attribute, not a Poly_Triangulation "
     "relative at all), the method OCCTDocumentTriangulationDeflection calls"),
    ("Graphic3d_MaterialAspect", "ambientColor", False,
     "a plausible-sounding but wrong-case guess: the real Phong ambient accessor is "
     "Ambient()/SetAmbientColor() with capital first letters, and camelCase never matches"),
    ("IMeshData_Model", "AddFace", True,
     "an ABSTRACT method (`virtual ... AddFace(...) = 0`), matched by the method-call shape even "
     "though the class itself is never instantiated, proving `declares_member` answers about the "
     "DECLARATION, not about whether the class is reachable (that is `classify`'s own, separate, "
     "wrapped-first test)"),
    ("Poly_MakeLoops", "LinkFlag", True,
     "a NESTED ENUM (Poly_MakeLoops::LinkFlag), matched by the nested-type shape rather than the "
     "method-call one, since nothing follows it with `(`"),
    ("Graphic3d_Camera", "Projection_Perspective", True,
     "an ENUM VALUE (Graphic3d_Camera::Projection's own `Projection_Perspective` enumerator, "
     "docs/reference/Display.md's real citation that first surfaced this shape needing a fifth "
     "case, not a contrived one), matched by neither method-call, nested-type, data-member nor "
     "base-class-walk -- only the dedicated enum-value shape"),
    ("Graphic3d_Camera", "Projection_Isometric", False,
     "a plausible-sounding enumerator that does not exist: the real Projection enum has "
     "Orthographic/Perspective/Stereo/MonoLeftEye/MonoRightEye, no Isometric"),
    ("HLRAlgo_Projector", "myPersp", True,
     "a class OUTSIDE this lane (Pass 4b's own #812 case, reused here as a boundary probe): "
     "HLRAlgo_ is not in LANE_CLASSES, but the header itself still exists in the pinned kernel, so "
     "declares_member (which reads the pinned header directly, not LANE_CLASSES) still resolves it "
     "True; this case exists to confirm declares_member's own header-reading path is lane-agnostic "
     "by design, `classify`'s wrapped/curated/documented ordering is the layer that scopes to the "
     "lane, not this function"),
]

PARSE_SELF_TEST_CASES = [
    ("- **OCCT:** `BRepMesh_IncrementalMesh::Perform`.",
     [("BRepMesh_IncrementalMesh", "Perform")],
     "the plain spelling, closing backtick straight after the member"),
    ("- **OCCT:** `RWMesh_FaceIterator::TriangleOriented()` returns the triangle.",
     [("RWMesh_FaceIterator", "TriangleOriented")],
     "the parenthesised spelling; a pattern anchored on the closing backtick would miss this"),
    ("`Poly_Triangulation::NbNodes()` then `Poly_Triangulation::NbTriangles()`.",
     [("Poly_Triangulation", "NbNodes"), ("Poly_Triangulation", "NbTriangles")],
     "two attributions on one line, so the walk is findall rather than search"),
    ("The `AIS_TextLabel` handle is returned.", [],
     "a class named with no member, which must not produce a pair"),
    ("    iter->iter.HasNormals();", [],
     "a real line of OCCTBridge_Mesh.mm using -> not ::, must not match"),
    ("Reached through TDataXtd_Triangulation::Node rather than named directly.", [],
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
    ap = argparse.ArgumentParser(description="#814 refman coverage census, Mesh/presentation/misc lane")
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

    print(f"#814 Mesh/presentation/misc lane: {total} classes across {len(LANE_CLASSES)} packages")
    print(f"{'class':<48} {'verdict':<22} note")
    print("-" * 140)

    tally = {"ok": 0, "deliberate, recorded": 0, "under": 0, "over": 0}
    unders = []
    bucket_tally: dict[str, int] = {}
    for pkg in sorted(LANE_CLASSES):
        for cls in LANE_CLASSES[pkg]:
            verdict, note, bridge, docs = classify(cls, cache)
            tally[verdict] += 1
            if cls in CURATED:
                bucket_tally[CURATED[cls][0]] = bucket_tally.get(CURATED[cls][0], 0) + 1
            if verdict == "under":
                unders.append((cls, note))
            print(f"{cls:<48} {verdict:<22} {note[:180]}")
            if args.verbose:
                if bridge:
                    print(f"{'':<48} {'':<22} bridge: {', '.join(bridge)}")
                if docs:
                    print(f"{'':<48} {'':<22} docs:   {', '.join(docs)}")

    print()
    print("verdicts:")
    for k in ("ok", "deliberate, recorded", "under"):
        print(f"  {k:<22} {tally[k]}")

    print()
    print("curated buckets:")
    for label, n in sorted(bucket_tally.items()):
        print(f"  {label:<40} {n:>4}")

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
            print("lane re-derivation: the pinned headers still give exactly these 368 classes")

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
