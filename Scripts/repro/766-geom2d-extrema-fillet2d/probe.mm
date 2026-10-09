// #1979 kernel parity for Extrema2dTests, ExtremaLocateExtCC2dTests and Fillet2DTests: the same
// Extrema_ExtElC2d / Extrema_ExtPElC2d / Extrema_ExtCC2d / Extrema_LocateExtCC2d runs and
// BRepFilletAPI_MakeFillet2d builds the bridge functions those tests reach make.
#include <Extrema_ExtElC2d.hxx>
#include <Extrema_ExtPElC2d.hxx>
#include <Extrema_ExtCC2d.hxx>
#include <Extrema_LocateExtCC2d.hxx>
#include <Extrema_POnCurv2d.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Line.hxx>
#include <GCE2d_MakeLine.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <gp_Lin2d.hxx>
#include <gp_Circ2d.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepFilletAPI_MakeFillet2d.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <cmath>
#include <cstdio>

static TopoDS_Face square20()
{
  gp_Pnt                  p1(-10, -10, 0), p2(10, -10, 0), p3(10, 10, 0), p4(-10, 10, 0);
  BRepBuilderAPI_MakeWire w;
  w.Add(BRepBuilderAPI_MakeEdge(p1, p2));
  w.Add(BRepBuilderAPI_MakeEdge(p2, p3));
  w.Add(BRepBuilderAPI_MakeEdge(p3, p4));
  w.Add(BRepBuilderAPI_MakeEdge(p4, p1));
  return BRepBuilderAPI_MakeFace(w.Wire(), true);
}

static void report(const char* tag, const TopoDS_Shape& s)
{
  TopTools_IndexedMapOfShape em;
  TopExp::MapShapes(s, TopAbs_EDGE, em);
  GProp_GProps g;
  BRepGProp::SurfaceProperties(s, g);
  printf("%s edges=%d area=%.12g\n", tag, em.Extent(), g.Mass());
}

int main()
{
  {
    Extrema_ExtElC2d e(gp_Lin2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), gp_Lin2d(gp_Pnt2d(0, 10), gp_Dir2d(1, 0)), 1e-9);
    printf("lin-lin (0,0)+x vs (0,10)+x: parallel=%d dist=%.12g\n", e.IsParallel(), sqrt(e.SquareDistance(1)));
    Extrema_ExtElC2d f(gp_Lin2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), gp_Lin2d(gp_Pnt2d(5, 3), gp_Dir2d(1, 0)), 1e-9);
    printf("lin-lin (0,0)+x vs (5,3)+x: parallel=%d dist=%.12g\n", f.IsParallel(), sqrt(f.SquareDistance(1)));
  }
  {
    Extrema_ExtElC2d e(gp_Lin2d(gp_Pnt2d(0, 20), gp_Dir2d(1, 0)),
                       gp_Circ2d(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5), 1e-9);
    printf("lin-circ: n=%d", e.NbExt());
    for (int i = 1; i <= e.NbExt(); i++)
      printf(" d%d=%.12g", i, sqrt(e.SquareDistance(i)));
    printf("\n");
  }
  {
    Extrema_ExtPElC2d e(gp_Pnt2d(10, 0), gp_Circ2d(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5), 1e-9, 0, 2 * M_PI);
    printf("pt-circ: n=%d", e.NbExt());
    for (int i = 1; i <= e.NbExt(); i++)
      printf(" d%d=%.12g", i, sqrt(e.SquareDistance(i)));
    printf("\n");
    Extrema_ExtPElC2d l(gp_Pnt2d(5, 5), gp_Lin2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 1e-9, RealFirst(), RealLast());
    printf("pt-lin: n=%d d1=%.12g foot=(%.12g, %.12g)\n", l.NbExt(), sqrt(l.SquareDistance(1)), l.Point(1).Value().X(),
           l.Point(1).Value().Y());
  }
  {
    Handle(Geom2d_Circle) c1 = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5);
    Handle(Geom2d_Circle) c2 = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(20, 0), gp_Dir2d(1, 0)), 5);
    Geom2dAdaptor_Curve   a1(c1, 0, 2 * M_PI), a2(c2, 0, 2 * M_PI);
    Extrema_ExtCC2d       e(a1, a2);
    printf("circ-circ: n=%d", e.NbExt());
    for (int i = 1; i <= e.NbExt(); i++)
      printf(" d%d=%.12g", i, sqrt(e.SquareDistance(i)));
    printf("\n");
  }
  {
    Handle(Geom2d_Circle) c  = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5);
    Handle(Geom2d_Line)   ln = GCE2d_MakeLine(gp_Pnt2d(10, -10), gp_Pnt2d(10, 10)).Value();
    Geom2dAdaptor_Curve   a1(c, 0, 2 * M_PI), a2(ln, -10, 10);
    Extrema_LocateExtCC2d e(a1, a2, 0, 0);
    Extrema_POnCurv2d     p1, p2;
    if (e.IsDone())
      e.Point(p1, p2);
    printf("LocateExtCC2d seed (0,0): done=%d dist=%.12g p1=(%.12g, %.12g) p2=(%.12g, %.12g)\n", e.IsDone(),
           e.IsDone() ? sqrt(e.SquareDistance()) : -1, p1.Value().X(), p1.Value().Y(), p2.Value().X(), p2.Value().Y());
  }
  {
    TopoDS_Face                f = square20();
    TopTools_IndexedMapOfShape vm, em;
    TopExp::MapShapes(f, TopAbs_VERTEX, vm);
    TopExp::MapShapes(f, TopAbs_EDGE, em);
    BRepFilletAPI_MakeFillet2d a(f);
    a.AddFillet(TopoDS::Vertex(vm(1)), 3.0);
    a.Build();
    report("fillet vertex 0 r3", a.Shape());
    BRepFilletAPI_MakeFillet2d b(f);
    for (int i = 1; i <= 4; i++)
      b.AddFillet(TopoDS::Vertex(vm(i)), 2.0);
    b.Build();
    report("fillet all 4 r2", b.Shape());
    BRepFilletAPI_MakeFillet2d c(f);
    c.AddChamfer(TopoDS::Edge(em(1)), TopoDS::Edge(em(2)), 2.0, 2.0);
    c.Build();
    report("chamfer edges 0,1 d2", c.Shape());
  }
  return 0;
}
