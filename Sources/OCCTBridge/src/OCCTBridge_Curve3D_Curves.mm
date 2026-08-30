//
//  OCCTBridge_Curve3D_Curves.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Curve3D.mm (#1380): Geom_*
//  (Circle/Ellipse/Hyperbola/Parabola/Line/OffsetCurve/BSpline/Bezier/TrimmedCurve),
//  CartesianPoint/Direction/Vector/Axis1+2/Transformation, gp_Quaternion, ElCLib -- default_bucket.
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
  if (!shape)
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

void OCCTCurve3DRelease(OCCTCurve3DRef c)
{
  delete c;
}

OCCTCurve3DRef OCCTEdgeGetCurve3D(OCCTEdgeRef edge)
{
  if (!occtShapeIsPresent(edge))
    return nullptr;
  try
  {
    BRepLib::BuildCurves3d(edge->edge);
    Standard_Real      first, last;
    Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, first, last);
    if (curve.IsNull())
      return nullptr;
    // Return the raw curve so consumers can DownCast to Geom_Circle /
    // Geom_Line / etc. for typed-property extraction. The edge's
    // parameter range stays available via Edge.parameterBounds.
    return new OCCTCurve3D(curve);
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTCurve3DGetDomain(OCCTCurve3DRef c, double* first, double* last)
{
  if (!c || c->curve.IsNull() || !first || !last)
    return;
  *first = c->curve->FirstParameter();
  *last  = c->curve->LastParameter();
}

bool OCCTCurve3DIsClosed(OCCTCurve3DRef c)
{
  if (!c || c->curve.IsNull())
    return false;
  return c->curve->IsClosed() == Standard_True;
}

bool OCCTCurve3DIsPeriodic(OCCTCurve3DRef c)
{
  if (!c || c->curve.IsNull())
    return false;
  return c->curve->IsPeriodic() == Standard_True;
}

double OCCTCurve3DGetPeriod(OCCTCurve3DRef c)
{
  if (!c || c->curve.IsNull())
    return 0.0;
  if (!c->curve->IsPeriodic())
    return 0.0;
  return c->curve->Period();
}

void OCCTCurve3DGetPoint(OCCTCurve3DRef c, double u, double* x, double* y, double* z)
{
  if (!c || c->curve.IsNull() || !x || !y || !z)
    return;
  gp_Pnt p = c->curve->Value(u);
  *x       = p.X();
  *y       = p.Y();
  *z       = p.Z();
}

void OCCTCurve3DD1(OCCTCurve3DRef c,
                   double         u,
                   double*        px,
                   double*        py,
                   double*        pz,
                   double*        vx,
                   double*        vy,
                   double*        vz)
{
  if (!c || c->curve.IsNull() || !px || !py || !pz || !vx || !vy || !vz)
    return;
  try
  {
    gp_Pnt p;
    gp_Vec v;
    c->curve->D1(u, p, v);
    *px = p.X();
    *py = p.Y();
    *pz = p.Z();
    *vx = v.X();
    *vy = v.Y();
    *vz = v.Z();
  }
  catch (...)
  {
  }
}

void OCCTCurve3DD2(OCCTCurve3DRef c,
                   double         u,
                   double*        px,
                   double*        py,
                   double*        pz,
                   double*        v1x,
                   double*        v1y,
                   double*        v1z,
                   double*        v2x,
                   double*        v2y,
                   double*        v2z)
{
  if (!c || c->curve.IsNull() || !px || !py || !pz || !v1x || !v1y || !v1z || !v2x || !v2y || !v2z)
    return;
  try
  {
    gp_Pnt p;
    gp_Vec v1, v2;
    c->curve->D2(u, p, v1, v2);
    *px  = p.X();
    *py  = p.Y();
    *pz  = p.Z();
    *v1x = v1.X();
    *v1y = v1.Y();
    *v1z = v1.Z();
    *v2x = v2.X();
    *v2y = v2.Y();
    *v2z = v2.Z();
  }
  catch (...)
  {
  }
}

OCCTCurve3DRef OCCTCurve3DCreateLine(double px,
                                     double py,
                                     double pz,
                                     double dx,
                                     double dy,
                                     double dz)
{
  try
  {
    gp_Pnt            origin(px, py, pz);
    gp_Dir            dir(dx, dy, dz);
    Handle(Geom_Line) line = new Geom_Line(origin, dir);
    return new OCCTCurve3D(line);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTCurve3DCreateCircle(double cx,
                                       double cy,
                                       double cz,
                                       double nx,
                                       double ny,
                                       double nz,
                                       double radius)
{
  try
  {
    if (!occtValidCircleRadius(radius))
      return nullptr;
    gp_Pnt              center(cx, cy, cz);
    gp_Dir              normal(nx, ny, nz);
    gp_Ax2              axis(center, normal);
    Handle(Geom_Circle) circle = new Geom_Circle(axis, radius);
    return new OCCTCurve3D(circle);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTCurve3DCreateEllipse(double cx,
                                        double cy,
                                        double cz,
                                        double nx,
                                        double ny,
                                        double nz,
                                        double majorR,
                                        double minorR)
{
  try
  {
    if (!occtValidEllipseRadii(majorR, minorR))
      return nullptr;
    gp_Ax2               axis(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
    Handle(Geom_Ellipse) ellipse = new Geom_Ellipse(axis, majorR, minorR);
    return new OCCTCurve3D(ellipse);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTCurve3DCreateParabola(double cx,
                                         double cy,
                                         double cz,
                                         double nx,
                                         double ny,
                                         double nz,
                                         double focal)
{
  try
  {
    if (!occtValidParabolaFocal(focal))
      return nullptr;
    gp_Ax2                axis(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
    Handle(Geom_Parabola) parabola = new Geom_Parabola(axis, focal);
    return new OCCTCurve3D(parabola);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTCurve3DCreateHyperbola(double cx,
                                          double cy,
                                          double cz,
                                          double nx,
                                          double ny,
                                          double nz,
                                          double majorR,
                                          double minorR)
{
  try
  {
    if (!occtValidHyperbolaRadii(majorR, minorR))
      return nullptr;
    gp_Ax2                 axis(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
    Handle(Geom_Hyperbola) hyp = new Geom_Hyperbola(axis, majorR, minorR);
    return new OCCTCurve3D(hyp);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTCurve3DCreateBSpline(const double*  poles,
                                        int32_t        poleCount,
                                        const double*  weights,
                                        const double*  knots,
                                        int32_t        knotCount,
                                        const int32_t* multiplicities,
                                        int32_t        degree)
{
  try
  {
    if (!poles || poleCount < 2 || !knots || knotCount < 2 || !multiplicities || degree < 1)
      return nullptr;

    TColgp_Array1OfPnt pArr(1, poleCount);
    for (int i = 0; i < poleCount; i++)
      pArr.SetValue(i + 1, gp_Pnt(poles[i * 3], poles[i * 3 + 1], poles[i * 3 + 2]));

    TColStd_Array1OfReal kArr(1, knotCount);
    for (int i = 0; i < knotCount; i++)
      kArr.SetValue(i + 1, knots[i]);

    TColStd_Array1OfInteger mArr(1, knotCount);
    for (int i = 0; i < knotCount; i++)
      mArr.SetValue(i + 1, multiplicities[i]);

    Handle(Geom_BSplineCurve) bsp;
    if (weights)
    {
      TColStd_Array1OfReal wArr(1, poleCount);
      for (int i = 0; i < poleCount; i++)
        wArr.SetValue(i + 1, weights[i]);
      bsp = new Geom_BSplineCurve(pArr, wArr, kArr, mArr, degree);
    }
    else
    {
      bsp = new Geom_BSplineCurve(pArr, kArr, mArr, degree);
    }
    return new OCCTCurve3D(bsp);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTCurve3DCreateBezier(const double* poles,
                                       int32_t       poleCount,
                                       const double* weights)
{
  try
  {
    if (!poles || poleCount < 2)
      return nullptr;

    TColgp_Array1OfPnt pArr(1, poleCount);
    for (int i = 0; i < poleCount; i++)
      pArr.SetValue(i + 1, gp_Pnt(poles[i * 3], poles[i * 3 + 1], poles[i * 3 + 2]));

    Handle(Geom_BezierCurve) bez;
    if (weights)
    {
      TColStd_Array1OfReal wArr(1, poleCount);
      for (int i = 0; i < poleCount; i++)
        wArr.SetValue(i + 1, weights[i]);
      bez = new Geom_BezierCurve(pArr, wArr);
    }
    else
    {
      bez = new Geom_BezierCurve(pArr);
    }
    return new OCCTCurve3D(bez);
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTCurve3DGetPoleCount(OCCTCurve3DRef c)
{
  if (!c || c->curve.IsNull())
    return 0;
  try
  {
    Handle(Geom_BSplineCurve) bsp = Handle(Geom_BSplineCurve)::DownCast(c->curve);
    if (!bsp.IsNull())
      return bsp->NbPoles();
    Handle(Geom_BezierCurve) bez = Handle(Geom_BezierCurve)::DownCast(c->curve);
    if (!bez.IsNull())
      return bez->NbPoles();
    return 0;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTCurve3DGetPoles(OCCTCurve3DRef c, double* outXYZ)
{
  if (!c || c->curve.IsNull() || !outXYZ)
    return 0;
  try
  {
    Handle(Geom_BSplineCurve) bsp = Handle(Geom_BSplineCurve)::DownCast(c->curve);
    if (!bsp.IsNull())
    {
      int n = bsp->NbPoles();
      for (int i = 1; i <= n; i++)
      {
        gp_Pnt p                = bsp->Pole(i);
        outXYZ[(i - 1) * 3]     = p.X();
        outXYZ[(i - 1) * 3 + 1] = p.Y();
        outXYZ[(i - 1) * 3 + 2] = p.Z();
      }
      return n;
    }
    Handle(Geom_BezierCurve) bez = Handle(Geom_BezierCurve)::DownCast(c->curve);
    if (!bez.IsNull())
    {
      int n = bez->NbPoles();
      for (int i = 1; i <= n; i++)
      {
        gp_Pnt p                = bez->Pole(i);
        outXYZ[(i - 1) * 3]     = p.X();
        outXYZ[(i - 1) * 3 + 1] = p.Y();
        outXYZ[(i - 1) * 3 + 2] = p.Z();
      }
      return n;
    }
    return 0;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTCurve3DGetDegree(OCCTCurve3DRef c)
{
  if (!c || c->curve.IsNull())
    return -1;
  try
  {
    Handle(Geom_BSplineCurve) bsp = Handle(Geom_BSplineCurve)::DownCast(c->curve);
    if (!bsp.IsNull())
      return bsp->Degree();
    Handle(Geom_BezierCurve) bez = Handle(Geom_BezierCurve)::DownCast(c->curve);
    if (!bez.IsNull())
      return bez->Degree();
    return -1;
  }
  catch (...)
  {
    return -1;
  }
}

OCCTCurve3DRef OCCTCurve3DTrim(OCCTCurve3DRef c, double u1, double u2)
{
  if (!c || c->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_TrimmedCurve) trimmed = new Geom_TrimmedCurve(c->curve, u1, u2);
    return new OCCTCurve3D(trimmed);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTCurve3DReversed(OCCTCurve3DRef c)
{
  if (!c || c->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_Curve) rev = Handle(Geom_Curve)::DownCast(c->curve->Reversed());
    if (rev.IsNull())
      return nullptr;
    return new OCCTCurve3D(rev);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTCurve3DTranslate(OCCTCurve3DRef c, double dx, double dy, double dz)
{
  if (!c || c->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_Curve) copy = Handle(Geom_Curve)::DownCast(c->curve->Copy());
    gp_Trsf            t;
    if (!occtBuildTrsf3D(t, 0, dx, dy, dz, 0, 0, 0, 0))
      return nullptr;
    copy->Transform(t);
    return new OCCTCurve3D(copy);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTCurve3DRotate(OCCTCurve3DRef c,
                                 double         axisOx,
                                 double         axisOy,
                                 double         axisOz,
                                 double         axisDx,
                                 double         axisDy,
                                 double         axisDz,
                                 double         angle)
{
  if (!c || c->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_Curve) copy = Handle(Geom_Curve)::DownCast(c->curve->Copy());
    gp_Trsf            t;
    if (!occtBuildTrsf3D(t, 1, axisOx, axisOy, axisOz, axisDx, axisDy, axisDz, angle))
      return nullptr;
    copy->Transform(t);
    return new OCCTCurve3D(copy);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTCurve3DScale(OCCTCurve3DRef c, double cx, double cy, double cz, double factor)
{
  if (!c || c->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_Curve) copy = Handle(Geom_Curve)::DownCast(c->curve->Copy());
    gp_Trsf            t;
    if (!occtBuildTrsf3D(t, 2, cx, cy, cz, factor, 0, 0, 0))
      return nullptr;
    copy->Transform(t);
    return new OCCTCurve3D(copy);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTCurve3DMirrorPoint(OCCTCurve3DRef c, double px, double py, double pz)
{
  if (!c || c->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_Curve) copy = Handle(Geom_Curve)::DownCast(c->curve->Copy());
    gp_Trsf            t;
    if (!occtBuildTrsf3D(t, 3, px, py, pz, 0, 0, 0, 0))
      return nullptr;
    copy->Transform(t);
    return new OCCTCurve3D(copy);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTCurve3DMirrorAxis(OCCTCurve3DRef c,
                                     double         px,
                                     double         py,
                                     double         pz,
                                     double         dx,
                                     double         dy,
                                     double         dz)
{
  if (!c || c->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_Curve) copy = Handle(Geom_Curve)::DownCast(c->curve->Copy());
    gp_Trsf            t;
    if (!occtBuildTrsf3D(t, 4, px, py, pz, dx, dy, dz, 0))
      return nullptr;
    copy->Transform(t);
    return new OCCTCurve3D(copy);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTCurve3DMirrorPlane(OCCTCurve3DRef c,
                                      double         px,
                                      double         py,
                                      double         pz,
                                      double         nx,
                                      double         ny,
                                      double         nz)
{
  if (!c || c->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_Curve) copy = Handle(Geom_Curve)::DownCast(c->curve->Copy());
    gp_Trsf            t;
    if (!occtBuildTrsf3D(t, 5, px, py, pz, nx, ny, nz, 0))
      return nullptr;
    copy->Transform(t);
    return new OCCTCurve3D(copy);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTCurve3DToBSpline(OCCTCurve3DRef c)
{
  if (!c || c->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_BSplineCurve) bsp = GeomConvert::CurveToBSplineCurve(c->curve);
    if (bsp.IsNull())
      return nullptr;
    return new OCCTCurve3D(bsp);
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTCurve3DFreeArray(OCCTCurve3DRef* curves, int32_t count)
{
  if (!curves)
    return;
  for (int32_t i = 0; i < count; i++)
  {
    delete curves[i];
    curves[i] = nullptr;
  }
}

OCCTCurve3DRef OCCTCurve3DApproximate(OCCTCurve3DRef c,
                                      double         tolerance,
                                      int32_t        continuity,
                                      int32_t        maxSegments,
                                      int32_t        maxDegree)
{
  return occtApproxCurve(c, tolerance, continuity, maxSegments, maxDegree).curve;
}

// #595: the curvature is reported alongside whether there is one, rather than spelled 0 when there
// is not. A straight curve's curvature is exactly 0 with the tangent perfectly well defined, so the
// old encoding could not tell a line from a curve with no derivatives at all. See
// Scripts/repro/595-curvature-zero-sentinel/. A cusp is NOT an absence: OCCT reports RealLast()
// there, meaning infinite, and that sentinel passes through unchanged.
bool OCCTCurve3DGetCurvature(OCCTCurve3DRef c, double u, double* curvature)
{
  *curvature = 0.0;
  if (!c || c->curve.IsNull())
    return false;
  try
  {
    GeomLProp_CLProps props = occtCurveLocalProps(c->curve, u, 2);
    if (!props.IsTangentDefined())
      return false;
    *curvature = props.Curvature();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DGetTangent(OCCTCurve3DRef c, double u, double* tx, double* ty, double* tz)
{
  if (!c || c->curve.IsNull() || !tx || !ty || !tz)
    return false;
  try
  {
    GeomLProp_CLProps props = occtCurveLocalProps(c->curve, u, 1);
    if (!props.IsTangentDefined())
      return false;
    gp_Dir dir;
    props.Tangent(dir);
    *tx = dir.X();
    *ty = dir.Y();
    *tz = dir.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DGetNormal(OCCTCurve3DRef c, double u, double* nx, double* ny, double* nz)
{
  if (!c || c->curve.IsNull() || !nx || !ny || !nz)
    return false;
  try
  {
    GeomLProp_CLProps props = occtCurveLocalProps(c->curve, u, 2);
    if (!props.IsTangentDefined())
      return false;
    gp_Dir dir;
    props.Normal(dir);
    *nx = dir.X();
    *ny = dir.Y();
    *nz = dir.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DGetCenterOfCurvature(OCCTCurve3DRef c, double u, double* cx, double* cy, double* cz)
{
  if (!c || c->curve.IsNull() || !cx || !cy || !cz)
    return false;
  try
  {
    GeomLProp_CLProps props = occtCurveLocalProps(c->curve, u, 2);
    if (!props.IsTangentDefined())
      return false;
    // Rejects a cusp's RealLast() curvature as well as a straight stretch's zero; the plain
    // "is it big enough" test this used to make let the sentinel through, and OCCT then handed
    // back (nan, inf, nan) as a successfully computed centre (#494).
    if (!occtCurveCurvatureIsInvertible(props.Curvature()))
      return false;
    gp_Pnt center;
    props.CentreOfCurvature(center);
    *cx = center.X();
    *cy = center.Y();
    *cz = center.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// #595: torsion is only defined where the curve has an osculating plane to twist out of, and the
// same 0 used to mean both "it does not" and "it does, and the curve lies flat in it". Every planar
// curve -- every circle and ellipse in the suite -- reports a real torsion of exactly 0, so that
// collision is as ordinary as the curvature one a few functions above.
bool OCCTCurve3DGetTorsion(OCCTCurve3DRef c, double u, double* torsion)
{
  *torsion = 0.0;
  if (!c || c->curve.IsNull())
    return false;
  try
  {
    gp_Pnt pnt;
    gp_Vec d1, d2, d3;
    c->curve->D3(u, pnt, d1, d2, d3);

    gp_Vec cross     = d1.Crossed(d2);
    double crossMag2 = cross.SquareMagnitude();
    if (crossMag2 < Precision::Confusion())
      return false;
    *torsion = cross.Dot(d3) / crossMag2;
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTCurve3DEvaluateGrid(OCCTCurve3DRef curve,
                                const double*  params,
                                int32_t        paramCount,
                                double*        outXYZ)
{
  if (!curve || curve->curve.IsNull() || !params || !outXYZ || paramCount <= 0)
    return 0;
  try
  {
    GeomGridEval_Curve         evaluator(curve->curve);
    NCollection_Array1<double> paramArr = occtGridEvalParams(params, paramCount);

    NCollection_Array1<gp_Pnt> results = evaluator.EvaluateGrid(paramArr);
    // Defensive: bound the write by the caller's buffer as well as by what OCCT returned.
    // Every evaluator in the pinned kernel returns exactly theParams.Length() or an empty
    // array (empty only for a null curve or empty params, both rejected above), so neither
    // direction is reachable today. Taking the min covers both anyway: a shorter result must
    // not be read past its end, and a longer one must not be written past outXYZ's end.
    int32_t n = std::min(paramCount, static_cast<int32_t>(results.Size()));
    for (int32_t i = 0; i < n; i++)
    {
      const gp_Pnt& pt  = results.Value(i + 1);
      outXYZ[i * 3]     = pt.X();
      outXYZ[i * 3 + 1] = pt.Y();
      outXYZ[i * 3 + 2] = pt.Z();
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTCurve3DEvaluateGridD1(OCCTCurve3DRef curve,
                                  const double*  params,
                                  int32_t        paramCount,
                                  double*        outXYZ,
                                  double*        outDXDYDZ)
{
  if (!curve || curve->curve.IsNull() || !params || !outXYZ || !outDXDYDZ || paramCount <= 0)
    return 0;
  try
  {
    GeomGridEval_Curve         evaluator(curve->curve);
    NCollection_Array1<double> paramArr = occtGridEvalParams(params, paramCount);

    NCollection_Array1<GeomGridEval::CurveD1> results = evaluator.EvaluateGridD1(paramArr);
    int32_t n = std::min(paramCount, static_cast<int32_t>(results.Size())); // see EvaluateGrid
    for (int32_t i = 0; i < n; i++)
    {
      const GeomGridEval::CurveD1& r = results.Value(i + 1);
      outXYZ[i * 3]                  = r.Point.X();
      outXYZ[i * 3 + 1]              = r.Point.Y();
      outXYZ[i * 3 + 2]              = r.Point.Z();
      outDXDYDZ[i * 3]               = r.D1.X();
      outDXDYDZ[i * 3 + 1]           = r.D1.Y();
      outDXDYDZ[i * 3 + 2]           = r.D1.Z();
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - Curve3D ConvertToPeriodic / SplitAt (v0.50)
OCCTCurve3DRef OCCTCurve3DConvertToPeriodic(OCCTCurve3DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return nullptr;
  try
  {
    ShapeCustom_Curve  scc(curve->curve);
    Handle(Geom_Curve) periodic = scc.ConvertToPeriodic(Standard_False);
    if (periodic.IsNull())
      return nullptr;
    auto* ref  = new OCCTCurve3D();
    ref->curve = periodic;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

// Both curve approximation entry points share occtApproxCurve, declared next to
// OCCTCurve3DApproximate above; see the #491 note there for why the gate is HasResult().
OCCTApproxCurveResult OCCTGeomConvertApproxCurve(OCCTCurve3DRef _Nonnull curve,
                                                 double  tolerance,
                                                 int32_t continuity,
                                                 int32_t maxSegments,
                                                 int32_t maxDegree)
{
  return occtApproxCurve(curve, tolerance, continuity, maxSegments, maxDegree);
}

OCCTGeomPoint3DRef _Nonnull OCCTGeomPoint3DCreate(double x, double y, double z)
{
  auto* ref  = new OCCTGeomPoint3D();
  ref->point = new Geom_CartesianPoint(x, y, z);
  return ref;
}

void OCCTGeomPoint3DRelease(OCCTGeomPoint3DRef _Nonnull ref)
{
  delete ref;
}

double OCCTGeomPoint3DX(OCCTGeomPoint3DRef _Nonnull ref)
{
  return ref->point->X();
}

double OCCTGeomPoint3DY(OCCTGeomPoint3DRef _Nonnull ref)
{
  return ref->point->Y();
}

double OCCTGeomPoint3DZ(OCCTGeomPoint3DRef _Nonnull ref)
{
  return ref->point->Z();
}

void OCCTGeomPoint3DSetCoord(OCCTGeomPoint3DRef _Nonnull ref, double x, double y, double z)
{
  ref->point->SetCoord(x, y, z);
}

double OCCTGeomPoint3DDistance(OCCTGeomPoint3DRef _Nonnull ref, OCCTGeomPoint3DRef _Nonnull other)
{
  return ref->point->Distance(other->point);
}

double OCCTGeomPoint3DSquareDistance(OCCTGeomPoint3DRef _Nonnull ref,
                                     OCCTGeomPoint3DRef _Nonnull other)
{
  return ref->point->SquareDistance(other->point);
}

void OCCTGeomPoint3DTranslate(OCCTGeomPoint3DRef _Nonnull ref, double dx, double dy, double dz)
{
  gp_Trsf t;
  t.SetTranslation(gp_Vec(dx, dy, dz));
  ref->point->Transform(t);
}

OCCTGeomDirectionRef _Nonnull OCCTGeomDirectionCreate(double x, double y, double z)
{
  auto* ref = new OCCTGeomDirection();
  try
  {
    ref->direction = new Geom_Direction(x, y, z);
  }
  catch (...)
  {
    ref->direction = new Geom_Direction(0, 0, 1);
  }
  return ref;
}

void OCCTGeomDirectionRelease(OCCTGeomDirectionRef _Nonnull ref)
{
  delete ref;
}

void OCCTGeomDirectionCoords(OCCTGeomDirectionRef _Nonnull ref, double* x, double* y, double* z)
{
  gp_Dir d = ref->direction->Dir();
  *x       = d.X();
  *y       = d.Y();
  *z       = d.Z();
}

void OCCTGeomDirectionSetCoord(OCCTGeomDirectionRef _Nonnull ref, double x, double y, double z)
{
  ref->direction->SetCoord(x, y, z);
}

OCCTGeomDirectionRef _Nullable OCCTGeomDirectionCrossed(OCCTGeomDirectionRef _Nonnull ref,
                                                        OCCTGeomDirectionRef _Nonnull other)
{
  try
  {
    Handle(Geom_Vector) cross = ref->direction->Crossed(other->direction);
    if (cross.IsNull())
      return nullptr;
    gp_Vec v          = cross->Vec();
    auto*  result     = new OCCTGeomDirection();
    result->direction = new Geom_Direction(v.X(), v.Y(), v.Z());
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTGeomVector3DRef _Nonnull OCCTGeomVector3DCreate(double x, double y, double z)
{
  auto* ref   = new OCCTGeomVector3D();
  ref->vector = new Geom_VectorWithMagnitude(x, y, z);
  return ref;
}

OCCTGeomVector3DRef _Nonnull OCCTGeomVector3DFromPoints(double x1,
                                                        double y1,
                                                        double z1,
                                                        double x2,
                                                        double y2,
                                                        double z2)
{
  auto* ref   = new OCCTGeomVector3D();
  ref->vector = new Geom_VectorWithMagnitude(gp_Pnt(x1, y1, z1), gp_Pnt(x2, y2, z2));
  return ref;
}

void OCCTGeomVector3DRelease(OCCTGeomVector3DRef _Nonnull ref)
{
  delete ref;
}

void OCCTGeomVector3DCoords(OCCTGeomVector3DRef _Nonnull ref, double* x, double* y, double* z)
{
  gp_Vec v = ref->vector->Vec();
  *x       = v.X();
  *y       = v.Y();
  *z       = v.Z();
}

double OCCTGeomVector3DMagnitude(OCCTGeomVector3DRef _Nonnull ref)
{
  return ref->vector->Magnitude();
}

double OCCTGeomVector3DDot(OCCTGeomVector3DRef _Nonnull ref, OCCTGeomVector3DRef _Nonnull other)
{
  return ref->vector->Dot(other->vector);
}

OCCTGeomVector3DRef _Nonnull OCCTGeomVector3DAdded(OCCTGeomVector3DRef _Nonnull ref,
                                                   OCCTGeomVector3DRef _Nonnull other)
{
  auto* result   = new OCCTGeomVector3D();
  result->vector = ref->vector->Added(other->vector);
  return result;
}

OCCTGeomVector3DRef _Nonnull OCCTGeomVector3DMultiplied(OCCTGeomVector3DRef _Nonnull ref,
                                                        double scalar)
{
  auto* result   = new OCCTGeomVector3D();
  result->vector = ref->vector->Multiplied(scalar);
  return result;
}

OCCTGeomVector3DRef _Nullable OCCTGeomVector3DNormalized(OCCTGeomVector3DRef _Nonnull ref)
{
  try
  {
    auto* result   = new OCCTGeomVector3D();
    result->vector = ref->vector->Normalized();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTGeomVector3DRef _Nonnull OCCTGeomVector3DCrossed(OCCTGeomVector3DRef _Nonnull ref,
                                                     OCCTGeomVector3DRef _Nonnull other)
{
  Handle(Geom_Vector) cross  = ref->vector->Crossed(other->vector);
  gp_Vec              v      = cross->Vec();
  auto*               result = new OCCTGeomVector3D();
  result->vector             = new Geom_VectorWithMagnitude(v);
  return result;
}

OCCTAxis1PlacementRef _Nonnull OCCTAxis1PlacementCreate(double px,
                                                        double py,
                                                        double pz,
                                                        double dx,
                                                        double dy,
                                                        double dz)
{
  auto* ref = new OCCTAxis1Placement();
  try
  {
    ref->axis = new Geom_Axis1Placement(gp_Pnt(px, py, pz), gp_Dir(dx, dy, dz));
  }
  catch (...)
  {
    ref->axis = new Geom_Axis1Placement(gp_Pnt(px, py, pz), gp_Dir(0, 0, 1));
  }
  return ref;
}

void OCCTAxis1PlacementRelease(OCCTAxis1PlacementRef _Nonnull ref)
{
  delete ref;
}

void OCCTAxis1PlacementLocation(OCCTAxis1PlacementRef _Nonnull ref, double* x, double* y, double* z)
{
  gp_Pnt p = ref->axis->Location();
  *x       = p.X();
  *y       = p.Y();
  *z       = p.Z();
}

void OCCTAxis1PlacementDirection(OCCTAxis1PlacementRef _Nonnull ref,
                                 double* x,
                                 double* y,
                                 double* z)
{
  gp_Dir d = ref->axis->Direction();
  *x       = d.X();
  *y       = d.Y();
  *z       = d.Z();
}

void OCCTAxis1PlacementReverse(OCCTAxis1PlacementRef _Nonnull ref)
{
  ref->axis->Reverse();
}

OCCTAxis1PlacementRef _Nonnull OCCTAxis1PlacementReversed(OCCTAxis1PlacementRef _Nonnull ref)
{
  auto* result = new OCCTAxis1Placement();
  result->axis = ref->axis->Reversed();
  return result;
}

void OCCTAxis1PlacementSetDirection(OCCTAxis1PlacementRef _Nonnull ref,
                                    double dx,
                                    double dy,
                                    double dz)
{
  try
  {
    ref->axis->SetDirection(gp_Dir(dx, dy, dz));
  }
  catch (...)
  {
  }
}

void OCCTAxis1PlacementSetLocation(OCCTAxis1PlacementRef _Nonnull ref,
                                   double px,
                                   double py,
                                   double pz)
{
  ref->axis->SetLocation(gp_Pnt(px, py, pz));
}

OCCTAxis2PlacementRef _Nonnull OCCTAxis2PlacementCreate(double px,
                                                        double py,
                                                        double pz,
                                                        double nx,
                                                        double ny,
                                                        double nz,
                                                        double vx,
                                                        double vy,
                                                        double vz)
{
  auto* ref = new OCCTAxis2Placement();
  try
  {
    ref->axis = new Geom_Axis2Placement(gp_Pnt(px, py, pz), gp_Dir(nx, ny, nz), gp_Dir(vx, vy, vz));
  }
  catch (...)
  {
    ref->axis = new Geom_Axis2Placement(gp_Pnt(px, py, pz), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0));
  }
  return ref;
}

void OCCTAxis2PlacementRelease(OCCTAxis2PlacementRef _Nonnull ref)
{
  delete ref;
}

void OCCTAxis2PlacementLocation(OCCTAxis2PlacementRef _Nonnull ref, double* x, double* y, double* z)
{
  gp_Pnt p = ref->axis->Location();
  *x       = p.X();
  *y       = p.Y();
  *z       = p.Z();
}

void OCCTAxis2PlacementDirection(OCCTAxis2PlacementRef _Nonnull ref,
                                 double* x,
                                 double* y,
                                 double* z)
{
  gp_Dir d = ref->axis->Direction();
  *x       = d.X();
  *y       = d.Y();
  *z       = d.Z();
}

void OCCTAxis2PlacementXDirection(OCCTAxis2PlacementRef _Nonnull ref,
                                  double* x,
                                  double* y,
                                  double* z)
{
  gp_Dir d = ref->axis->XDirection();
  *x       = d.X();
  *y       = d.Y();
  *z       = d.Z();
}

void OCCTAxis2PlacementYDirection(OCCTAxis2PlacementRef _Nonnull ref,
                                  double* x,
                                  double* y,
                                  double* z)
{
  gp_Dir d = ref->axis->YDirection();
  *x       = d.X();
  *y       = d.Y();
  *z       = d.Z();
}

void OCCTAxis2PlacementSetDirection(OCCTAxis2PlacementRef _Nonnull ref,
                                    double nx,
                                    double ny,
                                    double nz)
{
  try
  {
    ref->axis->SetDirection(gp_Dir(nx, ny, nz));
  }
  catch (...)
  {
  }
}

void OCCTAxis2PlacementSetXDirection(OCCTAxis2PlacementRef _Nonnull ref,
                                     double vx,
                                     double vy,
                                     double vz)
{
  try
  {
    ref->axis->SetXDirection(gp_Dir(vx, vy, vz));
  }
  catch (...)
  {
  }
}

OCCTCurveToAnaCurveResult OCCTGeomConvertCurveToAnalytical(OCCTCurve3DRef _Nonnull curveRef,
                                                           double tolerance,
                                                           double first,
                                                           double last)
{
  OCCTCurveToAnaCurveResult result = {nullptr, 0, 0, 0, false};
  if (!curveRef)
    return result;
  Handle(Geom_Curve) resCurve;
  if (!occtCurveToAnalytical(reinterpret_cast<OCCTCurve3D*>(curveRef)->curve,
                             tolerance,
                             first,
                             last,
                             resCurve,
                             result.newFirst,
                             result.newLast,
                             result.gap))
  {
    return result;
  }
  result.curve   = reinterpret_cast<OCCTCurve3DRef>(new OCCTCurve3D{resCurve});
  result.success = true;
  return result;
}

OCCTCurve3DRef _Nullable OCCTGceMakeCircFrom3Points(double p1x,
                                                    double p1y,
                                                    double p1z,
                                                    double p2x,
                                                    double p2y,
                                                    double p2z,
                                                    double p3x,
                                                    double p3y,
                                                    double p3z)
{
  try
  {
    gce_MakeCirc mc(gp_Pnt(p1x, p1y, p1z), gp_Pnt(p2x, p2y, p2z), gp_Pnt(p3x, p3y, p3z));
    if (!mc.IsDone())
      return nullptr;
    Handle(Geom_Circle) circ = new Geom_Circle(mc.Value());
    return (OCCTCurve3DRef) new OCCTCurve3D{circ};
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef _Nullable OCCTGceMakeCircFromCenterNormal(double cx,
                                                         double cy,
                                                         double cz,
                                                         double nx,
                                                         double ny,
                                                         double nz,
                                                         double radius)
{
  try
  {
    if (!occtValidCircleRadius(radius))
      return nullptr;
    gce_MakeCirc mc(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz), radius);
    if (!mc.IsDone())
      return nullptr;
    Handle(Geom_Circle) circ = new Geom_Circle(mc.Value());
    return (OCCTCurve3DRef) new OCCTCurve3D{circ};
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef _Nullable OCCTGceMakeLinFrom2Points(double p1x,
                                                   double p1y,
                                                   double p1z,
                                                   double p2x,
                                                   double p2y,
                                                   double p2z)
{
  try
  {
    gce_MakeLin ml(gp_Pnt(p1x, p1y, p1z), gp_Pnt(p2x, p2y, p2z));
    if (!ml.IsDone())
      return nullptr;
    Handle(Geom_Line) line = new Geom_Line(ml.Value());
    return (OCCTCurve3DRef) new OCCTCurve3D{line};
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTGceMakeDir(double  p1x,
                    double  p1y,
                    double  p1z,
                    double  p2x,
                    double  p2y,
                    double  p2z,
                    double* outX,
                    double* outY,
                    double* outZ)
{
  try
  {
    gce_MakeDir md(gp_Pnt(p1x, p1y, p1z), gp_Pnt(p2x, p2y, p2z));
    if (!md.IsDone())
      return false;
    *outX = md.Value().X();
    *outY = md.Value().Y();
    *outZ = md.Value().Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

OCCTCurve3DRef _Nullable OCCTGceMakeElips(double cx,
                                          double cy,
                                          double cz,
                                          double nx,
                                          double ny,
                                          double nz,
                                          double majorRadius,
                                          double minorRadius)
{
  try
  {
    if (!occtValidEllipseRadii(majorRadius, minorRadius))
      return nullptr;
    gce_MakeElips me(gp_Ax2(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz)), majorRadius, minorRadius);
    if (!me.IsDone())
      return nullptr;
    Handle(Geom_Ellipse) elips = new Geom_Ellipse(me.Value());
    return (OCCTCurve3DRef) new OCCTCurve3D{elips};
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef _Nullable OCCTGceMakeHypr(double cx,
                                         double cy,
                                         double cz,
                                         double nx,
                                         double ny,
                                         double nz,
                                         double majorRadius,
                                         double minorRadius)
{
  try
  {
    if (!occtValidHyperbolaRadii(majorRadius, minorRadius))
      return nullptr;
    gce_MakeHypr mh(gp_Ax2(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz)), majorRadius, minorRadius);
    if (!mh.IsDone())
      return nullptr;
    Handle(Geom_Hyperbola) hypr = new Geom_Hyperbola(mh.Value());
    return (OCCTCurve3DRef) new OCCTCurve3D{hypr};
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef _Nullable OCCTGceMakeParab(double cx,
                                          double cy,
                                          double cz,
                                          double nx,
                                          double ny,
                                          double nz,
                                          double focal)
{
  try
  {
    if (!occtValidParabolaFocal(focal))
      return nullptr;
    gce_MakeParab mp(gp_Ax2(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz)), focal);
    if (!mp.IsDone())
      return nullptr;
    Handle(Geom_Parabola) parab = new Geom_Parabola(mp.Value());
    return (OCCTCurve3DRef) new OCCTCurve3D{parab};
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTGeomTransformRef OCCTGeomTransformCreate(void)
{
  try
  {
    Handle(Geom_Transformation)* h = new Handle(Geom_Transformation)(new Geom_Transformation());
    return h;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTGeomTransformRelease(OCCTGeomTransformRef transform)
{
  auto* h = static_cast<Handle(Geom_Transformation)*>(transform);
  delete h;
}

void OCCTGeomTransformSetTranslation(OCCTGeomTransformRef transform,
                                     double               dx,
                                     double               dy,
                                     double               dz)
{
  try
  {
    auto* h = static_cast<Handle(Geom_Transformation)*>(transform);
    (*h)->SetTranslation(gp_Vec(dx, dy, dz));
  }
  catch (...)
  {
  }
}

void OCCTGeomTransformSetRotation(OCCTGeomTransformRef transform,
                                  double               originX,
                                  double               originY,
                                  double               originZ,
                                  double               dirX,
                                  double               dirY,
                                  double               dirZ,
                                  double               angleRadians)
{
  try
  {
    auto*  h = static_cast<Handle(Geom_Transformation)*>(transform);
    gp_Ax1 axis(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
    (*h)->SetRotation(axis, angleRadians);
  }
  catch (...)
  {
  }
}

void OCCTGeomTransformSetScale(OCCTGeomTransformRef transform,
                               double               centerX,
                               double               centerY,
                               double               centerZ,
                               double               scaleFactor)
{
  try
  {
    auto* h = static_cast<Handle(Geom_Transformation)*>(transform);
    (*h)->SetScale(gp_Pnt(centerX, centerY, centerZ), scaleFactor);
  }
  catch (...)
  {
  }
}

void OCCTGeomTransformSetMirrorPoint(OCCTGeomTransformRef transform, double x, double y, double z)
{
  try
  {
    auto* h = static_cast<Handle(Geom_Transformation)*>(transform);
    (*h)->SetMirror(gp_Pnt(x, y, z));
  }
  catch (...)
  {
  }
}

void OCCTGeomTransformSetMirrorAxis(OCCTGeomTransformRef transform,
                                    double               originX,
                                    double               originY,
                                    double               originZ,
                                    double               dirX,
                                    double               dirY,
                                    double               dirZ)
{
  try
  {
    auto*  h = static_cast<Handle(Geom_Transformation)*>(transform);
    gp_Ax1 axis(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
    (*h)->SetMirror(axis);
  }
  catch (...)
  {
  }
}

double OCCTGeomTransformScaleFactor(OCCTGeomTransformRef transform)
{
  try
  {
    auto* h = static_cast<Handle(Geom_Transformation)*>(transform);
    return (*h)->ScaleFactor();
  }
  catch (...)
  {
    return 1.0;
  }
}

bool OCCTGeomTransformIsNegative(OCCTGeomTransformRef transform)
{
  try
  {
    auto* h = static_cast<Handle(Geom_Transformation)*>(transform);
    return (*h)->IsNegative();
  }
  catch (...)
  {
    return false;
  }
}

void OCCTGeomTransformApply(OCCTGeomTransformRef transform, double* x, double* y, double* z)
{
  try
  {
    auto* h = static_cast<Handle(Geom_Transformation)*>(transform);
    (*h)->Transforms(*x, *y, *z);
  }
  catch (...)
  {
  }
}

double OCCTGeomTransformValue(OCCTGeomTransformRef transform, int row, int col)
{
  try
  {
    auto* h = static_cast<Handle(Geom_Transformation)*>(transform);
    return (*h)->Value(row, col);
  }
  catch (...)
  {
    return 0.0;
  }
}

OCCTGeomTransformRef OCCTGeomTransformMultiplied(OCCTGeomTransformRef t1, OCCTGeomTransformRef t2)
{
  try
  {
    auto*                       h1     = static_cast<Handle(Geom_Transformation)*>(t1);
    auto*                       h2     = static_cast<Handle(Geom_Transformation)*>(t2);
    Handle(Geom_Transformation) result = (*h1)->Multiplied(*h2);
    return new Handle(Geom_Transformation)(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTGeomTransformRef OCCTGeomTransformInverted(OCCTGeomTransformRef transform)
{
  try
  {
    auto*                       h      = static_cast<Handle(Geom_Transformation)*>(transform);
    Handle(Geom_Transformation) result = (*h)->Inverted();
    return new Handle(Geom_Transformation)(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTCurve3DCreateOffset(OCCTCurve3DRef basisCurve,
                                       double         offset,
                                       double         dirX,
                                       double         dirY,
                                       double         dirZ)
{
  if (!basisCurve || basisCurve->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_OffsetCurve) oc =
      new Geom_OffsetCurve(basisCurve->curve, offset, gp_Dir(dirX, dirY, dirZ));
    auto* ref  = new OCCTCurve3D();
    ref->curve = oc;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

double OCCTCurve3DOffsetValue(OCCTCurve3DRef curve)
{
  try
  {
    Handle(Geom_OffsetCurve) oc = Handle(Geom_OffsetCurve)::DownCast(curve->curve);
    if (oc.IsNull())
      return 0.0;
    return oc->Offset();
  }
  catch (...)
  {
    return 0.0;
  }
}

bool OCCTCurve3DOffsetDirection(OCCTCurve3DRef curve, double* dirX, double* dirY, double* dirZ)
{
  try
  {
    Handle(Geom_OffsetCurve) oc = Handle(Geom_OffsetCurve)::DownCast(curve->curve);
    if (oc.IsNull())
      return false;
    gp_Dir d = oc->Direction();
    *dirX    = d.X();
    *dirY    = d.Y();
    *dirZ    = d.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTElCLibValueOnLine(double  u,
                           double  ox,
                           double  oy,
                           double  oz,
                           double  dx,
                           double  dy,
                           double  dz,
                           double* outX,
                           double* outY,
                           double* outZ)
{
  try
  {
    gp_Pnt p = ElCLib::Value(u, gp_Lin(gp_Pnt(ox, oy, oz), gp_Dir(dx, dy, dz)));
    *outX    = p.X();
    *outY    = p.Y();
    *outZ    = p.Z();
  }
  catch (...)
  {
  }
}

void OCCTElCLibValueOnCircle(double  u,
                             double  cx,
                             double  cy,
                             double  cz,
                             double  nx,
                             double  ny,
                             double  nz,
                             double  radius,
                             double* outX,
                             double* outY,
                             double* outZ)
{
  try
  {
    gp_Pnt p = ElCLib::Value(u, gp_Circ(gp_Ax2(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz)), radius));
    *outX    = p.X();
    *outY    = p.Y();
    *outZ    = p.Z();
  }
  catch (...)
  {
  }
}

void OCCTElCLibValueOnEllipse(double  u,
                              double  cx,
                              double  cy,
                              double  cz,
                              double  nx,
                              double  ny,
                              double  nz,
                              double  majorRadius,
                              double  minorRadius,
                              double* outX,
                              double* outY,
                              double* outZ)
{
  try
  {
    gp_Pnt p = ElCLib::Value(
      u,
      gp_Elips(gp_Ax2(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz)), majorRadius, minorRadius));
    *outX = p.X();
    *outY = p.Y();
    *outZ = p.Z();
  }
  catch (...)
  {
  }
}

void OCCTElCLibD1OnLine(double  u,
                        double  ox,
                        double  oy,
                        double  oz,
                        double  dx,
                        double  dy,
                        double  dz,
                        double* outPX,
                        double* outPY,
                        double* outPZ,
                        double* outVX,
                        double* outVY,
                        double* outVZ)
{
  try
  {
    gp_Pnt p;
    gp_Vec v;
    ElCLib::D1(u, gp_Lin(gp_Pnt(ox, oy, oz), gp_Dir(dx, dy, dz)), p, v);
    *outPX = p.X();
    *outPY = p.Y();
    *outPZ = p.Z();
    *outVX = v.X();
    *outVY = v.Y();
    *outVZ = v.Z();
  }
  catch (...)
  {
  }
}

void OCCTElCLibD1OnCircle(double  u,
                          double  cx,
                          double  cy,
                          double  cz,
                          double  nx,
                          double  ny,
                          double  nz,
                          double  radius,
                          double* outPX,
                          double* outPY,
                          double* outPZ,
                          double* outVX,
                          double* outVY,
                          double* outVZ)
{
  try
  {
    gp_Pnt p;
    gp_Vec v;
    ElCLib::D1(u, gp_Circ(gp_Ax2(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz)), radius), p, v);
    *outPX = p.X();
    *outPY = p.Y();
    *outPZ = p.Z();
    *outVX = v.X();
    *outVY = v.Y();
    *outVZ = v.Z();
  }
  catch (...)
  {
  }
}

double OCCTElCLibParameterOnLine(double ox,
                                 double oy,
                                 double oz,
                                 double dx,
                                 double dy,
                                 double dz,
                                 double px,
                                 double py,
                                 double pz)
{
  try
  {
    return ElCLib::Parameter(gp_Lin(gp_Pnt(ox, oy, oz), gp_Dir(dx, dy, dz)), gp_Pnt(px, py, pz));
  }
  catch (...)
  {
    return 0.0;
  }
}

double OCCTElCLibParameterOnCircle(double cx,
                                   double cy,
                                   double cz,
                                   double nx,
                                   double ny,
                                   double nz,
                                   double radius,
                                   double px,
                                   double py,
                                   double pz)
{
  try
  {
    return ElCLib::Parameter(gp_Circ(gp_Ax2(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz)), radius),
                             gp_Pnt(px, py, pz));
  }
  catch (...)
  {
    return 0.0;
  }
}

double OCCTElCLibInPeriod(double u, double uFirst, double uLast)
{
  return ElCLib::InPeriod(u, uFirst, uLast);
}

OCCTQuaternionRef OCCTQuaternionCreate(double x, double y, double z, double w)
{
  auto* ref = new OCCTQuaternion();
  ref->q    = gp_Quaternion(x, y, z, w);
  return ref;
}

OCCTQuaternionRef OCCTQuaternionCreateFromAxisAngle(double ax, double ay, double az, double angle)
{
  auto* ref = new OCCTQuaternion();
  ref->q    = gp_Quaternion(gp_Vec(ax, ay, az), angle);
  return ref;
}

OCCTQuaternionRef OCCTQuaternionCreateFromVectors(double fromX,
                                                  double fromY,
                                                  double fromZ,
                                                  double toX,
                                                  double toY,
                                                  double toZ)
{
  auto* ref = new OCCTQuaternion();
  ref->q    = gp_Quaternion(gp_Vec(fromX, fromY, fromZ), gp_Vec(toX, toY, toZ));
  return ref;
}

void OCCTQuaternionRelease(OCCTQuaternionRef q)
{
  delete q;
}

void OCCTQuaternionGetComponents(OCCTQuaternionRef q, double* x, double* y, double* z, double* w)
{
  *x = q->q.X();
  *y = q->q.Y();
  *z = q->q.Z();
  *w = q->q.W();
}

void OCCTQuaternionSetEulerAngles(OCCTQuaternionRef q,
                                  int32_t           order,
                                  double            alpha,
                                  double            beta,
                                  double            gamma)
{
  q->q.SetEulerAngles((gp_EulerSequence)order, alpha, beta, gamma);
}

void OCCTQuaternionGetEulerAngles(OCCTQuaternionRef q,
                                  int32_t           order,
                                  double*           alpha,
                                  double*           beta,
                                  double*           gamma)
{
  q->q.GetEulerAngles((gp_EulerSequence)order, *alpha, *beta, *gamma);
}

void OCCTQuaternionGetMatrix(OCCTQuaternionRef q, double* matrix9)
{
  gp_Mat m   = q->q.GetMatrix();
  matrix9[0] = m.Value(1, 1);
  matrix9[1] = m.Value(1, 2);
  matrix9[2] = m.Value(1, 3);
  matrix9[3] = m.Value(2, 1);
  matrix9[4] = m.Value(2, 2);
  matrix9[5] = m.Value(2, 3);
  matrix9[6] = m.Value(3, 1);
  matrix9[7] = m.Value(3, 2);
  matrix9[8] = m.Value(3, 3);
}

void OCCTQuaternionMultiplyVec(OCCTQuaternionRef q,
                               double            vx,
                               double            vy,
                               double            vz,
                               double*           outX,
                               double*           outY,
                               double*           outZ)
{
  gp_Vec result = q->q.Multiply(gp_Vec(vx, vy, vz));
  *outX         = result.X();
  *outY         = result.Y();
  *outZ         = result.Z();
}

OCCTQuaternionRef OCCTQuaternionMultiply(OCCTQuaternionRef q1, OCCTQuaternionRef q2)
{
  auto* ref = new OCCTQuaternion();
  ref->q    = q1->q.Multiplied(q2->q);
  return ref;
}

void OCCTQuaternionGetVectorAndAngle(OCCTQuaternionRef q,
                                     double*           ax,
                                     double*           ay,
                                     double*           az,
                                     double*           angle)
{
  gp_Vec axis;
  double a;
  q->q.GetVectorAndAngle(axis, a);
  *ax    = axis.X();
  *ay    = axis.Y();
  *az    = axis.Z();
  *angle = a;
}

double OCCTQuaternionGetRotationAngle(OCCTQuaternionRef q)
{
  return q->q.GetRotationAngle();
}

void OCCTQuaternionNormalize(OCCTQuaternionRef q)
{
  q->q.Normalize();
}

OCCTCurve3DRef OCCTCurve3DOffsetBasis(OCCTCurve3DRef curve)
{
  if (!curve)
    return nullptr;
  try
  {
    Handle(Geom_OffsetCurve) oc = Handle(Geom_OffsetCurve)::DownCast(curve->curve);
    if (oc.IsNull())
      return nullptr;
    Handle(Geom_Curve) basis = oc->BasisCurve();
    if (basis.IsNull())
      return nullptr;
    return new OCCTCurve3D(basis);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTCurve3DTrimmed(OCCTCurve3DRef basisCurve, double u1, double u2)
{
  if (!basisCurve || basisCurve->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_TrimmedCurve) tc = new Geom_TrimmedCurve(basisCurve->curve, u1, u2);
    OCCTCurve3D*              c  = new OCCTCurve3D();
    c->curve                     = tc;
    return c;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTCurve3DStartPoint(OCCTCurve3DRef curve, double* x, double* y, double* z)
{
  // #478: these two were the only pair in the family with no guard at all, not even the
  // wrapper pointer. Zero out first so the guarded exit matches the catch below.
  *x = 0;
  *y = 0;
  *z = 0;
  if (!curve || curve->curve.IsNull())
    return;
  try
  {
    gp_Pnt p = curve->curve->Value(curve->curve->FirstParameter());
    *x       = p.X();
    *y       = p.Y();
    *z       = p.Z();
  }
  catch (...)
  {
    *x = 0;
    *y = 0;
    *z = 0;
  }
}

void OCCTCurve3DEndPoint(OCCTCurve3DRef curve, double* x, double* y, double* z)
{
  *x = 0;
  *y = 0;
  *z = 0; // #478, as above
  if (!curve || curve->curve.IsNull())
    return;
  try
  {
    gp_Pnt p = curve->curve->Value(curve->curve->LastParameter());
    *x       = p.X();
    *y       = p.Y();
    *z       = p.Z();
  }
  catch (...)
  {
    *x = 0;
    *y = 0;
    *z = 0;
  }
}

OCCTCurve3DRef OCCTCurve3DTrimmedBasis(OCCTCurve3DRef curve)
{
  try
  {
    Handle(Geom_TrimmedCurve) tc = Handle(Geom_TrimmedCurve)::DownCast(curve->curve);
    if (tc.IsNull())
      return nullptr;
    OCCTCurve3D* c = new OCCTCurve3D();
    c->curve       = tc->BasisCurve();
    return c;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTCurve3DSetTrim(OCCTCurve3DRef curve, double u1, double u2)
{
  try
  {
    Handle(Geom_TrimmedCurve) tc = Handle(Geom_TrimmedCurve)::DownCast(curve->curve);
    if (tc.IsNull())
      return false;
    tc->SetTrim(u1, u2);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTCurve3DGetContinuity(OCCTCurve3DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return 0;
  try
  {
    return static_cast<int32_t>(curve->curve->Continuity());
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTCurve3DBSplineKnotCount(OCCTCurve3DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return 0;
  Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return 0;
  return bs->NbKnots();
}

int32_t OCCTCurve3DBSplinePoleCount(OCCTCurve3DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return 0;
  Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return 0;
  return bs->NbPoles();
}

int32_t OCCTCurve3DBSplineDegree(OCCTCurve3DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return 0;
  Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return 0;
  return bs->Degree();
}

bool OCCTCurve3DBSplineIsRational(OCCTCurve3DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return false;
  return bs->IsRational();
}

void OCCTCurve3DBSplineGetKnots(OCCTCurve3DRef curve, double* knots)
{
  if (!curve || curve->curve.IsNull() || !knots)
    return;
  Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return;
  TColStd_Array1OfReal kArr(1, bs->NbKnots());
  bs->Knots(kArr);
  for (int i = 1; i <= bs->NbKnots(); i++)
    knots[i - 1] = kArr(i);
}

void OCCTCurve3DBSplineGetMults(OCCTCurve3DRef curve, int32_t* mults)
{
  if (!curve || curve->curve.IsNull() || !mults)
    return;
  Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return;
  TColStd_Array1OfInteger mArr(1, bs->NbKnots());
  bs->Multiplicities(mArr);
  for (int i = 1; i <= bs->NbKnots(); i++)
    mults[i - 1] = mArr(i);
}

void OCCTCurve3DBSplineGetPole(OCCTCurve3DRef curve, int32_t index, double* x, double* y, double* z)
{
  *x = 0;
  *y = 0;
  *z = 0;
  if (!curve || curve->curve.IsNull())
    return;
  Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull() || index < 1 || index > bs->NbPoles())
    return;
  gp_Pnt p = bs->Pole(index);
  *x       = p.X();
  *y       = p.Y();
  *z       = p.Z();
}

bool OCCTCurve3DBSplineSetPole(OCCTCurve3DRef curve, int32_t index, double x, double y, double z)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull() || index < 1 || index > bs->NbPoles())
    return false;
  try
  {
    bs->SetPole(index, gp_Pnt(x, y, z));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DBSplineSetWeight(OCCTCurve3DRef curve, int32_t index, double weight)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull() || index < 1 || index > bs->NbPoles())
    return false;
  try
  {
    bs->SetWeight(index, weight);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

double OCCTCurve3DBSplineGetWeight(OCCTCurve3DRef curve, int32_t index)
{
  if (!curve || curve->curve.IsNull())
    return 1.0;
  Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull() || index < 1 || index > bs->NbPoles())
    return 1.0;
  return bs->Weight(index);
}

bool OCCTCurve3DBSplineInsertKnot(OCCTCurve3DRef curve, double u, int32_t mult, double tol)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return false;
  try
  {
    bs->InsertKnot(u, mult, tol);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DBSplineRemoveKnot(OCCTCurve3DRef curve, int32_t index, int32_t mult, double tol)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull() || index < 1 || index > bs->NbKnots())
    return false;
  try
  {
    return bs->RemoveKnot(index, mult, tol);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DBSplineSegment(OCCTCurve3DRef curve, double u1, double u2)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return false;
  try
  {
    bs->Segment(u1, u2);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DBSplineIncreaseDegree(OCCTCurve3DRef curve, int32_t degree)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return false;
  try
  {
    bs->IncreaseDegree(degree);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

double OCCTCurve3DBSplineResolution(OCCTCurve3DRef curve, double tolerance3d)
{
  if (!curve || curve->curve.IsNull())
    return 0.0;
  Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return 0.0;
  double uTol = 0;
  bs->Resolution(tolerance3d, uTol);
  return uTol;
}

bool OCCTCurve3DBSplineSetPeriodic(OCCTCurve3DRef curve, bool periodic)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return false;
  try
  {
    if (periodic)
      bs->SetPeriodic();
    else
      bs->SetNotPeriodic();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTCurve3DBezierGetPole(OCCTCurve3DRef curve, int32_t index, double* x, double* y, double* z)
{
  *x = 0;
  *y = 0;
  *z = 0;
  if (!curve || curve->curve.IsNull())
    return;
  Handle(Geom_BezierCurve) bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull() || index < 1 || index > bz->NbPoles())
    return;
  gp_Pnt p = bz->Pole(index);
  *x       = p.X();
  *y       = p.Y();
  *z       = p.Z();
}

bool OCCTCurve3DBezierSetPole(OCCTCurve3DRef curve, int32_t index, double x, double y, double z)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom_BezierCurve) bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return false;
  try
  {
    bz->SetPole(index, gp_Pnt(x, y, z));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DBezierSetWeight(OCCTCurve3DRef curve, int32_t index, double weight)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom_BezierCurve) bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return false;
  try
  {
    bz->SetWeight(index, weight);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DBezierInsertPoleAfter(OCCTCurve3DRef curve,
                                      int32_t        index,
                                      double         x,
                                      double         y,
                                      double         z)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom_BezierCurve) bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return false;
  try
  {
    bz->InsertPoleAfter(index, gp_Pnt(x, y, z));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DBezierRemovePole(OCCTCurve3DRef curve, int32_t index)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom_BezierCurve) bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return false;
  try
  {
    bz->RemovePole(index);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DBezierSegment(OCCTCurve3DRef curve, double u1, double u2)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom_BezierCurve) bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return false;
  try
  {
    bz->Segment(u1, u2);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DBezierIncreaseDegree(OCCTCurve3DRef curve, int32_t degree)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom_BezierCurve) bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return false;
  try
  {
    bz->Increase(degree);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DBezierIsRational(OCCTCurve3DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom_BezierCurve) bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return false;
  return bz->IsRational();
}

int32_t OCCTCurve3DBezierDegree(OCCTCurve3DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return 0;
  Handle(Geom_BezierCurve) bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return 0;
  return bz->Degree();
}

int32_t OCCTCurve3DBezierPoleCount(OCCTCurve3DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return 0;
  Handle(Geom_BezierCurve) bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return 0;
  return bz->NbPoles();
}

double OCCTCurve3DCircleRadius(OCCTCurve3DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom_Circle) c = Handle(Geom_Circle)::DownCast(curve->curve);
    if (c.IsNull())
      return 0;
    return c->Radius();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTCurve3DCircleSetRadius(OCCTCurve3DRef curve, double radius)
{
  if (!curve)
    return false;
  try
  {
    Handle(Geom_Circle) c = Handle(Geom_Circle)::DownCast(curve->curve);
    if (c.IsNull())
      return false;
    if (!occtValidCircleRadius(radius))
      return false;
    c->SetRadius(radius);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

double OCCTCurve3DCircleEccentricity(OCCTCurve3DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom_Circle) c = Handle(Geom_Circle)::DownCast(curve->curve);
    if (c.IsNull())
      return 0;
    return c->Eccentricity();
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTCurve3DCircleXAxis(OCCTCurve3DRef curve,
                            double*        px,
                            double*        py,
                            double*        pz,
                            double*        dx,
                            double*        dy,
                            double*        dz)
{
  *px = 0;
  *py = 0;
  *pz = 0;
  *dx = 0;
  *dy = 0;
  *dz = 0;
  if (!curve)
    return;
  try
  {
    Handle(Geom_Circle) c = Handle(Geom_Circle)::DownCast(curve->curve);
    if (c.IsNull())
      return;
    gp_Ax1 ax = c->XAxis();
    *px       = ax.Location().X();
    *py       = ax.Location().Y();
    *pz       = ax.Location().Z();
    *dx       = ax.Direction().X();
    *dy       = ax.Direction().Y();
    *dz       = ax.Direction().Z();
  }
  catch (...)
  {
  }
}

void OCCTCurve3DCircleYAxis(OCCTCurve3DRef curve,
                            double*        px,
                            double*        py,
                            double*        pz,
                            double*        dx,
                            double*        dy,
                            double*        dz)
{
  *px = 0;
  *py = 0;
  *pz = 0;
  *dx = 0;
  *dy = 0;
  *dz = 0;
  if (!curve)
    return;
  try
  {
    Handle(Geom_Circle) c = Handle(Geom_Circle)::DownCast(curve->curve);
    if (c.IsNull())
      return;
    gp_Ax1 ax = c->YAxis();
    *px       = ax.Location().X();
    *py       = ax.Location().Y();
    *pz       = ax.Location().Z();
    *dx       = ax.Direction().X();
    *dy       = ax.Direction().Y();
    *dz       = ax.Direction().Z();
  }
  catch (...)
  {
  }
}

void OCCTCurve3DCircleCenter(OCCTCurve3DRef curve, double* x, double* y, double* z)
{
  *x = 0;
  *y = 0;
  *z = 0;
  if (!curve)
    return;
  try
  {
    Handle(Geom_Circle) c = Handle(Geom_Circle)::DownCast(curve->curve);
    if (c.IsNull())
      return;
    gp_Pnt ctr = c->Circ().Location();
    *x         = ctr.X();
    *y         = ctr.Y();
    *z         = ctr.Z();
  }
  catch (...)
  {
  }
}

double OCCTCurve3DEllipseMajorRadius(OCCTCurve3DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom_Ellipse) e = Handle(Geom_Ellipse)::DownCast(curve->curve);
    if (e.IsNull())
      return 0;
    return e->MajorRadius();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTCurve3DEllipseMinorRadius(OCCTCurve3DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom_Ellipse) e = Handle(Geom_Ellipse)::DownCast(curve->curve);
    if (e.IsNull())
      return 0;
    return e->MinorRadius();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTCurve3DEllipseSetMajorRadius(OCCTCurve3DRef curve, double r)
{
  if (!curve)
    return false;
  try
  {
    Handle(Geom_Ellipse) e = Handle(Geom_Ellipse)::DownCast(curve->curve);
    if (e.IsNull())
      return false;
    // The pair has to stay a valid ellipse, so the new value is judged against the radius
    // already on the curve, not on its own (#554).
    if (!occtValidEllipseRadii(r, e->MinorRadius()))
      return false;
    e->SetMajorRadius(r);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DEllipseSetMinorRadius(OCCTCurve3DRef curve, double r)
{
  if (!curve)
    return false;
  try
  {
    Handle(Geom_Ellipse) e = Handle(Geom_Ellipse)::DownCast(curve->curve);
    if (e.IsNull())
      return false;
    if (!occtValidEllipseRadii(e->MajorRadius(), r))
      return false;
    e->SetMinorRadius(r);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

double OCCTCurve3DEllipseEccentricity(OCCTCurve3DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom_Ellipse) e = Handle(Geom_Ellipse)::DownCast(curve->curve);
    if (e.IsNull())
      return 0;
    return e->Eccentricity();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTCurve3DEllipseFocal(OCCTCurve3DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom_Ellipse) e = Handle(Geom_Ellipse)::DownCast(curve->curve);
    if (e.IsNull())
      return 0;
    return e->Focal();
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTCurve3DEllipseFocus1(OCCTCurve3DRef curve, double* x, double* y, double* z)
{
  *x = 0;
  *y = 0;
  *z = 0;
  if (!curve)
    return;
  try
  {
    Handle(Geom_Ellipse) e = Handle(Geom_Ellipse)::DownCast(curve->curve);
    if (e.IsNull())
      return;
    gp_Pnt f = e->Focus1();
    *x       = f.X();
    *y       = f.Y();
    *z       = f.Z();
  }
  catch (...)
  {
  }
}

void OCCTCurve3DEllipseFocus2(OCCTCurve3DRef curve, double* x, double* y, double* z)
{
  *x = 0;
  *y = 0;
  *z = 0;
  if (!curve)
    return;
  try
  {
    Handle(Geom_Ellipse) e = Handle(Geom_Ellipse)::DownCast(curve->curve);
    if (e.IsNull())
      return;
    gp_Pnt f = e->Focus2();
    *x       = f.X();
    *y       = f.Y();
    *z       = f.Z();
  }
  catch (...)
  {
  }
}

double OCCTCurve3DEllipseParameter(OCCTCurve3DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom_Ellipse) e = Handle(Geom_Ellipse)::DownCast(curve->curve);
    if (e.IsNull())
      return 0;
    return e->Parameter();
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTCurve3DEllipseDirectrix1(OCCTCurve3DRef curve,
                                  double*        px,
                                  double*        py,
                                  double*        pz,
                                  double*        dx,
                                  double*        dy,
                                  double*        dz)
{
  *px = 0;
  *py = 0;
  *pz = 0;
  *dx = 0;
  *dy = 0;
  *dz = 0;
  if (!curve)
    return;
  try
  {
    Handle(Geom_Ellipse) e = Handle(Geom_Ellipse)::DownCast(curve->curve);
    if (e.IsNull())
      return;
    gp_Ax1 d = e->Directrix1();
    *px      = d.Location().X();
    *py      = d.Location().Y();
    *pz      = d.Location().Z();
    *dx      = d.Direction().X();
    *dy      = d.Direction().Y();
    *dz      = d.Direction().Z();
  }
  catch (...)
  {
  }
}

double OCCTCurve3DHyperbolaMajorRadius(OCCTCurve3DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom_Hyperbola) h = Handle(Geom_Hyperbola)::DownCast(curve->curve);
    if (h.IsNull())
      return 0;
    return h->MajorRadius();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTCurve3DHyperbolaMinorRadius(OCCTCurve3DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom_Hyperbola) h = Handle(Geom_Hyperbola)::DownCast(curve->curve);
    if (h.IsNull())
      return 0;
    return h->MinorRadius();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTCurve3DHyperbolaSetMajorRadius(OCCTCurve3DRef curve, double r)
{
  if (!curve)
    return false;
  try
  {
    Handle(Geom_Hyperbola) h = Handle(Geom_Hyperbola)::DownCast(curve->curve);
    if (h.IsNull())
      return false;
    if (!occtValidHyperbolaRadii(r, h->MinorRadius()))
      return false;
    h->SetMajorRadius(r);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DHyperbolaSetMinorRadius(OCCTCurve3DRef curve, double r)
{
  if (!curve)
    return false;
  try
  {
    Handle(Geom_Hyperbola) h = Handle(Geom_Hyperbola)::DownCast(curve->curve);
    if (h.IsNull())
      return false;
    if (!occtValidHyperbolaRadii(h->MajorRadius(), r))
      return false;
    h->SetMinorRadius(r);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

double OCCTCurve3DHyperbolaEccentricity(OCCTCurve3DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom_Hyperbola) h = Handle(Geom_Hyperbola)::DownCast(curve->curve);
    if (h.IsNull())
      return 0;
    return h->Eccentricity();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTCurve3DHyperbolaFocal(OCCTCurve3DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom_Hyperbola) h = Handle(Geom_Hyperbola)::DownCast(curve->curve);
    if (h.IsNull())
      return 0;
    return h->Focal();
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTCurve3DHyperbolaFocus1(OCCTCurve3DRef curve, double* x, double* y, double* z)
{
  *x = 0;
  *y = 0;
  *z = 0;
  if (!curve)
    return;
  try
  {
    Handle(Geom_Hyperbola) h = Handle(Geom_Hyperbola)::DownCast(curve->curve);
    if (h.IsNull())
      return;
    gp_Pnt f = h->Focus1();
    *x       = f.X();
    *y       = f.Y();
    *z       = f.Z();
  }
  catch (...)
  {
  }
}

void OCCTCurve3DHyperbolaAsymptote1(OCCTCurve3DRef curve,
                                    double*        px,
                                    double*        py,
                                    double*        pz,
                                    double*        dx,
                                    double*        dy,
                                    double*        dz)
{
  *px = 0;
  *py = 0;
  *pz = 0;
  *dx = 0;
  *dy = 0;
  *dz = 0;
  if (!curve)
    return;
  try
  {
    Handle(Geom_Hyperbola) h = Handle(Geom_Hyperbola)::DownCast(curve->curve);
    if (h.IsNull())
      return;
    gp_Ax1 a = h->Asymptote1();
    *px      = a.Location().X();
    *py      = a.Location().Y();
    *pz      = a.Location().Z();
    *dx      = a.Direction().X();
    *dy      = a.Direction().Y();
    *dz      = a.Direction().Z();
  }
  catch (...)
  {
  }
}

double OCCTCurve3DParabolaFocal(OCCTCurve3DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom_Parabola) p = Handle(Geom_Parabola)::DownCast(curve->curve);
    if (p.IsNull())
      return 0;
    return p->Focal();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTCurve3DParabolaSetFocal(OCCTCurve3DRef curve, double focal)
{
  if (!curve)
    return false;
  try
  {
    Handle(Geom_Parabola) p = Handle(Geom_Parabola)::DownCast(curve->curve);
    if (p.IsNull())
      return false;
    if (!occtValidParabolaFocal(focal))
      return false;
    p->SetFocal(focal);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTCurve3DParabolaFocus(OCCTCurve3DRef curve, double* x, double* y, double* z)
{
  *x = 0;
  *y = 0;
  *z = 0;
  if (!curve)
    return;
  try
  {
    Handle(Geom_Parabola) p = Handle(Geom_Parabola)::DownCast(curve->curve);
    if (p.IsNull())
      return;
    gp_Pnt f = p->Focus();
    *x       = f.X();
    *y       = f.Y();
    *z       = f.Z();
  }
  catch (...)
  {
  }
}

double OCCTCurve3DParabolaEccentricity(OCCTCurve3DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom_Parabola) p = Handle(Geom_Parabola)::DownCast(curve->curve);
    if (p.IsNull())
      return 0;
    return p->Eccentricity();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTCurve3DParabolaParameter(OCCTCurve3DRef curve)
{
  if (!curve)
    return 0;
  try
  {
    Handle(Geom_Parabola) p = Handle(Geom_Parabola)::DownCast(curve->curve);
    if (p.IsNull())
      return 0;
    return p->Parameter();
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTCurve3DParabolaDirectrix(OCCTCurve3DRef curve,
                                  double*        px,
                                  double*        py,
                                  double*        pz,
                                  double*        dx,
                                  double*        dy,
                                  double*        dz)
{
  *px = 0;
  *py = 0;
  *pz = 0;
  *dx = 0;
  *dy = 0;
  *dz = 0;
  if (!curve)
    return;
  try
  {
    Handle(Geom_Parabola) p = Handle(Geom_Parabola)::DownCast(curve->curve);
    if (p.IsNull())
      return;
    gp_Ax1 d = p->Directrix();
    *px      = d.Location().X();
    *py      = d.Location().Y();
    *pz      = d.Location().Z();
    *dx      = d.Direction().X();
    *dy      = d.Direction().Y();
    *dz      = d.Direction().Z();
  }
  catch (...)
  {
  }
}

void OCCTCurve3DLineDirection(OCCTCurve3DRef curve, double* dx, double* dy, double* dz)
{
  *dx = 0;
  *dy = 0;
  *dz = 0;
  if (!curve)
    return;
  try
  {
    Handle(Geom_Line) l = Handle(Geom_Line)::DownCast(curve->curve);
    if (l.IsNull())
      return;
    gp_Dir d = l->Lin().Direction();
    *dx      = d.X();
    *dy      = d.Y();
    *dz      = d.Z();
  }
  catch (...)
  {
  }
}

void OCCTCurve3DLineLocation(OCCTCurve3DRef curve, double* x, double* y, double* z)
{
  *x = 0;
  *y = 0;
  *z = 0;
  if (!curve)
    return;
  try
  {
    Handle(Geom_Line) l = Handle(Geom_Line)::DownCast(curve->curve);
    if (l.IsNull())
      return;
    gp_Pnt loc = l->Lin().Location();
    *x         = loc.X();
    *y         = loc.Y();
    *z         = loc.Z();
  }
  catch (...)
  {
  }
}

bool OCCTCurve3DLineSetDirection(OCCTCurve3DRef curve, double dx, double dy, double dz)
{
  if (!curve)
    return false;
  try
  {
    Handle(Geom_Line) l = Handle(Geom_Line)::DownCast(curve->curve);
    if (l.IsNull())
      return false;
    l->SetDirection(gp_Dir(dx, dy, dz));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DLineSetLocation(OCCTCurve3DRef curve, double x, double y, double z)
{
  if (!curve)
    return false;
  try
  {
    Handle(Geom_Line) l = Handle(Geom_Line)::DownCast(curve->curve);
    if (l.IsNull())
      return false;
    l->SetLocation(gp_Pnt(x, y, z));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTCurve3DLinePosition(OCCTCurve3DRef curve,
                             double*        px,
                             double*        py,
                             double*        pz,
                             double*        dx,
                             double*        dy,
                             double*        dz)
{
  *px = 0;
  *py = 0;
  *pz = 0;
  *dx = 0;
  *dy = 0;
  *dz = 0;
  if (!curve)
    return;
  try
  {
    Handle(Geom_Line) l = Handle(Geom_Line)::DownCast(curve->curve);
    if (l.IsNull())
      return;
    gp_Ax1 pos = l->Position();
    *px        = pos.Location().X();
    *py        = pos.Location().Y();
    *pz        = pos.Location().Z();
    *dx        = pos.Direction().X();
    *dy        = pos.Direction().Y();
    *dz        = pos.Direction().Z();
  }
  catch (...)
  {
  }
}

void OCCTCurve3DLineLin(OCCTCurve3DRef curve,
                        double*        px,
                        double*        py,
                        double*        pz,
                        double*        dx,
                        double*        dy,
                        double*        dz)
{
  *px = 0;
  *py = 0;
  *pz = 0;
  *dx = 0;
  *dy = 0;
  *dz = 0;
  if (!curve)
    return;
  try
  {
    Handle(Geom_Line) l = Handle(Geom_Line)::DownCast(curve->curve);
    if (l.IsNull())
      return;
    gp_Lin gl = l->Lin();
    *px       = gl.Location().X();
    *py       = gl.Location().Y();
    *pz       = gl.Location().Z();
    *dx       = gl.Direction().X();
    *dy       = gl.Direction().Y();
    *dz       = gl.Direction().Z();
  }
  catch (...)
  {
  }
}

bool OCCTCurve3DReverse(OCCTCurve3DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return false; // #478
  try
  {
    curve->curve->Reverse();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

OCCTCurve3DRef OCCTCurve3DCopy(OCCTCurve3DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return nullptr; // #478
  try
  {
    Handle(Geom_Curve) copy = Handle(Geom_Curve)::DownCast(curve->curve->Copy());
    if (copy.IsNull())
      return nullptr;
    return new OCCTCurve3D(copy);
  }
  catch (...)
  {
    return nullptr;
  }
}

// Delegates to OCCTCurve3DGetContinuity: same Continuity() call, one encoding (#485).
int32_t OCCTCurve3DContinuity(OCCTCurve3DRef curve)
{
  return OCCTCurve3DGetContinuity(curve);
}

void OCCTCurve3DEvalD0(OCCTCurve3DRef curve, double u, double* x, double* y, double* z)
{
  *x = 0;
  *y = 0;
  *z = 0;
  if (!curve || curve->curve.IsNull())
    return;
  try
  {
    gp_Pnt p = curve->curve->EvalD0(u);
    *x       = p.X();
    *y       = p.Y();
    *z       = p.Z();
  }
  catch (...)
  {
  }
}

void OCCTCurve3DEvalD1(OCCTCurve3DRef curve,
                       double         u,
                       double*        px,
                       double*        py,
                       double*        pz,
                       double*        d1x,
                       double*        d1y,
                       double*        d1z)
{
  *px  = 0;
  *py  = 0;
  *pz  = 0;
  *d1x = 0;
  *d1y = 0;
  *d1z = 0;
  if (!curve || curve->curve.IsNull())
    return;
  try
  {
    Geom_Curve::ResD1 r = curve->curve->EvalD1(u);
    *px                 = r.Point.X();
    *py                 = r.Point.Y();
    *pz                 = r.Point.Z();
    *d1x                = r.D1.X();
    *d1y                = r.D1.Y();
    *d1z                = r.D1.Z();
  }
  catch (...)
  {
  }
}

void OCCTCurve3DEvalD2(OCCTCurve3DRef curve,
                       double         u,
                       double*        px,
                       double*        py,
                       double*        pz,
                       double*        d1x,
                       double*        d1y,
                       double*        d1z,
                       double*        d2x,
                       double*        d2y,
                       double*        d2z)
{
  *px  = 0;
  *py  = 0;
  *pz  = 0;
  *d1x = 0;
  *d1y = 0;
  *d1z = 0;
  *d2x = 0;
  *d2y = 0;
  *d2z = 0;
  if (!curve || curve->curve.IsNull())
    return;
  try
  {
    Geom_Curve::ResD2 r = curve->curve->EvalD2(u);
    *px                 = r.Point.X();
    *py                 = r.Point.Y();
    *pz                 = r.Point.Z();
    *d1x                = r.D1.X();
    *d1y                = r.D1.Y();
    *d1z                = r.D1.Z();
    *d2x                = r.D2.X();
    *d2y                = r.D2.Y();
    *d2z                = r.D2.Z();
  }
  catch (...)
  {
  }
}

void OCCTCurve3DEvalD3(OCCTCurve3DRef curve,
                       double         u,
                       double*        px,
                       double*        py,
                       double*        pz,
                       double*        d1x,
                       double*        d1y,
                       double*        d1z,
                       double*        d2x,
                       double*        d2y,
                       double*        d2z,
                       double*        d3x,
                       double*        d3y,
                       double*        d3z)
{
  *px  = 0;
  *py  = 0;
  *pz  = 0;
  *d1x = 0;
  *d1y = 0;
  *d1z = 0;
  *d2x = 0;
  *d2y = 0;
  *d2z = 0;
  *d3x = 0;
  *d3y = 0;
  *d3z = 0;
  if (!curve || curve->curve.IsNull())
    return;
  try
  {
    Geom_Curve::ResD3 r = curve->curve->EvalD3(u);
    *px                 = r.Point.X();
    *py                 = r.Point.Y();
    *pz                 = r.Point.Z();
    *d1x                = r.D1.X();
    *d1y                = r.D1.Y();
    *d1z                = r.D1.Z();
    *d2x                = r.D2.X();
    *d2y                = r.D2.Y();
    *d2z                = r.D2.Z();
    *d3x                = r.D3.X();
    *d3y                = r.D3.Y();
    *d3z                = r.D3.Z();
  }
  catch (...)
  {
  }
}

// Failure contract: returns false, leaving *outParameter untouched. That now means only "no curve":
// every real curve has a nearest point to every point (#615). It used to also mean "no extremum",
// which is why this replaced two functions that computed the identical projection and disagreed
// about how to report its absence: OCCTCurve3DParameterAtPoint returned curve->FirstParameter(),
// OCCTCurve3DClosestParameter returned 0, which is not even in the domain of a curve trimmed to,
// say, [3, 8] (#500).
bool OCCTCurve3DNearestParameter(OCCTCurve3DRef _Nonnull curve,
                                 double x,
                                 double y,
                                 double z,
                                 double* _Nonnull outParameter)
{
  return occtNearestProjectionOnCurve3d(curve, gp_Pnt(x, y, z), nullptr, outParameter, nullptr);
}

OCCTProjOnCurveRef OCCTProjOnCurveCreate(OCCTCurve3DRef curve, double px, double py, double pz)
{
  if (!curve || curve->curve.IsNull())
    return nullptr;
  try
  {
    auto ref = new OCCTProjOnCurve();
    ref->proj.Init(gp_Pnt(px, py, pz), curve->curve);
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTProjOnCurveRelease(OCCTProjOnCurveRef proj)
{
  delete proj;
}

int32_t OCCTProjOnCurveNbPoints(OCCTProjOnCurveRef proj)
{
  if (!proj)
    return 0;
  try
  {
    return (int32_t)proj->proj.NbPoints();
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTProjOnCurvePoint(OCCTProjOnCurveRef proj, int32_t index, double* x, double* y, double* z)
{
  if (!proj)
  {
    *x = *y = *z = 0;
    return;
  }
  try
  {
    gp_Pnt p = proj->proj.Point(index);
    *x       = p.X();
    *y       = p.Y();
    *z       = p.Z();
  }
  catch (...)
  {
    *x = *y = *z = 0;
  }
}

double OCCTProjOnCurveParameter(OCCTProjOnCurveRef proj, int32_t index)
{
  if (!proj)
    return 0;
  try
  {
    return proj->proj.Parameter(index);
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTProjOnCurveDistance(OCCTProjOnCurveRef proj, int32_t index)
{
  if (!proj)
    return -1;
  try
  {
    return proj->proj.Distance(index);
  }
  catch (...)
  {
    return -1;
  }
}

double OCCTProjOnCurveLowerDistance(OCCTProjOnCurveRef proj)
{
  if (!proj)
    return -1;
  try
  {
    return proj->proj.LowerDistance();
  }
  catch (...)
  {
    return -1;
  }
}

double OCCTProjOnCurveLowerParam(OCCTProjOnCurveRef proj)
{
  if (!proj)
    return 0;
  try
  {
    return proj->proj.LowerDistanceParameter();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTCurve3DBSplineSetKnot(OCCTCurve3DRef curve, int32_t index, double knot)
{
  if (!curve || curve->curve.IsNull())
    return false;
  try
  {
    Handle(Geom_BSplineCurve) bsc = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bsc.IsNull())
      return false;
    bsc->SetKnot(index, knot);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTCurve3DBSplineGetKnotSequence(OCCTCurve3DRef curve, double* knotSeq, int32_t* count)
{
  if (!curve || curve->curve.IsNull())
  {
    *count = 0;
    return;
  }
  try
  {
    Handle(Geom_BSplineCurve) bsc = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bsc.IsNull())
    {
      *count = 0;
      return;
    }
    TColStd_Array1OfReal seq(1, bsc->NbPoles() + bsc->Degree() + 1);
    bsc->KnotSequence(seq);
    *count = seq.Length();
    for (int i = 1; i <= seq.Length(); i++)
    {
      knotSeq[i - 1] = seq(i);
    }
  }
  catch (...)
  {
    *count = 0;
  }
}

void OCCTCurve3DBSplineGetWeights(OCCTCurve3DRef curve, double* weights)
{
  if (!curve || curve->curve.IsNull())
    return;
  try
  {
    Handle(Geom_BSplineCurve) bsc = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bsc.IsNull())
      return;
    TColStd_Array1OfReal w(1, bsc->NbPoles());
    bsc->Weights(w);
    for (int i = 1; i <= w.Length(); i++)
    {
      weights[i - 1] = w(i);
    }
  }
  catch (...)
  {
  }
}

bool OCCTCurve3DBSplineInsertKnots(OCCTCurve3DRef curve,
                                   const double*  knots,
                                   const int32_t* mults,
                                   int32_t        count,
                                   double         tol)
{
  if (!curve || curve->curve.IsNull() || count <= 0)
    return false;
  try
  {
    Handle(Geom_BSplineCurve) bsc = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bsc.IsNull())
      return false;
    TColStd_Array1OfReal    knotsArr(1, count);
    TColStd_Array1OfInteger multsArr(1, count);
    for (int i = 0; i < count; i++)
    {
      knotsArr(i + 1) = knots[i];
      multsArr(i + 1) = mults[i];
    }
    bsc->InsertKnots(knotsArr, multsArr, tol);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DBSplineMovePoint(OCCTCurve3DRef curve,
                                 double         u,
                                 double         x,
                                 double         y,
                                 double         z,
                                 int32_t        index1,
                                 int32_t        index2)
{
  if (!curve || curve->curve.IsNull())
    return false;
  try
  {
    Handle(Geom_BSplineCurve) bsc = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bsc.IsNull())
      return false;
    int first, last;
    bsc->MovePoint(u, gp_Pnt(x, y, z), index1, index2, first, last);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTCurve3DBSplineLocalValue(OCCTCurve3DRef curve,
                                  double         u,
                                  int32_t        fromK1,
                                  int32_t        toK2,
                                  double*        x,
                                  double*        y,
                                  double*        z)
{
  if (!curve || curve->curve.IsNull())
  {
    *x = *y = *z = 0;
    return;
  }
  try
  {
    Handle(Geom_BSplineCurve) bsc = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bsc.IsNull())
    {
      *x = *y = *z = 0;
      return;
    }
    gp_Pnt p = bsc->LocalValue(u, fromK1, toK2);
    *x       = p.X();
    *y       = p.Y();
    *z       = p.Z();
  }
  catch (...)
  {
    *x = *y = *z = 0;
  }
}

int32_t OCCTCurve3DBSplineMaxDegree()
{
  return (int32_t)Geom_BSplineCurve::MaxDegree();
}

int32_t OCCTCurve3DBSplineLocateU(OCCTCurve3DRef curve, double u, double tol)
{
  if (!curve || curve->curve.IsNull())
    return 0;
  try
  {
    Handle(Geom_BSplineCurve) bsc = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bsc.IsNull())
      return 0;
    int ki = 0;
    bsc->LocateU(u, tol, ki, ki);
    return (int32_t)ki;
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTCurve3DIsBounded(OCCTCurve3DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return false;
  try
  {
    Handle(Geom_BoundedCurve) bc = Handle(Geom_BoundedCurve)::DownCast(curve->curve);
    return !bc.IsNull();
  }
  catch (...)
  {
    return false;
  }
}

void OCCTCurve3DDN(OCCTCurve3DRef curve, double u, int32_t n, double* x, double* y, double* z)
{
  if (!curve || curve->curve.IsNull())
  {
    *x = *y = *z = 0;
    return;
  }
  try
  {
    gp_Vec v = curve->curve->DN(u, n);
    *x       = v.X();
    *y       = v.Y();
    *z       = v.Z();
  }
  catch (...)
  {
    *x = *y = *z = 0;
  }
}

const char* OCCTCurve3DTypeName(OCCTCurve3DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return nullptr;
  try
  {
    return curve->curve->DynamicType()->Name();
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTInterpolateWithTangents(const double* points,
                                           int32_t       count,
                                           double        t1x,
                                           double        t1y,
                                           double        t1z,
                                           double        t2x,
                                           double        t2y,
                                           double        t2z)
{
  return OCCTCurve3DInterpolateWithTangents(points, count, t1x, t1y, t1z, t2x, t2y, t2z, 1e-6);
}

int32_t OCCTCurve3DSplitAtContinuity(OCCTCurve3DRef  curve,
                                     int32_t         continuity,
                                     double          tol,
                                     OCCTCurve3DRef* outSegments,
                                     int32_t         maxSegments)
{
  if (!curve || curve->curve.IsNull() || !outSegments || maxSegments < 1)
    return 0;
  try
  {
    Handle(Geom_BSplineCurve) bsp = GeomConvert::CurveToBSplineCurve(curve->curve);
    if (bsp.IsNull())
      return 0;

    if (continuity <= 1)
    {
      // Split at C1 discontinuities
      Handle(NCollection_HArray1<Handle(Geom_BSplineCurve)>) arr;
      GeomConvert::C0BSplineToArrayOfC1BSplineCurve(bsp, arr, tol);
      if (arr.IsNull())
        return 0;
      int n = std::min((int)arr->Length(), (int)maxSegments);
      for (int i = 0; i < n; i++)
      {
        outSegments[i] = (OCCTCurve3DRef) new OCCTCurve3D{arr->Value(arr->Lower() + i)};
      }
      return n;
    }
    else
    {
      // For higher continuity, just return the single BSpline
      outSegments[0] = (OCCTCurve3DRef) new OCCTCurve3D{bsp};
      return 1;
    }
  }
  catch (...)
  {
    return 0;
  }
}

OCCTCurve3DRef _Nullable OCCTHelixBuild(double posX,
                                        double posY,
                                        double posZ,
                                        double dirX,
                                        double dirY,
                                        double dirZ,
                                        double xDirX,
                                        double xDirY,
                                        double xDirZ,
                                        double t1,
                                        double t2,
                                        double pitch,
                                        double rStart,
                                        double taperAngle,
                                        bool   isClockwise,
                                        double tolerance,
                                        double* _Nonnull tolReached)
{
  try
  {
    HelixGeom_BuilderHelix builder;
    gp_Ax2 ax2(gp_Pnt(posX, posY, posZ), gp_Dir(dirX, dirY, dirZ), gp_Dir(xDirX, xDirY, xDirZ));
    builder.SetPosition(ax2);
    builder.SetCurveParameters(t1, t2, pitch, rStart, taperAngle, isClockwise);
    builder.SetTolerance(tolerance);
    builder.Perform();
    if (builder.ErrorStatus() != 0 || builder.Curves().IsEmpty())
      return nullptr;
    *tolReached = builder.ToleranceReached();
    auto  curve = builder.Curves().First();
    auto* ref   = new OCCTCurve3D;
    ref->curve  = curve;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef _Nullable OCCTHelixCoilBuild(double t1,
                                            double t2,
                                            double pitch,
                                            double rStart,
                                            double taperAngle,
                                            bool   isClockwise,
                                            double tolerance,
                                            double* _Nonnull tolReached)
{
  try
  {
    HelixGeom_BuilderHelixCoil builder;
    builder.SetCurveParameters(t1, t2, pitch, rStart, taperAngle, isClockwise);
    builder.SetTolerance(tolerance);
    builder.Perform();
    if (builder.ErrorStatus() != 0 || builder.Curves().IsEmpty())
      return nullptr;
    *tolReached = builder.ToleranceReached();
    auto  curve = builder.Curves().First();
    auto* ref   = new OCCTCurve3D;
    ref->curve  = curve;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTHelixCurveEval(double t1,
                        double t2,
                        double pitch,
                        double rStart,
                        double taperAngle,
                        bool   isClockwise,
                        double u,
                        double* _Nonnull px,
                        double* _Nonnull py,
                        double* _Nonnull pz)
{
  try
  {
    HelixGeom_HelixCurve hc;
    hc.Load(t1, t2, pitch, rStart, taperAngle, isClockwise);
    gp_Pnt p = hc.Value(u);
    *px      = p.X();
    *py      = p.Y();
    *pz      = p.Z();
  }
  catch (...)
  {
    *px = *py = *pz = 0;
  }
}

void OCCTHelixCurveD1(double t1,
                      double t2,
                      double pitch,
                      double rStart,
                      double taperAngle,
                      bool   isClockwise,
                      double u,
                      double* _Nonnull px,
                      double* _Nonnull py,
                      double* _Nonnull pz,
                      double* _Nonnull vx,
                      double* _Nonnull vy,
                      double* _Nonnull vz)
{
  try
  {
    HelixGeom_HelixCurve hc;
    hc.Load(t1, t2, pitch, rStart, taperAngle, isClockwise);
    gp_Pnt p;
    gp_Vec v;
    hc.D1(u, p, v);
    *px = p.X();
    *py = p.Y();
    *pz = p.Z();
    *vx = v.X();
    *vy = v.Y();
    *vz = v.Z();
  }
  catch (...)
  {
    *px = *py = *pz = *vx = *vy = *vz = 0;
  }
}

void OCCTHelixCurveD2(double t1,
                      double t2,
                      double pitch,
                      double rStart,
                      double taperAngle,
                      bool   isClockwise,
                      double u,
                      double* _Nonnull px,
                      double* _Nonnull py,
                      double* _Nonnull pz,
                      double* _Nonnull v1x,
                      double* _Nonnull v1y,
                      double* _Nonnull v1z,
                      double* _Nonnull v2x,
                      double* _Nonnull v2y,
                      double* _Nonnull v2z)
{
  try
  {
    HelixGeom_HelixCurve hc;
    hc.Load(t1, t2, pitch, rStart, taperAngle, isClockwise);
    gp_Pnt p;
    gp_Vec v1, v2;
    hc.D2(u, p, v1, v2);
    *px  = p.X();
    *py  = p.Y();
    *pz  = p.Z();
    *v1x = v1.X();
    *v1y = v1.Y();
    *v1z = v1.Z();
    *v2x = v2.X();
    *v2y = v2.Y();
    *v2z = v2.Z();
  }
  catch (...)
  {
    *px = *py = *pz = *v1x = *v1y = *v1z = *v2x = *v2y = *v2z = 0;
  }
}

OCCTCurve3DRef _Nullable OCCTHelixApproxToBSpline(double t1,
                                                  double t2,
                                                  double pitch,
                                                  double rStart,
                                                  double taperAngle,
                                                  bool   isClockwise,
                                                  double tolerance,
                                                  double* _Nonnull maxError)
{
  try
  {
    Handle(Geom_BSplineCurve) bspl;
    double                    err    = 0;
    int                       status = HelixGeom_Tools::ApprHelix(t1,
                                                                  t2,
                                                                  pitch,
                                                                  rStart,
                                                                  taperAngle,
                                                                  isClockwise,
                                                                  tolerance,
                                                                  bspl,
                                                                  err);
    if (status != 0 || bspl.IsNull())
      return nullptr;
    *maxError  = err;
    auto* ref  = new OCCTCurve3D;
    ref->curve = bspl;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTCurve3DLocalTangent(OCCTCurve3DRef _Nonnull curve,
                             double u,
                             double* _Nonnull tx,
                             double* _Nonnull ty,
                             double* _Nonnull tz,
                             bool* _Nonnull isDefined)
{
  if (curve->curve.IsNull())
  {
    *isDefined = false;
    *tx        = 0;
    *ty        = 0;
    *tz        = 0;
    return;
  }
  try
  {
    GeomLProp_CLProps props = occtCurveLocalProps(curve->curve, u, 1);
    *isDefined              = props.IsTangentDefined();
    if (*isDefined)
    {
      gp_Dir d;
      props.Tangent(d);
      *tx = d.X();
      *ty = d.Y();
      *tz = d.Z();
    }
    else
    {
      *tx = 0;
      *ty = 0;
      *tz = 0;
    }
  }
  catch (...)
  {
    *isDefined = false;
    *tx        = 0;
    *ty        = 0;
    *tz        = 0;
  }
}

void OCCTCurve3DLocalNormal(OCCTCurve3DRef _Nonnull curve,
                            double u,
                            double* _Nonnull nx,
                            double* _Nonnull ny,
                            double* _Nonnull nz,
                            bool* _Nonnull isDefined)
{
  if (curve->curve.IsNull())
  {
    *isDefined = false;
    *nx        = 0;
    *ny        = 0;
    *nz        = 0;
    return;
  }
  try
  {
    GeomLProp_CLProps props = occtCurveLocalProps(curve->curve, u, 2);
    *isDefined              = props.IsTangentDefined();
    if (*isDefined)
    {
      gp_Dir n;
      props.Normal(n);
      *nx = n.X();
      *ny = n.Y();
      *nz = n.Z();
    }
    else
    {
      *nx = 0;
      *ny = 0;
      *nz = 0;
    }
  }
  catch (...)
  {
    *isDefined = false;
    *nx        = 0;
    *ny        = 0;
    *nz        = 0;
  }
}

void OCCTCurve3DLocalCentreOfCurvature(OCCTCurve3DRef _Nonnull curve,
                                       double u,
                                       double* _Nonnull cx,
                                       double* _Nonnull cy,
                                       double* _Nonnull cz,
                                       bool* _Nonnull isDefined)
{
  if (curve->curve.IsNull())
  {
    *isDefined = false;
    *cx        = 0;
    *cy        = 0;
    *cz        = 0;
    return;
  }
  try
  {
    GeomLProp_CLProps props = occtCurveLocalProps(curve->curve, u, 2);
    // Two separate 1000x splits from the canonical sibling used to live on the next line: the
    // props resolution (above) and this gate's own 1e-10 literal, which also let a cusp's
    // RealLast() curvature through into a (nan, inf, nan) centre. Both now share one value.
    if (props.IsTangentDefined() && occtCurveCurvatureIsInvertible(props.Curvature()))
    {
      gp_Pnt p;
      props.CentreOfCurvature(p);
      *cx        = p.X();
      *cy        = p.Y();
      *cz        = p.Z();
      *isDefined = true;
    }
    else
    {
      *cx        = 0;
      *cy        = 0;
      *cz        = 0;
      *isDefined = false;
    }
  }
  catch (...)
  {
    *isDefined = false;
    *cx        = 0;
    *cy        = 0;
    *cz        = 0;
  }
}

bool OCCTCurve3DIsCN(OCCTCurve3DRef _Nonnull curve, int32_t n)
{
  try
  {
    auto c = *(occ::handle<Geom_Curve>*)curve;
    if (c.IsNull())
      return false;
    return c->IsCN(n);
  }
  catch (...)
  {
    return false;
  }
}

double OCCTCurve3DReversedParameter(OCCTCurve3DRef _Nonnull curve, double u)
{
  try
  {
    auto c = *(occ::handle<Geom_Curve>*)curve;
    if (c.IsNull())
      return u;
    return c->ReversedParameter(u);
  }
  catch (...)
  {
    return u;
  }
}

double OCCTCurve3DParametricTransformation(OCCTCurve3DRef _Nonnull curve,
                                           const double* _Nonnull trsf12)
{
  try
  {
    auto c = *(occ::handle<Geom_Curve>*)curve;
    if (c.IsNull())
      return 1.0;
    // #1009: GROUPED layout, nine rotation values then three translations. The reader is shared
    // with OCCTShapeTransformed and OCCTDocumentAddComponentMatrix; the layout is in its name
    // because the INTERLEAVED sibling accepts the same array and builds a different transform.
    return c->ParametricTransformation(occtTrsfFromMatrix12Grouped(trsf12));
  }
  catch (...)
  {
    return 1.0;
  }
}

double OCCTCurve3DBezierResolution(OCCTCurve3DRef _Nonnull curve, double tolerance3d)
{
  try
  {
    auto c = *(occ::handle<Geom_Curve>*)curve;
    if (c.IsNull())
      return 0;
    auto bez = occ::handle<Geom_BezierCurve>::DownCast(c);
    if (bez.IsNull())
      return 0;
    double uTol = 0;
    bez->Resolution(tolerance3d, uTol);
    return uTol;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTCurve3DBezierMaxDegree(void)
{
  return Geom_BezierCurve::MaxDegree();
}

bool OCCTCurve3DBSplineSetNotPeriodic(OCCTCurve3DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return false;
  try
  {
    bs->SetNotPeriodic();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DBSplineSetOrigin(OCCTCurve3DRef curve, int32_t index)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return false;
  try
  {
    bs->SetOrigin(index);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DBSplineIncreaseMultiplicity(OCCTCurve3DRef curve, int32_t index, int32_t mult)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return false;
  try
  {
    bs->IncreaseMultiplicity(index, mult);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DBSplineIncrementMultiplicity(OCCTCurve3DRef curve,
                                             int32_t        index1,
                                             int32_t        index2,
                                             int32_t        step)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return false;
  try
  {
    bs->IncrementMultiplicity(index1, index2, step);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DBSplineSetKnots(OCCTCurve3DRef curve, const double* knots, int32_t count)
{
  if (!curve || curve->curve.IsNull() || !knots || count <= 0)
    return false;
  Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull() || count != bs->NbKnots())
    return false;
  try
  {
    TColStd_Array1OfReal kArr(1, count);
    for (int32_t i = 0; i < count; i++)
    {
      kArr.SetValue(i + 1, knots[i]);
    }
    bs->SetKnots(kArr);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DBSplineReverse(OCCTCurve3DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return false;
  try
  {
    bs->Reverse();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DBSplineMovePointAndTangent(OCCTCurve3DRef curve,
                                           double         u,
                                           double         px,
                                           double         py,
                                           double         pz,
                                           double         tx,
                                           double         ty,
                                           double         tz,
                                           double         tolerance,
                                           int32_t        startIndex,
                                           int32_t        endIndex)
{
  if (!curve || curve->curve.IsNull())
    return false;
  Handle(Geom_BSplineCurve) bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
  if (bs.IsNull())
    return false;
  try
  {
    Standard_Integer errorStatus = 0;
    bs->MovePointAndTangent(u,
                            gp_Pnt(px, py, pz),
                            gp_Vec(tx, ty, tz),
                            tolerance,
                            startIndex,
                            endIndex,
                            errorStatus);
    return (errorStatus == 0);
  }
  catch (...)
  {
    return false;
  }
}

double OCCTCurve3DPeriod(OCCTCurve3DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return 0.0; // #478
  try
  {
    if (!curve->curve->IsPeriodic())
      return 0.0;
    return curve->curve->Period();
  }
  catch (...)
  {
    return 0.0;
  }
}

double OCCTCurve3DFirstParameter(OCCTCurve3DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return 0.0; // #478
  try
  {
    return curve->curve->FirstParameter();
  }
  catch (...)
  {
    return 0.0;
  }
}

double OCCTCurve3DLastParameter(OCCTCurve3DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return 0.0; // #478
  try
  {
    return curve->curve->LastParameter();
  }
  catch (...)
  {
    return 0.0;
  }
}

void OCCTCurve3DBezierStartPoint(OCCTCurve3DRef curve, double* x, double* y, double* z)
{
  if (!curve)
    return;
  auto bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return;
  try
  {
    gp_Pnt P = bz->StartPoint();
    *x       = P.X();
    *y       = P.Y();
    *z       = P.Z();
  }
  catch (...)
  {
  }
}

void OCCTCurve3DBezierEndPoint(OCCTCurve3DRef curve, double* x, double* y, double* z)
{
  if (!curve)
    return;
  auto bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return;
  try
  {
    gp_Pnt P = bz->EndPoint();
    *x       = P.X();
    *y       = P.Y();
    *z       = P.Z();
  }
  catch (...)
  {
  }
}

void OCCTCurve3DBezierGetPoles(OCCTCurve3DRef curve, double* poles)
{
  if (!curve || !poles)
    return;
  auto bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return;
  try
  {
    const auto& p   = bz->Poles();
    int         idx = 0;
    for (int i = p.Lower(); i <= p.Upper(); i++)
    {
      poles[idx++] = p(i).X();
      poles[idx++] = p(i).Y();
      poles[idx++] = p(i).Z();
    }
  }
  catch (...)
  {
  }
}

bool OCCTCurve3DBezierGetWeights(OCCTCurve3DRef curve, double* weights)
{
  if (!curve || !weights)
    return false;
  auto bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return false;
  try
  {
    const auto* w = bz->Weights();
    if (!w)
      return false;
    for (int i = w->Lower(); i <= w->Upper(); i++)
    {
      weights[i - w->Lower()] = (*w)(i);
    }
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DBezierIsClosed(OCCTCurve3DRef curve)
{
  if (!curve)
    return false;
  auto bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return false;
  try
  {
    return bz->IsClosed();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DBezierIsPeriodic(OCCTCurve3DRef curve)
{
  if (!curve)
    return false;
  auto bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return false;
  try
  {
    return bz->IsPeriodic();
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTCurve3DBezierContinuity(OCCTCurve3DRef curve)
{
  if (!curve)
    return 0;
  auto bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return 0;
  try
  {
    return (int32_t)bz->Continuity();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTCurve3DBezierIsCN(OCCTCurve3DRef curve, int32_t n)
{
  if (!curve)
    return false;
  auto bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return false;
  try
  {
    return bz->IsCN(n);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DBezierInsertPoleBefore(OCCTCurve3DRef curve,
                                       int32_t        index,
                                       double         x,
                                       double         y,
                                       double         z)
{
  if (!curve)
    return false;
  auto bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return false;
  try
  {
    bz->InsertPoleBefore(index, gp_Pnt(x, y, z));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DBezierReverse(OCCTCurve3DRef curve)
{
  if (!curve)
    return false;
  auto bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return false;
  try
  {
    bz->Reverse();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DBezierSetPoleWithWeight(OCCTCurve3DRef curve,
                                        int32_t        index,
                                        double         x,
                                        double         y,
                                        double         z,
                                        double         weight)
{
  if (!curve)
    return false;
  auto bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
  if (bz.IsNull())
    return false;
  try
  {
    bz->SetPole(index, gp_Pnt(x, y, z), weight);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DTransform(OCCTCurve3DRef curve,
                          int32_t        transformType,
                          double         p1,
                          double         p2,
                          double         p3,
                          double         p4,
                          double         p5,
                          double         p6,
                          double         p7)
{
  if (!curve || curve->curve.IsNull())
    return false;
  try
  {
    gp_Trsf trsf;
    if (!occtBuildTrsf3D(trsf, transformType, p1, p2, p3, p4, p5, p6, p7))
      return false;
    curve->curve->Transform(trsf);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DBSplinePeriodicNormalization(OCCTCurve3DRef curve, double* u)
{
  if (!curve || !u)
    return false;
  auto bsc = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
  if (bsc.IsNull() || !bsc->IsPeriodic())
    return false;
  try
  {
    bsc->PeriodicNormalization(*u);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DBSplineIsG1(OCCTCurve3DRef curve, double tFirst, double tLast, double angTol)
{
  if (!curve)
    return false;
  auto bsc = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
  if (bsc.IsNull())
    return false;
  try
  {
    return bsc->IsG1(tFirst, tLast, angTol);
  }
  catch (...)
  {
    return false;
  }
}

void OCCTCurve3DBSplineLocalD0(OCCTCurve3DRef curve,
                               double         u,
                               int32_t        fromK1,
                               int32_t        toK2,
                               double*        px,
                               double*        py,
                               double*        pz)
{
  if (!curve || curve->curve.IsNull())
  {
    *px = *py = *pz = 0;
    return;
  }
  try
  {
    auto bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull())
    {
      *px = *py = *pz = 0;
      return;
    }
    gp_Pnt p;
    bs->LocalD0(u, fromK1, toK2, p);
    *px = p.X();
    *py = p.Y();
    *pz = p.Z();
  }
  catch (...)
  {
    *px = *py = *pz = 0;
  }
}

void OCCTCurve3DBSplineLocalD1(OCCTCurve3DRef curve,
                               double         u,
                               int32_t        fromK1,
                               int32_t        toK2,
                               double*        px,
                               double*        py,
                               double*        pz,
                               double*        vx,
                               double*        vy,
                               double*        vz)
{
  if (!curve || curve->curve.IsNull())
  {
    *px = *py = *pz = *vx = *vy = *vz = 0;
    return;
  }
  try
  {
    auto bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull())
    {
      *px = *py = *pz = *vx = *vy = *vz = 0;
      return;
    }
    gp_Pnt p;
    gp_Vec v1;
    bs->LocalD1(u, fromK1, toK2, p, v1);
    *px = p.X();
    *py = p.Y();
    *pz = p.Z();
    *vx = v1.X();
    *vy = v1.Y();
    *vz = v1.Z();
  }
  catch (...)
  {
    *px = *py = *pz = *vx = *vy = *vz = 0;
  }
}

void OCCTCurve3DBSplineLocalD2(OCCTCurve3DRef curve,
                               double         u,
                               int32_t        fromK1,
                               int32_t        toK2,
                               double*        px,
                               double*        py,
                               double*        pz,
                               double*        v1x,
                               double*        v1y,
                               double*        v1z,
                               double*        v2x,
                               double*        v2y,
                               double*        v2z)
{
  if (!curve || curve->curve.IsNull())
  {
    *px = *py = *pz = *v1x = *v1y = *v1z = *v2x = *v2y = *v2z = 0;
    return;
  }
  try
  {
    auto bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull())
    {
      *px = *py = *pz = *v1x = *v1y = *v1z = *v2x = *v2y = *v2z = 0;
      return;
    }
    gp_Pnt p;
    gp_Vec v1, v2;
    bs->LocalD2(u, fromK1, toK2, p, v1, v2);
    *px  = p.X();
    *py  = p.Y();
    *pz  = p.Z();
    *v1x = v1.X();
    *v1y = v1.Y();
    *v1z = v1.Z();
    *v2x = v2.X();
    *v2y = v2.Y();
    *v2z = v2.Z();
  }
  catch (...)
  {
    *px = *py = *pz = *v1x = *v1y = *v1z = *v2x = *v2y = *v2z = 0;
  }
}

void OCCTCurve3DBSplineLocalD3(OCCTCurve3DRef curve,
                               double         u,
                               int32_t        fromK1,
                               int32_t        toK2,
                               double*        px,
                               double*        py,
                               double*        pz,
                               double*        v1x,
                               double*        v1y,
                               double*        v1z,
                               double*        v2x,
                               double*        v2y,
                               double*        v2z,
                               double*        v3x,
                               double*        v3y,
                               double*        v3z)
{
  if (!curve || curve->curve.IsNull())
  {
    *px = *py = *pz = *v1x = *v1y = *v1z = *v2x = *v2y = *v2z = *v3x = *v3y = *v3z = 0;
    return;
  }
  try
  {
    auto bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull())
    {
      *px = *py = *pz = *v1x = *v1y = *v1z = *v2x = *v2y = *v2z = *v3x = *v3y = *v3z = 0;
      return;
    }
    gp_Pnt p;
    gp_Vec v1, v2, v3;
    bs->LocalD3(u, fromK1, toK2, p, v1, v2, v3);
    *px  = p.X();
    *py  = p.Y();
    *pz  = p.Z();
    *v1x = v1.X();
    *v1y = v1.Y();
    *v1z = v1.Z();
    *v2x = v2.X();
    *v2y = v2.Y();
    *v2z = v2.Z();
    *v3x = v3.X();
    *v3y = v3.Y();
    *v3z = v3.Z();
  }
  catch (...)
  {
    *px = *py = *pz = *v1x = *v1y = *v1z = *v2x = *v2y = *v2z = *v3x = *v3y = *v3z = 0;
  }
}

void OCCTCurve3DBSplineLocalDN(OCCTCurve3DRef curve,
                               double         u,
                               int32_t        fromK1,
                               int32_t        toK2,
                               int32_t        n,
                               double*        vx,
                               double*        vy,
                               double*        vz)
{
  if (!curve || curve->curve.IsNull())
  {
    *vx = *vy = *vz = 0;
    return;
  }
  try
  {
    auto bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bs.IsNull())
    {
      *vx = *vy = *vz = 0;
      return;
    }
    gp_Vec v = bs->LocalDN(u, fromK1, toK2, n);
    *vx      = v.X();
    *vy      = v.Y();
    *vz      = v.Z();
  }
  catch (...)
  {
    *vx = *vy = *vz = 0;
  }
}

int32_t OCCTExtremaPCCurve(OCCTCurve3DRef curve,
                           double         px,
                           double         py,
                           double         pz,
                           double*        outParams,
                           double*        outDistances,
                           double*        outPx,
                           double*        outPy,
                           double*        outPz,
                           int32_t        maxResults)
{
  return occtExtremaPCCurveImpl(curve,
                                px,
                                py,
                                pz,
                                outParams,
                                outDistances,
                                outPx,
                                outPy,
                                outPz,
                                maxResults,
                                0,
                                0,
                                false);
}

int32_t OCCTExtremaPCCurveBounded(OCCTCurve3DRef curve,
                                  double         px,
                                  double         py,
                                  double         pz,
                                  double         uMin,
                                  double         uMax,
                                  double*        outParams,
                                  double*        outDistances,
                                  double*        outPx,
                                  double*        outPy,
                                  double*        outPz,
                                  int32_t        maxResults)
{
  return occtExtremaPCCurveImpl(curve,
                                px,
                                py,
                                pz,
                                outParams,
                                outDistances,
                                outPx,
                                outPy,
                                outPz,
                                maxResults,
                                uMin,
                                uMax,
                                true);
}

double OCCTExtremaPCMinDistance(OCCTCurve3DRef curve, double px, double py, double pz)
{
  if (!curve || curve->curve.IsNull())
    return -1.0;
  try
  {
    ExtremaPC_Curve extPC(curve->curve);
    if (!extPC.IsInitialized())
      return -1.0;
    const auto& result = extPC.Perform(gp_Pnt(px, py, pz), 1e-9);
    if (!result.IsDone() || result.NbExt() == 0)
      return -1.0;
    return std::sqrt(result.MinSquareDistance());
  }
  catch (...)
  {
    return -1.0;
  }
}

OCCTBSplineApproxInterpRef OCCTBSplineApproxInterpCreate(const double* points,
                                                         int32_t       count,
                                                         int32_t       nbControlPts,
                                                         int32_t       degree,
                                                         bool          continuousIfClosed)
{
  if (!points || count < 2)
    return nullptr;
  (void)nbControlPts;
  (void)continuousIfClosed; // advisory only, see section comment
  try
  {
    auto ref = new OCCTBSplineApproxInterp(count);
    for (int i = 0; i < count; i++)
      ref->pts(i + 1) = gp_Pnt(points[i * 3], points[i * 3 + 1], points[i * 3 + 2]);
    if (degree >= 1 && degree <= 25)
    {
      ref->degMin = std::min(3, degree);
      ref->degMax = std::max(degree, 8);
    }
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTBSplineApproxInterpRelease(OCCTBSplineApproxInterpRef ref)
{
  delete ref;
}

void OCCTBSplineApproxInterpInterpolatePoint(OCCTBSplineApproxInterpRef ref,
                                             int32_t                    pointIndex,
                                             bool                       withKink)
{
  (void)ref;
  (void)pointIndex;
  (void)withKink; // no-op: PointsToBSpline has no exact-point control
}

void OCCTBSplineApproxInterpPerform(OCCTBSplineApproxInterpRef ref)
{
  if (ref)
    ref->run();
}

void OCCTBSplineApproxInterpPerformOptimal(OCCTBSplineApproxInterpRef ref, int32_t maxIter)
{
  (void)maxIter;
  if (ref)
    ref->run();
}

bool OCCTBSplineApproxInterpIsDone(OCCTBSplineApproxInterpRef ref)
{
  return ref && ref->done;
}

OCCTCurve3DRef OCCTBSplineApproxInterpCurve(OCCTBSplineApproxInterpRef ref)
{
  if (!ref || !ref->done || ref->result.IsNull())
    return nullptr;
  try
  {
    auto cref   = new OCCTCurve3D();
    cref->curve = ref->result;
    return cref;
  }
  catch (...)
  {
    return nullptr;
  }
}

double OCCTBSplineApproxInterpMaxError(OCCTBSplineApproxInterpRef ref)
{
  return ref ? ref->maxErr : -1.0;
}

void OCCTBSplineApproxInterpSetAlpha(OCCTBSplineApproxInterpRef, double) {} // no-op

void OCCTBSplineApproxInterpSetMinPivot(OCCTBSplineApproxInterpRef, double) {} // no-op

void OCCTBSplineApproxInterpSetClosedTol(OCCTBSplineApproxInterpRef, double) {} // no-op

void OCCTBSplineApproxInterpSetKnotTol(OCCTBSplineApproxInterpRef, double) {} // no-op

void OCCTBSplineApproxInterpSetConvergenceTol(OCCTBSplineApproxInterpRef ref, double val)
{
  if (ref && val > 0)
    ref->tol3D = val; // drives the 3D fit tolerance
}

void OCCTBSplineApproxInterpSetProjectionTol(OCCTBSplineApproxInterpRef ref, double val)
{
  if (ref && val > 0)
    ref->tol3D = std::min(ref->tol3D, val);
}

OCCTCurve3DRef OCCTGeomAdaptorTransformedCurveCreate(OCCTCurve3DRef curve,
                                                     double         tx,
                                                     double         ty,
                                                     double         tz)
{
  if (!curve || curve->curve.IsNull())
    return nullptr;
  try
  {
    gp_Trsf trsf;
    trsf.SetTranslation(gp_Vec(tx, ty, tz));
    // Create a trimmed copy of the original curve with the transform applied
    Handle(Geom_Curve) origCurve = curve->curve;
    Handle(Geom_Curve) copyCurve = Handle(Geom_Curve)::DownCast(origCurve->Copy());
    if (copyCurve.IsNull())
      return nullptr;
    copyCurve->Transform(trsf);
    auto ref   = new OCCTCurve3D();
    ref->curve = copyCurve;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCompCurveRef OCCTCompCurveCreate(OCCTWireRef wire)
{
  if (!wire)
    return nullptr;
  try
  {
    return new OCCTCompCurve(wire->wire);
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTCompCurveRelease(OCCTCompCurveRef ref)
{
  delete ref;
}

double OCCTCompCurveLength(OCCTCompCurveRef ref)
{
  if (!ref)
    return -1.0;
  try
  {
    return adaptorLength(ref->adaptor);
  }
  catch (...)
  {
    return -1.0;
  }
}

void OCCTCompCurveParamRange(OCCTCompCurveRef ref, double* first, double* last)
{
  if (!ref)
    return;
  try
  {
    adaptorParamRange(ref->adaptor, first, last);
  }
  catch (...)
  {
  }
}

bool OCCTCompCurvePointAtParam(OCCTCompCurveRef ref, double u, double* x, double* y, double* z)
{
  if (!ref)
    return false;
  try
  {
    return adaptorPointAtParam(ref->adaptor, u, x, y, z);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCompCurveTangentAtParam(OCCTCompCurveRef ref, double u, double* x, double* y, double* z)
{
  if (!ref)
    return false;
  try
  {
    return adaptorTangentAtParam(ref->adaptor, u, x, y, z);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCompCurveParamAtAbscissa(OCCTCompCurveRef ref, double s, double* outParam)
{
  if (!ref)
    return false;
  try
  {
    return adaptorParamAtAbscissa(ref->adaptor, s, outParam);
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTCompCurveSampleUniform(OCCTCompCurveRef ref, int32_t count, double* outXYZ)
{
  if (!ref)
    return 0;
  try
  {
    return sampleAdaptorUniform(ref->adaptor, count, outXYZ);
  }
  catch (...)
  {
    return 0;
  }
}

OCCTEdgeCurveRef OCCTEdgeCurveCreate(OCCTEdgeRef edge)
{
  if (!edge)
    return nullptr;
  try
  {
    return new OCCTEdgeCurve(edge->edge);
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTEdgeCurveRelease(OCCTEdgeCurveRef ref)
{
  delete ref;
}

double OCCTEdgeCurveLength(OCCTEdgeCurveRef ref)
{
  if (!ref)
    return -1.0;
  try
  {
    return adaptorLength(ref->adaptor);
  }
  catch (...)
  {
    return -1.0;
  }
}

void OCCTEdgeCurveParamRange(OCCTEdgeCurveRef ref, double* first, double* last)
{
  if (!ref)
    return;
  try
  {
    adaptorParamRange(ref->adaptor, first, last);
  }
  catch (...)
  {
  }
}

bool OCCTEdgeCurvePointAtParam(OCCTEdgeCurveRef ref, double u, double* x, double* y, double* z)
{
  if (!ref)
    return false;
  try
  {
    return adaptorPointAtParam(ref->adaptor, u, x, y, z);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeCurveTangentAtParam(OCCTEdgeCurveRef ref, double u, double* x, double* y, double* z)
{
  if (!ref)
    return false;
  try
  {
    return adaptorTangentAtParam(ref->adaptor, u, x, y, z);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeCurveParamAtAbscissa(OCCTEdgeCurveRef ref, double s, double* outParam)
{
  if (!ref)
    return false;
  try
  {
    return adaptorParamAtAbscissa(ref->adaptor, s, outParam);
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTEdgeCurveSampleUniform(OCCTEdgeCurveRef ref, int32_t count, double* outXYZ)
{
  if (!ref)
    return 0;
  try
  {
    return sampleAdaptorUniform(ref->adaptor, count, outXYZ);
  }
  catch (...)
  {
    return 0;
  }
}
