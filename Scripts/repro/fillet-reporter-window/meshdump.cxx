// Tessellate the reporter's model, or the result of filleting one edge of it, for the SVG renderer (render.py).
//   meshdump model.brep <radius> <draw edge> [draw|def]    fillet result (prints FAIL <status> when IsDone() is false)
//   meshdump model.brep input <draw edge>                  the input, with the edge written as E lines
// Lines:  T x1 y1 z1 x2 y2 z2 x3 y3 z3 <face>    one triangle (outward)
//         E x1 y1 z1 x2 y2 z2 <tag>              one segment of an edge polyline
#include <BRepBndLib.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <ChFi3d_FilletShape.hxx>
#include <GCPnts_QuasiUniformDeflection.hxx>
#include <NCollection_IndexedMap.hxx>
#include <NCollection_Map.hxx>
#include <Poly_Triangulation.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopLoc_Location.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <TopoDS.hxx>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <unistd.h>
static void onSig(int s) { printf("FAIL signal%d\n", s); fflush(stdout); _exit(0); }
static void dumpMesh(const TopoDS_Shape& s)
{
  BRepMesh_IncrementalMesh(s, 0.02, false, 0.2, false);
  NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher> faces; TopExp::MapShapes(s, TopAbs_FACE, faces);
  for (int fi = 1; fi <= faces.Extent(); ++fi)
  {
    TopoDS_Face f = TopoDS::Face(faces(fi)); TopLoc_Location loc;
    occ::handle<Poly_Triangulation> t = BRep_Tool::Triangulation(f, loc);
    if (t.IsNull()) continue;
    bool rev = f.Orientation() == TopAbs_REVERSED;
    for (int i = 1; i <= t->NbTriangles(); ++i)
    {
      int a, b, c; t->Triangle(i).Get(a, b, c); if (rev) std::swap(b, c);
      gp_Pnt p[3] = {t->Node(a).Transformed(loc), t->Node(b).Transformed(loc), t->Node(c).Transformed(loc)};
      printf("T"); for (auto& q : p) printf(" %.6f %.6f %.6f", q.X(), q.Y(), q.Z()); printf(" %d\n", fi);
    }
  }
}
static void dumpEdge(const TopoDS_Edge& e, const char* tag)
{
  BRepAdaptor_Curve c(e); GCPnts_QuasiUniformDeflection d(c, 0.01);
  if (!d.IsDone()) return;
  for (int i = 1; i < d.NbPoints(); ++i) { gp_Pnt a = d.Value(i), b = d.Value(i + 1); printf("E %.6f %.6f %.6f %.6f %.6f %.6f %s\n", a.X(), a.Y(), a.Z(), b.X(), b.Y(), b.Z(), tag); }
}
int main(int, char** argv)
{
  signal(SIGSEGV, onSig); signal(SIGBUS, onSig); signal(SIGABRT, onSig);
  TopoDS_Shape s; BRep_Builder bb; BRepTools::Read(s, argv[1], bb);
  NCollection_Map<TopoDS_Shape, TopTools_ShapeMapHasher> seen; seen.Add(s);
  std::vector<TopoDS_Edge> byNum(1);
  for (TopExp_Explorer ex(s, TopAbs_EDGE); ex.More(); ex.Next()) if (seen.Add(ex.Current())) byNum.push_back(TopoDS::Edge(ex.Current()));
  if (!strcmp(argv[2], "input")) { dumpMesh(s); dumpEdge(byNum[atoi(argv[3])], "edge"); return 0; }
  double R = atof(argv[2]); int want = atoi(argv[3]); bool draw = argv[4] && !strcmp(argv[4], "draw");
  try
  {
    BRepFilletAPI_MakeFillet mk(s, ChFi3d_Rational);
    if (draw) { mk.SetParams(1e-2, 1e-4, 1e-5, 1e-4, 1e-5, 1e-3); mk.SetContinuity(GeomAbs_C1, 1e-2); }
    mk.Add(R, byNum[want]); mk.Build();
    if (!mk.IsDone()) { printf("FAIL notdone\n"); return 0; }
    TopoDS_Shape r = mk.Shape();
    printf("INFO valid=%d\n", (int)BRepCheck_Analyzer(r).IsValid());
    dumpMesh(r);
  }
  catch (Standard_Failure&) { printf("FAIL exception\n"); }
}
