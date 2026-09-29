// #2840: Extrema_ExtSS::Points and Extrema_ExtCS::Points read an empty point sequence when the
// analytic branch reported a parallel pair.
//
// Both classes count extrema with NbExt() == mySqDist.Length() and bound Points() against that
// count alone. Their analytic parallel branches (Extrema_ExtSS.cxx:226-234,
// Extrema_ExtCS.cxx:302-306) append one entry to mySqDist and NOTHING to the point sequences, so
// index 1 passes the range test and then reads Value(1) on an empty NCollection_Sequence. The
// bounds check that would have caught it lives in NCollection_Sequence::Value as an inline
// Standard_OutOfRange_Raise_if, which BUILD_RELEASE_DISABLE_EXCEPTIONS compiles out, so the read is
// an OS fault rather than a throw. #636 / carried patch 0024 is the same defect in Extrema_ExtCC.
//
// Patch 0044 bounds each Points() against its own point sequence instead, so the same call raises
// Standard_OutOfRange, which this probe catches and reports.
//
// Modes, each run in its own process because half of them are expected to die on a signal:
//
//   0  ExtSS, two parallel planes: IsDone / IsParallel / NbExt / SquareDistance. Always safe.
//   1  ExtSS, two parallel planes: Points(1, ...). Faults unpatched, raises patched.
//   2  ExtCS, a line parallel to a plane: IsDone / IsParallel / NbExt / SquareDistance. Safe.
//   3  ExtCS, a line parallel to a plane: Points(1, ...). Faults unpatched, raises patched.
//   4  ExtSS control, two separated spheres: every Points(i, ...) must keep working.
//   5  ExtCS control, a line and a sphere: same.
//
// Modes 4 and 5 are what makes modes 1 and 3 evidence rather than a coincidence: the new bound is
// tighter, so a patch that simply broke Points() for everything would satisfy 1 and 3 alone.
//
//   clang++ -std=c++17 -ObjC++ -w -O0 -g \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/2840/probe.mm -o /tmp/occt_probe_2840
//   for m in 0 1 2 3 4 5; do /tmp/occt_probe_2840 $m; echo "  mode $m exit=$?"; done
//
// To measure the patched kernel without a full rebuild, compile the patched Extrema_ExtSS.cxx and
// Extrema_ExtCS.cxx standalone and link them AHEAD of libOCCT-macos.a; see
// okf/policies/upstream-occt-patch-process.md section 3.

#include <Extrema_ExtCS.hxx>
#include <Extrema_ExtSS.hxx>
#include <Extrema_POnCurv.hxx>
#include <Extrema_POnSurf.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomAdaptor_Surface.hxx>
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

static occ::handle<Geom_Plane> plane(double z)
{
  return new Geom_Plane(gp_Pnt(0, 0, z), gp_Dir(0, 0, 1));
}

static occ::handle<Geom_SphericalSurface> sphere(double x, double r)
{
  return new Geom_SphericalSurface(gp_Ax3(gp_Pnt(x, 0, 0), gp_Dir(0, 0, 1)), r);
}

// Extrema_ExtSS over two surfaces, trimmed to finite UV so the analytic branch is reached with real
// bounds rather than a Geom_Plane's +/-2e100 natural domain.
static void extSS(const char*                      label,
                  const occ::handle<Geom_Surface>& s1,
                  const occ::handle<Geom_Surface>& s2,
                  const double                     uv1[4],
                  const double                     uv2[4],
                  bool                             readPoints)
{
  GeomAdaptor_Surface a1(s1, uv1[0], uv1[1], uv1[2], uv1[3]);
  GeomAdaptor_Surface a2(s2, uv2[0], uv2[1], uv2[2], uv2[3]);
  Extrema_ExtSS       ext(a1, a2, 1e-6, 1e-6);

  std::printf("  %-36s IsDone=%s", label, ext.IsDone() ? "true" : "false");
  if (!ext.IsDone())
  {
    std::printf("\n");
    return;
  }
  std::printf(" IsParallel=%s NbExt=%d", ext.IsParallel() ? "true" : "false", ext.NbExt());
  if (ext.NbExt() > 0)
  {
    std::printf(" SquareDistance(1)=%.6g", ext.SquareDistance(1));
  }
  std::printf("\n");
  std::fflush(stdout);

  if (!readPoints)
  {
    return;
  }
  for (int i = 1; i <= ext.NbExt(); ++i)
  {
    std::printf("    Points(%d, ...) behind the NbExt() guard...\n", i);
    std::fflush(stdout);
    Extrema_POnSurf p1, p2;
    ext.Points(i, p1, p2);
    std::printf("    returned (%.6g %.6g %.6g) (%.6g %.6g %.6g)\n",
                p1.Value().X(),
                p1.Value().Y(),
                p1.Value().Z(),
                p2.Value().X(),
                p2.Value().Y(),
                p2.Value().Z());
    std::fflush(stdout);
  }
}

