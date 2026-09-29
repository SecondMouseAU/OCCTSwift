//
//  OCCTBridge_Document_Functions.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Document.mm (#1380): TFunction_* (Logbook, GraphNode, Function, IFunction,
//  Scope, DriverTable), TNaming_* (topological naming history, CopyShape, Extensions, Scope,
//  Translator, Naming, SameShapeIterator). Public C surface unchanged; every sibling file imports
//  the same headers this one does (the shared preamble below). No symbol changes, pure file move --
//  see Scripts/repro/396-bridge-mm-split/ for how.
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
template <typename AttrType, typename ObjType, typename ToolGetter, typename LabelsGetter>

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
    occtRecordCaughtException(__func__);
    return 0;
  }
}

// Helper: common iteration logic for format enumeration (reading/writing)
// FormatsFn is a pointer-to-member-function of TDocStd_Application taking
// NCollection_Sequence<TCollection_AsciiString>&
template <typename FormatsFn>

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

// #964: the walk's upper bound. Reaching it means the count is a floor, not a measurement,
// which `outTruncated` reports so a caller can tell the two apart.
static const int kAssemblyItemCountLimit = 100000;

bool OCCTDocumentNamingRecord(OCCTDocumentRef     doc,
                              int64_t             labelId,
                              OCCTNamingEvolution evolution,
                              OCCTShapeRef        oldShape,
                              OCCTShapeRef        newShape)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;

    TNaming_Builder builder(label);
    switch (evolution)
    {
      case OCCTNamingPrimitive:
        if (!newShape)
          return false;
        builder.Generated(newShape->shape);
        break;
      case OCCTNamingGenerated:
        if (!oldShape || !newShape)
          return false;
        builder.Generated(oldShape->shape, newShape->shape);
        break;
      case OCCTNamingModify:
        if (!oldShape || !newShape)
          return false;
        builder.Modify(oldShape->shape, newShape->shape);
        break;
      case OCCTNamingDelete:
        if (!oldShape)
          return false;
        builder.Delete(oldShape->shape);
        break;
      case OCCTNamingSelected:
        if (!oldShape || !newShape)
          return false;
        builder.Select(newShape->shape, oldShape->shape);
        break;
      default:
        return false;
    }
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

OCCTShapeRef OCCTDocumentNamingGetCurrentShape(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return nullptr;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return nullptr;

    Handle(TNaming_NamedShape) ns;
    if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns))
      return nullptr;
    if (ns.IsNull() || ns->IsEmpty())
      return nullptr;

    TopoDS_Shape current = TNaming_Tool::CurrentShape(ns);
    if (current.IsNull())
      return nullptr;

    return new OCCTShape(current);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

OCCTShapeRef OCCTDocumentNamingGetShape(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return nullptr;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return nullptr;

    Handle(TNaming_NamedShape) ns;
    if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns))
      return nullptr;
    if (ns.IsNull() || ns->IsEmpty())
      return nullptr;

    TopoDS_Shape shape = TNaming_Tool::GetShape(ns);
    if (shape.IsNull())
      return nullptr;

    return new OCCTShape(shape);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

int32_t OCCTDocumentNamingHistoryCount(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return 0;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return 0;

    Handle(TNaming_NamedShape) ns;
    if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns))
      return 0;

    int32_t count = 0;
    for (TNaming_Iterator it(ns); it.More(); it.Next())
    {
      count++;
    }
    return count;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

bool OCCTDocumentNamingGetHistoryEntry(OCCTDocumentRef         doc,
                                       int64_t                 labelId,
                                       int32_t                 index,
                                       OCCTNamingHistoryEntry* outEntry)
{
  if (!doc || !outEntry || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;

    Handle(TNaming_NamedShape) ns;
    if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns))
      return false;

    int32_t i = 0;
    for (TNaming_Iterator it(ns); it.More(); it.Next(), i++)
    {
      if (i == index)
      {
        TNaming_Evolution evo    = it.Evolution();
        outEntry->hasOldShape    = !it.OldShape().IsNull();
        outEntry->hasNewShape    = !it.NewShape().IsNull();
        outEntry->isModification = it.IsModification();
        switch (evo)
        {
          case TNaming_PRIMITIVE:
            outEntry->evolution = OCCTNamingPrimitive;
            break;
          case TNaming_GENERATED:
            outEntry->evolution = OCCTNamingGenerated;
            break;
          case TNaming_MODIFY:
            outEntry->evolution = OCCTNamingModify;
            break;
          case TNaming_DELETE:
            outEntry->evolution = OCCTNamingDelete;
            break;
          case TNaming_SELECTED:
            outEntry->evolution = OCCTNamingSelected;
            break;
          default:
            outEntry->evolution = OCCTNamingPrimitive;
            break;
        }
        return true;
      }
    }
    return false;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

