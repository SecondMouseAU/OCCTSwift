// Reproducer for OCCTSwift#374 / upstream OCCT#1398: Resource_Manager::Resource_Manager()'s
// unsynchronized global `Debug` write, and Storage_Schema::ICurrentData()'s unsynchronized
// global Handle, both surfaced once #371 gave every document its own private
// TDocStd_Application (so application/schema CONSTRUCTION itself becomes concurrent, something
// the pre-#371 shared XCAFApp_Application::GetApplication() singleton never allowed).
//
// This is the "unguarded" variant of Scripts/repro/371-getapplication-singleton-elimination/
// occt_371_private_app.cpp -- same private-app-per-(thread,round) structure, but with NO
// ocafStoreMutexSim() around DefineFormat/SaveAs/Open, so the two races the #371 investigation
// found (and deliberately worked around at the bridge level, per its README) are free to fire
// against the real TSan-instrumented kernel:
//
//   1. Resource_Manager::Resource_Manager(const char*, bool) writes a file-scope `static bool
//      Debug` on every construction with zero synchronization. Every fresh TDocStd_Application's
//      first DefineFormat() call lazily constructs its own Resource_Manager (Resources()'s own
//      lazy-init is per-instance-mutex-guarded since the #344 fix, but that only serializes
//      repeat calls on the SAME instance, not first-construction across DIFFERENT instances).
//   2. Storage_Schema::ICurrentData() is a function-local static Handle(Storage_Data) mutated
//      with no lock at all: Write() (SaveAs's path) sets it for the duration of one store, and
//      ANY Storage_Schema construction -- including the throwaway one PCDM_ReadWriter_1::
//      ReadDocumentVersion/ReadReferenceCounter/ReadUserInfo builds on every Open() (reached via
//      CDF_Application::Retrieve -> SetDocumentVersion -> CDM_MetaData::DocumentVersion ->
//      CDF_Application::DocumentVersion -> PCDM_RetrievalDriver::DocumentVersion, unconditional
//      on every fresh, non-append Open()) -- calls Clear() -> ICurrentData().Nullify() in its
//      constructor. A load on one thread can null out a save's in-flight scratch data on another.
//
// Usage: occt_374_stress <threads> <rounds> <scratchDir>
//
// Unpatched: races reported by TSan (Resource_Manager.cxx:109 write vs. read at :258/:296/:450;
// Storage_Schema.cxx:699/797/802 Nullify/assign vs. read at :617/618/636/653/660/682).
// After Scripts/patches/0016 (Resource_Manager::Debug -> std::atomic<bool>; Storage_Schema
// ICurrentData()/Clear()/Write()/BindType/TypeBinding/AddPersistent/PersistentToAdd/
// HasTypeBinding/ISetCurrentData guarded by a shared std::recursive_mutex): 0 races expected.

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
  int rounds  = argc > 2 ? atoi(argv[2]) : 50;
  std::string dir = argc > 3 ? argv[3] : "/tmp/occt374_scratch";

  note("occt_374_stress: threads=%d rounds=%d dir=%s (UNGUARDED -- no ocafStoreMutex equivalent)",
       threads, rounds, dir.c_str());
  system((std::string("mkdir -p ") + dir).c_str());

  SpinBarrier barrier(threads);
  std::atomic<int> saveFailures{0};
  std::atomic<int> loadFailures{0};
  std::atomic<int> verifyFailures{0};

  auto worker = [&](int tid) {
    for (int r = 0; r < rounds; ++r)
    {
      // Brand new, private app per (thread, round) -- matches OCCTDocument's ctor since #371.
      // No mutex around DefineFormat: Resource_Manager's first-construction race is live here.
      Handle(TDocStd_Application) saveApp = new TDocStd_Application();
      BinDrivers::DefineFormat(saveApp);
      BinXCAFDrivers::DefineFormat(saveApp);

      Handle(TDocStd_Document) doc;
      saveApp->NewDocument("MDTV-XCAF", doc);
      populate(doc, tid * 100000 + r);
      doc->ChangeStorageFormat(TCollection_ExtendedString("BinXCAF", true));

      std::string path = dir + "/occt374_" + std::to_string(tid) + "_" + std::to_string(r) + ".xbf";
      TCollection_ExtendedString ePath(path.c_str(), true);

      barrier.arriveAndWait();

      // No mutex around SaveAs: Storage_Schema::ICurrentData()'s Write()-side race is live here.
      PCDM_StoreStatus storeStatus = saveApp->SaveAs(doc, ePath);
      if (storeStatus != PCDM_SS_OK)
      {
        saveFailures.fetch_add(1, std::memory_order_relaxed);
      }
      saveApp->Close(doc);

      // Separate, also-private app for the load side, exactly like OCCTDocumentLoadOCAF.
      Handle(TDocStd_Application) loadApp = new TDocStd_Application();
      BinDrivers::DefineFormat(loadApp);
      BinXCAFDrivers::DefineFormat(loadApp);

      Handle(TDocStd_Document) reloaded;
      // No mutex around Open: this is the throwaway `new Storage_Schema` in
      // PCDM_ReadWriter_1::ReadDocumentVersion (reached via SetDocumentVersion, unconditional on
      // a fresh Open()) that can Clear()/Nullify() ANOTHER thread's in-flight Write() data.
      PCDM_ReaderStatus readStatus = loadApp->Open(ePath, reloaded);
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

  note("occt_374_stress: done, saveFailures=%d loadFailures=%d verifyFailures=%d",
       saveFailures.load(), loadFailures.load(), verifyFailures.load());
  return (saveFailures.load() + loadFailures.load() + verifyFailures.load()) > 0 ? 1 : 0;
}
