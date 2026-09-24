// Epic #766, SurfaceAnalyticTests.swift: kernel parity for the thirteen tests. The same Geom_
// surfaces the bridge builds (GC_MakePlane point+normal, Geom_Cylindrical/Conical/Spherical/
// ToroidalSurface on gp_Ax3(origin, dir)), then D0, GeomLProp_SLProps normal and curvatures at
// Precision::Confusion() resolution (occtSurfaceLocalProps), periods and closure flags.
#include <GC_MakePlane.hxx>
#include <GeomLProp_SLProps.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Plane.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_ToroidalSurface.hxx>
#include <Precision.hxx>
#include <cstdio>

static void pt(const char* tag, const Handle(Geom_Surface)& s, double u, double v)
{
  gp_Pnt p = s->Value(u, v);
  printf("  %s S(%g,%g)=(%.17g, %.17g, %.17g)\n", tag, u, v, p.X(), p.Y(), p.Z());
}

int main()
{
  gp_Ax3               ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  Handle(Geom_Surface) plane  = GC_MakePlane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)).Value();
  Handle(Geom_Surface) sphere = new Geom_SphericalSurface(ax, 5);
  Handle(Geom_Surface) cyl3   = new Geom_CylindricalSurface(ax, 3);
  Handle(Geom_Surface) cyl4   = new Geom_CylindricalSurface(ax, 4);
  Handle(Geom_Surface) cone   = new Geom_ConicalSurface(ax, M_PI / 6, 5);
  Handle(Geom_Surface) torus  = new Geom_ToroidalSurface(ax, 10, 3);
  double               u1, u2, v1, v2;
  plane->Bounds(u1, u2, v1, v2);
  printf("planeEvaluation: uMin=%g\n", u1);
  pt("plane", plane, 0, 0);
  pt("plane", plane, 3, 4);
  GeomLProp_SLProps pn(plane, 0, 0, 1, Precision::Confusion());
  printf("planeNormal: N=(%g, %g, %g)\n", pn.Normal().X(), pn.Normal().Y(), pn.Normal().Z());
  printf("sphereProperties: IsUPeriodic=%d UPeriod=%.17g\n", sphere->IsUPeriodic(), sphere->UPeriod());
  printf("closureFlags: plane %d/%d cyl %d/%d sphere %d/%d torus %d/%d\n", plane->IsUClosed(), plane->IsVClosed(), cyl3->IsUClosed(),
         cyl3->IsVClosed(), sphere->IsUClosed(), sphere->IsVClosed(), torus->IsUClosed(), torus->IsVClosed());
  printf("sphereEvaluation:\n");
  pt("sphere", sphere, 0, 0);
  printf("cylinderCreation: IsUPeriodic=%d\n", cyl3->IsUPeriodic());
  pt("cylinder", cyl3, 0, 0);
  printf("coneCreation:\n");
  pt("cone", cone, 0, 0);
  pt("cone", cone, 0, 10);
  printf("torusCreation: periodic %d/%d\n", torus->IsUPeriodic(), torus->IsVPeriodic());
  pt("torus", torus, 0, 0);
  GeomLProp_SLProps sp(sphere, 0.5, 0.3, 2, Precision::Confusion());
  // IsCurvatureDefined() first, as occtSurfaceCurvaturePair does: it is what computes the
  // curvatures; GaussianCurvature() read cold reports 0 here.
  printf("  sphere IsCurvatureDefined=%d\n", sp.IsCurvatureDefined());
  printf("sphereGaussian/MeanCurvature: K=%.17g H=%.17g\n", sp.GaussianCurvature(), sp.MeanCurvature());
  GeomLProp_SLProps pp(plane, 0, 0, 2, Precision::Confusion());
  printf("planeGaussianCurvature: defined=%d K=%.17g\n", pp.IsCurvatureDefined(), pp.GaussianCurvature());
  GeomLProp_SLProps cp(cyl4, 0.5, 1.0, 2, Precision::Confusion());
  printf("  cylinder IsCurvatureDefined=%d\n", cp.IsCurvatureDefined());
  gp_Dir maxD, minD;
  cp.CurvatureDirections(maxD, minD);
  printf("cylinderPrincipalCurvatures: kMin=%.17g kMax=%.17g dirMin=(%g,%g,%g) dirMax=(%g,%g,%g)\n", cp.MinCurvature(), cp.MaxCurvature(),
         minD.X(), minD.Y(), minD.Z(), maxD.X(), maxD.Y(), maxD.Z());
  return 0;
}
