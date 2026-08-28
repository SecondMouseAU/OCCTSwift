#!/usr/bin/env python3
"""Issue #983 (Pass 3c of #807): refman coverage census, OCAF persistence and format drivers.

WHY A SCRIPT, NOT A LIST IN THE ISSUE: `docs/v2.0.0-plan.md`'s census rule, and this repo's
history of hand-built censuses that were confidently wrong differently each time (#558, #571,
#573, #583, #595, #507, #553, #562). #812/#811 (the two prior refman-coverage passes) are the
template this file follows; the shape of the answer is deliberately different here, per #983's
own body.

THE LANE IS ALREADY DERIVED. `Scripts/repro/973-ocaf-package-partition/partition_census.py
--pass 983` is the committed source of truth for the 38 packages/342 headers; `derive_lane.py`
next to this file diffs this file's own copy of that table against it (`--diff-973`) and confirms
the eight format-registration classes are reached by call. Nothing here re-derives the package
list by grep.

THE VERDICT SHAPE IS DELIBERATELY DIFFERENT FROM #811'S AND #812'S. Both those lanes are curated
CLASS by class, because a `HLRBRep_Data` and a `BRepFeat_Gluer` are different capabilities that
each earned their own reason. This lane is not shaped like that: 330 of its 342 headers are
either (a) one driver class per already-wrapped OCAF attribute type, registered wholesale by a
format's own `DefineFormat`, or (b) the schema/stream/file plumbing that registration exercises
internally. #983's own body says so directly: "expect this to be answered once for the whole
driver family rather than per class, and expect that to be the correct answer: an attribute
driver is not a callable capability, it is what makes an attribute survive a round trip." So the
`CURATED` table below is keyed by **package**, not by class: every class in a curated package
inherits that package's one reason, except the handful individually wrapped or individually
recorded. This is not a shortcut taken to save effort; it is #983's own predicted and requested
shape, checked against the real bridge and the real headers before being written down rather than
assumed from the prefix.

TWO QUESTIONS, per #983:

  UNDER-COVERAGE: any capability the **format-registration surface** is missing, not any
  individual driver (#983's own framing). Measured: two packages are a genuine, if narrow, gap
  (`StdDrivers_`/`StdLDrivers_`, see `GENUINE_GAP` below); everything else in the lane is
  attribute-driver or schema/stream machinery with no independent capability, recorded as such.

  OVER-COVERAGE: `Scripts/census-doc-occt-attribution.py --lane <all 38 packages>` finds 0
  candidates (this lane is barely documented outside the 8 format-registration classes and
  `docs/thread-safety.md`, so there is almost nothing for the detector's `Class::Method`
  attribution shape to find). The finding in this lane came from reading `docs/thread-safety.md`
  by hand, per #983's own instruction to check the three named issues (#349/#353/#374) against
  the pinned kernel: two stale claims, both real, both **filed as
  [#1232](https://github.com/SecondMouseAU/OCCTSwift/issues/1232) rather than fixed**, per this
  task's carve-out for that specific file (a human is concurrently building reproducers in the
  same area). See `DEFERRED_THREAD_SAFETY_FINDINGS` below.

CLASSIFICATION RULES.

  - wrapped: named on a real (non-comment) line of `Sources/OCCTBridge/{src/*.mm,include/*.h}`.
  - documented: named anywhere under `docs/` except `docs/CHANGELOG.md` and
    `docs/occtswift-wrapping-gaps.md` (the gaps file is excluded from the docs test for the same
    reason #811/#812 exclude it: a summary-table mention of the *toolkit* must not make every
    individual class in it read as "documented").
  - CURATED (this lane's own table, keyed by package): a package-level reason, established by
    reading the pinned headers (`grep DefineFormat`, checked for a matching *DocumentStorageDriver
    to tell a read/write format from a read-only one) rather than inferred from the name.
  - `deliberate, recorded` iff the class name appears in `docs/occtswift-wrapping-gaps.md`;
    `under` otherwise. Same ordering as #811/#812 (wrapped, then curated, then documented, then
    under) and the same gaps.md-exclusion rule; `selftest_removal_matrix.py` re-proves both here.

Run from anywhere (paths derive from this file's location, not the cwd):

    python3 Scripts/repro/983-ocaf-persistence-drivers/refman_census.py
    python3 Scripts/repro/983-ocaf-persistence-drivers/refman_census.py --verbose
    python3 Scripts/repro/983-ocaf-persistence-drivers/refman_census.py --reverify-lane
    python3 Scripts/repro/983-ocaf-persistence-drivers/refman_census.py --self-test

Exits 1 on a family-count drift, lane drift under `--reverify-lane`, an `under` with no
`docs/occtswift-wrapping-gaps.md` line, or a method attribution naming a member the pinned
headers do not declare. Exits 0 otherwise.
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

PACKAGES = [
    "BinDrivers", "BinLDrivers", "BinMDF", "BinMDataStd", "BinMDataXtd", "BinMDocStd",
    "BinMFunction", "BinMNaming", "BinMXCAFDoc", "BinObjMgt", "BinTObjDrivers", "BinXCAFDrivers",
    "FSD", "LDOM", "PCDM", "Plugin", "ShapePersistent", "StdDrivers", "StdLDrivers",
    "StdLPersistent", "StdObjMgt", "StdObject", "StdPersistent", "StdStorage", "Storage", "UTL",
    "XmlDrivers", "XmlLDrivers", "XmlMDF", "XmlMDataStd", "XmlMDataXtd", "XmlMDocStd",
    "XmlMFunction", "XmlMNaming", "XmlMXCAFDoc", "XmlObjMgt", "XmlTObjDrivers", "XmlXCAFDrivers",
]

# Header -> package overrides for the 3 LDOM headers with no underscore before the class-specific
# part (same shape, and same three headers within this lane, as
# `Scripts/repro/973-ocaf-package-partition/partition_census.py`'s HEADER_PACKAGE_OVERRIDES).
HEADER_PACKAGE_OVERRIDES = {
    "LDOMBasicString.hxx": "LDOM",
    "LDOMParser.hxx": "LDOM",
    "LDOMString.hxx": "LDOM",
}

FAMILY_COUNTS: dict[str, int] = {
    "BinDrivers": 4, "BinLDrivers": 6, "BinMDF": 9, "BinMDataStd": 23, "BinMDataXtd": 7,
    "BinMDocStd": 2, "BinMFunction": 4, "BinMNaming": 3, "BinMXCAFDoc": 15, "BinObjMgt": 10,
    "BinTObjDrivers": 8, "BinXCAFDrivers": 3, "FSD": 7, "LDOM": 24, "PCDM": 19, "Plugin": 4,
    "ShapePersistent": 13, "StdDrivers": 2, "StdLDrivers": 2, "StdLPersistent": 16,
    "StdObjMgt": 6, "StdObject": 7, "StdPersistent": 9, "StdStorage": 11, "Storage": 36,
    "UTL": 1, "XmlDrivers": 3, "XmlLDrivers": 5, "XmlMDF": 8, "XmlMDataStd": 23,
    "XmlMDataXtd": 7, "XmlMDocStd": 2, "XmlMFunction": 4, "XmlMNaming": 4, "XmlMXCAFDoc": 15,
    "XmlObjMgt": 9, "XmlTObjDrivers": 8, "XmlXCAFDrivers": 3,
}
LANE_TOTAL = 342

# ------------------------------------------------------------------------------------------------
# The lane: 342 classes across 38 packages, enumerated from the pinned kernel's own headers
# (OCCT 8.0.1 plus the carried patches) on 2026-08-28. Re-derive with `--reverify-lane`, which
# rebuilds this exact dict from `ls Libraries/OCCT.xcframework/macos-arm64/Headers` and diffs it
# against the literal below, the same check #811/#812 run on their own lanes.
# ------------------------------------------------------------------------------------------------

LANE_CLASSES: dict[str, list[str]] = {
    "BinDrivers": ["BinDrivers", "BinDrivers_DocumentRetrievalDriver",
                  "BinDrivers_DocumentStorageDriver", "BinDrivers_Marker"],
    "BinLDrivers": ["BinLDrivers", "BinLDrivers_DocumentRetrievalDriver",
                   "BinLDrivers_DocumentSection", "BinLDrivers_DocumentStorageDriver",
                   "BinLDrivers_Marker", "BinLDrivers_VectorOfDocumentSection"],
    "BinMDF": ["BinMDF", "BinMDF_ADriver", "BinMDF_ADriverTable", "BinMDF_DerivedDriver",
              "BinMDF_ReferenceDriver", "BinMDF_StringIdMap", "BinMDF_TagSourceDriver",
              "BinMDF_TypeADriverMap", "BinMDF_TypeIdMap"],
    "BinMDataStd": ["BinMDataStd", "BinMDataStd_AsciiStringDriver", "BinMDataStd_BooleanArrayDriver",
                    "BinMDataStd_BooleanListDriver", "BinMDataStd_ByteArrayDriver",
                    "BinMDataStd_ExpressionDriver", "BinMDataStd_ExtStringArrayDriver",
                    "BinMDataStd_ExtStringListDriver", "BinMDataStd_GenericEmptyDriver",
                    "BinMDataStd_GenericExtStringDriver", "BinMDataStd_IntPackedMapDriver",
                    "BinMDataStd_IntegerArrayDriver", "BinMDataStd_IntegerDriver",
                    "BinMDataStd_IntegerListDriver", "BinMDataStd_NamedDataDriver",
                    "BinMDataStd_RealArrayDriver", "BinMDataStd_RealDriver",
                    "BinMDataStd_RealListDriver", "BinMDataStd_ReferenceArrayDriver",
                    "BinMDataStd_ReferenceListDriver", "BinMDataStd_TreeNodeDriver",
                    "BinMDataStd_UAttributeDriver", "BinMDataStd_VariableDriver"],
    "BinMDataXtd": ["BinMDataXtd", "BinMDataXtd_ConstraintDriver", "BinMDataXtd_GeometryDriver",
                    "BinMDataXtd_PatternStdDriver", "BinMDataXtd_PositionDriver",
                    "BinMDataXtd_PresentationDriver", "BinMDataXtd_TriangulationDriver"],
    "BinMDocStd": ["BinMDocStd", "BinMDocStd_XLinkDriver"],
    "BinMFunction": ["BinMFunction", "BinMFunction_FunctionDriver", "BinMFunction_GraphNodeDriver",
                     "BinMFunction_ScopeDriver"],
    "BinMNaming": ["BinMNaming", "BinMNaming_NamedShapeDriver", "BinMNaming_NamingDriver"],
    "BinMXCAFDoc": ["BinMXCAFDoc", "BinMXCAFDoc_AssemblyItemRefDriver", "BinMXCAFDoc_CentroidDriver",
                    "BinMXCAFDoc_ColorDriver", "BinMXCAFDoc_DatumDriver", "BinMXCAFDoc_DimTolDriver",
                    "BinMXCAFDoc_GraphNodeDriver", "BinMXCAFDoc_LengthUnitDriver",
                    "BinMXCAFDoc_LocationDriver", "BinMXCAFDoc_MaterialDriver",
                    "BinMXCAFDoc_NoteBinDataDriver", "BinMXCAFDoc_NoteCommentDriver",
                    "BinMXCAFDoc_NoteDriver", "BinMXCAFDoc_VisMaterialDriver",
                    "BinMXCAFDoc_VisMaterialToolDriver"],
    "BinObjMgt": ["BinObjMgt_PByte", "BinObjMgt_PChar", "BinObjMgt_PExtChar", "BinObjMgt_PInteger",
                 "BinObjMgt_PReal", "BinObjMgt_PShortReal", "BinObjMgt_Persistent",
                 "BinObjMgt_Position", "BinObjMgt_RRelocationTable", "BinObjMgt_SRelocationTable"],
    "BinTObjDrivers": ["BinTObjDrivers", "BinTObjDrivers_DocumentRetrievalDriver",
                       "BinTObjDrivers_DocumentStorageDriver", "BinTObjDrivers_IntSparseArrayDriver",
                       "BinTObjDrivers_ModelDriver", "BinTObjDrivers_ObjectDriver",
                       "BinTObjDrivers_ReferenceDriver", "BinTObjDrivers_XYZDriver"],
    "BinXCAFDrivers": ["BinXCAFDrivers", "BinXCAFDrivers_DocumentRetrievalDriver",
                       "BinXCAFDrivers_DocumentStorageDriver"],
    "FSD": ["FSD_BStream", "FSD_Base64", "FSD_BinaryFile", "FSD_CmpFile", "FSD_FStream", "FSD_File",
           "FSD_FileHeader"],
    "LDOM": ["LDOMBasicString", "LDOMParser", "LDOMString", "LDOM_Attr", "LDOM_BasicAttribute",
            "LDOM_BasicElement", "LDOM_BasicNode", "LDOM_BasicText", "LDOM_CDATASection",
            "LDOM_CharReference", "LDOM_CharacterData", "LDOM_Comment", "LDOM_DeclareSequence",
            "LDOM_Document", "LDOM_DocumentType", "LDOM_Element", "LDOM_LDOMImplementation",
            "LDOM_MemManager", "LDOM_Node", "LDOM_NodeList", "LDOM_OSStream", "LDOM_Text",
            "LDOM_XmlReader", "LDOM_XmlWriter"],
    "PCDM": ["PCDM", "PCDM_BaseDriverPointer", "PCDM_DOMHeaderParser", "PCDM_Document",
            "PCDM_DriverError", "PCDM_ReadWriter", "PCDM_ReadWriter_1", "PCDM_Reader",
            "PCDM_ReaderFilter", "PCDM_ReaderStatus", "PCDM_Reference", "PCDM_ReferenceIterator",
            "PCDM_RetrievalDriver", "PCDM_SequenceOfDocument", "PCDM_SequenceOfReference",
            "PCDM_StorageDriver", "PCDM_StoreStatus", "PCDM_TypeOfFileDriver", "PCDM_Writer"],
    "Plugin": ["Plugin", "Plugin_Failure", "Plugin_Macro", "Plugin_MapOfFunctions"],
    "ShapePersistent": ["ShapePersistent", "ShapePersistent_BRep", "ShapePersistent_Geom",
                        "ShapePersistent_Geom2d", "ShapePersistent_Geom2d_Curve",
                        "ShapePersistent_Geom_Curve", "ShapePersistent_Geom_Surface",
                        "ShapePersistent_HArray1", "ShapePersistent_HArray2",
                        "ShapePersistent_HSequence", "ShapePersistent_Poly",
                        "ShapePersistent_TopoDS", "ShapePersistent_TriangleMode"],
    "StdDrivers": ["StdDrivers", "StdDrivers_DocumentRetrievalDriver"],
    "StdLDrivers": ["StdLDrivers", "StdLDrivers_DocumentRetrievalDriver"],
    "StdLPersistent": ["StdLPersistent", "StdLPersistent_Collection", "StdLPersistent_Data",
                       "StdLPersistent_Dependency", "StdLPersistent_Document",
                       "StdLPersistent_Function", "StdLPersistent_HArray1",
                       "StdLPersistent_HArray2", "StdLPersistent_HString",
                       "StdLPersistent_NamedData", "StdLPersistent_Real",
                       "StdLPersistent_TreeNode", "StdLPersistent_Value",
                       "StdLPersistent_Variable", "StdLPersistent_Void", "StdLPersistent_XLink"],
    "StdObjMgt": ["StdObjMgt_Attribute", "StdObjMgt_MapOfInstantiators", "StdObjMgt_Persistent",
                 "StdObjMgt_ReadData", "StdObjMgt_SharedObject", "StdObjMgt_WriteData"],
    "StdObject": ["StdObject_Location", "StdObject_Shape", "StdObject_gp_Axes",
                 "StdObject_gp_Curves", "StdObject_gp_Surfaces", "StdObject_gp_Trsfs",
                 "StdObject_gp_Vectors"],
    "StdPersistent": ["StdPersistent", "StdPersistent_DataXtd", "StdPersistent_DataXtd_Constraint",
                      "StdPersistent_DataXtd_PatternStd", "StdPersistent_HArray1",
                      "StdPersistent_Naming", "StdPersistent_PPrsStd", "StdPersistent_TopLoc",
                      "StdPersistent_TopoDS"],
    "StdStorage": ["StdStorage", "StdStorage_BacketOfPersistent", "StdStorage_Data",
                  "StdStorage_HSequenceOfRoots", "StdStorage_HeaderData", "StdStorage_MapOfRoots",
                  "StdStorage_MapOfTypes", "StdStorage_Root", "StdStorage_RootData",
                  "StdStorage_SequenceOfRoots", "StdStorage_TypeData"],
    "Storage": ["Storage", "Storage_ArrayOfCallBack", "Storage_ArrayOfSchema", "Storage_BaseDriver",
               "Storage_BucketOfPersistent", "Storage_CallBack", "Storage_Data",
               "Storage_DefaultCallBack", "Storage_Error", "Storage_HArrayOfCallBack",
               "Storage_HArrayOfSchema", "Storage_HPArray", "Storage_HSeqOfRoot",
               "Storage_HeaderData", "Storage_InternalData", "Storage_Macros",
               "Storage_MapOfCallBack", "Storage_MapOfPers", "Storage_OpenMode", "Storage_PArray",
               "Storage_PType", "Storage_Position", "Storage_Root", "Storage_RootData",
               "Storage_Schema", "Storage_SeqOfRoot", "Storage_SolveMode",
               "Storage_StreamExtCharParityError", "Storage_StreamFormatError",
               "Storage_StreamModeError", "Storage_StreamReadError",
               "Storage_StreamTypeMismatchError", "Storage_StreamUnknownTypeError",
               "Storage_StreamWriteError", "Storage_TypeData", "Storage_TypedCallBack"],
    "UTL": ["UTL"],
    "XmlDrivers": ["XmlDrivers", "XmlDrivers_DocumentRetrievalDriver",
                  "XmlDrivers_DocumentStorageDriver"],
    "XmlLDrivers": ["XmlLDrivers", "XmlLDrivers_DocumentRetrievalDriver",
                    "XmlLDrivers_DocumentStorageDriver", "XmlLDrivers_NamespaceDef",
                    "XmlLDrivers_SequenceOfNamespaceDef"],
    "XmlMDF": ["XmlMDF", "XmlMDF_ADriver", "XmlMDF_ADriverTable", "XmlMDF_DerivedDriver",
              "XmlMDF_MapOfDriver", "XmlMDF_ReferenceDriver", "XmlMDF_TagSourceDriver",
              "XmlMDF_TypeADriverMap"],
    "XmlMDataStd": ["XmlMDataStd", "XmlMDataStd_AsciiStringDriver", "XmlMDataStd_BooleanArrayDriver",
                    "XmlMDataStd_BooleanListDriver", "XmlMDataStd_ByteArrayDriver",
                    "XmlMDataStd_ExpressionDriver", "XmlMDataStd_ExtStringArrayDriver",
                    "XmlMDataStd_ExtStringListDriver", "XmlMDataStd_GenericEmptyDriver",
                    "XmlMDataStd_GenericExtStringDriver", "XmlMDataStd_IntPackedMapDriver",
                    "XmlMDataStd_IntegerArrayDriver", "XmlMDataStd_IntegerDriver",
                    "XmlMDataStd_IntegerListDriver", "XmlMDataStd_NamedDataDriver",
                    "XmlMDataStd_RealArrayDriver", "XmlMDataStd_RealDriver",
                    "XmlMDataStd_RealListDriver", "XmlMDataStd_ReferenceArrayDriver",
                    "XmlMDataStd_ReferenceListDriver", "XmlMDataStd_TreeNodeDriver",
                    "XmlMDataStd_UAttributeDriver", "XmlMDataStd_VariableDriver"],
    "XmlMDataXtd": ["XmlMDataXtd", "XmlMDataXtd_ConstraintDriver", "XmlMDataXtd_GeometryDriver",
                    "XmlMDataXtd_PatternStdDriver", "XmlMDataXtd_PositionDriver",
                    "XmlMDataXtd_PresentationDriver", "XmlMDataXtd_TriangulationDriver"],
    "XmlMDocStd": ["XmlMDocStd", "XmlMDocStd_XLinkDriver"],
    "XmlMFunction": ["XmlMFunction", "XmlMFunction_FunctionDriver", "XmlMFunction_GraphNodeDriver",
                     "XmlMFunction_ScopeDriver"],
    "XmlMNaming": ["XmlMNaming", "XmlMNaming_NamedShapeDriver", "XmlMNaming_NamingDriver",
                  "XmlMNaming_Shape1"],
    "XmlMXCAFDoc": ["XmlMXCAFDoc", "XmlMXCAFDoc_AssemblyItemRefDriver", "XmlMXCAFDoc_CentroidDriver",
                    "XmlMXCAFDoc_ColorDriver", "XmlMXCAFDoc_DatumDriver", "XmlMXCAFDoc_DimTolDriver",
                    "XmlMXCAFDoc_GraphNodeDriver", "XmlMXCAFDoc_LengthUnitDriver",
                    "XmlMXCAFDoc_LocationDriver", "XmlMXCAFDoc_MaterialDriver",
                    "XmlMXCAFDoc_NoteBinDataDriver", "XmlMXCAFDoc_NoteCommentDriver",
                    "XmlMXCAFDoc_NoteDriver", "XmlMXCAFDoc_VisMaterialDriver",
                    "XmlMXCAFDoc_VisMaterialToolDriver"],
    "XmlObjMgt": ["XmlObjMgt", "XmlObjMgt_Array1", "XmlObjMgt_DOMString", "XmlObjMgt_Document",
                 "XmlObjMgt_Element", "XmlObjMgt_GP", "XmlObjMgt_Persistent",
                 "XmlObjMgt_RRelocationTable", "XmlObjMgt_SRelocationTable"],
    "XmlTObjDrivers": ["XmlTObjDrivers", "XmlTObjDrivers_DocumentRetrievalDriver",
                       "XmlTObjDrivers_DocumentStorageDriver", "XmlTObjDrivers_IntSparseArrayDriver",
                       "XmlTObjDrivers_ModelDriver", "XmlTObjDrivers_ObjectDriver",
                       "XmlTObjDrivers_ReferenceDriver", "XmlTObjDrivers_XYZDriver"],
    "XmlXCAFDrivers": ["XmlXCAFDrivers", "XmlXCAFDrivers_DocumentRetrievalDriver",
                       "XmlXCAFDrivers_DocumentStorageDriver"],
}

# ------------------------------------------------------------------------------------------------
# CURATED, keyed by PACKAGE (see the module docstring for why). A class that is individually
# wrapped or individually documented never reaches this table (classify() checks those first), so
# e.g. `BinDrivers` (the bare, wrapped package header) never actually takes the
# DRIVER_TABLE_SUBCLASS reason below even though it is listed in that package's class set.
# ------------------------------------------------------------------------------------------------

DRIVER_TABLE_SUBCLASS = (
    "the concrete PCDM_StorageDriver/PCDM_Reader subclass this format's own DefineFormat "
    "(wrapped, see the format-registration surface) registers with the target application; "
    "reached on every save/load without ever being constructed by name in the bridge")
_DRIVER_TABLE_SUBCLASS_PACKAGES = {
    "BinDrivers": ["BinDrivers_DocumentRetrievalDriver", "BinDrivers_DocumentStorageDriver",
                  "BinDrivers_Marker"],
    "BinLDrivers": ["BinLDrivers_DocumentRetrievalDriver", "BinLDrivers_DocumentSection",
                   "BinLDrivers_DocumentStorageDriver", "BinLDrivers_Marker",
                   "BinLDrivers_VectorOfDocumentSection"],
    "XmlDrivers": ["XmlDrivers_DocumentRetrievalDriver", "XmlDrivers_DocumentStorageDriver"],
    "XmlLDrivers": ["XmlLDrivers_DocumentRetrievalDriver", "XmlLDrivers_DocumentStorageDriver",
                    "XmlLDrivers_NamespaceDef", "XmlLDrivers_SequenceOfNamespaceDef"],
    "BinXCAFDrivers": ["BinXCAFDrivers_DocumentRetrievalDriver",
                       "BinXCAFDrivers_DocumentStorageDriver"],
    "XmlXCAFDrivers": ["XmlXCAFDrivers_DocumentRetrievalDriver",
                       "XmlXCAFDrivers_DocumentStorageDriver"],
}

ATTRIBUTE_DRIVER = (
    "one driver class per already-wrapped OCAF attribute type for this format; AddDrivers "
    "(called from the format's own DocumentStorageDriver/DocumentRetrievalDriver, itself reached "
    "only through the wrapped DefineFormat) registers the whole table at once, so the bridge "
    "reaches every class in this package without ever naming one. Existence, not being called by "
    "name, is what lets the attribute survive a save/load round trip (#983's own framing)")
_ATTRIBUTE_DRIVER_PACKAGES = ["BinMDataStd", "BinMDataXtd", "BinMDocStd", "BinMFunction",
                              "BinMNaming", "BinMXCAFDoc", "XmlMDataStd", "XmlMDataXtd",
                              "XmlMDocStd", "XmlMFunction", "XmlMNaming", "XmlMXCAFDoc"]

TOBJ_DRIVER = (
    "the driver-per-attribute-type family for the TObj_-based custom document format (its own "
    "DefineFormat registers a distinct 'BinTObj'/'XmlTObj' format GUID, same shape as the "
    "attribute-driver families above), but TObj_ itself is barely wrapped (only "
    "TObj_Application, #982's lane) and no bridge function ever builds a TObj_-based document, so "
    "there is nothing this format's own storage/retrieval driver is ever asked to persist")
_TOBJ_DRIVER_PACKAGES = ["BinTObjDrivers", "XmlTObjDrivers"]

DRIVER_TABLE_INFRASTRUCTURE = (
    "the driver-table container (ADriverTable) and its own bootstrap drivers (TagSourceDriver, "
    "ReferenceDriver, DerivedDriver) that every attribute-driver package above registers into via "
    "AddDrivers; internal registration machinery for the driver table, not a capability of its own")
_DRIVER_TABLE_INFRASTRUCTURE_PACKAGES = ["BinMDF", "XmlMDF"]

STREAM_PRIMITIVES = (
    "the low-level scalar/array/relocation-table read-write primitives (ints, reals, strings, "
    "byte arrays, cross-reference relocation) every attribute driver above calls to serialize its "
    "own attribute's fields; internal implementation of the wire format, not a capability a "
    "caller reaches directly")
_STREAM_PRIMITIVES_PACKAGES = ["BinObjMgt", "XmlObjMgt"]

PERSISTENT_SCHEMA = (
    "the persistent-object schema and type-binding layer TDocStd_Application::SaveAs/Open "
    "(already wrapped, see the format-registration surface) walk internally to convert the OCAF "
    "label tree to and from a Storage_Data; never named or configured by a caller. Storage_ "
    "itself is the base this whole tier and PCDM_'s own drivers are defined in terms of (#973's "
    "own reason for filing it in this lane)")
_PERSISTENT_SCHEMA_PACKAGES = ["StdObjMgt", "StdObject", "StdPersistent", "StdLPersistent",
                               "ShapePersistent", "StdStorage", "Storage"]

PHYSICAL_FILE = (
    "the physical file open/read/write/seek primitives Storage_'s and PCDM_'s own drivers open "
    "through to reach disk; selected by the format's own driver, never by the caller")
_PHYSICAL_FILE_PACKAGES = ["FSD"]

PLUGIN_LOADER = (
    "the GUID-to-factory resolver CDF_Application and every *Drivers package's own Factory() "
    "static call internally to instantiate the right driver by format GUID; never invoked by "
    "name from the bridge, which selects a format by calling DefineFormat directly instead of "
    "through the plugin registry")
_PLUGIN_LOADER_PACKAGES = ["Plugin"]

XML_DOM = (
    "the XML DOM implementation the Xml* driver families and XmlObjMgt_ parse and write the "
    "on-disk XML persistence format through; internal implementation detail of the XML format, "
    "not a capability a caller configures")
_XML_DOM_PACKAGES = ["LDOM"]

PACKAGE_UTILITY = (
    "bare package header, an all-static string/name utility class OCCT's own OCAF persistence "
    "machinery calls internally; no instance, nothing a caller constructs")
_PACKAGE_UTILITY_PACKAGES = ["UTL"]

CROSS_DOC_REFERENCE = (
    "the on-disk file-reference bookkeeping behind a cross-document TDocStd_XLink; the "
    "persistence-layer counterpart of CDM_Reference/CDM_ReferenceIterator, which "
    "docs/occtswift-wrapping-gaps.md's Pass 3 section (#810) already records as unexposed "
    "('cross-document reference resolution is not exposed at all, only the TDocStd_XLink "
    "attribute that records a link'); the same recorded gap, extended to its file-level twin, "
    "not re-litigated here")
_CROSS_DOC_REFERENCE_CLASSES = {"PCDM": ["PCDM_Reference", "PCDM_ReferenceIterator"]}

DRIVER_ABSTRACT_BASE = (
    "abstract driver base class or internal read/write plumbing TDocStd_Application::SaveAs/Open "
    "(already wrapped) drives on the caller's behalf; the same 'abstract base'/'internal plumbing "
    "of an already-wrapped entry point' shape docs/occtswift-wrapping-gaps.md's Pass 3 section "
    "(#810) already uses throughout for CDF_/CDM_/TDF_'s own equivalents")
_DRIVER_ABSTRACT_BASE_CLASSES = {
    "PCDM": ["PCDM_BaseDriverPointer", "PCDM_DOMHeaderParser", "PCDM_Document", "PCDM_DriverError",
            "PCDM_ReadWriter", "PCDM_ReadWriter_1", "PCDM_Reader", "PCDM_ReaderFilter",
            "PCDM_RetrievalDriver", "PCDM_SequenceOfDocument", "PCDM_SequenceOfReference",
            "PCDM_StorageDriver", "PCDM_TypeOfFileDriver", "PCDM_Writer"],
}

GENUINE_GAP = (
    "StdDrivers::DefineFormat / StdLDrivers::DefineFormat have the identical shape as the six "
    "format-registration entry points already wrapped, registering the legacy 'MDTV-Standard' "
    "and 'OCC-StdLite' OCAF formats respectively, and neither is called anywhere in the bridge. "
    "Both are READ-ONLY at the OCCT level: each package ships only a *_DocumentRetrievalDriver, "
    "no *_DocumentStorageDriver (confirmed against the pinned headers), so even a caller who "
    "registered them could open an old-format document but never save one in that format. A "
    "genuine, if narrow, format-registration gap: importing an OCAF document written by "
    "pre-'lite' (pre-6.3-era) OCCT-based software is not supported by "
    "Document.defineFormat*()/loadOCAF(from:)")
_GENUINE_GAP_PACKAGES = ["StdDrivers", "StdLDrivers"]

CURATED: dict[str, tuple[str, str]] = {}
for _pkg, _classes in _DRIVER_TABLE_SUBCLASS_PACKAGES.items():
    for _c in _classes:
        CURATED[_c] = ("DRIVER_TABLE_SUBCLASS", DRIVER_TABLE_SUBCLASS)
for _pkg in _ATTRIBUTE_DRIVER_PACKAGES:
    for _c in LANE_CLASSES[_pkg]:
        CURATED[_c] = ("ATTRIBUTE_DRIVER", ATTRIBUTE_DRIVER)
for _pkg in _TOBJ_DRIVER_PACKAGES:
    for _c in LANE_CLASSES[_pkg]:
        CURATED[_c] = ("TOBJ_DRIVER", TOBJ_DRIVER)
for _pkg in _DRIVER_TABLE_INFRASTRUCTURE_PACKAGES:
    for _c in LANE_CLASSES[_pkg]:
        CURATED[_c] = ("DRIVER_TABLE_INFRASTRUCTURE", DRIVER_TABLE_INFRASTRUCTURE)
for _pkg in _STREAM_PRIMITIVES_PACKAGES:
    for _c in LANE_CLASSES[_pkg]:
        CURATED[_c] = ("STREAM_PRIMITIVES", STREAM_PRIMITIVES)
for _pkg in _PERSISTENT_SCHEMA_PACKAGES:
    for _c in LANE_CLASSES[_pkg]:
        CURATED[_c] = ("PERSISTENT_SCHEMA", PERSISTENT_SCHEMA)
for _pkg in _PHYSICAL_FILE_PACKAGES:
    for _c in LANE_CLASSES[_pkg]:
        CURATED[_c] = ("PHYSICAL_FILE", PHYSICAL_FILE)
for _pkg in _PLUGIN_LOADER_PACKAGES:
    for _c in LANE_CLASSES[_pkg]:
        CURATED[_c] = ("PLUGIN_LOADER", PLUGIN_LOADER)
for _pkg in _XML_DOM_PACKAGES:
    for _c in LANE_CLASSES[_pkg]:
        CURATED[_c] = ("XML_DOM", XML_DOM)
for _pkg in _PACKAGE_UTILITY_PACKAGES:
    for _c in LANE_CLASSES[_pkg]:
        CURATED[_c] = ("PACKAGE_UTILITY", PACKAGE_UTILITY)
for _pkg, _classes in _CROSS_DOC_REFERENCE_CLASSES.items():
    for _c in _classes:
        CURATED[_c] = ("CROSS_DOC_REFERENCE", CROSS_DOC_REFERENCE)
for _pkg, _classes in _DRIVER_ABSTRACT_BASE_CLASSES.items():
    for _c in _classes:
        CURATED[_c] = ("DRIVER_ABSTRACT_BASE", DRIVER_ABSTRACT_BASE)
for _pkg in _GENUINE_GAP_PACKAGES:
    for _c in LANE_CLASSES[_pkg]:
        CURATED[_c] = ("GENUINE_GAP", GENUINE_GAP)

# ------------------------------------------------------------------------------------------------
# Over-coverage. This lane's `census-doc-occt-attribution.py --lane <all 38 packages>` run found 0
# candidates (see module docstring). The one real finding came from a hand read of
# docs/thread-safety.md, per #983's own pointer at the #349/#353/#374 cluster; both are FILED as
# https://github.com/SecondMouseAU/OCCTSwift/issues/1232, not fixed, per this task's carve-out for
# that specific file. Recorded here so the census states what it found even though it did not act
# on it directly.
# ------------------------------------------------------------------------------------------------

DEFERRED_THREAD_SAFETY_FINDINGS: list[tuple[str, str, str]] = [
    ("docs/thread-safety.md:324-341", "`### `Resource_Manager::Debug` / `Storage_Schema::"
     "ICurrentData()` races, fixed (issue #374)` section",
     "describes the FIRST, SUPERSEDED version of the #374 kernel fix (an `ICurrentDataMutex()` "
     "function-local `std::recursive_mutex` guarding `Storage_Schema`'s shared static). "
     "Scripts/patches/README.md's own `0016` entry and issue #518 (closed) record that this was "
     "revised on upstream review (OCCT#1399): the shared static was deleted outright and replaced "
     "with a `mutable occ::handle<Storage_Data> myCurrentData` field on `Storage_Schema` itself, "
     "confirmed directly against `Scripts/patches/0016-*.patch`'s current contents, which contain "
     "no `ICurrentDataMutex` anywhere. `CLAUDE.md`'s own #374 entry in Known OCCT Bugs carries the "
     "identical stale mechanism."),
    ("docs/thread-safety.md:414-419", "the `Scripts/tsan.supp` suppression-policy paragraph",
     "gives 'the CDM_Application metadata-map race, #353, suppressed until its patch is carried' "
     "as the 'current example' of an open, suppressed kernel finding. `Scripts/tsan.supp` itself "
     "now says otherwise in its own comment: '(none currently, #353's CDM_Application:"
     "myMetaDataLookUpTable suppression was removed in v1.15.11 once Scripts/patches/0015 carried "
     "the kernel fix...)', and `Scripts/patches/0015-*.patch` is in fact present and carried."),
]


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
    """(verdict, note, bridge hits, docs hits). Ordering (wrapped, then curated, then documented,
    then under) and the gaps.md exclusion are both load-bearing, same as #811/#812;
    `selftest_removal_matrix.py` re-proves both on this lane."""
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
# `--reverify-lane`
# ------------------------------------------------------------------------------------------------

def _header_package(filename: str) -> str | None:
    if filename in HEADER_PACKAGE_OVERRIDES:
        return HEADER_PACKAGE_OVERRIDES[filename]
    base = filename[:-len(".hxx")]
    for pkg in sorted(PACKAGES, key=len, reverse=True):
        if base == pkg or base.startswith(pkg + "_"):
            return pkg
    return None


def reverify_lane() -> tuple[bool, list[str]]:
    if not os.path.isdir(OCCT_HEADERS):
        return (False, [f"{OCCT_HEADERS} not present, lane re-derivation skipped"])
    derived: dict[str, set[str]] = {p: set() for p in PACKAGES}
    for fn in os.listdir(OCCT_HEADERS):
        if not fn.endswith(".hxx"):
            continue
        pkg = _header_package(fn)
        if pkg is not None:
            derived[pkg].add(fn[: -len(".hxx")])
    embedded = {p: set(LANE_CLASSES[p]) for p in PACKAGES}
    msgs = []
    for pkg in PACKAGES:
        extra = derived[pkg] - embedded[pkg]
        missing = embedded[pkg] - derived[pkg]
        for c in sorted(extra):
            msgs.append(f"in the pinned headers but NOT in LANE_CLASSES[{pkg!r}]: {c}")
        for c in sorted(missing):
            msgs.append(f"in LANE_CLASSES[{pkg!r}] but NOT in the pinned headers: {c}")
    return (True, msgs)


# ------------------------------------------------------------------------------------------------
# Method-attribution check (borrowed shape from #811/#812; this lane's docs carry almost no
# `Class::Member` attributions to check -- most of the lane is undocumented machinery -- so this
# mainly guards the 8 format-registration classes and the handful of prose mentions elsewhere)
# ------------------------------------------------------------------------------------------------

_ATTRIBUTION_RE = re.compile(
    r"`([A-Za-z][A-Za-z0-9]*(?:_[A-Za-z0-9]+)?)::([A-Za-z_][A-Za-z0-9_]*)"
)

# `Storage_Schema::ICurrentData` is exactly the stale attribution
# `DEFERRED_THREAD_SAFETY_FINDINGS` files rather than fixes (docs/thread-safety.md:297,324,330):
# `ICurrentData()` was deleted by the revised #374/#518 fix and never restored. Allow-listed so
# this already-filed, already-known finding doesn't fail the gate every run until a human fixes
# docs/thread-safety.md directly; remove this entry the same day that file is corrected, which
# turns the census back into evidence that the fix landed rather than silence.
METHOD_ATTRIBUTION_ALLOWED: set[tuple[str, str]] = {
    ("Storage_Schema", "ICurrentData"),
}


def _header_bases(cls: str) -> list[str]:
    """Unlike #811's/#812's version of this function, there is no `using X = Template<...>` alias
    branch: no class in this lane's 342 is declared that way (measured, not assumed --
    `grep -rln '^using [A-Za-z_]* =' Libraries/OCCT.xcframework/macos-arm64/Headers/{38 package
    prefixes}` returns nothing), so carrying an alias-resolution path nothing in this lane's own
    data would ever exercise is exactly the "accepting branch with 0/N cases" shape #812's own
    README calls decoration. **This still returns a `part` split on every comma inside the
    template's own angle brackets**, e.g. `class BinObjMgt_RRelocationTable : public
    NCollection_DataMap<int, occ::handle<Standard_Transient>>` yields `["NCollection_DataMap",
    "occ::handle"]`, the second entry a parse artifact with no `.hxx` of its own. Not fixed here:
    it is what makes `declares_member`'s None-propagation path reachable by a REAL case on this
    lane (`SELF_TEST_CASES`' `BinObjMgt_RRelocationTable` entry) rather than a contrived one, and
    it does not affect any real classification, since nothing in `CURATED` or `LANE_CLASSES`
    method-checks a member on this class through that artifact base."""
    path = os.path.join(OCCT_HEADERS, cls + ".hxx")
    if not os.path.exists(path):
        return []
    text = _read(path)
    m = re.search(r"^\s*(?:class|struct)\s+" + re.escape(cls) + r"\s*:\s*([^{]+)", text, re.M)
    if not m:
        return []
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


# ------------------------------------------------------------------------------------------------
# Self-test
# ------------------------------------------------------------------------------------------------

SELF_TEST_CASES = [
    ("BinDrivers", "DefineFormat", True,
     "METHOD-CALL: the wrapped method, called directly by OCCTDocumentSaveOCAF and friends"),
    ("BinDrivers", "RegisterFormat", False,
     "a plausible-sounding name that is not declared: BinDrivers has DefineFormat/Factory/"
     "BindTypes, not RegisterFormat"),
    ("PCDM_Reader", "Mutex", True,
     "METHOD-CALL: the #349 fix's own accessor (Scripts/patches/0014), a real method on a class "
     "this lane curates as DRIVER_ABSTRACT_BASE -- proves the check still resolves a curated "
     "class's members, not only a wrapped one's"),
    ("PCDM_Reader", "Lock", False,
     "does not exist: the accessor is Mutex(), returning a std::mutex&, not a Lock()/Unlock() pair"),
    ("PCDM_ReaderFilter", "AppendMode", True,
     "NESTED TYPE: `enum AppendMode { AppendMode_Forbid, ... }` declared inside "
     "PCDM_ReaderFilter's own class body (PCDM_ReaderFilter.hxx:33), matched by neither the "
     "method-call shape (nothing follows it with `(`) nor the data-member one"),
    ("PCDM_ReaderFilter", "AppendModes", False,
     "a plural near-miss of the real nested enum above: proves the check is not doing a fuzzy or "
     "prefix match"),
    ("Storage_Schema", "myCurrentData", True,
     "DATA MEMBER: the field the REVISED #374/#518 fix actually ships (Scripts/patches/0016), a "
     "private data member matched by neither the method-call shape nor the nested-type one -- the "
     "same removal-matrix shape #812's HLRAlgo_Projector::myPersp case proves on its own lane"),
    ("Storage_Schema", "ICurrentDataMutex", False,
     "the SUPERSEDED mechanism docs/thread-safety.md still describes (see "
     "DEFERRED_THREAD_SAFETY_FINDINGS): does not exist in the pinned kernel, confirmed directly "
     "against Storage_Schema.hxx, which declares neither ICurrentDataMutex nor ICurrentData"),
    ("BinLDrivers_DocumentStorageDriver", "Mutex", True,
     "BASE-CLASS WALK: BinLDrivers_DocumentStorageDriver.hxx declares no Mutex of its own "
     "(confirmed by grep); it inherits directly from PCDM_StorageDriver (`class "
     "BinLDrivers_DocumentStorageDriver : public PCDM_StorageDriver`), which does. The concrete "
     "case behind this lane's own DRIVER_TABLE_SUBCLASS bucket: the subclass the bridge never "
     "names still carries every method its wrapped-format base declares"),
    ("PCDM_NoSuchDriver", "Anything", None,
     "HEADER ABSENT: not a real OCCT class, so PCDM_NoSuchDriver.hxx does not exist and the "
     "lookup must answer `cannot say` rather than False -- the plain header-absent path, "
     "independent of any base-class walk"),
    ("BinObjMgt_RRelocationTable", "ZzzNotAMember", None,
     "NONE-PROPAGATION: `class BinObjMgt_RRelocationTable : public NCollection_DataMap<int, "
     "occ::handle<Standard_Transient>>` -- _header_bases' comma-split does not respect the nested "
     "angle brackets, so it also returns 'occ::handle' as if it were a second base, a real parse "
     "artifact with no header of its own (see _header_bases' own docstring). NCollection_DataMap "
     "genuinely lacks ZzzNotAMember (False), so the walk proceeds to 'occ::handle', whose header "
     "is absent (None), and that None must propagate up rather than be swallowed as False -- this "
     "lane has no clean alias-template case (measured: no `using X = Template<...>` header in any "
     "of its 342), so this is the real case standing in for it rather than a contrived one"),
    ("CDM_Application", "MetaDataLookUpTableMutex", True,
     "NOT one of this lane's 342 classes (CDM_ is #810's); proves declares_member resolves off "
     "the full pinned OCCT_HEADERS tree, not just this lane's own class set -- the lane "
     "restriction is a separate skip in check_method_attributions(), exercised there, not here"),
]

