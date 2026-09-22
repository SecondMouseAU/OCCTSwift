//
//  OCCTBridge.mm
//  OCCTSwift
//
//  Objective-C++ implementation bridging to OpenCASCADE
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// MARK: - Global Serial Lock for Thread Safety
#include <mutex>

// Non-static (declared in OCCTBridge_Internal.h) so per-area TUs share the
// same underlying mutex via the linker.
std::recursive_mutex& occtGlobalMutex()
{
  static std::recursive_mutex mutex;
  return mutex;
}

void OCCTSerialLockAcquire(void)
{
  occtGlobalMutex().lock();
}

void OCCTSerialLockRelease(void)
{
  occtGlobalMutex().unlock();
}

// Install OCCT's signal handlers once (issue #175). OSD::SetSignal(false) installs
// SIGSEGV/SIGBUS/SIGFPE handlers without enabling the FPE-trapping FP mask, so an OS signal
// raised inside OCCT gets a named OCCT diagnostic (message + stack trace) rather than a bare
// crash report. Idempotent + thread-safe via std::once_flag.
//
// #1399: this comment used to end "so that signals raised inside OCCT become catchable via
// OCC_CATCH_SIGNALS instead of aborting the host process", which is not what this build does.
// OCC_CONVERT_SIGNALS is not defined here, so Standard_ErrorHandler.hxx expands
// OCC_CATCH_SIGNALS to nothing and Standard_ErrorHandler::Abort throws straight from the POSIX
// signal handler, which does not unwind. See okf/references/known-occt-bugs.md (#345) and the
// same correction at occtEnsureSignals' declaration in OCCTBridge_Internal.h.
#include <OSD.hxx>

void occtEnsureSignals()
{
  static std::once_flag once;
  std::call_once(once, [] { OSD::SetSignal(Standard_False); });
}

// MARK: - Caught-exception diagnostics (#1161)
//
// #1161 measured 3,652 `catch (...)` blocks in Sources/OCCTBridge/src and zero that catch
// Standard_Failure, so every OCCT failure reached Swift as nil with its type and message
// discarded. This is the channel that carries them across. It answers #1161's design question,
// asked in that issue's own triage, with a side channel: no signature changes, no
// `Result<T, OCCTError>` break across the public surface, no kernel rebuild.
//
// The mechanism is a bare `throw;` inside occtRecordCaughtException, which rethrows whatever the
// caller's `catch (...)` already holds and catches it again by type. That is what makes the
// per-site cost one line: an existing catch block does not have to be restructured into a typed
// catch ladder to get full diagnostics out of it. Verified against the pinned kernel in
// Scripts/repro/1161/probe.mm, which also shows ExceptionType() reporting the real OCCT subclass
// (Standard_ConstructionError, StdFail_NotDone) and a nested inner catch still rethrowing
// correctly to its outer one.
//
// NOT SIGNALS. OCC_CONVERT_SIGNALS is undefined in this build, so OCC_CATCH_SIGNALS expands to
// nothing and an OS signal raised inside OCCT never becomes a C++ exception. Nothing in this
// section can see a SIGSEGV/SIGBUS/SIGFPE, and the crashes that motivated #1161 (#345, #348,
// #484, #636, #913, #1022) are all that shape. See occtEnsureSignals above.
#include <Standard_Failure.hxx>
#include <Message.hxx>
#include <Message_Gravity.hxx>
#include <Message_Messenger.hxx>

#include <atomic>
#include <cstdlib>
#include <cstring>
#include <exception>
#include <string>
#include <vector>

