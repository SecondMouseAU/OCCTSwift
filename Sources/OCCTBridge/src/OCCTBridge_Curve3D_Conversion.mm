//
//  OCCTBridge_Curve3D_Conversion.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Curve3D.mm (#1380): GC_Make*, gce_Make*, GeomConvert, Convert_*, GeomAPI,
//  ShapeUpgrade/ShapeConstruct curve3d. Public C surface unchanged; every sibling file imports the
//  same headers this one does (the shared preamble below). No symbol changes, pure file move -- see
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

OCCTCurve3DRef OCCTCurve3DCreateSegment(double p1x,
                                        double p1y,
                                        double p1z,
                                        double p2x,
                                        double p2y,
                                        double p2z)
{
  try
  {
    gp_Pnt pt1(p1x, p1y, p1z);
    gp_Pnt pt2(p2x, p2y, p2z);
    if (pt1.Distance(pt2) < Precision::Confusion())
      return nullptr;
    GC_MakeSegment maker(pt1, pt2);
    if (!maker.IsDone())
      return nullptr;
    return new OCCTCurve3D(maker.Value());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTCurve3DCreateArcOfCircle(double p1x,
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
    GC_MakeArcOfCircle maker(gp_Pnt(p1x, p1y, p1z), gp_Pnt(p2x, p2y, p2z), gp_Pnt(p3x, p3y, p3z));
    if (!maker.IsDone())
      return nullptr;
    return new OCCTCurve3D(maker.Value());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTCurve3DInterpolate(const double* points,
                                      int32_t       count,
                                      bool          closed,
                                      double        tolerance)
{
  try
  {
    if (!points || count < 2)
      return nullptr;

    Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, count);
    for (int i = 0; i < count; i++)
      pts->SetValue(i + 1, gp_Pnt(points[i * 3], points[i * 3 + 1], points[i * 3 + 2]));

    GeomAPI_Interpolate interp(pts, closed ? Standard_True : Standard_False, tolerance);
    interp.Perform();
    if (!interp.IsDone())
      return nullptr;

    return new OCCTCurve3D(interp.Curve());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTCurve3DInterpolateWithTangents(const double* points,
                                                  int32_t       count,
                                                  double        stx,
                                                  double        sty,
                                                  double        stz,
                                                  double        etx,
                                                  double        ety,
                                                  double        etz,
                                                  double        tolerance)
{
  try
  {
    if (!points || count < 2)
      return nullptr;

    Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, count);
    for (int i = 0; i < count; i++)
      pts->SetValue(i + 1, gp_Pnt(points[i * 3], points[i * 3 + 1], points[i * 3 + 2]));

    GeomAPI_Interpolate interp(pts, Standard_False, tolerance);
    gp_Vec              startTan(stx, sty, stz);
    gp_Vec              endTan(etx, ety, etz);
    interp.Load(startTan, endTan);
    interp.Perform();
    if (!interp.IsDone())
      return nullptr;

    return new OCCTCurve3D(interp.Curve());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTCurve3DFitPoints(const double* points,
                                    int32_t       count,
                                    int32_t       minDeg,
                                    int32_t       maxDeg,
                                    double        tolerance)
{
  try
  {
    if (!points || count < 2)
      return nullptr;

    TColgp_Array1OfPnt pArr(1, count);
    for (int i = 0; i < count; i++)
      pArr.SetValue(i + 1, gp_Pnt(points[i * 3], points[i * 3 + 1], points[i * 3 + 2]));

    GeomAPI_PointsToBSpline fitter(pArr, minDeg, maxDeg, GeomAbs_C2, tolerance);
    if (!fitter.IsDone())
      return nullptr;

    return new OCCTCurve3D(fitter.Curve());
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTCurve3DBSplineToBeziers(OCCTCurve3DRef c, OCCTCurve3DRef* out, int32_t max)
{
  if (!c || c->curve.IsNull() || !out || max <= 0)
    return 0;
  try
  {
    Handle(Geom_BSplineCurve) bsp = Handle(Geom_BSplineCurve)::DownCast(c->curve);
    if (bsp.IsNull())
    {
      bsp = GeomConvert::CurveToBSplineCurve(c->curve);
      if (bsp.IsNull())
        return 0;
    }

    GeomConvert_BSplineCurveToBezierCurve converter(bsp);
    int32_t                               n = std::min((int32_t)converter.NbArcs(), max);
    for (int32_t i = 0; i < n; i++)
    {
      Handle(Geom_BezierCurve) arc = converter.Arc(i + 1);
      out[i]                       = new OCCTCurve3D(arc);
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

OCCTCurve3DRef OCCTCurve3DJoinToBSpline(const OCCTCurve3DRef* curves,
                                        int32_t               count,
                                        double                tolerance)
{
  if (!curves || count < 1)
    return nullptr;
  try
  {
    if (!curves[0] || curves[0]->curve.IsNull())
      return nullptr;

    Handle(Geom_BSplineCurve) first = GeomConvert::CurveToBSplineCurve(curves[0]->curve);
    if (first.IsNull())
      return nullptr;

    GeomConvert_CompCurveToBSplineCurve joiner(first);
    for (int32_t i = 1; i < count; i++)
    {
      if (!curves[i] || curves[i]->curve.IsNull())
        continue;
      Handle(Geom_BSplineCurve) bsp = GeomConvert::CurveToBSplineCurve(curves[i]->curve);
      if (!bsp.IsNull())
      {
        // Add() returns false and leaves the accumulated curve untouched when this curve isn't
        // G0-continuous with it (#1441); a discarded return silently drops the curve from the
        // join instead of failing, matching OCCTCurve3DJoinCurves/OCCTConcatenateCurves3D below.
        if (!joiner.Add(bsp, tolerance))
          return nullptr;
      }
    }
    return new OCCTCurve3D(joiner.BSplineCurve());
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTCurve3DIsPlanar(OCCTCurve3DRef curve,
                         double         tolerance,
                         double*        outNX,
                         double*        outNY,
                         double*        outNZ)
{
  if (!curve || curve->curve.IsNull())
    return false;
  try
  {
    ShapeAnalysis_Curve analyzer;
    gp_XYZ              normal;
    bool                result = analyzer.IsPlanar(curve->curve, normal, tolerance);
    if (result)
    {
      if (outNX)
        *outNX = normal.X();
      if (outNY)
        *outNY = normal.Y();
      if (outNZ)
        *outNZ = normal.Z();
      return true;
    }
    return false;
  }
  catch (...)
  {
    return false;
  }
}

OCCTCurve3DRef OCCTCurve3DArcOfEllipse(double centerX,
                                       double centerY,
                                       double centerZ,
                                       double normalX,
                                       double normalY,
                                       double normalZ,
                                       double majorRadius,
                                       double minorRadius,
                                       double angle1,
                                       double angle2,
                                       bool   sense)
{
  try
  {
    if (!occtValidEllipseRadii(majorRadius, minorRadius))
      return nullptr;
    gp_Ax2              ax(gp_Pnt(centerX, centerY, centerZ), gp_Dir(normalX, normalY, normalZ));
    gp_Elips            elips(ax, majorRadius, minorRadius);
    GC_MakeArcOfEllipse maker(elips, angle1, angle2, sense);
    if (!maker.IsDone())
      return nullptr;
    return new OCCTCurve3D(maker.Value());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTCurve3DArcOfEllipsePoints(double centerX,
                                             double centerY,
                                             double centerZ,
                                             double normalX,
                                             double normalY,
                                             double normalZ,
                                             double majorRadius,
                                             double minorRadius,
                                             double p1X,
                                             double p1Y,
                                             double p1Z,
                                             double p2X,
                                             double p2Y,
                                             double p2Z,
                                             bool   sense)
{
  try
  {
    // Not redundant with the IsDone() check below: a zero minor radius makes the two-point
    // form's ElCLib::Parameter inversion NaN, and IsDone() still reports true (#554).
    if (!occtValidEllipseRadii(majorRadius, minorRadius))
      return nullptr;
    gp_Ax2              ax(gp_Pnt(centerX, centerY, centerZ), gp_Dir(normalX, normalY, normalZ));
    gp_Elips            elips(ax, majorRadius, minorRadius);
    GC_MakeArcOfEllipse maker(elips, gp_Pnt(p1X, p1Y, p1Z), gp_Pnt(p2X, p2Y, p2Z), sense);
    if (!maker.IsDone())
      return nullptr;
    return new OCCTCurve3D(maker.Value());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTCurve3DJoinCurves(const OCCTCurve3DRef* curves, int32_t count, double tolerance)
{
  if (!curves || count < 1)
    return nullptr;
  try
  {
    // First curve initializes the joiner
    if (!curves[0] || curves[0]->curve.IsNull())
      return nullptr;
    Handle(Geom_BoundedCurve) first = Handle(Geom_BoundedCurve)::DownCast(curves[0]->curve);
    if (first.IsNull())
      return nullptr;

    GeomConvert_CompCurveToBSplineCurve joiner(first);

    for (int i = 1; i < count; i++)
    {
      if (!curves[i])
        return nullptr;
      Handle(Geom_BoundedCurve) bc = Handle(Geom_BoundedCurve)::DownCast(curves[i]->curve);
      if (bc.IsNull())
        return nullptr;
      if (!joiner.Add(bc, tolerance))
        return nullptr;
    }

    Handle(Geom_BSplineCurve) bsp = joiner.BSplineCurve();
    if (bsp.IsNull())
      return nullptr;

    auto* result  = new OCCTCurve3D();
    result->curve = bsp;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

// The nearest point over the curve's own domain, not over its basis curve (#539). Before, this was
// a bare ShapeAnalysis_Curve::Project, which on a segment trimmed to [3, 8] reported (100, 0, 0) at
// parameter 100, distance 0 -- so a `distance < tolerance` proximity test read a point 92 units
// away as lying on the curve. See occtNearestPointOnCurveRange for what each of its three candidate
// sources contributes and why none of them suffices alone.
OCCTCurveProjectResult OCCTCurve3DProjectPoint(OCCTCurve3DRef curve,
                                               double         px,
                                               double         py,
                                               double         pz,
                                               double         precision)
{
  OCCTCurveProjectResult result = {};
  if (!curve || curve->curve.IsNull())
    return result;
  try
  {
    gp_Pnt proj;
    double param = 0.0, dist = 0.0;
    if (!occtNearestPointOnCurveRange(curve->curve,
                                      gp_Pnt(px, py, pz),
                                      curve->curve->FirstParameter(),
                                      curve->curve->LastParameter(),
                                      precision,
                                      &proj,
                                      &param,
                                      &dist))
    {
      return result;
    }
    result.distance  = dist;
    result.parameter = param;
    result.projX     = proj.X();
    result.projY     = proj.Y();
    result.projZ     = proj.Z();
    return result;
  }
  catch (...)
  {
    return result;
  }
}

OCCTCurveValidateRangeResult OCCTCurve3DValidateRange(OCCTCurve3DRef curve,
                                                      double         first,
                                                      double         last,
                                                      double         precision)
{
  OCCTCurveValidateRangeResult result = {};
  result.first                        = first;
  result.last                         = last;
  result.wasAdjusted                  = false;
  if (!curve || curve->curve.IsNull())
    return result;
  try
  {
    ShapeAnalysis_Curve sac;
    double              f = first, l = last;
    bool                adjusted = sac.ValidateRange(curve->curve, f, l, precision);
    result.first                 = f;
    result.last                  = l;
    result.wasAdjusted           = adjusted;
    return result;
  }
  catch (...)
  {
    return result;
  }
}

int32_t OCCTCurve3DGetSamplePoints3D(OCCTCurve3DRef curve,
                                     double         first,
                                     double         last,
                                     double*        outXYZ,
                                     int32_t        maxPoints)
{
  if (!curve || curve->curve.IsNull() || !outXYZ || maxPoints <= 0)
    return 0;
  try
  {
    ShapeAnalysis_Curve          sac;
    NCollection_Sequence<gp_Pnt> pts;
    if (!sac.GetSamplePoints(curve->curve, first, last, pts))
      return 0;

    int32_t count = std::min((int32_t)pts.Length(), maxPoints);
    for (int32_t i = 0; i < count; i++)
    {
      const gp_Pnt& p   = pts.Value(i + 1); // 1-indexed
      outXYZ[i * 3]     = p.X();
      outXYZ[i * 3 + 1] = p.Y();
      outXYZ[i * 3 + 2] = p.Z();
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - GC ArcOfHyperbola / ArcOfParabola (v0.50)
OCCTCurve3DRef OCCTCurve3DArcOfHyperbola(double majorRadius,
                                         double minorRadius,
                                         double axisX,
                                         double axisY,
                                         double axisZ,
                                         double dirX,
                                         double dirY,
                                         double dirZ,
                                         double alpha1,
                                         double alpha2,
                                         bool   sense)
{
  try
  {
    if (!occtValidHyperbolaRadii(majorRadius, minorRadius))
      return nullptr;
    gp_Ax2                ax(gp_Pnt(axisX, axisY, axisZ), gp_Dir(dirX, dirY, dirZ));
    gp_Hypr               hypr(ax, majorRadius, minorRadius);
    GC_MakeArcOfHyperbola maker(hypr, alpha1, alpha2, sense ? Standard_True : Standard_False);
    if (!maker.IsDone())
      return nullptr;
    Handle(Geom_TrimmedCurve) arc = maker.Value();
    if (arc.IsNull())
      return nullptr;
    auto* ref  = new OCCTCurve3D();
    ref->curve = arc;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTCurve3DArcOfParabola(double focalDistance,
                                        double axisX,
                                        double axisY,
                                        double axisZ,
                                        double dirX,
                                        double dirY,
                                        double dirZ,
                                        double alpha1,
                                        double alpha2,
                                        bool   sense)
{
  try
  {
    if (!occtValidParabolaFocal(focalDistance))
      return nullptr;
    gp_Ax2               ax(gp_Pnt(axisX, axisY, axisZ), gp_Dir(dirX, dirY, dirZ));
    gp_Parab             parab(ax, focalDistance);
    GC_MakeArcOfParabola maker(parab, alpha1, alpha2, sense ? Standard_True : Standard_False);
    if (!maker.IsDone())
      return nullptr;
    Handle(Geom_TrimmedCurve) arc = maker.Value();
    if (arc.IsNull())
      return nullptr;
    auto* ref  = new OCCTCurve3D();
    ref->curve = arc;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTCurve3DSplitAt(OCCTCurve3DRef  curve,
                        double          splitParam,
                        OCCTCurve3DRef* outCurve1,
                        OCCTCurve3DRef* outCurve2)
{
  if (!curve || curve->curve.IsNull() || !outCurve1 || !outCurve2)
    return false;
  *outCurve1 = nullptr;
  *outCurve2 = nullptr;
  try
  {
    Handle(Geom_Curve) c     = curve->curve;
    double             first = c->FirstParameter();
    double             last  = c->LastParameter();
    if (splitParam <= first || splitParam >= last)
      return false;

    Handle(ShapeUpgrade_SplitCurve3d) splitter = new ShapeUpgrade_SplitCurve3d();
    splitter->Init(c, first, last);
    Handle(TColStd_HSequenceOfReal) splitVals = new TColStd_HSequenceOfReal();
    splitVals->Append(splitParam);
    splitter->SetSplitValues(splitVals);
    splitter->Perform(Standard_True);

    Handle(TColGeom_HArray1OfCurve) curves = splitter->GetCurves();
    if (curves.IsNull() || curves->Length() < 2)
      return false;

    auto* ref1  = new OCCTCurve3D();
    ref1->curve = curves->Value(1);
    *outCurve1  = ref1;

    auto* ref2  = new OCCTCurve3D();
    ref2->curve = curves->Value(2);
    *outCurve2  = ref2;
    return true;
  }
  catch (...)
  {
    return false;
  }
}

OCCTCurve3DRef _Nullable OCCTCurve3DMakeEllipse(double cx,
                                                double cy,
                                                double cz,
                                                double dx,
                                                double dy,
                                                double dz,
                                                double majorRadius,
                                                double minorRadius)
{
  try
  {
    if (!occtValidEllipseRadii(majorRadius, minorRadius))
      return nullptr;
    gp_Ax2         ax(gp_Pnt(cx, cy, cz), gp_Dir(dx, dy, dz));
    GC_MakeEllipse me(ax, majorRadius, minorRadius);
    if (!me.IsDone())
      return nullptr;
    auto* curve  = new OCCTCurve3D();
    curve->curve = me.Value();
    return curve;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef _Nullable OCCTCurve3DMakeEllipseThreePoints(double s1x,
                                                           double s1y,
                                                           double s1z,
                                                           double s2x,
                                                           double s2y,
                                                           double s2z,
                                                           double centerX,
                                                           double centerY,
                                                           double centerZ)
{
  try
  {
    GC_MakeEllipse me(gp_Pnt(s1x, s1y, s1z),
                      gp_Pnt(s2x, s2y, s2z),
                      gp_Pnt(centerX, centerY, centerZ));
    if (!me.IsDone())
      return nullptr;
    auto* curve  = new OCCTCurve3D();
    curve->curve = me.Value();
    return curve;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef _Nullable OCCTCurve3DMakeHyperbola(double cx,
                                                  double cy,
                                                  double cz,
                                                  double dx,
                                                  double dy,
                                                  double dz,
                                                  double majorRadius,
                                                  double minorRadius)
{
  try
  {
    if (!occtValidHyperbolaRadii(majorRadius, minorRadius))
      return nullptr;
    gp_Ax2           ax(gp_Pnt(cx, cy, cz), gp_Dir(dx, dy, dz));
    GC_MakeHyperbola mh(ax, majorRadius, minorRadius);
    if (!mh.IsDone())
      return nullptr;
    auto* curve  = new OCCTCurve3D();
    curve->curve = mh.Value();
    return curve;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef _Nullable OCCTCurve3DMakeHyperbolaThreePoints(double s1x,
                                                             double s1y,
                                                             double s1z,
                                                             double s2x,
                                                             double s2y,
                                                             double s2z,
                                                             double centerX,
                                                             double centerY,
                                                             double centerZ)
{
  try
  {
    GC_MakeHyperbola mh(gp_Pnt(s1x, s1y, s1z),
                        gp_Pnt(s2x, s2y, s2z),
                        gp_Pnt(centerX, centerY, centerZ));
    if (!mh.IsDone())
      return nullptr;
    auto* curve  = new OCCTCurve3D();
    curve->curve = mh.Value();
    return curve;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef _Nullable OCCTShapeConstructConvertToBSpline3D(OCCTCurve3DRef _Nonnull curve,
                                                              double first,
                                                              double last,
                                                              double precision)
{
  if (!curve || curve->curve.IsNull())
    return nullptr;
  try
  {
    ShapeConstruct_Curve      scc;
    Handle(Geom_BSplineCurve) bsp = scc.ConvertToBSpline(curve->curve, first, last, precision);
    if (bsp.IsNull())
      return nullptr;
    auto* ref  = new OCCTCurve3D();
    ref->curve = bsp;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTShapeConstructAdjustCurve3D(OCCTCurve3DRef _Nonnull curve,
                                     double p1x,
                                     double p1y,
                                     double p1z,
                                     double p2x,
                                     double p2y,
                                     double p2z)
{
  if (!curve || curve->curve.IsNull())
    return false;
  try
  {
    ShapeConstruct_Curve scc;
    return scc.AdjustCurve(curve->curve, gp_Pnt(p1x, p1y, p1z), gp_Pnt(p2x, p2y, p2z));
  }
  catch (...)
  {
    return false;
  }
}

int OCCTSplitCurve3dContinuity(OCCTCurve3DRef _Nonnull curveRef,
                               int    criterion,
                               double tolerance,
                               OCCTCurve3DRef _Nullable* _Nullable outCurves,
                               int maxCurves)
{
  try
  {
    auto* wrapper = reinterpret_cast<OCCTCurve3D*>(curveRef);
    if (!wrapper || wrapper->curve.IsNull())
      return 0;
    auto&                                       curve = wrapper->curve;
    Handle(ShapeUpgrade_SplitCurve3dContinuity) splitter =
      new ShapeUpgrade_SplitCurve3dContinuity();
    splitter->Init(curve);
    splitter->SetCriterion(occtGeomAbsFromParametricContinuity(criterion));
    splitter->SetTolerance(tolerance);
    splitter->Perform(true);
    auto curves = splitter->GetCurves();
    if (curves.IsNull())
      return 0;
    int n       = curves->Length();
    int written = 0;
    for (int i = curves->Lower(); i <= curves->Upper() && written < maxCurves; i++)
    {
      Handle(Geom_Curve) c = curves->Value(i);
      if (!c.IsNull() && outCurves)
      {
        outCurves[written] = reinterpret_cast<OCCTCurve3DRef>(new OCCTCurve3D{c});
      }
      written++;
    }
    return written;
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTGeomConvertIsLinear(const double* _Nonnull points,
                             int    count,
                             double tolerance,
                             double* _Nullable deviation)
{
  try
  {
    NCollection_Array1<gp_Pnt> pts(1, count);
    for (int i = 0; i < count; i++)
    {
      pts(i + 1) = gp_Pnt(points[i * 3], points[i * 3 + 1], points[i * 3 + 2]);
    }
    double dev    = 0;
    bool   result = GeomConvert_CurveToAnaCurve::IsLinear(pts, tolerance, dev);
    if (deviation)
      *deviation = dev;
    return result;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTConvertCompBezierToBSpline(const double*            poles,
                                    int32_t                  segCount,
                                    int32_t                  ptsPerSeg,
                                    OCCTBezierBSplineResult* out)
{
  if (!poles || segCount <= 0 || ptsPerSeg <= 0 || !out)
    return false;
  try
  {
    Convert_CompBezierCurvesToBSplineCurve conv;
    const double*                          p = poles;
    for (int s = 0; s < segCount; s++)
    {
      NCollection_Array1<gp_Pnt> seg(1, ptsPerSeg);
      for (int i = 1; i <= ptsPerSeg; i++)
      {
        seg(i) = gp_Pnt(p[0], p[1], p[2]);
        p += 3;
      }
      conv.AddCurve(seg);
    }
    conv.Perform();
    int nb = conv.NbPoles();
    int nk = conv.NbKnots();
    // OCCTBezierBSplineResult's poles/knots/mults are fixed-size (100 poles, 50 knots); a
    // composite curve with enough segments grows past that with no bound (#1441). Reject
    // rather than report an unclamped nbPoles/nbKnots against a buffer that only holds the
    // truncated prefix, which would leave the caller reading past its own fixed-size struct.
    if (nb > 100 || nk > 50)
      return false;
    out->degree  = conv.Degree();
    out->nbPoles = nb;
    out->nbKnots = nk;

    NCollection_Array1<gp_Pnt> resultPoles(1, nb);
    conv.Poles(resultPoles);
    for (int i = 1; i <= nb; i++)
    {
      out->poles[(i - 1) * 3]     = resultPoles(i).X();
      out->poles[(i - 1) * 3 + 1] = resultPoles(i).Y();
      out->poles[(i - 1) * 3 + 2] = resultPoles(i).Z();
    }

    NCollection_Array1<double> knots(1, nk);
    NCollection_Array1<int>    mults(1, nk);
    conv.KnotsAndMults(knots, mults);
    for (int i = 1; i <= nk; i++)
    {
      out->knots[i - 1] = knots(i);
      out->mults[i - 1] = mults(i);
    }
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTConvertCompBezier2dToBSpline2d(const double*              poles,
                                        int32_t                    segCount,
                                        int32_t                    ptsPerSeg,
                                        OCCTBezierBSpline2dResult* out)
{
  if (!poles || segCount <= 0 || ptsPerSeg <= 0 || !out)
    return false;
  try
  {
    Convert_CompBezierCurves2dToBSplineCurve2d conv;
    const double*                              p = poles;
    for (int s = 0; s < segCount; s++)
    {
      NCollection_Array1<gp_Pnt2d> seg(1, ptsPerSeg);
      for (int i = 1; i <= ptsPerSeg; i++)
      {
        seg(i) = gp_Pnt2d(p[0], p[1]);
        p += 2;
      }
      conv.AddCurve(seg);
    }
    conv.Perform();
    int nb = conv.NbPoles();
    int nk = conv.NbKnots();
    // Same fixed-capacity-vs-unclamped-count hazard as the 3D converter above (#1441): reject
    // rather than report a count against a buffer that only holds the truncated prefix.
    if (nb > 100 || nk > 50)
      return false;
    out->degree  = conv.Degree();
    out->nbPoles = nb;
    out->nbKnots = nk;

    NCollection_Array1<gp_Pnt2d> resultPoles(1, nb);
    conv.Poles(resultPoles);
    for (int i = 1; i <= nb; i++)
    {
      out->poles[(i - 1) * 2]     = resultPoles(i).X();
      out->poles[(i - 1) * 2 + 1] = resultPoles(i).Y();
    }

    NCollection_Array1<double> knots(1, nk);
    NCollection_Array1<int>    mults(1, nk);
    conv.KnotsAndMults(knots, mults);
    for (int i = 1; i <= nk; i++)
    {
      out->knots[i - 1] = knots(i);
      out->mults[i - 1] = mults(i);
    }
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DIsClosedWithPreci(OCCTCurve3DRef curve, double preci)
{
  if (!curve || curve->curve.IsNull())
    return false;
  try
  {
    return ShapeAnalysis_Curve::IsClosed(curve->curve, preci);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTCurve3DIsPeriodicSA(OCCTCurve3DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return false;
  try
  {
    return ShapeAnalysis_Curve::IsPeriodic(curve->curve);
  }
  catch (...)
  {
    return false;
  }
}

OCCTCurve3DRef OCCTGCMakeCircle(double cx,
                                double cy,
                                double cz,
                                double nx,
                                double ny,
                                double nz,
                                double radius)
{
  try
  {
    gp_Ax2        ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
    GC_MakeCircle mc(ax, radius);
    if (!mc.IsDone())
      return nullptr;
    auto result   = new OCCTCurve3D();
    result->curve = mc.Value();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTGCMakeCircle3Points(double x1,
                                       double y1,
                                       double z1,
                                       double x2,
                                       double y2,
                                       double z2,
                                       double x3,
                                       double y3,
                                       double z3)
{
  try
  {
    GC_MakeCircle mc(gp_Pnt(x1, y1, z1), gp_Pnt(x2, y2, z2), gp_Pnt(x3, y3, z3));
    if (!mc.IsDone())
      return nullptr;
    auto result   = new OCCTCurve3D();
    result->curve = mc.Value();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTGCMakeCircleCenterNormal(double cx,
                                            double cy,
                                            double cz,
                                            double nx,
                                            double ny,
                                            double nz,
                                            double radius)
{
  try
  {
    GC_MakeCircle mc(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz), radius);
    if (!mc.IsDone())
      return nullptr;
    auto result   = new OCCTCurve3D();
    result->curve = mc.Value();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTGCMakeCircleParallel(double cx,
                                        double cy,
                                        double cz,
                                        double nx,
                                        double ny,
                                        double nz,
                                        double radius,
                                        double dist)
{
  try
  {
    gp_Circ       circ(gp_Ax2(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz)), radius);
    GC_MakeCircle mc(circ, dist);
    if (!mc.IsDone())
      return nullptr;
    auto result   = new OCCTCurve3D();
    result->curve = mc.Value();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTGCMakeEllipse(double cx,
                                 double cy,
                                 double cz,
                                 double nx,
                                 double ny,
                                 double nz,
                                 double major,
                                 double minor)
{
  try
  {
    if (!occtValidEllipseRadii(major, minor))
      return nullptr;
    gp_Ax2         ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
    GC_MakeEllipse me(ax, major, minor);
    if (!me.IsDone())
      return nullptr;
    auto result   = new OCCTCurve3D();
    result->curve = me.Value();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTGCMakeEllipse3Points(double x1,
                                        double y1,
                                        double z1,
                                        double x2,
                                        double y2,
                                        double z2,
                                        double x3,
                                        double y3,
                                        double z3)
{
  try
  {
    GC_MakeEllipse me(gp_Pnt(x1, y1, z1), gp_Pnt(x2, y2, z2), gp_Pnt(x3, y3, z3));
    if (!me.IsDone())
      return nullptr;
    auto result   = new OCCTCurve3D();
    result->curve = me.Value();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTGCMakeEllipseFromElips(double cx,
                                          double cy,
                                          double cz,
                                          double nx,
                                          double ny,
                                          double nz,
                                          double xdx,
                                          double xdy,
                                          double xdz,
                                          double major,
                                          double minor)
{
  try
  {
    if (!occtValidEllipseRadii(major, minor))
      return nullptr;
    gp_Ax2         ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz), gp_Dir(xdx, xdy, xdz));
    GC_MakeEllipse me(ax, major, minor);
    if (!me.IsDone())
      return nullptr;
    auto result   = new OCCTCurve3D();
    result->curve = me.Value();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTGCMakeHyperbola(double cx,
                                   double cy,
                                   double cz,
                                   double nx,
                                   double ny,
                                   double nz,
                                   double major,
                                   double minor)
{
  try
  {
    if (!occtValidHyperbolaRadii(major, minor))
      return nullptr;
    gp_Ax2           ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
    GC_MakeHyperbola mh(ax, major, minor);
    if (!mh.IsDone())
      return nullptr;
    auto result   = new OCCTCurve3D();
    result->curve = mh.Value();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTGCMakeHyperbola3Points(double x1,
                                          double y1,
                                          double z1,
                                          double x2,
                                          double y2,
                                          double z2,
                                          double x3,
                                          double y3,
                                          double z3)
{
  try
  {
    // GC_MakeHyperbola from 3 points: S1, S2, Center
    gp_Hypr hypr;
    // There's no 3-point constructor for GC_MakeHyperbola, use gp_Hypr approach
    // S1 and S2 are on the hyperbola, center is the center
    // We'll construct from the geometry directly
    gp_Pnt s1(x1, y1, z1), s2(x2, y2, z2), center(x3, y3, z3);
    // Compute major axis direction
    gp_Dir xDir(s1.XYZ() - center.XYZ());
    double majorR = center.Distance(s1);
    // Minor axis from S2
    gp_Vec toS2(center, s2);
    gp_Vec majorVec(center, s1);
    double proj   = toS2.Dot(gp_Vec(xDir));
    gp_Vec perp   = toS2 - proj * gp_Vec(xDir);
    double minorR = perp.Magnitude();
    if (minorR < 1e-10)
      return nullptr;
    gp_Dir           normal = gp_Dir(majorVec.Crossed(perp));
    gp_Ax2           ax(center, normal, xDir);
    GC_MakeHyperbola mh(ax, majorR, minorR);
    if (!mh.IsDone())
      return nullptr;
    auto result   = new OCCTCurve3D();
    result->curve = mh.Value();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTConcatenateCurves3D(OCCTCurve3DRef* curves, int32_t count, double tolerance)
{
  if (!curves || count <= 0)
    return nullptr;
  try
  {
    // First curve must be bounded, so try to cast
    if (!curves[0] || curves[0]->curve.IsNull())
      return nullptr;
    Handle(Geom_BoundedCurve) first = Handle(Geom_BoundedCurve)::DownCast(curves[0]->curve);
    if (first.IsNull())
    {
      // Try trimming the curve using its parameter range
      double f = curves[0]->curve->FirstParameter();
      double l = curves[0]->curve->LastParameter();
      first    = new Geom_TrimmedCurve(curves[0]->curve, f, l);
    }
    GeomConvert_CompCurveToBSplineCurve comp(first);
    for (int32_t i = 1; i < count; i++)
    {
      if (!curves[i] || curves[i]->curve.IsNull())
        return nullptr;
      Handle(Geom_BoundedCurve) bc = Handle(Geom_BoundedCurve)::DownCast(curves[i]->curve);
      if (bc.IsNull())
      {
        double f = curves[i]->curve->FirstParameter();
        double l = curves[i]->curve->LastParameter();
        bc       = new Geom_TrimmedCurve(curves[i]->curve, f, l);
      }
      if (!comp.Add(bc, tolerance))
        return nullptr;
    }
    Handle(Geom_BSplineCurve) result = comp.BSplineCurve();
    if (result.IsNull())
      return nullptr;
    auto r   = new OCCTCurve3D();
    r->curve = result;
    return r;
  }
  catch (...)
  {
    return nullptr;
  }
}

// Two searches, and #615 deliberately changed only the second of them.
//
// The PRIMARY search is local by RANGE, not by proximity: it reports the LOWEST-DISTANCE extremum
// within a window of +/-10% of the domain around the guess. Note what initParam does and does not
// buy -- it bounds the window, and nothing selects among the extrema inside it by how near the
// guess they are, because the selection is GeomAPI_ProjectPointOnCurve::LowerDistanceParameter().
// Measured on a ramped sine BSpline, a guess of 90.9114 returns param 79.9751, 10.94 away from the
// guess, in preference to an extremum 0.13 away at 91.0378, because the far one is the closer of
// the two to the query POINT (10.07 against 15.19); 22 of 46 multi-extremum windows in that sweep
// behave so.
//
// The window is still what makes the answer local, and a windowed minimum can be a global MAXIMUM:
// on a half circle of radius 5 queried from (0, -6, 0) with a guess of pi/2 this reports 11, the
// far side. That is not the nearest point on the curve and is not claimed to be.
//
// Adding the window's two ends to that minimum -- the #539 recipe applied to [lo, hi] rather than
// to the whole curve -- was considered and rejected, on two grounds, and NOT on the ground that it
// would redefine initParam. It would not: the function already minimises over the window, so the
// ends are the only thing the change adds. The grounds are (1) it does not make the function
// correct under its own name, answering 10.865697905689686 on the arc above where the true nearest
// point is 7.81 away, and (2) a window's ends always evaluate, so the minimum would always be
// found, and the fallback below would become unreachable -- deleting the one path in this function
// that #615 fixes. Making the search global outright would leave initParam meaning nothing at all
// and the function a duplicate of OCCTCurve3DNearestParameter. So the primary search is left
// exactly as it was.
//
// The FALLBACK is a different matter, and was wrong. It fires precisely when the window contains no
// extremum, at which point the function has already abandoned locality and searched the whole
// curve. Having done that, it must give the whole curve's answer, which is the one
// OCCTCurve3DNearestParameter gives -- and #615 is that those two disagreed. Measured before:
// locateNearestPoint((0, -6, 0), initParam: 0) on that same half circle fell through to the
// fallback and answered pi/2 at distance 11, a point diametrically opposite a guess that sat on the
// true nearest point; and on a segment trimmed to [3, 8] queried at (100, 0, 0) it answered nil for
// every guess, because no window and no full-range search contains a perpendicular foot. Both now
// answer through the shared helper: 0 at 7.81, and 8 at 92.
// #999: the `tol` this used to take reached nothing. GeomAPI_ProjectPointOnCurve's windowed
// constructor has no tolerance, and the fallback below fixes Precision::Confusion() for the same
// reason its two converted siblings do. Extrema_LocateExtPC, which this function's name echoes,
// does take a TolU, but #615 moved this off that path on purpose.
bool OCCTExtremaLocateOnCurve(OCCTCurve3DRef curve,
                              double         px,
                              double         py,
                              double         pz,
                              double         initParam,
                              double*        param,
                              double*        distance)
{
  if (!curve || curve->curve.IsNull())
    return false;
  try
  {
    // Local search: the lowest-distance extremum inside a narrow window around the guess.
    // LowerDistanceParameter() below picks by distance to the query point, not by nearness to
    // initParam -- the guess bounds the window, it does not rank what is found in it.
    double                      f     = curve->curve->FirstParameter();
    double                      l     = curve->curve->LastParameter();
    double                      range = (l - f) * 0.1;
    double                      lo    = std::max(f, initParam - range);
    double                      hi    = std::min(l, initParam + range);
    GeomAPI_ProjectPointOnCurve proj(gp_Pnt(px, py, pz), curve->curve, lo, hi);
    if (proj.NbPoints() < 1)
    {
      // No extremum near the guess: fall back to the whole curve, and to the whole curve's
      // nearest point rather than to whichever extremum a full-range search turns up (#615).
      return occtNearestProjectionOnCurve3d(curve, gp_Pnt(px, py, pz), nullptr, param, distance);
    }
    *param    = proj.LowerDistanceParameter();
    *distance = proj.LowerDistance();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTExtremaPointCurve(OCCTCurve3DRef curve,
                              double         px,
                              double         py,
                              double         pz,
                              double*        params,
                              double*        distances,
                              int32_t        maxResults)
{
  if (!curve || curve->curve.IsNull())
    return 0;
  try
  {
    GeomAPI_ProjectPointOnCurve proj(gp_Pnt(px, py, pz), curve->curve);
    int32_t                     n = std::min((int32_t)proj.NbPoints(), maxResults);
    for (int32_t i = 0; i < n; i++)
    {
      params[i]    = proj.Parameter(i + 1);
      distances[i] = proj.Distance(i + 1);
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTExtremaPointSurface(OCCTSurfaceRef surface,
                                double         px,
                                double         py,
                                double         pz,
                                double*        us,
                                double*        vs,
                                double*        distances,
                                int32_t        maxResults)
{
  if (!surface || surface->surface.IsNull())
    return 0;
  try
  {
    GeomAPI_ProjectPointOnSurf proj(gp_Pnt(px, py, pz), surface->surface);
    if (!proj.IsDone())
      return 0;
    int32_t n = std::min((int32_t)proj.NbPoints(), maxResults);
    for (int32_t i = 0; i < n; i++)
    {
      double pu, pv;
      proj.Parameters(i + 1, pu, pv);
      us[i]        = pu;
      vs[i]        = pv;
      distances[i] = proj.Distance(i + 1);
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

OCCTCurve3DRef OCCTInterpolateWithAllTangents(const double* points,
                                              int32_t       count,
                                              const double* tangents,
                                              const bool*   tangentFlags)
{
  if (!points || !tangents || !tangentFlags || count < 2)
    return nullptr;
  try
  {
    Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, count);
    for (int i = 0; i < count; i++)
    {
      pts->SetValue(i + 1, gp_Pnt(points[i * 3], points[i * 3 + 1], points[i * 3 + 2]));
    }
    GeomAPI_Interpolate               interp(pts, Standard_False, 1e-6);
    NCollection_Array1<gp_Vec>        tans(1, count);
    Handle(NCollection_HArray1<bool>) flags = new NCollection_HArray1<bool>(1, count);
    for (int i = 0; i < count; i++)
    {
      tans.SetValue(i + 1, gp_Vec(tangents[i * 3], tangents[i * 3 + 1], tangents[i * 3 + 2]));
      flags->SetValue(i + 1, tangentFlags[i]);
    }
    interp.Load(tans, flags);
    interp.Perform();
    if (interp.IsDone())
    {
      return (OCCTCurve3DRef) new OCCTCurve3D{interp.Curve()};
    }
    return nullptr;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTInterpolateWithParameters(const double* points,
                                             int32_t       count,
                                             const double* parameters)
{
  if (!points || !parameters || count < 2)
    return nullptr;
  try
  {
    Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, count);
    for (int i = 0; i < count; i++)
    {
      pts->SetValue(i + 1, gp_Pnt(points[i * 3], points[i * 3 + 1], points[i * 3 + 2]));
    }
    Handle(TColStd_HArray1OfReal) params = new TColStd_HArray1OfReal(1, count);
    for (int i = 0; i < count; i++)
    {
      params->SetValue(i + 1, parameters[i]);
    }
    GeomAPI_Interpolate interp(pts, params, Standard_False, 1e-6);
    interp.Perform();
    if (interp.IsDone())
    {
      return (OCCTCurve3DRef) new OCCTCurve3D{interp.Curve()};
    }
    return nullptr;
  }
  catch (...)
  {
    return nullptr;
  }
}

// Exactly OCCTCurve3DInterpolate with the periodicity flag pinned. It used to be a second,
// independent GeomAPI_Interpolate call site, which had already drifted: it rejected count < 3
// where the general entry point rejects only count < 2, so the same 2-point input reached OCCT
// through one and not the other, and it hardcoded the tolerance with no way to reach any other
// value. Forwarding keeps the C ABI while leaving one implementation (#493, the 3D counterpart of
// #412's fix on OCCTInterpolate2DPeriodic). Callers that need a tolerance other than the default
// should call OCCTCurve3DInterpolate directly with closed = true.
OCCTCurve3DRef OCCTInterpolatePeriodic(const double* points, int32_t count)
{
  return OCCTCurve3DInterpolate(points, count, true, 1e-6);
}

OCCTCurve3DRef OCCTPointsToBSplineWithParams(const double* points,
                                             int32_t       count,
                                             int32_t       degMin,
                                             int32_t       degMax,
                                             int32_t       continuity,
                                             double        tol)
{
  if (!points || count < 2)
    return nullptr;
  try
  {
    TColgp_Array1OfPnt pts(1, count);
    for (int i = 0; i < count; i++)
    {
      pts.SetValue(i + 1, gp_Pnt(points[i * 3], points[i * 3 + 1], points[i * 3 + 2]));
    }
    GeomAPI_PointsToBSpline approx(pts,
                                   degMin,
                                   degMax,
                                   occtGeomAbsFromParametricContinuity(continuity),
                                   tol);
    if (approx.IsDone())
    {
      return (OCCTCurve3DRef) new OCCTCurve3D{approx.Curve()};
    }
    return nullptr;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTPointsToBSplineWithParameters(const double* points,
                                                 const double* params,
                                                 int32_t       count,
                                                 int32_t       degMin,
                                                 int32_t       degMax,
                                                 int32_t       continuity,
                                                 double        tol)
{
  if (!points || !params || count < 2)
    return nullptr;
  try
  {
    TColgp_Array1OfPnt   pts(1, count);
    TColStd_Array1OfReal prms(1, count);
    for (int i = 0; i < count; i++)
    {
      pts.SetValue(i + 1, gp_Pnt(points[i * 3], points[i * 3 + 1], points[i * 3 + 2]));
      prms.SetValue(i + 1, params[i]);
    }
    GeomAPI_PointsToBSpline approx(pts,
                                   prms,
                                   degMin,
                                   degMax,
                                   occtGeomAbsFromParametricContinuity(continuity),
                                   tol);
    if (approx.IsDone())
    {
      return (OCCTCurve3DRef) new OCCTCurve3D{approx.Curve()};
    }
    return nullptr;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTCurve3DConcatenateG1(const OCCTCurve3DRef* curves, int32_t count, double tol)
{
  if (!curves || count < 1)
    return nullptr;
  try
  {
    Handle(Geom_BSplineCurve) first =
      GeomConvert::CurveToBSplineCurve(((OCCTCurve3D*)curves[0])->curve);
    if (first.IsNull())
      return nullptr;
    GeomConvert_CompCurveToBSplineCurve concat(first);
    for (int i = 1; i < count; i++)
    {
      Handle(Geom_BSplineCurve) bsp =
        GeomConvert::CurveToBSplineCurve(((OCCTCurve3D*)curves[i])->curve);
      if (!bsp.IsNull())
      {
        // Same discarded-Add()-return hazard as OCCTCurve3DJoinToBSpline above (#1441).
        if (!concat.Add(bsp, tol))
          return nullptr;
      }
    }
    Handle(Geom_BSplineCurve) result = concat.BSplineCurve();
    if (result.IsNull())
      return nullptr;
    return (OCCTCurve3DRef) new OCCTCurve3D{result};
  }
  catch (...)
  {
    return nullptr;
  }
}
