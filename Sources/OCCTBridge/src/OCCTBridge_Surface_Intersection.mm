//
//  OCCTBridge_Surface_Intersection.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Surface.mm (#1380): Contap_* (Contour), GeomInt_IntSS, GeomAPI_IntCS.
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
#include <Adaptor2d_Curve2d.hxx>
#include <Contap_ContAna.hxx>
#include <Contap_Contour.hxx>
#include <Contap_IType.hxx>
#include <Contap_Line.hxx>
#include <Contap_Point.hxx>
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

#include <limits>

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
  // #2884: GeomFill_Profiler exposes no curve count, and two of the members the bridge calls
  // index into mySequence with no live bound test. The bridge is the only caller of AddCurve, so
  // it counts what it added. Kept in step across all seven copies of this struct by
  // check-bridge-type-odr.py (#2820).
  int curveCount;
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

int32_t OCCTContapSphereDir(double   cx,
                            double   cy,
                            double   cz,
                            double   radius,
                            double   dirX,
                            double   dirY,
                            double   dirZ,
                            int32_t* outType,
                            double*  outData)
{
  if (!outType || !outData)
    return -1;
  try
  {
    gp_Sphere      sphere(gp_Ax3(gp_Pnt(cx, cy, cz), gp_Dir(0, 0, 1)), radius);
    gp_Dir         viewDir(dirX, dirY, dirZ);
    Contap_ContAna contAna;
    contAna.Perform(sphere, viewDir);
    if (!contAna.IsDone())
      return -1;
    int32_t nb = contAna.NbContours();
    if (nb > 0)
    {
      GeomAbs_CurveType ctype = contAna.TypeContour();
      if (ctype == GeomAbs_Circle)
      {
        *outType       = 1; // circle
        gp_Circ circ   = contAna.Circle();
        gp_Pnt  center = circ.Location();
        outData[0]     = center.X();
        outData[1]     = center.Y();
        outData[2]     = center.Z();
        outData[3]     = circ.Radius();
      }
      else if (ctype == GeomAbs_Line)
      {
        *outType    = 0; // line
        gp_Lin line = contAna.Line(1);
        gp_Pnt loc  = line.Location();
        gp_Dir dir  = line.Direction();
        outData[0]  = loc.X();
        outData[1]  = loc.Y();
        outData[2]  = loc.Z();
        outData[3]  = dir.X();
        outData[4]  = dir.Y();
        outData[5]  = dir.Z();
      }
      else
      {
        *outType = 2; // walking/other
      }
    }
    return nb;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return -1;
  }
}

int32_t OCCTContapCylinderDir(double   px,
                              double   py,
                              double   pz,
                              double   axX,
                              double   axY,
                              double   axZ,
                              double   radius,
                              double   dirX,
                              double   dirY,
                              double   dirZ,
                              int32_t* outType,
                              double*  outData)
{
  if (!outType || !outData)
    return -1;
  try
  {
    gp_Cylinder    cyl(gp_Ax3(gp_Pnt(px, py, pz), gp_Dir(axX, axY, axZ)), radius);
    gp_Dir         viewDir(dirX, dirY, dirZ);
    Contap_ContAna contAna;
    contAna.Perform(cyl, viewDir);
    if (!contAna.IsDone())
      return -1;
    int32_t nb = contAna.NbContours();
    if (nb > 0)
    {
      GeomAbs_CurveType ctype = contAna.TypeContour();
      if (ctype == GeomAbs_Line)
      {
        *outType = 0; // line
        // #1416: Contap_ContAna::Perform(gp_Cylinder, gp_Dir) sets nbSol to exactly 0 or 2 on
        // its only success path (Contap_ContAna.cxx), never 1: a cylinder's silhouette against a
        // non-degenerate view direction is always the pair of tangent rulings either side of the
        // axis. Write every line NbContours() reports (capped at 2, the most this overload ever
        // produces), 6 doubles each: location xyz then direction xyz, line 1 at outData[0..5],
        // line 2 at outData[6..11]. Caller must provide a 12-double outData buffer.
        for (int32_t i = 0; i < nb && i < 2; ++i)
        {
          gp_Lin  line     = contAna.Line(i + 1);
          gp_Pnt  loc      = line.Location();
          gp_Dir  dir      = line.Direction();
          double* lineData = outData + (i * 6);
          lineData[0]      = loc.X();
          lineData[1]      = loc.Y();
          lineData[2]      = loc.Z();
          lineData[3]      = dir.X();
          lineData[4]      = dir.Y();
          lineData[5]      = dir.Z();
        }
      }
      else if (ctype == GeomAbs_Circle)
      {
        *outType       = 1; // circle
        gp_Circ circ   = contAna.Circle();
        gp_Pnt  center = circ.Location();
        outData[0]     = center.X();
        outData[1]     = center.Y();
        outData[2]     = center.Z();
        outData[3]     = circ.Radius();
      }
      else
      {
        *outType = 2;
      }
    }
    return nb;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return -1;
  }
}