namespace
{

// One caught exception, classified.
struct OCCTCaughtException
{
  std::string        context;
  std::string        exceptionType;
  std::string        message;
  std::string        stackTrace;
  OCCTDiagnosticKind kind = OCCTDiagnosticKindUnknown;
};

// Bound on the capture buffer. A capture switched on and never read is a slow leak otherwise;
// past the cap, records are counted and dropped rather than stored.
const size_t THE_DIAGNOSTIC_RECORD_LIMIT = 256;

struct OCCTDiagnosticsState
{
  std::vector<OCCTCaughtException> records;
  int32_t                          dropped = 0;
  bool                             capture = false;
};

// Thread-local, not shared: an OCCT exception is caught on the thread that made the bridge call,
// so its record belongs to that thread and no lock is needed. Also why a capture must not be
// opened around anything that can hop threads (an `await`); the Swift wrapper's capture scope
// takes a non-async closure so it cannot.
OCCTDiagnosticsState& occtDiagnosticsState()
{
  static thread_local OCCTDiagnosticsState aState;
  return aState;
}

// Enables logging when OCCTSWIFT_BRIDGE_DIAGNOSTICS is set to anything but empty or "0".
bool occtDiagnosticsLoggingFromEnvironment()
{
  const char* aValue = std::getenv("OCCTSWIFT_BRIDGE_DIAGNOSTICS");
  return aValue != nullptr && aValue[0] != '\0' && std::strcmp(aValue, "0") != 0;
}

// Process-wide, unlike the capture buffer: a developer switching logging on wants every thread's
// exceptions, not only the thread that flipped the switch.
std::atomic<bool>& occtDiagnosticsLogging()
{
  static std::atomic<bool> aFlag(occtDiagnosticsLoggingFromEnvironment());
  return aFlag;
}

// The record at `index`, or nullptr when there is no such record on this thread.
const OCCTCaughtException* occtDiagnosticRecordAt(int32_t theIndex)
{
  const OCCTDiagnosticsState& aState = occtDiagnosticsState();
  if (theIndex < 0 || static_cast<size_t>(theIndex) >= aState.records.size())
    return nullptr;
  return &aState.records[static_cast<size_t>(theIndex)];
}

// Send one record to OCCT's own default messenger, so a bridge diagnostic lands in the same
// stream as the kernel's own messages and obeys whatever printers the host attached.
void occtDiagnosticsLog(const OCCTCaughtException& theRecord)
{
  try
  {
    std::string aLine = "OCCTBridge: ";
    aLine += theRecord.context.empty() ? "<unknown function>" : theRecord.context;
    aLine += " caught ";
    aLine += theRecord.exceptionType.empty() ? "an exception" : theRecord.exceptionType;
    if (!theRecord.message.empty())
    {
      aLine += ": ";
      aLine += theRecord.message;
    }
    Message::DefaultMessenger()->Send(aLine.c_str(), Message_Alarm);
  }
  catch (...)
  {
    // A diagnostic that throws must not become the failure being diagnosed. Deliberately silent,
    // and deliberately not calling occtRecordCaughtException: this IS that function's tail.
  }
}

} // namespace

void occtRecordCaughtException(const char* theContext)
{
  OCCTDiagnosticsState& aState = occtDiagnosticsState();
  const bool            toLog  = occtDiagnosticsLogging().load(std::memory_order_relaxed);
  if (!aState.capture && !toLog)
    return;

  // Backstop for a call placed outside a catch block: a bare `throw;` with no exception in flight
  // calls std::terminate, and killing the process to report a diagnostic is not a trade worth
  // making. Never a licence to call this from anywhere but a catch block.
  if (!std::current_exception())
    return;

  OCCTCaughtException aRecord;
  aRecord.context = theContext != nullptr ? theContext : "";
  try
  {
    throw;
  }
  catch (const Standard_Failure& anEx)
  {
    // Standard_Failure derives from std::exception in OCCT 8.0.1, so this clause has to come
    // first or every OCCT failure is classified as a plain std::exception and loses its type.
    aRecord.kind          = OCCTDiagnosticKindOCCTFailure;
    aRecord.exceptionType = anEx.ExceptionType() != nullptr ? anEx.ExceptionType() : "";
    aRecord.message       = anEx.what() != nullptr ? anEx.what() : "";
    aRecord.stackTrace    = anEx.GetStackString() != nullptr ? anEx.GetStackString() : "";
  }
  catch (const std::exception& anEx)
  {
    aRecord.kind    = OCCTDiagnosticKindStdException;
    aRecord.message = anEx.what() != nullptr ? anEx.what() : "";
  }
  catch (...)
  {
    // Deliberately NOT calling occtRecordCaughtException here (#1161/#2077), and this is the one
    // site in the bridge where recording would not merely be wrong but fatal: this IS that
    // function's own classification ladder, so a call here would `throw;` the same exception,
    // reach this clause again and recurse until the stack ran out. #2077's sweep script inserted
    // one and it was reverted; the comment is what stops the next run reinserting it.
    aRecord.kind = OCCTDiagnosticKindUnknown;
  }

  if (toLog)
    occtDiagnosticsLog(aRecord);

  if (!aState.capture)
    return;
  if (aState.records.size() >= THE_DIAGNOSTIC_RECORD_LIMIT)
  {
    ++aState.dropped;
    return;
  }
  aState.records.push_back(aRecord);
}

