// Multi-threaded stress harness for OCCTSwift#1154: Topology flag mutation race
// Characterizes TopoDS_TShape::myState data races when the SAME TShape is
// accessed concurrently from multiple threads.
// Pure C++, no Swift/bridge layer -- isolates OCCT itself.
//
// Usage: occt_1154_stress <scenario> <threads> <iterations>
//   scenarios: tshape_myState_race | boolean_shared_topology

#include <atomic>
#include <chrono>
#include <cstdarg>
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
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_TShape.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>
#include <gp_Ax1.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

// Force non-inline access to myState to make TSan see the race
// We create a helper that directly manipulates myState through a pointer
static inline void setBit_noninline(uint16_t* state, uint16_t bit, bool on) {
    if (on) *state |= bit;
    else *state &= ~bit;
}

static inline bool getBit_noninline(const uint16_t* state, uint16_t bit) {
    return (*state & bit) != 0;
}

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
// Scenario 1: Direct myState race - multiple threads concurrently call
// setBit/getBit on the SAME TShape's myState field.
// This directly targets the non-atomic bitwise operations.
// ---------------------------------------------------------------------------
void runTShapeMyStateRace(int id, int iterations, TopoDS_TShape* sharedTShape) {
    // Bit constants from TopoDS_TShape
    constexpr uint16_t Bit_Free       = 0x0010;
    constexpr uint16_t Bit_Modified   = 0x0020;
    constexpr uint16_t Bit_Checked    = 0x0040;
    constexpr uint16_t Bit_Orientable = 0x0080;
    constexpr uint16_t Bit_Closed     = 0x0100;
    constexpr uint16_t Bit_Infinite   = 0x0200;
    constexpr uint16_t Bit_Convex     = 0x0400;
    constexpr uint16_t Bit_Locked     = 0x0800;
    
    // Get pointer to myState - it's private so we use the public methods
    // but we'll call them in a loop to trigger the race
    
    for (int it = 0; it < iterations; ++it) {
        // Concurrently read/write all flag bits
        sharedTShape->Free(!sharedTShape->Free());
        sharedTShape->Modified(!sharedTShape->Modified());
        sharedTShape->Checked(!sharedTShape->Checked());
        sharedTShape->Orientable(!sharedTShape->Orientable());
        sharedTShape->Closed(!sharedTShape->Closed());
        sharedTShape->Infinite(!sharedTShape->Infinite());
        sharedTShape->Convex(!sharedTShape->Convex());
        sharedTShape->Locked(!sharedTShape->Locked());
        
        // Read back
        (void)sharedTShape->Free();
        (void)sharedTShape->Modified();
        (void)sharedTShape->Checked();
        (void)sharedTShape->Orientable();
        (void)sharedTShape->Closed();
        (void)sharedTShape->Infinite();
        (void)sharedTShape->Convex();
        (void)sharedTShape->Locked();
        
        gOps++;
    }
}

// ---------------------------------------------------------------------------
// Scenario 2: Boolean result shares TShapes with inputs.
// Concurrent access to shared topology from result and inputs.
// ---------------------------------------------------------------------------
void runBooleanSharedTopology(int id, int iterations) {
    for (int it = 0; it < iterations; ++it) {
        // Create base shapes
        TopoDS_Shape box = BRepPrimAPI_MakeBox(10, 10, 10).Shape();
        TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(gp_Pnt(5, 5, 5), 6).Shape();

        // Fuse - result shares TShapes with inputs
        BRepAlgoAPI_Fuse fuse(box, sphere);
        fuse.Build();
        if (!fuse.IsDone()) { gErrors++; continue; }
        TopoDS_Shape result = fuse.Shape();

        // Collect all TShapes from result (these are shared with box/sphere)
        std::vector<Handle(TopoDS_TShape)> sharedTShapes;
        TopExp_Explorer exp(result, TopAbs_EDGE);
        for (; exp.More(); exp.Next()) {
            TopoDS_Edge edge = TopoDS::Edge(exp.Current());
            Handle(TopoDS_TShape) ts = edge.TShape();
            if (!ts.IsNull()) sharedTShapes.push_back(ts);
        }
        exp.Init(result, TopAbs_FACE);
        for (; exp.More(); exp.Next()) {
            TopoDS_Face face = TopoDS::Face(exp.Current());
            Handle(TopoDS_TShape) ts = face.TShape();
            if (!ts.IsNull()) sharedTShapes.push_back(ts);
        }

        // Remove duplicates
        for (size_t i = 0; i < sharedTShapes.size(); ++i) {
            for (size_t j = i + 1; j < sharedTShapes.size(); ) {
                if (sharedTShapes[i] == sharedTShapes[j]) {
                    sharedTShapes.erase(sharedTShapes.begin() + j);
                } else {
                    ++j;
                }
            }
        }

        // Now concurrently access the shared TShapes
        std::vector<std::thread> workers;
        
        auto workerFunc = [&](int workerId) {
            for (int i = 0; i < 20; ++i) {
                for (auto& ts : sharedTShapes) {
                    if (!ts.IsNull()) {
                        // These all read/write myState via non-atomic bitwise ops
                        ts->Free(!ts->Free());
                        ts->Modified(!ts->Modified());
                        ts->Checked(!ts->Checked());
                        ts->Orientable(!ts->Orientable());
                        ts->Closed(!ts->Closed());
                        ts->Infinite(!ts->Infinite());
                        ts->Convex(!ts->Convex());
                        ts->Locked(!ts->Locked());
                        
                        (void)ts->Free();
                        (void)ts->Modified();
                        (void)ts->Checked();
                        (void)ts->Orientable();
                        (void)ts->Closed();
                        (void)ts->Infinite();
                        (void)ts->Convex();
                        (void)ts->Locked();
                    }
                }
            }
        };

        int nThreads = 8;
        for (int i = 0; i < nThreads; ++i) {
            workers.emplace_back(workerFunc, i);
        }
        for (auto& t : workers) t.join();
        
        gOps++;
    }
}

