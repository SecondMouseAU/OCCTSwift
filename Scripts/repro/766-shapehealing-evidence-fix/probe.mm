// #766 evidence correction (ShapeHealing, #1976): kernel-side measurements for the parity records whose
// two sides were different quantities. Every corrected quantity is printed as `<record>|<key>|<json>`
// at %.17g, using the OCCT calls the bridge function makes; the Swift side is bridge-observed.txt in
// the same line format. Run from the repository root (the #318 fixture is read out of the Swift test
// file, as the original probe did, so there is one copy of it):
//   clang++ -std=c++17 -ObjC++ -w -I"$X/Headers" -L"$X" -lOCCT-macos -framework Foundation \
//     -framework AppKit -lz -lc++ Scripts/repro/766-shapehealing-evidence-fix/probe.mm -o /tmp/p
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepTools.hxx>
#include <BRepTools_Modifier.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <GProp_GProps.hxx>
#include <Geom_OffsetSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_Surface.hxx>
#include <ShapeAnalysis_Shell.hxx>
#include <ShapeCustom.hxx>
#include <ShapeCustom_BSplineRestriction.hxx>
#include <ShapeCustom_RestrictionParameters.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Shell.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepBndLib.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepBuilderAPI_NurbsConvert.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepBuilderAPI_Copy.hxx>
#include <BRepBuilderAPI_MakeSolid.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepLib.hxx>
#include <BRepTools_History.hxx>
#include <Bnd_Box.hxx>
#include <Precision.hxx>
#include <ShapeBuild_Edge.hxx>
#include <ShapeBuild_ReShape.hxx>
#include <ShapeFix_Shape.hxx>
#include <ShapeFix_Solid.hxx>
#include <ShapeUpgrade_RemoveLocations.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS_Iterator.hxx>
#include <cmath>
#include <cstdio>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

static void emit(const char* rec, const char* key, double v)
{
  printf("%s|%s|%.17g\n", rec, key, v);
}
static void emitInt(const char* rec, const char* key, long v)
{
  printf("%s|%s|%ld\n", rec, key, v);
}
static void emitBool(const char* rec, const char* key, bool v)
{
  printf("%s|%s|%s\n", rec, key, v ? "true" : "false");
}
static void emitNull(const char* rec, const char* key)
{
  printf("%s|%s|null\n", rec, key);
}

static double deviation(const TopoDS_Shape& r, const Handle(Geom_Surface)& src)
{
  TopExp_Explorer      e(r, TopAbs_FACE);
  Handle(Geom_Surface) fit = BRep_Tool::Surface(TopoDS::Face(e.Current()));
  double               u0, u1, v0, v1, worst = 0;
  src->Bounds(u0, u1, v0, v1);
  for (int i = 0; i <= 24; i++)
    for (int j = 0; j <= 24; j++)
    {
      double u = u0 + (u1 - u0) * i / 24, v = v0 + (v1 - v0) * j / 24;
      worst    = std::max(worst, src->Value(u, v).Distance(fit->Value(u, v)));
    }
  return worst;
}

