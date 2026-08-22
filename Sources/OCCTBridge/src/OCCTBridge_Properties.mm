//
//  OCCTBridge_Properties.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm, issue #99.
//
//  v0.18 properties + projection + proximity cluster:
//
//  - Face surface properties (area, mean / Gaussian / principal
//    curvatures, surface type, primary axis, UV bounds, eval at UV,
//    normal at UV)
//  - Edge 3D curve properties (curve type, parameter bounds, point /
//    tangent / normal / curvature / torsion / center of curvature,
//    project point onto edge)
//  - Point projection (onto curves and surfaces)
//  - Shape proximity (BRepExtrema_ShapeProximity overlap detection)
//  - Surface intersection (face / face section curves via
//    BRepAlgoAPI_Section)
//
//  Public C surface unchanged. No symbol changes, pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <Standard_ErrorHandler.hxx> // OCC_CATCH_SIGNALS (#175)
#include <BRep_Tool.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepAlgoAPI_Section.hxx>
#include <BRepExtrema_OverlapTool.hxx>
#include <BRepExtrema_ShapeProximity.hxx>
#include <BRepGProp.hxx>
#include <BRepGProp_Face.hxx>
#include <BRepGProp_MeshCinert.hxx>
#include <BRepGProp_MeshProps.hxx>
#include <BRepGProp_Cinert.hxx>
#include <BRepGProp_Sinert.hxx>
#include <BRepGProp_Vinert.hxx>
#include <BRepGProp_VinertGK.hxx>
#include <BRepLProp_CLProps.hxx>
#include <BRepLProp_SLProps.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepTools.hxx>

#include <Geom_Curve.hxx>
#include <Geom_Surface.hxx>
#include <Geom_SurfaceOfLinearExtrusion.hxx>
#include <Geom_SurfaceOfRevolution.hxx>
#include <GeomAbs_CurveType.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <GeomLProp_CLProps.hxx>
#include <GeomLProp_SLProps.hxx>

#include <gp_Ax1.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Sphere.hxx>
#include <gp_Vec.hxx>
#include <GProp_GProps.hxx>
#include <GProp_PrincipalProps.hxx>
#include <BRepAdaptor_CompCurve.hxx>
#include <GCPnts_AbscissaPoint.hxx>

#include <TopAbs.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopTools_ListOfShape.hxx>

// MARK: - Mass properties (#605 / #609)
//
// The contract each of these implements is documented on the declarations in
// OCCTBridge_Internal.h. In short: OCCT expects the caller to test Mass(), and to pass OnlyClosed
// when it wants the volume integral to refuse an open surface rather than estimate one. Neither
// happened anywhere in the bridge before #605/#609.

bool occtVolumeMassProperties(const TopoDS_Shape& shape, GProp_GProps& props)
{
  BRepGProp::VolumeProperties(shape, props, /*OnlyClosed*/ true);
  return props.Mass() != 0.0;
}

bool occtSurfaceMassProperties(const TopoDS_Shape& shape, GProp_GProps& props)
{
  BRepGProp::SurfaceProperties(shape, props);
  return props.Mass() != 0.0;
}

bool occtLinearMassProperties(const TopoDS_Shape& shape, GProp_GProps& props)
{
  BRepGProp::LinearProperties(shape, props);
  return props.Mass() != 0.0;
}

// MARK: - Face Surface Properties (v0.18.0)

#include <GeomLProp_SLProps.hxx>
#include <BRepGProp.hxx>

