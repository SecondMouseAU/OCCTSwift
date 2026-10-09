// Epic #766 (#1978), kernel parity for Issue558SamplingCountBoundsTests.swift. The count bounds
// themselves are Swift-side (Sampling), refused before any kernel call, so this probes only the
// kernel facts the rewritten coneSphereRequest control depends on: IntAna_IntQuadQuad on the
// cone (semi-angle 0.5, reference radius 5) against the suite's original sphere, centred on the
// axis at (0,0,5) r 3, and against the replacement, centred on the cone's surface at (5,0,0) r 3.
#include <IntAna_Curve.hxx>
#include <IntAna_IntQuadQuad.hxx>
#include <IntAna_Quadric.hxx>
#include <cstdio>
#include <gp_Cone.hxx>
#include <gp_Sphere.hxx>

static void pair(const char* name, gp_Pnt c)
{
  gp_Cone        cone(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 0.5, 5);
  IntAna_Quadric quad;
  quad.SetQuadric(gp_Sphere(gp_Ax3(c, gp_Dir(0, 0, 1)), 3));
  IntAna_IntQuadQuad iqq(cone, quad, 1e-6);
  printf("%s: IsDone %d NbCurve %d", name, iqq.IsDone(), iqq.IsDone() ? iqq.NbCurve() : -1);
  if (iqq.IsDone() && iqq.NbCurve() >= 1)
  {
    double f, l;
    IntAna_Curve cv = iqq.Curve(1);
    cv.Domain(f, l);
    gp_Pnt p = cv.Value(f);
    printf(" | curve 1 domain [%.9g, %.9g] start (%.6g, %.6g, %.6g)", f, l, p.X(), p.Y(), p.Z());
  }
  printf("\n");
}

int main()
{
  pair("sphere (0,0,5) r3, on the axis (original)", gp_Pnt(0, 0, 5));
  pair("sphere (5,0,0) r3, on the cone surface (rewrite)", gp_Pnt(5, 0, 0));
  return 0;
}
