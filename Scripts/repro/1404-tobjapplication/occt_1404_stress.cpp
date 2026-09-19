// OCCTSwift#1404: TObj_Application's own two fields are unsynchronized.
//
// TObj_Application::GetInstance() (TObj_Application.cxx) is a process-wide singleton:
//
//   occ::handle<TObj_Application> TObj_Application::GetInstance()
//   {
//     static occ::handle<TObj_Application> THE_TOBJ_APP(new TObj_Application);
//     return THE_TOBJ_APP;
//   }
//
// The lazy-init is a C++11 function-local static, so that part is thread-safe and is NOT what
// this harness is about. The defect is one layer up, in the singleton's own members:
//
//   A. myIsVerbose, behind SetVerbose()/IsVerbose(), is a plain unguarded bool.
//   B. myIsError. CreateNewDocument() writes myIsError = false, calls NewDocument(), then
//      returns !myIsError. Two concurrent calls interleave write-call-read on one shared
//      field, so one thread can clear another's in-flight error signal and turn a failed
//      creation into a reported success.
//
// Distinct from #341/#344/#349/#353/#371/#374. Those fixed XCAFApp_Application,
// CDF_Application, CDM_Application, Resource_Manager and Storage_Schema, and their patches
// (0012/0014/0015/0016) all ship in the pinned kernel, covering the machinery NewDocument()
// descends into. Nothing touches TObj_Application itself.
//
// THIS HARNESS IS EVIDENCE, NOT A GATE SCENARIO. It calls the kernel singleton directly and
// is therefore EXPECTED to race under TSan on a clean tree: no bridge lock is in the picture.
// It is deliberately not listed in Scripts/tsan-stress.sh's SCENARIOS, for the same reason
// 341's shared_adaptor_cache and obj_roundtrip_shared modes are excluded there: a mode that is
// expected to race gates nothing. The FIX is bridge-side (tobjApplicationMutex), and the thing
// that verifies it is `Scripts/tsan-stress.sh swift` over
// Tests/OCCTThreadTests/Issue1404TObjApplicationThreadSafetyTests.swift, which reaches the
// singleton the way a consumer actually does.
//
// Usage: occt_1404_stress <mode> <threads> <iterations>
//   verbose    concurrent SetVerbose/IsVerbose only (isolates myIsVerbose)
//   createdoc  concurrent CreateNewDocument only (isolates myIsError)
//   mixed      both, interleaved

#include <atomic>
#include <chrono>
#include <cstdarg>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <thread>
#include <unistd.h>
#include <vector>

#include <TCollection_ExtendedString.hxx>
#include <TDocStd_Document.hxx>
#include <TObj_Application.hxx>

std::atomic<long> gOps{0};
std::atomic<long> gCreateFailures{0};

static void note(const char* fmt, ...)
{
  va_list args;
  va_start(args, fmt);
  vfprintf(stderr, fmt, args);
  va_end(args);
  fprintf(stderr, "\n");
}

// A: hammer myIsVerbose from every thread. The value read back is not checked; with N writers
// any of them is a legitimate answer. What TSan reports is the unsynchronized access itself.
static void runVerbose(int id, int iterations)
{
  for (int it = 0; it < iterations; ++it)
  {
    Handle(TObj_Application) app = TObj_Application::GetInstance();
    app->SetVerbose((id + it) % 2 == 0);
    (void)app->IsVerbose();
    gOps++;
  }
}

// B: hammer myIsError through CreateNewDocument. Every call here is a valid BinOcaf creation
// that should succeed, so a false return is either a real failure or one thread's myIsError
// state being read by another thread's call.
static void runCreateDoc(int id, int iterations)
{
  (void)id;
  for (int it = 0; it < iterations; ++it)
  {
    Handle(TObj_Application)  app = TObj_Application::GetInstance();
    Handle(TDocStd_Document)  doc;
    TCollection_ExtendedString format("BinOcaf");
    if (!app->CreateNewDocument(doc, format))
    {
      gCreateFailures++;
    }
    gOps++;
  }
}

static void runMixed(int id, int iterations)
{
  for (int it = 0; it < iterations; ++it)
  {
    if ((id + it) % 2 == 0)
    {
      runCreateDoc(id, 1);
    }
    else
    {
      runVerbose(id, 1);
    }
  }
}

int main(int argc, char** argv)
{
  std::string mode       = argc > 1 ? argv[1] : "mixed";
  int         threads    = argc > 2 ? atoi(argv[2]) : 8;
  int         iterations = argc > 3 ? atoi(argv[3]) : 200;

  void (*fn)(int, int) = nullptr;
  if (mode == "verbose")
    fn = runVerbose;
  else if (mode == "createdoc")
    fn = runCreateDoc;
  else if (mode == "mixed")
    fn = runMixed;
  else
  {
    note("unknown mode '%s' (want verbose|createdoc|mixed)", mode.c_str());
    return 2;
  }

  note("mode=%s threads=%d iterations=%d", mode.c_str(), threads, iterations);

  std::vector<std::thread> pool;
  auto                     t0 = std::chrono::steady_clock::now();
  for (int i = 0; i < threads; ++i)
    pool.emplace_back(fn, i, iterations);
  for (auto& t : pool)
    t.join();
  auto t1 = std::chrono::steady_clock::now();

  double secs = std::chrono::duration<double>(t1 - t0).count();
  note("done: ops=%ld create_failures=%ld elapsed=%.2fs", gOps.load(), gCreateFailures.load(),
       secs);
  return 0;
}
