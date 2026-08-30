//
//  OCCTBridge_Surface_Fill.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Surface.mm (#1380): GeomFill_* (Sweep, NSections, Trihedron laws, Coons,
//  Generator, Gordon, NetworkSurface, DegeneratedBound, Profiler, Stretch, LocationDraft,
//  GuideTrihedron*, SectionPlacement, AppSurf, ConstrainedFilling, EvolvedSection, CoonsAlgPatch).
//  Public C surface unchanged; every sibling file imports the same headers this one does
//  (the shared preamble below). No symbol changes, pure file move -- see
//  Scripts/repro/396-bridge-mm-split/ for how.
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

// === #491: one GeomConvert_ApproxSurface run behind both surface approximation entry points ===
//
// OCCTSurfaceApproximate (Surface.approximated) and OCCTGeomConvertApproxSurface
// (Surface.approxWithDetails) are two views of the same approximation: the first returns the fitted
// BSpline surface, the second returns it alongside the diagnostics OCCT already computed for it.
// They were written independently and passed different values for GeomConvert_ApproxSurface's
// eighth constructor argument (0 here, 1 there), so they returned measurably different surfaces
// for the same request. They run through this one helper instead.
//
// That argument is PrecisCode, "the index of precision", and it is a real algorithm knob rather
// than a reserved value: GeomConvert_ApproxSurface::Approximate forwards it unchanged into
// AdvApp2Var_ApproxAFunc2Var, which clamps it to [0, 3] and hands it to AdvApp2Var_Context as
// iprecis, where lesparam (AdvApp2Var_Context.cxx:22) turns it into the Jacobi degree and the
// initial per-axis sample-point count that seed the iterative fit. Different values therefore seed
// a different parameterisation for identical tolerance/continuity/degree/segment inputs.
//
// The shared value is 0. Measured over 72 bounded cases (8 surface families x 6 tolerances, plus
// C0/C1 and maxDegree 10 variants): the two codes never disagreed on IsDone, and produced the same
// knot/pole layout in 71 of 72, but a different maxError in all 72: smaller with 0 in 64 of them,
// and in the single layout-differing case (an offset sphere at tolerance 1e-5) 0 met the requested
// tolerance with 27x15 poles where 1 needed 27x23. A caller asking for a tolerance wants the
// lightest surface that meets it, which is what 0 delivered.
//
// OCCT itself is split on the value, and splits along that same line. Every live construction of
// GeomConvert_ApproxSurface in the pinned p1 kernel, counted by reading each site rather than by
// grepping filenames (#573):
//
//   PrecisCode 0, both accepting the fit only when MaxError() clears a tolerance they must honour:
//     ShapeCustom_BSplineRestriction.cxx:852  (ConvertSurface; on a miss it re-fits, raising the
//                                              approximation tolerance, doubling MaxSeg or dropping
//                                              a continuity, until the error stops improving)
//     ShapeConstruct.cxx:265                  (ConvertSurfaceToBSpline; on a miss it returns the
//                                              over-tolerance surface, and drops a continuity only
//                                              when the fit throws)
//
//   PrecisCode 1, none of which look at MaxError() at all:
//     GeomConvert_1.cxx:786, :960             (SurfaceToBSplineSurface, its trimmed and its direct
//                                              branch; both take Surface() unconditionally)
//     ShapeUpgrade_UnifySameDomain.cxx:3629   (IntUnifyFaces; unconditional)
//     GeomFill_Sweep.cxx:296                  (BuildAll; gates on HasResult only)
//     GeomLib.cxx:1517                        (ExtendSurfByLength; gates on HasResult only, then
//                                              falls back to GeomConvert::SurfaceToBSplineSurface)
//     BRepOffset_Offset.cxx:1626              (Init, the spherical vertex face; gates on IsDone
//                                              only, then falls back to the exact sphere)
//
// The discriminator is what a site does with the answer, not where its tolerance came from:
// BRepOffset_Offset passes the caller's TolApp (1e-4 by default) and still passes 1, because it
// never checks the fit against it. This bridge takes a caller's tolerance and hands MaxError()
// straight back, so it is in the first group.
//
// Two kernel files name the class and are not call sites. BRepFill_Sweep.cxx:1162 sits inside a
// /* */ block spanning :1064 to :1179 and BRepFill_Filling.cxx:712 is a //-commented line; neither
// is compiled. An earlier revision of this census listed the BRepFill_Sweep one in the 0 group,
// which is what #573 corrects, so do not re-add either from a filename-level grep. The two Draw/QA
// harness sites (GeomliteTest_SurfaceCommands.cxx:1044, which takes PrecisCode from the command
// line, and QABugs_19.cxx:244) are test code and are excluded deliberately.
//
// GeomPlate_MakeApprox has no PrecisCode to census: it drives AdvApp2Var_ApproxAFunc2Var directly
// instead of going through GeomConvert_ApproxSurface, which is why it sits outside this list and
// needed its own contract (#571).
//
// Note both entry points have always gated on HasResult(), which OCCT documents as true even for a
// result "not NECESSARILY within the required tolerance". Unlike the curve pair, the surface pair
// never drifted on that, and unlike the curve class, this one really can report HasResult without
// IsDone (a torus at tolerance 1e-9 does). Reporting that through isDone is what approxWithDetails
// is for.
//
// Continuity decodes through the #490 shared occtGeomAbsFromParametricContinuity rather than a
// local copy; this was the one call site that still had its own until the #491/#490 merge.
static OCCTApproxSurfaceResult occtApproxSurface(OCCTSurfaceRef s,
                                                 double         tolerance,
                                                 int32_t        uContinuity,
                                                 int32_t        vContinuity,
                                                 int32_t        maxSegments,
                                                 int32_t        maxDegree)
{
  OCCTApproxSurfaceResult result = {};
  // Both the outer handle and the surface it wraps: a null Geom_Surface reaches
  // GeomAdaptor_Surface, whose own Standard_NullObject precondition is compiled out of this
  // Release kernel.
  if (!s || s->surface.IsNull())
    return result;
  try
  {
    GeomConvert_ApproxSurface approx(s->surface,
                                     tolerance,
                                     occtGeomAbsFromParametricContinuity(uContinuity),
                                     occtGeomAbsFromParametricContinuity(vContinuity),
                                     maxDegree,
                                     maxDegree,
                                     maxSegments,
                                     /* PrecisCode */ 0);
    result.isDone    = approx.IsDone();
    result.hasResult = approx.HasResult();
    if (result.hasResult)
    {
      result.maxError                  = approx.MaxError();
      Handle(Geom_BSplineSurface) bspl = approx.Surface();
      if (!bspl.IsNull())
        result.surface = new OCCTSurface(bspl);
    }
  }
  catch (...)
  {
  }
  return result;
}

