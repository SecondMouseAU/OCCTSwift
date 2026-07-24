# OCCTSwift#374 reproducer — `Resource_Manager::Debug` / `Storage_Schema::ICurrentData()` races

Kernel-fix writeup for the two races the [#371](https://github.com/SecondMouseAU/OCCTSwift/issues/371)
confirmation harness turned up: replacing every bridge use of the shared
`XCAFApp_Application::GetApplication()` singleton with a private `TDocStd_Application` per document
closed our exposure to the #341/#344/#349/#353 race family, but made application/schema
*construction itself* concurrent for the first time — something the old shared singleton never
allowed — and that surfaced two previously-uncaught OCCT foundation-layer races, filed upstream as
[OCCT#1398](https://github.com/Open-Cascade-SAS/OCCT/issues/1398).

## Verdict

**Real, previously-undetected kernel defects — fixed.** Both hypotheses in the issue are confirmed
exactly as described, with concrete TSan traces pinning down every call chain.

1. **`Resource_Manager::Resource_Manager(const char*, bool)`** (`Resource_Manager.cxx:109`) writes
   a file-scope `static bool Debug` on every construction, unsynchronized. Every fresh
   `TDocStd_Application`'s first `DefineFormat()` call lazily constructs its own `Resource_Manager`
   via `Resources()` (`TDocStd_Application.cxx:65`) — `Resources()`'s own lazy-init is per-instance
   mutex-guarded since the #344 fix, but that only serializes repeat calls on the *same* instance,
   not first-construction races across *different* instances built concurrently on different
   threads.
2. **`Storage_Schema::ICurrentData()`** (`Storage_Schema.cxx:802`) is a function-local static
   `Handle(Storage_Data)` mutated with zero synchronization anywhere: `Write()` (the `SaveAs()`
   path) sets it for the duration of one store via `ISetCurrentData()`, and *any* `Storage_Schema`
   construction — including the throwaway one `PCDM_ReadWriter_1::ReadReferenceCounter`/
   `ReadReferences`/`ReadDocumentVersion` each build on **every** `Open()` (reached
   unconditionally, on the non-append/not-already-retrieved path, via
   `CDF_Application::Retrieve` → `SetDocumentVersion`/`ReferenceIterator`/`ReferenceCounter` →
   `PCDM_RetrievalDriver`) — calls `Clear()` → `ICurrentData().Nullify()` in its constructor
   (`Storage_Schema.cxx:262`). A load on one thread nulls out a save's in-flight scratch data on
   another, and two concurrent loads' throwaway schemas race each other the same way.

Neither had ever been caught by this project's prior TSan gates (#298/#319/#341/#344/#345/#348/
#349/#353/#371) because none of them exercised concurrent *construction* of independent
application/schema instances — every prior investigation (and all of production, until #371)
shared one `XCAFApp_Application::GetApplication()` instance, so `Resources()`'s own per-instance
lazy-init mutex (from the #344 fix) accidentally serialized `Resource_Manager`/`Storage_Schema`
construction down to "runs once, ever, for the whole process." Moving to a private instance per
caller — the pattern OCCT's own maintainer recommended in #1396 — is what first makes these
concurrent.

## Repro

`occt_374_stress.cpp` — the "unguarded" variant of
[`371-getapplication-singleton-elimination/occt_371_private_app.cpp`](../371-getapplication-singleton-elimination/occt_371_private_app.cpp):
same private-`TDocStd_Application`-per-(thread,round) structure (build, populate, `SaveAs`,
`Close`, then a **separate** private app `Open`s + verifies + `Close`s), but with no
`ocafStoreMutexSim()` around `DefineFormat`/`SaveAs`/`Open` — the #371 investigation's own bridge
mitigation deliberately masks both races, so this reproducer omits it to exercise the real kernel
defect directly.

```
Usage: occt_374_stress <threads> <rounds> <scratchDir>
```

```bash
clang++ -std=c++17 -fsanitize=thread -g -O1 \
  -I <tsan-install>/include/opencascade -L <tsan-install>/lib \
  occt_374_stress.cpp -o occt_374_tsan \
  $(ls <tsan-install>/lib/libTK*.a | xargs -n1 basename | sed 's/^lib//;s/\.a$//;s/^/-l/') \
  -lz -lc++ -framework Foundation

MMGT_OPT=0 TSAN_OPTIONS="halt_on_error=0" ./occt_374_tsan 8 30 /tmp/occt374_scratch
```

## TSan confirmation

Built against the project's existing minimal-module TSan install
(`FoundationClasses`+`ModelingData`+`ModelingAlgorithms`+`DataExchange`, `RelWithDebInfo`,
`-fsanitize=thread -g`, patches 0001-0015 already applied — same protocol as #298/#319/#341/#344/
#349/#353/#371).

**Before the fix** (8 threads × 30 rounds): 13 TSan warnings, exit code 134 (SIGABRT), 0 functional
failures — 2 warnings in `Resource_Manager::Resource_Manager(char const*, bool)` at
`Resource_Manager.cxx:109` (write racing write, both via `TDocStd_Application::DefineFormat` →
`Resources()`), 11 in `Storage_Schema::Storage_Schema()` at `Storage_Schema.cxx:262` (the `Clear()`
call), reached via `ReadReferenceCounter`/`ReadReferences`→`ReadUserInfo`/`ReadDocumentVersion`, all
racing each other and (in other runs) `Write()`'s own use of `ICurrentData()`.

**After the fix** (`Scripts/patches/0016` applied, `TKernel` rebuilt in place — the only module
that changed): 0 races, clean exit, across 4 repeated runs (8×30, 8×50, 10×60, 8×40). Full gate
(`Scripts/tsan-stress.sh run`, 10 scenarios including this one) clean, 0 regressions on the
#341/#344/#349/#353/#371 scenarios.

## Fix

`Scripts/patches/0016-Resource_Manager-atomic-Debug-Storage_Schema-mutex-374.patch`. Two
independent fixes, matching the two distinct races, both following the established "lock/atomic
the shared resource, don't restructure the subsystem" precedent (#341's atomic bool, #344's
`CDF_Directory` mutex, #349's per-driver mutex, #353's table + per-object mutexes):

1. **`Resource_Manager::Debug`**: `static bool` → `static std::atomic<bool>`. It's a plain
   process-wide debug-logging flag, not meant to express per-instance intent (unlike #341's
   `theAutoNaming`, which needed a deeper per-instance redesign) — an atomic is sufficient and
   matches the issue's own suggested fix scope.
2. **`Storage_Schema::ICurrentData()`**: a new `Storage_Schema::ICurrentDataMutex()` (function-local
   static `std::recursive_mutex&`, mirroring `ICurrentData()`'s own existing accessor pattern) now
   guards every touch point: the constructor's `Clear()`, `Write()`'s entire body (from
   `ISetCurrentData()` through the trailing `Clear()` — the whole call is one atomic "session"
   against this global, so the lock spans it, not just each individual access), `BindType()`,
   `TypeBinding()`, `AddPersistent()`, `PersistentToAdd()`, `HasTypeBinding()` (inline in the
   header), and `ISetCurrentData()` itself. Recursive because `Write()`'s own critical section
   calls back into `BindType()`/`AddPersistent()`/`PersistentToAdd()` on the *same* thread via the
   per-type `Storage_CallBack::Write()` callbacks it invokes — a plain mutex would deadlock there.
   `AddPersistent()`'s pre-existing `static TCollection_AsciiString aTypeName` scratch variable
   (itself unsynchronized, a second, smaller hazard noticed while patching this function) is
   incidentally covered by the same lock now spanning the whole function body.

No signature changes to any public OCCT API — `ICurrentDataMutex()` is a new private static
accessor, exactly like `ICurrentData()` itself. `OCCTBridge.xcframework` did not need rebuilding;
only the pinned `OCCT.xcframework` kernel binary changed.

## Validation

- TSan: 4/4 clean runs after the fix (8×30, 8×50, 10×60, 8×40); 13 confirmed races + SIGABRT before,
  same binary/harness. Full `Scripts/tsan-stress.sh run` gate (10 scenarios): clean.
- Full production xcframework rebuilt via `Scripts/build-occt.sh` (macOS + iOS device + iOS
  simulator).
- `swift test` (full suite) and `Scripts/tsan-stress.sh swift` — see the parent task's final report
  for exact pass counts.

## Upstream status

Filed as [OCCT#1398](https://github.com/Open-Cascade-SAS/OCCT/issues/1398) (repro, filed during
#371). This investigation's fix is proposed as the upstream PR referenced from that issue.

## New follow-up races (NOT fixed here)

None found. Repeated post-fix TSan runs (4 total, up to 10×60) were fully clean — no new symptom
surfaced the way #344 → #349 → #353 each unmasked the next, or the way #371 unmasked this one. If a
future investigation wants to push harder (more threads/rounds, cross-document references to
exercise `CDM_Reference`/`PCDM_ReferenceIterator` paths this harness doesn't reach), that's the
next place to look.
