// Portable C++17 reproducer for OCCT parallel crashes (NO IGES)
// Version 2: Grouped tests — each operation type tested in isolation first,
// then combined. Reports crash/pass per group.
//
// Windows (MSVC):
//   cl /std:c++17 /EHsc /MD /I<OCCT_INC> test.cpp /Fe:test.exe /link /LIBPATH:<OCCT_LIB>
//      TKernel.lib TKMath.lib TKG2d.lib TKG3d.lib TKGeomBase.lib TKBRep.lib
//      TKGeomAlgo.lib TKTopAlgo.lib TKPrim.lib TKBO.lib TKBool.lib TKFillet.lib
//      TKShHealing.lib TKOffset.lib TKMesh.lib Advapi32.lib User32.lib Ws2_32.lib
//
// Linux/macOS:
//   clang++ -std=c++17 -w -I<OCCT_INC> test.cpp -L<OCCT_LIB> -lTKernel -lTKMath
//      -lTKG2d -lTKG3d -lTKGeomBase -lTKBRep -lTKGeomAlgo -lTKTopAlgo -lTKPrim
//      -lTKBO -lTKBool -lTKFillet -lTKShHealing -lTKOffset -lTKMesh -lpthread

#include <thread>
#include <vector>
#include <atomic>
#include <mutex>
#include <queue>
#include <functional>
#include <condition_variable>
#include <cstdio>
#include <cstdlib>
#include <chrono>

#include <Extrema_ExtElCS.hxx>
#include <gp_Lin.hxx>
#include <gp_Pln.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Cone.hxx>
#include <gp_Sphere.hxx>

#include <ShapeUpgrade_FaceDivide.hxx>
#include <ShapeUpgrade_ShapeDivideContinuity.hxx>
#include <ShapeUpgrade_UnifySameDomain.hxx>
#include <ShapeFix_Shape.hxx>

#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeCone.hxx>
#include <BRepPrimAPI_MakeTorus.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>

// ============================================================
// Thread pool
// ============================================================
class ThreadPool {
public:
    explicit ThreadPool(int n) : stop_(false) {
        for (int i = 0; i < n; i++)
            workers_.emplace_back([this] {
                while (true) {
                    std::function<void()> task;
                    { std::unique_lock<std::mutex> lock(mu_);
                      cv_.wait(lock, [this] { return stop_ || !tasks_.empty(); });
                      if (stop_ && tasks_.empty()) return;
                      task = std::move(tasks_.front()); tasks_.pop(); }
                    task();
                }
            });
    }
    void submit(std::function<void()> task) {
        { std::lock_guard<std::mutex> lock(mu_); tasks_.push(std::move(task)); }
        cv_.notify_one();
    }
    ~ThreadPool() {
        { std::lock_guard<std::mutex> lock(mu_); stop_ = true; }
        cv_.notify_all();
        for (auto& w : workers_) w.join();
    }
private:
    std::vector<std::thread> workers_;
    std::queue<std::function<void()>> tasks_;
    std::mutex mu_;
    std::condition_variable cv_;
    bool stop_;
};

// ============================================================
// Individual task functions — each creates independent objects
// ============================================================

// Group 1: Extrema (line-cylinder, line-sphere, line-cone)
void task_extrema_line_cyl(int seed) {
    double off = seed * 0.0137;
    gp_Lin line(gp_Pnt(off, off, off), gp_Dir(1, 0.1 * off, 0));
    gp_Cylinder cyl(gp_Ax3(gp_Pnt(5 + off, 5, 0), gp_Dir(0, 0, 1)), 3.0 + off * 0.1);
    Extrema_ExtElCS ext(line, cyl);
    if (ext.IsDone()) {
        for (int j = 1; j <= ext.NbExt(); j++) {
            Extrema_POnCurv pc; Extrema_POnSurf ps;
            ext.Points(j, pc, ps);
        }
    }
}

void task_extrema_line_sphere(int seed) {
    double off = seed * 0.023;
    gp_Lin line(gp_Pnt(0, 0, off), gp_Dir(1, 0, 0));
    gp_Sphere sph(gp_Ax3(gp_Pnt(10 + off, 0, 0), gp_Dir(0, 0, 1)), 5.0);
    Extrema_ExtElCS ext(line, sph);
    if (ext.IsDone()) {
        for (int j = 1; j <= ext.NbExt(); j++) {
            Extrema_POnCurv pc; Extrema_POnSurf ps;
            ext.Points(j, pc, ps);
        }
    }
}

