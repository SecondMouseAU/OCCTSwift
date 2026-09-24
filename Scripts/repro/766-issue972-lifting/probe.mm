// #766 / #1989: kernel-parity probe for Tests/OCCTMiscTests/Issue972LiftingTests.swift.
//
// Placement.lift is pure Swift (origin + x * xAxis + y * yAxis), so there is no bridge call to
// compare against. The kernel's own way of doing the same thing is a gp_Ax3 frame and
// gp_Trsf::SetTransformation from that frame to the world, which this probe applies to the same
// 2D points. It also shows what gp_Dir makes of the non-unit normal (0, 0, 7) the Flange test uses.
//
// Build (from the repo root, against the SwiftPM-resolved pinned kernel):
//   X=.build/artifacts/<checkout>/OCCT/OCCT.xcframework/macos-arm64
//   clang++ -std=c++17 -ObjC++ -w -I"$X/Headers" -L"$X" -lOCCT-macos \
//     -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/766-issue972-lifting/probe.mm -o /tmp/probe_766_972

#include <gp_Ax3.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Trsf.hxx>
#include <cmath>
#include <cstdio>

static void lift(const char* theLabel, const gp_Ax3& theFrame, double u, double v)
{
  gp_Trsf aToWorld;
  aToWorld.SetTransformation(theFrame, gp_Ax3()); // local frame coordinates -> world
  gp_Pnt p(u, v, 0);
  p.Transform(aToWorld);
  std::printf("%s: (%.17g, %.17g, %.17g)\n", theLabel, p.X(), p.Y(), p.Z());
}

int main()
{
  lift("liftMatchesTheFormula, origin (1,2,3), identity axes, (4,5)",
       gp_Ax3(gp_Pnt(1, 2, 3), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0)), 4, 5);
  const double s2 = std::sqrt(2.0) / 2;
  lift("liftRespectsARotatedBasis, x = (s2, s2, 0), (1,0)",
       gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), gp_Dir(s2, s2, 0)), 1, 0);
  gp_Dir n(0, 0, 7);
  std::printf("flangeNormalAgreesWithItsPlacement: gp_Dir(0, 0, 7) = (%.17g, %.17g, %.17g)\n",
              n.X(), n.Y(), n.Z());
  return 0;
}
