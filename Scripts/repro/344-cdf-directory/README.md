# OCCTSwift#344 reproducer, `CDF_Directory`/`XCAFApp_Application::GetApplication()` races

Minimal artifacts backing the root-cause of the uncatchable SIGSEGV seen in ~1-in-10 parallel
`swift test` runs, right after two concurrent OBJ mesh imports (found during the #341
investigation, confirmed to survive the #341 kernel fix in v1.15.5, see the #344 issue history).

## Verdict

**Two real, independent, previously-undetected races**, both in code the #341 TSan stress
(`Scripts/repro/341-meshcaf/occt_341_stress.cpp`) never reached, that harness builds its
`TDocStd_Document` directly (`new TDocStd_Document("BinXCAF")`), bypassing
`XCAFApp_Application`/`CDF_Application` entirely. The real bridge path
(`OCCTDocumentLoadOBJ`, `OCCTBridge_IO.mm`) does not: every document-producing bridge call goes
through `XCAFApp_Application::GetApplication()->NewDocument(...)`.

1. **`XCAFApp_Application::GetApplication()`** (`XCAFApp_Application.cxx`), a textbook
   double-checked-locking-without-locking bug:
   ```cpp
   static occ::handle<XCAFApp_Application> locApp;
   if (locApp.IsNull())
   {
     locApp = new XCAFApp_Application;
   }
   ```
   Two threads' first concurrent call can both observe `IsNull()` and both construct a new
   `XCAFApp_Application`, racing to assign the shared `locApp` handle. This is the dominant
   defect: TSan shows it doesn't just corrupt one handle, it produces **multiple concurrently
   constructed `XCAFApp_Application` instances** (each with its own `TPrsStd_DriverTable`
   registration, `CDF_Directory`, etc.), whose "losing" copies are then torn down while other
   threads are still constructing/using a same-generation object, cascading into races across
   dozens of unrelated destructors (`TDF_LabelNode::Destroy`, `TCollection_ExtendedString::~`,
   `CDM_Document::~CDM_Document`, `NCollection_BaseList::PClear`, ...) and several
   ctor/dtor-vs-virtual-call ("vptr") reports, i.e. genuine use of partially-constructed or
   partially-destroyed objects, not just a leaked handle.

2. **`CDF_Directory::Add`/`Remove`/`Contains`** (`CDF_Directory.cxx`), every
   `XCAFApp_Application`/`CDF_Application` instance is normally shared process-wide (that's the
   entire point of `GetApplication()`), so its one `CDF_Directory` receives `Add()` from every
   document-creating call on every thread. `myDocuments` is a plain `NCollection_List` with zero
   synchronization: `NCollection_BaseList::PAppend` mutates `myFirst`/`myLast`/`myLength` with no
   locking at all. Confirmed independently by TSan (`CDF_Directory.cxx:30`,
   `NCollection_BaseList.cxx:45/52/53`) even setting aside race #1.

The bridge never calls `Application->Close()` on a document (grep of `Sources/OCCTBridge`
confirms no call site), so `CDF_Directory::Remove` is never reached from OCCTSwift, every
document ever created via the bridge accumulates in `myDocuments` for the life of the process
(a separate, pre-existing leak, not fixed here since it's out of scope for #344).

## Repro

- `occt_344_newdoc_only.cpp`: free-running: N threads in a tight loop each call
  `XCAFApp_Application::GetApplication()->NewDocument(...)`. Fast (~300-900k ops/s
  uninstrumented), but OS scheduling naturally spreads out threads enough that true
  instruction-level collisions on the unsynchronized critical sections are rare, did not crash
  in isolation across several uninstrumented runs up to 320k total calls.
- `occt_344_barrier.cpp`: the one that matters: identical, but every thread spin-waits at a
  barrier before each round's `NewDocument()` call, forcing genuine simultaneous contention every
  round instead of relying on scheduling luck. **Crashes ~50% of the time** at 10 threads × 3000
  rounds against the stock (unpatched) shipped xcframework, with a debug (`-O0 -g`) build plus a
  temporary `SIGSEGV`/`SIGBUS` handler (`backtrace_symbols_fd`, per the
  `feedback-lldb-blocked-use-signal-handler` technique, lldb/core dumps are unavailable in the
  diagnosing sandbox). Both captured crashes resolve to the same site:
  ```
  TDocStd_Application::NewDocument(...) -> CDF_Application::Open(...)
  ```
  matching the `CDF_Directory::Add`/`NCollection_BaseList::PAppend` corruption mechanism exactly
  (one frame shows `CDF_Application::Open` duplicated, a stack-corruption artifact, not real
  recursion).
- `occt_344_stress.cpp`: same shape as the #341 harness's `obj_roundtrip_unique` scenario but
  going through `XCAFApp_Application::GetApplication()` (write+read OBJ round-trip, own file per
  thread) rather than a hand-built `TDocStd_Document`; included for completeness, not the primary
  repro (the free-running scheduling problem above applies here too).

```bash
clang++ -std=c++17 -O0 -g \
  -I Libraries/OCCT.xcframework/macos-arm64/Headers \
  -L Libraries/OCCT.xcframework/macos-arm64 \
  occt_344_barrier.cpp -o occt_344_barrier \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++
for i in $(seq 1 15); do ./occt_344_barrier 10 3000; done
```

TSan confirmation (minimal-module `FoundationClasses`+`ModelingData`+`ModelingAlgorithms`+
`DataExchange`, `RelWithDebInfo`, `-fsanitize=thread -g`, matching the #298/#319/#341 protocol):
stock p1 reports both races above (plus the resulting destructor cascade) within the first
~200 rounds at 8 threads; the fix (below) closes race #1 entirely, collapsing the cascade, and
converts race #2 into properly serialized access.

## Fix

`Scripts/patches/0012-CDF_Directory-XCAFApp_Application-thread-safety-344.patch`:

1. `XCAFApp_Application::GetApplication()`: fold construction into the `static` local's
   initializer (C++11 "magic statics" guarantee it runs exactly once, thread-safely), instead of
   a separate runtime `IsNull()` check + assignment.
2. `CDF_Directory`: a private `mutable std::mutex myMutex` guards `Add`/`Remove`/`Contains`/
   `Length`/`IsEmpty`/`Last`. `Add()` inlines the containment scan instead of calling the public
   `Contains()` to avoid a self-deadlock on the (non-recursive) mutex. `List()`, used only by the
   friend `CDF_DirectoryIterator`, which nothing in OCCTSwift's bridge uses, is intentionally
   left unguarded; iterating the returned reference is still not safe against a concurrent
   `Add()`/`Remove()`, and closing that gap would need a bigger API change (return a snapshot
   copy) out of proportion to the confirmed, reachable defect this patch fixes.

## Second part, found during validation

Fixing `GetApplication()`'s race means every caller now genuinely shares ONE `TDocStd_Application`
instance (as intended), which surfaced more races on that same instance's *other* unsynchronized
state, previously masked by threads sometimes getting different (uncontended) instances. Repeated
`swift test` runs (validating the fix above against `Tests/OCCTXCAFTests`) hit two more crashes:

3. **`TDocStd_Application::Resources()`**: the identical lazy-init race as `GetApplication()`:
   `if (myResources.IsNull()) { myResources = new Resource_Manager(...); }`, no locking.
4. **`Resource_Manager`'s maps** (`myRefMap`/`myUserMap`/`myExtStrMap`), zero synchronization.
   Caught live: SIGTRAP inside `Resource_Manager::SetResource`, called from
   `TDocStd_Application::DefineFormat` (itself called by `Document.defineAllFormats()`, a common
   per-test setup path many parallel XCAF tests invoke concurrently).
5. **`CDF_Application::myReaders`/`myWriters`** (format-name → driver maps), read/written from
   `DefineFormat`, `ReaderFromFormat`/`WriterFromFormat`, and `ReadingFormats`/`WritingFormats` with
   no locking. Caught live: SIGSEGV inside `TDocStd_Application::ReadingFormats` iterating
   `myReaders` while another thread's `DefineFormat` mutated it concurrently.

Fix: a mutex guards `Resources()`'s lazy-init (same pattern as fix 1); a `std::recursive_mutex`
guards `Resource_Manager`'s public accessors (recursive because `Integer()`/`Real()`/`ExtValue()`
call `Value()` internally, and the `int`/`double` `SetResource()` overloads call the `char*` one),
`GetMap()`, a raw-reference escape hatch with no callers in this area, is left unguarded, same
rationale as `CDF_Directory::List()`; a mutex guards `myReaders`/`myWriters` across every access
point. The new `Resource_Manager` mutex member makes the class non-copyable by default, breaking
`ShapeProcess_Context.cxx`'s existing `new Resource_Manager(*sRC)` thread-safety workaround, its
own comment already acknowledged this exact defect (*"calling of SetResource() for one object in
multiple threads causes race condition"*), worked around locally rather than fixed at the source.
Added an explicit copy constructor that copies the maps under the source's lock and
default-constructs a fresh mutex for the new instance.

Validated: both crashes reproducible before this part of the patch; 0/12 further `swift test` runs
of `OCCTXCAFTests` reproduce either after it.

## Known remaining issue (not fixed here)

A third, architecturally different crash surfaced in the same validation:
`BinLDrivers_DocumentStorageDriver::Write`/`WriteSubTree` corrupts a shared, cached, non-reentrant
storage-driver instance under concurrent `Save`/`SaveAs` of the *same format*,
`CDF_Application::WriterFromFormat` creates one driver per format and reuses it for every write,
but the driver's own `Write()` isn't reentrant (instance-level scratch state like `myRelocTable`
gets corrupted by concurrent callers). This is a shared *worker object*, not a container needing a
lock, and needs its own dedicated TSan investigation, filed separately as
[SecondMouseAU/OCCTSwift#349](https://github.com/SecondMouseAU/OCCTSwift/issues/349).

Filed upstream as [Open-Cascade-SAS/OCCT#1389](https://github.com/Open-Cascade-SAS/OCCT/issues/1389)
(repro) / [OCCT#1390](https://github.com/Open-Cascade-SAS/OCCT/pull/1390) (fix, two commits).
