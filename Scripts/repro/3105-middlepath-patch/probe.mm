// #3105: extends the #3098 probe with more solids and a path-phase replay (mode "feat").
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
#include <BRepPrimAPI_MakeTorus.hxx>
#include <BRepPrimAPI_MakeRevol.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepTools_WireExplorer.hxx>
#include <ShapeUpgrade_UnifySameDomain.hxx>
#include <BRepLib_MakeWire.hxx>
#include <TopoDS_Iterator.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRep_Tool.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <Poly_Triangulation.hxx>
#include <TopoDS_Face.hxx>
#include <TopLoc_Location.hxx>
#include <cstdio>
#include <vector>
#include <string>
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
  if (!strcmp(n, "tri") || !strcmp(n, "pent") || !strcmp(n, "oct8") || !strcmp(n, "star")) {
    int k = !strcmp(n, "tri") ? 3 : !strcmp(n, "pent") ? 5 : !strcmp(n, "oct8") ? 8 : 10;
    BRepBuilderAPI_MakePolygon mp;
    for (int i = 0; i < k; i++) {
      double r = (!strcmp(n, "star") && (i % 2)) ? 2.5 : 5;
      mp.Add(gp_Pnt(r * cos(i * 2 * M_PI / k), r * sin(i * 2 * M_PI / k), 0));
    }
    mp.Close();
    return BRepPrimAPI_MakePrism(BRepBuilderAPI_MakeFace(mp.Wire()).Face(), gp_Vec(0, 0, 10)).Shape();
  }
  if (!strcmp(n, "ushape")) {
    BRepBuilderAPI_MakePolygon mp;
    double q[8][2] = {{0,0},{10,0},{10,10},{7,10},{7,3},{3,3},{3,10},{0,10}};
    for (auto& v : q) mp.Add(gp_Pnt(v[0], v[1], 0));
    mp.Close();
    return BRepPrimAPI_MakePrism(BRepBuilderAPI_MakeFace(mp.Wire()).Face(), gp_Vec(0, 0, 10)).Shape();
  }
  if (!strcmp(n, "sqtube"))
    return BRepAlgoAPI_Cut(BRepPrimAPI_MakeBox(10, 10, 10).Shape(),
                           BRepPrimAPI_MakeBox(gp_Pnt(3, 3, -1), 4, 4, 12).Shape()).Shape();
  if (!strcmp(n, "frustum")) return BRepPrimAPI_MakeCone(5, 2, 10).Shape();
  if (!strcmp(n, "torus")) return BRepPrimAPI_MakeTorus(10, 2).Shape();
  if (!strcmp(n, "bend")) { // quarter-turn square tube section revolved about an offset axis
    BRepBuilderAPI_MakePolygon mp;
    mp.Add(gp_Pnt(10, 0, 0)); mp.Add(gp_Pnt(14, 0, 0)); mp.Add(gp_Pnt(14, 0, 4)); mp.Add(gp_Pnt(10, 0, 4)); mp.Close();
    return BRepPrimAPI_MakeRevol(BRepBuilderAPI_MakeFace(mp.Wire()).Face(), gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), M_PI / 2).Shape();
  }
  if (!strcmp(n, "elbow")) { // two boxes fused into an L-shaped bar
    return BRepAlgoAPI_Fuse(BRepPrimAPI_MakeBox(20, 4, 4).Shape(), BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 4, 20, 4).Shape()).Shape();
  }
  if (!strcmp(n, "capsule")) return BRepAlgoAPI_Fuse(BRepPrimAPI_MakeCylinder(3, 10).Shape(), BRepPrimAPI_MakeSphere(gp_Pnt(0, 0, 10), 3).Shape()).Shape();
  return TopoDS_Shape();
}


// ---- replay of Build()'s path phase through public OCCT pieces only (#3105) ----
typedef NCollection_IndexedDataMap<TopoDS_Shape, NCollection_List<TopoDS_Shape>, TopTools_ShapeMapHasher> AncMap;

static TopoDS_Wire unifiedWire(const TopoDS_Wire& w, ShapeUpgrade_UnifySameDomain& u)
{
  BRepLib_MakeWire mk;
  NCollection_Map<TopoDS_Shape, TopTools_ShapeMapHasher> gen;
  for (BRepTools_WireExplorer we(w); we.More(); we.Next())
  {
    TopoDS_Shape e = we.Current();
    const NCollection_List<TopoDS_Shape>& m = u.History()->Modified(e);
    if (!m.IsEmpty())
    {
      for (NCollection_List<TopoDS_Shape>::Iterator it(m); it.More(); it.Next())
        if (gen.Add(it.Value())) mk.Add(TopoDS::Edge(it.Value()));
    }
    else mk.Add(TopoDS::Edge(e));
  }
  return mk.Wire();
}

struct PathReplay { bool ok = false; std::string why; std::vector<int> lens; std::vector<int> endHit; int starts = 0; int ends = 0; bool closed = false; };

