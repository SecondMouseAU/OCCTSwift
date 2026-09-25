// Epic #766 evidence correction for PR #2666 (Tests/OCCTModelingTests/BooleanCheckTests.swift),
// record pairParityWithBooleanValidWith only. The bridge side of that record was the pair
// [isValidForBoolean(with:), isBooleanValidWith] and the kernel side one flag; both sides now
// carry `valid`. OCCTShapeBooleanCheckPair is BRepAlgoAPI_Check(s1, s2,
// static_cast<BOPAlgo_Operation>(op), testSmallEdges, testSelfInterference).IsValid(); the Swift
// defaults are operation 5 (BOPAlgo_UNKNOWN) with both tests on, and isValidForBoolean(with:)
// forwards to isBooleanValidWith. Same shapes as the test: a centred 10x20x30 box and a sphere of
// radius 5 at the origin.
#include <BRepAlgoAPI_Check.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <cstdio>

int main()
{
  TopoDS_Shape box    = BRepPrimAPI_MakeBox(gp_Pnt(-5, -10, -15), 10, 20, 30).Shape();
  TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(5).Shape();
  bool         valid  = BRepAlgoAPI_Check(box, sphere, static_cast<BOPAlgo_Operation>(5), true, true).IsValid();
  printf("pairParityWithBooleanValidWith: valid=%s\n", valid ? "true" : "false");
  return 0;
}
