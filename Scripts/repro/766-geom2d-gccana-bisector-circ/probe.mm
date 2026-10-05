// #1979 kernel parity for GccAnaBisectorTests, GccAnaCirc2d2TanRadTests and GccAnaCirc2dTanCenTests:
// the GccAna solvers, with the same inputs, that OCCTGccAnaPnt2dBisec, OCCTGccAnaLin2dBisec,
// OCCTGccAnaLinPnt2dBisec, OCCTGccAnaCirc2dBisec, OCCTGccAnaCircLin2dBisec,
// OCCTGccAnaCircPnt2dBisec, OCCTGccAnaCirc2d2TanRad* and OCCTGccAnaCirc2dTanCen* run.
#include <GccAna_Pnt2dBisec.hxx>
#include <GccAna_Lin2dBisec.hxx>
#include <GccAna_LinPnt2dBisec.hxx>
#include <GccAna_Circ2dBisec.hxx>
#include <GccAna_CircLin2dBisec.hxx>
#include <GccAna_CircPnt2dBisec.hxx>
#include <GccAna_Circ2d2TanRad.hxx>
#include <GccAna_Circ2dTanCen.hxx>
#include <GccEnt_QualifiedLin.hxx>
#include <GccInt_Bisec.hxx>
#include <gp_Lin2d.hxx>
#include <gp_Circ2d.hxx>
#include <gp_Elips2d.hxx>
#include <gp_Hypr2d.hxx>
#include <gp_Parab2d.hxx>
#include <gp_Ax22d.hxx>
#include <cstdio>

static void bisec(const char* tag, const Handle(GccInt_Bisec)& b)
{
  switch (b->ArcType())
  {
    case GccInt_Lin:
      printf("  %s line loc=(%.12g, %.12g) dir=(%.12g, %.12g)\n", tag, b->Line().Location().X(),
             b->Line().Location().Y(), b->Line().Direction().X(), b->Line().Direction().Y());
      break;
    case GccInt_Cir:
      printf("  %s circle centre=(%.12g, %.12g) r=%.12g\n", tag, b->Circle().Location().X(),
             b->Circle().Location().Y(), b->Circle().Radius());
      break;
    case GccInt_Ell:
      printf("  %s ellipse centre=(%.12g, %.12g) a=%.12g b=%.12g\n", tag, b->Ellipse().Location().X(),
             b->Ellipse().Location().Y(), b->Ellipse().MajorRadius(), b->Ellipse().MinorRadius());
      break;
    case GccInt_Hpr:
      printf("  %s hyperbola centre=(%.12g, %.12g) a=%.12g b=%.12g\n", tag, b->Hyperbola().Location().X(),
             b->Hyperbola().Location().Y(), b->Hyperbola().MajorRadius(), b->Hyperbola().MinorRadius());
      break;
    case GccInt_Par:
      printf("  %s parabola vertex=(%.12g, %.12g) focal=%.12g\n", tag, b->Parabola().Location().X(),
             b->Parabola().Location().Y(), b->Parabola().Focal());
      break;
    default:
      printf("  %s point\n", tag);
  }
}

int main()
{
  gp_Circ2d c5(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5);
  {
    GccAna_Pnt2dBisec b(gp_Pnt2d(0, 0), gp_Pnt2d(10, 0));
    printf("Pnt2dBisec (0,0)(10,0): loc=(%.12g, %.12g) dir=(%.12g, %.12g)\n", b.ThisSolution().Location().X(),
           b.ThisSolution().Location().Y(), b.ThisSolution().Direction().X(), b.ThisSolution().Direction().Y());
  }
  {
    GccAna_Lin2dBisec b(gp_Lin2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), gp_Lin2d(gp_Pnt2d(0, 0), gp_Dir2d(0, 1)));
    printf("Lin2dBisec x-axis/y-axis: n=%d\n", b.NbSolutions());
    for (int i = 1; i <= b.NbSolutions(); i++)
      printf("  loc=(%.12g, %.12g) dir=(%.12g, %.12g)\n", b.ThisSolution(i).Location().X(),
             b.ThisSolution(i).Location().Y(), b.ThisSolution(i).Direction().X(), b.ThisSolution(i).Direction().Y());
  }
  {
    GccAna_LinPnt2dBisec b(gp_Lin2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), gp_Pnt2d(5, 5));
    printf("LinPnt2dBisec x-axis/(5,5):\n");
    bisec("", b.ThisSolution());
  }
  {
    GccAna_Circ2dBisec b(c5, gp_Circ2d(gp_Ax22d(gp_Pnt2d(15, 0), gp_Dir2d(1, 0)), 3));
    printf("Circ2dBisec r5@(0,0) r3@(15,0): n=%d\n", b.NbSolutions());
    for (int i = 1; i <= b.NbSolutions(); i++)
      bisec("", b.ThisSolution(i));
  }
  {
    GccAna_CircLin2dBisec b(c5, gp_Lin2d(gp_Pnt2d(0, 10), gp_Dir2d(1, 0)));
    printf("CircLin2dBisec r5 / y=10: n=%d\n", b.NbSolutions());
    for (int i = 1; i <= b.NbSolutions(); i++)
      bisec("", b.ThisSolution(i));
  }
  {
    GccAna_CircPnt2dBisec b(c5, gp_Pnt2d(10, 0));
    printf("CircPnt2dBisec r5 / (10,0): n=%d\n", b.NbSolutions());
    for (int i = 1; i <= b.NbSolutions(); i++)
      bisec("", b.ThisSolution(i));
  }
  {
    GccAna_Circ2d2TanRad s(gp_Pnt2d(0, 0), gp_Pnt2d(2, 0), 2.0, 1e-6);
    printf("Circ2d2TanRad (0,0)(2,0) r2: n=%d\n", s.NbSolutions());
    for (int i = 1; i <= s.NbSolutions(); i++)
      printf("  centre=(%.12g, %.12g) r=%.12g\n", s.ThisSolution(i).Location().X(), s.ThisSolution(i).Location().Y(),
             s.ThisSolution(i).Radius());
    GccAna_Circ2d2TanRad t(GccEnt_QualifiedLin(gp_Lin2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), GccEnt_unqualified),
                           GccEnt_QualifiedLin(gp_Lin2d(gp_Pnt2d(0, 0), gp_Dir2d(0, 1)), GccEnt_unqualified), 5.0, 1e-6);
    printf("Circ2d2TanRad x-axis y-axis r5: n=%d\n", t.NbSolutions());
    for (int i = 1; i <= t.NbSolutions(); i++)
      printf("  centre=(%.12g, %.12g) r=%.12g\n", t.ThisSolution(i).Location().X(), t.ThisSolution(i).Location().Y(),
             t.ThisSolution(i).Radius());
  }
  {
    GccAna_Circ2dTanCen a(gp_Pnt2d(3, 0), gp_Pnt2d(0, 0));
    printf("Circ2dTanCen point (3,0) centre (0,0): n=%d r=%.12g\n", a.NbSolutions(), a.ThisSolution(1).Radius());
    GccAna_Circ2dTanCen b(gp_Lin2d(gp_Pnt2d(0, 5), gp_Dir2d(1, 0)), gp_Pnt2d(0, 0));
    printf("Circ2dTanCen line y=5 centre (0,0): n=%d r=%.12g\n", b.NbSolutions(), b.ThisSolution(1).Radius());
  }
  return 0;
}
