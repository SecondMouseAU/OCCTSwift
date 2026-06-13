//
//  OCCTBridge_Document.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  XDE / XCAF document support: document creation + lifecycle, assembly
//  traversal, transforms, colors, PBR + common visual materials, plus the
//  generic OCCTStringFree helper (declared in the public header but
//  defined here because every label-name getter that allocates a heap
//  string is in this block).
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

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
#include <XCAFDimTolObjects_DimensionObject.hxx>
#include <XCAFDimTolObjects_DimensionType.hxx>
#include <XCAFDimTolObjects_GeomToleranceObject.hxx>
#include <XCAFDimTolObjects_GeomToleranceType.hxx>
#include <TDF_Tool.hxx>
#include <TCollection_HAsciiString.hxx>
#include <TColStd_HArray1OfReal.hxx>
#include <TDataStd_Name.hxx>
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

// MARK: - XDE/XCAF Document Support (v0.6.0)

OCCTDocumentRef OCCTDocumentCreate(void) {
    OCCTDocument* document = nullptr;
    try {
        document = new OCCTDocument();

        // Create a new document
        document->app->NewDocument("MDTV-XCAF", document->doc);

        if (document->doc.IsNull()) {
            delete document;
            return nullptr;
        }

        // Get the tools
        document->shapeTool = XCAFDoc_DocumentTool::ShapeTool(document->doc->Main());
        document->colorTool = XCAFDoc_DocumentTool::ColorTool(document->doc->Main());
        document->materialTool = XCAFDoc_DocumentTool::VisMaterialTool(document->doc->Main());

        return document;
    } catch (...) {
        delete document;
        return nullptr;
    }
}

OCCTDocumentRef OCCTDocumentLoadSTEP(const char* path) {
    if (!path) return nullptr;

    OCCTDocument* document = nullptr;
    try {
        document = new OCCTDocument();

        // Create a new document
        document->app->NewDocument("MDTV-XCAF", document->doc);

        if (document->doc.IsNull()) {
            delete document;
            return nullptr;
        }

        // Configure the reader
        STEPCAFControl_Reader reader;
        reader.SetColorMode(Standard_True);
        reader.SetNameMode(Standard_True);
        reader.SetLayerMode(Standard_True);
        reader.SetPropsMode(Standard_True);
        reader.SetMatMode(Standard_True);  // Enable material reading

        // Read the file
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) {
            delete document;
            return nullptr;
        }

        // Transfer to document
        if (!reader.Transfer(document->doc)) {
            delete document;
            return nullptr;
        }

        // Get the tools
        document->shapeTool = XCAFDoc_DocumentTool::ShapeTool(document->doc->Main());
        document->colorTool = XCAFDoc_DocumentTool::ColorTool(document->doc->Main());
        document->materialTool = XCAFDoc_DocumentTool::VisMaterialTool(document->doc->Main());

        return document;
    } catch (...) {
        delete document;
        return nullptr;
    }
}

bool OCCTDocumentWriteSTEP(OCCTDocumentRef doc, const char* path) {
    if (!doc || !path) return false;

    try {
        // STEP and IGES writers share OCCT's non-thread-safe Interface_Static
        // globals; serialize all DE writes on one lock (#181-B).
        std::lock_guard<std::mutex> deLock(igesMutex());
        STEPCAFControl_Writer writer;
        writer.SetColorMode(Standard_True);
        writer.SetNameMode(Standard_True);
        writer.SetLayerMode(Standard_True);
        writer.SetPropsMode(Standard_True);
        writer.SetMaterialMode(Standard_True);  // Enable material writing

        if (!writer.Transfer(doc->doc, STEPControl_AsIs)) {
            return false;
        }

        IFSelect_ReturnStatus status = writer.Write(path);
        return status == IFSelect_RetDone;
    } catch (...) {
        return false;
    }
}

void OCCTDocumentRelease(OCCTDocumentRef doc) {
    if (!doc) return;

    try {
        if (!doc->doc.IsNull()) {
            doc->app->Close(doc->doc);
        }
    } catch (...) {
        // Ignore cleanup errors
    }

    delete doc;
}

// MARK: - XDE Assembly Traversal

int32_t OCCTDocumentGetRootCount(OCCTDocumentRef doc) {
    if (!doc || doc->shapeTool.IsNull()) return 0;

    try {
        TDF_LabelSequence roots;
        doc->shapeTool->GetFreeShapes(roots);
        return static_cast<int32_t>(roots.Length());
    } catch (...) {
        return 0;
    }
}

int64_t OCCTDocumentGetRootLabelId(OCCTDocumentRef doc, int32_t index) {
    if (!doc || doc->shapeTool.IsNull() || index < 0) return -1;

    try {
        TDF_LabelSequence roots;
        doc->shapeTool->GetFreeShapes(roots);

        if (index >= roots.Length()) return -1;

        TDF_Label label = roots.Value(index + 1);  // OCCT is 1-based
        return doc->registerLabel(label);
    } catch (...) {
        return -1;
    }
}

const char* OCCTDocumentGetLabelName(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc) return nullptr;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;

        Handle(TDataStd_Name) nameAttr;
        if (label.FindAttribute(TDataStd_Name::GetID(), nameAttr)) {
            TCollection_ExtendedString name = nameAttr->Get();
            TCollection_AsciiString asciiName(name);

            // Allocate and copy the string (caller must free with OCCTStringFree)
            char* result = new char[asciiName.Length() + 1];
            std::strcpy(result, asciiName.ToCString());
            return result;
        }

        return nullptr;
    } catch (...) {
        return nullptr;
    }
}

bool OCCTDocumentIsAssembly(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->shapeTool.IsNull()) return false;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;

        return doc->shapeTool->IsAssembly(label);
    } catch (...) {
        return false;
    }
}

bool OCCTDocumentIsReference(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->shapeTool.IsNull()) return false;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;

        return doc->shapeTool->IsReference(label);
    } catch (...) {
        return false;
    }
}

int32_t OCCTDocumentGetChildCount(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->shapeTool.IsNull()) return 0;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return 0;

        TDF_LabelSequence components;
        doc->shapeTool->GetComponents(label, components);
        return static_cast<int32_t>(components.Length());
    } catch (...) {
        return 0;
    }
}

int64_t OCCTDocumentGetChildLabelId(OCCTDocumentRef doc, int64_t parentLabelId, int32_t index) {
    if (!doc || doc->shapeTool.IsNull() || index < 0) return -1;

    try {
        TDF_Label parentLabel = doc->getLabel(parentLabelId);
        if (parentLabel.IsNull()) return -1;

        TDF_LabelSequence components;
        doc->shapeTool->GetComponents(parentLabel, components);

        if (index >= components.Length()) return -1;

        TDF_Label childLabel = components.Value(index + 1);  // OCCT is 1-based
        return doc->registerLabel(childLabel);
    } catch (...) {
        return -1;
    }
}

int64_t OCCTDocumentGetReferredLabelId(OCCTDocumentRef doc, int64_t refLabelId) {
    if (!doc || doc->shapeTool.IsNull()) return -1;

    try {
        TDF_Label refLabel = doc->getLabel(refLabelId);
        if (refLabel.IsNull()) return -1;

        TDF_Label referredLabel;
        if (!doc->shapeTool->GetReferredShape(refLabel, referredLabel)) {
            return -1;
        }

        return doc->registerLabel(referredLabel);
    } catch (...) {
        return -1;
    }
}

OCCTShapeRef OCCTDocumentGetShape(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->shapeTool.IsNull()) return nullptr;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;

        TopoDS_Shape shape = doc->shapeTool->GetShape(label);
        if (shape.IsNull()) return nullptr;

        return new OCCTShape(shape);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTDocumentGetShapeWithLocation(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->shapeTool.IsNull()) return nullptr;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;

        // Get shape with accumulated location
        TopoDS_Shape shape;

        // If it's a reference, get the referred shape with location
        if (doc->shapeTool->IsReference(label)) {
            TDF_Label referredLabel;
            if (doc->shapeTool->GetReferredShape(label, referredLabel)) {
                shape = doc->shapeTool->GetShape(referredLabel);
                // Apply location from reference
                TopLoc_Location loc = doc->shapeTool->GetLocation(label);
                shape.Location(loc);
            }
        } else {
            shape = doc->shapeTool->GetShape(label);
        }

        if (shape.IsNull()) return nullptr;

        return new OCCTShape(shape);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - XDE Transforms

void OCCTDocumentGetLocation(OCCTDocumentRef doc, int64_t labelId, float* outMatrix16) {
    if (!doc || !outMatrix16) return;

    // Initialize to identity matrix (column-major)
    for (int i = 0; i < 16; i++) {
        outMatrix16[i] = (i % 5 == 0) ? 1.0f : 0.0f;
    }

    if (doc->shapeTool.IsNull()) return;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return;

        TopLoc_Location loc = doc->shapeTool->GetLocation(label);
        if (loc.IsIdentity()) return;

        gp_Trsf trsf = loc.Transformation();

        // Extract rotation/scale part (3x3)
        for (int row = 0; row < 3; row++) {
            for (int col = 0; col < 3; col++) {
                outMatrix16[col * 4 + row] = static_cast<float>(trsf.Value(row + 1, col + 1));
            }
        }

        // Extract translation
        outMatrix16[12] = static_cast<float>(trsf.TranslationPart().X());
        outMatrix16[13] = static_cast<float>(trsf.TranslationPart().Y());
        outMatrix16[14] = static_cast<float>(trsf.TranslationPart().Z());
        outMatrix16[15] = 1.0f;
    } catch (...) {
        // Keep identity matrix on error
    }
}

// MARK: - XDE Colors

OCCTColor OCCTDocumentGetLabelColor(OCCTDocumentRef doc, int64_t labelId, OCCTColorType colorType) {
    OCCTColor result = {0, 0, 0, 1.0, false};

    if (!doc || doc->colorTool.IsNull()) return result;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return result;

        Quantity_ColorRGBA color;
        XCAFDoc_ColorType xcafType;

        switch (colorType) {
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
        if (doc->colorTool->GetColor(label, xcafType, color)) {
            result.r = color.GetRGB().Red();
            result.g = color.GetRGB().Green();
            result.b = color.GetRGB().Blue();
            result.a = color.Alpha();
            result.isSet = true;
            return result;
        }

        // If this is a reference, try to get color from referred shape
        if (doc->shapeTool->IsReference(label)) {
            TDF_Label referredLabel;
            if (doc->shapeTool->GetReferredShape(label, referredLabel)) {
                if (doc->colorTool->GetColor(referredLabel, xcafType, color)) {
                    result.r = color.GetRGB().Red();
                    result.g = color.GetRGB().Green();
                    result.b = color.GetRGB().Blue();
                    result.a = color.Alpha();
                    result.isSet = true;
                }
            }
        }

        return result;
    } catch (...) {
        return result;
    }
}

void OCCTDocumentSetLabelColor(OCCTDocumentRef doc, int64_t labelId, OCCTColorType colorType, double r, double g, double b) {
    if (!doc || doc->colorTool.IsNull()) return;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return;

        Quantity_Color color(r, g, b, Quantity_TOC_RGB);
        XCAFDoc_ColorType xcafType;

        switch (colorType) {
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
    } catch (...) {
        // Ignore errors
    }
}

// MARK: - XDE Materials (PBR)

OCCTMaterial OCCTDocumentGetLabelMaterial(OCCTDocumentRef doc, int64_t labelId) {
    OCCTMaterial result = {{0, 0, 0, 1.0, false}, 0.0, 0.5, {0, 0, 0, 1.0, false}, 0.0, false};

    if (!doc || doc->materialTool.IsNull()) return result;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return result;

        // Get shape to find material
        TopoDS_Shape shape = doc->shapeTool->GetShape(label);
        if (shape.IsNull()) {
            // Try from reference
            if (doc->shapeTool->IsReference(label)) {
                TDF_Label referredLabel;
                if (doc->shapeTool->GetReferredShape(label, referredLabel)) {
                    shape = doc->shapeTool->GetShape(referredLabel);
                }
            }
        }

        if (shape.IsNull()) return result;

        // Try to get material from shape
        Handle(XCAFDoc_VisMaterial) visMat = doc->materialTool->GetShapeMaterial(shape);
        if (visMat.IsNull()) return result;

        result.isSet = true;

        // Get PBR properties if available
        if (visMat->HasPbrMaterial()) {
            XCAFDoc_VisMaterialPBR pbr = visMat->PbrMaterial();

            // Base color
            Quantity_ColorRGBA baseColor = pbr.BaseColor;
            result.baseColor.r = baseColor.GetRGB().Red();
            result.baseColor.g = baseColor.GetRGB().Green();
            result.baseColor.b = baseColor.GetRGB().Blue();
            result.baseColor.a = baseColor.Alpha();
            result.baseColor.isSet = true;

            // Metallic and roughness
            result.metallic = pbr.Metallic;
            result.roughness = pbr.Roughness;

            // Emissive (Graphic3d_Vec3)
            result.emissive.r = pbr.EmissiveFactor.x();
            result.emissive.g = pbr.EmissiveFactor.y();
            result.emissive.b = pbr.EmissiveFactor.z();
            result.emissive.a = 1.0;
            result.emissive.isSet = true;
        } else if (visMat->HasCommonMaterial()) {
            // Fall back to common material
            XCAFDoc_VisMaterialCommon common = visMat->CommonMaterial();

            result.baseColor.r = common.DiffuseColor.Red();
            result.baseColor.g = common.DiffuseColor.Green();
            result.baseColor.b = common.DiffuseColor.Blue();
            result.baseColor.a = 1.0 - common.Transparency;
            result.baseColor.isSet = true;

            result.transparency = common.Transparency;

            // Estimate roughness from shininess
            result.roughness = 1.0 - (common.Shininess / 100.0);
        }

        return result;
    } catch (...) {
        return result;
    }
}

void OCCTDocumentSetLabelMaterial(OCCTDocumentRef doc, int64_t labelId, OCCTMaterial material) {
    if (!doc || doc->materialTool.IsNull() || !material.isSet) return;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return;

        TopoDS_Shape shape = doc->shapeTool->GetShape(label);
        if (shape.IsNull()) return;

        // Create new material
        Handle(XCAFDoc_VisMaterial) visMat = new XCAFDoc_VisMaterial();

        // Set PBR properties
        XCAFDoc_VisMaterialPBR pbr;
        pbr.BaseColor = Quantity_ColorRGBA(
            Quantity_Color(material.baseColor.r, material.baseColor.g, material.baseColor.b, Quantity_TOC_RGB),
            static_cast<float>(material.baseColor.a)
        );
        pbr.Metallic = static_cast<Standard_ShortReal>(material.metallic);
        pbr.Roughness = static_cast<Standard_ShortReal>(material.roughness);
        pbr.EmissiveFactor = Graphic3d_Vec3(
            static_cast<float>(material.emissive.r),
            static_cast<float>(material.emissive.g),
            static_cast<float>(material.emissive.b)
        );

        visMat->SetPbrMaterial(pbr);

        // Add material and bind to shape
        TDF_Label matLabel = doc->materialTool->AddMaterial(visMat, TCollection_AsciiString("Material"));
        doc->materialTool->SetShapeMaterial(shape, matLabel);
    } catch (...) {
        // Ignore errors
    }
}

// MARK: - XDE Utility

void OCCTStringFree(const char* str) {
    delete[] str;
}

// MARK: - Document Length Unit (v0.30.0)

#include <XCAFDoc_LengthUnit.hxx>

bool OCCTDocumentGetLengthUnit(OCCTDocumentRef doc, double* unitScale, char* unitName, int32_t maxNameLen) {
    if (!doc || doc->doc.IsNull() || !unitScale) return false;
    try {
        TDF_Label rootLabel = doc->doc->Main().Root();
        Handle(XCAFDoc_LengthUnit) luAttr;
        if (!rootLabel.FindAttribute(XCAFDoc_LengthUnit::GetID(), luAttr)) {
            // Try the main label
            TDF_Label mainLabel = doc->doc->Main();
            if (!mainLabel.FindAttribute(XCAFDoc_LengthUnit::GetID(), luAttr)) {
                return false;
            }
        }
        *unitScale = luAttr->GetUnitValue();
        if (unitName && maxNameLen > 0) {
            TCollection_AsciiString name = luAttr->GetUnitName();
            int len = name.Length();
            if (len >= maxNameLen) len = maxNameLen - 1;
            for (int i = 0; i < len; i++) {
                unitName[i] = name.Value(i + 1);
            }
            unitName[len] = '\0';
        }
        return true;
    } catch (...) {
        return false;
    }
}

// MARK: - Document Layers (v0.31.0)

#include <XCAFDoc_LayerTool.hxx>

int32_t OCCTDocumentGetLayerCount(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        Handle(XCAFDoc_LayerTool) layerTool = XCAFDoc_LayerTool::Set(doc->doc->Main());
        if (layerTool.IsNull()) return 0;
        TDF_LabelSequence labels;
        layerTool->GetLayerLabels(labels);
        return (int32_t)labels.Length();
    } catch (...) {
        return 0;
    }
}

bool OCCTDocumentGetLayerName(OCCTDocumentRef doc, int32_t index, char* outName, int32_t maxLen) {
    if (!doc || doc->doc.IsNull() || !outName || maxLen <= 0) return false;
    try {
        Handle(XCAFDoc_LayerTool) layerTool = XCAFDoc_LayerTool::Set(doc->doc->Main());
        if (layerTool.IsNull()) return false;
        TDF_LabelSequence labels;
        layerTool->GetLayerLabels(labels);
        if (index < 0 || index >= labels.Length()) return false;
        TDF_Label label = labels.Value(index + 1);
        TCollection_ExtendedString name;
        if (!layerTool->GetLayer(label, name)) return false;
        // Convert ExtendedString to ASCII
        TCollection_AsciiString ascii(name);
        int32_t len = ascii.Length();
        if (len >= maxLen) len = maxLen - 1;
        for (int32_t i = 0; i < len; i++) {
            outName[i] = ascii.Value(i + 1);
        }
        outName[len] = '\0';
        return true;
    } catch (...) {
        return false;
    }
}

// MARK: - Document Materials (v0.31.0)

#include <XCAFDoc_MaterialTool.hxx>
#include <TCollection_HAsciiString.hxx>

int32_t OCCTDocumentGetMaterialCount(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        Handle(XCAFDoc_MaterialTool) matTool = XCAFDoc_MaterialTool::Set(doc->doc->Main());
        if (matTool.IsNull()) return 0;
        TDF_LabelSequence labels;
        matTool->GetMaterialLabels(labels);
        return (int32_t)labels.Length();
    } catch (...) {
        return 0;
    }
}

bool OCCTDocumentGetMaterialInfo(OCCTDocumentRef doc, int32_t index, OCCTMaterialInfo* outInfo) {
    if (!doc || doc->doc.IsNull() || !outInfo) return false;
    try {
        Handle(XCAFDoc_MaterialTool) matTool = XCAFDoc_MaterialTool::Set(doc->doc->Main());
        if (matTool.IsNull()) return false;
        TDF_LabelSequence labels;
        matTool->GetMaterialLabels(labels);
        if (index < 0 || index >= labels.Length()) return false;
        TDF_Label label = labels.Value(index + 1);
        Handle(TCollection_HAsciiString) hName, hDesc, hDensName, hDensValType;
        double density = 0.0;
        matTool->GetMaterial(label, hName, hDesc, density, hDensName, hDensValType);
        memset(outInfo, 0, sizeof(OCCTMaterialInfo));
        if (!hName.IsNull()) {
            TCollection_AsciiString name = hName->String();
            int32_t len = std::min((int32_t)name.Length(), (int32_t)(sizeof(outInfo->name) - 1));
            for (int32_t i = 0; i < len; i++) {
                outInfo->name[i] = name.Value(i + 1);
            }
        }
        if (!hDesc.IsNull()) {
            TCollection_AsciiString desc = hDesc->String();
            int32_t len = std::min((int32_t)desc.Length(), (int32_t)(sizeof(outInfo->description) - 1));
            for (int32_t i = 0; i < len; i++) {
                outInfo->description[i] = desc.Value(i + 1);
            }
        }
        outInfo->density = density;
        return true;
    } catch (...) {
        return false;
    }
}

// MARK: - XDE GD&T / Dimension Tolerance (v0.21.0)
// ============================================================================

#include <XCAFDoc_DimTolTool.hxx>
#include <XCAFDoc_Dimension.hxx>
#include <XCAFDoc_GeomTolerance.hxx>
#include <XCAFDoc_Datum.hxx>
#include <XCAFDimTolObjects_DimensionObject.hxx>
#include <XCAFDimTolObjects_GeomToleranceObject.hxx>
#include <XCAFDimTolObjects_DatumObject.hxx>

int32_t OCCTDocumentGetDimensionCount(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        Handle(XCAFDoc_DimTolTool) dimTolTool =
            XCAFDoc_DimTolTool::Set(doc->doc->Main());
        TDF_LabelSequence labels;
        dimTolTool->GetDimensionLabels(labels);
        return (int32_t)labels.Length();
    } catch (...) {
        return 0;
    }
}

int32_t OCCTDocumentGetGeomToleranceCount(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        Handle(XCAFDoc_DimTolTool) dimTolTool =
            XCAFDoc_DimTolTool::Set(doc->doc->Main());
        TDF_LabelSequence labels;
        dimTolTool->GetGeomToleranceLabels(labels);
        return (int32_t)labels.Length();
    } catch (...) {
        return 0;
    }
}

int32_t OCCTDocumentGetDatumCount(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        Handle(XCAFDoc_DimTolTool) dimTolTool =
            XCAFDoc_DimTolTool::Set(doc->doc->Main());
        TDF_LabelSequence labels;
        dimTolTool->GetDatumLabels(labels);
        return (int32_t)labels.Length();
    } catch (...) {
        return 0;
    }
}

OCCTDimensionInfo OCCTDocumentGetDimensionInfo(OCCTDocumentRef doc, int32_t index) {
    OCCTDimensionInfo info = {};
    info.isValid = false;
    if (!doc || doc->doc.IsNull()) return info;
    try {
        Handle(XCAFDoc_DimTolTool) dimTolTool =
            XCAFDoc_DimTolTool::Set(doc->doc->Main());
        TDF_LabelSequence labels;
        dimTolTool->GetDimensionLabels(labels);
        if (index < 0 || index >= (int32_t)labels.Length()) return info;

        TDF_Label label = labels.Value(index + 1);
        Handle(XCAFDoc_Dimension) dimAttr;
        if (!label.FindAttribute(XCAFDoc_Dimension::GetID(), dimAttr)) return info;

        Handle(XCAFDimTolObjects_DimensionObject) dimObj = dimAttr->GetObject();
        if (dimObj.IsNull()) return info;

        info.type = (int32_t)dimObj->GetType();
        Handle(TColStd_HArray1OfReal) vals = dimObj->GetValues();
        if (!vals.IsNull() && vals->Length() > 0) {
            info.value = vals->Value(vals->Lower());
        }
        info.lowerTol = dimObj->GetLowerTolValue();
        info.upperTol = dimObj->GetUpperTolValue();
        info.isValid = true;
        return info;
    } catch (...) {
        return info;
    }
}

OCCTGeomToleranceInfo OCCTDocumentGetGeomToleranceInfo(OCCTDocumentRef doc, int32_t index) {
    OCCTGeomToleranceInfo info = {};
    info.isValid = false;
    if (!doc || doc->doc.IsNull()) return info;
    try {
        Handle(XCAFDoc_DimTolTool) dimTolTool =
            XCAFDoc_DimTolTool::Set(doc->doc->Main());
        TDF_LabelSequence labels;
        dimTolTool->GetGeomToleranceLabels(labels);
        if (index < 0 || index >= (int32_t)labels.Length()) return info;

        TDF_Label label = labels.Value(index + 1);
        Handle(XCAFDoc_GeomTolerance) tolAttr;
        if (!label.FindAttribute(XCAFDoc_GeomTolerance::GetID(), tolAttr)) return info;

        Handle(XCAFDimTolObjects_GeomToleranceObject) tolObj = tolAttr->GetObject();
        if (tolObj.IsNull()) return info;

        info.type = (int32_t)tolObj->GetType();
        info.value = tolObj->GetValue();
        info.isValid = true;
        return info;
    } catch (...) {
        return info;
    }
}

OCCTDatumInfo OCCTDocumentGetDatumInfo(OCCTDocumentRef doc, int32_t index) {
    OCCTDatumInfo info = {};
    info.isValid = false;
    memset(info.name, 0, sizeof(info.name));
    if (!doc || doc->doc.IsNull()) return info;
    try {
        Handle(XCAFDoc_DimTolTool) dimTolTool =
            XCAFDoc_DimTolTool::Set(doc->doc->Main());
        TDF_LabelSequence labels;
        dimTolTool->GetDatumLabels(labels);
        if (index < 0 || index >= (int32_t)labels.Length()) return info;

        TDF_Label label = labels.Value(index + 1);
        Handle(XCAFDoc_Datum) datumAttr;
        if (!label.FindAttribute(XCAFDoc_Datum::GetID(), datumAttr)) return info;

        Handle(XCAFDimTolObjects_DatumObject) datumObj = datumAttr->GetObject();
        if (datumObj.IsNull()) return info;

        Handle(TCollection_HAsciiString) hName = datumObj->GetName();
        if (!hName.IsNull() && hName->Length() > 0) {
            strncpy(info.name, hName->String().ToCString(),
                    std::min((int)sizeof(info.name) - 1, hName->Length()));
        }
        info.isValid = true;
        return info;
    } catch (...) {
        return info;
    }
}

// MARK: - GD&T Write Path (v0.140)

#include <XCAFDoc_ShapeTool.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <TDF_Tool.hxx>
#include <TCollection_AsciiString.hxx>

int32_t OCCTDocumentCreateDimension(OCCTDocumentRef doc,
                                     int64_t shapeLabelId,
                                     int32_t type,
                                     double value) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        Handle(XCAFDoc_DimTolTool) dimTolTool =
            XCAFDoc_DimTolTool::Set(doc->doc->Main());
        TDF_Label shapeLabel = doc->getLabel(shapeLabelId);
        if (shapeLabel.IsNull()) return -1;

        TDF_Label dimLabel = dimTolTool->AddDimension();
        TDF_LabelSequence shapeSeq;
        shapeSeq.Append(shapeLabel);
        dimTolTool->SetDimension(shapeSeq, shapeSeq, dimLabel);

        Handle(XCAFDoc_Dimension) dimAttr;
        if (!dimLabel.FindAttribute(XCAFDoc_Dimension::GetID(), dimAttr)) return -1;

        Handle(XCAFDimTolObjects_DimensionObject) dimObj =
            new XCAFDimTolObjects_DimensionObject();
        dimObj->SetType((XCAFDimTolObjects_DimensionType)type);
        Handle(TColStd_HArray1OfReal) vals = new TColStd_HArray1OfReal(1, 1);
        vals->SetValue(1, value);
        dimObj->SetValues(vals);
        dimAttr->SetObject(dimObj);

        // Return the index of the new dimension.
        TDF_LabelSequence labels;
        dimTolTool->GetDimensionLabels(labels);
        return (int32_t)labels.Length() - 1;
    } catch (...) {
        return -1;
    }
}

int32_t OCCTDocumentCreateGeomTolerance(OCCTDocumentRef doc,
                                         int64_t shapeLabelId,
                                         int32_t type,
                                         double value) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        Handle(XCAFDoc_DimTolTool) dimTolTool =
            XCAFDoc_DimTolTool::Set(doc->doc->Main());
        TDF_Label shapeLabel = doc->getLabel(shapeLabelId);
        if (shapeLabel.IsNull()) return -1;

        TDF_Label tolLabel = dimTolTool->AddGeomTolerance();
        TDF_LabelSequence shapeSeq;
        shapeSeq.Append(shapeLabel);
        dimTolTool->SetGeomTolerance(shapeSeq, tolLabel);

        Handle(XCAFDoc_GeomTolerance) tolAttr;
        if (!tolLabel.FindAttribute(XCAFDoc_GeomTolerance::GetID(), tolAttr)) return -1;

        Handle(XCAFDimTolObjects_GeomToleranceObject) tolObj =
            new XCAFDimTolObjects_GeomToleranceObject();
        tolObj->SetType((XCAFDimTolObjects_GeomToleranceType)type);
        tolObj->SetValue(value);
        tolAttr->SetObject(tolObj);

        TDF_LabelSequence labels;
        dimTolTool->GetGeomToleranceLabels(labels);
        return (int32_t)labels.Length() - 1;
    } catch (...) {
        return -1;
    }
}

