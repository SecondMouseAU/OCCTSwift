# OCCTSwift#353 reproducer, `CDM_Application::myMetaDataLookUpTable` / `CDM_MetaData` race

Root-cause writeup for the race surfaced during validation of the #349 fix (kernel patch
`Scripts/patches/0014`, shipped v1.15.9): post-#349-fix TSan runs consistently produced exactly
one different, previously-masked warning in `CDM_MetaData::IsRetrieved()`/`UnsetDocument()`. See
`Scripts/repro/349-ocaf-driver-reentrancy/README.md`'s "New finding surfaced by this fix" section
for the original report.

## Verdict

**Real, previously-undetected kernel defect, fixed.** The issue's own hypothesis is confirmed,
and the actual blast radius is a bit wider than the two call chains quoted in the issue text.

`CDM_Application::myMetaDataLookUpTable` (`CDM_Application.hxx:97`) is a plain
`NCollection_DataMap<TCollection_ExtendedString, occ::handle<CDM_MetaData>>`, one instance per
`CDM_Application`/`CDF_Application` (in practice the one process-wide `TDocStd_Application`
singleton, since #344's `GetApplication()`/`CDF_Application` fix), with zero synchronization
anywhere in the class. Every path that touches it races against every other:

- **Map mutation**: `CDM_MetaData::LookUp()` (both overloads, `CDM_MetaData.cxx:92`/`119`) does an
  unguarded `IsBound()` + `Bind()`/`Find()` sequence on the table, called from
  `CDF_FWOSDriver::MetaData`/`CreateMetaData` (via `CDF_StoreList::Store`, i.e. every
  `Store()`/`SaveAs()`), `XmlLDrivers_DocumentRetrievalDriver::Read` (line 445, reference-loading
  during XML retrieval), and `PCDM_ReferenceIterator::MetaData` (line 136, reference-loading for
  every format).
- **Map iteration**: `CDM_Document::SetMetaData()` (`CDM_Document.cxx:474`) iterates the **entire**
  table on every `SetMetaData()` call (i.e. every successful `Store()`) to update cross-document
  references, reading `theMetaData->IsRetrieved()`/`->Document()` for every OTHER document's
  metadata entry in the whole application, concurrently with whatever any other thread is doing to
  the map or to those `CDM_MetaData` objects.
- **Per-object state**: independent of the map itself, each `CDM_MetaData` instance's
  `myIsRetrieved`/`myDocument` fields are mutated by `SetDocument()`/`UnsetDocument()`
  (`CDM_MetaData.cxx:77`/`83`) and read by `IsRetrieved()`/`Document()` (`.cxx:67`/`72`) with no
  guard at all, this is the exact pair the original #349-writeup TSan trace caught:
  `CDM_Document::SetMetaData()`'s map-iteration loop (`CDM_Document.cxx:487`, reading
  `IsRetrieved()`) racing against a **different** document's destructor
  (`~CDM_Document() -> UnsetDocument()`, `CDM_Document.cxx:61`) tearing down its own, unrelated
  `CDM_MetaData` entry, `CDM_MetaData` objects are shared/long-lived (kept alive by the map for
  the application's lifetime, per `CDM_MetaData::LookUp`'s comment-free but observable "bind once,
  reuse forever" behavior), so any document's close can race any other thread's concurrent save.

This is the same failure class as `CDF_Directory::myDocuments` (#344) and `theAutoNaming` (#341):
a process/application-shared container (here, a container *and* the objects it hands out) mutated
with no lock, now exposed because #344's `GetApplication()` fix made every caller genuinely share
one `TDocStd_Application`/`CDM_Application` instance instead of sometimes getting independent
(uncontended) ones.

## Repro

`occt_353_barrier.cpp`: a rename/light adaptation of
`Scripts/repro/349-ocaf-driver-reentrancy/occt_349_barrier.cpp` (the same repro that originally
surfaced this race is the cleanest way to reproduce it in isolation; a bespoke reproducer wasn't
needed). N threads each build their own small `TDocStd_Document` with a **unique file path per
(thread, round)**, so the map grows every round (`Bind`, not `Find`) rather than reusing one
key, spin-wait at a barrier, then call `TDocStd_Application::SaveAs()` on the shared
`TDocStd_Application` at nearly the same instant, and finally `app->Close(doc)` to drop the
document's last reference at the end of the loop body (destroying it, and calling
`CDM_MetaData::UnsetDocument()` on its own entry) while other threads are mid-`SaveAs()` for their
own, different documents in the next round.

Must be run against a build with the #349 kernel fix (patch 0014) already applied, #353 is the
race #349's own fix unmasked, not #349's original driver-reentrancy defect.

```bash
clang++ -std=c++17 -O0 -g \
  -I Libraries/OCCT.xcframework/macos-arm64/Headers \
  -L Libraries/OCCT.xcframework/macos-arm64 \
  occt_353_barrier.cpp -o occt_353_barrier \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++

MMGT_OPT=0 ./occt_353_barrier 8 25 /tmp/occt353_scratch
```

## TSan confirmation

Built against the project's existing minimal-module TSan install
(`FoundationClasses`+`ModelingData`+`ModelingAlgorithms`+`DataExchange`, `RelWithDebInfo`,
`-fsanitize=thread -g`, matching the #298/#319/#341/#344/#349 protocol, reused
`Libraries/occt-build-tsan349`/`occt-install-tsan349` from the #349 investigation, which already
had patch 0014 baked in):

```bash
clang++ -std=c++17 -fsanitize=thread -g -O1 \
  -I <tsan-install>/include/opencascade -L <tsan-install>/lib \
  occt_353_barrier.cpp -o occt_353_tsan \
  $(ls <tsan-install>/lib/libTK*.a | xargs -n1 basename | sed 's/^lib//;s/\.a$//;s/^/-l/') \
  -lz -lc++ -framework Foundation

MMGT_OPT=0 TSAN_OPTIONS="halt_on_error=0" ./occt_353_tsan 8 25 /tmp/occt353_tsan_scratch
```

**Before the fix** (8 threads x 25 rounds, one run): 1 TSan warning, exit code 134 (SIGABRT),
matches the issue's reported symptom exactly:

```
WARNING: ThreadSanitizer: data race
  Read of size 1 at 0x... by thread T8 (mutexes: write M0):
    CDM_MetaData::IsRetrieved() const              CDM_MetaData.cxx:69
    CDM_Document::SetMetaData(...)                 CDM_Document.cxx:487
    CDF_StoreList::Store(...)                       CDF_StoreList.cxx:153
    CDF_Store::Realize(...)                         CDF_Store.cxx:157
    TDocStd_Application::SaveAs(...)                TDocStd_Application.cxx:363

  Previous write of size 1 at 0x... by thread T6:
    CDM_MetaData::UnsetDocument()                   CDM_MetaData.cxx:85
    CDM_Document::~CDM_Document()                   CDM_Document.cxx:61
    TDocStd_Document::~TDocStd_Document()            TDocStd_Document.hxx:46
SUMMARY: ThreadSanitizer: data race CDM_MetaData.cxx:69 in CDM_MetaData::IsRetrieved() const
```

Note `SetMetaData()`'s call at `CDF_StoreList.cxx:153` is still *inside* #349's own per-driver
`aDriverLock` (that lock's scope covers `Write()` through the reference-iteration loop in current
source), but that mutex is scoped to the cached `PCDM_StorageDriver` instance for one format, and
has no relationship at all to a *different* thread's document destructor, which never touches any
driver. The two races are on genuinely independent resources; #349's fix does nothing for this one
by construction, matching the issue's own framing.

**After the fix**: rebuilt `occt-build-tsan349`/`occt-install-tsan349` in place (`cmake --build`,
incremental, TKCDF/TKXmlL/TKLCAF and their dependents recompiled) with `Scripts/patches/0015`
applied to `occt-src`:

- 8x25: 0 races, clean exit (0, was 134/SIGABRT).
- 10x60: 0 races, clean exit.
- 3 further runs at 8x40: 0 races, clean exit, every run.

5/5 clean TSan runs after the fix, 0/5 before (1 confirmed race + abort every time it was tried).

## Fix

`Scripts/patches/0015-CDM_Application-metadata-lookup-table-mutex-353.patch`. Follows the
established "lock the shared resource, don't restructure the subsystem" precedent (#341's atomic
bool, #344's `CDF_Directory` mutex, #349's per-driver-instance mutex) rather than eliminating the
shared state, the "bind once, reuse forever, share across all documents" caching design of
`CDM_Application::myMetaDataLookUpTable` is load-bearing (it's how OCCT recognizes "this same file
is already open" across separate `Retrieve()`/`Store()` calls), not incidental scratch state like
#349's driver fields were.

Two independent things needed locking, matching the two distinct races found:

1. **The table itself** (`CDM_Application::myMetaDataLookUpTable`). Added
   `mutable std::mutex myMetaDataLookUpTableMutex` + a `MetaDataLookUpTableMutex()` accessor to
   `CDM_Application`. `CDM_MetaData::LookUp()` (both overloads) now takes the mutex as an explicit
   parameter and locks it around the `IsBound`/`Bind`/`Find` sequence; `CDM_Document::SetMetaData`
   locks it around its whole-table reference-update iteration. All four call sites that reach
   `LookUp()`/iterate the table already had a `CDM_Application`/`CDF_Application` handle in scope
   (`CDF_FWOSDriver` didn't, its constructor now also takes the mutex, alongside the table
   reference it already stored), so this needed no new plumbing beyond one extra parameter per call
   site.
2. **Each `CDM_MetaData` instance's own mutable state** (`myIsRetrieved`/`myDocument`),
   independent of the table, because two `CDM_MetaData` objects that are both already bound in the
   map (no `Bind()`/`Find()` involved) can still race on `SetDocument()`/`UnsetDocument()` vs.
   `IsRetrieved()`/`Document()` from different threads, exactly as the original TSan trace showed.
   Added a private `mutable std::mutex myDocumentMutex` to `CDM_MetaData`, locked in all four
   accessor/mutator methods.

Files touched: `CDM_Application.hxx` (mutex + accessor), `CDM_MetaData.hxx`/`.cxx` (per-object
mutex + `LookUp()` signature change), `CDM_Document.cxx` (`SetMetaData()` iteration lock),
`CDF_FWOSDriver.hxx`/`.cxx` (constructor + both `LookUp()` call sites), `CDF_Application.cxx`
(one-line constructor update), `XmlLDrivers_DocumentRetrievalDriver.cxx` and
`PCDM_ReferenceIterator.hxx`/`.cxx` (the other two `LookUp()`/`MetaData()` call sites). No changes
to any format-specific driver subclass.

**Not changed**: `CDM_MetaData::myDocumentVersion` (accessed via the private
`DocumentVersion(CDM_Application&)`, called from `CDM_Reference.cxx:91`/`107` and
`CDM_Application::SetDocumentVersion`) has the identical unguarded-mutable-field shape as
`myIsRetrieved`/`myDocument` but is on the document-*reference* resolution path, not the
save/close path this repro exercises, not observed racing in any run here, and not covered by
`occt_353_barrier` (which never loads cross-document references). Flagging as a plausible sibling,
not verified, not fixed, a natural target if a future TSan pass over the reference-loading path
turns up something.

## Validation

- TSan: 5/5 clean runs after the fix (8x25, 10x60, 3x8x40); 1 confirmed race + SIGABRT before, on
  the same binary/harness.
- `clang-format --dry-run --Werror` clean on every touched file (config:
  `Libraries/occt-src/.clang-format`).
- Full xcframework rebuilt via `Scripts/build-occt.sh` (macOS + iOS device + iOS simulator).
- `swift test --filter OCAFSaveLoadBinaryTests`, `swift test --filter OCCTXCAFTests`, and
  N full `swift test` runs, see the parent task's final report for exact pass counts.

## New follow-up races (NOT fixed here)

None found beyond the `myDocumentVersion` note above (which is speculative, not TSan-confirmed).
Repeated post-fix TSan runs (5 total, up to 10x60) were fully clean, no new symptom surfaced the
way #344 -> #349 -> #353 each unmasked the next. If a future investigation wants to push harder
(more threads/rounds, or a repro that also exercises `CDM_ReferenceIterator`/cross-document
references to hit `DocumentVersion()`), that's the next place to look.
