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
    if (extrema.NbExtrema() == 0)
      return -1.0;
    return extrema.LowerDistance();
  }
  catch (...)
  {
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
    return nullptr;
  }
}

void OCCTGeomEvalEllipsoidD0(double  a,
                             double  b,
                             double  c,
                             double  u,
                             double  v,
                             double* px,
                             double* py,
                             double* pz)
{
  try
  {
    gp_Ax3                    ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    GeomEval_EllipsoidSurface ell(ax, a, b, c);
    gp_Pnt                    p = ell.EvalD0(u, v);
    *px                         = p.X();
    *py                         = p.Y();
    *pz                         = p.Z();
  }
  catch (...)
  {
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
    return nullptr;
  }
}

void OCCTGeomEvalHyperboloidD0(double  r1,
                               double  r2,
                               int32_t mode,
                               double  u,
                               double  v,
                               double* px,
                               double* py,
                               double* pz)
{
  try
  {
    gp_Ax3                      ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    auto                        sm = mode == 0 ? GeomEval_HyperboloidSurface::SheetMode::OneSheet
                                               : GeomEval_HyperboloidSurface::SheetMode::TwoSheets;
    GeomEval_HyperboloidSurface hyp(ax, r1, r2, sm);
    gp_Pnt                      p = hyp.EvalD0(u, v);
    *px                           = p.X();
    *py                           = p.Y();
    *pz                           = p.Z();
  }
  catch (...)
  {
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
    return nullptr;
  }
}

void OCCTGeomEvalParaboloidD0(double focal, double u, double v, double* px, double* py, double* pz)
{
  try
  {
    gp_Ax3                     ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    GeomEval_ParaboloidSurface par(ax, focal);
    gp_Pnt                     p = par.EvalD0(u, v);
    *px                          = p.X();
    *py                          = p.Y();
    *pz                          = p.Z();
  }
  catch (...)
  {
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
    return nullptr;
  }
}

void OCCTGeomEvalCircularHelicoidD0(double  pitch,
                                    double  u,
                                    double  v,
                                    double* px,
                                    double* py,
                                    double* pz)
{
  try
  {
    gp_Ax3                           ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    GeomEval_CircularHelicoidSurface hel(ax, pitch);
    gp_Pnt                           p = hel.EvalD0(u, v);
    *px                                = p.X();
    *py                                = p.Y();
    *pz                                = p.Z();
  }
  catch (...)
  {
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
    return nullptr;
  }
}

void OCCTGeomEvalHypParaboloidD0(double  a,
                                 double  b,
                                 double  u,
                                 double  v,
                                 double* px,
                                 double* py,
                                 double* pz)
{
  try
  {
    gp_Ax3                        ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    GeomEval_HypParaboloidSurface hp(ax, a, b);
    gp_Pnt                        p = hp.EvalD0(u, v);
    *px                             = p.X();
    *py                             = p.Y();
    *pz                             = p.Z();
  }
  catch (...)
  {
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
    return nullptr;
  }
}
