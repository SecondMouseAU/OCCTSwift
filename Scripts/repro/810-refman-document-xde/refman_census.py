#!/usr/bin/env python3
"""Issue #810 (Pass 3 of #807): refman coverage census for the Document/XDE assembly lane.

Lane, per #810: `TDocStd_*`, `TDF_*`, `TDataStd_*`, `XCAFDoc_*`, `XCAFApp_*`, `CDF_*`/`CDM_*`, and
the `Document` Swift surface those sit under.

TWO DELIBERATE LANE DECISIONS, both stated here rather than discovered later.

  WIDER. #810 names seven prefixes, 188 headers. This census audits 278, adding six packages that
  no pass in #807 names at all, measured rather than assumed: a grep of all twelve sub-issue bodies
  for every OCAF/XDE-shaped prefix in the pinned headers returns them only from #810, and returns
  nothing for these six.

    - `TDataXtd_` (17) and `TNaming_` (36). Both are OCAF standard attributes on a `TDF_Label`,
      exactly like the `TDataStd_` package #810 does name, and both are partly wrapped here (14 of
      17 and 13 of 36 classes are constructed in `Sources/OCCTBridge`). `TNaming_` is also the
      mechanism `XCAFDoc_ShapeTool` is built on. Leaving them out would be #382/#384's failure
      shape, which #810's own review notes calls this programme's characteristic defect.
    - `XCAFDimTolObjects_` (23), `XCAFView_` (2), `XCAFNoteObjects_` (1). These are the payload
      types of `XCAFDoc_` attributes already in the lane: `XCAFDoc_Dimension::GetObject()` returns
      a `Handle(XCAFDimTolObjects_DimensionObject)` and nothing else, and the same holds for
      `XCAFDoc_Datum`, `XCAFDoc_GeomTolerance`, `XCAFDoc_View` and `XCAFDoc_Note`. Auditing
      `XCAFDoc_Dimension` while its only data-carrying type belongs to nobody is the same failure
      #808 named when it widened `BRep_Tool` to the whole `BRep_*` package.
    - `XCAFPrs_` (11). `XCAFPrs_DocumentExplorer`/`DocumentNode`/`Style` are wrapped and are
      document traversal and style reading, not rendering. The three presentation-only classes in
      the package (`XCAFPrs_AISObject`, `XCAFPrs_Driver`, `XCAFPrs_Texture`) are classified here
      with a note pointing at Pass 4d's AIS lane, so they are recorded rather than left in limbo.

  NARROWER, and handed off BY NAME rather than silently skipped. Forty-four further packages in the
  OCAF/persistence family, about 460 headers, are named by no pass either. They are enumerated with
  their measured bridge usage in #973 and are not audited here: they are the persistence, function
  and presentation-driver layers below the document API (`PCDM_`, `Storage_`, `Resource_`, the
  `Bin*`/`Xml*`/`Std*` driver packages, `TFunction_`, `TPrsStd_`, `TObj_`, `AppStd`/`AppStdL`).
  Auditing them properly means auditing a different surface than the one #810 describes, and
  folding 460 more headers into this table would make it a fourth again as large as #808 and #809
  combined without anyone having decided that.

WHY A SCRIPT, NOT A LIST IN THE ISSUE: `docs/v2.0.0-plan.md`'s census rule, and this repo's history
of hand-built censuses that were confidently wrong differently each time (#558, #571, #573, #583,
#595, #507, #553, #562).

TWO QUESTIONS, per #810:

  UNDER-COVERAGE: an OCCT class in the lane we neither wrap (name it on a line of
  `Sources/OCCTBridge/{src/*.mm,include/*.h}` that is neither a bare `#include` nor a comment) nor
  document (name it anywhere under `docs/` except `docs/CHANGELOG.md`, a historical record of what
  a past release changed rather than a claim about the current tree), with no reason recorded in
  `docs/occtswift-wrapping-gaps.md`.

  OVER-COVERAGE: something current docs assert that the pinned kernel does not support. Unlike
  #808 and #809, this pass did not establish it by one hand read-through. Two mechanical detectors
  ran first and every candidate either was adjudicated against the real code or is recorded here as
  a measured false positive:

    1. `Scripts/census-doc-occt-attribution.py --lane <this lane's prefixes>` (#928), the
       class-level detector. 34 candidates, 18 true, 16 false, a 47.1% false-positive rate on this
       lane against its own measured 41.0% over a uniform sample.
    2. `check_method_attributions()` in this file, which is new. #928 asks whether the CLASS a doc
       claim names is reached; it cannot see that `TNaming_Tool::SameShape` names a member the
       pinned `TNaming_Tool.hxx` does not declare, because `TNaming_Tool` itself is reached
       elsewhere. This check resolves every ``Class::Member`` attribution in the lane against that
       class's own pinned header and its ancestors. It found 17 findings #928 could not, in six
       families, and it is the reason this lane's count is 36 rather than 18.

  Both are floors. The one finding neither produced (`docs/thread-safety.md` describing document
  creation in the present tense as going through a singleton retired in #371) came from reading,
  and it is the flagship case #810's body names.

CLASSIFICATION RULES (mechanical unless a class is in one of the curated tables below, each
established during #810 by reading the pinned header, the refman via the `context` MCP at
`occt-refman@8.0.1`, and/or the real bridge call site; never inferred from the class name):

  - DEPRECATED_ALIASES: the header carries `Standard_HEADER_DEPRECATED` at file scope, which is 52
    of the 278. Note this is NOT the same test as "contains `Standard_DEPRECATED`": five wrapped,
    current classes (`TDocStd_Application`, `TDF_LabelSequence`, `TDataStd_Real`,
    `TDataStd_Variable`, `XCAFDoc_VisMaterial`) carry a per-METHOD `Standard_DEPRECATED` on one
    accessor while the class itself is live, and the file-scope test is what separates them.
  - UNDO_DELTA_RECORDS: a `TDF_AttributeDelta`/`TDF_Delta` subclass the framework produces during a
    commit. The caller reaches the whole set through `TDF_Delta`, which IS wrapped.
  - ABSTRACT_BASES: a pure virtual, or a constructor declared only after `protected:`, in the pinned
    header.
  - INTERNAL_REPRESENTATION: a concrete framework-owned storage record with no public entry point.
  - INTERNAL_HELPERS: a concrete class serving one specific already-wrapped entry point.
  - ENUMS_MIRRORED: an enum with no wrapped type name whose values the Swift surface mirrors case
    for case, checked against the pinned header's own ordinals.
  - ENUMS_UNWRAPPED: an enum nothing in the tree reads. A real capability gap.
  - COVERED_BY_SIBLING: the capability is wrapped through a different OCCT class.
  - DELIBERATE_DIVERGENCE: the pinned refman documents this as the way to do something and we
    deliberately do it another way. `XCAFApp_Application` is the only member and is the case #810
    was written around.
  - ADJACENT_LANE: in this package but belonging to another pass's subject matter, named here so it
    is recorded rather than dropped between two lanes.
  - Everything else: WRAPPED if named on a bridge line that is not a bare `#include` and not a
    comment; DOCUMENTED if named anywhere under `docs/` other than `docs/CHANGELOG.md`.

The wrapped test runs BEFORE the curated tables, following #808 rather than #809: this lane has 52
deprecated headers and two of them are genuinely called, and consulting the tables first would file
those two as `deliberate, recorded` behind a table entry claiming they have no call sites.

ONE LIMITATION, stated rather than left to be found. `deliberate, recorded` means the class NAME
appears somewhere in `docs/occtswift-wrapping-gaps.md`, not that the sentence around it is a
reason. Five of this lane's package classes (`TDF`, `TDataStd`, `TDataXtd`, `TNaming`, `XCAFDoc`)
matched that test before this pass wrote them an entry, because the file's "What's Wrapped" table
lists their toolkits by package name. #808 and #809 have the same weakness and neither says so. The
mitigation here is that every one of this lane's 160 recorded classes is named in a bullet written
by this pass and carrying its reason, so the name match and the reason coincide today; the test
still cannot tell the difference tomorrow.

Run from anywhere (paths derive from this file's location, not the cwd):

    python3 Scripts/repro/810-refman-document-xde/refman_census.py
    python3 Scripts/repro/810-refman-document-xde/refman_census.py --verbose
    python3 Scripts/repro/810-refman-document-xde/refman_census.py --reverify-lane
    python3 Scripts/repro/810-refman-document-xde/refman_census.py --self-test

Exits 1 on a `KNOWN_OVER_FINDINGS` regression, on a `DEFERRED_OVER_FINDINGS` entry that has been
fixed without being moved, on a method attribution that names a member the pinned headers do not
declare, on an `under` with no `docs/occtswift-wrapping-gaps.md` line, or on lane drift under
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

# ---------------------------------------------------------------------------------------------
# The lane: 278 classes, enumerated from the pinned kernel's own headers (OCCT 8.0.1 plus the
# carried patches, `Package.swift`'s v2.0.0 asset) on 2026-08-20. Re-derive with:
#
#   ls Libraries/OCCT.xcframework/macos-arm64/Headers \
#     | grep -E '^(TDocStd|TDF|TDataStd|TDataXtd|TNaming|XCAFDoc|XCAFApp|XCAFDimTolObjects|XCAFNoteObjects|XCAFView|XCAFPrs|CDF|CDM)(_[^.]+)?\.hxx$' \
#     | sed 's/\.hxx$//' | sort
#
# `--reverify-lane` runs exactly that derivation and diffs it against this list. A header that
# appears or disappears needs a hand audit of that class, not just a re-run: its wrapped/documented
# status is not knowable from this script.
# ---------------------------------------------------------------------------------------------

LANE_CLASSES: dict[str, list[str]] = {
    "TDocStd*": """TDocStd TDocStd_Application TDocStd_ApplicationDelta TDocStd_CompoundDelta
        TDocStd_Context TDocStd_Document TDocStd_FormatVersion TDocStd_LabelIDMapDataMap
        TDocStd_Modified TDocStd_MultiTransactionManager TDocStd_Owner TDocStd_PathParser
        TDocStd_SequenceOfApplicationDelta TDocStd_SequenceOfDocument TDocStd_XLink
        TDocStd_XLinkIterator TDocStd_XLinkPtr TDocStd_XLinkRoot TDocStd_XLinkTool""".split(),
    "TDF*": """TDF TDF_Attribute TDF_AttributeArray1 TDF_AttributeDataMap TDF_AttributeDelta
        TDF_AttributeDeltaList TDF_AttributeDoubleMap TDF_AttributeIterator TDF_AttributeList
        TDF_AttributeMap TDF_AttributeSequence TDF_ChildIDIterator TDF_ChildIterator
        TDF_ClosureMode TDF_ClosureTool TDF_ComparisonTool TDF_CopyLabel TDF_CopyTool TDF_Data
        TDF_DataSet TDF_DefaultDeltaOnModification TDF_DefaultDeltaOnRemoval TDF_Delta
        TDF_DeltaList TDF_DeltaOnAddition TDF_DeltaOnForget TDF_DeltaOnModification
        TDF_DeltaOnRemoval TDF_DeltaOnResume TDF_DerivedAttribute TDF_GUIDProgIDMap
        TDF_HAllocator TDF_HAttributeArray1 TDF_IDFilter TDF_IDList TDF_IDMap TDF_Label
        TDF_LabelDataMap TDF_LabelDoubleMap TDF_LabelIndexedMap TDF_LabelIntegerMap TDF_LabelList
        TDF_LabelMap TDF_LabelNode TDF_LabelNodePtr TDF_LabelSequence TDF_Reference
        TDF_RelocationTable TDF_TagSource TDF_Tool TDF_Transaction""".split(),
    "TDataStd*": """TDataStd TDataStd_AsciiString TDataStd_BooleanArray TDataStd_BooleanList
        TDataStd_ByteArray TDataStd_ChildNodeIterator TDataStd_Comment TDataStd_Current
        TDataStd_DataMapOfStringByte TDataStd_DataMapOfStringHArray1OfInteger
        TDataStd_DataMapOfStringHArray1OfReal TDataStd_DataMapOfStringReal
        TDataStd_DataMapOfStringString TDataStd_DeltaOnModificationOfByteArray
        TDataStd_DeltaOnModificationOfExtStringArray TDataStd_DeltaOnModificationOfIntArray
        TDataStd_DeltaOnModificationOfIntPackedMap TDataStd_DeltaOnModificationOfRealArray
        TDataStd_Directory TDataStd_Expression TDataStd_ExtStringArray TDataStd_ExtStringList
        TDataStd_GenericEmpty TDataStd_GenericExtString TDataStd_HDataMapOfStringByte
        TDataStd_HDataMapOfStringHArray1OfInteger TDataStd_HDataMapOfStringHArray1OfReal
        TDataStd_HDataMapOfStringInteger TDataStd_HDataMapOfStringReal
        TDataStd_HDataMapOfStringString TDataStd_HLabelArray1 TDataStd_IntPackedMap
        TDataStd_Integer TDataStd_IntegerArray TDataStd_IntegerList TDataStd_LabelArray1
        TDataStd_ListOfByte TDataStd_ListOfExtendedString TDataStd_Name TDataStd_NamedData
        TDataStd_NoteBook TDataStd_PtrTreeNode TDataStd_Real TDataStd_RealArray
        TDataStd_RealEnum TDataStd_RealList TDataStd_ReferenceArray TDataStd_ReferenceList
        TDataStd_Relation TDataStd_Tick TDataStd_TreeNode TDataStd_UAttribute
        TDataStd_Variable""".split(),
    "TDataXtd*": """TDataXtd TDataXtd_Array1OfTrsf TDataXtd_Axis TDataXtd_Constraint
        TDataXtd_ConstraintEnum TDataXtd_Geometry TDataXtd_GeometryEnum TDataXtd_HArray1OfTrsf
        TDataXtd_Pattern TDataXtd_PatternStd TDataXtd_Placement TDataXtd_Plane TDataXtd_Point
        TDataXtd_Position TDataXtd_Presentation TDataXtd_Shape TDataXtd_Triangulation""".split(),
    "TNaming*": """TNaming TNaming_Builder TNaming_CopyShape TNaming_DataMapOfShapePtrRefShape
        TNaming_DataMapOfShapeShapesSet TNaming_DeltaOnModification TNaming_DeltaOnRemoval
        TNaming_Evolution TNaming_Identifier TNaming_Iterator TNaming_IteratorOnShapesSet
        TNaming_ListOfIndexedDataMapOfShapeListOfShape TNaming_ListOfMapOfShape
        TNaming_ListOfNamedShape TNaming_Localizer TNaming_MapOfNamedShape
        TNaming_NCollections TNaming_Name TNaming_NameType TNaming_NamedShape TNaming_Naming
        TNaming_NamingTool TNaming_NewShapeIterator TNaming_OldShapeIterator
        TNaming_PtrAttribute TNaming_PtrNode TNaming_PtrRefShape TNaming_RefShape
        TNaming_SameShapeIterator TNaming_Scope TNaming_Selector TNaming_ShapesSet
        TNaming_Tool TNaming_TranslateTool TNaming_Translator TNaming_UsedShapes""".split(),
    "XCAFDoc*": """XCAFDoc XCAFDoc_Area XCAFDoc_AssemblyGraph XCAFDoc_AssemblyItemId
        XCAFDoc_AssemblyItemRef XCAFDoc_AssemblyIterator XCAFDoc_AssemblyTool XCAFDoc_Centroid
        XCAFDoc_ClippingPlaneTool XCAFDoc_Color XCAFDoc_ColorTool XCAFDoc_ColorType
        XCAFDoc_DataMapOfShapeLabel XCAFDoc_Datum XCAFDoc_DimTol XCAFDoc_DimTolTool
        XCAFDoc_Dimension XCAFDoc_DocumentTool XCAFDoc_Editor XCAFDoc_GeomTolerance
        XCAFDoc_GraphNode XCAFDoc_LayerTool XCAFDoc_LengthUnit XCAFDoc_Location
        XCAFDoc_Material XCAFDoc_MaterialTool XCAFDoc_Note XCAFDoc_NoteBalloon
        XCAFDoc_NoteBinData XCAFDoc_NoteComment XCAFDoc_NotesTool XCAFDoc_PartId
        XCAFDoc_ShapeMapTool XCAFDoc_ShapeTool XCAFDoc_View XCAFDoc_ViewTool
        XCAFDoc_VisMaterial XCAFDoc_VisMaterialCommon XCAFDoc_VisMaterialPBR
        XCAFDoc_VisMaterialTool XCAFDoc_Volume""".split(),
    "XCAFApp*": """XCAFApp_Application""".split(),
    "XCAFDimTolObjects*": """XCAFDimTolObjects_AngularQualifier
        XCAFDimTolObjects_DataMapOfToleranceDatum XCAFDimTolObjects_DatumModifWithValue
        XCAFDimTolObjects_DatumModifiersSequence XCAFDimTolObjects_DatumObject
        XCAFDimTolObjects_DatumSingleModif XCAFDimTolObjects_DatumTargetType
        XCAFDimTolObjects_DimensionFormVariance XCAFDimTolObjects_DimensionGrade
        XCAFDimTolObjects_DimensionModif XCAFDimTolObjects_DimensionModifiersSequence
        XCAFDimTolObjects_DimensionObject XCAFDimTolObjects_DimensionQualifier
        XCAFDimTolObjects_DimensionType XCAFDimTolObjects_GeomToleranceMatReqModif
        XCAFDimTolObjects_GeomToleranceModif XCAFDimTolObjects_GeomToleranceModifiersSequence
        XCAFDimTolObjects_GeomToleranceObject XCAFDimTolObjects_GeomToleranceType
        XCAFDimTolObjects_GeomToleranceTypeValue XCAFDimTolObjects_GeomToleranceZoneModif
        XCAFDimTolObjects_ToleranceZoneAffectedPlane XCAFDimTolObjects_Tool""".split(),
    "XCAFNoteObjects*": """XCAFNoteObjects_NoteObject""".split(),
    "XCAFView*": """XCAFView_Object XCAFView_ProjectionType""".split(),
    "XCAFPrs*": """XCAFPrs XCAFPrs_AISObject XCAFPrs_DataMapOfStyleShape
        XCAFPrs_DataMapOfStyleTransient XCAFPrs_DocumentExplorer XCAFPrs_DocumentIdIterator
        XCAFPrs_DocumentNode XCAFPrs_Driver XCAFPrs_IndexedDataMapOfShapeStyle XCAFPrs_Style
        XCAFPrs_Texture""".split(),
    "CDF*": """CDF_Application CDF_Directory CDF_DirectoryIterator CDF_FWOSDriver
        CDF_MetaDataDriver CDF_MetaDataDriverFactory CDF_Store CDF_StoreList
        CDF_StoreSetNameStatus CDF_SubComponentStatus CDF_TryStoreStatus
        CDF_TypeOfActivation""".split(),
    "CDM*": """CDM_Application CDM_CanCloseStatus CDM_Document CDM_DocumentPointer
        CDM_ListOfDocument CDM_ListOfReferences CDM_MapOfDocument CDM_MetaData
        CDM_NamesDirectory CDM_Reference CDM_ReferenceIterator""".split(),
}

LANE_HEADER_RE = re.compile(
    r"^(TDocStd|TDF|TDataStd|TDataXtd|TNaming|XCAFDoc|XCAFApp|XCAFDimTolObjects|XCAFNoteObjects"
    r"|XCAFView|XCAFPrs|CDF|CDM)(_[^.]+)?\.hxx$"
)

# The lane expressed as `--lane` prefixes for Scripts/census-doc-occt-attribution.py (#928).
# Printed by this script so the two stay in step and the #928 run is reproducible from here.
LANE_PREFIXES = (
    "TDocStd_,TDF_,TDataStd_,TDataXtd_,TNaming_,XCAFDoc_,XCAFApp_,"
    "XCAFDimTolObjects_,XCAFNoteObjects_,XCAFView_,XCAFPrs_,CDF_,CDM_"
)

# ---------------------------------------------------------------------------------------------
# Curated classifications. Each entry's reason was read out of the pinned header, the refman, or
# the bridge call site during #810; the matching `docs/occtswift-wrapping-gaps.md` entry carries
# the long form. `note` here is the short form.
# ---------------------------------------------------------------------------------------------

# 52 headers, every one carrying `Standard_HEADER_DEPRECATED` at file scope. Derived, not typed by
# hand:  grep -l Standard_HEADER_DEPRECATED  over the lane's headers.
_DEPRECATED_NOTE = (
    "deprecated since OCCT 8.0.0 at file scope; a typedef for an NCollection_* instantiation, not "
    "a distinct class."
)
DEPRECATED_ALIASES = {
    name: _DEPRECATED_NOTE
    for name in """TDocStd_LabelIDMapDataMap TDocStd_SequenceOfApplicationDelta
        TDocStd_SequenceOfDocument TDF_AttributeArray1 TDF_AttributeDataMap TDF_AttributeDeltaList
        TDF_AttributeDoubleMap TDF_AttributeList TDF_AttributeMap TDF_AttributeSequence
        TDF_DeltaList TDF_GUIDProgIDMap TDF_HAttributeArray1 TDF_IDList TDF_IDMap TDF_LabelDataMap
        TDF_LabelDoubleMap TDF_LabelIndexedMap TDF_LabelIntegerMap TDF_LabelList TDF_LabelMap
        TDF_LabelSequence TDataStd_DataMapOfStringByte TDataStd_DataMapOfStringHArray1OfInteger
        TDataStd_DataMapOfStringHArray1OfReal TDataStd_DataMapOfStringReal
        TDataStd_DataMapOfStringString TDataStd_HLabelArray1 TDataStd_LabelArray1
        TDataStd_ListOfByte TDataStd_ListOfExtendedString TDataXtd_Array1OfTrsf
        TDataXtd_HArray1OfTrsf TNaming_DataMapOfShapePtrRefShape TNaming_DataMapOfShapeShapesSet
        TNaming_ListOfIndexedDataMapOfShapeListOfShape TNaming_ListOfMapOfShape
        TNaming_ListOfNamedShape TNaming_MapOfNamedShape TNaming_NCollections
        XCAFDoc_DataMapOfShapeLabel XCAFDimTolObjects_DataMapOfToleranceDatum
        XCAFDimTolObjects_DatumModifiersSequence XCAFDimTolObjects_DimensionModifiersSequence
        XCAFDimTolObjects_GeomToleranceModifiersSequence XCAFPrs_DataMapOfStyleShape
        XCAFPrs_DataMapOfStyleTransient XCAFPrs_IndexedDataMapOfShapeStyle CDM_ListOfDocument
        CDM_ListOfReferences CDM_MapOfDocument CDM_NamesDirectory""".split()
}

# The framework's own undo/redo records. A commit produces them; `TDocStd_Document::GetUndos()`
# hands back a list of `TDF_Delta`, which IS wrapped (`OCCTDocumentCommitWithDelta` returns one and
# `TransactionDelta` reads it). Nothing constructs an individual record.
_DELTA_NOTE = (
    "an undo/redo record the framework produces during a commit; reached as a TDF_Delta through "
    "TDocStd_Document::GetUndos, which is wrapped (TransactionDelta)."
)
UNDO_DELTA_RECORDS = {
    name: _DELTA_NOTE
    for name in """TDocStd_ApplicationDelta TDocStd_CompoundDelta TDF_DefaultDeltaOnModification
        TDF_DefaultDeltaOnRemoval TDF_DeltaOnAddition TDF_DeltaOnForget TDF_DeltaOnModification
        TDF_DeltaOnRemoval TDF_DeltaOnResume TDataStd_DeltaOnModificationOfByteArray
        TDataStd_DeltaOnModificationOfExtStringArray TDataStd_DeltaOnModificationOfIntArray
        TDataStd_DeltaOnModificationOfIntPackedMap TDataStd_DeltaOnModificationOfRealArray
        TNaming_DeltaOnModification TNaming_DeltaOnRemoval""".split()
}

ABSTRACT_BASES = {
    "TDF_Attribute": "the root of every OCAF attribute; pure virtual ID()/NewEmpty()/Restore() and "
        "a constructor declared only after protected:. Every concrete attribute a caller would "
        "want is wrapped through Document's per-attribute API.",
    "TDF_AttributeDelta": "the root of the undo/redo record hierarchy; pure virtual Apply(), "
        "protected constructor.",
    "TDataStd_GenericEmpty": "an ancestor for field-less attributes, per its own header; no public "
        "constructor. Its concrete subclasses (XCAFDoc_ShapeTool, ColorTool, LayerTool and the "
        "rest of the XDE tool set) are wrapped.",
    "TDataStd_GenericExtString": "an ancestor for attributes holding one "
        "TCollection_ExtendedString, per its own header; no public constructor. TDataStd_Name, "
        "TDataStd_Comment and TDataStd_AsciiString are the wrapped concrete forms.",
    "CDM_Application": "the root of the application hierarchy; pure virtual Resources()/"
        "MessageDriver(), protected constructor. TDocStd_Application is the concrete one the "
        "bridge constructs.",
    "CDM_Document": "the root of the document hierarchy; pure virtual Update(), protected "
        "constructor. TDocStd_Document is the concrete one the bridge constructs.",
    "CDF_Application": "the session layer between CDM_Application and TDocStd_Application; its "
        "constructor is declared only after protected:, so a caller cannot build one. Every "
        "capability it declares (Open/Retrieve/Store, the reader and writer caches) is reached "
        "through TDocStd_Application, which the bridge does construct. Its header is #include'd in "
        "OCCTBridge_Document.mm and the class is never named in code.",
    "CDF_MetaDataDriver": "the per-DBMS metadata interface, per its own header (\"this class list "
        "the method that must be available for a specific DBMS\"); pure virtual, protected "
        "constructor. CDF_FWOSDriver is OCCT's own filesystem implementation and is selected by "
        "the application without the bridge naming it.",
    "CDF_MetaDataDriverFactory": "pure virtual factory for the above; no constructor at all.",
    "XCAFPrs_Driver": "a TPrsStd_Driver whose only purpose, per its own header, is to return an "
        "XCAFPrs_AISObject; no constructor. Presentation is Pass 4d's lane (#814).",
    "TDataXtd_Pattern": "pure virtual NbTrsfs()/ComputeTrsfs(); TDataXtd_PatternStd is the "
        "concrete one, and the bridge reaches it through TDataXtd_Pattern::GetID().",
}

# Framework-owned storage records with no public entry point; reached, if at all, through the
# wrapped TDF_Label / TDocStd_Document / XCAFDoc_* API.
INTERNAL_REPRESENTATION = {
    "TDF_LabelNode": "the label tree's own node record. A TDF_Label is a handle onto one; the "
        "header declares no public constructor and the whole surface is friend-only.",
    "TDF_HAllocator": "`typedef occ::handle<NCollection_BaseAllocator> TDF_HAllocator;`, the "
        "allocator handle TDF_Data hands its label nodes.",
    "TDF_LabelNodePtr": "`typedef TDF_LabelNode* TDF_LabelNodePtr;`, a raw pointer alias for the "
        "above node record.",
    "TDocStd_XLinkPtr": "`typedef TDocStd_XLink* TDocStd_XLinkPtr;`, a raw pointer alias used by "
        "TDocStd_XLinkRoot's intrusive list.",
    "TDataStd_PtrTreeNode": "`typedef TDataStd_TreeNode* TDataStd_PtrTreeNode;`, a raw pointer "
        "alias; TDataStd_TreeNode itself is wrapped.",
    "TNaming_PtrAttribute": "`typedef TNaming_NamedShape* TNaming_PtrAttribute;`, a raw pointer "
        "alias; TNaming_NamedShape itself is wrapped.",
    "TNaming_PtrNode": "`typedef TNaming_Node* TNaming_PtrNode;`, a raw pointer alias for a class "
        "that ships no header of its own at all.",
    "TNaming_PtrRefShape": "`typedef TNaming_RefShape* TNaming_PtrRefShape;`, a raw pointer alias.",
    "CDM_DocumentPointer": "`typedef CDM_Document* CDM_DocumentPointer;`, a raw pointer alias for "
        "the abstract document base.",
    "TNaming_RefShape": "the per-shape record inside TNaming_UsedShapes; no class documentation "
        "and no public entry point.",
    "TNaming_ShapesSet": "the shape set TNaming_Naming builds while resolving a name.",
    "TNaming_IteratorOnShapesSet": "the iterator over the above.",
    "TNaming_UsedShapes": "the single per-document attribute holding every shape the naming "
        "framework tracks, per its own header (\"Only one instance by Data, it always Stored as "
        "Attribute of The Root\"). Written by TNaming_Builder, which is wrapped.",
    "TDocStd_Owner": "the root-label back reference to the owning TDocStd_Document, per its own "
        "header. The bridge already holds the document handle it would recover.",
    "TDocStd_XLinkRoot": "the single root-label attribute chaining every external reference in a "
        "TDF_Data, per its own header. TDocStd_XLink, the per-reference attribute, is wrapped.",
    "XCAFDoc_PartId": "`typedef TCollection_AsciiString XCAFDoc_PartId;`, a string alias used by "
        "XCAFDoc_AssemblyItemId's path parsing.",
    "CDM_MetaData": "the per-file metadata record CDM_Application caches; the race in it is the "
        "subject of #353 and the kernel fix in patch 0015. No public constructor.",
}

INTERNAL_HELPERS = {
    "TDocStd": "the package class; two statics that print a document's contents to a stream.",
    "TDF": "the package class; one static (LowestID/UppestID bookkeeping) and no capability of "
        "its own.",
    "TDataStd": "the package class; static GUID accessors for the attributes it names, each of "
        "which is separately wrapped.",
    "TDataXtd": "the package class; static GUID accessors, same shape as TDataStd.",
    "TNaming": "the package class; static Print/Substitute helpers over the naming attributes.",
    "XCAFDoc": "the package class; static GUID accessors for the XDE attributes, each of which is "
        "separately wrapped.",
    "XCAFPrs": "the package class; statics that collect styles off a document for display.",
    "TDF_ClosureMode": "the option bag TDF_ClosureTool takes; no capability without it.",
    "TDF_ClosureTool": "builds the transitive closure of a label set, the input step of "
        "TDF_CopyTool. Reached only by constructing a TDF_DataSet the bridge does not expose.",
    "TDF_CopyTool": "the copy/paste engine behind TDF_CopyLabel, which IS wrapped "
        "(OCCTDocumentCopyLabel). Its header is #include'd in OCCTBridge_Document.mm and the "
        "class is never constructed.",
    "TDF_RelocationTable": "the source-to-target dictionary TDF_CopyTool fills; #include'd in "
        "OCCTBridge_Document.mm and never constructed, because TDF_CopyLabel owns its own.",
    "TDF_DerivedAttribute": "global registration bookkeeping for derived attribute types, per its "
        "own header (\"It is used internally by macros\").",
    "TDF_Tool": "general framework statics (Entry/Label/NbAttributes/DeepDump). #include'd in "
        "three bridge translation units and never called: the entry-string conversion the bridge "
        "needs goes through TDF_Label::EntryDump instead.",
    "TDF_Data": "the label tree root. #include'd in OCCTBridge_Document.mm and never named in "
        "code; every capability it offers (root label, transaction open/commit, delta generation) "
        "is reached through TDocStd_Document, which is wrapped.",
    "TDF_Transaction": "the RAII transaction guard. #include'd in OCCTBridge_Document.mm and "
        "never constructed; the bridge drives transactions through TDocStd_Document::"
        "OpenCommand/CommitCommand/AbortCommand instead, which is the document-level API.",
    "TDF_TagSource": "the child-tag provider. #include'd twice in OCCTBridge_Document.mm and "
        "never constructed; TDF_Label::NewChild(), which the bridge calls, is literally "
        "`TDF_TagSource::NewChild(*this)`, so the capability is reached without naming the class.",
    "TDocStd_Context": "an internal transaction-nesting context with no class documentation and no "
        "consumer in any other pinned header.",
    "TDocStd_Modified": "the root-label attribute registering modified labels. #include'd in "
        "OCCTBridge_Document.mm and never constructed; OCCTDocumentIsLabelModified reads "
        "TDocStd_Document::GetModified() instead, which is a different mechanism. The bridge "
        "header comment that says otherwise is #971.",
    "TDocStd_XLinkIterator": "iterates a document's external references. TDocStd_XLink and "
        "TDocStd_XLinkTool are both wrapped; the iterator is not, so a caller enumerates links by "
        "walking labels rather than by asking the document.",
    "TNaming_Identifier": "the naming resolver's internal per-argument identifier.",
    "TNaming_Localizer": "the naming resolver's ancestor/descendant search helper.",
    "TNaming_Name": "the resolved name TNaming_Naming stores, per its own header (\"store the "
        "arguments of Naming\"). TNaming_Naming is wrapped.",
    "TNaming_NamingTool": "statics the naming resolver calls while building a name.",
    "TNaming_TranslateTool": "copies the underlying TShape during a Transient-to-Transient "
        "translation, per its own header; TNaming_Translator, its driver, is wrapped.",
    "XCAFDoc_AssemblyTool": "generic assembly traversal statics, per its own header. "
        "XCAFDoc_AssemblyIterator and XCAFDoc_AssemblyGraph, the two traversals a caller actually "
        "asks for, are both wrapped.",
    "XCAFPrs_DocumentIdIterator": "splits a path identification string, per its own header; the "
        "bridge parses assembly paths through XCAFDoc_AssemblyItemId instead.",
    "CDF_Directory": "the per-application collection of open documents. #include'd in "
        "OCCTBridge_Document.mm and never constructed; TDocStd_Application::NbDocuments and "
        "GetDocument, both wrapped, are the read side. The race in it is #344, kernel patch 0012.",
    "CDF_DirectoryIterator": "iterates the above.",
    "CDF_Store": "the storage driver front end. The bridge calls TDocStd_Application::SaveAs/Save, "
        "which drive it; #349's kernel fix (patch 0014) is in CDF_StoreList, one level below.",
    "CDF_StoreList": "the per-store list of documents CDF_Store walks.",
    "CDF_FWOSDriver": "OCCT's own filesystem CDF_MetaDataDriver; selected by the application "
        "without any caller naming it.",
    "CDM_Reference": "the inter-document reference record.",
    "CDM_ReferenceIterator": "iterates the above. Cross-document references are not exposed: "
        "TDocStd_XLink is wrapped as an attribute, but resolving a link into a second open "
        "document is not.",
    "TDataStd_HDataMapOfStringByte": "a handle wrapper for one NCollection_DataMap instantiation, "
        "per its own header. TDataStd_NamedData, the attribute that holds these maps, is wrapped "
        "and its accessors are what a caller uses.",
    "TDataStd_HDataMapOfStringHArray1OfInteger": "handle wrapper for an NCollection_DataMap "
        "instantiation; reached through the wrapped TDataStd_NamedData.",
    "TDataStd_HDataMapOfStringHArray1OfReal": "handle wrapper for an NCollection_DataMap "
        "instantiation; reached through the wrapped TDataStd_NamedData.",
    "TDataStd_HDataMapOfStringInteger": "handle wrapper for an NCollection_DataMap instantiation; "
        "reached through the wrapped TDataStd_NamedData.",
    "TDataStd_HDataMapOfStringReal": "handle wrapper for an NCollection_DataMap instantiation; "
        "reached through the wrapped TDataStd_NamedData.",
    "TDataStd_HDataMapOfStringString": "handle wrapper for an NCollection_DataMap instantiation; "
        "reached through the wrapped TDataStd_NamedData.",
}

ENUMS_MIRRORED = {
    "TNaming_Evolution": "the Swift `NamingEvolution` mirrors all five values in order "
        "(primitive/generated/modify/delete/replace/selected as declared); the bridge passes the "
        "ordinal through without naming the type.",
    "XCAFDoc_ColorType": "the Swift `ColorType` mirrors all four values in order "
        "(generic/surface/curve/emission).",
    "XCAFView_ProjectionType": "the Swift `ViewObject.ProjectionType` mirrors both values in "
        "order (noCamera/parallel/central).",
    "XCAFDimTolObjects_DimensionType": "the Swift `DimensionInfo.type` carries the raw ordinal, "
        "documented as such rather than re-declared as a Swift enum.",
    "XCAFDimTolObjects_GeomToleranceType": "the Swift `GeomToleranceInfo.type` carries the raw "
        "ordinal, documented as such.",
    "TDataXtd_ConstraintEnum": "the Swift `ConstraintType` mirrors the constraint kinds the "
        "wrapped TDataXtd_Constraint accepts.",
    "TDataXtd_GeometryEnum": "the Swift `GeometryType` mirrors the values the wrapped "
        "TDataXtd_Geometry classifies.",
}

ENUMS_UNWRAPPED = {
    "TDocStd_FormatVersion": "the OCAF document format version. The bridge sets a storage format "
        "by name (BinOcaf/XmlOcaf/BinXCAF/...) and never selects a version, so writing an OLDER "
        "document version is not exposed, the same shape as TopTools_FormatVersion in #808.",
    "TDataStd_RealEnum": "the unit-of-measure tag on a TDataStd_Real. Its own header marks every "
        "value as obsolete bookkeeping and the attribute is wrapped without it.",
    "TNaming_NameType": "the naming resolver's rule kind. TNaming_Naming is wrapped as an opaque "
        "attribute; which rule resolved a name is not surfaced.",
    "CDF_StoreSetNameStatus": "CDF_Store::SetName's status. The bridge calls "
        "TDocStd_Application::SaveAs, which reports PCDM_StoreStatus instead, and that IS wrapped "
        "(StoreStatus).",
    "CDF_SubComponentStatus": "CDF_Store's per-referenced-document status; reachable only by "
        "driving CDF_Store directly.",
    "CDF_TryStoreStatus": "CDF_Store::Realize's status; same.",
    "CDF_TypeOfActivation": "how a referenced document was activated on open; cross-document "
        "reference resolution is not exposed at all (see CDM_ReferenceIterator).",
    "CDM_CanCloseStatus": "TDocStd_Document::CanClose's verdict. The bridge closes documents "
        "unconditionally and drops the reason.",
    "XCAFDimTolObjects_AngularQualifier": "one of thirteen GD&T qualifier/modifier enums. The "
        "bridge reads a dimension's type, value and tolerance bounds and does not surface its "
        "qualifiers or modifiers; doing so is a public API addition rather than a wrap.",
    "XCAFDimTolObjects_DatumModifWithValue": "GD&T datum modifier with a value; same.",
    "XCAFDimTolObjects_DatumSingleModif": "GD&T datum modifier; same.",
    "XCAFDimTolObjects_DatumTargetType": "GD&T datum target kind; same.",
    "XCAFDimTolObjects_DimensionFormVariance": "ISO 286 form variance; same.",
    "XCAFDimTolObjects_DimensionGrade": "ISO 286 tolerance grade; same.",
    "XCAFDimTolObjects_DimensionModif": "GD&T dimension modifier; same.",
    "XCAFDimTolObjects_DimensionQualifier": "GD&T dimension qualifier; same.",
    "XCAFDimTolObjects_GeomToleranceMatReqModif": "GD&T material requirement; same.",
    "XCAFDimTolObjects_GeomToleranceModif": "GD&T geometric tolerance modifier; same.",
    "XCAFDimTolObjects_GeomToleranceTypeValue": "GD&T tolerance value kind; same.",
    "XCAFDimTolObjects_GeomToleranceZoneModif": "GD&T tolerance zone modifier; same.",
    "XCAFDimTolObjects_ToleranceZoneAffectedPlane": "GD&T affected plane; same.",
}

COVERED_BY_SIBLING = {
    "TDocStd_PathParser": "deliberately removed, not merely unwrapped. #499 unified the bridge's "
        "four path parsers onto OSD_Path, and OCCTBridge_IO.h records why: "
        "TDocStd_PathParser::Parse() is wrong outright for extension-less paths. The header is "
        "#include'd nowhere and only the two comments explaining the removal name it.",
    "TDocStd_MultiTransactionManager": "synchronises one transaction across several documents. "
        "The bridge drives transactions per document through TDocStd_Document, so the manager's "
        "single-document behaviour is already covered; its NAMED-transaction API is the one thing "
        "it has that the document API does not, and that gap is #970.",
    "XCAFDoc_View": "the per-view attribute. XCAFView_Object, the value type it stores, IS "
        "wrapped (ViewObject), and the bridge reads and writes views through that; the attribute "
        "wrapper itself is never constructed.",
    "XCAFDoc_ViewTool": "the document-level view table. Same: the wrapped surface is "
        "XCAFView_Object, and views are reached by label rather than through the tool.",
}

DELIBERATE_DIVERGENCE = {
    "XCAFApp_Application": "NOT USED, on purpose, and the pinned refman says the opposite. "
        "XCAFApp_Application.hxx's own comment on GetApplication() reads \"This is the only valid "
        "method to get XCAFApp_Application object, and it should be called at least once before "
        "any actions with documents\", and its constructor is protected, so that static IS the "
        "only way to obtain one. #371 retired it bridge-side anyway: OCCTDocument's constructor "
        "does `app = new TDocStd_Application()`. The reason is measured, not stylistic. The "
        "process-wide singleton is what made #341, #344, #349 and #353 reachable at all, and "
        "upstream maintainer gkv311's review of OCCT#1396 states that GetApplication() \"exists "
        "solely for compatibility reasons\" and that OCCT's own guidance since 7.1 is a private "
        "TDocStd_Application per caller. The class is named in one bridge comment explaining the "
        "history and is constructed nowhere.",
}

ADJACENT_LANE = {
    "XCAFPrs_AISObject": "an AIS_ColoredShape presenting an XDE document. Display is Pass 4d's "
        "lane (#814); OCCTSwift's own display surface renders a Shape rather than a document, so "
        "nothing in the bridge builds one.",
    "XCAFPrs_Texture": "a Graphic3d_Texture2D holding an XDE texture. Pass 4d (#814) owns "
        "Graphic3d_*; the bridge reads XCAFDoc_VisMaterial's texture paths as strings instead.",
}

CURATED_TABLES = [
    ("deprecated alias", DEPRECATED_ALIASES),
    ("undo/redo delta record", UNDO_DELTA_RECORDS),
    ("abstract base", ABSTRACT_BASES),
    ("internal representation", INTERNAL_REPRESENTATION),
    ("internal helper", INTERNAL_HELPERS),
    ("enum, values mirrored", ENUMS_MIRRORED),
    ("enum, unwrapped", ENUMS_UNWRAPPED),
    ("covered by sibling", COVERED_BY_SIBLING),
    ("deliberate divergence from the refman", DELIBERATE_DIVERGENCE),
    ("adjacent lane", ADJACENT_LANE),
]

# ---------------------------------------------------------------------------------------------
# Confirmed over-coverage findings (#810), each fixed in the same PR that adds this script.
# `bad_phrase` is the wrong text that used to appear in `doc_file`; this script exits 1 if it ever
# reappears, and reports the finding as fixed otherwise. Whitespace is collapsed on both sides, so
# a re-wrap of the same wrong sentence still counts as a regression.
#
# Thirty-six findings in six families.
#
# THE APPLICATION FAMILY (7). Four claims name `XCAFApp_Application`, which #371 retired
# bridge-side and which the pinned header's own comment insists is the only way to get one; three
# name `CDF_Application`, which declares none of `NbDocuments`/`ReadingFormats`/`WritingFormats`.
# All seven run on `TDocStd_Application`. This is the case #810 was written around, and the
# `XCAFApp_Application` entry in DELIBERATE_DIVERGENCE above carries the reasoning.
#
# THE TRANSACTION FAMILY (3). `TDocStd_Document::NewCommand`, `TDF_Data::Transaction` and
# `TDF_Transaction::Commit` for three methods that run `OpenCommand`, `HasOpenCommand` and
# `CommitCommand` on the document. Two of the three also described behaviour the code does not
# deliver, which is #970.
#
# THE NAMING FAMILY (6). `TNaming_Tool::SameShape` twice for a `TNaming_SameShapeIterator` walk,
# and `TNaming_Tool` has no such member at all; `TNaming_Tool::GeneratedShape` and a bare
# `TNaming_Tool` for two `TNaming_NewShapeIterator`/`OldShapeIterator` walks;
# `TNaming_Builder::Select` for `TNaming_Selector::Select`, which is a different operation (the
# builder records a raw select pair, the selector computes a resolvable name);
# `TNaming_NamedShape::Get`/`TNaming_Iterator` for `TNaming_Tool::OriginalShape`.
#
# THE SPELLED-WRONG ACCESSOR FAMILY (14). A member name that does not exist beside one that does:
# `GetColor`/`GetTransparency`/`GetWidth`/`GetMode` for `TDataXtd_Presentation`'s `Color`/
# `Transparency`/`Width`/`Mode`; `SetExpressionString`/`GetExpressionString` for
# `TDataStd_Expression`'s `SetExpression`/`GetExpression`; four `TDocStd_XLink` Get/Set spellings
# for its two overloaded `DocumentEntry`/`LabelEntry`; `TNaming_Scope::Clear` for `ClearValid`;
# `TDataXtd_PatternStd::SetSignature` for `Signature`; `XCAFDoc_AssemblyItemRef::RemoveExtraRef`
# for `ClearExtraRef`; `XCAFDoc_ShapeMapTool::Map` for `GetMap`, which the strict first version of
# `_ATTRIBUTION_RE` skipped because the claim is written `Map().Extent()` and the pattern was
# anchored on a closing backtick.
#
# THE WRONG-CLASS-ENTIRELY FAMILY (5). `TDF_LabelSequence` for a `TDF_ChildIterator` walk;
# `XCAFDoc_AssemblyGraph::NbRoots` for `GetRoots().Extent()`;
# `XCAFDoc_AssemblyItemId::GetPathLength` for `GetPath().Size()`;
# `XCAFDoc_AssemblyItemRef::GetPath` for `GetItem()` plus `XCAFDoc_AssemblyItemId::ToString()`.
#
# A BEHAVIOUR CLAIM CONTRADICTED BY OUR OWN TREE (1). `docs/thread-safety.md` said, in the present
# tense, that every document-producing call goes through one process-wide `XCAFApp_Application`
# singleton. It did until v1.15.17. The same file's own #371 section, 130 lines further down, says
# so.
#
# Every finding was confirmed by reading the Swift method, following it to its bridge function, and
# reading that function's body, per okf/policies/measure-dont-assume.md.
#
# THE SIX COUNTS ABOVE ARE DERIVED, NOT TYPED. `FAMILY_COUNTS` below repeats them as data and
# `main()` asserts each against the table, because a hand-written total beside a list is exactly
# what CLAUDE.md's own patch-count paragraph warns about: a total and a list disagree silently and
# the total is the one everybody reads. Two of these were wrong when written by hand, in a prose
# block that had been read three times.
# ---------------------------------------------------------------------------------------------

FAMILY_COUNTS = {
    "application": 7,
    "transaction": 3,
    "naming": 6,
    "accessor spelling": 14,
    "wrong class": 5,
    "behaviour": 1,
}

KNOWN_OVER_FINDINGS = [
    # --- the application family ---
    {
        "family": "application",
        "subject": "Document.saveOCAF(to:)",
        "doc_file": "docs/reference/Document-Persistence-IO.md",
        "bad_phrase": "- **OCCT:** `XCAFApp_Application::SaveAs` / `PCDM_StoreStatus`.",
        "correct": "TDocStd_Application::SaveAs. XCAFApp_Application is not constructed anywhere "
            "in the bridge (#371).",
    },
    {
        "family": "application",
        "subject": "Document.saveOCAFInPlace()",
        "doc_file": "docs/reference/Document-Persistence-IO.md",
        "bad_phrase": "- **OCCT:** `XCAFApp_Application::Save`.",
        "correct": "TDocStd_Application::Save.",
    },
    {
        "family": "application",
        "subject": "Document.loadOCAF(from:)",
        "doc_file": "docs/reference/Document-Persistence-IO.md",
        "bad_phrase": "- **OCCT:** `XCAFApp_Application::Open` (with `BinDrivers`, `XmlDrivers`, "
            "`BinXCAFDrivers`, `XmlXCAFDrivers` registered).",
        "correct": "TDocStd_Application::Open, on a private application instance per document.",
    },
    {
        "family": "application",
        "subject": "Document.create(format:)",
        "doc_file": "docs/reference/Document-Persistence-IO.md",
        "bad_phrase": "- **OCCT:** `XCAFApp_Application::NewDocument`.",
        "correct": "TDocStd_Application::NewDocument.",
    },
    {
        "family": "application",
        "subject": "Document.documentCount",
        "doc_file": "docs/reference/Document-Persistence-IO.md",
        "bad_phrase": "- **OCCT:** `CDF_Application::NbDocuments`.",
        "correct": "TDocStd_Application::NbDocuments. CDF_Application does not declare it.",
    },
    {
        "family": "application",
        "subject": "Document.readingFormats",
        "doc_file": "docs/reference/Document-Persistence-IO.md",
        "bad_phrase": "- **OCCT:** `CDF_Application::ReadingFormats`.",
        "correct": "TDocStd_Application::ReadingFormats, named as a member pointer in the bridge.",
    },
    {
        "family": "application",
        "subject": "Document.writingFormats",
        "doc_file": "docs/reference/Document-Persistence-IO.md",
        "bad_phrase": "- **OCCT:** `CDF_Application::WritingFormats`.",
        "correct": "TDocStd_Application::WritingFormats, named as a member pointer in the bridge.",
    },
    # --- the transaction family ---
    {
        "family": "transaction",
        "subject": "Document.openNamedTransaction(_:)",
        "doc_file": "docs/reference/Document-OCAF-Attributes.md",
        "bad_phrase": "- **OCCT:** `TDocStd_Document::NewCommand` + `TDF_Transaction::Open`.",
        "correct": "TDocStd_Document::OpenCommand + HasOpenCommand. The name argument is dropped "
            "(#970).",
    },
    {
        "family": "transaction",
        "subject": "Document.transactionNumber",
        "doc_file": "docs/reference/Document-OCAF-Attributes.md",
        "bad_phrase": "- **OCCT:** `TDF_Data::Transaction`.",
        "correct": "TDocStd_Document::HasOpenCommand, returning 1 or 0 rather than a nesting "
            "depth (#970).",
    },
    {
        "family": "transaction",
        "subject": "Document.commitWithDelta()",
        "doc_file": "docs/reference/Document-OCAF-Attributes.md",
        "bad_phrase": "- **OCCT:** `TDF_Transaction::Commit`.",
        "correct": "TDocStd_Document::CommitCommand plus GetUndos().Last().",
    },
    # --- the naming family ---
    {
        "family": "naming",
        "subject": "Document.namingOriginalShape(on:)",
        "doc_file": "docs/reference/Document-OCAF-Attributes.md",
        "bad_phrase": "- **OCCT:** `TNaming_NamedShape::Get` / `TNaming_Iterator`.",
        "correct": "TNaming_Tool::OriginalShape on the label's TNaming_NamedShape.",
    },
    {
        "family": "naming",
        "subject": "Document.sameShapeCount(shape:)",
        "doc_file": "docs/reference/Document-OCAF-Attributes.md",
        "bad_phrase": "- **OCCT:** `TNaming_Tool::SameShape` count variant.",
        "correct": "TNaming_SameShapeIterator. TNaming_Tool declares no SameShape member.",
    },
    {
        "family": "naming",
        "subject": "Document.sameShapeLabels(shape:)",
        "doc_file": "docs/reference/Document-OCAF-Attributes.md",
        "bad_phrase": "- **OCCT:** `TNaming_Tool::SameShape`.",
        "correct": "TNaming_SameShapeIterator. TNaming_Tool declares no SameShape member.",
    },
    {
        "family": "naming",
        "subject": "Document.tracedForward(from:scope:)",
        "doc_file": "docs/reference/Document.md",
        "bad_phrase": "- **OCCT:** `TNaming_Tool::GeneratedShape` / forward-tracing "
            "(via `OCCTDocumentNamingTraceForward`).",
        "correct": "TNaming_NewShapeIterator, via OCCTDocumentNamingTraceForward.",
    },
    {
        "family": "naming",
        "subject": "Document.tracedBackward(from:scope:)",
        "doc_file": "docs/reference/Document.md",
        "bad_phrase": "- **OCCT:** `TNaming_Tool` backward-tracing "
            "(via `OCCTDocumentNamingTraceBackward`).",
        "correct": "TNaming_OldShapeIterator, via OCCTDocumentNamingTraceBackward.",
    },
    {
        "family": "naming",
        "subject": "Document.selectShape(_:context:on:)",
        "doc_file": "docs/reference/Document.md",
        "bad_phrase": "- **OCCT:** `TNaming_Builder::Select` (via `OCCTDocumentNamingSelect`).",
        "correct": "TNaming_Selector::Select. TNaming_Builder::Select exists but records a raw "
            "select pair rather than computing a resolvable name.",
    },
    # --- the spelled-wrong accessor family ---
    {
        "family": "accessor spelling",
        "subject": "Document.presentationGetColor(labelId:)",
        "doc_file": "docs/reference/Document-OCAF-Attributes.md",
        "bad_phrase": "- **OCCT:** `TDataXtd_Presentation::GetColor`.",
        "correct": "TDataXtd_Presentation::Color, guarded by HasOwnColor.",
    },
    {
        "family": "accessor spelling",
        "subject": "Document.presentationGetTransparency(labelId:)",
        "doc_file": "docs/reference/Document-OCAF-Attributes.md",
        "bad_phrase": "- **OCCT:** `TDataXtd_Presentation::GetTransparency`.",
        "correct": "TDataXtd_Presentation::Transparency, guarded by HasOwnTransparency.",
    },
    {
        "family": "accessor spelling",
        "subject": "Document.presentationGetWidth(labelId:)",
        "doc_file": "docs/reference/Document-OCAF-Attributes.md",
        "bad_phrase": "- **OCCT:** `TDataXtd_Presentation::GetWidth`.",
        "correct": "TDataXtd_Presentation::Width, guarded by HasOwnWidth.",
    },
    {
        "family": "accessor spelling",
        "subject": "Document.presentationGetMode(labelId:)",
        "doc_file": "docs/reference/Document-OCAF-Attributes.md",
        "bad_phrase": "- **OCCT:** `TDataXtd_Presentation::GetMode`.",
        "correct": "TDataXtd_Presentation::Mode, guarded by HasOwnMode.",
    },
    {
        "family": "accessor spelling",
        "subject": "Document.namingScopeClear()",
        "doc_file": "docs/reference/Document-OCAF-Attributes.md",
        "bad_phrase": "- **OCCT:** `TNaming_Scope::Clear`.",
        "correct": "TNaming_Scope::ClearValid.",
    },
    {
        "family": "accessor spelling",
        "subject": "Document.setExpressionString(_:at:)",
        "doc_file": "docs/reference/Document-XCAF-Notes.md",
        "bad_phrase": "- **OCCT:** `TDataStd_Expression::SetExpressionString`",
        "correct": "TDataStd_Expression::SetExpression.",
    },
    {
        "family": "accessor spelling",
        "subject": "Document.expressionString(at:)",
        "doc_file": "docs/reference/Document-XCAF-Notes.md",
        "bad_phrase": "- **OCCT:** `TDataStd_Expression::GetExpressionString`",
        "correct": "TDataStd_Expression::GetExpression.",
    },
    {
        "family": "accessor spelling",
        "subject": "Document.setXLinkDocumentEntry(_:at:)",
        "doc_file": "docs/reference/Document-XCAF-Notes.md",
        "bad_phrase": "- **OCCT:** `TDocStd_XLink::SetDocumentEntry`",
        "correct": "TDocStd_XLink::DocumentEntry(entry), the setter overload.",
    },
    {
        "family": "accessor spelling",
        "subject": "Document.xLinkDocumentEntry(at:)",
        "doc_file": "docs/reference/Document-XCAF-Notes.md",
        "bad_phrase": "- **OCCT:** `TDocStd_XLink::GetDocumentEntry`",
        "correct": "TDocStd_XLink::DocumentEntry(), the getter overload.",
    },
    {
        "family": "accessor spelling",
        "subject": "Document.setXLinkLabelEntry(_:at:)",
        "doc_file": "docs/reference/Document-XCAF-Notes.md",
        "bad_phrase": "- **OCCT:** `TDocStd_XLink::SetLabelEntry`",
        "correct": "TDocStd_XLink::LabelEntry(entry), the setter overload.",
    },
    {
        "family": "accessor spelling",
        "subject": "Document.xLinkLabelEntry(at:)",
        "doc_file": "docs/reference/Document-XCAF-Notes.md",
        "bad_phrase": "- **OCCT:** `TDocStd_XLink::GetLabelEntry`",
        "correct": "TDocStd_XLink::LabelEntry(), the getter overload.",
    },
    {
        "family": "accessor spelling",
        "subject": "Document.patternSetSignature(labelId:signature:)",
        "doc_file": "docs/reference/Document-Math-Bounds.md",
        "bad_phrase": "- **OCCT:** `TDataXtd_PatternStd::SetSignature` "
            "(via `OCCTDocumentPatternSetSignature`).",
        "correct": "TDataXtd_PatternStd::Signature, via OCCTDocumentPatternSetSignature.",
    },
    {
        "family": "accessor spelling",
        "subject": "Document.assemblyItemRefClearExtra(labelId:)",
        "doc_file": "docs/reference/Document-Math-Bounds.md",
        "bad_phrase": "- **OCCT:** `XCAFDoc_AssemblyItemRef::RemoveExtraRef` "
            "(via `OCCTDocumentAssemblyItemRefClearExtra`).",
        "correct": "XCAFDoc_AssemblyItemRef::ClearExtraRef, via "
            "OCCTDocumentAssemblyItemRefClearExtra.",
    },
    # --- the wrong-class-entirely family ---
    {
        "family": "wrong class",
        "subject": "AssemblyNode.descendants(allLevels:)",
        "doc_file": "docs/reference/Document.md",
        "bad_phrase": "- **OCCT:** `TDF_LabelSequence` recursive traversal "
            "(via `OCCTDocumentGetDescendantLabels`).",
        "correct": "TDF_ChildIterator(label, allLevels), via OCCTDocumentGetDescendantLabels.",
    },
    {
        "family": "accessor spelling",
        "subject": "AssemblyNode.shapeMapToolExtent",
        "doc_file": "docs/reference/Document-XCAF-Notes.md",
        "bad_phrase": "- **OCCT:** `XCAFDoc_ShapeMapTool::Map().Extent()`",
        "correct": "XCAFDoc_ShapeMapTool::GetMap().Extent(). There is no Map member. Found only "
            "after this file's attribution pattern was widened to see a parenthesised claim; see "
            "the note on _ATTRIBUTION_RE.",
    },
    {
        "family": "wrong class",
        "subject": "AssemblyGraph.rootCount",
        "doc_file": "docs/reference/Document-XCAF-Notes.md",
        "bad_phrase": "- **OCCT:** `XCAFDoc_AssemblyGraph::NbRoots`",
        "correct": "XCAFDoc_AssemblyGraph::GetRoots().Extent(). There is no NbRoots.",
    },
    {
        "family": "wrong class",
        "subject": "AssemblyItemId.pathCount",
        "doc_file": "docs/reference/Document-XCAF-Notes.md",
        "bad_phrase": "- **OCCT:** `XCAFDoc_AssemblyItemId::GetPathLength`",
        "correct": "XCAFDoc_AssemblyItemId::GetPath().Size(). There is no GetPathLength.",
    },
    {
        "family": "wrong class",
        "subject": "Document.assemblyItemRefPath(labelId:)",
        "doc_file": "docs/reference/Document-Math-Bounds.md",
        "bad_phrase": "- **OCCT:** `XCAFDoc_AssemblyItemRef::GetPath` "
            "(via `OCCTDocumentGetAssemblyItemRef`).",
        "correct": "XCAFDoc_AssemblyItemRef::GetItem() plus XCAFDoc_AssemblyItemId::ToString(), "
            "via OCCTDocumentGetAssemblyItemRef.",
    },
    {
        "family": "wrong class",
        "subject": "Document.hasPattern(labelId:)",
        "doc_file": "docs/reference/Document-Math-Bounds.md",
        "bad_phrase": "- **OCCT:** `TDataXtd_PatternStd::Find` (via `OCCTDocumentHasPattern`).",
        "correct": "TDF_Label::FindAttribute(TDataXtd_Pattern::GetID()), via "
            "OCCTDocumentHasPattern. TDataXtd_PatternStd has no Find.",
    },
    # --- a behaviour claim contradicted by our own tree ---
    {
        "family": "behaviour",
        "subject": "docs/thread-safety.md, document creation section",
        "doc_file": "docs/thread-safety.md",
        "bad_phrase": "Every one of these calls goes through a single process-wide "
            "`XCAFApp_Application` singleton (`XCAFApp_Application::GetApplication()`), so two "
            "kernel fixes were needed, both in OCCT itself, not the bridge:",
        "correct": "Past tense, with a forward pointer to the same file's #371 section: every such "
            "call went through the singleton until v1.15.17, which is why the two kernel fixes "
            "below were needed.",
    },
]

# ---------------------------------------------------------------------------------------------
# Over-coverage found by #810 and deliberately NOT fixed in its PR, each with the issue that owns
# it. Unlike KNOWN_OVER_FINDINGS, the check here is INVERTED: the bad text must still be present.
# A deferred finding that has quietly been fixed without moving to KNOWN_OVER_FINDINGS is a census
# that has stopped describing the tree, which is the failure this whole programme exists to catch,
# so it exits 1 and says which entry to move.
# ---------------------------------------------------------------------------------------------

DEFERRED_OVER_FINDINGS = [
    {
        "subject": "OCCTDocumentIsLabelModified",
        "doc_file": "Sources/OCCTBridge/include/OCCTBridge_Document.h",
        "bad_phrase": "/// Check if a label is marked as modified (via TDocStd_Modified on root).",
        "correct": "The function reads TDocStd_Document::GetModified(); TDocStd_Modified is never "
            "constructed in the bridge. The next line of the same comment already says so.",
        "issue": "#971",
        "why_deferred": "the file is grandfathered on Scripts/style-manifest-bridge.txt, so "
            "touching it requires bringing it fully clang-format clean in the same PR: 1,714 diff "
            "lines, measured, against a documentation-audit PR whose remaining diff is one-line "
            "corrections. Same trade #917 tracks for OCCTBridge_Modeling.mm and PR #923 deferred.",
    },
]

# ---------------------------------------------------------------------------------------------
# `Class::Member` attributions adjudicated as NOT findings, so the method check stays silent about
# them without going blind. Each is prose about kernel internals across versions rather than a
# claim about what a current method calls.
# ---------------------------------------------------------------------------------------------

METHOD_ATTRIBUTION_ALLOWED = {
    ("XCAFDoc_ShapeTool", "theAutoNaming"): "the private static flag #341 fixed; named in "
        "docs/thread-safety.md's account of that fix, not as an attribution.",
    ("XCAFDoc_ShapeTool", "AutoNamingScope"): "the RAII scope patch 0011 added and #363 then "
        "replaced with OwnAutoNamingScope; the same paragraph says so.",
}


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

    Same rule as #808's, and it matters at least as much here: `XCAFApp_Application` appears in
    `Sources/OCCTBridge/src/OCCTBridge_Document.mm` exactly once, inside a comment explaining that
    #371 stopped using it. Counting that as a wrap would file the lane's flagship finding as `ok`.
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

    The wrapped test runs FIRST, before the curated tables, following #808. Six deprecated headers
    in this lane are genuinely called (`TDF_LabelSequence` in five bridge functions alone), and
    consulting the tables first would file them as `deliberate, recorded` behind a table entry
    saying they have no call sites.
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
        haystack = " ".join(cache[path].split())
        needle = " ".join(finding["bad_phrase"].split())
        if needle in haystack:
            regressions.append(finding)
    return regressions


def check_deferred_findings() -> list[dict]:
    """The subset of DEFERRED_OVER_FINDINGS whose bad_phrase has GONE (fixed, entry not moved)."""
    stale = []
    cache: dict[str, str] = {}
    for finding in DEFERRED_OVER_FINDINGS:
        path = os.path.join(ROOT, finding["doc_file"])
        if path not in cache:
            cache[path] = _read(path) if os.path.exists(path) else ""
        haystack = " ".join(cache[path].split())
        needle = " ".join(finding["bad_phrase"].split())
        if needle not in haystack:
            stale.append(finding)
    return stale


# ---------------------------------------------------------------------------------------------
# The method-attribution check (new in this pass; see the docstring's OVER-COVERAGE section).
# ---------------------------------------------------------------------------------------------

# A backtick, a class name, `::`, a member name. Deliberately NOT anchored on a CLOSING backtick.
#
# It was, in this file's first version, and that cost a finding. `docs/` writes attributions three
# ways: `` `Class::Member` ``, `` `Class::Member()` `` and
# `` `Class::Member().Something()` ``. Requiring the closing backtick right after the member name
# sees only the first, and 471 of this lane's `Class::Member` occurrences are matched by the loose
# form against a smaller number by the strict one. The difference contained
# `XCAFDoc_ShapeMapTool::Map().Extent()`, which is wrong (the member is `GetMap`) and which the
# strict pattern skipped in silence. That is the exact failure mode this whole programme exists to
# catch, found in a detector written to catch it, so the pattern is loose and the self-test has a
# case for each of the three spellings.
_ATTRIBUTION_RE = re.compile(
    r"`([A-Za-z][A-Za-z0-9]*(?:_[A-Za-z0-9]+)?)::([A-Za-z_][A-Za-z0-9_]*)"
)


def _lane_class_names() -> set[str]:
    return {c for classes in LANE_CLASSES.values() for c in classes}


def _header_bases(cls: str) -> list[str]:
    path = os.path.join(OCCT_HEADERS, cls + ".hxx")
    if not os.path.exists(path):
        return []
    m = re.search(r"^\s*(?:class|struct)\s+" + re.escape(cls) + r"\s*:\s*([^{]+)",
                  _read(path), re.M)
    if not m:
        return []
    out = []
    for part in m.group(1).split(","):
        part = part.replace("public", "").replace("protected", "").replace("private", "")
        part = part.split("<")[0].strip()
        if part:
            out.append(part)
    return out


def declares_member(cls: str, member: str, seen: set[str] | None = None) -> bool | None:
    """Does `cls` (or an ancestor) declare `member` in the pinned headers?

    None means the header is not present, which is not a finding: a class outside the xcframework
    is not something this check can speak to.

    Three shapes count as a declaration, and each was added because omitting it produced a false
    report on this lane's real docs:

      - `member(` anywhere in the header, which covers every method and constructor;
      - a nested type (`enum`/`class`/`struct`/`using`/`typedef` named `member`), which is what
        `XCAFDoc_AssemblyGraph::NodeType` is;
      - `member;` or `member =`, a data member, which is what `CDF_Directory::myDocuments` is in
        `docs/thread-safety.md`'s prose about kernel internals.
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
        if declares_member(base, member, seen) is True:
            return True
    return False


