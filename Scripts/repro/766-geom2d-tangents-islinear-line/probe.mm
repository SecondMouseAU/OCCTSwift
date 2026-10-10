// #1979 kernel parity for Curve2DInterpolateTangentsParityTests, Curve2DIsLinearTests and
// Curve2DLineTests: the same OCCT calls, with the same inputs, that
// OCCTCurve2DInterpolateWithTangents, OCCTCurve2DIsLinear, OCCTCurve2DMakeLineThroughPoints and
// OCCTCurve2DMakeLineParallel make.
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <GC_MakeLine2d.hxx>
#include <ShapeCustom_Curve2d.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <Standard_Failure.hxx>
#include <cstdio>
#include <gp_Lin2d.hxx>
#include <vector>

static Handle(Geom2d_BSplineCurve) interp(const std::vector<gp_Pnt2d>& v)
{
  Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, (int)v.size());
  for (int i = 0; i < (int)v.size(); i++)
    pts->SetValue(i + 1, v[i]);
  Geom2dAPI_Interpolate in(pts, false, 1e-6);
  in.Perform();
  return in.Curve();
}

int main()
{
  for (double tol : {1e-6, 1e-3, 1e-8})
  {
    Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, 3);
    pts->SetValue(1, gp_Pnt2d(0, 0));
    pts->SetValue(2, gp_Pnt2d(5, 5));
    pts->SetValue(3, gp_Pnt2d(10, 0));
    Geom2dAPI_Interpolate in(pts, false, tol);
    in.Load(gp_Vec2d(1, 1), gp_Vec2d(1, -1));
    in.Perform();
    Handle(Geom2d_BSplineCurve) c = in.Curve();
    double                      f = c->FirstParameter(), l = c->LastParameter();
    printf("tangent interpolation tol %g: domain=[%.12g, %.12g] poles=%d mid=(%.12g, %.12g) value(2)=(%.12g, "
           "%.12g)\n",
           tol, f, l, c->NbPoles(), c->Value(0.5 * (f + l)).X(), c->Value(0.5 * (f + l)).Y(), c->Value(2).X(),
           c->Value(2).Y());
  }
  try
  {
    Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, 1);
    pts->SetValue(1, gp_Pnt2d(1, 2));
    Geom2dAPI_Interpolate in(pts, false, 1e-6);
    printf("single point: constructed\n");
  }
  catch (const Standard_Failure&)
  {
    printf("single point: Geom2dAPI_Interpolate raised\n");
  }
  for (auto v : {std::vector<gp_Pnt2d>{gp_Pnt2d(0, 0), gp_Pnt2d(5, 5), gp_Pnt2d(10, 10)},
                 std::vector<gp_Pnt2d>{gp_Pnt2d(0, 0), gp_Pnt2d(5, 10), gp_Pnt2d(10, 0)}})
  {
    auto                 c = interp(v);
    TColgp_Array1OfPnt2d poles(1, c->NbPoles());
    for (int i = 1; i <= c->NbPoles(); i++)
      poles(i) = c->Pole(i);
    for (double tol : {0.1, 1e-6})
    {
      double dev = 0;
      bool   lin = ShapeCustom_Curve2d::IsLinear(poles, tol, dev);
      printf("IsLinear (%g,%g)-(%g,%g)-(%g,%g) tol %g: %d deviation=%.12g\n", v[0].X(), v[0].Y(), v[1].X(),
             v[1].Y(), v[2].X(), v[2].Y(), tol, lin, dev);
    }
  }
  {
    GC_MakeLine2d m(gp_Pnt2d(0, 0), gp_Pnt2d(10, 10));
    printf("line through (0,0),(10,10): location=(%.12g, %.12g) direction=(%.12g, %.12g)\n",
           m.Value()->Location().X(), m.Value()->Location().Y(), m.Value()->Direction().X(),
           m.Value()->Direction().Y());
    GC_MakeLine2d p(gp_Lin2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5.0);
    printf("line parallel to x-axis at 5: location=(%.12g, %.12g) direction=(%.12g, %.12g)\n",
           p.Value()->Location().X(), p.Value()->Location().Y(), p.Value()->Direction().X(),
           p.Value()->Direction().Y());
  }
  return 0;
}
