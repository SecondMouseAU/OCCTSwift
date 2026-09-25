// #1979 kernel parity for Curve2DTests: the GCE2d / Geom2d constructions the Curve2D factories
// use, their D1 and period, and the point counts GCPnts_TangentialDeflection (angular 0.1,
// chordal 0.01, the drawAdaptive defaults) and GCPnts_UniformDeflection (0.1) give.
#include <GCE2d_MakeArcOfCircle.hxx>
#include <GCE2d_MakeArcOfEllipse.hxx>
#include <GCE2d_MakeSegment.hxx>
#include <GCPnts_TangentialDeflection.hxx>
#include <GCPnts_UniformDeflection.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Ellipse.hxx>
#include <Geom2d_Hyperbola.hxx>
#include <Geom2d_Parabola.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <gp_Circ2d.hxx>
#include <gp_Elips2d.hxx>
#include <gp_Hypr2d.hxx>
#include <gp_Parab2d.hxx>
#include <cmath>
#include <cstdio>

static int adaptive(const Handle(Geom2d_Curve)& c)
{
  Geom2dAdaptor_Curve a(c);
  GCPnts_TangentialDeflection s(a, 0.1, 0.01);
  return s.NbPoints();
}

int main()
{
  gp_Ax2d               ax(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
  Handle(Geom2d_Circle) c = new Geom2d_Circle(gp_Circ2d(ax, 5));
  Geom2dAdaptor_Curve   ca(c);
  GCPnts_UniformDeflection ud(ca, 0.1);
  printf("circle r5: period=%.15g adaptive=%d uniformDeflection(0.1)=%d\n", c->Period(), adaptive(c), ud.NbPoints());
  Handle(Geom2d_TrimmedCurve) arc = GCE2d_MakeArcOfCircle(gp_Circ2d(ax, 5), 0, M_PI / 2, true).Value();
  printf("arc r5 [0, pi/2]: end=(%.12g, %.12g) closed=%d\n", arc->EndPoint().X(), arc->EndPoint().Y(), arc->IsClosed());
  Handle(Geom2d_TrimmedCurve) a3 = GCE2d_MakeArcOfCircle(gp_Pnt2d(0, 0), gp_Pnt2d(5, 5), gp_Pnt2d(10, 0)).Value();
  gp_Pnt2d                    am = a3->Value(0.5 * (a3->FirstParameter() + a3->LastParameter()));
  printf("arc through (0,0)(5,5)(10,0): end=(%.12g, %.12g) mid=(%.12g, %.12g)\n", a3->EndPoint().X(), a3->EndPoint().Y(), am.X(),
         am.Y());
  Handle(Geom2d_Ellipse) e = new Geom2d_Ellipse(gp_Elips2d(ax, 10, 5));
  printf("ellipse 10x5: period=%.15g value(0)=(%g, %g)\n", e->Period(), e->Value(0).X(), e->Value(0).Y());
  Handle(Geom2d_Parabola) p = new Geom2d_Parabola(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 1);
  printf("parabola focal 1: focus=(%g, %g)\n", p->Focus().X(), p->Focus().Y());
  Handle(Geom2d_Hyperbola) h = new Geom2d_Hyperbola(gp_Hypr2d(ax, 5, 3));
  printf("hyperbola 5/3: major=%g value(0)=(%g, %g)\n", h->MajorRadius(), h->Value(0).X(), h->Value(0).Y());
  Handle(Geom2d_TrimmedCurve) s = GCE2d_MakeSegment(gp_Pnt2d(0, 0), gp_Pnt2d(10, 5)).Value();
  gp_Pnt2d                    sp;
  gp_Vec2d                    sv;
  s->D1(s->FirstParameter(), sp, sv);
  printf("segment (0,0)-(10,5): domain=[%.15g, %.15g] D1=(%.15g, %.15g) adaptive=%d\n", s->FirstParameter(), s->LastParameter(),
         sv.X(), sv.Y(), adaptive(s));
  Handle(Geom2d_TrimmedCurve) ea = GCE2d_MakeArcOfEllipse(gp_Elips2d(ax, 10, 5), 0, M_PI, true).Value();
  printf("ellipse arc 10x5 [0, pi]: adaptive=%d\n", adaptive(ea));
  return 0;
}