def check_method_attributions() -> tuple[bool, list[str]]:
    """Every ``Class::Member`` attribution in the lane, against that class's own pinned header.

    Returns (checked, messages). `checked` is False when `Libraries/` is absent, which is the case
    in CI and in a fresh clone; the caller reports that rather than passing silently.
    """
    if not os.path.isdir(OCCT_HEADERS):
        return (False, [f"{OCCT_HEADERS} not present, method-attribution check skipped"])
    lane = _lane_class_names()
    targets = _doc_files() + [
        os.path.join(BRIDGE_INC, f) for f in sorted(os.listdir(BRIDGE_INC)) if f.endswith(".h")
    ]
    msgs = []
    for path in targets:
        rel = os.path.relpath(path, ROOT)
        for lineno, line in enumerate(_read(path).splitlines(), 1):
            for cls, member in _ATTRIBUTION_RE.findall(line):
                if cls not in lane:
                    continue
                if (cls, member) in METHOD_ATTRIBUTION_ALLOWED:
                    continue
                if declares_member(cls, member) is False:
                    msgs.append(f"{rel}:{lineno}  {cls}::{member} is not declared by "
                                f"{cls}.hxx or any ancestor")
    return (True, msgs)


def reverify_lane() -> tuple[bool, list[str]]:
    """Re-derive the lane from the bundled headers and diff against LANE_CLASSES."""
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


