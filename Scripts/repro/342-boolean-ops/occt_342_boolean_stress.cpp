// Stress harness for #342 (bridge-level thread-handling contract): are ordinary boolean
// operations (BRepAlgoAPI_Fuse/Cut/Common, as wrapped by OCCTShapeUnion/Subtract/Intersect)
// safe to run concurrently on independent shapes? Never TSan'd before -- #298 already showed
// "independent shapes are safe" is not a safe assumption to make by inspection for this
// engine family (fillet/chamfer's legacy TopOpeBRepBuild engine hid a severe silent-corruption
// race), so this checks the modern BOPAlgo engine plain Fuse/Cut/Common goes through
// independently, rather than assuming it inherited #298's fix or was never affected.
//
// Two independent signals, matching the #298 methodology: TSan race reports, AND a
// correctness check against a single-threaded baseline (volume/face-count) -- a race that
// produces a wrong-but-plausible result without a crash would pass "no crash" but fail this.
//
// Usage: occt_342_boolean_stress <scenario> <threads> <iterations>
//   scenarios: fuse | cut | common | mixed | fuse_multi_parallel

#include <atomic>
#include <chrono>
#include <cstdarg>
#include <cstdio>
#include <cstdlib>
#include <thread>
#include <vector>

#include <BRepAlgoAPI_BuilderAlgo.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <GProp_GProps.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS_Shape.hxx>

std::atomic<long> gOps{0};
std::atomic<long> gErrors{0};
std::atomic<long> gWrongResult{0}; // diverged from the single-threaded baseline

static void note(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vfprintf(stderr, fmt, args);
    va_end(args);
    fprintf(stderr, "\n");
}

// Canonical overlap: box(10,10,10) + sphere(center (5,5,5), r=6), same shapes #298's own
// harness used -- an already-exercised, known-good pair, not a fresh unvalidated fixture.
static TopoDS_Shape makeBox() { return BRepPrimAPI_MakeBox(10, 10, 10).Shape(); }
static TopoDS_Shape makeSphere() { return BRepPrimAPI_MakeSphere(gp_Pnt(5, 5, 5), 6).Shape(); }

static int faceCount(const TopoDS_Shape& s) {
    int n = 0;
    for (TopExp_Explorer exp(s, TopAbs_FACE); exp.More(); exp.Next()) ++n;
    return n;
}

static double volumeOf(const TopoDS_Shape& s) {
    GProp_GProps props;
    BRepGProp::VolumeProperties(s, props);
    return props.Mass();
}

// Baselines computed once, single-threaded, before any thread starts.
static double gFuseBaselineVolume = 0;
static int    gFuseBaselineFaces  = 0;
static double gCutBaselineVolume  = 0;
static int    gCutBaselineFaces   = 0;
static double gCommonBaselineVolume = 0;
static int    gCommonBaselineFaces  = 0;

static void computeBaselines() {
    {
        BRepAlgoAPI_Fuse op(makeBox(), makeSphere());
        op.Build();
        gFuseBaselineVolume = volumeOf(op.Shape());
        gFuseBaselineFaces  = faceCount(op.Shape());
    }
    {
        BRepAlgoAPI_Cut op(makeBox(), makeSphere());
        op.Build();
        gCutBaselineVolume = volumeOf(op.Shape());
        gCutBaselineFaces  = faceCount(op.Shape());
    }
    {
        BRepAlgoAPI_Common op(makeBox(), makeSphere());
        op.Build();
        gCommonBaselineVolume = volumeOf(op.Shape());
        gCommonBaselineFaces  = faceCount(op.Shape());
    }
    note("baselines: fuse vol=%.6f faces=%d | cut vol=%.6f faces=%d | common vol=%.6f faces=%d",
         gFuseBaselineVolume, gFuseBaselineFaces, gCutBaselineVolume, gCutBaselineFaces,
         gCommonBaselineVolume, gCommonBaselineFaces);
}

static bool closeEnough(double a, double b) { return std::fabs(a - b) < 1e-6 * std::max(1.0, std::fabs(b)); }

void runFuse(int id, int iterations) {
    for (int it = 0; it < iterations; ++it) {
        BRepAlgoAPI_Fuse op(makeBox(), makeSphere());
        op.Build();
        if (!op.IsDone()) { gErrors++; note("[fuse %d] not done", id); continue; }
        TopoDS_Shape result = op.Shape();
        if (!closeEnough(volumeOf(result), gFuseBaselineVolume) || faceCount(result) != gFuseBaselineFaces) {
            gWrongResult++;
            note("[fuse %d] diverged: vol=%.6f faces=%d (expected vol=%.6f faces=%d)", id,
                 volumeOf(result), faceCount(result), gFuseBaselineVolume, gFuseBaselineFaces);
        }
        gOps++;
    }
}

