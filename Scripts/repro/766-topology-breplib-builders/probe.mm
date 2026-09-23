// Epic #766, BRepLibMakeEdgeTests.swift, BRepLibMakeFaceTests.swift, BRepLibMakeShellTests.swift,
// BRepLibPointCloudShapeTests.swift and BRepLibToolTriangulatedShapeTests.swift: kernel parity
// for all nine tests. Same inputs as the Swift tests, straight to OCCT: BRepLib_MakeEdge /
// MakeFace / MakeShell as the OCCTBRepLibMake* functions call them, measured with BRepGProp
// (edge length, face area), and BRepLib_PointCloudShape / BRepLib_ToolTriangulatedShape after
// the BRepMesh_IncrementalMesh(d, false, 0.5) Shape.mesh(linearDeflection: d) runs.
#include <BRepGProp.hxx>
#include <BRepLib_MakeEdge.hxx>
#include <BRepLib_MakeFace.hxx>
#include <BRepLib_MakeShell.hxx>
#include <BRepLib_PointCloudShape.hxx>
#include <BRepLib_ToolTriangulatedShape.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Tool.hxx>
#include <GProp_GProps.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Plane.hxx>
#include <Poly_Triangulation.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Vertex.hxx>
#include <cstdio>
#include <gp_Circ.hxx>
#include <gp_Lin.hxx>
#include <gp_Pln.hxx>

class Collector : public BRepLib_PointCloudShape
{
public:
  Collector(const TopoDS_Shape& s)
      : BRepLib_PointCloudShape(s)
  {
  }

  int n = 0;

protected:
  void addPoint(const gp_Pnt&, const gp_Vec&, const gp_Pnt2d&, const TopoDS_Shape&) override
  {
    n++;
  }
};

static double length(const TopoDS_Shape& e)
{
  GProp_GProps g;
  BRepGProp::LinearProperties(e, g);
  return g.Mass();
}

static double area(const TopoDS_Shape& f)
{
  GProp_GProps g;
  BRepGProp::SurfaceProperties(f, g);
  return g.Mass();
}

static void ends(const char* tag, const TopoDS_Edge& e)
{
  gp_Pnt a = BRep_Tool::Pnt(TopExp::FirstVertex(e)), b = BRep_Tool::Pnt(TopExp::LastVertex(e));
  printf("%s: length %.17g, from (%.17g, %.17g, %.17g) to (%.17g, %.17g, %.17g)\n", tag, length(e),
         a.X(), a.Y(), a.Z(), b.X(), b.Y(), b.Z());
}

int main()
{
  ends("edgeFromLine", BRepLib_MakeEdge(gp_Lin(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)), 0, 10).Edge());
  ends("edgeFromPoints", BRepLib_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(10, 5, 3)).Edge());
  ends("edgeFromCircle",
       BRepLib_MakeEdge(gp_Circ(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5), 0, M_PI).Edge());

  TopoDS_Face pf =
    BRepLib_MakeFace(new Geom_Plane(gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1))), 0, 10, 0, 10, 1e-6)
      .Face();
  printf("faceFromPlane: area %.17g\n", area(pf));
  TopoDS_Face cf =
    BRepLib_MakeFace(new Geom_CylindricalSurface(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5), 0,
                     M_PI, 0, 10, 1e-6)
      .Face();
  printf("faceFromCylinder: area %.17g\n", area(cf));
  BRepLib_MakeShell ms(new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 0, 10, 0, 10, false);
  int               nf = 0;
  for (TopExp_Explorer ex(ms.Shell(), TopAbs_FACE); ex.More(); ex.Next())
    nf++;
  printf("shellFromPlane: faces %d, area %.17g\n", nf, area(ms.Shell()));

  {
    TopoDS_Shape b = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
    BRepMesh_IncrementalMesh(b, 0.5, Standard_False, 0.5).Perform();
    Collector t(b);
    t.GeneratePointsByTriangulation();
    Collector d(b);
    d.GeneratePointsByDensity(1.0);
    int nodes = 0;
    for (TopExp_Explorer ex(b, TopAbs_FACE); ex.More(); ex.Next())
    {
      TopLoc_Location loc;
      nodes += BRep_Tool::Triangulation(TopoDS::Face(ex.Current()), loc)->NbNodes();
    }
    printf("pointCloudByTriangulation: %d points (triangulation nodes %d)\n", t.n, nodes);
    printf("pointCloudByDensity(1.0): %d points\n", d.n);
  }
  {
    TopoDS_Shape b = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
    BRepMesh_IncrementalMesh(b, 0.1, Standard_False, 0.5).Perform();
    int faces = 0, withNormals = 0;
    for (TopExp_Explorer ex(b, TopAbs_FACE); ex.More(); ex.Next())
    {
      TopLoc_Location            loc;
      Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(TopoDS::Face(ex.Current()), loc);
      if (tri.IsNull())
        continue;
      BRepLib_ToolTriangulatedShape::ComputeNormals(TopoDS::Face(ex.Current()), tri);
      faces++;
      withNormals += tri->HasNormals() ? 1 : 0;
    }
    printf("computeNormals: %d triangulated faces, %d with normals after\n", faces, withNormals);
  }
  return 0;
}
