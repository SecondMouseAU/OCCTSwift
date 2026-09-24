// Epic #766, Issue1566MergeNodesOverflowGuardTests.swift: kernel parity for all five tests.
// Same inputs as the Swift tests, straight to OCCT: a 10x10x10 BRepPrimAPI_MakeBox centred on the
// origin, BRepMesh_IncrementalMesh(box, 1.0), then Poly_MergeNodesTool(smoothAngle = pi/4,
// mergeTolerance = 0) fed each face's triangulation with its REVERSED flag, as OCCTPolyMergeNodes
// does. The buffer-size refusals are bridge behaviour with no kernel counterpart; what the kernel
// fixes is the node and triangle count those refusals are measured against.
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Tool.hxx>
#include <Poly_MergeNodesTool.hxx>
#include <Poly_Triangulation.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdio>

int main()
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  BRepMesh_IncrementalMesh(box, 1.0, Standard_False, 0.5);

  Handle(Poly_MergeNodesTool) tool = new Poly_MergeNodesTool(M_PI / 4, 0.0);
  for (TopExp_Explorer ex(box, TopAbs_FACE); ex.More(); ex.Next())
  {
    const TopoDS_Face&         f = TopoDS::Face(ex.Current());
    TopLoc_Location            loc;
    Handle(Poly_Triangulation) t = BRep_Tool::Triangulation(f, loc);
    if (!t.IsNull())
      tool->AddTriangulation(t, loc.IsIdentity() ? gp_Trsf() : loc.Transformation(),
                             f.Orientation() == TopAbs_REVERSED);
  }
  Handle(Poly_Triangulation) r = tool->Result();
  printf("merged box: nbNodes=%d nbTriangles=%d hasNormals=%d\n", r->NbNodes(), r->NbTriangles(),
         r->HasNormals());
  printf("vertexOverflowRefuses: nbNodes %d > maxVertices 1 -> %d\n", r->NbNodes(), r->NbNodes() > 1);
  printf("indexOverflowRefuses: nbTriangles*3 %d > maxIndices 1 -> %d\n", r->NbTriangles() * 3,
         r->NbTriangles() * 3 > 1);
  return 0;
}
