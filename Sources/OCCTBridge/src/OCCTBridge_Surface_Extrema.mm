//
//  OCCTBridge_Surface_Extrema.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Surface.mm (#1380): Extrema_ExtPS/ExtSS/ExtElSS/ExtPElS.
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

int32_t OCCTExtremaElSSPlanePlane(double  pl1x,
                                  double  pl1y,
                                  double  pl1z,
                                  double  pn1x,
                                  double  pn1y,
                                  double  pn1z,
                                  double  pl2x,
                                  double  pl2y,
                                  double  pl2z,
                                  double  pn2x,
                                  double  pn2y,
                                  double  pn2z,
                                  bool*   outIsParallel,
                                  double* outSquareDistance)
{
  *outIsParallel = false;
  try
  {
    gp_Pln          pl1(gp_Pnt(pl1x, pl1y, pl1z), gp_Dir(pn1x, pn1y, pn1z));
    gp_Pln          pl2(gp_Pnt(pl2x, pl2y, pl2z), gp_Dir(pn2x, pn2y, pn2z));
    Extrema_ExtElSS ext(pl1, pl2);
    if (!ext.IsDone())
      return -1;
    *outIsParallel = ext.IsParallel();
    // #1632: the square distance is the whole answer. This never calls Points(): the parallel
    // branch of Perform(gp_Pln, gp_Pln) fills mySqDist alone and leaves myPOnS1/myPOnS2 null,
    // so Points() faults uncatchably (#345, OCC_CATCH_SIGNALS is inert in this build), and the
    // non-parallel branch reports NbExt() == 0 so there is nothing to read there either. The
    // zeros this used to write into the point fields were a value that read as a measurement.
    if (!ext.IsParallel() || ext.NbExt() < 1)
      return 0;
    *outSquareDistance = ext.SquareDistance(1);
    return 1;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return -1;
  }
}

int32_t OCCTExtremaExtPElSPlane(double               px,
                                double               py,
                                double               pz,
                                double               plx,
                                double               ply,
                                double               plz,
                                double               pnx,
                                double               pny,
                                double               pnz,
                                double               tolerance,
                                OCCTExtremaElResult* out,
                                int32_t              max)
{
  try
  {
    gp_Pnt          p(px, py, pz);
    gp_Pln          pl(gp_Pnt(plx, ply, plz), gp_Dir(pnx, pny, pnz));
    Extrema_ExtPElS ext(p, pl, tolerance);
    if (!ext.IsDone())
      return -1;
    int n     = ext.NbExt();
    int count = 0;
    for (int i = 1; i <= n && count < max; i++)
    {
      out[count].squareDistance = ext.SquareDistance(i);
      gp_Pnt pt                 = ext.Point(i).Value();
      out[count].x1             = px;
      out[count].y1             = py;
      out[count].z1             = pz;
      out[count].x2             = pt.X();
      out[count].y2             = pt.Y();
      out[count].z2             = pt.Z();
      count++;
    }
    return count;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return -1;
  }
}

int32_t OCCTExtremaExtPElSSphere(double               px,
                                 double               py,
                                 double               pz,
                                 double               cx,
                                 double               cy,
                                 double               cz,
                                 double               radius,
                                 double               tolerance,
                                 OCCTExtremaElResult* out,
                                 int32_t              max)
{
  try
  {
    gp_Pnt          p(px, py, pz);
    gp_Sphere       sp(gp_Ax3(gp_Pnt(cx, cy, cz), gp_Dir(0, 0, 1)), radius);
    Extrema_ExtPElS ext(p, sp, tolerance);
    if (!ext.IsDone())
      return -1;
    int n     = ext.NbExt();
    int count = 0;
    for (int i = 1; i <= n && count < max; i++)
    {
      out[count].squareDistance = ext.SquareDistance(i);
      gp_Pnt pt                 = ext.Point(i).Value();
      out[count].x1             = px;
      out[count].y1             = py;
      out[count].z1             = pz;
      out[count].x2             = pt.X();
      out[count].y2             = pt.Y();
      out[count].z2             = pt.Z();
      count++;
    }
    return count;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return -1;
  }
}

int32_t OCCTExtremaExtPElSCylinder(double               px,
                                   double               py,
                                   double               pz,
                                   double               cx,
                                   double               cy,
                                   double               cz,
                                   double               nx,
                                   double               ny,
                                   double               nz,
                                   double               radius,
                                   double               tolerance,
                                   OCCTExtremaElResult* out,
                                   int32_t              max)
{
  try
  {
    gp_Pnt          p(px, py, pz);
    gp_Cylinder     cyl(gp_Ax3(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz)), radius);
    Extrema_ExtPElS ext(p, cyl, tolerance);
    if (!ext.IsDone())
      return -1;
    int n     = ext.NbExt();
    int count = 0;
    for (int i = 1; i <= n && count < max; i++)
    {
      out[count].squareDistance = ext.SquareDistance(i);
      gp_Pnt pt                 = ext.Point(i).Value();
      out[count].x1             = px;
      out[count].y1             = py;
      out[count].z1             = pz;
      out[count].x2             = pt.X();
      out[count].y2             = pt.Y();
      out[count].z2             = pt.Z();
      count++;
    }
    return count;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return -1;
  }
}

int32_t OCCTExtremaExtPElSCone(double               px,
                               double               py,
                               double               pz,
                               double               cx,
                               double               cy,
                               double               cz,
                               double               nx,
                               double               ny,
                               double               nz,
                               double               semiAngle,
                               double               refRadius,
                               double               tolerance,
                               OCCTExtremaElResult* out,
                               int32_t              max)
{
  try
  {
    gp_Pnt          p(px, py, pz);
    gp_Cone         cone(gp_Ax3(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz)), semiAngle, refRadius);
    Extrema_ExtPElS ext(p, cone, tolerance);
    if (!ext.IsDone())
      return -1;
    int n     = ext.NbExt();
    int count = 0;
    for (int i = 1; i <= n && count < max; i++)
    {
      out[count].squareDistance = ext.SquareDistance(i);
      gp_Pnt pt                 = ext.Point(i).Value();
      out[count].x1             = px;
      out[count].y1             = py;
      out[count].z1             = pz;
      out[count].x2             = pt.X();
      out[count].y2             = pt.Y();
      out[count].z2             = pt.Z();
      count++;
    }
    return count;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return -1;
  }
}

int32_t OCCTExtremaExtPElSTorus(double               px,
                                double               py,
                                double               pz,
                                double               cx,
                                double               cy,
                                double               cz,
                                double               nx,
                                double               ny,
                                double               nz,
                                double               majorRadius,
                                double               minorRadius,
                                double               tolerance,
                                OCCTExtremaElResult* out,
                                int32_t              max)
{
  try
  {
    gp_Pnt          p(px, py, pz);
    gp_Torus        tor(gp_Ax3(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz)), majorRadius, minorRadius);
    Extrema_ExtPElS ext(p, tor, tolerance);
    if (!ext.IsDone())
      return -1;
    int n     = ext.NbExt();
    int count = 0;
    for (int i = 1; i <= n && count < max; i++)
    {
      out[count].squareDistance = ext.SquareDistance(i);
      gp_Pnt pt                 = ext.Point(i).Value();
      out[count].x1             = px;
      out[count].y1             = py;
      out[count].z1             = pz;
      out[count].x2             = pt.X();
      out[count].y2             = pt.Y();
      out[count].z2             = pt.Z();
      count++;
    }
    return count;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return -1;
  }
}
