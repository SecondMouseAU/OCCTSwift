// #3110 probe: what does the OCCT builder do with out-of-range triangle indices?
// Mirrors OCCTShapeFromMesh (OCCTBridge_Modeling_WireEdgeFaceBuilders.mm) without any index guard.
// One case per process: ./probe <a> <b> <c>   (triangle indices; nodes = 3, 1-based valid range 1..3)
#include <BRepBuilderAPI_MakeShapeOnMesh.hxx>
#include <Poly_Triangulation.hxx>
#include <Poly_Triangle.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <Poly_Array1OfTriangle.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <TopExp_Explorer.hxx>
#include <cstdio>
#include <cstdlib>
int main(int argc, char** argv)
{
  int a = atoi(argv[1]), b = atoi(argv[2]), c = atoi(argv[3]);
  try
  {
    TColgp_Array1OfPnt nodes(1, 3);
    nodes.SetValue(1, gp_Pnt(0, 0, 0));
    nodes.SetValue(2, gp_Pnt(1, 0, 0));
    nodes.SetValue(3, gp_Pnt(0, 1, 0));
    Poly_Array1OfTriangle tris(1, 1);
    tris.SetValue(1, Poly_Triangle(a, b, c));
    Handle(Poly_Triangulation) mesh = new Poly_Triangulation(nodes, tris);
    printf("constructed\n"); fflush(stdout);
    BRepBuilderAPI_MakeShapeOnMesh maker(mesh);
    maker.Build();
    printf("built IsDone=%d\n", (int)maker.IsDone()); fflush(stdout);
    if (maker.IsDone())
    {
      int n = 0;
      for (TopExp_Explorer e(maker.Shape(), TopAbs_VERTEX); e.More(); e.Next()) n++;
      printf("vertices=%d\n", n); fflush(stdout);
      printf("valid=%d\n", (int)BRepCheck_Analyzer(maker.Shape()).IsValid());
    }
  }
  catch (Standard_Failure& f) { printf("exception: %s\n", f.GetMessageString()); }
  return 0;
}
