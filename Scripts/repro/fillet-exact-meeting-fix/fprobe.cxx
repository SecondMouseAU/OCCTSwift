// Raw-OCCT probe: BRepFilletAPI_MakeFillet on a corner-origin box, edges named by midpoint.
//   fprobe <mode> dx dy dz r mx,my,mz [mx,my,mz ...]
// mode: add  = one builder, Add(r, e) per edge, Build (the Shape.filleted path)
//       add2 = one builder, Add(r, r, e) per edge (FreeCAD's Part::Fillet call form)
//       seq  = one builder per edge, each applied to the previous result (fillet next to a finished fillet)
// One process per case: the original defect (OCCT#1568) is an uncatchable SIGSEGV.
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRepBndLib.hxx>
#include <Bnd_Box.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <NCollection_IndexedMap.hxx>
#include <Standard_Failure.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepCheck_Result.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRep_Tool.hxx>
#include <TopoDS_Face.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <ShapeFix_FixSmallFace.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
#include <BRep_Tool.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <gp_Trsf.hxx>
#include <gp_Ax1.hxx>
#include <gp_Dir.hxx>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <csignal>
#include <vector>
#include <string>
#include <unistd.h>
static void onSig(int s) { printf("RESULT SIGNAL %d\n", s); fflush(stdout); _exit(100 + s % 100); }
static TopoDS_Edge nearest(const TopoDS_Shape& sh, double x, double y, double z)
{
  NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher> edges;
  TopExp::MapShapes(sh, TopAbs_EDGE, edges);
  double best = 1e300; TopoDS_Edge be;
  for (int i = 1; i <= edges.Extent(); ++i)
  {
    Bnd_Box b; BRepBndLib::Add(edges(i), b);
    double a0, a1, a2, b0, b1, b2; b.Get(a0, a1, a2, b0, b1, b2);
    double d = pow((a0 + b0) / 2 - x, 2) + pow((a1 + b1) / 2 - y, 2) + pow((a2 + b2) / 2 - z, 2);
    if (d < best) { best = d; be = TopoDS::Edge(edges(i)); }
  }
  return be;
}
// DUMP=1: per-face surface type, area, edge count, BRepCheck verdict; MESH=1: BRepMesh_IncrementalMesh result.
static void dumpFaces(const TopoDS_Shape& res)
{
  BRepCheck_Analyzer an(res);
  int i = 0;
  for (TopExp_Explorer e(res, TopAbs_FACE); e.More(); e.Next(), ++i)
  {
    const TopoDS_Face& f = TopoDS::Face(e.Current());
    BRepAdaptor_Surface s(f);
    GProp_GProps p; BRepGProp::SurfaceProperties(f, p);
    int ne = 0; for (TopExp_Explorer x(f, TopAbs_EDGE); x.More(); x.Next()) ++ne;
    printf("  face %d type=%d area=%.6f edges=%d valid=%d orient=%d\n", i, (int)s.GetType(), p.Mass(), ne, (int)an.IsValid(f), (int)f.Orientation());
    if (getenv("DUMP") && getenv("DUMP")[0] == '2')
      for (TopExp_Explorer x(f, TopAbs_EDGE); x.More(); x.Next())
      {
        const TopoDS_Edge& ed = TopoDS::Edge(x.Current());
        double a, b; BRep_Tool::Range(ed, a, b);
        gp_Pnt p0, p1; BRepAdaptor_Curve c(ed); p0 = c.Value(c.FirstParameter()); p1 = c.Value(c.LastParameter());
        printf("      edge %p deg=%d (%.4f,%.4f,%.4f)->(%.4f,%.4f,%.4f) or=%d\n", (void*)ed.TShape().get(), (int)BRep_Tool::Degenerated(ed), p0.X(), p0.Y(), p0.Z(), p1.X(), p1.Y(), p1.Z(), (int)ed.Orientation());
      }
  }
}
static void report(const char* tag, bool done, int nfaulty, const TopoDS_Shape& res)
{
  bool valid = false; double vol = -1; int nf = 0;
  if (!res.IsNull())
  {
    valid = BRepCheck_Analyzer(res).IsValid();
    GProp_GProps p; BRepGProp::VolumeProperties(res, p); vol = p.Mass();
    for (TopExp_Explorer e(res, TopAbs_FACE); e.More(); e.Next()) ++nf;
  }
  printf("RESULT %s done=%d faulty=%d valid=%d vol=%.9f faces=%d\n", tag, (int)done, nfaulty, (int)valid, vol, nf);
  if (!res.IsNull() && getenv("DUMP")) dumpFaces(res);
  if (!res.IsNull() && getenv("CHECKS"))
  {
    // closedness: every non-degenerate edge borders exactly two faces (counting a seam twice via orientation)
    TopTools_IndexedDataMapOfShapeListOfShape em; TopExp::MapShapesAndAncestors(res, TopAbs_EDGE, TopAbs_FACE, em);
    int freeE = 0, nonManifold = 0;
    for (int i = 1; i <= em.Extent(); ++i)
    {
      if (BRep_Tool::Degenerated(TopoDS::Edge(em.FindKey(i)))) continue;
      int n = em.FindFromIndex(i).Extent();
      if (n < 2) ++freeE; else if (n > 2) ++nonManifold;
    }
    int solids = 0, shells = 0; for (TopExp_Explorer e(res, TopAbs_SOLID); e.More(); e.Next()) ++solids;
    for (TopExp_Explorer e(res, TopAbs_SHELL); e.More(); e.Next()) ++shells;
    printf("  CHECKS free_edges=%d non_manifold_edges=%d solids=%d shells=%d\n", freeE, nonManifold, solids, shells);
  }
  if (!res.IsNull() && getenv("MESH"))
  {
    BRepMesh_IncrementalMesh mesher(res, 0.01);
    int tris = 0, bad = 0;
    for (TopExp_Explorer e(res, TopAbs_FACE); e.More(); e.Next())
    {
      TopLoc_Location l; auto t = BRep_Tool::Triangulation(TopoDS::Face(e.Current()), l);
      if (t.IsNull()) ++bad; else tris += t->NbTriangles();
    }
    printf("  MESH isdone=%d faces_without_triangulation=%d triangles=%d\n", (int)mesher.IsDone(), bad, tris);
  }
}
int main(int argc, char** argv)
{
  signal(SIGSEGV, onSig); signal(SIGBUS, onSig); signal(SIGABRT, onSig);
  std::string mode = argv[1];
  double dx = atof(argv[2]), dy = atof(argv[3]), dz = atof(argv[4]), r = atof(argv[5]);
  TopoDS_Shape box = BRepPrimAPI_MakeBox(dx, dy, dz).Shape();
  if (getenv("SHAPE") && !strcmp(getenv("SHAPE"), "trap"))
  {
    // trapezoid prism: bottom side y=0 spans x 0..dx, top side y=dy spans x (dx-narrow)/2 ..; height dz.
    // The two slanted sides are not parallel, so their fillet contact lines converge.
    double narrow = atof(getenv("NARROW")), o = (dx - narrow) / 2;
    BRepBuilderAPI_MakePolygon poly; poly.Add(gp_Pnt(0, 0, 0)); poly.Add(gp_Pnt(dx, 0, 0)); poly.Add(gp_Pnt(dx - o, dy, 0)); poly.Add(gp_Pnt(o, dy, 0)); poly.Close();
    box = BRepPrimAPI_MakePrism(BRepBuilderAPI_MakeFace(poly.Wire()).Face(), gp_Vec(0, 0, dz)).Shape();
  }
  std::vector<double> m, rr;   // rr: per-edge radius; an argument "R:x,y,z" overrides r for that edge
  for (int i = 6; i < argc; ++i)
  {
    double a, b, c, q = r; const char* p = argv[i];
    if (strchr(p, ':')) { sscanf(p, "%lf:", &q); p = strchr(p, ':') + 1; }
    sscanf(p, "%lf,%lf,%lf", &a, &b, &c); m.push_back(a); m.push_back(b); m.push_back(c); rr.push_back(q);
  }
  if (getenv("ROT"))
  {
    // ROT="ax,ay,az,deg,tx,ty,tz": rotate and translate the box and the edge midpoints (exact meeting under rounding noise)
    double ax, ay, az, dg, tx, ty, tz; sscanf(getenv("ROT"), "%lf,%lf,%lf,%lf,%lf,%lf,%lf", &ax, &ay, &az, &dg, &tx, &ty, &tz);
    gp_Trsf t; t.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(ax, ay, az)), dg * M_PI / 180); t.SetTranslationPart(gp_Vec(tx, ty, tz));
    box = BRepBuilderAPI_Transform(box, t, true).Shape();
    for (size_t i = 0; i + 2 < m.size(); i += 3) { gp_Pnt p(m[i], m[i + 1], m[i + 2]); p.Transform(t); m[i] = p.X(); m[i + 1] = p.Y(); m[i + 2] = p.Z(); }
  }
  try
  {
    if (mode == "seq")
    {
      TopoDS_Shape cur = box;
      for (size_t i = 0; i + 2 < m.size() + 0 && i < m.size(); i += 3)
      {
        BRepFilletAPI_MakeFillet mk(cur);
        mk.Add(rr[i / 3], nearest(cur, m[i], m[i + 1], m[i + 2]));
        mk.Build();
        if (!mk.IsDone()) { printf("(seq step %zu failed, faulty=%d)\n", i / 3, mk.NbFaultyContours()); report("seq", false, mk.NbFaultyContours(), TopoDS_Shape()); return 0; }
        cur = mk.Shape();
      }
      report("seq", true, 0, cur);
      return 0;
    }
    if (mode == "common")
    {
      // Reference construction for r > w/2: intersect the box filleted on one edge with the box
      // filleted on the other (each alone is a legal fillet). Not part of the patch.
      TopoDS_Shape acc = box;
      TopoDS_Shape single[8]; int ns = 0;
      for (size_t i = 0; i + 2 < m.size(); i += 3)
      {
        BRepFilletAPI_MakeFillet one(box);
        one.Add(rr[i / 3], nearest(box, m[i], m[i + 1], m[i + 2]));
        one.Build();
        if (!one.IsDone()) { report("common", false, 0, TopoDS_Shape()); return 0; }
        single[ns++] = one.Shape();
      }
      acc = single[0];
      for (int i = 1; i < ns; ++i) { BRepAlgoAPI_Common cm(acc, single[i]); cm.Build(); if (!cm.IsDone()) { report("common", false, 0, TopoDS_Shape()); return 0; } acc = cm.Shape(); }
      report("common", true, 0, acc);
      return 0;
    }
    BRepFilletAPI_MakeFillet mk(box);
    for (size_t i = 0; i + 2 < m.size(); i += 3)
    {
      TopoDS_Edge e = nearest(box, m[i], m[i + 1], m[i + 2]);
      double q = rr[i / 3];
      if (mode == "add2") mk.Add(q, q, e); else mk.Add(q, e);
    }
    mk.Build();
    TopoDS_Shape res;
    if (mk.IsDone()) res = mk.Shape();
    if (mk.IsDone() && getenv("FIXSMALL"))
    {
      ShapeFix_FixSmallFace f; f.Init(res); f.SetPrecision(1e-6); f.Perform();
      TopoDS_Shape r1 = f.FixStripFace(false);
      printf("  FIXSMALL: null=%d\n", (int)r1.IsNull());
      if (!r1.IsNull()) res = r1;
    }
    report(mode.c_str(), mk.IsDone(), mk.NbFaultyContours(), res);
    if (mk.IsDone() && getenv("HIST"))
    {
      // history: for each input face Modified/IsDeleted, for each input edge Generated; are the listed faces in the result?
      NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher> inRes;
      TopExp::MapShapes(res, TopAbs_FACE, inRes);
      auto count = [&](const NCollection_List<TopoDS_Shape>& l, int& total, int& inres) { for (auto it = l.begin(); it != l.end(); ++it) { ++total; if (inRes.Contains(*it)) ++inres; } };
      NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher> fs, es;
      TopExp::MapShapes(box, TopAbs_FACE, fs); TopExp::MapShapes(box, TopAbs_EDGE, es);
      for (int i = 1; i <= fs.Extent(); ++i)
      {
        int t = 0, k = 0; count(mk.Modified(fs(i)), t, k);
        printf("  HIST face %d: deleted=%d modified=%d (of which in result %d)\n", i, (int)mk.IsDeleted(fs(i)), t, k);
      }
      for (int i = 1; i <= es.Extent(); ++i)
      {
        int t = 0, k = 0; count(mk.Generated(es(i)), t, k);
        if (t) printf("  HIST edge %d: generated=%d (of which in result %d)\n", i, t, k);
      }
    }
    printf("  stages: HasResult=%d NbFaultyContours=%d NbFaultyVertices=%d\n", (int)mk.HasResult(), mk.NbFaultyContours(), mk.NbFaultyVertices());
    for (int i = 1; i <= mk.NbFaultyContours(); ++i)
      printf("  faulty contour %d status=%d\n", mk.FaultyContour(i), (int)mk.StripeStatus(mk.FaultyContour(i)));
  }
  catch (Standard_Failure& f) { printf("RESULT %s exception %s: %s\n", mode.c_str(), f.GetMessageString() ? "Standard_Failure" : "", f.GetMessageString()); }
  catch (...) { printf("RESULT %s exception unknown\n", mode.c_str()); }
  return 0;
}
