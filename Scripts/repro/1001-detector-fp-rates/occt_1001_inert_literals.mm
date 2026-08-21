// Spot-check probe for the FALSE verdicts in the detect-hardcoded-arguments.py census (#1001).
//
// Most of those verdicts rest on "the literal is inert on the path this bridge function actually
// takes", which was first established by reading the kernel source. Reading the source is the
// weaker construction, so this measures it instead: each family below is rebuilt exactly as the
// bridge builds it, with the literal swept across four orders of magnitude, and the output printed.
// A family whose output does not move across the sweep is inert on that path.
//
// TWO POSITIVE CONTROLS, and they are the point of the probe rather than decoration. A sweep that
// reports "nothing moved" is indistinguishable from a sweep that cannot detect movement, so two
// families where the literal IS load-bearing are swept the same way:
//
//   * GCPnts_TangentialDeflection's two deflections, which set a point count.
//   * GeomFill_SimpleBound's Tol3d as seen by GeomFill_ConstrainedFilling, which is the one
//     GeomFill site whose bound is actually read (GeomFill_ConstrainedFilling.cxx:231, :426, :707,
//     :711 are the only readers of Tol3d()/Tolang() in the whole package).
//
// Both controls must move, or the rows reported as inert prove nothing.
//
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/1001-detector-fp-rates/occt_1001_inert_literals.mm -o /tmp/occt_1001_inert
//   /tmp/occt_1001_inert

#include <Adaptor3d_CurveOnSurface.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <Extrema_ExtCS.hxx>
#include <Extrema_ExtPS.hxx>
#include <Extrema_ExtSS.hxx>
#include <GCPnts_TangentialDeflection.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <Geom2d_Line.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <GeomFill_BoundWithSurf.hxx>
#include <GeomFill_ConstrainedFilling.hxx>
#include <GeomFill_CoonsAlgPatch.hxx>
#include <GeomFill_DegeneratedBound.hxx>
#include <GeomFill_SimpleBound.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Plane.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <GC_MakeSegment.hxx>
#include <gp_Ax3.hxx>
#include <gp_Pnt.hxx>

#include <cstdio>
#include <string>
#include <vector>

