//
//  OCCTBridge_Document_Assembly.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Document.mm (#1380): XDE assembly traversal/transforms,
//  XCAFDoc_ShapeTool/ShapeMapTool/Location/Editor/AssemblyItemRef/AssemblyItemId/AssemblyIterator,
//  XCAFPrs_DocumentExplorer. Public C surface unchanged; every sibling file imports the same
//  headers this one does (the shared preamble below). No symbol changes, pure file move -- see
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

bool OCCTDocumentIsSubShape(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->shapeTool.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    return XCAFDoc_ShapeTool::IsSubShape(label);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentEditorExpand(OCCTDocumentRef doc, int64_t labelId, bool recursively)
{
  if (!doc)
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    return XCAFDoc_Editor::Expand(doc->doc->Main(), label, recursively);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentEditorRescaleGeometry(OCCTDocumentRef doc,
                                       int64_t         labelId,
                                       double          scaleFactor,
                                       bool            forceIfNotRoot)
{
  if (!doc)
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    return XCAFDoc_Editor::RescaleGeometry(label, scaleFactor, forceIfNotRoot);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentSetLocation(OCCTDocumentRef ref, int64_t labelId, double tx, double ty, double tz)
{
  if (!ref)
    return false;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    gp_Trsf trsf;
    trsf.SetTranslation(gp_Vec(tx, ty, tz));
    TopLoc_Location          loc(trsf);
    Handle(XCAFDoc_Location) attr = XCAFDoc_Location::Set(label, loc);
    return !attr.IsNull();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentGetLocationTranslation(OCCTDocumentRef ref,
                                        int64_t         labelId,
                                        double*         outX,
                                        double*         outY,
                                        double*         outZ)
{
  if (!ref)
    return false;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(XCAFDoc_Location) attr;
    if (!label.FindAttribute(XCAFDoc_Location::GetID(), attr))
      return false;
    TopLoc_Location loc  = attr->Get();
    gp_Trsf         trsf = loc.Transformation();
    *outX                = trsf.TranslationPart().X();
    *outY                = trsf.TranslationPart().Y();
    *outZ                = trsf.TranslationPart().Z();
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentHasLocation(OCCTDocumentRef ref, int64_t labelId)
{
  if (!ref)
    return false;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(XCAFDoc_Location) attr;
    return label.FindAttribute(XCAFDoc_Location::GetID(), attr);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentSetShapeMapTool(OCCTDocumentRef ref, int64_t labelId)
{
  if (!ref)
    return false;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(XCAFDoc_ShapeMapTool) tool = XCAFDoc_ShapeMapTool::Set(label);
    return !tool.IsNull();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentShapeMapToolSetShape(OCCTDocumentRef ref, int64_t labelId, OCCTShapeRef shape)
{
  if (!ref || !shape)
    return false;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(XCAFDoc_ShapeMapTool) tool;
    if (!label.FindAttribute(XCAFDoc_ShapeMapTool::GetID(), tool))
      return false;
    tool->SetShape(*(const TopoDS_Shape*)shape);
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentShapeMapToolIsSubShape(OCCTDocumentRef ref, int64_t labelId, OCCTShapeRef shape)
{
  if (!ref || !shape)
    return false;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    Handle(XCAFDoc_ShapeMapTool) tool;
    if (!label.FindAttribute(XCAFDoc_ShapeMapTool::GetID(), tool))
      return false;
    return tool->IsSubShape(*(const TopoDS_Shape*)shape);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

int32_t OCCTDocumentShapeMapToolExtent(OCCTDocumentRef ref, int64_t labelId)
{
  if (!ref)
    return 0;
  try
  {
    auto*     doc   = (OCCTDocument*)ref;
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return 0;
    Handle(XCAFDoc_ShapeMapTool) tool;
    if (!label.FindAttribute(XCAFDoc_ShapeMapTool::GetID(), tool))
      return 0;
    return tool->GetMap().Extent();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

bool OCCTAssemblyItemIdIsValid(const char* str)
{
  try
  {
    TCollection_AsciiString aStr(str);
    XCAFDoc_AssemblyItemId  id(aStr);
    return !id.IsNull();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

int32_t OCCTAssemblyItemIdPathCount(const char* str)
{
  try
  {
    TCollection_AsciiString aStr(str);
    XCAFDoc_AssemblyItemId  id(aStr);
    return static_cast<int32_t>(id.GetPath().Size());
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

bool OCCTAssemblyItemIdIsEqual(const char* str1, const char* str2)
{
  try
  {
    TCollection_AsciiString aStr1(str1);
    TCollection_AsciiString aStr2(str2);
    XCAFDoc_AssemblyItemId  id1(aStr1);
    XCAFDoc_AssemblyItemId  id2(aStr2);
    return id1.IsEqual(id2);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

OCCTXCAFPrsStyle OCCTXCAFPrsStyleCreate(void)
{
  XCAFPrs_Style    style;
  OCCTXCAFPrsStyle result;
  result.surfR        = 0;
  result.surfG        = 0;
  result.surfB        = 0;
  result.surfAlpha    = 1.0f;
  result.hasSurfColor = false;
  result.curvR        = 0;
  result.curvG        = 0;
  result.curvB        = 0;
  result.hasCurvColor = false;
  result.isVisible    = style.IsVisible();
  result.isEmpty      = style.IsEmpty();
  return result;
}

int32_t OCCTDocumentAssemblyItemCount(OCCTDocumentRef doc, int32_t maxDepth, bool* outTruncated)
{
  if (outTruncated)
    *outTruncated = false;
  if (!doc || doc->doc.IsNull())
    return 0;
  try
  {
    int                      level = (maxDepth <= 0) ? INT_MAX : maxDepth;
    XCAFDoc_AssemblyIterator iter(doc->doc, level);
    int                      count = 0;
    // #964: the walk is bounded because XCAFDoc_AssemblyIterator keeps no visited set, so a
    // malformed self-referencing assembly would iterate until myMaxLevel (INT_MAX by default).
    // The bound stays; what changes is that hitting it is now reported instead of returned as
    // though it were the answer.
    while (iter.More())
    {
      count++;
      iter.Next();
      if (count >= kAssemblyItemCountLimit)
      {
        if (outTruncated)
          *outTruncated = true;
        return count;
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

bool OCCTDocumentSetAssemblyItemRef(OCCTDocumentRef doc, int64_t labelId, const char* itemPath)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull())
      return false;
    TCollection_AsciiString         path(itemPath);
    XCAFDoc_AssemblyItemId          itemId(path);
    Handle(XCAFDoc_AssemblyItemRef) ref = XCAFDoc_AssemblyItemRef::Set(label, itemId);
    return !ref.IsNull();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

const char* OCCTDocumentGetAssemblyItemRef(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return nullptr;
  try
  {
    TDF_Label                       label = doc->getLabel(labelId);
    Handle(XCAFDoc_AssemblyItemRef) ref;
    if (!label.FindAttribute(XCAFDoc_AssemblyItemRef::GetID(), ref))
      return nullptr;
    TCollection_AsciiString path = ref->GetItem().ToString();
    return strdup(path.ToCString());
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

bool OCCTDocumentAssemblyItemRefSetSubshape(OCCTDocumentRef doc, int64_t labelId, int32_t index)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label                       label = doc->getLabel(labelId);
    Handle(XCAFDoc_AssemblyItemRef) ref;
    if (!label.FindAttribute(XCAFDoc_AssemblyItemRef::GetID(), ref))
      return false;
    ref->SetSubshapeIndex(index);
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

int32_t OCCTDocumentAssemblyItemRefGetSubshape(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return -1;
  try
  {
    TDF_Label                       label = doc->getLabel(labelId);
    Handle(XCAFDoc_AssemblyItemRef) ref;
    if (!label.FindAttribute(XCAFDoc_AssemblyItemRef::GetID(), ref))
      return -1;
    if (!ref->IsSubshapeIndex())
      return -1;
    return ref->GetSubshapeIndex();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return -1;
  }
}

bool OCCTDocumentAssemblyItemRefHasExtra(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label                       label = doc->getLabel(labelId);
    Handle(XCAFDoc_AssemblyItemRef) ref;
    if (!label.FindAttribute(XCAFDoc_AssemblyItemRef::GetID(), ref))
      return false;
    return ref->HasExtraRef();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentAssemblyItemRefClearExtra(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return false;
  try
  {
    TDF_Label                       label = doc->getLabel(labelId);
    Handle(XCAFDoc_AssemblyItemRef) ref;
    if (!label.FindAttribute(XCAFDoc_AssemblyItemRef::GetID(), ref))
      return false;
    ref->ClearExtraRef();
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentAssemblyItemRefIsOrphan(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc || doc->doc.IsNull())
    return true;
  try
  {
    TDF_Label                       label = doc->getLabel(labelId);
    Handle(XCAFDoc_AssemblyItemRef) ref;
    if (!label.FindAttribute(XCAFDoc_AssemblyItemRef::GetID(), ref))
      return true;
    return ref->IsOrphan();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return true;
  }
}

int32_t OCCTDocumentExplorerCount(OCCTDocumentRef docRef)
{
  try
  {
    Handle(TDocStd_Document) doc = docRef->doc;
    XCAFPrs_DocumentExplorer explorer(doc,
                                      XCAFPrs_DocumentExplorerFlags_OnlyLeafNodes,
                                      XCAFPrs_Style());
    int32_t                  count = 0;
    while (explorer.More())
    {
      count++;
      explorer.Next();
    }
    return count;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

OCCTShapeRef OCCTDocumentExplorerShape(OCCTDocumentRef docRef, int32_t index)
{
  try
  {
    Handle(TDocStd_Document) doc = docRef->doc;
    XCAFPrs_DocumentExplorer explorer(doc,
                                      XCAFPrs_DocumentExplorerFlags_OnlyLeafNodes,
                                      XCAFPrs_Style());
    int32_t                  i = 0;
    while (explorer.More())
    {
      if (i == index)
      {
        const XCAFPrs_DocumentNode& node      = explorer.Current();
        Handle(XCAFDoc_ShapeTool)   shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
        TopoDS_Shape                shape;
        shapeTool->GetShape(node.RefLabel.IsNull() ? node.Label : node.RefLabel, shape);
        if (shape.IsNull())
          return nullptr;
        auto result   = new OCCTShape();
        result->shape = shape;
        if (!node.Location.IsIdentity())
          result->shape.Location(node.Location);
        return result;
      }
      i++;
      explorer.Next();
    }
    return nullptr;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

char* OCCTDocumentExplorerPathId(OCCTDocumentRef docRef, int32_t index)
{
  try
  {
    Handle(TDocStd_Document) doc = docRef->doc;
    XCAFPrs_DocumentExplorer explorer(doc,
                                      XCAFPrs_DocumentExplorerFlags_OnlyLeafNodes,
                                      XCAFPrs_Style());
    int32_t                  i = 0;
    while (explorer.More())
    {
      if (i == index)
      {
        return strdup(explorer.Current().Id.ToCString());
      }
      i++;
      explorer.Next();
    }
    return nullptr;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

int32_t OCCTDocumentExplorerDepth(OCCTDocumentRef docRef, int32_t index)
{
  try
  {
    Handle(TDocStd_Document) doc = docRef->doc;
    XCAFPrs_DocumentExplorer explorer(doc,
                                      XCAFPrs_DocumentExplorerFlags_OnlyLeafNodes,
                                      XCAFPrs_Style());
    int32_t                  i = 0;
    while (explorer.More())
    {
      if (i == index)
      {
        return (int32_t)explorer.CurrentDepth();
      }
      i++;
      explorer.Next();
    }
    return 0;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

// Always returns false: this explorer's flat index is built with
// XCAFPrs_DocumentExplorerFlags_OnlyLeafNodes (shared with OCCTDocumentExplorerCount/Shape/
// PathId/Depth/Location above), and that flag's own header comment documents it as skipping
// assembly nodes. No index reachable through this walk can ever be an assembly node, by design,
// not a bug: OCCTDocumentIsAssembly(doc, labelId) is the accessor that answers this question for
// real, against the free-shape/component label tree rather than this leaf-only list. #1480.
bool OCCTDocumentExplorerIsAssembly(OCCTDocumentRef docRef, int32_t index)
{
  try
  {
    Handle(TDocStd_Document)  doc       = docRef->doc;
    Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
    XCAFPrs_DocumentExplorer  explorer(doc,
                                       XCAFPrs_DocumentExplorerFlags_OnlyLeafNodes,
                                       XCAFPrs_Style());
    int32_t                   i = 0;
    while (explorer.More())
    {
      if (i == index)
      {
        const XCAFPrs_DocumentNode& node = explorer.Current();
        return shapeTool->IsAssembly(node.Label);
      }
      i++;
      explorer.Next();
    }
    return false;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

void OCCTDocumentExplorerLocation(OCCTDocumentRef docRef, int32_t index, double* matrix12)
{
  for (int j = 0; j < 12; j++)
    matrix12[j] = 0;
  matrix12[0]  = 1;
  matrix12[5]  = 1;
  matrix12[10] = 1; // identity
  try
  {
    Handle(TDocStd_Document) doc = docRef->doc;
    XCAFPrs_DocumentExplorer explorer(doc,
                                      XCAFPrs_DocumentExplorerFlags_OnlyLeafNodes,
                                      XCAFPrs_Style());
    int32_t                  i = 0;
    while (explorer.More())
    {
      if (i == index)
      {
        const XCAFPrs_DocumentNode& node = explorer.Current();
        TopLoc_Location             loc  = node.Location;
        if (!loc.IsIdentity())
        {
          gp_Trsf trsf = loc.Transformation();
          for (int r = 1; r <= 3; r++)
          {
            for (int c = 1; c <= 4; c++)
            {
              matrix12[(r - 1) * 4 + (c - 1)] = trsf.Value(r, c);
            }
          }
        }
        else
        {
          // Identity matrix
          for (int j = 0; j < 12; j++)
            matrix12[j] = 0;
          matrix12[0]  = 1;
          matrix12[5]  = 1;
          matrix12[10] = 1; // diag = 1
        }
        return;
      }
      i++;
      explorer.Next();
    }
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}
