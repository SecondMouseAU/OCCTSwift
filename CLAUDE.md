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
`Misc`, `Modeling`, `ShapeHealing`, `Stress`, `Surface`, `Thread`, `TopologyGraph`, `Topology`, `XCAF`.

- **Add a new suite** to the domain target that best matches it (e.g. a fillet suite → `OCCTModelingTests`,
  a `Curve2D` suite → `OCCTGeom2dTests`). If nothing fits, use `OCCTMiscTests`. Each target is a separate
  module with its own `@testable import OCCTSwift`; the only shared helper is `SIMD3.normalized` (redefine
  it in the target if needed).
- **Focused compile** (the point of the split): `swift build --target OCCTThreadTests` type-checks just
  that module in ~3 s — never touches the other domains.
- **Focused run:** `swift test --filter <StructName>` (the filter matches the test *struct* name, e.g.
  `Issue187`, not the `@Suite("...")` display string). `swift test` still runs everything.
- The full suite remains prone to the non-deterministic NCollection arm64 SEGV under parallel execution
  (see Known OCCT Bugs); a single domain target rarely trips it.

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
- Container-overflow in NCollection on arm64 macOS — pre-existing OCCT race condition that manifests as non-deterministic SEGV under parallel test execution
- `LocOpe_SplitDrafts` throws on incompatible geometry — always wrap `Perform()` in try-catch in bridge
- `BRepOffsetAPI_ThruSections` (loft) SIGSEGV'd (null deref, "Address 8") on mismatched closed profiles — `BRepFill_CompatibleWires::SameNumberByPolarMethod` over-advanced an unguarded correspondence-list iterator. It's an OS signal, so the bridge `catch(...)` cannot save it. **Fixed upstream in OCCT 8.0.0p1** (Open-Cascade-SAS/OCCT#1298, OCCTSwift #176/#178); the previously-carried `Scripts/patches/0001-*` was dropped — the current p1 xcframework has the guard natively (regression test "Loft polar-method SIGSEGV regression (#176)" passes against it). Note: `OCC_CATCH_SIGNALS` is inert in our build (no `OCC_CONVERT_SIGNALS`) — do not rely on it for signal safety; OS signals raised inside OCCT (e.g. #234) are still uncatchable in-process.

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
