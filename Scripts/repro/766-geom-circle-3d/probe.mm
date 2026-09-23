// #766 kernel parity for Tests/OCCTAnalysisTests/GeomCircle3DTests.swift.
// Builds the circle the way OCCTCurve3DCreateCircle does (Geom_Circle on gp_Ax2(center, normal))
// and reads the same accessors the OCCTCurve3DCircle* bridge functions read.
#include <Geom_Circle.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <cstdio>

static void ax1(const char* name, const gp_Ax1& a)
{
  printf("%s: position=(%.17g, %.17g, %.17g) direction=(%.17g, %.17g, %.17g)\n", name,
         a.Location().X(), a.Location().Y(), a.Location().Z(), a.Direction().X(),
         a.Direction().Y(), a.Direction().Z());
}

int main()
{
  Handle(Geom_Circle) c0 = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
  printf("circleRadius: radius=%.17g\n", c0->Radius());
  c0->SetRadius(10.0);
  printf("circleSetRadius: radius after SetRadius(10)=%.17g\n", c0->Radius());
  Handle(Geom_Circle) c1 = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
  printf("circleEccentricity: eccentricity=%.17g\n", c1->Eccentricity());

  Handle(Geom_Circle) c = new Geom_Circle(gp_Ax2(gp_Pnt(1, 2, 3), gp_Dir(0, 0, 1)), 5);
  gp_Pnt              ctr = c->Circ().Location();
  printf("circleCenter: center=(%.17g, %.17g, %.17g)\n", ctr.X(), ctr.Y(), ctr.Z());
  ax1("circleXAxis", c->XAxis());
  ax1("circleYAxis", c->YAxis());
  return 0;
}
