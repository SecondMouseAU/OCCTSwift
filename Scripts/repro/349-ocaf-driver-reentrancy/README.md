# OCCTSwift#349 reproducer, `BinLDrivers_DocumentStorageDriver`/`PCDM_Reader` driver reentrancy

Root-cause writeup for the SIGSEGV(s) seen in `OCAFSaveLoadBinaryTests.saveLoadBinOcaf()`
(`Tests/OCCTXCAFTests`), found during validation of the #344 fix, and mitigated on the bridge
side in v1.15.6 via `ocafStoreMutex()` (`Sources/OCCTBridge/src/OCCTBridge_Document.mm`).

## Verdict

**Real, previously-undetected kernel defect, fixed.** `CDF_Application::WriterFromFormat`/
`ReaderFromFormat` create a storage/retrieval driver instance **once per format** and cache it in
`myWriters`/`myReaders` (that map's own concurrent-access bug was #344, already fixed:
`myReadersWritersMutex`). Every subsequent `Store()`/`Retrieve()` call for that format is handed
back the **same cached driver instance**, including from different threads, different documents,
concurrently. But `PCDM_StorageDriver`/`PCDM_Reader` subclasses (`BinLDrivers_DocumentStorageDriver`
et al.) are not reentrant: `Write()`/`Read()` use **instance-level scratch state**, for
`BinLDrivers_DocumentStorageDriver` alone: `myRelocTable`, `myTypesMap`, `myPAtt`, `myEmptyLabels`,
`myMapUnsupported`, `mySizesToWrite`, `myFileName`, `myMsgDriver`, the lazily-initialized
`myDrivers` table, plus the base class's `myIsError`/`myStoreStatus`, that gets clobbered when two
threads call `Write()` on the same shared instance concurrently.

OCCT's own code already shows awareness that this instance gets used from multiple threads,
`CDF_StoreList::Store` resets the store status right before calling `Write()` with the comment
*"It has sense in multi-threaded access to the storage driver - this way we reset the status for
each call"*, but that's the only piece of state the original code accounts for; every other
member is untouched and races freely.

**XmlLDrivers/other-format siblings are affected too, structurally, not just BinLDrivers**:
`XmlLDrivers_DocumentStorageDriver`, `BinXCAFDrivers`/`XmlXCAFDrivers` variants, and the `TObj`
driver family all extend the same `PCDM_StorageDriver`/`PCDM_RetrievalDriver` base classes and
follow the identical per-instance-scratch-state pattern for their own `Write()`/`Read()`
overrides, the defect is in the base-class contract (a stateful, single-use-at-a-time driver
object cached and shared by `CDF_Application`), not specific to the binary OCAF format.

## Repro