void OCCTDiagnosticsSetCaptureEnabled(bool enabled)
{
  occtDiagnosticsState().capture = enabled;
}

bool OCCTDiagnosticsCaptureEnabled(void)
{
  return occtDiagnosticsState().capture;
}

void OCCTDiagnosticsSetLoggingEnabled(bool enabled)
{
  occtDiagnosticsLogging().store(enabled, std::memory_order_relaxed);
}

bool OCCTDiagnosticsLoggingEnabled(void)
{
  return occtDiagnosticsLogging().load(std::memory_order_relaxed);
}

void OCCTDiagnosticsClear(void)
{
  OCCTDiagnosticsState& aState = occtDiagnosticsState();
  aState.records.clear();
  aState.dropped = 0;
}

int32_t OCCTDiagnosticsRecordCount(void)
{
  return static_cast<int32_t>(occtDiagnosticsState().records.size());
}

int32_t OCCTDiagnosticsDroppedCount(void)
{
  return occtDiagnosticsState().dropped;
}

OCCTDiagnosticKind OCCTDiagnosticsRecordKind(int32_t index)
{
  const OCCTCaughtException* aRecord = occtDiagnosticRecordAt(index);
  return aRecord != nullptr ? aRecord->kind : OCCTDiagnosticKindUnknown;
}

const char* OCCTDiagnosticsRecordContext(int32_t index)
{
  const OCCTCaughtException* aRecord = occtDiagnosticRecordAt(index);
  return aRecord != nullptr ? aRecord->context.c_str() : nullptr;
}

const char* OCCTDiagnosticsRecordExceptionType(int32_t index)
{
  const OCCTCaughtException* aRecord = occtDiagnosticRecordAt(index);
  return aRecord != nullptr ? aRecord->exceptionType.c_str() : nullptr;
}

const char* OCCTDiagnosticsRecordMessage(int32_t index)
{
  const OCCTCaughtException* aRecord = occtDiagnosticRecordAt(index);
  return aRecord != nullptr ? aRecord->message.c_str() : nullptr;
}

const char* OCCTDiagnosticsRecordStackTrace(int32_t index)
{
  const OCCTCaughtException* aRecord = occtDiagnosticRecordAt(index);
  return aRecord != nullptr ? aRecord->stackTrace.c_str() : nullptr;
}

void OCCTDiagnosticsSetStackTraceDepth(int32_t depth)
{
  Standard_Failure::SetDefaultStackTraceLength(depth < 0 ? 0 : static_cast<int>(depth));
}

int32_t OCCTDiagnosticsStackTraceDepth(void)
{
  return static_cast<int32_t>(Standard_Failure::DefaultStackTraceLength());
}

// Suppress OCCT 8.0.0 header deprecation warnings (typedef aliases still work).
// Full migration to NCollection types is tracked for a future release.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-W#pragma-messages"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// OCCT Foundation Classes
#include <Standard.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>
#include <gp_Dir.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Trsf.hxx>
#include <gp_Pln.hxx>
#include <gp_Circ.hxx>

// Topology
#include <TopoDS.hxx>
#include <TopoDS_Shape.hxx>
#include <TopoDS_Wire.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Vertex.hxx>
#include <TopoDS_Compound.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>

