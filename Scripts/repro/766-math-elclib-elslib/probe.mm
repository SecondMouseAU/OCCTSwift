// Kernel parity probe for ElCLibTests and ElSLibTests (#1983): the ElCLib/ElSLib calls the
// OCCTElCLib* / OCCTElSLib* bridge functions make, with each test's own inputs.
#include <ElCLib.hxx>
#include <ElSLib.hxx>
#include <gp_Ax3.hxx>
#include <gp_Circ.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Elips.hxx>
#include <gp_Lin.hxx>
#include <gp_Pln.hxx>
#include <gp_Sphere.hxx>
#include <gp_Torus.hxx>
#include <cmath>
#include <cstdio>

static void pr(const char* tag, const gp_Pnt& p)
{
  printf("%s (%.12g, %.12g, %.12g)\n", tag, p.X(), p.Y(), p.Z());
}

int main()
{
  gp_Ax2 z(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  gp_Ax3 z3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  pr("valueOnLine", ElCLib::Value(5.0, gp_Lin(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0))));
  pr("valueOnCircle u=0", ElCLib::Value(0.0, gp_Circ(z, 10.0)));
  pr("valueOnCircle u=pi/2", ElCLib::Value(M_PI / 2, gp_Circ(z, 10.0)));
  pr("valueOnEllipse", ElCLib::Value(0.0, gp_Elips(z, 20.0, 10.0)));
  {
    gp_Pnt p;
    gp_Vec v;
    ElCLib::D1(0.0, gp_Circ(z, 10.0), p, v);
    pr("d1OnCircle point", p);
    printf("d1OnCircle tangent (%.12g, %.12g, %.12g)\n", v.X(), v.Y(), v.Z());
  }
  printf("parameterOnLine %.12g\n",
         ElCLib::Parameter(gp_Lin(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)), gp_Pnt(7, 0, 0)));
  printf("inPeriod %.15g (7 - 2pi = %.15g)\n", ElCLib::InPeriod(7.0, 0.0, 2 * M_PI), 7.0 - 2 * M_PI);
  pr("valueOnPlane", ElSLib::Value(3.0, 4.0, gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1))));
  pr("valueOnSphere", ElSLib::Value(0.0, 0.0, gp_Sphere(z3, 10.0)));
  pr("valueOnCylinder", ElSLib::Value(0.0, 10.0, gp_Cylinder(z3, 5.0)));
  pr("valueOnTorus (0,0)", ElSLib::Value(0.0, 0.0, gp_Torus(z3, 20.0, 5.0)));
  pr("valueOnTorus (0,pi/2)", ElSLib::Value(0.0, M_PI / 2, gp_Torus(z3, 20.0, 5.0)));
  {
    double u, v;
    ElSLib::Parameters(gp_Sphere(z3, 10.0), gp_Pnt(10, 0, 0), u, v);
    printf("parametersOnSphere u=%.12g v=%.12g\n", u, v);
  }
  return 0;
}
