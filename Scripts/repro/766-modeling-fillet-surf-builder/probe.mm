// Epic #766, Tests/OCCTModelingTests/FilletSurfBuilderTests.swift: kernel parity for its one test.
// OCCTFilletSurfBuild is FilletSurf_Builder(shape, {edge}, radius).Perform(), then IsDone,
// NbSurface, TolApp3d(i), FirstParameter, LastParameter. Same input: 10 mm box centred at the
// origin, each TopExp::MapShapes edge on its own (Shape.subShapes(ofType: .edge) order), radius 1.
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
  for (int i = 1; i <= edges.Extent(); i++)
  {
    NCollection_List<TopoDS_Shape> l;
    l.Append(edges(i));
    FilletSurf_Builder fb(b, l, 1.0);
    fb.Perform();
    int st = (int)fb.IsDone();
    printf("edge %d: status=%d (0=IsOk,1=IsNotOk,2=IsPartial)", i - 1, st);
    if (st != (int)FilletSurf_IsNotOk)
    {
      printf(" nbSurface=%d", fb.NbSurface());
      if (fb.NbSurface() > 0)
        printf(" tolApp3d(1)=%.17g first=%.17g last=%.17g", fb.TolApp3d(1), fb.FirstParameter(),
               fb.LastParameter());
    }
    printf("\n");
  }
  return 0;
}
