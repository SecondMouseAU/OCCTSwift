// Epic #766, BRepGPropDomainTests.swift: kernel parity for faceEdgeCount.
// BRepGProp_Domain(face), Init/More/Next, what OCCTShapeFaceDomainEdgeCount counts, over every face
// of Shape.box(width: 10, height: 10, depth: 10), centred on the origin (OCCTShapeCreateBox).
// Face index 0 is the first face TopExp_Explorer visits, the order occtFaceAt indexes by.
#include <BRepGProp_Domain.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cstdio>

int main()
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  int          i   = 0;
  for (TopExp_Explorer ex(box, TopAbs_FACE); ex.More(); ex.Next(), ++i)
  {
    BRepGProp_Domain d(TopoDS::Face(ex.Current()));
    int              n = 0;
    for (d.Init(); d.More(); d.Next())
      ++n;
    printf("faceEdgeCount: face %d domain edges=%d\n", i, n);
  }
  return 0;
}
