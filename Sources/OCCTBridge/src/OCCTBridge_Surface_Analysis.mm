//
//  OCCTBridge_Surface_Analysis.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Surface.mm (#1380): ShapeAnalysis_Surface,
//  LocalAnalysis_SurfaceContinuity, GeomLib, GeomConvert_SurfToAnaSurf. Public C surface unchanged;
//  every sibling file imports the same headers this one does (the shared preamble below). No symbol
//  changes, pure file move -- see Scripts/repro/396-bridge-mm-split/ for how.
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

OCCTCanonicalForm OCCTShapeRecognizeCanonical(OCCTShapeRef shape, double tolerance)
{
  OCCTCanonicalForm result = {};
  if (!shape)
    return result;
  try
  {
    ShapeAnalysis_CanonicalRecognition recog(shape->shape);
    gp_Pln                             pln;
    if (recog.IsPlane(tolerance, pln))
    {
      result.type         = 1;
      result.origin[0]    = pln.Location().X();
      result.origin[1]    = pln.Location().Y();
      result.origin[2]    = pln.Location().Z();
      result.direction[0] = pln.Axis().Direction().X();
      result.direction[1] = pln.Axis().Direction().Y();
      result.direction[2] = pln.Axis().Direction().Z();
      result.gap          = recog.GetGap();
      return result;
    }
    gp_Cylinder cyl;
    if (recog.IsCylinder(tolerance, cyl))
    {
      result.type         = 2;
      result.origin[0]    = cyl.Location().X();
      result.origin[1]    = cyl.Location().Y();
      result.origin[2]    = cyl.Location().Z();
      result.direction[0] = cyl.Axis().Direction().X();
      result.direction[1] = cyl.Axis().Direction().Y();
      result.direction[2] = cyl.Axis().Direction().Z();
      result.radius       = cyl.Radius();
      result.gap          = recog.GetGap();
      return result;
    }
    gp_Cone cone;
    if (recog.IsCone(tolerance, cone))
    {
      result.type         = 3;
      result.origin[0]    = cone.Location().X();
      result.origin[1]    = cone.Location().Y();
      result.origin[2]    = cone.Location().Z();
      result.direction[0] = cone.Axis().Direction().X();
      result.direction[1] = cone.Axis().Direction().Y();
      result.direction[2] = cone.Axis().Direction().Z();
      result.radius       = cone.RefRadius();
      result.radius2      = cone.SemiAngle();
      result.gap          = recog.GetGap();
      return result;
    }
    gp_Sphere sph;
    if (recog.IsSphere(tolerance, sph))
    {
      result.type         = 4;
      result.origin[0]    = sph.Location().X();
      result.origin[1]    = sph.Location().Y();
      result.origin[2]    = sph.Location().Z();
      result.direction[0] = sph.Position().Direction().X();
      result.direction[1] = sph.Position().Direction().Y();
      result.direction[2] = sph.Position().Direction().Z();
      result.radius       = sph.Radius();
      result.gap          = recog.GetGap();
      return result;
    }
    gp_Lin lin;
    if (recog.IsLine(tolerance, lin))
    {
      result.type         = 5;
      result.origin[0]    = lin.Location().X();
      result.origin[1]    = lin.Location().Y();
      result.origin[2]    = lin.Location().Z();
      result.direction[0] = lin.Direction().X();
      result.direction[1] = lin.Direction().Y();
      result.direction[2] = lin.Direction().Z();
      result.gap          = recog.GetGap();
      return result;
    }
    gp_Circ circ;
    if (recog.IsCircle(tolerance, circ))
    {
      result.type         = 6;
      result.origin[0]    = circ.Location().X();
      result.origin[1]    = circ.Location().Y();
      result.origin[2]    = circ.Location().Z();
      result.direction[0] = circ.Axis().Direction().X();
      result.direction[1] = circ.Axis().Direction().Y();
      result.direction[2] = circ.Axis().Direction().Z();
      result.radius       = circ.Radius();
      result.gap          = recog.GetGap();
      return result;
    }
    gp_Elips elips;
    if (recog.IsEllipse(tolerance, elips))
    {
      result.type         = 7;
      result.origin[0]    = elips.Location().X();
      result.origin[1]    = elips.Location().Y();
      result.origin[2]    = elips.Location().Z();
      result.direction[0] = elips.Axis().Direction().X();
      result.direction[1] = elips.Axis().Direction().Y();
      result.direction[2] = elips.Axis().Direction().Z();
      result.radius       = elips.MajorRadius();
      result.radius2      = elips.MinorRadius();
      result.gap          = recog.GetGap();
      return result;
    }
    return result;
  }
  catch (...)
  {
    return result;
  }
}

