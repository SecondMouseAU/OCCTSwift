// #1979 kernel parity for Curve2DProjectionParityTests, Curve2DSimplifyBSplineTests,
// Curve2DTransformTests and Direction2DUtilityTests: the same OCCT calls, with the same inputs,
// that the projection helper, OCCTCurve2DSimplifyBSpline, OCCTCurve2DTransform and the
// OCCTDirection2D* functions make.
#include <Geom2d_Line.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <GCE2d_MakeSegment.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <Geom2dAPI_ProjectPointOnCurve.hxx>
#include <ShapeCustom_Curve2d.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#include <gp_Trsf2d.hxx>
#include <gp_Ax2d.hxx>
#include <gp_Dir2d.hxx>
#include <cstdio>

static void proj(const char* tag, const Handle(Geom2d_Curve)& c, gp_Pnt2d p)
{
  Geom2dAPI_ProjectPointOnCurve pr(p, c);
  if (pr.NbPoints() == 0)
  {
    printf("%s: no extrema\n", tag);
    return;
  }
  printf("%s: n=%d nearest param=%.12g distance=%.12g\n", tag, pr.NbPoints(), pr.LowerDistanceParameter(),
         pr.LowerDistance());
}

static void xf(const char* tag, int type, double a, double b, double c, double d, gp_Pnt2d lp, gp_Dir2d ld)
{
  Handle(Geom2d_Line) l = new Geom2d_Line(lp, ld);
  gp_Trsf2d           t;
  switch (type)
  {
    case 0: t.SetTranslation(gp_Vec2d(a, b)); break;
    case 1: t.SetRotation(gp_Pnt2d(a, b), c); break;
    case 2: t.SetScale(gp_Pnt2d(a, b), c); break;
    case 3: t.SetMirror(gp_Pnt2d(a, b)); break;
    case 4: t.SetMirror(gp_Ax2d(gp_Pnt2d(a, b), gp_Dir2d(c, d))); break;
  }
  l->Transform(t);
  printf("%s: value(0)=(%.12g, %.12g) value(1)=(%.12g, %.12g)\n", tag, l->Value(0).X(), l->Value(0).Y(), l->Value(1).X(),
         l->Value(1).Y());
}

int main()
{
  Handle(Geom2d_TrimmedCurve) s = GCE2d_MakeSegment(gp_Pnt2d(0, 0), gp_Pnt2d(10, 0)).Value();
  Handle(Geom2d_Circle)       c = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5);
  proj("segment (5,3)", s, gp_Pnt2d(5, 3));
  proj("segment (0.5,-2)", s, gp_Pnt2d(0.5, -2));
  proj("circle (10,0)", c, gp_Pnt2d(10, 0));
  proj("circle (3,4)", c, gp_Pnt2d(3, 4));
  proj("segment (0,0)", s, gp_Pnt2d(0, 0));
  {
    Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, 6);
    double xy[6][2] = {{0, 0}, {2, 0.1}, {4, 0}, {6, 0.1}, {8, 0}, {10, 0}};
    for (int i = 0; i < 6; i++)
      pts->SetValue(i + 1, gp_Pnt2d(xy[i][0], xy[i][1]));
    Geom2dAPI_Interpolate in(pts, false, 1e-6);
    in.Perform();
    Handle(Geom2d_BSplineCurve) b = in.Curve();
    printf("interpolant before: poles=%d knots=%d degree=%d\n", b->NbPoles(), b->NbKnots(), b->Degree());
    bool ok = ShapeCustom_Curve2d::SimplifyBSpline2d(b, 0.2);
    printf("SimplifyBSpline2d(0.2) returned %d: poles=%d knots=%d degree=%d end=(%.12g, %.12g)\n", ok, b->NbPoles(),
           b->NbKnots(), b->Degree(), b->EndPoint().X(), b->EndPoint().Y());
  }
  xf("line (0,0)+x translate (5,3)", 0, 5, 3, 0, 0, gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
  xf("line (1,0)+x rotate pi/2 about origin", 1, 0, 0, M_PI / 2, 0, gp_Pnt2d(1, 0), gp_Dir2d(1, 0));
  xf("line (1,0)+x scale 2 about origin", 2, 0, 0, 2, 0, gp_Pnt2d(1, 0), gp_Dir2d(1, 0));
  xf("line (1,0)+x mirror through origin", 3, 0, 0, 0, 0, gp_Pnt2d(1, 0), gp_Dir2d(1, 0));
  xf("line (1,1)+x mirror in x-axis", 4, 0, 0, 1, 0, gp_Pnt2d(1, 1), gp_Dir2d(1, 0));
  gp_Dir2d n(3, 4);
  printf("gp_Dir2d(3,4)=(%.17g, %.17g) angle((1,0),(0,1))=%.17g cross=%.17g\n", n.X(), n.Y(),
         gp_Dir2d(1, 0).Angle(gp_Dir2d(0, 1)), gp_Dir2d(1, 0).Crossed(gp_Dir2d(0, 1)));
  return 0;
}