namespace
{

// Four orders of magnitude, spanning the shipped literals (1e-6, 1e-4, 1e-3, 1e-2, 0.1).
const std::vector<double> WIDE = {1e-6, 1e-4, 1e-2, 1.0};

// The measured bit-identical plateau containing the shipped Extrema literal of 1e-6.
//
// The wide sweep moves that family at 1.0, so its FALSE verdict cannot rest on the literal being
// inert, and the question becomes whether the shipped value sits on a plateau. A first draft of
// this probe answered that by loosening the comparison to a relative tolerance, which is choosing
// a number to make the run pass. Measured instead, over five repetitions of a sweep from 1e-9 to
// 1e-2: every row is byte-identical across all five, so there is NO run-to-run spread and no
// tolerance to derive. What moves is a deterministic function of the tolerance, with two step
// changes bracketing the shipped value:
//
//   Extrema_ExtCS squared distance steps at 1e-9 -> 1e-8   (36.713066051563104 -> 36.713066047401135)
//   Extrema_ExtSS squared distance steps at 1e-5 -> 1e-4   (121 -> 121.00000000000033)
//
// So the plateau is 1e-8 to 1e-5, the shipped 1e-6 sits one order inside each edge of it, and the
// comparison here stays bit-identical over exactly that range.
const std::vector<double> NARROW = {1e-8, 1e-7, 1e-6, 1e-5};

Handle(Geom_TrimmedCurve) segment(double x1, double y1, double z1,
                                  double x2, double y2, double z2)
{
  return GC_MakeSegment(gp_Pnt(x1, y1, z1), gp_Pnt(x2, y2, z2)).Value();
}

// A quadratic Bezier through three poles: the two corners the loop has to keep, and a middle pole
// pulled out of the plane so the boundary is genuinely curved.
Handle(Geom_BezierCurve) bulge(double x1, double y1, double z1,
                               double mx, double my, double mz,
                               double x2, double y2, double z2)
{
  NCollection_Array1<gp_Pnt> poles(1, 3);
  poles(1) = gp_Pnt(x1, y1, z1);
  poles(2) = gp_Pnt(mx, my, mz);
  poles(3) = gp_Pnt(x2, y2, z2);
  return new Geom_BezierCurve(poles);
}

// --- the four families the census reports as inert ------------------------------------------

// OCCTGeomFillCoonsAlgPatchEval (OCCTBridge_Surface.mm): four SimpleBounds into a CoonsAlgPatch,
// evaluated with Value(u, v). The patch never asks its bounds for a tolerance.
std::string coonsAlgPatch(double tol)
{
  Handle(GeomFill_SimpleBound) b1 =
    new GeomFill_SimpleBound(new GeomAdaptor_Curve(segment(0, 0, 0, 10, 0, 0)), tol, tol);
  Handle(GeomFill_SimpleBound) b2 =
    new GeomFill_SimpleBound(new GeomAdaptor_Curve(segment(10, 0, 0, 10, 10, 3)), tol, tol);
  Handle(GeomFill_SimpleBound) b3 =
    new GeomFill_SimpleBound(new GeomAdaptor_Curve(segment(10, 10, 3, 0, 10, 0)), tol, tol);
  Handle(GeomFill_SimpleBound) b4 =
    new GeomFill_SimpleBound(new GeomAdaptor_Curve(segment(0, 10, 0, 0, 0, 0)), tol, tol);
  GeomFill_CoonsAlgPatch patch(b1, b2, b3, b4);
  char                   buf[128];
  gp_Pnt                 a = patch.Value(0.25, 0.4);
  gp_Pnt                 b = patch.Value(0.75, 0.9);
  snprintf(buf, sizeof(buf), "(%.17g, %.17g, %.17g) (%.17g, %.17g, %.17g)",
           a.X(), a.Y(), a.Z(), b.X(), b.Y(), b.Z());
  return buf;
}

// OCCTGeomFillBoundWithSurfEvaluate (OCCTBridge_Surface.mm): Value / HasNormals / Norm only.
std::string boundWithSurf(double tol)
{
  Handle(Geom_CylindricalSurface) cyl =
    new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0);
  Handle(Geom2d_Line)         line = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 1));
  Handle(Geom2dAdaptor_Curve) ac   = new Geom2dAdaptor_Curve(line, 0, 3);
  Handle(GeomAdaptor_Surface) as   = new GeomAdaptor_Surface(cyl);
  Adaptor3d_CurveOnSurface    cos(ac, as);

  Handle(GeomFill_BoundWithSurf) bws = new GeomFill_BoundWithSurf(cos, tol, tol);
  char                           buf[192];
  gp_Pnt                         v = bws->Value(1.5);
  gp_Vec                         n = bws->HasNormals() ? bws->Norm(1.5) : gp_Vec(0, 0, 0);
  snprintf(buf, sizeof(buf), "value (%.17g, %.17g, %.17g) normals %d norm (%.17g, %.17g, %.17g)",
           v.X(), v.Y(), v.Z(), (int)bws->HasNormals(), n.X(), n.Y(), n.Z());
  return buf;
}

// OCCTGeomFillDegeneratedBoundValue / ...IsDegenerated (OCCTBridge_Surface.mm).
std::string degeneratedBound(double tol)
{
  Handle(GeomFill_DegeneratedBound) db =
    new GeomFill_DegeneratedBound(gp_Pnt(1, 2, 3), 0.0, 1.0, tol, tol);
  char   buf[160];
  gp_Pnt v = db->Value(0.4);
  snprintf(buf, sizeof(buf), "value (%.17g, %.17g, %.17g) degenerated %d",
           v.X(), v.Y(), v.Z(), (int)db->IsDegenerated());
  return buf;
}

