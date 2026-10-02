// Epic #766, BndLibExtraTests.swift: kernel parity for all six tests.
// Same inputs as the Swift tests (tolerance 0, the Swift default), straight to BndLib::Add, the
// OCCT entry point each OCCTBndLib* bridge function calls.
#include <BndLib.hxx>
#include <Bnd_Box.hxx>
#include <cstdio>
#include <gp_Ax2.hxx>
#include <gp_Ax3.hxx>
#include <gp_Circ.hxx>
#include <gp_Cone.hxx>
#include <gp_Elips.hxx>
#include <gp_Hypr.hxx>
#include <gp_Parab.hxx>

static void print(const char* name, const Bnd_Box& b)
{
  double x0, y0, z0, x1, y1, z1;
  b.Get(x0, y0, z0, x1, y1, z1);
  printf("%s: min=(%.17g, %.17g, %.17g) max=(%.17g, %.17g, %.17g)\n", name, x0, y0, z0, x1, y1, z1);
}

int main()
{
  const gp_Ax2 ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0));
  {
    Bnd_Box b;
    BndLib::Add(gp_Elips(ax, 10, 5), 0.0, b);
    print("ellipseBounds", b);
  }
  {
    Bnd_Box b;
    BndLib::Add(gp_Cone(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), M_PI / 6, 5), 0, 10, 0.0, b);
    print("coneBounds", b);
  }
  {
    Bnd_Box b;
    BndLib::Add(gp_Circ(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5), 0, M_PI / 2, 0.0, b);
    print("circleArcBounds", b);
  }
  {
    Bnd_Box b;
    BndLib::Add(gp_Elips(ax, 10, 5), 0, M_PI / 2, 0.0, b);
    print("ellipseArcBounds", b);
  }
  {
    Bnd_Box b;
    BndLib::Add(gp_Parab(ax, 2), -1, 1, 0.0, b);
    print("parabolaArcBounds", b);
  }
  {
    Bnd_Box b;
    BndLib::Add(gp_Hypr(ax, 5, 3), -1, 1, 0.0, b);
    print("hyperbolaArcBounds", b);
  }
  return 0;
}