// Geometry
#include <Geom_Circle.hxx>
#include <Geom_Line.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <Geom_Surface.hxx>
#include <Geom_Plane.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_CompCurveToBSplineCurve.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <TColStd_Array2OfReal.hxx>
#include <ShapeCustom_RestrictionParameters.hxx>
#include <RWObj_CafReader.hxx>
#include <RWObj_CafWriter.hxx>
#include <RWPly_CafWriter.hxx>
#include <NLPlate_NLPlate.hxx>
#include <NLPlate_HPG0Constraint.hxx>
#include <NLPlate_HPG1Constraint.hxx>
#include <Plate_D1.hxx>
#include <GeomAPI_PointsToBSplineSurface.hxx>
#include <ProjLib_ProjectOnPlane.hxx>
#include <GeomPlate_BuildAveragePlane.hxx>
#include <TNaming_Builder.hxx>
#include <TNaming_NamedShape.hxx>
#include <TNaming_Tool.hxx>
#include <ShapeAnalysis_Curve.hxx>
#include <Geom_SurfaceOfRevolution.hxx>
#include <BRepLib_FindSurface.hxx>
#include <ShapeFix_Wireframe.hxx>
#include <ShapeAnalysis_ShapeContents.hxx>
#include <XCAFDoc_LayerTool.hxx>
#include <GProp_PrincipalProps.hxx>
#include <GeomConvert_BSplineSurfaceToBezierSurface.hxx>
#include <GeomConvert_BSplineCurveKnotSplitting.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_BezierSurface.hxx>
#include <HLRBRep_PolyAlgo.hxx>
#include <HLRBRep_PolyHLRToShape.hxx>
#include <ShapeUpgrade_ShapeConvertToBezier.hxx>
#include <BRepExtrema_SelfIntersection.hxx>
#include <BRepGProp_Face.hxx>
#include <ShapeAnalysis_WireOrder.hxx>
#include <ShapeCustom.hxx>
#include <TDataStd_Integer.hxx>
#include <TDataStd_TreeNode.hxx>
#include <TDF_ChildIterator.hxx>
#include <TFunction_Function.hxx>
#include <TDataStd_Real.hxx>
#include <Geom2d_Line.hxx>
#include <BRepLProp_SLProps.hxx>
#include <BRepTools.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <GC_MakeCircle.hxx>
#include <GC_MakeLine.hxx>
#include <GC_MakeSegment.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColStd_Array1OfInteger.hxx>

// Primitive Creation
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeCone.hxx>
#include <BRepPrimAPI_MakeTorus.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepPrimAPI_MakeRevol.hxx>

// Sweep Operations
#include <BRepOffsetAPI_MakePipe.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>

// Boolean Operations
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Section.hxx>

// Modifications
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepOffsetAPI_MakeOffsetShape.hxx>
#include <BRepOffsetAPI_MakeOffset.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopTools_HSequenceOfShape.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
// TopTools_ListIteratorOfListOfShape.hxx removed in OCCT 8.0
#include <ShapeAnalysis_FreeBounds.hxx>
#include <GeomAbs_JoinType.hxx>

// Transformations
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepBuilderAPI_Copy.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>

// Building
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>

// Validation & Healing
#include <BRepLib.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <ShapeFix_Shape.hxx>
#include <ShapeFix_Solid.hxx>

// Sewing & Solid Creation
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepBuilderAPI_MakeSolid.hxx>
#include <TopoDS_Shell.hxx>
#include <TopoDS_Solid.hxx>

// Meshing
#include <BRepMesh_IncrementalMesh.hxx>
#include <IMeshTools_Parameters.hxx>
#include <Poly_Triangulation.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <Bnd_Box.hxx>
#include <BRepBndLib.hxx>
#include <GCPnts_TangentialDeflection.hxx>
#include <BRepAdaptor_Curve.hxx>

// Measurement & Analysis (v0.7.0)
#include <BRepExtrema_DistShapeShape.hxx>
#include <TopTools_IndexedMapOfShape.hxx>