// OCCTExtremaExtCS / OCCTExtremaExtPS / OCCTExtremaExtSS (Curve3D.mm and Surface.mm). The two
// doubles are TolU/TolV, iteration stop conditions, not domain bounds.
std::string extrema(double tol)
{
  Handle(Geom_Plane)          pl  = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  Handle(GeomAdaptor_Surface) as  = new GeomAdaptor_Surface(pl, -20, 20, -20, 20);
  // NOT a second plane: two parallel planes make Extrema_ExtSS report IsParallel, so every sweep
  // row printed the same -1 and the SS third of this fixture proved nothing either way. A cylinder
  // whose axis runs along X at height 9, radius 2, has a unique nearest point to the plane patch at
  // squared distance 49.
  Handle(Geom_CylindricalSurface) cyl2 =
    new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 9), gp_Dir(1, 0, 0)), 2.0);
  Handle(GeomAdaptor_Surface) as2 = new GeomAdaptor_Surface(cyl2, 0, 6.28318530717958647, -5, 5);
  Handle(GeomAdaptor_Curve)   ac =
    new GeomAdaptor_Curve(segment(-3, -4, 6, 8, 9, 11), 0, segment(-3, -4, 6, 8, 9, 11)->LastParameter());

  Extrema_ExtCS cs(*ac, *as, tol, tol);
  Extrema_ExtPS ps(gp_Pnt(2, 3, 9), *as, tol, tol);
  Extrema_ExtSS ss(*as, *as2, tol, tol);

  char buf[224];
  snprintf(buf, sizeof(buf),
           "CS done %d n %d d %.17g | PS done %d n %d d %.17g | SS done %d n %d d %.17g",
           (int)cs.IsDone(), cs.IsDone() && !cs.IsParallel() ? cs.NbExt() : -1,
           cs.IsDone() && !cs.IsParallel() && cs.NbExt() >= 1 ? cs.SquareDistance(1) : -1.0,
           (int)ps.IsDone(), ps.IsDone() ? ps.NbExt() : -1,
           ps.IsDone() && ps.NbExt() >= 1 ? ps.SquareDistance(1) : -1.0,
           (int)ss.IsDone(), ss.IsDone() && !ss.IsParallel() ? ss.NbExt() : -1,
           ss.IsDone() && !ss.IsParallel() && ss.NbExt() >= 1 ? ss.SquareDistance(1) : -1.0);
  return buf;
}

// --- the two positive controls ---------------------------------------------------------------

// OCCTWireExplorerGetEdge / ...GetEdgePointCount (OCCTBridge_Topology.mm). The two literals are an
// angular and a curvature deflection, and they set the point count.
std::string tangentialDeflection(double tol)
{
  Handle(Geom_CylindricalSurface) cyl =
    new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0);
  Handle(Geom2d_Line)      line = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0.3));
  TopoDS_Edge              edge = BRepBuilderAPI_MakeEdge(line, cyl, 0, 6).Edge();
  BRepAdaptor_Curve        curve(edge);
  GCPnts_TangentialDeflection disc(curve, tol, tol);
  char                     buf[64];
  snprintf(buf, sizeof(buf), "points %d", disc.NbPoints());
  return buf;
}

// OCCTGeomFillConstrained (OCCTBridge_Surface.mm). Same SimpleBound as the first family, but read
// this time, because GeomFill_ConstrainedFilling is the one class in the package that asks.
std::string constrainedFilling(double tol)
{
  // The first version of this control used the same four straight segments as the CoonsAlgPatch
  // fixture, and came back INERT: a quad of straight edges fits exactly as a 2x2, degree 1x1
  // surface at every tolerance, so the control could not have detected movement and proved nothing
  // about the three families reported inert beside it. Curved, out-of-plane boundaries give the
  // approximation something to trade against the tolerance.
  Handle(GeomFill_SimpleBound) b1 =
    new GeomFill_SimpleBound(new GeomAdaptor_Curve(bulge(0, 0, 0, 5, -2, 4, 10, 0, 0)), tol, tol);
  Handle(GeomFill_SimpleBound) b2 =
    new GeomFill_SimpleBound(new GeomAdaptor_Curve(bulge(10, 0, 0, 13, 5, -3, 10, 10, 3)), tol, tol);
  Handle(GeomFill_SimpleBound) b3 =
    new GeomFill_SimpleBound(new GeomAdaptor_Curve(bulge(10, 10, 3, 5, 13, 6, 0, 10, 0)), tol, tol);
  Handle(GeomFill_SimpleBound) b4 =
    new GeomFill_SimpleBound(new GeomAdaptor_Curve(bulge(0, 10, 0, -3, 5, -4, 0, 0, 0)), tol, tol);

  GeomFill_ConstrainedFilling filler(8, 15);
  filler.Init(b1, b2, b3, b4);
  Handle(Geom_BSplineSurface) s = filler.Surface();
  char                        buf[160];
  if (s.IsNull())
    return "null surface";
  gp_Pnt p = s->Value(0.5 * (s->UKnot(1) + s->UKnot(s->NbUKnots())),
                      0.5 * (s->VKnot(1) + s->VKnot(s->NbVKnots())));
  snprintf(buf, sizeof(buf), "poles %dx%d degree %dx%d mid (%.17g, %.17g, %.17g)",
           s->NbUPoles(), s->NbVPoles(), s->UDegree(), s->VDegree(), p.X(), p.Y(), p.Z());
  return buf;
}

