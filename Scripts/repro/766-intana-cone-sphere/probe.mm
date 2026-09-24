// Kernel parity probe for Tests/OCCTAnalysisTests/IntAnaConeSphereTests.swift (#1918, #1919).
// Mirrors OCCTIntAnaConeSphere / OCCTIntAnaConeSpherePoints: a gp_Cone at the origin along +Z and
// an IntAna_Quadric sphere, intersected by IntAna_IntQuadQuad; samples are IntAna_Curve::Value over
// the curve's Domain at first + (last - first) * i / (n - 1).
#include <IntAna_Curve.hxx>
#include <IntAna_IntQuadQuad.hxx>
#include <IntAna_Quadric.hxx>
#include <gp_Ax3.hxx>
#include <gp_Cone.hxx>
#include <gp_Sphere.hxx>
#include <cmath>
#include <cstdio>

static void run(double cx, double cy, double cz, double r, int samples)
{
  gp_Cone        cone(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), M_PI / 4, 0);
  IntAna_Quadric quad;
  quad.SetQuadric(gp_Sphere(gp_Ax3(gp_Pnt(cx, cy, cz), gp_Dir(0, 0, 1)), r));
  IntAna_IntQuadQuad iqq(cone, quad, 1e-6);
  printf("sphere centre (%g, %g, %g) radius %g: IsDone=%d Identical=%d NbCurve=%d\n", cx, cy, cz, r,
         (int)iqq.IsDone(), (int)iqq.IdenticalElements(), (int)iqq.NbCurve());
  if (samples == 0 || iqq.NbCurve() < 1)
    return;
  IntAna_Curve c = iqq.Curve(1);
  double       f, l;
  c.Domain(f, l);
  printf("  curve 1 domain [%.12g, %.12g], %d samples:\n", f, l, samples);
  double worstCone = 0, worstSphere = 0;
  for (int i = 0; i < samples; ++i)
  {
    double t = f + (l - f) * i / (samples - 1);
    gp_Pnt p = c.Value(t);
    // On the cone: sqrt(x^2 + y^2) == z tan(pi/4) == z. On the sphere: |p - c| == r.
    double dc = std::abs(std::sqrt(p.X() * p.X() + p.Y() * p.Y()) - p.Z());
    double ds = std::abs(p.Distance(gp_Pnt(cx, cy, cz)) - r);
    worstCone   = std::max(worstCone, dc);
    worstSphere = std::max(worstSphere, ds);
    printf("    [%d] (%.9f, %.9f, %.9f)\n", i, p.X(), p.Y(), p.Z());
  }
  printf("  max |rho - z| = %.3g, max ||p - c| - r| = %.3g\n", worstCone, worstSphere);
}

int main()
{
  run(0, 0, 5, 3, 0);  // coneSphereIntersection: on-axis sphere clear of the cone
  run(3, 0, 5, 2, 10); // both tests: off-axis sphere the cone pierces
  return 0;
}
