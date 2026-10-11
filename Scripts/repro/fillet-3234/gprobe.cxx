// Raw-OCCT probe for #3234: BRepFilletAPI_MakeFillet on a prism or a solid of revolution built from a section.
//
//   gprobe <prism L | revolve> <path> -- <add|seq> R:x,y,z [R:x,y,z ...]      fillet; each edge named by a point ON it
//   gprobe <prism L | revolve> <path> -- ref                                   the section itself, no fillet (the REFERENCE)
//
// path (XZ plane, y = 0, closed back to the start): S x z | L x z | A mx mz x z (arc through mid to end).
// prism L: the section extruded L along +Y.  revolve: the section turned 360 degrees about the Z axis (x is the radius).
// Prints one "RESULT ..." line (done, faulty, BRepCheck valid, volume, faces, solids, free and non-manifold edges, mesh ok).
// MESH=1 also prints the tessellation for the renderer: "T x1 y1 z1 x2 y2 z2 x3 y3 z3 <face>" and "E x1 y1 z1 x2 y2 z2 r".
// DUMP=1 prints one line per face with its surface type. One process per case: a fillet may crash uncatchably.
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepPrimAPI_MakeRevol.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <GCPnts_QuasiUniformDeflection.hxx>
#include <Poly_Triangulation.hxx>
#include <BRep_Tool.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopLoc_Location.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
#include <NCollection_IndexedMap.hxx>
#include <Standard_Failure.hxx>
#include <gp_Ax1.hxx>
#include <gp_Dir.hxx>
#include <gp_Vec.hxx>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <csignal>
#include <string>
#include <vector>
#include <unistd.h>

static void onSig(int s) { printf("RESULT SIGNAL %d\n", s); fflush(stdout); _exit(100 + s % 100); }

static TopoDS_Edge pick(const TopoDS_Shape& sh, double x, double y, double z)
{
  TopoDS_Vertex v = BRepBuilderAPI_MakeVertex(gp_Pnt(x, y, z));
  NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher> edges;
  TopExp::MapShapes(sh, TopAbs_EDGE, edges);
  double best = 1e300; TopoDS_Edge be;
  for (int i = 1; i <= edges.Extent(); ++i)
  {
    BRepExtrema_DistShapeShape d(v, edges(i));
    if (d.IsDone() && d.Value() < best) { best = d.Value(); be = TopoDS::Edge(edges(i)); }
  }
  return be;
}

static void dumpMesh(const TopoDS_Shape& s)
{
  BRepMesh_IncrementalMesh(s, getenv("DEFL") ? atof(getenv("DEFL")) : 0.01, false, getenv("ANG") ? atof(getenv("ANG")) : 0.15, false);
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
    BRepAdaptor_Curve c(TopoDS::Edge(ex.Current()));
    if (BRep_Tool::Degenerated(TopoDS::Edge(ex.Current()))) continue;
    GCPnts_QuasiUniformDeflection d(c, 0.01);
    if (!d.IsDone()) continue;
    for (int i = 1; i < d.NbPoints(); ++i) { gp_Pnt a = d.Value(i), b = d.Value(i + 1); printf("E %.6f %.6f %.6f %.6f %.6f %.6f r\n", a.X(), a.Y(), a.Z(), b.X(), b.Y(), b.Z()); }
  }
}

static void report(bool done, int faulty, const TopoDS_Shape& res)
{
  bool valid = false; double vol = -1; int nf = 0, ns = 0, freeE = 0, nonMan = 0, meshBad = -1;
  if (!res.IsNull())
  {
    valid = BRepCheck_Analyzer(res).IsValid();
    GProp_GProps p; BRepGProp::VolumeProperties(res, p); vol = p.Mass();
    for (TopExp_Explorer e(res, TopAbs_FACE); e.More(); e.Next()) ++nf;
    for (TopExp_Explorer e(res, TopAbs_SOLID); e.More(); e.Next()) ++ns;
    TopTools_IndexedDataMapOfShapeListOfShape em; TopExp::MapShapesAndAncestors(res, TopAbs_EDGE, TopAbs_FACE, em);
    for (int i = 1; i <= em.Extent(); ++i)
    {
      if (BRep_Tool::Degenerated(TopoDS::Edge(em.FindKey(i)))) continue;
      int n = em.FindFromIndex(i).Extent(); if (n < 2) ++freeE; else if (n > 2) ++nonMan;
    }
    BRepMesh_IncrementalMesh m(res, 0.05); meshBad = 0;
    for (TopExp_Explorer e(res, TopAbs_FACE); e.More(); e.Next()) { TopLoc_Location l; if (BRep_Tool::Triangulation(TopoDS::Face(e.Current()), l).IsNull()) ++meshBad; }
  }
  printf("RESULT done=%d faulty=%d valid=%d vol=%.12g faces=%d solids=%d free=%d nonman=%d meshbad=%d\n", (int)done, faulty, (int)valid, vol, nf, ns, freeE, nonMan, meshBad);
  if (!res.IsNull() && getenv("DUMP"))
  {
    int i = 0;
    for (TopExp_Explorer e(res, TopAbs_FACE); e.More(); e.Next(), ++i)
    {
      BRepAdaptor_Surface s(TopoDS::Face(e.Current())); GProp_GProps p; BRepGProp::SurfaceProperties(TopoDS::Face(e.Current()), p);
      printf("  face %d type=%d area=%.6f\n", i, (int)s.GetType(), p.Mass());
    }
  }
  if (!res.IsNull() && getenv("MESH")) dumpMesh(res);
}

