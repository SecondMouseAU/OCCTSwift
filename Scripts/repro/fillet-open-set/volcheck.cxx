// volcheck: the volume of a fillet result three ways, to tell a moved solid from a moved integral (#3336).
//   volcheck SRC.brep r:i ...      i is DRAW's `explode s e` index, 1 based, as in dprobe
// Prints, for the input and then for the BRepFilletAPI_MakeFillet result (set up as DRAW's `blend` and dprobe do):
//   fixed     BRepGProp::VolumeProperties(shape, props), the default fixed-order Gauss integration dprobe reports as vol
//   adaptive  BRepGProp::VolumeProperties(shape, props, 1e-6, false, false)
//   mesh      BRepMesh_IncrementalMesh (deflection MESHDEF, default 0.01) then a signed-tetrahedron sum over the faces
// Build it like the other programs here: build-probe.sh's clang++ line, with volcheck.cxx in place of dprobe.cxx.
// Each line also carries BRepCheck_Analyzer's verdict.
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <GProp_GProps.hxx>
#include <Poly_Triangulation.hxx>
#include <Standard_Failure.hxx>
#include <TopExp_Explorer.hxx>
#include <TopLoc_Location.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <NCollection_Map.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <cstdio>
#include <cstdlib>
#include <vector>
#include <string>

static double meshVolume(const TopoDS_Shape& s)
{
  BRepMesh_IncrementalMesh m(s, getenv("MESHDEF") ? atof(getenv("MESHDEF")) : 0.01, false, 0.1, true);
  double v = 0;
  for (TopExp_Explorer ex(s, TopAbs_FACE); ex.More(); ex.Next())
  {
    TopoDS_Face f = TopoDS::Face(ex.Current());
    TopLoc_Location loc;
    Handle(Poly_Triangulation) t = BRep_Tool::Triangulation(f, loc);
    if (t.IsNull()) continue;
    bool rev = f.Orientation() == TopAbs_REVERSED;
    for (int i = 1; i <= t->NbTriangles(); ++i)
    {
      int a, b, c; t->Triangle(i).Get(a, b, c);
      if (rev) std::swap(b, c);
      gp_Pnt p1 = t->Node(a).Transformed(loc), p2 = t->Node(b).Transformed(loc), p3 = t->Node(c).Transformed(loc);
      v += p1.XYZ().Dot(p2.XYZ().Crossed(p3.XYZ())) / 6.0;
    }
  }
  return v;
}

static void report(const char* tag, const TopoDS_Shape& s)
{
  double v1 = -1, v2 = -1, v3 = -1; int valid = -1;
  try { GProp_GProps g; BRepGProp::VolumeProperties(s, g); v1 = g.Mass(); } catch (...) {}
  try { GProp_GProps g; BRepGProp::VolumeProperties(s, g, 1e-6, false, false); v2 = g.Mass(); } catch (...) {}
  try { v3 = meshVolume(s); } catch (...) {}
  try { valid = BRepCheck_Analyzer(s).IsValid() ? 1 : 0; } catch (...) {}
  printf("%s fixed=%.6g adaptive=%.6g mesh=%.6g valid=%d\n", tag, v1, v2, v3, valid);
}

int main(int argc, char** argv)
{
  setvbuf(stdout, nullptr, _IOLBF, 0);
  TopoDS_Shape in; BRep_Builder bb;
  if (!BRepTools::Read(in, argv[1], bb)) { printf("readfail\n"); return 3; }
  report("input ", in);
  std::vector<TopoDS_Shape> E;
  { NCollection_Map<TopoDS_Shape, TopTools_ShapeMapHasher> seen; seen.Add(in);
    for (TopExp_Explorer ex(in, TopAbs_EDGE); ex.More(); ex.Next()) if (seen.Add(ex.Current())) E.push_back(ex.Current()); }
  BRepFilletAPI_MakeFillet mk(in, ChFi3d_Rational);
  mk.SetParams(1e-2, 1e-4, 1e-5, 1e-4, 1e-5, 1e-3);
  mk.SetContinuity(GeomAbs_C1, 1e-2);
  for (int i = 2; i < argc; ++i) { double r; int idx; sscanf(argv[i], "%lf:%d", &r, &idx); mk.Add(r, TopoDS::Edge(E[idx - 1])); }
  mk.Build();
  if (!mk.IsDone()) { printf("not done\n"); return 0; }
  report("result", mk.Shape());
  return 0;
}
