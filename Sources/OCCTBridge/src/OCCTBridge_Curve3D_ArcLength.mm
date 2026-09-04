//
//  OCCTBridge_Curve3D_ArcLength.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Curve3D.mm (#1380): GCPnts (UniformAbscissa, QuasiUniform,
//  TangentialDeflection, UniformDeflection), CPnts. Public C surface unchanged; every sibling file
//  imports the same headers this one does (the shared preamble below). No symbol changes, pure file
//  move -- see Scripts/repro/396-bridge-mm-split/ for how.
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

// Not one Gauss quadrature over the whole domain: that is what CPnts_AbscissaPoint::Length does,
// and it is up to 5% wrong on a multi-span BSpline (#477). #477 moved this to GCPnts, which splits
// at the GeomAbs_CN interval boundaries -- but a conic has one interval, so the single quadrature
// survived there and measured a whole ellipse up to 1.7% long. occtAdaptorArcLength
// (OCCTBridge_Internal.h) subdivides inside each interval until it converges. #603.
double OCCTCurve3DGetLength(OCCTCurve3DRef c)
{
  if (!c || c->curve.IsNull())
    return -1.0;
  try
  {
    GeomAdaptor_Curve adaptor(c->curve);
    return occtAdaptorArcLength(adaptor, adaptor.FirstParameter(), adaptor.LastParameter());
  }
  catch (...)
  {
    return -1.0;
  }
}

