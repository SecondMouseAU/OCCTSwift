// Kernel-parity probe for Tests/OCCTAnalysisTests/GeomCylinder3DTests.swift (#1855-#1858).
// Builds the same Geom_CylindricalSurface OCCTSurfaceCreateCylinder builds
// (gp_Ax3(origin, dir), radius) and prints every value the tests read.
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Curve.hxx>
#include <gp_Ax3.hxx>
#include <gp_Cylinder.hxx>
#include <cmath>
#include <cstdio>

static Handle(Geom_CylindricalSurface) make(double px, double py, double pz, double r)
{
  return new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(px, py, pz), gp_Dir(0, 0, 1)), r);
}

static void iso(const Handle(Geom_CylindricalSurface)& c, double u)
{
  Handle(Geom_Curve) l = c->UIso(u);
  gp_Pnt             p0 = l->Value(0), p3 = l->Value(3);
  printf("cylinderUIso: UIso(%.17g) type=%s first=%g last=%g Value(0)=(%.17g, %.17g, %.17g) "
         "Value(3)=(%.17g, %.17g, %.17g)\n",
         u, l->DynamicType()->Name(), l->FirstParameter(), l->LastParameter(),
         p0.X(), p0.Y(), p0.Z(), p3.X(), p3.Y(), p3.Z());
}

int main()
{
  // cylinderRadius
  Handle(Geom_CylindricalSurface) c = make(0, 0, 0, 5);
  printf("cylinderRadius: Radius=%.17g\n", c->Radius());

  // cylinderSetRadius (the bridge calls SetRadius unconditionally and returns true)
  Handle(Geom_CylindricalSurface) s = make(0, 0, 0, 5);
  s->SetRadius(10);
  printf("cylinderSetRadius: after SetRadius(10) Radius=%.17g\n", s->Radius());

  // cylinderAxis
  Handle(Geom_CylindricalSurface) a  = make(1, 2, 3, 5);
  gp_Ax1                          ax = a->Cylinder().Axis();
  printf("cylinderAxis: loc=(%.17g, %.17g, %.17g) dir=(%.17g, %.17g, %.17g)\n",
         ax.Location().X(), ax.Location().Y(), ax.Location().Z(),
         ax.Direction().X(), ax.Direction().Y(), ax.Direction().Z());

  // cylinderUIso
  iso(c, 0);
  iso(c, M_PI / 2);
  return 0;
}
