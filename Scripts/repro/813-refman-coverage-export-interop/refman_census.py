#!/usr/bin/env python3
"""Issue #813 (Pass 4c of #807): refman coverage census for the Export/interop lane.

WHY A SCRIPT, NOT A LIST IN THE ISSUE: `docs/v2.0.0-plan.md`'s census rule, and this repo's history
of hand-built censuses that were confidently wrong differently each time (#558, #571, #573, #583,
#595, #507, #553, #562). #811/#812/#982/#983 (the prior #807 passes) are the template this file
follows.

THE LANE, per #813's own `## Lane` text: `STEPControl_*`, `IGESControl_*`, `StlAPI_*`, `RWObj_*`,
`RWGltf_*`, `RWPly_*`, `RWMesh_*`, `Interface_*`, `Transfer_*`, `BinTools_*`, `Resource_*`, plus
the `Exporter`/`Importer` Swift surface. Eleven packages, **192 headers**, confirmed by
`derive_lane.py` (a naive prefix match without an optional bare-header suffix gives 190, missing
`BinTools.hxx`/`RWMesh.hxx`/`RWObj.hxx`/`StlAPI.hxx`, the same bare-package-header shape #812 found
for `HLRAlgo.hxx`/`HLRBRep.hxx`).

`BinTools_`/`Resource_` are in this lane on #973's own measurement (see #813's issue body): the
majority of each package's OCCT consumers are outside OCAF, and OCAF's own persistence formats
(`PCDM_`/`Storage_`/etc., #983's lane, Pass 3c) are explicitly NOT this lane's -- not re-litigated
here, both boundaries were already measured before this issue opened.

**The lane changed underneath this issue, per its own body.** Pass 4c's duplication work (#387)
landed the same day this audit was written: `Exporter.swift`/`DXFExporter.swift`/
`PDFExporter.swift`/`SVGExporter.swift` all got real changes (`validateExportInputs`,
`DrawingEntityBuffer`, `dashLengths`, `writeWithProgress`, `dataViaTempFile`). Re-checked directly
rather than assumed stale: none of the three non-OCCT writers (`PDFExporter`, `SVGExporter`,
`DXFExporter`) calls a single `OCCT*` identifier (`derive_lane.py`'s own check), so #813's own
flagged false-positive risk (#795 consolidated these onto one pure-Swift dispatcher, no OCCT
counterpart at all, the same shape #812 handled for ten pure-Swift drafting files) is confirmed
rather than merely warned about.

**22 of the 192 are wrapped, 0 documented-without-being-wrapped, 170 curated.** Unlike #811's
lane (real capability gaps throughout) and closer to #812's (mostly internal engine machinery),
this lane is the generic OCCT data-exchange (XSTEP) framework: `STEPControl_Reader`/`Writer` and
`IGESControl_Reader`/`Writer` are thin facades over `Interface_*`/`Transfer_*`, a ~100-class
generic entity/model/check/transfer-process framework a CAD consumer never touches directly, the
same shape #812 found for hidden-line removal's ~60 internal classes. Every curated reason below
was read off the pinned header (and, where the contract was in question, the refman through the
`context` MCP at `occt-refman@8.0.1`) during #813, never inferred from the class name.

TWO CLASSES THAT LOOKED "DOCUMENTED" AND ARE NOT, on inspection: `BinTools` and `RWMesh` (the two
bare package-utility headers with real doc-file hits, `docs/API_REFERENCE.md`,
`docs/reference/Document-XCAF-Notes.md`, `docs/reference/Document-Mesh-Fixing.md`) are the same
"toolkit-name mention counts as a false 'documented' hit" trap #812 found for `HLRAlgo`/`HLRBRep`
against the gaps.md summary line. Here it is worse: the `BinTools` hit is not just a heading
mention, it IS the #813 over-coverage finding below (docs attributed `toBinaryData()`/
`fromBinaryData()`/`writeBinary()`/`loadBinary()` to `BinTools::Write`/`BinTools::Read`, the bare
class's own static methods, when the bridge actually calls `BinTools_ShapeWriter::Write`/
`BinTools_ShapeReader::Read`). Both are classified via `CURATED` (checked before the docs test,
same ordering #811 established and #812 re-proved) rather than via the accidental docs hit, and
recorded in `docs/occtswift-wrapping-gaps.md` with the real, specific reason: PACKAGE_UTILITY,
matching `HLRAlgo`/`HLRBRep`.

OVER-COVERAGE, three findings, all fixed in this same PR (see the PR body for the diff):

  1. `docs/reference/Document-XCAF-Notes.md` (4 lines): `Shape.toBinaryData()`/`fromBinaryData()`/
     `writeBinary()`/`loadBinary()` attributed to `BinTools::Write`/`BinTools::Read` (the bare
     package-utility class's static methods). The bridge (`OCCTBinToolsWriteShape`/
     `OCCTBinToolsReadShape`/`OCCTBinToolsWriteShapeToFile`/`OCCTBinToolsReadShapeFromFile`,
     `OCCTBridge_IO.mm:2448-2522`) constructs `BinTools_ShapeWriter`/`BinTools_ShapeReader` and
     calls their `Write`/`Read` instance methods; the bare `BinTools::Write`/`Read` static methods
     are never called anywhere in the bridge (confirmed: zero `BinTools::` call sites tree-wide).
  2. `docs/reference/Shape.md:1885`: `IGESControl_Reader::Transfer` attributed to
     `OCCTImportIGESRoot`. No method named plain `Transfer` is declared anywhere on
     `IGESControl_Reader` or its base `XSControl_Reader` -- the header's own doc comment says
     `reader.Transfer(num)` in prose (a stale name, OCCT's own comment never updated), but the
     bridge (`OCCTBridge_IO.mm:1689`) calls `reader.TransferOneRoot(rootIndex)`, a real, distinct
     method (`XSControl_Reader.hxx:169`).
  3. `docs/reference/Shape.md:1623`: `Shape.loadSTEP(from:unitInMeters:progress:)` attributed to
     "`STEPControl_Reader` with `Interface_Static` unit setting". The bridge
     (`OCCTImportSTEPWithUnitProgress`, `OCCTBridge_IO.mm:497-498`) calls
     `reader.SetSystemLengthUnit(unitInMeters)` directly, a real method declared on
     `STEPControl_Reader` itself (`STEPControl_Reader.hxx:125`); `Interface_Static` is never
     touched for this specific call (the mutex comment two lines above, "STEP/IGES share
     Interface_Static globals", explains why the *lock* is needed elsewhere in the same file, not
     that this call uses it).

  The #928 detector (`census-doc-occt-attribution.py --lane ...`) found 3 candidates; 1 (finding 3
  above) was true, 2 were false positives of shapes this project has already catalogued: a
  heading-level "load" match picking up unrelated bridge functions (`Shape.load(from:)` -> the
  detector's own heuristic tried `OCCTImageLoad`/`OCCTSewingLoad`, neither STEP-related, while the
  real function, `OCCTImportSTEPProgress`, does call `STEPControl_Reader` correctly), and a
  cross-function hidden-member case (`RWMesh_CoordinateSystemConverter` is a private member of
  `RWObj_CafReader`'s base class, set via its public `SetFileCoordinateSystem`/
  `SetSystemCoordinateSystem` setters rather than constructed by name in the bridge function the
  heading names -- the exact shape #812's own `HLRBRep_HLRToShape` false positive was). Findings 1
  and 2 above were found by hand, reading every remaining `- **OCCT:**` bullet touching this lane's
  22 wrapped classes against the pinned headers, the same discipline #811/#812 applied.

UNDER-COVERAGE, four real capability gaps recorded (not "fixed": #813's own done-when criteria ask
only that a reason be recorded, and none of the four is large enough to justify a same-PR fix or a
follow-up issue on its own -- each is a small, optional enhancement, not a defect):

  - `RWMesh_EdgeIterator`: sibling of the wrapped `RWMesh_FaceIterator`/`RWMesh_VertexIterator`
    (all three inherit `RWMesh_ShapeIterator`), not wrapped. No design reason found; `Sources/`
    and `docs/` both confirm zero references anywhere in the tree.
  - `RWGltf_DracoParameters`: Draco mesh-compression settings for glTF export. `RWGltf_CafWriter`
    has no bridge-exposed compression control at all.
  - `Interface_Check`/`Interface_CheckIterator`: per-entity fail/warning messages from a STEP or
    IGES read. `OCCTImportSTEPWithDiagnostics` (the one bridge function whose name suggests this)
    reports shape-type info, not check messages; nothing in the tree surfaces read diagnostics at
    the entity level.

Run from anywhere (paths derive from this file's location, not the cwd):

    python3 Scripts/repro/813-refman-coverage-export-interop/refman_census.py
    python3 Scripts/repro/813-refman-coverage-export-interop/refman_census.py --verbose
    python3 Scripts/repro/813-refman-coverage-export-interop/refman_census.py --reverify-lane
    python3 Scripts/repro/813-refman-coverage-export-interop/refman_census.py --self-test

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

LANE_PACKAGES = ("STEPControl", "IGESControl", "StlAPI", "RWObj", "RWGltf", "RWPly", "RWMesh",
                  "Interface", "Transfer", "BinTools", "Resource")

LANE_HEADER_RE = re.compile(
    r"^(STEPControl|IGESControl|StlAPI|RWObj|RWGltf|RWPly|RWMesh|Interface|Transfer|BinTools|"
    r"Resource)(_[^.]+)?\.hxx$"
)

# ------------------------------------------------------------------------------------------------
# The lane: 192 classes, enumerated from the pinned kernel's own headers (OCCT 8.0.1 plus the
# carried patches) on 2026-08-28. Re-derive with `derive_lane.py`, or directly:
#
#   ls Libraries/OCCT.xcframework/macos-arm64/Headers | \
#     grep -E '^(STEPControl|IGESControl|StlAPI|RWObj|RWGltf|RWPly|RWMesh|Interface|Transfer|
#                BinTools|Resource)(_[^.]+)?\.hxx$' | sed 's/\.hxx$//' | sort
#
# `--reverify-lane` runs exactly that derivation and diffs it against this list.
# ------------------------------------------------------------------------------------------------

LANE_CLASSES: dict[str, list[str]] = {
    "STEPControl": [
        "STEPControl_ActorRead", "STEPControl_ActorWrite", "STEPControl_Controller",
        "STEPControl_Reader", "STEPControl_StepModelType", "STEPControl_Writer",
    ],
    "IGESControl": [
        "IGESControl_ActorWrite", "IGESControl_AlgoContainer", "IGESControl_Controller",
        "IGESControl_IGESBoundary", "IGESControl_Reader", "IGESControl_ToolContainer",
        "IGESControl_Writer",
    ],
    "StlAPI": ["StlAPI", "StlAPI_Reader", "StlAPI_Writer"],
    "RWObj": [
        "RWObj", "RWObj_CafReader", "RWObj_CafWriter", "RWObj_Material", "RWObj_MtlReader",
        "RWObj_ObjMaterialMap", "RWObj_ObjWriterContext", "RWObj_Reader", "RWObj_SubMesh",
        "RWObj_SubMeshReason", "RWObj_Tools", "RWObj_TriangulationReader",
    ],
    "RWGltf": [
        "RWGltf_CafReader", "RWGltf_CafWriter", "RWGltf_DracoParameters", "RWGltf_GltfAccessor",
        "RWGltf_GltfAccessorCompType", "RWGltf_GltfAccessorLayout", "RWGltf_GltfAlphaMode",
        "RWGltf_GltfArrayType", "RWGltf_GltfBufferView", "RWGltf_GltfBufferViewTarget",
        "RWGltf_GltfFace", "RWGltf_GltfJsonParser", "RWGltf_GltfLatePrimitiveArray",
        "RWGltf_GltfMaterialMap", "RWGltf_GltfOStreamWriter", "RWGltf_GltfPrimArrayData",
        "RWGltf_GltfPrimitiveMode", "RWGltf_GltfRootElement", "RWGltf_GltfSceneNodeMap",
        "RWGltf_MaterialCommon", "RWGltf_MaterialMetallicRoughness", "RWGltf_TriangulationReader",
        "RWGltf_WriterTrsfFormat",
    ],
    "RWPly": ["RWPly_CafWriter", "RWPly_PlyWriterContext"],
    "RWMesh": [
        "RWMesh", "RWMesh_CafReader", "RWMesh_CoordinateSystem", "RWMesh_CoordinateSystemConverter",
        "RWMesh_EdgeIterator", "RWMesh_FaceIterator", "RWMesh_MaterialMap", "RWMesh_NameFormat",
        "RWMesh_NodeAttributes", "RWMesh_ShapeIterator", "RWMesh_TriangulationReader",
        "RWMesh_TriangulationSource", "RWMesh_VertexIterator",
    ],
    "Interface": [
        "Interface_Array1OfFileParameter", "Interface_Array1OfHAsciiString", "Interface_BitMap",
        "Interface_Category", "Interface_Check", "Interface_CheckFailure",
        "Interface_CheckIterator", "Interface_CheckStatus", "Interface_CheckTool",
        "Interface_CopyControl", "Interface_CopyMap", "Interface_CopyTool",
        "Interface_DataMapOfTransientInteger", "Interface_DataState", "Interface_EntityCluster",
        "Interface_EntityIterator", "Interface_EntityList", "Interface_FileParameter",
        "Interface_FileReaderData", "Interface_FileReaderTool", "Interface_FloatWriter",
        "Interface_GTool", "Interface_GeneralLib", "Interface_GeneralModule",
        "Interface_GlobalNodeOfGeneralLib", "Interface_GlobalNodeOfReaderLib", "Interface_Graph",
        "Interface_GraphContent", "Interface_HArray1OfHAsciiString", "Interface_HGraph",
        "Interface_HSequenceOfCheck", "Interface_IndexedMapOfAsciiString", "Interface_IntList",
        "Interface_IntVal", "Interface_InterfaceError", "Interface_InterfaceMismatch",
        "Interface_InterfaceModel", "Interface_LineBuffer", "Interface_MSG",
        "Interface_NodeOfGeneralLib", "Interface_NodeOfReaderLib", "Interface_ParamList",
        "Interface_ParamSet", "Interface_ParamType", "Interface_Protocol", "Interface_ReaderLib",
        "Interface_ReaderModule", "Interface_ReportEntity", "Interface_STAT",
        "Interface_SequenceOfCheck", "Interface_ShareFlags", "Interface_ShareTool",
        "Interface_SignLabel", "Interface_SignType", "Interface_Static",
        "Interface_StaticSatisfies", "Interface_Statics", "Interface_Translates",
        "Interface_TypedValue", "Interface_UndefinedContent", "Interface_ValueInterpret",
        "Interface_ValueSatisfies", "Interface_VectorOfFileParameter", "Interface_Version",
    ],
    "Transfer": [
        "Transfer_ActorDispatch", "Transfer_ActorOfFinderProcess",
        "Transfer_ActorOfProcessForFinder", "Transfer_ActorOfProcessForTransient",
        "Transfer_ActorOfTransientProcess", "Transfer_Binder", "Transfer_BinderOfTransientInteger",
        "Transfer_DataInfo", "Transfer_DispatchControl", "Transfer_FindHasher", "Transfer_Finder",
        "Transfer_FinderProcess", "Transfer_HSequenceOfBinder", "Transfer_HSequenceOfFinder",
        "Transfer_IteratorOfProcessForFinder", "Transfer_IteratorOfProcessForTransient",
        "Transfer_MapContainer", "Transfer_MultipleBinder", "Transfer_ProcessForFinder",
        "Transfer_ProcessForTransient", "Transfer_ResultFromModel", "Transfer_ResultFromTransient",
        "Transfer_SequenceOfBinder", "Transfer_SequenceOfFinder",
        "Transfer_SimpleBinderOfTransient", "Transfer_StatusExec", "Transfer_StatusResult",
        "Transfer_TransferDeadLoop", "Transfer_TransferDispatch", "Transfer_TransferFailure",
        "Transfer_TransferInput", "Transfer_TransferIterator",
        "Transfer_TransferMapOfProcessForFinder", "Transfer_TransferMapOfProcessForTransient",
        "Transfer_TransferOutput", "Transfer_TransientListBinder", "Transfer_TransientMapper",
        "Transfer_TransientProcess", "Transfer_UndefMode", "Transfer_VoidBinder",
    ],
    "BinTools": [
        "BinTools", "BinTools_Curve2dSet", "BinTools_CurveSet", "BinTools_FormatVersion",
        "BinTools_IStream", "BinTools_LocationSet", "BinTools_LocationSetPtr", "BinTools_OStream",
        "BinTools_ObjectType", "BinTools_ShapeReader", "BinTools_ShapeSet",
        "BinTools_ShapeSetBase", "BinTools_ShapeWriter", "BinTools_SurfaceSet",
    ],
    "Resource": [
        "Resource_ConvertUnicode", "Resource_DataMapOfAsciiStringAsciiString",
        "Resource_DataMapOfAsciiStringExtendedString", "Resource_FormatType",
        "Resource_LexicalCompare", "Resource_Manager", "Resource_NoSuchResource",
        "Resource_Unicode",
    ],
}

FAMILY_COUNTS = {
    "STEPControl": 6, "IGESControl": 7, "StlAPI": 3, "RWObj": 12, "RWGltf": 23, "RWPly": 2,
    "RWMesh": 13, "Interface": 64, "Transfer": 40, "BinTools": 14, "Resource": 8,
}
LANE_TOTAL = 192

# ------------------------------------------------------------------------------------------------
# Curated classification tables. Each reason was read off the pinned header during #813 (briefs
# pulled from the `//!` Doxygen comment above each `class`/`struct`/`using` declaration, base
# classes and call sites confirmed by grep, not inferred from the name). 170 of the 192 land here.
# ------------------------------------------------------------------------------------------------

PACKAGE_UTILITY = {
    "BinTools": "bare package header, an all-static-method class (Write/Read/PutReal/GetReal/...) "
               "for the OLD one-shot binary shape I/O; superseded by the object-oriented "
               "BinTools_ShapeReader/ShapeWriter this bridge actually wraps and calls "
               "(OCCTBinToolsReadShape/WriteShape, OCCTBridge_IO.mm), which is also the #813 "
               "over-coverage finding: docs attributed the wrapped capability to this class by "
               "mistake, fixed in the same PR",
    "RWMesh": "bare package header, two static helpers (ReadNameAttribute/FormatName) for XCAF "
             "shape-label name formatting; RWMesh_FaceIterator/VertexIterator (the classes this "
             "bridge actually wraps) are unrelated iterator types in the same header file's "
             "package, not built on these two statics",
    "RWObj": "bare package header, one static helper (ReadFile) returning a raw Poly_Triangulation "
            "with no document/material support; superseded by RWObj_CafReader (wrapped), the "
            "document-aware, material-aware reader this bridge actually calls",
    "StlAPI": "bare package header, two static helpers (Write/Read) for one-shot STL I/O; "
             "superseded by the object-oriented StlAPI_Reader/StlAPI_Writer this bridge actually "
             "wraps and calls (OCCTImportSTL, OCCTExportSTLWithMode, OCCTBridge_IO.mm), same shape "
             "as BinTools above",
}

DEPRECATED_COLLECTION_ALIASES = {
    c: "file-scope Standard_HEADER_DEPRECATED, deprecated since OCCT 8.0.0, use NCollection directly"
    for c in [
        "Interface_Array1OfFileParameter", "Interface_Array1OfHAsciiString",
        "Interface_DataMapOfTransientInteger", "Interface_HArray1OfHAsciiString",
        "Interface_HSequenceOfCheck", "Interface_IndexedMapOfAsciiString",
        "Interface_SequenceOfCheck", "Interface_VectorOfFileParameter",
        "Transfer_HSequenceOfBinder", "Transfer_HSequenceOfFinder", "Transfer_SequenceOfBinder",
        "Transfer_SequenceOfFinder", "Transfer_TransferMapOfProcessForFinder",
        "Transfer_TransferMapOfProcessForTransient",
        "Resource_DataMapOfAsciiStringAsciiString", "Resource_DataMapOfAsciiStringExtendedString",
    ]
}

PRIVATE_IMPLEMENTATION = {
    "Interface_Statics": "declares no class: a pure C-preprocessor macro header (StaticHandle/"
                         "InitHandle/...) for pre-C++11 static-Handle initialisation idioms",
    "Interface_Translates": "declares no class: a pure C-preprocessor macro header "
                            "(SeqToArray/ArrayToSeq/...) for Sequence<->Array conversion boilerplate",
    "Interface_Version": "declares no class: four #define version-string macros "
                         "(XSTEP_PROCESSOR_VERSION and siblings)",
    "BinTools_LocationSetPtr": "not a class: `typedef BinTools_LocationSet* BinTools_LocationSetPtr`, "
                              "a raw-pointer alias for the generic template-instantiation interface",
    "Resource_ConvertUnicode": "declares no class: six `extern \"C\"` free functions "
                              "(Resource_sjis_to_unicode and siblings), the low-level codec "
                              "routines Resource_Unicode's static methods call internally",
}

CALLBACK_TYPEDEF = {
    "Interface_StaticSatisfies": "not a class: `typedef bool (*Interface_StaticSatisfies)(...)`, "
                                 "a callback function-pointer type for Interface_TypedValue's "
                                 "validation hook",
    "Interface_ValueInterpret": "not a class: a callback function-pointer typedef, sibling of "
                                "Interface_StaticSatisfies",
    "Interface_ValueSatisfies": "not a class: a callback function-pointer typedef, sibling of "
                                "Interface_StaticSatisfies",
}

EXCEPTION_TYPES = {
    "Interface_InterfaceError": "DEFINE_STANDARD_EXCEPTION(Interface_InterfaceError, "
                                "Standard_Failure): an exception type, not constructed by a caller",
    "Interface_InterfaceMismatch": "DEFINE_STANDARD_EXCEPTION(..., Interface_InterfaceError): "
                                   "exception subtype",
    "Interface_CheckFailure": "DEFINE_STANDARD_EXCEPTION(..., Interface_InterfaceError): "
                              "exception subtype",
    "Transfer_TransferFailure": "DEFINE_STANDARD_EXCEPTION(..., Interface_InterfaceError): "
                                "exception subtype",
    "Transfer_TransferDeadLoop": "DEFINE_STANDARD_EXCEPTION(..., Transfer_TransferFailure), and "
                                 "additionally class-level Standard_DEPRECATED since OCCT 7.9.0: "
                                 "\"this exception is deprecated and no longer thrown\"",
    "Resource_NoSuchResource": "DEFINE_STANDARD_EXCEPTION(..., Standard_NoSuchObject): exception "
                               "type Resource_Manager could throw; the bridge (ResourceManager.swift) "
                               "uses the bool-returning Find()/accessor overloads instead",
}

ENUMS_UNWRAPPED = {
    c: "an enum nothing in the tree reads, by value or by name (confirmed: zero occurrences in "
       "Sources/OCCTBridge)"
    for c in ["Interface_CheckStatus", "Interface_DataState", "Interface_ParamType",
              "Transfer_StatusExec", "Transfer_StatusResult", "Transfer_UndefMode"]
}

TRANSFER_ACTOR_PLUMBING = {
    c: "internal Transfer-framework registration/actor plumbing STEPControl_Reader/Writer set up "
       "for themselves (via STEPControl_Controller::Init, called from the reader/writer "
       "constructor); a caller never constructs one directly to use STEP import/export"
    for c in ["STEPControl_ActorRead", "STEPControl_ActorWrite", "STEPControl_Controller"]
}
TRANSFER_ACTOR_PLUMBING.update({
    c: "internal Transfer-framework registration/actor plumbing IGESControl_Reader/Writer set up "
       "for themselves (via IGESControl_Controller::Init, called from the reader/writer "
       "constructor); a caller never constructs one directly to use IGES import/export"
    for c in ["IGESControl_ActorWrite", "IGESControl_Controller", "IGESControl_AlgoContainer",
              "IGESControl_ToolContainer", "IGESControl_IGESBoundary"]
})

OBJ_INTERNAL = {
    c: "internal OBJ-format machinery (material/MTL parsing, sub-mesh grouping, low-level file "
       "tokenising, or the abstract Poly_Triangulation-only reader) RWObj_CafReader/CafWriter "
       "(wrapped) drive internally; not something a caller reaches directly"
    for c in ["RWObj_Material", "RWObj_MtlReader", "RWObj_ObjMaterialMap", "RWObj_ObjWriterContext",
              "RWObj_Reader", "RWObj_SubMesh", "RWObj_SubMeshReason", "RWObj_Tools",
              "RWObj_TriangulationReader"]
}

GLTF_FORMAT_INTERNAL = {
    c: "low-level glTF-spec data structure or enum (accessor/buffer-view/primitive/material JSON "
       "shape, or the internal JSON parser/writer) RWGltf_CafReader/CafWriter (wrapped) build and "
       "consume internally; a CAD consumer reads/writes a glTF file through the CafReader/CafWriter "
       "facade, never these"
    for c in ["RWGltf_GltfAccessor", "RWGltf_GltfAccessorCompType", "RWGltf_GltfAccessorLayout",
              "RWGltf_GltfAlphaMode", "RWGltf_GltfArrayType", "RWGltf_GltfBufferView",
              "RWGltf_GltfBufferViewTarget", "RWGltf_GltfFace", "RWGltf_GltfJsonParser",
              "RWGltf_GltfLatePrimitiveArray", "RWGltf_GltfMaterialMap", "RWGltf_GltfOStreamWriter",
              "RWGltf_GltfPrimArrayData", "RWGltf_GltfPrimitiveMode", "RWGltf_GltfRootElement",
              "RWGltf_GltfSceneNodeMap", "RWGltf_MaterialCommon", "RWGltf_MaterialMetallicRoughness",
              "RWGltf_TriangulationReader", "RWGltf_WriterTrsfFormat"]
}

PLY_INTERNAL = {
    "RWPly_PlyWriterContext": "internal low-level PLY-file writer scratch state RWPly_CafWriter "
                              "(wrapped) drives; not constructed by a caller",
}

MESH_ABSTRACT_BASE = {
    "RWMesh_CafReader": "the abstract base RWObj_CafReader and RWGltf_CafReader (both wrapped) "
                        "inherit; not separately constructed",
    "RWMesh_ShapeIterator": "the pure-virtual base RWMesh_FaceIterator and RWMesh_VertexIterator "
                            "(both wrapped, More()/Next() declared here and overridden there) "
                            "inherit; not separately constructed",
    "RWMesh_MaterialMap": "the abstract base RWObj_ObjMaterialMap and RWGltf_GltfMaterialMap "
                          "(both internal to their own package's CafWriter, see OBJ_INTERNAL/"
                          "GLTF_FORMAT_INTERNAL above) inherit; not separately constructed",
}

MESH_INTERNAL = {
    "RWMesh_NameFormat": "an enum nothing in the tree reads (confirmed: zero occurrences in "
                         "Sources/OCCTBridge); backs the bare RWMesh package-utility's own "
                         "FormatName(), itself unwrapped (see PACKAGE_UTILITY above)",
    "RWMesh_NodeAttributes": "internal per-node visibility/transform attribute struct "
                            "RWMesh_CafReader's implementation builds while walking a mesh file "
                            "into the XDE document tree",
    "RWMesh_TriangulationReader": "internal interface RWObj_TriangulationReader and "
                                  "RWGltf_TriangulationReader (both OBJ_INTERNAL/"
                                  "GLTF_FORMAT_INTERNAL above) implement for pluggable "
                                  "triangulation loading",
    "RWMesh_TriangulationSource": "internal mesh-data wrapper for delayed (lazy) triangulation "
                                  "loading, inherits Poly_Triangulation so it can sit temporarily "
                                  "inside a TopoDS_Face during assembly construction",
}

_XSTEP_MODEL_REASON = ("internal machinery of the generic XSTEP entity/model framework "
                       "STEPControl_Reader/Writer and IGESControl_Reader/Writer (all four wrapped) "
                       "are thin facades over: file-record parsing, entity graph/dependency "
                       "tracking, deep-copy/transfer bookkeeping, or model-container storage. A "
                       "CAD consumer reaches STEP/IGES data through the Reader/Writer facade, "
                       "never these ~100 classes directly, the same shape #812 found for hidden-"
                       "line removal's own ~60 internal engine classes")

XSTEP_MODEL_INTERNAL = {c: _XSTEP_MODEL_REASON for c in [
    "Interface_BitMap", "Interface_Category", "Interface_CheckTool", "Interface_CopyControl",
    "Interface_CopyMap", "Interface_CopyTool", "Interface_EntityCluster",
    "Interface_EntityIterator", "Interface_EntityList", "Interface_FileParameter",
    "Interface_FileReaderData", "Interface_FileReaderTool", "Interface_FloatWriter",
    "Interface_GTool", "Interface_GeneralLib", "Interface_GeneralModule",
    "Interface_GlobalNodeOfGeneralLib", "Interface_GlobalNodeOfReaderLib", "Interface_Graph",
    "Interface_GraphContent", "Interface_HGraph", "Interface_IntList", "Interface_IntVal",
    "Interface_InterfaceModel", "Interface_LineBuffer", "Interface_MSG",
    "Interface_NodeOfGeneralLib", "Interface_NodeOfReaderLib", "Interface_ParamList",
    "Interface_ParamSet", "Interface_Protocol", "Interface_ReaderLib", "Interface_ReaderModule",
    "Interface_ReportEntity", "Interface_STAT", "Interface_ShareFlags", "Interface_ShareTool",
    "Interface_SignLabel", "Interface_SignType", "Interface_TypedValue",
    "Interface_UndefinedContent",
]}

_XSTEP_TRANSFER_REASON = ("internal machinery of the generic Transfer-process framework "
                          "(Binder/Finder/ActorOf.../ProcessFor... result-mapping and dispatch) "
                          "the XSTEP readers/writers drive internally to move entities between a "
                          "file model and application objects; same shape as "
                          "XSTEP_MODEL_INTERNAL above, split into its own bucket because it is a "
                          "distinct package (Transfer_ rather than Interface_)")

XSTEP_TRANSFER_INTERNAL = {c: _XSTEP_TRANSFER_REASON for c in [
    "Transfer_ActorDispatch", "Transfer_ActorOfFinderProcess", "Transfer_ActorOfProcessForFinder",
    "Transfer_ActorOfProcessForTransient", "Transfer_ActorOfTransientProcess", "Transfer_Binder",
    "Transfer_BinderOfTransientInteger", "Transfer_DataInfo", "Transfer_DispatchControl",
    "Transfer_FindHasher", "Transfer_Finder", "Transfer_FinderProcess",
    "Transfer_IteratorOfProcessForFinder", "Transfer_IteratorOfProcessForTransient",
    "Transfer_MapContainer", "Transfer_MultipleBinder", "Transfer_ProcessForFinder",
    "Transfer_ProcessForTransient", "Transfer_ResultFromModel", "Transfer_ResultFromTransient",
    "Transfer_SimpleBinderOfTransient", "Transfer_TransferDispatch", "Transfer_TransferInput",
    "Transfer_TransferIterator", "Transfer_TransferOutput", "Transfer_TransientListBinder",
    "Transfer_TransientMapper", "Transfer_TransientProcess", "Transfer_VoidBinder",
]}

BINTOOLS_INTERNAL = {
    c: "internal binary-serialisation building block BinTools_ShapeReader/ShapeWriter (both "
       "wrapped) use to store curves/surfaces/locations, or the low-level typed stream/format-"
       "version machinery they share; not something a caller constructs to read or write a shape"
    for c in ["BinTools_Curve2dSet", "BinTools_CurveSet", "BinTools_FormatVersion",
              "BinTools_IStream", "BinTools_LocationSet", "BinTools_OStream",
              "BinTools_ObjectType", "BinTools_ShapeSet", "BinTools_ShapeSetBase",
              "BinTools_SurfaceSet"]
}

RESOURCE_INTERNAL = {
    "Resource_LexicalCompare": "internal comparator functor Resource_Manager (wrapped) uses to "
                               "order its own resource-name map; not constructed by a caller",
}

REAL_CAPABILITY_GAP = {
    "RWMesh_EdgeIterator": "sibling of the wrapped RWMesh_FaceIterator/RWMesh_VertexIterator (all "
                           "three inherit RWMesh_ShapeIterator), not wrapped. No design reason "
                           "found; confirmed zero references in Sources/ and docs/, a real, small, "
                           "unaddressed gap",
    "RWGltf_DracoParameters": "Draco mesh-compression settings for glTF export; RWGltf_CafWriter "
                              "(wrapped) exposes no compression control, a real, small, "
                              "unaddressed gap",
    "Interface_Check": "per-entity fail/warning messages from a STEP or IGES read. "
                       "OCCTImportSTEPWithDiagnostics reports shape-type info, not check "
                       "messages; nothing in the tree surfaces read diagnostics at the entity "
                       "level, a real, unaddressed gap",
    "Interface_CheckIterator": "the iterator over a model's Interface_Check results (\"especially "
                               "from InterfaceModel\", its own header doc); same unaddressed gap "
                               "as Interface_Check, the two are always consumed together",
}

CURATED: dict[str, tuple[str, str]] = {}
for _table, _label in (
    (PACKAGE_UTILITY, "PACKAGE_UTILITY"),
    (DEPRECATED_COLLECTION_ALIASES, "DEPRECATED_COLLECTION_ALIASES"),
    (PRIVATE_IMPLEMENTATION, "PRIVATE_IMPLEMENTATION"),
    (CALLBACK_TYPEDEF, "CALLBACK_TYPEDEF"),
    (EXCEPTION_TYPES, "EXCEPTION_TYPES"),
    (ENUMS_UNWRAPPED, "ENUMS_UNWRAPPED"),
    (TRANSFER_ACTOR_PLUMBING, "TRANSFER_ACTOR_PLUMBING"),
    (OBJ_INTERNAL, "OBJ_INTERNAL"),
    (GLTF_FORMAT_INTERNAL, "GLTF_FORMAT_INTERNAL"),
    (PLY_INTERNAL, "PLY_INTERNAL"),
    (MESH_ABSTRACT_BASE, "MESH_ABSTRACT_BASE"),
    (MESH_INTERNAL, "MESH_INTERNAL"),
    (XSTEP_MODEL_INTERNAL, "XSTEP_MODEL_INTERNAL"),
    (XSTEP_TRANSFER_INTERNAL, "XSTEP_TRANSFER_INTERNAL"),
    (BINTOOLS_INTERNAL, "BINTOOLS_INTERNAL"),
    (RESOURCE_INTERNAL, "RESOURCE_INTERNAL"),
    (REAL_CAPABILITY_GAP, "REAL_CAPABILITY_GAP"),
):
    for _cls, _why in _table.items():
        CURATED[_cls] = (_label, _why)

# ------------------------------------------------------------------------------------------------
# Over-coverage: three findings, all fixed in this same PR (see module docstring). Recorded here so
# a regression (the wrong attribution creeping back in) is caught rather than merely once-fixed.
# ------------------------------------------------------------------------------------------------

KNOWN_OVER_FINDINGS: list[tuple[str, str]] = [
    ("docs/reference/Document-XCAF-Notes.md", "**OCCT:** `BinTools::Write`"),
    ("docs/reference/Document-XCAF-Notes.md", "**OCCT:** `BinTools::Read`"),
    ("docs/reference/Shape.md", "**OCCT:** `IGESControl_Reader::Transfer` (via `OCCTImportIGESRoot`)"),
    ("docs/reference/Shape.md", "**OCCT:** `STEPControl_Reader` with `Interface_Static` unit "
     "setting"),
]
PRESENCE_EXEMPT_PINS: list[tuple[str, str]] = []
KNOWN_OVER_FINDING_COUNT = 3  # findings 1 (2 lines, 1 root cause), 2 and 3; see docstring

REJECTED_OVER_CANDIDATES: list[tuple[str, str, str]] = [
    ("docs/API_REFERENCE.md:702", "STEPControl_Reader via=OCCTDocumentLoadSTEPProgress,"
     "OCCTImageLoad,OCCTSewingLoad [heading]",
     "the #928 detector's heading-based walker matched the generic word \"load\" to unrelated "
     "bridge functions (image/sewing, neither STEP-related); the real function, "
     "OCCTImportSTEPProgress, does construct STEPControl_Reader"),
    ("docs/reference/Document-Persistence-IO.md:1021", "RWMesh_CoordinateSystemConverter "
     "via=OCCTDocumentLoadOBJ,OCCTDocumentLoadOBJWithCS,OCCTDocumentLoadOBJWithOptions (+1) "
     "[heading]",
     "RWMesh_CoordinateSystemConverter is a private member RWObj_CafReader's base class "
     "(RWMesh_CafReader) owns, set via the public SetFileCoordinateSystem/"
     "SetSystemCoordinateSystem setters OCCTDocumentLoadOBJWithCS calls directly, not "
     "constructed by name in the named function's own body; the walker cannot follow a value "
     "behind a setter on a different class, the exact shape #812's own HLRBRep_HLRToShape false "
     "positive was"),
]

METHOD_ATTRIBUTION_ALLOWED: set[tuple[str, str]] = {
    ("Resource_Manager", "Debug"): "docs/thread-safety.md's #374 section heading, "
        "\"`Resource_Manager::Debug` / `Storage_Schema::ICurrentData()` races, fixed\", uses "
        "Class::member notation for a file-scope C++ `static bool Debug` in Resource_Manager.cxx "
        "(the .cxx implementation file, not shipped in this xcframework's Headers/, so no header "
        "check can ever confirm or deny it) -- the doc text ITSELF says so two lines below "
        "(\"a file-scope static bool\"), an accurately-described, extensively TSan-validated OCCT "
        "kernel bug (issue #374, upstream OCCT#1398), not a claim that Resource_Manager.hxx "
        "declares a member named Debug. Header-only analysis cannot see .cxx-file statics.",
}

_ATTRIBUTION_RE = re.compile(
    r"`([A-Za-z][A-Za-z0-9]*(?:_[A-Za-z0-9]+)?)::([A-Za-z_][A-Za-z0-9_]*)"
)

# ------------------------------------------------------------------------------------------------
# Measurement (identical shape to #811/#812's refman_census.py; see #812's file for the rationale
# on each choice: the token-cache inversion, the comment-prefix collapse, the wrapped-before-curated
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
    """(verdict, note, bridge hits, docs hits). See #811/#812's classify docstrings for why the
    ordering (wrapped, then curated, then documented, then under) and the gaps.md exclusion are
    both load-bearing on their own lane; `selftest_removal_matrix.py` re-proves both here. On THIS
    lane the curated-first ordering is not merely defensive: BinTools and RWMesh (the two bare
    package headers) really do have non-gaps.md doc hits, and both would misclassify as `ok` if the
    docs test ran first (see module docstring)."""
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
# Over-coverage checks (structurally identical to #811/#812's)
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
    ("STEPControl_Reader", "TransferRoot", True,
     "declared directly on STEPControl_Reader (STEPControl_Reader.hxx:108), the method "
     "OCCTImportSTEPRoot calls -- exercises the lookup path CLAUDE.md mandates with a case, not "
     "only in prose"),
    ("STEPControl_Reader", "TransferAllRoots", False,
     "a plausible-sounding name that is not declared anywhere, comments included, on "
     "STEPControl_Reader.hxx or its base XSControl_Reader.hxx: the real methods are the singular "
     "TransferRoot (an index) and the inherited TransferRoots (all of them), never "
     "\"TransferAllRoots\""),
    ("IGESControl_Reader", "TransferOneRoot", True,
     "not declared, and not even mentioned in a comment, on IGESControl_Reader.hxx itself; found "
     "only via the BASE-CLASS WALK into XSControl_Reader (XSControl_Reader.hxx:169) -- the "
     "corrected form of the #813 over-coverage finding docs now cite, replacing the never-declared "
     "`Transfer` this pass found"),
    ("STEPControl_Reader", "SetSystemLengthUnit", True,
     "declared directly on STEPControl_Reader (STEPControl_Reader.hxx:125), the method "
     "OCCTImportSTEPWithUnitProgress calls -- confirms the OTHER #813 over-coverage finding's "
     "correction (docs wrongly said \"Interface_Static unit setting\") names a real, reachable "
     "method"),
    ("Resource_Manager", "SetResource", True,
     "a real, overloaded method (int/double/string/char16_t forms), declared at "
     "Resource_Manager.hxx:98-112"),
    ("Resource_Manager", "SetValue", False,
     "a plausible-sounding name that is not declared anywhere, comments included, on "
     "Resource_Manager.hxx or its base Standard_Transient.hxx: the real setter is SetResource, "
     "not SetValue (Value() is the GETTER, an asymmetric name pair easy to get wrong)"),
    ("RWMesh_FaceIterator", "HasColor", True,
     "NOT declared on RWMesh_FaceIterator.hxx itself; found via the BASE-CLASS WALK into "
     "RWMesh_ShapeIterator, a CONCRETE (non-pure-virtual) inline method "
     "(`bool HasColor() const { return myHasColor; }`) -- proves the walk finds a concrete "
     "inherited method, not only a pure-virtual one overridden inline (which More()/Next() are, "
     "and so cannot exercise this shape: all three RWMesh_*Iterator subclasses redeclare them)"),
    ("RWMesh_FaceIterator", "HasNext", False,
     "a plausible-sounding name (common in other iterator APIs) that is not declared anywhere, "
     "comments included, on RWMesh_FaceIterator.hxx or its base RWMesh_ShapeIterator.hxx: the "
     "real predicate is More(), OCCT/Java-style, not HasNext(), Swift-style"),
    ("RWGltf_CafWriter", "myFile", True,
     "a PRIVATE DATA MEMBER (RWGltf_CafWriter.hxx, the constructor's stored output-path field), "
     "matched by neither the method-call shape (nothing follows it with `(`) nor the nested-type "
     "one"),
    ("RWGltf_CafWriter", "myFilePath", False,
     "a plausible-sounding field that is not declared anywhere, comments included, on "
     "RWGltf_CafWriter.hxx or its base Standard_Transient.hxx: the real member is the shorter "
     "myFile above. Kept as the negative, same role as #811/#812's own planted near-miss pairs"),
    ("RWGltf_CafWriter", "Hasher", True,
     "a NESTED STRUCT (`RWGltf_CafWriter::Hasher`, RWGltf_CafWriter.hxx:497), matched by neither "
     "the method-call shape (nothing follows it with `(` in its own declaration) nor the "
     "data-member one"),
    ("RWGltf_CafWriter", "Comparator", False,
     "a plausible-sounding nested-type name that is not declared anywhere, comments included, on "
     "RWGltf_CafWriter.hxx or its base Standard_Transient.hxx: the real nested types are Mesh, "
     "RWGltf_StyledShape and Hasher, never Comparator"),
    ("Interface_TypedValue", "Satisfies", True,
     "NOT declared, and not even mentioned in a comment, on Interface_TypedValue.hxx itself; "
     "found via the BASE-CLASS WALK into MoniTool_TypedValue (MoniTool_TypedValue.hxx:237), a "
     "package OUTSIDE this lane entirely -- proves the walk is not artificially restricted to "
     "lane packages"),
    ("Interface_813NoSuchClass", "Foo", None,
     "the HEADER-ABSENT `cannot say` path: no header by this name is shipped. This lane has no "
     "alias-template-shaped curated class (unlike #812's HLRBRep_CLProps/GeomLProp_CLPropsBase), "
     "so unlike #811/#812 this case exercises the mechanism directly rather than through a real "
     "curated example -- kept for the same reason #812 keeps its own lane-instance-free checks: "
     "the property under test is that the PATH exists and returns None, not that this lane has a "
     "live curated instance of it"),
    ("RWObj_CafReader", "ZZZNoSuchMember813", None,
     "the NONE-PROPAGATION path, and unlike the case above this one is real and lane-native: "
     "RWObj_CafReader (wrapped) has TWO bases, `RWMesh_CafReader` (shipped, resolves False through "
     "its own base Standard_Transient) and `RWObj_IShapeReceiver` (declared inline inside "
     "RWObj_CafReader.hxx itself, so it has no separate .hxx of its own -- confirmed absent from "
     "Libraries/OCCT.xcframework/.../Headers). The walk must return None the moment the SECOND "
     "base's header turns out missing, not silently fall through to False because the FIRST base "
     "already resolved cleanly"),
]

PARSE_SELF_TEST_CASES = [
    ("- **OCCT:** `STEPControl_Reader::TransferRoot`.",
     [("STEPControl_Reader", "TransferRoot")],
     "the plain spelling, closing backtick straight after the member"),
    ("- **OCCT:** `IGESControl_Reader::TransferOneRoot()` returns whether it succeeded.",
     [("IGESControl_Reader", "TransferOneRoot")],
     "the parenthesised spelling; a pattern anchored on the closing backtick would miss this"),
    ("`Resource_Manager::SetResource()` then `Resource_Manager::Save()`.",
     [("Resource_Manager", "SetResource"), ("Resource_Manager", "Save")],
     "two attributions on one line, so the walk is findall rather than search"),
    ("The `STEPControl_Reader` handle is returned.", [],
     "a class named with no member, which must not produce a pair"),
    ("    reader.TransferRoots();", [],
     "a real line of OCCTBridge_IO.mm using `.` not `::`, must not match"),
    ("Reached through STEPControl_Reader::TransferRoot rather than named directly.", [],
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
    ap = argparse.ArgumentParser(description="#813 refman coverage census, Export/interop lane")
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

    print(f"#813 Export/interop lane: {total} classes across {len(LANE_CLASSES)} packages")
    print(f"{'class':<45} {'verdict':<22} note")
    print("-" * 140)

    tally = {"ok": 0, "deliberate, recorded": 0, "under": 0, "over": 0}
    unders = []
    for pkg in sorted(LANE_CLASSES):
        for cls in LANE_CLASSES[pkg]:
            verdict, note, bridge, docs = classify(cls, cache)
            tally[verdict] += 1
            if verdict == "under":
                unders.append((cls, note))
            print(f"{cls:<45} {verdict:<22} {note}")
            if args.verbose:
                if bridge:
                    print(f"{'':<45} {'':<22} bridge: {', '.join(bridge)}")
                if docs:
                    print(f"{'':<45} {'':<22} docs:   {', '.join(docs)}")

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
            print("  every one resolves against the pinned headers "
                  "(NOTE: declares_member does not strip comments, so a header's OWN stale doc "
                  "comment -- e.g. IGESControl_Reader.hxx's \"reader.Transfer(num)\" prose, the "
                  "source of one #813 over-coverage finding -- can produce a false True here; this "
                  "check did not catch that finding, a hand read of the bridge call sites did, see "
                  "module docstring)")

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
            print(f"lane re-derivation: the pinned headers still give exactly these {LANE_TOTAL} "
                  "classes")

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
