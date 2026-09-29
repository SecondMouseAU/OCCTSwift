//
//  OCCTBridge_IO_IgesFormat.mm
//  OCCTSwift
//
//  Split from OCCTBridge_IO.mm (#396/#1378-follow-on): IGESControl.
//  Public C surface unchanged; every sibling file imports the same headers this one does
//  (the shared preamble below). No symbol changes, pure file move -- see
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

OCCTShapeRef OCCTImportIGESProgress(const char*               path,
                                    const OCCTImportProgress* ctx,
                                    bool*                     outCancelled,
                                    OCCTReturnStatus* _Nullable outStatus)
{
  occtSetReturnStatus(outStatus, OCCTReturnStatusNotReached);
  clearCancelOut(outCancelled);
  if (!path)
    return nullptr;
  std::lock_guard<std::mutex> igesLock(igesMutex());
  // Declared outside the try so the catch below can still answer "was this cancelled?" (#525).
  opencascade::handle<BridgeProgressIndicator> indicator;
  try
  {
    IGESControl_Reader reader;
    if (!occtRecordReturnStatus(reader.ReadFile(path), outStatus))
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
    occtRecordCaughtException(__func__);
    setCancelOut(outCancelled, indicator);
    return nullptr;
  }
}

OCCTShapeRef OCCTImportIGESRobustProgress(const char*               path,
                                          const OCCTImportProgress* ctx,
                                          bool*                     outCancelled,
                                          OCCTReturnStatus* _Nullable outStatus)
{
  occtSetReturnStatus(outStatus, OCCTReturnStatusNotReached);
  clearCancelOut(outCancelled);
  if (!path)
    return nullptr;
  std::lock_guard<std::mutex> igesLock(igesMutex());
  // Declared outside the try so the catch below can still answer "was this cancelled?" (#525).
  opencascade::handle<BridgeProgressIndicator> indicator;
  try
  {
    IGESControl_Reader reader;
    // read.precision.mode stays File (0): SetRVal("read.precision.val", ...) only takes effect
    // under mode 1 ('User'), so setting both here was dead code (#1504). Matching the STEP
    // robust importers' own shape instead: trust the file's own declared resolution as the
    // basis tolerance, but tighten the ceiling ShapeFix is allowed to widen it to afterward,
    // from the default 1.0 down to 0.1, via the max-precision pair rather than forcing a fixed
    // basis value a coarser file's own geometry may not support.
    Interface_Static::SetIVal("read.precision.mode", 0);
    Interface_Static::SetRVal("read.maxprecision.val", 0.1);

    if (!occtRecordReturnStatus(reader.ReadFile(path), outStatus))
      return nullptr;

    indicator = new BridgeProgressIndicator(ctx);
    // Healing is half the work of a robust import, not a coda to it: measured at 38-50%
    // of transfer+heal across box/sphere/cylinder/torus compounds. Giving TransferRoots
    // the whole range therefore left ~40% of the import running where the caller's
    // range could never reach it, so shouldCancel() during healing was ignored and a
    // deadline could not bound the call (#300, same family as #286). Split it evenly.
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

    ShapeFix_Shape fixer(shape);
    fixer.Perform(scope.Next());
    // Perform() honours the break by returning early, which leaves a partially-healed
    // shape behind; report cancellation rather than handing that back as a result.
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
    occtRecordCaughtException(__func__);
    setCancelOut(outCancelled, indicator);
    return nullptr;
  }
}

