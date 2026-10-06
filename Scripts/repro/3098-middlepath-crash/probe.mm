// #3098: BRepOffsetAPI_MiddlePath crash inputs, one case per process.
// usage: probe <case>   cases: sameFace adjacentFaces nullEnds nullShape oppositeBox cylinder
//        faceVsWire unrelated sphere sameWire
#include <BRepOffsetAPI_MiddlePath.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepTools.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Shape.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepPrimAPI_MakeCone.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopExp.hxx>
#include <gp_Pnt.hxx>
#include <cstdio>
#include <cstring>
#include <csignal>
#include <execinfo.h>
#include <unistd.h>

static void onSegv(int sig)
{
  void* frames[40];
  int   n = backtrace(frames, 40);
  fprintf(stderr, "SIGNAL %d\n", sig);
  backtrace_symbols_fd(frames, n, 2);
  _exit(139);
}

static TopoDS_Shape face(const TopoDS_Shape& s, int i)
{
  int k = 0;
  for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next())
    if (k++ == i)
      return e.Current();
  return TopoDS_Shape();
}

static TopoDS_Shape octahedron()
{
  gp_Pnt p[6] = {gp_Pnt(1, 0, 0), gp_Pnt(-1, 0, 0), gp_Pnt(0, 1, 0), gp_Pnt(0, -1, 0), gp_Pnt(0, 0, 1), gp_Pnt(0, 0, -1)};
  int    t[8][3] = {{0, 2, 4}, {2, 1, 4}, {1, 3, 4}, {3, 0, 4}, {2, 0, 5}, {1, 2, 5}, {3, 1, 5}, {0, 3, 5}};
  BRepBuilderAPI_Sewing sew(1e-6);
  for (auto& f : t)
  {
    BRepBuilderAPI_MakePolygon mp(p[f[0]], p[f[1]], p[f[2]], true);
    sew.Add(BRepBuilderAPI_MakeFace(mp.Wire()).Face());
  }
  sew.Perform();
  return sew.SewedShape();
}

static TopoDS_Shape named(const char* n)
{
  if (!strcmp(n, "box")) return BRepPrimAPI_MakeBox(10, 10, 10).Shape();
  if (!strcmp(n, "cyl")) return BRepPrimAPI_MakeCylinder(5, 10).Shape();
  if (!strcmp(n, "cone")) return BRepPrimAPI_MakeCone(5, 0, 10).Shape();
  if (!strcmp(n, "octa")) return octahedron();
  if (!strcmp(n, "tube")) return BRepAlgoAPI_Cut(BRepPrimAPI_MakeCylinder(5, 10).Shape(), BRepPrimAPI_MakeCylinder(2, 10).Shape()).Shape();
  if (!strcmp(n, "hex")) {
    BRepBuilderAPI_MakePolygon mp;
    for (int i = 0; i < 6; i++) mp.Add(gp_Pnt(5 * cos(i * M_PI / 3), 5 * sin(i * M_PI / 3), 0));
    mp.Close();
    return BRepPrimAPI_MakePrism(BRepBuilderAPI_MakeFace(mp.Wire()).Face(), gp_Vec(0, 0, 10)).Shape();
  }
  if (!strcmp(n, "lshape")) {
    BRepBuilderAPI_MakePolygon mp;
    double q[6][2] = {{0,0},{10,0},{10,5},{5,5},{5,10},{0,10}};
    for (auto& v : q) mp.Add(gp_Pnt(v[0], v[1], 0));
    mp.Close();
    return BRepPrimAPI_MakePrism(BRepBuilderAPI_MakeFace(mp.Wire()).Face(), gp_Vec(0, 0, 10)).Shape();
  }
  return TopoDS_Shape();
}