`occt_349_barrier.cpp`: N threads each build their own small `TDocStd_Document` (own file, own
label tree, a **different** document/file per (thread, round), deliberately not a path
collision, to isolate the driver-reentrancy defect from unrelated file I/O races), spin-wait at a
barrier, then call `TDocStd_Application::SaveAs()` on the same shared `TDocStd_Application`
(hence the same cached `BinLDrivers_DocumentStorageDriver` instance for the `"BinOcaf"` format)
at nearly the same instant, maximizing genuine simultaneous contention on the shared driver
instead of relying on OS scheduling luck (same technique as
`Scripts/repro/344-cdf-directory/occt_344_barrier.cpp`). This bypasses OCCTSwift's own
`ocafStoreMutex()` bridge mitigation on purpose (that mutex doesn't exist in the kernel itself,
and this repro targets the kernel defect it's masking).

```bash
clang++ -std=c++17 -O0 -g \
  -I Libraries/OCCT.xcframework/macos-arm64/Headers \
  -L Libraries/OCCT.xcframework/macos-arm64 \
  occt_349_barrier.cpp -o occt_349_barrier \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++

MMGT_OPT=0 ./occt_349_barrier 2 2000 /tmp/occt349_scratch
```

**Crashes reliably against the stock (unpatched) shipped xcframework**: even with just **2**
threads × 2000 rounds (typically within the first few hundred rounds); 10 threads × 300 rounds
crashes on the very first round nearly every time. A clean 2-thread run isolates a single
backtrace (both threads crash from the same corrupted state, one caught, one already fatal):

```
BinMDF_ADriverTable::AssignIds(myTypesMap)      <- NCollection_BaseMap::Destroy (SIGSEGV)
BinLDrivers_DocumentStorageDriver::Write(stream)  (line 99: FirstPass -> myDrivers->AssignIds)
BinLDrivers_DocumentStorageDriver::Write(file)
CDF_StoreList::Store
CDF_Store::Realize
TDocStd_Application::SaveAs
```

i.e. exactly the call chain from the #349 issue, with the concrete corruption site: two
concurrent `Write()` calls both clearing/rebuilding `myTypesMap`
(`BinLDrivers_DocumentStorageDriver::FirstPass`, `.cxx:412-423`) out from under each other, so
`BinMDF_ADriverTable::AssignIds` (called with one thread's now-stale/half-cleared map) walks
freed/invalid `NCollection_IndexedMap` internal storage.

## TSan confirmation

Built against the project's existing minimal-module TSan install
(`FoundationClasses`+`ModelingData`+`ModelingAlgorithms`+`DataExchange`, `RelWithDebInfo`,
`-fsanitize=thread -g`, matching the #298/#319/#341/#344 protocol):

```bash
clang++ -std=c++17 -fsanitize=thread -g -O1 \
  -I <tsan-install>/include/opencascade -L <tsan-install>/lib \
  occt_349_barrier.cpp -o occt_349_tsan \
  $(ls <tsan-install>/lib/libTK*.a | xargs -n1 basename | sed 's/^lib//;s/\.a$//;s/^/-l/') \
  -lz -lc++ -framework Foundation

MMGT_OPT=0 TSAN_OPTIONS="halt_on_error=0" ./occt_349_tsan 8 25 /tmp/occt349_tsan_scratch
```

**Before the fix**: 136 distinct TSan race warnings in one run (8 threads × 25 rounds), the
process itself still SIGSEGVs (exit 139) partway through. Every non-`CDF_Directory`/`pthread_create`
report resolves into `BinLDrivers_DocumentStorageDriver::Write`/`FirstPass`/`FirstPassSubTree`/
`WriteSubTree`/`WriteInfoSection`, `PCDM_StorageDriver::SetIsError`/`SetStoreStatus`,
`BinMDF_ADriverTable::GetDriver`/`AssignIds`/`AddDerivedDriver`, and their `NCollection_BaseMap`/
`NCollection_IndexedMap`/`NCollection_BaseList` internals, confirming the whole per-call scratch
surface (not just one field) races, consistent with the "entire driver object is scratch state"
root cause above. (`CDF_Directory::Add` reports are the separate, already-fixed #344 defect,
this TSan install predates the #344 kernel patch, so it reproduces alongside ours; not relevant
here.)

**After the fix**: 0 races, 0 crashes, see "Fix" below for exact numbers.

## Fix

`Scripts/patches/0014-CDF-driver-reentrancy-mutex-349.patch`. Considered the two options from the
issue:

- **(a) coarser mutex serializing driver dispatch**: chosen.
- **(b) deeper reentrancy fix removing shared scratch state from the driver**: investigated and
  rejected as impractical here, unlike prior #298/#319/#341/#344 fixes. Those each had a small,
  well-bounded piece of shared state (one static bool, one list, one lazy-init handle). Here, TSan
  shows essentially the *entire* `BinLDrivers_DocumentStorageDriver` object is scratch state for
  the duration of one `Write()` call, by design (eight-plus members: `myRelocTable`, `myTypesMap`,
  `myPAtt`, `myEmptyLabels`, `myMapUnsupported`, `mySizesToWrite`, `myFileName`, `myDrivers`),
  *and* a nested shared object (`BinMDF_ADriverTable`) has its own internal mutation during
  `Write()` (`AddDerivedDriver`/`AssignIds`). Converting all of this to true per-call-local state
  would mean threading new parameters through every private helper (`FirstPass`,
  `FirstPassSubTree`, `WriteSubTree`, `WriteInfoSection`, `WriteShapeSection`, `WriteSizes`,
  `UnsupportedAttrMsg`), a sweeping signature change that every format's storage/retrieval driver
  subclass (`XmlLDrivers`, `BinXCAFDrivers`, `XmlXCAFDrivers`, `TObj` variants) would also need,
  for a change with high regression risk and far outside "minimal, surgical" for an upstream PR.

The mutex is placed on the **shared resource itself** (the cached driver instance), not as one
big lock around unrelated code:

1. `PCDM_StorageDriver` gets a `mutable std::mutex myMutex` + `Mutex()` accessor; `PCDM_Reader`
   (not `PCDM_RetrievalDriver`, `CDF_Application::ReaderFromFormat`/the two `Read()` call sites
   use the `PCDM_Reader` static type) gets the same. Every format's driver subclass inherits it
   for free, no changes needed to `BinLDrivers`/`XmlLDrivers`/`BinXCAFDrivers`/`XmlXCAFDrivers`/
   `TObj` drivers themselves.
2. The three places `CDF_Application`/`CDF_StoreList` actually invoke a cached, possibly-shared
   driver's `Write()`/`Read()` now hold that driver's own mutex for the call:
   `CDF_StoreList::Store` (around `SetStoreStatus`+`Write`), `CDF_Application::Retrieve` (around
   `Read`), `CDF_Application::Read` (around `Read`).

This directly targets the actual shared resource (the cached driver instance), matches the file's
own pre-existing "multi-threaded access to the storage driver" comment/intent, needs zero changes
in any concrete driver subclass, and doesn't serialize unrelated formats against each other (a
`"BinOcaf"` save and an unrelated `"Xml"` save use different cached driver instances and different
mutexes).

**Validation**: rebuilt the minimal-module TSan install with the patch applied
(`occt-build-tsan349`/`occt-install-tsan349`, same module set as above) and re-ran
`occt_349_tsan`:

- TSan race warnings: 136 → **0** (8×25), confirmed again at 10×200 (larger stress) → **0**.
- Process exit / crash: SIGSEGV (exit 139) → **clean exit** across N repeated runs (see numbers
  below).
- The pre-existing `CDF_Directory::Add` races (unrelated #344 defect, absent from this TSan
  install) are untouched by this patch, expected, out of scope.

Filed upstream as Open-Cascade-SAS/OCCT#<TBD> (repro) / #<TBD> (fix), not yet filed as of this
writeup; see the parent issue (#349) for filing status.

## New finding surfaced by this fix (NOT fixed here, follow-up)

Post-patch TSan runs (8×25 through 10×60) are **clean of every original #349 symptom**, but
consistently surface exactly **one** different, previously-masked race (same "fixing one race
exposes the next" pattern as #344's own history):

```
CDM_MetaData::IsRetrieved() const          (CDM_MetaData.cxx:69, read)
  <- CDM_Document::SetMetaData()           (CDM_Document.cxx:487)
    <- CDF_StoreList::Store()              (CDF_StoreList.cxx:153, AFTER our new driver lock is released)
races against
CDM_MetaData::UnsetDocument()              (CDM_MetaData.cxx:85, write)
  <- ~CDM_Document() <- ~TDocStd_Document()  (another thread's document being destroyed)
```

Root cause (read from source, not yet TSan-line-verified beyond the report above):
`CDM_Application::myMetaDataLookUpTable` (`CDM_Application.hxx:97`) is a plain
`NCollection_DataMap<TCollection_ExtendedString, occ::handle<CDM_MetaData>>`, **one instance per
`CDM_Application`/`CDF_Application`**, with zero synchronization, every `CDF_StoreList::Store()`/
`CDF_FWOSDriver::CreateMetaData()`/`CDM_MetaData::LookUp()` call across every thread sharing that
one `TDocStd_Application` reads/writes the same map and the `CDM_MetaData` objects it hands out.
Same failure class as `CDF_Directory::myDocuments` (#344) and `theAutoNaming` (#341): a
process/application-shared container mutated with no lock.

**Out of scope for #349** (that issue is specifically the driver `Write()`/`Read()` reentrancy
this patch fixes), not fixed here. `occt_349_barrier`'s repro already isolates it cleanly if a
future issue wants to pick it up: run 8-10 threads for 25-60+ rounds against the *patched* build
and it reproduces every time (1 warning per run, no crash observed from this one alone within the
runs performed here, unlike the #349 defect it was hiding behind). Recommend filing as a new
issue rather than folding into #349's scope.

## Bridge mitigation

`Sources/OCCTBridge/src/OCCTBridge_Document.mm`'s `ocafStoreMutex()` (serializing
`OCCTDocumentSaveOCAF`/`OCCTDocumentSaveOCAFInPlace`/`OCCTDocumentLoadOCAF`, shipped v1.15.6)
**stays** regardless of this kernel fix, same PR1→PR2 pattern as #298/#341/#344. It's coarser
than necessary now (it serializes ALL OCAF save/load through one bridge-wide mutex, not just
same-format contention), but removing it is a separate, lower-priority follow-up once the kernel
fix has shipped in a released xcframework for a while; not done here per the task's explicit
instruction to leave it in place.
