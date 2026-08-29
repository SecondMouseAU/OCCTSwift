// Multi-threaded stress harness for OCCTSwift#1153: BSpline adaptor cache data race
// Characterizes GeomAdaptor_Curve/BSplCLib_Cache and GeomAdaptor_Surface/BSplSLib_Cache
// races when a single adaptor is shared across threads.
// Pure C++, no Swift/bridge layer -- isolates OCCT itself.
//
// Both scenarios now cycle through D0/D1/D2/D3 (curve) and D0/D1/D2 (surface), not just D0:
// the review of the first version of this reproducer (#1322) found that D0 alone never touches
// the derivative-family nesting (D1 -> D1Local -> calculateDerivativeLocal, etc.) that self-
// deadlocked under the original PR's non-recursive std::mutex, so a D0-only "0 races" result was
// not evidence the derivative path was safe.
//
// Usage: occt_1153_stress <scenario> <threads> <iterations>
//   scenarios: shared_adaptor_curve | shared_adaptor_surface

#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

#include <GeomAPI_Interpolate.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <Geom_BSplineCurve.hxx>
#include <GeomAdaptor_Curve.hxx>

#include <GeomAPI_PointsToBSplineSurface.hxx>
#include <TColgp_HArray2OfPnt.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <Geom_BSplineSurface.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColStd_Array1OfInteger.hxx>

std::atomic<long> gOps{0};
std::atomic<long> gErrors{0};

static void note(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vfprintf(stderr, fmt, args);
    va_end(args);
    fprintf(stderr, "\n");
}

// ---------------------------------------------------------------------------
// Scenario: N threads share ONE GeomAdaptor_Curve (wrapping a BSpline curve)
// and hammer D0/D1/D2/D3 concurrently, cycling per iteration. Targets both
// GeomAdaptor_Curve's Cache handle (created/replaced by RebuildCache) and
// BSplCLib_Cache's own mutable evaluation state.
// ---------------------------------------------------------------------------
static Handle(Geom_BSplineCurve) makeSharedBSplineCurve() {
    Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, 6);
    pts->SetValue(1, gp_Pnt(0, 0, 0));
    pts->SetValue(2, gp_Pnt(1, 2, 0));
    pts->SetValue(3, gp_Pnt(2, -1, 1));
    pts->SetValue(4, gp_Pnt(3, 3, -1));
    pts->SetValue(5, gp_Pnt(4, 0, 2));
    pts->SetValue(6, gp_Pnt(5, 1, 0));
    GeomAPI_Interpolate interp(pts, false, 1e-6);
    interp.Perform();
    return interp.Curve();
}

void runSharedAdaptorCurve(int id, int iterations, GeomAdaptor_Curve* sharedAdaptor,
                           double uFirst, double uLast) {
    for (int it = 0; it < iterations; ++it) {
        double u = uFirst + (uLast - uFirst) * ((id * 37 + it) % 101) / 100.0;
        gp_Pnt p;
        bool finite = true;
        switch (it % 4) {
            case 0: {
                sharedAdaptor->D0(u, p);
                finite = std::isfinite(p.X()) && std::isfinite(p.Y()) && std::isfinite(p.Z());
                break;
            }
            case 1: {
                gp_Vec d1;
                sharedAdaptor->D1(u, p, d1);
                finite = std::isfinite(p.X()) && std::isfinite(d1.X());
                break;
            }
            case 2: {
                gp_Vec d1, d2;
                sharedAdaptor->D2(u, p, d1, d2);
                finite = std::isfinite(p.X()) && std::isfinite(d1.X()) && std::isfinite(d2.X());
                break;
            }
            default: {
                gp_Vec d1, d2, d3;
                sharedAdaptor->D3(u, p, d1, d2, d3);
                finite = std::isfinite(p.X()) && std::isfinite(d1.X()) && std::isfinite(d2.X())
                       && std::isfinite(d3.X());
                break;
            }
        }
        if (!finite) {
            gErrors++;
            note("[thread %d] shared-adaptor-curve D%d produced non-finite value at u=%f", id,
                 it % 4, u);
        }
        gOps++;
    }
}

// ---------------------------------------------------------------------------
// Scenario: N threads share ONE GeomAdaptor_Surface (wrapping a BSpline surface)
// and hammer D0/D1/D2 concurrently, cycling per iteration. Targets both
// GeomAdaptor_Surface's Cache handle and BSplSLib_Cache's own mutable state.
// ---------------------------------------------------------------------------
static Handle(Geom_BSplineSurface) makeSharedBSplineSurface() {
    // Create a simple 4x4 control point grid for a BSpline surface
    TColgp_Array2OfPnt poles(1, 4, 1, 4);
    for (int i = 1; i <= 4; ++i) {
        for (int j = 1; j <= 4; ++j) {
            double x = (i - 1) * 10.0;
            double y = (j - 1) * 10.0;
            double z = (i == 2 && j == 2) ? 5.0 : 0.0; // small bump in middle
            poles.SetValue(i, j, gp_Pnt(x, y, z));
        }
    }

    // Build knot vectors (uniform, degree 3)
    TColStd_Array1OfReal uKnots(1, 2);
    TColStd_Array1OfReal vKnots(1, 2);
    TColStd_Array1OfInteger uMults(1, 2);
    TColStd_Array1OfInteger vMults(1, 2);

    uKnots.SetValue(1, 0.0); uKnots.SetValue(2, 1.0);
    vKnots.SetValue(1, 0.0); vKnots.SetValue(2, 1.0);
    uMults.SetValue(1, 4); uMults.SetValue(2, 4);
    vMults.SetValue(1, 4); vMults.SetValue(2, 4);

    Handle(Geom_BSplineSurface) surf = new Geom_BSplineSurface(
        poles, uKnots, vKnots, uMults, vMults, 3, 3);
    return surf;
}

