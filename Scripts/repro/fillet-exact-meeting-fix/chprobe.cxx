// BRepFilletAPI_MakeChamfer on opposite edges of a 4 x 10 x 6 box (OCCT#1177 names chamfers too).
//   chprobe d x,y,z x,y,z
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRepBndLib.hxx>
#include <Bnd_Box.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <NCollection_IndexedMap.hxx>
#include <cstdio>
#include <cstdlib>
#include <cmath>
static TopoDS_Edge nearest(const TopoDS_Shape& sh, double x, double y, double z)
{
  NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher> edges; TopExp::MapShapes(sh, TopAbs_EDGE, edges);
  double best = 1e300; TopoDS_Edge be;
  for (int i = 1; i <= edges.Extent(); ++i)
  {
    Bnd_Box b; BRepBndLib::Add(edges(i), b); double a0, a1, a2, b0, b1, b2; b.Get(a0, a1, a2, b0, b1, b2);
    double d = pow((a0 + b0) / 2 - x, 2) + pow((a1 + b1) / 2 - y, 2) + pow((a2 + b2) / 2 - z, 2);
    if (d < best) { best = d; be = TopoDS::Edge(edges(i)); }
  }
  return be;
}
int main(int argc, char** argv)
{
  double d = atof(argv[1]); TopoDS_Shape box = BRepPrimAPI_MakeBox(4, 10, 6).Shape();
  BRepFilletAPI_MakeChamfer mk(box);
  for (int i = 2; i < argc; ++i) { double a, b, c; sscanf(argv[i], "%lf,%lf,%lf", &a, &b, &c); mk.Add(d, nearest(box, a, b, c)); }
  mk.Build();
  if (!mk.IsDone()) { printf("RESULT chamfer done=0\n"); return 0; }
  GProp_GProps p; BRepGProp::VolumeProperties(mk.Shape(), p); int nf = 0; for (TopExp_Explorer e(mk.Shape(), TopAbs_FACE); e.More(); e.Next()) ++nf;
  printf("RESULT chamfer done=1 valid=%d vol=%.9f faces=%d  (analytic %.9f)\n", (int)BRepCheck_Analyzer(mk.Shape()).IsValid(), p.Mass(), nf, 240 - 2 * 0.5 * d * d * 10);
}
