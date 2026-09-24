// Epic #766, Tests/OCCTAnalysisTests/BRepExtremaExtPCTests.swift: kernel parity probe.
//
// OCCTBRepExtremaExtPC does not take its distance from BRepExtrema_ExtPC (#580). It reads the
// edge's curve with BRep_Tool::Curve and answers with occtNearestPointOnCurveRange: the minimum
// over ShapeAnalysis_Curve::Project (when in range), every GeomAPI_ProjectPointOnCurve extremum in
// [first, last], and the two ends. solutionCount is BRepExtrema_ExtPC's NbExt. This probe
// reproduces both halves with the same OCCT calls, edges enumerated as occtEdgeAt does.
#include <BRep_Tool.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepExtrema_ExtPC.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>
#include <Geom_Curve.hxx>
#include <ShapeAnalysis_Curve.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <Precision.hxx>
#include <cstdio>

static void nearest(const char* name, int idx, const TopoDS_Edge& e, const gp_Pnt& p)
{
  double             first, last;
  Handle(Geom_Curve) c = BRep_Tool::Curve(e, first, last);
  double             best = RealLast(), bestPar = 0;
  gp_Pnt             bestPt;
  auto               consider = [&](double t) {
    if (t < first || t > last)
      return;
    gp_Pnt q = c->Value(t);
    double d = p.Distance(q);
    if (d < best)
    {
      best    = d;
      bestPar = t;
      bestPt  = q;
    }
  };
  {
    ShapeAnalysis_Curve sa;
    gp_Pnt              proj;
    double              par;
    sa.Project(c, p, Precision::Confusion(), proj, par);
    consider(par);
  }
  {
    GeomAPI_ProjectPointOnCurve pr(p, c, first, last);
    for (int i = 1; i <= pr.NbPoints(); ++i)
      consider(pr.Parameter(i));
  }
  consider(first);
  consider(last);
  int nb = -1;
  {
    BRepExtrema_ExtPC ext(BRepBuilderAPI_MakeVertex(p), e);
    if (ext.IsDone())
      nb = ext.NbExt();
  }
  printf("%s edge[%d] distance=%.17g parameter=%.17g point=(%.17g, %.17g, %.17g) ExtPC.NbExt=%d\n",
         name, idx, best, bestPar, bestPt.X(), bestPt.Y(), bestPt.Z(), nb);
}

int main()
{
  {
    // Shape.box(width: 10, height: 10, depth: 10), centred by OCCTShapeCreateBox.
    TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
    TopTools_IndexedMapOfShape map;
    TopExp::MapShapes(box, TopAbs_EDGE, map);
    printf("pointToEdge edge count=%d\n", map.Extent());
    for (int i = 1; i <= map.Extent(); ++i)
      nearest("pointToEdge", i - 1, TopoDS::Edge(map(i)), gp_Pnt(5, 5, 15));
  }
  {
    // Wire.polygon3D([(0,0,0), (10,0,0)], closed: false) -> OCCTWireCreateFastPolygon.
    BRepBuilderAPI_MakePolygon poly;
    poly.Add(gp_Pnt(0, 0, 0));
    poly.Add(gp_Pnt(10, 0, 0));
    TopoDS_Shape               w = poly.Wire();
    TopTools_IndexedMapOfShape map;
    TopExp::MapShapes(w, TopAbs_EDGE, map);
    printf("pointToWireEdge edge count=%d\n", map.Extent());
    nearest("pointToWireEdge", 0, TopoDS::Edge(map(1)), gp_Pnt(5, 3, 0));
  }
  return 0;
}
