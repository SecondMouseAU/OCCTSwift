// #1979 kernel parity for Curve2DInteriorTangentTests and Curve2DInterpolatePeriodicParityTests:
// Geom2dAPI_Interpolate with the same points, tangent flags and closure that
// OCCTCurve2DInterpolateWithInteriorTangents and OCCTCurve2DInterpolate pass it.
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#include <NCollection_HArray1.hxx>
#include <Standard_Failure.hxx>
#include <cstdio>
#include <map>
#include <vector>

static Handle(Geom2d_BSplineCurve) run(const char* tag, const std::vector<gp_Pnt2d>& v,
                                       const std::map<int, gp_Vec2d>& tans, bool closed, double tol)
{
  try
  {
    Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, (int)v.size());
    for (int i = 0; i < (int)v.size(); i++)
      pts->SetValue(i + 1, v[i]);
    Geom2dAPI_Interpolate in(pts, closed, tol);
    if (!tans.empty())
    {
      NCollection_Array1<gp_Vec2d>      tv(1, (int)v.size());
      Handle(NCollection_HArray1<bool>) fl = new NCollection_HArray1<bool>(1, (int)v.size());
      for (int i = 0; i < (int)v.size(); i++)
      {
        auto it = tans.find(i);
        tv.SetValue(i + 1, it == tans.end() ? gp_Vec2d(0, 0) : it->second);
        fl->SetValue(i + 1, it != tans.end());
      }
      in.Load(tv, fl);
    }
    in.Perform();
    if (!in.IsDone())
    {
      printf("%s: not done\n", tag);
      return nullptr;
    }
    Handle(Geom2d_BSplineCurve) c = in.Curve();
    double                      f = c->FirstParameter(), l = c->LastParameter();
    gp_Pnt2d                    p;
    gp_Vec2d                    d;
    c->D1(f, p, d);
    printf("%s: closed=%d periodic=%d domain=[%.12g, %.12g] poles=%d start=(%.12g, %.12g) D1(start)=(%.12g, "
           "%.12g) end=(%.12g, %.12g) mid=(%.12g, %.12g)\n",
           tag, c->IsClosed(), c->IsPeriodic(), f, l, c->NbPoles(), p.X(), p.Y(), d.X(), d.Y(),
           c->Value(l).X(), c->Value(l).Y(), c->Value(0.5 * (f + l)).X(), c->Value(0.5 * (f + l)).Y());
    return c;
  }
  catch (const Standard_Failure&)
  {
    printf("%s: raised\n", tag);
    return nullptr;
  }
}

int main()
{
  run("3pt no tangents", {gp_Pnt2d(0, 0), gp_Pnt2d(5, 3), gp_Pnt2d(10, 0)}, {}, false, 1e-6);
  run("3pt tangents (1,0) at 0 and 2", {gp_Pnt2d(0, 0), gp_Pnt2d(5, 5), gp_Pnt2d(10, 0)},
      {{0, gp_Vec2d(1, 0)}, {2, gp_Vec2d(1, 0)}}, false, 1e-6);
  auto c5 = run("5pt tangent (1,0) at 2",
                {gp_Pnt2d(0, 0), gp_Pnt2d(2, 3), gp_Pnt2d(5, 2), gp_Pnt2d(8, 3), gp_Pnt2d(10, 0)},
                {{2, gp_Vec2d(1, 0)}}, false, 1e-6);
  if (!c5.IsNull())
  {
    // Where the curve passes (5, 2): the knot for point 3 of a chord-length parametrisation.
    for (int i = 1; i <= c5->NbKnots(); i++)
    {
      gp_Pnt2d p;
      gp_Vec2d d;
      c5->D1(c5->Knot(i), p, d);
      printf("  knot %d u=%.12g point=(%.12g, %.12g) D1=(%.12g, %.12g)\n", i, c5->Knot(i), p.X(), p.Y(),
             d.X(), d.Y());
    }
  }
  run("closed 4pt tangent (1,0) at 1",
      {gp_Pnt2d(0, 0), gp_Pnt2d(5, 5), gp_Pnt2d(10, 0), gp_Pnt2d(5, -5)}, {{1, gp_Vec2d(1, 0)}}, true, 1e-6);
  run("2pt tangents (1,0) both", {gp_Pnt2d(0, 0), gp_Pnt2d(10, 0)}, {{0, gp_Vec2d(1, 0)}, {1, gp_Vec2d(1, 0)}},
      false, 1e-6);
  std::vector<gp_Pnt2d> sq = {gp_Pnt2d(0, 0), gp_Pnt2d(10, 0), gp_Pnt2d(10, 10), gp_Pnt2d(0, 10)};
  for (double t : {1e-6, 1e-3, 1e-4, 1e-8})
  {
    char tag[64];
    snprintf(tag, sizeof tag, "periodic square tol %g", t);
    run(tag, sq, {}, true, t);
  }
  run("periodic 2pt", {gp_Pnt2d(0, 0), gp_Pnt2d(10, 0)}, {}, true, 1e-6);
  std::vector<gp_Pnt2d> near = {gp_Pnt2d(0, 0), gp_Pnt2d(10, 0), gp_Pnt2d(10, 10), gp_Pnt2d(10, 10.00005),
                                gp_Pnt2d(0, 10)};
  run("periodic near-duplicate tol 1e-4", near, {}, true, 1e-4);
  run("periodic near-duplicate tol 1e-8", near, {}, true, 1e-8);
  return 0;
}
