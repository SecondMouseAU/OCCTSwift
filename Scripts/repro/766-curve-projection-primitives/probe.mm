// Epic #766 (#1978), kernel parity for Curve3DPlaneProjectionTests.swift and
// Curve3DPrimitiveTests.swift. Same inputs as the tests: GeomProjLib::ProjectOnPlane (as
// OCCTCurve3DProjectOnPlane calls it, keeping parametrization), GC_MakeSegment, Geom_Circle,
// Geom_Ellipse, GC_MakeArcOfCircle and Geom_Curve::D1/D2/Period.
#include <GC_MakeArcOfCircle.hxx>
#include <GC_MakeSegment.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomProjLib.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Line.hxx>
#include <Geom_Plane.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <Standard_Failure.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <cstdio>

static void proj(const char* name, const Handle(Geom_Curve)& c, gp_Dir n, gp_Dir d)
{
  Handle(Geom_Plane) pl = new Geom_Plane(gp_Pnt(0, 0, 0), n);
  try
  {
    Handle(Geom_Curve) r = GeomProjLib::ProjectOnPlane(c, pl, d, Standard_True);
    if (r.IsNull())
    {
      printf("%s: null\n", name);
      return;
    }
    double f = r->FirstParameter(), l = r->LastParameter();
    gp_Pnt a = r->Value(f), b = r->Value(l), m = r->Value((f + l) / 2);
    printf("%s: %s domain=[%.6g, %.6g] start=(%.17g, %.17g, %.17g) mid=(%.17g, %.17g, %.17g) end=(%.17g, %.17g, %.17g)\n",
           name, r->DynamicType()->Name(), f, l, a.X(), a.Y(), a.Z(), m.X(), m.Y(), m.Z(), b.X(),
           b.Y(), b.Z());
  }
  catch (Standard_Failure& e)
  {
    printf("%s: threw %s\n", name, e.what());
  }
}

int main()
{
  setvbuf(stdout, nullptr, _IONBF, 0);
  gp_Dir Z(0, 0, 1), Y(0, 1, 0);
  proj("segment (0,0,5)-(10,7,5) onto z=0 along Z", GC_MakeSegment(gp_Pnt(0, 0, 5), gp_Pnt(10, 7, 5)).Value(), Z, Z);
  proj("circle r=5 at z=10 onto z=0 along Z", new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 10), Z), 5), Z, Z);
  proj("arc (5,0,0)(0,5,0)(-5,0,0) onto y=0 along Y",
       GC_MakeArcOfCircle(gp_Pnt(5, 0, 0), gp_Pnt(0, 5, 0), gp_Pnt(-5, 0, 0)).Value(), Y, Y);
  Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, 4);
  pts->SetValue(1, gp_Pnt(0, 0, 1));
  pts->SetValue(2, gp_Pnt(3, 5, 2));
  pts->SetValue(3, gp_Pnt(7, 2, 4));
  pts->SetValue(4, gp_Pnt(10, 8, 3));
  GeomAPI_Interpolate ip(pts, false, 1e-6);
  ip.Perform();
  proj("interpolated BSpline onto z=0 along Z", ip.Curve(), Z, Z);
  proj("segment (2,3,8)-(12,3,8) onto z=0 along Z", GC_MakeSegment(gp_Pnt(2, 3, 8), gp_Pnt(12, 3, 8)).Value(), Z, Z);
  proj("segment (0,0,10)-(10,0,10) onto z=0 along (1,0,1)", GC_MakeSegment(gp_Pnt(0, 0, 10), gp_Pnt(10, 0, 10)).Value(), Z, gp_Dir(1, 0, 1));
  proj("segment (0,0,0)-(10,0,0) onto z=0 along (1,0,0.001)", GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Value(), Z, gp_Dir(1, 0, 0.001));

  Handle(Geom_Circle) c = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), Z), 5);
  printf("circle r=5: closed=%d periodic=%d period=%.17g value(0)=(%g, %g) value(pi/2)=(%.3g, %g)\n",
         c->IsClosed(), c->IsPeriodic(), c->Period(), c->Value(0).X(), c->Value(0).Y(),
         c->Value(M_PI / 2).X(), c->Value(M_PI / 2).Y());
  Handle(Geom_Ellipse) e = new Geom_Ellipse(gp_Ax2(gp_Pnt(0, 0, 0), Z), 10, 5);
  printf("ellipse 10x5: closed=%d periodic=%d period=%.17g\n", e->IsClosed(), e->IsPeriodic(), e->Period());
  Handle(Geom_Line) l = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
  printf("line domain=[%g, %g]\n", l->FirstParameter(), l->LastParameter());
  Handle(Geom_TrimmedCurve) s = GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(10, 5, 3)).Value();
  gp_Pnt p;
  gp_Vec v1, v2;
  s->D1(s->FirstParameter(), p, v1);
  printf("segment (0,0,0)-(10,5,3): domain=[%.17g, %.17g] D1(first)=(%.17g, %.17g, %.17g)\n",
         s->FirstParameter(), s->LastParameter(), v1.X(), v1.Y(), v1.Z());
  c->D2(0, p, v1, v2);
  printf("circle D2(0): P=(%g, %g, %g) V2=(%g, %g, %g)\n", p.X(), p.Y(), p.Z(), v2.X(), v2.Y(), v2.Z());
  // GC_MakeSegment on two coincident points (5,5,5) is not attempted here: it ended this probe
  // with SIGSEGV rather than reporting not-done, which is why OCCTCurve3DCreateSegment checks
  // the distance first and returns nil.

  return 0;
}
