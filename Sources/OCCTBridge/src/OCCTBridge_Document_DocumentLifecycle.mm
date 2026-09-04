//
//  OCCTBridge_Document_DocumentLifecycle.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Document.mm (#1380): Document main label/transactions/undo-redo/modified
//  labels/length unit/layers, XCAFDoc_DocumentTool/LayerTool/NotesTool/Note*, OCAF persistence,
//  TDocStd_XLinkTool -- default_bucket. Public C surface unchanged; every sibling file imports the
//  same headers this one does (the shared preamble below). No symbol changes, pure file move -- see
//  Scripts/repro/396-bridge-mm-split/ for how.
//

//
//  OCCTBridge_Document.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm, issue #99.
//
//  XDE / XCAF document support: document creation + lifecycle, assembly
//  traversal, transforms, colors, PBR + common visual materials, plus the
//  generic OCCTStringFree helper (declared in the public header but
//  defined here because every label-name getter that allocates a heap
//  string is in this block).
//
//  Public C surface unchanged. No symbol changes, pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <algorithm>

#include <STEPCAFControl_Reader.hxx>
#include <STEPCAFControl_Writer.hxx>
#include <STEPControl_StepModelType.hxx>
#include <IFSelect_ReturnStatus.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_VisMaterial.hxx>
#include <XCAFDoc_VisMaterialCommon.hxx>
#include <XCAFDoc_VisMaterialPBR.hxx>
#include <XCAFDoc_ColorType.hxx>
#include <TDF_LabelSequence.hxx>
#include <XCAFDoc_DimTolTool.hxx>
#include <XCAFDoc_Datum.hxx>
#include <XCAFDoc_Dimension.hxx>
#include <XCAFDoc_GeomTolerance.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <XCAFDimTolObjects_DatumObject.hxx>
#include <XCAFDimTolObjects_DimensionFormVariance.hxx>
#include <XCAFDimTolObjects_DimensionGrade.hxx>
#include <XCAFDimTolObjects_DimensionObject.hxx>
#include <XCAFDimTolObjects_DimensionType.hxx>
#include <XCAFDimTolObjects_GeomToleranceObject.hxx>
#include <XCAFDimTolObjects_GeomToleranceType.hxx>
#include <TDF_ChildIterator.hxx>
#include <TDF_Data.hxx>
#include <TDF_Delta.hxx>
#include <TDF_Tool.hxx>
#include <TCollection_HAsciiString.hxx>
#include <TColStd_HArray1OfReal.hxx>
#include <TDataStd_Name.hxx>
#include <TDataStd_RealArray.hxx>
#include <TCollection_AsciiString.hxx>
#include <TCollection_ExtendedString.hxx>
#include <Quantity_Color.hxx>
#include <Quantity_ColorRGBA.hxx>
#include <Graphic3d_Vec3.hxx>
#include <Graphic3d_Vec4.hxx>
#include <gp_Trsf.hxx>
#include <TopLoc_Location.hxx>
#include <TopAbs.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <BRep_Tool.hxx>

#include <cstring>

// Additional includes gathered from throughout the original file (#1380):
#include <XCAFDoc_LengthUnit.hxx>
#include <XCAFDoc_LayerTool.hxx>
#include <XCAFDoc_MaterialTool.hxx>
#include <TNaming_Builder.hxx>
#include <TNaming_NamedShape.hxx>
#include <TNaming_Selector.hxx>
#include <TNaming_Iterator.hxx>
#include <TNaming_NewShapeIterator.hxx>
#include <TNaming_OldShapeIterator.hxx>
#include <TNaming_Tool.hxx>
#include <TDF_Label.hxx>
#include <TDF_LabelMap.hxx>
#include <TDF_AttributeIterator.hxx>
#include <TDF_Reference.hxx>
#include <TDF_CopyLabel.hxx>
#include <TDF_TagSource.hxx>
#include <TDocStd_Modified.hxx>
#include <TDataStd_Integer.hxx>
#include <TDataStd_Real.hxx>
#include <TDataStd_AsciiString.hxx>
#include <TDataStd_Comment.hxx>
#include <TDataStd_IntegerArray.hxx>
#include <TDataStd_TreeNode.hxx>
#include <TDataStd_NamedData.hxx>
#include <TDataXtd_Shape.hxx>
#include <TDataXtd_Position.hxx>
#include <TDataXtd_Geometry.hxx>
#include <TDataXtd_Triangulation.hxx>
#include <TDataXtd_Point.hxx>
#include <TDataXtd_Axis.hxx>
#include <TDataXtd_Plane.hxx>
#include <TFunction_Logbook.hxx>
#include <TFunction_GraphNode.hxx>
#include <TFunction_Function.hxx>
#include <TFunction_ExecutionStatus.hxx>
#include <TNaming_CopyShape.hxx>
#include <TColStd_IndexedDataMapOfTransientTransient.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <Poly_Triangulation.hxx>
#include <gp_Lin.hxx>
#include <gp_Pln.hxx>
#include <BinDrivers.hxx>
#include <BinLDrivers.hxx>
#include <XmlDrivers.hxx>
#include <XmlLDrivers.hxx>
#include <BinXCAFDrivers.hxx>
#include <XmlXCAFDrivers.hxx>
#include <PCDM_StoreStatus.hxx>
#include <PCDM_ReaderStatus.hxx>
#include <NCollection_Sequence.hxx>
#include <XCAFDoc_Area.hxx>
#include <XCAFDoc_Volume.hxx>
#include <XCAFDoc_Centroid.hxx>
#include <XCAFDoc_Editor.hxx>
#include <NCollection_HSequence.hxx>
#include <XCAFDoc_Location.hxx>
#include <XCAFDoc_GraphNode.hxx>
#include <XCAFDoc_Color.hxx>
#include <XCAFDoc_Material.hxx>
#include <XCAFDoc_NoteComment.hxx>
#include <XCAFDoc_NoteBalloon.hxx>
#include <XCAFDoc_NoteBinData.hxx>
#include <XCAFDoc_NotesTool.hxx>
#include <XCAFDoc_ClippingPlaneTool.hxx>
#include <XCAFDoc_ShapeMapTool.hxx>
#include <XCAFDoc_AssemblyGraph.hxx>
#include <XCAFDoc_AssemblyItemId.hxx>
#include <XCAFView_Object.hxx>
#include <XCAFView_ProjectionType.hxx>
#include <XCAFNoteObjects_NoteObject.hxx>
#include <XCAFPrs_Style.hxx>
#include <TDataStd_Directory.hxx>
#include <TDataStd_Variable.hxx>
#include <TDataStd_Expression.hxx>
#include <TDocStd_XLink.hxx>
#include <XCAFDimTolObjects_Tool.hxx>
#include <TPrsStd_DriverTable.hxx>
#include <TObj_Application.hxx>
#include <TDataStd_BooleanArray.hxx>
#include <TDataStd_BooleanList.hxx>
#include <TDataStd_ByteArray.hxx>
#include <TDataStd_IntegerList.hxx>
#include <TDataStd_RealList.hxx>
#include <TDataStd_ExtStringArray.hxx>
#include <TDataStd_ExtStringList.hxx>
#include <TDataStd_ReferenceArray.hxx>
#include <TDataStd_ReferenceList.hxx>
#include <TDataStd_Relation.hxx>
#include <TDataStd_Tick.hxx>
#include <TDataStd_Current.hxx>
#include <TNaming_SameShapeIterator.hxx>
#include <TDataStd_IntPackedMap.hxx>
#include <TDataStd_NoteBook.hxx>
#include <TDataStd_UAttribute.hxx>
#include <TDataStd_ChildNodeIterator.hxx>
#include <TColStd_HPackedMapOfInteger.hxx>
#include <TColStd_PackedMapOfInteger.hxx>
#include <TDF_Transaction.hxx>
#include <TDF_CopyTool.hxx>
#include <TDF_ComparisonTool.hxx>
#include <TDF_DataSet.hxx>
#include <TDF_RelocationTable.hxx>
#include <TDocStd_XLinkTool.hxx>
#include <TDocStd_MultiTransactionManager.hxx>
#include <TFunction_IFunction.hxx>
#include <TFunction_Iterator.hxx>
#include <TFunction_Scope.hxx>
#include <TDF_ChildIDIterator.hxx>
#include <TFunction_DriverTable.hxx>
#include <TFunction_Driver.hxx>
#include <TNaming_Translator.hxx>
#include <TDataXtd_Placement.hxx>
#include <TDataXtd_Presentation.hxx>
#include <XCAFDoc_AssemblyIterator.hxx>
#include <XCAFDoc_DimTol.hxx>
#include <TDataXtd_Constraint.hxx>
#include <TDataXtd_ConstraintEnum.hxx>
#include <TDataXtd_PatternStd.hxx>
#include <TDataXtd_Pattern.hxx>
#include <XCAFDoc_AssemblyItemRef.hxx>
#include <TNaming_Naming.hxx>
#include <XCAFPrs_DocumentExplorer.hxx>
#include <XCAFPrs_DocumentNode.hxx>
#import <XCAFDoc_ColorTool.hxx>

// Shared private structs/helpers (#1380): every split file gets this identical block,
// compiled independently per TU -- see this split's own README for why.

// Generic GD&T label lookup helper. Consolidates the three near-identical helpers for
// dimensions, geometric tolerances, and datums (#1065).
template <typename AttrType,
          typename ObjType,
          typename ToolGetter,
          typename LabelsGetter,
          typename ReadableCheck>
static bool occtDocumentGdtObjectAtImpl(OCCTDocumentRef   doc,
                                        int32_t           index,
                                        ToolGetter&&      getTool,
                                        LabelsGetter&&    getLabels,
                                        ReadableCheck&&   isReadable,
                                        Handle(AttrType)& outAttr,
                                        Handle(ObjType)&  outObj)
{
  if (!doc || doc->doc.IsNull() || index < 0)
    return false;

  Handle(XCAFDoc_DimTolTool) tool = getTool(doc);
  TDF_LabelSequence          labels;
  getLabels(tool, labels);
  if (index >= (int32_t)labels.Length())
    return false;

  TDF_Label label = labels.Value(index + 1);
  if (!label.FindAttribute(AttrType::GetID(), outAttr))
    return false;

  if (!isReadable(label))
    return false;

  outObj = outAttr->GetObject();
  return !outObj.IsNull();
}

// Always-true readability check for types that do not need it.
static bool occtDocumentGdtAlwaysReadable(const TDF_Label&)
{
  return true;
}

// Resolve a dimension index to its attribute and its object. Every per-dimension accessor and
// mutator below differs only in what it then reads or sets, so the lookup lives here rather than
// once per entry point (#996, extended to the read path by #1004).
static bool occtDocumentDimensionObjectAt(OCCTDocumentRef                            doc,
                                          int32_t                                    dimensionIndex,
                                          Handle(XCAFDoc_Dimension)&                 outAttr,
                                          Handle(XCAFDimTolObjects_DimensionObject)& outObj)
{
  return occtDocumentGdtObjectAtImpl<XCAFDoc_Dimension, XCAFDimTolObjects_DimensionObject>(
    doc,
    dimensionIndex,
    [](OCCTDocumentRef d) { return XCAFDoc_DocumentTool::DimTolTool(d->doc->Main()); },
    [](Handle(XCAFDoc_DimTolTool) t, TDF_LabelSequence& l) { t->GetDimensionLabels(l); },
    occtDocumentGdtAlwaysReadable,
    outAttr,
    outObj);
}

// The tolerance counterpart of occtDocumentDimensionObjectAt, for the same reason (#1004).
static bool occtDocumentGeomToleranceObjectAt(OCCTDocumentRef                doc,
                                              int32_t                        toleranceIndex,
                                              Handle(XCAFDoc_GeomTolerance)& outAttr,
                                              Handle(XCAFDimTolObjects_GeomToleranceObject)& outObj)
{
  return occtDocumentGdtObjectAtImpl<XCAFDoc_GeomTolerance, XCAFDimTolObjects_GeomToleranceObject>(
    doc,
    toleranceIndex,
    [](OCCTDocumentRef d) { return XCAFDoc_DocumentTool::DimTolTool(d->doc->Main()); },
    [](Handle(XCAFDoc_DimTolTool) t, TDF_LabelSequence& l) { t->GetGeomToleranceLabels(l); },
    occtDocumentGdtAlwaysReadable,
    outAttr,
    outObj);
}

// #1030: XCAFDoc_Datum::GetObject builds the datum point's X out of the annotation plane's array
// rather than the point's own, so a datum carrying a point with no plane location dereferences a
// null handle. That is an OS signal, which no caller's catch can absorb (#1022). Patch 0029 fixes
// it in the kernel and is in no built kernel, so every bridge path that reaches GetObject asks this
// first. ChildLab_PlaneLoc and ChildLab_Pnt are a file-local anonymous enum in XCAFDoc_Datum.cxx,
// invisible from the header, hence the literal tags. The condition is the array attribute and never
// the child label: SetObject opens every child from ChildLab_Begin to ChildLab_End and only forgets
// their attributes, so all nineteen exist on any datum it wrote and a child-existence test would
// refuse every datum.
static bool occtDatumLabelIsReadable(const TDF_Label& datumLabel)
{
  if (datumLabel.IsNull())
    return false;

  const int                  datumChildPlaneLoc = 14;
  const int                  datumChildPnt      = 17;
  const TDF_Label            pntLabel           = datumLabel.FindChild(datumChildPnt, false);
  Handle(TDataStd_RealArray) pnt;
  if (pntLabel.IsNull() || !pntLabel.FindAttribute(TDataStd_RealArray::GetID(), pnt)
      || pnt->Length() != 3)
    return true;

  // Only ChildLab_PlaneLoc, matching the kernel's own && chain, which assigns aLoc from this
  // attribute before it goes on to test ChildLab_PlaneN and ChildLab_PlaneRef. The index test is
  // the rest of the same read: the kernel spells it aLoc->Value(aPnt->Lower()), so the plane array
  // existing is not enough, it has to hold that one index. Nothing OCCT writes uses a lower bound
  // other than 1, but the arrays are caller data and this is the read being guarded.
  const TDF_Label            planeLocLabel = datumLabel.FindChild(datumChildPlaneLoc, false);
  Handle(TDataStd_RealArray) planeLoc;
  if (planeLocLabel.IsNull() || !planeLocLabel.FindAttribute(TDataStd_RealArray::GetID(), planeLoc))
    return false;
  return pnt->Lower() >= planeLoc->Lower() && pnt->Lower() <= planeLoc->Upper();
}

