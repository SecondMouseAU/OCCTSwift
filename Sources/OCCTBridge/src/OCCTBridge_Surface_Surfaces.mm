//
//  OCCTBridge_Surface_Surfaces.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Surface.mm (#1380): Geom_* (RectangularTrimmedSurface, OffsetSurface,
//  Plane, Spherical, Toroidal, Cylindrical, Conical, SurfaceOfRevolution, Swept, BSpline, Bezier),
//  gce_Make, GC_Make*, ElSLib -- default_bucket. Public C surface unchanged; every sibling file
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

void OCCTSurfaceRelease(OCCTSurfaceRef s)
{
  delete s;
}

void OCCTSurfaceGetDomain(OCCTSurfaceRef s, double* uMin, double* uMax, double* vMin, double* vMax)
{
  if (!s || s->surface.IsNull() || !uMin || !uMax || !vMin || !vMax)
    return;
  s->surface->Bounds(*uMin, *uMax, *vMin, *vMax);
}

bool OCCTSurfaceIsUClosed(OCCTSurfaceRef s)
{
  if (!s || s->surface.IsNull())
    return false;
  return s->surface->IsUClosed() == Standard_True;
}

bool OCCTSurfaceIsVClosed(OCCTSurfaceRef s)
{
  if (!s || s->surface.IsNull())
    return false;
  return s->surface->IsVClosed() == Standard_True;
}

bool OCCTSurfaceIsUPeriodic(OCCTSurfaceRef s)
{
  if (!s || s->surface.IsNull())
    return false;
  return s->surface->IsUPeriodic() == Standard_True;
}

bool OCCTSurfaceIsVPeriodic(OCCTSurfaceRef s)
{
  if (!s || s->surface.IsNull())
    return false;
  return s->surface->IsVPeriodic() == Standard_True;
}

double OCCTSurfaceGetUPeriod(OCCTSurfaceRef s)
{
  if (!s || s->surface.IsNull() || !s->surface->IsUPeriodic())
    return 0.0;
  return s->surface->UPeriod();
}

double OCCTSurfaceGetVPeriod(OCCTSurfaceRef s)
{
  if (!s || s->surface.IsNull() || !s->surface->IsVPeriodic())
    return 0.0;
  return s->surface->VPeriod();
}

void OCCTSurfaceGetPoint(OCCTSurfaceRef s, double u, double v, double* x, double* y, double* z)
{
  if (!s || s->surface.IsNull() || !x || !y || !z)
    return;
  try
  {
    gp_Pnt p;
    s->surface->D0(u, v, p);
    *x = p.X();
    *y = p.Y();
    *z = p.Z();
  }
  catch (...)
  {
  }
}

void OCCTSurfaceD1(OCCTSurfaceRef s,
                   double         u,
                   double         v,
                   double*        px,
                   double*        py,
                   double*        pz,
                   double*        dux,
                   double*        duy,
                   double*        duz,
                   double*        dvx,
                   double*        dvy,
                   double*        dvz)
{
  if (!s || s->surface.IsNull() || !px || !py || !pz || !dux || !duy || !duz || !dvx || !dvy
      || !dvz)
    return;
  try
  {
    gp_Pnt p;
    gp_Vec du, dv;
    s->surface->D1(u, v, p, du, dv);
    *px  = p.X();
    *py  = p.Y();
    *pz  = p.Z();
    *dux = du.X();
    *duy = du.Y();
    *duz = du.Z();
    *dvx = dv.X();
    *dvy = dv.Y();
    *dvz = dv.Z();
  }
  catch (...)
  {
  }
}

void OCCTSurfaceD2(OCCTSurfaceRef s,
                   double         u,
                   double         v,
                   double*        px,
                   double*        py,
                   double*        pz,
                   double*        d1ux,
                   double*        d1uy,
                   double*        d1uz,
                   double*        d1vx,
                   double*        d1vy,
                   double*        d1vz,
                   double*        d2ux,
                   double*        d2uy,
                   double*        d2uz,
                   double*        d2vx,
                   double*        d2vy,
                   double*        d2vz,
                   double*        d2uvx,
                   double*        d2uvy,
                   double*        d2uvz)
{
  if (!s || s->surface.IsNull() || !px || !py || !pz || !d1ux || !d1uy || !d1uz || !d1vx || !d1vy
      || !d1vz || !d2ux || !d2uy || !d2uz || !d2vx || !d2vy || !d2vz || !d2uvx || !d2uvy || !d2uvz)
    return;
  try
  {
    gp_Pnt p;
    gp_Vec d1u, d1v, d2u, d2v, d2uv;
    s->surface->D2(u, v, p, d1u, d1v, d2u, d2v, d2uv);
    *px    = p.X();
    *py    = p.Y();
    *pz    = p.Z();
    *d1ux  = d1u.X();
    *d1uy  = d1u.Y();
    *d1uz  = d1u.Z();
    *d1vx  = d1v.X();
    *d1vy  = d1v.Y();
    *d1vz  = d1v.Z();
    *d2ux  = d2u.X();
    *d2uy  = d2u.Y();
    *d2uz  = d2u.Z();
    *d2vx  = d2v.X();
    *d2vy  = d2v.Y();
    *d2vz  = d2v.Z();
    *d2uvx = d2uv.X();
    *d2uvy = d2uv.Y();
    *d2uvz = d2uv.Z();
  }
  catch (...)
  {
  }
}

