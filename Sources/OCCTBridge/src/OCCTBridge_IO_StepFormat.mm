//
//  OCCTBridge_IO_StepFormat.mm
//  OCCTSwift
//
//  Split from OCCTBridge_IO.mm (#396/#1378-follow-on): STEPControl, STEPCAFControl,
//  APIHeaderSection (STEP header). Public C surface unchanged; every sibling file imports the same
//  headers this one does (the shared preamble below). No symbol changes, pure file move -- see
//  Scripts/repro/396-bridge-mm-split/ for how.
//

//
//  OCCTBridge_IO.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm, issue #99.
//
//  File I/O surface: STEP / IGES / STL / BREP / OBJ writers and the matching
//  importers. Plus the import-progress + cancellation channel from v0.168.0
//  / v0.169.0 (issue #98), since those entry points share readers/writers
//  with the synchronous variants.
//
//  Public C surface unchanged. No symbol changes: a pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <Standard_ErrorHandler.hxx> // OCC_CATCH_SIGNALS (#175)
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
#include <atomic>
#include <sstream>
#include <XCAFDoc_DocumentTool.hxx>
#include <TDF_LabelSequence.hxx>
#include <TDF_Label.hxx>
#include <RWObj_CafReader.hxx>
#include <RWObj_CafWriter.hxx>
#include <RWPly_CafWriter.hxx>
#include <TDocStd_Document.hxx>
#include <TDocStd_Application.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <IMeshTools_Parameters.hxx>
#include <StlAPI_Writer.hxx>
#include <StlAPI_Reader.hxx>
#include <BinTools.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <TopoDS_Iterator.hxx>
#include <TopoDS_Compound.hxx>

// Additional includes gathered from throughout the original file (#396/#1378-follow-on):
#include <StepTidy_DuplicateCleaner.hxx>
#include <RWMesh_CoordinateSystemConverter.hxx>
#include <RWMesh_CoordinateSystem.hxx>
#include <OSD_Timer.hxx>
#include <OSD_MemInfo.hxx>
#include <OSD_Environment.hxx>
#include <OSD_Path.hxx>
#include <OSD_Process.hxx>
#include <OSD_File.hxx>
#include <OSD_Protection.hxx>
#include <OSD_OpenMode.hxx>
#include <OSD_Host.hxx>
#include <OSD_PerfMeter.hxx>
#include <OSD_Directory.hxx>
#include <Resource_Unicode.hxx>
#include <OSD_DirectoryIterator.hxx>
#include <OSD_FileIterator.hxx>
#include <OSD_Disk.hxx>
#include <OSD_SharedLibrary.hxx>
#include <Message_Msg.hxx>
#include <Message_MsgFile.hxx>
#include <GeomLProp_CLProps.hxx>
#include <RWGltf_CafReader.hxx>
#include <RWGltf_CafWriter.hxx>

// Shared private structs/helpers (#396/#1378-follow-on): every split file gets this identical
// block, compiled independently per TU -- see this split's own README for why.

namespace
{

class BridgeProgressIndicator : public Message_ProgressIndicator
{
public:
  BridgeProgressIndicator(const OCCTImportProgress* ctx)
      : myCtx(ctx)
  {
  }

  void Show(const Message_ProgressScope& theScope, const Standard_Boolean isForce) override
  {
    (void)isForce;
    if (!myCtx || !myCtx->onProgress)
      return;
    // GetPosition() reports global progress 0.0...1.0.
    const double fraction = GetPosition();
    const char*  name     = theScope.Name();
    myCtx->onProgress(fraction, name, myCtx->userData);
  }

  // Latches the break rather than re-asking. OCCT polls this from every scope that guards a
  // loop, and the bridge polls it again at each phase boundary, so a caller that answers
  // "cancel" once -- a one-shot flag, a Task.isCancelled read that has already been consumed --
  // used to have that answer overwritten by the next poll: the algorithm aborted, the later
  // poll said "no break", and the call handed back its half-finished result as a success.
  // The documented contract is that a single true stops the call (#525).
  Standard_Boolean UserBreak() override
  {
    if (myBroken.load(std::memory_order_relaxed))
      return Standard_True;
    if (!myCtx || !myCtx->shouldCancel)
      return Standard_False;
    if (!myCtx->shouldCancel(myCtx->userData))
      return Standard_False;
    myBroken.store(true, std::memory_order_relaxed);
    return Standard_True;
  }

  // Whether a break was ever observed, without polling the caller again. std::atomic because
  // OCCT documents UserBreak() as callable concurrently (Message_ProgressIndicator.hxx).
  bool Cancelled() const { return myBroken.load(std::memory_order_relaxed); }

