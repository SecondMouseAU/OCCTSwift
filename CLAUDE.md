# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Summary

OCCTSwift is a comprehensive Swift wrapper for OpenCASCADE Technology (OCCT) 8.0.1. It exposes B-Rep solid modeling capabilities to Swift for macOS (arm64, v12+) and iOS (arm64, v15+) via a three-layer architecture: Swift public API → Objective-C++ bridge (C functions) → OCCT C++ library. Uses Swift 6 language mode (strict concurrency).

**One OCCT version is in play.** `Scripts/build-occt.sh` builds `V8_0_1` and `Package.swift` pins
the **`v3.0.0` release asset**, which is that same `V8_0_1` plus seventeen patches, `0010`-`0012`
and `0014`-`0027`. A clean checkout with no local `Libraries/` now gets the right kernel, and
`ci.yml`'s macOS job is a real signal again. Seventeen is what the **asset** holds;
`Scripts/patches/` holds nineteen, and the next paragraph is about the difference.

**Check the count against `Scripts/patches/` before trusting it.** The pin holds whatever was in the
tree when the asset was built, and patches land after. Any patch present in `Scripts/patches/` but
absent from the pinned asset is exercised by **no CI job at all**, because `build-and-test` resolves
the asset rather than building from source. (Narrowed below, in the #1018/#1022 paragraph: the one
PR that adds a patch does get it built by `kernel-integration.yml`. Every PR after it does not.) That is #585's failure shape, so it is worth ten seconds:
`ls Scripts/patches/*.patch | wc -l` against the number in this paragraph. If they differ, the
difference is the untested set, and any claim that a fix in it "is in the kernel" is unevidenced
until a rebuild. `v2.0.0-kernel.1` held eleven against a tree of fourteen, and `kernel.2` fourteen against
fifteen within minutes of being published, both for exactly this reason (#512). **It happened again
on 2026-08-17**, and inside a single session: the v2.0.0 asset held fifteen while `0026` (#905) and
`0027` (#913) sat in `Scripts/patches/` untested by anything, and `0027` arrived on `main` partway
through the very check that found `0026`. `v3.0.0-kernel.1` is the rebuild that closed it.

**As of #1018 and #1022 the counts diverge again, deliberately and with the reason written down.**
`Scripts/patches/` holds nineteen; the pinned asset holds seventeen. The two are `0028` (#1018) and
`0029` (#1022), and `ci.yml`'s `build-and-test` never sees either, which is exactly what the
paragraph above says a divergence means. One narrowing, measured on PR #1032 rather than assumed:
`kernel-integration.yml` triggers on `Scripts/patches/**`, so the PR that **adds** a patch does get
`V8_0_1` plus every carried patch built from source and the full suite run against it. That proves
the patch applies, compiles and regresses nothing. It cannot prove either fix works, since neither
has a Swift-reachable assertion, and it does not run on any later PR that leaves `Scripts/patches/`
alone. None of that makes "read `kernel-integration.yml` instead of `ci.yml`" good advice; #585 is
what discredited that. They are not equally urgent. `0028` is the one carried patch a
rebuild would give no Swift-side coverage to at all: `OCCTGeomPlateErrors`, the only bridge reader
of the three accessors it fixes, was deleted by #999 (PR #1015), so the upstream GTests are its only coverage
anywhere. `0029` is the opposite, an uncatchable SIGSEGV on `Document.datums` for any OCAF document
whose datum carries a point without an annotation plane, so until a rebuilt asset ships it nothing
protects a consumer. Do not read this note as permission to skip the check; read it as the answer
the check should produce today, so a twentieth patch appearing without a note is still a finding.

**The count check is necessary and not sufficient.** At the v2.0.0 release check the count agreed
(fifteen on disk, "fifteen" in the prose) while the enumeration immediately beside it in
`Package.swift` listed **eleven**, having never been extended past `0021`. A total and a list
disagree silently, and the total is the one everybody reads. What settles it is matching each
patch's own added lines against the pinned asset: every patch that touches a shipped `.hxx` can be
checked directly against `OCCT.xcframework/*/Headers/`, and the rest need either a green
`build-and-test` (which resolves the asset, not a local build) or a reproducer run. A `.cxx`-only
patch that adds a distinctive **string literal** is a third option and the cheapest: `0026`'s throw
message was confirmed with `strings` in all three slice archives. `0027` shows the limit of that
trick, since it signals through `myStatus` and adds no literal, so nothing in the binary can be
grepped for it; it is held instead by an `OCCTSWIFT_LOCAL=1`-gated test that **does not run in CI at
all**, which means a green `build-and-test` is not evidence for it and never was. Two patches,
`0018` and `0023`, are reachable by neither, because the bridge stops both defects before OCCT sees
them; they are the only carried patches with no CI coverage of any kind, and `Package.swift` says so
next to them.

Until 2026-08-04 this was not true: the pin was the v1.15.18 asset (`V8_0_0_p1` + patches
`0001`-`0016`), so every test asserting a newer patch's fix failed in CI indistinguishably from a
regression, and seven suites were red for that reason alone (#585). If you find advice to read
`kernel-integration.yml` instead of `ci.yml`, or to rely on `OCCTSWIFT_LOCAL=1` for correct results
rather than for speed, it predates that fix. The release commit re-points `url:`/`checksum:` at the
final v2.0.0 asset (#512).
See [`docs/occt-upgrades.md`](docs/occt-upgrades.md#p1-to-801-unreleased).

## Build & Test Commands

```bash
swift build                          # Build the package
swift build --target OCCTThreadTests # Focused compile: just one domain's tests (~3s) — see "Test Layout"
swift test                           # Run all tests (~3900 tests across per-domain targets)
swift test --filter "Issue187"       # Run suites whose struct name matches (matches the type, not @Suite title)
swift run OCCTTest                   # Run test executable
Scripts/tsan-stress.sh all           # ThreadSanitizer gate: REQUIRED for concurrency-touching changes (see docs/thread-safety.md)
```

### Static Gate Scripts

Eight gates, two censuses and one merge-history audit, all pure Python over the repo's own text. No
OCCT, no build, no network, ~3s for the lot. **CI runs every gate, plus every `--self-test` including the census's, in `ci.yml`'s
`gate-scripts` job** — a separate
`ubuntu-latest` job, not a step inside the macOS build, so it reports in under a minute and keeps
its own status check when `build-and-test` is red for an unrelated reason. Each exits 1 on a
defect and 0 when clean; `check-bridge-index`, `check-null-handle-guards`, `derive-gdt-enums` and
`derive-bridge-header-split` exit **2** if run from anywhere but the repo root (#625).

**`gate-scripts` is a required status check on `main`** (#649), via a repository ruleset (id
20252636, "require gate-scripts on main") which is the repo's only branch protection. It moved there
at the v2.0.0 release; before that it was on `refactor/381-pass1b`, the integration branch, which is
now merged. Five things worth knowing before you touch it:

- **Do not give the job a `name:` key.** The published check-run name is the job's `name:` when it
  has one and the job id otherwise, and that string is what the rule matches. A prose name reads
  like a comment, so rewording it would silently stop satisfying the rule while the PR UI looked
  unchanged — the same class of failure the gates themselves exist to catch. The job id is a stable
  identifier nobody edits for readability.
- **It became requirable on `main` only once `ci.yml` carrying the job had landed there.** A
  required check that never reports blocks a PR permanently with "Expected, waiting for status to be
  reported", and there is no way to clear it. Before flipping it, the check was confirmed to have
  actually published `success` on `main`'s HEAD, not merely to exist in the workflow file. For a
  `pull_request` the workflow is read from the merge ref, so once the base has the job every PR gets
  it regardless of how stale the head is.
- **A required check also declines direct pushes**, so `main` now takes changes by PR only, the
  release commit included. **Measured, not inferred**: a throwaway branch was added to this same
  ruleset, an empty commit pushed straight at it, and the push refused with `Required status check
  "gate-scripts" is expected` / `push declined due to repository rule violations`, then the branch
  and the ruleset entry removed. The first draft of this bullet asserted it from a refusal seen on
  the integration branch *before* the rule moved, which is a different ref under a different rule,
  and a release engineer meeting this at the release commit deserves better than an extrapolation.
  `okf/policies/changelog-on-merge.md` used to offer committing the transcription directly onto the
  base as one of two routes; that route is deleted, and the entry now goes on the PR's own branch as
  the last commit before merging.
- **No pattern rule covers `refactor/**`, deliberately.** A pattern is what made #780 expensive:
  renaming a branch to move it out of the pattern **closed its open PR**, and GitHub will not
  reopen one whose head branch was renamed. Narrowing to a single explicit branch was the remedy,
  and after the merge the natural landing place is `main` rather than a new pattern. Being
  *required* is a separate question from whether the job runs: `gate-scripts` runs on any PR whose
  **base** carries `ci.yml`, which is every branch cut from `main`, and requiring it elsewhere would
  only decide whether it blocks. Do not read that as "it runs everywhere". A PR based on a branch
  whose `ci.yml` predates the job never dispatches it, and marking it required there is exactly the
  unrecoverable stall the second bullet describes.
- **`build-and-test` is required nowhere, and that is still the right call for now.** It was
  0-for-21 on the integration branch under #585, because the pinned asset was an older kernel than
  the branch's tests were written against. That cause is gone. But it failed on `main` at the
  v2.0.0 release commit for an unrelated reason (the manifest pointed at a release asset that was
  still uploading, so SwiftPM got a 404), which is a live demonstration of why the advice here is to
  measure a run of green results before requiring it rather than requiring it on one.

```bash
python3 Scripts/check-bridge-index.py            # OCCTBridge.h's class → symbol index: stale / misfiled entries
python3 Scripts/check-null-handle-guards.py      # every bridge fn guards the Handle, not just the pointer
python3 Scripts/check-docs-defaults.py           # every default docs/reference/ restates matches its declaration
python3 Scripts/check-docs-existence.py          # every symbol docs/ documents as current still exists in Sources (#802)
python3 Scripts/check-borrowed-handles.py        # no struct/enum stores an OCCT*Ref it has no deinit to release (#965)
python3 Scripts/derive-bridge-header-split.py --verify  # every declaration sits in the header its .mm owns (#673)
python3 Scripts/derive-gdt-enums.py --verify      # the GD&T enums still match the pinned XCAFDimTolObjects headers (#996)
python3 Scripts/count-operations.py              # README + API_REFERENCE totals match the derived count
python3 Scripts/census-unmeasured-values.py      # CENSUS, not a gate: values returned as measurements that were never computed (#726)
python3 Scripts/census-doc-occt-attribution.py   # CENSUS, not a gate: docs attributing a method to an OCCT class its bridge fn never reaches (#928)
python3 Scripts/check-changelog-transcription.py # REPORT, not a gate yet: merges that landed with no CHANGELOG entry (#742)
```

`census-unmeasured-values.py` and `census-doc-occt-attribution.py` are the two entries that are
**not gates**. Each exits 0 whether or not it finds anything, because the output is a list of sites
for a human to adjudicate, not a verdict on the tree. CI therefore runs only their `--self-test`s:
a bare run could never fail and so could never signal. Their detectors can still go blind, which is
the failure every other entry here exists to prevent, so that is what CI holds them to.

**`census-doc-occt-attribution.py` is #807's over-coverage detector** (#928), and the only entry
whose bare run wants `Libraries/OCCT.xcframework`: the class-existence half is asked of the pinned
headers, never of the `occt-refman` MCP cache, and reports SKIPPED when they are absent, which is
the normal case in CI and in a fresh clone. The attribution half needs no kernel and runs anywhere,
off the committed `Scripts/occt-packages.txt` (354 package prefixes plus 168 no-underscore package
classes, derived from the pinned headers; `--reverify-packages` diffs it against them,
`--write-packages` rewrites it). Under a one-at-a-time removal matrix it caught **25 of #808's 26
confirmed findings and 6 of #809's 6**, and its measured false-positive rate is **41% over a 40-row
hand-adjudicated sample** (`Scripts/repro/928-over-coverage-detector/`, re-scorable with
`score_sample.py`). That rate is why it reports rather than gates; promoting it is a separate
decision on a better number, and it comes with a rename to `check-` per the convention above.

Seven of the eight gates take `--self-test`, as do both censuses and the merge-history audit, each running a fixture battery proving the *detector* catches each
failure mode. Run it whenever you change one of these scripts — three gate scripts on this branch
were confidently wrong (#618, #624/#630, #626), and a detector that reports "all clear" because it
is blind looks exactly like one reporting "all clear" because the tree is clean.
`count-operations.py` has no `--self-test` and **exits 2 on an unrecognised option** rather than
running the report, so writing `count-operations.py --self-test` to match its siblings fails loudly
instead of passing forever.

**Optional pre-commit hook** (`Scripts/git-hooks/pre-commit`) runs eighteen of CI's nineteen
invocations, flag for flag. The one it omits is `check-changelog-transcription.py`'s real run, which
audits the branch's merge history and so answers a question about the branch rather than about the
commit you are making; its `--self-test` does run. That is the only deliberate divergence between
the two lists, and it is here rather than in a comment because an undocumented difference between
the hook and CI is exactly the thing that makes a passing hook misleading. It is **opt-in and not installed by cloning**, so enable it deliberately:

```bash
# main checkout — surgical, leaves other hooks alone
ln -s ../../Scripts/git-hooks/pre-commit .git/hooks/pre-commit

# LINKED WORKTREE (.claude/worktrees/*) — the symlink above fails with "Not a directory" there,
# because a worktree's .git is a file, not a directory. Use either of these instead:
git config core.hooksPath Scripts/git-hooks                          # per-worktree
ln -s <main>/Scripts/git-hooks/pre-commit <main>/.git/hooks/pre-commit  # once, covers every worktree
```

`core.hooksPath` REPLACES `.git/hooks` rather than adding to it, so any hook you already have stops
firing while it is set. `git commit --no-verify` skips the hook. It checks the working tree rather
than the staged snapshot, runs whatever `python3` is on your PATH (CI pins 3.12), and exits 0 with a
warning if `python3` is missing — so a passing hook is weaker evidence than a passing CI job. CI is
the authority.

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
`master`), while this project pins **OCCT 8.0.1**. For version-sensitive details, the pinned
headers in `Libraries/OCCT.xcframework/.../Headers` are the source of truth. It documents the
upstream C++ API the bridge wraps, not the Swift surface.

## Architecture

```
Sources/OCCTSwift/          Swift public API (Shape, Wire, Surface, Face, Edge, Curve3D, Mesh, etc.)
Sources/OCCTBridge/include/ C function declarations (16 files: OCCTBridge.h umbrella + 15 per-domain headers, #395)
Sources/OCCTBridge/src/     Objective-C++ implementations (16 files, one per domain, matching the headers)
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

If the new function takes an `OCCTCurve3DRef` / `OCCTCurve2DRef` / `OCCTSurfaceRef`, guard the
handle as well as the pointer: `if (!x || x->curve.IsNull()) return <the fallback the catch below
uses>;`. Checking only the pointer says nothing about the handle, and 36 of the 57 OCCT entry
points this bridge passes such a handle into dereference it unconditionally, which is an
uncatchable signal, not something `catch (...)` can absorb (#478, #556, #618). Run
`python3 Scripts/check-null-handle-guards.py` to verify; it exits 1 on any unguarded site, and
`--self-test` proves both failure modes (an unguarded site reported, a guarded one not). **Both are
run by CI** in `ci.yml`'s `gate-scripts` job, so an unguarded site turns the PR's check red — until
#625 they were run by nothing at all, and this instruction described a gate that existed only as
prose. `gate-scripts` is a **required** status check on `refactor/**` (#649, via the repo's one
ruleset), so an unguarded site blocks the merge rather than merely showing red. See "Static Gate
Scripts" above for the rules that come with that, and for the optional pre-commit hook.

**The guard is required only where the OCCT call actually needs it.** Not every entry point
dereferences: `GeomLib_Tool::Parameter` returns false, `GeomAdaptor_Surface` and
`Approx_SameParameter` raise a catchable `Standard_Failure` the surrounding `catch (...)` already
turns into the same fallback a guard would return. Measure against
`Scripts/repro/556-null-handle-guard-sweep` before adding one; a guard on a call that copes is
noise, and the script's `ALLOWED` table records each such site with its measured reason.
The handle does not have to be spelled `x->curve` to reach OCCT: this bridge also reaches it
through a `reinterpret_cast`/`static_cast`/C-style cast, a pointer alias, a handle alias, and a
shared bridge helper. The checker handles those four, which are the four this tree currently uses
(#618); a hand-audit that greps for `->curve` handles none of them.

**A `TopoDS_Shape` needs a guard too, but only on some members (#1026).** If the new function takes
an `OCCTShapeRef`/`OCCTWireRef`/`OCCTEdgeRef`/`OCCTFaceRef`, the pointer test is again not enough,
because `Shape.nullified` is a public property returning a wrapper around a null `TopoDS_Shape`.
The rule is narrower than the handle one: a null `TopoDS_Shape` is safe to copy, compare, cast with
`TopoDS::Edge` and walk with `TopExp` (PR #1027 measured 345 cast sites and found none defective),
and unsafe on the ten members that dereference `myTShape` with no null test of their own:
`ShapeType()`, the eight flag accessors (`Free`, `Locked`, `Modified`, `Checked`, `Orientable`,
`Closed`, `Infinite`, `Convex`, getter and setter alike) and `EmptyCopy()`. `NbChildren()` is the
one OCCT guards itself. Reach any of those and the guard is
`if (!occtShapeIsPresent(x)) return <fallback>;` or, where a type test follows,
`if (!occtShapeIsType(x, TopAbs_T)) return <fallback>;`, both `inline` in `OCCTBridge_Internal.h`.
The same `check-null-handle-guards.py` enforces it, as a third walk with its own `SHAPE_ALLOWED`
table, and its fixtures are the `S*` ones. **Return the refusal the function already gives a
wrong-typed input, never a value that reads as a measurement** (#726): all forty-two sites had one,
so none needed inventing, and `Shape.isEmptyShape` is what a caller uses to tell a null shape from a
real negative.

**Four is a fact about this tree, not a closed set.** The checker is still blind to `(*cast).field`,
a reference-to-wrapper alias, an `IsNull()` whose result is discarded or does not dominate the use,
a negated guard, `extern "C"` on the definition line (which hides the whole function from its
parser), and a helper that guards only some paths; and it would wrongly report
`Handle(Geom_Curve) w(wrapper->curve);` constructor-init syntax. None of those appears today. If you
write one, teach the checker the shape in the same PR, and note that an `ALLOWED` entry is keyed
`(file, function)` with no argument index and no re-validation, so it exempts every argument of
that function and every later change to it.

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
- **Prove the test fails.** Every new test, and every new `--self-test` case, is run once with its
  subject broken: inject the defect, confirm the failure, restore, confirm the pass, report both.
  Adding a self-test is not the rule, watching it fail is. See
  [`okf/policies/prove-the-test-fails.md`](okf/policies/prove-the-test-fails.md) for why this is a
  policy here rather than a preference, including the two occasions a `--self-test` passed 6/6
  while one of its cases proved nothing.

## Known OCCT Bugs

- `BRepExtrema_ExtCC` crashes when edges are parallel — guard with `if (result.isParallel) { return result; }` before accessing points
- ~~Container-overflow in NCollection on arm64 macOS~~ — **this claim was never characterized and does not hold up.** Investigated for #341 (2026-07-21) using the #298 TSan protocol (minimal-module ThreadSanitizer build of V8_0_0_p1 + all 10 carried patches): `FoundationClasses`+`ModelingData`+`ModelingAlgorithms` stress scenarios (concurrent create/fuse/fillet, independent meshing) are clean except the already-known benign `BOPAlgo_InitMessages` lazy-init race. No NCollection race reproduced anywhere. Re-enabled the 3 suites in `Tests/OCCTStressTests/StressConcurrencyTests.swift` that had been `.disabled()` under this same unevidenced claim (some since ~v0.51.0) — 25/25 clean runs. **A real, different, previously-undetected race was found instead**: `XCAFDoc_ShapeTool::theAutoNaming`, a process-global `static bool` that `RWMesh_CafReader::fillDocument()`, `RWGltf_CafReader::fillDocument()` (a separate near-duplicate override — reachable via OBJ **and** glTF import), and `XCAFDoc_Editor::Expand()` (reentrant — recurses into itself) all save/mutate/restore with zero synchronization; `XCAFDoc_ShapeTool::AddShape` reads the same flag from every one of those and from ordinary unscoped calls too. Same failure class as #298 (unsynchronized global save/modify/restore), but logical/cosmetic (wrong auto-naming, or racy for the plain `bool` itself) rather than geometric. **Fixed upstream in v1.15.5** (`Scripts/patches/0011-*`, xcframework rebuilt): `XCAFDoc_ShapeTool::AutoNamingScope` (RAII, `std::recursive_mutex`-backed) replaces the three ad hoc save/restore call sites, and `theAutoNaming` itself is now `std::atomic<bool>` so unscoped readers (e.g. `AddShape` calls outside any of the three sites) are no longer racing on the raw storage either. Verified via TSan: 0 races across 4 runs (was 9-17/run), zero regression on the #298/independent-meshing scenarios. The interim bridge-side `meshCafMutex()` mitigation shipped in v1.15.4 was removed once this kernel patch shipped — matches the #298 PR1→PR2 pattern. Filed upstream as [OCCT#1387](https://github.com/Open-Cascade-SAS/OCCT/issues/1387) (repro) / [OCCT#1388](https://github.com/Open-Cascade-SAS/OCCT/pull/1388) (fix). See [`Scripts/repro/341-meshcaf/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/341-meshcaf) for the TSan reproducer and full writeup. #341. The two hard crashes (SIGSEGV/SIGABRT) observed empirically in ~2/20 full-suite parallel `swift test` runs during this investigation were filed separately as #344 (SIGSEGV, root-caused below) and #345 (SIGABRT, still uncharacterized — essentially no localizing evidence). **Revised in v1.15.15** after upstream review on OCCT#1388: maintainer gkv311 pointed out the mutex only serialized the three known override call sites against each other — every *other* read of `theAutoNaming` in `XCAFDoc_ShapeTool.cxx` (`AddShape`, `MakeReference`, `SetSHUO`) stayed outside any scope, so an unrelated unscoped caller on another thread could still observe another thread's temporary override; the atomic made that memory-safe, not logically correct. Root design issue: `theAutoNaming` was never meant to express per-document intent — the three overriding call sites each want to suppress naming for their own document build, and `XCAFDoc_ShapeTool` is already one instance per document, so the override belongs there, not on a shared global. **Fixed properly this time**: `XCAFDoc_ShapeTool::OwnAutoNamingScope` replaces `AutoNamingScope`, saving/restoring a per-instance `myOwnAutonaming` field instead of the shared flag — no locking needed at all, and nested scopes on the same instance (`XCAFDoc_Editor::Expand`'s self-recursion) still compose correctly since each restores exactly the override state it observed on entry, not an unconditional reset. Verified: same TSan stress (10×200, `obj_roundtrip_unique`), 0 races, matching the prior result; new isolation scenario ([`Scripts/repro/363-own-autonaming/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/363-own-autonaming)) directly checks the property the mutex fix couldn't guarantee — half the threads override locally while the other half do unscoped `AddShape()` on independent documents relying on the process-wide default, concurrently: 3000 operations, 0 leaks. Patch `0011` updated in place (same fix, corrected design — not a new patch number). Upstream PR #1388 updated to match; CI green on all 3 platforms, all GTest/regression/test suites. #363.
- `XCAFApp_Application::GetApplication()` / `CDF_Directory::Add` — **#344, the SIGSEGV #341 didn't explain.** Confirmed to survive the #341 kernel fix in v1.15.5 (re-ran the parallel `swift test` loop 12× on v1.15.5: 1 more hit, same signature) — a genuinely different, previously-undetected pair of races. `GetApplication()`'s lazy singleton init (`static Handle(XCAFApp_Application) locApp; if (locApp.IsNull()) { locApp = new XCAFApp_Application; }`) is a textbook double-checked-locking-without-locking bug: two threads' first concurrent call can both construct a new instance and race to assign `locApp`. TSan shows this is the dominant defect — it produces multiple concurrently-constructed `XCAFApp_Application` instances, cascading into races across dozens of unrelated destructors as the "losing" instances are torn down mid-flight. Separately, `CDF_Directory::Add`/`Remove`/`Contains` mutate/read `myDocuments` (a plain `NCollection_List`) with zero synchronization — every `CDF_Application` is normally one process-wide instance shared by every caller, so its one `CDF_Directory` receives `Add()` from every document-creating call on every thread, racing on `NCollection_BaseList::PAppend`. The #341 TSan stress never caught either: it builds `TDocStd_Document` directly, bypassing `XCAFApp_Application`/`CDF_Application` entirely — the real bridge path (`OCCTDocumentLoadOBJ` and every other document-producing call) does not. **Fixed in v1.15.6** (`Scripts/patches/0012-*`, xcframework rebuilt): `GetApplication()` folds construction into the static local's initializer (C++11 magic statics, thread-safe exactly once); `CDF_Directory` gets a private mutex guarding `Add`/`Remove`/`Contains`/`Length`/`IsEmpty`/`Last`. Verified via a debug (`-O0 -g`) build with a temporary `SIGSEGV`/`SIGBUS` handler: stock p1 crashes ~50% of runs at 10 threads × 3000 barrier-synchronized rounds, both captured backtraces resolving to `TDocStd_Application::NewDocument -> CDF_Application::Open`; TSan (same minimal-module protocol as #298/#319/#341) goes from 234 race reports to 9, all in `CDF_Directory::Add`/`PAppend` and all showing the same mutex held on both sides of the reported conflict — consistent with a TSan/allocator-recycling artifact (a control program with a trivially-correct mutex pattern shows no such warning under identical flags), not a genuine unaddressed race; the entire `GetApplication()`-driven destructor cascade is gone entirely. Filed upstream as [OCCT#1389](https://github.com/Open-Cascade-SAS/OCCT/issues/1389) (repro) / [OCCT#1390](https://github.com/Open-Cascade-SAS/OCCT/pull/1390) (fix, two commits). **Found during validation of this same fix**: correctly making `GetApplication()` a true singleton means every caller now genuinely shares ONE `TDocStd_Application` instance — surfacing more races on that instance's OTHER unsynchronized state, previously masked by threads sometimes getting different (uncontended) instances. Repeated `swift test` runs hit a SIGTRAP in `Resource_Manager::SetResource` (via `TDocStd_Application::DefineFormat`, itself called by the common `Document.defineAllFormats()` test-setup path) and a SIGSEGV in `TDocStd_Application::ReadingFormats` iterating `CDF_Application::myReaders` concurrently with a writer. `TDocStd_Application::Resources()` has the identical lazy-init bug as `GetApplication()`; `Resource_Manager`'s maps and `CDF_Application::myReaders`/`myWriters` have zero synchronization. Also fixed in v1.15.6 (same patch): a mutex for `Resources()`'s lazy-init, a `std::recursive_mutex` for `Resource_Manager`'s accessors (added an explicit copy constructor too — the new mutex broke `ShapeProcess_Context.cxx`'s existing `new Resource_Manager(*sRC)` thread-safety workaround, whose own comment already acknowledged this exact defect: *"calling of SetResource() for one object in multiple threads causes race condition"*), and a mutex for `myReaders`/`myWriters`. 0/12 further `swift test` runs of `OCCTXCAFTests` reproduce either crash after the fix. A THIRD, architecturally different crash surfaced in the same validation (`BinLDrivers_DocumentStorageDriver::Write` corrupting a shared, cached, non-reentrant storage-driver instance under concurrent `Save`/`SaveAs` of the same format) — a shared worker object, not a container needing a lock, so the kernel fix needs its own TSan investigation; filed separately as #349. It was severe enough on its own (~60% crash rate in `OCCTXCAFTests` alone once the two races above stopped masking it) that v1.15.6 ships an **interim bridge-side mitigation** for it too: `ocafStoreMutex()` (`OCCTBridge_Document.mm`) serializes `OCCTDocumentSaveOCAF`/`OCCTDocumentSaveOCAFInPlace`/`OCCTDocumentLoadOCAF` — the same #298/#341 PR1→PR2 pattern (bridge mutex now, kernel fix later). 0/12 further `swift test` runs of `OCCTXCAFTests` crash after this mitigation (some pre-existing, unrelated test-fixture flakes remain — hardcoded non-unique temp file paths across parallel `OCAF Save/Load` tests yielding `.alreadyRetrieved`, and the already-known `Issue173AssemblySTEPTests` flake — neither a kernel bug). See [`Scripts/repro/344-cdf-directory/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/344-cdf-directory) for the full writeup. #344.
- **Uncaught-exception SIGABRT — #345, the companion crash to #344.** #345 was filed alongside #344 from the same investigation with "essentially no localizing evidence" (just `exited with unexpected signal code 6`, no test name, no backtrace). An audit (prompted by #344's own finding that fixing one race exposes the next) turned up a plausible, distinct root cause: OCCT's `gp_Dir` constructor throws `Standard_ConstructionError` for a zero-length (or near-zero) direction/normal vector (`Libraries/occt-src/src/FoundationClasses/TKMath/gp/gp_Dir.hxx`); so does `Geom_Direction`'s. **49 public bridge functions** across `Sources/OCCTBridge/src/{OCCTBridge_Curve3D,OCCTBridge_Geom2d,OCCTBridge_Modeling,OCCTBridge_Spatial,OCCTBridge_Surface,OCCTBridge_Topology,OCCTBridge_Visualization}.mm` constructed `gp_Dir`/`gp_Ax1`/`gp_Ax2`/`gp_Ax3`/`Geom_Direction` directly from caller-supplied doubles (or called a `Geom_Surface`/`Geom_Curve` `D0`/`D1`/`D2` derivative evaluator, or a `GeomEval_*Surface` constructor — same throw risk for degenerate radius/amplitude/omega) with **no try/catch anywhere in the call chain** — e.g. `OCCTSurfaceD1`/`OCCTSurfaceD2` had none, right next to `OCCTSurfaceGetNormal` two lines below, which already did (an easy-to-miss inconsistency). An uncaught C++ exception crossing the bridge's `extern "C"`-ish boundary into Swift-generated call frames has no matching unwind personality routine — a guaranteed `std::terminate()` → `abort()` (SIGABRT), and it would leave almost no diagnostic trail, matching #345's profile exactly. **Fixed**: wrapped all 49 in `try { ... } catch (...) { <safe fallback> }` matching each file's existing idiom; the 3 functions returning a `_Nonnull` pointer (`OCCTAxis1PlacementCreate`, `OCCTAxis2PlacementCreate`, `OCCTOBBCreate`) fall back to constructing a valid default axis instead of `nullptr`, since returning null from a `_Nonnull` contract would just relocate the crash to the next dereference. Two confirmed false positives were left untouched: `computePlaneForPoints` (`OCCTBridge_AIS.mm`) and `buildTrsf3D` (**since #995 one `inline occtBuildTrsf3D` in `OCCTBridge_Internal.h`**; it was two separately-defined `static` helpers with byte-identical bodies, one each in `OCCTBridge_Curve3D.mm`/`OCCTBridge_Surface.mm`) are both already protected by a `try` in their callers, which #995 re-measured rather than inherited: all fourteen `occtBuildTrsf3D` call sites sit inside their own function's `try`, and a caller that reaches it from outside one turns a zero-length `gp_Dir` back into a `std::terminate`. New regression tests (`Tests/OCCTStressTests/StressNullInvalidTests.swift`: `mirrorAxisZeroDirection`, `mirrorPlaneZeroNormal`, `geomDirectionZeroVector`) exercise a zero vector through the public Swift API. **Validation**: 70 additional full-suite `swift test` runs (4419-4422 tests each, ~309,540 individual test executions) — zero SIGABRT recurrence, zero crashes of any kind (a handful of already-known, unrelated assertion-level test-fixture flakes remain). This is a bridge-only fix (no OCCT kernel change, no xcframework rebuild) — not an OCCT bug, so nothing filed upstream. #345's own bar for confident closure was "100+ runs with no recurrence"; 70 clean runs plus a fix matching the exact crash mechanism is short of that literal bar but is the strongest evidence gathered to date — recommend closing #345, reopen if it recurs.
- `PCDM_StorageDriver`/`PCDM_Reader` (backs `CDF_Application::WriterFromFormat`/`ReaderFromFormat`) — **#349, the third crash found validating #344.** `CDF_Application` caches one storage/retrieval driver instance per format and hands the same instance back to every `Store()`/`Retrieve()` call for that format, including concurrently from different threads/documents. But `BinLDrivers_DocumentStorageDriver` (and every other format's driver, structurally) is not reentrant: `Write()`/`Read()` mutate instance-level scratch state (`myRelocTable`, `myTypesMap`, and more) with zero synchronization, so two threads' concurrent `Write()` calls corrupt each other — reliable SIGSEGV (`BinMDF_ADriverTable::AssignIds` on a torn `myTypesMap`, reached via `BinLDrivers_DocumentStorageDriver::Write -> FirstPass -> CDF_StoreList::Store -> TDocStd_Application::SaveAs`). TSan (same minimal-module protocol as #298/#319/#341/#344) confirms directly: 136 race warnings + a live SIGSEGV in one run (8 threads × 25 rounds) on stock kernel. **Fixed in v1.15.9** (`Scripts/patches/0014-*`, xcframework rebuilt): `PCDM_StorageDriver`/`PCDM_Reader` each get a `mutable std::mutex` + `Mutex()` accessor — every concrete format driver subclass inherits the guard for free, zero subclass changes needed — held at the three call sites that invoke a cached, possibly-shared driver (`CDF_StoreList::Store`, `CDF_Application::Retrieve`, `CDF_Application::Read`). Considered making the driver itself reentrant (eliminating the shared scratch state) but rejected as impractical: TSan shows essentially the entire driver object is scratch state for one `Write()` call, plus a nested shared `BinMDF_ADriverTable` with its own internal mutation — fixing that properly would mean a sweeping signature change to every format driver's private helpers, out of proportion to a "minimal, surgical" upstream PR. Verified: TSan race warnings 136 → 0 (confirmed again at 10×200), crash → clean exit across repeated runs; full production xcframework rebuild + `swift test --filter OCAFSaveLoadBinaryTests`/`OCCTXCAFTests` clean, 3× full `swift test` (4423 tests) clean. The interim bridge-side mitigation (`ocafStoreMutex()`, shipped v1.15.6) stays in place — same PR1→PR2 pattern as #298/#341/#344. **Found during validation of this fix**: `CDM_Application::myMetaDataLookUpTable` (a plain, unsynchronized `NCollection_DataMap`, one per `CDM_Application`) races too — same failure class as `CDF_Directory::myDocuments` (#344) and `theAutoNaming` (#341), out of scope for #349, filed separately as #353. See [`Scripts/repro/349-ocaf-driver-reentrancy/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/349-ocaf-driver-reentrancy) for the full writeup. Filed upstream as [Open-Cascade-SAS/OCCT#1393](https://github.com/Open-Cascade-SAS/OCCT/issues/1393) (repro) / [OCCT#1394](https://github.com/Open-Cascade-SAS/OCCT/pull/1394) (fix, CI green on all platforms). #349.
- `CDM_Application::myMetaDataLookUpTable`/`CDM_MetaData` — **#353, the race #349's own fix unmasked.** `CDM_Application::myMetaDataLookUpTable` is shared process-wide (one `CDM_Application` singleton, since #344) with zero synchronization: `CDM_MetaData::LookUp()`'s map mutation (called from `CDF_FWOSDriver::MetaData`/`CreateMetaData`, `XmlLDrivers_DocumentRetrievalDriver::Read`, `PCDM_ReferenceIterator::MetaData`), `CDM_Document::SetMetaData()`'s whole-table iteration on every save, and each `CDM_MetaData`'s own `myIsRetrieved`/`myDocument` fields (mutated by `SetDocument`/`UnsetDocument`, read by `IsRetrieved`/`Document`) all race independently with no guard at all. TSan (same minimal-module protocol as #298/#319/#341/#344/#349) confirmed the exact trace quoted in the issue: `CDM_Document::SetMetaData()`'s map-iteration loop reading `IsRetrieved()` — still inside #349's own per-driver lock, but that lock has no relationship to a *different* thread's document destructor — racing `~CDM_Document() -> CDM_MetaData::UnsetDocument()` tearing down an unrelated document's metadata entry on another thread. 1 confirmed race + SIGABRT (exit 134) on stock #349-fixed kernel. **Fixed in v1.15.10** (`Scripts/patches/0015-*`, xcframework rebuilt): follows the established "lock the shared resource, don't restructure the subsystem" precedent (#341's atomic bool, #344's `CDF_Directory` mutex, #349's per-driver mutex) — the map's "bind once, reuse forever, share across all documents" caching design is load-bearing, not incidental scratch state. Two independent locks: `CDM_Application` gets a `mutable std::mutex` + accessor threaded through `CDM_MetaData::LookUp()`'s two overloads (now take the mutex as an explicit parameter) and `CDM_Document::SetMetaData()`'s iteration; `CDM_MetaData` gets its own private `mutable std::mutex` guarding `myIsRetrieved`/`myDocument`, independent of the table lock, since two already-bound `CDM_MetaData` objects can still race on those fields. No changes to any format-specific driver subclass. Verified: TSan race count 1 (+SIGABRT) → 0, clean exit across 5 runs (8×25, 10×60, 3×8×40); full production xcframework rebuild + `swift test --filter OCAFSaveLoadBinaryTests`/`OCCTXCAFTests` clean, 3× full `swift test` (4423 tests) clean. **Not changed**: `CDM_MetaData::myDocumentVersion` (reached via `CDM_Reference.cxx` and `CDM_Application::SetDocumentVersion`) has the identical unguarded-mutable-field shape as the fixed fields, but on the document-*reference* resolution path rather than save/close — not TSan-observed in any run (the repro doesn't exercise cross-document references), flagged as a plausible sibling for a future pass, not fixed here or filed as a separate issue (purely speculative, pattern-matched risk, not an observed defect). See [`Scripts/repro/353-cdm-metadata-lookup-table/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/353-cdm-metadata-lookup-table) for the full writeup. Filed upstream as [Open-Cascade-SAS/OCCT#1396](https://github.com/Open-Cascade-SAS/OCCT/issues/1396) (repro) / [OCCT#1397](https://github.com/Open-Cascade-SAS/OCCT/pull/1397) (fix, CI green on all platforms). #353.
- **`XCAFApp_Application::GetApplication()` singleton usage retired bridge-side — #371, prompted by upstream review of #353.** Reviewing #353's repro ([OCCT#1396](https://github.com/Open-Cascade-SAS/OCCT/issues/1396)), maintainer gkv311 pointed out our whole `theAutoNaming`/`GetApplication()`/`CDF_Directory`/driver-cache/`myMetaDataLookUpTable` race cluster (#341/#344/#349/#353) traces back to every document sharing one `XCAFApp_Application::GetApplication()` singleton — a method that "exists solely for compatibility reasons," floated for `Standard_DEPRECATED`; OCCT's own guidance since 7.1 is a private `TDocStd_Application` per caller. Verified against the actual headers before acting on it: `XCAFApp_Application`'s constructor is protected (only `GetApplication()` can build one), but the base `TDocStd_Application` has a public constructor and is directly instantiable; `CDF_Application::myDirectory`/`myReaders`/`myWriters` and `CDM_Application::myMetaDataLookUpTable` are all per-instance fields, not statics. **Fixed**: `OCCTDocument`'s ctor (`OCCTBridge_Internal.h`) now does `app = new TDocStd_Application()` instead of `XCAFApp_Application::GetApplication()`, and every other bridge call site that grabbed the singleton (9 total, `OCCTBridge_Document.mm` + `OCCTBridge_IO.mm`) does the same — confirmed equivalent via a ground-truth C++ test (create, attach XCAF tools, add shape, set color, retarget storage format, save, reload with a *separate* private instance) before touching any bridge code. Two latent bugs caught along the way: `OCCTDocumentLoadOCAF` and `OCCTDocumentLoadGLTF` each opened/created a document through a *different* app instance than the one stored on the returned `OCCTDocument` — harmless today only because both instances were the same shared singleton; fixed to consistently use the wrapper's own `document->app`. The dead `PCDM_RS_AlreadyRetrieved` retry branch in `OCCTDocumentLoadOCAF` (meaningful only when documents share one app's session directory) was removed — provably unreachable once each load gets a fresh, empty directory. **A dedicated confirmation harness, built specifically to test the new pattern rather than relying on existing coverage, found this wasn't a clean win**: private app per thread/round, zero shared state, zero serialization, run against the real TSan-instrumented kernel — 16 race warnings, in `Resource_Manager::Resource_Manager()` (unsynchronized file-scope global `Debug`, written on every construction) and `Storage_Schema::ICurrentData()` (a process-wide mutable `Handle` every `Storage_Schema` ctor nullifies and every (de)serialization call reads). Neither had ever surfaced in this project's prior TSan gates: every earlier investigation shared one application instance, so `Resources()`'s own per-instance lazy-init mutex (from the #344 fix) accidentally serialized `Resource_Manager`/`Storage_Schema` construction down to "runs once, ever, for the whole process" — moving to a private instance per caller is what first makes them concurrent. Filed upstream as [OCCT#1398](https://github.com/Open-Cascade-SAS/OCCT/issues/1398), not yet fixed in the kernel. **Practical consequence**: `ocafStoreMutex()` (the #349 bridge mitigation) is *not* redundant after this refactor — it turns out to also serialize the Resource_Manager/Storage_Schema hazard, for a reason unrelated to why it was first added — and its coverage was *expanded*, not removed, to also wrap the six `OCCTDocumentDefineFormatBin/BinL/Xml/XmlL/BinXCAF/XmlXCAF` functions and `OCCTDocumentCreateWithFormat` (previously outside the lock, safe only by accident since every document shared one app instance). Confirmed by adding an equivalent mutex to a copy of the confirmation harness: 8×50 threads/rounds, zero TSan warnings, matching the real bridge's coverage. **The upstream kernel PRs for #344/#349/#353 ([OCCT#1390](https://github.com/Open-Cascade-SAS/OCCT/pull/1390)/[#1394](https://github.com/Open-Cascade-SAS/OCCT/pull/1394)/[#1397](https://github.com/Open-Cascade-SAS/OCCT/pull/1397)) were NOT withdrawn** — all three fix real bugs in the singleton pattern OCCT's own header still documents as "the only valid method" to get an `XCAFApp_Application"; every other OCCT consumer following that guidance remains exposed. This is a bridge-only architecture change (no OCCT kernel patch, no `OCCT.xcframework` rebuild) — the prebuilt `OCCTBridge.xcframework` was rebuilt since `Sources/OCCTBridge/src/*.mm` changed. Verified: full `swift test` (4428 tests) clean, `Scripts/tsan-stress.sh swift` (bridge-level TSan, 445 tests) clean, `Scripts/tsan-stress.sh run` (kernel-level gate, now 9 scenarios including the new `371-getapplication-singleton-elimination`) clean. See [`Scripts/repro/371-getapplication-singleton-elimination/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/371-getapplication-singleton-elimination) for the full writeup. #371.
- **`Resource_Manager::Debug` / `Storage_Schema::ICurrentData()` races — #374, the two upstream defects #371's confirmation harness found ([OCCT#1398](https://github.com/Open-Cascade-SAS/OCCT/issues/1398)).** Root-caused and fixed, following the same TSan protocol as #298/#319/#341/#344/#349/#353/#371. (1) `Resource_Manager::Resource_Manager(const char*, bool)` (`Resource_Manager.cxx:109`) writes a file-scope `static bool Debug` on every construction with zero synchronization; every fresh `TDocStd_Application`'s first `DefineFormat()` call lazily constructs its own `Resource_Manager` via `Resources()`, and `Resources()`'s own per-instance lazy-init mutex (from the #344 fix) only serializes repeat calls on the *same* instance, not first-construction races across *different* instances built concurrently. (2) `Storage_Schema::ICurrentData()` (`Storage_Schema.cxx:802`) is a function-local static `Handle(Storage_Data)` mutated with no lock at all: `Write()` (the `SaveAs()` path) sets it for one store's duration, and *any* `Storage_Schema` construction — including the throwaway one `PCDM_ReadWriter_1::ReadReferenceCounter`/`ReadReferences`/`ReadDocumentVersion` each build on **every** `Open()` (reached unconditionally via `CDF_Application::Retrieve`, not just when the document has cross-references) — calls `Clear()` → `ICurrentData().Nullify()` in its constructor, nulling out another thread's in-flight save (or another thread's own in-flight load). Neither race had ever surfaced in this project's prior TSan gates because every earlier investigation shared one application instance, so `Resources()`'s lazy-init mutex accidentally serialized both down to "runs once, ever, for the whole process" — #371's move to a private instance per document is what first made them concurrent. Confirmed via a TSan reproducer built specifically to isolate these two mechanisms (the "unguarded" variant of #371's confirmation harness, no `ocafStoreMutexSim()`): 13 race warnings + SIGABRT before the fix (8×30), 0/4 clean runs after (8×30, 8×50, 10×60, 8×40). **Fixed in v1.15.18** (`Scripts/patches/0016-*`, xcframework rebuilt): `Resource_Manager::Debug` becomes `std::atomic<bool>` (a plain process-wide flag, not per-instance intent, so atomic is sufficient — unlike #341's `theAutoNaming`, which needed a deeper per-instance redesign); `Storage_Schema` gets a new `ICurrentDataMutex()` (function-local static `std::recursive_mutex&`, mirroring `ICurrentData()`'s own accessor pattern) guarding the constructor's `Clear()`, `Write()`'s entire body (one atomic "session" against the global, so the lock spans the whole call, not just each access), `BindType()`, `TypeBinding()`, `AddPersistent()`, `PersistentToAdd()`, `HasTypeBinding()`, and `ISetCurrentData()` — recursive because `Write()`'s own critical section calls back into `BindType()`/`AddPersistent()`/`PersistentToAdd()` on the same thread via per-type `Storage_CallBack::Write()` callbacks, which would deadlock a plain mutex. No public API signature changes; `OCCTBridge.xcframework` did not need rebuilding, only the pinned `OCCT.xcframework` kernel binary. Full `Scripts/tsan-stress.sh run` gate (10 scenarios) clean, 0 regressions on #341/#344/#349/#353/#371's own scenarios. See [`Scripts/repro/374-resource-manager-storage-schema-race/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/374-resource-manager-storage-schema-race) for the full writeup. Filed upstream as [OCCT#1398](https://github.com/Open-Cascade-SAS/OCCT/issues/1398) (repro, filed during #371); this fix is proposed as the corresponding kernel PR. #374.
- `BRepFill_Filling::AddConstraints` + `GeomPlate_BuildPlateSurface::Perform` — **two upstream defects that together SIGSEGV (uncatchable) any non-C0 surface filling against a curved boundary.** Backs `Shape.fill(boundaries:)` and `FillingSurface`; `FillingParameters` defaults `continuity` to `.g1`, so this was the *default* call path, not an opt-in one. (1) `AddConstraints`' face-less/non-C0 branch (`BRepFill_Filling.cxx:334-343`) calls `BRep_Tool::CurveOnSurface(edge, C2d, Surface, loc, f, l)` and then builds `new Geom2dAdaptor_Curve(C2d)` — **discarding the `f`/`l` it just fetched**. For the usual `Geom2d_Line` pcurve that is a ±2e100 parameter span instead of e.g. `[0, 2π]` (measured: constraint length 4e+101). Both sibling branches in the same function trim correctly (`BRepAdaptor_Curve` at `:322`, `BRepAdaptor_Curve2d` at `:361`). (2) The unprojectable constraint that produces makes `Perform` take its `!Ok` recovery branch, which constructs `GeomPlate_MakeApprox(myGeomPlateSurface, ...)` (`GeomPlate_BuildPlateSurface.cxx:537`) using the handle `Perform` unconditionally `Nullify()`s on entry (`:440`) and only assigns later (`:679/:720/:1889`) — a null-handle deref landing in `Plate_Plate::UVBox`. Proved with a probe compiled into the kernel: `myGeomPlateSurface.IsNull()=1` prints immediately before the crash. **The defect has two faces, split by geometry, which is why it hid for so long**: the same call is a *catchable* `Standard_Failure` ("Geom_RectangularTrimmedSurface::U parameters out of range") on a **planar** support surface, which rejects the absurd parameters, and an uncatchable SIGSEGV on an **unbounded/periodic** one (cylinder, sphere, cone), which accepts them — and the pre-existing tests only ever used rectangles/polygons at `.c0`. Always test both geometries when probing this family. **Fixed bridge-side** (no kernel patch, no xcframework rebuild): `occtFillingSupportFaceFromPCurve`/`occtFillingAddConstraint` (`OCCTBridge_Internal.h`) keep the face-less overload out of the call path above C0 by synthesizing a support face from the edge's own pcurve surface, so `Add(edge, face, order)` — which uses `BRepAdaptor_Curve2d` and trims correctly — is used instead. Verified equivalent to a kernel-patched build (one-line `Geom2dAdaptor_Curve(C2d, f, l)`, override-linked against the real archive): identical G0/G1 errors and identical geometry. **The kernel patch and the upstream filing are deliberately deferred, not done** — the one-liner is proven and would be patch `0017-*`, and defect (2) deserves its own commit since a null-handle deref in a recovery path is reachable by *any* failed projection, not just this one. Entry-point audit came back clean: zero `Standard_DEPRECATED` anywhere in `BRepFill`/`BRepOffsetAPI`/`GeomPlate` (pinned p1 *and* upstream master), OCCT's own Draw `filling` command uses the same two overloads the same way, and the upstream header explicitly documents the face-less overload as valid for G1/G2 when the edge has a face representation — so this is a contract violation, not misuse. Also note **`GeomAbs_G2` (ordinal 3) is never a valid order for this API**: `BRepFill_Filling` forwards the `GeomAbs_Shape` value to `GeomPlate_CurveConstraint`/`BRepFill_CurveConstraint` as an integer plate order and both reject outside `[-1, 2]`, so curvature continuity is `GeomAbs_C1` (ordinal 2) and `BRepOffsetAPI_MakeFilling.hxx:163` naming `GeomAbs_G2` as the curvature value is simply wrong. Reproducers at [`Scripts/repro/430-fill-untrimmed-pcurve/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/430-fill-untrimmed-pcurve). #430. **#433 and #434 fixed**: `FillingSurface` used to hand-map continuity locally instead of sharing `occtFillingContinuityToGeomAbs`, requesting `GeomAbs_C1` (curvature) for `.g1` and `GeomAbs_C2` (ordinal 4, always rejected) for `.g2` — failing the whole `build()` for the latter (#433). Root cause was architectural, not a typo: `FillingSurface` held its own `BRepFill_Filling` instead of the `BRepOffsetAPI_MakeFilling` `Shape.fill` already used (the same class, forwarding to a private `BRepFill_Filling` it never exposes) — the two entry points were reaching for the same fixes independently, `FillingSurface` from behind. Converged onto one implementation (#434): `FillingSurface` now builds the same `BRepOffsetAPI_MakeFilling` through the same `occtFillingMakeBuilder`, and both entry points share `occtFillingAddConstraint` — no longer templated, since both callers now hold the same concrete filler type. Gained `add(edge:support:continuity:)`, matching `FillConstraint`'s support-face semantics (used or the constraint fails, never silently substituted). Bridge-only change, no kernel patch, no xcframework rebuild — same pattern as #430/#431/#432.
- `AdvApp2Var_ApproxF2var::mma2ce1_` fills the U Jacobi-maxima buffer from the V slot — **#522, why `GeomConvert_ApproxSurface` at `GeomAbs_C0` returned a surface nowhere near its input while reporting `IsDone()` and a `MaxError()` five orders of magnitude too small.** `mma2ce1_` requests one scratch allocation and partitions it into seven consecutive buffers, `ipt4` for `XMAXJU` (the maxima of the U Jacobi polynomials) and `ipt5` for `XMAXJV`; both `mma2jmx_` calls that fill them targeted `ipt5`, so `XMAXJU` was never written and `mma2ce2_` read whatever the allocation left at `ipt4` — in practice zeros. Every truncation error the approximator computes is `|PATJAC(i,j)| * XMAXJU(i - 2*(IORDRU+1)) * XMAXJV(j - 2*(IORDRV+1))`, so a zero `XMAXJU` zeroed every term, with two silent consequences: (1) the interior approximation error of every patch evaluated to exactly 0, so `mma2ce2_`'s tolerance test could never fire on it and `MaxError()` only ever reflected the boundary-iso errors `AdvApp2Var_Patch::AddErrors` adds afterwards; (2) `mma2er2_`, asked for the lowest degree whose truncation error still fits the tolerance, always answered `NDMINU` — the floor derived from the constraint order and the neighbouring isos — because every candidate scored 0. **Where that floor is low the fit collapses onto it, which is what C0 produces**: `IORDRU = 0`, and a full sphere's V-boundary isos degenerate to its two poles (one coefficient each), so `NDMINU` is 1 and a radius-10 sphere at tolerance 1e-3 came back as a degree-1, 2-pole-in-U B-spline — a straight line across the full `2π` of longitude, deviating by the sphere's own diameter of 20 — reporting `MaxError()` 1.07e-4. A bicubic Bezier at C0/C0 collapsed to a 2×2 bilinear patch reporting 4.08e-15, *unchanged from tolerance 1e-1 down to 1e-7*, because the requested tolerance was compared against a number that was always zero. C1/C2 hid the collapse (their floor is already 8) but not the misreported error. **Degree collapse per se was never the defect** — a cylinder trimmed in V legitimately fits at `vDegree = 1` and always reported correctly; collapsing where the input is not linear was. The write also overran (`mma2jmx_` writes `ndjacu + 1 - 2*(IORDRU+1)` doubles into a slot sized for the `ndjacv` equivalent, running into `VECERR` when `MaxDegU >> MaxDegV`) — benign, since `VECERR` is re-zeroed on entry to `mma2ce2_`, but out of bounds. **Fixed** (`Scripts/patches/0019-*`, xcframework rebuilt): target `ipt4` from the U call. One character. `AdvApp2Var_Context`'s own two `mma2jmx_` calls, the only others in the tree, already write to separate per-direction arrays. Verified: across a 98-case sweep (7 surface families × all 9 (uCont, vCont) combinations of C0/C1/C2, plus C0/C0 at five tolerances) results whose real deviation exceeds the reported error by more than 10× go from **12 to 0**, and those exceeding it at all from 17 to 1 (a Bezier reproduced exactly, 9.95221e-15 reported vs 9.96978e-15 measured); reported errors rise slightly everywhere, which is the interior contribution being counted for the first time; full `swift test` (4842 tests) clean. **Blast radius is wider than the C0 collapse**: `GeomFill_Sweep`, `BRepOffset_Offset`, `GeomLib`, `ShapeCustom_BSplineRestriction`, `ShapeConstruct` and `GeomConvert_1` construct a `GeomConvert_ApproxSurface`, `ShapeCustom_ConvertToBSpline` and `ShapeUpgrade_UnifySameDomain` reach one, and `GeomPlate_MakeApprox` drives `AdvApp2Var_ApproxAFunc2Var` directly — most at C1/C2, where only the error was wrong, but `ShapeConstruct::ConvertSurfaceToBSpline` and `ShapeCustom_BSplineRestriction` both loop the requested continuity down to 0 on failure and then accept on `MaxError() <= tol`, and `ShapeCustom_ConvertToBSpline` *starts* at C0 for any offset surface (`ShapeCustom_ConvertToBSpline.cxx:148`). **Do not build this list with a filename grep**: `BRepFill_Sweep.cxx:1162` is inside a `/* */` block and `BRepFill_Filling.cxx:712` is `//`-commented, so neither is a caller, and the bridge's own `PrecisCode` census (`OCCTBridge_Surface.mm`) cited the `BRepFill_Sweep` one as live and missed `BRepOffset_Offset.cxx:1626` altogether until #573 rebuilt it by reading each site. Found while building #491's parity tests; `Issue491SurfaceApproxParityTests.maxErrorDescribesTheSharedFit`'s `.c0` exclusion is gone. **It is a regression, not an original defect (#756)**: `3016a390713d2e893f4bfa797882b9f0266840e1` (2021, a UBSan coding-rules cleanup) renumbered every workspace offset in `mma2ce1_` down by one and missed exactly one of the two `mma2jmx_` sites, confirmed at the release-tag level, `V7_5_0` writes two distinct slots and `V7_6_0` already collapses them to one. See [`Scripts/repro/522-approx-c0-collapse/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/522-approx-c0-collapse) for the reproducers, root-cause walkthrough and before/after sweep transcripts. #522.
- `BRepFeat_MakeCylindricalHole` part selection — **a silent wrong answer, not a crash: `BRepFeat_NoError` and the input handed back with the drill's faces imprinted on it, nothing removed.** Backs `Shape.cylindricalHole(...:extent:)`. The four modes that choose which piece of the drilling tool to keep (`PerformThruNext`, `PerformUntilEnd`, the ranged `Perform(Radius, PFrom, PTo)`, `PerformBlind`) call `SetOperation(Fuse)` — the one-argument overload, `BOPAlgo_CUT` — then `BOPAlgo_BOP::Perform()`, then `PartsOfTool()`. But `BRepFeat_Builder::PartsOfTool()` (`BRepFeat_Builder.cxx:107`) explores the builder's `myShape` for solids, and `myShape` holds the tool split by the object **only after the COMMON pass**; after a CUT it is the finished workpiece. So each mode's `nbparts >= 2` loop compares barycentres of bored plates and `KeepPart`s those plates, and `PerformResult()` then takes the kept-parts path with a keep set containing no tool part at all. `BRepFeat_Form` (`:806`) and `BRepFeat_RibSlot` (`:224`), the kernel's other two users of the same builder, both call the **two-argument** `SetOperation(myFuse, bFlag)` with `bFlag` true; `PerformResult()` re-derives `myOperation` from `myFuse`, so the operation finally built is the CUT either way. **Fixed in `Scripts/patches/0020-*`** (xcframework rebuilt): that two-argument call at the four sites. `Perform(Radius)` (through-all) selects no parts and stays on the one-argument overload — which is why it was the one extent that already drilled a stack correctly, and why the defect reads as "multi-body" rather than "part selection". **Two corrections to how #532 was scoped**: `PerformBlind` is affected too (unnamed only because the report came out of #496, which had newly wrapped the other two extents), and the trigger is not "more than one body" but "the cut result has two solids" — **a single solid reaches it**, e.g. an 8mm bar severed by its own r=5 bore. Measured on two stacked 50×50×20 plates (one bore removes 1570.7963): `.untilEnd` 0 → 3141.5927, `.range(0,70)` 0 → 3141.5927, `.blind(20)` 0 → 1178.0972; a single plate is byte-identical before and after. **One behaviour change beyond the bug**: an oversized radius that swallows the whole solid used to be `InvalidPlacement` for `PerformUntilEnd`/`PerformThruNext` because CUT emptied `myShape` and `nbparts` was 0; under COMMON `nbparts` is 1 and both now return the empty result `Perform(Radius)` and the boolean drill already returned. **A second defect in the same heuristic is reported, not fixed**: `PerformThruNext`'s closest-interval fallback (`:217-242`) nests its `// parbar > Last` branch *inside* `if (parbar < First)`, so that case is unreachable as written; `PerformBlind`'s equivalent (`:602-616`) has no such structure. Reproducer at [`Scripts/repro/532-cylindrical-hole-part-selection/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/532-cylindrical-hole-part-selection). Re-verified directly against current upstream `master`: the four call sites, the two correct callers, and the second, unfixed defect are all unchanged, and the touched file is byte-identical between `master` and our pin. Filed upstream as [OCCT#1447](https://github.com/Open-Cascade-SAS/OCCT/pull/1447), a fix PR with no companion repro issue, per upstream's own guidance on [OCCT#1409](https://github.com/Open-Cascade-SAS/OCCT/issues/1409#issuecomment-5124395058). #532.
- **`CPnts_AbscissaPoint::Length` / `CPnts_MyRootFunction::Value` integrate arc length with ONE fixed-order Gauss rule over the whole range they are handed — #603.** `order()` gives 10 to a conic, 5 to a parabola, `2*Degree` to a Bezier, `min(24, 2*NbPoles-1)` to a BSpline, and none resolves an integrand that varies sharply across a wide range. `GCPnts_AbscissaPoint::Length` splits at the `GeomAbs_CN` interval boundaries first, which is the whole of what #477 bought — but a conic has exactly one interval, so nothing is split and a whole ellipse measured up to 1.737% long (8x3 +0.337%, 10x1 +1.485%, 1x0.05 +1.737%), a **parabola over `[-100,100]` 3.087% SHORT** (the worst case in the family and the only one with the opposite sign, since order 5 is the lowest `order()` gives anything curved), a hyperbola +0.067%, a whipping cubic Bezier -0.189%. **Not a conic defect and not a "single span" defect**: the error follows the width of ONE integration interval, so the same 8x3 ellipse is 0.337% out over `[0,2pi]`, 0.0001% over `[0,pi]` and exact over `[0,pi/2]`, and #477's per-span split is a mitigation that only works where spans are narrow — a 5-point interpolation is 6.0e-5 out, 100x the 40-point curve #477 was tested on. Called *directly*, with nothing splitting, `CPnts_AbscissaPoint::Length` is 1.0e-1 out on a 200-point interpolation. **Fixed twice, deliberately.** Bridge side (v1.17.x, `occtAdaptorArcLength`/`occtArcWalkToLength` in `OCCTBridge_Internal.h`, shared by all 11 length sites and all 5 solver sites): each `GeomAbs_CN` interval is measured, then halved, quartered, ... until two successive levels agree to 1e-9 relative. **The subdivision has to happen INSIDE each interval** — halving the whole range puts the split on the domain midpoint, which on a uniformly-knotted curve is a knot GCPnts already splits at, so the level-2 sum equals the level-1 sum bit for bit and a "two levels agreed" test ratifies an answer that never moved (110.963893077 at both levels, truth 110.970568312). **The inverse had to move with the forward measurement**: `CPnts_MyRootFunction::Value(X)` is the same integral (one Gauss rule over `[u0,X]` minus the target), so today both are wrong by the same amount and `parameterAtLength(length)` still lands on the last parameter; fixing only the length moves that to 6.2438 on an ellipse whose domain ends at 6.2832. Kernel side (`Scripts/patches/0021-*`, xcframework rebuilt): a new header-only `CPnts_AdaptiveIntegration.hxx` does the same doubling for all four `Length` overloads and `Value`/`Values` — both, or neither, because fixing `Length` alone would break `GCPnts_UniformAbscissa`, which is *already accurate* (2.90e-14 true-arc spacing on an 8x3 ellipse) precisely because it inverts the same bias it measures; changed together its spacing is unchanged to the digit. Verified override-link first, then against the rebuilt binary with no override TUs, matching line for line; full `swift test` 5096 tests, no change. Cost: floor of three quadratures per interval where there was one, ~5x bridge-side and ~30x kernel-side on a conic; a line, circle or 2-pole Bezier/BSpline keeps its `GCPnts_LengthParametrized` closed form and never reaches the integrator. **`GCPnts_UniformAbscissa` is NOT affected** (the issue guessed it was; measured uniform in true arc to 1.9e-10 on the worst ellipse), but **`BRepGProp::LinearProperties` IS**, on its own integrator, and neither fix reaches it — it still reports 41.243157870 for a 10x1 elliptical edge against a true 40.639741801, so `Shape.linearProperties().length` now *disagrees* with `Shape.edgeArcLength`, where before both were wrong together. The bridge subdivision is redundant once the rebuilt kernel is pinned (2x cost, no answer change) — retire it in the release commit that bumps `Package.swift`'s `url:`/`checksum:`. See [`Scripts/repro/603-single-span-quadrature/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/603-single-span-quadrature). Filed upstream as [OCCT#1420](https://github.com/Open-Cascade-SAS/OCCT/pull/1420). #603.
- `LocOpe_SplitDrafts` throws on incompatible geometry — always wrap `Perform()` in try-catch in bridge
- `BRepOffsetAPI_ThruSections` (loft) SIGSEGV'd (null deref, "Address 8") on mismatched closed profiles — `BRepFill_CompatibleWires::SameNumberByPolarMethod` over-advanced an unguarded correspondence-list iterator. It's an OS signal, so the bridge `catch(...)` cannot save it. **Fixed upstream in OCCT 8.0.0p1** (Open-Cascade-SAS/OCCT#1298, OCCTSwift #176/#178); the previously-carried `Scripts/patches/0001-*` was dropped — the current p1 xcframework has the guard natively (regression test "Loft polar-method SIGSEGV regression (#176)" passes against it). Note: `OCC_CATCH_SIGNALS` is inert in our build (no `OCC_CONVERT_SIGNALS`) — do not rely on it for signal safety; OS signals raised inside OCCT (e.g. #234) are still uncatchable in-process.
- `ShapeAnalysis_FreeBounds` (backs `Shape.freeBoundsClosedWires`/`freeBoundsClosedCount`/`freeBoundsOpenWires`, and `Shape.freeBounds`) used to SIGSEGV (uncatchable) on certain shapes with multiple free-boundary components — isolated via AddressSanitizer to `connectWiresToWiresImpl`'s empty-input early return (`ShapeAnalysis_FreeBounds.cxx`) leaving its `owires` out-parameter uninitialized (null), which later crashes `NCollection_HSequence::Append`. Minimally reproducible with just two disjoint planar faces in one compound; not a simple loop-count threshold (150+ loops can be fine, 2 can crash) — depends only on whether any single component's boundary closes with zero edges left over. **Fixed upstream in v1.12.6** (`Scripts/patches/0004-*`, xcframework rebuilt): `connectWiresToWiresImpl` now initializes `owires` to an empty sequence before its early return. #310, upstream repro filed as Open-Cascade-SAS/OCCT#1376, fix as [OCCT#1377](https://github.com/Open-Cascade-SAS/OCCT/pull/1377); sibling `Standard_OutOfRange` bug in the same file, OCCT#1330, was a separate, unrelated defect in the same function — also now carried, see the `0007` entry below. **Shipped upstream in OCCT 8.0.1** ([OCCT#1377](https://github.com/Open-Cascade-SAS/OCCT/pull/1377)); patch `0004` retired, the fix now comes from the kernel.
- `ShapeFix_Face::FixPeriodicDegenerated` (invoked from `Shape.face(from:boundary:)`/`face(from:boundary:innerWires:)` and the `FaceFixer` API whenever a face's sole boundary wire is a single closed edge belting a `Surface.cone`'s full period, apex outside the wire's V range — e.g. a rivet/boss-rim seam fit as one periodic curve) used to SIGSEGV (uncatchable) on the ordinary `ShapeFix_Face fixer(face); fixer.Perform();` construction — a null-Context dereference at the function's final `Context()->Replace(myFace, myResult)`, the only one of twelve such call sites in the file missing the `if (!Context().IsNull())` guard every sibling uses. A standalone circle repro is negative (`wireFromEdges` alone never reaches `FixPeriodicDegenerated`); the minimal repro needs the wire trimmed to a periodic conical surface via `face(from:boundary:)`. **Fixed in v1.12.7**: bridge now calls `fixer.SetContext(new ShapeBuild_ReShape)` before `Perform()` at all three `ShapeFix_Face` call sites (immediate fix, any xcframework); kernel patch also carried (`Scripts/patches/0005-*`, xcframework rebuilt) and filed upstream as [OCCT#1378](https://github.com/Open-Cascade-SAS/OCCT/issues/1378) (repro) / [OCCT#1380](https://github.com/Open-Cascade-SAS/OCCT/pull/1380) (fix). #317. **Shipped upstream in OCCT 8.0.1** ([OCCT#1380](https://github.com/Open-Cascade-SAS/OCCT/pull/1380)); patch `0005` retired.
- `BRepGProp_EdgeTool::IntegrationOrder` (invoked from `BRepGProp::LinearProperties`, which backs `Shape.analyze(tolerance:)`'s small-edge scan) used to SIGSEGV (uncatchable) on an edge whose sole geometry is a Bezier/BSpline-type curve-on-surface pcurve (no 3D curve) — the common shape of a degenerate edge `BRepBuilderAPI_Sewing` produces reconciling near-coincident vertices between two faces that don't share an edge outright (surfaced sewing two real mesh-derived candidate faces from `kof_ii_engine_cover.stl`). `IntegrationOrder` correctly reads the pcurve's type via `BAC.GetType()` (the curve-on-surface-aware virtual dispatch) but then re-derives the pole count by hand from `BAC.Curve().Curve()` — a completely different, non-virtual accessor that's null whenever there's no 3D curve; down-casting that null handle and calling `->NbPoles()` on it crashes. A from-scratch synthetic degenerate edge (`BRep_Builder` + a hand-built `Geom2d_BSplineCurve` pcurve on a plane, no 3D curve) reproduces the identical crash trace — no real fixture needed to pin the mechanism. **Fixed in v1.12.8**: bridge's small-edge scan now skips degenerate edges outright (`OCCTShapeAnalyze`, immediate fix, any xcframework — a degenerate edge's zero 3D extent isn't a "small edge" defect to flag); kernel patch also carried (`Scripts/patches/0006-*`, xcframework rebuilt): `IntegrationOrder` now calls the adaptor's own (correctly-dispatching) `BAC.NbPoles()` instead. Filed upstream as [OCCT#1381](https://github.com/Open-Cascade-SAS/OCCT/issues/1381) (repro) / [OCCT#1382](https://github.com/Open-Cascade-SAS/OCCT/pull/1382) (fix). #318. **Shipped upstream in OCCT 8.0.1** ([OCCT#1382](https://github.com/Open-Cascade-SAS/OCCT/pull/1382)); patch `0006` retired.
- Three more upstream crash/hang fixes carried proactively (audit of OCCT PRs since our p1 baseline, not discovered via our own crashes — #323, v1.12.9): (1) `ShapeAnalysis_FreeBounds::connectWiresToWiresImpl` (the same helper as the #310 fix above) left a stale `lwire` index when a skipped-loop candidate wire had zero edges (e.g. a wire wrapping a single internal-orientation edge), so the outer loop's termination check never fired and it read invalid memory — `Scripts/patches/0007-*`, backports open third-party [OCCT#1331](https://github.com/Open-Cascade-SAS/OCCT/pull/1331) (fixes OCCT#1330, the "still open" sibling bug noted above). (2) `Geom_BSplineCurve::PeriodicNormalization` used an O(N) `while`-loop to bring an out-of-range parameter back into a periodic curve's range, and could infinite-loop outright once the parameter's magnitude vastly exceeded the period (floating-point no-op on `Parameter -= Period`) — hung `BRepAlgoAPI_Section` on cylindrical shapes; `Scripts/patches/0008-*`, backports merged [OCCT#1329](https://github.com/Open-Cascade-SAS/OCCT/pull/1329) (rewritten to O(1)). (3) `StepData_StepWriter::AddString` looped forever writing a single unbroken raw string longer than the 72-char line buffer (`StepLong`) — no amount of flushing ever made room; `Scripts/patches/0009-*`, backports open [OCCT#1318](https://github.com/Open-Cascade-SAS/OCCT/pull/1318) (splits the token across lines instead), regression test `STEPWriterOversizedNameTests` (`OCCTIOTests`) via `Shape.writeSTEP(to:name:)` with a >72-char name. **All three shipped upstream in OCCT 8.0.1** ([OCCT#1331](https://github.com/Open-Cascade-SAS/OCCT/pull/1331), [OCCT#1329](https://github.com/Open-Cascade-SAS/OCCT/pull/1329), [OCCT#1318](https://github.com/Open-Cascade-SAS/OCCT/pull/1318)); patches `0007`, `0008` and `0009` retired.
- `BOPAlgo_ArgumentAnalyzer`'s self-interference phase (backs `Shape.isSelfIntersecting(hardTimeout:)`) could run unboundedly past its `hardTimeout:` deadline on a pathological artifact — 619s+ CPU against a 30s deadline, never returning. Two compounding causes: (1) `Intf_Interference::Insert` called `Intf_TangentZone::GetPoint(Index)` inside a nested comparison loop; `GetPoint` is O(n) per call (the backing `NCollection_Sequence` has no O(1) indexed access), so every comparison paid that cost again — profiling attributed ~80% of runtime to `NCollection_BaseSequence::Find`. (2) the phase never polled its cooperative progress indicator below `BOPAlgo_CheckerSI::CheckFaceSelfIntersection`, so a caller's timeout could only fire between whole-face checks, not within one — exactly where the artifact got stuck. **Fixed in v1.15.1** (`Scripts/patches/0010-*`, xcframework rebuilt): `Intf_TangentZone::Points()` caches a true random-access array per zone (O(1) lookup); `Intf_Interference::SetBreaker` (thread-local, RAII-scoped via `Intf_InterferenceBreakerScope`) lets `Insert()` poll every 256 calls and abort by throwing `Standard_Failure`, wired up in `BOPAlgo_CheckerSI`'s self-intersect functor only when single-threaded (an exception from an `OSD_Parallel::For` worker thread would risk `std::terminate()`). Verified: a 0.5s deadline now returns in 0.547s and a 30s deadline in 30.1s, correct results throughout. Reproducer at [`Scripts/repro/319-selfintersection`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/319-selfintersection); filed upstream as [OCCT#1385](https://github.com/Open-Cascade-SAS/OCCT/issues/1385) (repro) / [OCCT#1386](https://github.com/Open-Cascade-SAS/OCCT/pull/1386) (fix, CI green on all 3 platforms). #319.
- `ShapeUpgrade_UnifySameDomain::IntUnifyFaces` (backs `UnifySameDomainBuilder.build()`) SIGSEGV'd (Address 0, uncatchable in-process) on a real mesh-sewn solid — found via OCCTReconstruct#194, minimized to a standalone, deterministic OCCTSwift-only reproducer. `IntUnifyFaces` (and its file-local `SplitWire` helper) disambiguate between multiple candidate next-edges at a branching vertex by comparing each candidate's pcurve tangent direction on the current reference face; three call sites fetch that pcurve via `BRep_Tool::CurveOnSurface(edge, refFace, first, last)` and dereference it immediately (`->D1(...)`/`->Value(...)`) with no `IsNull()` check — unlike every other `CurveOnSurface` call site in the same file, which do check. `CurveOnSurface` legitimately returns a null handle when an edge has no pcurve on the given face — routine for a raw mesh-sewn solid at a vertex shared by more than two edges. Confirmed via a debug (`-g -O0`) single-TU override-link + `lldb bt`: resolves precisely to `ShapeUpgrade_UnifySameDomain.cxx:4003` (`aPCurve->D1(...)`), reached via `IntUnifyFaces` → `UnifyFaces` → `Build`. **Fixed in v1.15.8** (`Scripts/patches/0013-*`, xcframework rebuilt): all five unguarded sites (three in `IntUnifyFaces`, two in `SplitWire`) now guard with `IsNull()`, following the file's own established pattern — a missing pcurve on a candidate edge means "skip it, not a rankable direction"; a missing pcurve on the current edge falls back to treating all candidates as equally likely, same as the existing single-candidate shortcut. Reproducer at [`Scripts/repro/348-unify-null-pcurve`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/348-unify-null-pcurve); filed upstream as [OCCT#1391](https://github.com/Open-Cascade-SAS/OCCT/issues/1391) (repro) / [OCCT#1392](https://github.com/Open-Cascade-SAS/OCCT/pull/1392) (fix). #348. **Shipped upstream in OCCT 8.0.1** ([OCCT#1392](https://github.com/Open-Cascade-SAS/OCCT/pull/1392)); patch `0013` retired. 8.0.1 also guards three further null-pcurve sites in the same file and makes `RelocatePCurvesToNewUorigin` return `bool`, so unify can now decline a relocation instead of proceeding with a partial one.
- `GeomTools_Curve2dSet::Add`/`GeomTools_SurfaceSet::Add` accept a null handle and defer the crash to `Write()`, unlike the `GeomTools_CurveSet` sibling: **#643, closed on evidence, no bridge fix needed.** `GeomTools_CurveSet::Add` guards (`return (C.IsNull()) ? 0 : myMap.Add(C);`); the other two don't (`return myMap.Add(S);`), so a null is bound at index 1 and only crashes later, inside `Write()` (`PrintCurve2d`/`PrintSurface` → `->DynamicType()`). `Index()` has the identical divergence one function down: no crash (`FindIndex` never dereferences), but a bogus non-zero index where `CurveSet::Index` correctly answers 0. Cluster C's census (#666, PR #711) found `OCCTGeomToolsCurve2dSetWrite`/`OCCTGeomToolsSurfaceSetWrite` (`OCCTBridge_IO.mm`) already guard every array element before `Add()` (the #618 "array element through a cast" shape) and are the only call sites of either class in the tree; re-verified rather than inherited, both statically (grep confirms one call site each, both guarded) and dynamically (override-linking the real bridge functions against a genuinely null-wrapping struct: refused, not crashed, for a null-only array and a mixed valid+null array). **Upstream asymmetry confirmed still live at the pinned kernel** (`v2.0.0-kernel.1`, re-measured directly, not assumed from the original 8.0.0p1 report) and byte-identical on current upstream `master`. **Fixed upstream, kernel patch carried** (`Scripts/patches/0023-*`, not yet in a rebuilt xcframework, tracked in #512): the same one-line guard `CurveSet::Add`/`Index` already have, applied to `Add`/`Index` on both siblings. Verified by override-linking the two patched files ahead of the unpatched archive: all three classes' `Add()` return 0 for a null handle and `Write()` completes normally; all three classes' `Index()` return 0. Filed upstream as [OCCT#1434](https://github.com/Open-Cascade-SAS/OCCT/issues/1434) (repro) / [OCCT#1435](https://github.com/Open-Cascade-SAS/OCCT/pull/1435) (fix). See [`Scripts/repro/643-geomtools-null-write/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/643-geomtools-null-write) for the full writeup and injection matrix. #643.
- `GeomFill_Sweep::BuildAll` overwrites the measured C1-conversion error with the requested tolerance: **#597, the kernel half** (the bridge half, #741/#751, closed separately, see below). `SError` is set to the real measured error at `GeomFill_Sweep.cxx:286` (`Approx.MaxErrorOnSurf()`), but when `ForceApproxC1` is set and the swept surface isn't already C1 in V, the class re-approximates through `GeomConvert_ApproxSurface(mySurface, theTol, ...)` (`theTol` a literal `1.e-4`) and, on `HasResult()` (documented as true even for a result "not NECESSARILY within the required tolerance"), finishes with `SError = theTol;` instead of reading `MaxError()`, which reports what the conversion actually achieved and sits two lines above, unread. `BRepFill_Sweep`/`BRepFill_PipeShell`/`BRepOffsetAPI_MakePipeShell::ErrorOnSurface()` all forward `SError` verbatim, so `SetForceApproxC1(true)`, a public, documented API, hands every caller a number describing the request, not the result. **Reaching the branch needs a spine whose tangent discontinuity sits inside one edge**, not at a vertex: `BRepFill_Sweep` splits at spine vertices, so a polyline spine never gets there. The fixture (from #572, pinned by `Issue572SweepApproxTests.swift`) is a single-edge degree-2 B-spline spine with an interior knot of multiplicity 2, swept with a circle profile. **Checked, not assumed, that `MaxError()` is the right quantity**: unlike `GeomPlate_MakeApprox::ApproxError()` (the #571 trap, which measures an *intermediate* object and broke 6/6 real tests when gated on), `GeomConvert_ApproxSurface`'s `Surf` argument here *is* `mySurface`, the exact surface being replaced, confirmed by reconstructing the identical call from outside the kernel and finding its output's degree/pole counts and measured deviations bit-identical to the real forced build's. Also confirmed the number **moves**: patch `0019` (#522) is what makes this possible, since before it every interior truncation error was structurally zero; measured `MaxError() = 2.54714` against the pinned kernel, matching #572's own independent measurement of the same fixture to the printed digit, 25000x the `0.0001` the stock code reports. **Fixed** (`Scripts/patches/0025-*`, override-link validated, not yet in a rebuilt xcframework): `SError = ConvertApprox.MaxError();`, one line; the four `CError` literal `0.` entries a few lines above are left untouched rather than fabricated (see #726). Validation confirms this is diagnostic-only: every geometry value the reproducer prints (degree/pole/knot counts, two independent geometric deviations, same-parameter and nearest-point) is byte-identical before and after, since `mySurface` is already `ConvertApprox.Surface()` two statements earlier; no bridge site gates on this number today (`PipeShellBuilder.errorOnSurface` is info-only, and `OCCTGeomFillSweep`'s own error gate from #741 never sets `ForceApproxC1` so never reaches this branch), so `swift test` is unaffected. See [`Scripts/repro/597-geomfill-sweep-error-overwrite/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/597-geomfill-sweep-error-overwrite) for the full writeup. Upstream PR drafted but not sent (`draft-pr.md` in that directory), per `okf/policies/upstream-occt-style.md`. #597.
- **`GeomPlate_MakeApprox::ApproxError()` and `BRepOffsetAPI_MakeFilling::G0Error()` look like the obvious gate for "accepted an approximation without reading its error" (Cluster E, #668), and are not: investigated and rejected on measurement, twice, for two different reasons. This is the bridge half of #597** (the kernel half is immediately above). `occtPlateApproxSurface` (`OCCTBridge_Internal.h`, backs `OCCTShapePlatePoints`/`OCCTShapePlateCurves` + 4 more entry points) and `OCCTShapeFillBuildResult` (`OCCTBridge_Healing.mm`, backs `OCCTShapeFill`/`OCCTShapeFillWithSupport`/`OCCTShapeFillConstraints`) both run an approximation and never check the error it reports, the same shape #741 fixed for `OCCTGeomFillSweep`. Both candidate fixes (`if (approx.ApproxError() > tolerance) return null;` / `if (filling.G0Error() > tolerance) return null;`) were built and run against the real bridge, not just reasoned about, and both broke real, already-shipped, already-tested behaviour. `GeomPlate_MakeApprox::ApproxError()`'s own header doc gives away why the plate site is unfixable this way: it measures distance between the **fitted BSpline and the intermediate `GeomPlate_Surface`** the caller never sees, not fidelity to the caller's own input points. On the #571 fixture it exceeds `tolerance` by up to 5.8x while the deviation from the caller's own 25 input points stays inside tolerance throughout, and gating on it failed all 6 `Issue571PlateApproxTests`. `BRepOffsetAPI_MakeFilling::G0Error()` is the right kind of number for the fill site (`BRepFill_Filling::G0Error()`'s own header: "the maximum distance between the result and the constraints", the caller's own boundary, unlike the plate case) but is still unsafe to gate on: `FillingParameters`'s Swift default is `tolerance: Double = 1e-4`, not a fallback for an unset value, so `Tol3d = 1e-4` is the number **every** default `Shape.fill` call is built at, and legitimate, correct, higher-continuity or heavily-constrained fills routinely exceed it. Gating broke 2 of 17 `FillingSupportFaceTests` (`curvatureContinuityIsAccepted`, `internalConstraintIsNotABoundary`), both at the plain default tolerance, both asserting specific, correct, checked geometry. **A PR #751 review caught that the fill site's own supporting fixture initially understated this**: `wavyEdge()` in `occt_597_fill_g0_realistic.mm` built its sine-sampled boundary points as a single-span, full-multiplicity `Geom_BSplineCurve`, i.e. as control poles of a degree-13 Bezier, which damps a high-frequency control polygon severely (62.8% of the intended amplitude gone, measured directly from the Bernstein basis). Rebuilt on `GeomAPI_Interpolate` (which actually interpolates the sampled points, matching `OCCTCurve3DInterpolate`'s existing precedent in `OCCTBridge_Curve3D.mm`), the same boundary's `G0Error` jumps from "within the bridge's default tolerance" to exceeding even that loosest tested tolerance by ~2000x, and the accepted surface's control poles land up to ~530 units from a ~10-unit-scale boundary. `IsDone()` is still true, and `G0Error()` alone (0.2) does not communicate how far the fit has actually diverged. A draft of this entry then claimed no single `G0Error()` threshold could separate that diverged fit from the two regressing tests, without measuring what those two tests' own `G0Error()` actually were; measured directly (temporary debug prints in both `BRepOffsetAPI_MakeFilling::Build()` call sites, reverted after), they are 5.295e-4 (5.3x tolerance) and 1.231e-3 (12.3x tolerance), two to three orders of magnitude below the corrected fixture's ~2000x. So a fixed absolute threshold placed between those values and the diverged case (e.g. 0.01) would in fact separate them; the honest conclusion is narrower, not reversed: gating on the *caller's own requested tolerance* is unsafe and proven so by the two real regressions, while a *fixed* threshold is unjustified rather than impossible, since nobody has measured what it should be and picking one now would be inventing a number with as little basis as the `1e-4` this investigation already discredited, exactly the failure mode #726 exists to catch. No bridge fix shipped from this investigation; two doc comments (`OCCTBridge_Internal.h` on `occtPlateApproxSurface`, `OCCTBridge_Healing.mm` on `OCCTShapeFillBuildResult`) record why, so the same fix is not silently re-attempted after a future file breakdown (#393-#395) moves either comment. `ShapeUpgrade_UnifySameDomain`'s two bridge sites and `ShapeCustom_BSplineRestriction` were also swept and need nothing: the former exposes no error API at all (confirms #741's finding), the latter already self-polices in the kernel (declines a face's conversion outright rather than ever accepting one out of tolerance). See [`Scripts/repro/597-bridge-modeling-healing-approx-error/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/597-bridge-modeling-healing-approx-error) for the full measurement and [`Scripts/repro/572-approx-consumer-sweep/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/572-approx-consumer-sweep) for Cluster E's own census artifact. #597.
- `BRepOffsetAPI_ThruSections::MakeSolid` marks a loft `Closed(true)` even when it could not actually cap both ends — **#905**. `ThruSectionsBuilder(isSolid: true)` silently omits both end-cap faces for a closed section wire with `k >= 2` periods of out-of-plane variation around the loop (a genuinely non-planar closed curve, not just one with nonzero Z spread): `build()` returns `true`, `shape.checkResult.isValid` is `false`, and `errorCount`/`detailedCheckStatuses` localize nothing. `MakeSolid()` caps each end via `PerformPlan()`, which only fits a plane (`BRepBuilderAPI_FindPlane`) or reuses a surface already attached to the wire's edges (`BRepLib_FindSurface`-backed `MakeFace(wire)`); neither fits a `k >= 2` wire (`k == 1`, e.g. `z = amp * cos(theta)` at constant radius, is secretly planar — the cylinder's intersection with a tilted plane — so it caps fine). `MakeSolid()` already tracks capping success in its own local `B`, threaded through both `PerformPlan()` calls, and discards it: it marks the shell/solid `Closed(true)` unconditionally regardless. Root cause behind #702 (closed): #702 fixed `healed()`/`fixSolid()` silently demoting the resulting invalid solid to a shell while reporting `isValid == true`; this issue is the capping omission #702 never investigated. **A null-face check (`myFirst.IsNull() || myLast.IsNull()`) looks like the fix and is not**: `PerformPlan()` also leaves the output face null, and returns success, when every edge of the wire is degenerate (a single-vertex "point" section from `AddVertex()`, e.g. a cone's apex) — that end needs no cap at all, and a null-face check cannot tell that apart from a genuine failure. Caught by CI on a fork PR staged to catch exactly this before submitting upstream: `BOPAlgo_PaveFillerTest.FuseConeLoftWithBox_DegeneratedEdge` (a circle-to-vertex loft, always legitimately capped) regressed to `IsDone() == false`; reproduced locally byte-for-byte (same failure line and message) before writing the real fix. **Fixed** (`Scripts/patches/0026-*`, override-link validated, not yet in a rebuilt xcframework): after the capping block, nullify both output faces (they alias the caller's `myFirst`/`myLast`, exposed via `FirstShape()`/`LastShape()`; a partial success on one wire before the other fails would otherwise leave a real, never-added face observable after a failed `Build()` — found in this PR's own review, unreachable via OCCTSwift's bridge but a real contract hazard for any other caller) and `throw StdFail_NotDone(...)`, matching the exception this same function already throws for a null shell two lines above — no signature change, no call-site change, since both call sites already run inside `Build()`'s only `try`/`catch`. `GetStatus()` is deliberately left unfixed: it stays `Done` on this path, since fixing it needs either a new out-parameter or a local `try`/`catch` at both call sites (the same multi-site shape the rejected null-face guard had) for a value nothing in this tree reads — `IsDone()` is the correct, and the only checked, signal. Validated against the actual upstream `BOPAlgo_PaveFillerTest.FuseConeLoftWithBox_DegeneratedEdge` (not just an equivalent local test): passes against the patched override, confirming the fix does not reintroduce the first attempt's regression. New GTests in `BRepOffsetAPI_ThruSections_Test.cxx`: `NonPlanarClosedWireCappingFails` (the `k=2` defect, proven to fail against the unpatched override first) and `DegenerateVertexEndStillSucceeds` (the cone/apex regression guard). Filed upstream as [OCCT#1462](https://github.com/Open-Cascade-SAS/OCCT/pull/1462), CI green on all platforms. **Process note**: the fork-PR staging step above ([gsdali/OCCT#1](https://github.com/gsdali/OCCT/pull/1), that fork's first and only PR) was itself a mistake — no other carried patch was ever validated that way, all went straight from local override-link testing to the real upstream PR — and is closed as erroneous; see `Scripts/patches/README.md`'s `0026` entry. **No general capping fix exists here or upstream**: a caller hitting this on a real non-planar loft (e.g. a bevel-gear section) can still assemble one by composition — loft the wall only (`isSolid: false`), pull the open boundary wires via `Shape.freeBoundsOpenWires`, cap each with `FillingSurface`/`Shape.fill` (#430/#433/#434), then sew — since `BRepFill_Filling`'s N-sided patch isn't limited to a plane the way `ThruSections`' own capping is.
- `BRepOffsetAPI_ThruSections::CreateSmoothed` overruns (or, in the opposite direction, silently
  misaligns) its fixed-stride `shapes` array when a section's edge count differs from section 1's —
  **#913**, found incidentally reviewing #910's own fix. `CreateSmoothed()` derives `nbEdges` from
  section 1 alone and allocates `shapes` sized `nbSects * nbEdges`, then fills it walking each
  section's actual edges with no bounds check. `checkCompatibility(true)` (the default) reconciles
  differing edge counts via `BRepFill_CompatibleWires` before `CreateSmoothed()` ever runs;
  `checkCompatibility(false)` skips that, so a later section with a different edge count than
  section 1 either overruns the array (more edges — heap corruption, observed as SIGSEGV **and**
  SIGBUS in different binaries, both genuinely reproduced, not a contradiction to resolve to one —
  see the patch's own writeup) or, with fewer edges landing the running write index back in bounds
  by the end, reports `Build() == true` with per-section strides silently misaligned to the wrong
  geometry (confirmed: `Shape().IsValid() == false` for the accepted result). **Reached only with
  3+ sections**: exactly 2 always takes the `CreateRuled()` path instead, a different mechanism
  that doesn't share this allocation. **Needs no reused builder**: the crash "needing" one was a
  symptom of allocator state at the moment of the overrun, not the cause — a single `Build()` call
  with all mismatched sections from the start carries the identical latent corruption, just
  landing in unmapped-but-harmless heap slack more often than not. **Fixed** (`Scripts/patches/0027-*`,
  override-link validated, not yet in a rebuilt xcframework): before allocating `shapes`, walk every
  non-punctual section and reject on a count mismatch (an inequality test, not a "too many" test —
  deliberately symmetric, since both directions are the same contract violation) with
  `BRepFill_ThruSectionErrorStatus_ProfilesInconsistent`, matching the early-return idiom this
  function already uses two lines below. Punctual end sections (`AddVertex()`, one degenerate edge,
  not zero — an earlier draft of the comment said "zero" and was wrong) stay exempt, matching the
  existing `w1Point`/`w2Point` handling; the exemption additionally verifies the section actually
  has at least one edge before trusting that classification, since `w1Point`/`w2Point` are
  vacuously `true` for a wire with no edges at all — a hardening this project could not reproduce a
  live crash for (tried a fresh and a reused builder both; something downstream already reports
  `IsDone() == false` for that input today, by an unconfirmed mechanism, independent of this patch)
  but kept anyway since it is correct and cheap regardless. Filed upstream as
  [OCCT#1466](https://github.com/Open-Cascade-SAS/OCCT/pull/1466), CI green. See
  `Scripts/patches/README.md`'s `0027` entry for the full writeup, including the two rejected
  test-fixture arithmetic mistakes found en route (a degenerate 2-edge "digon" test that
  accidentally exercised an unrelated shortfall case instead of the reviewer's own carefully-chosen
  no-overrun example, and a zero-edge GTest that was removed rather than kept as unproven coverage).
- `GeomPlate_BuildPlateSurface::G0Error()` / `G1Error()` / `G2Error()` return uninitialised members
  after a `Perform()` whose constraints were all point constraints: **#1018**, the kernel side of
  what made #1015 delete `Surface.plateErrors` rather than repair it. `myG0Error`/`myG1Error`/
  `myG2Error` have no in-class initialiser and none of the three constructors assigns them;
  `VerifSurface()` is the only writer and `Perform()` reaches it only on the branch with at least
  one curve constraint. The point-only branch ends with `VerifPoints(di, an, cu)`, which measures
  the same three deviations into locals and throws them away. **Proved by construction, not by
  staring at odd numbers**: placement-new the class over a buffer filled with `0x5A` and the pattern
  (`1.78388675173e+127` as a double) survives the constructor *and* a point-only `Perform()` in all
  three members, which is only possible if nothing wrote them. On the stack the same fixture gives
  three builds that agree with each other inside one process and disagree with the next process's
  three, and the numbers change again on every run, which is the signature of an uninitialised read
  rather than a wrong computation. `stock.txt` and `stock-second-run.txt` are one such pair, and
  they are deliberately not quoted here: re-running the script produces different ones. **Fixed** (`Scripts/patches/0028-*`, override-link validated, not in a
  rebuilt xcframework), four parts: in-class initialisers for the three members, `Perform()`
  clearing them alongside the `myGeomPlateSurface.Nullify()` it already does on entry, the
  point-only branch keeping what `VerifPoints()` measured (`1.74210553841e-12` on a 25-point wavy
  grid, not `0`), and `VerifPoints()` accumulating a maximum instead of overwriting, which the third
  part needs to be correct rather than being extra scope, since the accessors document a maximum and
  the fixture separates the two (max `1.74210553841e-12` against last `1.57145571589e-12`).
  **The entry reset was not in the first draft**, which argued the gap needed a decision about what
  `IsDone()` should report after a cancel. It does not: the reset changes nothing on either
  successful path, because `VerifSurface()` zeroes the three on the curve branch and the point-only
  branch assigns them, and the PR's own pre-PR review is what caught the overreach. **The curve branch is
  deliberately left unfixed**, and that is the interesting half: `BRepFill_Filling::Build()`
  consumes `G0Error()` for `dmax` (a vertex tolerance) and `seuil` (the
  `GeomPlate_PlateG0Criterion` threshold), so folding point deviations into a mixed build would move
  real geometry, a separate question from the uninitialised read. The reproducer's control confirms
  it does not move: `2.08788369733e-05` curve-only and `0.00104645741524` curve-plus-points,
  identical before and after. **Nothing in this repo is exposed today, by accident rather than by
  design**: `BRepFill_Filling` forwards all three accessors verbatim and `OCCTFillingG0Error` and
  siblings read them, but `Build()` returns early on an empty boundary so its plate always has a
  curve constraint, `myIsDone` follows `myPlate.IsDone()`, and the three bridge functions check
  `IsDone()` first. Three independent facts in two classes, none of them written down as a contract.
  The remaining hole is `Perform()`'s `UserBreak()` return, which leaves `myPlate.IsDone()` true with
  the members never written; `BRepFill_Filling` passes no progress range so it cannot take it, but a
  direct `GeomPlate_BuildPlateSurface` caller can. The in-class initialisers cover the read before
  any `Perform()`, and the entry reset covers a cancelled rebuild that would otherwise hand back the
  previous build's numbers with `IsDone()` still true. Four GTests added to the class's existing
  `GeomPlate_BuildPlateSurface_Test.cxx`, run unfiltered so the file's six pre-existing cases are
  exercised on both sides: 6 passed / 4 failed against unpatched sources, 10 passed patched, each new
  case recomputing its expected value from the built surface rather than hard-coding a
  platform-specific number. The entry reset was isolated on its own rather than trusted to the
  all-or-nothing run: patch applied with only that line removed, exactly one case fails, reporting
  the first build's own `1.7421055384149805e-12`. See
  [`Scripts/repro/1018-geomplate-uninitialised-errors/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/1018-geomplate-uninitialised-errors)
  for the reproducer and the reachability chain, and `Scripts/patches/README.md`'s `0028` entry for
  the full writeup. Filed upstream as [OCCT#1481](https://github.com/Open-Cascade-SAS/OCCT/pull/1481).
- `XCAFDoc_Datum::GetObject` builds the datum point's X from the **annotation plane's** array
  instead of the point's own: **#1022**, a wrong answer and an uncatchable SIGSEGV from the same
  one-character divergence. The `ChildLab_Pnt` block reads `aLoc->Value(aPnt->Lower())`, where
  `aLoc` is the handle the `ChildLab_PlaneLoc` block above it fills;
  `XCAFDoc_GeomTolerance::GetObject`'s otherwise identical block reads `aPnt->Value(aPnt->Lower())`,
  so this is a divergence rather than a shared idiom. **Two faces, deliberately tested separately**:
  a datum written with plane location `(6,6,6)` and point `(7,7,7)` reads back `(6,7,7)`, the stored
  point unrecoverable; and a datum with a point and **no** plane dereferences a null handle, since
  `aLoc` is only ever assigned by the plane block's `FindAttribute`. A guard that stopped only the
  crash would leave the wrong value in place, which is why the value has its own test.
  **Reachability was measured, not inherited from the report**, and it is wider than "read-side":
  since #1004 (PR #1025) hoisted `occtDocumentDatumObjectAt`, **seven** bridge functions route through that one
  helper and five of them are write paths (`OCCTDocumentSetDatumPosition`,
  `OCCTDocumentSetDatumModifiers`, `OCCTDocumentSetDatumModifierWithValue`,
  `OCCTDocumentSetDatumTarget`, `OCCTDocumentSetDatumTargetPlacement`, alongside
  `OCCTDocumentGetDatumInfo` and `OCCTDocumentGetDatumModifier`); the helper calls `GetObject()`
  before any caller can look at the result, so a write that never touches the point still takes the
  crash. A STEP import alone cannot produce the crashing shape: `STEPCAFControl_Reader` sets a datum plane and never a datum point (its only
  `SetPoint` calls are on an `XCAFDimTolObjects_DimensionObject`, a different class). An OCAF load
  can, and the reproducer proves it rather than arguing it, by saving the point-only datum to
  BinXCAF, reloading into a fresh `TDocStd_Application` and crashing on the reload;
  `HasPlane()`/`HasPoint()` are independent flags and `SetObject` writes the two label blocks
  independently, so this is what the public OCCT API produces. Nothing in this repo authors it
  today, because `OCCTDocumentCreateDatum` sets a name, a position and a
  `DatumModifWithValue_None` pair, and nothing that reaches either branch, which is a property of
  the current write surface rather than of the read path. `STEPCAFControl_Writer` calls `GetObject()` on
  every datum in three places, so exporting such a document takes the same crash as reading it.
  **Fixed** (`Scripts/patches/0029-*`, override-link validated, not in a rebuilt xcframework): read
  the point's own array, one character plus a one-line comment. Three GTests added to the existing
  `XCAFDoc_GDT_Test.cxx`: unpatched the run has to be split, because `GdtDatum_PointWithoutPlane`
  takes the whole process down with a SIGSEGV and gtest cannot catch one, so the value case fails in
  a ten-case invocation while the plane-only control and all eight pre-existing cases pass, and the
  crash case exits 139 alone; patched, all eleven pass in one unfiltered run.
  **A bridge-side guard is possible and is tracked as #1030 rather than shipped here**, because
  `OCCTBridge_Document.mm` was held by a concurrent agent when this landed, not because the guard is
  wrong; the crash is uncatchable and `0029` is in no built kernel, so nothing protects a consumer
  meanwhile: the check must precede `GetObject()`, `XCAFDoc_Datum`
  exposes no `HasPlane()`, and `ChildLab_PlaneLoc`/`ChildLab_Pnt` are a file-local anonymous enum,
  tags `14` and `17` at this pin, so any guard hard-codes two private tags upstream can renumber
  with no compile-time signal here. `XCAFDoc_Datum::GetName()` is not a way around it: it returns
  the legacy `myName` that `SetObject` never writes. See
  [`Scripts/repro/1022-datum-point-from-plane-array/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/1022-datum-point-from-plane-array)
  for the reproducer and the full reachability walk. Filed upstream as
  [OCCT#1483](https://github.com/Open-Cascade-SAS/OCCT/pull/1483).

### Carrying OCCT source patches

`Scripts/patches/*.patch` are upstream-bound fixes applied to `occt-src` (idempotently) by `build-occt.sh` before each cmake build. Drop a `git diff` (`-p1`, prefixes `a/`,`b/`) in that dir to carry a new one. Existing build trees (`occt-build-*`) pin a stale macOS SDK sysroot and can no longer incrementally compile — a fresh `cmake` configure (clean build dir) is required to pick up patches.

## Release Process

**The rules below live in `okf/policies/`, not here.** This section says what a release involves and
points at the policy that owns each piece. It does not restate them, because a restated rule is a
copy with no update path, and the version of this section that stood until 2026-08-08 proved it: it
told you to put the CHANGELOG entry in the diff, which
[`changelog-on-merge`](okf/policies/changelog-on-merge.md) forbids.

### What a release is now

Not "~100 new operations". That described the wrapping phase, when each release added a slab of
newly wrapped OCCT surface. v2.0.0 adds almost none: it is a correctness release, built from the
duplication audit (#377) and the five correctness clusters (#669). Read
[`docs/v2.0.0-plan.md`](docs/v2.0.0-plan.md) for the actual scope. The operation count is derived,
not chosen: `python3 Scripts/count-operations.py`.

### The order

1. **Every PR is already merged and its docs already current.** For a repo not yet on stable semver,
   [`docs-current`](okf/policies/docs-current.md) requires docs to ship in the same PR as the
   change, so there is no docs sweep at release. If you find yourself writing docs at release time,
   a PR skipped its own.
2. **Transcribe the CHANGELOG.** Entries were written in each PR body and transcribed at merge, per
   [`changelog-on-merge`](okf/policies/changelog-on-merge.md). At release you are checking the
   `## Unreleased` section is complete, not writing it. `python3 Scripts/check-changelog-transcription.py`
   audits the branch's merge history for entries that never landed.
3. **Assemble `docs/SEMVER.md`.** Per [`semver-at-release`](okf/policies/semver-at-release.md), no
   PR touches that file. It is written once, here, from the `## SemVer impact` statement in every
   merged PR body. This is the first point the whole set is visible and the version number is a real
   decision.
4. **Pin the final kernel.** Re-point `Package.swift`'s `url:`/`checksum:` at the release asset. The
   pre-release kernels (`v2.0.0-kernel.*`) exist so CI builds what the branch's tests are written
   against; the release commit replaces them (#512). Check the patch count in `Package.swift`'s
   comment against `ls Scripts/patches/*.patch | wc -l`: any difference is a patch no CI job has
   ever exercised.
5. **Verify.** Full `swift test`, the five gate scripts with their `--self-test`s, and
   `Scripts/tsan-stress.sh all` if anything touched concurrency.
6. **Counts.** `python3 Scripts/count-operations.py` must agree with README.md and
   `docs/API_REFERENCE.md`. It is a gate; never hand-edit a total to match.
7. `git tag vX.Y.Z`, `gh release create`.

### Adding a wrapped operation

The old numbered workflow described this rather than a release, which is why it read as stale: the
per-operation loop is bridge header, bridge impl, Swift wrapper, test, docs, and it is written up
properly in [`docs/guides/adding-features.md`](docs/guides/adding-features.md). Ground-truth a new
OCCT class first with `/ground-truth`, and put the probe under `Scripts/repro/<issue>/` rather than
`/tmp`, so the evidence survives the session that produced it.

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
- Stay faithful to OCCT: a legitimate feature that isn't a direct wrap of an OCCT operation belongs
  in a downstream ecosystem package, not here — see
  [`okf/policies/scope-boundary.md`](okf/policies/scope-boundary.md)

**Scope note, 2026-08-08.** The second directive is about **wrapping** releases and is left as the
user wrote it. It does not describe v2.0.0, which is a correctness release adding almost no
operations: see [`docs/v2.0.0-plan.md`](docs/v2.0.0-plan.md). Reading it as a target to hit while
working the correctness clusters would be a misreading, and the stale Release Process section that
sat above used to reinforce exactly that. Only the user changes this list.
