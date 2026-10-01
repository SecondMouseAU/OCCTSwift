// Epic #766 (#1978), kernel parity for Issue636ExtremaParallelCurvesTests and
// Issue853UniformAbscissaDistanceCeilingTests. #636: Extrema_ExtCC on the parallel pairs (IsParallel,
// and the distance it reports) and on the crossing and disjoint pairs. #853: GCPnts_UniformAbscissa
// by distance on a 10-unit box edge, whole and over [0, 1].
#include <BRepAdaptor_Curve.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <Extrema_ExtCC.hxx>
#include <GC_MakeSegment.hxx>
#include <GCPnts_UniformAbscissa.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Geom_Line.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdio>

static void cc(const char* name, const Handle(Geom_Curve)& a, const Handle(Geom_Curve)& b)
{
  GeomAdaptor_Curve A(a), B(b);
  Extrema_ExtCC     e(A, B);
  printf("%s: done %d parallel %d", name, e.IsDone(), e.IsDone() ? e.IsParallel() : -1);
  if (e.IsDone() && e.IsParallel())
    printf(" sqdist(1) %.9g", e.SquareDistance(1));
  else if (e.IsDone())
  {
    printf(" NbExt %d", e.NbExt());
    for (int i = 1; i <= e.NbExt(); i++)
      printf(" | dist %.9g", sqrt(e.SquareDistance(i)));
  }
  printf("\n");
}

int main()
{
  cc("parallel lines 5 apart", new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)), new Geom_Line(gp_Pnt(0, 5, 0), gp_Dir(1, 0, 0)));
  cc("overlapping parallel segments", GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Value(),
     GC_MakeSegment(gp_Pnt(0, 5, 0), gp_Pnt(10, 5, 0)).Value());
  cc("disjoint parallel segments", GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Value(),
     GC_MakeSegment(gp_Pnt(20, 5, 0), gp_Pnt(30, 5, 0)).Value());
  cc("skew lines", new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)), new Geom_Line(gp_Pnt(5, -5, 1), gp_Dir(0, 1, 0)));

  TopoDS_Shape    box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopExp_Explorer ex(box, TopAbs_EDGE);
  BRepAdaptor_Curve e(TopoDS::Edge(ex.Current()));
  GCPnts_UniformAbscissa w(e, 3.0);
  printf("box edge [%g, %g] by distance 3: done %d NbPoints %d\n", e.FirstParameter(), e.LastParameter(), w.IsDone(), w.NbPoints());
  GCPnts_UniformAbscissa r(e, 0.2, 0, 1);
  printf("box edge [0, 1] by distance 0.2: done %d NbPoints %d\n", r.IsDone(), r.NbPoints());
  return 0;
}
