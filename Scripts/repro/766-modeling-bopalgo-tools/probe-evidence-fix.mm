// Epic #766 evidence fix, Tests/OCCTModelingTests/BOPAlgoToolsTests.swift.
// probe.mm printed the area at %.10g. This probe repeats the same bridge calls (OCCTBOPAlgoEdgesToWires:
// BOPAlgo_Tools::EdgesToWires(compound, result, false, 1e-7), a result only when the status is 0;
// OCCTBOPAlgoWiresToFaces: BOPAlgo_Tools::WiresToFaces(wires, result, 1e-7), a result only when it returns true)
// on the four edges of the 10 x 10 rectangle at %.17g. The area is BRepGProp::SurfaceProperties, as Shape.surfaceArea.
#include <BOPAlgo_Tools.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepGProp.hxx>
#include <BRep_Builder.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Edge.hxx>
#include <cstdio>

int main()
{
  gp_Pnt          p[4] = {gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0), gp_Pnt(0, 10, 0)};
  TopoDS_Compound c;
  BRep_Builder    b;
  b.MakeCompound(c);
  for (int i = 0; i < 4; i++)
    b.Add(c, BRepBuilderAPI_MakeEdge(p[i], p[(i + 1) % 4]).Edge());
  TopoDS_Shape wires;
  int          status = BOPAlgo_Tools::EdgesToWires(c, wires, false, 1e-7);
  TopTools_IndexedMapOfShape w;
  TopExp::MapShapes(wires, TopAbs_WIRE, w);
  printf("edgesToWires: produced=%d status=%d wires=%d\n", status == 0, status, w.Extent());
  TopoDS_Shape faces;
  bool         ok = BOPAlgo_Tools::WiresToFaces(wires, faces, 1e-7);
  TopTools_IndexedMapOfShape f;
  TopExp::MapShapes(faces, TopAbs_FACE, f);
  GProp_GProps g;
  BRepGProp::SurfaceProperties(faces, g);
  printf("wiresToFaces: produced=%d faces=%d area=%.17g\n", ok, f.Extent(), g.Mass());
  return 0;
}
