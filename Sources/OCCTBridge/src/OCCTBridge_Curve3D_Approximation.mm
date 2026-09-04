//
//  OCCTBridge_Curve3D_Approximation.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Curve3D.mm (#1380): Approx_* (Curve3d, CurveOnSurface,
//  CurvilinearParameter, SameParameter, ApproxCurve), LocalAnalysis_CurveContinuity, GeomLib.
//  Public C surface unchanged; every sibling file imports the same headers this one does
//  (the shared preamble below). No symbol changes, pure file move -- see
//  Scripts/repro/396-bridge-mm-split/ for how.
//

//
//  OCCTBridge_Curve3D.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm, issue #99.
//
//  3D parametric curve cluster (v0.19):
//
//  - Geom_Curve construction (line, circle, ellipse, hyperbola, parabola,
//    Bezier, BSpline, trimmed, offset)
//  - GC makers (segment, circle, arc-of-circle)
//  - Conversion (Bezier <-> BSpline, composite-curve to BSpline,
//    GeomConvert_ApproxCurve)
//  - Sampling (UniformAbscissa, UniformDeflection, TangentialDeflection)
//  - Interpolation + fitting (Geom_BSpline through points)
//  - Local properties (GeomLProp_CLProps)
//  - Tangent / curvature evaluation
//
//  Defines `struct OCCTCurve3D` locally; the matching definition in
//  OCCTBridge.mm has identical layout (ODR-safe across TUs).
//
//  Public C surface unchanged. No symbol changes: a pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <Approx_Curve3d.hxx>
#include <Approx_CurveOnSurface.hxx>
#include <Approx_CurvilinearParameter.hxx>
#include <CPnts_UniformDeflection.hxx>
#include <LocalAnalysis_CurveContinuity.hxx>
#include <Geom_Axis1Placement.hxx>
#include <Geom_Axis2Placement.hxx>
#include <Geom_CartesianPoint.hxx>
#include <Geom_Direction.hxx>
#include <Geom_Point.hxx>
#include <Geom_Vector.hxx>
#include <Geom_VectorWithMagnitude.hxx>
#include <ShapeConstruct_Curve.hxx>
#include <GeomLib_Tool.hxx>
#include <GeomLib_CheckBSplineCurve.hxx>
#include <GeomLib_Interpolate.hxx>
#include <Approx_SameParameter.hxx>
#include <Extrema_ExtCC.hxx>
#include <Extrema_ExtCS.hxx>
#include <Extrema_LocateExtCC.hxx>
#include <Extrema_POnCurv.hxx>
#include <Extrema_POnSurf.hxx>
#include <gce_MakeCirc.hxx>
#include <gce_MakeDir.hxx>
#include <gce_MakeElips.hxx>
#include <gce_MakeHypr.hxx>
#include <gce_MakeLin.hxx>
#include <gce_MakeParab.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <Extrema_GenLocateExtPS.hxx>
#include <TColStd_HArray1OfReal.hxx>
#include <HelixGeom_BuilderHelix.hxx>
#include <HelixGeom_BuilderHelixCoil.hxx>
#include <HelixGeom_HelixCurve.hxx>
#include <HelixGeom_Tools.hxx>
#include <GeomEval_CircularHelixCurve.hxx>
#include <GeomEval_SineWaveCurve.hxx>
#include <GeomEval_TBezierCurve.hxx>
#include <GeomEval_AHTBezierCurve.hxx>
#include <GeomAdaptor_TransformedCurve.hxx>
// Approx_BSplineApproxInterp was removed in OCCT 8.0.0p1 (it backed the old Gordon
// prototype). The wrapper below is reimplemented on GeomAPI_PointsToBSpline, the
// documented replacement, keeping the same C ABI; see that section's comment for the
// resulting semantic changes (nbControlPoints/interpolation kinks become advisory).
#include <GeomAPI_PointsToBSpline.hxx>
#include <Geom_BSplineCurve.hxx>
#include <GeomAbs_Shape.hxx>
#include <Extrema_ExtPC.hxx>
#include <ExtremaPC_Curve.hxx>
#include <TColStd_HArray1OfBoolean.hxx>
#include <ShapeUpgrade_SplitCurve3dContinuity.hxx>
#include <BRep_Tool.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepLib.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <GeomAdaptor_Surface.hxx>

#include <GC_MakeArcOfCircle.hxx>
#include <GC_MakeArcOfEllipse.hxx>
#include <GC_MakeArcOfHyperbola.hxx>
#include <GC_MakeArcOfParabola.hxx>
#include <GC_MakeCircle.hxx>
#include <GC_MakeEllipse.hxx>
#include <GC_MakeHyperbola.hxx>
#include <GC_MakeSegment.hxx>
#include <ShapeCustom_Curve.hxx>
#include <ShapeUpgrade_SplitCurve3d.hxx>
#include <TColGeom_HArray1OfCurve.hxx>
#include <TColStd_HSequenceOfReal.hxx>
#include <gp_Hypr.hxx>
#include <gp_Parab.hxx>

#include <GCPnts_TangentialDeflection.hxx>
#include <GCPnts_UniformAbscissa.hxx>
#include <GCPnts_UniformDeflection.hxx>