  DEFINE_STANDARD_RTTI_INLINE(BridgeProgressIndicator, Message_ProgressIndicator)

private:
  const OCCTImportProgress* myCtx;
  std::atomic<bool>         myBroken{false};
};

DEFINE_STANDARD_HANDLE(BridgeProgressIndicator, Message_ProgressIndicator)

static inline void clearCancelOut(bool* outCancelled)
{
  if (outCancelled)
    *outCancelled = false;
}

// Report a cancelled call as cancelled whichever exit it takes (#525).
//
// The explicit UserBreak() checkpoints are not the only way out of these functions: an aborted
// TransferRoots reports zero transferred roots, an aborted transfer can leave a null shape or a
// non-Done status behind, and a break raised inside OCCT arrives here as an exception. Those
// paths used to return "failed" for a call the caller had explicitly cancelled, so which error a
// caller saw depended on which phase the cancellation happened to land in. Every failure return
// below the indicator's construction therefore passes through this, and it reads the latch rather
// than polling again -- the answer belongs to the poll that actually stopped the work.
static inline void setCancelOut(bool*                                               outCancelled,
                                const opencascade::handle<BridgeProgressIndicator>& ind)
{
  if (outCancelled)
    *outCancelled = !ind.IsNull() && ind->Cancelled();
}

// Turn every shell a sewing produced into a solid, rather than only the first (#302).
//
// The robust importers used to do `TopExp_Explorer(sewed, TopAbs_SHELL)` and keep `.Current()`
// alone, so every body after the first was silently discarded: 10 boxes in, 1 box out, no error.
// Sewing itself is fine -- it returns one shell per body -- the truncation was ours.
//
// Iterates a compound's IMMEDIATE children rather than exploring for shells, because an explorer
// descends INTO solids: a hollow body owns an outer shell plus one per void, and solidifying those
// separately would split one body into several. Shapes we cannot solidify are passed through
// untouched rather than dropped -- losing them silently is the defect being fixed.
//
// Shape of the result follows the input, since a sewing yields a bare SHELL for a single body and
// a compound of shells for several: one body in, one solid out; several in, a compound of solids.
// theSolidsCreated counts only shells actually converted, matching `solidCreated`'s meaning.
static TopoDS_Shape occtSolidifyShells(const TopoDS_Shape& theShape, int& theSolidsCreated)
{
  if (theShape.IsNull())
    return theShape;

  const TopAbs_ShapeEnum type = theShape.ShapeType();
  if (type == TopAbs_SHELL)
  {
    BRepBuilderAPI_MakeSolid makeSolid(TopoDS::Shell(theShape));
    if (makeSolid.IsDone())
    {
      theSolidsCreated++;
      return makeSolid.Solid();
    }
    return theShape;
  }
  if (type == TopAbs_COMPOUND || type == TopAbs_COMPSOLID)
  {
    BRep_Builder    builder;
    TopoDS_Compound out;
    builder.MakeCompound(out);
    int children = 0;
    for (TopoDS_Iterator it(theShape); it.More(); it.Next())
    {
      builder.Add(out, occtSolidifyShells(it.Value(), theSolidsCreated));
      children++;
    }
    if (children == 0)
      return theShape;
    if (children == 1)
    {
      // One body in, a plain solid out -- don't wrap it in a compound. Only unwrap to a
      // SOLID: a lone face or an unsolidifiable shell stays wrapped, as it was before.
      TopoDS_Iterator it(out);
      if (it.Value().ShapeType() == TopAbs_SOLID)
        return it.Value();
    }
    return out;
  }
  return theShape; // SOLID, FACE, anything else: not ours to touch
}

} // namespace

// #794: shared helper for STL Import (base vs Robust)
static OCCTShapeRef occtImportSTLImpl(const char* path, double sewingTolerance, bool robust)
{
  if (!path)
    return nullptr;

  try
  {
    TopoDS_Shape  shape;
    StlAPI_Reader reader;
    if (!reader.Read(shape, path))
      return nullptr;
    if (shape.IsNull())
      return nullptr;

    if (!robust)
    {
      return new OCCTShape(shape);
    }

    // Robust path: sew disconnected faces
    BRepBuilderAPI_Sewing sewing(sewingTolerance);
    sewing.Add(shape);
    sewing.Perform();
    TopoDS_Shape sewedShape = sewing.SewedShape();
    if (sewedShape.IsNull())
      sewedShape = shape;

    // Create a solid from every shell, not just the first (#302)
    TopoDS_Shape resultShape = sewedShape;
    if (sewedShape.ShapeType() != TopAbs_SOLID)
    {
      int solidsCreated = 0;
      resultShape       = occtSolidifyShells(sewedShape, solidsCreated);
    }

    // Apply shape healing
    ShapeFix_Shape fixer(resultShape);
    fixer.Perform();
    TopoDS_Shape fixed = fixer.Shape();
    return new OCCTShape(fixed.IsNull() ? resultShape : fixed);
  }
  catch (...)
  {
    return nullptr;
  }
}

// Shared XDE export pipeline for OBJ/PLY and similar formats.
// Tessellates the shape, creates an XDE document, adds the shape, collects root labels,
// and invokes the provided writer factory to perform the write.
// The writerFactory is a callable taking (const char* path) and returning a writer
// that has a Perform(doc, rootLabels, nullptr, fileInfo, Message_ProgressRange()) method.
// Returns true on success, false on any error.
template <typename WriterFactory>
static bool occtExportCafImpl(OCCTShapeRef    shape,
                              const char*     path,
                              double          deflection,
                              WriterFactory&& writerFactory)
{
  if (!shape || !path)
    return false;
  try
  {
    // Tessellate the shape first
    BRepMesh_IncrementalMesh mesher(shape->shape, deflection);
    mesher.Perform();

    // Create an XDE document
    Handle(TDocStd_Document)    doc;
    Handle(TDocStd_Application) app = new TDocStd_Application();
    Handle(XCAFDoc_ShapeTool)   shapeTool;
    if (!occtDocumentInit(app, doc, &shapeTool, nullptr, nullptr))
      return false;

    shapeTool->AddShape(shape->shape);

    // Collect root labels
    NCollection_Sequence<TDF_Label> rootLabels;
    TDF_LabelSequence               freeShapes;
    shapeTool->GetFreeShapes(freeShapes);
    for (int i = 1; i <= freeShapes.Length(); ++i)
    {
      rootLabels.Append(freeShapes.Value(i));
    }

    // Create and configure writer via factory, then perform write
    auto writer = writerFactory(path);
    NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> fileInfo;
    bool success = writer.Perform(doc, rootLabels, nullptr, fileInfo, Message_ProgressRange());

    app->Close(doc);
    return success;
  }
  catch (...)
  {
    return false;
  }
}

// #794: shared helper for Document Write (OBJ vs PLY with options)
static bool occtDocumentWriteImpl(OCCTDocumentRef doc,
                                  const char*     path,
                                  double          deflection,
                                  bool            isPLY,
                                  bool            normals,
                                  bool            colors,
                                  bool            texCoords)
{
  if (!doc || !path || doc->doc.IsNull() || doc->shapeTool.IsNull())
    return false;
  try
  {
    // Re-mesh if deflection > 0
    if (deflection > 0)
    {
      TDF_LabelSequence freeShapes;
      doc->shapeTool->GetFreeShapes(freeShapes);
      for (int i = 1; i <= freeShapes.Length(); i++)
      {
        TopoDS_Shape shape = doc->shapeTool->GetShape(freeShapes.Value(i));
        if (!shape.IsNull())
        {
          BRepMesh_IncrementalMesh mesher(shape, deflection);
          mesher.Perform();
        }
      }
    }

    if (isPLY)
    {
      RWPly_CafWriter writer(path);
      writer.SetNormals(normals);
      writer.SetColors(colors);
      writer.SetTexCoords(texCoords);
      NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> fileInfo;
      return writer.Perform(doc->doc, fileInfo, Message_ProgressRange());
    }
    else
    {
      RWObj_CafWriter                                                              writer(path);
      NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> fileInfo;
      return writer.Perform(doc->doc, fileInfo, Message_ProgressRange());
    }
  }
  catch (...)
  {
    return false;
  }
}

