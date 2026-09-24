// Epic #766, AdvancedPlateSurfaceTests.swift: kernel parity for the eight tests.
// Same inputs as the Swift tests, straight to OCCT, mirroring OCCTShapePlatePointsAdvanced and
// OCCTShapePlateMixed: GeomPlate_BuildPlateSurface(degree, nbPtsOnCur, nbIter) with one
// GeomPlate_PointConstraint per point (and one GeomPlate_CurveConstraint per wire edge), then
// GeomPlate_MakeApprox(plate, tol, 20, 8, tol * 0.1, 0, GeomAbs_C1) as occtPlateApproxSurface
// calls it, BRepBuilderAPI_MakeFace, BRepGProp::SurfaceProperties for the area, and
// BRepExtrema_DistShapeShape for each constraint point's distance to the face.
#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <GeomPlate_BuildPlateSurface.hxx>
#include <GeomPlate_CurveConstraint.hxx>
#include <GeomPlate_MakeApprox.hxx>
#include <GeomPlate_PointConstraint.hxx>
#include <GeomPlate_Surface.hxx>
#include <Geom_BSplineSurface.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Wire.hxx>
#include <TopoDS_Edge.hxx>
#include <cstdio>
#include <vector>

struct P
{
  double x, y, z;
};

static TopoDS_Face finish(GeomPlate_BuildPlateSurface& b, double tol, bool& ok)
{
  ok = false;
  b.Perform();
  if (!b.IsDone())
    return TopoDS_Face();
  Handle(GeomPlate_Surface) s = b.Surface();
  if (s.IsNull())
    return TopoDS_Face();
  GeomPlate_MakeApprox        approx(s, tol, 20, 8, tol * 0.1, 0, GeomAbs_C1);
  Handle(Geom_BSplineSurface) bs = approx.Surface();
  if (bs.IsNull())
    return TopoDS_Face();
  BRepBuilderAPI_MakeFace mf(bs, tol);
  if (!mf.IsDone())
    return TopoDS_Face();
  ok = true;
  return mf.Face();
}

static void report(const char* name, const TopoDS_Face& f, bool ok, const std::vector<P>& pts)
{
  if (!ok)
  {
    printf("%s: face=nil\n", name);
    return;
  }
  GProp_GProps g;
  BRepGProp::SurfaceProperties(f, g);
  printf("%s: face=ok area=%.17g", name, g.Mass());
  double worst = 0;
  for (const P& p : pts)
  {
    BRepExtrema_DistShapeShape d(BRepBuilderAPI_MakeVertex(gp_Pnt(p.x, p.y, p.z)).Vertex(), f);
    if (d.IsDone() && d.Value() > worst)
      worst = d.Value();
  }
  printf(" maxPointDistance=%.3g\n", worst);
}

static void points(const char*             name,
                   const std::vector<P>&   pts,
                   const std::vector<int>& orders,
                   int                     deg    = 3,
                   int                     nbPts  = 15,
                   int                     nbIter = 2,
                   double                  tol    = 0.01)
{
  try
  {
    GeomPlate_BuildPlateSurface b(deg, nbPts, nbIter);
    for (size_t i = 0; i < pts.size(); i++)
      b.Add(new GeomPlate_PointConstraint(gp_Pnt(pts[i].x, pts[i].y, pts[i].z), orders[i]));
    bool        ok;
    TopoDS_Face f = finish(b, tol, ok);
    report(name, f, ok, pts);
  }
  catch (Standard_Failure& e)
  {
    printf("%s: threw %s\n", name, e.GetMessageString());
  }
}

int main()
{
  points("platePointsAdvancedG0",
         {{0, 0, 0}, {10, 0, 1}, {10, 10, 2}, {0, 10, 1}, {5, 5, 3}},
         {0, 0, 0, 0, 0});
  // The Swift layer refuses .g1 before the bridge is reached (#1460). This is what the kernel
  // does when it is not refused: the tangent-free order-1 point constraint is accepted.
  points("platePointsMixedOrders(unrefused)",
         {{0, 0, 0}, {10, 0, 0}, {10, 10, 0}, {0, 10, 0}, {5, 5, 2}},
         {0, 1, 0, 1, 0});
  points("platePointsCustomParams",
         {{0, 0, 0},
          {5, 0, 1},
          {10, 0, 0},
          {0, 5, 1},
          {5, 5, 3},
          {10, 5, 1},
          {0, 10, 0},
          {5, 10, 1},
          {10, 10, 0}},
         std::vector<int>(9, 0),
         4,
         20,
         3,
         0.001);
  // Mismatch and too-few are refused in Swift before the bridge. The kernel on two points:
  points("platePointsTooFew(unrefused)", {{0, 0, 0}, {1, 0, 0}}, {0, 0});
  points("plateAdvancedArea",
         {{0, 0, 0}, {10, 0, 0}, {10, 10, 0}, {0, 10, 0}, {5, 5, 5}},
         std::vector<int>(5, 0));

  // Mixed: two points plus the closed square wire (Wire.path: one MakeEdge per segment).
  try
  {
    GeomPlate_BuildPlateSurface b(3, 15, 2);
    b.Add(new GeomPlate_PointConstraint(gp_Pnt(5, 5, 3), 0));
    b.Add(new GeomPlate_PointConstraint(gp_Pnt(2, 8, 1), 0));
    gp_Pnt c[4] = {gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0), gp_Pnt(0, 10, 0)};
    BRepBuilderAPI_MakeWire mw;
    for (int i = 0; i < 4; i++)
      mw.Add(BRepBuilderAPI_MakeEdge(c[i], c[(i + 1) % 4]).Edge());
    for (TopExp_Explorer e(mw.Wire(), TopAbs_EDGE); e.More(); e.Next())
    {
      BRepAdaptor_Curve a(TopoDS::Edge(e.Current()));
      b.Add(new GeomPlate_CurveConstraint(new BRepAdaptor_Curve(a), 0));
    }
    bool        ok;
    TopoDS_Face f = finish(b, 0.01, ok);
    report("plateMixedPointsAndCurves",
           f,
           ok,
           {{5, 5, 3}, {2, 8, 1}, {0, 0, 0}, {10, 0, 0}, {10, 10, 0}, {0, 10, 0}, {5, 0, 0}});
  }
  catch (Standard_Failure& e)
  {
    printf("plateMixedPointsAndCurves: threw %s\n", e.GetMessageString());
  }
  points("plateMixedPointsOnly", {{0, 0, 0}, {10, 0, 1}, {10, 10, 2}, {0, 10, 1}}, {0, 0, 0, 0});
  return 0;
}
