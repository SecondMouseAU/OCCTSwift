# Carried OCCT source patches

Patches in this directory are upstream-bound OCCT bug fixes we carry until they ship in an OCCT
release. `Scripts/build-occt.sh` applies each one (idempotently, `-p1`, `a/`,`b/` prefixes) to
`Libraries/occt-src` before every cmake build. A patch takes effect only when the xcframework is
**rebuilt** from source — the binary shipped in `Libraries/OCCT.xcframework` does not yet include it
until a rebuild + release. See ["Shipping a rebuild"](../../docs/guides/building-occt.md#shipping-a-rebuild)
for what that takes.

**Numbers are never reused.** Re-pinning to OCCT `V8_0_1` on 2026-08-03 retired ten patches, so the
carried sequence now reads 0010–0012, 0014–0021. The gaps are the retirements, not missing files:
the numbers are cited across `CLAUDE.md`, `docs/`, closed issues and `Scripts/repro/`, and
renumbering would have silently repointed every one of those citations at a different fix.
[Retired patches](#retired-patches) below keeps each one's writeup, with the equivalence check that
justified deleting the file.

## 0010-Intf_Interference-O1-tangent-zone-checkpoint-breaker-319.patch

**Fixes the upstream OCCT hang behind [#319](https://github.com/SecondMouseAU/OCCTSwift/issues/319)** — `isSelfIntersecting`'s `hardTimeout:` bound could not actually interrupt the self-interference search on a pathological artifact, running 619s+ of CPU (and observed to run far longer, uninterrupted) against a 30s deadline. Reported upstream as [Open-Cascade-SAS/OCCT#1385](https://github.com/Open-Cascade-SAS/OCCT/issues/1385) (reproducer at
[`Scripts/repro/319-selfintersection`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/319-selfintersection)), fix as [OCCT#1386](https://github.com/Open-Cascade-SAS/OCCT/pull/1386) (CI green on all 3 platforms, ready for review).

Two independent, compounding defects in `BOPAlgo_ArgumentAnalyzer`'s self-interference phase (`BOPAlgo_CheckerSI::CheckFaceSelfIntersection` → `IntTools_FaceFace::Perform` → `Intf_Interference::Insert`):

1. **O(n)-per-call point access.** `Intf_Interference::Insert` compares points between the new tangent zone and every existing zone via `Intf_TangentZone::GetPoint(Index)`, called inside a doubly-nested loop. `GetPoint` indexes the zone's backing `NCollection_Sequence` — a linked list with no O(1) random access — so each call walks from the nearest end. Profiling the pathological artifact (both independently and cross-checked against a second session's report) attributed ~80% of leaf samples to `NCollection_BaseSequence::Find`. The artifact's geometry produces an unboundedly growing *number* of distinct tangent zones, not one giant merging zone, so this alone is an O(1)-per-lookup fix to an inherently expensive matching structure — it helps, but does not bound wall-clock time.
2. **No checkpoint below `CheckFaceSelfIntersection`.** The self-interference phase never polled its cooperative progress indicator (OCCT's usual `Message_ProgressRange`/`UserBreak()` idiom) anywhere inside a single face's check — only *between* whole-face checks. A caller's timeout could therefore only fire in the gaps between faces, not while stuck inside one, which is exactly where the artifact spends its time.

**Fix:** (1) `Intf_TangentZone::Points()` builds and caches a true `NCollection_Array1` per zone in one linear pass on first use, invalidated by any mutation (`Append`/`InsertAfter`/`InsertBefore`); `Insert()` now indexes through the cached array instead of calling `GetPoint` in the nested loop — same comparisons, same result, O(1) lookup. (2) `Intf_Interference::SetBreaker` (a thread-local, RAII-scoped via `Intf_InterferenceBreakerScope`) lets `Insert()` poll a `Message_ProgressScope` every 256 calls (not every call, to avoid taxing the common case) and abort by throwing `Standard_Failure`, unwinding the deep `IntTools_FaceFace`/`Intf_Interference` call stack safely. `BOPAlgo_CheckerSI`'s self-intersect functor wires this up around `IntTools_FaceFace::Perform`, gated on `!myRunParallel` — an exception thrown from a worker thread of `OSD_Parallel::For`'s parallel path would be unsafe (risks `std::terminate()`), so the checkpoint is only active on the single-threaded path.

**Validation:** verified on the linked artifact — with both fixes, a 0.5s deadline returns in 0.547s and a 30s deadline returns in 30.1s (vs. 619s+ CPU / never returning on stock p1), with correct `HasFaulty()` results at every deadline tested (0.5s/1s/2s/3s/5s/30s), clean across a 10x repeated-run stress test. Zero regression on clean, overlapping, and grid self-intersection sanity cases (byte-identical `HasFaulty()`/point output). An empty-zone edge case (`Intf_TangentZone::Points()` on a zone with zero points) is guarded explicitly — `NCollection_Array1::Resize(1, 0, false)` throws `Standard_RangeError` for an empty range, caught by a dedicated GTest before it could reach a real caller. New upstream GTests `Intf_TangentZone_Test.cxx` (`Points()` correctness and cache invalidation, including the empty-zone case) and `Intf_Interference_Test.cxx` (breaker aborts `Insert()` promptly; a non-tripping or absent breaker leaves behavior unchanged) pass on Linux/Windows/macOS in OCCT's own CI, alongside the full regression/GTest/build matrix — all green on the first PR submission.

**Retire** once the bundled OCCT includes this fix.

## 0011-XCAFDoc_ShapeTool-AutoNamingScope-341.patch

**Fixes the upstream OCCT thread-safety defect behind [#341](https://github.com/SecondMouseAU/OCCTSwift/issues/341)** — concurrent OBJ/glTF import or PLY/OBJ/glTF export races on `XCAFDoc_ShapeTool`'s global auto-naming mode.

`XCAFDoc_ShapeTool::theAutoNaming` is a file-scope `static bool` — a single process-wide setting, by design (the header says so explicitly: "This setting is global; it cannot be made a member function"). Three independent call sites do the same unsynchronized save/modify/restore dance around it: `RWMesh_CafReader::fillDocument()` (shared base of `RWObj_CafReader` and `RWGltf_CafReader` — OBJ **and** glTF import both hit this), `RWGltf_CafReader::fillDocument()` (a *separate*, near-duplicate override — not a call into the base class's version), and `XCAFDoc_Editor::Expand()` (which additionally recurses into itself while the dance is still in flight). `XCAFDoc_ShapeTool::AddShape`/`addShape` reads the same flag internally to decide whether to auto-generate a name.

ThreadSanitizer on an 8-10 thread concurrent-OBJ-round-trip stress (each thread its own uniquely-named file, V8_0_0_p1 + patches `0001`–`0010`) reports 9-17 races per run — `SetAutoNaming`/`AutoNaming`/`addShape`'s internal read, all on `theAutoNaming` — confirming two distinct problems: (1) two threads' save/modify/restore critical sections can interleave, so one thread's restore stomps another's still-in-progress override (a *logical* bug: the wrong auto-naming mode is active for part of a build, independent of memory safety); (2) `theAutoNaming` itself is a plain `bool` read and written with no synchronization from *any* caller, including ordinary `AddShape` calls made outside any of the three save/restore call sites above — a genuine data race (undefined behavior) on every access, not just inside the three call sites.

**Fix, both layers.** `XCAFDoc_ShapeTool::AutoNamingScope` is a new RAII helper (`AutoNamingScope(bool)` constructor / destructor) that holds a `std::recursive_mutex` for its *entire* lifetime — not just around the individual get/set calls — so two threads' save-modify-restore sequences serialize against each other instead of interleaving (recursive because `XCAFDoc_Editor::Expand()` needs to reenter it on the same thread). All three call sites now use it instead of a bare `AutoNaming()`/`SetAutoNaming()` pair, collapsing `XCAFDoc_Editor::Expand()`'s two duplicate manual-restore-before-return sites into one destructor-driven restore that fires on every exit path. Separately, `theAutoNaming` itself is now `std::atomic<bool>` instead of a plain `bool`, so *every* access anywhere in the file — including `AddShape`'s internal read, which participates in none of the three scoped sections — is well-defined and TSan-clean, closing the residual gap the mutex alone doesn't reach (an unscoped `AddShape` call has no scope to be excluded by; it was never going to get a *stable* value while another thread's scope is active, since the flag is deliberately global, but it must at least get a *real*, non-torn one).

**Validation:** the same TSan stress (10 threads × 200 iterations, 2000 concurrent OBJ round-trips) reports **zero** `XCAFDoc_ShapeTool` races after the patch, across 4 separate runs — only the already-known, unrelated `Message_PrinterOStream`/`std::cout` console-write race remains (OCCT's default messenger has no internal locking; cosmetic, not fixed here). Regression-clean on the `create_fillet_boolean` (#298) and `mesh_independent` scenarios — only the already-known benign `BOPAlgo_InitMessages` lazy-init race, unchanged. `RWGltf_CafReader`'s copy of the fix could not be exercised under TSan directly (this repo's minimal-module TSan build excludes `TKDEGLTF` — it requires RapidJSON, disabled for the faster build) but compiles cleanly and is mechanically identical to the `RWMesh_CafReader`/`RWObj_CafReader` path that *was* verified.

Superseded the interim bridge-side mitigation (`meshCafMutex()` in `OCCTBridge_IO.mm`, shipped v1.15.4) — removed once this kernel patch made the underlying OCCT calls safe on their own.

Reported and isolated at SecondMouseAU/OCCTSwift#341; filed upstream as [Open-Cascade-SAS/OCCT#1387](https://github.com/Open-Cascade-SAS/OCCT/issues/1387) (repro), fix as [OCCT#1388](https://github.com/Open-Cascade-SAS/OCCT/pull/1388).

**Revised (SecondMouseAU/OCCTSwift#363), patch content above updated in place — not a new patch
number.** Upstream reviewer gkv311 caught something this writeup's own "closing the residual gap"
framing above got wrong: the mutex only serialized the three known override call sites against each
other, not the many *other* reads of `theAutoNaming` scattered through `XCAFDoc_ShapeTool.cxx`
(`AddShape`, `MakeReference`, `SetSHUO`) — those stayed outside any scope, so an unrelated unscoped
caller on another thread could still observe another thread's temporary override. The atomic
conversion made that access memory-safe; it did not make the override *behavior* correct for callers
outside the three scoped sites. The "the flag is deliberately global" framing above was itself the
mistake: `theAutoNaming` was never meant to express per-document intent — the three overriding call
sites each want to suppress naming for their own document's build, not change a process-wide
setting, and `XCAFDoc_ShapeTool` is already one instance per document. The override belongs there.

**Fixed properly this time.** `XCAFDoc_ShapeTool::OwnAutoNamingScope` replaces `AutoNamingScope`,
saving/restoring a per-instance `myOwnAutonaming` field (`-1` inherits the process-wide default,
`0`/`1` is a local override) instead of the shared flag. No locking needed at all — two threads
working on two different documents (two different `ShapeTool` instances) never touch each other's
state. `AddShape`/`MakeReference`/`SetSHUO` now read a new `OwnAutoNaming()` accessor instead of
`theAutoNaming` directly; `MakeReference` is no longer `static`, since it now reads instance state.
One subtlety a naive port of gkv311's one-line sketch would have missed: `XCAFDoc_Editor::Expand()`
recurses into itself on the same document, so a bare `SetOwnAutoNaming()`/`UnsetOwnAutoNaming()`
pair at entry/exit would clobber an outer call's still-active override mid-recursion (the inner
call's unconditional "reset to inherit global" would win). `OwnAutoNamingScope` does a proper
save/restore of whatever override state the instance had on entry, so nested scopes on the same
instance compose correctly — same reentrancy guarantee the old `recursive_mutex` gave, achieved here
by symmetric save/restore instead of a lock. `theAutoNaming` itself stays `std::atomic<bool>` —
`SetAutoNaming()`/`AutoNaming()` remain callable concurrently from any thread at any time,
independent of any instance's own override.

**Re-validated:** the same TSan stress (10 threads × 200 iterations, `obj_roundtrip_unique`) reports
zero `theAutoNaming` races, matching the prior result. New scenario
(`Scripts/repro/363-own-autonaming/occt_363_isolation.cpp`, `isolation` mode) directly checks the
property the mutex fix couldn't guarantee: half the threads locally override via
`OwnAutoNamingScope` on their own document while the other half do plain unscoped `AddShape()` on
independent documents relying on the process-wide default, concurrently — 3000 operations, zero
instances of the unscoped threads observing another thread's override.

Upstream PR #1388 updated to the new design; CI green on all 3 platforms (build/GTest/regression/
test), all originally-green checks stayed green.

**Retire** once the bundled OCCT includes this fix.

## 0012-CDF_Directory-XCAFApp_Application-thread-safety-344.patch

**Fixes the upstream OCCT crash behind [#344](https://github.com/SecondMouseAU/OCCTSwift/issues/344)** — an uncatchable SIGSEGV seen in ~1-in-10 parallel `swift test` runs right after two concurrent OBJ mesh imports, confirmed to survive the #341 kernel fix (theAutoNaming) in v1.15.5.

Two independent, previously-undetected races, both in code the #341 TSan stress never reached — that harness (`Scripts/repro/341-meshcaf/occt_341_stress.cpp`) builds its `TDocStd_Document` directly (`new TDocStd_Document("BinXCAF")`), bypassing `XCAFApp_Application`/`CDF_Application` entirely. The real bridge path (`OCCTDocumentLoadOBJ` and every other document-producing bridge call) does not: all of them go through `XCAFApp_Application::GetApplication()->NewDocument(...)`.

1. **`XCAFApp_Application::GetApplication()`** — a textbook double-checked-locking-without-locking bug: `static Handle(XCAFApp_Application) locApp; if (locApp.IsNull()) { locApp = new XCAFApp_Application; }`. Two threads' first concurrent call can both observe `IsNull()` and both construct a new instance, racing to assign the shared `locApp` handle. This is the dominant defect: TSan shows it produces **multiple concurrently constructed `XCAFApp_Application` instances**, whose "losing" copies are then torn down while other threads are still constructing/using a same-generation object — cascading into races across dozens of unrelated destructors (`TDF_LabelNode::Destroy`, `TCollection_ExtendedString::~`, `CDM_Document::~CDM_Document`, `NCollection_BaseList::PClear`, ...) and several ctor/dtor-vs-virtual-call ("vptr") reports, not just a leaked handle.
2. **`CDF_Directory::Add`/`Remove`/`Contains`** — every `XCAFApp_Application`/`CDF_Application` instance is normally shared process-wide (the entire point of `GetApplication()`), so its one `CDF_Directory` receives `Add()` from every document-creating call on every thread. `myDocuments` is a plain `NCollection_List` with zero synchronization: `NCollection_BaseList::PAppend` mutates `myFirst`/`myLast`/`myLength` with no locking at all. Confirmed independently by TSan (`CDF_Directory.cxx:30`, `NCollection_BaseList.cxx:45/52/53`) even setting aside race #1.

The bridge never calls `Application->Close()` on a document (no call site in `Sources/OCCTBridge`), so `CDF_Directory::Remove` is never reached from OCCTSwift — every document ever created via the bridge accumulates in `myDocuments` for the life of the process. That's a separate, pre-existing leak, not fixed here (out of scope for #344).

**Fix, both layers:**

1. `XCAFApp_Application::GetApplication()`: fold construction into the static local's initializer — a C++11 "magic static" is thread-safe exactly once, unlike the previous separate `IsNull()`-guarded assignment.
2. `CDF_Directory`: a private `mutable std::mutex myMutex` guards `Add`/`Remove`/`Contains`/`Length`/`IsEmpty`/`Last`. `Add()` inlines the containment scan instead of calling the public `Contains()`, to avoid a self-deadlock on the (non-recursive) mutex. `List()` — used only by the friend `CDF_DirectoryIterator`, which nothing in OCCTSwift's bridge uses — is intentionally left unguarded; closing that gap would need a bigger API change (a snapshot copy) out of proportion to the two confirmed, reachable races this patch fixes.

**Validation:** a debug (`-O0 -g`) build with a temporary `SIGSEGV`/`SIGBUS` signal handler (`backtrace_symbols_fd`, per the `feedback-lldb-blocked-use-signal-handler` technique) crashes ~50% of runs at 10 threads × 3000 barrier-synchronized rounds on stock p1, resolving to `TDocStd_Application::NewDocument -> CDF_Application::Open` both times — matching the `CDF_Directory::Add`/`PAppend` corruption mechanism. TSan (minimal-module build, same protocol as #298/#319/#341): stock p1 reports 234 races at 8 threads × 200 free-running iterations; the patch reduces this to 9, all directly in `CDF_Directory::Add`/`PAppend` and all showing the *same* mutex held on both sides of the reported conflict (`mutexes: write M0` on both the read and the write) — a pattern consistent with a TSan/allocator-recycling artifact rather than a genuine unaddressed race (a control program with a trivially-correct `std::lock_guard` pattern under the identical TSan flags reports no such warning). The entire `GetApplication()`-driven destructor cascade — dozens of unique signatures pre-fix — is gone entirely.

**Second part, found during validation.** Fixing `GetApplication()`'s race means every caller now genuinely shares ONE `TDocStd_Application` instance (as intended) — which surfaced further races on that *same* instance's other unsynchronized state, previously masked by threads sometimes getting different (uncontended) instances of their own. Repeated `swift test` runs (validating the fix above) hit two more crashes in `Tests/OCCTXCAFTests`, both resolving to state on the same shared singleton:

3. **`TDocStd_Application::Resources()`** — the identical lazy-init race pattern as `GetApplication()`: `if (myResources.IsNull()) { myResources = new Resource_Manager(...); }`, no locking.
4. **`Resource_Manager`'s own maps** (`myRefMap`/`myUserMap`/`myExtStrMap`) — no synchronization at all. Caught live: a SIGTRAP inside `Resource_Manager::SetResource`, called from `TDocStd_Application::DefineFormat` (itself called by `Document.defineAllFormats()`, a common per-test setup call many parallel XCAF tests invoke concurrently).
5. **`CDF_Application::myReaders`/`myWriters`** (format-name → driver maps) — read/written from `DefineFormat`, `ReaderFromFormat`/`WriterFromFormat`, and `ReadingFormats`/`WritingFormats` with no locking. Caught live: a SIGSEGV inside `TDocStd_Application::ReadingFormats` iterating `myReaders` while another thread's `DefineFormat` mutated it concurrently.

**Fix, continued:** a mutex guards `Resources()`'s lazy-init (same pattern as fix 1); a `std::recursive_mutex` guards `Resource_Manager`'s public accessors (recursive because `Integer()`/`Real()`/`ExtValue()` call `Value()` internally, and the `int`/`double` `SetResource()` overloads call the `char*` one) — `GetMap()`, a raw-reference escape hatch with no callers in this area, is left unguarded, same rationale as `CDF_Directory::List()`; a mutex guards `CDF_Application::myReaders`/`myWriters` across every access point. The new `Resource_Manager` mutex member makes the class non-copyable by default, breaking `ShapeProcess_Context.cxx`'s existing (pre-existing, unrelated) `new Resource_Manager(*sRC)` thread-safety workaround (its own comment: *"Creating copy of sRC for thread safety of Resource_Manager variables... calling of SetResource() for one object in multiple threads causes race condition"* — OCCT's own prior acknowledgement of this exact defect, worked around locally rather than fixed at the source) — added an explicit copy constructor that copies the maps under the source's lock and default-constructs a fresh mutex for the new instance.

**Validation, continued:** SIGTRAP (`Resource_Manager::SetResource`) and SIGSEGV (`TDocStd_Application::ReadingFormats`) both reproducible before this part of the patch; 0/12 further `swift test` runs of `OCCTXCAFTests` reproduce either after it.

A third, separate crash surfaced during this same validation (`BinLDrivers_DocumentStorageDriver::Write`/`WriteSubTree` corrupting a *shared, cached, non-reentrant storage-driver instance* under concurrent `Save`/`SaveAs` of the same format) — architecturally different (a shared worker object, not a container needing a lock) and **not fixed here**; filed separately as SecondMouseAU/OCCTSwift#349 for its own dedicated investigation.

See [`Scripts/repro/344-cdf-directory/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/344-cdf-directory) for the reproducers and full writeup. Filed upstream as [Open-Cascade-SAS/OCCT#1389](https://github.com/Open-Cascade-SAS/OCCT/issues/1389) (repro) / [OCCT#1390](https://github.com/Open-Cascade-SAS/OCCT/pull/1390) (fix, two commits).

**Retire** once the bundled OCCT includes this fix.

## 0014-CDF-driver-reentrancy-mutex-349.patch

**Fixes the upstream OCCT crash behind [#349](https://github.com/SecondMouseAU/OCCTSwift/issues/349)** — an uncatchable SIGSEGV under concurrent `Save`/`SaveAs` of the same document format, surfaced during validation of the #344 fix (the third, architecturally distinct crash found in that pass, deliberately not folded into patch 0012).

`CDF_Application::WriterFromFormat`/`ReaderFromFormat` cache one storage/retrieval driver instance per format (`myWriters`/`myReaders`, the map itself already made safe by #344) and hand the *same* cached instance back to every subsequent `Store()`/`Retrieve()` call for that format — including from different threads, different documents, concurrently. But `PCDM_StorageDriver`/`PCDM_Reader` subclasses (`BinLDrivers_DocumentStorageDriver` et al.) are not reentrant: `Write()`/`Read()` mutate instance-level scratch state — for `BinLDrivers_DocumentStorageDriver` alone: `myRelocTable`, `myTypesMap`, `myPAtt`, `myEmptyLabels`, `myMapUnsupported`, `mySizesToWrite`, `myFileName`, `myMsgDriver`, the lazily-initialized `myDrivers` table, plus the base class's `myIsError`/`myStoreStatus` — that gets clobbered when two threads call `Write()` on the same shared instance concurrently. `CDF_StoreList::Store`'s own comment already shows awareness the driver is shared across threads ("It has sense in multi-threaded access to the storage driver..."), but only the store-status was ever made safe; every other member raced freely. Structural, not BinLDrivers-specific: `XmlLDrivers`, `BinXCAFDrivers`/`XmlXCAFDrivers`, and `TObj` drivers all extend the same base classes and follow the identical per-instance-scratch-state pattern.

Confirmed via a debug (`-O0 -g`) build with a temporary SIGSEGV/SIGBUS signal handler: two threads racing `TDocStd_Application::SaveAs()` on a shared application crash reliably (within a few hundred rounds at just 2 threads), resolving to `BinMDF_ADriverTable::AssignIds(myTypesMap) <- NCollection_BaseMap::Destroy`, reached via `BinLDrivers_DocumentStorageDriver::Write -> FirstPass -> CDF_StoreList::Store -> CDF_Store::Realize -> TDocStd_Application::SaveAs` — two concurrent `Write()` calls both clearing/rebuilding `myTypesMap` out from under each other. TSan (minimal-module build, same protocol as #298/#319/#341/#344) confirms it directly: 136 distinct race warnings in one run (8 threads × 25 rounds), process itself still SIGSEGVs (exit 139) partway through — every non-unrelated report resolves into `BinLDrivers_DocumentStorageDriver::Write`/`FirstPass`/`FirstPassSubTree`/`WriteSubTree`/`WriteInfoSection`, `PCDM_StorageDriver::SetIsError`/`SetStoreStatus`, `BinMDF_ADriverTable::GetDriver`/`AssignIds`/`AddDerivedDriver`, and their `NCollection_BaseMap`/`NCollection_IndexedMap`/`NCollection_BaseList` internals — consistent with the whole per-call scratch surface racing, not just one field.

**Fix:** considered the issue's own two options — (a) a coarser mutex serializing driver dispatch, or (b) making the driver's `Write()`/`Read()` genuinely reentrant by eliminating shared scratch state. (b) was investigated and rejected as impractical here (unlike #298/#319/#341/#344, which each had one small, well-bounded piece of shared state): TSan shows essentially the *entire* driver object is scratch state for the duration of one `Write()` call, plus a nested shared object (`BinMDF_ADriverTable`) with its own internal mutation — eliminating it would mean threading new parameters through half a dozen private helpers, a sweeping signature change every format driver subclass would also need, for a change with high regression risk and far outside "minimal, surgical" for an upstream PR. Went with (a), placed on the shared resource itself rather than as one big lock around unrelated code: `PCDM_StorageDriver`/`PCDM_Reader` each get a `mutable std::mutex` + `Mutex()` accessor (every concrete format driver inherits it for free, zero subclass changes needed), held by the three places `CDF_Application`/`CDF_StoreList` actually invoke a cached, possibly-shared driver's `Write()`/`Read()`: `CDF_StoreList::Store`, `CDF_Application::Retrieve`, `CDF_Application::Read`. Doesn't serialize unrelated formats against each other — a `"BinOcaf"` save and an unrelated `"Xml"` save use different cached driver instances and different mutexes.

**Validation:** rebuilt the minimal-module TSan install with the patch applied and re-ran the same stress: race warnings 136 → **0** (confirmed again at a larger 10×200 stress), crash (SIGSEGV, exit 139) → **clean exit** across repeated runs. Full production xcframework rebuilt via `Scripts/build-occt.sh` (all 3 core slices, clean); `swift test --filter OCAFSaveLoadBinaryTests` and `swift test --filter OCCTXCAFTests` (339 tests) both clean, plus **3× full `swift test`** (4423 tests / 1282 suites each) clean, zero failures.

**New finding surfaced by this fix, not fixed here:** post-patch TSan runs consistently surface one different, previously-masked race — same "fixing one race exposes the next" pattern as #344's own history. `CDM_Application::myMetaDataLookUpTable` is a plain `NCollection_DataMap`, one instance per `CDM_Application`/`CDF_Application`, with zero synchronization; every `CDF_StoreList::Store()`/`CDF_FWOSDriver::CreateMetaData()`/`CDM_MetaData::LookUp()` call across every thread sharing that one `TDocStd_Application` reads/writes the same map and the `CDM_MetaData` objects it hands out — same failure class as `CDF_Directory::myDocuments` (#344) and `theAutoNaming` (#341). Out of scope for #349 (specifically the driver reentrancy this patch fixes); filed separately as [SecondMouseAU/OCCTSwift#353](https://github.com/SecondMouseAU/OCCTSwift/issues/353).

**Bridge mitigation:** `Sources/OCCTBridge/src/OCCTBridge_Document.mm`'s `ocafStoreMutex()` (serializing `OCCTDocumentSaveOCAF`/`OCCTDocumentSaveOCAFInPlace`/`OCCTDocumentLoadOCAF`, shipped v1.15.6) **stays** regardless of this kernel fix — same PR1→PR2 pattern as #298/#341/#344. It's coarser than necessary now, but removing it is a separate, lower-priority follow-up once this kernel fix has shipped in a released xcframework for a while.

See [`Scripts/repro/349-ocaf-driver-reentrancy/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/349-ocaf-driver-reentrancy) for the reproducer and full writeup. Filed upstream as [Open-Cascade-SAS/OCCT#1393](https://github.com/Open-Cascade-SAS/OCCT/issues/1393) (repro) / [OCCT#1394](https://github.com/Open-Cascade-SAS/OCCT/pull/1394) (fix, CI green on all platforms).

**Retire** once the bundled OCCT includes this fix.

## 0015-CDM_Application-metadata-lookup-table-mutex-353.patch

**Fixes the upstream OCCT crash behind [#353](https://github.com/SecondMouseAU/OCCTSwift/issues/353)** — a race surfaced while validating the #349 fix (patch 0014, shipped v1.15.9): post-#349-fix TSan runs consistently produced exactly one different, previously-masked warning, matching the "fixing one race exposes the next" pattern from #341→#344→#349.

`CDM_Application::myMetaDataLookUpTable` is a plain `NCollection_DataMap`, one instance per `CDM_Application` (in practice the one process-wide singleton, since #344's `GetApplication()` fix), with zero synchronization anywhere in the class. Three independent things race: (1) **map mutation** — `CDM_MetaData::LookUp()`'s unguarded `IsBound`+`Bind`/`Find`, called from `CDF_FWOSDriver::MetaData`/`CreateMetaData` (every `Store()`/`SaveAs()`), `XmlLDrivers_DocumentRetrievalDriver::Read`, and `PCDM_ReferenceIterator::MetaData`; (2) **map iteration** — `CDM_Document::SetMetaData()` walks the *entire* table on every save, reading every other document's `CDM_MetaData` state; (3) **per-object state** — each `CDM_MetaData`'s `myIsRetrieved`/`myDocument` fields, mutated by `SetDocument()`/`UnsetDocument()` and read by `IsRetrieved()`/`Document()` with no guard at all. TSan confirmed the exact trace quoted in the issue: `CDM_Document::SetMetaData()`'s map-iteration loop (reading `IsRetrieved()`, still inside #349's own per-driver lock — but that lock has no relationship to a *different* thread's document destructor) racing `~CDM_Document() -> CDM_MetaData::UnsetDocument()` tearing down an unrelated document's metadata entry on another thread. 1 confirmed race + SIGABRT (exit 134) on stock #349-fixed kernel, matching the issue's reported symptom exactly.

**Fix:** follows the established "lock the shared resource, don't restructure the subsystem" precedent (#341's atomic bool, #344's `CDF_Directory` mutex, #349's per-driver mutex) — the map's "bind once, reuse forever, share across all documents" caching design is load-bearing (how OCCT recognizes "this file is already open" across separate calls), not incidental scratch state. Two independent locks, matching the two distinct race shapes: (1) `CDM_Application` gets a `mutable std::mutex myMetaDataLookUpTableMutex` + accessor, threaded through `CDM_MetaData::LookUp()`'s two overloads (now take the mutex as an explicit parameter) and `CDM_Document::SetMetaData()`'s iteration — `CDF_FWOSDriver`'s constructor also now takes the mutex alongside the table reference it already stored; (2) `CDM_MetaData` gets its own private `mutable std::mutex myDocumentMutex` guarding `myIsRetrieved`/`myDocument`, since two already-bound `CDM_MetaData` objects can race on `SetDocument()`/`UnsetDocument()` vs. `IsRetrieved()`/`Document()` independent of the table lock. No changes to any format-specific driver subclass.

**Validation:** rebuilt the minimal-module TSan install (reused `occt-build-tsan349`/`occt-install-tsan349` from the #349 investigation, which already had patch 0014 baked in) with 0015 applied: race count 1 (+SIGABRT) → **0**, clean exit, across 5 runs (8×25, 10×60, 3×8×40). Full production xcframework rebuilt via `Scripts/build-occt.sh`; `swift test --filter OCAFSaveLoadBinaryTests`/`OCCTXCAFTests` and 3× full `swift test` (4423 tests) all clean.

**Not changed**: `CDM_MetaData::myDocumentVersion` (reached via `CDM_Reference.cxx` and `CDM_Application::SetDocumentVersion`) has the identical unguarded-mutable-field shape as the fixed `myIsRetrieved`/`myDocument`, but on the document-*reference* resolution path rather than save/close — not TSan-observed in any run (the repro doesn't exercise cross-document references), flagged as a plausible sibling for a future pass, not fixed here.

**Upstream formatting note:** OCCT's CI `clang-format` (invoked via their format-check workflow) disagreed with a locally-run `clang-format` (v22.1.8) on two spots — both formatter-alignment artifacts (`AlignConsecutiveAssignments`/declaration alignment shifting due to nearby edits), not intentional changes. Applied CI's own `format.patch` artifact to resolve; the version skew is a tooling quirk, not a real formatting defect. Worth checking CI's format-check output (not just a local dry-run) before every future upstream OCCT PR.

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

**Fixes two upstream OCCT crashes found while auditing the `ShapeFix_Face` call sites in [#484](https://github.com/SecondMouseAU/OCCTSwift/issues/484)** — the same defect class as `0005`/#317 (an unguarded null `ShapeBuild_ReShape` context dereference), in two classes that were never patched or filed.

`ShapeFix_ComposeShell::Perform()`, `ShapeFix_ComposeShell::SplitEdges()` and `ShapeUpgrade_WireDivide::Perform()` dereference `Context()` unconditionally. `Context()` returns `ShapeFix_Root::myContext`, which the base constructor leaves **null** and only an explicit `SetContext()` ever fills — so the ordinary `Init(...)` + `Perform()` pair those classes' public API invites is an immediate null-handle dereference, an uncatchable SIGSEGV at Address 0. No exotic geometry needed: a plain 4-edge planar square face crashes both classes 100% of the time.

Both are the odd ones out in their own package. `ShapeUpgrade_FaceDivide::Perform()` — the in-kernel driver of *both* classes, and the reason neither crash shows up in OCCT's own test suite — opens with exactly the guard this patch adds, then hands its context down to the compose shell (`ShapeUpgrade_FaceDivide.cxx:185`) and the wire divide (`:238`). Reached that way, neither class ever sees a null context. Reached directly, both crash. `ShapeFix_Shape::Init`, `ShapeFix_Shell::Perform`, `ShapeFix_Solid::Perform`, `ShapeFix_FixSmallFace::Init`, `ShapeFix_SplitCommonVertex::Init`, `ShapeFix_Wireframe` (both entry points), `ShapeFix_Wire::FixGap3d`/`FixGap2d`, `ShapeFix_Face::FixMissingSeam` and `ShapeUpgrade_ShapeDivide::Perform` all carry the same self-creating guard already.

**Fix:** the guard OCCT itself uses in those ten places — `if (Context().IsNull()) { SetContext(new ShapeBuild_ReShape); }` — at the three public entry points missing it. `ShapeFix_ComposeShell`'s other context-dereferencing methods (`LoadWires`, `SplitWire`, `SplitByLine`, `MakeFacesOnPatch`, `DispatchWires`) are all reached through `Perform()` or `SplitEdges()`, so guarding those two covers them; they are also `const`, so they could not create a context themselves.

**Validation** (fast path, no full rebuild — see the `#0001` entry above for the override-link technique): a 4-edge planar square face and an unbounded-cylinder face, run through both classes with no `SetContext()` call, SIGSEGV 100% of the time on stock `V8_0_0_p1` + patches `0001`–`0016` and complete normally after this patch. On the *with-context* path — the only one that worked before — the result is **byte-identical** before and after (BREP dump hash plus face/wire/edge/vertex counts compared for both surfaces and both classes), and the no-context path now produces that same result instead of crashing.

**Confirmed against the real binary** ([#512](https://github.com/SecondMouseAU/OCCTSwift/issues/512)): `Libraries/OCCT.xcframework` has since been rebuilt from source with all 17 patches, and both reproducers were re-run against it with **no** override-linked TUs: the two `ctx=NO` cases that were `KILLED BY SIGNAL 11` now complete, and all four `ctx=yes` fingerprints are identical to the values recorded pre-rebuild in the reproducer's README. Full `swift test` (4842 tests / 1346 suites) clean.

Both crashes were already closed **bridge-side**, before this patch existed: `OCCTShapeFixComposeShell` and `OCCTShapeUpgradeWireDivide` (`OCCTBridge_Healing.mm`) each call `SetContext(new ShapeBuild_ReShape())` with a comment naming the SIGSEGV. This patch fixes the kernel so those workarounds can eventually retire, and so the crash is closed for every other OCCT consumer following the documented `Init` + `Perform` usage.

See [`Scripts/repro/484-null-reshape-context/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/484-null-reshape-context) for the reproducer and full writeup. Filed upstream as [Open-Cascade-SAS/OCCT#1409](https://github.com/Open-Cascade-SAS/OCCT/issues/1409) (repro) / [OCCT#1410](https://github.com/Open-Cascade-SAS/OCCT/pull/1410) (fix), both still open with the PR unmerged as of 2026-07-30. Both defects are still present on upstream `master` (verified against `37dd5686` at filing time), and the PR branch's post-edit blobs hash identically to this patch's output, so the fix is the same on `master` as on our `V8_0_0_p1` pin.

**Retire** once the bundled OCCT includes this fix.

## 0018-GCPnts-degenerate-count-and-duplicate-end-point-555.patch

**Fixes two upstream OCCT defects in the arc-length samplers, behind [#555](https://github.com/SecondMouseAU/OCCTSwift/issues/555)**, both about the requested point count. [#501](https://github.com/SecondMouseAU/OCCTSwift/issues/501) had already closed the OCCTSwift-reachable half of the first one at the bridge layer; this is the kernel side, which every other OCCT consumer still carried.

1. **`GCPnts_UniformAbscissa::NbPoints()` can exceed the requested count.** `initialize` sizes its parameter array at `theNbPoints + 5` and the arc-length walk fills it until it reaches the end parameter or runs out of room, setting `myNbPoints` to whatever it reached. A caller that sizes its own buffer from the request rather than from `NbPoints()` overflows it. `GCPnts_QuasiUniformAbscissa` inherits this for every curve that is neither Bezier nor BSpline, since it forwards to `GCPnts_UniformAbscissa` for those, so the same class returns exactly `theNbPoints` on a Bezier and possibly more on an ellipse.

   The mechanism is a tolerance mismatch, not an off-by-one. `Perform` terminates on `std::abs(aUi - aUU2) <= theEPSILON`, where `theEPSILON` comes from `theC.Resolution(theTol)`, which converts a 3D tolerance to a parametric one using the curve's **largest** derivative. On an ellipse with major radius 1e6 and minor radius 1e-3 that is about 1e-13, while the local derivative at the end of that curve is 1e-3, making the parametric tolerance that actually corresponds to 1e-7 in 3D about 1e-4. The walk stops 1.557e-08 short, does not call that done, takes one more step and snaps it to the end. **The surplus point is a duplicate**: 1.175e-10 away from its neighbour in 3D.

2. **A point count below 2 stores out of bounds.** Both classes document `theNbPoints >= 2` and enforce it with `Standard_ConstructionError_Raise_if`, which compiles to nothing under `No_Exception`, how the shipped Release kernel is built (see `0016`'s neighbour issue #487). `GCPnts_QuasiUniformAbscissa`'s Bezier/BSpline branch then allocates `new NCollection_HArray1<double>(1, theNbPoints)`, an empty range for such a count, and the next statement is an unconditional `myParams->SetValue(1, theU1)`. `SetValue`'s own bounds check is a `Raise_if` too, so the store lands out of bounds: uncatchable SIGSEGV, same class as `0001`/#263, `0004`/#310, `0005`/#317 and `0006`/#318.

**Fix:** for the second, an ordinary `if` after each `Raise_if`, leaving the object not done for a count below 2. The `Raise_if` stays, so a build with exceptions enabled throws exactly as before; this only stops the undefined behaviour where the check is compiled out. Applied to both classes, since `GCPnts_UniformAbscissa` had the same missing precondition without the crash (it answered a request for zero points with five). For the first, `Perform` also accepts a point that coincides with the end **in 3D** within the caller's tolerance, not only one close in parameter: the 3D tolerance is threaded in alongside the parametric one, the end point is evaluated once outside the walk, and the distance test sits behind a cheap `aUU2 - aUi < aDelta` gate so it runs on the final step rather than every step. Keeping the exact end parameter is the point: clamping `myNbPoints` to the request, the other obvious fix, would drop it and leave the distribution stopping short of the curve.

No public API signature changes.

**Validation** (fast path, no full rebuild, see the `#0001` entry above for the override-link technique, but compile the two TUs with `-DNDEBUG -DNo_Exception` to match the production build, or the `Raise_if` comes back and the measurement is of a kernel nobody ships): across 17 curve types and counts 2 to 200, 6766 configurations, **232 lines change and they are exactly the 232 that were over-requesting**; every other line is byte-identical, and on the changed lines the last parameter is still exactly the end. Over-request goes to 0, and every degenerate count on every curve returns `IsDone() == false` for both classes. Confirmed against the rebuilt xcframework with no override-linked TUs, matching the override-linked prediction byte for byte. Full `swift test` (4842 tests / 1346 suites) clean.

See [`Scripts/repro/555-gcpnts-count-contract/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/555-gcpnts-count-contract) for the reproducers and full writeup. Filed upstream as [Open-Cascade-SAS/OCCT#1417](https://github.com/Open-Cascade-SAS/OCCT/pull/1417), a fix PR with no companion repro issue, per upstream's own guidance on [OCCT#1409](https://github.com/Open-Cascade-SAS/OCCT/issues/1409#issuecomment-5124395058). Based on `b8f597c6`; the two touched files are byte-identical between upstream `master` and our `V8_0_0_p1` pin, so the patch is the same change on both.

**Retire** once the bundled OCCT includes this fix.

## 0019-AdvApp2Var-jacobi-max-wrong-workspace-slot-522.patch

**Fixes the upstream OCCT defect behind [#522](https://github.com/SecondMouseAU/OCCTSwift/issues/522)**, found while building [#491](https://github.com/SecondMouseAU/OCCTSwift/issues/491)'s surface-approximation parity tests: `GeomConvert_ApproxSurface` asked for `GeomAbs_C0` returned a surface nowhere near its input while reporting `IsDone()` and a `MaxError()` five orders of magnitude too small.

`AdvApp2Var_ApproxF2var::mma2ce1_` requests one scratch allocation and partitions it into seven consecutive buffers, of which `ipt4` holds `XMAXJU` (the maxima of the U Jacobi polynomials) and `ipt5` holds `XMAXJV` (the V ones). Both `mma2jmx_` calls that fill them target `ipt5`:

```c
AdvApp2Var_ApproxF2var::mma2jmx_(ndjacu, iordru, &wrkar_off[ipt5]);   /* -> should be ipt4 */
AdvApp2Var_ApproxF2var::mma2jmx_(ndjacv, iordrv, &wrkar_off[ipt5]);
```

So `XMAXJU` is never written. `mma2ce2_` still reads it at `ipt4`, where the allocation left whatever was there — in practice zeros — and passes it to `mma2er1_`/`mma2er2_`, whose entire error model is `|PATJAC(i,j)| * XMAXJU(i - 2*(IORDRU+1)) * XMAXJV(j - 2*(IORDRV+1))`. A zero `XMAXJU` zeroes every term, with two silent consequences: (1) the interior approximation error of a patch is reported as exactly 0 whatever the discarded coefficients are, so `mma2ce2_`'s tolerance test can never fire on it and `MaxError()` only ever reflects the boundary-iso errors `AdvApp2Var_Patch::AddErrors` adds afterwards; (2) `mma2er2_`, asked for the lowest degree whose truncation error still fits the tolerance, always answers `NDMINU`, the floor derived from the constraint order and the neighbouring isos, because every candidate scores 0.

Where that floor is low the fit collapses onto it. C0 gives `IORDRU = 0`, and a full sphere's V-boundary isos degenerate to its two poles, one coefficient each, so `NDMINU` is 1: a radius-10 sphere at tolerance 1e-3 came back as a degree-1, 2-pole-in-U B-spline — a straight line across the full `2*pi` of longitude, deviating by the sphere's own diameter of 20 — reporting `MaxError()` 1.07e-4. A bicubic Bezier at C0/C0 collapsed to a 2x2 bilinear patch reporting 4.08e-15, unchanged from tolerance 1e-1 down to 1e-7, because the requested tolerance was compared against a number that was always zero. C1 and C2 hid the collapse (their floor is already high) but not the misreported error.

The write also overruns: `mma2jmx_` writes `ndjacu + 1 - 2*(IORDRU+1)` doubles and the `ipt5` slot is sized for the `ndjacv` equivalent, so a request with `MaxDegU` well above `MaxDegV` runs past `XMAXJV` into the `VECERR` slot behind it. Benign in practice — `VECERR` is re-zeroed on entry to `mma2ce2_` and the run stays inside the single allocation — but out of bounds for the buffer it was given.

**Fix:** target `ipt4` from the U call. One character; the two lines then read symmetrically. `AdvApp2Var_Context`'s own two `mma2jmx_` calls (the only others in the tree) already write to separate per-direction arrays and were correct.

**Validation** (fast path first, then the real binary — see the `#0001` entry above for the override-link technique, compiled with `-DNDEBUG -DNo_Exception` to match the production build): dumping `&wrkar_off[ipt4]` shows `xmaxju[8] = 0 0 0 0 0 0 0 0` on stock and `0.9682 0.986 1.078 1.173 1.265 1.352 1.434 1.513` after. Across a 98-case sweep (7 surface families x all 9 `(uCont, vCont)` combinations of C0/C1/C2, plus C0/C0 at five tolerances) the results whose real deviation exceeds the reported `MaxError` by more than 10x go from **12 to 0**, and those that exceed it at all from 17 to 1 — the survivor being a Bezier reproduced exactly, reporting 9.95221e-15 against a measured 9.96978e-15. Reported errors rise slightly everywhere, which is the interior contribution being counted for the first time. Confirmed against the rebuilt xcframework with no override-linked TUs, matching the override-linked prediction line for line. Full `swift test` (4842 tests / 1346 suites) clean.

`GeomConvert_ApproxSurface` is not a leaf. `GeomFill_Sweep`, `BRepOffset_Offset`, `GeomLib`, `ShapeCustom_BSplineRestriction`, `ShapeConstruct`, `ShapeUpgrade_UnifySameDomain` and `GeomConvert_1` (twice) all construct it, `ShapeCustom_ConvertToBSpline` reaches it through `ShapeConstruct`, and `GeomPlate_MakeApprox` drives `AdvApp2Var_ApproxAFunc2Var` directly. Most pass C1 or C2, where the collapse cannot happen, but the always-zero interior error affected all of them; and the healing paths reach C0 deliberately: `ShapeConstruct::ConvertSurfaceToBSpline` and `ShapeCustom_BSplineRestriction` both loop the requested continuity down to 0 on failure and then accept the result on `MaxError() <= tol`, and `ShapeCustom_ConvertToBSpline` *starts* at C0 for any offset surface (`ShapeCustom_ConvertToBSpline.cxx:148`) before handing off to the first of those. (`BRepFill_Sweep.cxx:1162` and `BRepFill_Filling.cxx:712` also name the class but are both inside comment blocks, so neither is a live caller; see #573.)

See [`Scripts/repro/522-approx-c0-collapse/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/522-approx-c0-collapse) for the reproducers and full writeup. Filed upstream as [Open-Cascade-SAS/OCCT#1418](https://github.com/Open-Cascade-SAS/OCCT/pull/1418), a fix PR with no companion repro issue, per upstream's own guidance on [OCCT#1409](https://github.com/Open-Cascade-SAS/OCCT/issues/1409#issuecomment-5124395058). Based on `b8f597c6`; the touched file is byte-identical between upstream `master` and our `V8_0_0_p1` pin, so the patch is the same change on both.

**Retire** once the bundled OCCT includes this fix.

## 0020-BRepFeat_MakeCylindricalHole-select-tool-parts-532.patch

**Fixes the upstream OCCT wrong-answer behind [#532](https://github.com/SecondMouseAU/OCCTSwift/issues/532)** — a silent one: `BRepFeat_NoError` and the input handed back with the drill's faces imprinted on it, no material removed.

The four `BRepFeat_MakeCylindricalHole` modes that choose which piece of the drilling tool to keep — `PerformThruNext`, `PerformUntilEnd`, the ranged `Perform(Radius, PFrom, PTo)` and `PerformBlind` — drive `BRepFeat_Builder` with the one-argument `SetOperation(Fuse)`, i.e. `BOPAlgo_CUT`, and then call `PartsOfTool()`. That method (`BRepFeat_Builder.cxx:107`) collects the solids of the builder's `myShape`, which holds the tool split by the object only after the **COMMON** pass; after a CUT it is the finished workpiece. So each mode's `nbparts >= 2` selection loop compares barycentres of *bored plates* and then registers those plates as "kept parts of the tool" via `KeepPart`. `PerformResult()` sees a non-empty `myShapes`, takes the kept-parts path with a keep set that contains no tool part at all, and subtracts nothing.

The kernel's other two users of the same builder already do this correctly: `BRepFeat_Form` (`BRepFeat_Form.cxx:806`) and `BRepFeat_RibSlot` (`BRepFeat_RibSlot.cxx:224`) both call the two-argument `SetOperation(myFuse, bFlag)` with `bFlag` true before `Perform()`, selecting `BOPAlgo_COMMON`. `PerformResult()` re-derives `myOperation` from `myFuse`, so the operation finally built is the CUT either way.

**Fix:** that two-argument call at the four part-selecting sites. `Perform(Radius)` — the infinite-cylinder through-all — selects no parts, never calls `PartsOfTool()`, and keeps the one-argument overload; that is why it was the one mode that already drilled a stack correctly, and why the defect reads as "multi-body" rather than "part selection".

The defect is invisible whenever the cut result happens to have one solid, which is the single-plate case every existing test used. It appears as soon as it has two — a drill axis crossing two bodies of a compound, or, with no compound involved, a single bar the bore severs in half.

**Validation:** [`Scripts/repro/532-cylindrical-hole-part-selection/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/532-cylindrical-hole-part-selection) measures every mode across six geometries, before and after. On a compound of two 50×50×20 plates on the drill axis (one bore removes 1570.7963): `PerformUntilEnd` 0.0000 → 3141.5927, ranged `Perform(R, 0, 70)` 0.0000 → 3141.5927, `PerformBlind(20)` 0.0000 → 1178.0972; three plates, `PerformUntilEnd` 0.0000 → 4712.3890; the severed single bar, `PerformUntilEnd`/`PerformThruNext`/ranged `Perform` 0.0000 → 1407.2952 each. A single plate is byte-identical before and after. A channel and a hollow box — both one solid with two spans on the axis — give the same answer before and after while the selection loop goes from one part to two real tool parts, which is the non-regression evidence that matters. The full #496 contract matrix (`Scripts/repro/496-drill-hole-contracts/`) is unchanged apart from the rows this patch fixes and the oversized-radius row below. `swift test` clean.

**One behaviour change beyond the bug.** A radius so large the bore swallows the whole workpiece used to return `BRepFeat_InvalidPlacement` from `PerformUntilEnd`/`PerformThruNext`: under CUT the oversized tool emptied `myShape`, so `nbparts` was 0 and the "the tool meets nothing" guard fired. Under COMMON the tool meets the whole workpiece, `nbparts` is 1, and those modes now return the same empty result `Perform(Radius)` and a plain `BRepAlgoAPI_Cut` against the same cylinder always returned. `nbparts == 0` now means what the guard reads as.

**A second defect in the same heuristic, not fixed here.** `PerformThruNext`'s closest-interval fallback (`BRepFeat_MakeCylindricalHole.cxx:217-242`) has a misplaced brace: the `// parbar > Last` branch is nested *inside* `if (parbar < First)`, as the `else` of the distance comparison, so the "beyond `Last`" case is unreachable as written. `PerformBlind`'s equivalent fallback (`:602-616`) compares `std::abs(First - parbar)` uniformly and has no such structure. The fallback only runs when no tool part's barycentre lies in `[First, Last]`, which none of the probed geometries reach, so it is reported rather than changed.

**Retire** once the bundled OCCT includes this fix.

## 0021-CPnts-adaptive-arc-length-integration-603.patch

**Fixes the upstream OCCT defect behind [#603](https://github.com/SecondMouseAU/OCCTSwift/issues/603)**, which OCCTSwift already works around bridge-side: `CPnts_AbscissaPoint::Length` integrates `|C'(u)|` with **one** fixed-order Gauss rule over the whole range it is handed — `order()` gives 10 to a conic, 5 to a parabola, `2 * Degree` to a Bezier, `min(24, 2 * NbPoles - 1)` to a B-spline.

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

The error is set by how much `|C'|` varies across **one** integration interval, not by the curve's type: the same 8 × 3 ellipse is 0.337% out over `[0, 2π]`, 0.0001% over `[0, π]` and exact over `[0, π/2]`. So the per-span split is not a fix either, just a mitigation that happens to work when spans are narrow — a 5-point interpolation is 100× worse than a 40-point one.

`CPnts_AbscissaPoint::Length` **called directly** is far worse than through `GCPnts`, because nothing splits at all: 3.6e-2 on the 5-point interpolation, 7.4e-2 at 40 points and **1.0e-1 at 200 points**, where the `min(24, ...)` cap means one order-24 rule covers the entire domain.

**Fix:** a new header-only `CPnts_AdaptiveIntegration.hxx` integrates over `[U1, U2]`, then over the same range split in two, four, … equal parts, until two successive levels agree to `1e-9` relative (ceiling 512 parts). All four `CPnts_AbscissaPoint::Length` overloads and `CPnts_MyRootFunction::Value`/`Values` use it.

**`CPnts_MyRootFunction` has to move with `Length`, not after it.** That class is the function `math_FunctionRoot` drives to answer "which parameter is this far along?", and its `Value(X)` is *the same integral*: one Gauss rule over `[myX0, X]` minus the target. Today both are wrong by the same amount, which is why `GCPnts_AbscissaPoint(C, GCPnts_AbscissaPoint::Length(C), first)` still lands on the last parameter and why `GCPnts_UniformAbscissa` spaces its points uniformly in *true* arc (measured: 2.9e-14 on an 8 × 3 ellipse) despite computing a total that is 0.337% wrong. Fixing `Length` alone would break both of those. Fixing them together keeps the sampler's spacing bit-for-bit (2.9e-14 → 2.9e-14, 1.59e-10 → 1.59e-10 on a 1 × 0.05 ellipse) and makes every fraction of the way accurate: `GCPnts_AbscissaPoint(ellipse 8×3, total/2, first)` moves from `u = 3.162016203` to `u = 3.141592654`.

**Validation** (override-link first, then the rebuilt binary — see the `#0001` entry for the technique, compiled with `-DNDEBUG -DNo_Exception` to match the production build): every relative error in the table above goes to ≤ 2.6e-13, `CPnts_AbscissaPoint::Length`'s own direct errors from 1.0e-1 to 2.8e-8, and the inverse from 3.4e-3/1.5e-2/1.7e-2 at the full length to ≤ 1.8e-13 at every fraction. The rebuilt xcframework reproduces the override-linked prediction line for line with no override TUs. Full `swift test` (5096 tests / 1371 suites): no change, the same 3 pre-existing `Issue496CylindricalHoleTests` failures as before the rebuild.

**Cost:** the floor is three quadratures where there was one, and a curve whose closed form is exact (`GeomAbs_Line`, `GeomAbs_Circle`, a 2-pole Bezier/B-spline) never reaches the integrator at all. `GCPnts_AbscissaPoint::Length` on an 8 × 3 ellipse goes 0.24 µs → 7.2 µs; on a 200-span B-spline 87 µs → 444 µs; `GCPnts_UniformAbscissa` at 500 points on an ellipse 2.71 ms → 6.20 ms.

**Not reached by this patch:** `BRepGProp::LinearProperties` runs its own integrator and still reports 41.243157870 for a 10 × 1 elliptical edge against a true 40.639741801 (confirmed unchanged against the rebuilt binary). Same defect class, different code, its own fix.

**OCCTSwift's own bridge-side subdivision (#603, `occtAdaptorArcLength`) is now redundant but not removed.** `ci.yml` resolves the pinned *released* kernel, which does not carry this patch, so removing it would fail the #603 regression tests there until a release ships this binary. Layered on the fixed kernel it costs almost exactly 2× (an 8 × 3 ellipse 3.3 µs → 6.6 µs) and changes no answer — retire it in the release commit that bumps `Package.swift`'s `url:`/`checksum:`.

See [`Scripts/repro/603-single-span-quadrature/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/603-single-span-quadrature) for the reproducers and full writeup. Filed upstream as [Open-Cascade-SAS/OCCT#1420](https://github.com/Open-Cascade-SAS/OCCT/pull/1420), a fix PR with no companion repro issue, per upstream's own guidance on [OCCT#1409](https://github.com/Open-Cascade-SAS/OCCT/issues/1409#issuecomment-5124395058). The three touched files are byte-identical between upstream `master` and our `V8_0_0_p1` pin, so the patch is the same change on both.

**Retire** once the bundled OCCT includes this fix.

## 0022-ChFi2d_Builder-AddChamfer-connexion-error-check-705.patch

**Fixes the upstream OCCT defect behind [#705](https://github.com/SecondMouseAU/OCCTSwift/issues/705)**,
which OCCTSwift already guards bridge-side (`OCCTFace2DChamfer`, `OCCTBridge_Modeling.mm`):
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
closest point to report — only a distance. `NbExt()` reports `1` in exactly those cases, so
`Points(1)` indexes an empty `NCollection_Sequence`. `Points()`'s own bounds check is a raw `throw`,
not compiled out under `No_Exception` (this project's Release kernel is built with
`BUILD_RELEASE_DISABLE_EXCEPTIONS=ON`) — but it checks the wrong bound, so it never fires. The check
that would catch the real problem, `NCollection_Sequence::Value()`'s own `Standard_OutOfRange_Raise_if`,
*is* built from that macro and *is* compiled to nothing under `No_Exception`; with no guard left,
indexing an empty sequence walks a null node. Confirmed with a standalone binary linked directly
against `libOCCT-macos.a`: a genuine SIGSEGV, not a C++ exception a `catch (...)` could absorb.
`GeomAPI_ExtremaCurveCurve::Points()` (what `OCCTCurve3DExtrema` calls) has the identical shape one
layer up — its own bounds check is also a `Raise_if` no-op under `No_Exception` — so nothing between
the bridge and the null-node dereference does anything until this patch.

**Caller survey before choosing a fix shape** (the issue asked for one; two alternatives were
considered and rejected):

- *Redefine `NbExt()` to count `mypoints` instead of `mySqDist`.* Rejected:
  `GeomAPI_ExtremaCurveCurve::LowerDistance()` reaches `SquareDistance(myIndex)`, which
  bounds-checks against `NbExt()` too. Redefining it would make the parallel-distance-only case
  (which has a perfectly well-defined distance, just no unique point) start refusing
  `LowerDistance()` as well — measured that this caller currently gets a correct answer in exactly
  the branches this patch touches, and unifying the counts would have broken it.
- *Gate `Points()` on `IsParallel()`* (what the bridge does, one layer up, for its own purpose).
  Traced every branch of `PrepareParallelResult` by hand: `IsParallel()` is true in precisely the
  branches that leave `mypoints` empty and false in precisely the branches that populate it, no
  exceptions found — so this is equivalent to the fix actually made, *today*. Chose the
  container-bound version instead because it is self-defending against the shape of the bug (an
  index into a container with fewer entries than claimed) rather than relying on a correspondence
  between two fields that nothing enforces, and because `SquareDistance()` already bounds against
  the container it reads (`mySqDist`) — `Points()` doing the same against `mypoints` matches an
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
(`OCCTCurve2DMinDistance`, `OCCTCurve2DAllExtrema` — the latter is the "very likely a 2D sibling"
follow-up PR #730 flagged but didn't confirm; this patch's repro confirms it is not).

**Validation** (override-link, no full rebuild, see the `#0001` entry above for the technique,
compiled with `-DNDEBUG -DNo_Exception` to match the production build): four fixtures — finite
parallel segments with overlapping projected ranges, the same with disjoint ranges, two infinite
parallel `Geom_Line`s, and finite parallel segments whose projected ranges touch at exactly one
point. The first two are the issue's own ground truth; the third is PR #730's own regression
fixture shape; the fourth was added after tracing `PrepareParallelResult`'s line-line branch by
hand suggested it might be a counter-example to the `IsParallel()`/`mypoints` correspondence above —
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
the pinned `v2.0.0-kernel.1` binary asset — see `docs/v2.0.0-plan.md`'s release watch-out. The next
kernel rebuild needs to carry all three, and confirm all three actually reached the binary rather
than assuming the rebuild picked them up, per `docs/guides/building-occt.md`'s shipping-a-rebuild
steps.

## 0025-GeomFill_Sweep-report-achieved-conversion-error-597.patch

**Fixes the upstream OCCT defect behind [#597](https://github.com/SecondMouseAU/OCCTSwift/issues/597)**
(kernel half — the bridge half was investigated and closed as provably empty by PR #751, both
obvious fixes there broke real tests).

`GeomFill_Sweep::BuildAll` measures the swept surface's real approximation error at
`GeomFill_Sweep.cxx:286` (`SError = Approx.MaxErrorOnSurf();`). When the caller has requested
`ForceApproxC1` and the swept surface isn't already C1 in V, it re-approximates through
`GeomConvert_ApproxSurface(mySurface, theTol, ...)` (`theTol` a literal `1.e-4`) and, on
`HasResult()`, replaces `mySurface` with the conversion's output — then overwrites the measured
error with the requested tolerance instead of reading what the conversion achieved:

```cpp
SError = theTol;   // GeomFill_Sweep.cxx:325
```

`GeomConvert_ApproxSurface::HasResult()` is documented as true even for a result "not NECESSARILY
within the required tolerance," and `MaxError()` — which reports what was actually achieved — sits
unread two lines above. `BRepFill_Sweep`/`BRepFill_PipeShell`/`BRepOffsetAPI_MakePipeShell::ErrorOnSurface()`
all forward `SError` verbatim, so `BRepOffsetAPI_MakePipeShell::SetForceApproxC1(true)` — a public,
documented API — hands every caller a number describing the request, not the result.

**Getting a repro to fire needs care.** The branch only runs when the *swept surface itself* fails
`IsCNv(1)`, and `BRepFill_Sweep` splits its sweep at every spine **vertex**, so a polyline spine
never reaches it — the discontinuity has to sit inside one unsplit edge. The fixture (borrowed from
[#572](https://github.com/SecondMouseAU/OCCTSwift/issues/572), pinned by
`Tests/OCCTModelingTests/Issue572SweepApproxTests.swift`) is a single-edge spine built as one
degree-2 B-spline curve with an interior knot of multiplicity 2 — a C0 corner inside what
`BRepFill_Sweep` treats as one edge — swept with a unit circle profile and Frenet trihedron via
`BRepFill_PipeShell`, matching the bridge's own construction exactly.

**Is `MaxError()` the right quantity? Checked, not assumed.** #597's bridge half died on exactly
this trap: `GeomPlate_MakeApprox::ApproxError()` measures fidelity to an *intermediate*
`GeomPlate_Surface`, not the caller's actual input, so gating on it broke 6/6
`Issue571PlateApproxTests`. Here there is no third object: `GeomConvert_ApproxSurface`'s `Surf`
argument *is* `mySurface`, the exact surface being replaced. Confirmed by reconstructing the same
`GeomConvert_ApproxSurface(unforcedSurface, 1e-4, C1, C1, 14, 14, 16, 1)` call from outside the
kernel (using the surface a separate `ForceApproxC1(false)` build returns, which never reaches this
branch and is exactly what `mySurface` holds at the real call site) — its output has the same
degree/pole counts as the real forced build's, and deviation from the same unforced-surface baseline
to each is bit-identical, proving the reconstruction is the real call, not a divergent simulation.
**Does `MaxError()` actually move?** Patch `0019` (#522) is what makes this possible: before it,
every interior truncation error was structurally zero, so `MaxError()` could not report a large
number no matter how bad the fit was. Measured against the currently pinned kernel (all of
`0010`-`0012`/`0014`-`0021` baked in): `MaxError() = 2.54714`, matching #572's own independent
measurement of this identical fixture (`2.547`) to the printed precision. It moves.

**Fix:** `SError = ConvertApprox.MaxError();`. One line. `CError`'s four literal `0.` entries a few
lines above are left untouched — no 2D curve error is available from `GeomConvert_ApproxSurface` at
this point, and inventing one would be exactly the fabrication [#726](https://github.com/SecondMouseAU/OCCTSwift/issues/726) exists to prevent.

**Validation** (override-link, no full rebuild, see the `#0001` entry above for the technique,
compiled with `-DNDEBUG -DNo_Exception` to match the production build): the real, in-kernel
`BRepFill_PipeShell`/`GeomFill_Sweep` object's `ErrorOnSurface()` goes from `0.0001` (exactly
`theTol`, stock) to `2.54714` (matching the externally-reconstructed prediction exactly) after the
patch. Every other value the harness prints — the returned surface's degree/pole/knot counts and two
independent geometric deviations (same-parameter and nearest-point) — is byte-identical before and
after: this patch changes only what the class *reports*, never the surface any caller receives
(`mySurface` is already `ConvertApprox.Surface()` two statements earlier). Consumer survey: no
existing bridge site gates on this number — `PipeShellBuilder.errorOnSurface` is info-only (its one
test asserts `>= 0`), and `OCCTGeomFillSweep`'s own error gate (added in PR #741, the other half of
#597) never sets `ForceApproxC1` so it never reaches this branch at all. `swift test` is therefore
unaffected; this is a diagnostic-only fix.

Confirmed the patch applies cleanly (`git apply --check -p1`) to both the pinned `V8_0_1` tag and
current upstream `master` (`b8f597c6`), byte-identical between the two for the touched file.
`clang-format --dry-run --Werror` against OCCT's own `.clang-format` reports zero violations.

See [`Scripts/repro/597-geomfill-sweep-error-overwrite/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/597-geomfill-sweep-error-overwrite)
for the reproducer, fixture derivation and full before/after transcripts. **Filed upstream as a PR
draft only** (`draft-pr.md` in that directory, **not sent** — this task's constraints forbid writing
to `Open-Cascade-SAS/OCCT`), per `okf/policies/upstream-occt-style.md` and the precedent of `0018`,
`0019`, `0021` and `0024`: the fix was ready, so the PR description carries the repro and root cause
a standalone issue would have.

**Retire** once the bundled OCCT includes this fix.

**Pin consequence**: this is the fourth patch (after `0022`, `0023`, `0024`) carried in the tree but
outside the pinned `v2.0.0-kernel.1` binary asset. PR #754 (`chore/512-repin-kernel-2`, open at the
time of writing) re-pins to `v2.0.0-kernel.2`, folding in all fourteen (`0010`-`0012`,
`0014`-`0024`) — once that merges, `0025` becomes the *only* patch left outside the pin, exactly the
gap `docs/v2.0.0-plan.md`'s RESOLVED block already names by number ahead of time. Watch for it at
the next re-pin, same as `0022`-`0024`.

# Retired patches

The `.patch` files below are **deleted**. Each fix now comes from the pinned OCCT release itself, so
re-applying it would fail (the change is already in the source tree) and `build-occt.sh` would abort.
The writeups are kept because for several of these they are the only record of the root cause at
this depth; read them as history, not as a description of anything the build still does.

Before each file was deleted its hunks were checked against the as-merged upstream form in the
pinned tag, because review can change a patch between submission and merge, and for `0001` it did.
Each section opens with that verdict.

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
itself under the same `"STEP"`/`"step"` names the plain writer resolves by —
`STEPControl_Writer::SetWS()` unconditionally re-runs `SelectNorm("STEP")`. So after **any** XDE STEP
read (merely *constructing* a `STEPCAFControl_Reader` is enough — no `ReadFile`, no `Transfer`, no
document), every shape-level STEP write ran with **empty** `OperationsFlags`: `DirectFaces` never ran,
and faces built on indirect (left-handed) surfaces were silently dropped.

A cone frustum (r1=5, r2=2, h=10) wrote as a 2-face solid with its lateral `CONICAL_SURFACE` and seam
`LINE`s missing and 63% of its volume gone (408.407 → 151.844) — while still reporting
`isValid == true`. Only cones were affected: box/cylinder/sphere/torus have no indirect surfaces.

p1 already *defines* `STEPControl_Writer::InitializeMissingParameters()` (which restores the default
ShapeFix parameters **and** the `SplitCommonVertex`/`DirectFaces` flags when absent) but never calls
it — dead code there, and `private`, so a consumer cannot invoke it either. The patch is upstream's
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


**Fixes the upstream OCCT thread-safety defect behind [#298](https://github.com/SecondMouseAU/OCCTSwift/issues/298)** — concurrent `BRepFilletAPI_MakeFillet` builds on independent shapes corrupt each other.

`BRepFilletAPI_MakeFillet` reconstructs its result solid through the legacy `TopOpeBRepBuild` boolean engine (`ChFi3d_Builder::Compute` → `TopOpeBRepBuild_HBuilder::MergeSolid` → `TopOpeBRepBuild_Builder::SplitSolid`), which passes state between methods through **file-scope `static` variables**. That makes it non-reentrant: two fillet builds on separate threads produce a wrong-but-plausible solid that fails `BRepCheck` — silent bad geometry, no crash, no thrown error.

ThreadSanitizer on an 8-thread fuse+fillet stress (V8_0_0_p1) pinpoints the **functional** culprit as `STATIC_SOLIDINDEX` in `TopOpeBRepBuild_Builder.cxx`: `SplitSolid` sets it to 1/2 to tell `FillSolid` which operand it is splitting, and `FillSolid` reads it back to pick the operand shape. Concurrent reconstructions interleave the writes, so `FillSolid` mis-classifies faces and drops material (the ~260-unit volume loss in the repro). Fixing that one variable makes a stress of 1600 concurrent fillet builds return correct geometry every time (was ~15–20% corrupt).

The patch converts the fillet-path shared statics to `static thread_local` (each thread keeps its own copy of the cross-call state; single-thread behaviour is unchanged):

- **Functional** (cause the corruption): `STATIC_SOLIDINDEX` (`TopOpeBRepBuild_Builder.cxx`) and `STATIC_lastVPind` (`TopOpeBRep_kpart.cxx`, same cross-call-cache pattern, converted for the same reason).
- **Benign data races** on the same path (no geometry corruption observed — `STATIC_SOLIDINDEX` alone already gives correct geometry — but still UB; converted so concurrent fillet is TSan-clean): the constant/evolutive-radius blend solvers' scratch cache (`BlendFunc_ConstRad.cxx`, `BlendFunc_EvolRad.cxx`) and the ChFi3d curve checker's reused adaptor (`ChFi3d_Builder_6.cxx`).

This is the same class of fix, in the same engine, as [Open-Cascade-SAS/OCCT#1180](https://github.com/Open-Cascade-SAS/OCCT/pull/1180) (19 TKBool globals → `thread_local` across 8 files); `STATIC_SOLIDINDEX` and these were not covered by it.

**Validation:** the isolated pure-C++ repro (`fuse` two/three prisms → fillet the seam, 8 threads) returns BRepCheck-invalid solids across several wrong volumes on stock p1, and 0/1600 invalid with a single correct volume after the patch. ThreadSanitizer reports the `STATIC_SOLIDINDEX` and `BlendFunc` scratch races on stock p1 and is clean on the fillet path after the patch (only an unrelated benign `BOPAlgo_InitMessages` lazy-init race remains, in the boolean path — orthogonal). The in-wrapper `occtFilletMutex` that v1.12.1 shipped as the interim guard was **already removed in v1.12.3** once this kernel patch made fillet reentrant — the patch is now the sole protection.

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


**Fixes the upstream OCCT crash behind [#310](https://github.com/SecondMouseAU/OCCTSwift/issues/310)** — `ShapeAnalysis_FreeBounds` (backing `Shape.freeBoundsClosedWires`/`freeBoundsClosedCount`/`freeBoundsOpenWires`) SIGSEGVs on certain shapes with multiple free-boundary components.

`ShapeAnalysis_FreeBounds::SplitWire` (its per-wire helper) finds each wire's closed sub-loops, then hands whatever edges weren't consumed to `ConnectEdgesToWires` to build the "open" result. When a wire's edges are **entirely** consumed by closed-loop detection — leaving zero leftover edges — that hand-off is an empty (but non-null) sequence. The call chain `ConnectEdgesToWires` → `ConnectWiresToWires` → `connectWiresToWiresImpl` starts with:

```cpp
if (iwires.IsNull() || !iwires->Length())
{
  return;
}
```

For empty input this returns **without ever assigning `owires`** — every caller in the file starts from a freshly-defaulted (null) handle, so the null propagates all the way back to `SplitWire`'s `open` output parameter, then to `ShapeAnalysis_FreeBounds::SplitWires`'s `open->Append(tmpopen)` — dereferencing the null handle, an uncatchable SIGSEGV. Not a data-volume threshold: it depends only on whether *any* single free-boundary component happens to close with nothing left over, so a shape with 150+ loops can be fine while a 2-loop shape crashes (and vice versa).

**Fix:** the one-line contract restoration `connectWiresToWiresImpl`'s own non-empty path already follows a few lines down (`owires = new NCollection_HSequence<TopoDS_Shape>;` before populating it) — "nothing to connect" should produce a valid **empty** result, not an untouched out-parameter.

**Validation** (AddressSanitizer, extending the #0001 override-link technique — see the patch's own commit message for the full command sequence): an ASan-instrumented macOS-arm64 build (`ModelingAlgorithms`+`ModelingData`+`FoundationClasses`, `RelWithDebInfo`, `MMGT_OPT=0` at runtime) crashes 100% of the time on two disjoint planar faces in one compound — same function, same `NCollection_Sequence::Append` call, same `0xfffffffffffffff8` fault address at both `-O2` and `-O0` — and returns the correct `2 closed, 0 open` after the patch. On the real 150-face fixture from #310: `tol=0.05` gives `152 closed/0 open` byte-identical before and after (no behavior change on the working path); `tol=0.10` crashes on stock p1 and returns `144 closed/0 open` after.

Reported and isolated at SecondMouseAU/OCCTSwift#310; a repro-only report was filed upstream as [Open-Cascade-SAS/OCCT#1376](https://github.com/Open-Cascade-SAS/OCCT/issues/1376) before the root cause was pinned down, followed up with the fix as [OCCT#1377](https://github.com/Open-Cascade-SAS/OCCT/pull/1377).

**Retire** once the bundled OCCT includes this fix.

## 0005-ShapeFix_Face-guard-null-context-FixPeriodicDegenerated-317.patch

**RETIRED 2026-08-03. The `.patch` file is deleted.** Shipped upstream in OCCT `V8_0_1` as [OCCT#1380](https://github.com/Open-Cascade-SAS/OCCT/pull/1380); the pin moved from `V8_0_0_p1` to `V8_0_1` in the same change.

**Equivalence check.** Identical: the same `if (!Context().IsNull())` guard around the same `Replace()`, differing only by our `// #317:` comment line.


**Fixes the upstream OCCT crash behind [#317](https://github.com/SecondMouseAU/OCCTSwift/issues/317)** — `ShapeFix_Face::Perform` SIGSEGVs healing a face whose sole boundary wire is a single closed edge belting the full period of a `Geom_ConicalSurface` (the shape produced by fitting a rivet/boss-rim seam as one periodic curve — `Wire.wireFromEdges` itself was the original suspect, per the issue's title, until a real in-process backtrace pinpointed the actual site).

`ShapeFix_Face::FixPeriodicDegenerated()` (added to patch in a degenerate apex edge for exactly this "lone wire belts a cone" case) builds the apex edge/wire, assembles a new face, and finalizes:

```cpp
myResult = aNewFace;
Context()->Replace(myFace, myResult);
```

Every *other* `Context()->Replace` call site in this same file — eleven of them — guards against a null `Context()` first (either a plain `if (!Context().IsNull())`, or a lazy `SetContext(new ShapeBuild_ReShape)` when null). `FixPeriodicDegenerated` even checks `Context().IsNull()` at the *top* of the function before calling `Context()->Apply()` — but the check is missing at the *bottom*. `Context()` returns `ShapeFix_Root::myContext`, which the base constructor leaves null; it's only set by an explicit `SetContext()` call, which the ordinary, most common usage (`ShapeFix_Face fixer(face); fixer.Perform();` — including our own bridge, before this patch) never makes. Any caller healing a lone periodic-conical wire without a context null-derefs.

**Fix:** the same guard used at every other call site in the file — only replace in the context if there is one.

**Validation** (fast path, no full rebuild — see the `#0001` entry above for the override-link technique): a synthetic single closed edge (`GeomAPI_Interpolate`, `closed=true`, 10 real points from a rivet rim on `railsim_581_lead.stl`) trimmed to a `Geom_ConicalSurface` via `BRepBuilderAPI_MakeFace(surf, wire, true)`, then healed with a bare `ShapeFix_Face fixer(face); fixer.Perform();`, SIGSEGVs 100% of the time on stock `V8_0_0_p1`. Diagnosed with a custom `backtrace_symbols_fd` `SIGSEGV` handler (`lldb`/core dumps unavailable in the diagnosing sandbox — see the `feedback-lldb-blocked-use-signal-handler` note): the backtrace pins the crash to `ShapeFix_Face::FixPeriodicDegenerated`; `-O0` single-TU override-link tracing confirms every prior statement in the function completes and the crash is specifically the unguarded `Context()->Replace` call. After the patch the same input returns `IsDone()==true` and a valid healed face. Also applied as a defensive `fixer.SetContext(new ShapeBuild_ReShape)` in the three OCCTSwift bridge call sites that construct a bare `ShapeFix_Face` (`OCCTShapeCreateFaceFromSurfaceWire[WithHoles]`, `OCCTFaceFixerCreate`), so the crash is closed immediately without waiting on an xcframework rebuild.

Reported and isolated at SecondMouseAU/OCCTSwift#317; filed upstream as [Open-Cascade-SAS/OCCT#1378](https://github.com/Open-Cascade-SAS/OCCT/issues/1378), fix as [OCCT#1380](https://github.com/Open-Cascade-SAS/OCCT/pull/1380).

**Retire** once the bundled OCCT includes this fix.

## 0006-BRepGProp_EdgeTool-use-adaptor-NbPoles-curve-on-surface-318.patch

**RETIRED 2026-08-03. The `.patch` file is deleted.** Shipped upstream in OCCT `V8_0_1` as [OCCT#1382](https://github.com/Open-Cascade-SAS/OCCT/pull/1382); the pin moved from `V8_0_0_p1` to `V8_0_1` in the same change.

**Equivalence check.** Identical: the carried patch reverse-applies cleanly against `V8_0_1`.


**Fixes the upstream OCCT crash behind [#318](https://github.com/SecondMouseAU/OCCTSwift/issues/318)** — `BRepGProp::LinearProperties` (backing `Shape.analyze(tolerance:)`'s small-edge scan, and anything else built on `BRepGProp_Cinert`) SIGSEGVs computing the integration order for an edge whose sole geometry is a Bezier/BSpline-type curve-on-surface pcurve (no 3D curve) — the common case for a degenerate edge `BRepBuilderAPI_Sewing` produces reconciling near-coincident vertices between two faces that don't share an edge outright.

`BRepGProp_EdgeTool::IntegrationOrder` branches on `BAC.GetType()` (a `BRepAdaptor_Curve`), which correctly reports the curve-on-surface pcurve's type via `GeomAdaptor_TransformedCurve::GetType()`'s override (`myConSurf.IsNull() ? myCurve.GetType() : myConSurf->GetType()`), but then reads the pole count via a completely different, non-virtual path: `BAC.Curve().Curve()`, down-cast to `Geom_BezierCurve`/`Geom_BSplineCurve`. `BAC.Curve()` returns the base `GeomAdaptor_Curve` sub-object (`myCurve`), which holds the 3D-curve representation only — it is never `Load()`ed when the edge has no 3D curve (only `myConSurf` gets set), so the handle is null, the down-cast returns null, and `->NbPoles()` dereferences it.

**Fix:** `GeomAdaptor_TransformedCurve` already has a correctly-dispatching `NbPoles()` override right next to `GetType()` in the same header (`myConSurf.IsNull() ? myCurve.NbPoles() : myConSurf->NbPoles()`). Calling `BAC.NbPoles()` instead of manually re-deriving the pole count fixes the crash and matches the accessor `GetType()` already uses one line above it — no cast, no null check needed, no behaviour change for an edge that does have a 3D curve.

**Validation:** sewing two real mesh-derived planar candidate faces from OCCTReconstruct's plane-select spike (`kof_ii_engine_cover.stl`, regions 10 + 64) with `BRepBuilderAPI_Sewing` produces a compound containing a degenerate edge whose only representation is a BSpline-type pcurve; running `BRepGProp::LinearProperties(edge, props)` on it (the same call `Shape.analyze(tolerance:)` makes per edge) SIGSEGVs 100% of the time on stock p1 — diagnosed with a custom `SIGSEGV` handler (`lldb`/core dumps unavailable in the diagnosing sandbox), backtrace pins the crash to `BRepGProp_EdgeTool::IntegrationOrder`. A from-scratch synthetic degenerate edge (`BRep_Builder` + a hand-built `Geom2d_BSplineCurve` pcurve on a plane, no 3D curve) reproduces the identical crash trace, confirming the mechanism doesn't depend on the specific fixture. After the patch both the real fixture and the synthetic edge complete and return a sane length. Also applied as a defensive guard in the bridge (`OCCTShapeAnalyze`'s small-edge scan skips degenerate edges outright — a degenerate edge's zero 3D extent isn't a "small edge" defect to flag, and this closes the crash immediately without waiting on an xcframework rebuild).

Reported and isolated at SecondMouseAU/OCCTSwift#318; filed upstream as [Open-Cascade-SAS/OCCT#1381](https://github.com/Open-Cascade-SAS/OCCT/issues/1381), fix as [OCCT#1382](https://github.com/Open-Cascade-SAS/OCCT/pull/1382).

**Retire** once the bundled OCCT includes this fix.

## 0007-ShapeAnalysis_FreeBounds-reset-lwire-skipped-loop-323.patch

**RETIRED 2026-08-03. The `.patch` file is deleted.** Shipped upstream in OCCT `V8_0_1` as [OCCT#1331](https://github.com/Open-Cascade-SAS/OCCT/pull/1331); the pin moved from `V8_0_0_p1` to `V8_0_1` in the same change.

**Equivalence check.** Identical: the carried patch reverse-applies cleanly against `V8_0_1`.


**Backports** [Open-Cascade-SAS/OCCT#1331](https://github.com/Open-Cascade-SAS/OCCT/pull/1331) (open, third-party author, pinned to commit `7557161a3dbe7e1ba18a3e63e1e104830d8c24c5`), fixing [OCCT#1330](https://github.com/Open-Cascade-SAS/OCCT/issues/1330). Audited and queued in [#323](https://github.com/SecondMouseAU/OCCTSwift/issues/323) alongside `0008`/`0009`; unlike `0001`–`0006`, this batch wasn't discovered via an OCCTSwift crash report — it's a proactive audit of upstream OCCT PRs filed since our `V8_0_0_p1` baseline that fix crashes/hangs in code paths we exercise.

`ShapeAnalysis_FreeBounds::connectWiresToWiresImpl` — the same static helper patch `0004` already touches for a different bug (#310) — has a "find the next unconsumed wire" loop that sets `lwire = i` **before** checking whether the candidate wire it just loaded actually has any edges:

```cpp
lwire = i;
sewd->Add(TopoDS::Wire(arrwires->Value(lwire)));
aSel.LoadList(lwire);
if (sewd->NbEdges() > 0) { break; }
sewd->Clear();
```

If the wire is skipped (zero edges — e.g. a "wire" wrapping a single **internal-orientation** edge, which contributes no real boundary edges), `lwire` is left stale instead of reset. If every remaining candidate is likewise skipped, the loop exits with `lwire` still holding that stale index rather than `-1`, so the caller's `if (lwire == -1) { done = true; }` never fires — the outer loop's next iteration reads invalid memory through the stale `sewd`.

**Fix:** only assign `lwire = i` once the wire is actually accepted (`sewd->NbEdges() > 0`), matching upstream's exact reordering.

**Validation** (fast path, no full rebuild — see the `#0001` entry above for the override-link technique): the upstream TCL test (`tests/bugs/heal/bug1330`) translated to C++ — a valid closed triangle wire plus a single internal-orientation edge, fed to `ShapeAnalysis_FreeBounds::ConnectEdgesToWires` — SIGSEGVs 100% of the time on stock p1 + patches `0001`–`0006` (`ShapeExtend_WireData::Edge` reading invalid data) and returns a valid 1-wire result after this patch.

Reported upstream as [OCCT#1330](https://github.com/Open-Cascade-SAS/OCCT/issues/1330) / [OCCT#1331](https://github.com/Open-Cascade-SAS/OCCT/pull/1331) (third party, open — pin to the SHA above and re-verify if it changes in review).

**Retire** once the bundled OCCT includes this fix.

## 0008-Geom_BSplineCurve-O1-PeriodicNormalization-323.patch

**RETIRED 2026-08-03. The `.patch` file is deleted.** Shipped upstream in OCCT `V8_0_1` as [OCCT#1329](https://github.com/Open-Cascade-SAS/OCCT/pull/1329); the pin moved from `V8_0_0_p1` to `V8_0_1` in the same change.

**Equivalence check.** Identical: the carried patch reverse-applies cleanly against `V8_0_1`.


**Backports** [Open-Cascade-SAS/OCCT#1329](https://github.com/Open-Cascade-SAS/OCCT/pull/1329) (merged 2026-07-05, upstream commit `37c9279f446894c5d123cb1fdda0ac848959361f`), fixing [OCCT#1288](https://github.com/Open-Cascade-SAS/OCCT/issues/1288) ("Boolean operation 'section' hangs-up for a pair of cylindrical shapes"). Audited and queued in [#323](https://github.com/SecondMouseAU/OCCTSwift/issues/323).

`Geom_BSplineCurve::PeriodicNormalization` brought an out-of-range parameter back into a periodic curve's valid range by repeatedly adding/subtracting one period at a time in a `while` loop — O(N) in the distance from the valid range, and a genuine infinite loop once the parameter's magnitude is many orders larger than the period: `Parameter -= Period` becomes a floating-point no-op at that magnitude, so the loop never terminates. `BRepAlgoAPI_Section` hung indefinitely reaching this path on cylindrical shapes with self-intersecting geometry.

**Fix:** rewritten to O(1) — one division (`std::floor`) computes the whole number of periods to shift, applied in a single step, with at most one single-period correction for floating-point residual overshoot (using `std::nextafter` to guarantee forward progress if the correction is itself a no-op). An early return when the parameter is already in range skips even that division in the common case.

**Validation** (fast path, no full rebuild): a normal closed periodic curve (`GeomAPI_Interpolate`, 8 points on a unit circle, period ≈ 6.12) with `PeriodicNormalization(1e17)` hangs indefinitely on stock p1 (confirmed by wall-clock timeout) and returns instantly with a valid in-range parameter (`1.0364`) after the patch. A sanity sweep of nine in-range/near-boundary/several-periods-off parameters produces **byte-identical** output before and after — no behavior change for values this function is normally called with.

Filed upstream by OCCT as [OCCT#1329](https://github.com/Open-Cascade-SAS/OCCT/pull/1329) (merged, stable).

**Retire** once the bundled OCCT moves past commit `37c9279f446894c5d123cb1fdda0ac848959361f`.

## 0009-StepData_StepWriter-split-oversized-string-323.patch

**RETIRED 2026-08-03. The `.patch` file is deleted.** Shipped upstream in OCCT `V8_0_1` as [OCCT#1318](https://github.com/Open-Cascade-SAS/OCCT/pull/1318); the pin moved from `V8_0_0_p1` to `V8_0_1` in the same change.

**Equivalence check.** Identical: the carried patch reverse-applies cleanly against `V8_0_1`.


**Backports** [Open-Cascade-SAS/OCCT#1318](https://github.com/Open-Cascade-SAS/OCCT/pull/1318) (open, by an OCCT maintainer, pinned to commit `72bc2368372d93d6f84717f2327131d4c000d7c1`). No linked upstream issue. Audited and queued in [#323](https://github.com/SecondMouseAU/OCCTSwift/issues/323). Same subsystem as `0002`.

`StepData_StepWriter::AddString` writes a raw token into the writer's current-line buffer (fixed at 72 characters, `StepLong`), flushing and resetting the line whenever the pending text won't fit — assuming the token itself is never longer than one full line. When a single unbroken string value (e.g. a long name/label field with no natural break point) is longer than 72 characters, the flush-check can never become true no matter how many times the line is reset: the loop runs forever.

**Fix:** when the token fits within `StepLong`, behavior is unchanged. When it doesn't, the new code splits the token across as many lines as needed, filling each with as much as fits before flushing and continuing with the remainder — continuation lines also drop their indentation when the indented prefix would leave no room for the pending text.

**Validation** (fast path, no full rebuild): `StepData_StepWriter::StartEntity` + `SendString` (the public entry point — `AddString` itself is private) with a 200-character unbroken string hangs indefinitely on stock p1 (confirmed by wall-clock timeout) and returns instantly after the patch, correctly split across three continuation lines with the original text intact end-to-end. A sanity check with only normal-length fields produces **byte-identical** `Print()` output before and after. New OCCTSwift-level regression test `STEPWriterOversizedNameTests` (`OCCTIOTests`) exercises the same path through `Shape.writeSTEP(to:name:)`.

**Retire** once the bundled OCCT includes this fix (open PR — pin to the SHA above and re-verify if it changes in review).

## 0013-ShapeUpgrade_UnifySameDomain-guard-null-pcurve-348.patch

**RETIRED 2026-08-03. The `.patch` file is deleted.** Shipped upstream in OCCT `V8_0_1` as [OCCT#1392](https://github.com/Open-Cascade-SAS/OCCT/pull/1392); the pin moved from `V8_0_0_p1` to `V8_0_1` in the same change.

**Equivalence check.** Identical: all five guards are present verbatim, our comment strings included. Upstream then went further in the same file; see the carried-forward note below.

**Carried forward into 8.0.1 triage.** `V8_0_1` added null-pcurve guards beyond these five, in
`getCurveParams`, `FindClosestPoints` and `TransformPCurves`, and changed
`RelocatePCurvesToNewUorigin` from `void` to `bool` so a relocation that cannot be done is now
declined and its partial result discarded rather than carried on with. That is a behaviour change
to `UnifySameDomainBuilder.build()`, not just a crash guard; it is measured in the 8.0.1 absorb.


**Fixes the upstream OCCT crash behind [#348](https://github.com/SecondMouseAU/OCCTSwift/issues/348)** — an uncatchable SIGSEGV in `UnifySameDomainBuilder.build()` on a real mesh-sewn solid, minimized to a standalone OCCTSwift-only reproducer (no mesh handling, no OCCTReconstruct code involved).

`ShapeUpgrade_UnifySameDomain::IntUnifyFaces` (and its file-local `SplitWire` helper) disambiguate between multiple candidate next-edges at a branching vertex by comparing each candidate's pcurve tangent direction on the current reference face. Three call sites in `IntUnifyFaces` (`ShapeUpgrade_UnifySameDomain.cxx:3989`, `:4003`, `:4027`) and a structurally identical pair in `SplitWire` (`:4643`, `:4659`) fetch that pcurve via `BRep_Tool::CurveOnSurface(edge, refFace, first, last)` and dereference it immediately (`->D1(...)`/`->Value(...)`) with no `IsNull()` check — unlike every other `CurveOnSurface` call site in the same file (e.g. `:426`, `:1838`), which do check. `CurveOnSurface` legitimately returns a null handle when an edge has no pcurve on the given face — routine for a raw per-triangle mesh-sewn solid (`BRepBuilderAPI_Sewing` output from an STL/mesh import) at a vertex shared by more than two edges. The dereference is a null-pointer virtual call: Address 0, uncatchable in-process (same signature as the #263/#310/#317/#318 crash family).

Confirmed via a debug (`-g -O0`) single-TU override-link (compile the patched `.cxx` standalone and link it *before* `libOCCT-macos.a`, so the linker never pulls the stock archive member for these symbols) + `lldb bt`: the crash resolves precisely to `ShapeUpgrade_UnifySameDomain.cxx:4003` (`aPCurve->D1(...)`), reached via `IntUnifyFaces` → `UnifyFaces` → `Build`.

**Fix:** guard all five call sites with `IsNull()` checks, following the file's own established pattern. A missing pcurve on a *candidate* edge means "skip it, not a rankable direction" (`continue`); a missing pcurve on the *current* edge (nothing to compare candidates against) falls back to treating all candidates as equally likely — the same fallback the surrounding code already takes for the "only one candidate" case (`TmpElist.Extent() <= 1`/`aElist.Extent() == 1`).

**Validation:** the attached fixture SIGSEGVs 3/3 on stock p1 + patches 0001-0012 (v1.15.7) and survives repeated runs (3+) with the patch applied.

See [`Scripts/repro/348-unify-null-pcurve/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/348-unify-null-pcurve) for the reproducer and full writeup. Filed upstream as [Open-Cascade-SAS/OCCT#1391](https://github.com/Open-Cascade-SAS/OCCT/issues/1391) (repro) / [OCCT#1392](https://github.com/Open-Cascade-SAS/OCCT/pull/1392) (fix).

**Retire** once the bundled OCCT includes this fix.
