// #1515: is the one-line fix (bound[0]/bound[2] sampled at U) sufficient, or do the corner
// coefficients need re-deriving as the issue claims?
//
// Strategy: build the same boundary set, then compute three surfaces at the same (u,v):
//   1. the pinned kernel's GeomFill_CoonsAlgPatch::Value(U,V)            (buggy)
//   2. a re-implementation using the kernel's OWN coefficients, with bound[0]/[2] at U (naive fix)
//   3. GeomFill_ConstrainedFilling::Surface(), the known-correct reference the issue used
#include <cstdio>
#include <cmath>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRep_Tool.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomFill_CoonsAlgPatch.hxx>
#include <GeomFill_SimpleBound.hxx>
#include <GeomFill_ConstrainedFilling.hxx>
#include <GeomFill_Boundary.hxx>
#include <Geom_Surface.hxx>
#include <TopoDS_Edge.hxx>
#include <gp_Pnt.hxx>
#include <Law_Function.hxx>

static Handle(GeomFill_SimpleBound) mk(gp_Pnt a, gp_Pnt b)
{
  TopoDS_Edge e = BRepBuilderAPI_MakeEdge(a, b);
  double f, l;
  Handle(Geom_Curve) c = BRep_Tool::Curve(e, f, l);
  Handle(GeomAdaptor_Curve) ac = new GeomAdaptor_Curve(c, f, l);
  return new GeomFill_SimpleBound(ac, 1e-5, 1e-5);
}

int main()
{
  gp_Pnt p00(0, 0, 0), p10(10, 0, 0), p11(10, 10, 0), p01(0, 10, 0);
  // Order per GeomFill_ConstrainedFilling's convention: bound[0],[2] are the U-direction sides.
  Handle(GeomFill_Boundary) b0 = mk(p00, p10);   // v = 0 edge, runs along U
  Handle(GeomFill_Boundary) b1 = mk(p10, p11);   // u = 1 edge, runs along V
  Handle(GeomFill_Boundary) b2 = mk(p01, p11);   // v = 1 edge, runs along U
  Handle(GeomFill_Boundary) b3 = mk(p00, p01);   // u = 0 edge, runs along V

  GeomFill_CoonsAlgPatch patch(b0, b1, b2, b3);

  printf("   u     v  |      kernel Value()     |   one-line-fixed Value()\n");
  printf("------------+-------------------------+--------------------------\n");
  double us[] = {0.0, 0.0, 0.5, 0.5, 1.0, 1.0, 0.25, 0.75};
  double vs[] = {0.0, 0.5, 0.0, 0.5, 0.0, 0.5, 0.75, 0.25};
  for (int i = 0; i < 8; ++i)
  {
    double U = us[i], V = vs[i];
    gp_Pnt k = patch.Value(U, V);

    // Re-implement Value() with the kernel's own coefficients, sampling bound[0]/[2] at U.
    double a0 = patch.Func(0)->Value(V);   // a[0] evaluated at V, as the kernel does
    double a1 = patch.Func(1)->Value(U);
    double a2 = 1.0 - a0, a3 = 1.0 - a1;
    gp_XYZ cor = patch.Bound(0)->Value(U).XYZ() * a0;
    cor += patch.Bound(1)->Value(V).XYZ() * a1;
    cor += patch.Bound(2)->Value(U).XYZ() * a2;
    cor += patch.Bound(3)->Value(V).XYZ() * a3;
    cor += patch.Corner(0).XYZ() * (-a0 * a3);
    cor += patch.Corner(1).XYZ() * (-a0 * a1);
    cor += patch.Corner(2).XYZ() * (-a1 * a2);
    cor += patch.Corner(3).XYZ() * (-a2 * a3);
    gp_Pnt fixed(cor);

    printf("%5.2f %5.2f | (%7.3f,%7.3f) | (%7.3f,%7.3f)\n",
           U, V, k.X(), k.Y(), fixed.X(), fixed.Y());
  }
  return 0;
}
