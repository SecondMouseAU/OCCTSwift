// Raw-OCCT probe for the fillet and chamfer comb (branch fix/fillet-comb-chamfer). One process per case: a kernel crash is
// uncatchable and the driver puts a timeout on the process.
//
//   cprobe list  SHAPE                      edges and faces: index, bounding-box centre, type, length or area, normal
//   cprobe run   SHAPE OP [+ OP ...]        apply the ops one after the other; one RESULT line (done valid solids faces vol ms)
//   cprobe mesh  SHAPE OP [+ OP ...]        as run, then STATUS and T / E lines for the renderer (render_chamfer.py)
//   cprobe brep  SHAPE out.brep             write the input shape (the Swift cross-check loads it)
//   cprobe profile L S x z  L x z ...       the REFERENCE: a polygon in the XZ plane extruded L along +Y (no fillet or chamfer code)
//
// SHAPE  box:dx,dy,dz (corner at the origin)          cyl:R,H (axis Z, base at the origin)
//        plate:dx,dy,dz,R (a hole of radius R through the middle, axis Z)
//        poly:H;x,y;x,y;... (polygon in XY extruded H along Z)      brep:path
// EDGE   x,y,z   the edge whose bounding-box centre is nearest         FACE   x,y,z   likewise for faces
// OP     fillet R EDGE...                one builder, Add(R, e) per edge (Shape.filleted(edges:radius:))
//        fillet_each R EDGE...           one builder per edge, each on the previous result
//        fillet_all R                    every edge (Shape.filleted(radius:))
//        chamfer_all D                   every edge, Add(D, e) (Shape.chamfered(distance:))
//        chamfer_sym D EDGE...           Add(D, e)
//        chamfer2 D1 D2 EDGE@FACE...     Add(D1, D2, e, f) (Shape.chamferedTwoDistances)
//        chamferda D ANG EDGE@FACE...    AddDA(D, ANG degrees, e, f) (Shape.chamferedDistAngle)
//        chamfer2m D1:D2:EDGE@FACE...    one builder, its own (D1, D2) per edge       chamfer_dam D:ANG:EDGE@FACE...  likewise with angles
//   "+" separates ops; each works on the result of the one before. The edge and face are re-resolved on that result.
// Guard: occtBlendResultIsValid is BRepCheck_Analyzer::IsValid on the result (plus pcurve-only / surfaceless checks that a
// builder result never trips), so guard=1 is done && valid.
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <Bnd_Box.hxx>
#include <GCPnts_QuasiUniformDeflection.hxx>
#include <GProp_GProps.hxx>
#include <NCollection_IndexedMap.hxx>
#include <NCollection_IndexedDataMap.hxx>
#include <Poly_Triangulation.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopLoc_Location.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Ax2.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>
#include <chrono>
#include <cmath>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <unistd.h>
#include <vector>

typedef NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher> ShapeMap;

static void onSig(int s)
{
  printf("RESULT done=SIGNAL%d valid=0 solids=0 faces=0 vol=0 ms=0\n", s);
  fflush(stdout);
  _exit(100 + s % 100);
}

static std::vector<std::string> split(const std::string& s, char c)
{
  std::vector<std::string> out;
  std::string cur;
  for (char ch : s)
  {
    if (ch == c) { out.push_back(cur); cur.clear(); }
    else cur += ch;
  }
  out.push_back(cur);
  return out;
}

static gp_Pnt parsePnt(const std::string& s)
{
  double x = 0, y = 0, z = 0;
  sscanf(s.c_str(), "%lf,%lf,%lf", &x, &y, &z);
  return gp_Pnt(x, y, z);
}

