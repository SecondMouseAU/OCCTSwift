// Epic #766, Tests/OCCTModelingTests/BooleanCheckTests.swift: kernel parity for all 11 tests.
// OCCTShapeBooleanCheckSingle is BRepAlgoAPI_Check(s, testSmallEdges, testSelfInterference)
// .IsValid(); OCCTShapeBooleanCheckPair is BRepAlgoAPI_Check(s1, s2,
// static_cast<BOPAlgo_Operation>(op), testSmallEdges, testSelfInterference).IsValid().
#include <BRepAlgoAPI_Check.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <cstdio>

static TopoDS_Shape box(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

static int single(const TopoDS_Shape& s, bool small = true, bool self = true)
{
  return BRepAlgoAPI_Check(s, small, self).IsValid();
}

static int pair(const TopoDS_Shape& a, const TopoDS_Shape& b, int op, bool small = true, bool self = true)
{
  return BRepAlgoAPI_Check(a, b, static_cast<BOPAlgo_Operation>(op), small, self).IsValid();
}

int main()
{
  TopoDS_Shape b10    = box(10, 10, 10);
  TopoDS_Shape b123   = box(10, 20, 30);
  TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(5).Shape();
  TopoDS_Shape cyl    = BRepPrimAPI_MakeCylinder(5, 10).Shape();
  printf("validBoxCheck: %d\n", single(b10));
  printf("twoBoxesValid (box10 + sphere5, op 5): %d\n", pair(b10, sphere, 5));
  printf("cylinderValid: %d\n", single(cyl));
  printf("singleShapeValid: %d\n", single(b123));
  printf("sphereValid: %d\n", single(sphere));
  printf("pairShapesValidForFuse (op 2): %d\n", pair(b123, sphere, 2));
  printf("pairShapesValidForCut (op 3): %d\n", pair(b123, sphere, 3));
  TopTools_IndexedMapOfShape faces;
  TopExp::MapShapes(b123, TopAbs_FACE, faces);
  printf("solidVsFace: CUT(op 2)=%d CUT21(op 3)=%d\n", pair(b123, faces(1), 2, false, false),
         pair(b123, faces(1), 3, false, false));
  printf("singleShapeNoSelfInterference: %d\n", single(b123, false, true));
  printf("singleShapeParity: box %d/%d sphere %d/%d\n", single(b123), single(b123), single(sphere),
         single(sphere));
  printf("pairParity: %d/%d\n", pair(b123, sphere, 5), pair(b123, sphere, 5));
  return 0;
}
