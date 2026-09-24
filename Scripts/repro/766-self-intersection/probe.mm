// Epic #766, SelfIntersectionTests.swift: kernel parity for all four tests, plus the positive
// control the rewritten suite adds. Same sequence as OCCTShapeSelfIntersection:
// BRepMesh_IncrementalMesh(shape, deflection), then BRepExtrema_SelfIntersection(shape, tol),
// Perform, IsDone, OverlapElements().Size().
// Shape.box is centred on the origin (OCCTShapeCreateBox); sphere and cylinder are the plain
// BRepPrimAPI makers (OCCTShapeCreateSphere, OCCTShapeCreateCylinder).
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepExtrema_SelfIntersection.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Builder.hxx>
#include <TopoDS_Compound.hxx>
#include <cstdio>
#include <gp_Trsf.hxx>

static void run(const char* name, const TopoDS_Shape& s, double tol, double defl)
{
  BRepMesh_IncrementalMesh     mesh(s, defl);
  BRepExtrema_SelfIntersection si(s, tol);
  si.Perform();
  printf("%s: done=%d overlapCount=%d\n", name, si.IsDone(),
         si.IsDone() ? (int)si.OverlapElements().Size() : -1);
}

static TopoDS_Shape box(double a)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-a / 2, -a / 2, -a / 2), a, a, a).Shape();
}

int main()
{
  run("boxNoSelfIntersection", box(10), 0.001, 0.5);
  run("sphereNoSelfIntersection", BRepPrimAPI_MakeSphere(5).Shape(), 0.001, 0.5);
  run("cylinderNoSelfIntersection", BRepPrimAPI_MakeCylinder(3, 10).Shape(), 0.001, 0.5);
  run("customParameters", box(5), 0.01, 0.1);

  // Positive control: two 10-boxes, the second shifted by (5, 5, 5), in one compound. Their faces
  // cross, so the check has something to find.
  gp_Trsf t;
  t.SetTranslation(gp_Vec(5, 5, 5));
  TopoDS_Compound c;
  BRep_Builder    b;
  b.MakeCompound(c);
  b.Add(c, box(10));
  b.Add(c, BRepBuilderAPI_Transform(box(10), t, true).Shape());
  run("overlappingCompoundReportsOverlaps", c, 0.001, 0.5);
  return 0;
}
