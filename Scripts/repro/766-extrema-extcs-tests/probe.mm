// Kernel-parity probe for Tests/OCCTAnalysisTests/ExtremaExtCSTests.swift (#766 execution,
// issues #1816, #1817). Mirrors OCCTExtremaExtCS / OCCTExtremaExtCSPoint: a GeomAdaptor_Curve
// over [uFirst, uLast] and a GeomAdaptor_Surface into Extrema_ExtCS(C, S, 1e-6, 1e-6).

#include <GC_MakePlane.hxx>
#include <Geom_Line.hxx>
#include <Geom_Plane.hxx>
#include <Geom_SphericalSurface.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <Extrema_ExtCS.hxx>
#include <Extrema_POnCurv.hxx>
#include <Extrema_POnSurf.hxx>
#include <gp.hxx>
#include <cmath>
#include <cstdio>

static void run(const char* name, const Handle(Geom_Curve)& c, double u0, double u1,
                const Handle(Geom_Surface)& s)
{
  Handle(GeomAdaptor_Curve)   ac = new GeomAdaptor_Curve(c, u0, u1);
  Handle(GeomAdaptor_Surface) as = new GeomAdaptor_Surface(s);
  Extrema_ExtCS               ext(*ac, *as, 1e-6, 1e-6);
  printf("%s: isDone=%d", name, (int)ext.IsDone());
  if (!ext.IsDone())
  {
    printf("\n");
    return;
  }
  printf(" isParallel=%d", (int)ext.IsParallel());
  if (ext.IsParallel())
  {
    printf(" squareDistance(1)=%.12f\n", ext.SquareDistance(1));
    return;
  }
  printf(" nbExt=%d\n", ext.NbExt());
  for (int i = 1; i <= ext.NbExt(); ++i)
  {
    Extrema_POnCurv pc;
    Extrema_POnSurf ps;
    ext.Points(i, pc, ps);
    double u, v;
    ps.Parameter(u, v);
    printf("  [%d] sqDist=%.12f dist=%.12f p1=(%.9g, %.9g, %.9g) t=%.9g p2=(%.9g, %.9g, %.9g) "
           "uv=(%.9g, %.9g)\n",
           i, ext.SquareDistance(i), std::sqrt(ext.SquareDistance(i)),
           pc.Value().X(), pc.Value().Y(), pc.Value().Z(), pc.Parameter(),
           ps.Value().X(), ps.Value().Y(), ps.Value().Z(), u, v);
  }
}

int main()
{
  // curveSurfaceParallel: line through (0,0,10) along +X, plane z = 0 (OCCTSurfacePlaneFromPointNormal).
  Handle(Geom_Line)  l1    = new Geom_Line(gp_Pnt(0, 0, 10), gp_Dir(1, 0, 0));
  Handle(Geom_Plane) plane = GC_MakePlane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)).Value();
  run("curveSurfaceParallel", l1, -10, 10, plane);

  // curveSurfaceDistance: line through (10,0,0) along +Z, sphere r=5 at origin
  // (OCCTSurfaceCreateSphere: gp_Ax3(center, gp::DZ())).
  Handle(Geom_Line)             l2  = new Geom_Line(gp_Pnt(10, 0, 0), gp_Dir(0, 0, 1));
  Handle(Geom_SphericalSurface) sph = new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp::DZ()), 5);
  run("curveSurfaceDistance", l2, -5, 5, sph);
  return 0;
}