struct Family
{
  const char*                name;
  const char*                sites;
  std::string                (*run)(double);
  const std::vector<double>* sweep;
  bool                       expectInert;
  const char*                establishes;
};

const Family FAMILIES[] = {
  {"GeomFill_SimpleBound -> CoonsAlgPatch", "Surface.mm:3379-3382", coonsAlgPatch, &WIDE, true,
   "the patch never reads its bounds' tolerance, so the literal cannot be displacing anything"},
  {"GeomFill_BoundWithSurf", "Surface.mm:4008", boundWithSurf, &WIDE, true,
   "Value/HasNormals/Norm never read Tol3d or Tolang"},
  {"GeomFill_DegeneratedBound", "Surface.mm:3952,3973", degeneratedBound, &WIDE, true,
   "Value/IsDegenerated never read Tol3d or Tolang"},
  {"Extrema_ExtCS / ExtPS / ExtSS TolU,TolV, wide", "Curve3D.mm:3310,3338 Surface.mm:4843-4919",
   extrema, &WIDE, false,
   "the literal IS load-bearing at 1.0, so this row's FALSE verdict cannot rest on inertness"},
  {"Extrema_ExtCS / ExtPS / ExtSS TolU,TolV, narrow", "Curve3D.mm:3310,3338 Surface.mm:4843-4919",
   extrema, &NARROW, true,
   "the shipped 1e-6 is bit-identical across the measured plateau 1e-8 to 1e-5, one order inside "
   "each edge, so it is a defensible default rather than a displaced parameter"},
  {"CONTROL GCPnts_TangentialDeflection", "Topology.mm:145,180", tangentialDeflection, &WIDE, false,
   "the harness can detect movement, coarsely"},
  {"CONTROL GeomFill_SimpleBound -> ConstrainedFilling", "Surface.mm:2180-2194",
   constrainedFilling, &WIDE, false,
   "the harness can detect movement in the GeomFill_SimpleBound family specifically"},
};

} // namespace

int main()
{
  int wrong = 0;
  for (const Family& f : FAMILIES)
  {
    printf("== %s   (%s)\n", f.name, f.sites);
    std::vector<std::string> out;
    for (double t : *f.sweep)
    {
      std::string r;
      try
      {
        r = f.run(t);
      }
      catch (...)
      {
        r = "threw";
      }
      out.push_back(r);
      printf("   %-8g %s\n", t, r.c_str());
    }
    bool inert = true;
    for (size_t i = 1; i < out.size(); ++i)
      if (out[i] != out[0])
        inert = false;
    const char* verdict = inert ? "INERT across the sweep" : "MOVES across the sweep";
    bool        asExpected = (inert == f.expectInert);
    printf("   -> %s%s\n      establishes: %s\n\n", verdict,
           asExpected ? "" : "   [NOT AS EXPECTED]", f.establishes);
    if (!asExpected)
      ++wrong;
  }
  printf("%d family/families did not behave as the census verdict assumes\n", wrong);
  return wrong == 0 ? 0 : 1;
}
