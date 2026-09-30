//
//  OCCTBridge_Surface_Conversion.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Surface.mm (#1380): GeomConvert_ApproxSurface, ShapeCustom_Surface,
//  KnotSplitting/JoinBezierPatches/ConvertToAnalytical/SplitByContinuity/GridEval,
//  GeomAPI_ProjectPointOnSurf, BiTgte_CurveOnEdge. Public C surface unchanged; every sibling file
//  imports the same headers this one does (the shared preamble below). No symbol changes, pure file
//  move -- see Scripts/repro/396-bridge-mm-split/ for how.
//

//
//  OCCTBridge_Surface.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm, issue #99.
//
//  3D parametric surface cluster (v0.20):
//
//  - Geom_Surface construction (plane, cylinder, cone, sphere, torus,
//    surface-of-revolution, surface-of-extrusion, BSpline, Bezier,
//    rectangular-trimmed, offset)
//  - GeomConvert + GeomConvert_ApproxSurface
//  - GeomFill_Pipe (parametric pipe surface)
//  - Local properties (GeomLProp_SLProps)
//  - Adaptor (GeomAdaptor_Surface) introspection: surface type, axes,
//    UV bounds, periodic flags, degrees, knot/pole counts
//
//  OCCTSurface struct definition kept in BOTH this TU and OCCTBridge.mm
//  (identical layout, ODR-safe across TUs), main still uses
//  surface->surface field access in projection / surface-grid eval / etc.
//
//  Public C surface unchanged. No symbol changes, pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <cmath>
#include <Geom_BezierSurface.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_Curve.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_OffsetSurface.hxx>
#include <Geom_Plane.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_Surface.hxx>
#include <Geom_SurfaceOfLinearExtrusion.hxx>
#include <Geom_SurfaceOfRevolution.hxx>
#include <Geom_ToroidalSurface.hxx>

#include <GeomAbs_Shape.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_ApproxSurface.hxx>
#include <GeomConvert_BSplineSurfaceToBezierSurface.hxx>
#include <GeomAPI_IntSS.hxx>
#include <GeomAPI_IntCS.hxx>
#include <GC_MakeConicalSurface.hxx>
#include <GC_MakeCylindricalSurface.hxx>
#include <GC_MakePlane.hxx>
#include <GC_MakeTrimmedCone.hxx>
#include <GC_MakeTrimmedCylinder.hxx>
#include <GeomConvert_BSplineSurfaceKnotSplitting.hxx>
#include <GeomConvert_CompBezierSurfacesToBSplineSurface.hxx>
#include <GeomFill_Pipe.hxx>
#include <GeomFill_BSplineCurves.hxx>
#include <Adaptor3d_IsoCurve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <LocalAnalysis_SurfaceContinuity.hxx>
#include <GeomFill_ConstantBiNormal.hxx>
#include <GeomFill_Darboux.hxx>
#include <GeomFill_Fixed.hxx>
#include <GeomFill_Frenet.hxx>
#include <GeomFill_NSections.hxx>
#include <GeomFill_BoundWithSurf.hxx>
#include <GeomLib_Tool.hxx>
#include <GeomLib_IsPlanarSurface.hxx>
#include <GeomFill_AppSurf.hxx>
#include <GeomFill_DegeneratedBound.hxx>
#include <GeomFill_GuideTrihedronAC.hxx>
#include <GeomFill_GuideTrihedronPlan.hxx>
#include <GeomFill_Line.hxx>
#include <GeomFill_LocationDraft.hxx>
#include <GeomFill_Profiler.hxx>
#include <GeomFill_SectionGenerator.hxx>
#include <GeomFill_SectionPlacement.hxx>
#include <GeomFill_Stretch.hxx>
#include <GeomFill_Generator.hxx>
#include <Extrema_ExtPS.hxx>
#include <Extrema_ExtSS.hxx>
#include <Extrema_POnSurf.hxx>
#include <gce_MakePln.hxx>
#include <Convert_CylinderToBSplineSurface.hxx>
#include <Convert_ConeToBSplineSurface.hxx>
#include <Convert_TorusToBSplineSurface.hxx>
#include <Convert_SphereToBSplineSurface.hxx>
#include <BiTgte_CurveOnEdge.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <GeomAPI_PointsToBSplineSurface.hxx>
#include <TColgp_HArray2OfPnt.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <TColStd_Array2OfReal.hxx>
#include <Adaptor3d_CurveOnSurface.hxx>
#include <BRepTopAdaptor_TopolTool.hxx>
#include <Contap_ContAna.hxx>
#include <Contap_Contour.hxx>
#include <Contap_IType.hxx>
#include <Contap_Line.hxx>
#include <Approx_MCurvesToBSpCurve.hxx>
#include <GeomFill_Coons.hxx>
#include <GeomFill_CoonsAlgPatch.hxx>
#include <GeomFill_CorrectedFrenet.hxx>
#include <GeomFill_Curved.hxx>
#include <GeomFill_CurveAndTrihedron.hxx>
#include <GeomFill_DiscreteTrihedron.hxx>
#include <GeomFill_DraftTrihedron.hxx>
#include <GeomFill_EvolvedSection.hxx>
#include <GeomFill_Sweep.hxx>
#include <GeomFill_UniformSection.hxx>
#include <GeomInt_IntSS.hxx>
#include <IntSurf_PntOn2S.hxx>
#include <Law_Constant.hxx>
#include <GeomFill_ConstrainedFilling.hxx>
#include <GeomFill_SimpleBound.hxx>
#include <ShapeCustom_Surface.hxx>
#include <ShapeUpgrade_SplitSurfaceContinuity.hxx>
#include <TColGeom_Array2OfBezierSurface.hxx>
#include <TColStd_HSequenceOfReal.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepAdaptor_CompCurve.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <GeomLProp_SLProps.hxx>
#include <TopExp_Explorer.hxx>
#include <TopAbs.hxx>
#include <TopoDS.hxx>
#include <BRep_Tool.hxx>
#include <GeomAPI_ExtremaSurfaceSurface.hxx>