int32_t OCCTDocumentCreateDatum(OCCTDocumentRef doc, const char* name) {
    if (!doc || doc->doc.IsNull() || !name) return -1;
    try {
        Handle(XCAFDoc_DimTolTool) dimTolTool =
            XCAFDoc_DimTolTool::Set(doc->doc->Main());

        TDF_Label datLabel = dimTolTool->AddDatum();
        Handle(XCAFDoc_Datum) datAttr;
        if (!datLabel.FindAttribute(XCAFDoc_Datum::GetID(), datAttr)) return -1;

        Handle(XCAFDimTolObjects_DatumObject) datObj =
            new XCAFDimTolObjects_DatumObject();
        datObj->SetName(new TCollection_HAsciiString(name));
        datAttr->SetObject(datObj);

        TDF_LabelSequence labels;
        dimTolTool->GetDatumLabels(labels);
        return (int32_t)labels.Length() - 1;
    } catch (...) {
        return -1;
    }
}

bool OCCTDocumentSetDimensionTolerance(OCCTDocumentRef doc,
                                        int32_t dimensionIndex,
                                        double lowerTol, double upperTol) {
    if (!doc || doc->doc.IsNull() || dimensionIndex < 0) return false;
    try {
        Handle(XCAFDoc_DimTolTool) dimTolTool =
            XCAFDoc_DimTolTool::Set(doc->doc->Main());
        TDF_LabelSequence labels;
        dimTolTool->GetDimensionLabels(labels);
        if (dimensionIndex >= (int32_t)labels.Length()) return false;

        TDF_Label label = labels.Value(dimensionIndex + 1);
        Handle(XCAFDoc_Dimension) dimAttr;
        if (!label.FindAttribute(XCAFDoc_Dimension::GetID(), dimAttr)) return false;

        Handle(XCAFDimTolObjects_DimensionObject) dimObj = dimAttr->GetObject();
        if (dimObj.IsNull()) return false;

        dimObj->SetLowerTolValue(lowerTol);
        dimObj->SetUpperTolValue(upperTol);
        dimAttr->SetObject(dimObj);
        return true;
    } catch (...) {
        return false;
    }
}

// MARK: - TNaming: Topological Naming History (v0.25.0)

#include <TNaming_Builder.hxx>
#include <TNaming_NamedShape.hxx>
#include <TNaming_Selector.hxx>
#include <TNaming_Iterator.hxx>
#include <TNaming_NewShapeIterator.hxx>
#include <TNaming_OldShapeIterator.hxx>
#include <TNaming_Tool.hxx>
#include <TDF_Label.hxx>
#include <TDF_LabelMap.hxx>
#include <TDF_Data.hxx>

int64_t OCCTDocumentCreateLabel(OCCTDocumentRef doc, int64_t parentLabelId) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label parentLabel;
        if (parentLabelId < 0) {
            // Create under document root
            parentLabel = doc->doc->Main();
        } else {
            parentLabel = doc->getLabel(parentLabelId);
            if (parentLabel.IsNull()) return -1;
        }
        TDF_Label newLabel = parentLabel.NewChild();
        return doc->registerLabel(newLabel);
    } catch (...) {
        return -1;
    }
}

bool OCCTDocumentNamingRecord(OCCTDocumentRef doc, int64_t labelId,
                               OCCTNamingEvolution evolution,
                               OCCTShapeRef oldShape, OCCTShapeRef newShape) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;

        TNaming_Builder builder(label);
        switch (evolution) {
            case OCCTNamingPrimitive:
                if (!newShape) return false;
                builder.Generated(newShape->shape);
                break;
            case OCCTNamingGenerated:
                if (!oldShape || !newShape) return false;
                builder.Generated(oldShape->shape, newShape->shape);
                break;
            case OCCTNamingModify:
                if (!oldShape || !newShape) return false;
                builder.Modify(oldShape->shape, newShape->shape);
                break;
            case OCCTNamingDelete:
                if (!oldShape) return false;
                builder.Delete(oldShape->shape);
                break;
            case OCCTNamingSelected:
                if (!oldShape || !newShape) return false;
                builder.Select(newShape->shape, oldShape->shape);
                break;
            default:
                return false;
        }
        return true;
    } catch (...) {
        return false;
    }
}

OCCTShapeRef OCCTDocumentNamingGetCurrentShape(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return nullptr;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;

        Handle(TNaming_NamedShape) ns;
        if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns)) return nullptr;
        if (ns.IsNull() || ns->IsEmpty()) return nullptr;

        TopoDS_Shape current = TNaming_Tool::CurrentShape(ns);
        if (current.IsNull()) return nullptr;

        return new OCCTShape(current);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTDocumentNamingGetShape(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return nullptr;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;

        Handle(TNaming_NamedShape) ns;
        if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns)) return nullptr;
        if (ns.IsNull() || ns->IsEmpty()) return nullptr;

        TopoDS_Shape shape = TNaming_Tool::GetShape(ns);
        if (shape.IsNull()) return nullptr;

        return new OCCTShape(shape);
    } catch (...) {
        return nullptr;
    }
}

int32_t OCCTDocumentNamingHistoryCount(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return 0;

        Handle(TNaming_NamedShape) ns;
        if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns)) return 0;

        int32_t count = 0;
        for (TNaming_Iterator it(ns); it.More(); it.Next()) {
            count++;
        }
        return count;
    } catch (...) {
        return 0;
    }
}

bool OCCTDocumentNamingGetHistoryEntry(OCCTDocumentRef doc, int64_t labelId,
                                        int32_t index, OCCTNamingHistoryEntry* outEntry) {
    if (!doc || !outEntry || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;

        Handle(TNaming_NamedShape) ns;
        if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns)) return false;

        int32_t i = 0;
        for (TNaming_Iterator it(ns); it.More(); it.Next(), i++) {
            if (i == index) {
                TNaming_Evolution evo = it.Evolution();
                outEntry->hasOldShape = !it.OldShape().IsNull();
                outEntry->hasNewShape = !it.NewShape().IsNull();
                outEntry->isModification = it.IsModification();
                switch (evo) {
                    case TNaming_PRIMITIVE: outEntry->evolution = OCCTNamingPrimitive; break;
                    case TNaming_GENERATED: outEntry->evolution = OCCTNamingGenerated; break;
                    case TNaming_MODIFY: outEntry->evolution = OCCTNamingModify; break;
                    case TNaming_DELETE: outEntry->evolution = OCCTNamingDelete; break;
                    case TNaming_SELECTED: outEntry->evolution = OCCTNamingSelected; break;
                    default: outEntry->evolution = OCCTNamingPrimitive; break;
                }
                return true;
            }
        }
        return false;
    } catch (...) {
        return false;
    }
}

OCCTShapeRef OCCTDocumentNamingGetOldShape(OCCTDocumentRef doc, int64_t labelId, int32_t index) {
    if (!doc || doc->doc.IsNull()) return nullptr;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;

        Handle(TNaming_NamedShape) ns;
        if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns)) return nullptr;

        int32_t i = 0;
        for (TNaming_Iterator it(ns); it.More(); it.Next(), i++) {
            if (i == index) {
                TopoDS_Shape old = it.OldShape();
                if (old.IsNull()) return nullptr;
                return new OCCTShape(old);
            }
        }
        return nullptr;
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTDocumentNamingGetNewShape(OCCTDocumentRef doc, int64_t labelId, int32_t index) {
    if (!doc || doc->doc.IsNull()) return nullptr;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;

        Handle(TNaming_NamedShape) ns;
        if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns)) return nullptr;

        int32_t i = 0;
        for (TNaming_Iterator it(ns); it.More(); it.Next(), i++) {
            if (i == index) {
                TopoDS_Shape nw = it.NewShape();
                if (nw.IsNull()) return nullptr;
                return new OCCTShape(nw);
            }
        }
        return nullptr;
    } catch (...) {
        return nullptr;
    }
}

int32_t OCCTDocumentNamingTraceForward(OCCTDocumentRef doc, int64_t accessLabelId,
                                        OCCTShapeRef shape,
                                        OCCTShapeRef* outShapes, int32_t maxCount) {
    if (!doc || !shape || !outShapes || doc->doc.IsNull()) return 0;
    try {
        TDF_Label access = doc->getLabel(accessLabelId);
        if (access.IsNull()) return 0;

        int32_t count = 0;
        for (TNaming_NewShapeIterator it(shape->shape, access);
             it.More() && count < maxCount; it.Next()) {
            TopoDS_Shape s = it.Shape();
            if (!s.IsNull()) {
                outShapes[count] = new OCCTShape(s);
                count++;
            }
        }
        return count;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTDocumentNamingTraceBackward(OCCTDocumentRef doc, int64_t accessLabelId,
                                         OCCTShapeRef shape,
                                         OCCTShapeRef* outShapes, int32_t maxCount) {
    if (!doc || !shape || !outShapes || doc->doc.IsNull()) return 0;
    try {
        TDF_Label access = doc->getLabel(accessLabelId);
        if (access.IsNull()) return 0;

        int32_t count = 0;
        for (TNaming_OldShapeIterator it(shape->shape, access);
             it.More() && count < maxCount; it.Next()) {
            TopoDS_Shape s = it.Shape();
            if (!s.IsNull()) {
                outShapes[count] = new OCCTShape(s);
                count++;
            }
        }
        return count;
    } catch (...) {
        return 0;
    }
}

bool OCCTDocumentNamingSelect(OCCTDocumentRef doc, int64_t labelId,
                               OCCTShapeRef selection, OCCTShapeRef context) {
    if (!doc || !selection || !context || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;

        TNaming_Selector selector(label);
        return selector.Select(selection->shape, context->shape);
    } catch (...) {
        return false;
    }
}

OCCTShapeRef OCCTDocumentNamingResolve(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return nullptr;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;

        TNaming_Selector selector(label);
        TDF_LabelMap valid;
        if (!selector.Solve(valid)) return nullptr;

        Handle(TNaming_NamedShape) ns = selector.NamedShape();
        if (ns.IsNull() || ns->IsEmpty()) return nullptr;

        TopoDS_Shape shape = TNaming_Tool::CurrentShape(ns);
        if (shape.IsNull()) return nullptr;

        return new OCCTShape(shape);
    } catch (...) {
        return nullptr;
    }
}

int32_t OCCTDocumentNamingGetEvolution(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return -1;

        Handle(TNaming_NamedShape) ns;
        if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns)) return -1;

        switch (ns->Evolution()) {
            case TNaming_PRIMITIVE: return OCCTNamingPrimitive;
            case TNaming_GENERATED: return OCCTNamingGenerated;
            case TNaming_MODIFY: return OCCTNamingModify;
            case TNaming_DELETE: return OCCTNamingDelete;
            case TNaming_SELECTED: return OCCTNamingSelected;
            default: return -1;
        }
    } catch (...) {
        return -1;
    }
}


// ============================================================
// MARK: - TDF Label Properties (v0.54.0)

#include <TDF_ChildIterator.hxx>
#include <TDF_AttributeIterator.hxx>
#include <TDF_Reference.hxx>
#include <TDF_CopyLabel.hxx>
#include <TDF_TagSource.hxx>
#include <TDocStd_Modified.hxx>

int32_t OCCTDocumentLabelTag(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return -1;
        return label.Tag();
    } catch (...) { return -1; }
}

int32_t OCCTDocumentLabelDepth(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return -1;
        return label.Depth();
    } catch (...) { return -1; }
}

bool OCCTDocumentLabelIsNull(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return true;
    try {
        TDF_Label label = doc->getLabel(labelId);
        return label.IsNull();
    } catch (...) { return true; }
}

bool OCCTDocumentLabelIsRoot(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        return label.IsRoot();
    } catch (...) { return false; }
}

int64_t OCCTDocumentLabelFather(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull() || label.IsRoot()) return -1;
        TDF_Label father = label.Father();
        if (father.IsNull()) return -1;
        return doc->registerLabel(father);
    } catch (...) { return -1; }
}

int64_t OCCTDocumentLabelRoot(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return -1;
        TDF_Label root = label.Root();
        if (root.IsNull()) return -1;
        return doc->registerLabel(root);
    } catch (...) { return -1; }
}

bool OCCTDocumentLabelHasAttribute(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        return label.HasAttribute();
    } catch (...) { return false; }
}

int32_t OCCTDocumentLabelNbAttributes(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return 0;
        return label.NbAttributes();
    } catch (...) { return 0; }
}

bool OCCTDocumentLabelHasChild(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        return label.HasChild();
    } catch (...) { return false; }
}

int32_t OCCTDocumentLabelNbChildren(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return 0;
        return label.NbChildren();
    } catch (...) { return 0; }
}

int64_t OCCTDocumentLabelFindChild(OCCTDocumentRef doc, int64_t labelId, int32_t tag, bool create) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return -1;
        TDF_Label child = label.FindChild(tag, create);
        if (child.IsNull()) return -1;
        return doc->registerLabel(child);
    } catch (...) { return -1; }
}

void OCCTDocumentLabelForgetAllAttributes(OCCTDocumentRef doc, int64_t labelId, bool clearChildren) {
    if (!doc || doc->doc.IsNull()) return;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return;
        label.ForgetAllAttributes(clearChildren);
    } catch (...) {}
}

int32_t OCCTDocumentGetDescendantLabels(OCCTDocumentRef doc, int64_t labelId,
                                         bool allLevels,
                                         int64_t* outLabelIds, int32_t maxCount) {
    if (!doc || doc->doc.IsNull() || !outLabelIds || maxCount <= 0) return 0;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return 0;
        int32_t count = 0;
        for (TDF_ChildIterator it(label, allLevels); it.More() && count < maxCount; it.Next()) {
            outLabelIds[count] = doc->registerLabel(it.Value());
            count++;
        }
        return count;
    } catch (...) { return 0; }
}

// MARK: - TDF Label Name (v0.54.0)

bool OCCTDocumentSetLabelName(OCCTDocumentRef doc, int64_t labelId, const char* name) {
    if (!doc || doc->doc.IsNull() || !name) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        TDataStd_Name::Set(label, TCollection_ExtendedString(name, true));
        return true;
    } catch (...) { return false; }
}

// MARK: - TDF Reference (v0.54.0)

bool OCCTDocumentLabelSetReference(OCCTDocumentRef doc, int64_t labelId, int64_t targetLabelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        TDF_Label target = doc->getLabel(targetLabelId);
        if (label.IsNull() || target.IsNull()) return false;
        TDF_Reference::Set(label, target);
        return true;
    } catch (...) { return false; }
}

int64_t OCCTDocumentLabelGetReference(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return -1;
        Handle(TDF_Reference) ref;
        if (!label.FindAttribute(TDF_Reference::GetID(), ref)) return -1;
        TDF_Label target = ref->Get();
        if (target.IsNull()) return -1;
        return doc->registerLabel(target);
    } catch (...) { return -1; }
}

// MARK: - TDF CopyLabel (v0.54.0)

bool OCCTDocumentCopyLabel(OCCTDocumentRef doc, int64_t sourceLabelId, int64_t destLabelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label source = doc->getLabel(sourceLabelId);
        TDF_Label dest = doc->getLabel(destLabelId);
        if (source.IsNull() || dest.IsNull()) return false;
        TDF_CopyLabel copier(source, dest);
        copier.Perform();
        return copier.IsDone();
    } catch (...) { return false; }
}

// MARK: - Document Main Label (v0.54.0)

int64_t OCCTDocumentGetMainLabel(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label main = doc->doc->Main();
        if (main.IsNull()) return -1;
        return doc->registerLabel(main);
    } catch (...) { return -1; }
}

// MARK: - Document Transactions (v0.54.0)

void OCCTDocumentOpenTransaction(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return;
    try {
        doc->doc->OpenCommand();
    } catch (...) {}
}

bool OCCTDocumentCommitTransaction(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        return doc->doc->CommitCommand();
    } catch (...) { return false; }
}

void OCCTDocumentAbortTransaction(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return;
    try {
        doc->doc->AbortCommand();
    } catch (...) {}
}

bool OCCTDocumentHasOpenTransaction(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        return doc->doc->HasOpenCommand();
    } catch (...) { return false; }
}

// MARK: - Document Undo/Redo (v0.54.0)

void OCCTDocumentSetUndoLimit(OCCTDocumentRef doc, int32_t limit) {
    if (!doc || doc->doc.IsNull()) return;
    try {
        doc->doc->SetUndoLimit(limit);
    } catch (...) {}
}

int32_t OCCTDocumentGetUndoLimit(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        return doc->doc->GetUndoLimit();
    } catch (...) { return 0; }
}

bool OCCTDocumentUndo(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        return doc->doc->Undo();
    } catch (...) { return false; }
}

bool OCCTDocumentRedo(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        return doc->doc->Redo();
    } catch (...) { return false; }
}

int32_t OCCTDocumentGetAvailableUndos(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        return doc->doc->GetAvailableUndos();
    } catch (...) { return 0; }
}

int32_t OCCTDocumentGetAvailableRedos(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        return doc->doc->GetAvailableRedos();
    } catch (...) { return 0; }
}

// MARK: - Document Modified Labels (v0.54.0)

void OCCTDocumentSetModified(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return;
        doc->doc->SetModified(label);
    } catch (...) {}
}

void OCCTDocumentClearModified(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return;
    try {
        doc->doc->PurgeModified();
    } catch (...) {}
}

bool OCCTDocumentIsLabelModified(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        const auto& modified = doc->doc->GetModified();
        return modified.Contains(label);
    } catch (...) { return false; }
}

// MARK: - TDataStd Scalar Attributes (v0.55.0)

#include <TDataStd_Integer.hxx>
#include <TDataStd_Real.hxx>
#include <TDataStd_AsciiString.hxx>
#include <TDataStd_Comment.hxx>
#include <TDataStd_IntegerArray.hxx>
#include <TDataStd_RealArray.hxx>
#include <TDataStd_TreeNode.hxx>
#include <TDataStd_NamedData.hxx>

bool OCCTDocumentSetIntegerAttr(OCCTDocumentRef doc, int64_t labelId, int32_t value) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        TDataStd_Integer::Set(label, value);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentGetIntegerAttr(OCCTDocumentRef doc, int64_t labelId, int32_t* outValue) {
    if (!doc || doc->doc.IsNull() || !outValue) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TDataStd_Integer) attr;
        if (!label.FindAttribute(TDataStd_Integer::GetID(), attr)) return false;
        *outValue = attr->Get();
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentSetRealAttr(OCCTDocumentRef doc, int64_t labelId, double value) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        TDataStd_Real::Set(label, value);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentGetRealAttr(OCCTDocumentRef doc, int64_t labelId, double* outValue) {
    if (!doc || doc->doc.IsNull() || !outValue) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TDataStd_Real) attr;
        if (!label.FindAttribute(TDataStd_Real::GetID(), attr)) return false;
        *outValue = attr->Get();
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentSetAsciiStringAttr(OCCTDocumentRef doc, int64_t labelId, const char* value) {
    if (!doc || doc->doc.IsNull() || !value) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        TDataStd_AsciiString::Set(label, TCollection_AsciiString(value));
        return true;
    } catch (...) { return false; }
}

const char* OCCTDocumentGetAsciiStringAttr(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return nullptr;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;
        Handle(TDataStd_AsciiString) attr;
        if (!label.FindAttribute(TDataStd_AsciiString::GetID(), attr)) return nullptr;
        return strdup(attr->Get().ToCString());
    } catch (...) { return nullptr; }
}

bool OCCTDocumentSetCommentAttr(OCCTDocumentRef doc, int64_t labelId, const char* value) {
    if (!doc || doc->doc.IsNull() || !value) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        TDataStd_Comment::Set(label, TCollection_ExtendedString(value, true));
        return true;
    } catch (...) { return false; }
}

const char* OCCTDocumentGetCommentAttr(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return nullptr;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;
        Handle(TDataStd_Comment) attr;
        if (!label.FindAttribute(TDataStd_Comment::GetID(), attr)) return nullptr;
        TCollection_AsciiString ascii(attr->Get());
        return strdup(ascii.ToCString());
    } catch (...) { return nullptr; }
}

// MARK: - TDataStd Integer Array (v0.55.0)

bool OCCTDocumentInitIntegerArray(OCCTDocumentRef doc, int64_t labelId, int32_t lower, int32_t upper) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        TDataStd_IntegerArray::Set(label, lower, upper);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentSetIntegerArrayValue(OCCTDocumentRef doc, int64_t labelId, int32_t index, int32_t value) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TDataStd_IntegerArray) attr;
        if (!label.FindAttribute(TDataStd_IntegerArray::GetID(), attr)) return false;
        attr->SetValue(index, value);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentGetIntegerArrayValue(OCCTDocumentRef doc, int64_t labelId, int32_t index, int32_t* outValue) {
    if (!doc || doc->doc.IsNull() || !outValue) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TDataStd_IntegerArray) attr;
        if (!label.FindAttribute(TDataStd_IntegerArray::GetID(), attr)) return false;
        if (index < attr->Lower() || index > attr->Upper()) return false;
        *outValue = attr->Value(index);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentGetIntegerArrayBounds(OCCTDocumentRef doc, int64_t labelId, int32_t* outLower, int32_t* outUpper) {
    if (!doc || doc->doc.IsNull() || !outLower || !outUpper) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TDataStd_IntegerArray) attr;
        if (!label.FindAttribute(TDataStd_IntegerArray::GetID(), attr)) return false;
        *outLower = attr->Lower();
        *outUpper = attr->Upper();
        return true;
    } catch (...) { return false; }
}

// MARK: - TDataStd Real Array (v0.55.0)

bool OCCTDocumentInitRealArray(OCCTDocumentRef doc, int64_t labelId, int32_t lower, int32_t upper) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        TDataStd_RealArray::Set(label, lower, upper);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentSetRealArrayValue(OCCTDocumentRef doc, int64_t labelId, int32_t index, double value) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TDataStd_RealArray) attr;
        if (!label.FindAttribute(TDataStd_RealArray::GetID(), attr)) return false;
        attr->SetValue(index, value);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentGetRealArrayValue(OCCTDocumentRef doc, int64_t labelId, int32_t index, double* outValue) {
    if (!doc || doc->doc.IsNull() || !outValue) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TDataStd_RealArray) attr;
        if (!label.FindAttribute(TDataStd_RealArray::GetID(), attr)) return false;
        if (index < attr->Lower() || index > attr->Upper()) return false;
        *outValue = attr->Value(index);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentGetRealArrayBounds(OCCTDocumentRef doc, int64_t labelId, int32_t* outLower, int32_t* outUpper) {
    if (!doc || doc->doc.IsNull() || !outLower || !outUpper) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TDataStd_RealArray) attr;
        if (!label.FindAttribute(TDataStd_RealArray::GetID(), attr)) return false;
        *outLower = attr->Lower();
        *outUpper = attr->Upper();
        return true;
    } catch (...) { return false; }
}

// MARK: - TDataStd TreeNode (v0.55.0)

bool OCCTDocumentSetTreeNode(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        TDataStd_TreeNode::Set(label);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentAppendTreeChild(OCCTDocumentRef doc, int64_t parentLabelId, int64_t childLabelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label parentLabel = doc->getLabel(parentLabelId);
        TDF_Label childLabel = doc->getLabel(childLabelId);
        if (parentLabel.IsNull() || childLabel.IsNull()) return false;
        Handle(TDataStd_TreeNode) parentNode, childNode;
        if (!parentLabel.FindAttribute(TDataStd_TreeNode::GetDefaultTreeID(), parentNode)) return false;
        if (!childLabel.FindAttribute(TDataStd_TreeNode::GetDefaultTreeID(), childNode)) return false;
        return parentNode->Append(childNode);
    } catch (...) { return false; }
}

int64_t OCCTDocumentTreeNodeFather(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return -1;
        Handle(TDataStd_TreeNode) node;
        if (!label.FindAttribute(TDataStd_TreeNode::GetDefaultTreeID(), node)) return -1;
        if (!node->HasFather()) return -1;
        return doc->registerLabel(node->Father()->Label());
    } catch (...) { return -1; }
}

int64_t OCCTDocumentTreeNodeFirst(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return -1;
        Handle(TDataStd_TreeNode) node;
        if (!label.FindAttribute(TDataStd_TreeNode::GetDefaultTreeID(), node)) return -1;
        if (!node->HasFirst()) return -1;
        return doc->registerLabel(node->First()->Label());
    } catch (...) { return -1; }
}

int64_t OCCTDocumentTreeNodeNext(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return -1;
        Handle(TDataStd_TreeNode) node;
        if (!label.FindAttribute(TDataStd_TreeNode::GetDefaultTreeID(), node)) return -1;
        if (!node->HasNext()) return -1;
        return doc->registerLabel(node->Next()->Label());
    } catch (...) { return -1; }
}

bool OCCTDocumentTreeNodeHasFather(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TDataStd_TreeNode) node;
        if (!label.FindAttribute(TDataStd_TreeNode::GetDefaultTreeID(), node)) return false;
        return node->HasFather();
    } catch (...) { return false; }
}

int32_t OCCTDocumentTreeNodeDepth(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return -1;
        Handle(TDataStd_TreeNode) node;
        if (!label.FindAttribute(TDataStd_TreeNode::GetDefaultTreeID(), node)) return -1;
        return node->Depth();
    } catch (...) { return -1; }
}

int32_t OCCTDocumentTreeNodeNbChildren(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return 0;
        Handle(TDataStd_TreeNode) node;
        if (!label.FindAttribute(TDataStd_TreeNode::GetDefaultTreeID(), node)) return 0;
        return node->NbChildren();
    } catch (...) { return 0; }
}

// MARK: - TDataStd NamedData (v0.55.0)

static Handle(TDataStd_NamedData) getOrCreateNamedData(OCCTDocumentRef doc, int64_t labelId) {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull()) return nullptr;
    Handle(TDataStd_NamedData) nd;
    if (!label.FindAttribute(TDataStd_NamedData::GetID(), nd)) {
        nd = TDataStd_NamedData::Set(label);
    }
    return nd;
}

static Handle(TDataStd_NamedData) findNamedData(OCCTDocumentRef doc, int64_t labelId) {
    TDF_Label label = doc->getLabel(labelId);
    if (label.IsNull()) return nullptr;
    Handle(TDataStd_NamedData) nd;
    label.FindAttribute(TDataStd_NamedData::GetID(), nd);
    return nd;
}