bool OCCTFaceGetUVBounds(OCCTFaceRef face, double* uMin, double* uMax, double* vMin, double* vMax)
{
  if (!face || !uMin || !uMax || !vMin || !vMax)
    return false;

  try
  {
    BRepTools::UVBounds(face->face, *uMin, *uMax, *vMin, *vMax);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFaceEvaluateAtUV(OCCTFaceRef face, double u, double v, double* px, double* py, double* pz)
{
  if (!occtShapeIsPresent(face) || !px || !py || !pz)
    return false;

  try
  {
    Handle(Geom_Surface) surface = BRep_Tool::Surface(face->face);
    if (surface.IsNull())
      return false;

    gp_Pnt pnt;
    surface->D0(u, v, pnt);
    *px = pnt.X();
    *py = pnt.Y();
    *pz = pnt.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFaceGetNormalAtUV(OCCTFaceRef face, double u, double v, double* nx, double* ny, double* nz)
{
  if (!occtShapeIsPresent(face) || !nx || !ny || !nz)
    return false;

  try
  {
    Handle(Geom_Surface) surface = BRep_Tool::Surface(face->face);
    if (surface.IsNull())
      return false;

    GeomLProp_SLProps props = occtSurfaceLocalProps(surface, u, v, 1);
    if (!props.IsNormalDefined())
      return false;

    gp_Dir normal = props.Normal();
    // Reverse if face orientation is reversed
    if (face->face.Orientation() == TopAbs_REVERSED)
    {
      normal.Reverse();
    }
    *nx = normal.X();
    *ny = normal.Y();
    *nz = normal.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFaceGetGaussianCurvature(OCCTFaceRef face, double u, double v, double* curvature)
{
  if (!occtShapeIsPresent(face) || !curvature)
    return false;

  try
  {
    Handle(Geom_Surface) surface = BRep_Tool::Surface(face->face);
    if (surface.IsNull())
      return false;

    GeomLProp_SLProps props = occtSurfaceLocalProps(surface, u, v, 2);
    if (!props.IsCurvatureDefined())
      return false;

    *curvature = props.GaussianCurvature();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFaceGetMeanCurvature(OCCTFaceRef face, double u, double v, double* curvature)
{
  if (!occtShapeIsPresent(face) || !curvature)
    return false;

  try
  {
    Handle(Geom_Surface) surface = BRep_Tool::Surface(face->face);
    if (surface.IsNull())
      return false;

    GeomLProp_SLProps props = occtSurfaceLocalProps(surface, u, v, 2);
    if (!props.IsCurvatureDefined())
      return false;

    *curvature = props.MeanCurvature();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFaceGetPrincipalCurvatures(OCCTFaceRef face,
                                    double      u,
                                    double      v,
                                    double*     k1,
                                    double*     k2,
                                    double*     d1x,
                                    double*     d1y,
                                    double*     d1z,
                                    double*     d2x,
                                    double*     d2y,
                                    double*     d2z)
{
  if (!occtShapeIsPresent(face) || !k1 || !k2 || !d1x || !d1y || !d1z || !d2x || !d2y || !d2z)
    return false;

  try
  {
    Handle(Geom_Surface) surface = BRep_Tool::Surface(face->face);
    if (surface.IsNull())
      return false;

    GeomLProp_SLProps props = occtSurfaceLocalProps(surface, u, v, 2);
    if (!props.IsCurvatureDefined())
      return false;

    *k1 = props.MinCurvature();
    *k2 = props.MaxCurvature();

    gp_Dir dir1, dir2;
    props.CurvatureDirections(dir1, dir2);
    *d1x = dir1.X();
    *d1y = dir1.Y();
    *d1z = dir1.Z();
    *d2x = dir2.X();
    *d2y = dir2.Y();
    *d2z = dir2.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTFaceGetSurfaceType(OCCTFaceRef face)
{
  if (!face)
    return 10; // Other

  try
  {
    BRepAdaptor_Surface adaptor(face->face);
    switch (adaptor.GetType())
    {
      case GeomAbs_Plane:
        return 0;
      case GeomAbs_Cylinder:
        return 1;
      case GeomAbs_Cone:
        return 2;
      case GeomAbs_Sphere:
        return 3;
      case GeomAbs_Torus:
        return 4;
      case GeomAbs_BezierSurface:
        return 5;
      case GeomAbs_BSplineSurface:
        return 6;
      case GeomAbs_SurfaceOfRevolution:
        return 7;
      case GeomAbs_SurfaceOfExtrusion:
        return 8;
      case GeomAbs_OffsetSurface:
        return 9;
      default:
        return 10;
    }
  }
  catch (...)
  {
    return 10;
  }
}

double OCCTFaceGetArea(OCCTFaceRef face, double tolerance)
{
  if (!face)
    return -1.0;

  try
  {
    GProp_GProps props;
    BRepGProp::SurfaceProperties(face->face, props, tolerance);
    return props.Mass();
  }
  catch (...)
  {
    return -1.0;
  }
}

#include <Geom_SurfaceOfRevolution.hxx>
#include <Geom_SurfaceOfLinearExtrusion.hxx>

bool OCCTFaceGetPrimaryAxis(OCCTFaceRef face,
                            double*     ox,
                            double*     oy,
                            double*     oz,
                            double*     dx,
                            double*     dy,
                            double*     dz,
                            int32_t*    outKind)
{
  *ox      = 0;
  *oy      = 0;
  *oz      = 0;
  *dx      = 0;
  *dy      = 0;
  *dz      = 1;
  *outKind = 0;
  if (!occtShapeIsPresent(face))
    return false;
  try
  {
    BRepAdaptor_Surface adaptor(face->face);
    gp_Ax1              axis;
    int                 kind = 0;
    switch (adaptor.GetType())
    {
      case GeomAbs_Cylinder: {
        axis = adaptor.Cylinder().Axis();
        kind = 1;
        break;
      }
      case GeomAbs_Cone: {
        axis = adaptor.Cone().Axis();
        kind = 2;
        break;
      }
      case GeomAbs_Sphere: {
        gp_Sphere s = adaptor.Sphere();
        axis        = gp_Ax1(s.Location(), s.Position().Direction());
        kind        = 3;
        break;
      }
      case GeomAbs_Torus: {
        axis = adaptor.Torus().Axis();
        kind = 4;
        break;
      }
      case GeomAbs_SurfaceOfRevolution: {
        Handle(Geom_Surface)             surf = BRep_Tool::Surface(face->face);
        Handle(Geom_SurfaceOfRevolution) rev  = Handle(Geom_SurfaceOfRevolution)::DownCast(surf);
        if (rev.IsNull())
          return false;
        axis = rev->Axis();
        kind = 5;
        break;
      }
      case GeomAbs_SurfaceOfExtrusion: {
        Handle(Geom_Surface)                  surf = BRep_Tool::Surface(face->face);
        Handle(Geom_SurfaceOfLinearExtrusion) ext =
          Handle(Geom_SurfaceOfLinearExtrusion)::DownCast(surf);
        if (ext.IsNull())
          return false;
        gp_Dir dir = ext->Direction();
        // Extrusion has no canonical origin, use basis curve start.
        Handle(Geom_Curve) basis = ext->BasisCurve();
        gp_Pnt             origin(0, 0, 0);
        if (!basis.IsNull())
        {
          origin = basis->Value(basis->FirstParameter());
        }
        axis = gp_Ax1(origin, dir);
        kind = 6;
        break;
      }
      default:
        return false;
    }
    const gp_Pnt& p = axis.Location();
    const gp_Dir& d = axis.Direction();
    *ox             = p.X();
    *oy             = p.Y();
    *oz             = p.Z();
    *dx             = d.X();
    *dy             = d.Y();
    *dz             = d.Z();
    *outKind        = kind;
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - Edge 3D Curve Properties (v0.18.0)

#include <GeomLProp_CLProps.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <GeomAbs_CurveType.hxx>

bool OCCTEdgeGetParameterBounds(OCCTEdgeRef edge, double* first, double* last)
{
  if (!occtShapeIsPresent(edge) || !first || !last)
    return false;

  try
  {
    Standard_Real      f, l;
    Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, f, l);
    if (curve.IsNull())
      return false;

    *first = f;
    *last  = l;
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeGetCurvature3D(OCCTEdgeRef edge, double param, double* curvature)
{
  if (!occtShapeIsPresent(edge) || !curvature)
    return false;

  try
  {
    Standard_Real      f, l;
    Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, f, l);
    if (curve.IsNull())
      return false;

    GeomLProp_CLProps props = occtCurveLocalProps(curve, param, 2);
    if (!props.IsTangentDefined())
      return false;

    *curvature = props.Curvature();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeGetTangent3D(OCCTEdgeRef edge, double param, double* tx, double* ty, double* tz)
{
  if (!occtShapeIsPresent(edge) || !tx || !ty || !tz)
    return false;

  try
  {
    Standard_Real      f, l;
    Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, f, l);
    if (curve.IsNull())
      return false;

    GeomLProp_CLProps props = occtCurveLocalProps(curve, param, 1);
    if (!props.IsTangentDefined())
      return false;

    gp_Dir dir;
    props.Tangent(dir);
    *tx = dir.X();
    *ty = dir.Y();
    *tz = dir.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeGetNormal3D(OCCTEdgeRef edge, double param, double* nx, double* ny, double* nz)
{
  if (!occtShapeIsPresent(edge) || !nx || !ny || !nz)
    return false;

  try
  {
    Standard_Real      f, l;
    Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, f, l);
    if (curve.IsNull())
      return false;

    GeomLProp_CLProps props = occtCurveLocalProps(curve, param, 2);
    if (!props.IsTangentDefined())
      return false;

    gp_Dir dir;
    props.Normal(dir);
    *nx = dir.X();
    *ny = dir.Y();
    *nz = dir.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeGetCenterOfCurvature3D(OCCTEdgeRef edge,
                                    double      param,
                                    double*     cx,
                                    double*     cy,
                                    double*     cz)
{
  if (!occtShapeIsPresent(edge) || !cx || !cy || !cz)
    return false;

  try
  {
    Standard_Real      f, l;
    Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, f, l);
    if (curve.IsNull())
      return false;

    GeomLProp_CLProps props = occtCurveLocalProps(curve, param, 2);
    if (!props.IsTangentDefined())
      return false;

    // Also rejects a cusp's RealLast() curvature, which the previous magnitude-only test let
    // through into a (nan, inf, nan) centre reported as success (#494).
    if (!occtCurveCurvatureIsInvertible(props.Curvature()))
      return false;

    gp_Pnt center;
    props.CentreOfCurvature(center);
    *cx = center.X();
    *cy = center.Y();
    *cz = center.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeGetTorsion(OCCTEdgeRef edge, double param, double* torsion)
{
  if (!occtShapeIsPresent(edge) || !torsion)
    return false;

  try
  {
    Standard_Real      f, l;
    Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, f, l);
    if (curve.IsNull())
      return false;

    // Need 3rd derivative for torsion
    gp_Pnt pnt;
    gp_Vec d1, d2, d3;
    curve->D3(param, pnt, d1, d2, d3);

    // Torsion = (d1 x d2) . d3 / |d1 x d2|^2
    gp_Vec cross     = d1.Crossed(d2);
    double crossMag2 = cross.SquareMagnitude();
    if (crossMag2 < Precision::Confusion())
    {
      *torsion = 0.0;
      return true;
    }
    *torsion = cross.Dot(d3) / crossMag2;
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeGetPointAtParam(OCCTEdgeRef edge, double param, double* px, double* py, double* pz)
{
  if (!occtShapeIsPresent(edge) || !px || !py || !pz)
    return false;

  try
  {
    Standard_Real      f, l;
    Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, f, l);
    if (curve.IsNull())
      return false;

    gp_Pnt pnt;
    curve->D0(param, pnt);
    *px = pnt.X();
    *py = pnt.Y();
    *pz = pnt.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTEdgeGetCurveType(OCCTEdgeRef edge)
{
  if (!occtShapeIsPresent(edge))
    return 8; // Other

  try
  {
    BRepAdaptor_Curve adaptor(edge->edge);
    switch (adaptor.GetType())
    {
      case GeomAbs_Line:
        return 0;
      case GeomAbs_Circle:
        return 1;
      case GeomAbs_Ellipse:
        return 2;
      case GeomAbs_Hyperbola:
        return 3;
      case GeomAbs_Parabola:
        return 4;
      case GeomAbs_BezierCurve:
        return 5;
      case GeomAbs_BSplineCurve:
        return 6;
      case GeomAbs_OffsetCurve:
        return 7;
      default:
        return 8;
    }
  }
  catch (...)
  {
    return 8;
  }
}

// MARK: - Point Projection (v0.18.0)

#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>

OCCTSurfaceProjectionResult OCCTFaceProjectPoint(OCCTFaceRef face, double px, double py, double pz)
{
  OCCTSurfaceProjectionResult result = {};
  result.isValid                     = false;
  if (!occtShapeIsPresent(face))
    return result;

  try
  {
    Handle(Geom_Surface) surface = BRep_Tool::Surface(face->face);
    if (surface.IsNull())
      return result;

    double uMin, uMax, vMin, vMax;
    BRepTools::UVBounds(face->face, uMin, uMax, vMin, vMax);

    GeomAPI_ProjectPointOnSurf
      proj(gp_Pnt(px, py, pz), surface, uMin, uMax, vMin, vMax, Precision::Confusion());
    if (proj.NbPoints() == 0)
      return result;

    gp_Pnt nearest = proj.NearestPoint();
    result.px      = nearest.X();
    result.py      = nearest.Y();
    result.pz      = nearest.Z();
    proj.LowerDistanceParameters(result.u, result.v);
    result.distance = proj.LowerDistance();
    result.isValid  = true;
    return result;
  }
  catch (...)
  {
    return result;
  }
}

int32_t OCCTFaceProjectPointAll(OCCTFaceRef                  face,
                                double                       px,
                                double                       py,
                                double                       pz,
                                OCCTSurfaceProjectionResult* results,
                                int32_t                      maxResults)
{
  if (!occtShapeIsPresent(face) || !results || maxResults <= 0)
    return 0;

  try
  {
    Handle(Geom_Surface) surface = BRep_Tool::Surface(face->face);
    if (surface.IsNull())
      return 0;

    double uMin, uMax, vMin, vMax;
    BRepTools::UVBounds(face->face, uMin, uMax, vMin, vMax);

    GeomAPI_ProjectPointOnSurf
      proj(gp_Pnt(px, py, pz), surface, uMin, uMax, vMin, vMax, Precision::Confusion());

    int32_t count = std::min((int32_t)proj.NbPoints(), maxResults);
    for (int32_t i = 0; i < count; i++)
    {
      gp_Pnt pnt    = proj.Point(i + 1);
      results[i].px = pnt.X();
      results[i].py = pnt.Y();
      results[i].pz = pnt.Z();
      proj.Parameters(i + 1, results[i].u, results[i].v);
      results[i].distance = proj.Distance(i + 1);
      results[i].isValid  = true;
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

// Shares OCCTCurve3DProjectPoint's nearest-point-on-a-range implementation since #539. The defect
// here was the other half of that one: a bare GeomAPI_ProjectPointOnCurve honours the edge's range
// but reports extrema rather than minima, so it answered 11 for the point (0, -6, 0) against a
// half-circle edge whose nearest point is 7.81 away, and declined to answer at all (isValid
// false, surfacing as nil) whenever the nearest point was an end rather than a perpendicular
// foot, which is every point beyond the end of a straight edge. isValid now means what the header
// says it means: false only for an edge with no 3D curve to project onto.
OCCTCurveProjectionResult OCCTEdgeProjectPoint(OCCTEdgeRef edge, double px, double py, double pz)
{
  OCCTCurveProjectionResult result = {};
  result.isValid                   = false;
  if (!occtShapeIsPresent(edge))
    return result;

  try
  {
    Standard_Real      first, last;
    Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, first, last);
    if (curve.IsNull())
      return result;

    gp_Pnt nearest;
    if (!occtNearestPointOnCurveRange(curve,
                                      gp_Pnt(px, py, pz),
                                      first,
                                      last,
                                      Precision::Confusion(),
                                      &nearest,
                                      &result.parameter,
                                      &result.distance))
    {
      return result;
    }
    result.px      = nearest.X();
    result.py      = nearest.Y();
    result.pz      = nearest.Z();
    result.isValid = true;
    return result;
  }
  catch (...)
  {
    return result;
  }
}

// MARK: - Shape Proximity (v0.18.0)

#include <BRepExtrema_ShapeProximity.hxx>
#include <BRepExtrema_OverlapTool.hxx>

int32_t OCCTShapeProximity(OCCTShapeRef           shape1,
                           OCCTShapeRef           shape2,
                           double                 tolerance,
                           OCCTFaceProximityPair* outPairs,
                           int32_t                maxPairs,
                           double                 deflection)
{
  if (!shape1 || !shape2 || !outPairs || maxPairs <= 0)
    return 0;

  try
  {
    // BRepExtrema_ShapeProximity requires triangulated shapes
    BRepMesh_IncrementalMesh mesh1(shape1->shape, deflection);
    BRepMesh_IncrementalMesh mesh2(shape2->shape, deflection);

    BRepExtrema_ShapeProximity prox(shape1->shape, shape2->shape, (Standard_Real)tolerance);
    prox.Perform();

    if (!prox.IsDone())
      return 0;

    // Get overlapping face indices
    const auto& overlaps1 = prox.OverlapSubShapes1();
    int32_t     count     = 0;

    for (NCollection_DataMap<int, TColStd_PackedMapOfInteger>::Iterator it(overlaps1);
         it.More() && count < maxPairs;
         it.Next())
    {
      int32_t                           face1Idx = (int32_t)it.Key();
      const TColStd_PackedMapOfInteger& face2Set = it.Value();
      for (TColStd_PackedMapOfInteger::Iterator it2(face2Set); it2.More() && count < maxPairs;
           it2.Next())
      {
        outPairs[count].face1Index = face1Idx;
        outPairs[count].face2Index = (int32_t)it2.Key();
        count++;
      }
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

#include <BOPAlgo_CheckerSI.hxx>
#include <BOPAlgo_Alerts.hxx>
#include <BOPDS_DS.hxx>
#include <BOPDS_Pair.hxx>

bool OCCTShapeSelfIntersects(OCCTShapeRef shape)
{
  // BOPAlgo_CheckerSI::Perform dereferences a null TopoDS_Shape. Measured against the pinned
  // kernel, that is a SIGSEGV in a standalone process, for a default-constructed shape and for the
  // Nullify()d copy Shape.nullified hands back alike. Removing this guard takes the test binary
  // down on 12 of 15 runs, and on the other 3 returns HasErrors() instead, a wrong answer rather
  // than a fault. A signal would not reach the catch below, so refuse the shape here.
  if (!occtShapeIsPresent(shape))
    return false;

  try
  {
    BOPAlgo_CheckerSI    checker;
    TopTools_ListOfShape shapes;
    shapes.Append(shape->shape);
    checker.SetArguments(shapes);
    checker.Perform();

    // HasErrors() is BOPAlgo_Options' "did this algorithm fail" flag, not "did it find an
    // interference"; returning it as the answer was #1088. The result lives in
    // BOPDS_DS::Interferences(), walked below as BOPAlgo_ArgumentAnalyzer::TestSelfInterferences
    // walks it.
    //
    // The error test comes first, and it is what makes the map safe to read. Perform() reaches
    // PostTreat(), which is what leaves the map holding only genuine interferences, exactly when
    // HasErrors() is false; its one other error-free exit is a user break, and this function
    // installs no Message_ProgressIndicator, so that exit is unreachable and HasErrors() == false
    // means the run completed. Giving this call a timeout would break that: an interrupted run
    // leaves the pave filler's raw pairs in the map, and a clean box then reports three of them.
    if (checker.HasErrors())
      return false;

    const BOPDS_DS* ds = checker.PDS();
    if (!ds)
      return false;

    NCollection_Map<BOPDS_Pair>::Iterator it(ds->Interferences());
    for (; it.More(); it.Next())
    {
      int n1 = 0, n2 = 0;
      it.Value().Indices(n1, n2);
      // A pair involving a shape the pave filler created is not an interference of the input.
      if (ds->IsNewShape(n1) || ds->IsNewShape(n2))
        continue;
      return true;
    }
    return false;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTShapeInertiaProperties(OCCTShapeRef shape, OCCTInertiaProperties* outProps)
{
  if (!shape || !outProps)
    return false;
  try
  {
    GProp_GProps props;
    if (!occtVolumeMassProperties(shape->shape, props))
      return false;

    outProps->volume  = props.Mass();
    gp_Pnt cm         = props.CentreOfMass();
    outProps->centerX = cm.X();
    outProps->centerY = cm.Y();
    outProps->centerZ = cm.Z();

    gp_Mat mat           = props.MatrixOfInertia();
    outProps->inertia[0] = mat(1, 1);
    outProps->inertia[1] = mat(1, 2);
    outProps->inertia[2] = mat(1, 3);
    outProps->inertia[3] = mat(2, 1);
    outProps->inertia[4] = mat(2, 2);
    outProps->inertia[5] = mat(2, 3);
    outProps->inertia[6] = mat(3, 1);
    outProps->inertia[7] = mat(3, 2);
    outProps->inertia[8] = mat(3, 3);

    GProp_PrincipalProps pp = props.PrincipalProperties();
    double               Ix, Iy, Iz;
    pp.Moments(Ix, Iy, Iz);
    outProps->principalIx = Ix;
    outProps->principalIy = Iy;
    outProps->principalIz = Iz;

    gp_Vec v1                  = pp.FirstAxisOfInertia();
    gp_Vec v2                  = pp.SecondAxisOfInertia();
    gp_Vec v3                  = pp.ThirdAxisOfInertia();
    outProps->principalAxes[0] = v1.X();
    outProps->principalAxes[1] = v1.Y();
    outProps->principalAxes[2] = v1.Z();
    outProps->principalAxes[3] = v2.X();
    outProps->principalAxes[4] = v2.Y();
    outProps->principalAxes[5] = v2.Z();
    outProps->principalAxes[6] = v3.X();
    outProps->principalAxes[7] = v3.Y();
    outProps->principalAxes[8] = v3.Z();

    outProps->hasSymmetryAxis  = pp.HasSymmetryAxis();
    outProps->hasSymmetryPoint = pp.HasSymmetryPoint();

    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTShapeSurfaceInertiaProperties(OCCTShapeRef shape, OCCTInertiaProperties* outProps)
{
  if (!shape || !outProps)
    return false;
  try
  {
    GProp_GProps props;
    if (!occtSurfaceMassProperties(shape->shape, props))
      return false;

    outProps->volume  = props.Mass(); // Surface area in this context
    gp_Pnt cm         = props.CentreOfMass();
    outProps->centerX = cm.X();
    outProps->centerY = cm.Y();
    outProps->centerZ = cm.Z();

    gp_Mat mat           = props.MatrixOfInertia();
    outProps->inertia[0] = mat(1, 1);
    outProps->inertia[1] = mat(1, 2);
    outProps->inertia[2] = mat(1, 3);
    outProps->inertia[3] = mat(2, 1);
    outProps->inertia[4] = mat(2, 2);
    outProps->inertia[5] = mat(2, 3);
    outProps->inertia[6] = mat(3, 1);
    outProps->inertia[7] = mat(3, 2);
    outProps->inertia[8] = mat(3, 3);

    GProp_PrincipalProps pp = props.PrincipalProperties();
    double               Ix, Iy, Iz;
    pp.Moments(Ix, Iy, Iz);
    outProps->principalIx = Ix;
    outProps->principalIy = Iy;
    outProps->principalIz = Iz;

    gp_Vec v1                  = pp.FirstAxisOfInertia();
    gp_Vec v2                  = pp.SecondAxisOfInertia();
    gp_Vec v3                  = pp.ThirdAxisOfInertia();
    outProps->principalAxes[0] = v1.X();
    outProps->principalAxes[1] = v1.Y();
    outProps->principalAxes[2] = v1.Z();
    outProps->principalAxes[3] = v2.X();
    outProps->principalAxes[4] = v2.Y();
    outProps->principalAxes[5] = v2.Z();
    outProps->principalAxes[6] = v3.X();
    outProps->principalAxes[7] = v3.Y();
    outProps->principalAxes[8] = v3.Z();

    outProps->hasSymmetryAxis  = pp.HasSymmetryAxis();
    outProps->hasSymmetryPoint = pp.HasSymmetryPoint();

    return true;
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - Wire / Curve Properties (v0.9.0)

OCCTCurveInfo OCCTWireGetCurveInfo(OCCTWireRef wire)
{
  OCCTCurveInfo result = {};
  result.isValid       = false;
  if (!wire)
    return result;

  try
  {
    BRepAdaptor_CompCurve curve(wire->wire);

    // Get length: the same subdivided measurement OCCTWireGetLength makes, so the two
    // spellings of a wire's length cannot disagree on an elliptical edge. #603.
    result.length = occtAdaptorArcLength(curve, curve.FirstParameter(), curve.LastParameter());

    // Get closed/periodic status
    result.isClosed   = curve.IsClosed();
    result.isPeriodic = curve.IsPeriodic();

    // Get start point
    Standard_Real first   = curve.FirstParameter();
    Standard_Real last    = curve.LastParameter();
    gp_Pnt        startPt = curve.Value(first);
    gp_Pnt        endPt   = curve.Value(last);

    result.startX = startPt.X();
    result.startY = startPt.Y();
    result.startZ = startPt.Z();
    result.endX   = endPt.X();
    result.endY   = endPt.Y();
    result.endZ   = endPt.Z();

    result.isValid = true;
    return result;
  }
  catch (...)
  {
    return result;
  }
}

double OCCTWireGetLength(OCCTWireRef wire)
{
  if (!wire)
    return -1.0;

  try
  {
    BRepAdaptor_CompCurve curve(wire->wire);
    // A BRepAdaptor_CompCurve reports one GeomAbs_CN interval per edge span, so a wire made of
    // lines and circles was already exact, but one elliptical edge in it measured 1.485%
    // long, because that edge's span still got a single quadrature. #603.
    return occtAdaptorArcLength(curve, curve.FirstParameter(), curve.LastParameter());
  }
  catch (...)
  {
    return -1.0;
  }
}

bool OCCTWireGetPointAt(OCCTWireRef wire, double param, double* x, double* y, double* z)
{
  if (!wire || !x || !y || !z)
    return false;

  try
  {
    BRepAdaptor_CompCurve curve(wire->wire);
    Standard_Real         first = curve.FirstParameter();
    Standard_Real         last  = curve.LastParameter();

    // Map normalized parameter [0,1] to actual parameter range
    Standard_Real actualParam = first + param * (last - first);

    gp_Pnt pt = curve.Value(actualParam);
    *x        = pt.X();
    *y        = pt.Y();
    *z        = pt.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireGetTangentAt(OCCTWireRef wire, double param, double* tx, double* ty, double* tz)
{
  if (!wire || !tx || !ty || !tz)
    return false;

  try
  {
    BRepAdaptor_CompCurve curve(wire->wire);
    Standard_Real         first = curve.FirstParameter();
    Standard_Real         last  = curve.LastParameter();

    // Map normalized parameter [0,1] to actual parameter range
    Standard_Real actualParam = first + param * (last - first);

    gp_Pnt pt;
    gp_Vec tangent;
    curve.D1(actualParam, pt, tangent);

    // Normalize the tangent
    if (tangent.Magnitude() > 1e-10)
    {
      tangent.Normalize();
    }

    *tx = tangent.X();
    *ty = tangent.Y();
    *tz = tangent.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// #595: the -1.0 error sentinel became a bool, and the degenerate branch below stopped answering 0.
// This one already reached Swift as an optional, but only through -1.0, the null-derivative case
// returned 0.0, a straight wire's real curvature, so the optional never fired for the case that
// actually has no answer.
bool OCCTWireGetCurvatureAt(OCCTWireRef wire, double param, double* curvature)
{
  *curvature = 0.0;
  if (!wire)
    return false;

  try
  {
    BRepAdaptor_CompCurve curve(wire->wire);
    Standard_Real         first = curve.FirstParameter();
    Standard_Real         last  = curve.LastParameter();

    // Map normalized parameter [0,1] to actual parameter range
    Standard_Real actualParam = first + param * (last - first);

    // Get first and second derivatives
    gp_Pnt pt;
    gp_Vec d1, d2;
    curve.D2(actualParam, pt, d1, d2);

    // Curvature formula: κ = |d1 × d2| / |d1|³
    gp_Vec cross = d1.Crossed(d2);
    double d1Mag = d1.Magnitude();
    // A null first derivative is a cusp: the formula divides by it, and unlike
    // GeomLProp_CLProps this hand-rolled path has no RealLast() sentinel to report instead.
    // Nothing is the answer here, not zero.
    if (d1Mag < 1e-10)
      return false;

    *curvature = cross.Magnitude() / (d1Mag * d1Mag * d1Mag);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

OCCTCurvePoint OCCTWireGetCurvePointAt(OCCTWireRef wire, double param)
{
  OCCTCurvePoint result = {};
  result.isValid        = false;
  result.hasNormal      = false;
  if (!wire)
    return result;

  try
  {
    BRepAdaptor_CompCurve curve(wire->wire);
    Standard_Real         first = curve.FirstParameter();
    Standard_Real         last  = curve.LastParameter();

    // Map normalized parameter [0,1] to actual parameter range
    Standard_Real actualParam = first + param * (last - first);

    // Get position and derivatives
    gp_Pnt pt;
    gp_Vec d1, d2;
    curve.D2(actualParam, pt, d1, d2);

    result.posX = pt.X();
    result.posY = pt.Y();
    result.posZ = pt.Z();

    // Normalize tangent (d1)
    double d1Mag = d1.Magnitude();
    if (d1Mag > 1e-10)
    {
      gp_Vec tangent = d1.Divided(d1Mag);
      result.tanX    = tangent.X();
      result.tanY    = tangent.Y();
      result.tanZ    = tangent.Z();

      // Compute curvature: κ = |d1 × d2| / |d1|³
      gp_Vec cross     = d1.Crossed(d2);
      result.curvature = cross.Magnitude() / (d1Mag * d1Mag * d1Mag);

      // Compute principal normal if curvature is non-zero
      // Normal = (d1 × d2) × d1, normalized, pointing toward center of curvature
      if (result.curvature > 1e-10)
      {
        // Principal normal is perpendicular to tangent, in the osculating plane
        // N = (T' - (T' · T)T) / |T' - (T' · T)T|
        // For arc-length parameterization, T' is already perpendicular to T
        // For general parameterization, we use: N = d2 - (d2 · T)T, normalized
        gp_Vec T(result.tanX, result.tanY, result.tanZ);
        double d2DotT    = d2.Dot(T);
        gp_Vec normalDir = d2 - T.Multiplied(d2DotT);
        double normalMag = normalDir.Magnitude();
        if (normalMag > 1e-10)
        {
          normalDir.Divide(normalMag);
          result.normX     = normalDir.X();
          result.normY     = normalDir.Y();
          result.normZ     = normalDir.Z();
          result.hasNormal = true;
        }
      }
    }
    else
    {
      result.tanX = result.tanY = result.tanZ = 0.0;
      result.curvature                        = 0.0;
    }

    result.isValid = true;
    return result;
  }
  catch (...)
  {
    return result;
  }
}

// MARK: - BRepGProp_Face (v0.45)
bool OCCTFaceGetNaturalBounds(OCCTFaceRef face,
                              double*     uMin,
                              double*     uMax,
                              double*     vMin,
                              double*     vMax)
{
  if (!occtShapeIsPresent(face) || !uMin || !uMax || !vMin || !vMax)
    return false;
  try
  {
    BRepGProp_Face gpropFace(face->face);
    gpropFace.Bounds(*uMin, *uMax, *vMin, *vMax);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFaceEvaluateNormalAtUV(OCCTFaceRef face,
                                double      u,
                                double      v,
                                double*     px,
                                double*     py,
                                double*     pz,
                                double*     nx,
                                double*     ny,
                                double*     nz)
{
  if (!occtShapeIsPresent(face) || !px || !py || !pz || !nx || !ny || !nz)
    return false;
  try
  {
    BRepGProp_Face gpropFace(face->face);
    gp_Pnt         point;
    gp_Vec         normal;
    gpropFace.Normal(u, v, point, normal);
    *px = point.X();
    *py = point.Y();
    *pz = point.Z();
    *nx = normal.X();
    *ny = normal.Y();
    *nz = normal.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - GProp Principal Inertia (v0.46)
bool OCCTShapeVolumeInertia(OCCTShapeRef shape, OCCTVolumeInertiaResult* result)
{
  if (!shape || !result)
    return false;
  try
  {
    GProp_GProps props;
    if (!occtVolumeMassProperties(shape->shape, props))
      return false;

    result->volume = props.Mass();

    gp_Pnt com      = props.CentreOfMass();
    result->centerX = com.X();
    result->centerY = com.Y();
    result->centerZ = com.Z();

    // Matrix of inertia about center of mass. This used to recompute the whole framework into a
    // second GProp_GProps before reading it, which cost a second integration for an identical
    // answer. MatrixOfInertia() is already referenced to the centre of mass.
    gp_Mat mat         = props.MatrixOfInertia();
    result->inertia[0] = mat(1, 1);
    result->inertia[1] = mat(1, 2);
    result->inertia[2] = mat(1, 3);
    result->inertia[3] = mat(2, 1);
    result->inertia[4] = mat(2, 2);
    result->inertia[5] = mat(2, 3);
    result->inertia[6] = mat(3, 1);
    result->inertia[7] = mat(3, 2);
    result->inertia[8] = mat(3, 3);

    // Principal properties
    GProp_PrincipalProps principal = props.PrincipalProperties();
    double               I1, I2, I3;
    principal.Moments(I1, I2, I3);
    result->principalMoment1 = I1;
    result->principalMoment2 = I2;
    result->principalMoment3 = I3;

    const gp_Vec& a1 = principal.FirstAxisOfInertia();
    result->axis1X   = a1.X();
    result->axis1Y   = a1.Y();
    result->axis1Z   = a1.Z();

    const gp_Vec& a2 = principal.SecondAxisOfInertia();
    result->axis2X   = a2.X();
    result->axis2Y   = a2.Y();
    result->axis2Z   = a2.Z();

    const gp_Vec& a3 = principal.ThirdAxisOfInertia();
    result->axis3X   = a3.X();
    result->axis3Y   = a3.Y();
    result->axis3Z   = a3.Z();

    principal.RadiusOfGyration(result->gyrationRadius1,
                               result->gyrationRadius2,
                               result->gyrationRadius3);

    // Same `principal` object OCCTShapeInertiaProperties reads these from, #848.
    result->hasSymmetryAxis  = principal.HasSymmetryAxis();
    result->hasSymmetryPoint = principal.HasSymmetryPoint();

    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTShapeSurfaceInertia(OCCTShapeRef shape, OCCTSurfaceInertiaResult* result)
{
  if (!shape || !result)
    return false;
  try
  {
    GProp_GProps props;
    if (!occtSurfaceMassProperties(shape->shape, props))
      return false;

    result->area = props.Mass();

    gp_Pnt com      = props.CentreOfMass();
    result->centerX = com.X();
    result->centerY = com.Y();
    result->centerZ = com.Z();

    gp_Mat mat         = props.MatrixOfInertia();
    result->inertia[0] = mat(1, 1);
    result->inertia[1] = mat(1, 2);
    result->inertia[2] = mat(1, 3);
    result->inertia[3] = mat(2, 1);
    result->inertia[4] = mat(2, 2);
    result->inertia[5] = mat(2, 3);
    result->inertia[6] = mat(3, 1);
    result->inertia[7] = mat(3, 2);
    result->inertia[8] = mat(3, 3);

    GProp_PrincipalProps principal = props.PrincipalProperties();
    double               I1, I2, I3;
    principal.Moments(I1, I2, I3);
    result->principalMoment1 = I1;
    result->principalMoment2 = I2;
    result->principalMoment3 = I3;

    // Same `principal` object OCCTShapeSurfaceInertiaProperties reads these from, #848.
    result->hasSymmetryAxis  = principal.HasSymmetryAxis();
    result->hasSymmetryPoint = principal.HasSymmetryPoint();

    return true;
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - GeomLProp CL/SL Props (v0.63)
// --- GeomLProp_CLProps ---

OCCTCurveLocalProps OCCTGeomLPropCLProps(OCCTShapeRef edgeShape, double param)
{
  OCCTCurveLocalProps result = {};
  if (!edgeShape)
    return result;
  try
  {
    TopoDS_Edge        edge = TopoDS::Edge(edgeShape->shape);
    double             f, l;
    Handle(Geom_Curve) curve = BRep_Tool::Curve(edge, f, l);
    if (curve.IsNull())
      return result;

    // Was its own 1e-6 resolution, the third value the bridge passed to a GeomLProp_* props
    // (Precision::Confusion() from the canonical Curve3D/Surface entry points, 1e-10 from the
    // Local* family) and the same one #405 removed from OCCTSurfaceCurvatures, so this
    // reported a different answer than Edge.curvature3D(at:) for the same edge and parameter.
    GeomLProp_CLProps props = occtCurveLocalProps(curve, param, 2);
    gp_Pnt            pt    = props.Value();
    result.px               = pt.X();
    result.py               = pt.Y();
    result.pz               = pt.Z();
    // Asked before Curvature(), which is only meaningful once the tangent is established; the
    // old order relied on Curvature() raising, and it raises through
    // LProp_NotDefined_Raise_if, which compiles out under No_Exception.
    result.tangentDefined = props.IsTangentDefined();

    if (result.tangentDefined)
    {
      result.curvature = props.Curvature();

      gp_Dir tangent;
      props.Tangent(tangent);
      result.tx = tangent.X();
      result.ty = tangent.Y();
      result.tz = tangent.Z();

      // Rejects a cusp's RealLast() curvature too: Normal() raises on it, but
      // CentreOfCurvature() does not, and used to yield (nan, inf, nan) (#494).
      result.curvatureInvertible = occtCurveCurvatureIsInvertible(result.curvature);
      if (result.curvatureInvertible)
      {
        gp_Dir normal;
        props.Normal(normal);
        result.nx = normal.X();
        result.ny = normal.Y();
        result.nz = normal.Z();

        gp_Pnt center;
        props.CentreOfCurvature(center);
        result.cx = center.X();
        result.cy = center.Y();
        result.cz = center.Z();
      }
    }
  }
  catch (...)
  {
  }
  return result;
}

// --- GeomLProp_SLProps ---

OCCTSurfaceLocalProps OCCTGeomLPropSLProps(OCCTShapeRef faceShape, double u, double v)
{
  OCCTSurfaceLocalProps result = {};
  if (!faceShape)
    return result;
  try
  {
    TopoDS_Face          face = TopoDS::Face(faceShape->shape);
    Handle(Geom_Surface) surf = BRep_Tool::Surface(face);
    if (surf.IsNull())
      return result;

    // Same 1e-6 drift as OCCTGeomLPropCLProps above: this disagreed with
    // OCCTFaceGetGaussianCurvature/MeanCurvature/PrincipalCurvatures, which read the same
    // quantities off the same surface through Precision::Confusion() props (#494).
    GeomLProp_SLProps props = occtSurfaceLocalProps(surf, u, v, 2);
    gp_Pnt            pt    = props.Value();
    result.px               = pt.X();
    result.py               = pt.Y();
    result.pz               = pt.Z();

    result.normalDefined = props.IsNormalDefined();
    if (result.normalDefined)
    {
      gp_Dir n  = props.Normal();
      result.nx = n.X();
      result.ny = n.Y();
      result.nz = n.Z();
    }

    if (props.IsTangentUDefined())
    {
      gp_Dir tu;
      props.TangentU(tu);
      result.tuX = tu.X();
      result.tuY = tu.Y();
      result.tuZ = tu.Z();
    }
    if (props.IsTangentVDefined())
    {
      gp_Dir tv;
      props.TangentV(tv);
      result.tvX = tv.X();
      result.tvY = tv.Y();
      result.tvZ = tv.Z();
    }

    result.curvatureDefined = props.IsCurvatureDefined();
    if (result.curvatureDefined)
    {
      result.maxCurvature      = props.MaxCurvature();
      result.minCurvature      = props.MinCurvature();
      result.meanCurvature     = props.MeanCurvature();
      result.gaussianCurvature = props.GaussianCurvature();
      result.isUmbilic         = props.IsUmbilic();
    }
  }
  catch (...)
  {
  }
  return result;
}

// MARK: - BRepGProp_MeshCinert + MeshProps (v0.74)
// --- BRepGProp_MeshCinert ---

int32_t OCCTMeshCinertPreparePolygon(OCCTEdgeRef _Nonnull edge,
                                     double* _Nonnull coords,
                                     int32_t maxPoints)
{
  if (!edge)
    return 0;
  try
  {
    Handle(NCollection_HArray1<gp_Pnt>) polyPts;
    BRepGProp_MeshCinert::PreparePolygon(TopoDS::Edge(edge->edge), polyPts);
    if (polyPts.IsNull() || polyPts->Length() == 0)
      return 0;
    int32_t count = std::min((int32_t)polyPts->Length(), maxPoints);
    for (int32_t i = 0; i < count; i++)
    {
      const gp_Pnt& pt  = polyPts->Value(polyPts->Lower() + i);
      coords[i * 3]     = pt.X();
      coords[i * 3 + 1] = pt.Y();
      coords[i * 3 + 2] = pt.Z();
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

OCCTMeshCinertResult OCCTMeshCinertCompute(const double* _Nonnull coords, int32_t pointCount)
{
  OCCTMeshCinertResult result = {};
  if (pointCount < 2)
    return result;
  try
  {
    NCollection_Array1<gp_Pnt> points(1, pointCount);
    for (int32_t i = 0; i < pointCount; i++)
    {
      points.SetValue(i + 1, gp_Pnt(coords[i * 3], coords[i * 3 + 1], coords[i * 3 + 2]));
    }
    BRepGProp_MeshCinert cinert;
    cinert.SetLocation(gp_Pnt(0, 0, 0));
    cinert.Perform(points);
    result.mass    = cinert.Mass();
    gp_Pnt cm      = cinert.CentreOfMass();
    result.centerX = cm.X();
    result.centerY = cm.Y();
    result.centerZ = cm.Z();
  }
  catch (...)
  {
  }
  return result;
}

// --- BRepGProp_MeshProps ---

OCCTMeshPropsResult OCCTMeshPropsCompute(OCCTFaceRef _Nonnull face, OCCTMeshPropsType type)
{
  OCCTMeshPropsResult result = {};
  if (!face)
    return result;
  try
  {
    TopLoc_Location            loc;
    Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(TopoDS::Face(face->face), loc);
    if (tri.IsNull())
      return result;

    BRepGProp_MeshProps::BRepGProp_MeshObjType objType =
      (type == OCCTMeshPropsSurface) ? BRepGProp_MeshProps::Sinert : BRepGProp_MeshProps::Vinert;
    BRepGProp_MeshProps props(objType);
    props.SetLocation(gp_Pnt(0, 0, 0));
    props.Perform(tri, loc, TopoDS::Face(face->face).Orientation());
    result.mass    = props.Mass();
    gp_Pnt cm      = props.CentreOfMass();
    result.centerX = cm.X();
    result.centerY = cm.Y();
    result.centerZ = cm.Z();
  }
  catch (...)
  {
  }
  return result;
}

// MARK: - BRepGProp Cinert / Sinert / Vinert (v0.75)
// --- BRepGProp_Cinert ---

OCCTCurveInertiaResult OCCTBRepGPropCinert(OCCTEdgeRef _Nonnull edge)
{
  OCCTCurveInertiaResult result = {};
  if (!occtShapeIsPresent(edge))
    return result;
  try
  {
    BRepAdaptor_Curve curve(TopoDS::Edge(edge->edge));
    BRepGProp_Cinert  cinert(curve, gp_Pnt(0, 0, 0));
    result.mass    = cinert.Mass();
    gp_Pnt cm      = cinert.CentreOfMass();
    result.centerX = cm.X();
    result.centerY = cm.Y();
    result.centerZ = cm.Z();
  }
  catch (...)
  {
  }
  return result;
}

// --- BRepGProp_Sinert ---

OCCTFaceSurfaceInertia OCCTBRepGPropSinert(OCCTFaceRef _Nonnull face)
{
  OCCTFaceSurfaceInertia result = {};
  if (!occtShapeIsPresent(face))
    return result;
  try
  {
    BRepGProp_Face   gpropFace(TopoDS::Face(face->face));
    BRepGProp_Sinert sinert;
    sinert.SetLocation(gp_Pnt(0, 0, 0));
    sinert.Perform(gpropFace);
    result.mass    = sinert.Mass();
    gp_Pnt cm      = sinert.CentreOfMass();
    result.centerX = cm.X();
    result.centerY = cm.Y();
    result.centerZ = cm.Z();
  }
  catch (...)
  {
  }
  return result;
}

OCCTFaceSurfaceInertia OCCTBRepGPropSinertAdaptive(OCCTFaceRef _Nonnull face, double epsilon)
{
  OCCTFaceSurfaceInertia result = {};
  if (!occtShapeIsPresent(face))
    return result;
  try
  {
    BRepGProp_Face   gpropFace(TopoDS::Face(face->face));
    BRepGProp_Sinert sinert;
    sinert.SetLocation(gp_Pnt(0, 0, 0));
    double err     = sinert.Perform(gpropFace, epsilon);
    result.mass    = sinert.Mass();
    result.epsilon = err;
    gp_Pnt cm      = sinert.CentreOfMass();
    result.centerX = cm.X();
    result.centerY = cm.Y();
    result.centerZ = cm.Z();
  }
  catch (...)
  {
  }
  return result;
}

// --- BRepGProp_Vinert ---

OCCTFaceVolumeInertia OCCTBRepGPropVinert(OCCTFaceRef _Nonnull face)
{
  OCCTFaceVolumeInertia result = {};
  if (!occtShapeIsPresent(face))
    return result;
  try
  {
    BRepGProp_Face   gpropFace(TopoDS::Face(face->face));
    BRepGProp_Vinert vinert;
    vinert.SetLocation(gp_Pnt(0, 0, 0));
    vinert.Perform(gpropFace);
    result.mass    = vinert.Mass();
    gp_Pnt cm      = vinert.CentreOfMass();
    result.centerX = cm.X();
    result.centerY = cm.Y();
    result.centerZ = cm.Z();
  }
  catch (...)
  {
  }
  return result;
}

OCCTFaceVolumeInertia OCCTBRepGPropVinertPlane(OCCTFaceRef _Nonnull face,
                                               double planeNX,
                                               double planeNY,
                                               double planeNZ,
                                               double planeDist)
{
  OCCTFaceVolumeInertia result = {};
  if (!occtShapeIsPresent(face))
    return result;
  try
  {
    BRepGProp_Face gpropFace(TopoDS::Face(face->face));
    gp_Dir         normal(planeNX, planeNY, planeNZ);
    gp_Pln plane(gp_Pnt(normal.X() * planeDist, normal.Y() * planeDist, normal.Z() * planeDist),
                 normal);
    BRepGProp_Vinert vinert(gpropFace, plane, gp_Pnt(0, 0, 0));
    result.mass    = vinert.Mass();
    gp_Pnt cm      = vinert.CentreOfMass();
    result.centerX = cm.X();
    result.centerY = cm.Y();
    result.centerZ = cm.Z();
  }
  catch (...)
  {
  }
  return result;
}

// MARK: - BRepGProp_VinertGK (v0.79)
// --- BRepGProp_VinertGK ---
OCCTVinertGKResult OCCTBRepGPropVinertGK(OCCTShapeRef _Nonnull faceRef,
                                         double locX,
                                         double locY,
                                         double locZ,
                                         double tolerance,
                                         bool   computeCG)
{
  OCCTVinertGKResult result = {};
  try
  {
    const TopoDS_Shape& shape = *(const TopoDS_Shape*)faceRef;
    TopoDS_Face         face  = TopoDS::Face(shape);

    BRepGProp_Face bface(face);
    gp_Pnt         loc(locX, locY, locZ);

    BRepGProp_VinertGK vgk(bface, loc, tolerance, computeCG, false);
    result.mass         = vgk.Mass();
    result.errorReached = vgk.GetErrorReached();

    if (computeCG)
    {
      gp_Pnt cg      = vgk.CentreOfMass();
      result.centerX = cg.X();
      result.centerY = cg.Y();
      result.centerZ = cg.Z();
    }
  }
  catch (...)
  {
  }
  return result;
}

// MARK: - v0.97: BRepGProp_Domain
// MARK: - BRepGProp_Domain (v0.97.0)

#include <BRepGProp_Domain.hxx>

int32_t OCCTShapeFaceDomainEdgeCount(OCCTShapeRef shape, int32_t faceIndex)
{
  if (!shape)
    return 0;
  try
  {
    TopoDS_Face face = occtFaceAt(shape->shape, faceIndex);
    if (face.IsNull())
      return 0;

    BRepGProp_Domain domain(face);
    int              count = 0;
    domain.Init();
    while (domain.More())
    {
      count++;
      domain.Next();
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - v0.103/v0.104: GProp Element/Cylinder/Cone Properties
// MARK: - GProp Element Properties (v0.103.0)

#include <GProp_CelGProps.hxx>
#include <GProp_PGProps.hxx>
#include <GProp_SelGProps.hxx>
#include <GProp_VelGProps.hxx>

// GProp_CelGProps computes its centroid analytically rather than accumulating into a
// GProp_GProps framework, so a zero-*length* result is still a correct answer: a curve sampled
// over an empty parameter range has a mass of 0 and a centre at the point itself. What is NOT an
// answer is a rejected input. Both of these build a gp_Dir from caller data, and gp_Dir throws
// Standard_ConstructionError on a zero-length vector, two coincident endpoints here, a zero
// normal there, which the catch used to turn into mass 0 with a centre of (0,0,0). See #609.
bool OCCTGPropLineSegment(double  x1,
                          double  y1,
                          double  z1,
                          double  x2,
                          double  y2,
                          double  z2,
                          double* outLength,
                          double* cx,
                          double* cy,
                          double* cz)
{
  if (!outLength || !cx || !cy || !cz)
    return false;
  try
  {
    gp_Pnt          p1(x1, y1, z1), p2(x2, y2, z2);
    gp_Lin          line(p1, gp_Dir(gp_Vec(p1, p2)));
    double          u2 = p1.Distance(p2);
    GProp_CelGProps props(line, 0.0, u2, gp_Pnt(0, 0, 0));
    gp_Pnt          cm = props.CentreOfMass();
    *outLength         = props.Mass();
    *cx                = cm.X();
    *cy                = cm.Y();
    *cz                = cm.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTGPropCircularArc(double  centerX,
                          double  centerY,
                          double  centerZ,
                          double  normalX,
                          double  normalY,
                          double  normalZ,
                          double  radius,
                          double  u1,
                          double  u2,
                          double* outLength,
                          double* cx,
                          double* cy,
                          double* cz)
{
  if (!outLength || !cx || !cy || !cz)
    return false;
  try
  {
    gp_Ax2          ax(gp_Pnt(centerX, centerY, centerZ), gp_Dir(normalX, normalY, normalZ));
    gp_Circ         circ(ax, radius);
    GProp_CelGProps props(circ, u1, u2, gp_Pnt(0, 0, 0));
    gp_Pnt          cm = props.CentreOfMass();
    *outLength         = props.Mass();
    *cx                = cm.X();
    *cy                = cm.Y();
    *cz                = cm.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

double OCCTGPropPointSetCentroid(const double* points,
                                 int32_t       count,
                                 double*       cx,
                                 double*       cy,
                                 double*       cz)
{
  try
  {
    NCollection_Array1<gp_Pnt> pts(1, count);
    for (int i = 0; i < count; i++)
    {
      pts(i + 1) = gp_Pnt(points[i * 3], points[i * 3 + 1], points[i * 3 + 2]);
    }
    GProp_PGProps props(pts);
    gp_Pnt        cm = props.CentreOfMass();
    *cx              = cm.X();
    *cy              = cm.Y();
    *cz              = cm.Z();
    return props.Mass();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTGPropSphereSurface(double radius, double* cx, double* cy, double* cz)
{
  try
  {
    gp_Sphere       sphere(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), radius);
    GProp_SelGProps props(sphere, 0, 2 * M_PI, -M_PI / 2, M_PI / 2, gp_Pnt(0, 0, 0));
    gp_Pnt          cm = props.CentreOfMass();
    *cx                = cm.X();
    *cy                = cm.Y();
    *cz                = cm.Z();
    return props.Mass();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTGPropSphereVolume(double radius, double* cx, double* cy, double* cz)
{
  try
  {
    gp_Sphere       sphere(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), radius);
    GProp_VelGProps props(sphere, 0, 2 * M_PI, -M_PI / 2, M_PI / 2, gp_Pnt(0, 0, 0));
    gp_Pnt          cm = props.CentreOfMass();
    *cx                = cm.X();
    *cy                = cm.Y();
    *cz                = cm.Z();
    return props.Mass();
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - GProp Cylinder/Cone (v0.104.0)

double OCCTGPropCylinderSurface(double radius, double height)
{
  try
  {
    gp_Cylinder     cyl(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), radius);
    GProp_SelGProps props(cyl, 0, 2 * M_PI, 0, height, gp_Pnt(0, 0, 0));
    return props.Mass();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTGPropCylinderVolume(double radius, double height)
{
  try
  {
    gp_Cylinder     cyl(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), radius);
    GProp_VelGProps props(cyl, 0, 2 * M_PI, 0, height, gp_Pnt(0, 0, 0));
    return props.Mass();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTGPropConeSurface(double semiAngle, double refRadius, double height)
{
  try
  {
    gp_Cone         cone(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), semiAngle, refRadius);
    GProp_SelGProps props(cone, 0, 2 * M_PI, 0, height, gp_Pnt(0, 0, 0));
    return props.Mass();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTGPropConeVolume(double semiAngle, double refRadius, double height)
{
  try
  {
    gp_Cone         cone(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), semiAngle, refRadius);
    GProp_VelGProps props(cone, 0, 2 * M_PI, 0, height, gp_Pnt(0, 0, 0));
    return props.Mass();
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - v0.105: GProp Torus + GProp weighted point sets
// MARK: - GProp Torus (v0.105.0)

double OCCTGPropTorusSurface(double majorRadius, double minorRadius)
{
  try
  {
    gp_Torus        torus(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), majorRadius, minorRadius);
    GProp_SelGProps props(torus, 0, 2 * M_PI, 0, 2 * M_PI, gp_Pnt(0, 0, 0));
    return props.Mass();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTGPropTorusVolume(double majorRadius, double minorRadius)
{
  try
  {
    gp_Torus        torus(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), majorRadius, minorRadius);
    GProp_VelGProps props(torus, 0, 2 * M_PI, 0, 2 * M_PI, gp_Pnt(0, 0, 0));
    return props.Mass();
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - GProp weighted point sets (v0.105.0)

double OCCTGPropPointSetWeightedCentroid(const double* points,
                                         const double* weights,
                                         int32_t       count,
                                         double*       cx,
                                         double*       cy,
                                         double*       cz)
{
  *cx = 0;
  *cy = 0;
  *cz = 0;
  try
  {
    GProp_PGProps props;
    for (int32_t i = 0; i < count; i++)
    {
      gp_Pnt p(points[i * 3], points[i * 3 + 1], points[i * 3 + 2]);
      props.AddPoint(p, weights[i]);
    }
    gp_Pnt cm = props.CentreOfMass();
    *cx       = cm.X();
    *cy       = cm.Y();
    *cz       = cm.Z();
    return props.Mass();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTGPropBarycentre(const double* points, int32_t count, double* cx, double* cy, double* cz)
{
  if (!points || !cx || !cy || !cz)
    return false;
  try
  {
    GProp_PGProps props;
    for (int32_t i = 0; i < count; i++)
    {
      gp_Pnt p(points[i * 3], points[i * 3 + 1], points[i * 3 + 2]);
      props.AddPoint(p);
    }
    // An empty point set has no barycentre. GProp_PGProps reports (0,0,0) for one, which is a
    // point a caller cannot distinguish from the barycentre of a set centred on the origin.
    // Mass is the point count here, so testing it is exact. See #609.
    if (props.Mass() == 0.0)
      return false;
    gp_Pnt cm = props.CentreOfMass();
    *cx       = cm.X();
    *cy       = cm.Y();
    *cz       = cm.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - v0.111: BRepLProp_CLProps + SLProps
//
// #529: every construction below goes through occtEdgeLocalProps / occtFaceLocalProps, so these
// fifteen entry points ask "does this quantity exist here" at the same resolution as the
// GeomLProp_*-backed entry points a few hundred lines above, which #494 converged. They used to
// pass a literal 1e-6, a decade looser, and a decade is where the disagreement lives: measured on a
// cone face, OCCTFaceLPropMeanCurvature returned 0 at v = 1e-6 while OCCTFaceGetMeanCurvature
// returned -8.66e5 for the same point of the same face.
//
// MARK: - BRepLProp_CLProps (v0.111.0)

bool OCCTEdgeLPropValue(OCCTShapeRef edge, double param, double* x, double* y, double* z)
{
  *x = 0;
  *y = 0;
  *z = 0;
  if (!occtShapeIsPresent(edge))
    return false;
  try
  {
    BRepAdaptor_Curve ac(TopoDS::Edge(edge->shape));
    BRepLProp_CLProps props = occtEdgeLocalProps(ac, param, 2);
    gp_Pnt            p     = props.Value();
    *x                      = p.X();
    *y                      = p.Y();
    *z                      = p.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeLPropTangent(OCCTShapeRef edge, double param, double* dx, double* dy, double* dz)
{
  *dx = 0;
  *dy = 0;
  *dz = 0;
  if (!occtShapeIsPresent(edge))
    return false;
  try
  {
    BRepAdaptor_Curve ac(TopoDS::Edge(edge->shape));
    BRepLProp_CLProps props = occtEdgeLocalProps(ac, param, 2);
    if (!props.IsTangentDefined())
      return false;
    gp_Dir tan;
    props.Tangent(tan);
    *dx = tan.X();
    *dy = tan.Y();
    *dz = tan.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// #595, the same change the faceLProp* block above took in #583: an undefined tangent used to be
// spelled 0, which is a straight edge's real curvature. The degeneracy is reachable without
// constructing anything odd: a sphere carries a degenerate edge at each pole, with no 3D curve at
// all, and every Shape.edge* entry point walks edges without asking. A cusp still reports
// RealLast(), an answer rather than an absence.
bool OCCTEdgeLPropCurvature(OCCTShapeRef edge, double param, double* curvature)
{
  *curvature = 0;
  if (!occtShapeIsPresent(edge))
    return false;
  try
  {
    BRepAdaptor_Curve ac(TopoDS::Edge(edge->shape));
    BRepLProp_CLProps props = occtEdgeLocalProps(ac, param, 2);
    if (!props.IsTangentDefined())
      return false;
    *curvature = props.Curvature();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeLPropNormal(OCCTShapeRef edge, double param, double* dx, double* dy, double* dz)
{
  *dx = 0;
  *dy = 0;
  *dz = 0;
  if (!occtShapeIsPresent(edge))
    return false;
  try
  {
    BRepAdaptor_Curve ac(TopoDS::Edge(edge->shape));
    BRepLProp_CLProps props = occtEdgeLocalProps(ac, param, 2);
    if (!props.IsTangentDefined())
      return false;
    // The same gate OCCTEdgeGetNormal3D's neighbour uses. Normal() rejects both a null and a
    // RealLast() curvature itself, by throwing, so this only replaces an exception with a
    // return, but it is the predicate that makes the answer reportable rather than absorbed.
    if (!occtCurveCurvatureIsInvertible(props.Curvature()))
      return false;
    gp_Dir n;
    props.Normal(n);
    *dx = n.X();
    *dy = n.Y();
    *dz = n.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeLPropCentreOfCurvature(OCCTShapeRef edge,
                                    double       param,
                                    double*      x,
                                    double*      y,
                                    double*      z)
{
  *x = 0;
  *y = 0;
  *z = 0;
  if (!occtShapeIsPresent(edge))
    return false;
  try
  {
    BRepAdaptor_Curve ac(TopoDS::Edge(edge->shape));
    BRepLProp_CLProps props = occtEdgeLocalProps(ac, param, 2);
    if (!props.IsTangentDefined())
      return false;
    // Unlike Normal(), CentreOfCurvature() does *not* reject the RealLast() sentinel: it tests
    // only |Curvature()| <= resolution, which RealLast() passes, and then divides by the
    // myCurvature field the sentinel path never assigned. So a near-cusp used to come back as a
    // point of (nan, inf, nan). Measured, on a Bezier whose first two poles sit 1e-8 apart.
    // #494 found this on the Geom_ side; it is the same template.
    if (!occtCurveCurvatureIsInvertible(props.Curvature()))
      return false;
    gp_Pnt p;
    props.CentreOfCurvature(p);
    *x = p.X();
    *y = p.Y();
    *z = p.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeLPropD1(OCCTShapeRef edge, double param, double* d1x, double* d1y, double* d1z)
{
  *d1x = 0;
  *d1y = 0;
  *d1z = 0;
  if (!occtShapeIsPresent(edge))
    return false;
  try
  {
    BRepAdaptor_Curve ac(TopoDS::Edge(edge->shape));
    BRepLProp_CLProps props = occtEdgeLocalProps(ac, param, 1);
    const gp_Vec&     d1    = props.D1();
    *d1x                    = d1.X();
    *d1y                    = d1.Y();
    *d1z                    = d1.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - BRepLProp_SLProps (v0.111.0)

// #583: the six entry points that report a value below used to return it bare, with 0 (or the
// origin, for the point, or false for the umbilic predicate) standing in for every way of not
// having one: a null handle, a Shape that is not a face, and a point where IsCurvatureDefined() is
// false. That encoding has no spare value to spend: measured on the pinned kernel, a cylinder's
// Gaussian curvature and its maximum curvature are exactly 0 at every point of the surface, with
// the curvature defined, and a plane's four curvatures and its point at (0, 0) are all exactly zero
// as well. See Scripts/repro/583-lprop-zero-sentinel/.

bool OCCTFaceLPropValue(OCCTShapeRef face, double u, double v, double* x, double* y, double* z)
{
  *x = 0;
  *y = 0;
  *z = 0;
  if (!face)
    return false;
  try
  {
    BRepAdaptor_Surface as(TopoDS::Face(face->shape));
    BRepLProp_SLProps   props = occtFaceLocalProps(as, u, v, 2);
    gp_Pnt              p     = props.Value();
    *x                        = p.X();
    *y                        = p.Y();
    *z                        = p.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFaceLPropNormal(OCCTShapeRef face, double u, double v, double* dx, double* dy, double* dz)
{
  *dx = 0;
  *dy = 0;
  *dz = 0;
  if (!face)
    return false;
  try
  {
    BRepAdaptor_Surface as(TopoDS::Face(face->shape));
    BRepLProp_SLProps   props = occtFaceLocalProps(as, u, v, 2);
    if (!props.IsNormalDefined())
      return false;
    gp_Dir n = props.Normal();
    *dx      = n.X();
    *dy      = n.Y();
    *dz      = n.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFaceLPropMaxCurvature(OCCTShapeRef face, double u, double v, double* curvature)
{
  *curvature = 0;
  if (!face)
    return false;
  try
  {
    BRepAdaptor_Surface as(TopoDS::Face(face->shape));
    BRepLProp_SLProps   props = occtFaceLocalProps(as, u, v, 2);
    if (!props.IsCurvatureDefined())
      return false;
    *curvature = props.MaxCurvature();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFaceLPropMinCurvature(OCCTShapeRef face, double u, double v, double* curvature)
{
  *curvature = 0;
  if (!face)
    return false;
  try
  {
    BRepAdaptor_Surface as(TopoDS::Face(face->shape));
    BRepLProp_SLProps   props = occtFaceLocalProps(as, u, v, 2);
    if (!props.IsCurvatureDefined())
      return false;
    *curvature = props.MinCurvature();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFaceLPropMeanCurvature(OCCTShapeRef face, double u, double v, double* curvature)
{
  *curvature = 0;
  if (!face)
    return false;
  try
  {
    BRepAdaptor_Surface as(TopoDS::Face(face->shape));
    BRepLProp_SLProps   props = occtFaceLocalProps(as, u, v, 2);
    if (!props.IsCurvatureDefined())
      return false;
    *curvature = props.MeanCurvature();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFaceLPropGaussianCurvature(OCCTShapeRef face, double u, double v, double* curvature)
{
  *curvature = 0;
  if (!face)
    return false;
  try
  {
    BRepAdaptor_Surface as(TopoDS::Face(face->shape));
    BRepLProp_SLProps   props = occtFaceLocalProps(as, u, v, 2);
    if (!props.IsCurvatureDefined())
      return false;
    *curvature = props.GaussianCurvature();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFaceLPropIsUmbilic(OCCTShapeRef face, double u, double v, bool* isUmbilic)
{
  *isUmbilic = false;
  if (!face)
    return false;
  try
  {
    BRepAdaptor_Surface as(TopoDS::Face(face->shape));
    BRepLProp_SLProps   props = occtFaceLocalProps(as, u, v, 2);
    // The return is definedness, not the answer: without this the caller could not tell a
    // cylinder (genuinely not umbilic) from a cone apex (no principal curvatures to compare).
    if (!props.IsCurvatureDefined())
      return false;
    *isUmbilic = props.IsUmbilic();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFaceLPropTangentU(OCCTShapeRef face,
                           double       u,
                           double       v,
                           double*      dx,
                           double*      dy,
                           double*      dz)
{
  *dx = 0;
  *dy = 0;
  *dz = 0;
  if (!face)
    return false;
  try
  {
    BRepAdaptor_Surface as(TopoDS::Face(face->shape));
    BRepLProp_SLProps   props = occtFaceLocalProps(as, u, v, 2);
    if (!props.IsTangentUDefined())
      return false;
    gp_Dir tan;
    props.TangentU(tan);
    *dx = tan.X();
    *dy = tan.Y();
    *dz = tan.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFaceLPropTangentV(OCCTShapeRef face,
                           double       u,
                           double       v,
                           double*      dx,
                           double*      dy,
                           double*      dz)
{
  *dx = 0;
  *dy = 0;
  *dz = 0;
  if (!face)
    return false;
  try
  {
    BRepAdaptor_Surface as(TopoDS::Face(face->shape));
    BRepLProp_SLProps   props = occtFaceLocalProps(as, u, v, 2);
    if (!props.IsTangentVDefined())
      return false;
    gp_Dir tan;
    props.TangentV(tan);
    *dx = tan.X();
    *dy = tan.Y();
    *dz = tan.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - v0.114: Shape mass properties expansion
// --- Shape mass properties expansion ---

bool OCCTShapeLinearProperties(OCCTShapeRef shape,
                               double*      length,
                               double*      cx,
                               double*      cy,
                               double*      cz)
{
  if (!shape || !length || !cx || !cy || !cz)
    return false;
  try
  {
    GProp_GProps props;
    if (!occtLinearMassProperties(shape->shape, props))
      return false;
    gp_Pnt com = props.CentreOfMass();
    *length    = props.Mass();
    *cx        = com.X();
    *cy        = com.Y();
    *cz        = com.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTShapeMomentOfInertia(OCCTShapeRef shape,
                              double*      ixx,
                              double*      iyy,
                              double*      izz,
                              double*      ixy,
                              double*      ixz,
                              double*      iyz)
{
  if (!shape || !ixx || !iyy || !izz || !ixy || !ixz || !iyz)
    return false;
  try
  {
    GProp_GProps props;
    if (!occtVolumeMassProperties(shape->shape, props))
      return false;
    gp_Mat mat = props.MatrixOfInertia();
    *ixx       = mat(1, 1);
    *iyy       = mat(2, 2);
    *izz       = mat(3, 3);
    *ixy       = mat(1, 2);
    *ixz       = mat(1, 3);
    *iyz       = mat(2, 3);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTShapePrincipalAxes(OCCTShapeRef shape, double* axes9)
{
  if (!shape || !axes9)
    return false;
  try
  {
    GProp_GProps props;
    // Without a mass test this hands back the identity basis for anything with no volume:
    // math_Jacobi on the zero inertia matrix returns three orthonormal eigenvectors, which
    // read as a perfectly plausible answer. See #609.
    if (!occtVolumeMassProperties(shape->shape, props))
      return false;
    GProp_PrincipalProps pp = props.PrincipalProperties();
    const gp_Vec&        v1 = pp.FirstAxisOfInertia();
    const gp_Vec&        v2 = pp.SecondAxisOfInertia();
    const gp_Vec&        v3 = pp.ThirdAxisOfInertia();
    axes9[0]                = v1.X();
    axes9[1]                = v1.Y();
    axes9[2]                = v1.Z();
    axes9[3]                = v2.X();
    axes9[4]                = v2.Y();
    axes9[5]                = v2.Z();
    axes9[6]                = v3.X();
    axes9[7]                = v3.Y();
    axes9[8]                = v3.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTShapeRadiusOfGyration(OCCTShapeRef shape,
                               double       ax,
                               double       ay,
                               double       az,
                               double       dx,
                               double       dy,
                               double       dz,
                               double*      outRadius)
{
  if (!shape || !outRadius)
    return false;
  try
  {
    GProp_GProps props;
    // GProp_GProps::RadiusOfGyration is sqrt(MomentOfInertia(A) / dim) with no guard, so a
    // zero-mass framework returns NaN rather than a zero. Its GProp_PrincipalProps sibling
    // does guard (`if (0.0e0 != dim)`), which is why the radii-triple read 0 from the same
    // framework that made this return NaN. See #609.
    if (!occtVolumeMassProperties(shape->shape, props))
      return false;
    gp_Ax1 axis(gp_Pnt(ax, ay, az), gp_Dir(dx, dy, dz));
    *outRadius = props.RadiusOfGyration(axis);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - Measurement & Analysis (v0.7.0)

#include <Bnd_Box.hxx>
#include <BRepBndLib.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopExp.hxx>

OCCTShapeProperties OCCTShapeGetProperties(OCCTShapeRef shape, double density)
{
  OCCTShapeProperties result = {};
  result.isValid             = false;

  if (!shape)
    return result;

  try
  {
    // Volume + centre of mass. Without a closed volume there is no mass, no centre of mass and
    // no inertia tensor, so the whole framework is empty and the caller gets nil.
    GProp_GProps volumeProps;
    if (!occtVolumeMassProperties(shape->shape, volumeProps))
      return result;

    result.volume = volumeProps.Mass();
    result.mass   = result.volume * density;

    gp_Pnt com     = volumeProps.CentreOfMass();
    result.centerX = com.X();
    result.centerY = com.Y();
    result.centerZ = com.Z();

    // Inertia matrix (relative to center of mass)
    gp_Mat inertia = volumeProps.MatrixOfInertia();
    result.ixx     = inertia.Value(1, 1) * density;
    result.ixy     = inertia.Value(1, 2) * density;
    result.ixz     = inertia.Value(1, 3) * density;
    result.iyx     = inertia.Value(2, 1) * density;
    result.iyy     = inertia.Value(2, 2) * density;
    result.iyz     = inertia.Value(2, 3) * density;
    result.izx     = inertia.Value(3, 1) * density;
    result.izy     = inertia.Value(3, 2) * density;
    result.izz     = inertia.Value(3, 3) * density;

    // Surface area
    GProp_GProps surfaceProps;
    BRepGProp::SurfaceProperties(shape->shape, surfaceProps);
    result.surfaceArea = surfaceProps.Mass();

    result.isValid = true;
  }
  catch (...)
  {
    // Return with isValid = false
  }

  return result;
}

bool OCCTShapeGetVolume(OCCTShapeRef shape, double* outVolume)
{
  if (!shape || !outVolume)
    return false;

  occtEnsureSignals();
  try
  {
    OCC_CATCH_SIGNALS
    GProp_GProps props;
    if (!occtVolumeMassProperties(shape->shape, props))
      return false;
    *outVolume = props.Mass();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTShapeSignedVolumeFlux(OCCTShapeRef shape, double* outFlux)
{
  if (!shape || !outFlux)
    return false;

  occtEnsureSignals();
  try
  {
    OCC_CATCH_SIGNALS
    GProp_GProps props;
    // Deliberately NOT occtVolumeMassProperties: this is the divergence integral with
    // OnlyClosed left at its default, which is exactly what the strict volume path refuses.
    //
    // The two want different things. As a *measurement* the open-surface result is worthless,
    // which is why OCCTShapeGetVolume refuses it. As an *orientation signal* it is sound for
    // any orientable surface, closed or not, because reversing the surface negates the flux.
    // Measured on five faces of a 10x20x30 box: +4800 forward, -4800 reversed. Shape.sweep
    // relies on that to normalise a pipe whose faces point inward (#170), and the pipe it
    // produces is an open shell, so a closed-only test would silently stop normalising it.
    // See #609.
    BRepGProp::VolumeProperties(shape->shape, props);
    *outFlux = props.Mass();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

double OCCTShapeGetSurfaceArea(OCCTShapeRef shape)
{
  if (!shape)
    return -1.0;

  try
  {
    GProp_GProps props;
    BRepGProp::SurfaceProperties(shape->shape, props);
    return props.Mass();
  }
  catch (...)
  {
    return -1.0;
  }
}

bool OCCTShapeGetCenterOfMass(OCCTShapeRef shape, double* outX, double* outY, double* outZ)
{
  if (!shape || !outX || !outY || !outZ)
    return false;

  try
  {
    GProp_GProps props;
    if (!occtVolumeMassProperties(shape->shape, props))
      return false;

    gp_Pnt com = props.CentreOfMass();
    *outX      = com.X();
    *outY      = com.Y();
    *outZ      = com.Z();

    return true;
  }
  catch (...)
  {
    return false;
  }
}

OCCTDistanceResult OCCTShapeDistance(OCCTShapeRef shape1, OCCTShapeRef shape2, double deflection)
{
  OCCTDistanceResult result = {};
  result.isValid            = false;

  if (!shape1 || !shape2)
    return result;

  try
  {
    BRepExtrema_DistShapeShape distCalc(shape1->shape, shape2->shape, deflection);

    if (distCalc.IsDone() && distCalc.NbSolution() > 0)
    {
      result.distance      = distCalc.Value();
      result.solutionCount = distCalc.NbSolution();

      // Get first solution points
      gp_Pnt p1 = distCalc.PointOnShape1(1);
      gp_Pnt p2 = distCalc.PointOnShape2(1);

      result.p1x = p1.X();
      result.p1y = p1.Y();
      result.p1z = p1.Z();
      result.p2x = p2.X();
      result.p2y = p2.Y();
      result.p2z = p2.Z();

      result.isValid = true;
    }
  }
  catch (...)
  {
    // Return with isValid = false
  }

  return result;
}

bool OCCTShapeIntersects(OCCTShapeRef shape1, OCCTShapeRef shape2, double tolerance)
{
  if (!shape1 || !shape2)
    return false;

  try
  {
    BRepExtrema_DistShapeShape distCalc(shape1->shape, shape2->shape, tolerance);

    if (distCalc.IsDone() && distCalc.NbSolution() > 0)
    {
      return distCalc.Value() <= tolerance;
    }
    return false;
  }
  catch (...)
  {
    return false;
  }
}

// The three vertex accessors below read the shared sub-shape enumeration (occtMapSubShapes,
// OCCTBridge_Internal.h), so "a vertex" here means what it means everywhere else in the bridge:
// one entry per distinct vertex, not one per occurrence in the topology tree (#502).

int32_t OCCTShapeGetVertexCount(OCCTShapeRef shape)
{
  return OCCTShapeGetSubShapeCount(shape, TopAbs_VERTEX);
}

bool OCCTShapeGetVertexAt(OCCTShapeRef shape,
                          int32_t      index,
                          double*      outX,
                          double*      outY,
                          double*      outZ)
{
  if (!shape || !outX || !outY || !outZ)
    return false;

  try
  {
    TopoDS_Shape vertex = occtSubShapeAt(shape->shape, TopAbs_VERTEX, index);
    if (vertex.IsNull())
      return false;

    gp_Pnt point = BRep_Tool::Pnt(TopoDS::Vertex(vertex));
    *outX        = point.X();
    *outY        = point.Y();
    *outZ        = point.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTShapeGetVertices(OCCTShapeRef shape, double* outVertices)
{
  if (!shape || !outVertices)
    return 0;

  try
  {
    TopTools_IndexedMapOfShape vertexMap;
    int32_t                    count = occtMapSubShapes(shape->shape, TopAbs_VERTEX, vertexMap);
    for (int32_t i = 0; i < count; i++)
    {
      gp_Pnt point = BRep_Tool::Pnt(TopoDS::Vertex(vertexMap(i + 1))); // 1-based

      outVertices[i * 3]     = point.X();
      outVertices[i * 3 + 1] = point.Y();
      outVertices[i * 3 + 2] = point.Z();
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

// MARK: - Bounds

// #943: returns false when the box is void, matching OCCTShapeBoundingBox/
// OCCTShapeBoundingBoxOptimal. The six doubles cannot carry the distinction on their own: a void
// shape and a genuinely zero-size shape at the world origin both serialize to six zeros, so a
// Swift caller reading only the values has to guess. Both this and the two entry points above now
// share occtComputeBoundingBox (OCCTBridge_Internal.h), which is the single place that decides
// void-vs-measured; before #834 this was the only bounds entry point with no IsVoid() check at
// all, and before #943 the guard it gained still could not be reported to the caller.
//
// The box itself is unchanged: BRepBndLib::Add with useTriangulation, exactly as
// OCCTShapeBoundingBox computes it.
bool OCCTShapeGetBounds(OCCTShapeRef shape,
                        double*      minX,
                        double*      minY,
                        double*      minZ,
                        double*      maxX,
                        double*      maxY,
                        double*      maxZ)
{
  if (!minX || !minY || !minZ || !maxX || !maxY || !maxZ)
    return false;
  *minX = *minY = *minZ = *maxX = *maxY = *maxZ = 0.0;
  if (!shape)
    return false;
  return occtComputeBoundingBox(shape->shape,
                                /*optimal=*/false,
                                /*useTriangulation=*/true,
                                /*useShapeTolerance=*/false,
                                *minX,
                                *minY,
                                *minZ,
                                *maxX,
                                *maxY,
                                *maxZ);
}
