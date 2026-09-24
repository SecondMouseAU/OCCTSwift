// Epic #766 (#1978), kernel parity for Curve3DConversionTests.swift, Curve3DDrawTests.swift and
// Curve3DEvalTests.swift. Same inputs as the tests, mirroring the bridge: GeomConvert::
// CurveToBSplineCurve, GeomConvert_BSplineCurveToBezierCurve, GeomConvert_CompCurveToBSplineCurve,
// GCPnts_TangentialDeflection / UniformAbscissa / UniformDeflection, and Geom_Curve::EvalD0..D3.
#include <GC_MakeSegment.hxx>
#include <GCPnts_TangentialDeflection.hxx>
#include <GCPnts_UniformAbscissa.hxx>
#include <GCPnts_UniformDeflection.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_BSplineCurveToBezierCurve.hxx>
#include <GeomConvert_CompCurveToBSplineCurve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <cstdio>

int main()
{
  Handle(Geom_Circle) circle = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
  Handle(Geom_BSplineCurve) b = GeomConvert::CurveToBSplineCurve(circle);
  printf("circleToBSpline: degree=%d poles=%d rational=%d periodic=%d\n", b->Degree(), b->NbPoles(),
         b->IsRational(), b->IsPeriodic());
  GeomConvert_BSplineCurveToBezierCurve bz(b);
  printf("bsplineToBeziers: NbArcs=%d\n", bz.NbArcs());
  {
    Handle(Geom_BSplineCurve) s1 = GeomConvert::CurveToBSplineCurve(GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(5, 0, 0)).Value());
    Handle(Geom_BSplineCurve) s2 = GeomConvert::CurveToBSplineCurve(GC_MakeSegment(gp_Pnt(5, 0, 0), gp_Pnt(10, 5, 0)).Value());
    GeomConvert_CompCurveToBSplineCurve j(s1);
    bool                                ok = j.Add(s2, 1e-6);
    Handle(Geom_BSplineCurve)           r  = j.BSplineCurve();
    printf("joinCurves: add=%d start=(%g, %g, %g) end=(%g, %g, %g) domain=[%.17g, %.17g]\n", ok,
           r->StartPoint().X(), r->StartPoint().Y(), r->StartPoint().Z(), r->EndPoint().X(),
           r->EndPoint().Y(), r->EndPoint().Z(), r->FirstParameter(), r->LastParameter());
  }
  {
    Handle(Geom_BSplineCurve) s1 = GeomConvert::CurveToBSplineCurve(GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(1, 0, 0)).Value());
    Handle(Geom_BSplineCurve) s2 = GeomConvert::CurveToBSplineCurve(GC_MakeSegment(gp_Pnt(5, 0, 0), gp_Pnt(6, 0, 0)).Value());
    GeomConvert_CompCurveToBSplineCurve j(s1);
    printf("joinRejectsDisconnected: add=%d\n", j.Add(s2, 1e-6));
  }
  GeomAdaptor_Curve           ca(circle);
  GCPnts_TangentialDeflection td(ca, 0.1, 0.01);
  printf("drawAdaptive (circle r=5) at the Swift defaults (0.1, 0.01): %d points\n", td.NbPoints());
  GCPnts_UniformAbscissa ua(ca, 32);
  printf("drawUniform 32: done=%d NbPoints=%d\n", ua.IsDone(), ua.NbPoints());
  GCPnts_UniformDeflection ud(ca, 0.1);
  printf("drawDeflection 0.1: done=%d NbPoints=%d\n", ud.IsDone(), ud.NbPoints());
  Handle(Geom_TrimmedCurve) seg = GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(10, 5, 3)).Value();
  GeomAdaptor_Curve         sa(seg);
  GCPnts_TangentialDeflection tds(sa, 0.1, 0.01);
  printf("drawAdaptive segment at (0.1, 0.01): %d points\n", tds.NbPoints());

  Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, 5);
  pts->SetValue(1, gp_Pnt(0, 0, 0));
  pts->SetValue(2, gp_Pnt(2, 3, 0));
  pts->SetValue(3, gp_Pnt(5, 5, 0));
  pts->SetValue(4, gp_Pnt(8, 3, 0));
  pts->SetValue(5, gp_Pnt(10, 0, 0));
  GeomAPI_Interpolate ip(pts, false, 1e-6);
  ip.Perform();
  Handle(Geom_BSplineCurve) c   = ip.Curve();
  double                    mid = (c->FirstParameter() + c->LastParameter()) / 2;
  gp_Pnt                    p0  = c->EvalD0(c->FirstParameter());
  Geom_Curve::ResD3         r3  = c->EvalD3(mid);
  printf("eval fixture: domain=[%.17g, %.17g] mid=%.17g\n", c->FirstParameter(), c->LastParameter(), mid);
  printf("  EvalD0(first)=(%.17g, %.17g, %.17g)\n", p0.X(), p0.Y(), p0.Z());
  printf("  EvalD3(mid): P=(%.17g, %.17g, %.17g) D1=(%.17g, %.17g, %.17g) D2=(%.17g, %.17g, %.17g) D3=(%.17g, %.17g, %.17g)\n",
         r3.Point.X(), r3.Point.Y(), r3.Point.Z(), r3.D1.X(), r3.D1.Y(), r3.D1.Z(), r3.D2.X(),
         r3.D2.Y(), r3.D2.Z(), r3.D3.X(), r3.D3.Y(), r3.D3.Z());
  gp_Pnt q = circle->EvalD0(0);
  printf("circle EvalD0(0)=(%.17g, %.17g, %.17g)\n", q.X(), q.Y(), q.Z());
  return 0;
}
