// Epic #766 kernel-parity probe for TrsfModificationTests.swift, UzawaTests.swift and
// Vector2DMathTests.swift. Same OCCT calls, same inputs, as OCCTShapeTrsfModification
// (gp_Trsf::SetValues + BRepTools_TrsfModification + BRepTools_Modifier), OCCTShapeGetBounds
// (BRepBndLib::Add, triangulation, no gap), OCCTShapeGetVolume (BRepGProp volume properties),
// OCCTMathUzawa (math_Uzawa) and OCCTXYModulus / OCCTXYCrossed / OCCTXYDot / OCCTXYNormalize.
#include <BRepBndLib.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepTools_Modifier.hxx>
#include <BRepTools_TrsfModification.hxx>
#include <Bnd_Box.hxx>
#include <GProp_GProps.hxx>
#include <gp_Trsf.hxx>
#include <gp_XY.hxx>
#include <math_Matrix.hxx>
#include <math_Uzawa.hxx>
#include <math_Vector.hxx>
#include <cstdio>

static void modify(const char* name, const TopoDS_Shape& s, const double* a)
{
  gp_Trsf t;
  t.SetValues(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11]);
  Handle(BRepTools_TrsfModification) mod = new BRepTools_TrsfModification(t);
  BRepTools_Modifier                 m(s, mod);
  TopoDS_Shape                       r = m.ModifiedShape(s);
  Bnd_Box                            box;
  BRepBndLib::Add(r, box, true);
  double x0, y0, z0, x1, y1, z1;
  box.Get(x0, y0, z0, x1, y1, z1);
  GProp_GProps p;
  BRepGProp::VolumeProperties(r, p);
  printf("%s: done=%d valid=%d volume=%.17g min=(%.17g, %.17g, %.17g) max=(%.17g, %.17g, %.17g)\n",
         name, m.IsDone(), BRepCheck_Analyzer(r).IsValid(), p.Mass(), x0, y0, z0, x1, y1, z1);
}

int main()
{
  const double tr[12] = {1, 0, 0, 100, 0, 1, 0, 200, 0, 0, 1, 300};
  const double rz[12] = {0, -1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0};
  modify("applyTranslation (centred 10x20x30)",
         BRepPrimAPI_MakeBox(gp_Pnt(-5, -10, -15), 10, 20, 30).Shape(), tr);
  modify("applyRotation (centred 10-cube, as originally written)",
         BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape(), rz);
  modify("applyRotation (10x20x30 at (1,0,0), rewritten)",
         BRepPrimAPI_MakeBox(gp_Pnt(1, 0, 0), 10, 20, 30).Shape(), rz);

  math_Matrix Cont(1, 1, 1, 2);
  Cont(1, 1) = 1;
  Cont(1, 2) = 1;
  math_Vector Sec(1, 1);
  Sec(1) = 1;
  math_Vector Start(1, 2);
  Start(1) = 0;
  Start(2) = 0;
  math_Uzawa u(Cont, Sec, Start, 1e-6, 1e-6, 500);
  printf("constrainedOptimization: done=%d", u.IsDone());
  if (u.IsDone())
    printf(" x=(%.17g, %.17g) iterations=%d", u.Value()(1), u.Value()(2), u.NbIterations());
  printf("\n");

  printf("Vector2DMath modulus (3,4): %.17g\n", gp_XY(3, 4).Modulus());
  printf("Vector2DMath cross (1,0)x(0,1): %.17g\n", gp_XY(1, 0).Crossed(gp_XY(0, 1)));
  printf("Vector2DMath dot (1,2).(3,4): %.17g\n", gp_XY(1, 2).Dot(gp_XY(3, 4)));
  gp_XY n = gp_XY(3, 4).Normalized();
  printf("Vector2DMath normalize (3,4): (%.17g, %.17g) modulus %.17g\n", n.X(), n.Y(), n.Modulus());
  return 0;
}
