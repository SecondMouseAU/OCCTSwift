// Barrier-synchronized variant of occt_344_newdoc_only.cpp: instead of letting threads run
// freely (where OS scheduling naturally spreads out their NewDocument() calls), every thread
// spin-waits at a barrier before each iteration so all threads call
// XCAFApp_Application::GetApplication()->NewDocument() at nearly the same instant, maximizing
// the odds of colliding inside the unsynchronized CDF_Directory::Add() -> NCollection_List::
// Append() critical section on each round.
//
// Usage: occt_344_barrier <threads> <rounds>

#include <atomic>
#include <chrono>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <execinfo.h>
#include <thread>
#include <unistd.h>
#include <vector>

#include <TDocStd_Document.hxx>
#include <XCAFApp_Application.hxx>
#include <XCAFDoc_DocumentTool.hxx>

// Temporary diagnostic-only signal handler (per feedback-lldb-blocked-use-signal-handler):
// lldb attach and core dumps are both unavailable in this environment, so install our own
// handler AFTER OCCT's OSD::SetSignal would run (this repro never calls it, so we win the
// race for free) to get a function-level backtrace via backtrace_symbols_fd. Not a fix,
// debug-only scaffolding for this repro binary.
static void crashHandler(int sig)
{
  void* frames[64];
  int n = backtrace(frames, 64);
  const char msg[] = "\n*** crashHandler caught signal ***\n";
  write(STDERR_FILENO, msg, sizeof(msg) - 1);
  backtrace_symbols_fd(frames, n, STDERR_FILENO);
  _Exit(128 + sig);
}

static void installCrashHandler()
{
  signal(SIGSEGV, crashHandler);
  signal(SIGBUS, crashHandler);
}

static void note(const char* fmt, ...)
{
  va_list args;
  va_start(args, fmt);
  vfprintf(stderr, fmt, args);
  va_end(args);
  fprintf(stderr, "\n");
}

struct SpinBarrier
{
  explicit SpinBarrier(int n)
      : myTotal(n),
        myCount(0),
        myGeneration(0)
  {
  }

  void Wait()
  {
    int gen = myGeneration.load(std::memory_order_acquire);
    if (myCount.fetch_add(1, std::memory_order_acq_rel) + 1 == myTotal)
    {
      myCount.store(0, std::memory_order_relaxed);
      myGeneration.fetch_add(1, std::memory_order_release);
    }
    else
    {
      while (myGeneration.load(std::memory_order_acquire) == gen)
      {
        // spin
      }
    }
  }

  int myTotal;
  std::atomic<int> myCount;
  std::atomic<int> myGeneration;
};

int main(int argc, char** argv)
{
  installCrashHandler();
  int threads = argc > 1 ? atoi(argv[1]) : 16;
  int rounds = argc > 2 ? atoi(argv[2]) : 5000;

  note("threads=%d rounds=%d (total=%ld lock-stepped NewDocument calls)", threads, rounds,
       (long)threads * rounds);

  SpinBarrier barrier(threads);
  std::atomic<long> gOps{0};
  std::vector<std::thread> pool;
  auto t0 = std::chrono::steady_clock::now();

  for (int i = 0; i < threads; ++i)
  {
    pool.emplace_back([&, i]() {
      for (int r = 0; r < rounds; ++r)
      {
        barrier.Wait(); // all threads cross this line together, every round
        Handle(TDocStd_Document) doc;
        Handle(XCAFApp_Application) app = XCAFApp_Application::GetApplication();
        app->NewDocument("MDTV-XCAF", doc);
        if (doc.IsNull())
        {
          note("[thread %d] NewDocument returned null at round %d", i, r);
          _Exit(3);
        }
        Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
        (void)shapeTool;
        gOps++;
      }
    });
  }
  for (auto& t : pool)
  {
    t.join();
  }

  auto t1 = std::chrono::steady_clock::now();
  double secs = std::chrono::duration<double>(t1 - t0).count();
  note("done: ops=%ld elapsed=%.2fs", gOps.load(), secs);
  return 0;
}
