// Kernel-parity probe for Tests/OCCTAnalysisTests/PolyhedralDistanceTests.swift (#766
// execution, issue #1882). Mirrors the Swift test: two r=5 spheres 20 apart, each meshed by
// OCCTShapeCreateMesh (BRepMesh_IncrementalMesh(shape, 0.1, false, 0.5)), then
// OCCTShapePolyhedralDistance (BRepExtrema_Poly::Distance).

#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepExtrema_Poly.hxx>
#include <gp_Trsf.hxx>
#include <cstdio>

static void poly(const char* name, const TopoDS_Shape& a, const TopoDS_Shape& b)
{
  gp_Pnt           p1, p2;
  Standard_Real    d  = -1;
  Standard_Boolean ok = BRepExtrema_Poly::Distance(a, b, p1, p2, d);
  printf("%s: ok=%d", name, (int)ok);
  if (ok)
    printf(" distance=%.12f p1=(%.9g, %.9g, %.9g) p2=(%.9g, %.9g, %.9g)",
           d, p1.X(), p1.Y(), p1.Z(), p2.X(), p2.Y(), p2.Z());
  printf("\n");
}

int main()
{
  TopoDS_Shape s1 = BRepPrimAPI_MakeSphere(5.0).Shape();
  gp_Trsf      t;
  t.SetTranslation(gp_Vec(20, 0, 0));
  TopoDS_Shape s2 = BRepBuilderAPI_Transform(BRepPrimAPI_MakeSphere(5.0).Shape(), t, Standard_True).Shape();

  poly("unmeshed (no triangulation)", s1, s2);

  BRepMesh_IncrementalMesh m1(s1, 0.1, Standard_False, 0.5);
  m1.Perform();
  BRepMesh_IncrementalMesh m2(s2, 0.1, Standard_False, 0.5);
  m2.Perform();
  poly("polyDist (both meshed at 0.1)", s1, s2);
  return 0;
}