// The same refusal for the OTHER GD&T table. occtDocumentDatumObjectAt reads the tool this bridge
// attaches to Main() itself, while XCAFDimTolObjects_Tool and XCAFDoc_Editor::RescaleGeometry both
// go through XCAFDoc_DocumentTool::DimTolTool, which is the table every importer writes, and both
// call GetObject on every datum they find with nothing between them and the crash. CheckDimTolTool
// rather than DimTolTool, so asking the question never creates the table (#1030).
//
// Each caller gets the set ITS OWN walk reaches, not the union. Refusing on a datum the caller
// would never have touched is a wrong answer where there was no crash, and both of these report
// failure as an ordinary value (0, false) that a caller cannot tell from a real one.
static bool occtDocumentToolDimTolTool(const TDF_Label& access, Handle(XCAFDoc_DimTolTool)& outTool)
{
  if (access.IsNull() || !XCAFDoc_DocumentTool::CheckDimTolTool(access))
    return false;
  outTool = XCAFDoc_DocumentTool::DimTolTool(access);
  return !outTool.IsNull();
}

// A label carrying no XCAFDoc_Datum attribute is skipped by both kernel walks before they reach
// GetObject (XCAFDimTolObjects_Tool.cxx:83, XCAFDoc_Editor.cxx:1014), so it is skipped here too:
// refusing on one would be the same over-refusal the tolerance scoping above exists to avoid.
static bool occtDatumSequenceIsReadable(const TDF_LabelSequence& datums)
{
  for (int i = 1; i <= datums.Length(); ++i)
  {
    Handle(XCAFDoc_Datum) datum;
    if (!datums.Value(i).FindAttribute(XCAFDoc_Datum::GetID(), datum))
      continue;
    if (!occtDatumLabelIsReadable(datums.Value(i)))
      return false;
  }
  return true;
}

// XCAFDoc_Editor::RescaleGeometry walks GetDatumLabels, so every datum in the table is reached.
static bool occtDocumentToolDatumsAreReadable(const TDF_Label& access)
{
  Handle(XCAFDoc_DimTolTool) dimTolTool;
  if (!occtDocumentToolDimTolTool(access, dimTolTool))
    return true;
  TDF_LabelSequence datums;
  dimTolTool->GetDatumLabels(datums);
  return occtDatumSequenceIsReadable(datums);
}

// XCAFDimTolObjects_Tool::GetGeomTolerances reaches a datum only through the tolerance it is
// attached to, so this mirrors that walk rather than the whole table: a stray unreadable datum
// linked to no tolerance is never read there, and refusing on it would report zero tolerances for
// a document that has them.
static bool occtDocumentToolToleranceDatumsAreReadable(const TDF_Label& access)
{
  Handle(XCAFDoc_DimTolTool) dimTolTool;
  if (!occtDocumentToolDimTolTool(access, dimTolTool))
    return true;
  for (TDF_ChildIterator it(dimTolTool->Label()); it.More(); it.Next())
  {
    Handle(XCAFDoc_GeomTolerance) tolerance;
    if (!it.Value().FindAttribute(XCAFDoc_GeomTolerance::GetID(), tolerance))
      continue;
    TDF_LabelSequence datums;
    if (!dimTolTool->GetDatumOfTolerLabels(tolerance->Label(), datums))
      continue;
    if (!occtDatumSequenceIsReadable(datums))
      return false;
  }
  return true;
}

// The datum counterpart of occtDocumentDimensionObjectAt, for the same reason (#1004).
static bool occtDocumentDatumObjectAt(OCCTDocumentRef                        doc,
                                      int32_t                                datumIndex,
                                      Handle(XCAFDoc_Datum)&                 outAttr,
                                      Handle(XCAFDimTolObjects_DatumObject)& outObj)
{
  return occtDocumentGdtObjectAtImpl<XCAFDoc_Datum, XCAFDimTolObjects_DatumObject>(
    doc,
    datumIndex,
    [](OCCTDocumentRef d) { return XCAFDoc_DocumentTool::DimTolTool(d->doc->Main()); },
    [](Handle(XCAFDoc_DimTolTool) t, TDF_LabelSequence& l) { t->GetDatumLabels(l); },
    occtDatumLabelIsReadable,
    outAttr,
    outObj);
}

/// Apply a plus/minus tolerance pair to a dimension object, and report whether the object kept it.
///
/// Both setters return false, and change nothing, when the dimension is already a range.
/// Discarding that reported success for a call that did nothing (#996). Neither is
/// short-circuited, so the two arguments stay symmetric rather than one being applied and one
/// not. That is safe for the rejection this project has actually measured, a range dimension,
/// where both refuse: see Scripts/repro/996-gdt-read-surface/. It is NOT a general guarantee
/// that OCCT rejects the pair atomically on every path, and no such guarantee is documented
/// upstream. The readback is what makes the caller's answer correct either way: verify rather than
/// trust the return pair, since a partial application would otherwise be reported as a clean
/// failure and the caller could not tell it from a no-op.
///
/// This file's own copy has exactly one live caller: the create path immediately below, run from
/// OCCTDocumentCreateDimensionWithTolerance. OCCTDocumentSetDimensionTolerance, the other spelling
/// of "apply a tolerance" the defect #1056 is about, is a different function in
/// OCCTBridge_Document_GDT.mm, calling that file's own byte-identical copy of this one, not this
/// one (#1481, which is also why this whole shared-helpers block exists identically in six
/// OCCTBridge_Document_*.mm files: a leftover of #1380's mechanical split that duplicated it
/// everywhere without pruning per-file reachability). In every file but this one and GDT.mm, both
/// this function and occtDocumentCreateDimensionImpl below are dead code: defined, never called.
static bool occtDimensionApplyTolerance(const Handle(XCAFDimTolObjects_DimensionObject)& dimObj,
                                        double                                           lowerTol,
                                        double                                           upperTol)
{
  const bool lowerOk = dimObj->SetLowerTolValue(lowerTol);
  const bool upperOk = dimObj->SetUpperTolValue(upperTol);
  return lowerOk && upperOk && dimObj->GetLowerTolValue() == lowerTol
         && dimObj->GetUpperTolValue() == upperTol;
}

/// Shared by OCCTDocumentCreateDimension and OCCTDocumentCreateDimensionWithTolerance.
///
/// The whole object, tolerance pair included, is built and checked before AddDimension() is called,
/// so no refusal leaves a dimension behind. Doing it the other way round is what #1056 reported:
/// the label existed, the caller got its index, and the tolerance it asked for had been dropped.
/// Nothing here can undo an AddDimension(), so the only way to make -1 mean "no dimension was
/// created" is to decide before creating.
///
/// It is NOT "the document is untouched": XCAFDoc_DimTolTool::Set runs above both refusals and
/// attaches the DimTol and Shape tools to Main() when they are absent, so the first GD&T call on a
/// fresh document leaves those behind whatever it returns. That was true before this change too.
static int32_t occtDocumentCreateDimensionImpl(OCCTDocumentRef doc,
                                               int64_t         shapeLabelId,
                                               int32_t         type,
                                               double          value,
                                               bool            withTolerance,
                                               double          lowerTol,
                                               double          upperTol)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  try
  {
    Handle(XCAFDoc_DimTolTool) dimTolTool = XCAFDoc_DocumentTool::DimTolTool(doc->doc->Main());
    TDF_Label                  shapeLabel = doc->getLabel(shapeLabelId);
    if (shapeLabel.IsNull())
      return -1;

    Handle(XCAFDimTolObjects_DimensionObject) dimObj = new XCAFDimTolObjects_DimensionObject();
    // XCAFDimTolObjects_DimensionObject's constructor sets four booleans and nothing else, and
    // XCAFDoc_Dimension::SetObject then reads the qualifier, the angular qualifier, the decimal
    // places and the tolerance class off the object unconditionally to decide what to store. Left
    // alone those are storage nobody wrote, so the neutral values are set here rather than relying
    // on a fresh allocation reading as zero, which is what it happens to do today and is not a
    // guarantee. Measured in Scripts/repro/1004-gdt-accessors/ (#1004).
    dimObj->SetQualifier(XCAFDimTolObjects_DimensionQualifier_None);
    dimObj->SetAngularQualifier(XCAFDimTolObjects_AngularQualifier_None);
    dimObj->SetNbOfDecimalPlaces(0, 0);
    dimObj->SetClassOfTolerance(false,
                                XCAFDimTolObjects_DimensionFormVariance_None,
                                XCAFDimTolObjects_DimensionGrade_IT01);
    dimObj->SetType((XCAFDimTolObjects_DimensionType)type);
    Handle(TColStd_HArray1OfReal) vals = new TColStd_HArray1OfReal(1, 1);
    vals->SetValue(1, value);
    dimObj->SetValues(vals);

    if (withTolerance && !occtDimensionApplyTolerance(dimObj, lowerTol, upperTol))
      return -1;

    TDF_Label dimLabel = dimTolTool->AddDimension();
    // The single-shape overload, not the 3-sequence one: SetDimension(shapeSeq, shapeSeq, dimLabel)
    // registers shapeLabel as BOTH the DimensionRefFirstGUID and DimensionRefSecondGUID graph-node
    // father, double-registering this dimension for shapeLabel (#1481). SetDimension(theL, theDimL)
    // forwards to the 3-label overload with a null second label, which only appends to the first
    // sequence, registering the shape once.
    dimTolTool->SetDimension(shapeLabel, dimLabel);

    Handle(XCAFDoc_Dimension) dimAttr;
    if (!dimLabel.FindAttribute(XCAFDoc_Dimension::GetID(), dimAttr))
      return -1;

    dimAttr->SetObject(dimObj);

    // Return the index of the new dimension.
    TDF_LabelSequence labels;
    dimTolTool->GetDimensionLabels(labels);
    return (int32_t)labels.Length() - 1;
  }
  catch (...)
  {
    return -1;
  }
}

// Every value in a modifier array has to name a real enumerator before any of the array is stored,
// because an out-of-range one is appended, written through and read back verbatim. Checked up front
// rather than inside the append loop, so a rejected array leaves the document untouched (#1037).
static bool occtDocumentModifiersInRange(const int32_t* modifiers, int32_t count, int32_t maxValue)
{
  for (int32_t i = 0; i < count; ++i)
    if (modifiers[i] < 0 || modifiers[i] > maxValue)
      return false;
  return true;
}

