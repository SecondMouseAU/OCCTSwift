// Epic #766, Tests/OCCTModelingTests/LocOpeFindEdgesTests.swift: kernel parity for
// findEdgesInFace. OCCTLocOpeFindEdgesInFace runs LocOpe_FindEdgesInFace::Set(shape, face) on
// face(at: 0) (the first face of TopExp::MapShapes(FACE)) and walks Init/More/Next.
#include <BRepPrimAPI_MakeBox.hxx>
#include <LocOpe_FindEdgesInFace.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

int main()
{
  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape faces, edges;
  TopExp::MapShapes(box, TopAbs_FACE, faces);
  TopExp::MapShapes(box, TopAbs_EDGE, edges);
  LocOpe_FindEdgesInFace f;
  f.Set(box, TopoDS::Face(faces(1)));
  int n = 0;
  printf("findEdgesInFace: edge indices =");
  for (f.Init(); f.More(); f.Next(), n++)
    printf(" %d", edges.FindIndex(f.Edge()) - 1);
  printf("\nfindEdgesInFace: count=%d\n", n);
  return 0;
}
