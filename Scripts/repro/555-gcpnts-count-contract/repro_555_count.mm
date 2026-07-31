// OCCTSwift#555 reproducer: the two GCPnts point-count defects.
//
//   1. NbPoints() is not bounded by the requested count, so a caller that sizes its buffer from
//      the request overflows it. Measured on an ellipse whose parametric epsilon is far too tight
//      near the end.
//   2. A point count below 2 stores out of bounds in GCPnts_QuasiUniformAbscissa's Bezier/BSpline
//      branch, and produces a nonsense distribution elsewhere. Each case runs in a fork()ed child
//      so one SIGSEGV does not hide the others.
//
// Build against the pinned kernel with the production defines (see the README): -DNo_Exception is
// what makes defect 2 reachable, and leaving it off measures a build nobody ships.

#include <Adaptor3d_Curve.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Line.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <GCPnts_QuasiUniformAbscissa.hxx>
#include <GCPnts_UniformAbscissa.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <gp_Ax2.hxx>
#include <gp_Elips.hxx>

#include <cstdio>
#include <cstdlib>
#include <string>
#include <sys/wait.h>
#include <unistd.h>

static Handle(Geom_Ellipse) pathologicalEllipse()
{
  return new Geom_Ellipse(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 1.0e6, 1.0e-3);
}

static Handle(Geom_BezierCurve) bezier4()
{
  TColgp_Array1OfPnt poles(1, 4);
  poles.SetValue(1, gp_Pnt(0, 0, 0));
  poles.SetValue(2, gp_Pnt(1, 2, 0));
  poles.SetValue(3, gp_Pnt(3, -1, 0));
  poles.SetValue(4, gp_Pnt(4, 0, 0));
  return new Geom_BezierCurve(poles);
}

static Handle(Geom_BSplineCurve) bspline8()
{
  TColgp_Array1OfPnt pts(1, 8);
  for (int i = 1; i <= 8; ++i)
    pts.SetValue(i, gp_Pnt(i, (i % 3) * 0.7, 0));
  GeomAPI_PointsToBSpline fit(pts);
  return fit.Curve();
}

// --- Defect 1: NbPoints() vs the requested count -----------------------------------------------

static int defect1()
{
  Handle(Geom_Ellipse) e = pathologicalEllipse();
  GeomAdaptor_Curve    ad(e);
  printf("--- Defect 1: requested vs actual NbPoints(), ellipse major=1e6 minor=1e-3 ---\n");
  int overUA = 0, overQU = 0, worstUA = 0, worstQU = 0;
  for (int n = 2; n <= 60; ++n)
  {
    GCPnts_UniformAbscissa      ua(ad, n, ad.FirstParameter(), ad.LastParameter());
    GCPnts_QuasiUniformAbscissa qu(ad, n, ad.FirstParameter(), ad.LastParameter());
    const int                   gotUA = ua.IsDone() ? ua.NbPoints() : -1;
    const int                   gotQU = qu.IsDone() ? qu.NbPoints() : -1;
    if (gotUA > n)
    {
      ++overUA;
      if (gotUA - n > worstUA)
        worstUA = gotUA - n;
    }
    if (gotQU > n)
    {
      ++overQU;
      if (gotQU - n > worstQU)
        worstQU = gotQU - n;
    }
    if (n <= 12 || gotUA > n)
      printf("  n=%-3d UniformAbscissa=%-4d QuasiUniform=%-4d%s\n", n, gotUA, gotQU,
             (gotUA > n || gotQU > n) ? "   <-- OVER REQUEST" : "");
  }
  printf("  counts 2..60: UniformAbscissa over-request %d times (worst +%d), "
         "QuasiUniform %d times (worst +%d)\n",
         overUA, worstUA, overQU, worstQU);

  // Is the surplus point a real point, or a duplicate of its neighbour?
  for (int n = 2; n <= 60; ++n)
  {
    GCPnts_UniformAbscissa ua(ad, n, ad.FirstParameter(), ad.LastParameter());
    if (!ua.IsDone() || ua.NbPoints() <= n)
      continue;
    const int    k  = ua.NbPoints();
    const double p0 = ua.Parameter(k - 1), p1 = ua.Parameter(k);
    gp_Pnt       a  = ad.Value(p0), b = ad.Value(p1);
    printf("  first over-request case n=%d: last two params differ by %.3e, points by %.3e (3D)\n",
           n, p1 - p0, a.Distance(b));
    break;
  }
  return overUA + overQU;
}

// --- Defect 2: degenerate counts ---------------------------------------------------------------

enum Klass
{
  KUniform,
  KQuasi
};

static void runCase(const char* curveName, const char* klassName, Klass k, int nbPoints)
{
  fflush(stdout);
  pid_t pid = fork();
  if (pid == 0)
  {
    Handle(Geom_Curve) c;
    std::string        cn(curveName);
    if (cn == "line")
      c = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
    else if (cn == "circle")
      c = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0);
    else if (cn == "ellipse")
      c = pathologicalEllipse();
    else if (cn == "bezier4")
      c = bezier4();
    else
      c = bspline8();

    GeomAdaptor_Curve ad(c);
    double            u1 = ad.FirstParameter(), u2 = ad.LastParameter();
    if (cn == "line")
    {
      u1 = 0.0;
      u2 = 10.0;
    }
    if (k == KUniform)
    {
      GCPnts_UniformAbscissa a(ad, nbPoints, u1, u2);
      printf("done=%d nb=%d", (int)a.IsDone(), a.IsDone() ? a.NbPoints() : -1);
    }
    else
    {
      GCPnts_QuasiUniformAbscissa a(ad, nbPoints, u1, u2);
      printf("done=%d nb=%d", (int)a.IsDone(), a.IsDone() ? a.NbPoints() : -1);
    }
    fflush(stdout);
    _exit(0);
  }
  int status = 0;
  waitpid(pid, &status, 0);
  printf("  %-10s %-22s n=%-2d : ", curveName, klassName, nbPoints);
  fflush(stdout);
  if (WIFSIGNALED(status))
    printf("  *** KILLED BY SIGNAL %d ***", WTERMSIG(status));
  printf("\n");
}

static void defect2()
{
  printf("\n--- Defect 2: degenerate point counts ---\n");
  const char* curves[] = {"line", "circle", "ellipse", "bezier4", "bspline8"};
  for (int n = 0; n <= 1; ++n)
  {
    for (const char* cn : curves)
    {
      runCase(cn, "GCPnts_UniformAbscissa", KUniform, n);
      runCase(cn, "GCPnts_QuasiUniformAbscissa", KQuasi, n);
    }
    printf("\n");
  }
  printf("  (negative count)\n");
  for (const char* cn : curves)
  {
    runCase(cn, "GCPnts_UniformAbscissa", KUniform, -3);
    runCase(cn, "GCPnts_QuasiUniformAbscissa", KQuasi, -3);
  }
}

int main()
{
  setvbuf(stdout, nullptr, _IONBF, 0);
  defect1();
  defect2();
  printf("\nPROBE COMPLETE\n");
  return 0;
}
