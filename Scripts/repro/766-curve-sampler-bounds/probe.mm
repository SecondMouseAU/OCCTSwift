// Epic #766 (#1978), kernel parity for GCPntsSamplerBoundsTests.swift (#501). The same
// 1e6 x 1e-3 ellipse and counts: what GCPnts_QuasiUniformAbscissa and GCPnts_UniformAbscissa
// return before the bridge's occtSamplerKept/occtSamplerIndex clamp, so the transcript shows
// which counts overshoot and by how much the raw last parameter sits from the end.
#include <GCPnts_QuasiUniformAbscissa.hxx>
#include <GCPnts_UniformAbscissa.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Geom_Ellipse.hxx>
#include <cstdio>

int main()
{
  Handle(Geom_Ellipse) e = new Geom_Ellipse(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 1e6, 1e-3);
  GeomAdaptor_Curve    a(e);
  double               end = e->LastParameter();
  for (int n : {4, 5, 8, 12, 14, 18, 20, 22, 25, 26, 31, 33, 34, 35, 39, 40})
  {
    GCPnts_QuasiUniformAbscissa q(a, n);
    GCPnts_UniformAbscissa      u(a, n);
    printf("count %2d: quasi NbPoints=%d last-end=%.3g | uniform NbPoints=%d last-end=%.3g\n", n,
           q.NbPoints(), q.Parameter(q.NbPoints()) - end, u.NbPoints(), u.Parameter(u.NbPoints()) - end);
  }
  return 0;
}
