// #1979 kernel parity for Issue1050BisectorDomainTests, Issue1085BisectorNonFiniteTests and
// coincidentBisectorsReportSegmentEndpoints: the OCCT calls OCCTBisectorInterPointPoint makes
// (Bisector_Bisec on two point pairs, Bisector_Inter over each bisector's own range), run on the
// same fixtures. Each case runs in a forked child under a 20 s alarm, so a kernel hang on a
// non-finite input is reported rather than hanging the probe.
#include <Bisector_Bisec.hxx>
#include <Bisector_Inter.hxx>
#include <Geom2d_CartesianPoint.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <IntRes2d_Domain.hxx>
#include <IntRes2d_IntersectionPoint.hxx>
#include <IntRes2d_IntersectionSegment.hxx>
#include <Standard_Failure.hxx>
#include <cmath>
#include <cstdio>
#include <limits>
#include <signal.h>
#include <sys/wait.h>
#include <unistd.h>

static bool bis(Bisector_Bisec& b, double ax, double ay, double bx, double by)
{
  Handle(Geom2d_CartesianPoint) pA = new Geom2d_CartesianPoint(gp_Pnt2d(ax, ay));
  Handle(Geom2d_CartesianPoint) pB = new Geom2d_CartesianPoint(gp_Pnt2d(bx, by));
  gp_Vec2d                      v(bx - ax, by - ay);
  gp_Vec2d                      perp(-v.Y(), v.X());
  gp_Vec2d                      v1 = perp;
  v1.Normalize();
  gp_Vec2d v2 = perp.Reversed();
  v2.Normalize();
  b.Perform(pA, pB, gp_Pnt2d((ax + bx) / 2, (ay + by) / 2), v1, v2, 1.0, 1e-6);
  return !b.Value().IsNull();
}

static void run(const char* tag, double ax, double ay, double bx, double by, double cx, double cy, double dx, double dy)
{
  fflush(stdout);
  pid_t pid = fork();
  if (pid == 0)
  {
    alarm(20);
    try
    {
      Bisector_Bisec b1, b2;
      if (!bis(b1, ax, ay, bx, by) || !bis(b2, cx, cy, dx, dy))
      {
        printf("%s: a bisector is null\n", tag);
        _exit(0);
      }
      const Handle(Geom2d_TrimmedCurve)& c1 = b1.Value();
      const Handle(Geom2d_TrimmedCurve)& c2 = b2.Value();
      double f1 = c1->FirstParameter(), l1 = c1->LastParameter();
      double f2 = c2->FirstParameter(), l2 = c2->LastParameter();
      IntRes2d_Domain d1(c1->Value(f1), f1, 1e-6, c1->Value(l1), l1, 1e-6);
      IntRes2d_Domain d2(c2->Value(f2), f2, 1e-6, c2->Value(l2), l2, 1e-6);
      Bisector_Inter  in;
      in.Perform(b1, d1, b2, d2, 1e-6, 1e-6, false);
      printf("%s: done=%d points=%d segments=%d", tag, in.IsDone(), in.NbPoints(), in.NbSegments());
      for (int i = 1; i <= in.NbPoints(); i++)
        printf(" [(%.15g, %.15g) u1=%.12g u2=%.12g]", in.Point(i).Value().X(), in.Point(i).Value().Y(),
               in.Point(i).ParamOnFirst(), in.Point(i).ParamOnSecond());
      for (int i = 1; i <= in.NbSegments(); i++)
      {
        const IntRes2d_IntersectionSegment& s = in.Segment(i);
        if (s.HasFirstPoint())
          printf(" seg-first[(%.12g, %.12g) u1=%.12g u2=%.12g]", s.FirstPoint().Value().X(), s.FirstPoint().Value().Y(),
                 s.FirstPoint().ParamOnFirst(), s.FirstPoint().ParamOnSecond());
        if (s.HasLastPoint())
          printf(" seg-last[u1=%.6g u2=%.6g]", s.LastPoint().ParamOnFirst(), s.LastPoint().ParamOnSecond());
      }
      printf("\n");
    }
    catch (Standard_Failure& e)
    {
      printf("%s: throws %s\n", tag, e.what());
    }
    fflush(stdout);
    _exit(0);
  }
  int st = 0;
  waitpid(pid, &st, 0);
  if (WIFSIGNALED(st))
    printf("%s: child killed by signal %d%s\n", tag, WTERMSIG(st), WTERMSIG(st) == SIGALRM ? " (hang, 20 s alarm)" : "");
}

int main()
{
  run("beyond old window", 0, 0, 0, 10, -155, 0, -145, 0);
  run("inside old window", 0, 0, 0, 10, -55, 0, -45, 0);
  run("parallel", 0, 0, 0, 10, 0, 40, 0, 60);
  run("dead side", 0, 0, 0, 10, 19.9995, 1.01, 20.0005, 10.99);
  run("dead side, A and B swapped", 0, 10, 0, 0, 19.9995, 1.01, 20.0005, 10.99);
  run("beyond input extent", 0, 0, 0, 10, -19.0558, 25.0900, -20.9442, 34.9100);
  run("circumcentre ABCD", 0, 0, 4, 0, 4, 0, 2, 3);
  run("circumcentre BACD", 4, 0, 0, 0, 4, 0, 2, 3);
  run("circumcentre ABDC", 0, 0, 4, 0, 2, 3, 4, 0);
  run("circumcentre BADC", 4, 0, 0, 0, 2, 3, 4, 0);
  run("coincident A=B", 5, 5, 5, 5, -55, 0, -45, 0);
  run("coincident A=B, C=D", 5, 5, 5, 5, -3, -3, -3, -3);
  run("coincident bisectors 1", 0, 0, 4, 0, 0, 0, 4, 0);
  run("coincident bisectors 2", 0, 0, 4, 0, 1, 0, 3, 0);
  run("coincident bisectors 3", 0, 0, 0, 4, 0, 1, 0, 3);
  const double nan = std::numeric_limits<double>::quiet_NaN(), inf = INFINITY, big = 1e200, n149 = 1e149;
  run("NaN a.x", nan, 0, 0, 10, -55, 0, -45, 0);
  run("NaN d.y", 0, 0, 0, 10, -55, 0, -45, nan);
  run("+inf a.x", inf, 0, 0, 10, -55, 0, -45, 0);
  run("-inf d.y", 0, 0, 0, 10, -55, 0, -45, -inf);
  run("1e200 a.x", big, 0, 0, 10, -55, 0, -45, 0);
  run("1e149 old fixture (c, d = -1e149, -1e149 + 10)", 0, 0, 0, 10, -n149, 0, -n149 + 10, 0);
  run("1e149 c.x, d.x = +1e149, meeting at (0, 5)", 0, 0, 0, 10, -n149, 0, n149, 10);
  run("1e149 a.x", n149, 0, n149, 10, -55, 0, -45, 0);
  return 0;
}
