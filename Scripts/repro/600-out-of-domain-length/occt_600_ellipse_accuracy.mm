// Follow-up probe: how wrong is GCPnts_AbscissaPoint::Length on a single-span analytic conic?
#include <cmath>
#include <cstdio>
#include <GCPnts_AbscissaPoint.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_TrimmedCurve.hxx>

static double simpsonEllipse(double a, double b, double t0, double t1, int n = 2000000)
{
  auto f = [&](double t) { return std::hypot(a * std::sin(t), b * std::cos(t)); };
  const double h = (t1 - t0) / n;
  double       s = f(t0) + f(t1);
  for (int i = 1; i < n; ++i) s += (i % 2 ? 4 : 2) * f(t0 + i * h);
  return s * h / 3.0;
}

int main()
{
  printf("ellipse: GCPnts vs a 2M-point Simpson quadrature of the elliptic integral\n");
  printf("%8s %8s %14s %14s %10s  %s\n", "a", "b", "GCPnts", "truth", "rel err", "range");
  const double cases[][2] = {{5, 5}, {8, 3}, {8, 7}, {10, 1}, {100, 30}, {1, 0.05}};
  for (const auto& c : cases)
  {
    Handle(Geom_Ellipse) e =
        new Geom_Ellipse(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), c[0], c[1] == c[0] ? c[1] * 0.999999 : c[1]);
    GeomAdaptor_Curve ad(e);
    const double got = GCPnts_AbscissaPoint::Length(ad);
    const double truth = simpsonEllipse(c[0], c[1] == c[0] ? c[1] * 0.999999 : c[1], 0, 2 * M_PI);
    printf("%8.3f %8.3f %14.6f %14.6f %9.4f%%  whole\n", c[0], c[1], got, truth,
           100.0 * (got - truth) / truth);

    // A sub-range, to show whether the error is confined to the full period.
    const double gotHalf = GCPnts_AbscissaPoint::Length(ad, 0, M_PI);
    const double truthHalf = simpsonEllipse(c[0], c[1] == c[0] ? c[1] * 0.999999 : c[1], 0, M_PI);
    printf("%8s %8s %14.6f %14.6f %9.4f%%  [0, pi]\n", "", "", gotHalf, truthHalf,
           100.0 * (gotHalf - truthHalf) / truthHalf);

    const double gotQ = GCPnts_AbscissaPoint::Length(ad, 0, M_PI / 2);
    const double truthQ = simpsonEllipse(c[0], c[1] == c[0] ? c[1] * 0.999999 : c[1], 0, M_PI / 2);
    printf("%8s %8s %14.6f %14.6f %9.4f%%  [0, pi/2]\n", "", "", gotQ, truthQ,
           100.0 * (gotQ - truthQ) / truthQ);
  }

  // A circle is exact (length-parametrized: |u2-u1| * radius).
  Handle(Geom_Circle) circ = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0);
  GeomAdaptor_Curve   cad(circ);
  printf("\ncircle r=5: GCPnts=%.9f truth=%.9f\n", GCPnts_AbscissaPoint::Length(cad),
         2 * M_PI * 5.0);

  // Does splitting the range by hand recover the accuracy? (i.e. is it the single quadrature?)
  Handle(Geom_Ellipse) e83 = new Geom_Ellipse(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 8, 3);
  GeomAdaptor_Curve    ad83(e83);
  for (int pieces : {1, 2, 4, 8, 16, 64})
  {
    double sum = 0;
    for (int i = 0; i < pieces; ++i)
      sum += GCPnts_AbscissaPoint::Length(ad83, 2 * M_PI * i / pieces, 2 * M_PI * (i + 1) / pieces);
    printf("ellipse 8x3 summed over %2d equal sub-ranges: %.6f (truth %.6f, err %.4f%%)\n", pieces,
           sum, simpsonEllipse(8, 3, 0, 2 * M_PI),
           100.0 * (sum - simpsonEllipse(8, 3, 0, 2 * M_PI)) / simpsonEllipse(8, 3, 0, 2 * M_PI));
  }
  return 0;
}
