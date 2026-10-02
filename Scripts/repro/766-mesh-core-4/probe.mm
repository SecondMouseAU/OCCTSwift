// Epic #766, OCCTMeshTests.swift suites "Poly_Connect Mesh Adjacency Tests", "v0.115.0 -
// Triangulation Queries", "v0.160 MeshCache write API", "v0.158 MeshView two-tier mesh storage" and
// "Poly Copy & Mutators": kernel parity for their 18 tests.
// Same inputs as the Swift tests, straight to OCCT. The box is 10x10x10 centred on the origin; face
// index n is index n + 1 of TopExp::MapShapes (face 0 is x = -5, face 1 is x = +5). The BRepGraph
// calls are the ones OCCTBridge_BRepGraph.mm makes: Clear() then Shapes().Add(shape) with
// Parallel = false and CreateAutoProduct = false, the Mesh().Poly() counts, the
// Mesh().Effective() / Cache() presence queries, and Mesh().Editor() / Editor() for the writes.
#include <BRepGraph.hxx>
#include <BRepGraph_EditorView.hxx>
#include <BRepGraph_MeshView.hxx>
#include <Poly_Array1OfTriangle.hxx>
#include <BRepGraph_ShapesView.hxx>
#include <BRepGraph_NodeId.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Tool.hxx>
#include <Poly_Connect.hxx>
#include <Poly_Polygon2D.hxx>
#include <Poly_Polygon3D.hxx>
#include <Poly_PolygonOnTriangulation.hxx>
#include <Poly_Triangulation.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static TopoDS_Shape box()
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
}

static TopoDS_Face faceAt(const TopoDS_Shape& s, int zeroBased)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, TopAbs_FACE, m);
  return TopoDS::Face(m(zeroBased + 1));
}

static void graphCounts(BRepGraph& g, const char* label)
{
  printf("  %s: triangulations=%d polygons3D=%d polygons2D=%d polygonsOnTri=%d active: tri=%d p3d=%d p2d=%d pot=%d\n",
         label, g.Mesh().Poly().NbFaceTriangulations(), g.Mesh().Poly().NbEdgePolygons3D(),
         g.Mesh().Poly().NbCoEdgePolygons2D(), g.Mesh().Poly().NbCoEdgePolygonsOnTri(),
         g.Mesh().Poly().NbActiveTriangulations(), g.Mesh().Poly().NbActivePolygons3D(),
         g.Mesh().Poly().NbActivePolygons2D(), g.Mesh().Poly().NbActivePolygonsOnTri());
}

static bool build(BRepGraph& g, const TopoDS_Shape& s)
{
  g.Clear();
  BRepGraph::ShapesView::Options opts;
  opts.Parallel          = false;
  opts.CreateAutoProduct = false;
  return g.Shapes().Add(s, opts).IsOk();
}

