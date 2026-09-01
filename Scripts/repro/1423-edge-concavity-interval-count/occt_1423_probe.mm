// Probe for #1423: try to force BRepOffset_Analyse::Type(edge) to return 2+ intervals via the
// exact construction path the bridge uses (BRepOffset_Analyse analyser(shape, angle); no
// SetFaceOffsetMap call).
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepOffset_Analyse.hxx>
#include <BRepOffset_Interval.hxx>
#include <TopExp_Explorer.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <gp_Pnt.hxx>
#include <gp_Circ.hxx>
#include <gp_Ax2.hxx>
#include <cstdio>

static void probe(const char* label, const TopoDS_Shape& shape, double angle) {
  printf("=== %s ===\n", label);
  BRepOffset_Analyse analyser(shape, angle);
  if (!analyser.IsDone()) {
    printf("  analyser.IsDone() == false\n\n");
    return;
  }
  TopTools_IndexedMapOfShape edgeMap;
  TopExp::MapShapes(shape, TopAbs_EDGE, edgeMap);
  int maxIntervals = 0;
  int totalEdges = edgeMap.Extent();
  int mixedCount = 0;
  for (int i = 1; i <= totalEdges; i++) {
    const TopoDS_Edge& e = TopoDS::Edge(edgeMap(i));
    const auto& intervals = analyser.Type(e);
    int n = intervals.Extent();
    if (n > maxIntervals) maxIntervals = n;
    if (n >= 2) {
      printf("  edge %d has %d intervals:", i, n);
      for (auto it = intervals.begin(); it != intervals.end(); ++it) {
        printf(" [%.4f,%.4f]type=%d", it->First(), it->Last(), (int)it->Type());
      }
      printf("\n");
    }
    for (auto it = intervals.begin(); it != intervals.end(); ++it) {
      if (it->Type() == ChFiDS_Mixed) mixedCount++;
    }
  }
  printf("  totalEdges=%d maxIntervalsOnAnyEdge=%d mixedIntervals=%d\n\n", totalEdges, maxIntervals, mixedCount);
}

int main() {
  // 1. Box (simple planar, sharp edges)
  {
    TopoDS_Shape box = BRepPrimAPI_MakeBox(10, 10, 10).Shape();
    probe("box", box, 0.01);
  }
  // 2. Box + sphere fuse (mix of planar/spherical, tangent + sharp edges)
  {
    TopoDS_Shape box = BRepPrimAPI_MakeBox(10, 10, 10).Shape();
    TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(gp_Pnt(5, 5, 10), 4).Shape();
    TopoDS_Shape fused = BRepAlgoAPI_Fuse(box, sphere).Shape();
    probe("box+sphere fuse", fused, 0.01);
  }
  // 3. Filleted box (fillet introduces cylindrical blend faces meeting planar faces at tangent
  //    edges -- likely candidate for curvature transitions)
  {
    TopoDS_Shape box = BRepPrimAPI_MakeBox(10, 10, 10).Shape();
    BRepFilletAPI_MakeFillet mkFillet(box);
    for (TopExp_Explorer ex(box, TopAbs_EDGE); ex.More(); ex.Next()) {
      mkFillet.Add(2.0, TopoDS::Edge(ex.Current()));
    }
    TopoDS_Shape filleted = mkFillet.Shape();
    probe("fully filleted box", filleted, 0.01);
  }
  // 4. ThruSections loft between a triangle and a square (non-matching profiles -> the lofted
  //    side faces are BSpline surfaces with curvature transitions along shared edges)
  {
    BRepBuilderAPI_MakePolygon poly1;
    poly1.Add(gp_Pnt(0, 0, 0));
    poly1.Add(gp_Pnt(10, 0, 0));
    poly1.Add(gp_Pnt(5, 8, 0));
    poly1.Close();
    BRepBuilderAPI_MakePolygon poly2;
    poly2.Add(gp_Pnt(-2, -2, 10));
    poly2.Add(gp_Pnt(12, -2, 10));
    poly2.Add(gp_Pnt(12, 12, 10));
    poly2.Add(gp_Pnt(-2, 12, 10));
    poly2.Close();
    BRepOffsetAPI_ThruSections loft(true, false);
    loft.AddWire(poly1.Wire());
    loft.AddWire(poly2.Wire());
    loft.Build();
    if (loft.IsDone()) {
      probe("thrusections triangle-to-square loft", loft.Shape(), 0.01);
    } else {
      printf("=== thrusections triangle-to-square loft ===\n  loft.IsDone() == false\n\n");
    }
  }
  // 5. Cylinder + box fuse with fillets on the tangent seam (curvature transition candidate)
  {
    TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(3, 10).Shape();
    TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, 3), 10, 10, 4).Shape();
    TopoDS_Shape fused = BRepAlgoAPI_Fuse(cyl, box).Shape();
    probe("cylinder+box fuse", fused, 0.01);
  }
  return 0;
}
