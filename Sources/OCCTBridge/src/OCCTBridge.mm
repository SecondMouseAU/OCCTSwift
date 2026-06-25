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
std::recursive_mutex& occtGlobalMutex() {
    static std::recursive_mutex mutex;
    return mutex;
}
void OCCTSerialLockAcquire(void) { occtGlobalMutex().lock(); }
void OCCTSerialLockRelease(void) { occtGlobalMutex().unlock(); }

// Install OCCT's signal handlers once (issue #175). OSD::SetSignal(false) installs
// SIGSEGV/SIGBUS/SIGFPE handlers without enabling the FPE-trapping FP mask, so that
// signals raised inside OCCT become catchable via OCC_CATCH_SIGNALS instead of aborting
// the host process. Idempotent + thread-safe via std::once_flag.
#include <OSD.hxx>
void occtEnsureSignals() {
    static std::once_flag once;
    std::call_once(once, []{ OSD::SetSignal(Standard_False); });
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

// For mesh-to-shape conversion
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepBuilderAPI_MakeSolid.hxx>
#include <ShapeFix_Solid.hxx>

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
#include <Geom_BSplineSurface.hxx>
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
#include <XCAFApp_Application.hxx>
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

// BREP native format (v0.10.0)
#include <BRep_Builder.hxx>

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
#include <BRepAdaptor_Curve.hxx>
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
#include <LocOpe_SplitDrafts.hxx>
#include <LocOpe_FindEdges.hxx>
#include <LocOpe_FindEdgesInFace.hxx>
#include <LocOpe_CSIntersector.hxx>
#include <LocOpe_PntFace.hxx>
// #include <LocOpe_Gluer.hxx> // unused
#include <BRepCheck_Analyzer.hxx>
#include <BRepCheck_Edge.hxx>
#include <BRepCheck_Wire.hxx>
#include <BRepCheck_Shell.hxx>
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

#include <BRepBuilderAPI_Sewing.hxx>

struct OCCTSewing {
    BRepBuilderAPI_Sewing sewing;
    OCCTSewing(double tol) : sewing(tol) {}
};

// OCCTShape, OCCTWire, OCCTMesh, OCCTFace, OCCTEdge, OCCTDocument, OCCTDrawing
// are now defined in OCCTBridge_Internal.h (imported above).

// MARK: - #263 self-intersecting-wire guard

#include <BRepCheck_Result.hxx>
#include <BRepCheck_ListOfStatus.hxx>

// A self-intersecting wire (BRepCheck_SelfIntersectingWire) — typically a mesh-derived
// outline that crosses itself — extrudes into a prism whose subsequent ShapeFix_Shape
// heal corrupts the heap and aborts with an uncatchable OS signal (#263; backtrace
// ShapeFix_Face::FixOrientation → BRep_Tool::Curve → BRep_TEdge::EmptyCopy). The bug is
// upstream in OCCT, but OCC_CATCH_SIGNALS is inert in this build, so the only safe defence
// is to PREVENT the crashing prism: detect the bad wire and refuse the op. Such a profile
// can never form a valid extruded solid, so returning nil loses nothing.
bool occtHasSelfIntersectingWire(const TopoDS_Shape& s) {
    if (s.IsNull()) return false;
    try {
        BRepCheck_Analyzer analyzer(s);
        if (analyzer.IsValid()) return false;   // fast path: a valid shape can't carry the flag
        for (TopExp_Explorer we(s, TopAbs_WIRE); we.More(); we.Next()) {
            Handle(BRepCheck_Result) res = analyzer.Result(we.Current());
            if (res.IsNull()) continue;
            for (BRepCheck_ListIteratorOfListOfStatus it(res->Status()); it.More(); it.Next()) {
                if (it.Value() == BRepCheck_SelfIntersectingWire) return true;
            }
        }
    } catch (...) {
        // A BRepCheck that itself throws on the input is a strong "do not proceed" signal.
        return true;
    }
    return false;
}

