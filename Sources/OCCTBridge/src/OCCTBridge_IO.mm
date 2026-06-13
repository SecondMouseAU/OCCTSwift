//
//  OCCTBridge_IO.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  File I/O surface: STEP / IGES / STL / BREP / OBJ writers and the matching
//  importers. Plus the import-progress + cancellation channel from v0.168.0
//  / v0.169.0 (issue #98), since those entry points share readers/writers
//  with the synchronous variants.
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <Standard_ErrorHandler.hxx>   // OCC_CATCH_SIGNALS (#175)
#include <STEPControl_Reader.hxx>
#include <STEPControl_Writer.hxx>
#include <STEPControl_StepModelType.hxx>
#include <STEPCAFControl_Reader.hxx>
#include <STEPCAFControl_Writer.hxx>
#include <IGESControl_Reader.hxx>
#include <IGESControl_Writer.hxx>
#include <Interface_Static.hxx>
#include <IFSelect_ReturnStatus.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepBuilderAPI_MakeSolid.hxx>
#include <ShapeFix_Shape.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Shell.hxx>
#include <Message_ProgressIndicator.hxx>
#include <Message_ProgressScope.hxx>
#include <Message_ProgressRange.hxx>
#include <GeomTools_CurveSet.hxx>
#include <GeomTools_Curve2dSet.hxx>
#include <GeomTools_SurfaceSet.hxx>
#include <VrmlAPI_Writer.hxx>
#include <VrmlAPI_RepresentationOfShape.hxx>
#include <UnitsAPI.hxx>
#include <UnitsAPI_SystemUnits.hxx>
#include <BinTools.hxx>
#include <BinTools_ShapeReader.hxx>
#include <BinTools_ShapeWriter.hxx>
#include <Message.hxx>
#include <Message_Messenger.hxx>
#include <Message_PrinterOStream.hxx>
#include <Message_Report.hxx>
#include <Message_Gravity.hxx>
#include <APIHeaderSection_MakeHeader.hxx>
#include <Resource_Manager.hxx>
#include <UnitsMethods.hxx>
#include <sstream>
#include <XCAFDoc_DocumentTool.hxx>
#include <TDF_LabelSequence.hxx>
#include <TDF_Label.hxx>
#include <RWObj_CafReader.hxx>
#include <RWObj_CafWriter.hxx>
#include <RWPly_CafWriter.hxx>
#include <TDocStd_Document.hxx>
#include <XCAFApp_Application.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <StlAPI_Writer.hxx>
#include <StlAPI_Reader.hxx>
#include <BinTools.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>

// MARK: - Export

bool OCCTExportSTL(OCCTShapeRef shape, const char* path, double deflection) {
    if (!shape || !path) return false;

    try {
        // Mesh the shape first
        BRepMesh_IncrementalMesh mesher(shape->shape, deflection);
        mesher.Perform();

        StlAPI_Writer writer;
        writer.ASCIIMode() = Standard_False; // Binary STL for smaller files
        return writer.Write(shape->shape, path);
    } catch (...) {
        return false;
    }
}

bool OCCTExportSTLWithMode(OCCTShapeRef shape, const char* path, double deflection, bool ascii) {
    if (!shape || !path) return false;

    try {
        BRepMesh_IncrementalMesh mesher(shape->shape, deflection);
        mesher.Perform();

        StlAPI_Writer writer;
        writer.ASCIIMode() = ascii ? Standard_True : Standard_False;
        return writer.Write(shape->shape, path);
    } catch (...) {
        return false;
    }
}

bool OCCTExportSTEP(OCCTShapeRef shape, const char* path) {
    if (!shape || !path) return false;

    try {
        // Serialize all DE writes: STEP/IGES share Interface_Static globals (#181-B).
        std::lock_guard<std::mutex> deLock(igesMutex());
        // Use a scoped block to ensure all OCCT objects are destroyed before return
        bool success = false;
        {
            STEPControl_Writer writer;
            Interface_Static::SetCVal("write.step.schema", "AP214");

            IFSelect_ReturnStatus status = writer.Transfer(shape->shape, STEPControl_AsIs);
            if (status != IFSelect_RetDone) {
                return false;
            }

            status = writer.Write(path);
            success = (status == IFSelect_RetDone);

            // Writer goes out of scope here and is automatically destroyed
        }
        return success;
    } catch (...) {
        return false;
    }
}

bool OCCTExportSTEPWithName(OCCTShapeRef shape, const char* path, const char* name) {
    if (!shape || !path) return false;

    try {
        // Use a scoped block to ensure all OCCT objects are destroyed before return
        bool success = false;
        {
            STEPControl_Writer writer;
            Interface_Static::SetCVal("write.step.schema", "AP214");
            if (name) {
                Interface_Static::SetCVal("write.step.product.name", name);
            }

            IFSelect_ReturnStatus status = writer.Transfer(shape->shape, STEPControl_AsIs);
            if (status != IFSelect_RetDone) {
                return false;
            }

            status = writer.Write(path);
            success = (status == IFSelect_RetDone);

            // Writer goes out of scope here and is automatically destroyed
        }
        return success;
    } catch (...) {
        return false;
    }
}

// MARK: - Import progress + cancellation (v0.168.0, issue #98)

#include <Message_ProgressIndicator.hxx>
#include <Message_ProgressScope.hxx>
#include <Message_ProgressRange.hxx>

// Forward decl: igesMutex() is defined alongside the existing IGES bridge functions
// further down in the file. The Progress variants need to take the same lock.

namespace {

class BridgeProgressIndicator : public Message_ProgressIndicator {
public:
    BridgeProgressIndicator(const OCCTImportProgress* ctx) : myCtx(ctx) {}

    void Show(const Message_ProgressScope& theScope, const Standard_Boolean isForce) override {
        (void)isForce;
        if (!myCtx || !myCtx->onProgress) return;
        // GetPosition() reports global progress 0.0...1.0.
        const double fraction = GetPosition();
        const char* name = theScope.Name();
        myCtx->onProgress(fraction, name, myCtx->userData);
    }

    Standard_Boolean UserBreak() override {
        if (!myCtx || !myCtx->shouldCancel) return Standard_False;
        return myCtx->shouldCancel(myCtx->userData) ? Standard_True : Standard_False;
    }

    DEFINE_STANDARD_RTTI_INLINE(BridgeProgressIndicator, Message_ProgressIndicator)

private:
    const OCCTImportProgress* myCtx;
};

DEFINE_STANDARD_HANDLE(BridgeProgressIndicator, Message_ProgressIndicator)

static inline void clearCancelOut(bool* outCancelled) {
    if (outCancelled) *outCancelled = false;
}
static inline void setCancelOut(bool* outCancelled, opencascade::handle<BridgeProgressIndicator>& ind) {
    if (outCancelled && !ind.IsNull()) *outCancelled = ind->UserBreak() ? true : false;
}

}

