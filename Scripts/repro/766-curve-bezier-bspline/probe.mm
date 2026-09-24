// Epic #766 (#1978), kernel parity for Curve3DArcAliasParityTests.swift, Curve3DArcLengthTests.swift,
// Curve3DArcLengthFailureParityTests.swift, Curve3DBezierCompletionsTests.swift and
// Curve3DBSplineTests.swift. Same inputs as the Swift tests, straight to the classes the bridge uses:
// GC_MakeArcOfCircle, GCPnts_AbscissaPoint (the bridge's occtAdaptorArcLength integrates the same
// length), Geom_BezierCurve, GeomAPI_Interpolate and GeomAPI_PointsToBSpline.
#include <GC_MakeArcOfCircle.hxx>
#include <GC_MakeSegment.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <cmath>
#include <cstdio>

static void arc(const char* name, gp_Pnt a, gp_Pnt b, gp_Pnt c)
{
  GC_MakeArcOfCircle m(a, b, c);
  printf("%s: done=%d", name, m.IsDone());
  if (m.IsDone())
  {
    Handle(Geom_TrimmedCurve) t = m.Value();
    gp_Pnt s = t->StartPoint(), e = t->EndPoint(), mid = t->Value((t->FirstParameter() + t->LastParameter()) / 2);
    printf(" domain=[%.17g, %.17g] start=(%.17g, %.17g, %.17g) mid=(%.17g, %.17g, %.17g) end=(%.17g, %.17g, %.17g) closed=%d",
           t->FirstParameter(), t->LastParameter(), s.X(), s.Y(), s.Z(), mid.X(), mid.Y(), mid.Z(),
           e.X(), e.Y(), e.Z(), t->IsClosed());
  }
  printf("\n");
}

