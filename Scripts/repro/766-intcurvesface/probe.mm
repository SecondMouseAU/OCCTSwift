// Epic #766, IntCurvesFaceTests.swift: kernel parity for both tests.
// Shape.intersectLine(origin:direction:) is OCCTLocOpeCSIntersectLine ->
// LocOpe_CSIntersector(shape).Perform({gp_Lin}), then NbPoints(1)/Point(1, i).
// The shape is Shape.fromFace(box.faces()[i]) for a centred 10x20x30 box.
#include <BRepPrimAPI_MakeBox.hxx>
#include <LocOpe_CSIntersector.hxx>
#include <LocOpe_PntFace.hxx>
#include <NCollection_Sequence.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <cstdio>
#include <gp_Lin.hxx>

static void run(const char* tag, const TopoDS_Shape& face)
{
  LocOpe_CSIntersector         cs(face);
  NCollection_Sequence<gp_Lin> lines;
  lines.Append(gp_Lin(gp_Pnt(0, 0, -50), gp_Dir(0, 0, 1)));
  cs.Perform(lines);
  printf("%s: done=%d nbPoints=%d\n", tag, cs.IsDone(), cs.NbPoints(1));
  for (int i = 1; i <= cs.NbPoints(1); i++)
  {
    const LocOpe_PntFace& pf = cs.Point(1, i);
    printf("  [%d] pnt=(%.17g, %.17g, %.17g) parameter=%.17g uv=(%.17g, %.17g)\n", i, pf.Pnt().X(),
           pf.Pnt().Y(), pf.Pnt().Z(), pf.Parameter(), pf.UParameter(), pf.VParameter());
  }
}

int main()
{
  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -10, -15), 10, 20, 30).Shape();
  TopTools_IndexedMapOfShape fm;
  TopExp::MapShapes(box, TopAbs_FACE, fm);
  run("lineFaceIntersection: faces()[4] (z = -15 cap)", fm(5));
  run("lineParallelToFaceMisses: faces()[0] (x = -5 plane)", fm(1));
  return 0;
}
