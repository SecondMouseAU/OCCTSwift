// Epic #766, Tests/OCCTModelingTests/LocOpeSpliterTests.swift: kernel parity for
// splitByWireOnFace. OCCTLocOpeSplitByWireOnFace takes the 0-based face occtFaceAt(shape, i)
// (TopExp::MapShapes(FACE)), binds the wire with LocOpe_WiresOnShape::Bind(w, face) + BindAll(),
// and runs LocOpe_Spliter::Perform. The test tries indices 1...6 on the centred 10 mm box with the
// line (-6,0,5)-(6,0,5); index 6 names no face (nullptr).
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <LocOpe_Spliter.hxx>
#include <LocOpe_WiresOnShape.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

int main()
{
  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape faces;
  TopExp::MapShapes(box, TopAbs_FACE, faces);
  TopoDS_Wire w = BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(gp_Pnt(-6, 0, 5), gp_Pnt(6, 0, 5)));
  for (int i = 1; i <= 6; i++)
  {
    if (i >= faces.Extent())
    {
      printf("faceIndex %d: no such face (bridge returns nullptr)\n", i);
      continue;
    }
    try
    {
      Handle(LocOpe_WiresOnShape) wos = new LocOpe_WiresOnShape(box);
      wos->Bind(w, TopoDS::Face(faces(i + 1)));
      wos->BindAll();
      LocOpe_Spliter sp(box);
      sp.Perform(wos);
      if (!sp.IsDone())
      {
        printf("faceIndex %d: not done\n", i);
        continue;
      }
      TopTools_IndexedMapOfShape rf;
      TopExp::MapShapes(sp.ResultingShape(), TopAbs_FACE, rf);
      printf("faceIndex %d: done faces=%d valid=%d\n", i, rf.Extent(),
             BRepCheck_Analyzer(sp.ResultingShape()).IsValid());
    }
    catch (Standard_Failure& e)
    {
      printf("faceIndex %d: threw %s\n", i, e.what());
    }
  }
  return 0;
}