static void extCS(const char*                      label,
                  const occ::handle<Geom_Curve>&   c,
                  double                           cLo,
                  double                           cHi,
                  const occ::handle<Geom_Surface>& s,
                  const double                     uv[4],
                  bool                             readPoints)
{
  GeomAdaptor_Curve   ac(c, cLo, cHi);
  GeomAdaptor_Surface as(s, uv[0], uv[1], uv[2], uv[3]);
  Extrema_ExtCS       ext(ac, as, 1e-6, 1e-6);

  std::printf("  %-36s IsDone=%s", label, ext.IsDone() ? "true" : "false");
  if (!ext.IsDone())
  {
    std::printf("\n");
    return;
  }
  std::printf(" IsParallel=%s NbExt=%d", ext.IsParallel() ? "true" : "false", ext.NbExt());
  if (ext.NbExt() > 0)
  {
    std::printf(" SquareDistance(1)=%.6g", ext.SquareDistance(1));
  }
  std::printf("\n");
  std::fflush(stdout);

  if (!readPoints)
  {
    return;
  }
  for (int i = 1; i <= ext.NbExt(); ++i)
  {
    std::printf("    Points(%d, ...) behind the NbExt() guard...\n", i);
    std::fflush(stdout);
    Extrema_POnCurv pc;
    Extrema_POnSurf ps;
    ext.Points(i, pc, ps);
    std::printf("    returned (%.6g %.6g %.6g) (%.6g %.6g %.6g)\n",
                pc.Value().X(),
                pc.Value().Y(),
                pc.Value().Z(),
                ps.Value().X(),
                ps.Value().Y(),
                ps.Value().Z());
    std::fflush(stdout);
  }
}

int main(int argc, char** argv)
{
  const int mode = (argc > 1) ? std::atoi(argv[1]) : 0;
  std::printf("mode %d\n", mode);

  // A plane trimmed to a finite square, and a sphere over its whole natural domain.
  static const double square[4] = {-10.0, 10.0, -10.0, 10.0};
  static const double ball[4]   = {0.0, 2.0 * M_PI, -M_PI_2, M_PI_2};

  try
  {
    switch (mode)
    {
      case 0:
      case 1:
        extSS("ExtSS parallel planes, gap 5", plane(0), plane(5), square, square, mode == 1);
        break;
      case 2:
      case 3:
        extCS("ExtCS line parallel to plane, gap 5",
              new Geom_Line(gp_Pnt(0, 0, 5), gp_Dir(1, 0, 0)),
              -10,
              10,
              plane(0),
              square,
              mode == 3);
        break;
      case 4:
        extSS("ExtSS control, spheres 20 apart", sphere(0, 3), sphere(20, 5), ball, ball, true);
        break;
      case 5:
        extCS("ExtCS control, line 40 above a sphere",
              new Geom_Line(gp_Pnt(0, 0, 40), gp_Dir(1, 0, 0)),
              -10,
              10,
              sphere(0, 3),
              ball,
              true);
        break;
      default:
        std::printf("unknown mode\n");
        return 2;
    }
  }
  catch (Standard_Failure const& f)
  {
    std::printf("    caught %s: \"%s\"\n", f.ExceptionType(), f.what());
    std::printf("mode %d finished, the read was refused rather than faulting\n", mode);
    return 0;
  }
  catch (...)
  {
    std::printf("    caught an unknown C++ exception\n");
    return 1;
  }
  std::printf("mode %d finished without dying\n", mode);
  return 0;
}