// pair mode: probe pair <shape> <i> <j> : reports vertices/edges shared by the OUTER WIRES, then runs
static int pairMode(const char* n, int i, int j)
{
  TopoDS_Shape s = named(n);
  TopoDS_Shape a = face(s, i), b = face(s, j);
  if (a.IsNull() || b.IsNull()) return 3;
  TopTools_IndexedMapOfShape va, vb, ea, eb;
  TopoDS_Wire wa = BRepTools::OuterWire(TopoDS::Face(a)), wb = BRepTools::OuterWire(TopoDS::Face(b));
  TopExp::MapShapes(wa, TopAbs_VERTEX, va); TopExp::MapShapes(wb, TopAbs_VERTEX, vb);
  TopExp::MapShapes(wa, TopAbs_EDGE, ea); TopExp::MapShapes(wb, TopAbs_EDGE, eb);
  int sv = 0, se = 0;
  for (int k = 1; k <= va.Extent(); k++) if (vb.Contains(va(k))) sv++;
  for (int k = 1; k <= ea.Extent(); k++) if (eb.Contains(ea(k))) se++;
  printf("%s %d %d sharedVerts=%d sharedEdges=%d same=%d ", n, i, j, sv, se, (int)a.IsSame(b));
  fflush(stdout);
  BRepOffsetAPI_MiddlePath builder(s, a, b);
  builder.Build();
  printf("-> done=%d\n", (int)builder.IsDone());
  return 0;
}

int main(int argc, char** argv)
{
  if (argc == 5 && !strcmp(argv[1], "pair"))
  {
    signal(SIGSEGV, onSegv);
    signal(SIGABRT, onSegv);
    return pairMode(argv[2], atoi(argv[3]), atoi(argv[4]));
  }
  signal(SIGSEGV, onSegv);
  signal(SIGBUS, onSegv);
  signal(SIGABRT, onSegv);
  const char*  c = argc > 1 ? argv[1] : "";
  TopoDS_Shape box = BRepPrimAPI_MakeBox(10, 10, 10).Shape();
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();
  TopoDS_Shape sph = BRepPrimAPI_MakeSphere(5).Shape();
  TopoDS_Shape shape = box, a, b;
  if (!strcmp(c, "sameFace")) { a = b = face(box, 0); }
  else if (!strcmp(c, "adjacentFaces")) { a = face(box, 0); b = face(box, 2); }
  else if (!strcmp(c, "nullEnds")) { }
  else if (!strcmp(c, "nullStart")) { b = face(box, 1); }
  else if (!strcmp(c, "nullEnd")) { a = face(box, 0); }
  else if (!strcmp(c, "nullShape")) { shape = TopoDS_Shape(); a = face(box, 0); b = face(box, 1); }
  else if (!strcmp(c, "oppositeBox")) { a = face(box, 0); b = face(box, 1); }
  else if (!strcmp(c, "cylinder")) { shape = cyl; a = face(cyl, 1); b = face(cyl, 2); }
  else if (!strcmp(c, "cylSideCap")) { shape = cyl; a = face(cyl, 0); b = face(cyl, 1); }
  else if (!strcmp(c, "sphere")) { shape = sph; a = face(sph, 0); b = face(sph, 0); }
  else if (!strcmp(c, "wireOpposite")) { a = BRepTools::OuterWire(TopoDS::Face(face(box, 0))); b = BRepTools::OuterWire(TopoDS::Face(face(box, 1))); }
  else if (!strcmp(c, "sameWire")) { a = b = BRepTools::OuterWire(TopoDS::Face(face(box, 0))); }
  else if (!strcmp(c, "nonFaceWire")) { a = box; b = face(box, 1); }
  else if (!strcmp(c, "edgeStart")) { TopExp_Explorer e(box, TopAbs_EDGE); a = e.Current(); b = face(box, 1); }
  else if (!strcmp(c, "vertexStart")) { TopExp_Explorer e(box, TopAbs_VERTEX); a = e.Current(); b = face(box, 1); }
  else if (!strcmp(c, "shellStart")) { TopExp_Explorer e(box, TopAbs_SHELL); a = e.Current(); b = face(box, 1); }
  else return 2;
  try {
  BRepOffsetAPI_MiddlePath builder(shape, a, b);
  builder.Build();
  printf("%s: done=%d null=%d\n", c, (int)builder.IsDone(), builder.IsDone() ? (int)builder.Shape().IsNull() : -1);
  } catch (Standard_Failure const& f) { printf("%s: exception %s\n", c, f.GetMessageString()); }
  return 0;
}