// Every curvature entry point goes through this one GeomLProp_SLProps construction, so the
// resolution argument, the linear tolerance IsCurvatureDefined() tests tangent vectors against
// for nullity, is stated once. OCCTSurfaceCurvatures used to construct its own with a hardcoded
// 1e-6, 10x looser than Precision::Confusion(), so the two APIs could disagree about whether
// curvature is defined at all for the same surface and the same (u, v) (#405). The resolution
// itself now comes from occtLocalPropsResolution(), shared with the Local* family that #405 left
// on its own 1e-10 (#494).
// Returns false (leaving the outputs untouched) where curvature is undefined. Since #595 every
// caller passes that false straight through to its own caller instead of substituting a value.
static bool occtSurfaceCurvaturePair(OCCTSurfaceRef s,
                                     double         u,
                                     double         v,
                                     double*        gaussian,
                                     double*        mean)
{
  if (!s || s->surface.IsNull())
    return false;
  try
  {
    GeomLProp_SLProps props = occtSurfaceLocalProps(s->surface, u, v, 2);
    if (!props.IsCurvatureDefined())
      return false;
    if (gaussian)
      *gaussian = props.GaussianCurvature();
    if (mean)
      *mean = props.MeanCurvature();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

static Handle(Geom_BSplineCurve) toBSplineCurve(const Handle(Geom_Curve)& curve)
{
  Handle(Geom_BSplineCurve) bsc = Handle(Geom_BSplineCurve)::DownCast(curve);
  if (!bsc.IsNull())
  {
    // Re-convert to ensure consistent parameterization
    return GeomConvert::CurveToBSplineCurve(curve, Convert_QuasiAngular);
  }
  // Convert any Geom_Curve to BSpline
  return GeomConvert::CurveToBSplineCurve(curve, Convert_QuasiAngular);
}

// #725: GeomConvert_CompBezierSurfacesToBSplineSurface has no rational path at all.
// GeomConvert_CompBezierSurfacesToBSplineSurface.cxx:374-389 computes
// `isrational |= IsURational() || IsVRational()` over every patch and then
// `Standard_NotImplemented_Raise_if(isrational, ...)`, which this project's Release kernel
// compiles out via No_Exception (the same defect class #640 fixed for
// math_GaussSetIntegration). The converter proceeds anyway, silently dropping every patch's
// weights and returning the POLYNOMIAL surface through the same control net, with
// IsDone() == true: measured on a rational quarter-cylinder Bezier patch, a 0.606602 radius
// error reported as success. Reject before constructing the converter using the exact
// predicate the compiled-out guard uses, mirroring #640's resolution. Clamping or silently
// dropping the weights is not an option here, for the same reason it was not in #430/#437.
static bool occtAnyBezierPatchIsRational(const TColGeom_Array2OfBezierSurface& bezArray)
{
  for (int32_t r = bezArray.LowerRow(); r <= bezArray.UpperRow(); r++)
  {
    for (int32_t c = bezArray.LowerCol(); c <= bezArray.UpperCol(); c++)
    {
      const Handle(Geom_BezierSurface)& bez = bezArray.Value(r, c);
      if (!bez.IsNull() && (bez->IsURational() || bez->IsVRational()))
        return true;
    }
  }
  return false;
}

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

static OCCTTrihedronFrame makeEmptyFrame()
{
  return {0, 0, 0, 0, 0, 0, 0, 0, 0};
}

// Helper: extract poles from GeomFill_Filling into flat array
// Returns actual pole count (nbU * nbV), outPoints must be pre-sized
static int extractFillingPoles(GeomFill_Filling& filling, double* outPoints, int maxPoints)
{
  int nbU   = filling.NbUPoles();
  int nbV   = filling.NbVPoles();
  int total = nbU * nbV;
  if (total > maxPoints)
    total = maxPoints;
  NCollection_Array2<gp_Pnt> poles(1, nbU, 1, nbV);
  filling.Poles(poles);
  int idx = 0;
  for (int i = 1; i <= nbU && idx < maxPoints; i++)
  {
    for (int j = 1; j <= nbV && idx < maxPoints; j++)
    {
      gp_Pnt pt              = poles(i, j);
      outPoints[idx * 3]     = pt.X();
      outPoints[idx * 3 + 1] = pt.Y();
      outPoints[idx * 3 + 2] = pt.Z();
      idx++;
    }
  }
  return total;
}

// Package one occtSurfaceToAnalytical answer as the C result both entry points return.
static OCCTSurfToAnaSurfResult occtSurfToAnaSurfResult(OCCTSurfaceRef _Nullable surfaceRef,
                                                       double        tolerance,
                                                       const double* uvBounds)
{
  OCCTSurfToAnaSurfResult result = {nullptr, 0, false};
  if (!surfaceRef)
    return result;
  Handle(Geom_Surface) resSurf;
  if (!occtSurfaceToAnalytical(reinterpret_cast<OCCTSurface*>(surfaceRef)->surface,
                               tolerance,
                               uvBounds,
                               resSurf,
                               result.gap))
  {
    return result;
  }
  result.surface = reinterpret_cast<OCCTSurfaceRef>(new OCCTSurface{resSurf});
  result.success = true;
  return result;
}

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

// Helper: build Geom_BSplineSurface from Convert_ElementarySurfaceToBSplineSurface result
// #801: use batch accessors (Poles/Weights/UKnots/VKnots/UMultiplicities/VMultiplicities)
// instead of deprecated per-index accessors on Convert_ElementarySurfaceToBSplineSurface.
static OCCTSurfaceRef buildSurfaceFromElementary(
  const Convert_ElementarySurfaceToBSplineSurface& conv)
{
  int nup = conv.NbUPoles(), nvp = conv.NbVPoles();
  int nuk = conv.NbUKnots(), nvk = conv.NbVKnots();
  int udeg = conv.UDegree(), vdeg = conv.VDegree();

  TColgp_Array2OfPnt   poles(1, nup, 1, nvp);
  TColStd_Array2OfReal weights(1, nup, 1, nvp);
  // Batch copy for poles/weights (2D arrays)
  const TColgp_Array2OfPnt&   convPoles   = conv.Poles();
  const TColStd_Array2OfReal& convWeights = conv.Weights();
  for (int i = 1; i <= nup; i++)
    for (int j = 1; j <= nvp; j++)
    {
      poles(i, j)   = convPoles.Value(i, j);
      weights(i, j) = convWeights.Value(i, j);
    }

  TColStd_Array1OfReal    uknots(1, nuk), vknots(1, nvk);
  TColStd_Array1OfInteger umults(1, nuk), vmults(1, nvk);
  // Batch copy for knots/mults (1D arrays)
  const TColStd_Array1OfReal&    convUKnots = conv.UKnots();
  const TColStd_Array1OfInteger& convUMults = conv.UMultiplicities();
  const TColStd_Array1OfReal&    convVKnots = conv.VKnots();
  const TColStd_Array1OfInteger& convVMults = conv.VMultiplicities();
  for (int i = 1; i <= nuk; i++)
  {
    uknots(i) = convUKnots.Value(i);
    umults(i) = convUMults.Value(i);
  }
  for (int i = 1; i <= nvk; i++)
  {
    vknots(i) = convVKnots.Value(i);
    vmults(i) = convVMults.Value(i);
  }

  Handle(Geom_BSplineSurface) bss = new Geom_BSplineSurface(poles,
                                                            weights,
                                                            uknots,
                                                            vknots,
                                                            umults,
                                                            vmults,
                                                            udeg,
                                                            vdeg,
                                                            conv.IsUPeriodic(),
                                                            conv.IsVPeriodic());
  if (bss.IsNull())
    return nullptr;
  OCCTSurface* result = new OCCTSurface();
  result->surface     = bss;
  return result;
}

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

OCCTSurfaceRef OCCTSurfaceCreatePipe(OCCTCurve3DRef path, double radius)
{
  if (!path || path->curve.IsNull() || radius <= 0)
    return nullptr;
  try
  {
    GeomFill_Pipe pipe(path->curve, radius);
    pipe.Perform(Standard_True, Standard_False);
    Handle(Geom_Surface) result = pipe.Surface();
    if (result.IsNull())
      return nullptr;
    return new OCCTSurface(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceCreatePipeWithSection(OCCTCurve3DRef path, OCCTCurve3DRef section)
{
  if (!path || path->curve.IsNull() || !section || section->curve.IsNull())
    return nullptr;
  try
  {
    GeomFill_Pipe pipe(path->curve, section->curve);
    pipe.Perform(Standard_True, Standard_False);
    Handle(Geom_Surface) result = pipe.Surface();
    if (result.IsNull())
      return nullptr;
    return new OCCTSurface(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceBezierFill4(OCCTCurve3DRef c1,
                                      OCCTCurve3DRef c2,
                                      OCCTCurve3DRef c3,
                                      OCCTCurve3DRef c4,
                                      int32_t        fillStyle)
{
  if (!c1 || c1->curve.IsNull() || !c2 || c2->curve.IsNull() || !c3 || c3->curve.IsNull() || !c4
      || c4->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_BezierCurve) bc1 = Handle(Geom_BezierCurve)::DownCast(c1->curve);
    Handle(Geom_BezierCurve) bc2 = Handle(Geom_BezierCurve)::DownCast(c2->curve);
    Handle(Geom_BezierCurve) bc3 = Handle(Geom_BezierCurve)::DownCast(c3->curve);
    Handle(Geom_BezierCurve) bc4 = Handle(Geom_BezierCurve)::DownCast(c4->curve);
    if (bc1.IsNull() || bc2.IsNull() || bc3.IsNull() || bc4.IsNull())
      return nullptr;
    GeomFill_FillingStyle style = GeomFill_StretchStyle;
    if (fillStyle == 1)
      style = GeomFill_CoonsStyle;
    else if (fillStyle == 2)
      style = GeomFill_CurvedStyle;
    GeomFill_BezierCurves      filler(bc1, bc2, bc3, bc4, style);
    Handle(Geom_BezierSurface) surf = filler.Surface();
    if (surf.IsNull())
      return nullptr;
    return new OCCTSurface(surf);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceBezierFill2(OCCTCurve3DRef c1, OCCTCurve3DRef c2, int32_t fillStyle)
{
  if (!c1 || c1->curve.IsNull() || !c2 || c2->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_BezierCurve) bc1 = Handle(Geom_BezierCurve)::DownCast(c1->curve);
    Handle(Geom_BezierCurve) bc2 = Handle(Geom_BezierCurve)::DownCast(c2->curve);
    if (bc1.IsNull() || bc2.IsNull())
      return nullptr;
    GeomFill_FillingStyle style = GeomFill_StretchStyle;
    if (fillStyle == 1)
      style = GeomFill_CoonsStyle;
    else if (fillStyle == 2)
      style = GeomFill_CurvedStyle;
    GeomFill_BezierCurves      filler(bc1, bc2, style);
    Handle(Geom_BezierSurface) surf = filler.Surface();
    if (surf.IsNull())
      return nullptr;
    return new OCCTSurface(surf);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceFillBSpline2Curves(OCCTCurve3DRef curve1,
                                             OCCTCurve3DRef curve2,
                                             int32_t        fillStyle)
{
  if (!curve1 || !curve2 || curve1->curve.IsNull() || curve2->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_BSplineCurve) c1 = toBSplineCurve(curve1->curve);
    Handle(Geom_BSplineCurve) c2 = toBSplineCurve(curve2->curve);
    if (c1.IsNull() || c2.IsNull())
      return nullptr;

    GeomFill_FillingStyle style = GeomFill_StretchStyle;
    if (fillStyle == 1)
      style = GeomFill_CoonsStyle;
    else if (fillStyle == 2)
      style = GeomFill_CurvedStyle;

    GeomFill_BSplineCurves      filler(c1, c2, style);
    Handle(Geom_BSplineSurface) surf = filler.Surface();
    if (surf.IsNull())
      return nullptr;
    return new OCCTSurface(surf);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceFillBSpline4Curves(OCCTCurve3DRef c1,
                                             OCCTCurve3DRef c2,
                                             OCCTCurve3DRef c3,
                                             OCCTCurve3DRef c4,
                                             int32_t        fillStyle)
{
  if (!c1 || !c2 || !c3 || !c4)
    return nullptr;
  if (c1->curve.IsNull() || c2->curve.IsNull() || c3->curve.IsNull() || c4->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_BSplineCurve) bc1 = toBSplineCurve(c1->curve);
    Handle(Geom_BSplineCurve) bc2 = toBSplineCurve(c2->curve);
    Handle(Geom_BSplineCurve) bc3 = toBSplineCurve(c3->curve);
    Handle(Geom_BSplineCurve) bc4 = toBSplineCurve(c4->curve);
    if (bc1.IsNull() || bc2.IsNull() || bc3.IsNull() || bc4.IsNull())
      return nullptr;

    GeomFill_FillingStyle style = GeomFill_StretchStyle;
    if (fillStyle == 1)
      style = GeomFill_CoonsStyle;
    else if (fillStyle == 2)
      style = GeomFill_CurvedStyle;

    GeomFill_BSplineCurves      filler(bc1, bc2, bc3, bc4, style);
    Handle(Geom_BSplineSurface) surf = filler.Surface();
    if (surf.IsNull())
      return nullptr;
    return new OCCTSurface(surf);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTGeomFillConstrained(OCCTEdgeRef edge1,
                                     OCCTEdgeRef edge2,
                                     OCCTEdgeRef edge3,
                                     OCCTEdgeRef edge4,
                                     int32_t     maxDeg,
                                     int32_t     maxSeg)
{
  if (!edge1 || !edge2 || !edge3)
    return nullptr;
  try
  {
    // Extract curves from edges
    auto getCurve = [](const TopoDS_Edge& edge) -> Handle(Geom_TrimmedCurve) {
      double             first, last;
      Handle(Geom_Curve) curve = BRep_Tool::Curve(edge, first, last);
      if (curve.IsNull())
        return nullptr;
      return new Geom_TrimmedCurve(curve, first, last);
    };

    Handle(Geom_TrimmedCurve) c1 = getCurve(edge1->edge);
    Handle(Geom_TrimmedCurve) c2 = getCurve(edge2->edge);
    Handle(Geom_TrimmedCurve) c3 = getCurve(edge3->edge);
    if (c1.IsNull() || c2.IsNull() || c3.IsNull())
      return nullptr;

    Handle(GeomFill_SimpleBound) b1 =
      new GeomFill_SimpleBound(new GeomAdaptor_Curve(c1), 1e-4, 1e-4);
    Handle(GeomFill_SimpleBound) b2 =
      new GeomFill_SimpleBound(new GeomAdaptor_Curve(c2), 1e-4, 1e-4);
    Handle(GeomFill_SimpleBound) b3 =
      new GeomFill_SimpleBound(new GeomAdaptor_Curve(c3), 1e-4, 1e-4);

    GeomFill_ConstrainedFilling filler(maxDeg, maxSeg);

    if (edge4)
    {
      Handle(Geom_TrimmedCurve) c4 = getCurve(edge4->edge);
      if (c4.IsNull())
        return nullptr;
      Handle(GeomFill_SimpleBound) b4 =
        new GeomFill_SimpleBound(new GeomAdaptor_Curve(c4), 1e-4, 1e-4);
      filler.Init(b1, b2, b3, b4);
    }
    else
    {
      filler.Init(b1, b2, b3);
    }

    Handle(Geom_BSplineSurface) surface = filler.Surface();
    if (surface.IsNull())
      return nullptr;

    // Build a face from the surface
    BRepBuilderAPI_MakeFace faceMaker(surface, 1e-6);
    if (!faceMaker.IsDone())
      return nullptr;
    return new OCCTShape(faceMaker.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

int OCCTGeomFillCoonsPoles(const double* b1,
                           const double* b2,
                           const double* b3,
                           const double* b4,
                           int           pointsPerSide,
                           double*       outPoints,
                           int           maxPoints,
                           int*          outNbU,
                           int*          outNbV)
{
  if (!b1 || !b2 || !b3 || !b4 || !outPoints || pointsPerSide < 2)
    return 0;
  try
  {
    NCollection_Array1<gp_Pnt> P1(1, pointsPerSide), P2(1, pointsPerSide), P3(1, pointsPerSide),
      P4(1, pointsPerSide);
    for (int i = 0; i < pointsPerSide; i++)
    {
      P1(i + 1) = gp_Pnt(b1[i * 3], b1[i * 3 + 1], b1[i * 3 + 2]);
      P2(i + 1) = gp_Pnt(b2[i * 3], b2[i * 3 + 1], b2[i * 3 + 2]);
      P3(i + 1) = gp_Pnt(b3[i * 3], b3[i * 3 + 1], b3[i * 3 + 2]);
      P4(i + 1) = gp_Pnt(b4[i * 3], b4[i * 3 + 1], b4[i * 3 + 2]);
    }
    GeomFill_Coons coons(P1, P2, P3, P4);
    if (outNbU)
      *outNbU = coons.NbUPoles();
    if (outNbV)
      *outNbV = coons.NbVPoles();
    return extractFillingPoles(coons, outPoints, maxPoints);
  }
  catch (...)
  {
    return 0;
  }
}

int OCCTGeomFillCurvedPoles(const double* b1,
                            const double* b2,
                            const double* b3,
                            const double* b4,
                            int           pointsPerSide,
                            double*       outPoints,
                            int           maxPoints,
                            int*          outNbU,
                            int*          outNbV)
{
  if (!b1 || !b2 || !b3 || !b4 || !outPoints || pointsPerSide < 2)
    return 0;
  try
  {
    NCollection_Array1<gp_Pnt> P1(1, pointsPerSide), P2(1, pointsPerSide), P3(1, pointsPerSide),
      P4(1, pointsPerSide);
    for (int i = 0; i < pointsPerSide; i++)
    {
      P1(i + 1) = gp_Pnt(b1[i * 3], b1[i * 3 + 1], b1[i * 3 + 2]);
      P2(i + 1) = gp_Pnt(b2[i * 3], b2[i * 3 + 1], b2[i * 3 + 2]);
      P3(i + 1) = gp_Pnt(b3[i * 3], b3[i * 3 + 1], b3[i * 3 + 2]);
      P4(i + 1) = gp_Pnt(b4[i * 3], b4[i * 3 + 1], b4[i * 3 + 2]);
    }
    GeomFill_Curved curved(P1, P2, P3, P4);
    if (outNbU)
      *outNbU = curved.NbUPoles();
    if (outNbV)
      *outNbV = curved.NbVPoles();
    return extractFillingPoles(curved, outPoints, maxPoints);
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTGeomFillCoonsAlgPatchEval(OCCTShapeRef edge1,
                                   OCCTShapeRef edge2,
                                   OCCTShapeRef edge3,
                                   OCCTShapeRef edge4,
                                   int          evalU,
                                   int          evalV,
                                   double*      outPoints)
{
  if (!edge1 || !edge2 || !edge3 || !edge4 || !outPoints)
    return;
  try
  {
    auto makeAdaptor = [](OCCTShapeRef e) -> Handle(GeomAdaptor_Curve) {
      TopoDS_Edge        edge = TopoDS::Edge(e->shape);
      double             f, l;
      Handle(Geom_Curve) curve = BRep_Tool::Curve(edge, f, l);
      return new GeomAdaptor_Curve(curve, f, l);
    };
    Handle(GeomAdaptor_Curve) ac1 = makeAdaptor(edge1);
    Handle(GeomAdaptor_Curve) ac2 = makeAdaptor(edge2);
    Handle(GeomAdaptor_Curve) ac3 = makeAdaptor(edge3);
    Handle(GeomAdaptor_Curve) ac4 = makeAdaptor(edge4);

    Handle(GeomFill_SimpleBound) b1 = new GeomFill_SimpleBound(ac1, 1e-3, 1e-3);
    Handle(GeomFill_SimpleBound) b2 = new GeomFill_SimpleBound(ac2, 1e-3, 1e-3);
    Handle(GeomFill_SimpleBound) b3 = new GeomFill_SimpleBound(ac3, 1e-3, 1e-3);
    Handle(GeomFill_SimpleBound) b4 = new GeomFill_SimpleBound(ac4, 1e-3, 1e-3);

    GeomFill_CoonsAlgPatch patch(b1, b2, b3, b4);
    for (int i = 0; i < evalU; i++)
    {
      for (int j = 0; j < evalV; j++)
      {
        double u           = (evalU > 1) ? (double)i / (evalU - 1) : 0.5;
        double v           = (evalV > 1) ? (double)j / (evalV - 1) : 0.5;
        gp_Pnt pt          = patch.Value(u, v);
        int    idx         = (i * evalV + j) * 3;
        outPoints[idx]     = pt.X();
        outPoints[idx + 1] = pt.Y();
        outPoints[idx + 2] = pt.Z();
      }
    }
  }
  catch (...)
  {
  }
}

OCCTShapeRef _Nullable OCCTGeomFillSweep(OCCTShapeRef pathEdge, OCCTShapeRef sectionEdge)
{
  if (!pathEdge || !sectionEdge)
    return nullptr;
  try
  {
    // Path curve
    TopoDS_Edge        path = TopoDS::Edge(pathEdge->shape);
    double             pf, pl;
    Handle(Geom_Curve) pathCurve = BRep_Tool::Curve(path, pf, pl);
    if (pathCurve.IsNull())
      return nullptr;
    Handle(GeomAdaptor_Curve) pathAdaptor = new GeomAdaptor_Curve(pathCurve, pf, pl);

    // Section curve
    TopoDS_Edge        section = TopoDS::Edge(sectionEdge->shape);
    double             sf, sl;
    Handle(Geom_Curve) sectionCurve = BRep_Tool::Curve(section, sf, sl);
    if (sectionCurve.IsNull())
      return nullptr;

    // Trihedron + location
    Handle(GeomFill_CorrectedFrenet)   trihedron = new GeomFill_CorrectedFrenet();
    Handle(GeomFill_CurveAndTrihedron) location  = new GeomFill_CurveAndTrihedron(trihedron);
    location->SetCurve(pathAdaptor);

    // Section law
    Handle(GeomFill_UniformSection) sectionLaw = new GeomFill_UniformSection(sectionCurve);

    // Sweep
    // #597: GeomFill_Sweep::Build's general path (BuildAll) always fits the swept surface
    // with an internal Approx_SweepApproximation and records the achieved deviation in
    // ErrorOnSurface(). IsDone() alone says only that SOME surface was produced, not that
    // it is within the tolerance this call asks for. This entry point used to accept
    // whatever Build() returned without ever reading that number: the same "accepts an
    // approximation without reading the error it reports" shape #597 names at
    // GeomFill_Sweep.cxx:296 and ShapeUpgrade_UnifySameDomain.cxx:3629, except neither of
    // those two sites is reachable from this file (see the PR body for the measurement;
    // both live behind PipeShellBuilder/UnifySameDomainBuilder in OCCTBridge_Modeling.mm),
    // and the ForceApproxC1 one's reported error is a hardcoded constant that cannot move
    // once that branch fires, the same shape as #522's zero, so reading it would not have
    // helped even from there. Here the number is real and does move, so reject rather than
    // silently hand back a surface that missed the tolerance it was built at.
    // A bridge-chosen fit tolerance, not an OCCT default: GeomFill_Sweep::SetTolerance(const
    // double Tol3d, const double BoundTol = 1.0, const double Tol2d = 1.0e-5, const double
    // TolAngular = 1.0) has no default for Tol3d at all, and none of its three actual
    // defaults equals 1e-4. Not caller-configurable today (Shape.geomFillSweep(path:section:)
    // takes no tolerance parameter, unlike the sibling GeomFill_NetworkSurface/GeomFill_Gordon
    // entry points in this file); left that way here rather than as a drive-by API change --
    // see the PR notes for why.
    const double   tolerance = 1e-4;
    GeomFill_Sweep sweep(location);
    sweep.SetTolerance(tolerance);
    sweep.Build(sectionLaw, GeomFill_Location, GeomAbs_C2, 10, 50);
    if (!sweep.IsDone())
      return nullptr;
    if (sweep.ErrorOnSurface() > tolerance)
      return nullptr;

    Handle(Geom_Surface) surface = sweep.Surface();
    if (surface.IsNull())
      return nullptr;

    BRepBuilderAPI_MakeFace mf(surface, 1e-6);
    if (!mf.IsDone())
      return nullptr;
    return new OCCTShape(mf.Face());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTEvolvedSectionInfo OCCTGeomFillEvolvedSectionInfo(OCCTShapeRef edgeShape)
{
  OCCTEvolvedSectionInfo result = {0, 0, 0, false};
  if (!edgeShape)
    return result;
  try
  {
    TopoDS_Edge        edge = TopoDS::Edge(edgeShape->shape);
    double             f, l;
    Handle(Geom_Curve) curve = BRep_Tool::Curve(edge, f, l);
    if (curve.IsNull())
      return result;

    Handle(Law_Constant) law = new Law_Constant();
    law->Set(1.0, 0.0, 1.0);
    GeomFill_EvolvedSection evolved(curve, law);

    int nbPoles, nbKnots, degree;
    evolved.SectionShape(nbPoles, nbKnots, degree);
    result.nbPoles    = nbPoles;
    result.nbKnots    = nbKnots;
    result.degree     = degree;
    result.isRational = evolved.IsRational();
  }
  catch (...)
  {
  }
  return result;
}

OCCTTrihedronFrame OCCTGeomFillFixedTrihedron(double tangentX,
                                              double tangentY,
                                              double tangentZ,
                                              double normalX,
                                              double normalY,
                                              double normalZ,
                                              double param)
{
  OCCTTrihedronFrame frame = {};
  try
  {
    Handle(GeomFill_Fixed) fixed =
      new GeomFill_Fixed(gp_Vec(tangentX, tangentY, tangentZ), gp_Vec(normalX, normalY, normalZ));
    gp_Vec t, n, b;
    if (fixed->D0(param, t, n, b))
    {
      frame.tx = t.X();
      frame.ty = t.Y();
      frame.tz = t.Z();
      frame.nx = n.X();
      frame.ny = n.Y();
      frame.nz = n.Z();
      frame.bx = b.X();
      frame.by = b.Y();
      frame.bz = b.Z();
    }
  }
  catch (...)
  {
  }
  return frame;
}

OCCTSurfaceRef OCCTGeomFillNSections(const OCCTCurve3DRef* curveRefs,
                                     const double*         params,
                                     int32_t               count)
{
  try
  {
    NCollection_Sequence<Handle(Geom_Curve)> sections;
    NCollection_Sequence<double>             paramSeq;
    for (int32_t i = 0; i < count; i++)
    {
      auto* wrapper = reinterpret_cast<OCCTCurve3D*>(curveRefs[i]);
      if (!wrapper || wrapper->curve.IsNull())
        return nullptr;
      sections.Append(wrapper->curve);
      paramSeq.Append(params[i]);
    }

    Handle(GeomFill_NSections) nsec = new GeomFill_NSections(sections, paramSeq);
    nsec->ComputeSurface();
    Handle(Geom_BSplineSurface) surf = nsec->BSplineSurface();
    if (surf.IsNull())
      return nullptr;

    auto* result    = new OCCTSurface();
    result->surface = surf;
    return reinterpret_cast<OCCTSurfaceRef>(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTGeomFillNSectionsInfo(const OCCTCurve3DRef* curveRefs,
                               const double*         params,
                               int32_t               count,
                               int32_t*              outNbPoles,
                               int32_t*              outNbKnots,
                               int32_t*              outDegree)
{
  *outNbPoles = 0;
  *outNbKnots = 0;
  *outDegree  = 0;
  try
  {
    NCollection_Sequence<Handle(Geom_Curve)> sections;
    NCollection_Sequence<double>             paramSeq;
    for (int32_t i = 0; i < count; i++)
    {
      auto* wrapper = reinterpret_cast<OCCTCurve3D*>(curveRefs[i]);
      if (!wrapper || wrapper->curve.IsNull())
        return;
      sections.Append(wrapper->curve);
      paramSeq.Append(params[i]);
    }

    Handle(GeomFill_NSections) nsec = new GeomFill_NSections(sections, paramSeq);
    int                        nbP = 0, nbK = 0, deg = 0;
    nsec->SectionShape(nbP, nbK, deg);
    *outNbPoles = (int32_t)nbP;
    *outNbKnots = (int32_t)nbK;
    *outDegree  = (int32_t)deg;
  }
  catch (...)
  {
  }
}

OCCTSurfaceRef OCCTGeomFillGenerator(const OCCTCurve3DRef* curves,
                                     int32_t               curveCount,
                                     double                tolerance)
{
  try
  {
    GeomFill_Generator gen;

    for (int i = 0; i < curveCount; i++)
    {
      auto* cw = (OCCTCurve3D*)curves[i];
      if (!cw || cw->curve.IsNull())
        return nullptr;
      gen.AddCurve(cw->curve);
    }

    gen.Perform(tolerance);
    Handle(Geom_Surface) surf = gen.Surface();
    if (surf.IsNull())
      return nullptr;

    auto* out    = new OCCTSurface();
    out->surface = surf;
    return (OCCTSurfaceRef)out;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTBoundaryPoint OCCTGeomFillDegeneratedBoundValue(double px,
                                                    double py,
                                                    double pz,
                                                    double first,
                                                    double last,
                                                    double param)
{
  OCCTBoundaryPoint result = {};
  try
  {
    Handle(GeomFill_DegeneratedBound) db =
      new GeomFill_DegeneratedBound(gp_Pnt(px, py, pz), first, last, 1e-3, 1e-3);
    gp_Pnt val = db->Value(param);
    result.x   = val.X();
    result.y   = val.Y();
    result.z   = val.Z();
  }
  catch (...)
  {
  }
  return result;
}

bool OCCTGeomFillDegeneratedBoundIsDegenerated(double px,
                                               double py,
                                               double pz,
                                               double first,
                                               double last)
{
  try
  {
    Handle(GeomFill_DegeneratedBound) db =
      new GeomFill_DegeneratedBound(gp_Pnt(px, py, pz), first, last, 1e-3, 1e-3);
    return db->IsDegenerated();
  }
  catch (...)
  {
    return false;
  }
}

void OCCTGeomFillProfilerAddCurve(OCCTGeomFillProfilerRef _Nonnull ref,
                                  OCCTCurve3DRef _Nonnull curveRef)
{
  try
  {
    auto* opaque = (GeomFillProfilerOpaque*)ref;
    // Bound through curveRef->curve (not this file's other *(const Handle(Geom_Curve)*)curveRef
    // cast idiom) specifically so check-null-handle-guards.py's already-recognised "handle
    // alias" form can see this guard: a future removal is then a CI failure, not a silent
    // regression.
    const Handle(Geom_Curve)& curve = curveRef->curve;
    // #710: GeomFill_Profiler::AddCurve dereferences Curve unconditionally
    // (Curve->IsInstance(...) before any null check), an uncatchable SIGSEGV on a null Handle.
    if (curve.IsNull())
      return;
    opaque->profiler.AddCurve(curve);
  }
  catch (...)
  {
  }
}

// MARK: - GeomFill_Stretch (v0.79)
// --- GeomFill_Stretch ---
OCCTStretchFillResult OCCTGeomFillStretch(const double* _Nonnull p1,
                                          const double* _Nonnull p2,
                                          const double* _Nonnull p3,
                                          const double* _Nonnull p4,
                                          int count,
                                          double* _Nullable outPoles,
                                          int maxPoles)
{
  OCCTStretchFillResult result = {};
  try
  {
    NCollection_Array1<gp_Pnt> P1(1, count), P2(1, count), P3(1, count), P4(1, count);
    for (int i = 0; i < count; i++)
    {
      P1(i + 1) = gp_Pnt(p1[i * 3], p1[i * 3 + 1], p1[i * 3 + 2]);
      P2(i + 1) = gp_Pnt(p2[i * 3], p2[i * 3 + 1], p2[i * 3 + 2]);
      P3(i + 1) = gp_Pnt(p3[i * 3], p3[i * 3 + 1], p3[i * 3 + 2]);
      P4(i + 1) = gp_Pnt(p4[i * 3], p4[i * 3 + 1], p4[i * 3 + 2]);
    }

    GeomFill_Stretch stretch(P1, P2, P3, P4);
    result.nbUPoles   = stretch.NbUPoles();
    result.nbVPoles   = stretch.NbVPoles();
    result.isRational = stretch.isRational();

    if (outPoles && maxPoles >= result.nbUPoles * result.nbVPoles)
    {
      NCollection_Array2<gp_Pnt> poles(1, result.nbUPoles, 1, result.nbVPoles);
      stretch.Poles(poles);
      int idx = 0;
      for (int u = 1; u <= result.nbUPoles; u++)
      {
        for (int v = 1; v <= result.nbVPoles; v++)
        {
          outPoles[idx++] = poles(u, v).X();
          outPoles[idx++] = poles(u, v).Y();
          outPoles[idx++] = poles(u, v).Z();
        }
      }
    }
  }
  catch (...)
  {
  }
  return result;
}

OCCTLocationDraftRef OCCTGeomFillLocationDraftCreate(double dirX,
                                                     double dirY,
                                                     double dirZ,
                                                     double angle)
{
  try
  {
    auto* opaque = new LocationDraftOpaque();
    opaque->loc  = new GeomFill_LocationDraft(gp_Dir(dirX, dirY, dirZ), angle);
    return opaque;
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - GeomFill_SectionPlacement (v0.79)
// --- GeomFill_SectionPlacement ---
OCCTSectionPlacementResult OCCTGeomFillSectionPlacement(OCCTCurve3DRef _Nonnull pathCurveRef,
                                                        OCCTCurve3DRef _Nonnull sectionCurveRef,
                                                        double dirX,
                                                        double dirY,
                                                        double dirZ,
                                                        double draftAngle,
                                                        double tolerance)
{
  OCCTSectionPlacementResult result = {};
  try
  {
    const Handle(Geom_Curve)& pathCurve = *(const Handle(Geom_Curve)*)pathCurveRef;
    // Bound through sectionCurveRef->curve (not pathCurve's *(const Handle(Geom_Curve)*)ref
    // cast above) specifically so check-null-handle-guards.py's already-recognised "handle
    // alias" form can see this guard: a future removal is then a CI failure, not a silent
    // regression. pathCurve is left on the cast form deliberately: it needs no guard (see
    // below), and an ALLOWED entry would have to be keyed by function, exempting sectionCurve
    // too and blinding the checker to the guard this comment is about.
    const Handle(Geom_Curve)& sectionCurve = sectionCurveRef->curve;
    // #710: pathCurve is safe -- GeomAdaptor_Curve below raises a catchable Standard_Failure
    // on a null Handle. sectionCurve is not: the GeomFill_SectionPlacement ctor dereferences
    // Section unconditionally (Section->IsInstance(...) before any null check), an uncatchable
    // SIGSEGV on a null Handle.
    if (sectionCurve.IsNull())
      return result;

    Handle(GeomFill_LocationDraft) loc =
      new GeomFill_LocationDraft(gp_Dir(dirX, dirY, dirZ), draftAngle);
    Handle(GeomAdaptor_Curve) pathAdaptor = new GeomAdaptor_Curve(pathCurve);
    loc->SetCurve(pathAdaptor);

    GeomFill_SectionPlacement placement(loc, sectionCurve);
    placement.Perform(tolerance);

    result.isDone = placement.IsDone();
    if (result.isDone)
    {
      result.parameterOnPath    = placement.ParameterOnPath();
      result.parameterOnSection = placement.ParameterOnSection();
      result.distance           = placement.Distance();
      result.angle              = placement.Angle();
    }
  }
  catch (...)
  {
  }
  return result;
}

// MARK: - GeomFill_AppSurf (v0.79)
// --- GeomFill_AppSurf ---
OCCTAppSurfResult OCCTGeomFillAppSurf(const OCCTCurve3DRef _Nonnull* _Nonnull curveRefs,
                                      int    count,
                                      int    degMin,
                                      int    degMax,
                                      double tol3d,
                                      double tol2d)
{
  OCCTAppSurfResult result = {};
  try
  {
    // #644: GeomFill_AppSurf's approximation solver is never driven with fewer than 2
    // sections anywhere in the kernel; a single section SIGSEGVs setting up the solver's
    // degree-of-freedom bookkeeping. Surface.appSurf(curves:) guards this at the Swift
    // boundary (matching nSections/generatedFromSections' own `count >= 2` guard for the same
    // GeomFill_* family), so `count` is never < 2 through the public API -- this bridge
    // function itself carries no separate count guard, matching those two siblings' own
    // bridge-side C functions.
    GeomFill_SectionGenerator secGen;
    for (int i = 0; i < count; i++)
    {
      // Bound through curveRefs[i]->curve (not this file's other
      // *(const Handle(Geom_Curve)*)ref cast idiom) specifically so
      // check-null-handle-guards.py's already-recognised "handle alias" form can see this
      // guard: a future removal is then a CI failure, not a silent regression.
      const Handle(Geom_Curve)& curve = curveRefs[i]->curve;
      // #710: GeomFill_SectionGenerator::AddCurve is the inherited, non-virtual
      // GeomFill_Profiler::AddCurve, which dereferences curve unconditionally -- an
      // uncatchable SIGSEGV on a null Handle, same mechanism as
      // OCCTGeomFillProfilerAddCurve above.
      if (curve.IsNull())
        return result;
      secGen.AddCurve(curve);
    }
    secGen.Perform(1e-6);

    Handle(NCollection_HArray1<double>) params = new NCollection_HArray1<double>(1, count);
    for (int i = 0; i < count; i++)
    {
      params->SetValue(i + 1, (double)i / (double)(count - 1));
    }
    secGen.SetParam(params);

    Handle(GeomFill_Line) line = new GeomFill_Line(count);

    GeomFill_AppSurf appSurf(degMin, degMax, tol3d, tol2d, 10, false);
    appSurf.Perform(line, secGen, false);

    result.isDone = appSurf.IsDone();
    if (result.isDone)
    {
      appSurf.SurfShape(result.uDegree,
                        result.vDegree,
                        result.nbUPoles,
                        result.nbVPoles,
                        result.nbUKnots,
                        result.nbVKnots);
    }
  }
  catch (...)
  {
  }
  return result;
}

OCCTSurfaceRef OCCTGeomFillGordon(const OCCTCurve3DRef* profiles,
                                  int32_t               profileCount,
                                  const OCCTCurve3DRef* guides,
                                  int32_t               guideCount,
                                  double                tolerance)
{
  if (!profiles || !guides || profileCount < 2 || guideCount < 2)
    return nullptr;
  try
  {
    NCollection_Array1<occ::handle<Geom_Curve>> profs(0, profileCount - 1);
    for (int i = 0; i < profileCount; i++)
    {
      if (!profiles[i] || profiles[i]->curve.IsNull())
        return nullptr;
      profs.SetValue(i, profiles[i]->curve);
    }
    NCollection_Array1<occ::handle<Geom_Curve>> gds(0, guideCount - 1);
    for (int i = 0; i < guideCount; i++)
    {
      if (!guides[i] || guides[i]->curve.IsNull())
        return nullptr;
      gds.SetValue(i, guides[i]->curve);
    }

    GeomFill_Gordon gordon;
    gordon.Init(profs, gds, tolerance);
    gordon.Perform();
    if (!gordon.IsDone())
      return nullptr;

    auto surf = gordon.Surface();
    if (surf.IsNull())
      return nullptr;

    auto ref     = new OCCTSurface();
    ref->surface = surf;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

// Build a Gordon surface reporting status + approximate flag.
OCCTSurfaceRef OCCTGeomFillGordonReport(const OCCTCurve3DRef* profiles,
                                        int32_t               profileCount,
                                        const OCCTCurve3DRef* guides,
                                        int32_t               guideCount,
                                        double                tolerance,
                                        int32_t               approximationMode,
                                        int32_t*              outStatus,
                                        bool*                 outIsApproximate)
{
  if (outStatus)
    *outStatus = (int32_t)GeomFill_Gordon::ResultStatus::NotStarted;
  if (outIsApproximate)
    *outIsApproximate = false;
  if (!profiles || !guides || profileCount < 2 || guideCount < 2)
  {
    if (outStatus)
      *outStatus = (int32_t)GeomFill_Gordon::ResultStatus::InvalidInput;
    return nullptr;
  }
  try
  {
    NCollection_Array1<occ::handle<Geom_Curve>> profs(0, profileCount - 1);
    for (int i = 0; i < profileCount; i++)
    {
      if (!profiles[i] || profiles[i]->curve.IsNull())
        return nullptr;
      profs.SetValue(i, profiles[i]->curve);
    }
    NCollection_Array1<occ::handle<Geom_Curve>> gds(0, guideCount - 1);
    for (int i = 0; i < guideCount; i++)
    {
      if (!guides[i] || guides[i]->curve.IsNull())
        return nullptr;
      gds.SetValue(i, guides[i]->curve);
    }

    GeomFill_Gordon gordon;
    gordon.SetApproximationMode(approximationMode == 1
                                  ? GeomFill_Gordon::ApproximationMode::AllowApproximateFallback
                                  : GeomFill_Gordon::ApproximationMode::ExactOnly);
    gordon.Init(profs, gds, tolerance);
    gordon.Perform();

    if (outStatus)
      *outStatus = (int32_t)gordon.Status();
    if (outIsApproximate)
      *outIsApproximate = gordon.IsApproximate();

    if (!gordon.IsDone())
      return nullptr;
    auto surf = gordon.Surface();
    if (surf.IsNull())
      return nullptr;

    auto ref     = new OCCTSurface();
    ref->surface = surf;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

// #689: real per-pair contact points and RAW (not normalized) locator parameters.
//
// GeomFill_NetworkSurface::Perform() builds a profile skin whose U-axis is the profile
// curves' own natural parameter domain and a guide skin whose U-axis is theGuideParameters
// (GeomFill_NetworkSurface.cxx's makeNetworkSurface/alignSurfaces); the two are required to
// share ONE knot RANGE (sameKnotRange, called from uniteKnots) before either is aligned to the
// other. theGuideParameters is documented as "U parameters locating guides on profile skin",
// i.e. it has to live in the profile curves' own domain, not a caller-invented one, and the
// mirror image holds for theProfileParameters against the guide curves' domain. The previous
// implementation stuffed a uniform [0,1] fraction into both arrays regardless of what domain
// the curves actually used, which only shares a range with a profile/guide domain that also
// happens to be [0,1] by coincidence. Measured directly (see PR body): that is why every
// fixture tried failed identically with KnotAlignmentFailed, including the simplest possible
// 2x2 bilinear patch built from two unit-length straight lines each way, a network that is
// otherwise a perfect, error-free fit.
//
// Fix: use GeomAPI_ExtremaCurveCurve (the same public class GeomFill_Gordon's own internal
// network preparation uses for this) to find each profile/guide pair's real contact point and
// each curve's own raw parameter there, then average across the family the way
// GeomFill_Gordon.cxx does (aGuideParamValues = columnMeans, aProfileParamValues = rowMeans) to
// get one locator value per profile and per guide, both already in the domain the corresponding
// skin needs. This does not replicate GeomFill_Gordon's full network preparation (curve
// reordering, non-linear reparametrization to a common basis, rational contact weights); that
// machinery is private to GeomFill_Gordon.cxx (GeomFill_GordonUtilities.pxx, not part of
// any installed header), and the class's own doc comment says a "GeomFill_NetworkSurface does
// not find curve intersections, sort the network, convert arbitrary curves, or reparametrize
// the input" by design. What is fixed is the one defect present on every input tried, including
// the fully consistent, non-degenerate ones: the wrong parameter DOMAIN. Verified against a 2x2
// bilinear patch (symmetric and asymmetric), a 3x3 curved grid, and the existing rational
// quarter-cylinder Gordon fixture (profiles are quarter-circle arcs): all four now report
// .done and reproduce their reference geometry to within 1e-14, the last one on real weight-1
// intersection points despite genuinely rational profile curves, because
// makeCorrectedProfileSkin's own rational branch combines the (correctly rational) profile and
// guide skins independently of what weight the intersection grid was given.
//
// GeomAPI_ExtremaCurveCurve SIGSEGVs on parallel curves at every capacity (#636, a kernel
// defect one layer under Extrema_ExtCC: NbExtrema() reports 1 but Points()/Parameters() index
// an empty sequence when IsParallel(), and this Release kernel disables the bounds check that
// would otherwise throw). PR #730 proposes the same IsParallel() guard for the OTHER call site
// of this class (Curve3D.extrema, OCCTBridge_Curve3D.mm), but it has not merged: as this tree
// stands, that call site has no guard at all and still SIGSEGVs on parallel curves. The
// IsParallel() check below is this function's own guard, protecting this new call site
// regardless of whether or when #730 lands.
//
// A pair with no real extremum (parallel, or the search otherwise found none) has no contact
// point to measure. The previous version of this fix substituted each curve's own
// FirstParameter() and averaged that invented point in with the real ones -- exactly the
// failure class #726 tracks: a value nobody measured, blended into a result reported .done
// with no error. Fixed by rejecting the whole network as .invalidInput instead (see below);
// the caller can already distinguish that from .done, the same as an undersized input.
// Also fixed in the same pass: Points(1, ...)/Parameters(1, ...) unconditionally read
// solution index 1, but GeomAPI_ExtremaCurveCurve exposes NearestPoints()/
// LowerDistanceParameters() precisely because index 1 is not guaranteed to be the globally
// nearest extremum -- on a curved profile/guide pair the wrong index can feed a real but
// spurious contact point into the surface build with no error signal. Uses the same pair of
// accessors already established for this class elsewhere in this file (OCCTSurfaceExtrema,
// above).
OCCTSurfaceRef OCCTGeomFillNetworkSurface(const OCCTCurve3DRef* profiles,
                                          int32_t               profileCount,
                                          const OCCTCurve3DRef* guides,
                                          int32_t               guideCount,
                                          double                tolerance,
                                          int32_t*              outStatus)
{
  if (outStatus)
    *outStatus = (int32_t)GeomFill_NetworkSurface::ResultStatus::NotStarted;
  if (!profiles || !guides || profileCount < 2 || guideCount < 2)
  {
    if (outStatus)
      *outStatus = (int32_t)GeomFill_NetworkSurface::ResultStatus::InvalidInput;
    return nullptr;
  }
  try
  {
    // Convert inputs to explicit non-periodic B-spline curves.
    NCollection_Array1<occ::handle<Geom_BSplineCurve>> profs(1, profileCount);
    for (int i = 0; i < profileCount; i++)
    {
      if (!profiles[i] || profiles[i]->curve.IsNull())
        return nullptr;
      Handle(Geom_BSplineCurve) bs = GeomConvert::CurveToBSplineCurve(profiles[i]->curve);
      if (bs.IsNull())
        return nullptr;
      if (bs->IsPeriodic())
        bs->SetNotPeriodic();
      profs.SetValue(i + 1, bs);
    }
    NCollection_Array1<occ::handle<Geom_BSplineCurve>> gds(1, guideCount);
    for (int i = 0; i < guideCount; i++)
    {
      if (!guides[i] || guides[i]->curve.IsNull())
        return nullptr;
      Handle(Geom_BSplineCurve) bs = GeomConvert::CurveToBSplineCurve(guides[i]->curve);
      if (bs.IsNull())
        return nullptr;
      if (bs->IsPeriodic())
        bs->SetNotPeriodic();
      gds.SetValue(i + 1, bs);
    }

    // Per-pair real contact point + each curve's own raw parameter there.
    // profParam(i,j): profile i's own parameter at its contact with guide j.
    // guideParam(i,j): guide j's own parameter at its contact with profile i.
    // Row is GUIDE, column is PROFILE, which is the opposite of the obvious reading and is
    // what GeomFill_NetworkSurface::Init's own isReadyToBuild() requires: rows must match
    // theGuideParameters and columns theProfileParameters, following BSplSLib::Interpolate's
    // UParameters/ColLength convention. NCollection_Array2 makes this easy to get backwards,
    // because ColLength() returns NbRows() and RowLength() returns NbColumns(), the reverse of
    // what both names suggest.
    //
    // Getting it backwards is silent on a square network: with an equal profile and guide count
    // the swapped grid is still the right SHAPE, so Init accepts it and the builder returns a
    // surface with its two off-diagonal corners exactly point-reflected, reporting .done. That
    // is how it shipped, and how a 2x2 regression fixture failed to catch it (#748). On any
    // non-square network the same bug is loud: a 2x3 fails Init outright with invalidInput.
    NCollection_Array2<gp_Pnt> ipts(1, guideCount, 1, profileCount);
    NCollection_Array2<double> iwts(1, guideCount, 1, profileCount);
    NCollection_Array2<double> profParam(1, profileCount, 1, guideCount);
    NCollection_Array2<double> guideParam(1, profileCount, 1, guideCount);
    for (int i = 0; i < profileCount; i++)
    {
      const Handle(Geom_BSplineCurve)& pc = profs.Value(i + 1);
      for (int j = 0; j < guideCount; j++)
      {
        const Handle(Geom_BSplineCurve)& gc = gds.Value(j + 1);
        GeomAPI_ExtremaCurveCurve        ex(pc, gc);
        // #636: NbExtrema() can report 1 on parallel curves with Points()/Parameters()
        // indexing nothing behind it, so IsParallel() has to gate the read, not IsDone()
        // or NbExtrema() alone. A pair with no real extremum has no contact point to
        // measure at all: reject the whole network rather than average in an invented
        // one (see the comment above this function).
        if (ex.IsParallel() || ex.NbExtrema() < 1)
        {
          if (outStatus)
            *outStatus = (int32_t)GeomFill_NetworkSurface::ResultStatus::InvalidInput;
          return nullptr;
        }
        // NearestPoints()/LowerDistanceParameters(), not Points(1, ...)/Parameters(1, ...):
        // index 1 is not guaranteed to be the globally nearest extremum.
        gp_Pnt pp, gp;
        ex.NearestPoints(pp, gp);
        double pparam, gparam;
        ex.LowerDistanceParameters(pparam, gparam);
        ipts.SetValue(j + 1, i + 1, pp);
        iwts.SetValue(j + 1, i + 1, 1.0);
        profParam.SetValue(i + 1, j + 1, pparam);
        guideParam.SetValue(i + 1, j + 1, gparam);
      }
    }

    // theProfileParameters[i] = mean over guides of guide j's own parameter at its contact
    // with profile i (locates profile i on the guide skin's domain).
    NCollection_Array1<double> profileParams(1, profileCount);
    for (int i = 0; i < profileCount; i++)
    {
      double sum = 0.0;
      for (int j = 0; j < guideCount; j++)
        sum += guideParam.Value(i + 1, j + 1);
      profileParams.SetValue(i + 1, sum / guideCount);
    }
    // theGuideParameters[j] = mean over profiles of profile i's own parameter at its
    // contact with guide j (locates guide j on the profile skin's domain).
    NCollection_Array1<double> guideParams(1, guideCount);
    for (int j = 0; j < guideCount; j++)
    {
      double sum = 0.0;
      for (int i = 0; i < profileCount; i++)
        sum += profParam.Value(i + 1, j + 1);
      guideParams.SetValue(j + 1, sum / profileCount);
    }

    GeomFill_NetworkSurface net;
    net.Init(profs, gds, profileParams, guideParams, ipts, iwts, tolerance, false, false);
    net.Perform();
    if (outStatus)
      *outStatus = (int32_t)net.Status();
    if (!net.IsDone())
      return nullptr;

    const Handle(Geom_BSplineSurface)& surf = net.Surface();
    if (surf.IsNull())
      return nullptr;
    auto ref     = new OCCTSurface();
    ref->surface = surf;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}