void task_extrema_line_cone(int seed) {
    double off = seed * 0.019;
    gp_Lin line(gp_Pnt(off, 0, 0), gp_Dir(0, 1, 0));
    gp_Cone cone(gp_Ax3(gp_Pnt(5, 5 + off, 0), gp_Dir(0, 0, 1)), 0.3, 2.0);
    try {
        Extrema_ExtElCS ext(line, cone);
        if (ext.IsDone() && !ext.IsParallel()) {
            for (int j = 1; j <= ext.NbExt(); j++) {
                Extrema_POnCurv pc; Extrema_POnSurf ps;
                ext.Points(j, pc, ps);
            }
        }
    } catch (...) {}
}

// Group 2: ShapeUpgrade (FaceDivide, ShapeDivideContinuity)
void task_face_divide_box(int seed) {
    double s = 10.0 + seed * 0.03;
    BRepPrimAPI_MakeBox box(s, s + 5, s + 10);
    TopExp_Explorer ex(box.Shape(), TopAbs_FACE);
    if (ex.More()) {
        try {
            ShapeUpgrade_FaceDivide div(TopoDS::Face(ex.Current()));
            div.Perform();
        } catch (...) {}
    }
}

void task_face_divide_cyl(int seed) {
    double r = 5.0 + seed * 0.02;
    BRepPrimAPI_MakeCylinder cyl(r, 20.0);
    TopExp_Explorer ex(cyl.Shape(), TopAbs_FACE);
    if (ex.More()) {
        try {
            ShapeUpgrade_FaceDivide div(TopoDS::Face(ex.Current()));
            div.Perform();
        } catch (...) {}
    }
}

void task_shape_divide_continuity(int seed) {
    double s = 10.0 + seed * 0.04;
    BRepPrimAPI_MakeBox box(s, s + 3, s + 7);
    try {
        ShapeUpgrade_ShapeDivideContinuity div(box.Shape());
        div.Perform();
    } catch (...) {}
}

// Group 3: Boolean operations
void task_boolean_cut(int seed) {
    double s = 10.0 + seed * 0.07;
    BRepPrimAPI_MakeBox box(s, s, s);
    BRepPrimAPI_MakeSphere sph(gp_Pnt(s/2, s/2, s/2), s * 0.6);
    BRepAlgoAPI_Cut cut(box.Shape(), sph.Shape());
    if (cut.IsDone()) {
        GProp_GProps props;
        BRepGProp::VolumeProperties(cut.Shape(), props);
        (void)props.Mass();
    }
}

// Group 4: Fillet
void task_fillet(int seed) {
    double s = 20.0 + seed * 0.04;
    BRepPrimAPI_MakeBox box(s, s, s);
    TopoDS_Shape shape = box.Shape();
    BRepFilletAPI_MakeFillet fillet(shape);
    TopExp_Explorer ex(shape, TopAbs_EDGE);
    if (ex.More()) {
        fillet.Add(1.0, TopoDS::Edge(ex.Current()));
        try {
            fillet.Build();
            if (fillet.IsDone()) {
                BRepCheck_Analyzer analyzer(fillet.Shape());
                (void)analyzer.IsValid();
            }
        } catch (...) {}
    }
}

// Group 5: ShapeFix
void task_shape_fix(int seed) {
    double s = 12.0 + seed * 0.06;
    BRepPrimAPI_MakeBox box(s, s, s);
    BRepPrimAPI_MakeSphere sph(gp_Pnt(s/2, s/2, s/2), s * 0.7);
    BRepAlgoAPI_Cut cut(box.Shape(), sph.Shape());
    if (cut.IsDone()) {
        try {
            ShapeFix_Shape fixer(cut.Shape());
            fixer.Perform();
            (void)fixer.Shape();
        } catch (...) {}
    }
}

// Group 6: UnifySameDomain
void task_unify(int seed) {
    double s = 10.0 + seed * 0.03;
    BRepPrimAPI_MakeBox box1(s, s, s);
    BRepPrimAPI_MakeBox box2(gp_Pnt(s, 0, 0), s, s, s);
    BRepAlgoAPI_Fuse fuse(box1.Shape(), box2.Shape());
    if (fuse.IsDone()) {
        try {
            ShapeUpgrade_UnifySameDomain u(fuse.Shape());
            u.Build();
            (void)u.Shape();
        } catch (...) {}
    }
}

