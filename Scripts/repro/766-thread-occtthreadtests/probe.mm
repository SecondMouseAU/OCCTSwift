// #1990 (epic #766): kernel parity for Tests/OCCTThreadTests/OCCTThreadTests.swift.
//
// ThreadedFeatureTests' four tests reach the kernel through OCCTShapeBuildThreadCutter (the
// analytic helicoid cutter, OCCTBridge_AdvancedModeling.mm) plus BRepAlgoAPI_Cut/Fuse, or
// through the Swift-side direct rod build (lofts and sewing, no single bridge entry point).
//
// Part A rebuilds each scenario in pure OCCT with the inputs ThreadFeatures.swift's
// applyThreadCut computes: the bored block (BRepPrimAPI box minus cylinder), the analytic cutter
// (the same GeomAPI_Interpolate / BRepFill::Face / Sewing / MakeSolid sequence the bridge runs,
// transcribed here so the probe needs no bridge), the per-start fuse and the cut, then reports
// BRepGProp volume (OnlyClosed=true, as OCCTShapeGetVolume) and BRepCheck_Analyzer validity.
//
// Part B reads the BREP files the Swift run exported (argv[1] = directory, argv[2..] = names) and re-measures each
// one with the same two kernel calls, for the direct-build shaft, whose construction is Swift
// composition of already-wrapped primitives rather than one OCCT algorithm.
//
// Build: see CLAUDE.md "Compile a Ground Truth C++ Test" (-I/-L at the resolved xcframework).

#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeSolid.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFill.hxx>
#include <BRepGProp.hxx>
#include <BRepLib.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <GProp_GProps.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Solid.hxx>
#include <cmath>
#include <cstdio>
#include <string>

static double vol(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p, Standard_True);
  return p.Mass();
}

static int valid(const TopoDS_Shape& s) { return BRepCheck_Analyzer(s).IsValid() ? 1 : 0; }

static int nfaces(const TopoDS_Shape& s)
{
  int n = 0;
  for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next())
    ++n;
  return n;
}

// Transcription of OCCTShapeBuildThreadCutter's body, same arguments.
static TopoDS_Shape cutter(gp_Vec O, gp_Vec A, gp_Vec R0, double pitch, double turns,
                           double apexSign, double helixRadius, double cutDepth,
                           double outerHalf, double apexHalf, double bleed, double phase,
                           double handed, int N)
{
  const gp_Vec T0     = A.Crossed(R0);
  const double outerR = helixRadius - apexSign * bleed;
  const double apexR  = helixRadius + apexSign * cutDepth;
  const double cr[4]  = {outerR, apexR, apexR, outerR};
  const double cz[4]  = {-outerHalf, -apexHalf, apexHalf, outerHalf};
  TopoDS_Edge  edges[4];
  for (int k = 0; k < 4; ++k)
  {
    Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, N + 1);
    for (int i = 0; i <= N; ++i)
    {
      const double fr     = (double)i / (double)N;
      const double theta  = handed * (phase + 2.0 * M_PI * turns * fr);
      const double zc     = pitch * turns * fr + cz[k];
      const gp_Vec radial = R0 * std::cos(theta) + T0 * std::sin(theta);
      const gp_Vec P      = O + A * zc + radial * cr[k];
      pts->SetValue(i + 1, gp_Pnt(P.X(), P.Y(), P.Z()));
    }
    GeomAPI_Interpolate interp(pts, Standard_False, 1e-7);
    interp.Perform();
    edges[k] = BRepBuilderAPI_MakeEdge(interp.Curve());
  }
  BRepBuilderAPI_Sewing sewer(1e-6);
  for (int k = 0; k < 4; ++k)
    sewer.Add(BRepFill::Face(edges[k], edges[(k + 1) % 4]));
  for (int cap = 0; cap < 2; ++cap)
  {
    const double               theta  = handed * (phase + 2.0 * M_PI * turns * cap);
    const double               zbase  = pitch * turns * cap;
    const gp_Vec               radial = R0 * std::cos(theta) + T0 * std::sin(theta);
    BRepBuilderAPI_MakePolygon poly;
    for (int k = 0; k < 4; ++k)
    {
      const gp_Vec P = O + A * (zbase + cz[k]) + radial * cr[k];
      poly.Add(gp_Pnt(P.X(), P.Y(), P.Z()));
    }
    poly.Close();
    sewer.Add(BRepBuilderAPI_MakeFace(poly.Wire(), Standard_True).Face());
  }
  sewer.Perform();
  TopExp_Explorer se(sewer.SewedShape(), TopAbs_SHELL);
  TopoDS_Solid    solid = BRepBuilderAPI_MakeSolid(TopoDS::Shell(se.Current())).Solid();
  BRepLib::OrientClosedSolid(solid);
  return solid;
}

struct Spec
{
  double d, p;
  double cutDepth() const { return p * std::sqrt(3.0) / 2 * 5 / 8; }
  double minor() const { return d - 2 * cutDepth(); }
  double rootFlat() const { return p / 4; }
};