bool OCCTDocumentNamedDataSetInteger(OCCTDocumentRef doc, int64_t labelId, const char* name, int32_t value) {
    if (!doc || doc->doc.IsNull() || !name) return false;
    try {
        auto nd = getOrCreateNamedData(doc, labelId);
        if (nd.IsNull()) return false;
        nd->SetInteger(TCollection_AsciiString(name), value);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentNamedDataGetInteger(OCCTDocumentRef doc, int64_t labelId, const char* name, int32_t* outValue) {
    if (!doc || doc->doc.IsNull() || !name || !outValue) return false;
    try {
        auto nd = findNamedData(doc, labelId);
        if (nd.IsNull()) return false;
        TCollection_AsciiString key(name);
        if (!nd->HasInteger(key)) return false;
        *outValue = nd->GetInteger(key);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentNamedDataHasInteger(OCCTDocumentRef doc, int64_t labelId, const char* name) {
    if (!doc || doc->doc.IsNull() || !name) return false;
    try {
        auto nd = findNamedData(doc, labelId);
        if (nd.IsNull()) return false;
        return nd->HasInteger(TCollection_AsciiString(name));
    } catch (...) { return false; }
}

bool OCCTDocumentNamedDataSetReal(OCCTDocumentRef doc, int64_t labelId, const char* name, double value) {
    if (!doc || doc->doc.IsNull() || !name) return false;
    try {
        auto nd = getOrCreateNamedData(doc, labelId);
        if (nd.IsNull()) return false;
        nd->SetReal(TCollection_AsciiString(name), value);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentNamedDataGetReal(OCCTDocumentRef doc, int64_t labelId, const char* name, double* outValue) {
    if (!doc || doc->doc.IsNull() || !name || !outValue) return false;
    try {
        auto nd = findNamedData(doc, labelId);
        if (nd.IsNull()) return false;
        TCollection_AsciiString key(name);
        if (!nd->HasReal(key)) return false;
        *outValue = nd->GetReal(key);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentNamedDataHasReal(OCCTDocumentRef doc, int64_t labelId, const char* name) {
    if (!doc || doc->doc.IsNull() || !name) return false;
    try {
        auto nd = findNamedData(doc, labelId);
        if (nd.IsNull()) return false;
        return nd->HasReal(TCollection_AsciiString(name));
    } catch (...) { return false; }
}

bool OCCTDocumentNamedDataSetString(OCCTDocumentRef doc, int64_t labelId, const char* name, const char* value) {
    if (!doc || doc->doc.IsNull() || !name || !value) return false;
    try {
        auto nd = getOrCreateNamedData(doc, labelId);
        if (nd.IsNull()) return false;
        nd->SetString(TCollection_AsciiString(name), TCollection_ExtendedString(value, true));
        return true;
    } catch (...) { return false; }
}

const char* OCCTDocumentNamedDataGetString(OCCTDocumentRef doc, int64_t labelId, const char* name) {
    if (!doc || doc->doc.IsNull() || !name) return nullptr;
    try {
        auto nd = findNamedData(doc, labelId);
        if (nd.IsNull()) return nullptr;
        TCollection_AsciiString key(name);
        if (!nd->HasString(key)) return nullptr;
        TCollection_AsciiString ascii(nd->GetString(key));
        return strdup(ascii.ToCString());
    } catch (...) { return nullptr; }
}

bool OCCTDocumentNamedDataHasString(OCCTDocumentRef doc, int64_t labelId, const char* name) {
    if (!doc || doc->doc.IsNull() || !name) return false;
    try {
        auto nd = findNamedData(doc, labelId);
        if (nd.IsNull()) return false;
        return nd->HasString(TCollection_AsciiString(name));
    } catch (...) { return false; }
}

// MARK: - TDataXtd Shape Attribute (v0.56.0)

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

bool OCCTDocumentSetShapeAttr(OCCTDocumentRef doc, int64_t labelId, OCCTShapeRef shape) {
    if (!doc || doc->doc.IsNull() || !shape) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        // TDataXtd_Shape::New requires an empty label, so use TNaming_Builder directly
        // to store the shape, which is what Set() does internally anyway
        Handle(TDataXtd_Shape) attr;
        if (!label.FindAttribute(TDataXtd_Shape::GetID(), attr)) {
            attr = new TDataXtd_Shape();
            label.AddAttribute(attr);
        }
        TNaming_Builder builder(label);
        builder.Generated(shape->shape);
        return true;
    } catch (...) { return false; }
}

OCCTShapeRef OCCTDocumentGetShapeAttr(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return nullptr;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;
        Handle(TDataXtd_Shape) attr;
        if (!label.FindAttribute(TDataXtd_Shape::GetID(), attr)) return nullptr;
        TopoDS_Shape shape = TDataXtd_Shape::Get(label);
        if (shape.IsNull()) return nullptr;
        return new OCCTShape(shape);
    } catch (...) { return nullptr; }
}

bool OCCTDocumentHasShapeAttr(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TDataXtd_Shape) attr;
        return label.FindAttribute(TDataXtd_Shape::GetID(), attr);
    } catch (...) { return false; }
}

// MARK: - TDataXtd Position Attribute (v0.56.0)

bool OCCTDocumentSetPositionAttr(OCCTDocumentRef doc, int64_t labelId, double x, double y, double z) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        TDataXtd_Position::Set(label, gp_Pnt(x, y, z));
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentGetPositionAttr(OCCTDocumentRef doc, int64_t labelId, double* outX, double* outY, double* outZ) {
    if (!doc || doc->doc.IsNull() || !outX || !outY || !outZ) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        gp_Pnt pos;
        if (!TDataXtd_Position::Get(label, pos)) return false;
        *outX = pos.X();
        *outY = pos.Y();
        *outZ = pos.Z();
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentHasPositionAttr(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        gp_Pnt pos;
        return TDataXtd_Position::Get(label, pos);
    } catch (...) { return false; }
}

// MARK: - TDataXtd Geometry Attribute (v0.56.0)

bool OCCTDocumentSetGeometryAttr(OCCTDocumentRef doc, int64_t labelId, int32_t geometryType) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TDataXtd_Geometry) geom = TDataXtd_Geometry::Set(label);
        if (geom.IsNull()) return false;
        geom->SetType(static_cast<TDataXtd_GeometryEnum>(geometryType));
        return true;
    } catch (...) { return false; }
}

int32_t OCCTDocumentGetGeometryType(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return -1;
        Handle(TDataXtd_Geometry) geom;
        if (!label.FindAttribute(TDataXtd_Geometry::GetID(), geom)) return -1;
        return static_cast<int32_t>(geom->GetType());
    } catch (...) { return -1; }
}

bool OCCTDocumentHasGeometryAttr(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TDataXtd_Geometry) geom;
        return label.FindAttribute(TDataXtd_Geometry::GetID(), geom);
    } catch (...) { return false; }
}

// MARK: - TDataXtd Triangulation Attribute (v0.56.0)

bool OCCTDocumentSetTriangulationFromShape(OCCTDocumentRef doc, int64_t labelId, OCCTShapeRef shape, double deflection) {
    if (!doc || doc->doc.IsNull() || !shape) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;

        // Mesh the shape
        BRepMesh_IncrementalMesh mesher(shape->shape, deflection);

        // Get triangulation from first face
        TopExp_Explorer exp(shape->shape, TopAbs_FACE);
        if (!exp.More()) return false;
        TopoDS_Face face = TopoDS::Face(exp.Current());
        TopLoc_Location loc;
        Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(face, loc);
        if (tri.IsNull()) return false;

        Handle(TDataXtd_Triangulation) attr = TDataXtd_Triangulation::Set(label, tri);
        return !attr.IsNull();
    } catch (...) { return false; }
}

int32_t OCCTDocumentTriangulationNbNodes(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return 0;
        Handle(TDataXtd_Triangulation) attr;
        if (!label.FindAttribute(TDataXtd_Triangulation::GetID(), attr)) return 0;
        return attr->NbNodes();
    } catch (...) { return 0; }
}

int32_t OCCTDocumentTriangulationNbTriangles(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return 0;
        Handle(TDataXtd_Triangulation) attr;
        if (!label.FindAttribute(TDataXtd_Triangulation::GetID(), attr)) return 0;
        return attr->NbTriangles();
    } catch (...) { return 0; }
}

double OCCTDocumentTriangulationDeflection(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return 0.0;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return 0.0;
        Handle(TDataXtd_Triangulation) attr;
        if (!label.FindAttribute(TDataXtd_Triangulation::GetID(), attr)) return 0.0;
        return attr->Deflection();
    } catch (...) { return 0.0; }
}

// MARK: - TDataXtd Point/Axis/Plane (v0.56.0)

bool OCCTDocumentSetPointAttr(OCCTDocumentRef doc, int64_t labelId, double x, double y, double z) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TDataXtd_Point) attr = TDataXtd_Point::Set(label, gp_Pnt(x, y, z));
        return !attr.IsNull();
    } catch (...) { return false; }
}

bool OCCTDocumentSetAxisAttr(OCCTDocumentRef doc, int64_t labelId, double ox, double oy, double oz, double dx, double dy, double dz) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        gp_Lin line(gp_Pnt(ox, oy, oz), gp_Dir(dx, dy, dz));
        Handle(TDataXtd_Axis) attr = TDataXtd_Axis::Set(label, line);
        return !attr.IsNull();
    } catch (...) { return false; }
}

bool OCCTDocumentSetPlaneAttr(OCCTDocumentRef doc, int64_t labelId, double ox, double oy, double oz, double nx, double ny, double nz) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        gp_Pln plane(gp_Pnt(ox, oy, oz), gp_Dir(nx, ny, nz));
        Handle(TDataXtd_Plane) attr = TDataXtd_Plane::Set(label, plane);
        return !attr.IsNull();
    } catch (...) { return false; }
}

// MARK: - TFunction Logbook (v0.56.0)

bool OCCTDocumentSetLogbook(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TFunction_Logbook) logbook = TFunction_Logbook::Set(label);
        return !logbook.IsNull();
    } catch (...) { return false; }
}

bool OCCTDocumentLogbookSetTouched(OCCTDocumentRef doc, int64_t logbookLabelId, int64_t targetLabelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label logLabel = doc->getLabel(logbookLabelId);
        if (logLabel.IsNull()) return false;
        // TFunction_Logbook::Set places logbook on root, so find it there
        Handle(TFunction_Logbook) logbook;
        if (!logLabel.Root().FindAttribute(TFunction_Logbook::GetID(), logbook)) return false;
        TDF_Label target = doc->getLabel(targetLabelId);
        if (target.IsNull()) return false;
        logbook->SetTouched(target);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentLogbookSetImpacted(OCCTDocumentRef doc, int64_t logbookLabelId, int64_t targetLabelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label logLabel = doc->getLabel(logbookLabelId);
        if (logLabel.IsNull()) return false;
        Handle(TFunction_Logbook) logbook;
        if (!logLabel.Root().FindAttribute(TFunction_Logbook::GetID(), logbook)) return false;
        TDF_Label target = doc->getLabel(targetLabelId);
        if (target.IsNull()) return false;
        logbook->SetImpacted(target);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentLogbookIsModified(OCCTDocumentRef doc, int64_t logbookLabelId, int64_t targetLabelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label logLabel = doc->getLabel(logbookLabelId);
        if (logLabel.IsNull()) return false;
        Handle(TFunction_Logbook) logbook;
        if (!logLabel.Root().FindAttribute(TFunction_Logbook::GetID(), logbook)) return false;
        TDF_Label target = doc->getLabel(targetLabelId);
        if (target.IsNull()) return false;
        return logbook->IsModified(target);
    } catch (...) { return false; }
}

bool OCCTDocumentLogbookClear(OCCTDocumentRef doc, int64_t logbookLabelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label logLabel = doc->getLabel(logbookLabelId);
        if (logLabel.IsNull()) return false;
        Handle(TFunction_Logbook) logbook;
        if (!logLabel.Root().FindAttribute(TFunction_Logbook::GetID(), logbook)) return false;
        logbook->Clear();
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentLogbookIsEmpty(OCCTDocumentRef doc, int64_t logbookLabelId) {
    if (!doc || doc->doc.IsNull()) return true;
    try {
        TDF_Label logLabel = doc->getLabel(logbookLabelId);
        if (logLabel.IsNull()) return true;
        Handle(TFunction_Logbook) logbook;
        if (!logLabel.Root().FindAttribute(TFunction_Logbook::GetID(), logbook)) return true;
        return logbook->IsEmpty();
    } catch (...) { return true; }
}

// MARK: - TFunction GraphNode (v0.56.0)

bool OCCTDocumentSetGraphNode(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TFunction_GraphNode) node = TFunction_GraphNode::Set(label);
        return !node.IsNull();
    } catch (...) { return false; }
}

bool OCCTDocumentGraphNodeAddPrevious(OCCTDocumentRef doc, int64_t labelId, int32_t prevTag) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TFunction_GraphNode) node;
        if (!label.FindAttribute(TFunction_GraphNode::GetID(), node)) return false;
        return node->AddPrevious(prevTag);
    } catch (...) { return false; }
}

bool OCCTDocumentGraphNodeAddNext(OCCTDocumentRef doc, int64_t labelId, int32_t nextTag) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TFunction_GraphNode) node;
        if (!label.FindAttribute(TFunction_GraphNode::GetID(), node)) return false;
        return node->AddNext(nextTag);
    } catch (...) { return false; }
}

bool OCCTDocumentGraphNodeSetStatus(OCCTDocumentRef doc, int64_t labelId, int32_t status) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TFunction_GraphNode) node;
        if (!label.FindAttribute(TFunction_GraphNode::GetID(), node)) return false;
        node->SetStatus(static_cast<TFunction_ExecutionStatus>(status));
        return true;
    } catch (...) { return false; }
}

int32_t OCCTDocumentGraphNodeGetStatus(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return -1;
        Handle(TFunction_GraphNode) node;
        if (!label.FindAttribute(TFunction_GraphNode::GetID(), node)) return -1;
        return static_cast<int32_t>(node->GetStatus());
    } catch (...) { return -1; }
}

bool OCCTDocumentGraphNodeRemoveAllPrevious(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TFunction_GraphNode) node;
        if (!label.FindAttribute(TFunction_GraphNode::GetID(), node)) return false;
        node->RemoveAllPrevious();
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentGraphNodeRemoveAllNext(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TFunction_GraphNode) node;
        if (!label.FindAttribute(TFunction_GraphNode::GetID(), node)) return false;
        node->RemoveAllNext();
        return true;
    } catch (...) { return false; }
}

// MARK: - TFunction Function Attribute (v0.56.0)

bool OCCTDocumentSetFunctionAttr(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TFunction_Function) func = TFunction_Function::Set(label);
        return !func.IsNull();
    } catch (...) { return false; }
}

bool OCCTDocumentFunctionIsFailed(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TFunction_Function) func;
        if (!label.FindAttribute(TFunction_Function::GetID(), func)) return false;
        return func->Failed();
    } catch (...) { return false; }
}

int32_t OCCTDocumentFunctionGetFailure(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return -1;
        Handle(TFunction_Function) func;
        if (!label.FindAttribute(TFunction_Function::GetID(), func)) return -1;
        return func->GetFailure();
    } catch (...) { return -1; }
}

bool OCCTDocumentFunctionSetFailure(OCCTDocumentRef doc, int64_t labelId, int32_t mode) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TFunction_Function) func;
        if (!label.FindAttribute(TFunction_Function::GetID(), func)) return false;
        func->SetFailure(mode);
        return true;
    } catch (...) { return false; }
}

// MARK: - TNaming CopyShape (v0.56.0)

// MARK: - OCAF Persistence (v0.57.0)

#include <BinDrivers.hxx>
#include <BinLDrivers.hxx>
#include <XmlDrivers.hxx>
#include <XmlLDrivers.hxx>
#include <BinXCAFDrivers.hxx>
#include <XmlXCAFDrivers.hxx>
#include <PCDM_StoreStatus.hxx>
#include <PCDM_ReaderStatus.hxx>
#include <NCollection_Sequence.hxx>

void OCCTDocumentDefineFormatBin(OCCTDocumentRef doc) {
    if (!doc || doc->app.IsNull()) return;
    try { BinDrivers::DefineFormat(doc->app); } catch (...) {}
}

void OCCTDocumentDefineFormatBinL(OCCTDocumentRef doc) {
    if (!doc || doc->app.IsNull()) return;
    try { BinLDrivers::DefineFormat(doc->app); } catch (...) {}
}

void OCCTDocumentDefineFormatXml(OCCTDocumentRef doc) {
    if (!doc || doc->app.IsNull()) return;
    try { XmlDrivers::DefineFormat(doc->app); } catch (...) {}
}

void OCCTDocumentDefineFormatXmlL(OCCTDocumentRef doc) {
    if (!doc || doc->app.IsNull()) return;
    try { XmlLDrivers::DefineFormat(doc->app); } catch (...) {}
}

void OCCTDocumentDefineFormatBinXCAF(OCCTDocumentRef doc) {
    if (!doc || doc->app.IsNull()) return;
    try { BinXCAFDrivers::DefineFormat(doc->app); } catch (...) {}
}

void OCCTDocumentDefineFormatXmlXCAF(OCCTDocumentRef doc) {
    if (!doc || doc->app.IsNull()) return;
    try { XmlXCAFDrivers::DefineFormat(doc->app); } catch (...) {}
}

int32_t OCCTDocumentSaveOCAF(OCCTDocumentRef doc, const char* path) {
    if (!doc || doc->doc.IsNull() || !path) return -1;
    try {
        TCollection_ExtendedString ePath(path, true);
        PCDM_StoreStatus status = doc->app->SaveAs(doc->doc, ePath);
        return static_cast<int32_t>(status);
    } catch (...) { return -1; }
}

OCCTDocumentRef OCCTDocumentLoadOCAF(const char* path, int32_t* outStatus) {
    if (!path) { if (outStatus) *outStatus = -1; return nullptr; }
    try {
        Handle(XCAFApp_Application) app = XCAFApp_Application::GetApplication();

        // Register all format drivers
        BinDrivers::DefineFormat(app);
        XmlDrivers::DefineFormat(app);
        BinXCAFDrivers::DefineFormat(app);
        XmlXCAFDrivers::DefineFormat(app);

        Handle(TDocStd_Document) loadedDoc;
        TCollection_ExtendedString ePath(path, true);
        PCDM_ReaderStatus status = app->Open(ePath, loadedDoc);

        // If already retrieved, find and close existing doc, then re-open
        if (status == PCDM_RS_AlreadyRetrieved || status == PCDM_RS_AlreadyRetrievedAndModified) {
            // Find the existing document in the application session
            int nbDocs = app->NbDocuments();
            for (int i = 1; i <= nbDocs; i++) {
                Handle(TDocStd_Document) existingDoc;
                app->GetDocument(i, existingDoc);
                if (!existingDoc.IsNull() && existingDoc->IsSaved()) {
                    // Close it
                    try { app->Close(existingDoc); } catch (...) {}
                    break;
                }
            }
            loadedDoc.Nullify();
            status = app->Open(ePath, loadedDoc);
        }

        if (outStatus) *outStatus = static_cast<int32_t>(status);

        if (status != PCDM_RS_OK || loadedDoc.IsNull()) return nullptr;

        OCCTDocument* document = new OCCTDocument();
        document->doc = loadedDoc;
        document->shapeTool = XCAFDoc_DocumentTool::ShapeTool(loadedDoc->Main());
        document->colorTool = XCAFDoc_DocumentTool::ColorTool(loadedDoc->Main());
        document->materialTool = XCAFDoc_DocumentTool::VisMaterialTool(loadedDoc->Main());

        return document;
    } catch (...) {
        if (outStatus) *outStatus = -1;
        return nullptr;
    }
}

int32_t OCCTDocumentSaveOCAFInPlace(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        if (!doc->doc->IsSaved()) return -1;
        PCDM_StoreStatus status = doc->app->Save(doc->doc);
        return static_cast<int32_t>(status);
    } catch (...) { return -1; }
}

bool OCCTDocumentIsSaved(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return false;
    try { return doc->doc->IsSaved(); } catch (...) { return false; }
}

const char* OCCTDocumentGetStorageFormat(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return nullptr;
    try {
        TCollection_AsciiString ascii(doc->doc->StorageFormat());
        return strdup(ascii.ToCString());
    } catch (...) { return nullptr; }
}

bool OCCTDocumentSetStorageFormat(OCCTDocumentRef doc, const char* format) {
    if (!doc || doc->doc.IsNull() || !format) return false;
    try {
        doc->doc->ChangeStorageFormat(TCollection_ExtendedString(format, true));
        return true;
    } catch (...) { return false; }
}

int32_t OCCTDocumentNbDocuments(OCCTDocumentRef doc) {
    if (!doc || doc->app.IsNull()) return 0;
    try { return doc->app->NbDocuments(); } catch (...) { return 0; }
}

int32_t OCCTDocumentReadingFormats(OCCTDocumentRef doc, const char** outFormats, int32_t maxFormats) {
    if (!doc || doc->app.IsNull() || !outFormats || maxFormats <= 0) return 0;
    try {
        NCollection_Sequence<TCollection_AsciiString> formats;
        doc->app->ReadingFormats(formats);
        int32_t count = std::min((int32_t)formats.Length(), maxFormats);
        for (int32_t i = 0; i < count; i++) {
            outFormats[i] = strdup(formats.Value(i + 1).ToCString());
        }
        return count;
    } catch (...) { return 0; }
}

int32_t OCCTDocumentWritingFormats(OCCTDocumentRef doc, const char** outFormats, int32_t maxFormats) {
    if (!doc || doc->app.IsNull() || !outFormats || maxFormats <= 0) return 0;
    try {
        NCollection_Sequence<TCollection_AsciiString> formats;
        doc->app->WritingFormats(formats);
        int32_t count = std::min((int32_t)formats.Length(), maxFormats);
        for (int32_t i = 0; i < count; i++) {
            outFormats[i] = strdup(formats.Value(i + 1).ToCString());
        }
        return count;
    } catch (...) { return 0; }
}

OCCTDocumentRef OCCTDocumentCreateWithFormat(const char* format) {
    if (!format) return nullptr;
    try {
        OCCTDocument* document = new OCCTDocument();
        TCollection_ExtendedString eFormat(format, true);

        // Register all format drivers
        BinDrivers::DefineFormat(document->app);
        XmlDrivers::DefineFormat(document->app);
        BinXCAFDrivers::DefineFormat(document->app);
        XmlXCAFDrivers::DefineFormat(document->app);

        document->app->NewDocument(eFormat, document->doc);
        if (document->doc.IsNull()) {
            delete document;
            return nullptr;
        }

        // Initialize XCAF tools if format is XCAF
        TCollection_AsciiString asciiFormat(format);
        if (asciiFormat.Search("XCAF") >= 0 || asciiFormat.Search("xcaf") >= 0) {
            document->shapeTool = XCAFDoc_DocumentTool::ShapeTool(document->doc->Main());
            document->colorTool = XCAFDoc_DocumentTool::ColorTool(document->doc->Main());
            document->materialTool = XCAFDoc_DocumentTool::VisMaterialTool(document->doc->Main());
        }

        return document;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTShapeDeepCopy(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        if (shape->shape.IsNull()) return nullptr;
        TColStd_IndexedDataMapOfTransientTransient aMap;
        TopoDS_Shape copy;
        TNaming_CopyShape::CopyTool(shape->shape, aMap, copy);
        if (copy.IsNull()) return nullptr;
        return new OCCTShape(copy);
    } catch (...) { return nullptr; }
}

// MARK: - XDE ShapeTool Expansion (v0.60.0)

#include <XCAFDoc_Area.hxx>
#include <XCAFDoc_Volume.hxx>
#include <XCAFDoc_Centroid.hxx>
#include <XCAFDoc_Editor.hxx>
#include <NCollection_HSequence.hxx>

int32_t OCCTDocumentGetShapeCount(OCCTDocumentRef doc) {
    if (!doc || doc->shapeTool.IsNull()) return 0;
    try {
        TDF_LabelSequence shapes;
        doc->shapeTool->GetShapes(shapes);
        return shapes.Length();
    } catch (...) { return 0; }
}

int64_t OCCTDocumentGetShapeLabelId(OCCTDocumentRef doc, int32_t index) {
    if (!doc || doc->shapeTool.IsNull()) return -1;
    try {
        TDF_LabelSequence shapes;
        doc->shapeTool->GetShapes(shapes);
        if (index < 0 || index >= shapes.Length()) return -1;
        return doc->registerLabel(shapes.Value(index + 1));
    } catch (...) { return -1; }
}

int32_t OCCTDocumentGetFreeShapeCount(OCCTDocumentRef doc) {
    if (!doc || doc->shapeTool.IsNull()) return 0;
    try {
        TDF_LabelSequence shapes;
        doc->shapeTool->GetFreeShapes(shapes);
        return shapes.Length();
    } catch (...) { return 0; }
}

int64_t OCCTDocumentGetFreeShapeLabelId(OCCTDocumentRef doc, int32_t index) {
    if (!doc || doc->shapeTool.IsNull()) return -1;
    try {
        TDF_LabelSequence shapes;
        doc->shapeTool->GetFreeShapes(shapes);
        if (index < 0 || index >= shapes.Length()) return -1;
        return doc->registerLabel(shapes.Value(index + 1));
    } catch (...) { return -1; }
}

bool OCCTDocumentIsTopLevel(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->shapeTool.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        return doc->shapeTool->IsTopLevel(label);
    } catch (...) { return false; }
}

bool OCCTDocumentIsComponent(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->shapeTool.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        return doc->shapeTool->IsComponent(label);
    } catch (...) { return false; }
}

bool OCCTDocumentIsCompound(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->shapeTool.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        return doc->shapeTool->IsCompound(label);
    } catch (...) { return false; }
}

bool OCCTDocumentIsSubShape(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->shapeTool.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        return XCAFDoc_ShapeTool::IsSubShape(label);
    } catch (...) { return false; }
}

int64_t OCCTDocumentFindShape(OCCTDocumentRef doc, OCCTShapeRef shape) {
    if (!doc || !shape || doc->shapeTool.IsNull()) return -1;
    try {
        TDF_Label label;
        bool found = doc->shapeTool->FindShape(shape->shape, label);
        if (!found || label.IsNull()) return -1;
        return doc->registerLabel(label);
    } catch (...) { return -1; }
}

int64_t OCCTDocumentSearchShape(OCCTDocumentRef doc, OCCTShapeRef shape) {
    if (!doc || !shape || doc->shapeTool.IsNull()) return -1;
    try {
        TDF_Label label;
        bool found = doc->shapeTool->Search(shape->shape, label);
        if (!found || label.IsNull()) return -1;
        return doc->registerLabel(label);
    } catch (...) { return -1; }
}

int32_t OCCTDocumentGetSubShapeCount(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->shapeTool.IsNull()) return 0;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return 0;
        TDF_LabelSequence subShapes;
        doc->shapeTool->GetSubShapes(label, subShapes);
        return subShapes.Length();
    } catch (...) { return 0; }
}

int64_t OCCTDocumentGetSubShapeLabelId(OCCTDocumentRef doc, int64_t labelId, int32_t index) {
    if (!doc || doc->shapeTool.IsNull()) return -1;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return -1;
        TDF_LabelSequence subShapes;
        doc->shapeTool->GetSubShapes(label, subShapes);
        if (index < 0 || index >= subShapes.Length()) return -1;
        return doc->registerLabel(subShapes.Value(index + 1));
    } catch (...) { return -1; }
}

int64_t OCCTDocumentAddShape(OCCTDocumentRef doc, OCCTShapeRef shape, bool makeAssembly) {
    if (!doc || !shape || doc->shapeTool.IsNull()) return -1;
    try {
        TDF_Label label = doc->shapeTool->AddShape(shape->shape, makeAssembly);
        if (label.IsNull()) return -1;
        return doc->registerLabel(label);
    } catch (...) { return -1; }
}

int64_t OCCTDocumentNewShape(OCCTDocumentRef doc) {
    if (!doc || doc->shapeTool.IsNull()) return -1;
    try {
        TDF_Label label = doc->shapeTool->NewShape();
        if (label.IsNull()) return -1;
        return doc->registerLabel(label);
    } catch (...) { return -1; }
}

bool OCCTDocumentRemoveShape(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->shapeTool.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        return doc->shapeTool->RemoveShape(label);
    } catch (...) { return false; }
}

int64_t OCCTDocumentAddComponent(OCCTDocumentRef doc, int64_t assemblyLabelId,
    int64_t shapeLabelId, double tx, double ty, double tz) {
    if (!doc || doc->shapeTool.IsNull()) return -1;
    try {
        TDF_Label assemblyLabel = doc->getLabel(assemblyLabelId);
        TDF_Label shapeLabel = doc->getLabel(shapeLabelId);
        if (assemblyLabel.IsNull() || shapeLabel.IsNull()) return -1;
        gp_Trsf trsf;
        trsf.SetTranslation(gp_Vec(tx, ty, tz));
        TDF_Label comp = doc->shapeTool->AddComponent(assemblyLabel, shapeLabel, TopLoc_Location(trsf));
        if (comp.IsNull()) return -1;
        return doc->registerLabel(comp);
    } catch (...) { return -1; }
}

int64_t OCCTDocumentAddComponentMatrix(OCCTDocumentRef doc, int64_t assemblyLabelId,
    int64_t shapeLabelId, const double* matrix12) {
    if (!doc || doc->shapeTool.IsNull() || !matrix12) return -1;
    try {
        TDF_Label assemblyLabel = doc->getLabel(assemblyLabelId);
        TDF_Label shapeLabel = doc->getLabel(shapeLabelId);
        if (assemblyLabel.IsNull() || shapeLabel.IsNull()) return -1;
        // Row-major 3x3 rotation + translation; gp_Trsf::SetValues throws if not a proper rigid
        // (orthonormal, det +1) transform — reflections must be baked as a mirrored product (#174).
        gp_Trsf trsf;
        trsf.SetValues(matrix12[0], matrix12[1], matrix12[2], matrix12[9],
                       matrix12[3], matrix12[4], matrix12[5], matrix12[10],
                       matrix12[6], matrix12[7], matrix12[8], matrix12[11]);
        TDF_Label comp = doc->shapeTool->AddComponent(assemblyLabel, shapeLabel, TopLoc_Location(trsf));
        if (comp.IsNull()) return -1;
        return doc->registerLabel(comp);
    } catch (...) { return -1; }
}