// ---- helpers shared by the solid-construction records (Issue 442 / 443) ----
static double vol(const TopoDS_Shape& s)
{
  GProp_GProps g;
  BRepGProp::VolumeProperties(s, g);
  return g.Mass();
}
static int uniq(const TopoDS_Shape& s, TopAbs_ShapeEnum t)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, t, m);
  return m.Extent();
}
static TopoDS_Shape box(double x, double y, double z, double w)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(x, y, z), w, w, w).Shape();
}
static TopoDS_Shape compoundOf(const std::vector<TopoDS_Shape>& v)
{
  BRep_Builder    b;
  TopoDS_Compound c;
  b.MakeCompound(c);
  for (const TopoDS_Shape& s : v)
    b.Add(c, s);
  return c;
}
// occtSolidBodiesToShape
static TopoDS_Shape bodiesToShape(const std::vector<TopoDS_Shape>& v)
{
  if (v.empty())
    return TopoDS_Shape();
  if (v.size() == 1)
    return v[0];
  return compoundOf(v);
}
// occtSelectBodyShells: every shell an even number of the other closed shells enclose
static void selectBodyShells(const std::vector<TopoDS_Shell>& shells, std::vector<TopoDS_Shell>& out)
{
  if (shells.empty())
    return;
  if (shells.size() == 1)
  {
    out.push_back(shells[0]);
    return;
  }
  std::vector<int> enclosed(shells.size(), 0);
  for (size_t i = 0; i < shells.size(); i++)
  {
    if (!BRep_Tool::IsClosed(shells[i]))
      continue;
    TopoDS_Solid ref;
    BRep_Builder b;
    b.MakeSolid(ref);
    b.Add(ref, shells[i]);
    BRepClass3d_SolidClassifier c(ref);
    c.PerformInfinitePoint(Precision::Confusion());
    TopAbs_State inside = c.State() == TopAbs_IN ? TopAbs_OUT : TopAbs_IN;
    for (size_t j = 0; j < shells.size(); j++)
    {
      if (i == j)
        continue;
      TopExp_Explorer v(shells[j], TopAbs_VERTEX);
      c.Perform(BRep_Tool::Pnt(TopoDS::Vertex(v.Current())), Precision::Confusion());
      if (c.State() == inside)
        enclosed[j]++;
    }
  }
  for (size_t i = 0; i < shells.size(); i++)
    if (enclosed[i] % 2 == 0)
      out.push_back(shells[i]);
}
// occtBodyBoundingShells
static std::vector<TopoDS_Shell> bodyShells(const TopoDS_Shape& s)
{
  std::vector<TopoDS_Shell>  sel;
  TopTools_IndexedMapOfShape claimed;
  for (TopExp_Explorer se(s, TopAbs_SOLID); se.More(); se.Next())
  {
    std::vector<TopoDS_Shell> g;
    for (TopExp_Explorer sh(se.Current(), TopAbs_SHELL); sh.More(); sh.Next())
    {
      claimed.Add(sh.Current());
      g.push_back(TopoDS::Shell(sh.Current()));
    }
    selectBodyShells(g, sel);
  }
  std::vector<TopoDS_Shell> freeShells;
  for (TopExp_Explorer sh(s, TopAbs_SHELL); sh.More(); sh.Next())
  {
    if (claimed.Contains(sh.Current()))
      continue;
    claimed.Add(sh.Current());
    freeShells.push_back(TopoDS::Shell(sh.Current()));
  }
  selectBodyShells(freeShells, sel);
  return sel;
}
// OCCTShapeFixSolid
static TopoDS_Shape apiFixSolid(const TopoDS_Shape& s)
{
  std::vector<TopoDS_Shape> fixed;
  for (TopExp_Explorer e(s, TopAbs_SOLID); e.More(); e.Next())
  {
    ShapeFix_Solid f(TopoDS::Solid(e.Current()));
    f.Perform();
    TopoDS_Shape r = f.Shape();
    if (r.IsNull())
    {
      fixed.push_back(e.Current());
      continue;
    }
    if (r.ShapeType() == TopAbs_COMPOUND)
    {
      size_t before = fixed.size();
      for (TopoDS_Iterator it(r); it.More(); it.Next())
        fixed.push_back(it.Value());
      if (fixed.size() == before)
        fixed.push_back(e.Current());
    }
    else
      fixed.push_back(r);
  }
  return bodiesToShape(fixed);
}
// OCCTShapeSolidFromShell
static TopoDS_Shape apiSolidFromShellFixed(const TopoDS_Shape& s)
{
  std::vector<TopoDS_Shape> made;
  for (const TopoDS_Shell& sh : bodyShells(s))
  {
    ShapeFix_Solid f;
    TopoDS_Solid   so = f.SolidFromShell(sh);
    made.push_back(so.IsNull() ? TopoDS_Shape(sh) : TopoDS_Shape(so));
  }
  return bodiesToShape(made);
}
// OCCTShapeCreateSolidFromShell (and, with a context, OCCTShapeCreateSolidFromShellWithHistory)
static TopoDS_Shape apiSolidFrom(const TopoDS_Shape& s, const Handle(ShapeBuild_ReShape)& ctx = Handle(ShapeBuild_ReShape)())
{
  std::vector<TopoDS_Shape> made;
  for (const TopoDS_Shell& sh : bodyShells(s))
  {
    BRepBuilderAPI_MakeSolid ms(sh);
    TopoDS_Solid             so;
    if (ms.IsDone())
      so = ms.Solid();
    if (so.IsNull())
    {
      made.push_back(sh);
      continue;
    }
    ShapeFix_Solid f(so);
    if (!ctx.IsNull())
      f.SetContext(ctx);
    f.Perform();
    TopoDS_Shape fx = f.Solid();
    made.push_back((fx.IsNull() || fx.ShapeType() != TopAbs_SOLID) ? TopoDS_Shape(so) : fx);
  }
  return bodiesToShape(made);
}
// Shape.sewn / Shape.sew(shapes:) (OCCTShapeSewSingle, OCCTShapeSew): sew, and make a solid of a closed shell
static TopoDS_Shape apiSew(const std::vector<TopoDS_Shape>& shapes, double tol = 1e-6)
{
  BRepBuilderAPI_Sewing sw(tol);
  for (const TopoDS_Shape& x : shapes)
    sw.Add(x);
  sw.Perform();
  TopoDS_Shape sewn = sw.SewedShape();
  if (sewn.IsNull())
    return sewn;
  if (sewn.ShapeType() == TopAbs_SHELL && sewn.Closed())
  {
    BRepBuilderAPI_MakeSolid ms(TopoDS::Shell(sewn));
    if (ms.IsDone())
      return ms.Solid();
  }
  return sewn;
}
// OCCTShapeUpgrade: sew, one solid per body-bounding shell, ShapeFix_Shape
static TopoDS_Shape apiUpgraded(const TopoDS_Shape& s, double tol)
{
  BRepBuilderAPI_Sewing sw(tol);
  sw.Add(s);
  sw.Perform();
  TopoDS_Shape sewn = sw.SewedShape();
  if (sewn.IsNull())
    sewn = s;
  TopoDS_Shape result = sewn;
  if (sewn.ShapeType() != TopAbs_SOLID)
  {
    std::vector<TopoDS_Shape> made;
    for (const TopoDS_Shell& sh : bodyShells(sewn))
    {
      BRepBuilderAPI_MakeSolid ms(sh);
      made.push_back(ms.IsDone() ? TopoDS_Shape(ms.Solid()) : TopoDS_Shape(sh));
    }
    TopoDS_Shape solids = bodiesToShape(made);
    if (!solids.IsNull())
      result = solids;
  }
  ShapeFix_Shape fx(result);
  fx.Perform();
  TopoDS_Shape fixed = fx.Shape();
  return fixed.IsNull() ? result : fixed;
}
static void emitSolids(const char* rec, const char* prefix, const TopoDS_Shape& s)
{
  char k[96];
  const char* p = prefix[0] ? prefix : "";
  const char* d = prefix[0] ? "." : "";
  snprintf(k, sizeof k, "%s%sbodies", p, d);
  emitInt(rec, k, uniq(s, TopAbs_SOLID));
  snprintf(k, sizeof k, "%s%sfaces", p, d);
  emitInt(rec, k, uniq(s, TopAbs_FACE));
  snprintf(k, sizeof k, "%s%svolume", p, d);
  emit(rec, k, vol(s));
}
static void bounds(const TopoDS_Shape& s, double& x0, double& x1)
{
  Bnd_Box b;
  BRepBndLib::Add(s, b, true);
  double y0, z0, y1, z1;
  b.Get(x0, y0, z0, x1, y1, z1);
}
static TopoDS_Shape firstShell(const TopoDS_Shape& s)
{
  return TopExp_Explorer(s, TopAbs_SHELL).Current();
}
static TopoDS_Shape hollowBox()
{
  return BRepAlgoAPI_Cut(box(0, 0, 0, 20), box(5, 5, 5, 10)).Shape();
}
static TopoDS_Shape multiconnex()
{
  BRep_Builder b;
  TopoDS_Solid so;
  b.MakeSolid(so);
  b.Add(so, firstShell(box(0, 0, 0, 10)));
  b.Add(so, firstShell(box(20, 0, 0, 10)));
  return so;
}
// one closed 10-cube shell and a disjoint sewn five-face shell (11 faces)
static TopoDS_Shape closedAndOpen()
{
  TopoDS_Shape closedShell = firstShell(box(0, 0, 0, 10));
  TopoDS_Shape openBox     = box(30, 0, 0, 10);
  TopTools_IndexedMapOfShape faces;
  TopExp::MapShapes(openBox, TopAbs_FACE, faces);
  std::vector<TopoDS_Shape> five;
  for (int i = 2; i <= faces.Extent(); i++)
    five.push_back(faces(i));
  TopoDS_Shape openShell = apiSew(five);
  return compoundOf({closedShell, openShell});
}