// Shape.box(width:height:depth:) is centred on the origin (OCCTShapeCreateBox), so the block spans
// -15..15 on every axis. `ax` is where the bore axis starts: (15,15,0) is the fixture the tests
// shipped with (the block's +X+Y corner edge), (0,0,-15) is the rewritten one (the block's centre).
static TopoDS_Shape bored(const Spec& s, gp_Pnt ax)
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-15, -15, -15), 30, 30, 30).Shape();
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(gp_Ax2(ax, gp_Dir(0, 0, 1)), s.minor() / 2, 30).Shape();
  return BRepAlgoAPI_Cut(box, cyl).Shape();
}

// applyThreadCut's analytic branch for an internal thread (apexSign +1) on the +Z axis.
static TopoDS_Shape analyticHole(const TopoDS_Shape& blank, const Spec& s, gp_Pnt ax,
                                 double length, int starts, double handed)
{
  const double turns     = length / s.p;
  const double bleed     = std::max(s.cutDepth() * 0.05, 1e-3);
  const double apexHalf  = s.rootFlat() / 2;
  const double outerHalf = apexHalf + (s.cutDepth() + bleed) * std::tan(M_PI / 6);
  const int    n         = (int)std::min(400.0, std::max(64.0, std::round(turns * 24)));
  // perpendicularBasis(+Z).1 = (0,1,0), the radial0 ThreadFeatures.swift passes.
  TopoDS_Shape combined;
  for (int k = 0; k < starts; ++k)
  {
    TopoDS_Shape c = cutter(gp_Vec(ax.XYZ()), gp_Vec(0, 0, 1), gp_Vec(0, 1, 0), s.p, turns, +1,
                            s.minor() / 2, s.cutDepth(), outerHalf, apexHalf, bleed,
                            2 * M_PI * k / starts, handed, n);
    combined = (k == 0) ? c : BRepAlgoAPI_Fuse(combined, c).Shape();
  }
  return BRepAlgoAPI_Cut(blank, combined).Shape();
}

static void scenarios(const char* tag, gp_Pnt ax)
{
  Spec         m10{10, 1.5};
  TopoDS_Shape b1 = bored(m10, ax);
  printf("[%s]\n", tag);
  printf("  M10x1.5 minor=%.9f cutDepth=%.9f\n", m10.minor(), m10.cutDepth());
  printf("  bored        vol=%.9f valid=%d faces=%d\n", vol(b1), valid(b1), nfaces(b1));
  TopoDS_Shape h1 = analyticHole(b1, m10, ax, 20, 1, +1);
  printf("  hole d=20    analytic vol=%.9f valid=%d faces=%d\n", vol(h1), valid(h1), nfaces(h1));
  TopoDS_Shape rh = analyticHole(b1, m10, ax, 10, 1, +1);
  TopoDS_Shape lh = analyticHole(b1, m10, ax, 10, 1, -1);
  printf("  rh d=10      analytic vol=%.9f valid=%d faces=%d\n", vol(rh), valid(rh), nfaces(rh));
  printf("  lh d=10      analytic vol=%.9f valid=%d faces=%d\n", vol(lh), valid(lh), nfaces(lh));
  Spec         s2{10, 2.0};
  TopoDS_Shape b4 = bored(s2, ax);
  printf("  bored P2     vol=%.9f valid=%d faces=%d\n", vol(b4), valid(b4), nfaces(b4));
  TopoDS_Shape one = analyticHole(b4, s2, ax, 10, 1, +1);
  TopoDS_Shape two = analyticHole(b4, s2, ax, 10, 2, +1);
  printf("  1-start P2   analytic vol=%.9f valid=%d faces=%d\n", vol(one), valid(one), nfaces(one));
  printf("  2-start P2   analytic vol=%.9f valid=%d faces=%d\n", vol(two), valid(two), nfaces(two));
}

int main(int argc, char** argv)
{
  printf("== Part A: pure-OCCT rebuild of each ThreadedFeatureTests scenario ==\n");
  scenarios("shipped fixture, axis on the block's corner edge (15,15,0)", gp_Pnt(15, 15, 0));
  scenarios("rewritten fixture, axis through the block's centre from (0,0,-15)",
            gp_Pnt(0, 0, -15));
  TopoDS_Shape shaft = BRepPrimAPI_MakeCylinder(5, 30).Shape();
  printf("shaft r5 h30  vol=%.9f valid=%d faces=%d\n", vol(shaft), valid(shaft), nfaces(shaft));

  if (argc > 1)
  {
    printf("== Part B: kernel re-measure of the shapes the Swift run exported ==\n");
    for (int i = 2; i < argc; ++i)
    {
      TopoDS_Shape s;
      BRep_Builder bb;
      std::string  path = std::string(argv[1]) + "/" + argv[i] + ".brep";
      if (!BRepTools::Read(s, path.c_str(), bb))
      {
        printf("%-18s (no file)\n", argv[i]);
        continue;
      }
      printf("%-18s vol=%.9f valid=%d faces=%d\n", argv[i], vol(s), valid(s), nfaces(s));
    }
  }
  return 0;
}
