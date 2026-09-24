// Kernel parity probe for Tests/OCCTAnalysisTests/BndSphereTests.swift (#766).
//
// Same Bnd_Sphere calls the bridge makes (OCCTBridge_Spatial_Bounding.mm OCCTBndSphereCreate,
// OCCTBridge_Spatial_MathSolvers.mm for the rest): construct with (center, radius, 0, 0) then
// SetValid(true); Radius(); Center(); Distance(gp_XYZ); IsOut(gp_XYZ, maxDist = 0);
// IsOut(Bnd_Sphere); Add(Bnd_Sphere).
#include <Bnd_Sphere.hxx>
#include <gp_XYZ.hxx>
#include <cstdio>

static Bnd_Sphere make(double x, double y, double z, double r)
{
  Bnd_Sphere s(gp_XYZ(x, y, z), r, 0, 0);
  s.SetValid(true);
  return s;
}

static bool isOutPoint(const Bnd_Sphere& s, double x, double y, double z)
{
  double maxDist = 0;
  return s.IsOut(gp_XYZ(x, y, z), maxDist);
}

int main()
{
  {
    Bnd_Sphere s = make(1, 2, 3, 5);
    gp_XYZ     c = s.Center();
    printf("createAndQuery radius=%.17g center=(%.17g, %.17g, %.17g)\n", s.Radius(), c.X(), c.Y(), c.Z());
  }
  {
    Bnd_Sphere s = make(0, 0, 0, 5);
    printf("distanceToPoint (10,0,0) distance=%.17g\n", s.Distance(gp_XYZ(10, 0, 0)));
    printf("distanceToPoint (0,3,4) distance=%.17g\n", s.Distance(gp_XYZ(0, 3, 4)));
  }
  {
    Bnd_Sphere s = make(0, 0, 0, 5);
    printf("isOutsidePoint (100,0,0)=%d (1,0,0)=%d (0,0,0)=%d (6,0,0)=%d (4.9,0,0)=%d\n",
           (int)isOutPoint(s, 100, 0, 0),
           (int)isOutPoint(s, 1, 0, 0),
           (int)isOutPoint(s, 0, 0, 0),
           (int)isOutPoint(s, 6, 0, 0),
           (int)isOutPoint(s, 4.9, 0, 0));
  }
  {
    Bnd_Sphere s1 = make(0, 0, 0, 1);
    Bnd_Sphere s2 = make(100, 0, 0, 1);
    Bnd_Sphere s3 = make(1.5, 0, 0, 1);
    printf("isOutsideSphere far=%d overlapping=%d\n", (int)s1.IsOut(s2), (int)s1.IsOut(s3));
  }
  {
    Bnd_Sphere s1 = make(0, 0, 0, 5);
    Bnd_Sphere s2 = make(10, 0, 0, 5);
    s1.Add(s2);
    gp_XYZ c = s1.Center();
    printf("addMerge radius=%.17g center=(%.17g, %.17g, %.17g)\n", s1.Radius(), c.X(), c.Y(), c.Z());
  }
  return 0;
}
