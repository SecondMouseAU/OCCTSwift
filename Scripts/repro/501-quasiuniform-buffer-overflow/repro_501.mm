// OCCTSwift#501 reproducer: GCPnts arc-length samplers write past the caller's buffer.
//
// Every bridge function here is handed a buffer sized from the *requested* point count and then
// fills it with `sampler.NbPoints()` values. GCPnts_UniformAbscissa sizes its own parameter array
// at `nbPoints + 5` and lets the arc-length walk run to that array's length, so NbPoints() can come
// back larger than the request, and GCPnts_QuasiUniformAbscissa forwards to it for every curve
// that is neither Bezier nor BSpline.
//
// Each call below writes into a buffer followed by sentinel doubles; a changed sentinel is a real
// heap write past the end. Section C covers the degenerate counts that OCCT's own `>= 2`
// precondition is supposed to reject but cannot, because the Release kernel compiles
// `Standard_ConstructionError_Raise_if` out (No_Exception).
//
// Build (from the repo root):
//   clang++ -std=c++17 -ObjC++ -w -O0 \
//     -ISources/OCCTBridge/include -ISources/OCCTBridge/src \
//     -ILibraries/OCCT.xcframework/macos-arm64/Headers \
//     -LLibraries/OCCT.xcframework/macos-arm64 \
//     Scripts/repro/501-quasiuniform-buffer-overflow/repro_501.mm \
//     Sources/OCCTBridge/src/OCCTBridge_Curve3D.mm \
//     Sources/OCCTBridge/src/OCCTBridge_Geom2d.mm \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ -o /tmp/repro_501
//   /tmp/repro_501
//
// Exit status is 1 while any call still overflows, 0 once they all respect the buffer.

#include <cstdio>
#include <cmath>
#include <vector>
#include <string>

#include "OCCTBridge.h"
#include "OCCTBridge_Internal.h"

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom2d_Ellipse.hxx>
#include <gp_Ax2.hxx>
#include <gp_Ax22d.hxx>

// A curve whose arc-length walk lands just short of the end parameter, so the sampler takes one
// extra step and snaps to the end: major radius 1e6, minor radius 1e-3. The gap that triggers it
// is ~1.6e-8 in parameter, far above the sampler's own epsilon (Resolution(1e-7) ~ 1e-13 here).
static const double kMajor = 1e6;
static const double kMinor = 1e-3;

static const double kSentinel = -1234.5678;
static int gFailures = 0;

namespace {

struct Guarded {
    std::vector<double> buf;
    int32_t             capacity;   // slots the caller is allowed to write

    explicit Guarded(int32_t cap) : buf(cap + 8, kSentinel), capacity(cap) {
        for (int32_t i = 0; i < cap; ++i) buf[i] = 0.0;
    }
    double* data() { return buf.data(); }
    int clobbered() const {
        int n = 0;
        for (size_t i = capacity; i < buf.size(); ++i) if (buf[i] != kSentinel) ++n;
        return n;
    }
};

void report(const char* site, int32_t count, int32_t returned, int clobbered,
            double lastWritten, double curveEnd) {
    const bool overflowed = clobbered > 0;
    const bool shortOfEnd = !overflowed && std::isfinite(curveEnd)
                            && std::abs(lastWritten - curveEnd) > 1e-12;
    if (overflowed) ++gFailures;
    printf("  %-34s count=%-3d returned=%-3d guard=%d%s%s\n",
           site, count, returned, clobbered,
           overflowed ? "   OVERFLOW" : "",
           shortOfEnd ? "   (last param short of the curve end)" : "");
}

}  // namespace

int main() {
    setvbuf(stdout, nullptr, _IONBF, 0);

    gp_Ax2   ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    gp_Ax22d ax2(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));

    Handle(Geom_Ellipse)   e3 = new Geom_Ellipse(ax3, kMajor, kMinor);
    Handle(Geom2d_Ellipse) e2 = new Geom2d_Ellipse(ax2, kMajor, kMinor);

    OCCTCurve3D  curve3d(e3);
    OCCTCurve2D  curve2d(e2);
    OCCTEdge     edge(BRepBuilderAPI_MakeEdge(e3, 0.0, 2 * M_PI).Edge());
    const double uEnd = 2 * M_PI;

    // Counts measured to make the sampler overshoot on this ellipse.
    const int counts[] = {4, 5, 8, 12, 14, 18, 20, 22, 25, 26, 31, 33, 34, 35, 39, 40};

    printf("=== A. OCCTCurve3DQuasiUniformAbscissa: buffer holds `nbPoints` doubles ===\n");
    for (int n : counts) {
        Guarded g(n);
        int32_t got = OCCTCurve3DQuasiUniformAbscissa(&curve3d, n, g.data());
        report("OCCTCurve3DQuasiUniformAbscissa", n, got, g.clobbered(),
               got > 0 ? g.buf[std::min(got, n) - 1] : 0.0, uEnd);
    }

    printf("\n=== B. OCCTCurve3DDrawUniform: buffer holds `pointCount * 3` doubles ===\n");
    for (int n : counts) {
        Guarded g(n * 3);
        int32_t got = OCCTCurve3DDrawUniform(&curve3d, n, g.data());
        report("OCCTCurve3DDrawUniform", n, got, g.clobbered(), NAN, NAN);
    }

    printf("\n=== C. OCCTCurve2DDrawUniform: buffer holds `pointCount * 2` doubles ===\n");
    for (int n : counts) {
        Guarded g(n * 2);
        int32_t got = OCCTCurve2DDrawUniform(&curve2d, n, g.data());
        report("OCCTCurve2DDrawUniform", n, got, g.clobbered(), NAN, NAN);
    }

    printf("\n=== D. OCCTGCPntsQuasiUniform: already clamps to maxParams ===\n");
    for (int n : counts) {
        Guarded g(n);
        int32_t got = OCCTGCPntsQuasiUniform(&edge, n, g.data(), n);
        report("OCCTGCPntsQuasiUniform", n, got, g.clobbered(),
               got > 0 ? g.buf[got - 1] : 0.0, uEnd);
    }

    printf("\n=== E. degenerate counts (OCCT's own `>= 2` precondition is compiled out) ===\n");
    printf("     GCPnts_QuasiUniformAbscissa(bezier_or_bspline, 0) SIGSEGVs inside OCCT on a\n"
           "     (1, 0)-ranged NCollection_HArray1; every entry point must reject it itself.\n");
    for (int n : {0, 1}) {
        Guarded a(std::max(n, 1));
        printf("  OCCTCurve3DQuasiUniformAbscissa    count=%d returned=%d\n", n,
               OCCTCurve3DQuasiUniformAbscissa(&curve3d, n, a.data()));
        Guarded b(std::max(n, 1) * 3);
        printf("  OCCTCurve3DDrawUniform            count=%d returned=%d\n", n,
               OCCTCurve3DDrawUniform(&curve3d, n, b.data()));
        Guarded c(std::max(n, 1) * 2);
        printf("  OCCTCurve2DDrawUniform            count=%d returned=%d\n", n,
               OCCTCurve2DDrawUniform(&curve2d, n, c.data()));
    }

    printf("\n%s: %d overflowing call%s\n", gFailures ? "FAIL" : "PASS",
           gFailures, gFailures == 1 ? "" : "s");
    return gFailures ? 1 : 0;
}
