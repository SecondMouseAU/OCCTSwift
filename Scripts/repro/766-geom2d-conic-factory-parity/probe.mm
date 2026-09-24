// #1979 kernel parity for Curve2DCircleFactoryParityTests and Curve2DConicFactoryParityTests: the
// gce_Make*2d and direct Geom2d_* constructions both Curve2D factory families make, including the
// degenerate inputs the bridge refuses before OCCT sees them.
#include <gce_MakeCirc2d.hxx>
#include <gce_MakeElips2d.hxx>
#include <gce_MakeHypr2d.hxx>
#include <gce_MakeParab2d.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Ellipse.hxx>
#include <Geom2d_Hyperbola.hxx>
#include <Geom2d_Parabola.hxx>
#include <gp_Ax22d.hxx>
#include <cstdio>

static void pt(const char* tag, const Handle(Geom2d_Curve)& c, double u)
{
  gp_Pnt2d p = c->Value(u);
  printf("%s value(%g)=(%.12g, %.12g)\n", tag, u, p.X(), p.Y());
}

int main()
{
  gp_Ax2d ax(gp_Pnt2d(3, -4), gp_Dir2d(1, 0));
  for (double r : {0.0, -1.0})
  {
    gce_MakeCirc2d m(gp_Pnt2d(0, 0), r);
    printf("gce_MakeCirc2d radius %g: IsDone=%d\n", r, m.IsDone());
  }
  {
    gce_MakeCirc2d m(gp_Pnt2d(3, -4), 5);
    Handle(Geom2d_Circle) g = new Geom2d_Circle(m.Value());
    Handle(Geom2d_Circle) d = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(3, -4), gp_Dir2d(1, 0)), 5);
    pt("circle gce", g, 0);
    pt("circle direct", d, 0);
    pt("circle gce", g, M_PI / 2);
  }
  {
    gce_MakeElips2d z(ax, 0, 0), n(ax, 8, -4), e(ax, 5, 5);
    printf("gce_MakeElips2d (0,0) IsDone=%d, (8,-4) IsDone=%d, (5,5) IsDone=%d\n", z.IsDone(),
           n.IsDone(), e.IsDone());
    gce_MakeElips2d m(ax, 8, 4);
    Handle(Geom2d_Ellipse) g = new Geom2d_Ellipse(m.Value());
    Handle(Geom2d_Ellipse) d = new Geom2d_Ellipse(gp_Ax22d(gp_Pnt2d(3, -4), gp_Dir2d(1, 0)), 8, 4);
    pt("ellipse gce", g, 0);
    pt("ellipse direct", d, 0);
    pt("ellipse gce", g, M_PI / 2);
  }
  {
    gce_MakeHypr2d z(ax, 0, 0, true), s(ax, 3, 6, true);
    printf("gce_MakeHypr2d (0,0) IsDone=%d, (3,6) IsDone=%d\n", z.IsDone(), s.IsDone());
    gce_MakeHypr2d           m(ax, 6, 3, true);
    Handle(Geom2d_Hyperbola) g = new Geom2d_Hyperbola(m.Value());
    Handle(Geom2d_Hyperbola) d =
      new Geom2d_Hyperbola(gp_Ax22d(gp_Pnt2d(3, -4), gp_Dir2d(1, 0)), 6, 3);
    pt("hyperbola gce", g, 0);
    pt("hyperbola direct", d, 0);
    pt("hyperbola gce", g, 1);
  }
  {
    gce_MakeParab2d z(ax, 0);
    printf("gce_MakeParab2d focal 0 IsDone=%d\n", z.IsDone());
    gce_MakeParab2d         m(ax, 3);
    Handle(Geom2d_Parabola) g = new Geom2d_Parabola(m.Value());
    // Curve2D.parabola(focus:direction:focalLength:) steps back from the focus by the focal length.
    Handle(Geom2d_Parabola) d = new Geom2d_Parabola(gp_Ax2d(gp_Pnt2d(6 - 3, -4), gp_Dir2d(1, 0)), 3);
    pt("parabola gce", g, 0);
    pt("parabola direct", d, 0);
    pt("parabola gce", g, 2);
  }
  return 0;
}
