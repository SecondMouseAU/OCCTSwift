// #1979 kernel parity for GCMake2dConicTests: the GC_MakeCircle2d / GC_MakeEllipse2d /
// GC_MakeHyperbola2d / GC_MakeParabola2d calls, with the same inputs, that the
// OCCTCurve2DMake* bridge functions make.
#include <GC_MakeCircle2d.hxx>
#include <GC_MakeEllipse2d.hxx>
#include <GC_MakeHyperbola2d.hxx>
#include <GC_MakeParabola2d.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Ellipse.hxx>
#include <Geom2d_Hyperbola.hxx>
#include <Geom2d_Parabola.hxx>
#include <gp_Circ2d.hxx>
#include <gp_Ax22d.hxx>
#include <cstdio>

static void circ(const char* tag, const Handle(Geom2d_Circle)& c)
{
  printf("%s: centre=(%.12g, %.12g) r=%.12g closed=%d value(0)=(%.12g, %.12g)\n", tag, c->Location().X(),
         c->Location().Y(), c->Radius(), c->IsClosed(), c->Value(0).X(), c->Value(0).Y());
}

int main()
{
  circ("centre+radius", GC_MakeCircle2d(gp_Pnt2d(0, 0), 5).Value());
  circ("3 points (1,0)(0,1)(-1,0)", GC_MakeCircle2d(gp_Pnt2d(1, 0), gp_Pnt2d(0, 1), gp_Pnt2d(-1, 0)).Value());
  circ("centre+point (3,0)", GC_MakeCircle2d(gp_Pnt2d(0, 0), gp_Pnt2d(3, 0)).Value());
  circ("axis r5", GC_MakeCircle2d(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5).Value());
  circ("parallel +2", GC_MakeCircle2d(gp_Circ2d(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5), 2).Value());
  circ("parallel -2", GC_MakeCircle2d(gp_Circ2d(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5), -2).Value());
  auto el = [](const char* tag, const Handle(Geom2d_Ellipse)& e) {
    printf("%s: centre=(%.12g, %.12g) a=%.12g b=%.12g closed=%d value(pi/2)=(%.12g, %.12g)\n", tag, e->Location().X(),
           e->Location().Y(), e->MajorRadius(), e->MinorRadius(), e->IsClosed(), e->Value(M_PI / 2).X(),
           e->Value(M_PI / 2).Y());
  };
  el("ellipse axis 10x5", GC_MakeEllipse2d(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 10, 5).Value());
  el("ellipse 3 points", GC_MakeEllipse2d(gp_Pnt2d(10, 0), gp_Pnt2d(0, 5), gp_Pnt2d(0, 0)).Value());
  el("ellipse ax22d 10x5", GC_MakeEllipse2d(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0), gp_Dir2d(0, 1)), 10, 5).Value());
  auto hy = [](const char* tag, const Handle(Geom2d_Hyperbola)& h) {
    printf("%s: centre=(%.12g, %.12g) a=%.12g b=%.12g value(0)=(%.12g, %.12g)\n", tag, h->Location().X(),
           h->Location().Y(), h->MajorRadius(), h->MinorRadius(), h->Value(0).X(), h->Value(0).Y());
  };
  hy("hyperbola axis 10/5", GC_MakeHyperbola2d(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 10, 5).Value());
  hy("hyperbola 3 points", GC_MakeHyperbola2d(gp_Pnt2d(10, 0), gp_Pnt2d(0, 5), gp_Pnt2d(0, 0)).Value());
  auto pa = [](const char* tag, const Handle(Geom2d_Parabola)& p) {
    printf("%s: vertex=(%.12g, %.12g) focal=%.12g focus=(%.12g, %.12g) value(2)=(%.12g, %.12g)\n", tag,
           p->Location().X(), p->Location().Y(), p->Focal(), p->Focus().X(), p->Focus().Y(), p->Value(2).X(),
           p->Value(2).Y());
  };
  pa("parabola axis focal 5", GC_MakeParabola2d(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5, true).Value());
  pa("parabola directrix x=0, focus (5,0)",
     GC_MakeParabola2d(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(0, 1)), gp_Pnt2d(5, 0)).Value());
  return 0;
}
