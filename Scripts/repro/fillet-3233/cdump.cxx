// Fillets whose contours share a vertex (#3233): run the kernel's BRepFilletAPI_MakeFillet, and build the REFERENCE with no
// fillet code at all (removal prisms and balls cut out of the base solid), then compare.
//   cdump <fillet|ref|cmp> <shape> <r:mx,my,mz ...> -- <removal item ...>
// shape  box:dx,dy,dz                      corner-origin box
//        poly:H:x,y;x,y;...                plan polygon (counter-clockwise) extruded up from z = 0 by H
// removal items (the reference is base minus the union of these):
//   P:p0:e:d1:d2:t0:t1:q1:q2:cu:cv:r[:clip=x,y;x,y;...]
//        prism of the corner profile (corner at p0, lines to p0+q1*d1 and p0+q2*d2, arc of radius r centred p0+cu*d1+cv*d2)
//        swept along the unit vector e from t0 to t1; optional plan polygon that it is intersected with
//   B:x0,y0,z0,x1,y1,z1:cx,cy,cz:r        the box minus the ball (the corner removed by a spherical blend)
//   V:ox,oy,oz:sx,sy,sz:r:deg             the right-angle corner profile (corner at o, line to o+r*s, line to o-r*z, arc centred o+r*s-r*z)
//                                         revolved deg degrees about the vertical axis through o, counter-clockwise from the direction s
//                                         (the blend round a reflex vertical edge: the edge is the pivot)
// fillet: STATUS done valid vol faces solids shells free nonmanifold; then T and E lines (mesh) for render3233.py
// ref:    STATUS the same for the reference, then T and E lines
// cmp:    both, no mesh, plus the volume of kernel-minus-reference and reference-minus-kernel
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepPrimAPI_MakeRevol.hxx>
#include <gp_Ax1.hxx>
#include <gp_Dir.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepBndLib.hxx>
#include <BRep_Tool.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <GCPnts_QuasiUniformDeflection.hxx>
#include <Poly_Triangulation.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopLoc_Location.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
#include <NCollection_IndexedMap.hxx>
#include <Standard_Failure.hxx>
#include <gp_Vec.hxx>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <csignal>
#include <string>
#include <vector>
#include <unistd.h>
static void onSig(int s) { printf("STATUS signal %d\n", s); fflush(stdout); _exit(100 + s % 100); }
static std::vector<std::string> split(const std::string& s, char c)
{
  std::vector<std::string> o; std::string cur;
  for (char ch : s) { if (ch == c) { o.push_back(cur); cur.clear(); } else cur += ch; }
  o.push_back(cur); return o;
}
static gp_Vec vec3(const std::string& s) { double a, b, c; sscanf(s.c_str(), "%lf,%lf,%lf", &a, &b, &c); return gp_Vec(a, b, c); }
static double volume(const TopoDS_Shape& s) { GProp_GProps p; BRepGProp::VolumeProperties(s, p, 1.e-10, false, false); return p.Mass(); }   // adaptive, to 1e-10 relative
static TopoDS_Shape polyPrism(const std::vector<std::pair<double, double>>& pts, double z0, double h)
{
  BRepBuilderAPI_MakePolygon mp; for (auto& p : pts) mp.Add(gp_Pnt(p.first, p.second, z0)); mp.Close();
  TopoDS_Shape s = BRepPrimAPI_MakePrism(BRepBuilderAPI_MakeFace(mp.Wire(), true).Face(), gp_Vec(0, 0, h)).Shape();
  if (volume(s) < 0) s.Reverse();
  return s;
}
static TopoDS_Shape makeBase(const std::string& spec)
{
  if (spec.rfind("box:", 0) == 0) { gp_Vec v = vec3(spec.substr(4)); return BRepPrimAPI_MakeBox(v.X(), v.Y(), v.Z()).Shape(); }
  auto parts = split(spec, ':'); double H = atof(parts[1].c_str());
  std::vector<std::pair<double, double>> pts;
  for (auto& q : split(parts[2], ';')) { double x, y; sscanf(q.c_str(), "%lf,%lf", &x, &y); pts.push_back({x, y}); }
  return polyPrism(pts, 0, H);
}
static TopoDS_Edge nearest(const TopoDS_Shape& sh, const gp_Vec& m)
{
  NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher> edges; TopExp::MapShapes(sh, TopAbs_EDGE, edges);
  double best = 1e300; TopoDS_Edge be;
  for (int i = 1; i <= edges.Extent(); ++i)
  {
    Bnd_Box b; BRepBndLib::Add(edges(i), b); double a0, a1, a2, b0, b1, b2; b.Get(a0, a1, a2, b0, b1, b2);
    double d = pow((a0 + b0) / 2 - m.X(), 2) + pow((a1 + b1) / 2 - m.Y(), 2) + pow((a2 + b2) / 2 - m.Z(), 2);
    if (d < best) { best = d; be = TopoDS::Edge(edges(i)); }
  }
  return be;
}
static TopoDS_Shape removalPrism(const std::string& item)
{
  auto f = split(item, ':');   // P p0 e d1 d2 t0 t1 q1 q2 cu cv r [clip]
  gp_Vec p0 = vec3(f[1]), e = vec3(f[2]), d1 = vec3(f[3]), d2 = vec3(f[4]);
  double t0 = atof(f[5].c_str()), t1 = atof(f[6].c_str()), q1 = atof(f[7].c_str()), q2 = atof(f[8].c_str());
  double cu = atof(f[9].c_str()), cv = atof(f[10].c_str()), r = atof(f[11].c_str());
  gp_Vec o = p0 + e * t0;
  gp_Vec a = o + d1 * q1, b = o + d2 * q2, c = o + d1 * cu + d2 * cv;
  gp_Vec toO = o - c; toO.Normalize(); gp_Vec m = c + toO * r;
  auto P = [](const gp_Vec& v) { return gp_Pnt(v.X(), v.Y(), v.Z()); };
  BRepBuilderAPI_MakeWire w;
  w.Add(BRepBuilderAPI_MakeEdge(P(o), P(a)).Edge());
  w.Add(BRepBuilderAPI_MakeEdge(GC_MakeArcOfCircle(P(a), P(m), P(b)).Value()).Edge());
  w.Add(BRepBuilderAPI_MakeEdge(P(b), P(o)).Edge());
  TopoDS_Shape s = BRepPrimAPI_MakePrism(BRepBuilderAPI_MakeFace(w.Wire(), true).Face(), e * (t1 - t0)).Shape();
  if (volume(s) < 0) s.Reverse();
  if (f.size() > 12 && f[12].rfind("clip=", 0) == 0)
  {
    std::vector<std::pair<double, double>> pts;
    for (auto& q : split(f[12].substr(5), ';')) { double x, y; sscanf(q.c_str(), "%lf,%lf", &x, &y); pts.push_back({x, y}); }
    BRepAlgoAPI_Common cm(s, polyPrism(pts, -100, 200)); cm.Build();
    if (!cm.IsDone()) { printf("STATUS refclipfail\n"); exit(0); }
    s = cm.Shape();
  }
  return s;
}
static TopoDS_Shape buildRef(const TopoDS_Shape& base, const std::vector<std::string>& items)
{
  TopoDS_Shape cur = base;
  for (auto& it : items)
  {
    TopoDS_Shape rem;
    if (it[0] == 'P') rem = removalPrism(it);
    else if (it[0] == 'V')
    {
      auto f = split(it, ':'); gp_Vec o = vec3(f[1]), sd = vec3(f[2]); double r = atof(f[3].c_str()), deg = atof(f[4].c_str());
      auto P = [](const gp_Vec& v) { return gp_Pnt(v.X(), v.Y(), v.Z()); };
      gp_Vec z(0, 0, 1), a = o + sd * r, b = o - z * r, c = o + sd * r - z * r;
      gp_Vec toO = o - c; toO.Normalize(); gp_Vec m = c + toO * r;
      BRepBuilderAPI_MakeWire w;
      w.Add(BRepBuilderAPI_MakeEdge(P(o), P(a)).Edge());
      w.Add(BRepBuilderAPI_MakeEdge(GC_MakeArcOfCircle(P(a), P(m), P(b)).Value()).Edge());
      w.Add(BRepBuilderAPI_MakeEdge(P(b), P(o)).Edge());
      rem = BRepPrimAPI_MakeRevol(BRepBuilderAPI_MakeFace(w.Wire(), true).Face(), gp_Ax1(P(o), gp_Dir(0, 0, 1)), deg * M_PI / 180.).Shape();
      if (volume(rem) < 0) rem.Reverse();
    }
    else
    {
      auto f = split(it, ':'); double v[6]; sscanf(f[1].c_str(), "%lf,%lf,%lf,%lf,%lf,%lf", v, v + 1, v + 2, v + 3, v + 4, v + 5);
      gp_Vec c = vec3(f[2]); double r = atof(f[3].c_str());
      TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(v[0], v[1], v[2]), gp_Pnt(v[3], v[4], v[5])).Shape();
      BRepAlgoAPI_Cut cb(box, BRepPrimAPI_MakeSphere(gp_Pnt(c.X(), c.Y(), c.Z()), r).Shape()); cb.Build();
      if (!cb.IsDone()) { printf("STATUS refballfail\n"); exit(0); }
      rem = cb.Shape();
    }
    BRepAlgoAPI_Cut cu(cur, rem); cu.Build();
    if (!cu.IsDone()) { printf("STATUS refcutfail\n"); exit(0); }
    cur = cu.Shape();
  }
  return cur;
}
static void stats(const char* tag, bool done, const TopoDS_Shape& res)
{
  if (!done || res.IsNull()) { printf("STATUS %s declined\n", tag); return; }
  int nf = 0, sol = 0, sh = 0, freeE = 0, nm = 0;
  for (TopExp_Explorer e(res, TopAbs_FACE); e.More(); e.Next()) ++nf;
  for (TopExp_Explorer e(res, TopAbs_SOLID); e.More(); e.Next()) ++sol;
  for (TopExp_Explorer e(res, TopAbs_SHELL); e.More(); e.Next()) ++sh;
  TopTools_IndexedDataMapOfShapeListOfShape em; TopExp::MapShapesAndAncestors(res, TopAbs_EDGE, TopAbs_FACE, em);
  for (int i = 1; i <= em.Extent(); ++i)
  {
    if (BRep_Tool::Degenerated(TopoDS::Edge(em.FindKey(i)))) continue;
    int n = em.FindFromIndex(i).Extent(); if (n < 2) ++freeE; else if (n > 2) ++nm;
  }
  printf("STATUS %s done valid=%d vol=%.9f faces=%d solids=%d shells=%d free=%d nonmanifold=%d\n", tag, (int)BRepCheck_Analyzer(res).IsValid(), volume(res), nf, sol, sh, freeE, nm);
  fflush(stdout);
}
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
  for (TopExp_Explorer ex(s, TopAbs_EDGE); ex.More(); ex.Next())
  {
    BRepAdaptor_Curve c(TopoDS::Edge(ex.Current())); GCPnts_QuasiUniformDeflection d(c, 0.01);
    if (!d.IsDone()) continue;
    for (int i = 1; i < d.NbPoints(); ++i) { gp_Pnt a = d.Value(i), b = d.Value(i + 1); printf("E %.6f %.6f %.6f %.6f %.6f %.6f r\n", a.X(), a.Y(), a.Z(), b.X(), b.Y(), b.Z()); }
  }
}
int main(int argc, char** argv)
{
  signal(SIGSEGV, onSig); signal(SIGBUS, onSig); signal(SIGABRT, onSig);
  std::string mode = argv[1];
  TopoDS_Shape base = makeBase(argv[2]);
  std::vector<std::string> edges, items; bool inItems = false;
  for (int i = 3; i < argc; ++i) { if (!strcmp(argv[i], "--")) { inItems = true; continue; } (inItems ? items : edges).push_back(argv[i]); }
  TopoDS_Shape kres, rres; bool kdone = false;
  try
  {
    if (mode != "ref")
    {
      BRepFilletAPI_MakeFillet mk(base);
      for (auto& e : edges) { double q; char buf[200]; sscanf(e.c_str(), "%lf:%199s", &q, buf); mk.Add(q, nearest(base, vec3(buf))); }
      mk.Build();
      kdone = mk.IsDone(); if (kdone) kres = mk.Shape();
    }
    if (mode != "fillet") rres = buildRef(base, items);
  }
  catch (Standard_Failure& f) { printf("STATUS exception %s\n", f.GetMessageString()); return 0; }
  catch (...) { printf("STATUS exception unknown\n"); return 0; }
  if (mode == "fillet") { stats("kernel", kdone, kres); if (kdone && !getenv("NOMESH")) dumpMesh(kres); }
  else if (mode == "ref") { stats("ref", true, rres); dumpMesh(rres); }
  else
  {
    stats("kernel", kdone, kres); stats("ref", true, rres);
    if (kdone && BRepCheck_Analyzer(kres).IsValid())
    {
      try
      {
        BRepAlgoAPI_Cut a(kres, rres); a.Build(); BRepAlgoAPI_Cut b(rres, kres); b.Build();
        printf("DIFF kernel_minus_ref=%.9f ref_minus_kernel=%.9f\n", a.IsDone() ? volume(a.Shape()) : -1., b.IsDone() ? volume(b.Shape()) : -1.);
      }
      catch (...) { printf("DIFF failed\n"); }
    }
  }
  return 0;
}