// Helper: common iteration logic for naming trace (forward/backward)
// Template parameter: the iterator type (TNaming_NewShapeIterator or TNaming_OldShapeIterator)
template <typename Iterator>
static int32_t occtDocumentNamingTraceImpl(OCCTDocumentRef doc,
                                           int64_t         accessLabelId,
                                           OCCTShapeRef    shape,
                                           OCCTShapeRef*   outShapes,
                                           int32_t         maxCount)
{
  if (!doc || !shape || !outShapes || doc->doc.IsNull())
    return 0;
  try
  {
    TDF_Label access = doc->getLabel(accessLabelId);
    if (access.IsNull())
      return 0;

    int32_t count = 0;
    for (Iterator it(shape->shape, access); it.More() && count < maxCount; it.Next())
    {
      TopoDS_Shape s = it.Shape();
      if (!s.IsNull())
      {
        outShapes[count] = new OCCTShape(s);
        count++;
      }
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

// #970: move a pending named-transaction name onto the delta the commit just produced.
// TDF_Delta is the only thing in OCCT that carries a caller-supplied transaction name:
// TDocStd_MultiTransactionManager::CommitCommand(theName) is myUndos.First()->SetName(theName),
// and TDocStd_Document::Undo copies the name onto the redo delta, so it survives undo/redo.
// CommitCommand returns false when nothing changed, in which case there is no delta to name;
// the pending name is dropped either way, since the transaction it belonged to is over.
// Both call sites have already checked doc and doc->doc, so neither is rechecked here.
// The name is converted the same way OCCTDeltaSetName converts its own argument.
static void occtApplyPendingTransactionName(OCCTDocumentRef doc, bool committed)
{
  if (doc->pendingTransactionName.empty())
    return;
  if (committed)
  {
    auto& undos = doc->doc->GetUndos();
    if (!undos.IsEmpty())
    {
      Handle(TDF_Delta) delta = undos.Last();
      delta->SetName(TCollection_ExtendedString(doc->pendingTransactionName.c_str()));
    }
  }
  doc->pendingTransactionName.clear();
}

static Handle(TDataStd_NamedData) getOrCreateNamedData(OCCTDocumentRef doc, int64_t labelId)
{
  TDF_Label label = doc->getLabel(labelId);
  if (label.IsNull())
    return nullptr;
  Handle(TDataStd_NamedData) nd;
  if (!label.FindAttribute(TDataStd_NamedData::GetID(), nd))
  {
    nd = TDataStd_NamedData::Set(label);
  }
  return nd;
}

static Handle(TDataStd_NamedData) findNamedData(OCCTDocumentRef doc, int64_t labelId)
{
  TDF_Label label = doc->getLabel(labelId);
  if (label.IsNull())
    return nullptr;
  Handle(TDataStd_NamedData) nd;
  label.FindAttribute(TDataStd_NamedData::GetID(), nd);
  return nd;
}

// Merge every meshed face of `shape` into one triangulation, in the coordinate system the
// shape itself is expressed in: each face's per-face triangulation is stored in its own
// TopLoc_Location, so the nodes are transformed on the way in, and a REVERSED face has its
// winding flipped so the merged result is consistently outward. UV nodes are dropped: they
// index per-face parameter spaces that no longer mean anything once the faces are pooled.
//
// NOTE the frame. Before #443 this function fetched the location and DISCARDED it, storing
// one face's nodes in that face's own local frame. For a located face (an assembly component,
// anything from Shape.transformed()) the stored numbers therefore change, independently of
// the "every face, not the first" fix. The shape's frame is the right one for an attribute
// nothing else carries a location for, but it is a behaviour change; see the CHANGELOG.
//
// Node normals are handled MORE strictly than OCCTShapeCreateMesh, which pushes
// triangulation->Normal(i) raw with neither the location transform nor the reversal
// (OCCTBridge_Mesh.mm); only its winding swap matches this. That divergence means
// Mesh.normals and this attribute disagree for a located or reversed face; settling which is
// wrong is Shape.mesh()'s question, not this function's.
//
// The normal branch never fires on the ordinary path: BRepMesh_IncrementalMesh does not
// populate node normals (measured, 0 of 6 box faces and 0 of 1 sphere face; there is no
// SetNormal anywhere under occt-src TKMesh). It fires only for a face that arrived carrying
// a normal-bearing triangulation from elsewhere, which glTF import does produce.
//
// Returns a null handle when the shape has no face, or when nothing in it meshed.
static Handle(Poly_Triangulation) occtMergedTriangulation(const TopoDS_Shape& shape,
                                                          double              deflection)
{
  // The constructor meshes; no Perform() call, matching what this function did before.
  BRepMesh_IncrementalMesh mesher(shape, deflection);

  int    nbNodes = 0, nbTriangles = 0;
  bool   hasNormals      = true;
  double worstDeflection = 0.0;
  for (TopExp_Explorer exp(shape, TopAbs_FACE); exp.More(); exp.Next())
  {
    TopLoc_Location            loc;
    Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(TopoDS::Face(exp.Current()), loc);
    if (tri.IsNull())
      continue;
    nbNodes += tri->NbNodes();
    nbTriangles += tri->NbTriangles();
    // Normals only survive the merge if every contributing face carries them; a
    // partially-filled normal array would read as valid and be wrong on the rest.
    if (!tri->HasNormals())
      hasNormals = false;
    // Each face records the deflection it actually achieved, so the merged mesh's is
    // the worst of them. A hand-built Poly_Triangulation starts at 0, and a 0 here
    // would read as "exact".
    worstDeflection = std::max(worstDeflection, tri->Deflection());
  }
  if (nbNodes == 0 || nbTriangles == 0)
    return Handle(Poly_Triangulation)();

  Handle(Poly_Triangulation) merged =
    new Poly_Triangulation(nbNodes, nbTriangles, Standard_False, hasNormals);
  merged->Deflection(worstDeflection);
  int nodeAt = 0, triangleAt = 0;
  for (TopExp_Explorer exp(shape, TopAbs_FACE); exp.More(); exp.Next())
  {
    TopoDS_Face                face = TopoDS::Face(exp.Current());
    TopLoc_Location            loc;
    Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(face, loc);
    if (tri.IsNull())
      continue;

    const gp_Trsf transformation = loc.Transformation();
    const bool    reversed       = (face.Orientation() == TopAbs_REVERSED);
    const int     base           = nodeAt; // 0-based offset; Poly_Triangulation indices are 1-based

    for (int i = 1; i <= tri->NbNodes(); i++)
    {
      merged->SetNode(++nodeAt, tri->Node(i).Transformed(transformation));
      if (hasNormals)
      {
        gp_Dir normal = tri->Normal(i);
        if (reversed)
          normal.Reverse();
        merged->SetNormal(nodeAt, normal.Transformed(transformation));
      }
    }
    for (int i = 1; i <= tri->NbTriangles(); i++)
    {
      int n1 = 0, n2 = 0, n3 = 0;
      tri->Triangle(i).Get(n1, n2, n3);
      if (reversed)
        std::swap(n2, n3);
      merged->SetTriangle(++triangleAt, Poly_Triangle(base + n1, base + n2, base + n3));
    }
  }
  return merged;
}

// Helper: common iteration logic for format enumeration (reading/writing)
// FormatsFn is a pointer-to-member-function of TDocStd_Application taking
// NCollection_Sequence<TCollection_AsciiString>&
template <typename FormatsFn>
static int32_t occtDocumentFormatsImpl(OCCTDocumentRef doc,
                                       const char**    outFormats,
                                       int32_t         maxFormats,
                                       FormatsFn       formatsFn)
{
  if (!doc || doc->app.IsNull() || !outFormats || maxFormats <= 0)
    return 0;
  try
  {
    NCollection_Sequence<TCollection_AsciiString> formats;
    (doc->app.get()->*formatsFn)(formats);
    int32_t count = std::min((int32_t)formats.Length(), maxFormats);
    for (int32_t i = 0; i < count; i++)
    {
      outFormats[i] = strdup(formats.Value(i + 1).ToCString());
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

struct OCCTAssemblyGraph
{
  Handle(XCAFDoc_AssemblyGraph) graph;
};

struct OCCTViewObject
{
  Handle(XCAFView_Object) obj;
};

struct OCCTNoteObject
{
  Handle(XCAFNoteObjects_NoteObject) obj;
};

// Helper to get label from document ref + tag (duplicate of main bridge's helper, ODR-safe across
// TUs)
static TDF_Label getLabelForTag(OCCTDocumentRef document, int tag)
{
  if (tag == 0)
    return document->doc->Main();
  return document->doc->Main().FindChild(tag, Standard_True);
}

// #964: the walk's upper bound. Reaching it means the count is a floor, not a measurement,
// which `outTruncated` reports so a caller can tell the two apart.
static const int kAssemblyItemCountLimit = 100000;

OCCTDocumentRef OCCTDocumentCreate(void)
{
  OCCTDocument* document = nullptr;
  try
  {
    document = new OCCTDocument();

    if (!occtDocumentInit(document))
    {
      delete document;
      return nullptr;
    }

    return document;
  }
  catch (...)
  {
    delete document;
    return nullptr;
  }
}

OCCTDocumentRef OCCTDocumentLoadSTEP(const char* path)
{
  if (!path)
    return nullptr;

  // Serialize all DE reads: STEP/IGES share Interface_Static globals (#181-B, #359).
  std::lock_guard<std::mutex> igesLock(igesMutex());
  OCCTDocument*               document = nullptr;
  try
  {
    document = new OCCTDocument();

    if (!occtDocumentInit(document))
    {
      delete document;
      return nullptr;
    }

    // Configure the reader
    STEPCAFControl_Reader reader;
    reader.SetColorMode(Standard_True);
    reader.SetNameMode(Standard_True);
    reader.SetLayerMode(Standard_True);
    reader.SetPropsMode(Standard_True);
    reader.SetMatMode(Standard_True); // Enable material reading

    // Read the file
    IFSelect_ReturnStatus status = reader.ReadFile(path);
    if (status != IFSelect_RetDone)
    {
      delete document;
      return nullptr;
    }

    // Transfer to document
    if (!reader.Transfer(document->doc))
    {
      delete document;
      return nullptr;
    }

    return document;
  }
  catch (...)
  {
    delete document;
    return nullptr;
  }
}

bool OCCTDocumentWriteSTEP(OCCTDocumentRef doc, const char* path)
{
  if (!doc || !path)
    return false;

  try
  {
    // STEP and IGES writers share OCCT's non-thread-safe Interface_Static
    // globals; serialize all DE writes on one lock (#181-B).
    std::lock_guard<std::mutex> deLock(igesMutex());
    STEPCAFControl_Writer       writer;
    writer.SetColorMode(Standard_True);
    writer.SetNameMode(Standard_True);
    writer.SetLayerMode(Standard_True);
    writer.SetPropsMode(Standard_True);
    writer.SetMaterialMode(Standard_True); // Enable material writing

    if (!writer.Transfer(doc->doc, STEPControl_AsIs))
    {
      return false;
    }

    IFSelect_ReturnStatus status = writer.Write(path);
    return status == IFSelect_RetDone;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTDocumentRelease(OCCTDocumentRef doc)
{
  if (!doc)
    return;

  try
  {
    if (!doc->doc.IsNull())
    {
      doc->app->Close(doc->doc);
    }
  }
  catch (...)
  {
    // Ignore cleanup errors
  }

  delete doc;
}

int32_t OCCTDocumentGetRootCount(OCCTDocumentRef doc)
{
  if (!doc || doc->shapeTool.IsNull())
    return 0;

  try
  {
    TDF_LabelSequence roots;
    doc->shapeTool->GetFreeShapes(roots);
    return static_cast<int32_t>(roots.Length());
  }
  catch (...)
  {
    return 0;
  }
}

int64_t OCCTDocumentGetRootLabelId(OCCTDocumentRef doc, int32_t index)
{
  if (!doc || doc->shapeTool.IsNull() || index < 0)
    return -1;

  try
  {
    TDF_LabelSequence roots;
    doc->shapeTool->GetFreeShapes(roots);

    if (index >= roots.Length())
      return -1;

    TDF_Label label = roots.Value(index + 1); // OCCT is 1-based
    return doc->registerLabel(label);
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDocumentIsAssembly(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->shapeTool.IsNull())
    return false;

  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;

    return doc->shapeTool->IsAssembly(label);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentIsReference(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->shapeTool.IsNull())
    return false;

  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;

    return doc->shapeTool->IsReference(label);
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTDocumentGetChildCount(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->shapeTool.IsNull())
    return 0;

  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return 0;

    TDF_LabelSequence components;
    doc->shapeTool->GetComponents(label, components);
    return static_cast<int32_t>(components.Length());
  }
  catch (...)
  {
    return 0;
  }
}

int64_t OCCTDocumentGetChildLabelId(OCCTDocumentRef doc, int64_t parentLabelId, int32_t index)
{
  if (!doc || doc->shapeTool.IsNull() || index < 0)
    return -1;

  try
  {
    TDF_Label parentLabel = doc->getLabel(parentLabelId);
    if (parentLabel.IsNull())
      return -1;

    TDF_LabelSequence components;
    doc->shapeTool->GetComponents(parentLabel, components);

    if (index >= components.Length())
      return -1;

    TDF_Label childLabel = components.Value(index + 1); // OCCT is 1-based
    return doc->registerLabel(childLabel);
  }
  catch (...)
  {
    return -1;
  }
}

int64_t OCCTDocumentGetReferredLabelId(OCCTDocumentRef doc, int64_t refLabelId)
{
  if (!doc || doc->shapeTool.IsNull())
    return -1;

  try
  {
    TDF_Label refLabel = doc->getLabel(refLabelId);
    if (refLabel.IsNull())
      return -1;

    TDF_Label referredLabel;
    if (!doc->shapeTool->GetReferredShape(refLabel, referredLabel))
    {
      return -1;
    }

    return doc->registerLabel(referredLabel);
  }
  catch (...)
  {
    return -1;
  }
}

OCCTShapeRef OCCTDocumentGetShape(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->shapeTool.IsNull())
    return nullptr;

  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return nullptr;

    TopoDS_Shape shape = doc->shapeTool->GetShape(label);
    if (shape.IsNull())
      return nullptr;

    return new OCCTShape(shape);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTDocumentGetShapeWithLocation(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->shapeTool.IsNull())
    return nullptr;

  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return nullptr;

    // Get shape with accumulated location
    TopoDS_Shape shape;

    // If it's a reference, get the referred shape with location
    if (doc->shapeTool->IsReference(label))
    {
      TDF_Label referredLabel;
      if (doc->shapeTool->GetReferredShape(label, referredLabel))
      {
        shape = doc->shapeTool->GetShape(referredLabel);
        // Apply location from reference
        TopLoc_Location loc = doc->shapeTool->GetLocation(label);
        shape.Location(loc);
      }
    }
    else
    {
      shape = doc->shapeTool->GetShape(label);
    }

    if (shape.IsNull())
      return nullptr;

    return new OCCTShape(shape);
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTDocumentGetLocation(OCCTDocumentRef doc, int64_t labelId, float* outMatrix16)
{
  if (!doc || !outMatrix16)
    return;

  // Initialize to identity matrix (column-major)
  for (int i = 0; i < 16; i++)
  {
    outMatrix16[i] = (i % 5 == 0) ? 1.0f : 0.0f;
  }

  if (doc->shapeTool.IsNull())
    return;

  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return;

    TopLoc_Location loc = doc->shapeTool->GetLocation(label);
    if (loc.IsIdentity())
      return;

    gp_Trsf trsf = loc.Transformation();

    // Extract rotation/scale part (3x3)
    for (int row = 0; row < 3; row++)
    {
      for (int col = 0; col < 3; col++)
      {
        outMatrix16[col * 4 + row] = static_cast<float>(trsf.Value(row + 1, col + 1));
      }
    }

    // Extract translation
    outMatrix16[12] = static_cast<float>(trsf.TranslationPart().X());
    outMatrix16[13] = static_cast<float>(trsf.TranslationPart().Y());
    outMatrix16[14] = static_cast<float>(trsf.TranslationPart().Z());
    outMatrix16[15] = 1.0f;
  }
  catch (...)
  {
    // Keep identity matrix on error
  }
}

void OCCTStringFree(const char* str)
{
  delete[] str;
}

bool OCCTDocumentGetLengthUnit(OCCTDocumentRef doc,
                               double*         unitScale,
                               char*           unitName,
                               int32_t         maxNameLen)
{
  if (!doc || doc->doc.IsNull() || !unitScale)
    return false;
  try
  {
    TDF_Label                  rootLabel = doc->doc->Main().Root();
    Handle(XCAFDoc_LengthUnit) luAttr;
    if (!rootLabel.FindAttribute(XCAFDoc_LengthUnit::GetID(), luAttr))
    {
      // Try the main label
      TDF_Label mainLabel = doc->doc->Main();
      if (!mainLabel.FindAttribute(XCAFDoc_LengthUnit::GetID(), luAttr))
      {
        return false;
      }
    }
    *unitScale = luAttr->GetUnitValue();
    if (unitName && maxNameLen > 0)
    {
      TCollection_AsciiString name = luAttr->GetUnitName();
      int                     len  = name.Length();
      if (len >= maxNameLen)
        len = maxNameLen - 1;
      for (int i = 0; i < len; i++)
      {
        unitName[i] = name.Value(i + 1);
      }
      unitName[len] = '\0';
    }
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTDocumentGetLayerCount(OCCTDocumentRef doc)
{
  if (!doc || doc->doc.IsNull())
    return 0;
  try
  {
    Handle(XCAFDoc_LayerTool) layerTool = XCAFDoc_LayerTool::Set(doc->doc->Main());
    if (layerTool.IsNull())
      return 0;
    TDF_LabelSequence labels;
    layerTool->GetLayerLabels(labels);
    return (int32_t)labels.Length();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTDocumentGetLayerName(OCCTDocumentRef doc,
                                 int32_t         index,
                                 char* _Nullable outName,
                                 int32_t maxLen)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  if (maxLen < 0)
    return -1;
  try
  {
    Handle(XCAFDoc_LayerTool) layerTool = XCAFDoc_LayerTool::Set(doc->doc->Main());
    if (layerTool.IsNull())
      return -1;
    TDF_LabelSequence labels;
    layerTool->GetLayerLabels(labels);
    if (index < 0 || index >= labels.Length())
      return -1;
    TDF_Label                  label = labels.Value(index + 1);
    TCollection_ExtendedString name;
    if (!layerTool->GetLayer(label, name))
      return -1;
    // Convert ExtendedString to ASCII
    TCollection_AsciiString ascii(name);
    int32_t                 len = ascii.Length();
    // Allow length-only query with outName == NULL and maxLen == 0
    if (!outName && maxLen == 0)
      return len;
    // Invalid: null buffer with positive maxLen, or non-null buffer with zero/negative maxLen
    if (!outName || maxLen <= 0)
      return -1;
    // Copy up to maxLen-1 characters, NUL-terminate
    int32_t copyLen = std::min(len, maxLen - 1);
    for (int32_t i = 0; i < copyLen; i++)
    {
      outName[i] = ascii.Value(i + 1);
    }
    outName[copyLen] = '\0';
    return len;
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTDocumentCreateDimension(OCCTDocumentRef doc,
                                    int64_t         shapeLabelId,
                                    int32_t         type,
                                    double          value)
{
  return occtDocumentCreateDimensionImpl(doc, shapeLabelId, type, value, false, 0.0, 0.0);
}

int32_t OCCTDocumentCreateDimensionWithTolerance(OCCTDocumentRef doc,
                                                 int64_t         shapeLabelId,
                                                 int32_t         type,
                                                 double          value,
                                                 double          lowerTol,
                                                 double          upperTol)
{
  return occtDocumentCreateDimensionImpl(doc, shapeLabelId, type, value, true, lowerTol, upperTol);
}

int64_t OCCTDocumentCreateLabel(OCCTDocumentRef doc, int64_t parentLabelId)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  try
  {
    TDF_Label parentLabel;
    if (parentLabelId < 0)
    {
      // Create under document root
      parentLabel = doc->doc->Main();
    }
    else
    {
      parentLabel = doc->getLabel(parentLabelId);
      if (parentLabel.IsNull())
        return -1;
    }
    TDF_Label newLabel = parentLabel.NewChild();
    return doc->registerLabel(newLabel);
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTDocumentLabelTag(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return -1;
    return label.Tag();
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTDocumentLabelDepth(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return -1;
    return label.Depth();
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDocumentLabelIsNull(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return true;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    return label.IsNull();
  }
  catch (...)
  {
    return true;
  }
}

bool OCCTDocumentLabelIsRoot(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    return label.IsRoot();
  }
  catch (...)
  {
    return false;
  }
}

int64_t OCCTDocumentLabelFather(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull() || label.IsRoot())
      return -1;
    TDF_Label father = label.Father();
    if (father.IsNull())
      return -1;
    return doc->registerLabel(father);
  }
  catch (...)
  {
    return -1;
  }
}

int64_t OCCTDocumentLabelRoot(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return -1;
    TDF_Label root = label.Root();
    if (root.IsNull())
      return -1;
    return doc->registerLabel(root);
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDocumentLabelHasAttribute(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    return label.HasAttribute();
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTDocumentLabelNbAttributes(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return 0;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return 0;
    return label.NbAttributes();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTDocumentLabelHasChild(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    return label.HasChild();
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTDocumentLabelNbChildren(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return 0;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return 0;
    return label.NbChildren();
  }
  catch (...)
  {
    return 0;
  }
}

int64_t OCCTDocumentLabelFindChild(OCCTDocumentRef doc, int64_t labelId, int32_t tag, bool create)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return -1;
    TDF_Label child = label.FindChild(tag, create);
    if (child.IsNull())
      return -1;
    return doc->registerLabel(child);
  }
  catch (...)
  {
    return -1;
  }
}

void OCCTDocumentLabelForgetAllAttributes(OCCTDocumentRef doc, int64_t labelId, bool clearChildren)
{
  if (!doc || doc->doc.IsNull())
    return;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return;
    label.ForgetAllAttributes(clearChildren);
  }
  catch (...)
  {
  }
}

int32_t OCCTDocumentGetDescendantLabels(OCCTDocumentRef doc,
                                        int64_t         labelId,
                                        bool            allLevels,
                                        int64_t*        outLabelIds,
                                        int32_t         maxCount)
{
  if (!doc || doc->doc.IsNull() || !outLabelIds || maxCount <= 0)
    return 0;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return 0;
    int32_t count = 0;
    for (TDF_ChildIterator it(label, allLevels); it.More() && count < maxCount; it.Next())
    {
      outLabelIds[count] = doc->registerLabel(it.Value());
      count++;
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTDocumentLabelSetReference(OCCTDocumentRef doc, int64_t labelId, int64_t targetLabelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label  = doc->getLabel(labelId);
    TDF_Label target = doc->getLabel(targetLabelId);
    if (label.IsNull() || target.IsNull())
      return false;
    TDF_Reference::Set(label, target);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int64_t OCCTDocumentLabelGetReference(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return -1;
    Handle(TDF_Reference) ref;
    if (!label.FindAttribute(TDF_Reference::GetID(), ref))
      return -1;
    TDF_Label target = ref->Get();
    if (target.IsNull())
      return -1;
    return doc->registerLabel(target);
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDocumentCopyLabel(OCCTDocumentRef doc, int64_t sourceLabelId, int64_t destLabelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label source = doc->getLabel(sourceLabelId);
    TDF_Label dest   = doc->getLabel(destLabelId);
    if (source.IsNull() || dest.IsNull())
      return false;
    TDF_CopyLabel copier(source, dest);
    copier.Perform();
    return copier.IsDone();
  }
  catch (...)
  {
    return false;
  }
}

int64_t OCCTDocumentGetMainLabel(OCCTDocumentRef doc)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  try
  {
    TDF_Label main = doc->doc->Main();
    if (main.IsNull())
      return -1;
    return doc->registerLabel(main);
  }
  catch (...)
  {
    return -1;
  }
}

void OCCTDocumentOpenTransaction(OCCTDocumentRef doc)
{
  if (!doc || doc->doc.IsNull())
    return;
  try
  {
    // An unnamed open supersedes any name left pending by an earlier one (#970).
    doc->pendingTransactionName.clear();
    doc->doc->OpenCommand();
  }
  catch (...)
  {
  }
}

bool OCCTDocumentCommitTransaction(OCCTDocumentRef doc)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    const bool committed = doc->doc->CommitCommand();
    occtApplyPendingTransactionName(doc, committed);
    return committed;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTDocumentAbortTransaction(OCCTDocumentRef doc)
{
  if (!doc || doc->doc.IsNull())
    return;
  try
  {
    doc->doc->AbortCommand();
    doc->pendingTransactionName.clear();
  }
  catch (...)
  {
  }
}

bool OCCTDocumentHasOpenTransaction(OCCTDocumentRef doc)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    return doc->doc->HasOpenCommand();
  }
  catch (...)
  {
    return false;
  }
}

void OCCTDocumentSetUndoLimit(OCCTDocumentRef doc, int32_t limit)
{
  if (!doc || doc->doc.IsNull())
    return;
  try
  {
    doc->doc->SetUndoLimit(limit);
  }
  catch (...)
  {
  }
}

int32_t OCCTDocumentGetUndoLimit(OCCTDocumentRef doc)
{
  if (!doc || doc->doc.IsNull())
    return 0;
  try
  {
    return doc->doc->GetUndoLimit();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTDocumentUndo(OCCTDocumentRef doc)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    return doc->doc->Undo();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentRedo(OCCTDocumentRef doc)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    return doc->doc->Redo();
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTDocumentGetAvailableUndos(OCCTDocumentRef doc)
{
  if (!doc || doc->doc.IsNull())
    return 0;
  try
  {
    return doc->doc->GetAvailableUndos();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTDocumentGetAvailableRedos(OCCTDocumentRef doc)
{
  if (!doc || doc->doc.IsNull())
    return 0;
  try
  {
    return doc->doc->GetAvailableRedos();
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTDocumentSetModified(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return;
    doc->doc->SetModified(label);
  }
  catch (...)
  {
  }
}

void OCCTDocumentClearModified(OCCTDocumentRef doc)
{
  if (!doc || doc->doc.IsNull())
    return;
  try
  {
    doc->doc->PurgeModified();
  }
  catch (...)
  {
  }
}

bool OCCTDocumentIsLabelModified(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    const auto& modified = doc->doc->GetModified();
    return modified.Contains(label);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentNamedDataSetInteger(OCCTDocumentRef doc,
                                     int64_t         labelId,
                                     const char*     name,
                                     int32_t         value)
{
  if (!doc || doc->doc.IsNull() || !name)
    return false;
  try
  {
    auto nd = getOrCreateNamedData(doc, labelId);
    if (nd.IsNull())
      return false;
    nd->SetInteger(TCollection_AsciiString(name), value);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentNamedDataGetInteger(OCCTDocumentRef doc,
                                     int64_t         labelId,
                                     const char*     name,
                                     int32_t*        outValue)
{
  if (!doc || doc->doc.IsNull() || !name || !outValue)
    return false;
  try
  {
    auto nd = findNamedData(doc, labelId);
    if (nd.IsNull())
      return false;
    TCollection_AsciiString key(name);
    if (!nd->HasInteger(key))
      return false;
    *outValue = nd->GetInteger(key);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentNamedDataHasInteger(OCCTDocumentRef doc, int64_t labelId, const char* name)
{
  if (!doc || doc->doc.IsNull() || !name)
    return false;
  try
  {
    auto nd = findNamedData(doc, labelId);
    if (nd.IsNull())
      return false;
    return nd->HasInteger(TCollection_AsciiString(name));
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentNamedDataSetReal(OCCTDocumentRef doc,
                                  int64_t         labelId,
                                  const char*     name,
                                  double          value)
{
  if (!doc || doc->doc.IsNull() || !name)
    return false;
  try
  {
    auto nd = getOrCreateNamedData(doc, labelId);
    if (nd.IsNull())
      return false;
    nd->SetReal(TCollection_AsciiString(name), value);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentNamedDataGetReal(OCCTDocumentRef doc,
                                  int64_t         labelId,
                                  const char*     name,
                                  double*         outValue)
{
  if (!doc || doc->doc.IsNull() || !name || !outValue)
    return false;
  try
  {
    auto nd = findNamedData(doc, labelId);
    if (nd.IsNull())
      return false;
    TCollection_AsciiString key(name);
    if (!nd->HasReal(key))
      return false;
    *outValue = nd->GetReal(key);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentNamedDataHasReal(OCCTDocumentRef doc, int64_t labelId, const char* name)
{
  if (!doc || doc->doc.IsNull() || !name)
    return false;
  try
  {
    auto nd = findNamedData(doc, labelId);
    if (nd.IsNull())
      return false;
    return nd->HasReal(TCollection_AsciiString(name));
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentNamedDataSetString(OCCTDocumentRef doc,
                                    int64_t         labelId,
                                    const char*     name,
                                    const char*     value)
{
  if (!doc || doc->doc.IsNull() || !name || !value)
    return false;
  try
  {
    auto nd = getOrCreateNamedData(doc, labelId);
    if (nd.IsNull())
      return false;
    nd->SetString(TCollection_AsciiString(name), TCollection_ExtendedString(value, true));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

const char* OCCTDocumentNamedDataGetString(OCCTDocumentRef doc, int64_t labelId, const char* name)
{
  if (!doc || doc->doc.IsNull() || !name)
    return nullptr;
  try
  {
    auto nd = findNamedData(doc, labelId);
    if (nd.IsNull())
      return nullptr;
    TCollection_AsciiString key(name);
    if (!nd->HasString(key))
      return nullptr;
    TCollection_AsciiString ascii(nd->GetString(key));
    return strdup(ascii.ToCString());
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTDocumentNamedDataHasString(OCCTDocumentRef doc, int64_t labelId, const char* name)
{
  if (!doc || doc->doc.IsNull() || !name)
    return false;
  try
  {
    auto nd = findNamedData(doc, labelId);
    if (nd.IsNull())
      return false;
    return nd->HasString(TCollection_AsciiString(name));
  }
  catch (...)
  {
    return false;
  }
}

void OCCTDocumentDefineFormatBin(OCCTDocumentRef doc)
{
  if (!doc || doc->app.IsNull())
    return;
  std::lock_guard<std::mutex> storeLock(ocafStoreMutex());
  try
  {
    BinDrivers::DefineFormat(doc->app);
  }
  catch (...)
  {
  }
}

void OCCTDocumentDefineFormatBinL(OCCTDocumentRef doc)
{
  if (!doc || doc->app.IsNull())
    return;
  std::lock_guard<std::mutex> storeLock(ocafStoreMutex());
  try
  {
    BinLDrivers::DefineFormat(doc->app);
  }
  catch (...)
  {
  }
}

void OCCTDocumentDefineFormatXml(OCCTDocumentRef doc)
{
  if (!doc || doc->app.IsNull())
    return;
  std::lock_guard<std::mutex> storeLock(ocafStoreMutex());
  try
  {
    XmlDrivers::DefineFormat(doc->app);
  }
  catch (...)
  {
  }
}

void OCCTDocumentDefineFormatXmlL(OCCTDocumentRef doc)
{
  if (!doc || doc->app.IsNull())
    return;
  std::lock_guard<std::mutex> storeLock(ocafStoreMutex());
  try
  {
    XmlLDrivers::DefineFormat(doc->app);
  }
  catch (...)
  {
  }
}

void OCCTDocumentDefineFormatBinXCAF(OCCTDocumentRef doc)
{
  if (!doc || doc->app.IsNull())
    return;
  std::lock_guard<std::mutex> storeLock(ocafStoreMutex());
  try
  {
    BinXCAFDrivers::DefineFormat(doc->app);
  }
  catch (...)
  {
  }
}

void OCCTDocumentDefineFormatXmlXCAF(OCCTDocumentRef doc)
{
  if (!doc || doc->app.IsNull())
    return;
  std::lock_guard<std::mutex> storeLock(ocafStoreMutex());
  try
  {
    XmlXCAFDrivers::DefineFormat(doc->app);
  }
  catch (...)
  {
  }
}

// #349/#371: interim serialization for OCAF Save/Load/DefineFormat, see OCCTBridge_Internal.h.
std::mutex& ocafStoreMutex()
{
  static std::mutex mutex;
  return mutex;
}

int32_t OCCTDocumentSaveOCAF(OCCTDocumentRef doc, const char* path)
{
  if (!doc || doc->doc.IsNull() || !path)
    return -1;
  try
  {
    std::lock_guard<std::mutex> storeLock(ocafStoreMutex());
    TCollection_ExtendedString  ePath(path, true);
    PCDM_StoreStatus            status = doc->app->SaveAs(doc->doc, ePath);
    return static_cast<int32_t>(status);
  }
  catch (...)
  {
    return -1;
  }
}

OCCTDocumentRef OCCTDocumentLoadOCAF(const char* path, int32_t* outStatus)
{
  if (!path)
  {
    if (outStatus)
      *outStatus = -1;
    return nullptr;
  }
  OCCTDocument* document = nullptr;
  try
  {
    std::lock_guard<std::mutex> storeLock(ocafStoreMutex());
    // #371: document->app (not a separate local app) must be the one that opens the file --
    // Save/SaveOCAFInPlace/Close later all go through document->app, and a document opened by
    // one TDocStd_Application instance isn't a session member of a different one.
    document = new OCCTDocument();

    // Register all format drivers
    BinDrivers::DefineFormat(document->app);
    XmlDrivers::DefineFormat(document->app);
    BinXCAFDrivers::DefineFormat(document->app);
    XmlXCAFDrivers::DefineFormat(document->app);

    // #371: no PCDM_RS_AlreadyRetrieved handling needed -- that status meant this path was
    // already open in the app's session directory, which could only happen when every load
    // shared one process-wide app/directory. document->app is fresh per call, so its
    // directory is always empty at this point; the status can't occur.
    Handle(TDocStd_Document)   loadedDoc;
    TCollection_ExtendedString ePath(path, true);
    PCDM_ReaderStatus          status = document->app->Open(ePath, loadedDoc);

    if (outStatus)
      *outStatus = static_cast<int32_t>(status);

    if (status != PCDM_RS_OK || loadedDoc.IsNull())
    {
      delete document;
      return nullptr;
    }

    document->doc          = loadedDoc;
    document->shapeTool    = XCAFDoc_DocumentTool::ShapeTool(loadedDoc->Main());
    document->colorTool    = XCAFDoc_DocumentTool::ColorTool(loadedDoc->Main());
    document->materialTool = XCAFDoc_DocumentTool::VisMaterialTool(loadedDoc->Main());

    return document;
  }
  catch (...)
  {
    delete document;
    if (outStatus)
      *outStatus = -1;
    return nullptr;
  }
}

int32_t OCCTDocumentSaveOCAFInPlace(OCCTDocumentRef doc)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  try
  {
    std::lock_guard<std::mutex> storeLock(ocafStoreMutex());
    if (!doc->doc->IsSaved())
      return -1;
    PCDM_StoreStatus status = doc->app->Save(doc->doc);
    return static_cast<int32_t>(status);
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDocumentIsSaved(OCCTDocumentRef doc)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    return doc->doc->IsSaved();
  }
  catch (...)
  {
    return false;
  }
}

const char* OCCTDocumentGetStorageFormat(OCCTDocumentRef doc)
{
  if (!doc || doc->doc.IsNull())
    return nullptr;
  try
  {
    TCollection_AsciiString ascii(doc->doc->StorageFormat());
    return strdup(ascii.ToCString());
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTDocumentSetStorageFormat(OCCTDocumentRef doc, const char* format)
{
  if (!doc || doc->doc.IsNull() || !format)
    return false;
  try
  {
    doc->doc->ChangeStorageFormat(TCollection_ExtendedString(format, true));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTDocumentNbDocuments(OCCTDocumentRef doc)
{
  if (!doc || doc->app.IsNull())
    return 0;
  try
  {
    return doc->app->NbDocuments();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTDocumentReadingFormats(OCCTDocumentRef doc, const char** outFormats, int32_t maxFormats)
{
  return occtDocumentFormatsImpl(doc, outFormats, maxFormats, &TDocStd_Application::ReadingFormats);
}

int32_t OCCTDocumentWritingFormats(OCCTDocumentRef doc, const char** outFormats, int32_t maxFormats)
{
  return occtDocumentFormatsImpl(doc, outFormats, maxFormats, &TDocStd_Application::WritingFormats);
}

OCCTDocumentRef OCCTDocumentCreateWithFormat(const char* format)
{
  if (!format)
    return nullptr;
  OCCTDocument* document = nullptr;
  try
  {
    document = new OCCTDocument();
    TCollection_ExtendedString eFormat(format, true);

    // Register all format drivers (#371: ocafStoreMutex() covers DefineFormat too)
    std::lock_guard<std::mutex> storeLock(ocafStoreMutex());
    BinDrivers::DefineFormat(document->app);
    XmlDrivers::DefineFormat(document->app);
    BinXCAFDrivers::DefineFormat(document->app);
    XmlXCAFDrivers::DefineFormat(document->app);

    document->app->NewDocument(eFormat, document->doc);
    if (document->doc.IsNull())
    {
      delete document;
      return nullptr;
    }

    // Initialize XCAF tools if format is XCAF
    TCollection_AsciiString asciiFormat(format);
    if (asciiFormat.Search("XCAF") >= 0 || asciiFormat.Search("xcaf") >= 0)
    {
      document->shapeTool    = XCAFDoc_DocumentTool::ShapeTool(document->doc->Main());
      document->colorTool    = XCAFDoc_DocumentTool::ColorTool(document->doc->Main());
      document->materialTool = XCAFDoc_DocumentTool::VisMaterialTool(document->doc->Main());
    }

    return document;
  }
  catch (...)
  {
    delete document;
    return nullptr;
  }
}

int32_t OCCTDocumentGetShapeCount(OCCTDocumentRef doc)
{
  if (!doc || doc->shapeTool.IsNull())
    return 0;
  try
  {
    TDF_LabelSequence shapes;
    doc->shapeTool->GetShapes(shapes);
    return shapes.Length();
  }
  catch (...)
  {
    return 0;
  }
}

int64_t OCCTDocumentGetShapeLabelId(OCCTDocumentRef doc, int32_t index)
{
  if (!doc || doc->shapeTool.IsNull())
    return -1;
  try
  {
    TDF_LabelSequence shapes;
    doc->shapeTool->GetShapes(shapes);
    if (index < 0 || index >= shapes.Length())
      return -1;
    return doc->registerLabel(shapes.Value(index + 1));
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTDocumentGetFreeShapeCount(OCCTDocumentRef doc)
{
  if (!doc || doc->shapeTool.IsNull())
    return 0;
  try
  {
    TDF_LabelSequence shapes;
    doc->shapeTool->GetFreeShapes(shapes);
    return shapes.Length();
  }
  catch (...)
  {
    return 0;
  }
}

int64_t OCCTDocumentGetFreeShapeLabelId(OCCTDocumentRef doc, int32_t index)
{
  if (!doc || doc->shapeTool.IsNull())
    return -1;
  try
  {
    TDF_LabelSequence shapes;
    doc->shapeTool->GetFreeShapes(shapes);
    if (index < 0 || index >= shapes.Length())
      return -1;
    return doc->registerLabel(shapes.Value(index + 1));
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDocumentIsTopLevel(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->shapeTool.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    return doc->shapeTool->IsTopLevel(label);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentIsComponent(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->shapeTool.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    return doc->shapeTool->IsComponent(label);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentIsCompound(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->shapeTool.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    return doc->shapeTool->IsCompound(label);
  }
  catch (...)
  {
    return false;
  }
}

int64_t OCCTDocumentFindShape(OCCTDocumentRef doc, OCCTShapeRef shape)
{
  if (!doc || !shape || doc->shapeTool.IsNull())
    return -1;
  try
  {
    TDF_Label label;
    bool      found = doc->shapeTool->FindShape(shape->shape, label);
    if (!found || label.IsNull())
      return -1;
    return doc->registerLabel(label);
  }
  catch (...)
  {
    return -1;
  }
}

int64_t OCCTDocumentSearchShape(OCCTDocumentRef doc, OCCTShapeRef shape)
{
  if (!doc || !shape || doc->shapeTool.IsNull())
    return -1;
  try
  {
    TDF_Label label;
    bool      found = doc->shapeTool->Search(shape->shape, label);
    if (!found || label.IsNull())
      return -1;
    return doc->registerLabel(label);
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTDocumentGetSubShapeCount(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->shapeTool.IsNull())
    return 0;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return 0;
    TDF_LabelSequence subShapes;
    doc->shapeTool->GetSubShapes(label, subShapes);
    return subShapes.Length();
  }
  catch (...)
  {
    return 0;
  }
}

int64_t OCCTDocumentGetSubShapeLabelId(OCCTDocumentRef doc, int64_t labelId, int32_t index)
{
  if (!doc || doc->shapeTool.IsNull())
    return -1;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return -1;
    TDF_LabelSequence subShapes;
    doc->shapeTool->GetSubShapes(label, subShapes);
    if (index < 0 || index >= subShapes.Length())
      return -1;
    return doc->registerLabel(subShapes.Value(index + 1));
  }
  catch (...)
  {
    return -1;
  }
}

int64_t OCCTDocumentAddShape(OCCTDocumentRef doc, OCCTShapeRef shape, bool makeAssembly)
{
  if (!doc || !shape || doc->shapeTool.IsNull())
    return -1;
  try
  {
    TDF_Label label = doc->shapeTool->AddShape(shape->shape, makeAssembly);
    if (label.IsNull())
      return -1;
    return doc->registerLabel(label);
  }
  catch (...)
  {
    return -1;
  }
}

int64_t OCCTDocumentNewShape(OCCTDocumentRef doc)
{
  if (!doc || doc->shapeTool.IsNull())
    return -1;
  try
  {
    TDF_Label label = doc->shapeTool->NewShape();
    if (label.IsNull())
      return -1;
    return doc->registerLabel(label);
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDocumentRemoveShape(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->shapeTool.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    return doc->shapeTool->RemoveShape(label);
  }
  catch (...)
  {
    return false;
  }
}

int64_t OCCTDocumentAddComponent(OCCTDocumentRef doc,
                                 int64_t         assemblyLabelId,
                                 int64_t         shapeLabelId,
                                 double          tx,
                                 double          ty,
                                 double          tz)
{
  if (!doc || doc->shapeTool.IsNull())
    return -1;
  try
  {
    TDF_Label assemblyLabel = doc->getLabel(assemblyLabelId);
    TDF_Label shapeLabel    = doc->getLabel(shapeLabelId);
    if (assemblyLabel.IsNull() || shapeLabel.IsNull())
      return -1;
    gp_Trsf trsf;
    trsf.SetTranslation(gp_Vec(tx, ty, tz));
    TDF_Label comp = doc->shapeTool->AddComponent(assemblyLabel, shapeLabel, TopLoc_Location(trsf));
    if (comp.IsNull())
      return -1;
    return doc->registerLabel(comp);
  }
  catch (...)
  {
    return -1;
  }
}

int64_t OCCTDocumentAddComponentMatrix(OCCTDocumentRef doc,
                                       int64_t         assemblyLabelId,
                                       int64_t         shapeLabelId,
                                       const double*   matrix12)
{
  if (!doc || doc->shapeTool.IsNull() || !matrix12)
    return -1;
  try
  {
    TDF_Label assemblyLabel = doc->getLabel(assemblyLabelId);
    TDF_Label shapeLabel    = doc->getLabel(shapeLabelId);
    if (assemblyLabel.IsNull() || shapeLabel.IsNull())
      return -1;
    // #1009: GROUPED layout, nine rotation values then three translations. The reader is shared
    // with OCCTShapeTransformed and OCCTCurve3DParametricTransformation; the layout is in its name
    // because the INTERLEAVED sibling accepts the same array and builds a different transform.
    //
    // The comment that stood here said gp_Trsf::SetValues "throws if not a proper rigid
    // (orthonormal, det +1) transform", so reflections had to be baked as a mirrored product
    // (#174). Measured against the pinned kernel, it throws for none of them. Its own header names
    // a null determinant as the single precondition, not orthonormality, and SetValues is
    // Standard_EXPORT, compiled inside OCCT's Release TUs where No_Exception removes even that: a
    // reflection (det -1), a singular matrix, an all-zero matrix and a shear are each accepted. A
    // reflection also works rather than merely being tolerated, reporting ScaleFactor() -1 and
    // moving a box's centre of mass from x = 6 to x = -6 with its volume unchanged. So a caller
    // handing this function a mirrored placement gets the mirror, and #174's premise that gp_Trsf
    // rejects reflections does not hold here. Scripts/repro/1009-matrix12-grouped/ has the run.
    TDF_Label comp =
      doc->shapeTool->AddComponent(assemblyLabel,
                                   shapeLabel,
                                   TopLoc_Location(occtTrsfFromMatrix12Grouped(matrix12)));
    if (comp.IsNull())
      return -1;
    return doc->registerLabel(comp);
  }
  catch (...)
  {
    return -1;
  }
}

void OCCTDocumentRemoveComponent(OCCTDocumentRef doc, int64_t componentLabelId)
{
  if (!doc || doc->shapeTool.IsNull())
    return;
  try
  {
    TDF_Label label = doc->getLabel(componentLabelId);
    if (label.IsNull())
      return;
    doc->shapeTool->RemoveComponent(label);
  }
  catch (...)
  {
  }
}

int32_t OCCTDocumentGetComponentCount(OCCTDocumentRef doc, int64_t assemblyLabelId)
{
  if (!doc || doc->shapeTool.IsNull())
    return 0;
  try
  {
    TDF_Label label = doc->getLabel(assemblyLabelId);
    if (label.IsNull())
      return 0;
    TDF_LabelSequence components;
    doc->shapeTool->GetComponents(label, components);
    return components.Length();
  }
  catch (...)
  {
    return 0;
  }
}

int64_t OCCTDocumentGetComponentLabelId(OCCTDocumentRef doc, int64_t assemblyLabelId, int32_t index)
{
  if (!doc || doc->shapeTool.IsNull())
    return -1;
  try
  {
    TDF_Label label = doc->getLabel(assemblyLabelId);
    if (label.IsNull())
      return -1;
    TDF_LabelSequence components;
    doc->shapeTool->GetComponents(label, components);
    if (index < 0 || index >= components.Length())
      return -1;
    return doc->registerLabel(components.Value(index + 1));
  }
  catch (...)
  {
    return -1;
  }
}

int64_t OCCTDocumentGetComponentReferredLabelId(OCCTDocumentRef doc, int64_t componentLabelId)
{
  if (!doc || doc->shapeTool.IsNull())
    return -1;
  try
  {
    TDF_Label label = doc->getLabel(componentLabelId);
    if (label.IsNull())
      return -1;
    TDF_Label referred;
    bool      ok = doc->shapeTool->GetReferredShape(label, referred);
    if (!ok || referred.IsNull())
      return -1;
    return doc->registerLabel(referred);
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTDocumentGetShapeUserCount(OCCTDocumentRef doc, int64_t shapeLabelId)
{
  if (!doc || doc->shapeTool.IsNull())
    return 0;
  try
  {
    TDF_Label label = doc->getLabel(shapeLabelId);
    if (label.IsNull())
      return 0;
    TDF_LabelSequence users;
    return doc->shapeTool->GetUsers(label, users);
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTDocumentUpdateAssemblies(OCCTDocumentRef doc)
{
  if (!doc || doc->shapeTool.IsNull())
    return;
  try
  {
    doc->shapeTool->UpdateAssemblies();
  }
  catch (...)
  {
  }
}

bool OCCTDocumentExpandShape(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->shapeTool.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    return doc->shapeTool->Expand(label);
  }
  catch (...)
  {
    return false;
  }
}

void OCCTDocumentSetShapeColor(OCCTDocumentRef doc,
                               OCCTShapeRef    shape,
                               int32_t         colorType,
                               double          r,
                               double          g,
                               double          b)
{
  // #763: delegates rather than storing through the RGB-only SetColor overload. It has no callers
  // left (Document.setShapeColor moved to the RGBA entry point), but it stays exported and so
  // stays reachable, and the two bodies side by side were one copy-paste away from silently
  // reintroducing the alpha loss this pass just fixed. Opaque is the only alpha an RGB-only
  // caller can mean.
  OCCTDocumentSetShapeColorRGBA(doc, shape, colorType, r, g, b, 1.0f);
}

void OCCTDocumentSetLabelVisibility(OCCTDocumentRef doc, int64_t labelId, bool visible)
{
  if (!doc || doc->colorTool.IsNull())
    return;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return;
    doc->colorTool->SetVisibility(label, visible);
  }
  catch (...)
  {
  }
}

bool OCCTDocumentGetLabelVisibility(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->colorTool.IsNull())
    return true;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return true;
    return doc->colorTool->IsVisible(label);
  }
  catch (...)
  {
    return true;
  }
}

void OCCTDocumentSetArea(OCCTDocumentRef doc, int64_t labelId, double area)
{
  if (!doc)
    return;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return;
    XCAFDoc_Area::Set(label, area);
  }
  catch (...)
  {
  }
}

double OCCTDocumentGetArea(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc)
    return -1;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return -1;
    double area;
    if (XCAFDoc_Area::Get(label, area))
      return area;
  }
  catch (...)
  {
  }
  return -1;
}

void OCCTDocumentSetVolume(OCCTDocumentRef doc, int64_t labelId, double volume)
{
  if (!doc)
    return;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return;
    XCAFDoc_Volume::Set(label, volume);
  }
  catch (...)
  {
  }
}

double OCCTDocumentGetVolume(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc)
    return -1;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return -1;
    double vol;
    if (XCAFDoc_Volume::Get(label, vol))
      return vol;
  }
  catch (...)
  {
  }
  return -1;
}

void OCCTDocumentSetCentroid(OCCTDocumentRef doc, int64_t labelId, double x, double y, double z)
{
  if (!doc)
    return;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return;
    XCAFDoc_Centroid::Set(label, gp_Pnt(x, y, z));
  }
  catch (...)
  {
  }
}

bool OCCTDocumentGetCentroid(OCCTDocumentRef doc,
                             int64_t         labelId,
                             double*         outX,
                             double*         outY,
                             double*         outZ)
{
  if (!doc)
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    gp_Pnt centroid;
    if (XCAFDoc_Centroid::Get(label, centroid))
    {
      if (outX)
        *outX = centroid.X();
      if (outY)
        *outY = centroid.Y();
      if (outZ)
        *outZ = centroid.Z();
      return true;
    }
  }
  catch (...)
  {
  }
  return false;
}

void OCCTDocumentSetLayer(OCCTDocumentRef doc, int64_t labelId, const char* layerName)
{
  if (!doc || !layerName)
    return;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return;
    Handle(XCAFDoc_LayerTool) layerTool = XCAFDoc_DocumentTool::LayerTool(doc->doc->Main());
    layerTool->SetLayer(label, TCollection_ExtendedString(layerName));
  }
  catch (...)
  {
  }
}

bool OCCTDocumentIsLayerSet(OCCTDocumentRef doc, int64_t labelId, const char* layerName)
{
  if (!doc || !layerName)
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(XCAFDoc_LayerTool) layerTool = XCAFDoc_DocumentTool::LayerTool(doc->doc->Main());
    return layerTool->IsSet(label, TCollection_ExtendedString(layerName));
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTDocumentGetLabelLayers(OCCTDocumentRef doc,
                                   int64_t         labelId,
                                   char**          outNames,
                                   int32_t         maxNames,
                                   int32_t         maxLen)
{
  if (!doc || !outNames)
    return 0;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return 0;
    Handle(XCAFDoc_LayerTool) layerTool = XCAFDoc_DocumentTool::LayerTool(doc->doc->Main());
    Handle(NCollection_HSequence<TCollection_ExtendedString>) layers = layerTool->GetLayers(label);
    if (layers.IsNull())
      return 0;
    int32_t count = std::min((int32_t)layers->Length(), maxNames);
    for (int32_t i = 0; i < count; i++)
    {
      TCollection_AsciiString ascii(layers->Value(i + 1));
      strncpy(outNames[i], ascii.ToCString(), maxLen - 1);
      outNames[i][maxLen - 1] = '\0';
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

int64_t OCCTDocumentFindLayer(OCCTDocumentRef doc, const char* layerName)
{
  if (!doc || !layerName)
    return -1;
  try
  {
    Handle(XCAFDoc_LayerTool) layerTool = XCAFDoc_DocumentTool::LayerTool(doc->doc->Main());
    TDF_Label layerLabel = layerTool->FindLayer(TCollection_ExtendedString(layerName));
    if (layerLabel.IsNull())
      return -1;
    return doc->registerLabel(layerLabel);
  }
  catch (...)
  {
    return -1;
  }
}

void OCCTDocumentSetLayerVisibility(OCCTDocumentRef doc, int64_t layerLabelId, bool visible)
{
  if (!doc)
    return;
  try
  {
    TDF_Label label = doc->getLabel(layerLabelId);
    if (label.IsNull())
      return;
    Handle(XCAFDoc_LayerTool) layerTool = XCAFDoc_DocumentTool::LayerTool(doc->doc->Main());
    layerTool->SetVisibility(label, visible);
  }
  catch (...)
  {
  }
}

bool OCCTDocumentGetLayerVisibility(OCCTDocumentRef doc, int64_t layerLabelId)
{
  if (!doc)
    return true;
  try
  {
    TDF_Label label = doc->getLabel(layerLabelId);
    if (label.IsNull())
      return true;
    Handle(XCAFDoc_LayerTool) layerTool = XCAFDoc_DocumentTool::LayerTool(doc->doc->Main());
    return layerTool->IsVisible(label);
  }
  catch (...)
  {
    return true;
  }
}

bool OCCTDocumentSetNoteComment(OCCTDocumentRef ref,
                                int64_t         labelId,
                                const char*     userName,
                                const char*     timeStamp,
                                const char*     comment)
{
  if (!ref)
    return false;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    TCollection_ExtendedString  user(userName);
    TCollection_ExtendedString  ts(timeStamp);
    TCollection_ExtendedString  cmt(comment);
    Handle(XCAFDoc_NoteComment) attr = XCAFDoc_NoteComment::Set(label, user, ts, cmt);
    return !attr.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

const char* _Nullable OCCTDocumentGetNoteCommentText(OCCTDocumentRef ref, int64_t labelId)
{
  if (!ref)
    return nullptr;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return nullptr;
    Handle(XCAFDoc_NoteComment) attr;
    if (!label.FindAttribute(XCAFDoc_NoteComment::GetID(), attr))
      return nullptr;
    TCollection_ExtendedString es = attr->Comment();
    TCollection_AsciiString    as(es);
    char*                      result = (char*)malloc(as.Length() + 1);
    if (!result)
      return nullptr;
    memcpy(result, as.ToCString(), as.Length() + 1);
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

const char* _Nullable OCCTDocumentGetNoteUserName(OCCTDocumentRef ref, int64_t labelId)
{
  if (!ref)
    return nullptr;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return nullptr;
    // Try NoteComment first, then NoteBalloon, then NoteBinData
    Handle(XCAFDoc_NoteComment) nc;
    if (label.FindAttribute(XCAFDoc_NoteComment::GetID(), nc))
    {
      TCollection_ExtendedString es = nc->UserName();
      TCollection_AsciiString    as(es);
      char*                      result = (char*)malloc(as.Length() + 1);
      if (!result)
        return nullptr;
      memcpy(result, as.ToCString(), as.Length() + 1);
      return result;
    }
    Handle(XCAFDoc_NoteBalloon) nb;
    if (label.FindAttribute(XCAFDoc_NoteBalloon::GetID(), nb))
    {
      TCollection_ExtendedString es = nb->UserName();
      TCollection_AsciiString    as(es);
      char*                      result = (char*)malloc(as.Length() + 1);
      if (!result)
        return nullptr;
      memcpy(result, as.ToCString(), as.Length() + 1);
      return result;
    }
    return nullptr;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTDocumentSetNoteBalloon(OCCTDocumentRef ref,
                                int64_t         labelId,
                                const char*     userName,
                                const char*     timeStamp,
                                const char*     comment)
{
  if (!ref)
    return false;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    TCollection_ExtendedString  user(userName);
    TCollection_ExtendedString  ts(timeStamp);
    TCollection_ExtendedString  cmt(comment);
    Handle(XCAFDoc_NoteBalloon) attr = XCAFDoc_NoteBalloon::Set(label, user, ts, cmt);
    return !attr.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetNoteBinData(OCCTDocumentRef ref,
                                int64_t         labelId,
                                const char*     userName,
                                const char*     timeStamp,
                                const char*     title,
                                const char*     mimeType,
                                const uint8_t*  data,
                                int32_t         dataSize)
{
  if (!ref)
    return false;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    TCollection_ExtendedString           user(userName);
    TCollection_ExtendedString           ts(timeStamp);
    TCollection_ExtendedString           tit(title);
    TCollection_AsciiString              mime(mimeType);
    Handle(NCollection_HArray1<uint8_t>) arr = new NCollection_HArray1<uint8_t>(1, dataSize);
    for (int i = 0; i < dataSize; i++)
    {
      arr->SetValue(i + 1, data[i]);
    }
    Handle(XCAFDoc_NoteBinData) attr = XCAFDoc_NoteBinData::Set(label, user, ts, tit, mime, arr);
    return !attr.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTDocumentGetNoteBinDataSize(OCCTDocumentRef ref, int64_t labelId)
{
  if (!ref)
    return 0;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return 0;
    Handle(XCAFDoc_NoteBinData) attr;
    if (!label.FindAttribute(XCAFDoc_NoteBinData::GetID(), attr))
      return 0;
    return attr->Size();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTDocumentNotesToolNbNotes(OCCTDocumentRef ref)
{
  if (!ref)
    return -1;
  try
  {
    auto*                     doc  = (OCCTDocument*)ref;
    TDF_Label                 main = doc->doc->Main();
    Handle(XCAFDoc_NotesTool) tool = XCAFDoc_DocumentTool::NotesTool(main);
    if (tool.IsNull())
      return -1;
    return tool->NbNotes();
  }
  catch (...)
  {
    return -1;
  }
}

int64_t OCCTDocumentNotesToolCreateComment(OCCTDocumentRef ref,
                                           const char*     userName,
                                           const char*     timeStamp,
                                           const char*     comment)
{
  if (!ref)
    return -1;
  try
  {
    auto*                     doc  = (OCCTDocument*)ref;
    TDF_Label                 main = doc->doc->Main();
    Handle(XCAFDoc_NotesTool) tool = XCAFDoc_DocumentTool::NotesTool(main);
    if (tool.IsNull())
      return -1;
    TCollection_ExtendedString user(userName);
    TCollection_ExtendedString ts(timeStamp);
    TCollection_ExtendedString cmt(comment);
    Handle(XCAFDoc_Note)       note = tool->CreateComment(user, ts, cmt);
    if (note.IsNull())
      return -1;
    return doc->registerLabel(note->Label());
  }
  catch (...)
  {
    return -1;
  }
}

int64_t OCCTDocumentNotesToolCreateBalloon(OCCTDocumentRef ref,
                                           const char*     userName,
                                           const char*     timeStamp,
                                           const char*     comment)
{
  if (!ref)
    return -1;
  try
  {
    auto*                     doc  = (OCCTDocument*)ref;
    TDF_Label                 main = doc->doc->Main();
    Handle(XCAFDoc_NotesTool) tool = XCAFDoc_DocumentTool::NotesTool(main);
    if (tool.IsNull())
      return -1;
    TCollection_ExtendedString user(userName);
    TCollection_ExtendedString ts(timeStamp);
    TCollection_ExtendedString cmt(comment);
    Handle(XCAFDoc_Note)       note = tool->CreateBalloon(user, ts, cmt);
    if (note.IsNull())
      return -1;
    return doc->registerLabel(note->Label());
  }
  catch (...)
  {
    return -1;
  }
}

int64_t OCCTDocumentNotesToolCreateBinData(OCCTDocumentRef ref,
                                           const char*     userName,
                                           const char*     timeStamp,
                                           const char*     title,
                                           const char*     mimeType,
                                           const uint8_t*  data,
                                           int32_t         dataSize)
{
  if (!ref)
    return -1;
  try
  {
    auto*                     doc  = (OCCTDocument*)ref;
    TDF_Label                 main = doc->doc->Main();
    Handle(XCAFDoc_NotesTool) tool = XCAFDoc_DocumentTool::NotesTool(main);
    if (tool.IsNull())
      return -1;
    TCollection_ExtendedString           user(userName);
    TCollection_ExtendedString           ts(timeStamp);
    TCollection_ExtendedString           tit(title);
    TCollection_AsciiString              mime(mimeType);
    Handle(NCollection_HArray1<uint8_t>) arr = new NCollection_HArray1<uint8_t>(1, dataSize);
    for (int i = 0; i < dataSize; i++)
    {
      arr->SetValue(i + 1, data[i]);
    }
    Handle(XCAFDoc_Note) note = tool->CreateBinData(user, ts, tit, mime, arr);
    if (note.IsNull())
      return -1;
    return doc->registerLabel(note->Label());
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDocumentNotesToolDeleteNote(OCCTDocumentRef ref, int64_t noteLabelId)
{
  if (!ref)
    return false;
  try
  {
    auto*                     doc  = (OCCTDocument*)ref;
    TDF_Label                 main = doc->doc->Main();
    Handle(XCAFDoc_NotesTool) tool = XCAFDoc_DocumentTool::NotesTool(main);
    if (tool.IsNull())
      return false;
    TDF_Label noteLabel = doc->getLabel(noteLabelId);
    if (noteLabel.IsNull())
      return false;
    return tool->DeleteNote(noteLabel);
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTDocumentNotesToolDeleteAllNotes(OCCTDocumentRef ref)
{
  if (!ref)
    return 0;
  try
  {
    auto*                     doc  = (OCCTDocument*)ref;
    TDF_Label                 main = doc->doc->Main();
    Handle(XCAFDoc_NotesTool) tool = XCAFDoc_DocumentTool::NotesTool(main);
    if (tool.IsNull())
      return 0;
    return tool->DeleteAllNotes();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTDocumentNotesToolNbOrphanNotes(OCCTDocumentRef ref)
{
  if (!ref)
    return 0;
  try
  {
    auto*                     doc  = (OCCTDocument*)ref;
    TDF_Label                 main = doc->doc->Main();
    Handle(XCAFDoc_NotesTool) tool = XCAFDoc_DocumentTool::NotesTool(main);
    if (tool.IsNull())
      return 0;
    return tool->NbOrphanNotes();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTDocumentNotesToolDeleteOrphanNotes(OCCTDocumentRef ref)
{
  if (!ref)
    return 0;
  try
  {
    auto*                     doc  = (OCCTDocument*)ref;
    TDF_Label                 main = doc->doc->Main();
    Handle(XCAFDoc_NotesTool) tool = XCAFDoc_DocumentTool::NotesTool(main);
    if (tool.IsNull())
      return 0;
    return tool->DeleteOrphanNotes();
  }
  catch (...)
  {
    return 0;
  }
}

OCCTAssemblyGraphRef OCCTAssemblyGraphCreate(OCCTDocumentRef ref)
{
  if (!ref)
    return nullptr;
  try
  {
    auto*                         doc   = (OCCTDocument*)ref;
    Handle(XCAFDoc_AssemblyGraph) graph = new XCAFDoc_AssemblyGraph(doc->doc);
    if (graph.IsNull())
      return nullptr;
    return (OCCTAssemblyGraphRef) new OCCTAssemblyGraph{graph};
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTAssemblyGraphRelease(OCCTAssemblyGraphRef ref)
{
  delete (OCCTAssemblyGraph*)ref;
}

int32_t OCCTAssemblyGraphNbNodes(OCCTAssemblyGraphRef ref)
{
  if (!ref)
    return 0;
  try
  {
    return ((OCCTAssemblyGraph*)ref)->graph->NbNodes();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTAssemblyGraphNbLinks(OCCTAssemblyGraphRef ref)
{
  if (!ref)
    return 0;
  try
  {
    return ((OCCTAssemblyGraph*)ref)->graph->NbLinks();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTAssemblyGraphNbRoots(OCCTAssemblyGraphRef ref)
{
  if (!ref)
    return 0;
  try
  {
    auto& roots = ((OCCTAssemblyGraph*)ref)->graph->GetRoots();
    return roots.Extent();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTAssemblyGraphGetNodeType(OCCTAssemblyGraphRef ref, int32_t nodeIndex)
{
  if (!ref)
    return -1;
  try
  {
    return (int32_t)((OCCTAssemblyGraph*)ref)->graph->GetNodeType(nodeIndex);
  }
  catch (...)
  {
    return -1;
  }
}

OCCTViewObjectRef OCCTViewObjectCreate(void)
{
  try
  {
    return (OCCTViewObjectRef) new OCCTViewObject{new XCAFView_Object()};
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTViewObjectRelease(OCCTViewObjectRef ref)
{
  delete (OCCTViewObject*)ref;
}

void OCCTViewObjectSetType(OCCTViewObjectRef ref, int32_t type)
{
  if (!ref)
    return;
  try
  {
    ((OCCTViewObject*)ref)->obj->SetType((XCAFView_ProjectionType)type);
  }
  catch (...)
  {
  }
}

int32_t OCCTViewObjectGetType(OCCTViewObjectRef ref)
{
  if (!ref)
    return 0;
  try
  {
    return (int32_t)((OCCTViewObject*)ref)->obj->Type();
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTViewObjectSetViewDirection(OCCTViewObjectRef ref, double x, double y, double z)
{
  if (!ref)
    return;
  try
  {
    ((OCCTViewObject*)ref)->obj->SetViewDirection(gp_Dir(x, y, z));
  }
  catch (...)
  {
  }
}

void OCCTViewObjectGetViewDirection(OCCTViewObjectRef ref, double* x, double* y, double* z)
{
  if (!ref)
  {
    *x = 0;
    *y = 0;
    *z = -1;
    return;
  }
  try
  {
    gp_Dir dir = ((OCCTViewObject*)ref)->obj->ViewDirection();
    *x         = dir.X();
    *y         = dir.Y();
    *z         = dir.Z();
  }
  catch (...)
  {
    *x = 0;
    *y = 0;
    *z = -1;
  }
}

void OCCTViewObjectSetUpDirection(OCCTViewObjectRef ref, double x, double y, double z)
{
  if (!ref)
    return;
  try
  {
    ((OCCTViewObject*)ref)->obj->SetUpDirection(gp_Dir(x, y, z));
  }
  catch (...)
  {
  }
}

void OCCTViewObjectGetUpDirection(OCCTViewObjectRef ref, double* x, double* y, double* z)
{
  if (!ref)
  {
    *x = 0;
    *y = 0;
    *z = 1;
    return;
  }
  try
  {
    gp_Dir dir = ((OCCTViewObject*)ref)->obj->UpDirection();
    *x         = dir.X();
    *y         = dir.Y();
    *z         = dir.Z();
  }
  catch (...)
  {
    *x = 0;
    *y = 0;
    *z = 1;
  }
}

void OCCTViewObjectSetWindowHSize(OCCTViewObjectRef ref, double size)
{
  if (!ref)
    return;
  try
  {
    ((OCCTViewObject*)ref)->obj->SetWindowHorizontalSize(size);
  }
  catch (...)
  {
  }
}

double OCCTViewObjectGetWindowHSize(OCCTViewObjectRef ref)
{
  if (!ref)
    return 0;
  try
  {
    return ((OCCTViewObject*)ref)->obj->WindowHorizontalSize();
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTViewObjectSetWindowVSize(OCCTViewObjectRef ref, double size)
{
  if (!ref)
    return;
  try
  {
    ((OCCTViewObject*)ref)->obj->SetWindowVerticalSize(size);
  }
  catch (...)
  {
  }
}

double OCCTViewObjectGetWindowVSize(OCCTViewObjectRef ref)
{
  if (!ref)
    return 0;
  try
  {
    return ((OCCTViewObject*)ref)->obj->WindowVerticalSize();
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTViewObjectSetFrontPlaneDistance(OCCTViewObjectRef ref, double dist)
{
  if (!ref)
    return;
  try
  {
    ((OCCTViewObject*)ref)->obj->SetFrontPlaneDistance(dist);
  }
  catch (...)
  {
  }
}

double OCCTViewObjectGetFrontPlaneDistance(OCCTViewObjectRef ref)
{
  if (!ref)
    return 0;
  try
  {
    return ((OCCTViewObject*)ref)->obj->FrontPlaneDistance();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTViewObjectHasFrontPlaneClipping(OCCTViewObjectRef ref)
{
  if (!ref)
    return false;
  try
  {
    return ((OCCTViewObject*)ref)->obj->HasFrontPlaneClipping();
  }
  catch (...)
  {
    return false;
  }
}

void OCCTViewObjectUnsetFrontPlaneClipping(OCCTViewObjectRef ref)
{
  if (!ref)
    return;
  try
  {
    ((OCCTViewObject*)ref)->obj->UnsetFrontPlaneClipping();
  }
  catch (...)
  {
  }
}

void OCCTViewObjectSetBackPlaneDistance(OCCTViewObjectRef ref, double dist)
{
  if (!ref)
    return;
  try
  {
    ((OCCTViewObject*)ref)->obj->SetBackPlaneDistance(dist);
  }
  catch (...)
  {
  }
}

double OCCTViewObjectGetBackPlaneDistance(OCCTViewObjectRef ref)
{
  if (!ref)
    return 0;
  try
  {
    return ((OCCTViewObject*)ref)->obj->BackPlaneDistance();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTViewObjectHasBackPlaneClipping(OCCTViewObjectRef ref)
{
  if (!ref)
    return false;
  try
  {
    return ((OCCTViewObject*)ref)->obj->HasBackPlaneClipping();
  }
  catch (...)
  {
    return false;
  }
}

void OCCTViewObjectUnsetBackPlaneClipping(OCCTViewObjectRef ref)
{
  if (!ref)
    return;
  try
  {
    ((OCCTViewObject*)ref)->obj->UnsetBackPlaneClipping();
  }
  catch (...)
  {
  }
}

void OCCTViewObjectSetName(OCCTViewObjectRef ref, const char* name)
{
  if (!ref)
    return;
  try
  {
    ((OCCTViewObject*)ref)->obj->SetName(new TCollection_HAsciiString(name));
  }
  catch (...)
  {
  }
}

const char* _Nullable OCCTViewObjectGetName(OCCTViewObjectRef ref)
{
  if (!ref)
    return nullptr;
  try
  {
    Handle(TCollection_HAsciiString) n = ((OCCTViewObject*)ref)->obj->Name();
    if (n.IsNull())
      return nullptr;
    TCollection_AsciiString s      = n->String();
    char*                   result = (char*)malloc(s.Length() + 1);
    if (!result)
      return nullptr;
    memcpy(result, s.ToCString(), s.Length() + 1);
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTNoteObjectRef OCCTNoteObjectCreate(void)
{
  try
  {
    return (OCCTNoteObjectRef) new OCCTNoteObject{new XCAFNoteObjects_NoteObject()};
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTNoteObjectRelease(OCCTNoteObjectRef ref)
{
  delete (OCCTNoteObject*)ref;
}

bool OCCTNoteObjectHasPlane(OCCTNoteObjectRef ref)
{
  if (!ref)
    return false;
  try
  {
    return ((OCCTNoteObject*)ref)->obj->HasPlane();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTNoteObjectHasPoint(OCCTNoteObjectRef ref)
{
  if (!ref)
    return false;
  try
  {
    return ((OCCTNoteObject*)ref)->obj->HasPoint();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTNoteObjectHasPointText(OCCTNoteObjectRef ref)
{
  if (!ref)
    return false;
  try
  {
    return ((OCCTNoteObject*)ref)->obj->HasPointText();
  }
  catch (...)
  {
    return false;
  }
}

void OCCTNoteObjectSetPlane(OCCTNoteObjectRef ref,
                            double            origX,
                            double            origY,
                            double            origZ,
                            double            normX,
                            double            normY,
                            double            normZ)
{
  if (!ref)
    return;
  try
  {
    gp_Ax2 ax(gp_Pnt(origX, origY, origZ), gp_Dir(normX, normY, normZ));
    ((OCCTNoteObject*)ref)->obj->SetPlane(ax);
  }
  catch (...)
  {
  }
}

void OCCTNoteObjectGetPlane(OCCTNoteObjectRef ref, double* origX, double* origY, double* origZ)
{
  if (!ref)
  {
    *origX = 0;
    *origY = 0;
    *origZ = 0;
    return;
  }
  try
  {
    gp_Ax2 ax = ((OCCTNoteObject*)ref)->obj->GetPlane();
    *origX    = ax.Location().X();
    *origY    = ax.Location().Y();
    *origZ    = ax.Location().Z();
  }
  catch (...)
  {
    *origX = 0;
    *origY = 0;
    *origZ = 0;
  }
}

void OCCTNoteObjectSetPoint(OCCTNoteObjectRef ref, double x, double y, double z)
{
  if (!ref)
    return;
  try
  {
    ((OCCTNoteObject*)ref)->obj->SetPoint(gp_Pnt(x, y, z));
  }
  catch (...)
  {
  }
}

void OCCTNoteObjectGetPoint(OCCTNoteObjectRef ref, double* x, double* y, double* z)
{
  if (!ref)
  {
    *x = 0;
    *y = 0;
    *z = 0;
    return;
  }
  try
  {
    gp_Pnt p = ((OCCTNoteObject*)ref)->obj->GetPoint();
    *x       = p.X();
    *y       = p.Y();
    *z       = p.Z();
  }
  catch (...)
  {
    *x = 0;
    *y = 0;
    *z = 0;
  }
}

void OCCTNoteObjectSetPresentation(OCCTNoteObjectRef ref, OCCTShapeRef shape)
{
  if (!ref || !shape)
    return;
  try
  {
    ((OCCTNoteObject*)ref)->obj->SetPresentation(*(const TopoDS_Shape*)shape);
  }
  catch (...)
  {
  }
}

OCCTShapeRef OCCTNoteObjectGetPresentation(OCCTNoteObjectRef ref)
{
  if (!ref)
    return nullptr;
  try
  {
    const TopoDS_Shape& s = ((OCCTNoteObject*)ref)->obj->GetPresentation();
    if (s.IsNull())
      return nullptr;
    return (OCCTShapeRef) new TopoDS_Shape(s);
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTNoteObjectReset(OCCTNoteObjectRef ref)
{
  if (!ref)
    return;
  try
  {
    ((OCCTNoteObject*)ref)->obj->Reset();
  }
  catch (...)
  {
  }
}

OCCTXCAFPrsStyle OCCTXCAFPrsStyleCreateFull(double surfR,
                                            double surfG,
                                            double surfB,
                                            float  surfAlpha,
                                            double curvR,
                                            double curvG,
                                            double curvB,
                                            bool   visible)
{
  OCCTXCAFPrsStyle result;
  result.surfR        = surfR;
  result.surfG        = surfG;
  result.surfB        = surfB;
  result.surfAlpha    = surfAlpha;
  result.hasSurfColor = true;
  result.curvR        = curvR;
  result.curvG        = curvG;
  result.curvB        = curvB;
  result.hasCurvColor = true;
  result.isVisible    = visible;
  result.isEmpty      = false;
  return result;
}

bool OCCTDocumentXLinkSet(OCCTDocumentRef document, int labelTag)
{
  try
  {
    TDF_Label             label = getLabelForTag(document, labelTag);
    Handle(TDocStd_XLink) xlink = TDocStd_XLink::Set(label);
    return !xlink.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentXLinkSetDocumentEntry(OCCTDocumentRef document, int labelTag, const char* entry)
{
  try
  {
    TDF_Label             label = getLabelForTag(document, labelTag);
    Handle(TDocStd_XLink) xlink;
    if (!label.FindAttribute(TDocStd_XLink::GetID(), xlink))
      return false;
    xlink->DocumentEntry(TCollection_AsciiString(entry));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

const char* OCCTDocumentXLinkGetDocumentEntry(OCCTDocumentRef document, int labelTag)
{
  try
  {
    TDF_Label             label = getLabelForTag(document, labelTag);
    Handle(TDocStd_XLink) xlink;
    if (!label.FindAttribute(TDocStd_XLink::GetID(), xlink))
      return nullptr;
    TCollection_AsciiString entry  = xlink->DocumentEntry();
    char*                   result = (char*)malloc(entry.Length() + 1);
    strcpy(result, entry.ToCString());
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTDocumentXLinkSetLabelEntry(OCCTDocumentRef document, int labelTag, const char* entry)
{
  try
  {
    TDF_Label             label = getLabelForTag(document, labelTag);
    Handle(TDocStd_XLink) xlink;
    if (!label.FindAttribute(TDocStd_XLink::GetID(), xlink))
      return false;
    xlink->LabelEntry(TCollection_AsciiString(entry));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

const char* OCCTDocumentXLinkGetLabelEntry(OCCTDocumentRef document, int labelTag)
{
  try
  {
    TDF_Label             label = getLabelForTag(document, labelTag);
    Handle(TDocStd_XLink) xlink;
    if (!label.FindAttribute(TDocStd_XLink::GetID(), xlink))
      return nullptr;
    TCollection_AsciiString entry  = xlink->LabelEntry();
    char*                   result = (char*)malloc(entry.Length() + 1);
    strcpy(result, entry.ToCString());
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTDriverTableInitStandard()
{
  try
  {
    Handle(TPrsStd_DriverTable) table = TPrsStd_DriverTable::Get();
    table->InitStandardDrivers();
  }
  catch (...)
  {
  }
}

bool OCCTDriverTableExists()
{
  try
  {
    Handle(TPrsStd_DriverTable) table = TPrsStd_DriverTable::Get();
    return !table.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

void OCCTDriverTableClear()
{
  try
  {
    Handle(TPrsStd_DriverTable) table = TPrsStd_DriverTable::Get();
    if (!table.IsNull())
      table->Clear();
  }
  catch (...)
  {
  }
}

OCCTTObjAppRef OCCTTObjApplicationGetInstance()
{
  try
  {
    Handle(TObj_Application) app = TObj_Application::GetInstance();
    if (app.IsNull())
      return nullptr;
    // Prevent reference count from going to 0
    app->IncrementRefCounter();
    return app.get();
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTTObjApplicationSetVerbose(OCCTTObjAppRef app, bool verbose)
{
  try
  {
    auto* a = static_cast<TObj_Application*>(app);
    a->SetVerbose(verbose);
  }
  catch (...)
  {
  }
}

bool OCCTTObjApplicationIsVerbose(OCCTTObjAppRef app)
{
  try
  {
    auto* a = static_cast<TObj_Application*>(app);
    return a->IsVerbose();
  }
  catch (...)
  {
    return false;
  }
}

OCCTDocumentRef OCCTTObjApplicationCreateDocument(OCCTTObjAppRef app)
{
  try
  {
    auto*                      a = static_cast<TObj_Application*>(app);
    Handle(TObj_Application)   hApp(a);
    Handle(TDocStd_Document)   doc;
    TCollection_ExtendedString format("BinOcaf");
    if (!hApp->CreateNewDocument(doc, format))
      return nullptr;
    if (doc.IsNull())
      return nullptr;
    // Wrap in OCCTDocument struct
    OCCTDocument* result = new OCCTDocument();
    result->doc          = doc;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTIDFilterRef OCCTIDFilterCreate(bool ignoreAll)
{
  try
  {
    TDF_IDFilter* filter = new TDF_IDFilter(ignoreAll);
    return filter;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTIDFilterRelease(OCCTIDFilterRef filter)
{
  try
  {
    auto* f = static_cast<TDF_IDFilter*>(filter);
    delete f;
  }
  catch (...)
  {
  }
}

bool OCCTIDFilterIgnoreAll(OCCTIDFilterRef filter)
{
  try
  {
    auto* f = static_cast<TDF_IDFilter*>(filter);
    return f->IgnoreAll();
  }
  catch (...)
  {
    return false;
  }
}

void OCCTIDFilterSetIgnoreAll(OCCTIDFilterRef filter, bool ignoreAll)
{
  try
  {
    auto* f = static_cast<TDF_IDFilter*>(filter);
    f->IgnoreAll(ignoreAll);
  }
  catch (...)
  {
  }
}

void OCCTIDFilterKeep(OCCTIDFilterRef filter, const char* guidString)
{
  try
  {
    auto*         f = static_cast<TDF_IDFilter*>(filter);
    Standard_GUID guid(guidString);
    f->Keep(guid);
  }
  catch (...)
  {
  }
}

void OCCTIDFilterIgnore(OCCTIDFilterRef filter, const char* guidString)
{
  try
  {
    auto*         f = static_cast<TDF_IDFilter*>(filter);
    Standard_GUID guid(guidString);
    f->Ignore(guid);
  }
  catch (...)
  {
  }
}

bool OCCTIDFilterIsKept(OCCTIDFilterRef filter, const char* guidString)
{
  try
  {
    auto*         f = static_cast<TDF_IDFilter*>(filter);
    Standard_GUID guid(guidString);
    return f->IsKept(guid);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTIDFilterIsIgnored(OCCTIDFilterRef filter, const char* guidString)
{
  try
  {
    auto*         f = static_cast<TDF_IDFilter*>(filter);
    Standard_GUID guid(guidString);
    return f->IsIgnored(guid);
  }
  catch (...)
  {
    return false;
  }
}

void OCCTIntPackedMapFreeValues(int* values)
{
  if (values)
    free(values);
}

void OCCTUAttributeFreeGUID(const char* guidString)
{
  if (guidString)
    free((void*)guidString);
}

int32_t OCCTDocumentOpenNamedTransaction(OCCTDocumentRef doc, const char* name)
{
  if (!doc || doc->doc.IsNull())
    return 0;
  try
  {
    // OpenCommand throws Standard_DomainError when one is already open, and the catch below
    // returns 0 without having touched the pending name, so a refused open leaves the running
    // transaction's own name alone.
    doc->doc->OpenCommand();
    const Handle(TDF_Data)& data = doc->doc->GetData();
    if (data.IsNull())
      return 0;
    // Nothing opens when the undo limit is 0 (TDocStd_Document::OpenTransaction opens its
    // TDF_Transaction only when myUndoLimit != 0), and a name held across that would land on
    // whatever commits next. Store it only once a transaction is genuinely open.
    if (name && doc->doc->HasOpenCommand())
      doc->pendingTransactionName = name;
    else
      doc->pendingTransactionName.clear();
    return static_cast<int32_t>(data->Transaction());
  }
  catch (...)
  {
    return 0;
  }
}

void* OCCTDocumentCommitWithDelta(OCCTDocumentRef doc)
{
  if (!doc || doc->doc.IsNull())
    return nullptr;
  try
  {
    // #970: no SetUndoLimit(100) here. TDocStd_Document::SetUndoLimit commits the open
    // transaction before it changes the limit, so the CommitCommand below had nothing left to
    // commit and this function returned nullptr for every transaction that had one open. The
    // undo limit is the caller's to set (OCCTDocumentSetUndoLimit); with undo disabled, which
    // is OCCT's default, there is no delta to hand back.
    bool ok = doc->doc->CommitCommand();
    occtApplyPendingTransactionName(doc, ok);
    if (!ok)
      return nullptr;
    auto& undos = doc->doc->GetUndos();
    if (undos.IsEmpty())
      return nullptr;
    Handle(TDF_Delta)* deltaPtr = new Handle(TDF_Delta)(undos.Last());
    return static_cast<void*>(deltaPtr);
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTDocumentGetTransactionNumber(OCCTDocumentRef doc)
{
  if (!doc || doc->doc.IsNull())
    return 0;
  try
  {
    // #970: read OCCT's own counter rather than encoding HasOpenCommand() as 1 or 0. A document
    // holds at most one TDF transaction, so this is 0 or 1 in every state its command API can
    // reach, nested transaction mode included; see Scripts/repro/970-transaction-api.
    const Handle(TDF_Data)& data = doc->doc->GetData();
    if (data.IsNull())
      return 0;
    return static_cast<int32_t>(data->Transaction());
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTDeltaIsEmpty(void* delta)
{
  try
  {
    auto* ptr = static_cast<Handle(TDF_Delta)*>(delta);
    return (*ptr)->IsEmpty();
  }
  catch (...)
  {
    return true;
  }
}

int32_t OCCTDeltaBeginTime(void* delta)
{
  try
  {
    auto* ptr = static_cast<Handle(TDF_Delta)*>(delta);
    return (*ptr)->BeginTime();
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTDeltaEndTime(void* delta)
{
  try
  {
    auto* ptr = static_cast<Handle(TDF_Delta)*>(delta);
    return (*ptr)->EndTime();
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTDeltaAttributeDeltaCount(void* delta)
{
  try
  {
    auto* ptr = static_cast<Handle(TDF_Delta)*>(delta);
    return static_cast<int32_t>((*ptr)->AttributeDeltas().Size());
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTDeltaSetName(void* delta, const char* name)
{
  try
  {
    auto* ptr = static_cast<Handle(TDF_Delta)*>(delta);
    (*ptr)->SetName(TCollection_ExtendedString(name));
  }
  catch (...)
  {
  }
}

const char* OCCTDeltaGetName(void* delta)
{
  try
  {
    auto*                      ptr   = static_cast<Handle(TDF_Delta)*>(delta);
    TCollection_ExtendedString ename = (*ptr)->Name();
    TCollection_AsciiString    aname(ename);
    return strdup(aname.ToCString());
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTDeltaFreeName(const char* name)
{
  if (name)
    free((void*)name);
}

void OCCTDeltaRelease(void* delta)
{
  if (delta)
  {
    auto* ptr = static_cast<Handle(TDF_Delta)*>(delta);
    delete ptr;
  }
}

bool OCCTDocumentIsSelfContained(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;

    Handle(TDF_DataSet) ds = new TDF_DataSet();
    ds->AddLabel(label);
    for (TDF_ChildIterator cit(label, true); cit.More(); cit.Next())
    {
      ds->AddLabel(cit.Value());
    }
    return TDF_ComparisonTool::IsSelfContained(label, ds);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentXLinkCopy(OCCTDocumentRef doc, int64_t tgtLabelId, int64_t srcLabelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label tgt = doc->getLabel(tgtLabelId);
    TDF_Label src = doc->getLabel(srcLabelId);
    if (src.IsNull() || tgt.IsNull())
      return false;

    TDocStd_XLinkTool tool;
    tool.Copy(tgt, src);
    return tool.IsDone();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentXLinkCopyWithLink(OCCTDocumentRef doc, int64_t tgtLabelId, int64_t srcLabelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label tgt = doc->getLabel(tgtLabelId);
    TDF_Label src = doc->getLabel(srcLabelId);
    if (src.IsNull() || tgt.IsNull())
      return false;

    TDocStd_XLinkTool tool;
    tool.CopyWithLink(tgt, src);
    return tool.IsDone();
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTDocumentAttributeCount(OCCTDocumentRef doc, int64_t labelId, bool withoutForgotten)
{
  if (!doc || doc->doc.IsNull())
    return 0;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return 0;

    int count = 0;
    for (TDF_AttributeIterator it(label, withoutForgotten); it.More(); it.Next())
    {
      count++;
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTDocumentDataSetIsEmpty(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return true;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return true;

    Handle(TDF_DataSet) ds = new TDF_DataSet();
    ds->AddLabel(label);
    return ds->IsEmpty();
  }
  catch (...)
  {
    return true;
  }
}

int32_t OCCTDocumentChildIDCount(OCCTDocumentRef doc,
                                 int64_t         labelId,
                                 const char*     guidString,
                                 bool            allLevels)
{
  if (!doc || doc->doc.IsNull())
    return 0;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return 0;
    Standard_GUID guid(guidString);
    int           count = 0;
    for (TDF_ChildIDIterator it(label, guid, allLevels); it.More(); it.Next())
    {
      count++;
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTDocumentNamingScopeValid(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    doc->namingScope.Valid(label);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentNamingScopeValidChildren(OCCTDocumentRef doc, int64_t labelId, bool withRoot)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    doc->namingScope.ValidChildren(label, withRoot);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentNamingScopeIsValid(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    return doc->namingScope.IsValid(label);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentNamingScopeUnvalid(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    doc->namingScope.Unvalid(label);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTDocumentNamingScopeClear(OCCTDocumentRef doc)
{
  if (!doc || doc->doc.IsNull())
    return;
  try
  {
    doc->namingScope.ClearValid();
  }
  catch (...)
  {
  }
}

int32_t OCCTDocumentNamingScopeValidCount(OCCTDocumentRef doc)
{
  if (!doc || doc->doc.IsNull())
    return 0;
  try
  {
    return doc->namingScope.GetValid().Extent();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTShapeIsSame(OCCTShapeRef shape1, OCCTShapeRef shape2)
{
  if (!shape1 || !shape2)
    return false;
  return shape1->shape.IsSame(shape2->shape);
}

void OCCTDocumentFreeDimTolString(const char* str)
{
  if (str)
    free((void*)str);
}

void OCCTDocumentFreeAssemblyItemRefString(const char* str)
{
  if (str)
    free((void*)str);
}

OCCTShapeRef OCCTDocumentExplorerFindShape(OCCTDocumentRef docRef, const char* pathId)
{
  try
  {
    Handle(TDocStd_Document) doc = docRef->doc;
    TCollection_AsciiString  id(pathId);
    TopoDS_Shape             shape = XCAFPrs_DocumentExplorer::FindShapeFromPathId(doc, id);
    if (shape.IsNull())
      return nullptr;
    auto result   = new OCCTShape();
    result->shape = shape;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

int64_t OCCTDocumentColorToolAddColor(OCCTDocumentRef doc, double r, double g, double b)
{
  if (!doc)
    return -1;
  try
  {
    auto           colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
    Quantity_Color col(r, g, b, Quantity_TOC_RGB);
    TDF_Label      lab = colorTool->AddColor(col);
    if (lab.IsNull())
      return -1;
    return doc->registerLabel(lab);
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDocumentColorToolRemoveColor(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc)
    return false;
  try
  {
    auto      colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
    TDF_Label lab       = doc->getLabel(labelId);
    if (lab.IsNull())
      return false;
    colorTool->RemoveColor(lab);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTDocumentColorToolGetColorCount(OCCTDocumentRef doc)
{
  if (!doc)
    return 0;
  try
  {
    auto                            colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
    NCollection_Sequence<TDF_Label> labels;
    colorTool->GetColors(labels);
    return (int32_t)labels.Length();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTDocumentColorToolUnSetColor(OCCTDocumentRef doc, int64_t labelId, int32_t colorType)
{
  if (!doc)
    return false;
  try
  {
    auto      colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
    TDF_Label lab       = doc->getLabel(labelId);
    if (lab.IsNull())
      return false;
    colorTool->UnSetColor(lab, (XCAFDoc_ColorType)colorType);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentColorToolSetVisibility(OCCTDocumentRef doc, int64_t labelId, bool visible)
{
  if (!doc)
    return false;
  try
  {
    auto      colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
    TDF_Label lab       = doc->getLabel(labelId);
    if (lab.IsNull())
      return false;
    colorTool->SetVisibility(lab, visible);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentColorToolIsColorByLayer(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc)
    return false;
  try
  {
    auto      colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
    TDF_Label lab       = doc->getLabel(labelId);
    if (lab.IsNull())
      return false;
    return colorTool->IsColorByLayer(lab);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentColorToolSetColorByLayer(OCCTDocumentRef doc, int64_t labelId, bool isByLayer)
{
  if (!doc)
    return false;
  try
  {
    auto      colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
    TDF_Label lab       = doc->getLabel(labelId);
    if (lab.IsNull())
      return false;
    colorTool->SetColorByLayer(lab, isByLayer);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int64_t OCCTDocumentColorToolFindColor(OCCTDocumentRef doc, double r, double g, double b)
{
  if (!doc)
    return -1;
  try
  {
    auto           colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
    Quantity_Color col(r, g, b, Quantity_TOC_RGB);
    TDF_Label      lab = colorTool->FindColor(col);
    if (lab.IsNull())
      return -1;
    return doc->registerLabel(lab);
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDocumentColorToolSetInstanceColor(OCCTDocumentRef doc,
                                           OCCTShapeRef    shape,
                                           int32_t         colorType,
                                           double          r,
                                           double          g,
                                           double          b)
{
  if (!doc || !shape)
    return false;
  try
  {
    auto           colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
    Quantity_Color col(r, g, b, Quantity_TOC_RGB);
    return colorTool->SetInstanceColor(shape->shape, (XCAFDoc_ColorType)colorType, col);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentColorToolGetInstanceColor(OCCTDocumentRef doc,
                                           OCCTShapeRef    shape,
                                           int32_t         colorType,
                                           double*         r,
                                           double*         g,
                                           double*         b)
{
  if (!doc || !shape)
    return false;
  try
  {
    auto           colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
    Quantity_Color col;
    if (!colorTool->GetInstanceColor(shape->shape, (XCAFDoc_ColorType)colorType, col))
      return false;
    *r = col.Red();
    *g = col.Green();
    *b = col.Blue();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTDocumentColorToolGetAllColors(OCCTDocumentRef doc, int64_t** outLabelIds)
{
  if (!doc || !outLabelIds)
    return 0;
  *outLabelIds = nullptr;
  try
  {
    NCollection_Sequence<TDF_Label> labels;
    doc->colorTool->GetColors(labels);
    int count = static_cast<int>(labels.Size());
    if (count == 0)
      return 0;
    int64_t* ids = (int64_t*)malloc(count * sizeof(int64_t));
    if (!ids)
      return 0;
    for (int i = 1; i <= count; i++)
    {
      const TDF_Label& lab = labels.Value(i);
      // Find or add to label registry
      int64_t idx = -1;
      for (int64_t j = 0; j < (int64_t)doc->labels.size(); j++)
      {
        if (doc->labels[j].IsEqual(lab))
        {
          idx = j;
          break;
        }
      }
      if (idx < 0)
      {
        idx = (int64_t)doc->labels.size();
        doc->labels.push_back(lab);
      }
      ids[i - 1] = idx;
    }
    *outLabelIds = ids;
    return count;
  }
  catch (...)
  {
    return 0;
  }
}