OCCTShapeRef OCCTDocumentNamingGetOldShape(OCCTDocumentRef doc, int64_t labelId, int32_t index)
{
  if (!doc || doc->doc.IsNull())
    return nullptr;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return nullptr;

    Handle(TNaming_NamedShape) ns;
    if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns))
      return nullptr;

    int32_t i = 0;
    for (TNaming_Iterator it(ns); it.More(); it.Next(), i++)
    {
      if (i == index)
      {
        TopoDS_Shape old = it.OldShape();
        if (old.IsNull())
          return nullptr;
        return new OCCTShape(old);
      }
    }
    return nullptr;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

OCCTShapeRef OCCTDocumentNamingGetNewShape(OCCTDocumentRef doc, int64_t labelId, int32_t index)
{
  if (!doc || doc->doc.IsNull())
    return nullptr;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return nullptr;

    Handle(TNaming_NamedShape) ns;
    if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns))
      return nullptr;

    int32_t i = 0;
    for (TNaming_Iterator it(ns); it.More(); it.Next(), i++)
    {
      if (i == index)
      {
        TopoDS_Shape nw = it.NewShape();
        if (nw.IsNull())
          return nullptr;
        return new OCCTShape(nw);
      }
    }
    return nullptr;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

int32_t OCCTDocumentNamingTraceForward(OCCTDocumentRef doc,
                                       int64_t         accessLabelId,
                                       OCCTShapeRef    shape,
                                       OCCTShapeRef*   outShapes,
                                       int32_t         maxCount)
{
  return occtDocumentNamingTraceImpl<TNaming_NewShapeIterator>(doc,
                                                               accessLabelId,
                                                               shape,
                                                               outShapes,
                                                               maxCount);
}

int32_t OCCTDocumentNamingTraceBackward(OCCTDocumentRef doc,
                                        int64_t         accessLabelId,
                                        OCCTShapeRef    shape,
                                        OCCTShapeRef*   outShapes,
                                        int32_t         maxCount)
{
  return occtDocumentNamingTraceImpl<TNaming_OldShapeIterator>(doc,
                                                               accessLabelId,
                                                               shape,
                                                               outShapes,
                                                               maxCount);
}

bool OCCTDocumentNamingSelect(OCCTDocumentRef doc,
                              int64_t         labelId,
                              OCCTShapeRef    selection,
                              OCCTShapeRef    context)
{
  if (!doc || !selection || !context || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;

    TNaming_Selector selector(label);
    return selector.Select(selection->shape, context->shape);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

OCCTShapeRef OCCTDocumentNamingResolve(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return nullptr;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return nullptr;

    TNaming_Selector selector(label);
    TDF_LabelMap     valid;
    if (!selector.Solve(valid))
      return nullptr;

    Handle(TNaming_NamedShape) ns = selector.NamedShape();
    if (ns.IsNull() || ns->IsEmpty())
      return nullptr;

    TopoDS_Shape shape = TNaming_Tool::CurrentShape(ns);
    if (shape.IsNull())
      return nullptr;

    return new OCCTShape(shape);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

int32_t OCCTDocumentNamingGetEvolution(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return -1;

    Handle(TNaming_NamedShape) ns;
    if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns))
      return -1;

    switch (ns->Evolution())
    {
      case TNaming_PRIMITIVE:
        return OCCTNamingPrimitive;
      case TNaming_GENERATED:
        return OCCTNamingGenerated;
      case TNaming_MODIFY:
        return OCCTNamingModify;
      case TNaming_DELETE:
        return OCCTNamingDelete;
      case TNaming_SELECTED:
        return OCCTNamingSelected;
      default:
        return -1;
    }
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return -1;
  }
}

