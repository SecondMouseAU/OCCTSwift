#include <cstdio>
#include <cmath>
#include <CPnts_AbscissaPoint.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <gp_Ax2.hxx>
#include <gp_Elips.hxx>

// #1690: is the bridge-side convergence loop in occtArcConvergedLength still doing anything on the
// pinned kernel? Patch 0021 made CPnts_AbscissaPoint::Length adaptive in the kernel itself, so the
// prediction is that one span already equals the subdivided sum.
static double subdivided(const GeomAdaptor_Curve& ad, double lo, double hi, int n)
{
  double h = (hi - lo) / n, total = 0.0;
  for (int i = 0; i < n; ++i)
    total += CPnts_AbscissaPoint::Length(ad, lo + i * h, (i + 1 == n) ? hi : lo + (i + 1) * h);
  return total;
}

int main()
{
  // A 10 x 3 ellipse: eccentric enough that a single non-adaptive Gauss span was visibly wrong.
  gp_Elips e(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10.0, 3.0);
  occ::handle<Geom_Ellipse> ge = new Geom_Ellipse(e);
  GeomAdaptor_Curve ad(ge, 0.0, 2 * M_PI);

  double one  = CPnts_AbscissaPoint::Length(ad, 0.0, 2 * M_PI);
  printf("CPnts  single span      = %.15f\n", one);
  for (int n : {2, 4, 8, 16, 64, 256})
  {
    double s = subdivided(ad, 0.0, 2 * M_PI, n);
    printf("CPnts  %3d pieces       = %.15f   rel-diff vs single = %.3e\n", n, s,
           std::abs(s - one) / std::abs(s));
  }
  double g = GCPnts_AbscissaPoint::Length(ad, 0.0, 2 * M_PI);
  printf("GCPnts single span      = %.15f\n", g);

  // Ground truth: Simpson on the ellipse integrand, the same reference the Swift tests use.
  int    N = 200000;
  double h = (2 * M_PI) / N, acc = 0.0;
  auto   f = [&](double t) { return std::hypot(10.0 * std::sin(t), 3.0 * std::cos(t)); };
  for (int i = 0; i <= N; ++i)
  {
    double w = (i == 0 || i == N) ? 1.0 : (i % 2 ? 4.0 : 2.0);
    acc += w * f(i * h);
  }
  double truth = acc * h / 3.0;
  printf("Simpson ground truth    = %.15f\n", truth);
  printf("single-span error       = %.3e relative\n", std::abs(one - truth) / truth);
  return 0;
}
