// Epic #766, BRepLibExtendedTests.swift "Update deflection": the test was rewritten onto a
// radius-5 sphere (BRepPrimAPI_MakeSphere(5.0), the shape Shape.sphere(radius: 5) builds), so its
// kernel values need a sphere run; probe.mm's updateDeflection block measures the box. Same
// sequence as the test: BRepMesh_IncrementalMesh(0.5, false, 0.5) (what Shape.mesh(linearDeflection:
// 0.5) runs), BRepLib::UpdateDeflection, then the face's bounds with BRepBndLib::Add(face, box,
// useTriangulation = true) (what Face.bounds runs).
#include <BRepBndLib.hxx>
#include <BRepLib.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Tool.hxx>
#include <Bnd_Box.hxx>
#include <Poly_Triangulation.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static void faceBounds(const char* tag, const TopoDS_Face& f)
{
  Bnd_Box b;
  BRepBndLib::Add(f, b, Standard_True);
  double x0, y0, z0, x1, y1, z1;
  b.Get(x0, y0, z0, x1, y1, z1);
  TopLoc_Location            loc;
  Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(f, loc);
  printf("%s: triangulation deflection %.17g, face bounds min (%.17g, %.17g, %.17g) max (%.17g, "
         "%.17g, %.17g)\n",
         tag, tri.IsNull() ? -1.0 : tri->Deflection(), x0, y0, z0, x1, y1, z1);
}

int main()
{
  TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(5.0).Shape();
  BRepMesh_IncrementalMesh(sphere, 0.5, Standard_False, 0.5).Perform();
  TopTools_IndexedMapOfShape faces;
  TopExp::MapShapes(sphere, TopAbs_FACE, faces);
  printf("sphere faces: %d\n", faces.Extent());
  faceBounds("sphere updateDeflection before", TopoDS::Face(faces(1)));
  BRepLib::UpdateDeflection(sphere);
  faceBounds("sphere updateDeflection after", TopoDS::Face(faces(1)));
  return 0;
}