void OCCTDocumentRemoveComponent(OCCTDocumentRef doc, int64_t componentLabelId) {
    if (!doc || doc->shapeTool.IsNull()) return;
    try {
        TDF_Label label = doc->getLabel(componentLabelId);
        if (label.IsNull()) return;
        doc->shapeTool->RemoveComponent(label);
    } catch (...) {}
}

int32_t OCCTDocumentGetComponentCount(OCCTDocumentRef doc, int64_t assemblyLabelId) {
    if (!doc || doc->shapeTool.IsNull()) return 0;
    try {
        TDF_Label label = doc->getLabel(assemblyLabelId);
        if (label.IsNull()) return 0;
        TDF_LabelSequence components;
        doc->shapeTool->GetComponents(label, components);
        return components.Length();
    } catch (...) { return 0; }
}

int64_t OCCTDocumentGetComponentLabelId(OCCTDocumentRef doc, int64_t assemblyLabelId, int32_t index) {
    if (!doc || doc->shapeTool.IsNull()) return -1;
    try {
        TDF_Label label = doc->getLabel(assemblyLabelId);
        if (label.IsNull()) return -1;
        TDF_LabelSequence components;
        doc->shapeTool->GetComponents(label, components);
        if (index < 0 || index >= components.Length()) return -1;
        return doc->registerLabel(components.Value(index + 1));
    } catch (...) { return -1; }
}

int64_t OCCTDocumentGetComponentReferredLabelId(OCCTDocumentRef doc, int64_t componentLabelId) {
    if (!doc || doc->shapeTool.IsNull()) return -1;
    try {
        TDF_Label label = doc->getLabel(componentLabelId);
        if (label.IsNull()) return -1;
        TDF_Label referred;
        bool ok = doc->shapeTool->GetReferredShape(label, referred);
        if (!ok || referred.IsNull()) return -1;
        return doc->registerLabel(referred);
    } catch (...) { return -1; }
}

int32_t OCCTDocumentGetShapeUserCount(OCCTDocumentRef doc, int64_t shapeLabelId) {
    if (!doc || doc->shapeTool.IsNull()) return 0;
    try {
        TDF_Label label = doc->getLabel(shapeLabelId);
        if (label.IsNull()) return 0;
        TDF_LabelSequence users;
        return doc->shapeTool->GetUsers(label, users);
    } catch (...) { return 0; }
}

void OCCTDocumentUpdateAssemblies(OCCTDocumentRef doc) {
    if (!doc || doc->shapeTool.IsNull()) return;
    try {
        doc->shapeTool->UpdateAssemblies();
    } catch (...) {}
}

bool OCCTDocumentExpandShape(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->shapeTool.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        return doc->shapeTool->Expand(label);
    } catch (...) { return false; }
}

// MARK: - XDE ColorTool by Shape (v0.60.0)

void OCCTDocumentSetShapeColor(OCCTDocumentRef doc, OCCTShapeRef shape,
    int32_t colorType, double r, double g, double b) {
    if (!doc || !shape || doc->colorTool.IsNull()) return;
    try {
        Quantity_Color color(r, g, b, Quantity_TOC_RGB);
        doc->colorTool->SetColor(shape->shape, color, static_cast<XCAFDoc_ColorType>(colorType));
    } catch (...) {}
}

OCCTColor OCCTDocumentGetShapeColor(OCCTDocumentRef doc, OCCTShapeRef shape, int32_t colorType) {
    OCCTColor result = {0, 0, 0, 1.0, false};
    if (!doc || !shape || doc->colorTool.IsNull()) return result;
    try {
        Quantity_Color color;
        bool hasColor = doc->colorTool->GetColor(shape->shape, static_cast<XCAFDoc_ColorType>(colorType), color);
        if (hasColor) {
            result.r = color.Red();
            result.g = color.Green();
            result.b = color.Blue();
            result.a = 1.0;
            result.isSet = true;
        }
    } catch (...) {}
    return result;
}

bool OCCTDocumentIsShapeColorSet(OCCTDocumentRef doc, OCCTShapeRef shape, int32_t colorType) {
    if (!doc || !shape || doc->colorTool.IsNull()) return false;
    try {
        return doc->colorTool->IsSet(shape->shape, static_cast<XCAFDoc_ColorType>(colorType));
    } catch (...) { return false; }
}

void OCCTDocumentSetLabelVisibility(OCCTDocumentRef doc, int64_t labelId, bool visible) {
    if (!doc || doc->colorTool.IsNull()) return;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return;
        doc->colorTool->SetVisibility(label, visible);
    } catch (...) {}
}

bool OCCTDocumentGetLabelVisibility(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->colorTool.IsNull()) return true;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return true;
        return doc->colorTool->IsVisible(label);
    } catch (...) { return true; }
}

// MARK: - XDE Area / Volume / Centroid (v0.60.0)

void OCCTDocumentSetArea(OCCTDocumentRef doc, int64_t labelId, double area) {
    if (!doc) return;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return;
        XCAFDoc_Area::Set(label, area);
    } catch (...) {}
}

double OCCTDocumentGetArea(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc) return -1;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return -1;
        double area;
        if (XCAFDoc_Area::Get(label, area)) return area;
    } catch (...) {}
    return -1;
}

void OCCTDocumentSetVolume(OCCTDocumentRef doc, int64_t labelId, double volume) {
    if (!doc) return;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return;
        XCAFDoc_Volume::Set(label, volume);
    } catch (...) {}
}

double OCCTDocumentGetVolume(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc) return -1;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return -1;
        double vol;
        if (XCAFDoc_Volume::Get(label, vol)) return vol;
    } catch (...) {}
    return -1;
}

void OCCTDocumentSetCentroid(OCCTDocumentRef doc, int64_t labelId, double x, double y, double z) {
    if (!doc) return;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return;
        XCAFDoc_Centroid::Set(label, gp_Pnt(x, y, z));
    } catch (...) {}
}

bool OCCTDocumentGetCentroid(OCCTDocumentRef doc, int64_t labelId, double* outX, double* outY, double* outZ) {
    if (!doc) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        gp_Pnt centroid;
        if (XCAFDoc_Centroid::Get(label, centroid)) {
            if (outX) *outX = centroid.X();
            if (outY) *outY = centroid.Y();
            if (outZ) *outZ = centroid.Z();
            return true;
        }
    } catch (...) {}
    return false;
}

// MARK: - XDE LayerTool Expansion (v0.60.0)

void OCCTDocumentSetLayer(OCCTDocumentRef doc, int64_t labelId, const char* layerName) {
    if (!doc || !layerName) return;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return;
        Handle(XCAFDoc_LayerTool) layerTool = XCAFDoc_DocumentTool::LayerTool(doc->doc->Main());
        layerTool->SetLayer(label, TCollection_ExtendedString(layerName));
    } catch (...) {}
}

bool OCCTDocumentIsLayerSet(OCCTDocumentRef doc, int64_t labelId, const char* layerName) {
    if (!doc || !layerName) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(XCAFDoc_LayerTool) layerTool = XCAFDoc_DocumentTool::LayerTool(doc->doc->Main());
        return layerTool->IsSet(label, TCollection_ExtendedString(layerName));
    } catch (...) { return false; }
}

int32_t OCCTDocumentGetLabelLayers(OCCTDocumentRef doc, int64_t labelId,
    char** outNames, int32_t maxNames, int32_t maxLen) {
    if (!doc || !outNames) return 0;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return 0;
        Handle(XCAFDoc_LayerTool) layerTool = XCAFDoc_DocumentTool::LayerTool(doc->doc->Main());
        Handle(NCollection_HSequence<TCollection_ExtendedString>) layers = layerTool->GetLayers(label);
        if (layers.IsNull()) return 0;
        int32_t count = std::min((int32_t)layers->Length(), maxNames);
        for (int32_t i = 0; i < count; i++) {
            TCollection_AsciiString ascii(layers->Value(i + 1));
            strncpy(outNames[i], ascii.ToCString(), maxLen - 1);
            outNames[i][maxLen - 1] = '\0';
        }
        return count;
    } catch (...) { return 0; }
}

int64_t OCCTDocumentFindLayer(OCCTDocumentRef doc, const char* layerName) {
    if (!doc || !layerName) return -1;
    try {
        Handle(XCAFDoc_LayerTool) layerTool = XCAFDoc_DocumentTool::LayerTool(doc->doc->Main());
        TDF_Label layerLabel = layerTool->FindLayer(TCollection_ExtendedString(layerName));
        if (layerLabel.IsNull()) return -1;
        return doc->registerLabel(layerLabel);
    } catch (...) { return -1; }
}

void OCCTDocumentSetLayerVisibility(OCCTDocumentRef doc, int64_t layerLabelId, bool visible) {
    if (!doc) return;
    try {
        TDF_Label label = doc->getLabel(layerLabelId);
        if (label.IsNull()) return;
        Handle(XCAFDoc_LayerTool) layerTool = XCAFDoc_DocumentTool::LayerTool(doc->doc->Main());
        layerTool->SetVisibility(label, visible);
    } catch (...) {}
}

bool OCCTDocumentGetLayerVisibility(OCCTDocumentRef doc, int64_t layerLabelId) {
    if (!doc) return true;
    try {
        TDF_Label label = doc->getLabel(layerLabelId);
        if (label.IsNull()) return true;
        Handle(XCAFDoc_LayerTool) layerTool = XCAFDoc_DocumentTool::LayerTool(doc->doc->Main());
        return layerTool->IsVisible(label);
    } catch (...) { return true; }
}

// MARK: - XDE Editor (v0.60.0)

bool OCCTDocumentEditorExpand(OCCTDocumentRef doc, int64_t labelId, bool recursively) {
    if (!doc) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        return XCAFDoc_Editor::Expand(doc->doc->Main(), label, recursively);
    } catch (...) { return false; }
}

bool OCCTDocumentEditorRescaleGeometry(OCCTDocumentRef doc, int64_t labelId,
    double scaleFactor, bool forceIfNotRoot) {
    if (!doc) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        return XCAFDoc_Editor::RescaleGeometry(label, scaleFactor, forceIfNotRoot);
    } catch (...) { return false; }
}


// MARK: - v0.83: XDE Attributes (XCAFDoc_Location/GraphNode/Color/Material/Note*/NotesTool/ClippingPlaneTool/ShapeMapTool/AssemblyGraph/AssemblyItemId/VisMaterial/View/NoteObject/PrsStyle)
// MARK: - v0.83.0: XDE Attributes

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
#include <XCAFDoc_VisMaterialCommon.hxx>
#include <XCAFDoc_VisMaterialPBR.hxx>
#include <XCAFView_Object.hxx>
#include <XCAFView_ProjectionType.hxx>
#include <XCAFNoteObjects_NoteObject.hxx>
#include <XCAFPrs_Style.hxx>
#include <TopLoc_Location.hxx>
#include <TCollection_HAsciiString.hxx>

// --- XCAFDoc_Location ---

bool OCCTDocumentSetLocation(OCCTDocumentRef ref, int64_t labelId,
                              double tx, double ty, double tz) {
    if (!ref) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        gp_Trsf trsf;
        trsf.SetTranslation(gp_Vec(tx, ty, tz));
        TopLoc_Location loc(trsf);
        Handle(XCAFDoc_Location) attr = XCAFDoc_Location::Set(label, loc);
        return !attr.IsNull();
    } catch (...) { return false; }
}

bool OCCTDocumentGetLocationTranslation(OCCTDocumentRef ref, int64_t labelId,
                                         double *outX, double *outY, double *outZ) {
    if (!ref) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(XCAFDoc_Location) attr;
        if (!label.FindAttribute(XCAFDoc_Location::GetID(), attr)) return false;
        TopLoc_Location loc = attr->Get();
        gp_Trsf trsf = loc.Transformation();
        *outX = trsf.TranslationPart().X();
        *outY = trsf.TranslationPart().Y();
        *outZ = trsf.TranslationPart().Z();
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentHasLocation(OCCTDocumentRef ref, int64_t labelId) {
    if (!ref) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(XCAFDoc_Location) attr;
        return label.FindAttribute(XCAFDoc_Location::GetID(), attr);
    } catch (...) { return false; }
}

// --- XCAFDoc_GraphNode ---

bool OCCTDocumentSetGraphNodeAttr(OCCTDocumentRef ref, int64_t labelId) {
    if (!ref) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(XCAFDoc_GraphNode) node = XCAFDoc_GraphNode::Set(label);
        return !node.IsNull();
    } catch (...) { return false; }
}

bool OCCTDocumentGraphNodeSetChild(OCCTDocumentRef ref, int64_t parentLabelId, int64_t childLabelId) {
    if (!ref) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label parentLabel = doc->getLabel(parentLabelId);
        TDF_Label childLabel = doc->getLabel(childLabelId);
        if (parentLabel.IsNull() || childLabel.IsNull()) return false;
        Handle(XCAFDoc_GraphNode) parentNode, childNode;
        if (!parentLabel.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), parentNode)) return false;
        if (!childLabel.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), childNode)) return false;
        parentNode->SetChild(childNode);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentGraphNodeSetFather(OCCTDocumentRef ref, int64_t childLabelId, int64_t parentLabelId) {
    if (!ref) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label childLabel = doc->getLabel(childLabelId);
        TDF_Label parentLabel = doc->getLabel(parentLabelId);
        if (childLabel.IsNull() || parentLabel.IsNull()) return false;
        Handle(XCAFDoc_GraphNode) childNode, parentNode;
        if (!childLabel.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), childNode)) return false;
        if (!parentLabel.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), parentNode)) return false;
        childNode->SetFather(parentNode);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentGraphNodeUnSetChild(OCCTDocumentRef ref, int64_t parentLabelId, int64_t childLabelId) {
    if (!ref) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label parentLabel = doc->getLabel(parentLabelId);
        TDF_Label childLabel = doc->getLabel(childLabelId);
        if (parentLabel.IsNull() || childLabel.IsNull()) return false;
        Handle(XCAFDoc_GraphNode) parentNode, childNode;
        if (!parentLabel.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), parentNode)) return false;
        if (!childLabel.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), childNode)) return false;
        parentNode->UnSetChild(childNode);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentGraphNodeUnSetFather(OCCTDocumentRef ref, int64_t childLabelId, int64_t parentLabelId) {
    if (!ref) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label childLabel = doc->getLabel(childLabelId);
        TDF_Label parentLabel = doc->getLabel(parentLabelId);
        if (childLabel.IsNull() || parentLabel.IsNull()) return false;
        Handle(XCAFDoc_GraphNode) childNode, parentNode;
        if (!childLabel.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), childNode)) return false;
        if (!parentLabel.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), parentNode)) return false;
        childNode->UnSetFather(parentNode);
        return true;
    } catch (...) { return false; }
}

int32_t OCCTDocumentGraphNodeNbChildren(OCCTDocumentRef ref, int64_t labelId) {
    if (!ref) return 0;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return 0;
        Handle(XCAFDoc_GraphNode) node;
        if (!label.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), node)) return 0;
        return node->NbChildren();
    } catch (...) { return 0; }
}

int32_t OCCTDocumentGraphNodeNbFathers(OCCTDocumentRef ref, int64_t labelId) {
    if (!ref) return 0;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return 0;
        Handle(XCAFDoc_GraphNode) node;
        if (!label.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), node)) return 0;
        return node->NbFathers();
    } catch (...) { return 0; }
}

bool OCCTDocumentGraphNodeIsFather(OCCTDocumentRef ref, int64_t labelId, int64_t otherLabelId) {
    if (!ref) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        TDF_Label otherLabel = doc->getLabel(otherLabelId);
        if (label.IsNull() || otherLabel.IsNull()) return false;
        Handle(XCAFDoc_GraphNode) node, otherNode;
        if (!label.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), node)) return false;
        if (!otherLabel.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), otherNode)) return false;
        return node->IsFather(otherNode);
    } catch (...) { return false; }
}

bool OCCTDocumentGraphNodeIsChild(OCCTDocumentRef ref, int64_t labelId, int64_t otherLabelId) {
    if (!ref) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        TDF_Label otherLabel = doc->getLabel(otherLabelId);
        if (label.IsNull() || otherLabel.IsNull()) return false;
        Handle(XCAFDoc_GraphNode) node, otherNode;
        if (!label.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), node)) return false;
        if (!otherLabel.FindAttribute(XCAFDoc_GraphNode::GetDefaultGraphID(), otherNode)) return false;
        return node->IsChild(otherNode);
    } catch (...) { return false; }
}

// --- XCAFDoc_Color ---

bool OCCTDocumentSetColorAttr(OCCTDocumentRef ref, int64_t labelId,
                               double r, double g, double b) {
    if (!ref) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Quantity_Color color(r, g, b, Quantity_TOC_sRGB);
        Handle(XCAFDoc_Color) attr = XCAFDoc_Color::Set(label, color);
        return !attr.IsNull();
    } catch (...) { return false; }
}

bool OCCTDocumentSetColorRGBAAttr(OCCTDocumentRef ref, int64_t labelId,
                                    double r, double g, double b, float alpha) {
    if (!ref) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Quantity_ColorRGBA rgba(Quantity_Color(r, g, b, Quantity_TOC_sRGB), alpha);
        Handle(XCAFDoc_Color) attr = XCAFDoc_Color::Set(label, rgba);
        return !attr.IsNull();
    } catch (...) { return false; }
}

bool OCCTDocumentSetColorNOCAttr(OCCTDocumentRef ref, int64_t labelId, int32_t noc) {
    if (!ref) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Quantity_Color color((Quantity_NameOfColor)noc);
        Handle(XCAFDoc_Color) attr = XCAFDoc_Color::Set(label, color);
        return !attr.IsNull();
    } catch (...) { return false; }
}

bool OCCTDocumentGetColorAttr(OCCTDocumentRef ref, int64_t labelId,
                               double *outR, double *outG, double *outB) {
    if (!ref) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(XCAFDoc_Color) attr;
        if (!label.FindAttribute(XCAFDoc_Color::GetID(), attr)) return false;
        Quantity_Color c = attr->GetColor();
        *outR = c.Red();
        *outG = c.Green();
        *outB = c.Blue();
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentGetColorRGBAAttr(OCCTDocumentRef ref, int64_t labelId,
                                    double *outR, double *outG, double *outB,
                                    float *outAlpha) {
    if (!ref) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(XCAFDoc_Color) attr;
        if (!label.FindAttribute(XCAFDoc_Color::GetID(), attr)) return false;
        Quantity_ColorRGBA rgba = attr->GetColorRGBA();
        *outR = rgba.GetRGB().Red();
        *outG = rgba.GetRGB().Green();
        *outB = rgba.GetRGB().Blue();
        *outAlpha = rgba.Alpha();
        return true;
    } catch (...) { return false; }
}

float OCCTDocumentGetColorAlphaAttr(OCCTDocumentRef ref, int64_t labelId) {
    if (!ref) return 1.0f;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return 1.0f;
        Handle(XCAFDoc_Color) attr;
        if (!label.FindAttribute(XCAFDoc_Color::GetID(), attr)) return 1.0f;
        return attr->GetAlpha();
    } catch (...) { return 1.0f; }
}

int32_t OCCTDocumentGetColorNOCAttr(OCCTDocumentRef ref, int64_t labelId) {
    if (!ref) return -1;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return -1;
        Handle(XCAFDoc_Color) attr;
        if (!label.FindAttribute(XCAFDoc_Color::GetID(), attr)) return -1;
        return (int32_t)attr->GetNOC();
    } catch (...) { return -1; }
}

// --- XCAFDoc_Material ---

bool OCCTDocumentSetMaterialAttr(OCCTDocumentRef ref, int64_t labelId,
                                  const char *name, const char *description,
                                  double density,
                                  const char *densName, const char *densValType) {
    if (!ref) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TCollection_HAsciiString) hName = new TCollection_HAsciiString(name);
        Handle(TCollection_HAsciiString) hDesc = new TCollection_HAsciiString(description);
        Handle(TCollection_HAsciiString) hDensName = new TCollection_HAsciiString(densName);
        Handle(TCollection_HAsciiString) hDensType = new TCollection_HAsciiString(densValType);
        Handle(XCAFDoc_Material) attr = XCAFDoc_Material::Set(label, hName, hDesc, density, hDensName, hDensType);
        return !attr.IsNull();
    } catch (...) { return false; }
}

const char *_Nullable OCCTDocumentGetMaterialAttrName(OCCTDocumentRef ref, int64_t labelId) {
    if (!ref) return nullptr;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;
        Handle(XCAFDoc_Material) attr;
        if (!label.FindAttribute(XCAFDoc_Material::GetID(), attr)) return nullptr;
        Handle(TCollection_HAsciiString) n = attr->GetName();
        if (n.IsNull()) return nullptr;
        TCollection_AsciiString s = n->String();
        char *result = (char *)malloc(s.Length() + 1);
        if (!result) return nullptr;
        memcpy(result, s.ToCString(), s.Length() + 1);
        return result;
    } catch (...) { return nullptr; }
}

const char *_Nullable OCCTDocumentGetMaterialAttrDescription(OCCTDocumentRef ref, int64_t labelId) {
    if (!ref) return nullptr;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;
        Handle(XCAFDoc_Material) attr;
        if (!label.FindAttribute(XCAFDoc_Material::GetID(), attr)) return nullptr;
        Handle(TCollection_HAsciiString) d = attr->GetDescription();
        if (d.IsNull()) return nullptr;
        TCollection_AsciiString s = d->String();
        char *result = (char *)malloc(s.Length() + 1);
        if (!result) return nullptr;
        memcpy(result, s.ToCString(), s.Length() + 1);
        return result;
    } catch (...) { return nullptr; }
}

bool OCCTDocumentGetMaterialAttrDensity(OCCTDocumentRef ref, int64_t labelId, double *outDensity) {
    if (!ref) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(XCAFDoc_Material) attr;
        if (!label.FindAttribute(XCAFDoc_Material::GetID(), attr)) return false;
        *outDensity = attr->GetDensity();
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentHasMaterialAttr(OCCTDocumentRef ref, int64_t labelId) {
    if (!ref) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(XCAFDoc_Material) attr;
        return label.FindAttribute(XCAFDoc_Material::GetID(), attr);
    } catch (...) { return false; }
}

// --- XCAFDoc_NoteComment ---

bool OCCTDocumentSetNoteComment(OCCTDocumentRef ref, int64_t labelId,
                                 const char *userName, const char *timeStamp,
                                 const char *comment) {
    if (!ref) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        TCollection_ExtendedString user(userName);
        TCollection_ExtendedString ts(timeStamp);
        TCollection_ExtendedString cmt(comment);
        Handle(XCAFDoc_NoteComment) attr = XCAFDoc_NoteComment::Set(label, user, ts, cmt);
        return !attr.IsNull();
    } catch (...) { return false; }
}

const char *_Nullable OCCTDocumentGetNoteCommentText(OCCTDocumentRef ref, int64_t labelId) {
    if (!ref) return nullptr;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;
        Handle(XCAFDoc_NoteComment) attr;
        if (!label.FindAttribute(XCAFDoc_NoteComment::GetID(), attr)) return nullptr;
        TCollection_ExtendedString es = attr->Comment();
        TCollection_AsciiString as(es);
        char *result = (char *)malloc(as.Length() + 1);
        if (!result) return nullptr;
        memcpy(result, as.ToCString(), as.Length() + 1);
        return result;
    } catch (...) { return nullptr; }
}

const char *_Nullable OCCTDocumentGetNoteUserName(OCCTDocumentRef ref, int64_t labelId) {
    if (!ref) return nullptr;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;
        // Try NoteComment first, then NoteBalloon, then NoteBinData
        Handle(XCAFDoc_NoteComment) nc;
        if (label.FindAttribute(XCAFDoc_NoteComment::GetID(), nc)) {
            TCollection_ExtendedString es = nc->UserName();
            TCollection_AsciiString as(es);
            char *result = (char *)malloc(as.Length() + 1);
            if (!result) return nullptr;
            memcpy(result, as.ToCString(), as.Length() + 1);
            return result;
        }
        Handle(XCAFDoc_NoteBalloon) nb;
        if (label.FindAttribute(XCAFDoc_NoteBalloon::GetID(), nb)) {
            TCollection_ExtendedString es = nb->UserName();
            TCollection_AsciiString as(es);
            char *result = (char *)malloc(as.Length() + 1);
            if (!result) return nullptr;
            memcpy(result, as.ToCString(), as.Length() + 1);
            return result;
        }
        return nullptr;
    } catch (...) { return nullptr; }
}

// --- XCAFDoc_NoteBalloon ---

bool OCCTDocumentSetNoteBalloon(OCCTDocumentRef ref, int64_t labelId,
                                 const char *userName, const char *timeStamp,
                                 const char *comment) {
    if (!ref) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        TCollection_ExtendedString user(userName);
        TCollection_ExtendedString ts(timeStamp);
        TCollection_ExtendedString cmt(comment);
        Handle(XCAFDoc_NoteBalloon) attr = XCAFDoc_NoteBalloon::Set(label, user, ts, cmt);
        return !attr.IsNull();
    } catch (...) { return false; }
}

// --- XCAFDoc_NoteBinData ---

bool OCCTDocumentSetNoteBinData(OCCTDocumentRef ref, int64_t labelId,
                                 const char *userName, const char *timeStamp,
                                 const char *title, const char *mimeType,
                                 const uint8_t *data, int32_t dataSize) {
    if (!ref) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        TCollection_ExtendedString user(userName);
        TCollection_ExtendedString ts(timeStamp);
        TCollection_ExtendedString tit(title);
        TCollection_AsciiString mime(mimeType);
        Handle(NCollection_HArray1<uint8_t>) arr = new NCollection_HArray1<uint8_t>(1, dataSize);
        for (int i = 0; i < dataSize; i++) {
            arr->SetValue(i + 1, data[i]);
        }
        Handle(XCAFDoc_NoteBinData) attr = XCAFDoc_NoteBinData::Set(label, user, ts, tit, mime, arr);
        return !attr.IsNull();
    } catch (...) { return false; }
}

int32_t OCCTDocumentGetNoteBinDataSize(OCCTDocumentRef ref, int64_t labelId) {
    if (!ref) return 0;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return 0;
        Handle(XCAFDoc_NoteBinData) attr;
        if (!label.FindAttribute(XCAFDoc_NoteBinData::GetID(), attr)) return 0;
        return attr->Size();
    } catch (...) { return 0; }
}

// --- XCAFDoc_NotesTool ---

int32_t OCCTDocumentNotesToolNbNotes(OCCTDocumentRef ref) {
    if (!ref) return -1;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label main = doc->doc->Main();
        Handle(XCAFDoc_NotesTool) tool = XCAFDoc_DocumentTool::NotesTool(main);
        if (tool.IsNull()) return -1;
        return tool->NbNotes();
    } catch (...) { return -1; }
}

int64_t OCCTDocumentNotesToolCreateComment(OCCTDocumentRef ref,
                                             const char *userName,
                                             const char *timeStamp,
                                             const char *comment) {
    if (!ref) return -1;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label main = doc->doc->Main();
        Handle(XCAFDoc_NotesTool) tool = XCAFDoc_DocumentTool::NotesTool(main);
        if (tool.IsNull()) return -1;
        TCollection_ExtendedString user(userName);
        TCollection_ExtendedString ts(timeStamp);
        TCollection_ExtendedString cmt(comment);
        Handle(XCAFDoc_Note) note = tool->CreateComment(user, ts, cmt);
        if (note.IsNull()) return -1;
        return doc->registerLabel(note->Label());
    } catch (...) { return -1; }
}

