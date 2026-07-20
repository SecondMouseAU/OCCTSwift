// Ground-truth reproducer for OCCTSwift#319 Track 2 / OCCTReconstruct#295.
// Loads the extracted single-face pathological shell and runs
// BOPAlgo_ArgumentAnalyzer's self-interference check on it directly (no
// Swift/bridge layer), matching the exact call OCCTShapeSelfIntersectsBounded
// makes. Bounded to a wall-clock ceiling for the "does it hang" measurement.
#include <BOPAlgo_ArgumentAnalyzer.hxx>
#include <BRep_Builder.hxx>
#include <BRepTools.hxx>
#include <TopoDS_Shape.hxx>
#include <Message_ProgressIndicator.hxx>
#include <Message_ProgressScope.hxx>

#include <chrono>
#include <cstdio>
#include <csignal>
#include <unistd.h>

class WatchdogBreaker : public Message_ProgressIndicator {
public:
    explicit WatchdogBreaker(double seconds)
        : myDeadline(std::chrono::steady_clock::now()
            + std::chrono::duration_cast<std::chrono::steady_clock::duration>(
                std::chrono::duration<double>(seconds))) {}
    Standard_Boolean UserBreak() override {
        return std::chrono::steady_clock::now() >= myDeadline ? Standard_True : Standard_False;
    }
    void Show(const Message_ProgressScope&, const Standard_Boolean) override {}
    DEFINE_STANDARD_RTTI_INLINE(WatchdogBreaker, Message_ProgressIndicator)
private:
    std::chrono::steady_clock::time_point myDeadline;
};

int main(int argc, char** argv) {
    const char* path = argc > 1 ? argv[1] : "dualskin_lateral.15.brep";
    double timeoutSeconds = argc > 2 ? atof(argv[2]) : 30.0;
    double wallCeiling = argc > 3 ? atof(argv[3]) : 20.0; // how long WE wait before giving up

    TopoDS_Shape shape;
    BRep_Builder builder;
    if (!BRepTools::Read(shape, path, builder)) {
        std::printf("FAIL: could not read %s\n", path);
        return 2;
    }
    std::printf("Loaded shape from %s\n", path);

    auto t0 = std::chrono::steady_clock::now();

    BOPAlgo_ArgumentAnalyzer aa;
    aa.SetShape1(shape);
    aa.ArgumentTypeMode() = true;
    aa.SelfInterMode() = true;
    aa.StopOnFirstFaulty() = true;
    aa.SetRunParallel(false);

    Handle(WatchdogBreaker) breaker = new WatchdogBreaker(timeoutSeconds);
    Message_ProgressRange range = breaker->Start();

    // Run Perform() but bound OUR OWN wait: fork isn't available easily here,
    // so just call Perform() directly -- if it doesn't return within
    // wallCeiling, the process itself will just keep running past that; the
    // caller (shell script) is expected to kill -9 it and inspect via `sample`.
    aa.Perform(range);

    auto t1 = std::chrono::steady_clock::now();
    double elapsed = std::chrono::duration<double>(t1 - t0).count();
    std::printf("Perform() returned after %.3fs (requested cooperative timeout %.1fs)\n",
                elapsed, timeoutSeconds);
    std::printf("HasFaulty = %d\n", aa.HasFaulty() ? 1 : 0);
    std::printf("breaker tripped = %d\n", breaker->UserBreak() ? 1 : 0);
    return 0;
}
