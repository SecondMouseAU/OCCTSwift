// Epic #766 (#1978), kernel parity for Curve3DQueriesV123Tests.swift,
// Curve3DTransformFamilyParityTests.swift and CurveApproximationTests.swift. Same inputs as the
// tests: Geom_Curve::Period/FirstParameter/LastParameter, Geom_Curve::Transform (the in-place and
// copying families both call it with the same gp_Trsf), and Approx_Curve3d on BRepAdaptor_Curve
// (tolerance 1e-3, C2, 100 segments, degree 8), as OCCTEdgeApproxCurve/Info call it.
#include <Approx_Curve3d.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRep_Tool.hxx>
#include <GC_MakeSegment.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Line.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static void approx(const char* name, const TopoDS_Edge& e)
{
  Handle(BRepAdaptor_Curve) a = new BRepAdaptor_Curve(e);
  Approx_Curve3d            ap(a, 1e-3, GeomAbs_C2, 100, 8);
  Handle(Geom_BSplineCurve) b = ap.Curve();
  gp_Pnt                    s = b->StartPoint(), m = b->Value((b->FirstParameter() + b->LastParameter()) / 2), t = b->EndPoint();
  printf("%s: done=%d hasResult=%d maxError=%.17g degree=%d poles=%d start=(%.17g, %.17g, %.17g) mid=(%.17g, %.17g, %.17g) end=(%.17g, %.17g, %.17g)\n",
         name, ap.IsDone(), ap.HasResult(), ap.MaxError(), b->Degree(), b->NbPoles(), s.X(), s.Y(),
         s.Z(), m.X(), m.Y(), m.Z(), t.X(), t.Y(), t.Z());
}

int main()
{
  Handle(Geom_Circle) c = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
  printf("circle r=5: period=%.17g first=%.17g last=%.17g\n", c->Period(), c->FirstParameter(), c->LastParameter());
  Handle(Geom_Line) l = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
  printf("line: first=%g last=%g\n", l->FirstParameter(), l->LastParameter());
  gp_Trsf t;
  t.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), M_PI / 3);
  Handle(Geom_TrimmedCurve) s  = GC_MakeSegment(gp_Pnt(5, 0, 0), gp_Pnt(10, 0, 0)).Value();
  Handle(Geom_Curve)        cp = Handle(Geom_Curve)::DownCast(s->Transformed(t));
  s->Transform(t);
  printf("rotate pi/3: in place start=(%.17g, %.17g) copy start=(%.17g, %.17g)\n", s->StartPoint().X(),
         s->StartPoint().Y(), cp->Value(cp->FirstParameter()).X(), cp->Value(cp->FirstParameter()).Y());

  TopoDS_Shape               cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();
  TopTools_IndexedMapOfShape em;
  TopExp::MapShapes(cyl, TopAbs_EDGE, em);
  for (int i = 1; i <= em.Extent(); i++)
    if (BRepAdaptor_Curve(TopoDS::Edge(em(i))).GetType() == GeomAbs_Circle)
    {
      approx("first circular edge of cylinder r=5 h=10", TopoDS::Edge(em(i)));
      break;
    }
  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape bm;
  TopExp::MapShapes(box, TopAbs_EDGE, bm);
  approx("box 10 (centred) edge[0]", TopoDS::Edge(bm(1)));
  return 0;
}
