//
//  OCCTBridge_IO_Diagnostics.mm
//  OCCTSwift
//
//  Split from OCCTBridge_IO.mm (#396/#1378-follow-on): Message_Messenger/Report/Msg, UnitsAPI,
//  UnitsMethods. Public C surface unchanged; every sibling file imports the same headers this one
//  does (the shared preamble below). No symbol changes, pure file move -- see
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
#include <ShapeExtend.hxx>
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

double OCCTUnitsAnyToAny(double value, const char* fromUnit, const char* toUnit)
{
  try
  {
    return UnitsAPI::AnyToAny(value, fromUnit, toUnit);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0.0;
  }
}

double OCCTUnitsAnyToSI(double value, const char* unit)
{
  try
  {
    return UnitsAPI::AnyToSI(value, unit);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0.0;
  }
}

double OCCTUnitsAnyFromSI(double value, const char* unit)
{
  try
  {
    return UnitsAPI::AnyFromSI(value, unit);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0.0;
  }
}

double OCCTUnitsAnyToLS(double value, const char* unit)
{
  try
  {
    return UnitsAPI::AnyToLS(value, unit);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0.0;
  }
}

double OCCTUnitsAnyFromLS(double value, const char* unit)
{
  try
  {
    return UnitsAPI::AnyFromLS(value, unit);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0.0;
  }
}