// Advanced Modeling (v0.8.0)
#include <BRepOffsetAPI_DraftAngle.hxx>
#include <BRepAlgoAPI_Defeaturing.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <Law_Linear.hxx>
#include <BRepBuilderAPI_TransitionMode.hxx>

// Surfaces & Curves (v0.9.0)
#include <BRepAdaptor_CompCurve.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <BRepLProp_CLProps.hxx>
#include <GeomFill_BSplineCurves.hxx>
#include <BRepFill.hxx>
#include <TColgp_Array2OfPnt.hxx>

// Import/Export
#include <STEPControl_Reader.hxx>
#include <STEPControl_Writer.hxx>
#include <StlAPI_Writer.hxx>
#include <Interface_Static.hxx>
#include <XSControl_WorkSession.hxx>
#include <Transfer_FinderProcess.hxx>

#include <vector>
#include <cmath>
#include <string>

// XDE/XCAF Support (v0.6.0)
#include <Graphic3d_Vec3.hxx>
#include <TDocStd_Document.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <XCAFDoc_ColorTool.hxx>
#include <XCAFDoc_VisMaterialTool.hxx>
#include <XCAFDoc_VisMaterial.hxx>
#include <TDF_Label.hxx>
#include <TDF_LabelSequence.hxx>
#include <TDF_Tool.hxx>
#include <TDataStd_Name.hxx>
#include <Quantity_Color.hxx>
#include <Quantity_ColorRGBA.hxx>
#include <TopLoc_Location.hxx>
#include <STEPCAFControl_Reader.hxx>
#include <STEPCAFControl_Writer.hxx>

// HLR (Hidden Line Removal) for 2D drawings
#include <HLRBRep_Algo.hxx>
#include <HLRBRep_HLRToShape.hxx>
#include <HLRAlgo_Projector.hxx>

// IGES import/export (v0.10.0)
#include <IGESControl_Reader.hxx>
#include <IGESControl_Writer.hxx>

// Geometry Construction (v0.11.0)
#include <GeomAPI_Interpolate.hxx>
#include <TColgp_HArray1OfPnt.hxx>

// Feature-Based Modeling (v0.12.0)
#include <BRepFeat_MakePrism.hxx>
#include <BRepFeat_MakeCylindricalHole.hxx>
#include <BRepFeat_SplitShape.hxx>
#include <BRepFeat_Gluer.hxx>
#include <BRepOffsetAPI_MakeEvolved.hxx>
#include <BRepAlgoAPI_Splitter.hxx>

// Shape Healing & Analysis (v0.13.0)
#include <ShapeAnalysis_Shell.hxx>
#include <ShapeAnalysis_Wire.hxx>
#include <ShapeAnalysis_Surface.hxx>
#include <ShapeAnalysis_ShapeTolerance.hxx>
#include <ShapeFix_Wire.hxx>
#include <ShapeFix_Face.hxx>
#include <ShapeFix_Shell.hxx>
#include <ShapeUpgrade_UnifySameDomain.hxx>
#include <BRepCheck_Wire.hxx>
#include <BRepCheck_Shell.hxx>

// Camera (Metal Visualization)
#include <Graphic3d_Camera.hxx>

// SelectMgr (Metal Visualization)
#include <SelectMgr_ViewerSelector.hxx>
#include <SelectMgr_SelectableObject.hxx>
#include <SelectMgr_SelectionManager.hxx>
#include <SelectMgr_EntityOwner.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <StdSelect_BRepSelectionTool.hxx>
#include <StdSelect_BRepOwner.hxx>
#include <NCollection_DataMap.hxx>
#include <NCollection_Sequence.hxx>
#include <NCollection_IndexedDataMap.hxx>
#include <NCollection_Map.hxx>
#include <NCollection_PackedMap.hxx>
#include <TCollection_AsciiString.hxx>
#include <TColStd_PackedMapOfInteger.hxx>
#include <Graphic3d_Mat4.hxx>
#include <Graphic3d_Mat4d.hxx>
#include <Poly_Connect.hxx>

// Prs3d_Drawer (Metal Visualization)
#include <Prs3d_Drawer.hxx>