static TopoDS_Shape makeShape(const std::string& spec)
{
  size_t k = spec.find(':');
  std::string kind = spec.substr(0, k), arg = spec.substr(k + 1);
  if (kind == "box")
  {
    double a, b, c;
    sscanf(arg.c_str(), "%lf,%lf,%lf", &a, &b, &c);
    return BRepPrimAPI_MakeBox(a, b, c).Shape();
  }
  if (kind == "cyl")
  {
    double r, h;
    sscanf(arg.c_str(), "%lf,%lf", &r, &h);
    return BRepPrimAPI_MakeCylinder(r, h).Shape();
  }
  if (kind == "plate")
  {
    double a, b, c, r;
    sscanf(arg.c_str(), "%lf,%lf,%lf,%lf", &a, &b, &c, &r);
    TopoDS_Shape box = BRepPrimAPI_MakeBox(a, b, c).Shape();
    TopoDS_Shape hole = BRepPrimAPI_MakeCylinder(gp_Ax2(gp_Pnt(a / 2, b / 2, -1), gp::DZ()), r, c + 2).Shape();
    return BRepAlgoAPI_Cut(box, hole).Shape();
  }
  if (kind == "poly")
  {
    std::vector<std::string> parts = split(arg, ';');
    double h = atof(parts[0].c_str());
    BRepBuilderAPI_MakePolygon poly;
    for (size_t i = 1; i < parts.size(); ++i)
    {
      double x, y;
      sscanf(parts[i].c_str(), "%lf,%lf", &x, &y);
      poly.Add(gp_Pnt(x, y, 0));
    }
    poly.Close();
    return BRepPrimAPI_MakePrism(BRepBuilderAPI_MakeFace(poly.Wire(), true).Face(), gp_Vec(0, 0, h)).Shape();
  }
  if (kind == "brep")
  {
    TopoDS_Shape s;
    BRep_Builder bb;
    BRepTools::Read(s, arg.c_str(), bb);
    return s;
  }
  fprintf(stderr, "bad shape %s\n", spec.c_str());
  exit(2);
}

static gp_Pnt bboxCentre(const TopoDS_Shape& s)
{
  Bnd_Box b;
  BRepBndLib::Add(s, b);
  double a0, a1, a2, b0, b1, b2;
  b.Get(a0, a1, a2, b0, b1, b2);
  return gp_Pnt((a0 + b0) / 2, (a1 + b1) / 2, (a2 + b2) / 2);
}

static TopoDS_Shape nearestSub(const TopoDS_Shape& sh, TopAbs_ShapeEnum t, const gp_Pnt& p)
{
  ShapeMap m;
  TopExp::MapShapes(sh, t, m);
  double best = 1e300;
  TopoDS_Shape be;
  for (int i = 1; i <= m.Extent(); ++i)
  {
    double d = bboxCentre(m(i)).SquareDistance(p);
    if (d < best) { best = d; be = m(i); }
  }
  return be;
}

static void listShape(const TopoDS_Shape& s)
{
  ShapeMap em, fm;
  TopExp::MapShapes(s, TopAbs_EDGE, em);
  TopExp::MapShapes(s, TopAbs_FACE, fm);
  for (int i = 1; i <= em.Extent(); ++i)
  {
    BRepAdaptor_Curve c(TopoDS::Edge(em(i)));
    GProp_GProps p;
    BRepGProp::LinearProperties(em(i), p);
    gp_Pnt m = bboxCentre(em(i));
    printf("E %d %.9f %.9f %.9f type=%d len=%.9f\n", i - 1, m.X(), m.Y(), m.Z(), (int)c.GetType(), p.Mass());
  }
  for (int i = 1; i <= fm.Extent(); ++i)
  {
    BRepAdaptor_Surface su(TopoDS::Face(fm(i)));
    GProp_GProps p;
    BRepGProp::SurfaceProperties(fm(i), p);
    gp_Pnt m = bboxCentre(fm(i));
    double nx = 0, ny = 0, nz = 0;
    if (su.GetType() == GeomAbs_Plane)
    {
      gp_Dir n = su.Plane().Axis().Direction();
      if (fm(i).Orientation() == TopAbs_REVERSED) n.Reverse();
      nx = n.X(); ny = n.Y(); nz = n.Z();
    }
    printf("F %d %.9f %.9f %.9f type=%d area=%.9f n=%.6f,%.6f,%.6f\n", i - 1, m.X(), m.Y(), m.Z(), (int)su.GetType(), p.Mass(), nx, ny, nz);
  }
}

struct Outcome
{
  bool done = false;
  std::string note;
  TopoDS_Shape shape;
};

