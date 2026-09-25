// #766 / #1989 evidence correction: kernel side of the like-for-like records in
// okf/references/766-execution/kernel-parity/OCCTMiscTests.json.
//
// The earlier probes under Scripts/repro/766-misc-*/ printed %.12g and named quantities the
// bridge side did not carry. This one prints, for every corrected record, the SAME quantity the
// Swift test observes, one line per key, at %.17g, as
//     <record id>|<key>|<json value>
// so the JSON records are built from this transcript and the matching bridge-side transcript
// (a temporary Swift test, printed and discarded) without any value being typed by hand. The
// OCCT calls are the ones the bridge functions make; each record id says which.
//
// bridge-observed.txt beside this file is that Swift-side print: a temporary test file
// (Tests/OCCTMiscTests/Tmp1989Fix.swift) that rebuilt each test's fixture through the public API,
// ran with `swift test --filter Tmp1989Fix`, and was deleted, never committed. Keys starting with
// an underscore are notes (a mechanism, or a second measurement) and are not part of a record.
// The two transcripts share one line format, so they can be read side by side.
//
// Build (from the repo root, against the SwiftPM-resolved pinned kernel):
//   X=.build/artifacts/<checkout>/OCCT/OCCT.xcframework/macos-arm64
//   clang++ -std=c++17 -ObjC++ -w -I"$X/Headers" -L"$X" -lOCCT-macos \
//     -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/766-misc-evidence-fix/probe.mm -o /tmp/probe_766_misc_fix

#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRepExtrema_SelfIntersection.hxx>
#include <BRepGProp.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCone.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepTools.hxx>
#include <BRep_Tool.hxx>
#include <Bnd_Box.hxx>
#include <GCE2d_MakeSegment.hxx>
#include <GC_MakeSegment.hxx>
#include <GProp_GProps.hxx>
#include <Geom2dConvert.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <GeomAPI_ExtremaCurveCurve.hxx>
#include <GeomAPI_IntCS.hxx>
#include <GeomAPI_IntSS.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <GeomConvert.hxx>
#include <GeomLProp_CLProps.hxx>
#include <GeomLProp_SLProps.hxx>
#include <GeomLib_LogSample.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Line.hxx>
#include <Geom_Plane.hxx>
#include <Geom_SphericalSurface.hxx>
#include <IntCurvesFace_ShapeIntersector.hxx>
#include <NCollection_Array1.hxx>
#include <NCollection_HArray1.hxx>
#include <NCollection_KDTree.hxx>
#include <OSD_DirectoryIterator.hxx>
#include <OSD_FileIterator.hxx>
#include <OSD_Path.hxx>
#include <Precision.hxx>
#include <Resource_Unicode.hxx>
#include <TCollection_ExtendedString.hxx>
#include <TColStd_HArray1OfReal.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopLoc_Location.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <gp_Ax3.hxx>
#include <gp_Dir.hxx>
#include <gp_Lin.hxx>
#include <gp_Pln.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <limits>
#include <string>
#include <sys/stat.h>
#include <unistd.h>

// ---- output -----------------------------------------------------------------------------------
static std::string num(double v)
{
  char b[64];
  std::snprintf(b, sizeof b, "%.17g", v);
  return b;
}
static void emit(const char* id, const char* key, const std::string& json)
{
  std::printf("%s|%s|%s\n", id, key, json.c_str());
}
static void emitNum(const char* id, const char* key, double v) { emit(id, key, num(v)); }
static void emitInt(const char* id, const char* key, long v) { emit(id, key, std::to_string(v)); }
static void emitBool(const char* id, const char* key, bool v) { emit(id, key, v ? "true" : "false"); }
static void emitStr(const char* id, const char* key, const std::string& s) { emit(id, key, "\"" + s + "\""); }
static void emitVec(const char* id, const char* key, double x, double y, double z)
{
  emit(id, key, "[" + num(x) + ", " + num(y) + ", " + num(z) + "]");
}
static void emitPnt(const char* id, const char* key, const gp_Pnt& p) { emitVec(id, key, p.X(), p.Y(), p.Z()); }
static void emitDir(const char* id, const char* key, gp_Vec v)
{
  v.Normalize();
  emitVec(id, key, v.X(), v.Y(), v.Z());
}