// ClipPlane (Metal Visualization)
#include <Graphic3d_ClipPlane.hxx>
#include <Graphic3d_Vec4.hxx>
#include <Graphic3d_BndBox3d.hxx>

// ZLayerSettings (Metal Visualization)
#include <Graphic3d_ZLayerSettings.hxx>
#include <Graphic3d_PolygonOffset.hxx>

// Advanced Blends & Surface Filling (v0.14.0)
#include <ChFi2d.hxx>
#include <ChFi2d_Builder.hxx>
#include <ChFi2d_FilletAPI.hxx>
#include <ChFi2d_ChamferAPI.hxx>
#include <BRepOffsetAPI_MakeFilling.hxx>
#include <GeomPlate_BuildPlateSurface.hxx>
#include <GeomPlate_MakeApprox.hxx>
#include <GeomPlate_PointConstraint.hxx>
#include <GeomPlate_CurveConstraint.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Adaptor3d_CurveOnSurface.hxx>

// v0.47.0: LocOpe_Revol, LocOpe_DPrism, GeomFill_ConstrainedFilling, BRepCheck
#include <LocOpe_Revol.hxx>
#include <LocOpe_DPrism.hxx>
#include <Adaptor3d_Curve.hxx>
#include <GeomFill_ConstrainedFilling.hxx>
#include <GeomFill_SimpleBound.hxx>
#include <BRepCheck_Face.hxx>
#include <BRepCheck_Solid.hxx>
#include <BRepCheck_Result.hxx>
#include <BRepCheck_Status.hxx>
#include <BRepCheck_ListOfStatus.hxx>

// v0.61.0: Approx, Contap, BOPAlgo, IntCurvesFace, BRepMesh, GeomPlate
#include <Contap_ContAna.hxx>
#include <gp_Sphere.hxx>
#include <gp_Cylinder.hxx>
#include <IntCurvesFace_Intersector.hxx>
#include <gp_Lin.hxx>
#include <BOPAlgo_CellsBuilder.hxx>
#include <BOPAlgo_Splitter.hxx>
#include <BOPAlgo_ArgumentAnalyzer.hxx>
#include <BRepAdaptor_Curve2d.hxx>
#include <BRepMesh_Deflection.hxx>
#include <Approx_CurveOnSurface.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <GeomAbs_Shape.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <BRepBuilderAPI_MakeShapeOnMesh.hxx>
#include <Poly_Array1OfTriangle.hxx>
#include <Poly_Triangle.hxx>
#include <GeomPlate_Surface.hxx>

// v0.48.0: Comprehensive LocOpe, BRepCheck, ShapeFix, BRepExtrema, ShapeUpgrade
#include <LocOpe_Pipe.hxx>
#include <LocOpe_LinearForm.hxx>
#include <LocOpe_RevolutionForm.hxx>
#include <LocOpe_SplitShape.hxx>
#include <LocOpe_FindEdges.hxx>
#include <LocOpe_FindEdgesInFace.hxx>
#include <LocOpe_CSIntersector.hxx>
#include <LocOpe_PntFace.hxx>
// #include <LocOpe_Gluer.hxx> // unused
#include <BRepCheck_Edge.hxx>
#include <BRepCheck_Vertex.hxx>
#include <ShapeFix_ShapeTolerance.hxx>
#include <ShapeFix_SplitCommonVertex.hxx>
#include <ShapeFix_FaceConnect.hxx>
#include <ShapeFix_Edge.hxx>
#include <ShapeFix_WireVertex.hxx>
#include <BRepExtrema_ExtCC.hxx>
#include <BRepExtrema_ExtFF.hxx>
#include <BRepExtrema_ExtPF.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <ShapeUpgrade_ShapeDivideClosed.hxx>
#include <ShapeUpgrade_ShapeDivideContinuity.hxx>

// #include <NCollection_Sequence.hxx> // unused in v0.48

// MARK: - Internal Structures

struct OCCTSewing
{
  BRepBuilderAPI_Sewing sewing;

  OCCTSewing(double tol)
      : sewing(tol)
  {
  }
};