static Outcome applyOp(const TopoDS_Shape& in, const std::vector<std::string>& op)
{
  Outcome o;
  const std::string& k = op[0];
  try
  {
    if (k == "fillet" || k == "fillet_all")
    {
      double r = atof(op[1].c_str());
      BRepFilletAPI_MakeFillet mk(in);
      if (k == "fillet_all")
        for (TopExp_Explorer ex(in, TopAbs_EDGE); ex.More(); ex.Next()) mk.Add(r, TopoDS::Edge(ex.Current()));
      else
        for (size_t i = 2; i < op.size(); ++i) mk.Add(r, TopoDS::Edge(nearestSub(in, TopAbs_EDGE, parsePnt(op[i]))));
      mk.Build();
      o.done = mk.IsDone();
      if (o.done) o.shape = mk.Shape();
      else o.note = "faultyContours=" + std::to_string(mk.NbFaultyContours());
    }
    else if (k == "fillet_each")
    {
      double r = atof(op[1].c_str());
      TopoDS_Shape cur = in;
      o.done = true;
      for (size_t i = 2; i < op.size(); ++i)
      {
        BRepFilletAPI_MakeFillet mk(cur);
        mk.Add(r, TopoDS::Edge(nearestSub(cur, TopAbs_EDGE, parsePnt(op[i]))));
        mk.Build();
        if (!mk.IsDone()) { o.done = false; o.note = "step " + std::to_string(i - 1) + " declined"; break; }
        cur = mk.Shape();
      }
      if (o.done) o.shape = cur;
    }
    else
    {
      BRepFilletAPI_MakeChamfer mk(in);
      if (k == "chamfer_all")
      {
        double d = atof(op[1].c_str());
        for (TopExp_Explorer ex(in, TopAbs_EDGE); ex.More(); ex.Next()) mk.Add(d, TopoDS::Edge(ex.Current()));
      }
      else if (k == "chamfer_sym")
      {
        double d = atof(op[1].c_str());
        for (size_t i = 2; i < op.size(); ++i) mk.Add(d, TopoDS::Edge(nearestSub(in, TopAbs_EDGE, parsePnt(op[i]))));
      }
      else if (k == "chamfer2" || k == "chamferda")
      {
        double d1 = atof(op[1].c_str()), d2 = atof(op[2].c_str());
        for (size_t i = 3; i < op.size(); ++i)
        {
          std::vector<std::string> ef = split(op[i], '@');
          TopoDS_Edge e = TopoDS::Edge(nearestSub(in, TopAbs_EDGE, parsePnt(ef[0])));
          TopoDS_Face f = TopoDS::Face(nearestSub(in, TopAbs_FACE, parsePnt(ef[1])));
          if (k == "chamfer2") mk.Add(d1, d2, e, f);
          else mk.AddDA(d1, d2 * M_PI / 180.0, e, f);
        }
      }
      else if (k == "chamfer2m" || k == "chamfer_dam")
      {
        // one builder, a (D1:D2|ANG:EDGE@FACE) triple per edge
        for (size_t i = 1; i < op.size(); ++i)
        {
          std::vector<std::string> t = split(op[i], ':');
          std::vector<std::string> ef = split(t[2], '@');
          double a = atof(t[0].c_str()), b = atof(t[1].c_str());
          TopoDS_Edge e = TopoDS::Edge(nearestSub(in, TopAbs_EDGE, parsePnt(ef[0])));
          TopoDS_Face f = TopoDS::Face(nearestSub(in, TopAbs_FACE, parsePnt(ef[1])));
          if (k == "chamfer2m") mk.Add(a, b, e, f);
          else mk.AddDA(a, b * M_PI / 180.0, e, f);
        }
      }
      else { o.note = "bad op"; return o; }
      mk.Build();
      o.done = mk.IsDone();
      if (o.done) o.shape = mk.Shape();
    }
  }
  catch (Standard_Failure const& e)
  {
    o.done = false;
    o.note = std::string("EXC ") + e.GetMessageString();
  }
  catch (...)
  {
    o.done = false;
    o.note = "EXC";
  }
  return o;
}

static void dumpMesh(const TopoDS_Shape& s)
{
  BRepMesh_IncrementalMesh(s, 0.02, false, 0.2, false);
  ShapeMap faces;
  TopExp::MapShapes(s, TopAbs_FACE, faces);
  for (int fi = 1; fi <= faces.Extent(); ++fi)
  {
    TopoDS_Face f = TopoDS::Face(faces(fi));
    TopLoc_Location loc;
    occ::handle<Poly_Triangulation> t = BRep_Tool::Triangulation(f, loc);
    if (t.IsNull()) continue;
    bool rev = f.Orientation() == TopAbs_REVERSED;
    for (int i = 1; i <= t->NbTriangles(); ++i)
    {
      int a, b, c;
      t->Triangle(i).Get(a, b, c);
      if (rev) std::swap(b, c);
      gp_Pnt p[3] = {t->Node(a).Transformed(loc), t->Node(b).Transformed(loc), t->Node(c).Transformed(loc)};
      printf("T");
      for (auto& q : p) printf(" %.6f %.6f %.6f", q.X(), q.Y(), q.Z());
      printf(" %d\n", fi);
    }
  }
}

