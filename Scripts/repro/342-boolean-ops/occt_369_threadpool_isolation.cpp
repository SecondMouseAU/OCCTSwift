// Isolates #369's question: is OSD_ThreadPool::DefaultPool() itself unsafe for concurrent
// INDEPENDENT Launcher users (multiple unrelated top-level threads each locking a subset of the
// pool and dispatching trivial, self-contained work with no OCCT geometry/topology involved), or
// is #367's corruption specific to how BOPTools_Parallel/BOPAlgo_PaveFiller use the pool?
//
// Each top-level thread creates its own Launcher on the SAME DefaultPool(), and each dispatched
// job only ever touches memory local to that Launcher's own call (a private buffer, indexed by
// the DATA index the Job::Perform loop hands out via JobRange::It() -- not the thread index,
// deliberately, to also fland any cross-Launcher thread-index collision). If this stays clean,
// the pool's own Lock/Free/WakeUp/WaitIdle bookkeeping is exonerated and the bug is upstream of
// it (BOPTools_Parallel's usage, or something in the OCCT allocator triggered only under real
// BOPAlgo work). If this reproduces corruption/races too, the bug is in OSD_ThreadPool itself.
//
// Usage: occt_369_threadpool_isolation <threads> <iterations>

#include <atomic>
#include <chrono>
#include <cstdarg>
#include <cstdio>
#include <cstdlib>
#include <thread>
#include <vector>

#include <OSD_ThreadPool.hxx>

std::atomic<long> gOps{0};
std::atomic<long> gErrors{0};

static void note(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vfprintf(stderr, fmt, args);
    va_end(args);
    fprintf(stderr, "\n");
}

// Each top-level caller does N trivial "jobs": write its own unique tag into a private buffer
// slot, then immediately read it back. If any other Launcher's worker ever touches this buffer,
// or if a worker writes/reads the WRONG slot, the readback will show something other than
// exactly what this call itself wrote (a foreign tag value, or the wrong slot's tag).
struct Job {
    std::vector<int64_t>* buffer;
    int64_t tag;
};

void runCaller(int id, int iterations) {
    for (int it = 0; it < iterations; ++it) {
        const int kSlots = 64;
        std::vector<int64_t> buffer(kSlots, -1);
        int64_t tag = (static_cast<int64_t>(id) << 32) | static_cast<int64_t>(it);

        OSD_ThreadPool::Launcher launcher(*OSD_ThreadPool::DefaultPool(), -1);
        launcher.Perform(0, kSlots, [&](int /*threadIndex*/, int dataIndex) {
            buffer[dataIndex] = tag;
            // Immediately read back -- if another Launcher's worker interleaved a write to
            // this exact heap slot between our write and this read, we'd see a foreign tag.
            if (buffer[dataIndex] != tag) {
                gErrors++;
                note("[caller %d it %d] slot %d: wrote tag=%lld, read back %lld", id, it,
                     dataIndex, (long long)tag, (long long)buffer[dataIndex]);
            }
        });

        // Final full-buffer check: every slot must hold exactly this call's tag.
        for (int i = 0; i < kSlots; ++i) {
            if (buffer[i] != tag) {
                gErrors++;
                note("[caller %d it %d] final check slot %d: expected tag=%lld, got %lld", id, it,
                     i, (long long)tag, (long long)buffer[i]);
            }
        }
        gOps++;
    }
}

int main(int argc, char** argv) {
    int threads = argc > 1 ? atoi(argv[1]) : 8;
    int iterations = argc > 2 ? atoi(argv[2]) : 50;

    note("threads=%d iterations=%d poolThreads=%d", threads, iterations,
         OSD_ThreadPool::DefaultPool()->NbThreads());

    std::vector<std::thread> pool;
    auto t0 = std::chrono::steady_clock::now();
    for (int i = 0; i < threads; ++i) pool.emplace_back(runCaller, i, iterations);
    for (auto& t : pool) t.join();
    auto t1 = std::chrono::steady_clock::now();

    double secs = std::chrono::duration<double>(t1 - t0).count();
    note("done: ops=%ld errors=%ld elapsed=%.2fs", gOps.load(), gErrors.load(), secs);
    return gErrors.load() > 0 ? 1 : 0;
}
