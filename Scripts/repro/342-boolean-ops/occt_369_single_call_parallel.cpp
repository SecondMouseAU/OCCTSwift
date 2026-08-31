// #369 decisive isolation: does BRepAlgoAPI_BuilderAlgo::SetRunParallel(true) alone -- ONE
// top-level call, in a program with NO std::thread anywhere, no concurrent callers, no external
// contention for OSD_ThreadPool::DefaultPool() at all -- produce a wrong result for the box+sphere
// fuse that occt_342_boolean_stress's fuse_multi_parallel scenario found wrong 400/400 times (both
// solo and at 8 concurrent callers, with ZERO TSan races either way)?
//
// If SetRunParallel(true) is wrong here even in a single-threaded DRIVER program (the only
// concurrency at all is OSD_ThreadPool's own internal worker threads, spawned and joined entirely
// within this one Build() call), the defect is not a cross-caller/thread-safety bug at all: it is
// BRepAlgoAPI_BuilderAlgo/BOPAlgo_PaveFiller producing a WRONG ANSWER whenever its own internal
// parallel dispatch actually uses more than one real OS thread, independent of any race.
//
// Usage: occt_369_single_call_parallel [reps]

#include <cstdio>
#include <cstdlib>

#include <BRepAlgoAPI_BuilderAlgo.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <GProp_GProps.hxx>
#include <BRepGProp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_ListOfShape.hxx>
#include <gp_Pnt.hxx>

static int faceCount(const TopoDS_Shape& s) {
    int n = 0;
    for (TopExp_Explorer ex(s, TopAbs_FACE); ex.More(); ex.Next()) ++n;
    return n;
}

static double volumeOf(const TopoDS_Shape& s) {
    GProp_GProps props;
    BRepGProp::VolumeProperties(s, props);
    return props.Mass();
}

static void runOnce(bool runParallel, int& faces, double& volume) {
    TopTools_ListOfShape args;
    args.Append(BRepPrimAPI_MakeBox(10, 10, 10).Shape());
    args.Append(BRepPrimAPI_MakeSphere(gp_Pnt(5, 5, 5), 6).Shape());
    BRepAlgoAPI_BuilderAlgo builder;
    builder.SetArguments(args);
    builder.SetRunParallel(runParallel);
    builder.Build();
    if (!builder.IsDone()) {
        faces = -1;
        volume = -1;
        return;
    }
    TopoDS_Shape result = builder.Shape();
    faces = faceCount(result);
    volume = volumeOf(result);
}

int main(int argc, char** argv) {
    int reps = argc > 1 ? atoi(argv[1]) : 20;

    int serialWrong = 0, parallelWrong = 0;
    int refFaces = -1;
    double refVolume = -1;

    for (int i = 0; i < reps; ++i) {
        int faces;
        double volume;

        runOnce(false, faces, volume);
        if (i == 0) {
            refFaces = faces;
            refVolume = volume;
            printf("serial reference: faces=%d volume=%.6f\n", refFaces, refVolume);
        } else if (faces != refFaces) {
            serialWrong++;
            printf("[serial   rep %d] diverged: faces=%d volume=%.6f\n", i, faces, volume);
        }

        runOnce(true, faces, volume);
        if (faces != refFaces) {
            parallelWrong++;
            printf("[parallel rep %d] diverged: faces=%d volume=%.6f (expected faces=%d volume=%.6f)\n",
                   i, faces, volume, refFaces, refVolume);
        }
    }

    printf("done: reps=%d serialWrong=%d parallelWrong=%d\n", reps, serialWrong, parallelWrong);
    return (serialWrong > 0 || parallelWrong == 0) ? 1 : 0;  // fail loudly if serial ever wrong,
                                                              // or if parallel NEVER diverges (test
                                                              // would then prove nothing)
}
