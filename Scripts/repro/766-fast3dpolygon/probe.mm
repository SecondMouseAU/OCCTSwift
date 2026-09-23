// #766 kernel parity for Tests/OCCTAnalysisTests/Fast3DPolygonTests.swift.
// Same OCCT calls as OCCTWireCreateFastPolygon (BRepBuilderAPI_MakePolygon, Add per point, Close
// when closed) and OCCTWireExplorerEdgeCount (BRepTools_WireExplorer).
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepTools_WireExplorer.hxx>
#include <Standard_Failure.hxx>
#include <TopoDS_Wire.hxx>
#include <cstdio>
#include <vector>

static void run(const char* name, const std::vector<gp_Pnt>& pts, bool closed)
{
  try
  {
    BRepBuilderAPI_MakePolygon poly;
    for (const gp_Pnt& p : pts)
      poly.Add(p);
    if (closed)
      poly.Close();
    printf("%s: IsDone=%d", name, poly.IsDone() ? 1 : 0);
    if (!poly.IsDone())
    {
      printf("\n");
      return;
    }
    int n = 0;
    for (BRepTools_WireExplorer exp(poly.Wire()); exp.More(); exp.Next())
      ++n;
    printf(" WireExplorer edges=%d\n", n);
  }
  catch (const Standard_Failure& f)
  {
    printf("%s: threw %s\n", name, f.what());
  }
}

int main()
{
  run("closedSquare", {gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0), gp_Pnt(0, 10, 0)}, true);
  run("openTriangle", {gp_Pnt(0, 0, 0), gp_Pnt(5, 0, 3), gp_Pnt(10, 5, 6)}, false);
  run("nonPlanarPolygon", {gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 5), gp_Pnt(0, 10, 10)},
      true);
  run("twoPointPolygon", {gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)}, false);
  // singlePointReturnsNil: Wire.polygon3D refuses fewer than 2 points before the bridge, and the
  // bridge refuses them again. What the kernel itself does with one point, closed (the Swift
  // default):
  run("singlePointReturnsNil (kernel, closed)", {gp_Pnt(0, 0, 0)}, true);
  return 0;
}