bool OCCTDocumentSetLogbook(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TFunction_Logbook) logbook = TFunction_Logbook::Set(label);
    return !logbook.IsNull();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentLogbookSetTouched(OCCTDocumentRef doc,
                                   int64_t         logbookLabelId,
                                   int64_t         targetLabelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label logLabel = doc->getLabel(logbookLabelId);
    if (logLabel.IsNull())
      return false;
    // TFunction_Logbook::Set places logbook on root, so find it there
    Handle(TFunction_Logbook) logbook;
    if (!logLabel.Root().FindAttribute(TFunction_Logbook::GetID(), logbook))
      return false;
    TDF_Label target = doc->getLabel(targetLabelId);
    if (target.IsNull())
      return false;
    logbook->SetTouched(target);
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentLogbookSetImpacted(OCCTDocumentRef doc,
                                    int64_t         logbookLabelId,
                                    int64_t         targetLabelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label logLabel = doc->getLabel(logbookLabelId);
    if (logLabel.IsNull())
      return false;
    Handle(TFunction_Logbook) logbook;
    if (!logLabel.Root().FindAttribute(TFunction_Logbook::GetID(), logbook))
      return false;
    TDF_Label target = doc->getLabel(targetLabelId);
    if (target.IsNull())
      return false;
    logbook->SetImpacted(target);
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentLogbookIsModified(OCCTDocumentRef doc,
                                   int64_t         logbookLabelId,
                                   int64_t         targetLabelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label logLabel = doc->getLabel(logbookLabelId);
    if (logLabel.IsNull())
      return false;
    Handle(TFunction_Logbook) logbook;
    if (!logLabel.Root().FindAttribute(TFunction_Logbook::GetID(), logbook))
      return false;
    TDF_Label target = doc->getLabel(targetLabelId);
    if (target.IsNull())
      return false;
    return logbook->IsModified(target);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentLogbookClear(OCCTDocumentRef doc, int64_t logbookLabelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label logLabel = doc->getLabel(logbookLabelId);
    if (logLabel.IsNull())
      return false;
    Handle(TFunction_Logbook) logbook;
    if (!logLabel.Root().FindAttribute(TFunction_Logbook::GetID(), logbook))
      return false;
    logbook->Clear();
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentLogbookIsEmpty(OCCTDocumentRef doc, int64_t logbookLabelId)
{
  if (!doc || doc->doc.IsNull())
    return true;
  try
  {
    TDF_Label logLabel = doc->getLabel(logbookLabelId);
    if (logLabel.IsNull())
      return true;
    Handle(TFunction_Logbook) logbook;
    if (!logLabel.Root().FindAttribute(TFunction_Logbook::GetID(), logbook))
      return true;
    return logbook->IsEmpty();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return true;
  }
}

bool OCCTDocumentSetGraphNode(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TFunction_GraphNode) node = TFunction_GraphNode::Set(label);
    return !node.IsNull();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentGraphNodeAddPrevious(OCCTDocumentRef doc, int64_t labelId, int32_t prevTag)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TFunction_GraphNode) node;
    if (!label.FindAttribute(TFunction_GraphNode::GetID(), node))
      return false;
    return node->AddPrevious(prevTag);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentGraphNodeAddNext(OCCTDocumentRef doc, int64_t labelId, int32_t nextTag)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TFunction_GraphNode) node;
    if (!label.FindAttribute(TFunction_GraphNode::GetID(), node))
      return false;
    return node->AddNext(nextTag);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentGraphNodeSetStatus(OCCTDocumentRef doc, int64_t labelId, int32_t status)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TFunction_GraphNode) node;
    if (!label.FindAttribute(TFunction_GraphNode::GetID(), node))
      return false;
    node->SetStatus(static_cast<TFunction_ExecutionStatus>(status));
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

int32_t OCCTDocumentGraphNodeGetStatus(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return -1;
    Handle(TFunction_GraphNode) node;
    if (!label.FindAttribute(TFunction_GraphNode::GetID(), node))
      return -1;
    return static_cast<int32_t>(node->GetStatus());
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return -1;
  }
}

bool OCCTDocumentGraphNodeRemoveAllPrevious(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TFunction_GraphNode) node;
    if (!label.FindAttribute(TFunction_GraphNode::GetID(), node))
      return false;
    node->RemoveAllPrevious();
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentGraphNodeRemoveAllNext(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TFunction_GraphNode) node;
    if (!label.FindAttribute(TFunction_GraphNode::GetID(), node))
      return false;
    node->RemoveAllNext();
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentSetFunctionAttr(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TFunction_Function) func = TFunction_Function::Set(label);
    return !func.IsNull();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentFunctionIsFailed(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TFunction_Function) func;
    if (!label.FindAttribute(TFunction_Function::GetID(), func))
      return false;
    return func->Failed();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

int32_t OCCTDocumentFunctionGetFailure(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return -1;
    Handle(TFunction_Function) func;
    if (!label.FindAttribute(TFunction_Function::GetID(), func))
      return -1;
    return func->GetFailure();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return -1;
  }
}