int main()
{
  setvbuf(stdout, nullptr, _IONBF, 0);

  // ---- KEYS: Issue 570, an offset sphere over its full domain (poles included) ----
  {
    Handle(Geom_SphericalSurface) sph = new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10);
    Handle(Geom_OffsetSurface)    off = new Geom_OffsetSurface(sph, 2);
    double                        u0, u1, v0, v1;
    off->Bounds(u0, u1, v0, v1);
    TopoDS_Face f = BRepBuilderAPI_MakeFace(off, u0, u1, v0, v1, 1e-7);

    // K033: OCCTShapeBSplineRestriction = ShapeCustom::BSplineRestriction(tol 0.01, degree 9, 10000
    // segments, C1/C1, degree priority true, rational true, default parameters).
    {
      Handle(ShapeCustom_RestrictionParameters) p = new ShapeCustom_RestrictionParameters();
      TopoDS_Shape r = ShapeCustom::BSplineRestriction(f, 0.01, 0.01, 9, 10000, GeomAbs_C1, GeomAbs_C1, true, true, p);
      emit("K033", "deviation", deviation(r, off));
    }
    // K034: OCCTShapeCustomBSplineRestriction with the test's C0, C1, C2 (degree priority true,
    // rational true, occtDefaults parameters, tol 0.01, degree 9, 10000 segments).
    {
      GeomAbs_Shape cs[] = {GeomAbs_C0, GeomAbs_C1, GeomAbs_C2};
      const char*   ck[] = {"c0", "c1", "c2"};
      for (int k = 0; k < 3; k++)
      {
        Handle(ShapeCustom_RestrictionParameters) p = new ShapeCustom_RestrictionParameters();
        TopoDS_Shape r = ShapeCustom::BSplineRestriction(f, 0.01, 0.01, 9, 10000, cs[k], cs[k], true, true, p);
        emit("K034", ck[k], deviation(r, off));
      }
    }
    // K035: OCCTShapeBSplineRestrictionAdvanced defaults except degree 9 and 10000 segments:
    // approxSurface/curve3d/curve2d true, C1/C1, degree priority true, rational false, via BRepTools_Modifier.
    {
      Handle(ShapeCustom_BSplineRestriction) m =
        new ShapeCustom_BSplineRestriction(true, true, true, 0.01, 0.01, GeomAbs_C1, GeomAbs_C1, 9, 10000, true, false);
      BRepTools_Modifier mod(f, m);
      if (mod.IsDone())
        emit("K035", "deviation", deviation(mod.ModifiedShape(f), off));
    }
  }

  // ---- KEYS: Issue 318, the sewn shape with degenerate BSpline-pcurve edges ----
  {
    std::ifstream in("Tests/OCCTShapeHealingTests/Issue318DegenerateCurveOnSurfaceEdgeTests.swift");
    std::string   all((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
    size_t        a = all.find("static let fixtureBREP = \"\"\"\n");
    size_t        z = all.find("\"\"\"", a + 30);
    std::string   body = all.substr(a + 29, z - (a + 29)), line, brep;
    std::istringstream ls(body);
    while (std::getline(ls, line))
      brep += (line.size() >= 8 ? line.substr(8) : std::string()) + "\n";
    std::istringstream bs(brep);
    TopoDS_Shape       s;
    BRep_Builder       bb;
    BRepTools::Read(s, bs, bb);
    // The bridge (OCCTShapeAnalyze, tolerance 0.11477): edges skipping degenerate ones whose
    // LinearProperties length is under the tolerance, and free edges summed over the shape's shells.
    int smallEdges = 0, freeEdges = 0;
    for (TopExp_Explorer e(s, TopAbs_EDGE); e.More(); e.Next())
    {
      const TopoDS_Edge& ed = TopoDS::Edge(e.Current());
      if (BRep_Tool::Degenerated(ed))
        continue;
      GProp_GProps g;
      BRepGProp::LinearProperties(ed, g);
      if (g.Mass() < 0.11477)
        smallEdges++;
    }
    int shells = 0;
    for (TopExp_Explorer sh(s, TopAbs_SHELL); sh.More(); sh.Next())
    {
      shells++;
      ShapeAnalysis_Shell an;
      an.CheckOrientedShells(sh.Current(), true, true);
      if (an.HasFreeEdges())
        for (TopExp_Explorer fe(an.FreeEdges(), TopAbs_EDGE); fe.More(); fe.Next())
          freeEdges++;
    }
    emitInt("K038", "smallEdgeCount", smallEdges);
    emitInt("K038", "freeEdgeCount", freeEdges);
    emitInt("K038", "shellsInFixture", shells);
  }

  // ---- TYPES batch 1 ----
  {
    // T024: ShapeBuild_Edge::Copy(edge0, no sharing) is a new edge, not the same one
    TopoDS_Shape               b = box(-5, -5, -5, 10);
    TopTools_IndexedMapOfShape edges;
    TopExp::MapShapes(b, TopAbs_EDGE, edges);
    ShapeBuild_Edge sbe;
    TopoDS_Edge     c2 = sbe.Copy(TopoDS::Edge(edges(1)), false);
    emitBool("T024", "isSame", c2.IsSame(edges(1)));
  }
  {
    // T035-T037: BRepBuilderAPI_NurbsConvert (OCCTShapeConvertToNURBS)
    TopoDS_Shape             b2 = BRepPrimAPI_MakeBox(gp_Pnt(-5, -2.5, -1.5), 10, 5, 3).Shape();
    TopoDS_Shape             sp = BRepPrimAPI_MakeSphere(5).Shape();
    TopoDS_Shape             bx = box(-5, -5, -5, 10);
    BRepFilletAPI_MakeFillet mf(bx);
    for (TopExp_Explorer e(bx, TopAbs_EDGE); e.More(); e.Next())
      mf.Add(1.0, TopoDS::Edge(e.Current()));
    mf.Build();
    const char*  ids[] = {"T035", "T036", "T037"};
    TopoDS_Shape in[]  = {b2, sp, mf.Shape()};
    for (int i = 0; i < 3; i++)
    {
      BRepBuilderAPI_NurbsConvert nc(in[i]);
      TopoDS_Shape                r = nc.Shape();
      int                         n = 0;
      for (TopExp_Explorer e(r, TopAbs_FACE); e.More(); e.Next())
        if (BRepAdaptor_Surface(TopoDS::Face(e.Current())).GetType() == GeomAbs_BSplineSurface)
          n++;
      emitBool(ids[i], "valid", BRepCheck_Analyzer(r).IsValid());
      emitInt(ids[i], "bsplineFaces", n);
      emit(ids[i], "volume", vol(r));
    }
  }
  {
    // T038: a box placed with a +(100, 200, 300) location (TopoDS_Shape::Moved), then RemoveLocations
    gp_Trsf t;
    t.SetTranslation(gp_Vec(100, 200, 300));
    TopoDS_Shape                 locd = box(-5, -5, -5, 10).Moved(TopLoc_Location(t));
    ShapeUpgrade_RemoveLocations rl;
    rl.Remove(locd);
    TopoDS_Shape r = rl.GetResult();
    Bnd_Box      bb;
    BRepBndLib::Add(r, bb, true);
    double x0, y0, z0, x1, y1, z1;
    bb.Get(x0, y0, z0, x1, y1, z1);
    emitBool("T038", "valid", BRepCheck_Analyzer(r).IsValid());
    emit("T038", "volume", vol(r));
    printf("T038|boundsMin|[%.17g, %.17g, %.17g]\n", x0, y0, z0);
    printf("T038|boundsMax|[%.17g, %.17g, %.17g]\n", x1, y1, z1);
  }
  {
    // T039: cylinder rotated pi/4 about X (a copying transform), placed with a +50 x location
    // (TopoDS_Shape::Moved, as Shape.moved does), then ShapeUpgrade_RemoveLocations
    TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5, 10).Shape();
    gp_Trsf      rt;
    rt.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)), M_PI / 4);
    TopoDS_Shape rot = BRepBuilderAPI_Transform(cyl, rt, true).Shape();
    gp_Trsf      tr;
    tr.SetTranslation(gp_Vec(50, 0, 0));
    TopoDS_Shape                 placed = rot.Moved(TopLoc_Location(tr));
    ShapeUpgrade_RemoveLocations rl;
    rl.Remove(placed);
    TopoDS_Shape r = rl.GetResult();
    Bnd_Box      bb;
    BRepBndLib::Add(r, bb, true);
    double x0, y0, z0, x1, y1, z1;
    bb.Get(x0, y0, z0, x1, y1, z1);
    emitBool("T039", "valid", BRepCheck_Analyzer(r).IsValid());
    emit("T039", "volume", vol(r));
    printf("T039|boundsMin|[%.17g, %.17g, %.17g]\n", x0, y0, z0);
    printf("T039|boundsMax|[%.17g, %.17g, %.17g]\n", x1, y1, z1);
  }
  {
    // T040: BRepLib::SameParameter(1e-6) on a copy of the box: validity and face count
    BRepBuilderAPI_Copy c(box(-5, -5, -5, 10));
    TopoDS_Shape        r = c.Shape();
    BRepLib::SameParameter(r, 1e-6);
    emitBool("T040", "valid", BRepCheck_Analyzer(r).IsValid());
    emitInt("T040", "faces", uniq(r, TopAbs_FACE));
  }

  // Issue 442: fixSolid / solidFromShellFixed
  TopoDS_Shape two    = compoundOf({box(0, 0, 0, 10), box(20, 0, 0, 10)});
  TopoDS_Shape one    = box(0, 0, 0, 10);
  TopoDS_Shape hollow = hollowBox();
  TopoDS_Shape multi  = multiconnex();
  {
    emitSolids("T043", "", apiFixSolid(two));
    TopoDS_Shape r = apiFixSolid(one);
    emitSolids("T044", "", r);
    emitBool("T044", "isSolid", r.ShapeType() == TopAbs_SOLID);
    emitBool("T044", "valid", BRepCheck_Analyzer(r).IsValid());
    emitSolids("T045", "", apiFixSolid(hollow));
    emitSolids("T046", "", apiFixSolid(multi));
    emitSolids("T048", "", apiSolidFromShellFixed(two));
    r = apiSolidFromShellFixed(one);
    emitSolids("T049", "", r);
    emitBool("T049", "isSolid", r.ShapeType() == TopAbs_SOLID);
    r = apiSolidFromShellFixed(hollow);
    emitSolids("T050", "", r);
    emitBool("T050", "isSolid", r.ShapeType() == TopAbs_SOLID);
    emitSolids("T051", "", apiSolidFromShellFixed(multi));
    // T052: one solid holding the hollow body's two shells and a wider body's shell
    {
      BRep_Builder b;
      TopoDS_Solid three;
      b.MakeSolid(three);
      for (TopExp_Explorer e(hollow, TopAbs_SHELL); e.More(); e.Next())
        b.Add(three, e.Current());
      b.Add(three, firstShell(box(50, 0, 0, 30)));
      emitSolids("T052", "", apiSolidFromShellFixed(three));
    }
    // T053: two free shells; T054: the same free shell twice
    emitSolids("T053", "", apiSolidFromShellFixed(compoundOf({firstShell(box(0, 0, 0, 10)), firstShell(box(20, 0, 0, 10))})));
    {
      TopoDS_Shape sh = firstShell(box(0, 0, 0, 10));
      emitSolids("T054", "", apiSolidFromShellFixed(compoundOf({sh, sh})));
    }
    // T056: the documented direct-children walk on fixSolid(two boxes), and a single box
    {
      TopoDS_Shape healed = apiFixSolid(two);
      int          kids = 0;
      bool         allSolids = true;
      for (TopoDS_Iterator it(healed); it.More(); it.Next())
      {
        kids++;
        allSolids = allSolids && it.Value().ShapeType() == TopAbs_SOLID;
      }
      emitInt("T056", "directChildren", kids);
      emitBool("T056", "allChildrenSolids", allSolids);
      emitInt("T056", "shellsAtAnyDepth", uniq(healed, TopAbs_SHELL));
      emit("T056", "volume", vol(healed));
      TopoDS_Shape single = apiFixSolid(one);
      emitBool("T056", "singleIsSolid", single.ShapeType() == TopAbs_SOLID);
      emitInt("T056", "singleShells", uniq(single, TopAbs_SHELL));
    }
    // T057: the issue's table: the input, fixSolid and solidFromShellFixed of two boxes
    {
      const char*  labels[] = {"input", "fixSolid", "solidFromShellFixed"};
      TopoDS_Shape shapes[] = {two, apiFixSolid(two), apiSolidFromShellFixed(two)};
      for (int i = 0; i < 3; i++)
      {
        emitSolids("T057", labels[i], shapes[i]);
        double x0, x1;
        bounds(shapes[i], x0, x1);
        char k[64];
        snprintf(k, sizeof k, "%s.minX", labels[i]);
        emit("T057", k, x0);
        snprintf(k, sizeof k, "%s.maxX", labels[i]);
        emit("T057", k, x1);
      }
    }
  }

  // Issue 443: solid(from:), solidWithFullHistory(from:), upgraded()
  {
    TopoDS_Shape sewnTwo = apiSew({two});
    emitSolids("T058", "", apiSolidFrom(sewnTwo));
    {
      TopoDS_Shape a = apiSolidFrom(sewnTwo), b = apiSolidFromShellFixed(sewnTwo);
      emitInt("T059", "viaMakeSolid.bodies", uniq(a, TopAbs_SOLID));
      emit("T059", "viaMakeSolid.volume", vol(a));
      emitInt("T059", "viaShapeFix.bodies", uniq(b, TopAbs_SOLID));
      emit("T059", "viaShapeFix.volume", vol(b));
      emitBool("T059", "bodiesAgree", uniq(a, TopAbs_SOLID) == uniq(b, TopAbs_SOLID));
    }
    TopoDS_Shape r = apiSolidFrom(firstShell(box(0, 0, 0, 10)));
    emitSolids("T060", "", r);
    emitBool("T060", "isSolid", r.ShapeType() == TopAbs_SOLID);
    emitBool("T060", "valid", BRepCheck_Analyzer(r).IsValid());
    TopoDS_Shape co = closedAndOpen();
    r               = apiSolidFrom(co);
    emitInt("T061", "bodies", uniq(r, TopAbs_SOLID));
    emitInt("T061", "faces", uniq(r, TopAbs_FACE));
    r = apiSolidFrom(hollow);
    emitSolids("T062", "", r);
    emitBool("T062", "isSolid", r.ShapeType() == TopAbs_SOLID);
    emitSolids("T063", "", apiSolidFrom(multi));
    TopoDS_Shape sewnHollow = apiSew({hollow});
    {
      TopoDS_Shape a = apiSolidFrom(sewnHollow), b = apiSolidFromShellFixed(sewnHollow);
      emitInt("T065", "viaSolidFrom.bodies", uniq(a, TopAbs_SOLID));
      emit("T065", "viaSolidFrom.volume", vol(a));
      emitInt("T065", "viaSolidFromShellFixed.bodies", uniq(b, TopAbs_SOLID));
      emit("T065", "viaSolidFromShellFixed.volume", vol(b));
    }
    {
      TopoDS_Shape a = apiSolidFromShellFixed(hollow), b = apiSolidFromShellFixed(sewnHollow);
      emitInt("T066", "fromSolid.bodies", uniq(a, TopAbs_SOLID));
      emit("T066", "fromSolid.volume", vol(a));
      emitInt("T066", "fromShells.bodies", uniq(b, TopAbs_SOLID));
      emit("T066", "fromShells.volume", vol(b));
      emitBool("T066", "bodiesAgree", uniq(a, TopAbs_SOLID) == uniq(b, TopAbs_SOLID));
    }
    {
      std::vector<TopoDS_Shape> many;
      for (int i = 0; i < 100; i++)
        many.push_back(box(i * 20.0, 0, 0, 10));
      r = apiSolidFrom(apiSew({compoundOf(many)}));
      emitInt("T067", "bodies", uniq(r, TopAbs_SOLID));
      emit("T067", "volume", vol(r));
    }
    r = apiSolidFrom(compoundOf({firstShell(box(0, 0, 0, 10)), firstShell(box(10, 0, 0, 10))}));
    emitInt("T068", "bodies", uniq(r, TopAbs_SOLID));
    emit("T068", "volume", vol(r));
    // history variant: one ShapeBuild_ReShape shared by every body
    {
      Handle(ShapeBuild_ReShape) ctx = new ShapeBuild_ReShape;
      emitSolids("T069", "", apiSolidFrom(sewnTwo, ctx));
    }
    {
      TopoDS_Shape a = box(0, 0, 0, 10), b = box(20, 0, 0, 10);
      Handle(ShapeBuild_ReShape) ctx = new ShapeBuild_ReShape;
      r = apiSolidFrom(compoundOf({firstShell(a), firstShell(b)}), ctx);
      emitInt("T070", "bodies", uniq(r, TopAbs_SOLID));
      Handle(BRepTools_History) h = ctx->History();
      int                       queried = 0, deleted = 0;
      TopoDS_Shape              boxes[] = {a, b};
      for (int i = 0; i < 2; i++)
      {
        TopTools_IndexedMapOfShape fs;
        TopExp::MapShapes(boxes[i], TopAbs_FACE, fs);
        for (int k = 1; k <= fs.Extent(); k++)
        {
          queried++;
          if (!h.IsNull() && h->IsRemoved(fs(k)))
            deleted++;
        }
      }
      emitInt("T070", "facesQueried", queried);
      emitInt("T070", "facesReportedDeleted", deleted);
    }
    {
      Handle(ShapeBuild_ReShape) ctx = new ShapeBuild_ReShape;
      r = apiSolidFrom(firstShell(box(0, 0, 0, 10)), ctx);
      emitInt("T071", "bodies", uniq(r, TopAbs_SOLID));
      emitBool("T071", "isSolid", r.ShapeType() == TopAbs_SOLID);
      emit("T071", "volume", vol(r));
    }
    {
      Handle(ShapeBuild_ReShape) ctx = new ShapeBuild_ReShape;
      r = apiSolidFrom(co, ctx);
      emitInt("T072", "bodies", uniq(r, TopAbs_SOLID));
      emitInt("T072", "faces", uniq(r, TopAbs_FACE));
    }
    // upgraded()
    r = apiUpgraded(two, 1e-6);
    emitSolids("T073", "", r);
    {
      double x0, x1;
      bounds(r, x0, x1);
      emit("T073", "minX", x0);
      emit("T073", "maxX", x1);
    }
    {
      TopTools_IndexedMapOfShape fs;
      TopExp::MapShapes(two, TopAbs_FACE, fs);
      std::vector<TopoDS_Shape> loose;
      for (int k = 1; k <= fs.Extent(); k++)
        loose.push_back(fs(k));
      emitSolids("T074", "", apiUpgraded(compoundOf(loose), 1e-6));
    }
    r = apiUpgraded(one, 1e-6);
    emitSolids("T075", "", r);
    emitBool("T075", "valid", BRepCheck_Analyzer(r).IsValid());
    emit("T076", "inputVolume", vol(hollow));
    r = apiUpgraded(hollow, 1e-6);
    emitInt("T076", "bodies", uniq(r, TopAbs_SOLID));
    emit("T076", "volume", vol(r));
    {
      TopoDS_Shape nested = compoundOf({BRepAlgoAPI_Cut(box(0, 0, 0, 20), box(4, 4, 4, 12)).Shape(), box(6, 6, 6, 8)});
      r                   = apiUpgraded(nested, 1e-6);
      emitInt("T077", "bodies", uniq(r, TopAbs_SOLID));
      emit("T077", "volume", vol(r));
    }
    r = apiUpgraded(co, 1e-6);
    emitInt("T078", "faces", uniq(r, TopAbs_FACE));
    {
      TopTools_IndexedMapOfShape fs;
      TopExp::MapShapes(box(-5, -5, -5, 10), TopAbs_FACE, fs);
      r = apiUpgraded(fs(1), 1e-6);
      emitInt("T079", "bodies", uniq(r, TopAbs_SOLID));
      emitInt("T079", "faces", uniq(r, TopAbs_FACE));
    }
  }
  return 0;
}
