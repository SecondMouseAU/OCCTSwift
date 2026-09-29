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
template <typename AttrType, typename ObjType, typename ToolGetter, typename LabelsGetter>

// Helper: common iteration logic for naming trace (forward/backward)
// Template parameter: the iterator type (TNaming_NewShapeIterator or TNaming_OldShapeIterator)
template <typename Iterator>

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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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

      // Estimate roughness from shininess (and specular color): reuses the same
      // physically-based conversion the visualization side already has for this exact shape,
      // "common material (specular color + shininess) -> roughness"
      // (OCCTMaterialRoughnessFromSpecular, OCCTBridge_Visualization_Appearance.mm,
      // Graphic3d_PBRMaterial::RoughnessFromSpecular). #1508: the previous `1.0 - (common.Shininess
      // / 100.0)` treated Shininess as if it were on a 0-100 scale;
      // XCAFDoc_VisMaterialCommon::Shininess is documented [0,1] (XCAFDoc_VisMaterialCommon.hxx's
      // own default ctor, `Shininess(1.0f)`), so the /100 division collapsed every legitimate value
      // into [0.99, 1.0], reporting a fully glossy material (Shininess 1.0) as nearly fully matte.
      result.roughness = OCCTMaterialRoughnessFromSpecular(common.SpecularColor.Red(),
                                                           common.SpecularColor.Green(),
                                                           common.SpecularColor.Blue(),
                                                           common.Shininess);
    }

    return result;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    // #1508: Quantity_TOC_RGB, matching OCCTDocumentGetColorAttr's Red()/Green()/Blue() readback
    // (Quantity_Color.hxx: those return the internal value with no colorspace conversion) and the
    // sibling OCCTDocumentSetLabelColor/GetLabelColor pair in this same file, which already
    // round-trip correctly on Quantity_TOC_RGB both ways. TOC_sRGB here silently gamma-encoded the
    // caller's RGB into OCCT's internal linear storage on the way in, with nothing decoding it back
    // out, so set-then-get returned a different color than was set.
    Quantity_Color        color(r, g, b, Quantity_TOC_RGB);
    Handle(XCAFDoc_Color) attr = XCAFDoc_Color::Set(label, color);
    return !attr.IsNull();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
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
    // #1508: Quantity_TOC_RGB, see OCCTDocumentSetColorAttr's comment above -- same mismatch,
    // same fix.
    Quantity_ColorRGBA    rgba(Quantity_Color(r, g, b, Quantity_TOC_RGB), alpha);
    Handle(XCAFDoc_Color) attr = XCAFDoc_Color::Set(label, rgba);
    return !attr.IsNull();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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

OCCTXCAFPrsStyle OCCTXCAFPrsStyleCreateWithCurvColor(double r, double g, double b)
{
  XCAFPrs_Style style;
  style.SetColorCurv(Quantity_Color(r, g, b, Quantity_TOC_sRGB));
  OCCTXCAFPrsStyle result;
  result.surfR        = 0;
  result.surfG        = 0;
  result.surfB        = 0;
  result.surfAlpha    = 1.0f;
  result.hasSurfColor = false;
  result.curvR        = r;
  result.curvG        = g;
  result.curvB        = b;
  result.hasCurvColor = true;
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
    return true;
  }
}
