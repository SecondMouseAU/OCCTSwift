// Epic #766, FillingSupportFaceTests.swift: kernel parity for the geometric claims of its nineteen
// tests. The fixture is BRepPrimAPI_MakeSphere(gp_Ax2(O, Z), 10, -pi/2, 50 deg), the rim its
// topmost closed edge (the circle at z = 10 sin 50 deg), the wall the rim's adjacent face. Each fill
// is BRepOffsetAPI_MakeFilling(3, 15, 2, false, 1e-5, 1e-4, 0.01, 0.1, maxDeg, 9) as
// occtFillingMakeBuilder builds it, with each edge added the way occtFillingAddConstraint adds it
// (C0 face-less; above C0 with the wall as support; GeomAbs_G1 for .g1 and GeomAbs_C1 for .g2).
// Printed: the result's z extent (Bnd_Box) and, for the degree cap, the surface degrees.
#include <BRepAdaptor_Surface.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepOffsetAPI_MakeFilling.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Tool.hxx>
#include <Bnd_Box.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_Surface.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>
#include <cstdio>

static double zext(const TopoDS_Shape& s)
{
  Bnd_Box b;
  BRepBndLib::Add(s, b);
  double x0, y0, z0, x1, y1, z1;
  b.Get(x0, y0, z0, x1, y1, z1);
  return z1 - z0;
}

static void result(const char* name, BRepOffsetAPI_MakeFilling& f)
{
  try
  {
    f.Build();
    if (!f.IsDone())
    {
      printf("%s: not done\n", name);
      return;
    }
    TopoDS_Face face = TopoDS::Face(f.Shape());
    Handle(Geom_BSplineSurface) bs = Handle(Geom_BSplineSurface)::DownCast(BRep_Tool::Surface(face));
    printf("%s: z extent (Bnd_Box, with its enlargement)=%.6g", name, zext(face));
    if (!bs.IsNull())
      printf(" degree=%dx%d", bs->UDegree(), bs->VDegree());
    printf("\n");
  }
  catch (Standard_Failure& e)
  {
    printf("%s: threw %s\n", name, e.GetMessageString());
  }
}

int main()
{
  TopoDS_Shape bowl = BRepPrimAPI_MakeSphere(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10, -M_PI / 2, 50.0 * M_PI / 180.0).Shape();
  TopTools_IndexedMapOfShape edges;
  TopExp::MapShapes(bowl, TopAbs_EDGE, edges);
  TopoDS_Edge rim;
  double      best = -1e9;
  for (int i = 1; i <= edges.Extent(); i++)
  {
    TopoDS_Edge e = TopoDS::Edge(edges(i));
    if (!BRep_Tool::IsClosed(e) && !(BRep_Tool::Pnt(TopExp::FirstVertex(e)).Distance(BRep_Tool::Pnt(TopExp::LastVertex(e))) < 1e-7))
      continue;
    if (BRep_Tool::Degenerated(e))
      continue;
    Bnd_Box b;
    BRepBndLib::Add(e, b);
    double x0, y0, z0, x1, y1, z1;
    b.Get(x0, y0, z0, x1, y1, z1);
    if (z1 > best)
    {
      best = z1;
      rim  = e;
    }
  }
  TopTools_IndexedDataMapOfShapeListOfShape ef;
  TopExp::MapShapesAndAncestors(bowl, TopAbs_EDGE, TopAbs_FACE, ef);
  TopoDS_Face wall = TopoDS::Face(ef.FindFromKey(rim).First());
  printf("rim: z=%.9g\n", BRep_Tool::Pnt(TopExp::FirstVertex(rim)).Z());

  auto mk = [](int maxDeg) { return BRepOffsetAPI_MakeFilling(3, 15, 2, false, 1e-5, 1e-4, 0.01, 0.1, maxDeg, 9); };
  {
    auto f = mk(8);
    f.Add(rim, GeomAbs_C0, true);
    result("flat (.g0 rim)", f);
  }
  {
    auto f = mk(8);
    f.Add(rim, wall, GeomAbs_G1, true);
    result("tangent (.g1 rim, wall support)", f);
  }
  {
    auto f = mk(8);
    f.Add(rim, wall, GeomAbs_C1, true);
    result("curvature (.g2 -> GeomAbs_C1, wall support)", f);
  }
  {
    auto f = mk(3);
    f.Add(rim, wall, GeomAbs_G1, true);
    result("tangent, maxDegree 3", f);
  }
  {
    auto f = mk(8);
    f.Add(rim, GeomAbs_C0, true);
    f.Add(BRepBuilderAPI_MakeEdge(gp_Pnt(-5, 0, 10), gp_Pnt(5, 0, 10)).Edge(), GeomAbs_C0, false);
    result("rim + interior line (not bound)", f);
  }
  {
    auto        f  = mk(8);
    TopoDS_Wire sq = BRepBuilderAPI_MakePolygon(gp_Pnt(-5, -5, 0), gp_Pnt(5, -5, 0), gp_Pnt(5, 5, 0), gp_Pnt(-5, 5, 0), true).Wire();
    for (TopExp_Explorer e(sq, TopAbs_EDGE); e.More(); e.Next())
      f.Add(TopoDS::Edge(e.Current()), GeomAbs_C0, true);
    result("free-standing square, degraded to C0", f);
  }
  {
    auto        f  = mk(8);
    TopoDS_Wire sq = BRepBuilderAPI_MakePolygon(gp_Pnt(-5, -5, 0), gp_Pnt(5, -5, 0), gp_Pnt(5, 5, 0), gp_Pnt(-5, 5, 0), true).Wire();
    try
    {
      for (TopExp_Explorer e(sq, TopAbs_EDGE); e.More(); e.Next())
        f.Add(TopoDS::Edge(e.Current()), GeomAbs_G1, true);
      result("free-standing square at G1 face-less (the pre-#1503 path)", f);
    }
    catch (Standard_Failure& e)
    {
      printf("free-standing square at G1 face-less (the pre-#1503 path): threw %s\n", e.GetMessageString());
    }
  }
  return 0;
}
