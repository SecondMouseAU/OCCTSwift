// #766 kernel parity for Tests/OCCTAnalysisTests/CurveSurfaceIntersectionTests.swift.
// Same OCCT calls as OCCTCurveSurfaceIntersect / OCCTCurve3DIntersectSurface: GeomAPI_IntCS on
// a GC_MakeSegment curve against a Geom_SphericalSurface (gp::DZ axis) or a GC_MakePlane plane.
#include <GC_MakePlane.hxx>
#include <GC_MakeSegment.hxx>
#include <GeomAPI_IntCS.hxx>
#include <Geom_Plane.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <gp.hxx>
#include <gp_Ax3.hxx>
#include <cstdio>

static void run(const char* name, gp_Pnt a, gp_Pnt b, const Handle(Geom_Surface)& s)
{
  Handle(Geom_TrimmedCurve) c = GC_MakeSegment(a, b).Value();
  GeomAPI_IntCS             inter(c, s);
  printf("%s: IsDone=%d NbPoints=%d\n",
         name,
         inter.IsDone() ? 1 : 0,
         inter.IsDone() ? inter.NbPoints() : -1);
  for (int i = 1; inter.IsDone() && i <= inter.NbPoints(); ++i)
  {
    gp_Pnt p = inter.Point(i);
    double u, v, w;
    inter.Parameters(i, u, v, w);
    printf("  [%d] point=(%.17g, %.17g, %.17g) u=%.17g v=%.17g w=%.17g\n",
           i, p.X(), p.Y(), p.Z(), u, v, w);
  }
}

int main()
{
  Handle(Geom_SphericalSurface) sphere =
    new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp::DZ()), 5);
  Handle(Geom_Plane) plane = GC_MakePlane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)).Value();
  run("lineIntersectsSphere", gp_Pnt(0, 0, -20), gp_Pnt(0, 0, 20), sphere);
  run("lineParallelToPlane", gp_Pnt(0, 0, 5), gp_Pnt(10, 0, 5), plane);
  run("lineThroughSphereXAxis", gp_Pnt(-10, 0, 0), gp_Pnt(10, 0, 0), sphere);
  run("lineTangentToSphere", gp_Pnt(-10, 5, 0), gp_Pnt(10, 5, 0), sphere);
  run("lineMissingSphere", gp_Pnt(-10, 10, 0), gp_Pnt(10, 10, 0), sphere);
  run("lineThroughPlane", gp_Pnt(0, 0, -5), gp_Pnt(0, 0, 5), plane);
  return 0;
}
