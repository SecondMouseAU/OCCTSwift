// Epic #766 kernel-parity probe for Tests/OCCTMathTests/GeomVector3DTests.swift.
// Same Geom_VectorWithMagnitude calls and inputs as OCCTGeomVector3D*.
#include <Geom_VectorWithMagnitude.hxx>
#include <gp_Pnt.hxx>
#include <cstdio>

static void pv(const char* n, const Handle(Geom_Vector)& v)
{
  gp_Vec g = v->Vec();
  printf("%s: (%.10g, %.10g, %.10g) magnitude=%.10g\n", n, g.X(), g.Y(), g.Z(), v->Magnitude());
}

int main()
{
  Handle(Geom_VectorWithMagnitude) a = new Geom_VectorWithMagnitude(3, 4, 0);
  printf("magnitude: %.10g\n", a->Magnitude());
  Handle(Geom_VectorWithMagnitude) b =
    new Geom_VectorWithMagnitude(gp_Pnt(1, 1, 1), gp_Pnt(4, 5, 1));
  pv("fromPoints", b);
  Handle(Geom_VectorWithMagnitude) d1 = new Geom_VectorWithMagnitude(1, 2, 3);
  Handle(Geom_VectorWithMagnitude) d2 = new Geom_VectorWithMagnitude(4, 5, 6);
  printf("dot: %.10g\n", d1->Dot(d2));
  Handle(Geom_VectorWithMagnitude) x = new Geom_VectorWithMagnitude(1, 0, 0);
  Handle(Geom_VectorWithMagnitude) y = new Geom_VectorWithMagnitude(0, 1, 0);
  pv("added", x->Added(y));
  pv("multiplied", d1->Multiplied(2.0));
  Handle(Geom_VectorWithMagnitude) z = new Geom_VectorWithMagnitude(0, 0, 10);
  pv("normalized", z->Normalized());
  pv("crossed", x->Crossed(y));
  return 0;
}