OCCTShapeRef OCCTImportSTEPProgress(const char* path,
                                      const OCCTImportProgress* ctx,
                                      bool* outCancelled) {
    clearCancelOut(outCancelled);
    if (!path) return nullptr;
    try {
        STEPControl_Reader reader;
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return nullptr;

        opencascade::handle<BridgeProgressIndicator> indicator = new BridgeProgressIndicator(ctx);
        Message_ProgressRange range = indicator->Start();
        reader.TransferRoots(range);
        if (indicator->UserBreak()) { setCancelOut(outCancelled, indicator); return nullptr; }

        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return nullptr;
        return new OCCTShape(shape);
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTImportSTEPRobustProgress(const char* path,
                                            const OCCTImportProgress* ctx,
                                            bool* outCancelled) {
    clearCancelOut(outCancelled);
    if (!path) return nullptr;
    try {
        STEPControl_Reader reader;
        Interface_Static::SetIVal("read.precision.mode", 0);
        Interface_Static::SetRVal("read.maxprecision.val", 0.1);
        Interface_Static::SetIVal("read.surfacecurve.mode", 3);
        Interface_Static::SetIVal("read.step.product.mode", 1);

        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return nullptr;

        opencascade::handle<BridgeProgressIndicator> indicator = new BridgeProgressIndicator(ctx);
        Message_ProgressRange range = indicator->Start();
        if (reader.TransferRoots(range) == 0) return nullptr;
        if (indicator->UserBreak()) { setCancelOut(outCancelled, indicator); return nullptr; }

        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return nullptr;

        TopAbs_ShapeEnum shapeType = shape.ShapeType();
        if (shapeType == TopAbs_SOLID) {
            ShapeFix_Shape fixer(shape);
            fixer.Perform();
            TopoDS_Shape fixed = fixer.Shape();
            return new OCCTShape(fixed.IsNull() ? shape : fixed);
        }
        if (shapeType == TopAbs_COMPOUND || shapeType == TopAbs_SHELL || shapeType == TopAbs_FACE) {
            BRepBuilderAPI_Sewing sewing(1.0e-4);
            sewing.SetNonManifoldMode(Standard_False);
            sewing.Add(shape);
            sewing.Perform();
            TopoDS_Shape sewedShape = sewing.SewedShape();
            if (sewedShape.IsNull()) sewedShape = shape;

            TopoDS_Shape resultShape = sewedShape;
            if (sewedShape.ShapeType() != TopAbs_SOLID) {
                TopExp_Explorer shellExp(sewedShape, TopAbs_SHELL);
                if (shellExp.More()) {
                    BRepBuilderAPI_MakeSolid makeSolid(TopoDS::Shell(shellExp.Current()));
                    if (makeSolid.IsDone()) resultShape = makeSolid.Solid();
                }
            }
            ShapeFix_Shape fixer(resultShape);
            fixer.Perform();
            TopoDS_Shape fixed = fixer.Shape();
            return new OCCTShape(fixed.IsNull() ? resultShape : fixed);
        }
        ShapeFix_Shape fixer(shape);
        fixer.Perform();
        TopoDS_Shape fixed = fixer.Shape();
        return new OCCTShape(fixed.IsNull() ? shape : fixed);
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTImportSTEPWithUnitProgress(const char* path, double unitInMeters,
                                              const OCCTImportProgress* ctx,
                                              bool* outCancelled) {
    clearCancelOut(outCancelled);
    if (!path) return nullptr;
    try {
        STEPControl_Reader reader;
        reader.SetSystemLengthUnit(unitInMeters);
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return nullptr;

        opencascade::handle<BridgeProgressIndicator> indicator = new BridgeProgressIndicator(ctx);
        Message_ProgressRange range = indicator->Start();
        reader.TransferRoots(range);
        if (indicator->UserBreak()) { setCancelOut(outCancelled, indicator); return nullptr; }

        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return nullptr;
        return new OCCTShape(shape);
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTImportIGESProgress(const char* path,
                                      const OCCTImportProgress* ctx,
                                      bool* outCancelled) {
    clearCancelOut(outCancelled);
    if (!path) return nullptr;
    std::lock_guard<std::mutex> igesLock(igesMutex());
    try {
        IGESControl_Reader reader;
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return nullptr;

        opencascade::handle<BridgeProgressIndicator> indicator = new BridgeProgressIndicator(ctx);
        Message_ProgressRange range = indicator->Start();
        reader.TransferRoots(range);
        if (indicator->UserBreak()) { setCancelOut(outCancelled, indicator); return nullptr; }

        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return nullptr;
        return new OCCTShape(shape);
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTImportIGESRobustProgress(const char* path,
                                            const OCCTImportProgress* ctx,
                                            bool* outCancelled) {
    clearCancelOut(outCancelled);
    if (!path) return nullptr;
    std::lock_guard<std::mutex> igesLock(igesMutex());
    try {
        IGESControl_Reader reader;
        Interface_Static::SetIVal("read.precision.mode", 0);
        Interface_Static::SetRVal("read.precision.val", 0.0001);

        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return nullptr;

        opencascade::handle<BridgeProgressIndicator> indicator = new BridgeProgressIndicator(ctx);
        Message_ProgressRange range = indicator->Start();
        if (reader.TransferRoots(range) == 0) return nullptr;
        if (indicator->UserBreak()) { setCancelOut(outCancelled, indicator); return nullptr; }

        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return nullptr;

        ShapeFix_Shape fixer(shape);
        fixer.Perform();
        TopoDS_Shape fixed = fixer.Shape();
        return new OCCTShape(fixed.IsNull() ? shape : fixed);
    } catch (...) { return nullptr; }
}

OCCTDocumentRef OCCTDocumentLoadSTEPProgress(const char* path,
                                               const OCCTImportProgress* ctx,
                                               bool* outCancelled) {
    clearCancelOut(outCancelled);
    if (!path) return nullptr;
    OCCTDocument* document = nullptr;
    try {
        document = new OCCTDocument();
        document->app->NewDocument("MDTV-XCAF", document->doc);
        if (document->doc.IsNull()) { delete document; return nullptr; }

        STEPCAFControl_Reader reader;
        reader.SetColorMode(Standard_True);
        reader.SetNameMode(Standard_True);
        reader.SetLayerMode(Standard_True);
        reader.SetPropsMode(Standard_True);
        reader.SetMatMode(Standard_True);

        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) { delete document; return nullptr; }

        opencascade::handle<BridgeProgressIndicator> indicator = new BridgeProgressIndicator(ctx);
        Message_ProgressRange range = indicator->Start();
        bool ok = reader.Transfer(document->doc, range);
        if (indicator->UserBreak()) { setCancelOut(outCancelled, indicator); delete document; return nullptr; }
        if (!ok) { delete document; return nullptr; }

        document->shapeTool = XCAFDoc_DocumentTool::ShapeTool(document->doc->Main());
        document->colorTool = XCAFDoc_DocumentTool::ColorTool(document->doc->Main());
        document->materialTool = XCAFDoc_DocumentTool::VisMaterialTool(document->doc->Main());
        return document;
    } catch (...) { delete document; return nullptr; }
}

// MARK: - Mesh + export progress (v0.169.0, issue #98 follow-up)

OCCTShapeRef OCCTShapeIncrementalMeshProgress(OCCTShapeRef shape,
                                                double linearDeflection,
                                                double angularDeflection,
                                                const OCCTImportProgress* ctx,
                                                bool* outCancelled) {
    clearCancelOut(outCancelled);
    if (!shape) return nullptr;
    try {
        opencascade::handle<BridgeProgressIndicator> indicator = new BridgeProgressIndicator(ctx);
        Message_ProgressRange range = indicator->Start();
        BRepMesh_IncrementalMesh mesher(shape->shape, linearDeflection, Standard_False, angularDeflection);
        mesher.Perform(range);
        if (indicator->UserBreak()) { setCancelOut(outCancelled, indicator); return nullptr; }
        // Return a new OCCTShape wrapping the same (now-meshed) TopoDS_Shape so callers
        // can chain. The original handle is also valid.
        return new OCCTShape(shape->shape);
    } catch (...) { return nullptr; }
}

bool OCCTExportSTEPProgress(OCCTShapeRef shape, const char* path,
                              const OCCTImportProgress* ctx, bool* outCancelled) {
    clearCancelOut(outCancelled);
    if (!shape || !path) return false;
    try {
        // Serialize all DE writes: STEP/IGES share Interface_Static globals (#181-B).
        std::lock_guard<std::mutex> deLock(igesMutex());
        STEPControl_Writer writer;
        Interface_Static::SetCVal("write.step.schema", "AP214");
        opencascade::handle<BridgeProgressIndicator> indicator = new BridgeProgressIndicator(ctx);
        Message_ProgressRange range = indicator->Start();
        IFSelect_ReturnStatus status = writer.Transfer(shape->shape, STEPControl_AsIs, true, range);
        if (indicator->UserBreak()) { setCancelOut(outCancelled, indicator); return false; }
        if (status != IFSelect_RetDone) return false;
        return writer.Write(path) == IFSelect_RetDone;
    } catch (...) { return false; }
}

bool OCCTExportSTEPWithModeProgress(OCCTShapeRef shape, const char* path, int32_t modelType,
                                      const OCCTImportProgress* ctx, bool* outCancelled) {
    clearCancelOut(outCancelled);
    if (!shape || !path) return false;
    try {
        STEPControl_Writer writer;
        Interface_Static::SetCVal("write.step.schema", "AP214");
        opencascade::handle<BridgeProgressIndicator> indicator = new BridgeProgressIndicator(ctx);
        Message_ProgressRange range = indicator->Start();
        STEPControl_StepModelType mode = static_cast<STEPControl_StepModelType>(modelType);
        IFSelect_ReturnStatus status = writer.Transfer(shape->shape, mode, true, range);
        if (indicator->UserBreak()) { setCancelOut(outCancelled, indicator); return false; }
        if (status != IFSelect_RetDone) return false;
        return writer.Write(path) == IFSelect_RetDone;
    } catch (...) { return false; }
}

bool OCCTExportIGESProgress(OCCTShapeRef shape, const char* path,
                              const OCCTImportProgress* ctx, bool* outCancelled) {
    clearCancelOut(outCancelled);
    if (!shape || !path || shape->shape.IsNull()) return false;
    std::lock_guard<std::mutex> igesLock(igesMutex());
    try {
        BRepCheck_Analyzer analyzer(shape->shape);
        if (!analyzer.IsValid()) return false;

        IGESControl_Writer writer("MM", 0);
        opencascade::handle<BridgeProgressIndicator> indicator = new BridgeProgressIndicator(ctx);
        Message_ProgressRange range = indicator->Start();
        if (!writer.AddShape(shape->shape, range)) return false;
        if (indicator->UserBreak()) { setCancelOut(outCancelled, indicator); return false; }
        writer.ComputeModel();
        return writer.Write(path);
    } catch (...) { return false; }
}

bool OCCTDocumentWriteSTEPProgress(OCCTDocumentRef doc, const char* path,
                                     const OCCTImportProgress* ctx, bool* outCancelled) {
    clearCancelOut(outCancelled);
    if (!doc || !path) return false;
    try {
        // Serialize all DE writes: STEP/IGES share Interface_Static globals (#181-B).
        std::lock_guard<std::mutex> deLock(igesMutex());
        STEPCAFControl_Writer writer;
        writer.SetColorMode(Standard_True);
        writer.SetNameMode(Standard_True);
        writer.SetLayerMode(Standard_True);
        writer.SetPropsMode(Standard_True);
        writer.SetMaterialMode(Standard_True);
        opencascade::handle<BridgeProgressIndicator> indicator = new BridgeProgressIndicator(ctx);
        Message_ProgressRange range = indicator->Start();
        if (!writer.Transfer(doc->doc, STEPControl_AsIs, nullptr, range)) {
            if (indicator->UserBreak()) { setCancelOut(outCancelled, indicator); return false; }
            return false;
        }
        if (indicator->UserBreak()) { setCancelOut(outCancelled, indicator); return false; }
        IFSelect_ReturnStatus status = writer.Write(path);
        return status == IFSelect_RetDone;
    } catch (...) { return false; }
}

OCCTDocumentRef OCCTDocumentLoadSTEPWithModesProgress(const char* path,
                                                        bool colorMode, bool nameMode, bool layerMode,
                                                        bool propsMode, bool gdtMode, bool matMode,
                                                        const OCCTImportProgress* ctx,
                                                        bool* outCancelled) {
    clearCancelOut(outCancelled);
    if (!path) return nullptr;
    OCCTDocument* document = nullptr;
    try {
        document = new OCCTDocument();
        document->app->NewDocument("MDTV-XCAF", document->doc);
        if (document->doc.IsNull()) { delete document; return nullptr; }

        STEPCAFControl_Reader reader;
        reader.SetColorMode(colorMode);
        reader.SetNameMode(nameMode);
        reader.SetLayerMode(layerMode);
        reader.SetPropsMode(propsMode);
        reader.SetGDTMode(gdtMode);
        reader.SetMatMode(matMode);

        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) { delete document; return nullptr; }

        opencascade::handle<BridgeProgressIndicator> indicator = new BridgeProgressIndicator(ctx);
        Message_ProgressRange range = indicator->Start();
        bool ok = reader.Transfer(document->doc, range);
        if (indicator->UserBreak()) { setCancelOut(outCancelled, indicator); delete document; return nullptr; }
        if (!ok) { delete document; return nullptr; }

        document->shapeTool = XCAFDoc_DocumentTool::ShapeTool(document->doc->Main());
        document->colorTool = XCAFDoc_DocumentTool::ColorTool(document->doc->Main());
        document->materialTool = XCAFDoc_DocumentTool::VisMaterialTool(document->doc->Main());
        return document;
    } catch (...) { delete document; return nullptr; }
}

// MARK: - Import

OCCTShapeRef OCCTImportSTEP(const char* path) {
    if (!path) return nullptr;

    try {
        STEPControl_Reader reader;
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return nullptr;

        // Transfer all roots
        reader.TransferRoots();

        // Get the result as a single shape (compound if multiple)
        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return nullptr;

        return new OCCTShape(shape);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Robust STEP Import

int OCCTShapeGetType(OCCTShapeRef shape) {
    if (!shape) return -1;
    return static_cast<int>(shape->shape.ShapeType());
}

bool OCCTShapeIsValidSolid(OCCTShapeRef shape) {
    if (!shape) return false;
    occtEnsureSignals();
    try {
        OCC_CATCH_SIGNALS
        if (shape->shape.ShapeType() != TopAbs_SOLID) return false;
        BRepCheck_Analyzer analyzer(shape->shape);
        return analyzer.IsValid();
    } catch (...) {
        return false;
    }
}

OCCTShapeRef OCCTImportSTEPRobust(const char* path) {
    if (!path) return nullptr;

    try {
        STEPControl_Reader reader;

        // Configure reader for better precision handling
        Interface_Static::SetIVal("read.precision.mode", 0);
        Interface_Static::SetRVal("read.maxprecision.val", 0.1);
        Interface_Static::SetIVal("read.surfacecurve.mode", 3);
        Interface_Static::SetIVal("read.step.product.mode", 1);

        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return nullptr;

        if (reader.TransferRoots() == 0) return nullptr;

        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return nullptr;

        TopAbs_ShapeEnum shapeType = shape.ShapeType();

        // If already a solid, just apply healing
        if (shapeType == TopAbs_SOLID) {
            ShapeFix_Shape fixer(shape);
            fixer.Perform();
            TopoDS_Shape fixed = fixer.Shape();
            return new OCCTShape(fixed.IsNull() ? shape : fixed);
        }

        // Try sewing and solid creation for non-solids
        if (shapeType == TopAbs_COMPOUND || shapeType == TopAbs_SHELL ||
            shapeType == TopAbs_FACE) {

            // Sew disconnected faces/shells
            BRepBuilderAPI_Sewing sewing(1.0e-4);
            sewing.SetNonManifoldMode(Standard_False);
            sewing.Add(shape);
            sewing.Perform();
            TopoDS_Shape sewedShape = sewing.SewedShape();
            if (sewedShape.IsNull()) sewedShape = shape;

            // Try to create solid from shell
            TopoDS_Shape resultShape = sewedShape;
            if (sewedShape.ShapeType() != TopAbs_SOLID) {
                TopExp_Explorer shellExp(sewedShape, TopAbs_SHELL);
                if (shellExp.More()) {
                    BRepBuilderAPI_MakeSolid makeSolid(TopoDS::Shell(shellExp.Current()));
                    if (makeSolid.IsDone()) {
                        resultShape = makeSolid.Solid();
                    }
                }
            }

            // Apply shape healing
            ShapeFix_Shape fixer(resultShape);
            fixer.Perform();
            TopoDS_Shape fixed = fixer.Shape();
            return new OCCTShape(fixed.IsNull() ? resultShape : fixed);
        }

        // Fallback: just heal whatever we got
        ShapeFix_Shape fixer(shape);
        fixer.Perform();
        TopoDS_Shape fixed = fixer.Shape();
        return new OCCTShape(fixed.IsNull() ? shape : fixed);

    } catch (...) {
        return nullptr;
    }
}

OCCTSTEPImportResult OCCTImportSTEPWithDiagnostics(const char* path) {
    OCCTSTEPImportResult result = {nullptr, -1, -1, false, false, false};
    if (!path) return result;

    try {
        STEPControl_Reader reader;

        // Configure reader
        Interface_Static::SetIVal("read.precision.mode", 0);
        Interface_Static::SetRVal("read.maxprecision.val", 0.1);
        Interface_Static::SetIVal("read.surfacecurve.mode", 3);
        Interface_Static::SetIVal("read.step.product.mode", 1);

        if (reader.ReadFile(path) != IFSelect_RetDone) return result;
        if (reader.TransferRoots() == 0) return result;

        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return result;

        result.originalType = static_cast<int>(shape.ShapeType());

        // Process non-solids
        if (shape.ShapeType() != TopAbs_SOLID) {
            // Try sewing
            BRepBuilderAPI_Sewing sewing(1.0e-4);
            sewing.SetNonManifoldMode(Standard_False);
            sewing.Add(shape);
            sewing.Perform();
            TopoDS_Shape sewedShape = sewing.SewedShape();
            if (!sewedShape.IsNull() && !sewedShape.IsSame(shape)) {
                shape = sewedShape;
                result.sewingApplied = true;
            }

            // Try solid creation
            if (shape.ShapeType() != TopAbs_SOLID) {
                TopExp_Explorer shellExp(shape, TopAbs_SHELL);
                if (shellExp.More()) {
                    BRepBuilderAPI_MakeSolid makeSolid(TopoDS::Shell(shellExp.Current()));
                    if (makeSolid.IsDone()) {
                        shape = makeSolid.Solid();
                        result.solidCreated = true;
                    }
                }
            }
        }

        // Apply shape healing
        ShapeFix_Shape fixer(shape);
        fixer.Perform();
        TopoDS_Shape fixed = fixer.Shape();
        if (!fixed.IsNull()) {
            shape = fixed;
            result.healingApplied = true;
        }

        result.shape = new OCCTShape(shape);
        result.resultType = static_cast<int>(shape.ShapeType());
        return result;

    } catch (...) {
        return result;
    }
}

// MARK: - STEP Optimization (v0.28.0)

#include <StepTidy_DuplicateCleaner.hxx>

bool OCCTStepTidyOptimize(const char* inputPath, const char* outputPath) {
    if (!inputPath || !outputPath) return false;
    try {
        STEPControl_Reader reader;
        if (reader.ReadFile(inputPath) != IFSelect_RetDone) return false;

        // Run tidy on the work session before transferring
        Handle(XSControl_WorkSession) ws = reader.WS();
        StepTidy_DuplicateCleaner cleaner(ws);
        cleaner.Perform();

        // Now transfer and write
        reader.TransferRoots();

        STEPControl_Writer writer;
        for (int i = 1; i <= reader.NbShapes(); i++) {
            writer.Transfer(reader.Shape(i), STEPControl_AsIs);
        }
        return writer.Write(outputPath) == IFSelect_RetDone;
    } catch (...) {
        return false;
    }
}
// MARK: - STL Import (v0.17.0)

#include <StlAPI_Reader.hxx>

OCCTShapeRef OCCTImportSTL(const char* path) {
    if (!path) return nullptr;

    try {
        TopoDS_Shape shape;
        StlAPI_Reader reader;
        if (!reader.Read(shape, path)) return nullptr;
        if (shape.IsNull()) return nullptr;
        return new OCCTShape(shape);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTImportSTLRobust(const char* path, double sewingTolerance) {
    if (!path) return nullptr;

    try {
        TopoDS_Shape shape;
        StlAPI_Reader reader;
        if (!reader.Read(shape, path)) return nullptr;
        if (shape.IsNull()) return nullptr;

        // Sew disconnected faces
        BRepBuilderAPI_Sewing sewing(sewingTolerance);
        sewing.Add(shape);
        sewing.Perform();
        TopoDS_Shape sewedShape = sewing.SewedShape();
        if (sewedShape.IsNull()) sewedShape = shape;

        // Try to create solid from shell
        TopoDS_Shape resultShape = sewedShape;
        if (sewedShape.ShapeType() != TopAbs_SOLID) {
            TopExp_Explorer shellExp(sewedShape, TopAbs_SHELL);
            if (shellExp.More()) {
                BRepBuilderAPI_MakeSolid makeSolid(TopoDS::Shell(shellExp.Current()));
                if (makeSolid.IsDone()) {
                    resultShape = makeSolid.Solid();
                }
            }
        }

        // Apply shape healing
        ShapeFix_Shape fixer(resultShape);
        fixer.Perform();
        TopoDS_Shape fixed = fixer.Shape();
        return new OCCTShape(fixed.IsNull() ? resultShape : fixed);
    } catch (...) {
        return nullptr;
    }
}


// MARK: - OBJ Import/Export (v0.17.0)

#include <RWObj_CafReader.hxx>
#include <RWObj_CafWriter.hxx>
#include <TDocStd_Document.hxx>
#include <XCAFApp_Application.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <Message_ProgressRange.hxx>

OCCTShapeRef OCCTImportOBJ(const char* path) {
    if (!path) return nullptr;

    try {
        // Use RWObj_CafReader for OBJ import
        RWObj_CafReader objReader;

        // Create an XDE document
        Handle(TDocStd_Document) doc;
        Handle(XCAFApp_Application) app = XCAFApp_Application::GetApplication();
        app->NewDocument("MDTV-XCAF", doc);

        objReader.SetDocument(doc);
        TCollection_AsciiString filePath(path);
        if (!objReader.Perform(filePath, Message_ProgressRange())) return nullptr;

        // Extract shape from document
        Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
        TopoDS_Shape shape = shapeTool->GetOneShape();
        if (shape.IsNull()) return nullptr;

        // Close document
        app->Close(doc);

        return new OCCTShape(shape);
    } catch (...) {
        return nullptr;
    }
}

bool OCCTExportOBJ(OCCTShapeRef shape, const char* path, double deflection) {
    if (!shape || !path) return false;

    try {
        // Tessellate the shape first
        BRepMesh_IncrementalMesh mesher(shape->shape, deflection);
        mesher.Perform();

        // Create an XDE document
        Handle(TDocStd_Document) doc;
        Handle(XCAFApp_Application) app = XCAFApp_Application::GetApplication();
        app->NewDocument("MDTV-XCAF", doc);

        Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
        shapeTool->AddShape(shape->shape);

        // Write OBJ
        RWObj_CafWriter writer(path);
        NCollection_Sequence<TDF_Label> rootLabels;
        TDF_LabelSequence freeShapes;
        shapeTool->GetFreeShapes(freeShapes);
        for (int i = 1; i <= freeShapes.Length(); ++i) {
            rootLabels.Append(freeShapes.Value(i));
        }
        NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> fileInfo;
        bool success = writer.Perform(doc, rootLabels, nullptr, fileInfo, Message_ProgressRange());

        app->Close(doc);
        return success;
    } catch (...) {
        return false;
    }
}


// MARK: - PLY Export (v0.17.0)

#include <RWPly_CafWriter.hxx>

bool OCCTExportPLY(OCCTShapeRef shape, const char* path, double deflection) {
    if (!shape || !path) return false;

    try {
        // Tessellate the shape first
        BRepMesh_IncrementalMesh mesher(shape->shape, deflection);
        mesher.Perform();

        // Create an XDE document
        Handle(TDocStd_Document) doc;
        Handle(XCAFApp_Application) app = XCAFApp_Application::GetApplication();
        app->NewDocument("MDTV-XCAF", doc);

        Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
        shapeTool->AddShape(shape->shape);

        // Write PLY
        RWPly_CafWriter writer(path);
        writer.SetNormals(true);
        NCollection_Sequence<TDF_Label> rootLabels;
        TDF_LabelSequence freeShapes;
        shapeTool->GetFreeShapes(freeShapes);
        for (int i = 1; i <= freeShapes.Length(); ++i) {
            rootLabels.Append(freeShapes.Value(i));
        }
        NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> fileInfo;
        bool success = writer.Perform(doc, rootLabels, nullptr, fileInfo, Message_ProgressRange());

        app->Close(doc);
        return success;
    } catch (...) {
        return false;
    }
}


// MARK: - STEP Full Coverage — STEPControl_Writer (v0.58.0)

bool OCCTExportSTEPWithMode(OCCTShapeRef shape, const char* path, int32_t modelType) {
    if (!shape || !path) return false;
    try {
        // Serialize all DE writes: STEP/IGES share Interface_Static globals (#181-B).
        std::lock_guard<std::mutex> deLock(igesMutex());
        STEPControl_Writer writer;
        Interface_Static::SetCVal("write.step.schema", "AP214");
        STEPControl_StepModelType mode = static_cast<STEPControl_StepModelType>(modelType);
        IFSelect_ReturnStatus status = writer.Transfer(shape->shape, mode);
        if (status != IFSelect_RetDone) return false;
        status = writer.Write(path);
        return status == IFSelect_RetDone;
    } catch (...) { return false; }
}

bool OCCTExportSTEPWithModeAndTolerance(OCCTShapeRef shape, const char* path,
                                         int32_t modelType, double tolerance) {
    if (!shape || !path) return false;
    try {
        // Serialize all DE writes: STEP/IGES share Interface_Static globals (#181-B).
        std::lock_guard<std::mutex> deLock(igesMutex());
        STEPControl_Writer writer;
        Interface_Static::SetCVal("write.step.schema", "AP214");
        writer.SetTolerance(tolerance);
        STEPControl_StepModelType mode = static_cast<STEPControl_StepModelType>(modelType);
        IFSelect_ReturnStatus status = writer.Transfer(shape->shape, mode);
        if (status != IFSelect_RetDone) return false;
        status = writer.Write(path);
        return status == IFSelect_RetDone;
    } catch (...) { return false; }
}

bool OCCTExportSTEPCleanDuplicates(OCCTShapeRef shape, const char* path, int32_t modelType) {
    if (!shape || !path) return false;
    try {
        // Serialize all DE writes: STEP/IGES share Interface_Static globals (#181-B).
        std::lock_guard<std::mutex> deLock(igesMutex());
        STEPControl_Writer writer;
        Interface_Static::SetCVal("write.step.schema", "AP214");
        STEPControl_StepModelType mode = static_cast<STEPControl_StepModelType>(modelType);
        IFSelect_ReturnStatus status = writer.Transfer(shape->shape, mode);
        if (status != IFSelect_RetDone) return false;
        writer.CleanDuplicateEntities();
        status = writer.Write(path);
        return status == IFSelect_RetDone;
    } catch (...) { return false; }
}

// MARK: - STEP Full Coverage — STEPControl_Reader (v0.58.0)

int32_t OCCTSTEPReaderNbRoots(const char* path) {
    if (!path) return 0;
    try {
        STEPControl_Reader reader;
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return 0;
        return reader.NbRootsForTransfer();
    } catch (...) { return 0; }
}

OCCTShapeRef OCCTImportSTEPRoot(const char* path, int32_t rootIndex) {
    if (!path || rootIndex < 1) return nullptr;
    try {
        STEPControl_Reader reader;
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return nullptr;
        int nbRoots = reader.NbRootsForTransfer();
        if (rootIndex > nbRoots) return nullptr;
        if (!reader.TransferRoot(rootIndex)) return nullptr;
        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return nullptr;
        return new OCCTShape(shape);
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTImportSTEPWithUnit(const char* path, double unitInMeters) {
    if (!path) return nullptr;
    try {
        STEPControl_Reader reader;
        reader.SetSystemLengthUnit(unitInMeters);
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return nullptr;
        reader.TransferRoots();
        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return nullptr;
        return new OCCTShape(shape);
    } catch (...) { return nullptr; }
}

int32_t OCCTSTEPReaderNbShapes(const char* path) {
    if (!path) return 0;
    try {
        STEPControl_Reader reader;
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return 0;
        reader.TransferRoots();
        return reader.NbShapes();
    } catch (...) { return 0; }
}

// MARK: - STEP Full Coverage — STEPCAFControl Modes (v0.58.0)

OCCTDocumentRef OCCTDocumentLoadSTEPWithModes(const char* path,
    bool colorMode, bool nameMode, bool layerMode,
    bool propsMode, bool gdtMode, bool matMode) {
    if (!path) return nullptr;

    OCCTDocument* document = nullptr;
    try {
        document = new OCCTDocument();
        document->app->NewDocument("MDTV-XCAF", document->doc);
        if (document->doc.IsNull()) {
            delete document;
            return nullptr;
        }

        STEPCAFControl_Reader reader;
        reader.SetColorMode(colorMode);
        reader.SetNameMode(nameMode);
        reader.SetLayerMode(layerMode);
        reader.SetPropsMode(propsMode);
        reader.SetGDTMode(gdtMode);
        reader.SetMatMode(matMode);

        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) {
            delete document;
            return nullptr;
        }

        if (!reader.Transfer(document->doc)) {
            delete document;
            return nullptr;
        }

        document->shapeTool = XCAFDoc_DocumentTool::ShapeTool(document->doc->Main());
        document->colorTool = XCAFDoc_DocumentTool::ColorTool(document->doc->Main());
        document->materialTool = XCAFDoc_DocumentTool::VisMaterialTool(document->doc->Main());

        return document;
    } catch (...) {
        delete document;
        return nullptr;
    }
}

bool OCCTDocumentWriteSTEPWithModes(OCCTDocumentRef doc, const char* path,
    int32_t modelType, bool colorMode, bool nameMode, bool layerMode,
    bool dimTolMode, bool materialMode) {
    if (!doc || !path || doc->doc.IsNull()) return false;

    try {
        STEPCAFControl_Writer writer;
        writer.SetColorMode(colorMode);
        writer.SetNameMode(nameMode);
        writer.SetLayerMode(layerMode);
        writer.SetDimTolMode(dimTolMode);
        writer.SetMaterialMode(materialMode);

        STEPControl_StepModelType mode = static_cast<STEPControl_StepModelType>(modelType);
        if (!writer.Transfer(doc->doc, mode)) return false;

        IFSelect_ReturnStatus status = writer.Write(path);
        return status == IFSelect_RetDone;
    } catch (...) { return false; }
}

// MARK: - IGES Full Coverage — Reader (v0.59.0)

int32_t OCCTIGESReaderNbRoots(const char* path) {
    if (!path) return 0;
    std::lock_guard<std::mutex> igesLock(igesMutex());
    try {
        IGESControl_Reader reader;
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return 0;
        return reader.NbRootsForTransfer();
    } catch (...) { return 0; }
}

OCCTShapeRef OCCTImportIGESRoot(const char* path, int32_t rootIndex) {
    if (!path || rootIndex < 1) return nullptr;
    std::lock_guard<std::mutex> igesLock(igesMutex());
    try {
        IGESControl_Reader reader;
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return nullptr;
        int nbRoots = reader.NbRootsForTransfer();
        if (rootIndex > nbRoots) return nullptr;
        if (!reader.TransferOneRoot(rootIndex)) return nullptr;
        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return nullptr;
        return new OCCTShape(shape);
    } catch (...) { return nullptr; }
}

int32_t OCCTIGESReaderNbShapes(const char* path) {
    if (!path) return 0;
    std::lock_guard<std::mutex> igesLock(igesMutex());
    try {
        IGESControl_Reader reader;
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return 0;
        reader.TransferRoots();
        return reader.NbShapes();
    } catch (...) { return 0; }
}

OCCTShapeRef OCCTImportIGESVisible(const char* path) {
    if (!path) return nullptr;
    std::lock_guard<std::mutex> igesLock(igesMutex());
    try {
        IGESControl_Reader reader;
        reader.SetReadVisible(true);
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return nullptr;
        reader.TransferRoots();
        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return nullptr;
        return new OCCTShape(shape);
    } catch (...) { return nullptr; }
}

// MARK: - IGES Full Coverage — Writer (v0.59.0)

bool OCCTExportIGESWithUnit(OCCTShapeRef shape, const char* path, const char* unit) {
    if (!shape || !path || !unit) return false;
    if (shape->shape.IsNull()) return false;
    std::lock_guard<std::mutex> igesLock(igesMutex());
    try {
        BRepCheck_Analyzer analyzer(shape->shape);
        if (!analyzer.IsValid()) return false;
        IGESControl_Writer writer(unit, 0); // 0 = Faces mode
        if (!writer.AddShape(shape->shape)) return false;
        writer.ComputeModel();
        return writer.Write(path);
    } catch (...) { return false; }
}

bool OCCTExportIGESBRepMode(OCCTShapeRef shape, const char* path) {
    if (!shape || !path) return false;
    if (shape->shape.IsNull()) return false;
    std::lock_guard<std::mutex> igesLock(igesMutex());
    try {
        BRepCheck_Analyzer analyzer(shape->shape);
        if (!analyzer.IsValid()) return false;
        IGESControl_Writer writer("MM", 1); // 1 = BRep mode
        if (!writer.AddShape(shape->shape)) return false;
        writer.ComputeModel();
        return writer.Write(path);
    } catch (...) { return false; }
}

bool OCCTExportIGESMultiShape(const OCCTShapeRef* shapes, int32_t count, const char* path) {
    if (!shapes || count <= 0 || !path) return false;
    std::lock_guard<std::mutex> igesLock(igesMutex());
    try {
        IGESControl_Writer writer;
        int added = 0;
        for (int32_t i = 0; i < count; i++) {
            if (!shapes[i] || shapes[i]->shape.IsNull()) continue;
            // Validate each shape before adding to IGES writer
            BRepCheck_Analyzer analyzer(shapes[i]->shape);
            if (!analyzer.IsValid()) continue;
            writer.AddShape(shapes[i]->shape);
            added++;
        }
        if (added == 0) return false;
        writer.ComputeModel();
        return writer.Write(path);
    } catch (...) { return false; }
}

// MARK: - OBJ Document I/O (v0.59.0)

#include <RWMesh_CoordinateSystemConverter.hxx>
#include <RWMesh_CoordinateSystem.hxx>

OCCTDocumentRef OCCTDocumentLoadOBJ(const char* path) {
    if (!path) return nullptr;
    try {
        OCCTDocument* document = new OCCTDocument();
        document->app->NewDocument("MDTV-XCAF", document->doc);
        if (document->doc.IsNull()) { delete document; return nullptr; }

        RWObj_CafReader objReader;
        objReader.SetDocument(document->doc);
        TCollection_AsciiString filePath(path);
        if (!objReader.Perform(filePath, Message_ProgressRange())) {
            delete document;
            return nullptr;
        }

        document->shapeTool = XCAFDoc_DocumentTool::ShapeTool(document->doc->Main());
        document->colorTool = XCAFDoc_DocumentTool::ColorTool(document->doc->Main());
        document->materialTool = XCAFDoc_DocumentTool::VisMaterialTool(document->doc->Main());
        return document;
    } catch (...) { return nullptr; }
}

OCCTDocumentRef OCCTDocumentLoadOBJWithOptions(const char* path,
    bool singlePrecision, double systemLengthUnit) {
    if (!path) return nullptr;
    try {
        OCCTDocument* document = new OCCTDocument();
        document->app->NewDocument("MDTV-XCAF", document->doc);
        if (document->doc.IsNull()) { delete document; return nullptr; }

        RWObj_CafReader objReader;
        objReader.SetDocument(document->doc);
        objReader.SetSinglePrecision(singlePrecision);
        if (systemLengthUnit > 0) {
            objReader.SetSystemLengthUnit(systemLengthUnit);
        }

        TCollection_AsciiString filePath(path);
        if (!objReader.Perform(filePath, Message_ProgressRange())) {
            delete document;
            return nullptr;
        }

        document->shapeTool = XCAFDoc_DocumentTool::ShapeTool(document->doc->Main());
        document->colorTool = XCAFDoc_DocumentTool::ColorTool(document->doc->Main());
        document->materialTool = XCAFDoc_DocumentTool::VisMaterialTool(document->doc->Main());
        return document;
    } catch (...) { return nullptr; }
}

bool OCCTDocumentWriteOBJ(OCCTDocumentRef doc, const char* path, double deflection) {
    if (!doc || !path || doc->doc.IsNull() || doc->shapeTool.IsNull()) return false;
    try {
        // Re-mesh if deflection > 0
        if (deflection > 0) {
            TDF_LabelSequence freeShapes;
            doc->shapeTool->GetFreeShapes(freeShapes);
            for (int i = 1; i <= freeShapes.Length(); i++) {
                TopoDS_Shape shape = doc->shapeTool->GetShape(freeShapes.Value(i));
                if (!shape.IsNull()) {
                    BRepMesh_IncrementalMesh mesher(shape, deflection);
                    mesher.Perform();
                }
            }
        }

        RWObj_CafWriter writer(path);
        NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> fileInfo;
        return writer.Perform(doc->doc, fileInfo, Message_ProgressRange());
    } catch (...) { return false; }
}

// MARK: - PLY Export Expansion (v0.59.0)

bool OCCTDocumentWritePLY(OCCTDocumentRef doc, const char* path, double deflection,
    bool normals, bool colors, bool texCoords) {
    if (!doc || !path || doc->doc.IsNull() || doc->shapeTool.IsNull()) return false;
    try {
        // Re-mesh if deflection > 0
        if (deflection > 0) {
            TDF_LabelSequence freeShapes;
            doc->shapeTool->GetFreeShapes(freeShapes);
            for (int i = 1; i <= freeShapes.Length(); i++) {
                TopoDS_Shape shape = doc->shapeTool->GetShape(freeShapes.Value(i));
                if (!shape.IsNull()) {
                    BRepMesh_IncrementalMesh mesher(shape, deflection);
                    mesher.Perform();
                }
            }
        }

        RWPly_CafWriter writer(path);
        writer.SetNormals(normals);
        writer.SetColors(colors);
        writer.SetTexCoords(texCoords);
        NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> fileInfo;
        return writer.Perform(doc->doc, fileInfo, Message_ProgressRange());
    } catch (...) { return false; }
}

bool OCCTExportPLYWithOptions(OCCTShapeRef shape, const char* path, double deflection,
    bool normals, bool colors, bool texCoords) {
    if (!shape || !path) return false;
    try {
        BRepMesh_IncrementalMesh mesher(shape->shape, deflection);
        mesher.Perform();

        Handle(TDocStd_Document) doc;
        Handle(XCAFApp_Application) app = XCAFApp_Application::GetApplication();
        app->NewDocument("MDTV-XCAF", doc);

        Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
        shapeTool->AddShape(shape->shape);

        RWPly_CafWriter writer(path);
        writer.SetNormals(normals);
        writer.SetColors(colors);
        writer.SetTexCoords(texCoords);
        NCollection_Sequence<TDF_Label> rootLabels;
        TDF_LabelSequence freeShapes;
        shapeTool->GetFreeShapes(freeShapes);
        for (int i = 1; i <= freeShapes.Length(); ++i) {
            rootLabels.Append(freeShapes.Value(i));
        }
        NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> fileInfo;
        bool success = writer.Perform(doc, rootLabels, nullptr, fileInfo, Message_ProgressRange());
        app->Close(doc);
        return success;
    } catch (...) { return false; }
}

// MARK: - RWMesh Coordinate System (v0.59.0)

OCCTDocumentRef OCCTDocumentLoadOBJWithCS(const char* path,
    int32_t inputCS, int32_t outputCS, double inputLengthUnit, double outputLengthUnit) {
    if (!path) return nullptr;
    try {
        OCCTDocument* document = new OCCTDocument();
        document->app->NewDocument("MDTV-XCAF", document->doc);
        if (document->doc.IsNull()) { delete document; return nullptr; }

        RWObj_CafReader objReader;
        objReader.SetDocument(document->doc);

        if (inputLengthUnit > 0) objReader.SetFileLengthUnit(inputLengthUnit);
        if (outputLengthUnit > 0) objReader.SetSystemLengthUnit(outputLengthUnit);

        if (inputCS >= 0) {
            objReader.SetFileCoordinateSystem(static_cast<RWMesh_CoordinateSystem>(inputCS));
        }
        if (outputCS >= 0) {
            objReader.SetSystemCoordinateSystem(static_cast<RWMesh_CoordinateSystem>(outputCS));
        }

        TCollection_AsciiString filePath(path);
        if (!objReader.Perform(filePath, Message_ProgressRange())) {
            delete document;
            return nullptr;
        }

        document->shapeTool = XCAFDoc_DocumentTool::ShapeTool(document->doc->Main());
        document->colorTool = XCAFDoc_DocumentTool::ColorTool(document->doc->Main());
        document->materialTool = XCAFDoc_DocumentTool::VisMaterialTool(document->doc->Main());
        return document;
    } catch (...) { return nullptr; }
}


// MARK: - GeomTools persistence: CurveSet / Curve2dSet / SurfaceSet (v0.80)
// --- GeomTools_CurveSet ---

const char * _Nullable OCCTGeomToolsCurveSetWrite(const OCCTCurve3DRef * curveRefs, int count) {
    try {
        GeomTools_CurveSet cs;
        for (int i = 0; i < count; i++) {
            auto* c = (OCCTCurve3D*)curveRefs[i];
            cs.Add(c->curve);
        }
        std::ostringstream oss;
        cs.Write(oss);
        std::string s = oss.str();
        char* result = (char*)malloc(s.size() + 1);
        memcpy(result, s.c_str(), s.size() + 1);
        return result;
    } catch (...) { return nullptr; }
}

OCCTCurve3DRef * _Nullable OCCTGeomToolsCurveSetRead(const char * data, int * outCount) {
    *outCount = 0;
    try {
        std::istringstream iss(data);
        GeomTools_CurveSet cs;
        cs.Read(iss);
        // Count curves (1-based indexing, index 0 returns null)
        int n = 0;
        for (int i = 1; ; i++) {
            try {
                Handle(Geom_Curve) c = cs.Curve(i);
                if (c.IsNull()) break;
                n++;
            } catch (...) { break; }
        }
        if (n == 0) return nullptr;
        OCCTCurve3DRef* arr = (OCCTCurve3DRef*)malloc(sizeof(OCCTCurve3DRef) * n);
        for (int i = 0; i < n; i++) {
            Handle(Geom_Curve) c = cs.Curve(i + 1);
            arr[i] = (OCCTCurve3DRef)new OCCTCurve3D{c};
        }
        *outCount = n;
        return arr;
    } catch (...) { return nullptr; }
}

void OCCTGeomToolsCurveSetFreeArray(OCCTCurve3DRef * array, int count) {
    if (!array) return;
    for (int i = 0; i < count; i++) {
        if (array[i]) OCCTCurve3DRelease(array[i]);
    }
    free(array);
}

// --- GeomTools_Curve2dSet ---

const char * _Nullable OCCTGeomToolsCurve2dSetWrite(const OCCTCurve2DRef * curveRefs, int count) {
    try {
        GeomTools_Curve2dSet cs;
        for (int i = 0; i < count; i++) {
            auto* c = (OCCTCurve2D*)curveRefs[i];
            cs.Add(c->curve);
        }
        std::ostringstream oss;
        cs.Write(oss);
        std::string s = oss.str();
        char* result = (char*)malloc(s.size() + 1);
        memcpy(result, s.c_str(), s.size() + 1);
        return result;
    } catch (...) { return nullptr; }
}

OCCTCurve2DRef * _Nullable OCCTGeomToolsCurve2dSetRead(const char * data, int * outCount) {
    *outCount = 0;
    try {
        std::istringstream iss(data);
        GeomTools_Curve2dSet cs;
        cs.Read(iss);
        int n = 0;
        for (int i = 1; ; i++) {
            try {
                Handle(Geom2d_Curve) c = cs.Curve2d(i);
                if (c.IsNull()) break;
                n++;
            } catch (...) { break; }
        }
        if (n == 0) return nullptr;
        OCCTCurve2DRef* arr = (OCCTCurve2DRef*)malloc(sizeof(OCCTCurve2DRef) * n);
        for (int i = 0; i < n; i++) {
            Handle(Geom2d_Curve) c = cs.Curve2d(i + 1);
            arr[i] = (OCCTCurve2DRef)new OCCTCurve2D{c};
        }
        *outCount = n;
        return arr;
    } catch (...) { return nullptr; }
}

void OCCTGeomToolsCurve2dSetFreeArray(OCCTCurve2DRef * array, int count) {
    if (!array) return;
    for (int i = 0; i < count; i++) {
        if (array[i]) OCCTCurve2DRelease(array[i]);
    }
    free(array);
}

// --- GeomTools_SurfaceSet ---

const char * _Nullable OCCTGeomToolsSurfaceSetWrite(const OCCTSurfaceRef * surfRefs, int count) {
    try {
        GeomTools_SurfaceSet ss;
        for (int i = 0; i < count; i++) {
            auto* s = (OCCTSurface*)surfRefs[i];
            ss.Add(s->surface);
        }
        std::ostringstream oss;
        ss.Write(oss);
        std::string s = oss.str();
        char* result = (char*)malloc(s.size() + 1);
        memcpy(result, s.c_str(), s.size() + 1);
        return result;
    } catch (...) { return nullptr; }
}

OCCTSurfaceRef * _Nullable OCCTGeomToolsSurfaceSetRead(const char * data, int * outCount) {
    *outCount = 0;
    try {
        std::istringstream iss(data);
        GeomTools_SurfaceSet ss;
        ss.Read(iss);
        int n = 0;
        for (int i = 1; ; i++) {
            try {
                Handle(Geom_Surface) s = ss.Surface(i);
                if (s.IsNull()) break;
                n++;
            } catch (...) { break; }
        }
        if (n == 0) return nullptr;
        OCCTSurfaceRef* arr = (OCCTSurfaceRef*)malloc(sizeof(OCCTSurfaceRef) * n);
        for (int i = 0; i < n; i++) {
            Handle(Geom_Surface) s = ss.Surface(i + 1);
            arr[i] = (OCCTSurfaceRef)new OCCTSurface{s};
        }
        *outCount = n;
        return arr;
    } catch (...) { return nullptr; }
}

void OCCTGeomToolsSurfaceSetFreeArray(OCCTSurfaceRef * array, int count) {
    if (!array) return;
    for (int i = 0; i < count; i++) {
        if (array[i]) OCCTSurfaceRelease(array[i]);
    }
    free(array);
}

void OCCTGeomToolsFreeString(const char * str) {
    if (str) free((void*)str);
}

// MARK: - VrmlAPI Writer (v0.84)
bool OCCTVrmlWriteShape(OCCTShapeRef shape, const char* filePath,
                        int version, double deflection, int representation) {
    try {
        VrmlAPI_Writer writer;
        writer.SetDeflection(deflection);
        switch (representation) {
            case 0: writer.SetRepresentation(VrmlAPI_ShadedRepresentation); break;
            case 1: writer.SetRepresentation(VrmlAPI_WireFrameRepresentation); break;
            case 2: writer.SetRepresentation(VrmlAPI_BothRepresentation); break;
            default: writer.SetRepresentation(VrmlAPI_ShadedRepresentation); break;
        }
        return writer.Write(shape->shape, filePath, version);
    } catch (...) { return false; }
}

bool OCCTVrmlWriteDocument(OCCTDocumentRef document, const char* filePath, double scale) {
    try {
        VrmlAPI_Writer writer;
        return writer.WriteDoc(document->doc, filePath, scale);
    } catch (...) { return false; }
}

// MARK: - UnitsAPI (v0.85)
// --- UnitsAPI ---

double OCCTUnitsAnyToAny(double value, const char* fromUnit, const char* toUnit) {
    try {
        return UnitsAPI::AnyToAny(value, fromUnit, toUnit);
    } catch (...) { return 0.0; }
}

double OCCTUnitsAnyToSI(double value, const char* unit) {
    try {
        return UnitsAPI::AnyToSI(value, unit);
    } catch (...) { return 0.0; }
}

double OCCTUnitsAnyFromSI(double value, const char* unit) {
    try {
        return UnitsAPI::AnyFromSI(value, unit);
    } catch (...) { return 0.0; }
}

double OCCTUnitsAnyToLS(double value, const char* unit) {
    try {
        return UnitsAPI::AnyToLS(value, unit);
    } catch (...) { return 0.0; }
}

double OCCTUnitsAnyFromLS(double value, const char* unit) {
    try {
        return UnitsAPI::AnyFromLS(value, unit);
    } catch (...) { return 0.0; }
}

void OCCTUnitsSetLocalSystem(int system) {
    try {
        UnitsAPI::SetLocalSystem(static_cast<UnitsAPI_SystemUnits>(system));
    } catch (...) { }
}

int OCCTUnitsGetLocalSystem() {
    try {
        return static_cast<int>(UnitsAPI::LocalSystem());
    } catch (...) { return 0; }
}


// MARK: - BinTools Shape I/O (v0.85)
// --- BinTools Shape I/O ---

const void* OCCTBinToolsWriteShape(OCCTShapeRef shape, int* outLength) {
    try {
        std::ostringstream oss;
        BinTools_ShapeWriter writer;
        writer.Write(shape->shape, oss);
        std::string data = oss.str();
        *outLength = (int)data.size();
        void* buf = malloc(data.size());
        memcpy(buf, data.data(), data.size());
        return buf;
    } catch (...) { *outLength = 0; return nullptr; }
}

OCCTShapeRef OCCTBinToolsReadShape(const void* data, int length) {
    try {
        std::string str((const char*)data, length);
        std::istringstream iss(str);
        BinTools_ShapeReader reader;
        TopoDS_Shape readShape;
        reader.Read(iss, readShape);
        if (readShape.IsNull()) return nullptr;
        return new OCCTShape(readShape);
    } catch (...) { return nullptr; }
}

bool OCCTBinToolsWriteShapeToFile(OCCTShapeRef shape, const char* filePath) {
    try {
        std::ofstream fout(filePath, std::ios::binary);
        if (!fout.is_open()) return false;
        BinTools_ShapeWriter writer;
        writer.Write(shape->shape, fout);
        return true;
    } catch (...) { return false; }
}

OCCTShapeRef OCCTBinToolsReadShapeFromFile(const char* filePath) {
    try {
        std::ifstream fin(filePath, std::ios::binary);
        if (!fin.is_open()) return nullptr;
        BinTools_ShapeReader reader;
        TopoDS_Shape readShape;
        reader.Read(fin, readShape);
        if (readShape.IsNull()) return nullptr;
        return new OCCTShape(readShape);
    } catch (...) { return nullptr; }
}

// MARK: - Message Messenger + Report (v0.85)
// --- Message_Messenger ---

OCCTMessengerRef OCCTMessengerCreate() {
    try {
        Handle(Message_Messenger) msg = new Message_Messenger();
        if (msg.IsNull()) return nullptr;
        msg->IncrementRefCounter();
        return msg.get();
    } catch (...) { return nullptr; }
}

void OCCTMessengerRelease(OCCTMessengerRef messenger) {
    try {
        auto* m = static_cast<Message_Messenger*>(messenger);
        m->DecrementRefCounter();
        if (m->GetRefCount() == 0) delete m;
    } catch (...) { }
}

int OCCTMessengerPrinterCount(OCCTMessengerRef messenger) {
    try {
        auto* m = static_cast<Message_Messenger*>(messenger);
        return m->Printers().Size();
    } catch (...) { return 0; }
}

void OCCTMessengerSend(OCCTMessengerRef messenger, const char* message, int gravity) {
    try {
        auto* m = static_cast<Message_Messenger*>(messenger);
        Message_Gravity g = static_cast<Message_Gravity>(gravity);
        m->Send(TCollection_AsciiString(message), g);
    } catch (...) { }
}

bool OCCTMessengerAddFilePrinter(OCCTMessengerRef messenger, const char* filePath, int gravity) {
    try {
        auto* m = static_cast<Message_Messenger*>(messenger);
        Message_Gravity g = static_cast<Message_Gravity>(gravity);
        Handle(Message_PrinterOStream) printer = new Message_PrinterOStream(filePath, false, g);
        return m->AddPrinter(printer);
    } catch (...) { return false; }
}

void OCCTMessengerRemoveAllPrinters(OCCTMessengerRef messenger) {
    try {
        auto* m = static_cast<Message_Messenger*>(messenger);
        // Remove by type — remove all Standard_Transient printers
        Handle(Standard_Type) printerType = STANDARD_TYPE(Message_Printer);
        m->RemovePrinters(printerType);
    } catch (...) { }
}

// --- Message_Report ---

OCCTReportRef OCCTReportCreate() {
    try {
        Handle(Message_Report) report = new Message_Report();
        if (report.IsNull()) return nullptr;
        report->IncrementRefCounter();
        return report.get();
    } catch (...) { return nullptr; }
}

void OCCTReportRelease(OCCTReportRef report) {
    try {
        auto* r = static_cast<Message_Report*>(report);
        r->DecrementRefCounter();
        if (r->GetRefCount() == 0) delete r;
    } catch (...) { }
}

void OCCTReportSetLimit(OCCTReportRef report, int limit) {
    try {
        auto* r = static_cast<Message_Report*>(report);
        r->SetLimit(limit);
    } catch (...) { }
}

int OCCTReportGetLimit(OCCTReportRef report) {
    try {
        auto* r = static_cast<Message_Report*>(report);
        return r->Limit();
    } catch (...) { return 0; }
}

void OCCTReportClear(OCCTReportRef report) {
    try {
        auto* r = static_cast<Message_Report*>(report);
        r->Clear();
    } catch (...) { }
}

void OCCTReportClearByGravity(OCCTReportRef report, int gravity) {
    try {
        auto* r = static_cast<Message_Report*>(report);
        r->Clear(static_cast<Message_Gravity>(gravity));
    } catch (...) { }
}

const char* OCCTReportDump(OCCTReportRef report) {
    try {
        auto* r = static_cast<Message_Report*>(report);
        std::ostringstream oss;
        r->Dump(oss);
        std::string str = oss.str();
        char* result = (char*)malloc(str.size() + 1);
        strcpy(result, str.c_str());
        return result;
    } catch (...) { return nullptr; }
}

const char* OCCTReportDumpByGravity(OCCTReportRef report, int gravity) {
    try {
        auto* r = static_cast<Message_Report*>(report);
        std::ostringstream oss;
        r->Dump(oss, static_cast<Message_Gravity>(gravity));
        std::string str = oss.str();
        char* result = (char*)malloc(str.size() + 1);
        strcpy(result, str.c_str());
        return result;
    } catch (...) { return nullptr; }
}

// MARK: - v0.91: OSD_Timer
// MARK: - OSD_Timer (v0.91.0)

#include <OSD_Timer.hxx>

struct OCCTTimer {
    OSD_Timer timer;
};

OCCTTimerRef OCCTTimerCreate() {
    return new OCCTTimer();
}

void OCCTTimerRelease(OCCTTimerRef timer) {
    delete timer;
}

void OCCTTimerStart(OCCTTimerRef timer) {
    timer->timer.Start();
}

void OCCTTimerStop(OCCTTimerRef timer) {
    timer->timer.Stop();
}

void OCCTTimerReset(OCCTTimerRef timer) {
    timer->timer.Reset();
}

double OCCTTimerElapsedTime(OCCTTimerRef timer) {
    return timer->timer.ElapsedTime();
}

double OCCTTimerGetWallClockTime() {
    return OSD_Timer::GetWallClockTime();
}

// MARK: - v0.93: OSD_MemInfo
// MARK: - OSD_MemInfo (v0.93.0)

#include <OSD_MemInfo.hxx>

int64_t OCCTMemInfoHeapUsage() {
    try {
        OSD_MemInfo info(true);
        return (int64_t)info.Value(OSD_MemInfo::MemHeapUsage);
    } catch (...) { return -1; }
}

int64_t OCCTMemInfoWorkingSet() {
    try {
        OSD_MemInfo info(true);
        return (int64_t)info.Value(OSD_MemInfo::MemWorkingSet);
    } catch (...) { return -1; }
}

double OCCTMemInfoHeapUsageMiB() {
    try {
        OSD_MemInfo info(true);
        return info.ValuePreciseMiB(OSD_MemInfo::MemHeapUsage);
    } catch (...) { return -1.0; }
}

const char* OCCTMemInfoString() {
    try {
        TCollection_AsciiString str = OSD_MemInfo::PrintInfo();
        return strdup(str.ToCString());
    } catch (...) { return nullptr; }
}

void OCCTMemInfoFreeString(const char* str) {
    if (str) free((void*)str);
}

// MARK: - v0.94: OSD_Environment
// MARK: - OSD_Environment (v0.94.0)

#include <OSD_Environment.hxx>

const char* OCCTEnvironmentGet(const char* name) {
    try {
        TCollection_AsciiString aname(name);
        OSD_Environment env(aname);
        TCollection_AsciiString val = env.Value();
        if (val.Length() == 0) return nullptr;
        return strdup(val.ToCString());
    } catch (...) { return nullptr; }
}

bool OCCTEnvironmentSet(const char* name, const char* value) {
    try {
        TCollection_AsciiString aname(name);
        TCollection_AsciiString aval(value);
        OSD_Environment env(aname, aval);
        env.Build();
        return !env.Failed();
    } catch (...) { return false; }
}

void OCCTEnvironmentRemove(const char* name) {
    try {
        TCollection_AsciiString aname(name);
        OSD_Environment env(aname);
        env.Remove();
    } catch (...) {}
}

void OCCTEnvironmentFreeString(const char* str) {
    if (str) free((void*)str);
}

// MARK: - v0.96/v0.98/v0.99: OSD_Path + OSD_Chronometer + OSD_Process + OSD_File
// MARK: - OSD_Path (v0.96.0)

#include <OSD_Path.hxx>

const char* OCCTOSDPathName(const char* path) {
    try {
        TCollection_AsciiString apath(path);
        OSD_Path p(apath);
        TCollection_AsciiString name = p.Name();
        return strdup(name.ToCString());
    } catch (...) { return nullptr; }
}

const char* OCCTOSDPathExtension(const char* path) {
    try {
        TCollection_AsciiString apath(path);
        OSD_Path p(apath);
        TCollection_AsciiString ext = p.Extension();
        return strdup(ext.ToCString());
    } catch (...) { return nullptr; }
}

const char* OCCTOSDPathTrek(const char* path) {
    try {
        TCollection_AsciiString apath(path);
        OSD_Path p(apath);
        TCollection_AsciiString trek = p.Trek();
        return strdup(trek.ToCString());
    } catch (...) { return nullptr; }
}

const char* OCCTOSDPathSystemName(const char* path) {
    try {
        TCollection_AsciiString apath(path);
        OSD_Path p(apath);
        TCollection_AsciiString sysName;
        p.SystemName(sysName);
        return strdup(sysName.ToCString());
    } catch (...) { return nullptr; }
}

void OCCTOSDPathFolderAndFile(const char* path, const char** outFolder, const char** outFile) {
    try {
        TCollection_AsciiString apath(path);
        TCollection_AsciiString folder, file;
        OSD_Path::FolderAndFileFromPath(apath, folder, file);
        *outFolder = strdup(folder.ToCString());
        *outFile = strdup(file.ToCString());
    } catch (...) {
        *outFolder = nullptr;
        *outFile = nullptr;
    }
}

bool OCCTOSDPathIsValid(const char* path) {
    try {
        TCollection_AsciiString apath(path);
        return OSD_Path::IsValid(apath);
    } catch (...) { return false; }
}

bool OCCTOSDPathIsUnixPath(const char* path) { return OSD_Path::IsUnixPath(path); }
bool OCCTOSDPathIsRelative(const char* path) { return OSD_Path::IsRelativePath(path); }
bool OCCTOSDPathIsAbsolute(const char* path) { return OSD_Path::IsAbsolutePath(path); }

void OCCTOSDPathFreeString(const char* str) {
    if (str) free((void*)str);
}
// MARK: - OSD_Chronometer (v0.98.0)

void OCCTGetProcessCPU(double* userSeconds, double* systemSeconds) {
    OSD_Chronometer::GetProcessCPU(*userSeconds, *systemSeconds);
}

void OCCTGetThreadCPU(double* userSeconds, double* systemSeconds) {
    OSD_Chronometer::GetThreadCPU(*userSeconds, *systemSeconds);
}

// MARK: - OSD_Process (v0.98.0)

#include <OSD_Process.hxx>

int32_t OCCTProcessId() {
    try { OSD_Process p; return p.ProcessId(); } catch (...) { return -1; }
}

const char* OCCTProcessUserName() {
    try {
        OSD_Process p;
        TCollection_AsciiString user = p.UserName();
        return strdup(user.ToCString());
    } catch (...) { return nullptr; }
}

const char* OCCTProcessExecutablePath() {
    try {
        TCollection_AsciiString path = OSD_Process::ExecutablePath();
        if (path.Length() == 0) return nullptr;
        return strdup(path.ToCString());
    } catch (...) { return nullptr; }
}

const char* OCCTProcessExecutableFolder() {
    try {
        TCollection_AsciiString path = OSD_Process::ExecutableFolder();
        if (path.Length() == 0) return nullptr;
        return strdup(path.ToCString());
    } catch (...) { return nullptr; }
}

void OCCTProcessFreeString(const char* str) { if (str) free((void*)str); }
// MARK: - OSD_File (v0.99.0)

#include <OSD_File.hxx>
#include <OSD_Path.hxx>
#include <OSD_Protection.hxx>
#include <OSD_OpenMode.hxx>

struct OCCTOSDFile {
    OSD_File file;
    OCCTOSDFile() {}
    explicit OCCTOSDFile(const OSD_Path& path) : file(path) {}
};

OCCTOSDFileRef OCCTFileCreate(const char* path) {
    try {
        TCollection_AsciiString apath(path);
        OSD_Path opath(apath);
        return new OCCTOSDFile(opath);
    } catch (...) { return new OCCTOSDFile(); }
}

OCCTOSDFileRef OCCTFileCreateTemporary(void) {
    try {
        auto* f = new OCCTOSDFile();
        f->file.BuildTemporary();
        return f;
    } catch (...) { return new OCCTOSDFile(); }
}

void OCCTFileRelease(OCCTOSDFileRef file) {
    delete file;
}

bool OCCTFileOpen(OCCTOSDFileRef file) {
    if (!file) return false;
    try {
        file->file.Build(OSD_ReadWrite, OSD_Protection());
        return !file->file.Failed();
    } catch (...) { return false; }
}

bool OCCTFileOpenReadOnly(OCCTOSDFileRef file) {
    if (!file) return false;
    try {
        file->file.Open(OSD_ReadOnly, OSD_Protection());
        return !file->file.Failed();
    } catch (...) { return false; }
}

bool OCCTFileWrite(OCCTOSDFileRef file, const char* data, int32_t length) {
    if (!file || !data || length <= 0) return false;
    try {
        TCollection_AsciiString str(data, length);
        file->file.Write(str, length);
        return !file->file.Failed();
    } catch (...) { return false; }
}

char* OCCTFileReadLine(OCCTOSDFileRef file, int32_t bufSize) {
    if (!file || bufSize <= 0) return nullptr;
    try {
        TCollection_AsciiString line;
        int actualRead = 0;
        file->file.ReadLine(line, bufSize, actualRead);
        if (file->file.Failed() && actualRead == 0) return nullptr;
        std::string s = line.ToCString();
        char* result = (char*)malloc(s.size() + 1);
        if (!result) return nullptr;
        memcpy(result, s.c_str(), s.size() + 1);
        return result;
    } catch (...) { return nullptr; }
}

char* OCCTFileReadAll(OCCTOSDFileRef file, int32_t* outLength) {
    if (!file || !outLength) return nullptr;
    *outLength = 0;
    try {
        // Get file size
        size_t sz = file->file.Size();
        if (file->file.Failed() || sz == 0) return nullptr;

        // Read entire content line by line
        std::string accumulated;
        accumulated.reserve(sz);
        while (!file->file.IsAtEnd() && !file->file.Failed()) {
            TCollection_AsciiString line;
            int n = 0;
            file->file.ReadLine(line, 65536, n);
            if (n > 0) {
                if (!accumulated.empty()) accumulated += "\n";
                accumulated += line.ToCString();
            } else {
                break;
            }
        }
        char* result = (char*)malloc(accumulated.size() + 1);
        if (!result) return nullptr;
        memcpy(result, accumulated.c_str(), accumulated.size() + 1);
        *outLength = (int32_t)accumulated.size();
        return result;
    } catch (...) { return nullptr; }
}

void OCCTFileClose(OCCTOSDFileRef file) {
    if (!file) return;
    try { file->file.Close(); } catch (...) {}
}

bool OCCTFileIsOpen(OCCTOSDFileRef file) {
    if (!file) return false;
    try { return file->file.IsOpen(); } catch (...) { return false; }
}

int64_t OCCTFileSize(OCCTOSDFileRef file) {
    if (!file) return -1;
    try {
        size_t sz = file->file.Size();
        if (file->file.Failed()) return -1;
        return (int64_t)sz;
    } catch (...) { return -1; }
}

void OCCTFileRewind(OCCTOSDFileRef file) {
    if (!file) return;
    try { file->file.Rewind(); } catch (...) {}
}

bool OCCTFileIsAtEnd(OCCTOSDFileRef file) {
    if (!file) return true;
    try { return file->file.IsAtEnd(); } catch (...) { return true; }
}

void OCCTFileFreeString(char* str) {
    free(str);
}

// MARK: - v0.100: APIHeaderSection_MakeHeader (STEP header)
// --- APIHeaderSection_MakeHeader ---

struct OCCTStepHeader {
    APIHeaderSection_MakeHeader header;
    OCCTStepHeader(const char* filename) : header(0) {
        header.Init(filename);
    }
};

OCCTStepHeaderRef OCCTStepHeaderCreate(const char* filename) {
    if (!filename) return nullptr;
    try {
        return new OCCTStepHeader(filename);
    } catch (...) { return nullptr; }
}

void OCCTStepHeaderRelease(OCCTStepHeaderRef header) {
    delete header;
}

bool OCCTStepHeaderIsDone(OCCTStepHeaderRef header) {
    if (!header) return false;
    try { return header->header.IsDone(); } catch (...) { return false; }
}

char* OCCTStepHeaderGetName(OCCTStepHeaderRef header) {
    if (!header) return nullptr;
    try {
        auto name = header->header.Name();
        if (name.IsNull()) return nullptr;
        return strdup(name->ToCString());
    } catch (...) { return nullptr; }
}

void OCCTStepHeaderSetName(OCCTStepHeaderRef header, const char* name) {
    if (!header || !name) return;
    try {
        header->header.SetName(new TCollection_HAsciiString(name));
    } catch (...) {}
}

char* OCCTStepHeaderGetTimeStamp(OCCTStepHeaderRef header) {
    if (!header) return nullptr;
    try {
        auto ts = header->header.TimeStamp();
        if (ts.IsNull()) return nullptr;
        return strdup(ts->ToCString());
    } catch (...) { return nullptr; }
}

void OCCTStepHeaderSetTimeStamp(OCCTStepHeaderRef header, const char* timestamp) {
    if (!header || !timestamp) return;
    try {
        header->header.SetTimeStamp(new TCollection_HAsciiString(timestamp));
    } catch (...) {}
}

char* OCCTStepHeaderGetAuthor(OCCTStepHeaderRef header) {
    if (!header) return nullptr;
    try {
        if (header->header.NbAuthor() < 1) return nullptr;
        auto val = header->header.AuthorValue(1);
        if (val.IsNull()) return nullptr;
        return strdup(val->ToCString());
    } catch (...) { return nullptr; }
}

void OCCTStepHeaderSetAuthor(OCCTStepHeaderRef header, const char* author) {
    if (!header || !author) return;
    try {
        header->header.SetAuthorValue(1, new TCollection_HAsciiString(author));
    } catch (...) {}
}

char* OCCTStepHeaderGetOrganization(OCCTStepHeaderRef header) {
    if (!header) return nullptr;
    try {
        if (header->header.NbOrganization() < 1) return nullptr;
        auto val = header->header.OrganizationValue(1);
        if (val.IsNull()) return nullptr;
        return strdup(val->ToCString());
    } catch (...) { return nullptr; }
}

void OCCTStepHeaderSetOrganization(OCCTStepHeaderRef header, const char* org) {
    if (!header || !org) return;
    try {
        header->header.SetOrganizationValue(1, new TCollection_HAsciiString(org));
    } catch (...) {}
}

char* OCCTStepHeaderGetPreprocessorVersion(OCCTStepHeaderRef header) {
    if (!header) return nullptr;
    try {
        auto val = header->header.PreprocessorVersion();
        if (val.IsNull()) return nullptr;
        return strdup(val->ToCString());
    } catch (...) { return nullptr; }
}

void OCCTStepHeaderSetPreprocessorVersion(OCCTStepHeaderRef header, const char* ppv) {
    if (!header || !ppv) return;
    try {
        header->header.SetPreprocessorVersion(new TCollection_HAsciiString(ppv));
    } catch (...) {}
}

char* OCCTStepHeaderGetOriginatingSystem(OCCTStepHeaderRef header) {
    if (!header) return nullptr;
    try {
        auto val = header->header.OriginatingSystem();
        if (val.IsNull()) return nullptr;
        return strdup(val->ToCString());
    } catch (...) { return nullptr; }
}

void OCCTStepHeaderSetOriginatingSystem(OCCTStepHeaderRef header, const char* os) {
    if (!header || !os) return;
    try {
        header->header.SetOriginatingSystem(new TCollection_HAsciiString(os));
    } catch (...) {}
}

// MARK: - v0.101: Resource_Manager
// --- Resource_Manager ---

struct OCCTResourceManager {
    Handle(Resource_Manager) mgr;
};

OCCTResourceManagerRef OCCTResourceManagerCreate(void) {
    OCCTResourceManager* rm = new OCCTResourceManager();
    rm->mgr = new Resource_Manager();
    return rm;
}

void OCCTResourceManagerRelease(OCCTResourceManagerRef mgr) {
    delete mgr;
}

void OCCTResourceManagerSetString(OCCTResourceManagerRef mgr, const char* key, const char* value) {
    try { mgr->mgr->SetResource(key, value); } catch (...) {}
}

void OCCTResourceManagerSetInt(OCCTResourceManagerRef mgr, const char* key, int32_t value) {
    try { mgr->mgr->SetResource(key, (int)value); } catch (...) {}
}

void OCCTResourceManagerSetReal(OCCTResourceManagerRef mgr, const char* key, double value) {
    try { mgr->mgr->SetResource(key, value); } catch (...) {}
}

bool OCCTResourceManagerFind(OCCTResourceManagerRef mgr, const char* key) {
    try { return mgr->mgr->Find(key); } catch (...) { return false; }
}

char* OCCTResourceManagerGetString(OCCTResourceManagerRef mgr, const char* key) {
    try {
        const char* val = mgr->mgr->Value(key);
        return strdup(val);
    } catch (...) { return nullptr; }
}

int32_t OCCTResourceManagerGetInt(OCCTResourceManagerRef mgr, const char* key) {
    try { return (int32_t)mgr->mgr->Integer(key); } catch (...) { return 0; }
}

double OCCTResourceManagerGetReal(OCCTResourceManagerRef mgr, const char* key) {
    try { return mgr->mgr->Real(key); } catch (...) { return 0.0; }
}


// MARK: - v0.104: OSD_Host + OSD_PerfMeter
// MARK: - OSD_Host (v0.104.0)

#include <OSD_Host.hxx>

char* OCCTHostName(void) {
    try {
        OSD_Host host;
        return strdup(host.HostName().ToCString());
    } catch (...) { return nullptr; }
}

char* OCCTSystemVersion(void) {
    try {
        OSD_Host host;
        return strdup(host.SystemVersion().ToCString());
    } catch (...) { return nullptr; }
}

char* OCCTInternetAddress(void) {
    try {
        OSD_Host host;
        return strdup(host.InternetAddress().ToCString());
    } catch (...) { return nullptr; }
}
// MARK: - OSD_PerfMeter (v0.104.0)

#include <OSD_PerfMeter.hxx>

struct OCCTPerfMeter {
    OSD_PerfMeter meter;
};

OCCTPerfMeterRef OCCTPerfMeterCreate(const char* name) {
    auto m = new OCCTPerfMeter();
    TCollection_AsciiString n(name);
    m->meter.Init(n);
    m->meter.Start();
    return m;
}

void OCCTPerfMeterRelease(OCCTPerfMeterRef meter) { delete meter; }
void OCCTPerfMeterStart(OCCTPerfMeterRef meter) { meter->meter.Start(); }
void OCCTPerfMeterStop(OCCTPerfMeterRef meter) { meter->meter.Stop(); }
double OCCTPerfMeterElapsed(OCCTPerfMeterRef meter) { return meter->meter.Elapsed(); }

// MARK: - v0.105: OSD_Directory + Resource_Unicode
// MARK: - OSD_Directory (v0.105.0)

#include <OSD_Directory.hxx>
#include <OSD_Path.hxx>
#include <OSD_Protection.hxx>

bool OCCTDirectoryExists(const char* path) {
    try {
        TCollection_AsciiString aPath(path);
        OSD_Path osdPath(aPath);
        OSD_Directory dir(osdPath);
        return dir.Exists();
    } catch (...) { return false; }
}

bool OCCTDirectoryCreate(const char* path) {
    try {
        TCollection_AsciiString aPath(path);
        OSD_Path osdPath(aPath);
        OSD_Directory dir(osdPath);
        OSD_Protection prot;
        dir.Build(prot);
        return dir.Exists();
    } catch (...) { return false; }
}

char* OCCTDirectoryBuildTemporary(void) {
    try {
        OSD_Directory tmpDir = OSD_Directory::BuildTemporary();
        OSD_Path tmpPath;
        tmpDir.Path(tmpPath);
        TCollection_AsciiString sysName;
        tmpPath.SystemName(sysName);
        return strdup(sysName.ToCString());
    } catch (...) { return nullptr; }
}

bool OCCTDirectoryRemove(const char* path) {
    try {
        TCollection_AsciiString aPath(path);
        OSD_Path osdPath(aPath);
        OSD_Directory dir(osdPath);
        if (!dir.Exists()) return false;
        dir.Remove();
        return !dir.Exists();
    } catch (...) { return false; }
}
// MARK: - Resource_Unicode (v0.105.0)

#include <Resource_Unicode.hxx>

void OCCTUnicodeSetFormat(int32_t format) {
    try {
        Resource_FormatType fmt;
        switch (format) {
            case 0: fmt = Resource_FormatType_SJIS; break;
            case 1: fmt = Resource_FormatType_EUC; break;
            case 2: fmt = Resource_FormatType_GB; break;
            case 3: fmt = Resource_FormatType_ANSI; break;
            default: fmt = Resource_FormatType_ANSI; break;
        }
        Resource_Unicode::SetFormat(fmt);
    } catch (...) {}
}

int32_t OCCTUnicodeGetFormat(void) {
    try {
        Resource_FormatType fmt = Resource_Unicode::GetFormat();
        switch (fmt) {
            case Resource_FormatType_SJIS: return 0;
            case Resource_FormatType_EUC: return 1;
            case Resource_FormatType_GB: return 2;
            case Resource_FormatType_ANSI: return 3;
            default: return 3;
        }
    } catch (...) { return 3; }
}

char* OCCTUnicodeConvertToUnicode(const char* input) {
    try {
        TCollection_AsciiString aStr(input);
        TCollection_ExtendedString eStr;
        Resource_Unicode::ConvertFormatToUnicode(aStr.ToCString(), eStr);
        // Convert extended string to a simple C string (ASCII portion)
        std::string result;
        for (int i = 1; i <= eStr.Length(); i++) {
            char16_t c = eStr.Value(i);
            if (c < 128) {
                result += (char)c;
            }
        }
        return strdup(result.c_str());
    } catch (...) { return nullptr; }
}

bool OCCTUnicodeConvertFromUnicode(const char* utf8Input, char* output, int32_t maxSize) {
    try {
        TCollection_ExtendedString eStr(utf8Input, true);
        Standard_PCharacter buf = output;
        bool ok = Resource_Unicode::ConvertUnicodeToFormat(eStr, buf, maxSize);
        return ok;
    } catch (...) { return false; }
}

// MARK: - v0.106: OSD_DirectoryIterator + OSD_FileIterator
// MARK: - OSD_DirectoryIterator (v0.106.0)

#include <OSD_DirectoryIterator.hxx>
#include <OSD_Directory.hxx>

int32_t OCCTDirectoryIteratorCount(const char* path, const char* mask) {
    try {
        TCollection_AsciiString aPath(path);
        OSD_Path osdPath(aPath);
        TCollection_AsciiString aMask(mask);
        OSD_DirectoryIterator it(osdPath, aMask);
        int32_t count = 0;
        while (it.More()) {
            count++;
            it.Next();
            if (count > 10000) break;
        }
        return count;
    } catch (...) { return 0; }
}

char* OCCTDirectoryIteratorName(const char* path, const char* mask, int32_t index) {
    try {
        TCollection_AsciiString aPath(path);
        OSD_Path osdPath(aPath);
        TCollection_AsciiString aMask(mask);
        OSD_DirectoryIterator it(osdPath, aMask);
        int32_t i = 0;
        while (it.More()) {
            if (i == index) {
                OSD_Directory dir = it.Values();
                OSD_Path dirPath;
                dir.Path(dirPath);
                TCollection_AsciiString name;
                dirPath.SystemName(name);
                return strdup(name.ToCString());
            }
            i++;
            it.Next();
            if (i > 10000) break;
        }
        return nullptr;
    } catch (...) { return nullptr; }
}

int32_t OCCTDirectoryList(const char* path, const char* mask, char** names, int32_t maxCount) {
    try {
        TCollection_AsciiString aPath(path);
        OSD_Path osdPath(aPath);
        TCollection_AsciiString aMask(mask);
        OSD_DirectoryIterator it(osdPath, aMask);
        int32_t count = 0;
        while (it.More() && count < maxCount) {
            OSD_Directory dir = it.Values();
            OSD_Path dirPath;
            dir.Path(dirPath);
            TCollection_AsciiString name;
            dirPath.SystemName(name);
            names[count] = strdup(name.ToCString());
            count++;
            it.Next();
        }
        return count;
    } catch (...) { return 0; }
}
// MARK: - OSD_FileIterator (v0.106.0)

#include <OSD_FileIterator.hxx>

int32_t OCCTFileIteratorCount(const char* path, const char* mask) {
    try {
        TCollection_AsciiString aPath(path);
        OSD_Path osdPath(aPath);
        TCollection_AsciiString aMask(mask);
        OSD_FileIterator it(osdPath, aMask);
        int32_t count = 0;
        while (it.More()) {
            count++;
            it.Next();
            if (count > 10000) break;
        }
        return count;
    } catch (...) { return 0; }
}

char* OCCTFileIteratorName(const char* path, const char* mask, int32_t index) {
    try {
        TCollection_AsciiString aPath(path);
        OSD_Path osdPath(aPath);
        TCollection_AsciiString aMask(mask);
        OSD_FileIterator it(osdPath, aMask);
        int32_t i = 0;
        while (it.More()) {
            if (i == index) {
                OSD_File file = it.Values();
                OSD_Path filePath;
                file.Path(filePath);
                TCollection_AsciiString name;
                filePath.SystemName(name);
                return strdup(name.ToCString());
            }
            i++;
            it.Next();
            if (i > 10000) break;
        }
        return nullptr;
    } catch (...) { return nullptr; }
}

int32_t OCCTFileList(const char* path, const char* mask, char** names, int32_t maxCount) {
    try {
        TCollection_AsciiString aPath(path);
        OSD_Path osdPath(aPath);
        TCollection_AsciiString aMask(mask);
        OSD_FileIterator it(osdPath, aMask);
        int32_t count = 0;
        while (it.More() && count < maxCount) {
            OSD_File file = it.Values();
            OSD_Path filePath;
            file.Path(filePath);
            TCollection_AsciiString name;
            filePath.SystemName(name);
            names[count] = strdup(name.ToCString());
            count++;
            it.Next();
        }
        return count;
    } catch (...) { return 0; }
}

// MARK: - v0.109: OSD_Disk + OSD_SharedLibrary + Message_Msg
// MARK: - OSD_Disk (v0.109.0)

#include <OSD_Disk.hxx>
#include <OSD_Path.hxx>

int64_t OCCTDiskSize(const char* path) {
    try {
        TCollection_AsciiString apath(path);
        OSD_Path opath(apath);
        OSD_Disk disk(opath);
        return (int64_t)disk.DiskSize();
    } catch (...) { return 0; }
}

int64_t OCCTDiskFree(const char* path) {
    try {
        TCollection_AsciiString apath(path);
        OSD_Path opath(apath);
        OSD_Disk disk(opath);
        return (int64_t)disk.DiskFree();
    } catch (...) { return 0; }
}

bool OCCTDiskIsValid(const char* path) {
    try {
        TCollection_AsciiString apath(path);
        OSD_Path opath(apath);
        OSD_Disk disk(opath);
        // If it doesn't throw, it's valid enough
        disk.DiskSize();
        return true;
    } catch (...) { return false; }
}

char* OCCTDiskName(const char* path) {
    try {
        TCollection_AsciiString apath(path);
        OSD_Path opath(apath);
        OSD_Disk disk(opath);
        OSD_Path namePath = disk.Name();
        TCollection_AsciiString nameStr;
        namePath.SystemName(nameStr);
        return strdup(nameStr.ToCString());
    } catch (...) { return nullptr; }
}

// MARK: - OSD_SharedLibrary (v0.109.0)

#include <OSD_SharedLibrary.hxx>

struct OCCTSharedLib {
    OSD_SharedLibrary lib;
    OCCTSharedLib(const char* name) : lib(name) {}
};

OCCTSharedLibRef OCCTSharedLibCreate(const char* name) {
    try {
        return new OCCTSharedLib(name);
    } catch (...) { return nullptr; }
}

void OCCTSharedLibRelease(OCCTSharedLibRef lib) {
    delete lib;
}

bool OCCTSharedLibOpen(OCCTSharedLibRef lib) {
    if (!lib) return false;
    try {
        return lib->lib.DlOpen(OSD_RTLD_LAZY);
    } catch (...) { return false; }
}

void OCCTSharedLibClose(OCCTSharedLibRef lib) {
    if (!lib) return;
    try {
        lib->lib.DlClose();
    } catch (...) {}
}

char* OCCTSharedLibName(OCCTSharedLibRef lib) {
    if (!lib) return nullptr;
    try {
        const char* name = lib->lib.Name();
        return name ? strdup(name) : nullptr;
    } catch (...) { return nullptr; }
}
// MARK: - Message_Msg (v0.109.0)

#include <Message_Msg.hxx>
#include <Message_MsgFile.hxx>

char* OCCTMessageMsgGet(const char* key) {
    try {
        Message_Msg msg(key);
        TCollection_ExtendedString str = msg.Get();
        TCollection_AsciiString astr(str);
        return strdup(astr.ToCString());
    } catch (...) { return nullptr; }
}

bool OCCTMessageMsgFileLoad(const char* fileName) {
    try {
        return Message_MsgFile::LoadFile(fileName);
    } catch (...) { return false; }
}

bool OCCTMessageMsgFileLoadDefault(void) {
    try {
        return Message_MsgFile::LoadFromEnv("CSF_XHatch", "");
    } catch (...) { return false; }
}

bool OCCTMessageMsgHasMsg(const char* key) {
    try {
        return Message_MsgFile::HasMsg(TCollection_AsciiString(key));
    } catch (...) { return false; }
}

// MARK: - v0.116: UnitsAPI helpers
double OCCTUnitsGetLengthFactor(int32_t unit) {
    try {
        return UnitsMethods::GetLengthFactorValue(unit);
    } catch (...) { return 0.0; }
}

double OCCTUnitsGetLengthUnitScale(int32_t fromUnit, int32_t toUnit) {
    try {
        return UnitsMethods::GetLengthUnitScale((UnitsMethods_LengthUnit)fromUnit,
                                                 (UnitsMethods_LengthUnit)toUnit);
    } catch (...) { return 0.0; }
}

const char* _Nullable OCCTUnitsDumpLengthUnit(int32_t unit) {
    try {
        return UnitsMethods::DumpLengthUnit((UnitsMethods_LengthUnit)unit);
    } catch (...) { return nullptr; }
}

// GeomLProp_CLProps (was LProp3d_CLProps in RC4)

#include <GeomLProp_CLProps.hxx>

// MARK: - v0.118: BREP string serialization
// --- BREP string serialization ---

char* OCCTShapeToBREPString(OCCTShapeRef shape) {
    try {
        auto* s = static_cast<OCCTShape*>(shape);
        std::ostringstream oss;
        BRepTools::Write(s->shape, oss);
        std::string str = oss.str();
        char* result = (char*)malloc(str.size() + 1);
        if (!result) return nullptr;
        memcpy(result, str.c_str(), str.size() + 1);
        return result;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTShapeFromBREPString(const char* brepString) {
    try {
        std::istringstream iss(brepString);
        BRep_Builder builder;
        TopoDS_Shape shape;
        BRepTools::Read(shape, iss, builder);
        if (shape.IsNull()) return nullptr;
        auto* r = new OCCTShape();
        r->shape = shape;
        return r;
    } catch (...) { return nullptr; }
}

// MARK: - v0.121: GLTF Import/Export
// end of v0.124.0 implementations

// MARK: - GLTF Import/Export (v0.121.0)

#include <RWGltf_CafReader.hxx>
#include <RWGltf_CafWriter.hxx>

OCCTShapeRef _Nullable OCCTImportGLTF(const char* _Nonnull path) {
    if (!path) return nullptr;
    try {
        RWGltf_CafReader reader;
        Handle(TDocStd_Document) doc;
        Handle(XCAFApp_Application) app = XCAFApp_Application::GetApplication();
        app->NewDocument("MDTV-XCAF", doc);
        reader.SetDocument(doc);
        TCollection_AsciiString filePath(path);
        if (!reader.Perform(filePath, Message_ProgressRange())) return nullptr;
        Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
        TopoDS_Shape shape = shapeTool->GetOneShape();
        if (shape.IsNull()) return nullptr;
        auto* ref = new OCCTShape;
        ref->shape = shape;
        return ref;
    } catch (...) { return nullptr; }
}

bool OCCTExportGLTF(OCCTShapeRef _Nonnull shape, const char* _Nonnull path,
                      bool isBinary, double deflection) {
    if (!shape || !path) return false;
    try {
        BRepMesh_IncrementalMesh mesher(shape->shape, deflection);
        Handle(TDocStd_Document) doc;
        Handle(XCAFApp_Application) app = XCAFApp_Application::GetApplication();
        app->NewDocument("MDTV-XCAF", doc);
        Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
        shapeTool->AddShape(shape->shape);
        TCollection_AsciiString filePath(path);
        RWGltf_CafWriter writer(filePath, isBinary);
        NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> fileInfo;
        return writer.Perform(doc, fileInfo, Message_ProgressRange());
    } catch (...) { return false; }
}

OCCTDocumentRef _Nullable OCCTDocumentLoadGLTF(const char* _Nonnull path) {
    if (!path) return nullptr;
    try {
        auto* docRef = new OCCTDocument;
        Handle(XCAFApp_Application) app = XCAFApp_Application::GetApplication();
        app->NewDocument("MDTV-XCAF", docRef->doc);
        RWGltf_CafReader reader;
        reader.SetDocument(docRef->doc);
        TCollection_AsciiString filePath(path);
        if (!reader.Perform(filePath, Message_ProgressRange())) {
            delete docRef;
            return nullptr;
        }
        return docRef;
    } catch (...) { return nullptr; }
}

bool OCCTDocumentWriteGLTF(OCCTDocumentRef _Nonnull doc, const char* _Nonnull path, bool isBinary) {
    if (!doc || !path) return false;
    try {
        TCollection_AsciiString filePath(path);
        RWGltf_CafWriter writer(filePath, isBinary);
        NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> fileInfo;
        return writer.Perform(doc->doc, fileInfo, Message_ProgressRange());
    } catch (...) { return false; }
}

// end of v0.121.0 implementations

// MARK: - IGES Import/Export (v0.10.0)
// IGES reader/writer uses C-level global state (iges_newparam, iges_param, etc.)
// that is NOT thread-safe. All IGES operations MUST be serialized.
// See: https://github.com/Open-Cascade-SAS/OCCT/issues/1179
// Non-static (declared in OCCTBridge_Internal.h) so per-area TUs share the
// same underlying mutex via the linker.
std::mutex& igesMutex() {
    static std::mutex mutex;
    return mutex;
}

OCCTShapeRef OCCTImportIGES(const char* path) {
    if (!path) return nullptr;

    std::lock_guard<std::mutex> igesLock(igesMutex());
    try {
        IGESControl_Reader reader;
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return nullptr;

        // Transfer all roots
        reader.TransferRoots();

        // Get the result as a single shape (compound if multiple)
        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return nullptr;

        return new OCCTShape(shape);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTImportIGESRobust(const char* path) {
    if (!path) return nullptr;

    std::lock_guard<std::mutex> igesLock(igesMutex());
    try {
        IGESControl_Reader reader;

        // Configure reader for better handling
        Interface_Static::SetIVal("read.precision.mode", 0);
        Interface_Static::SetRVal("read.precision.val", 0.0001);

        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return nullptr;

        if (reader.TransferRoots() == 0) return nullptr;

        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return nullptr;

        // Apply shape healing
        ShapeFix_Shape fixer(shape);
        fixer.Perform();
        TopoDS_Shape fixed = fixer.Shape();

        return new OCCTShape(fixed.IsNull() ? shape : fixed);
    } catch (...) {
        return nullptr;
    }
}

bool OCCTExportIGES(OCCTShapeRef shape, const char* path) {
    if (!shape || !path) return false;
    if (shape->shape.IsNull()) return false;

    std::lock_guard<std::mutex> igesLock(igesMutex());
    try {
        // Validate shape before IGES export — OCCT translator can segfault on invalid geometry
        BRepCheck_Analyzer analyzer(shape->shape);
        if (!analyzer.IsValid()) return false;

        bool success = false;
        {
            IGESControl_Writer writer("MM", 0);  // Millimeters, faces mode

            if (!writer.AddShape(shape->shape)) {
                return false;
            }

            writer.ComputeModel();
            success = writer.Write(path);
        }
        return success;
    } catch (...) {
        return false;
    }
}


// MARK: - BREP Native Format (v0.10.0)

OCCTShapeRef OCCTImportBREP(const char* path) {
    if (!path) return nullptr;

    try {
        TopoDS_Shape shape;
        BRep_Builder builder;

        if (!BRepTools::Read(shape, path, builder)) {
            return nullptr;
        }

        if (shape.IsNull()) return nullptr;

        return new OCCTShape(shape);
    } catch (...) {
        return nullptr;
    }
}

bool OCCTExportBREP(OCCTShapeRef shape, const char* path) {
    if (!shape || !path) return false;

    try {
        return BRepTools::Write(shape->shape, path);
    } catch (...) {
        return false;
    }
}

bool OCCTExportBREPWithTriangles(OCCTShapeRef shape, const char* path, bool withTriangles, bool withNormals) {
    if (!shape || !path) return false;

    try {
        return BRepTools::Write(shape->shape, path, withTriangles, withNormals, TopTools_FormatVersion_CURRENT);
    } catch (...) {
        return false;
    }
}


