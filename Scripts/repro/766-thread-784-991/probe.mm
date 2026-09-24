// #1990 (epic #766) kernel parity for the two kernel-reaching files of the 784-991 group:
// Issue990ThreadAxisBasisTests and Issue991ThreadProfileFlatWidthTests::cutPathStillCuts.
//
// Part 1: gp_Ax2(origin, axis).YDirection() for the six world axes, which the Swift thread datum
// (perpendicularBasis(to:).1) must equal.
// Part 2: re-measures, in pure OCCT, the solids the Swift tests built. The Swift run wrote each
// solid to BREP (argv[1] directory); this probe reads them back and repeats the test's own
// measurements with the calls the bridge makes: BRepGProp::VolumeProperties(OnlyClosed=true)
// (OCCTShapeGetVolume), BRepClass3d_SolidClassifier at tol 1e-6 (OCCTShapeClassifyPoint) and
// BRepCheck_Analyzer (OCCTShapeIsValid).
#include <BRepCheck_Analyzer.hxx>
#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepGProp.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <GProp_GProps.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Ax2.hxx>
#include <cmath>
#include <cstdio>
#include <limits>
#include <numbers>
#include <string>

static bool load(const std::string& path, TopoDS_Shape& s)
{
  BRep_Builder b;
  return BRepTools::Read(s, path.c_str(), b);
}

static double vol(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p, true);
  return p.Mass();
}

int main(int argc, char** argv)
{
  if (argc < 2)
  {
    std::printf("usage: probe <brep-dir>\n");
    return 2;
  }
  std::string dir = argv[1];
  const char* names[6] = {"+X", "-X", "+Y", "-Y", "+Z", "-Z"};
  const char* files[6] = {"px", "nx", "py", "ny", "pz", "nz"};
  double      ax[6][3] = {{1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0}, {0, 0, 1}, {0, 0, -1}};

  std::printf("== Part 1: gp_Ax2(origin, axis).YDirection()\n");
  for (int i = 0; i < 6; i++)
  {
    gp_Ax2 a2(gp_Pnt(0, 0, 0), gp_Dir(ax[i][0], ax[i][1], ax[i][2]));
    gp_Dir y = a2.YDirection();
    std::printf("%s YDirection = (%.17g, %.17g, %.17g)\n", names[i], y.X(), y.Y(), y.Z());
  }

  std::printf("== Part 2a: Issue990 groove measurement on the Swift-built solids\n");
  // Mirrors Issue990ThreadAxisBasisTests.grooveAngle: nominal 12, pitch 2, ISO-68 cutDepth
  // = 5H/8 with H = P*sqrt(3)/2, probe radius D/2 - cutDepth/2, axial station 2P, 72 samples.
  const double D = 12.0, P = 2.0;
  const double cutDepth = P * std::sqrt(3.0) / 2 * 5 / 8;
  const double probeR = D / 2 - cutDepth / 2;
  const double station = 2 * P;
  for (int i = 0; i < 6; i++)
  {
    TopoDS_Shape shank, threaded;
    if (!load(dir + "/990_" + files[i] + "_shank.brep", shank)
        || !load(dir + "/990_" + files[i] + "_threaded.brep", threaded))
    {
      std::printf("%s: BREP read failed\n", names[i]);
      continue;
    }
    gp_Ax2 a2(gp_Pnt(0, 0, 0), gp_Dir(ax[i][0], ax[i][1], ax[i][2]));
    gp_Dir d = a2.YDirection();
    gp_Dir a(ax[i][0], ax[i][1], ax[i][2]);
    gp_Dir t = a.Crossed(d);
    double x = 0, y = 0;
    int    hits = 0;
    for (int k = 0; k < 72; k++)
    {
      double th = k * 2 * std::numbers::pi / 72;
      gp_Pnt p(station * a.X() + probeR * (std::cos(th) * d.X() + std::sin(th) * t.X()),
               station * a.Y() + probeR * (std::cos(th) * d.Y() + std::sin(th) * t.Y()),
               station * a.Z() + probeR * (std::cos(th) * d.Z() + std::sin(th) * t.Z()));
      BRepClass3d_SolidClassifier c(threaded, p, 1e-6);
      if (c.State() == TopAbs_OUT)
      {
        x += std::cos(th);
        y += std::sin(th);
        hits++;
      }
    }
    double vb = vol(shank), vt = vol(threaded);
    std::printf("%s: degrees=%.6f grooveFraction=%.6f removed=%.9f (blank %.9f, threaded %.9f)\n",
                names[i],
                hits ? std::atan2(y, x) * 180 / std::numbers::pi : std::numeric_limits<double>::quiet_NaN(),
                hits / 72.0,
                vb - vt,
                vb,
                vt);
  }

  std::printf("== Part 2b: Issue991 cutPathStillCuts on the Swift-built solids\n");
  TopoDS_Shape block, tapped;
  if (load(dir + "/991_block.brep", block) && load(dir + "/991_tapped.brep", tapped))
  {
    BRepCheck_Analyzer an(tapped);
    std::printf("block volume=%.9f tapped volume=%.9f tapped valid=%d ratio=%.9f\n",
                vol(block),
                vol(tapped),
                an.IsValid() ? 1 : 0,
                vol(tapped) / vol(block));
  }
  else
    std::printf("991: BREP read failed\n");
  return 0;
}