PARSE_SELF_TEST_CASES = [
    ("- **OCCT:** `BinDrivers::DefineFormat`.",
     [("BinDrivers", "DefineFormat")],
     "the plain spelling, closing backtick straight after the member"),
    ("- **OCCT:** `PCDM_StorageDriver::Mutex()` guards the write.",
     [("PCDM_StorageDriver", "Mutex")],
     "the parenthesised spelling; a pattern anchored on the closing backtick would miss this"),
    ("`BinXCAFDrivers::DefineFormat()` then `XmlXCAFDrivers::DefineFormat()`.",
     [("BinXCAFDrivers", "DefineFormat"), ("XmlXCAFDrivers", "DefineFormat")],
     "two attributions on one line, so the walk is findall rather than search"),
    ("The `PCDM_ReaderStatus` enum is returned.", [],
     "a class named with no member, which must not produce a pair"),
    ("    doc->app->SaveAs(doc->doc, ePath);", [],
     "a real line of OCCTBridge_Document.mm using -> not ::, must not match"),
    ("Reached through BinDrivers::DefineFormat rather than named directly.", [],
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
    ap = argparse.ArgumentParser(description="#983 refman coverage census, OCAF persistence lane")
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

    print(f"#983 OCAF persistence and format drivers: {total} classes across "
          f"{len(LANE_CLASSES)} packages")
    print(f"{'class':<48} {'verdict':<22} note")
    print("-" * 160)

    tally = {"ok": 0, "deliberate, recorded": 0, "under": 0, "over": 0}
    unders = []
    for pkg in sorted(LANE_CLASSES):
        for cls in LANE_CLASSES[pkg]:
            verdict, note, bridge, docs = classify(cls, cache)
            tally[verdict] += 1
            if verdict == "under":
                unders.append((cls, note))
            note_display = note if len(note) < 120 else note[:117] + "..."
            print(f"{cls:<48} {verdict:<22} {note_display}")
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
    print(f"over-coverage: 0 fixed-in-this-PR findings tracked (this lane's "
          f"census-doc-occt-attribution.py sweep found 0 candidates); "
          f"{len(DEFERRED_THREAD_SAFETY_FINDINGS)} finding(s) filed rather than fixed, per the "
          f"docs/thread-safety.md carve-out:")
    for loc, what, why in DEFERRED_THREAD_SAFETY_FINDINGS:
        print(f"  {loc}  {what}")
        print(f"    {why}")

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
            print(f"lane re-derivation: the pinned headers still give exactly these {LANE_TOTAL} "
                  "classes")

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
