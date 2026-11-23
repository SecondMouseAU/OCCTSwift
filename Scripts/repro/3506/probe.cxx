// #3506: which inputs make IntCurve_IntConicConic::Perform (line against circle or ellipse)
// never return. One forked child per case, a 3 second alarm each, so a hang is a result and not
// the end of the run.
//
//   usage: probe            runs every case against whatever kernel it was linked with
//
// The caller shapes are the ones BRepCheck_Wire::SelfIntersect hands Geom2dInt_GInter: a line
// against a full circle (or ellipse) domain, tolerance 1e-9 on both ends of the conic's domain.
#include <IntCurve_IntConicConic.hxx>
#include <IntRes2d_Domain.hxx>
#include <gp_Ax2d.hxx>
#include <gp_Circ2d.hxx>
#include <gp_Elips2d.hxx>
#include <gp_Lin2d.hxx>

#include <cmath>
#include <cstdio>
#include <functional>
#include <limits>
#include <string>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

namespace
{
const double kTwoPi = 2.0 * M_PI;
const double kTol   = 1.0e-9;

// A line along +x through (-3, y0), domain [0, 6].
void lineAt(double y0, gp_Lin2d& L, IntRes2d_Domain& D)
{
  L = gp_Lin2d(gp_Pnt2d(-3.0, y0), gp_Dir2d(1.0, 0.0));
  D = IntRes2d_Domain(gp_Pnt2d(-3.0, y0), 0.0, kTol, gp_Pnt2d(3.0, y0), 6.0, kTol);
}

int circleCase(double r, double y0)
{
  gp_Lin2d        L;
  IntRes2d_Domain DL;
  lineAt(y0, L, DL);
  gp_Circ2d       C(gp_Ax2d(gp_Pnt2d(0.0, 0.0), gp_Dir2d(1.0, 0.0)), r);
  IntRes2d_Domain DC(gp_Pnt2d(r, 0.0), 0.0, kTol, gp_Pnt2d(r, 0.0), kTwoPi, kTol);
  IntCurve_IntConicConic I;
  I.Perform(L, DL, C, DC, kTol, kTol);
  return I.IsDone() ? I.NbPoints() : -1;
}

int ellipseCase(double major, double minor, double y0)
{
  gp_Lin2d        L;
  IntRes2d_Domain DL;
  lineAt(y0, L, DL);
  gp_Elips2d      E(gp_Ax2d(gp_Pnt2d(0.0, 0.0), gp_Dir2d(1.0, 0.0)), major, minor);
  IntRes2d_Domain DE(gp_Pnt2d(major, 0.0), 0.0, kTol, gp_Pnt2d(major, 0.0), kTwoPi, kTol);
  IntCurve_IntConicConic I;
  I.Perform(L, DL, E, DE, kTol, kTol);
  return I.IsDone() ? I.NbPoints() : -1;
}

// A circle domain whose parameters are not finite, on a healthy circle.
int circleDomainCase(double first, double last)
{
  gp_Lin2d        L;
  IntRes2d_Domain DL;
  lineAt(0.0, L, DL);
  gp_Circ2d       C(gp_Ax2d(gp_Pnt2d(0.0, 0.0), gp_Dir2d(1.0, 0.0)), 1.0);
  IntRes2d_Domain DC(gp_Pnt2d(1.0, 0.0), first, kTol, gp_Pnt2d(1.0, 0.0), last, kTol);
  IntCurve_IntConicConic I;
  I.Perform(L, DL, C, DC, kTol, kTol);
  return I.IsDone() ? I.NbPoints() : -1;
}

// Two circles of radius 1 that cross, the second with a domain whose parameters are not finite:
// the Circle/Circle overload carries the same period reduction.
int circlesDomainCase(double first, double last)
{
  gp_Circ2d       C1(gp_Ax2d(gp_Pnt2d(0.0, 0.0), gp_Dir2d(1.0, 0.0)), 1.0);
  gp_Circ2d       C2(gp_Ax2d(gp_Pnt2d(1.0, 0.0), gp_Dir2d(1.0, 0.0)), 1.0);
  IntRes2d_Domain D1(gp_Pnt2d(1.0, 0.0), 0.0, kTol, gp_Pnt2d(1.0, 0.0), kTwoPi, kTol);
  IntRes2d_Domain D2(gp_Pnt2d(2.0, 0.0), first, kTol, gp_Pnt2d(2.0, 0.0), last, kTol);
  IntCurve_IntConicConic I;
  I.Perform(C1, D1, C2, D2, kTol, kTol);
  return I.IsDone() ? I.NbPoints() : -1;
}

struct Case
{
  std::string          name;
  std::function<int()> run;
};
} // namespace

