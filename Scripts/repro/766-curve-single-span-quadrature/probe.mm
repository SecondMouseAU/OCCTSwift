// Epic #766 (#1978), kernel parity for Issue603SingleSpanQuadratureTests.swift: the raw
// GCPnts_AbscissaPoint::Length on each fixture next to a 200,000-panel Simpson reference, so the
// transcript shows whether the pinned kernel still carries the single-span quadrature error the
// suite describes, and GCPnts_AbscissaPoint's inverse at the full length.
#include <GCPnts_AbscissaPoint.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Hyperbola.hxx>
#include <Geom_Parabola.hxx>
#include <cmath>
#include <cstdio>

static double simpson(const Handle(Geom_Curve)& c, double t0, double t1)
{
  const int n = 200000;
  double    h = (t1 - t0) / n, s = 0;
  auto      f = [&](double t) {
    gp_Pnt p;
    gp_Vec v;
    c->D1(t, p, v);
    return v.Magnitude();
  };
  s = f(t0) + f(t1);
  for (int i = 1; i < n; i++)
    s += (i % 2 ? 4.0 : 2.0) * f(t0 + i * h);
  return s * h / 3;
}

static void row(const char* name, const Handle(Geom_Curve)& c, double t0, double t1)
{
  GeomAdaptor_Curve a(c);
  double            g = GCPnts_AbscissaPoint::Length(a, t0, t1), r = simpson(c, t0, t1);
  printf("%s: GCPnts %.12g Simpson %.12g relative %.3g\n", name, g, r, fabs(g - r) / r);
}

int main()
{
  double ab[][2] = {{8, 3}, {8, 7}, {10, 1}, {100, 30}, {1, 0.05}};
  for (auto& e : ab)
  {
    char n[64];
    snprintf(n, sizeof n, "ellipse %g x %g", e[0], e[1]);
    row(n, new Geom_Ellipse(gp_Ax2(), e[0], e[1]), 0, 2 * M_PI);
  }
  row("parabola F3 [-100, 100]", new Geom_Parabola(gp_Ax2(), 3), -100, 100);
  row("hyperbola 5x2 [-4, 4]", new Geom_Hyperbola(gp_Ax2(), 5, 2), -4, 4);
  Handle(Geom_Ellipse) e = new Geom_Ellipse(gp_Ax2(), 10, 1);
  GeomAdaptor_Curve    a(e);
  double               L = GCPnts_AbscissaPoint::Length(a);
  GCPnts_AbscissaPoint inv(a, L, 0);
  printf("ellipse 10 x 1 inverse at full length: %.12g (domain end %.12g)\n", inv.Parameter(), 2 * M_PI);
  return 0;
}
