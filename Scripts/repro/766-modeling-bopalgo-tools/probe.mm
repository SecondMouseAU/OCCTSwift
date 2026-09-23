// Epic #766, Tests/OCCTModelingTests/BOPAlgoToolsTests.swift: kernel parity for both tests.
// OCCTBOPAlgoEdgesToWires: BOPAlgo_Tools::EdgesToWires(compound, result, false, 1e-7), status 0 = ok.
// OCCTBOPAlgoWiresToFaces: BOPAlgo_Tools::WiresToFaces(wires, result, 1e-7).
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
  printf("edgesToWires: status=%d wires=%d\n", status, w.Extent());
  TopoDS_Shape faces;
  bool         ok = BOPAlgo_Tools::WiresToFaces(wires, faces, 1e-7);
  TopTools_IndexedMapOfShape f;
  TopExp::MapShapes(faces, TopAbs_FACE, f);
  GProp_GProps g;
  BRepGProp::SurfaceProperties(faces, g);
  printf("wiresToFaces: ok=%d faces=%d area=%.10g\n", ok, f.Extent(), g.Mass());
  return 0;
}
