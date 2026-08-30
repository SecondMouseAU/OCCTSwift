//
//  OCCTBridge_Document_Appearance.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Document.mm (#1380): XDE colors/materials (PBR),
//  XCAFDoc_Color/ColorTool/Material/VisMaterial*/ClippingPlaneTool. Public C surface unchanged;
//  every sibling file imports the same headers this one does (the shared preamble below). No symbol
//  changes, pure file move -- see Scripts/repro/396-bridge-mm-split/ for how.
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
    [](OCCTDocumentRef d) { return XCAFDoc_DimTolTool::Set(d->doc->Main()); },
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
/// One copy, two callers: OCCTDocumentSetDimensionTolerance and the create path this file's
/// occtDocumentCreateDimensionImpl runs. Both are in this file and nothing outside it applies a
/// tolerance, so file-static is the right reach. The two spellings of the operation disagreeing
/// about what counts as applied is the defect #1056 is about, so they share the test rather than
/// each carrying their own.
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

    TDF_Label         dimLabel = dimTolTool->AddDimension();
    TDF_LabelSequence shapeSeq;
    shapeSeq.Append(shapeLabel);
    dimTolTool->SetDimension(shapeSeq, shapeSeq, dimLabel);

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

OCCTColor OCCTDocumentGetLabelColor(OCCTDocumentRef doc, int64_t labelId, OCCTColorType colorType)
{
  OCCTColor result = {0, 0, 0, 1.0, false};

  if (!doc || doc->colorTool.IsNull())
    return result;

  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return result;

    Quantity_ColorRGBA color;
    XCAFDoc_ColorType  xcafType;

    switch (colorType)
    {
      case OCCTColorTypeSurface:
        xcafType = XCAFDoc_ColorSurf;
        break;
      case OCCTColorTypeCurve:
        xcafType = XCAFDoc_ColorCurv;
        break;
      default:
        xcafType = XCAFDoc_ColorGen;
        break;
    }

    // Try to get color from this label
    if (doc->colorTool->GetColor(label, xcafType, color))
    {
      result.r     = color.GetRGB().Red();
      result.g     = color.GetRGB().Green();
      result.b     = color.GetRGB().Blue();
      result.a     = color.Alpha();
      result.isSet = true;
      return result;
    }

    // If this is a reference, try to get color from referred shape
    if (doc->shapeTool->IsReference(label))
    {
      TDF_Label referredLabel;
      if (doc->shapeTool->GetReferredShape(label, referredLabel))
      {
        if (doc->colorTool->GetColor(referredLabel, xcafType, color))
        {
          result.r     = color.GetRGB().Red();
          result.g     = color.GetRGB().Green();
          result.b     = color.GetRGB().Blue();
          result.a     = color.Alpha();
          result.isSet = true;
        }
      }
    }

    return result;
  }
  catch (...)
  {
    return result;
  }
}

void OCCTDocumentSetLabelColor(OCCTDocumentRef doc,
                               int64_t         labelId,
                               OCCTColorType   colorType,
                               double          r,
                               double          g,
                               double          b)
{
  if (!doc || doc->colorTool.IsNull())
    return;

  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return;

    Quantity_Color    color(r, g, b, Quantity_TOC_RGB);
    XCAFDoc_ColorType xcafType;

    switch (colorType)
    {
      case OCCTColorTypeSurface:
        xcafType = XCAFDoc_ColorSurf;
        break;
      case OCCTColorTypeCurve:
        xcafType = XCAFDoc_ColorCurv;
        break;
      default:
        xcafType = XCAFDoc_ColorGen;
        break;
    }

    doc->colorTool->SetColor(label, color, xcafType);
  }
  catch (...)
  {
    // Ignore errors
  }
}

