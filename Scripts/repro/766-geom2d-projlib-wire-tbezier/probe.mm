// #1979 kernel parity for ProjLibTests, ProjLibProjectOnSurfaceTests, TBezierCurve2DTests and the
// Wire2DChamfer/Wire2DFillet suites: ProjLib::Project on the plane/cylinder fixtures,
// ProjLib_ProjectOnSurface as OCCTProjLibProjectOnSurface calls it, Geom2dEval_TBezierCurve, and
// ChFi2d_Builder on a 10x5 rectangle face as OCCTWireFillet2D / OCCTWireChamfer2D use it.
#include <BRepAdaptor_CompCurve.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepTools_WireExplorer.hxx>
#include <BRep_Tool.hxx>
#include <ChFi2d_Builder.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <Geom2dEval_TBezierCurve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Line.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <ProjLib.hxx>
#include <ProjLib_ProjectOnSurface.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Vertex.hxx>
#include <TopoDS_Wire.hxx>
#include <gp_Circ.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Lin.hxx>
#include <gp_Pln.hxx>
#include <cmath>
#include <cstdio>

static double wireLength(const TopoDS_Shape& s, int* edges)
{
  double len = 0;
  *edges     = 0;
  for (TopExp_Explorer ex(s, TopAbs_EDGE); ex.More(); ex.Next())
  {
    BRepAdaptor_Curve c(TopoDS::Edge(ex.Current()));
    len += GCPnts_AbscissaPoint::Length(c);
    (*edges)++;
  }
  return len;
}

int main()
{
  gp_Pln   pl(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  gp_Lin2d l = ProjLib::Project(pl, gp_Lin(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)));
  printf("ProjLib line on XY plane: loc=(%g, %g) dir=(%g, %g)\n", l.Location().X(), l.Location().Y(), l.Direction().X(),
         l.Direction().Y());
  gp_Circ2d c = ProjLib::Project(pl, gp_Circ(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5));
  printf("ProjLib circle on XY plane: center=(%g, %g) r=%g\n", c.Location().X(), c.Location().Y(), c.Radius());
  gp_Cylinder cy(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
  gp_Lin2d    lc = ProjLib::Project(cy, gp_Lin(gp_Pnt(5, 0, 0), gp_Dir(0, 0, 1)));
  printf("ProjLib axis line on r5 cylinder: loc=(%g, %g) dir=(%g, %g)\n", lc.Location().X(), lc.Location().Y(),
         lc.Direction().X(), lc.Direction().Y());

  Handle(Geom_CylindricalSurface) gcy = new Geom_CylindricalSurface(cy);
  Handle(Geom_Line)               gl  = new Geom_Line(gp_Pnt(5, 0, 0), gp_Dir(0, 1, 1));
  Handle(Geom_TrimmedCurve)       tr  = new Geom_TrimmedCurve(gl, 0, 10);
  ProjLib_ProjectOnSurface        proj;
  proj.Load(new GeomAdaptor_Surface(gcy));
  proj.Load(new GeomAdaptor_Curve(tr), 1e-3);
  printf("ProjLib_ProjectOnSurface (5,0,0)+(0,1,1) [0,10] on r5 cylinder: done=%d", proj.IsDone());
  if (proj.IsDone())
  {
    Handle(Geom_BSplineCurve) b = proj.BSpline();
    printf(" domain=[%.12g, %.12g] poles=%d degree=%d\n", b->FirstParameter(), b->LastParameter(), b->NbPoles(), b->Degree());
    for (double u : {b->FirstParameter(), 0.5 * (b->FirstParameter() + b->LastParameter()), b->LastParameter(), 0.0, 10.0})
    {
      gp_Pnt p = b->Value(u);
      printf("  value(%.6g) = (%.12g, %.12g, %.12g) radius=%.12g\n", u, p.X(), p.Y(), p.Z(), std::hypot(p.X(), p.Y()));
    }
  }
  else
    printf("\n");

  NCollection_Array1<gp_Pnt2d> tp(1, 3);
  tp.SetValue(1, gp_Pnt2d(0, 0));
  tp.SetValue(2, gp_Pnt2d(1, 1));
  tp.SetValue(3, gp_Pnt2d(2, 0));
  Handle(Geom2dEval_TBezierCurve) tb = new Geom2dEval_TBezierCurve(tp, 1.0);
  double f = tb->FirstParameter(), la = tb->LastParameter();
  gp_Pnt2d a = tb->Value(f), m = tb->Value(0.5 * (f + la)), e = tb->Value(la);
  printf("Geom2dEval_TBezierCurve (0,0)(1,1)(2,0) alpha 1: domain=[%.12g, %.12g] start=(%.12g, %.12g) mid=(%.12g, %.12g) end=(%.12g, %.12g)\n", f,
         la, a.X(), a.Y(), m.X(), m.Y(), e.X(), e.Y());

  BRepBuilderAPI_MakePolygon poly(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 5, 0), gp_Pnt(0, 5, 0), true);
  TopoDS_Face                face = BRepBuilderAPI_MakeFace(poly.Wire(), true);
  TopTools_IndexedMapOfShape vm;
  TopExp::MapShapes(poly.Wire(), TopAbs_VERTEX, vm);
  for (int kind = 0; kind < 2; kind++)
  {
    ChFi2d_Builder b(face);
    TopoDS_Vertex  v = TopoDS::Vertex(vm(1));
    if (kind == 0)
      b.AddFillet(v, 1.0);
    else
    {
      TopTools_IndexedDataMapOfShapeListOfShape ve;
      TopExp::MapShapesAndAncestors(face, TopAbs_VERTEX, TopAbs_EDGE, ve);
      const TopTools_ListOfShape& es = ve.FindFromKey(v);
      b.AddChamfer(TopoDS::Edge(es.First()), TopoDS::Edge(es.Last()), 1.0, 1.0);
    }
    int    n   = 0;
    double len = b.Status() == ChFi2d_IsDone ? wireLength(b.Result(), &n) : -1;
    printf("ChFi2d_Builder %s on one corner of the 10x5 rectangle: status=%d edges=%d length=%.12g\n",
           kind == 0 ? "fillet r1" : "chamfer 1x1", (int)b.Status(), n, len);
  }
  return 0;
}
