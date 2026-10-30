// #3490 item 3 / #2746: BRepCheck_Analyzer on a planar face whose edge has lost its 3D curve.
//
//   K=<OCCT.xcframework>/macos-arm64
//   clang++ -std=c++17 -O0 -g -w -I $K/Headers brepcheck-pcurve-only-edge.cxx -L $K -lOCCT-macos \
//     -lc++ -framework Foundation -o /tmp/pcurve-only && /tmp/pcurve-only
//
// Without carried patch 0077 the analyzer dies in BRepCheck_Edge::InContext (a backtrace is
// printed, exit 9). With it, "valid after 0".
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <Geom_Curve.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>

#include <cstdio>
#include <execinfo.h>
#include <signal.h>
#include <unistd.h>

static void onSignal(int)
{
  void* frames[40];
  backtrace_symbols_fd(frames, backtrace(frames, 40), 2);
  _exit(9);
}

int main()
{
  signal(SIGSEGV, onSignal);
  signal(SIGBUS, onSignal);
  TopoDS_Shape    box = BRepPrimAPI_MakeBox(10, 20, 30).Shape();
  TopExp_Explorer faces(box, TopAbs_FACE);
  TopoDS_Face     face = TopoDS::Face(faces.Current());
  std::fprintf(stderr, "valid before %d\n", (int)BRepCheck_Analyzer(face).IsValid());
  TopExp_Explorer edges(face, TopAbs_EDGE);
  TopoDS_Edge      edge = TopoDS::Edge(edges.Current());
  BRep_Builder().UpdateEdge(edge, occ::handle<Geom_Curve>(), BRep_Tool::Tolerance(edge));
  double a, b;
  std::fprintf(stderr, "3d curve now null: %d\n", (int)BRep_Tool::Curve(edge, a, b).IsNull());
  std::fprintf(stderr, "valid after %d\n", (int)BRepCheck_Analyzer(face).IsValid());
  return 0;
}