void OCCTUnitsSetLocalSystem(int system)
{
  try
  {
    UnitsAPI::SetLocalSystem(static_cast<UnitsAPI_SystemUnits>(system));
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

int OCCTUnitsGetLocalSystem()
{
  try
  {
    return static_cast<int>(UnitsAPI::LocalSystem());
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

OCCTMessengerRef OCCTMessengerCreate()
{
  try
  {
    Handle(Message_Messenger) msg = new Message_Messenger();
    if (msg.IsNull())
      return nullptr;
    msg->IncrementRefCounter();
    // #2952: record the reference this bridge just took, so OCCTMessengerRelease can tell a release
    // it owes from one it does not. After IncrementRefCounter, never before; see
    // OCCTBridge_Internal.h.
    occtBorrowRegister(msg.get());
    return msg.get();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

void OCCTMessengerRelease(OCCTMessengerRef messenger)
{
  // #2952: give back a reference this bridge actually took, and nothing else. A null, a second
  // release of the same pointer, or a pointer OCCTMessengerCreate never returned is refused here
  // and counted by OCCTBridgeRefusedReleaseCount. `_Nonnull` on the declaration is a promise the
  // compiler does not enforce, and OCCTBridge is reachable to a consumer (#967), so the null
  // does arrive. Unlike OCCTTObjApplicationRelease (#2897) there is no process-wide static
  // holding a reference to absorb an over-release: the first release already drops the count to
  // zero and deletes, so a second one reads GetRefCount() out of freed memory and may delete it
  // again. This one guard covers both cases because a null is never registered.
  if (!occtBorrowGiveBack(messenger))
    return;

  try
  {
    auto* m = static_cast<Message_Messenger*>(messenger);
    m->DecrementRefCounter();
    if (m->GetRefCount() == 0)
      delete m;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

int OCCTMessengerPrinterCount(OCCTMessengerRef messenger)
{
  try
  {
    auto* m = static_cast<Message_Messenger*>(messenger);
    return static_cast<int>(m->Printers().Size());
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

void OCCTMessengerSend(OCCTMessengerRef messenger, const char* message, int gravity)
{
  try
  {
    auto*           m = static_cast<Message_Messenger*>(messenger);
    Message_Gravity g = static_cast<Message_Gravity>(gravity);
    m->Send(TCollection_AsciiString(message), g);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

bool OCCTMessengerAddFilePrinter(OCCTMessengerRef messenger, const char* filePath, int gravity)
{
  try
  {
    auto*                          m       = static_cast<Message_Messenger*>(messenger);
    Message_Gravity                g       = static_cast<Message_Gravity>(gravity);
    Handle(Message_PrinterOStream) printer = new Message_PrinterOStream(filePath, false, g);
    return m->AddPrinter(printer);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

void OCCTMessengerRemoveAllPrinters(OCCTMessengerRef messenger)
{
  try
  {
    auto* m = static_cast<Message_Messenger*>(messenger);
    // Remove by type: remove all Standard_Transient printers
    Handle(Standard_Type) printerType = STANDARD_TYPE(Message_Printer);
    m->RemovePrinters(printerType);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

OCCTReportRef OCCTReportCreate()
{
  try
  {
    Handle(Message_Report) report = new Message_Report();
    if (report.IsNull())
      return nullptr;
    report->IncrementRefCounter();
    // #2952: record the reference this bridge just took, so OCCTReportRelease can tell a release
    // it owes from one it does not. After IncrementRefCounter, never before; see
    // OCCTBridge_Internal.h.
    occtBorrowRegister(report.get());
    return report.get();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

void OCCTReportRelease(OCCTReportRef report)
{
  // #2952: the OCCTMessengerRelease guard above, for the same reasons. See OCCTBridge_Internal.h.
  if (!occtBorrowGiveBack(report))
    return;

  try
  {
    auto* r = static_cast<Message_Report*>(report);
    r->DecrementRefCounter();
    if (r->GetRefCount() == 0)
      delete r;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

void OCCTReportSetLimit(OCCTReportRef report, int limit)
{
  try
  {
    auto* r = static_cast<Message_Report*>(report);
    r->SetLimit(limit);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

int OCCTReportGetLimit(OCCTReportRef report)
{
  try
  {
    auto* r = static_cast<Message_Report*>(report);
    return r->Limit();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

void OCCTReportClear(OCCTReportRef report)
{
  try
  {
    auto* r = static_cast<Message_Report*>(report);
    r->Clear();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

void OCCTReportClearByGravity(OCCTReportRef report, int gravity)
{
  try
  {
    auto* r = static_cast<Message_Report*>(report);
    r->Clear(static_cast<Message_Gravity>(gravity));
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

const char* OCCTReportDump(OCCTReportRef report)
{
  try
  {
    auto*              r = static_cast<Message_Report*>(report);
    std::ostringstream oss;
    r->Dump(oss);
    std::string str    = oss.str();
    char*       result = (char*)malloc(str.size() + 1);
    strcpy(result, str.c_str());
    return result;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

const char* OCCTReportDumpByGravity(OCCTReportRef report, int gravity)
{
  try
  {
    auto*              r = static_cast<Message_Report*>(report);
    std::ostringstream oss;
    r->Dump(oss, static_cast<Message_Gravity>(gravity));
    std::string str    = oss.str();
    char*       result = (char*)malloc(str.size() + 1);
    strcpy(result, str.c_str());
    return result;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

char* OCCTMessageMsgGet(const char* key)
{
  try
  {
    Message_Msg                msg(key);
    TCollection_ExtendedString str = msg.Get();
    TCollection_AsciiString    astr(str);
    return strdup(astr.ToCString());
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

bool OCCTMessageMsgFileLoad(const char* fileName)
{
  try
  {
    return Message_MsgFile::LoadFile(fileName);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTMessageMsgFileLoadDefault(void)
{
  try
  {
    // "CSF_XHatch" (issue #1422) was a fabricated env var name -- it appears nowhere in OCCT and
    // could never resolve. The only two real upstream "default message set" loaders are
    // ShapeExtend::Init() (CSF_SHMessage/"SHAPE", ShapeExtend.cxx) and
    // Interface_Static::Standards() (CSF_XSMessage/"XSTEP", Interface_StaticStandards.cxx).
    // ShapeExtend::Init() is the one chosen here: it does nothing but load ShapeFix diagnostic
    // messages, matching this function's own documented, narrow contract, where
    // Interface_Static::Standards() would also silently configure ~15 unrelated XSTEP read/write
    // precision/tolerance static parameters as a side effect. Both internally retry
    // Message_MsgFile::LoadFromEnv(<real env var>, <real file name>) first (matching the upstream
    // precedent's shape) and fall back to a message set compiled into the OCCT static library on
    // failure, so this reliably succeeds even though neither env var is ever set anywhere in this
    // project or by any downstream SwiftPM consumer.
    ShapeExtend::Init();
    return Message_MsgFile::HasMsg(TCollection_AsciiString("ShapeFix.FixSmallSolid.MSG0"));
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTMessageMsgHasMsg(const char* key)
{
  try
  {
    return Message_MsgFile::HasMsg(TCollection_AsciiString(key));
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

// MARK: - v0.116: UnitsAPI helpers
double OCCTUnitsGetLengthFactor(int32_t unit)
{
  try
  {
    return UnitsMethods::GetLengthFactorValue(unit);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0.0;
  }
}

double OCCTUnitsGetLengthUnitScale(int32_t fromUnit, int32_t toUnit)
{
  try
  {
    return UnitsMethods::GetLengthUnitScale((UnitsMethods_LengthUnit)fromUnit,
                                            (UnitsMethods_LengthUnit)toUnit);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0.0;
  }
}

const char* _Nullable OCCTUnitsDumpLengthUnit(int32_t unit)
{
  try
  {
    return UnitsMethods::DumpLengthUnit((UnitsMethods_LengthUnit)unit);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}
