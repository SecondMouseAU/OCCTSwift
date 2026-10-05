// #1979 kernel parity for GccAnaCirc2d3TanTests, GccAnaLin2d2TanTests, GccAnaLineSolverTests and
// GccCircleOnConstraintTests: the GccAna / Geom2dGcc solvers, with the same inputs (unqualified,
// tolerance 1e-6), that the OCCTGccAna* and OCCTGeom2dGcc* bridge functions run.
#include <GccAna_Circ2d3Tan.hxx>
#include <GccAna_Lin2d2Tan.hxx>
#include <GccAna_Lin2dTanPar.hxx>
#include <GccAna_Lin2dTanPer.hxx>
#include <GccAna_Lin2dTanObl.hxx>
#include <GccAna_Circ2d2TanOn.hxx>
#include <GccAna_Circ2dTanOnRad.hxx>
#include <GccEnt_QualifiedLin.hxx>
#include <GccEnt_QualifiedCirc.hxx>
#include <Geom2dGcc_QualifiedCurve.hxx>
#include <Geom2dGcc_Lin2dTanObl.hxx>
#include <Geom2dGcc_Circ2d2TanOn.hxx>
#include <Geom2dGcc_Circ2dTanOnRad.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <gce_MakeCirc2d.hxx>
#include <gp_Lin2d.hxx>
#include <gp_Circ2d.hxx>
#include <gp_Ax22d.hxx>
#include <cstdio>

#define U GccEnt_unqualified
static gp_Lin2d  L(double px, double py, double dx, double dy) { return gp_Lin2d(gp_Pnt2d(px, py), gp_Dir2d(dx, dy)); }
static gp_Circ2d C(double x, double y, double r) { return gp_Circ2d(gp_Ax2d(gp_Pnt2d(x, y), gp_Dir2d(1, 0)), r); }

template <class S> static void circs(const char* tag, S& s)
{
  printf("%s: done=%d n=%d\n", tag, s.IsDone(), s.IsDone() ? s.NbSolutions() : 0);
  for (int i = 1; s.IsDone() && i <= s.NbSolutions(); i++)
    printf("  centre=(%.12g, %.12g) r=%.12g\n", s.ThisSolution(i).Location().X(), s.ThisSolution(i).Location().Y(),
           s.ThisSolution(i).Radius());
}

template <class S> static void lines(const char* tag, S& s)
{
  printf("%s: done=%d n=%d\n", tag, s.IsDone(), s.IsDone() ? s.NbSolutions() : 0);
  for (int i = 1; s.IsDone() && i <= s.NbSolutions(); i++)
    printf("  loc=(%.12g, %.12g) dir=(%.12g, %.12g)\n", s.ThisSolution(i).Location().X(), s.ThisSolution(i).Location().Y(),
           s.ThisSolution(i).Direction().X(), s.ThisSolution(i).Direction().Y());
}