bool OCCTDocumentFunctionSetFailure(OCCTDocumentRef doc, int64_t labelId, int32_t mode)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TFunction_Function) func;
    if (!label.FindAttribute(TFunction_Function::GetID(), func))
      return false;
    func->SetFailure(mode);
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

OCCTShapeRef OCCTShapeDeepCopy(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    if (shape->shape.IsNull())
      return nullptr;
    TColStd_IndexedDataMapOfTransientTransient aMap;
    TopoDS_Shape                               copy;
    TNaming_CopyShape::CopyTool(shape->shape, aMap, copy);
    if (copy.IsNull())
      return nullptr;
    return new OCCTShape(copy);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

bool OCCTNamingIsEmpty(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return true;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return true;
    Handle(TNaming_NamedShape) ns;
    if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns))
      return true;
    return ns->IsEmpty();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return true;
  }
}

int OCCTNamingGetVersion(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return 0;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return 0;
    Handle(TNaming_NamedShape) ns;
    if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns))
      return 0;
    return ns->Version();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

bool OCCTNamingSetVersion(OCCTDocumentRef doc, int64_t labelId, int version)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TNaming_NamedShape) ns;
    if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns))
      return false;
    ns->SetVersion(version);
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

OCCTShapeRef OCCTNamingOriginalShape(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return nullptr;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return nullptr;
    Handle(TNaming_NamedShape) ns;
    if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns))
      return nullptr;
    TopoDS_Shape shape = TNaming_Tool::OriginalShape(ns);
    if (shape.IsNull())
      return nullptr;
    auto* ref  = new OCCTShape();
    ref->shape = shape;
    return ref;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

