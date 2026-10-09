// Epic #766, TBezierCurve3DTests.swift, TBezierSurfaceTests.swift,
// TopTransSurfaceTransitionTests.swift and TypeNameTests.swift: kernel parity for the fourteen tests.
//  - GeomEval_TBezierCurve (plain and weighted) and GeomEval_TBezierSurface on the same poles, as
//    OCCTGeomEvalTBezier*Create build them; even pole counts go to the constructor unguarded here.
//  - TopTrans_SurfaceTransition Reset/Compare (plain and curvature forms) at tolerance 1e-6, with
//    orientation 0 = FORWARD, 1 = REVERSED (occtOrientationFromInt).
//  - DynamicType()->Name() of the objects the Swift factories build.
#include <GC_MakeLine.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <GeomEval_TBezierCurve.hxx>
#include <GeomEval_TBezierSurface.hxx>
#include <Geom2d_Line.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Line.hxx>
#include <Geom_Plane.hxx>
#include <Geom_SphericalSurface.hxx>
#include <NCollection_Array1.hxx>
#include <NCollection_Array2.hxx>
#include <Standard_Failure.hxx>
#include <TopAbs_State.hxx>
#include <TopTrans_SurfaceTransition.hxx>
#include <cmath>
#include <cstdio>

static void pt(const char* tag, const gp_Pnt& p)
{
  printf(" %s=(%.17g, %.17g, %.17g)", tag, p.X(), p.Y(), p.Z());
}

int main()
{
  NCollection_Array1<gp_Pnt> poles(1, 3);
  poles(1) = gp_Pnt(0, 0, 0);
  poles(2) = gp_Pnt(1, 1, 0);
  poles(3) = gp_Pnt(2, 0, 0);
  {
    Handle(GeomEval_TBezierCurve) c = new GeomEval_TBezierCurve(poles, 1.0);
    printf("createAndEval: domain=[%.17g, %.17g]", c->FirstParameter(), c->LastParameter());
    pt("start", c->Value(c->FirstParameter()));
    pt("end", c->Value(c->LastParameter()));
    pt("mid", c->Value((c->FirstParameter() + c->LastParameter()) / 2));
    printf("\n");
  }
  {
    NCollection_Array1<double> w(1, 3);
    w(1) = 1;
    w(2) = 2;
    w(3) = 1;
    Handle(GeomEval_TBezierCurve) c = new GeomEval_TBezierCurve(poles, w, 1.0);
    printf("rationalTBezier: domain=[%.17g, %.17g]", c->FirstParameter(), c->LastParameter());
    pt("mid", c->Value((c->FirstParameter() + c->LastParameter()) / 2));
    printf("\n");
  }
  try
  {
    NCollection_Array1<gp_Pnt> two(1, 2);
    two(1) = gp_Pnt(0, 0, 0);
    two(2) = gp_Pnt(1, 1, 0);
    Handle(GeomEval_TBezierCurve) c = new GeomEval_TBezierCurve(two, 1.0);
    printf("rejectsEvenPoleCount: kernel accepted 2 poles\n");
  }
  catch (Standard_Failure& e)
  {
    printf("rejectsEvenPoleCount: kernel threw %s\n", e.GetMessageString());
  }
  {
    NCollection_Array2<gp_Pnt> sp(1, 3, 1, 3);
    for (int i = 0; i < 3; i++)
      for (int j = 0; j < 3; j++)
        sp(i + 1, j + 1) = gp_Pnt(i, j, 0.5 * std::sin((i + j) * 0.5));
    Handle(GeomEval_TBezierSurface) s = new GeomEval_TBezierSurface(sp, 1.0, 1.0);
    double u1, u2, v1, v2;
    s->Bounds(u1, u2, v1, v2);
    printf("createSurface: bounds=[%.17g, %.17g]x[%.17g, %.17g]", u1, u2, v1, v2);
    pt("S(30%,70%)", s->Value(u1 + 0.3 * (u2 - u1), v1 + 0.7 * (v2 - v1)));
    printf("\n");
  }
  try
  {
    NCollection_Array2<gp_Pnt> sp(1, 4, 1, 3);
    for (int i = 0; i < 4; i++)
      for (int j = 0; j < 3; j++)
        sp(i + 1, j + 1) = gp_Pnt(i, j, 0);
    Handle(GeomEval_TBezierSurface) s = new GeomEval_TBezierSurface(sp, 1.0, 1.0);
    printf("rejectsEvenCounts: kernel accepted 4 x 3\n");
  }
  catch (Standard_Failure& e)
  {
    printf("rejectsEvenCounts: kernel threw %s\n", e.GetMessageString());
  }
  const char* st[] = {"IN", "OUT", "ON", "UNKNOWN"};
  for (int o = 0; o < 2; o++)
  {
    TopTrans_SurfaceTransition t;
    t.Reset(gp_Dir(1, 0, 0), gp_Dir(0, 0, 1));
    t.Compare(1e-6, gp_Dir(0, 1, 0), o ? TopAbs_REVERSED : TopAbs_FORWARD, o ? TopAbs_REVERSED : TopAbs_FORWARD);
    printf("%s: StateBefore=%s StateAfter=%s\n", o ? "reversedCrossing" : "forwardCrossing", st[t.StateBefore()], st[t.StateAfter()]);
  }
  {
    TopTrans_SurfaceTransition t;
    t.Reset(gp_Dir(1, 0, 0), gp_Dir(0, 0, 1), gp_Dir(0, 1, 0), gp_Dir(0, 0, 1), 0.1, 0.01);
    t.Compare(1e-6, gp_Dir(0, 1, 0), gp_Dir(1, 0, 0), gp_Dir(0, 0, 1), 0.05, 0.005, TopAbs_FORWARD, TopAbs_FORWARD);
    printf("withCurvature: StateBefore=%s StateAfter=%s\n", st[t.StateBefore()], st[t.StateAfter()]);
  }
  printf("stateEnumValues: TopAbs_IN=%d TopAbs_OUT=%d TopAbs_ON=%d TopAbs_UNKNOWN=%d\n", TopAbs_IN, TopAbs_OUT, TopAbs_ON, TopAbs_UNKNOWN);
  printf("typeNames: %s %s %s %s\n", STANDARD_TYPE(Geom_Line)->Name(), STANDARD_TYPE(Geom_BSplineCurve)->Name(), STANDARD_TYPE(Geom2d_Line)->Name(),
         STANDARD_TYPE(Geom_SphericalSurface)->Name());
  printf("typeNames: %s\n", STANDARD_TYPE(Geom_Plane)->Name());
  return 0;
}
