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
  entry (#341, mitigated) and #344/#345 (the two crashes, still uncharacterized). A single domain
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
- ~~Container-overflow in NCollection on arm64 macOS~~ — **this claim was never characterized and does not hold up.** Investigated for #341 (2026-07-21) using the #298 TSan protocol (minimal-module ThreadSanitizer build of V8_0_0_p1 + all 10 carried patches): `FoundationClasses`+`ModelingData`+`ModelingAlgorithms` stress scenarios (concurrent create/fuse/fillet, independent meshing) are clean except the already-known benign `BOPAlgo_InitMessages` lazy-init race. No NCollection race reproduced anywhere. Re-enabled the 3 suites in `Tests/OCCTStressTests/StressConcurrencyTests.swift` that had been `.disabled()` under this same unevidenced claim (some since ~v0.51.0) — 25/25 clean runs. **A real, different, previously-undetected race was found instead**: `XCAFDoc_ShapeTool::theAutoNaming`, a process-global `static bool` that `RWMesh_CafReader::fillDocument()` (the shared base of `RWObj_CafReader` and `RWGltf_CafReader` — reachable via OBJ **and** glTF import, and PLY export via `AddShape`) saves/mutates/restores with zero synchronization; `XCAFDoc_ShapeTool::AddShape` reads the same flag. Same failure class as #298 (unsynchronized global save/modify/restore), but cosmetic (wrong auto-naming) rather than geometric. **Mitigated in this release**: every OBJ/glTF/PLY CAF bridge function now serializes on `meshCafMutex()` (`OCCTBridge_IO.mm`) — bridge-only fix, no kernel patch/xcframework rebuild needed yet; not filed upstream. See [`Scripts/repro/341-meshcaf/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/341-meshcaf) for the TSan reproducer and full writeup. #341. The two hard crashes (SIGSEGV/SIGABRT) observed empirically in ~2/20 full-suite parallel `swift test` runs during this investigation remain uncharacterized and are filed separately: #344 (SIGSEGV, garbage fault address, immediately after two concurrent OBJ imports — possibly the same `theAutoNaming` race in a rarer timing window, unconfirmed) and #345 (SIGABRT, essentially no localizing evidence). Correction: an earlier version of this entry blamed the SIGABRT on a "File was not written with this version of the topology" message seen nearby in the log — that message is routine, expected output from two intentional negative tests (`Tests/OCCTIOTests/OCCTIOTests.swift`'s `BREPStringSerializationTests`) and appears in every run including clean ones; it has no connection to either crash.
- `LocOpe_SplitDrafts` throws on incompatible geometry — always wrap `Perform()` in try-catch in bridge
- `BRepOffsetAPI_ThruSections` (loft) SIGSEGV'd (null deref, "Address 8") on mismatched closed profiles — `BRepFill_CompatibleWires::SameNumberByPolarMethod` over-advanced an unguarded correspondence-list iterator. It's an OS signal, so the bridge `catch(...)` cannot save it. **Fixed upstream in OCCT 8.0.0p1** (Open-Cascade-SAS/OCCT#1298, OCCTSwift #176/#178); the previously-carried `Scripts/patches/0001-*` was dropped — the current p1 xcframework has the guard natively (regression test "Loft polar-method SIGSEGV regression (#176)" passes against it). Note: `OCC_CATCH_SIGNALS` is inert in our build (no `OCC_CONVERT_SIGNALS`) — do not rely on it for signal safety; OS signals raised inside OCCT (e.g. #234) are still uncatchable in-process.
- `ShapeAnalysis_FreeBounds` (backs `Shape.freeBoundsClosedWires`/`freeBoundsClosedCount`/`freeBoundsOpenWires`, and `Shape.freeBounds`) used to SIGSEGV (uncatchable) on certain shapes with multiple free-boundary components — isolated via AddressSanitizer to `connectWiresToWiresImpl`'s empty-input early return (`ShapeAnalysis_FreeBounds.cxx`) leaving its `owires` out-parameter uninitialized (null), which later crashes `NCollection_HSequence::Append`. Minimally reproducible with just two disjoint planar faces in one compound; not a simple loop-count threshold (150+ loops can be fine, 2 can crash) — depends only on whether any single component's boundary closes with zero edges left over. **Fixed upstream in v1.12.6** (`Scripts/patches/0004-*`, xcframework rebuilt): `connectWiresToWiresImpl` now initializes `owires` to an empty sequence before its early return. #310, upstream repro filed as Open-Cascade-SAS/OCCT#1376, fix as [OCCT#1377](https://github.com/Open-Cascade-SAS/OCCT/pull/1377); sibling `Standard_OutOfRange` bug in the same file, OCCT#1330, was a separate, unrelated defect in the same function — also now carried, see the `0007` entry below.
- `ShapeFix_Face::FixPeriodicDegenerated` (invoked from `Shape.face(from:boundary:)`/`face(from:boundary:innerWires:)` and the `FaceFixer` API whenever a face's sole boundary wire is a single closed edge belting a `Surface.cone`'s full period, apex outside the wire's V range — e.g. a rivet/boss-rim seam fit as one periodic curve) used to SIGSEGV (uncatchable) on the ordinary `ShapeFix_Face fixer(face); fixer.Perform();` construction — a null-Context dereference at the function's final `Context()->Replace(myFace, myResult)`, the only one of twelve such call sites in the file missing the `if (!Context().IsNull())` guard every sibling uses. A standalone circle repro is negative (`wireFromEdges` alone never reaches `FixPeriodicDegenerated`); the minimal repro needs the wire trimmed to a periodic conical surface via `face(from:boundary:)`. **Fixed in v1.12.7**: bridge now calls `fixer.SetContext(new ShapeBuild_ReShape)` before `Perform()` at all three `ShapeFix_Face` call sites (immediate fix, any xcframework); kernel patch also carried (`Scripts/patches/0005-*`, xcframework rebuilt) and filed upstream as [OCCT#1378](https://github.com/Open-Cascade-SAS/OCCT/issues/1378) (repro) / [OCCT#1380](https://github.com/Open-Cascade-SAS/OCCT/pull/1380) (fix). #317.
- `BRepGProp_EdgeTool::IntegrationOrder` (invoked from `BRepGProp::LinearProperties`, which backs `Shape.analyze(tolerance:)`'s small-edge scan) used to SIGSEGV (uncatchable) on an edge whose sole geometry is a Bezier/BSpline-type curve-on-surface pcurve (no 3D curve) — the common shape of a degenerate edge `BRepBuilderAPI_Sewing` produces reconciling near-coincident vertices between two faces that don't share an edge outright (surfaced sewing two real mesh-derived candidate faces from `kof_ii_engine_cover.stl`). `IntegrationOrder` correctly reads the pcurve's type via `BAC.GetType()` (the curve-on-surface-aware virtual dispatch) but then re-derives the pole count by hand from `BAC.Curve().Curve()` — a completely different, non-virtual accessor that's null whenever there's no 3D curve; down-casting that null handle and calling `->NbPoles()` on it crashes. A from-scratch synthetic degenerate edge (`BRep_Builder` + a hand-built `Geom2d_BSplineCurve` pcurve on a plane, no 3D curve) reproduces the identical crash trace — no real fixture needed to pin the mechanism. **Fixed in v1.12.8**: bridge's small-edge scan now skips degenerate edges outright (`OCCTShapeAnalyze`, immediate fix, any xcframework — a degenerate edge's zero 3D extent isn't a "small edge" defect to flag); kernel patch also carried (`Scripts/patches/0006-*`, xcframework rebuilt): `IntegrationOrder` now calls the adaptor's own (correctly-dispatching) `BAC.NbPoles()` instead. Filed upstream as [OCCT#1381](https://github.com/Open-Cascade-SAS/OCCT/issues/1381) (repro) / [OCCT#1382](https://github.com/Open-Cascade-SAS/OCCT/pull/1382) (fix). #318.
- Three more upstream crash/hang fixes carried proactively (audit of OCCT PRs since our p1 baseline, not discovered via our own crashes — #323, v1.12.9): (1) `ShapeAnalysis_FreeBounds::connectWiresToWiresImpl` (the same helper as the #310 fix above) left a stale `lwire` index when a skipped-loop candidate wire had zero edges (e.g. a wire wrapping a single internal-orientation edge), so the outer loop's termination check never fired and it read invalid memory — `Scripts/patches/0007-*`, backports open third-party [OCCT#1331](https://github.com/Open-Cascade-SAS/OCCT/pull/1331) (fixes OCCT#1330, the "still open" sibling bug noted above). (2) `Geom_BSplineCurve::PeriodicNormalization` used an O(N) `while`-loop to bring an out-of-range parameter back into a periodic curve's range, and could infinite-loop outright once the parameter's magnitude vastly exceeded the period (floating-point no-op on `Parameter -= Period`) — hung `BRepAlgoAPI_Section` on cylindrical shapes; `Scripts/patches/0008-*`, backports merged [OCCT#1329](https://github.com/Open-Cascade-SAS/OCCT/pull/1329) (rewritten to O(1)). (3) `StepData_StepWriter::AddString` looped forever writing a single unbroken raw string longer than the 72-char line buffer (`StepLong`) — no amount of flushing ever made room; `Scripts/patches/0009-*`, backports open [OCCT#1318](https://github.com/Open-Cascade-SAS/OCCT/pull/1318) (splits the token across lines instead), regression test `STEPWriterOversizedNameTests` (`OCCTIOTests`) via `Shape.writeSTEP(to:name:)` with a >72-char name.
- `BOPAlgo_ArgumentAnalyzer`'s self-interference phase (backs `Shape.isSelfIntersecting(hardTimeout:)`) could run unboundedly past its `hardTimeout:` deadline on a pathological artifact — 619s+ CPU against a 30s deadline, never returning. Two compounding causes: (1) `Intf_Interference::Insert` called `Intf_TangentZone::GetPoint(Index)` inside a nested comparison loop; `GetPoint` is O(n) per call (the backing `NCollection_Sequence` has no O(1) indexed access), so every comparison paid that cost again — profiling attributed ~80% of runtime to `NCollection_BaseSequence::Find`. (2) the phase never polled its cooperative progress indicator below `BOPAlgo_CheckerSI::CheckFaceSelfIntersection`, so a caller's timeout could only fire between whole-face checks, not within one — exactly where the artifact got stuck. **Fixed in v1.15.1** (`Scripts/patches/0010-*`, xcframework rebuilt): `Intf_TangentZone::Points()` caches a true random-access array per zone (O(1) lookup); `Intf_Interference::SetBreaker` (thread-local, RAII-scoped via `Intf_InterferenceBreakerScope`) lets `Insert()` poll every 256 calls and abort by throwing `Standard_Failure`, wired up in `BOPAlgo_CheckerSI`'s self-intersect functor only when single-threaded (an exception from an `OSD_Parallel::For` worker thread would risk `std::terminate()`). Verified: a 0.5s deadline now returns in 0.547s and a 30s deadline in 30.1s, correct results throughout. Reproducer at [`Scripts/repro/319-selfintersection`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/319-selfintersection); filed upstream as [OCCT#1385](https://github.com/Open-Cascade-SAS/OCCT/issues/1385) (repro) / [OCCT#1386](https://github.com/Open-Cascade-SAS/OCCT/pull/1386) (fix, CI green on all 3 platforms). #319.

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