#include <Geom_BezierCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Curve.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Hyperbola.hxx>
#include <Geom_Line.hxx>
#include <Geom_OffsetCurve.hxx>
#include <Geom_Parabola.hxx>
#include <Geom_TrimmedCurve.hxx>

#include <GeomAdaptor_Curve.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_ApproxCurve.hxx>
#include <GeomConvert_BSplineCurveToBezierCurve.hxx>
#include <GeomConvert_CompCurveToBSplineCurve.hxx>
#include <GeomLProp_CLProps.hxx>

#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>

// MARK: - Curve3D: 3D Parametric Curves (v0.19.0)

#include <Bnd_Box.hxx>
#include <BndLib_Add3dCurve.hxx>
#include <GCPnts_AbscissaPoint.hxx>

// Additional includes gathered from throughout the original file (#1380):
#include <GeomGridEval_Curve.hxx>
#include <GeomGridEval.hxx>
#include <ShapeAnalysis_Curve.hxx>
#include <GeomAPI_ExtremaCurveCurve.hxx>
#include <GCPnts_QuasiUniformAbscissa.hxx>
#include <GCPnts_QuasiUniformDeflection.hxx>
#include <ShapeUpgrade_SplitCurve2dContinuity.hxx>
#include <ShapeUpgrade_ConvertCurve2dToBezier.hxx>
#include <Geom_Transformation.hxx>
#include <ElCLib.hxx>
#include <gp_Quaternion.hxx>
#include <gp_EulerSequence.hxx>
#include <Convert_CompBezierCurvesToBSplineCurve.hxx>
#include <Convert_CompBezierCurves2dToBSplineCurve2d.hxx>
#include <gp_Pnt2d.hxx>
#include <NCollection_Array1.hxx>
#include <GeomLib_LogSample.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Hatch_Hatcher.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepTools.hxx>
#include <TopoDS.hxx>
#include <TopExp_Explorer.hxx>
#include <gp_Sphere.hxx>
#include <gp_Torus.hxx>
#include <gp_Cone.hxx>
#include <Geom_Plane.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_ToroidalSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_SweptSurface.hxx>
#include <Geom_SurfaceOfLinearExtrusion.hxx>
#include <Geom_SurfaceOfRevolution.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Ellipse.hxx>
#include <Geom2d_Hyperbola.hxx>
#include <Geom2d_Parabola.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2d_OffsetCurve.hxx>
#include <Extrema_ExtElC.hxx>
#include <Extrema_ExtElCS.hxx>
#include <Extrema_ExtElSS.hxx>
#include <Extrema_ExtPElC.hxx>
#include <Extrema_ExtPElS.hxx>
#include <gp_Elips.hxx>
#include <gp_Cylinder.hxx>
#include <math_IntegerVector.hxx>
#include <GeomLProp_SLProps.hxx>
#include <Adaptor3d_Curve.hxx>
#include <BRepAdaptor_CompCurve.hxx>

// Shared private structs/helpers (#1380): every split file gets this identical block,
// compiled independently per TU -- see this split's own README for why.

// === #491: one GeomConvert_ApproxCurve run behind both curve approximation entry points ===
//
// OCCTCurve3DApproximate (Curve3D.approximated) and OCCTGeomConvertApproxCurve
// (Curve3D.approxWithDetails) are two views of the same approximation: the first returns the
// fitted BSpline, the second returns it alongside the diagnostics OCCT already computed for it.
// They were written independently and drifted on which completion accessor decides success
// (IsDone() here, HasResult() there), so they run through this one helper instead.
//
// The shared gate is HasResult(). The header documents the two as different questions: IsDone() is
// "the approximation has been done within required tolerance", HasResult() is "did come out with a
// result that is not NECESSARILY within the required tolerance". In this kernel they cannot
// actually disagree: GeomConvert_ApproxCurve copies both flags off AdvApprox_ApproxAFunction, whose
// only HasResult-without-IsDone path is the ErrorCode = -1 assignment at
// AdvApprox_ApproxAFunction.cxx:550, commented out upstream ("// for now ErrorCode=-1;"). With
// that line dead, ErrorCode is only ever 0 (both flags set) or 1 (neither), which is why gating on
// IsDone() never actually rejected an over-tolerance fit: a circle fitted with one segment at
// degree 3 against a 1e-9 tolerance reports maxError 5.1 and still reports IsDone.
//
// HasResult() is the right one to standardise on regardless. It is what OCCT's own curve conversion
// entry points use (GeomConvert.cxx:345/441, GeomToIGES_GeomCurve.cxx:632,
// GeomFill_Profiler.cxx:136), it is what both surface entry points already used, and it is the only
// gate under which approxWithDetails' isDone/maxError diagnostics mean anything: reporting
// isDone: false is the point of that API, so it cannot also be the reason to return nothing.
//
// Continuity decodes through the #490 shared occtGeomAbsFromParametricContinuity rather than a
// local copy; this was the one call site that still had its own until the #491/#490 merge.
static OCCTApproxCurveResult occtApproxCurve(OCCTCurve3DRef c,
                                             double         tolerance,
                                             int32_t        continuity,
                                             int32_t        maxSegments,
                                             int32_t        maxDegree)
{
  OCCTApproxCurveResult result = {};
  // Both the outer handle and the curve it wraps: a null Geom_Curve reaches GeomAdaptor_Curve,
  // whose own Standard_NullObject precondition is compiled out of this Release kernel.
  if (!c || c->curve.IsNull())
    return result;
  try
  {
    GeomConvert_ApproxCurve approx(c->curve,
                                   tolerance,
                                   occtGeomAbsFromParametricContinuity(continuity),
                                   maxSegments,
                                   maxDegree);
    result.isDone    = approx.IsDone();
    result.hasResult = approx.HasResult();
    if (result.hasResult)
    {
      result.maxError                = approx.MaxError();
      Handle(Geom_BSplineCurve) bspl = approx.Curve();
      if (!bspl.IsNull())
        result.curve = new OCCTCurve3D(bspl);
    }
  }
  catch (...)
  {
  }
  return result;
}

