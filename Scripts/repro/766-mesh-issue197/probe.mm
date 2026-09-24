// Epic #766, Issue197MeshDeflectionTests.swift: kernel parity for all three tests.
// Same inputs as the Swift tests, straight to OCCT: BRepPrimAPI_MakeSphere(10), meshed by
// BRepMesh_IncrementalMesh(shape, deflection) and written by StlAPI_Writer in binary mode (what
// OCCTShapeWriteSTLBinary -> OCCTExportSTLWithMode does), then Poly_CoherentTriangulation built
// from the first face's triangulation at deflection 0.2 (OCCTCoherentTriangulationCreateFromMesh).
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Tool.hxx>
#include <Poly_CoherentTriangulation.hxx>
#include <Poly_Triangulation.hxx>
#include <StlAPI_Writer.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cstdio>
#include <sys/stat.h>

static long stlSize(double deflection, const char* path)
{
  TopoDS_Shape             s = BRepPrimAPI_MakeSphere(10.0).Shape();
  BRepMesh_IncrementalMesh mesher(s, deflection);
  StlAPI_Writer            w;
  w.ASCIIMode()   = Standard_False;
  bool        ok  = w.Write(s, path);
  struct stat st  = {};
  long        len = (stat(path, &st) == 0) ? (long)st.st_size : -1;
  printf("  deflection=%.17g write=%d size=%ld triangles=%ld\n", deflection, ok, len, (len - 84) / 50);
  remove(path);
  return len;
}

int main()
{
  printf("stlBinaryDeflection:\n");
  long coarse = stlSize(1.0, "/tmp/766_mesh_coarse.stl");
  long fine   = stlSize(0.05, "/tmp/766_mesh_fine.stl");
  printf("  fine > coarse: %d\n", fine > coarse);

  printf("stlDefaultUnchanged:\n");
  stlSize(0.1, "/tmp/766_mesh_default.stl");

  printf("coherentTriangulationDeflection:\n");
  for (double d : {0.2, 0.1})
  {
    TopoDS_Shape             s = BRepPrimAPI_MakeSphere(10.0).Shape();
    BRepMesh_IncrementalMesh mesh(s, d);
    for (TopExp_Explorer exp(s, TopAbs_FACE); exp.More(); exp.Next())
    {
      TopLoc_Location            loc;
      Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(TopoDS::Face(exp.Current()), loc);
      if (!tri.IsNull())
      {
        Handle(Poly_CoherentTriangulation) ct = new Poly_CoherentTriangulation(tri);
        printf("  deflection=%.17g firstFace nbNodes=%d nbTriangles=%d coherent NTriangles=%d\n",
               d, tri->NbNodes(), tri->NbTriangles(), ct->NTriangles());
        break;
      }
    }
  }
  return 0;
}
