// Kernel parity probe for the GceMake*Tests files (#1983): gce_MakeCirc, gce_MakeDir,
// gce_MakeElips, gce_MakeHypr, gce_MakeLin, gce_MakeParab, gce_MakePln (OCCTGceMake*), and
// GC_MakeConicalSurface / GC_MakeCylindricalSurface for the two #420 routes that now share them.
#include <GC_MakeConicalSurface.hxx>
#include <GC_MakeCylindricalSurface.hxx>
#include <GC_MakePlane.hxx>
#include <Geom_Circle.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Hyperbola.hxx>
#include <Geom_Line.hxx>
#include <Geom_Parabola.hxx>
#include <Geom_Plane.hxx>
#include <gce_MakeCirc.hxx>
#include <gce_MakeDir.hxx>
#include <gce_MakeElips.hxx>
#include <gce_MakeHypr.hxx>
#include <gce_MakeLin.hxx>
#include <gce_MakeParab.hxx>
#include <gce_MakePln.hxx>
#include <cmath>
#include <cstdio>

static void pr(const char* tag, const gp_Pnt& p)
{
  printf("%s (%.12g, %.12g, %.12g)\n", tag, p.X(), p.Y(), p.Z());
}

int main()
{
  gp_Ax2 z(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  {
    gce_MakeCirc        mc(gp_Pnt(5, 0, 0), gp_Pnt(0, 5, 0), gp_Pnt(-5, 0, 0));
    Handle(Geom_Circle) c = new Geom_Circle(mc.Value());
    printf("circleThrough3Points done=%d radius=%.12g\n", mc.IsDone(), c->Radius());
    pr("circleThrough3Points center", c->Location());
    pr("circleThrough3Points P(0)", c->Value(0));
  }
  {
    gce_MakeCirc        mc(gp_Pnt(1, 2, 3), gp_Dir(0, 0, 1), 7.0);
    Handle(Geom_Circle) c = new Geom_Circle(mc.Value());
    printf("circleFromCenterNormal done=%d radius=%.12g\n", mc.IsDone(), c->Radius());
    pr("circleFromCenterNormal P(0)", c->Value(0));
    pr("circleFromCenterNormal P(pi/2)", c->Value(M_PI / 2));
  }
  {
    GC_MakeConicalSurface       mk(gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 10), 5.0, 2.0);
    Handle(Geom_ConicalSurface) s = mk.Value();
    printf("coneFrom2PointsRadii done=%d semiAngle=%.15g refRadius=%.12g\n",
           mk.IsDone(), s->SemiAngle(), s->RefRadius());
    pr("coneFrom2PointsRadii axis position", s->Location());
    GC_MakeConicalSurface       sw(gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 10), 2.0, 5.0);
    Handle(Geom_ConicalSurface) t = sw.Value();
    printf("  radii swapped: semiAngle=%.15g refRadius=%.12g\n", t->SemiAngle(), t->RefRadius());
  }
  {
    GC_MakeCylindricalSurface       mk(gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 10), gp_Pnt(3, 0, 0));
    Handle(Geom_CylindricalSurface) s = mk.Value();
    printf("cylinderFrom3Points done=%d radius=%.12g\n", mk.IsDone(), s->Radius());
    pr("cylinderFrom3Points axis position", s->Location());
    GC_MakeCylindricalSurface       sw(gp_Pnt(3, 0, 0), gp_Pnt(0, 0, 10), gp_Pnt(0, 0, 0));
    Handle(Geom_CylindricalSurface) t = sw.Value();
    printf("  p1/p3 swapped: radius=%.12g\n", t->Radius());
  }
  {
    gce_MakeDir md(gp_Pnt(0, 0, 0), gp_Pnt(3, 0, 0));
    printf("directionFrom2Points done=%d (%.12g, %.12g, %.12g)\n",
           md.IsDone(), md.Value().X(), md.Value().Y(), md.Value().Z());
  }
  {
    gce_MakeElips        me(z, 10, 5);
    Handle(Geom_Ellipse) e = new Geom_Ellipse(me.Value());
    printf("ellipseFromCenterNormal done=%d major=%.12g minor=%.12g\n",
           me.IsDone(), e->MajorRadius(), e->MinorRadius());
    pr("ellipseFromCenterNormal P(0)", e->Value(0));
    pr("ellipseFromCenterNormal P(pi/2)", e->Value(M_PI / 2));
  }
  {
    gce_MakeHypr           mh(z, 8, 3);
    Handle(Geom_Hyperbola) h = new Geom_Hyperbola(mh.Value());
    printf("hyperbolaFromCenterNormal done=%d major=%.12g minor=%.12g\n",
           mh.IsDone(), h->MajorRadius(), h->MinorRadius());
    pr("hyperbolaFromCenterNormal P(0)", h->Value(0));
    pr("hyperbolaFromCenterNormal P(1)", h->Value(1));
  }
  {
    gce_MakeLin       ml(gp_Pnt(0, 0, 0), gp_Pnt(1, 2, 3));
    Handle(Geom_Line) l = new Geom_Line(ml.Value());
    gp_Dir            d = l->Position().Direction();
    printf("lineFrom2Points done=%d dir (%.12g, %.12g, %.12g)\n", ml.IsDone(), d.X(), d.Y(), d.Z());
    pr("lineFrom2Points P(0)", l->Value(0));
    pr("lineFrom2Points P(sqrt(14))", l->Value(std::sqrt(14.0)));
  }
  {
    gce_MakeParab         mp(z, 4.0);
    Handle(Geom_Parabola) p = new Geom_Parabola(mp.Value());
    printf("parabolaFromCenterNormal done=%d focal=%.12g\n", mp.IsDone(), p->Focal());
    pr("parabolaFromCenterNormal P(0)", p->Value(0));
    pr("parabolaFromCenterNormal P(8)", p->Value(8));
  }
  {
    gce_MakePln        mp(0, 0, 1, -5);
    Handle(Geom_Plane) pl = new Geom_Plane(mp.Value());
    double             a, b, c, d;
    pl->Coefficients(a, b, c, d);
    printf("planeFromEquation done=%d coefficients (%.12g, %.12g, %.12g, %.12g)\n",
           mp.IsDone(), a, b, c, d);
    pr("planeFromEquation location", pl->Location());
  }
  {
    GC_MakePlane       mp(gp_Pnt(0, 0, 0), gp_Pnt(1, 0, 0), gp_Pnt(0, 1, 0));
    Handle(Geom_Plane) pl = mp.Value();
    double             a, b, c, d;
    pl->Coefficients(a, b, c, d);
    printf("planeFrom3Points (GC_MakePlane) done=%d coefficients (%.12g, %.12g, %.12g, %.12g)\n",
           mp.IsDone(), a, b, c, d);
  }
  return 0;
}