int64_t OCCTDocumentNotesToolCreateBalloon(OCCTDocumentRef ref,
                                             const char *userName,
                                             const char *timeStamp,
                                             const char *comment) {
    if (!ref) return -1;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label main = doc->doc->Main();
        Handle(XCAFDoc_NotesTool) tool = XCAFDoc_DocumentTool::NotesTool(main);
        if (tool.IsNull()) return -1;
        TCollection_ExtendedString user(userName);
        TCollection_ExtendedString ts(timeStamp);
        TCollection_ExtendedString cmt(comment);
        Handle(XCAFDoc_Note) note = tool->CreateBalloon(user, ts, cmt);
        if (note.IsNull()) return -1;
        return doc->registerLabel(note->Label());
    } catch (...) { return -1; }
}

int64_t OCCTDocumentNotesToolCreateBinData(OCCTDocumentRef ref,
                                             const char *userName,
                                             const char *timeStamp,
                                             const char *title,
                                             const char *mimeType,
                                             const uint8_t *data,
                                             int32_t dataSize) {
    if (!ref) return -1;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label main = doc->doc->Main();
        Handle(XCAFDoc_NotesTool) tool = XCAFDoc_DocumentTool::NotesTool(main);
        if (tool.IsNull()) return -1;
        TCollection_ExtendedString user(userName);
        TCollection_ExtendedString ts(timeStamp);
        TCollection_ExtendedString tit(title);
        TCollection_AsciiString mime(mimeType);
        Handle(NCollection_HArray1<uint8_t>) arr = new NCollection_HArray1<uint8_t>(1, dataSize);
        for (int i = 0; i < dataSize; i++) {
            arr->SetValue(i + 1, data[i]);
        }
        Handle(XCAFDoc_Note) note = tool->CreateBinData(user, ts, tit, mime, arr);
        if (note.IsNull()) return -1;
        return doc->registerLabel(note->Label());
    } catch (...) { return -1; }
}

bool OCCTDocumentNotesToolDeleteNote(OCCTDocumentRef ref, int64_t noteLabelId) {
    if (!ref) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label main = doc->doc->Main();
        Handle(XCAFDoc_NotesTool) tool = XCAFDoc_DocumentTool::NotesTool(main);
        if (tool.IsNull()) return false;
        TDF_Label noteLabel = doc->getLabel(noteLabelId);
        if (noteLabel.IsNull()) return false;
        return tool->DeleteNote(noteLabel);
    } catch (...) { return false; }
}

int32_t OCCTDocumentNotesToolDeleteAllNotes(OCCTDocumentRef ref) {
    if (!ref) return 0;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label main = doc->doc->Main();
        Handle(XCAFDoc_NotesTool) tool = XCAFDoc_DocumentTool::NotesTool(main);
        if (tool.IsNull()) return 0;
        return tool->DeleteAllNotes();
    } catch (...) { return 0; }
}

int32_t OCCTDocumentNotesToolNbOrphanNotes(OCCTDocumentRef ref) {
    if (!ref) return 0;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label main = doc->doc->Main();
        Handle(XCAFDoc_NotesTool) tool = XCAFDoc_DocumentTool::NotesTool(main);
        if (tool.IsNull()) return 0;
        return tool->NbOrphanNotes();
    } catch (...) { return 0; }
}

int32_t OCCTDocumentNotesToolDeleteOrphanNotes(OCCTDocumentRef ref) {
    if (!ref) return 0;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label main = doc->doc->Main();
        Handle(XCAFDoc_NotesTool) tool = XCAFDoc_DocumentTool::NotesTool(main);
        if (tool.IsNull()) return 0;
        return tool->DeleteOrphanNotes();
    } catch (...) { return 0; }
}

// --- XCAFDoc_ClippingPlaneTool ---

int64_t OCCTDocumentClipPlaneToolAdd(OCCTDocumentRef ref,
                                       double planeOrigX, double planeOrigY, double planeOrigZ,
                                       double planeNormX, double planeNormY, double planeNormZ,
                                       const char *name, bool capping) {
    if (!ref) return -1;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label main = doc->doc->Main();
        Handle(XCAFDoc_ClippingPlaneTool) tool = XCAFDoc_DocumentTool::ClippingPlaneTool(main);
        if (tool.IsNull()) return -1;
        gp_Pln plane(gp_Pnt(planeOrigX, planeOrigY, planeOrigZ),
                     gp_Dir(planeNormX, planeNormY, planeNormZ));
        TCollection_ExtendedString eName(name);
        TDF_Label clipLabel = tool->AddClippingPlane(plane, eName, capping);
        if (clipLabel.IsNull()) return -1;
        return doc->registerLabel(clipLabel);
    } catch (...) { return -1; }
}

bool OCCTDocumentClipPlaneToolGet(OCCTDocumentRef ref, int64_t labelId,
                                    double *origX, double *origY, double *origZ,
                                    double *normX, double *normY, double *normZ,
                                    bool *capping) {
    if (!ref) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label main = doc->doc->Main();
        Handle(XCAFDoc_ClippingPlaneTool) tool = XCAFDoc_DocumentTool::ClippingPlaneTool(main);
        if (tool.IsNull()) return false;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        gp_Pln plane;
        TCollection_ExtendedString name;
        bool cap = false;
        if (!tool->GetClippingPlane(label, plane, name, cap)) return false;
        *origX = plane.Location().X();
        *origY = plane.Location().Y();
        *origZ = plane.Location().Z();
        gp_Dir n = plane.Axis().Direction();
        *normX = n.X();
        *normY = n.Y();
        *normZ = n.Z();
        *capping = cap;
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentClipPlaneToolIsClipPlane(OCCTDocumentRef ref, int64_t labelId) {
    if (!ref) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label main = doc->doc->Main();
        Handle(XCAFDoc_ClippingPlaneTool) tool = XCAFDoc_DocumentTool::ClippingPlaneTool(main);
        if (tool.IsNull()) return false;
        TDF_Label label = doc->getLabel(labelId);
        return tool->IsClippingPlane(label);
    } catch (...) { return false; }
}

bool OCCTDocumentClipPlaneToolRemove(OCCTDocumentRef ref, int64_t labelId) {
    if (!ref) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label main = doc->doc->Main();
        Handle(XCAFDoc_ClippingPlaneTool) tool = XCAFDoc_DocumentTool::ClippingPlaneTool(main);
        if (tool.IsNull()) return false;
        TDF_Label label = doc->getLabel(labelId);
        return tool->RemoveClippingPlane(label);
    } catch (...) { return false; }
}

// --- XCAFDoc_ShapeMapTool ---

bool OCCTDocumentSetShapeMapTool(OCCTDocumentRef ref, int64_t labelId) {
    if (!ref) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(XCAFDoc_ShapeMapTool) tool = XCAFDoc_ShapeMapTool::Set(label);
        return !tool.IsNull();
    } catch (...) { return false; }
}

bool OCCTDocumentShapeMapToolSetShape(OCCTDocumentRef ref, int64_t labelId, OCCTShapeRef shape) {
    if (!ref || !shape) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(XCAFDoc_ShapeMapTool) tool;
        if (!label.FindAttribute(XCAFDoc_ShapeMapTool::GetID(), tool)) return false;
        tool->SetShape(*(const TopoDS_Shape *)shape);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentShapeMapToolIsSubShape(OCCTDocumentRef ref, int64_t labelId, OCCTShapeRef shape) {
    if (!ref || !shape) return false;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(XCAFDoc_ShapeMapTool) tool;
        if (!label.FindAttribute(XCAFDoc_ShapeMapTool::GetID(), tool)) return false;
        return tool->IsSubShape(*(const TopoDS_Shape *)shape);
    } catch (...) { return false; }
}

int32_t OCCTDocumentShapeMapToolExtent(OCCTDocumentRef ref, int64_t labelId) {
    if (!ref) return 0;
    try {
        auto *doc = (OCCTDocument *)ref;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return 0;
        Handle(XCAFDoc_ShapeMapTool) tool;
        if (!label.FindAttribute(XCAFDoc_ShapeMapTool::GetID(), tool)) return 0;
        return tool->GetMap().Extent();
    } catch (...) { return 0; }
}

// --- XCAFDoc_AssemblyGraph ---

struct OCCTAssemblyGraph {
    Handle(XCAFDoc_AssemblyGraph) graph;
};

OCCTAssemblyGraphRef OCCTAssemblyGraphCreate(OCCTDocumentRef ref) {
    if (!ref) return nullptr;
    try {
        auto *doc = (OCCTDocument *)ref;
        Handle(XCAFDoc_AssemblyGraph) graph = new XCAFDoc_AssemblyGraph(doc->doc);
        if (graph.IsNull()) return nullptr;
        return (OCCTAssemblyGraphRef)new OCCTAssemblyGraph{graph};
    } catch (...) { return nullptr; }
}

void OCCTAssemblyGraphRelease(OCCTAssemblyGraphRef ref) {
    delete (OCCTAssemblyGraph *)ref;
}

int32_t OCCTAssemblyGraphNbNodes(OCCTAssemblyGraphRef ref) {
    if (!ref) return 0;
    try {
        return ((OCCTAssemblyGraph *)ref)->graph->NbNodes();
    } catch (...) { return 0; }
}

int32_t OCCTAssemblyGraphNbLinks(OCCTAssemblyGraphRef ref) {
    if (!ref) return 0;
    try {
        return ((OCCTAssemblyGraph *)ref)->graph->NbLinks();
    } catch (...) { return 0; }
}

int32_t OCCTAssemblyGraphNbRoots(OCCTAssemblyGraphRef ref) {
    if (!ref) return 0;
    try {
        auto& roots = ((OCCTAssemblyGraph *)ref)->graph->GetRoots();
        return roots.Extent();
    } catch (...) { return 0; }
}

int32_t OCCTAssemblyGraphGetNodeType(OCCTAssemblyGraphRef ref, int32_t nodeIndex) {
    if (!ref) return -1;
    try {
        return (int32_t)((OCCTAssemblyGraph *)ref)->graph->GetNodeType(nodeIndex);
    } catch (...) { return -1; }
}

// --- XCAFDoc_AssemblyItemId ---

bool OCCTAssemblyItemIdIsValid(const char *str) {
    try {
        TCollection_AsciiString aStr(str);
        XCAFDoc_AssemblyItemId id(aStr);
        return !id.IsNull();
    } catch (...) { return false; }
}

int32_t OCCTAssemblyItemIdPathCount(const char *str) {
    try {
        TCollection_AsciiString aStr(str);
        XCAFDoc_AssemblyItemId id(aStr);
        return id.GetPath().Size();
    } catch (...) { return 0; }
}

bool OCCTAssemblyItemIdIsEqual(const char *str1, const char *str2) {
    try {
        TCollection_AsciiString aStr1(str1);
        TCollection_AsciiString aStr2(str2);
        XCAFDoc_AssemblyItemId id1(aStr1);
        XCAFDoc_AssemblyItemId id2(aStr2);
        return id1.IsEqual(id2);
    } catch (...) { return false; }
}

// --- XCAFView_Object ---

struct OCCTViewObject {
    Handle(XCAFView_Object) obj;
};

OCCTViewObjectRef OCCTViewObjectCreate(void) {
    try {
        return (OCCTViewObjectRef)new OCCTViewObject{new XCAFView_Object()};
    } catch (...) { return nullptr; }
}

void OCCTViewObjectRelease(OCCTViewObjectRef ref) {
    delete (OCCTViewObject *)ref;
}

void OCCTViewObjectSetType(OCCTViewObjectRef ref, int32_t type) {
    if (!ref) return;
    try {
        ((OCCTViewObject *)ref)->obj->SetType((XCAFView_ProjectionType)type);
    } catch (...) {}
}

int32_t OCCTViewObjectGetType(OCCTViewObjectRef ref) {
    if (!ref) return 0;
    try {
        return (int32_t)((OCCTViewObject *)ref)->obj->Type();
    } catch (...) { return 0; }
}

void OCCTViewObjectSetViewDirection(OCCTViewObjectRef ref, double x, double y, double z) {
    if (!ref) return;
    try {
        ((OCCTViewObject *)ref)->obj->SetViewDirection(gp_Dir(x, y, z));
    } catch (...) {}
}

void OCCTViewObjectGetViewDirection(OCCTViewObjectRef ref, double *x, double *y, double *z) {
    if (!ref) { *x = 0; *y = 0; *z = -1; return; }
    try {
        gp_Dir dir = ((OCCTViewObject *)ref)->obj->ViewDirection();
        *x = dir.X(); *y = dir.Y(); *z = dir.Z();
    } catch (...) { *x = 0; *y = 0; *z = -1; }
}

void OCCTViewObjectSetUpDirection(OCCTViewObjectRef ref, double x, double y, double z) {
    if (!ref) return;
    try {
        ((OCCTViewObject *)ref)->obj->SetUpDirection(gp_Dir(x, y, z));
    } catch (...) {}
}

void OCCTViewObjectGetUpDirection(OCCTViewObjectRef ref, double *x, double *y, double *z) {
    if (!ref) { *x = 0; *y = 0; *z = 1; return; }
    try {
        gp_Dir dir = ((OCCTViewObject *)ref)->obj->UpDirection();
        *x = dir.X(); *y = dir.Y(); *z = dir.Z();
    } catch (...) { *x = 0; *y = 0; *z = 1; }
}

void OCCTViewObjectSetWindowHSize(OCCTViewObjectRef ref, double size) {
    if (!ref) return;
    try { ((OCCTViewObject *)ref)->obj->SetWindowHorizontalSize(size); } catch (...) {}
}

double OCCTViewObjectGetWindowHSize(OCCTViewObjectRef ref) {
    if (!ref) return 0;
    try { return ((OCCTViewObject *)ref)->obj->WindowHorizontalSize(); } catch (...) { return 0; }
}

void OCCTViewObjectSetWindowVSize(OCCTViewObjectRef ref, double size) {
    if (!ref) return;
    try { ((OCCTViewObject *)ref)->obj->SetWindowVerticalSize(size); } catch (...) {}
}

double OCCTViewObjectGetWindowVSize(OCCTViewObjectRef ref) {
    if (!ref) return 0;
    try { return ((OCCTViewObject *)ref)->obj->WindowVerticalSize(); } catch (...) { return 0; }
}

void OCCTViewObjectSetFrontPlaneDistance(OCCTViewObjectRef ref, double dist) {
    if (!ref) return;
    try { ((OCCTViewObject *)ref)->obj->SetFrontPlaneDistance(dist); } catch (...) {}
}

double OCCTViewObjectGetFrontPlaneDistance(OCCTViewObjectRef ref) {
    if (!ref) return 0;
    try { return ((OCCTViewObject *)ref)->obj->FrontPlaneDistance(); } catch (...) { return 0; }
}

bool OCCTViewObjectHasFrontPlaneClipping(OCCTViewObjectRef ref) {
    if (!ref) return false;
    try { return ((OCCTViewObject *)ref)->obj->HasFrontPlaneClipping(); } catch (...) { return false; }
}

void OCCTViewObjectUnsetFrontPlaneClipping(OCCTViewObjectRef ref) {
    if (!ref) return;
    try { ((OCCTViewObject *)ref)->obj->UnsetFrontPlaneClipping(); } catch (...) {}
}

void OCCTViewObjectSetBackPlaneDistance(OCCTViewObjectRef ref, double dist) {
    if (!ref) return;
    try { ((OCCTViewObject *)ref)->obj->SetBackPlaneDistance(dist); } catch (...) {}
}

double OCCTViewObjectGetBackPlaneDistance(OCCTViewObjectRef ref) {
    if (!ref) return 0;
    try { return ((OCCTViewObject *)ref)->obj->BackPlaneDistance(); } catch (...) { return 0; }
}

bool OCCTViewObjectHasBackPlaneClipping(OCCTViewObjectRef ref) {
    if (!ref) return false;
    try { return ((OCCTViewObject *)ref)->obj->HasBackPlaneClipping(); } catch (...) { return false; }
}

void OCCTViewObjectUnsetBackPlaneClipping(OCCTViewObjectRef ref) {
    if (!ref) return;
    try { ((OCCTViewObject *)ref)->obj->UnsetBackPlaneClipping(); } catch (...) {}
}

void OCCTViewObjectSetName(OCCTViewObjectRef ref, const char *name) {
    if (!ref) return;
    try {
        ((OCCTViewObject *)ref)->obj->SetName(new TCollection_HAsciiString(name));
    } catch (...) {}
}

const char *_Nullable OCCTViewObjectGetName(OCCTViewObjectRef ref) {
    if (!ref) return nullptr;
    try {
        Handle(TCollection_HAsciiString) n = ((OCCTViewObject *)ref)->obj->Name();
        if (n.IsNull()) return nullptr;
        TCollection_AsciiString s = n->String();
        char *result = (char *)malloc(s.Length() + 1);
        if (!result) return nullptr;
        memcpy(result, s.ToCString(), s.Length() + 1);
        return result;
    } catch (...) { return nullptr; }
}

// --- XCAFNoteObjects_NoteObject ---

struct OCCTNoteObject {
    Handle(XCAFNoteObjects_NoteObject) obj;
};

OCCTNoteObjectRef OCCTNoteObjectCreate(void) {
    try {
        return (OCCTNoteObjectRef)new OCCTNoteObject{new XCAFNoteObjects_NoteObject()};
    } catch (...) { return nullptr; }
}

void OCCTNoteObjectRelease(OCCTNoteObjectRef ref) {
    delete (OCCTNoteObject *)ref;
}

bool OCCTNoteObjectHasPlane(OCCTNoteObjectRef ref) {
    if (!ref) return false;
    try { return ((OCCTNoteObject *)ref)->obj->HasPlane(); } catch (...) { return false; }
}

bool OCCTNoteObjectHasPoint(OCCTNoteObjectRef ref) {
    if (!ref) return false;
    try { return ((OCCTNoteObject *)ref)->obj->HasPoint(); } catch (...) { return false; }
}

bool OCCTNoteObjectHasPointText(OCCTNoteObjectRef ref) {
    if (!ref) return false;
    try { return ((OCCTNoteObject *)ref)->obj->HasPointText(); } catch (...) { return false; }
}

void OCCTNoteObjectSetPlane(OCCTNoteObjectRef ref,
                              double origX, double origY, double origZ,
                              double normX, double normY, double normZ) {
    if (!ref) return;
    try {
        gp_Ax2 ax(gp_Pnt(origX, origY, origZ), gp_Dir(normX, normY, normZ));
        ((OCCTNoteObject *)ref)->obj->SetPlane(ax);
    } catch (...) {}
}

void OCCTNoteObjectGetPlane(OCCTNoteObjectRef ref,
                              double *origX, double *origY, double *origZ) {
    if (!ref) { *origX = 0; *origY = 0; *origZ = 0; return; }
    try {
        gp_Ax2 ax = ((OCCTNoteObject *)ref)->obj->GetPlane();
        *origX = ax.Location().X();
        *origY = ax.Location().Y();
        *origZ = ax.Location().Z();
    } catch (...) { *origX = 0; *origY = 0; *origZ = 0; }
}

void OCCTNoteObjectSetPoint(OCCTNoteObjectRef ref, double x, double y, double z) {
    if (!ref) return;
    try { ((OCCTNoteObject *)ref)->obj->SetPoint(gp_Pnt(x, y, z)); } catch (...) {}
}

void OCCTNoteObjectGetPoint(OCCTNoteObjectRef ref, double *x, double *y, double *z) {
    if (!ref) { *x = 0; *y = 0; *z = 0; return; }
    try {
        gp_Pnt p = ((OCCTNoteObject *)ref)->obj->GetPoint();
        *x = p.X(); *y = p.Y(); *z = p.Z();
    } catch (...) { *x = 0; *y = 0; *z = 0; }
}

void OCCTNoteObjectSetPresentation(OCCTNoteObjectRef ref, OCCTShapeRef shape) {
    if (!ref || !shape) return;
    try {
        ((OCCTNoteObject *)ref)->obj->SetPresentation(*(const TopoDS_Shape *)shape);
    } catch (...) {}
}

OCCTShapeRef OCCTNoteObjectGetPresentation(OCCTNoteObjectRef ref) {
    if (!ref) return nullptr;
    try {
        const TopoDS_Shape& s = ((OCCTNoteObject *)ref)->obj->GetPresentation();
        if (s.IsNull()) return nullptr;
        return (OCCTShapeRef)new TopoDS_Shape(s);
    } catch (...) { return nullptr; }
}

void OCCTNoteObjectReset(OCCTNoteObjectRef ref) {
    if (!ref) return;
    try { ((OCCTNoteObject *)ref)->obj->Reset(); } catch (...) {}
}

// --- XCAFPrs_Style ---

OCCTXCAFPrsStyle OCCTXCAFPrsStyleCreate(void) {
    XCAFPrs_Style style;
    OCCTXCAFPrsStyle result;
    result.surfR = 0; result.surfG = 0; result.surfB = 0;
    result.surfAlpha = 1.0f;
    result.hasSurfColor = false;
    result.curvR = 0; result.curvG = 0; result.curvB = 0;
    result.hasCurvColor = false;
    result.isVisible = style.IsVisible();
    result.isEmpty = style.IsEmpty();
    return result;
}

OCCTXCAFPrsStyle OCCTXCAFPrsStyleCreateWithSurfColor(double r, double g, double b, float alpha) {
    XCAFPrs_Style style;
    Quantity_ColorRGBA rgba(Quantity_Color(r, g, b, Quantity_TOC_sRGB), alpha);
    style.SetColorSurf(rgba);
    OCCTXCAFPrsStyle result;
    result.surfR = r; result.surfG = g; result.surfB = b;
    result.surfAlpha = alpha;
    result.hasSurfColor = true;
    result.curvR = 0; result.curvG = 0; result.curvB = 0;
    result.hasCurvColor = false;
    result.isVisible = style.IsVisible();
    result.isEmpty = style.IsEmpty();
    return result;
}

OCCTXCAFPrsStyle OCCTXCAFPrsStyleCreateFull(double surfR, double surfG, double surfB, float surfAlpha,
                                              double curvR, double curvG, double curvB,
                                              bool visible) {
    OCCTXCAFPrsStyle result;
    result.surfR = surfR; result.surfG = surfG; result.surfB = surfB;
    result.surfAlpha = surfAlpha;
    result.hasSurfColor = true;
    result.curvR = curvR; result.curvG = curvG; result.curvB = curvB;
    result.hasCurvColor = true;
    result.isVisible = visible;
    result.isEmpty = false;
    return result;
}

bool OCCTXCAFPrsStyleIsEqual(const OCCTXCAFPrsStyle *s1, const OCCTXCAFPrsStyle *s2) {
    try {
        XCAFPrs_Style style1, style2;
        if (s1->hasSurfColor) {
            style1.SetColorSurf(Quantity_ColorRGBA(Quantity_Color(s1->surfR, s1->surfG, s1->surfB, Quantity_TOC_sRGB), s1->surfAlpha));
        }
        if (s1->hasCurvColor) {
            style1.SetColorCurv(Quantity_Color(s1->curvR, s1->curvG, s1->curvB, Quantity_TOC_sRGB));
        }
        style1.SetVisibility(s1->isVisible);

        if (s2->hasSurfColor) {
            style2.SetColorSurf(Quantity_ColorRGBA(Quantity_Color(s2->surfR, s2->surfG, s2->surfB, Quantity_TOC_sRGB), s2->surfAlpha));
        }
        if (s2->hasCurvColor) {
            style2.SetColorCurv(Quantity_Color(s2->curvR, s2->curvG, s2->curvB, Quantity_TOC_sRGB));
        }
        style2.SetVisibility(s2->isVisible);

        return style1.IsEqual(style2);
    } catch (...) { return false; }
}

// --- XCAFDoc_VisMaterialCommon ---

OCCTVisMaterialCommon OCCTVisMaterialCommonDefault(void) {
    XCAFDoc_VisMaterialCommon mat;
    OCCTVisMaterialCommon result;
    result.diffuseR = mat.DiffuseColor.Red();
    result.diffuseG = mat.DiffuseColor.Green();
    result.diffuseB = mat.DiffuseColor.Blue();
    result.ambientR = mat.AmbientColor.Red();
    result.ambientG = mat.AmbientColor.Green();
    result.ambientB = mat.AmbientColor.Blue();
    result.specularR = mat.SpecularColor.Red();
    result.specularG = mat.SpecularColor.Green();
    result.specularB = mat.SpecularColor.Blue();
    result.emissiveR = mat.EmissiveColor.Red();
    result.emissiveG = mat.EmissiveColor.Green();
    result.emissiveB = mat.EmissiveColor.Blue();
    result.shininess = mat.Shininess;
    result.transparency = mat.Transparency;
    result.isDefined = mat.IsDefined;
    return result;
}

bool OCCTVisMaterialCommonIsEqual(const OCCTVisMaterialCommon *a, const OCCTVisMaterialCommon *b) {
    try {
        XCAFDoc_VisMaterialCommon ma, mb;
        ma.DiffuseColor = Quantity_Color(a->diffuseR, a->diffuseG, a->diffuseB, Quantity_TOC_sRGB);
        ma.AmbientColor = Quantity_Color(a->ambientR, a->ambientG, a->ambientB, Quantity_TOC_sRGB);
        ma.SpecularColor = Quantity_Color(a->specularR, a->specularG, a->specularB, Quantity_TOC_sRGB);
        ma.EmissiveColor = Quantity_Color(a->emissiveR, a->emissiveG, a->emissiveB, Quantity_TOC_sRGB);
        ma.Shininess = a->shininess;
        ma.Transparency = a->transparency;
        ma.IsDefined = a->isDefined;

        mb.DiffuseColor = Quantity_Color(b->diffuseR, b->diffuseG, b->diffuseB, Quantity_TOC_sRGB);
        mb.AmbientColor = Quantity_Color(b->ambientR, b->ambientG, b->ambientB, Quantity_TOC_sRGB);
        mb.SpecularColor = Quantity_Color(b->specularR, b->specularG, b->specularB, Quantity_TOC_sRGB);
        mb.EmissiveColor = Quantity_Color(b->emissiveR, b->emissiveG, b->emissiveB, Quantity_TOC_sRGB);
        mb.Shininess = b->shininess;
        mb.Transparency = b->transparency;
        mb.IsDefined = b->isDefined;

        return ma.IsEqual(mb);
    } catch (...) { return false; }
}

// --- XCAFDoc_VisMaterialPBR ---

OCCTVisMaterialPBR OCCTVisMaterialPBRDefault(void) {
    XCAFDoc_VisMaterialPBR pbr;
    OCCTVisMaterialPBR result;
    result.baseColorR = pbr.BaseColor.GetRGB().Red();
    result.baseColorG = pbr.BaseColor.GetRGB().Green();
    result.baseColorB = pbr.BaseColor.GetRGB().Blue();
    result.baseColorAlpha = pbr.BaseColor.Alpha();
    result.metallic = pbr.Metallic;
    result.roughness = pbr.Roughness;
    result.refractionIndex = pbr.RefractionIndex;
    result.emissionR = pbr.EmissiveFactor.r();
    result.emissionG = pbr.EmissiveFactor.g();
    result.emissionB = pbr.EmissiveFactor.b();
    result.isDefined = pbr.IsDefined;
    return result;
}

bool OCCTVisMaterialPBRIsEqual(const OCCTVisMaterialPBR *a, const OCCTVisMaterialPBR *b) {
    try {
        XCAFDoc_VisMaterialPBR pa, pb;
        pa.BaseColor = Quantity_ColorRGBA(Quantity_Color(a->baseColorR, a->baseColorG, a->baseColorB, Quantity_TOC_sRGB), a->baseColorAlpha);
        pa.Metallic = a->metallic;
        pa.Roughness = a->roughness;
        pa.RefractionIndex = a->refractionIndex;
        pa.EmissiveFactor = Graphic3d_Vec3((float)a->emissionR, (float)a->emissionG, (float)a->emissionB);
        pa.IsDefined = a->isDefined;

        pb.BaseColor = Quantity_ColorRGBA(Quantity_Color(b->baseColorR, b->baseColorG, b->baseColorB, Quantity_TOC_sRGB), b->baseColorAlpha);
        pb.Metallic = b->metallic;
        pb.Roughness = b->roughness;
        pb.RefractionIndex = b->refractionIndex;
        pb.EmissiveFactor = Graphic3d_Vec3((float)b->emissionR, (float)b->emissionG, (float)b->emissionB);
        pb.IsDefined = b->isDefined;

        return pa.IsEqual(pb);
    } catch (...) { return false; }
}