int main(int argc, char** argv)
{
  signal(SIGSEGV, onSig); signal(SIGBUS, onSig); signal(SIGABRT, onSig);
  std::string kind = argv[1]; int i = 2; double L = 0;
  if (kind == "prism") L = atof(argv[i++]);
  BRepBuilderAPI_MakeWire wire; gp_Pnt cur, first;
  for (; i < argc && strcmp(argv[i], "--"); )
  {
    std::string t = argv[i];
    if (t == "S") { cur = first = gp_Pnt(atof(argv[i + 1]), 0, atof(argv[i + 2])); i += 3; }
    else if (t == "L") { gp_Pnt n(atof(argv[i + 1]), 0, atof(argv[i + 2])); if (cur.Distance(n) > 1e-9) wire.Add(BRepBuilderAPI_MakeEdge(cur, n).Edge()); cur = n; i += 3; }
    else if (t == "A") { gp_Pnt m(atof(argv[i + 1]), 0, atof(argv[i + 2])), n(atof(argv[i + 3]), 0, atof(argv[i + 4])); wire.Add(BRepBuilderAPI_MakeEdge(GC_MakeArcOfCircle(cur, m, n).Value()).Edge()); cur = n; i += 5; }
    else return 2;
  }
  if (cur.Distance(first) > 1e-9) wire.Add(BRepBuilderAPI_MakeEdge(cur, first).Edge());
  ++i;                                           // past "--"
  std::string mode = argv[i++];
  TopoDS_Shape solid;
  BRepBuilderAPI_MakeFace mf(wire.Wire(), true);
  if (kind == "prism") solid = BRepPrimAPI_MakePrism(mf.Face(), gp_Vec(0, L, 0)).Shape();
  else solid = BRepPrimAPI_MakeRevol(mf.Face(), gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1))).Shape();
  { GProp_GProps p; BRepGProp::VolumeProperties(solid, p); if (p.Mass() < 0) solid.Reverse(); }
  if (mode == "ref") { report(true, 0, solid); return 0; }
  std::vector<double> rr; std::vector<gp_Pnt> pts;
  for (; i < argc; ++i)
  {
    double q, a, b, c; sscanf(argv[i], "%lf:%lf,%lf,%lf", &q, &a, &b, &c); rr.push_back(q); pts.push_back(gp_Pnt(a, b, c));
  }
  try
  {
    if (mode == "seq")
    {
      TopoDS_Shape cur2 = solid;
      for (size_t k = 0; k < rr.size(); ++k)
      {
        BRepFilletAPI_MakeFillet mk(cur2); mk.Add(rr[k], pick(cur2, pts[k].X(), pts[k].Y(), pts[k].Z())); mk.Build();
        if (!mk.IsDone()) { printf("(seq step %zu declined)\n", k); report(false, mk.NbFaultyContours(), TopoDS_Shape()); return 0; }
        cur2 = mk.Shape();
      }
      report(true, 0, cur2); return 0;
    }
    BRepFilletAPI_MakeFillet mk(solid);
    for (size_t k = 0; k < rr.size(); ++k) mk.Add(rr[k], pick(solid, pts[k].X(), pts[k].Y(), pts[k].Z()));
    mk.Build();
    TopoDS_Shape res; if (mk.IsDone()) res = mk.Shape();
    report(mk.IsDone(), mk.NbFaultyContours(), res);
  }
  catch (Standard_Failure& f) { printf("RESULT exception %s\n", f.GetMessageString()); }
  catch (...) { printf("RESULT exception unknown\n"); }
  return 0;
}