# ---------------------------------------------------------------------------------------------
# Self-test. `refman_census.py` is a repro artifact rather than a gate, but the method-attribution
# check above is a new DETECTOR, and a detector that reports "all clear" because it is blind looks
# exactly like one reporting "all clear" because the tree is clean
# (okf/policies/prove-the-test-fails.md). These cases exercise `declares_member` against the real
# pinned headers, and each of the three accepting shapes has a case that fails when that shape is
# removed. The removal matrix is in this directory's README.
# ---------------------------------------------------------------------------------------------

SELF_TEST_CASES = [
    # (class, member, expected, why this case exists)
    ("TNaming_Tool", "SameShape", False,
     "the real finding: TNaming_Tool declares CurrentShape/GetShape/OriginalShape/ValidUntil "
     "and no SameShape. Without this case nothing proves the check reports anything."),
    ("TNaming_Tool", "OriginalShape", True,
     "the method that actually runs, in the same class, so a check that answered False for "
     "everything would fail here."),
    ("XCAFDoc_AssemblyGraph", "NodeType", True,
     "a NESTED ENUM, not a method. Removing the nested-type shape from declares_member turns "
     "this into a false report against docs/reference/Document-XCAF-Notes.md."),
    ("CDF_Directory", "myDocuments", True,
     "a private DATA MEMBER named in docs/thread-safety.md's prose about the #344 race. Removing "
     "the data-member shape turns this into a false report."),
    ("XCAFApp_Application", "SaveAs", True,
     "inherited from TDocStd_Application. Removing the base-class walk turns this into a false "
     "report, and would also have masked the lane's flagship finding as the wrong KIND of defect: "
     "the claim is wrong because the class is not constructed, not because the member is missing."),
    ("TDataXtd_Presentation", "GetColor", False,
     "the spelled-wrong accessor family: Color() exists, GetColor() does not. Proves the check "
     "distinguishes a near-miss spelling rather than matching loosely."),
    ("TDocStd_XLink", "DocumentEntry", True,
     "the correct overloaded spelling for the four TDocStd_XLink findings, so the corrections "
     "this PR writes are themselves checked."),
    ("XCAFDoc_AssemblyItemRef", "ClearExtraRef", True,
     "the correct spelling for RemoveExtraRef, same reason."),
    ("XCAFDoc_ShapeMapTool", "Map", False,
     "the finding the strict, closing-backtick-anchored pattern missed: the doc wrote "
     "`XCAFDoc_ShapeMapTool::Map().Extent()` and the member is GetMap. Paired with the parse "
     "case below, which is what proves the pattern sees it at all."),
    ("XCAFDoc_ShapeMapTool", "GetMap", True,
     "the correct spelling, so a check that answered False for everything would fail here."),
]

