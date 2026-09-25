// Epic #766, Mesh evidence correction pass: the two kernel measurements the committed Mesh probes
// did not print in the form the corrected records need.
//
// 1. The three "Mesh boolean ..." tests: BRepAlgoAPI_Fuse / Cut / Common on the ORIGINAL SOLIDS
//    (the same inputs as OCCTMeshTests.swift, built as BRepPrimAPI primitives, not the sewn shells
//    Mesh.toShape() makes), meshed by BRepMesh_IncrementalMesh at 0.5 / 0.5 as
//    OCCTShapeCreateMesh does, then the triangle count and the volume the result mesh encloses
//    (divergence theorem over the float vertices, in double, exactly as the Swift tests'
//    `enclosedVolume` computes it). 766-mesh-core-1's transcript holds the sewn-shell pipeline:
//    72 / 2000, 120 / 1000, 0 / 0.
// 2. "Create triangulation rep and bind it to a face": whether face 0 of a fresh, unmeshed box graph
//    has a mesh entry before and after Mesh().Editor().Faces().SetCachedTriangulation, on ONE graph
//    (766-mesh-core-4 printed the two states from two different graphs).
#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepGraph.hxx>
#include <BRepGraph_EditorView.hxx>
#include <BRepGraph_MeshView.hxx>
#include <BRepGraph_NodeId.hxx>
#include <BRepGraph_ShapesView.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Tool.hxx>
#include <Poly_Array1OfTriangle.hxx>
#include <Poly_Triangulation.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cstdio>
#include <utility>

static void meshStats(const TopoDS_Shape& s, const char* label)
{
  BRepMesh_IncrementalMesh(s, 0.5, Standard_False, 0.5);
  long   tris = 0;
  double vol  = 0;
  for (TopExp_Explorer ex(s, TopAbs_FACE); ex.More(); ex.Next())
  {
    const TopoDS_Face&         f = TopoDS::Face(ex.Current());
    TopLoc_Location            loc;
    Handle(Poly_Triangulation) t = BRep_Tool::Triangulation(f, loc);
    if (t.IsNull())
      continue;
    for (int i = 1; i <= t->NbTriangles(); i++)
    {
      int a, b, c;
      t->Triangle(i).Get(a, b, c);
      if (f.Orientation() == TopAbs_REVERSED)
        std::swap(b, c);
      // float vertices, as the bridge stores them
      float p[3][3];
      int   n[3] = {a, b, c};
      for (int k = 0; k < 3; k++)
      {
        gp_Pnt q = t->Node(n[k]).Transformed(loc);
        p[k][0]  = (float)q.X();
        p[k][1]  = (float)q.Y();
        p[k][2]  = (float)q.Z();
      }
      vol += ((double)p[0][0] * ((double)p[1][1] * p[2][2] - (double)p[1][2] * p[2][1])
              - (double)p[0][1] * ((double)p[1][0] * p[2][2] - (double)p[1][2] * p[2][0])
              + (double)p[0][2] * ((double)p[1][0] * p[2][1] - (double)p[1][1] * p[2][0]))
             / 6.0;
      tris++;
    }
  }
  printf("  %s: triangleCount=%ld volume=%.17g\n", label, tris, vol);
}

static TopoDS_Shape box()
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
}

int main()
{
  printf("solid Booleans meshed at 0.5 (the reference the three Mesh boolean tests are measured against):\n");
  {
    gp_Trsf tr;
    tr.SetTranslation(gp_Vec(5, 0, 0));
    TopoDS_Shape moved = BRepBuilderAPI_Transform(box(), tr, Standard_True).Shape();
    meshStats(BRepAlgoAPI_Fuse(box(), moved).Shape(), "union: box 10 and the same box moved +5 in x");
  }
  meshStats(BRepAlgoAPI_Cut(box(), BRepPrimAPI_MakeCylinder(3, 15).Shape()).Shape(), "subtraction: box 10 minus cylinder r3 h15");
  meshStats(BRepAlgoAPI_Common(box(), BRepPrimAPI_MakeSphere(7).Shape()).Shape(), "intersection: box 10 and sphere r7");

  printf("BRepGraph face 0 of a fresh unmeshed box, one graph:\n");
  {
    BRepGraph g;
    g.Clear();
    BRepGraph::ShapesView::Options opts;
    opts.Parallel          = false;
    opts.CreateAutoProduct = false;
    g.Shapes().Add(box(), opts);
    bool               before = g.Mesh().Effective().Faces().Has(BRepGraph_FaceId(0));
    TColgp_Array1OfPnt nodes(1, 4);
    nodes(1) = gp_Pnt(0, 0, 0);
    nodes(2) = gp_Pnt(1, 0, 0);
    nodes(3) = gp_Pnt(0, 1, 0);
    nodes(4) = gp_Pnt(1, 1, 0);
    Poly_Array1OfTriangle tris(1, 2);
    tris(1) = Poly_Triangle(1, 2, 3);
    tris(2) = Poly_Triangle(2, 4, 3);
    g.Mesh().Editor().Faces().SetCachedTriangulation(BRepGraph_FaceId(0), new Poly_Triangulation(nodes, tris));
    bool after = g.Mesh().Effective().Faces().Has(BRepGraph_FaceId(0));
    printf("  Effective().Faces().Has(0): before=%d after SetCachedTriangulation=%d\n", before, after);
  }
  return 0;
}
