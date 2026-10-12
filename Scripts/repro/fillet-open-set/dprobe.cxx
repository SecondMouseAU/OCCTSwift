// dprobe: replays a DRAW fillet/chamfer reproducer through the raw OCCT API, one process per case.
//   dprobe SRC OP SPEC...
// SRC  path.brep | box:dx,dy,dz | s1217:Y   (the #1217 prism, Y of the corner point)
// OP   blend r:i ...      BRepFilletAPI_MakeFillet, Add(r, edge i); i is DRAW's `explode s e` index, 1 based
//      chamf  d:i ...     BRepFilletAPI_MakeChamfer, Add(d, edge i)
//      blendall r         every edge
//      chamfall d
//      count              print the number of edges (RESULT edges=N)
//      check              the bopcheck of the input shape alone
// The fillet is set up as DRAW's `blend` does (ChFi3d_Rational, SetParams(1e-2,1e-4,1e-5,1e-4,1e-5,1e-3), SetContinuity(C1,1e-2)).
// Output: BUILD done=1 ms=N as soon as Build returns, then STAGE lines (brepcheck, volume, bopcheck) as each finishes,
// then one RESULT line (done valid bopfaults solids faces volume ms). A process killed on a timeout therefore shows which
// stage it was in. DPROBE_NOCHECK=1 stops after BUILD.
#include <BOPAlgo_ArgumentAnalyzer.hxx>
#include <BOPAlgo_CheckResult.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <Geom_BSplineCurve.hxx>
#include <GProp_GProps.hxx>
#include <NCollection_Array1.hxx>
#include <NCollection_Map.hxx>
#include <NCollection_IndexedMap.hxx>
#include <Standard_Failure.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <TopoDS.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

static std::vector<TopoDS_Shape> explodeEdges(const TopoDS_Shape& s)
{
  NCollection_Map<TopoDS_Shape, TopTools_ShapeMapHasher> seen;
  std::vector<TopoDS_Shape> out;
  seen.Add(s);
  for (TopExp_Explorer ex(s, TopAbs_EDGE); ex.More(); ex.Next())
    if (seen.Add(ex.Current())) out.push_back(ex.Current());
  return out;
}

static TopoDS_Shape s1217(double Y)
{
  auto bez = [](double x0, double y0, double x1, double y1, double x2, double y2, double x3, double y3) {
    NCollection_Array1<gp_Pnt> p(1, 4);
    p(1) = gp_Pnt(x0, y0, 0); p(2) = gp_Pnt(x1, y1, 0); p(3) = gp_Pnt(x2, y2, 0); p(4) = gp_Pnt(x3, y3, 0);
    NCollection_Array1<double> w(1, 4); w.Init(1.0);
    NCollection_Array1<double> k(1, 2); k(1) = 0; k(2) = 1;
    NCollection_Array1<int> m(1, 2); m(1) = 4; m(2) = 4;
    return BRepBuilderAPI_MakeEdge(new Geom_BSplineCurve(p, w, k, m, 3)).Edge();
  };
  TopoDS_Edge e1 = bez(73.33, -78.324136, 79.1083, -77.1377, 86.4629, -76.9095, 93.8515, Y);
  TopoDS_Edge e2 = bez(93.8515, Y, 107.14, -77.7741, 117.599, -78.5754, 125.89, -80.3085);
  BRepBuilderAPI_MakePolygon poly;
  poly.Add(gp_Pnt(125.89, -80.3085, 0)); poly.Add(gp_Pnt(125.89, -68.760604, 0));
  poly.Add(gp_Pnt(73.33, -68.760604, 0)); poly.Add(gp_Pnt(73.33, -78.324136, 0));
  BRepBuilderAPI_MakeWire w;
  w.Add(e1); w.Add(e2); w.Add(poly.Wire());
  TopoDS_Face f = BRepBuilderAPI_MakeFace(w.Wire(), true);
  return BRepPrimAPI_MakePrism(f, gp_Vec(0, 0, 20)).Shape();
}