int main()
{
  const double nan = std::numeric_limits<double>::quiet_NaN();
  const double inf = std::numeric_limits<double>::infinity();
  const double den = std::numeric_limits<double>::denorm_min();

  std::vector<Case> cases = {
    {"circle r=1 (control)", [] { return circleCase(1.0, 0.0); }},
    {"circle r=1e-7", [] { return circleCase(1.0e-7, 0.0); }},
    {"circle r=1e-9", [] { return circleCase(1.0e-9, 0.0); }},
    {"circle r=1e-12", [] { return circleCase(1.0e-12, 0.0); }},
    {"circle r=1e-20", [] { return circleCase(1.0e-20, 0.0); }},
    {"circle r=1e-300", [] { return circleCase(1.0e-300, 0.0); }},
    {"circle r=denorm_min", [&] { return circleCase(den, 0.0); }},
    {"circle r=0", [] { return circleCase(0.0, 0.0); }},
    {"circle r=0, line off the centre", [] { return circleCase(0.0, 0.5); }},
    {"circle r=NaN", [&] { return circleCase(nan, 0.0); }},
    {"circle r=+inf", [&] { return circleCase(inf, 0.0); }},
    {"ellipse 2 x 1 (control)", [] { return ellipseCase(2.0, 1.0, 0.0); }},
    {"ellipse 2 x 1e-12", [] { return ellipseCase(2.0, 1.0e-12, 0.0); }},
    {"ellipse 2 x 1e-300", [] { return ellipseCase(2.0, 1.0e-300, 0.0); }},
    {"ellipse 2 x 0", [] { return ellipseCase(2.0, 0.0, 0.0); }},
    {"ellipse 0 x 0", [] { return ellipseCase(0.0, 0.0, 0.0); }},
    {"circle domain first=-inf", [&] { return circleDomainCase(-inf, kTwoPi); }},
    {"circle domain last=+inf", [&] { return circleDomainCase(0.0, inf); }},
    {"circle domain first=NaN", [&] { return circleDomainCase(nan, kTwoPi); }},
    {"circle domain last=NaN", [&] { return circleDomainCase(0.0, nan); }},
    {"two circles, domain first=-inf", [&] { return circlesDomainCase(-inf, kTwoPi); }},
    {"two circles, domain last=+inf", [&] { return circlesDomainCase(0.0, inf); }},
    {"two circles (control)", [] { return circlesDomainCase(0.0, kTwoPi); }},
  };

  int hangs = 0;
  for (const Case& c : cases)
  {
    fflush(stdout);
    pid_t pid = fork();
    if (pid == 0)
    {
      alarm(3);
      int n = c.run();
      printf("  %-36s returned, NbPoints=%d\n", c.name.c_str(), n);
      fflush(stdout);
      _exit(0);
    }
    int status = 0;
    waitpid(pid, &status, 0);
    if (WIFSIGNALED(status))
    {
      int sig = WTERMSIG(status);
      if (sig == SIGALRM)
      {
        printf("  %-36s HANG (no return in 3 s)\n", c.name.c_str());
        ++hangs;
      }
      else
      {
        printf("  %-36s SIGNAL %d\n", c.name.c_str(), sig);
        ++hangs;
      }
    }
  }
  printf("%d of %zu cases hung or crashed\n", hangs, cases.size());
  return hangs ? 1 : 0;
}