// #794: shared helper for PLY Export (base vs WithOptions)
// Uses the shared XDE export pipeline (occtExportCafImpl) with a PLY-specific writer factory.
static bool occtExportPLYImpl(OCCTShapeRef shape,
                              const char*  path,
                              double       deflection,
                              bool         normals,
                              bool         colors,
                              bool         texCoords)
{
  return occtExportCafImpl(shape, path, deflection, [normals, colors, texCoords](const char* p) {
    RWPly_CafWriter w(p);
    w.SetNormals(normals);
    w.SetColors(colors);
    w.SetTexCoords(texCoords);
    return w;
  });
}

struct OCCTTimer
{
  OSD_Timer timer;
};

// Every OCCTOSDPath* string accessor differs only in which component it reads back, so they share
// one construction, one strdup and one failure outcome (nullptr). #499 folded the parallel
// TDocStd_PathParser family into this one; OSD_Path is the workhorse the rest of the bridge already
// uses, and it parses the cases TDocStd_PathParser::Parse() got wrong (extension-less paths,
// dotfiles inside a directory, a dot in a directory name).
namespace
{
enum class OSDPathComponent
{
  Name,
  Extension,
  Trek,
  SystemName
};

const char* osdPathComponent(const char* path, OSDPathComponent which)
{
  try
  {
    TCollection_AsciiString apath(path);
    OSD_Path                p(apath);
    TCollection_AsciiString result;
    switch (which)
    {
      case OSDPathComponent::Name:
        result = p.Name();
        break;
      case OSDPathComponent::Extension:
        result = p.Extension();
        break;
      case OSDPathComponent::Trek:
        result = p.Trek();
        break;
      case OSDPathComponent::SystemName:
        p.SystemName(result);
        break;
    }
    return strdup(result.ToCString());
  }
  catch (...)
  {
    return nullptr;
  }
}
} // namespace

struct OCCTOSDFile
{
  OSD_File file;

  OCCTOSDFile() {}

  explicit OCCTOSDFile(const OSD_Path& path)
      : file(path)
  {
  }
};

struct OCCTStepHeader
{
  APIHeaderSection_MakeHeader header;

  OCCTStepHeader(const char* filename)
      : header(0)
  {
    header.Init(filename);
  }
};

struct OCCTResourceManager
{
  Handle(Resource_Manager) mgr;
};

struct OCCTPerfMeter
{
  OSD_PerfMeter meter;
};

struct OCCTSharedLib
{
  OSD_SharedLibrary lib;

  OCCTSharedLib(const char* name)
      : lib(name)
  {
  }
};

