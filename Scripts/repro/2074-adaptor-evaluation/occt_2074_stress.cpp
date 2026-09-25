// Multi-threaded stress harness for OCCTSwift#2074: the Surface/Curve3D evaluation surface,
// which #707 named as having no TSan scenario at all.
//
// Pure C++, no Swift/bridge layer, so this isolates OCCT itself.
//
// WHY THIS SURFACE. Carried patch 0031 (#1153) already found a real defect here:
// BSplCLib_Cache and BSplSLib_Cache hold the span they last built and rebuild it IN PLACE from a
// const evaluator, so two threads evaluating parameters in different spans make one cache rebuild
// under the other's feet. The second thread then reads polynomial coefficients for a span its
// parameter is not in, which is a WRONG POINT rather than merely a sanitiser report.
//
// That is reachable without any caller sharing a cache deliberately: GeomAdaptor_Curve and
// GeomAdaptor_Surface build one cache per adaptor and hand it to every caller of their const
// evaluators, and they also do a check-then-act on the cache handle itself. 0031's own test showed
// the shared-handle check-then-act is a SEPARATE defect from the span rebuild, which is why the
// modes below separate "share the geometry, build your own adaptor" from "share the adaptor".
//
// THE PARAMETERS MATTER. Every mode drives threads at parameters in DIFFERENT spans, staggered by
// thread index. A harness whose threads all evaluate the same span would find nothing here however
// many threads it ran, because the cache would never need rebuilding.
//
// GATE MEMBERSHIP. Only the *_independent and *_shared_geometry modes belong in
// Scripts/tsan-stress.sh's SCENARIOS. The *_shared_adaptor modes are adversarial by construction,
// the same shape as #341's shared_adaptor_cache and the cross_talk_schema_* modes that the POLICY
// block in that script excludes: one GeomAdaptor_Curve handed to eight threads races by design,
// and gating on it would be gating on a usage the API does not offer.

#include <atomic>
#include <cstdarg>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <thread>
#include <vector>

#include <BSplCLib.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>

static std::atomic<long> gOps{0};
static std::atomic<long> gErrors{0};

static void note(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vfprintf(stderr, fmt, args);
    va_end(args);
    fprintf(stderr, "\n");
}

// ---------------------------------------------------------------------------
// Geometry with MANY spans, so a thread's parameter selects a different span from its neighbour's.

static Handle(Geom_BSplineCurve) makeMultiSpanCurve() {
    const int nPoles = 12;
    TColgp_Array1OfPnt poles(1, nPoles);
    for (int i = 1; i <= nPoles; ++i) {
        poles(i) = gp_Pnt(i * 10.0, (i % 3) * 7.0, (i % 5) * 3.0);
    }
    // Degree 3, uniform interior knots: nPoles - degree + 1 = 10 distinct knots, 9 spans.
    const int nKnots = nPoles - 3 + 1;
    TColStd_Array1OfReal knots(1, nKnots);
    TColStd_Array1OfInteger mults(1, nKnots);
    for (int i = 1; i <= nKnots; ++i) {
        knots(i) = (double)(i - 1) / (nKnots - 1);
        mults(i) = 1;
    }
    mults(1) = 4;
    mults(nKnots) = 4;
    return new Geom_BSplineCurve(poles, knots, mults, 3);
}

static Handle(Geom_BSplineSurface) makeMultiSpanSurface() {
    const int nu = 10, nv = 10;
    TColgp_Array2OfPnt poles(1, nu, 1, nv);
    for (int i = 1; i <= nu; ++i) {
        for (int j = 1; j <= nv; ++j) {
            poles(i, j) = gp_Pnt(i * 8.0, j * 8.0, ((i * j) % 7) * 2.0);
        }
    }
    const int nku = nu - 3 + 1, nkv = nv - 3 + 1;
    TColStd_Array1OfReal uknots(1, nku), vknots(1, nkv);
    TColStd_Array1OfInteger umults(1, nku), vmults(1, nkv);
    for (int i = 1; i <= nku; ++i) { uknots(i) = (double)(i - 1) / (nku - 1); umults(i) = 1; }
    for (int j = 1; j <= nkv; ++j) { vknots(j) = (double)(j - 1) / (nkv - 1); vmults(j) = 1; }
    umults(1) = 4; umults(nku) = 4;
    vmults(1) = 4; vmults(nkv) = 4;
    return new Geom_BSplineSurface(poles, uknots, vknots, umults, vmults, 3, 3);
}

// A parameter in a span chosen by thread index, so neighbours land in different spans.
static double spanParam(int tid, int iter, double lo, double hi, int spans) {
    const int span = (tid + iter) % spans;
    const double width = (hi - lo) / spans;
    return lo + width * (span + 0.5);
}

// ---------------------------------------------------------------------------
// Modes.

static void runCurveIndependent(int tid, int iterations) {
    for (int k = 0; k < iterations; ++k) {
        Handle(Geom_BSplineCurve) curve = makeMultiSpanCurve();  // own geometry
        GeomAdaptor_Curve adaptor(curve);                        // own adaptor
        const double u = spanParam(tid, k, adaptor.FirstParameter(), adaptor.LastParameter(), 9);
        gp_Pnt p = adaptor.Value(u);
        gp_Vec d1;
        adaptor.D1(u, p, d1);
        if (p.X() != p.X()) ++gErrors;  // NaN guard, a wrong span shows up here first
        ++gOps;
    }
}

