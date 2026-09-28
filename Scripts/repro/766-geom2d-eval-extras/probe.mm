// #1979 kernel parity for Curve2DConvertToLineTests, Curve2DEvalTests, Curve2DExtrasTests and
// Curve2DExtrasV112Tests: the same OCCT calls, with the same inputs, that OCCTCurve2DConvertToLine,
// OCCTCurve2DEvalD0/D1/D2, OCCTCurve2DReverse, OCCTCurve2DCopy, OCCTCurve2DCurveType and
// OCCTCurve2DNearestParameter make.
#include <Geom2d_Line.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <Geom2dAPI_ProjectPointOnCurve.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <ShapeCustom_Curve2d.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#include <cstdio>

int main()
{
  {
    Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, 2);
    pts->SetValue(1, gp_Pnt2d(0, 0));
    pts->SetValue(2, gp_Pnt2d(10, 0));
    Geom2dAPI_Interpolate in(pts, false, 1e-6);
    in.Perform();
    Handle(Geom2d_BSplineCurve) c = in.Curve();
    double                      nf = 0, nl = 0, dev = 0;
    Handle(Geom2d_Line)         l =
      ShapeCustom_Curve2d::ConvertToLine2d(c, c->FirstParameter(), c->LastParameter(), 1e-3, nf, nl, dev);
    printf("ConvertToLine2d: interpolant domain=[%.12g, %.12g] line=%s newFirst=%.12g newLast=%.12g "
           "deviation=%.3g\n",
           c->FirstParameter(), c->LastParameter(), l.IsNull() ? "null" : "Geom2d_Line", nf, nl, dev);
    if (!l.IsNull())
      printf("  line location=(%.12g, %.12g) direction=(%.12g, %.12g) value(newLast)=(%.12g, %.12g)\n",
             l->Location().X(), l->Location().Y(), l->Direction().X(), l->Direction().Y(),
             l->Value(nl).X(), l->Value(nl).Y());
  }
  Handle(Geom2d_Circle) c5 = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5);
  {
    gp_Pnt2d p;
    gp_Vec2d v1, v2;
    c5->D2(0, p, v1, v2);
    printf("circle r5 D2(0): P=(%.12g, %.12g) D1=(%.12g, %.12g) D2=(%.12g, %.12g)\n", p.X(), p.Y(),
           v1.X(), v1.Y(), v2.X(), v2.Y());
  }
  {
    Handle(Geom2d_Line) l = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
    l->Reverse();
    printf("line after Reverse: value(1)=(%.12g, %.12g)\n", l->Value(1).X(), l->Value(1).Y());
  }
  {
    Handle(Geom2d_Circle) orig = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5);
    Handle(Geom2d_Curve)  copy = Handle(Geom2d_Curve)::DownCast(orig->Copy());
    orig->Reverse();
    printf("circle copy then reverse original: orig value(pi/2)=(%.12g, %.12g) copy value(pi/2)=(%.12g, "
           "%.12g) copy closed=%d\n",
           orig->Value(M_PI / 2).X(), orig->Value(M_PI / 2).Y(), copy->Value(M_PI / 2).X(),
           copy->Value(M_PI / 2).Y(), copy->IsClosed());
  }
  {
    Handle(Geom2d_Line) l = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
    printf("Geom2dAdaptor type line=%d circle=%d\n", (int)Geom2dAdaptor_Curve(l).GetType(),
           (int)Geom2dAdaptor_Curve(c5).GetType());
    Geom2dAPI_ProjectPointOnCurve p(gp_Pnt2d(5, 0), l);
    printf("nearest parameter of (5,0) on x-axis line: %.17g\n", p.LowerDistanceParameter());
  }
  return 0;
}
