// #766 kernel parity: ShapeBuildEdgeTests, ShapeBuildVertexTests. ShapeBuild_Edge and
// ShapeBuild_Vertex (OCCTShapeBuildEdge* / OCCTShapeBuildVertex*) on the box's first mapped edges,
// faces and vertices (Shape.subShapes(ofType:) is TopExp::MapShapes order).
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRep_Tool.hxx>
#include <ShapeAnalysis_Edge.hxx>
#include <ShapeBuild_Edge.hxx>
#include <ShapeBuild_Vertex.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static void edgeReport(const char* label, const TopoDS_Edge& e, const TopoDS_Face& f)
{
  ShapeAnalysis_Edge sae;
  double             a = 0, b = 0;
  bool               c3 = !BRep_Tool::Curve(e, a, b).IsNull();
  gp_Pnt             p1 = BRep_Tool::Pnt(sae.FirstVertex(e)), p2 = BRep_Tool::Pnt(sae.LastVertex(e));
  printf("%s: hasCurve3d=%d range=[%g, %g] hasPCurve(face0)=%d first=(%g, %g, %g) last=(%g, %g, %g)\n", label, (int)c3, a, b,
         (int)sae.HasPCurve(e, f), p1.X(), p1.Y(), p1.Z(), p2.X(), p2.Y(), p2.Z());
}

int main()
{
  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape edges, faces, verts;
  TopExp::MapShapes(box, TopAbs_EDGE, edges);
  TopExp::MapShapes(box, TopAbs_FACE, faces);
  TopExp::MapShapes(box, TopAbs_VERTEX, verts);
  TopoDS_Edge     e0 = TopoDS::Edge(edges(1)), e1 = TopoDS::Edge(edges(2));
  TopoDS_Face     f0 = TopoDS::Face(faces(1));
  TopoDS_Vertex   v0 = TopoDS::Vertex(verts(1)), v1 = TopoDS::Vertex(verts(2));
  ShapeBuild_Edge sbe;
  edgeReport("edge0", e0, f0);
  edgeReport("edge1", e1, f0);
  gp_Pnt a = BRep_Tool::Pnt(v0), b = BRep_Tool::Pnt(v1);
  printf("vertex0=(%g, %g, %g) tol=%g vertex1=(%g, %g, %g) tol=%g\n", a.X(), a.Y(), a.Z(), BRep_Tool::Tolerance(v0), b.X(),
         b.Y(), b.Z(), BRep_Tool::Tolerance(v1));
  TopoDS_Edge c1 = sbe.Copy(e0, true);
  edgeReport("Copy(edge0, share)", c1, f0);
  printf("  IsSame(edge0)=%d\n", (int)c1.IsSame(e0));
  TopoDS_Edge c2 = sbe.Copy(e0, false);
  edgeReport("Copy(edge0, no share)", c2, f0);
  edgeReport("CopyReplaceVertices(edge0, v0, v1)", sbe.CopyReplaceVertices(e0, v0, v1), f0);
  {
    TopoDS_Edge c = sbe.Copy(e0, true);
    sbe.SetRange3d(c, 0.0, 5.0);
    edgeReport("copy + SetRange3d(0,5)", c, f0);
    sbe.CopyRanges(c, e1);
    edgeReport("  then CopyRanges(from edge1)", c, f0);
  }
  {
    TopoDS_Edge c = sbe.Copy(e0, true);
    printf("BuildCurve3d(edge0 copy)=%d\n", (int)sbe.BuildCurve3d(c));
    sbe.RemoveCurve3d(c);
    edgeReport("copy + RemoveCurve3d", c, f0);
  }
  {
    TopoDS_Edge c = sbe.Copy(e0, true);
    sbe.RemovePCurve(c, f0);
    edgeReport("copy + RemovePCurve(face0)", c, f0);
    sbe.CopyPCurves(c, e0);
    edgeReport("  then CopyPCurves(from edge0)", c, f0);
  }
  {
    // A planar face projects a missing pcurve on demand, so the pcurve tests use a cylinder's
    // lateral face (first mapped face) and its first mapped edge instead.
    TopoDS_Shape               cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();
    TopTools_IndexedMapOfShape ce, cf;
    TopExp::MapShapes(cyl, TopAbs_EDGE, ce);
    TopExp::MapShapes(cyl, TopAbs_FACE, cf);
    TopoDS_Edge ec = TopoDS::Edge(ce(1));
    TopoDS_Face fc = TopoDS::Face(cf(1));
    printf("cylinder face0 surface=%s\n", BRep_Tool::Surface(fc)->DynamicType()->Name());
    edgeReport("cyl edge0", ec, fc);
    TopoDS_Edge c = sbe.Copy(ec, true);
    sbe.RemovePCurve(c, fc);
    edgeReport("cyl copy + RemovePCurve(face0)", c, fc);
    sbe.CopyPCurves(c, ec);
    edgeReport("  then CopyPCurves(from cyl edge0)", c, fc);
  }
  ShapeBuild_Vertex sbv;
  for (double k : {1.0001, 1.5})
  {
    TopoDS_Vertex r = sbv.CombineVertex(v0, v1, k);
    gp_Pnt        p = BRep_Tool::Pnt(r);
    printf("CombineVertex(v0, v1, %g) = (%g, %g, %g) tol=%.9f\n", k, p.X(), p.Y(), p.Z(), BRep_Tool::Tolerance(r));
  }
  {
    TopoDS_Vertex r = sbv.CombineVertex(gp_Pnt(0, 0, 0), gp_Pnt(0.01, 0, 0), 0.01, 0.01, 1.0001);
    gp_Pnt        p = BRep_Tool::Pnt(r);
    printf("CombineVertex(points 0.01 apart, tol 0.01 each) = (%g, %g, %g) tol=%.9f\n", p.X(), p.Y(), p.Z(),
           BRep_Tool::Tolerance(r));
  }
  return 0;
}
