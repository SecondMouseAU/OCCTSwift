// Reproducer for #1415: OCCTWireAnalyze never sets analyzer's face.
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <ShapeAnalysis_Wire.hxx>
#include <TopoDS_Wire.hxx>
#include <gp_Pnt.hxx>
#include <cstdio>

int main() {
  gp_Pnt p1(0, 0, 0);
  gp_Pnt p2(10, 0, 0);
  BRepBuilderAPI_MakeEdge edgeMaker(p1, p2);
  TopoDS_Edge edge = edgeMaker.Edge();
  BRepBuilderAPI_MakeWire wireMaker(edge);
  TopoDS_Wire wire = wireMaker.Wire();

  printf("wire.Closed() (TopoDS flag) = %d\n", (int)wire.Closed());

  // Exact reproduction of OCCTWireAnalyze's code path: NO SetFace call.
  TopoDS_Face face; // never assigned, matching the bridge
  ShapeAnalysis_Wire analyzer;
  analyzer.Load(wire);
  analyzer.SetPrecision(1e-7);

  printf("IsReady()                   = %d\n", (int)analyzer.IsReady());
  bool checkClosed = analyzer.CheckClosed(1e-7);
  printf("CheckClosed(tol)            = %d   (problem detected if 1... wait, semantics: true=problem)\n", (int)checkClosed);

  bool bridgeIsClosed = wire.Closed() || !checkClosed;
  printf("bridge-computed isClosed    = %d   (for a wire that is NOT closed)\n", (int)bridgeIsClosed);

  bool selfInt = analyzer.CheckSelfIntersection();
  printf("CheckSelfIntersection()     = %d   (bridge-reported hasSelfIntersection)\n", (int)selfInt);

  return 0;
}