int32_t OCCTCurve3DQuasiUniformAbscissa(OCCTCurve3DRef curve, int32_t nbPoints, double* outParams)
{
  // outParams holds nbPoints doubles, which is not what the sampler is bounded by. See
  // occtSamplerKept/occtSamplerIndex in OCCTBridge_Internal.h (#501).
  if (!curve || curve->curve.IsNull() || !outParams || !occtValidSampleCount(nbPoints))
    return 0;
  try
  {
    GeomAdaptor_Curve           adaptor(curve->curve);
    GCPnts_QuasiUniformAbscissa sampler(adaptor, nbPoints);
    if (!sampler.IsDone())
      return 0;
    int32_t total = sampler.NbPoints();
    int32_t n     = occtSamplerKept(total, nbPoints);
    for (int32_t i = 0; i < n; i++)
    {
      outParams[i] = sampler.Parameter(occtSamplerIndex(i, n, total));
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTCurve3DQuasiUniformDeflection(OCCTCurve3DRef curve,
                                          double         deflection,
                                          double*        outXYZ,
                                          int32_t        maxPoints)
{
  if (!curve || curve->curve.IsNull() || !outXYZ || maxPoints <= 0)
    return 0;
  try
  {
    GeomAdaptor_Curve             adaptor(curve->curve);
    GCPnts_QuasiUniformDeflection sampler(adaptor, deflection);
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

bool OCCTCPntsUniformDeflection(OCCTShapeRef shape,
                                double       deflection,
                                double* _Nullable* _Nonnull outParams,
                                double* _Nullable* _Nonnull outPoints,
                                int32_t* outCount)
{
  return occtCPntsUniformDeflectionImpl(shape,
                                        deflection,
                                        0,
                                        0,
                                        false,
                                        outParams,
                                        outPoints,
                                        outCount);
}

bool OCCTCPntsUniformDeflectionRange(OCCTShapeRef shape,
                                     double       deflection,
                                     double       u1,
                                     double       u2,
                                     double* _Nullable* _Nonnull outParams,
                                     double* _Nullable* _Nonnull outPoints,
                                     int32_t* outCount)
{
  return occtCPntsUniformDeflectionImpl(shape,
                                        deflection,
                                        u1,
                                        u2,
                                        true,
                                        outParams,
                                        outPoints,
                                        outCount);
}

int32_t OCCTGCPntsQuasiUniform(OCCTEdgeRef _Nonnull edge,
                               int32_t nbPoints,
                               double* _Nonnull params,
                               int32_t maxParams)
{
  if (!occtShapeIsPresent(edge) || !occtValidSampleCount(nbPoints))
    return 0;
  try
  {
    BRepAdaptor_Curve           curve(TopoDS::Edge(edge->edge));
    GCPnts_QuasiUniformAbscissa sampler(curve, nbPoints);
    if (!sampler.IsDone())
      return 0;
    // This one always clamped, but to the tail, so whenever the sampler overshot the result
    // stopped short of the edge's last parameter. occtSamplerIndex keeps the end (#501).
    int32_t total = sampler.NbPoints();
    int32_t count = occtSamplerKept(total, maxParams);
    for (int32_t i = 0; i < count; i++)
    {
      params[i] = sampler.Parameter(occtSamplerIndex(i, count, total)); // 1-based
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

// These four are called twice by their Swift wrappers (once with params == nullptr to learn the
// count, then again with a buffer of exactly that size), so the sampler's own overshoot is already
// accounted for and there is nothing to clamp. The count preconditions still have to be applied
// here: without them nbPoints == 0 reported IsDone() with five parameters (#501).
int32_t OCCTUniformAbscissaByCount(OCCTShapeRef edge, int32_t nbPoints, double* params)
{
  if (!occtShapeIsPresent(edge) || !occtValidSampleCount(nbPoints))
    return 0;
  try
  {
    BRepAdaptor_Curve      ac(TopoDS::Edge(edge->shape));
    GCPnts_UniformAbscissa ua(ac, nbPoints);
    if (!ua.IsDone())
      return 0;
    int32_t n = (int32_t)ua.NbPoints();
    if (params)
    {
      for (int32_t i = 0; i < n; i++)
      {
        params[i] = ua.Parameter(i + 1);
      }
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTUniformAbscissaByDistance(OCCTShapeRef edge, double abscissa, double* params)
{
  if (!occtShapeIsPresent(edge))
    return 0;
  try
  {
    BRepAdaptor_Curve      ac(TopoDS::Edge(edge->shape));
    GCPnts_UniformAbscissa ua(ac, abscissa);
    if (!ua.IsDone())
      return 0;
    int32_t n = (int32_t)ua.NbPoints();
    if (params)
    {
      for (int32_t i = 0; i < n; i++)
      {
        params[i] = ua.Parameter(i + 1);
      }
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTUniformAbscissaByCountRange(OCCTShapeRef edge,
                                        int32_t      nbPoints,
                                        double       u1,
                                        double       u2,
                                        double*      params)
{
  if (!occtShapeIsPresent(edge) || !occtValidSampleCount(nbPoints))
    return 0;
  try
  {
    BRepAdaptor_Curve      ac(TopoDS::Edge(edge->shape));
    GCPnts_UniformAbscissa ua(ac, nbPoints, u1, u2);
    if (!ua.IsDone())
      return 0;
    int32_t n = (int32_t)ua.NbPoints();
    if (params)
    {
      for (int32_t i = 0; i < n; i++)
      {
        params[i] = ua.Parameter(i + 1);
      }
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTUniformAbscissaByDistanceRange(OCCTShapeRef edge,
                                           double       abscissa,
                                           double       u1,
                                           double       u2,
                                           double*      params)
{
  if (!occtShapeIsPresent(edge))
    return 0;
  try
  {
    BRepAdaptor_Curve      ac(TopoDS::Edge(edge->shape));
    GCPnts_UniformAbscissa ua(ac, abscissa, u1, u2);
    if (!ua.IsDone())
      return 0;
    int32_t n = (int32_t)ua.NbPoints();
    if (params)
    {
      for (int32_t i = 0; i < n; i++)
      {
        params[i] = ua.Parameter(i + 1);
      }
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

// occtAdaptorParameterAtLength, not GCPnts_AbscissaPoint directly: the kernel's root finder
// inverts the same single quadrature OCCTCurve3DGetLength no longer uses, so left alone it would
// answer 6.2438 for the full length of an 8 x 3 ellipse whose domain ends at 6.2832. #603.
double OCCTCurve3DParameterAtLength(OCCTCurve3DRef curve, double arcLength, double fromParam)
{
  if (!curve || curve->curve.IsNull())
    return 0;
  try
  {
    GeomAdaptor_Curve adaptor(curve->curve);
    double            parameter = 0;
    if (occtAdaptorParameterAtLength(adaptor, arcLength, fromParam, parameter))
      return parameter;
    return 0;
  }
  catch (...)
  {
    return 0;
  }
}
