# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Summary

OCCTSwift is a comprehensive Swift wrapper for OpenCASCADE Technology (OCCT) 8.0.0 (GA). It exposes B-Rep solid modeling capabilities to Swift for macOS (arm64, v12+) and iOS (arm64, v15+) via a three-layer architecture: Swift public API → Objective-C++ bridge (C functions) → OCCT C++ library. Uses Swift 6 language mode (strict concurrency).

## Build & Test Commands

```bash
swift build                          # Build the package
swift build --target OCCTThreadTests # Focused compile: just one domain's tests (~3s) — see "Test Layout"
swift test                           # Run all tests (~3900 tests across per-domain targets)
swift test --filter "Issue187"       # Run suites whose struct name matches (matches the type, not @Suite title)
swift run OCCTTest                   # Run test executable
```

### Compile a Ground Truth C++ Test

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  /tmp/occt_vXX_test.mm -o /tmp/occt_vXX_test
/tmp/occt_vXX_test
```

### Verify OCCT Symbols

```bash
nm -C Libraries/OCCT.xcframework/macos-arm64/libOCCT-macos.a 2>/dev/null | grep "ClassName" | head -5
```

### OCCT Reference Docs (context7)

OCCT's developer overview / user guides (the `dev.opencascade.org/doc/overview` content,
generated from the repo's `dox/` guides) plus the wiki and headers are available via context7
as **`/open-cascade-sas/occt`**. Query it when wrapping new ops or checking C++ API usage
(e.g. `BRepAlgoAPI` options, `ThruSections`, healing) — it complements `/audit-occt` and the
header-analyzer agent. **Caveats:** context7's snapshot is the **occt-7.9** branch (+ some
`master`), while this project pins **OCCT 8.0.0** — for version-sensitive details, the pinned
headers in `Libraries/OCCT.xcframework/.../Headers` are the source of truth. It documents the
upstream C++ API the bridge wraps, not the Swift surface.

## Architecture

```
Sources/OCCTSwift/          Swift public API (Shape, Wire, Surface, Face, Edge, Curve3D, Mesh, etc.)
Sources/OCCTBridge/include/ C function declarations (single file: OCCTBridge.h)
Sources/OCCTBridge/src/     Objective-C++ implementations (single file: OCCTBridge.mm)
Libraries/OCCT.xcframework  Pre-built OCCT static library (arm64 macOS/iOS)
Tests/OCCT<Domain>Tests/    Per-domain Swift Testing targets (see "Test Layout")
Scripts/build-occt.sh       Builds OCCT.xcframework from source
```

### Handle-Based Memory Management

Opaque handle types (`OCCTShapeRef`, `OCCTWireRef`, `OCCTFaceRef`, `OCCTEdgeRef`, `OCCTMeshRef`) are typedef'd pointers. Swift classes wrap these handles and call the corresponding `Release` function in `deinit`. Every bridge function that creates an OCCT object must have a matching `Release` function.

### Adding a New Wrapped Operation

1. **Bridge header** (`OCCTBridge.h`): Add C function declaration
2. **Bridge impl** (`OCCTBridge.mm`): Add Objective-C++ implementation calling OCCT C++ API
3. **Swift wrapper** (appropriate `.swift` file): Add public method/static factory
4. **Test**: Add `@Suite`/`@Test` to the matching `Tests/OCCT<Domain>Tests/` target (see "Test Layout")

## Naming Conventions

- Bridge functions: `OCCTShape...`, `OCCTWire...`, `OCCTFace...`, `OCCTEdge...`
- Wire-to-shape conversion: `OCCTShapeFromWire()` (NOT `OCCTWireToShape`)
- Check enum values: `OCCTCheckNoError` (NOT `OCCTCheckStatusNoError`)
- `vertices()` is a method, not a property
- Swift factory methods are static: `Shape.box()`, `Wire.rectangle()`
- Fallible operations return optionals, not force-unwrapped values

## Test Layout

Tests are split into **per-domain test targets** (one Swift module each) so editing/compiling
one domain never recompiles the rest. The old 50k-line `ShapeTests.swift` monolith was split by
suite into these targets (each `Tests/OCCT<Domain>Tests/`, declared in `Package.swift`):

`Analysis`, `Curve`, `Drawing`, `Foundation`, `Geom2d`, `IO`, `Integration`, `Math`, `Mesh`,
`Misc`, `Modeling`, `ShapeHealing`, `Stress`, `Surface`, `Thread`, `BRepGraph`, `Topology`, `XCAF`.

- **Add a new suite** to the domain target that best matches it (e.g. a fillet suite → `OCCTModelingTests`,
  a `Curve2D` suite → `OCCTGeom2dTests`). If nothing fits, use `OCCTMiscTests`. Each target is a separate
  module with its own `@testable import OCCTSwift`; the only shared helper is `SIMD3.normalized` (redefine
  it in the target if needed).
- **Focused compile** (the point of the split): `swift build --target OCCTThreadTests` type-checks just
  that module in ~3 s — never touches the other domains.
- **Focused run:** `swift test --filter <StructName>` (the filter matches the test *struct* name, e.g.
  `Issue187`, not the `@Suite("...")` display string). `swift test` still runs everything.
- The full suite occasionally (~1-in-10 parallel runs) hits a hard crash (SIGSEGV/SIGABRT) or a
  timing-flake under parallel execution — see Known OCCT Bugs' `XCAFDoc_ShapeTool::theAutoNaming`
  entry (#341, fixed in the kernel) and #344/#345 (the two crashes, still uncharacterized). A single domain
  target rarely trips either.

## Test Conventions

- Framework: Swift Testing (`@Suite`, `@Test`, `#expect`)
- **Never force-unwrap in `#expect`** — Swift Testing does NOT short-circuit. Use:
  ```swift
  if let r = result { #expect(r.isValid) }
  ```
  Not: `#expect(result != nil); #expect(result!.isValid)`