OCCTMaterial OCCTDocumentGetLabelMaterial(OCCTDocumentRef doc, int64_t labelId)
{
  OCCTMaterial result = {{0, 0, 0, 1.0, false}, 0.0, 0.5, {0, 0, 0, 1.0, false}, 0.0, false};

  if (!doc || doc->materialTool.IsNull())
    return result;

  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return result;

    // Get shape to find material
    TopoDS_Shape shape = doc->shapeTool->GetShape(label);
    if (shape.IsNull())
    {
      // Try from reference
      if (doc->shapeTool->IsReference(label))
      {
        TDF_Label referredLabel;
        if (doc->shapeTool->GetReferredShape(label, referredLabel))
        {
          shape = doc->shapeTool->GetShape(referredLabel);
        }
      }
    }

    if (shape.IsNull())
      return result;

    // Try to get material from shape
    Handle(XCAFDoc_VisMaterial) visMat = doc->materialTool->GetShapeMaterial(shape);
    if (visMat.IsNull())
      return result;

    result.isSet = true;

    // Get PBR properties if available
    if (visMat->HasPbrMaterial())
    {
      XCAFDoc_VisMaterialPBR pbr = visMat->PbrMaterial();

      // Base color
      Quantity_ColorRGBA baseColor = pbr.BaseColor;
      result.baseColor.r           = baseColor.GetRGB().Red();
      result.baseColor.g           = baseColor.GetRGB().Green();
      result.baseColor.b           = baseColor.GetRGB().Blue();
      result.baseColor.a           = baseColor.Alpha();
      result.baseColor.isSet       = true;

      // Metallic and roughness
      result.metallic  = pbr.Metallic;
      result.roughness = pbr.Roughness;

      // Emissive (Graphic3d_Vec3)
      result.emissive.r     = pbr.EmissiveFactor.x();
      result.emissive.g     = pbr.EmissiveFactor.y();
      result.emissive.b     = pbr.EmissiveFactor.z();
      result.emissive.a     = 1.0;
      result.emissive.isSet = true;
    }
    else if (visMat->HasCommonMaterial())
    {
      // Fall back to common material
      XCAFDoc_VisMaterialCommon common = visMat->CommonMaterial();

      result.baseColor.r     = common.DiffuseColor.Red();
      result.baseColor.g     = common.DiffuseColor.Green();
      result.baseColor.b     = common.DiffuseColor.Blue();
      result.baseColor.a     = 1.0 - common.Transparency;
      result.baseColor.isSet = true;

      result.transparency = common.Transparency;

      // Estimate roughness from shininess
      result.roughness = 1.0 - (common.Shininess / 100.0);
    }

    return result;
  }
  catch (...)
  {
    return result;
  }
}

void OCCTDocumentSetLabelMaterial(OCCTDocumentRef doc, int64_t labelId, OCCTMaterial material)
{
  if (!doc || doc->materialTool.IsNull() || !material.isSet)
    return;

  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return;

    TopoDS_Shape shape = doc->shapeTool->GetShape(label);
    if (shape.IsNull())
      return;

    // Create new material
    Handle(XCAFDoc_VisMaterial) visMat = new XCAFDoc_VisMaterial();

    // Set PBR properties
    XCAFDoc_VisMaterialPBR pbr;
    pbr.BaseColor      = Quantity_ColorRGBA(Quantity_Color(material.baseColor.r,
                                                           material.baseColor.g,
                                                           material.baseColor.b,
                                                           Quantity_TOC_RGB),
                                            static_cast<float>(material.baseColor.a));
    pbr.Metallic       = static_cast<Standard_ShortReal>(material.metallic);
    pbr.Roughness      = static_cast<Standard_ShortReal>(material.roughness);
    pbr.EmissiveFactor = Graphic3d_Vec3(static_cast<float>(material.emissive.r),
                                        static_cast<float>(material.emissive.g),
                                        static_cast<float>(material.emissive.b));

    visMat->SetPbrMaterial(pbr);

    // Add material and bind to shape
    TDF_Label matLabel =
      doc->materialTool->AddMaterial(visMat, TCollection_AsciiString("Material"));
    doc->materialTool->SetShapeMaterial(shape, matLabel);
  }
  catch (...)
  {
    // Ignore errors
  }
}

