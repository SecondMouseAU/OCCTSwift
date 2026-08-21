# OCCTSwift#374 reproducer, `Resource_Manager::Debug` / `Storage_Schema::ICurrentData()` races

Kernel-fix writeup for the two races the [#371](https://github.com/SecondMouseAU/OCCTSwift/issues/371)
confirmation harness turned up: replacing every bridge use of the shared
`XCAFApp_Application::GetApplication()` singleton with a private `TDocStd_Application` per document
closed our exposure to the #341/#344/#349/#353 race family, but made application/schema
*construction itself* concurrent for the first time, something the old shared singleton never
allowed, and that surfaced two previously-uncaught OCCT foundation-layer races, filed upstream as
[OCCT#1398](https://github.com/Open-Cascade-SAS/OCCT/issues/1398).

## Verdict

**Real, previously-undetected kernel defects, fixed.** Both hypotheses in the issue are confirmed
exactly as described, with concrete TSan traces pinning down every call chain.

1. **`Resource_Manager::Resource_Manager(const char*, bool)`** (`Resource_Manager.cxx:109`) writes
   a file-scope `static bool Debug` on every construction, unsynchronized. Every fresh
   `TDocStd_Application`'s first `DefineFormat()` call lazily constructs its own `Resource_Manager`
   via `Resources()` (`TDocStd_Application.cxx:65`), `Resources()`'s own lazy-init is per-instance
   mutex-guarded since the #344 fix, but that only serializes repeat calls on the *same* instance,
   not first-construction races across *different* instances built concurrently on different
   threads.
2. **`Storage_Schema::ICurrentData()`** (`Storage_Schema.cxx:802`) is a function-local static
   `Handle(Storage_Data)` mutated with zero synchronization anywhere: `Write()` (the `SaveAs()`
   path) sets it for the duration of one store via `ISetCurrentData()`, and *any* `Storage_Schema`
   construction, including the throwaway one `PCDM_ReadWriter_1::ReadReferenceCounter`/
   `ReadReferences`/`ReadDocumentVersion` each build on **every** `Open()` (reached
   unconditionally, on the non-append/not-already-retrieved path, via
   `CDF_Application::Retrieve` → `SetDocumentVersion`/`ReferenceIterator`/`ReferenceCounter` →
   `PCDM_RetrievalDriver`), calls `Clear()` → `ICurrentData().Nullify()` in its constructor
   (`Storage_Schema.cxx:262`). A load on one thread nulls out a save's in-flight scratch data on
   another, and two concurrent loads' throwaway schemas race each other the same way.

Neither had ever been caught by this project's prior TSan gates (#298/#319/#341/#344/#345/#348/
#349/#353/#371) because none of them exercised concurrent *construction* of independent
application/schema instances, every prior investigation (and all of production, until #371)
shared one `XCAFApp_Application::GetApplication()` instance, so `Resources()`'s own per-instance
lazy-init mutex (from the #344 fix) accidentally serialized `Resource_Manager`/`Storage_Schema`
construction down to "runs once, ever, for the whole process." Moving to a private instance per
caller, the pattern OCCT's own maintainer recommended in #1396, is what first makes these
concurrent.

## Repro

`occt_374_stress.cpp`: the "unguarded" variant of
[`371-getapplication-singleton-elimination/occt_371_private_app.cpp`](../371-getapplication-singleton-elimination/occt_371_private_app.cpp):
same private-`TDocStd_Application`-per-(thread,round) structure (build, populate, `SaveAs`,
`Close`, then a **separate** private app `Open`s + verifies + `Close`s), but with no
`ocafStoreMutexSim()` around `DefineFormat`/`SaveAs`/`Open`, the #371 investigation's own bridge
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
`-fsanitize=thread -g`, patches 0001-0015 already applied, same protocol as #298/#319/#341/#344/
#349/#353/#371).

**Before the fix** (8 threads × 30 rounds): 13 TSan warnings, exit code 134 (SIGABRT), 0 functional
failures, 2 warnings in `Resource_Manager::Resource_Manager(char const*, bool)` at
`Resource_Manager.cxx:109` (write racing write, both via `TDocStd_Application::DefineFormat` →
`Resources()`), 11 in `Storage_Schema::Storage_Schema()` at `Storage_Schema.cxx:262` (the `Clear()`
call), reached via `ReadReferenceCounter`/`ReadReferences`→`ReadUserInfo`/`ReadDocumentVersion`, all
racing each other and (in other runs) `Write()`'s own use of `ICurrentData()`.

**After the fix** (`Scripts/patches/0016` applied, `TKernel` rebuilt in place, the only module
that changed): 0 races, clean exit, across 4 repeated runs (8×30, 8×50, 10×60, 8×40). Full gate
(`Scripts/tsan-stress.sh run`, 10 scenarios including this one) clean, 0 regressions on the
#341/#344/#349/#353/#371 scenarios.

## Fix

`Scripts/patches/0016-Resource_Manager-atomic-Debug-Storage_Schema-per-instance-374.patch`. Two
independent fixes, matching the two distinct races. Fix 1 follows the established "lock/atomic the
shared resource, don't restructure the subsystem" precedent (#341's atomic bool, #344's
`CDF_Directory` mutex, #349's per-driver mutex, #353's table + per-object mutexes). Fix 2 originally
did too, and was revised on upstream review to remove the sharing instead (see "Revised" below):

1. **`Resource_Manager::Debug`**: `static bool` → `static std::atomic<bool>`. It's a plain
   process-wide debug-logging flag, not meant to express per-instance intent (unlike #341's
   `theAutoNaming`, which needed a deeper per-instance redesign), an atomic is sufficient and
   matches the issue's own suggested fix scope.
2. **`Storage_Schema::ICurrentData()`**: the function-local static is deleted. The handle becomes a
   `mutable occ::handle<Storage_Data> myCurrentData` field on `Storage_Schema`, so there is no
   shared state left to guard. `Write()` assigns the field, `Clear()` nullifies its own, and
   `HasTypeBinding()`/`BindType()`/`TypeBinding()`/`AddPersistent()`/`PersistentToAdd()` read it
   through `*this`. The two private statics `ISetCurrentData()` and `ICurrentData()` are removed.
   `mutable` because all of those methods are `const`.

   The same commit drops the `static` from `AddPersistent()`'s `TCollection_AsciiString aTypeName`
   scratch variable, a separate, smaller process-wide hazard in the same class. It is assigned from
   the `tName` argument and read two lines later, so `static` only ever saved an allocation. The
   mutex version covered it incidentally; the per-instance field does not, and a lock is the wrong
   answer for a value that wants to be a local.

No signature changes to any public OCCT API: `ICurrentData()` and `ISetCurrentData()` were both
private, and nothing outside `Storage_Schema` referenced either. `OCCTBridge.xcframework` did not
need rebuilding; only the pinned `OCCT.xcframework` kernel binary changed.

### Revised on upstream review (#518)

The first shipped version of fix 2 (v1.15.18) added `Storage_Schema::ICurrentDataMutex()`, a
function-local `static std::recursive_mutex&` mirroring `ICurrentData()`'s own accessor pattern,
held across the constructor's `Clear()`, the whole body of `Write()` (one atomic session against the
global rather than one lock per access), `BindType()`, `TypeBinding()`, `AddPersistent()`,
`PersistentToAdd()`, `HasTypeBinding()` and `ISetCurrentData()`. Recursive, because `Write()`'s own
critical section re-enters `BindType`/`AddPersistent`/`PersistentToAdd` on the same thread through
the per-type `Storage_CallBack::Write()` callbacks it invokes.

That was memory-safe but it synchronized access to sharing that should not exist. Reviewing
[OCCT#1399](https://github.com/Open-Cascade-SAS/OCCT/pull/1399#issuecomment-5112586065), maintainer
gkv311 suggested the field instead. The state was never process-wide: **every** `Storage_Schema` in
the tree is constructed locally by its caller and used only there (`PCDM_StorageDriver::Write`, and
`PCDM_ReadWriter_1` at three sites), no instance is cached or shared anywhere, and
`Storage_CallBack::Add`/`Write`/`Read` all take the driving schema as an argument, so every callback
re-entry lands back on the same instance. The other `Storage_Schema` users in the tree
(`BinLDrivers`, `XmlMDF`, `StdLDrivers`) touch only its statics `CheckTypeMigration()` and
`ICreationDate()`, neither of which reads the current data.

The field is also strictly stronger on the failure this issue reported. Under the mutex, a throwaway
`Storage_Schema` built by `PCDM_ReadWriter_1` during an unrelated `Open()` still nullified an
in-flight `Write()`'s current data, it just did so without a data race. Under the field it cannot
reach another instance's data at all. It narrows exactly one thing: the mutex incidentally
serialized two threads driving the *same* `Storage_Schema` instance, and the field does not. No
caller does that, because no instance is shared.

Same correction, and the same lesson, as #341 to #363: a lock is the right tool only when the state
is genuinely one shared resource; when it is per-instance data masquerading as a global, relocate
the ownership.

## Validation

- TSan: 4/4 clean runs after the fix (8×30, 8×50, 10×60, 8×40); 13 confirmed races + SIGABRT before,
  same binary/harness. Full `Scripts/tsan-stress.sh run` gate (10 scenarios): clean.
- Full production xcframework rebuilt via `Scripts/build-occt.sh` (macOS + iOS device + iOS
  simulator).
- `swift test` (full suite) and `Scripts/tsan-stress.sh swift`, see the parent task's final report
  for exact pass counts.

## Upstream status

Filed as [OCCT#1398](https://github.com/Open-Cascade-SAS/OCCT/issues/1398) (repro, filed during
#371). This investigation's fix is proposed as the upstream PR referenced from that issue.

## New follow-up races (NOT fixed here)

None found. Repeated post-fix TSan runs (4 total, up to 10×60) were fully clean, no new symptom
surfaced the way #344 → #349 → #353 each unmasked the next, or the way #371 unmasked this one. If a
future investigation wants to push harder (more threads/rounds, cross-document references to
exercise `CDM_Reference`/`PCDM_ReferenceIterator` paths this harness doesn't reach), that's the
next place to look.