# Fixtures for `_ATTRIBUTION_RE` itself, one per spelling `docs/` actually uses. `declares_member`
# can only adjudicate a pair the pattern produced, so a battery that exercises only the former
# proves nothing about a pattern that silently skips a whole spelling. It did.
PARSE_SELF_TEST_CASES = [
    ("- **OCCT:** `TNaming_Tool::SameShape`.",
     [("TNaming_Tool", "SameShape")],
     "the plain spelling, closing backtick straight after the member."),
    ("- **OCCT:** `XCAFDoc_ShapeMapTool::Map().Extent()`",
     [("XCAFDoc_ShapeMapTool", "Map")],
     "the parenthesised spelling. The strict pattern returned nothing here, which is how "
     "XCAFDoc_ShapeMapTool::Map survived the first run of this census."),
    ("- **OCCT:** `TDF_Label::FindAttribute(TDataXtd_Pattern::GetID())` (via `X`).",
     [("TDF_Label", "FindAttribute")],
     "a nested call. Only the backticked head is a claim; the inner TDataXtd_Pattern::GetID has "
     "no backtick of its own and is deliberately not extracted twice."),
    ("Plain prose naming TNaming_Tool::SameShape with no backticks at all.",
     [],
     "no backtick, no claim. Without this case the pattern could drop its backtick anchor "
     "entirely and every case above would still pass."),
]


