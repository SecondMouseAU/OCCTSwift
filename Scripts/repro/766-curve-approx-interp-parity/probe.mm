// Epic #766 (#1978), kernel parity for Issue491Curve3DApproxParityTests and
// Issue493InterpolatePeriodicParityTests. Both suites compare two Swift entry points to each other,
// so this records what the one kernel class under both returns: GeomConvert_ApproxCurve on the
// fixtures (flags, maxError, degree, poles), and GeomAPI_Interpolate periodic on the square, the
// two-point loop, the single point and the near-coincident triple at each tolerance.
#include <GeomAPI_Interpolate.hxx>
#include <GeomConvert_ApproxCurve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Line.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <cstdio>
#include <vector>

static void approx(const char* name, const Handle(Geom_Curve)& c, double tol, GeomAbs_Shape s, int seg, int deg)
{
  try
  {
    GeomConvert_ApproxCurve a(c, tol, s, seg, deg);
    printf("%s: IsDone %d HasResult %d MaxError %.6g", name, a.IsDone(), a.HasResult(), a.MaxError());
    if (a.HasResult())
      printf(" degree %d poles %d", a.Curve()->Degree(), a.Curve()->NbPoles());
    printf("\n");
  }
  catch (Standard_Failure& e)
  {
    printf("%s: throws %s\n", name, e.what());
  }
}

static void interp(const char* name, const std::vector<gp_Pnt>& p, double tol)
{
  try
  {
    Handle(TColgp_HArray1OfPnt) a = new TColgp_HArray1OfPnt(1, (int)p.size());
    for (int i = 0; i < (int)p.size(); i++)
      a->SetValue(i + 1, p[i]);
    GeomAPI_Interpolate ip(a, true, tol);
    ip.Perform();
    printf("%s tol %g: IsDone %d", name, tol, ip.IsDone());
    if (ip.IsDone())
      printf(" periodic %d closed %d domain [%.17g, %.17g]", ip.Curve()->IsPeriodic(), ip.Curve()->IsClosed(),
             ip.Curve()->FirstParameter(), ip.Curve()->LastParameter());
    printf("\n");
  }
  catch (Standard_Failure& e)
  {
    printf("%s tol %g: throws %s\n", name, tol, e.what());
  }
}

int main()
{
  Handle(Geom_Circle)  circ = new Geom_Circle(gp_Ax2(), 10);
  Handle(Geom_Ellipse) ell  = new Geom_Ellipse(gp_Ax2(), 50, 1);
  Handle(Geom_Curve)   seg  = new Geom_TrimmedCurve(new Geom_Line(gp_Pnt(1, 2, 3), gp_Dir(1, 1, 0)), 0, 10);
  approx("circle defaults", circ, 1e-3, GeomAbs_C2, 100, 8);
  approx("circle 1 seg deg 3 tol 1e-9", circ, 1e-9, GeomAbs_C0, 1, 3);
  approx("circle 2 seg deg 3 tol 1e-9", circ, 1e-9, GeomAbs_C0, 2, 3);
  approx("circle tol 1e-15", circ, 1e-15, GeomAbs_C2, 100, 8);
  approx("ellipse defaults", ell, 1e-3, GeomAbs_C2, 100, 8);
  approx("ellipse 1 seg deg 3", ell, 1e-9, GeomAbs_C0, 1, 3);
  approx("ellipse deg 4 in 4 seg", ell, 1e-12, GeomAbs_C2, 4, 4);
  approx("line segment", seg, 1e-6, GeomAbs_C1, 10, 3);
  approx("ellipse seg 40 deg 5", ell, 1e-6, GeomAbs_C2, 40, 5);
  approx("ellipse seg 5 deg 40", ell, 1e-6, GeomAbs_C2, 5, 40);

  interp("square", {gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0), gp_Pnt(0, 10, 0)}, 1e-6);
  interp("two points", {gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)}, 1e-6);
  interp("one point", {gp_Pnt(1, 2, 3)}, 1e-6);
  for (double t : {1e-6, 1e-9, 1e-2})
    interp("near-coincident", {gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10.001, 0, 0)}, t);
  interp("non-planar", {gp_Pnt(5, 0, 0), gp_Pnt(0, 5, 2), gp_Pnt(-5, 0, 4), gp_Pnt(0, -5, 2)}, 1e-5);
  return 0;
}
