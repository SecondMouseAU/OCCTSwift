// Tessellate a shape and write it as text for the SVG renderer (render.py). Output lines:
//   T x1 y1 z1 x2 y2 z2 x3 y3 z3 <face index>      one triangle (outward orientation)
//   E x1 y1 z1 x2 y2 z2 [<tag>]                      one segment of an edge polyline
// Modes:
//   meshdump fillet dx dy dz r mx,my,mz [...]   corner-origin box, those edges filleted in one builder; writes FAIL if IsDone() is false
//   meshdump brep file.brep [drawEdge ...]      a BREP; the named DRAW-numbered edges are written as tagged E lines
#include <BRepFilletAPI_MakeFillet.hxx>
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
  if (mode == "fillet")
  {
    double dx = atof(argv[2]), dy = atof(argv[3]), dz = atof(argv[4]), r = atof(argv[5]);
    TopoDS_Shape box = BRepPrimAPI_MakeBox(dx, dy, dz).Shape();
    BRepFilletAPI_MakeFillet mk(box);
    for (int i = 6; i < argc; ++i) { double a, b, c; sscanf(argv[i], "%lf,%lf,%lf", &a, &b, &c); mk.Add(r, nearest(box, a, b, c)); }
    try { mk.Build(); } catch (...) { printf("FAIL\n"); return 0; }
    if (!mk.IsDone()) { printf("FAIL\n"); return 0; }
    dumpMesh(mk.Shape());
    return 0;
  }
  TopoDS_Shape s; BRep_Builder bb; BRepTools::Read(s, argv[2], bb);
  dumpMesh(s);
  NCollection_Map<TopoDS_Shape, TopTools_ShapeMapHasher> seen; seen.Add(s);
  std::vector<TopoDS_Edge> byNum(1);
  for (TopExp_Explorer ex(s, TopAbs_EDGE); ex.More(); ex.Next()) if (seen.Add(ex.Current())) byNum.push_back(TopoDS::Edge(ex.Current()));
  for (int i = 3; i < argc; ++i) { int n = atoi(argv[i]); if (n > 0 && n < (int)byNum.size()) dumpEdge(byNum[n], argv[i]); }
}