int main()
{
  printf("Poly_Connect (box at 0.1, face index 1):\n");
  {
    TopoDS_Shape b = box();
    BRepMesh_IncrementalMesh(b, 0.1, Standard_False, 0.5);
    TopLoc_Location            loc;
    Handle(Poly_Triangulation) t = BRep_Tool::Triangulation(faceAt(b, 1), loc);
    Poly_Connect               c(t);
    int                        a1, a2, a3;
    c.Triangles(1, a1, a2, a3);
    printf("  triangles=%d nodes=%d adjacency(1)=(%d, %d, %d) Triangle(node 1)=%d", t->NbTriangles(), t->NbNodes(), a1,
           a2, a3, c.Triangle(1));
    int n = 0;
    for (c.Initialize(1); c.More(); c.Next())
      n++;
    printf(" fan(node 1)=%d\n", n);
  }

  printf("Triangulation queries (box at 1.0, face index 0):\n");
  {
    TopoDS_Shape b = box();
    BRepMesh_IncrementalMesh(b, 1.0, Standard_False, 0.5);
    TopLoc_Location            loc;
    Handle(Poly_Triangulation) t = BRep_Tool::Triangulation(faceAt(b, 0), loc);
    gp_Pnt                     p = t->Node(1).Transformed(loc.Transformation());
    int                        n1, n2, n3;
    t->Triangle(1).Get(n1, n2, n3);
    printf("  nodes=%d triangles=%d deflection=%.17g node(1)=(%g, %g, %g) triangle(1)=(%d, %d, %d) hasUV=%d",
           t->NbNodes(), t->NbTriangles(), t->Deflection(), p.X(), p.Y(), p.Z(), n1, n2, n3, t->HasUVNodes());
    if (t->HasUVNodes())
      printf(" uv(1)=(%.17g, %.17g)", t->UVNode(1).X(), t->UVNode(1).Y());
    printf("\n");
  }

  printf("Triangulation create from arrays:\n");
  {
    TColgp_Array1OfPnt nodes(1, 4);
    nodes(1) = gp_Pnt(0, 0, 0);
    nodes(2) = gp_Pnt(1, 0, 0);
    nodes(3) = gp_Pnt(0, 1, 0);
    nodes(4) = gp_Pnt(1, 1, 0);
    Poly_Array1OfTriangle tris(1, 2);
    tris(1)                         = Poly_Triangle(1, 2, 3);
    tris(2)                         = Poly_Triangle(2, 4, 3);
    Handle(Poly_Triangulation) t    = new Poly_Triangulation(nodes, tris);
    int                        a, b, c;
    t->Triangle(1).Get(a, b, c);
    t->Deflection(0.01);
    printf("  nodes=%d triangles=%d node(1)=(%g, %g, %g) triangle(1) 1-based=(%d, %d, %d) deflection=%.17g\n",
           t->NbNodes(), t->NbTriangles(), t->Node(1).X(), t->Node(1).Y(), t->Node(1).Z(), a, b, c, t->Deflection());

    BRepGraph g;
    build(g, box());
    g.Mesh().Editor().Faces().SetCachedTriangulation(BRepGraph_FaceId(0), t);
    printf("  graph face 0 after SetCachedTriangulation: Effective().Faces().Has=%d\n",
           g.Mesh().Effective().Faces().Has(BRepGraph_FaceId(0)));
  }
  {
    TColgp_Array1OfPnt p(1, 3);
    p(1)                     = gp_Pnt(0, 0, 0);
    p(2)                     = gp_Pnt(1, 0, 0);
    p(3)                     = gp_Pnt(2, 0, 0);
    Handle(Poly_Polygon3D) poly = new Poly_Polygon3D(p);
    BRepGraph              g;
    build(g, box());
    printf("  graph edge 0 before: Effective().Edges().Has=%d", g.Mesh().Effective().Edges().Has(BRepGraph_EdgeId(0)));
    g.Mesh().Editor().Edges().SetCachedPolygon3D(BRepGraph_EdgeId(0), poly);
    printf(", after SetCachedPolygon3D=%d\n", g.Mesh().Effective().Edges().Has(BRepGraph_EdgeId(0)));
    BRepGraph g2;
    build(g2, box());
    g2.Editor().Edges().SetPersistentPolygon3D(BRepGraph_EdgeId(0), poly);
    printf("  graph edge 0 after SetPersistentPolygon3D: Effective().Edges().Has=%d\n",
           g2.Mesh().Effective().Edges().Has(BRepGraph_EdgeId(0)));
  }

  printf("MeshView:\n");
  {
    BRepGraph g;
    build(g, box());
    graphCounts(g, "fresh graph, unmeshed box");
    printf("  face 0 Has=%d edge 0 Has=%d coedge 0 cache Has=%d\n", g.Mesh().Effective().Faces().Has(BRepGraph_FaceId(0)),
           g.Mesh().Effective().Edges().Has(BRepGraph_EdgeId(0)), g.Mesh().Cache().CoEdges().Has(BRepGraph_CoEdgeId(0)));
  }
  {
    TopoDS_Shape b = box();
    BRepMesh_IncrementalMesh(b, 0.5, Standard_False, 0.5);
    BRepGraph g;
    build(g, b);
    graphCounts(g, "graph of a box meshed at 0.5");
    printf("  face 0 Has=%d\n", g.Mesh().Effective().Faces().Has(BRepGraph_FaceId(0)));
  }

  printf("Poly copy / mutators:\n");
  {
    TColgp_Array1OfPnt2d p(1, 3);
    p(1)                        = gp_Pnt2d(0, 0);
    p(2)                        = gp_Pnt2d(1, 0);
    p(3)                        = gp_Pnt2d(1, 1);
    Handle(Poly_Polygon2D) poly = new Poly_Polygon2D(p);
    poly->Deflection(0.25);
    Handle(Poly_Polygon2D) cp = poly->Copy();
    printf("  Polygon2D copy: nbNodes=%d node(3)=(%g, %g) deflection=%.17g\n", cp->NbNodes(), cp->Nodes()(3).X(),
           cp->Nodes()(3).Y(), cp->Deflection());
  }
  {
    TColStd_Array1OfInteger n(1, 4);
    for (int i = 1; i <= 4; i++)
      n(i) = i;
    Handle(Poly_PolygonOnTriangulation) poly = new Poly_PolygonOnTriangulation(n);
    Handle(Poly_PolygonOnTriangulation) cp   = poly->Copy();
    printf("  PolygonOnTriangulation copy: nbNodes=%d nodes=(%d, %d, %d, %d)\n", cp->NbNodes(), cp->Node(1), cp->Node(2),
           cp->Node(3), cp->Node(4));
    NCollection_Array1<int>& arr = poly->ChangeNodeArray();
    for (int i = 0; i < 4; i++)
      arr.SetValue(arr.Lower() + i, 5 + i);
    printf("  after ChangeNodeArray <- 5...8: node(1)=%d node(4)=%d length=%d\n", poly->Node(1), poly->Node(4),
           arr.Length());
  }
  {
    TColStd_Array1OfInteger n(1, 3);
    TColStd_Array1OfReal    par(1, 3);
    for (int i = 1; i <= 3; i++)
    {
      n(i)   = i;
      par(i) = i - 1;
    }
    Handle(Poly_PolygonOnTriangulation) poly = new Poly_PolygonOnTriangulation(n, par);
    NCollection_Array1<double>&         arr  = poly->ChangeParameterArray();
    for (int i = 0; i < 3; i++)
      arr.SetValue(arr.Lower() + i, 10.0 * (i + 1));
    printf("  after ChangeParameterArray <- 10, 20, 30: parameter(2)=%.17g length=%d\n", poly->Parameter(2),
           arr.Length());
    TColStd_Array1OfInteger m(1, 3);
    for (int i = 1; i <= 3; i++)
      m(i) = i;
    Handle(Poly_PolygonOnTriangulation) noPar = new Poly_PolygonOnTriangulation(m);
    printf("  without parameters: HasParameters=%d\n", noPar->HasParameters());
  }
  return 0;
}
