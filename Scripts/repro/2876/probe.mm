// #2876: the distance between two parallel surfaces is real, computed, and thrown away.
//
// #2840 measured the defect one layer down, at Extrema_ExtSS / Extrema_ExtCS. This probe measures
// the layer the bridge actually calls, GeomAPI_ExtremaSurfaceSurface and
// GeomAPI_ExtremaCurveSurface, because that is where the API decision lands: OCCTSurfaceExtrema
// builds a GeomAPI_ExtremaSurfaceSurface, and OCCTCurve3DDistanceToSurface builds a
// GeomAPI_ExtremaCurveSurface. It is deliberately a SECOND CONSTRUCTION of #2840's finding rather
// than a re-run of it (okf/policies/measure-dont-assume.md), and the two must agree: 25 as a square
// distance there, 5 as a distance here.
//
// The three questions, and the three things the modes have to keep apart:
//
//   "distance reported, points absent"  LowerDistance() is 5 and NearestPoints() faults.
//   "nothing reported"                  myIsDone false, so LowerDistance() itself raises.
//   "a fabricated zero"                 LowerDistance() returning 0.0, or the caller's zero-filled
//                                       output struct surviving untouched, would look like two
//                                       coincident surfaces. Every mode prints the number.
//
// Modes, one per process, because half of them are expected to die on a signal:
//
//   0  SS, two parallel planes 5 apart, finite UV: IsDone / IsParallel / NbExtrema /
//      LowerDistance. Safe, and the measurement this issue is about.
//   1  SS, the same pair: NearestPoints(). Faults on an unpatched kernel (raises under patch 0044,
//      which is carried and NOT pinned). This is what makes mode 0 "points absent" rather than
//      "points not asked for".
//   2  SS, the same pair over the planes' own +/-2e100 natural domain, no trimming. Confirms the
//      verdict is the geometry's and not the UV box's.
//   3  SS control, two spheres 20 apart, radii 3 and 5: not parallel, LowerDistance 12, and
//      NearestPoints() returns a real pair. Distinguishes "the parallel branch drops the points"
//      from "this build's Points() is broken".
//   4  SS control, two crossing (non-parallel) planes: "nothing reported". They intersect, so
//      there is no extremum at all, NbExtrema() is 0 and LowerDistance() itself raises. This is
//      the case a distance-reporting wrapper must keep separate from a distance of zero.
//   5  SS, two COINCIDENT planes: IsParallel true and LowerDistance a real, measured 0. Without
//      this mode a fabricated zero and a correct zero read the same; with it, mode 0's 5 and mode
//      5's 0 are two different computed numbers from the same code path.
//   6  CS, a line 5 above a plane: IsParallel true, LowerDistance 5. This already works through
//      OCCTCurve3DDistanceToSurface, and it is the asymmetry #2876 is closing: curve-surface
//      answers, surface-surface refuses.
//   7  CS control, a line 40 above a sphere of radius 3: not parallel, LowerDistance 37.
//
//   clang++ -std=c++17 -ObjC++ -w -O0 -g \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/2876/probe.mm -o /tmp/occt_probe_2876
//   for m in 0 1 2 3 4 5 6 7; do /tmp/occt_probe_2876 $m; echo "  mode $m exit=$?"; done
//
// The transcript this produced is committed next to it as transcript.txt.

#include <GeomAPI_ExtremaCurveSurface.hxx>
#include <GeomAPI_ExtremaSurfaceSurface.hxx>
#include <Geom_Line.hxx>
#include <Geom_Plane.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Standard_Failure.hxx>
#include <gp_Ax3.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

#include <cmath>
#include <cstdio>
#include <cstdlib>

static occ::handle<Geom_Plane> planeZ(double z)
{
  return new Geom_Plane(gp_Pnt(0, 0, z), gp_Dir(0, 0, 1));
}

static occ::handle<Geom_SphericalSurface> sphere(double x, double r)
{
  return new Geom_SphericalSurface(gp_Ax3(gp_Pnt(x, 0, 0), gp_Dir(0, 0, 1)), r);
}