bool OCCTExportIGESProgress(OCCTShapeRef              shape,
                            const char*               path,
                            const OCCTImportProgress* ctx,
                            bool*                     outCancelled)
{
  clearCancelOut(outCancelled);
  if (!shape || !path || shape->shape.IsNull())
    return false;
  std::lock_guard<std::mutex> igesLock(igesMutex());
  // Declared outside the try so the catch below can still answer "was this cancelled?" (#525).
  opencascade::handle<BridgeProgressIndicator> indicator;
  try
  {
    // #2750: BRepCheck_Analyzer faults on a face edge with no valid 3D curve and a pcurve (#2746),
    // and this export already refuses an invalid shape. Such an edge IS invalid, by OCCT's own
    // BRepCheck_No3DCurve, so the guard reaches the same refusal one step earlier.
    if (occtShapeHasPCurveOnlyEdge(shape->shape))
      return false;
    // #2777: a face with no surface faults on the way out, whatever edges it carries. The writer
    // reaches three untested dereferences of that handle and the BRepCheck_Analyzer below is one of
    // them, so the guard sits ahead of it. The shape is invalid either way, which is the refusal
    // this function already gives an analyzer-invalid one. See occtShapeHasSurfacelessFace.
    if (occtShapeHasSurfacelessFace(shape->shape))
      return false;
    BRepCheck_Analyzer analyzer(shape->shape);
    if (!analyzer.IsValid())
      return false;

    IGESControl_Writer writer("MM", 0);
    indicator                   = new BridgeProgressIndicator(ctx);
    Message_ProgressRange range = indicator->Start();
    // AddShape reports failure for a transfer the break aborted, so ask before believing it (#525).
    if (!writer.AddShape(shape->shape, range))
    {
      setCancelOut(outCancelled, indicator);
      return false;
    }
    if (indicator->UserBreak())
    {
      setCancelOut(outCancelled, indicator);
      return false;
    }
    writer.ComputeModel();
    return writer.Write(path);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    setCancelOut(outCancelled, indicator);
    return false;
  }
}

