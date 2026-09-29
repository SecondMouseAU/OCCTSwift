// #2831 channel two: is a count-accessor guard real protection for GeomAPI_ExtremaSurfaceSurface?
//
// GeomAPI_ExtremaSurfaceSurface::NbExtrema() returns myExtSS.NbExt() when myIsDone, and myIsDone is
// myExtSS.IsDone() && (myExtSS.NbExt() > 0). Extrema_ExtSS::NbExt() is mySqDist.Length(), and its
// analytic parallel branch (Extrema_ExtSS.cxx:226-234) appends ONE entry to mySqDist and NOTHING to
// myPOnS1/myPOnS2. So on parallel surfaces NbExtrema() reports 1 while there is no point behind it,
// and Extrema_ExtSS::Points bounds only against NbExt(), so Points(1, ...) reads
// myPOnS1.Value(1) on an empty NCollection_Sequence. That is #636's shape, one class over.
//
// mode 0 (default): report IsDone/IsParallel/NbExtrema/LowerDistance, which are all safe.
// mode 1: call NearestPoints(), the read the count guard is supposed to be protecting.
// mode 2: the same through LowerDistanceParameters(), the other accessor the bridge reads.
//
// Run each mode in its own process and look at the exit status: modes 1 and 2 are expected to die
// on a signal, uncatchably, because BUILD_RELEASE_DISABLE_EXCEPTIONS compiles out the
// Standard_OutOfRange_Raise_if inside NCollection_Sequence::Value.
//
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/2831/probe.mm -o /tmp/occt_probe_2831
//   for m in 0 1 2; do /tmp/occt_probe_2831 $m; echo "  mode $m exit=$?"; done

#include <GeomAPI_ExtremaSurfaceSurface.hxx>
#include <Geom_Plane.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

#include <cstdio>
#include <cstdlib>

static void run(int mode, const char* label, double lo, double hi)
{
  occ::handle<Geom_Plane> p1 = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  occ::handle<Geom_Plane> p2 = new Geom_Plane(gp_Pnt(0, 0, 5), gp_Dir(0, 0, 1));

  try
  {
    GeomAPI_ExtremaSurfaceSurface ext(p1, p2, lo, hi, lo, hi, lo, hi, lo, hi);
    std::printf("  %-28s NbExtrema=%d IsParallel=%s",
                label,
                ext.NbExtrema(),
                ext.IsParallel() ? "true" : "false");
    if (ext.NbExtrema() > 0)
    {
      std::printf(" LowerDistance=%.6g", ext.LowerDistance());
    }
    std::printf("\n");
    std::fflush(stdout);

    if (mode == 1 && ext.NbExtrema() > 0)
    {
      std::printf("    calling NearestPoints() behind the NbExtrema() > 0 guard...\n");
      std::fflush(stdout);
      gp_Pnt a, b;
      ext.NearestPoints(a, b);
      std::printf("    returned (%.6g %.6g %.6g) (%.6g %.6g %.6g)\n",
                  a.X(),
                  a.Y(),
                  a.Z(),
                  b.X(),
                  b.Y(),
                  b.Z());
    }
    if (mode == 2 && ext.NbExtrema() > 0)
    {
      std::printf("    calling LowerDistanceParameters() behind the same guard...\n");
      std::fflush(stdout);
      double u1, v1, u2, v2;
      ext.LowerDistanceParameters(u1, v1, u2, v2);
      std::printf("    returned %.6g %.6g %.6g %.6g\n", u1, v1, u2, v2);
    }
  }
  catch (Standard_Failure const& f)
  {
    std::printf("    caught Standard_Failure: %s\n", f.GetMessageString());
  }
  catch (...)
  {
    std::printf("    caught unknown exception\n");
  }
  std::fflush(stdout);
}

int main(int argc, char** argv)
{
  int mode = (argc > 1) ? std::atoi(argv[1]) : 0;
  std::printf("mode %d, two parallel Geom_Planes 5 apart\n", mode);
  run(mode, "finite bounds -10..10", -10.0, 10.0);
  run(mode, "wider bounds -1000..1000", -1000.0, 1000.0);
  std::printf("mode %d finished without dying\n", mode);
  return 0;
}
