// Epic #766, Tests/OCCTModelingTests/LocOpeSplitShapeTests.swift: kernel parity for splitEdge.
// OCCTLocOpeSplitShapeByVertex takes edge occtEdgeAt(shape, 0) (TopExp::MapShapes(EDGE)), maps
// the normalized parameter 0.5 onto BRep_Tool::Range, adds a vertex there with
// LocOpe_SplitShape::Add(vertex, param, edge), and returns DescendantShapes(edge) as a compound
// (nullptr when fewer than 2).
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Tool.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <Geom_Curve.hxx>
#include <LocOpe_SplitShape.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

int main()
{
  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape edges;
  TopExp::MapShapes(box, TopAbs_EDGE, edges);
  TopoDS_Edge       e = TopoDS::Edge(edges(1));
  double            f, l;
  Handle(Geom_Curve) c = BRep_Tool::Curve(e, f, l);
  double            u = f + 0.5 * (l - f);
  gp_Pnt            p = c->Value(u);
  LocOpe_SplitShape sp(box);
  sp.Add(BRepBuilderAPI_MakeVertex(p), u, e);
  const auto& d = sp.DescendantShapes(e);
  printf("splitEdge: range=[%g, %g] split point=(%g, %g, %g) descendants=%d\n", f, l, p.X(), p.Y(), p.Z(),
         (int)d.Size());
  TopTools_IndexedMapOfShape verts;
  int                        i = 0;
  for (auto it = d.begin(); it != d.end(); ++it, ++i)
  {
    TopExp::MapShapes(*it, TopAbs_VERTEX, verts);
    BRepAdaptor_Curve ac(TopoDS::Edge(*it));
    printf("  descendant %d: type=%d length=%g\n", i, (int)it->ShapeType(), GCPnts_AbscissaPoint::Length(ac));
  }
  printf("splitEdge: distinct vertices over descendants=%d\n", verts.Extent());
  return 0;
}