void runSharedAdaptorSurface(int id, int iterations, GeomAdaptor_Surface* sharedAdaptor,
                             double uFirst, double uLast, double vFirst, double vLast) {
    for (int it = 0; it < iterations; ++it) {
        double u = uFirst + (uLast - uFirst) * ((id * 37 + it) % 101) / 100.0;
        double v = vFirst + (vLast - vFirst) * ((id * 41 + it) % 101) / 100.0;
        gp_Pnt p;
        bool finite = true;
        switch (it % 3) {
            case 0: {
                sharedAdaptor->D0(u, v, p);
                finite = std::isfinite(p.X()) && std::isfinite(p.Y()) && std::isfinite(p.Z());
                break;
            }
            case 1: {
                gp_Vec d1u, d1v;
                sharedAdaptor->D1(u, v, p, d1u, d1v);
                finite = std::isfinite(p.X()) && std::isfinite(d1u.X()) && std::isfinite(d1v.X());
                break;
            }
            default: {
                gp_Vec d1u, d1v, d2u, d2v, d2uv;
                sharedAdaptor->D2(u, v, p, d1u, d1v, d2u, d2v, d2uv);
                finite = std::isfinite(p.X()) && std::isfinite(d1u.X()) && std::isfinite(d1v.X())
                       && std::isfinite(d2u.X()) && std::isfinite(d2v.X())
                       && std::isfinite(d2uv.X());
                break;
            }
        }
        if (!finite) {
            gErrors++;
            note("[thread %d] shared-adaptor-surface D%d produced non-finite value at u=%f, v=%f",
                 id, it % 3, u, v);
        }
        gOps++;
    }
}

int main(int argc, char** argv) {
    std::string scenario = argc > 1 ? argv[1] : "shared_adaptor_curve";
    int threads = argc > 2 ? atoi(argv[2]) : 8;
    int iterations = argc > 3 ? atoi(argv[3]) : 20;

    note("scenario=%s threads=%d iterations=%d", scenario.c_str(), threads, iterations);

    // NOTE (#1153 review finding 3, re-found while re-verifying): the original reproducer
    // declared sharedAdaptor *inside* this if/else-if chain while `pool` and the join loop
    // lived outside it. A variable's scope ends at its own block's closing brace regardless of
    // what code runs afterwards, so sharedAdaptor was destroyed the instant the if/else-if
    // chain finished spawning threads -- while every worker thread was still running against
    // it, well before `t.join()` below ever ran. That is a real use-after-scope bug in the
    // harness itself, independent of #1153, and it was corrupting both the "before" and "after"
    // TSan results (a GeomAdaptor_Curve/Surface, including its own mutex, torn down under
    // threads still calling into it looks identical to the race #1153 is about). Each scenario
    // now owns its adaptor, pool and join loop in one scope so the adaptor outlives every
    // thread that touches it.
    auto t0 = std::chrono::steady_clock::now();

    if (scenario == "shared_adaptor_curve") {
        Handle(Geom_BSplineCurve) curve = makeSharedBSplineCurve();
        GeomAdaptor_Curve sharedAdaptor(curve);
        double uFirst = curve->FirstParameter();
        double uLast = curve->LastParameter();
        std::vector<std::thread> pool;
        for (int i = 0; i < threads; ++i)
            pool.emplace_back(runSharedAdaptorCurve, i, iterations, &sharedAdaptor, uFirst, uLast);
        for (auto& t : pool) t.join();
    } else if (scenario == "shared_adaptor_surface") {
        Handle(Geom_BSplineSurface) surf = makeSharedBSplineSurface();
        GeomAdaptor_Surface sharedAdaptor(surf);
        double uFirst, uLast, vFirst, vLast;
        surf->Bounds(uFirst, uLast, vFirst, vLast);
        std::vector<std::thread> pool;
        for (int i = 0; i < threads; ++i)
            pool.emplace_back(runSharedAdaptorSurface, i, iterations, &sharedAdaptor, uFirst, uLast, vFirst, vLast);
        for (auto& t : pool) t.join();
    } else {
        note("unknown scenario: %s", scenario.c_str());
        return 2;
    }

    auto t1 = std::chrono::steady_clock::now();
    double secs = std::chrono::duration<double>(t1 - t0).count();
    note("done: ops=%ld errors=%ld elapsed=%.2fs", gOps.load(), gErrors.load(), secs);
    return gErrors.load() > 0 ? 1 : 0;
}