int32_t OCCTSurfaceToBezierPatches(OCCTSurfaceRef  surface,
                                   OCCTSurfaceRef* outPatches,
                                   int32_t         maxPatches)
{
  if (!surface || !outPatches || maxPatches < 1)
    return 0;
  if (surface->surface.IsNull())
    return 0;
  try
  {
    // First convert to BSpline if needed
    Handle(Geom_BSplineSurface) bspline = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bspline.IsNull())
    {
      // Try approximate conversion
      Handle(Geom_Surface) surf = surface->surface;
      // Use ShapeConstruct to convert
      bspline = GeomConvert::SurfaceToBSplineSurface(surf);
      if (bspline.IsNull())
        return 0;
    }
    GeomConvert_BSplineSurfaceToBezierSurface converter(bspline);
    int32_t                                   nbU   = converter.NbUPatches();
    int32_t                                   nbV   = converter.NbVPatches();
    int32_t                                   total = nbU * nbV;
    int32_t                                   count = std::min(total, maxPatches);
    int32_t                                   idx   = 0;
    for (int32_t i = 1; i <= nbU && idx < count; ++i)
    {
      for (int32_t j = 1; j <= nbV && idx < count; ++j)
      {
        Handle(Geom_BezierSurface) patch = converter.Patch(i, j);
        if (!patch.IsNull())
        {
          outPatches[idx] = new OCCTSurface(patch);
          idx++;
        }
        else
        {
          outPatches[idx] = nullptr;
          idx++;
        }
      }
    }
    return idx;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTSurfaceSingularityCount(OCCTSurfaceRef surface, double tolerance)
{
  if (!surface || surface->surface.IsNull())
    return 0;
  try
  {
    ShapeAnalysis_Surface analyzer(surface->surface);
    return analyzer.NbSingularities(tolerance);
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTSurfaceIsDegenerated(OCCTSurfaceRef surface,
                              double         x,
                              double         y,
                              double         z,
                              double         tolerance)
{
  if (!surface || surface->surface.IsNull())
    return false;
  try
  {
    ShapeAnalysis_Surface analyzer(surface->surface);
    gp_Pnt                point(x, y, z);
    return analyzer.IsDegenerated(point, tolerance);
  }
  catch (...)
  {
    return false;
  }
}

OCCTSurfaceUVResult OCCTSurfaceValueOfUV(OCCTSurfaceRef surface,
                                         double         px,
                                         double         py,
                                         double         pz,
                                         double         precision)
{
  OCCTSurfaceUVResult result = {};
  if (!surface || surface->surface.IsNull())
    return result;
  try
  {
    Handle(ShapeAnalysis_Surface) sa = new ShapeAnalysis_Surface(surface->surface);
    gp_Pnt2d                      uv = sa->ValueOfUV(gp_Pnt(px, py, pz), precision);
    result.u                         = uv.X();
    result.v                         = uv.Y();
    result.gap                       = sa->Gap();
    return result;
  }
  catch (...)
  {
    return result;
  }
}

OCCTSurfaceUVResult OCCTSurfaceNextValueOfUV(OCCTSurfaceRef surface,
                                             double         prevU,
                                             double         prevV,
                                             double         px,
                                             double         py,
                                             double         pz,
                                             double         precision)
{
  OCCTSurfaceUVResult result = {};
  if (!surface || surface->surface.IsNull())
    return result;
  try
  {
    Handle(ShapeAnalysis_Surface) sa = new ShapeAnalysis_Surface(surface->surface);
    gp_Pnt2d uv = sa->NextValueOfUV(gp_Pnt2d(prevU, prevV), gp_Pnt(px, py, pz), precision);
    result.u    = uv.X();
    result.v    = uv.Y();
    result.gap  = sa->Gap();
    return result;
  }
  catch (...)
  {
    return result;
  }
}

// MARK: - Surface KnotSplitting / JoinBezierPatches (v0.50)
// #403: also fills the U/V split PARAMETER buffers (not just the counts) -- the
// underlying GeomConvert_BSplineSurfaceKnotSplitting analyzer always computed
// USplitValue/VSplitValue, this just wasn't surfaced. #562: and fills the raw knot-table
// indices those parameters came from, which is what a second, now-deleted family of bridge
// functions existed to return. Any out buffer may be null (or its max 0) to skip it; one
// analyzer construction serves all four, where that family needed three.
OCCTSurfaceKnotSplitResult OCCTSurfaceKnotSplitting(OCCTSurfaceRef surface,
                                                    int32_t        uContinuity,
                                                    int32_t        vContinuity,
                                                    double*        outUParams,
                                                    int32_t*       outUIndices,
                                                    int32_t        maxU,
                                                    double*        outVParams,
                                                    int32_t*       outVIndices,
                                                    int32_t        maxV)
{
  OCCTSurfaceKnotSplitResult result = {};
  if (!surface)
    return result;
  try
  {
    Handle(Geom_BSplineSurface) bsurf = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bsurf.IsNull())
      return result;
    GeomConvert_BSplineSurfaceKnotSplitting splitter(bsurf, uContinuity, vContinuity);
    result.nbUSplits = splitter.NbUSplits();
    result.nbVSplits = splitter.NbVSplits();
    if (outUParams && maxU > 0)
    {
      occtWriteKnotSplitParams(
        result.nbUSplits,
        [&](int32_t i) { return splitter.USplitValue(i); },
        [&](int32_t idx) { return bsurf->UKnot(idx); },
        outUParams,
        maxU);
    }
    if (outUIndices && maxU > 0)
    {
      occtWriteKnotSplits<int32_t>(
        result.nbUSplits,
        [&](int32_t i) { return (int32_t)splitter.USplitValue(i); },
        outUIndices,
        maxU);
    }
    if (outVParams && maxV > 0)
    {
      occtWriteKnotSplitParams(
        result.nbVSplits,
        [&](int32_t i) { return splitter.VSplitValue(i); },
        [&](int32_t idx) { return bsurf->VKnot(idx); },
        outVParams,
        maxV);
    }
    if (outVIndices && maxV > 0)
    {
      occtWriteKnotSplits<int32_t>(
        result.nbVSplits,
        [&](int32_t i) { return (int32_t)splitter.VSplitValue(i); },
        outVIndices,
        maxV);
    }
  }
  catch (...)
  {
  }
  return result;
}

OCCTSurfaceRef OCCTSurfaceJoinBezierPatches(const OCCTSurfaceRef* patches,
                                            int32_t               nRows,
                                            int32_t               nCols)
{
  if (!patches || nRows <= 0 || nCols <= 0)
    return nullptr;
  try
  {
    TColGeom_Array2OfBezierSurface bezArray(1, nRows, 1, nCols);
    for (int32_t r = 0; r < nRows; r++)
    {
      for (int32_t c = 0; c < nCols; c++)
      {
        auto* sref = patches[r * nCols + c];
        if (!sref)
          return nullptr;
        Handle(Geom_BezierSurface) bez = Handle(Geom_BezierSurface)::DownCast(sref->surface);
        if (bez.IsNull())
          return nullptr;
        bezArray.SetValue(r + 1, c + 1, bez);
      }
    }
    if (occtAnyBezierPatchIsRational(bezArray))
      return nullptr;
    GeomConvert_CompBezierSurfacesToBSplineSurface conv(bezArray);
    if (!conv.IsDone())
      return nullptr;
    Handle(Geom_BSplineSurface) bsurf = new Geom_BSplineSurface(conv.Poles()->Array2(),
                                                                conv.UKnots()->Array1(),
                                                                conv.VKnots()->Array1(),
                                                                conv.UMultiplicities()->Array1(),
                                                                conv.VMultiplicities()->Array1(),
                                                                conv.UDegree(),
                                                                conv.VDegree());
    if (bsurf.IsNull())
      return nullptr;
    auto* ref    = new OCCTSurface();
    ref->surface = bsurf;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTLocalAnalysisSurfaceContinuity(OCCTSurfaceRef _Nonnull surface1,
                                        double u1,
                                        double v1,
                                        OCCTSurfaceRef _Nonnull surface2,
                                        double  u2,
                                        double  v2,
                                        int32_t order,
                                        int32_t* _Nonnull outEffectiveOrder,
                                        double* _Nonnull outC0Value,
                                        double* _Nonnull outG1Angle,
                                        double* _Nonnull outC1UAngle,
                                        double* _Nonnull outC1VAngle)
{
  try
  {
    auto s1 = (OCCTSurface*)surface1;
    auto s2 = (OCCTSurface*)surface2;
    if (!s1 || s1->surface.IsNull() || !s2 || s2->surface.IsNull())
      return false;

    const GeomAbs_Shape effective = occtGeomAbsFromAnalysisOrder(order);
    const int32_t       measured  = occtAnalysisMeasuredMask(effective);

    LocalAnalysis_SurfaceContinuity sc(s1->surface, u1, v1, s2->surface, u2, v2, effective);
    if (!sc.IsDone())
      return false;

    // The request echoed back, same as the curve analyser, see the note there.
    *outEffectiveOrder = occtAnalysisOrderFromGeomAbs(sc.ContinuityStatus());
    *outC0Value        = sc.C0Value();
    *outG1Angle        = ((measured & 0x02) && sc.IsG1()) ? sc.G1Angle() : -1.0;
    *outC1UAngle       = ((measured & 0x04) && sc.IsC1()) ? sc.C1UAngle() : -1.0;
    *outC1VAngle       = ((measured & 0x04) && sc.IsC1()) ? sc.C1VAngle() : -1.0;
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTLocalAnalysisSurfaceContinuityFlags(OCCTSurfaceRef _Nonnull surface1,
                                                double u1,
                                                double v1,
                                                OCCTSurfaceRef _Nonnull surface2,
                                                double  u2,
                                                double  v2,
                                                int32_t order,
                                                int32_t* _Nonnull outMeasured)
{
  *outMeasured = 0;
  try
  {
    auto s1 = (OCCTSurface*)surface1;
    auto s2 = (OCCTSurface*)surface2;
    if (!s1 || s1->surface.IsNull() || !s2 || s2->surface.IsNull())
      return 0;

    const GeomAbs_Shape effective = occtGeomAbsFromAnalysisOrder(order);
    const int32_t       measured  = occtAnalysisMeasuredMask(effective);

    LocalAnalysis_SurfaceContinuity sc(s1->surface, u1, v1, s2->surface, u2, v2, effective);
    if (!sc.IsDone())
      return 0;

    int32_t flags = 0;
    if (sc.IsC0())
      flags |= 1;
    if (sc.IsG1())
      flags |= 2;
    if (sc.IsC1())
      flags |= 4;
    if (sc.IsG2())
      flags |= 8;
    if (sc.IsC2())
      flags |= 16;
    *outMeasured = measured;
    return flags & measured;
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - GeomLib_Tool Surface Param + IsPlanar (v0.77)
bool OCCTGeomLibToolParametersSurface(OCCTSurfaceRef _Nonnull surfRef,
                                      double px,
                                      double py,
                                      double pz,
                                      double maxDist,
                                      double* _Nonnull outU,
                                      double* _Nonnull outV)
{
  try
  {
    auto&  surf = reinterpret_cast<OCCTSurface*>(surfRef)->surface;
    double u = 0, v = 0;
    bool   ok = GeomLib_Tool::Parameters(surf, gp_Pnt(px, py, pz), maxDist, u, v);
    if (ok)
    {
      *outU = u;
      *outV = v;
    }
    return ok;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTGeomLibIsPlanarSurface(OCCTSurfaceRef _Nonnull surfRef, double tolerance)
{
  try
  {
    auto&                   surf = reinterpret_cast<OCCTSurface*>(surfRef)->surface;
    GeomLib_IsPlanarSurface checker(surf, tolerance);
    return checker.IsPlanar();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTGeomLibPlanarSurfacePlane(OCCTSurfaceRef _Nonnull surfRef,
                                   double tolerance,
                                   double* _Nonnull ox,
                                   double* _Nonnull oy,
                                   double* _Nonnull oz,
                                   double* _Nonnull nx,
                                   double* _Nonnull ny,
                                   double* _Nonnull nz,
                                   double* _Nonnull xx,
                                   double* _Nonnull xy,
                                   double* _Nonnull xz)
{
  try
  {
    auto&                   surf = reinterpret_cast<OCCTSurface*>(surfRef)->surface;
    GeomLib_IsPlanarSurface checker(surf, tolerance);
    if (!checker.IsPlanar())
      return false;
    const gp_Pln& pln  = checker.Plan();
    gp_Pnt        loc  = pln.Location();
    gp_Dir        dir  = pln.Axis().Direction();
    gp_Dir        xdir = pln.XAxis().Direction();
    *ox                = loc.X();
    *oy                = loc.Y();
    *oz                = loc.Z();
    *nx                = dir.X();
    *ny                = dir.Y();
    *nz                = dir.Z();
    *xx                = xdir.X();
    *xy                = xdir.Y();
    *xz                = xdir.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTGeomConvertIsCanonical(OCCTSurfaceRef _Nonnull surfaceRef)
{
  try
  {
    auto& surface = reinterpret_cast<OCCTSurface*>(surfaceRef)->surface;
    return GeomConvert_SurfToAnaSurf::IsCanonical(surface);
  }
  catch (...)
  {
    return false;
  }
}

double OCCTSurfaceProjectPointUV(OCCTSurfaceRef surface,
                                 double         px,
                                 double         py,
                                 double         pz,
                                 double         preci,
                                 double*        u,
                                 double*        v)
{
  if (!surface || surface->surface.IsNull())
  {
    *u = 0;
    *v = 0;
    return -1.0;
  }
  try
  {
    Handle(ShapeAnalysis_Surface) sas = new ShapeAnalysis_Surface(surface->surface);
    gp_Pnt2d                      uv  = sas->ValueOfUV(gp_Pnt(px, py, pz), preci);
    *u                                = uv.X();
    *v                                = uv.Y();
    return sas->Gap();
  }
  catch (...)
  {
    *u = 0;
    *v = 0;
    return -1.0;
  }
}

bool OCCTSurfaceHasSingularities(OCCTSurfaceRef surface, double preci)
{
  if (!surface || surface->surface.IsNull())
    return false;
  try
  {
    Handle(ShapeAnalysis_Surface) sas = new ShapeAnalysis_Surface(surface->surface);
    return sas->HasSingularities(preci);
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTSurfaceNbSingularities(OCCTSurfaceRef surface, double preci)
{
  if (!surface || surface->surface.IsNull())
    return 0;
  try
  {
    Handle(ShapeAnalysis_Surface) sas = new ShapeAnalysis_Surface(surface->surface);
    return sas->NbSingularities(preci);
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTSurfaceIsUClosedSA(OCCTSurfaceRef surface, double preci)
{
  if (!surface || surface->surface.IsNull())
    return false;
  try
  {
    Handle(ShapeAnalysis_Surface) sas = new ShapeAnalysis_Surface(surface->surface);
    return sas->IsUClosed(preci);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceIsVClosedSA(OCCTSurfaceRef surface, double preci)
{
  if (!surface || surface->surface.IsNull())
    return false;
  try
  {
    Handle(ShapeAnalysis_Surface) sas = new ShapeAnalysis_Surface(surface->surface);
    return sas->IsVClosed(preci);
  }
  catch (...)
  {
    return false;
  }
}

/// UVFromIso: refine a (U,V) for P3D by projecting onto the surface's iso-lines; returns the best
/// 3D gap (very large on failure).
double OCCTSurfaceUVFromIso(OCCTSurfaceRef surface,
                            double         px,
                            double         py,
                            double         pz,
                            double         preci,
                            double*        u,
                            double*        v)
{
  if (!surface || surface->surface.IsNull())
  {
    if (u)
      *u = 0;
    if (v)
      *v = 0;
    return -1.0;
  }
  try
  {
    Handle(ShapeAnalysis_Surface) sas = new ShapeAnalysis_Surface(surface->surface);
    double                        U = 0, V = 0;
    double                        d = sas->UVFromIso(gp_Pnt(px, py, pz), preci, U, V);
    if (u)
      *u = U;
    if (v)
      *v = V;
    return d;
  }
  catch (...)
  {
    if (u)
      *u = 0;
    if (v)
      *v = 0;
    return -1.0;
  }
}

/// Detail of singularity #num (1-based): 3D pole point, first/last 2D points of the degenerate
/// iso-line, its first/last parameters, and whether it is a U-iso (else V-iso). `preci` is in/out.
bool OCCTSurfaceSingularityDetail(OCCTSurfaceRef surface,
                                  int32_t        num,
                                  double*        preci,
                                  double*        px,
                                  double*        py,
                                  double*        pz,
                                  double*        firstU,
                                  double*        firstV,
                                  double*        lastU,
                                  double*        lastV,
                                  double*        firstPar,
                                  double*        lastPar,
                                  bool*          uIsoDegenerate)
{
  if (!surface || surface->surface.IsNull())
    return false;
  try
  {
    Handle(ShapeAnalysis_Surface) sas = new ShapeAnalysis_Surface(surface->surface);
    gp_Pnt                        P3d;
    gp_Pnt2d                      f2, l2;
    double                        fp = 0, lp = 0;
    Standard_Boolean              uiso = Standard_False;
    double                        pr   = preci ? *preci : 0.0;
    if (!sas->Singularity(num, pr, P3d, f2, l2, fp, lp, uiso))
      return false;
    if (preci)
      *preci = pr;
    if (px)
      *px = P3d.X();
    if (py)
      *py = P3d.Y();
    if (pz)
      *pz = P3d.Z();
    if (firstU)
      *firstU = f2.X();
    if (firstV)
      *firstV = f2.Y();
    if (lastU)
      *lastU = l2.X();
    if (lastV)
      *lastV = l2.Y();
    if (firstPar)
      *firstPar = fp;
    if (lastPar)
      *lastPar = lp;
    if (uIsoDegenerate)
      *uIsoDegenerate = uiso;
    return true;
  }
  catch (...)
  {
    return false;
  }
}

/// ProjectDegenerated: adjust the indeterminate 2D coordinate of a point lying in a surface
/// singularity, taking the fixed coordinate from a `neighbour` 2D point. Returns the resolved
/// (ru,rv).
bool OCCTSurfaceProjectDegenerated(OCCTSurfaceRef surface,
                                   double         px,
                                   double         py,
                                   double         pz,
                                   double         preci,
                                   double         neighbourU,
                                   double         neighbourV,
                                   double*        ru,
                                   double*        rv)
{
  if (!surface || surface->surface.IsNull())
    return false;
  try
  {
    Handle(ShapeAnalysis_Surface) sas = new ShapeAnalysis_Surface(surface->surface);
    gp_Pnt2d                      result;
    if (!sas->ProjectDegenerated(gp_Pnt(px, py, pz),
                                 preci,
                                 gp_Pnt2d(neighbourU, neighbourV),
                                 result))
      return false;
    if (ru)
      *ru = result.X();
    if (rv)
      *rv = result.Y();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

/// Like OCCTSurfaceProjectPointUV but restricts the search to the [u1,u2]×[v1,v2] domain
/// (ShapeAnalysis_Surface:SetDomain), disambiguates projection on periodic / self-overlapping
/// surfaces. Returns the 3D gap (Gap()), or -1 on failure.
double OCCTSurfaceProjectPointUVInDomain(OCCTSurfaceRef surface,
                                         double         px,
                                         double         py,
                                         double         pz,
                                         double         preci,
                                         double         u1,
                                         double         u2,
                                         double         v1,
                                         double         v2,
                                         double*        u,
                                         double*        v)
{
  if (!surface || surface->surface.IsNull())
  {
    if (u)
      *u = 0;
    if (v)
      *v = 0;
    return -1.0;
  }
  try
  {
    Handle(ShapeAnalysis_Surface) sas = new ShapeAnalysis_Surface(surface->surface);
    sas->SetDomain(u1, u2, v1, v2);
    gp_Pnt2d uv = sas->ValueOfUV(gp_Pnt(px, py, pz), preci);
    if (u)
      *u = uv.X();
    if (v)
      *v = uv.Y();
    return sas->Gap();
  }
  catch (...)
  {
    if (u)
      *u = 0;
    if (v)
      *v = 0;
    return -1.0;
  }
}
