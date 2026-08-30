//
//  OCCTBridge_IO_MeshFormats.mm
//  OCCTSwift
//
//  Split from OCCTBridge_IO.mm (#396/#1378-follow-on): StlAPI, RWObj, RWPly, RWGltf, RWMesh,
//  BRepMesh, IMeshTools. Public C surface unchanged; every sibling file imports the same headers
//  this one does (the shared preamble below). No symbol changes, pure file move -- see
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

bool OCCTExportSTL(OCCTShapeRef shape, const char* path, double deflection)
{
  if (!shape || !path)
    return false;

  try
  {
    // The ctor meshes; a following Perform() would only re-check the triangulation it
    // just built (measured at 0.0003s against a 1.29s mesh -- redundant, not costly).
    BRepMesh_IncrementalMesh mesher(shape->shape, deflection);

    StlAPI_Writer writer;
    writer.ASCIIMode() = Standard_False; // Binary STL for smaller files
    return writer.Write(shape->shape, path);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTExportSTLWithMode(OCCTShapeRef shape, const char* path, double deflection, bool ascii)
{
  if (!shape || !path)
    return false;

  try
  {
    // Ctor meshes; the following Perform() was redundant (see OCCTExportSTL).
    BRepMesh_IncrementalMesh mesher(shape->shape, deflection);

    StlAPI_Writer writer;
    writer.ASCIIMode() = ascii ? Standard_True : Standard_False;
    return writer.Write(shape->shape, path);
  }
  catch (...)
  {
    return false;
  }
}

OCCTShapeRef OCCTShapeIncrementalMeshProgress(OCCTShapeRef              shape,
                                              double                    linearDeflection,
                                              double                    angularDeflection,
                                              const OCCTImportProgress* ctx,
                                              bool*                     outCancelled)
{
  clearCancelOut(outCancelled);
  if (!shape)
    return nullptr;
  // Declared outside the try so the catch below can still answer "was this cancelled?" (#525).
  opencascade::handle<BridgeProgressIndicator> indicator;
  try
  {
    indicator = new BridgeProgressIndicator(ctx);
    // The (shape, linDefl, isRelative, angDefl) ctor calls Perform() internally with a null
    // range, so it meshes uninterruptibly before any range we pass afterwards is ever polled
    // (and a following Perform(range) then meshes a second time). Only the parameters ctor
    // consumes a range. Leaving AngleInterior/MinSize/DeflectionInterior at their defaults
    // matches what the other ctor did; Perform() resolves them identically (#286).
    IMeshTools_Parameters params;
    params.Deflection = linearDeflection;
    params.Angle      = angularDeflection;
    params.Relative   = Standard_False;
    params.InParallel = Standard_False;
    BRepMesh_IncrementalMesh mesher(shape->shape, params, indicator->Start());
    if (indicator->UserBreak())
    {
      setCancelOut(outCancelled, indicator);
      return nullptr;
    }
    // Return a new OCCTShape wrapping the same (now-meshed) TopoDS_Shape so callers
    // can chain. The original handle is also valid.
    return new OCCTShape(shape->shape);
  }
  catch (...)
  {
    setCancelOut(outCancelled, indicator);
    return nullptr;
  }
}

OCCTShapeRef OCCTImportSTL(const char* path)
{
  return occtImportSTLImpl(path, 0, false);
}

OCCTShapeRef OCCTImportSTLRobust(const char* path, double sewingTolerance)
{
  return occtImportSTLImpl(path, sewingTolerance, true);
}

OCCTShapeRef OCCTImportOBJ(const char* path)
{
  if (!path)
    return nullptr;

  try
  {
    // Use RWObj_CafReader for OBJ import
    RWObj_CafReader objReader;

    // Create an XDE document
    Handle(TDocStd_Document)    doc;
    Handle(TDocStd_Application) app = new TDocStd_Application();
    Handle(XCAFDoc_ShapeTool)   shapeTool;
    if (!occtDocumentInit(app, doc, &shapeTool, nullptr, nullptr))
      return nullptr;

    objReader.SetDocument(doc);
    TCollection_AsciiString filePath(path);
    if (!objReader.Perform(filePath, Message_ProgressRange()))
      return nullptr;

    // Extract shape from document
    TopoDS_Shape shape = shapeTool->GetOneShape();
    if (shape.IsNull())
      return nullptr;

    // Close document
    app->Close(doc);

    return new OCCTShape(shape);
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTExportOBJ(OCCTShapeRef shape, const char* path, double deflection)
{
  return occtExportCafImpl(shape, path, deflection, [](const char* p) {
    return RWObj_CafWriter(p);
  });
}

OCCTDocumentRef OCCTDocumentLoadOBJ(const char* path)
{
  if (!path)
    return nullptr;
  try
  {
    OCCTDocument* document = new OCCTDocument();

    if (!occtDocumentInit(document))
    {
      delete document;
      return nullptr;
    }

    RWObj_CafReader objReader;
    objReader.SetDocument(document->doc);
    TCollection_AsciiString filePath(path);
    if (!objReader.Perform(filePath, Message_ProgressRange()))
    {
      delete document;
      return nullptr;
    }

    // Tools already initialized by occtDocumentInit
    return document;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTDocumentRef OCCTDocumentLoadOBJWithOptions(const char* path,
                                               bool        singlePrecision,
                                               double      systemLengthUnit)
{
  if (!path)
    return nullptr;
  try
  {
    OCCTDocument* document = new OCCTDocument();

    if (!occtDocumentInit(document))
    {
      delete document;
      return nullptr;
    }

    RWObj_CafReader objReader;
    objReader.SetDocument(document->doc);
    objReader.SetSinglePrecision(singlePrecision);
    if (systemLengthUnit > 0)
    {
      objReader.SetSystemLengthUnit(systemLengthUnit);
    }

    TCollection_AsciiString filePath(path);
    if (!objReader.Perform(filePath, Message_ProgressRange()))
    {
      delete document;
      return nullptr;
    }

    // Tools already initialized by occtDocumentInit
    return document;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTDocumentWriteOBJ(OCCTDocumentRef doc, const char* path, double deflection)
{
  return occtDocumentWriteImpl(doc, path, deflection, false, false, false, false);
}

bool OCCTDocumentWritePLY(OCCTDocumentRef doc,
                          const char*     path,
                          double          deflection,
                          bool            normals,
                          bool            colors,
                          bool            texCoords)
{
  return occtDocumentWriteImpl(doc, path, deflection, true, normals, colors, texCoords);
}

bool OCCTExportPLY(OCCTShapeRef shape, const char* path, double deflection)
{
  return occtExportPLYImpl(shape, path, deflection, true, false, false);
}

bool OCCTExportPLYWithOptions(OCCTShapeRef shape,
                              const char*  path,
                              double       deflection,
                              bool         normals,
                              bool         colors,
                              bool         texCoords)
{
  return occtExportPLYImpl(shape, path, deflection, normals, colors, texCoords);
}

OCCTDocumentRef OCCTDocumentLoadOBJWithCS(const char* path,
                                          int32_t     inputCS,
                                          int32_t     outputCS,
                                          double      inputLengthUnit,
                                          double      outputLengthUnit)
{
  if (!path)
    return nullptr;
  try
  {
    OCCTDocument* document = new OCCTDocument();

    if (!occtDocumentInit(document))
    {
      delete document;
      return nullptr;
    }

    RWObj_CafReader objReader;
    objReader.SetDocument(document->doc);

    if (inputLengthUnit > 0)
      objReader.SetFileLengthUnit(inputLengthUnit);
    if (outputLengthUnit > 0)
      objReader.SetSystemLengthUnit(outputLengthUnit);

    if (inputCS >= 0)
    {
      objReader.SetFileCoordinateSystem(static_cast<RWMesh_CoordinateSystem>(inputCS));
    }
    if (outputCS >= 0)
    {
      objReader.SetSystemCoordinateSystem(static_cast<RWMesh_CoordinateSystem>(outputCS));
    }

    TCollection_AsciiString filePath(path);
    if (!objReader.Perform(filePath, Message_ProgressRange()))
    {
      delete document;
      return nullptr;
    }

    // Tools already initialized by occtDocumentInit
    return document;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef _Nullable OCCTImportGLTF(const char* _Nonnull path)
{
  if (!path)
    return nullptr;
  try
  {
    RWGltf_CafReader            reader;
    Handle(TDocStd_Document)    doc;
    Handle(TDocStd_Application) app = new TDocStd_Application();
    Handle(XCAFDoc_ShapeTool)   shapeTool;
    if (!occtDocumentInit(app, doc, &shapeTool, nullptr, nullptr))
      return nullptr;
    reader.SetDocument(doc);
    TCollection_AsciiString filePath(path);
    if (!reader.Perform(filePath, Message_ProgressRange()))
      return nullptr;
    TopoDS_Shape shape = shapeTool->GetOneShape();
    if (shape.IsNull())
      return nullptr;
    auto* ref  = new OCCTShape;
    ref->shape = shape;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTExportGLTF(OCCTShapeRef _Nonnull shape,
                    const char* _Nonnull path,
                    bool   isBinary,
                    double deflection)
{
  if (!shape || !path)
    return false;
  try
  {
    BRepMesh_IncrementalMesh    mesher(shape->shape, deflection);
    Handle(TDocStd_Document)    doc;
    Handle(TDocStd_Application) app = new TDocStd_Application();
    Handle(XCAFDoc_ShapeTool)   shapeTool;
    if (!occtDocumentInit(app, doc, &shapeTool, nullptr, nullptr))
      return false;
    shapeTool->AddShape(shape->shape);
    TCollection_AsciiString filePath(path);
    RWGltf_CafWriter        writer(filePath, isBinary);
    NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> fileInfo;
    return writer.Perform(doc, fileInfo, Message_ProgressRange());
  }
  catch (...)
  {
    return false;
  }
}

OCCTDocumentRef _Nullable OCCTDocumentLoadGLTF(const char* _Nonnull path)
{
  if (!path)
    return nullptr;
  try
  {
    auto* docRef = new OCCTDocument;

    if (!occtDocumentInit(docRef))
    {
      delete docRef;
      return nullptr;
    }

    RWGltf_CafReader reader;
    reader.SetDocument(docRef->doc);
    TCollection_AsciiString filePath(path);
    if (!reader.Perform(filePath, Message_ProgressRange()))
    {
      delete docRef;
      return nullptr;
    }
    return docRef;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTDocumentWriteGLTF(OCCTDocumentRef _Nonnull doc, const char* _Nonnull path, bool isBinary)
{
  if (!doc || !path)
    return false;
  try
  {
    TCollection_AsciiString filePath(path);
    RWGltf_CafWriter        writer(filePath, isBinary);
    NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> fileInfo;
    return writer.Perform(doc->doc, fileInfo, Message_ProgressRange());
  }
  catch (...)
  {
    return false;
  }
}
