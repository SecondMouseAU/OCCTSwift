# Carried OCCT source patches

Patches in this directory are upstream-bound OCCT bug fixes we carry until they ship in an OCCT
release. `Scripts/build-occt.sh` applies each one (idempotently, `-p1`, `a/`,`b/` prefixes) to
`Libraries/occt-src` before every cmake build. A patch takes effect only when the xcframework is
**rebuilt** from source, the binary shipped in `Libraries/OCCT.xcframework` does not yet include it
until a rebuild + release. See ["Shipping a rebuild"](../../docs/guides/building-occt.md#shipping-a-rebuild)
for what that takes.

**Adding or retiring a patch means regenerating `Scripts/occt-raise-if-map.txt` in the same PR.**
That map is a committed derivation of this directory's effect on `Libraries/occt-src`, so a patch
that adds or moves an `<Exception>_Raise_if` or a `throw` changes it.
`python3 Scripts/census-compiled-out-validation.py --write-table` rewrites it from the tree
`build-occt.sh` patched, and refuses a tree that does not carry every patch here.
`check-inventory-prose.py` fails when the map's provenance stamp and this directory disagree,
which is what nothing did while `0042` sat in the kernel and not in the map for two pins (#2885).

**Numbers are never reused, with one recorded exception.** Re-pinning to OCCT `V8_0_1` on
2026-08-03 retired ten patches, `0032`
retired 2026-09-02 (superseded by upstream's own fix, not shipped in our pin), and `0035` retired
2026-09-20 (it reintroduced #280; see its [Retired patches](#retired-patches) entry).
The carried sequence now reads 0010–0012, 0014–0031, 0033–0034, 0036–0048, 0050–0060.
The gaps are the retirements, not missing files:
the numbers are cited across `CLAUDE.md`, `docs/`, closed issues and `Scripts/repro/`, and
renumbering would have silently repointed every one of those citations at a different fix.
[Retired patches](#retired-patches) below keeps each one's writeup, with the equivalence check that
justified deleting the file.

**The exception is `0034`, and it is the reason the rule is worth stating.**
`0034-LocOpe_SplitDrafts-trim-infinite-pipe-curves-1393.patch` held the number from 2026-09-07
(`19d2f12f`) to 2026-09-08 (`be2d0d77`), and
`0034-GeomFill-CoonsAlgPatch-Value-U-parameter-1515.patch` took it on 2026-09-19 (`f1625673`). It
was reused because the first `0034` lasted a day and left no citation behind, which is a defensible
call and still a reuse. The cost showed up in
[#2190](https://github.com/SecondMouseAU/OCCTSwift/issues/2190): the pinned asset carries the
retired one, and "the asset has 0034" is now ambiguous between a patch we carry and a patch we
deleted. `Scripts/check-pinned-asset-patches.py` keys that retired patch `0034-LocOpe` for exactly
this reason. **Do not reuse a number again, however short the number's life was**, and if you
somehow must, record it here the way this paragraph does.

## 0010-Intf_Interference-O1-tangent-zone-checkpoint-breaker-319.patch

**Fixes the upstream OCCT hang behind [#319](https://github.com/SecondMouseAU/OCCTSwift/issues/319)**: `isSelfIntersecting`'s `hardTimeout:` bound could not actually interrupt the self-interference search on a pathological artifact, running 619s+ of CPU (and observed to run far longer, uninterrupted) against a 30s deadline. Reported upstream as [Open-Cascade-SAS/OCCT#1385](https://github.com/Open-Cascade-SAS/OCCT/issues/1385) (reproducer at
[`Scripts/repro/319-selfintersection`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/319-selfintersection)), fix as [OCCT#1386](https://github.com/Open-Cascade-SAS/OCCT/pull/1386) (CI green on all 3 platforms, ready for review).

Two independent, compounding defects in `BOPAlgo_ArgumentAnalyzer`'s self-interference phase (`BOPAlgo_CheckerSI::CheckFaceSelfIntersection` → `IntTools_FaceFace::Perform` → `Intf_Interference::Insert`):

1. **O(n)-per-call point access.** `Intf_Interference::Insert` compares points between the new tangent zone and every existing zone via `Intf_TangentZone::GetPoint(Index)`, called inside a doubly-nested loop. `GetPoint` indexes the zone's backing `NCollection_Sequence`, a linked list with no O(1) random access, so each call walks from the nearest end. Profiling the pathological artifact (both independently and cross-checked against a second session's report) attributed ~80% of leaf samples to `NCollection_BaseSequence::Find`. The artifact's geometry produces an unboundedly growing *number* of distinct tangent zones, not one giant merging zone, so this alone is an O(1)-per-lookup fix to an inherently expensive matching structure, it helps, but does not bound wall-clock time.
2. **No checkpoint below `CheckFaceSelfIntersection`.** The self-interference phase never polled its cooperative progress indicator (OCCT's usual `Message_ProgressRange`/`UserBreak()` idiom) anywhere inside a single face's check, only *between* whole-face checks. A caller's timeout could therefore only fire in the gaps between faces, not while stuck inside one, which is exactly where the artifact spends its time.

**Fix:** (1) `Intf_TangentZone::Points()` builds and caches a true `NCollection_Array1` per zone in one linear pass on first use, invalidated by any mutation (`Append`/`InsertAfter`/`InsertBefore`); `Insert()` now indexes through the cached array instead of calling `GetPoint` in the nested loop, same comparisons, same result, O(1) lookup. (2) `Intf_Interference::SetBreaker` (a thread-local, RAII-scoped via `Intf_InterferenceBreakerScope`) lets `Insert()` poll a `Message_ProgressScope` every 256 calls (not every call, to avoid taxing the common case) and abort by throwing `Standard_Failure`, unwinding the deep `IntTools_FaceFace`/`Intf_Interference` call stack safely. `BOPAlgo_CheckerSI`'s self-intersect functor wires this up around `IntTools_FaceFace::Perform`, gated on `!myRunParallel`, an exception thrown from a worker thread of `OSD_Parallel::For`'s parallel path would be unsafe (risks `std::terminate()`), so the checkpoint is only active on the single-threaded path.

**Validation:** verified on the linked artifact, with both fixes, a 0.5s deadline returns in 0.547s and a 30s deadline returns in 30.1s (vs. 619s+ CPU / never returning on stock p1), with correct `HasFaulty()` results at every deadline tested (0.5s/1s/2s/3s/5s/30s), clean across a 10x repeated-run stress test. Zero regression on clean, overlapping, and grid self-intersection sanity cases (byte-identical `HasFaulty()`/point output). An empty-zone edge case (`Intf_TangentZone::Points()` on a zone with zero points) is guarded explicitly, `NCollection_Array1::Resize(1, 0, false)` throws `Standard_RangeError` for an empty range, caught by a dedicated GTest before it could reach a real caller. New upstream GTests `Intf_TangentZone_Test.cxx` (`Points()` correctness and cache invalidation, including the empty-zone case) and `Intf_Interference_Test.cxx` (breaker aborts `Insert()` promptly; a non-tripping or absent breaker leaves behavior unchanged) pass on Linux/Windows/macOS in OCCT's own CI, alongside the full regression/GTest/build matrix, all green on the first PR submission.

**Retire** once the bundled OCCT includes this fix.

## 0011-XCAFDoc_ShapeTool-AutoNamingScope-341.patch

**Fixes the upstream OCCT thread-safety defect behind [#341](https://github.com/SecondMouseAU/OCCTSwift/issues/341)**: concurrent OBJ/glTF import or PLY/OBJ/glTF export races on `XCAFDoc_ShapeTool`'s global auto-naming mode.

`XCAFDoc_ShapeTool::theAutoNaming` is a file-scope `static bool`, a single process-wide setting, by design (the header says so explicitly: "This setting is global; it cannot be made a member function"). Three independent call sites do the same unsynchronized save/modify/restore dance around it: `RWMesh_CafReader::fillDocument()` (shared base of `RWObj_CafReader` and `RWGltf_CafReader`, OBJ **and** glTF import both hit this), `RWGltf_CafReader::fillDocument()` (a *separate*, near-duplicate override, not a call into the base class's version), and `XCAFDoc_Editor::Expand()` (which additionally recurses into itself while the dance is still in flight). `XCAFDoc_ShapeTool::AddShape`/`addShape` reads the same flag internally to decide whether to auto-generate a name.

ThreadSanitizer on an 8-10 thread concurrent-OBJ-round-trip stress (each thread its own uniquely-named file, V8_0_0_p1 + patches `0001`–`0010`) reports 9-17 races per run, `SetAutoNaming`/`AutoNaming`/`addShape`'s internal read, all on `theAutoNaming`, confirming two distinct problems: (1) two threads' save/modify/restore critical sections can interleave, so one thread's restore stomps another's still-in-progress override (a *logical* bug: the wrong auto-naming mode is active for part of a build, independent of memory safety); (2) `theAutoNaming` itself is a plain `bool` read and written with no synchronization from *any* caller, including ordinary `AddShape` calls made outside any of the three save/restore call sites above, a genuine data race (undefined behavior) on every access, not just inside the three call sites.

**Fix, both layers.** `XCAFDoc_ShapeTool::AutoNamingScope` is a new RAII helper (`AutoNamingScope(bool)` constructor / destructor) that holds a `std::recursive_mutex` for its *entire* lifetime, not just around the individual get/set calls, so two threads' save-modify-restore sequences serialize against each other instead of interleaving (recursive because `XCAFDoc_Editor::Expand()` needs to reenter it on the same thread). All three call sites now use it instead of a bare `AutoNaming()`/`SetAutoNaming()` pair, collapsing `XCAFDoc_Editor::Expand()`'s two duplicate manual-restore-before-return sites into one destructor-driven restore that fires on every exit path. Separately, `theAutoNaming` itself is now `std::atomic<bool>` instead of a plain `bool`, so *every* access anywhere in the file, including `AddShape`'s internal read, which participates in none of the three scoped sections, is well-defined and TSan-clean, closing the residual gap the mutex alone doesn't reach (an unscoped `AddShape` call has no scope to be excluded by; it was never going to get a *stable* value while another thread's scope is active, since the flag is deliberately global, but it must at least get a *real*, non-torn one).

**Validation:** the same TSan stress (10 threads × 200 iterations, 2000 concurrent OBJ round-trips) reports **zero** `XCAFDoc_ShapeTool` races after the patch, across 4 separate runs, only the already-known, unrelated `Message_PrinterOStream`/`std::cout` console-write race remains (OCCT's default messenger has no internal locking; cosmetic, not fixed here). Regression-clean on the `create_fillet_boolean` (#298) and `mesh_independent` scenarios, only the already-known benign `BOPAlgo_InitMessages` lazy-init race, unchanged. `RWGltf_CafReader`'s copy of the fix could not be exercised under TSan directly (this repo's minimal-module TSan build excludes `TKDEGLTF`, it requires RapidJSON, disabled for the faster build) but compiles cleanly and is mechanically identical to the `RWMesh_CafReader`/`RWObj_CafReader` path that *was* verified.

Superseded the interim bridge-side mitigation (`meshCafMutex()` in `OCCTBridge_IO.mm`, shipped v1.15.4), removed once this kernel patch made the underlying OCCT calls safe on their own.

Reported and isolated at SecondMouseAU/OCCTSwift#341; filed upstream as [Open-Cascade-SAS/OCCT#1387](https://github.com/Open-Cascade-SAS/OCCT/issues/1387) (repro), fix as [OCCT#1388](https://github.com/Open-Cascade-SAS/OCCT/pull/1388).

**Revised (SecondMouseAU/OCCTSwift#363), patch content above updated in place, not a new patch
number.** Upstream reviewer gkv311 caught something this writeup's own "closing the residual gap"
framing above got wrong: the mutex only serialized the three known override call sites against each
other, not the many *other* reads of `theAutoNaming` scattered through `XCAFDoc_ShapeTool.cxx`
(`AddShape`, `MakeReference`, `SetSHUO`), those stayed outside any scope, so an unrelated unscoped
caller on another thread could still observe another thread's temporary override. The atomic
conversion made that access memory-safe; it did not make the override *behavior* correct for callers
outside the three scoped sites. The "the flag is deliberately global" framing above was itself the
mistake: `theAutoNaming` was never meant to express per-document intent, the three overriding call
sites each want to suppress naming for their own document's build, not change a process-wide
setting, and `XCAFDoc_ShapeTool` is already one instance per document. The override belongs there.

**Fixed properly this time.** `XCAFDoc_ShapeTool::OwnAutoNamingScope` replaces `AutoNamingScope`,
saving/restoring a per-instance `myOwnAutonaming` field (`-1` inherits the process-wide default,
`0`/`1` is a local override) instead of the shared flag. No locking needed at all, two threads
working on two different documents (two different `ShapeTool` instances) never touch each other's
state. `AddShape`/`MakeReference`/`SetSHUO` now read a new `OwnAutoNaming()` accessor instead of
`theAutoNaming` directly; `MakeReference` is no longer `static`, since it now reads instance state.
One subtlety a naive port of gkv311's one-line sketch would have missed: `XCAFDoc_Editor::Expand()`
recurses into itself on the same document, so a bare `SetOwnAutoNaming()`/`UnsetOwnAutoNaming()`
pair at entry/exit would clobber an outer call's still-active override mid-recursion (the inner
call's unconditional "reset to inherit global" would win). `OwnAutoNamingScope` does a proper
save/restore of whatever override state the instance had on entry, so nested scopes on the same
instance compose correctly, same reentrancy guarantee the old `recursive_mutex` gave, achieved here
by symmetric save/restore instead of a lock. `theAutoNaming` itself stays `std::atomic<bool>`,
`SetAutoNaming()`/`AutoNaming()` remain callable concurrently from any thread at any time,
independent of any instance's own override.

**Re-validated:** the same TSan stress (10 threads × 200 iterations, `obj_roundtrip_unique`) reports
zero `theAutoNaming` races, matching the prior result. New scenario
(`Scripts/repro/363-own-autonaming/occt_363_isolation.cpp`, `isolation` mode) directly checks the
property the mutex fix couldn't guarantee: half the threads locally override via
`OwnAutoNamingScope` on their own document while the other half do plain unscoped `AddShape()` on
independent documents relying on the process-wide default, concurrently, 3000 operations, zero
instances of the unscoped threads observing another thread's override.

Upstream PR #1388 updated to the new design; CI green on all 3 platforms (build/GTest/regression/
test), all originally-green checks stayed green.

**Retire** once the bundled OCCT includes this fix.

## 0012-CDF_Directory-XCAFApp_Application-thread-safety-344.patch

**Fixes the upstream OCCT crash behind [#344](https://github.com/SecondMouseAU/OCCTSwift/issues/344)**: an uncatchable SIGSEGV seen in ~1-in-10 parallel `swift test` runs right after two concurrent OBJ mesh imports, confirmed to survive the #341 kernel fix (theAutoNaming) in v1.15.5.

Two independent, previously-undetected races, both in code the #341 TSan stress never reached, that harness (`Scripts/repro/341-meshcaf/occt_341_stress.cpp`) builds its `TDocStd_Document` directly (`new TDocStd_Document("BinXCAF")`), bypassing `XCAFApp_Application`/`CDF_Application` entirely. The real bridge path (`OCCTDocumentLoadOBJ` and every other document-producing bridge call) does not: all of them go through `XCAFApp_Application::GetApplication()->NewDocument(...)`.

1. **`XCAFApp_Application::GetApplication()`**: a textbook double-checked-locking-without-locking bug: `static Handle(XCAFApp_Application) locApp; if (locApp.IsNull()) { locApp = new XCAFApp_Application; }`. Two threads' first concurrent call can both observe `IsNull()` and both construct a new instance, racing to assign the shared `locApp` handle. This is the dominant defect: TSan shows it produces **multiple concurrently constructed `XCAFApp_Application` instances**, whose "losing" copies are then torn down while other threads are still constructing/using a same-generation object, cascading into races across dozens of unrelated destructors (`TDF_LabelNode::Destroy`, `TCollection_ExtendedString::~`, `CDM_Document::~CDM_Document`, `NCollection_BaseList::PClear`, ...) and several ctor/dtor-vs-virtual-call ("vptr") reports, not just a leaked handle.
2. **`CDF_Directory::Add`/`Remove`/`Contains`**: every `XCAFApp_Application`/`CDF_Application` instance is normally shared process-wide (the entire point of `GetApplication()`), so its one `CDF_Directory` receives `Add()` from every document-creating call on every thread. `myDocuments` is a plain `NCollection_List` with zero synchronization: `NCollection_BaseList::PAppend` mutates `myFirst`/`myLast`/`myLength` with no locking at all. Confirmed independently by TSan (`CDF_Directory.cxx:30`, `NCollection_BaseList.cxx:45/52/53`) even setting aside race #1.

The bridge never calls `Application->Close()` on a document (no call site in `Sources/OCCTBridge`), so `CDF_Directory::Remove` is never reached from OCCTSwift, every document ever created via the bridge accumulates in `myDocuments` for the life of the process. That's a separate, pre-existing leak, not fixed here (out of scope for #344).

**Fix, both layers:**

1. `XCAFApp_Application::GetApplication()`: fold construction into the static local's initializer, a C++11 "magic static" is thread-safe exactly once, unlike the previous separate `IsNull()`-guarded assignment.
2. `CDF_Directory`: a private `mutable std::mutex myMutex` guards `Add`/`Remove`/`Contains`/`Length`/`IsEmpty`/`Last`. `Add()` inlines the containment scan instead of calling the public `Contains()`, to avoid a self-deadlock on the (non-recursive) mutex. `List()`, used only by the friend `CDF_DirectoryIterator`, which nothing in OCCTSwift's bridge uses, is intentionally left unguarded; closing that gap would need a bigger API change (a snapshot copy) out of proportion to the two confirmed, reachable races this patch fixes.

**Validation:** a debug (`-O0 -g`) build with a temporary `SIGSEGV`/`SIGBUS` signal handler (`backtrace_symbols_fd`, per the `feedback-lldb-blocked-use-signal-handler` technique) crashes ~50% of runs at 10 threads × 3000 barrier-synchronized rounds on stock p1, resolving to `TDocStd_Application::NewDocument -> CDF_Application::Open` both times, matching the `CDF_Directory::Add`/`PAppend` corruption mechanism. TSan (minimal-module build, same protocol as #298/#319/#341): stock p1 reports 234 races at 8 threads × 200 free-running iterations; the patch reduces this to 9, all directly in `CDF_Directory::Add`/`PAppend` and all showing the *same* mutex held on both sides of the reported conflict (`mutexes: write M0` on both the read and the write), a pattern consistent with a TSan/allocator-recycling artifact rather than a genuine unaddressed race (a control program with a trivially-correct `std::lock_guard` pattern under the identical TSan flags reports no such warning). The entire `GetApplication()`-driven destructor cascade, dozens of unique signatures pre-fix, is gone entirely.

**Second part, found during validation.** Fixing `GetApplication()`'s race means every caller now genuinely shares ONE `TDocStd_Application` instance (as intended), which surfaced further races on that *same* instance's other unsynchronized state, previously masked by threads sometimes getting different (uncontended) instances of their own. Repeated `swift test` runs (validating the fix above) hit two more crashes in `Tests/OCCTXCAFTests`, both resolving to state on the same shared singleton:

3. **`TDocStd_Application::Resources()`**: the identical lazy-init race pattern as `GetApplication()`: `if (myResources.IsNull()) { myResources = new Resource_Manager(...); }`, no locking.
4. **`Resource_Manager`'s own maps** (`myRefMap`/`myUserMap`/`myExtStrMap`), no synchronization at all. Caught live: a SIGTRAP inside `Resource_Manager::SetResource`, called from `TDocStd_Application::DefineFormat` (itself called by `Document.defineAllFormats()`, a common per-test setup call many parallel XCAF tests invoke concurrently).
5. **`CDF_Application::myReaders`/`myWriters`** (format-name → driver maps), read/written from `DefineFormat`, `ReaderFromFormat`/`WriterFromFormat`, and `ReadingFormats`/`WritingFormats` with no locking. Caught live: a SIGSEGV inside `TDocStd_Application::ReadingFormats` iterating `myReaders` while another thread's `DefineFormat` mutated it concurrently.

**Fix, continued:** a mutex guards `Resources()`'s lazy-init (same pattern as fix 1); a `std::recursive_mutex` guards `Resource_Manager`'s public accessors (recursive because `Integer()`/`Real()`/`ExtValue()` call `Value()` internally, and the `int`/`double` `SetResource()` overloads call the `char*` one), `GetMap()`, a raw-reference escape hatch with no callers in this area, is left unguarded, same rationale as `CDF_Directory::List()`; a mutex guards `CDF_Application::myReaders`/`myWriters` across every access point. The new `Resource_Manager` mutex member makes the class non-copyable by default, breaking `ShapeProcess_Context.cxx`'s existing (pre-existing, unrelated) `new Resource_Manager(*sRC)` thread-safety workaround (its own comment: *"Creating copy of sRC for thread safety of Resource_Manager variables... calling of SetResource() for one object in multiple threads causes race condition"*, OCCT's own prior acknowledgement of this exact defect, worked around locally rather than fixed at the source), added an explicit copy constructor that copies the maps under the source's lock and default-constructs a fresh mutex for the new instance.

**Validation, continued:** SIGTRAP (`Resource_Manager::SetResource`) and SIGSEGV (`TDocStd_Application::ReadingFormats`) both reproducible before this part of the patch; 0/12 further `swift test` runs of `OCCTXCAFTests` reproduce either after it.

A third, separate crash surfaced during this same validation (`BinLDrivers_DocumentStorageDriver::Write`/`WriteSubTree` corrupting a *shared, cached, non-reentrant storage-driver instance* under concurrent `Save`/`SaveAs` of the same format), architecturally different (a shared worker object, not a container needing a lock) and **not fixed here**; filed separately as SecondMouseAU/OCCTSwift#349 for its own dedicated investigation.

See [`Scripts/repro/344-cdf-directory/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/344-cdf-directory) for the reproducers and full writeup. Filed upstream as [Open-Cascade-SAS/OCCT#1389](https://github.com/Open-Cascade-SAS/OCCT/issues/1389) (repro) / [OCCT#1390](https://github.com/Open-Cascade-SAS/OCCT/pull/1390) (fix, two commits).

**Retire** once the bundled OCCT includes this fix.

## 0014-CDF-driver-reentrancy-mutex-349.patch

**Fixes the upstream OCCT crash behind [#349](https://github.com/SecondMouseAU/OCCTSwift/issues/349)**: an uncatchable SIGSEGV under concurrent `Save`/`SaveAs` of the same document format, surfaced during validation of the #344 fix (the third, architecturally distinct crash found in that pass, deliberately not folded into patch 0012).

`CDF_Application::WriterFromFormat`/`ReaderFromFormat` cache one storage/retrieval driver instance per format (`myWriters`/`myReaders`, the map itself already made safe by #344) and hand the *same* cached instance back to every subsequent `Store()`/`Retrieve()` call for that format, including from different threads, different documents, concurrently. But `PCDM_StorageDriver`/`PCDM_Reader` subclasses (`BinLDrivers_DocumentStorageDriver` et al.) are not reentrant: `Write()`/`Read()` mutate instance-level scratch state, for `BinLDrivers_DocumentStorageDriver` alone: `myRelocTable`, `myTypesMap`, `myPAtt`, `myEmptyLabels`, `myMapUnsupported`, `mySizesToWrite`, `myFileName`, `myMsgDriver`, the lazily-initialized `myDrivers` table, plus the base class's `myIsError`/`myStoreStatus`, that gets clobbered when two threads call `Write()` on the same shared instance concurrently. `CDF_StoreList::Store`'s own comment already shows awareness the driver is shared across threads ("It has sense in multi-threaded access to the storage driver..."), but only the store-status was ever made safe; every other member raced freely. Structural, not BinLDrivers-specific: `XmlLDrivers`, `BinXCAFDrivers`/`XmlXCAFDrivers`, and `TObj` drivers all extend the same base classes and follow the identical per-instance-scratch-state pattern.

Confirmed via a debug (`-O0 -g`) build with a temporary SIGSEGV/SIGBUS signal handler: two threads racing `TDocStd_Application::SaveAs()` on a shared application crash reliably (within a few hundred rounds at just 2 threads), resolving to `BinMDF_ADriverTable::AssignIds(myTypesMap) <- NCollection_BaseMap::Destroy`, reached via `BinLDrivers_DocumentStorageDriver::Write -> FirstPass -> CDF_StoreList::Store -> CDF_Store::Realize -> TDocStd_Application::SaveAs`, two concurrent `Write()` calls both clearing/rebuilding `myTypesMap` out from under each other. TSan (minimal-module build, same protocol as #298/#319/#341/#344) confirms it directly: 136 distinct race warnings in one run (8 threads × 25 rounds), process itself still SIGSEGVs (exit 139) partway through, every non-unrelated report resolves into `BinLDrivers_DocumentStorageDriver::Write`/`FirstPass`/`FirstPassSubTree`/`WriteSubTree`/`WriteInfoSection`, `PCDM_StorageDriver::SetIsError`/`SetStoreStatus`, `BinMDF_ADriverTable::GetDriver`/`AssignIds`/`AddDerivedDriver`, and their `NCollection_BaseMap`/`NCollection_IndexedMap`/`NCollection_BaseList` internals, consistent with the whole per-call scratch surface racing, not just one field.

**Fix:** considered the issue's own two options, (a) a coarser mutex serializing driver dispatch, or (b) making the driver's `Write()`/`Read()` genuinely reentrant by eliminating shared scratch state. (b) was investigated and rejected as impractical here (unlike #298/#319/#341/#344, which each had one small, well-bounded piece of shared state): TSan shows essentially the *entire* driver object is scratch state for the duration of one `Write()` call, plus a nested shared object (`BinMDF_ADriverTable`) with its own internal mutation, eliminating it would mean threading new parameters through half a dozen private helpers, a sweeping signature change every format driver subclass would also need, for a change with high regression risk and far outside "minimal, surgical" for an upstream PR. Went with (a), placed on the shared resource itself rather than as one big lock around unrelated code: `PCDM_StorageDriver`/`PCDM_Reader` each get a `mutable std::mutex` + `Mutex()` accessor (every concrete format driver inherits it for free, zero subclass changes needed), held by the three places `CDF_Application`/`CDF_StoreList` actually invoke a cached, possibly-shared driver's `Write()`/`Read()`: `CDF_StoreList::Store`, `CDF_Application::Retrieve`, `CDF_Application::Read`. Doesn't serialize unrelated formats against each other, a `"BinOcaf"` save and an unrelated `"Xml"` save use different cached driver instances and different mutexes.

**Validation:** rebuilt the minimal-module TSan install with the patch applied and re-ran the same stress: race warnings 136 → **0** (confirmed again at a larger 10×200 stress), crash (SIGSEGV, exit 139) → **clean exit** across repeated runs. Full production xcframework rebuilt via `Scripts/build-occt.sh` (all 3 core slices, clean); `swift test --filter OCAFSaveLoadBinaryTests` and `swift test --filter OCCTXCAFTests` (339 tests) both clean, plus **3× full `swift test`** (4423 tests / 1282 suites each) clean, zero failures.

**New finding surfaced by this fix, not fixed here:** post-patch TSan runs consistently surface one different, previously-masked race, same "fixing one race exposes the next" pattern as #344's own history. `CDM_Application::myMetaDataLookUpTable` is a plain `NCollection_DataMap`, one instance per `CDM_Application`/`CDF_Application`, with zero synchronization; every `CDF_StoreList::Store()`/`CDF_FWOSDriver::CreateMetaData()`/`CDM_MetaData::LookUp()` call across every thread sharing that one `TDocStd_Application` reads/writes the same map and the `CDM_MetaData` objects it hands out, same failure class as `CDF_Directory::myDocuments` (#344) and `theAutoNaming` (#341). Out of scope for #349 (specifically the driver reentrancy this patch fixes); filed separately as [SecondMouseAU/OCCTSwift#353](https://github.com/SecondMouseAU/OCCTSwift/issues/353).

**Bridge mitigation:** `Sources/OCCTBridge/src/OCCTBridge_Document.mm`'s `ocafStoreMutex()` (serializing `OCCTDocumentSaveOCAF`/`OCCTDocumentSaveOCAFInPlace`/`OCCTDocumentLoadOCAF`, shipped v1.15.6) **stays** regardless of this kernel fix, same PR1→PR2 pattern as #298/#341/#344. It's coarser than necessary now, but removing it is a separate, lower-priority follow-up once this kernel fix has shipped in a released xcframework for a while.

See [`Scripts/repro/349-ocaf-driver-reentrancy/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/349-ocaf-driver-reentrancy) for the reproducer and full writeup. Filed upstream as [Open-Cascade-SAS/OCCT#1393](https://github.com/Open-Cascade-SAS/OCCT/issues/1393) (repro) / [OCCT#1394](https://github.com/Open-Cascade-SAS/OCCT/pull/1394) (fix, CI green on all platforms).

**Retire** once the bundled OCCT includes this fix.

## 0015-CDM_Application-metadata-lookup-table-mutex-353.patch

**Fixes the upstream OCCT crash behind [#353](https://github.com/SecondMouseAU/OCCTSwift/issues/353)**: a race surfaced while validating the #349 fix (patch 0014, shipped v1.15.9): post-#349-fix TSan runs consistently produced exactly one different, previously-masked warning, matching the "fixing one race exposes the next" pattern from #341→#344→#349.

`CDM_Application::myMetaDataLookUpTable` is a plain `NCollection_DataMap`, one instance per `CDM_Application` (in practice the one process-wide singleton, since #344's `GetApplication()` fix), with zero synchronization anywhere in the class. Three independent things race: (1) **map mutation**, `CDM_MetaData::LookUp()`'s unguarded `IsBound`+`Bind`/`Find`, called from `CDF_FWOSDriver::MetaData`/`CreateMetaData` (every `Store()`/`SaveAs()`), `XmlLDrivers_DocumentRetrievalDriver::Read`, and `PCDM_ReferenceIterator::MetaData`; (2) **map iteration**, `CDM_Document::SetMetaData()` walks the *entire* table on every save, reading every other document's `CDM_MetaData` state; (3) **per-object state**, each `CDM_MetaData`'s `myIsRetrieved`/`myDocument` fields, mutated by `SetDocument()`/`UnsetDocument()` and read by `IsRetrieved()`/`Document()` with no guard at all. TSan confirmed the exact trace quoted in the issue: `CDM_Document::SetMetaData()`'s map-iteration loop (reading `IsRetrieved()`, still inside #349's own per-driver lock, but that lock has no relationship to a *different* thread's document destructor) racing `~CDM_Document() -> CDM_MetaData::UnsetDocument()` tearing down an unrelated document's metadata entry on another thread. 1 confirmed race + SIGABRT (exit 134) on stock #349-fixed kernel, matching the issue's reported symptom exactly.

**Fix:** follows the established "lock the shared resource, don't restructure the subsystem" precedent (#341's atomic bool, #344's `CDF_Directory` mutex, #349's per-driver mutex), the map's "bind once, reuse forever, share across all documents" caching design is load-bearing (how OCCT recognizes "this file is already open" across separate calls), not incidental scratch state. Two independent locks, matching the two distinct race shapes: (1) `CDM_Application` gets a `mutable std::mutex myMetaDataLookUpTableMutex` + accessor, threaded through `CDM_MetaData::LookUp()`'s two overloads (now take the mutex as an explicit parameter) and `CDM_Document::SetMetaData()`'s iteration, `CDF_FWOSDriver`'s constructor also now takes the mutex alongside the table reference it already stored; (2) `CDM_MetaData` gets its own private `mutable std::mutex myDocumentMutex` guarding `myIsRetrieved`/`myDocument`, since two already-bound `CDM_MetaData` objects can race on `SetDocument()`/`UnsetDocument()` vs. `IsRetrieved()`/`Document()` independent of the table lock. No changes to any format-specific driver subclass.

**Validation:** rebuilt the minimal-module TSan install (reused `occt-build-tsan349`/`occt-install-tsan349` from the #349 investigation, which already had patch 0014 baked in) with 0015 applied: race count 1 (+SIGABRT) → **0**, clean exit, across 5 runs (8×25, 10×60, 3×8×40). Full production xcframework rebuilt via `Scripts/build-occt.sh`; `swift test --filter OCAFSaveLoadBinaryTests`/`OCCTXCAFTests` and 3× full `swift test` (4423 tests) all clean.

**Not changed**: `CDM_MetaData::myDocumentVersion` (reached via `CDM_Reference.cxx` and `CDM_Application::SetDocumentVersion`) has the identical unguarded-mutable-field shape as the fixed `myIsRetrieved`/`myDocument`, but on the document-*reference* resolution path rather than save/close, not TSan-observed in any run (the repro doesn't exercise cross-document references), flagged as a plausible sibling for a future pass, not fixed here.

**Upstream formatting note:** OCCT's CI `clang-format` (invoked via their format-check workflow) disagreed with a locally-run `clang-format` (v22.1.8) on two spots, both formatter-alignment artifacts (`AlignConsecutiveAssignments`/declaration alignment shifting due to nearby edits), not intentional changes. Applied CI's own `format.patch` artifact to resolve; the version skew is a tooling quirk, not a real formatting defect. Worth checking CI's format-check output (not just a local dry-run) before every future upstream OCCT PR.

See [`Scripts/repro/353-cdm-metadata-lookup-table/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/353-cdm-metadata-lookup-table) for the reproducer and full writeup. Filed upstream as [Open-Cascade-SAS/OCCT#1396](https://github.com/Open-Cascade-SAS/OCCT/issues/1396) (repro) / [OCCT#1397](https://github.com/Open-Cascade-SAS/OCCT/pull/1397) (fix, CI green on all platforms).

**Retire** once the bundled OCCT includes this fix.

## 0016-Resource_Manager-atomic-Debug-Storage_Schema-per-instance-374.patch

**Fixes the two upstream OCCT races behind [#374](https://github.com/SecondMouseAU/OCCTSwift/issues/374)**, found by the confirmation harness written for [#371](https://github.com/SecondMouseAU/OCCTSwift/issues/371), the bridge-side change that stopped every document sharing one `XCAFApp_Application::GetApplication()` singleton and gave each its own `TDocStd_Application`.

1. **`Resource_Manager::Debug`** (`Resource_Manager.cxx`) is a file-scope `static bool` written on *every* construction, unsynchronized. Each fresh `TDocStd_Application`'s first `DefineFormat()` lazily constructs its own `Resource_Manager` via `Resources()`, and the per-instance lazy-init mutex added by `0012` only serializes repeat calls on the *same* instance, not first-construction across different instances built concurrently.
2. **`Storage_Schema::ICurrentData()`** (`Storage_Schema.cxx`) is a function-local `static Handle(Storage_Data)` with no lock at all. `Write()` (the `SaveAs()` path) sets it for the duration of one store, while *any* `Storage_Schema` construction calls `Clear()` → `ICurrentData().Nullify()`, including the throwaway instances `PCDM_ReadWriter_1::ReadReferenceCounter`/`ReadReferences`/`ReadDocumentVersion` each build on **every** `Open()`, reached unconditionally through `CDF_Application::Retrieve` and not only for documents with cross-references. So an unrelated load nulls out another thread's in-flight save.

Neither had ever appeared in this project's TSan gates: every earlier investigation shared one application instance, so `Resources()`'s lazy-init mutex accidentally serialized both down to "runs once, ever, per process". #371 is what first made them concurrent.

**Fix, part 1:** `Debug` becomes `std::atomic<bool>`. It is a plain process-wide flag, not per-instance intent, so atomic is sufficient here (unlike `0011`/#341's `theAutoNaming`, which needed a per-instance redesign).

**Fix, part 2 (revised, see below):** `ICurrentData()`'s function-local static is deleted and the handle becomes a `mutable occ::handle<Storage_Data> myCurrentData` field on `Storage_Schema`. Nothing is left to lock. `Write()` assigns the field instead of calling `ISetCurrentData()`, `Clear()` nullifies its own, and `HasTypeBinding()`/`BindType()`/`TypeBinding()`/`AddPersistent()`/`PersistentToAdd()` read it through `*this`; the two private statics `ISetCurrentData()` and `ICurrentData()` are removed. `mutable` because every one of those methods is `const`.

The state was never process-wide in the first place: **every** `Storage_Schema` in the tree is constructed locally by its caller and used only there (`PCDM_StorageDriver::Write`, and `PCDM_ReadWriter_1` at three sites), no instance is ever cached or shared, and `Storage_CallBack::Add`/`Write`/`Read` all take the driving schema as an argument, so every callback re-entry lands back on the same instance. `ICurrentData()`/`ISetCurrentData()` were private, so removing them breaks no caller inside or outside the kernel. Other `Storage_Schema` users elsewhere in the tree touch only its statics `CheckTypeMigration()` and `ICreationDate()`, neither of which reads the current data.

**Revised on upstream review ([#518](https://github.com/SecondMouseAU/OCCTSwift/issues/518)).** The first shipped version of part 2 (v1.15.18) took the other route: an `ICurrentDataMutex()` function-local `static std::recursive_mutex&`, held across the constructor's `Clear()`, the whole body of `Write()`, and every internal accessor, recursive because `Write()`'s critical section re-enters `BindType`/`AddPersistent`/`PersistentToAdd` on the same thread through per-type `Storage_CallBack::Write()` callbacks. Memory-safe, but it synchronized access to sharing that should not exist rather than removing it. Maintainer gkv311 pointed that out on [OCCT#1399](https://github.com/Open-Cascade-SAS/OCCT/pull/1399#issuecomment-5112586065) and suggested the field. Same correction, and the same lesson, as `0011`/#341 to #363: a lock is the right tool only when the state is genuinely one shared resource; when it is per-instance data masquerading as a global, relocate the ownership.

The per-instance design is also strictly stronger on the failure #374 actually reported. Under the mutex, a throwaway `Storage_Schema` built by `PCDM_ReadWriter_1` during an unrelated `Open()` still nullified the current data of an in-flight `Write()`, it just did so without a data race; it had to wait its turn, and the save it interfered with had already finished or not yet started. Under the field it cannot reach another instance's data at all. It narrows one thing: the mutex incidentally serialized two threads driving the *same* `Storage_Schema` instance, which the field does not. No caller does that, since no instance is shared.

**Validation:** the "unguarded" variant of #371's confirmation harness (private app per thread/round, no `ocafStoreMutexSim()`) reports 13 races + SIGABRT on stock at 8×30. The mutex version was 0 races across 4 runs (8×30, 8×50, 10×60, 8×40); the per-instance version is 0 races and 0 save/load/verify failures across 8×50, 8×30 and 10×60. Full `Scripts/tsan-stress.sh run` gate (10 scenarios) clean on both, no regression on #341/#344/#349/#353/#371's own scenarios.

See [`Scripts/repro/374-resource-manager-storage-schema-race/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/374-resource-manager-storage-schema-race) for the reproducer and full writeup. Filed upstream as [Open-Cascade-SAS/OCCT#1398](https://github.com/Open-Cascade-SAS/OCCT/issues/1398) (repro, filed during #371) / [OCCT#1399](https://github.com/Open-Cascade-SAS/OCCT/pull/1399) (fix). Both are still open as of 2026-08-07. OCCT#1399 was force-pushed on 2026-07-30 to match this per-instance design, per maintainer review on [that PR](https://github.com/Open-Cascade-SAS/OCCT/pull/1399#issuecomment-5112586065); #518, which tracked that update, is closed.

**Retire** once the bundled OCCT includes this fix.

## 0017-null-reshape-context-ComposeShell-WireDivide-484.patch

**Fixes two upstream OCCT crashes found while auditing the `ShapeFix_Face` call sites in [#484](https://github.com/SecondMouseAU/OCCTSwift/issues/484)**: the same defect class as `0005`/#317 (an unguarded null `ShapeBuild_ReShape` context dereference), in two classes that were never patched or filed.

`ShapeFix_ComposeShell::Perform()`, `ShapeFix_ComposeShell::SplitEdges()` and `ShapeUpgrade_WireDivide::Perform()` dereference `Context()` unconditionally. `Context()` returns `ShapeFix_Root::myContext`, which the base constructor leaves **null** and only an explicit `SetContext()` ever fills, so the ordinary `Init(...)` + `Perform()` pair those classes' public API invites is an immediate null-handle dereference, an uncatchable SIGSEGV at Address 0. No exotic geometry needed: a plain 4-edge planar square face crashes both classes 100% of the time.

Both are the odd ones out in their own package. `ShapeUpgrade_FaceDivide::Perform()`, the in-kernel driver of *both* classes, and the reason neither crash shows up in OCCT's own test suite, opens with exactly the guard this patch adds, then hands its context down to the compose shell (`ShapeUpgrade_FaceDivide.cxx:185`) and the wire divide (`:238`). Reached that way, neither class ever sees a null context. Reached directly, both crash. `ShapeFix_Shape::Init`, `ShapeFix_Shell::Perform`, `ShapeFix_Solid::Perform`, `ShapeFix_FixSmallFace::Init`, `ShapeFix_SplitCommonVertex::Init`, `ShapeFix_Wireframe` (both entry points), `ShapeFix_Wire::FixGap3d`/`FixGap2d`, `ShapeFix_Face::FixMissingSeam` and `ShapeUpgrade_ShapeDivide::Perform` all carry the same self-creating guard already.

**Fix:** the guard OCCT itself uses in those ten places, `if (Context().IsNull()) { SetContext(new ShapeBuild_ReShape); }`, at the three public entry points missing it. `ShapeFix_ComposeShell`'s other context-dereferencing methods (`LoadWires`, `SplitWire`, `SplitByLine`, `MakeFacesOnPatch`, `DispatchWires`) are all reached through `Perform()` or `SplitEdges()`, so guarding those two covers them; they are also `const`, so they could not create a context themselves.

**Validation** (fast path, no full rebuild, see the `#0001` entry above for the override-link technique): a 4-edge planar square face and an unbounded-cylinder face, run through both classes with no `SetContext()` call, SIGSEGV 100% of the time on stock `V8_0_0_p1` + patches `0001`–`0016` and complete normally after this patch. On the *with-context* path, the only one that worked before, the result is **byte-identical** before and after (BREP dump hash plus face/wire/edge/vertex counts compared for both surfaces and both classes), and the no-context path now produces that same result instead of crashing.

**Confirmed against the real binary** ([#512](https://github.com/SecondMouseAU/OCCTSwift/issues/512)): `Libraries/OCCT.xcframework` has since been rebuilt from source with all 17 patches, and both reproducers were re-run against it with **no** override-linked TUs: the two `ctx=NO` cases that were `KILLED BY SIGNAL 11` now complete, and all four `ctx=yes` fingerprints are identical to the values recorded pre-rebuild in the reproducer's README. Full `swift test` (4842 tests / 1346 suites) clean.

Both crashes were already closed **bridge-side**, before this patch existed: `OCCTShapeFixComposeShell` and `OCCTShapeUpgradeWireDivide` (`OCCTBridge_Healing.mm`) each call `SetContext(new ShapeBuild_ReShape())` with a comment naming the SIGSEGV. This patch fixes the kernel so those workarounds can eventually retire, and so the crash is closed for every other OCCT consumer following the documented `Init` + `Perform` usage.

See [`Scripts/repro/484-null-reshape-context/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/484-null-reshape-context) for the reproducer and full writeup. Filed upstream as [Open-Cascade-SAS/OCCT#1409](https://github.com/Open-Cascade-SAS/OCCT/issues/1409) (repro) / [OCCT#1410](https://github.com/Open-Cascade-SAS/OCCT/pull/1410) (fix), both still open with the PR unmerged as of 2026-07-30. Both defects are still present on upstream `master` (verified against `37dd5686` at filing time), and the PR branch's post-edit blobs hash identically to this patch's output, so the fix is the same on `master` as on our `V8_0_0_p1` pin.

**Retire** once the bundled OCCT includes this fix.

## 0018-GCPnts-degenerate-count-and-duplicate-end-point-555.patch

**Fixes two upstream OCCT defects in the arc-length samplers, behind [#555](https://github.com/SecondMouseAU/OCCTSwift/issues/555)**, both about the requested point count. [#501](https://github.com/SecondMouseAU/OCCTSwift/issues/501) had already closed the OCCTSwift-reachable half of the first one at the bridge layer; this is the kernel side, which every other OCCT consumer still carried.

1. **`GCPnts_UniformAbscissa::NbPoints()` can exceed the requested count.** `initialize` sizes its parameter array at `theNbPoints + 5` and the arc-length walk fills it until it reaches the end parameter or runs out of room, setting `myNbPoints` to whatever it reached. A caller that sizes its own buffer from the request rather than from `NbPoints()` overflows it. `GCPnts_QuasiUniformAbscissa` inherits this for every curve that is neither Bezier nor BSpline, since it forwards to `GCPnts_UniformAbscissa` for those, so the same class returns exactly `theNbPoints` on a Bezier and possibly more on an ellipse.

   The mechanism is a tolerance mismatch, not an off-by-one. `Perform` terminates on `std::abs(aUi - aUU2) <= theEPSILON`, where `theEPSILON` comes from `theC.Resolution(theTol)`, which converts a 3D tolerance to a parametric one using the curve's **largest** derivative. On an ellipse with major radius 1e6 and minor radius 1e-3 that is about 1e-13, while the local derivative at the end of that curve is 1e-3, making the parametric tolerance that actually corresponds to 1e-7 in 3D about 1e-4. The walk stops 1.557e-08 short, does not call that done, takes one more step and snaps it to the end. **The surplus point is a duplicate**: 1.175e-10 away from its neighbour in 3D.

2. **A point count below 2 stores out of bounds.** Both classes document `theNbPoints >= 2` and enforce it with `Standard_ConstructionError_Raise_if`, which compiles to nothing under `No_Exception`, how the shipped Release kernel is built (see `0016`'s neighbour issue #487). `GCPnts_QuasiUniformAbscissa`'s Bezier/BSpline branch then allocates `new NCollection_HArray1<double>(1, theNbPoints)`, an empty range for such a count, and the next statement is an unconditional `myParams->SetValue(1, theU1)`. `SetValue`'s own bounds check is a `Raise_if` too, so the store lands out of bounds: uncatchable SIGSEGV, same class as `0001`/#263, `0004`/#310, `0005`/#317 and `0006`/#318.

**Fix:** for the second, an ordinary `if` that **replaces** each `Raise_if` (not one added alongside
it), leaving the object not done for a count below 2 in every build, not only one that defines
`No_Exception`. Applied to both classes, since `GCPnts_UniformAbscissa` had the same missing
precondition without the crash (it answered a request for zero points with five). For the first,
`Perform` also accepts a point that coincides with the end **in 3D** within the caller's tolerance,
not only one close in parameter: the tolerance is threaded in alongside the parametric one, squared
once outside the loop, and compared with `SquareDistance()` rather than `Distance()` on every
candidate step; the end point is evaluated once outside the walk, and the distance test sits behind
a cheap `aUU2 - aUi < aDelta` gate so it runs on the final step rather than every step. Keeping the
exact end parameter is the point: clamping `myNbPoints` to the request, the other obvious fix, would
drop it and leave the distribution stopping short of the curve.

No public API signature changes.

**Revised 2026-08-07 (#755), patch content above updated in place, not a new patch number.**
Maintainer gkv311 [reviewed the upstream PR](https://github.com/Open-Cascade-SAS/OCCT/pull/1417#issuecomment-3150937)
with three requests. Two were mechanical (`SquareDistance()`/hoisted tolerance instead of `Distance()`
in the loop; the `Perform` parameter renamed `theTol3d` to `theTol`, since the same template also
instantiates on `Adaptor2d_Curve2d`, where "3d" was simply wrong). The third needed a decision, not
just compliance: he offered two ways to stop duplicating `Standard_ConstructionError_Raise_if`, an
assert-grade macro meant to compile away under `No_Exception`: (a) replace it with an unconditional
`throw`, or (b) drop the duplicate and answer not-done unconditionally. We build with
`BUILD_RELEASE_DISABLE_EXCEPTIONS=ON` (`No_Exception` defined), so (a) would start throwing for a
degenerate count in our own build where it currently cannot, and (b) would not. Measured rather than
guessed: every one of the 9 bridge call sites that construct either class with a caller-supplied count
(one of them a shared static helper with 2 further callers, 11 total) already wraps the construction
in `catch (...)`, and `Issue558SamplingCountBoundsTests.swift` asserts the not-done/empty-result
contract for exactly this input across every one of those entry points, so both options are
observably identical for OCCTSwift's own contract. Chose **(b)**: it is the option that does not
depend on a build flag, and it is what #555 argued for in the first place, a silent not-done rather
than an exception. Confirmed directly by compiling both variants **without** `No_Exception` and
constructing each class with a degenerate count: the pre-review patch still throws
`Standard_ConstructionError` there (exceptions enabled, so the un-replaced `Raise_if` fires);
after this revision, neither class throws in either build configuration. Re-ran the full
232/6766-configuration equivalence sweep and the degenerate-count sweep (5 curve types, both
classes, counts `{0, 1, -3}`) against the revised patch, override-linked with production flags: both
verdicts unchanged from the numbers below.

**Validation** (fast path, no full rebuild, see the `#0001` entry above for the override-link technique, but compile the two TUs with `-DNDEBUG -DNo_Exception` to match the production build, or the `Raise_if` comes back and the measurement is of a kernel nobody ships): across 17 curve types and counts 2 to 200, 6766 configurations, **232 lines change and they are exactly the 232 that were over-requesting**; every other line is byte-identical, and on the changed lines the last parameter is still exactly the end. Over-request goes to 0, and every degenerate count on every curve returns `IsDone() == false` for both classes. Confirmed against the rebuilt xcframework with no override-linked TUs, matching the override-linked prediction byte for byte. Full `swift test` (4842 tests / 1346 suites) clean.

See [`Scripts/repro/555-gcpnts-count-contract/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/555-gcpnts-count-contract) for the reproducers and full writeup, and
[`Scripts/repro/555-gcpnts-count-contract/upstream/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/555-gcpnts-count-contract/upstream)
for the post-review commit and the reply, both of which went out on 2026-08-10. Filed upstream as [Open-Cascade-SAS/OCCT#1417](https://github.com/Open-Cascade-SAS/OCCT/pull/1417), a fix PR with no companion repro issue, per upstream's own guidance on [OCCT#1409](https://github.com/Open-Cascade-SAS/OCCT/issues/1409#issuecomment-5124395058). Based on `b8f597c6`; the two touched files are byte-identical between upstream `master` and our `V8_0_0_p1` pin, so the patch is the same change on both. **The live PR is now [OCCT#1457](https://github.com/Open-Cascade-SAS/OCCT/pull/1457)**, same head branch and same fix: #1417 was closed on 2026-08-10 by a `git commit --amend` against a shallow clone, which GitHub reads as unrelated history, and reopening is not possible once that happens.

**Retire** once the bundled OCCT includes this fix.

## 0019-AdvApp2Var-jacobi-max-wrong-workspace-slot-522.patch

**Fixes the upstream OCCT defect behind [#522](https://github.com/SecondMouseAU/OCCTSwift/issues/522)**, found while building [#491](https://github.com/SecondMouseAU/OCCTSwift/issues/491)'s surface-approximation parity tests: `GeomConvert_ApproxSurface` asked for `GeomAbs_C0` returned a surface nowhere near its input while reporting `IsDone()` and a `MaxError()` five orders of magnitude too small.

`AdvApp2Var_ApproxF2var::mma2ce1_` requests one scratch allocation and partitions it into seven consecutive buffers, of which `ipt4` holds `XMAXJU` (the maxima of the U Jacobi polynomials) and `ipt5` holds `XMAXJV` (the V ones). Both `mma2jmx_` calls that fill them target `ipt5`:

```c
AdvApp2Var_ApproxF2var::mma2jmx_(ndjacu, iordru, &wrkar_off[ipt5]);   /* -> should be ipt4 */
AdvApp2Var_ApproxF2var::mma2jmx_(ndjacv, iordrv, &wrkar_off[ipt5]);
```

So `XMAXJU` is never written. `mma2ce2_` still reads it at `ipt4`, where the allocation left whatever was there, in practice zeros, and passes it to `mma2er1_`/`mma2er2_`, whose entire error model is `|PATJAC(i,j)| * XMAXJU(i - 2*(IORDRU+1)) * XMAXJV(j - 2*(IORDRV+1))`. A zero `XMAXJU` zeroes every term, with two silent consequences: (1) the interior approximation error of a patch is reported as exactly 0 whatever the discarded coefficients are, so `mma2ce2_`'s tolerance test can never fire on it and `MaxError()` only ever reflects the boundary-iso errors `AdvApp2Var_Patch::AddErrors` adds afterwards; (2) `mma2er2_`, asked for the lowest degree whose truncation error still fits the tolerance, always answers `NDMINU`, the floor derived from the constraint order and the neighbouring isos, because every candidate scores 0.

Where that floor is low the fit collapses onto it. C0 gives `IORDRU = 0`, and a full sphere's V-boundary isos degenerate to its two poles, one coefficient each, so `NDMINU` is 1: a radius-10 sphere at tolerance 1e-3 came back as a degree-1, 2-pole-in-U B-spline, a straight line across the full `2*pi` of longitude, deviating by the sphere's own diameter of 20, reporting `MaxError()` 1.07e-4. A bicubic Bezier at C0/C0 collapsed to a 2x2 bilinear patch reporting 4.08e-15, unchanged from tolerance 1e-1 down to 1e-7, because the requested tolerance was compared against a number that was always zero. C1 and C2 hid the collapse (their floor is already high) but not the misreported error.

The write also overruns: `mma2jmx_` writes `ndjacu + 1 - 2*(IORDRU+1)` doubles and the `ipt5` slot is sized for the `ndjacv` equivalent, so a request with `MaxDegU` well above `MaxDegV` runs past `XMAXJV` into the `VECERR` slot behind it. Benign in practice, `VECERR` is re-zeroed on entry to `mma2ce2_` and the run stays inside the single allocation, but out of bounds for the buffer it was given.

**Fix:** target `ipt4` from the U call. One character; the two lines then read symmetrically. `AdvApp2Var_Context`'s own two `mma2jmx_` calls (the only others in the tree) already write to separate per-direction arrays and were correct.

**Validation** (fast path first, then the real binary, see the `#0001` entry above for the override-link technique, compiled with `-DNDEBUG -DNo_Exception` to match the production build): dumping `&wrkar_off[ipt4]` shows `xmaxju[8] = 0 0 0 0 0 0 0 0` on stock and `0.9682 0.986 1.078 1.173 1.265 1.352 1.434 1.513` after. Across a 98-case sweep (7 surface families x all 9 `(uCont, vCont)` combinations of C0/C1/C2, plus C0/C0 at five tolerances) the results whose real deviation exceeds the reported `MaxError` by more than 10x go from **12 to 0**, and those that exceed it at all from 17 to 1, the survivor being a Bezier reproduced exactly, reporting 9.95221e-15 against a measured 9.96978e-15. Reported errors rise slightly everywhere, which is the interior contribution being counted for the first time. Confirmed against the rebuilt xcframework with no override-linked TUs, matching the override-linked prediction line for line. Full `swift test` (4842 tests / 1346 suites) clean.

`GeomConvert_ApproxSurface` is not a leaf. `GeomFill_Sweep`, `BRepOffset_Offset`, `GeomLib`, `ShapeCustom_BSplineRestriction`, `ShapeConstruct`, `ShapeUpgrade_UnifySameDomain` and `GeomConvert_1` (twice) all construct it, `ShapeCustom_ConvertToBSpline` reaches it through `ShapeConstruct`, and `GeomPlate_MakeApprox` drives `AdvApp2Var_ApproxAFunc2Var` directly. Most pass C1 or C2, where the collapse cannot happen, but the always-zero interior error affected all of them; and the healing paths reach C0 deliberately: `ShapeConstruct::ConvertSurfaceToBSpline` and `ShapeCustom_BSplineRestriction` both loop the requested continuity down to 0 on failure and then accept the result on `MaxError() <= tol`, and `ShapeCustom_ConvertToBSpline` *starts* at C0 for any offset surface (`ShapeCustom_ConvertToBSpline.cxx:148`) before handing off to the first of those. (`BRepFill_Sweep.cxx:1162` and `BRepFill_Filling.cxx:712` also name the class but are both inside comment blocks, so neither is a live caller; see #573.)

See [`Scripts/repro/522-approx-c0-collapse/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/522-approx-c0-collapse) for the reproducers and full writeup. Filed upstream as [Open-Cascade-SAS/OCCT#1418](https://github.com/Open-Cascade-SAS/OCCT/pull/1418), a fix PR with no companion repro issue, per upstream's own guidance on [OCCT#1409](https://github.com/Open-Cascade-SAS/OCCT/issues/1409#issuecomment-5124395058). Based on `b8f597c6`; the touched file is byte-identical between upstream `master` and our `V8_0_0_p1` pin, so the patch is the same change on both. **Merged upstream 2026-08-10**, one file, 1 insertion and 1 deletion, and it is on `upstream/master` as `07e6d8d40`. It is not in any OCCT release yet, so this patch stays carried; retire it at the release that contains it, per the rule below.

**Provenance (#756):** this is a regression, not an original defect. `3016a390713d2e893f4bfa797882b9f0266840e1` (2021, a UBSan coding-rules cleanup) renumbered every workspace offset in `mma2ce1_` down by one position and missed exactly one of the two `mma2jmx_` call sites; confirmed at the release-tag level, not just the commit diff, `V7_5_0` writes the U and V Jacobi maxima to two distinct slots and `V7_6_0` (the first release after the commit) already collapses them to one. Full mechanism is in [`Scripts/repro/522-approx-c0-collapse/README.md`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/522-approx-c0-collapse#upstream-provenance-756). The reply drafted to carry it upstream was never sent, and #1418 merged without it; that directory's `upstream/` files each say so at the top (#803).

**Retire** once the bundled OCCT includes this fix.

## 0020-BRepFeat_MakeCylindricalHole-select-tool-parts-532.patch

**Fixes the upstream OCCT wrong-answer behind [#532](https://github.com/SecondMouseAU/OCCTSwift/issues/532)**: a silent one: `BRepFeat_NoError` and the input handed back with the drill's faces imprinted on it, no material removed.

The four `BRepFeat_MakeCylindricalHole` modes that choose which piece of the drilling tool to keep, `PerformThruNext`, `PerformUntilEnd`, the ranged `Perform(Radius, PFrom, PTo)` and `PerformBlind`, drive `BRepFeat_Builder` with the one-argument `SetOperation(Fuse)`, i.e. `BOPAlgo_CUT`, and then call `PartsOfTool()`. That method (`BRepFeat_Builder.cxx:107`) collects the solids of the builder's `myShape`, which holds the tool split by the object only after the **COMMON** pass; after a CUT it is the finished workpiece. So each mode's `nbparts >= 2` selection loop compares barycentres of *bored plates* and then registers those plates as "kept parts of the tool" via `KeepPart`. `PerformResult()` sees a non-empty `myShapes`, takes the kept-parts path with a keep set that contains no tool part at all, and subtracts nothing.

The kernel's other two users of the same builder already do this correctly: `BRepFeat_Form` (`BRepFeat_Form.cxx:806`) and `BRepFeat_RibSlot` (`BRepFeat_RibSlot.cxx:224`) both call the two-argument `SetOperation(myFuse, bFlag)` with `bFlag` true before `Perform()`, selecting `BOPAlgo_COMMON`. `PerformResult()` re-derives `myOperation` from `myFuse`, so the operation finally built is the CUT either way.

**Fix:** that two-argument call at the four part-selecting sites. `Perform(Radius)`, the infinite-cylinder through-all, selects no parts, never calls `PartsOfTool()`, and keeps the one-argument overload; that is why it was the one mode that already drilled a stack correctly, and why the defect reads as "multi-body" rather than "part selection".

The defect is invisible whenever the cut result happens to have one solid, which is the single-plate case every existing test used. It appears as soon as it has two, a drill axis crossing two bodies of a compound, or, with no compound involved, a single bar the bore severs in half.

**Validation:** [`Scripts/repro/532-cylindrical-hole-part-selection/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/532-cylindrical-hole-part-selection) measures every mode across six geometries, before and after. On a compound of two 50×50×20 plates on the drill axis (one bore removes 1570.7963): `PerformUntilEnd` 0.0000 → 3141.5927, ranged `Perform(R, 0, 70)` 0.0000 → 3141.5927, `PerformBlind(20)` 0.0000 → 1178.0972; three plates, `PerformUntilEnd` 0.0000 → 4712.3890; the severed single bar, `PerformUntilEnd`/`PerformThruNext`/ranged `Perform` 0.0000 → 1407.2952 each. A single plate is byte-identical before and after. A channel and a hollow box, both one solid with two spans on the axis, give the same answer before and after while the selection loop goes from one part to two real tool parts, which is the non-regression evidence that matters. The full #496 contract matrix (`Scripts/repro/496-drill-hole-contracts/`) is unchanged apart from the rows this patch fixes and the oversized-radius row below. `swift test` clean.

**One behaviour change beyond the bug.** A radius so large the bore swallows the whole workpiece used to return `BRepFeat_InvalidPlacement` from `PerformUntilEnd`/`PerformThruNext`: under CUT the oversized tool emptied `myShape`, so `nbparts` was 0 and the "the tool meets nothing" guard fired. Under COMMON the tool meets the whole workpiece, `nbparts` is 1, and those modes now return the same empty result `Perform(Radius)` and a plain `BRepAlgoAPI_Cut` against the same cylinder always returned. `nbparts == 0` now means what the guard reads as.

**A second defect in the same heuristic, not fixed here.** `PerformThruNext`'s closest-interval fallback (`BRepFeat_MakeCylindricalHole.cxx:217-242`) has a misplaced brace: the `// parbar > Last` branch is nested *inside* `if (parbar < First)`, as the `else` of the distance comparison, so the "beyond `Last`" case is unreachable as written. `PerformBlind`'s equivalent fallback (`:602-616`) compares `std::abs(First - parbar)` uniformly and has no such structure. The fallback only runs when no tool part's barycentre lies in `[First, Last]`, which none of the probed geometries reach, so it is reported rather than changed.

Re-verified directly against current upstream `master` (not assumed from the `V8_0_0_p1` baseline this was first measured on): the four call sites are unchanged, `BRepFeat_Form`/`BRepFeat_RibSlot` still use the two-argument overload, and the second, unfixed defect is still present at the same lines. The touched file is byte-identical between `master` and our pin. Compiled `BRepFeat_MakeCylindricalHole.cxx` from `master` as an override translation unit, once unmodified and once with this patch, and ran the `Scripts/repro/532-cylindrical-hole-part-selection/` probe against both: the unmodified build reproduces every "before" figure above (including the oversized-radius `InvalidPlacement`), the patched build reproduces every "after" figure.

Filed upstream as [Open-Cascade-SAS/OCCT#1447](https://github.com/Open-Cascade-SAS/OCCT/pull/1447), a fix PR with no companion repro issue, per upstream's own guidance on [OCCT#1409](https://github.com/Open-Cascade-SAS/OCCT/issues/1409#issuecomment-5124395058).

**Retire** once the bundled OCCT includes this fix.

## 0021-CPnts-adaptive-arc-length-integration-603.patch

**Fixes the upstream OCCT defect behind [#603](https://github.com/SecondMouseAU/OCCTSwift/issues/603)**, which OCCTSwift already works around bridge-side: `CPnts_AbscissaPoint::Length` integrates `|C'(u)|` with **one** fixed-order Gauss rule over the whole range it is handed, `order()` gives 10 to a conic, 5 to a parabola, `2 * Degree` to a Bezier, `min(24, 2 * NbPoles - 1)` to a B-spline.

`GCPnts_AbscissaPoint::Length` splits at the `GeomAbs_CN` interval boundaries and applies that rule per interval, so a multi-span B-spline is mostly saved by the split. A conic has exactly one interval, so nothing is split and the rule has to cover the whole domain in one go. Measured against a 16-point composite Gauss-Legendre quadrature of `|C'(u)|` over 40,000 panels, cross-checked against a Richardson-extrapolated chord sum:

| curve | `GCPnts::Length` | truth | error |
|---|---|---|---|
| ellipse 8 × 3 | 36.489426687 | 36.366862783 | +0.337% |
| ellipse 10 × 1 | 41.243157870 | 40.639741801 | +1.485% |
| ellipse 1 × 0.05 | 4.089251430 | 4.019425619 | +1.737% |
| parabola f=3 over `[-100, 100]` | 1638.523403092 | 1690.708711624 | **−3.087%** |
| hyperbola 5/2 over `[-4, 4]` | 285.669841141 | 285.479768689 | +0.067% |
| Bezier degree 3, whipping poles | 48.124450786 | 48.215369891 | −0.189% |
| interpolated B-spline, 5 points | 110.963893077 | 110.970568312 | −0.0060% |
| circle, line | exact | exact | length-parametrized, no quadrature |

The error is set by how much `|C'|` varies across **one** integration interval, not by the curve's type: the same 8 × 3 ellipse is 0.337% out over `[0, 2π]`, 0.0001% over `[0, π]` and exact over `[0, π/2]`. So the per-span split is not a fix either, just a mitigation that happens to work when spans are narrow, a 5-point interpolation is 100× worse than a 40-point one.

`CPnts_AbscissaPoint::Length` **called directly** is far worse than through `GCPnts`, because nothing splits at all: 3.6e-2 on the 5-point interpolation, 7.4e-2 at 40 points and **1.0e-1 at 200 points**, where the `min(24, ...)` cap means one order-24 rule covers the entire domain.

**Fix:** a new header-only `CPnts_AdaptiveIntegration.hxx` integrates over `[U1, U2]`, then over the same range split in two, four, … equal parts, until two successive levels agree to `1e-9` relative (ceiling 512 parts). All four `CPnts_AbscissaPoint::Length` overloads and `CPnts_MyRootFunction::Value`/`Values` use it.

**`CPnts_MyRootFunction` has to move with `Length`, not after it.** That class is the function `math_FunctionRoot` drives to answer "which parameter is this far along?", and its `Value(X)` is *the same integral*: one Gauss rule over `[myX0, X]` minus the target. Today both are wrong by the same amount, which is why `GCPnts_AbscissaPoint(C, GCPnts_AbscissaPoint::Length(C), first)` still lands on the last parameter and why `GCPnts_UniformAbscissa` spaces its points uniformly in *true* arc (measured: 2.9e-14 on an 8 × 3 ellipse) despite computing a total that is 0.337% wrong. Fixing `Length` alone would break both of those. Fixing them together keeps the sampler's spacing bit-for-bit (2.9e-14 → 2.9e-14, 1.59e-10 → 1.59e-10 on a 1 × 0.05 ellipse) and makes every fraction of the way accurate: `GCPnts_AbscissaPoint(ellipse 8×3, total/2, first)` moves from `u = 3.162016203` to `u = 3.141592654`.

**Validation** (override-link first, then the rebuilt binary, see the `#0001` entry for the technique, compiled with `-DNDEBUG -DNo_Exception` to match the production build): every relative error in the table above goes to ≤ 2.6e-13, `CPnts_AbscissaPoint::Length`'s own direct errors from 1.0e-1 to 2.8e-8, and the inverse from 3.4e-3/1.5e-2/1.7e-2 at the full length to ≤ 1.8e-13 at every fraction. The rebuilt xcframework reproduces the override-linked prediction line for line with no override TUs. Full `swift test` (5096 tests / 1371 suites): no change, the same 3 pre-existing `Issue496CylindricalHoleTests` failures as before the rebuild.

**Cost:** the floor is three quadratures where there was one, and a curve whose closed form is exact (`GeomAbs_Line`, `GeomAbs_Circle`, a 2-pole Bezier/B-spline) never reaches the integrator at all. `GCPnts_AbscissaPoint::Length` on an 8 × 3 ellipse goes 0.24 µs → 7.2 µs; on a 200-span B-spline 87 µs → 444 µs; `GCPnts_UniformAbscissa` at 500 points on an ellipse 2.71 ms → 6.20 ms.

**Not reached by this patch:** `BRepGProp::LinearProperties` runs its own integrator and still reports 41.243157870 for a 10 × 1 elliptical edge against a true 40.639741801 (confirmed unchanged against the rebuilt binary). Same defect class, different code, its own fix.

**OCCTSwift's own bridge-side subdivision (#603, `occtAdaptorArcLength`) is now redundant but not removed.** `ci.yml` resolves the pinned *released* kernel, which does not carry this patch, so removing it would fail the #603 regression tests there until a release ships this binary. Layered on the fixed kernel it costs almost exactly 2× (an 8 × 3 ellipse 3.3 µs → 6.6 µs) and changes no answer, retire it in the release commit that bumps `Package.swift`'s `url:`/`checksum:`.

See [`Scripts/repro/603-single-span-quadrature/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/603-single-span-quadrature) for the reproducers and full writeup. Filed upstream as [Open-Cascade-SAS/OCCT#1420](https://github.com/Open-Cascade-SAS/OCCT/pull/1420), a fix PR with no companion repro issue, per upstream's own guidance on [OCCT#1409](https://github.com/Open-Cascade-SAS/OCCT/issues/1409#issuecomment-5124395058). The three touched files are byte-identical between upstream `master` and our `V8_0_0_p1` pin, so the patch is the same change on both.

**Retire** once the bundled OCCT includes this fix.

## 0022-ChFi2d_Builder-AddChamfer-connexion-error-check-705.patch

**Fixes the upstream OCCT defect behind [#705](https://github.com/SecondMouseAU/OCCTSwift/issues/705)**,
which OCCTSwift already guards bridge-side (`OCCTFace2DChamfer`, `OCCTBridge_Modeling_Chamfer.mm`
since #396's twelve-way split; `OCCTBridge_Modeling.mm` at the time this patch was written):
`Shape.chamfer2D(edgePairs:distances:)` SIGSEGVs, uncatchably, when the same edge pair is named
twice, found by Cluster B's fillet/chamfer edge-set census (#665).

`ChFi2d_Builder::AddChamfer(E1, E2, D1, D2)` calls `ChFi2d::FindConnectedEdges` to look up the
pair's shared vertex, then dereferences the two edges it returns without checking the returned
status first. `FindConnectedEdges` returns `ChFi2d_ConnexionError` on every failure path, which is
what this patch checks; it does not leave both edges null on all of them (one incident edge assigns
`E1`, three or more assign both, see the repro README's table), so nullness would have been the
wrong thing to guard on. A second call
naming the same pair hits exactly that: the pair's shared vertex is removed from the face's wire by
the first call's own `BuildNewWire`, so the second call's lookup fails and the two null edges it
returns reach `ComputeChamfer` unchecked. Confirmed with a debug (`-O0`) single-TU override-link
(this file compiled standalone and linked before the OCCT static archive, so the linker resolves
this TU's symbols from the override): the crash is inside `ComputeChamfer`, with `EE1`/`EE2` both
null, exit 139 on stock.

`ChFi2d_Builder::AddChamfer(E, V, D, Ang)`, the sibling overload calling the identical
`FindConnectedEdges`, already checks the returned status correctly and returns a null edge on
`ChFi2d_ConnexionError`. Reachable from OCCT's own DRAW `chfi2d` command too
(`BRepTest_Fillet2DCommands.cxx`), which loops over edge-name pairs from the command line and calls
this same overload once per pair, so a `chfi2d` invocation naming the same two edges twice reaches
the identical crash.

**Fix:** adds the same status check immediately after `FindConnectedEdges`, returning `chamfer`,
the default-constructed null edge this function already returns on its other refusal paths (lines
83, 89, 95), rather than a new value.

**Validation** (override-link, no full rebuild, see the `#0001` entry above for the technique): a
rectangular planar face, `BRepFilletAPI_MakeFillet2d::AddChamfer` called twice with the identical
edge pair. Before the patch, the second call SIGSEGVs (exit 139) every time; after, it returns a
null edge with `Status() == ChFi2d_ConnexionError` (numeric 7), matching the sibling overload's own
answer for an unconnected vertex. The first call is unaffected in both cases:
`Status() == ChFi2d_IsDone` (numeric 5), a valid non-null edge. `clang-format --dry-run --Werror`
reports only pre-existing, unrelated violations elsewhere in the file, unchanged in count and
content; the four added lines are clean.

**Bridge guard stays regardless.** This is the established pattern here (#298, #341, #344, #349):
the bridge-side duplicate-pair check in `OCCTFace2DChamfer` shipped first and is not removed by this
patch, since a caller on the currently-pinned kernel (which does not carry this patch until a
rebuild ships it) still needs it. See [`Scripts/repro/705-chamfer2d-duplicate-pair/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/705-chamfer2d-duplicate-pair)
for the reproducers. Filed upstream as [Open-Cascade-SAS/OCCT#1431](https://github.com/Open-Cascade-SAS/OCCT/issues/1431)
(repro) / [OCCT#1432](https://github.com/Open-Cascade-SAS/OCCT/pull/1432) (fix).

**Retire** once the bundled OCCT includes this fix.

## 0023-GeomTools_Curve2dSet-SurfaceSet-null-handle-643.patch

**Fixes the upstream OCCT defect behind [#643](https://github.com/SecondMouseAU/OCCTSwift/issues/643)**,
found while fixing #618 (PR #641) and confirmed as part of Cluster C's null-handle census (#666,
PR #711): `GeomTools_Curve2dSet::Add`/`GeomTools_SurfaceSet::Add` accept a null handle silently and
defer the crash to `Write()`, where `GeomTools_CurveSet::Add` (the third copy of the same writer)
already drops it.

`GeomTools_CurveSet::Add` (`GeomTools_CurveSet.cxx:70`) reads `return (C.IsNull()) ? 0 :
myMap.Add(C);`. `GeomTools_Curve2dSet::Add` and `GeomTools_SurfaceSet::Add` read `return
myMap.Add(S);`, with no guard. A null handle is accepted and bound at index 1, so the caller gets no
signal at `Add()` time at all; the crash only surfaces later, inside `Write()`
(`Curve2dSet::Write` → `PrintCurve2d` → `C->DynamicType()`, `SurfaceSet::Write` → `PrintSurface` →
`S->DynamicType()`). The same asymmetry repeats one function down in `Index()`: `CurveSet::Index`
guards, the two siblings do not; this one does not crash (`NCollection_IndexedMap::FindIndex`
never dereferences its argument), but it silently returns a bogus non-zero index for a handle that
was never validly bound, where `CurveSet::Index` correctly answers 0.

**Measured directly against the pinned kernel** (`v2.0.0-kernel.1`, OCCT `V8_0_1` + the ten carried
patches), fork-per-probe so a crash is reported rather than ending the run:

```
  -- Add() alone --
  GeomTools_CurveSet::Add(null)                  Add returned 0    returned normally
  GeomTools_Curve2dSet::Add(null)                Add returned 1    returned normally
  GeomTools_SurfaceSet::Add(null)                Add returned 1    returned normally

  -- Add() then Write(), which is what the bridge does --
  GeomTools_CurveSet::Add(null) + Write          returned normally
  GeomTools_Curve2dSet::Add(null) + Write        SIGSEGV (uncatchable)
  GeomTools_SurfaceSet::Add(null) + Write        SIGSEGV (uncatchable)
```

Byte-identical between our `V8_0_1` pin and upstream `master`, so this is not fixed further up
either.

**Not reachable through OCCTSwift today.** `OCCTGeomToolsCurve2dSetWrite`/
`OCCTGeomToolsSurfaceSetWrite` (`Sources/OCCTBridge/src/OCCTBridge_IO.mm`) already guard every array
element before calling `Add()` (`if (!c || c->curve.IsNull()) return nullptr;`, the #618
"array element through a cast" shape), and these two bridge functions are the only call sites of
`GeomTools_Curve2dSet`/`GeomTools_SurfaceSet` in the whole tree. Confirmed by override-linking the
real `OCCTBridge_IO.mm` against a genuinely null-handle-wrapping `OCCTCurve2D`/`OCCTSurface`: both
functions return `nullptr` rather than crashing, for a null-only array and for a mixed valid+null
array. Removing the bridge guard (injected, then restored) reproduces the SIGSEGV through the real
bridge function, confirming the guard is load-bearing, not incidental. This is a kernel-only fix;
no bridge change is needed or made.

**Fix:** the same one-line guard `GeomTools_CurveSet::Add`/`Index` already have, applied to both
methods on both sibling classes:

```cpp
int GeomTools_Curve2dSet::Add(const occ::handle<Geom2d_Curve>& S)
{
  return (S.IsNull()) ? 0 : myMap.Add(S);
}
int GeomTools_Curve2dSet::Index(const occ::handle<Geom2d_Curve>& S) const
{
  return (S.IsNull()) ? 0 : myMap.FindIndex(S);
}
// and the same pair on GeomTools_SurfaceSet
```

**Validation** (override-link, no full rebuild, see the `#0001` entry above for the technique):
compiled the two patched `.cxx` files standalone and linked them ahead of the OCCT static archive.
Before the patch, `Curve2dSet`/`SurfaceSet::Add(null)` both return 1 and `Write()` SIGSEGVs; after,
all three classes' `Add()` return 0 and `Write()` completes normally. `Index()` before the patch
returns the same bogus 1 for the two siblings after adding a null handle; after, all three classes'
`Index()` return 0, matching `CurveSet::Index`. A populated, all-valid-handle set is unaffected in
either direction.

See [`Scripts/repro/643-geomtools-null-write/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/643-geomtools-null-write)
for the reproducer. Filed upstream as [Open-Cascade-SAS/OCCT#1434](https://github.com/Open-Cascade-SAS/OCCT/issues/1434)
(repro) / [OCCT#1435](https://github.com/Open-Cascade-SAS/OCCT/pull/1435) (fix).

**Retire** once the bundled OCCT includes this fix.

## 0024-Extrema_ExtCC-Points-bound-against-mypoints-636.patch

**Fixes the upstream OCCT defect behind [#636](https://github.com/SecondMouseAU/OCCTSwift/issues/636)**,
already mitigated bridge-side (`OCCTCurve3DExtrema`, `Sources/OCCTBridge/src/OCCTBridge_Curve3D.mm`,
PR #730): `Curve3D.extrema(with:maxCount:)` SIGSEGV'd, uncatchably, on parallel curves at every
capacity including its own default, both for unbounded lines and for finite segments whose
projected ranges overlap.

`Extrema_ExtCC::NbExt()` counts `mySqDist`; `Extrema_ExtCC::Points()` reads a different container,
`mypoints`, but bounds-checks the request against `NbExt()`. Several branches of
`PrepareParallelResult` append a distance to `mySqDist` with no matching pair in `mypoints`, because
in those branches the curves are parallel over a continuous range and there genuinely is no unique
closest point to report, only a distance. `NbExt()` reports `1` in exactly those cases, so
`Points(1)` indexes an empty `NCollection_Sequence`. `Points()`'s own bounds check is a raw `throw`,
not compiled out under `No_Exception` (this project's Release kernel is built with
`BUILD_RELEASE_DISABLE_EXCEPTIONS=ON`), but it checks the wrong bound, so it never fires. The check
that would catch the real problem, `NCollection_Sequence::Value()`'s own `Standard_OutOfRange_Raise_if`,
*is* built from that macro and *is* compiled to nothing under `No_Exception`; with no guard left,
indexing an empty sequence walks a null node. Confirmed with a standalone binary linked directly
against `libOCCT-macos.a`: a genuine SIGSEGV, not a C++ exception a `catch (...)` could absorb.
`GeomAPI_ExtremaCurveCurve::Points()` (what `OCCTCurve3DExtrema` calls) has the identical shape one
layer up, its own bounds check is also a `Raise_if` no-op under `No_Exception`, so nothing between
the bridge and the null-node dereference does anything until this patch.

**Caller survey before choosing a fix shape** (the issue asked for one; two alternatives were
considered and rejected):

- *Redefine `NbExt()` to count `mypoints` instead of `mySqDist`.* Rejected:
  `GeomAPI_ExtremaCurveCurve::LowerDistance()` reaches `SquareDistance(myIndex)`, which
  bounds-checks against `NbExt()` too. Redefining it would make the parallel-distance-only case
  (which has a perfectly well-defined distance, just no unique point) start refusing
  `LowerDistance()` as well, measured that this caller currently gets a correct answer in exactly
  the branches this patch touches, and unifying the counts would have broken it.
- *Gate `Points()` on `IsParallel()`* (what the bridge does, one layer up, for its own purpose).
  Traced every branch of `PrepareParallelResult` by hand: `IsParallel()` is true in precisely the
  branches that leave `mypoints` empty and false in precisely the branches that populate it, no
  exceptions found, so this is equivalent to the fix actually made, *today*. Chose the
  container-bound version instead because it is self-defending against the shape of the bug (an
  index into a container with fewer entries than claimed) rather than relying on a correspondence
  between two fields that nothing enforces, and because `SquareDistance()` already bounds against
  the container it reads (`mySqDist`), `Points()` doing the same against `mypoints` matches an
  existing pattern in the same file rather than adding a new one.

**Fix:** bounds `Points()` against `mypoints.Length()` instead of `NbExt()`:

```cpp
void Extrema_ExtCC::Points(const int N, Extrema_POnCurv& P1, Extrema_POnCurv& P2) const
{
  if (N < 1 || 2 * N > mypoints.Length())
  {
    throw Standard_OutOfRange();
  }
  P1 = mypoints.Value(2 * N - 1);
  P2 = mypoints.Value(2 * N);
}
```

Plus a matching `//! Exceptions` doc line on the header declaration, and a **companion, behavior-neutral
addition** to `Geom2dAPI_ExtremaCurveCurve.hxx`: a one-line `IsParallel()` forwarder, matching the
3D sibling's own convenience method (`Extrema_ExtCC2d::IsParallel()` was already public and already
reachable via the existing `Extrema()` accessor, so this closes an ergonomic gap, not a capability
one). The 2D curve-curve class was measured, not assumed, to be already safe: its own `NbExtrema()`
correctly reports `0` in every fixture this patch's 3D counterpart makes crash, so `Points()` is
genuinely unreachable there today, in both bridge call sites that use it
(`OCCTCurve2DMinDistance`, `OCCTCurve2DAllExtrema`, the latter is the "very likely a 2D sibling"
follow-up PR #730 flagged but didn't confirm; this patch's repro confirms it is not).

**Validation** (override-link, no full rebuild, see the `#0001` entry above for the technique,
compiled with `-DNDEBUG -DNo_Exception` to match the production build): four fixtures, finite
parallel segments with overlapping projected ranges, the same with disjoint ranges, two infinite
parallel `Geom_Line`s, and finite parallel segments whose projected ranges touch at exactly one
point. The first two are the issue's own ground truth; the third is PR #730's own regression
fixture shape; the fourth was added after tracing `PrepareParallelResult`'s line-line branch by
hand suggested it might be a counter-example to the `IsParallel()`/`mypoints` correspondence above,
measuring it disproved that (see the repro README's "four fixtures" table). Before the patch, the
overlapping and infinite cases SIGSEGV (exit 139) through both `GeomAPI_ExtremaCurveCurve::Points()`
and `Extrema_ExtCC::Points()` directly; after, both throw a catchable `Standard_OutOfRange`. The
disjoint and touching cases are **byte-identical** before and after, in both the returned points and
`LowerDistance()`/`Distance()` (which read `mySqDist` and are untouched by this patch, measured
across all four fixtures rather than assumed). Confirmed the patch applies cleanly (`git apply
--check`) to both the pinned `V8_0_1` tag and current upstream `master`, byte-identical between the
two for every touched file, so there is no rebase to do before filing. `clang-format --dry-run
--Werror` against OCCT's own `.clang-format` reports zero violations on all three changed files.

See [`Scripts/repro/636-extrema-parallel/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/636-extrema-parallel)
for the reproducer and the full caller survey. **Filed upstream 2026-08-07 as
[Open-Cascade-SAS/OCCT#1445](https://github.com/Open-Cascade-SAS/OCCT/pull/1445)**, PR only and no
companion issue, per `okf/policies/upstream-occt-style.md` and the precedent of `0018`, `0019` and
`0021`: the fix was ready, so the PR description carries the repro and root cause that a standalone
issue would have. Verified applying cleanly to upstream `master` at `b8f597c6` immediately before
filing. That directory's `draft-issue.md` is retained as the text to use if the defect ever needs
reporting ahead of a fix; `draft-pr.md` is what was sent.

**Retire** once the bundled OCCT includes this fix.

**Pin consequence**: this is the third patch (after `0022`, `0023`) carried in the tree but outside
the pinned `v2.0.0-kernel.1` binary asset, see `docs/v2.0.0-plan.md`'s release watch-out. The next
kernel rebuild needs to carry all three, and confirm all three actually reached the binary rather
than assuming the rebuild picked them up, per `docs/guides/building-occt.md`'s shipping-a-rebuild
steps.

## 0025-GeomFill_Sweep-report-achieved-conversion-error-597.patch

**Fixes the upstream OCCT defect behind [#597](https://github.com/SecondMouseAU/OCCTSwift/issues/597)**
(kernel half; the bridge half was investigated and closed as provably empty by PR #751, both
obvious fixes there broke real tests).

`GeomFill_Sweep::BuildAll` measures the swept surface's real approximation error at
`GeomFill_Sweep.cxx:286` (`SError = Approx.MaxErrorOnSurf();`). When the caller has requested
`ForceApproxC1` and the swept surface isn't already C1 in V, it re-approximates through
`GeomConvert_ApproxSurface(mySurface, theTol, ...)` (`theTol` a literal `1.e-4`) and, on
`HasResult()`, replaces `mySurface` with the conversion's output, then overwrites the measured
error with the requested tolerance instead of reading what the conversion achieved:

```cpp
SError = theTol;   // GeomFill_Sweep.cxx:325
```

`GeomConvert_ApproxSurface::HasResult()` is documented as true even for a result "not NECESSARILY
within the required tolerance," and `MaxError()`, which reports what was actually achieved, sits
unread two lines above. `BRepFill_Sweep`/`BRepFill_PipeShell`/`BRepOffsetAPI_MakePipeShell::ErrorOnSurface()`
all forward `SError` verbatim, so `BRepOffsetAPI_MakePipeShell::SetForceApproxC1(true)`, a public,
documented API, hands every caller a number describing the request, not the result.

**Getting a repro to fire needs care.** The branch only runs when the *swept surface itself* fails
`IsCNv(1)`, and `BRepFill_Sweep` splits its sweep at every spine **vertex**, so a polyline spine
never reaches it: the discontinuity has to sit inside one unsplit edge. The fixture (borrowed from
[#572](https://github.com/SecondMouseAU/OCCTSwift/issues/572), pinned by
`Tests/OCCTModelingTests/Sweeps/Issue572SweepApproxTests.swift`) is a single-edge spine built as one
degree-2 B-spline curve with an interior knot of multiplicity 2, a C0 corner inside what
`BRepFill_Sweep` treats as one edge, swept with a unit circle profile and Frenet trihedron via
`BRepFill_PipeShell`, matching the bridge's own construction exactly.

**Is `MaxError()` the right quantity? Checked, not assumed.** #597's bridge half died on exactly
this trap: `GeomPlate_MakeApprox::ApproxError()` measures fidelity to an *intermediate*
`GeomPlate_Surface`, not the caller's actual input, so gating on it broke 6/6
`Issue571PlateApproxTests`. Here there is no third object: `GeomConvert_ApproxSurface`'s `Surf`
argument *is* `mySurface`, the exact surface being replaced. Confirmed by reconstructing the same
`GeomConvert_ApproxSurface(unforcedSurface, 1e-4, C1, C1, 14, 14, 16, 1)` call from outside the
kernel (using the surface a separate `ForceApproxC1(false)` build returns, which never reaches this
branch and is exactly what `mySurface` holds at the real call site): its output has the same
degree/pole counts as the real forced build's, and deviation from the same unforced-surface baseline
to each is bit-identical, proving the reconstruction is the real call, not a divergent simulation.
**Does `MaxError()` actually move?** Patch `0019` (#522) is what makes this possible: before it,
every interior truncation error was structurally zero, so `MaxError()` could not report a large
number no matter how bad the fit was. Measured against the currently pinned kernel (all of
`0010`-`0012`/`0014`-`0021` baked in): `MaxError() = 2.54714`, matching #572's own independent
measurement of this identical fixture (`2.547`) to the printed precision. It moves.

**Fix:** `SError = ConvertApprox.MaxError();`. One line. `CError`'s four literal `0.` entries a few
lines above are left untouched: no 2D curve error is available from `GeomConvert_ApproxSurface` at
this point, and inventing one would be exactly the fabrication [#726](https://github.com/SecondMouseAU/OCCTSwift/issues/726) exists to prevent.

**Validation** (override-link, no full rebuild, see the `#0001` entry above for the technique,
compiled with `-DNDEBUG -DNo_Exception` to match the production build): the real, in-kernel
`BRepFill_PipeShell`/`GeomFill_Sweep` object's `ErrorOnSurface()` goes from `0.0001` (exactly
`theTol`, stock) to `2.54714` (matching the externally-reconstructed prediction exactly) after the
patch. Every other value the harness prints, the returned surface's degree/pole/knot counts and two
independent geometric deviations (same-parameter and nearest-point), is byte-identical before and
after: this patch changes only what the class *reports*, never the surface any caller receives
(`mySurface` is already `ConvertApprox.Surface()` two statements earlier). Consumer survey: no
existing bridge site gates on this number. `PipeShellBuilder.errorOnSurface` is info-only (its one
test asserts `>= 0`), and `OCCTGeomFillSweep`'s own error gate (added in PR #741, the other half of
#597) never sets `ForceApproxC1` so it never reaches this branch at all. `swift test` is therefore
unaffected; this is a diagnostic-only fix.

Confirmed the patch applies cleanly (`git apply --check -p1`) to both the pinned `V8_0_1` tag and
current upstream `master` (`b8f597c6`), byte-identical between the two for the touched file.
`clang-format --dry-run --Werror` against OCCT's own `.clang-format` reports zero violations.

See [`Scripts/repro/597-geomfill-sweep-error-overwrite/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/597-geomfill-sweep-error-overwrite)
for the reproducer, fixture derivation and full before/after transcripts. **Filed upstream as a PR
draft only** (`draft-pr.md` in that directory, **not sent**: this task's constraints forbid writing
to `Open-Cascade-SAS/OCCT`), per `okf/policies/upstream-occt-style.md` and the precedent of `0018`,
`0019`, `0021` and `0024`: the fix was ready, so the PR description carries the repro and root cause
a standalone issue would have.

**Retire** once the bundled OCCT includes this fix.

**Pin consequence**: this is the fourth patch (after `0022`, `0023`, `0024`) carried in the tree but
outside the pinned `v2.0.0-kernel.1` binary asset. PR #754 (`chore/512-repin-kernel-2`, open at the
time of writing) re-pins to `v2.0.0-kernel.2`, folding in all fourteen (`0010`-`0012`,
`0014`-`0024`); once that merges, `0025` becomes the *only* patch left outside the pin, exactly the
gap `docs/v2.0.0-plan.md`'s RESOLVED block already names by number ahead of time. Watch for it at
the next re-pin, same as `0022`-`0024`.

## 0026-BRepOffsetAPI_ThruSections-capping-guard-905.patch

**Fixes the upstream OCCT defect behind [#905](https://github.com/SecondMouseAU/OCCTSwift/issues/905)**
,  `ThruSectionsBuilder(isSolid: true)` silently omits both end-cap faces for a closed section wire
with two or more periods of out-of-plane variation around the loop (a genuinely non-planar closed
curve). `build()` returns `true`, `checkResult.isValid` is `false`, and `checkResult.errorCount`/
`detailedCheckStatuses` localize nothing.

`MakeSolid()` (the static helper `CreateRuled()`/`CreateSmoothed()` both call to close a loft's two
open ends) caps each end via `PerformPlan()`, which only fits a plane (`BRepBuilderAPI_FindPlane`)
or reuses a surface already attached to the wire's edges (`BRepLib_FindSurface`-backed
`MakeFace(wire)`). A wire with `k >= 2` out-of-plane periods has neither, so `PerformPlan()` fails,
but `MakeSolid()` already tracks this in its own local `B` (threaded through both `PerformPlan()`
calls) and discards it: it unconditionally marks the shell/solid `Closed(true)` and returns
regardless of whether capping actually succeeded. `k == 1` (e.g. `z = amp * cos(theta)` at constant
radius) caps fine, because that curve is secretly planar, the intersection of the cylinder
`r = const` with a tilted plane, so `BRepBuilderAPI_FindPlane` finds it; `k >= 2` has no such plane.

**A first attempt at this fix, checked and rejected before landing here.** Guarding the two call
sites on `myFirst.IsNull() || myLast.IsNull()` looks right and is not: `PerformPlan()` also leaves
the output face null, and returns `true` (no failure), when every edge of the wire is degenerate, a
single-vertex "point" section built via `AddVertex()`, e.g. a cone's apex, which needs no cap face
at all. A null-face check cannot tell that case apart from a genuine capping failure. CI on the
fork PR caught this directly: `BOPAlgo_PaveFillerTest.FuseConeLoftWithBox_DegeneratedEdge` (a
circle-to-vertex loft) regressed, `IsDone()` reading `false` for input that has always legitimately
succeeded. Reproduced locally byte-for-byte against that exact GTest before writing the real fix
(same failure line, same message).

**Fix:** after the capping block, if `B` is still `false`, capping was needed and failed, not
skipped because it wasn't needed, nullify both output faces and throw `StdFail_NotDone`, matching
the exception this same function already throws for a null shell two lines above:

```cpp
if (!B)
{
  face1.Nullify();
  face2.Nullify();
  throw StdFail_NotDone("BRepOffsetAPI_ThruSections: could not close a non-planar extremity");
}
```

The nullify matters because `face1`/`face2` alias the caller's `myFirst`/`myLast` (exposed publicly
via `FirstShape()`/`LastShape()`): if wire1's `PerformPlan()` succeeds (writing a real face) but
wire2's fails, `B` ends `false` on wire2's failure alone, and without the nullify `myFirst` would
still hold a genuine, but never-added-to-the-shell, face after a failed `Build()`. Found in review
(PR #909); OCCTSwift's own bridge never calls `FirstShape()`/`LastShape()` on `ThruSections` so this
was unreachable here, but it is a real contract hazard for any other OCCT consumer, corrected before
filing upstream.

No signature change and no call-site change: both call sites already run inside `Build()`'s only
`try`/`catch` (`catch (Standard_Failure const&) { NotDone(); return; }`), so the throw propagates
there and `IsDone()` correctly reads `false`.

**`GetStatus()` is deliberately left unfixed, not merely unfixed by omission.** It stays
`BRepFill_ThruSectionErrorStatus_Done` on this path, because `Build()`'s catch is generic, it
doesn't set `myStatus` for *any* exception source, not one this patch introduces. `MakeSolid()` is
a free function with no access to `myStatus` (a private member), so making `GetStatus()` correct
here would mean either a new out-parameter threaded through both call sites, or wrapping both
`MakeSolid()` calls in their own local `try`/`catch` to set `myStatus` before rethrowing, the
same multi-site-touch shape the rejected null-face guard had, for a return value nothing in this
tree reads (`IsDone()` is what every caller, including OCCTSwift's own bridge, actually checks).
Sibling patch `0022` (#705, `ChFi2d_Builder::AddChamfer`) took the other side of this trade-off,
it populates its class's own status enum for the identical "silently proceeds with a bad result"
bug class, but that fix had no `Build()`-style shared catch to route around; here, the throw
already reaches the one place (`Build()`'s catch) every caller of `IsDone()` already depends on, so
adding a second signaling path for a value nothing reads was judged not worth the doubled diff.
**Why a throw, not surfacing a number** (contrast with sibling `0025` / #597, same TKOffset/loft
family, which fixed its bug by surfacing a discarded `MaxError()` through an existing diagnostic
accessor at zero control-flow change): `0025`'s bug was a wrong *diagnostic* value on an operation
that had already succeeded; this bug is a wrong *pass/fail* answer, and `IsDone()`/exceptions are
how this exact function already reports pass/fail for every other failure mode in it (the null-shell
throw two lines above, `Georges.GetStatus()` failures, `BRepFill_CompatibleWires` failures), no
existing accessor plays `MaxError()`'s role for capping success.

**Validation** (override-link, no full rebuild, see `#0001`'s retired entry for the technique):
compiled and linked both the unpatched and patched `.cxx` ahead of the pinned `libOCCT-macos.a`.
Against the unpatched override, a new GTest (`BRepOffsetAPI_ThruSections_Test.cxx`,
`NonPlanarClosedWireCappingFails`) fails exactly as the issue describes (`IsDone()` reads `true`
for a `k=2` two-wire loft); against the patched override it passes, along with a second new test
(`DegenerateVertexEndStillSucceeds`, the cone/apex shape) and all three pre-existing tests in the
file. The actual upstream `BOPAlgo_PaveFillerTest.FuseConeLoftWithBox_DegeneratedEdge` (compiled
unmodified from `Libraries/occt-src`) passes against the patched override, direct confirmation the
fix does not reintroduce the first attempt's regression, not just an equivalent local test standing
in for it. `clang-format --dry-run --Werror` against OCCT's own `.clang-format` reports zero
violations on both changed files. All three checks re-run and re-confirmed after adding the
`face1`/`face2` nullify (PR #909 review): same five/five, same `FuseConeLoftWithBox_DegeneratedEdge`
pass.

Filed upstream as [OCCT#1462](https://github.com/Open-Cascade-SAS/OCCT/pull/1462). **Note on
process, not on the fix**: an earlier session had opened a same-repo
staging PR on the `gsdali/OCCT` fork itself ([gsdali/OCCT#1](https://github.com/gsdali/OCCT/pull/1),
that fork's first and, now, only PR) to CI-validate a first attempt before submitting upstream,
that attempt's null-face guard is what regressed `FuseConeLoftWithBox_DegeneratedEdge` (see above).
Staging a PR on our own fork isn't how any other carried patch in this file was validated; every one
went straight from local override-link testing to the real upstream PR. gsdali/OCCT#1 is closed as
erroneous; OCCT#1462 above is the only submission.

**Retire** once the bundled OCCT includes this fix.

**Pin consequence**: the pinned `v2.0.0` release asset has all fifteen patches through `0025`
baked in (`Package.swift`'s own census: "ALL FIFTEEN ARE VERIFIED PRESENT IN THE PINNED ASSET").
`0026` is carried on disk only, the first patch since `0022`-`0025` themselves were folded into
that release to sit outside the pin. Watch for it at the next kernel re-pin.

## 0027-BRepOffsetAPI_ThruSections-CreateSmoothed-section-edge-count-guard-913.patch

**Fixes the upstream OCCT defect behind [#913](https://github.com/SecondMouseAU/OCCTSwift/issues/913)**
,  found incidentally while investigating #910 (a different, bridge-side #905-review finding):
`ThruSectionsBuilder`, given `checkCompatibility(false)` and a section whose edge count differs
from the first section, SIGSEGVs instead of failing cleanly.

`CreateSmoothed()` derives `nbEdges`, the edge count it assumes every section has, from section 1
alone (or section 2, if section 1 is a punctual/degenerate vertex section). It allocates `shapes`,
an `NCollection_Array1<TopoDS_Shape>` sized exactly `nbSects * nbEdges`, then fills it by walking
each section's wire with a `BRepTools_WireExplorer`, incrementing a running index with **no bounds
check**. Nothing enforces that every section actually has `nbEdges` edges: `BRepFill_CompatibleWires`
(via `checkCompatibility(true)`, the default) normally reconciles differing edge counts across
sections before `CreateSmoothed()` ever runs, but `checkCompatibility(false)` skips that entirely.
A section with a **different** edge count than section 1 goes one of two ways:

- **More edges**: the fill loop walks the array straight past the end of `shapes`, an
  out-of-bounds write, corrupting adjacent heap memory rather than raising a catchable failure.
- **Fewer edges**: no overrun (the total write count can still land inside `shapes`' bounds), so
  `Build()` reports success today, but with per-section strides silently misaligned to different
  geometry than intended. Confirmed directly: a 2/1/3-edge three-section input under
  `checkCompatibility(false)` reports `Build() == true` and `Shape().IsValid() == false` against
  the stock library, deterministically, no process-state dependency (PR #915 review finding 3,
  the first version of this patch's own SemVer note undersold this, describing only the crashing
  direction).

**Reached only with 3+ sections.** With exactly 2 sections, `Build()` always takes the
`CreateRuled()` path instead (`if (myWires.Length() == 2 || myIsRuled) CreateRuled(); else
CreateSmoothed();`), which builds its shell via `BRepFill_Generator`, a different mechanism that
doesn't share this fixed-stride allocation. A single `Build()` call with all mismatched (more-edges)
sections present from the start does **not** reliably crash even though the identical out-of-bounds
write still occurs; what actually varies is process/allocator state at the time of the overrun
(confirmed directly: instrumenting the fill loop shows the write index reaching one past
`shapes.Upper()` either way, but a from-scratch process quietly lands the write in
unmapped-but-harmless heap slack where a process that already ran one successful `Build()` call does
not). Symptom, not cause: this made the defect look like it needed a *reused* builder when it
doesn't, any 3+-section `checkCompatibility(false)` call with mismatched edge counts carries the
same latent corruption (or, in the fewer-edges direction, the same silent misalignment,
deterministically regardless of process state).

**Fix:** before allocating `shapes`, walk every non-punctual section and count its edges; on a
mismatch (an inequality test, not a "too many" test, deliberately symmetric, since both directions
are the same underlying contract violation and only one of them used to crash), set `myStatus` to
`BRepFill_ThruSectionErrorStatus_ProfilesInconsistent` and return, matching the early-return idiom
this function already uses two lines below (`TS.IsNull()` -> `myStatus = Failed; return;`). Punctual
end sections (`AddVertex()`, e.g. a cone's apex) are exempt, matching the existing
`w1Point`/`w2Point` handling throughout the rest of the function, a point section legitimately has
a different edge count and the fill loop's punctual branch doesn't walk it the same way: that branch
repeats the section's own edge `nbEdges` times to fill its slots, so it needs at least one edge to
exist, not zero (PR #915 review finding 11, an earlier draft of this entry, and the patch's own
first-draft comment, said "(zero) edge count"; `AddVertex()` creates a wire with exactly **one**
degenerate edge). `w1Point`/`w2Point` themselves are computed by a pre-existing loop that is
vacuously `true` for a wire with no edges at all, not reachable through any wrapper this project
ships (a `Wire` needs at least one edge to exist), but the guard checks for at least one edge before
exempting a section as punctual rather than trusting that classification unconditionally (PR #915
review finding 4; attempted to reproduce a live crash for this specific case via both a fresh and a
reused builder and could not. OCCT's own pipeline handles a genuinely empty wire more gracefully
than the code reading alone suggested, but the added check is correct and cheap regardless of
whether today's fill loop actually reaches the unguarded path it describes).

The guard shares its punctual-section test (`isPunctualSection`, a local lambda) with the
pre-existing fill loop 15 lines below, which used to duplicate the same two-clause boolean
expression separately (PR #915 review finding 9), hoisted so the two cannot silently drift apart on
which sections take the punctual branch.

**Validation** (override-link, no full rebuild for this patch's own writeup, see `#0001`'s retired
entry for the technique; the OCCTSwift-side PR carrying this one also rebuilds the local
xcframework, since #913 asked for that explicitly rather than deferring it like `0026`): compiled
and linked both the unpatched and patched `.cxx` ahead of the pinned `libOCCT-macos.a`, across six
scenarios, the three that legitimately succeed today (matching edge counts under
`checkCompatibility(false)`; a punctual section at either end mixed with matching wire sections;
`checkCompatibility(true)` with mismatched sections, reconciled by `BRepFill_CompatibleWires` as
before) are all byte-for-byte unaffected; the original more-edges scenario now fails cleanly
(`IsDone() == false`) instead of crashing; the new fewer-edges scenario, silently "successful" with
invalid geometry on the stock library, now also fails cleanly; and a section with genuinely zero
edges at the punctual position no longer reaches the fill loop's unguarded walk. Re-confirmed all
six hold with `No_Exception`/`NDEBUG` defined (matching a Release build configuration close to what
the shipped archive itself was likely built with): the fix eliminates the out-of-bounds write
itself, so it does not depend on `Standard_OutOfRange`'s range check being compiled in.
`clang-format --dry-run --Werror` against OCCT's own `.clang-format` reports zero violations on
both changed files.

**The zero-edge-at-punctual-position scenario is a code hardening, not a proven-live fix.**
Committed only the fewer-edges GTest, not a zero-edge one: the fewer-edges scenario genuinely fails
`EXPECT_FALSE(IsDone())` against the pristine, unpatched source (proved first, per this project's
own "prove the test fails" convention, before writing the fix), but a from-scratch equivalent for a
genuinely empty wire at the punctual position passes *even against pristine, unpatched code*,
something else downstream (most likely `TotalSurf()`'s own null-surface guard, a few lines below,
reacting to whatever a degenerate empty-wire input produces) already reports `IsDone() == false`
for it today, by a different and unconfirmed mechanism, independent of this patch. The explicit
`hasAnyEdge` check is kept anyway (it is correct regardless, and cheap), but no committed test
claims to be proof it closes a live gap, because the one written could not be made to fail without
it, see finding 4 in the PR #915 review thread for the full attempt, including a reused-builder
variant that also did not reproduce a crash.

**SIGSEGV vs. SIGBUS** (PR #915 review finding 12): both signals were genuinely observed for the
more-edges overrun, in different binaries, and that is not a contradiction to reconcile down to one
,  it's exactly what heap corruption looks like. The standalone from-scratch C++ reproducer (its own
`backtrace_symbols_fd`-based signal handler installed) reported signal 11 (SIGSEGV) consistently.
The upstream GTest (`MismatchedSectionEdgeCountFailsCleanlyWithoutCheck`, linked against the stock
archive with no custom handler, OS default handling) reported signal 10 (SIGBUS). Same defect, same
out-of-bounds write, two different binaries with different allocator/memory layout at the moment of
the overrun, which of the two manifests is exactly the kind of detail this defect's own root-cause
section says depends on process/allocator state, not something either transcript got wrong.

Filed upstream as [OCCT#1466](https://github.com/Open-Cascade-SAS/OCCT/pull/1466).

**Retire** once the bundled OCCT includes this fix.

## 0028-GeomPlate_BuildPlateSurface-uninitialised-G0-G1-G2-errors-1018.patch

**Fixes the upstream OCCT uninitialised read behind
[#1018](https://github.com/SecondMouseAU/OCCTSwift/issues/1018)**: `GeomPlate_BuildPlateSurface`'s
`G0Error()`, `G1Error()` and `G2Error()` return uninitialised members after a `Perform()` whose
constraints were all point constraints.

`myG0Error` / `myG1Error` / `myG2Error` have no in-class initialiser and none of the three
constructors assigns them. `VerifSurface()` is their only writer, and `Perform()` calls it only on
the branch that has at least one curve constraint (`GeomPlate_BuildPlateSurface.cxx:684`). The
point-only branch (`:700-727`) ends with `VerifPoints(di, an, cu)`, which computes the same three
deviations into locals and discards them. So a point-only plate leaves all three members untouched
and all three accessors read whatever was in that memory.

**Measured**, not inferred, at the pinned kernel
([`Scripts/repro/1018-geomplate-uninitialised-errors/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/1018-geomplate-uninitialised-errors)):
placement-new the class over a buffer filled with `0x5A` and the pattern (`1.78388675173e+127` read
back as a double) survives the constructor **and** a point-only `Perform()` in all three members,
which is only possible if nothing wrote them. On the stack instead, the same fixture gives three
builds that agree with each other inside one process and disagree with the next process's three, and
the numbers change again on every run, which is what distinguishes an uninitialised read from a
wrong computation. `stock.txt` and `stock-second-run.txt` are one such pair; no specific value is
quoted here, because re-running the script produces different ones. That matches the three consecutive `Surface.plateErrors` calls #1018 quotes from before
its deletion (`1.9355577472e-313`, `-3.105038551588571e+231`, `-nan`).

**Fix, four parts.**

1. The three members get in-class initialisers, so the accessors are defined before the first
   `Perform()` rather than reading the caller's memory.
2. `Perform()` clears them alongside the `myGeomPlateSurface.Nullify()` it already does on entry, so
   a build that returns early does not report the previous build's deviations. Two early returns
   precede `VerifSurface()` even on the curve branch (`UserBreak()`, and a `Plate_Plate` solve that
   did not converge), and `Plate_Plate::Init()` leaves `IsDone()` true, so `IsDone()` does not warn
   a caller off that case. **The first draft of this patch left that gap and argued for it**, on the
   grounds that closing it meant deciding what `IsDone()` should report after a cancel. The PR's own
   pre-PR review pointed out that the reset needs no such decision, and it does not: it changes
   nothing on either successful path, since `VerifSurface()` zeroes the three on the curve branch
   before its own max loop and the point-only branch assigns them below.

   **What the reset does report is `0`, and `0` is not a measurement**, which is the
   `Scripts/census-unmeasured-values.py` shape this same patch's part 3 exists to avoid. It is
   defensible here for a reason that was checked rather than assumed: on every path that leaves the
   three at `0`, `Surface()` is null too. `Perform()` nullifies it on the same entry, the
   zero-constraint and `UserBreak` returns all precede the `myGeomPlateSurface = new
   GeomPlate_Surface(...)` assignment, and a `UserBreak` on a later loop iteration leaves the
   previous iteration's `VerifSurface()` values rather than the reset's. So "no result" stays
   observable through the accessor callers already have, and `0` is never the only thing a caller is
   given. A sentinel would have been the alternative, and it would change the accessors' return
   contract for every existing caller, which is not this patch's to do.
3. The point-only branch assigns the deviations `VerifPoints()` just measured instead of discarding
   them. They are the only deviations that build produces, so this reports the measurement rather
   than substituting a zero, which is the `Scripts/census-unmeasured-values.py` failure class
   (#726). Measured on a 25-point wavy grid the real answer is `1.74210553841e-12` rather than `0`,
   and on nine order-1 constraints off a sphere `8.00593208497e-16` (G0) and `6.0044719032e-16`
   (G1).
4. `VerifPoints()` accumulates each deviation as a maximum over the point constraints instead of
   overwriting it. Without this, part 3 would put "the last constraint's deviation" behind an
   accessor documented as "the max distance / angle / difference of curvature between the result and
   the constraints", so it is required for part 3 to be correct rather than extra scope. Both of its
   call sites discarded the values before, so nothing observable changes for the curve branch. The
   fixture separates the two: max `1.74210553841e-12` against last `1.57145571589e-12` at order 0,
   and max `6.0044719032e-16` against last `3.05083725475e-16` for the order-1 angle.

**The curve branch is deliberately left alone.** `VerifSurface()` keeps writing the three members
from the curve constraints only, and the `VerifPoints()` call the curve branch makes when it also
has point constraints stays discarded. This is not an oversight: `BRepFill_Filling::Build()`
consumes `G0Error()` for `dmax` (applied as a vertex tolerance via `BB.UpdateVertex`) and for
`seuil` (the `GeomPlate_PlateG0Criterion` threshold), so folding point deviations into a mixed build
would move real geometry, which is a separate behavioural question from the uninitialised read.
The reproducer's section D is the control for that: a curve-only plate reports
`2.08788369733e-05` and a curve-plus-points plate `0.00104645741524`, identical before and after.

**Reachability here.** `BRepFill_Filling::G0Error()`/`G1Error()`/`G2Error()` forward straight to
this class (`BRepFill_Filling.cxx:814-837`) and `OCCTFillingG0Error`/`G1Error`/`G2Error` read them
for `FillingSurface.g0Error`/`g1Error`/`g2Error`. That path is safe today by a chain of three
independent facts rather than by design: `Build()` returns early with `myIsDone = false` on an empty
boundary, so its plate always has a curve constraint; `myIsDone` follows `myPlate.IsDone()`, so a
failed solve also reports not done; and the three bridge functions check `IsDone()` before reading.
None of the six bridge sites that construct a `GeomPlate_BuildPlateSurface` directly calls the
accessors, and `OCCTGeomPlateErrors`, which did, was deleted by #999 (PR #1015). So this patch fixes nothing
observable in OCCTSwift today; it is carried because the defect is live upstream and because that
chain is the kind of accidental protection this project keeps finding on the wrong side of.

**Validation.** Override-linked the patched translation unit ahead of the pinned archive (see
`run.sh`): every value in the reproducer moves exactly as described above, and section D's curve
branch is byte-identical. Four new GTests in the class's existing
`GeomPlate_BuildPlateSurface_Test.cxx` (`PointOnlyConstraintsReportMeasuredErrors`,
`PointOnlyErrorsAreMaximaNotTheLastConstraint`, `ErrorsAreZeroBeforePerform`,
`CancelledRebuildDoesNotReportThePreviousErrors`), each recomputing the expected value from the
built surface rather than hard-coding it, so none pins a platform-specific number. `run-gtest.sh`
runs them both ways, unfiltered, so the file's six pre-existing cases are exercised on both sides
too: **6 passed / 4 failed** against the unpatched sources and **10 passed** against the patched
ones (`gtest.txt`). Both runs compile the class out of `Libraries/occt-src`, applying this patch to
a scratch copy for the second, so neither depends on which branch the upstream checkout is sitting
on; the GTest source is the only thing taken from that checkout, and the script checks it by name
for all four cases before running. `ErrorsAreZeroBeforePerform` uses the `0x5A` placement-new buffer
deliberately: an uninitialised member can read `0` by luck (it did, for `G2Error()`, in the
unpatched GTest run), so a plain construction would be a test that passes for the wrong reason.
Part 2 was isolated separately rather than trusted to the all-or-nothing run: with the patch applied
and **only** the `Perform()`-entry reset removed, exactly one case fails, and it fails reporting
`1.7421055384149805e-12`, the first build's own deviation, which is the stale-value mechanism itself
rather than a coincidence.
`clang-format --dry-run --Werror` against OCCT's own `.clang-format` reports zero violations on all
three changed files. `GeomPlate_BuildPlateSurface.cxx` and `.hxx` are byte-identical between the
pinned `V8_0_1` tree and current upstream `master` (`7d2efad9c`), checked rather than assumed.

**Not in the pinned asset.** `Package.swift` pins the v3.0.0 release asset, which carries
`0010`-`0012` and `0014`-`0027`, so `ci.yml`'s `build-and-test` never sees this patch. That is
#585's shape and is stated here rather than left to be discovered. One narrowing, measured rather
than assumed: `kernel-integration.yml` triggers on `Scripts/patches/**`, so the PR carrying this
patch does get `V8_0_1` plus all nineteen built from source and the full suite run against that
binary. It proves the patch applies, compiles and regresses nothing; it cannot prove the fix works,
because the defect has no Swift-reachable path left after #999 (PR #1015) deleted
`OCCTGeomPlateErrors`, and it does not run on any later PR that leaves `Scripts/patches/` alone. A
rebuilt asset would buy no Swift-side coverage either, for the same reason: the upstream GTests are
this patch's only coverage anywhere.

Filed upstream as [OCCT#1481](https://github.com/Open-Cascade-SAS/OCCT/pull/1481).

**Retire** once the bundled OCCT includes this fix.

## 0029-XCAFDoc_Datum-point-read-from-plane-array-1022.patch

**Fixes the upstream OCCT defect behind
[#1022](https://github.com/SecondMouseAU/OCCTSwift/issues/1022)**: `XCAFDoc_Datum::GetObject` builds
the datum's point from `aLoc`, the array the `ChildLab_PlaneLoc` block above it fills, instead of
`aPnt`, the point's own.

```cpp
gp_Pnt aP(aLoc->Value(aPnt->Lower()),        // aLoc, not aPnt
          aPnt->Value(aPnt->Lower() + 1),
          aPnt->Value(aPnt->Lower() + 2));
```

`XCAFDoc_GeomTolerance::GetObject`'s block is otherwise identical and reads
`aPnt->Value(aPnt->Lower())`, so this is a one-character divergence rather than a shared idiom.

**Two faces, and they are separate defects with separate triggers**, which is why the fix carries a
test for each rather than one for the crash.

1. **A wrong answer when the datum has both.** Measured: plane location `(6,6,6)` and point
   `(7,7,7)` written, `point=(6,7,7)` read back. The stored point is not recoverable. A guard that
   only stopped the crash would leave this in place, which is the reason it is tested on its own.
2. **An uncatchable SIGSEGV when the datum has a point and no plane.** `aLoc` is declared before the
   plane block and assigned only by a successful `FindAttribute` there, so it is null when the point
   block dereferences it. An OS signal, not a `Standard_Failure`, so the bridge's `catch (...)`
   cannot absorb it.

**Reachability, measured rather than inherited from the report.** Both crashing sections of the
reproducer read the datum with exactly the three calls `occtDocumentDatumObjectAt` makes
(`GetDatumLabels`, `FindAttribute`, `GetObject`). **Seven** bridge functions route through that
shared helper since #1004 (PR #1025) hoisted it, and five of them are write paths, so the exposure is not
read-side only: `OCCTDocumentGetDatumInfo`, `OCCTDocumentGetDatumModifier`,
`OCCTDocumentSetDatumPosition`, `OCCTDocumentSetDatumModifiers`,
`OCCTDocumentSetDatumModifierWithValue`, `OCCTDocumentSetDatumTarget`,
`OCCTDocumentSetDatumTargetPlacement`. The helper calls `GetObject()` before any caller can look at
what it returned, so a write that never touches the point still takes the crash. Being one helper is
also why a guard is one site rather than seven.

- **A STEP import alone cannot produce the crashing shape.** `STEPCAFControl_Reader` sets a datum
  plane and never a datum point: its only `SetPoint` calls are on an
  `XCAFDimTolObjects_DimensionObject`, a different class, and the datum object's enumerated
  mutations are `SetName`, `SetPosition`, `SetModifiers`, `SetModifierWithValue` and the datum
  target ones. A STEP-imported datum is the safe shape.
- **An OCAF load can, and the reproducer's section D proves it** rather than arguing it: the same
  point-only datum is saved to BinXCAF, reloaded into a fresh `TDocStd_Application`, and crashes on
  the reload. `HasPlane()` and `HasPoint()` are independent flags and `SetObject` writes the two
  blocks independently, so this is what the public OCCT API produces, not a hand-forged label tree.
- **Nothing in this repo authors it today.** `OCCTDocumentCreateDatum` sets a name, a position and
  a `DatumModifWithValue_None` pair, and nothing that reaches either branch (#1004's own comment
  explains why those two are needed and why the datum-target setters are deliberately left alone).
  So every datum this package writes takes neither branch. That is a property of the current write
  surface, not of the read path, and it is the only reason the existing suite does not crash.
- **The STEP writer is a second reader of the same accessor.** `STEPCAFControl_Writer` calls
  `GetObject()` on every datum in three places, so exporting a document holding such a datum takes
  the same crash.

**A bridge-side guard is possible and is reported rather than shipped.** The reason is an
ownership boundary rather than a judgement that the guard is wrong: `OCCTBridge_Document.mm` is held
by a concurrent agent in this lane, so a guard written here would race their edits in the one file
the guard belongs in. It is tracked as
[#1030](https://github.com/SecondMouseAU/OCCTSwift/issues/1030) rather than left in prose, because
this patch is in no built kernel and the crash is uncatchable, so nothing protects a consumer
meanwhile. The check has to precede `GetObject()`, and
`XCAFDoc_Datum` exposes no `HasPlane()`, so the only way to ask is the label's children:
`ChildLab_PlaneLoc` and `ChildLab_Pnt` are values of a **file-local anonymous enum**, tags `14` and
`17` at this pin, invisible from the header. A guard would skip the datum when `FindChild(17,
false)` holds a length-3 `TDataStd_RealArray` and `FindChild(14, false)` holds no
`TDataStd_RealArray` (only `ChildLab_PlaneLoc` matters, since the kernel's `&&` chain assigns
`aLoc` before testing `ChildLab_PlaneN`). Cheap and precise, at the cost of hard-coding two private
tags that upstream can renumber with no compile-time signal here. `XCAFDoc_Datum::GetName()` is not
an alternative: it returns the legacy `myName` that `SetObject` never writes, so swapping it in
would return an empty name for every datum this package or the STEP reader creates.

**Validation.** `run.sh` builds the reproducer against the pinned archive and against the patched
translation unit override-linked ahead of it: section A goes from `(6,7,7)` to `(7,7,7)`, sections C
and D go from SIGSEGV to `point=(7,7,7)`, and section B's plane-only control is identical either
way. Three GTests in the existing `XCAFDoc_GDT_Test.cxx`
(`GdtDatum_PointIsReadFromItsOwnArray`, `GdtDatum_PointWithoutPlane`, `GdtDatum_PlaneWithoutPoint`)
are run both ways by `run-gtest.sh`, so the file's eight pre-existing cases are exercised on both
sides. Unpatched the run is split in two, because `GdtDatum_PointWithoutPlane` takes the whole
process down with a SIGSEGV and gtest cannot catch one: ten cases in the first invocation, of which
the value case fails and the plane-only control plus all eight pre-existing ones pass, and the crash
case alone in a second, exiting 139. Patched, **all eleven pass in one unfiltered run**.
`clang-format --dry-run --Werror` against OCCT's own `.clang-format` reports zero violations on both
changed files. `XCAFDoc_Datum.cxx` is byte-identical between the pinned `V8_0_1` tree and current
upstream `master` (`7d2efad9c`), checked rather than assumed.

**Not in the pinned asset**, same as `0028`: `ci.yml`'s `build-and-test` resolves the pinned
kernel and never sees it. `kernel-integration.yml` does build this patch on the PR that carries it,
which proves it applies, compiles and regresses nothing, but the suite cannot exercise the fix:
`OCCTDocumentCreateDatum` cannot author a datum that reaches either branch, so no Swift test can
reach the defect without a new write path. Unlike `0028`, that gap matters, because this one is an
uncatchable crash a consumer can reach through an OCAF load. That is what #1030 is for.

Filed upstream as [OCCT#1483](https://github.com/Open-Cascade-SAS/OCCT/pull/1483).

**Retire** once the bundled OCCT includes this fix.

## 0030-TopoDS_TShape-myState-atomic-1154.patch

**Fixes the upstream OCCT data race behind
[#1154](https://github.com/SecondMouseAU/OCCTSwift/issues/1154)**: `TopoDS_TShape::myState` packs
the shape type and eight boolean flags (Free, Modified, Checked, Orientable, Closed, Infinite,
Convex, Locked) into one plain `uint16_t`, and every getter/setter reads or read-modify-writes it
with ordinary, non-atomic bitwise operations.

A `TopoDS_TShape` is not private to one `TopoDS_Shape`: boolean operations (`BRepAlgoAPI_Fuse` and
siblings) routinely produce a result that shares edge/face TShapes with its inputs, so the same
instance is reachable from several `TopoDS_Shape` handles at once, in ordinary concurrent use, not
a misuse. Two threads mutating two different flags on the same instance race on the same 16-bit
word: both can read the same stale value before either writes back, and whichever write lands last
silently discards the other thread's update, a non-atomic read-modify-write lost update.

**Fix.** `myState` becomes `std::atomic<uint16_t>`. Every getter loads with
`std::memory_order_acquire`; `setBit()` becomes a `compare_exchange_weak` retry loop releasing on
success. Confirmed, not assumed, that `std::atomic<uint16_t>` is the same size and alignment as the
`uint16_t` it replaces on this platform and always lock-free (`sizeof`/`alignof` both 2,
`is_always_lock_free` 1), so no other member's layout changes, since `myState` is the class's last
data member. No public signature changes.

**Copy-constructibility, checked rather than assumed.** `std::atomic<uint16_t>` has no copy
constructor, so `TopoDS_TShape`'s implicitly-generated copy constructor and copy-assignment operator
become implicitly deleted; `Standard_Transient` (the base) *does* define a working public copy
constructor, so the design does not rule out by-value copies elsewhere in the hierarchy on its face.
Checked two ways: an exhaustive grep across the entire `Libraries/occt-src/src` tree for
`TopoDS_TShape` and each of its eight concrete subclasses, filtered to exclude
`occ::handle<...>`/`Handle(...)`/pointer/reference/declaration/RTTI-macro occurrences, found zero
by-value uses anywhere; and a real compile check, 22 `.cxx` files (all nine in `TKBRep/TopoDS/` plus
`TopExp.cxx`, `TopExp_Explorer.cxx`, `BRepTools.cxx`, `BRep_Builder.cxx`,
`BRepAlgoAPI_BooleanOperation.cxx`, `BRepBuilderAPI_MakeShape.cxx`, `ShapeFix_Shape.cxx`) compiled
cleanly against the patched header placed ahead of the xcframework's own copy. Nothing in the tree
copies a `TopoDS_TShape` by value.

**Validation.** `Scripts/repro/1154-topology-flag-race/occt_1154_stress.cpp`, under ThreadSanitizer,
two scenarios: a hand-picked shared `TShape*` with direct flag calls, and a real `BRepAlgoAPI_Fuse`
result sharing TShapes with its inputs. Unpatched, both race on every run (`run.sh before`), at both
light and heavy thread/iteration counts; patched, both are clean across multiple separate runs at
higher load than the failing ones (`run.sh after`; 0/2 and 0/2, all exit 0). A GTest,
`TopoDS_TShape_Test.ConcurrentFlagMutationsAreNotLost` (added to the existing
`TopoDS_TShape_Test.cxx`; `gtest-addition.diff` in the repro directory is the exact addition, not
carried here since GTest source never is), stresses one shared TShape from seven threads each owning
one flag: unpatched it fails intermittently (1, 2, 4, 6 lost updates observed across four runs, never
0); patched, always 0 across six runs. All eight pre-existing cases in the file pass on both sides.
`clang-format --dry-run --Werror -style=file:Libraries/occt-src/.clang-format` against both the
patched header and the modified test file reports zero violations. See
[`Scripts/repro/1154-topology-flag-race/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/1154-topology-flag-race)
for the full writeup, transcripts and reproducer.

Filed upstream as [OCCT#1548](https://github.com/Open-Cascade-SAS/OCCT/pull/1548) against `master`, a fix PR (override-link validated, not yet in a rebuilt xcframework when written).

**Retire** once the bundled OCCT includes this fix.

## 0031-bspline-adaptor-cache-thread-safety-1153.patch

**Fixes the upstream OCCT data race behind
[#1153](https://github.com/SecondMouseAU/OCCTSwift/issues/1153)**, on the second attempt: PR #1322
first tried this fix and was rejected on six review findings, the most serious a genuine
self-deadlock. This patch is a rewrite from scratch, not a fixup of #1322's content; #1322's own
branch/patch never merged and is not part of this repo's history.

`BSplCLib_Cache`/`BSplSLib_Cache` (backing `GeomAdaptor_Curve`/`GeomAdaptor_Surface` for BSpline
and Bezier curves/surfaces) cache polynomial coefficients per span for evaluation performance, and
every method touching that mutable cache state (`BuildCache`, `D0`-`D3`, the `*Local` overloads)
was `const` and completely unsynchronized. A second, independent race sits one layer up:
`GeomAdaptor_Curve`/`GeomAdaptor_Surface`'s `EvalD0`-`EvalD3`/`D0`-`D2` do an unsynchronized
check-then-act on the `Cache` handle (`if (Cache.IsNull() || !IsCacheValid(u)) RebuildCache(u);`),
so two threads sharing one adaptor can both replace the handle and race on it directly, independent
of anything inside the cache object itself.

**Finding 1 (self-deadlock).** #1322's patch wrapped every `BSplCLib_Cache` method body in
`Locked(myMutex, [&]{...})`, backed by a plain `std::mutex`. `D1()`/`D2()`/`D3()` (and the
protected `calculateDerivative()`) each lock once, then call a `*Local`/`calculateDerivativeLocal`
overload that is *itself* a public entry point and locks the same non-recursive mutex again on the
same thread: undefined behavior, and a guaranteed hang in every real implementation, on the very
first derivative call, single-threaded, no concurrency needed to observe it. Confirmed by direct
reproduction against #1322's actual patch content (`Scripts/repro/1153-bspline-adaptor-cache/deadlock_before.txt`),
not by reasoning about the code: a single-threaded `D1()` call never returns; an external-timeout
probe (background process + `pgrep`, since GTest's own timeout mechanisms do not reliably terminate
a thread genuinely blocked inside a system mutex) confirms it is still alive seconds later.

**Fix: `std::recursive_mutex`, chosen over the lock-once refactor.** Both are legitimate options;
recursive was chosen because `D0Local`/`D1Local`/`D2Local`/`D3Local` (and `calculateDerivativeLocal`)
are genuinely dual-role in this API — each is documented as a public entry point in its own right
(for a caller that already has a pre-computed local parameter) *and* is called internally by the
flat-parameter overloads. A lock-once design would need every such method split into a thin public
locking wrapper plus a private unlocked twin, doubling the method count across two classes for a
change whose only goal is correctness, not restructuring the public surface. `std::recursive_mutex`
fixes the actual defect with the smallest, most reviewable diff: every method keeps its exact
existing body, wrapped in the same `Locked()` helper #1322 used, with only the mutex type changed.
This project has precedent for the identical tradeoff: the `Storage_Schema`/`#374` entry above
chose a recursive mutex for the same reason (a critical section that calls back into sibling locked
methods on the same thread).

**Finding 2 (false scope claim, now genuinely fixed).** #1322's commit message and PR body claimed
all four classes were protected; the actual diff touched only `BSplCLib_Cache`. This patch fixes
`BSplSLib_Cache` for real, confirmed by reading its actual structure (`BSplSLib_Cache.cxx`) rather
than assuming symmetry with its curve-side twin: its `D1()`/`D2()` do *not* themselves nest into
`D1Local()`/`D2Local()` the way the curve side's do (they duplicate the computation inline instead),
so only `D0()`→`D0Local()` has the nesting shape finding 1 describes — a narrower exposure than
`BSplCLib_Cache`'s, but real, and the same `Locked()`/`std::recursive_mutex` pattern is applied
uniformly to all six of its methods regardless, since a recursive mutex is correct whether or not a
given method happens to nest.

`GeomAdaptor_Curve`/`GeomAdaptor_Surface` are fixed too, determined by reading their `.cxx` rather
than assumed necessary or unnecessary: fixing the caches' own internal mutex does nothing for the
Cache-handle race, since that race is about *which object* the `Cache` member points to, not about
serializing calls into whichever object it currently holds. Each class gets a second, independent
`mutable std::mutex myCacheMutex;`, locked around the whole check-`IsCacheValid`-`RebuildCache`-
evaluate sequence at every call site (8 in `GeomAdaptor_Curve::EvalD0`-`EvalD3`, 6 in
`GeomAdaptor_Surface::D0`-`D2`); `RebuildCache()` itself takes no lock, since every call site into
it already holds `myCacheMutex` (a "lock once" design here, unlike the caches themselves, because
nothing in `RebuildCache()` calls back into another locked entry point on the same thread). Both
classes' doc comments previously stated outright that "these evaluations are not thread-safe and
parallel evaluations need to be prevented" — updated to describe the corrected contract.

**A `std::mutex` member breaks copy semantics — checked by real compilation, not declared and
hoped.** The first attempt at this half of the fix deleted the copy constructor/assignment
operator outright, on the reasoning that these are `Standard_Transient` (handle-based) classes with
a sanctioned `ShallowCopy()` clone path. A real compile check against real, load-bearing OCCT code
(`GeomAdaptor_TransformedCurve.cxx`/`GeomAdaptor_TransformedSurface.cxx`) immediately broke: both
classes' own `ShallowCopy()` overrides do `aCopy->myCurve = aGeomCurve;` — an actual
copy-**assignment** of a `GeomAdaptor_Curve`/`GeomAdaptor_Surface` value
(`error: overload resolution selected deleted operator '='`). Fixed instead with a hand-written
copy constructor and assignment operator on each class that copy every field except the new mutex;
the copy gets a freshly default-constructed mutex, which is the only correct semantics, since a
copied adaptor's critical section is independent of the original's. Re-verified clean by direct
compilation (`clang++ -fsyntax-only`) of 8 real consumer files against the patched headers:
`GeomAdaptor_Curve.cxx`, `GeomAdaptor_Surface.cxx`, `GeomAdaptor_TransformedCurve.cxx`,
`GeomAdaptor_TransformedSurface.cxx`, `GeomAdaptor_SurfaceOfLinearExtrusion.cxx` and
`GeomAdaptor_SurfaceOfRevolution.cxx` (both real `GeomAdaptor_Surface` subclasses),
`BRepAdaptor_Curve.cxx` and `BRepAdaptor_Surface.cxx` (the two highest-traffic consumers, which
hold a `GeomAdaptor_Curve`/`GeomAdaptor_Surface` **by value**, not by handle, via
`GeomAdaptor_TransformedCurve`/`GeomAdaptor_TransformedSurface`).

**Finding 3 (the reproducer's own "0 races" claim was not evidence, for two separate reasons).**
`occt_1153_stress.cpp` only ever called `D0()` in both scenarios, never touching the
derivative-family nesting finding 1 is about, so a clean run said nothing about whether that path
was safe. Separately, #1322's own branch (not `main`, since it never merged) carried
`Scripts/tsan.supp` suppressions for `BSplSLib_Cache::D0Local`/`BSplSLib::BuildCache`/
`BSplCLib_Cache::D0` that would have masked whatever the surface scenario's D0-only run otherwise
reported. Fixed: the reproducer now cycles every iteration through `D0`/`D1`/`D2`/`D3` (curve) and
`D0`/`D1`/`D2` (surface), exercising every nesting site in both classes' public surface under load.
`main`'s `Scripts/tsan.supp` never carried the finding-3 suppression lines at all (confirmed by
grep before writing this entry, not assumed): they existed only on #1322's own, never-merged
branch, added by that PR's own reproducer commit, so there is nothing to retire here.

**A second, real bug was found and fixed while doing this, independent of #1153 itself.** The
original reproducer's `main()` declared `GeomAdaptor_Curve sharedAdaptor(curve);` *inside* the
`if (scenario == "shared_adaptor_curve") { ... }` block, while `pool` and the `t.join()` loop lived
outside the whole `if`/`else if` chain. A local variable's scope ends at its own block's closing
brace regardless of what runs afterwards, so `sharedAdaptor` was destroyed the instant that block
finished spawning threads — while every worker thread was still running against it, well before
`t.join()` ever executed. This use-after-scope bug was corrupting both the "before" and "after"
TSan results: an adaptor (including its own brand-new mutex) torn down under threads still calling
into it produces the same crash signature as the race #1153 is about, and at 16×3000 it crashed the
patched binary with a `pthread_mutex_lock` SIGSEGV inside `BSplCLib_Cache::D3` that had nothing to
do with the real fix (an ASan single-threaded control, `asan_probe.cpp`, ruled out a buffer overflow
as the cause first, which is what pointed the investigation at the scoping bug instead). Fixed by
giving each scenario its own `pool`/join loop inside its own scope, so the adaptor outlives every
thread that touches it.

**Validation.** TSan (`Scripts/repro/1153-bspline-adaptor-cache/run.sh`), both scenarios at 16
threads × 3000 iterations: **before** (stock), curve 42 races (including a genuine SIGSEGV inside
`Geom_BSplineCurve::Weights()` reached through a torn `GeomAdaptor_Curve::EvalD3`), surface 15
races; **after** (this patch), 0 races both scenarios, 48000 clean operations each, confirmed
across repeated runs. GTests added to both classes' existing `*_Cache_Test.cxx`
(`Libraries/occt-src/src/FoundationClasses/TKMath/GTests/`; `gtest-addition-bsplclib.diff`/
`gtest-addition-bspslib.diff` in the repro directory are the exact additions, not carried here since
GTest source never is): a single-threaded `DerivativeMethodsDoNotDeadlock` (hangs against #1322's
actual patch / a hand-built naive non-recursive-mutex `BSplSLib_Cache` variant, passes in
milliseconds against the fix) and a concurrent `ConcurrentRebuildAndEvaluationMatchesReference` (16
threads × 3000 iterations, each rebuilding the cache every iteration before evaluating, matching
against a single-threaded reference). Stated plainly rather than glossed over: the concurrent GTest
needed a genuine correction mid-writing (a first version that only evaluated an already-built cache
was exercising pure concurrent reads, not a data race at all, and passed against unpatched code
unconditionally), and even corrected it still passes leniently against stock code on plain hardware
without TSan, since every thread computes identical bytes, unlike #1154's bit-ownership design
where a clobbered bit is directly observable; the TSan transcript above, not this GTest, is the
authoritative evidence the race itself is gone. `GeomAdaptor_Curve`/`GeomAdaptor_Surface`'s own
layer has no GTest in this patch, a real gap noted rather than hidden; the TSan evidence above
covers it instead, and a `GeomAdaptor_Curve_Test.cxx` already exists as the natural place to add one
later (`GeomAdaptor_Surface_Test.cxx` does not exist yet).

`clang-format --dry-run --Werror -style=file:Libraries/occt-src/.clang-format`: both touched
headers clean as written; `BSplCLib_Cache.cxx`/`BSplSLib_Cache.cxx`/`GeomAdaptor_Curve.cxx`
reformatted wholesale (safe, since every line in the relevant sections is new or immediately
adjacent to new code); `GeomAdaptor_Surface.cxx` fixed surgically with `clang-format -lines=N:N`
targeting only this patch's 4 new lines, since the stock file already carries 7 pre-existing,
unrelated violations (confirmed byte-identical, same lines, in the untouched stock file) that a
whole-file reformat would have swept in as noise.

See [`Scripts/repro/1153-bspline-adaptor-cache/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/1153-bspline-adaptor-cache)
for the full writeup, transcripts and reproducer.

Filed upstream as [OCCT#1554](https://github.com/Open-Cascade-SAS/OCCT/pull/1554) against `master`, **closed and withdrawn 2026-10-05**: the maintainer (gkv311) said the per-thread `ShallowCopy` adaptor is the intended design. Carried until the retire-or-keep decision, [#3065](https://github.com/SecondMouseAU/OCCTSwift/issues/3065).

**Retire** once the bundled OCCT includes this fix.

## 0033-Interface_Static-thread-safety-mutex-1157.patch

**Fixes the OCCTSwift#1157 investigation's own scope: `Interface_Static`'s shared parameter table,
and only that.** `Interface_Static`'s backing store is `MoniTool_TypedValue::Stats()`'s `astats`, a
file-scope `NCollection_DataMap<TCollection_AsciiString, occ::handle<Standard_Transient>>` declared
in a *different* file (`MoniTool_TypedValue.cxx`), mapping parameter name to the boxed
`Interface_Static` object holding its value; the value itself lives in `MoniTool_TypedValue`'s own
`theival`/`thehval`/`theoval`, mutated via inherited, unoverridden `SetIntegerValue`/
`SetCStringValue`/`SetRealValue`. `SetCStringValue` mutates a shared `TCollection_HAsciiString`
buffer in two steps (`Clear()` then `AssignCat()`), so concurrent same-parameter writes race on the
buffer object itself, a memory-safety hazard, not only a logical one. Every STEP/IGES read/write
call (`STEPControl_Reader`/`Writer`, `STEPCAFControl_Reader`/`Writer`, `IGESControl_Reader`/`Writer`,
`IGESCAFControl_Reader`/`Writer`) reads this table repeatedly throughout the operation, not just at
entry: `BRepToIGES_BREntity`/`GeomToIGES_GeomCurve`/`GeomSurface`/`IGESToBRep_Actor`/
`CurveAndSurface`/`StepToGeom`/`XSAlgo_ShapeProcessor` all call `Interface_Static::IVal`/`RVal`/
`CVal` once per entity/curve/surface converted, and `XSControl_Controller::Customise` (run on every
`STEPControl_Reader`/`Writer` and `IGESControl_Reader`/`Writer` construction, via `SelectNorm` →
`SetController` → `Customise`) calls `Interface_Static::Items()`, a full map iteration, on every
single reader/writer construction regardless of whether the caller ever calls `SetCVal`/`SetIVal`/
`SetRVal` itself.

**Fix:** a single, function-local static, thread-safe-lazy-init (C++11 magic statics)
`std::recursive_mutex` (`StaticsMutex()`, anonymous namespace, `Interface_Static.cxx`), taken for
the whole body of every `Interface_Static` static entry point that touches `Stats()` or a
per-parameter value: `Init` (both overloads), `Static`, `IsPresent`, `CDef`, `IDef`, `IsSet`, `CVal`,
`IVal`, `RVal`, `SetCVal`, `SetIVal`, `SetRVal`, `Update`, `IsUpdated`, `Items`, `FillMap`.
`SetUptodate()`/`UpdatedStatus()` (`Interface_Static`'s own instance methods) need no separate lock,
their only three call sites (`Update`, `IsUpdated`, `Items`) already hold this one before calling
them. Recursive, not plain, because several of these call back into others declared here on the
same thread: `Init`'s `Interface_ParamMisc` branch calls `Static()`, the `'&'` edit-syntax branch
calls `Static()` then mutates the returned handle's own limit/enum fields directly, `Init(char)`
calls the `Interface_ParamType` overload then `Static()` again for the `'p'` post-check. A plain
mutex would self-deadlock the very first `STEPControl_Controller` construction, which makes ~50 such
calls under its own mutex-guarded once-only registration, several of the `Interface_ParamMisc` form
— the identical shape `0031`/`#1153`'s first, rejected patch attempt (PR #1322) hit for
`BSplCLib_Cache`, a different class, same mechanism. `Interface_Static::Standards()` (defined in a
**separate** file, `Interface_StaticStandards.cxx`, deliberately not touched by this patch: it only
ever calls through the now-locked `Interface_Static::Init`/`SetIVal`, never touching `Stats()` or a
value field itself, so two concurrent `Standards()` calls interleaving at the per-`Init()`-call
granularity are safe under the fix, whichever thread's `Init()` for a given name runs first wins
under the lock, the other's `IsBound()` check, also under the lock, sees it and returns `false`
harmlessly) needs no direct guard for this claim, confirmed rather than assumed: zero
`Interface_Static.cxx` races in any TSan run below, patched, including scenarios that still race on
`Standards()`'s own unrelated one-time flag.

**`thread_local` was considered and rejected, for a different reason than the investigation
started from.** No internal OCCT parallelism reaches this code (grepped
`TKDESTEP`/`TKDEIGES`/`TKXSBase` for `OSD_Parallel`/`OSD_ThreadPool`/`std::thread`/`tbb::`, zero hits
in the read/write call chain), so there is no caller-configures/worker-reads hazard. Instead:
`STEPControl_Controller`'s constructor, `STEPCAFControl_Controller::Init()`, `STEPControl_Controller
::Init()` (a *different* function from the constructor, called by every `STEPControl_Writer`/
`Reader`), `IGESControl_Controller`'s constructor, `IGESData::Init()`, and `Interface_Static::
Standards()` itself each gate ~50-100 `Interface_Static::Init` calls behind a one-time process-global
guard, only two of which (the two constructors) are mutex-protected. `thread_local` storage would
leave every thread but the process's first STEP/IGES caller with a permanently empty table, since
the guards themselves (not thread_local) would report "already done" and skip re-populating it on
every subsequent thread; `CVal`/`IVal`/`RVal` would silently return `""`/`0` for every parameter —
worse than the current race, invisible to a one-operation-per-thread reproducer.

**Validation.** `Scripts/repro/1157-interface-static-thread-safety/occt_1157_stress.cpp` calls the
exact `STEPControl_Reader`/`Writer`/`IGESControl_Reader`/`Writer` sequences the bridge uses (same
`Interface_Static::Set*Val` calls, same order), with no `igesMutex()`-equivalent lock. Override-link
validated against a private minimal-module TSan build (`FoundationClasses`+`ModelingData`+
`ModelingAlgorithms`+`DataExchange`, `V8_0_1` + all 32 previously-carried patches). TSan:
`step_write_independent` (8×20) 91 races + SIGABRT unpatched → 47 races + SIGABRT patched;
`iges_write_independent` (8×20) 406 races + SIGABRT unpatched → 72 races + SIGABRT patched. The
count drop alone is not the claim, grepping every run for `Interface_Static.cxx` (not "did the count
fall" but "does the class this patch targets appear in any report, anywhere") goes from reports
whose critical section is literally inside `Interface_Static::Init`'s own
`NCollection_DataMap::emplaceImpl`/`ReSize` (`MoniTool_TypedValue::Stats()`'s map) or
`SetCStringValue`'s buffer mutation, to **zero, in both write scenarios, patched**.

**This is a partial fix and its own doc comment says so.** It does not make two independent,
concurrently-running operations that set DIFFERENT values for the SAME named parameter produce
correct output: `Interface_Static` is a shared global used as an implicit parameter-passing channel
between a caller's `Set*Val` and reads many frames below it inside `Transfer()`/`Write()`, and no
accessor-level lock closes that window. Measured directly: a `cross_talk_schema_locked` scenario
(every individual `SetCVal`/`CVal` call wrapped in its own `std::mutex`, simulating exactly what a
container-level kernel fix provides) cross-talks 16000/16000 (100%), byte-identical to the fully
unlocked rate. OCCTSwift's own `igesMutex()` stays in place, unchanged, after this patch.

**The residual races prove the wider claim empirically.** `step_write_independent`'s 47 residual
races (0 touching `Interface_Static.cxx`) are in `Interface_StaticStandards.cxx`'s own
`THE_Interface_Static_deja` flag, `XSControl_Controller.cxx`'s own `static NCollection_DataMap<...>
listad` (a controller-name registry backing `Record`/`Recorded`), `STEPControl_Controller::Init()`'s
own `inic` flag, and `IFSelect_WorkSession`'s constructor (a global named `errhand`); the IGES
side's 72 add `IGESControl_Controller::Init()`'s own flag, `Interface_InterfaceModel::Template`,
`IGESData_IGESModel::GetFromAnother`, `IGESToBRep::SetAlgoContainer`/`Init`, `ShapeProcess::
FindOperator`/`Perform`, and `IGESData_GlobalSection.cxx`'s `CopyString` helper: at least nine
sibling classes across `TKXSBase`/`TKDESTEP`/`TKDEIGES` carrying the identical unsynchronized-
process-global shape. A dedicated `step_write_warmstart` scenario (single-threaded warm-up
in-process before the concurrent pool starts, so every one-time-init guard is already `true` when
the threads start — `std::thread`'s constructor is a genuine happens-before edge) confirms these are
mostly cold-start artifacts (`Standards()`'s flag, `STEPControl_Controller::Init()`'s `inic`,
`XSControl_Controller::Record` all disappear entirely, before and after the patch) but **not all of
them**: 28 races unpatched / 32 patched remain, all in `STEPControl_ActorWrite::SetGroupMode`/
`IsAssembly` and `IFSelect_WorkSession::SendAll`/its own constructor. This is structural, not a
cold-start artifact: `XSControl_Controller` registers exactly one `STEPControl_Controller` per
process by design (`Recorded("STEP")` looks up a shared singleton), so every `STEPControl_Writer`
construction, on every thread, at any point in a long-running process's life, shares that one
controller's `STEPControl_ActorWrite` (`myAdaptorWrite`), and `Transfer()` mutates its state per
call; `IFSelect_WorkSession::errhand` is written by every `XSControl_WorkSession()` construction,
unconditionally, forever. "True concurrent STEP/IGES I/O" is therefore not achievable via a minimal,
surgical patch: it would mean restructuring `XSControl_Controller`'s per-format-singleton ownership
(so `myAdaptorWrite`/`myAdaptorRead` become per-operation state) plus at least nine more classes, an
architectural project, the same class of judgment this project already reached for
`GeomPlate_MakeApprox::ApproxError()` (#597).

**Not fixed:** `thelibtv` (`MoniTool_TypedValue.cxx`'s other file-scope map, backing `AddLib`/`Lib`/
`FromLib`) has the identical shape and is unreachable from the STEP/IGES call chains this
investigation traced (its only callers are `Interface_GTool.cxx`, an unrelated registration
mechanism, and `MoniTool_TypedValue.cxx` itself). `Interface_StaticStandards.cxx`'s
`THE_Interface_Static_deja`, `XSControl_Controller.cxx`'s `listad`, `STEPControl_Controller::Init()`
's `inic`, `IGESControl_Controller`'s own constructor guard, `IGESData::Init()`'s own guard, and the
persistent `STEPControl_ActorWrite`/`IFSelect_WorkSession::errhand` races documented above are all
real, all measured, none fixed here, each a different class from `Interface_Static` and out of this
issue's named scope.

See [`Scripts/repro/1157-interface-static-thread-safety/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/1157-interface-static-thread-safety)
for the reproducer, full TSan transcripts and the complete writeup.

Filed upstream as [OCCT#1553](https://github.com/Open-Cascade-SAS/OCCT/pull/1553) against `master`, a fix PR (override-link validated, not yet in a rebuilt xcframework when written).

**Retire** once the bundled OCCT includes this fix.

## 0034-GeomFill-CoonsAlgPatch-Value-U-parameter-1515.patch

**`GeomFill_CoonsAlgPatch::Value(U, V)` sampled all four boundaries at `V`.** `bound[0]` and
`bound[2]` are the U-direction sides, per the constructor's own corner-point derivation, and the
class's derivative functions already know it: `D1U` calls `bound[0]->D1(U, ...)` and
`bound[2]->D1(U, ...)`, and `DUV` does the same. Only the plain `Value()` used `V` for those two.

The effect is not a small error. For any boundary set whose V-direction sides are straight,
`Value(U, V)` is **completely independent of `U`**, and the whole surface collapses onto the
diagonal `U == V` locus. Every sample with `U == V` is coincidentally right, which is what let it
survive.

**The fix is two lines, and OCCTSwift#1515 said it could not be.** That issue reported that a naive
swap "produces a third, different, still-wrong set of values ... because the correction-term
coefficients (`a0..a3`, and the four corner blends) would need re-deriving consistently too", and
concluded the defect needed a real re-derivation. That is wrong, and both the algebra and a
measurement say so.

Differentiating a `Value()` with `bound[0]`/`bound[2]` at `U` gives `D1U` **exactly**, every corner
coefficient included: `d/dU [a0*bound0(U)] = a0*bound0'(U)` matches `D1U`'s `bound[0]->D1(U)`
scaled by `a0`; `d/dU [a1(U)*bound1(V)] = a1'(U)*bound1(V)` matches its `bound[1]->Value(V)` scaled
by the derivative `a1`; and each of the four corner terms matches under `a3 = 1 - a1`, `a3' = -a1'`.
Since `D1U` is already correct in the shipped kernel, the `Value()` it is the derivative of is the
one this patch writes.

Confirmed numerically on a planar square
(`Scripts/repro/1515-coons-value-u-parameter/occt_1515_coons_probe.mm`), re-implementing `Value()`
with the kernel's own coefficients and only the two sampling parameters changed:

```
   u     v  |      kernel Value()     |   one-line-fixed Value()
 0.00  0.50 | (  0.500,  0.500)       | (  0.000,  0.500)
 0.50  0.00 | (  0.000,  0.000)       | (  0.500,  0.000)
 1.00  0.50 | (  0.500,  0.500)       | (  1.000,  0.500)
 0.25  0.75 | (  0.750,  0.750)       | (  0.250,  0.750)
```

The fixed column is the exact bilinear surface. No coefficient was touched.

**Blast radius.** `GeomFill_ConstrainedFilling` builds a `GeomFill_CoonsAlgPatch` but never calls
`Value()`; it evaluates through `Eval()` and fits an approximated B-spline, so its output was never
affected. The one consumer that calls `Value()` directly is OCCTSwift's own
`OCCTGeomFillCoonsAlgPatchEval`, backing `Shape.coonsAlgPatch`, which samples it across an eval
grid.

**Upstream-bound.** Filed as [OCCT#1550](https://github.com/Open-Cascade-SAS/OCCT/pull/1550) against `master`; see the note in `okf/references/carried-occt-patches.md` about
the seven OCCTSwift thread-safety PRs still open on Release 8.1.


## 0037-STEPControl-ActorRead-non-manifold-flag-per-instance-2061.patch

**Fixes a cross-thread data race on the STEP read actor's non-manifold flag**
([#2061](https://github.com/SecondMouseAU/OCCTSwift/issues/2061)).
`STEPControl_ActorRead.cxx:208` held `NM_DETECTED` as an anonymous-namespace global: reset at
`:993`, set at `:1028`/`:1041` while transferring one shape representation, and read at
`:742`/`:805` to decide whether a `COMPOUND` component is flattened into its parent or kept nested.
Per-operation state in a process global.

Upstream's own comment above the declaration already records the intended direction:

> The better way is to pass this information via binder or via TopoDS_Shape itself, however,
> this is very specific info to do so...

**The fix is a private member**, `myIsNMDetected`, with a default member initialiser. Every read and
write is already inside a `STEPControl_ActorRead` member function, so **no signature changes**. It
works because `STEPControl_Controller::ActorRead()` never assigns `myAdaptorRead` (only
`myAdaptorWrite`, `:345`), so it builds a fresh actor per call which `XSControl_TransferReader`
caches per session. Had the read actor been shared the way IGES's is, a member would have fixed
nothing.

**Measured**, override-linked against `Libraries/occt-install-tsan`, six threads x ten iterations:

| | `NM_DETECTED` race reported | Total races |
|---|---|---|
| unpatched | **5 of 5 runs** | 40 across 5 runs |
| patched | **0 of 5 runs** | 10 across 5 runs |

**What this does NOT show.** The wrong-shape outcome follows from the code and the flag
demonstrably leaks across threads, but it did not occur in ~10,000 reads across three
configurations: the reset at `:993` reliably wins the race to the same thread's read. This is a
confirmed race on a flag that gates shape construction, not a demonstrated wrong answer, and the
distinction is kept deliberately. Full method, including two fixture traps and why a setter-skewed
thread pool measured worse, in
[`Scripts/repro/2061-nm-detected/`](../repro/2061-nm-detected/README.md).

Filed upstream as [OCCT#1552](https://github.com/Open-Cascade-SAS/OCCT/pull/1552) against `master`, a fix PR (override-link validated, not yet in a rebuilt xcframework when written).

**Retire** once the bundled OCCT includes this fix.

## 0038-Interface_CheckTool-errh-per-instance-1403.patch

**Fixes a shared error-handling sentinel in `Interface_CheckTool`**
([#1403](https://github.com/SecondMouseAU/OCCTSwift/issues/1403)). `errh`
(`Interface_CheckTool.cxx:39`) decided whether `FillCheck` wraps each module `CheckCase` call in its
own `try`. The six bulk list builders clear it because they wrap the whole loop; `Check(num)` sets it
because it does not.

**It is not only a race.** The bulk builders clear the flag and never restore it, so any bulk list
operation leaves error handling off **process-wide**. A later direct `FillCheck` call, on any
instance, then runs unguarded and a `Standard_Failure` that should have been caught and reported as
a check fail escapes instead. `FillCheck` is public, so that sequence is reachable single-threaded.

Relocated to a private member; all eight sites are already inside `Interface_CheckTool` member
functions, so **no signature changes**. Same shape as `0036`.

**Measured**: `errh` reported as a racing global **7 times before, 0 after**, across the five
registered DE scenarios.

**Filed as [OCCT#1555](https://github.com/Open-Cascade-SAS/OCCT/pull/1555)** with a test that
provably fails without the fix, which is what `0039` could not manage and why the two were treated
differently.

`Interface_CheckTool_Test.ErrorHandlingSentinelIsPerInstance` has one tool run `CompleteCheckList`
and then asserts a second, untouched tool still guards its own `FillCheck`. Verified by
override-linking the unpatched `Interface_CheckTool.cxx` against an otherwise identical build:

```
Actual: it throws Standard_Failure with description "deliberate failure from ThrowingModule".
another tool's bulk list operation disabled this tool's error handling
[  FAILED  ] Interface_CheckTool_Test.ErrorHandlingSentinelIsPerInstance
```

1 failed before, 2 passed after. A second case, `FillCheckCatchesARaisingModule`, pins that the
guard is real rather than absent, so the first is not vacuous.

The machinery this needed (a raising `Interface_GeneralModule`, a protocol selecting it, a concrete
model) is why it was held at first. `Interface_CheckTool(model, protocol)` builds its own `GTool`
per instance, which is what made it tractable without leaning on global registration for the tool
itself.

**Retire** once the bundled OCCT includes this fix.

## 0039-Interface_FileReaderData-per-instance-param-cache-1403.patch

**Gives `Interface_FileReaderData` its own parameter cache**
([#1403](https://github.com/SecondMouseAU/OCCTSwift/issues/1403)). `Param()`/`ChangeParam()`
memoised the last resolved record and its base offset in three file-scope statics
(`thefic`/`thenm0`/`thenp0`), guarded by a global counter so only the most recently constructed
instance could use the memo. The declaration says why:

> Optimization : Fields not possible, because Param is const. Too bad
> So, we assume that we read one file at a time (reasonable assumption)

`mutable` removes that blocker, so the fields the comment wanted are available.

**Two things follow, and the second was not expected.** Concurrent readers stop sharing the memo.
And the optimisation starts working at all: constructing any second `Interface_FileReaderData` made
`thefic != thenum0` permanently true for the first, so every earlier instance fell back to the
uncached path for the rest of its life.

The guarded slow path computed `theparams->Param(thenumpar(num - 1) + nump)` and the fast path
computed `theparams->Param(thenp0 + nump)` where `thenp0` was that same `thenumpar(num - 1)`, so the
branch only ever chose between a cached and an uncached way of producing one value. Dropping it
loses nothing; that equivalence was checked before deleting it, which is the check `0035` taught.

**`InitParams()` now clears the memo**, which the original did not need to do. It is the only writer
of `thenumpar` after construction and the memo caches an offset read out of it, so the memo must not
outlive a write. The old code got that by accident, because constructing the next instance disabled
the memo anyway.

`thenum0` was private and referenced only here. The base subobject changes size, so both subclasses
were compile-checked: `StepData_StepReaderData` and `IGESData_IGESReaderData`.

**Measured**: `thenm0` **3 before, 0 after**; `thefic` **1 before, 0 after**.

**HELD FROM UPSTREAM, decided 2026-09-21. Not to be filed as-is.**

No test can demonstrate this change. The guarded and unguarded paths always computed the same value,
which is why the branch could be deleted at all, so **no deterministic single-threaded test
distinguishes before from after**. A draft test that appeared to, asserting the memo does not outlive
`InitParams`, was found to pass without the fix: `Interface_ParamSet::Append` appends to the end
(`thenbpar++`), so a stale base offset still resolves to the right slot, and calling `InitParams` for
an earlier record corrupts the record table regardless, so the sequence is not meaningful use.

Offering upstream a PR whose tests cannot fail invites a review question with no good answer, and
`okf/policies/prove-the-test-fails.md` is the rule being respected rather than worked around. Carried
locally instead, where the measured race removal and the restored optimisation are the whole benefit.

**Also correcting this entry's own earlier claim**: the `InitParams()` memo invalidation is
**defensive, not a fix for a reachable bug**. `InitParams` is the only writer of `thenumpar` after
construction and callers run it *after* a record's parameters rather than before
(`StepFile_Read.cxx:153`), so a finalised record's base offset never moves and the memo cannot go
stale in documented use. The two lines make the dependency explicit and cost nothing; they close no
hole.

**Retire** once the bundled OCCT includes this fix.

## 0040-controller-one-time-init-thread-safe-1403.patch

**Fixes three unguarded one-time-init flags** in the STEP and IGES controllers
([#1403](https://github.com/SecondMouseAU/OCCTSwift/issues/1403)):

| Site | Before |
|---|---|
| `STEPControl_Controller::Init()` | unguarded `static bool inic` |
| `IGESControl_Controller::Init()` | unguarded `static bool inic` |
| `IGESControl_Controller` constructor | unguarded `static bool init` |

Two threads can both read the flag as false and both run the one-time work, which for the two
`Init()` functions means constructing and `AutoRecord()`ing a second controller under the same name.

**#1403's re-scope called this "matching STEP's existing mutex" and that was wrong.** Only
`STEPControl_Controller`'s *constructor* has a mutex; both `Init()` functions are unguarded, STEP's
included. Three sites, not one asymmetry.

All three become function-local static initialisation, which C++11 guarantees runs exactly once even
when several threads arrive together, so the check-then-act disappears rather than being locked
around. No mutex is added and STEP's existing constructor mutex is left alone.

**Re-entry checked first**, because a lambda that re-enters its own static initialisation deadlocks,
which is how the first attempt at `0031` self-deadlocked: `XSAlgo::Init`, `IGESToBRep::Init`,
`IGESSolid::Init` and `IGESAppli::Init` do not call back into either controller's `Init`, and every
caller of those is an entry point.

Carries a GTest (`XSControl_ControllerInit_Test`). It is a smoke guard rather than a demonstration:
the previous check-then-act usually also produced a working registration, because a second
`Record()` of the same controller kind returns early. The race is what TSan measures.

Not filed upstream: **held**, since no GTest can observe it. A second call of a one-time init in a shared GTest binary is unobservable. Revisit if a way to observe it appears.

**Retire** once the bundled OCCT includes this fix.

## 0041-DE-registry-maps-synchronised-1403.patch

**Synchronises two process-wide name-keyed registries**
([#1403](https://github.com/SecondMouseAU/OCCTSwift/issues/1403)):

- `listad`, `XSControl_Controller.cxx:59`, controllers by format name. `Record` does `IsBound`, then
  `ChangeFind`, then `Bind`, so two threads recording controllers can rehash under each other.
- `atemp`, `Interface_InterfaceModel.cxx:44`, template models by name. `Template()` calls
  `HasTemplate()` and then `ChangeFind`, a check-then-act across two lookups.

**A lock is the right tool here, unlike the rest of this series.** These are registries: one per
process is the design, so the state is shared deliberately rather than wrongly made global, which is
the distinction `docs/thread-safety.md` draws.

**Recursive is required, not preferred**, for `atemp`: `Template()` calls `HasTemplate()` before
reading the map, so a plain mutex self-deadlocks on the same thread.

**`astats` is deliberately excluded**, and it is the third registry of this shape. Every access
reaches it through `Interface_Static`, whose seventeen entry points `0033` already mutexes, and it
stopped being reported once `0033` was in the build. A second lock on the same data through a
different path invites lock-order inversion for no gain.

Filed upstream as [OCCT#1603](https://github.com/Open-Cascade-SAS/OCCT/pull/1603) against `IR`, with stress GTests, one of them probabilistic with a measured failure rate.

**Retire** once the bundled OCCT includes this fix.

## 0042-ShapeAnalysis-GetFaceUVBounds-null-surface-2773.patch

**`ShapeAnalysis::GetFaceUVBounds` dereferences a null surface on a face with no surface and no
edges** ([#2773](https://github.com/SecondMouseAU/OCCTSwift/issues/2773)),
`src/ModelingAlgorithms/TKShHealing/ShapeAnalysis/ShapeAnalysis.cxx:280` in the pinned tree:

```cpp
  TopExp_Explorer ex(FF, TopAbs_EDGE);
  if (!ex.More())
  {
    TopLoc_Location L;
    BRep_Tool::Surface(F, L)->Bounds(UMin, UMax, VMin, VMax);   // no null test
    return;
  }
```

**Both clauses of the input are necessary.** A surface-less face carrying a wire takes the pcurve
loop below instead, where the `Bnd_Box2d` stays void and `Bnd_Box2d::Get` raises a catchable
`Standard_ConstructionError`, so `ShapeUpgrade_ShapeDivide` reports `ShapeExtend_FAIL2` correctly.
Only the edgeless case reaches the dereference. That is the same narrowing
[PR #2776](https://github.com/SecondMouseAU/OCCTSwift/pull/2776)'s bridge predicate is built on,
and it is why the guard there tests for a surface-less **and** edgeless face rather than a null
surface.

### The behaviour chosen, and the two alternatives measured against it

**The patch raises `Standard_NullObject`. It does not return silently.** Three measurements, all
made by override-linking the changed translation unit ahead of `libOCCT-macos.a`
(`okf/policies/upstream-occt-patch-process.md` §3), no kernel rebuild:

**The function's own other failure path already raises.** `Bnd_Box2d::Get` throws
`Standard_ConstructionError("Bnd_Box is void")` when no edge yielded a pcurve, which is how the
surface-less-with-wire face is already reported. Raising makes the two surface-less input classes
agree instead of leaving one of them a dead process.

**Returning without touching the outputs does not fix the crash, it moves it.** The function is
`void` and no caller checks a status; all nine call sites read the four doubles straight afterwards.
`ShapeUpgrade_FaceDivide::SplitSurface` then dereferences the same null surface eight lines later at
`surf->Bounds(aSUf, aSUl, aSVf, aSVl)`. Measured with a third, silent-return variant built for the
comparison: `GetFaceUVBounds` hands back the caller's uninitialised doubles unchanged (`-1` in the
probe, which is what the probe had put there), and both
`ShapeUpgrade_ShapeDivide::Perform` and `ShapeUpgrade_FaceDivide::Perform` still exit 139. Silent
return is the #726 shape and a crash, rather than either one.

**A raise is catchable unconditionally; the signal is not.** `OCC_CATCH_SIGNALS` at
`ShapeUpgrade_ShapeDivide.cxx:190` is **not** inert in this build (OCCT's own
`adm/cmake/occt_defs_flags.cmake:48` adds `OCC_CONVERT_SIGNALS` on every non-Windows target), but it
converts a signal only while an `OSD` signal handler is registered, and no divide wrapper and no
`.brep` import calls `occtEnsureSignals()`. An ordinary `catch (Standard_Failure const&)` sees
`Standard_NullObject` regardless of that process state, so the `ShapeExtend_FAIL2` handler the kernel
already has starts working rather than depending on what an unrelated caller did earlier.

[`okf/policies/follow-occt-callers.md`](../../okf/policies/follow-occt-callers.md) is the rule that
settled this: the callee's source says what the value is, the callers say what it means, and here the
callers say a failure is a `Standard_Failure` to be caught and encoded, not an out-parameter to be
inspected.

### Measured, one process per case, macOS arm64 against `V8_0_1`

| case | unpatched | silent-return variant | patched |
|---|---|---|---|
| `ShapeAnalysis::GetFaceUVBounds`, surface-less edgeless face | SIGSEGV, exit 139 | returns the caller's uninitialised doubles | raises `Standard_NullObject` |
| `ShapeUpgrade_ShapeDivide::Perform`, compound holding it | SIGSEGV, exit 139 | SIGSEGV, exit 139 | `perform=0 FAIL=1 FAIL2=1` |
| `ShapeUpgrade_FaceDivide::Perform` directly, no `OCC_CATCH_SIGNALS` above it | SIGSEGV, exit 139 | SIGSEGV, exit 139 | raises `Standard_NullObject` |
| control: surface-less face **carrying a wire** | `perform=0 FAIL=1 FAIL2=1` | unchanged | unchanged |
| control: healthy box | `perform=0`, no status | unchanged | unchanged |
| control: `ShapeFix_Shape` over the same compound | `perform=0 result-null=0` | unchanged | unchanged |

Row two is the point: the patched answer is byte for byte the control in row four, which is the
verdict the kernel already reaches for the neighbouring input.

### The GTest, and proving it fails

`src/ModelingAlgorithms/TKShHealing/GTests/ShapeAnalysis_Test.cxx`, four cases: the raise, the
surface-less-with-wire neighbour (`Standard_ConstructionError`), the no-edge branch's own valid input
(a `Geom_SphericalSurface` with no wires still reports the surface's bounds, so the branch is guarded
rather than removed), and a box face for the pcurve branch. **It lives in the upstream PR only, not
in this `.patch` file**, matching `0029`: the carried patch is the kernel fix, and `build-occt.sh`
does not build OCCT's GTests.

Proved per [`okf/policies/prove-the-test-fails.md`](../../okf/policies/prove-the-test-fails.md), by
linking the same `gtest` object against each variant in turn: against the unpatched
`ShapeAnalysis.cxx` the first case takes the process down with signal 11 (exit 139) before any
other case runs; against the patched one, 4/4 pass.

### The bridge guard stays

PR #2776 guards twelve bridge functions with `occtShapeSurfacelessEdgelessFaceCount`. **That guard is
not made redundant by this patch and must not be removed.** The pinned asset does not carry `0042`,
so every consumer on a released OCCTSwift still meets the unpatched kernel, and the guard is what
keeps their process alive. It becomes redundant only at a repin, and even then it is the boundary
refusal `okf/policies/scope-boundary.md` prefers over relying on a kernel raise.

### Built locally and verified in the binary, 2026-09-27

Unlike most of this list, this patch was not left inert on disk. `Scripts/build-occt.sh` was run to
completion (all three slices, ~65 min) against a **fresh** `V8_0_1` clone, and the result was checked
three ways rather than assumed from the exit code:

- **The tree it was built from.** `docs/guides/building-occt.md`'s "Shipping a rebuild" step 1:
  all thirty patches reverse-apply, and the computed set of modified files that no carried patch
  explains is **empty**, over 78 modified files. This is a fresh clone, so it does not carry the two
  retired-patch strays that made the v4.0.0-kernel.1 asset a thirty-one-patch binary under a
  twenty-nine-patch label (#2190).
- **The fix is in the binary, by symbol.** `python3 Scripts/check-pinned-asset-patches.py --asset
  Libraries/OCCT.xcframework --require-asset` reports `0042` **CONFIRMED PRESENT** on its `literal`
  evidence in `macos-arm64`, `ios-arm64` and `ios-arm64-simulator`. The same string is absent from
  the pinned asset, which is the control. Its two findings are the `0032` and `0034-LocOpe`
  ACKNOWLEDGED rows going stale against a build that correctly lacks both, which is the expiry those
  rows exist for.
- **The reproducer, before and after, same probe and same fixtures.**
  `Scripts/repro/2773-shapedivide-surfaceless-face/run.sh` was run against the SwiftPM-resolved
  pinned asset and then against the rebuilt xcframework:

| case | pinned asset | rebuilt kernel |
|---|---|---|
| `divide-memory no` | SIGSEGV, exit 139 | `perform=false status-fail=true FAIL2=true`, exit 0 |
| `divide-file <compound>.brep no` | SIGSEGV, exit 139 | `FAIL2=true`, exit 0 |
| `divide-file <bare face>.brep no` | SIGSEGV, exit 139 | `FAIL2=true`, exit 0 |
| `facedivide-direct no` | SIGSEGV, exit 139 | `CAUGHT Standard_Failure at the CALLER: Standard_NullObject`, exit 0 |
| `facedivide-direct yes` | exit 1, `no catch was found` | caught, exit 0 |
| `uvbounds no` | SIGSEGV, exit 139 | `CAUGHT Standard_Failure at the CALLER`, exit 0 |
| `uvbounds yes` | exit 1, `no catch was found` | caught, exit 0 |
| `divide-memory-withwire`, both dispositions | `FAIL2` | unchanged |
| `shapefix`, both dispositions | `perform=false result-null=false` | unchanged |
| `step-write` / `step-read` | accepted, zero faces back | unchanged |
| `iges-write` | SIGSEGV, exit 139 | **unchanged**, and expected: a separate defect in `IGESControl_Writer::AddShape`, not this one |

**Every case that died now reports, and no control moved.** The two committed `.brep` fixtures came
back byte-identical from both runs, so the regenerated inputs are the same inputs.

Full `swift test` against the rebuilt kernel: **6,436 tests in 1,583 suites over all 18 targets, all
passed**, exit 0. The interesting result is everything **else** passing, since PR #2776's guard means
the crashing input no longer reaches the kernel from Swift at all. Run as
`env -u OCCTSWIFT_BRIDGE_PREBUILT OCCTSWIFT_LOCAL=1 swift test`, and the archive it linked was
confirmed local rather than the downloaded pin by symbol, not assumed.

### CI coverage, and the pin

**The patch is carried and locally verified, and `Package.swift` is NOT repinned at it.** A repin is
a release step with its own policy and sequencing (`okf/policies/pinned-kernel-patch-check.md`,
`docs/guides/building-occt.md`), and it needs a published release asset. So:

`ci.yml`'s `build-and-test` resolves the **pinned** asset, which lacks `0042`, and the required
status check therefore does not exercise the fix at all. `kernel-integration.yml` does: its trigger
paths include `Scripts/patches/**`, so it builds OCCT from source with this patch applied and runs
the full Swift suite against that binary, on the PR that adds it and on `main` afterwards. That
proves the patch applies, compiles and regresses nothing. **It cannot prove the fix reaches a
consumer**, because no released asset carries it.

A repin needs: a rebuild from a tree whose only modifications are the carried patches (done),
`python3 Scripts/check-pinned-asset-patches.py --require-asset` clean against that asset, the zip
uploaded as a new pre-release, **both** `url:` and `checksum:` bumped, `0042` moved into
`Package.swift`'s enumerated list (which takes `patches_pinned` to thirty and `patches_unpinned`
back to zero), and the two stale ACKNOWLEDGED rows retired. Recorded here rather than left to be
discovered.

Filed upstream as **[OCCT#1583](https://github.com/Open-Cascade-SAS/OCCT/pull/1583)** against `master`, with the
GTest, no companion issue. Prior art re-checked 2026-09-27: zero upstream issues and zero PRs
mention `GetFaceUVBounds`, `dpasukhi`'s open series is Unicode strings, math robustness and
`ApplicationFramework`, and OCCT#1514 `Data Exchange - Harden malformed input handling` (merged
2026-09-01) touches only the OBJ, STL, VRML and STEP readers plus `Standard_ReadLineBuffer`, nothing
in `TKShHealing`.

**Retire** once the bundled OCCT includes this fix.

## 0043-BRepGProp_Gauss-keeps-the-by-plane-mass-2827.patch

**The by-plane mass is computed and then discarded**
([#2827](https://github.com/SecondMouseAU/OCCTSwift/issues/2827)),
`src/ModelingAlgorithms/TKTopAlgo/BRepGProp/BRepGProp_Gauss.cxx:494-528` in the pinned tree:

```cpp
  convert(theInertia, theOutGravityCenter, theOutMatrixOfInertia, theOutMass);  // sets the mass
  if (std::abs(theInertia.Mass) >= EPS_DIM && theIsByPoint)
  {
    ...
    theOutMass = theInertia.Mass;
  }
  else
  {
    theOutMass = 0.0;                    // every by-plane call lands here
    theOutGravityCenter.SetCoord(0.0, 0.0, 0.0);
  }
```

The four-argument `convert` on the first line has already written the correct mass. The
`&& theIsByPoint` then sends every by-plane call into an `else` written for the vanishing-mass case,
which overwrites it with `0.0` and the gravity centre with `(0, 0, 0)`. The fix is to drop
`&& theIsByPoint` from the outer condition, which is also what makes the inner
`if (theIsByPoint) ... else ...` live: that `else` is unreachable today, and it exists, so the outer
condition was meant to test `EPS_DIM` alone.

**Why the inner `else` is the right formula and not just the reachable one.** For a by-point
computation `theCoeff` is a three-element translation, `theOrigin - loc`
(`BRepGProp_Vinert.cxx:238`), so the gravity centre is `theCoeff[i] + I*/mass`. For a by-plane
computation `theCoeff` is the four plane coefficients `a, b, c, d` with `d` re-based on `loc`
(`BRepGProp_Vinert.cxx:279`). Those are not a translation and must not be added to a coordinate. The
by-plane gravity centre is `I*/mass` relative to `loc`, which is what the inner `else` computes and
what the four-argument `convert` on the first line had already written. The matrix of inertia is
assigned unconditionally after the branch and does not move.

### The population, derived rather than grepped

`BRepGProp_Gauss::Compute` reaches this overload only when `myType == Vinert`, and calls the
four-argument `convert` otherwise, so `BRepGProp_Sinert` and `BRepGProp_Cinert` are untouched. Inside
`BRepGProp_Vinert` the flag is `false` at exactly three `Compute` call sites,
`BRepGProp_Vinert.cxx:285`, `:300` and `:317`, which are the bodies of the four by-plane `Perform`
overloads (`:263` forwards to `:273`, whose body is `:285`) and therefore of the four `gp_Pln`
constructors that delegate to them. Both `Compute` paths, the adaptive one at
`BRepGProp_Gauss.cxx:1101` and the plain one at `:1388`, reach this `convert`.

**OCCT has no callers of that path at all**, per
[`okf/policies/follow-occt-callers.md`](../../okf/policies/follow-occt-callers.md)'s "when OCCT does
not answer" clause. `BRepGProp.cxx:311` is the kernel's only `BRepGProp_Vinert` call site and it
passes a point. The by-plane public entry point, `BRepGProp::VolumePropertiesGK(S, Props, thePln,
...)`, goes through `BRepGProp_VinertGK` and `math_KronrodSingleIntegration`, a separate integrator
that never reaches this function. So the kernel never meets the defect itself, and the expected value
had to be measured rather than read off a call site.

### Measured, macOS arm64, before and after

`Scripts/repro/2827/probe.mm`, per face with the `BRepGProp_Domain` loaded so the integral is over
the trimmed region, alongside `VolumePropertiesGK` over the same shape as the independent
construction. The transcript against the patched kernel is committed as
`Scripts/repro/2827/patched-kernel-transcript.txt`:

| fixture and plane | `Vinert` by plane, before | after `0043` | `VolumePropertiesGK` |
|---|---|---|---|
| 10-cube, plane z = 0 | 0 | 1000 | 999.9999999999999 |
| 10-cube, plane z = -100 | 0 | 1000 | 1000.000000000002 |
| 10-cube, oblique plane | 0 | 999.9999999999999 | 1000 |
| 20x20x2 plate, radius-3 hole, z = 0 | 0 | 743.4513322353836 | 743.4513322353838 |
| cylinder r = 5 h = 10, plane z = 0 | 0 | 785.3981633974481 | 785.3981633974456 |

The by-point `Vinert` sums over the same faces are 999.9999999999998, 743.4513322353837 and
785.3981633974482, and `BRepGProp::VolumeProperties` reports 999.9999999999998, 743.4513322353836 and
785.3981633974482. So the zero was not the integrand vanishing, and not a plane placed where the
answer happens to be zero: the same three shapes through OCCT's own by-plane entry point give the
volume to the last few digits, and the patched `Vinert` now does too.

### What the by-plane mass IS, which had to be settled before anything could assert it

A value that reads as a measurement and is not one is #2827's whole character, so "replace the zero
with the number we saw" would repeat it one level up. Neither the sum nor any single face's value is
a snapshot in the regression suite; both are identities derived from the integrand and measured
against a construction that shares no code with it.

The by-plane integrand is (`BRepGProp_Gauss.cxx:340-348`)

```
dv = (n_hat . n_face) * d1 * dS,   d1 = n_hat . P - theCoeff[3]
```

with `theCoeff[3]` the plane's fourth coefficient re-based at `BRepGProp_Vinert.cxx:279`. So `dv` is
the signed volume of the column between the surface element and the reference plane, and two
divergence-theorem identities follow, neither depending on which plane was passed:

- `F = d1 * n_hat` has `div F = n_hat . n_hat = 1`, so the **per-face sum over a closed shell is the
  enclosed volume, for any plane.** The offset moves the per-face split and not the total.
- `F_x = (x * d1 - n_hat_x * d1 * d1 / 2) * n_hat` has `div F_x = x`, and that bracket is exactly the
  `Ix` integrand at `BRepGProp_Gauss.cxx:350`, so the **mass-weighted sum of the per-face gravity
  centres is the solid's own first moment**, again for any plane. This is also why the inner `else`
  the patch makes live is the right formula: the centre it writes is the column's centroid.

Measured against `BRepGProp::VolumeProperties`, which goes through a different loop and never reaches
this function. On a 20x20x2 plate with a radius-3 hole translated to (7, -3, 2), so the first moment
is not a comparison against the origin, for a plane through the origin, a plane at z = -100 and an
oblique one, all three give sum 743.45133223538 against volume 743.4513322353836 and first moment
(12638.672648, 5204.15932565, 2230.35399671) against the same three figures from
`VolumeProperties`. A 10-cube and a cylinder agree to the same precision.

**A third identity, per face rather than summed.** For a *planar* face the integral reduces to
`(n_hat . n_face) * area * (n_hat . C - d)` with `C` the face's area centroid and `d` the offset the
caller asked for, so the by-plane mass is affine in the plane offset with slope minus the face's
signed projected area. (Written with a `+` here until #2873: see below.) Measured on the plate's
seven faces with the plane normal along z: the two caps have slope +371.72566611769 and
-371.72566611769, exactly `+-area`, and the four sides and the cylindrical wall have slope 0, as
faces parallel to the normal must.

**The offset's sign is inverted, so the value is measured about the plane mirrored through the
origin.** The integrand reads `theCoeff[3]` as the right-hand side of `n_hat . X = theCoeff[3]` and
subtracts it, while `aCoeff[3] = d - n_hat . loc` fills it from `gp_Pln::Coefficients`' `d`, which
belongs to the `n_hat . X + d = 0` form. Measured on a flat cap where `mass / area` reads `d1` off
directly: the cap at z = 2 gives `d1` 2, 3, -98 and 7 for planes at z = 0, 1, -100 and 5, where the
geometric signed distance is 2, 1, 102 and -3. That is a **separate** defect from this patch, it does
not disturb either identity above (`d1` is still affine with gradient `n_hat`, which is all they
need), and it is held as [#2873](https://github.com/SecondMouseAU/OCCTSwift/issues/2873) for the same
upstream PR rather than patched here days before 8.0.2.

Two corrections to that paragraph as it first stood, both from #2873's own probe
(`Scripts/repro/2873/`). **`loc` is not a second defect.** `SetLocation` moves `d1` by nothing at the
origin, at (0, 0, 3) and at the non-axial (-4, 11, 2.5), and that is the behaviour a distance to a
plane has to have: the `- n_hat . loc` term exists to cancel the `P - loc` the integrand works in,
and it cancels exactly, before and after the sign is corrected. There is one defect here, not two.
**And it is three sites, not one:** `BRepGProp_VinertGK.cxx:219` and `:244` make the same conversion
for the Kronrod path, whose integrand subtracts it at `BRepGProp_UFunction.cxx:99`, so the upstream
hunk covers `BRepGProp_Vinert.cxx:279` and both of those. The two implementations print identical
`d1` on every row of the probe, which is what makes this a second construction rather than a re-run.

**The bridge compensated until the repin that pinned `0048`.** `OCCTBRepGPropVinertPlane` was
handed `(planeNormal, planeDistance)` and built the `gp_Pln` itself, so it built the mirrored one and
`Face.volumeInertia(planeNormal:planeDistance:)` measured about the plane the caller named. **A
kernel carrying the upstream hunk while that mirror was still in place measured about the mirrored
plane again**, so the mirror came out in the change that pinned `0048` (#3015), not in the one that
retires this patch. `BRepGPropVinertTests`' two sign assertions are what failed on #3014 when it had
not.

### CI coverage, and the pin

**Built and pinned by `v4.0.0-kernel.3`**, on the same day it was carried. It spent hours, not a
release window, as the only carried patch in the tree that had never been compiled, and the reason
it did not stay that way is that what it left exposed is a value a caller reads rather than a latent
race: `Face.volumeInertia(planeNormal:planeDistance:)` returned a fabricated `0.0` for every face and
every plane. The standing hold on repinning until OCCT 8.0.2 lands
(`okf/policies/pinned-kernel-patch-check.md`) was the argument against the rebuild, and it lost to
that.

- `ci.yml`'s `build-and-test` resolves the pinned asset, which now carries `0043`, so the required
  status check exercises it on every PR.
- `kernel-integration.yml` triggers on `Scripts/patches/**` and builds from source, and it is the
  independent check that the patch is in the binary rather than merely in the tree: building against
  the new asset locally makes #2827's regression fail at the same lines and values as that job's own
  build.
- The wasm kernel is a patch behind until the 8.0.2 rebuild, acknowledged in
  `Scripts/wasm-kernel-pin.txt` and keyed to thirty-one native patches so it expires at the next
  repin.

What the repin took: a rebuild from a tree whose only modifications are the carried patches (79
modified files against 79 patch-touched files, zero unexplained, all thirty-one reverse-applying),
`python3 Scripts/check-pinned-asset-patches.py --require-asset` against the published asset, the zip
uploaded as the `v4.0.0-kernel.3` pre-release, **both** `url:` and `checksum:` bumped, `0043` moved
into `Package.swift`'s enumerated list (taking `patches_pinned` to thirty-one and `patches_unpinned`
to none), and `Tests/OCCTAnalysisTests/BRepGProp/BRepGPropVinertTests.swift`'s pinned-zero regression replaced
by the three identities above rather than by the numbers that were observed.

**Retargeting risk at 8.0.2.** `BRepGProp_Gauss.cxx` is unmodified by every other carried patch, and
upstream `master` was byte-identical on this line as of 2026-09-29 with no issue or PR naming
`BRepGProp_Gauss`, so the hunk is expected to apply to `V8_0_2` unchanged. Re-run
`git -C occt-src apply --check` at the repin rather than assuming it.

Filed upstream as [OCCT#1587](https://github.com/Open-Cascade-SAS/OCCT/pull/1587) against `master`; the hold on upstream PRs until 8.0.2 was cancelled on 2026-10-07
(see [`okf/policies/upstream-occt-patch-process.md`](../../okf/policies/upstream-occt-patch-process.md)). **The submission carries a second
hunk**, for [#2873](https://github.com/SecondMouseAU/OCCTSwift/issues/2873): `aCoeff[3] = d - n . loc`
at `BRepGProp_Vinert.cxx:279`, and the same two lines at `BRepGProp_VinertGK.cxx:219` and `:244`, are
subtracted by the integrand, so the offset reaches it with the opposite sign to a geometric distance
and the value is measured about the plane mirrored through the origin. `loc` is not part of it: it
cancels, correctly, both before and after. This patch exposes that rather than causing it, and the
two belong in one PR because a reviewer reading the first will ask about the second. The upstream submission is where
the GTest goes; the carried patch is the one-liner alone, as `0042` was.

**Retire** once the bundled OCCT includes this fix.

## 0044-Extrema-ExtSS-ExtCS-Points-bound-against-point-sequence-2840.patch

**`Points()` reads an empty point sequence on a parallel pair**
([#2840](https://github.com/SecondMouseAU/OCCTSwift/issues/2840)). `Extrema_ExtSS` and
`Extrema_ExtCS` both count extrema with `NbExt() == mySqDist.Length()` and bound `Points()` against
that count alone, and both analytic branches append a distance with no matching point pair when the
pair is parallel (`Extrema_ExtSS.cxx:226-234`, `Extrema_ExtCS.cxx:302-306` in the pinned tree):

```cpp
  myIsPar = myExtElSS.IsParallel();
  if (myIsPar)
  {
    mySqDist.Append(myExtElSS.SquareDistance(1));   // and nothing to myPOnS1/myPOnS2
  }
```

An equidistant family has no unique witness point, so there is nothing to append. `NbExt()` then
reports 1, `Points(1, ...)` passes its range test, and `myPOnS1.Value(1)` reads an empty
`NCollection_Sequence`. The fix is the one `Extrema_ExtCC::Points` already carries as `0024`: bound
against the point sequence. The tighter bound changes nothing for a non-parallel result, since
`mySqDist` and the point sequences are appended together in every other branch.

**The fault is not in `Points()`' own bound test.** That test is a literal `throw`, live in this
Release build. What faults is `NCollection_Sequence::Value`'s `Standard_OutOfRange_Raise_if`, which
is **inline** and therefore compiled out by `BUILD_RELEASE_DISABLE_EXCEPTIONS` in whichever
translation unit expands it, here `Extrema_ExtSS.cxx`. So the read is an OS fault rather than a
throw, uncatchable in-process (#345), and
`Scripts/census-compiled-out-validation.py` has no channel that could have seen it: filed as
[#2858](https://github.com/SecondMouseAU/OCCTSwift/issues/2858).

### The family is exactly three, and generalising has nothing to generalise over

This patch is the third instance of `0024`'s shape and the question of whether to generalise rather
than copy was asked before it was written, in #2840 and answered by #2801's sweep. Every `.cxx`
under `src/ModelingData/TKGeomBase/Extrema` that mentions `myIsPar`, compared for `mySqDist.Append`
count against point-append count:

| class | sqdist appends | point appends | verdict |
|---|---|---|---|
| `Extrema_ExtCC` | 11 | 0 | #636, carried patch `0024` |
| `Extrema_ExtCS` | 4 | 6 | this patch |
| `Extrema_ExtSS` | 4 | 3 | this patch |
| `Extrema_ExtCC2d` | 2 | 0 | clean: `Points` bounds against `mynbext`, which moves in lockstep with `mypoints.Append` in both `Results` overloads |
| `Extrema_ExtElC2d` | 0 | 0 | clean: fixed-size member array bounded against `myNbExt` |
| `Extrema_ExtElC`, `Extrema_ExtElCS`, `Extrema_ExtElSS` | 0 | 0 | no appends at all |

**There is no fourth, so the shared fix has three call sites and will not acquire more.** And there
is no shared thing to put the fix in: the three classes hold their points in three different member
shapes, `mypoints` interleaved for `Extrema_ExtCC`, `myPOnC`/`myPOnS` for `Extrema_ExtCS`,
`myPOnS1`/`myPOnS2` for `Extrema_ExtSS`, with no common base and no accessor in common. A helper
over that is a new base class or a new free function for a one-line predicate, which is a larger
change to propose upstream than the three one-line bounds it would replace, and which upstream has
no precedent for in this package. So the shape is copied, deliberately, and the two remaining sites
land together rather than one at a time.

### Measured, macOS arm64, before and after

`Scripts/repro/2840/probe.mm` against the pinned `v4.0.0-kernel.3` asset with both translation units
override-linked, per
[`okf/policies/upstream-occt-patch-process.md`](../../okf/policies/upstream-occt-patch-process.md)
section 3. The transcript is committed as `Scripts/repro/2840/override-link-transcript.txt`.

| mode | before | after |
|---|---|---|
| `Extrema_ExtSS`, two `Geom_Plane`s 5 apart, `Points(1, ...)` | exit 139 | `Standard_OutOfRange`, exit 0 |
| `Extrema_ExtCS`, a `Geom_Line` 5 above a `Geom_Plane`, `Points(1, ...)` | exit 139 | `Standard_OutOfRange`, exit 0 |
| `Extrema_ExtSS` control, two spheres 20 apart | 2 extrema, points returned | identical |
| `Extrema_ExtCS` control, a line 40 above a sphere | 2 extrema, points returned | identical |

`IsDone()`, `IsParallel()`, `NbExt()` and `SquareDistance(1)` are unchanged on every mode: the
parallel pair still reports its one real measurement, 25 as a square distance in both cases. Only
the point read moves, from a fault to a refusal. The unpatched override-linked run is
byte-identical to the archive alone, which is how the pinned asset is known to carry no fix of its
own here.

### CI coverage, and the pin

**Pinned by `v4.0.0-kernel.4`, the first asset to hold it.** It was carried without a rebuild on
2026-09-30, when the pinned `v4.0.0-kernel.3` asset lacked it, and until the repin it was in **no**
required check: `ci.yml`'s `build-and-test` resolves the asset. Now that the asset holds it,
`build-and-test` exercises it. `kernel-integration.yml` triggers on `Scripts/patches/**` and builds
`V8_0_1` plus every carried patch from source, so the PR that added it got it compiled, which proved
it applied, compiled and regressed nothing.

It was not rebuilt the day it was carried, because **the bridge already refused the input before the
kernel saw it**. `0043` was rebuilt the day it was carried because what it left exposed was a value
a caller reads. This one left nothing exposed: `OCCTSurfaceExtrema` gained an `IsParallel()` gate
with #2831, and every other bridge entry point that reaches either class through a point read
already had one (`OCCTExtremaExtSSPoint`, `OCCTExtremaExtCSPoint`, `OCCTCurve3DDistanceToSurface`,
which reads `LowerDistance()` alone). The standing hold on repinning until OCCT 8.0.2 landed
therefore won, until `v4.0.0-kernel.4` was cut for other patches and absorbed this one.

**Retargeting risk at 8.0.2.** No other carried patch touches either file, and both `Points()`
bodies are three lines that have not changed since the class was written, so the hunks are expected
to apply to `V8_0_2` unchanged. Re-run `git -C occt-src apply --check` at the repin rather than
assuming it.

Filed upstream as [OCCT#1596](https://github.com/Open-Cascade-SAS/OCCT/pull/1596) against `IR` (the hold on upstream PRs until 8.0.2 was cancelled on 2026-10-07). The submission was staged in
`Scripts/repro/2840/upstream/`: two GTests, `Extrema_ExtSS_Test.cxx` and `Extrema_ExtCS_Test.cxx`,
compiled and run both ways (each parallel case exits 139 unpatched and passes patched, both controls
pass on both sides), plus the two `FILES.cmake` lines they need. `0024` is still unfiled too, so one
PR covering all three classes may read better than two.

**Retire** once the bundled OCCT includes this fix.

## 0045-Geom-Bezier-InsertPoleAfter-pole-bound-2875.patch

**`InsertPoleAfter` refuses two poles short of what the constructors build**
([#2875](https://github.com/SecondMouseAU/OCCTSwift/issues/2875)). Both Bezier curve classes accept
up to `MaxDegree() + 1` poles at construction (`Geom2d_BezierCurve.cxx:78` and `:93`,
`Geom_BezierCurve.cxx:93` and `:109`):

```cpp
  if (nbpoles < 2 || nbpoles > (Geom2d_BezierCurve::MaxDegree() + 1))
    throw Standard_ConstructionError();
```

and `Increase()` tops out at a degree of `MaxDegree()`, the same bound written as a degree.
`InsertPoleAfter` compares the pole count against the degree bound instead
(`Geom2d_BezierCurve.cxx:199`, `Geom_BezierCurve.cxx:214`):

```cpp
  Standard_ConstructionError_Raise_if(nbpoles >= Geom2d_BezierCurve::MaxDegree()
                                        || Weight <= gp::Resolution(), ...);
```

so insertion stops at `MaxDegree()` poles. A caller can hold a legally constructed curve longer
than `InsertPoleAfter` will grow a shorter one to. The fix is one character at each site, `>=` to
`>`, plus the one-line comment that says which quantity `MaxDegree()` bounds.

**`MaxDegree()` is a degree bound, and the classes' own tables say so.** `BSplCLib::MaxDegree()` is
25. Both classes size the static tables behind `Multiplicities()` and `KnotSequence()` as
`MaxDegree() + 1` and index them by `myPoles.Length() - 1`, so a curve of `MaxDegree() + 1` poles
is in range for every one of them, which is what makes the relaxed bound safe rather than merely
symmetric. Measured rather than reasoned: at 26 poles the 2d class answers `degree=25`,
`Multiplicities().Length()=2`, `KnotSequence().Length()=52`.

**Both sites in the tree are changed, which is the whole of the defect.** A grep for a pole count
compared against `MaxDegree()` with `>=` returns exactly two hits, the 2d class and the 3d one, and
no more. `Geom_BezierSurface::InsertPoleColAfter` / `InsertPoleRowAfter` carry **no** `MaxDegree`
bound at all, and `UMultiplicities()` / `UKnotSequence()` index the same fixed 26-element tables by
pole count, so growing a Bezier surface past 26 poles in one direction reads off the end of a
`std::array`. That is a different defect with a different fix and it is deliberately not in this
patch; it is filed separately.

### Half of this patch is inert in the shipped kernel, and that is the reason the bridge guard stays

The two sites are not written the same way. The 3d class throws literally; the 2d class goes
through `Standard_ConstructionError_Raise_if`, which `No_Exception` empties in a Release build
(#2801). So in the kernel this repo ships, **the 2d class has no pole bound at all**, patched or
not, and the only thing enforcing one is `OCCTCurve2DBezierInsertPoleAfter`'s own guard. The probe
shows it directly: under `-DNo_Exception` the 2d curve grows past 100 poles on both sides of the
patch, while the 3d curve moves from 25 to 26.

### Measured, macOS arm64, before and after

`Scripts/repro/2875-bezier-insertpole-bound/`, both translation units override-linked ahead of the
pinned macOS slice, per
[`okf/policies/upstream-occt-patch-process.md`](../../okf/policies/upstream-occt-patch-process.md)
section 3, in both build configurations. Transcript committed as `transcript.txt`.

| build | class | ctor max poles | insert max, before | insert max, after |
|---|---|---|---|---|
| shipped (`No_Exception`) | `Geom2d_BezierCurve` | 26 | 102 (unbounded) | 102 (unbounded) |
| shipped (`No_Exception`) | `Geom_BezierCurve` | 26 | 25 | **26** |
| exceptions enabled | `Geom2d_BezierCurve` | 26 | 25 | **26** |
| exceptions enabled | `Geom_BezierCurve` | 26 | 25 | **26** |

The 102 is the probe's own insertion limit, not a kernel one.

### Compiled, three slices

The two translation units this patch touches were compiled for all three xcframework slices by
hand rather than through a full kernel rebuild, `-std=c++17 -O3 -DNDEBUG -DNo_Exception -arch
arm64` against each slice's own SDK and headers: `arm64-apple-macos12`, `arm64-apple-ios15` and the
iOS simulator. Six compiles, no warnings and no errors. The log is committed as
`Scripts/repro/2875-bezier-insertpole-bound/compile-log.txt`. The `.pxx` private headers
(`Geom2dEval_RepUtils.pxx`, `GeomEval_RepUtils.pxx`) are not installed into the xcframework, so the
compile line adds their package directories from `Libraries/occt-src`.

### CI coverage, and the pin

**Pinned.** It was carried before it was pinned, and `ci.yml`'s `build-and-test` resolves the
pinned asset, so until the repin the patch was in no required check. Now that the asset holds it,
`build-and-test` exercises it. `kernel-integration.yml` triggers on `Scripts/patches/**` and builds
`V8_0_1` plus every carried patch from source, which proves it applies, compiles and regresses
nothing.

**Retargeting risk at 8.0.2.** No other carried patch touches either file, and neither
`InsertPoleAfter` has changed shape in years, so the hunks are expected to apply to `V8_0_2`
unchanged. Re-run the apply check at the repin rather than assuming it.

Filed upstream as [OCCT#1593](https://github.com/Open-Cascade-SAS/OCCT/pull/1593) against `IR` ([#1589](https://github.com/Open-Cascade-SAS/OCCT/pull/1589) closed); the hold on upstream PRs until 8.0.2 was cancelled on 2026-10-07.

**Retire** once the bundled OCCT includes this fix, **but keep the bridge guard**: it is the only
bound the 2d class has in a `No_Exception` build.

## 0046-math_Uzawa-Errinit-row-dimension-2860.patch

**The initial-error vector is sized by unknowns and written by constraints**
([#2860](https://github.com/SecondMouseAU/OCCTSwift/issues/2860), finding 1). Both `math_Uzawa`
constructors size `Errinit` on the column count (`math_Uzawa.cxx:47` and `:67`):

```cpp
    : Resul(1, Cont.ColNumber()),
      Erruza(1, Cont.ColNumber()),
      Errinit(1, Cont.ColNumber()),
```

and `Perform` then writes the whole thing by row (`:101`, `:104`):

```cpp
  for (i = 1; i <= Nlig; i++)        // Nlig = Cont.RowNumber()
    Errinit(i) = Cont(i, 1) * StartingPoint(1) - Secont(i);
```

Every read is a row index too: `:131`-`:138` in the direct branch and `:215` in the iterative one.
The accessor's own declaration says what the vector is, "the initial error
`Cont*StartingPoint-Secont`", which has one entry per constraint. So `RowNumber()` is the
documented length as well as the written one, and the fix is one word at each of the two
constructors.

**The dimension check above it cannot catch this.**
`Standard_DimensionError_Raise_if((Secont.Length() != Nlig) || ((Nce + Nci) != Nlig), " ")` relates
`Secont` and `Nce + Nci` to the row count and never relates rows to columns, so restoring it with
`-DBUILD_RELEASE_DISABLE_EXCEPTIONS=OFF` would not catch an overdetermined system. That is this
finding's bearing on
[`okf/policies/occt-validation-is-compiled-out.md`](../../okf/policies/occt-validation-is-compiled-out.md):
it is a kernel defect on its own terms, not a compiled-out check.

`math_Uzawa.cxx` also `#define`s `No_Standard_OutOfRange` and `No_Standard_DimensionError` itself,
at the top of the file, so `NCollection_Array1`'s inline bounds check is gone here even in a Debug
build and nothing reports the overrun.

**The three sibling members are correct and are left alone.** `Resul` and `Erruza` are indexed by
unknown (`:144`-`:147`, `:194`-`:198`), `Vardua` and `CTCinv` by constraint. Only `Errinit` is
indexed by one and sized by the other.

### Measured, macOS arm64, before and after

`Scripts/repro/2860-uzawa-errinit-dimension/`, one process per size because the largest faults,
the translation unit override-linked ahead of the pinned macOS slice. `math_Vector` inlines 32
doubles, so the outcome is decided by size rather than by validity, and the probe carries cases
either side of that threshold. Transcript committed as `transcript.txt`.

| constraints x unknowns | `InitialError().Length()` before | after | exit before / after |
|---|---|---|---|
| 2 x 2, the shape every existing test uses | 2, correct | 2 | 0 / 0 |
| 4 x 2, below the inline buffer | 2, expected 4 | **4** | 0 / 0 |
| 33 x 32, one slot past the inline buffer | 32, expected 33 | **33** | 0 / 0 |
| 40 x 33, seven past a heap block | 33, expected 40 | **40** | 0 / 0 |
| 100 x 2 | fault | **100** | **139** / 0 |

`IsDone()` and `Value(1)` are unchanged on every size that returned at all, including the
`-0.0234375` at 33 x 32 that #2860 recorded. Only the vector's length, and the write it bounds,
move.

### Compiled, three slices

`math_Uzawa.cxx` compiled by hand for all three xcframework slices, `-std=c++17 -O3 -DNDEBUG
-DNo_Exception -arch arm64` against each slice's own SDK and headers: `arm64-apple-macos12`,
`arm64-apple-ios15` and the iOS simulator. Three compiles, no warnings and no errors. The log is
committed as `Scripts/repro/2875-bezier-insertpole-bound/compile-log.txt`, which covers all three
translation units of both patches in one run.

### CI coverage, and the pin

**Pinned.** Unlike `0044`, this one left something exposed before the repin: the fault was in the
kernel and `OCCTMathUzawa`'s `nConstraints > nVars` guard was the only thing between a Swift caller
and it. That guard was added for exactly this, so nothing was exposed in practice, but the exposure
was to a future bridge author rather than nil.

**The bridge guard stays now that this is pinned**, a deliberate exception to the rule in
[`okf/policies/pinned-kernel-patch-check.md`](../../okf/policies/pinned-kernel-patch-check.md) that
a repin retires the mitigation its patch supersedes. Patched, the kernel returns a correctly sized
initial error for an overdetermined system instead of faulting, which is a behaviour the Swift
surface has not decided to expose: `MathSolver.uzawa` refusing `nConstraints > nVars` is an API
decision as well as a crash guard, and relaxing it is a SemVer change, not a cleanup. The guard
also still covers anyone pinning an older asset.

**Retargeting risk at 8.0.2.** No other carried patch touches `math_Uzawa.cxx`, and the two
constructors have not changed shape, so the hunks are expected to apply to `V8_0_2` unchanged.
Re-run the apply check at the repin rather than assuming it.

Filed upstream as [OCCT#1588](https://github.com/Open-Cascade-SAS/OCCT/pull/1588) against `master`; the hold on upstream PRs until 8.0.2 was cancelled on 2026-10-07. #2860 already
names this as the upstream-worthy item of its cluster, and the reading above is the report.

**Retire** once the bundled OCCT includes this fix, keeping the bridge guard.

## 0047-BRepMesh_IncrementalMesh-initParameters-refuses-NaN-2879-2900.patch

**`initParameters` validates five meshing parameters with five tests NaN defeats**
([#2879](https://github.com/SecondMouseAU/OCCTSwift/issues/2879),
[#2900](https://github.com/SecondMouseAU/OCCTSwift/issues/2900)).
`BRepMesh_IncrementalMesh::initParameters` is an inline private member of
`BRepMesh_IncrementalMesh.hxx`, called once, from `BRepMesh_IncrementalMesh.cxx:87`, and it is the
only place the kernel checks these values at all:

```cpp
if (myParameters.Deflection < Precision::Confusion())         { throw ... }
if (myParameters.DeflectionInterior < Precision::Confusion()) { ... = Deflection; }
if (myParameters.MinSize < Precision::Confusion())            { ... = recomputed; }
if (myParameters.Angle < Precision::Angular())                { throw ... }
if (myParameters.AngleInterior < Precision::Angular())        { ... = 2.0 * Angle; }
```

Every comparison with NaN is false. So a NaN parameter satisfies none of the five: the two tests
that refuse do not refuse, the three that substitute a usable value do not substitute, and the NaN
reaches `BRepMesh_FaceDiscret` intact. The patch spells each test `!(value >= bound)`, which puts
NaN on the refusing or substituting branch because an unordered comparison makes `>=` false and the
negation true. For every ordered value the two spellings are the same test, so no bound moves and
no valid input changes behaviour.

The two throwing tests are literal `throw` statements rather than `*_Raise_if` macros, so
`No_Exception` does not remove them and the refusal is live in this Release build. That is why the
ordinary too-small value was already refused promptly and catchably, and why NaN is the single
input that walked through.

### Why #2879 and #2900 are one patch and not two

They are one mechanism, in one function, in one header, reached by one set of callers. The linear
hole is `Deflection < Precision::Confusion()` at `:81` and the angular one is
`Angle < Precision::Angular()` at `:99`, eighteen lines apart in the same `initParameters` body.
#2896's PR body already recorded the kernel fix as `!(Deflection >= Precision::Confusion())` and
said the angular test wanted the identical treatment, with the two travelling together as one
upstream change rather than two; #2900 was filed to measure the angular half before anything was
written, and it did. Splitting them would ask an upstream reviewer to accept the argument twice and
would leave the function half-guarded against a single failure mode in between.

### The symptoms are different, which is the reason to measure both halves

Linear, `Scripts/repro/2879/`, on `BRepPrimAPI_MakeCylinder(10, 5)`, one process per case with an
external timeout because a tessellation that does not return is not catchable in-process:

| deflection | result |
|---|---|
| 0.1 | 130 nodes, 1 s |
| 1e-4 | 3,978 nodes, 1 s |
| 1e-5 | 12,570 nodes, 5 s |
| 1e-6 | 39,742 nodes, 72 s |
| **1e-7**, the floor itself | 88,862 nodes, 92 s |
| 9e-8, 1e-12, 0.0, -1.0 | `Standard_NumericError` from `initParameters`, under 1 s each |
| **NaN** | **did not return in 600 s** |

On a box, whose faces are all planar, the same NaN returned a mesh at no stated deflection (24
nodes); on a free circular edge it gave 22,216 `Poly_Polygon3D` nodes where a valid request gives
33. One input, three different wrong answers, none of them a refusal.

Angular, `Scripts/repro/2900/`, same cylinder, at linear deflection 10.0 so that the angle is the
criterion that decides:

| angle | result |
|---|---|
| 0.05 | 254 nodes |
| 0.2 | 254 nodes |
| 0.5 | 106 nodes |
| 1.0 | 54 nodes |
| 9e-13, 0.0, -1.0 | `Standard_NumericError` from `initParameters` |
| **NaN** | `IsDone()` **true**, `Angle` NaN, `AngleInterior` NaN, **18 nodes** |

So the angular hole is not a hang and not a refusal. It is the coarsest mesh the linear rule alone
will accept, reported as done, which is harder to notice than either.

### `AngleInterior`, and the other two substituting tests

The three substituting tests are in the patch for the function's own invariant rather than for a
measured defect, and the difference is worth stating rather than blurring.

`AngleInterior` is the one the issue asked about, because it is **rewritten** to `2.0 * Angle`
rather than refused, so a NaN `Angle` reaches it by arithmetic. Guarding `Angle` is what closes
that direction, and the probe confirms `AngleInterior` is NaN in exactly the cases `Angle` is. The
other direction was measured too, with `Angle` held at 0.5: a NaN `AngleInterior` that does reach
`initParameters` changes neither the node count nor the triangle count on either fixture, 106 nodes
on the cylinder, the same as a valid interior angle gives. That is the measurement behind the
bridge's decision not to guard the field (`occtValidMeshAngle`'s doc comment), and it is the same
measurement here.

It is guarded in the kernel anyway, along with `DeflectionInterior` and `MinSize`, for two reasons
that are about the function rather than about any one fixture. A function whose contract is that
nothing out of bounds reaches the mesher cannot leave three of its five tests permeable to the one
value that defeats all five. And the substitutions themselves are only finite once the two throwing
guards are in place: `(std::min)(Deflection, DeflectionInterior)` inside the `MinSize` branch and
`2.0 * myParameters.Angle` inside the `AngleInterior` branch would otherwise manufacture a fresh
NaN from one they were handed. `DeflectionInterior` and `MinSize` were not separately measured, and
this entry says so rather than implying a measurement that was not made.

### Compiled, 2026-10-02

`BRepMesh_IncrementalMesh.cxx` is the only translation unit that calls this function, and the
patched header was put ahead of the pinned ones on the include path, confirmed with `clang++ -H`
rather than assumed. Compiled clean, no diagnostics, on all three slices:

| slice | target | result |
|---|---|---|
| `macos-arm64` | `arm64-apple-macos12.0` | exit 0, no output |
| `ios-arm64` | `arm64-apple-ios15.0` | exit 0, no output |
| `ios-arm64-simulator` | `arm64-apple-ios15.0-simulator` | exit 0, no output |

`git apply --check` is clean against the patched `Libraries/occt-src`, which is the tree
`build-occt.sh` hands to cmake, with `0001` through `0044` already applied.

### CI coverage, and the pin

**Pinned.** It was carried before it was pinned, and `ci.yml`'s `build-and-test` resolves the pinned
asset, so until the repin the patch was in **no** required check. Now that the asset holds it,
`build-and-test` exercises it. `kernel-integration.yml` triggers on `Scripts/patches/**` and builds
`V8_0_1` plus every carried patch from source, so the PR that added it got it compiled, and that
proved it applies, compiles and regresses nothing. It could not prove the fix reaches a consumer,
and could not even if it ran on every PR, because the bridge already refuses the input first.

### The bridge guards stay

`occtValidMeshDeflection` and `occtValidMeshAngle` in `OCCTBridge_Internal.h` are **not** retired
now that this is pinned. This is the `0042` and `0044` shape, the deliberate exception to the rule in
[`okf/policies/pinned-kernel-patch-check.md`](../../okf/policies/pinned-kernel-patch-check.md) that
a repin retires the mitigation its patch supersedes: with the patch the kernel throws
`Standard_NumericError` for the same input the guards refuse, so both answer the site's documented
refusal and the guards are redundant rather than wrong. They also still cover anyone pinning an
older asset, and the wasm kernel, which is a pin behind.

### Retargeting risk at 8.0.2

No other carried patch touches `BRepMesh_IncrementalMesh.hxx`, and `initParameters` is a
twenty-line body that has not moved since `MinSize` was added to it. Re-run
`git -C occt-src apply --check` at the repin rather than assuming it.

Filed upstream as [OCCT#1598](https://github.com/Open-Cascade-SAS/OCCT/pull/1598) against `IR`; the hold on upstream PRs until 8.0.2 was cancelled on 2026-10-07.

**Retire** once the bundled OCCT includes this fix.

## 0048-BRepGProp-by-plane-offset-sign-2873.patch

**The by-plane overloads measure about the plane mirrored through the origin**
([#2873](https://github.com/SecondMouseAU/OCCTSwift/issues/2873)). Every by-plane
`BRepGProp_Vinert` and `BRepGProp_VinertGK` overload stores the plane the same way:

```cpp
thePlane.Coefficients(aCoeff[0], aCoeff[1], aCoeff[2], aCoeff[3]);
aCoeff[3] = aCoeff[3] - aCoeff[0] * loc.X() - aCoeff[1] * loc.Y() - aCoeff[2] * loc.Z();
```

and both integrands then **subtract** that coefficient: `BRepGProp_Gauss.cxx:344 with 0043 applied, :343 without` for the Gauss
path and `BRepGProp_UFunction.cxx:99` for the Gauss-Kronrod one, in each case against
`P - loc`. `gp_Pln::Coefficients` gives `a, b, c, d` for `a x + b y + c z + d = 0`, so the signed
distance from the plane to `P` is `n . P + d`, and substituting the stored coefficient gives

```
d1 = n . (P - loc) - (d - n . loc) = n . P - d
```

which is the distance to the plane at `n . X == d`, the reflection of the caller's plane through
the origin. Both halves of that one line are wrong in the same direction: the offset carries the
wrong sign, and `loc` cancels out of the result entirely rather than re-basing it, so
`SetLocation` has no effect on a by-plane computation at all.

Negating the coefficient as it is stored fixes both halves at once. With `aCoeff[3] = -d - n . loc`
the integrands compute `d1 = n . (P - loc) + d + n . loc = n . P + d`, the signed distance to the
plane as passed, independent of `loc` as a distance to a plane must be. The integrands are left
alone: their minus sign is what makes `loc` re-base correctly once the stored offset has the right
sign, and changing them instead would need the same edit at these five sites anyway.

### All five sites, because they are one convention and not five defects

| file | lines | what reaches them |
|---|---|---|
| `BRepGProp_Vinert.cxx` | 280, 297, 314 | the four `Perform(gp_Pln)` overloads, through `BRepGProp_Gauss` |
| `BRepGProp_VinertGK.cxx` | 219, 244 | the two `Perform(gp_Pln)` overloads, through `BRepGProp_UFunction` |

Fixing one class and not the other would leave `BRepGProp::VolumeProperties` and
`BRepGProp::VolumePropertiesGK` disagreeing per face about which plane they measured. Those are the
only five: a grep for the coefficient assignment across `Libraries/occt-src/src` returns exactly
them.

### Measured

`Scripts/repro/2827/probe.mm`'s `reportSignConvention`, macOS arm64 against the
`v4.0.0-kernel.3` asset, on a flat cap of area 371.7256661 square to the plane normal, where
`mass == (n . n_face) * area * d1` exactly, so `mass / area` reads `d1` off directly. The cap is at
z = 2:

| `loc.z` | plane at z = | `mass` | `d1` | geometric distance |
|---|---|---|---|---|
| 0 | 0 | 743.45133223538 | 2 | 2 |
| 0 | 1 | 1115.1769983531 | 3 | 1 |
| 0 | -100 | -36429.115279534 | -98 | 102 |
| 3 | 0 | 743.45133223538 | 2 | 2 |
| 3 | 1 | 1115.1769983531 | 3 | 1 |
| 3 | -100 | -36429.115279534 | -98 | 102 |

`d1` tracks `z + planeOffset` where it should track `z - planeOffset`, and `loc` changes nothing.
Both are what the derivation predicts.

### What does not change

**Aggregates.** `d1` stays an affine function of `P` with gradient `n`, which is the only property
the divergence-theorem identities need, so the per-face sum over a closed shell is still the
enclosed volume and the mass-weighted sum of the per-face centres is still the first moment, for
any plane. `BRepGProp::VolumePropertiesGK(S, Props, thePln, ...)` therefore reports the same volume
and centre of mass before and after. What changes is a per-face reading, which is the decomposition
a caller asks for when it passes a plane rather than a point.

**Anything in OCCT.** Nothing in the kernel reads a per-face by-plane value: `BRepGProp.cxx:311` is
the only `BRepGProp_Vinert` call site and passes a point, and `:809` and `:892` forward a plane to
`BRepGProp_VinertGK` for an aggregate. And until `0043` the by-plane mass was overwritten with
`0.0` before any caller could see it, so the value this corrects has never been readable from a
release build.

### Does `0043` already carry this hunk? No

`0043`'s own `Scripts/patches/README.md` entry and
[`okf/references/carried-occt-patches.md`](../../okf/references/carried-occt-patches.md) both say
"the submission carries a second hunk for #2873", which describes the **upstream PR** that is still
being held, not the carried `.patch` file. The file touches one file,
`BRepGProp_Gauss.cxx`, and one line in it, the `&& theIsByPoint` in `convert`. It contains no sign
change and does not mention `BRepGProp_Vinert.cxx` or `BRepGProp_VinertGK.cxx`. So this is its own
patch. The two still travel upstream in one PR, where they are two hunks of one story: `0043` makes
the by-plane value readable and `0048` makes it right.

### Compiled, 2026-10-02

Both changed translation units, compiled clean with no diagnostics on all three slices:

| TU | `macos-arm64` | `ios-arm64` | `ios-arm64-simulator` |
|---|---|---|---|
| `BRepGProp_Vinert.cxx` | exit 0 | exit 0 | exit 0 |
| `BRepGProp_VinertGK.cxx` | exit 0 | exit 0 | exit 0 |

`git apply --check` is clean against the patched `Libraries/occt-src`, `0043` included, which is
the tree `build-occt.sh` hands to cmake.

### The bridge side WAS a compensation, not a guard, and the repin deleted it (#3015)

This was the one carried patch whose bridge-side companion had to come out at the repin rather than
stay. `OCCTBRepGPropVinertPlane` did not refuse an input, it built the `gp_Pln` **mirrored through
the origin on purpose**, so that the unpatched kernel answered about the plane the Swift caller asked
for:

```cpp
gp_Pln plane(gp_Pnt(normal.XYZ() * -planeDist), normal);   // until v4.0.0-kernel.4
```

A kernel carrying `0048` with that mirror still in place measures about the mirrored plane again,
and the two sign assertions in `Tests/OCCTAnalysisTests/BRepGProp/BRepGPropVinertTests.swift` failed on #3014
for exactly that reason. The change that repinned to an asset carrying `0048` (#3031) therefore:

- deleted the mirror in `OCCTBRepGPropVinertPlane`, so the line now reads
  `gp_Pln plane(gp_Pnt(normal.XYZ() * planeDist), normal);`, and rewrote the comment block that
  explains it as history,
- left the by-plane assertions in `BRepGPropVinertTests` on the corrected convention, which they
  pass against the pinned kernel,
- dropped the "pass `-d`" note from `Face.volumeInertia(planeNormal:planeDistance:)` and from
  `docs/reference/Shape-HLR-Geom.md`.

Until that change the mirror was correct and had to stay, because CI resolves the pinned asset and
removing it earlier would have turned a correct answer into a sign-flipped one on every consumer.

### Retargeting risk at 8.0.2

`0043` touches `BRepGProp_Gauss.cxx` and this one touches `BRepGProp_Vinert.cxx` and
`BRepGProp_VinertGK.cxx`, so they do not overlap, and all five target lines are a single assignment
that has not changed since the classes were written. Re-run `git -C occt-src apply --check` at the
repin rather than assuming it.

Filed upstream as [OCCT#1601](https://github.com/Open-Cascade-SAS/OCCT/pull/1601) against `IR`, on its own: it is independent of [OCCT#1587](https://github.com/Open-Cascade-SAS/OCCT/pull/1587) (`0043`), whose diff only removes `&& theIsByPoint` in `BRepGProp_Gauss.cxx`.

**Retire** once the bundled OCCT includes this fix, and delete the bridge mirror in the same change.


## 0050-GProp_SelGProps-cone-lateral-area-drops-cos-semiangle-2992.patch

**`GProp_SelGProps::Perform(gp_Cone)` returns `cos(semiAngle)` times the lateral area**
([#2992](https://github.com/SecondMouseAU/OCCTSwift/issues/2992)). `GProp_SelGProps.cxx:123-125`
in the pinned tree:

```cpp
  double Auxi1 = R + (Z2 + Z1) * Snt / 2.;
  double Auxi2 = (Z2 * Z2 + Z1 * Z2 + Z1 * Z1) / 3.;
  dim          = (Alpha2 - Alpha1) * Cnt * (Z2 - Z1) * Auxi1;
```

`gp_Cone`'s `v` runs along the generatrix:

    P(u, v) = Loc + (R + v sin a)(cos u X + sin u Y) + v cos a Z

so `dP/du = (R + v sin a)(-sin u X + cos u Y)` and `dP/dv = sin a (cos u X + sin u Y) + cos a Z`.
The two are orthogonal, `|dP/du|` is `R + v sin a`, `|dP/dv|` is 1, and the area element is
therefore `(R + v sin a) du dv`. Integrated over `u in [Alpha1, Alpha2]`, `v in [Z1, Z2]`:

    A = (Alpha2 - Alpha1) (Z2 - Z1) (R + (Z2 + Z1) sin a / 2)

which is `Auxi1` times `(Alpha2 - Alpha1) (Z2 - Z1)`. The `Cnt` has no term to come from, so the
fix is to delete it and nothing else.

**No reading of `Z` saves it.** Were `Z` the axial coordinate rather than the slant, the correction
would be a *division* by `cos(a)`. And the factor goes to 1 as `a` does, which is why the
`gp_Cylinder` overload beside it (`dim = R (Z2 - Z1) (Alpha2 - Alpha1)`, exact) never showed this.

**The centre of mass in the same function is untouched by this patch, and is correct for `z`.**
`Iz = Cnt (R (Z2 + Z1) / 2 + Snt * Auxi2) / Auxi1` is the first moment of the same area element
divided by `Auxi1`, so it is independent of how `dim` is scaled. The override-link run below
confirms it does not move. (This entry once called the whole centre correct. `x` and `y` are only
correct over a full turn; [`0055`](#0055-gprop_selgprops-gprop_velgprops-cone-matrix-of-inertia-3010patch)
fixes the `sin^2 a` term that a partial turn exposes.)

### Why the closed form is the arbiter, and not a call site

`GProp_SelGProps` and `GProp_VelGProps` have **no caller anywhere in `Libraries/occt-src`**:

```
grep -rn 'GProp_SelGProps\|GProp_VelGProps' --include=*.cxx --include=*.hxx
```

returns only their own definitions. So
[`okf/policies/follow-occt-callers.md`](../../okf/policies/follow-occt-callers.md)'s usual answer,
copy what OCCT's own callers do, has nothing to copy, and its "when OCCT does not answer" branch
applies. The two arbiters used instead are the closed form above and the **cylinder limit**: a cone
of vanishing semi-angle is the cylinder that the same class answers exactly, and the patched form
converges on it while the unpatched one does not.

### The derivation was re-checked, not inherited

#2992 derived the fix rather than measuring it, and
[#2970](https://github.com/SecondMouseAU/OCCTSwift/issues/2970) is about exactly that failure mode.
The surface integral above was re-derived from `gp_Cone`'s parametrisation before the hunk was
written, evaluated symbolically against the kernel's own expression, and then measured in the
kernel by override-link. All three agree.

### Measured, macOS arm64, before and after

`Scripts/repro/2992/probe.cxx` against the pinned `v4.0.0-kernel.3` asset with
`GProp_SelGProps.cxx` and `GProp_VelGProps.cxx` override-linked, per
[`okf/policies/upstream-occt-patch-process.md`](../../okf/policies/upstream-occt-patch-process.md)
section 3. The transcript is `Scripts/repro/2992/override-link-transcript.txt`.
`gp_Cone(gp::XOY(), pi/6, 5)`, `u in [0, 2 pi]`, `v in [0, 10]`:

| quantity | before | after | closed form |
|---|---|---|---|
| `Mass()` | `408.10485695269909` | `471.23889803846896` | `471.23889803846896` |
| ratio to the closed form | `0.86602540378443882` | `1` exactly | `cos(pi/6)` is `0.86602540378443871` |
| `CentreOfMass()` | `(0, 0, 4.81125224325)` | identical | unchanged by the patch |

Cylinder limit, same R and slant height, against the cylinder's `314.15926535897933`:

| semiAngle | before | after |
|---|---|---|
| `1e-3` | `314.47326733528` | `314.47342457198` |
| `1e-6` | `314.15957951809` | `314.15957951824` |
| `1e-9` | `314.15926567314` | `314.15926567314` |

Both converge, because the defect is a factor rather than a term, which is also why the area half
of #2992 took a closed-form comparison to find at all. The residual at `1e-9` is the first-order
term `pi h^2 sin a`, `3.14e-7`, not an error.

### What was deliberately NOT fixed

The inertia terms below `dim` carry a **separate** discrepancy, found while re-deriving this one
and measured, not fixed here. `Dm(3, 3) = IR2 * (Alpha2 - Alpha1)` should be the second moment
about the axis:

    int r^2 dA = (A2 - A1) int (R + v s)^3 dv = (A2 - A1)(Z2 - Z1)(R1^3 + R1^2 R2 + R1 R2^2 + R2^3) / 4

and the kernel's `IR2 = ZZ * Snt * (...) / 4` with `ZZ = (Z2 - Z1) * Cnt` is that times
`cos a sin a`: `12753.276779771842` against `29452.43112740431`, a ratio of `0.4330127018922193`
where `cos(pi/6) sin(pi/6)` is `0.4330127018922193`. `IZ2` is wrong in a third way (an extra
`(Z2 - Z1) Cnt`, and a `/ 4` applied to a term that should not have it). None of that is in this
patch: it is a distinct defect with its own derivation, nothing in the bridge reads it, and
changing a second result under cover of this one is how a patch stops being reviewable. Filed
separately as [#3010](https://github.com/SecondMouseAU/OCCTSwift/issues/3010).

### CI coverage, and the pin

**Pinned, like `0051` and `0052`.** It was carried before it was pinned, and `ci.yml`'s
`build-and-test` resolves the pinned asset, so `Tests/OCCTAnalysisTests/MassProperties/GPropCylConeTests.swift`
was **red there** until the repin; `kernel-integration.yml` triggers on `Scripts/patches/**`, builds
`V8_0_1` plus every carried patch from source, and is where those tests passed in the meantime. That
split is #585 and it was the expected state of a PR carrying a kernel fix and its regression
together. The repin closed it.

**Unlike `0044`, this one left a value a caller reads wrong**, through
`GeometryProperties.coneSurfaceArea(semiAngle:refRadius:height:)`, which is `0043`'s situation
rather than `0044`'s. No bridge-side mitigation was added anyway: dividing the factor back out in
the bridge would have had to be retired at the repin, and would have double-corrected a kernel that
already carried the patch in the window between. The rebuild was same-night, so the window was
hours.

**Retargeting risk at 8.0.2.** No other carried patch touches this file and the expression has not
changed since the class was written, so the hunk is expected to apply to `V8_0_2` unchanged. Re-run
`git -C occt-src apply --check` at the repin rather than assuming it.

Filed upstream with `0051` and `0055` as one PR, [OCCT#1599](https://github.com/Open-Cascade-SAS/OCCT/pull/1599) against `IR` (the hold on upstream PRs until 8.0.2 was cancelled on 2026-10-07). `0055`'s hunks need `0050`'s and `0051`'s context. They are one
defect in two files and the old `GProp_VelGProps` `dim` is exactly this one's old `dim` times
`(Z2 - Z1) sin a`.

**Retire** once the bundled OCCT includes this fix.

## 0051-GProp_VelGProps-cone-volume-is-the-frustum-2992.patch

**`GProp_VelGProps::Perform(gp_Cone)` returns a quantity that vanishes at the cylinder limit**
([#2992](https://github.com/SecondMouseAU/OCCTSwift/issues/2992)). `GProp_VelGProps.cxx:168-171`
in the pinned tree:

```cpp
  double ZZ    = (Z2 - Z1) * (Z2 - Z1) * Cnt * Snt;
  double Auxi1 = 2 * R + (Z2 + Z1) * Snt;

  dim = ZZ * (Alpha2 - Alpha1) * Auxi1 / 2.;
```

The `Snt` in `ZZ` carries straight into `dim`, so the reported volume goes to **zero** as the
semi-angle does. The `gp_Cylinder` overload in the same class answers that same solid exactly with
`dim = (Alpha2 - Alpha1) R^2 (Z2 - Z1) / 2`, so the two disagree in the limit where they describe
the same thing.

### The frustum, derived

The solid between the axis and the cone patch. With `z = v cos a` and `r(z) = R + v sin a`:

    V = int du int r(z)^2 / 2 dz
      = (Alpha2 - Alpha1) cos a / 2 int_{Z1}^{Z2} (R + v sin a)^2 dv
      = (Alpha2 - Alpha1) cos a (Z2 - Z1) (R1^2 + R1 R2 + R2^2) / 6

with `R1 = R + Z1 sin a`, `R2 = R + Z2 sin a`, which over a full turn is the familiar
`pi H (R1^2 + R1 R2 + R2^2) / 3` with `H = (Z2 - Z1) cos a`. That is the convention the cylinder and
sphere overloads of this class both use (sphere: `4 pi R^3 / 3` over the full range).

Expanded in `R` and `sin a`, `R1^2 + R1 R2 + R2^2` is

    3 R^2 + 3 R (Z1 + Z2) sin a + (Z1^2 + Z1 Z2 + Z2^2) sin^2 a

which is the form the hunk uses, so that the existing `R1`, `R2` and `Coef0` locals keep their
position after `dim` and clang-format's declaration-alignment block is left alone. At `a = 0` it
collapses to `(Alpha2 - Alpha1) R^2 (Z2 - Z1) / 2`, exactly the cylinder overload.

### Why the closed form is the arbiter, and the derivation re-checked

Same as `0050`: neither class has a caller anywhere in `Libraries/occt-src`, so
[`okf/policies/follow-occt-callers.md`](../../okf/policies/follow-occt-callers.md)'s "when OCCT does
not answer" branch applies and the arbiters are the closed form plus the cylinder limit. The
integral above was re-derived from `gp_Cone`'s parametrisation rather than taken from #2992, and
#2992's own candidate expression,
`(A2 - A1) cos a / 2 [R^2 (Z2 - Z1) + R sin a (Z2^2 - Z1^2) + sin^2 a (Z2^3 - Z1^3) / 3]`, was
checked against it and agrees to the last bit. The form carried differs from it by one ulp and is
preferred only for the diff shape.

**Note the relationship between the two halves of #2992**: the old `dim` here is exactly `0050`'s
old `dim` times `(Z2 - Z1) sin a`, confirmed numerically (`4.999999999999999` against
`(Z2 - Z1) sin a = 4.999999999999999`). One was derived from the other, which is why the two
patches are one upstream PR.

### Measured, macOS arm64, before and after

Same probe and transcript as `0050`, `gp_Cone(gp::XOY(), pi/6, 5)`, `u in [0, 2 pi]`,
`v in [0, 10]`:

| quantity | before | after | frustum |
|---|---|---|---|
| `Mass()` | `2040.524284763495` | `1587.0744437049409` | `1587.0744437049404` |
| error | `453` | `4.6e-13` | |

Cylinder limit, against the cylinder's `785.39816339744823`, which is the decisive evidence:

| semiAngle | before | after |
|---|---|---|
| `1e-3` | `3.14473214923` | `786.96961317468` |
| `1e-6` | `0.00314159580` | `785.39973419443` |
| `1e-9` | `0.00000314159` | `785.39816496824` |

Before, it converges on zero. After, on the cylinder. The residual at `1e-9` is the first-order
term `pi R h^2 sin a`, `1.57e-6`. The centre of mass is unchanged on every case.

### What was deliberately NOT fixed

As in `0050`, the inertia terms below `dim` carry their own discrepancy: `IR2` is built from a
four-term quartic over 4 where the second moment about the axis integrates to
`cos a (Z2 - Z1)(R1^4 + R1^3 R2 + R1^2 R2^2 + R1 R2^3 + R2^4) / 20`, a five-term quartic over 20,
and it keeps the same spurious `sin a` in `ZZ`. Out of scope here, for the same reason, and filed
as [#3010](https://github.com/SecondMouseAU/OCCTSwift/issues/3010) with `0050`'s half.

### CI coverage, and the pin

Identical to `0050`'s, and for the same reason: `GeometryProperties.coneVolume(semiAngle:refRadius:height:)`
returned the wrong value on the asset pinned before the repin, so this was `0043`'s situation and
not `0044`'s. Filed upstream with `0050` as one PR,
[OCCT#1599](https://github.com/Open-Cascade-SAS/OCCT/pull/1599) against `IR`.

**Retire** once the bundled OCCT includes this fix.

## 0052-Geom_BezierSurface-rational-axis-prose-matches-example-2991.patch

**`Geom_BezierSurface.hxx`'s `IsURational`/`IsVRational` prose contradicts its own example matrix**
([#2991](https://github.com/SecondMouseAU/OCCTSwift/issues/2991)). The header says:

```
  //! Returns False if the weights are identical in the U direction,
  //! Example :
  //!               |1.0, 1.0, 1.0|
  //! if Weights =  |0.5, 0.5, 0.5|   returns False
  //!               |2.0, 2.0, 2.0|
  Standard_EXPORT bool IsURational() const;
```

The weights in that matrix are **not** identical in the U direction, they run `1.0, 0.5, 2.0` down
a column. They are identical in the V direction. Prose and example contradict each other, and the
example is the one that matches the code.

**The implementation is the authority.** `Geom_BezierSurface.cxx`'s static `Rational()` sets
`Urational` from

```cpp
  Urational = (std::abs(Weights(I, J) - Weights(I, J + 1)) > Epsilon(std::abs(Weights(I, J))));
```

inside a loop over `I` that walks `J`, so the comparison is between neighbours in the **column**
index, which is V. `Urational` is therefore false exactly when every **row** is constant, and
`Vrational` false exactly when every column is. Each flag names the axis opposite the one it
compares along.

**`Geom_BSplineSurface.hxx` already states this correctly**, with the same two example matrices
("Returns False if for each row of weights all the weights are identical"), so the two headers
disagree with one another as well as one of them disagreeing with the implementation. The patch
gives `Geom_BezierSurface` the wording `Geom_BSplineSurface` already has, leaving the example
matrices and the tolerance sentence untouched, which is the smallest change that makes all three
agree.

### Measured

`Scripts/repro/2976-surface-rational-axes/probe.mm`, four explicit weight matrices against the
pinned kernel:

| weights | `IsURational` | `IsVRational` |
|---|---|---|
| rows constant, varies along U | 0 | 1 |
| columns constant, varies along V | 1 | 0 |
| all equal | 0 | 0 |
| varies along both | 1 | 1 |

A `Geom_BSplineSurface` converted from a `r = 5`, `h = 10` cylinder reports `(0, 1)`, and `(1, 0)`
after `ExchangeUV()`, the same way round.

### Why carry a comment fix at all

It changes no binary, so it leaves nothing exposed and it is in no test. It is carried for two
reasons. The tree we build and the tree we file upstream from should agree, so that the 8.0.2
submission is cut from the same source as everything else; and the wrong prose has already cost
something, having nearly been recorded as a defect by one lift batch reading a converted cylinder's
`(0, 1)` as an inverted conversion.

`Geom_BezierSurface.cxx` was compiled against the corrected header on all three slices to confirm
the header still builds, which is the only compile a documentation patch can offer.

### CI coverage, and the pin

Pinned with `0050` and `0051`, and unlike them it left nothing for a caller to
read wrong: PR #2990 already documents the real behaviour on all four Swift properties with the
cylinder as the worked example and a test pinning both directions.

Filed upstream alone as [OCCT#1602](https://github.com/Open-Cascade-SAS/OCCT/pull/1602) against `IR`, documentation only, so no GTest. The plan to batch it with #2875's and #2860's
one-character fixes went with the hold on upstream PRs until 8.0.2, cancelled on 2026-10-07.

**Retire** once the bundled OCCT includes this fix.

## 0053-BRepOffset_MakeOffset-arc-join-roots-in-binding-order-3003.patch

**An arc-join offset returns its faces in an order set by allocation addresses**
([#3003](https://github.com/SecondMouseAU/OCCTSwift/issues/3003)). `BRepOffset_MakeOffset::BuildOffsetByArc`
keeps one `BRepOffset_Offset` per face, per convex edge (a tube) and per vertex (a sphere) in

```cpp
NCollection_DataMap<TopoDS_Shape, BRepOffset_Offset, TopTools_ShapeMapHasher> MapSF;   // :1911
```

and walks it (`:2092`) to register each offset face as a root of `myInitOffsetFace` and of
`myImageOffset`. `MakeShells` (`:3691`) passes `myImageOffset.Roots()` to `BRepTools_Quilt`, which
keeps the faces in the order it is given them. `std::hash<TopoDS_Shape>` is the address of the
`TShape` (`TopoDS_Shape.hxx:332-341`), so the faces of every arc-join result come out in an order
the allocator decided. `BRepGProp` sums a volume over the faces in the order the shape holds them,
so the last digits of the volume move with it: the 4e-16 to 9e-16 on three lines of two #766 probes
that #2965 allowed for with a `tolerance` key.

**It is none of the three things the issue named.** One thread, `BOPAlgo_Options::GetParallelMode()`
false, no shared state, no uninitialised read: with the walk fixed the same inputs give the same
bits in every process and every build. The fourth cause is a traversal in the order of a hash of
pointer values.

The fix records the order the entries are bound in (the faces as `MakeOffsetFaces` binds them, which
is `BRepLib::SortFaces` over `myFaceComp` and then the faces `BRepOffset_Analyse` added; then the
tubes; then the spheres) in an `NCollection_IndexedMap` and walks that, looking each entry up in
`MapSF`, from which `ToContext` may have removed it. About thirty-five changed lines in one
function, no signature change. `NCollection_OrderedDataMap`, which 8.0.0 added for exactly this, is
the idiomatic spelling and is not used because `MapSF`'s type is a parameter of
`BRepOffset_Inter3d::ConnexIntByInt` and `ContextIntByInt`, in another header and translation unit,
and `BiTgte_Blend` holds a member of the same type.

### Measured, macOS arm64, before and after

`Scripts/repro/3003-offset-roots-hash-order/`, against the pinned `v4.0.0-kernel.4` macOS slice,
the unmodified file recompiled with the kernel's own flags as the control, and the patched file
override-linked. Sixty fresh processes per row; "dumps" is the number of distinct hashes of the
bit-exact `BinTools` dump of the result.

| request | volumes before / after | dumps before / after |
|---|---|---|
| 10-box, offset +1, `GeomAbs_Arc` | 7 / **1** | 60 / **1** |
| 20-box, thick solid 2.0, top face open | 3 / **1** | 60 / **1** |
| 20-box, thick solid 2.0, nothing open | 6 / **1** | 60 / **1** |
| 10-box, offset -1, `GeomAbs_Arc` | 1 / 1 | 55 / **1** |
| cylinder, offset +1, `GeomAbs_Arc` | 1 / 1 | 24 / **1** |
| 10-box, offset +1, `GeomAbs_Intersection` | 1 / 1 | 1 / 1 |

The control reproduces the drift (7, 1, 1, 1, 3, 5 volumes), so the override toolchain is not the
variable. In one process, 32 builds of the first row with a different amount of heap held before
each give **11 to 32** distinct face orders per process unpatched (20 processes) and **1** patched in every one. Over a 72-request battery (nine
shapes, eight requests each, twenty processes) 29 requests returned more than one distinct result
unpatched, 26 of them only in sub-shape order, and none patched; 69 of the 72 return the same
outcome unpatched and patched.

### What the fix does for one kind of input

For an input whose success depends on the order the roots arrive in, the patched kernel gives the
same answer every time, which may be the failing one. The fuse of two boxes (`BRepAlgoAPI_Fuse`,
coplanar faces left split) returns a solid from arc-join `offset(+1)` in 11 of 20 processes
(7 and 8 of 20 in two earlier censuses) and reports `IsDone()` with a **null shape** in the rest.
Binding order, the order chosen, is one of the failing ones, so patched it fails in all 20. The
outcome flipping with nothing but the heap different shows it is a property of the intersection
stage that follows, and its own defect. Taking this patch turns that input from "about two runs in
five" into "never". Binding order is what an insertion-ordered map gives and so what upstream would
choose; nothing was tuned to this input, and a different fixed order could favour it at the price of
an arbitrary choice that another input might fail.

### Compiled, three slices

`BRepOffset_MakeOffset.cxx` compiled for all three xcframework slices, `-std=c++17 -O3 -DNDEBUG
-DNo_Exception -arch arm64` against each slice's own SDK and the pinned headers
(`arm64-apple-macos12`, `arm64-apple-ios15`, `arm64-apple-ios15-simulator`), and the GTest file for
the host. Four compiles, no warnings in the changed ranges and no errors. The log is
`Scripts/repro/3003-offset-roots-hash-order/compile-log.txt`.

### The GTest

`ArcJoin_FaceOrderDoesNotDependOnAddresses` in `BRepOffset_MakeOffset_Test.cxx`: 32 builds of the
offset of a freshly made box (one box offset repeatedly does not show the defect, the map is also
keyed on the input's own sub-shapes) with a different amount of heap held before each, comparing every face's centre and the
volume's bits with build 0. Against the override-linked unmodified file it **fails**, 15 of 15 runs
(812 failed expectations in one, the first from build 1); against the patched file it passes, 15 of
15 (462 ms), and the other 19 tests in the file pass on both.

### CI coverage, and the pin

**Carried, and pinned from `v4.0.0-kernel.5`.** Until that repin no required check exercised it,
because `build-and-test` resolved an asset without it. `Issue3003OffsetOrderTests` was gated on
`OCCTSWIFT_LOCAL=1` for that reason and ran in `kernel-integration.yml`, which builds the patch from
source. **The two `tolerance` declarations in
`766-modeling-evidence-fix/reproduce.json` and `766-modeling-issue568-index-skip/reproduce-evidence-fix.json`
stayed until it was pinned**, because against the earlier asset those three lines still drifted; they
came out, and the three transcripts were recaptured, with that repin. The patched
`offsetArc` value is `1698.436569847848`, one value out of the unpatched distribution and not the
transcript's `...475`.

Nothing is exposed to a Swift caller that a bridge guard could cover. The consequence is a face
order and the last digits of a sum, and `OCCTShapeOffsetByJoin` hands back whatever the builder
returns.

**Retargeting risk at 8.0.2.** `IR` and `master` carry the same `MapSF` walk, at `:2061` on `IR`; the
`BuildOffsetByArc` hunks apply to both with `git apply --check`, and `IR` differs from `V8_0_1` in
this file by removed debug code and one `Image(E).First()` to `FirstImage(E)` change. Re-run the
apply check at the repin rather than assuming it.

Filed upstream as [OCCT#1600](https://github.com/Open-Cascade-SAS/OCCT/pull/1600) against `IR` (the hold on upstream PRs until 8.0.2 was cancelled on 2026-10-07). The PR discloses that it makes the two-box-fuse arc offset fail deterministically, 20 of 20, instead of intermittently, an intersection-stage order dependence it does not address. Upstream was
checked on 2026-10-03 and has no report and no PR about the order of an offset's faces; the draft is
this patch's own message.

**Retire** once the bundled OCCT includes this fix.


## 0054-ChFi3d_Builder-StartSol-drops-an-obstacle-with-no-edge-2881.patch

**A fillet blend that reaches an obstacle with no edge to follow evaluates an empty curve**
([#2881](https://github.com/SecondMouseAU/OCCTSwift/issues/2881), upstream
[OCCT#1568](https://github.com/Open-Cascade-SAS/OCCT/issues/1568)),
`src/ModelingAlgorithms/TKFillet/ChFi3d/ChFi3d_Builder_2.cxx:1530-1562` in the pinned tree.
`ChFi3d_Builder::StartSol`, on reaching an obstacle face, sets `c1obstacle`, replaces `HC` with a
fresh `BRepAdaptor_Curve2d`, and looks for the arc edge among the obstacle face's edges:

```cpp
HC = new BRepAdaptor_Curve2d();
... find newedge among Fv's edges by IsSame(anArcEdge) ...
if (!newedge.IsNull()) { HC->Initialize(newedge, Fv); ... return true; }
else                   { prepareDefaultReturn(); return false; }   // HC is still the empty adaptor
```

When no edge matches, the `else` returns `false` and leaves `HC` as the default-constructed adaptor,
which holds no curve, with `c1obstacle` still `true`. `PerformSetOfSurfOnElSpine` tests
`!Ok && HC.IsNull()` for the end of the chain, an empty non-null `HC` passes that test, and
`obstacleon1`/`obstacleon2` then select the obstacle path, which hands `HC` to
`ChFi3d_FilBuilder::PerformSurf`. The `SurfRst` walk evaluates it through
`Adaptor3d_CurveOnSurface::EvalD1` and `Geom2dAdaptor_Curve::D1` falls to its `default:` arm and
dereferences a null curve. That is a SIGSEGV inside `Build()`, which `OCC_CATCH_SIGNALS` being inert
in this build means no bridge `catch (...)` can reach, and `BRepFilletAPI_MakeFillet` is named in 96
bridge sites.

The fix is three lines in that `else`: `HC.Nullify(); c1obstacle = false;` before the existing
return, which gives the caller the state it already handles for "no obstacle". The sibling failure
in the same block, returning `false` when `HSref` or `HCref` is null, leaves `HC` null, which the
caller does handle; it is left alone because no input reaches it.

### How the cause was found, and what was ruled out

`Scripts/repro/occt1568-fillet-opposite-edge/`, against the pinned macOS slice with override-linked
copies of three kernel files (the unmodified file recompiled with the kernel's flags is the
control, and each copy differs by a few logging lines):

- **The first hypothesis was wrong.** #2881 guessed an edge with no pcurve on its reference face,
  which would make `BRepAdaptor_Curve2d::Initialize` leave the adaptor empty. Logging every
  `Initialize` call (494 calls at radius 1.49, 326 up to the fault at 1.5) shows it never sees a null
  pcurve on this model.
- **The faulting adaptor was identified by address.** `Adaptor3d_CurveOnSurface::EvalD1` is called
  once before the fault, on a `BRepAdaptor_Curve2d` that appears in the log as a default
  construction and never as an `Initialize`.
- **The branch fires exactly where the crash is.** Logging it gives two hits at radius 1.5 and none
  at 1.49 or 1.5000001. What it sees: the blend's face is a plane, the neighbour face found at the
  vertex is a four-edged B-spline surface, and the arc edge is in the blend's face but in none of the
  neighbour's edges under any orientation.

### Measured, macOS arm64, before and after

`BRepFilletAPI_MakeFillet` on the model attached to OCCT#1568 (19 faces, 42 edges), one edge at a
time, `ChFi3d_Rational` with `BRepTest_FilletCommands`' parameters, the patched file override-linked.

| radius | unpatched | patched |
|---|---|---|
| 0.3 and 1.0 | 20 done, 22 raise "no suitable edges" | identical |
| 1.5 | 12 done, **8 SIGSEGV**, 22 raise | 12 done, 8 not done (`NbFaultyContours = 1`), 22 raise |

Across 42 edges and nine radii (0.3, 0.8, 1.0, 1.2, 1.4999999, 1.5, 1.5000001, 1.8, 2.5), 378 cases,
exactly eight outcomes change, edges 12 to 19 at 1.5, each from SIGSEGV to a normal completion with
`IsDone() == false`. The other 370 are identical, 170 completed and 200 raising the same exception.
The eight now behave as radius 1.4999999 already did.

**Filed upstream as [OCCT#1591](https://github.com/Open-Cascade-SAS/OCCT/pull/1591) against `master`**; the report is [OCCT#1568](https://github.com/Open-Cascade-SAS/OCCT/issues/1568). Upstream's GTests are organised per toolkit and every PR is asked for
one; the reproducer needs the 19-face model, and plain boxes with radii at their face widths (372
cases) never reach the branch, so a small programmatic input is still to be found. OCCT#1568 carries
our minimisation and a note that we would report the cause.

## 0055-GProp_SelGProps-GProp_VelGProps-cone-matrix-of-inertia-3010.patch

**`GProp_SelGProps::Perform(gp_Cone)` and `GProp_VelGProps::Perform(gp_Cone)` compute the matrix of
inertia wrongly, and `GProp_VelGProps` the centre of mass of the solid**
([#3010](https://github.com/SecondMouseAU/OCCTSwift/issues/3010)), separately from the `dim`
defect [#2992](https://github.com/SecondMouseAU/OCCTSwift/issues/2992) that `0050` and `0051` fix.
`Scripts/repro/3010-cone-inertia/` holds the probe, `run.sh` and the transcript.

The issue named two lines, `Dm(3, 3)` of each class. Measuring the whole matrix against an
independent integral found more, and the extra part is necessary: with the two lines fixed alone the
matrix a caller reads is still wrong, so the patch fixes what makes the result right and no more.
`Dm` is the matrix of inertia about the cone's location in the cone's axes. With
`r = R + v sin a`, `z = v cos a`, the surface element `r dv du` and, for the volume, the solid swept
between the axis and the patch, `dV = rho drho du dz` (the convention `0051` documents), the entries
per unit angle are:

| quantity | surface | volume |
|---|---|---|
| `Dm(3, 3)` | `int r^3 dv` = `(Z2 - Z1)(R1^3 + R1^2 R2 + R1 R2^2 + R2^3) / 4` | `cos a (Z2 - Z1)(R1^4 + R1^3 R2 + R1^2 R2^2 + R1 R2^3 + R2^4) / 20` |
| `z^2` moment | `cos^2 a (Z2 - Z1)(R Auxi2 + sin a (Z2^3 + Z2^2 Z1 + Z2 Z1^2 + Z1^3) / 4)` | `cos^3 a / 2 int v^2 r^2 dv` |
| `x z` moment | `cos a int r^2 v dv`, times `(Sn2 - Sn1)` | `cos^2 a / 3 int v r^3 dv`, times `(Sn2 - Sn1)` |

with `R1 = R + Z1 sin a`, `R2 = R + Z2 sin a`, `Auxi2 = (Z2^2 + Z1 Z2 + Z1^2) / 3`, and the angular
factors `(Delta + Cn2 Sn2 - Cn1 Sn1) / 2` for `cos^2 u`, the same with the sign flipped for `sin^2 u`,
`(Sn2^2 - Sn1^2) / 2` for `sin u cos u`.

### What was wrong

The issue's two lines hold: `GProp_SelGProps` `IR2` carries a spurious `cos a sin a` (the issue's
`Dm(3, 3)` of 12753.28 against 29452.43), and `GProp_VelGProps` `IR2` is a four-term cubic over 4
where the moment is a five-term quartic over 20, with the `sin a` that `0051` took out of `dim`. The
rest, all in the two cone overloads:

- **`GProp_SelGProps`.** `IZ2` carries an extra `(Z2 - Z1) cos a` and divides both of its terms by 4
  where only the `sin a` term takes it. `ISn2` is a copy of `ICn2`, with a plus where the sine
  integral has a minus. `ICnSn` is `(Cn2^2 - Cn1^2)` where the integral is `(Sn2^2 - Sn1^2) / 2`.
  `ICnz` and `ISnz` are a different polynomial. The `x` and `y` of the centre of mass use `sin a`
  where the quadratic term is `sin^2 a`, which a full turn hides because it multiplies terms in
  `sin u` and `cos u` that integrate to zero. `0050` said the centre was already right; for `z`, and
  for a full turn, it is.
- **`GProp_VelGProps`.** The centre of mass is the one of the lateral surface in all three
  coordinates (`Iz` is `GProp_SelGProps`'s expression), not of the solid: 4.81125224325 against
  5.25801138012 at the issue's `gp_Cone`. `ISn2`, `IZ2`, `ICnSn`, `ICnz` and `ISnz` are wrong as above.
- **Both: the assembly.** `inertia` is built as `gp_Mat` of the rows `lambda_i * v_i` from
  `math_Jacobi(Dm)`, which is `diag(lambda) V^T` and not `V diag(lambda) V^T`: the order and sign Jacobi gives
  the eigenvectors change the matrix, and the kernel's matrix for the issue's own cone has its
  74394 off the diagonal. And `Dm`, which is about the cone's location, is added to the Huyghens term of the
  centre of mass as if it were already about the centre of mass.

The patch computes every entry from the integrals above and assembles
`inertia = P Dm P^T - H(g, Location) + H(g, loc)`, `P` being the columns of the cone's axes and `H`
the `GProp::HOperator` term. That is the matrix of inertia about `loc` whatever `loc` is. The mass is
not touched, and neither is the Jacobi assembly of the cylinder, sphere and torus overloads.

**It applies on top of `0050` and `0051` and not without them:** its hunks take their context from
the lines those two change (`git apply --check` on the bare `V8_0_1` files fails; on the files with
`0050` and `0051` applied it passes, and the reverse applies too).

### Why an independent integral is the arbiter

As for `0050` and `0051`, neither class has a caller in OCCT, so there is no call site to copy
([`okf/policies/follow-occt-callers.md`](../../okf/policies/follow-occt-callers.md)). The arbiter is a
Gauss-Legendre integral over the cone's own parameter space (24 nodes, a triple integral for the
solid) written in `probe.cxx`; it shares no formula with the kernel's code or this patch. It
reproduces the issue's closed form: `29452.431127404328` for `Dm(3, 3)` at `a` = pi/6, `R` = 5,
`v` in [0, 10].

### Measured, macOS arm64, before and after

`run.sh`: the control is `GProp_SelGProps.cxx` and `GProp_VelGProps.cxx` recompiled from source with
`0050` and `0051` applied and linked ahead of `libOCCT-macos.a`; the variant is the same with `0055`.
Compared with the integral: mass, centre of mass, the matrix of inertia about the centre of mass, and
the moment about an oblique axis through (2, -1, 3) from a `loc` there. Sixteen cases (semi-angles
pi/6, pi/12, pi/3, -pi/6, -pi/12 and -pi/4; full and partial turns; one straddling `v` = 0) in a
frame untilted at the origin and a frame tilted and translated, 64 checks:

| case (untilted frame) | class | largest matrix entry error, before | after | centre of mass error, before | after |
|---|---|---|---|---|---|
| pi/6, R 5, v 0..10 (the issue) | surface | 2.5 | 1.2e-15 | 1.2e-14 | 1.2e-14 |
| | volume | 2.4 | 6.3e-15 | 0.45 | 1.9e-14 |
| pi/12, R 8, v 0.5..6 | surface | 0.75 | 7.6e-16 | 5.0e-15 | 5.0e-15 |
| | volume | 1.0 | 4.2e-15 | 0.071 | 1.6e-14 |
| pi/3, R 8, v 0.5..6 | surface | 1.0 | 4.8e-16 | 1.6e-15 | 1.5e-15 |
| | volume | 1.7 | 1.3e-15 | 0.098 | 4.8e-15 |
| -pi/6, R 8, v 0.5..6 | surface | 1.4 | 7.8e-16 | 1.4e-15 | 1.4e-15 |
| | volume | 2.7 | 3.4e-15 | 0.17 | 1.4e-14 |
| -pi/12, R 8, v 1..7 | surface | 1.2 | 4.9e-16 | 4.1e-15 | 4.1e-15 |
| | volume | 1.9 | 2.8e-15 | 0.11 | 2.8e-15 |
| pi/6, R 5, v 1..9, u 0.3..2.2 | surface | 4.9 | 3.9e-15 | 0.87 | 1.0e-14 |
| | volume | 8.2 | 3.4e-14 | 5.4 | 2.4e-14 |
| -pi/4, R 9, v 0.5..7, u 0.3..4 | surface | 0.83 | 3.5e-16 | 1.7 | 5.1e-15 |
| | volume | 4.9 | 2.8e-15 | 2.8 | 1.2e-14 |
| pi/6, R 5, v -3..4 | surface | 0.60 | 2.6e-16 | 7.9e-16 | 7.9e-16 |
| | volume | 2.4 | 4.4e-15 | 0.31 | 1.9e-15 |

Matrix entry errors are relative to the largest entry of the exact matrix. 64 of 64 checks fail
before and 0 of 64 after, with the largest matrix deviation 3.8e-14 and the largest centre-of-mass
deviation 7.9e-14. The negative semi-angles are `gp_Cone`'s own: its `v` then runs toward the apex,
and the cases keep `r` positive.

**The same probe on `gp_Cylinder` and `gp_Sphere` fails 16 of 16 and is not fixed here.** For the
full `gp_Cylinder` surface of radius 5 and height 10 `Dm(3, 3)` is 314.159 where the second moment
about the axis is 7853.98, which is the `R^2` the cylinder's `Dm(3, 3) = Alpha2 - Alpha1` drops, and
the same Jacobi assembly flips signs in its matrix. `GProp_VelGProps`'s cylinder and sphere centre
of mass is wrong for a partial turn too (1.4 and 1.0 in the probe). Measured and not diagnosed: it
is another cluster, the first question #3010 asked and left open, and a fix belongs in its own
patch. That patch is [`0057`](#0057-gprop_selgprops-gprop_velgprops-cylinder-sphere-torus-inertia-3091patch).

**Nothing in the bridge reads any of it.** `GeometryProperties.coneSurfaceArea` and `.coneVolume`
read `Mass()` alone, so no Swift test reaches these values and there is no `OCCTSWIFT_LOCAL`-gated
test for this patch; `probe.cxx` and `run.sh` are the regression, and `run.sh` exits 1 unless the
control fails and the variant passes.
*Since #3091:* `GProps.cone` reads them, and `Issue3091GPropsTests` compares the cone overloads with
the same independent integral (gated on `OCCTSWIFT_LOCAL=1` until `v4.0.0-kernel.5`).

**Filed upstream** with `0050` and `0051` as one PR, [OCCT#1599](https://github.com/Open-Cascade-SAS/OCCT/pull/1599) against `IR`, because its hunks need their context lines.

**Retire** once the bundled OCCT includes this fix.

## 0056-BRepLib-Plane-creates-the-default-plane-under-the-magic-static-lock-3039.patch

**`BRepLib::Plane()` creates its process-global plane on first use with no lock, so concurrent
first use of `BRepLib_MakeEdge2d` reads a plane the losing thread has released**
([#3039](https://github.com/SecondMouseAU/OCCTSwift/issues/3039)). `Scripts/repro/3039-brep-lib-plane/`
holds the probe, `run.sh`, the harness and the transcript.

`BRepLib_MakeEdge2d` builds every vertex through `BRepLib::Plane()->Value(x, y)` (`Point`, line 52),
projects through it (`Project`, line 64) and attaches it to the edge (`UpdateEdge`, line 621). The
plane is a file-scope handle the getter creates when it finds it null:

```cpp
static occ::handle<Geom_Plane> thePlane;
...
if (thePlane.IsNull()) { thePlane = new Geom_Plane(gp::XOY()); }
return thePlane;
```

Two threads making their first 2D edge together both see a null handle and both assign. The losing
assignment releases the plane the other thread has already read through, so a vertex is read from
freed memory: coordinates of zero or denormal garbage, or a SIGSEGV, SIGBUS or SIGTRAP, with no
diagnostic. `Scripts/repro/342-boolean-ops/README.md` looked at these statics and concluded that
nothing calls the setters "so there is no write to race against"; the getter itself writes.

### The fix

The plane is held by a function-local static, which C++11 initialises under a lock:

```cpp
static occ::handle<Geom_Plane>& thePlane()
{
  static occ::handle<Geom_Plane> aPlane = new Geom_Plane(gp::XOY());
  return aPlane;
}
```

`Message::DefaultMessenger()` creates its messenger the same way, which is the call site this follows
([`okf/policies/follow-occt-callers.md`](../../okf/policies/follow-occt-callers.md)). The setter keeps
its behaviour, including that a null argument restores the default plane, which the old getter did by
re-creating it on the next read. The setter is still unsynchronised, as `BRepLib::Precision`'s is, and
`BRepLib::Precision`'s static, one line above, is untouched. `BRepBuilderAPI::Plane()` forwards to the
same function and is covered with it.

**No other patch touches `BRepLib.cxx`, so it applies to the bare `V8_0_1` file.** It adds no raise or
throw, and `Scripts/occt-raise-if-map.txt` changes only in its stamp.

### Measured, macOS arm64, before and after

`run.sh`, 3000 fresh processes per row, N threads released together from a spin barrier, each
building a half circle and reading both vertices (the race can only happen on the first call in a
process). `asset` is the archive as shipped; `control` is the unmodified `BRepLib.cxx` recompiled and
linked ahead of it (same defect, higher rate: the flags are not the build's own); `warm` is `control`
with `BRepLib::Plane()` called once before the threads start.

| threads | row | clean | wrong vertex | SIGSEGV | SIGBUS | other signal |
|---|---|---|---|---|---|---|
| 4 | asset | 2921 | 12 | 13 | 53 | 1 |
| 4 | control | 2251 | 743 | 4 | 2 | 0 |
| 4 | **patched** | **3000** | 0 | 0 | 0 | 0 |
| 4 | warm | 3000 | 0 | 0 | 0 | 0 |
| 16 | asset | 2871 | 13 | 54 | 52 | 10 |
| 16 | control | 2632 | 339 | 14 | 13 | 2 |
| 16 | **patched** | **3000** | 0 | 0 | 0 | 0 |
| 16 | warm | 3000 | 0 | 0 | 0 | 0 |

The warm row is the control for the cause: initialising the plane first removes every failure, so
the lazy initialisation is what fails and not the thread count or the edge construction.

### The Swift test

`Issue3039BRepLibPlaneFirstUseTests` (`OCCTThreadTests`) runs the same race through
`Shape.edge2dFromCircle` and `Shape.edge2d(from:to:)`. One process can only test it once, so the
parent test re-runs the test runner as 64 fresh child processes (same executable and arguments minus
`--filter` and `--skip`, plus a filter for the suite and `OCCTSWIFT_3039_CHILD=1`), each of which
builds its first `edge2d*` edges on 16 threads. It was gated on `OCCTSWIFT_LOCAL=1` while the pinned
asset lacked the patch, and is ungated since `v4.0.0-kernel.5` pinned it (passed in 135 s against that
asset, 2026-10-07). Against the unpatched archive 7, 6 and 12 of 64 children failed in three
runs, one of them by SIGSEGV; with `BRepLib.cxx` recompiled at `-O0 -g` with this patch swapped into a
copy of the archive, 0 of 64 failed in each of four runs.

**Upstream checked 2026-10-07:** no PR or issue; `IR` and `master` carry the same lines at
`BRepLib.cxx` lines 83-85 and 138-145, and dpasukhi's "Eliminate mutable static state" series
(OCCT#1519, #1180) did not touch this file. **Filed upstream as [OCCT#1597](https://github.com/Open-Cascade-SAS/OCCT/pull/1597) against `IR`**, with the GTest `BRepLib_Test.Plane_ConcurrentFirstUse` and a death-test child; the failure rates are in the PR.

**Retire** once the bundled OCCT includes this fix.


## 0057-GProp_SelGProps-GProp_VelGProps-cylinder-sphere-torus-inertia-3091.patch

**`GProp_SelGProps::Perform` and `GProp_VelGProps::Perform` compute the matrix of inertia of a
`gp_Cylinder`, `gp_Sphere` and `gp_Torus` wrongly, the centre of mass of the solid for a partial turn,
and the area and volume of a torus over part of the tube**
([#3091](https://github.com/SecondMouseAU/OCCTSwift/issues/3091)), the cluster
[`0055`](#0055-gprop_selgprops-gprop_velgprops-cone-matrix-of-inertia-3010patch) left open beside the
`gp_Cone` overloads. `Scripts/repro/3091/` holds the probe, `run.sh` and the transcript.

The issue measured the cylinder and the sphere (16 of 16 failing); measuring the torus the same way
found it fails too, so it is in the patch. Six overloads, one defect pattern:

- **The assembly.** Each builds `Dm`, the matrix of inertia about the location of the surface in its own
  axes, then `gp_Mat(rows of lambda_i * v_i)` from the Jacobi decomposition of `Dm`. That is
  `diag(lambda) V^T` and not `V diag(lambda) V^T`, so the sign Jacobi happens to give an eigenvector
  changes the matrix, and `Dm`, which is about the location, is added to the Huyghens term of the
  centre of mass as if it were already about the centre of mass. The patch assembles
  `inertia = P Dm P^T - H(g, Location) + H(g, loc)` as `0055` does.
- **`Dm` itself.** The cylinder surface has `Dm(3, 3) = Alpha2 - Alpha1` where the second moment about
  the axis is `R^3 (Z2 - Z1) (Alpha2 - Alpha1)` (the issue's 314.159 against 7853.98: the `R^2` and the
  height), and its `xz` and `yz` entries drop a factor `R`. The volume overloads carry polynomials
  that match no integral. Every entry is now the closed form of the integral, per the table in the
  patch header.
- **The solid's centre of mass.** `GProp_VelGProps`, `gp_Cylinder`, partial turn: `R` times the mean unit
  vector where the sector of a disc has `2 R / 3` times it. `gp_Sphere`: `R` where the wedge of a ball
  has `3 R / 4`, and `R (sin v2 + sin v1) / 2` in `z` where it is `3 R (sin v2 + sin v1) / 8`, so a
  part of the latitude reads wrong even over a full turn. A full cylinder turn hides the first, a
  whole sphere hides both.
- **`gp_Torus`.** Both classes read the area (`R r (u2 - u1)(v2 - v1)`) and the volume
  (`R r^2 (u2 - u1)(v2 - v1) / 2`) as if the tube were a full turn: over part of the tube the area
  is `r (R (v2 - v1) + r (sin v2 - sin v1))(u2 - u1)`, and the solid below is
  `r^2 (R (v2 - v1) / 2 + r (sin v2 - sin v1) / 3)(u2 - u1)`. The centre of mass of both reads the plain mean of
  `rho = R + r cos v` in `x` and `y` and of `r sin v` in `z`, where the element weights them: the
  surface by `int rho^2 dv / int rho dv`, the solid by the matching ratios of `t`-weighted integrals.
  And `GProp_VelGProps::Perform(gp_Torus)` reads `cos(Alpha2)` where `cos(Teta2)` is meant, in
  the one line that sets `Cnt2`.

**The torus volume of a part of the tube is a convention OCCT does not state, and this patch chooses
one.** The patch takes the solid swept by the segment from the circle through the centres of the tube
to the patch, `P = ((R + t r cos v) cos u, (R + t r cos v) sin u, t r sin v)` with `t` in [0, 1] and
`dV = (R + t r cos v) t r^2 dt dv du`. A full range gives `2 pi^2 R r^2` as the code already read, and
the other volume overloads sweep the solid from the axis or the centre to the patch in the same
way. A different choice (the solid between the patch and the torus's axis, say) would change only
the partial-tube torus volume.

**Not fixed, and not scoped here:** `Perform` stores `g` in global coordinates, where `CentreOfMass()` and
`MatrixOfInertia()` read it relative to `loc` (and `GProp_GProps::Add` reads it as `loc + g`), so
both are right only when `loc` is the origin. It is the same in every `Perform` of both classes,
including the cone's, and older than `0055`. `GProps` (Swift) therefore leaves the reference point
out and fixes it at the origin.

`GProp_SelGProps` and `GProp_VelGProps` still have no caller in `Libraries/occt-src`, so
[`okf/policies/follow-occt-callers.md`](../../okf/policies/follow-occt-callers.md) has no call site to
copy. The arbiter is an independent Gauss-Legendre integral over the surface's parameter space,
written in `Scripts/repro/3091/probe.cxx` and in `Issue3091GPropsTests`, which shares no formula
with the kernel's.

### Measured, macOS arm64, before and after

`run.sh`: the two translation units recompiled from source at `-O3`, once with `0050`, `0051` and
`0055` (the control) and once with `0057` on top (the variant), linked ahead of `libOCCT-macos.a`.
96 checks: three shapes, the surface and the solid, four ranges each (a full turn and three partial
ranges in `u` and `v`), the frame untilted and tilted and translated, each checking mass, centre of
mass, the matrix of inertia about it, and `MomentOfInertia` about an oblique axis through (2, -1, 3).
**96 fail before and 0 after**, the largest deviation 1.1e-13.

| shape, class | largest matrix entry error, control | variant | largest centre-of-mass error, control | variant |
|---|---|---|---|---|
| cylinder, surface | 4.4 | 2.6e-14 | 1.2e-14 | 1.2e-14 |
| cylinder, volume | 13 | 1.1e-13 | 2.1 | 1.4e-13 |
| sphere, surface | 3.4 | 4.4e-14 | 9.0e-15 | 9.0e-15 |
| sphere, volume | 5.2 | 5.2e-14 | 1.0 | 1.9e-14 |
| torus, surface | 2.5 | 8.0e-15 | 1.2 | 1.2e-14 |
| torus, volume | 2.3 | 2.2e-14 | 2.8 | 5.5e-14 |

Matrix errors are relative to the largest entry of the exact matrix. The torus mass over part of
the tube is off by up to 81% (surface) and 43% (volume) in the control and exact in the variant. The
issue's number reproduces: the full cylinder surface, `R` = 5, height 10, reads 314.15926535897933
about its axis in the control against 7853.981633974483 in the variant and in the integral.

The patch was authored against the patched tree (`0050`, `0051` and `0055` applied) and applies only
on top of them. It adds no raise or throw, so `Scripts/occt-raise-if-map.txt` changes only in its
stamp.

### The Swift test

`GProps` (#3091), the wrapper of both classes, is the first Swift API that reads these values, so the
regression test goes through it: `Issue3091GPropsTests` (`OCCTAnalysisTests`).
`everyOverloadAgreesWithTheIndependentIntegral` compares all 48 combinations of shape, class, range
and frame with a Gauss-Legendre integral written in the test. It and three more tests (the issue's
number, the solid's centres for a partial turn and the principal properties) were gated on
`OCCTSWIFT_LOCAL=1` while the pinned asset lacked the patch, and are ungated since
`v4.0.0-kernel.5` pinned it; they pass against that asset. The counterfactual below was measured
before the repin and is the record that they fail without the patch. Measured by swapping the two members of a copy of the pinned archive (the `ar r` shortcut, not a
rebuild), on macOS arm64, with `OCCTSWIFT_LOCAL=1`: on the archive as shipped 4 of the suite's 10 tests
fail (the four gated ones) and 6 pass; with the members built from `0050`, `0051` and `0055` only,
the same 4 fail, on 112 cylinder, sphere and torus findings and none for the cone; with `0057` on top
all 10 pass, the 48-combination test in 9 s (its tolerance is 1e-9; the probe's largest deviation is 1.1e-13). The six that run on
the asset were each broken with their subject (a range order left unchecked, the frame origin
ignored, the kind inverted, `add` reporting success without composing, a non-finite axis let through)
and each failed.

**Upstream checked 2026-10-07:** no PR or issue about either class; both files last changed upstream
on 2026-03-10 (OCCT#1156, an LProp unification already in the pinned tree). **Not yet filed
upstream**; it goes up with `0050`, `0051` and `0055` as one report on the cone, cylinder, sphere
and torus, with a GTest of its own then, since upstream's reviewers ask for one on every PR.

**Retire** once the bundled OCCT includes this fix.

## 0058-BRepOffsetAPI_MiddlePath-Build-carries-a-vertex-path-forward-3105.patch

**`BRepOffsetAPI_MiddlePath::Build` casts a path that has already reached a vertex to an edge, reads
past the end of a path, hands a null face to `BRep_Tool::CurveOnSurface` and, for a sweep that never
reaches the end section, never ends; it aborts the process or runs on**
([#3105](https://github.com/SecondMouseAU/OCCTSwift/issues/3105)). `Scripts/repro/3105-middlepath-patch/`
holds the probe, the scan, the validation, the transcripts and the review images.

`Build()` starts one path per vertex of the start section along the edges of the solid, away from the
start wire, and builds one section per level from level `i` of two neighbouring paths, joining them by
an edge of the solid or by a new edge on the face that holds both. A path that reaches the end section
before the others is padded with its last vertex, so its section is a point, and a section whose two
ends are points is already handled (`EdgeSeq(j - 1) = E12` or `ProperEdge`). The faults are the places
where that handling stops:

| Lines (V8_0_1) | Pairs | What is read |
|---|---|---|
| 580, 584 | 91 | `myPaths(k)(i).ShapeType()` where the pad at level `i` cast the vertex a pad at level `i - 1` left, and appended the null shape that `TopExp::LastVertex` returns for it |
| 664, 668 | 21 | `TopoDS::Edge(myPaths(k)(i - 1))` of a vertex, or of level 0 |
| 672, 706 | 4 | `BRep_Tool::CurveOnSurface(E1, theFace, ...)` with `theFace` null |

(116 of the 196 pairs of 16 solids that share no vertex and are not the same face, one process per pair,
against `v4.0.0-kernel.5`; the 4 and 21 are one pair different from the faulting line because `ushape 4 7`
reaches the cast before it reaches the null face.)

### The contract (settled by the user, 2026-10-09)

The intended input is the two end caps, faces or wires, of an extruded, lofted or swept body, and the
result is the sweep path; the use case is recovering sweep parameters from imported geometry. For any
other pair the function is best-effort. It never crashes, aborts or runs on, for any face or wire pair.
Where the algorithm yields a valid connected wire it is returned even if the path is odd (loops,
zigzags, leaves the bounding box): the caller judges it. Where no result exists (the end section is not
reached within the level bound, no connecting edge, a null edge from `BRepLib_MakeEdge`) the builder is
left not done and the bridge answers nil. nil never means "the shape is not a pipe", only "no path could
be built". The 14 doubtful paths are therefore kept, and the level bound is the number of edges of the
solid.

### What the algorithm intends, and the change

The user's reading of the images was that the paths `Build()` traces are valid guides (one per start
vertex, along the edges of the solid to the end face), so a path that has arrived is a point and the
sections that follow are sections of points. That is what the first pad already does; the code simply
cannot do it twice. The change is the same handling in the places that cast, and a bound where the
sweep does not terminate:

- **The pad appends the vertex again** (`PadPath`, 8 lines). Carrying a point forward is what the
  first pad does; refusing at the second one instead computes 72 pairs fewer (ablation B1 below).
- **A vertex end of a new section edge is read as `BRep_Tool::Parameters(vertex, face)`** (`EndPoint2d`,
  replacing about 25 lines that cast the path's previous edge). A vertex has no pcurve; the previous
  edge ended at it, so its end on the face is the vertex's own parameter, which is what the previous
  edge would have given. Refusing instead computes 81 fewer.
- **No face holds both edges** (`theFace` null): the connecting edge of the solid is searched without
  the face condition (the condition disambiguates parallel edges and has no meaning without a face);
  if there is none, return. Without both lines 46 pairs abort.
- **`BRepLib_MakeEdge` of a null 2d line, or of vertices not on the line** (`MakeSectionEdge`): a null
  edge instead of a fault or a thrown `StdFail_NotDone`; a null candidate is not "good" in the choice
  that follows. Without it 55 more pairs throw.
- **`GeomAPI_Interpolate::Load` with a zero tangent**: the flag array the interpolation already takes
  says the point has no tangent imposed; set it where every path is a point. Without it 12 pairs
  throw `Standard_ConstructionError`.
- **The insertion before level `i` (`ChooseEdge == 1`)** casts the element at level `i`: return if it is
  not an edge. Without it 5 pairs abort.
- **A bound on the levels**: a path holds each edge of the solid at most once, so the loop ends after
  `EFmap.Extent()` levels. Without it every sweep that does not reach the end section runs on, one
  process 5 s and 1 GB in, and 6 of the first 7 pairs of the scan ran past its limit.

Seven changes, each measured against the scan by removing it (ablations B1 to B7, `abl2/` in the
scratch tree, numbers in `ablation-summary.txt`). Four checks that looked reasonable were removed
because removing them changed nothing in 573 pairs: a null `PCurve` in the second branch, a null
chosen edge, `Interpol.IsDone()`, and the length of the path in `PadPath`.

**What could go wrong, and what upstream would ask.**
- This is a behaviour change and not a guard. Every pair that returned a path returns the same path
  (the 42, to six places), but a pair that aborted now returns one, and nothing in OCCT's own tests
  covers `BRepOffsetAPI_MiddlePath` with a path that is a point at the first level or a concave
  corner. Upstream will ask for a GTest with those solids and an independent check of the result.
- The new results are as good as the interpolation that builds them. For the U- and L-shaped prisms
  the section centroids zigzag and the spline imposed through them with tangents from the paths can
  loop or overshoot: 14 of the 81 new paths do (listed in `review/index.md`). They are valid wires, they
  end at the centroids, and they are not what a person would draw. Under the contract they are returned; upstream may prefer to refuse
  them, or to interpolate without the imposed tangents, which is a separate change to the final
  phase.
- `EFmap.Extent()` as the bound is an argument, not a theorem: the insertion at `ChooseEdge == 1` can
  lengthen a path, and a sweep over a solid whose paths need more levels than it has edges would be
  refused. The most any of the 124 pairs that answer needed was a third of the bound.
- `BRep_Tool::Parameters` of a vertex on a periodic face can pick the other side of the seam than the
  pcurve of the previous edge would have; the pairs of the scan with curved faces (cylinder, cone,
  frustum, tube, bend, capsule) came out unchanged where they answered before; whether any of the new
  ones reads a vertex on a seam was not measured.
- A refusal returns with the builder not done and does not say why, which is what the start of
  `Build()` already does.

**Where it refuses.** Every pair that answers not done is one of these, measured in
`guards-final.txt`:
- the end section is not reached within `EFmap.Extent()` levels: 38 pairs that share no vertex, 35 of them among the 116 (a cap of a tube against
  its bore, 2; the outer wall of a cube with a square hole against the wall of the hole, 24; eight of
  the fused L-shaped bar, five of them among the 116; the four opposite triangle pairs of an octahedron, where two of three paths
  end on the same vertex of the opposite triangle and none reaches the third). The sections
  themselves are never the end section, so there is no sweep to compute;
- no connecting edge of the solid and no common face (28 pairs of all 573, 22 of them touching sections);
- a vertex end is not on the face that holds the new edge (13, all of the fused bar, 7 of them touching);
- the 2d line between the two ends is null (7, six of the triangle prism, all touching);
- the insertion at `ChooseEdge == 1` meets a vertex, not an edge (5, all touching);
- the kernel already answered not done, before any of this (19, as before).

### Measured

All 573 pairs of the 16 solids, one process per pair with a limit, the probe built in the release
macros (`-DNo_Exception -DNDEBUG`) against the pinned archive with `BRepOffsetAPI_MiddlePath.cxx`
compiled from the 44-patch tree linked ahead of it (control) and the same file with `0058` (variant):

| 573 pairs | abort | run past the limit | throw (caught) | answer a path | answer not done |
|---|---|---|---|---|---|
| control (`scan-before.txt`) | 423 | 0 | 89 | 42 | 19 |
| `0058` (`scan-after.txt`) | 0 | 0 | 56 | 124 | 393 |

Of the 196 pairs that share no vertex and are not the same face: control 116 abort / 37 throw / 41 path
/ 2 not done; patched 0 / 22 / 122 / 52. Of the 116 aborts: 60 of the 91 in G1 and all 21 in G2 answer a
path (81 in all, all valid; 14 doubtful), the other 35 answer not done. The 42 pairs that returned a
path return the same one, edge count, length and centre of mass to six places (`cmp.py`).

**Geometric validation of every answered path** (`validate.py`, `validate-out.txt`): a valid wire by
`BRepCheck_Analyzer`, connected, from the centre of the start section to the centre of the end section
(within 1e-6), in the plane of each section, no shorter than the chord between them, no longer than the
longest traced guide, inside the solid for the convex solids and inside its bounding box for the
others, no crossing of itself where the path lies in a plane, and identical on three runs. The 81 new
paths pass all of it except: 4 (`star 0/4, 1/4, 2/4, ushape 4/6`) leave the bounding box, and in G2 10
(`lshape 3/5`, `ushape 0/4, 0/5, 0/6, 1/3, 3/5, 3/6, 3/7, 4/7, 5/7`) leave it, cross themselves or run longer
than the longest guide. Those 14 are the doubtful ones. The 42 older paths pass everything.
`tri 0/0` (the same face twice) answers a wire with an edge that has no curve and fails
`BRepCheck`; the bridge refuses it and the kernel is not changed for it.

### The Swift test

`Issue3105MiddlePathKernelTests` (`OCCTModelingTests`) walks every pair of faces of a hexagonal prism, an
L-shaped prism, a U-shaped prism, a tube and an octahedron and checks each path it gets: valid, from
the centroid of the start face to the centroid of the end face, between the chord and one and a half
times it; the counts per solid are the scan's (10, 10, 21, 1, 0). It is gated on `OCCTSWIFT_LOCAL=1`,
the way the other unpinned patches' tests were, and runs in `kernel-integration.yml`. Measured with the
`ar r` swap into a copy of the pinned xcframework, macOS arm64: on the archive as shipped it aborts the
process with SIGSEGV (`swift-test-unpatched.txt`); with the member built from `0058` all five tests pass
(`swift-test-patched.txt`), and the nine #3098 guard tests still pass. The bridge guard stays: it
protects every kernel without `0058`, and is retired at the repin that pins it.

**Upstream checked 2026-10-09:** no PR or issue mentions `MiddlePath`, and `IR` carries the same file as
`V8_0_1`. **Not yet filed upstream**; it needs a GTest of its own in `TKOffset/GTests/` (a hexagonal
prism, faces 0 and 2) and the contract above stated in its description.

**Retire** once the bundled OCCT includes this fix.

# Retired patches

The `.patch` files below are **deleted**. Each fix now comes from the pinned OCCT release itself, so
re-applying it would fail (the change is already in the source tree) and `build-occt.sh` would abort.
The writeups are kept because for several of these they are the only record of the root cause at
this depth; read them as history, not as a description of anything the build still does.

Before each file was deleted its hunks were checked against the as-merged upstream form in the
pinned tag, because review can change a patch between submission and merge, and for `0001` it did.
Each section opens with that verdict.

## 0059-ChFi3d-Builder-fillets-that-meet-exactly-are-built-not-refused-3207.patch

**Two fillets that meet exactly are built instead of refused** ([#3207](https://github.com/SecondMouseAU/OCCTSwift/issues/3207), upstream [OCCT#1177](https://github.com/Open-Cascade-SAS/OCCT/issues/1177) and `tests/bugs/modalg_7/bug25478_1`), `src/ModelingAlgorithms/TKFillet/ChFi3d/` in the pinned tree. **Candidate: no PR, nothing reported upstream.**

On a 4 x 10 x 6 box, fillets on the two top edges along Y give `IsDone() == false` at r = 2 (half the 4 wide face) and valid solids up to 1.99999999. The refusal is the OCC119 guard against intersecting fillets, in two places that both throw `StdFail_NotDone("... fillets have too big radiuses")`: `PerformOneCorner` (the end caps on the end face touch at a point) and `ChFi3d_StripeEdgeInter` (the two contact curves on the top face coincide). With both lifted, r = 2 builds, but the top face between the stripes is left with no width and the result is BRepCheck-invalid (8 faces, one of area 0).

The change lets exactly that through: `ChFi3d_IsEndContact` (the caps only touch end to end, and the first end is not past the second's), a `ChFi3d_StripeEdgeInter` that returns true when one segment spans both curves, then `ShapeFix_FixSmallFace::FixStripFace` on the result and a `BRepCheck_Analyzer` guard that turns a not-valid answer back into "not done". The two quarter cylinders end up sharing one edge: a semicircle.

**What it does not do.** A radius above half the width is refused as before. The fillet surfaces cross, and the stripe builder only knows how to cut a face with a stripe, not how to trim two stripes at the curve where they cross: with the checks lifted for r = 2.2 the result is "done" with volume 330 for a 240 box. The right construction is the intersection of the single-edge fillets (`BRepAlgoAPI_Common`), which matches the analytic volume on 2.0 to 3.99999 in `Scripts/repro/fillet-exact-meeting-fix/`; it is a different algorithm and is not carried here.

Known limits: `Modified()`/`Generated()` return the faces from before `FixStripFace`; a meeting exact only up to rounding noise (random rotations of the box) fails cleanly 18 times in 40; `BRepFilletAPI_MakeChamfer` at d = w/2 is still refused; `Generated` history for the removed top face reads as deleted.

Measured against the `v4.0.0-kernel.5` asset with the three changed files override-linked (`Scripts/repro/fillet-exact-meeting-fix/README.md`): 715 box cases before and after, none regressed and none newly invalid; 16 `IsDone` false now valid with the analytic volume.

## 0060-BRepFilletAPI_MakeFillet-fillets-that-cross-or-run-out-of-face-3208.patch

**Fillets whose arcs cross, and fillets that run out of face, are built** ([#3208](https://github.com/SecondMouseAU/OCCTSwift/issues/3208), upstream [OCCT#1177](https://github.com/Open-Cascade-SAS/OCCT/issues/1177)), `src/ModelingAlgorithms/TKFillet/BRepFilletAPI/` in the pinned tree. **Candidate: no PR, nothing reported upstream, the behaviour is waiting on the maintainer's review of `Scripts/repro/fillet-pivot-edges/review/`.**

On a 4 x 10 x 6 box, fillets on the two top edges with r1 + r2 > 4 give `IsDone() == false` (`PerformOneCorner` and `ChFi3d_StripeEdgeInter` refuse the crossing end caps and contact curves), and so does one fillet with r >= 4 (the contact line on the top face is outside the face: `ChFiDS_StartsolFailure`). The stripe builder only cuts a face with a stripe; crossing stripes need a surface-surface section in the data structure, and a fillet that runs out of face needs an edge as its second support. This patch does not add either. After `Compute()` fails, `BRepFilletAPI_MakeFillet::Build` tries two constructions, each checked for a valid closed solid that takes material away:

- contours that share no vertex, all constant radius: the `BRepAlgoAPI_Common` of the shape filleted on each contour alone. Each arc is tangent to the wall it starts on and the arcs cross on the face between at an included angle below 180 degrees (the intersection of the rounded profiles; the closed forms are in `oracle.py`);
- one straight edge between two planar rectangles at a right angle: the pivot rule. A face that runs out before the tangent point ends the arc at its far edge: the arc stays tangent to the other face and passes through that edge, or through both far edges when both run out. The shape is cut by the prism of the region between the arc and the faces, and the cut must remove exactly cross-section area times edge length.

Between them: the contour result must remove at least the maximum and at most the sum of what each contour removes, and the builder is reset so that its faulty contours read zero. `Modified`, `Generated` and `IsDeleted` know nothing of the new faces. Contours that share a vertex, variable radius, curved or non-rectangular faces and concave edges decline as before. `ChFi3d_Builder` gains the inline accessor `InitialShape()`; `TKFillet` lists `TKPrim`.

Measured against the `v4.0.0-kernel.5` asset with 0058, 0059 and the changed units override-linked (`Scripts/repro/fillet-pivot-edges/README.md`): 715 box cases before and after, 312 valid ones identical, 331 unchanged, 70 `IsDone` false now valid, none newly invalid; every new success valid, closed, tessellating, deterministic and within 1e-11 of the analytic volume.

## 0035-STEPControl-Writer-drop-per-transfer-init-1259.patch

**RETIRED 2026-09-20, one day after it landed. The `.patch` file is deleted.** It reintroduced
[#280](https://github.com/SecondMouseAU/OCCTSwift/issues/280), a silent shape-corruption bug, and
turned `kernel-integration.yml` red on `main`.

**What it did.** Removed `InitializeMissingParameters()` from `STEPControl_Writer::Transfer`, a
byte-identical backport of the one part of upstream
[OCCT#1259](https://github.com/Open-Cascade-SAS/OCCT/pull/1259) the pinned `V8_0_1` lacked.

**Why it was wrong, and the reasoning that got it wrong.** Its own writeup argued the call was
"nearly inert", because both of its guards read through the same process-shared actor that
`STEPControl_Controller`'s constructor has already populated, so in the default path both branches
are false. **The premise is true and the conclusion does not follow.** `InitializeMissingParameters`
is not only an initialiser, it is a *repair*:

```cpp
if (!GetShapeProcessFlags().second)
{
  ShapeProcess::OperationsFlags aFlags;
  aFlags.set(ShapeProcess::Operation::SplitCommonVertex);
  aFlags.set(ShapeProcess::Operation::DirectFaces);
  SetShapeProcessFlags(aFlags);
}
```

`DirectFaces` is exactly the operation whose absence causes #280. Constructing a
`STEPCAFControl_Reader`, which any XDE STEP read does, leaves the shared actor's `OperationsFlags`
empty, so the guard is **not** false on that path: the call fires and repairs the poisoned actor
before every write. Removing it removes the repair. The "default path" the argument reasoned about
was the only path it looked at.

**How it presented.** `kernel-integration.yml` runs the suite against a kernel built from this
directory, so it is the only job that ever sees an unpinned patch.
`STEPWriterCAFCorruptionTests`, #280's own regression guard, failed there: `CONICAL_SURFACE`
absent from the written file, the frustum down from 3 faces to 2, and its volume out by 63% while
still reporting `isValid == true`. CI bisects it cleanly: three green runs on `0034`'s branch and
on `main` after it merged, then failure on `0035`'s branch and on `main` after that merged.

**The lesson, which is about backporting rather than about this line.** Upstream dropped this call
as part of a coordinated change; whatever makes the drop safe upstream is in the quarter of #1259
our pin does not have. A byte-identical hunk is not a safe backport when three quarters of its
change is already present and the remaining quarter is what it depended on. Take the whole change
or none of it.

**Not to be re-backported** before a repin onto a kernel carrying #1259 in full, at which point it
arrives on its own. Tracked as [#2056](https://github.com/SecondMouseAU/OCCTSwift/issues/2056).

## 0036-IFSelect_WorkSession-per-instance-error-guard-1403.patch

**`errhand` is a recursion sentinel, and sharing it loses a thread's exception handling.** Every one
of the nine guarded blocks in `IFSelect_WorkSession` has this shape:

```cpp
if (errhand) { errhand = false; try { ... EvalSelection(sel); } catch (...) {} errhand = theerrhand; return iter; }
// the real work, reached only through that recursive call
```

The flag exists so the function wraps itself in a `try` exactly once. With two threads, A clears it
and recurses into the guarded path while **B sees it already false and takes the unguarded path**,
losing its exception handling entirely. That is a lost-protection bug rather than a torn flag, and
it was the busiest racing site in the whole data-exchange path.

The global was a pure mirror of the per-instance `theerrhand`, written only as
`theerrhand = errhand = ...`, so it is deleted and a per-instance
`mutable bool myInErrorHandler` takes the sentinel role. **No lock.** #363 is the precedent: it moved
`theAutoNaming` onto `XCAFDoc_ShapeTool` after upstream rejected the mutex framing, and
`docs/thread-safety.md` states the rule as relocating ownership rather than locking the wrong owner.

Measured by override-link against the TSan kernel
(`Scripts/repro/1403-workession-errhand/`): `IFSelect_WorkSession.cxx:86` goes from **6 race access
sites to 0**, `step_read` 4 races to 3, `iges_read` 15 to 11. The remaining
`IFSelect_WorkSession` strings in the patched logs are caller frames, which every DE operation has.

**Live in current upstream master**, not just the pin: `static bool errhand;` is still at
`IFSelect_WorkSession.cxx:78` with 36 references.

`bufstr`, the other global on that line, is deliberately untouched. It is returned as
`ToCString()`, so concurrent callers get pointers into one shared buffer; that is an API-shape
defect needing a signature decision, not a field move.

## 0001-ShapeFix_Face-guard-non-face-context-replacement-263.patch

**RETIRED 2026-08-03. The `.patch` file is deleted.** Shipped upstream in OCCT `V8_0_1` as [OCCT#1323](https://github.com/Open-Cascade-SAS/OCCT/pull/1323); the pin moved from `V8_0_0_p1` to `V8_0_1` in the same change.

**Equivalence check, the one that is not equivalent.** Upstream's merged form is *broader* than the one carried here: it guards `anApplied.IsNull() || anApplied.ShapeType() != TopAbs_FACE`, where this patch checked only the shape type. A face an earlier fix had *removed* rather than replaced would therefore have called `ShapeType()` on a null shape here. Retiring this patch is an upgrade, not a like-for-like swap. That is the reason every retirement gets diffed against its as-merged form rather than assumed identical because the PR says "merged".


**Fixes the upstream OCCT crash behind [#263](https://github.com/SecondMouseAU/OCCTSwift/issues/263)**
(reported upstream as [Open-Cascade-SAS/OCCT#1322](https://github.com/Open-Cascade-SAS/OCCT/issues/1322); fix
offered as [Open-Cascade-SAS/OCCT#1323](https://github.com/Open-Cascade-SAS/OCCT/pull/1323), CI green, ready for review).

`ShapeFix_Face::Perform` casts `Context()->Apply(myFace)` with `TopoDS::Face(S.EmptyCopied())` in
three places, none of which check the type. When an earlier fix sharing the same `ShapeBuild_ReShape`
context has replaced the face with a **compound** (e.g. a self-intersecting face split into several
faces), `Apply()` returns a non-face. The unchecked cast then builds an invalid `TopoDS_Face` handle
over a compound `TShape`; subsequent topology operations corrupt the heap and abort the process with
an uncatchable OS signal (`ShapeFix_Face::FixOrientation` → `BRep_Tool::Curve` → `BRep_TEdge::EmptyCopy`,
SIGSEGV/SIGBUS at varying addresses).

The compound replacement already exists on entry to `Perform` (it was recorded by a prior face's
fix), so the patch adds a single guard at the top of `Perform`: if `Context()->Apply(myFace)` is not
a face, record it as the result and return, since the replacement is already in the context and there is
nothing to fix here. This one guard covers all three cast sites.

**Validation** (fast path, no full rebuild): compile the single patched TU and link it *before*
`libOCCT-macos.a` so it overrides that symbol:

```bash
clang++ -std=c++17 -O2 -w -I Libraries/OCCT.xcframework/macos-arm64/Headers \
  -c Libraries/occt-src/src/ModelingAlgorithms/TKShHealing/ShapeFix/ShapeFix_Face.cxx -o /tmp/sff.o
clang++ -std=c++17 -O2 repro.cxx /tmp/sff.o \
  -L Libraries/OCCT.xcframework/macos-arm64 -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ -o repro
MMGT_OPT=0 ./repro
```

A 4-point "bowtie" face extruded into a prism and healed (`ShapeFix_Shape`) crashes 3/3 on stock
OCCT 8.0.0p1 and survives 5/5 with the patch; the four `OCCTReconstruct` `crash-repro` fixtures
likewise survive. `ShapeFix_Shape` output on valid box/sphere/cylinder is byte-identical to stock
(the guard only triggers for a non-face replacement, which never happens for a well-formed face).

Until the xcframework is rebuilt with this patch, the in-wrapper guard shipped in v1.8.3
(`occtHasSelfIntersectingWire`) prevents the crash from reaching this code.

## 0002-STEPControl_Writer-initialize-missing-shape-processing-1334.patch

**RETIRED 2026-08-03. The `.patch` file is deleted.** Shipped upstream in OCCT `V8_0_1` as [OCCT#1334](https://github.com/Open-Cascade-SAS/OCCT/pull/1334); the pin moved from `V8_0_0_p1` to `V8_0_1` in the same change.

**Equivalence check.** Identical: the carried patch reverse-applies cleanly against `V8_0_1`.


**Backports [Open-Cascade-SAS/OCCT#1334](https://github.com/Open-Cascade-SAS/OCCT/pull/1334)** ("Data
Exchange - initialize STEP writer healing parameters", merged 2026-07-10), which lands *after* our
`V8_0_0_p1` pin (tagged 2026-06-16). Fixes [#280](https://github.com/SecondMouseAU/OCCTSwift/issues/280).

`STEPCAFControl_Controller`'s constructor replaces the actor its base `STEPControl_Controller`
constructor had just configured, without re-applying `SetShapeProcessFlags`, and then `AutoRecord()`s
itself under the same `"STEP"`/`"step"` names the plain writer resolves by,
`STEPControl_Writer::SetWS()` unconditionally re-runs `SelectNorm("STEP")`. So after **any** XDE STEP
read (merely *constructing* a `STEPCAFControl_Reader` is enough, no `ReadFile`, no `Transfer`, no
document), every shape-level STEP write ran with **empty** `OperationsFlags`: `DirectFaces` never ran,
and faces built on indirect (left-handed) surfaces were silently dropped.

A cone frustum (r1=5, r2=2, h=10) wrote as a 2-face solid with its lateral `CONICAL_SURFACE` and seam
`LINE`s missing and 63% of its volume gone (408.407 → 151.844), while still reporting
`isValid == true`. Only cones were affected: box/cylinder/sphere/torus have no indirect surfaces.

p1 already *defines* `STEPControl_Writer::InitializeMissingParameters()` (which restores the default
ShapeFix parameters **and** the `SplitCommonVertex`/`DirectFaces` flags when absent) but never calls
it, dead code there, and `private`, so a consumer cannot invoke it either. The patch is upstream's
one-line fix: call it at the point of transfer.

**Validation:** `STEPWriterCAFCorruptionTests` in `Tests/OCCTIOTests` does the XDE read itself and
asserts the frustum still round-trips (3 faces, `CONICAL_SURFACE` present in the file, volume within
1% of the analytic 130π). Red against the stock p1 binary, green after this rebuild. It also fixes the
long-standing `cone()` failure in `StressFormatRoundTripTests`, which passed in isolation and failed in
every full run because `OCCTIOTests` reads a STEP first.

**Retire** once the bundled OCCT moves past upstream `e2de4398ca6bf034074e6921599da76a9941c792`.

## 0003-TopOpeBRep-non-reentrant-globals-fillet-298.patch

**RETIRED 2026-08-03. The `.patch` file is deleted.** Shipped upstream in OCCT `V8_0_1` as [OCCT#1374](https://github.com/Open-Cascade-SAS/OCCT/pull/1374); the pin moved from `V8_0_0_p1` to `V8_0_1` in the same change.

**Equivalence check.** Identical symbol for symbol: all five files, the same declarations become `thread_local`. Only the comment wording differs (upstream prefers one-liners).


**Fixes the upstream OCCT thread-safety defect behind [#298](https://github.com/SecondMouseAU/OCCTSwift/issues/298)**: concurrent `BRepFilletAPI_MakeFillet` builds on independent shapes corrupt each other.

`BRepFilletAPI_MakeFillet` reconstructs its result solid through the legacy `TopOpeBRepBuild` boolean engine (`ChFi3d_Builder::Compute` → `TopOpeBRepBuild_HBuilder::MergeSolid` → `TopOpeBRepBuild_Builder::SplitSolid`), which passes state between methods through **file-scope `static` variables**. That makes it non-reentrant: two fillet builds on separate threads produce a wrong-but-plausible solid that fails `BRepCheck`, silent bad geometry, no crash, no thrown error.

ThreadSanitizer on an 8-thread fuse+fillet stress (V8_0_0_p1) pinpoints the **functional** culprit as `STATIC_SOLIDINDEX` in `TopOpeBRepBuild_Builder.cxx`: `SplitSolid` sets it to 1/2 to tell `FillSolid` which operand it is splitting, and `FillSolid` reads it back to pick the operand shape. Concurrent reconstructions interleave the writes, so `FillSolid` mis-classifies faces and drops material (the ~260-unit volume loss in the repro). Fixing that one variable makes a stress of 1600 concurrent fillet builds return correct geometry every time (was ~15–20% corrupt).

The patch converts the fillet-path shared statics to `static thread_local` (each thread keeps its own copy of the cross-call state; single-thread behaviour is unchanged):

- **Functional** (cause the corruption): `STATIC_SOLIDINDEX` (`TopOpeBRepBuild_Builder.cxx`) and `STATIC_lastVPind` (`TopOpeBRep_kpart.cxx`, same cross-call-cache pattern, converted for the same reason).
- **Benign data races** on the same path (no geometry corruption observed, `STATIC_SOLIDINDEX` alone already gives correct geometry, but still UB; converted so concurrent fillet is TSan-clean): the constant/evolutive-radius blend solvers' scratch cache (`BlendFunc_ConstRad.cxx`, `BlendFunc_EvolRad.cxx`) and the ChFi3d curve checker's reused adaptor (`ChFi3d_Builder_6.cxx`).

This is the same class of fix, in the same engine, as [Open-Cascade-SAS/OCCT#1180](https://github.com/Open-Cascade-SAS/OCCT/pull/1180) (19 TKBool globals → `thread_local` across 8 files); `STATIC_SOLIDINDEX` and these were not covered by it.

**Validation:** the isolated pure-C++ repro (`fuse` two/three prisms → fillet the seam, 8 threads) returns BRepCheck-invalid solids across several wrong volumes on stock p1, and 0/1600 invalid with a single correct volume after the patch. ThreadSanitizer reports the `STATIC_SOLIDINDEX` and `BlendFunc` scratch races on stock p1 and is clean on the fillet path after the patch (only an unrelated benign `BOPAlgo_InitMessages` lazy-init race remains, in the boolean path, orthogonal). The in-wrapper `occtFilletMutex` that v1.12.1 shipped as the interim guard was **already removed in v1.12.3** once this kernel patch made fillet reentrant, the patch is now the sole protection.

**Submitted upstream** as [Open-Cascade-SAS/OCCT#1374](https://github.com/Open-Cascade-SAS/OCCT/pull/1374) (open). **Retire** once an upstream OCCT release includes these `thread_local` conversions and we re-pin to it.

## 0004-ShapeAnalysis_FreeBounds-init-owires-empty-input-310.patch

**RETIRED 2026-08-03. The `.patch` file is deleted.** Shipped upstream in OCCT `V8_0_1` as [OCCT#1377](https://github.com/Open-Cascade-SAS/OCCT/pull/1377); the pin moved from `V8_0_0_p1` to `V8_0_1` in the same change.

**Equivalence check.** Identical: the same `owires = new NCollection_HSequence<TopoDS_Shape>;` at the same place, upstream adding only a trailing comment. Note that `V8_0_1` rewrote far more of this function than this patch or `0007` did; see the carried-forward note below.

**Carried forward into 8.0.1 triage.** `V8_0_1` rewrote `connectWiresToWiresImpl` well beyond this
one-line fix and `0007`'s: the seed wire is now the first wire that *has* edges rather than
unconditionally wire 1, zero-edge non-manifold wires are appended straight to the output, the
function returns early when no wire has any edges, and `isUsedManifoldMode` is gone entirely,
taking with it the separate vertex-map closure detection that non-manifold wires used to get, so
`ShapeExtend_WireData` is now always constructed in manifold mode. `ConnectEdgesToWires` also skips
INTERNAL and EXTERNAL edges outright and remaps the reversed-orientation write-back through an
index table. Any of that can move what `Shape.freeBounds*` reports; it is measured, not assumed,
in the 8.0.1 absorb.


**Fixes the upstream OCCT crash behind [#310](https://github.com/SecondMouseAU/OCCTSwift/issues/310)**: `ShapeAnalysis_FreeBounds` (backing `Shape.freeBoundsClosedWires`/`freeBoundsClosedCount`/`freeBoundsOpenWires`) SIGSEGVs on certain shapes with multiple free-boundary components.

`ShapeAnalysis_FreeBounds::SplitWire` (its per-wire helper) finds each wire's closed sub-loops, then hands whatever edges weren't consumed to `ConnectEdgesToWires` to build the "open" result. When a wire's edges are **entirely** consumed by closed-loop detection, leaving zero leftover edges, that hand-off is an empty (but non-null) sequence. The call chain `ConnectEdgesToWires` → `ConnectWiresToWires` → `connectWiresToWiresImpl` starts with:

```cpp
if (iwires.IsNull() || !iwires->Length())
{
  return;
}
```

For empty input this returns **without ever assigning `owires`**, every caller in the file starts from a freshly-defaulted (null) handle, so the null propagates all the way back to `SplitWire`'s `open` output parameter, then to `ShapeAnalysis_FreeBounds::SplitWires`'s `open->Append(tmpopen)`, dereferencing the null handle, an uncatchable SIGSEGV. Not a data-volume threshold: it depends only on whether *any* single free-boundary component happens to close with nothing left over, so a shape with 150+ loops can be fine while a 2-loop shape crashes (and vice versa).

**Fix:** the one-line contract restoration `connectWiresToWiresImpl`'s own non-empty path already follows a few lines down (`owires = new NCollection_HSequence<TopoDS_Shape>;` before populating it), "nothing to connect" should produce a valid **empty** result, not an untouched out-parameter.

**Validation** (AddressSanitizer, extending the #0001 override-link technique, see the patch's own commit message for the full command sequence): an ASan-instrumented macOS-arm64 build (`ModelingAlgorithms`+`ModelingData`+`FoundationClasses`, `RelWithDebInfo`, `MMGT_OPT=0` at runtime) crashes 100% of the time on two disjoint planar faces in one compound, same function, same `NCollection_Sequence::Append` call, same `0xfffffffffffffff8` fault address at both `-O2` and `-O0`, and returns the correct `2 closed, 0 open` after the patch. On the real 150-face fixture from #310: `tol=0.05` gives `152 closed/0 open` byte-identical before and after (no behavior change on the working path); `tol=0.10` crashes on stock p1 and returns `144 closed/0 open` after.

Reported and isolated at SecondMouseAU/OCCTSwift#310; a repro-only report was filed upstream as [Open-Cascade-SAS/OCCT#1376](https://github.com/Open-Cascade-SAS/OCCT/issues/1376) before the root cause was pinned down, followed up with the fix as [OCCT#1377](https://github.com/Open-Cascade-SAS/OCCT/pull/1377).

**Retire** once the bundled OCCT includes this fix.

## 0005-ShapeFix_Face-guard-null-context-FixPeriodicDegenerated-317.patch

**RETIRED 2026-08-03. The `.patch` file is deleted.** Shipped upstream in OCCT `V8_0_1` as [OCCT#1380](https://github.com/Open-Cascade-SAS/OCCT/pull/1380); the pin moved from `V8_0_0_p1` to `V8_0_1` in the same change.

**Equivalence check.** Identical: the same `if (!Context().IsNull())` guard around the same `Replace()`, differing only by our `// #317:` comment line.


**Fixes the upstream OCCT crash behind [#317](https://github.com/SecondMouseAU/OCCTSwift/issues/317)**: `ShapeFix_Face::Perform` SIGSEGVs healing a face whose sole boundary wire is a single closed edge belting the full period of a `Geom_ConicalSurface` (the shape produced by fitting a rivet/boss-rim seam as one periodic curve, `Wire.wireFromEdges` itself was the original suspect, per the issue's title, until a real in-process backtrace pinpointed the actual site).

`ShapeFix_Face::FixPeriodicDegenerated()` (added to patch in a degenerate apex edge for exactly this "lone wire belts a cone" case) builds the apex edge/wire, assembles a new face, and finalizes:

```cpp
myResult = aNewFace;
Context()->Replace(myFace, myResult);
```

Every *other* `Context()->Replace` call site in this same file, eleven of them, guards against a null `Context()` first (either a plain `if (!Context().IsNull())`, or a lazy `SetContext(new ShapeBuild_ReShape)` when null). `FixPeriodicDegenerated` even checks `Context().IsNull()` at the *top* of the function before calling `Context()->Apply()`, but the check is missing at the *bottom*. `Context()` returns `ShapeFix_Root::myContext`, which the base constructor leaves null; it's only set by an explicit `SetContext()` call, which the ordinary, most common usage (`ShapeFix_Face fixer(face); fixer.Perform();`, including our own bridge, before this patch) never makes. Any caller healing a lone periodic-conical wire without a context null-derefs.

**Fix:** the same guard used at every other call site in the file, only replace in the context if there is one.

**Validation** (fast path, no full rebuild, see the `#0001` entry above for the override-link technique): a synthetic single closed edge (`GeomAPI_Interpolate`, `closed=true`, 10 real points from a rivet rim on `railsim_581_lead.stl`) trimmed to a `Geom_ConicalSurface` via `BRepBuilderAPI_MakeFace(surf, wire, true)`, then healed with a bare `ShapeFix_Face fixer(face); fixer.Perform();`, SIGSEGVs 100% of the time on stock `V8_0_0_p1`. Diagnosed with a custom `backtrace_symbols_fd` `SIGSEGV` handler (`lldb`/core dumps unavailable in the diagnosing sandbox, see the `feedback-lldb-blocked-use-signal-handler` note): the backtrace pins the crash to `ShapeFix_Face::FixPeriodicDegenerated`; `-O0` single-TU override-link tracing confirms every prior statement in the function completes and the crash is specifically the unguarded `Context()->Replace` call. After the patch the same input returns `IsDone()==true` and a valid healed face. Also applied as a defensive `fixer.SetContext(new ShapeBuild_ReShape)` in the three OCCTSwift bridge call sites that construct a bare `ShapeFix_Face` (`OCCTShapeCreateFaceFromSurfaceWire[WithHoles]`, `OCCTFaceFixerCreate`), so the crash is closed immediately without waiting on an xcframework rebuild.

Reported and isolated at SecondMouseAU/OCCTSwift#317; filed upstream as [Open-Cascade-SAS/OCCT#1378](https://github.com/Open-Cascade-SAS/OCCT/issues/1378), fix as [OCCT#1380](https://github.com/Open-Cascade-SAS/OCCT/pull/1380).

**Retire** once the bundled OCCT includes this fix.

## 0006-BRepGProp_EdgeTool-use-adaptor-NbPoles-curve-on-surface-318.patch

**RETIRED 2026-08-03. The `.patch` file is deleted.** Shipped upstream in OCCT `V8_0_1` as [OCCT#1382](https://github.com/Open-Cascade-SAS/OCCT/pull/1382); the pin moved from `V8_0_0_p1` to `V8_0_1` in the same change.

**Equivalence check.** Identical: the carried patch reverse-applies cleanly against `V8_0_1`.


**Fixes the upstream OCCT crash behind [#318](https://github.com/SecondMouseAU/OCCTSwift/issues/318)**: `BRepGProp::LinearProperties` (backing `Shape.analyze(tolerance:)`'s small-edge scan, and anything else built on `BRepGProp_Cinert`) SIGSEGVs computing the integration order for an edge whose sole geometry is a Bezier/BSpline-type curve-on-surface pcurve (no 3D curve), the common case for a degenerate edge `BRepBuilderAPI_Sewing` produces reconciling near-coincident vertices between two faces that don't share an edge outright.

`BRepGProp_EdgeTool::IntegrationOrder` branches on `BAC.GetType()` (a `BRepAdaptor_Curve`), which correctly reports the curve-on-surface pcurve's type via `GeomAdaptor_TransformedCurve::GetType()`'s override (`myConSurf.IsNull() ? myCurve.GetType() : myConSurf->GetType()`), but then reads the pole count via a completely different, non-virtual path: `BAC.Curve().Curve()`, down-cast to `Geom_BezierCurve`/`Geom_BSplineCurve`. `BAC.Curve()` returns the base `GeomAdaptor_Curve` sub-object (`myCurve`), which holds the 3D-curve representation only, it is never `Load()`ed when the edge has no 3D curve (only `myConSurf` gets set), so the handle is null, the down-cast returns null, and `->NbPoles()` dereferences it.

**Fix:** `GeomAdaptor_TransformedCurve` already has a correctly-dispatching `NbPoles()` override right next to `GetType()` in the same header (`myConSurf.IsNull() ? myCurve.NbPoles() : myConSurf->NbPoles()`). Calling `BAC.NbPoles()` instead of manually re-deriving the pole count fixes the crash and matches the accessor `GetType()` already uses one line above it, no cast, no null check needed, no behaviour change for an edge that does have a 3D curve.

**Validation:** sewing two real mesh-derived planar candidate faces from OCCTReconstruct's plane-select spike (`kof_ii_engine_cover.stl`, regions 10 + 64) with `BRepBuilderAPI_Sewing` produces a compound containing a degenerate edge whose only representation is a BSpline-type pcurve; running `BRepGProp::LinearProperties(edge, props)` on it (the same call `Shape.analyze(tolerance:)` makes per edge) SIGSEGVs 100% of the time on stock p1, diagnosed with a custom `SIGSEGV` handler (`lldb`/core dumps unavailable in the diagnosing sandbox), backtrace pins the crash to `BRepGProp_EdgeTool::IntegrationOrder`. A from-scratch synthetic degenerate edge (`BRep_Builder` + a hand-built `Geom2d_BSplineCurve` pcurve on a plane, no 3D curve) reproduces the identical crash trace, confirming the mechanism doesn't depend on the specific fixture. After the patch both the real fixture and the synthetic edge complete and return a sane length. Also applied as a defensive guard in the bridge (`OCCTShapeAnalyze`'s small-edge scan skips degenerate edges outright, a degenerate edge's zero 3D extent isn't a "small edge" defect to flag, and this closes the crash immediately without waiting on an xcframework rebuild).

Reported and isolated at SecondMouseAU/OCCTSwift#318; filed upstream as [Open-Cascade-SAS/OCCT#1381](https://github.com/Open-Cascade-SAS/OCCT/issues/1381), fix as [OCCT#1382](https://github.com/Open-Cascade-SAS/OCCT/pull/1382).

**Retire** once the bundled OCCT includes this fix.

## 0007-ShapeAnalysis_FreeBounds-reset-lwire-skipped-loop-323.patch

**RETIRED 2026-08-03. The `.patch` file is deleted.** Shipped upstream in OCCT `V8_0_1` as [OCCT#1331](https://github.com/Open-Cascade-SAS/OCCT/pull/1331); the pin moved from `V8_0_0_p1` to `V8_0_1` in the same change.

**Equivalence check.** Identical: the carried patch reverse-applies cleanly against `V8_0_1`.


**Backports** [Open-Cascade-SAS/OCCT#1331](https://github.com/Open-Cascade-SAS/OCCT/pull/1331) (open, third-party author, pinned to commit `7557161a3dbe7e1ba18a3e63e1e104830d8c24c5`), fixing [OCCT#1330](https://github.com/Open-Cascade-SAS/OCCT/issues/1330). Audited and queued in [#323](https://github.com/SecondMouseAU/OCCTSwift/issues/323) alongside `0008`/`0009`; unlike `0001`–`0006`, this batch wasn't discovered via an OCCTSwift crash report, it's a proactive audit of upstream OCCT PRs filed since our `V8_0_0_p1` baseline that fix crashes/hangs in code paths we exercise.

`ShapeAnalysis_FreeBounds::connectWiresToWiresImpl`: the same static helper patch `0004` already touches for a different bug (#310), has a "find the next unconsumed wire" loop that sets `lwire = i` **before** checking whether the candidate wire it just loaded actually has any edges:

```cpp
lwire = i;
sewd->Add(TopoDS::Wire(arrwires->Value(lwire)));
aSel.LoadList(lwire);
if (sewd->NbEdges() > 0) { break; }
sewd->Clear();
```

If the wire is skipped (zero edges, e.g. a "wire" wrapping a single **internal-orientation** edge, which contributes no real boundary edges), `lwire` is left stale instead of reset. If every remaining candidate is likewise skipped, the loop exits with `lwire` still holding that stale index rather than `-1`, so the caller's `if (lwire == -1) { done = true; }` never fires, the outer loop's next iteration reads invalid memory through the stale `sewd`.

**Fix:** only assign `lwire = i` once the wire is actually accepted (`sewd->NbEdges() > 0`), matching upstream's exact reordering.

**Validation** (fast path, no full rebuild, see the `#0001` entry above for the override-link technique): the upstream TCL test (`tests/bugs/heal/bug1330`) translated to C++, a valid closed triangle wire plus a single internal-orientation edge, fed to `ShapeAnalysis_FreeBounds::ConnectEdgesToWires`, SIGSEGVs 100% of the time on stock p1 + patches `0001`–`0006` (`ShapeExtend_WireData::Edge` reading invalid data) and returns a valid 1-wire result after this patch.

Reported upstream as [OCCT#1330](https://github.com/Open-Cascade-SAS/OCCT/issues/1330) / [OCCT#1331](https://github.com/Open-Cascade-SAS/OCCT/pull/1331) (third party, open, pin to the SHA above and re-verify if it changes in review).

**Retire** once the bundled OCCT includes this fix.

## 0008-Geom_BSplineCurve-O1-PeriodicNormalization-323.patch

**RETIRED 2026-08-03. The `.patch` file is deleted.** Shipped upstream in OCCT `V8_0_1` as [OCCT#1329](https://github.com/Open-Cascade-SAS/OCCT/pull/1329); the pin moved from `V8_0_0_p1` to `V8_0_1` in the same change.

**Equivalence check.** Identical: the carried patch reverse-applies cleanly against `V8_0_1`.


**Backports** [Open-Cascade-SAS/OCCT#1329](https://github.com/Open-Cascade-SAS/OCCT/pull/1329) (merged 2026-07-05, upstream commit `37c9279f446894c5d123cb1fdda0ac848959361f`), fixing [OCCT#1288](https://github.com/Open-Cascade-SAS/OCCT/issues/1288) ("Boolean operation 'section' hangs-up for a pair of cylindrical shapes"). Audited and queued in [#323](https://github.com/SecondMouseAU/OCCTSwift/issues/323).

`Geom_BSplineCurve::PeriodicNormalization` brought an out-of-range parameter back into a periodic curve's valid range by repeatedly adding/subtracting one period at a time in a `while` loop. O(N) in the distance from the valid range, and a genuine infinite loop once the parameter's magnitude is many orders larger than the period: `Parameter -= Period` becomes a floating-point no-op at that magnitude, so the loop never terminates. `BRepAlgoAPI_Section` hung indefinitely reaching this path on cylindrical shapes with self-intersecting geometry.

**Fix:** rewritten to O(1), one division (`std::floor`) computes the whole number of periods to shift, applied in a single step, with at most one single-period correction for floating-point residual overshoot (using `std::nextafter` to guarantee forward progress if the correction is itself a no-op). An early return when the parameter is already in range skips even that division in the common case.

**Validation** (fast path, no full rebuild): a normal closed periodic curve (`GeomAPI_Interpolate`, 8 points on a unit circle, period ≈ 6.12) with `PeriodicNormalization(1e17)` hangs indefinitely on stock p1 (confirmed by wall-clock timeout) and returns instantly with a valid in-range parameter (`1.0364`) after the patch. A sanity sweep of nine in-range/near-boundary/several-periods-off parameters produces **byte-identical** output before and after, no behavior change for values this function is normally called with.

Filed upstream by OCCT as [OCCT#1329](https://github.com/Open-Cascade-SAS/OCCT/pull/1329) (merged, stable).

**Retire** once the bundled OCCT moves past commit `37c9279f446894c5d123cb1fdda0ac848959361f`.

## 0009-StepData_StepWriter-split-oversized-string-323.patch

**RETIRED 2026-08-03. The `.patch` file is deleted.** Shipped upstream in OCCT `V8_0_1` as [OCCT#1318](https://github.com/Open-Cascade-SAS/OCCT/pull/1318); the pin moved from `V8_0_0_p1` to `V8_0_1` in the same change.

**Equivalence check.** Identical: the carried patch reverse-applies cleanly against `V8_0_1`.


**Backports** [Open-Cascade-SAS/OCCT#1318](https://github.com/Open-Cascade-SAS/OCCT/pull/1318) (open, by an OCCT maintainer, pinned to commit `72bc2368372d93d6f84717f2327131d4c000d7c1`). No linked upstream issue. Audited and queued in [#323](https://github.com/SecondMouseAU/OCCTSwift/issues/323). Same subsystem as `0002`.

`StepData_StepWriter::AddString` writes a raw token into the writer's current-line buffer (fixed at 72 characters, `StepLong`), flushing and resetting the line whenever the pending text won't fit, assuming the token itself is never longer than one full line. When a single unbroken string value (e.g. a long name/label field with no natural break point) is longer than 72 characters, the flush-check can never become true no matter how many times the line is reset: the loop runs forever.

**Fix:** when the token fits within `StepLong`, behavior is unchanged. When it doesn't, the new code splits the token across as many lines as needed, filling each with as much as fits before flushing and continuing with the remainder, continuation lines also drop their indentation when the indented prefix would leave no room for the pending text.

**Validation** (fast path, no full rebuild): `StepData_StepWriter::StartEntity` + `SendString` (the public entry point, `AddString` itself is private) with a 200-character unbroken string hangs indefinitely on stock p1 (confirmed by wall-clock timeout) and returns instantly after the patch, correctly split across three continuation lines with the original text intact end-to-end. A sanity check with only normal-length fields produces **byte-identical** `Print()` output before and after. New OCCTSwift-level regression test `STEPWriterOversizedNameTests` (`OCCTIOTests`) exercises the same path through `Shape.writeSTEP(to:name:)`.

**Retire** once the bundled OCCT includes this fix (open PR, pin to the SHA above and re-verify if it changes in review).

## 0013-ShapeUpgrade_UnifySameDomain-guard-null-pcurve-348.patch

**RETIRED 2026-08-03. The `.patch` file is deleted.** Shipped upstream in OCCT `V8_0_1` as [OCCT#1392](https://github.com/Open-Cascade-SAS/OCCT/pull/1392); the pin moved from `V8_0_0_p1` to `V8_0_1` in the same change.

**Equivalence check.** Identical: all five guards are present verbatim, our comment strings included. Upstream then went further in the same file; see the carried-forward note below.

**Carried forward into 8.0.1 triage.** `V8_0_1` added null-pcurve guards beyond these five, in
`getCurveParams`, `FindClosestPoints` and `TransformPCurves`, and changed
`RelocatePCurvesToNewUorigin` from `void` to `bool` so a relocation that cannot be done is now
declined and its partial result discarded rather than carried on with. That is a behaviour change
to `UnifySameDomainBuilder.build()`, not just a crash guard; it is measured in the 8.0.1 absorb.


**Fixes the upstream OCCT crash behind [#348](https://github.com/SecondMouseAU/OCCTSwift/issues/348)**: an uncatchable SIGSEGV in `UnifySameDomainBuilder.build()` on a real mesh-sewn solid, minimized to a standalone OCCTSwift-only reproducer (no mesh handling, no OCCTReconstruct code involved).

`ShapeUpgrade_UnifySameDomain::IntUnifyFaces` (and its file-local `SplitWire` helper) disambiguate between multiple candidate next-edges at a branching vertex by comparing each candidate's pcurve tangent direction on the current reference face. Three call sites in `IntUnifyFaces` (`ShapeUpgrade_UnifySameDomain.cxx:3989`, `:4003`, `:4027`) and a structurally identical pair in `SplitWire` (`:4643`, `:4659`) fetch that pcurve via `BRep_Tool::CurveOnSurface(edge, refFace, first, last)` and dereference it immediately (`->D1(...)`/`->Value(...)`) with no `IsNull()` check, unlike every other `CurveOnSurface` call site in the same file (e.g. `:426`, `:1838`), which do check. `CurveOnSurface` legitimately returns a null handle when an edge has no pcurve on the given face, routine for a raw per-triangle mesh-sewn solid (`BRepBuilderAPI_Sewing` output from an STL/mesh import) at a vertex shared by more than two edges. The dereference is a null-pointer virtual call: Address 0, uncatchable in-process (same signature as the #263/#310/#317/#318 crash family).

Confirmed via a debug (`-g -O0`) single-TU override-link (compile the patched `.cxx` standalone and link it *before* `libOCCT-macos.a`, so the linker never pulls the stock archive member for these symbols) + `lldb bt`: the crash resolves precisely to `ShapeUpgrade_UnifySameDomain.cxx:4003` (`aPCurve->D1(...)`), reached via `IntUnifyFaces` → `UnifyFaces` → `Build`.

**Fix:** guard all five call sites with `IsNull()` checks, following the file's own established pattern. A missing pcurve on a *candidate* edge means "skip it, not a rankable direction" (`continue`); a missing pcurve on the *current* edge (nothing to compare candidates against) falls back to treating all candidates as equally likely, the same fallback the surrounding code already takes for the "only one candidate" case (`TmpElist.Extent() <= 1`/`aElist.Extent() == 1`).

**Validation:** the attached fixture SIGSEGVs 3/3 on stock p1 + patches 0001-0012 (v1.15.7) and survives repeated runs (3+) with the patch applied.

See [`Scripts/repro/348-unify-null-pcurve/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/348-unify-null-pcurve) for the reproducer and full writeup. Filed upstream as [Open-Cascade-SAS/OCCT#1391](https://github.com/Open-Cascade-SAS/OCCT/issues/1391) (repro) / [OCCT#1392](https://github.com/Open-Cascade-SAS/OCCT/pull/1392) (fix).

**Retire** once the bundled OCCT includes this fix.

## 0032-TopOpeBRepBuild-KPart-merge-globals-thread-local-1371.patch

**RETIRED 2026-09-02. The `.patch` file is deleted.** Not because our pinned kernel carries the
fix — it doesn't, and won't from this patch. Retired because two things are true together: the
twelve globals this patch touched are still confirmed unreachable from this bridge's own call
surface (the #1155/#1371 reachability probe this entry's own writeup describes below), so carrying
an unshipped, untested fix for them buys nothing live; and OCCT's own upstream `master` now fixes
the same defect through a structurally better mechanism than this patch ever offered. **Not an
equivalence check** in the sense the other retirements above run (this was never shipped in any
pinned asset to diff against), just a measured statement that upstream's fix supersedes ours.

**What supersedes it.** [OCCT#1505](https://github.com/Open-Cascade-SAS/OCCT/pull/1505) (merged
2026-08-25) and [OCCT#1509](https://github.com/Open-Cascade-SAS/OCCT/pull/1509) (merged 2026-08-28),
both by maintainer dpasukhi, part of a numbered "Coding - Eliminate mutable static state" cleanup
series, convert `TopOpeBRepBuild_ffsfs.cxx`/`GridSS.cxx`/`GridFF.cxx`'s `GLOBAL_*`/`stabuild_*`/
`static_CONF*` statics — the same ones this patch made `thread_local` — into per-instance member
fields on `TopOpeBRepBuild_Builder` instead. That is a better fix, not just a different one: it
removes the shared mutable state entirely rather than giving each thread its own copy of it, which
is strictly stronger (no possibility of a thread silently reusing another thread's stale value
across an `Perform`/`GMergeSolids` call sequence, a failure mode `thread_local` alone doesn't rule
out). #1509 also reaches further than this patch did: it fixes `GLOBAL_faces2d`
(`TopOpeBRepBuild_GridFF.cxx`), which this patch's own writeup above explicitly left
un-investigated as a wider-reaching sibling of the same shape.

**Lesson for how this project contributes fixes going forward**, not just for this one patch:
check `gh pr list --repo Open-Cascade-SAS/OCCT --search "author:dpasukhi"` (or equivalent) for
recent upstream activity in the same class/subsystem *before* starting a new investigation in the
caching/mutable-global-state space, not after landing a patch. Doing that here would have shown
#1505 four days before this patch was even carried, or at minimum before it was pointed at as a
"contribute" candidate. See CLAUDE.md's "Carrying OCCT source patches" section for where this is
now a standing step.

Original writeup, kept as history (the investigation and reachability proof below are unaffected by
the retirement; only the "carry/upstream this patch" conclusion is superseded):

**Fixes the upstream OCCT thread-safety defect filed as
[#1371](https://github.com/SecondMouseAU/OCCTSwift/issues/1371)**, the one near-miss the #1155
survey ([`Scripts/repro/1155-thread-safety-survey/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/1155-thread-safety-survey))
turned up: twelve unsynchronized file-scope statics in the legacy `TopOpeBRepBuild_Builder` engine
`BRepFilletAPI_MakeFillet`/`MakeChamfer` drive through `ChFi3d_Builder` → `TopOpeBRepBuild_HBuilder`.

`TopOpeBRepBuild_ffsfs.cxx` and `TopOpeBRepBuild_GridSS.cxx` (plus `TopOpeBRepBuild_GridFF.cxx`,
which turned out to hold `GLOBAL_classifysplitedge`'s one true definition, a file the issue's own
scope didn't name) pass state between `TopOpeBRepBuild_Builder::GFillFaceSFS` and its callers
(`GFillShellSFS`, `GFillSolidSFS`/`GFillSolidsSFS`, `GMergeSolids`) through: `GLOBAL_classifysplitedge`,
`GLOBAL_revownsplfacori`, `GLOBAL_SplitAnc`, `GLOBAL_lfr1`, `GLOBAL_lfrtoprocess` (extern-linked
across the three files), and `static_CONF1`/`static_CONF2`, `stabuild_IMELF1`/`IMELF2`,
`stabuild_IDMEALF1`/`IDMEALF2`, `stabuild_IMEF` (file-local to `GridSS.cxx`), twelve in total (the
issue's own tally said eleven, undercounting `stabuild_IMEF`; corrected here, not inherited). Same
shape as `0003`'s retired `STATIC_SOLIDINDEX`/`STATIC_Gmotherope`/`STATIC_motheropedef` fix in the
same toolkit (file-scope statics carrying state between methods within one logical operation, zero
synchronization), a different pair of globals that fix did not reach.

**Confirmed unreachable today, filed and fixed anyway.** The #1155 survey proved, by two independent
methods (a static call-graph read: `TopOpeBRepBuild_HBuilder::Perform(HDS)`, the only overload
`ChFi3d_Builder.cxx` calls, never computes `myIsKPart`, which only the unused two-argument
`Perform(HDS, S1, S2)` does; and an empirical `fprintf`-probe override-link driven through
`BRepFilletAPI_MakeFillet`/`MakeChamfer` on five SameDomain-merge-prone geometries, zero hits) that
this bridge's own call surface never reaches `MergeKPart`/`GMergeSolids`/the `GFill*SFS` family, so
nothing races on these twelve today. Fixed ahead of the reachability anyway, on this project's own
established precedent for exactly this shape (#298/#341/#344/#349/#353/#374/#1154/#1153): a live,
unsynchronized file-scope static is a defect the day something starts driving the two-argument
`Perform`/two-solid path, not the day someone notices.

**Fix (retired, no longer carried):** all twelve converted to `thread_local`, the same idiom `0003`/
`checkcurve` (`ChFi3d_Builder_6.cxx`) already established in this toolkit. The five extern-linked
globals need `thread_local` on both their one true definition *and* every `extern` declaration
referencing them, not just the definition, since C++ requires storage duration to agree across every
declaration of the same variable; verified directly rather than assumed, by `nm -C` on the linked
archive, which shows a genuine TLV (thread-local variable) wrapper routine generated for each of the
five, not a plain data symbol. No public API change, no signature change to any function in any of
the three files.

**Verification, and its real limit.** All three files compiled and linked cleanly across all three
xcframework slices (macOS, iOS device, iOS simulator) via the by-hand incremental `TKBool` rebuild.
A genuine functional (swift test / TSan) run against a freshly-rebuilt local kernel was attempted
and abandoned: that session's `Libraries/occt-build-macos` incremental build tree had drifted into
the exact failure this repo's own `Scripts/patches/README.md` header already documents ("Existing
build trees pin a stale macOS SDK sysroot and can no longer incrementally compile"), producing a
binary that SIGBUS-crashes on an unrelated, unmodified test (`Issue298FilletThreadSafetyTests`)
identically whether this patch is applied or reverted, proven by A/B rebuilding both ways and
confirming the crash is unchanged; the crash does not reproduce against the pinned *release* kernel
(fetched fresh via SwiftPM, no local override) at all. That isolates the crash to that session's
stale local build tree, not to this patch, but it also means the patch's functional correctness
rested on the same reachability probe/TSan evidence #1371 already gathered for the unpatched code
(showing 0 races because the code is unreached) rather than on a fresh green run against the patched
binary.

**Not fixed by this patch (now fixed upstream instead, see the retirement note above):**
`GLOBAL_faces2d`, declared two lines above `GLOBAL_classifysplitedge` in
`TopOpeBRepBuild_GridFF.cxx` with the identical unsynchronized-file-scope-static shape, but a wider
reach (also read/written from `TopOpeBRepBuild_GridEE.cxx`, `TopOpeBRepBuild_on.cxx` and
`TopOpeBRepBuild_Builder1_1.cxx`). #1509 fixes this one too.

See [`Scripts/repro/1155-thread-safety-survey/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/1155-thread-safety-survey)
for the survey. #1371.
