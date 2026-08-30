//
//  OCCTBridge_Document_Attributes.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Document.mm (#1380): TDataStd_* (scalar/array/list attributes, TreeNode,
//  NamedData), TDataXtd_*
//  (Shape/Position/Geometry/Triangulation/Point/Axis/Plane/Placement/Presentation/Constraint/PatternStd).
//  No dedicated TDF bucket: TDF_Label-touching functions (properties/name, Reference, CopyLabel,
//  IDFilter, Delta, ComparisonTool, Transaction, AttributeIterator, DataSet) all co-reference a
//  stronger-voting package here and land in Attributes or DocumentLifecycle instead. Public C
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

const char* OCCTDocumentGetLabelName(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc)
    return nullptr;

  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return nullptr;

    Handle(TDataStd_Name) nameAttr;
    if (label.FindAttribute(TDataStd_Name::GetID(), nameAttr))
    {
      TCollection_ExtendedString name = nameAttr->Get();
      TCollection_AsciiString    asciiName(name);

      // Allocate and copy the string (caller must free with OCCTStringFree)
      char* result = new char[asciiName.Length() + 1];
      std::strcpy(result, asciiName.ToCString());
      return result;
    }

    return nullptr;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTDocumentSetLabelName(OCCTDocumentRef doc, int64_t labelId, const char* name)
{
  if (!doc || doc->doc.IsNull() || !name)
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    TDataStd_Name::Set(label, TCollection_ExtendedString(name, true));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetIntegerAttr(OCCTDocumentRef doc, int64_t labelId, int32_t value)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    TDataStd_Integer::Set(label, value);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentGetIntegerAttr(OCCTDocumentRef doc, int64_t labelId, int32_t* outValue)
{
  if (!doc || doc->doc.IsNull() || !outValue)
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TDataStd_Integer) attr;
    if (!label.FindAttribute(TDataStd_Integer::GetID(), attr))
      return false;
    *outValue = attr->Get();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetRealAttr(OCCTDocumentRef doc, int64_t labelId, double value)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    TDataStd_Real::Set(label, value);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentGetRealAttr(OCCTDocumentRef doc, int64_t labelId, double* outValue)
{
  if (!doc || doc->doc.IsNull() || !outValue)
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TDataStd_Real) attr;
    if (!label.FindAttribute(TDataStd_Real::GetID(), attr))
      return false;
    *outValue = attr->Get();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetAsciiStringAttr(OCCTDocumentRef doc, int64_t labelId, const char* value)
{
  if (!doc || doc->doc.IsNull() || !value)
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    TDataStd_AsciiString::Set(label, TCollection_AsciiString(value));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

const char* OCCTDocumentGetAsciiStringAttr(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return nullptr;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return nullptr;
    Handle(TDataStd_AsciiString) attr;
    if (!label.FindAttribute(TDataStd_AsciiString::GetID(), attr))
      return nullptr;
    return strdup(attr->Get().ToCString());
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTDocumentSetCommentAttr(OCCTDocumentRef doc, int64_t labelId, const char* value)
{
  if (!doc || doc->doc.IsNull() || !value)
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    TDataStd_Comment::Set(label, TCollection_ExtendedString(value, true));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

const char* OCCTDocumentGetCommentAttr(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return nullptr;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return nullptr;
    Handle(TDataStd_Comment) attr;
    if (!label.FindAttribute(TDataStd_Comment::GetID(), attr))
      return nullptr;
    TCollection_AsciiString ascii(attr->Get());
    return strdup(ascii.ToCString());
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTDocumentInitIntegerArray(OCCTDocumentRef doc,
                                  int64_t         labelId,
                                  int32_t         lower,
                                  int32_t         upper)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    TDataStd_IntegerArray::Set(label, lower, upper);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetIntegerArrayValue(OCCTDocumentRef doc,
                                      int64_t         labelId,
                                      int32_t         index,
                                      int32_t         value)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TDataStd_IntegerArray) attr;
    if (!label.FindAttribute(TDataStd_IntegerArray::GetID(), attr))
      return false;
    attr->SetValue(index, value);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentGetIntegerArrayValue(OCCTDocumentRef doc,
                                      int64_t         labelId,
                                      int32_t         index,
                                      int32_t*        outValue)
{
  if (!doc || doc->doc.IsNull() || !outValue)
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TDataStd_IntegerArray) attr;
    if (!label.FindAttribute(TDataStd_IntegerArray::GetID(), attr))
      return false;
    if (index < attr->Lower() || index > attr->Upper())
      return false;
    *outValue = attr->Value(index);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentGetIntegerArrayBounds(OCCTDocumentRef doc,
                                       int64_t         labelId,
                                       int32_t*        outLower,
                                       int32_t*        outUpper)
{
  if (!doc || doc->doc.IsNull() || !outLower || !outUpper)
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TDataStd_IntegerArray) attr;
    if (!label.FindAttribute(TDataStd_IntegerArray::GetID(), attr))
      return false;
    *outLower = attr->Lower();
    *outUpper = attr->Upper();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentInitRealArray(OCCTDocumentRef doc, int64_t labelId, int32_t lower, int32_t upper)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    TDataStd_RealArray::Set(label, lower, upper);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetRealArrayValue(OCCTDocumentRef doc,
                                   int64_t         labelId,
                                   int32_t         index,
                                   double          value)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TDataStd_RealArray) attr;
    if (!label.FindAttribute(TDataStd_RealArray::GetID(), attr))
      return false;
    attr->SetValue(index, value);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentGetRealArrayValue(OCCTDocumentRef doc,
                                   int64_t         labelId,
                                   int32_t         index,
                                   double*         outValue)
{
  if (!doc || doc->doc.IsNull() || !outValue)
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TDataStd_RealArray) attr;
    if (!label.FindAttribute(TDataStd_RealArray::GetID(), attr))
      return false;
    if (index < attr->Lower() || index > attr->Upper())
      return false;
    *outValue = attr->Value(index);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentGetRealArrayBounds(OCCTDocumentRef doc,
                                    int64_t         labelId,
                                    int32_t*        outLower,
                                    int32_t*        outUpper)
{
  if (!doc || doc->doc.IsNull() || !outLower || !outUpper)
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TDataStd_RealArray) attr;
    if (!label.FindAttribute(TDataStd_RealArray::GetID(), attr))
      return false;
    *outLower = attr->Lower();
    *outUpper = attr->Upper();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetTreeNode(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    TDataStd_TreeNode::Set(label);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentAppendTreeChild(OCCTDocumentRef doc, int64_t parentLabelId, int64_t childLabelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label parentLabel = doc->getLabel(parentLabelId);
    TDF_Label childLabel  = doc->getLabel(childLabelId);
    if (parentLabel.IsNull() || childLabel.IsNull())
      return false;
    Handle(TDataStd_TreeNode) parentNode, childNode;
    if (!parentLabel.FindAttribute(TDataStd_TreeNode::GetDefaultTreeID(), parentNode))
      return false;
    if (!childLabel.FindAttribute(TDataStd_TreeNode::GetDefaultTreeID(), childNode))
      return false;
    return parentNode->Append(childNode);
  }
  catch (...)
  {
    return false;
  }
}

int64_t OCCTDocumentTreeNodeFather(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return -1;
    Handle(TDataStd_TreeNode) node;
    if (!label.FindAttribute(TDataStd_TreeNode::GetDefaultTreeID(), node))
      return -1;
    if (!node->HasFather())
      return -1;
    return doc->registerLabel(node->Father()->Label());
  }
  catch (...)
  {
    return -1;
  }
}

int64_t OCCTDocumentTreeNodeFirst(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return -1;
    Handle(TDataStd_TreeNode) node;
    if (!label.FindAttribute(TDataStd_TreeNode::GetDefaultTreeID(), node))
      return -1;
    if (!node->HasFirst())
      return -1;
    return doc->registerLabel(node->First()->Label());
  }
  catch (...)
  {
    return -1;
  }
}

int64_t OCCTDocumentTreeNodeNext(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return -1;
    Handle(TDataStd_TreeNode) node;
    if (!label.FindAttribute(TDataStd_TreeNode::GetDefaultTreeID(), node))
      return -1;
    if (!node->HasNext())
      return -1;
    return doc->registerLabel(node->Next()->Label());
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDocumentTreeNodeHasFather(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TDataStd_TreeNode) node;
    if (!label.FindAttribute(TDataStd_TreeNode::GetDefaultTreeID(), node))
      return false;
    return node->HasFather();
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTDocumentTreeNodeDepth(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return -1;
    Handle(TDataStd_TreeNode) node;
    if (!label.FindAttribute(TDataStd_TreeNode::GetDefaultTreeID(), node))
      return -1;
    return node->Depth();
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTDocumentTreeNodeNbChildren(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return 0;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return 0;
    Handle(TDataStd_TreeNode) node;
    if (!label.FindAttribute(TDataStd_TreeNode::GetDefaultTreeID(), node))
      return 0;
    return node->NbChildren();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTDocumentSetShapeAttr(OCCTDocumentRef doc, int64_t labelId, OCCTShapeRef shape)
{
  if (!doc || doc->doc.IsNull() || !shape)
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    // TDataXtd_Shape::New requires an empty label, so use TNaming_Builder directly
    // to store the shape, which is what Set() does internally anyway
    Handle(TDataXtd_Shape) attr;
    if (!label.FindAttribute(TDataXtd_Shape::GetID(), attr))
    {
      attr = new TDataXtd_Shape();
      label.AddAttribute(attr);
    }
    TNaming_Builder builder(label);
    builder.Generated(shape->shape);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

OCCTShapeRef OCCTDocumentGetShapeAttr(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return nullptr;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return nullptr;
    Handle(TDataXtd_Shape) attr;
    if (!label.FindAttribute(TDataXtd_Shape::GetID(), attr))
      return nullptr;
    TopoDS_Shape shape = TDataXtd_Shape::Get(label);
    if (shape.IsNull())
      return nullptr;
    return new OCCTShape(shape);
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTDocumentHasShapeAttr(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TDataXtd_Shape) attr;
    return label.FindAttribute(TDataXtd_Shape::GetID(), attr);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetPositionAttr(OCCTDocumentRef doc, int64_t labelId, double x, double y, double z)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    TDataXtd_Position::Set(label, gp_Pnt(x, y, z));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentGetPositionAttr(OCCTDocumentRef doc,
                                 int64_t         labelId,
                                 double*         outX,
                                 double*         outY,
                                 double*         outZ)
{
  if (!doc || doc->doc.IsNull() || !outX || !outY || !outZ)
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    gp_Pnt pos;
    if (!TDataXtd_Position::Get(label, pos))
      return false;
    *outX = pos.X();
    *outY = pos.Y();
    *outZ = pos.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentHasPositionAttr(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    gp_Pnt pos;
    return TDataXtd_Position::Get(label, pos);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetGeometryAttr(OCCTDocumentRef doc, int64_t labelId, int32_t geometryType)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TDataXtd_Geometry) geom = TDataXtd_Geometry::Set(label);
    if (geom.IsNull())
      return false;
    geom->SetType(static_cast<TDataXtd_GeometryEnum>(geometryType));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTDocumentGetGeometryType(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return -1;
    Handle(TDataXtd_Geometry) geom;
    if (!label.FindAttribute(TDataXtd_Geometry::GetID(), geom))
      return -1;
    return static_cast<int32_t>(geom->GetType());
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDocumentHasGeometryAttr(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TDataXtd_Geometry) geom;
    return label.FindAttribute(TDataXtd_Geometry::GetID(), geom);
  }
  catch (...)
  {
    return false;
  }
}

// Stores the WHOLE shape's mesh, not the first face's (#443). The attribute is what later
// readers trust as "this label's geometry", and a 6-face box used to arrive as 4 nodes.
bool OCCTDocumentSetTriangulationFromShape(OCCTDocumentRef doc,
                                           int64_t         labelId,
                                           OCCTShapeRef    shape,
                                           double          deflection)
{
  if (!doc || doc->doc.IsNull() || !shape)
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;

    Handle(Poly_Triangulation) tri = occtMergedTriangulation(shape->shape, deflection);
    if (tri.IsNull())
      return false;

    Handle(TDataXtd_Triangulation) attr = TDataXtd_Triangulation::Set(label, tri);
    return !attr.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTDocumentTriangulationNbNodes(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return 0;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return 0;
    Handle(TDataXtd_Triangulation) attr;
    if (!label.FindAttribute(TDataXtd_Triangulation::GetID(), attr))
      return 0;
    return attr->NbNodes();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTDocumentTriangulationNbTriangles(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return 0;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return 0;
    Handle(TDataXtd_Triangulation) attr;
    if (!label.FindAttribute(TDataXtd_Triangulation::GetID(), attr))
      return 0;
    return attr->NbTriangles();
  }
  catch (...)
  {
    return 0;
  }
}

// Reading a stored node back was not possible before #443: the attribute exposed only its
// counts and deflection, so nothing in the Swift API could see the coordinates it holds. That
// is part of why the first-face bug, and the frame it stored in, went unnoticed.
bool OCCTDocumentTriangulationNode(OCCTDocumentRef doc,
                                   int64_t         labelId,
                                   int32_t         index,
                                   double*         outXYZ)
{
  if (!doc || doc->doc.IsNull() || !outXYZ)
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TDataXtd_Triangulation) attr;
    if (!label.FindAttribute(TDataXtd_Triangulation::GetID(), attr))
      return false;
    Handle(Poly_Triangulation) tri = attr->Get();
    if (tri.IsNull() || index < 1 || index > tri->NbNodes())
      return false;
    const gp_Pnt p = tri->Node(index);
    outXYZ[0]      = p.X();
    outXYZ[1]      = p.Y();
    outXYZ[2]      = p.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// HasNormals() first: Poly_Triangulation::Normal reads myNormals unconditionally, and that
// array is empty for anything BRepMesh produced.
bool OCCTDocumentTriangulationNormal(OCCTDocumentRef doc,
                                     int64_t         labelId,
                                     int32_t         index,
                                     double*         outXYZ)
{
  if (!doc || doc->doc.IsNull() || !outXYZ)
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TDataXtd_Triangulation) attr;
    if (!label.FindAttribute(TDataXtd_Triangulation::GetID(), attr))
      return false;
    Handle(Poly_Triangulation) tri = attr->Get();
    if (tri.IsNull() || !tri->HasNormals() || index < 1 || index > tri->NbNodes())
      return false;
    const gp_Dir n = tri->Normal(index);
    outXYZ[0]      = n.X();
    outXYZ[1]      = n.Y();
    outXYZ[2]      = n.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

double OCCTDocumentTriangulationDeflection(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return 0.0;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return 0.0;
    Handle(TDataXtd_Triangulation) attr;
    if (!label.FindAttribute(TDataXtd_Triangulation::GetID(), attr))
      return 0.0;
    return attr->Deflection();
  }
  catch (...)
  {
    return 0.0;
  }
}

bool OCCTDocumentSetPointAttr(OCCTDocumentRef doc, int64_t labelId, double x, double y, double z)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TDataXtd_Point) attr = TDataXtd_Point::Set(label, gp_Pnt(x, y, z));
    return !attr.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetAxisAttr(OCCTDocumentRef doc,
                             int64_t         labelId,
                             double          ox,
                             double          oy,
                             double          oz,
                             double          dx,
                             double          dy,
                             double          dz)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    gp_Lin                line(gp_Pnt(ox, oy, oz), gp_Dir(dx, dy, dz));
    Handle(TDataXtd_Axis) attr = TDataXtd_Axis::Set(label, line);
    return !attr.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetPlaneAttr(OCCTDocumentRef doc,
                              int64_t         labelId,
                              double          ox,
                              double          oy,
                              double          oz,
                              double          nx,
                              double          ny,
                              double          nz)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    gp_Pln                 plane(gp_Pnt(ox, oy, oz), gp_Dir(nx, ny, nz));
    Handle(TDataXtd_Plane) attr = TDataXtd_Plane::Set(label, plane);
    return !attr.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentDirectoryNew(OCCTDocumentRef document, int labelTag)
{
  try
  {
    TDF_Label                  label = getLabelForTag(document, labelTag);
    Handle(TDataStd_Directory) dir   = TDataStd_Directory::New(label);
    return !dir.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentDirectoryFind(OCCTDocumentRef document, int labelTag)
{
  try
  {
    TDF_Label                  label = getLabelForTag(document, labelTag);
    Handle(TDataStd_Directory) dir;
    return TDataStd_Directory::Find(label, dir);
  }
  catch (...)
  {
    return false;
  }
}

int OCCTDocumentDirectoryAddSubDirectory(OCCTDocumentRef document, int parentLabelTag)
{
  try
  {
    TDF_Label                  parentLabel = getLabelForTag(document, parentLabelTag);
    Handle(TDataStd_Directory) dir;
    if (!TDataStd_Directory::Find(parentLabel, dir))
      return -1;
    Handle(TDataStd_Directory) subDir = TDataStd_Directory::AddDirectory(dir);
    if (subDir.IsNull())
      return -1;
    return subDir->Label().Tag();
  }
  catch (...)
  {
    return -1;
  }
}

int OCCTDocumentDirectoryMakeObjectLabel(OCCTDocumentRef document, int parentLabelTag)
{
  try
  {
    TDF_Label                  parentLabel = getLabelForTag(document, parentLabelTag);
    Handle(TDataStd_Directory) dir;
    if (!TDataStd_Directory::Find(parentLabel, dir))
      return -1;
    TDF_Label objLabel = TDataStd_Directory::MakeObjectLabel(dir);
    if (objLabel.IsNull())
      return -1;
    return objLabel.Tag();
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDocumentVariableSet(OCCTDocumentRef document, int labelTag)
{
  try
  {
    TDF_Label                 label = getLabelForTag(document, labelTag);
    Handle(TDataStd_Variable) var   = TDataStd_Variable::Set(label);
    return !var.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentVariableSetName(OCCTDocumentRef document, int labelTag, const char* name)
{
  try
  {
    TDF_Label                 label = getLabelForTag(document, labelTag);
    Handle(TDataStd_Variable) var;
    if (!label.FindAttribute(TDataStd_Variable::GetID(), var))
      return false;
    var->Name(TCollection_ExtendedString(name));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

const char* OCCTDocumentVariableGetName(OCCTDocumentRef document, int labelTag)
{
  try
  {
    TDF_Label                 label = getLabelForTag(document, labelTag);
    Handle(TDataStd_Variable) var;
    if (!label.FindAttribute(TDataStd_Variable::GetID(), var))
      return nullptr;
    TCollection_AsciiString aStr(var->Name());
    char*                   result = (char*)malloc(aStr.Length() + 1);
    strcpy(result, aStr.ToCString());
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTDocumentVariableSetValue(OCCTDocumentRef document, int labelTag, double value)
{
  try
  {
    TDF_Label                 label = getLabelForTag(document, labelTag);
    Handle(TDataStd_Variable) var;
    if (!label.FindAttribute(TDataStd_Variable::GetID(), var))
      return false;
    var->Set(value);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

double OCCTDocumentVariableGetValue(OCCTDocumentRef document, int labelTag)
{
  try
  {
    TDF_Label                 label = getLabelForTag(document, labelTag);
    Handle(TDataStd_Variable) var;
    if (!label.FindAttribute(TDataStd_Variable::GetID(), var))
      return 0.0;
    if (!var->IsValued())
      return 0.0;
    return var->Get();
  }
  catch (...)
  {
    return 0.0;
  }
}

bool OCCTDocumentVariableIsValued(OCCTDocumentRef document, int labelTag)
{
  try
  {
    TDF_Label                 label = getLabelForTag(document, labelTag);
    Handle(TDataStd_Variable) var;
    if (!label.FindAttribute(TDataStd_Variable::GetID(), var))
      return false;
    return var->IsValued();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentVariableSetUnit(OCCTDocumentRef document, int labelTag, const char* unit)
{
  try
  {
    TDF_Label                 label = getLabelForTag(document, labelTag);
    Handle(TDataStd_Variable) var;
    if (!label.FindAttribute(TDataStd_Variable::GetID(), var))
      return false;
    var->Unit(TCollection_AsciiString(unit));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

const char* OCCTDocumentVariableGetUnit(OCCTDocumentRef document, int labelTag)
{
  try
  {
    TDF_Label                 label = getLabelForTag(document, labelTag);
    Handle(TDataStd_Variable) var;
    if (!label.FindAttribute(TDataStd_Variable::GetID(), var))
      return nullptr;
    TCollection_AsciiString unit   = var->Unit();
    char*                   result = (char*)malloc(unit.Length() + 1);
    strcpy(result, unit.ToCString());
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTDocumentVariableSetConstant(OCCTDocumentRef document, int labelTag, bool isConstant)
{
  try
  {
    TDF_Label                 label = getLabelForTag(document, labelTag);
    Handle(TDataStd_Variable) var;
    if (!label.FindAttribute(TDataStd_Variable::GetID(), var))
      return false;
    var->Constant(isConstant);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentVariableIsConstant(OCCTDocumentRef document, int labelTag)
{
  try
  {
    TDF_Label                 label = getLabelForTag(document, labelTag);
    Handle(TDataStd_Variable) var;
    if (!label.FindAttribute(TDataStd_Variable::GetID(), var))
      return false;
    return var->IsConstant();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentExpressionSet(OCCTDocumentRef document, int labelTag)
{
  try
  {
    TDF_Label                   label = getLabelForTag(document, labelTag);
    Handle(TDataStd_Expression) expr  = TDataStd_Expression::Set(label);
    return !expr.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentExpressionSetString(OCCTDocumentRef document, int labelTag, const char* expression)
{
  try
  {
    TDF_Label                   label = getLabelForTag(document, labelTag);
    Handle(TDataStd_Expression) expr;
    if (!label.FindAttribute(TDataStd_Expression::GetID(), expr))
      return false;
    expr->SetExpression(TCollection_ExtendedString(expression));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

const char* OCCTDocumentExpressionGetString(OCCTDocumentRef document, int labelTag)
{
  try
  {
    TDF_Label                   label = getLabelForTag(document, labelTag);
    Handle(TDataStd_Expression) expr;
    if (!label.FindAttribute(TDataStd_Expression::GetID(), expr))
      return nullptr;
    TCollection_AsciiString aStr(expr->GetExpression());
    char*                   result = (char*)malloc(aStr.Length() + 1);
    strcpy(result, aStr.ToCString());
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

const char* OCCTDocumentExpressionGetName(OCCTDocumentRef document, int labelTag)
{
  try
  {
    TDF_Label                   label = getLabelForTag(document, labelTag);
    Handle(TDataStd_Expression) expr;
    if (!label.FindAttribute(TDataStd_Expression::GetID(), expr))
      return nullptr;
    TCollection_AsciiString aStr(expr->Name());
    char*                   result = (char*)malloc(aStr.Length() + 1);
    strcpy(result, aStr.ToCString());
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTDocumentVariableAssignExpression(OCCTDocumentRef document, int labelTag)
{
  try
  {
    TDF_Label                 label = getLabelForTag(document, labelTag);
    Handle(TDataStd_Variable) var;
    if (!label.FindAttribute(TDataStd_Variable::GetID(), var))
      return false;
    Handle(TDataStd_Expression) expr = var->Assign();
    return !expr.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentVariableDesassignExpression(OCCTDocumentRef document, int labelTag)
{
  try
  {
    TDF_Label                 label = getLabelForTag(document, labelTag);
    Handle(TDataStd_Variable) var;
    if (!label.FindAttribute(TDataStd_Variable::GetID(), var))
      return false;
    var->Desassign();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentVariableIsAssigned(OCCTDocumentRef document, int labelTag)
{
  try
  {
    TDF_Label                 label = getLabelForTag(document, labelTag);
    Handle(TDataStd_Variable) var;
    if (!label.FindAttribute(TDataStd_Variable::GetID(), var))
      return false;
    return var->IsAssigned();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetBooleanArray(OCCTDocumentRef document,
                                 int             tag,
                                 int             lower,
                                 int             upper,
                                 const bool*     values,
                                 int             count)
{
  try
  {
    TDF_Label label = getLabelForTag(document, tag);
    auto      arr   = TDataStd_BooleanArray::Set(label, lower, upper);
    int       len   = upper - lower + 1;
    for (int i = 0; i < len && i < count; i++)
    {
      arr->SetValue(lower + i, values[i]);
    }
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int OCCTDocumentGetBooleanArray(OCCTDocumentRef document, int tag, bool* values, int maxCount)
{
  try
  {
    TDF_Label                     label = getLabelForTag(document, tag);
    Handle(TDataStd_BooleanArray) arr;
    if (!label.FindAttribute(TDataStd_BooleanArray::GetID(), arr))
      return -1;
    int len = arr->Length();
    if (values)
    {
      int n = std::min(len, maxCount);
      for (int i = 0; i < n; i++)
      {
        values[i] = arr->Value(arr->Lower() + i);
      }
    }
    return len;
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDocumentHasBooleanArray(OCCTDocumentRef document, int tag)
{
  try
  {
    TDF_Label                     label = getLabelForTag(document, tag);
    Handle(TDataStd_BooleanArray) arr;
    return label.FindAttribute(TDataStd_BooleanArray::GetID(), arr);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetBooleanList(OCCTDocumentRef document, int tag, const bool* values, int count)
{
  try
  {
    TDF_Label label = getLabelForTag(document, tag);
    auto      lst   = TDataStd_BooleanList::Set(label);
    lst->Clear();
    for (int i = 0; i < count; i++)
    {
      lst->Append(values[i]);
    }
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int OCCTDocumentGetBooleanList(OCCTDocumentRef document, int tag, bool* values, int maxCount)
{
  try
  {
    TDF_Label                    label = getLabelForTag(document, tag);
    Handle(TDataStd_BooleanList) lst;
    if (!label.FindAttribute(TDataStd_BooleanList::GetID(), lst))
      return -1;
    int count = lst->Extent();
    if (values)
    {
      int i = 0;
      for (auto it = lst->List().cbegin(); it != lst->List().cend() && i < maxCount; ++it, ++i)
      {
        values[i] = (*it != 0);
      }
    }
    return count;
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDocumentBooleanListAppend(OCCTDocumentRef document, int tag, bool value)
{
  try
  {
    TDF_Label                    label = getLabelForTag(document, tag);
    Handle(TDataStd_BooleanList) lst;
    if (!label.FindAttribute(TDataStd_BooleanList::GetID(), lst))
    {
      lst = TDataStd_BooleanList::Set(label);
    }
    lst->Append(value);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentBooleanListClear(OCCTDocumentRef document, int tag)
{
  try
  {
    TDF_Label                    label = getLabelForTag(document, tag);
    Handle(TDataStd_BooleanList) lst;
    if (!label.FindAttribute(TDataStd_BooleanList::GetID(), lst))
      return false;
    lst->Clear();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentHasBooleanList(OCCTDocumentRef document, int tag)
{
  try
  {
    TDF_Label                    label = getLabelForTag(document, tag);
    Handle(TDataStd_BooleanList) lst;
    return label.FindAttribute(TDataStd_BooleanList::GetID(), lst);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetByteArray(OCCTDocumentRef document,
                              int             tag,
                              int             lower,
                              int             upper,
                              const uint8_t*  values,
                              int             count)
{
  try
  {
    TDF_Label label = getLabelForTag(document, tag);
    auto      arr   = TDataStd_ByteArray::Set(label, lower, upper);
    int       len   = upper - lower + 1;
    for (int i = 0; i < len && i < count; i++)
    {
      arr->SetValue(lower + i, values[i]);
    }
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int OCCTDocumentGetByteArray(OCCTDocumentRef document, int tag, uint8_t* values, int maxCount)
{
  try
  {
    TDF_Label                  label = getLabelForTag(document, tag);
    Handle(TDataStd_ByteArray) arr;
    if (!label.FindAttribute(TDataStd_ByteArray::GetID(), arr))
      return -1;
    int len = arr->Length();
    if (values)
    {
      int n = std::min(len, maxCount);
      for (int i = 0; i < n; i++)
      {
        values[i] = arr->Value(arr->Lower() + i);
      }
    }
    return len;
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDocumentHasByteArray(OCCTDocumentRef document, int tag)
{
  try
  {
    TDF_Label                  label = getLabelForTag(document, tag);
    Handle(TDataStd_ByteArray) arr;
    return label.FindAttribute(TDataStd_ByteArray::GetID(), arr);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetIntegerList(OCCTDocumentRef document, int tag, const int* values, int count)
{
  try
  {
    TDF_Label label = getLabelForTag(document, tag);
    auto      lst   = TDataStd_IntegerList::Set(label);
    lst->Clear();
    for (int i = 0; i < count; i++)
    {
      lst->Append(values[i]);
    }
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int OCCTDocumentGetIntegerList(OCCTDocumentRef document, int tag, int* values, int maxCount)
{
  try
  {
    TDF_Label                    label = getLabelForTag(document, tag);
    Handle(TDataStd_IntegerList) lst;
    if (!label.FindAttribute(TDataStd_IntegerList::GetID(), lst))
      return -1;
    int count = lst->Extent();
    if (values)
    {
      int i = 0;
      for (auto it = lst->List().cbegin(); it != lst->List().cend() && i < maxCount; ++it, ++i)
      {
        values[i] = *it;
      }
    }
    return count;
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDocumentIntegerListAppend(OCCTDocumentRef document, int tag, int value)
{
  try
  {
    TDF_Label                    label = getLabelForTag(document, tag);
    Handle(TDataStd_IntegerList) lst;
    if (!label.FindAttribute(TDataStd_IntegerList::GetID(), lst))
    {
      lst = TDataStd_IntegerList::Set(label);
    }
    lst->Append(value);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentIntegerListClear(OCCTDocumentRef document, int tag)
{
  try
  {
    TDF_Label                    label = getLabelForTag(document, tag);
    Handle(TDataStd_IntegerList) lst;
    if (!label.FindAttribute(TDataStd_IntegerList::GetID(), lst))
      return false;
    lst->Clear();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentHasIntegerList(OCCTDocumentRef document, int tag)
{
  try
  {
    TDF_Label                    label = getLabelForTag(document, tag);
    Handle(TDataStd_IntegerList) lst;
    return label.FindAttribute(TDataStd_IntegerList::GetID(), lst);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetRealList(OCCTDocumentRef document, int tag, const double* values, int count)
{
  try
  {
    TDF_Label label = getLabelForTag(document, tag);
    auto      lst   = TDataStd_RealList::Set(label);
    lst->Clear();
    for (int i = 0; i < count; i++)
    {
      lst->Append(values[i]);
    }
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int OCCTDocumentGetRealList(OCCTDocumentRef document, int tag, double* values, int maxCount)
{
  try
  {
    TDF_Label                 label = getLabelForTag(document, tag);
    Handle(TDataStd_RealList) lst;
    if (!label.FindAttribute(TDataStd_RealList::GetID(), lst))
      return -1;
    int count = lst->Extent();
    if (values)
    {
      int i = 0;
      for (auto it = lst->List().cbegin(); it != lst->List().cend() && i < maxCount; ++it, ++i)
      {
        values[i] = *it;
      }
    }
    return count;
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDocumentRealListAppend(OCCTDocumentRef document, int tag, double value)
{
  try
  {
    TDF_Label                 label = getLabelForTag(document, tag);
    Handle(TDataStd_RealList) lst;
    if (!label.FindAttribute(TDataStd_RealList::GetID(), lst))
    {
      lst = TDataStd_RealList::Set(label);
    }
    lst->Append(value);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentRealListClear(OCCTDocumentRef document, int tag)
{
  try
  {
    TDF_Label                 label = getLabelForTag(document, tag);
    Handle(TDataStd_RealList) lst;
    if (!label.FindAttribute(TDataStd_RealList::GetID(), lst))
      return false;
    lst->Clear();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentHasRealList(OCCTDocumentRef document, int tag)
{
  try
  {
    TDF_Label                 label = getLabelForTag(document, tag);
    Handle(TDataStd_RealList) lst;
    return label.FindAttribute(TDataStd_RealList::GetID(), lst);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetExtStringArray(OCCTDocumentRef    document,
                                   int                tag,
                                   int                lower,
                                   int                upper,
                                   const char* const* values,
                                   int                count)
{
  try
  {
    TDF_Label label = getLabelForTag(document, tag);
    auto      arr   = TDataStd_ExtStringArray::Set(label, lower, upper);
    int       len   = upper - lower + 1;
    for (int i = 0; i < len && i < count; i++)
    {
      arr->SetValue(lower + i, TCollection_ExtendedString(values[i], true));
    }
    return true;
  }
  catch (...)
  {
    return false;
  }
}

char* OCCTDocumentGetExtStringArrayValue(OCCTDocumentRef document, int tag, int index)
{
  try
  {
    TDF_Label                       label = getLabelForTag(document, tag);
    Handle(TDataStd_ExtStringArray) arr;
    if (!label.FindAttribute(TDataStd_ExtStringArray::GetID(), arr))
      return nullptr;
    if (index < arr->Lower() || index > arr->Upper())
      return nullptr;
    TCollection_ExtendedString val = arr->Value(index);
    TCollection_AsciiString    ascii(val);
    return strdup(ascii.ToCString());
  }
  catch (...)
  {
    return nullptr;
  }
}

int OCCTDocumentGetExtStringArrayLength(OCCTDocumentRef document, int tag)
{
  try
  {
    TDF_Label                       label = getLabelForTag(document, tag);
    Handle(TDataStd_ExtStringArray) arr;
    if (!label.FindAttribute(TDataStd_ExtStringArray::GetID(), arr))
      return -1;
    return arr->Length();
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDocumentHasExtStringArray(OCCTDocumentRef document, int tag)
{
  try
  {
    TDF_Label                       label = getLabelForTag(document, tag);
    Handle(TDataStd_ExtStringArray) arr;
    return label.FindAttribute(TDataStd_ExtStringArray::GetID(), arr);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetExtStringList(OCCTDocumentRef    document,
                                  int                tag,
                                  const char* const* values,
                                  int                count)
{
  try
  {
    TDF_Label label = getLabelForTag(document, tag);
    auto      lst   = TDataStd_ExtStringList::Set(label);
    lst->Clear();
    for (int i = 0; i < count; i++)
    {
      lst->Append(TCollection_ExtendedString(values[i], true));
    }
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int OCCTDocumentGetExtStringListCount(OCCTDocumentRef document, int tag)
{
  try
  {
    TDF_Label                      label = getLabelForTag(document, tag);
    Handle(TDataStd_ExtStringList) lst;
    if (!label.FindAttribute(TDataStd_ExtStringList::GetID(), lst))
      return -1;
    return lst->Extent();
  }
  catch (...)
  {
    return -1;
  }
}

char* OCCTDocumentGetExtStringListValue(OCCTDocumentRef document, int tag, int index)
{
  try
  {
    TDF_Label                      label = getLabelForTag(document, tag);
    Handle(TDataStd_ExtStringList) lst;
    if (!label.FindAttribute(TDataStd_ExtStringList::GetID(), lst))
      return nullptr;
    int i = 0;
    for (auto it = lst->List().cbegin(); it != lst->List().cend(); ++it, ++i)
    {
      if (i == index)
      {
        TCollection_AsciiString ascii(*it);
        return strdup(ascii.ToCString());
      }
    }
    return nullptr;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTDocumentExtStringListAppend(OCCTDocumentRef document, int tag, const char* value)
{
  try
  {
    TDF_Label                      label = getLabelForTag(document, tag);
    Handle(TDataStd_ExtStringList) lst;
    if (!label.FindAttribute(TDataStd_ExtStringList::GetID(), lst))
    {
      lst = TDataStd_ExtStringList::Set(label);
    }
    lst->Append(TCollection_ExtendedString(value, true));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentExtStringListClear(OCCTDocumentRef document, int tag)
{
  try
  {
    TDF_Label                      label = getLabelForTag(document, tag);
    Handle(TDataStd_ExtStringList) lst;
    if (!label.FindAttribute(TDataStd_ExtStringList::GetID(), lst))
      return false;
    lst->Clear();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentHasExtStringList(OCCTDocumentRef document, int tag)
{
  try
  {
    TDF_Label                      label = getLabelForTag(document, tag);
    Handle(TDataStd_ExtStringList) lst;
    return label.FindAttribute(TDataStd_ExtStringList::GetID(), lst);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetReferenceArray(OCCTDocumentRef document,
                                   int             tag,
                                   int             lower,
                                   int             upper,
                                   const int*      refTags,
                                   int             count)
{
  try
  {
    TDF_Label label = getLabelForTag(document, tag);
    TDF_Label main  = document->doc->Main();
    auto      arr   = TDataStd_ReferenceArray::Set(label, lower, upper);
    int       len   = upper - lower + 1;
    for (int i = 0; i < len && i < count; i++)
    {
      arr->SetValue(lower + i, main.FindChild(refTags[i]));
    }
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int OCCTDocumentGetReferenceArray(OCCTDocumentRef document, int tag, int* refTags, int maxCount)
{
  try
  {
    TDF_Label                       label = getLabelForTag(document, tag);
    Handle(TDataStd_ReferenceArray) arr;
    if (!label.FindAttribute(TDataStd_ReferenceArray::GetID(), arr))
      return -1;
    int len = arr->Length();
    if (refTags)
    {
      int n = std::min(len, maxCount);
      for (int i = 0; i < n; i++)
      {
        refTags[i] = arr->Value(arr->Lower() + i).Tag();
      }
    }
    return len;
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDocumentHasReferenceArray(OCCTDocumentRef document, int tag)
{
  try
  {
    TDF_Label                       label = getLabelForTag(document, tag);
    Handle(TDataStd_ReferenceArray) arr;
    return label.FindAttribute(TDataStd_ReferenceArray::GetID(), arr);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetReferenceList(OCCTDocumentRef document, int tag, const int* refTags, int count)
{
  try
  {
    TDF_Label label = getLabelForTag(document, tag);
    TDF_Label main  = document->doc->Main();
    auto      lst   = TDataStd_ReferenceList::Set(label);
    lst->Clear();
    for (int i = 0; i < count; i++)
    {
      lst->Append(main.FindChild(refTags[i]));
    }
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int OCCTDocumentGetReferenceList(OCCTDocumentRef document, int tag, int* refTags, int maxCount)
{
  try
  {
    TDF_Label                      label = getLabelForTag(document, tag);
    Handle(TDataStd_ReferenceList) lst;
    if (!label.FindAttribute(TDataStd_ReferenceList::GetID(), lst))
      return -1;
    int count = lst->Extent();
    if (refTags)
    {
      int i = 0;
      for (auto it = lst->List().cbegin(); it != lst->List().cend() && i < maxCount; ++it, ++i)
      {
        refTags[i] = (*it).Tag();
      }
    }
    return count;
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDocumentReferenceListAppend(OCCTDocumentRef document, int tag, int refTag)
{
  try
  {
    TDF_Label                      label = getLabelForTag(document, tag);
    TDF_Label                      main  = document->doc->Main();
    Handle(TDataStd_ReferenceList) lst;
    if (!label.FindAttribute(TDataStd_ReferenceList::GetID(), lst))
    {
      lst = TDataStd_ReferenceList::Set(label);
    }
    lst->Append(main.FindChild(refTag));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentReferenceListClear(OCCTDocumentRef document, int tag)
{
  try
  {
    TDF_Label                      label = getLabelForTag(document, tag);
    Handle(TDataStd_ReferenceList) lst;
    if (!label.FindAttribute(TDataStd_ReferenceList::GetID(), lst))
      return false;
    lst->Clear();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentHasReferenceList(OCCTDocumentRef document, int tag)
{
  try
  {
    TDF_Label                      label = getLabelForTag(document, tag);
    Handle(TDataStd_ReferenceList) lst;
    return label.FindAttribute(TDataStd_ReferenceList::GetID(), lst);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetRelation(OCCTDocumentRef document, int tag, const char* relation)
{
  try
  {
    TDF_Label label = getLabelForTag(document, tag);
    auto      rel   = TDataStd_Relation::Set(label);
    rel->SetRelation(TCollection_ExtendedString(relation, true));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

char* OCCTDocumentGetRelation(OCCTDocumentRef document, int tag)
{
  try
  {
    TDF_Label                 label = getLabelForTag(document, tag);
    Handle(TDataStd_Relation) rel;
    if (!label.FindAttribute(TDataStd_Relation::GetID(), rel))
      return nullptr;
    TCollection_AsciiString ascii(rel->GetRelation());
    return strdup(ascii.ToCString());
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTDocumentHasRelation(OCCTDocumentRef document, int tag)
{
  try
  {
    TDF_Label                 label = getLabelForTag(document, tag);
    Handle(TDataStd_Relation) rel;
    return label.FindAttribute(TDataStd_Relation::GetID(), rel);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetTick(OCCTDocumentRef document, int tag)
{
  try
  {
    TDF_Label label = getLabelForTag(document, tag);
    TDataStd_Tick::Set(label);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentHasTick(OCCTDocumentRef document, int tag)
{
  try
  {
    TDF_Label             label = getLabelForTag(document, tag);
    Handle(TDataStd_Tick) tick;
    return label.FindAttribute(TDataStd_Tick::GetID(), tick);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentRemoveTick(OCCTDocumentRef document, int tag)
{
  try
  {
    TDF_Label             label = getLabelForTag(document, tag);
    Handle(TDataStd_Tick) tick;
    if (!label.FindAttribute(TDataStd_Tick::GetID(), tick))
      return false;
    label.ForgetAttribute(TDataStd_Tick::GetID());
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetCurrentLabel(OCCTDocumentRef document, int tag)
{
  try
  {
    TDF_Label label = getLabelForTag(document, tag);
    TDataStd_Current::Set(label);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int OCCTDocumentGetCurrentLabel(OCCTDocumentRef document)
{
  try
  {
    TDF_Label root = document->doc->Main();
    if (!TDataStd_Current::Has(root))
      return -1;
    TDF_Label current = TDataStd_Current::Get(root);
    return current.Tag();
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDocumentHasCurrentLabel(OCCTDocumentRef document)
{
  try
  {
    TDF_Label root = document->doc->Main();
    return TDataStd_Current::Has(root);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTIntPackedMapSet(OCCTDocumentRef doc, int tag, bool isDelta)
{
  try
  {
    TDF_Label                     label = getLabelForTag(doc, tag);
    Handle(TDataStd_IntPackedMap) attr  = TDataStd_IntPackedMap::Set(label, isDelta);
    return !attr.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTIntPackedMapAdd(OCCTDocumentRef doc, int tag, int value)
{
  try
  {
    TDF_Label                     label = getLabelForTag(doc, tag);
    Handle(TDataStd_IntPackedMap) attr;
    if (!label.FindAttribute(TDataStd_IntPackedMap::GetID(), attr))
      return false;
    return attr->Add(value);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTIntPackedMapRemove(OCCTDocumentRef doc, int tag, int value)
{
  try
  {
    TDF_Label                     label = getLabelForTag(doc, tag);
    Handle(TDataStd_IntPackedMap) attr;
    if (!label.FindAttribute(TDataStd_IntPackedMap::GetID(), attr))
      return false;
    return attr->Remove(value);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTIntPackedMapContains(OCCTDocumentRef doc, int tag, int value)
{
  try
  {
    TDF_Label                     label = getLabelForTag(doc, tag);
    Handle(TDataStd_IntPackedMap) attr;
    if (!label.FindAttribute(TDataStd_IntPackedMap::GetID(), attr))
      return false;
    return attr->Contains(value);
  }
  catch (...)
  {
    return false;
  }
}

int OCCTIntPackedMapExtent(OCCTDocumentRef doc, int tag)
{
  try
  {
    TDF_Label                     label = getLabelForTag(doc, tag);
    Handle(TDataStd_IntPackedMap) attr;
    if (!label.FindAttribute(TDataStd_IntPackedMap::GetID(), attr))
      return 0;
    return attr->Extent();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTIntPackedMapClear(OCCTDocumentRef doc, int tag)
{
  try
  {
    TDF_Label                     label = getLabelForTag(doc, tag);
    Handle(TDataStd_IntPackedMap) attr;
    if (!label.FindAttribute(TDataStd_IntPackedMap::GetID(), attr))
      return false;
    return attr->Clear();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTIntPackedMapIsEmpty(OCCTDocumentRef doc, int tag)
{
  try
  {
    TDF_Label                     label = getLabelForTag(doc, tag);
    Handle(TDataStd_IntPackedMap) attr;
    if (!label.FindAttribute(TDataStd_IntPackedMap::GetID(), attr))
      return true;
    return attr->IsEmpty();
  }
  catch (...)
  {
    return true;
  }
}

int OCCTIntPackedMapGetValues(OCCTDocumentRef doc, int tag, int** values)
{
  try
  {
    TDF_Label                     label = getLabelForTag(doc, tag);
    Handle(TDataStd_IntPackedMap) attr;
    if (!label.FindAttribute(TDataStd_IntPackedMap::GetID(), attr))
    {
      *values = nullptr;
      return 0;
    }
    const TColStd_PackedMapOfInteger& map   = attr->GetMap();
    int                               count = map.Extent();
    if (count == 0)
    {
      *values = nullptr;
      return 0;
    }

    *values = (int*)malloc(count * sizeof(int));
    int i   = 0;
    for (TColStd_PackedMapOfInteger::Iterator it(map); it.More(); it.Next())
    {
      (*values)[i] = it.Key();
      i++;
    }
    return count;
  }
  catch (...)
  {
    *values = nullptr;
    return 0;
  }
}

bool OCCTIntPackedMapChangeValues(OCCTDocumentRef doc, int tag, const int* values, int count)
{
  try
  {
    TDF_Label                     label = getLabelForTag(doc, tag);
    Handle(TDataStd_IntPackedMap) attr;
    if (!label.FindAttribute(TDataStd_IntPackedMap::GetID(), attr))
      return false;
    TColStd_PackedMapOfInteger newMap;
    for (int i = 0; i < count; i++)
    {
      newMap.Add(values[i]);
    }
    return attr->ChangeMap(newMap);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTNoteBookNew(OCCTDocumentRef doc, int tag)
{
  try
  {
    TDF_Label                 label = getLabelForTag(doc, tag);
    Handle(TDataStd_NoteBook) nb    = TDataStd_NoteBook::New(label);
    return !nb.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

int OCCTNoteBookAppendReal(OCCTDocumentRef doc, int tag, double value)
{
  try
  {
    TDF_Label                 label = getLabelForTag(doc, tag);
    Handle(TDataStd_NoteBook) nb;
    if (!label.FindAttribute(TDataStd_NoteBook::GetID(), nb))
      return -1;
    Handle(TDataStd_Real) attr = nb->Append(value);
    if (attr.IsNull())
      return -1;
    return attr->Label().Tag();
  }
  catch (...)
  {
    return -1;
  }
}

int OCCTNoteBookAppendInteger(OCCTDocumentRef doc, int tag, int value)
{
  try
  {
    TDF_Label                 label = getLabelForTag(doc, tag);
    Handle(TDataStd_NoteBook) nb;
    if (!label.FindAttribute(TDataStd_NoteBook::GetID(), nb))
      return -1;
    Handle(TDataStd_Integer) attr = nb->Append(value);
    if (attr.IsNull())
      return -1;
    return attr->Label().Tag();
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTNoteBookFind(OCCTDocumentRef doc, int tag)
{
  try
  {
    TDF_Label                 label = getLabelForTag(doc, tag);
    Handle(TDataStd_NoteBook) nb;
    return TDataStd_NoteBook::Find(label, nb);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTUAttributeSet(OCCTDocumentRef doc, int tag, const char* guidString)
{
  try
  {
    TDF_Label                   label = getLabelForTag(doc, tag);
    Standard_GUID               guid(guidString);
    Handle(TDataStd_UAttribute) attr = TDataStd_UAttribute::Set(label, guid);
    return !attr.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTUAttributeHas(OCCTDocumentRef doc, int tag, const char* guidString)
{
  try
  {
    TDF_Label                   label = getLabelForTag(doc, tag);
    Standard_GUID               guid(guidString);
    Handle(TDataStd_UAttribute) attr;
    return label.FindAttribute(guid, attr);
  }
  catch (...)
  {
    return false;
  }
}

const char* OCCTUAttributeGetID(OCCTDocumentRef doc, int tag, const char* guidString)
{
  try
  {
    TDF_Label                   label = getLabelForTag(doc, tag);
    Standard_GUID               guid(guidString);
    Handle(TDataStd_UAttribute) attr;
    if (!label.FindAttribute(guid, attr))
      return nullptr;

    const Standard_GUID& id = attr->ID();
    Standard_SStream     ss;
    id.ShallowDump(ss);
    std::string str = ss.str();
    return strdup(str.c_str());
  }
  catch (...)
  {
    return nullptr;
  }
}

int OCCTChildNodeIteratorCount(OCCTDocumentRef doc, int tag, bool allLevels)
{
  try
  {
    TDF_Label                 label = getLabelForTag(doc, tag);
    Handle(TDataStd_TreeNode) node;
    if (!label.FindAttribute(TDataStd_TreeNode::GetDefaultTreeID(), node))
      return 0;

    int count = 0;
    for (TDataStd_ChildNodeIterator it(node, allLevels); it.More(); it.Next())
      count++;
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTDocumentSetPlacement(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TDataXtd_Placement) p = TDataXtd_Placement::Set(label);
    return !p.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentHasPlacement(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TDataXtd_Placement) p;
    return label.FindAttribute(TDataXtd_Placement::GetID(), p);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetPresentation(OCCTDocumentRef doc, int64_t labelId, const char* driverGUID)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Standard_GUID                 guid(driverGUID);
    Handle(TDataXtd_Presentation) pres = TDataXtd_Presentation::Set(label, guid);
    return !pres.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

void OCCTDocumentUnsetPresentation(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (!label.IsNull())
      TDataXtd_Presentation::Unset(label);
  }
  catch (...)
  {
  }
}

bool OCCTDocumentHasPresentation(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TDataXtd_Presentation) pres;
    return label.FindAttribute(TDataXtd_Presentation::GetID(), pres);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentPresentationSetDisplayed(OCCTDocumentRef doc, int64_t labelId, bool displayed)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label                     label = doc->getLabel(labelId);
    Handle(TDataXtd_Presentation) pres;
    if (!label.FindAttribute(TDataXtd_Presentation::GetID(), pres))
      return false;
    pres->SetDisplayed(displayed);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentPresentationIsDisplayed(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label                     label = doc->getLabel(labelId);
    Handle(TDataXtd_Presentation) pres;
    if (!label.FindAttribute(TDataXtd_Presentation::GetID(), pres))
      return false;
    return pres->IsDisplayed();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentPresentationSetColor(OCCTDocumentRef doc, int64_t labelId, int32_t colorIndex)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label                     label = doc->getLabel(labelId);
    Handle(TDataXtd_Presentation) pres;
    if (!label.FindAttribute(TDataXtd_Presentation::GetID(), pres))
      return false;
    pres->SetColor((Quantity_NameOfColor)colorIndex);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTDocumentPresentationGetColor(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  try
  {
    TDF_Label                     label = doc->getLabel(labelId);
    Handle(TDataXtd_Presentation) pres;
    if (!label.FindAttribute(TDataXtd_Presentation::GetID(), pres))
      return -1;
    if (!pres->HasOwnColor())
      return -1;
    return (int32_t)pres->Color();
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDocumentPresentationSetTransparency(OCCTDocumentRef doc, int64_t labelId, double value)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label                     label = doc->getLabel(labelId);
    Handle(TDataXtd_Presentation) pres;
    if (!label.FindAttribute(TDataXtd_Presentation::GetID(), pres))
      return false;
    pres->SetTransparency(value);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

double OCCTDocumentPresentationGetTransparency(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return -1.0;
  try
  {
    TDF_Label                     label = doc->getLabel(labelId);
    Handle(TDataXtd_Presentation) pres;
    if (!label.FindAttribute(TDataXtd_Presentation::GetID(), pres))
      return -1.0;
    if (!pres->HasOwnTransparency())
      return -1.0;
    return pres->Transparency();
  }
  catch (...)
  {
    return -1.0;
  }
}

bool OCCTDocumentPresentationSetWidth(OCCTDocumentRef doc, int64_t labelId, double width)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label                     label = doc->getLabel(labelId);
    Handle(TDataXtd_Presentation) pres;
    if (!label.FindAttribute(TDataXtd_Presentation::GetID(), pres))
      return false;
    pres->SetWidth(width);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

double OCCTDocumentPresentationGetWidth(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return -1.0;
  try
  {
    TDF_Label                     label = doc->getLabel(labelId);
    Handle(TDataXtd_Presentation) pres;
    if (!label.FindAttribute(TDataXtd_Presentation::GetID(), pres))
      return -1.0;
    if (!pres->HasOwnWidth())
      return -1.0;
    return pres->Width();
  }
  catch (...)
  {
    return -1.0;
  }
}

bool OCCTDocumentPresentationSetMode(OCCTDocumentRef doc, int64_t labelId, int32_t mode)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label                     label = doc->getLabel(labelId);
    Handle(TDataXtd_Presentation) pres;
    if (!label.FindAttribute(TDataXtd_Presentation::GetID(), pres))
      return false;
    pres->SetMode(mode);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTDocumentPresentationGetMode(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  try
  {
    TDF_Label                     label = doc->getLabel(labelId);
    Handle(TDataXtd_Presentation) pres;
    if (!label.FindAttribute(TDataXtd_Presentation::GetID(), pres))
      return -1;
    if (!pres->HasOwnMode())
      return -1;
    return pres->Mode();
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTDocumentSetConstraint(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TDataXtd_Constraint) cst = TDataXtd_Constraint::Set(label);
    return !cst.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentConstraintSetType(OCCTDocumentRef doc, int64_t labelId, int32_t type)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label                   label = doc->getLabel(labelId);
    Handle(TDataXtd_Constraint) cst;
    if (!label.FindAttribute(TDataXtd_Constraint::GetID(), cst))
      return false;
    cst->SetType((TDataXtd_ConstraintEnum)type);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTDocumentConstraintGetType(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  try
  {
    TDF_Label                   label = doc->getLabel(labelId);
    Handle(TDataXtd_Constraint) cst;
    if (!label.FindAttribute(TDataXtd_Constraint::GetID(), cst))
      return -1;
    return (int32_t)cst->GetType();
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTDocumentConstraintNbGeometries(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return 0;
  try
  {
    TDF_Label                   label = doc->getLabel(labelId);
    Handle(TDataXtd_Constraint) cst;
    if (!label.FindAttribute(TDataXtd_Constraint::GetID(), cst))
      return 0;
    return cst->NbGeometries();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTDocumentConstraintIsPlanar(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label                   label = doc->getLabel(labelId);
    Handle(TDataXtd_Constraint) cst;
    if (!label.FindAttribute(TDataXtd_Constraint::GetID(), cst))
      return false;
    return cst->IsPlanar();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentConstraintIsDimension(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label                   label = doc->getLabel(labelId);
    Handle(TDataXtd_Constraint) cst;
    if (!label.FindAttribute(TDataXtd_Constraint::GetID(), cst))
      return false;
    return cst->IsDimension();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentConstraintSetVerified(OCCTDocumentRef doc, int64_t labelId, bool verified)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label                   label = doc->getLabel(labelId);
    Handle(TDataXtd_Constraint) cst;
    if (!label.FindAttribute(TDataXtd_Constraint::GetID(), cst))
      return false;
    cst->Verified(verified);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentConstraintGetVerified(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label                   label = doc->getLabel(labelId);
    Handle(TDataXtd_Constraint) cst;
    if (!label.FindAttribute(TDataXtd_Constraint::GetID(), cst))
      return false;
    return cst->Verified();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentConstraintClearGeometries(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label                   label = doc->getLabel(labelId);
    Handle(TDataXtd_Constraint) cst;
    if (!label.FindAttribute(TDataXtd_Constraint::GetID(), cst))
      return false;
    cst->ClearGeometries();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentSetPatternStd(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TDataXtd_PatternStd) pat = TDataXtd_PatternStd::Set(label);
    return !pat.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDocumentPatternSetSignature(OCCTDocumentRef doc, int64_t labelId, int32_t signature)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label                   label = doc->getLabel(labelId);
    Handle(TDataXtd_PatternStd) pat;
    if (!label.FindAttribute(TDataXtd_Pattern::GetID(), pat))
      return false;
    pat->Signature(signature);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTDocumentPatternGetSignature(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  try
  {
    TDF_Label                   label = doc->getLabel(labelId);
    Handle(TDataXtd_PatternStd) pat;
    if (!label.FindAttribute(TDataXtd_Pattern::GetID(), pat))
      return -1;
    return pat->Signature();
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTDocumentPatternNbTrsfs(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return 0;
  try
  {
    TDF_Label                   label = doc->getLabel(labelId);
    Handle(TDataXtd_PatternStd) pat;
    if (!label.FindAttribute(TDataXtd_Pattern::GetID(), pat))
      return 0;
    return pat->NbTrsfs();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTDocumentHasPattern(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label                   label = doc->getLabel(labelId);
    Handle(TDataXtd_PatternStd) pat;
    return label.FindAttribute(TDataXtd_Pattern::GetID(), pat);
  }
  catch (...)
  {
    return false;
  }
}