#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Ax3.hxx>
#include <gp_Cone.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Sphere.hxx>
#include <gp_Torus.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>

// MARK: - Surface: Parametric Surfaces (v0.20.0)
// ============================================================================

#include <BndLib_AddSurface.hxx>

// Additional includes gathered from throughout the original file (#1380):
#include <GeomGridEval_Surface.hxx>
#include <GeomAPI_ExtremaCurveSurface.hxx>
#include <ShapeAnalysis_CanonicalRecognition.hxx>
#include <gp_Elips.hxx>
#include <GeomFill_BezierCurves.hxx>
#include <GeomFill_FillingStyle.hxx>
#include <Geom_BezierCurve.hxx>
#include <ShapeAnalysis_Surface.hxx>
#include <BRepLib_CheckCurveOnSurface.hxx>
#include <GC_MakeArcOfEllipse.hxx>
#include <ShapeFix_EdgeConnect.hxx>
#include <ShapeUpgrade_ShapeConvertToBezier.hxx>
#include <BRepFill_Filling.hxx>
#include <BRepExtrema_SelfIntersection.hxx>
#include <BRepGProp_Face.hxx>
#include <ShapeAnalysis_WireOrder.hxx>
#include <ElSLib.hxx>
#include <Convert_ElementarySurfaceToBSplineSurface.hxx>
#include <Geom_OffsetCurve.hxx>
#include <gp_Pnt2d.hxx>
#include <NCollection_HArray1.hxx>
#include <NCollection_Array1.hxx>
#include <TopExp.hxx>
#include <TopoDS_Edge.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <ProjLib_Plane.hxx>
#include <ProjLib_Cylinder.hxx>
#include <gp_Pln.hxx>
#include <gp_Lin.hxx>
#include <gp_Circ.hxx>
#include <GeomEval_EllipsoidSurface.hxx>
#include <GeomEval_HyperboloidSurface.hxx>
#include <GeomEval_ParaboloidSurface.hxx>
#include <GeomEval_CircularHelicoidSurface.hxx>
#include <GeomEval_HypParaboloidSurface.hxx>
#include <GeomFill_Gordon.hxx>
#include <GeomEval_TBezierSurface.hxx>
#include <GeomEval_AHTBezierSurface.hxx>
#include <GeomFill_NetworkSurface.hxx>
#include <GeomAPI_ExtremaCurveCurve.hxx>

// Shared private structs/helpers (#1380): every split file gets this identical block,
// compiled independently per TU -- see this split's own README for why.

struct OCCTGeomIntSS
{
  GeomInt_IntSS intss;
  bool          valid;
};

struct OCCTContapContour
{
  Contap_Contour contour;
  bool           valid;
  bool           empty;
};

// MARK: - GeomFill_Profiler (v0.79)
// --- GeomFill_Profiler ---
struct GeomFillProfilerOpaque
{
  GeomFill_Profiler profiler;
  bool              isDone;
};

// MARK: - GeomFill_LocationDraft (v0.79)
// --- GeomFill_LocationDraft ---
struct LocationDraftOpaque
{
  Handle(GeomFill_LocationDraft) loc;
};

