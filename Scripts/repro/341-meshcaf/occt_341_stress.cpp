// Multi-threaded stress harness for OCCTSwift#341: characterizing the claimed
// "pre-existing non-deterministic NCollection arm64 race under parallel execution"
// against a ThreadSanitizer-instrumented OCCT V8_0_0_p1 build (+ all 10 carried
// patches). Pure C++, no Swift/bridge layer -- isolates OCCT itself.
//
// Usage: occt_341_stress <scenario> <threads> <iterations> [tmpDir]
//   scenarios: create_fillet_boolean | shared_adaptor_cache | obj_roundtrip_unique
//              | obj_roundtrip_shared | mesh_independent
//
// obj_roundtrip_unique is the one that matters: it is the minimal repro for the
// XCAFDoc_ShapeTool::theAutoNaming race (see README.md).

#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRepMesh_IncrementalMesh.hxx>

#include <GeomAPI_Interpolate.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <Geom_BSplineCurve.hxx>
#include <GeomAdaptor_Curve.hxx>

#include <RWObj_CafReader.hxx>
#include <RWObj_CafWriter.hxx>
#include <TDocStd_Document.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <TDF_LabelSequence.hxx>
#include <Message_ProgressRange.hxx>

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
// Scenario: independent create -> fuse -> fillet -> volume, per thread.
// Baseline: mirrors #298's already-fixed repro shape (fuse-then-fillet).
// ---------------------------------------------------------------------------
void runCreateFilletBoolean(int id, int iterations) {
    for (int it = 0; it < iterations; ++it) {
        TopoDS_Shape box = BRepPrimAPI_MakeBox(10, 10, 10).Shape();
        TopoDS_Shape sph = BRepPrimAPI_MakeSphere(gp_Pnt(5, 5, 5), 6).Shape();
        BRepAlgoAPI_Fuse fuse(box, sph);
        fuse.Build();
        if (!fuse.IsDone()) { gErrors++; continue; }
        TopoDS_Shape fused = fuse.Shape();

        BRepFilletAPI_MakeFillet mkFillet(fused);
        TopExp_Explorer exp(fused, TopAbs_EDGE);
        int n = 0;
        for (; exp.More() && n < 4; exp.Next(), ++n) {
            mkFillet.Add(0.5, TopoDS::Edge(exp.Current()));
        }
        mkFillet.Build();
        if (mkFillet.IsDone()) {
            TopoDS_Shape filleted = mkFillet.Shape();
            GProp_GProps props;
            BRepGProp::VolumeProperties(filleted, props);
            double v = props.Mass();
            if (!(v > 0)) { gErrors++; note("[thread %d] fillet volume <= 0: %f", id, v); }
        }
        gOps++;
    }
}

// ---------------------------------------------------------------------------
// Scenario: N threads independently mesh independent shapes concurrently
// (BRepMesh_IncrementalMesh -- internally parallel via OSD_ThreadPool).
// ---------------------------------------------------------------------------
void runMeshIndependent(int id, int iterations) {
    for (int it = 0; it < iterations; ++it) {
        TopoDS_Shape sph = BRepPrimAPI_MakeSphere(gp_Pnt(id, it, 0), 5 + (it % 3)).Shape();
        BRepMesh_IncrementalMesh mesher(sph, 0.1);
        mesher.Perform();
        if (!mesher.IsDone()) { gErrors++; note("[thread %d] mesh not done", id); }
        gOps++;
    }
}