int32_t OCCTDocumentGetMaterialCount(OCCTDocumentRef doc)
{
  if (!doc || doc->doc.IsNull())
    return 0;
  try
  {
    Handle(XCAFDoc_MaterialTool) matTool = XCAFDoc_MaterialTool::Set(doc->doc->Main());
    if (matTool.IsNull())
      return 0;
    TDF_LabelSequence labels;
    matTool->GetMaterialLabels(labels);
    return (int32_t)labels.Length();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTDocumentGetMaterialInfo(OCCTDocumentRef doc, int32_t index, OCCTMaterialInfo* outInfo)
{
  if (!doc || doc->doc.IsNull() || !outInfo)
    return false;
  try
  {
    Handle(XCAFDoc_MaterialTool) matTool = XCAFDoc_MaterialTool::Set(doc->doc->Main());
    if (matTool.IsNull())
      return false;
    TDF_LabelSequence labels;
    matTool->GetMaterialLabels(labels);
    if (index < 0 || index >= labels.Length())
      return false;
    TDF_Label                        label = labels.Value(index + 1);
    Handle(TCollection_HAsciiString) hName, hDesc, hDensName, hDensValType;
    double                           density = 0.0;
    matTool->GetMaterial(label, hName, hDesc, density, hDensName, hDensValType);
    memset(outInfo, 0, sizeof(OCCTMaterialInfo));
    if (!hName.IsNull())
    {
      TCollection_AsciiString name = hName->String();
      int32_t len = std::min((int32_t)name.Length(), (int32_t)(sizeof(outInfo->name) - 1));
      for (int32_t i = 0; i < len; i++)
      {
        outInfo->name[i] = name.Value(i + 1);
      }
    }
    if (!hDesc.IsNull())
    {
      TCollection_AsciiString desc = hDesc->String();
      int32_t len = std::min((int32_t)desc.Length(), (int32_t)(sizeof(outInfo->description) - 1));
      for (int32_t i = 0; i < len; i++)
      {
        outInfo->description[i] = desc.Value(i + 1);
      }
    }
    outInfo->density = density;
    return true;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTDocumentSetShapeColorRGBA(OCCTDocumentRef doc,
                                   OCCTShapeRef    shape,
                                   int32_t         colorType,
                                   double          r,
                                   double          g,
                                   double          b,
                                   float           alpha)
{
  if (!doc || !shape || doc->colorTool.IsNull())
    return;
  try
  {
    Quantity_ColorRGBA color(Quantity_Color(r, g, b, Quantity_TOC_RGB), alpha);
    doc->colorTool->SetColor(shape->shape, color, static_cast<XCAFDoc_ColorType>(colorType));
  }
  catch (...)
  {
  }
}

OCCTColor OCCTDocumentGetShapeColor(OCCTDocumentRef doc, OCCTShapeRef shape, int32_t colorType)
{
  OCCTColor result = {0, 0, 0, 1.0, false};
  if (!doc || !shape || doc->colorTool.IsNull())
    return result;
  try
  {
    // #763: read via the RGBA overload (XCAFDoc_ColorTool::GetColor(shape, type, Quantity_Color&)
    // internally fetches the RGBA value and then discards alpha) so a real stored alpha -
    // e.g. from a STEP import's transparent surface style, or OCCTDocumentSetShapeColorRGBA -
    // is reported instead of the hardcoded 1.0 OCCTDocumentGetLabelColor already avoids.
    Quantity_ColorRGBA color;
    bool               hasColor =
      doc->colorTool->GetColor(shape->shape, static_cast<XCAFDoc_ColorType>(colorType), color);
    if (hasColor)
    {
      result.r     = color.GetRGB().Red();
      result.g     = color.GetRGB().Green();
      result.b     = color.GetRGB().Blue();
      result.a     = color.Alpha();
      result.isSet = true;
    }
  }
  catch (...)
  {
  }
  return result;
}

bool OCCTDocumentIsShapeColorSet(OCCTDocumentRef doc, OCCTShapeRef shape, int32_t colorType)
{
  if (!doc || !shape || doc->colorTool.IsNull())
    return false;
  try
  {
    return doc->colorTool->IsSet(shape->shape, static_cast<XCAFDoc_ColorType>(colorType));
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetColorAttr(OCCTDocumentRef ref, int64_t labelId, double r, double g, double b)
{
  if (!ref)
    return false;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Quantity_Color        color(r, g, b, Quantity_TOC_sRGB);
    Handle(XCAFDoc_Color) attr = XCAFDoc_Color::Set(label, color);
    return !attr.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetColorRGBAAttr(OCCTDocumentRef ref,
                                  int64_t         labelId,
                                  double          r,
                                  double          g,
                                  double          b,
                                  float           alpha)
{
  if (!ref)
    return false;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Quantity_ColorRGBA    rgba(Quantity_Color(r, g, b, Quantity_TOC_sRGB), alpha);
    Handle(XCAFDoc_Color) attr = XCAFDoc_Color::Set(label, rgba);
    return !attr.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetColorNOCAttr(OCCTDocumentRef ref, int64_t labelId, int32_t noc)
{
  if (!ref)
    return false;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Quantity_Color        color((Quantity_NameOfColor)noc);
    Handle(XCAFDoc_Color) attr = XCAFDoc_Color::Set(label, color);
    return !attr.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentGetColorAttr(OCCTDocumentRef ref,
                              int64_t         labelId,
                              double*         outR,
                              double*         outG,
                              double*         outB)
{
  if (!ref)
    return false;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(XCAFDoc_Color) attr;
    if (!label.FindAttribute(XCAFDoc_Color::GetID(), attr))
      return false;
    Quantity_Color c = attr->GetColor();
    *outR            = c.Red();
    *outG            = c.Green();
    *outB            = c.Blue();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentGetColorRGBAAttr(OCCTDocumentRef ref,
                                  int64_t         labelId,
                                  double*         outR,
                                  double*         outG,
                                  double*         outB,
                                  float*          outAlpha)
{
  if (!ref)
    return false;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(XCAFDoc_Color) attr;
    if (!label.FindAttribute(XCAFDoc_Color::GetID(), attr))
      return false;
    Quantity_ColorRGBA rgba = attr->GetColorRGBA();
    *outR                   = rgba.GetRGB().Red();
    *outG                   = rgba.GetRGB().Green();
    *outB                   = rgba.GetRGB().Blue();
    *outAlpha               = rgba.Alpha();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

float OCCTDocumentGetColorAlphaAttr(OCCTDocumentRef ref, int64_t labelId)
{
  if (!ref)
    return 1.0f;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return 1.0f;
    Handle(XCAFDoc_Color) attr;
    if (!label.FindAttribute(XCAFDoc_Color::GetID(), attr))
      return 1.0f;
    return attr->GetAlpha();
  }
  catch (...)
  {
    return 1.0f;
  }
}

int32_t OCCTDocumentGetColorNOCAttr(OCCTDocumentRef ref, int64_t labelId)
{
  if (!ref)
    return -1;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return -1;
    Handle(XCAFDoc_Color) attr;
    if (!label.FindAttribute(XCAFDoc_Color::GetID(), attr))
      return -1;
    return (int32_t)attr->GetNOC();
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDocumentSetMaterialAttr(OCCTDocumentRef ref,
                                 int64_t         labelId,
                                 const char*     name,
                                 const char*     description,
                                 double          density,
                                 const char*     densName,
                                 const char*     densValType)
{
  if (!ref)
    return false;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TCollection_HAsciiString) hName     = new TCollection_HAsciiString(name);
    Handle(TCollection_HAsciiString) hDesc     = new TCollection_HAsciiString(description);
    Handle(TCollection_HAsciiString) hDensName = new TCollection_HAsciiString(densName);
    Handle(TCollection_HAsciiString) hDensType = new TCollection_HAsciiString(densValType);
    Handle(XCAFDoc_Material)         attr =
      XCAFDoc_Material::Set(label, hName, hDesc, density, hDensName, hDensType);
    return !attr.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

const char* _Nullable OCCTDocumentGetMaterialAttrName(OCCTDocumentRef ref, int64_t labelId)
{
  if (!ref)
    return nullptr;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return nullptr;
    Handle(XCAFDoc_Material) attr;
    if (!label.FindAttribute(XCAFDoc_Material::GetID(), attr))
      return nullptr;
    Handle(TCollection_HAsciiString) n = attr->GetName();
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

const char* _Nullable OCCTDocumentGetMaterialAttrDescription(OCCTDocumentRef ref, int64_t labelId)
{
  if (!ref)
    return nullptr;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return nullptr;
    Handle(XCAFDoc_Material) attr;
    if (!label.FindAttribute(XCAFDoc_Material::GetID(), attr))
      return nullptr;
    Handle(TCollection_HAsciiString) d = attr->GetDescription();
    if (d.IsNull())
      return nullptr;
    TCollection_AsciiString s      = d->String();
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

bool OCCTDocumentGetMaterialAttrDensity(OCCTDocumentRef ref, int64_t labelId, double* outDensity)
{
  if (!ref)
    return false;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(XCAFDoc_Material) attr;
    if (!label.FindAttribute(XCAFDoc_Material::GetID(), attr))
      return false;
    *outDensity = attr->GetDensity();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentHasMaterialAttr(OCCTDocumentRef ref, int64_t labelId)
{
  if (!ref)
    return false;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(XCAFDoc_Material) attr;
    return label.FindAttribute(XCAFDoc_Material::GetID(), attr);
  }
  catch (...)
  {
    return false;
  }
}

int64_t OCCTDocumentClipPlaneToolAdd(OCCTDocumentRef ref,
                                     double          planeOrigX,
                                     double          planeOrigY,
                                     double          planeOrigZ,
                                     double          planeNormX,
                                     double          planeNormY,
                                     double          planeNormZ,
                                     const char*     name,
                                     bool            capping)
{
  if (!ref)
    return -1;
  try
  {
    auto*                             doc  = (OCCTDocument*)ref;
    TDF_Label                         main = doc->doc->Main();
    Handle(XCAFDoc_ClippingPlaneTool) tool = XCAFDoc_DocumentTool::ClippingPlaneTool(main);
    if (tool.IsNull())
      return -1;
    gp_Pln                     plane(gp_Pnt(planeOrigX, planeOrigY, planeOrigZ),
                                     gp_Dir(planeNormX, planeNormY, planeNormZ));
    TCollection_ExtendedString eName(name);
    TDF_Label                  clipLabel = tool->AddClippingPlane(plane, eName, capping);
    if (clipLabel.IsNull())
      return -1;
    return doc->registerLabel(clipLabel);
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDocumentClipPlaneToolGet(OCCTDocumentRef ref,
                                  int64_t         labelId,
                                  double*         origX,
                                  double*         origY,
                                  double*         origZ,
                                  double*         normX,
                                  double*         normY,
                                  double*         normZ,
                                  bool*           capping)
{
  if (!ref)
    return false;
  try
  {
    auto*                             doc  = (OCCTDocument*)ref;
    TDF_Label                         main = doc->doc->Main();
    Handle(XCAFDoc_ClippingPlaneTool) tool = XCAFDoc_DocumentTool::ClippingPlaneTool(main);
    if (tool.IsNull())
      return false;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    gp_Pln                     plane;
    TCollection_ExtendedString name;
    bool                       cap = false;
    if (!tool->GetClippingPlane(label, plane, name, cap))
      return false;
    *origX   = plane.Location().X();
    *origY   = plane.Location().Y();
    *origZ   = plane.Location().Z();
    gp_Dir n = plane.Axis().Direction();
    *normX   = n.X();
    *normY   = n.Y();
    *normZ   = n.Z();
    *capping = cap;
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentClipPlaneToolIsClipPlane(OCCTDocumentRef ref, int64_t labelId)
{
  if (!ref)
    return false;
  try
  {
    auto*                             doc  = (OCCTDocument*)ref;
    TDF_Label                         main = doc->doc->Main();
    Handle(XCAFDoc_ClippingPlaneTool) tool = XCAFDoc_DocumentTool::ClippingPlaneTool(main);
    if (tool.IsNull())
      return false;
    TDF_Label label = doc->getLabel(labelId);
    return tool->IsClippingPlane(label);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentClipPlaneToolRemove(OCCTDocumentRef ref, int64_t labelId)
{
  if (!ref)
    return false;
  try
  {
    auto*                             doc  = (OCCTDocument*)ref;
    TDF_Label                         main = doc->doc->Main();
    Handle(XCAFDoc_ClippingPlaneTool) tool = XCAFDoc_DocumentTool::ClippingPlaneTool(main);
    if (tool.IsNull())
      return false;
    TDF_Label label = doc->getLabel(labelId);
    return tool->RemoveClippingPlane(label);
  }
  catch (...)
  {
    return false;
  }
}

OCCTXCAFPrsStyle OCCTXCAFPrsStyleCreateWithSurfColor(double r, double g, double b, float alpha)
{
  XCAFPrs_Style      style;
  Quantity_ColorRGBA rgba(Quantity_Color(r, g, b, Quantity_TOC_sRGB), alpha);
  style.SetColorSurf(rgba);
  OCCTXCAFPrsStyle result;
  result.surfR        = r;
  result.surfG        = g;
  result.surfB        = b;
  result.surfAlpha    = alpha;
  result.hasSurfColor = true;
  result.curvR        = 0;
  result.curvG        = 0;
  result.curvB        = 0;
  result.hasCurvColor = false;
  result.isVisible    = style.IsVisible();
  result.isEmpty      = style.IsEmpty();
  return result;
}

bool OCCTXCAFPrsStyleIsEqual(const OCCTXCAFPrsStyle* s1, const OCCTXCAFPrsStyle* s2)
{
  try
  {
    XCAFPrs_Style style1, style2;
    if (s1->hasSurfColor)
    {
      style1.SetColorSurf(
        Quantity_ColorRGBA(Quantity_Color(s1->surfR, s1->surfG, s1->surfB, Quantity_TOC_sRGB),
                           s1->surfAlpha));
    }
    if (s1->hasCurvColor)
    {
      style1.SetColorCurv(Quantity_Color(s1->curvR, s1->curvG, s1->curvB, Quantity_TOC_sRGB));
    }
    style1.SetVisibility(s1->isVisible);

    if (s2->hasSurfColor)
    {
      style2.SetColorSurf(
        Quantity_ColorRGBA(Quantity_Color(s2->surfR, s2->surfG, s2->surfB, Quantity_TOC_sRGB),
                           s2->surfAlpha));
    }
    if (s2->hasCurvColor)
    {
      style2.SetColorCurv(Quantity_Color(s2->curvR, s2->curvG, s2->curvB, Quantity_TOC_sRGB));
    }
    style2.SetVisibility(s2->isVisible);

    return style1.IsEqual(style2);
  }
  catch (...)
  {
    return false;
  }
}

OCCTVisMaterialCommon OCCTVisMaterialCommonDefault(void)
{
  XCAFDoc_VisMaterialCommon mat;
  OCCTVisMaterialCommon     result;
  result.diffuseR     = mat.DiffuseColor.Red();
  result.diffuseG     = mat.DiffuseColor.Green();
  result.diffuseB     = mat.DiffuseColor.Blue();
  result.ambientR     = mat.AmbientColor.Red();
  result.ambientG     = mat.AmbientColor.Green();
  result.ambientB     = mat.AmbientColor.Blue();
  result.specularR    = mat.SpecularColor.Red();
  result.specularG    = mat.SpecularColor.Green();
  result.specularB    = mat.SpecularColor.Blue();
  result.emissiveR    = mat.EmissiveColor.Red();
  result.emissiveG    = mat.EmissiveColor.Green();
  result.emissiveB    = mat.EmissiveColor.Blue();
  result.shininess    = mat.Shininess;
  result.transparency = mat.Transparency;
  result.isDefined    = mat.IsDefined;
  return result;
}

bool OCCTVisMaterialCommonIsEqual(const OCCTVisMaterialCommon* a, const OCCTVisMaterialCommon* b)
{
  try
  {
    XCAFDoc_VisMaterialCommon ma, mb;
    ma.DiffuseColor  = Quantity_Color(a->diffuseR, a->diffuseG, a->diffuseB, Quantity_TOC_sRGB);
    ma.AmbientColor  = Quantity_Color(a->ambientR, a->ambientG, a->ambientB, Quantity_TOC_sRGB);
    ma.SpecularColor = Quantity_Color(a->specularR, a->specularG, a->specularB, Quantity_TOC_sRGB);
    ma.EmissiveColor = Quantity_Color(a->emissiveR, a->emissiveG, a->emissiveB, Quantity_TOC_sRGB);
    ma.Shininess     = a->shininess;
    ma.Transparency  = a->transparency;
    ma.IsDefined     = a->isDefined;

    mb.DiffuseColor  = Quantity_Color(b->diffuseR, b->diffuseG, b->diffuseB, Quantity_TOC_sRGB);
    mb.AmbientColor  = Quantity_Color(b->ambientR, b->ambientG, b->ambientB, Quantity_TOC_sRGB);
    mb.SpecularColor = Quantity_Color(b->specularR, b->specularG, b->specularB, Quantity_TOC_sRGB);
    mb.EmissiveColor = Quantity_Color(b->emissiveR, b->emissiveG, b->emissiveB, Quantity_TOC_sRGB);
    mb.Shininess     = b->shininess;
    mb.Transparency  = b->transparency;
    mb.IsDefined     = b->isDefined;

    return ma.IsEqual(mb);
  }
  catch (...)
  {
    return false;
  }
}

OCCTVisMaterialPBR OCCTVisMaterialPBRDefault(void)
{
  XCAFDoc_VisMaterialPBR pbr;
  OCCTVisMaterialPBR     result;
  result.baseColorR      = pbr.BaseColor.GetRGB().Red();
  result.baseColorG      = pbr.BaseColor.GetRGB().Green();
  result.baseColorB      = pbr.BaseColor.GetRGB().Blue();
  result.baseColorAlpha  = pbr.BaseColor.Alpha();
  result.metallic        = pbr.Metallic;
  result.roughness       = pbr.Roughness;
  result.refractionIndex = pbr.RefractionIndex;
  result.emissionR       = pbr.EmissiveFactor.r();
  result.emissionG       = pbr.EmissiveFactor.g();
  result.emissionB       = pbr.EmissiveFactor.b();
  result.isDefined       = pbr.IsDefined;
  return result;
}

bool OCCTVisMaterialPBRIsEqual(const OCCTVisMaterialPBR* a, const OCCTVisMaterialPBR* b)
{
  try
  {
    XCAFDoc_VisMaterialPBR pa, pb;
    pa.BaseColor = Quantity_ColorRGBA(
      Quantity_Color(a->baseColorR, a->baseColorG, a->baseColorB, Quantity_TOC_sRGB),
      a->baseColorAlpha);
    pa.Metallic        = a->metallic;
    pa.Roughness       = a->roughness;
    pa.RefractionIndex = a->refractionIndex;
    pa.EmissiveFactor =
      Graphic3d_Vec3((float)a->emissionR, (float)a->emissionG, (float)a->emissionB);
    pa.IsDefined = a->isDefined;

    pb.BaseColor = Quantity_ColorRGBA(
      Quantity_Color(b->baseColorR, b->baseColorG, b->baseColorB, Quantity_TOC_sRGB),
      b->baseColorAlpha);
    pb.Metallic        = b->metallic;
    pb.Roughness       = b->roughness;
    pb.RefractionIndex = b->refractionIndex;
    pb.EmissiveFactor =
      Graphic3d_Vec3((float)b->emissionR, (float)b->emissionG, (float)b->emissionB);
    pb.IsDefined = b->isDefined;

    return pa.IsEqual(pb);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentColorToolIsVisible(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc)
    return true;
  try
  {
    TDF_Label lab = doc->getLabel(labelId);
    if (lab.IsNull())
      return true;
    return XCAFDoc_ColorTool::IsVisible(lab);
  }
  catch (...)
  {
    return true;
  }
}