// ---- helpers ----------------------------------------------------------------------------------
static gp_Trsf grouped(const double* m)
{
  gp_Trsf t;
  t.SetValues(m[0], m[1], m[2], m[9], m[3], m[4], m[5], m[10], m[6], m[7], m[8], m[11]);
  return t;
}
static gp_Trsf interleaved(const double* m)
{
  gp_Trsf t;
  t.SetValues(m[0], m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9], m[10], m[11]);
  return t;
}
// occtComputeBoundingBox with optimal = false, useTriangulation = true.
static void bbox(const TopoDS_Shape& s, double* mn, double* mx)
{
  Bnd_Box b;
  BRepBndLib::Add(s, b, Standard_True);
  b.Get(mn[0], mn[1], mn[2], mx[0], mx[1], mx[2]);
}
static Handle(TColgp_HArray1OfPnt) pts(const double (*p)[3], int n)
{
  Handle(TColgp_HArray1OfPnt) a = new TColgp_HArray1OfPnt(1, n);
  for (int i = 0; i < n; i++)
    a->SetValue(i + 1, gp_Pnt(p[i][0], p[i][1], p[i][2]));
  return a;
}
static void curveEnds(const char* id, const Handle(Geom_Curve)& c, bool withTangents)
{
  const double u0 = c->FirstParameter(), u1 = c->LastParameter();
  gp_Pnt       p0, p1;
  gp_Vec       v0, v1;
  c->D1(u0, p0, v0);
  c->D1(u1, p1, v1);
  emitPnt(id, "start", p0);
  emitPnt(id, "end", p1);
  if (withTangents)
  {
    emitDir(id, "unit_start_tangent", v0);
    emitDir(id, "unit_end_tangent", v1);
  }
}
static double volume(const TopoDS_Shape& s)
{
  GProp_GProps g;
  BRepGProp::VolumeProperties(s, g);
  return g.Mass();
}
// SheetMetal.Builder.extrude: the lifted profile as a closed polygon, a planar face, a prism.
static TopoDS_Shape flange(gp_Pnt o, gp_Vec uAxis, gp_Vec vAxis, gp_Vec n, double w, double h, double t)
{
  auto at = [&](double u, double v) { return o.Translated(uAxis * u + vAxis * v); };
  BRepBuilderAPI_MakePolygon poly(at(0, 0), at(w, 0), at(w, h), at(0, h), Standard_True);
  TopoDS_Face                face = BRepBuilderAPI_MakeFace(poly.Wire(), Standard_True).Face();
  return BRepPrimAPI_MakePrism(face, n * t).Shape();
}
// Face normal and UV midpoint exactly as OCCTFaceGetNormalAtUV / OCCTFaceEvaluateAtUV do.
static void faceMid(const TopoDS_Face& f, gp_Pnt& p, gp_Dir& n)
{
  double u0, u1, v0, v1;
  BRepTools::UVBounds(f, u0, u1, v0, v1);
  const double         u = 0.5 * (u0 + u1), v = 0.5 * (v0 + v1);
  Handle(Geom_Surface) s = BRep_Tool::Surface(f);
  s->D0(u, v, p);
  GeomLProp_SLProps props(s, u, v, 1, Precision::Confusion());
  n = props.Normal();
  if (f.Orientation() == TopAbs_REVERSED)
    n.Reverse();
}
// The plane's shape as ConstructionContext.planeShape builds it: OCCTWireCreateFastPolygon
// (BRepBuilderAPI_MakePolygon Add x n, Close, IsDone) then OCCTShapeCreateFaceFromWire
// (BRepBuilderAPI_MakeFace, IsDone). Both bridge functions run inside try / catch (...) and return
// nullptr on failure, so an OCCT exception is a refusal too. `how` records which step refused.
static bool planeShapeBuilt(const gp_Pnt* p, int n, std::string& how)
{
  try
  {
    BRepBuilderAPI_MakePolygon poly;
    for (int i = 0; i < n; i++)
      poly.Add(p[i]);
    poly.Close();
    if (!poly.IsDone())
    {
      how = "MakePolygon not done";
      return false;
    }
    BRepBuilderAPI_MakeFace face(poly.Wire(), Standard_True);
    if (!face.IsDone())
    {
      how = "MakePolygon done, MakeFace not done";
      return false;
    }
    how = "built";
    return true;
  }
  catch (const Standard_Failure& e)
  {
    how = std::string("threw ") + e.ExceptionType() + ": " + (e.what() ? e.what() : "");
    return false;
  }
}

