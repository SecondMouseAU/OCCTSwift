//
//  OCCTBridge_IO_NativeFormats.mm
//  OCCTSwift
//
//  Split from OCCTBridge_IO.mm (#396/#1378-follow-on): BinTools, GeomTools persistence, BREP
//  native/string, VrmlAPI. Public C surface unchanged; every sibling file imports the same headers
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

} // namespace

// Shared XDE export pipeline for OBJ/PLY and similar formats.
// Tessellates the shape, creates an XDE document, adds the shape, collects root labels,
// and invokes the provided writer factory to perform the write.
// The writerFactory is a callable taking (const char* path) and returning a writer
// that has a Perform(doc, rootLabels, nullptr, fileInfo, Message_ProgressRange()) method.
// Returns true on success, false on any error.
template <typename WriterFactory>

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
    occtRecordCaughtException(__func__);
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

const char* _Nullable OCCTGeomToolsCurveSetWrite(const OCCTCurve3DRef* curveRefs, int count)
{
  try
  {
    GeomTools_CurveSet cs;
    for (int i = 0; i < count; i++)
    {
      auto* c = (OCCTCurve3D*)curveRefs[i];
      // Same opener as the Curve2dSet/SurfaceSet writers below, for a different reason.
      // GeomTools_CurveSet::Add is the only one of the three that guards its handle
      // (GeomTools_CurveSet.cxx:70, `return (C.IsNull()) ? 0 : myMap.Add(C)`), so a null
      // here does not crash: it is silently dropped, and Write() then emits a set with
      // fewer curves than the caller passed. Curve3D.serializeCurves/deserializeCurves is
      // a round trip, so that is a silent truncation, and the surviving indices no longer
      // match the input array. Refusing the batch is what the siblings already do (#618).
      if (!c || c->curve.IsNull())
        return nullptr;
      // Add() returns the index of the key, new OR existing (NCollection_IndexedMap.hxx),
      // deduplicating by underlying-object identity. cs is fresh above, so the i-th (0-based)
      // insertion of a genuinely new curve always lands at the next sequential 1-based index;
      // anything else means this curve's Handle target was already added earlier in the batch,
      // which would otherwise silently collapse to that earlier entry (#1512). Refuse the whole
      // batch, matching the null-handle refusal immediately above.
      if (cs.Add(c->curve) != i + 1)
        return nullptr;
    }
    std::ostringstream oss;
    cs.Write(oss);
    std::string s      = oss.str();
    char*       result = (char*)malloc(s.size() + 1);
    memcpy(result, s.c_str(), s.size() + 1);
    return result;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

OCCTCurve3DRef* _Nullable OCCTGeomToolsCurveSetRead(const char* data, int* outCount)
{
  *outCount = 0;
  try
  {
    std::istringstream iss(data);
    GeomTools_CurveSet cs;
    cs.Read(iss);
    // Count curves (1-based indexing, index 0 returns null)
    int n = 0;
    for (int i = 1;; i++)
    {
      try
      {
        Handle(Geom_Curve) c = cs.Curve(i);
        if (c.IsNull())
          break;
        n++;
      }
      catch (...)
      {
        // Deliberately NOT calling occtRecordCaughtException here (#1161). GeomTools_*Set is
        // 1-based with no count accessor, so walking off the end is how the loop LEARNS the
        // size: this catch is the normal exit, not a failure, and the read goes on to return
        // every element it found. The function's own outermost catch does record.
        break;
      }
    }
    if (n == 0)
      return nullptr;
    OCCTCurve3DRef* arr = (OCCTCurve3DRef*)malloc(sizeof(OCCTCurve3DRef) * n);
    for (int i = 0; i < n; i++)
    {
      Handle(Geom_Curve) c = cs.Curve(i + 1);
      arr[i]               = (OCCTCurve3DRef) new OCCTCurve3D{c};
    }
    *outCount = n;
    return arr;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

void OCCTGeomToolsCurveSetFreeArray(OCCTCurve3DRef* array, int count)
{
  if (!array)
    return;
  for (int i = 0; i < count; i++)
  {
    if (array[i])
      OCCTCurve3DRelease(array[i]);
  }
  free(array);
}

const char* _Nullable OCCTGeomToolsCurve2dSetWrite(const OCCTCurve2DRef* curveRefs, int count)
{
  try
  {
    GeomTools_Curve2dSet cs;
    for (int i = 0; i < count; i++)
    {
      auto* c = (OCCTCurve2D*)curveRefs[i];
      if (!c || c->curve.IsNull())
        return nullptr;
      // Same dedup refusal as OCCTGeomToolsCurveSetWrite above: Add() returns the index of
      // the key, new OR existing, deduplicating by underlying-object identity. cs is fresh
      // above, so anything but the next sequential 1-based index means this curve's Handle
      // target was already added earlier in the batch (#1512).
      if (cs.Add(c->curve) != i + 1)
        return nullptr;
    }
    std::ostringstream oss;
    cs.Write(oss);
    std::string s      = oss.str();
    char*       result = (char*)malloc(s.size() + 1);
    memcpy(result, s.c_str(), s.size() + 1);
    return result;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

OCCTCurve2DRef* _Nullable OCCTGeomToolsCurve2dSetRead(const char* data, int* outCount)
{
  *outCount = 0;
  try
  {
    std::istringstream   iss(data);
    GeomTools_Curve2dSet cs;
    cs.Read(iss);
    int n = 0;
    for (int i = 1;; i++)
    {
      try
      {
        Handle(Geom2d_Curve) c = cs.Curve2d(i);
        if (c.IsNull())
          break;
        n++;
      }
      catch (...)
      {
        // Deliberately NOT calling occtRecordCaughtException here (#1161). GeomTools_*Set is
        // 1-based with no count accessor, so walking off the end is how the loop LEARNS the
        // size: this catch is the normal exit, not a failure, and the read goes on to return
        // every element it found. The function's own outermost catch does record.
        break;
      }
    }
    if (n == 0)
      return nullptr;
    OCCTCurve2DRef* arr = (OCCTCurve2DRef*)malloc(sizeof(OCCTCurve2DRef) * n);
    for (int i = 0; i < n; i++)
    {
      Handle(Geom2d_Curve) c = cs.Curve2d(i + 1);
      arr[i]                 = (OCCTCurve2DRef) new OCCTCurve2D{c};
    }
    *outCount = n;
    return arr;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

void OCCTGeomToolsCurve2dSetFreeArray(OCCTCurve2DRef* array, int count)
{
  if (!array)
    return;
  for (int i = 0; i < count; i++)
  {
    if (array[i])
      OCCTCurve2DRelease(array[i]);
  }
  free(array);
}

const char* _Nullable OCCTGeomToolsSurfaceSetWrite(const OCCTSurfaceRef* surfRefs, int count)
{
  try
  {
    GeomTools_SurfaceSet ss;
    for (int i = 0; i < count; i++)
    {
      auto* s = (OCCTSurface*)surfRefs[i];
      if (!s || s->surface.IsNull())
        return nullptr;
      // Same dedup refusal as OCCTGeomToolsCurveSetWrite above: Add() returns the index of
      // the key, new OR existing, deduplicating by underlying-object identity. ss is fresh
      // above, so anything but the next sequential 1-based index means this surface's Handle
      // target was already added earlier in the batch (#1512).
      if (ss.Add(s->surface) != i + 1)
        return nullptr;
    }
    std::ostringstream oss;
    ss.Write(oss);
    std::string s      = oss.str();
    char*       result = (char*)malloc(s.size() + 1);
    memcpy(result, s.c_str(), s.size() + 1);
    return result;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

OCCTSurfaceRef* _Nullable OCCTGeomToolsSurfaceSetRead(const char* data, int* outCount)
{
  *outCount = 0;
  try
  {
    std::istringstream   iss(data);
    GeomTools_SurfaceSet ss;
    ss.Read(iss);
    int n = 0;
    for (int i = 1;; i++)
    {
      try
      {
        Handle(Geom_Surface) s = ss.Surface(i);
        if (s.IsNull())
          break;
        n++;
      }
      catch (...)
      {
        // Deliberately NOT calling occtRecordCaughtException here (#1161). GeomTools_*Set is
        // 1-based with no count accessor, so walking off the end is how the loop LEARNS the
        // size: this catch is the normal exit, not a failure, and the read goes on to return
        // every element it found. The function's own outermost catch does record.
        break;
      }
    }
    if (n == 0)
      return nullptr;
    OCCTSurfaceRef* arr = (OCCTSurfaceRef*)malloc(sizeof(OCCTSurfaceRef) * n);
    for (int i = 0; i < n; i++)
    {
      Handle(Geom_Surface) s = ss.Surface(i + 1);
      arr[i]                 = (OCCTSurfaceRef) new OCCTSurface{s};
    }
    *outCount = n;
    return arr;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

void OCCTGeomToolsSurfaceSetFreeArray(OCCTSurfaceRef* array, int count)
{
  if (!array)
    return;
  for (int i = 0; i < count; i++)
  {
    if (array[i])
      OCCTSurfaceRelease(array[i]);
  }
  free(array);
}

void OCCTGeomToolsFreeString(const char* str)
{
  if (str)
    free((void*)str);
}

// MARK: - VrmlAPI Writer (v0.84)
bool OCCTVrmlWriteShape(OCCTShapeRef shape,
                        const char*  filePath,
                        int          version,
                        double       deflection,
                        int          representation)
{
  try
  {
    VrmlAPI_Writer writer;
    writer.SetDeflection(deflection);
    switch (representation)
    {
      case 0:
        writer.SetRepresentation(VrmlAPI_ShadedRepresentation);
        break;
      case 1:
        writer.SetRepresentation(VrmlAPI_WireFrameRepresentation);
        break;
      case 2:
        writer.SetRepresentation(VrmlAPI_BothRepresentation);
        break;
      default:
        writer.SetRepresentation(VrmlAPI_ShadedRepresentation);
        break;
    }
    return writer.Write(shape->shape, filePath, version);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTVrmlWriteDocument(OCCTDocumentRef document, const char* filePath, double scale)
{
  try
  {
    VrmlAPI_Writer writer;
    return writer.WriteDoc(document->doc, filePath, scale);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

const void* OCCTBinToolsWriteShape(OCCTShapeRef shape, int* outLength)
{
  try
  {
    std::ostringstream   oss;
    BinTools_ShapeWriter writer;
    writer.Write(shape->shape, oss);
    std::string data = oss.str();
    *outLength       = (int)data.size();
    void* buf        = malloc(data.size());
    memcpy(buf, data.data(), data.size());
    return buf;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    *outLength = 0;
    return nullptr;
  }
}

OCCTShapeRef OCCTBinToolsReadShape(const void* data, int length)
{
  try
  {
    std::string          str((const char*)data, length);
    std::istringstream   iss(str);
    BinTools_ShapeReader reader;
    TopoDS_Shape         readShape;
    reader.Read(iss, readShape);
    if (readShape.IsNull())
      return nullptr;
    return new OCCTShape(readShape);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

bool OCCTBinToolsWriteShapeToFile(OCCTShapeRef shape, const char* filePath)
{
  try
  {
    std::ofstream fout(filePath, std::ios::binary);
    if (!fout.is_open())
      return false;
    BinTools_ShapeWriter writer;
    writer.Write(shape->shape, fout);
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

OCCTShapeRef OCCTBinToolsReadShapeFromFile(const char* filePath)
{
  try
  {
    std::ifstream fin(filePath, std::ios::binary);
    if (!fin.is_open())
      return nullptr;
    BinTools_ShapeReader reader;
    TopoDS_Shape         readShape;
    reader.Read(fin, readShape);
    if (readShape.IsNull())
      return nullptr;
    return new OCCTShape(readShape);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

char* OCCTShapeToBREPString(OCCTShapeRef shape)
{
  try
  {
    auto*              s = static_cast<OCCTShape*>(shape);
    std::ostringstream oss;
    BRepTools::Write(s->shape, oss);
    std::string str    = oss.str();
    char*       result = (char*)malloc(str.size() + 1);
    if (!result)
      return nullptr;
    memcpy(result, str.c_str(), str.size() + 1);
    return result;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeFromBREPString(const char* brepString)
{
  try
  {
    std::istringstream iss(brepString);
    BRep_Builder       builder;
    TopoDS_Shape       shape;
    BRepTools::Read(shape, iss, builder);
    if (shape.IsNull())
      return nullptr;
    auto* r  = new OCCTShape();
    r->shape = shape;
    return r;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

OCCTShapeRef OCCTImportBREP(const char* path)
{
  if (!path)
    return nullptr;

  try
  {
    TopoDS_Shape shape;
    BRep_Builder builder;

    if (!BRepTools::Read(shape, path, builder))
    {
      return nullptr;
    }

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

bool OCCTExportBREP(OCCTShapeRef shape, const char* path)
{
  if (!shape || !path)
    return false;

  try
  {
    return BRepTools::Write(shape->shape, path);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTExportBREPWithTriangles(OCCTShapeRef shape,
                                 const char*  path,
                                 bool         withTriangles,
                                 bool         withNormals)
{
  if (!shape || !path)
    return false;

  try
  {
    return BRepTools::Write(shape->shape,
                            path,
                            withTriangles,
                            withNormals,
                            TopTools_FormatVersion_CURRENT);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}
