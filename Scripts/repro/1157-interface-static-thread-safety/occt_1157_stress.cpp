// Multi-threaded stress harness for OCCTSwift#1157: "Interface_Static process globals in
// STEP/IGES: Bridge serializes via igesMutex() but kernel fix needed."
//
// Pure C++, no Swift/bridge/Objective-C++ layer -- calls the exact same OCCT sequences
// Sources/OCCTBridge/src/OCCTBridge_IO_StepFormat.mm / OCCTBridge_IO_IgesFormat.mm make
// (STEPControl_Reader/Writer, IGESControl_Reader/Writer, the same Interface_Static::Set*Val
// calls, in the same order) with NO igesMutex()-equivalent lock. This is "the bridge with
// igesMutex() removed" without needing to override-link the actual .mm files: the bridge's
// own critical sections are exactly these OCCT calls plus the Set*Val calls immediately
// before them, and igesMutex() is a single lock_guard wrapping that whole sequence, so
// calling the same sequence with no lock at all reproduces precisely the state the bridge
// would be in if the mutex were deleted.
//
// Two independent things are measured, deliberately kept apart:
//
//  1. MEMORY SAFETY (TSan-observable data races / crashes) in Interface_Static's backing
//     store (MoniTool_TypedValue::Stats()'s astats/thelibtv NCollection_DataMaps, and each
//     named Interface_Static object's own mutable fields) under genuinely independent
//     concurrent STEP/IGES read/write operations. Run under `Scripts/tsan-stress.sh run`
//     (or standalone against Libraries/occt-install-tsan) to see race reports.
//
//  2. LOGICAL CORRECTNESS ("cross-talk"): because Interface_Static is process-global shared
//     mutable state used as an IMPLICIT parameter-passing channel between a caller's
//     SetCVal/SetIVal/SetRVal and reads deep inside a *different* function call several
//     frames down the same logical operation, two concurrently-running operations that set
//     DIFFERENT values for the SAME named parameter can observe each other's value instead
//     of their own -- a wrong-answer bug, not a crash, and NOT fixed by only making the
//     container itself memory-safe (see cross_talk_schema_locked below, which wraps every
//     individual Set/Get in its own mutex -- exactly what a "lock the accessor" kernel fix
//     would provide -- and still cross-talks just as often).
//
// Usage: occt_1157_stress <scenario|all> <threads> <iterations> [scratch_dir]
//   scenarios: step_write_independent | step_read_independent
//              | iges_write_independent | iges_read_independent
//              | mixed_step_iges_independent
//              | cross_talk_schema_unlocked | cross_talk_schema_locked

#include <atomic>
#include <cstdarg>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <IFSelect_ReturnStatus.hxx>
#include <IGESControl_Reader.hxx>
#include <IGESControl_Writer.hxx>
#include <Interface_Static.hxx>
#include <STEPControl_Reader.hxx>
#include <STEPControl_StepModelType.hxx>
#include <STEPControl_Writer.hxx>
#include <TopoDS_Shape.hxx>

std::atomic<long> gOps{0};
std::atomic<long> gErrors{0};
std::atomic<long> gCrossTalk{0};

static void note(const char* fmt, ...)
{
  va_list args;
  va_start(args, fmt);
  vfprintf(stderr, fmt, args);
  va_end(args);
  fprintf(stderr, "\n");
}

static std::string gScratch = ".";

