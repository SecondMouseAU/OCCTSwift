// #1979 kernel parity for Geom2dEvalSineWaveTests, Geom2dHyperbolaTests, Geom2dLineTests,
// Geom2dLPropTests, Geom2dOffsetTests and Geom2dParabolaTests: Geom2dEval_SineWaveCurve,
// Geom2d_Hyperbola / Geom2d_Line / Geom2d_OffsetCurve / Geom2d_Parabola properties and
// GeomLProp_CurAndInf2d, with the same inputs the bridge functions use.
#include <Geom2dEval_SineWaveCurve.hxx>
#include <Geom2d_Hyperbola.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2d_Ellipse.hxx>
#include <Geom2d_OffsetCurve.hxx>
#include <Geom2d_Parabola.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <GeomLProp_CurAndInf2d.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#include <gp_Ax22d.hxx>
#include <cstdio>

static void curinf(const char* tag, const Handle(Geom2d_Curve)& c, bool inf)
{
  GeomLProp_CurAndInf2d a;
  if (inf)
    a.PerformInf(c);
  else
    a.PerformCurExt(c);
  printf("%s: n=%d", tag, a.NbPoints());
  for (int i = 1; i <= a.NbPoints(); i++)
    printf(" [u=%.12g %s]", a.Parameter(i),
           a.Type(i) == LProp_Inflection ? "Inflection" : a.Type(i) == LProp_MinCur ? "MinCur" : "MaxCur");
  printf("\n");
}

static Handle(Geom2d_BSplineCurve) interp(double pts[4][2])
{
  Handle(TColgp_HArray1OfPnt2d) p = new TColgp_HArray1OfPnt2d(1, 4);
  for (int i = 0; i < 4; i++)
    p->SetValue(i + 1, gp_Pnt2d(pts[i][0], pts[i][1]));
  Geom2dAPI_Interpolate in(p, false, 1e-6);
  in.Perform();
  return in.Curve();
}

int main()
{
  {
    Geom2dEval_SineWaveCurve s(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 1.5, 2.0, 0.0);
    for (double u : {0.0, M_PI / 4})
    {
      gp_Pnt2d p;
      gp_Vec2d v;
      s.D1(u, p, v);
      printf("sine A1.5 w2 u=%.12g: P=(%.12g, %.12g) D1=(%.12g, %.12g)\n", u, p.X(), p.Y(), v.X(), v.Y());
    }
  }
  {
    Handle(Geom2d_Hyperbola) h = new Geom2d_Hyperbola(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5, 3);
    printf("hyperbola 5/3: a=%.12g b=%.12g ecc=%.12g focal=%.12g focus1=(%.12g, %.12g)\n", h->MajorRadius(),
           h->MinorRadius(), h->Eccentricity(), h->Focal(), h->Focus1().X(), h->Focus1().Y());
  }
  {
    Handle(Geom2d_Line) l = new Geom2d_Line(gp_Pnt2d(1, 2), gp_Dir2d(1, 0));
    printf("line (1,2)+x: dir=(%.12g, %.12g) loc=(%.12g, %.12g)\n", l->Direction().X(), l->Direction().Y(),
           l->Location().X(), l->Location().Y());
    l->SetDirection(gp_Dir2d(0, 1));
    printf("  SetDirection(0,1): dir=(%.12g, %.12g)\n", l->Direction().X(), l->Direction().Y());
    l->SetLocation(gp_Pnt2d(5, 5));
    printf("  SetLocation(5,5): loc=(%.12g, %.12g)\n", l->Location().X(), l->Location().Y());
    Handle(Geom2d_Line) x = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
    printf("x-axis distance to (0,5) = %.12g\n", x->Distance(gp_Pnt2d(0, 5)));
  }
  {
    Handle(Geom2d_Ellipse) e = new Geom2d_Ellipse(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 10, 5);
    curinf("ellipse 10x5 curvature extrema", e, false);
    double s1[4][2] = {{0, 0}, {3, 10}, {7, -10}, {10, 0}};
    curinf("S-curve (0,0)(3,10)(7,-10)(10,0) inflections", interp(s1), true);
    double s2[4][2] = {{0, 0}, {2, 5}, {5, -5}, {8, 0}};
    curinf("S-curve (0,0)(2,5)(5,-5)(8,0) inflections", interp(s2), true);
  }
  {
    Handle(Geom2d_Line)        b  = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
    Handle(Geom2d_OffsetCurve) oc = new Geom2d_OffsetCurve(b, 3);
    printf("offset line by 3: offset=%.12g value(0)=(%.12g, %.12g) basis value(2)=(%.12g, %.12g)\n", oc->Offset(),
           oc->Value(0).X(), oc->Value(0).Y(), oc->BasisCurve()->Value(2).X(), oc->BasisCurve()->Value(2).Y());
    oc->SetOffsetValue(5);
    printf("  SetOffsetValue(5): offset=%.12g value(0)=(%.12g, %.12g)\n", oc->Offset(), oc->Value(0).X(), oc->Value(0).Y());
  }
  {
    // Curve2D.parabola(focus:direction:focalLength:) steps back from the focus by the focal length.
    Handle(Geom2d_Parabola) p = new Geom2d_Parabola(gp_Ax2d(gp_Pnt2d(-3, 0), gp_Dir2d(1, 0)), 3);
    printf("parabola focus (0,0) focal 3: focal=%.12g focus=(%.12g, %.12g) ecc=%.12g parameter=%.12g\n", p->Focal(),
           p->Focus().X(), p->Focus().Y(), p->Eccentricity(), p->Parameter());
    p->SetFocal(5);
    printf("  SetFocal(5): focal=%.12g focus=(%.12g, %.12g)\n", p->Focal(), p->Focus().X(), p->Focus().Y());
  }
  return 0;
}