// MARK: - GeomFill_GuideTrihedronAC (v0.79)
// --- GeomFill_GuideTrihedronAC ---
struct GuideTrihedronACOpaque
{
  Handle(GeomFill_GuideTrihedronAC) tri;
};

// MARK: - GeomFill_GuideTrihedronPlan (v0.79)
// --- GeomFill_GuideTrihedronPlan ---
struct GuideTrihedronPlanOpaque
{
  Handle(GeomFill_GuideTrihedronPlan) tri;
};

// buildSurfaceFromElementary (defined below, shared with Cylinder/Cone/Torus) takes any
// Convert_ElementarySurfaceToBSplineSurface subclass by base-class reference.
// Convert_SphereToBSplineSurface is one such subclass (#791), so it can call the same helper;
// forward-declared here since the helper's definition follows this function in the file.
static OCCTSurfaceRef buildSurfaceFromElementary(
  const Convert_ElementarySurfaceToBSplineSurface& conv);

struct OCCTBiTgteCurveOnEdge
{
  BiTgte_CurveOnEdge curve;

  OCCTBiTgteCurveOnEdge(const TopoDS_Edge& e1, const TopoDS_Edge& e2)
      : curve(e1, e2)
  {
  }
};

struct OCCTProjOnSurf
{
  GeomAPI_ProjectPointOnSurf proj;
};

struct OCCTIntCS
{
  GeomAPI_IntCS intcs;
};

