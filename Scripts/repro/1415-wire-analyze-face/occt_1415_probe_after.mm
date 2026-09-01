#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRep_Tool.hxx>
#include <ShapeAnalysis_Wire.hxx>
#include <TopExp.hxx>
#include <TopoDS_Wire.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Vertex.hxx>
#include <gp_Pnt.hxx>
#include <gp_Circ.hxx>
#include <gp_Ax2.hxx>
#include <cstdio>

// Mirrors the PROPOSED fixed OCCTWireAnalyze logic.
static void probe(const char* label, const TopoDS_Wire& wire, double tolerance) {
  printf("=== %s ===\n", label);

  ShapeAnalysis_Wire analyzer;
  analyzer.Load(wire);
  analyzer.SetPrecision(tolerance);

  // Try to build a real supporting face (established bridge precedent:
  // BRepBuilderAPI_MakeFace(wire, true), as used e.g. in OCCTWireFillet2D). Only possible for
  // (approximately) planar wires; a non-planar 3D wire leaves the analyzer without a face, which
  // is a real, pre-existing OCCT limitation of ShapeAnalysis_Wire's self-intersection check
  // (fundamentally pcurve/2D-projection based).
  BRepBuilderAPI_MakeFace makeFace(wire, /*OnlyPlane=*/true);
  if (makeFace.IsDone()) {
    analyzer.SetFace(makeFace.Face());
  }

  // isClosed: computed directly from 3D endpoint coincidence, not from
  // ShapeAnalysis_Wire::CheckClosed(), whose DONE/FAIL semantics ("true" = "found a FIXABLE
  // problem") make its `false` return ambiguous between "genuinely closed" and "failed to
  // determine" -- so it can't be safely negated into isClosed regardless of the face fix.
  bool isClosed = wire.Closed();
  if (!isClosed) {
    TopoDS_Vertex vFirst, vLast;
    TopExp::Vertices(wire, vFirst, vLast);
    if (!vFirst.IsNull() && !vLast.IsNull()) {
      isClosed = vFirst.IsSame(vLast) ||
                 BRep_Tool::Pnt(vFirst).Distance(BRep_Tool::Pnt(vLast)) <= tolerance;
    }
  }

  bool selfInt = analyzer.CheckSelfIntersection();

  printf("isClosed            = %d\n", (int)isClosed);
  printf("hasSelfIntersection = %d\n", (int)selfInt);
  printf("\n");
}

int main() {
  {
    gp_Pnt p1(0, 0, 0), p2(10, 0, 0);
    TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(p1, p2).Edge();
    TopoDS_Wire wire = BRepBuilderAPI_MakeWire(edge).Wire();
    probe("open single-edge line (expect isClosed=0, hasSelfIntersection=0)", wire, 1e-7);
  }
  {
    gp_Pnt p1(0, 0, 0), p2(10, 0, 0), p3(10, 5, 0), p4(0, 5, 0);
    TopoDS_Edge e1 = BRepBuilderAPI_MakeEdge(p1, p2).Edge();
    TopoDS_Edge e2 = BRepBuilderAPI_MakeEdge(p2, p3).Edge();
    TopoDS_Edge e3 = BRepBuilderAPI_MakeEdge(p3, p4).Edge();
    TopoDS_Edge e4 = BRepBuilderAPI_MakeEdge(p4, p1).Edge();
    TopoDS_Wire wire = BRepBuilderAPI_MakeWire(e1, e2, e3, e4).Wire();
    probe("closed planar rectangle (expect isClosed=1, hasSelfIntersection=0)", wire, 1e-7);
  }
  {
    gp_Pnt p1(0, 0, 0), p2(10, 0, 0), p3(10, 5, 0);
    TopoDS_Edge e1 = BRepBuilderAPI_MakeEdge(p1, p2).Edge();
    TopoDS_Edge e2 = BRepBuilderAPI_MakeEdge(p2, p3).Edge();
    TopoDS_Wire wire = BRepBuilderAPI_MakeWire(e1, e2).Wire();
    probe("open planar polyline L shape (expect isClosed=0)", wire, 1e-7);
  }
  {
    gp_Pnt p1(0, 0, 0), p2(10, 10, 0), p3(10, 0, 0), p4(0, 10, 0);
    TopoDS_Edge e1 = BRepBuilderAPI_MakeEdge(p1, p2).Edge();
    TopoDS_Edge e2 = BRepBuilderAPI_MakeEdge(p2, p3).Edge();
    TopoDS_Edge e3 = BRepBuilderAPI_MakeEdge(p3, p4).Edge();
    TopoDS_Edge e4 = BRepBuilderAPI_MakeEdge(p4, p1).Edge();
    TopoDS_Wire wire = BRepBuilderAPI_MakeWire(e1, e2, e3, e4).Wire();
    probe("bowtie self-intersecting quad (expect isClosed=1, hasSelfIntersection=1)", wire, 1e-7);
  }
  {
    gp_Ax2 ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    gp_Circ circ(ax, 5.0);
    TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(circ).Edge();
    TopoDS_Wire wire = BRepBuilderAPI_MakeWire(edge).Wire();
    probe("circle wire (expect isClosed=1, hasSelfIntersection=0)", wire, 1e-7);
  }
  // Small numeric gap: endpoints close but not exactly coincident, different vertex objects,
  // built by hand rather than via MakeWire's shared-vertex path.
  {
    gp_Pnt p1(0, 0, 0), p2(10, 0, 0), p3(10, 5, 0), p4(0.0000001, 5, 0), p1b(0, 0.0000001, 0);
    TopoDS_Edge e1 = BRepBuilderAPI_MakeEdge(p1, p2).Edge();
    TopoDS_Edge e2 = BRepBuilderAPI_MakeEdge(p2, p3).Edge();
    TopoDS_Edge e3 = BRepBuilderAPI_MakeEdge(p3, p4).Edge();
    TopoDS_Edge e4 = BRepBuilderAPI_MakeEdge(p4, p1b).Edge();
    TopoDS_Wire wire = BRepBuilderAPI_MakeWire(e1, e2, e3, e4).Wire();
    printf("wire.Closed() flag for near-coincident-but-distinct-vertex case = %d\n", (int)wire.Closed());
    probe("near-coincident endpoints, tol=1e-4 (expect isClosed=1)", wire, 1e-4);
  }
  return 0;
}
