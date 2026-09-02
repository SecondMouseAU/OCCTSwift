//
//  OCCTBridge_Document_GDT.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Document.mm (#1380): XDE GD&T/Dimension Tolerance,
//  XCAFDoc_Datum/DimTol/DimTolTool/GeomTolerance/Dimension/GraphNode, XCAFDimTolObjects. Public C
//  surface unchanged; every sibling file imports the same headers this one does (the shared
//  preamble below). No symbol changes, pure file move -- see Scripts/repro/396-bridge-mm-split/ for
//  how.
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

int32_t OCCTDocumentGetDimensionCount(OCCTDocumentRef doc)
{
  if (!doc || doc->doc.IsNull())
    return 0;
  try
  {
    Handle(XCAFDoc_DimTolTool) dimTolTool = XCAFDoc_DocumentTool::DimTolTool(doc->doc->Main());
    TDF_LabelSequence          labels;
    dimTolTool->GetDimensionLabels(labels);
    return (int32_t)labels.Length();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTDocumentGetGeomToleranceCount(OCCTDocumentRef doc)
{
  if (!doc || doc->doc.IsNull())
    return 0;
  try
  {
    Handle(XCAFDoc_DimTolTool) dimTolTool = XCAFDoc_DocumentTool::DimTolTool(doc->doc->Main());
    TDF_LabelSequence          labels;
    dimTolTool->GetGeomToleranceLabels(labels);
    return (int32_t)labels.Length();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTDocumentGetDatumCount(OCCTDocumentRef doc)
{
  if (!doc || doc->doc.IsNull())
    return 0;
  try
  {
    Handle(XCAFDoc_DimTolTool) dimTolTool = XCAFDoc_DocumentTool::DimTolTool(doc->doc->Main());
    TDF_LabelSequence          labels;
    dimTolTool->GetDatumLabels(labels);
    return (int32_t)labels.Length();
  }
  catch (...)
  {
    return 0;
  }
}

OCCTDimensionInfo OCCTDocumentGetDimensionInfo(OCCTDocumentRef doc, int32_t index)
{
  OCCTDimensionInfo info = {};
  info.isValid           = false;
  try
  {
    Handle(XCAFDoc_Dimension)                 dimAttr;
    Handle(XCAFDimTolObjects_DimensionObject) dimObj;
    if (!occtDocumentDimensionObjectAt(doc, index, dimAttr, dimObj))
      return info;

    info.type = (int32_t)dimObj->GetType();

    // Ask OCCT which kind this is rather than re-deriving it from the array length: the two
    // predicates ARE the length test, so asking them keeps the rule in one place (#996).
    Handle(TColStd_HArray1OfReal) vals = dimObj->GetValues();
    if (dimObj->IsDimWithRange())
      info.boundsKind = OCCTDimensionBoundsRange;
    else if (dimObj->IsDimWithPlusMinusTolerance())
      info.boundsKind = OCCTDimensionBoundsPlusMinus;
    else if (!vals.IsNull() && vals->Length() > 0)
      info.boundsKind = OCCTDimensionBoundsSimple;
    else
      info.boundsKind = OCCTDimensionBoundsUnset;

    // GetValue(), not vals->Value(vals->Lower()). For a range those differ: GetValue() returns the
    // midpoint, the first slot is the lower bound, and reporting the latter as "the value" is what
    // made a 10..12 range read back as a plain 10 with no tolerance (#996).
    info.value      = dimObj->GetValue();
    info.lowerBound = dimObj->GetLowerBound();
    info.upperBound = dimObj->GetUpperBound();
    // The pinned header's doc comments on this pair are swapped upstream ("Returns the lower value"
    // sits above GetUpperTolValue, and vice versa), and the 8.0.1 refman renders the same swap. The
    // functions are not swapped: measured on a raw [100,200,300] values array, GetLowerTolValue()
    // returns slot 2 (200) and GetUpperTolValue() slot 3 (300), which is what
    // SetLowerTolValue/SetUpperTolValue write. Do not "fix" these two to match the comments. See
    // Scripts/repro/996-gdt-read-surface/.
    info.lowerTol = dimObj->GetLowerTolValue();
    info.upperTol = dimObj->GetUpperTolValue();

    // Independent of boundsKind: a range dimension can carry an ISO 286 class too, since
    // IsDimWithClassOfTolerance() reads the form variance rather than the array length.
    info.hasClassOfTolerance = dimObj->IsDimWithClassOfTolerance();
    if (info.hasClassOfTolerance)
    {
      bool                                    isHole = false;
      XCAFDimTolObjects_DimensionFormVariance fmVar  = XCAFDimTolObjects_DimensionFormVariance_None;
      XCAFDimTolObjects_DimensionGrade        grade  = XCAFDimTolObjects_DimensionGrade_IT01;
      if (dimObj->GetClassOfTolerance(isHole, fmVar, grade))
      {
        info.classOfToleranceIsHole = isHole;
        info.formVariance           = (int32_t)fmVar;
        info.grade                  = (int32_t)grade;
      }
      else
      {
        info.hasClassOfTolerance = false;
      }
    }

    // Both qualifiers carry their own absence: OCCT's _None member is ordinal 0 and HasQualifier()
    // is exactly `!= _None`, so the enum value is reported as-is and the predicate is asked of OCCT
    // rather than re-derived here, the same way boundsKind is above (#1004).
    info.qualifier        = (int32_t)dimObj->GetQualifier();
    info.angularQualifier = (int32_t)dimObj->GetAngularQualifier();

    // GetNbOfDecimalPlaces has no predicate beside it, and its pair is stored on the label only
    // when one of the two is positive, so that condition is the presence test.
    int left = 0, right = 0;
    dimObj->GetNbOfDecimalPlaces(left, right);
    info.hasDecimalPlaces = (left > 0 || right > 0);
    if (info.hasDecimalPlaces)
    {
      info.decimalPlacesLeft  = (int32_t)left;
      info.decimalPlacesRight = (int32_t)right;
    }

    info.modifierCount = (int32_t)dimObj->GetModifiers().Length();

    info.isValid = true;
    return info;
  }
  catch (...)
  {
    return info;
  }
}

int32_t OCCTDocumentGetDimensionModifier(OCCTDocumentRef doc,
                                         int32_t         dimensionIndex,
                                         int32_t         modifierIndex)
{
  if (modifierIndex < 0)
    return -1;
  try
  {
    Handle(XCAFDoc_Dimension)                 dimAttr;
    Handle(XCAFDimTolObjects_DimensionObject) dimObj;
    if (!occtDocumentDimensionObjectAt(doc, dimensionIndex, dimAttr, dimObj))
      return -1;

    // NCollection_Sequence is 1-based; the bridge's own index is 0-based, matching every other
    // count-plus-index pair here.
    const NCollection_Sequence<XCAFDimTolObjects_DimensionModif> modifiers = dimObj->GetModifiers();
    if (modifierIndex >= modifiers.Length())
      return -1;
    return (int32_t)modifiers.Value(modifierIndex + 1);
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDimensionTypeIsDimensionalLocation(int32_t type)
{
  if (type < 0 || type > (int32_t)XCAFDimTolObjects_DimensionType_DimensionPresentation)
    return false;
  return XCAFDimTolObjects_DimensionObject::IsDimensionalLocation(
    (XCAFDimTolObjects_DimensionType)type);
}

bool OCCTDimensionTypeIsDimensionalSize(int32_t type)
{
  if (type < 0 || type > (int32_t)XCAFDimTolObjects_DimensionType_DimensionPresentation)
    return false;
  return XCAFDimTolObjects_DimensionObject::IsDimensionalSize(
    (XCAFDimTolObjects_DimensionType)type);
}

OCCTGeomToleranceInfo OCCTDocumentGetGeomToleranceInfo(OCCTDocumentRef doc, int32_t index)
{
  OCCTGeomToleranceInfo info = {};
  info.isValid               = false;
  try
  {
    Handle(XCAFDoc_GeomTolerance)                 tolAttr;
    Handle(XCAFDimTolObjects_GeomToleranceObject) tolObj;
    if (!occtDocumentGeomToleranceObjectAt(doc, index, tolAttr, tolObj))
      return info;

    info.type  = (int32_t)tolObj->GetType();
    info.value = tolObj->GetValue();

    // Three enums whose _None member is their own absence, reported as-is, the same way the
    // dimension qualifiers are above (#1004).
    info.typeOfValue         = (int32_t)tolObj->GetTypeOfValue();
    info.materialRequirement = (int32_t)tolObj->GetMaterialRequirementModifier();
    info.zoneModifier        = (int32_t)tolObj->GetZoneModifier();

    // Two doubles with no _None member and no predicate. XCAFDoc_GeomTolerance::SetObject stores
    // each only when it is positive, so that condition is the presence test; a zero is what an
    // unstored one reads back as, and the two are not distinguishable any other way.
    const double zoneValue    = tolObj->GetValueOfZoneModifier();
    info.hasZoneModifierValue = (zoneValue > 0.0);
    info.zoneModifierValue    = info.hasZoneModifierValue ? zoneValue : 0.0;
    const double maxValue     = tolObj->GetMaxValueModifier();
    info.hasMaxValueModifier  = (maxValue > 0.0);
    info.maxValueModifier     = info.hasMaxValueModifier ? maxValue : 0.0;

    info.modifierCount = (int32_t)tolObj->GetModifiers().Length();

    info.isValid = true;
    return info;
  }
  catch (...)
  {
    return info;
  }
}

int32_t OCCTDocumentGetGeomToleranceModifier(OCCTDocumentRef doc,
                                             int32_t         toleranceIndex,
                                             int32_t         modifierIndex)
{
  if (modifierIndex < 0)
    return -1;
  try
  {
    Handle(XCAFDoc_GeomTolerance)                 tolAttr;
    Handle(XCAFDimTolObjects_GeomToleranceObject) tolObj;
    if (!occtDocumentGeomToleranceObjectAt(doc, toleranceIndex, tolAttr, tolObj))
      return -1;

    const NCollection_Sequence<XCAFDimTolObjects_GeomToleranceModif> modifiers =
      tolObj->GetModifiers();
    if (modifierIndex >= modifiers.Length())
      return -1;
    return (int32_t)modifiers.Value(modifierIndex + 1);
  }
  catch (...)
  {
    return -1;
  }
}

OCCTDatumInfo OCCTDocumentGetDatumInfo(OCCTDocumentRef doc, int32_t index)
{
  OCCTDatumInfo info = {};
  info.isValid       = false;
  try
  {
    Handle(XCAFDoc_Datum)                 datumAttr;
    Handle(XCAFDimTolObjects_DatumObject) datumObj;
    if (!occtDocumentDatumObjectAt(doc, index, datumAttr, datumObj))
      return info;

    // Positions in a reference frame are 1-based, so 0 is the reading for a datum that has no
    // place in one rather than a first place. See the struct's own comment for the derivation.
    const int position = datumObj->GetPosition();
    info.hasPosition   = (position > 0);
    info.position      = info.hasPosition ? (int32_t)position : 0;

    XCAFDimTolObjects_DatumModifWithValue modifier = XCAFDimTolObjects_DatumModifWithValue_None;
    double                                modifierValue = 0.0;
    datumObj->GetModifierWithValue(modifier, modifierValue);
    info.modifierWithValue = (int32_t)modifier;
    // The value is only ever read under its own modifier, so it is left at 0 rather than reported
    // when there is none: GetModifierWithValue writes both out-parameters unconditionally, and the
    // second is the fresh object's unassigned member when no modifier was ever set.
    info.modifierValue =
      (modifier != XCAFDimTolObjects_DatumModifWithValue_None) ? modifierValue : 0.0;

    info.modifierCount = (int32_t)datumObj->GetModifiers().Length();

    info.isDatumTarget = datumObj->IsDatumTarget();
    if (info.isDatumTarget)
    {
      const XCAFDimTolObjects_DatumTargetType targetType = datumObj->GetDatumTargetType();
      info.targetType                                    = (int32_t)targetType;
      info.targetNumber = (int32_t)datumObj->GetDatumTargetNumber();

      // XCAFDoc_Datum::SetObject nests the length inside HasDatumTargetParams() and a
      // `type != _Point` test, and the width inside that plus `type == _Rectangle`. Anything
      // outside those two combinations is the object's own unassigned member; measured per type in
      // Scripts/repro/1004-gdt-accessors/.
      info.hasTargetParams = datumObj->HasDatumTargetParams();
      if (info.hasTargetParams)
      {
        info.hasTargetLength = (targetType != XCAFDimTolObjects_DatumTargetType_Point);
        if (info.hasTargetLength)
          info.targetLength = datumObj->GetDatumTargetLength();
        info.hasTargetWidth = (targetType == XCAFDimTolObjects_DatumTargetType_Rectangle);
        if (info.hasTargetWidth)
          info.targetWidth = datumObj->GetDatumTargetWidth();
      }
    }

    info.isValid = true;
    return info;
  }
  catch (...)
  {
    return info;
  }
}

int32_t OCCTDocumentGetDatumName(OCCTDocumentRef doc, int32_t index, char* outName, int32_t maxLen)
{
  if (maxLen < 0 || (maxLen > 0 && !outName))
    return -1;
  if (maxLen > 0)
    outName[0] = '\0';
  try
  {
    Handle(XCAFDoc_Datum)                 datumAttr;
    Handle(XCAFDimTolObjects_DatumObject) datumObj;
    if (!occtDocumentDatumObjectAt(doc, index, datumAttr, datumObj))
      return -1;

    Handle(TCollection_HAsciiString) hName = datumObj->GetName();
    // A datum with no name reads as the empty string rather than as a failure: absence of a name is
    // not absence of a datum, and -1 is reserved for a datum that cannot be read at all.
    const int32_t length = hName.IsNull() ? 0 : (int32_t)hName->Length();
    if (length > 0 && maxLen > 0)
    {
      const int32_t copied = std::min(length, maxLen - 1);
      memcpy(outName, hName->String().ToCString(), (size_t)copied);
      outName[copied] = '\0';
    }
    // The whole length, never the copied length: a caller compares it against its own maxLen to
    // learn that what it holds is a prefix, which is the report the fixed 64-byte buffer could not
    // make (#1055).
    return length;
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTDocumentGetDatumModifier(OCCTDocumentRef doc, int32_t datumIndex, int32_t modifierIndex)
{
  if (modifierIndex < 0)
    return -1;
  try
  {
    Handle(XCAFDoc_Datum)                 datumAttr;
    Handle(XCAFDimTolObjects_DatumObject) datumObj;
    if (!occtDocumentDatumObjectAt(doc, datumIndex, datumAttr, datumObj))
      return -1;

    const NCollection_Sequence<XCAFDimTolObjects_DatumSingleModif> modifiers =
      datumObj->GetModifiers();
    if (modifierIndex >= modifiers.Length())
      return -1;
    return (int32_t)modifiers.Value(modifierIndex + 1);
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTDocumentCreateGeomTolerance(OCCTDocumentRef doc,
                                        int64_t         shapeLabelId,
                                        int32_t         type,
                                        double          value)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  try
  {
    Handle(XCAFDoc_DimTolTool) dimTolTool = XCAFDoc_DocumentTool::DimTolTool(doc->doc->Main());
    TDF_Label                  shapeLabel = doc->getLabel(shapeLabelId);
    if (shapeLabel.IsNull())
      return -1;

    TDF_Label         tolLabel = dimTolTool->AddGeomTolerance();
    TDF_LabelSequence shapeSeq;
    shapeSeq.Append(shapeLabel);
    dimTolTool->SetGeomTolerance(shapeSeq, tolLabel);

    Handle(XCAFDoc_GeomTolerance) tolAttr;
    if (!tolLabel.FindAttribute(XCAFDoc_GeomTolerance::GetID(), tolAttr))
      return -1;

    Handle(XCAFDimTolObjects_GeomToleranceObject) tolObj =
      new XCAFDimTolObjects_GeomToleranceObject();
    // The constructor sets four booleans and the affected-plane type, and nothing else;
    // XCAFDoc_GeomTolerance::SetObject then reads these five off the object unconditionally to
    // decide what to store. Left alone they are storage nobody wrote (#1004).
    tolObj->SetTypeOfValue(XCAFDimTolObjects_GeomToleranceTypeValue_None);
    tolObj->SetMaterialRequirementModifier(XCAFDimTolObjects_GeomToleranceMatReqModif_None);
    tolObj->SetZoneModifier(XCAFDimTolObjects_GeomToleranceZoneModif_None);
    tolObj->SetValueOfZoneModifier(0.0);
    tolObj->SetMaxValueModifier(0.0);
    tolObj->SetType((XCAFDimTolObjects_GeomToleranceType)type);
    tolObj->SetValue(value);
    tolAttr->SetObject(tolObj);

    TDF_LabelSequence labels;
    dimTolTool->GetGeomToleranceLabels(labels);
    return (int32_t)labels.Length() - 1;
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTDocumentCreateDatum(OCCTDocumentRef doc, const char* name)
{
  if (!doc || doc->doc.IsNull() || !name)
    return -1;
  try
  {
    Handle(XCAFDoc_DimTolTool) dimTolTool = XCAFDoc_DocumentTool::DimTolTool(doc->doc->Main());

    TDF_Label             datLabel = dimTolTool->AddDatum();
    Handle(XCAFDoc_Datum) datAttr;
    if (!datLabel.FindAttribute(XCAFDoc_Datum::GetID(), datAttr))
      return -1;

    Handle(XCAFDimTolObjects_DatumObject) datObj = new XCAFDimTolObjects_DatumObject();
    // XCAFDoc_Datum::SetObject reads exactly two things off the object before it knows whether the
    // datum is a target: the position and the modifier-with-value pair. Both are storage the
    // constructor never wrote, so they are assigned here. The target type, number, length and width
    // are deliberately NOT assigned: each sits behind myIsDTarget or myIsValidDT, which the
    // constructor does set to false, and SetDatumTargetLength/Width/Axis would raise myIsValidDT
    // as a side effect and report a datum target where there is none (#1004).
    datObj->SetPosition(0);
    datObj->SetModifierWithValue(XCAFDimTolObjects_DatumModifWithValue_None, 0.0);
    datObj->SetName(new TCollection_HAsciiString(name));
    datAttr->SetObject(datObj);

    TDF_LabelSequence labels;
    dimTolTool->GetDatumLabels(labels);
    return (int32_t)labels.Length() - 1;
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDocumentSetDimensionTolerance(OCCTDocumentRef doc,
                                       int32_t         dimensionIndex,
                                       double          lowerTol,
                                       double          upperTol)
{
  try
  {
    Handle(XCAFDoc_Dimension)                 dimAttr;
    Handle(XCAFDimTolObjects_DimensionObject) dimObj;
    if (!occtDocumentDimensionObjectAt(doc, dimensionIndex, dimAttr, dimObj))
      return false;

    if (!occtDimensionApplyTolerance(dimObj, lowerTol, upperTol))
      return false;

    dimAttr->SetObject(dimObj);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetDimensionBounds(OCCTDocumentRef doc,
                                    int32_t         dimensionIndex,
                                    double          lowerBound,
                                    double          upperBound)
{
  try
  {
    Handle(XCAFDoc_Dimension)                 dimAttr;
    Handle(XCAFDimTolObjects_DimensionObject) dimObj;
    if (!occtDocumentDimensionObjectAt(doc, dimensionIndex, dimAttr, dimObj))
      return false;

    // SetLowerBound/SetUpperBound branch on myVal->Length() > 1. From a SIMPLE dimension they
    // build the degenerate range this call wants, either way round. From a PLUS/MINUS one they
    // write IN PLACE into slots 1 and 2 of a length-3 array, so the requested upper bound lands
    // in the lower TOLERANCE slot, the stale upper tolerance survives, and the dimension stays
    // plus/minus. Measured: [20,-0.3,0.7] then bounds 10/12 gives GetValue=10, loTol=12,
    // upTol=0.7, still plus/minus. So verify the readback rather than trusting the writes, the
    // same way OCCTDocumentSetDimensionTolerance does for the opposite conversion.
    // Refuse BEFORE writing, not after. GetObject hands back an object aliasing the document's
    // live TDataStd_RealArray, so a rejected write has already corrupted the stored dimension by
    // the time a readback could notice: measured, a refusal after the fact still left value=10.
    if (dimObj->IsDimWithPlusMinusTolerance())
      return false;

    dimObj->SetLowerBound(lowerBound);
    dimObj->SetUpperBound(upperBound);
    if (!dimObj->IsDimWithRange() || dimObj->GetLowerBound() != lowerBound
        || dimObj->GetUpperBound() != upperBound)
      return false;

    dimAttr->SetObject(dimObj);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetDimensionClassOfTolerance(OCCTDocumentRef doc,
                                              int32_t         dimensionIndex,
                                              bool            isHole,
                                              int32_t         formVariance,
                                              int32_t         grade)
{
  // #1037: an out-of-range formVariance is not merely stored and read back, it also makes
  // XCAFDimTolObjects_DimensionObject::IsDimWithClassOfTolerance() true, since that is a bare
  // test against _None. The reader then reports the class as present while the value decodes to
  // nothing.
  if (formVariance < 0 || formVariance > (int32_t)XCAFDimTolObjects_DimensionFormVariance_ZC
      || grade < 0 || grade > (int32_t)XCAFDimTolObjects_DimensionGrade_IT18)
    return false;
  try
  {
    Handle(XCAFDoc_Dimension)                 dimAttr;
    Handle(XCAFDimTolObjects_DimensionObject) dimObj;
    if (!occtDocumentDimensionObjectAt(doc, dimensionIndex, dimAttr, dimObj))
      return false;

    dimObj->SetClassOfTolerance(isHole,
                                (XCAFDimTolObjects_DimensionFormVariance)formVariance,
                                (XCAFDimTolObjects_DimensionGrade)grade);
    dimAttr->SetObject(dimObj);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetDimensionQualifier(OCCTDocumentRef doc,
                                       int32_t         dimensionIndex,
                                       int32_t         qualifier)
{
  if (qualifier < 0 || qualifier > (int32_t)XCAFDimTolObjects_DimensionQualifier_Avg)
    return false;
  try
  {
    Handle(XCAFDoc_Dimension)                 dimAttr;
    Handle(XCAFDimTolObjects_DimensionObject) dimObj;
    if (!occtDocumentDimensionObjectAt(doc, dimensionIndex, dimAttr, dimObj))
      return false;

    dimObj->SetQualifier((XCAFDimTolObjects_DimensionQualifier)qualifier);
    dimAttr->SetObject(dimObj);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetDimensionAngularQualifier(OCCTDocumentRef doc,
                                              int32_t         dimensionIndex,
                                              int32_t         angularQualifier)
{
  if (angularQualifier < 0 || angularQualifier > (int32_t)XCAFDimTolObjects_AngularQualifier_Equal)
    return false;
  try
  {
    Handle(XCAFDoc_Dimension)                 dimAttr;
    Handle(XCAFDimTolObjects_DimensionObject) dimObj;
    if (!occtDocumentDimensionObjectAt(doc, dimensionIndex, dimAttr, dimObj))
      return false;

    dimObj->SetAngularQualifier((XCAFDimTolObjects_AngularQualifier)angularQualifier);
    dimAttr->SetObject(dimObj);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetDimensionDecimalPlaces(OCCTDocumentRef doc,
                                           int32_t         dimensionIndex,
                                           int32_t         left,
                                           int32_t         right)
{
  if (left < 0 || right < 0)
    return false;
  try
  {
    Handle(XCAFDoc_Dimension)                 dimAttr;
    Handle(XCAFDimTolObjects_DimensionObject) dimObj;
    if (!occtDocumentDimensionObjectAt(doc, dimensionIndex, dimAttr, dimObj))
      return false;

    dimObj->SetNbOfDecimalPlaces((int)left, (int)right);
    dimAttr->SetObject(dimObj);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetDimensionModifiers(OCCTDocumentRef doc,
                                       int32_t         dimensionIndex,
                                       const int32_t*  modifiers,
                                       int32_t         count)
{
  if (count < 0 || (count > 0 && !modifiers)
      || !occtDocumentModifiersInRange(modifiers,
                                       count,
                                       (int32_t)XCAFDimTolObjects_DimensionModif_Between))
    return false;
  try
  {
    Handle(XCAFDoc_Dimension)                 dimAttr;
    Handle(XCAFDimTolObjects_DimensionObject) dimObj;
    if (!occtDocumentDimensionObjectAt(doc, dimensionIndex, dimAttr, dimObj))
      return false;

    NCollection_Sequence<XCAFDimTolObjects_DimensionModif> sequence;
    for (int32_t i = 0; i < count; ++i)
      sequence.Append((XCAFDimTolObjects_DimensionModif)modifiers[i]);
    // SetModifiers replaces the sequence outright, so an empty one clears it, which is what the
    // header promises for count 0. AddModifier would append instead and could not express that.
    dimObj->SetModifiers(sequence);
    dimAttr->SetObject(dimObj);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetGeomToleranceTypeOfValue(OCCTDocumentRef doc,
                                             int32_t         toleranceIndex,
                                             int32_t         typeOfValue)
{
  if (typeOfValue < 0
      || typeOfValue > (int32_t)XCAFDimTolObjects_GeomToleranceTypeValue_SphericalDiameter)
    return false;
  try
  {
    Handle(XCAFDoc_GeomTolerance)                 tolAttr;
    Handle(XCAFDimTolObjects_GeomToleranceObject) tolObj;
    if (!occtDocumentGeomToleranceObjectAt(doc, toleranceIndex, tolAttr, tolObj))
      return false;

    tolObj->SetTypeOfValue((XCAFDimTolObjects_GeomToleranceTypeValue)typeOfValue);
    tolAttr->SetObject(tolObj);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetGeomToleranceMaterialRequirement(OCCTDocumentRef doc,
                                                     int32_t         toleranceIndex,
                                                     int32_t         materialRequirement)
{
  if (materialRequirement < 0
      || materialRequirement > (int32_t)XCAFDimTolObjects_GeomToleranceMatReqModif_L)
    return false;
  try
  {
    Handle(XCAFDoc_GeomTolerance)                 tolAttr;
    Handle(XCAFDimTolObjects_GeomToleranceObject) tolObj;
    if (!occtDocumentGeomToleranceObjectAt(doc, toleranceIndex, tolAttr, tolObj))
      return false;

    tolObj->SetMaterialRequirementModifier(
      (XCAFDimTolObjects_GeomToleranceMatReqModif)materialRequirement);
    tolAttr->SetObject(tolObj);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetGeomToleranceZoneModifier(OCCTDocumentRef doc,
                                              int32_t         toleranceIndex,
                                              int32_t         zoneModifier,
                                              double          value)
{
  if (zoneModifier < 0
      || zoneModifier > (int32_t)XCAFDimTolObjects_GeomToleranceZoneModif_NonUniform)
    return false;
  try
  {
    Handle(XCAFDoc_GeomTolerance)                 tolAttr;
    Handle(XCAFDimTolObjects_GeomToleranceObject) tolObj;
    if (!occtDocumentGeomToleranceObjectAt(doc, toleranceIndex, tolAttr, tolObj))
      return false;

    const bool none = (zoneModifier == (int32_t)XCAFDimTolObjects_GeomToleranceZoneModif_None);
    tolObj->SetZoneModifier((XCAFDimTolObjects_GeomToleranceZoneModif)zoneModifier);
    // A non-positive value is normalised to 0 rather than passed through, so the stored state
    // matches what the reader can report: SetObject writes the value only under `> 0`, and a
    // negative one would be silently dropped on the way out. A _None modifier clears the value for
    // the same reason it is cleared in OCCTDocumentSetDatumModifierWithValue: the reader gates the
    // value on `> 0` and never on the modifier, so a number surviving a cleared modifier reads
    // back as a projected-zone length on a tolerance that has no projected zone (#1056).
    tolObj->SetValueOfZoneModifier((!none && value > 0.0) ? value : 0.0);
    tolAttr->SetObject(tolObj);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetGeomToleranceMaxValueModifier(OCCTDocumentRef doc,
                                                  int32_t         toleranceIndex,
                                                  double          value)
{
  try
  {
    Handle(XCAFDoc_GeomTolerance)                 tolAttr;
    Handle(XCAFDimTolObjects_GeomToleranceObject) tolObj;
    if (!occtDocumentGeomToleranceObjectAt(doc, toleranceIndex, tolAttr, tolObj))
      return false;

    tolObj->SetMaxValueModifier(value > 0.0 ? value : 0.0);
    tolAttr->SetObject(tolObj);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetGeomToleranceModifiers(OCCTDocumentRef doc,
                                           int32_t         toleranceIndex,
                                           const int32_t*  modifiers,
                                           int32_t         count)
{
  if (count < 0 || (count > 0 && !modifiers)
      || !occtDocumentModifiersInRange(modifiers,
                                       count,
                                       (int32_t)XCAFDimTolObjects_GeomToleranceModif_All_Over))
    return false;
  try
  {
    Handle(XCAFDoc_GeomTolerance)                 tolAttr;
    Handle(XCAFDimTolObjects_GeomToleranceObject) tolObj;
    if (!occtDocumentGeomToleranceObjectAt(doc, toleranceIndex, tolAttr, tolObj))
      return false;

    NCollection_Sequence<XCAFDimTolObjects_GeomToleranceModif> sequence;
    for (int32_t i = 0; i < count; ++i)
      sequence.Append((XCAFDimTolObjects_GeomToleranceModif)modifiers[i]);
    tolObj->SetModifiers(sequence);
    tolAttr->SetObject(tolObj);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetDatumPosition(OCCTDocumentRef doc, int32_t datumIndex, int32_t position)
{
  try
  {
    Handle(XCAFDoc_Datum)                 datumAttr;
    Handle(XCAFDimTolObjects_DatumObject) datumObj;
    if (!occtDocumentDatumObjectAt(doc, datumIndex, datumAttr, datumObj))
      return false;

    datumObj->SetPosition(position > 0 ? (int)position : 0);
    datumAttr->SetObject(datumObj);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetDatumModifiers(OCCTDocumentRef doc,
                                   int32_t         datumIndex,
                                   const int32_t*  modifiers,
                                   int32_t         count)
{
  if (count < 0 || (count > 0 && !modifiers)
      || !occtDocumentModifiersInRange(modifiers,
                                       count,
                                       (int32_t)XCAFDimTolObjects_DatumSingleModif_Translation))
    return false;
  try
  {
    Handle(XCAFDoc_Datum)                 datumAttr;
    Handle(XCAFDimTolObjects_DatumObject) datumObj;
    if (!occtDocumentDatumObjectAt(doc, datumIndex, datumAttr, datumObj))
      return false;

    NCollection_Sequence<XCAFDimTolObjects_DatumSingleModif> sequence;
    for (int32_t i = 0; i < count; ++i)
      sequence.Append((XCAFDimTolObjects_DatumSingleModif)modifiers[i]);
    datumObj->SetModifiers(sequence);
    datumAttr->SetObject(datumObj);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetDatumModifierWithValue(OCCTDocumentRef doc,
                                           int32_t         datumIndex,
                                           int32_t         modifier,
                                           double          value)
{
  if (modifier < 0 || modifier > (int32_t)XCAFDimTolObjects_DatumModifWithValue_Spherical)
    return false;
  try
  {
    Handle(XCAFDoc_Datum)                 datumAttr;
    Handle(XCAFDimTolObjects_DatumObject) datumObj;
    if (!occtDocumentDatumObjectAt(doc, datumIndex, datumAttr, datumObj))
      return false;

    // The value is cleared alongside the modifier, so a later _None never leaves a stale number
    // behind for a reader that stops gating on the modifier.
    const bool none = (modifier == (int32_t)XCAFDimTolObjects_DatumModifWithValue_None);
    datumObj->SetModifierWithValue((XCAFDimTolObjects_DatumModifWithValue)modifier,
                                   none ? 0.0 : value);
    datumAttr->SetObject(datumObj);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetDatumTarget(OCCTDocumentRef doc,
                                int32_t         datumIndex,
                                bool            isTarget,
                                int32_t         type,
                                int32_t         number)
{
  if (isTarget
      && (type < 0 || type > (int32_t)XCAFDimTolObjects_DatumTargetType_Area || number < 0))
    return false;
  try
  {
    Handle(XCAFDoc_Datum)                 datumAttr;
    Handle(XCAFDimTolObjects_DatumObject) datumObj;
    if (!occtDocumentDatumObjectAt(doc, datumIndex, datumAttr, datumObj))
      return false;

    datumObj->IsDatumTarget(isTarget);
    if (isTarget)
    {
      datumObj->SetDatumTargetType((XCAFDimTolObjects_DatumTargetType)type);
      datumObj->SetDatumTargetNumber((int)number);
    }
    datumAttr->SetObject(datumObj);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetDatumTargetPlacement(OCCTDocumentRef doc,
                                         int32_t         datumIndex,
                                         const double*   location,
                                         const double*   normal,
                                         const double*   reference,
                                         double          length,
                                         double          width)
{
  if (!location || !normal || !reference)
    return false;
  try
  {
    Handle(XCAFDoc_Datum)                 datumAttr;
    Handle(XCAFDimTolObjects_DatumObject) datumObj;
    if (!occtDocumentDatumObjectAt(doc, datumIndex, datumAttr, datumObj))
      return false;

    // #1038: XCAFDoc_Datum::SetObject nests the whole axis/length/width block inside
    // if (IsDatumTarget()), and inside that takes an Area branch that writes no axis at all. On a
    // datum that is not a target, or whose target type is Area, everything below is set on the
    // object and then dropped on the floor, so reporting success would describe a call that
    // persisted nothing. Refuse instead, and leave it to the caller to run
    // OCCTDocumentSetDatumTarget with a non-Area type first.
    if (!datumObj->IsDatumTarget()
        || datumObj->GetDatumTargetType() == XCAFDimTolObjects_DatumTargetType_Area)
      return false;

    // gp_Dir throws Standard_ConstructionError on a zero-length vector, which the surrounding
    // catch turns into false rather than letting it cross into Swift frames (#345).
    const gp_Ax2 axis(gp_Pnt(location[0], location[1], location[2]),
                      gp_Dir(normal[0], normal[1], normal[2]),
                      gp_Dir(reference[0], reference[1], reference[2]));
    datumObj->SetDatumTargetAxis(axis);
    datumObj->SetDatumTargetLength(length);
    datumObj->SetDatumTargetWidth(width);
    datumAttr->SetObject(datumObj);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetGraphNodeAttr(OCCTDocumentRef ref, int64_t labelId)
{
  if (!ref)
    return false;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(XCAFDoc_GraphNode) node = XCAFDoc_GraphNode::Set(label);
    return !node.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentGraphNodeSetChild(OCCTDocumentRef ref, int64_t parentLabelId, int64_t childLabelId)
{
  if (!ref)
    return false;
  try
  {
    auto*     doc         = (OCCTDocument*)ref;
    TDF_Label parentLabel = doc->getLabel(parentLabelId);
    TDF_Label childLabel  = doc->getLabel(childLabelId);
    if (parentLabel.IsNull() || childLabel.IsNull())
      return false;
    Handle(XCAFDoc_GraphNode) parentNode, childNode;
    if (!parentLabel.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), parentNode))
      return false;
    if (!childLabel.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), childNode))
      return false;
    parentNode->SetChild(childNode);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentGraphNodeSetFather(OCCTDocumentRef ref,
                                    int64_t         childLabelId,
                                    int64_t         parentLabelId)
{
  if (!ref)
    return false;
  try
  {
    auto*     doc         = (OCCTDocument*)ref;
    TDF_Label childLabel  = doc->getLabel(childLabelId);
    TDF_Label parentLabel = doc->getLabel(parentLabelId);
    if (childLabel.IsNull() || parentLabel.IsNull())
      return false;
    Handle(XCAFDoc_GraphNode) childNode, parentNode;
    if (!childLabel.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), childNode))
      return false;
    if (!parentLabel.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), parentNode))
      return false;
    childNode->SetFather(parentNode);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentGraphNodeUnSetChild(OCCTDocumentRef ref,
                                     int64_t         parentLabelId,
                                     int64_t         childLabelId)
{
  if (!ref)
    return false;
  try
  {
    auto*     doc         = (OCCTDocument*)ref;
    TDF_Label parentLabel = doc->getLabel(parentLabelId);
    TDF_Label childLabel  = doc->getLabel(childLabelId);
    if (parentLabel.IsNull() || childLabel.IsNull())
      return false;
    Handle(XCAFDoc_GraphNode) parentNode, childNode;
    if (!parentLabel.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), parentNode))
      return false;
    if (!childLabel.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), childNode))
      return false;
    parentNode->UnSetChild(childNode);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentGraphNodeUnSetFather(OCCTDocumentRef ref,
                                      int64_t         childLabelId,
                                      int64_t         parentLabelId)
{
  if (!ref)
    return false;
  try
  {
    auto*     doc         = (OCCTDocument*)ref;
    TDF_Label childLabel  = doc->getLabel(childLabelId);
    TDF_Label parentLabel = doc->getLabel(parentLabelId);
    if (childLabel.IsNull() || parentLabel.IsNull())
      return false;
    Handle(XCAFDoc_GraphNode) childNode, parentNode;
    if (!childLabel.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), childNode))
      return false;
    if (!parentLabel.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), parentNode))
      return false;
    childNode->UnSetFather(parentNode);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTDocumentGraphNodeNbChildren(OCCTDocumentRef ref, int64_t labelId)
{
  if (!ref)
    return 0;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return 0;
    Handle(XCAFDoc_GraphNode) node;
    if (!label.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), node))
      return 0;
    return node->NbChildren();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTDocumentGraphNodeNbFathers(OCCTDocumentRef ref, int64_t labelId)
{
  if (!ref)
    return 0;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return 0;
    Handle(XCAFDoc_GraphNode) node;
    if (!label.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), node))
      return 0;
    return node->NbFathers();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTDocumentGraphNodeIsFather(OCCTDocumentRef ref, int64_t labelId, int64_t otherLabelId)
{
  if (!ref)
    return false;
  try
  {
    auto*     doc        = (OCCTDocument*)ref;
    TDF_Label label      = doc->getLabel(labelId);
    TDF_Label otherLabel = doc->getLabel(otherLabelId);
    if (label.IsNull() || otherLabel.IsNull())
      return false;
    Handle(XCAFDoc_GraphNode) node, otherNode;
    if (!label.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), node))
      return false;
    if (!otherLabel.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), otherNode))
      return false;
    return node->IsFather(otherNode);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentGraphNodeIsChild(OCCTDocumentRef ref, int64_t labelId, int64_t otherLabelId)
{
  if (!ref)
    return false;
  try
  {
    auto*     doc        = (OCCTDocument*)ref;
    TDF_Label label      = doc->getLabel(labelId);
    TDF_Label otherLabel = doc->getLabel(otherLabelId);
    if (label.IsNull() || otherLabel.IsNull())
      return false;
    Handle(XCAFDoc_GraphNode) node, otherNode;
    if (!label.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), node))
      return false;
    if (!otherLabel.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), otherNode))
      return false;
    return node->IsChild(otherNode);
  }
  catch (...)
  {
    return false;
  }
}

int OCCTDocumentDimTolDimensionCount(OCCTDocumentRef document)
{
  if (!document || document->doc.IsNull())
    return 0;
  try
  {
    XCAFDimTolObjects_Tool                                          tool(document->doc);
    NCollection_Sequence<Handle(XCAFDimTolObjects_DimensionObject)> dims;
    tool.GetDimensions(dims);
    return static_cast<int>(dims.Size());
  }
  catch (...)
  {
    return 0;
  }
}

int OCCTDocumentDimTolToleranceCount(OCCTDocumentRef document)
{
  if (!document || document->doc.IsNull())
    return 0;
  try
  {
    // GetGeomTolerances calls GetObject on every datum linked to a tolerance, outside
    // occtDocumentDatumObjectAt and on the document tool's own table (#1030).
    if (!occtDocumentToolToleranceDatumsAreReadable(document->doc->Main()))
      return 0;
    XCAFDimTolObjects_Tool                                              tool(document->doc);
    NCollection_Sequence<Handle(XCAFDimTolObjects_GeomToleranceObject)> tols;
    NCollection_Sequence<Handle(XCAFDimTolObjects_DatumObject)>         datums;
    NCollection_DataMap<Handle(XCAFDimTolObjects_GeomToleranceObject),
                        Handle(XCAFDimTolObjects_DatumObject)>
      datumMap;
    tool.GetGeomTolerances(tols, datums, datumMap);
    return static_cast<int>(tols.Size());
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTDocumentSetDimTol(OCCTDocumentRef doc,
                           int64_t         labelId,
                           int32_t         kind,
                           const double*   values,
                           int32_t         valueCount,
                           const char*     name,
                           const char*     description)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;

    Handle(NCollection_HArray1<double>) vals;
    if (valueCount > 0)
    {
      vals = new NCollection_HArray1<double>(1, valueCount);
      for (int i = 0; i < valueCount; i++)
      {
        vals->SetValue(i + 1, values[i]);
      }
    }
    Handle(TCollection_HAsciiString) hName = new TCollection_HAsciiString(name);
    Handle(TCollection_HAsciiString) hDesc = new TCollection_HAsciiString(description);

    Handle(XCAFDoc_DimTol) dt = XCAFDoc_DimTol::Set(label, kind, vals, hName, hDesc);
    return !dt.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTDocumentGetDimTolKind(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  try
  {
    TDF_Label              label = doc->getLabel(labelId);
    Handle(XCAFDoc_DimTol) dt;
    if (!label.FindAttribute(XCAFDoc_DimTol::GetID(), dt))
      return -1;
    return dt->GetKind();
  }
  catch (...)
  {
    return -1;
  }
}

const char* OCCTDocumentGetDimTolName(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return nullptr;
  try
  {
    TDF_Label              label = doc->getLabel(labelId);
    Handle(XCAFDoc_DimTol) dt;
    if (!label.FindAttribute(XCAFDoc_DimTol::GetID(), dt))
      return nullptr;
    Handle(TCollection_HAsciiString) name = dt->GetName();
    if (name.IsNull())
      return nullptr;
    return strdup(name->ToCString());
  }
  catch (...)
  {
    return nullptr;
  }
}

const char* OCCTDocumentGetDimTolDescription(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return nullptr;
  try
  {
    TDF_Label              label = doc->getLabel(labelId);
    Handle(XCAFDoc_DimTol) dt;
    if (!label.FindAttribute(XCAFDoc_DimTol::GetID(), dt))
      return nullptr;
    Handle(TCollection_HAsciiString) desc = dt->GetDescription();
    if (desc.IsNull())
      return nullptr;
    return strdup(desc->ToCString());
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTDocumentGetDimTolValues(OCCTDocumentRef doc,
                                    int64_t         labelId,
                                    double*         outValues,
                                    int32_t         maxCount)
{
  if (!doc || doc->doc.IsNull() || !outValues)
    return 0;
  try
  {
    TDF_Label              label = doc->getLabel(labelId);
    Handle(XCAFDoc_DimTol) dt;
    if (!label.FindAttribute(XCAFDoc_DimTol::GetID(), dt))
      return 0;
    Handle(NCollection_HArray1<double>) vals = dt->GetVal();
    if (vals.IsNull())
      return 0;
    int count = std::min((int)vals->Length(), (int)maxCount);
    for (int i = 0; i < count; i++)
    {
      outValues[i] = vals->Value(i + 1);
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}