int32_t OCCTSurfaceEvaluateGrid(OCCTSurfaceRef surface,
                                const double*  uParams,
                                int32_t        uCount,
                                const double*  vParams,
                                int32_t        vCount,
                                double*        outXYZ)
{
  if (!surface || surface->surface.IsNull() || !uParams || !vParams || !outXYZ || uCount <= 0
      || vCount <= 0)
    return 0;
  try
  {
    GeomGridEval_Surface       evaluator(surface->surface);
    NCollection_Array1<double> uArr = occtGridEvalParams(uParams, uCount);
    NCollection_Array1<double> vArr = occtGridEvalParams(vParams, vCount);

    NCollection_Array2<gp_Pnt> results = evaluator.EvaluateGrid(uArr, vArr);
    // Reject rather than clamp, unlike the curve family's std::min. The loop below indexes
    // results by uCount/vCount, so a short grid would be an out-of-bounds *read* here (and
    // this build defines No_Exception, so NCollection's own bounds check is compiled out and
    // that read is undefined rather than a caught Standard_OutOfRange). A partly-filled 2D
    // grid also has no count worth returning: a caller checking n == uCount * vCount cannot
    // do anything useful with "some rows are real". Not reachable in the pinned kernel, where
    // every surface evaluator returns a full uCount x vCount grid or an empty one, and empty
    // bottoms out at a null surface or empty params, both rejected above.
    if (results.NbRows() < uCount || results.NbColumns() < vCount)
      return 0;

    for (int32_t iu = 0; iu < uCount; iu++)
    {
      for (int32_t iv = 0; iv < vCount; iv++)
      {
        const gp_Pnt& pt    = results.Value(iu + 1, iv + 1);
        const int32_t idx   = occtSurfaceGridIndex(iu, iv, vCount);
        outXYZ[idx * 3]     = pt.X();
        outXYZ[idx * 3 + 1] = pt.Y();
        outXYZ[idx * 3 + 2] = pt.Z();
      }
    }
    return uCount * vCount;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

int32_t OCCTSurfaceEvaluateGridD1(OCCTSurfaceRef surface,
                                  const double*  uParams,
                                  int32_t        uCount,
                                  const double*  vParams,
                                  int32_t        vCount,
                                  double*        outXYZ,
                                  double*        outD1U,
                                  double*        outD1V)
{
  if (!surface || surface->surface.IsNull() || !uParams || !vParams || !outXYZ || !outD1U || !outD1V
      || uCount <= 0 || vCount <= 0)
    return 0;
  try
  {
    GeomGridEval_Surface       evaluator(surface->surface);
    NCollection_Array1<double> uArr = occtGridEvalParams(uParams, uCount);
    NCollection_Array1<double> vArr = occtGridEvalParams(vParams, vCount);

    NCollection_Array2<GeomGridEval::SurfD1> results = evaluator.EvaluateGridD1(uArr, vArr);
    if (results.NbRows() < uCount || results.NbColumns() < vCount)
      return 0; // see EvaluateGrid

    for (int32_t iu = 0; iu < uCount; iu++)
    {
      for (int32_t iv = 0; iv < vCount; iv++)
      {
        const GeomGridEval::SurfD1& r   = results.Value(iu + 1, iv + 1);
        const int32_t               idx = occtSurfaceGridIndex(iu, iv, vCount);
        outXYZ[idx * 3]                 = r.Point.X();
        outXYZ[idx * 3 + 1]             = r.Point.Y();
        outXYZ[idx * 3 + 2]             = r.Point.Z();
        outD1U[idx * 3]                 = r.D1U.X();
        outD1U[idx * 3 + 1]             = r.D1U.Y();
        outD1U[idx * 3 + 2]             = r.D1U.Z();
        outD1V[idx * 3]                 = r.D1V.X();
        outD1V[idx * 3 + 1]             = r.D1V.Y();
        outD1V[idx * 3 + 2]             = r.D1V.Z();
      }
    }
    return uCount * vCount;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

int32_t OCCTCurve3DIntersectSurface(OCCTCurve3DRef                curve,
                                    OCCTSurfaceRef                surface,
                                    OCCTCurveSurfaceIntersection* outHits,
                                    int32_t                       maxHits)
{
  if (!curve || curve->curve.IsNull() || !surface || surface->surface.IsNull() || !outHits
      || maxHits <= 0)
    return 0;
  try
  {
    GeomAPI_IntCS inter(curve->curve, surface->surface);
    if (!inter.IsDone())
      return 0;
    int32_t nb    = inter.NbPoints();
    int32_t count = (nb < maxHits) ? nb : maxHits;
    for (int32_t i = 0; i < count; i++)
    {
      gp_Pnt pt = inter.Point(i + 1);
      double w, u, v;
      inter.Parameters(i + 1, u, v, w);
      outHits[i].point[0]   = pt.X();
      outHits[i].point[1]   = pt.Y();
      outHits[i].point[2]   = pt.Z();
      outHits[i].paramCurve = w;
      outHits[i].paramU     = u;
      outHits[i].paramV     = v;
    }
    return count;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

int32_t OCCTSurfaceIntersect(OCCTSurfaceRef  s1,
                             OCCTSurfaceRef  s2,
                             double          tolerance,
                             OCCTCurve3DRef* outCurves,
                             int32_t         maxCurves)
{
  if (!s1 || s1->surface.IsNull() || !s2 || s2->surface.IsNull() || !outCurves || maxCurves <= 0)
    return 0;
  try
  {
    GeomAPI_IntSS inter(s1->surface, s2->surface, tolerance);
    if (!inter.IsDone())
      return 0;
    int32_t nb    = inter.NbLines();
    int32_t count = (nb < maxCurves) ? nb : maxCurves;
    for (int32_t i = 0; i < count; i++)
    {
      Handle(Geom_Curve) c = inter.Line(i + 1);
      if (c.IsNull())
      {
        outCurves[i] = nullptr;
      }
      else
      {
        outCurves[i] = new OCCTCurve3D(c);
      }
    }
    return count;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

double OCCTCurve3DDistanceToSurface(OCCTCurve3DRef curve, OCCTSurfaceRef surface)
{
  if (!curve || curve->curve.IsNull() || !surface || surface->surface.IsNull())
    return -1.0;
  try
  {
    GeomAPI_ExtremaCurveSurface extrema(curve->curve, surface->surface);
    // NbExtrema() == 0 is exactly IsDone() here (#2831): it returns myExtCS.NbExt() when myIsDone
    // and 0 otherwise, and myIsDone is set whenever Extrema_ExtCS is done with either a solution or
    // a parallel verdict, whose branch appends one mySqDist entry (Extrema_ExtCS.cxx:305). So the
    // count is >= 1 whenever the algorithm succeeded, and LowerDistance() reads mySqDist alone.
    //
    // THAT HOLDS ONLY BECAUSE THIS READS THE DISTANCE AND NOTHING ELSE. The same parallel branch
    // appends nothing to the point sequences, so a Points()/NearestPoints() read behind this same
    // guard would fault uncatchably, which is what #2840 measured in the Extrema_ExtSS twin. Add an
    // IsParallel() gate before touching a point here, do not extend the count test.
    if (extrema.NbExtrema() == 0)
      return -1.0;
    return extrema.LowerDistance();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return -1.0;
  }
}

int32_t OCCTSurfaceSurfaceIntersect(OCCTSurfaceRef  surface1,
                                    OCCTSurfaceRef  surface2,
                                    double          tolerance,
                                    OCCTCurve3DRef* outCurves,
                                    int32_t         maxCurves)
{
  if (!surface1 || !surface2 || !outCurves || maxCurves < 1)
    return 0;
  if (surface1->surface.IsNull() || surface2->surface.IsNull())
    return 0;
  try
  {
    GeomAPI_IntSS intersector(surface1->surface, surface2->surface, tolerance);
    if (!intersector.IsDone())
      return 0;
    int32_t nbLines = intersector.NbLines();
    int32_t count   = std::min(nbLines, maxCurves);
    for (int32_t i = 0; i < count; ++i)
    {
      Handle(Geom_Curve) curve = intersector.Line(i + 1); // 1-based
      if (curve.IsNull())
      {
        outCurves[i] = nullptr;
      }
      else
      {
        outCurves[i] = new OCCTCurve3D(curve);
      }
    }
    return count;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

int32_t OCCTCurveSurfaceIntersect(OCCTCurve3DRef         curve,
                                  OCCTSurfaceRef         surface,
                                  OCCTCurveSurfacePoint* outPoints,
                                  int32_t                maxPoints)
{
  if (!curve || !surface || !outPoints || maxPoints < 1)
    return 0;
  if (curve->curve.IsNull() || surface->surface.IsNull())
    return 0;
  try
  {
    GeomAPI_IntCS intersector(curve->curve, surface->surface);
    if (!intersector.IsDone())
      return 0;
    int32_t nbPoints = intersector.NbPoints();
    int32_t count    = std::min(nbPoints, maxPoints);
    for (int32_t i = 0; i < count; ++i)
    {
      gp_Pnt pt = intersector.Point(i + 1);
      double u, v, w;
      intersector.Parameters(i + 1, u, v, w);
      outPoints[i].x = pt.X();
      outPoints[i].y = pt.Y();
      outPoints[i].z = pt.Z();
      outPoints[i].u = u;
      outPoints[i].v = v;
      outPoints[i].w = w;
    }
    return count;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

int32_t OCCTSurfaceExtrema(OCCTSurfaceRef            s1,
                           OCCTSurfaceRef            s2,
                           double                    u1Min,
                           double                    u1Max,
                           double                    v1Min,
                           double                    v1Max,
                           double                    u2Min,
                           double                    u2Max,
                           double                    v2Min,
                           double                    v2Max,
                           OCCTSurfaceExtremaResult* outResult)
{
  if (!s1 || !s2 || !outResult)
    return 0;
  if (s1->surface.IsNull() || s2->surface.IsNull())
    return 0;
  try
  {
    GeomAPI_ExtremaSurfaceSurface
      extrema(s1->surface, s2->surface, u1Min, u1Max, v1Min, v1Max, u2Min, u2Max, v2Min, v2Max);

    // #2840: NbExtrema() > 0 is NOT enough to read NearestPoints()/LowerDistanceParameters(), and
    // this is not the harmless version of that mistake. Extrema_ExtSS's analytic parallel branch
    // (Extrema_ExtSS.cxx:226-234) appends one entry to mySqDist and nothing to myPOnS1/myPOnS2,
    // NbExt() is mySqDist.Length(), and Extrema_ExtSS::Points bounds only against NbExt(), so both
    // accessors read myPOnS1.Value(1) on an empty NCollection_Sequence. Standard_OutOfRange is
    // compiled out in this Release kernel, so that read is an OS fault, uncatchable by the
    // catch (...) below (#345). Measured with two parallel Geom_Planes 5 apart,
    // Scripts/repro/2831/probe.mm: NbExtrema() == 1, IsParallel() == true, LowerDistance() == 5
    // correctly, and NearestPoints() and LowerDistanceParameters() each exit 139.
    //
    // So gate on IsParallel(), as OCCTCurve3DExtrema does for Extrema_ExtCC's identical shape
    // (#636) and as OCCTExtremaExtElSSPlanes does one layer down. The refusal loses a real
    // measurement, the constant gap between the two surfaces, because OCCTSurfaceExtremaResult has
    // no way to report a distance with no points; giving it one is a SemVer event, held as #2876.
    //
    // Carried patch 0044 fixes the kernel half, bounding Extrema_ExtSS::Points against myPOnS1
    // rather than NbExt(), but it is NOT in the pinned asset and THIS GATE IS NOT RETIRED WHEN IT
    // IS. Patched, the kernel raises Standard_OutOfRange for the same input, which the catch below
    // turns into the same 0; the gate says so up front, costs nothing, and covers an older pin.
    if (extrema.IsParallel())
      return 0;
    int32_t nb = extrema.NbExtrema();
    if (nb <= 0)
      return 0;

    outResult->distance = extrema.LowerDistance();
    gp_Pnt p1, p2;
    extrema.NearestPoints(p1, p2);
    outResult->p1X = p1.X();
    outResult->p1Y = p1.Y();
    outResult->p1Z = p1.Z();
    outResult->p2X = p2.X();
    outResult->p2Y = p2.Y();
    outResult->p2Z = p2.Z();
    extrema.LowerDistanceParameters(outResult->u1, outResult->v1, outResult->u2, outResult->v2);
    return nb;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

// MARK: - Surface ConvertToAnalytical (v0.50)
OCCTSurfaceAnalyticalResult OCCTSurfaceConvertToAnalytical(OCCTSurfaceRef surface, double tolerance)
{
  OCCTSurfaceAnalyticalResult result = {};
  if (!surface || surface->surface.IsNull())
    return result;
  try
  {
    ShapeCustom_Surface  sc(surface->surface);
    Handle(Geom_Surface) recognized = sc.ConvertToAnalytical(tolerance, Standard_False);
    if (!recognized.IsNull())
    {
      auto* ref      = new OCCTSurface();
      ref->surface   = recognized;
      result.surface = ref;
      result.gap     = sc.Gap();
    }
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
  return result;
}

OCCTSurfaceRef _Nullable OCCTSurfaceConvertToPeriodic(OCCTSurfaceRef _Nonnull surface)
{
  if (!surface || surface->surface.IsNull())
    return nullptr;
  try
  {
    ShapeCustom_Surface  sc(surface->surface);
    Handle(Geom_Surface) periodic = sc.ConvertToPeriodic(Standard_False);
    if (periodic.IsNull())
      return nullptr;
    auto* ref    = new OCCTSurface();
    ref->surface = periodic;
    return ref;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

double OCCTSurfaceConversionGap(OCCTSurfaceRef _Nonnull surface)
{
  // Deprecated, always -1.0 (#1510). This used to construct a throwaway ShapeCustom_Surface and
  // run an unrelated ConvertToAnalytical(1e-3) recognition pass just to read its Gap(), which
  // reflects ONLY the last ConvertToAnalytical call per ShapeCustom_Surface's own header doc, and
  // is written even on ConvertToAnalytical's rejection path. It never measured
  // OCCTSurfaceConvertToPeriodic's result at all, and ConvertToPeriodic itself has no deviation to
  // report: it is a pure knot rearrangement (Geom_BSplineSurface::SetUPeriodic/SetVPeriodic), with
  // no myGap write anywhere in its implementation. See Scripts/repro/1510-surface-conversion-gap/
  // for the direct-sampling confirmation that a real gap measurement here would be uninformative.
  (void)surface;
  return -1.0;
}

OCCTBiTgteCurveOnEdgeRef OCCTBiTgteCurveOnEdgeCreate(OCCTShapeRef edgeOnFace, OCCTShapeRef edge)
{
  if (!edgeOnFace || !edge)
    return nullptr;
  try
  {
    TopoDS_Edge e1 = TopoDS::Edge(edgeOnFace->shape);
    TopoDS_Edge e2 = TopoDS::Edge(edge->shape);
    return new OCCTBiTgteCurveOnEdge(e1, e2);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

void OCCTBiTgteCurveOnEdgeRelease(OCCTBiTgteCurveOnEdgeRef curve)
{
  delete curve;
}

void OCCTBiTgteCurveOnEdgeDomain(OCCTBiTgteCurveOnEdgeRef curve, double* first, double* last)
{
  if (!curve)
    return;
  try
  {
    *first = curve->curve.FirstParameter();
    *last  = curve->curve.LastParameter();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

void OCCTBiTgteCurveOnEdgeValue(OCCTBiTgteCurveOnEdgeRef curve,
                                double                   u,
                                double*                  x,
                                double*                  y,
                                double*                  z)
{
  if (!curve)
    return;
  try
  {
    gp_Pnt p;
    curve->curve.D0(u, p);
    *x = p.X();
    *y = p.Y();
    *z = p.Z();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

OCCTSurfaceRef OCCTPointsToSurfaceBSpline(const double* points,
                                          int32_t       uCount,
                                          int32_t       vCount,
                                          int32_t       degMin,
                                          int32_t       degMax,
                                          int32_t       continuity,
                                          double        tol)
{
  if (!points || uCount < 2 || vCount < 2)
    return nullptr;
  try
  {
    TColgp_Array2OfPnt pts(1, uCount, 1, vCount);
    for (int v = 0; v < vCount; v++)
    {
      for (int u = 0; u < uCount; u++)
      {
        int idx = (v * uCount + u) * 3;
        pts.SetValue(u + 1, v + 1, gp_Pnt(points[idx], points[idx + 1], points[idx + 2]));
      }
    }
    GeomAPI_PointsToBSplineSurface approx(pts,
                                          degMin,
                                          degMax,
                                          occtGeomAbsFromParametricContinuity(continuity),
                                          tol);
    if (approx.IsDone())
    {
      return (OCCTSurfaceRef) new OCCTSurface{approx.Surface()};
    }
    return nullptr;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

// #1669: the 3D GeomEval surface evaluators' success contract, matching the curve half in
// OCCTBridge_Curve3D_Approximation.mm and the Geom2dEval ten #1646/#1668 fixed before it.
//
// These were `void` wrapped in a `try`, so a throw left the caller's pre-zeroed buffer untouched
// and Swift received the zero vector, indistinguishable from a real answer at the origin. The flag
// is read off the OUTPUTS rather than off the throw, because a non-finite argument walks past
// OCCT's `<= 0` validation (every comparison against NaN is false) and finite arguments can still
// evaluate to a non-finite point. EvalD0 never raises for any parameter, so a finite result is the
// whole of what "succeeded" can mean.
//
// Deliberately a second small file-static pair rather than a shared symbol: these are six-line
// leaf checks, and #1645 is the record of what giving small helpers external linkage across
// several .mm files costs.

/// Write a D0 result, refusing a non-finite point. Returns whether the outputs are a measurement.
static bool occtEvalSurfWriteD0(const gp_Pnt& p, double* px, double* py, double* pz)
{
  if (!std::isfinite(p.X()) || !std::isfinite(p.Y()) || !std::isfinite(p.Z()))
    return false;
  *px = p.X();
  *py = p.Y();
  *pz = p.Z();
  return true;
}

bool OCCTGeomEvalEllipsoidD0(double  a,
                             double  b,
                             double  c,
                             double  u,
                             double  v,
                             double* px,
                             double* py,
                             double* pz)
{
  if (!px || !py || !pz)
    return false;
  *px = 0.0;
  *py = 0.0;
  *pz = 0.0;
  try
  {
    gp_Ax3                    ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    GeomEval_EllipsoidSurface ell(ax, a, b, c);
    return occtEvalSurfWriteD0(ell.EvalD0(u, v), px, py, pz);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    *px = 0.0;
    *py = 0.0;
    *pz = 0.0;
    return false;
  }
}

OCCTSurfaceRef OCCTGeomEvalEllipsoidCreate(double a, double b, double c)
{
  try
  {
    gp_Ax3                    ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    auto                      ell = new GeomEval_EllipsoidSurface(ax, a, b, c);
    occ::handle<Geom_Surface> hSurf(ell);
    auto                      ref = new OCCTSurface();
    ref->surface                  = hSurf;
    return ref;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

bool OCCTGeomEvalHyperboloidD0(double  r1,
                               double  r2,
                               int32_t mode,
                               double  u,
                               double  v,
                               double* px,
                               double* py,
                               double* pz)
{
  if (!px || !py || !pz)
    return false;
  *px = 0.0;
  *py = 0.0;
  *pz = 0.0;
  try
  {
    gp_Ax3                      ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    auto                        sm = mode == 0 ? GeomEval_HyperboloidSurface::SheetMode::OneSheet
                                               : GeomEval_HyperboloidSurface::SheetMode::TwoSheets;
    GeomEval_HyperboloidSurface hyp(ax, r1, r2, sm);
    return occtEvalSurfWriteD0(hyp.EvalD0(u, v), px, py, pz);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    *px = 0.0;
    *py = 0.0;
    *pz = 0.0;
    return false;
  }
}

OCCTSurfaceRef OCCTGeomEvalHyperboloidCreate(double r1, double r2, int32_t mode)
{
  try
  {
    gp_Ax3                    ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    auto                      sm  = mode == 0 ? GeomEval_HyperboloidSurface::SheetMode::OneSheet
                                              : GeomEval_HyperboloidSurface::SheetMode::TwoSheets;
    auto                      hyp = new GeomEval_HyperboloidSurface(ax, r1, r2, sm);
    occ::handle<Geom_Surface> hSurf(hyp);
    auto                      ref = new OCCTSurface();
    ref->surface                  = hSurf;
    return ref;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

bool OCCTGeomEvalParaboloidD0(double focal, double u, double v, double* px, double* py, double* pz)
{
  if (!px || !py || !pz)
    return false;
  *px = 0.0;
  *py = 0.0;
  *pz = 0.0;
  try
  {
    gp_Ax3                     ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    GeomEval_ParaboloidSurface par(ax, focal);
    return occtEvalSurfWriteD0(par.EvalD0(u, v), px, py, pz);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    *px = 0.0;
    *py = 0.0;
    *pz = 0.0;
    return false;
  }
}

OCCTSurfaceRef OCCTGeomEvalParaboloidCreate(double focal)
{
  try
  {
    gp_Ax3                    ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    auto                      par = new GeomEval_ParaboloidSurface(ax, focal);
    occ::handle<Geom_Surface> hSurf(par);
    auto                      ref = new OCCTSurface();
    ref->surface                  = hSurf;
    return ref;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

bool OCCTGeomEvalCircularHelicoidD0(double  pitch,
                                    double  u,
                                    double  v,
                                    double* px,
                                    double* py,
                                    double* pz)
{
  if (!px || !py || !pz)
    return false;
  *px = 0.0;
  *py = 0.0;
  *pz = 0.0;
  try
  {
    gp_Ax3                           ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    GeomEval_CircularHelicoidSurface hel(ax, pitch);
    return occtEvalSurfWriteD0(hel.EvalD0(u, v), px, py, pz);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    *px = 0.0;
    *py = 0.0;
    *pz = 0.0;
    return false;
  }
}

OCCTSurfaceRef OCCTGeomEvalCircularHelicoidCreate(double pitch)
{
  try
  {
    gp_Ax3                    ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    auto                      hel = new GeomEval_CircularHelicoidSurface(ax, pitch);
    occ::handle<Geom_Surface> hSurf(hel);
    auto                      ref = new OCCTSurface();
    ref->surface                  = hSurf;
    return ref;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

bool OCCTGeomEvalHypParaboloidD0(double  a,
                                 double  b,
                                 double  u,
                                 double  v,
                                 double* px,
                                 double* py,
                                 double* pz)
{
  if (!px || !py || !pz)
    return false;
  *px = 0.0;
  *py = 0.0;
  *pz = 0.0;
  try
  {
    gp_Ax3                        ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    GeomEval_HypParaboloidSurface hp(ax, a, b);
    return occtEvalSurfWriteD0(hp.EvalD0(u, v), px, py, pz);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    *px = 0.0;
    *py = 0.0;
    *pz = 0.0;
    return false;
  }
}

OCCTSurfaceRef OCCTGeomEvalHypParaboloidCreate(double a, double b)
{
  try
  {
    gp_Ax3                    ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    auto                      hp = new GeomEval_HypParaboloidSurface(ax, a, b);
    occ::handle<Geom_Surface> hSurf(hp);
    auto                      ref = new OCCTSurface();
    ref->surface                  = hSurf;
    return ref;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

OCCTSurfaceRef OCCTGeomEvalTBezierSurfaceCreate(const double* poles,
                                                int32_t       uCount,
                                                int32_t       vCount,
                                                double        alphaU,
                                                double        alphaV)
{
  if (!poles || uCount < 3 || vCount < 3 || uCount % 2 == 0 || vCount % 2 == 0)
    return nullptr;
  try
  {
    NCollection_Array2<gp_Pnt> pts(1, uCount, 1, vCount);
    for (int i = 0; i < uCount; i++)
      for (int j = 0; j < vCount; j++)
      {
        int idx           = (i * vCount + j) * 3;
        pts(i + 1, j + 1) = gp_Pnt(poles[idx], poles[idx + 1], poles[idx + 2]);
      }
    auto                      ts = new GeomEval_TBezierSurface(pts, alphaU, alphaV);
    occ::handle<Geom_Surface> hSurf(ts);
    auto                      ref = new OCCTSurface(hSurf);
    return ref;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

OCCTSurfaceRef OCCTGeomEvalAHTBezierSurfaceCreate(const double* poles,
                                                  int32_t       uCount,
                                                  int32_t       vCount,
                                                  int32_t       algDegreeU,
                                                  int32_t       algDegreeV,
                                                  double        alphaU,
                                                  double        alphaV,
                                                  double        betaU,
                                                  double        betaV)
{
  if (!poles || uCount < 1 || vCount < 1)
    return nullptr;
  try
  {
    NCollection_Array2<gp_Pnt> pts(1, uCount, 1, vCount);
    for (int i = 0; i < uCount; i++)
      for (int j = 0; j < vCount; j++)
      {
        int idx           = (i * vCount + j) * 3;
        pts(i + 1, j + 1) = gp_Pnt(poles[idx], poles[idx + 1], poles[idx + 2]);
      }
    auto as =
      new GeomEval_AHTBezierSurface(pts, algDegreeU, algDegreeV, alphaU, alphaV, betaU, betaV);
    occ::handle<Geom_Surface> hSurf(as);
    auto                      ref = new OCCTSurface(hSurf);
    return ref;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}
