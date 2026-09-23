// Multi-threaded stress harness for OCCTSwift#2075: the BRepGraph surface, the second of the two
// #707 named as having no TSan scenario at all.
//
// Pure C++, no Swift/bridge layer, so this isolates OCCT itself.
//
// WHY THIS SURFACE WAS RANKED SECOND. Unlike Surface/Curve3D (#2074) there is no known defect
// here. What made it a candidate rather than a guess is the identity model: BRepGraph UIDs are
// graph-local (#295/#303), so a graph is a stateful object a caller holds and mutates across
// calls, which is the shape every defect this protocol has found has had.
//
// WHAT THE STRUCTURAL READ SAID FIRST. Across the 83 files of
// src/ModelingData/TKBRep/BRepGraph: zero file-scope mutable statics, zero function-local
// statics, and exactly three `mutable` members, all three of them mutexes
// (BRepGraph_CacheRegistry and BRepGraph_LayerRegistry carry a std::shared_mutex,
// BRepGraph_CacheDerivedState a std::mutex). The family was written thread-aware.
//
// That is a reason to expect clean, not a substitute for measuring. #1155's survey is the
// precedent: eight classes read as instance-state-only and were still run concurrently, and the
// one near-miss it found was a live file-scope cluster that reading alone had not settled.
//
// GATE MEMBERSHIP. Only the *_independent modes belong in Scripts/tsan-stress.sh's SCENARIOS.
// `shared_graph_*` mutates one BRepGraph from eight threads, which races by construction the same
// way #341's shared_adaptor_cache and the cross_talk_schema_* modes do, and the POLICY block in
// that script excludes exactly that.

#include <atomic>
#include <cstdarg>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <thread>
#include <vector>

#include <BRepGraph.hxx>
#include <BRepGraph_ShapesView.hxx>
#include <BRepGraph_TopoView.hxx>
#include <BRepGraph_Tool.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <TopoDS_Shape.hxx>

static std::atomic<long> gOps{0};
static std::atomic<long> gErrors{0};

static void note(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vfprintf(stderr, fmt, args);
    va_end(args);
    fprintf(stderr, "\n");
}

static TopoDS_Shape makeShape(int tid) {
    // Differing dimensions per thread, so two threads are not ingesting identical topology and
    // a cache keyed on shape content cannot make them accidentally agree.
    const double d = 10.0 + tid;
    return (tid % 2 == 0) ? TopoDS_Shape(BRepPrimAPI_MakeBox(d, d + 1, d + 2).Shape())
                          : TopoDS_Shape(BRepPrimAPI_MakeCylinder(d, d + 3).Shape());
}

static bool buildGraph(BRepGraph& g, const TopoDS_Shape& s) {
    g.Clear();  // upstream's declared rebuild boundary: stamps identity (#303)
    BRepGraph::ShapesView::Options opts;
    opts.Parallel          = false;
    opts.CreateAutoProduct = false;
    return g.Shapes().Add(s, opts).IsOk();
}

// Traversal that touches the derived-state and registry paths rather than only construction,
// since those are where the three mutexes are.
static void traverse(const BRepGraph& g) {
    const int faces = (int)g.Topo().Faces().Nb();
    const int edges = (int)g.Topo().Edges().Nb();
    for (int i = 0; i < faces; ++i) {
        (void)BRepGraph_Tool::Face::OuterWire(g, BRepGraph_FaceId(i));
    }
    for (int i = 0; i < edges; ++i) {
        (void)BRepGraph_Tool::Edge::IsBoundary(g, BRepGraph_EdgeId(i));
        (void)BRepGraph_Tool::Edge::IsManifold(g, BRepGraph_EdgeId(i));
    }
}

// ---------------------------------------------------------------------------
// Modes.

static void runBuildIndependent(int tid, int iterations) {
    for (int k = 0; k < iterations; ++k) {
        BRepGraph g;  // own graph
        if (!buildGraph(g, makeShape(tid))) { ++gErrors; continue; }
        ++gOps;
    }
}

static void runTraverseIndependent(int tid, int iterations) {
    BRepGraph g;
    if (!buildGraph(g, makeShape(tid))) { ++gErrors; return; }
    for (int k = 0; k < iterations; ++k) {
        traverse(g);
        ++gOps;
    }
}

static void runBuildAndTraverseIndependent(int tid, int iterations) {
    for (int k = 0; k < iterations; ++k) {
        BRepGraph g;
        if (!buildGraph(g, makeShape(tid + k))) { ++gErrors; continue; }
        traverse(g);
        ++gOps;
    }
}

// ADVERSARIAL, excluded from the gate: one graph, mutated and read by every thread.
static BRepGraph* gSharedGraph = nullptr;

static void runSharedGraphTraverse(int tid, int iterations) {
    for (int k = 0; k < iterations; ++k) {
        traverse(*gSharedGraph);
        ++gOps;
    }
}

// ---------------------------------------------------------------------------
struct Scenario {
    const char* name;
    void (*fn)(int, int);
    void (*setup)();
};

static void setupSharedGraph() {
    gSharedGraph = new BRepGraph();
    if (!buildGraph(*gSharedGraph, makeShape(0))) note("shared graph build failed");
}

static Scenario SCENARIOS[] = {
    {"graph_build_independent", runBuildIndependent, nullptr},
    {"graph_traverse_independent", runTraverseIndependent, nullptr},
    {"graph_build_traverse_independent", runBuildAndTraverseIndependent, nullptr},
    // Adversarial, not for the gate.
    {"shared_graph_traverse", runSharedGraphTraverse, setupSharedGraph},
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
            gOps = 0; gErrors = 0;
            runOne(s.name, threads, iterations);
            note("    ops=%ld errors=%ld", gOps.load(), gErrors.load());
        }
    } else {
        runOne(scenario.c_str(), threads, iterations);
        note("ops=%ld errors=%ld", gOps.load(), gErrors.load());
    }
    return gErrors.load() > 0 ? 1 : 0;
}
