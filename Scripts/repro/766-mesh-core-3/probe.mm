// Epic #766, OCCTMeshTests.swift suites "BRepGProp MeshCinert Tests", "BRepGProp MeshProps Tests",
// "BRepMesh ShapeTool Tests", "Poly_Polygon3D", "Poly_PolygonOnTriangulation", "Poly_MergeNodesTool"
// and "Poly_CoherentTriangulation": kernel parity for their 21 tests.
// Same inputs as the Swift tests, straight to OCCT: a 10x10x10 box centred on the origin, meshed
// at 0.1 (1.0 where the test says so); "first face" / "first edge" are index 1 of
// TopExp::MapShapes, which is what Shape.faces() / edges() enumerate.
#include <BRepBndLib.hxx>
#include <BRepGProp_MeshCinert.hxx>
#include <BRepGProp_MeshProps.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepMesh_ShapeTool.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Tool.hxx>
#include <Bnd_Box.hxx>
#include <Poly_CoherentTriangulation.hxx>
#include <Poly_MergeNodesTool.hxx>
#include <Poly_Polygon3D.hxx>
#include <Poly_PolygonOnTriangulation.hxx>
#include <Poly_Triangulation.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdio>

static TopoDS_Shape meshedBox(double defl)
{
  TopoDS_Shape b = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  BRepMesh_IncrementalMesh(b, defl, Standard_False, 0.5);
  return b;
}