static void dumpEdge(const TopoDS_Edge& e)
{
  BRepAdaptor_Curve c(e);
  GCPnts_QuasiUniformDeflection d(c, 0.01);
  if (!d.IsDone()) return;
  for (int i = 1; i < d.NbPoints(); ++i)
  {
    gp_Pnt a = d.Value(i), b = d.Value(i + 1);
    printf("E %.6f %.6f %.6f %.6f %.6f %.6f r\n", a.X(), a.Y(), a.Z(), b.X(), b.Y(), b.Z());
  }
}

int main(int argc, char** argv)
{
  signal(SIGSEGV, onSig); signal(SIGBUS, onSig); signal(SIGABRT, onSig); signal(SIGFPE, onSig);
  if (argc < 3) return 2;
  std::string mode = argv[1];
  if (mode == "profile")
  {
    double L = atof(argv[2]);
    int i = 3;
    BRepBuilderAPI_MakePolygon poly;
    while (i < argc)
    {
      std::string t = argv[i];
      if (t == "S" || t == "L") { poly.Add(gp_Pnt(atof(argv[i + 1]), 0, atof(argv[i + 2]))); i += 3; }
      else return 1;
    }
    poly.Close();
    TopoDS_Shape res = BRepPrimAPI_MakePrism(BRepBuilderAPI_MakeFace(poly.Wire(), true).Face(), gp_Vec(0, L, 0)).Shape();
    GProp_GProps p;
    BRepGProp::VolumeProperties(res, p);
    if (p.Mass() < 0) { res.Reverse(); p = GProp_GProps(); BRepGProp::VolumeProperties(res, p); }
    int nf = 0;
    for (TopExp_Explorer ex(res, TopAbs_FACE); ex.More(); ex.Next()) ++nf;
    printf("STATUS valid=%d vol=%.9f faces=%d\n", (int)BRepCheck_Analyzer(res).IsValid(), p.Mass(), nf);
    dumpMesh(res);
    for (TopExp_Explorer ex(res, TopAbs_EDGE); ex.More(); ex.Next()) dumpEdge(TopoDS::Edge(ex.Current()));
    return 0;
  }
  TopoDS_Shape shape = makeShape(argv[2]);
  if (mode == "list") { listShape(shape); return 0; }
  if (mode == "brep") { BRepTools::Write(shape, argv[3]); return 0; }
  std::vector<std::vector<std::string>> ops(1);
  for (int i = 3; i < argc; ++i)
  {
    if (std::string(argv[i]) == "+") ops.emplace_back();
    else ops.back().push_back(argv[i]);
  }
  auto t0 = std::chrono::steady_clock::now();
  TopoDS_Shape cur = shape;
  bool done = true;
  std::string note;
  for (auto& op : ops)
  {
    Outcome o = applyOp(cur, op);
    if (!o.done) { done = false; note = o.note; break; }
    cur = o.shape;
  }
  double ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - t0).count();
  if (!done)
  {
    printf("RESULT done=0 valid=0 solids=0 faces=0 vol=0 ms=%.0f note=%s\n", ms, note.empty() ? "-" : note.c_str());
    return 0;
  }
  int valid = 0, solids = 0, faces = 0;
  double vol = 0;
  try
  {
    valid = BRepCheck_Analyzer(cur).IsValid() ? 1 : 0;
    for (TopExp_Explorer ex(cur, TopAbs_SOLID); ex.More(); ex.Next()) ++solids;
    for (TopExp_Explorer ex(cur, TopAbs_FACE); ex.More(); ex.Next()) ++faces;
    GProp_GProps p;
    BRepGProp::VolumeProperties(cur, p);
    vol = p.Mass();
  }
  catch (...) { note = "CHECK-EXC"; }
  printf("RESULT done=1 valid=%d solids=%d faces=%d vol=%.9f ms=%.0f note=%s\n", valid, solids, faces, vol, ms, note.empty() ? "-" : note.c_str());
  if (mode == "mesh")
  {
    printf("STATUS valid=%d vol=%.9f faces=%d\n", valid, vol, faces);
    dumpMesh(cur);
    for (TopExp_Explorer ex(cur, TopAbs_EDGE); ex.More(); ex.Next()) dumpEdge(TopoDS::Edge(ex.Current()));
  }
  return 0;
}
