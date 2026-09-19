//
//  OCCTBridge_Surface_Adaptor.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Surface.mm (#1380): Adaptor3d_IsoCurve, BRepAdaptor, GeomAdaptor.
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
#include <BRepAdaptor_Surface.hxx> // #1502: OCCTGeomFillDarbouxTrihedron's real curve-on-surface
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

bool OCCTSurfaceGetBoundingBox(OCCTSurfaceRef s,
                               double*        xMin,
                               double*        yMin,
                               double*        zMin,
                               double*        xMax,
                               double*        yMax,
                               double*        zMax)
{
  if (!s || s->surface.IsNull() || !xMin || !yMin || !zMin || !xMax || !yMax || !zMax)
    return false;
  try
  {
    GeomAdaptor_Surface adaptor(s->surface);
    Bnd_Box             box;
    BndLib_AddSurface::Add(adaptor, 0.01, box);
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

OCCTTrihedronFrame OCCTGeomFillDraftTrihedron(OCCTShapeRef edgeShape,
                                              double       param,
                                              double       biNormalX,
                                              double       biNormalY,
                                              double       biNormalZ,
                                              double       angle)
{
  if (!occtShapeIsPresent(edgeShape))
    return makeEmptyFrame();
  try
  {
    TopoDS_Edge               edge    = TopoDS::Edge(edgeShape->shape);
    Handle(BRepAdaptor_Curve) adaptor = new BRepAdaptor_Curve(edge);
    GeomFill_DraftTrihedron   draft(gp_Vec(biNormalX, biNormalY, biNormalZ), angle);
    draft.SetCurve(adaptor);
    gp_Vec tangent, normal, binormal;
    if (!draft.D0(param, tangent, normal, binormal))
      return makeEmptyFrame();
    return {tangent.X(),
            tangent.Y(),
            tangent.Z(),
            normal.X(),
            normal.Y(),
            normal.Z(),
            binormal.X(),
            binormal.Y(),
            binormal.Z()};
  }
  catch (...)
  {
    return makeEmptyFrame();
  }
}

OCCTTrihedronFrame OCCTGeomFillDiscreteTrihedron(OCCTShapeRef edgeShape, double param)
{
  if (!occtShapeIsPresent(edgeShape))
    return makeEmptyFrame();
  try
  {
    TopoDS_Edge                edge    = TopoDS::Edge(edgeShape->shape);
    Handle(BRepAdaptor_Curve)  adaptor = new BRepAdaptor_Curve(edge);
    GeomFill_DiscreteTrihedron discrete;
    discrete.SetCurve(adaptor);
    gp_Vec tangent, normal, binormal;
    if (!discrete.D0(param, tangent, normal, binormal))
      return makeEmptyFrame();
    return {tangent.X(),
            tangent.Y(),
            tangent.Z(),
            normal.X(),
            normal.Y(),
            normal.Z(),
            binormal.X(),
            binormal.Y(),
            binormal.Z()};
  }
  catch (...)
  {
    return makeEmptyFrame();
  }
}

OCCTTrihedronFrame OCCTGeomFillCorrectedFrenet(OCCTShapeRef edgeShape, double param)
{
  if (!occtShapeIsPresent(edgeShape))
    return makeEmptyFrame();
  try
  {
    TopoDS_Edge               edge    = TopoDS::Edge(edgeShape->shape);
    Handle(BRepAdaptor_Curve) adaptor = new BRepAdaptor_Curve(edge);
    GeomFill_CorrectedFrenet  corrected;
    corrected.SetCurve(adaptor);
    gp_Vec tangent, normal, binormal;
    if (!corrected.D0(param, tangent, normal, binormal))
      return makeEmptyFrame();
    return {tangent.X(),
            tangent.Y(),
            tangent.Z(),
            normal.X(),
            normal.Y(),
            normal.Z(),
            binormal.X(),
            binormal.Y(),
            binormal.Z()};
  }
  catch (...)
  {
    return makeEmptyFrame();
  }
}

void OCCTAdaptor3dIsoCurveEval(OCCTShapeRef faceShape,
                               int          isoType,
                               double       param,
                               int          evalCount,
                               double*      outPoints)
{
  if (!occtShapeIsPresent(faceShape) || !outPoints || evalCount < 1)
    return;
  try
  {
    TopoDS_Face          face    = TopoDS::Face(faceShape->shape);
    Handle(Geom_Surface) surface = BRep_Tool::Surface(face);
    if (surface.IsNull())
      return;
    Handle(GeomAdaptor_Surface) surfAdaptor = new GeomAdaptor_Surface(surface);

    GeomAbs_IsoType    type = (isoType == 0) ? GeomAbs_IsoU : GeomAbs_IsoV;
    Adaptor3d_IsoCurve iso(surfAdaptor, type, param);

    double first = iso.FirstParameter();
    double last  = iso.LastParameter();
    // Clamp infinite parameters
    if (first < -1e6)
      first = -1e6;
    if (last > 1e6)
      last = 1e6;

    for (int i = 0; i < evalCount; i++)
    {
      double t = occtUniformParameter(first, last, i, evalCount);
      gp_Pnt pt;
      iso.D0(t, pt);
      outPoints[i * 3]     = pt.X();
      outPoints[i * 3 + 1] = pt.Y();
      outPoints[i * 3 + 2] = pt.Z();
    }
  }
  catch (...)
  {
  }
}

OCCTTrihedronFrame OCCTGeomFillDarbouxTrihedron(OCCTShapeRef edgeShape,
                                                OCCTShapeRef faceShape,
                                                double       param)
{
  OCCTTrihedronFrame frame = {};
  if (!occtShapeIsPresent(edgeShape) || !occtShapeIsPresent(faceShape))
    return frame;
  try
  {
    auto*       edgeWrapper = reinterpret_cast<OCCTShape*>(edgeShape);
    auto*       faceWrapper = reinterpret_cast<OCCTShape*>(faceShape);
    TopoDS_Edge edge        = TopoDS::Edge(edgeWrapper->shape);
    TopoDS_Face face        = TopoDS::Face(faceWrapper->shape);

    // #1502: GeomFill_Darboux::D0/D1/D2 unconditionally static_cast<>s the handle
    // SetCurve() was given to Adaptor3d_CurveOnSurface* and reads its private
    // myCurve/mySurface fields; a plain BRepAdaptor_Curve (an unrelated
    // Adaptor3d_Curve sibling) has neither at those offsets, an uncatchable bus
    // error. Build a real curve-on-surface from the edge's pcurve on `face`
    // instead, the same construction OCCTValidateEdge (OCCTBridge_Healing_Misc.mm)
    // and OCCT's own BRepFill_EdgeOnSurfLaw use to drive a Darboux trihedron along
    // an edge lying on a face.
    double               first, last;
    Handle(Geom2d_Curve) pcurve = BRep_Tool::CurveOnSurface(edge, face, first, last);
    if (pcurve.IsNull())
      return frame;

    Handle(BRepAdaptor_Surface)      brepSurf  = new BRepAdaptor_Surface(face);
    Handle(Geom2dAdaptor_Curve)      adapCurve = new Geom2dAdaptor_Curve(pcurve, first, last);
    Handle(Adaptor3d_CurveOnSurface) cos       = new Adaptor3d_CurveOnSurface(adapCurve, brepSurf);

    Handle(GeomFill_Darboux) darboux = new GeomFill_Darboux();
    darboux->SetCurve(cos);

    gp_Vec t, n, b;
    if (darboux->D0(param, t, n, b))
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

OCCTTrihedronFrame OCCTGeomFillFrenetTrihedron(OCCTShapeRef edgeShape, double param)
{
  OCCTTrihedronFrame frame = {};
  if (!occtShapeIsPresent(edgeShape))
    return frame;
  try
  {
    auto*                     wrapper = reinterpret_cast<OCCTShape*>(edgeShape);
    TopoDS_Edge               edge    = TopoDS::Edge(wrapper->shape);
    Handle(BRepAdaptor_Curve) adaptor = new BRepAdaptor_Curve(edge);

    Handle(GeomFill_Frenet) frenet = new GeomFill_Frenet();
    frenet->SetCurve(adaptor);

    gp_Vec t, n, b;
    if (frenet->D0(param, t, n, b))
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

OCCTTrihedronFrame OCCTGeomFillConstantBiNormalTrihedron(OCCTShapeRef edgeShape,
                                                         double       param,
                                                         double       biNormalX,
                                                         double       biNormalY,
                                                         double       biNormalZ)
{
  OCCTTrihedronFrame frame = {};
  if (!occtShapeIsPresent(edgeShape))
    return frame;
  try
  {
    auto*                     wrapper = reinterpret_cast<OCCTShape*>(edgeShape);
    TopoDS_Edge               edge    = TopoDS::Edge(wrapper->shape);
    Handle(BRepAdaptor_Curve) adaptor = new BRepAdaptor_Curve(edge);

    Handle(GeomFill_ConstantBiNormal) cbn =
      new GeomFill_ConstantBiNormal(gp_Dir(biNormalX, biNormalY, biNormalZ));
    cbn->SetCurve(adaptor);

    gp_Vec t, n, b;
    if (cbn->D0(param, t, n, b))
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

bool OCCTGeomFillBoundWithSurfEvaluate(OCCTSurfaceRef surface,
                                       OCCTCurve2DRef curve2d,
                                       double         first,
                                       double         last,
                                       double         param,
                                       double*        outX,
                                       double*        outY,
                                       double*        outZ,
                                       double*        outNX,
                                       double*        outNY,
                                       double*        outNZ)
{
  try
  {
    auto* sw = (OCCTSurface*)surface;
    auto* cw = (OCCTCurve2D*)curve2d;
    if (!sw || sw->surface.IsNull() || !cw || cw->curve.IsNull())
      return false;

    Handle(GeomAdaptor_Surface) adapSurf  = new GeomAdaptor_Surface(sw->surface);
    Handle(Geom2dAdaptor_Curve) adapCurve = new Geom2dAdaptor_Curve(cw->curve, first, last);

    Adaptor3d_CurveOnSurface       cos(adapCurve, adapSurf);
    Handle(GeomFill_BoundWithSurf) bws = new GeomFill_BoundWithSurf(cos, 1e-3, 1e-3);

    gp_Pnt val = bws->Value(param);
    *outX      = val.X();
    *outY      = val.Y();
    *outZ      = val.Z();

    if (bws->HasNormals())
    {
      gp_Vec norm = bws->Norm(param);
      *outNX      = norm.X();
      *outNY      = norm.Y();
      *outNZ      = norm.Z();
    }
    else
    {
      *outNX = *outNY = *outNZ = 0;
    }
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTGeomFillLocationDraftSetCurve(OCCTLocationDraftRef _Nonnull ref,
                                       OCCTCurve3DRef _Nonnull curveRef)
{
  try
  {
    auto*                     opaque  = (LocationDraftOpaque*)ref;
    const Handle(Geom_Curve)& curve   = *(const Handle(Geom_Curve)*)curveRef;
    Handle(GeomAdaptor_Curve) adaptor = new GeomAdaptor_Curve(curve);
    return opaque->loc->SetCurve(adaptor);
  }
  catch (...)
  {
    return false;
  }
}

OCCTGuideTrihedronACRef OCCTGeomFillGuideTrihedronACCreate(OCCTCurve3DRef _Nonnull guideCurveRef)
{
  try
  {
    const Handle(Geom_Curve)& curve   = *(const Handle(Geom_Curve)*)guideCurveRef;
    Handle(GeomAdaptor_Curve) adaptor = new GeomAdaptor_Curve(curve);
    auto*                     opaque  = new GuideTrihedronACOpaque();
    opaque->tri                       = new GeomFill_GuideTrihedronAC(adaptor);
    return opaque;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTGeomFillGuideTrihedronACSetCurve(OCCTGuideTrihedronACRef _Nonnull ref,
                                          OCCTCurve3DRef _Nonnull pathCurveRef)
{
  try
  {
    auto*                     opaque  = (GuideTrihedronACOpaque*)ref;
    const Handle(Geom_Curve)& curve   = *(const Handle(Geom_Curve)*)pathCurveRef;
    Handle(GeomAdaptor_Curve) adaptor = new GeomAdaptor_Curve(curve);
    return opaque->tri->SetCurve(adaptor);
  }
  catch (...)
  {
    return false;
  }
}

OCCTGuideTrihedronPlanRef OCCTGeomFillGuideTrihedronPlanCreate(
  OCCTCurve3DRef _Nonnull guideCurveRef)
{
  try
  {
    const Handle(Geom_Curve)& curve   = *(const Handle(Geom_Curve)*)guideCurveRef;
    Handle(GeomAdaptor_Curve) adaptor = new GeomAdaptor_Curve(curve);
    auto*                     opaque  = new GuideTrihedronPlanOpaque();
    opaque->tri                       = new GeomFill_GuideTrihedronPlan(adaptor);
    return opaque;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTGeomFillGuideTrihedronPlanSetCurve(OCCTGuideTrihedronPlanRef _Nonnull ref,
                                            OCCTCurve3DRef _Nonnull pathCurveRef)
{
  try
  {
    auto*                     opaque  = (GuideTrihedronPlanOpaque*)ref;
    const Handle(Geom_Curve)& curve   = *(const Handle(Geom_Curve)*)pathCurveRef;
    Handle(GeomAdaptor_Curve) adaptor = new GeomAdaptor_Curve(curve);
    return opaque->tri->SetCurve(adaptor);
  }
  catch (...)
  {
    return false;
  }
}

OCCTExtremaExtPSResult OCCTExtremaExtPS(double px, double py, double pz, OCCTSurfaceRef surface)
{
  OCCTExtremaExtPSResult result = {false, 0};
  try
  {
    auto*                       s  = (OCCTSurface*)surface;
    Handle(GeomAdaptor_Surface) as = new GeomAdaptor_Surface(s->surface);
    Extrema_ExtPS               ext(gp_Pnt(px, py, pz), *as, 1e-6, 1e-6);
    result.isDone = ext.IsDone();
    if (result.isDone)
      result.nbExt = ext.NbExt();
  }
  catch (...)
  {
  }
  return result;
}

OCCTExtremaPointOnSurf OCCTExtremaExtPSPoint(double         px,
                                             double         py,
                                             double         pz,
                                             OCCTSurfaceRef surface,
                                             int            index)
{
  OCCTExtremaPointOnSurf result = {};
  try
  {
    auto*                       s  = (OCCTSurface*)surface;
    Handle(GeomAdaptor_Surface) as = new GeomAdaptor_Surface(s->surface);
    Extrema_ExtPS               ext(gp_Pnt(px, py, pz), *as, 1e-6, 1e-6);
    if (ext.IsDone() && index >= 1 && index <= ext.NbExt())
    {
      result.squareDistance     = ext.SquareDistance(index);
      const Extrema_POnSurf& ps = ext.Point(index);
      result.x                  = ps.Value().X();
      result.y                  = ps.Value().Y();
      result.z                  = ps.Value().Z();
      ps.Parameter(result.u, result.v);
    }
  }
  catch (...)
  {
  }
  return result;
}

OCCTExtremaExtSSResult OCCTExtremaExtSS(OCCTSurfaceRef surface1, OCCTSurfaceRef surface2)
{
  OCCTExtremaExtSSResult result = {false, false, 0};
  try
  {
    auto*                       s1  = (OCCTSurface*)surface1;
    auto*                       s2  = (OCCTSurface*)surface2;
    Handle(GeomAdaptor_Surface) as1 = new GeomAdaptor_Surface(s1->surface);
    Handle(GeomAdaptor_Surface) as2 = new GeomAdaptor_Surface(s2->surface);
    Extrema_ExtSS               ext(*as1, *as2, 1e-6, 1e-6);
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

OCCTExtremaSSPointPair OCCTExtremaExtSSPoint(OCCTSurfaceRef surface1,
                                             OCCTSurfaceRef surface2,
                                             int            index)
{
  OCCTExtremaSSPointPair result = {};
  try
  {
    auto*                       s1  = (OCCTSurface*)surface1;
    auto*                       s2  = (OCCTSurface*)surface2;
    Handle(GeomAdaptor_Surface) as1 = new GeomAdaptor_Surface(s1->surface);
    Handle(GeomAdaptor_Surface) as2 = new GeomAdaptor_Surface(s2->surface);
    Extrema_ExtSS               ext(*as1, *as2, 1e-6, 1e-6);
    if (ext.IsDone() && !ext.IsParallel() && index >= 1 && index <= ext.NbExt())
    {
      result.squareDistance = ext.SquareDistance(index);
      Extrema_POnSurf p1, p2;
      ext.Points(index, p1, p2);
      result.x1 = p1.Value().X();
      result.y1 = p1.Value().Y();
      result.z1 = p1.Value().Z();
      p1.Parameter(result.u1, result.v1);
      result.x2 = p2.Value().X();
      result.y2 = p2.Value().Y();
      result.z2 = p2.Value().Z();
      p2.Parameter(result.u2, result.v2);
    }
  }
  catch (...)
  {
  }
  return result;
}

int32_t OCCTSurfaceGetType(OCCTSurfaceRef surface)
{
  if (!surface || surface->surface.IsNull())
    return 10; // OtherSurface
  try
  {
    GeomAdaptor_Surface as(surface->surface);
    return (int32_t)as.GetType();
  }
  catch (...)
  {
    return 10;
  }
}