void runCut(int id, int iterations) {
    for (int it = 0; it < iterations; ++it) {
        BRepAlgoAPI_Cut op(makeBox(), makeSphere());
        op.Build();
        if (!op.IsDone()) { gErrors++; note("[cut %d] not done", id); continue; }
        TopoDS_Shape result = op.Shape();
        if (!closeEnough(volumeOf(result), gCutBaselineVolume) || faceCount(result) != gCutBaselineFaces) {
            gWrongResult++;
            note("[cut %d] diverged: vol=%.6f faces=%d (expected vol=%.6f faces=%d)", id,
                 volumeOf(result), faceCount(result), gCutBaselineVolume, gCutBaselineFaces);
        }
        gOps++;
    }
}

void runCommon(int id, int iterations) {
    for (int it = 0; it < iterations; ++it) {
        BRepAlgoAPI_Common op(makeBox(), makeSphere());
        op.Build();
        if (!op.IsDone()) { gErrors++; note("[common %d] not done", id); continue; }
        TopoDS_Shape result = op.Shape();
        if (!closeEnough(volumeOf(result), gCommonBaselineVolume) || faceCount(result) != gCommonBaselineFaces) {
            gWrongResult++;
            note("[common %d] diverged: vol=%.6f faces=%d (expected vol=%.6f faces=%d)", id,
                 volumeOf(result), faceCount(result), gCommonBaselineVolume, gCommonBaselineFaces);
        }
        gOps++;
    }
}

// Half the threads fuse, a third cut, the rest common -- a realistic mixed workload rather
// than N threads all doing the exact same op (which could mask interference that only shows
// up when different BOPAlgo code paths run concurrently).
void runMixed(int id, int iterations) {
    switch (id % 3) {
        case 0: runFuse(id, iterations); break;
        case 1: runCut(id, iterations); break;
        default: runCommon(id, iterations); break;
    }
}

// OCCTShapeFuseMulti's own pattern: SetRunParallel(true) -- internal parallelism -- run
// concurrently across threads too, so N threads each spawn their own internal worker pool
// simultaneously. Tests oversubscription/interference, not just plain concurrent calls.
void runFuseMultiParallel(int id, int iterations) {
    for (int it = 0; it < iterations; ++it) {
        TopTools_ListOfShape args;
        args.Append(makeBox());
        args.Append(makeSphere());
        BRepAlgoAPI_BuilderAlgo builder;
        builder.SetArguments(args);
        builder.SetRunParallel(Standard_True);
        builder.Build();
        if (!builder.IsDone()) { gErrors++; note("[fuse_multi %d] not done", id); continue; }
        TopoDS_Shape result = builder.Shape();
        if (!closeEnough(volumeOf(result), gFuseBaselineVolume) || faceCount(result) != gFuseBaselineFaces) {
            gWrongResult++;
            note("[fuse_multi %d] diverged: vol=%.6f faces=%d (expected vol=%.6f faces=%d)", id,
                 volumeOf(result), faceCount(result), gFuseBaselineVolume, gFuseBaselineFaces);
        }
        gOps++;
    }
}

int main(int argc, char** argv) {
    std::string scenario = argc > 1 ? argv[1] : "mixed";
    int threads = argc > 2 ? atoi(argv[2]) : 8;
    int iterations = argc > 3 ? atoi(argv[3]) : 50;

    note("scenario=%s threads=%d iterations=%d", scenario.c_str(), threads, iterations);
    computeBaselines();

    std::vector<std::thread> pool;
    auto t0 = std::chrono::steady_clock::now();

    if (scenario == "fuse") {
        for (int i = 0; i < threads; ++i) pool.emplace_back(runFuse, i, iterations);
    } else if (scenario == "cut") {
        for (int i = 0; i < threads; ++i) pool.emplace_back(runCut, i, iterations);
    } else if (scenario == "common") {
        for (int i = 0; i < threads; ++i) pool.emplace_back(runCommon, i, iterations);
    } else if (scenario == "mixed") {
        for (int i = 0; i < threads; ++i) pool.emplace_back(runMixed, i, iterations);
    } else if (scenario == "fuse_multi_parallel") {
        for (int i = 0; i < threads; ++i) pool.emplace_back(runFuseMultiParallel, i, iterations);
    } else {
        note("unknown scenario: %s", scenario.c_str());
        return 2;
    }

    for (auto& t : pool) t.join();

    auto t1 = std::chrono::steady_clock::now();
    double secs = std::chrono::duration<double>(t1 - t0).count();
    note("done: ops=%ld errors=%ld wrongResult=%ld elapsed=%.2fs", gOps.load(), gErrors.load(),
         gWrongResult.load(), secs);
    return (gErrors.load() > 0 || gWrongResult.load() > 0) ? 1 : 0;
}