bool OCCTSurfaceGetNormal(OCCTSurfaceRef s, double u, double v, double* nx, double* ny, double* nz)
{
  if (!s || s->surface.IsNull() || !nx || !ny || !nz)
    return false;
  try
  {
    GeomLProp_SLProps props = occtSurfaceLocalProps(s->surface, u, v, 1);
    if (!props.IsNormalDefined())
      return false;
    gp_Dir n = props.Normal();
    *nx      = n.X();
    *ny      = n.Y();
    *nz      = n.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// Exactly OCCTSurfacePlaneFromPointNormal (GC_MakePlane), a second, independent point+normal
// plane constructor. Both throw/catch identically for a degenerate normal (ground-truthed for
// #421: GC_MakePlane's point+normal overload adds no check beyond gp_Dir's own construction-time
// validity), so forwarding is behaviour-preserving. Keeps the C ABI while leaving one
// implementation.
OCCTSurfaceRef OCCTSurfaceCreatePlane(double px,
                                      double py,
                                      double pz,
                                      double nx,
                                      double ny,
                                      double nz)
{
  return OCCTSurfacePlaneFromPointNormal(px, py, pz, nx, ny, nz);
}

OCCTSurfaceRef OCCTSurfaceCreateCylinder(double px,
                                         double py,
                                         double pz,
                                         double dx,
                                         double dy,
                                         double dz,
                                         double radius)
{
  try
  {
    if (radius <= 0)
      return nullptr;
    gp_Pnt                          origin(px, py, pz);
    gp_Dir                          dir(dx, dy, dz);
    gp_Ax3                          axis(origin, dir);
    Handle(Geom_CylindricalSurface) cyl = new Geom_CylindricalSurface(axis, radius);
    return new OCCTSurface(cyl);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceCreateCone(double px,
                                     double py,
                                     double pz,
                                     double dx,
                                     double dy,
                                     double dz,
                                     double radius,
                                     double semiAngle)
{
  try
  {
    if (radius < 0)
      return nullptr;
    gp_Pnt                      origin(px, py, pz);
    gp_Dir                      dir(dx, dy, dz);
    gp_Ax3                      axis(origin, dir);
    Handle(Geom_ConicalSurface) cone = new Geom_ConicalSurface(axis, semiAngle, radius);
    return new OCCTSurface(cone);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceCreateSphere(double cx, double cy, double cz, double radius)
{
  try
  {
    if (radius <= 0)
      return nullptr;
    gp_Pnt                        center(cx, cy, cz);
    gp_Ax3                        axis(center, gp::DZ());
    Handle(Geom_SphericalSurface) sphere = new Geom_SphericalSurface(axis, radius);
    return new OCCTSurface(sphere);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceCreateTorus(double px,
                                      double py,
                                      double pz,
                                      double dx,
                                      double dy,
                                      double dz,
                                      double majorRadius,
                                      double minorRadius)
{
  try
  {
    if (majorRadius <= 0 || minorRadius <= 0 || minorRadius >= majorRadius)
      return nullptr;
    gp_Pnt                       origin(px, py, pz);
    gp_Dir                       dir(dx, dy, dz);
    gp_Ax3                       axis(origin, dir);
    Handle(Geom_ToroidalSurface) torus = new Geom_ToroidalSurface(axis, majorRadius, minorRadius);
    return new OCCTSurface(torus);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceCreateExtrusion(OCCTCurve3DRef profile, double dx, double dy, double dz)
{
  if (!profile || profile->curve.IsNull())
    return nullptr;
  try
  {
    gp_Dir                                dir(dx, dy, dz);
    Handle(Geom_SurfaceOfLinearExtrusion) ext =
      new Geom_SurfaceOfLinearExtrusion(profile->curve, dir);
    return new OCCTSurface(ext);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceCreateRevolution(OCCTCurve3DRef meridian,
                                           double         px,
                                           double         py,
                                           double         pz,
                                           double         dx,
                                           double         dy,
                                           double         dz)
{
  if (!meridian || meridian->curve.IsNull())
    return nullptr;
  try
  {
    gp_Pnt                           origin(px, py, pz);
    gp_Dir                           dir(dx, dy, dz);
    gp_Ax1                           axis(origin, dir);
    Handle(Geom_SurfaceOfRevolution) rev = new Geom_SurfaceOfRevolution(meridian->curve, axis);
    return new OCCTSurface(rev);
  }
  catch (...)
  {
    return nullptr;
  }
}

// Unlike OCCTSurfaceDrawMesh's superficially identical `< 2` (which was this function's own
// divisor masquerading as a kernel rule, #620), the 2 here IS OCCT's constraint and must stay:
// Geom_BezierSurface's header states it raises "if the number of poles of the surface is lower
// than 2 ... in one of the two directions U or V", since a Bezier's degree is poles - 1 and must
// be >= 1. Measured: a 1 x N pole array throws Standard_ConstructionError, 2 x 2 builds a
// degree-1 x degree-1 surface. Surface.bezier(poles:weights:) already guards the same bound.
OCCTSurfaceRef OCCTSurfaceCreateBezier(const double* poles,
                                       int32_t       uCount,
                                       int32_t       vCount,
                                       const double* weights)
{
  if (!poles || uCount < 2 || vCount < 2)
    return nullptr;
  try
  {
    TColgp_Array2OfPnt poleArray(1, uCount, 1, vCount);
    for (int32_t i = 0; i < uCount; i++)
    {
      for (int32_t j = 0; j < vCount; j++)
      {
        int idx = (i * vCount + j) * 3;
        poleArray.SetValue(i + 1, j + 1, gp_Pnt(poles[idx], poles[idx + 1], poles[idx + 2]));
      }
    }
    Handle(Geom_BezierSurface) bez;
    if (weights)
    {
      TColStd_Array2OfReal wArr(1, uCount, 1, vCount);
      for (int32_t i = 0; i < uCount; i++)
      {
        for (int32_t j = 0; j < vCount; j++)
        {
          wArr.SetValue(i + 1, j + 1, weights[i * vCount + j]);
        }
      }
      bez = new Geom_BezierSurface(poleArray, wArr);
    }
    else
    {
      bez = new Geom_BezierSurface(poleArray);
    }
    return new OCCTSurface(bez);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceCreateBSpline(const double*  poles,
                                        int32_t        uPoleCount,
                                        int32_t        vPoleCount,
                                        const double*  weights,
                                        const double*  uKnots,
                                        int32_t        uKnotCount,
                                        const double*  vKnots,
                                        int32_t        vKnotCount,
                                        const int32_t* uMults,
                                        const int32_t* vMults,
                                        int32_t        uDegree,
                                        int32_t        vDegree)
{
  if (!poles || !uKnots || !vKnots || !uMults || !vMults)
    return nullptr;
  if (uPoleCount < 2 || vPoleCount < 2 || uKnotCount < 2 || vKnotCount < 2)
    return nullptr;
  try
  {
    TColgp_Array2OfPnt poleArray(1, uPoleCount, 1, vPoleCount);
    for (int32_t i = 0; i < uPoleCount; i++)
    {
      for (int32_t j = 0; j < vPoleCount; j++)
      {
        int idx = (i * vPoleCount + j) * 3;
        poleArray.SetValue(i + 1, j + 1, gp_Pnt(poles[idx], poles[idx + 1], poles[idx + 2]));
      }
    }

    TColStd_Array1OfReal uKnotArr(1, uKnotCount);
    for (int32_t i = 0; i < uKnotCount; i++)
      uKnotArr.SetValue(i + 1, uKnots[i]);
    TColStd_Array1OfReal vKnotArr(1, vKnotCount);
    for (int32_t i = 0; i < vKnotCount; i++)
      vKnotArr.SetValue(i + 1, vKnots[i]);

    TColStd_Array1OfInteger uMultArr(1, uKnotCount);
    for (int32_t i = 0; i < uKnotCount; i++)
      uMultArr.SetValue(i + 1, uMults[i]);
    TColStd_Array1OfInteger vMultArr(1, vKnotCount);
    for (int32_t i = 0; i < vKnotCount; i++)
      vMultArr.SetValue(i + 1, vMults[i]);

    Handle(Geom_BSplineSurface) bsp;
    if (weights)
    {
      TColStd_Array2OfReal wArr(1, uPoleCount, 1, vPoleCount);
      for (int32_t i = 0; i < uPoleCount; i++)
      {
        for (int32_t j = 0; j < vPoleCount; j++)
        {
          wArr.SetValue(i + 1, j + 1, weights[i * vPoleCount + j]);
        }
      }
      bsp = new Geom_BSplineSurface(poleArray,
                                    wArr,
                                    uKnotArr,
                                    vKnotArr,
                                    uMultArr,
                                    vMultArr,
                                    uDegree,
                                    vDegree);
    }
    else
    {
      bsp = new Geom_BSplineSurface(poleArray,
                                    uKnotArr,
                                    vKnotArr,
                                    uMultArr,
                                    vMultArr,
                                    uDegree,
                                    vDegree);
    }
    return new OCCTSurface(bsp);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceTrim(OCCTSurfaceRef s, double u1, double u2, double v1, double v2)
{
  if (!s || s->surface.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_RectangularTrimmedSurface) trimmed =
      new Geom_RectangularTrimmedSurface(s->surface, u1, u2, v1, v2);
    return new OCCTSurface(trimmed);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceOffset(OCCTSurfaceRef s, double distance)
{
  if (!s || s->surface.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_OffsetSurface) offset = new Geom_OffsetSurface(s->surface, distance);
    return new OCCTSurface(offset);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceTranslate(OCCTSurfaceRef s, double dx, double dy, double dz)
{
  if (!s || s->surface.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_Surface) copy = Handle(Geom_Surface)::DownCast(s->surface->Copy());
    gp_Trsf              trsf;
    if (!occtBuildTrsf3D(trsf, 0, dx, dy, dz, 0, 0, 0, 0))
      return nullptr;
    copy->Transform(trsf);
    return new OCCTSurface(copy);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceRotate(OCCTSurfaceRef s,
                                 double         axOx,
                                 double         axOy,
                                 double         axOz,
                                 double         axDx,
                                 double         axDy,
                                 double         axDz,
                                 double         angle)
{
  if (!s || s->surface.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_Surface) copy = Handle(Geom_Surface)::DownCast(s->surface->Copy());
    gp_Trsf              trsf;
    if (!occtBuildTrsf3D(trsf, 1, axOx, axOy, axOz, axDx, axDy, axDz, angle))
      return nullptr;
    copy->Transform(trsf);
    return new OCCTSurface(copy);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceScale(OCCTSurfaceRef s, double cx, double cy, double cz, double factor)
{
  if (!s || s->surface.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_Surface) copy = Handle(Geom_Surface)::DownCast(s->surface->Copy());
    gp_Trsf              trsf;
    if (!occtBuildTrsf3D(trsf, 2, cx, cy, cz, factor, 0, 0, 0))
      return nullptr;
    copy->Transform(trsf);
    return new OCCTSurface(copy);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceMirrorPlane(OCCTSurfaceRef s,
                                      double         px,
                                      double         py,
                                      double         pz,
                                      double         nx,
                                      double         ny,
                                      double         nz)
{
  if (!s || s->surface.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_Surface) copy = Handle(Geom_Surface)::DownCast(s->surface->Copy());
    gp_Trsf              trsf;
    if (!occtBuildTrsf3D(trsf, 5, px, py, pz, nx, ny, nz, 0))
      return nullptr;
    copy->Transform(trsf);
    return new OCCTSurface(copy);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceMirrorPoint(OCCTSurfaceRef s, double px, double py, double pz)
{
  if (!s || s->surface.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_Surface) copy = Handle(Geom_Surface)::DownCast(s->surface->Copy());
    gp_Trsf              trsf;
    if (!occtBuildTrsf3D(trsf, 3, px, py, pz, 0, 0, 0, 0))
      return nullptr;
    copy->Transform(trsf);
    return new OCCTSurface(copy);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceMirrorAxis(OCCTSurfaceRef s,
                                     double         px,
                                     double         py,
                                     double         pz,
                                     double         dx,
                                     double         dy,
                                     double         dz)
{
  if (!s || s->surface.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_Surface) copy = Handle(Geom_Surface)::DownCast(s->surface->Copy());
    gp_Trsf              trsf;
    if (!occtBuildTrsf3D(trsf, 4, px, py, pz, dx, dy, dz, 0))
      return nullptr;
    copy->Transform(trsf);
    return new OCCTSurface(copy);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceToBSpline(OCCTSurfaceRef s)
{
  if (!s || s->surface.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_BSplineSurface) bsp = GeomConvert::SurfaceToBSplineSurface(s->surface);
    if (bsp.IsNull())
      return nullptr;
    return new OCCTSurface(bsp);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceApproximate(OCCTSurfaceRef s,
                                      double         tolerance,
                                      int32_t        continuity,
                                      int32_t        maxSegments,
                                      int32_t        maxDegree)
{
  return occtApproxSurface(s, tolerance, continuity, continuity, maxSegments, maxDegree).surface;
}

OCCTCurve3DRef OCCTSurfaceUIso(OCCTSurfaceRef s, double u)
{
  if (!s || s->surface.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_Curve) iso = s->surface->UIso(u);
    if (iso.IsNull())
      return nullptr;
    return new OCCTCurve3D(iso);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTSurfaceVIso(OCCTSurfaceRef s, double v)
{
  if (!s || s->surface.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_Curve) iso = s->surface->VIso(v);
    if (iso.IsNull())
      return nullptr;
    return new OCCTCurve3D(iso);
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTSurfaceDrawGrid(OCCTSurfaceRef s,
                            int32_t        uCount,
                            int32_t        vCount,
                            int32_t        pointsPerLine,
                            double*        outXYZ,
                            int32_t        maxPoints,
                            int32_t*       outLineLengths,
                            int32_t        maxLines)
{
  if (!s || s->surface.IsNull() || !outXYZ || !outLineLengths || maxPoints <= 0 || maxLines <= 0)
    return 0;
  try
  {
    double uMin, uMax, vMin, vMax;
    s->surface->Bounds(uMin, uMax, vMin, vMax);

    // Clamp infinite bounds
    if (uMin < -1e6)
      uMin = -100;
    if (uMax > 1e6)
      uMax = 100;
    if (vMin < -1e6)
      vMin = -100;
    if (vMax > 1e6)
      vMax = 100;

    int32_t totalPoints = 0;
    int32_t lineIdx     = 0;

    // U-iso lines (constant U, varying V)
    for (int32_t i = 0; i < uCount && lineIdx < maxLines; i++)
    {
      double  u         = occtUniformParameter(uMin, uMax, i, uCount);
      int32_t ptsInLine = 0;
      for (int32_t j = 0; j < pointsPerLine && totalPoints < maxPoints; j++)
      {
        double v = occtUniformParameter(vMin, vMax, j, pointsPerLine);
        gp_Pnt p;
        s->surface->D0(u, v, p);
        outXYZ[totalPoints * 3]     = p.X();
        outXYZ[totalPoints * 3 + 1] = p.Y();
        outXYZ[totalPoints * 3 + 2] = p.Z();
        totalPoints++;
        ptsInLine++;
      }
      outLineLengths[lineIdx++] = ptsInLine;
    }

    // V-iso lines (constant V, varying U)
    for (int32_t j = 0; j < vCount && lineIdx < maxLines; j++)
    {
      double  v         = occtUniformParameter(vMin, vMax, j, vCount);
      int32_t ptsInLine = 0;
      for (int32_t i = 0; i < pointsPerLine && totalPoints < maxPoints; i++)
      {
        double u = occtUniformParameter(uMin, uMax, i, pointsPerLine);
        gp_Pnt p;
        s->surface->D0(u, v, p);
        outXYZ[totalPoints * 3]     = p.X();
        outXYZ[totalPoints * 3 + 1] = p.Y();
        outXYZ[totalPoints * 3 + 2] = p.Z();
        totalPoints++;
        ptsInLine++;
      }
      outLineLengths[lineIdx++] = ptsInLine;
    }

    return totalPoints;
  }
  catch (...)
  {
    return 0;
  }
}

// The minimum here is 1 sample per direction, not 2. Despite the name this is not a mesher:
// there is no BRepMesh, no triangulation and no quad, just a uniform walk of the parametric
// bounds evaluating Geom_Surface::D0, and a single (u, v) is a perfectly valid OCCT evaluation
// (measured: a 1 x 20 iso-row off a sphere is 20 finite points). The old `uCount < 2` guard was
// not OCCT's constraint but this function's own divisor: `i / (uCount - 1)` divides by zero at
// count 1, and the NaN parameter that produces is worse than a throw, because D0 does not throw
// on NaN, it returns NaN coordinates silently. OCCTSurfaceDrawGrid, forty lines above, samples
// the same bounds and had spelled the divisor defensively since the commit that introduced both
// functions; that expression is now occtUniformParameter, so neither loop states it in its own
// words and a single iso-row is served rather than rejected (#620). Every other member of this
// U-major grid family already accepted 1. DrawGrid guards no count at all, EvaluateGrid and
// EvaluateGridD1 guard `<= 0`, so the 2 here was the family's sole outlier.
//
// Note the infinite-bounds clamp below happens BEFORE the sampling, so on an unbounded surface
// the row a single sample lands on is the clamped -100, not the surface's own -2e100 uMin.
int32_t OCCTSurfaceDrawMesh(OCCTSurfaceRef s, int32_t uCount, int32_t vCount, double* outXYZ)
{
  if (!s || s->surface.IsNull() || !outXYZ || uCount < 1 || vCount < 1)
    return 0;
  try
  {
    double uMin, uMax, vMin, vMax;
    s->surface->Bounds(uMin, uMax, vMin, vMax);

    // Clamp infinite bounds
    if (uMin < -1e6)
      uMin = -100;
    if (uMax > 1e6)
      uMax = 100;
    if (vMin < -1e6)
      vMin = -100;
    if (vMax > 1e6)
      vMax = 100;

    int32_t idx = 0;
    for (int32_t i = 0; i < uCount; i++)
    {
      double u = occtUniformParameter(uMin, uMax, i, uCount);
      for (int32_t j = 0; j < vCount; j++)
      {
        double v = occtUniformParameter(vMin, vMax, j, vCount);
        gp_Pnt p;
        s->surface->D0(u, v, p);
        outXYZ[idx * 3]     = p.X();
        outXYZ[idx * 3 + 1] = p.Y();
        outXYZ[idx * 3 + 2] = p.Z();
        idx++;
      }
    }
    return idx;
  }
  catch (...)
  {
    return 0;
  }
}

// #595: both report definedness rather than spelling its absence 0, matching their
// OCCTFaceGetGaussianCurvature / OCCTFaceGetMeanCurvature counterparts, which read the same
// quantity off the same surface through the face. The collision here was the widest of the family:
// the Gaussian curvature of a plane, a cylinder and a cone is exactly 0 at every point of the
// surface, with IsCurvatureDefined() true, so whole surfaces returned the "no answer" value.
bool OCCTSurfaceGetGaussianCurvature(OCCTSurfaceRef s, double u, double v, double* curvature)
{
  *curvature = 0.0;
  return occtSurfaceCurvaturePair(s, u, v, curvature, nullptr);
}

bool OCCTSurfaceGetMeanCurvature(OCCTSurfaceRef s, double u, double v, double* curvature)
{
  *curvature = 0.0;
  return occtSurfaceCurvaturePair(s, u, v, nullptr, curvature);
}

bool OCCTSurfaceGetPrincipalCurvatures(OCCTSurfaceRef s,
                                       double         u,
                                       double         v,
                                       double*        kMin,
                                       double*        kMax,
                                       double*        d1x,
                                       double*        d1y,
                                       double*        d1z,
                                       double*        d2x,
                                       double*        d2y,
                                       double*        d2z)
{
  if (!s || s->surface.IsNull() || !kMin || !kMax || !d1x || !d1y || !d1z || !d2x || !d2y || !d2z)
    return false;
  try
  {
    GeomLProp_SLProps props = occtSurfaceLocalProps(s->surface, u, v, 2);
    if (!props.IsCurvatureDefined())
      return false;
    *kMin = props.MinCurvature();
    *kMax = props.MaxCurvature();
    // GeomLProp_SLProps::CurvatureDirections(gp_Dir& MaxD, gp_Dir& MinD) takes the MAXIMUM
    // direction first and the MINIMUM second (GeomLProp_SLProps.hxx). kMin/d1 above are paired
    // as the MINIMUM curvature, so minD (not maxD) is what belongs in d1 (#1437, same defect as
    // OCCTFaceGetPrincipalCurvatures in OCCTBridge_Properties.mm); the correct pairing already
    // exists next door as OCCTSurfaceLocalCurvatureDirections in this same file.
    gp_Dir maxD, minD;
    props.CurvatureDirections(maxD, minD);
    *d1x = minD.X();
    *d1y = minD.Y();
    *d1z = minD.Z();
    *d2x = maxD.X();
    *d2y = maxD.Y();
    *d2z = maxD.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTSurfaceGetUPoleCount(OCCTSurfaceRef s)
{
  if (!s || s->surface.IsNull())
    return 0;
  Handle(Geom_BSplineSurface) bsp = Handle(Geom_BSplineSurface)::DownCast(s->surface);
  if (bsp.IsNull())
  {
    Handle(Geom_BezierSurface) bez = Handle(Geom_BezierSurface)::DownCast(s->surface);
    if (!bez.IsNull())
      return bez->NbUPoles();
    return 0;
  }
  return bsp->NbUPoles();
}

int32_t OCCTSurfaceGetVPoleCount(OCCTSurfaceRef s)
{
  if (!s || s->surface.IsNull())
    return 0;
  Handle(Geom_BSplineSurface) bsp = Handle(Geom_BSplineSurface)::DownCast(s->surface);
  if (bsp.IsNull())
  {
    Handle(Geom_BezierSurface) bez = Handle(Geom_BezierSurface)::DownCast(s->surface);
    if (!bez.IsNull())
      return bez->NbVPoles();
    return 0;
  }
  return bsp->NbVPoles();
}

int32_t OCCTSurfaceGetPoles(OCCTSurfaceRef s, double* outXYZ)
{
  if (!s || s->surface.IsNull() || !outXYZ)
    return 0;
  try
  {
    Handle(Geom_BSplineSurface) bsp = Handle(Geom_BSplineSurface)::DownCast(s->surface);
    Handle(Geom_BezierSurface)  bez = Handle(Geom_BezierSurface)::DownCast(s->surface);

    int uCount = 0, vCount = 0;
    if (!bsp.IsNull())
    {
      uCount  = bsp->NbUPoles();
      vCount  = bsp->NbVPoles();
      int idx = 0;
      for (int i = 1; i <= uCount; i++)
      {
        for (int j = 1; j <= vCount; j++)
        {
          gp_Pnt p            = bsp->Pole(i, j);
          outXYZ[idx * 3]     = p.X();
          outXYZ[idx * 3 + 1] = p.Y();
          outXYZ[idx * 3 + 2] = p.Z();
          idx++;
        }
      }
      return idx;
    }
    else if (!bez.IsNull())
    {
      uCount  = bez->NbUPoles();
      vCount  = bez->NbVPoles();
      int idx = 0;
      for (int i = 1; i <= uCount; i++)
      {
        for (int j = 1; j <= vCount; j++)
        {
          gp_Pnt p            = bez->Pole(i, j);
          outXYZ[idx * 3]     = p.X();
          outXYZ[idx * 3 + 1] = p.Y();
          outXYZ[idx * 3 + 2] = p.Z();
          idx++;
        }
      }
      return idx;
    }
    return 0;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTSurfaceGetUDegree(OCCTSurfaceRef s)
{
  if (!s || s->surface.IsNull())
    return 0;
  Handle(Geom_BSplineSurface) bsp = Handle(Geom_BSplineSurface)::DownCast(s->surface);
  if (bsp.IsNull())
  {
    Handle(Geom_BezierSurface) bez = Handle(Geom_BezierSurface)::DownCast(s->surface);
    if (!bez.IsNull())
      return bez->UDegree();
    return 0;
  }
  return bsp->UDegree();
}

int32_t OCCTSurfaceGetVDegree(OCCTSurfaceRef s)
{
  if (!s || s->surface.IsNull())
    return 0;
  Handle(Geom_BSplineSurface) bsp = Handle(Geom_BSplineSurface)::DownCast(s->surface);
  if (bsp.IsNull())
  {
    Handle(Geom_BezierSurface) bez = Handle(Geom_BezierSurface)::DownCast(s->surface);
    if (!bez.IsNull())
      return bez->VDegree();
    return 0;
  }
  return bsp->VDegree();
}

bool OCCTShapeCheckCurveOnSurface(OCCTShapeRef shape, double* outMaxDist, double* outMaxParam)
{
  if (!shape || !outMaxDist || !outMaxParam)
    return false;
  try
  {
    double globalMaxDist  = 0;
    double globalMaxParam = 0;
    bool   anyChecked     = false;

    for (TopExp_Explorer fExp(shape->shape, TopAbs_FACE); fExp.More(); fExp.Next())
    {
      TopoDS_Face face = TopoDS::Face(fExp.Current());
      for (TopExp_Explorer eExp(face, TopAbs_EDGE); eExp.More(); eExp.Next())
      {
        TopoDS_Edge          edge = TopoDS::Edge(eExp.Current());
        double               f, l;
        Handle(Geom2d_Curve) pcurve = BRep_Tool::CurveOnSurface(edge, face, f, l);
        if (pcurve.IsNull())
          continue;

        BRepLib_CheckCurveOnSurface checker(edge, face);
        checker.Perform();
        if (checker.IsDone())
        {
          double dist = checker.MaxDistance();
          if (dist > globalMaxDist)
          {
            globalMaxDist  = dist;
            globalMaxParam = checker.MaxParameter();
          }
          anyChecked = true;
        }
      }
    }

    *outMaxDist  = globalMaxDist;
    *outMaxParam = globalMaxParam;
    return anyChecked;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTGeomFillConstrainedInfo(OCCTShapeRef face, OCCTConstrainedFillingInfo* info)
{
  if (!face || !info)
    return false;
  try
  {
    // Extract the BSpline surface from the face
    for (TopExp_Explorer exp(face->shape, TopAbs_FACE); exp.More(); exp.Next())
    {
      TopoDS_Face                 f       = TopoDS::Face(exp.Current());
      Handle(Geom_Surface)        surf    = BRep_Tool::Surface(f);
      Handle(Geom_BSplineSurface) bspline = Handle(Geom_BSplineSurface)::DownCast(surf);
      if (!bspline.IsNull())
      {
        info->isValid = true;
        info->uDegree = bspline->UDegree();
        info->vDegree = bspline->VDegree();
        info->uPoles  = bspline->NbUPoles();
        info->vPoles  = bspline->NbVPoles();
        return true;
      }
    }
    info->isValid = false;
    return false;
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - Surface Makers from Axis/Points/Normal (v0.50)
OCCTSurfaceRef OCCTSurfaceConicalFromAxis(double axisX,
                                          double axisY,
                                          double axisZ,
                                          double dirX,
                                          double dirY,
                                          double dirZ,
                                          double semiAngle,
                                          double radius)
{
  try
  {
    gp_Ax2                ax(gp_Pnt(axisX, axisY, axisZ), gp_Dir(dirX, dirY, dirZ));
    GC_MakeConicalSurface maker(ax, semiAngle, radius);
    if (!maker.IsDone())
      return nullptr;
    Handle(Geom_ConicalSurface) surf = maker.Value();
    if (surf.IsNull())
      return nullptr;
    auto* ref    = new OCCTSurface();
    ref->surface = surf;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceConicalFromPointsRadii(double p1x,
                                                 double p1y,
                                                 double p1z,
                                                 double p2x,
                                                 double p2y,
                                                 double p2z,
                                                 double r1,
                                                 double r2)
{
  try
  {
    GC_MakeConicalSurface maker(gp_Pnt(p1x, p1y, p1z), gp_Pnt(p2x, p2y, p2z), r1, r2);
    if (!maker.IsDone())
      return nullptr;
    Handle(Geom_ConicalSurface) surf = maker.Value();
    if (surf.IsNull())
      return nullptr;
    auto* ref    = new OCCTSurface();
    ref->surface = surf;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceCylindricalFromAxis(double axisX,
                                              double axisY,
                                              double axisZ,
                                              double dirX,
                                              double dirY,
                                              double dirZ,
                                              double radius)
{
  try
  {
    gp_Ax2                    ax(gp_Pnt(axisX, axisY, axisZ), gp_Dir(dirX, dirY, dirZ));
    GC_MakeCylindricalSurface maker(ax, radius);
    if (!maker.IsDone())
      return nullptr;
    Handle(Geom_CylindricalSurface) surf = maker.Value();
    if (surf.IsNull())
      return nullptr;
    auto* ref    = new OCCTSurface();
    ref->surface = surf;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceCylindricalFromPoints(double p1x,
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
    GC_MakeCylindricalSurface maker(gp_Pnt(p1x, p1y, p1z),
                                    gp_Pnt(p2x, p2y, p2z),
                                    gp_Pnt(p3x, p3y, p3z));
    if (!maker.IsDone())
      return nullptr;
    Handle(Geom_CylindricalSurface) surf = maker.Value();
    if (surf.IsNull())
      return nullptr;
    auto* ref    = new OCCTSurface();
    ref->surface = surf;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfacePlaneFromPoints(double p1x,
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
    GC_MakePlane maker(gp_Pnt(p1x, p1y, p1z), gp_Pnt(p2x, p2y, p2z), gp_Pnt(p3x, p3y, p3z));
    if (!maker.IsDone())
      return nullptr;
    Handle(Geom_Plane) plane = maker.Value();
    if (plane.IsNull())
      return nullptr;
    auto* ref    = new OCCTSurface();
    ref->surface = plane;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfacePlaneFromPointNormal(double px,
                                               double py,
                                               double pz,
                                               double nx,
                                               double ny,
                                               double nz)
{
  try
  {
    GC_MakePlane maker(gp_Pnt(px, py, pz), gp_Dir(nx, ny, nz));
    if (!maker.IsDone())
      return nullptr;
    Handle(Geom_Plane) plane = maker.Value();
    if (plane.IsNull())
      return nullptr;
    auto* ref    = new OCCTSurface();
    ref->surface = plane;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceTrimmedCone(double p1x,
                                      double p1y,
                                      double p1z,
                                      double p2x,
                                      double p2y,
                                      double p2z,
                                      double r1,
                                      double r2)
{
  try
  {
    GC_MakeTrimmedCone maker(gp_Pnt(p1x, p1y, p1z), gp_Pnt(p2x, p2y, p2z), r1, r2);
    if (!maker.IsDone())
      return nullptr;
    Handle(Geom_RectangularTrimmedSurface) surf = maker.Value();
    if (surf.IsNull())
      return nullptr;
    auto* ref    = new OCCTSurface();
    ref->surface = surf;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceTrimmedCylinder(double axisX,
                                          double axisY,
                                          double axisZ,
                                          double dirX,
                                          double dirY,
                                          double dirZ,
                                          double radius,
                                          double height)
{
  try
  {
    gp_Ax1                 ax(gp_Pnt(axisX, axisY, axisZ), gp_Dir(dirX, dirY, dirZ));
    GC_MakeTrimmedCylinder maker(ax, radius, height);
    if (!maker.IsDone())
      return nullptr;
    Handle(Geom_RectangularTrimmedSurface) surf = maker.Value();
    if (surf.IsNull())
      return nullptr;
    auto* ref    = new OCCTSurface();
    ref->surface = surf;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - Surface SplitByContinuity (v0.50)
OCCTSurfaceContinuitySplitResult OCCTSurfaceSplitByContinuity(OCCTSurfaceRef surface,
                                                              int32_t        criterion,
                                                              double         tolerance)
{
  OCCTSurfaceContinuitySplitResult result = {};
  if (!surface)
    return result;
  try
  {
    Handle(Geom_BSplineSurface) bsurf = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bsurf.IsNull())
      return result;

    Handle(ShapeUpgrade_SplitSurfaceContinuity) splitter =
      new ShapeUpgrade_SplitSurfaceContinuity();
    splitter->Init(bsurf);
    splitter->SetCriterion(occtGeomAbsFromParametricContinuity(criterion));
    splitter->SetTolerance(tolerance);
    splitter->Perform();

    result.isOk     = splitter->Status(ShapeExtend_OK);
    result.wasSplit = splitter->Status(ShapeExtend_DONE1);

    const Handle(TColStd_HSequenceOfReal)& uVals = splitter->USplitValues();
    const Handle(TColStd_HSequenceOfReal)& vVals = splitter->VSplitValues();
    result.nUSplits                              = uVals.IsNull() ? 0 : uVals->Length();
    result.nVSplits                              = vVals.IsNull() ? 0 : vVals->Length();
  }
  catch (...)
  {
  }
  return result;
}

OCCTGeomIntSSRef _Nullable OCCTGeomIntSSCreate(OCCTShapeRef face1,
                                               OCCTShapeRef face2,
                                               double       tolerance)
{
  if (!occtShapeIsPresent(face1) || !occtShapeIsPresent(face2))
    return nullptr;
  try
  {
    TopoDS_Face          f1 = TopoDS::Face(face1->shape);
    TopoDS_Face          f2 = TopoDS::Face(face2->shape);
    Handle(Geom_Surface) s1 = BRep_Tool::Surface(f1);
    Handle(Geom_Surface) s2 = BRep_Tool::Surface(f2);
    if (s1.IsNull() || s2.IsNull())
      return nullptr;
    auto* ref = new OCCTGeomIntSS();
    ref->intss.Perform(s1, s2, tolerance, true, false, false);
    ref->valid = ref->intss.IsDone();
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

int OCCTGeomIntSSLineCount(OCCTGeomIntSSRef ref)
{
  if (!ref)
    return 0;
  auto* r = static_cast<OCCTGeomIntSS*>(ref);
  if (!r->valid)
    return 0;
  return r->intss.NbLines();
}

OCCTShapeRef _Nullable OCCTGeomIntSSLine(OCCTGeomIntSSRef ref, int index)
{
  if (!ref)
    return nullptr;
  auto* r = static_cast<OCCTGeomIntSS*>(ref);
  if (!r->valid || index < 1 || index > r->intss.NbLines())
    return nullptr;
  try
  {
    Handle(Geom_Curve) curve = r->intss.Line(index);
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

int OCCTGeomIntSSPointCount(OCCTGeomIntSSRef ref)
{
  if (!ref)
    return 0;
  auto* r = static_cast<OCCTGeomIntSS*>(ref);
  if (!r->valid)
    return 0;
  return r->intss.NbPoints();
}

void OCCTGeomIntSSPoint(OCCTGeomIntSSRef ref, int index, double* x, double* y, double* z)
{
  if (!ref || !x || !y || !z)
    return;
  auto* r = static_cast<OCCTGeomIntSS*>(ref);
  if (!r->valid || index < 1 || index > r->intss.NbPoints())
    return;
  try
  {
    gp_Pnt pt = r->intss.Point(index);
    *x        = pt.X();
    *y        = pt.Y();
    *z        = pt.Z();
  }
  catch (...)
  {
  }
}

void OCCTGeomIntSSRelease(OCCTGeomIntSSRef ref)
{
  if (ref)
    delete static_cast<OCCTGeomIntSS*>(ref);
}

OCCTShapeRef _Nullable OCCTAdaptor3dIsoCurveEdge(OCCTShapeRef faceShape,
                                                 int          isoType,
                                                 double       param,
                                                 double       p1,
                                                 double       p2)
{
  if (!occtShapeIsPresent(faceShape))
    return nullptr;
  try
  {
    TopoDS_Face          face    = TopoDS::Face(faceShape->shape);
    Handle(Geom_Surface) surface = BRep_Tool::Surface(face);
    if (surface.IsNull())
      return nullptr;

    // Create iso-curve as a Geom_Curve
    Handle(Geom_Curve) isoCurve;
    if (isoType == 0)
    {
      isoCurve = surface->UIso(param);
    }
    else
    {
      isoCurve = surface->VIso(param);
    }
    if (isoCurve.IsNull())
      return nullptr;

    BRepBuilderAPI_MakeEdge me(isoCurve, p1, p2);
    if (!me.IsDone())
      return nullptr;
    return new OCCTShape(me.Edge());
  }
  catch (...)
  {
    return nullptr;
  }
}

// Both surface approximation entry points share occtApproxSurface, declared next to
// OCCTSurfaceApproximate above, see the #491 note there for the PrecisCode rationale. Note this
// entry point takes maxDegree BEFORE maxSegments, the reverse of OCCTSurfaceApproximate's order.
OCCTApproxSurfaceResult OCCTGeomConvertApproxSurface(OCCTSurfaceRef _Nonnull surface,
                                                     double  tolerance,
                                                     int32_t uContinuity,
                                                     int32_t vContinuity,
                                                     int32_t maxDegree,
                                                     int32_t maxSegments)
{
  return occtApproxSurface(surface, tolerance, uContinuity, vContinuity, maxSegments, maxDegree);
}

OCCTSurfToAnaSurfResult OCCTGeomConvertSurfToAnalytical(OCCTSurfaceRef _Nonnull surfaceRef,
                                                        double tolerance)
{
  return occtSurfToAnaSurfResult(surfaceRef, tolerance, nullptr);
}

OCCTSurfToAnaSurfResult OCCTGeomConvertSurfToAnalyticalBounded(OCCTSurfaceRef _Nonnull surfaceRef,
                                                               double tolerance,
                                                               double uMin,
                                                               double uMax,
                                                               double vMin,
                                                               double vMax)
{
  const double uvBounds[4] = {uMin, uMax, vMin, vMax};
  return occtSurfToAnaSurfResult(surfaceRef, tolerance, uvBounds);
}

OCCTGeomFillProfilerRef OCCTGeomFillProfilerCreate(void)
{
  try
  {
    auto* opaque   = new GeomFillProfilerOpaque();
    opaque->isDone = false;
    return opaque;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTGeomFillProfilerPerform(OCCTGeomFillProfilerRef _Nonnull ref, double tolerance)
{
  try
  {
    auto* opaque = (GeomFillProfilerOpaque*)ref;
    opaque->profiler.Perform(tolerance);
    opaque->isDone = true;
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int OCCTGeomFillProfilerDegree(OCCTGeomFillProfilerRef _Nonnull ref)
{
  try
  {
    auto* opaque = (GeomFillProfilerOpaque*)ref;
    return opaque->profiler.Degree();
  }
  catch (...)
  {
    return 0;
  }
}

int OCCTGeomFillProfilerNbPoles(OCCTGeomFillProfilerRef _Nonnull ref)
{
  try
  {
    auto* opaque = (GeomFillProfilerOpaque*)ref;
    return opaque->profiler.NbPoles();
  }
  catch (...)
  {
    return 0;
  }
}

int OCCTGeomFillProfilerNbKnots(OCCTGeomFillProfilerRef _Nonnull ref)
{
  try
  {
    auto* opaque = (GeomFillProfilerOpaque*)ref;
    return opaque->profiler.NbKnots();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTGeomFillProfilerIsPeriodic(OCCTGeomFillProfilerRef _Nonnull ref)
{
  try
  {
    auto* opaque = (GeomFillProfilerOpaque*)ref;
    return opaque->profiler.IsPeriodic();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTGeomFillProfilerPoles(OCCTGeomFillProfilerRef _Nonnull ref,
                               int curveIndex,
                               double* _Nonnull outX,
                               double* _Nonnull outY,
                               double* _Nonnull outZ,
                               int maxPoles)
{
  try
  {
    auto* opaque = (GeomFillProfilerOpaque*)ref;
    int   nPoles = opaque->profiler.NbPoles();
    if (nPoles > maxPoles)
      return false;
    NCollection_Array1<gp_Pnt> poles(1, nPoles);
    opaque->profiler.Poles(curveIndex, poles);
    for (int i = 1; i <= nPoles; i++)
    {
      outX[i - 1] = poles(i).X();
      outY[i - 1] = poles(i).Y();
      outZ[i - 1] = poles(i).Z();
    }
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTGeomFillProfilerKnotsAndMults(OCCTGeomFillProfilerRef _Nonnull ref,
                                       double* _Nonnull outKnots,
                                       int* _Nonnull outMults,
                                       int maxKnots)
{
  try
  {
    auto* opaque = (GeomFillProfilerOpaque*)ref;
    int   nKnots = opaque->profiler.NbKnots();
    if (nKnots > maxKnots)
      return false;
    NCollection_Array1<double> knots(1, nKnots);
    NCollection_Array1<int>    mults(1, nKnots);
    opaque->profiler.KnotsAndMults(knots, mults);
    for (int i = 1; i <= nKnots; i++)
    {
      outKnots[i - 1] = knots(i);
      outMults[i - 1] = mults(i);
    }
    return true;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTGeomFillProfilerRelease(OCCTGeomFillProfilerRef _Nonnull ref)
{
  delete (GeomFillProfilerOpaque*)ref;
}

bool OCCTGeomFillLocationDraftD0(OCCTLocationDraftRef _Nonnull ref,
                                 double param,
                                 double* _Nonnull mat,
                                 double* _Nonnull vecX,
                                 double* _Nonnull vecY,
                                 double* _Nonnull vecZ)
{
  try
  {
    auto*  opaque = (LocationDraftOpaque*)ref;
    gp_Mat M;
    gp_Vec V;
    bool   ok = opaque->loc->D0(param, M, V);
    if (ok)
    {
      // Store 3x3 matrix row-major
      for (int r = 1; r <= 3; r++)
        for (int c = 1; c <= 3; c++)
          mat[(r - 1) * 3 + (c - 1)] = M.Value(r, c);
      *vecX = V.X();
      *vecY = V.Y();
      *vecZ = V.Z();
    }
    return ok;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTGeomFillLocationDraftSetAngle(OCCTLocationDraftRef _Nonnull ref, double angle)
{
  try
  {
    auto* opaque = (LocationDraftOpaque*)ref;
    opaque->loc->SetAngle(angle);
  }
  catch (...)
  {
  }
}

void OCCTGeomFillLocationDraftDirection(OCCTLocationDraftRef _Nonnull ref,
                                        double* _Nonnull x,
                                        double* _Nonnull y,
                                        double* _Nonnull z)
{
  try
  {
    auto*  opaque = (LocationDraftOpaque*)ref;
    gp_Dir d      = opaque->loc->Direction();
    *x            = d.X();
    *y            = d.Y();
    *z            = d.Z();
  }
  catch (...)
  {
  }
}

void OCCTGeomFillLocationDraftRelease(OCCTLocationDraftRef _Nonnull ref)
{
  delete (LocationDraftOpaque*)ref;
}

bool OCCTGeomFillGuideTrihedronACD0(OCCTGuideTrihedronACRef _Nonnull ref,
                                    double param,
                                    double* _Nonnull tX,
                                    double* _Nonnull tY,
                                    double* _Nonnull tZ,
                                    double* _Nonnull nX,
                                    double* _Nonnull nY,
                                    double* _Nonnull nZ,
                                    double* _Nonnull bX,
                                    double* _Nonnull bY,
                                    double* _Nonnull bZ)
{
  try
  {
    auto*  opaque = (GuideTrihedronACOpaque*)ref;
    gp_Vec T, N, B;
    bool   ok = opaque->tri->D0(param, T, N, B);
    if (ok)
    {
      *tX = T.X();
      *tY = T.Y();
      *tZ = T.Z();
      *nX = N.X();
      *nY = N.Y();
      *nZ = N.Z();
      *bX = B.X();
      *bY = B.Y();
      *bZ = B.Z();
    }
    return ok;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTGeomFillGuideTrihedronACRelease(OCCTGuideTrihedronACRef _Nonnull ref)
{
  delete (GuideTrihedronACOpaque*)ref;
}

bool OCCTGeomFillGuideTrihedronPlanD0(OCCTGuideTrihedronPlanRef _Nonnull ref,
                                      double param,
                                      double* _Nonnull tX,
                                      double* _Nonnull tY,
                                      double* _Nonnull tZ,
                                      double* _Nonnull nX,
                                      double* _Nonnull nY,
                                      double* _Nonnull nZ,
                                      double* _Nonnull bX,
                                      double* _Nonnull bY,
                                      double* _Nonnull bZ)
{
  try
  {
    auto*  opaque = (GuideTrihedronPlanOpaque*)ref;
    gp_Vec T, N, B;
    bool   ok = opaque->tri->D0(param, T, N, B);
    if (ok)
    {
      *tX = T.X();
      *tY = T.Y();
      *tZ = T.Z();
      *nX = N.X();
      *nY = N.Y();
      *nZ = N.Z();
      *bX = B.X();
      *bY = B.Y();
      *bZ = B.Z();
    }
    return ok;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTGeomFillGuideTrihedronPlanRelease(OCCTGuideTrihedronPlanRef _Nonnull ref)
{
  delete (GuideTrihedronPlanOpaque*)ref;
}

// MARK: - gce_Make Pln (v0.80)
// Note (#420): OCCTGceMakeCone / OCCTGceMakeCylinderFrom3Points used to live here,
// duplicating OCCTSurfaceConicalFromPointsRadii / OCCTSurfaceCylindricalFromPoints
// (same points-and-radii inputs) via a separate gce_MakeCone/gce_MakeCylinder ->
// gp_Cone/gp_Cylinder -> Geom_ConicalSurface/Geom_CylindricalSurface round-trip.
// Removed in favor of the single GC_MakeConicalSurface/GC_MakeCylindricalSurface
// path; see Surface.coneFrom2PointsRadii/cylinderFrom3Points in Surface.swift.
OCCTSurfaceRef _Nullable OCCTGceMakePlnFromEquation(double a, double b, double c, double d)
{
  try
  {
    gce_MakePln mp(a, b, c, d);
    if (!mp.IsDone())
      return nullptr;
    Handle(Geom_Plane) plane = new Geom_Plane(mp.Value());
    return (OCCTSurfaceRef) new OCCTSurface{plane};
  }
  catch (...)
  {
    return nullptr;
  }
}

// Exactly OCCTSurfacePlaneFromPoints (GC_MakePlane), a second, independent 3-point plane
// constructor. Ground-truthed for #421 (control, collinear, collinear-uneven, and both
// coincident-point cases): GC_MakePlane and gce_MakePln's 3-point overloads agree on every case
// tested, so forwarding is behaviour-preserving. Keeps the C ABI while leaving one implementation.
OCCTSurfaceRef _Nullable OCCTGceMakePlnFrom3Points(double p1x,
                                                   double p1y,
                                                   double p1z,
                                                   double p2x,
                                                   double p2y,
                                                   double p2z,
                                                   double p3x,
                                                   double p3y,
                                                   double p3z)
{
  return OCCTSurfacePlaneFromPoints(p1x, p1y, p1z, p2x, p2y, p2z, p3x, p3y, p3z);
}

OCCTSurfaceRef OCCTSurfaceCreateRectangularTrimmed(OCCTSurfaceRef basisSurface,
                                                   double         u1,
                                                   double         u2,
                                                   double         v1,
                                                   double         v2)
{
  if (!basisSurface || basisSurface->surface.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_RectangularTrimmedSurface) ts =
      new Geom_RectangularTrimmedSurface(basisSurface->surface, u1, u2, v1, v2);
    auto* ref    = new OCCTSurface();
    ref->surface = ts;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceCreateTrimmedInU(OCCTSurfaceRef basisSurface,
                                           double         param1,
                                           double         param2)
{
  if (!basisSurface || basisSurface->surface.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_RectangularTrimmedSurface) ts =
      new Geom_RectangularTrimmedSurface(basisSurface->surface, param1, param2, true);
    auto* ref    = new OCCTSurface();
    ref->surface = ts;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceCreateTrimmedInV(OCCTSurfaceRef basisSurface,
                                           double         param1,
                                           double         param2)
{
  if (!basisSurface || basisSurface->surface.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_RectangularTrimmedSurface) ts =
      new Geom_RectangularTrimmedSurface(basisSurface->surface, param1, param2, false);
    auto* ref    = new OCCTSurface();
    ref->surface = ts;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTElSLibValueOnPlane(double  u,
                            double  v,
                            double  ox,
                            double  oy,
                            double  oz,
                            double  nx,
                            double  ny,
                            double  nz,
                            double* outX,
                            double* outY,
                            double* outZ)
{
  try
  {
    gp_Pnt p = ElSLib::Value(u, v, gp_Pln(gp_Pnt(ox, oy, oz), gp_Dir(nx, ny, nz)));
    *outX    = p.X();
    *outY    = p.Y();
    *outZ    = p.Z();
  }
  catch (...)
  {
  }
}

void OCCTElSLibValueOnCylinder(double  u,
                               double  v,
                               double  ox,
                               double  oy,
                               double  oz,
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
    gp_Pnt p =
      ElSLib::Value(u, v, gp_Cylinder(gp_Ax3(gp_Pnt(ox, oy, oz), gp_Dir(nx, ny, nz)), radius));
    *outX = p.X();
    *outY = p.Y();
    *outZ = p.Z();
  }
  catch (...)
  {
  }
}

void OCCTElSLibValueOnCone(double  u,
                           double  v,
                           double  ox,
                           double  oy,
                           double  oz,
                           double  nx,
                           double  ny,
                           double  nz,
                           double  refRadius,
                           double  semiAngle,
                           double* outX,
                           double* outY,
                           double* outZ)
{
  try
  {
    gp_Pnt p =
      ElSLib::Value(u,
                    v,
                    gp_Cone(gp_Ax3(gp_Pnt(ox, oy, oz), gp_Dir(nx, ny, nz)), semiAngle, refRadius));
    *outX = p.X();
    *outY = p.Y();
    *outZ = p.Z();
  }
  catch (...)
  {
  }
}

void OCCTElSLibValueOnSphere(double  u,
                             double  v,
                             double  ox,
                             double  oy,
                             double  oz,
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
    gp_Pnt p =
      ElSLib::Value(u, v, gp_Sphere(gp_Ax3(gp_Pnt(ox, oy, oz), gp_Dir(nx, ny, nz)), radius));
    *outX = p.X();
    *outY = p.Y();
    *outZ = p.Z();
  }
  catch (...)
  {
  }
}

void OCCTElSLibValueOnTorus(double  u,
                            double  v,
                            double  ox,
                            double  oy,
                            double  oz,
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
    gp_Pnt p = ElSLib::Value(
      u,
      v,
      gp_Torus(gp_Ax3(gp_Pnt(ox, oy, oz), gp_Dir(nx, ny, nz)), majorRadius, minorRadius));
    *outX = p.X();
    *outY = p.Y();
    *outZ = p.Z();
  }
  catch (...)
  {
  }
}

void OCCTElSLibParametersOnSphere(double  ox,
                                  double  oy,
                                  double  oz,
                                  double  nx,
                                  double  ny,
                                  double  nz,
                                  double  radius,
                                  double  px,
                                  double  py,
                                  double  pz,
                                  double* outU,
                                  double* outV)
{
  try
  {
    double u, v;
    ElSLib::Parameters(gp_Sphere(gp_Ax3(gp_Pnt(ox, oy, oz), gp_Dir(nx, ny, nz)), radius),
                       gp_Pnt(px, py, pz),
                       u,
                       v);
    *outU = u;
    *outV = v;
  }
  catch (...)
  {
  }
}

void OCCTElSLibD1OnSphere(double  u,
                          double  v,
                          double  ox,
                          double  oy,
                          double  oz,
                          double  nx,
                          double  ny,
                          double  nz,
                          double  radius,
                          double* outPX,
                          double* outPY,
                          double* outPZ,
                          double* outVuX,
                          double* outVuY,
                          double* outVuZ,
                          double* outVvX,
                          double* outVvY,
                          double* outVvZ)
{
  try
  {
    gp_Pnt p;
    gp_Vec vu, vv;
    ElSLib::D1(u, v, gp_Sphere(gp_Ax3(gp_Pnt(ox, oy, oz), gp_Dir(nx, ny, nz)), radius), p, vu, vv);
    *outPX  = p.X();
    *outPY  = p.Y();
    *outPZ  = p.Z();
    *outVuX = vu.X();
    *outVuY = vu.Y();
    *outVuZ = vu.Z();
    *outVvX = vv.X();
    *outVvY = vv.Y();
    *outVvZ = vv.Z();
  }
  catch (...)
  {
  }
}

OCCTSurfaceRef OCCTConvertSphereToBSplineSurface(double ox,
                                                 double oy,
                                                 double oz,
                                                 double nx,
                                                 double ny,
                                                 double nz,
                                                 double radius)
{
  try
  {
    gp_Sphere                      sphere(gp_Ax3(gp_Pnt(ox, oy, oz), gp_Dir(nx, ny, nz)), radius);
    Convert_SphereToBSplineSurface conv(sphere);
    return buildSurfaceFromElementary(conv);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTConvertCylinderToBSplineSurface(double ox,
                                                   double oy,
                                                   double oz,
                                                   double nx,
                                                   double ny,
                                                   double nz,
                                                   double radius,
                                                   double u1,
                                                   double u2,
                                                   double v1,
                                                   double v2)
{
  try
  {
    gp_Cylinder                      cyl(gp_Ax3(gp_Pnt(ox, oy, oz), gp_Dir(nx, ny, nz)), radius);
    Convert_CylinderToBSplineSurface conv(cyl, u1, u2, v1, v2);
    return buildSurfaceFromElementary(conv);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTConvertConeToBSplineSurface(double ox,
                                               double oy,
                                               double oz,
                                               double nx,
                                               double ny,
                                               double nz,
                                               double semiAngle,
                                               double refRadius,
                                               double u1,
                                               double u2,
                                               double v1,
                                               double v2)
{
  try
  {
    gp_Cone cone(gp_Ax3(gp_Pnt(ox, oy, oz), gp_Dir(nx, ny, nz)), semiAngle, refRadius);
    Convert_ConeToBSplineSurface conv(cone, u1, u2, v1, v2);
    return buildSurfaceFromElementary(conv);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTConvertTorusToBSplineSurface(double ox,
                                                double oy,
                                                double oz,
                                                double nx,
                                                double ny,
                                                double nz,
                                                double majorRadius,
                                                double minorRadius)
{
  try
  {
    gp_Torus torus(gp_Ax3(gp_Pnt(ox, oy, oz), gp_Dir(nx, ny, nz)), majorRadius, minorRadius);
    Convert_TorusToBSplineSurface conv(torus);
    return buildSurfaceFromElementary(conv);
  }
  catch (...)
  {
    return nullptr;
  }
}

double OCCTSurfaceOffsetValue(OCCTSurfaceRef surface)
{
  if (!surface || surface->surface.IsNull())
    return 0.0;
  Handle(Geom_OffsetSurface) off = Handle(Geom_OffsetSurface)::DownCast(surface->surface);
  if (off.IsNull())
    return 0.0;
  return off->Offset();
}

void OCCTSurfaceSetOffsetValue(OCCTSurfaceRef surface, double offset)
{
  if (!surface || surface->surface.IsNull())
    return;
  Handle(Geom_OffsetSurface) off = Handle(Geom_OffsetSurface)::DownCast(surface->surface);
  if (off.IsNull())
    return;
  try
  {
    off->SetOffsetValue(offset);
  }
  catch (...)
  {
  }
}

OCCTSurfaceRef OCCTSurfaceOffsetBasis(OCCTSurfaceRef surface)
{
  if (!surface || surface->surface.IsNull())
    return nullptr;
  Handle(Geom_OffsetSurface) off = Handle(Geom_OffsetSurface)::DownCast(surface->surface);
  if (off.IsNull())
    return nullptr;
  Handle(Geom_Surface) basis = off->BasisSurface();
  if (basis.IsNull())
    return nullptr;
  auto* ref    = new OCCTSurface();
  ref->surface = basis;
  return ref;
}

/// BRepGProp_Face Gauss-integration orders (number of integration points) in U and V, non-zero
/// only for BSpline faces. Returns false if `face` is not a face.
bool OCCTBRepGPropFaceIntegrationOrders(OCCTShapeRef face, int32_t* uOrder, int32_t* vOrder)
{
  if (!face || face->shape.IsNull() || face->shape.ShapeType() != TopAbs_FACE)
    return false;
  try
  {
    BRepGProp_Face gf(TopoDS::Face(face->shape));
    if (uOrder)
      *uOrder = gf.UIntegrationOrder();
    if (vOrder)
      *vOrder = gf.VIntegrationOrder();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

/// BRepGProp_Face U-direction integration knots (BSpline spans over the face's U range). Fills up
/// to `maxCount` into `buffer` and returns the count, or 0 on failure.
int32_t OCCTBRepGPropFaceUKnots(OCCTShapeRef face, double* buffer, int32_t maxCount)
{
  if (!face || face->shape.IsNull() || face->shape.ShapeType() != TopAbs_FACE)
    return 0;
  try
  {
    BRepGProp_Face gf(TopoDS::Face(face->shape));
    double         u1, u2, v1, v2;
    gf.Bounds(u1, u2, v1, v2);
    Handle(NCollection_HArray1<double>) knots = gf.GetUKnots(u1, u2);
    if (knots.IsNull())
      return 0;
    int32_t n = 0;
    for (int i = knots->Lower(); i <= knots->Upper() && n < maxCount; i++, n++)
    {
      if (buffer)
        buffer[n] = knots->Value(i);
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTBRepGPropFaceVKnots(OCCTShapeRef face, double* buffer, int32_t maxCount)
{
  if (!face || face->shape.IsNull() || face->shape.ShapeType() != TopAbs_FACE)
    return 0;
  try
  {
    BRepGProp_Face gf(TopoDS::Face(face->shape));
    int            n = gf.SVIntSubs();
    if (n < 1)
      n = 1;
    // SVIntSubs() returns the V subinterval count, N-1; VKnots() always writes N knots
    // (BRepGProp_Face.cxx), one past the subinterval count, so the array must hold n+1 (#1433).
    NCollection_Array1<double> k(1, n + 1);
    gf.VKnots(k);
    int32_t c = 0;
    for (int i = k.Lower(); i <= k.Upper() && c < maxCount; i++, c++)
    {
      if (buffer)
        buffer[c] = k.Value(i);
    }
    return c;
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTBRepGPropFaceSurfaceIntegration(OCCTShapeRef face,
                                         double       eps,
                                         int32_t*     order,
                                         int32_t*     uSubs,
                                         int32_t*     vSubs)
{
  if (!face || face->shape.IsNull() || face->shape.ShapeType() != TopAbs_FACE)
    return false;
  try
  {
    BRepGProp_Face gf(TopoDS::Face(face->shape));
    if (order)
      *order = gf.SIntOrder(eps);
    if (uSubs)
      *uSubs = gf.SUIntSubs();
    if (vSubs)
      *vSubs = gf.SVIntSubs();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTBRepGPropFaceBoundaryIntegration(OCCTShapeRef face,
                                          int32_t      edgeIndex,
                                          double       eps,
                                          int32_t*     order,
                                          int32_t*     subs,
                                          double*      knotBuffer,
                                          int32_t      maxKnots,
                                          int32_t*     knotCount)
{
  if (knotCount)
    *knotCount = 0;
  if (!face || face->shape.IsNull() || face->shape.ShapeType() != TopAbs_FACE)
    return false;
  try
  {
    TopoDS_Face                f = TopoDS::Face(face->shape);
    TopTools_IndexedMapOfShape emap;
    TopExp::MapShapes(f, TopAbs_EDGE, emap);
    if (edgeIndex < 0 || edgeIndex >= emap.Extent())
      return false;
    BRepGProp_Face gf(f);
    if (!gf.Load(TopoDS::Edge(emap(edgeIndex + 1))))
      return false; // load the boundary arc
    if (order)
      *order = gf.LIntOrder(eps);
    int s = gf.LIntSubs();
    if (subs)
      *subs = s;
    int n = s < 1 ? 1 : s;
    // LIntSubs() returns the subinterval count, N-1; LKnots() always writes N knots
    // (BRepGProp_Face.cxx), one past the subinterval count, so the array must hold n+1 (#1433).
    NCollection_Array1<double> k(1, n + 1);
    gf.LKnots(k);
    int32_t c = 0;
    for (int i = k.Lower(); i <= k.Upper() && c < maxKnots; i++, c++)
    {
      if (knotBuffer)
        knotBuffer[c] = k.Value(i);
    }
    if (knotCount)
      *knotCount = c;
    return true;
  }
  catch (...)
  {
    return false;
  }
}

OCCTSurfaceRef OCCTGCMakeConicalSurface(double cx,
                                        double cy,
                                        double cz,
                                        double nx,
                                        double ny,
                                        double nz,
                                        double semiAngle,
                                        double radius)
{
  try
  {
    gp_Ax2                ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
    GC_MakeConicalSurface mc(ax, semiAngle, radius);
    if (!mc.IsDone())
      return nullptr;
    return new OCCTSurface(mc.Value());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTGCMakeConicalSurface2Pts(double x1,
                                            double y1,
                                            double z1,
                                            double x2,
                                            double y2,
                                            double z2,
                                            double r1,
                                            double r2)
{
  try
  {
    GC_MakeConicalSurface mc(gp_Pnt(x1, y1, z1), gp_Pnt(x2, y2, z2), r1, r2);
    if (!mc.IsDone())
      return nullptr;
    return new OCCTSurface(mc.Value());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTGCMakeConicalSurface4Pts(double x1,
                                            double y1,
                                            double z1,
                                            double x2,
                                            double y2,
                                            double z2,
                                            double x3,
                                            double y3,
                                            double z3,
                                            double x4,
                                            double y4,
                                            double z4)
{
  try
  {
    GC_MakeConicalSurface mc(gp_Pnt(x1, y1, z1),
                             gp_Pnt(x2, y2, z2),
                             gp_Pnt(x3, y3, z3),
                             gp_Pnt(x4, y4, z4));
    if (!mc.IsDone())
      return nullptr;
    return new OCCTSurface(mc.Value());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTGCMakeCylindricalSurface(double cx,
                                            double cy,
                                            double cz,
                                            double nx,
                                            double ny,
                                            double nz,
                                            double radius)
{
  try
  {
    gp_Ax2                    ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
    GC_MakeCylindricalSurface mc(ax, radius);
    if (!mc.IsDone())
      return nullptr;
    return new OCCTSurface(mc.Value());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTGCMakeCylindricalSurface3Pts(double x1,
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
    GC_MakeCylindricalSurface mc(gp_Pnt(x1, y1, z1), gp_Pnt(x2, y2, z2), gp_Pnt(x3, y3, z3));
    if (!mc.IsDone())
      return nullptr;
    return new OCCTSurface(mc.Value());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTGCMakeCylindricalSurfaceFromCircle(double cx,
                                                      double cy,
                                                      double cz,
                                                      double nx,
                                                      double ny,
                                                      double nz,
                                                      double radius)
{
  try
  {
    gp_Ax2                    ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
    gp_Circ                   circ(ax, radius);
    GC_MakeCylindricalSurface mc(circ);
    if (!mc.IsDone())
      return nullptr;
    return new OCCTSurface(mc.Value());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTGCMakeCylindricalSurfaceParallel(double cx,
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
    gp_Ax2                    ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
    gp_Cylinder               cyl(ax, radius);
    GC_MakeCylindricalSurface mc(cyl, dist);
    if (!mc.IsDone())
      return nullptr;
    return new OCCTSurface(mc.Value());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTGCMakeCylindricalSurfaceAxis(double px,
                                                double py,
                                                double pz,
                                                double dx,
                                                double dy,
                                                double dz,
                                                double radius)
{
  try
  {
    gp_Ax1                    ax(gp_Pnt(px, py, pz), gp_Dir(dx, dy, dz));
    GC_MakeCylindricalSurface mc(ax, radius);
    if (!mc.IsDone())
      return nullptr;
    return new OCCTSurface(mc.Value());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTGCMakeTrimmedCone2Pts(double x1,
                                         double y1,
                                         double z1,
                                         double x2,
                                         double y2,
                                         double z2,
                                         double r1,
                                         double r2)
{
  try
  {
    GC_MakeTrimmedCone mc(gp_Pnt(x1, y1, z1), gp_Pnt(x2, y2, z2), r1, r2);
    if (!mc.IsDone())
      return nullptr;
    return new OCCTSurface(mc.Value());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTGCMakeTrimmedCone4Pts(double x1,
                                         double y1,
                                         double z1,
                                         double x2,
                                         double y2,
                                         double z2,
                                         double x3,
                                         double y3,
                                         double z3,
                                         double x4,
                                         double y4,
                                         double z4)
{
  try
  {
    GC_MakeTrimmedCone mc(gp_Pnt(x1, y1, z1),
                          gp_Pnt(x2, y2, z2),
                          gp_Pnt(x3, y3, z3),
                          gp_Pnt(x4, y4, z4));
    if (!mc.IsDone())
      return nullptr;
    return new OCCTSurface(mc.Value());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTGCMakeTrimmedCylinderCircle(double cx,
                                               double cy,
                                               double cz,
                                               double nx,
                                               double ny,
                                               double nz,
                                               double radius,
                                               double height)
{
  try
  {
    gp_Ax2                 ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
    gp_Circ                circ(ax, radius);
    GC_MakeTrimmedCylinder mc(circ, height);
    if (!mc.IsDone())
      return nullptr;
    return new OCCTSurface(mc.Value());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTGCMakeTrimmedCylinderAxis(double px,
                                             double py,
                                             double pz,
                                             double dx,
                                             double dy,
                                             double dz,
                                             double radius,
                                             double height)
{
  try
  {
    gp_Ax1                 ax(gp_Pnt(px, py, pz), gp_Dir(dx, dy, dz));
    GC_MakeTrimmedCylinder mc(ax, radius, height);
    if (!mc.IsDone())
      return nullptr;
    return new OCCTSurface(mc.Value());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTGCMakeTrimmedCylinder3Pts(double x1,
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
    GC_MakeTrimmedCylinder mc(gp_Pnt(x1, y1, z1), gp_Pnt(x2, y2, z2), gp_Pnt(x3, y3, z3));
    if (!mc.IsDone())
      return nullptr;
    return new OCCTSurface(mc.Value());
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTSurfaceGetContinuity(OCCTSurfaceRef surface)
{
  if (!surface || surface->surface.IsNull())
    return 0;
  try
  {
    return static_cast<int32_t>(surface->surface->Continuity());
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTSurfaceGetNBounds(OCCTSurfaceRef surface, int32_t* uSpans, int32_t* vSpans)
{
  *uSpans = 0;
  *vSpans = 0;
  if (!surface || surface->surface.IsNull())
    return;
  try
  {
    double u1, u2, v1, v2;
    surface->surface->Bounds(u1, u2, v1, v2);
    *uSpans = (u2 > u1) ? 1 : 0;
    *vSpans = (v2 > v1) ? 1 : 0;
  }
  catch (...)
  {
  }
}

int32_t OCCTSurfaceBSplineNbUKnots(OCCTSurfaceRef surface)
{
  if (!surface || surface->surface.IsNull())
    return 0;
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return 0;
  return bs->NbUKnots();
}

int32_t OCCTSurfaceBSplineNbVKnots(OCCTSurfaceRef surface)
{
  if (!surface || surface->surface.IsNull())
    return 0;
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return 0;
  return bs->NbVKnots();
}

int32_t OCCTSurfaceBSplineNbUPoles(OCCTSurfaceRef surface)
{
  if (!surface || surface->surface.IsNull())
    return 0;
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return 0;
  return bs->NbUPoles();
}

int32_t OCCTSurfaceBSplineNbVPoles(OCCTSurfaceRef surface)
{
  if (!surface || surface->surface.IsNull())
    return 0;
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return 0;
  return bs->NbVPoles();
}

int32_t OCCTSurfaceBSplineUDegree(OCCTSurfaceRef surface)
{
  if (!surface || surface->surface.IsNull())
    return 0;
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return 0;
  return bs->UDegree();
}

int32_t OCCTSurfaceBSplineVDegree(OCCTSurfaceRef surface)
{
  if (!surface || surface->surface.IsNull())
    return 0;
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return 0;
  return bs->VDegree();
}

bool OCCTSurfaceBSplineIsURational(OCCTSurfaceRef surface)
{
  if (!surface || surface->surface.IsNull())
    return false;
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  return bs->IsURational();
}

bool OCCTSurfaceBSplineIsVRational(OCCTSurfaceRef surface)
{
  if (!surface || surface->surface.IsNull())
    return false;
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  return bs->IsVRational();
}

void OCCTSurfaceBSplineGetPole(OCCTSurfaceRef surface,
                               int32_t        uIndex,
                               int32_t        vIndex,
                               double*        x,
                               double*        y,
                               double*        z)
{
  *x = 0;
  *y = 0;
  *z = 0;
  if (!surface || surface->surface.IsNull())
    return;
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return;
  if (uIndex < 1 || uIndex > bs->NbUPoles() || vIndex < 1 || vIndex > bs->NbVPoles())
    return;
  gp_Pnt p = bs->Pole(uIndex, vIndex);
  *x       = p.X();
  *y       = p.Y();
  *z       = p.Z();
}

bool OCCTSurfaceBSplineSetPole(OCCTSurfaceRef surface,
                               int32_t        uIndex,
                               int32_t        vIndex,
                               double         x,
                               double         y,
                               double         z)
{
  if (!surface || surface->surface.IsNull())
    return false;
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    bs->SetPole(uIndex, vIndex, gp_Pnt(x, y, z));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBSplineSetWeight(OCCTSurfaceRef surface,
                                 int32_t        uIndex,
                                 int32_t        vIndex,
                                 double         weight)
{
  if (!surface || surface->surface.IsNull())
    return false;
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    bs->SetWeight(uIndex, vIndex, weight);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBSplineInsertUKnot(OCCTSurfaceRef surface, double u, int32_t mult, double tol)
{
  if (!surface || surface->surface.IsNull())
    return false;
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    bs->InsertUKnot(u, mult, tol);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBSplineInsertVKnot(OCCTSurfaceRef surface, double v, int32_t mult, double tol)
{
  if (!surface || surface->surface.IsNull())
    return false;
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    bs->InsertVKnot(v, mult, tol);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBSplineSegment(OCCTSurfaceRef surface, double u1, double u2, double v1, double v2)
{
  if (!surface || surface->surface.IsNull())
    return false;
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    bs->Segment(u1, u2, v1, v2);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBSplineIncreaseDegree(OCCTSurfaceRef surface, int32_t uDeg, int32_t vDeg)
{
  if (!surface || surface->surface.IsNull())
    return false;
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    bs->IncreaseDegree(uDeg, vDeg);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBSplineExchangeUV(OCCTSurfaceRef surface)
{
  if (!surface || surface->surface.IsNull())
    return false;
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    bs->ExchangeUV();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTSurfacePlaneCoefficients(OCCTSurfaceRef surface,
                                  double*        A,
                                  double*        B,
                                  double*        C,
                                  double*        D)
{
  *A = 0;
  *B = 0;
  *C = 0;
  *D = 0;
  if (!surface)
    return;
  try
  {
    Handle(Geom_Plane) p = Handle(Geom_Plane)::DownCast(surface->surface);
    if (p.IsNull())
      return;
    p->Coefficients(*A, *B, *C, *D);
  }
  catch (...)
  {
  }
}

OCCTCurve3DRef OCCTSurfacePlaneUIso(OCCTSurfaceRef surface, double u)
{
  if (!surface)
    return nullptr;
  try
  {
    Handle(Geom_Plane) p = Handle(Geom_Plane)::DownCast(surface->surface);
    if (p.IsNull())
      return nullptr;
    Handle(Geom_Curve) iso = p->UIso(u);
    if (iso.IsNull())
      return nullptr;
    return new OCCTCurve3D(iso);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTSurfacePlaneVIso(OCCTSurfaceRef surface, double v)
{
  if (!surface)
    return nullptr;
  try
  {
    Handle(Geom_Plane) p = Handle(Geom_Plane)::DownCast(surface->surface);
    if (p.IsNull())
      return nullptr;
    Handle(Geom_Curve) iso = p->VIso(v);
    if (iso.IsNull())
      return nullptr;
    return new OCCTCurve3D(iso);
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTSurfacePlanePln(OCCTSurfaceRef surface,
                         double*        px,
                         double*        py,
                         double*        pz,
                         double*        nx,
                         double*        ny,
                         double*        nz)
{
  *px = 0;
  *py = 0;
  *pz = 0;
  *nx = 0;
  *ny = 0;
  *nz = 0;
  if (!surface)
    return;
  try
  {
    Handle(Geom_Plane) p = Handle(Geom_Plane)::DownCast(surface->surface);
    if (p.IsNull())
      return;
    gp_Pln pln  = p->Pln();
    gp_Pnt loc  = pln.Location();
    gp_Dir norm = pln.Axis().Direction();
    *px         = loc.X();
    *py         = loc.Y();
    *pz         = loc.Z();
    *nx         = norm.X();
    *ny         = norm.Y();
    *nz         = norm.Z();
  }
  catch (...)
  {
  }
}

double OCCTSurfaceSphereRadius(OCCTSurfaceRef surface)
{
  if (!surface)
    return 0;
  try
  {
    Handle(Geom_SphericalSurface) s = Handle(Geom_SphericalSurface)::DownCast(surface->surface);
    if (s.IsNull())
      return 0;
    return s->Radius();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTSurfaceSphereSetRadius(OCCTSurfaceRef surface, double radius)
{
  if (!surface)
    return false;
  try
  {
    Handle(Geom_SphericalSurface) s = Handle(Geom_SphericalSurface)::DownCast(surface->surface);
    if (s.IsNull())
      return false;
    s->SetRadius(radius);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

double OCCTSurfaceSphereArea(OCCTSurfaceRef surface)
{
  if (!surface)
    return 0;
  try
  {
    Handle(Geom_SphericalSurface) s = Handle(Geom_SphericalSurface)::DownCast(surface->surface);
    if (s.IsNull())
      return 0;
    return s->Area();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTSurfaceSphereVolume(OCCTSurfaceRef surface)
{
  if (!surface)
    return 0;
  try
  {
    Handle(Geom_SphericalSurface) s = Handle(Geom_SphericalSurface)::DownCast(surface->surface);
    if (s.IsNull())
      return 0;
    return s->Volume();
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTSurfaceSphereCenter(OCCTSurfaceRef surface, double* x, double* y, double* z)
{
  *x = 0;
  *y = 0;
  *z = 0;
  if (!surface)
    return;
  try
  {
    Handle(Geom_SphericalSurface) s = Handle(Geom_SphericalSurface)::DownCast(surface->surface);
    if (s.IsNull())
      return;
    gp_Pnt c = s->Sphere().Location();
    *x       = c.X();
    *y       = c.Y();
    *z       = c.Z();
  }
  catch (...)
  {
  }
}

OCCTCurve3DRef OCCTSurfaceSphereUIso(OCCTSurfaceRef surface, double u)
{
  if (!surface)
    return nullptr;
  try
  {
    Handle(Geom_SphericalSurface) s = Handle(Geom_SphericalSurface)::DownCast(surface->surface);
    if (s.IsNull())
      return nullptr;
    Handle(Geom_Curve) iso = s->UIso(u);
    if (iso.IsNull())
      return nullptr;
    return new OCCTCurve3D(iso);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTSurfaceSphereVIso(OCCTSurfaceRef surface, double v)
{
  if (!surface)
    return nullptr;
  try
  {
    Handle(Geom_SphericalSurface) s = Handle(Geom_SphericalSurface)::DownCast(surface->surface);
    if (s.IsNull())
      return nullptr;
    Handle(Geom_Curve) iso = s->VIso(v);
    if (iso.IsNull())
      return nullptr;
    return new OCCTCurve3D(iso);
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTSurfaceSphereSphere(OCCTSurfaceRef surface,
                             double*        cx,
                             double*        cy,
                             double*        cz,
                             double*        radius)
{
  *cx     = 0;
  *cy     = 0;
  *cz     = 0;
  *radius = 0;
  if (!surface)
    return;
  try
  {
    Handle(Geom_SphericalSurface) s = Handle(Geom_SphericalSurface)::DownCast(surface->surface);
    if (s.IsNull())
      return;
    gp_Sphere sph = s->Sphere();
    gp_Pnt    c   = sph.Location();
    *cx           = c.X();
    *cy           = c.Y();
    *cz           = c.Z();
    *radius       = sph.Radius();
  }
  catch (...)
  {
  }
}

double OCCTSurfaceTorusMajorRadius(OCCTSurfaceRef surface)
{
  if (!surface)
    return 0;
  try
  {
    Handle(Geom_ToroidalSurface) t = Handle(Geom_ToroidalSurface)::DownCast(surface->surface);
    if (t.IsNull())
      return 0;
    return t->MajorRadius();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTSurfaceTorusMinorRadius(OCCTSurfaceRef surface)
{
  if (!surface)
    return 0;
  try
  {
    Handle(Geom_ToroidalSurface) t = Handle(Geom_ToroidalSurface)::DownCast(surface->surface);
    if (t.IsNull())
      return 0;
    return t->MinorRadius();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTSurfaceTorusSetMajorRadius(OCCTSurfaceRef surface, double r)
{
  if (!surface)
    return false;
  try
  {
    Handle(Geom_ToroidalSurface) t = Handle(Geom_ToroidalSurface)::DownCast(surface->surface);
    if (t.IsNull())
      return false;
    t->SetMajorRadius(r);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceTorusSetMinorRadius(OCCTSurfaceRef surface, double r)
{
  if (!surface)
    return false;
  try
  {
    Handle(Geom_ToroidalSurface) t = Handle(Geom_ToroidalSurface)::DownCast(surface->surface);
    if (t.IsNull())
      return false;
    t->SetMinorRadius(r);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

double OCCTSurfaceTorusArea(OCCTSurfaceRef surface)
{
  if (!surface)
    return 0;
  try
  {
    Handle(Geom_ToroidalSurface) t = Handle(Geom_ToroidalSurface)::DownCast(surface->surface);
    if (t.IsNull())
      return 0;
    return t->Area();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTSurfaceTorusVolume(OCCTSurfaceRef surface)
{
  if (!surface)
    return 0;
  try
  {
    Handle(Geom_ToroidalSurface) t = Handle(Geom_ToroidalSurface)::DownCast(surface->surface);
    if (t.IsNull())
      return 0;
    return t->Volume();
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTSurfaceTorusAxis(OCCTSurfaceRef surface,
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
  *dz = 1;
  if (!surface)
    return;
  try
  {
    Handle(Geom_ToroidalSurface) t = Handle(Geom_ToroidalSurface)::DownCast(surface->surface);
    if (t.IsNull())
      return;
    gp_Ax1        a = t->Axis();
    const gp_Pnt& p = a.Location();
    const gp_Dir& d = a.Direction();
    *px             = p.X();
    *py             = p.Y();
    *pz             = p.Z();
    *dx             = d.X();
    *dy             = d.Y();
    *dz             = d.Z();
  }
  catch (...)
  {
  }
}

void OCCTSurfaceRevolutionAxis(OCCTSurfaceRef surface,
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
  *dz = 1;
  if (!surface)
    return;
  try
  {
    Handle(Geom_SurfaceOfRevolution) r =
      Handle(Geom_SurfaceOfRevolution)::DownCast(surface->surface);
    if (r.IsNull())
      return;
    gp_Ax1        a = r->Axis();
    const gp_Pnt& p = a.Location();
    const gp_Dir& d = a.Direction();
    *px             = p.X();
    *py             = p.Y();
    *pz             = p.Z();
    *dx             = d.X();
    *dy             = d.Y();
    *dz             = d.Z();
  }
  catch (...)
  {
  }
}

void OCCTSurfaceRevolutionLocation(OCCTSurfaceRef surface, double* x, double* y, double* z)
{
  *x = 0;
  *y = 0;
  *z = 0;
  if (!surface)
    return;
  try
  {
    Handle(Geom_SurfaceOfRevolution) r =
      Handle(Geom_SurfaceOfRevolution)::DownCast(surface->surface);
    if (r.IsNull())
      return;
    gp_Pnt p = r->Location();
    *x       = p.X();
    *y       = p.Y();
    *z       = p.Z();
  }
  catch (...)
  {
  }
}

double OCCTSurfaceCylinderRadius(OCCTSurfaceRef surface)
{
  if (!surface)
    return 0;
  try
  {
    Handle(Geom_CylindricalSurface) c = Handle(Geom_CylindricalSurface)::DownCast(surface->surface);
    if (c.IsNull())
      return 0;
    return c->Radius();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTSurfaceCylinderSetRadius(OCCTSurfaceRef surface, double r)
{
  if (!surface)
    return false;
  try
  {
    Handle(Geom_CylindricalSurface) c = Handle(Geom_CylindricalSurface)::DownCast(surface->surface);
    if (c.IsNull())
      return false;
    c->SetRadius(r);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTSurfaceCylinderAxis(OCCTSurfaceRef surface,
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
  if (!surface)
    return;
  try
  {
    Handle(Geom_CylindricalSurface) c = Handle(Geom_CylindricalSurface)::DownCast(surface->surface);
    if (c.IsNull())
      return;
    gp_Ax1 ax = c->Cylinder().Axis();
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

OCCTCurve3DRef OCCTSurfaceCylinderUIso(OCCTSurfaceRef surface, double u)
{
  if (!surface)
    return nullptr;
  try
  {
    Handle(Geom_CylindricalSurface) c = Handle(Geom_CylindricalSurface)::DownCast(surface->surface);
    if (c.IsNull())
      return nullptr;
    Handle(Geom_Curve) iso = c->UIso(u);
    if (iso.IsNull())
      return nullptr;
    return new OCCTCurve3D(iso);
  }
  catch (...)
  {
    return nullptr;
  }
}

double OCCTSurfaceConeSemiAngle(OCCTSurfaceRef surface)
{
  if (!surface)
    return 0;
  try
  {
    Handle(Geom_ConicalSurface) c = Handle(Geom_ConicalSurface)::DownCast(surface->surface);
    if (c.IsNull())
      return 0;
    return c->SemiAngle();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTSurfaceConeRefRadius(OCCTSurfaceRef surface)
{
  if (!surface)
    return 0;
  try
  {
    Handle(Geom_ConicalSurface) c = Handle(Geom_ConicalSurface)::DownCast(surface->surface);
    if (c.IsNull())
      return 0;
    return c->RefRadius();
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTSurfaceConeApex(OCCTSurfaceRef surface, double* x, double* y, double* z)
{
  *x = 0;
  *y = 0;
  *z = 0;
  if (!surface)
    return;
  try
  {
    Handle(Geom_ConicalSurface) c = Handle(Geom_ConicalSurface)::DownCast(surface->surface);
    if (c.IsNull())
      return;
    gp_Pnt a = c->Apex();
    *x       = a.X();
    *y       = a.Y();
    *z       = a.Z();
  }
  catch (...)
  {
  }
}

void OCCTSurfaceConeAxis(OCCTSurfaceRef surface,
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
  if (!surface)
    return;
  try
  {
    Handle(Geom_ConicalSurface) c = Handle(Geom_ConicalSurface)::DownCast(surface->surface);
    if (c.IsNull())
      return;
    gp_Ax1 ax = c->Cone().Axis();
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

void OCCTSurfaceSweptDirection(OCCTSurfaceRef surface, double* dx, double* dy, double* dz)
{
  *dx = 0;
  *dy = 0;
  *dz = 0;
  if (!surface)
    return;
  try
  {
    Handle(Geom_SweptSurface) sw = Handle(Geom_SweptSurface)::DownCast(surface->surface);
    if (sw.IsNull())
      return;
    gp_Dir d = sw->Direction();
    *dx      = d.X();
    *dy      = d.Y();
    *dz      = d.Z();
  }
  catch (...)
  {
  }
}

OCCTCurve3DRef OCCTSurfaceSweptBasisCurve(OCCTSurfaceRef surface)
{
  if (!surface)
    return nullptr;
  try
  {
    Handle(Geom_SweptSurface) sw = Handle(Geom_SweptSurface)::DownCast(surface->surface);
    if (sw.IsNull())
      return nullptr;
    Handle(Geom_Curve) basis = sw->BasisCurve();
    if (basis.IsNull())
      return nullptr;
    return new OCCTCurve3D(basis);
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTSurfaceBounds(OCCTSurfaceRef surface,
                       double*        uMin,
                       double*        uMax,
                       double*        vMin,
                       double*        vMax)
{
  *uMin = 0;
  *uMax = 0;
  *vMin = 0;
  *vMax = 0;
  if (!surface || surface->surface.IsNull())
    return; // #478
  try
  {
    surface->surface->Bounds(*uMin, *uMax, *vMin, *vMax);
  }
  catch (...)
  {
  }
}

// Delegates to OCCTSurfaceGetContinuity: same Continuity() call, one encoding (#485).
int32_t OCCTSurfaceContinuity(OCCTSurfaceRef surface)
{
  return OCCTSurfaceGetContinuity(surface);
}

OCCTSurfaceRef OCCTSurfaceCopy(OCCTSurfaceRef surface)
{
  if (!surface || surface->surface.IsNull())
    return nullptr; // #478
  try
  {
    Handle(Geom_Surface) copy = Handle(Geom_Surface)::DownCast(surface->surface->Copy());
    if (copy.IsNull())
      return nullptr;
    return new OCCTSurface(copy);
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTSurfaceEvalD0(OCCTSurfaceRef surface, double u, double v, double* x, double* y, double* z)
{
  *x = 0;
  *y = 0;
  *z = 0;
  if (!surface || surface->surface.IsNull())
    return;
  try
  {
    gp_Pnt p = surface->surface->EvalD0(u, v);
    *x       = p.X();
    *y       = p.Y();
    *z       = p.Z();
  }
  catch (...)
  {
  }
}

void OCCTSurfaceEvalD1(OCCTSurfaceRef surface,
                       double         u,
                       double         v,
                       double*        px,
                       double*        py,
                       double*        pz,
                       double*        d1ux,
                       double*        d1uy,
                       double*        d1uz,
                       double*        d1vx,
                       double*        d1vy,
                       double*        d1vz)
{
  *px   = 0;
  *py   = 0;
  *pz   = 0;
  *d1ux = 0;
  *d1uy = 0;
  *d1uz = 0;
  *d1vx = 0;
  *d1vy = 0;
  *d1vz = 0;
  if (!surface || surface->surface.IsNull())
    return;
  try
  {
    Geom_Surface::ResD1 r = surface->surface->EvalD1(u, v);
    *px                   = r.Point.X();
    *py                   = r.Point.Y();
    *pz                   = r.Point.Z();
    *d1ux                 = r.D1U.X();
    *d1uy                 = r.D1U.Y();
    *d1uz                 = r.D1U.Z();
    *d1vx                 = r.D1V.X();
    *d1vy                 = r.D1V.Y();
    *d1vz                 = r.D1V.Z();
  }
  catch (...)
  {
  }
}

void OCCTSurfaceEvalD2(OCCTSurfaceRef surface,
                       double         u,
                       double         v,
                       double*        px,
                       double*        py,
                       double*        pz,
                       double*        d1ux,
                       double*        d1uy,
                       double*        d1uz,
                       double*        d1vx,
                       double*        d1vy,
                       double*        d1vz,
                       double*        d2ux,
                       double*        d2uy,
                       double*        d2uz,
                       double*        d2vx,
                       double*        d2vy,
                       double*        d2vz,
                       double*        d2uvx,
                       double*        d2uvy,
                       double*        d2uvz)
{
  *px    = 0;
  *py    = 0;
  *pz    = 0;
  *d1ux  = 0;
  *d1uy  = 0;
  *d1uz  = 0;
  *d1vx  = 0;
  *d1vy  = 0;
  *d1vz  = 0;
  *d2ux  = 0;
  *d2uy  = 0;
  *d2uz  = 0;
  *d2vx  = 0;
  *d2vy  = 0;
  *d2vz  = 0;
  *d2uvx = 0;
  *d2uvy = 0;
  *d2uvz = 0;
  if (!surface || surface->surface.IsNull())
    return;
  try
  {
    Geom_Surface::ResD2 r = surface->surface->EvalD2(u, v);
    *px                   = r.Point.X();
    *py                   = r.Point.Y();
    *pz                   = r.Point.Z();
    *d1ux                 = r.D1U.X();
    *d1uy                 = r.D1U.Y();
    *d1uz                 = r.D1U.Z();
    *d1vx                 = r.D1V.X();
    *d1vy                 = r.D1V.Y();
    *d1vz                 = r.D1V.Z();
    *d2ux                 = r.D2U.X();
    *d2uy                 = r.D2U.Y();
    *d2uz                 = r.D2U.Z();
    *d2vx                 = r.D2V.X();
    *d2vy                 = r.D2V.Y();
    *d2vz                 = r.D2V.Z();
    *d2uvx                = r.D2UV.X();
    *d2uvy                = r.D2UV.Y();
    *d2uvz                = r.D2UV.Z();
  }
  catch (...)
  {
  }
}

OCCTProjOnSurfRef OCCTProjOnSurfCreate(OCCTSurfaceRef surface, double px, double py, double pz)
{
  if (!surface || surface->surface.IsNull())
    return nullptr;
  try
  {
    auto ref = new OCCTProjOnSurf();
    ref->proj.Init(gp_Pnt(px, py, pz), surface->surface);
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTProjOnSurfRelease(OCCTProjOnSurfRef proj)
{
  delete proj;
}

int32_t OCCTProjOnSurfNbPoints(OCCTProjOnSurfRef proj)
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

void OCCTProjOnSurfPoint(OCCTProjOnSurfRef proj, int32_t index, double* x, double* y, double* z)
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

void OCCTProjOnSurfParameters(OCCTProjOnSurfRef proj, int32_t index, double* u, double* v)
{
  if (!proj)
  {
    *u = *v = 0;
    return;
  }
  try
  {
    proj->proj.Parameters(index, *u, *v);
  }
  catch (...)
  {
    *u = *v = 0;
  }
}

double OCCTProjOnSurfDistance(OCCTProjOnSurfRef proj, int32_t index)
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

double OCCTProjOnSurfLowerDistance(OCCTProjOnSurfRef proj)
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

void OCCTProjOnSurfLowerParams(OCCTProjOnSurfRef proj, double* u, double* v)
{
  if (!proj)
  {
    *u = *v = 0;
    return;
  }
  try
  {
    proj->proj.LowerDistanceParameters(*u, *v);
  }
  catch (...)
  {
    *u = *v = 0;
  }
}

OCCTIntCSRef OCCTIntCSCreate(OCCTCurve3DRef curve, OCCTSurfaceRef surface)
{
  if (!curve || curve->curve.IsNull() || !surface || surface->surface.IsNull())
    return nullptr;
  try
  {
    auto ref = new OCCTIntCS();
    ref->intcs.Perform(curve->curve, surface->surface);
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTIntCSRelease(OCCTIntCSRef intcs)
{
  delete intcs;
}

int32_t OCCTIntCSNbPoints(OCCTIntCSRef intcs)
{
  if (!intcs)
    return 0;
  try
  {
    return (int32_t)intcs->intcs.NbPoints();
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTIntCSPoint(OCCTIntCSRef intcs,
                    int32_t      index,
                    double*      x,
                    double*      y,
                    double*      z,
                    double*      w,
                    double*      u,
                    double*      v)
{
  if (!intcs)
  {
    *x = *y = *z = *w = *u = *v = 0;
    return;
  }
  try
  {
    gp_Pnt p = intcs->intcs.Point(index);
    *x       = p.X();
    *y       = p.Y();
    *z       = p.Z();
    intcs->intcs.Parameters(index, *u, *v, *w);
  }
  catch (...)
  {
    *x = *y = *z = *w = *u = *v = 0;
  }
}

int32_t OCCTIntCSNbSegments(OCCTIntCSRef intcs)
{
  if (!intcs)
    return 0;
  try
  {
    return (int32_t)intcs->intcs.NbSegments();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTSurfaceBSplineSetUKnot(OCCTSurfaceRef surface, int32_t index, double knot)
{
  if (!surface || surface->surface.IsNull())
    return false;
  try
  {
    Handle(Geom_BSplineSurface) bss = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bss.IsNull())
      return false;
    bss->SetUKnot(index, knot);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBSplineSetVKnot(OCCTSurfaceRef surface, int32_t index, double knot)
{
  if (!surface || surface->surface.IsNull())
    return false;
  try
  {
    Handle(Geom_BSplineSurface) bss = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bss.IsNull())
      return false;
    bss->SetVKnot(index, knot);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTSurfaceBSplineGetUKnots(OCCTSurfaceRef surface, double* knots)
{
  if (!surface || surface->surface.IsNull())
    return;
  try
  {
    Handle(Geom_BSplineSurface) bss = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bss.IsNull())
      return;
    TColStd_Array1OfReal k(1, bss->NbUKnots());
    bss->UKnots(k);
    for (int i = 1; i <= k.Length(); i++)
      knots[i - 1] = k(i);
  }
  catch (...)
  {
  }
}

void OCCTSurfaceBSplineGetVKnots(OCCTSurfaceRef surface, double* knots)
{
  if (!surface || surface->surface.IsNull())
    return;
  try
  {
    Handle(Geom_BSplineSurface) bss = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bss.IsNull())
      return;
    TColStd_Array1OfReal k(1, bss->NbVKnots());
    bss->VKnots(k);
    for (int i = 1; i <= k.Length(); i++)
      knots[i - 1] = k(i);
  }
  catch (...)
  {
  }
}

void OCCTSurfaceBSplineGetWeights(OCCTSurfaceRef surface,
                                  double*        weights,
                                  int32_t*       rows,
                                  int32_t*       cols)
{
  if (!surface || surface->surface.IsNull())
  {
    *rows = *cols = 0;
    return;
  }
  try
  {
    Handle(Geom_BSplineSurface) bss = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bss.IsNull())
    {
      *rows = *cols = 0;
      return;
    }
    int nr = bss->NbUPoles(), nc = bss->NbVPoles();
    *rows = nr;
    *cols = nc;
    TColStd_Array2OfReal w(1, nr, 1, nc);
    bss->Weights(w);
    int idx = 0;
    for (int i = 1; i <= nr; i++)
      for (int j = 1; j <= nc; j++)
        weights[idx++] = w(i, j);
  }
  catch (...)
  {
    *rows = *cols = 0;
  }
}

bool OCCTSurfaceBSplineRemoveUKnot(OCCTSurfaceRef surface, int32_t index, int32_t mult, double tol)
{
  if (!surface || surface->surface.IsNull())
    return false;
  try
  {
    Handle(Geom_BSplineSurface) bss = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bss.IsNull())
      return false;
    return bss->RemoveUKnot(index, mult, tol);
  }
  catch (...)
  {
    return false;
  }
}

void OCCTSurfaceDN(OCCTSurfaceRef surface,
                   double         u,
                   double         v,
                   int32_t        nu,
                   int32_t        nv,
                   double*        x,
                   double*        y,
                   double*        z)
{
  if (!surface || surface->surface.IsNull())
  {
    *x = *y = *z = 0;
    return;
  }
  try
  {
    gp_Vec vec = surface->surface->DN(u, v, nu, nv);
    *x         = vec.X();
    *y         = vec.Y();
    *z         = vec.Z();
  }
  catch (...)
  {
    *x = *y = *z = 0;
  }
}

const char* OCCTSurfaceTypeName(OCCTSurfaceRef surface)
{
  if (!surface || surface->surface.IsNull())
    return nullptr;
  try
  {
    return surface->surface->DynamicType()->Name();
  }
  catch (...)
  {
    return nullptr;
  }
}

// Non-optional-return counterpart of OCCTSurfaceGetNormal. It keeps its own contract, a
// zero vector where the normal is undefined, since the Swift wrapper returns a plain
// SIMD3, but delegates the computation so the two entry points cannot disagree about
// *where* the normal is undefined. It used to hand-roll D1 + gp_Vec::Crossed against a
// literal 1e-15 magnitude epsilon, which classified degeneracy differently from
// GeomLProp_SLProps::IsNormalDefined() near a singularity (#401).
void OCCTSurfaceNormal(OCCTSurfaceRef surface,
                       double         u,
                       double         v,
                       double*        nx,
                       double*        ny,
                       double*        nz)
{
  if (!nx || !ny || !nz)
    return;
  *nx = *ny = *nz = 0;
  OCCTSurfaceGetNormal(surface, u, v, nx, ny, nz);
}

// #595: the pair form reports definedness too. Its documented contract is that it agrees with
// OCCTSurfaceGetGaussianCurvature / GetMeanCurvature "including on whether curvature is defined at
// all", which it could not do while the only thing it returned was a pair of doubles.
bool OCCTSurfaceCurvatures(OCCTSurfaceRef surface,
                           double         u,
                           double         v,
                           double*        gaussian,
                           double*        mean)
{
  if (!gaussian || !mean)
    return false;
  *gaussian = *mean = 0;
  return occtSurfaceCurvaturePair(surface, u, v, gaussian, mean);
}

// MARK: - v0.116: Surface Local Curvatures + Curvature Directions
//
// These two report the same GeomLProp_SLProps quantities as OCCTSurfaceCurvatures /
// OCCTSurfaceGetGaussianCurvature / OCCTSurfaceGetMeanCurvature / OCCTSurfaceGetPrincipalCurvatures
// above, differing only in returning all four curvature scalars (or both directions) in one call.
// They used to construct their props with a hardcoded 1e-10 rather than the shared resolution, so
// they disagreed with every one of those siblings about whether curvature exists at all near a
// degeneracy, reporting a defined mean curvature of -8.66e7 at a point on a cone the canonical
// entry points called undefined. Both now build props through occtSurfaceLocalProps (#494).
void OCCTSurfaceLocalCurvatures(OCCTSurfaceRef _Nonnull surface,
                                double u,
                                double v,
                                double* _Nonnull gaussian,
                                double* _Nonnull mean,
                                double* _Nonnull maxCurvature,
                                double* _Nonnull minCurvature,
                                bool* _Nonnull isDefined)
{
  if (surface->surface.IsNull())
  {
    *isDefined    = false;
    *gaussian     = 0;
    *mean         = 0;
    *maxCurvature = 0;
    *minCurvature = 0;
    return;
  }
  try
  {
    GeomLProp_SLProps props = occtSurfaceLocalProps(surface->surface, u, v, 2);
    *isDefined              = props.IsCurvatureDefined();
    if (*isDefined)
    {
      *gaussian     = props.GaussianCurvature();
      *mean         = props.MeanCurvature();
      *maxCurvature = props.MaxCurvature();
      *minCurvature = props.MinCurvature();
    }
    else
    {
      *gaussian     = 0;
      *mean         = 0;
      *maxCurvature = 0;
      *minCurvature = 0;
    }
  }
  catch (...)
  {
    *isDefined    = false;
    *gaussian     = 0;
    *mean         = 0;
    *maxCurvature = 0;
    *minCurvature = 0;
  }
}

void OCCTSurfaceLocalCurvatureDirections(OCCTSurfaceRef _Nonnull surface,
                                         double u,
                                         double v,
                                         double* _Nonnull maxDx,
                                         double* _Nonnull maxDy,
                                         double* _Nonnull maxDz,
                                         double* _Nonnull minDx,
                                         double* _Nonnull minDy,
                                         double* _Nonnull minDz,
                                         bool* _Nonnull isDefined)
{
  if (surface->surface.IsNull())
  {
    *isDefined = false;
    *maxDx     = 0;
    *maxDy     = 0;
    *maxDz     = 0;
    *minDx     = 0;
    *minDy     = 0;
    *minDz     = 0;
    return;
  }
  try
  {
    GeomLProp_SLProps props = occtSurfaceLocalProps(surface->surface, u, v, 2);
    *isDefined              = props.IsCurvatureDefined() && !props.IsUmbilic();
    if (*isDefined)
    {
      gp_Dir maxD, minD;
      props.CurvatureDirections(maxD, minD);
      *maxDx = maxD.X();
      *maxDy = maxD.Y();
      *maxDz = maxD.Z();
      *minDx = minD.X();
      *minDy = minD.Y();
      *minDz = minD.Z();
    }
    else
    {
      *maxDx = 0;
      *maxDy = 0;
      *maxDz = 0;
      *minDx = 0;
      *minDy = 0;
      *minDz = 0;
    }
  }
  catch (...)
  {
    *isDefined = false;
    *maxDx     = 0;
    *maxDy     = 0;
    *maxDz     = 0;
    *minDx     = 0;
    *minDy     = 0;
    *minDz     = 0;
  }
}

int32_t OCCTSurfaceBezierNbUPoles(OCCTSurfaceRef surface)
{
  try
  {
    auto* s      = static_cast<OCCTSurface*>(surface);
    auto  bezier = occ::handle<Geom_BezierSurface>::DownCast(s->surface);
    if (bezier.IsNull())
      return 0;
    return (int32_t)bezier->NbUPoles();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTSurfaceBezierNbVPoles(OCCTSurfaceRef surface)
{
  try
  {
    auto* s      = static_cast<OCCTSurface*>(surface);
    auto  bezier = occ::handle<Geom_BezierSurface>::DownCast(s->surface);
    if (bezier.IsNull())
      return 0;
    return (int32_t)bezier->NbVPoles();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTSurfaceBezierUDegree(OCCTSurfaceRef surface)
{
  try
  {
    auto* s      = static_cast<OCCTSurface*>(surface);
    auto  bezier = occ::handle<Geom_BezierSurface>::DownCast(s->surface);
    if (bezier.IsNull())
      return -1;
    return (int32_t)bezier->UDegree();
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTSurfaceBezierVDegree(OCCTSurfaceRef surface)
{
  try
  {
    auto* s      = static_cast<OCCTSurface*>(surface);
    auto  bezier = occ::handle<Geom_BezierSurface>::DownCast(s->surface);
    if (bezier.IsNull())
      return -1;
    return (int32_t)bezier->VDegree();
  }
  catch (...)
  {
    return -1;
  }
}

void OCCTSurfaceBezierGetPole(OCCTSurfaceRef surface,
                              int32_t        uIndex,
                              int32_t        vIndex,
                              double*        x,
                              double*        y,
                              double*        z)
{
  try
  {
    auto* s      = static_cast<OCCTSurface*>(surface);
    auto  bezier = occ::handle<Geom_BezierSurface>::DownCast(s->surface);
    if (bezier.IsNull())
    {
      *x = *y = *z = 0;
      return;
    }
    gp_Pnt p = bezier->Pole(uIndex, vIndex);
    *x       = p.X();
    *y       = p.Y();
    *z       = p.Z();
  }
  catch (...)
  {
    *x = *y = *z = 0;
  }
}

bool OCCTSurfaceBezierSetPole(OCCTSurfaceRef surface,
                              int32_t        uIndex,
                              int32_t        vIndex,
                              double         x,
                              double         y,
                              double         z)
{
  try
  {
    auto* s      = static_cast<OCCTSurface*>(surface);
    auto  bezier = occ::handle<Geom_BezierSurface>::DownCast(s->surface);
    if (bezier.IsNull())
      return false;
    bezier->SetPole(uIndex, vIndex, gp_Pnt(x, y, z));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBezierSetWeight(OCCTSurfaceRef surface,
                                int32_t        uIndex,
                                int32_t        vIndex,
                                double         weight)
{
  try
  {
    auto* s      = static_cast<OCCTSurface*>(surface);
    auto  bezier = occ::handle<Geom_BezierSurface>::DownCast(s->surface);
    if (bezier.IsNull())
      return false;
    bezier->SetWeight(uIndex, vIndex, weight);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBezierSegment(OCCTSurfaceRef surface, double u1, double u2, double v1, double v2)
{
  try
  {
    auto* s      = static_cast<OCCTSurface*>(surface);
    auto  bezier = occ::handle<Geom_BezierSurface>::DownCast(s->surface);
    if (bezier.IsNull())
      return false;
    bezier->Segment(u1, u2, v1, v2);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBezierIsURational(OCCTSurfaceRef surface)
{
  try
  {
    auto* s      = static_cast<OCCTSurface*>(surface);
    auto  bezier = occ::handle<Geom_BezierSurface>::DownCast(s->surface);
    if (bezier.IsNull())
      return false;
    return bezier->IsURational();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBezierIsVRational(OCCTSurfaceRef surface)
{
  try
  {
    auto* s      = static_cast<OCCTSurface*>(surface);
    auto  bezier = occ::handle<Geom_BezierSurface>::DownCast(s->surface);
    if (bezier.IsNull())
      return false;
    return bezier->IsVRational();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBezierExchangeUV(OCCTSurfaceRef surface)
{
  try
  {
    auto* s      = static_cast<OCCTSurface*>(surface);
    auto  bezier = occ::handle<Geom_BezierSurface>::DownCast(s->surface);
    if (bezier.IsNull())
      return false;
    bezier->ExchangeUV();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTSurfaceBSplineResolution(OCCTSurfaceRef surface,
                                  double         tolerance3d,
                                  double*        uResolution,
                                  double*        vResolution)
{
  try
  {
    auto* s   = static_cast<OCCTSurface*>(surface);
    auto  bsp = occ::handle<Geom_BSplineSurface>::DownCast(s->surface);
    if (bsp.IsNull())
    {
      *uResolution = *vResolution = 0;
      return;
    }
    bsp->Resolution(tolerance3d, *uResolution, *vResolution);
  }
  catch (...)
  {
    *uResolution = *vResolution = 0;
  }
}

bool OCCTSurfaceBSplineSetUPeriodic(OCCTSurfaceRef surface, bool periodic)
{
  try
  {
    auto* s   = static_cast<OCCTSurface*>(surface);
    auto  bsp = occ::handle<Geom_BSplineSurface>::DownCast(s->surface);
    if (bsp.IsNull())
      return false;
    if (periodic)
      bsp->SetUPeriodic();
    else
      bsp->SetUNotPeriodic();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBSplineSetVPeriodic(OCCTSurfaceRef surface, bool periodic)
{
  try
  {
    auto* s   = static_cast<OCCTSurface*>(surface);
    auto  bsp = occ::handle<Geom_BSplineSurface>::DownCast(s->surface);
    if (bsp.IsNull())
      return false;
    if (periodic)
      bsp->SetVPeriodic();
    else
      bsp->SetVNotPeriodic();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

double OCCTSurfaceBSplineGetWeight(OCCTSurfaceRef surface, int32_t uIndex, int32_t vIndex)
{
  try
  {
    auto* s   = static_cast<OCCTSurface*>(surface);
    auto  bsp = occ::handle<Geom_BSplineSurface>::DownCast(s->surface);
    if (bsp.IsNull())
      return 0;
    return bsp->Weight(uIndex, vIndex);
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTSurfaceIsCNu(OCCTSurfaceRef _Nonnull surface, int32_t n)
{
  try
  {
    auto s = *(occ::handle<Geom_Surface>*)surface;
    if (s.IsNull())
      return false;
    return s->IsCNu(n);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceIsCNv(OCCTSurfaceRef _Nonnull surface, int32_t n)
{
  try
  {
    auto s = *(occ::handle<Geom_Surface>*)surface;
    if (s.IsNull())
      return false;
    return s->IsCNv(n);
  }
  catch (...)
  {
    return false;
  }
}

OCCTSurfaceRef _Nullable OCCTSurfaceUReversed(OCCTSurfaceRef _Nonnull surface)
{
  try
  {
    auto s = *(occ::handle<Geom_Surface>*)surface;
    if (s.IsNull())
      return nullptr;
    auto rev = s->UReversed();
    if (rev.IsNull())
      return nullptr;
    // Allocate as OCCTSurface, matching every other factory in this file (and what
    // OCCTSurfaceRelease deletes as); a bare occ::handle<Geom_Surface> here was a
    // new/delete type mismatch (#1433).
    return new OCCTSurface(rev);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef _Nullable OCCTSurfaceVReversed(OCCTSurfaceRef _Nonnull surface)
{
  try
  {
    auto s = *(occ::handle<Geom_Surface>*)surface;
    if (s.IsNull())
      return nullptr;
    auto rev = s->VReversed();
    if (rev.IsNull())
      return nullptr;
    // Allocate as OCCTSurface, matching every other factory in this file (and what
    // OCCTSurfaceRelease deletes as); a bare occ::handle<Geom_Surface> here was a
    // new/delete type mismatch (#1433).
    return new OCCTSurface(rev);
  }
  catch (...)
  {
    return nullptr;
  }
}

double OCCTSurfaceUReversedParameter(OCCTSurfaceRef _Nonnull surface, double u)
{
  try
  {
    auto s = *(occ::handle<Geom_Surface>*)surface;
    if (s.IsNull())
      return u;
    return s->UReversedParameter(u);
  }
  catch (...)
  {
    return u;
  }
}

double OCCTSurfaceVReversedParameter(OCCTSurfaceRef _Nonnull surface, double v)
{
  try
  {
    auto s = *(occ::handle<Geom_Surface>*)surface;
    if (s.IsNull())
      return v;
    return s->VReversedParameter(v);
  }
  catch (...)
  {
    return v;
  }
}

bool OCCTSurfaceBSplineRemoveVKnot(OCCTSurfaceRef _Nonnull surface,
                                   int32_t index,
                                   int32_t mult,
                                   double  tol)
{
  try
  {
    auto s = *(occ::handle<Geom_Surface>*)surface;
    if (s.IsNull())
      return false;
    auto bsp = occ::handle<Geom_BSplineSurface>::DownCast(s);
    if (bsp.IsNull())
      return false;
    return bsp->RemoveVKnot(index, mult, tol);
  }
  catch (...)
  {
    return false;
  }
}

void OCCTSurfaceBezierResolution(OCCTSurfaceRef _Nonnull surface,
                                 double tolerance3d,
                                 double* _Nonnull uResolution,
                                 double* _Nonnull vResolution)
{
  try
  {
    auto s = *(occ::handle<Geom_Surface>*)surface;
    if (s.IsNull())
    {
      *uResolution = 0;
      *vResolution = 0;
      return;
    }
    auto bez = occ::handle<Geom_BezierSurface>::DownCast(s);
    if (bez.IsNull())
    {
      *uResolution = 0;
      *vResolution = 0;
      return;
    }
    bez->Resolution(tolerance3d, *uResolution, *vResolution);
  }
  catch (...)
  {
    *uResolution = 0;
    *vResolution = 0;
  }
}

int32_t OCCTSurfaceBezierMaxDegree(void)
{
  return Geom_BezierSurface::MaxDegree();
}

int32_t OCCTSurfaceBSplineMaxDegree(void)
{
  return Geom_BSplineSurface::MaxDegree();
}

bool OCCTSurfaceBSplineSetUNotPeriodic(OCCTSurfaceRef surface)
{
  if (!surface || surface->surface.IsNull())
    return false;
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    bs->SetUNotPeriodic();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBSplineSetVNotPeriodic(OCCTSurfaceRef surface)
{
  if (!surface || surface->surface.IsNull())
    return false;
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    bs->SetVNotPeriodic();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBSplineSetUOrigin(OCCTSurfaceRef surface, int32_t index)
{
  if (!surface || surface->surface.IsNull())
    return false;
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    bs->SetUOrigin(index);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBSplineSetVOrigin(OCCTSurfaceRef surface, int32_t index)
{
  if (!surface || surface->surface.IsNull())
    return false;
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    bs->SetVOrigin(index);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBSplineIncreaseUMultiplicity(OCCTSurfaceRef surface, int32_t index, int32_t mult)
{
  if (!surface || surface->surface.IsNull())
    return false;
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    bs->IncreaseUMultiplicity(index, mult);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBSplineIncreaseVMultiplicity(OCCTSurfaceRef surface, int32_t index, int32_t mult)
{
  if (!surface || surface->surface.IsNull())
    return false;
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    bs->IncreaseVMultiplicity(index, mult);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBSplineInsertUKnots(OCCTSurfaceRef surface,
                                    const double*  knots,
                                    const int32_t* mults,
                                    int32_t        count,
                                    double         tol)
{
  if (!surface || surface->surface.IsNull() || !knots || !mults || count <= 0)
    return false;
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    TColStd_Array1OfReal    kArr(1, count);
    TColStd_Array1OfInteger mArr(1, count);
    for (int32_t i = 0; i < count; i++)
    {
      kArr.SetValue(i + 1, knots[i]);
      mArr.SetValue(i + 1, mults[i]);
    }
    bs->InsertUKnots(kArr, mArr, tol);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBSplineInsertVKnots(OCCTSurfaceRef surface,
                                    const double*  knots,
                                    const int32_t* mults,
                                    int32_t        count,
                                    double         tol)
{
  if (!surface || surface->surface.IsNull() || !knots || !mults || count <= 0)
    return false;
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    TColStd_Array1OfReal    kArr(1, count);
    TColStd_Array1OfInteger mArr(1, count);
    for (int32_t i = 0; i < count; i++)
    {
      kArr.SetValue(i + 1, knots[i]);
      mArr.SetValue(i + 1, mults[i]);
    }
    bs->InsertVKnots(kArr, mArr, tol);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBSplineMovePoint(OCCTSurfaceRef surface,
                                 double         u,
                                 double         v,
                                 double         px,
                                 double         py,
                                 double         pz,
                                 int32_t        uIndex1,
                                 int32_t        uIndex2,
                                 int32_t        vIndex1,
                                 int32_t        vIndex2)
{
  if (!surface || surface->surface.IsNull())
    return false;
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    Standard_Integer uFirstIndex, uLastIndex, vFirstIndex, vLastIndex;
    bs->MovePoint(u,
                  v,
                  gp_Pnt(px, py, pz),
                  uIndex1,
                  uIndex2,
                  vIndex1,
                  vIndex2,
                  uFirstIndex,
                  uLastIndex,
                  vFirstIndex,
                  vLastIndex);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBSplineSetPoleCol(OCCTSurfaceRef surface,
                                  int32_t        vIndex,
                                  const double*  coords,
                                  int32_t        count)
{
  if (!surface || surface->surface.IsNull() || !coords || count <= 0)
    return false;
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    int32_t nUPoles = bs->NbUPoles();
    if (count != nUPoles)
      return false;
    TColgp_Array1OfPnt poles(1, nUPoles);
    for (int32_t i = 0; i < nUPoles; i++)
    {
      poles.SetValue(i + 1, gp_Pnt(coords[i * 3], coords[i * 3 + 1], coords[i * 3 + 2]));
    }
    bs->SetPoleCol(vIndex, poles);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBSplineSetPoleRow(OCCTSurfaceRef surface,
                                  int32_t        uIndex,
                                  const double*  coords,
                                  int32_t        count)
{
  if (!surface || surface->surface.IsNull() || !coords || count <= 0)
    return false;
  Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    int32_t nVPoles = bs->NbVPoles();
    if (count != nVPoles)
      return false;
    TColgp_Array1OfPnt poles(1, nVPoles);
    for (int32_t i = 0; i < nVPoles; i++)
    {
      poles.SetValue(i + 1, gp_Pnt(coords[i * 3], coords[i * 3 + 1], coords[i * 3 + 2]));
    }
    bs->SetPoleRow(uIndex, poles);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

double OCCTSurfaceUPeriod(OCCTSurfaceRef surface)
{
  if (!surface || surface->surface.IsNull())
    return 0.0; // #478
  try
  {
    if (!surface->surface->IsUPeriodic())
      return 0.0;
    return surface->surface->UPeriod();
  }
  catch (...)
  {
    return 0.0;
  }
}

double OCCTSurfaceVPeriod(OCCTSurfaceRef surface)
{
  if (!surface || surface->surface.IsNull())
    return 0.0; // #478
  try
  {
    if (!surface->surface->IsVPeriodic())
      return 0.0;
    return surface->surface->VPeriod();
  }
  catch (...)
  {
    return 0.0;
  }
}

void OCCTSurfaceBSplineLocalD0(OCCTSurfaceRef surface,
                               double         u,
                               double         v,
                               int32_t        fromUK1,
                               int32_t        toUK2,
                               int32_t        fromVK1,
                               int32_t        toVK2,
                               double*        x,
                               double*        y,
                               double*        z)
{
  if (!surface)
    return;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return;
  try
  {
    gp_Pnt P;
    bs->LocalD0(u, v, fromUK1, toUK2, fromVK1, toVK2, P);
    *x = P.X();
    *y = P.Y();
    *z = P.Z();
  }
  catch (...)
  {
  }
}

void OCCTSurfaceBSplineLocalD1(OCCTSurfaceRef surface,
                               double         u,
                               double         v,
                               int32_t        fromUK1,
                               int32_t        toUK2,
                               int32_t        fromVK1,
                               int32_t        toVK2,
                               double*        px,
                               double*        py,
                               double*        pz,
                               double*        d1ux,
                               double*        d1uy,
                               double*        d1uz,
                               double*        d1vx,
                               double*        d1vy,
                               double*        d1vz)
{
  if (!surface)
    return;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return;
  try
  {
    gp_Pnt P;
    gp_Vec D1U, D1V;
    bs->LocalD1(u, v, fromUK1, toUK2, fromVK1, toVK2, P, D1U, D1V);
    *px   = P.X();
    *py   = P.Y();
    *pz   = P.Z();
    *d1ux = D1U.X();
    *d1uy = D1U.Y();
    *d1uz = D1U.Z();
    *d1vx = D1V.X();
    *d1vy = D1V.Y();
    *d1vz = D1V.Z();
  }
  catch (...)
  {
  }
}

void OCCTSurfaceBSplineLocalD2(OCCTSurfaceRef surface,
                               double         u,
                               double         v,
                               int32_t        fromUK1,
                               int32_t        toUK2,
                               int32_t        fromVK1,
                               int32_t        toVK2,
                               double*        px,
                               double*        py,
                               double*        pz,
                               double*        d1ux,
                               double*        d1uy,
                               double*        d1uz,
                               double*        d1vx,
                               double*        d1vy,
                               double*        d1vz,
                               double*        d2ux,
                               double*        d2uy,
                               double*        d2uz,
                               double*        d2vx,
                               double*        d2vy,
                               double*        d2vz,
                               double*        d2uvx,
                               double*        d2uvy,
                               double*        d2uvz)
{
  if (!surface)
    return;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return;
  try
  {
    gp_Pnt P;
    gp_Vec D1U, D1V, D2U, D2V, D2UV;
    bs->LocalD2(u, v, fromUK1, toUK2, fromVK1, toVK2, P, D1U, D1V, D2U, D2V, D2UV);
    *px    = P.X();
    *py    = P.Y();
    *pz    = P.Z();
    *d1ux  = D1U.X();
    *d1uy  = D1U.Y();
    *d1uz  = D1U.Z();
    *d1vx  = D1V.X();
    *d1vy  = D1V.Y();
    *d1vz  = D1V.Z();
    *d2ux  = D2U.X();
    *d2uy  = D2U.Y();
    *d2uz  = D2U.Z();
    *d2vx  = D2V.X();
    *d2vy  = D2V.Y();
    *d2vz  = D2V.Z();
    *d2uvx = D2UV.X();
    *d2uvy = D2UV.Y();
    *d2uvz = D2UV.Z();
  }
  catch (...)
  {
  }
}

void OCCTSurfaceBSplineLocalD3(OCCTSurfaceRef surface,
                               double         u,
                               double         v,
                               int32_t        fromUK1,
                               int32_t        toUK2,
                               int32_t        fromVK1,
                               int32_t        toVK2,
                               double*        px,
                               double*        py,
                               double*        pz,
                               double*        d1ux,
                               double*        d1uy,
                               double*        d1uz,
                               double*        d1vx,
                               double*        d1vy,
                               double*        d1vz,
                               double*        d2ux,
                               double*        d2uy,
                               double*        d2uz,
                               double*        d2vx,
                               double*        d2vy,
                               double*        d2vz,
                               double*        d2uvx,
                               double*        d2uvy,
                               double*        d2uvz,
                               double*        d3ux,
                               double*        d3uy,
                               double*        d3uz,
                               double*        d3vx,
                               double*        d3vy,
                               double*        d3vz,
                               double*        d3uuvx,
                               double*        d3uuvy,
                               double*        d3uuvz,
                               double*        d3uvvx,
                               double*        d3uvvy,
                               double*        d3uvvz)
{
  if (!surface)
    return;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return;
  try
  {
    gp_Pnt P;
    gp_Vec D1U, D1V, D2U, D2V, D2UV, D3U, D3V, D3UUV, D3UVV;
    bs->LocalD3(u,
                v,
                fromUK1,
                toUK2,
                fromVK1,
                toVK2,
                P,
                D1U,
                D1V,
                D2U,
                D2V,
                D2UV,
                D3U,
                D3V,
                D3UUV,
                D3UVV);
    *px     = P.X();
    *py     = P.Y();
    *pz     = P.Z();
    *d1ux   = D1U.X();
    *d1uy   = D1U.Y();
    *d1uz   = D1U.Z();
    *d1vx   = D1V.X();
    *d1vy   = D1V.Y();
    *d1vz   = D1V.Z();
    *d2ux   = D2U.X();
    *d2uy   = D2U.Y();
    *d2uz   = D2U.Z();
    *d2vx   = D2V.X();
    *d2vy   = D2V.Y();
    *d2vz   = D2V.Z();
    *d2uvx  = D2UV.X();
    *d2uvy  = D2UV.Y();
    *d2uvz  = D2UV.Z();
    *d3ux   = D3U.X();
    *d3uy   = D3U.Y();
    *d3uz   = D3U.Z();
    *d3vx   = D3V.X();
    *d3vy   = D3V.Y();
    *d3vz   = D3V.Z();
    *d3uuvx = D3UUV.X();
    *d3uuvy = D3UUV.Y();
    *d3uuvz = D3UUV.Z();
    *d3uvvx = D3UVV.X();
    *d3uvvy = D3UVV.Y();
    *d3uvvz = D3UVV.Z();
  }
  catch (...)
  {
  }
}

void OCCTSurfaceBSplineLocalDN(OCCTSurfaceRef surface,
                               double         u,
                               double         v,
                               int32_t        fromUK1,
                               int32_t        toUK2,
                               int32_t        fromVK1,
                               int32_t        toVK2,
                               int32_t        nu,
                               int32_t        nv,
                               double*        vx,
                               double*        vy,
                               double*        vz)
{
  if (!surface)
    return;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return;
  try
  {
    gp_Vec V = bs->LocalDN(u, v, fromUK1, toUK2, fromVK1, toVK2, nu, nv);
    *vx      = V.X();
    *vy      = V.Y();
    *vz      = V.Z();
  }
  catch (...)
  {
  }
}

void OCCTSurfaceBSplineLocalValue(OCCTSurfaceRef surface,
                                  double         u,
                                  double         v,
                                  int32_t        fromUK1,
                                  int32_t        toUK2,
                                  int32_t        fromVK1,
                                  int32_t        toVK2,
                                  double*        x,
                                  double*        y,
                                  double*        z)
{
  if (!surface)
    return;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return;
  try
  {
    gp_Pnt P = bs->LocalValue(u, v, fromUK1, toUK2, fromVK1, toVK2);
    *x       = P.X();
    *y       = P.Y();
    *z       = P.Z();
  }
  catch (...)
  {
  }
}

OCCTCurve3DRef OCCTSurfaceBSplineUIso(OCCTSurfaceRef surface, double u)
{
  if (!surface)
    return nullptr;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return nullptr;
  try
  {
    auto curve = bs->UIso(u);
    if (curve.IsNull())
      return nullptr;
    auto* ref  = new OCCTCurve3D;
    ref->curve = curve;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTSurfaceBSplineVIso(OCCTSurfaceRef surface, double v)
{
  if (!surface)
    return nullptr;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return nullptr;
  try
  {
    auto curve = bs->VIso(v);
    if (curve.IsNull())
      return nullptr;
    auto* ref  = new OCCTCurve3D;
    ref->curve = curve;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTSurfaceBSplineLocateU(OCCTSurfaceRef surface,
                               double         u,
                               double         paramTol,
                               int32_t*       i1,
                               int32_t*       i2)
{
  if (!surface)
    return;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return;
  try
  {
    int I1 = 0, I2 = 0;
    bs->LocateU(u, paramTol, I1, I2);
    *i1 = I1;
    *i2 = I2;
  }
  catch (...)
  {
  }
}

void OCCTSurfaceBSplineLocateV(OCCTSurfaceRef surface,
                               double         v,
                               double         paramTol,
                               int32_t*       i1,
                               int32_t*       i2)
{
  if (!surface)
    return;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return;
  try
  {
    int I1 = 0, I2 = 0;
    bs->LocateV(v, paramTol, I1, I2);
    *i1 = I1;
    *i2 = I2;
  }
  catch (...)
  {
  }
}

double OCCTSurfaceBSplineUKnot(OCCTSurfaceRef surface, int32_t index)
{
  if (!surface)
    return 0.0;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return 0.0;
  try
  {
    return bs->UKnot(index);
  }
  catch (...)
  {
    return 0.0;
  }
}

double OCCTSurfaceBSplineVKnot(OCCTSurfaceRef surface, int32_t index)
{
  if (!surface)
    return 0.0;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return 0.0;
  try
  {
    return bs->VKnot(index);
  }
  catch (...)
  {
    return 0.0;
  }
}

int32_t OCCTSurfaceBSplineUMultiplicity(OCCTSurfaceRef surface, int32_t index)
{
  if (!surface)
    return 0;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return 0;
  try
  {
    return bs->UMultiplicity(index);
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTSurfaceBSplineVMultiplicity(OCCTSurfaceRef surface, int32_t index)
{
  if (!surface)
    return 0;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return 0;
  try
  {
    return bs->VMultiplicity(index);
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTSurfaceBSplineUKnotDistribution(OCCTSurfaceRef surface)
{
  if (!surface)
    return 0;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return 0;
  try
  {
    return (int32_t)bs->UKnotDistribution();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTSurfaceBSplineVKnotDistribution(OCCTSurfaceRef surface)
{
  if (!surface)
    return 0;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return 0;
  try
  {
    return (int32_t)bs->VKnotDistribution();
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTSurfaceBSplineGetPoles(OCCTSurfaceRef surface, double* poles)
{
  if (!surface || !poles)
    return;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return;
  try
  {
    const auto& p   = bs->Poles();
    int         idx = 0;
    for (int i = p.LowerRow(); i <= p.UpperRow(); i++)
    {
      for (int j = p.LowerCol(); j <= p.UpperCol(); j++)
      {
        const gp_Pnt& pt = p(i, j);
        poles[idx++]     = pt.X();
        poles[idx++]     = pt.Y();
        poles[idx++]     = pt.Z();
      }
    }
  }
  catch (...)
  {
  }
}

void OCCTSurfaceBSplineBounds(OCCTSurfaceRef surface,
                              double*        u1,
                              double*        u2,
                              double*        v1,
                              double*        v2)
{
  if (!surface)
    return;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return;
  try
  {
    bs->Bounds(*u1, *u2, *v1, *v2);
  }
  catch (...)
  {
  }
}

bool OCCTSurfaceBSplineIsUClosed(OCCTSurfaceRef surface)
{
  if (!surface)
    return false;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    return bs->IsUClosed();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBSplineIsVClosed(OCCTSurfaceRef surface)
{
  if (!surface)
    return false;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    return bs->IsVClosed();
  }
  catch (...)
  {
    return false;
  }
}

OCCTCurve3DRef OCCTSurfaceBezierUIso(OCCTSurfaceRef surface, double u)
{
  if (!surface)
    return nullptr;
  auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
  if (bz.IsNull())
    return nullptr;
  try
  {
    auto curve = bz->UIso(u);
    if (curve.IsNull())
      return nullptr;
    auto* ref  = new OCCTCurve3D;
    ref->curve = curve;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTSurfaceBezierVIso(OCCTSurfaceRef surface, double v)
{
  if (!surface)
    return nullptr;
  auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
  if (bz.IsNull())
    return nullptr;
  try
  {
    auto curve = bz->VIso(v);
    if (curve.IsNull())
      return nullptr;
    auto* ref  = new OCCTCurve3D;
    ref->curve = curve;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTSurfaceBezierIsUClosed(OCCTSurfaceRef surface)
{
  if (!surface)
    return false;
  auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
  if (bz.IsNull())
    return false;
  try
  {
    return bz->IsUClosed();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBezierIsVClosed(OCCTSurfaceRef surface)
{
  if (!surface)
    return false;
  auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
  if (bz.IsNull())
    return false;
  try
  {
    return bz->IsVClosed();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBezierIsUPeriodic(OCCTSurfaceRef surface)
{
  if (!surface)
    return false;
  auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
  if (bz.IsNull())
    return false;
  try
  {
    return bz->IsUPeriodic();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBezierIsVPeriodic(OCCTSurfaceRef surface)
{
  if (!surface)
    return false;
  auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
  if (bz.IsNull())
    return false;
  try
  {
    return bz->IsVPeriodic();
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTSurfaceBezierContinuity(OCCTSurfaceRef surface)
{
  if (!surface)
    return 0;
  auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
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

bool OCCTSurfaceBezierIsCNu(OCCTSurfaceRef surface, int32_t n)
{
  if (!surface)
    return false;
  auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
  if (bz.IsNull())
    return false;
  try
  {
    return bz->IsCNu(n);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBezierIsCNv(OCCTSurfaceRef surface, int32_t n)
{
  if (!surface)
    return false;
  auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
  if (bz.IsNull())
    return false;
  try
  {
    return bz->IsCNv(n);
  }
  catch (...)
  {
    return false;
  }
}

void OCCTSurfaceBezierGetPoles(OCCTSurfaceRef surface, double* poles)
{
  if (!surface || !poles)
    return;
  auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
  if (bz.IsNull())
    return;
  try
  {
    const auto& p   = bz->Poles();
    int         idx = 0;
    for (int i = p.LowerRow(); i <= p.UpperRow(); i++)
    {
      for (int j = p.LowerCol(); j <= p.UpperCol(); j++)
      {
        const gp_Pnt& pt = p(i, j);
        poles[idx++]     = pt.X();
        poles[idx++]     = pt.Y();
        poles[idx++]     = pt.Z();
      }
    }
  }
  catch (...)
  {
  }
}

bool OCCTSurfaceBezierGetWeights(OCCTSurfaceRef surface, double* weights)
{
  if (!surface || !weights)
    return false;
  auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
  if (bz.IsNull())
    return false;
  try
  {
    const auto* w = bz->Weights();
    if (!w)
      return false;
    int idx = 0;
    for (int i = w->LowerRow(); i <= w->UpperRow(); i++)
    {
      for (int j = w->LowerCol(); j <= w->UpperCol(); j++)
      {
        weights[idx++] = (*w)(i, j);
      }
    }
    return true;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTSurfaceBezierBounds(OCCTSurfaceRef surface, double* u1, double* u2, double* v1, double* v2)
{
  if (!surface)
    return;
  auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
  if (bz.IsNull())
    return;
  try
  {
    bz->Bounds(*u1, *u2, *v1, *v2);
  }
  catch (...)
  {
  }
}

void OCCTSurfaceBSplineGetUMultiplicities(OCCTSurfaceRef surface, int32_t* mults)
{
  if (!surface || !mults)
    return;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return;
  try
  {
    int n = bs->NbUKnots();
    for (int i = 1; i <= n; i++)
    {
      mults[i - 1] = bs->UMultiplicity(i);
    }
  }
  catch (...)
  {
  }
}

void OCCTSurfaceBSplineGetVMultiplicities(OCCTSurfaceRef surface, int32_t* mults)
{
  if (!surface || !mults)
    return;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return;
  try
  {
    int n = bs->NbVKnots();
    for (int i = 1; i <= n; i++)
    {
      mults[i - 1] = bs->VMultiplicity(i);
    }
  }
  catch (...)
  {
  }
}

bool OCCTSurfaceBSplineUReverse(OCCTSurfaceRef surface)
{
  if (!surface)
    return false;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    bs->UReverse();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBSplineVReverse(OCCTSurfaceRef surface)
{
  if (!surface)
    return false;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    bs->VReverse();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBSplinePeriodicNormalization(OCCTSurfaceRef surface, double* u, double* v)
{
  if (!surface)
    return false;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    bs->PeriodicNormalization(*u, *v);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBezierInsertPoleColAfter(OCCTSurfaceRef surface,
                                         int32_t        colIndex,
                                         const double*  poles,
                                         int32_t        poleCount)
{
  if (!surface || !poles)
    return false;
  auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
  if (bz.IsNull())
    return false;
  try
  {
    int nbUPoles = bz->NbUPoles();
    if (poleCount != nbUPoles)
      return false;
    NCollection_Array1<gp_Pnt> col(1, nbUPoles);
    for (int i = 0; i < nbUPoles; i++)
    {
      col.SetValue(i + 1, gp_Pnt(poles[i * 3], poles[i * 3 + 1], poles[i * 3 + 2]));
    }
    bz->InsertPoleColAfter(colIndex, col);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBezierInsertPoleRowAfter(OCCTSurfaceRef surface,
                                         int32_t        rowIndex,
                                         const double*  poles,
                                         int32_t        poleCount)
{
  if (!surface || !poles)
    return false;
  auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
  if (bz.IsNull())
    return false;
  try
  {
    int nbVPoles = bz->NbVPoles();
    if (poleCount != nbVPoles)
      return false;
    NCollection_Array1<gp_Pnt> row(1, nbVPoles);
    for (int i = 0; i < nbVPoles; i++)
    {
      row.SetValue(i + 1, gp_Pnt(poles[i * 3], poles[i * 3 + 1], poles[i * 3 + 2]));
    }
    bz->InsertPoleRowAfter(rowIndex, row);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBezierRemovePoleCol(OCCTSurfaceRef surface, int32_t colIndex)
{
  if (!surface)
    return false;
  auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
  if (bz.IsNull())
    return false;
  try
  {
    bz->RemovePoleCol(colIndex);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBezierRemovePoleRow(OCCTSurfaceRef surface, int32_t rowIndex)
{
  if (!surface)
    return false;
  auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
  if (bz.IsNull())
    return false;
  try
  {
    bz->RemovePoleRow(rowIndex);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBezierIncreaseDegree(OCCTSurfaceRef surface, int32_t uDeg, int32_t vDeg)
{
  if (!surface)
    return false;
  auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
  if (bz.IsNull())
    return false;
  try
  {
    bz->Increase(uDeg, vDeg);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBezierUReverse(OCCTSurfaceRef surface)
{
  if (!surface)
    return false;
  auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
  if (bz.IsNull())
    return false;
  try
  {
    bz->UReverse();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBezierVReverse(OCCTSurfaceRef surface)
{
  if (!surface)
    return false;
  auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
  if (bz.IsNull())
    return false;
  try
  {
    bz->VReverse();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBezierSetPoleColWeights(OCCTSurfaceRef surface,
                                        int32_t        vIndex,
                                        const double*  poles,
                                        const double*  weights,
                                        int32_t        count)
{
  if (!surface || !poles || !weights || count <= 0)
    return false;
  auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
  if (bz.IsNull())
    return false;
  try
  {
    NCollection_Array1<gp_Pnt> colPoles(1, count);
    NCollection_Array1<double> colWeights(1, count);
    for (int i = 0; i < count; i++)
    {
      colPoles.SetValue(i + 1, gp_Pnt(poles[i * 3], poles[i * 3 + 1], poles[i * 3 + 2]));
      colWeights.SetValue(i + 1, weights[i]);
    }
    bz->SetPoleCol(vIndex, colPoles, colWeights);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBezierSetPoleRowWeights(OCCTSurfaceRef surface,
                                        int32_t        uIndex,
                                        const double*  poles,
                                        const double*  weights,
                                        int32_t        count)
{
  if (!surface || !poles || !weights || count <= 0)
    return false;
  auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
  if (bz.IsNull())
    return false;
  try
  {
    NCollection_Array1<gp_Pnt> rowPoles(1, count);
    NCollection_Array1<double> rowWeights(1, count);
    for (int i = 0; i < count; i++)
    {
      rowPoles.SetValue(i + 1, gp_Pnt(poles[i * 3], poles[i * 3 + 1], poles[i * 3 + 2]));
      rowWeights.SetValue(i + 1, weights[i]);
    }
    bz->SetPoleRow(uIndex, rowPoles, rowWeights);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceTransform(OCCTSurfaceRef surface,
                          int32_t        transformType,
                          double         p1,
                          double         p2,
                          double         p3,
                          double         p4,
                          double         p5,
                          double         p6,
                          double         p7)
{
  if (!surface || surface->surface.IsNull())
    return false;
  try
  {
    gp_Trsf trsf;
    if (!occtBuildTrsf3D(trsf, transformType, p1, p2, p3, p4, p5, p6, p7))
      return false;
    surface->surface->Transform(trsf);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBSplineSetWeightCol(OCCTSurfaceRef surface,
                                    int32_t        vIndex,
                                    const double*  weights,
                                    int32_t        count)
{
  if (!surface || surface->surface.IsNull() || !weights || count <= 0)
    return false;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    TColStd_Array1OfReal w(1, count);
    for (int i = 0; i < count; i++)
      w.SetValue(i + 1, weights[i]);
    bs->SetWeightCol(vIndex, w);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBSplineSetWeightRow(OCCTSurfaceRef surface,
                                    int32_t        uIndex,
                                    const double*  weights,
                                    int32_t        count)
{
  if (!surface || surface->surface.IsNull() || !weights || count <= 0)
    return false;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    TColStd_Array1OfReal w(1, count);
    for (int i = 0; i < count; i++)
      w.SetValue(i + 1, weights[i]);
    bs->SetWeightRow(uIndex, w);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBSplineIncrementUMultiplicity(OCCTSurfaceRef surface,
                                              int32_t        fromIndex,
                                              int32_t        toIndex,
                                              int32_t        step)
{
  if (!surface || surface->surface.IsNull())
    return false;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    bs->IncrementUMultiplicity(fromIndex, toIndex, step);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBSplineIncrementVMultiplicity(OCCTSurfaceRef surface,
                                              int32_t        fromIndex,
                                              int32_t        toIndex,
                                              int32_t        step)
{
  if (!surface || surface->surface.IsNull())
    return false;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    bs->IncrementVMultiplicity(fromIndex, toIndex, step);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTSurfaceBSplineFirstUKnotIndex(OCCTSurfaceRef surface)
{
  if (!surface || surface->surface.IsNull())
    return 0;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return 0;
  try
  {
    return (int32_t)bs->FirstUKnotIndex();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTSurfaceBSplineLastUKnotIndex(OCCTSurfaceRef surface)
{
  if (!surface || surface->surface.IsNull())
    return 0;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return 0;
  try
  {
    return (int32_t)bs->LastUKnotIndex();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTSurfaceBSplineFirstVKnotIndex(OCCTSurfaceRef surface)
{
  if (!surface || surface->surface.IsNull())
    return 0;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return 0;
  try
  {
    return (int32_t)bs->FirstVKnotIndex();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTSurfaceBSplineLastVKnotIndex(OCCTSurfaceRef surface)
{
  if (!surface || surface->surface.IsNull())
    return 0;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return 0;
  try
  {
    return (int32_t)bs->LastVKnotIndex();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTSurfaceBSplineCheckAndSegment(OCCTSurfaceRef surface,
                                       double         u1,
                                       double         u2,
                                       double         v1,
                                       double         v2,
                                       double         uTol,
                                       double         vTol)
{
  if (!surface || surface->surface.IsNull())
    return false;
  auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
  if (bs.IsNull())
    return false;
  try
  {
    bs->CheckAndSegment(u1, u2, v1, v2, uTol, vTol);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBezierInsertPoleColBefore(OCCTSurfaceRef surface,
                                          int32_t        colIndex,
                                          const double*  poles,
                                          int32_t        poleCount)
{
  if (!surface || !poles)
    return false;
  auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
  if (bz.IsNull())
    return false;
  try
  {
    int nbUPoles = bz->NbUPoles();
    if (poleCount != nbUPoles)
      return false;
    NCollection_Array1<gp_Pnt> col(1, nbUPoles);
    for (int i = 0; i < nbUPoles; i++)
    {
      col.SetValue(i + 1, gp_Pnt(poles[i * 3], poles[i * 3 + 1], poles[i * 3 + 2]));
    }
    bz->InsertPoleColBefore(colIndex, col);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBezierInsertPoleRowBefore(OCCTSurfaceRef surface,
                                          int32_t        rowIndex,
                                          const double*  poles,
                                          int32_t        poleCount)
{
  if (!surface || !poles)
    return false;
  auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
  if (bz.IsNull())
    return false;
  try
  {
    int nbVPoles = bz->NbVPoles();
    if (poleCount != nbVPoles)
      return false;
    NCollection_Array1<gp_Pnt> row(1, nbVPoles);
    for (int i = 0; i < nbVPoles; i++)
    {
      row.SetValue(i + 1, gp_Pnt(poles[i * 3], poles[i * 3 + 1], poles[i * 3 + 2]));
    }
    bz->InsertPoleRowBefore(rowIndex, row);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBezierSetPoleCol(OCCTSurfaceRef surface,
                                 int32_t        vIndex,
                                 const double*  poles,
                                 int32_t        count)
{
  if (!surface || !poles || count <= 0)
    return false;
  auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
  if (bz.IsNull())
    return false;
  try
  {
    NCollection_Array1<gp_Pnt> col(1, count);
    for (int i = 0; i < count; i++)
    {
      col.SetValue(i + 1, gp_Pnt(poles[i * 3], poles[i * 3 + 1], poles[i * 3 + 2]));
    }
    bz->SetPoleCol(vIndex, col);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBezierSetPoleRow(OCCTSurfaceRef surface,
                                 int32_t        uIndex,
                                 const double*  poles,
                                 int32_t        count)
{
  if (!surface || !poles || count <= 0)
    return false;
  auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
  if (bz.IsNull())
    return false;
  try
  {
    NCollection_Array1<gp_Pnt> row(1, count);
    for (int i = 0; i < count; i++)
    {
      row.SetValue(i + 1, gp_Pnt(poles[i * 3], poles[i * 3 + 1], poles[i * 3 + 2]));
    }
    bz->SetPoleRow(uIndex, row);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBezierSetWeightCol(OCCTSurfaceRef surface,
                                   int32_t        vIndex,
                                   const double*  weights,
                                   int32_t        count)
{
  if (!surface || !weights || count <= 0)
    return false;
  auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
  if (bz.IsNull())
    return false;
  try
  {
    TColStd_Array1OfReal w(1, count);
    for (int i = 0; i < count; i++)
      w.SetValue(i + 1, weights[i]);
    bz->SetWeightCol(vIndex, w);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSurfaceBezierSetWeightRow(OCCTSurfaceRef surface,
                                   int32_t        uIndex,
                                   const double*  weights,
                                   int32_t        count)
{
  if (!surface || !weights || count <= 0)
    return false;
  auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
  if (bz.IsNull())
    return false;
  try
  {
    TColStd_Array1OfReal w(1, count);
    for (int i = 0; i < count; i++)
      w.SetValue(i + 1, weights[i]);
    bz->SetWeightRow(uIndex, w);
    return true;
  }
  catch (...)
  {
    return false;
  }
}