int main(int argc, char** argv)
{
  if (argc < 3) return 2;
  std::string src = argv[1], op = argv[2];
  TopoDS_Shape in;
  if (src.rfind("box:", 0) == 0)
  {
    double a, b, c; sscanf(src.c_str() + 4, "%lf,%lf,%lf", &a, &b, &c);
    in = BRepPrimAPI_MakeBox(a, b, c).Shape();
  }
  else if (src.rfind("s1217:", 0) == 0) in = s1217(atof(src.c_str() + 6));
  else { BRep_Builder bb; if (!BRepTools::Read(in, src.c_str(), bb)) { printf("RESULT readfail\n"); return 3; } }
  std::vector<TopoDS_Shape> E = explodeEdges(in);
  if (op == "check")
  {
    auto t = std::chrono::steady_clock::now();
    BOPAlgo_ArgumentAnalyzer a; a.SetShape1(in); a.SelfInterMode() = true; a.SmallEdgeMode() = true; a.Perform();
    printf("RESULT bopcheck_of_input faults=%d ms=%.0f\n", a.HasFaulty() ? (int)a.GetCheckResult().Size() : 0,
           std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - t).count());
    return 0;
  }
  if (op == "count") { printf("RESULT edges=%d\n", (int)E.size()); return 0; }
  TopoDS_Shape res;
  bool done = false;
  auto t0 = std::chrono::steady_clock::now();
  std::string note;
  try
  {
    bool chamf = op == "chamf" || op == "chamfall";
    bool all = op == "blendall" || op == "chamfall";
    std::vector<std::pair<double, int>> sp;
    if (all) { for (size_t i = 0; i < E.size(); ++i) sp.push_back({atof(argv[3]), (int)i + 1}); }
    else for (int i = 3; i < argc; ++i)
    {
      double r; int idx; if (sscanf(argv[i], "%lf:%d", &r, &idx) != 2) return 4;
      if (idx < 1 || idx > (int)E.size()) { printf("RESULT badindex\n"); return 5; }
      sp.push_back({r, idx});
    }
    if (chamf)
    {
      BRepFilletAPI_MakeChamfer mk(in);
      for (auto& p : sp) mk.Add(p.first, TopoDS::Edge(E[p.second - 1]));
      mk.Build(); done = mk.IsDone(); if (done) res = mk.Shape();
    }
    else
    {
      BRepFilletAPI_MakeFillet mk(in, ChFi3d_Rational);
      mk.SetParams(1e-2, 1e-4, 1e-5, 1e-4, 1e-5, 1e-3);
      mk.SetContinuity(GeomAbs_C1, 1e-2);
      for (auto& p : sp) mk.Add(p.first, TopoDS::Edge(E[p.second - 1]));
      mk.Build(); done = mk.IsDone(); if (done) res = mk.Shape();
      else note = "faultyContours=" + std::to_string(mk.NbFaultyContours()) + " faultyVertices=" + std::to_string(mk.NbFaultyVertices());
    }
  }
  catch (Standard_Failure const& e) { note = std::string("EXC ") + e.GetMessageString(); }
  catch (...) { note = "EXC"; }
  double ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - t0).count();
  if (!done || res.IsNull()) { printf("RESULT done=0 %s ms=%.0f\n", note.c_str(), ms); return 0; }
  printf("BUILD done=1 ms=%.0f\n", ms); fflush(stdout);
  if (getenv("DPROBE_NOCHECK")) return 0;
  int valid = -1, faults = -1, solids = 0, faces = 0; double vol = 0;
  auto lap = [&](const char* what, std::chrono::steady_clock::time_point t) {
    printf("STAGE %s ms=%.0f\n", what, std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - t).count());
    fflush(stdout);
  };
  for (TopExp_Explorer ex(res, TopAbs_SOLID); ex.More(); ex.Next()) ++solids;
  for (TopExp_Explorer ex(res, TopAbs_FACE); ex.More(); ex.Next()) ++faces;
  { auto t = std::chrono::steady_clock::now();
    try { valid = BRepCheck_Analyzer(res).IsValid() ? 1 : 0; } catch (...) { valid = -2; }
    lap("brepcheck", t); printf("STAGE brepcheck_valid=%d solids=%d faces=%d\n", valid, solids, faces); fflush(stdout); }
  { auto t = std::chrono::steady_clock::now();
    try { GProp_GProps g; BRepGProp::VolumeProperties(res, g); vol = g.Mass(); } catch (...) {}
    lap("volume", t); }
  { auto t = std::chrono::steady_clock::now();
    try
    {
      BOPAlgo_ArgumentAnalyzer a; a.SetShape1(res);
      a.SelfInterMode() = true; a.SmallEdgeMode() = true;
      a.Perform(); faults = a.HasFaulty() ? (int)a.GetCheckResult().Size() : 0;
    } catch (...) { faults = -2; }
    lap("bopcheck", t); }
  printf("RESULT done=1 valid=%d bopfaults=%d solids=%d faces=%d vol=%.6g ms=%.0f\n", valid, faults, solids, faces, vol, ms);
  return 0;
}