// OCCTShape, OCCTWire, OCCTMesh, OCCTFace, OCCTEdge, OCCTDocument, OCCTDrawing
// are now defined in OCCTBridge_Internal.h (imported above).

// MARK: - #263 self-intersecting-wire guard

// A self-intersecting wire (BRepCheck_SelfIntersectingWire) — typically a mesh-derived
// outline that crosses itself — extrudes into a prism whose subsequent ShapeFix_Shape
// heal corrupts the heap and aborts with an uncatchable OS signal (#263; backtrace
// ShapeFix_Face::FixOrientation → BRep_Tool::Curve → BRep_TEdge::EmptyCopy). The bug is
// upstream in OCCT, but OCC_CATCH_SIGNALS is inert in this build, so the only safe defence
// is to PREVENT the crashing prism: detect the bad wire and refuse the op. Such a profile
// can never form a valid extruded solid, so returning nil loses nothing.
bool occtHasSelfIntersectingWire(const TopoDS_Shape& s)
{
  if (s.IsNull())
    return false;
  try
  {
    BRepCheck_Analyzer analyzer(s);
    if (!analyzer.IsValid())
    {
      // A wire that already bounds a TopoDS_Face somewhere in `s` gets a real face context
      // from BRepCheck_Analyzer's own recursive walk, so BRepCheck_Wire::SelfIntersect() can
      // fire on it here.
      for (TopExp_Explorer we(s, TopAbs_WIRE); we.More(); we.Next())
      {
        Handle(BRepCheck_Result) res = analyzer.Result(we.Current());
        if (res.IsNull())
          continue;
        for (BRepCheck_ListIteratorOfListOfStatus it(res->Status()); it.More(); it.Next())
        {
          if (it.Value() == BRepCheck_SelfIntersectingWire)
            return true;
        }
      }
    }

    // #1505: BRepCheck_Wire::SelfIntersect() requires a TopoDS_Face context to project pcurves
    // onto, so a wire with no enclosing face anywhere in `s` (e.g. a bare Shape.fromWire(_:)
    // shape, which is exactly what OCCTShapeCreateExtrusionShape/OCCTShapeHeal/
    // OCCTShapeHealWithHistory can be handed) is never examined by the walk above; it always
    // reads back "not flagged". If `s` carries no face at all, synthesize a planar face per
    // wire and check that instead. A shape that already has a face is left to the walk above:
    // every wire in it either bounds one of those faces (already checked with its real
    // context) or, in the two-callers case this bridge never builds, is a stray wire alongside
    // a face in the same compound, which stays out of scope for this fix.
    if (TopExp_Explorer(s, TopAbs_FACE).More())
      return false;

    for (TopExp_Explorer we(s, TopAbs_WIRE); we.More(); we.Next())
    {
      const TopoDS_Wire& wire = TopoDS::Wire(we.Current());
      try
      {
        BRepBuilderAPI_MakeFace faceMaker(wire, /*OnlyPlane=*/true);
        if (!faceMaker.IsDone())
          continue; // not planar, or otherwise can't be faced: no verdict from this path
        BRepCheck_Analyzer wireAnalyzer(faceMaker.Face());
        if (wireAnalyzer.IsValid())
          continue;
        for (TopExp_Explorer fwe(faceMaker.Face(), TopAbs_WIRE); fwe.More(); fwe.Next())
        {
          Handle(BRepCheck_Result) res = wireAnalyzer.Result(fwe.Current());
          if (res.IsNull())
            continue;
          for (BRepCheck_ListIteratorOfListOfStatus it(res->Status()); it.More(); it.Next())
          {
            if (it.Value() == BRepCheck_SelfIntersectingWire)
              return true;
          }
        }
      }
      catch (...)
      {
        // Couldn't face/check this one wire; fall through to whatever the other wires (or the
        // original analyzer walk above) already found rather than treating this as fatal.
        // Deliberately NOT calling occtRecordCaughtException here (#1161): this one recovers, and
        // the guard goes on to return a real verdict.
        continue;
      }
    }
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    // A BRepCheck that itself throws on the input is a strong "do not proceed" signal.
    return true;
  }
  return false;
}
