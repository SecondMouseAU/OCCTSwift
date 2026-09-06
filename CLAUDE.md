# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**The rules live in `okf/`; this file is the working summary.** Where a section here points at an
`okf/policies/` or `okf/references/` page, that page is canonical and this file is the short form.
A rule restated here in full is a copy with no update path, which is how the version of this file
that stood until 2026-09-07 grew to 159 KB, 70% of it Known OCCT Bugs narrative now held in
[`okf/references/known-occt-bugs.md`](okf/references/known-occt-bugs.md).

## Project Summary

OCCTSwift is a comprehensive Swift wrapper for OpenCASCADE Technology (OCCT) 8.0.1. It exposes B-Rep solid modeling capabilities to Swift for macOS (arm64, v12+) and iOS (arm64, v15+) via a three-layer architecture: Swift public API → Objective-C++ bridge (C functions) → OCCT C++ library. Uses Swift 6 language mode (strict concurrency).

**One OCCT version is in play.** `Scripts/build-occt.sh` builds `V8_0_1` and `Package.swift` pins
the `v3.0.0` release asset, which is that same `V8_0_1` plus the carried patches that existed when
it was built. `Scripts/patches/` holds more than the asset does, and any patch the asset lacks is
exercised by **no CI job**, because `build-and-test` resolves the asset rather than building from
source. Before trusting "the fix is in the kernel", run
`ls Scripts/patches/*.patch | wc -l` against the count in `Package.swift`'s manifest comment, and
read [`okf/policies/pinned-kernel-patch-check.md`](okf/policies/pinned-kernel-patch-check.md) for
why the count is necessary and not sufficient, and
[`okf/references/carried-occt-patches.md`](okf/references/carried-occt-patches.md) for the current
divergence (twenty-two on disk, seventeen pinned, as of 2026-09-07) and what each unpinned patch
leaves exposed. A divergence with a written reason is expected; one without is a finding.

## Build & Test Commands

```bash
swift build                          # Build the package
swift build --target OCCTThreadTests # Focused compile: just one domain's tests (~3s), see "Test Layout"
swift test                           # Run all tests
swift test --filter "Issue187"       # Run suites whose struct name matches (matches the type, not @Suite title)
swift run OCCTTest                   # Run test executable
Scripts/tsan-stress.sh all           # ThreadSanitizer gate: REQUIRED for concurrency-touching changes (see docs/thread-safety.md)
Scripts/format-bridge.sh             # clang-format every enforced Sources/OCCTBridge file in place
Scripts/format-bridge.sh --check     # ...or just report, which is exactly what CI and the hook run
```

**Run `Scripts/format-bridge.sh` after any edit to a bridge `.h`/`.mm`.** All 33 bridge files are
enforced (`Scripts/style-manifest-bridge.txt` is empty), and OCCT's style aligns consecutive
declarations and assignments, so two ordinary new locals in a row are a violation unless the tool
wrote them. Hand-aligning is not a substitute. The version is pinned in
`Scripts/clang-format-version.txt`; a clang-format on a different major is refused, since 21.1.8
and 22.1.8 were measured to disagree on 10 of the 33 files. `Scripts/install-clang-format.py` gets
the pinned version onto a machine with no pip or venv; see
[`docs/guides/clang-format-setup.md`](docs/guides/clang-format-setup.md).

### Static Gate Scripts

Eight gates, four censuses and one merge-history audit, all pure Python over the repo's own text.
No OCCT, no build, no network, ~3s for the lot (a bare `census-unmeasured-values.py` run is ~13s).
CI runs every gate, plus every `--self-test` including the censuses', in `ci.yml`'s `gate-scripts`
job, a **required status check on `main`**. Each gate exits 1 on a defect and 0 when clean; a census
exits 0 always, so CI runs only its `--self-test`. The rules behind the list, the gate/census
distinction, the pre-commit hook and its one deliberate divergence from CI are in
[`okf/policies/static-gates.md`](okf/policies/static-gates.md); the ruleset rules (never give the
job a `name:` key, never require a check that has not yet reported, `main` takes PRs only) are in
[`okf/policies/required-status-checks.md`](okf/policies/required-status-checks.md).

