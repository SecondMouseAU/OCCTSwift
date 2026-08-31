// #369 root-cause, step 2 of the README's suggested next steps: exercise BOPTools_Parallel.hxx's
// ContextFunctor2 (the exact class BOPAlgo_PaveFiller uses via `BOPTools_Parallel::Perform(bool,
// TypeSolverVector&, handle<TypeContext>&)`) directly, with a toy solver/context pair instead of
// real BOP geometry. occt_369_threadpool_isolation.cpp already exonerated OSD_ThreadPool's own
// Lock/Free/WakeUp/WaitIdle bookkeeping; this harness keeps that primitive in the loop but adds
// BACK exactly the machinery occt_369_threadpool_isolation.cpp deliberately left out:
//   - a per-Launcher `ContextFunctor2::myContextArray` sized to [Lower,Upper] and indexed by
//     `theThreadIndex` (the value OSD_ThreadPool.cxx's Launcher constructor RENUMBERS per-Launcher,
//     "make thread index to fit into myThreads range" -- so two concurrent Launchers can and do
//     hand out the SAME numeric theThreadIndex to DIFFERENT physical worker threads);
//   - a lazily-constructed-per-slot Context object built via
//     `new TypeContext(NCollection_BaseAllocator::CommonBaseAllocator())`, the exact allocator
//     call BOPAlgo_PaveFiller's real IntTools_Context construction uses;
//   - the SetContext()/ChangeLast() self-thread binding BOPTools_Parallel::Perform does before
//     dispatch.
//
// If THIS reproduces corruption, the bug is confirmed inside BOPTools_Parallel.hxx itself
// (the ContextFunctor2/thread-index-reuse machinery), not further down in
// BOPAlgo_PaveFiller/BOPDS_DS/IntTools_Context. If it stays clean, the bug is further down.
//
// Usage: occt_369_contextfunctor2_isolation <threads> <iterations> <itemsPerCall>

#include <atomic>
#include <chrono>
#include <cstdarg>
#include <cstdio>
#include <cstdlib>
#include <thread>
#include <vector>

#include <BOPTools_Parallel.hxx>
#include <NCollection_DynamicArray.hxx>
#include <Standard_Transient.hxx>

std::atomic<long> gOps{0};
std::atomic<long> gErrors{0};

static void note(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vfprintf(stderr, fmt, args);
    va_end(args);
    fprintf(stderr, "\n");
}

// Mirrors IntTools_Context: one instance is meant to be private to a single (Launcher-local)
// thread slot for the duration of one BOPTools_Parallel::Perform call. It carries a "which call
// created me" tag and a mutable per-instance counter, exactly the shape a real cached-classifier
// context has (state a solver reads/writes across its Perform() calls on the same context).
class ToyContext : public Standard_Transient {
public:
    explicit ToyContext(const occ::handle<NCollection_BaseAllocator>& /*alloc*/) {}
    int64_t owner = -1;  // first caller-tag that touched this context instance
    int64_t hits = 0;    // how many Perform() calls used this exact context instance
};

// Mirrors BOPAlgo_EdgeFace/IntTools_EdgeFace's interface as BOPTools_Parallel::ContextFunctor2
// requires it: SetContext(handle<TypeContext>&) then Perform().
class ToySolver {
public:
    void SetContext(const occ::handle<ToyContext>& ctx) { myContext = ctx; }

    // Real work: claim a private heap slot with our own tag, hold it briefly (to widen any
    // interleaving window), then verify nobody else touched it -- same private-buffer-tag check
    // occt_369_threadpool_isolation.cpp uses, plus a check that the CONTEXT instance we were
    // handed is only ever used by callers matching the same top-level "owner" tag, which is what
    // ContextFunctor2's per-Launcher myContextArray is supposed to guarantee.
    void Perform() {
        *mySlot = myTag;
        std::this_thread::yield();
        if (*mySlot != myTag) {
            gErrors++;
            note("[tag %lld] slot corrupted: expected %lld, got %lld", (long long)myTag,
                 (long long)myTag, (long long)*mySlot);
        }

        if (!myContext.IsNull()) {
            int64_t prevOwner = myContext->owner;
            int64_t ownerHigh = myTag >> 32;  // caller id, ignoring iteration/item bits
            if (myContext->hits == 0) {
                myContext->owner = ownerHigh;
            } else if (myContext->owner != ownerHigh && prevOwner != -1) {
                gErrors++;
                note("[tag %lld] context instance %p already owned by caller %lld (this call is "
                     "caller %lld) -- ContextFunctor2 handed the SAME context slot to two "
                     "DIFFERENT top-level callers within an overlapping window",
                     (long long)myTag, (void*)myContext.get(), (long long)prevOwner,
                     (long long)ownerHigh);
            }
            myContext->hits++;
        }
    }

    int64_t                 myTag  = 0;
    int64_t*                mySlot = nullptr;
    occ::handle<ToyContext> myContext;
};

typedef NCollection_DynamicArray<ToySolver> ToySolverVector;

void runCaller(int id, int iterations, int itemsPerCall) {
    for (int it = 0; it < iterations; ++it) {
        std::vector<int64_t>    buffer(itemsPerCall, -1);
        ToySolverVector          solvers;
        occ::handle<ToyContext>  mainContext = new ToyContext(nullptr);
        int64_t                  base        = (static_cast<int64_t>(id) << 32) |
                                    (static_cast<int64_t>(it) << 16);

        for (int i = 0; i < itemsPerCall; ++i) {
            ToySolver& s = solvers.Appended();
            s.myTag      = base | static_cast<int64_t>(i);
            s.mySlot     = &buffer[i];
        }

        // Exact call shape BOPAlgo_PaveFiller uses: BOPTools_Parallel::Perform(myRunParallel,
        // aVEdgeFace, myContext) with theIsRunParallel=true, routing through
        // OSD_ThreadPool::DefaultPool() via ContextFunctor2 since USE_TBB=OFF in this build means
        // OSD_Parallel::ToUseOcctThreads() defaults true.
        BOPTools_Parallel::Perform(/*theIsRunParallel=*/true, solvers, mainContext);

        for (int i = 0; i < itemsPerCall; ++i) {
            int64_t expected = base | static_cast<int64_t>(i);
            if (buffer[i] != expected) {
                gErrors++;
                note("[caller %d it %d] final slot %d: expected %lld, got %lld", id, it, i,
                     (long long)expected, (long long)buffer[i]);
            }
        }
        gOps++;
    }
}

int main(int argc, char** argv) {
    int threads      = argc > 1 ? atoi(argv[1]) : 8;
    int iterations   = argc > 2 ? atoi(argv[2]) : 50;
    int itemsPerCall = argc > 3 ? atoi(argv[3]) : 64;

    note("threads=%d iterations=%d itemsPerCall=%d poolThreads=%d", threads, iterations,
         itemsPerCall, OSD_ThreadPool::DefaultPool()->NbThreads());

    std::vector<std::thread> pool;
    auto t0 = std::chrono::steady_clock::now();
    for (int i = 0; i < threads; ++i) pool.emplace_back(runCaller, i, iterations, itemsPerCall);
    for (auto& t : pool) t.join();
    auto t1 = std::chrono::steady_clock::now();

    double secs = std::chrono::duration<double>(t1 - t0).count();
    note("done: ops=%ld errors=%ld elapsed=%.2fs", gOps.load(), gErrors.load(), secs);
    return gErrors.load() > 0 ? 1 : 0;
}
