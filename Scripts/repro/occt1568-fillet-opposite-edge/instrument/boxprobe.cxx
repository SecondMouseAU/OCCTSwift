#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <NCollection_IndexedMap.hxx>
#include <TopExp.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <cstdio>
#include <cstdlib>
#include <csignal>
#include <unistd.h>
static void onSig(int s) { printf("RESULT SIGNAL %d\n", s); fflush(stdout); _exit(100 + s % 100); }
int main(int argc, char** argv)
{
  signal(SIGSEGV, onSig); signal(SIGBUS, onSig); signal(SIGABRT, onSig);
  double dx = atof(argv[1]), dy = atof(argv[2]), dz = atof(argv[3]), r = atof(argv[4]);
  int ei = atoi(argv[5]);
  TopoDS_Shape box = BRepPrimAPI_MakeBox(dx, dy, dz).Shape();
  NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher> edges;
  TopExp::MapShapes(box, TopAbs_EDGE, edges);
  if (ei < 1 || ei > edges.Extent()) { printf("RESULT bad edge\n"); return 2; }
  try
  {
    BRepFilletAPI_MakeFillet mk(box);
    mk.Add(r, TopoDS::Edge(edges(ei)));
    mk.Build();
    printf("RESULT done=%d\n", (int)mk.IsDone());
  }
  catch (...) { printf("RESULT exception\n"); }
  return 0;
}
