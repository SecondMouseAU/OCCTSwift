// Epic #766 evidence correction for PR #2687 (Tests/OCCTModelingTests/BooleanHistoryTests.swift).
// probe.mm printed the volume at %.10g and the modified-face count under a key the bridge side did
// not share. This probe repeats the same fuse and prints every double at %.17g and every flag as
// true/false, one `label: key=value ...` line per test.
// OCCTShapeFuseWithHistory is BRepAlgoAPI_Fuse(a, b) then Modified(face) over a's faces (TopExp_Explorer)
// with the list lengths summed; the boxes are the tests' centred cubes, the second translated in x.
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
  printf("%s: done=%s volume=%.17g modifiedFaces=%d\n", label, fuse.IsDone() ? "true" : "false", p.Mass(),
         modified);
}

int main()
{
  run("fuseWithHistory", 10, 5);
  run("fuseNonOverlappingHistory", 5, 20);
  return 0;
}
