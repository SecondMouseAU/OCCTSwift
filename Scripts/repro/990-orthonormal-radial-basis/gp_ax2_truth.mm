// Ground truth for #990: OCCT's own `gp_Ax2(gp_Pnt, gp_Dir)` basis, read straight from the
// pinned kernel rather than recomputed in Swift. `perpendicularBasis(to:)` claims to reproduce
// this algorithm, and `basis-compare.swift` checks its copy against these numbers before drawing
// any conclusion from it.
//
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/990-orthonormal-radial-basis/gp_ax2_truth.mm -o /tmp/gp_ax2_truth
//   /tmp/gp_ax2_truth

#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <cstdio>

static void report(const char* name, double x, double y, double z) {
  gp_Ax2 ax(gp_Pnt(0, 0, 0), gp_Dir(x, y, z));
  const gp_Dir& xd = ax.XDirection();
  const gp_Dir& yd = ax.YDirection();
  printf("%-10s X=(%+.17g,%+.17g,%+.17g)  Y=(%+.17g,%+.17g,%+.17g)\n", name,
         xd.X(), xd.Y(), xd.Z(), yd.X(), yd.Y(), yd.Z());
}

int main() {
  report("+X", 1, 0, 0);
  report("-X", -1, 0, 0);
  report("+Y", 0, 1, 0);
  report("-Y", 0, -1, 0);
  report("+Z", 0, 0, 1);
  report("-Z", 0, 0, -1);
  report("(1,2,3)", 1, 2, 3);
  report("(1,1,1)", 1, 1, 1);
  report("(0,1,1)", 0, 1, 1);
  return 0;
}
