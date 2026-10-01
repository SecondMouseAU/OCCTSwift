// #2897: the wasm `indirect call type mismatch` inside OCCTTObjApplicationCreateDocument.
//
// The bridge is not in this probe, and neither is Swift: it links the pinned OCCT kernel directly
// and replays the exact call sequence the bridge makes, so what it measures is the kernel's own
// behaviour under that sequence rather than anything OCCTSwift compiles.
//
// PHASE 1 is the control. Fetch the singleton, make a document, close it, release. This is what
// the trapping test does and it succeeds, which is why the trap is NOT a vtable or ABI
// disagreement between the headers and the archive: the virtual dispatch resolves correctly.
//
// PHASE 2 is the defect. `OCCTTObjApplicationRelease` is a bare `DecrementRefCounter()`, so a
// release with no matching `GetInstance()` leaves the process-wide singleton's reference count one
// BELOW what its own function-local static handle represents. Nothing is freed at that moment.
//
// PHASE 3 is where it is freed, and by an innocent caller: the next `occ::handle` to fall out of
// scope decrements to zero and calls `Delete()`, which is `delete this`. The static handle inside
// `TObj_Application::GetInstance()` still points at the freed object.
//
// PHASE 4 is #2897's trace. Every later caller gets that dangling pointer, reads a vptr out of
// reclaimed memory and dispatches through it. On wasm the function index that comes back has a
// type the call site did not declare and the engine traps. On Apple it is an indirect branch
// through whatever the reclaimed block now holds. Nothing here is a wasm defect; wasm is the only
// platform that says so.
//
// Build and run with ./run.sh (wasm) or ./run.sh --native (macOS, and --asan for the verdict).

#include <TObj_Application.hxx>
#include <TDocStd_Document.hxx>
#include <TCollection_ExtendedString.hxx>

#include <cstdio>

#if defined(__wasi__)
// wasi-libc declares the dynamic-loader entry points and defines none of them, and
// `OSD_SharedLibrary.cxx` is pulled in by `CDF_Application`'s plugin lookup, which is on
// `TObj_Application`'s own inheritance path. The Swift build never meets this because its link
// supplies stubs of its own; a bare clang++ link does, so the stubs are here. Nothing in this
// probe loads a plugin, so one that always fails is the whole requirement.
extern "C"
{
  void* dlopen(const char*, int) { return nullptr; }

  void* dlsym(void*, const char*) { return nullptr; }

  char* dlerror() { return const_cast<char*>("dlopen is not available on wasip1"); }

  int dlclose(void*) { return 0; }
}
#endif

namespace
{

//! `OCCTTObjApplicationGetInstance`, byte for byte.
void* bridgeGetInstance()
{
  occ::handle<TObj_Application> app = TObj_Application::GetInstance();
  if (app.IsNull())
  {
    return nullptr;
  }
  app->IncrementRefCounter();
  return app.get();
}

//! `OCCTTObjApplicationRelease`, byte for byte.
void bridgeRelease(void* app)
{
  if (app == nullptr)
  {
    return;
  }
  static_cast<TObj_Application*>(app)->DecrementRefCounter();
}

//! The singleton's own count, with this reader's temporary handle subtracted so the number means
//! what a reader expects. One is the floor: the static handle in GetInstance() and nothing else.
int refCount()
{
  occ::handle<TObj_Application> app = TObj_Application::GetInstance();
  return app->GetRefCount() - 1;
}

void report(const char* step)
{
  std::printf("  %-28s refcount = %d\n", step, refCount());
  std::fflush(stdout);
}

void slot26(const char* label, void* app)
{
  void** vptr = *reinterpret_cast<void***>(app);
  std::printf("  %-28s vptr = %p, slot 26 (CreateNewDocument) = %p\n", label, (void*)vptr, vptr[26]);
  std::fflush(stdout);
}

bool createAndCloseDocument(void* app)
{
  TObj_Application*             a = static_cast<TObj_Application*>(app);
  occ::handle<TDocStd_Document> doc;
  TCollection_ExtendedString    format("BinOcaf");
  if (!a->CreateNewDocument(doc, format) || doc.IsNull())
  {
    return false;
  }
  // Without this the document stays in the application's own CDF_Directory and keeps a reference
  // to the application, which hides the whole defect: the count cannot reach zero while a document
  // is open. Closing it is what an application does, and it is what makes the floor the floor.
  a->Close(doc);
  return true;
}

} // namespace

int main()
{
  std::printf("PHASE 1: the control, a healthy singleton\n");
  report("at rest");
  {
    void* app = bridgeGetInstance();
    report("after GetInstance");
    slot26("", app);
    std::printf("  %-28s %s\n",
                "CreateNewDocument",
                createAndCloseDocument(app) ? "a document" : "nothing");
    bridgeRelease(app);
    report("after Release");
  }

  std::printf("PHASE 2: one unmatched release, which is what the test suite performs\n");
  {
    void* app = bridgeGetInstance();
    report("after GetInstance");
    bridgeRelease(app);
    report("after Release");
    bridgeRelease(app); // Issue1588TObjApplicationReleaseTests performs exactly this.
    report("after the UNMATCHED one");
  }

  std::printf("PHASE 3: the next ordinary handle to fall out of scope frees it\n");
  {
    occ::handle<TObj_Application> scoped = TObj_Application::GetInstance();
    std::printf("  %-28s refcount = %d\n", "a scoped handle", scoped->GetRefCount());
    std::fflush(stdout);
  }
  std::printf("  %-28s Delete() ran, so GetInstance()'s static handle now dangles\n", "dropped");
  std::fflush(stdout);

  std::printf("PHASE 4: the call #2897's trace names, through the dangling singleton\n");
  {
    void* app = bridgeGetInstance();
    std::printf("  %-28s app = %p\n", "after GetInstance", app);
    std::fflush(stdout);
    slot26("read from freed memory", app);
    std::printf("  %-28s %s\n",
                "CreateNewDocument",
                createAndCloseDocument(app) ? "a document" : "nothing");
  }

  std::printf("DONE (no trap)\n");
  return 0;
}