// ---------------------------------------------------------------------------
// Scenario: deliberately SHARE one Geom_BSplineCurve + one GeomAdaptor_Curve
// across all threads, hammering D0/D1 concurrently. This directly targets
// GeomAdaptor_Curve's mutable, unsynchronized BSplCLib_Cache (RebuildCache /
// IsCacheValid / D0 / D1 -- confirmed via source read, zero locking) named in
// OCCTSerialQueue.swift's doc comment ("BSpline adaptor caches ... have data
// races"). This is intentionally an ADVERSARIAL scenario the current Swift
// bridge API does NOT reach (every bridge call site constructs its own
// function-local GeomAdaptor_Curve) -- it characterizes the underlying OCCT
// class in isolation, not a reachable OCCTSwift bug.
// ---------------------------------------------------------------------------
static Handle(Geom_BSplineCurve) makeSharedBSpline() {
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

void runSharedAdaptorCache(int id, int iterations, GeomAdaptor_Curve* sharedAdaptor,
                            double uFirst, double uLast) {
    for (int it = 0; it < iterations; ++it) {
        double u = uFirst + (uLast - uFirst) * ((id * 37 + it) % 101) / 100.0;
        gp_Pnt p;
        sharedAdaptor->D0(u, p);
        if (!(std::isfinite(p.X()) && std::isfinite(p.Y()) && std::isfinite(p.Z()))) {
            gErrors++;
            note("[thread %d] shared-adaptor D0 produced non-finite point at u=%f", id, u);
        }
        gOps++;
    }
}

// ---------------------------------------------------------------------------
// Scenario: N threads round-trip OBJ (write then read back), each its OWN
// uniquely-named file -- isolates OCCT's RWObj_CafReader/Writer + XCAF
// document machinery from any test-harness file-path collision. This mirrors
// the empirical SIGSEGV observed under `swift test` (garbage-looking fault
// address right after two DIFFERENT tests' concurrent OBJ mesh reads
// interleaved in the log, each with its own unique temp path).
// ---------------------------------------------------------------------------
void runObjRoundtripUnique(int id, int iterations, const std::string& tmpDir) {
    for (int it = 0; it < iterations; ++it) {
        TopoDS_Shape box = BRepPrimAPI_MakeBox(10, 20, 30).Shape();
        BRepMesh_IncrementalMesh mesher(box, 0.5);
        mesher.Perform();

        std::ostringstream pathStream;
        pathStream << tmpDir << "/occt341_obj_" << id << "_" << it << ".obj";
        std::string path = pathStream.str();

        Handle(TDocStd_Document) writeDoc = new TDocStd_Document("BinXCAF");
        Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(writeDoc->Main());
        shapeTool->AddShape(box);

        NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> fileInfo;
        RWObj_CafWriter writer(path.c_str());
        Message_ProgressRange range;
        bool wroteOk = writer.Perform(writeDoc, fileInfo, range);
        if (!wroteOk) { gErrors++; note("[thread %d] OBJ write failed: %s", id, path.c_str()); continue; }

        Handle(TDocStd_Document) readDoc = new TDocStd_Document("BinXCAF");
        RWObj_CafReader reader;
        reader.SetDocument(readDoc);
        bool readOk = reader.Perform(path.c_str(), range);
        if (!readOk) { gErrors++; note("[thread %d] OBJ read failed: %s", id, path.c_str()); continue; }

        std::remove(path.c_str());
        gOps++;
    }
}

// ---------------------------------------------------------------------------
// Scenario: N threads round-trip OBJ through the SAME literal shared path --
// deliberately adversarial. If this (and only this) crashes while the
// unique-path scenario above is clean, the mechanism is a plain file race,
// not OCCT internal memory corruption.
// ---------------------------------------------------------------------------
void runObjRoundtripShared(int id, int iterations, const std::string& tmpDir) {
    std::string path = tmpDir + "/occt341_obj_SHARED.obj";
    for (int it = 0; it < iterations; ++it) {
        TopoDS_Shape box = BRepPrimAPI_MakeBox(10, 20, 30).Shape();
        BRepMesh_IncrementalMesh mesher(box, 0.5);
        mesher.Perform();

        Handle(TDocStd_Document) writeDoc = new TDocStd_Document("BinXCAF");
        Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(writeDoc->Main());
        shapeTool->AddShape(box);

        NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> fileInfo;
        RWObj_CafWriter writer(path.c_str());
        Message_ProgressRange range;
        writer.Perform(writeDoc, fileInfo, range);

        Handle(TDocStd_Document) readDoc = new TDocStd_Document("BinXCAF");
        RWObj_CafReader reader;
        reader.SetDocument(readDoc);
        bool readOk = reader.Perform(path.c_str(), range);
        if (!readOk) { gErrors++; }
        gOps++;
    }
}

int main(int argc, char** argv) {
    std::string scenario = argc > 1 ? argv[1] : "create_fillet_boolean";
    int threads = argc > 2 ? atoi(argv[2]) : 8;
    int iterations = argc > 3 ? atoi(argv[3]) : 20;
    std::string tmpDir = argc > 4 ? argv[4] : "/tmp";

    note("scenario=%s threads=%d iterations=%d", scenario.c_str(), threads, iterations);

    std::vector<std::thread> pool;
    auto t0 = std::chrono::steady_clock::now();

    if (scenario == "create_fillet_boolean") {
        for (int i = 0; i < threads; ++i) pool.emplace_back(runCreateFilletBoolean, i, iterations);
    } else if (scenario == "mesh_independent") {
        for (int i = 0; i < threads; ++i) pool.emplace_back(runMeshIndependent, i, iterations);
    } else if (scenario == "shared_adaptor_cache") {
        Handle(Geom_BSplineCurve) curve = makeSharedBSpline();
        GeomAdaptor_Curve sharedAdaptor(curve);
        double uFirst = curve->FirstParameter();
        double uLast = curve->LastParameter();
        for (int i = 0; i < threads; ++i)
            pool.emplace_back(runSharedAdaptorCache, i, iterations, &sharedAdaptor, uFirst, uLast);
    } else if (scenario == "obj_roundtrip_unique") {
        for (int i = 0; i < threads; ++i) pool.emplace_back(runObjRoundtripUnique, i, iterations, tmpDir);
    } else if (scenario == "obj_roundtrip_shared") {
        for (int i = 0; i < threads; ++i) pool.emplace_back(runObjRoundtripShared, i, iterations, tmpDir);
    } else {
        note("unknown scenario: %s", scenario.c_str());
        return 2;
    }

    for (auto& t : pool) t.join();

    auto t1 = std::chrono::steady_clock::now();
    double secs = std::chrono::duration<double>(t1 - t0).count();
    note("done: ops=%ld errors=%ld elapsed=%.2fs", gOps.load(), gErrors.load(), secs);
    return gErrors.load() > 0 ? 1 : 0;
}