// MARK: - v0.84: TDataStd Directory/Variable/Expression, TDocStd_XLink, XCAFDimTolObjects_Tool, TPrsStd_DriverTable, TObj_Application

#include <TDataStd_Directory.hxx>
#include <TDataStd_Variable.hxx>
#include <TDataStd_Expression.hxx>
#include <TDocStd_XLink.hxx>
#include <XCAFDimTolObjects_Tool.hxx>
#include <TPrsStd_DriverTable.hxx>
#include <TObj_Application.hxx>
#include <TDF_TagSource.hxx>

// Helper to get label from document ref + tag (duplicate of main bridge's helper, ODR-safe across TUs)
static TDF_Label getLabelForTag(OCCTDocumentRef document, int tag) {
    if (tag == 0) return document->doc->Main();
    return document->doc->Main().FindChild(tag, Standard_True);
}

// --- TDataStd_Directory ---

bool OCCTDocumentDirectoryNew(OCCTDocumentRef document, int labelTag) {
    try {
        TDF_Label label = getLabelForTag(document, labelTag);
        Handle(TDataStd_Directory) dir = TDataStd_Directory::New(label);
        return !dir.IsNull();
    } catch (...) { return false; }
}

bool OCCTDocumentDirectoryFind(OCCTDocumentRef document, int labelTag) {
    try {
        TDF_Label label = getLabelForTag(document, labelTag);
        Handle(TDataStd_Directory) dir;
        return TDataStd_Directory::Find(label, dir);
    } catch (...) { return false; }
}

int OCCTDocumentDirectoryAddSubDirectory(OCCTDocumentRef document, int parentLabelTag) {
    try {
        TDF_Label parentLabel = getLabelForTag(document, parentLabelTag);
        Handle(TDataStd_Directory) dir;
        if (!TDataStd_Directory::Find(parentLabel, dir)) return -1;
        Handle(TDataStd_Directory) subDir = TDataStd_Directory::AddDirectory(dir);
        if (subDir.IsNull()) return -1;
        return subDir->Label().Tag();
    } catch (...) { return -1; }
}

int OCCTDocumentDirectoryMakeObjectLabel(OCCTDocumentRef document, int parentLabelTag) {
    try {
        TDF_Label parentLabel = getLabelForTag(document, parentLabelTag);
        Handle(TDataStd_Directory) dir;
        if (!TDataStd_Directory::Find(parentLabel, dir)) return -1;
        TDF_Label objLabel = TDataStd_Directory::MakeObjectLabel(dir);
        if (objLabel.IsNull()) return -1;
        return objLabel.Tag();
    } catch (...) { return -1; }
}

// --- TDataStd_Variable ---

bool OCCTDocumentVariableSet(OCCTDocumentRef document, int labelTag) {
    try {
        TDF_Label label = getLabelForTag(document, labelTag);
        Handle(TDataStd_Variable) var = TDataStd_Variable::Set(label);
        return !var.IsNull();
    } catch (...) { return false; }
}

bool OCCTDocumentVariableSetName(OCCTDocumentRef document, int labelTag, const char* name) {
    try {
        TDF_Label label = getLabelForTag(document, labelTag);
        Handle(TDataStd_Variable) var;
        if (!label.FindAttribute(TDataStd_Variable::GetID(), var)) return false;
        var->Name(TCollection_ExtendedString(name));
        return true;
    } catch (...) { return false; }
}

const char* OCCTDocumentVariableGetName(OCCTDocumentRef document, int labelTag) {
    try {
        TDF_Label label = getLabelForTag(document, labelTag);
        Handle(TDataStd_Variable) var;
        if (!label.FindAttribute(TDataStd_Variable::GetID(), var)) return nullptr;
        TCollection_AsciiString aStr(var->Name());
        char* result = (char*)malloc(aStr.Length() + 1);
        strcpy(result, aStr.ToCString());
        return result;
    } catch (...) { return nullptr; }
}

bool OCCTDocumentVariableSetValue(OCCTDocumentRef document, int labelTag, double value) {
    try {
        TDF_Label label = getLabelForTag(document, labelTag);
        Handle(TDataStd_Variable) var;
        if (!label.FindAttribute(TDataStd_Variable::GetID(), var)) return false;
        var->Set(value);
        return true;
    } catch (...) { return false; }
}

double OCCTDocumentVariableGetValue(OCCTDocumentRef document, int labelTag) {
    try {
        TDF_Label label = getLabelForTag(document, labelTag);
        Handle(TDataStd_Variable) var;
        if (!label.FindAttribute(TDataStd_Variable::GetID(), var)) return 0.0;
        if (!var->IsValued()) return 0.0;
        return var->Get();
    } catch (...) { return 0.0; }
}

bool OCCTDocumentVariableIsValued(OCCTDocumentRef document, int labelTag) {
    try {
        TDF_Label label = getLabelForTag(document, labelTag);
        Handle(TDataStd_Variable) var;
        if (!label.FindAttribute(TDataStd_Variable::GetID(), var)) return false;
        return var->IsValued();
    } catch (...) { return false; }
}

bool OCCTDocumentVariableSetUnit(OCCTDocumentRef document, int labelTag, const char* unit) {
    try {
        TDF_Label label = getLabelForTag(document, labelTag);
        Handle(TDataStd_Variable) var;
        if (!label.FindAttribute(TDataStd_Variable::GetID(), var)) return false;
        var->Unit(TCollection_AsciiString(unit));
        return true;
    } catch (...) { return false; }
}

const char* OCCTDocumentVariableGetUnit(OCCTDocumentRef document, int labelTag) {
    try {
        TDF_Label label = getLabelForTag(document, labelTag);
        Handle(TDataStd_Variable) var;
        if (!label.FindAttribute(TDataStd_Variable::GetID(), var)) return nullptr;
        TCollection_AsciiString unit = var->Unit();
        char* result = (char*)malloc(unit.Length() + 1);
        strcpy(result, unit.ToCString());
        return result;
    } catch (...) { return nullptr; }
}

bool OCCTDocumentVariableSetConstant(OCCTDocumentRef document, int labelTag, bool isConstant) {
    try {
        TDF_Label label = getLabelForTag(document, labelTag);
        Handle(TDataStd_Variable) var;
        if (!label.FindAttribute(TDataStd_Variable::GetID(), var)) return false;
        var->Constant(isConstant);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentVariableIsConstant(OCCTDocumentRef document, int labelTag) {
    try {
        TDF_Label label = getLabelForTag(document, labelTag);
        Handle(TDataStd_Variable) var;
        if (!label.FindAttribute(TDataStd_Variable::GetID(), var)) return false;
        return var->IsConstant();
    } catch (...) { return false; }
}

// --- TDataStd_Expression ---

bool OCCTDocumentExpressionSet(OCCTDocumentRef document, int labelTag) {
    try {
        TDF_Label label = getLabelForTag(document, labelTag);
        Handle(TDataStd_Expression) expr = TDataStd_Expression::Set(label);
        return !expr.IsNull();
    } catch (...) { return false; }
}

bool OCCTDocumentExpressionSetString(OCCTDocumentRef document, int labelTag, const char* expression) {
    try {
        TDF_Label label = getLabelForTag(document, labelTag);
        Handle(TDataStd_Expression) expr;
        if (!label.FindAttribute(TDataStd_Expression::GetID(), expr)) return false;
        expr->SetExpression(TCollection_ExtendedString(expression));
        return true;
    } catch (...) { return false; }
}

const char* OCCTDocumentExpressionGetString(OCCTDocumentRef document, int labelTag) {
    try {
        TDF_Label label = getLabelForTag(document, labelTag);
        Handle(TDataStd_Expression) expr;
        if (!label.FindAttribute(TDataStd_Expression::GetID(), expr)) return nullptr;
        TCollection_AsciiString aStr(expr->GetExpression());
        char* result = (char*)malloc(aStr.Length() + 1);
        strcpy(result, aStr.ToCString());
        return result;
    } catch (...) { return nullptr; }
}

const char* OCCTDocumentExpressionGetName(OCCTDocumentRef document, int labelTag) {
    try {
        TDF_Label label = getLabelForTag(document, labelTag);
        Handle(TDataStd_Expression) expr;
        if (!label.FindAttribute(TDataStd_Expression::GetID(), expr)) return nullptr;
        TCollection_AsciiString aStr(expr->Name());
        char* result = (char*)malloc(aStr.Length() + 1);
        strcpy(result, aStr.ToCString());
        return result;
    } catch (...) { return nullptr; }
}

bool OCCTDocumentVariableAssignExpression(OCCTDocumentRef document, int labelTag) {
    try {
        TDF_Label label = getLabelForTag(document, labelTag);
        Handle(TDataStd_Variable) var;
        if (!label.FindAttribute(TDataStd_Variable::GetID(), var)) return false;
        Handle(TDataStd_Expression) expr = var->Assign();
        return !expr.IsNull();
    } catch (...) { return false; }
}

bool OCCTDocumentVariableDesassignExpression(OCCTDocumentRef document, int labelTag) {
    try {
        TDF_Label label = getLabelForTag(document, labelTag);
        Handle(TDataStd_Variable) var;
        if (!label.FindAttribute(TDataStd_Variable::GetID(), var)) return false;
        var->Desassign();
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentVariableIsAssigned(OCCTDocumentRef document, int labelTag) {
    try {
        TDF_Label label = getLabelForTag(document, labelTag);
        Handle(TDataStd_Variable) var;
        if (!label.FindAttribute(TDataStd_Variable::GetID(), var)) return false;
        return var->IsAssigned();
    } catch (...) { return false; }
}

// --- TDocStd_XLink ---

bool OCCTDocumentXLinkSet(OCCTDocumentRef document, int labelTag) {
    try {
        TDF_Label label = getLabelForTag(document, labelTag);
        Handle(TDocStd_XLink) xlink = TDocStd_XLink::Set(label);
        return !xlink.IsNull();
    } catch (...) { return false; }
}

bool OCCTDocumentXLinkSetDocumentEntry(OCCTDocumentRef document, int labelTag, const char* entry) {
    try {
        TDF_Label label = getLabelForTag(document, labelTag);
        Handle(TDocStd_XLink) xlink;
        if (!label.FindAttribute(TDocStd_XLink::GetID(), xlink)) return false;
        xlink->DocumentEntry(TCollection_AsciiString(entry));
        return true;
    } catch (...) { return false; }
}

const char* OCCTDocumentXLinkGetDocumentEntry(OCCTDocumentRef document, int labelTag) {
    try {
        TDF_Label label = getLabelForTag(document, labelTag);
        Handle(TDocStd_XLink) xlink;
        if (!label.FindAttribute(TDocStd_XLink::GetID(), xlink)) return nullptr;
        TCollection_AsciiString entry = xlink->DocumentEntry();
        char* result = (char*)malloc(entry.Length() + 1);
        strcpy(result, entry.ToCString());
        return result;
    } catch (...) { return nullptr; }
}

bool OCCTDocumentXLinkSetLabelEntry(OCCTDocumentRef document, int labelTag, const char* entry) {
    try {
        TDF_Label label = getLabelForTag(document, labelTag);
        Handle(TDocStd_XLink) xlink;
        if (!label.FindAttribute(TDocStd_XLink::GetID(), xlink)) return false;
        xlink->LabelEntry(TCollection_AsciiString(entry));
        return true;
    } catch (...) { return false; }
}

const char* OCCTDocumentXLinkGetLabelEntry(OCCTDocumentRef document, int labelTag) {
    try {
        TDF_Label label = getLabelForTag(document, labelTag);
        Handle(TDocStd_XLink) xlink;
        if (!label.FindAttribute(TDocStd_XLink::GetID(), xlink)) return nullptr;
        TCollection_AsciiString entry = xlink->LabelEntry();
        char* result = (char*)malloc(entry.Length() + 1);
        strcpy(result, entry.ToCString());
        return result;
    } catch (...) { return nullptr; }
}

// --- XCAFDimTolObjects_Tool ---

int OCCTDocumentDimTolDimensionCount(OCCTDocumentRef document) {
    try {
        XCAFDimTolObjects_Tool tool(document->doc);
        NCollection_Sequence<Handle(XCAFDimTolObjects_DimensionObject)> dims;
        tool.GetDimensions(dims);
        return dims.Size();
    } catch (...) { return 0; }
}

int OCCTDocumentDimTolToleranceCount(OCCTDocumentRef document) {
    try {
        XCAFDimTolObjects_Tool tool(document->doc);
        NCollection_Sequence<Handle(XCAFDimTolObjects_GeomToleranceObject)> tols;
        NCollection_Sequence<Handle(XCAFDimTolObjects_DatumObject)> datums;
        NCollection_DataMap<Handle(XCAFDimTolObjects_GeomToleranceObject), Handle(XCAFDimTolObjects_DatumObject)> datumMap;
        tool.GetGeomTolerances(tols, datums, datumMap);
        return tols.Size();
    } catch (...) { return 0; }
}

// --- TPrsStd_DriverTable ---

void OCCTDriverTableInitStandard() {
    try {
        Handle(TPrsStd_DriverTable) table = TPrsStd_DriverTable::Get();
        table->InitStandardDrivers();
    } catch (...) { }
}

bool OCCTDriverTableExists() {
    try {
        Handle(TPrsStd_DriverTable) table = TPrsStd_DriverTable::Get();
        return !table.IsNull();
    } catch (...) { return false; }
}

void OCCTDriverTableClear() {
    try {
        Handle(TPrsStd_DriverTable) table = TPrsStd_DriverTable::Get();
        if (!table.IsNull()) table->Clear();
    } catch (...) { }
}

// --- TObj_Application ---

OCCTTObjAppRef OCCTTObjApplicationGetInstance() {
    try {
        Handle(TObj_Application) app = TObj_Application::GetInstance();
        if (app.IsNull()) return nullptr;
        // Prevent reference count from going to 0
        app->IncrementRefCounter();
        return app.get();
    } catch (...) { return nullptr; }
}

void OCCTTObjApplicationSetVerbose(OCCTTObjAppRef app, bool verbose) {
    try {
        auto* a = static_cast<TObj_Application*>(app);
        a->SetVerbose(verbose);
    } catch (...) { }
}

bool OCCTTObjApplicationIsVerbose(OCCTTObjAppRef app) {
    try {
        auto* a = static_cast<TObj_Application*>(app);
        return a->IsVerbose();
    } catch (...) { return false; }
}

OCCTDocumentRef OCCTTObjApplicationCreateDocument(OCCTTObjAppRef app) {
    try {
        auto* a = static_cast<TObj_Application*>(app);
        Handle(TObj_Application) hApp(a);
        Handle(TDocStd_Document) doc;
        TCollection_ExtendedString format("BinOcaf");
        if (!hApp->CreateNewDocument(doc, format)) return nullptr;
        if (doc.IsNull()) return nullptr;
        // Wrap in OCCTDocument struct
        OCCTDocument* result = new OCCTDocument();
        result->doc = doc;
        return result;
    } catch (...) { return nullptr; }
}


// MARK: - TDF_IDFilter (v0.85)
// --- TDF_IDFilter ---

OCCTIDFilterRef OCCTIDFilterCreate(bool ignoreAll) {
    try {
        TDF_IDFilter* filter = new TDF_IDFilter(ignoreAll);
        return filter;
    } catch (...) { return nullptr; }
}

void OCCTIDFilterRelease(OCCTIDFilterRef filter) {
    try {
        auto* f = static_cast<TDF_IDFilter*>(filter);
        delete f;
    } catch (...) { }
}

bool OCCTIDFilterIgnoreAll(OCCTIDFilterRef filter) {
    try {
        auto* f = static_cast<TDF_IDFilter*>(filter);
        return f->IgnoreAll();
    } catch (...) { return false; }
}

void OCCTIDFilterSetIgnoreAll(OCCTIDFilterRef filter, bool ignoreAll) {
    try {
        auto* f = static_cast<TDF_IDFilter*>(filter);
        f->IgnoreAll(ignoreAll);
    } catch (...) { }
}

void OCCTIDFilterKeep(OCCTIDFilterRef filter, const char* guidString) {
    try {
        auto* f = static_cast<TDF_IDFilter*>(filter);
        Standard_GUID guid(guidString);
        f->Keep(guid);
    } catch (...) { }
}

void OCCTIDFilterIgnore(OCCTIDFilterRef filter, const char* guidString) {
    try {
        auto* f = static_cast<TDF_IDFilter*>(filter);
        Standard_GUID guid(guidString);
        f->Ignore(guid);
    } catch (...) { }
}

bool OCCTIDFilterIsKept(OCCTIDFilterRef filter, const char* guidString) {
    try {
        auto* f = static_cast<TDF_IDFilter*>(filter);
        Standard_GUID guid(guidString);
        return f->IsKept(guid);
    } catch (...) { return false; }
}

bool OCCTIDFilterIsIgnored(OCCTIDFilterRef filter, const char* guidString) {
    try {
        auto* f = static_cast<TDF_IDFilter*>(filter);
        Standard_GUID guid(guidString);
        return f->IsIgnored(guid);
    } catch (...) { return false; }
}

// MARK: - TDataStd Boolean/Byte/Integer/Real/ExtString/Reference Arrays + Lists (v0.85)
// MARK: - TDataStd_BooleanArray

#include <TDataStd_BooleanArray.hxx>

bool OCCTDocumentSetBooleanArray(OCCTDocumentRef document, int tag,
                                  int lower, int upper,
                                  const bool* values, int count) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        auto arr = TDataStd_BooleanArray::Set(label, lower, upper);
        int len = upper - lower + 1;
        for (int i = 0; i < len && i < count; i++) {
            arr->SetValue(lower + i, values[i]);
        }
        return true;
    } catch (...) { return false; }
}

int OCCTDocumentGetBooleanArray(OCCTDocumentRef document, int tag,
                                 bool* values, int maxCount) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_BooleanArray) arr;
        if (!label.FindAttribute(TDataStd_BooleanArray::GetID(), arr)) return -1;
        int len = arr->Length();
        if (values) {
            int n = std::min(len, maxCount);
            for (int i = 0; i < n; i++) {
                values[i] = arr->Value(arr->Lower() + i);
            }
        }
        return len;
    } catch (...) { return -1; }
}

bool OCCTDocumentHasBooleanArray(OCCTDocumentRef document, int tag) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_BooleanArray) arr;
        return label.FindAttribute(TDataStd_BooleanArray::GetID(), arr);
    } catch (...) { return false; }
}

// MARK: - TDataStd_BooleanList

#include <TDataStd_BooleanList.hxx>

bool OCCTDocumentSetBooleanList(OCCTDocumentRef document, int tag,
                                 const bool* values, int count) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        auto lst = TDataStd_BooleanList::Set(label);
        lst->Clear();
        for (int i = 0; i < count; i++) {
            lst->Append(values[i]);
        }
        return true;
    } catch (...) { return false; }
}

int OCCTDocumentGetBooleanList(OCCTDocumentRef document, int tag,
                                bool* values, int maxCount) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_BooleanList) lst;
        if (!label.FindAttribute(TDataStd_BooleanList::GetID(), lst)) return -1;
        int count = lst->Extent();
        if (values) {
            int i = 0;
            for (auto it = lst->List().cbegin(); it != lst->List().cend() && i < maxCount; ++it, ++i) {
                values[i] = (*it != 0);
            }
        }
        return count;
    } catch (...) { return -1; }
}

bool OCCTDocumentBooleanListAppend(OCCTDocumentRef document, int tag, bool value) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_BooleanList) lst;
        if (!label.FindAttribute(TDataStd_BooleanList::GetID(), lst)) {
            lst = TDataStd_BooleanList::Set(label);
        }
        lst->Append(value);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentBooleanListClear(OCCTDocumentRef document, int tag) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_BooleanList) lst;
        if (!label.FindAttribute(TDataStd_BooleanList::GetID(), lst)) return false;
        lst->Clear();
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentHasBooleanList(OCCTDocumentRef document, int tag) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_BooleanList) lst;
        return label.FindAttribute(TDataStd_BooleanList::GetID(), lst);
    } catch (...) { return false; }
}

// MARK: - TDataStd_ByteArray

#include <TDataStd_ByteArray.hxx>

bool OCCTDocumentSetByteArray(OCCTDocumentRef document, int tag,
                               int lower, int upper,
                               const uint8_t* values, int count) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        auto arr = TDataStd_ByteArray::Set(label, lower, upper);
        int len = upper - lower + 1;
        for (int i = 0; i < len && i < count; i++) {
            arr->SetValue(lower + i, values[i]);
        }
        return true;
    } catch (...) { return false; }
}

int OCCTDocumentGetByteArray(OCCTDocumentRef document, int tag,
                              uint8_t* values, int maxCount) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_ByteArray) arr;
        if (!label.FindAttribute(TDataStd_ByteArray::GetID(), arr)) return -1;
        int len = arr->Length();
        if (values) {
            int n = std::min(len, maxCount);
            for (int i = 0; i < n; i++) {
                values[i] = arr->Value(arr->Lower() + i);
            }
        }
        return len;
    } catch (...) { return -1; }
}

bool OCCTDocumentHasByteArray(OCCTDocumentRef document, int tag) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_ByteArray) arr;
        return label.FindAttribute(TDataStd_ByteArray::GetID(), arr);
    } catch (...) { return false; }
}

// MARK: - TDataStd_IntegerList

#include <TDataStd_IntegerList.hxx>

bool OCCTDocumentSetIntegerList(OCCTDocumentRef document, int tag,
                                 const int* values, int count) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        auto lst = TDataStd_IntegerList::Set(label);
        lst->Clear();
        for (int i = 0; i < count; i++) {
            lst->Append(values[i]);
        }
        return true;
    } catch (...) { return false; }
}

int OCCTDocumentGetIntegerList(OCCTDocumentRef document, int tag,
                                int* values, int maxCount) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_IntegerList) lst;
        if (!label.FindAttribute(TDataStd_IntegerList::GetID(), lst)) return -1;
        int count = lst->Extent();
        if (values) {
            int i = 0;
            for (auto it = lst->List().cbegin(); it != lst->List().cend() && i < maxCount; ++it, ++i) {
                values[i] = *it;
            }
        }
        return count;
    } catch (...) { return -1; }
}

bool OCCTDocumentIntegerListAppend(OCCTDocumentRef document, int tag, int value) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_IntegerList) lst;
        if (!label.FindAttribute(TDataStd_IntegerList::GetID(), lst)) {
            lst = TDataStd_IntegerList::Set(label);
        }
        lst->Append(value);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentIntegerListClear(OCCTDocumentRef document, int tag) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_IntegerList) lst;
        if (!label.FindAttribute(TDataStd_IntegerList::GetID(), lst)) return false;
        lst->Clear();
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentHasIntegerList(OCCTDocumentRef document, int tag) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_IntegerList) lst;
        return label.FindAttribute(TDataStd_IntegerList::GetID(), lst);
    } catch (...) { return false; }
}

// MARK: - TDataStd_RealList

#include <TDataStd_RealList.hxx>

bool OCCTDocumentSetRealList(OCCTDocumentRef document, int tag,
                              const double* values, int count) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        auto lst = TDataStd_RealList::Set(label);
        lst->Clear();
        for (int i = 0; i < count; i++) {
            lst->Append(values[i]);
        }
        return true;
    } catch (...) { return false; }
}

int OCCTDocumentGetRealList(OCCTDocumentRef document, int tag,
                             double* values, int maxCount) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_RealList) lst;
        if (!label.FindAttribute(TDataStd_RealList::GetID(), lst)) return -1;
        int count = lst->Extent();
        if (values) {
            int i = 0;
            for (auto it = lst->List().cbegin(); it != lst->List().cend() && i < maxCount; ++it, ++i) {
                values[i] = *it;
            }
        }
        return count;
    } catch (...) { return -1; }
}

bool OCCTDocumentRealListAppend(OCCTDocumentRef document, int tag, double value) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_RealList) lst;
        if (!label.FindAttribute(TDataStd_RealList::GetID(), lst)) {
            lst = TDataStd_RealList::Set(label);
        }
        lst->Append(value);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentRealListClear(OCCTDocumentRef document, int tag) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_RealList) lst;
        if (!label.FindAttribute(TDataStd_RealList::GetID(), lst)) return false;
        lst->Clear();
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentHasRealList(OCCTDocumentRef document, int tag) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_RealList) lst;
        return label.FindAttribute(TDataStd_RealList::GetID(), lst);
    } catch (...) { return false; }
}

// MARK: - TDataStd_ExtStringArray

#include <TDataStd_ExtStringArray.hxx>

bool OCCTDocumentSetExtStringArray(OCCTDocumentRef document, int tag,
                                    int lower, int upper,
                                    const char* const* values, int count) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        auto arr = TDataStd_ExtStringArray::Set(label, lower, upper);
        int len = upper - lower + 1;
        for (int i = 0; i < len && i < count; i++) {
            arr->SetValue(lower + i, TCollection_ExtendedString(values[i], true));
        }
        return true;
    } catch (...) { return false; }
}

char* OCCTDocumentGetExtStringArrayValue(OCCTDocumentRef document, int tag, int index) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_ExtStringArray) arr;
        if (!label.FindAttribute(TDataStd_ExtStringArray::GetID(), arr)) return nullptr;
        if (index < arr->Lower() || index > arr->Upper()) return nullptr;
        TCollection_ExtendedString val = arr->Value(index);
        TCollection_AsciiString ascii(val);
        return strdup(ascii.ToCString());
    } catch (...) { return nullptr; }
}

int OCCTDocumentGetExtStringArrayLength(OCCTDocumentRef document, int tag) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_ExtStringArray) arr;
        if (!label.FindAttribute(TDataStd_ExtStringArray::GetID(), arr)) return -1;
        return arr->Length();
    } catch (...) { return -1; }
}

bool OCCTDocumentHasExtStringArray(OCCTDocumentRef document, int tag) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_ExtStringArray) arr;
        return label.FindAttribute(TDataStd_ExtStringArray::GetID(), arr);
    } catch (...) { return false; }
}

// MARK: - TDataStd_ExtStringList

#include <TDataStd_ExtStringList.hxx>

bool OCCTDocumentSetExtStringList(OCCTDocumentRef document, int tag,
                                   const char* const* values, int count) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        auto lst = TDataStd_ExtStringList::Set(label);
        lst->Clear();
        for (int i = 0; i < count; i++) {
            lst->Append(TCollection_ExtendedString(values[i], true));
        }
        return true;
    } catch (...) { return false; }
}

int OCCTDocumentGetExtStringListCount(OCCTDocumentRef document, int tag) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_ExtStringList) lst;
        if (!label.FindAttribute(TDataStd_ExtStringList::GetID(), lst)) return -1;
        return lst->Extent();
    } catch (...) { return -1; }
}

char* OCCTDocumentGetExtStringListValue(OCCTDocumentRef document, int tag, int index) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_ExtStringList) lst;
        if (!label.FindAttribute(TDataStd_ExtStringList::GetID(), lst)) return nullptr;
        int i = 0;
        for (auto it = lst->List().cbegin(); it != lst->List().cend(); ++it, ++i) {
            if (i == index) {
                TCollection_AsciiString ascii(*it);
                return strdup(ascii.ToCString());
            }
        }
        return nullptr;
    } catch (...) { return nullptr; }
}

bool OCCTDocumentExtStringListAppend(OCCTDocumentRef document, int tag, const char* value) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_ExtStringList) lst;
        if (!label.FindAttribute(TDataStd_ExtStringList::GetID(), lst)) {
            lst = TDataStd_ExtStringList::Set(label);
        }
        lst->Append(TCollection_ExtendedString(value, true));
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentExtStringListClear(OCCTDocumentRef document, int tag) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_ExtStringList) lst;
        if (!label.FindAttribute(TDataStd_ExtStringList::GetID(), lst)) return false;
        lst->Clear();
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentHasExtStringList(OCCTDocumentRef document, int tag) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_ExtStringList) lst;
        return label.FindAttribute(TDataStd_ExtStringList::GetID(), lst);
    } catch (...) { return false; }
}

// MARK: - TDataStd_ReferenceArray

#include <TDataStd_ReferenceArray.hxx>

