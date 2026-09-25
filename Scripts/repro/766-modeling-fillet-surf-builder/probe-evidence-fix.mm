// Epic #766 evidence correction for PR #2691 (Tests/OCCTModelingTests/FilletSurfBuilderTests.swift).
// probe.mm printed the first edge's line as `status=0 (0=IsOk,...) nbSurface=1 tolApp3d(1)=... first=... last=...`
// and the record's kernel side said "FilletSurf_IsOk on all 12 edges". The bridge side used the keys
// status, surfaces, tolerance, firstParameter, lastParameter. This probe repeats the same
// FilletSurf_Builder calls and prints those keys, every double at %.17g (-0 written as 0), one
// `label: key=value ...` line, for the first TopExp::MapShapes edge (what the Swift test pins), plus
// a summary line over all 12 edges so the "all edges" claim is read from a run.
// OCCTFilletSurfBuild is FilletSurf_Builder(shape, {edge}, radius).Perform(), then IsDone,
// NbSurface, TolApp3d(i), FirstParameter, LastParameter. Same input: 10 mm box centred at the
// origin, radius 1.
#include <BRepPrimAPI_MakeBox.hxx>
#include <FilletSurf_Builder.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <cstdio>

int main()
{
  TopoDS_Shape               b = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape edges;
  TopExp::MapShapes(b, TopAbs_EDGE, edges);
  int isOk = 0, oneSurface = 0;
  for (int i = 1; i <= edges.Extent(); i++)
  {
    NCollection_List<TopoDS_Shape> l;
    l.Append(edges(i));
    FilletSurf_Builder fb(b, l, 1.0);
    fb.Perform();
    int st = (int)fb.IsDone();
    isOk += (st == (int)FilletSurf_IsOk);
    oneSurface += (fb.NbSurface() == 1);
    if (i == 1)
      printf("filletSurface: status=%d surfaces=%d tolerance=%.17g firstParameter=%.17g lastParameter=%.17g\n", st,
             fb.NbSurface(), fb.TolApp3d(1), fb.FirstParameter() + 0.0, fb.LastParameter() + 0.0);
  }
  printf("allEdges: edges=%d statusIsOk=%d withOneSurface=%d\n", edges.Extent(), isOk, oneSurface);
  return 0;
}