```bash
python3 Scripts/check-bridge-index.py            # OCCTBridge.h's class → symbol index: stale / misfiled entries
python3 Scripts/check-null-handle-guards.py      # every bridge fn guards the Handle, not just the pointer
python3 Scripts/check-docs-defaults.py           # every default docs/reference/ restates matches its declaration
python3 Scripts/check-docs-existence.py          # every symbol docs/ documents as current still exists in Sources (#802)
python3 Scripts/check-borrowed-handles.py        # no struct/enum stores an OCCT*Ref it has no deinit to release (#965)
python3 Scripts/derive-bridge-header-split.py --verify  # every declaration sits in the header its .mm owns (#673)
python3 Scripts/derive-gdt-enums.py --verify      # the GD&T enums still match the pinned XCAFDimTolObjects headers (#996)
python3 Scripts/count-operations.py              # README + API_REFERENCE + docs/index.md totals match the derived count
python3 Scripts/census-unmeasured-values.py      # CENSUS, not a gate: values returned as measurements that were never computed (#726)
python3 Scripts/census-doc-occt-attribution.py   # CENSUS, not a gate: docs attributing a method to an OCCT class its bridge fn never reaches (#928)
python3 Scripts/census-arguments-tuple-shapes.py # CENSUS, not a gate: @Test(arguments:) elements whose layout trips the toolchain defect (#1057)
python3 Scripts/census-comment-staleness.py      # CENSUS, not a gate: comments naming a symbol/flag/patch that no longer resolves (#872)
python3 Scripts/check-changelog-transcription.py # REPORT, not a gate yet: merges that landed with no CHANGELOG entry (#742)
```

