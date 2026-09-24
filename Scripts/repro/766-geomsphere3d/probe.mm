// Kernel parity probe for Tests/OCCTAnalysisTests/GeomSphere3DTests.swift (#766).
//
// Builds the same Geom_SphericalSurface that OCCTSurfaceCreateSphere builds (gp_Ax3 at the
// centre with gp::DZ(), radius r) and calls the Geom_SphericalSurface members the
// OCCTSurfaceSphere* bridge functions call, with the tests' inputs.
#include <Geom_SphericalSurface.hxx>
#include <Geom_Curve.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <Geom_Circle.hxx>
#include <gp_Ax3.hxx>
#include <gp_Sphere.hxx>
#include <gp.hxx>
#include <cstdio>

static Handle(Geom_SphericalSurface) makeSphere(double cx, double cy, double cz, double r)
{
  return new Geom_SphericalSurface(gp_Ax3(gp_Pnt(cx, cy, cz), gp::DZ()), r);
}

static void printIso(const char* name, const Handle(Geom_Curve)& c)
{
  double f = c->FirstParameter(), l = c->LastParameter();
  gp_Pnt a = c->Value(f), m = c->Value((f + l) / 2), b = c->Value(l);
  printf("%s: type=%s first=%.17g last=%.17g\n", name, c->DynamicType()->Name(), f, l);
  printf("  start=(%.17g, %.17g, %.17g)\n", a.X(), a.Y(), a.Z());
  printf("  mid=(%.17g, %.17g, %.17g)\n", m.X(), m.Y(), m.Z());
  printf("  end=(%.17g, %.17g, %.17g)\n", b.X(), b.Y(), b.Z());
}

int main()
{
  Handle(Geom_SphericalSurface) s = makeSphere(0, 0, 0, 5);
  printf("sphereRadius: Radius()=%.17g\n", s->Radius());

  Handle(Geom_SphericalSurface) s2 = makeSphere(0, 0, 0, 5);
  s2->SetRadius(10);
  printf("sphereSetRadius: after SetRadius(10) Radius()=%.17g\n", s2->Radius());

  printf("sphereArea: Area()=%.17g (4*pi*25=%.17g)\n", s->Area(), 4 * M_PI * 25);
  printf("sphereVolume: Volume()=%.17g (4/3*pi*125=%.17g)\n", s->Volume(), 4.0 / 3.0 * M_PI * 125);

  Handle(Geom_SphericalSurface) s3 = makeSphere(1, 2, 3, 5);
  gp_Pnt c = s3->Sphere().Location();
  printf("sphereCenter: Sphere().Location()=(%.17g, %.17g, %.17g)\n", c.X(), c.Y(), c.Z());

  printIso("sphereUIso: UIso(0)", s->UIso(0));
  printIso("sphereVIso: VIso(0)", s->VIso(0));

  gp_Sphere sph = s->Sphere();
  printf("sphereSphere: Sphere() centre=(%.17g, %.17g, %.17g) radius=%.17g\n",
         sph.Location().X(), sph.Location().Y(), sph.Location().Z(), sph.Radius());
  return 0;
}
