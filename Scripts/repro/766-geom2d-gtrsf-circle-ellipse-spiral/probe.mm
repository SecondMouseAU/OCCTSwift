// #1979 kernel parity for GeneralTransform2DTests, Geom2dCircleTests, Geom2dEllipseTests and
// Geom2dEvalArchimedeanSpiralTests: gp_GTrsf2d affinity/multiply/invert/transform, Geom2d_Circle
// and Geom2d_Ellipse properties, and Geom2dEval_ArchimedeanSpiralCurve evaluation, with the same
// inputs the bridge functions use.
#include <gp_GTrsf2d.hxx>
#include <gp_Ax2d.hxx>
#include <gp_Mat2d.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Ellipse.hxx>
#include <Geom2dEval_ArchimedeanSpiralCurve.hxx>
#include <cstdio>

static void mat(const char* tag, const gp_GTrsf2d& g)
{
  const gp_Mat2d& m = g.VectorialPart();
  printf("%s: mat=[%.12g, %.12g, %.12g, %.12g] t=(%.12g, %.12g)\n", tag, m.Value(1, 1), m.Value(1, 2), m.Value(2, 1),
         m.Value(2, 2), g.TranslationPart().X(), g.TranslationPart().Y());
}

int main()
{
  gp_GTrsf2d a, b;
  a.SetAffinity(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 2.0);
  b.SetAffinity(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 0.5);
  mat("affinity x-axis ratio 2", a);
  mat("affinity x 2 multiplied by x 0.5", a.Multiplied(b));
  mat("affinity x 2 inverted", a.Inverted());
  gp_XY p(1, 1);
  gp_XY q = a.Transformed(p);
  printf("affinity x 2 on (1,1) -> (%.12g, %.12g)\n", q.X(), q.Y());
  Handle(Geom2d_Circle) c = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(3, 4), gp_Dir2d(1, 0)), 5);
  printf("circle r5 @(3,4): radius=%.12g ecc=%.12g centre=(%.12g, %.12g) xaxis dir=(%.12g, %.12g)\n", c->Radius(),
         c->Eccentricity(), c->Location().X(), c->Location().Y(), c->XAxis().Direction().X(), c->XAxis().Direction().Y());
  c->SetRadius(8);
  printf("  SetRadius(8): radius=%.12g\n", c->Radius());
  Handle(Geom2d_Ellipse) e = new Geom2d_Ellipse(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 10, 5);
  printf("ellipse 10x5: a=%.12g b=%.12g ecc=%.12g focal=%.12g focus1=(%.12g, %.12g) focus2=(%.12g, %.12g)\n",
         e->MajorRadius(), e->MinorRadius(), e->Eccentricity(), e->Focal(), e->Focus1().X(), e->Focus1().Y(),
         e->Focus2().X(), e->Focus2().Y());
  e->SetMajorRadius(20);
  e->SetMinorRadius(8);
  printf("  SetMajorRadius(20), SetMinorRadius(8): a=%.12g b=%.12g\n", e->MajorRadius(), e->MinorRadius());
  for (double a0 : {0.0, 1.0, 2.0})
  {
    double                             g = a0 == 1.0 ? 0.5 : 1.0;
    Handle(Geom2dEval_ArchimedeanSpiralCurve) s =
      new Geom2dEval_ArchimedeanSpiralCurve(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), a0, g);
    for (double u : {0.0, 2 * M_PI})
    {
      gp_Pnt2d pt;
      gp_Vec2d d1;
      s->D1(u, pt, d1);
      printf("archimedean a=%g b=%g u=%.12g: P=(%.12g, %.12g) D1=(%.12g, %.12g)\n", a0, g, u, pt.X(), pt.Y(), d1.X(),
             d1.Y());
    }
  }
  return 0;
}
