// Epic #766 (#1978), kernel parity for EdgeCurve3DTests.swift and EllipseArcTests.swift. Same
// inputs as the tests: BRep_Tool::Curve on the edges (the raw, untrimmed curve OCCTEdgeGetCurve3D
// returns) and GC_MakeArcOfEllipse by angles and by points.
#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRep_Tool.hxx>
#include <GC_MakeArcOfEllipse.hxx>
#include <Geom_Circle.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static void arc(const char* name, const Handle(Geom_TrimmedCurve)& t)
{
  double f = t->FirstParameter(), l = t->LastParameter();
  gp_Pnt a = t->Value(f), m = t->Value((f + l) / 2), b = t->Value(l);
  printf("%s: domain=[%.17g, %.17g] closed=%d start=(%.17g, %.17g, %.17g) mid=(%.17g, %.17g, %.17g) end=(%.17g, %.17g, %.17g)\n",
         name, f, l, t->IsClosed(), a.X(), a.Y(), a.Z(), m.X(), m.Y(), m.Z(), b.X(), b.Y(), b.Z());
}

int main()
{
  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape em;
  TopExp::MapShapes(box, TopAbs_EDGE, em);
  double             f, l;
  Handle(Geom_Curve) c = BRep_Tool::Curve(TopoDS::Edge(em(1)), f, l);
  printf("box edge[0]: raw curve %s domain=[%g, %g], edge range [%g, %g]\n", c->DynamicType()->Name(),
         c->FirstParameter(), c->LastParameter(), f, l);
  TopoDS_Shape               cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();
  TopTools_IndexedMapOfShape cm;
  TopExp::MapShapes(cyl, TopAbs_EDGE, cm);
  for (int i = 1; i <= cm.Extent(); i++)
  {
    Handle(Geom_Curve) cc = BRep_Tool::Curve(TopoDS::Edge(cm(i)), f, l);
    if (auto circ = Handle(Geom_Circle)::DownCast(cc))
      printf("cylinder edge[%d]: Geom_Circle radius=%.17g\n", i - 1, circ->Radius());
  }
  Handle(Geom_Circle) q = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
  TopoDS_Edge         qe = BRepBuilderAPI_MakeEdge(q, 0, M_PI / 2);
  Handle(Geom_Curve)  qc = BRep_Tool::Curve(qe, f, l);
  printf("quarter arc edge: raw %s domain=[%.17g, %.17g], edge range [%.17g, %.17g]\n",
         qc->DynamicType()->Name(), qc->FirstParameter(), qc->LastParameter(), f, l);

  gp_Elips e(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10, 5);
  arc("arcOfEllipse angles [0, pi/2]", GC_MakeArcOfEllipse(e, 0, M_PI / 2, true).Value());
  arc("arcOfEllipse (10,0,0) -> (-10,0,0)", GC_MakeArcOfEllipse(e, gp_Pnt(10, 0, 0), gp_Pnt(-10, 0, 0), true).Value());
  arc("arcOfEllipse angles [0, pi]", GC_MakeArcOfEllipse(e, 0, M_PI, true).Value());
  return 0;
}
