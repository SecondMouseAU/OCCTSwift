// Epic #766, Tests/OCCTModelingTests/BooleanHistoryTests.swift: kernel parity for both tests.
// OCCTShapeFuseWithHistory runs BRepAlgoAPI_Fuse and collects Modified() of every shape1 face
// reached by a TopExp_Explorer; the Swift result shape is a separate union. Same inputs here.
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <TopExp_Explorer.hxx>
#include <cstdio>

static TopoDS_Shape box(double s, double tx)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-s / 2 + tx, -s / 2, -s / 2), s, s, s).Shape();
}

static void run(const char* label, double s, double tx)
{
  TopoDS_Shape     a = box(s, 0), b = box(s, tx);
  BRepAlgoAPI_Fuse fuse(a, b);
  int              modified = 0;
  for (TopExp_Explorer ex(a, TopAbs_FACE); ex.More(); ex.Next())
    modified += fuse.Modified(ex.Current()).Extent();
  GProp_GProps p;
  BRepGProp::VolumeProperties(fuse.Shape(), p);
  printf("%s: done=%d volume=%.10g modifiedFacesOfShape1=%d\n", label, fuse.IsDone(), p.Mass(), modified);
}

int main()
{
  run("fuseWithHistory", 10, 5);
  run("fuseNonOverlappingHistory", 5, 20);
  return 0;
}
