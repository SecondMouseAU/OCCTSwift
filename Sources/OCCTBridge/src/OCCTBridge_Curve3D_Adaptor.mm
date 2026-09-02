//
//  OCCTBridge_Curve3D_Adaptor.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Curve3D.mm (#1380): BRepAdaptor, GeomAdaptor.
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

// A non-finite bound is rejected here rather than handed to GCPnts, which answers it differently
// per curve type -- see occtValidParameterRange (OCCTBridge_Internal.h) for the measurements. #548.
// The measurement itself is occtAdaptorLengthBetween (same header), which measures the part of the
// range that lies on the curve, winding a curve whose domain covers a period. #600.
double OCCTCurve3DGetLengthBetween(OCCTCurve3DRef c, double u1, double u2)
{
  if (!c || c->curve.IsNull())
    return -1.0;
  if (!occtValidParameterRange(u1, u2))
    return -1.0;
  try
  {
    GeomAdaptor_Curve adaptor(c->curve);
    return occtAdaptorLengthBetween(adaptor, u1, u2);
  }
  catch (...)
  {
    return -1.0;
  }
}

int32_t OCCTCurve3DDrawAdaptive(OCCTCurve3DRef c,
                                double         angularDefl,
                                double         chordalDefl,
                                double*        outXYZ,
                                int32_t        maxPoints)
{
  if (!c || c->curve.IsNull() || !outXYZ || maxPoints <= 0)
    return 0;
  try
  {
    GeomAdaptor_Curve           adaptor(c->curve);
    GCPnts_TangentialDeflection sampler(adaptor, angularDefl, chordalDefl);
    int32_t                     n = std::min((int32_t)sampler.NbPoints(), maxPoints);
    for (int32_t i = 0; i < n; i++)
    {
      gp_Pnt p          = sampler.Value(i + 1);
      outXYZ[i * 3]     = p.X();
      outXYZ[i * 3 + 1] = p.Y();
      outXYZ[i * 3 + 2] = p.Z();
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTCurve3DDrawUniform(OCCTCurve3DRef c, int32_t pointCount, double* outXYZ)
{
  // outXYZ holds pointCount triples, which is not what the sampler is bounded by. See
  // occtSamplerKept/occtSamplerIndex in OCCTBridge_Internal.h (#501).
  if (!c || c->curve.IsNull() || !outXYZ || !occtValidSampleCount(pointCount))
    return 0;
  try
  {
    GeomAdaptor_Curve      adaptor(c->curve);
    GCPnts_UniformAbscissa sampler(adaptor, pointCount);
    if (!sampler.IsDone())
      return 0;
    int32_t total = sampler.NbPoints();
    int32_t n     = occtSamplerKept(total, pointCount);
    for (int32_t i = 0; i < n; i++)
    {
      double u          = sampler.Parameter(occtSamplerIndex(i, n, total));
      gp_Pnt p          = adaptor.Value(u);
      outXYZ[i * 3]     = p.X();
      outXYZ[i * 3 + 1] = p.Y();
      outXYZ[i * 3 + 2] = p.Z();
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTCurve3DDrawDeflection(OCCTCurve3DRef c,
                                  double         deflection,
                                  double*        outXYZ,
                                  int32_t        maxPoints)
{
  if (!c || c->curve.IsNull() || !outXYZ || maxPoints <= 0)
    return 0;
  try
  {
    GeomAdaptor_Curve        adaptor(c->curve);
    GCPnts_UniformDeflection sampler(adaptor, deflection);
    if (!sampler.IsDone())
      return 0;
    int32_t n = std::min((int32_t)sampler.NbPoints(), maxPoints);
    for (int32_t i = 0; i < n; i++)
    {
      gp_Pnt p          = sampler.Value(i + 1);
      outXYZ[i * 3]     = p.X();
      outXYZ[i * 3 + 1] = p.Y();
      outXYZ[i * 3 + 2] = p.Z();
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTCurve3DGetBoundingBox(OCCTCurve3DRef c,
                               double*        xMin,
                               double*        yMin,
                               double*        zMin,
                               double*        xMax,
                               double*        yMax,
                               double*        zMax)
{
  if (!c || c->curve.IsNull() || !xMin || !yMin || !zMin || !xMax || !yMax || !zMax)
    return false;
  try
  {
    GeomAdaptor_Curve adaptor(c->curve);
    Bnd_Box           box;
    BndLib_Add3dCurve::Add(adaptor, 0.01, box);
    if (box.IsVoid())
      return false;
    box.Get(*xMin, *yMin, *zMin, *xMax, *yMax, *zMax);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeApproxCurveInfo(OCCTEdgeRef edge,
                             double      tolerance,
                             int32_t     maxSegments,
                             int32_t     maxDegree,
                             double*     outMaxError,
                             int32_t*    outDegree,
                             int32_t*    outNbPoles)
{
  if (!occtShapeIsPresent(edge) || !outMaxError || !outDegree || !outNbPoles)
    return false;
  try
  {
    BRepAdaptor_Curve adaptorCurve(edge->edge);
    Approx_Curve3d    approx(new BRepAdaptor_Curve(adaptorCurve),
                             tolerance,
                             GeomAbs_C2,
                             maxSegments,
                             maxDegree);
    if (!approx.IsDone() && !approx.HasResult())
      return false;
    *outMaxError = approx.MaxError();
    auto bspline = approx.Curve();
    if (bspline.IsNull())
      return false;
    *outDegree  = bspline->Degree();
    *outNbPoles = bspline->NbPoles();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

OCCTShapeRef OCCTApproxCurveOnSurface(OCCTShapeRef edge,
                                      OCCTShapeRef face,
                                      double       tolerance,
                                      int32_t      maxSegments,
                                      int32_t      maxDegree)
{
  // #1026: occtShapeIsType (OCCTBridge_Internal.h) folds the pointer test into the null-shape test
  // TopoDS_Shape::ShapeType() needs; without the second this refused a wrong-typed shape and
  // crashed on a null one.
  if (!occtShapeIsType(edge, TopAbs_EDGE) || !occtShapeIsType(face, TopAbs_FACE))
    return nullptr;
  try
  {
    TopoDS_Edge e = TopoDS::Edge(edge->shape);
    TopoDS_Face f = TopoDS::Face(face->shape);

    // Get PCurve and surface
    double               first, last;
    Handle(Geom2d_Curve) pcurve = BRep_Tool::CurveOnSurface(e, f, first, last);
    if (pcurve.IsNull())
      return nullptr;

    Handle(Geom_Surface) surface = BRep_Tool::Surface(f);
    if (surface.IsNull())
      return nullptr;

    Handle(Geom2dAdaptor_Curve) curveAdaptor = new Geom2dAdaptor_Curve(pcurve, first, last);
    Handle(GeomAdaptor_Surface) surfAdaptor  = new GeomAdaptor_Surface(surface);

    Approx_CurveOnSurface approx(curveAdaptor, surfAdaptor, first, last, tolerance);
    approx.Perform(maxSegments, maxDegree, GeomAbs_C2);

    if (!approx.IsDone() || !approx.HasResult())
      return nullptr;
    Handle(Geom_BSplineCurve) curve3d = approx.Curve3d();
    if (curve3d.IsNull())
      return nullptr;

    BRepBuilderAPI_MakeEdge edgeMaker(curve3d);
    if (!edgeMaker.IsDone())
      return nullptr;
    return new OCCTShape(edgeMaker.Edge());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef _Nullable OCCTApproxCurvilinearParameter(OCCTShapeRef edgeShape,
                                                      double       tolerance,
                                                      int          maxDegree,
                                                      int          maxSegments)
{
  if (!edgeShape)
    return nullptr;
  try
  {
    TopoDS_Edge                 edge    = TopoDS::Edge(edgeShape->shape);
    Handle(BRepAdaptor_Curve)   adaptor = new BRepAdaptor_Curve(edge);
    Approx_CurvilinearParameter approx(adaptor, tolerance, GeomAbs_C1, maxDegree, maxSegments);
    if (!approx.IsDone() || !approx.HasResult())
      return nullptr;
    Handle(Geom_BSplineCurve) curve = approx.Curve3d();
    if (curve.IsNull())
      return nullptr;
    BRepBuilderAPI_MakeEdge me(curve);
    if (!me.IsDone())
      return nullptr;
    return new OCCTShape(me.Edge());
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTGCPntsTangentialDeflection(OCCTEdgeRef _Nonnull edge,
                                       double  angularDeflection,
                                       double  curvatureDeflection,
                                       int32_t minPoints,
                                       double* _Nonnull params,
                                       double* _Nullable coords,
                                       int32_t maxPoints)
{
  if (!occtShapeIsPresent(edge))
    return 0;
  try
  {
    BRepAdaptor_Curve           curve(TopoDS::Edge(edge->edge));
    GCPnts_TangentialDeflection sampler(curve,
                                        angularDeflection,
                                        curvatureDeflection,
                                        std::max((int)minPoints, 2));
    int32_t                     count = std::min((int32_t)sampler.NbPoints(), maxPoints);
    for (int32_t i = 0; i < count; i++)
    {
      params[i] = sampler.Parameter(i + 1);
      if (coords)
      {
        gp_Pnt pt         = sampler.Value(i + 1);
        coords[i * 3]     = pt.X();
        coords[i * 3 + 1] = pt.Y();
        coords[i * 3 + 2] = pt.Z();
      }
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTGCPntsTangentialDeflectionCurve(OCCTCurve3DRef _Nonnull curve,
                                            double  angularDeflection,
                                            double  curvatureDeflection,
                                            int32_t minPoints,
                                            double* _Nonnull params,
                                            double* _Nullable coords,
                                            int32_t maxPoints)
{
  if (!curve || curve->curve.IsNull())
    return 0;
  try
  {
    GeomAdaptor_Curve           adaptor(curve->curve);
    GCPnts_TangentialDeflection sampler(adaptor,
                                        angularDeflection,
                                        curvatureDeflection,
                                        std::max((int)minPoints, 2));
    int32_t                     count = std::min((int32_t)sampler.NbPoints(), maxPoints);
    for (int32_t i = 0; i < count; i++)
    {
      params[i] = sampler.Parameter(i + 1);
      if (coords)
      {
        gp_Pnt pt         = sampler.Value(i + 1);
        coords[i * 3]     = pt.X();
        coords[i * 3 + 1] = pt.Y();
        coords[i * 3 + 2] = pt.Z();
      }
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

OCCTExtremaExtCCResult OCCTExtremaExtCC(OCCTCurve3DRef curve1,
                                        double         u1First,
                                        double         u1Last,
                                        OCCTCurve3DRef curve2,
                                        double         u2First,
                                        double         u2Last)
{
  OCCTExtremaExtCCResult result = {false, false, 0};
  try
  {
    auto*                     c1  = (OCCTCurve3D*)curve1;
    auto*                     c2  = (OCCTCurve3D*)curve2;
    Handle(GeomAdaptor_Curve) ac1 = new GeomAdaptor_Curve(c1->curve, u1First, u1Last);
    Handle(GeomAdaptor_Curve) ac2 = new GeomAdaptor_Curve(c2->curve, u2First, u2Last);
    Extrema_ExtCC             ext(*ac1, *ac2);
    result.isDone = ext.IsDone();
    if (result.isDone)
    {
      result.isParallel = ext.IsParallel();
      if (!result.isParallel)
        result.nbExt = ext.NbExt();
    }
  }
  catch (...)
  {
  }
  return result;
}

OCCTExtremaPointPair OCCTExtremaExtCCPoint(OCCTCurve3DRef curve1,
                                           double         u1First,
                                           double         u1Last,
                                           OCCTCurve3DRef curve2,
                                           double         u2First,
                                           double         u2Last,
                                           int            index)
{
  OCCTExtremaPointPair result = {};
  try
  {
    auto*                     c1  = (OCCTCurve3D*)curve1;
    auto*                     c2  = (OCCTCurve3D*)curve2;
    Handle(GeomAdaptor_Curve) ac1 = new GeomAdaptor_Curve(c1->curve, u1First, u1Last);
    Handle(GeomAdaptor_Curve) ac2 = new GeomAdaptor_Curve(c2->curve, u2First, u2Last);
    Extrema_ExtCC             ext(*ac1, *ac2);
    if (ext.IsDone() && !ext.IsParallel() && index >= 1 && index <= ext.NbExt())
    {
      result.squareDistance = ext.SquareDistance(index);
      Extrema_POnCurv p1, p2;
      ext.Points(index, p1, p2);
      result.x1     = p1.Value().X();
      result.y1     = p1.Value().Y();
      result.z1     = p1.Value().Z();
      result.param1 = p1.Parameter();
      result.x2     = p2.Value().X();
      result.y2     = p2.Value().Y();
      result.z2     = p2.Value().Z();
      result.param2 = p2.Parameter();
    }
  }
  catch (...)
  {
  }
  return result;
}

OCCTExtremaExtCSResult OCCTExtremaExtCS(OCCTCurve3DRef curve,
                                        double         uFirst,
                                        double         uLast,
                                        OCCTSurfaceRef surface)
{
  OCCTExtremaExtCSResult result = {false, false, 0};
  try
  {
    auto*                       c  = (OCCTCurve3D*)curve;
    auto*                       s  = (OCCTSurface*)surface;
    Handle(GeomAdaptor_Curve)   ac = new GeomAdaptor_Curve(c->curve, uFirst, uLast);
    Handle(GeomAdaptor_Surface) as = new GeomAdaptor_Surface(s->surface);
    Extrema_ExtCS               ext(*ac, *as, 1e-6, 1e-6);
    result.isDone = ext.IsDone();
    if (result.isDone)
    {
      result.isParallel = ext.IsParallel();
      if (!result.isParallel)
        result.nbExt = ext.NbExt();
    }
  }
  catch (...)
  {
  }
  return result;
}

OCCTExtremaPointPair OCCTExtremaExtCSPoint(OCCTCurve3DRef curve,
                                           double         uFirst,
                                           double         uLast,
                                           OCCTSurfaceRef surface,
                                           int            index)
{
  OCCTExtremaPointPair result = {};
  try
  {
    auto*                       c  = (OCCTCurve3D*)curve;
    auto*                       s  = (OCCTSurface*)surface;
    Handle(GeomAdaptor_Curve)   ac = new GeomAdaptor_Curve(c->curve, uFirst, uLast);
    Handle(GeomAdaptor_Surface) as = new GeomAdaptor_Surface(s->surface);
    Extrema_ExtCS               ext(*ac, *as, 1e-6, 1e-6);
    if (ext.IsDone() && !ext.IsParallel() && index >= 1 && index <= ext.NbExt())
    {
      result.squareDistance = ext.SquareDistance(index);
      Extrema_POnCurv pc;
      Extrema_POnSurf ps;
      ext.Points(index, pc, ps);
      result.x1     = pc.Value().X();
      result.y1     = pc.Value().Y();
      result.z1     = pc.Value().Z();
      result.param1 = pc.Parameter();
      result.x2     = ps.Value().X();
      result.y2     = ps.Value().Y();
      result.z2     = ps.Value().Z();
      double u, v;
      ps.Parameter(u, v);
      result.param2 = u; // Store U in param2; V not directly available in this struct
    }
  }
  catch (...)
  {
  }
  return result;
}

OCCTExtremaLocateExtCCResult OCCTExtremaLocateExtCC(OCCTCurve3DRef curve1,
                                                    double         u1First,
                                                    double         u1Last,
                                                    OCCTCurve3DRef curve2,
                                                    double         u2First,
                                                    double         u2Last,
                                                    double         seedU,
                                                    double         seedV)
{
  OCCTExtremaLocateExtCCResult result = {};
  try
  {
    auto*                     c1  = (OCCTCurve3D*)curve1;
    auto*                     c2  = (OCCTCurve3D*)curve2;
    Handle(GeomAdaptor_Curve) ac1 = new GeomAdaptor_Curve(c1->curve, u1First, u1Last);
    Handle(GeomAdaptor_Curve) ac2 = new GeomAdaptor_Curve(c2->curve, u2First, u2Last);
    Extrema_LocateExtCC       ext(*ac1, *ac2, seedU, seedV);
    result.isDone = ext.IsDone();
    if (result.isDone)
    {
      result.squareDistance = ext.SquareDistance();
      Extrema_POnCurv p1, p2;
      ext.Point(p1, p2);
      result.x1     = p1.Value().X();
      result.y1     = p1.Value().Y();
      result.z1     = p1.Value().Z();
      result.param1 = p1.Parameter();
      result.x2     = p2.Value().X();
      result.y2     = p2.Value().Y();
      result.z2     = p2.Value().Z();
      result.param2 = p2.Parameter();
    }
  }
  catch (...)
  {
  }
  return result;
}

int32_t OCCTCurve3DCurveType(OCCTCurve3DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return 8; // OtherCurve
  try
  {
    GeomAdaptor_Curve ac(curve->curve);
    return (int32_t)ac.GetType();
  }
  catch (...)
  {
    return 8;
  }
}

bool OCCTExtremaLocateOnSurface(OCCTSurfaceRef surface,
                                double         px,
                                double         py,
                                double         pz,
                                double         initU,
                                double         initV,
                                double         tol,
                                double*        u,
                                double*        v,
                                double*        distance)
{
  if (!surface || surface->surface.IsNull())
    return false;
  try
  {
    GeomAdaptor_Surface    as(surface->surface);
    Extrema_GenLocateExtPS ext(as, tol, tol);
    ext.Perform(gp_Pnt(px, py, pz), initU, initV);
    if (!ext.IsDone())
      return false;
    ext.Point().Parameter(*u, *v);
    *distance = sqrt(ext.SquareDistance());
    return true;
  }
  catch (...)
  {
    return false;
  }
}
