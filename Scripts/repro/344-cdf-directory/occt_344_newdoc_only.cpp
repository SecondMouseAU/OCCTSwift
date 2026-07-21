// Tighter isolation of the OCCTSwift#344 lead: does NOT touch RWObj_CafReader/Writer or
// any file I/O at all. Pure stress on XCAFApp_Application::GetApplication()->NewDocument(),
// which internally does CDF_Application::Open() -> CDF_Directory::Add() -> an unsynchronized
// NCollection_List<Handle(CDM_Document)>::Append(). Every OCCTSwift document-producing bridge
// call (loadOBJ, loadSTEP, loadIGES, loadGLTF, Document() constructors, ...) goes through this
// same shared, process-global CDF_Directory, and the bridge never calls Application->Close()
// (grep of Sources/OCCTBridge confirms no ->Close() call site), so myDocuments only ever
// grows -- meaning every one of these calls, for the entire lifetime of a test process, races
// against every other one on the same list.
//
// Usage: occt_344_newdoc_only <threads> <iterations>

#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <thread>
#include <unistd.h>
#include <vector>

#include <TDocStd_Document.hxx>
#include <XCAFApp_Application.hxx>
#include <XCAFDoc_DocumentTool.hxx>

std::atomic<long> gOps{0};

static void note(const char* fmt, ...)
{
  va_list args;
  va_start(args, fmt);
  vfprintf(stderr, fmt, args);
  va_end(args);
  fprintf(stderr, "\n");
}

void runNewDocumentOnly(int id, int iterations)
{
  (void)id;
  for (int it = 0; it < iterations; ++it)
  {
    Handle(TDocStd_Document) doc;
    Handle(XCAFApp_Application) app = XCAFApp_Application::GetApplication();
    app->NewDocument("MDTV-XCAF", doc);
    if (doc.IsNull())
    {
      note("[thread %d] NewDocument returned null at iteration %d", id, it);
      _exit(3);
    }
    // Touch the document like the bridge does right after NewDocument, to keep the
    // repro representative (XCAFDoc_DocumentTool::ShapeTool attaches an attribute).
    Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
    (void)shapeTool;
    gOps++;
  }
}

int main(int argc, char** argv)
{
  int threads = argc > 1 ? atoi(argv[1]) : 16;
  int iterations = argc > 2 ? atoi(argv[2]) : 20000;

  note("threads=%d iterations=%d (total=%ld NewDocument calls)", threads, iterations,
       (long)threads * iterations);

  std::vector<std::thread> pool;
  auto t0 = std::chrono::steady_clock::now();

  for (int i = 0; i < threads; ++i)
  {
    pool.emplace_back(runNewDocumentOnly, i, iterations);
  }
  for (auto& t : pool)
  {
    t.join();
  }

  auto t1 = std::chrono::steady_clock::now();
  double secs = std::chrono::duration<double>(t1 - t0).count();
  note("done: ops=%ld elapsed=%.2fs (%.0f ops/s)", gOps.load(), secs, gOps.load() / secs);
  return 0;
}