bool OCCTDocumentSetReferenceArray(OCCTDocumentRef document, int tag,
                                    int lower, int upper,
                                    const int* refTags, int count) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        TDF_Label main = document->doc->Main();
        auto arr = TDataStd_ReferenceArray::Set(label, lower, upper);
        int len = upper - lower + 1;
        for (int i = 0; i < len && i < count; i++) {
            arr->SetValue(lower + i, main.FindChild(refTags[i]));
        }
        return true;
    } catch (...) { return false; }
}

int OCCTDocumentGetReferenceArray(OCCTDocumentRef document, int tag,
                                   int* refTags, int maxCount) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_ReferenceArray) arr;
        if (!label.FindAttribute(TDataStd_ReferenceArray::GetID(), arr)) return -1;
        int len = arr->Length();
        if (refTags) {
            int n = std::min(len, maxCount);
            for (int i = 0; i < n; i++) {
                refTags[i] = arr->Value(arr->Lower() + i).Tag();
            }
        }
        return len;
    } catch (...) { return -1; }
}

bool OCCTDocumentHasReferenceArray(OCCTDocumentRef document, int tag) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_ReferenceArray) arr;
        return label.FindAttribute(TDataStd_ReferenceArray::GetID(), arr);
    } catch (...) { return false; }
}

// MARK: - TDataStd_ReferenceList

#include <TDataStd_ReferenceList.hxx>

bool OCCTDocumentSetReferenceList(OCCTDocumentRef document, int tag,
                                   const int* refTags, int count) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        TDF_Label main = document->doc->Main();
        auto lst = TDataStd_ReferenceList::Set(label);
        lst->Clear();
        for (int i = 0; i < count; i++) {
            lst->Append(main.FindChild(refTags[i]));
        }
        return true;
    } catch (...) { return false; }
}

int OCCTDocumentGetReferenceList(OCCTDocumentRef document, int tag,
                                  int* refTags, int maxCount) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_ReferenceList) lst;
        if (!label.FindAttribute(TDataStd_ReferenceList::GetID(), lst)) return -1;
        int count = lst->Extent();
        if (refTags) {
            int i = 0;
            for (auto it = lst->List().cbegin(); it != lst->List().cend() && i < maxCount; ++it, ++i) {
                refTags[i] = (*it).Tag();
            }
        }
        return count;
    } catch (...) { return -1; }
}

bool OCCTDocumentReferenceListAppend(OCCTDocumentRef document, int tag, int refTag) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        TDF_Label main = document->doc->Main();
        Handle(TDataStd_ReferenceList) lst;
        if (!label.FindAttribute(TDataStd_ReferenceList::GetID(), lst)) {
            lst = TDataStd_ReferenceList::Set(label);
        }
        lst->Append(main.FindChild(refTag));
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentReferenceListClear(OCCTDocumentRef document, int tag) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_ReferenceList) lst;
        if (!label.FindAttribute(TDataStd_ReferenceList::GetID(), lst)) return false;
        lst->Clear();
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentHasReferenceList(OCCTDocumentRef document, int tag) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_ReferenceList) lst;
        return label.FindAttribute(TDataStd_ReferenceList::GetID(), lst);
    } catch (...) { return false; }
}

// MARK: - TDataStd_Relation

#include <TDataStd_Relation.hxx>

bool OCCTDocumentSetRelation(OCCTDocumentRef document, int tag, const char* relation) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        auto rel = TDataStd_Relation::Set(label);
        rel->SetRelation(TCollection_ExtendedString(relation, true));
        return true;
    } catch (...) { return false; }
}

char* OCCTDocumentGetRelation(OCCTDocumentRef document, int tag) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_Relation) rel;
        if (!label.FindAttribute(TDataStd_Relation::GetID(), rel)) return nullptr;
        TCollection_AsciiString ascii(rel->GetRelation());
        return strdup(ascii.ToCString());
    } catch (...) { return nullptr; }
}

bool OCCTDocumentHasRelation(OCCTDocumentRef document, int tag) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_Relation) rel;
        return label.FindAttribute(TDataStd_Relation::GetID(), rel);
    } catch (...) { return false; }
}

// MARK: - TDataStd Tick + Current (v0.85)
// MARK: - TDataStd_Tick

#include <TDataStd_Tick.hxx>

bool OCCTDocumentSetTick(OCCTDocumentRef document, int tag) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        TDataStd_Tick::Set(label);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentHasTick(OCCTDocumentRef document, int tag) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_Tick) tick;
        return label.FindAttribute(TDataStd_Tick::GetID(), tick);
    } catch (...) { return false; }
}

bool OCCTDocumentRemoveTick(OCCTDocumentRef document, int tag) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        Handle(TDataStd_Tick) tick;
        if (!label.FindAttribute(TDataStd_Tick::GetID(), tick)) return false;
        label.ForgetAttribute(TDataStd_Tick::GetID());
        return true;
    } catch (...) { return false; }
}

// MARK: - TDataStd_Current

#include <TDataStd_Current.hxx>

bool OCCTDocumentSetCurrentLabel(OCCTDocumentRef document, int tag) {
    try {
        TDF_Label label = getLabelForTag(document, tag);
        TDataStd_Current::Set(label);
        return true;
    } catch (...) { return false; }
}

int OCCTDocumentGetCurrentLabel(OCCTDocumentRef document) {
    try {
        TDF_Label root = document->doc->Main();
        if (!TDataStd_Current::Has(root)) return -1;
        TDF_Label current = TDataStd_Current::Get(root);
        return current.Tag();
    } catch (...) { return -1; }
}

bool OCCTDocumentHasCurrentLabel(OCCTDocumentRef document) {
    try {
        TDF_Label root = document->doc->Main();
        return TDataStd_Current::Has(root);
    } catch (...) { return false; }
}

// MARK: - TNaming Extensions + TDataStd_IntPackedMap/NoteBook/UAttribute/ChildNodeIterator + TDF_Transaction/Delta/ComparisonTool + TDocStd_XLinkTool + TFunction_IFunction/Scope + TDF_AttributeIterator/DataSet (v0.88-v0.89)
// MARK: - TNaming Extensions (v0.88.0)

#include <TNaming_SameShapeIterator.hxx>
#include <TDataStd_IntPackedMap.hxx>
#include <TDataStd_NoteBook.hxx>
#include <TDataStd_UAttribute.hxx>
#include <TDataStd_ChildNodeIterator.hxx>
#include <TColStd_HPackedMapOfInteger.hxx>
#include <TColStd_PackedMapOfInteger.hxx>

bool OCCTNamingIsEmpty(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return true;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return true;
        Handle(TNaming_NamedShape) ns;
        if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns)) return true;
        return ns->IsEmpty();
    } catch (...) { return true; }
}

int OCCTNamingGetVersion(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return 0;
        Handle(TNaming_NamedShape) ns;
        if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns)) return 0;
        return ns->Version();
    } catch (...) { return 0; }
}

bool OCCTNamingSetVersion(OCCTDocumentRef doc, int64_t labelId, int version) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TNaming_NamedShape) ns;
        if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns)) return false;
        ns->SetVersion(version);
        return true;
    } catch (...) { return false; }
}

OCCTShapeRef OCCTNamingOriginalShape(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return nullptr;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;
        Handle(TNaming_NamedShape) ns;
        if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns)) return nullptr;
        TopoDS_Shape shape = TNaming_Tool::OriginalShape(ns);
        if (shape.IsNull()) return nullptr;
        auto* ref = new OCCTShape();
        ref->shape = shape;
        return ref;
    } catch (...) { return nullptr; }
}

bool OCCTNamingHasLabel(OCCTDocumentRef doc, OCCTShapeRef shape) {
    if (!doc || doc->doc.IsNull() || !shape) return false;
    try {
        TDF_Label root = doc->doc->Main();
        return TNaming_Tool::HasLabel(root, shape->shape);
    } catch (...) { return false; }
}

int64_t OCCTNamingFindLabel(OCCTDocumentRef doc, OCCTShapeRef shape) {
    if (!doc || doc->doc.IsNull() || !shape) return -1;
    try {
        TDF_Label root = doc->doc->Main();
        int transDef = 0;
        TDF_Label label = TNaming_Tool::Label(root, shape->shape, transDef);
        if (label.IsNull()) return -1;
        // Find the label in the document's label array
        for (int64_t i = 0; i < (int64_t)doc->labels.size(); i++) {
            if (doc->labels[i].IsEqual(label)) return i;
        }
        // Label exists but not in our array — register it
        return doc->registerLabel(label);
    } catch (...) { return -1; }
}

int OCCTNamingValidUntil(OCCTDocumentRef doc, OCCTShapeRef shape) {
    if (!doc || doc->doc.IsNull() || !shape) return -1;
    try {
        TDF_Label root = doc->doc->Main();
        return TNaming_Tool::ValidUntil(root, shape->shape);
    } catch (...) { return -1; }
}

// MARK: - TNaming_SameShapeIterator

int32_t OCCTNamingSameShapeCount(OCCTDocumentRef doc, OCCTShapeRef shape) {
    if (!doc || doc->doc.IsNull() || !shape) return 0;
    try {
        TDF_Label root = doc->doc->Main();
        int count = 0;
        for (TNaming_SameShapeIterator it(shape->shape, root); it.More(); it.Next()) count++;
        return count;
    } catch (...) { return 0; }
}

int32_t OCCTNamingSameShapeLabels(OCCTDocumentRef doc, OCCTShapeRef shape,
                                   int64_t* outLabelIds, int32_t maxCount) {
    if (!doc || doc->doc.IsNull() || !shape || !outLabelIds || maxCount <= 0) return 0;
    try {
        TDF_Label root = doc->doc->Main();
        int32_t i = 0;
        for (TNaming_SameShapeIterator it(shape->shape, root); it.More() && i < maxCount; it.Next()) {
            TDF_Label label = it.Label();
            // Find or register the label
            int64_t labelId = -1;
            for (int64_t j = 0; j < (int64_t)doc->labels.size(); j++) {
                if (doc->labels[j].IsEqual(label)) { labelId = j; break; }
            }
            if (labelId < 0) labelId = doc->registerLabel(label);
            outLabelIds[i] = labelId;
            i++;
        }
        return i;
    } catch (...) { return 0; }
}

// MARK: - TDataStd_IntPackedMap

bool OCCTIntPackedMapSet(OCCTDocumentRef doc, int tag, bool isDelta) {
    try {
        TDF_Label label = getLabelForTag(doc, tag);
        Handle(TDataStd_IntPackedMap) attr = TDataStd_IntPackedMap::Set(label, isDelta);
        return !attr.IsNull();
    } catch (...) { return false; }
}

bool OCCTIntPackedMapAdd(OCCTDocumentRef doc, int tag, int value) {
    try {
        TDF_Label label = getLabelForTag(doc, tag);
        Handle(TDataStd_IntPackedMap) attr;
        if (!label.FindAttribute(TDataStd_IntPackedMap::GetID(), attr)) return false;
        return attr->Add(value);
    } catch (...) { return false; }
}

bool OCCTIntPackedMapRemove(OCCTDocumentRef doc, int tag, int value) {
    try {
        TDF_Label label = getLabelForTag(doc, tag);
        Handle(TDataStd_IntPackedMap) attr;
        if (!label.FindAttribute(TDataStd_IntPackedMap::GetID(), attr)) return false;
        return attr->Remove(value);
    } catch (...) { return false; }
}

bool OCCTIntPackedMapContains(OCCTDocumentRef doc, int tag, int value) {
    try {
        TDF_Label label = getLabelForTag(doc, tag);
        Handle(TDataStd_IntPackedMap) attr;
        if (!label.FindAttribute(TDataStd_IntPackedMap::GetID(), attr)) return false;
        return attr->Contains(value);
    } catch (...) { return false; }
}

int OCCTIntPackedMapExtent(OCCTDocumentRef doc, int tag) {
    try {
        TDF_Label label = getLabelForTag(doc, tag);
        Handle(TDataStd_IntPackedMap) attr;
        if (!label.FindAttribute(TDataStd_IntPackedMap::GetID(), attr)) return 0;
        return attr->Extent();
    } catch (...) { return 0; }
}

bool OCCTIntPackedMapClear(OCCTDocumentRef doc, int tag) {
    try {
        TDF_Label label = getLabelForTag(doc, tag);
        Handle(TDataStd_IntPackedMap) attr;
        if (!label.FindAttribute(TDataStd_IntPackedMap::GetID(), attr)) return false;
        return attr->Clear();
    } catch (...) { return false; }
}

bool OCCTIntPackedMapIsEmpty(OCCTDocumentRef doc, int tag) {
    try {
        TDF_Label label = getLabelForTag(doc, tag);
        Handle(TDataStd_IntPackedMap) attr;
        if (!label.FindAttribute(TDataStd_IntPackedMap::GetID(), attr)) return true;
        return attr->IsEmpty();
    } catch (...) { return true; }
}

int OCCTIntPackedMapGetValues(OCCTDocumentRef doc, int tag, int** values) {
    try {
        TDF_Label label = getLabelForTag(doc, tag);
        Handle(TDataStd_IntPackedMap) attr;
        if (!label.FindAttribute(TDataStd_IntPackedMap::GetID(), attr)) {
            *values = nullptr; return 0;
        }
        const TColStd_PackedMapOfInteger& map = attr->GetMap();
        int count = map.Extent();
        if (count == 0) { *values = nullptr; return 0; }

        *values = (int*)malloc(count * sizeof(int));
        int i = 0;
        for (TColStd_PackedMapOfInteger::Iterator it(map); it.More(); it.Next()) {
            (*values)[i] = it.Key();
            i++;
        }
        return count;
    } catch (...) { *values = nullptr; return 0; }
}

void OCCTIntPackedMapFreeValues(int* values) {
    if (values) free(values);
}

bool OCCTIntPackedMapChangeValues(OCCTDocumentRef doc, int tag,
                                    const int* values, int count) {
    try {
        TDF_Label label = getLabelForTag(doc, tag);
        Handle(TDataStd_IntPackedMap) attr;
        if (!label.FindAttribute(TDataStd_IntPackedMap::GetID(), attr)) return false;
        TColStd_PackedMapOfInteger newMap;
        for (int i = 0; i < count; i++) {
            newMap.Add(values[i]);
        }
        return attr->ChangeMap(newMap);
    } catch (...) { return false; }
}

// MARK: - TDataStd_NoteBook

bool OCCTNoteBookNew(OCCTDocumentRef doc, int tag) {
    try {
        TDF_Label label = getLabelForTag(doc, tag);
        Handle(TDataStd_NoteBook) nb = TDataStd_NoteBook::New(label);
        return !nb.IsNull();
    } catch (...) { return false; }
}

int OCCTNoteBookAppendReal(OCCTDocumentRef doc, int tag, double value) {
    try {
        TDF_Label label = getLabelForTag(doc, tag);
        Handle(TDataStd_NoteBook) nb;
        if (!label.FindAttribute(TDataStd_NoteBook::GetID(), nb)) return -1;
        Handle(TDataStd_Real) attr = nb->Append(value);
        if (attr.IsNull()) return -1;
        return attr->Label().Tag();
    } catch (...) { return -1; }
}

int OCCTNoteBookAppendInteger(OCCTDocumentRef doc, int tag, int value) {
    try {
        TDF_Label label = getLabelForTag(doc, tag);
        Handle(TDataStd_NoteBook) nb;
        if (!label.FindAttribute(TDataStd_NoteBook::GetID(), nb)) return -1;
        Handle(TDataStd_Integer) attr = nb->Append(value);
        if (attr.IsNull()) return -1;
        return attr->Label().Tag();
    } catch (...) { return -1; }
}

bool OCCTNoteBookFind(OCCTDocumentRef doc, int tag) {
    try {
        TDF_Label label = getLabelForTag(doc, tag);
        Handle(TDataStd_NoteBook) nb;
        return TDataStd_NoteBook::Find(label, nb);
    } catch (...) { return false; }
}

// MARK: - TDataStd_UAttribute

bool OCCTUAttributeSet(OCCTDocumentRef doc, int tag, const char* guidString) {
    try {
        TDF_Label label = getLabelForTag(doc, tag);
        Standard_GUID guid(guidString);
        Handle(TDataStd_UAttribute) attr = TDataStd_UAttribute::Set(label, guid);
        return !attr.IsNull();
    } catch (...) { return false; }
}

bool OCCTUAttributeHas(OCCTDocumentRef doc, int tag, const char* guidString) {
    try {
        TDF_Label label = getLabelForTag(doc, tag);
        Standard_GUID guid(guidString);
        Handle(TDataStd_UAttribute) attr;
        return label.FindAttribute(guid, attr);
    } catch (...) { return false; }
}

const char* OCCTUAttributeGetID(OCCTDocumentRef doc, int tag, const char* guidString) {
    try {
        TDF_Label label = getLabelForTag(doc, tag);
        Standard_GUID guid(guidString);
        Handle(TDataStd_UAttribute) attr;
        if (!label.FindAttribute(guid, attr)) return nullptr;

        const Standard_GUID& id = attr->ID();
        Standard_SStream ss;
        id.ShallowDump(ss);
        std::string str = ss.str();
        return strdup(str.c_str());
    } catch (...) { return nullptr; }
}

void OCCTUAttributeFreeGUID(const char* guidString) {
    if (guidString) free((void*)guidString);
}

// MARK: - TDataStd_ChildNodeIterator

int OCCTChildNodeIteratorCount(OCCTDocumentRef doc, int tag, bool allLevels) {
    try {
        TDF_Label label = getLabelForTag(doc, tag);
        Handle(TDataStd_TreeNode) node;
        if (!label.FindAttribute(TDataStd_TreeNode::GetDefaultTreeID(), node)) return 0;

        int count = 0;
        for (TDataStd_ChildNodeIterator it(node, allLevels); it.More(); it.Next()) count++;
        return count;
    } catch (...) { return 0; }
}

// MARK: - TDF_Transaction Named (v0.89.0)

#include <TDF_Transaction.hxx>
#include <TDF_Delta.hxx>
#include <TDF_CopyTool.hxx>
#include <TDF_ComparisonTool.hxx>
#include <TDF_DataSet.hxx>
#include <TDF_RelocationTable.hxx>
#include <TDF_AttributeIterator.hxx>
#include <TDocStd_XLinkTool.hxx>
#include <TDocStd_MultiTransactionManager.hxx>
#include <TFunction_IFunction.hxx>
#include <TFunction_Iterator.hxx>
#include <TFunction_Scope.hxx>

int32_t OCCTDocumentOpenNamedTransaction(OCCTDocumentRef doc, const char* name) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        doc->doc->OpenCommand();
        return doc->doc->HasOpenCommand() ? 1 : 0;
    } catch (...) { return 0; }
}

void* OCCTDocumentCommitWithDelta(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return nullptr;
    try {
        doc->doc->SetUndoLimit(100);
        bool ok = doc->doc->CommitCommand();
        if (!ok) return nullptr;
        auto& undos = doc->doc->GetUndos();
        if (undos.IsEmpty()) return nullptr;
        Handle(TDF_Delta)* deltaPtr = new Handle(TDF_Delta)(undos.Last());
        return static_cast<void*>(deltaPtr);
    } catch (...) { return nullptr; }
}

int32_t OCCTDocumentGetTransactionNumber(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        return doc->doc->HasOpenCommand() ? 1 : 0;
    } catch (...) { return 0; }
}

// MARK: - TDF_Delta (v0.89.0)

bool OCCTDeltaIsEmpty(void* delta) {
    try {
        auto* ptr = static_cast<Handle(TDF_Delta)*>(delta);
        return (*ptr)->IsEmpty();
    } catch (...) { return true; }
}

int32_t OCCTDeltaBeginTime(void* delta) {
    try {
        auto* ptr = static_cast<Handle(TDF_Delta)*>(delta);
        return (*ptr)->BeginTime();
    } catch (...) { return -1; }
}

int32_t OCCTDeltaEndTime(void* delta) {
    try {
        auto* ptr = static_cast<Handle(TDF_Delta)*>(delta);
        return (*ptr)->EndTime();
    } catch (...) { return -1; }
}

int32_t OCCTDeltaAttributeDeltaCount(void* delta) {
    try {
        auto* ptr = static_cast<Handle(TDF_Delta)*>(delta);
        return (*ptr)->AttributeDeltas().Size();
    } catch (...) { return 0; }
}

void OCCTDeltaSetName(void* delta, const char* name) {
    try {
        auto* ptr = static_cast<Handle(TDF_Delta)*>(delta);
        (*ptr)->SetName(TCollection_ExtendedString(name));
    } catch (...) {}
}

const char* OCCTDeltaGetName(void* delta) {
    try {
        auto* ptr = static_cast<Handle(TDF_Delta)*>(delta);
        TCollection_ExtendedString ename = (*ptr)->Name();
        TCollection_AsciiString aname(ename);
        return strdup(aname.ToCString());
    } catch (...) { return nullptr; }
}

void OCCTDeltaFreeName(const char* name) {
    if (name) free((void*)name);
}

void OCCTDeltaRelease(void* delta) {
    if (delta) {
        auto* ptr = static_cast<Handle(TDF_Delta)*>(delta);
        delete ptr;
    }
}

// MARK: - TDF_ComparisonTool (v0.89.0)

bool OCCTDocumentIsSelfContained(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;

        Handle(TDF_DataSet) ds = new TDF_DataSet();
        ds->AddLabel(label);
        for (TDF_ChildIterator cit(label, true); cit.More(); cit.Next()) {
            ds->AddLabel(cit.Value());
        }
        return TDF_ComparisonTool::IsSelfContained(label, ds);
    } catch (...) { return false; }
}

// MARK: - TDocStd_XLinkTool (v0.89.0)

bool OCCTDocumentXLinkCopy(OCCTDocumentRef doc, int64_t tgtLabelId, int64_t srcLabelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label tgt = doc->getLabel(tgtLabelId);
        TDF_Label src = doc->getLabel(srcLabelId);
        if (src.IsNull() || tgt.IsNull()) return false;

        TDocStd_XLinkTool tool;
        tool.Copy(tgt, src);
        return tool.IsDone();
    } catch (...) { return false; }
}

bool OCCTDocumentXLinkCopyWithLink(OCCTDocumentRef doc, int64_t tgtLabelId, int64_t srcLabelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label tgt = doc->getLabel(tgtLabelId);
        TDF_Label src = doc->getLabel(srcLabelId);
        if (src.IsNull() || tgt.IsNull()) return false;

        TDocStd_XLinkTool tool;
        tool.CopyWithLink(tgt, src);
        return tool.IsDone();
    } catch (...) { return false; }
}

// MARK: - TFunction_IFunction (v0.89.0)

bool OCCTDocumentNewFunction(OCCTDocumentRef doc, int64_t labelId, const char* guidString) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;

        TDF_Label root = doc->doc->GetData()->Root();
        TFunction_Scope::Set(root);

        Standard_GUID guid(guidString);
        TFunction_IFunction::NewFunction(label, guid);
        Handle(TFunction_Function) func;
        return label.FindAttribute(TFunction_Function::GetID(), func);
    } catch (...) { return false; }
}

bool OCCTDocumentDeleteFunction(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        return TFunction_IFunction::DeleteFunction(label);
    } catch (...) { return false; }
}

int32_t OCCTDocumentFunctionGetExecStatus(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return -1;

        Handle(TFunction_Function) func;
        if (!label.FindAttribute(TFunction_Function::GetID(), func)) return -1;

        TFunction_IFunction ifunc(label);
        return (int32_t)ifunc.GetStatus();
    } catch (...) { return -1; }
}

bool OCCTDocumentFunctionSetExecStatus(OCCTDocumentRef doc, int64_t labelId, int32_t status) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;

        Handle(TFunction_Function) func;
        if (!label.FindAttribute(TFunction_Function::GetID(), func)) return false;

        TFunction_IFunction ifunc(label);
        ifunc.SetStatus((TFunction_ExecutionStatus)status);
        return true;
    } catch (...) { return false; }
}

// MARK: - TFunction_Scope (v0.89.0)

bool OCCTDocumentSetFunctionScope(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label root = doc->doc->GetData()->Root();
        Handle(TFunction_Scope) scope = TFunction_Scope::Set(root);
        return !scope.IsNull();
    } catch (...) { return false; }
}

bool OCCTDocumentFunctionScopeAdd(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label root = doc->doc->GetData()->Root();
        Handle(TFunction_Scope) scope;
        if (!root.FindAttribute(TFunction_Scope::GetID(), scope)) return false;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        return scope->AddFunction(label);
    } catch (...) { return false; }
}

bool OCCTDocumentFunctionScopeRemove(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label root = doc->doc->GetData()->Root();
        Handle(TFunction_Scope) scope;
        if (!root.FindAttribute(TFunction_Scope::GetID(), scope)) return false;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        return scope->RemoveFunction(label);
    } catch (...) { return false; }
}

bool OCCTDocumentFunctionScopeHas(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label root = doc->doc->GetData()->Root();
        Handle(TFunction_Scope) scope;
        if (!root.FindAttribute(TFunction_Scope::GetID(), scope)) return false;
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        return scope->HasFunction(label);
    } catch (...) { return false; }
}

bool OCCTDocumentFunctionScopeRemoveAll(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label root = doc->doc->GetData()->Root();
        Handle(TFunction_Scope) scope;
        if (!root.FindAttribute(TFunction_Scope::GetID(), scope)) return false;
        scope->RemoveAllFunctions();
        return true;
    } catch (...) { return false; }
}

int32_t OCCTDocumentFunctionScopeCount(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        TDF_Label root = doc->doc->GetData()->Root();
        Handle(TFunction_Scope) scope;
        if (!root.FindAttribute(TFunction_Scope::GetID(), scope)) return 0;
        return scope->GetFunctions().Extent();
    } catch (...) { return 0; }
}

int32_t OCCTDocumentFunctionScopeGetFreeID(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label root = doc->doc->GetData()->Root();
        Handle(TFunction_Scope) scope;
        if (!root.FindAttribute(TFunction_Scope::GetID(), scope)) return -1;
        return scope->GetFreeID();
    } catch (...) { return -1; }
}

// MARK: - TDF_AttributeIterator (v0.89.0)

int32_t OCCTDocumentAttributeCount(OCCTDocumentRef doc, int64_t labelId, bool withoutForgotten) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return 0;

        int count = 0;
        for (TDF_AttributeIterator it(label, withoutForgotten); it.More(); it.Next()) {
            count++;
        }
        return count;
    } catch (...) { return 0; }
}

// MARK: - TDF_DataSet (v0.89.0)

bool OCCTDocumentDataSetIsEmpty(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return true;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return true;

        Handle(TDF_DataSet) ds = new TDF_DataSet();
        ds->AddLabel(label);
        return ds->IsEmpty();
    } catch (...) { return true; }
}

// MARK: - v0.90: TDF_ChildIDIterator + TDocStd_PathParser + TFunction_DriverTable + TNaming_Scope/Translator + TDataXtd_Placement/Presentation + XCAFDoc_AssemblyIterator/DimTol
// MARK: - TDF_ChildIDIterator (v0.90.0)

#include <TDF_ChildIDIterator.hxx>

int32_t OCCTDocumentChildIDCount(OCCTDocumentRef doc, int64_t labelId,
                                  const char* guidString, bool allLevels) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return 0;
        Standard_GUID guid(guidString);
        int count = 0;
        for (TDF_ChildIDIterator it(label, guid, allLevels); it.More(); it.Next()) {
            count++;
        }
        return count;
    } catch (...) { return 0; }
}

// MARK: - TDocStd_PathParser (v0.90.0)

#include <TDocStd_PathParser.hxx>

const char* OCCTPathParserTrek(const char* path) {
    try {
        TCollection_ExtendedString epath(path);
        TDocStd_PathParser parser(epath);
        TCollection_AsciiString astr(parser.Trek());
        return strdup(astr.ToCString());
    } catch (...) { return nullptr; }
}

const char* OCCTPathParserName(const char* path) {
    try {
        TCollection_ExtendedString epath(path);
        TDocStd_PathParser parser(epath);
        TCollection_AsciiString astr(parser.Name());
        return strdup(astr.ToCString());
    } catch (...) { return nullptr; }
}

const char* OCCTPathParserExtension(const char* path) {
    try {
        TCollection_ExtendedString epath(path);
        TDocStd_PathParser parser(epath);
        TCollection_AsciiString astr(parser.Extension());
        return strdup(astr.ToCString());
    } catch (...) { return nullptr; }
}

