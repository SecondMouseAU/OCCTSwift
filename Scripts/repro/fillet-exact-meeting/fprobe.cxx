// Raw-OCCT probe: BRepFilletAPI_MakeFillet on a corner-origin box, edges named by midpoint.
//   fprobe <mode> dx dy dz r mx,my,mz [mx,my,mz ...]
// mode: add  = one builder, Add(r, e) per edge, Build (the Shape.filleted path)
//       add2 = one builder, Add(r, r, e) per edge (FreeCAD's Part::Fillet call form)
//       seq  = one builder per edge, each applied to the previous result (fillet next to a finished fillet)
// One process per case: the original defect (OCCT#1568) is an uncatchable SIGSEGV.
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRepBndLib.hxx>
#include <Bnd_Box.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <NCollection_IndexedMap.hxx>
#include <Standard_Failure.hxx>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <csignal>
#include <vector>
#include <string>
#include <unistd.h>
static void onSig(int s) { printf("RESULT SIGNAL %d\n", s); fflush(stdout); _exit(100 + s % 100); }
static TopoDS_Edge nearest(const TopoDS_Shape& sh, double x, double y, double z)
{
  NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher> edges;
  TopExp::MapShapes(sh, TopAbs_EDGE, edges);
  double best = 1e300; TopoDS_Edge be;
  for (int i = 1; i <= edges.Extent(); ++i)
  {
    Bnd_Box b; BRepBndLib::Add(edges(i), b);
    double a0, a1, a2, b0, b1, b2; b.Get(a0, a1, a2, b0, b1, b2);
    double d = pow((a0 + b0) / 2 - x, 2) + pow((a1 + b1) / 2 - y, 2) + pow((a2 + b2) / 2 - z, 2);
    if (d < best) { best = d; be = TopoDS::Edge(edges(i)); }
  }
  return be;
}
static void report(const char* tag, bool done, int nfaulty, const TopoDS_Shape& res)
{
  bool valid = false; double vol = -1; int nf = 0;
  if (!res.IsNull())
  {
    valid = BRepCheck_Analyzer(res).IsValid();
    GProp_GProps p; BRepGProp::VolumeProperties(res, p); vol = p.Mass();
    for (TopExp_Explorer e(res, TopAbs_FACE); e.More(); e.Next()) ++nf;
  }
  printf("RESULT %s done=%d faulty=%d valid=%d vol=%.9f faces=%d\n", tag, (int)done, nfaulty, (int)valid, vol, nf);
}
int main(int argc, char** argv)
{
  signal(SIGSEGV, onSig); signal(SIGBUS, onSig); signal(SIGABRT, onSig);
  std::string mode = argv[1];
  double dx = atof(argv[2]), dy = atof(argv[3]), dz = atof(argv[4]), r = atof(argv[5]);
  TopoDS_Shape box = BRepPrimAPI_MakeBox(dx, dy, dz).Shape();
  std::vector<double> m;
  for (int i = 6; i < argc; ++i) { double a, b, c; sscanf(argv[i], "%lf,%lf,%lf", &a, &b, &c); m.push_back(a); m.push_back(b); m.push_back(c); }
  try
  {
    if (mode == "seq")
    {
      TopoDS_Shape cur = box;
      for (size_t i = 0; i + 2 < m.size() + 0 && i < m.size(); i += 3)
      {
        BRepFilletAPI_MakeFillet mk(cur);
        mk.Add(r, nearest(cur, m[i], m[i + 1], m[i + 2]));
        mk.Build();
        if (!mk.IsDone()) { printf("(seq step %zu failed, faulty=%d)\n", i / 3, mk.NbFaultyContours()); report("seq", false, mk.NbFaultyContours(), TopoDS_Shape()); return 0; }
        cur = mk.Shape();
      }
      report("seq", true, 0, cur);
      return 0;
    }
    BRepFilletAPI_MakeFillet mk(box);
    for (size_t i = 0; i + 2 < m.size(); i += 3)
    {
      TopoDS_Edge e = nearest(box, m[i], m[i + 1], m[i + 2]);
      if (mode == "add2") mk.Add(r, r, e); else mk.Add(r, e);
    }
    mk.Build();
    TopoDS_Shape res;
    if (mk.IsDone()) res = mk.Shape();
    report(mode.c_str(), mk.IsDone(), mk.NbFaultyContours(), res);
    printf("  stages: HasResult=%d NbFaultyContours=%d NbFaultyVertices=%d\n", (int)mk.HasResult(), mk.NbFaultyContours(), mk.NbFaultyVertices());
    for (int i = 1; i <= mk.NbFaultyContours(); ++i)
      printf("  faulty contour %d status=%d\n", mk.FaultyContour(i), (int)mk.StripeStatus(mk.FaultyContour(i)));
  }
  catch (Standard_Failure& f) { printf("RESULT %s exception %s: %s\n", mode.c_str(), f.GetMessageString() ? "Standard_Failure" : "", f.GetMessageString()); }
  catch (...) { printf("RESULT %s exception unknown\n", mode.c_str()); }
  return 0;
}