int main()
{
  TopoDS_Shape               box = meshedBox(0.1);
  TopTools_IndexedMapOfShape faces, edges;
  TopExp::MapShapes(box, TopAbs_FACE, faces);
  TopExp::MapShapes(box, TopAbs_EDGE, edges);
  const TopoDS_Face& f1 = TopoDS::Face(faces(1));
  const TopoDS_Edge& e1 = TopoDS::Edge(edges(1));

  printf("MeshCinert prepareAndCompute:\n");
  {
    Handle(NCollection_HArray1<gp_Pnt>) pts;
    BRepGProp_MeshCinert::PreparePolygon(e1, pts);
    printf("  first edge polygon points=%d", pts.IsNull() ? -1 : pts->Length());
    for (int i = pts->Lower(); i <= pts->Upper(); i++)
      printf(" (%g, %g, %g)", pts->Value(i).X(), pts->Value(i).Y(), pts->Value(i).Z());
    NCollection_Array1<gp_Pnt> arr(1, pts->Length());
    for (int i = 0; i < pts->Length(); i++)
      arr(i + 1) = pts->Value(pts->Lower() + i);
    BRepGProp_MeshCinert c;
    c.SetLocation(gp_Pnt(0, 0, 0));
    c.Perform(arr);
    printf("\n  mass=%.17g centre=(%g, %g, %g)\n", c.Mass(), c.CentreOfMass().X(), c.CentreOfMass().Y(),
           c.CentreOfMass().Z());
  }

  printf("MeshProps (first face):\n");
  {
    TopLoc_Location            loc;
    Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(f1, loc);
    for (auto kind : {BRepGProp_MeshProps::Sinert, BRepGProp_MeshProps::Vinert})
    {
      BRepGProp_MeshProps p(kind);
      p.SetLocation(gp_Pnt(0, 0, 0));
      p.Perform(tri, loc, f1.Orientation());
      printf("  %s: mass=%.17g centre=(%g, %g, %g) faceOrientation=%d\n",
             kind == BRepGProp_MeshProps::Sinert ? "surface" : "volume", p.Mass(), p.CentreOfMass().X(),
             p.CentreOfMass().Y(), p.CentreOfMass().Z(), f1.Orientation());
    }
  }

  printf("ShapeTool:\n");
  {
    printf("  MaxFaceTolerance(first face)=%.17g\n", BRepMesh_ShapeTool::MaxFaceTolerance(f1));
    Bnd_Box bb;
    BRepBndLib::Add(BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape(), bb);
    double maxDim = 0;
    BRepMesh_ShapeTool::BoxMaxDimension(bb, maxDim);
    printf("  BoxMaxDimension=%.17g\n", maxDim);
    gp_Pnt2d uv1, uv2;
    bool     ok = BRepMesh_ShapeTool::UVPoints(e1, f1, uv1, uv2);
    printf("  UVPoints(first edge, first face)=%d (%.17g, %.17g) (%.17g, %.17g)\n", ok, uv1.X(), uv1.Y(),
           uv2.X(), uv2.Y());
  }

  printf("Poly_Polygon3D:\n");
  {
    TColgp_Array1OfPnt p(1, 3);
    p(1) = gp_Pnt(0, 0, 0);
    p(2) = gp_Pnt(10, 0, 0);
    p(3) = gp_Pnt(10, 10, 0);
    Handle(Poly_Polygon3D) a = new Poly_Polygon3D(p);
    printf("  without params: nbNodes=%d hasParameters=%d\n", a->NbNodes(), a->HasParameters());
    TColgp_Array1OfPnt q(1, 3);
    q(1) = gp_Pnt(0, 0, 0);
    q(2) = gp_Pnt(10, 0, 0);
    q(3) = gp_Pnt(20, 0, 0);
    TColStd_Array1OfReal par(1, 3);
    par(1)                   = 0;
    par(2)                   = 10;
    par(3)                   = 20;
    Handle(Poly_Polygon3D) b = new Poly_Polygon3D(q, par);
    printf("  with params: nbNodes=%d hasParameters=%d parameter(2)=%.17g\n", b->NbNodes(), b->HasParameters(),
           b->Parameters()(2));
    TColgp_Array1OfPnt r(1, 2);
    r(1)                     = gp_Pnt(0, 0, 0);
    r(2)                     = gp_Pnt(10, 0, 0);
    Handle(Poly_Polygon3D) c = new Poly_Polygon3D(r);
    printf("  deflection default=%.17g", c->Deflection());
    c->Deflection(1.0);
    printf(" after Deflection(1.0)=%.17g\n", c->Deflection());
  }

  printf("Poly_PolygonOnTriangulation:\n");
  {
    TColStd_Array1OfInteger n(1, 4);
    for (int i = 1; i <= 4; i++)
      n(i) = i;
    Handle(Poly_PolygonOnTriangulation) a = new Poly_PolygonOnTriangulation(n);
    printf("  without params: nbNodes=%d node(1)=%d node(4)=%d hasParameters=%d\n", a->NbNodes(), a->Node(1),
           a->Node(4), a->HasParameters());
    TColStd_Array1OfInteger m(1, 3);
    TColStd_Array1OfReal    par(1, 3);
    for (int i = 1; i <= 3; i++)
    {
      m(i)   = i;
      par(i) = i - 1;
    }
    Handle(Poly_PolygonOnTriangulation) b = new Poly_PolygonOnTriangulation(m, par);
    printf("  with params: nbNodes=%d hasParameters=%d parameter(2)=%.17g\n", b->NbNodes(), b->HasParameters(),
           b->Parameter(2));
    TColStd_Array1OfInteger k(1, 2);
    k(1)                                  = 1;
    k(2)                                  = 2;
    Handle(Poly_PolygonOnTriangulation) c = new Poly_PolygonOnTriangulation(k);
    c->Deflection(0.1);
    printf("  after Deflection(0.1)=%.17g\n", c->Deflection());
  }

  printf("Poly_MergeNodesTool (box at 1.0, smoothAngle pi/4):\n");
  {
    TopoDS_Shape                b    = meshedBox(1.0);
    Handle(Poly_MergeNodesTool) tool = new Poly_MergeNodesTool(M_PI / 4, 0.0);
    for (TopExp_Explorer ex(b, TopAbs_FACE); ex.More(); ex.Next())
    {
      const TopoDS_Face&         f = TopoDS::Face(ex.Current());
      TopLoc_Location            loc;
      Handle(Poly_Triangulation) t = BRep_Tool::Triangulation(f, loc);
      tool->AddTriangulation(t, loc.IsIdentity() ? gp_Trsf() : loc.Transformation(),
                             f.Orientation() == TopAbs_REVERSED);
    }
    printf("  nbNodes=%d nbTriangles=%d\n", tool->Result()->NbNodes(), tool->Result()->NbTriangles());
  }

  printf("Poly_CoherentTriangulation:\n");
  {
    Handle(Poly_CoherentTriangulation) ct = new Poly_CoherentTriangulation();
    int n0 = ct->SetNode(gp_XYZ(0, 0, 0)), n1 = ct->SetNode(gp_XYZ(1, 0, 0)), n2 = ct->SetNode(gp_XYZ(0, 1, 0));
    printf("  SetNode indices: %d %d %d\n", n0, n1, n2);
    ct->SetNode(gp_XYZ(1, 1, 0));
    const Poly_CoherentTriangle* t0 = ct->AddTriangle(0, 1, 2);
    ct->AddTriangle(1, 3, 2);
    printf("  two triangles: NTriangles=%d\n", ct->NTriangles());
    int links = ct->ComputeLinks();
    printf("  ComputeLinks=%d NLinks=%d\n", links, ct->NLinks());
    ct->RemoveTriangle(const_cast<Poly_CoherentTriangle&>(*t0));
    printf("  after RemoveTriangle(first): NTriangles=%d\n", ct->NTriangles());
  }
  {
    Handle(Poly_CoherentTriangulation) ct = new Poly_CoherentTriangulation();
    printf("  deflection default=%.17g", ct->Deflection());
    ct->SetDeflection(0.5);
    printf(" after SetDeflection(0.5)=%.17g\n", ct->Deflection());
  }
  {
    Handle(Poly_CoherentTriangulation) ct = new Poly_CoherentTriangulation();
    ct->SetNode(gp_XYZ(1.5, 2.5, 3.5));
    ct->SetNode(gp_XYZ(4, 5, 6));
    ct->SetNode(gp_XYZ(7, 8, 9));
    ct->AddTriangle(0, 1, 2);
    Handle(Poly_Triangulation) r = ct->GetTriangulation();
    printf("  GetTriangulation: nbNodes=%d nbTriangles=%d node(1)=(%g, %g, %g) node(2)=(%g, %g, %g)\n",
           r->NbNodes(), r->NbTriangles(), r->Node(1).X(), r->Node(1).Y(), r->Node(1).Z(), r->Node(2).X(),
           r->Node(2).Y(), r->Node(2).Z());
  }
  {
    TopoDS_Shape b = meshedBox(1.0);
    // CreateFromMesh re-meshes at its default 0.1 (incremental: no-op on the 1.0 box) and takes
    // the first face's triangulation.
    BRepMesh_IncrementalMesh(b, 0.1);
    TopLoc_Location            loc;
    Handle(Poly_Triangulation) t = BRep_Tool::Triangulation(TopoDS::Face(TopExp_Explorer(b, TopAbs_FACE).Current()), loc);
    Handle(Poly_CoherentTriangulation) ct = new Poly_CoherentTriangulation(t);
    printf("  createFromMesh(box): first face NTriangles=%d\n", ct->NTriangles());
  }
  return 0;
}
