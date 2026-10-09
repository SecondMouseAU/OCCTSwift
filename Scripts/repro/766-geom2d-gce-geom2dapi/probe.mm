// #1979 kernel parity for GceMakeCirc2dTests, GceMakeElips2dTests, GceMakeHypr2dTests,
// GceMakeLin2dTests, GceMakeParab2dTests, Geom2dAPIInterpolateTests and
// Geom2dAPIPointsToBSplineTests: the gce_Make*2d, Geom2dAPI_Interpolate and
// Geom2dAPI_PointsToBSpline calls, with the same inputs, that the bridge functions make.
#include <gce_MakeCirc2d.hxx>
#include <gce_MakeElips2d.hxx>
#include <gce_MakeHypr2d.hxx>
#include <gce_MakeLin2d.hxx>
#include <gce_MakeParab2d.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Ellipse.hxx>
#include <Geom2d_Hyperbola.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2d_Parabola.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <Geom2dAPI_PointsToBSpline.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <cstdio>

static void pts(const char* tag, const Handle(Geom2d_Curve)& c, std::initializer_list<double> us)
{
  printf("%s domain=[%.12g, %.12g]", tag, c->FirstParameter(), c->LastParameter());
  for (double u : us)
    printf(" value(%g)=(%.12g, %.12g)", u, c->Value(u).X(), c->Value(u).Y());
  printf("\n");
}

int main()
{
  pts("gce circle centre (0,0) r5", new Geom2d_Circle(gce_MakeCirc2d(gp_Pnt2d(0, 0), 5.0).Value()), {0, M_PI / 2});
  pts("gce circle through (5,0),(0,5),(-5,0)",
      new Geom2d_Circle(gce_MakeCirc2d(gp_Pnt2d(5, 0), gp_Pnt2d(0, 5), gp_Pnt2d(-5, 0)).Value()), {0, 1, 2});
  gp_Ax2d ax(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
  pts("gce ellipse 8x4", new Geom2d_Ellipse(gce_MakeElips2d(ax, 8, 4).Value()), {0, M_PI / 2});
  pts("gce hyperbola 6/3", new Geom2d_Hyperbola(gce_MakeHypr2d(ax, 6, 3, true).Value()), {0, 1});
  pts("gce line (0,0)-(1,0)", new Geom2d_Line(gce_MakeLin2d(gp_Pnt2d(0, 0), gp_Pnt2d(1, 0)).Value()), {0, 3});
  pts("gce line x - 5 = 0", new Geom2d_Line(gce_MakeLin2d(1, 0, -5).Value()), {0, 3});
  pts("gce parabola focal 3", new Geom2d_Parabola(gce_MakeParab2d(ax, 3).Value()), {0, 6});
  for (bool periodic : {false, true})
  {
    double xy[4][2] = {{0, 0}, {1, 1}, {2, 0}, {3, 1}};
    if (periodic)
    {
      xy[3][0] = 1;
      xy[3][1] = -1;
    }
    Handle(TColgp_HArray1OfPnt2d) p = new TColgp_HArray1OfPnt2d(1, 4);
    for (int i = 0; i < 4; i++)
      p->SetValue(i + 1, gp_Pnt2d(xy[i][0], xy[i][1]));
    Geom2dAPI_Interpolate in(p, periodic, 1e-6);
    in.Perform();
    Handle(Geom2d_BSplineCurve) c = in.Curve();
    printf("interpolate periodic=%d: done=%d isPeriodic=%d poles=%d ", periodic, in.IsDone(), c->IsPeriodic(),
           c->NbPoles());
    pts("", c, {c->Knot(2)});
  }
  {
    TColgp_Array1OfPnt2d p(1, 5);
    double               xy[5][2] = {{0, 0}, {1, 2}, {2, 1}, {3, 3}, {4, 0}};
    for (int i = 0; i < 5; i++)
      p(i + 1) = gp_Pnt2d(xy[i][0], xy[i][1]);
    Geom2dAPI_PointsToBSpline a(p);
    Handle(Geom2d_BSplineCurve) c = a.Curve();
    printf("PointsToBSpline default: done=%d degree=%d poles=%d start=(%.12g, %.12g) end=(%.12g, %.12g)\n", a.IsDone(),
           c->Degree(), c->NbPoles(), c->StartPoint().X(), c->StartPoint().Y(), c->EndPoint().X(), c->EndPoint().Y());
  }
  return 0;
}
