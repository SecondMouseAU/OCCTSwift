// Confirmation harness for OCCTSwift#371: with a PRIVATE TDocStd_Application per document
// (never XCAFApp_Application::GetApplication(), never shared between threads or documents),
// none of the #341/#344/#349/#353 shared-state races are even reachable -- every racy field
// those issues fixed (CDF_Directory::myDocuments, CDF_Application::myReaders/myWriters,
// CDM_Application::myMetaDataLookUpTable) lives on the TDocStd_Application/CDF_Application
// instance itself, and this harness never lets two threads touch the same instance.
//
// Deliberately the INVERSE of occt_349_barrier.cpp/occt_344_barrier.cpp/occt_353_barrier.cpp:
// those construct ONE shared app across all threads (the officially-supported singleton usage
// those issues target). This one constructs a fresh app PER (thread, round) -- the pattern
// Sources/OCCTBridge/src/OCCTBridge_Internal.h's OCCTDocument ctor now uses -- and exercises a
// full create -> populate -> SaveAs -> Close -> Open(separate private app) -> verify -> Close
// cycle per round, barrier-synchronized for maximum genuine concurrency.
//
// ocafStoreMutexSim() below matches OCCTSwift's real bridge-side ocafStoreMutex()
// (Sources/OCCTBridge/src/OCCTBridge_Document.mm), which is REQUIRED here even though no state
// is shared between application instances: removing it (tested during the #371 investigation)
// reproduces two previously-uncharacterized OCCT races -- Resource_Manager::Resource_Manager()'s
// unsynchronized global `Debug` write, and Storage_Schema::ICurrentData()'s unsynchronized global
// handle -- filed upstream as OCCT#1398. Neither is reachable through CDF_Application/
// TDocStd_Application's own per-instance state (already private here); both live one layer
// lower, in genuinely process-global OCCT foundation-layer singletons this refactor doesn't
// touch. See README.md for the full writeup, including the unguarded (racing) result.
//
// Usage: occt_371_private_app <threads> <rounds> <scratchDir>

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
#include <BinXCAFDrivers.hxx>
#include <TDataStd_Name.hxx>
#include <TDataStd_Integer.hxx>
#include <TDF_Label.hxx>
#include <TDF_LabelSequence.hxx>
#include <TDocStd_Application.hxx>
#include <TDocStd_Document.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <mutex>

// Mirrors OCCTSwift's real bridge-side ocafStoreMutex() -- see header comment above.
static std::mutex& ocafStoreMutexSim() { static std::mutex m; return m; }

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

static void populate(const Handle(TDocStd_Document) & doc, int seed)
{
  Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
  TopoDS_Shape box = BRepPrimAPI_MakeBox(1 + (seed % 10), 2, 3).Shape();
  TDF_Label boxLabel = shapeTool->AddShape(box, false);
  for (int i = 0; i < 10; ++i)
  {
    TDF_Label child = boxLabel.FindChild(i + 1, true);
    TDataStd_Name::Set(child, TCollection_ExtendedString("node"));
    TDataStd_Integer::Set(child, seed * 1000 + i);
  }
}

int main(int argc, char** argv)
{
  installCrashHandler();

  int threads = argc > 1 ? atoi(argv[1]) : 8;
  int rounds  = argc > 2 ? atoi(argv[2]) : 200;
  std::string dir = argc > 3 ? argv[3] : "/tmp/occt371_scratch";

  note("occt_371_private_app: threads=%d rounds=%d dir=%s", threads, rounds, dir.c_str());
  system((std::string("mkdir -p ") + dir).c_str());

  SpinBarrier barrier(threads);
  std::atomic<int> saveFailures{0};
  std::atomic<int> loadFailures{0};
  std::atomic<int> verifyFailures{0};

  auto worker = [&](int tid) {
    for (int r = 0; r < rounds; ++r)
    {
      // #371 pattern: brand new, private app for THIS create+save -- never shared with any
      // other thread, never reused across rounds. Matches OCCTDocument's ctor exactly.
      Handle(TDocStd_Application) saveApp = new TDocStd_Application();
      {
        std::lock_guard<std::mutex> lk(ocafStoreMutexSim());
        BinDrivers::DefineFormat(saveApp);
        BinXCAFDrivers::DefineFormat(saveApp);
      }

      Handle(TDocStd_Document) doc;
      saveApp->NewDocument("MDTV-XCAF", doc);
      populate(doc, tid * 100000 + r);
      doc->ChangeStorageFormat(TCollection_ExtendedString("BinXCAF", true));

      std::string path = dir + "/occt371_" + std::to_string(tid) + "_" + std::to_string(r) + ".xbf";
      TCollection_ExtendedString ePath(path.c_str(), true);

      barrier.arriveAndWait();

      PCDM_StoreStatus storeStatus;
      {
        std::lock_guard<std::mutex> lk(ocafStoreMutexSim());
        storeStatus = saveApp->SaveAs(doc, ePath);
      }
      if (storeStatus != PCDM_SS_OK)
      {
        saveFailures.fetch_add(1, std::memory_order_relaxed);
      }
      saveApp->Close(doc);

      // #371 pattern: a SEPARATE, also-private app for the load side -- exactly like
      // OCCTDocumentLoadOCAF, which never reuses the app that wrote the file.
      Handle(TDocStd_Application) loadApp = new TDocStd_Application();
      {
        std::lock_guard<std::mutex> lk(ocafStoreMutexSim());
        BinDrivers::DefineFormat(loadApp);
        BinXCAFDrivers::DefineFormat(loadApp);
      }

      Handle(TDocStd_Document) reloaded;
      PCDM_ReaderStatus readStatus;
      {
        std::lock_guard<std::mutex> lk(ocafStoreMutexSim());
        readStatus = loadApp->Open(ePath, reloaded);
      }
      if (readStatus != PCDM_RS_OK || reloaded.IsNull())
      {
        loadFailures.fetch_add(1, std::memory_order_relaxed);
      }
      else
      {
        Handle(XCAFDoc_ShapeTool) reloadedShapeTool = XCAFDoc_DocumentTool::ShapeTool(reloaded->Main());
        TDF_LabelSequence freeShapes;
        reloadedShapeTool->GetFreeShapes(freeShapes);
        if (freeShapes.Length() != 1)
        {
          verifyFailures.fetch_add(1, std::memory_order_relaxed);
        }
        loadApp->Close(reloaded);
      }
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

  note("occt_371_private_app: done, saveFailures=%d loadFailures=%d verifyFailures=%d",
       saveFailures.load(), loadFailures.load(), verifyFailures.load());
  return (saveFailures.load() + loadFailures.load() + verifyFailures.load()) > 0 ? 1 : 0;
}