int main()
{
  const double tol = 1e-6;
  {
    gce_MakeCirc2d m(gp_Pnt2d(0, 0), gp_Pnt2d(10, 0), gp_Pnt2d(5, 5));
    printf("gce_MakeCirc2d 3 points: centre=(%.12g, %.12g) r=%.12g\n", m.Value().Location().X(), m.Value().Location().Y(),
           m.Value().Radius());
    GccAna_Circ2d3Tan p(gp_Pnt2d(0, 0), gp_Pnt2d(10, 0), gp_Pnt2d(5, 5), tol);
    circs("Circ2d3Tan points", p);
  }
  {
    GccAna_Circ2d3Tan s(GccEnt_QualifiedLin(L(0, 0, 1, 0), U), GccEnt_QualifiedLin(L(0, 0, 0, 1), U),
                        GccEnt_QualifiedLin(L(10, 0, 0, 1), U), tol);
    circs("Circ2d3Tan lines x-axis, y-axis, x=10", s);
  }
  {
    GccAna_Circ2d3Tan s(GccEnt_QualifiedCirc(C(0, 0, 3), U), GccEnt_QualifiedCirc(C(10, 0, 3), U),
                        GccEnt_QualifiedCirc(C(5, 8, 3), U), tol);
    circs("Circ2d3Tan circles", s);
  }
  {
    GccAna_Circ2d3Tan s(GccEnt_QualifiedCirc(C(0, 0, 3), U), GccEnt_QualifiedCirc(C(10, 0, 3), U), gp_Pnt2d(5, 15), tol);
    circs("Circ2d3Tan 2 circles + point", s);
  }
  {
    GccAna_Circ2d3Tan s(GccEnt_QualifiedCirc(C(0, 0, 3), U), gp_Pnt2d(5, 5), gp_Pnt2d(10, 10), tol);
    circs("Circ2d3Tan circle + 2 points", s);
  }
  {
    GccAna_Circ2d3Tan s(GccEnt_QualifiedLin(L(0, 0, 1, 0), U), GccEnt_QualifiedLin(L(0, 0, 0, 1), U), gp_Pnt2d(5, 5), tol);
    circs("Circ2d3Tan 2 lines + point", s);
  }
  {
    GccAna_Lin2d2Tan s(GccEnt_QualifiedCirc(C(0, 0, 1), U), gp_Pnt2d(3, 0), tol);
    lines("Lin2d2Tan circle r1 + (3,0)", s);
  }
  {
    GccAna_Lin2dTanPar a(gp_Pnt2d(5, 5), L(0, 0, 1, 0));
    lines("Lin2dTanPar point (5,5)", a);
    GccAna_Lin2dTanPar b(GccEnt_QualifiedCirc(gp_Circ2d(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5), U), L(0, 0, 1, 0));
    lines("Lin2dTanPar circle r5", b);
    GccAna_Lin2dTanPer c(gp_Pnt2d(5, 5), L(0, 0, 1, 0));
    lines("Lin2dTanPer point (5,5)", c);
    GccAna_Lin2dTanPer d(GccEnt_QualifiedCirc(gp_Circ2d(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5), U), L(0, 0, 1, 0));
    lines("Lin2dTanPer circle r5", d);
    GccAna_Lin2dTanObl e(gp_Pnt2d(5, 5), L(0, 0, 1, 0), M_PI / 4);
    lines("Lin2dTanObl point (5,5) pi/4", e);
    Handle(Geom2d_Circle)    g = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5);
    Geom2dGcc_Lin2dTanObl    f(Geom2dGcc_QualifiedCurve(Geom2dAdaptor_Curve(g), U), L(0, 0, 1, 0), tol, M_PI / 4);
    lines("Geom2dGcc Lin2dTanObl circle r5 pi/4", f);
  }
  {
    GccAna_Circ2d2TanOn a(GccEnt_QualifiedLin(L(0, 0, 1, 0), U), GccEnt_QualifiedLin(L(0, 10, 1, 0), U), L(5, 0, 0, 1), tol);
    circs("Circ2d2TanOn y=0, y=10, centre on x=5", a);
    GccAna_Circ2dTanOnRad b(GccEnt_QualifiedLin(L(0, 0, 1, 0), U), L(0, 0, 0, 1), 5, tol);
    circs("Circ2dTanOnRad y=0, centre on x=0, r5", b);
    Handle(Geom2d_Circle)  c1 = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5);
    Handle(Geom2d_Circle)  c2 = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(20, 0), gp_Dir2d(1, 0)), 5);
    Handle(Geom2d_Line)    on = new Geom2d_Line(gp_Pnt2d(10, 0), gp_Dir2d(0, 1));
    Geom2dGcc_Circ2d2TanOn g(Geom2dGcc_QualifiedCurve(Geom2dAdaptor_Curve(c1), U),
                             Geom2dGcc_QualifiedCurve(Geom2dAdaptor_Curve(c2), U), Geom2dAdaptor_Curve(on), tol, 0, 0, 0);
    circs("Geom2dGcc Circ2d2TanOn circles r5 @0 and @20, centre on x=10", g);
    Handle(Geom2d_Line)      on2 = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(0, 1));
    Geom2dGcc_Circ2dTanOnRad h(Geom2dGcc_QualifiedCurve(Geom2dAdaptor_Curve(c1), U), Geom2dAdaptor_Curve(on2), 3, tol);
    circs("Geom2dGcc Circ2dTanOnRad circle r5, centre on x=0, r3", h);
  }
  return 0;
}