static PathReplay replayPaths(const TopoDS_Shape& shape, const TopoDS_Shape& a, const TopoDS_Shape& b)
{
  PathReplay R;
  ShapeUpgrade_UnifySameDomain un(shape);
  un.Build();
  TopoDS_Shape init = un.Shape();
  TopoDS_Wire sw = unifiedWire(BRepTools::OuterWire(TopoDS::Face(a)), un);
  TopoDS_Wire ew = unifiedWire(BRepTools::OuterWire(TopoDS::Face(b)), un);
  bool closed = sw.Closed();
  R.closed = closed;
  NCollection_Sequence<TopoDS_Shape> startV;
  NCollection_Map<TopoDS_Shape, TopTools_ShapeMapHasher> endV, startEdges;
  BRepTools_WireExplorer we(sw);
  for (; we.More(); we.Next()) startV.Append(we.CurrentVertex());
  if (!closed) startV.Append(we.CurrentVertex());
  for (we.Init(ew); we.More(); we.Next()) endV.Add(we.CurrentVertex());
  if (!closed) endV.Add(we.CurrentVertex());
  for (TopoDS_Iterator it(sw); it.More(); it.Next()) startEdges.Add(it.Value());
  R.starts = startV.Length(); R.ends = endV.Extent();
  AncMap VE;
  TopExp::MapShapesAndAncestors(init, TopAbs_VERTEX, TopAbs_EDGE, VE);
  NCollection_Map<TopoDS_Shape, TopTools_ShapeMapHasher> cur;
  NCollection_Sequence<NCollection_Sequence<TopoDS_Shape>> paths;
  TopoDS_Vertex V1, V2, NV; TopoDS_Edge ed;
  for (int i = 1; i <= startV.Length(); i++)
  {
    NCollection_Sequence<TopoDS_Shape> Edges;
    if (!VE.Contains(startV(i))) { R.why = "startVertexNotInUnified"; return R; }
    for (NCollection_List<TopoDS_Shape>::Iterator it(VE.FindFromKey(startV(i))); it.More(); it.Next())
    {
      ed = TopoDS::Edge(it.Value());
      if (!startEdges.Contains(ed))
      {
        TopExp::Vertices(ed, V1, V2, true);
        if (V1.IsSame(startV(i))) cur.Add(V2); else { ed.Reverse(); cur.Add(V1); }
        Edges.Append(ed);
        break;
      }
    }
    if (Edges.IsEmpty()) { R.why = "noOutgoingEdge"; return R; }
    paths.Append(Edges);
  }
  NCollection_List<TopoDS_Shape> nextV;
  for (;;)
  {
    for (int i = 1; i <= paths.Length(); i++)
    {
      const TopoDS_Shape& sh = paths(i).Last();
      TopoDS_Edge te; TopoDS_Vertex tv;
      if (sh.ShapeType() == TopAbs_EDGE) { te = TopoDS::Edge(sh); tv = TopExp::LastVertex(te, true); }
      else { if (paths(i).Length() < 2) { R.why = "bareVertexFirst"; return R; } te = TopoDS::Edge(paths(i)(paths(i).Length() - 1)); tv = TopoDS::Vertex(sh); }
      if (endV.Contains(tv)) continue;
      if (!VE.Contains(tv)) { R.why = "vertexNotInMap"; return R; }
      NCollection_Map<TopoDS_Shape, TopTools_ShapeMapHasher> cand;
      for (NCollection_List<TopoDS_Shape>::Iterator it(VE.FindFromKey(tv)); it.More(); it.Next())
      {
        ed = TopoDS::Edge(it.Value());
        if (ed.IsSame(te)) continue;
        TopExp::Vertices(ed, V1, V2, true);
        if (V1.IsSame(tv)) NV = V2; else { ed.Reverse(); NV = V1; }
        if (!cur.Contains(NV)) cand.Add(ed);
      }
      if (!cand.IsEmpty())
      {
        if (cand.Extent() > 1) paths(i).Append(tv);
        else { NCollection_Map<TopoDS_Shape, TopTools_ShapeMapHasher>::Iterator mi(cand); ed = TopoDS::Edge(mi.Key()); paths(i).Append(ed); nextV.Append(TopExp::LastVertex(ed, true)); }
      }
    }
    if (nextV.IsEmpty()) break;
    for (NCollection_List<TopoDS_Shape>::Iterator it(nextV); it.More(); it.Next()) cur.Add(it.Value());
    nextV.Clear();
  }
  R.ok = true;
  for (int i = 1; i <= paths.Length(); i++)
  {
    R.lens.push_back(paths(i).Length());
    const TopoDS_Shape& sh = paths(i).Last();
    TopoDS_Vertex tv = sh.ShapeType() == TopAbs_EDGE ? TopExp::LastVertex(TopoDS::Edge(sh), true) : TopoDS::Vertex(sh);
    R.endHit.push_back(endV.Contains(tv) ? 1 : 0);
  }
  return R;
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
  try {
  if (getenv("FEAT")) {
    PathReplay R = replayPaths(s, a, b);
    printf("replay=%s starts=%d ends=%d lens=", R.ok ? "ok" : R.why.c_str(), R.starts, R.ends);
    for (size_t k = 0; k < R.lens.size(); k++) printf("%d%s", R.lens[k], k + 1 < R.lens.size() ? "," : "");
    printf(" endHit=");
    for (size_t k = 0; k < R.endHit.size(); k++) printf("%d", R.endHit[k]);
    printf(" ");
  }
  fflush(stdout);
  fflush(stdout);
  BRepOffsetAPI_MiddlePath builder(s, a, b);
  builder.Build();
  printf("-> done=%d", (int)builder.IsDone());
  if (builder.IsDone() && !builder.Shape().IsNull()) {
    // signature of the answer, so a before/after run can show that a working pair did not change
    GProp_GProps lp; BRepGProp::LinearProperties(builder.Shape(), lp);
    int ne = 0; for (TopExp_Explorer e(builder.Shape(), TopAbs_EDGE); e.More(); e.Next()) ne++;
    gp_Pnt c = lp.CentreOfMass();
    printf(" edges=%d length=%.6f centre=%.6f,%.6f,%.6f", ne, lp.Mass(), c.X(), c.Y(), c.Z());
    if (const char* d = getenv("DUMPDIR")) {
      char f[512];
      snprintf(f, sizeof f, "%s/%s_%d_%d_path.brep", d, n, i, j); BRepTools::Write(builder.Shape(), f);
    }
  }
  printf("\n");
  if (const char* d = getenv("DUMPDIR")) {
    char f[512];
    snprintf(f, sizeof f, "%s/%s_%d_%d_solid.brep", d, n, i, j); BRepTools::Write(s, f);
    snprintf(f, sizeof f, "%s/%s_%d_%d_start.brep", d, n, i, j); BRepTools::Write(a, f);
    snprintf(f, sizeof f, "%s/%s_%d_%d_end.brep", d, n, i, j); BRepTools::Write(b, f);
  }
  } catch (Standard_Failure const& f) { printf("-> exception %s\n", f.GetMessageString()); return 4; }
  return 0;
}

