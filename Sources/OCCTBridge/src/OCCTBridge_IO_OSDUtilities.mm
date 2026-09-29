//
//  OCCTBridge_IO_OSDUtilities.mm
//  OCCTSwift
//
//  Split from OCCTBridge_IO.mm (#396/#1378-follow-on):
//  OSD_Timer/MemInfo/Environment/Path/Process/File/Host/PerfMeter/Directory/Disk/SharedLibrary,
//  Resource_Manager, Resource_Unicode. Public C surface unchanged; every sibling file imports the
//  same headers this one does (the shared preamble below). No symbol changes, pure file move -- see
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    // UTF-8-encode every code unit (#1442): 1 byte for [0,0x7F] (already handled below),
    // 2 bytes for [0x80,0x7FF], 3 bytes for [0x800,0xFFFF]. char16_t here is a single OCCT
    // extended-character code unit, never a surrogate half, so no pair-combining is needed.
    std::string result;
    for (int i = 1; i <= eStr.Length(); i++)
    {
      char16_t c = eStr.Value(i);
      if (c < 0x80)
      {
        result += (char)c;
      }
      else if (c < 0x800)
      {
        result += (char)(0xC0 | (c >> 6));
        result += (char)(0x80 | (c & 0x3F));
      }
      else
      {
        result += (char)(0xE0 | (c >> 12));
        result += (char)(0x80 | ((c >> 6) & 0x3F));
        result += (char)(0x80 | (c & 0x3F));
      }
    }
    return strdup(result.c_str());
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
    return 0;
  }
}

// Construct OSD_Disk directly from the path string, not via OSD_Path (#1442). OSD_Disk(const
// OSD_Path&) reads OSD_Path::Disk() (the "drive" component); OSD_Path.cxx's UnixExtract, the
// branch every macOS/iOS/Linux path takes, never assigns myDisk, so that route left myDiskName
// permanently empty on those platforms and every statvfs() call (and hence DiskSize()/
// DiskFree()/Failed()) failed regardless of whether the real path was valid. The const char*
// overload assigns myDiskName from the raw string directly and is unaffected.

int64_t OCCTDiskSize(const char* path)
{
  try
  {
    OSD_Disk disk(path);
    // OSD_Disk::DiskSize() reports 512-byte blocks (OSD_Disk.hxx), this bridge fn is
    // documented in KB; 1 block = 0.5 KB (#1442).
    return (int64_t)disk.DiskSize() / 2;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

int64_t OCCTDiskFree(const char* path)
{
  try
  {
    OSD_Disk disk(path);
    // OSD_Disk::DiskFree() reports 512-byte blocks (OSD_Disk.hxx), this bridge fn is
    // documented in KB; 1 block = 0.5 KB (#1442).
    return (int64_t)disk.DiskFree() / 2;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

bool OCCTDiskIsValid(const char* path)
{
  try
  {
    OSD_Disk disk(path);
    // DiskSize() does not throw on failure (OSD_Disk.cxx): it sets the OSD_Error flag and
    // returns 0. Check Failed(), not the exception (#1442), matching OCCTEnvironmentSet's
    // !env.Failed() pattern elsewhere in this file.
    disk.DiskSize();
    return !disk.Failed();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}