// ---------------------------------------------------------------------------
// 1. STEPControl_Writer, independent shapes to independent files. Mirrors
// OCCTExportSTEP/OCCTExportSTEPWithName exactly: SetCVal("write.step.schema", ...) then
// Transfer(shape, STEPControl_AsIs) then Write(path). No lock.
// ---------------------------------------------------------------------------
void runStepWriteIndependent(int id, int iterations)
{
  for (int it = 0; it < iterations; ++it)
  {
    TopoDS_Shape shape = BRepPrimAPI_MakeBox(10 + (it % 5), 20, 30).Shape();
    STEPControl_Writer writer;
    Interface_Static::SetCVal("write.step.schema", "AP214");

    IFSelect_ReturnStatus status = writer.Transfer(shape, STEPControl_AsIs);
    if (status != IFSelect_RetDone)
    {
      gErrors++;
      note("[thread %d] step write: Transfer failed", id);
      continue;
    }

    std::string path = gScratch + "/step_write_" + std::to_string(id) + "_" + std::to_string(it) + ".step";
    status = writer.Write(path.c_str());
    if (status != IFSelect_RetDone)
    {
      gErrors++;
      note("[thread %d] step write: Write failed", id);
    }
    gOps++;
  }
}

// ---------------------------------------------------------------------------
// 2. STEPControl_Reader, N threads reading the SAME pre-written file independently.
// Mirrors OCCTImportSTEPRobustProgress: SetIVal/SetRVal calls, ReadFile, TransferRoots,
// OneShape. No lock. Setup (writing the shared input file) happens single-threaded
// before any thread starts.
// ---------------------------------------------------------------------------
static std::string gStepReadFixture;

void runStepReadIndependent(int id, int iterations)
{
  for (int it = 0; it < iterations; ++it)
  {
    STEPControl_Reader reader;
    Interface_Static::SetIVal("read.precision.mode", 0);
    Interface_Static::SetRVal("read.maxprecision.val", 0.1);
    Interface_Static::SetIVal("read.surfacecurve.mode", 3);
    Interface_Static::SetIVal("read.step.product.mode", 1);

    IFSelect_ReturnStatus status = reader.ReadFile(gStepReadFixture.c_str());
    if (status != IFSelect_RetDone)
    {
      gErrors++;
      note("[thread %d] step read: ReadFile failed", id);
      continue;
    }
    reader.TransferRoots();
    TopoDS_Shape shape = reader.OneShape();
    if (shape.IsNull())
    {
      gErrors++;
      note("[thread %d] step read: OneShape null", id);
    }
    gOps++;
  }
}

// ---------------------------------------------------------------------------
// 3. IGESControl_Writer, independent shapes to independent files. Mirrors
// OCCTExportIGESProgress: BRepCheck_Analyzer validity check, IGESControl_Writer("MM", 0),
// AddShape, Write(path). No lock.
// ---------------------------------------------------------------------------
void runIgesWriteIndependent(int id, int iterations)
{
  for (int it = 0; it < iterations; ++it)
  {
    TopoDS_Shape shape = BRepPrimAPI_MakeSphere(5 + (it % 5)).Shape();
    BRepCheck_Analyzer analyzer(shape);
    if (!analyzer.IsValid())
    {
      gErrors++;
      continue;
    }

    IGESControl_Writer writer("MM", 0);
    bool ok = writer.AddShape(shape);
    if (!ok)
    {
      gErrors++;
      note("[thread %d] iges write: AddShape failed", id);
      continue;
    }
    std::string path = gScratch + "/iges_write_" + std::to_string(id) + "_" + std::to_string(it) + ".iges";
    if (!writer.Write(path.c_str()))
    {
      gErrors++;
      note("[thread %d] iges write: Write failed", id);
    }
    gOps++;
  }
}

// ---------------------------------------------------------------------------
// 4. IGESControl_Reader, N threads reading the SAME pre-written file independently.
// Mirrors OCCTImportIGESRobustProgress's SetIVal/SetRVal + ReadFile + TransferRoots.
// ---------------------------------------------------------------------------
static std::string gIgesReadFixture;