// Group 7: Shape creation + mass properties
void task_shape_creation(int seed) {
    BRepPrimAPI_MakeBox box(10 + seed * 0.01, 20, 30);
    BRepPrimAPI_MakeCylinder cyl(5.0, 15.0);
    BRepPrimAPI_MakeCone cone(5.0, 2.0, 10.0);
    BRepPrimAPI_MakeTorus torus(10.0, 3.0);
    GProp_GProps props;
    BRepGProp::VolumeProperties(box.Shape(), props);
    BRepGProp::VolumeProperties(cyl.Shape(), props);
    BRepGProp::VolumeProperties(cone.Shape(), props);
    BRepGProp::VolumeProperties(torus.Shape(), props);
}

// ============================================================
// Test runner
// ============================================================

struct GroupResult {
    const char* name;
    bool crashed;  // set by signal handler or by absence of completion
    int rounds_completed;
};

// Run a single group: submit N tasks of one type over R rounds
bool run_group(const char* name, std::function<void(int)> task,
               int workers, int tasks_per_round, int rounds) {
    printf("  Testing %-30s ", name);
    fflush(stdout);

    for (int r = 0; r < rounds; r++) {
        ThreadPool pool(workers);
        for (int i = 0; i < tasks_per_round; i++) {
            int seed = r * 10000 + i;
            pool.submit([&task, seed] { task(seed); });
        }
    }
    printf("PASS (%d rounds x %d tasks)\n", rounds, tasks_per_round);
    return true;
}

// Run all groups mixed
bool run_combined(int workers, int tasks_per_round, int rounds) {
    printf("  Testing %-30s ", "ALL COMBINED");
    fflush(stdout);

    for (int r = 0; r < rounds; r++) {
        ThreadPool pool(workers);
        for (int i = 0; i < tasks_per_round; i++) {
            int seed = r * 10000 + i;
            pool.submit([seed, i] {
                switch (i % 10) {
                    case 0: task_extrema_line_cyl(seed); break;
                    case 1: task_extrema_line_sphere(seed); break;
                    case 2: task_extrema_line_cone(seed); break;
                    case 3: task_face_divide_box(seed); break;
                    case 4: task_face_divide_cyl(seed); break;
                    case 5: task_shape_divide_continuity(seed); break;
                    case 6: task_boolean_cut(seed); break;
                    case 7: task_fillet(seed); break;
                    case 8: task_shape_fix(seed); break;
                    case 9: task_unify(seed); break;
                }
            });
        }
    }
    printf("PASS (%d rounds x %d tasks)\n", rounds, tasks_per_round);
    return true;
}

int main(int argc, char* argv[]) {
    int workers = std::thread::hardware_concurrency();
    if (workers < 8) workers = 16;
    int tasks = 300;
    int rounds = 10;
    if (argc > 1) tasks = atoi(argv[1]);
    if (argc > 2) rounds = atoi(argv[2]);

    printf("OCCT Parallel Crash Reproducer v2 (Portable C++17, NO IGES)\n");
    printf("=============================================================\n");
    printf("Workers: %d, Tasks/round: %d, Rounds: %d\n", workers, tasks, rounds);
    printf("Each task creates independent OCCT objects. No shared state.\n\n");

    // Phase 1: Test each group in isolation
    printf("Phase 1: Individual groups (isolated)\n");
    printf("--------------------------------------\n");
    run_group("Extrema (line-cylinder)",     task_extrema_line_cyl,       workers, tasks, rounds);
    run_group("Extrema (line-sphere)",       task_extrema_line_sphere,    workers, tasks, rounds);
    run_group("Extrema (line-cone)",         task_extrema_line_cone,      workers, tasks, rounds);
    run_group("ShapeUpgrade FaceDivide/Box", task_face_divide_box,        workers, tasks, rounds);
    run_group("ShapeUpgrade FaceDivide/Cyl", task_face_divide_cyl,        workers, tasks, rounds);
    run_group("ShapeUpgrade DivideCont",     task_shape_divide_continuity,workers, tasks, rounds);
    run_group("Boolean (Cut)",               task_boolean_cut,            workers, tasks, rounds);
    run_group("Fillet",                      task_fillet,                 workers, tasks, rounds);
    run_group("ShapeFix",                    task_shape_fix,              workers, tasks, rounds);
    run_group("UnifySameDomain",             task_unify,                  workers, tasks, rounds);
    run_group("Shape creation + GProp",      task_shape_creation,         workers, tasks, rounds);

    printf("\nPhase 2: Combined (all groups mixed)\n");
    printf("--------------------------------------\n");
    run_combined(workers, tasks, rounds);

    printf("\nAll tests completed without crash.\n");
    return 0;
}
