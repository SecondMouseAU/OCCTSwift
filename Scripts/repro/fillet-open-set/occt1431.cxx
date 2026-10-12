// Source: the program posted in Open-Cascade-SAS/OCCT#1431 by its reporter, quoted unchanged for replay (not ours).
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepFilletAPI_MakeFillet2d.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Pnt.hxx>
#include <vector>

int main() {
  BRepBuilderAPI_MakePolygon poly;
  poly.Add(gp_Pnt(0, 0, 0));
  poly.Add(gp_Pnt(10, 0, 0));
  poly.Add(gp_Pnt(10, 10, 0));
  poly.Add(gp_Pnt(0, 10, 0));
  poly.Close();
  TopoDS_Face face = BRepBuilderAPI_MakeFace(poly.Wire()).Face();

  std::vector<TopoDS_Edge> edges;
  for (TopExp_Explorer ex(face, TopAbs_EDGE); ex.More(); ex.Next())
    edges.push_back(TopoDS::Edge(ex.Current()));

  BRepFilletAPI_MakeFillet2d chamfer(face);
  chamfer.AddChamfer(edges[0], edges[1], 1.0, 2.0);   // first call: succeeds, Status() == ChFi2d_IsDone
  chamfer.AddChamfer(edges[0], edges[1], 1.0, 2.0);   // second call, SAME pair: *** SIGSEGV ***
  return 0;
}