Run a script's `--self-test` whenever you change it: three gates were confidently wrong while
reporting all clear (#618, #624/#630, #626). `count-operations.py` has no `--self-test` and exits 2
on the option. Four scripts exit 2 if run from anywhere but the repo root (#625).

**Optional pre-commit hook**: `ln -s ../../Scripts/git-hooks/pre-commit .git/hooks/pre-commit` in
the main checkout, or `git config core.hooksPath Scripts/git-hooks` in a linked worktree (its
`.git` is a file, so the symlink fails). CI is the authority; the hook is the preview.

### Compile a Ground Truth C++ Test

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/<issue>/probe.mm -o /tmp/occt_probe
/tmp/occt_probe
```

Put the probe under `Scripts/repro/<issue>/` rather than `/tmp`, so the evidence survives the
session that produced it.

### Verify OCCT Symbols

```bash
nm -C Libraries/OCCT.xcframework/macos-arm64/libOCCT-macos.a 2>/dev/null | grep "ClassName" | head -5
```

### OCCT Reference Docs

Look OCCT signatures up, never recall them: the `context` MCP (`occt`, `occt-refman`, `occtswift`)
first, per [`okf/policies/context-first.md`](okf/policies/context-first.md); context7's
`/open-cascade-sas/occt` for the developer guides (its snapshot is the occt-7.9 branch, so for
version-sensitive details the pinned headers in `Libraries/OCCT.xcframework/.../Headers` are the
source of truth). It documents the upstream C++ API the bridge wraps, not the Swift surface.

## Architecture

```
Sources/OCCTSwift/          Swift public API (Shape, Wire, Surface, Face, Edge, Curve3D, Mesh, etc.)
Sources/OCCTBridge/include/ C function declarations (16 files: OCCTBridge.h umbrella + 15 per-domain headers, #395)
Sources/OCCTBridge/src/     Objective-C++ implementations (one per domain, matching the headers,
                             except Modeling: split into 12 OCCTBridge_Modeling_<Bucket>.mm files
                             by OCCT subsystem under one shared OCCTBridge_Modeling.h, #396)
Libraries/OCCT.xcframework  Pre-built OCCT static library (arm64 macOS/iOS)
Tests/OCCT<Domain>Tests/    Per-domain Swift Testing targets (see "Test Layout")
Scripts/build-occt.sh       Builds OCCT.xcframework from source
```

### Handle-Based Memory Management

Opaque handle types (`OCCTShapeRef`, `OCCTWireRef`, `OCCTFaceRef`, `OCCTEdgeRef`, `OCCTMeshRef`) are typedef'd pointers. Swift classes wrap these handles and call the corresponding `Release` function in `deinit`. Every bridge function that creates an OCCT object must have a matching `Release` function.

### Adding a New Wrapped Operation

1. **Bridge header** (the matching `Sources/OCCTBridge/include/OCCTBridge_<Domain>.h`): Add C function declaration
2. **Bridge impl** (the matching `Sources/OCCTBridge/src/OCCTBridge_<Domain>.mm`): Add Objective-C++ implementation calling OCCT C++ API
3. **Swift wrapper** (appropriate `.swift` file): Add public method/static factory
4. **Test**: Add `@Suite`/`@Test` to the matching `Tests/OCCT<Domain>Tests/` target (see "Test Layout")
5. **Docs**, in the same PR, per [`okf/policies/docs-current.md`](okf/policies/docs-current.md)

The full loop is in [`docs/guides/adding-features.md`](docs/guides/adding-features.md). Ground-truth
a new OCCT class first with `/ground-truth`.

**Guard the handle, not just the pointer.** A function taking an `OCCTCurve3DRef` /
`OCCTCurve2DRef` / `OCCTSurfaceRef` starts with
`if (!x || x->curve.IsNull()) return <the fallback the catch below uses>;` wherever the OCCT call
dereferences the handle, since 36 of the 57 such entry points crash uncatchably on a null one. A
function taking an `OCCTShapeRef`/`OCCTWireRef`/`OCCTEdgeRef`/`OCCTFaceRef` guards with
`occtShapeIsPresent(x)` or `occtShapeIsType(x, TopAbs_T)` before any of the ten `TopoDS_Shape`
members that dereference `myTShape`, and before any of the 17 measured OCCT entry points that
dereference the shape for you (`BRep_Tool::Curve` and family, the `BRepAdaptor_Curve` constructors,
`ShapeFix_Shape::Perform`). The guard returns the refusal the function already gives a wrong-typed
input, never a value that reads as a measurement. `check-null-handle-guards.py` enforces both;
where the guard is required, where it is noise, the alias shapes the checker knows and the ones it
is blind to are in [`okf/policies/null-handle-guards.md`](okf/policies/null-handle-guards.md).

## Naming Conventions

- Bridge functions: `OCCTShape...`, `OCCTWire...`, `OCCTFace...`, `OCCTEdge...`
- Wire-to-shape conversion: `OCCTShapeFromWire()` (NOT `OCCTWireToShape`)
- Check enum values: `OCCTCheckNoError` (NOT `OCCTCheckStatusNoError`)
- `vertices()` is a method, not a property
- Swift factory methods are static: `Shape.box()`, `Wire.rectangle()`
- Fallible operations return optionals, not force-unwrapped values

## Test Layout

Tests are split into **per-domain test targets** (one Swift module each) so editing/compiling
one domain never recompiles the rest. Each is `Tests/OCCT<Domain>Tests/`, declared in `Package.swift`:

`Analysis`, `Curve`, `Drawing`, `Foundation`, `Geom2d`, `IO`, `Integration`, `Math`, `Mesh`,
`Misc`, `Modeling`, `ShapeHealing`, `Stress`, `Surface`, `Thread`, `BRepGraph`, `Topology`, `XCAF`.

- **Add a new suite** to the domain target that best matches it (e.g. a fillet suite → `OCCTModelingTests`,
  a `Curve2D` suite → `OCCTGeom2dTests`). If nothing fits, use `OCCTMiscTests`. Each target is a separate
  module with its own `@testable import OCCTSwift`; the only shared helper is `SIMD3.normalized` (redefine
  it in the target if needed).
- **Focused compile** (the point of the split): `swift build --target OCCTThreadTests` type-checks just
  that module in ~3 s, never touches the other domains.
- **Focused run:** `swift test --filter <StructName>` (the filter matches the test *struct* name, e.g.
  `Issue187`, not the `@Suite("...")` display string). `swift test` still runs everything.
- The full suite occasionally hits a timing flake under parallel execution: hardcoded temp paths
  in the `OCAF Save/Load` tests and the `Issue173AssemblySTEPTests` flake, neither a kernel bug.
  The hard crashes that used to accompany it (#341, #344, #345, #349, #353) are root-caused and
  fixed; see the Known OCCT Bugs reference. A single domain target rarely trips anything.

## Test Conventions

- Framework: Swift Testing (`@Suite`, `@Test`, `#expect`)
- **Never force-unwrap in `#expect`**: Swift Testing does NOT short-circuit. Use:
  ```swift
  if let r = result { #expect(r.isValid) }
  ```
  Not: `#expect(result != nil); #expect(result!.isValid)`
- Edge indices may vary across runs, iterate edges to find a working one when testing edge-specific operations
- Wrap OCCT calls that may throw `StdFail_NotDone` in try-catch on the C bridge side
- **Prove the test fails.** Every new test, and every new `--self-test` case, is run once with its
  subject broken: inject the defect, confirm the failure, restore, confirm the pass, report both.
  See [`okf/policies/prove-the-test-fails.md`](okf/policies/prove-the-test-fails.md).
- **A `@Test(arguments:)` element pairing a reference-counted member with a builtin vector of 32
  bytes or more cannot be written at all** (#1057). `(String, SIMD3<Double>)` corrupts the Swift
  task allocator whatever the test body does: it crashes with an empty body, with a single case,
  under `.serialized`, and in a package with no OCCTSwift dependency, while
  `(SIMD3<Double>, SIMD3<Double>)` is clean. The process prints `freed pointer was not the last
  allocation`, and the SIGSEGV you may also see comes from OCCT's process-wide signal handler
  reporting a fault it did not raise. **It is a toolchain defect, not OCCT**, narrowed to a nested
  `async throws` function with an `isolated (any Actor)?` parameter, which is what the `@Test`
  macro expands to, reported as [swiftlang/swift#91639](https://github.com/swiftlang/swift/issues/91639).
  Debug-only; `-O` is clean. Both halves are necessary and the pair is not sufficient:
  `(String, simd_double3x3)` runs clean, so `census-arguments-tuple-shapes.py` reports `unknown`
  where it cannot resolve a named type. Write the cases as one test walking a list, and say in a
  comment why, since the workaround otherwise reads as a style choice somebody will later
  "clean up".

## Known OCCT Bugs

The record is [`okf/references/known-occt-bugs.md`](okf/references/known-occt-bugs.md): one row
per defect with its fix (carried patch, bridge guard, shipped in 8.0.1, or not a bug) and where the
full writeup lives (`Scripts/patches/README.md` for a carried patch, `Scripts/repro/<issue>/` for
the reproducer). What a bridge author needs without opening it:

- `BRepExtrema_ExtCC` crashes on parallel edges: `if (result.isParallel) { return result; }`
  before reading points. `Extrema_ExtCC::Points` itself over-reads on the same input (patch `0024`).
- `LocOpe_SplitDrafts::Perform()` throws on incompatible geometry: always `try`/`catch` it.
- `OCC_CATCH_SIGNALS` is inert in this build (no `OCC_CONVERT_SIGNALS`). An OS signal raised
  inside OCCT is uncatchable in-process, and so is a C++ exception that reaches the Swift boundary
  (#345), which is why every `gp_Dir`/`gp_Ax*`/`Geom_Direction` construction from caller doubles
  sits inside a `try`.
- `GeomAbs_G2` is never a valid order for `BRepFill_Filling`: curvature continuity is
  `GeomAbs_C1` (ordinal 2), whatever `BRepOffsetAPI_MakeFilling.hxx` says. Test any filling change
  on both a planar and a periodic support surface, since #430 was catchable on one and an
  uncatchable SIGSEGV on the other.
- `BRepOffsetAPI_ThruSections` takes `CreateRuled` for exactly two sections and `CreateSmoothed`
  for three or more, so a two-section test never reaches #913's array. `MakeSolid` cannot cap a
  non-planar section (#905); loft the wall, cap with `Shape.fill`, sew.
- `BRepAlgoAPI_BuilderAlgo` is General Fuse, a compound of split parts, not `BRepAlgoAPI_Fuse`'s
  merged solid; comparing the two is #367's mistake, not a kernel bug.
- `GeomPlate_MakeApprox::ApproxError()` and `MakeFilling::G0Error()` are not gates for "accepted
  an approximation unread"; both were tried and both broke correct results (#597).
- **Retire when the kernel is repinned**: the bridge-side arc-length subdivision
  (`occtAdaptorArcLength`, #603, redundant against patch `0021`), the datum lookup guard in
  `occtDocumentDatumObjectAt` (#1030, blocks a readable datum once `0029` is in), and the
  `Scripts/tsan.supp` lines for `TopoDS_TShape::myState` (`0030`). None of their tests can signal
  that they have outlived their fix.
- `OCCTShapeFuseMulti` runs with `SetRunParallel(false)`; re-enabling it is very likely safe (#369)
  and is a separate, open decision.

### Carrying OCCT source patches

`Scripts/patches/*.patch` are upstream-bound fixes applied to `occt-src` (idempotently) by
`build-occt.sh` before each cmake build. Drop a `git diff` (`-p1`, prefixes `a/`,`b/`) in that dir
to carry a new one; numbers are never reused. Existing build trees (`occt-build-*`) pin a stale
macOS SDK sysroot and can no longer incrementally compile, so a fresh `cmake` configure is required
to pick up patches. The lifecycle from GTest to upstream PR is
[`okf/policies/upstream-occt-patch-process.md`](okf/policies/upstream-occt-patch-process.md) and
[`okf/policies/upstream-occt-style.md`](okf/policies/upstream-occt-style.md).

**Check upstream's own recent activity before starting a kernel-defect investigation**, especially
anything touching caching, mutable or `static` state, or thread-safety. Maintainer dpasukhi is
running a systematic "Eliminate mutable static state" PR series, roughly one a day, and his blog
(`occt3d.com/blog/`) describes intended kernel architecture. Patch `0032` (#1371) shipped four days
after upstream fixed the same globals better and was retired unshipped. A five-minute
`gh pr list --repo Open-Cascade-SAS/OCCT --search "author:dpasukhi <keyword>"` first can save the
whole investigation.

## Release Process

**The rules live in `okf/policies/`.** This section says what a release involves and points at the
policy that owns each piece.

A release is a correctness release now, not "~100 new operations": that described the wrapping
phase. See [`docs/v4.0.0-plan.md`](docs/v4.0.0-plan.md) for the current scope; the operation count
is derived, never chosen: `python3 Scripts/count-operations.py`.

1. **Every PR is already merged and its docs already current**, per
   [`docs-current`](okf/policies/docs-current.md). If you are writing docs at release time, a PR
   skipped its own.
2. **Transcribe the CHANGELOG.** Entries were written in each PR body and transcribed at merge, per
   [`changelog-on-merge`](okf/policies/changelog-on-merge.md). At release you check the
   `## Unreleased` section is complete; `python3 Scripts/check-changelog-transcription.py` audits
   the merge history for entries that never landed.
3. **Assemble `docs/SEMVER.md`** from the `## SemVer impact` statement in every merged PR body, per
   [`semver-at-release`](okf/policies/semver-at-release.md). No PR touches that file.
4. **Pin the final kernel.** Re-point `Package.swift`'s `url:`/`checksum:` at the release asset,
   check the patch count per [`pinned-kernel-patch-check`](okf/policies/pinned-kernel-patch-check.md),
   and retire the bridge-side mitigations listed under Known OCCT Bugs above.
5. **Verify.** Full `swift test`, every gate with its `--self-test`, and `Scripts/tsan-stress.sh all`
   if anything touched concurrency.
6. **Counts.** `python3 Scripts/count-operations.py` must agree with README.md,
   `docs/API_REFERENCE.md` and `docs/index.md`. Never hand-edit a total to match. Two headlines
   are outside the gate (`docs/occtswift-wrapping-gaps.md`, `docs/integration-tests.md`); re-derive
   with `grep -rn 'operations' docs/ README.md`.
7. `git tag vX.Y.Z`, `gh release create`. `main` takes the release commit by PR like everything else.

## Workflow Automations

- **`/audit-occt`**: scans the OCCT headers against `OCCTBridge.h` and produces a categorized gap
  report with Tier 1/2/3 priorities. Use it to plan what to wrap next.
- **`/ground-truth`** `<version> <Class1> <Class2> ...`: generates, compiles and runs a C++ probe
  against the xcframework. Step 1 of wrapping a new class.
- **`/document-api`**: generates the `docs/reference/` page for an OCCTSwift type.
- Subagents in `.claude/agents/`: **`occt-header-analyzer`** (reads `.hxx` headers, proposes C
  bridge signatures) and **`bridge-generator`** (turns that analysis into header, impl, Swift
  wrapper and tests).

## Documentation Standards

`docs/index.md` is the map of `docs/`. The rules:

- **README.md** stays concise (~175 lines). Detailed content goes in `docs/`.
- **No stale plans or proposals**: delete docs when the work is done or abandoned.
- **No version-specific release notes** as separate files, everything goes in `CHANGELOG.md`.
- **No duplicate content**: one canonical location per topic. Link, don't copy. This file included.
- **Keep docs current**: when upgrading OCCT or changing architecture, update the relevant doc in the same commit.
- **Operation counts and version numbers** must match reality. Grep for stale numbers when releasing.
- **Code reviews and handoff docs** are ephemeral, don't commit them.
- **Document with a runnable Swift snippet so context7 indexes it.** Our Swift API is indexed on
  context7 as `/gsdali/occtswift` (verified #210), and context7 ranks on code-example density. When
  wrapping or changing a public API, give it a `///` summary, parameter docs and at least one fenced
  ```` ```swift ```` snippet; the cookbook pages under `docs/guides/cookbook/` are the richest source.
- **No em-dashes, no banned words**, per [`okf/policies/writing-style.md`](okf/policies/writing-style.md).

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
| Kernel defects, one row each | `okf/references/known-occt-bugs.md` |
| Carried patches, and which are pinned | `okf/references/carried-occt-patches.md` |
| How this repo works | `okf/policies/` |

## User Directives

- Wrap **everything**, comprehensive wrapper, leave nothing out
- Each release should be ~100 new operations
- Infinite OCCT surfaces must be trimmed before converting to BSpline
- Stay faithful to OCCT: a legitimate feature that isn't a direct wrap of an OCCT operation belongs
  in a downstream ecosystem package, not here, see
  [`okf/policies/scope-boundary.md`](okf/policies/scope-boundary.md)

**Scope note, 2026-08-08.** The second directive is about **wrapping** releases and is left as the
user wrote it; correctness releases (v2.0.0 onward) add almost no operations. Only the user changes
this list.