def self_test() -> int:
    failures = 0

    print(f"self-test, parser: {len(PARSE_SELF_TEST_CASES)} cases against _ATTRIBUTION_RE")
    for line, expected, why in PARSE_SELF_TEST_CASES:
        got = _ATTRIBUTION_RE.findall(line)
        ok = got == expected
        print(f"  [{'PASS' if ok else 'FAIL'}] {line[:64]!r} -> {got}")
        if not ok:
            print(f"         expected {expected}: {why}")
            failures += 1
    print()

    if not os.path.isdir(OCCT_HEADERS):
        print("SELF-TEST, HEADERS: SKIPPED, Libraries/OCCT.xcframework is not present.")
        print("  This half reads the pinned headers by design (CLAUDE.md's source of truth for")
        print("  version-sensitive detail), so it cannot run in CI or in a fresh clone. It is")
        print("  reported rather than passed silently. The parser half above ran.")
        return 1 if failures else 0
    print(f"self-test, headers: {len(SELF_TEST_CASES)} cases against the pinned headers")
    for cls, member, expected, why in SELF_TEST_CASES:
        got = declares_member(cls, member)
        ok = got is expected
        print(f"  [{'PASS' if ok else 'FAIL'}] {cls}::{member} -> {got} (expected {expected})")
        if not ok:
            print(f"         {why}")
            failures += 1
    total = len(PARSE_SELF_TEST_CASES) + len(SELF_TEST_CASES)
    print()
    if failures:
        print(f"SELF-TEST FAILED: {failures} of {total}")
        return 1
    print(f"SELF-TEST PASSED: {total} of {total} "
          f"({len(PARSE_SELF_TEST_CASES)} parser, {len(SELF_TEST_CASES)} headers)")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument(
        "--reverify-lane",
        action="store_true",
        help="re-derive LANE_CLASSES from Libraries/OCCT.xcframework and fail on any difference",
    )
    parser.add_argument("--self-test", action="store_true",
                        help="run the method-attribution detector's own fixture battery")
    args = parser.parse_args()

    if args.self_test:
        return self_test()

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

    print(f"{'lane':20} {'occt_class':50} {'documented?':12} {'wrapped?':9} {'verdict':22} note")
    print("-" * 160)
    for r in rows:
        print(
            f"{r['lane']:20} {r['class']:50} {str(r['documented']):12} {str(r['wrapped']):9} "
            f"{r['verdict']:22} {r['note']}"
        )
        if args.verbose:
            if r["wrapped_files"]:
                print(f"{'':20}   wrapped in: {', '.join(r['wrapped_files'])}")
            if r["doc_files"]:
                print(f"{'':20}   documented in: {', '.join(r['doc_files'])}")

    print()
    counts: dict[str, int] = {}
    for r in rows:
        counts[r["verdict"]] = counts.get(r["verdict"], 0) + 1
    print(f"Total classes in lane: {len(rows)}")
    for verdict in ("ok", "deliberate, recorded", "under"):
        print(f"  {verdict}: {counts.get(verdict, 0)}")
    # `over` is not a per-class verdict and never was: over-coverage is a wrong claim in prose,
    # not a property of a class's wrapped/documented state. #808 and #809 printed three counts and
    # said so; this pass prints the `over` count too, from the two detectors below, because it now
    # has one that was measured rather than asserted.
    print(f"  over: {len(KNOWN_OVER_FINDINGS)} fixed in this PR, "
          f"{len(DEFERRED_OVER_FINDINGS)} deferred with an issue")
    assert not any(r["verdict"] == "over" for r in rows), "classify() cannot return 'over'"

    exit_code = 0

    print()
    derived: dict[str, int] = {}
    for f in KNOWN_OVER_FINDINGS:
        derived[f["family"]] = derived.get(f["family"], 0) + 1
    if derived != FAMILY_COUNTS:
        print("FAMILY COUNT DRIFT: the docstring's per-family totals no longer match the table.")
        for fam in sorted(set(derived) | set(FAMILY_COUNTS)):
            if derived.get(fam) != FAMILY_COUNTS.get(fam):
                print(f"  {fam}: table has {derived.get(fam, 0)}, "
                      f"FAMILY_COUNTS says {FAMILY_COUNTS.get(fam, 0)}")
        exit_code = 1

    print(f"Known over-coverage findings tracked: {len(KNOWN_OVER_FINDINGS)} "
          f"({', '.join(f'{k} {v}' for k, v in sorted(derived.items()))})")
    regressions = check_over_findings()
    if regressions:
        print("REGRESSION: the following fixed over-coverage findings have reappeared:")
        for f in regressions:
            print(f"  {f['doc_file']}: {f['subject']} -- {f['bad_phrase']!r}")
        exit_code = 1
    else:
        print("All known over-coverage findings remain fixed.")
        print("  This is a regression check, not a search. New over-coverage in this lane is found")
        print("  by re-running the two detectors:")
        print(f"    python3 Scripts/census-doc-occt-attribution.py --lane {LANE_PREFIXES}")
        print("    (and the method-attribution check below, which runs as part of this script)")

    print()
    print(f"Deferred over-coverage findings: {len(DEFERRED_OVER_FINDINGS)}")
    stale = check_deferred_findings()
    for f in DEFERRED_OVER_FINDINGS:
        print(f"  {f['doc_file']}: {f['subject']} ({f['issue']})")
        print(f"    deferred because {f['why_deferred']}")
    if stale:
        print("STALE: the following deferred findings appear to have been FIXED. Move each entry")
        print("from DEFERRED_OVER_FINDINGS to KNOWN_OVER_FINDINGS so the regression check pins it:")
        for f in stale:
            print(f"  {f['doc_file']}: {f['subject']} ({f['issue']})")
        exit_code = 1

    print()
    checked, msgs = check_method_attributions()
    if not checked:
        print(f"Method-attribution check SKIPPED: {msgs[0]}")
    elif msgs:
        print("METHOD ATTRIBUTIONS naming a member the pinned headers do not declare:")
        for m in msgs:
            print(f"  {m}")
        exit_code = 1
    else:
        print("Method-attribution check clean: every `Class::Member` claim in this lane resolves")
        print("to a declaration in that class's own pinned header or an ancestor's.")

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