// ---------------------------------------------------------------------------
// Scenario 3: Concurrent orientation flips via Transform on shared shape
// ---------------------------------------------------------------------------
void runConcurrentOrientation(int id, int iterations) {
    for (int it = 0; it < iterations; ++it) {
        // Create ONE shape that all threads will modify
        TopoDS_Shape baseShape = BRepPrimAPI_MakeBox(10, 10, 10).Shape();
        
        std::vector<std::thread> workers;
        
        auto workerFunc = [&](int workerId) {
            for (int i = 0; i < 10; ++i) {
                gp_Trsf trsf;
                trsf.SetRotation(gp_Ax1(gp_Pnt(0,0,0), gp_Dir(0,0,1)), workerId * 0.01);
                
                // copy = Standard_False means it modifies the shape in place
                BRepBuilderAPI_Transform transformer(baseShape, trsf, Standard_False);
                transformer.Build();
                if (!transformer.IsDone()) { gErrors++; return; }
                
                TopoDS_Shape transformed = transformer.Shape();
                
                // Read orientation
                TopExp_Explorer exp(transformed, TopAbs_EDGE);
                for (; exp.More(); exp.Next()) {
                    TopoDS_Edge edge = TopoDS::Edge(exp.Current());
                    TopAbs_Orientation o = edge.Orientation();
                    (void)o;
                }
            }
        };

        int nThreads = 4;
        for (int i = 0; i < nThreads; ++i) {
            workers.emplace_back(workerFunc, i);
        }
        for (auto& t : workers) t.join();
        
        gOps++;
    }
}

int main(int argc, char** argv) {
    std::string scenario = argc > 1 ? argv[1] : "tshape_myState_race";
    int threads = argc > 2 ? atoi(argv[2]) : 8;
    int iterations = argc > 3 ? atoi(argv[3]) : 20;

    note("scenario=%s threads=%d iterations=%d", scenario.c_str(), threads, iterations);

    std::vector<std::thread> pool;
    auto t0 = std::chrono::steady_clock::now();

    if (scenario == "tshape_myState_race") {
        // Create one TShape to share
        TopoDS_Shape shape = BRepPrimAPI_MakeBox(10, 10, 10).Shape();
        TopExp_Explorer exp(shape, TopAbs_FACE);
        Handle(TopoDS_TShape) sharedTShape;
        for (; exp.More(); exp.Next()) {
            TopoDS_Face face = TopoDS::Face(exp.Current());
            sharedTShape = face.TShape();
            if (!sharedTShape.IsNull()) break;
        }
        
        if (sharedTShape.IsNull()) {
            note("ERROR: Could not get TShape");
            return 2;
        }
        
        note("Using TShape at %p", sharedTShape.get());
        for (int i = 0; i < threads; ++i)
            pool.emplace_back(runTShapeMyStateRace, i, iterations, sharedTShape.get());
    } else if (scenario == "boolean_shared_topology") {
        for (int i = 0; i < threads; ++i)
            pool.emplace_back(runBooleanSharedTopology, i, iterations);
    } else if (scenario == "concurrent_orientation") {
        for (int i = 0; i < threads; ++i)
            pool.emplace_back(runConcurrentOrientation, i, iterations);
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