int32_t OCCTIGESReaderNbRoots(const char* path, OCCTReturnStatus* _Nullable outStatus)
{
  occtSetReturnStatus(outStatus, OCCTReturnStatusNotReached);
  if (!path)
    return 0;
  std::lock_guard<std::mutex> igesLock(igesMutex());
  try
  {
    IGESControl_Reader reader;
    if (!occtRecordReturnStatus(reader.ReadFile(path), outStatus))
      return 0;
    return reader.NbRootsForTransfer();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

OCCTShapeRef OCCTImportIGESRoot(const char* path,
                                int32_t     rootIndex,
                                OCCTReturnStatus* _Nullable outStatus)
{
  occtSetReturnStatus(outStatus, OCCTReturnStatusNotReached);
  if (!path || rootIndex < 1)
    return nullptr;
  std::lock_guard<std::mutex> igesLock(igesMutex());
  try
  {
    IGESControl_Reader reader;
    if (!occtRecordReturnStatus(reader.ReadFile(path), outStatus))
      return nullptr;
    int nbRoots = reader.NbRootsForTransfer();
    if (rootIndex > nbRoots)
      return nullptr;
    if (!reader.TransferOneRoot(rootIndex))
      return nullptr;
    TopoDS_Shape shape = reader.OneShape();
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

int32_t OCCTIGESReaderNbShapes(const char* path, OCCTReturnStatus* _Nullable outStatus)
{
  occtSetReturnStatus(outStatus, OCCTReturnStatusNotReached);
  if (!path)
    return 0;
  std::lock_guard<std::mutex> igesLock(igesMutex());
  try
  {
    IGESControl_Reader reader;
    if (!occtRecordReturnStatus(reader.ReadFile(path), outStatus))
      return 0;
    reader.TransferRoots();
    return reader.NbShapes();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

OCCTShapeRef OCCTImportIGESVisible(const char* path, OCCTReturnStatus* _Nullable outStatus)
{
  occtSetReturnStatus(outStatus, OCCTReturnStatusNotReached);
  if (!path)
    return nullptr;
  std::lock_guard<std::mutex> igesLock(igesMutex());
  try
  {
    IGESControl_Reader reader;
    reader.SetReadVisible(true);
    if (!occtRecordReturnStatus(reader.ReadFile(path), outStatus))
      return nullptr;
    reader.TransferRoots();
    TopoDS_Shape shape = reader.OneShape();
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

bool OCCTExportIGESWithUnit(OCCTShapeRef shape, const char* path, const char* unit)
{
  if (!shape || !path || !unit)
    return false;
  if (shape->shape.IsNull())
    return false;
  std::lock_guard<std::mutex> igesLock(igesMutex());
  try
  {
    // #2750: BRepCheck_Analyzer faults on a face edge with no valid 3D curve and a pcurve (#2746),
    // and this export already refuses an invalid shape. Such an edge IS invalid, by OCCT's own
    // BRepCheck_No3DCurve, so the guard reaches the same refusal one step earlier.
    if (occtShapeHasPCurveOnlyEdge(shape->shape))
      return false;
    // #2777: a face with no surface faults on the way out, whatever edges it carries. The writer
    // reaches three untested dereferences of that handle and the BRepCheck_Analyzer below is one of
    // them, so the guard sits ahead of it. The shape is invalid either way, which is the refusal
    // this function already gives an analyzer-invalid one. See occtShapeHasSurfacelessFace.
    if (occtShapeHasSurfacelessFace(shape->shape))
      return false;
    BRepCheck_Analyzer analyzer(shape->shape);
    if (!analyzer.IsValid())
      return false;
    IGESControl_Writer writer(unit, 0); // 0 = Faces mode
    if (!writer.AddShape(shape->shape))
      return false;
    writer.ComputeModel();
    return writer.Write(path);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTExportIGESBRepMode(OCCTShapeRef shape, const char* path)
{
  if (!shape || !path)
    return false;
  if (shape->shape.IsNull())
    return false;
  std::lock_guard<std::mutex> igesLock(igesMutex());
  try
  {
    // #2750: BRepCheck_Analyzer faults on a face edge with no valid 3D curve and a pcurve (#2746),
    // and this export already refuses an invalid shape. Such an edge IS invalid, by OCCT's own
    // BRepCheck_No3DCurve, so the guard reaches the same refusal one step earlier.
    if (occtShapeHasPCurveOnlyEdge(shape->shape))
      return false;
    // #2777: a face with no surface faults on the way out, whatever edges it carries. The writer
    // reaches three untested dereferences of that handle and the BRepCheck_Analyzer below is one of
    // them, so the guard sits ahead of it. The shape is invalid either way, which is the refusal
    // this function already gives an analyzer-invalid one. See occtShapeHasSurfacelessFace.
    if (occtShapeHasSurfacelessFace(shape->shape))
      return false;
    BRepCheck_Analyzer analyzer(shape->shape);
    if (!analyzer.IsValid())
      return false;
    IGESControl_Writer writer("MM", 1); // 1 = BRep mode
    if (!writer.AddShape(shape->shape))
      return false;
    writer.ComputeModel();
    return writer.Write(path);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTExportIGESMultiShape(const OCCTShapeRef* shapes, int32_t count, const char* path)
{
  if (!shapes || count <= 0 || !path)
    return false;
  std::lock_guard<std::mutex> igesLock(igesMutex());
  try
  {
    IGESControl_Writer writer;
    int                added = 0;
    for (int32_t i = 0; i < count; i++)
    {
      if (!shapes[i] || shapes[i]->shape.IsNull())
        continue;
      // Validate each shape before adding to IGES writer.
      // #2750: this one shape faults inside the analyzer (#2746) and is invalid by OCCT's own
      // BRepCheck_No3DCurve, so it is skipped exactly as an analyzer-invalid shape already is.
      if (occtShapeHasPCurveOnlyEdge(shapes[i]->shape))
        continue;
      // #2777: a face with no surface faults on the way out, whatever edges it carries, and the
      // analyzer below is one of the three sites that dereference the handle. Skipped exactly as an
      // analyzer-invalid shape already is. See occtShapeHasSurfacelessFace.
      if (occtShapeHasSurfacelessFace(shapes[i]->shape))
        continue;
      BRepCheck_Analyzer analyzer(shapes[i]->shape);
      if (!analyzer.IsValid())
        continue;
      // AddShape can still reject a BRepCheck_Analyzer-valid shape, e.g. a degenerate edge
      // with no 3D curve translates to a null IGES entity (#1504); refuse the whole export
      // rather than silently write a file missing geometry the caller asked for, matching
      // the fail-fast contract #1226 already established for this entry point.
      if (!writer.AddShape(shapes[i]->shape))
        return false;
      added++;
    }
    if (added == 0)
      return false;
    writer.ComputeModel();
    return writer.Write(path);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

// MARK: - IGES Import/Export (v0.10.0)
// IGES reader/writer uses C-level global state (iges_newparam, iges_param, etc.)
// that is NOT thread-safe. All IGES operations MUST be serialized.
// See: https://github.com/Open-Cascade-SAS/OCCT/issues/1179
// Non-static (declared in OCCTBridge_Internal.h) so per-area TUs share the
// same underlying mutex via the linker.
std::mutex& igesMutex()
{
  static std::mutex mutex;
  return mutex;
}

OCCTShapeRef OCCTImportIGES(const char* path, OCCTReturnStatus* _Nullable outStatus)
{
  occtSetReturnStatus(outStatus, OCCTReturnStatusNotReached);
  if (!path)
    return nullptr;

  std::lock_guard<std::mutex> igesLock(igesMutex());
  try
  {
    IGESControl_Reader reader;
    if (!occtRecordReturnStatus(reader.ReadFile(path), outStatus))
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
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

OCCTShapeRef OCCTImportIGESRobust(const char* path, OCCTReturnStatus* _Nullable outStatus)
{
  occtSetReturnStatus(outStatus, OCCTReturnStatusNotReached);
  if (!path)
    return nullptr;

  std::lock_guard<std::mutex> igesLock(igesMutex());
  try
  {
    IGESControl_Reader reader;

    // read.precision.mode stays File (0): SetRVal("read.precision.val", ...) only takes effect
    // under mode 1 ('User'), so setting both here was dead code (#1504). Matching the STEP
    // robust importers' own shape instead: trust the file's own declared resolution as the
    // basis tolerance, but tighten the ceiling ShapeFix is allowed to widen it to afterward,
    // from the default 1.0 down to 0.1, via the max-precision pair rather than forcing a fixed
    // basis value a coarser file's own geometry may not support.
    Interface_Static::SetIVal("read.precision.mode", 0);
    Interface_Static::SetRVal("read.maxprecision.val", 0.1);

    if (!occtRecordReturnStatus(reader.ReadFile(path), outStatus))
      return nullptr;

    if (reader.TransferRoots() == 0)
      return nullptr;

    TopoDS_Shape shape = reader.OneShape();
    if (shape.IsNull())
      return nullptr;

    // Apply shape healing
    ShapeFix_Shape fixer(shape);
    fixer.Perform();
    TopoDS_Shape fixed = fixer.Shape();

    return new OCCTShape(fixed.IsNull() ? shape : fixed);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

double OCCTDebugGetReadMaxPrecisionVal(void)
{
  std::lock_guard<std::mutex> igesLock(igesMutex());
  return Interface_Static::RVal("read.maxprecision.val");
}

void OCCTDebugSetReadMaxPrecisionVal(double value)
{
  std::lock_guard<std::mutex> igesLock(igesMutex());
  Interface_Static::SetRVal("read.maxprecision.val", value);
}

bool OCCTExportIGES(OCCTShapeRef shape, const char* path)
{
  if (!shape || !path)
    return false;
  if (shape->shape.IsNull())
    return false;

  std::lock_guard<std::mutex> igesLock(igesMutex());
  try
  {
    // Validate shape before IGES export, since the OCCT translator can segfault on
    // invalid geometry
    // #2750: BRepCheck_Analyzer faults on a face edge with no valid 3D curve and a pcurve (#2746),
    // and this export already refuses an invalid shape. Such an edge IS invalid, by OCCT's own
    // BRepCheck_No3DCurve, so the guard reaches the same refusal one step earlier.
    if (occtShapeHasPCurveOnlyEdge(shape->shape))
      return false;
    // #2777: a face with no surface faults on the way out, whatever edges it carries. The writer
    // reaches three untested dereferences of that handle and the BRepCheck_Analyzer below is one of
    // them, so the guard sits ahead of it. The shape is invalid either way, which is the refusal
    // this function already gives an analyzer-invalid one. See occtShapeHasSurfacelessFace.
    if (occtShapeHasSurfacelessFace(shape->shape))
      return false;
    BRepCheck_Analyzer analyzer(shape->shape);
    if (!analyzer.IsValid())
      return false;

    bool success = false;
    {
      IGESControl_Writer writer("MM", 0); // Millimeters, faces mode

      if (!writer.AddShape(shape->shape))
      {
        return false;
      }

      writer.ComputeModel();
      success = writer.Write(path);
    }
    return success;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}