void runIgesReadIndependent(int id, int iterations)
{
  for (int it = 0; it < iterations; ++it)
  {
    IGESControl_Reader reader;
    Interface_Static::SetIVal("read.precision.mode", 0);
    Interface_Static::SetRVal("read.precision.val", 0.0001);

    IFSelect_ReturnStatus status = reader.ReadFile(gIgesReadFixture.c_str());
    if (status != IFSelect_RetDone)
    {
      gErrors++;
      note("[thread %d] iges read: ReadFile failed", id);
      continue;
    }
    if (reader.TransferRoots() == 0)
    {
      gErrors++;
      note("[thread %d] iges read: TransferRoots got 0", id);
      continue;
    }
    TopoDS_Shape shape = reader.OneShape();
    if (shape.IsNull())
    {
      gErrors++;
      note("[thread %d] iges read: OneShape null", id);
    }
    gOps++;
  }
}

// ---------------------------------------------------------------------------
// 5. Mixed: exactly the issue's own reproduction snippet, scaled up. Each thread does one
// of the four operations above in round-robin, all four sharing the SAME Interface_Static
// table simultaneously (STEP and IGES both read/write "xstep.cascade.unit", among others).
// ---------------------------------------------------------------------------
void runMixedStepIgesIndependent(int id, int iterations)
{
  switch (id % 4)
  {
    case 0: runStepWriteIndependent(id, iterations); break;
    case 1: runIgesWriteIndependent(id, iterations); break;
    case 2: runStepReadIndependent(id, iterations); break;
    default: runIgesReadIndependent(id, iterations); break;
  }
}

// ---------------------------------------------------------------------------
// 6. Cross-talk (unlocked): direct proof that Interface_Static functions as a shared,
// unsynchronized implicit parameter channel. Each thread repeatedly sets
// "write.step.schema" to ITS OWN value, yields (widening the race window the way a real
// multi-statement Transfer()/Write() call naturally does), then reads the same parameter
// back. If it does not see its own value, another thread's concurrent Set clobbered it
// in between: a wrong-answer bug, independent of any crash.
// ---------------------------------------------------------------------------
void runCrossTalkSchemaUnlocked(int id, int iterations)
{
  const char* mine = (id % 2 == 0) ? "AP203" : "AP214IS";
  for (int it = 0; it < iterations; ++it)
  {
    Interface_Static::SetCVal("write.step.schema", mine);
    std::this_thread::yield();
    const char* seen = Interface_Static::CVal("write.step.schema");
    if (strcmp(seen, mine) != 0)
    {
      gCrossTalk++;
    }
    gOps++;
  }
}

// ---------------------------------------------------------------------------
// 7. Cross-talk (locked): the SAME scenario, but every individual SetCVal/CVal call is
// wrapped in its own std::mutex lock/unlock -- simulating exactly what a kernel-side fix
// that only makes the Interface_Static ACCESSORS thread-safe (a mutex or atomic guarding
// each Set*/Get* call, or making the backing NCollection_DataMap itself a concurrent
// container) would provide. If cross-talk still happens at a similar rate, that is direct
// evidence that container-level memory safety and this scenario's logical correctness are
// independent properties: the race is in the WINDOW between one thread's Set and its own
// later Get (or between a caller's Set and the read many stack frames below it inside
// Transfer()/Write()), not in the Set or Get call itself.
// ---------------------------------------------------------------------------
static std::mutex gAccessorMutex;

void runCrossTalkSchemaLocked(int id, int iterations)
{
  const char* mine = (id % 2 == 0) ? "AP203" : "AP214IS";
  for (int it = 0; it < iterations; ++it)
  {
    {
      std::lock_guard<std::mutex> lock(gAccessorMutex);
      Interface_Static::SetCVal("write.step.schema", mine);
    }
    std::this_thread::yield();
    const char* seen;
    {
      std::lock_guard<std::mutex> lock(gAccessorMutex);
      seen = Interface_Static::CVal("write.step.schema");
    }
    if (strcmp(seen, mine) != 0)
    {
      gCrossTalk++;
    }
    gOps++;
  }
}

// ---------------------------------------------------------------------------

struct Scenario
{
  const char* name;
  void (*fn)(int, int);
};

