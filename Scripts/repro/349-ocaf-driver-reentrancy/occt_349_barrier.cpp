// Barrier-synchronized reproducer for OCCTSwift#349: BinLDrivers_DocumentStorageDriver::Write
// is not reentrant, but CDF_Application::WriterFromFormat caches and returns ONE shared driver
// instance per format (myWriters), so concurrent SaveAs() calls for the same format on
// different documents/threads run Write() on the SAME driver object, stomping its instance-level
// scratch state (myRelocTable, myPAtt, myTypesMap, myEmptyLabels, myMapUnsupported,
// mySizesToWrite, myFileName, myDrivers lazy-init) with no synchronization.
//
// Every thread builds its own tiny TDocStd_Document (own file, own label tree, deliberately
// NOT a file-path collision, to isolate the driver-reentrancy defect from unrelated I/O races)
// and spin-waits at a barrier before each round's SaveAs(), maximizing genuine simultaneous
// contention on the shared BinLDrivers_DocumentStorageDriver instance instead of relying on OS
// scheduling luck (same technique as Scripts/repro/344-cdf-directory/occt_344_barrier.cpp).
//
// This bypasses OCCTSwift's own ocafStoreMutex() bridge mitigation on purpose, that mutex isn't
// present in the kernel itself, and this repro targets the kernel defect.
//
// Usage: occt_349_barrier <threads> <rounds> <scratchDir>

#include <atomic>
#include <chrono>
#include <csignal>
#include <cstdarg>
#include <cstdio>
#include <cstdlib>
#include <execinfo.h>
#include <string>
#include <thread>
#include <unistd.h>
#include <vector>

#include <BinDrivers.hxx>
#include <TDataStd_Name.hxx>
#include <TDataStd_Integer.hxx>
#include <TDF_Label.hxx>
#include <TDocStd_Application.hxx>
#include <TDocStd_Document.hxx>

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
  explicit SpinBarrier(int n) : myTotal(n), myCount(0), myGeneration(0) {}

  void arriveAndWait()
  {
    int gen = myGeneration.load(std::memory_order_relaxed);
    if (myCount.fetch_add(1, std::memory_order_acq_rel) + 1 == myTotal)
    {
      myCount.store(0, std::memory_order_relaxed);
      myGeneration.fetch_add(1, std::memory_order_release);
    }
    else
    {
      while (myGeneration.load(std::memory_order_acquire) == gen)
      {
        std::this_thread::yield();
      }
    }
  }

  int myTotal;
  std::atomic<int> myCount;
  std::atomic<int> myGeneration;
};

// Builds a small OCAF document tree so Write() has real attribute/label work to race on.
static void populate(const Handle(TDocStd_Document) & doc, int seed)
{
  TDF_Label root = doc->Main();
  for (int i = 0; i < 25; ++i)
  {
    TDF_Label child = root.FindChild(i + 1, true);
    TDataStd_Name::Set(child, TCollection_ExtendedString("node"));
    TDataStd_Integer::Set(child, seed * 1000 + i);
  }
}

int main(int argc, char** argv)
{
  installCrashHandler();

  int threads = argc > 1 ? atoi(argv[1]) : 8;
  int rounds  = argc > 2 ? atoi(argv[2]) : 200;
  std::string dir = argc > 3 ? argv[3] : "/tmp/occt349_scratch";

  note("occt_349_barrier: threads=%d rounds=%d dir=%s", threads, rounds, dir.c_str());
  system((std::string("mkdir -p ") + dir).c_str());

  Handle(TDocStd_Application) app = new TDocStd_Application();
  BinDrivers::DefineFormat(app);

  SpinBarrier barrier(threads);
  std::atomic<int> failures{0};

  auto worker = [&](int tid) {
    for (int r = 0; r < rounds; ++r)
    {
      Handle(TDocStd_Document) doc;
      app->NewDocument("BinOcaf", doc);
      populate(doc, tid * 100000 + r);

      std::string path = dir + "/occt349_" + std::to_string(tid) + "_" + std::to_string(r) + ".cbf";
      TCollection_ExtendedString ePath(path.c_str(), true);

      barrier.arriveAndWait();
      PCDM_StoreStatus status = app->SaveAs(doc, ePath);
      if (status != PCDM_SS_OK)
      {
        failures.fetch_add(1, std::memory_order_relaxed);
      }

      app->Close(doc);
    }
  };

  std::vector<std::thread> pool;
  for (int t = 0; t < threads; ++t)
  {
    pool.emplace_back(worker, t);
  }
  for (auto& th : pool)
  {
    th.join();
  }

  note("occt_349_barrier: done, failures=%d", failures.load());
  return 0;
}
