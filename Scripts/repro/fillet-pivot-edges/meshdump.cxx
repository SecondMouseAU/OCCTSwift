// Tessellate a shape and write it as text for the SVG renderer (render.py). Output lines:
//   T x1 y1 z1 x2 y2 z2 x3 y3 z3 <face index>      one triangle (outward orientation)
//   E x1 y1 z1 x2 y2 z2 [<tag>]                      one segment of an edge polyline
// Modes:
//   meshdump kernel dx dy dz mode R:mx,my,mz [...]   corner-origin box, those edges filleted (radius R each, mode add or seq); writes FAIL if
//                                                    IsDone() is false, otherwise "STATUS valid=<0|1> vol=<v> faces=<n>" then T and E lines
//   meshdump profile L start x z  [L x z | A mx mz x z ...]   the REFERENCE construction: the analytic section (lines and exact arcs through a
//                                                    middle point, in the XZ plane) extruded L along Y; same output. Not part of the patch.
//   meshdump brep file.brep [drawEdge ...]           a BREP; the named DRAW-numbered edges are written as tagged E lines
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <gp_Vec.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepBndLib.hxx>
#include <BRep_Tool.hxx>
#include <BRep_Builder.hxx>
#include <BRepTools.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <GCPnts_QuasiUniformDeflection.hxx>
#include <Poly_Triangulation.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopLoc_Location.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <NCollection_IndexedMap.hxx>
#include <NCollection_Map.hxx>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
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
  std::string mode = argv[1];
  if (mode == "kernel")
  {
    double dx = atof(argv[2]), dy = atof(argv[3]), dz = atof(argv[4]);
    std::string how = argv[5];
    TopoDS_Shape box = BRepPrimAPI_MakeBox(dx, dy, dz).Shape();
    TopoDS_Shape res;
    try
    {
      if (how == "seq")
      {
        res = box;
        for (int i = 6; i < argc; ++i)
        {
          double q, a, b, c; sscanf(argv[i], "%lf:%lf,%lf,%lf", &q, &a, &b, &c);
          BRepFilletAPI_MakeFillet mk(res); mk.Add(q, nearest(res, a, b, c)); mk.Build();
          if (!mk.IsDone()) { printf("FAIL\n"); return 0; }
          res = mk.Shape();
        }
      }
      else
      {
        BRepFilletAPI_MakeFillet mk(box);
        for (int i = 6; i < argc; ++i) { double q, a, b, c; sscanf(argv[i], "%lf:%lf,%lf,%lf", &q, &a, &b, &c); mk.Add(q, nearest(box, a, b, c)); }
        mk.Build();
        if (!mk.IsDone()) { printf("FAIL\n"); return 0; }
        res = mk.Shape();
      }
    }
    catch (...) { printf("FAIL\n"); return 0; }
    GProp_GProps p; BRepGProp::VolumeProperties(res, p);
    int nf = 0; for (TopExp_Explorer ex(res, TopAbs_FACE); ex.More(); ex.Next()) ++nf;
    printf("STATUS valid=%d vol=%.9f faces=%d\n", (int)BRepCheck_Analyzer(res).IsValid(), p.Mass(), nf);
    dumpMesh(res);
    for (TopExp_Explorer ex(res, TopAbs_EDGE); ex.More(); ex.Next()) dumpEdge(TopoDS::Edge(ex.Current()), "r");
    return 0;
  }
  if (mode == "profile")
  {
    double L = atof(argv[2]);
    int i = 3; BRepBuilderAPI_MakeWire wire; gp_Pnt cur, first; bool have = false;
    while (i < argc)
    {
      std::string t = argv[i];
      if (t == "S") { cur = first = gp_Pnt(atof(argv[i + 1]), 0, atof(argv[i + 2])); have = true; i += 3; }
      else if (t == "L") { gp_Pnt n(atof(argv[i + 1]), 0, atof(argv[i + 2])); if (cur.Distance(n) > 1e-9) wire.Add(BRepBuilderAPI_MakeEdge(cur, n).Edge()); cur = n; i += 3; }
      else if (t == "A") { gp_Pnt m(atof(argv[i + 1]), 0, atof(argv[i + 2])), n(atof(argv[i + 3]), 0, atof(argv[i + 4])); wire.Add(BRepBuilderAPI_MakeEdge(GC_MakeArcOfCircle(cur, m, n).Value()).Edge()); cur = n; i += 5; }
      else return 1;
    }
    if (cur.Distance(first) > 1e-9) wire.Add(BRepBuilderAPI_MakeEdge(cur, first).Edge());
    TopoDS_Shape res = BRepPrimAPI_MakePrism(BRepBuilderAPI_MakeFace(wire.Wire(), true).Face(), gp_Vec(0, L, 0)).Shape();
    GProp_GProps p; BRepGProp::VolumeProperties(res, p);
    if (p.Mass() < 0) { res.Reverse(); p = GProp_GProps(); BRepGProp::VolumeProperties(res, p); }
    int nf = 0; for (TopExp_Explorer ex(res, TopAbs_FACE); ex.More(); ex.Next()) ++nf;
    printf("STATUS valid=%d vol=%.9f faces=%d\n", (int)BRepCheck_Analyzer(res).IsValid(), p.Mass(), nf);
    dumpMesh(res);
    for (TopExp_Explorer ex(res, TopAbs_EDGE); ex.More(); ex.Next()) dumpEdge(TopoDS::Edge(ex.Current()), "r");
    return 0;
  }
  TopoDS_Shape s; BRep_Builder bb; BRepTools::Read(s, argv[2], bb);
  dumpMesh(s);
  NCollection_Map<TopoDS_Shape, TopTools_ShapeMapHasher> seen; seen.Add(s);
  std::vector<TopoDS_Edge> byNum(1);
  for (TopExp_Explorer ex(s, TopAbs_EDGE); ex.More(); ex.Next()) if (seen.Add(ex.Current())) byNum.push_back(TopoDS::Edge(ex.Current()));
  for (int i = 3; i < argc; ++i) { int n = atoi(argv[i]); if (n > 0 && n < (int)byNum.size()) dumpEdge(byNum[n], argv[i]); }
}
