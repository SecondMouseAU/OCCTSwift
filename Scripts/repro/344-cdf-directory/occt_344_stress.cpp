// Multi-threaded stress harness for OCCTSwift#344: characterizing the SIGSEGV seen right
// after two concurrent OBJ mesh imports in `swift test` parallel runs, surviving the #341
// fix (XCAFDoc_ShapeTool::theAutoNaming, now XCAFDoc_ShapeTool::AutoNamingScope).
//
// Unlike Scripts/repro/341-meshcaf/occt_341_stress.cpp (which constructs a fresh
// `new TDocStd_Document("BinXCAF")` directly, bypassing XCAFApp_Application entirely), this
// harness mirrors the REAL bridge call path (OCCTDocumentLoadOBJ, OCCTBridge_IO.mm):
//
//   XCAFApp_Application::GetApplication()->NewDocument("MDTV-XCAF", doc);
//   RWObj_CafReader reader; reader.SetDocument(doc); reader.Perform(path, range);
//
// `GetApplication()` returns a process-wide singleton; TDocStd_Application::NewDocument()
// calls CDF_Application::Open(), which does `myDirectory->Add(aDocument)` against that
// ONE shared CDF_Directory's `NCollection_List<Handle(CDM_Document)>` -- with zero
// synchronization anywhere in CDF_Directory::Add/Remove/Contains. Every concurrent
// document creation across the whole process races on this same list.
//
// Usage: occt_344_stress <threads> <iterations> <tmpDir>

#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepMesh_IncrementalMesh.hxx>

#include <RWObj_CafReader.hxx>
#include <RWObj_CafWriter.hxx>
#include <TDocStd_Document.hxx>
#include <XCAFApp_Application.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <Message_ProgressRange.hxx>

std::atomic<long> gOps{0};
std::atomic<long> gErrors{0};

static void note(const char* fmt, ...)
{
  va_list args;
  va_start(args, fmt);
  vfprintf(stderr, fmt, args);
  va_end(args);
  fprintf(stderr, "\n");
}

// Mirrors OCCTDocumentLoadOBJ (OCCTBridge_IO.mm) exactly: goes through the shared
// XCAFApp_Application singleton, not a hand-built TDocStd_Document.
void runObjImportViaApplication(int id, int iterations, const std::string& tmpDir)
{
  for (int it = 0; it < iterations; ++it)
  {
    TopoDS_Shape box = BRepPrimAPI_MakeBox(10, 20, 30).Shape();
    BRepMesh_IncrementalMesh mesher(box, 0.5);
    mesher.Perform();

    std::ostringstream pathStream;
    pathStream << tmpDir << "/occt344_obj_" << id << "_" << it << ".obj";
    std::string path = pathStream.str();

    // Write via a throwaway document (write side isn't the focus, keep it simple).
    {
      Handle(TDocStd_Document) writeDoc;
      Handle(XCAFApp_Application) app = XCAFApp_Application::GetApplication();
      app->NewDocument("MDTV-XCAF", writeDoc);
      Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(writeDoc->Main());
      shapeTool->AddShape(box);

      NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> fileInfo;
      RWObj_CafWriter writer(path.c_str());
      Message_ProgressRange range;
      bool wroteOk = writer.Perform(writeDoc, fileInfo, range);
      if (!wroteOk)
      {
        gErrors++;
        note("[thread %d] OBJ write failed: %s", id, path.c_str());
        continue;
      }
    }

    // Read side: EXACTLY the OCCTDocumentLoadOBJ bridge sequence.
    {
      Handle(TDocStd_Document) readDoc;
      Handle(XCAFApp_Application) app = XCAFApp_Application::GetApplication();
      app->NewDocument("MDTV-XCAF", readDoc);
      if (readDoc.IsNull())
      {
        gErrors++;
        continue;
      }

      RWObj_CafReader reader;
      reader.SetDocument(readDoc);
      Message_ProgressRange range;
      TCollection_AsciiString filePath(path.c_str());
      bool readOk = reader.Perform(filePath, range);
      if (!readOk)
      {
        gErrors++;
        note("[thread %d] OBJ read failed: %s", id, path.c_str());
        continue;
      }
      Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(readDoc->Main());
      (void)shapeTool;
    }

    std::remove(path.c_str());
    gOps++;
  }
}

int main(int argc, char** argv)
{
  int threads = argc > 1 ? atoi(argv[1]) : 8;
  int iterations = argc > 2 ? atoi(argv[2]) : 50;
  std::string tmpDir = argc > 3 ? argv[3] : "/tmp";

  note("threads=%d iterations=%d tmpDir=%s", threads, iterations, tmpDir.c_str());

  std::vector<std::thread> pool;
  auto t0 = std::chrono::steady_clock::now();

  for (int i = 0; i < threads; ++i)
  {
    pool.emplace_back(runObjImportViaApplication, i, iterations, tmpDir);
  }
  for (auto& t : pool)
  {
    t.join();
  }

  auto t1 = std::chrono::steady_clock::now();
  double secs = std::chrono::duration<double>(t1 - t0).count();
  note("done: ops=%ld errors=%ld elapsed=%.2fs", gOps.load(), gErrors.load(), secs);
  return gErrors.load() > 0 ? 1 : 0;
}