int main()
{
  const double translate567[12] = {1, 0, 0, 0, 1, 0, 0, 0, 1, 5, 6, 7};
  const double c30 = std::cos(M_PI / 6), s30 = std::sin(M_PI / 6);
  const double rotated[12] = {c30, -s30, 0, s30, c30, 0, 0, 0, 1, 5, 6, 7};
  const double mirrorInX[12] = {-1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0};

  // OCCTShapeCreateBox: centred on the origin.
  TopoDS_Shape centred = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();

  // r1 transform_shift: OCCTShapeTransformed on the centred box, GROUPED translate567.
  {
    double bmn[3], bmx[3], amn[3], amx[3];
    bbox(centred, bmn, bmx);
    bbox(BRepBuilderAPI_Transform(centred, grouped(translate567), Standard_True).Shape(), amn, amx);
    emitVec("r1", "shift_min", amn[0] - bmn[0], amn[1] - bmn[1], amn[2] - bmn[2]);
    emitVec("r1", "shift_max", amx[0] - bmx[0], amx[1] - bmx[1], amx[2] - bmx[2]);
  }
  // r2 grouped_vs_interleaved: rotated-and-translated, GROUPED reader vs the reshuffled array read
  // INTERLEAVED (OCCTShapeTransformFromMatrix).
  {
    const double asInterleaved[12] = {rotated[0], rotated[1], rotated[2], rotated[9],
                                      rotated[3], rotated[4], rotated[5], rotated[10],
                                      rotated[6], rotated[7], rotated[8], rotated[11]};
    double gmn[3], gmx[3], imn[3], imx[3];
    bbox(BRepBuilderAPI_Transform(centred, grouped(rotated), Standard_True).Shape(), gmn, gmx);
    bbox(BRepBuilderAPI_Transform(centred, interleaved(asInterleaved), Standard_True).Shape(), imn, imx);
    emitVec("r2", "grouped_min", gmn[0], gmn[1], gmn[2]);
    emitVec("r2", "grouped_max", gmx[0], gmx[1], gmx[2]);
    emitVec("r2", "interleaved_min", imn[0], imn[1], imn[2]);
    emitVec("r2", "interleaved_max", imx[0], imx[1], imx[2]);
  }
  // r3 component_shift: OCCTDocumentAddComponentMatrix attaches TopLoc_Location(GROUPED trsf).
  {
    double bmn[3], bmx[3], amn[3], amx[3];
    bbox(centred, bmn, bmx);
    bbox(centred.Moved(TopLoc_Location(grouped(translate567))), amn, amx);
    emitVec("r3", "shift_min", amn[0] - bmn[0], amn[1] - bmn[1], amn[2] - bmn[2]);
  }
  // r4 reflection: OCCTShapeCreateBoxAt(1,0,0, 10, 10, 10), mirrored in X.
  {
    TopoDS_Shape corner = BRepPrimAPI_MakeBox(gp_Pnt(1, 0, 0), 10, 10, 10).Shape();
    double       mn[3], mx[3];
    bbox(corner.Moved(TopLoc_Location(grouped(mirrorInX))), mn, mx);
    emitNum("r4", "min_x", mn[0]);
    emitNum("r4", "max_x", mx[0]);
  }
  // r5 flange_normal: Flange.init normalises (0, 0, 7); the kernel's gp_Dir does the same.
  {
    gp_Dir d(0, 0, 7);
    emitVec("r5", "normalised", d.X(), d.Y(), d.Z());
  }
  // r6 curve3d_counts: OCCTCurve3DExtrema (GeomAPI_ExtremaCurveCurve), OCCTCurve3DIntersectSurface
  // (GeomAPI_IntCS), OCCTCurve3DSplitAtContinuity (CurveToBSplineCurve + C0BSplineToArrayOfC1).
  Handle(Geom_Curve) a = GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Value();
  {
    Handle(Geom_Curve) b = GC_MakeSegment(gp_Pnt(5, -5, 1), gp_Pnt(5, 5, 1)).Value();
    GeomAPI_ExtremaCurveCurve e(a, b);
    emitInt("r6", "extrema", e.NbExtrema());
    Handle(Geom_Curve) through = GC_MakeSegment(gp_Pnt(0, 0, -20), gp_Pnt(0, 0, 20)).Value();
    GeomAPI_IntCS      ics(through, new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
    emitInt("r6", "intersections", ics.NbPoints());
    Handle(Geom_BSplineCurve)                                bsp = GeomConvert::CurveToBSplineCurve(a);
    Handle(NCollection_HArray1<Handle(Geom_BSplineCurve)>) arr;
    GeomConvert::C0BSplineToArrayOfC1BSplineCurve(bsp, arr, 1e-6);
    emitInt("r6", "split_pieces", arr.IsNull() ? 0 : arr->Length());
  }
  // r7 curve2d_split: OCCTCurve2DSplitAtContinuity.
  {
    Handle(Geom2d_Curve)        c   = GCE2d_MakeSegment(gp_Pnt2d(0, 0), gp_Pnt2d(10, 0)).Value();
    Handle(Geom2d_BSplineCurve) bsp = Geom2dConvert::CurveToBSplineCurve(c);
    Handle(NCollection_HArray1<Handle(Geom2d_BSplineCurve)>) arr;
    Geom2dConvert::C0BSplineToArrayOfC1BSplineCurve(bsp, arr, 1e-6);
    emitInt("r7", "split_pieces", arr.IsNull() ? 0 : arr->Length());
  }
  // r8 projection: OCCTExtremaPointCurve (GeomAPI_ProjectPointOnCurve), OCCTExtremaPointSurface.
  {
    GeomAPI_ProjectPointOnCurve pc(gp_Pnt(5, 5, 0), a);
    GeomAPI_ProjectPointOnSurf  ps(gp_Pnt(1, 1, 5), new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
    emitInt("r8", "curve", pc.NbPoints());
    emitInt("r8", "surface", ps.NbPoints());
  }
  // r9 kdtree: NCollection_KDTree over (0,0,0), (1,1,1), (2,2,2).
  {
    gp_Pnt                        p[3] = {gp_Pnt(0, 0, 0), gp_Pnt(1, 1, 1), gp_Pnt(2, 2, 2)};
    NCollection_KDTree<gp_Pnt, 3> tree;
    tree.Build(p, 3);
    NCollection_Array1<size_t> idx(1, 3);
    NCollection_Array1<double> dist(1, 3);
    emitInt("r9", "kNearest", (long)tree.KNearestPoints(gp_Pnt(0, 0, 0), 3, idx, dist));
    emitInt("r9", "range", (long)tree.RangeSearch(gp_Pnt(0, 0, 0), 10).Size());
    emitInt("r9", "box", (long)tree.BoxSearch(gp_Pnt(-9, -9, -9), gp_Pnt(9, 9, 9)).Size());
  }
  // r10 listing: OSD_FileIterator (OCCTFileList) and OSD_DirectoryIterator (OCCTDirectoryList)
  // over a directory holding seven files. The names are printed, to say what the directory
  // iterator reports.
  {
    char  tmpl[] = "/tmp/occt-misc-evidence-XXXXXX";
    char* dir    = mkdtemp(tmpl);
    for (int i = 0; i < 7; i++)
    {
      std::string path = std::string(dir) + "/f" + std::to_string(i) + ".txt";
      FILE*       f    = std::fopen(path.c_str(), "w");
      std::fputs("x", f);
      std::fclose(f);
    }
    long        files = 0, dirs = 0;
    std::string dirNames;
    for (OSD_FileIterator it(OSD_Path(dir), "*"); it.More(); it.Next())
      files++;
    for (OSD_DirectoryIterator it(OSD_Path(dir), "*"); it.More(); it.Next())
    {
      dirs++;
      OSD_Directory           d = it.Values();
      OSD_Path                p;
      d.Path(p);
      TCollection_AsciiString n;
      p.SystemName(n);
      dirNames += (dirNames.empty() ? "" : ",") + std::string(n.ToCString());
    }
    emitInt("r10", "files", files);
    emitInt("r10", "directories", dirs);
    emitStr("r10", "_directory_names", dirNames);
    for (int i = 0; i < 7; i++)
      unlink((std::string(dir) + "/f" + std::to_string(i) + ".txt").c_str());
    rmdir(dir);
  }
  // r11 logsample: GeomLib_LogSample(1, 100, n).
  {
    GeomLib_LogSample s16(1, 100, 16), s1(1, 100, 1);
    emitInt("r11", "count_for_16", s16.NbPoints());
    emitNum("r11", "first_of_16", s16.GetParameter(1));
    emitNum("r11", "last_of_16", s16.GetParameter(16));
    emitInt("r11", "count_for_1", s1.NbPoints());
  }
  // r12 to r14 interpolation.
  const double three[3][3] = {{0, 0, 0}, {5, 5, 0}, {10, 0, 0}};
  {
    GeomAPI_Interpolate it(pts(three, 3), Standard_False, 1e-6);
    it.Load(gp_Vec(1, 1, 0), gp_Vec(1, -1, 0));
    it.Perform();
    curveEnds("r12", it.Curve(), true);
    GeomAPI_Interpolate plain(pts(three, 3), Standard_False, 1e-6);
    plain.Perform();
    gp_Pnt p;
    gp_Vec v;
    plain.Curve()->D1(plain.Curve()->FirstParameter(), p, v);
    emitDir("r12", "_without_load_unit_start_tangent", v);
  }
  // r12b interpolateWithAllTangents: OCCTInterpolateWithAllTangents, Load(tangents, flags) with only
  // the first and last tangents constrained.
  {
    GeomAPI_Interpolate               it(pts(three, 3), Standard_False, 1e-6);
    NCollection_Array1<gp_Vec>        tans(1, 3);
    Handle(NCollection_HArray1<bool>) flags = new NCollection_HArray1<bool>(1, 3);
    tans.SetValue(1, gp_Vec(1, 1, 0));
    tans.SetValue(2, gp_Vec(1, 0, 0));
    tans.SetValue(3, gp_Vec(1, -1, 0));
    flags->SetValue(1, true);
    flags->SetValue(2, false);
    flags->SetValue(3, true);
    it.Load(tans, flags);
    it.Perform();
    const Handle(Geom_BSplineCurve)& c = it.Curve();
    gp_Pnt                           p0, p1;
    gp_Vec                           v0, v1;
    c->D1(c->FirstParameter(), p0, v0);
    c->D1(c->LastParameter(), p1, v1);
    emitDir("r12b", "unit_start_tangent", v0);
    emitDir("r12b", "unit_end_tangent", v1);
  }
  {
    Handle(TColStd_HArray1OfReal) params = new TColStd_HArray1OfReal(1, 3);
    params->SetValue(1, 0.0);
    params->SetValue(2, 0.5);
    params->SetValue(3, 1.0);
    GeomAPI_Interpolate it(pts(three, 3), params, Standard_False, 1e-6);
    it.Perform();
    const Handle(Geom_BSplineCurve)& c = it.Curve();
    emit("r13", "domain", "[" + num(c->FirstParameter()) + ", " + num(c->LastParameter()) + "]");
    emitPnt("r13", "point_at_half", c->Value(0.5));
    GeomAPI_Interpolate noParams(pts(three, 3), Standard_False, 1e-6);
    noParams.Perform();
    emit("r13", "_without_parameters_domain",
         "[" + num(noParams.Curve()->FirstParameter()) + ", " + num(noParams.Curve()->LastParameter()) + "]");
  }
  {
    const double square[4][3] = {{0, 0, 0}, {10, 0, 0}, {10, 10, 0}, {0, 10, 0}};
    GeomAPI_Interpolate it(pts(square, 4), Standard_True, 1e-6);
    it.Perform();
    const Handle(Geom_BSplineCurve)& c = it.Curve();
    emitBool("r14", "is_periodic", c->IsPeriodic());
    emitBool("r14", "is_closed", c->IsClosed());
    emitNum("r14", "domain_length", c->LastParameter() - c->FirstParameter());
    emitPnt("r14", "start", c->Value(c->FirstParameter()));
  }
  // r15 face_angles and r26 edge_angle: the centred box's faces and edges in TopExp order.
  TopTools_IndexedMapOfShape edges, faces;
  TopExp::MapShapes(centred, TopAbs_EDGE, edges);
  TopExp::MapShapes(centred, TopAbs_FACE, faces);
  {
    long n0 = 0, n90 = 0, n180 = 0, other = 0;
    for (int i = 1; i <= faces.Extent(); i++)
      for (int j = i + 1; j <= faces.Extent(); j++)
      {
        gp_Pnt pi, pj;
        gp_Dir ni, nj;
        faceMid(TopoDS::Face(faces(i)), pi, ni);
        faceMid(TopoDS::Face(faces(j)), pj, nj);
        double ang = gp_Vec(ni).Angle(gp_Vec(nj));
        if (ang < 1e-3)
          n0++;
        else if (std::fabs(ang - M_PI) < 1e-3)
          n180++;
        else if (std::fabs(ang - M_PI / 2) < 1e-3)
          n90++;
        else
          other++;
      }
    emitInt("r15", "0", n0);
    emitInt("r15", "pi/2", n90);
    emitInt("r15", "pi", n180);
    emitInt("r15", "other", other);
  }
  {
    // OCCTEdgeGetTangent3D at the linear midpoint of each edge's parameter range.
    auto tangentAtMid = [](const TopoDS_Edge& e) {
      double f, l;
      Handle(Geom_Curve) c = BRep_Tool::Curve(e, f, l);
      GeomLProp_CLProps props(c, 0.5 * (f + l), 1, Precision::Confusion());
      gp_Dir            d;
      props.Tangent(d);
      return gp_Vec(d);
    };
    emitNum("r26", "angle", tangentAtMid(TopoDS::Edge(edges(1))).Angle(tangentAtMid(TopoDS::Edge(edges(2)))));
  }
  // r16 and r17 edge parameters: BRep_Tool::Curve range of the first edge (OCCTEdgeGetParameterBounds).
  {
    double f, l;
    BRep_Tool::Curve(TopoDS::Edge(edges(1)), f, l);
    emitNum("r16", "p0", f);
    emitNum("r16", "p_mid", f + (l - f) * 0.5);
    emitNum("r16", "p1", l);
    emitNum("r17", "p_below", f);
    emitNum("r17", "p_above", l);
  }
  // r18 and r19 lift: a gp_Ax3 frame and gp_Trsf::SetTransformation into the world.
  {
    auto lift = [](const gp_Ax3& frame, double u, double v, const char* id) {
      gp_Trsf t;
      t.SetTransformation(frame, gp_Ax3());
      gp_Pnt p(u, v, 0);
      p.Transform(t);
      emitPnt(id, "point", p);
    };
    lift(gp_Ax3(gp_Pnt(1, 2, 3), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0)), 4, 5, "r18");
    const double s2 = std::sqrt(2.0) / 2;
    lift(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), gp_Dir(s2, s2, 0)), 1, 0, "r19");
  }
  // r20 raycast: IntCurvesFace_ShapeIntersector, ray (0,0,20) along -Z.
  {
    IntCurvesFace_ShapeIntersector it;
    it.Load(centred, 1e-7);
    it.Perform(gp_Lin(gp_Pnt(0, 0, 20), gp_Dir(0, 0, -1)), -1e10, 1e10);
    emitInt("r20", "count", it.NbPnt());
  }
  // r21 surface_intersections: GeomAPI_IntSS on planes z = 0 and y = 0.
  {
    GeomAPI_IntSS iss(new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)),
                      new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 1, 0)), 1e-7);
    emitInt("r21", "count", iss.NbLines());
  }
  // r22 allDistanceSolutions and r23 selfIntersectionPairs.
  {
    TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(5).Shape();
    BRepExtrema_DistShapeShape d(centred, sphere);
    emitInt("r22", "count", d.NbSolution());
    BRepMesh_IncrementalMesh     mesh(centred, 0.1);
    BRepExtrema_SelfIntersection si(centred, 0.0);
    si.Perform();
    long pairs = 0;
    for (NCollection_DataMap<int, TColStd_PackedMapOfInteger>::Iterator it(si.OverlapElements()); it.More();
         it.Next())
      pairs += it.Value().Extent();
    emitInt("r23", "count", pairs);
  }
  // r24 unicode: Resource_Unicode::ConvertUnicodeToFormat.
  {
    TCollection_ExtendedString s("hello", true);
    char                       buf[64] = {0};
    Standard_PCharacter        bufPtr  = buf;
    Resource_Unicode::ConvertUnicodeToFormat(s, bufPtr, 64);
    emitStr("r24", "string", buf);
  }
  // r25 sketch_profile: the closed 10 x 10 square polygon's wire length (BRepGProp linear).
  {
    BRepBuilderAPI_MakePolygon poly;
    poly.Add(gp_Pnt(0, 0, 0));
    poly.Add(gp_Pnt(10, 0, 0));
    poly.Add(gp_Pnt(10, 10, 0));
    poly.Add(gp_Pnt(0, 10, 0));
    poly.Close();
    GProp_GProps g;
    BRepGProp::LinearProperties(poly.Wire(), g);
    emitNum("r25", "length", g.Mass());
    BRepBuilderAPI_MakePolygon withDiag;
    withDiag.Add(gp_Pnt(0, 0, 0));
    withDiag.Add(gp_Pnt(10, 0, 0));
    withDiag.Add(gp_Pnt(10, 10, 0));
    withDiag.Add(gp_Pnt(0, 10, 0));
    withDiag.Add(gp_Pnt(0, 0, 0));
    withDiag.Add(gp_Pnt(10, 10, 0));
    GProp_GProps g2;
    BRepGProp::LinearProperties(withDiag.Wire(), g2);
    emitNum("r25", "_with_construction_diagonal_length", g2.Mass());
  }
  // r27 to r29 unsignedAngle: gp_Vec::Angle. r29 is the degenerate input, where the kernel throws.
  emitNum("r27", "angle", gp_Vec(1, 0, 0).Angle(gp_Vec(2, 0, 0)));
  emitNum("r28", "angle", gp_Vec(1, 0, 0).Angle(gp_Vec(-1, 0, 0)));
  {
    bool refusedA = false, refusedB = false;
    try
    {
      gp_Vec(0, 0, 0).Angle(gp_Vec(1, 0, 0));
    }
    catch (const Standard_Failure&)
    {
      refusedA = true;
    }
    try
    {
      gp_Vec(0, 0, 0).Angle(gp_Vec(0, 0, 0));
    }
    catch (const Standard_Failure&)
    {
      refusedB = true;
    }
    emitBool("r29", "refused", refusedA && refusedB);
  }
  // r30 and r31: gp_Dir::Angle for the axis directions and the plane normals.
  emitNum("r30", "angle", gp_Dir(1, 0, 0).Angle(gp_Dir(0, 1, 0)));
  emitNum("r31", "angle", gp_Dir(0, 0, 1).Angle(gp_Dir(0, 1, 0)));
  // r32 and r33 coplanar: no OCCT face-coplanarity call exists, so the rule Face.isCoplanar applies
  // (normals parallel within 1e-4 rad, separation along the normal below 1e-6) is applied to the
  // kernel's own plane geometry.
  {
    auto coplanar = [](const TopoDS_Face& f, const TopoDS_Face& g) {
      gp_Pnt pf, pg;
      gp_Dir nf, ng;
      faceMid(f, pf, nf);
      faceMid(g, pg, ng);
      double ang = gp_Vec(nf).Angle(gp_Vec(ng));
      if (!(ang < 1e-4 || (M_PI - ang) < 1e-4))
        return false;
      return std::fabs(gp_Vec(pf, pg).Dot(gp_Vec(ng))) < 1e-6;
    };
    emitBool("r32", "coplanar", coplanar(TopoDS::Face(faces(1)), TopoDS::Face(faces(1))));
    emitBool("r33", "coplanar", coplanar(TopoDS::Face(faces(1)), TopoDS::Face(faces(2))));
    gp_Pnt p1, p2;
    gp_Dir n1, n2;
    faceMid(TopoDS::Face(faces(1)), p1, n1);
    faceMid(TopoDS::Face(faces(2)), p2, n2);
    emitNum("r33", "_separation", std::fabs(gp_Vec(p1, p2).Dot(gp_Vec(n2))));
  }
  // r34 cone radius: distance from the axis line to the surface point at the UV midpoint of the
  // cone face (the value Face.revolutionProperties reports).
  {
    TopoDS_Shape cone = BRepPrimAPI_MakeCone(5, 0, 10).Shape();
    for (TopExp_Explorer ex(cone, TopAbs_FACE); ex.More(); ex.Next())
    {
      TopoDS_Face         f = TopoDS::Face(ex.Current());
      BRepAdaptor_Surface s(f);
      if (s.GetType() != GeomAbs_Cone)
        continue;
      double u0, u1, v0, v1;
      BRepTools::UVBounds(f, u0, u1, v0, v1);
      gp_Pnt q    = s.Value(0.5 * (u0 + u1), 0.5 * (v0 + v1));
      gp_Ax1 axis = s.Cone().Axis();
      gp_Vec off(axis.Location(), q);
      gp_Vec along = gp_Vec(axis.Direction()) * off.Dot(gp_Vec(axis.Direction()));
      emitNum("r34", "radius", (off - along).Magnitude());
      emitNum("r34", "_distance_to_axis_origin", off.Magnitude());
    }
  }
  // r35 spherical cap: a sphere's radius is the distance from the centre to any surface point.
  {
    Handle(Geom_SphericalSurface) sph = new Geom_SphericalSurface(gp_Ax3(), 5);
    TopoDS_Face cap = BRepBuilderAPI_MakeFace(sph, 0, 2 * M_PI, 1.3, 1.5, 1e-7).Face();
    double      u0, u1, v0, v1;
    BRepTools::UVBounds(cap, u0, u1, v0, v1);
    BRepAdaptor_Surface s(cap);
    gp_Pnt              q = s.Value(0.5 * (u0 + u1), 0.5 * (v0 + v1));
    emitNum("r35", "radius", gp_Vec(gp_Pnt(0, 0, 0), q).Magnitude());
    emitNum("r35", "_radial_component_to_z_the_old_bug", std::hypot(q.X(), q.Y()));
  }
  // r36 and r37 materialize: is the plane's shape built (see planeShapeBuilt).
  {
    const double h = 1e-9;
    gp_Pnt       sq[4] = {gp_Pnt(-h, -h, 0), gp_Pnt(h, -h, 0), gp_Pnt(h, h, 0), gp_Pnt(-h, h, 0)};
    std::string  how;
    emitBool("r36", "shape_built", planeShapeBuilt(sq, 4, how));
    emitStr("r36", "_how", how);
    const double nan   = std::numeric_limits<double>::quiet_NaN();
    gp_Pnt       nn[4] = {gp_Pnt(nan, nan, nan), gp_Pnt(nan, nan, nan), gp_Pnt(nan, nan, nan),
                          gp_Pnt(nan, nan, nan)};
    emitBool("r37", "shape_built", planeShapeBuilt(nn, 4, how));
    emitStr("r37", "_how", how);
  }
  // r38 to r41 unbent SheetMetal fixtures: prisms and a fuse.
  {
    const gp_Vec X(1, 0, 0), Y(0, 1, 0), Z(0, 0, 1);
    TopoDS_Shape a1 = flange(gp_Pnt(0, 0, 0), X, Y, Z, 20, 10, 2);
    TopoDS_Shape b1 = flange(gp_Pnt(0, 10, 0), X, Z, Y, 10, 10, 2);
    emitNum("r38", "volume", volume(BRepAlgoAPI_Fuse(a1, b1).Shape()));
    emitNum("r39", "volume", volume(flange(gp_Pnt(0, 0, 0), X, Y, Z, 50, 25, 3)));
    emitNum("r40", "volume", volume(flange(gp_Pnt(0, 0, 0), X, Y, Z, 40, 20, 2.5)));
    TopoDS_Shape base    = flange(gp_Pnt(0, 0, 0), X, Y, Z, 65, 28, 3);
    TopoDS_Shape upright = flange(gp_Pnt(0, 28, 0), X, Z, Y, 65, 40, 3);
    emitNum("r41", "volume", volume(BRepAlgoAPI_Fuse(base, upright).Shape()));
  }
  return 0;
}
