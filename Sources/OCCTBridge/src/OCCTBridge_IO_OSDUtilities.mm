//
//  OCCTBridge_IO_OSDUtilities.mm
//  OCCTSwift
//
//  Split from OCCTBridge_IO.mm (#396/#1378-follow-on):
//  OSD_Timer/MemInfo/Environment/Path/Process/File/Host/PerfMeter/Directory/Disk/SharedLibrary,
//  Resource_Manager, Resource_Unicode. Public C surface unchanged; imports the same OCCTBridge_IO.h
//  every sibling file does. No symbol changes, pure file move -- see
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

OCCTTimerRef OCCTTimerCreate()
{
  return new OCCTTimer();
}

void OCCTTimerRelease(OCCTTimerRef timer)
{
  delete timer;
}

void OCCTTimerStart(OCCTTimerRef timer)
{
  timer->timer.Start();
}

void OCCTTimerStop(OCCTTimerRef timer)
{
  timer->timer.Stop();
}

void OCCTTimerReset(OCCTTimerRef timer)
{
  timer->timer.Reset();
}

double OCCTTimerElapsedTime(OCCTTimerRef timer)
{
  return timer->timer.ElapsedTime();
}

double OCCTTimerGetWallClockTime()
{
  return OSD_Timer::GetWallClockTime();
}

int64_t OCCTMemInfoHeapUsage()
{
  try
  {
    OSD_MemInfo info(true);
    return (int64_t)info.Value(OSD_MemInfo::MemHeapUsage);
  }
  catch (...)
  {
    return -1;
  }
}

int64_t OCCTMemInfoWorkingSet()
{
  try
  {
    OSD_MemInfo info(true);
    return (int64_t)info.Value(OSD_MemInfo::MemWorkingSet);
  }
  catch (...)
  {
    return -1;
  }
}

double OCCTMemInfoHeapUsageMiB()
{
  try
  {
    OSD_MemInfo info(true);
    return info.ValuePreciseMiB(OSD_MemInfo::MemHeapUsage);
  }
  catch (...)
  {
    return -1.0;
  }
}