- Edge indices may vary across runs — iterate edges to find a working one when testing edge-specific operations
- Wrap OCCT calls that may throw `StdFail_NotDone` in try-catch on the C bridge side

## Known OCCT Bugs

- `BRepExtrema_ExtCC` crashes when edges are parallel — guard with `if (result.isParallel) { return result; }` before accessing points
- ~~Container-overflow in NCollection on arm64 macOS~~ — **this claim was never characterized and does not hold up.** Investigated for #341 (2026-07-21) using the #298 TSan protocol (minimal-module ThreadSanitizer build of V8_0_0_p1 + all 10 carried patches): `FoundationClasses`+`ModelingData`+`ModelingAlgorithms` stress scenarios (concurrent create/fuse/fillet, independent meshing) are clean except the already-known benign `BOPAlgo_InitMessages` lazy-init race. No NCollection race reproduced anywhere. Re-enabled the 3 suites in `Tests/OCCTStressTests/StressConcurrencyTests.swift` that had been `.disabled()` under this same unevidenced claim (some since ~v0.51.0) — 25/25 clean runs. **A real, different, previously-undetected race was found instead**: `XCAFDoc_ShapeTool::theAutoNaming`, a process-global `static bool` that `RWMesh_CafReader::fillDocument()`, `RWGltf_CafReader::fillDocument()` (a separate near-duplicate override — reachable via OBJ **and** glTF import), and `XCAFDoc_Editor::Expand()` (reentrant — recurses into itself) all save/mutate/restore with zero synchronization; `XCAFDoc_ShapeTool::AddShape` reads the same flag from every one of those and from ordinary unscoped calls too. Same failure class as #298 (unsynchronized global save/modify/restore), but logical/cosmetic (wrong auto-naming, or racy for the plain `bool` itself) rather than geometric. **Fixed upstream in v1.15.5** (`Scripts/patches/0011-*`, xcframework rebuilt): `XCAFDoc_ShapeTool::AutoNamingScope` (RAII, `std::recursive_mutex`-backed) replaces the three ad hoc save/restore call sites, and `theAutoNaming` itself is now `std::atomic<bool>` so unscoped readers (e.g. `AddShape` calls outside any of the three sites) are no longer racing on the raw storage either. Verified via TSan: 0 races across 4 runs (was 9-17/run), zero regression on the #298/independent-meshing scenarios. The interim bridge-side `meshCafMutex()` mitigation shipped in v1.15.4 was removed once this kernel patch shipped — matches the #298 PR1→PR2 pattern. Filed upstream as [OCCT#1387](https://github.com/Open-Cascade-SAS/OCCT/issues/1387) (repro) / [OCCT#1388](https://github.com/Open-Cascade-SAS/OCCT/pull/1388) (fix, draft). See [`Scripts/repro/341-meshcaf/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/341-meshcaf) for the TSan reproducer and full writeup. #341. The two hard crashes (SIGSEGV/SIGABRT) observed empirically in ~2/20 full-suite parallel `swift test` runs during this investigation were filed separately as #344 (SIGSEGV, root-caused below) and #345 (SIGABRT, still uncharacterized — essentially no localizing evidence).
- `XCAFApp_Application::GetApplication()` / `CDF_Directory::Add` — **#344, the SIGSEGV #341 didn't explain.** Confirmed to survive the #341 kernel fix in v1.15.5 (re-ran the parallel `swift test` loop 12× on v1.15.5: 1 more hit, same signature) — a genuinely different, previously-undetected pair of races. `GetApplication()`'s lazy singleton init (`static Handle(XCAFApp_Application) locApp; if (locApp.IsNull()) { locApp = new XCAFApp_Application; }`) is a textbook double-checked-locking-without-locking bug: two threads' first concurrent call can both construct a new instance and race to assign `locApp`. TSan shows this is the dominant defect — it produces multiple concurrently-constructed `XCAFApp_Application` instances, cascading into races across dozens of unrelated destructors as the "losing" instances are torn down mid-flight. Separately, `CDF_Directory::Add`/`Remove`/`Contains` mutate/read `myDocuments` (a plain `NCollection_List`) with zero synchronization — every `CDF_Application` is normally one process-wide instance shared by every caller, so its one `CDF_Directory` receives `Add()` from every document-creating call on every thread, racing on `NCollection_BaseList::PAppend`. The #341 TSan stress never caught either: it builds `TDocStd_Document` directly, bypassing `XCAFApp_Application`/`CDF_Application` entirely — the real bridge path (`OCCTDocumentLoadOBJ` and every other document-producing call) does not. **Fixed in v1.15.6** (`Scripts/patches/0012-*`, xcframework rebuilt): `GetApplication()` folds construction into the static local's initializer (C++11 magic statics, thread-safe exactly once); `CDF_Directory` gets a private mutex guarding `Add`/`Remove`/`Contains`/`Length`/`IsEmpty`/`Last`. Verified via a debug (`-O0 -g`) build with a temporary `SIGSEGV`/`SIGBUS` handler: stock p1 crashes ~50% of runs at 10 threads × 3000 barrier-synchronized rounds, both captured backtraces resolving to `TDocStd_Application::NewDocument -> CDF_Application::Open`; TSan (same minimal-module protocol as #298/#319/#341) goes from 234 race reports to 9, all in `CDF_Directory::Add`/`PAppend` and all showing the same mutex held on both sides of the reported conflict — consistent with a TSan/allocator-recycling artifact (a control program with a trivially-correct mutex pattern shows no such warning under identical flags), not a genuine unaddressed race; the entire `GetApplication()`-driven destructor cascade is gone entirely. Filed upstream as [OCCT#1389](https://github.com/Open-Cascade-SAS/OCCT/issues/1389) (repro) / [OCCT#1390](https://github.com/Open-Cascade-SAS/OCCT/pull/1390) (fix, two commits). **Found during validation of this same fix**: correctly making `GetApplication()` a true singleton means every caller now genuinely shares ONE `TDocStd_Application` instance — surfacing more races on that instance's OTHER unsynchronized state, previously masked by threads sometimes getting different (uncontended) instances. Repeated `swift test` runs hit a SIGTRAP in `Resource_Manager::SetResource` (via `TDocStd_Application::DefineFormat`, itself called by the common `Document.defineAllFormats()` test-setup path) and a SIGSEGV in `TDocStd_Application::ReadingFormats` iterating `CDF_Application::myReaders` concurrently with a writer. `TDocStd_Application::Resources()` has the identical lazy-init bug as `GetApplication()`; `Resource_Manager`'s maps and `CDF_Application::myReaders`/`myWriters` have zero synchronization. Also fixed in v1.15.6 (same patch): a mutex for `Resources()`'s lazy-init, a `std::recursive_mutex` for `Resource_Manager`'s accessors (added an explicit copy constructor too — the new mutex broke `ShapeProcess_Context.cxx`'s existing `new Resource_Manager(*sRC)` thread-safety workaround, whose own comment already acknowledged this exact defect: *"calling of SetResource() for one object in multiple threads causes race condition"*), and a mutex for `myReaders`/`myWriters`. 0/12 further `swift test` runs of `OCCTXCAFTests` reproduce either crash after the fix. A THIRD, architecturally different crash surfaced in the same validation (`BinLDrivers_DocumentStorageDriver::Write` corrupting a shared, cached, non-reentrant storage-driver instance under concurrent `Save`/`SaveAs` of the same format) — a shared worker object, not a container needing a lock, so the kernel fix needs its own TSan investigation; filed separately as #349. It was severe enough on its own (~60% crash rate in `OCCTXCAFTests` alone once the two races above stopped masking it) that v1.15.6 ships an **interim bridge-side mitigation** for it too: `ocafStoreMutex()` (`OCCTBridge_Document.mm`) serializes `OCCTDocumentSaveOCAF`/`OCCTDocumentSaveOCAFInPlace`/`OCCTDocumentLoadOCAF` — the same #298/#341 PR1→PR2 pattern (bridge mutex now, kernel fix later). 0/12 further `swift test` runs of `OCCTXCAFTests` crash after this mitigation (some pre-existing, unrelated test-fixture flakes remain — hardcoded non-unique temp file paths across parallel `OCAF Save/Load` tests yielding `.alreadyRetrieved`, and the already-known `Issue173AssemblySTEPTests` flake — neither a kernel bug). See [`Scripts/repro/344-cdf-directory/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/344-cdf-directory) for the full writeup. #344.
- **Uncaught-exception SIGABRT — #345, the companion crash to #344.** #345 was filed alongside #344 from the same investigation with "essentially no localizing evidence" (just `exited with unexpected signal code 6`, no test name, no backtrace). An audit (prompted by #344's own finding that fixing one race exposes the next) turned up a plausible, distinct root cause: OCCT's `gp_Dir` constructor throws `Standard_ConstructionError` for a zero-length (or near-zero) direction/normal vector (`Libraries/occt-src/src/FoundationClasses/TKMath/gp/gp_Dir.hxx`); so does `Geom_Direction`'s. **49 public bridge functions** across `Sources/OCCTBridge/src/{OCCTBridge_Curve3D,OCCTBridge_Geom2d,OCCTBridge_Modeling,OCCTBridge_Spatial,OCCTBridge_Surface,OCCTBridge_Topology,OCCTBridge_Visualization}.mm` constructed `gp_Dir`/`gp_Ax1`/`gp_Ax2`/`gp_Ax3`/`Geom_Direction` directly from caller-supplied doubles (or called a `Geom_Surface`/`Geom_Curve` `D0`/`D1`/`D2` derivative evaluator, or a `GeomEval_*Surface` constructor — same throw risk for degenerate radius/amplitude/omega) with **no try/catch anywhere in the call chain** — e.g. `OCCTSurfaceD1`/`OCCTSurfaceD2` had none, right next to `OCCTSurfaceGetNormal` two lines below, which already did (an easy-to-miss inconsistency). An uncaught C++ exception crossing the bridge's `extern "C"`-ish boundary into Swift-generated call frames has no matching unwind personality routine — a guaranteed `std::terminate()` → `abort()` (SIGABRT), and it would leave almost no diagnostic trail, matching #345's profile exactly. **Fixed**: wrapped all 49 in `try { ... } catch (...) { <safe fallback> }` matching each file's existing idiom; the 3 functions returning a `_Nonnull` pointer (`OCCTAxis1PlacementCreate`, `OCCTAxis2PlacementCreate`, `OCCTOBBCreate`) fall back to constructing a valid default axis instead of `nullptr`, since returning null from a `_Nonnull` contract would just relocate the crash to the next dereference. Two confirmed false positives were left untouched: `computePlaneForPoints` (`OCCTBridge_AIS.mm`) and `buildTrsf3D` (two separately-defined `static` helpers, one each in `OCCTBridge_Curve3D.mm`/`OCCTBridge_Surface.mm`) are both already protected by a `try` in their sole caller. New regression tests (`Tests/OCCTStressTests/StressNullInvalidTests.swift`: `mirrorAxisZeroDirection`, `mirrorPlaneZeroNormal`, `geomDirectionZeroVector`) exercise a zero vector through the public Swift API. **Validation**: 70 additional full-suite `swift test` runs (4419-4422 tests each, ~309,540 individual test executions) — zero SIGABRT recurrence, zero crashes of any kind (a handful of already-known, unrelated assertion-level test-fixture flakes remain). This is a bridge-only fix (no OCCT kernel change, no xcframework rebuild) — not an OCCT bug, so nothing filed upstream. #345's own bar for confident closure was "100+ runs with no recurrence"; 70 clean runs plus a fix matching the exact crash mechanism is short of that literal bar but is the strongest evidence gathered to date — recommend closing #345, reopen if it recurs.
- `PCDM_StorageDriver`/`PCDM_Reader` (backs `CDF_Application::WriterFromFormat`/`ReaderFromFormat`) — **#349, the third crash found validating #344.** `CDF_Application` caches one storage/retrieval driver instance per format and hands the same instance back to every `Store()`/`Retrieve()` call for that format, including concurrently from different threads/documents. But `BinLDrivers_DocumentStorageDriver` (and every other format's driver, structurally) is not reentrant: `Write()`/`Read()` mutate instance-level scratch state (`myRelocTable`, `myTypesMap`, and more) with zero synchronization, so two threads' concurrent `Write()` calls corrupt each other — reliable SIGSEGV (`BinMDF_ADriverTable::AssignIds` on a torn `myTypesMap`, reached via `BinLDrivers_DocumentStorageDriver::Write -> FirstPass -> CDF_StoreList::Store -> TDocStd_Application::SaveAs`). TSan (same minimal-module protocol as #298/#319/#341/#344) confirms directly: 136 race warnings + a live SIGSEGV in one run (8 threads × 25 rounds) on stock kernel. **Fixed in v1.15.9** (`Scripts/patches/0014-*`, xcframework rebuilt): `PCDM_StorageDriver`/`PCDM_Reader` each get a `mutable std::mutex` + `Mutex()` accessor — every concrete format driver subclass inherits the guard for free, zero subclass changes needed — held at the three call sites that invoke a cached, possibly-shared driver (`CDF_StoreList::Store`, `CDF_Application::Retrieve`, `CDF_Application::Read`). Considered making the driver itself reentrant (eliminating the shared scratch state) but rejected as impractical: TSan shows essentially the entire driver object is scratch state for one `Write()` call, plus a nested shared `BinMDF_ADriverTable` with its own internal mutation — fixing that properly would mean a sweeping signature change to every format driver's private helpers, out of proportion to a "minimal, surgical" upstream PR. Verified: TSan race warnings 136 → 0 (confirmed again at 10×200), crash → clean exit across repeated runs; full production xcframework rebuild + `swift test --filter OCAFSaveLoadBinaryTests`/`OCCTXCAFTests` clean, 3× full `swift test` (4423 tests) clean. The interim bridge-side mitigation (`ocafStoreMutex()`, shipped v1.15.6) stays in place — same PR1→PR2 pattern as #298/#341/#344. **Found during validation of this fix**: `CDM_Application::myMetaDataLookUpTable` (a plain, unsynchronized `NCollection_DataMap`, one per `CDM_Application`) races too — same failure class as `CDF_Directory::myDocuments` (#344) and `theAutoNaming` (#341), out of scope for #349, filed separately as #353. See [`Scripts/repro/349-ocaf-driver-reentrancy/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/349-ocaf-driver-reentrancy) for the full writeup. Filed upstream as [Open-Cascade-SAS/OCCT#1393](https://github.com/Open-Cascade-SAS/OCCT/issues/1393) (repro) / [OCCT#1394](https://github.com/Open-Cascade-SAS/OCCT/pull/1394) (fix, CI green on all platforms). #349.
- `LocOpe_SplitDrafts` throws on incompatible geometry — always wrap `Perform()` in try-catch in bridge
- `BRepOffsetAPI_ThruSections` (loft) SIGSEGV'd (null deref, "Address 8") on mismatched closed profiles — `BRepFill_CompatibleWires::SameNumberByPolarMethod` over-advanced an unguarded correspondence-list iterator. It's an OS signal, so the bridge `catch(...)` cannot save it. **Fixed upstream in OCCT 8.0.0p1** (Open-Cascade-SAS/OCCT#1298, OCCTSwift #176/#178); the previously-carried `Scripts/patches/0001-*` was dropped — the current p1 xcframework has the guard natively (regression test "Loft polar-method SIGSEGV regression (#176)" passes against it). Note: `OCC_CATCH_SIGNALS` is inert in our build (no `OCC_CONVERT_SIGNALS`) — do not rely on it for signal safety; OS signals raised inside OCCT (e.g. #234) are still uncatchable in-process.
- `ShapeAnalysis_FreeBounds` (backs `Shape.freeBoundsClosedWires`/`freeBoundsClosedCount`/`freeBoundsOpenWires`, and `Shape.freeBounds`) used to SIGSEGV (uncatchable) on certain shapes with multiple free-boundary components — isolated via AddressSanitizer to `connectWiresToWiresImpl`'s empty-input early return (`ShapeAnalysis_FreeBounds.cxx`) leaving its `owires` out-parameter uninitialized (null), which later crashes `NCollection_HSequence::Append`. Minimally reproducible with just two disjoint planar faces in one compound; not a simple loop-count threshold (150+ loops can be fine, 2 can crash) — depends only on whether any single component's boundary closes with zero edges left over. **Fixed upstream in v1.12.6** (`Scripts/patches/0004-*`, xcframework rebuilt): `connectWiresToWiresImpl` now initializes `owires` to an empty sequence before its early return. #310, upstream repro filed as Open-Cascade-SAS/OCCT#1376, fix as [OCCT#1377](https://github.com/Open-Cascade-SAS/OCCT/pull/1377); sibling `Standard_OutOfRange` bug in the same file, OCCT#1330, was a separate, unrelated defect in the same function — also now carried, see the `0007` entry below.
- `ShapeFix_Face::FixPeriodicDegenerated` (invoked from `Shape.face(from:boundary:)`/`face(from:boundary:innerWires:)` and the `FaceFixer` API whenever a face's sole boundary wire is a single closed edge belting a `Surface.cone`'s full period, apex outside the wire's V range — e.g. a rivet/boss-rim seam fit as one periodic curve) used to SIGSEGV (uncatchable) on the ordinary `ShapeFix_Face fixer(face); fixer.Perform();` construction — a null-Context dereference at the function's final `Context()->Replace(myFace, myResult)`, the only one of twelve such call sites in the file missing the `if (!Context().IsNull())` guard every sibling uses. A standalone circle repro is negative (`wireFromEdges` alone never reaches `FixPeriodicDegenerated`); the minimal repro needs the wire trimmed to a periodic conical surface via `face(from:boundary:)`. **Fixed in v1.12.7**: bridge now calls `fixer.SetContext(new ShapeBuild_ReShape)` before `Perform()` at all three `ShapeFix_Face` call sites (immediate fix, any xcframework); kernel patch also carried (`Scripts/patches/0005-*`, xcframework rebuilt) and filed upstream as [OCCT#1378](https://github.com/Open-Cascade-SAS/OCCT/issues/1378) (repro) / [OCCT#1380](https://github.com/Open-Cascade-SAS/OCCT/pull/1380) (fix). #317.
- `BRepGProp_EdgeTool::IntegrationOrder` (invoked from `BRepGProp::LinearProperties`, which backs `Shape.analyze(tolerance:)`'s small-edge scan) used to SIGSEGV (uncatchable) on an edge whose sole geometry is a Bezier/BSpline-type curve-on-surface pcurve (no 3D curve) — the common shape of a degenerate edge `BRepBuilderAPI_Sewing` produces reconciling near-coincident vertices between two faces that don't share an edge outright (surfaced sewing two real mesh-derived candidate faces from `kof_ii_engine_cover.stl`). `IntegrationOrder` correctly reads the pcurve's type via `BAC.GetType()` (the curve-on-surface-aware virtual dispatch) but then re-derives the pole count by hand from `BAC.Curve().Curve()` — a completely different, non-virtual accessor that's null whenever there's no 3D curve; down-casting that null handle and calling `->NbPoles()` on it crashes. A from-scratch synthetic degenerate edge (`BRep_Builder` + a hand-built `Geom2d_BSplineCurve` pcurve on a plane, no 3D curve) reproduces the identical crash trace — no real fixture needed to pin the mechanism. **Fixed in v1.12.8**: bridge's small-edge scan now skips degenerate edges outright (`OCCTShapeAnalyze`, immediate fix, any xcframework — a degenerate edge's zero 3D extent isn't a "small edge" defect to flag); kernel patch also carried (`Scripts/patches/0006-*`, xcframework rebuilt): `IntegrationOrder` now calls the adaptor's own (correctly-dispatching) `BAC.NbPoles()` instead. Filed upstream as [OCCT#1381](https://github.com/Open-Cascade-SAS/OCCT/issues/1381) (repro) / [OCCT#1382](https://github.com/Open-Cascade-SAS/OCCT/pull/1382) (fix). #318.
- Three more upstream crash/hang fixes carried proactively (audit of OCCT PRs since our p1 baseline, not discovered via our own crashes — #323, v1.12.9): (1) `ShapeAnalysis_FreeBounds::connectWiresToWiresImpl` (the same helper as the #310 fix above) left a stale `lwire` index when a skipped-loop candidate wire had zero edges (e.g. a wire wrapping a single internal-orientation edge), so the outer loop's termination check never fired and it read invalid memory — `Scripts/patches/0007-*`, backports open third-party [OCCT#1331](https://github.com/Open-Cascade-SAS/OCCT/pull/1331) (fixes OCCT#1330, the "still open" sibling bug noted above). (2) `Geom_BSplineCurve::PeriodicNormalization` used an O(N) `while`-loop to bring an out-of-range parameter back into a periodic curve's range, and could infinite-loop outright once the parameter's magnitude vastly exceeded the period (floating-point no-op on `Parameter -= Period`) — hung `BRepAlgoAPI_Section` on cylindrical shapes; `Scripts/patches/0008-*`, backports merged [OCCT#1329](https://github.com/Open-Cascade-SAS/OCCT/pull/1329) (rewritten to O(1)). (3) `StepData_StepWriter::AddString` looped forever writing a single unbroken raw string longer than the 72-char line buffer (`StepLong`) — no amount of flushing ever made room; `Scripts/patches/0009-*`, backports open [OCCT#1318](https://github.com/Open-Cascade-SAS/OCCT/pull/1318) (splits the token across lines instead), regression test `STEPWriterOversizedNameTests` (`OCCTIOTests`) via `Shape.writeSTEP(to:name:)` with a >72-char name.
- `BOPAlgo_ArgumentAnalyzer`'s self-interference phase (backs `Shape.isSelfIntersecting(hardTimeout:)`) could run unboundedly past its `hardTimeout:` deadline on a pathological artifact — 619s+ CPU against a 30s deadline, never returning. Two compounding causes: (1) `Intf_Interference::Insert` called `Intf_TangentZone::GetPoint(Index)` inside a nested comparison loop; `GetPoint` is O(n) per call (the backing `NCollection_Sequence` has no O(1) indexed access), so every comparison paid that cost again — profiling attributed ~80% of runtime to `NCollection_BaseSequence::Find`. (2) the phase never polled its cooperative progress indicator below `BOPAlgo_CheckerSI::CheckFaceSelfIntersection`, so a caller's timeout could only fire between whole-face checks, not within one — exactly where the artifact got stuck. **Fixed in v1.15.1** (`Scripts/patches/0010-*`, xcframework rebuilt): `Intf_TangentZone::Points()` caches a true random-access array per zone (O(1) lookup); `Intf_Interference::SetBreaker` (thread-local, RAII-scoped via `Intf_InterferenceBreakerScope`) lets `Insert()` poll every 256 calls and abort by throwing `Standard_Failure`, wired up in `BOPAlgo_CheckerSI`'s self-intersect functor only when single-threaded (an exception from an `OSD_Parallel::For` worker thread would risk `std::terminate()`). Verified: a 0.5s deadline now returns in 0.547s and a 30s deadline in 30.1s, correct results throughout. Reproducer at [`Scripts/repro/319-selfintersection`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/319-selfintersection); filed upstream as [OCCT#1385](https://github.com/Open-Cascade-SAS/OCCT/issues/1385) (repro) / [OCCT#1386](https://github.com/Open-Cascade-SAS/OCCT/pull/1386) (fix, CI green on all 3 platforms). #319.
- `ShapeUpgrade_UnifySameDomain::IntUnifyFaces` (backs `UnifySameDomainBuilder.build()`) SIGSEGV'd (Address 0, uncatchable in-process) on a real mesh-sewn solid — found via OCCTReconstruct#194, minimized to a standalone, deterministic OCCTSwift-only reproducer. `IntUnifyFaces` (and its file-local `SplitWire` helper) disambiguate between multiple candidate next-edges at a branching vertex by comparing each candidate's pcurve tangent direction on the current reference face; three call sites fetch that pcurve via `BRep_Tool::CurveOnSurface(edge, refFace, first, last)` and dereference it immediately (`->D1(...)`/`->Value(...)`) with no `IsNull()` check — unlike every other `CurveOnSurface` call site in the same file, which do check. `CurveOnSurface` legitimately returns a null handle when an edge has no pcurve on the given face — routine for a raw mesh-sewn solid at a vertex shared by more than two edges. Confirmed via a debug (`-g -O0`) single-TU override-link + `lldb bt`: resolves precisely to `ShapeUpgrade_UnifySameDomain.cxx:4003` (`aPCurve->D1(...)`), reached via `IntUnifyFaces` → `UnifyFaces` → `Build`. **Fixed in v1.15.8** (`Scripts/patches/0013-*`, xcframework rebuilt): all five unguarded sites (three in `IntUnifyFaces`, two in `SplitWire`) now guard with `IsNull()`, following the file's own established pattern — a missing pcurve on a candidate edge means "skip it, not a rankable direction"; a missing pcurve on the current edge falls back to treating all candidates as equally likely, same as the existing single-candidate shortcut. Reproducer at [`Scripts/repro/348-unify-null-pcurve`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/348-unify-null-pcurve); filed upstream as [OCCT#1391](https://github.com/Open-Cascade-SAS/OCCT/issues/1391) (repro) / [OCCT#1392](https://github.com/Open-Cascade-SAS/OCCT/pull/1392) (fix). #348.

### Carrying OCCT source patches

`Scripts/patches/*.patch` are upstream-bound fixes applied to `occt-src` (idempotently) by `build-occt.sh` before each cmake build. Drop a `git diff` (`-p1`, prefixes `a/`,`b/`) in that dir to carry a new one. Existing build trees (`occt-build-*`) pin a stale macOS SDK sysroot and can no longer incrementally compile — a fresh `cmake` configure (clean build dir) is required to pick up patches.

## Release Process

Each release adds ~100 new operations following this strict order:

1. Ground truth C++ test at `/tmp/occt_vXX_test.mm` — compile and run
2. C bridge declarations + implementations
3. `swift build` — zero errors
4. Swift wrappers
5. `swift build` — zero errors
6. Tests
7. `swift test` — all pass
8. **Update docs — MANDATORY every release (OKF release discipline), even for a one-method change:**
   - `README.md` (table counts, feature bullets, totals)
   - `docs/API_REFERENCE.md` (op-count tables + Total + Swift→OCCT mapping rows for the new ops)
   - `docs/CHANGELOG.md` (the release entry)
   - any `docs/reference/<Type>.md` page covering a changed type
   - `///` doc comments with a fenced ```swift``` snippet on every new public API (context7 harvests these)
9. `git commit`, `git push`, `git tag vX.Y.Z`, `gh release create`

> No release ships with stale docs. If an API surface changed, the docs change in the **same** release.

## Workflow Automations

### Slash Commands

- **`/audit-occt`** — Scans all 6,612 OCCT headers against `OCCTBridge.h` and produces a categorized gap report with Tier 1/2/3 priorities and a recommended next-release scope. Use this to plan what to wrap next.
- **`/ground-truth`** `<version> <Class1> <Class2> ...` — Generates `/tmp/occt_v{XX}_test.mm`, compiles it against the xcframework, runs it, and reports pass/fail. Use this as step 1 of the release process.

### Subagents (`.claude/agents/`)

- **`occt-header-analyzer`** — Reads OCCT `.hxx` headers for specified classes. Extracts constructors, methods, Handle usage, and dependencies. Proposes C bridge function signatures following project conventions. Flags abstract classes and complex hierarchies.
- **`bridge-generator`** — Takes header analysis and generates all four code artifacts: bridge header declarations, bridge Obj-C++ implementations, Swift wrappers, and Swift Testing tests. Encodes exact patterns from the codebase.

### Typical Wrapping Workflow

1. `/audit-occt` → pick ~20-25 operations for the next release
2. `/ground-truth v51 Class1 Class2 ...` → verify OCCT APIs work
3. Invoke `occt-header-analyzer` agent on the class list → get API analysis
4. Invoke `bridge-generator` agent with the analysis → get code artifacts
5. Insert generated code, `swift build`, `swift test`, iterate on failures
6. Update README.md, commit, tag, release

## Documentation Standards

### docs/ Structure

```
docs/
├── API_REFERENCE.md          # Full operation-by-OCCT-class mapping (generated from README)
├── CHANGELOG.md              # Release history (every version, concise)
├── architecture/overview.md  # Three-layer design, memory model, file layout
├── guides/
│   ├── adding-features.md    # Step-by-step: bridge header → impl → Swift → test
│   ├── building-occt.md      # Rebuild OCCT.xcframework from source
│   └── occt-concepts.md      # B-Rep topology, handles, shapes primer
├── integration-tests.md      # Design, CAM, stress, and regression test plans
├── naming-conventions.md     # Bridge and Swift naming patterns
├── occt-upgrades.md          # Breaking changes per OCCT version (rc3→rc4→rc5→8.0.0 GA)
├── occtswift-wrapping-gaps.md # What's wrapped, what's not, and why
└── thread-safety.md          # OCCTSerial mutex, parallel execution
```

### Rules

- **README.md** stays concise (~175 lines). Detailed content goes in `docs/`.
- **No stale plans or proposals** — delete docs when the work is done or abandoned.
- **No version-specific release notes** as separate files — everything goes in `CHANGELOG.md`.
- **No duplicate content** — one canonical location per topic. Link, don't copy.
- **Keep docs current** — when upgrading OCCT or changing architecture, update the relevant doc in the same commit.
- **Operation counts and version numbers** must match reality. Grep for stale numbers when releasing.
- **Code reviews and handoff docs** are ephemeral — don't commit them.
- **Document with a runnable Swift snippet so context7 indexes it.** Our Swift API is indexed on
  context7 as `/gsdali/occtswift` (verified #210) — and context7 ranks on **code-example density**.
  So when wrapping or changing a public API, give it a `///` summary + parameter docs + at least one
  fenced ```` ```swift ```` snippet (the cookbook pages under `docs/guides/cookbook/` are the richest
  source; high-traffic types should also carry an in-source snippet). Snippets are what context7
  harvests — terse one-line summaries don't surface in answers.

### What Goes Where

| Content | Location |
|---------|----------|
| Quick start, ecosystem links, examples | `README.md` |
| Full API tables (Swift → OCCT mapping) | `docs/API_REFERENCE.md` |
| How the bridge works | `docs/architecture/overview.md` |
| How to add new operations | `docs/guides/adding-features.md` |
| OCCT version migration notes | `docs/occt-upgrades.md` |
| What's wrapped and what isn't | `docs/occtswift-wrapping-gaps.md` |
| Thread safety guidance | `docs/thread-safety.md` |
| Release-by-release history | `docs/CHANGELOG.md` |

## User Directives

- Wrap **everything** — comprehensive wrapper, leave nothing out
- Each release should be ~100 new operations
- Infinite OCCT surfaces must be trimmed before converting to BSpline
