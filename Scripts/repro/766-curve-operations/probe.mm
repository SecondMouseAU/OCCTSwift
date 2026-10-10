// Epic #766 (#1978), kernel parity for Curve3DExtrasTests.swift, Curve3DExtrasV112Tests.swift,
// Curve3DInterpolateTangentToleranceParityTests.swift and Curve3DOperationsTests.swift. Same inputs
// as the tests: Geom_Curve::Reverse/Copy/Transform, GeomAdaptor_Curve::GetType,
// GeomAPI_ProjectPointOnCurve, GeomAPI_Interpolate with tangents, GCPnts_AbscissaPoint.
#include <GC_MakeSegment.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Line.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <cstdio>

static void ends(const char* name, const Handle(Geom_Curve)& c)
{
  gp_Pnt a = c->Value(c->FirstParameter()), b = c->Value(c->LastParameter());
  printf("%s: start=(%.17g, %.17g, %.17g) end=(%.17g, %.17g, %.17g)\n", name, a.X(), a.Y(), a.Z(),
         b.X(), b.Y(), b.Z());
}

static Handle(Geom_TrimmedCurve) seg(gp_Pnt a, gp_Pnt b)
{
  return GC_MakeSegment(a, b).Value();
}

int main()
{
  {
    auto s = seg(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0));
    Handle(Geom_Curve) copy = Handle(Geom_Curve)::DownCast(s->Copy());
    s->Reverse();
    ends("segment after Reverse", s);
    ends("copy taken before Reverse", copy);
  }
  Handle(Geom_Line)   line   = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
  Handle(Geom_Circle) circle = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
  printf("GetType: line=%d circle=%d\n", (int)GeomAdaptor_Curve(line).GetType(),
         (int)GeomAdaptor_Curve(circle).GetType());
  GeomAPI_ProjectPointOnCurve pr(gp_Pnt(5, 0, 0), line);
  printf("projection of (5,0,0) on the X axis: parameter=%.17g distance=%g\n",
         pr.LowerDistanceParameter(), pr.LowerDistance());
  {
    Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, 3);
    pts->SetValue(1, gp_Pnt(0, 0, 0));
    pts->SetValue(2, gp_Pnt(5, 5, 5));
    pts->SetValue(3, gp_Pnt(10, 0, 0));
    GeomAPI_Interpolate ip(pts, false, 1e-6);
    ip.Load(gp_Vec(1, 1, 1), gp_Vec(1, -1, -1));
    ip.Perform();
    gp_Pnt p;
    gp_Vec v0, v1;
    ip.Curve()->D1(ip.Curve()->FirstParameter(), p, v0);
    ip.Curve()->D1(ip.Curve()->LastParameter(), p, v1);
    printf("interpolate with tangents: d1 start=(%.17g, %.17g, %.17g) end=(%.17g, %.17g, %.17g)\n",
           v0.X(), v0.Y(), v0.Z(), v1.X(), v1.Y(), v1.Z());
    Handle(TColgp_HArray1OfPnt) close = new TColgp_HArray1OfPnt(1, 3);
    close->SetValue(1, gp_Pnt(0, 0, 0));
    close->SetValue(2, gp_Pnt(0, 0, 5e-7));
    close->SetValue(3, gp_Pnt(10, 0, 0));
    for (double tol : {1e-6, 1e-9})
    {
      try
      {
        GeomAPI_Interpolate c2(close, false, tol);
        c2.Load(gp_Vec(1, 0, 0), gp_Vec(1, 0, 0));
        c2.Perform();
        printf("points 5e-7 apart, tolerance %g: done=%d\n", tol, c2.IsDone());
      }
      catch (Standard_Failure& f)
      {
        printf("points 5e-7 apart, tolerance %g: threw %s\n", tol, f.what());
      }
    }
  }
  {
    Handle(Geom_TrimmedCurve) q = new Geom_TrimmedCurve(circle, 0, M_PI / 2);
    ends("circle trimmed to [0, pi/2]", q);
    ends("segment (0,0,0)-(10,5,3) reversed", Handle(Geom_Curve)::DownCast(seg(gp_Pnt(0, 0, 0), gp_Pnt(10, 5, 3))->Reversed()));
    gp_Trsf t;
    t.SetTranslation(gp_Vec(5, 5, 5));
    ends("segment (0,0,0)-(10,0,0) translated (5,5,5)", Handle(Geom_Curve)::DownCast(seg(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0))->Transformed(t)));
    t.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), M_PI / 2);
    ends("segment (5,0,0)-(10,0,0) rotated pi/2 about Z", Handle(Geom_Curve)::DownCast(seg(gp_Pnt(5, 0, 0), gp_Pnt(10, 0, 0))->Transformed(t)));
    t.SetScale(gp_Pnt(0, 0, 0), 3);
    ends("segment (1,0,0)-(2,0,0) scaled 3", Handle(Geom_Curve)::DownCast(seg(gp_Pnt(1, 0, 0), gp_Pnt(2, 0, 0))->Transformed(t)));
    t.SetMirror(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
    ends("segment (0,0,1)-(10,0,1) mirrored in z = 0", Handle(Geom_Curve)::DownCast(seg(gp_Pnt(0, 0, 1), gp_Pnt(10, 0, 1))->Transformed(t)));
    t.SetMirror(gp_Pnt(0, 0, 0));
    ends("segment (1,0,0)-(2,0,0) mirrored through the origin", Handle(Geom_Curve)::DownCast(seg(gp_Pnt(1, 0, 0), gp_Pnt(2, 0, 0))->Transformed(t)));
    t.SetMirror(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)));
    ends("segment (1,1,0)-(2,1,0) mirrored across the X axis", Handle(Geom_Curve)::DownCast(seg(gp_Pnt(1, 1, 0), gp_Pnt(2, 1, 0))->Transformed(t)));
    GeomAdaptor_Curve s345(seg(gp_Pnt(0, 0, 0), gp_Pnt(3, 4, 0)));
    GeomAdaptor_Curve c5(circle);
    auto              s10 = seg(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0));
    GeomAdaptor_Curve a10(s10);
    printf("lengths: (3,4,0) segment %.17g, r=5 circle %.17g, half of the 10 segment %.17g\n",
           GCPnts_AbscissaPoint::Length(s345), GCPnts_AbscissaPoint::Length(c5),
           GCPnts_AbscissaPoint::Length(a10, 0, 5));
  }
  return 0;
}