// #794: shared helper for CPnts_UniformDeflection (full range vs explicit u1,u2)
static bool occtCPntsUniformDeflectionImpl(OCCTShapeRef shape,
                                           double       deflection,
                                           double       u1,
                                           double       u2,
                                           bool         hasRange,
                                           double* _Nullable* _Nonnull outParams,
                                           double* _Nullable* _Nonnull outPoints,
                                           int32_t* outCount)
{
  if (!occtShapeIsPresent(shape))
    return false;
  try
  {
    TopoDS_Edge       edge = TopoDS::Edge(shape->shape);
    BRepAdaptor_Curve bac(edge);
    double            firstParam = bac.FirstParameter();
    double            lastParam  = bac.LastParameter();
    if (hasRange)
    {
      // CPnts_UniformDeflection with explicit parameter range
      CPnts_UniformDeflection ud(bac, deflection, u1, u2, 1e-7, true);
      std::vector<double>     params;
      std::vector<gp_Pnt>     pts;
      while (ud.More())
      {
        double p = ud.Value();
        params.push_back(p);
        pts.push_back(bac.Value(p));
        ud.Next();
      }
      int32_t n = (int32_t)params.size();
      *outCount = n;
      if (n == 0)
      {
        *outParams = nullptr;
        *outPoints = nullptr;
        return false;
      }
      *outParams = (double*)malloc(n * sizeof(double));
      *outPoints = (double*)malloc(n * 3 * sizeof(double));
      for (int32_t i = 0; i < n; i++)
      {
        (*outParams)[i]         = params[i];
        (*outPoints)[i * 3]     = pts[i].X();
        (*outPoints)[i * 3 + 1] = pts[i].Y();
        (*outPoints)[i * 3 + 2] = pts[i].Z();
      }
      return true;
    }
    else
    {
      // CPnts_UniformDeflection with full range
      CPnts_UniformDeflection ud(bac, deflection, firstParam, lastParam, 1e-7, true);
      std::vector<double>     params;
      std::vector<gp_Pnt>     pts;
      while (ud.More())
      {
        double p = ud.Value();
        params.push_back(p);
        pts.push_back(bac.Value(p));
        ud.Next();
      }
      int32_t n = (int32_t)params.size();
      *outCount = n;
      if (n == 0)
      {
        *outParams = nullptr;
        *outPoints = nullptr;
        return false;
      }
      *outParams = (double*)malloc(n * sizeof(double));
      *outPoints = (double*)malloc(n * 3 * sizeof(double));
      for (int32_t i = 0; i < n; i++)
      {
        (*outParams)[i]         = params[i];
        (*outPoints)[i * 3]     = pts[i].X();
        (*outPoints)[i * 3 + 1] = pts[i].Y();
        (*outPoints)[i * 3 + 2] = pts[i].Z();
      }
      return true;
    }
  }
  catch (...)
  {
    return false;
  }
}

struct OCCTGeomPoint3D
{
  Handle(Geom_CartesianPoint) point;
};

struct OCCTGeomDirection
{
  Handle(Geom_Direction) direction;
};

struct OCCTGeomVector3D
{
  Handle(Geom_VectorWithMagnitude) vector;
};

struct OCCTAxis1Placement
{
  Handle(Geom_Axis1Placement) axis;
};

struct OCCTAxis2Placement
{
  Handle(Geom_Axis2Placement) axis;
};

struct OCCTQuaternion
{
  gp_Quaternion q;
};