int main()
{
  arc("arc (5,0,0) (0,5,0) (-5,0,0)", gp_Pnt(5, 0, 0), gp_Pnt(0, 5, 0), gp_Pnt(-5, 0, 0));
  arc("collinear (0,0,0) (1,0,0) (2,0,0)", gp_Pnt(0, 0, 0), gp_Pnt(1, 0, 0), gp_Pnt(2, 0, 0));
  arc("coincident (3,4,5) x3", gp_Pnt(3, 4, 5), gp_Pnt(3, 4, 5), gp_Pnt(3, 4, 5));

  Handle(Geom_TrimmedCurve) seg = GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Value();
  GeomAdaptor_Curve         sa(seg);
  double f = seg->FirstParameter(), l = seg->LastParameter(), mid = (f + l) / 2;
  printf("segment (0,0,0)-(10,0,0): domain=[%.17g, %.17g] length=%.17g length[first, mid]=%.17g "
         "length[mid, mid]=%.17g length[first, quarter]=%.17g\n",
         f, l, GCPnts_AbscissaPoint::Length(sa), GCPnts_AbscissaPoint::Length(sa, f, mid),
         GCPnts_AbscissaPoint::Length(sa, mid, mid),
         GCPnts_AbscissaPoint::Length(sa, f, f + (l - f) / 4));
  GCPnts_AbscissaPoint ap(sa, 5.0, f);
  printf("  parameter at length 5 from first = %.17g -> point x=%.17g\n", ap.Parameter(),
         seg->Value(ap.Parameter()).X());
  Handle(Geom_Circle) circ = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10);
  GeomAdaptor_Curve   ca(circ);
  double              C = GCPnts_AbscissaPoint::Length(ca);
  GCPnts_AbscissaPoint aq(ca, C / 4, 0);
  gp_Pnt              q = circ->Value(aq.Parameter());
  printf("circle r=10: length=%.17g, parameter at length/4 = %.17g -> (%.17g, %.17g, %.17g)\n", C,
         aq.Parameter(), q.X(), q.Y(), q.Z());

  {
    TColgp_Array1OfPnt p(1, 2);
    p(1) = gp_Pnt(0, 0, 0);
    p(2) = gp_Pnt(1, 1, 1);
    Handle(Geom_BezierCurve) b = new Geom_BezierCurve(p);
    b->InsertPoleBefore(1, gp_Pnt(0.5, 0.5, 0.5));
    printf("InsertPoleBefore(1): nbPoles=%d degree=%d pole1=(%g, %g, %g)\n", b->NbPoles(),
           b->Degree(), b->Pole(1).X(), b->Pole(1).Y(), b->Pole(1).Z());
  }
  {
    TColgp_Array1OfPnt p(1, 2);
    p(1) = gp_Pnt(0, 0, 0);
    p(2) = gp_Pnt(10, 20, 30);
    Handle(Geom_BezierCurve) b = new Geom_BezierCurve(p);
    b->Reverse();
    printf("Reverse: start=(%g, %g, %g) end=(%g, %g, %g)\n", b->StartPoint().X(),
           b->StartPoint().Y(), b->StartPoint().Z(), b->EndPoint().X(), b->EndPoint().Y(),
           b->EndPoint().Z());
  }
  {
    TColgp_Array1OfPnt   p(1, 3);
    TColStd_Array1OfReal w(1, 3);
    p(1) = gp_Pnt(0, 0, 0);
    p(2) = gp_Pnt(5, 5, 0);
    p(3) = gp_Pnt(10, 0, 0);
    w.Init(1.0);
    Handle(Geom_BezierCurve) b = new Geom_BezierCurve(p, w);
    printf("rational weights 1,1,1: IsRational=%d\n", b->IsRational());
    b->SetPole(2, gp_Pnt(5, 10, 0), 2.0);
    printf("SetPole(2, (5,10,0), 2.0): pole2=(%g, %g, %g) weight2=%g rational=%d C(0.5)=(%.17g, %.17g)\n",
           b->Pole(2).X(), b->Pole(2).Y(), b->Pole(2).Z(), b->Weight(2), b->IsRational(),
           b->Value(0.5).X(), b->Value(0.5).Y());
  }
  {
    TColgp_Array1OfPnt p(1, 3);
    p(1) = gp_Pnt(0, 0, 0);
    p(2) = gp_Pnt(5, 10, 0);
    p(3) = gp_Pnt(10, 0, 0);
    Handle(Geom_BezierCurve) b = new Geom_BezierCurve(p);
    printf("quadraticBezier: degree=%d nbPoles=%d\n", b->Degree(), b->NbPoles());
  }
  {
    Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, 4);
    pts->SetValue(1, gp_Pnt(0, 0, 0));
    pts->SetValue(2, gp_Pnt(3, 5, 1));
    pts->SetValue(3, gp_Pnt(7, 2, 3));
    pts->SetValue(4, gp_Pnt(10, 0, 0));
    GeomAPI_Interpolate ip(pts, false, 1e-6);
    ip.Perform();
    Handle(Geom_BSplineCurve) c = ip.Curve();
    printf("interpolate: domain=[%.17g, %.17g] start=(%g, %g, %g) end=(%g, %g, %g) knots:", c->FirstParameter(),
           c->LastParameter(), c->StartPoint().X(), c->StartPoint().Y(), c->StartPoint().Z(),
           c->EndPoint().X(), c->EndPoint().Y(), c->EndPoint().Z());
    for (int i = 1; i <= c->NbKnots(); i++)
      printf(" %.17g", c->Knot(i));
    printf("\n");
  }
  {
    Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, 3);
    pts->SetValue(1, gp_Pnt(0, 0, 0));
    pts->SetValue(2, gp_Pnt(5, 5, 5));
    pts->SetValue(3, gp_Pnt(10, 0, 0));
    GeomAPI_Interpolate ip(pts, false, 1e-6);
    ip.Load(gp_Vec(1, 1, 1), gp_Vec(1, -1, -1));
    ip.Perform();
    Handle(Geom_BSplineCurve) c = ip.Curve();
    gp_Pnt                    p0, p1;
    gp_Vec                    v0, v1;
    c->D1(c->FirstParameter(), p0, v0);
    c->D1(c->LastParameter(), p1, v1);
    printf("interpolateWithTangents: done=%d start=(%g, %g, %g) end=(%g, %g, %g) d1(start)=(%.17g, %.17g, %.17g) d1(end)=(%.17g, %.17g, %.17g)\n",
           ip.IsDone(), p0.X(), p0.Y(), p0.Z(), p1.X(), p1.Y(), p1.Z(), v0.X(), v0.Y(), v0.Z(),
           v1.X(), v1.Y(), v1.Z());
  }
  {
    TColgp_Array1OfPnt p(1, 20);
    for (int i = 0; i < 20; i++)
    {
      double t = i / 19.0 * M_PI * 2;
      p(i + 1) = gp_Pnt(std::cos(t) * 5, std::sin(t) * 5, i * 0.5);
    }
    Handle(Geom_BSplineCurve) c = GeomAPI_PointsToBSpline(p, 3, 8, GeomAbs_C2, 1e-3).Curve();
    gp_Pnt s = c->StartPoint(), e = c->EndPoint();
    printf("fitPoints: degree=%d poles=%d start=(%.17g, %.17g, %.17g) end=(%.17g, %.17g, %.17g)\n",
           c->Degree(), c->NbPoles(), s.X(), s.Y(), s.Z(), e.X(), e.Y(), e.Z());
  }
  return 0;
}