static Scenario SCENARIOS[] = {
  {"step_write_independent", runStepWriteIndependent},
  {"step_read_independent", runStepReadIndependent},
  {"iges_write_independent", runIgesWriteIndependent},
  {"iges_read_independent", runIgesReadIndependent},
  {"mixed_step_iges_independent", runMixedStepIgesIndependent},
  {"cross_talk_schema_unlocked", runCrossTalkSchemaUnlocked},
  {"cross_talk_schema_locked", runCrossTalkSchemaLocked},
};

static void writeFixtures()
{
  // STEP fixture.
  {
    TopoDS_Shape shape = BRepPrimAPI_MakeBox(15, 25, 35).Shape();
    STEPControl_Writer writer;
    Interface_Static::SetCVal("write.step.schema", "AP214");
    writer.Transfer(shape, STEPControl_AsIs);
    gStepReadFixture = gScratch + "/fixture.step";
    writer.Write(gStepReadFixture.c_str());
  }
  // IGES fixture.
  {
    TopoDS_Shape shape = BRepPrimAPI_MakeSphere(8).Shape();
    IGESControl_Writer writer("MM", 0);
    writer.AddShape(shape);
    gIgesReadFixture = gScratch + "/fixture.iges";
    writer.Write(gIgesReadFixture.c_str());
  }
}

static void runOne(const char* name, int threads, int iterations)
{
  bool needsFixtures = strstr(name, "read") != nullptr || strcmp(name, "mixed_step_iges_independent") == 0;
  if (needsFixtures)
    writeFixtures();

  // Answers whether the residual races in step_write_independent (the ones outside
  // Interface_Static.cxx: STEPControl_Controller::Init()'s own "inic" flag,
  // Interface_Static::Standards()'s own "THE_Interface_Static_deja" flag,
  // XSControl_Controller's "listad" registry, IFSelect_WorkSession's "errhand" global)
  // are a one-time cold-start hazard -- absent once ANY single-threaded STEP write has
  // already run in this process and forced every one-time lazy init to completion on one
  // thread -- or whether they persist under concurrent load regardless. Forces exactly
  // that warm-up, single-threaded, in THIS process (so the static flags carry over,
  // unlike running the binary twice), before spawning the real concurrent pool.
  bool warmStart = strcmp(name, "step_write_warmstart") == 0;
  const char* realName = warmStart ? "step_write_independent" : name;
  if (warmStart)
  {
    runStepWriteIndependent(-1, 1);
  }

  for (auto& s : SCENARIOS)
  {
    if (strcmp(realName, s.name) != 0)
      continue;
    std::vector<std::thread> pool;
    for (int i = 0; i < threads; ++i)
    {
      pool.emplace_back(s.fn, i, iterations);
    }
    for (auto& th : pool)
      th.join();
    return;
  }
  note("unknown scenario: %s", name);
  exit(2);
}

int main(int argc, char** argv)
{
  if (argc < 4)
  {
    note("usage: %s <scenario|all> <threads> <iterations> [scratch_dir]", argv[0]);
    return 2;
  }
  std::string scenario = argv[1];
  int         threads = atoi(argv[2]);
  int         iterations = atoi(argv[3]);
  if (argc >= 5)
    gScratch = argv[4];

  if (scenario == "all")
  {
    for (auto& s : SCENARIOS)
    {
      note(">>> %s", s.name);
      gOps = 0;
      gErrors = 0;
      gCrossTalk = 0;
      runOne(s.name, threads, iterations);
      note("    ops=%ld errors=%ld crossTalk=%ld", gOps.load(), gErrors.load(), gCrossTalk.load());
    }
  }
  else
  {
    runOne(scenario.c_str(), threads, iterations);
    note("ops=%ld errors=%ld crossTalk=%ld", gOps.load(), gErrors.load(), gCrossTalk.load());
  }

  return gErrors.load() > 0 ? 1 : 0;
}
