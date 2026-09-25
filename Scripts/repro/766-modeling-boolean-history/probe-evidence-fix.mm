// Epic #766 evidence correction for PR #2687 (Tests/OCCTModelingTests/BooleanHistoryTests.swift).
// probe.mm printed the volume at %.10g and the modified-face count under a key the bridge side did
// not share. This probe repeats the same fuse and prints every double at %.17g and every flag as
// true/false, one `label: key=value ...` line per test.
// OCCTShapeFuseWithHistory is BRepAlgoAPI_Fuse(a, b) then Modified(face) over a's faces (TopExp_Explorer)
// with the list lengths summed; the boxes are the tests' centred cubes, the second translated in x.
//
// Tightening pass (#766): the tests asserted `r.shape.volume! > 0` (a force-unwrap inside #expect, and
// any positive volume passed) and `r.modifiedFaces.count > 0`, after a separate non-nil check and inside
// an `if let`. They now assert the measured volume, the solid count of the fused shape and the modified
// count exactly, and that every modified shape is a face, so each line also prints `solids`
// (TopExp::MapShapes over the fuse's shape) and `allFaces` (every entry of Modified(face) is a
// TopAbs_FACE, true for the empty list).
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
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
  bool             allFaces = true;
  for (TopExp_Explorer ex(a, TopAbs_FACE); ex.More(); ex.Next())
  {
    const TopTools_ListOfShape& m = fuse.Modified(ex.Current());
    modified += m.Extent();
    for (TopTools_ListIteratorOfListOfShape it(m); it.More(); it.Next())
      if (it.Value().ShapeType() != TopAbs_FACE)
        allFaces = false;
  }
  GProp_GProps p;
  BRepGProp::VolumeProperties(fuse.Shape(), p);
  TopTools_IndexedMapOfShape solids;
  TopExp::MapShapes(fuse.Shape(), TopAbs_SOLID, solids);
  printf("%s: done=%s volume=%.17g solids=%d modifiedFaces=%d allFaces=%s\n", label, fuse.IsDone() ? "true" : "false",
         p.Mass(), solids.Extent(), modified, allFaces ? "true" : "false");
}

int main()
{
  run("fuseWithHistory", 10, 5);
  run("fuseNonOverlappingHistory", 5, 20);
  return 0;
}