// One nearest-point answer behind every entry point that wants the nearest solution over the
// curve's whole range: OCCTCurve3DNearestParameter and OCCTExtremaLocateOnCurve's full-range
// fallback.
//
// #500 unified them onto a single GeomAPI_ProjectPointOnCurve construction. #615 makes that
// construction the RIGHT one: GeomAPI reports extrema, not minima, so LowerDistance is not the
// nearest point and NbPoints() == 0 is not "no nearest point". Measured on the geometry #539 named,
// a half circle of radius 5 queried from (0, -6, 0): this reported the far side of the arc, 11
// away, where OCCTCurve3DProjectPoint -- converted by #539, same promise, same curve, same point --
// reported the true nearest at 7.81; and on a segment trimmed to [3, 8] queried at (100, 0, 0) it
// reported nothing at all where the converted sibling reported the segment's own end, 92 away. So
// the two spellings disagreed about which point is nearest AND about whether there is one.
//
// Both are now the same answer because both are now the same helper. See
// occtNearestPointOnCurveRange (OCCTBridge_Internal.h) for what each of its three candidate sources
// contributes and why none of them suffices alone.
//
// CONSEQUENCE, and it is the point rather than a side effect: this no longer returns false for a
// point with no perpendicular foot. A point beyond the end of a bounded curve is nearest to that
// end, and a circle's centre is equidistant from every point on it, so both now answer -- with a
// real parameter and a true distance. False is left meaning what it means for the converted
// siblings: no curve to answer about. Precision::Confusion() is the projection precision, matching
// the two converted entry points that likewise take none from their caller:
// OCCTEdgeProjectPoint (OCCTBridge_Properties.mm) and OCCTBRepExtremaExtPC
// (OCCTBridge_Topology.mm). Nothing in THIS file set that precedent -- OCCTCurve3DProjectPoint,
// the only other local caller of the helper, is handed a precision by its own caller.
//
// Not routed through here, and why: OCCTExtremaLocateOnCurve's PRIMARY search deliberately reports
// a windowed extremum near a caller-supplied guess (see there, and note that "near" is the window,
// not a ranking); OCCTExtremaPointCurve and OCCTProjOnCurve* need every extremum, not the nearest;
// OCCTEdgeProjectPoint (OCCTBridge_Properties.mm) reaches the same shared helper by its own route,
// from BRep_Tool::Curve's range rather than a Geom_Curve's.
static bool occtNearestProjectionOnCurve3d(OCCTCurve3DRef curve,
                                           const gp_Pnt&  point,
                                           gp_Pnt*        outNearest,
                                           double*        outParameter,
                                           double*        outDistance)
{
  if (!curve || curve->curve.IsNull())
    return false;
  try
  {
    return occtNearestPointOnCurveRange(curve->curve,
                                        point,
                                        curve->curve->FirstParameter(),
                                        curve->curve->LastParameter(),
                                        Precision::Confusion(),
                                        outNearest,
                                        outParameter,
                                        outDistance);
  }
  catch (...)
  {
    return false;
  }
}

struct OCCTProjOnCurve
{
  GeomAPI_ProjectPointOnCurve proj;
};