bool OCCTExportSTEP(OCCTShapeRef shape, const char* path)
{
  if (!shape || !path)
    return false;

  try
  {
    // Serialize all DE writes: STEP/IGES share Interface_Static globals (#181-B).
    std::lock_guard<std::mutex> deLock(igesMutex());
    // Use a scoped block to ensure all OCCT objects are destroyed before return
    bool success = false;
    {
      STEPControl_Writer writer;
      Interface_Static::SetCVal("write.step.schema", "AP214");

      IFSelect_ReturnStatus status = writer.Transfer(shape->shape, STEPControl_AsIs);
      if (status != IFSelect_RetDone)
      {
        return false;
      }

      status  = writer.Write(path);
      success = (status == IFSelect_RetDone);

      // Writer goes out of scope here and is automatically destroyed
    }
    return success;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTExportSTEPWithName(OCCTShapeRef shape, const char* path, const char* name)
{
  if (!shape || !path)
    return false;

  // Serialize all DE writes: STEP/IGES share Interface_Static globals (#181-B, #359).
  std::lock_guard<std::mutex> deLock(igesMutex());
  try
  {
    // Use a scoped block to ensure all OCCT objects are destroyed before return
    bool success = false;
    {
      STEPControl_Writer writer;
      Interface_Static::SetCVal("write.step.schema", "AP214");
      if (name)
      {
        Interface_Static::SetCVal("write.step.product.name", name);
      }

      IFSelect_ReturnStatus status = writer.Transfer(shape->shape, STEPControl_AsIs);
      if (status != IFSelect_RetDone)
      {
        return false;
      }

      status  = writer.Write(path);
      success = (status == IFSelect_RetDone);

      // Writer goes out of scope here and is automatically destroyed
    }
    return success;
  }
  catch (...)
  {
    return false;
  }
}

OCCTShapeRef OCCTImportSTEPProgress(const char*               path,
                                    const OCCTImportProgress* ctx,
                                    bool*                     outCancelled)
{
  clearCancelOut(outCancelled);
  if (!path)
    return nullptr;
  // Serialize all DE reads: STEP/IGES share Interface_Static globals (#181-B, #359).
  std::lock_guard<std::mutex> igesLock(igesMutex());
  // Declared outside the try so the catch below can still answer "was this cancelled?" (#525).
  opencascade::handle<BridgeProgressIndicator> indicator;
  try
  {
    STEPControl_Reader    reader;
    IFSelect_ReturnStatus status = reader.ReadFile(path);
    if (status != IFSelect_RetDone)
      return nullptr;

    indicator                   = new BridgeProgressIndicator(ctx);
    Message_ProgressRange range = indicator->Start();
    reader.TransferRoots(range);
    if (indicator->UserBreak())
    {
      setCancelOut(outCancelled, indicator);
      return nullptr;
    }

    TopoDS_Shape shape = reader.OneShape();
    if (shape.IsNull())
      return nullptr;
    return new OCCTShape(shape);
  }
  catch (...)
  {
    setCancelOut(outCancelled, indicator);
    return nullptr;
  }
}

OCCTShapeRef OCCTImportSTEPRobustProgress(const char*               path,
                                          const OCCTImportProgress* ctx,
                                          bool*                     outCancelled)
{
  clearCancelOut(outCancelled);
  if (!path)
    return nullptr;
  // Serialize all DE reads: STEP/IGES share Interface_Static globals (#181-B, #359).
  std::lock_guard<std::mutex> igesLock(igesMutex());
  // Declared outside the try so the catch below can still answer "was this cancelled?" (#525).
  opencascade::handle<BridgeProgressIndicator> indicator;
  try
  {
    STEPControl_Reader reader;
    Interface_Static::SetIVal("read.precision.mode", 0);
    Interface_Static::SetRVal("read.maxprecision.val", 0.1);
    Interface_Static::SetIVal("read.surfacecurve.mode", 3);
    Interface_Static::SetIVal("read.step.product.mode", 1);

    IFSelect_ReturnStatus status = reader.ReadFile(path);
    if (status != IFSelect_RetDone)
      return nullptr;

    indicator = new BridgeProgressIndicator(ctx);
    // Split the range: the repair phase below is comparable in cost to the transfer and
    // must stay within the caller's reach. See OCCTImportIGESRobustProgress (#300).
    Message_ProgressScope scope(indicator->Start(), "Import", 2);
    // A break during the transfer leaves zero roots transferred, which is how a cancellation
    // that lands in this phase reaches the caller -- as cancelled, not as a failed import (#525).
    if (reader.TransferRoots(scope.Next()) == 0)
    {
      setCancelOut(outCancelled, indicator);
      return nullptr;
    }
    if (indicator->UserBreak())
    {
      setCancelOut(outCancelled, indicator);
      return nullptr;
    }

    TopoDS_Shape shape = reader.OneShape();
    if (shape.IsNull())
      return nullptr;

    TopAbs_ShapeEnum shapeType = shape.ShapeType();
    if (shapeType == TopAbs_SOLID)
    {
      ShapeFix_Shape fixer(shape);
      fixer.Perform(scope.Next());
      if (indicator->UserBreak())
      {
        setCancelOut(outCancelled, indicator);
        return nullptr;
      }
      TopoDS_Shape fixed = fixer.Shape();
      return new OCCTShape(fixed.IsNull() ? shape : fixed);
    }
    if (shapeType == TopAbs_COMPOUND || shapeType == TopAbs_SHELL || shapeType == TopAbs_FACE)
    {
      // Sewing costs ~1% of what healing does, so it takes a thin slice of the repair
      // half rather than an even one -- an even split would stall the reported fraction
      // at the handover.
      Message_ProgressScope repair(scope.Next(), "Repair", 10);
      BRepBuilderAPI_Sewing sewing(1.0e-4);
      sewing.SetNonManifoldMode(Standard_False);
      sewing.Add(shape);
      sewing.Perform(repair.Next(1));
      if (indicator->UserBreak())
      {
        setCancelOut(outCancelled, indicator);
        return nullptr;
      }
      TopoDS_Shape sewedShape = sewing.SewedShape();
      if (sewedShape.IsNull())
        sewedShape = shape;

      TopoDS_Shape resultShape = sewedShape;
      if (sewedShape.ShapeType() != TopAbs_SOLID)
      {
        int solidsCreated = 0;
        resultShape       = occtSolidifyShells(sewedShape, solidsCreated);
      }
      ShapeFix_Shape fixer(resultShape);
      fixer.Perform(repair.Next(9));
      if (indicator->UserBreak())
      {
        setCancelOut(outCancelled, indicator);
        return nullptr;
      }
      TopoDS_Shape fixed = fixer.Shape();
      return new OCCTShape(fixed.IsNull() ? resultShape : fixed);
    }
    ShapeFix_Shape fixer(shape);
    fixer.Perform(scope.Next());
    if (indicator->UserBreak())
    {
      setCancelOut(outCancelled, indicator);
      return nullptr;
    }
    TopoDS_Shape fixed = fixer.Shape();
    return new OCCTShape(fixed.IsNull() ? shape : fixed);
  }
  catch (...)
  {
    setCancelOut(outCancelled, indicator);
    return nullptr;
  }
}

OCCTShapeRef OCCTImportSTEPWithUnitProgress(const char*               path,
                                            double                    unitInMeters,
                                            const OCCTImportProgress* ctx,
                                            bool*                     outCancelled)
{
  clearCancelOut(outCancelled);
  if (!path)
    return nullptr;
  // Serialize all DE reads: STEP/IGES share Interface_Static globals (#181-B, #359).
  std::lock_guard<std::mutex> igesLock(igesMutex());
  // Declared outside the try so the catch below can still answer "was this cancelled?" (#525).
  opencascade::handle<BridgeProgressIndicator> indicator;
  try
  {
    STEPControl_Reader reader;
    reader.SetSystemLengthUnit(unitInMeters);
    IFSelect_ReturnStatus status = reader.ReadFile(path);
    if (status != IFSelect_RetDone)
      return nullptr;

    indicator                   = new BridgeProgressIndicator(ctx);
    Message_ProgressRange range = indicator->Start();
    reader.TransferRoots(range);
    if (indicator->UserBreak())
    {
      setCancelOut(outCancelled, indicator);
      return nullptr;
    }

    TopoDS_Shape shape = reader.OneShape();
    if (shape.IsNull())
      return nullptr;
    return new OCCTShape(shape);
  }
  catch (...)
  {
    setCancelOut(outCancelled, indicator);
    return nullptr;
  }
}

OCCTDocumentRef OCCTDocumentLoadSTEPProgress(const char*               path,
                                             const OCCTImportProgress* ctx,
                                             bool*                     outCancelled)
{
  clearCancelOut(outCancelled);
  if (!path)
    return nullptr;
  // Serialize all DE reads: STEP/IGES share Interface_Static globals (#181-B, #359).
  std::lock_guard<std::mutex> igesLock(igesMutex());
  OCCTDocument*               document = nullptr;
  // Declared outside the try so the catch below can still answer "was this cancelled?" (#525).
  opencascade::handle<BridgeProgressIndicator> indicator;
  try
  {
    document = new OCCTDocument();

    if (!occtDocumentInit(document))
    {
      delete document;
      return nullptr;
    }

    STEPCAFControl_Reader reader;
    reader.SetColorMode(Standard_True);
    reader.SetNameMode(Standard_True);
    reader.SetLayerMode(Standard_True);
    reader.SetPropsMode(Standard_True);
    reader.SetMatMode(Standard_True);

    IFSelect_ReturnStatus status = reader.ReadFile(path);
    if (status != IFSelect_RetDone)
    {
      delete document;
      return nullptr;
    }

    indicator                   = new BridgeProgressIndicator(ctx);
    Message_ProgressRange range = indicator->Start();
    bool                  ok    = reader.Transfer(document->doc, range);
    if (indicator->UserBreak())
    {
      setCancelOut(outCancelled, indicator);
      delete document;
      return nullptr;
    }
    if (!ok)
    {
      delete document;
      return nullptr;
    }

    // Tools already initialized by occtDocumentInit
    return document;
  }
  catch (...)
  {
    setCancelOut(outCancelled, indicator);
    delete document;
    return nullptr;
  }
}

bool OCCTExportSTEPProgress(OCCTShapeRef              shape,
                            const char*               path,
                            const OCCTImportProgress* ctx,
                            bool*                     outCancelled)
{
  clearCancelOut(outCancelled);
  if (!shape || !path)
    return false;
  // Declared outside the try so the catch below can still answer "was this cancelled?" (#525).
  opencascade::handle<BridgeProgressIndicator> indicator;
  try
  {
    // Serialize all DE writes: STEP/IGES share Interface_Static globals (#181-B).
    std::lock_guard<std::mutex> deLock(igesMutex());
    STEPControl_Writer          writer;
    Interface_Static::SetCVal("write.step.schema", "AP214");
    indicator                    = new BridgeProgressIndicator(ctx);
    Message_ProgressRange range  = indicator->Start();
    IFSelect_ReturnStatus status = writer.Transfer(shape->shape, STEPControl_AsIs, true, range);
    if (indicator->UserBreak())
    {
      setCancelOut(outCancelled, indicator);
      return false;
    }
    if (status != IFSelect_RetDone)
      return false;
    return writer.Write(path) == IFSelect_RetDone;
  }
  catch (...)
  {
    setCancelOut(outCancelled, indicator);
    return false;
  }
}

bool OCCTExportSTEPWithModeProgress(OCCTShapeRef              shape,
                                    const char*               path,
                                    int32_t                   modelType,
                                    const OCCTImportProgress* ctx,
                                    bool*                     outCancelled)
{
  clearCancelOut(outCancelled);
  if (!shape || !path)
    return false;
  // Serialize all DE writes: STEP/IGES share Interface_Static globals (#181-B, #359).
  std::lock_guard<std::mutex> deLock(igesMutex());
  // Declared outside the try so the catch below can still answer "was this cancelled?" (#525).
  opencascade::handle<BridgeProgressIndicator> indicator;
  try
  {
    STEPControl_Writer writer;
    Interface_Static::SetCVal("write.step.schema", "AP214");
    indicator                        = new BridgeProgressIndicator(ctx);
    Message_ProgressRange     range  = indicator->Start();
    STEPControl_StepModelType mode   = static_cast<STEPControl_StepModelType>(modelType);
    IFSelect_ReturnStatus     status = writer.Transfer(shape->shape, mode, true, range);
    if (indicator->UserBreak())
    {
      setCancelOut(outCancelled, indicator);
      return false;
    }
    if (status != IFSelect_RetDone)
      return false;
    return writer.Write(path) == IFSelect_RetDone;
  }
  catch (...)
  {
    setCancelOut(outCancelled, indicator);
    return false;
  }
}

bool OCCTDocumentWriteSTEPProgress(OCCTDocumentRef           doc,
                                   const char*               path,
                                   const OCCTImportProgress* ctx,
                                   bool*                     outCancelled)
{
  clearCancelOut(outCancelled);
  if (!doc || !path)
    return false;
  // Declared outside the try so the catch below can still answer "was this cancelled?" (#525).
  opencascade::handle<BridgeProgressIndicator> indicator;
  try
  {
    // Serialize all DE writes: STEP/IGES share Interface_Static globals (#181-B).
    std::lock_guard<std::mutex> deLock(igesMutex());
    STEPCAFControl_Writer       writer;
    writer.SetColorMode(Standard_True);
    writer.SetNameMode(Standard_True);
    writer.SetLayerMode(Standard_True);
    writer.SetPropsMode(Standard_True);
    writer.SetMaterialMode(Standard_True);
    indicator                   = new BridgeProgressIndicator(ctx);
    Message_ProgressRange range = indicator->Start();
    if (!writer.Transfer(doc->doc, STEPControl_AsIs, nullptr, range))
    {
      if (indicator->UserBreak())
      {
        setCancelOut(outCancelled, indicator);
        return false;
      }
      return false;
    }
    if (indicator->UserBreak())
    {
      setCancelOut(outCancelled, indicator);
      return false;
    }
    IFSelect_ReturnStatus status = writer.Write(path);
    return status == IFSelect_RetDone;
  }
  catch (...)
  {
    setCancelOut(outCancelled, indicator);
    return false;
  }
}

OCCTDocumentRef OCCTDocumentLoadSTEPWithModesProgress(const char*               path,
                                                      bool                      colorMode,
                                                      bool                      nameMode,
                                                      bool                      layerMode,
                                                      bool                      propsMode,
                                                      bool                      gdtMode,
                                                      bool                      matMode,
                                                      const OCCTImportProgress* ctx,
                                                      bool*                     outCancelled)
{
  clearCancelOut(outCancelled);
  if (!path)
    return nullptr;
  // Serialize all DE reads: STEP/IGES share Interface_Static globals (#181-B, #359).
  std::lock_guard<std::mutex> igesLock(igesMutex());
  OCCTDocument*               document = nullptr;
  // Declared outside the try so the catch below can still answer "was this cancelled?" (#525).
  opencascade::handle<BridgeProgressIndicator> indicator;
  try
  {
    document = new OCCTDocument();

    if (!occtDocumentInit(document))
    {
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
    if (status != IFSelect_RetDone)
    {
      delete document;
      return nullptr;
    }

    indicator                   = new BridgeProgressIndicator(ctx);
    Message_ProgressRange range = indicator->Start();
    bool                  ok    = reader.Transfer(document->doc, range);
    if (indicator->UserBreak())
    {
      setCancelOut(outCancelled, indicator);
      delete document;
      return nullptr;
    }
    if (!ok)
    {
      delete document;
      return nullptr;
    }

    // Tools already initialized by occtDocumentInit
    return document;
  }
  catch (...)
  {
    setCancelOut(outCancelled, indicator);
    delete document;
    return nullptr;
  }
}

OCCTShapeRef OCCTImportSTEP(const char* path)
{
  if (!path)
    return nullptr;

  // Serialize all DE reads: STEP/IGES share Interface_Static globals (#181-B, #359).
  std::lock_guard<std::mutex> igesLock(igesMutex());
  try
  {
    STEPControl_Reader    reader;
    IFSelect_ReturnStatus status = reader.ReadFile(path);
    if (status != IFSelect_RetDone)
      return nullptr;

    // Transfer all roots
    reader.TransferRoots();

    // Get the result as a single shape (compound if multiple)
    TopoDS_Shape shape = reader.OneShape();
    if (shape.IsNull())
      return nullptr;

    return new OCCTShape(shape);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTImportSTEPRobust(const char* path)
{
  if (!path)
    return nullptr;

  // Serialize all DE reads: STEP/IGES share Interface_Static globals (#181-B, #359).
  std::lock_guard<std::mutex> igesLock(igesMutex());
  try
  {
    STEPControl_Reader reader;

    // Configure reader for better precision handling
    Interface_Static::SetIVal("read.precision.mode", 0);
    Interface_Static::SetRVal("read.maxprecision.val", 0.1);
    Interface_Static::SetIVal("read.surfacecurve.mode", 3);
    Interface_Static::SetIVal("read.step.product.mode", 1);

    IFSelect_ReturnStatus status = reader.ReadFile(path);
    if (status != IFSelect_RetDone)
      return nullptr;

    if (reader.TransferRoots() == 0)
      return nullptr;

    TopoDS_Shape shape = reader.OneShape();
    if (shape.IsNull())
      return nullptr;

    TopAbs_ShapeEnum shapeType = shape.ShapeType();

    // If already a solid, just apply healing
    if (shapeType == TopAbs_SOLID)
    {
      ShapeFix_Shape fixer(shape);
      fixer.Perform();
      TopoDS_Shape fixed = fixer.Shape();
      return new OCCTShape(fixed.IsNull() ? shape : fixed);
    }

    // Try sewing and solid creation for non-solids
    if (shapeType == TopAbs_COMPOUND || shapeType == TopAbs_SHELL || shapeType == TopAbs_FACE)
    {

      // Sew disconnected faces/shells
      BRepBuilderAPI_Sewing sewing(1.0e-4);
      sewing.SetNonManifoldMode(Standard_False);
      sewing.Add(shape);
      sewing.Perform();
      TopoDS_Shape sewedShape = sewing.SewedShape();
      if (sewedShape.IsNull())
        sewedShape = shape;

      // Create a solid from every shell, not just the first (#302)
      TopoDS_Shape resultShape = sewedShape;
      if (sewedShape.ShapeType() != TopAbs_SOLID)
      {
        int solidsCreated = 0;
        resultShape       = occtSolidifyShells(sewedShape, solidsCreated);
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
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSTEPImportResult OCCTImportSTEPWithDiagnostics(const char* path)
{
  OCCTSTEPImportResult result = {nullptr, -1, -1, false, false, false, 0};
  if (!path)
    return result;

  // Serialize all DE reads: STEP/IGES share Interface_Static globals (#181-B, #359).
  std::lock_guard<std::mutex> igesLock(igesMutex());
  try
  {
    STEPControl_Reader reader;

    // Configure reader
    Interface_Static::SetIVal("read.precision.mode", 0);
    Interface_Static::SetRVal("read.maxprecision.val", 0.1);
    Interface_Static::SetIVal("read.surfacecurve.mode", 3);
    Interface_Static::SetIVal("read.step.product.mode", 1);

    if (reader.ReadFile(path) != IFSelect_RetDone)
      return result;
    if (reader.TransferRoots() == 0)
      return result;

    TopoDS_Shape shape = reader.OneShape();
    if (shape.IsNull())
      return result;

    result.originalType = static_cast<int>(shape.ShapeType());

    // Process non-solids
    if (shape.ShapeType() != TopAbs_SOLID)
    {
      // Try sewing
      BRepBuilderAPI_Sewing sewing(1.0e-4);
      sewing.SetNonManifoldMode(Standard_False);
      sewing.Add(shape);
      sewing.Perform();
      TopoDS_Shape sewedShape = sewing.SewedShape();
      if (!sewedShape.IsNull() && !sewedShape.IsSame(shape))
      {
        shape                = sewedShape;
        result.sewingApplied = true;
      }

      // Create a solid from every shell, not just the first (#302)
      if (shape.ShapeType() != TopAbs_SOLID)
      {
        int          solidsCreated = 0;
        TopoDS_Shape solidified    = occtSolidifyShells(shape, solidsCreated);
        if (solidsCreated > 0)
        {
          shape                = solidified;
          result.solidCreated  = true;
          result.solidsCreated = solidsCreated;
        }
      }
    }

    // Apply shape healing
    ShapeFix_Shape fixer(shape);
    fixer.Perform();
    TopoDS_Shape fixed = fixer.Shape();
    if (!fixed.IsNull())
    {
      shape                 = fixed;
      result.healingApplied = true;
    }

    result.shape      = new OCCTShape(shape);
    result.resultType = static_cast<int>(shape.ShapeType());
    return result;
  }
  catch (...)
  {
    return result;
  }
}

bool OCCTStepTidyOptimize(const char* inputPath, const char* outputPath)
{
  if (!inputPath || !outputPath)
    return false;
  // Serialize all DE reads/writes: STEP/IGES share Interface_Static globals (#181-B, #359).
  std::lock_guard<std::mutex> deLock(igesMutex());
  try
  {
    STEPControl_Reader reader;
    if (reader.ReadFile(inputPath) != IFSelect_RetDone)
      return false;

    // Run tidy on the work session before transferring
    Handle(XSControl_WorkSession) ws = reader.WS();
    StepTidy_DuplicateCleaner     cleaner(ws);
    cleaner.Perform();

    // Now transfer and write
    reader.TransferRoots();

    STEPControl_Writer writer;
    for (int i = 1; i <= reader.NbShapes(); i++)
    {
      writer.Transfer(reader.Shape(i), STEPControl_AsIs);
    }
    return writer.Write(outputPath) == IFSelect_RetDone;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTExportSTEPWithMode(OCCTShapeRef shape, const char* path, int32_t modelType)
{
  if (!shape || !path)
    return false;
  try
  {
    // Serialize all DE writes: STEP/IGES share Interface_Static globals (#181-B).
    std::lock_guard<std::mutex> deLock(igesMutex());
    STEPControl_Writer          writer;
    Interface_Static::SetCVal("write.step.schema", "AP214");
    STEPControl_StepModelType mode   = static_cast<STEPControl_StepModelType>(modelType);
    IFSelect_ReturnStatus     status = writer.Transfer(shape->shape, mode);
    if (status != IFSelect_RetDone)
      return false;
    status = writer.Write(path);
    return status == IFSelect_RetDone;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTExportSTEPWithModeAndTolerance(OCCTShapeRef shape,
                                        const char*  path,
                                        int32_t      modelType,
                                        double       tolerance)
{
  if (!shape || !path)
    return false;
  try
  {
    // Serialize all DE writes: STEP/IGES share Interface_Static globals (#181-B).
    std::lock_guard<std::mutex> deLock(igesMutex());
    STEPControl_Writer          writer;
    Interface_Static::SetCVal("write.step.schema", "AP214");
    writer.SetTolerance(tolerance);
    STEPControl_StepModelType mode   = static_cast<STEPControl_StepModelType>(modelType);
    IFSelect_ReturnStatus     status = writer.Transfer(shape->shape, mode);
    if (status != IFSelect_RetDone)
      return false;
    status = writer.Write(path);
    return status == IFSelect_RetDone;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTExportSTEPCleanDuplicates(OCCTShapeRef shape, const char* path, int32_t modelType)
{
  if (!shape || !path)
    return false;
  try
  {
    // Serialize all DE writes: STEP/IGES share Interface_Static globals (#181-B).
    std::lock_guard<std::mutex> deLock(igesMutex());
    STEPControl_Writer          writer;
    Interface_Static::SetCVal("write.step.schema", "AP214");
    STEPControl_StepModelType mode   = static_cast<STEPControl_StepModelType>(modelType);
    IFSelect_ReturnStatus     status = writer.Transfer(shape->shape, mode);
    if (status != IFSelect_RetDone)
      return false;
    writer.CleanDuplicateEntities();
    status = writer.Write(path);
    return status == IFSelect_RetDone;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTSTEPReaderNbRoots(const char* path)
{
  if (!path)
    return 0;
  // Serialize all DE reads: STEP/IGES share Interface_Static globals (#181-B, #359).
  std::lock_guard<std::mutex> igesLock(igesMutex());
  try
  {
    STEPControl_Reader    reader;
    IFSelect_ReturnStatus status = reader.ReadFile(path);
    if (status != IFSelect_RetDone)
      return 0;
    return reader.NbRootsForTransfer();
  }
  catch (...)
  {
    return 0;
  }
}

OCCTShapeRef OCCTImportSTEPRoot(const char* path, int32_t rootIndex)
{
  if (!path || rootIndex < 1)
    return nullptr;
  // Serialize all DE reads: STEP/IGES share Interface_Static globals (#181-B, #359).
  std::lock_guard<std::mutex> igesLock(igesMutex());
  try
  {
    STEPControl_Reader    reader;
    IFSelect_ReturnStatus status = reader.ReadFile(path);
    if (status != IFSelect_RetDone)
      return nullptr;
    int nbRoots = reader.NbRootsForTransfer();
    if (rootIndex > nbRoots)
      return nullptr;
    if (!reader.TransferRoot(rootIndex))
      return nullptr;
    TopoDS_Shape shape = reader.OneShape();
    if (shape.IsNull())
      return nullptr;
    return new OCCTShape(shape);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTImportSTEPWithUnit(const char* path, double unitInMeters)
{
  if (!path)
    return nullptr;
  // Serialize all DE reads: STEP/IGES share Interface_Static globals (#181-B, #359).
  std::lock_guard<std::mutex> igesLock(igesMutex());
  try
  {
    STEPControl_Reader reader;
    reader.SetSystemLengthUnit(unitInMeters);
    IFSelect_ReturnStatus status = reader.ReadFile(path);
    if (status != IFSelect_RetDone)
      return nullptr;
    reader.TransferRoots();
    TopoDS_Shape shape = reader.OneShape();
    if (shape.IsNull())
      return nullptr;
    return new OCCTShape(shape);
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTSTEPReaderNbShapes(const char* path)
{
  if (!path)
    return 0;
  // Serialize all DE reads: STEP/IGES share Interface_Static globals (#181-B, #359).
  std::lock_guard<std::mutex> igesLock(igesMutex());
  try
  {
    STEPControl_Reader    reader;
    IFSelect_ReturnStatus status = reader.ReadFile(path);
    if (status != IFSelect_RetDone)
      return 0;
    reader.TransferRoots();
    return reader.NbShapes();
  }
  catch (...)
  {
    return 0;
  }
}

OCCTDocumentRef OCCTDocumentLoadSTEPWithModes(const char* path,
                                              bool        colorMode,
                                              bool        nameMode,
                                              bool        layerMode,
                                              bool        propsMode,
                                              bool        gdtMode,
                                              bool        matMode)
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

    STEPCAFControl_Reader reader;
    reader.SetColorMode(colorMode);
    reader.SetNameMode(nameMode);
    reader.SetLayerMode(layerMode);
    reader.SetPropsMode(propsMode);
    reader.SetGDTMode(gdtMode);
    reader.SetMatMode(matMode);

    IFSelect_ReturnStatus status = reader.ReadFile(path);
    if (status != IFSelect_RetDone)
    {
      delete document;
      return nullptr;
    }

    if (!reader.Transfer(document->doc))
    {
      delete document;
      return nullptr;
    }

    // Tools already initialized by occtDocumentInit
    return document;
  }
  catch (...)
  {
    delete document;
    return nullptr;
  }
}

bool OCCTDocumentWriteSTEPWithModes(OCCTDocumentRef doc,
                                    const char*     path,
                                    int32_t         modelType,
                                    bool            colorMode,
                                    bool            nameMode,
                                    bool            layerMode,
                                    bool            dimTolMode,
                                    bool            materialMode)
{
  if (!doc || !path || doc->doc.IsNull())
    return false;

  // Serialize all DE writes: STEP/IGES share Interface_Static globals (#181-B, #359).
  std::lock_guard<std::mutex> deLock(igesMutex());
  try
  {
    STEPCAFControl_Writer writer;
    writer.SetColorMode(colorMode);
    writer.SetNameMode(nameMode);
    writer.SetLayerMode(layerMode);
    writer.SetDimTolMode(dimTolMode);
    writer.SetMaterialMode(materialMode);

    STEPControl_StepModelType mode = static_cast<STEPControl_StepModelType>(modelType);
    if (!writer.Transfer(doc->doc, mode))
      return false;

    IFSelect_ReturnStatus status = writer.Write(path);
    return status == IFSelect_RetDone;
  }
  catch (...)
  {
    return false;
  }
}

OCCTStepHeaderRef OCCTStepHeaderCreate(const char* filename)
{
  if (!filename)
    return nullptr;
  try
  {
    return new OCCTStepHeader(filename);
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTStepHeaderRelease(OCCTStepHeaderRef header)
{
  delete header;
}

bool OCCTStepHeaderIsDone(OCCTStepHeaderRef header)
{
  if (!header)
    return false;
  try
  {
    return header->header.IsDone();
  }
  catch (...)
  {
    return false;
  }
}

char* OCCTStepHeaderGetName(OCCTStepHeaderRef header)
{
  if (!header)
    return nullptr;
  try
  {
    auto name = header->header.Name();
    if (name.IsNull())
      return nullptr;
    return strdup(name->ToCString());
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTStepHeaderSetName(OCCTStepHeaderRef header, const char* name)
{
  if (!header || !name)
    return;
  try
  {
    header->header.SetName(new TCollection_HAsciiString(name));
  }
  catch (...)
  {
  }
}

char* OCCTStepHeaderGetTimeStamp(OCCTStepHeaderRef header)
{
  if (!header)
    return nullptr;
  try
  {
    auto ts = header->header.TimeStamp();
    if (ts.IsNull())
      return nullptr;
    return strdup(ts->ToCString());
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTStepHeaderSetTimeStamp(OCCTStepHeaderRef header, const char* timestamp)
{
  if (!header || !timestamp)
    return;
  try
  {
    header->header.SetTimeStamp(new TCollection_HAsciiString(timestamp));
  }
  catch (...)
  {
  }
}

char* OCCTStepHeaderGetAuthor(OCCTStepHeaderRef header)
{
  if (!header)
    return nullptr;
  try
  {
    if (header->header.NbAuthor() < 1)
      return nullptr;
    auto val = header->header.AuthorValue(1);
    if (val.IsNull())
      return nullptr;
    return strdup(val->ToCString());
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTStepHeaderSetAuthor(OCCTStepHeaderRef header, const char* author)
{
  if (!header || !author)
    return;
  try
  {
    header->header.SetAuthorValue(1, new TCollection_HAsciiString(author));
  }
  catch (...)
  {
  }
}

char* OCCTStepHeaderGetOrganization(OCCTStepHeaderRef header)
{
  if (!header)
    return nullptr;
  try
  {
    if (header->header.NbOrganization() < 1)
      return nullptr;
    auto val = header->header.OrganizationValue(1);
    if (val.IsNull())
      return nullptr;
    return strdup(val->ToCString());
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTStepHeaderSetOrganization(OCCTStepHeaderRef header, const char* org)
{
  if (!header || !org)
    return;
  try
  {
    header->header.SetOrganizationValue(1, new TCollection_HAsciiString(org));
  }
  catch (...)
  {
  }
}

char* OCCTStepHeaderGetPreprocessorVersion(OCCTStepHeaderRef header)
{
  if (!header)
    return nullptr;
  try
  {
    auto val = header->header.PreprocessorVersion();
    if (val.IsNull())
      return nullptr;
    return strdup(val->ToCString());
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTStepHeaderSetPreprocessorVersion(OCCTStepHeaderRef header, const char* ppv)
{
  if (!header || !ppv)
    return;
  try
  {
    header->header.SetPreprocessorVersion(new TCollection_HAsciiString(ppv));
  }
  catch (...)
  {
  }
}

char* OCCTStepHeaderGetOriginatingSystem(OCCTStepHeaderRef header)
{
  if (!header)
    return nullptr;
  try
  {
    auto val = header->header.OriginatingSystem();
    if (val.IsNull())
      return nullptr;
    return strdup(val->ToCString());
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTStepHeaderSetOriginatingSystem(OCCTStepHeaderRef header, const char* os)
{
  if (!header || !os)
    return;
  try
  {
    header->header.SetOriginatingSystem(new TCollection_HAsciiString(os));
  }
  catch (...)
  {
  }
}