static void runSurfaceIndependent(int tid, int iterations) {
    for (int k = 0; k < iterations; ++k) {
        Handle(Geom_BSplineSurface) surf = makeMultiSpanSurface();
        GeomAdaptor_Surface adaptor(surf);
        const double u = spanParam(tid, k, adaptor.FirstUParameter(), adaptor.LastUParameter(), 7);
        const double v = spanParam(tid, k + 1, adaptor.FirstVParameter(), adaptor.LastVParameter(), 7);
        gp_Pnt p = adaptor.Value(u, v);
        gp_Vec du, dv;
        adaptor.D1(u, v, p, du, dv);
        if (p.X() != p.X()) ++gErrors;
        ++gOps;
    }
}

// The realistic consumer shape: one curve/surface shared, each thread builds its own adaptor.
// This is what a Swift caller holding one Curve3D and evaluating it from several tasks produces.
static Handle(Geom_BSplineCurve) gSharedCurve;
static Handle(Geom_BSplineSurface) gSharedSurface;

static void runCurveSharedGeometry(int tid, int iterations) {
    for (int k = 0; k < iterations; ++k) {
        GeomAdaptor_Curve adaptor(gSharedCurve);  // own adaptor, shared geometry
        const double u = spanParam(tid, k, adaptor.FirstParameter(), adaptor.LastParameter(), 9);
        gp_Pnt p = adaptor.Value(u);
        if (p.X() != p.X()) ++gErrors;
        ++gOps;
    }
}

static void runSurfaceSharedGeometry(int tid, int iterations) {
    for (int k = 0; k < iterations; ++k) {
        GeomAdaptor_Surface adaptor(gSharedSurface);
        const double u = spanParam(tid, k, adaptor.FirstUParameter(), adaptor.LastUParameter(), 7);
        const double v = spanParam(tid, k + 1, adaptor.FirstVParameter(), adaptor.LastVParameter(), 7);
        gp_Pnt p = adaptor.Value(u, v);
        if (p.X() != p.X()) ++gErrors;
        ++gOps;
    }
}

// ADVERSARIAL, excluded from the gate. One adaptor, and therefore one cache, for every thread.
// This is 0031's own reproduction shape and races by construction.
static GeomAdaptor_Curve* gSharedCurveAdaptor = nullptr;
static GeomAdaptor_Surface* gSharedSurfaceAdaptor = nullptr;

static void runCurveSharedAdaptor(int tid, int iterations) {
    for (int k = 0; k < iterations; ++k) {
        const double u = spanParam(tid, k, gSharedCurveAdaptor->FirstParameter(),
                                   gSharedCurveAdaptor->LastParameter(), 9);
        gp_Pnt p = gSharedCurveAdaptor->Value(u);
        if (p.X() != p.X()) ++gErrors;
        ++gOps;
    }
}

static void runSurfaceSharedAdaptor(int tid, int iterations) {
    for (int k = 0; k < iterations; ++k) {
        const double u = spanParam(tid, k, gSharedSurfaceAdaptor->FirstUParameter(),
                                   gSharedSurfaceAdaptor->LastUParameter(), 7);
        const double v = spanParam(tid, k + 1, gSharedSurfaceAdaptor->FirstVParameter(),
                                   gSharedSurfaceAdaptor->LastVParameter(), 7);
        gp_Pnt p = gSharedSurfaceAdaptor->Value(u, v);
        if (p.X() != p.X()) ++gErrors;
        ++gOps;
    }
}

// ---------------------------------------------------------------------------
struct Scenario {
    const char* name;
    void (*fn)(int, int);
    void (*setup)();
};

static void setupSharedCurve() { gSharedCurve = makeMultiSpanCurve(); }
static void setupSharedSurface() { gSharedSurface = makeMultiSpanSurface(); }
static void setupSharedCurveAdaptor() {
    gSharedCurve = makeMultiSpanCurve();
    gSharedCurveAdaptor = new GeomAdaptor_Curve(gSharedCurve);
}
static void setupSharedSurfaceAdaptor() {
    gSharedSurface = makeMultiSpanSurface();
    gSharedSurfaceAdaptor = new GeomAdaptor_Surface(gSharedSurface);
}

static Scenario SCENARIOS[] = {
    {"curve_independent", runCurveIndependent, nullptr},
    {"surface_independent", runSurfaceIndependent, nullptr},
    {"curve_shared_geometry", runCurveSharedGeometry, setupSharedCurve},
    {"surface_shared_geometry", runSurfaceSharedGeometry, setupSharedSurface},
    // Adversarial, not for the gate.
    {"curve_shared_adaptor", runCurveSharedAdaptor, setupSharedCurveAdaptor},
    {"surface_shared_adaptor", runSurfaceSharedAdaptor, setupSharedSurfaceAdaptor},
};

static void runOne(const char* name, int threads, int iterations) {
    for (auto& s : SCENARIOS) {
        if (strcmp(name, s.name) != 0) continue;
        if (s.setup) s.setup();
        std::vector<std::thread> pool;
        for (int i = 0; i < threads; ++i) pool.emplace_back(s.fn, i, iterations);
        for (auto& th : pool) th.join();
        return;
    }
    note("unknown scenario: %s", name);
    exit(2);
}

int main(int argc, char** argv) {
    if (argc < 4) {
        note("usage: %s <scenario|all> <threads> <iterations>", argv[0]);
        return 2;
    }
    std::string scenario = argv[1];
    int threads = atoi(argv[2]);
    int iterations = atoi(argv[3]);
    if (scenario == "all") {
        for (auto& s : SCENARIOS) {
            note(">>> %s", s.name);
            gOps = 0;
            gErrors = 0;
            runOne(s.name, threads, iterations);
            note("    ops=%ld errors=%ld", gOps.load(), gErrors.load());
        }
    } else {
        runOne(scenario.c_str(), threads, iterations);
        note("ops=%ld errors=%ld", gOps.load(), gErrors.load());
    }
    return gErrors.load() > 0 ? 1 : 0;
}
