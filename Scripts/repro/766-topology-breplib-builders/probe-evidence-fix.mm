// Epic #766, BRepLibToolTriangulatedShapeTests.swift "Compute normals on meshed shape", rewritten to
// assert what the normals are, not only that computeNormals() returned true. Same sequence as the
// test and OCCTBRepLibComputeNormals: BRepMesh_IncrementalMesh(0.1, false, 0.5) on a 10 x 10 x 10
// box (what Shape.mesh(linearDeflection: 0.1) runs), then BRepLib_ToolTriangulatedShape::ComputeNormals
// on every face's triangulation. Per face it reads HasNormals before and after, NbNodes, the plane
// normal of triangle 1 (cross of its two edges) and every node normal's deviation from that plane
// (| |n . plane| - 1 |), the quantities the test asserts.
#include <BRepLib_ToolTriangulatedShape.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Tool.hxx>
#include <Poly_Triangulation.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdio>

int main()
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  BRepMesh_IncrementalMesh(box, 0.1, Standard_False, 0.5).Perform();

  TopTools_IndexedMapOfShape faces;
  TopExp::MapShapes(box, TopAbs_FACE, faces);
  int before = 0;
  for (int i = 1; i <= faces.Extent(); ++i)
  {
    TopLoc_Location            loc;
    Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(TopoDS::Face(faces(i)), loc);
    if (!tri.IsNull() && tri->HasNormals())
      ++before;
  }
  printf("before: faces %d withNormals %d\n", faces.Extent(), before);

  // OCCTBRepLibComputeNormals: every triangulated face, ComputeNormals, true if any ran.
  int ran = 0;
  for (TopExp_Explorer ex(box, TopAbs_FACE); ex.More(); ex.Next())
  {
    TopoDS_Face                face = TopoDS::Face(ex.Current());
    TopLoc_Location            loc;
    Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(face, loc);
    if (!tri.IsNull())
    {
      BRepLib_ToolTriangulatedShape::ComputeNormals(face, tri);
      ++ran;
    }
  }
  printf("ComputeNormals ran on %d faces, computed=%d\n", ran, ran > 0 ? 1 : 0);

  int    after  = 0;
  double maxDev = 0.0;
  int    nodesPerFaceMin = 1 << 30, nodesPerFaceMax = 0;
  for (int i = 1; i <= faces.Extent(); ++i)
  {
    TopLoc_Location            loc;
    Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(TopoDS::Face(faces(i)), loc);
    if (tri.IsNull())
      continue;
    if (tri->HasNormals())
      ++after;
    int a, b, c;
    tri->Triangle(1).Get(a, b, c);
    gp_Pnt pa = tri->Node(a), pb = tri->Node(b), pc = tri->Node(c);
    gp_Vec plane = gp_Vec(pa, pb).Crossed(gp_Vec(pa, pc));
    plane.Normalize();
    printf("face %d: hasNormals=%d nodes=%d plane=(%.17g, %.17g, %.17g) normals:", i - 1,
           tri->HasNormals() ? 1 : 0, tri->NbNodes(), plane.X(), plane.Y(), plane.Z());
    nodesPerFaceMin = std::min(nodesPerFaceMin, (int)tri->NbNodes());
    nodesPerFaceMax = std::max(nodesPerFaceMax, (int)tri->NbNodes());
    for (int k = 1; k <= tri->NbNodes() && tri->HasNormals(); ++k)
    {
      gp_Dir n   = tri->Normal(k);
      double dev = std::fabs(std::fabs(n.X() * plane.X() + n.Y() * plane.Y() + n.Z() * plane.Z()) - 1.0);
      maxDev     = std::max(maxDev, dev);
      printf(" (%.17g, %.17g, %.17g)", n.X(), n.Y(), n.Z());
    }
    printf("\n");
  }
  printf("after: faces %d withNormals %d nodesPerFace %d..%d maxPlaneDeviation %.17g\n",
         faces.Extent(), after, nodesPerFaceMin, nodesPerFaceMax, maxDev);
  return 0;
}
