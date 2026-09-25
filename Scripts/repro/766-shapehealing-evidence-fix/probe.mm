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
#include <cmath>
#include <cstdio>
#include <fstream>
#include <sstream>
#include <string>

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
  return 0;
}