bool OCCTNamingHasLabel(OCCTDocumentRef doc, OCCTShapeRef shape)
{
  if (!doc || doc->doc.IsNull() || !shape)
    return false;
  try
  {
    TDF_Label root = doc->doc->Main();
    return TNaming_Tool::HasLabel(root, shape->shape);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

int64_t OCCTNamingFindLabel(OCCTDocumentRef doc, OCCTShapeRef shape)
{
  if (!doc || doc->doc.IsNull() || !shape)
    return -1;
  try
  {
    TDF_Label root     = doc->doc->Main();
    int       transDef = 0;
    TDF_Label label    = TNaming_Tool::Label(root, shape->shape, transDef);
    if (label.IsNull())
      return -1;
    // Find the label in the document's label array
    for (int64_t i = 0; i < (int64_t)doc->labels.size(); i++)
    {
      if (doc->labels[i].IsEqual(label))
        return i;
    }
    // Label exists but not in our array, register it
    return doc->registerLabel(label);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return -1;
  }
}

int OCCTNamingValidUntil(OCCTDocumentRef doc, OCCTShapeRef shape)
{
  if (!doc || doc->doc.IsNull() || !shape)
    return -1;
  try
  {
    TDF_Label root = doc->doc->Main();
    return TNaming_Tool::ValidUntil(root, shape->shape);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return -1;
  }
}

int32_t OCCTNamingSameShapeCount(OCCTDocumentRef doc, OCCTShapeRef shape)
{
  if (!doc || doc->doc.IsNull() || !shape)
    return 0;
  try
  {
    TDF_Label root  = doc->doc->Main();
    int       count = 0;
    for (TNaming_SameShapeIterator it(shape->shape, root); it.More(); it.Next())
      count++;
    return count;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

int32_t OCCTNamingSameShapeLabels(OCCTDocumentRef doc,
                                  OCCTShapeRef    shape,
                                  int64_t*        outLabelIds,
                                  int32_t         maxCount)
{
  if (!doc || doc->doc.IsNull() || !shape || !outLabelIds || maxCount <= 0)
    return 0;
  try
  {
    TDF_Label root = doc->doc->Main();
    int32_t   i    = 0;
    for (TNaming_SameShapeIterator it(shape->shape, root); it.More() && i < maxCount; it.Next())
    {
      TDF_Label label = it.Label();
      // Find or register the label
      int64_t labelId = -1;
      for (int64_t j = 0; j < (int64_t)doc->labels.size(); j++)
      {
        if (doc->labels[j].IsEqual(label))
        {
          labelId = j;
          break;
        }
      }
      if (labelId < 0)
        labelId = doc->registerLabel(label);
      outLabelIds[i] = labelId;
      i++;
    }
    return i;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

bool OCCTDocumentNewFunction(OCCTDocumentRef doc, int64_t labelId, const char* guidString)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;

    TDF_Label root = doc->doc->GetData()->Root();
    TFunction_Scope::Set(root);

    Standard_GUID guid(guidString);
    TFunction_IFunction::NewFunction(label, guid);
    Handle(TFunction_Function) func;
    return label.FindAttribute(TFunction_Function::GetID(), func);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentDeleteFunction(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    return TFunction_IFunction::DeleteFunction(label);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

int32_t OCCTDocumentFunctionGetExecStatus(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return -1;

    Handle(TFunction_Function) func;
    if (!label.FindAttribute(TFunction_Function::GetID(), func))
      return -1;

    TFunction_IFunction ifunc(label);
    return (int32_t)ifunc.GetStatus();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return -1;
  }
}

bool OCCTDocumentFunctionSetExecStatus(OCCTDocumentRef doc, int64_t labelId, int32_t status)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;

    Handle(TFunction_Function) func;
    if (!label.FindAttribute(TFunction_Function::GetID(), func))
      return false;

    TFunction_IFunction ifunc(label);
    ifunc.SetStatus((TFunction_ExecutionStatus)status);
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentSetFunctionScope(OCCTDocumentRef doc)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label               root  = doc->doc->GetData()->Root();
    Handle(TFunction_Scope) scope = TFunction_Scope::Set(root);
    return !scope.IsNull();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentFunctionScopeAdd(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label               root = doc->doc->GetData()->Root();
    Handle(TFunction_Scope) scope;
    if (!root.FindAttribute(TFunction_Scope::GetID(), scope))
      return false;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    return scope->AddFunction(label);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentFunctionScopeRemove(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label               root = doc->doc->GetData()->Root();
    Handle(TFunction_Scope) scope;
    if (!root.FindAttribute(TFunction_Scope::GetID(), scope))
      return false;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    return scope->RemoveFunction(label);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentFunctionScopeHas(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label               root = doc->doc->GetData()->Root();
    Handle(TFunction_Scope) scope;
    if (!root.FindAttribute(TFunction_Scope::GetID(), scope))
      return false;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    return scope->HasFunction(label);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentFunctionScopeRemoveAll(OCCTDocumentRef doc)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label               root = doc->doc->GetData()->Root();
    Handle(TFunction_Scope) scope;
    if (!root.FindAttribute(TFunction_Scope::GetID(), scope))
      return false;
    scope->RemoveAllFunctions();
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

int32_t OCCTDocumentFunctionScopeCount(OCCTDocumentRef doc)
{
  if (!doc || doc->doc.IsNull())
    return 0;
  try
  {
    TDF_Label               root = doc->doc->GetData()->Root();
    Handle(TFunction_Scope) scope;
    if (!root.FindAttribute(TFunction_Scope::GetID(), scope))
      return 0;
    return scope->GetFunctions().Extent();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

int32_t OCCTDocumentFunctionScopeGetFreeID(OCCTDocumentRef doc)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  try
  {
    TDF_Label               root = doc->doc->GetData()->Root();
    Handle(TFunction_Scope) scope;
    if (!root.FindAttribute(TFunction_Scope::GetID(), scope))
      return -1;
    return scope->GetFreeID();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return -1;
  }
}

bool OCCTFunctionDriverTableHasDriver(const char* guidString)
{
  try
  {
    Handle(TFunction_DriverTable) table = TFunction_DriverTable::Get();
    if (table.IsNull())
      return false;
    Standard_GUID guid(guidString);
    return table->HasDriver(guid);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

void OCCTFunctionDriverTableClear()
{
  try
  {
    Handle(TFunction_DriverTable) table = TFunction_DriverTable::Get();
    if (!table.IsNull())
      table->Clear();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

OCCTShapeRef OCCTShapeTranslatorCopy(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    TNaming_Translator translator;
    translator.Add(shape->shape);
    translator.Perform();
    if (!translator.IsDone())
      return nullptr;
    TopoDS_Shape copy = translator.Copied(shape->shape);
    if (copy.IsNull())
      return nullptr;
    OCCTShape* result = new OCCTShape();
    result->shape     = copy;
    return result;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

bool OCCTDocumentInsertNaming(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TNaming_Naming) naming = TNaming_Naming::Insert(label);
    return !naming.IsNull();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentNamingIsDefined(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(TNaming_Naming) naming;
    if (!label.FindAttribute(TNaming_Naming::GetID(), naming))
      return false;
    return naming->IsDefined();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}