int32_t OCCTContapSphereEye(double   cx,
                            double   cy,
                            double   cz,
                            double   radius,
                            double   eyeX,
                            double   eyeY,
                            double   eyeZ,
                            int32_t* outType,
                            double*  outData)
{
  if (!outType || !outData)
    return -1;
  try
  {
    gp_Sphere      sphere(gp_Ax3(gp_Pnt(cx, cy, cz), gp_Dir(0, 0, 1)), radius);
    gp_Pnt         eye(eyeX, eyeY, eyeZ);
    Contap_ContAna contAna;
    contAna.Perform(sphere, eye);
    if (!contAna.IsDone())
      return -1;
    int32_t nb = contAna.NbContours();
    if (nb > 0)
    {
      GeomAbs_CurveType ctype = contAna.TypeContour();
      if (ctype == GeomAbs_Circle)
      {
        *outType       = 1;
        gp_Circ circ   = contAna.Circle();
        gp_Pnt  center = circ.Location();
        outData[0]     = center.X();
        outData[1]     = center.Y();
        outData[2]     = center.Z();
        outData[3]     = circ.Radius();
      }
      else if (ctype == GeomAbs_Line)
      {
        *outType    = 0;
        gp_Lin line = contAna.Line(1);
        gp_Pnt loc  = line.Location();
        gp_Dir dir  = line.Direction();
        outData[0]  = loc.X();
        outData[1]  = loc.Y();
        outData[2]  = loc.Z();
        outData[3]  = dir.X();
        outData[4]  = dir.Y();
        outData[5]  = dir.Z();
      }
      else
      {
        *outType = 2;
      }
    }
    return nb;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return -1;
  }
}