const char* OCCTMemInfoString()
{
  try
  {
    TCollection_AsciiString str = OSD_MemInfo::PrintInfo();
    return strdup(str.ToCString());
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTMemInfoFreeString(const char* str)
{
  if (str)
    free((void*)str);
}

const char* OCCTEnvironmentGet(const char* name)
{
  try
  {
    TCollection_AsciiString aname(name);
    OSD_Environment         env(aname);
    TCollection_AsciiString val = env.Value();
    if (val.Length() == 0)
      return nullptr;
    return strdup(val.ToCString());
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTEnvironmentSet(const char* name, const char* value)
{
  try
  {
    TCollection_AsciiString aname(name);
    TCollection_AsciiString aval(value);
    OSD_Environment         env(aname, aval);
    env.Build();
    return !env.Failed();
  }
  catch (...)
  {
    return false;
  }
}

void OCCTEnvironmentRemove(const char* name)
{
  try
  {
    TCollection_AsciiString aname(name);
    OSD_Environment         env(aname);
    env.Remove();
  }
  catch (...)
  {
  }
}

void OCCTEnvironmentFreeString(const char* str)
{
  if (str)
    free((void*)str);
}

const char* OCCTOSDPathName(const char* path)
{
  return osdPathComponent(path, OSDPathComponent::Name);
}

const char* OCCTOSDPathExtension(const char* path)
{
  return osdPathComponent(path, OSDPathComponent::Extension);
}

const char* OCCTOSDPathTrek(const char* path)
{
  return osdPathComponent(path, OSDPathComponent::Trek);
}

const char* OCCTOSDPathSystemName(const char* path)
{
  return osdPathComponent(path, OSDPathComponent::SystemName);
}

void OCCTOSDPathFolderAndFile(const char* path, const char** outFolder, const char** outFile)
{
  try
  {
    TCollection_AsciiString apath(path);
    TCollection_AsciiString folder, file;
    OSD_Path::FolderAndFileFromPath(apath, folder, file);
    *outFolder = strdup(folder.ToCString());
    *outFile   = strdup(file.ToCString());
  }
  catch (...)
  {
    *outFolder = nullptr;
    *outFile   = nullptr;
  }
}

bool OCCTOSDPathIsValid(const char* path)
{
  try
  {
    TCollection_AsciiString apath(path);
    return OSD_Path::IsValid(apath);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTOSDPathIsUnixPath(const char* path)
{
  return OSD_Path::IsUnixPath(path);
}

bool OCCTOSDPathIsRelative(const char* path)
{
  return OSD_Path::IsRelativePath(path);
}

bool OCCTOSDPathIsAbsolute(const char* path)
{
  return OSD_Path::IsAbsolutePath(path);
}

void OCCTOSDPathFreeString(const char* str)
{
  if (str)
    free((void*)str);
}

void OCCTGetProcessCPU(double* userSeconds, double* systemSeconds)
{
  OSD_Chronometer::GetProcessCPU(*userSeconds, *systemSeconds);
}

void OCCTGetThreadCPU(double* userSeconds, double* systemSeconds)
{
  OSD_Chronometer::GetThreadCPU(*userSeconds, *systemSeconds);
}

int32_t OCCTProcessId()
{
  try
  {
    OSD_Process p;
    return p.ProcessId();
  }
  catch (...)
  {
    return -1;
  }
}

const char* OCCTProcessUserName()
{
  try
  {
    OSD_Process             p;
    TCollection_AsciiString user = p.UserName();
    return strdup(user.ToCString());
  }
  catch (...)
  {
    return nullptr;
  }
}

const char* OCCTProcessExecutablePath()
{
  try
  {
    TCollection_AsciiString path = OSD_Process::ExecutablePath();
    if (path.Length() == 0)
      return nullptr;
    return strdup(path.ToCString());
  }
  catch (...)
  {
    return nullptr;
  }
}

const char* OCCTProcessExecutableFolder()
{
  try
  {
    TCollection_AsciiString path = OSD_Process::ExecutableFolder();
    if (path.Length() == 0)
      return nullptr;
    return strdup(path.ToCString());
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTProcessFreeString(const char* str)
{
  if (str)
    free((void*)str);
}

OCCTOSDFileRef OCCTFileCreate(const char* path)
{
  try
  {
    TCollection_AsciiString apath(path);
    OSD_Path                opath(apath);
    return new OCCTOSDFile(opath);
  }
  catch (...)
  {
    return new OCCTOSDFile();
  }
}

OCCTOSDFileRef OCCTFileCreateTemporary(void)
{
  try
  {
    auto* f = new OCCTOSDFile();
    f->file.BuildTemporary();
    return f;
  }
  catch (...)
  {
    return new OCCTOSDFile();
  }
}

void OCCTFileRelease(OCCTOSDFileRef file)
{
  delete file;
}

bool OCCTFileOpen(OCCTOSDFileRef file)
{
  if (!file)
    return false;
  try
  {
    file->file.Build(OSD_ReadWrite, OSD_Protection());
    return !file->file.Failed();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFileOpenReadOnly(OCCTOSDFileRef file)
{
  if (!file)
    return false;
  try
  {
    file->file.Open(OSD_ReadOnly, OSD_Protection());
    return !file->file.Failed();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFileWrite(OCCTOSDFileRef file, const char* data, int32_t length)
{
  if (!file || !data || length <= 0)
    return false;
  try
  {
    TCollection_AsciiString str(data, length);
    file->file.Write(str, length);
    return !file->file.Failed();
  }
  catch (...)
  {
    return false;
  }
}

char* OCCTFileReadLine(OCCTOSDFileRef file, int32_t bufSize)
{
  if (!file || bufSize <= 0)
    return nullptr;
  try
  {
    TCollection_AsciiString line;
    int                     actualRead = 0;
    file->file.ReadLine(line, bufSize, actualRead);
    if (file->file.Failed() && actualRead == 0)
      return nullptr;
    std::string s      = line.ToCString();
    char*       result = (char*)malloc(s.size() + 1);
    if (!result)
      return nullptr;
    memcpy(result, s.c_str(), s.size() + 1);
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

char* OCCTFileReadAll(OCCTOSDFileRef file, int32_t* outLength)
{
  if (!file || !outLength)
    return nullptr;
  *outLength = 0;
  try
  {
    // Get file size
    size_t sz = file->file.Size();
    if (file->file.Failed() || sz == 0)
      return nullptr;

    // Read entire content line by line
    std::string accumulated;
    accumulated.reserve(sz);
    while (!file->file.IsAtEnd() && !file->file.Failed())
    {
      TCollection_AsciiString line;
      int                     n = 0;
      file->file.ReadLine(line, 65536, n);
      if (n > 0)
      {
        if (!accumulated.empty())
          accumulated += "\n";
        accumulated += line.ToCString();
      }
      else
      {
        break;
      }
    }
    char* result = (char*)malloc(accumulated.size() + 1);
    if (!result)
      return nullptr;
    memcpy(result, accumulated.c_str(), accumulated.size() + 1);
    *outLength = (int32_t)accumulated.size();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTFileClose(OCCTOSDFileRef file)
{
  if (!file)
    return;
  try
  {
    file->file.Close();
  }
  catch (...)
  {
  }
}

bool OCCTFileIsOpen(OCCTOSDFileRef file)
{
  if (!file)
    return false;
  try
  {
    return file->file.IsOpen();
  }
  catch (...)
  {
    return false;
  }
}

int64_t OCCTFileSize(OCCTOSDFileRef file)
{
  if (!file)
    return -1;
  try
  {
    size_t sz = file->file.Size();
    if (file->file.Failed())
      return -1;
    return (int64_t)sz;
  }
  catch (...)
  {
    return -1;
  }
}

void OCCTFileRewind(OCCTOSDFileRef file)
{
  if (!file)
    return;
  try
  {
    file->file.Rewind();
  }
  catch (...)
  {
  }
}

bool OCCTFileIsAtEnd(OCCTOSDFileRef file)
{
  if (!file)
    return true;
  try
  {
    return file->file.IsAtEnd();
  }
  catch (...)
  {
    return true;
  }
}

void OCCTFileFreeString(char* str)
{
  free(str);
}

OCCTResourceManagerRef OCCTResourceManagerCreate(void)
{
  OCCTResourceManager* rm = new OCCTResourceManager();
  rm->mgr                 = new Resource_Manager();
  return rm;
}

void OCCTResourceManagerRelease(OCCTResourceManagerRef mgr)
{
  delete mgr;
}

void OCCTResourceManagerSetString(OCCTResourceManagerRef mgr, const char* key, const char* value)
{
  try
  {
    mgr->mgr->SetResource(key, value);
  }
  catch (...)
  {
  }
}

void OCCTResourceManagerSetInt(OCCTResourceManagerRef mgr, const char* key, int32_t value)
{
  try
  {
    mgr->mgr->SetResource(key, (int)value);
  }
  catch (...)
  {
  }
}

void OCCTResourceManagerSetReal(OCCTResourceManagerRef mgr, const char* key, double value)
{
  try
  {
    mgr->mgr->SetResource(key, value);
  }
  catch (...)
  {
  }
}

bool OCCTResourceManagerFind(OCCTResourceManagerRef mgr, const char* key)
{
  try
  {
    return mgr->mgr->Find(key);
  }
  catch (...)
  {
    return false;
  }
}

char* OCCTResourceManagerGetString(OCCTResourceManagerRef mgr, const char* key)
{
  try
  {
    const char* val = mgr->mgr->Value(key);
    return strdup(val);
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTResourceManagerGetInt(OCCTResourceManagerRef mgr, const char* key)
{
  try
  {
    return (int32_t)mgr->mgr->Integer(key);
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTResourceManagerGetReal(OCCTResourceManagerRef mgr, const char* key)
{
  try
  {
    return mgr->mgr->Real(key);
  }
  catch (...)
  {
    return 0.0;
  }
}

char* OCCTHostName(void)
{
  try
  {
    OSD_Host host;
    return strdup(host.HostName().ToCString());
  }
  catch (...)
  {
    return nullptr;
  }
}

char* OCCTSystemVersion(void)
{
  try
  {
    OSD_Host host;
    return strdup(host.SystemVersion().ToCString());
  }
  catch (...)
  {
    return nullptr;
  }
}

char* OCCTInternetAddress(void)
{
  try
  {
    OSD_Host host;
    return strdup(host.InternetAddress().ToCString());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTPerfMeterRef OCCTPerfMeterCreate(const char* name)
{
  auto                    m = new OCCTPerfMeter();
  TCollection_AsciiString n(name);
  m->meter.Init(n);
  m->meter.Start();
  return m;
}

void OCCTPerfMeterRelease(OCCTPerfMeterRef meter)
{
  delete meter;
}

void OCCTPerfMeterStart(OCCTPerfMeterRef meter)
{
  meter->meter.Start();
}

void OCCTPerfMeterStop(OCCTPerfMeterRef meter)
{
  meter->meter.Stop();
}

double OCCTPerfMeterElapsed(OCCTPerfMeterRef meter)
{
  return meter->meter.Elapsed();
}

bool OCCTDirectoryExists(const char* path)
{
  try
  {
    TCollection_AsciiString aPath(path);
    OSD_Path                osdPath(aPath);
    OSD_Directory           dir(osdPath);
    return dir.Exists();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTDirectoryCreate(const char* path)
{
  try
  {
    TCollection_AsciiString aPath(path);
    OSD_Path                osdPath(aPath);
    OSD_Directory           dir(osdPath);
    OSD_Protection          prot;
    dir.Build(prot);
    return dir.Exists();
  }
  catch (...)
  {
    return false;
  }
}

char* OCCTDirectoryBuildTemporary(void)
{
  try
  {
    OSD_Directory tmpDir = OSD_Directory::BuildTemporary();
    OSD_Path      tmpPath;
    tmpDir.Path(tmpPath);
    TCollection_AsciiString sysName;
    tmpPath.SystemName(sysName);
    return strdup(sysName.ToCString());
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTDirectoryRemove(const char* path)
{
  try
  {
    TCollection_AsciiString aPath(path);
    OSD_Path                osdPath(aPath);
    OSD_Directory           dir(osdPath);
    if (!dir.Exists())
      return false;
    dir.Remove();
    return !dir.Exists();
  }
  catch (...)
  {
    return false;
  }
}

void OCCTUnicodeSetFormat(int32_t format)
{
  try
  {
    Resource_FormatType fmt;
    switch (format)
    {
      case 0:
        fmt = Resource_FormatType_SJIS;
        break;
      case 1:
        fmt = Resource_FormatType_EUC;
        break;
      case 2:
        fmt = Resource_FormatType_GB;
        break;
      case 3:
        fmt = Resource_FormatType_ANSI;
        break;
      default:
        fmt = Resource_FormatType_ANSI;
        break;
    }
    Resource_Unicode::SetFormat(fmt);
  }
  catch (...)
  {
  }
}

int32_t OCCTUnicodeGetFormat(void)
{
  try
  {
    Resource_FormatType fmt = Resource_Unicode::GetFormat();
    switch (fmt)
    {
      case Resource_FormatType_SJIS:
        return 0;
      case Resource_FormatType_EUC:
        return 1;
      case Resource_FormatType_GB:
        return 2;
      case Resource_FormatType_ANSI:
        return 3;
      default:
        return 3;
    }
  }
  catch (...)
  {
    return 3;
  }
}

char* OCCTUnicodeConvertToUnicode(const char* input)
{
  try
  {
    TCollection_AsciiString    aStr(input);
    TCollection_ExtendedString eStr;
    Resource_Unicode::ConvertFormatToUnicode(aStr.ToCString(), eStr);
    // Convert extended string to a simple C string (ASCII portion)
    std::string result;
    for (int i = 1; i <= eStr.Length(); i++)
    {
      char16_t c = eStr.Value(i);
      if (c < 128)
      {
        result += (char)c;
      }
    }
    return strdup(result.c_str());
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTUnicodeConvertFromUnicode(const char* utf8Input,
                                      char* _Nullable output,
                                      int32_t maxSize)
{
  try
  {
    TCollection_ExtendedString eStr(utf8Input, true);

    /* First, get the converted string length by converting with a sufficiently large buffer */
    /* We need to know the length before we can return it. Since
     * Resource_Unicode::ConvertUnicodeToFormat */
    /* requires a buffer, we will do the conversion to a temporary buffer first. */

    /* Estimate: UTF-8 to other encodings typically does not expand by more than 2x */
    std::vector<char>   tempBuf(std::strlen(utf8Input) * 4 + 1);
    Standard_PCharacter tempBufPtr = tempBuf.data();
    bool ok = Resource_Unicode::ConvertUnicodeToFormat(eStr,
                                                       tempBufPtr,
                                                       static_cast<int32_t>(tempBuf.size()));
    if (!ok)
      return -1;

    int32_t resultLen = static_cast<int32_t>(std::strlen(tempBuf.data()));

    /* Handle edge cases for maxSize */
    if (maxSize < 0)
      return -1;

    /* Allow length-only query with output == NULL and maxSize == 0 */
    if (!output && maxSize == 0)
      return resultLen;

    /* Invalid: null buffer with positive maxSize, or non-null buffer with zero/negative maxSize */
    if (!output || maxSize <= 0)
      return -1;

    /* Copy up to maxSize-1 characters, NUL-terminate */
    int32_t copyLen = std::min(resultLen, maxSize - 1);
    memcpy(output, tempBuf.data(), copyLen);
    output[copyLen] = '\0';
    return resultLen;
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTDirectoryIteratorCount(const char* path, const char* mask)
{
  try
  {
    TCollection_AsciiString aPath(path);
    OSD_Path                osdPath(aPath);
    TCollection_AsciiString aMask(mask);
    OSD_DirectoryIterator   it(osdPath, aMask);
    int32_t                 count = 0;
    while (it.More())
    {
      count++;
      it.Next();
      if (count > 10000)
        break;
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

char* OCCTDirectoryIteratorName(const char* path, const char* mask, int32_t index)
{
  try
  {
    TCollection_AsciiString aPath(path);
    OSD_Path                osdPath(aPath);
    TCollection_AsciiString aMask(mask);
    OSD_DirectoryIterator   it(osdPath, aMask);
    int32_t                 i = 0;
    while (it.More())
    {
      if (i == index)
      {
        OSD_Directory dir = it.Values();
        OSD_Path      dirPath;
        dir.Path(dirPath);
        TCollection_AsciiString name;
        dirPath.SystemName(name);
        return strdup(name.ToCString());
      }
      i++;
      it.Next();
      if (i > 10000)
        break;
    }
    return nullptr;
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTDirectoryList(const char* path, const char* mask, char** names, int32_t maxCount)
{
  try
  {
    TCollection_AsciiString aPath(path);
    OSD_Path                osdPath(aPath);
    TCollection_AsciiString aMask(mask);
    OSD_DirectoryIterator   it(osdPath, aMask);
    int32_t                 count = 0;
    while (it.More() && count < maxCount)
    {
      OSD_Directory dir = it.Values();
      OSD_Path      dirPath;
      dir.Path(dirPath);
      TCollection_AsciiString name;
      dirPath.SystemName(name);
      names[count] = strdup(name.ToCString());
      count++;
      it.Next();
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTFileIteratorCount(const char* path, const char* mask)
{
  try
  {
    TCollection_AsciiString aPath(path);
    OSD_Path                osdPath(aPath);
    TCollection_AsciiString aMask(mask);
    OSD_FileIterator        it(osdPath, aMask);
    int32_t                 count = 0;
    while (it.More())
    {
      count++;
      it.Next();
      if (count > 10000)
        break;
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

char* OCCTFileIteratorName(const char* path, const char* mask, int32_t index)
{
  try
  {
    TCollection_AsciiString aPath(path);
    OSD_Path                osdPath(aPath);
    TCollection_AsciiString aMask(mask);
    OSD_FileIterator        it(osdPath, aMask);
    int32_t                 i = 0;
    while (it.More())
    {
      if (i == index)
      {
        OSD_File file = it.Values();
        OSD_Path filePath;
        file.Path(filePath);
        TCollection_AsciiString name;
        filePath.SystemName(name);
        return strdup(name.ToCString());
      }
      i++;
      it.Next();
      if (i > 10000)
        break;
    }
    return nullptr;
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTFileList(const char* path, const char* mask, char** names, int32_t maxCount)
{
  try
  {
    TCollection_AsciiString aPath(path);
    OSD_Path                osdPath(aPath);
    TCollection_AsciiString aMask(mask);
    OSD_FileIterator        it(osdPath, aMask);
    int32_t                 count = 0;
    while (it.More() && count < maxCount)
    {
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
  }
  catch (...)
  {
    return 0;
  }
}

int64_t OCCTDiskSize(const char* path)
{
  try
  {
    TCollection_AsciiString apath(path);
    OSD_Path                opath(apath);
    OSD_Disk                disk(opath);
    return (int64_t)disk.DiskSize();
  }
  catch (...)
  {
    return 0;
  }
}

int64_t OCCTDiskFree(const char* path)
{
  try
  {
    TCollection_AsciiString apath(path);
    OSD_Path                opath(apath);
    OSD_Disk                disk(opath);
    return (int64_t)disk.DiskFree();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTDiskIsValid(const char* path)
{
  try
  {
    TCollection_AsciiString apath(path);
    OSD_Path                opath(apath);
    OSD_Disk                disk(opath);
    // If it doesn't throw, it's valid enough
    disk.DiskSize();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

char* OCCTDiskName(const char* path)
{
  try
  {
    TCollection_AsciiString apath(path);
    OSD_Path                opath(apath);
    OSD_Disk                disk(opath);
    OSD_Path                namePath = disk.Name();
    TCollection_AsciiString nameStr;
    namePath.SystemName(nameStr);
    return strdup(nameStr.ToCString());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSharedLibRef OCCTSharedLibCreate(const char* name)
{
  try
  {
    return new OCCTSharedLib(name);
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTSharedLibRelease(OCCTSharedLibRef lib)
{
  delete lib;
}

bool OCCTSharedLibOpen(OCCTSharedLibRef lib)
{
  if (!lib)
    return false;
  try
  {
    return lib->lib.DlOpen(OSD_RTLD_LAZY);
  }
  catch (...)
  {
    return false;
  }
}

void OCCTSharedLibClose(OCCTSharedLibRef lib)
{
  if (!lib)
    return;
  try
  {
    lib->lib.DlClose();
  }
  catch (...)
  {
  }
}

char* OCCTSharedLibName(OCCTSharedLibRef lib)
{
  if (!lib)
    return nullptr;
  try
  {
    const char* name = lib->lib.Name();
    return name ? strdup(name) : nullptr;
  }
  catch (...)
  {
    return nullptr;
  }
}