void OCCTPathParserFreeString(const char* str) {
    if (str) free((void*)str);
}

// MARK: - TFunction_DriverTable (v0.90.0)

#include <TFunction_DriverTable.hxx>
#include <TFunction_Driver.hxx>

bool OCCTFunctionDriverTableHasDriver(const char* guidString) {
    try {
        Handle(TFunction_DriverTable) table = TFunction_DriverTable::Get();
        if (table.IsNull()) return false;
        Standard_GUID guid(guidString);
        return table->HasDriver(guid);
    } catch (...) { return false; }
}

void OCCTFunctionDriverTableClear() {
    try {
        Handle(TFunction_DriverTable) table = TFunction_DriverTable::Get();
        if (!table.IsNull()) table->Clear();
    } catch (...) {}
}

// MARK: - TNaming_Scope (v0.90.0)

#include <TNaming_Scope.hxx>

static TNaming_Scope& getDocNamingScope() {
    static TNaming_Scope scope(true);
    return scope;
}

bool OCCTDocumentNamingScopeValid(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        getDocNamingScope().Valid(label);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentNamingScopeValidChildren(OCCTDocumentRef doc, int64_t labelId, bool withRoot) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        getDocNamingScope().ValidChildren(label, withRoot);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentNamingScopeIsValid(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        return getDocNamingScope().IsValid(label);
    } catch (...) { return false; }
}

bool OCCTDocumentNamingScopeUnvalid(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        getDocNamingScope().Unvalid(label);
        return true;
    } catch (...) { return false; }
}

void OCCTDocumentNamingScopeClear(OCCTDocumentRef doc) {
    try {
        getDocNamingScope().ClearValid();
    } catch (...) {}
}

int32_t OCCTDocumentNamingScopeValidCount(OCCTDocumentRef doc) {
    try {
        return getDocNamingScope().GetValid().Extent();
    } catch (...) { return 0; }
}
// MARK: - TNaming_Translator (v0.90.0)

#include <TNaming_Translator.hxx>

OCCTShapeRef OCCTShapeTranslatorCopy(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        TNaming_Translator translator;
        translator.Add(shape->shape);
        translator.Perform();
        if (!translator.IsDone()) return nullptr;
        TopoDS_Shape copy = translator.Copied(shape->shape);
        if (copy.IsNull()) return nullptr;
        OCCTShape* result = new OCCTShape();
        result->shape = copy;
        return result;
    } catch (...) { return nullptr; }
}

bool OCCTShapeIsSame(OCCTShapeRef shape1, OCCTShapeRef shape2) {
    if (!shape1 || !shape2) return false;
    return shape1->shape.IsSame(shape2->shape);
}
// MARK: - TDataXtd_Placement (v0.90.0)

#include <TDataXtd_Placement.hxx>

bool OCCTDocumentSetPlacement(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TDataXtd_Placement) p = TDataXtd_Placement::Set(label);
        return !p.IsNull();
    } catch (...) { return false; }
}

bool OCCTDocumentHasPlacement(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TDataXtd_Placement) p;
        return label.FindAttribute(TDataXtd_Placement::GetID(), p);
    } catch (...) { return false; }
}

// MARK: - TDataXtd_Presentation (v0.90.0)

#include <TDataXtd_Presentation.hxx>

bool OCCTDocumentSetPresentation(OCCTDocumentRef doc, int64_t labelId, const char* driverGUID) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Standard_GUID guid(driverGUID);
        Handle(TDataXtd_Presentation) pres = TDataXtd_Presentation::Set(label, guid);
        return !pres.IsNull();
    } catch (...) { return false; }
}

void OCCTDocumentUnsetPresentation(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (!label.IsNull()) TDataXtd_Presentation::Unset(label);
    } catch (...) {}
}

bool OCCTDocumentHasPresentation(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TDataXtd_Presentation) pres;
        return label.FindAttribute(TDataXtd_Presentation::GetID(), pres);
    } catch (...) { return false; }
}

bool OCCTDocumentPresentationSetDisplayed(OCCTDocumentRef doc, int64_t labelId, bool displayed) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(TDataXtd_Presentation) pres;
        if (!label.FindAttribute(TDataXtd_Presentation::GetID(), pres)) return false;
        pres->SetDisplayed(displayed);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentPresentationIsDisplayed(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(TDataXtd_Presentation) pres;
        if (!label.FindAttribute(TDataXtd_Presentation::GetID(), pres)) return false;
        return pres->IsDisplayed();
    } catch (...) { return false; }
}

bool OCCTDocumentPresentationSetColor(OCCTDocumentRef doc, int64_t labelId, int32_t colorIndex) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(TDataXtd_Presentation) pres;
        if (!label.FindAttribute(TDataXtd_Presentation::GetID(), pres)) return false;
        pres->SetColor((Quantity_NameOfColor)colorIndex);
        return true;
    } catch (...) { return false; }
}

int32_t OCCTDocumentPresentationGetColor(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(TDataXtd_Presentation) pres;
        if (!label.FindAttribute(TDataXtd_Presentation::GetID(), pres)) return -1;
        if (!pres->HasOwnColor()) return -1;
        return (int32_t)pres->Color();
    } catch (...) { return -1; }
}

bool OCCTDocumentPresentationSetTransparency(OCCTDocumentRef doc, int64_t labelId, double value) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(TDataXtd_Presentation) pres;
        if (!label.FindAttribute(TDataXtd_Presentation::GetID(), pres)) return false;
        pres->SetTransparency(value);
        return true;
    } catch (...) { return false; }
}

double OCCTDocumentPresentationGetTransparency(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return -1.0;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(TDataXtd_Presentation) pres;
        if (!label.FindAttribute(TDataXtd_Presentation::GetID(), pres)) return -1.0;
        if (!pres->HasOwnTransparency()) return -1.0;
        return pres->Transparency();
    } catch (...) { return -1.0; }
}

bool OCCTDocumentPresentationSetWidth(OCCTDocumentRef doc, int64_t labelId, double width) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(TDataXtd_Presentation) pres;
        if (!label.FindAttribute(TDataXtd_Presentation::GetID(), pres)) return false;
        pres->SetWidth(width);
        return true;
    } catch (...) { return false; }
}

double OCCTDocumentPresentationGetWidth(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return -1.0;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(TDataXtd_Presentation) pres;
        if (!label.FindAttribute(TDataXtd_Presentation::GetID(), pres)) return -1.0;
        if (!pres->HasOwnWidth()) return -1.0;
        return pres->Width();
    } catch (...) { return -1.0; }
}

bool OCCTDocumentPresentationSetMode(OCCTDocumentRef doc, int64_t labelId, int32_t mode) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(TDataXtd_Presentation) pres;
        if (!label.FindAttribute(TDataXtd_Presentation::GetID(), pres)) return false;
        pres->SetMode(mode);
        return true;
    } catch (...) { return false; }
}

int32_t OCCTDocumentPresentationGetMode(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(TDataXtd_Presentation) pres;
        if (!label.FindAttribute(TDataXtd_Presentation::GetID(), pres)) return -1;
        if (!pres->HasOwnMode()) return -1;
        return pres->Mode();
    } catch (...) { return -1; }
}
// MARK: - XCAFDoc_AssemblyIterator (v0.90.0)

#include <XCAFDoc_AssemblyIterator.hxx>

int32_t OCCTDocumentAssemblyItemCount(OCCTDocumentRef doc, int32_t maxDepth) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        int level = (maxDepth <= 0) ? INT_MAX : maxDepth;
        XCAFDoc_AssemblyIterator iter(doc->doc, level);
        int count = 0;
        while (iter.More()) {
            count++;
            iter.Next();
            if (count > 100000) break;
        }
        return count;
    } catch (...) { return 0; }
}

// MARK: - XCAFDoc_DimTol (v0.90.0)

#include <XCAFDoc_DimTol.hxx>
#include <TCollection_HAsciiString.hxx>

bool OCCTDocumentSetDimTol(OCCTDocumentRef doc, int64_t labelId,
                            int32_t kind,
                            const double* values, int32_t valueCount,
                            const char* name, const char* description) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;

        Handle(NCollection_HArray1<double>) vals;
        if (valueCount > 0) {
            vals = new NCollection_HArray1<double>(1, valueCount);
            for (int i = 0; i < valueCount; i++) {
                vals->SetValue(i + 1, values[i]);
            }
        }
        Handle(TCollection_HAsciiString) hName = new TCollection_HAsciiString(name);
        Handle(TCollection_HAsciiString) hDesc = new TCollection_HAsciiString(description);

        Handle(XCAFDoc_DimTol) dt = XCAFDoc_DimTol::Set(label, kind, vals, hName, hDesc);
        return !dt.IsNull();
    } catch (...) { return false; }
}

int32_t OCCTDocumentGetDimTolKind(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(XCAFDoc_DimTol) dt;
        if (!label.FindAttribute(XCAFDoc_DimTol::GetID(), dt)) return -1;
        return dt->GetKind();
    } catch (...) { return -1; }
}

const char* OCCTDocumentGetDimTolName(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return nullptr;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(XCAFDoc_DimTol) dt;
        if (!label.FindAttribute(XCAFDoc_DimTol::GetID(), dt)) return nullptr;
        Handle(TCollection_HAsciiString) name = dt->GetName();
        if (name.IsNull()) return nullptr;
        return strdup(name->ToCString());
    } catch (...) { return nullptr; }
}

const char* OCCTDocumentGetDimTolDescription(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return nullptr;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(XCAFDoc_DimTol) dt;
        if (!label.FindAttribute(XCAFDoc_DimTol::GetID(), dt)) return nullptr;
        Handle(TCollection_HAsciiString) desc = dt->GetDescription();
        if (desc.IsNull()) return nullptr;
        return strdup(desc->ToCString());
    } catch (...) { return nullptr; }
}

int32_t OCCTDocumentGetDimTolValues(OCCTDocumentRef doc, int64_t labelId,
                                     double* outValues, int32_t maxCount) {
    if (!doc || doc->doc.IsNull() || !outValues) return 0;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(XCAFDoc_DimTol) dt;
        if (!label.FindAttribute(XCAFDoc_DimTol::GetID(), dt)) return 0;
        Handle(NCollection_HArray1<double>) vals = dt->GetVal();
        if (vals.IsNull()) return 0;
        int count = std::min((int)vals->Length(), (int)maxCount);
        for (int i = 0; i < count; i++) {
            outValues[i] = vals->Value(i + 1);
        }
        return count;
    } catch (...) { return 0; }
}

void OCCTDocumentFreeDimTolString(const char* str) {
    if (str) free((void*)str);
}

// MARK: - v0.92: TDataXtd_Constraint
// MARK: - TDataXtd_Constraint (v0.92.0)

#include <TDataXtd_Constraint.hxx>
#include <TDataXtd_ConstraintEnum.hxx>

bool OCCTDocumentSetConstraint(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TDataXtd_Constraint) cst = TDataXtd_Constraint::Set(label);
        return !cst.IsNull();
    } catch (...) { return false; }
}

bool OCCTDocumentConstraintSetType(OCCTDocumentRef doc, int64_t labelId, int32_t type) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(TDataXtd_Constraint) cst;
        if (!label.FindAttribute(TDataXtd_Constraint::GetID(), cst)) return false;
        cst->SetType((TDataXtd_ConstraintEnum)type);
        return true;
    } catch (...) { return false; }
}

int32_t OCCTDocumentConstraintGetType(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(TDataXtd_Constraint) cst;
        if (!label.FindAttribute(TDataXtd_Constraint::GetID(), cst)) return -1;
        return (int32_t)cst->GetType();
    } catch (...) { return -1; }
}

int32_t OCCTDocumentConstraintNbGeometries(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(TDataXtd_Constraint) cst;
        if (!label.FindAttribute(TDataXtd_Constraint::GetID(), cst)) return 0;
        return cst->NbGeometries();
    } catch (...) { return 0; }
}

bool OCCTDocumentConstraintIsPlanar(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(TDataXtd_Constraint) cst;
        if (!label.FindAttribute(TDataXtd_Constraint::GetID(), cst)) return false;
        return cst->IsPlanar();
    } catch (...) { return false; }
}

bool OCCTDocumentConstraintIsDimension(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(TDataXtd_Constraint) cst;
        if (!label.FindAttribute(TDataXtd_Constraint::GetID(), cst)) return false;
        return cst->IsDimension();
    } catch (...) { return false; }
}

bool OCCTDocumentConstraintSetVerified(OCCTDocumentRef doc, int64_t labelId, bool verified) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(TDataXtd_Constraint) cst;
        if (!label.FindAttribute(TDataXtd_Constraint::GetID(), cst)) return false;
        cst->Verified(verified);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentConstraintGetVerified(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(TDataXtd_Constraint) cst;
        if (!label.FindAttribute(TDataXtd_Constraint::GetID(), cst)) return false;
        return cst->Verified();
    } catch (...) { return false; }
}

bool OCCTDocumentConstraintClearGeometries(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(TDataXtd_Constraint) cst;
        if (!label.FindAttribute(TDataXtd_Constraint::GetID(), cst)) return false;
        cst->ClearGeometries();
        return true;
    } catch (...) { return false; }
}

// MARK: - v0.93: TDataXtd_PatternStd
// MARK: - TDataXtd_PatternStd (v0.93.0)

#include <TDataXtd_PatternStd.hxx>
#include <TDataXtd_Pattern.hxx>

bool OCCTDocumentSetPatternStd(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TDataXtd_PatternStd) pat = TDataXtd_PatternStd::Set(label);
        return !pat.IsNull();
    } catch (...) { return false; }
}

bool OCCTDocumentPatternSetSignature(OCCTDocumentRef doc, int64_t labelId, int32_t signature) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(TDataXtd_PatternStd) pat;
        if (!label.FindAttribute(TDataXtd_Pattern::GetID(), pat)) return false;
        pat->Signature(signature);
        return true;
    } catch (...) { return false; }
}

int32_t OCCTDocumentPatternGetSignature(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(TDataXtd_PatternStd) pat;
        if (!label.FindAttribute(TDataXtd_Pattern::GetID(), pat)) return -1;
        return pat->Signature();
    } catch (...) { return -1; }
}

int32_t OCCTDocumentPatternNbTrsfs(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(TDataXtd_PatternStd) pat;
        if (!label.FindAttribute(TDataXtd_Pattern::GetID(), pat)) return 0;
        return pat->NbTrsfs();
    } catch (...) { return 0; }
}

bool OCCTDocumentHasPattern(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(TDataXtd_PatternStd) pat;
        return label.FindAttribute(TDataXtd_Pattern::GetID(), pat);
    } catch (...) { return false; }
}

// MARK: - v0.96-v0.97: XCAFDoc_AssemblyItemRef + TNaming_Naming
// MARK: - XCAFDoc_AssemblyItemRef (v0.96.0)

#include <XCAFDoc_AssemblyItemRef.hxx>
#include <XCAFDoc_AssemblyItemId.hxx>

bool OCCTDocumentSetAssemblyItemRef(OCCTDocumentRef doc, int64_t labelId, const char* itemPath) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        TCollection_AsciiString path(itemPath);
        XCAFDoc_AssemblyItemId itemId(path);
        Handle(XCAFDoc_AssemblyItemRef) ref = XCAFDoc_AssemblyItemRef::Set(label, itemId);
        return !ref.IsNull();
    } catch (...) { return false; }
}

const char* OCCTDocumentGetAssemblyItemRef(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return nullptr;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(XCAFDoc_AssemblyItemRef) ref;
        if (!label.FindAttribute(XCAFDoc_AssemblyItemRef::GetID(), ref)) return nullptr;
        TCollection_AsciiString path = ref->GetItem().ToString();
        return strdup(path.ToCString());
    } catch (...) { return nullptr; }
}

bool OCCTDocumentAssemblyItemRefSetSubshape(OCCTDocumentRef doc, int64_t labelId, int32_t index) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(XCAFDoc_AssemblyItemRef) ref;
        if (!label.FindAttribute(XCAFDoc_AssemblyItemRef::GetID(), ref)) return false;
        ref->SetSubshapeIndex(index);
        return true;
    } catch (...) { return false; }
}

int32_t OCCTDocumentAssemblyItemRefGetSubshape(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(XCAFDoc_AssemblyItemRef) ref;
        if (!label.FindAttribute(XCAFDoc_AssemblyItemRef::GetID(), ref)) return -1;
        if (!ref->IsSubshapeIndex()) return -1;
        return ref->GetSubshapeIndex();
    } catch (...) { return -1; }
}

bool OCCTDocumentAssemblyItemRefHasExtra(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(XCAFDoc_AssemblyItemRef) ref;
        if (!label.FindAttribute(XCAFDoc_AssemblyItemRef::GetID(), ref)) return false;
        return ref->HasExtraRef();
    } catch (...) { return false; }
}

bool OCCTDocumentAssemblyItemRefClearExtra(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(XCAFDoc_AssemblyItemRef) ref;
        if (!label.FindAttribute(XCAFDoc_AssemblyItemRef::GetID(), ref)) return false;
        ref->ClearExtraRef();
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentAssemblyItemRefIsOrphan(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return true;
    try {
        TDF_Label label = doc->getLabel(labelId);
        Handle(XCAFDoc_AssemblyItemRef) ref;
        if (!label.FindAttribute(XCAFDoc_AssemblyItemRef::GetID(), ref)) return true;
        return ref->IsOrphan();
    } catch (...) { return true; }
}

void OCCTDocumentFreeAssemblyItemRefString(const char* str) {
    if (str) free((void*)str);
}
// MARK: - TNaming_Naming (v0.97.0)

#include <TNaming_Naming.hxx>

bool OCCTDocumentInsertNaming(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TNaming_Naming) naming = TNaming_Naming::Insert(label);
        return !naming.IsNull();
    } catch (...) { return false; }
}

bool OCCTDocumentNamingIsDefined(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;
        Handle(TNaming_Naming) naming;
        if (!label.FindAttribute(TNaming_Naming::GetID(), naming)) return false;
        return naming->IsDefined();
    } catch (...) { return false; }
}

// MARK: - v0.104: XCAFPrs_DocumentExplorer
// MARK: - XCAFPrs_DocumentExplorer (v0.104.0)

#include <XCAFPrs_DocumentExplorer.hxx>
#include <XCAFPrs_DocumentNode.hxx>

int32_t OCCTDocumentExplorerCount(OCCTDocumentRef docRef) {
    try {
        Handle(TDocStd_Document) doc = docRef->doc;
        XCAFPrs_DocumentExplorer explorer(doc, XCAFPrs_DocumentExplorerFlags_OnlyLeafNodes, XCAFPrs_Style());
        int32_t count = 0;
        while (explorer.More()) { count++; explorer.Next(); }
        return count;
    } catch (...) { return 0; }
}

OCCTShapeRef OCCTDocumentExplorerShape(OCCTDocumentRef docRef, int32_t index) {
    try {
        Handle(TDocStd_Document) doc = docRef->doc;
        XCAFPrs_DocumentExplorer explorer(doc, XCAFPrs_DocumentExplorerFlags_OnlyLeafNodes, XCAFPrs_Style());
        int32_t i = 0;
        while (explorer.More()) {
            if (i == index) {
                const XCAFPrs_DocumentNode& node = explorer.Current();
                Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
                TopoDS_Shape shape;
                shapeTool->GetShape(node.RefLabel.IsNull() ? node.Label : node.RefLabel, shape);
                if (shape.IsNull()) return nullptr;
                auto result = new OCCTShape();
                result->shape = shape;
                if (!node.Location.IsIdentity()) result->shape.Location(node.Location);
                return result;
            }
            i++;
            explorer.Next();
        }
        return nullptr;
    } catch (...) { return nullptr; }
}

char* OCCTDocumentExplorerPathId(OCCTDocumentRef docRef, int32_t index) {
    try {
        Handle(TDocStd_Document) doc = docRef->doc;
        XCAFPrs_DocumentExplorer explorer(doc, XCAFPrs_DocumentExplorerFlags_OnlyLeafNodes, XCAFPrs_Style());
        int32_t i = 0;
        while (explorer.More()) {
            if (i == index) {
                return strdup(explorer.Current().Id.ToCString());
            }
            i++;
            explorer.Next();
        }
        return nullptr;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTDocumentExplorerFindShape(OCCTDocumentRef docRef, const char* pathId) {
    try {
        Handle(TDocStd_Document) doc = docRef->doc;
        TCollection_AsciiString id(pathId);
        TopoDS_Shape shape = XCAFPrs_DocumentExplorer::FindShapeFromPathId(doc, id);
        if (shape.IsNull()) return nullptr;
        auto result = new OCCTShape();
        result->shape = shape;
        return result;
    } catch (...) { return nullptr; }
}

// MARK: - v0.105: XCAFPrs_DocumentExplorer extensions
// MARK: - XCAFPrs_DocumentExplorer extensions (v0.105.0)

int32_t OCCTDocumentExplorerDepth(OCCTDocumentRef docRef, int32_t index) {
    try {
        Handle(TDocStd_Document) doc = docRef->doc;
        XCAFPrs_DocumentExplorer explorer(doc, XCAFPrs_DocumentExplorerFlags_OnlyLeafNodes, XCAFPrs_Style());
        int32_t i = 0;
        while (explorer.More()) {
            if (i == index) {
                return (int32_t)explorer.CurrentDepth();
            }
            i++;
            explorer.Next();
        }
        return 0;
    } catch (...) { return 0; }
}

bool OCCTDocumentExplorerIsAssembly(OCCTDocumentRef docRef, int32_t index) {
    try {
        Handle(TDocStd_Document) doc = docRef->doc;
        Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
        XCAFPrs_DocumentExplorer explorer(doc, XCAFPrs_DocumentExplorerFlags_OnlyLeafNodes, XCAFPrs_Style());
        int32_t i = 0;
        while (explorer.More()) {
            if (i == index) {
                const XCAFPrs_DocumentNode& node = explorer.Current();
                return shapeTool->IsAssembly(node.Label);
            }
            i++;
            explorer.Next();
        }
        return false;
    } catch (...) { return false; }
}

void OCCTDocumentExplorerLocation(OCCTDocumentRef docRef, int32_t index, double* matrix12) {
    for (int i = 0; i < 12; i++) matrix12[i] = (i % 4 == i / 3) ? 1.0 : 0.0; // identity
    try {
        Handle(TDocStd_Document) doc = docRef->doc;
        XCAFPrs_DocumentExplorer explorer(doc, XCAFPrs_DocumentExplorerFlags_OnlyLeafNodes, XCAFPrs_Style());
        int32_t i = 0;
        while (explorer.More()) {
            if (i == index) {
                const XCAFPrs_DocumentNode& node = explorer.Current();
                TopLoc_Location loc = node.Location;
                if (!loc.IsIdentity()) {
                    gp_Trsf trsf = loc.IsIdentity() ? gp_Trsf() : loc.IsIdentity() ? gp_Trsf() : loc.IsIdentity() ? gp_Trsf() : loc.Transformation();
                    for (int r = 1; r <= 3; r++) {
                        for (int c = 1; c <= 4; c++) {
                            matrix12[(r-1)*4 + (c-1)] = trsf.Value(r, c);
                        }
                    }
                } else {
                    // Identity matrix
                    for (int j = 0; j < 12; j++) matrix12[j] = 0;
                    matrix12[0] = 1; matrix12[5] = 1; matrix12[10] = 1; // diag = 1
                }
                return;
            }
            i++;
            explorer.Next();
        }
    } catch (...) {}
}

// MARK: - v0.126/v0.127: XCAFDoc_ColorTool completions
// --- XCAFDoc_ColorTool completions ---

#import <XCAFDoc_ColorTool.hxx>
#import <XCAFDoc_DocumentTool.hxx>
#import <Quantity_Color.hxx>
#import <Quantity_ColorRGBA.hxx>

int64_t OCCTDocumentColorToolAddColor(OCCTDocumentRef doc, double r, double g, double b) {
    if (!doc) return -1;
    try {
        auto colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
        Quantity_Color col(r, g, b, Quantity_TOC_RGB);
        TDF_Label lab = colorTool->AddColor(col);
        if (lab.IsNull()) return -1;
        return doc->registerLabel(lab);
    } catch (...) { return -1; }
}

bool OCCTDocumentColorToolRemoveColor(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc) return false;
    try {
        auto colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return false;
        colorTool->RemoveColor(lab);
        return true;
    } catch (...) { return false; }
}

int32_t OCCTDocumentColorToolGetColorCount(OCCTDocumentRef doc) {
    if (!doc) return 0;
    try {
        auto colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
        NCollection_Sequence<TDF_Label> labels;
        colorTool->GetColors(labels);
        return (int32_t)labels.Length();
    } catch (...) { return 0; }
}

bool OCCTDocumentColorToolUnSetColor(OCCTDocumentRef doc, int64_t labelId, int32_t colorType) {
    if (!doc) return false;
    try {
        auto colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return false;
        colorTool->UnSetColor(lab, (XCAFDoc_ColorType)colorType);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentColorToolIsVisible(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc) return true;
    try {
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return true;
        return XCAFDoc_ColorTool::IsVisible(lab);
    } catch (...) { return true; }
}

bool OCCTDocumentColorToolSetVisibility(OCCTDocumentRef doc, int64_t labelId, bool visible) {
    if (!doc) return false;
    try {
        auto colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return false;
        colorTool->SetVisibility(lab, visible);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentColorToolIsColorByLayer(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc) return false;
    try {
        auto colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return false;
        return colorTool->IsColorByLayer(lab);
    } catch (...) { return false; }
}

bool OCCTDocumentColorToolSetColorByLayer(OCCTDocumentRef doc, int64_t labelId, bool isByLayer) {
    if (!doc) return false;
    try {
        auto colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return false;
        colorTool->SetColorByLayer(lab, isByLayer);
        return true;
    } catch (...) { return false; }
}

int64_t OCCTDocumentColorToolFindColor(OCCTDocumentRef doc, double r, double g, double b) {
    if (!doc) return -1;
    try {
        auto colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
        Quantity_Color col(r, g, b, Quantity_TOC_RGB);
        TDF_Label lab = colorTool->FindColor(col);
        if (lab.IsNull()) return -1;
        return doc->registerLabel(lab);
    } catch (...) { return -1; }
}

bool OCCTDocumentColorToolSetInstanceColor(OCCTDocumentRef doc, OCCTShapeRef shape,
                                            int32_t colorType, double r, double g, double b) {
    if (!doc || !shape) return false;
    try {
        auto colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
        Quantity_Color col(r, g, b, Quantity_TOC_RGB);
        return colorTool->SetInstanceColor(shape->shape, (XCAFDoc_ColorType)colorType, col);
    } catch (...) { return false; }
}

bool OCCTDocumentColorToolGetInstanceColor(OCCTDocumentRef doc, OCCTShapeRef shape,
                                            int32_t colorType,
                                            double* r, double* g, double* b) {
    if (!doc || !shape) return false;
    try {
        auto colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
        Quantity_Color col;
        if (!colorTool->GetInstanceColor(shape->shape, (XCAFDoc_ColorType)colorType, col))
            return false;
        *r = col.Red();
        *g = col.Green();
        *b = col.Blue();
        return true;
    } catch (...) { return false; }
}
// --- XCAFDoc_ColorTool completions ---

int32_t OCCTDocumentColorToolGetAllColors(OCCTDocumentRef doc, int64_t** outLabelIds) {
    if (!doc || !outLabelIds) return 0;
    *outLabelIds = nullptr;
    try {
        NCollection_Sequence<TDF_Label> labels;
        doc->colorTool->GetColors(labels);
        int count = labels.Size();
        if (count == 0) return 0;
        int64_t* ids = (int64_t*)malloc(count * sizeof(int64_t));
        if (!ids) return 0;
        for (int i = 1; i <= count; i++) {
            const TDF_Label& lab = labels.Value(i);
            // Find or add to label registry
            int64_t idx = -1;
            for (int64_t j = 0; j < (int64_t)doc->labels.size(); j++) {
                if (doc->labels[j].IsEqual(lab)) { idx = j; break; }
            }
            if (idx < 0) {
                idx = (int64_t)doc->labels.size();
                doc->labels.push_back(lab);
            }
            ids[i-1] = idx;
        }
        *outLabelIds = ids;
        return count;
    } catch (...) { return 0; }
}