OCCTContapContourRef _Nullable OCCTContapContourDirection(OCCTShapeRef faceShape,
                                                          double       dx,
                                                          double       dy,
                                                          double       dz)
{
  if (!faceShape)
    return nullptr;
  try
  {
    TopoDS_Face                      face = TopoDS::Face(faceShape->shape);
    Handle(BRepAdaptor_Surface)      surf = new BRepAdaptor_Surface(face);
    Handle(BRepTopAdaptor_TopolTool) tool = new BRepTopAdaptor_TopolTool(surf);
    auto*                            ref  = new OCCTContapContour();
    ref->contour.Init(gp_Vec(dx, dy, dz));
    ref->contour.Perform(surf, tool);
    ref->valid = ref->contour.IsDone();
    ref->empty = ref->contour.IsEmpty();
    return ref;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

OCCTContapContourRef _Nullable OCCTContapContourEye(OCCTShapeRef faceShape,
                                                    double       ex,
                                                    double       ey,
                                                    double       ez)
{
  if (!faceShape)
    return nullptr;
  try
  {
    TopoDS_Face                      face = TopoDS::Face(faceShape->shape);
    Handle(BRepAdaptor_Surface)      surf = new BRepAdaptor_Surface(face);
    Handle(BRepTopAdaptor_TopolTool) tool = new BRepTopAdaptor_TopolTool(surf);
    auto*                            ref  = new OCCTContapContour();
    ref->contour.Init(gp_Pnt(ex, ey, ez));
    ref->contour.Perform(surf, tool);
    ref->valid = ref->contour.IsDone();
    ref->empty = ref->contour.IsEmpty();
    return ref;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

int OCCTContapContourLineCount(OCCTContapContourRef ref)
{
  if (!ref)
    return 0;
  auto* r = static_cast<OCCTContapContour*>(ref);
  if (!r->valid || r->empty)
    return 0;
  return r->contour.NbLines();
}

int OCCTContapContourLinePointCount(OCCTContapContourRef ref, int lineIndex)
{
  if (!ref)
    return 0;
  auto* r = static_cast<OCCTContapContour*>(ref);
  if (!r->valid || r->empty)
    return 0;
  if (lineIndex < 1 || lineIndex > r->contour.NbLines())
    return 0;
  try
  {
    return r->contour.Line(lineIndex).NbPnts();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

void OCCTContapContourLinePoint(OCCTContapContourRef ref,
                                int                  lineIndex,
                                int                  pointIndex,
                                double*              x,
                                double*              y,
                                double*              z)
{
  if (!ref || !x || !y || !z)
    return;
  auto* r = static_cast<OCCTContapContour*>(ref);
  if (!r->valid || r->empty)
    return;
  try
  {
    const Contap_Line& line = r->contour.Line(lineIndex);
    if (pointIndex < 1 || pointIndex > line.NbPnts())
      return;
    gp_Pnt pt = line.Point(pointIndex).Value();
    *x        = pt.X();
    *y        = pt.Y();
    *z        = pt.Z();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

int OCCTContapContourLineType(OCCTContapContourRef ref, int lineIndex)
{
  if (!ref)
    return -1;
  auto* r = static_cast<OCCTContapContour*>(ref);
  if (!r->valid || r->empty)
    return -1;
  if (lineIndex < 1 || lineIndex > r->contour.NbLines())
    return -1;
  try
  {
    Contap_IType t = r->contour.Line(lineIndex).TypeContour();
    return static_cast<int>(t);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return -1;
  }
}

void OCCTContapContourRelease(OCCTContapContourRef ref)
{
  if (ref)
    delete static_cast<OCCTContapContour*>(ref);
}

// #1635: geometry for the contour types Contap_Line::NbPnts()/Point() refuse.
//
// Every accessor here goes through this helper, which is the only place the line index is
// validated. It returns nullptr rather than throwing, so a caller that gets nullptr refuses
// without writing to its out-parameters: absence must not be spelled as a zero on this API,
// which is the defect the walking-only accessors above already had reported against them.
static const Contap_Line* occtContapLineAt(OCCTContapContourRef ref, int lineIndex)
{
  if (!ref)
    return nullptr;
  auto* r = static_cast<OCCTContapContour*>(ref);
  if (!r->valid || r->empty)
    return nullptr;
  if (lineIndex < 1 || lineIndex > r->contour.NbLines())
    return nullptr;
  return &r->contour.Line(lineIndex);
}

bool OCCTContapContourLineAsLine(OCCTContapContourRef ref, int lineIndex, double* out)
{
  if (!out)
    return false;
  try
  {
    const Contap_Line* line = occtContapLineAt(ref, lineIndex);
    if (!line || line->TypeContour() != Contap_Lin)
      return false;
    const gp_Lin l = line->Line();
    out[0]         = l.Location().X();
    out[1]         = l.Location().Y();
    out[2]         = l.Location().Z();
    out[3]         = l.Direction().X();
    out[4]         = l.Direction().Y();
    out[5]         = l.Direction().Z();
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTContapContourLineAsCircle(OCCTContapContourRef ref, int lineIndex, double* out)
{
  if (!out)
    return false;
  try
  {
    const Contap_Line* line = occtContapLineAt(ref, lineIndex);
    if (!line || line->TypeContour() != Contap_Circle)
      return false;
    const gp_Circ c = line->Circle();
    out[0]          = c.Location().X();
    out[1]          = c.Location().Y();
    out[2]          = c.Location().Z();
    out[3]          = c.Axis().Direction().X();
    out[4]          = c.Axis().Direction().Y();
    out[5]          = c.Axis().Direction().Z();
    out[6]          = c.XAxis().Direction().X();
    out[7]          = c.XAxis().Direction().Y();
    out[8]          = c.XAxis().Direction().Z();
    out[9]          = c.Radius();
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTContapContourLineArcRange(OCCTContapContourRef ref,
                                   int                  lineIndex,
                                   double*              outFirst,
                                   double*              outLast)
{
  if (!outFirst || !outLast)
    return false;
  try
  {
    const Contap_Line* line = occtContapLineAt(ref, lineIndex);
    if (!line || line->TypeContour() != Contap_Restriction)
      return false;
    const occ::handle<Adaptor2d_Curve2d>& arc = line->Arc();
    if (arc.IsNull())
      return false;
    *outFirst = arc->FirstParameter();
    *outLast  = arc->LastParameter();
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTContapContourLineArcPoint(OCCTContapContourRef ref,
                                   int                  lineIndex,
                                   double               parameter,
                                   double*              outU,
                                   double*              outV)
{
  if (!outU || !outV)
    return false;
  try
  {
    const Contap_Line* line = occtContapLineAt(ref, lineIndex);
    if (!line || line->TypeContour() != Contap_Restriction)
      return false;
    const occ::handle<Adaptor2d_Curve2d>& arc = line->Arc();
    if (arc.IsNull())
      return false;
    const gp_Pnt2d p = arc->Value(parameter);
    *outU            = p.X();
    *outV            = p.Y();
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

int OCCTContapContourLineVertexCount(OCCTContapContourRef ref, int lineIndex)
{
  try
  {
    const Contap_Line* line = occtContapLineAt(ref, lineIndex);
    if (!line)
      return 0;
    return line->NbVertex();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

bool OCCTContapContourLineVertex(OCCTContapContourRef ref,
                                 int                  lineIndex,
                                 int                  vertexIndex,
                                 OCCTContapVertex*    out)
{
  if (!out)
    return false;
  try
  {
    const Contap_Line* line = occtContapLineAt(ref, lineIndex);
    if (!line)
      return false;
    if (vertexIndex < 1 || vertexIndex > line->NbVertex())
      return false;
    const Contap_Point& p = line->Vertex(vertexIndex);
    out->x                = p.Value().X();
    out->y                = p.Value().Y();
    out->z                = p.Value().Z();
    p.Parameters(out->u, out->v);
    out->parameterOnLine = p.ParameterOnLine();
    out->isOnArc         = p.IsOnArc();
    // ParameterOnArc() throws Standard_DomainError when the point is not on an arc. NaN rather
    // than 0 so a caller that reads it without checking isOnArc gets something that cannot be
    // mistaken for a parameter.
    out->parameterOnArc =
      p.IsOnArc() ? p.ParameterOnArc() : std::numeric_limits<double>::quiet_NaN();
    out->isVertex   = p.IsVertex();
    out->isMultiple = p.IsMultiple();
    out->isInternal = p.IsInternal();
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}
