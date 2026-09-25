#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS_Shape.hxx>
#include <cstdio>

int main() {
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5,-5,-5), 10,10,10).Shape();
  int n=0;
  for (TopExp_Explorer exp(box, TopAbs_EDGE); exp.More(); exp.Next()) n++;
  std::printf("fresh box edges (raw explorer, no map) = %d\n", n);

  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();
  int m=0;
  for (TopExp_Explorer exp(cyl, TopAbs_EDGE); exp.More(); exp.Next()) m++;
  std::printf("fresh cyl edges (raw explorer, no map) = %d\n", m);
  return 0;
}
