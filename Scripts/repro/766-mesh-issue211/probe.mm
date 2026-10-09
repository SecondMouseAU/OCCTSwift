// Epic #766, Issue211MeshParamTests.swift: kernel parity for all three tests.
// Same inputs as the Swift tests, straight to OCCT: IMeshTools_Parameters filled the way
// OCCTShapeCreateMeshWithParams fills it from MeshParameters.default, BRepMesh_IncrementalMesh
// on BRepPrimAPI_MakeSphere(5), node and triangle counts summed over every face (what
// Mesh.vertexCount / Mesh.triangleCount read back from the bridge's per-face concatenation).
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Tool.hxx>
#include <IMeshTools_Parameters.hxx>
#include <Poly_Triangulation.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static IMeshTools_Parameters bridgeParams(double deflection, bool allowQualityDecrease)
{
  IMeshTools_Parameters p;
  p.Deflection               = deflection;
  p.Angle                    = 0.5;
  p.DeflectionInterior       = deflection;
  p.AngleInterior            = 0.5;
  p.MinSize                  = 0.0;
  p.Relative                 = Standard_False;
  p.InParallel               = Standard_True;
  p.InternalVerticesMode     = Standard_True;
  p.ControlSurfaceDeflection = Standard_True;
  p.AdjustMinSize            = Standard_False;
  p.AllowQualityDecrease     = allowQualityDecrease;
  return p;
}

static void counts(const TopoDS_Shape& s, int& nodes, int& tris)
{
  nodes = tris = 0;
  for (TopExp_Explorer ex(s, TopAbs_FACE); ex.More(); ex.Next())
  {
    TopLoc_Location            loc;
    Handle(Poly_Triangulation) t = BRep_Tool::Triangulation(TopoDS::Face(ex.Current()), loc);
    if (!t.IsNull())
    {
      nodes += t->NbNodes();
      tris += t->NbTriangles();
    }
  }
}

static void mesh(const TopoDS_Shape& s, double d, bool allow, const char* label)
{
  BRepMesh_IncrementalMesh m(s, bridgeParams(d, allow));
  m.Perform();
  int n, t;
  counts(s, n, t);
  printf("  %s: deflection=%.17g allowQualityDecrease=%d vertexCount=%d triangleCount=%d\n",
         label, d, allow, n, t);
}

int main()
{
  printf("defaultIsFalse: IMeshTools_Parameters().AllowQualityDecrease=%d\n",
         IMeshTools_Parameters().AllowQualityDecrease);

  printf("meshesWithFlag:\n");
  mesh(BRepPrimAPI_MakeSphere(5.0).Shape(), 0.1, true, "fresh sphere");

  printf("coarserReplacesFiner (original test: two separate shapes):\n");
  mesh(BRepPrimAPI_MakeSphere(5.0).Shape(), 0.05, false, "fresh fine");
  mesh(BRepPrimAPI_MakeSphere(5.0).Shape(), 1.0, true, "fresh coarse");

  printf("coarserReplacesFiner (rewritten test: one shape, re-meshed):\n");
  {
    TopoDS_Shape s = BRepPrimAPI_MakeSphere(5.0).Shape();
    mesh(s, 0.05, false, "same shape, fine");
    mesh(s, 1.0, false, "same shape, coarse, flag off");
  }
  {
    TopoDS_Shape s = BRepPrimAPI_MakeSphere(5.0).Shape();
    mesh(s, 0.05, false, "same shape, fine");
    mesh(s, 1.0, true, "same shape, coarse, flag on");
  }
  return 0;
}