// #794: shared helper for ExtremaPC (whole curve vs bounded)
static int32_t occtExtremaPCCurveImpl(OCCTCurve3DRef curve,
                                      double         px,
                                      double         py,
                                      double         pz,
                                      double*        outParams,
                                      double*        outDistances,
                                      double*        outPx,
                                      double*        outPy,
                                      double*        outPz,
                                      int32_t        maxResults,
                                      double         uMin,
                                      double         uMax,
                                      bool           hasBounds)
{
  if (!curve || curve->curve.IsNull() || !outParams || !outDistances || maxResults <= 0)
    return 0;
  try
  {
    // ExtremaPC_Curve has deleted copy/move, so construct directly
    ExtremaPC_Curve extPC(hasBounds ? curve->curve : curve->curve,
                          hasBounds ? uMin : 0,
                          hasBounds ? uMax : 0);
    if (!extPC.IsInitialized())
      return 0;
    const auto& result = extPC.Perform(gp_Pnt(px, py, pz), 1e-9);
    if (!result.IsDone())
      return 0;
    int n = std::min((int)result.NbExt(), (int)maxResults);
    for (int i = 0; i < n; i++)
    {
      outParams[i]    = result[i].Parameter;
      outDistances[i] = std::sqrt(result[i].SquareDistance);
      if (outPx)
        outPx[i] = result[i].Point.X();
      if (outPy)
        outPy[i] = result[i].Point.Y();
      if (outPz)
        outPz[i] = result[i].Point.Z();
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

// --- Approx_BSplineApproxInterp (reimplemented on GeomAPI_PointsToBSpline) ---
//
// OCCT 8.0.0p1 removed Approx_BSplineApproxInterp. The C ABI here is preserved, but the
// fit is now produced by GeomAPI_PointsToBSpline (least-squares B-spline approximation),
// the migration target named in the p1 release notes. Semantic differences vs the old
// solver, kept so callers compile & run unchanged:
//   * nbControlPoints is ADVISORY: PointsToBSpline picks the pole count needed to meet
//     the tolerance within [DegMin, DegMax]; it is no longer an exact constraint.
//   * InterpolatePoint()/kink markers are no-ops (PointsToBSpline has no per-point exact
//     interpolation or C0-break control). The approximation still passes near the points.
//   * MaxError() is computed by projecting the input points back onto the fitted curve.
//   * PerformOptimal() is identical to Perform(); maxIter is ignored (no iterative mode).
//   * The Gauss-solver / parametrization / closed-curve tuning setters are no-ops; the
//     convergence and projection tolerance setters drive the 3D fit tolerance.
struct OCCTBSplineApproxInterp
{
  NCollection_Array1<gp_Pnt>     pts;
  int                            degMin = 3;
  int                            degMax = 8;
  double                         tol3D  = 1.0e-3;
  occ::handle<Geom_BSplineCurve> result;
  bool                           done   = false;
  double                         maxErr = -1.0;

  explicit OCCTBSplineApproxInterp(int count)
      : pts(1, count)
  {
  }

  void run()
  {
    try
    {
      GeomAPI_PointsToBSpline fit(pts, degMin, degMax, GeomAbs_C2, tol3D);
      result = fit.Curve();
      done   = !result.IsNull();
      maxErr = -1.0;
      if (done)
      {
        double mx = 0.0;
        for (NCollection_Array1<gp_Pnt>::Iterator it(pts); it.More(); it.Next())
        {
          GeomAPI_ProjectPointOnCurve proj(it.Value(), result);
          if (proj.NbPoints() > 0)
            mx = std::max(mx, proj.LowerDistance());
        }
        maxErr = mx;
      }
    }
    catch (...)
    {
      done = false;
      result.Nullify();
      maxErr = -1.0;
    }
  }
};

// Both of these share the whole-bridge arc-length measurement and its inverse rather than calling
// GCPnts directly, so an edge or a wire measured through EdgeCurve/WireCurve agrees with the same
// edge measured through Shape.edgeArcLength and with the curve it was built from. #603.
static double adaptorLength(Adaptor3d_Curve& a)
{
  return occtAdaptorArcLength(a, a.FirstParameter(), a.LastParameter());
}

static void adaptorParamRange(Adaptor3d_Curve& a, double* first, double* last)
{
  if (first)
    *first = a.FirstParameter();
  if (last)
    *last = a.LastParameter();
}

static bool adaptorPointAtParam(Adaptor3d_Curve& a, double u, double* x, double* y, double* z)
{
  gp_Pnt p = a.Value(u);
  if (x)
    *x = p.X();
  if (y)
    *y = p.Y();
  if (z)
    *z = p.Z();
  return true;
}

static bool adaptorTangentAtParam(Adaptor3d_Curve& a, double u, double* x, double* y, double* z)
{
  gp_Pnt p;
  gp_Vec d1;
  a.D1(u, p, d1);
  if (d1.Magnitude() < 1e-12)
    return false; // degenerate (e.g. cusp)
  gp_Dir dir(d1);
  if (x)
    *x = dir.X();
  if (y)
    *y = dir.Y();
  if (z)
    *z = dir.Z();
  return true;
}

static bool adaptorParamAtAbscissa(Adaptor3d_Curve& a, double s, double* outParam)
{
  double parameter = 0;
  if (!occtAdaptorParameterAtLength(a, s, a.FirstParameter(), parameter))
    return false;
  if (outParam)
    *outParam = parameter;
  return true;
}

// N points spaced equally by arc length along the curve. outXYZ must hold count*3 doubles;
// returns the number of points actually written.
static int32_t sampleAdaptorUniform(Adaptor3d_Curve& a, int32_t count, double* outXYZ)
{
  if (!occtValidSampleCount(count) || !outXYZ)
    return 0;
  GCPnts_UniformAbscissa sampler(a, count);
  if (!sampler.IsDone())
    return 0;
  // The sampler is not bounded by `count`. See occtSamplerKept/occtSamplerIndex (#501).
  int32_t total = sampler.NbPoints();
  int32_t n     = occtSamplerKept(total, count);
  for (int32_t i = 0; i < n; ++i)
  {
    gp_Pnt p          = a.Value(sampler.Parameter(occtSamplerIndex(i, n, total)));
    outXYZ[i * 3 + 0] = p.X();
    outXYZ[i * 3 + 1] = p.Y();
    outXYZ[i * 3 + 2] = p.Z();
  }
  return n;
}

// Opaque handle: holds the adaptor by value (BRepAdaptor_CompCurve(const TopoDS_Wire&)).
struct OCCTCompCurve
{
  BRepAdaptor_CompCurve adaptor;

  explicit OCCTCompCurve(const TopoDS_Wire& w)
      : adaptor(w)
  {
  }
};

struct OCCTEdgeCurve
{
  BRepAdaptor_Curve adaptor;

  explicit OCCTEdgeCurve(const TopoDS_Edge& e)
      : adaptor(e)
  {
  }
};

// MARK: - Approx_Curve3d (v0.46)
OCCTCurve3DRef OCCTEdgeApproxCurve(OCCTEdgeRef edge,
                                   double      tolerance,
                                   int32_t     maxSegments,
                                   int32_t     maxDegree)
{
  if (!occtShapeIsPresent(edge))
    return nullptr;
  try
  {
    BRepAdaptor_Curve adaptorCurve(edge->edge);
    Approx_Curve3d    approx(new BRepAdaptor_Curve(adaptorCurve),
                             tolerance,
                             GeomAbs_C2,
                             maxSegments,
                             maxDegree);
    if (!approx.IsDone() && !approx.HasResult())
      return nullptr;
    auto bspline = approx.Curve();
    if (bspline.IsNull())
      return nullptr;
    return new OCCTCurve3D(bspline);
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTLocalAnalysisCurveContinuity(OCCTCurve3DRef _Nonnull curve1,
                                      double u1,
                                      OCCTCurve3DRef _Nonnull curve2,
                                      double  u2,
                                      int32_t order,
                                      int32_t* _Nonnull outEffectiveOrder,
                                      double* _Nonnull outC0Value,
                                      double* _Nonnull outG1Angle,
                                      double* _Nonnull outC1Angle,
                                      double* _Nonnull outC1Ratio,
                                      double* _Nonnull outC2Angle,
                                      double* _Nonnull outC2Ratio,
                                      double* _Nonnull outG2Angle,
                                      double* _Nonnull outG2CurvatureVariation)
{
  try
  {
    auto c1 = (OCCTCurve3D*)curve1;
    auto c2 = (OCCTCurve3D*)curve2;
    if (!c1 || c1->curve.IsNull() || !c2 || c2->curve.IsNull())
      return false;

    const GeomAbs_Shape effective = occtGeomAbsFromAnalysisOrder(order);
    const int32_t       measured  = occtAnalysisMeasuredMask(effective);

    LocalAnalysis_CurveContinuity cc(c1->curve, u1, c2->curve, u2, effective);
    if (!cc.IsDone())
      return false;

    // ContinuityStatus() returns the order the analyser was constructed with, verbatim: it
    // is the request echoed back, not a measurement. Reported as the *effective* order so a
    // caller can see where a saturated request landed.
    *outEffectiveOrder       = occtAnalysisOrderFromGeomAbs(cc.ContinuityStatus());
    *outC0Value              = cc.C0Value();
    *outG1Angle              = ((measured & 0x02) && cc.IsG1()) ? cc.G1Angle() : -1.0;
    *outC1Angle              = ((measured & 0x04) && cc.IsC1()) ? cc.C1Angle() : -1.0;
    *outC1Ratio              = ((measured & 0x04) && cc.IsC1()) ? cc.C1Ratio() : -1.0;
    *outC2Angle              = ((measured & 0x10) && cc.IsC2()) ? cc.C2Angle() : -1.0;
    *outC2Ratio              = ((measured & 0x10) && cc.IsC2()) ? cc.C2Ratio() : -1.0;
    *outG2Angle              = ((measured & 0x08) && cc.IsG2()) ? cc.G2Angle() : -1.0;
    *outG2CurvatureVariation = ((measured & 0x08) && cc.IsG2()) ? cc.G2CurvatureVariation() : -1.0;
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTLocalAnalysisCurveContinuityFlags(OCCTCurve3DRef _Nonnull curve1,
                                              double u1,
                                              OCCTCurve3DRef _Nonnull curve2,
                                              double  u2,
                                              int32_t order,
                                              int32_t* _Nonnull outMeasured)
{
  *outMeasured = 0;
  try
  {
    auto c1 = (OCCTCurve3D*)curve1;
    auto c2 = (OCCTCurve3D*)curve2;
    if (!c1 || c1->curve.IsNull() || !c2 || c2->curve.IsNull())
      return 0;

    const GeomAbs_Shape effective = occtGeomAbsFromAnalysisOrder(order);
    const int32_t       measured  = occtAnalysisMeasuredMask(effective);

    LocalAnalysis_CurveContinuity cc(c1->curve, u1, c2->curve, u2, effective);
    if (!cc.IsDone())
      return 0;

    int32_t flags = 0;
    if (cc.IsC0())
      flags |= 1;
    if (cc.IsG1())
      flags |= 2;
    if (cc.IsC1())
      flags |= 4;
    if (cc.IsG2())
      flags |= 8;
    if (cc.IsC2())
      flags |= 16;
    *outMeasured = measured;
    return flags & measured;
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - GeomLib_Tool Param3D (v0.77)
bool OCCTGeomLibToolParameter3D(OCCTCurve3DRef _Nonnull curveRef,
                                double px,
                                double py,
                                double pz,
                                double maxDist,
                                double* _Nonnull outParam)
{
  try
  {
    auto&  curve = reinterpret_cast<OCCTCurve3D*>(curveRef)->curve;
    double param = 0;
    bool   ok    = GeomLib_Tool::Parameter(curve, gp_Pnt(px, py, pz), maxDist, param);
    if (ok)
      *outParam = param;
    return ok;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTGeomLibCheckBSpline3D(OCCTCurve3DRef _Nonnull curveRef,
                               double tolerance,
                               double angularTol,
                               bool* _Nonnull needFixFirst,
                               bool* _Nonnull needFixLast)
{
  try
  {
    auto&                     curve = reinterpret_cast<OCCTCurve3D*>(curveRef)->curve;
    Handle(Geom_BSplineCurve) bsp   = Handle(Geom_BSplineCurve)::DownCast(curve);
    if (bsp.IsNull())
      return false;
    // Do not gate on IsDone(): myDone is only ever set true by the constructor's trivial
    // early-exit branch (periodic curve, or fewer than 4 poles) or by FixTangentOnCurve(). Along
    // the real analysis branch (an ordinary non-periodic curve with 4+ poles), myDone is never
    // touched, even though myFixFirstTangent/myFixLastTangent are correctly computed there.
    // OCCT's own internal caller (TopOpeBRepTool_CurveTool.cxx) never checks IsDone() either,
    // it goes straight to NeedTangentFix, matching OCCTGeomLibFixBSpline3D below. #1457.
    GeomLib_CheckBSplineCurve checker(bsp, tolerance, angularTol);
    bool                      f = false, l = false;
    checker.NeedTangentFix(f, l);
    *needFixFirst = f;
    *needFixLast  = l;
    return true;
  }
  catch (...)
  {
    return false;
  }
}

OCCTCurve3DRef _Nullable OCCTGeomLibFixBSpline3D(OCCTCurve3DRef _Nonnull curveRef,
                                                 double tolerance,
                                                 double angularTol,
                                                 bool   fixFirst,
                                                 bool   fixLast)
{
  try
  {
    auto&                     curve = reinterpret_cast<OCCTCurve3D*>(curveRef)->curve;
    Handle(Geom_BSplineCurve) bsp   = Handle(Geom_BSplineCurve)::DownCast(curve);
    if (bsp.IsNull())
      return nullptr;
    GeomLib_CheckBSplineCurve checker(bsp, tolerance, angularTol);
    Handle(Geom_BSplineCurve) fixed = checker.FixedTangent(fixFirst, fixLast);
    if (fixed.IsNull())
      return nullptr;
    return reinterpret_cast<OCCTCurve3DRef>(new OCCTCurve3D{fixed});
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef _Nullable OCCTGeomLibInterpolate(int degree,
                                                int numPoints,
                                                const double* _Nonnull pointsXYZ,
                                                const double* _Nonnull parameters)
{
  try
  {
    NCollection_Array1<gp_Pnt> pts(1, numPoints);
    NCollection_Array1<double> params(1, numPoints);
    for (int i = 0; i < numPoints; i++)
    {
      pts(i + 1)    = gp_Pnt(pointsXYZ[i * 3], pointsXYZ[i * 3 + 1], pointsXYZ[i * 3 + 2]);
      params(i + 1) = parameters[i];
    }
    GeomLib_Interpolate interp(degree, numPoints, pts, params);
    if (!interp.IsDone())
      return nullptr;
    Handle(Geom_BSplineCurve) curve = interp.Curve();
    if (curve.IsNull())
      return nullptr;
    return reinterpret_cast<OCCTCurve3DRef>(new OCCTCurve3D{curve});
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTApproxSameParameter(OCCTCurve3DRef _Nonnull curve3dRef,
                             OCCTCurve2DRef _Nonnull curve2dRef,
                             OCCTSurfaceRef _Nonnull surfRef,
                             double tolerance,
                             bool* _Nonnull outIsSame,
                             double* _Nonnull outTolReached)
{
  try
  {
    auto&                c3d  = reinterpret_cast<OCCTCurve3D*>(curve3dRef)->curve;
    auto&                c2d  = reinterpret_cast<OCCTCurve2D*>(curve2dRef)->curve;
    auto&                surf = reinterpret_cast<OCCTSurface*>(surfRef)->surface;
    Approx_SameParameter checker(c3d, c2d, surf, tolerance);
    if (!checker.IsDone())
      return false;
    *outIsSame     = checker.IsSameParameter();
    *outTolReached = checker.TolReached();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTLogSample(double a, double b, int32_t n, double* params)
{
  try
  {
    GeomLib_LogSample sampler(a, b, n);
    for (int32_t i = 1; i <= n; i++)
    {
      params[i - 1] = sampler.GetParameter(i);
    }
  }
  catch (...)
  {
    for (int32_t i = 0; i < n; i++)
      params[i] = 0;
  }
}

void OCCTGeomEvalCircularHelixD0(double  radius,
                                 double  pitch,
                                 double  u,
                                 double* px,
                                 double* py,
                                 double* pz)
{
  try
  {
    gp_Ax2                      ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    GeomEval_CircularHelixCurve helix(ax, radius, pitch);
    gp_Pnt                      p = helix.EvalD0(u);
    *px                           = p.X();
    *py                           = p.Y();
    *pz                           = p.Z();
  }
  catch (...)
  {
  }
}

void OCCTGeomEvalCircularHelixD1(double  radius,
                                 double  pitch,
                                 double  u,
                                 double* px,
                                 double* py,
                                 double* pz,
                                 double* vx,
                                 double* vy,
                                 double* vz)
{
  try
  {
    gp_Ax2                      ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    GeomEval_CircularHelixCurve helix(ax, radius, pitch);
    auto                        res = helix.EvalD1(u);
    *px                             = res.Point.X();
    *py                             = res.Point.Y();
    *pz                             = res.Point.Z();
    *vx                             = res.D1.X();
    *vy                             = res.D1.Y();
    *vz                             = res.D1.Z();
  }
  catch (...)
  {
  }
}

void OCCTGeomEvalCircularHelixD2(double  radius,
                                 double  pitch,
                                 double  u,
                                 double* px,
                                 double* py,
                                 double* pz,
                                 double* d1x,
                                 double* d1y,
                                 double* d1z,
                                 double* d2x,
                                 double* d2y,
                                 double* d2z)
{
  try
  {
    gp_Ax2                      ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    GeomEval_CircularHelixCurve helix(ax, radius, pitch);
    auto                        res = helix.EvalD2(u);
    *px                             = res.Point.X();
    *py                             = res.Point.Y();
    *pz                             = res.Point.Z();
    *d1x                            = res.D1.X();
    *d1y                            = res.D1.Y();
    *d1z                            = res.D1.Z();
    *d2x                            = res.D2.X();
    *d2y                            = res.D2.Y();
    *d2z                            = res.D2.Z();
  }
  catch (...)
  {
  }
}

OCCTCurve3DRef OCCTGeomEvalCircularHelixCurveCreate(double radius, double pitch)
{
  try
  {
    gp_Ax2                  ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    auto                    helix = new GeomEval_CircularHelixCurve(ax, radius, pitch);
    occ::handle<Geom_Curve> hCurve(helix);
    auto                    ref = new OCCTCurve3D();
    ref->curve                  = hCurve;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTGeomEvalSineWaveD0(double  amplitude,
                            double  omega,
                            double  phase,
                            double  u,
                            double* px,
                            double* py,
                            double* pz)
{
  try
  {
    gp_Ax2                 ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    GeomEval_SineWaveCurve sw(ax, amplitude, omega, phase);
    gp_Pnt                 p = sw.EvalD0(u);
    *px                      = p.X();
    *py                      = p.Y();
    *pz                      = p.Z();
  }
  catch (...)
  {
  }
}

void OCCTGeomEvalSineWaveD1(double  amplitude,
                            double  omega,
                            double  phase,
                            double  u,
                            double* px,
                            double* py,
                            double* pz,
                            double* vx,
                            double* vy,
                            double* vz)
{
  try
  {
    gp_Ax2                 ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    GeomEval_SineWaveCurve sw(ax, amplitude, omega, phase);
    auto                   res = sw.EvalD1(u);
    *px                        = res.Point.X();
    *py                        = res.Point.Y();
    *pz                        = res.Point.Z();
    *vx                        = res.D1.X();
    *vy                        = res.D1.Y();
    *vz                        = res.D1.Z();
  }
  catch (...)
  {
  }
}

OCCTCurve3DRef OCCTGeomEvalSineWaveCurveCreate(double amplitude, double omega, double phase)
{
  try
  {
    gp_Ax2                  ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    auto                    sw = new GeomEval_SineWaveCurve(ax, amplitude, omega, phase);
    occ::handle<Geom_Curve> hCurve(sw);
    auto                    ref = new OCCTCurve3D();
    ref->curve                  = hCurve;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTGeomEvalTBezierCurveCreate(const double* poles, int32_t count, double alpha)
{
  if (!poles || count < 3 || count % 2 == 0)
    return nullptr;
  try
  {
    NCollection_Array1<gp_Pnt> pts(1, count);
    for (int i = 0; i < count; i++)
      pts(i + 1) = gp_Pnt(poles[i * 3], poles[i * 3 + 1], poles[i * 3 + 2]);
    auto                    tc = new GeomEval_TBezierCurve(pts, alpha);
    occ::handle<Geom_Curve> hCurve(tc);
    auto                    ref = new OCCTCurve3D();
    ref->curve                  = hCurve;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTGeomEvalTBezierCurveCreateRational(const double* poles,
                                                      const double* weights,
                                                      int32_t       count,
                                                      double        alpha)
{
  if (!poles || !weights || count < 3 || count % 2 == 0)
    return nullptr;
  try
  {
    NCollection_Array1<gp_Pnt> pts(1, count);
    NCollection_Array1<double> wts(1, count);
    for (int i = 0; i < count; i++)
    {
      pts(i + 1) = gp_Pnt(poles[i * 3], poles[i * 3 + 1], poles[i * 3 + 2]);
      wts(i + 1) = weights[i];
    }
    auto                    tc = new GeomEval_TBezierCurve(pts, wts, alpha);
    occ::handle<Geom_Curve> hCurve(tc);
    auto                    ref = new OCCTCurve3D();
    ref->curve                  = hCurve;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTGeomEvalAHTBezierCurveCreate(const double* poles,
                                                int32_t       count,
                                                int32_t       algDegree,
                                                double        alpha,
                                                double        beta)
{
  if (!poles || count < 1)
    return nullptr;
  try
  {
    NCollection_Array1<gp_Pnt> pts(1, count);
    for (int i = 0; i < count; i++)
      pts(i + 1) = gp_Pnt(poles[i * 3], poles[i * 3 + 1], poles[i * 3 + 2]);
    auto                    ac = new GeomEval_AHTBezierCurve(pts, algDegree, alpha, beta);
    occ::handle<Geom_Curve> hCurve(ac);
    auto                    ref = new OCCTCurve3D();
    ref->curve                  = hCurve;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTGeomEvalAHTBezierCurveCreateRational(const double* poles,
                                                        const double* weights,
                                                        int32_t       count,
                                                        int32_t       algDegree,
                                                        double        alpha,
                                                        double        beta)
{
  if (!poles || !weights || count < 1)
    return nullptr;
  try
  {
    NCollection_Array1<gp_Pnt> pts(1, count);
    NCollection_Array1<double> wts(1, count);
    for (int i = 0; i < count; i++)
    {
      pts(i + 1) = gp_Pnt(poles[i * 3], poles[i * 3 + 1], poles[i * 3 + 2]);
      wts(i + 1) = weights[i];
    }
    auto                    ac = new GeomEval_AHTBezierCurve(pts, wts, algDegree, alpha, beta);
    occ::handle<Geom_Curve> hCurve(ac);
    auto                    ref = new OCCTCurve3D();
    ref->curve                  = hCurve;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}