// review-image modes (#3105). mesh: every face of the solid as triangles, in the explorer order the
// pair indices use. pathpoly: the middle path Build() answers, as polylines (nothing when not done).
static int meshMode(const char* n, const char* file)
{
  TopoDS_Shape s = named(n);
  BRepMesh_IncrementalMesh(s, 0.05, false, 0.3, false);
  FILE* f = fopen(file, "w");
  int k = 0;
  for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next(), k++)
  {
    TopLoc_Location loc;
    occ::handle<Poly_Triangulation> t = BRep_Tool::Triangulation(TopoDS::Face(e.Current()), loc);
    if (t.IsNull()) { fprintf(f, "F %d 0\n", k); continue; }
    fprintf(f, "F %d %d\n", k, (int)t->NbTriangles());
    for (int i = 1; i <= t->NbTriangles(); i++)
    {
      int a, b, c; t->Triangle(i).Get(a, b, c);
      gp_Pnt p[3] = {t->Node(a).Transformed(loc.Transformation()), t->Node(b).Transformed(loc.Transformation()), t->Node(c).Transformed(loc.Transformation())};
      fprintf(f, "T %.5f %.5f %.5f %.5f %.5f %.5f %.5f %.5f %.5f\n", p[0].X(), p[0].Y(), p[0].Z(), p[1].X(), p[1].Y(), p[1].Z(), p[2].X(), p[2].Y(), p[2].Z());
    }
  }
  fclose(f);
  return 0;
}

static int pathPolyMode(const char* n, int i, int j, const char* file)
{
  TopoDS_Shape s = named(n);
  TopoDS_Shape a = face(s, i), b = face(s, j);
  BRepOffsetAPI_MiddlePath builder(s, a, b);
  builder.Build();
  FILE* f = fopen(file, "w");
  fprintf(f, "DONE %d\n", (int)builder.IsDone());
  if (builder.IsDone())
    for (TopExp_Explorer e(builder.Shape(), TopAbs_EDGE); e.More(); e.Next())
    {
      BRepAdaptor_Curve c(TopoDS::Edge(e.Current()));
      fprintf(f, "L");
      for (int k = 0; k <= 24; k++)
      {
        gp_Pnt p = c.Value(c.FirstParameter() + (c.LastParameter() - c.FirstParameter()) * k / 24.0);
        fprintf(f, " %.5f %.5f %.5f", p.X(), p.Y(), p.Z());
      }
      fprintf(f, "\n");
    }
  fclose(f);
  return 0;
}

int main(int argc, char** argv)
{
  if (argc == 3 && !strcmp(argv[1], "count"))
  {
    TopoDS_Shape s = named(argv[2]);
    int k = 0;
    for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next()) k++;
    printf("%d\n", k);
    return 0;
  }
  if (argc == 4 && !strcmp(argv[1], "mesh")) return meshMode(argv[2], argv[3]);
  if (argc == 6 && !strcmp(argv[1], "pathpoly")) return pathPolyMode(argv[2], atoi(argv[3]), atoi(argv[4]), argv[5]);
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