// GeomAPI_ExtremaSurfaceSurface over an explicit UV box, which is the bounded Init the bridge's
// OCCTSurfaceExtrema uses. uv1/uv2 are {uMin, uMax, vMin, vMax}.
static void extremaSS(const char*                      label,
                      const occ::handle<Geom_Surface>& s1,
                      const occ::handle<Geom_Surface>& s2,
                      const double                     uv1[4],
                      const double                     uv2[4],
                      bool                             readPoints)
{
  GeomAPI_ExtremaSurfaceSurface ex(s1,
                                   s2,
                                   uv1[0],
                                   uv1[1],
                                   uv1[2],
                                   uv1[3],
                                   uv2[0],
                                   uv2[1],
                                   uv2[2],
                                   uv2[3]);

  std::printf("  %-44s IsParallel=%s NbExtrema=%d",
              label,
              ex.IsParallel() ? "true" : "false",
              ex.NbExtrema());
  // LowerDistance() raises StdFail_NotDone when myIsDone is false, which is the "nothing reported"
  // case, and it must stay distinguishable from a zero distance.
  try
  {
    std::printf(" LowerDistance=%.17g", ex.LowerDistance());
  }
  catch (const Standard_Failure& f)
  {
    std::printf(" LowerDistance raised %s", f.ExceptionType());
  }
  std::printf("\n");
  std::fflush(stdout);

  if (!readPoints)
  {
    return;
  }
  std::printf("    NearestPoints() behind NbExtrema()...\n");
  std::fflush(stdout);
  gp_Pnt p1, p2;
  ex.NearestPoints(p1, p2);
  std::printf("    returned (%.6g %.6g %.6g) (%.6g %.6g %.6g), |p1p2|=%.17g\n",
              p1.X(),
              p1.Y(),
              p1.Z(),
              p2.X(),
              p2.Y(),
              p2.Z(),
              p1.Distance(p2));
  std::fflush(stdout);
}

// GeomAPI_ExtremaCurveSurface, the class OCCTCurve3DDistanceToSurface already reads
// LowerDistance() from. No point read here: #2840 established that it faults the same way, and the
// point of these two modes is the distance.
static void extremaCS(const char*                      label,
                      const occ::handle<Geom_Curve>&   c,
                      double                           cLo,
                      double                           cHi,
                      const occ::handle<Geom_Surface>& s,
                      const double                     uv[4])
{
  GeomAPI_ExtremaCurveSurface ex(c, s, cLo, cHi, uv[0], uv[1], uv[2], uv[3]);

  std::printf("  %-44s IsParallel=%s NbExtrema=%d",
              label,
              ex.IsParallel() ? "true" : "false",
              ex.NbExtrema());
  try
  {
    std::printf(" LowerDistance=%.17g", ex.LowerDistance());
  }
  catch (const Standard_Failure& f)
  {
    std::printf(" LowerDistance raised %s", f.ExceptionType());
  }
  std::printf("\n");
  std::fflush(stdout);
}

int main(int argc, char** argv)
{
  const int mode = (argc > 1) ? std::atoi(argv[1]) : 0;
  std::printf("mode %d\n", mode);

  static const double square[4]   = {-10.0, 10.0, -10.0, 10.0};
  static const double infinite[4] = {-1.0e100, 1.0e100, -1.0e100, 1.0e100};
  static const double ball[4]     = {0.0, 2.0 * M_PI, -M_PI_2, M_PI_2};

  try
  {
    switch (mode)
    {
      case 0:
      case 1:
        extremaSS("SS parallel planes, gap 5, finite UV",
                  planeZ(0),
                  planeZ(5),
                  square,
                  square,
                  mode == 1);
        break;
      case 2:
        extremaSS("SS parallel planes, gap 5, natural domain",
                  planeZ(0),
                  planeZ(5),
                  infinite,
                  infinite,
                  false);
        break;
      case 3:
        extremaSS("SS control, spheres r3/r5 20 apart", sphere(0, 3), sphere(20, 5), ball, ball,
                  true);
        break;
      case 4:
        extremaSS("SS control, crossing planes, no extremum",
                  planeZ(0),
                  new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)),
                  square,
                  square,
                  false);
        break;
      case 5:
        extremaSS("SS coincident planes, a measured zero",
                  planeZ(0),
                  planeZ(0),
                  square,
                  square,
                  false);
        break;
      case 6:
        extremaCS("CS line 5 above a plane",
                  new Geom_Line(gp_Pnt(0, 0, 5), gp_Dir(1, 0, 0)),
                  -10,
                  10,
                  planeZ(0),
                  square);
        break;
      case 7:
        extremaCS("CS control, line 40 above a sphere r3",
                  new Geom_Line(gp_Pnt(0, 0, 40), gp_Dir(1, 0, 0)),
                  -10,
                  10,
                  sphere(0, 3),
                  ball);
        break;
      default:
        std::printf("  unknown mode\n");
        return 2;
    }
  }
  catch (const Standard_Failure& f)
  {
    std::printf("  caught %s: \"%s\"\n", f.ExceptionType(), f.what());
    return 0;
  }
  return 0;
}
