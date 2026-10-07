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
the pre-release asset its `url:` names, which is that same `V8_0_1` plus the carried patches that
existed when it was built. Any patch the asset lacks is exercised by **no required check**, because
`build-and-test` resolves the asset rather than building from source; `kernel-integration.yml` is
the one job that builds an unpinned patch, and it proves the patch applies, compiles and regresses
nothing, never that the fix reaches a consumer. Before trusting "the fix is
in the kernel", run
`ls Scripts/patches/*.patch | wc -l` against the count in `Package.swift`'s manifest comment, and
read [`okf/policies/pinned-kernel-patch-check.md`](okf/policies/pinned-kernel-patch-check.md) for
why the count is necessary and not sufficient, and
[`okf/references/carried-occt-patches.md`](okf/references/carried-occt-patches.md) for both counts,
the current divergence and what an unpinned patch leaves exposed. **The numbers themselves are on
that page and not on this one**, per #2954: a count restated in the working summary is a copy that
drifts, and this one drifted for three pins. A divergence with a written
reason is expected; one without is a finding.

**The comparison runs the other way too, and nothing used to make it.** The `v4.0.0-kernel.1` asset
held **thirty-one** patches: the twenty-nine carried then, plus `0032` and the retired
`0034-LocOpe_SplitDrafts-trim-infinite-pipe-curves-1393`, both deleted from `Scripts/patches/` but
never reverted out of the `Libraries/occt-src` tree it was built from, since `build-occt.sh`
applies patches idempotently and never reverts. Both are inert, and the divergence is written up in
`Package.swift`'s pin block and in
[`okf/references/carried-occt-patches.md`](okf/references/carried-occt-patches.md) (#2190). Two
consequences before you act on either number. The tree has since been cleaned, so a **local rebuild
yielded a different checksum from that asset**, which was expected and not a corrupt download. The
asset pinned since `v4.0.0-kernel.4` (now `v4.0.0-kernel.5`) was built from the cleaned tree, and `Package.swift` says what a
mismatch against it means. And `python3 Scripts/check-pinned-asset-patches.py --require-asset` is the check that
reads the binary rather than the prose: about seven seconds over all three slices, deliberately
**not** a `gate-scripts` script (it reads a 1.3 GB xcframework CI does not check out), and part of
the repin step in the Release Process below.

**And there is a SECOND pinned kernel, which a repin also owes.** Since #2269 the wasm build has
its own asset, `libOCCT-wasm.a` plus a header tree, pinned in
[`Scripts/wasm-kernel-pin.txt`](Scripts/wasm-kernel-pin.txt) rather than in `Package.swift`, because
SwiftPM has no `binaryTarget` for a bare static library. **A native repin that does not also rebuild
and republish it puts macOS and the browser on different kernels**, and nothing that reads the
xcframework would notice. `Scripts/check-wasm-kernel-parity.py` is the gate, and it runs in
`gate-scripts` on every PR precisely because the PR that has to be caught is a native repin, which
touches no wasm path. It takes a dated acknowledgement for the 69-minute rebuild, keyed to the native
patch count so it expires at the next repin. It fired on its first real occasion **29 seconds** after
the asset was published; that gap (`0042`) was rebuilt and closed the next day. **Whether they are
apart right now is not stated here**, because a statement of it goes stale at the next repin: an
`ACKNOWLEDGED_*` key in `Scripts/wasm-kernel-pin.txt` is a written divergence, and none is none. The
rule and that story are in
[`okf/policies/pinned-kernel-patch-check.md`](okf/policies/pinned-kernel-patch-check.md); the current
divergence is in
[`okf/references/carried-occt-patches.md`](okf/references/carried-occt-patches.md).

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

**Run `Scripts/format-bridge.sh` after any edit to a bridge `.h`/`.mm`.** Every bridge `.h` and
`.mm` is enforced with nothing grandfathered, because there is no exemption list;
[`okf/policies/code-style.md`](okf/policies/code-style.md) holds the file count. OCCT's style
aligns consecutive declarations and assignments, so two ordinary new locals in a row are a
violation unless the tool wrote them. Hand-aligning is not a substitute. The version is pinned in
`Scripts/clang-format-version.txt`; a clang-format on a different major is refused, since 21.1.8
and 22.1.8 were measured to disagree on 10 of the files. `Scripts/install-clang-format.py` gets
the pinned version onto a machine with no pip or venv; see
[`docs/guides/clang-format-setup.md`](docs/guides/clang-format-setup.md).

### Static Gate Scripts

Gates, censuses and a merge-history audit, all pure Python over the repo's own text. No OCCT, no
build, no network, and the whole job reports in under a minute on the runner. **How many there are
of each kind is counted in [`okf/policies/static-gates.md`](okf/policies/static-gates.md)**, not
here (#2954), along with the measured breakdown and the recipe for re-deriving it rather than
trusting it: this line claimed `~3s for the lot` while the measured figure was about fifteen times
that, and nothing checked it (#2203).
CI runs every gate, plus every `--self-test` including the censuses', in `ci.yml`'s `gate-scripts`
job, a **required status check on `main`**. Each gate exits 1 on a defect and 0 when clean; a census
exits 0 always, so CI runs only its `--self-test`. The job also runs a release check's
`--self-test` and nothing else: `check-pinned-asset-patches.py` reaches a verdict like a gate, but
reads the pinned xcframework to reach it, so its real run belongs to the pin step and it is counted
as neither a gate nor a census. The rules behind the list, the gate/census/release-check
distinction, the pre-commit hook and its one deliberate divergence from CI are in
[`okf/policies/static-gates.md`](okf/policies/static-gates.md); the ruleset rules (never give the
job a `name:` key, never require a check that has not yet reported, `main` takes PRs only) are in
[`okf/policies/required-status-checks.md`](okf/policies/required-status-checks.md).

```bash
python3 Scripts/check-bridge-index.py            # OCCTBridge.h's class → symbol index: stale / misfiled entries
python3 Scripts/check-null-handle-guards.py      # every bridge fn guards the Handle, not just the pointer
python3 Scripts/check-docs-defaults.py           # every default AND enum case list docs/reference/ restates matches its declaration (#2145)
python3 Scripts/check-docs-existence.py          # every symbol docs/ documents as current still exists in Sources (#802)
python3 Scripts/check-borrowed-handles.py        # no struct/enum stores an OCCT*Ref it has no deinit to release (#965)
python3 Scripts/derive-bridge-header-split.py --verify  # every declaration sits in the header its .mm owns (#673)
python3 Scripts/derive-gdt-enums.py --verify      # the GD&T enums still match the pinned XCAFDimTolObjects headers (#996)
python3 Scripts/count-operations.py              # README + API_REFERENCE + docs/index.md totals match the derived count
python3 Scripts/check-throwing-calls.py          # every throwing OCCT construction/evaluator is caught, guarded or unreachable (#1407)
python3 Scripts/check-patch-deletes-guarded-symbol.py  # no carried patch deletes a line whose symbol a test comment guards (#2058)
python3 Scripts/check-bridge-diagnostics.py      # every function-level bridge catch (...) records what it caught (#2077)
python3 Scripts/check-wasm-kernel-parity.py      # the wasm kernel asset carries the same patch set as the pinned native one (#2269)
python3 Scripts/check-preprocessor-balance.py     # no patch unbalances a source file's #if/#else/#endif (#2167)
python3 Scripts/check-wasi-patch-base.py         # every patches-wasi patch was cut from the carried-patch tree (#2168)
python3 Scripts/check-bridge-type-odr.py         # every type defined in more than one bridge .mm is defined identically (#2820)
python3 Scripts/check-bridge-adaptor-members.py # no bridge struct stores an OCCT adaptor beyond the two allowlisted ones (#3065)
python3 Scripts/check-transient-release-idiom.py  # every bridge release of a raw Standard_Transient is opencascade::handle::EndScope (#2974)
python3 Scripts/census-unmeasured-values.py      # CENSUS, not a gate: values returned as measurements that were never computed (#726)
python3 Scripts/census-doc-occt-attribution.py   # CENSUS, not a gate: docs attributing a method to an OCCT class its bridge fn never reaches (#928)
python3 Scripts/census-arguments-tuple-shapes.py # CENSUS, not a gate: @Test(arguments:) elements whose layout trips the toolchain defect (#1057)
python3 Scripts/census-comment-staleness.py      # CENSUS, not a gate: comments naming a symbol/flag/patch that no longer resolves (#872)
python3 Scripts/census-api-reference-rows.py     # CENSUS, not a gate: API_REFERENCE category-row entries resolving to no declaration (#1679)
python3 Scripts/census-dead-file-statics.py      # CENSUS, not a gate: bridge `static` definitions with no use in their own file (#1628)
python3 Scripts/census-compiled-out-validation.py # CENSUS, not a gate: bridge protection resting on an OCCT check No_Exception removed (#2801)
python3 Scripts/check-inventory-prose.py        # every counted claim about the patch, gate, swift-format-exemption, bridge-file and test-target inventories matches them (#1408, #2910), and occt-raise-if-map.txt's stamp names the patch set on disk (#2885)
python3 Scripts/check-changelog-transcription.py # REPORT, never a gate: merges that landed with no CHANGELOG entry (#742, #2779)
python3 Scripts/check-pinned-asset-patches.py --self-test  # RELEASE CHECK: only the self-test runs here; the real run reads the pinned asset (#2190)
```

Run a script's `--self-test` whenever you change it: three gates were confidently wrong while
reporting all clear (#618, #624/#630, #626). `count-operations.py` has no `--self-test` and exits 2
on the option. A handful of scripts exit 2 if run from anywhere but the repo root;
[`static-gates`](okf/policies/static-gates.md) names them (#625).

**Optional pre-commit hook**: `ln -s ../../Scripts/git-hooks/pre-commit .git/hooks/pre-commit` in
the main checkout, or `git config core.hooksPath Scripts/git-hooks` in a linked worktree (its
`.git` is a file, so the symlink fails). CI is the authority; the hook is the preview.

### Merging a PR

```bash
python3 Scripts/merge-pr.py <n> --dry-run   # print every action, change nothing
python3 Scripts/merge-pr.py <n>             # transcribe the entry onto the branch, push, merge
```

**Use it rather than merging by hand.** It extracts the `## CHANGELOG entry` block from the PR body
verbatim, commits it to `docs/CHANGELOG.md` as the last commit on the PR's branch, and merges; a
section saying "None" becomes a `No-Changelog:` trailer on the merge commit instead. That is exactly
what [`changelog-on-merge`](okf/policies/changelog-on-merge.md) asks a merger to do, and three of
five consecutive merges did not do it (#2779). `check-changelog-transcription.py` stays as the
backstop for a merge made without it, and is not a gate: it asks a post-merge question, so as a
required check it would fail every open PR for the previous merge's omission.

**Head the entry descriptively, with its issue numbers.** A bare `### Fixed` / `### Added` /
`### Changed` is refused, because it identifies nothing and so defeats the duplicate test: nine
entries were extracted, printed to the operator and silently discarded between 2026-09-30 and
2026-10-01, with a line each saying the work was already done (#2951). Neither tool now claims an
entry is present without printing where: the merge re-reads `docs/CHANGELOG.md` after the splice
and refuses to push or merge if the entry is not under `## Unreleased`, and the backstop skips a
category heading rather than matching six words that identify nothing. **An entry wrapped whole in
a bare ``` fence is refused too**, because the fence transcribes with it and renders the entry as a
code block; the policy's own worked example is fenced to display it, and copying that literally is
where the shape comes from (#2963). The convention and both
refusals are in [`changelog-on-merge`](okf/policies/changelog-on-merge.md).

### Doc Snippet Type-Check

```bash
python3 Scripts/check-doc-snippets.py              # GATE: every fenced swift snippet in docs/ and /// comments type-checks (#1683)
python3 Scripts/check-doc-snippets.py --run        # ...and RUNS every one that compiles (#2851)
python3 Scripts/check-doc-snippets.py --list       # inventory per kind, no compile
python3 Scripts/check-doc-snippets.py --self-test
```

**Outside `gate-scripts`**, because it compiles the snippets against the built `OCCTSwift` module
and that job is pure Python with no OCCT and no build. It runs in `ci.yml`'s
`swift build + test (macOS)` job, after the build it reuses, in about a minute, and it does not
count toward the gate/census totals above, which are derived from `gate-scripts` alone.

It hands every snippet to `swiftc` rather than matching argument labels with a regex: #1675 holds
two attempts at the regex and a record of how each reported a real API as missing, and a checker
that does that is worse than no checker. **Most fences in the corpus are not snippets at all**: a
signature restatement is uncompilable anywhere, because a bodiless `func` is, and they outnumber
the snippets the gate type-checks; of the snippets, a large minority are fragments opening mid-flow
with a receiver the prose introduced. `--list` prints the population per kind, and
[`static-gates`](okf/policies/static-gates.md#the-detectors-outside-gate-scripts) records the last
measurement of it, dated, because no counted claim about the repository lives on this page
(#2959). A snippet that is deliberately not compilable carries its exemption on the page, in the
fence info string:

    ```swift no-typecheck: a listing of case spellings, not statements

The reason after the colon is required, and it is for a snippet that is uncompilable for a reason
the script cannot derive. An elided placeholder is not one: `= ...`, `{ ... }`, `[...]` and
`= // prose` are recognised as fragments (#2092), so they need no marker and should not carry one.
**It gates**: it was a census while a 211-snippet backlog stood, and was promoted once #2092 and
#2093 took that to zero. In CI both invocations take `--require-typecheck`, which fails the step
rather than reporting on a population it never examined (#2098). A wrong signature *restatement* is
a different question, and `check-docs-defaults.py` covers the enum case of it (#2145).

**It runs them too, since #2851.** Type-checking says an example is a legal program, not that it
works, and the strongest form of "does not work" is that running it takes the process down.
`docs/reference/Surface-Analysis.md`'s `extrema(to:)` example was #2840's crash reproducer,
carrying `≈ 10.0` as its expected answer, and it type-checked clean on every CI run for as long as
#2840's defect existed. It compiles every snippet that type-checks into **one** executable (a link
each would be hours rather than the minute the job takes), which announces each case and takes a
starting index, so the driver restarts it past whatever killed it: a clean corpus is one process
and each defect costs one more. A planted case that **must** die is the canary, the compile
stages' device with its sign flipped, and the working directory is a scratch one, because a
documented example that writes a STEP file writes it into `$PWD`. A snippet that compiles and must
not be run says so on the page, in a marker distinct from `no-typecheck:` because it answers a
different question. **It is the default, off by `--no-run`** rather than on by a flag CI passes,
so a local run and CI cannot check different things; three runs each on one laptop measured a
median 5 s without it and 18 s with it:

    ```swift no-run: writes a 40 MB STEP file

The reason is required, as with the other marker. A snippet that **throws** is not a failure: a
handful do, all of them documented examples reading a `/tmp` path the repo does not ship. It gated
on its
first day because the backlog was two, both fixed in #2852's PR: an untrimmed
`Curve3D.circularHelix` whose `drawAdaptive()` subdivides an infinite domain forever, and an
untrimmed `Surface.cylinder` handed to `Shape.shell(from:)`, which is the User Directive about
infinite surfaces, met in the reference documentation.

**It does not build the module it compiles against, so it checks that module's age (#2816).** A
`.swiftmodule` another branch left in `.build` makes a correct page look broken: an initialiser that
is failable here and was not there reports `initializer for conditional binding must have Optional
type` on every snippet that binds it, which is exactly the three false failures reported on PR
#2799. A module older than any of its own inputs is therefore **refused** rather than compiled
against: exit 2 with or without `--require-typecheck`, naming the file and `swift build`. The inputs
are `MODULE_INPUT_GLOBS`, and it is the extensions that count rather than the directories:
`Sources/OCCTSwift/**/*.swift`, `Sources/OCCTBridge/**/*.{h,mm,modulemap}` and `Package.swift`. A
missing module stays a skip, because a skip is visible to whoever has no build while a stale module
is not. `docs/` is not an input, so editing a snippet never trips it, and CI never meets it, because
the `swift build` step ahead of it recompiles the module on every run.

### Swift Format Lint

```bash
python3 Scripts/check-swift-format.py            # GATE: every tracked .swift file passes swift-format lint --strict, nothing exempt (#2852)
python3 Scripts/check-swift-format.py --list     # the population, lint nothing
python3 Scripts/check-swift-format.py --self-test
```

**Outside `gate-scripts` too**, because it shells out to `swift-format`, which that job does not
have. It runs in `code-style.yml` beside the SwiftLint and clang-format steps, and is counted in no
total on this page.

**The population is `git ls-files '*.swift'`, all of it, not a directory.** Until #2852 this was
four lines of shell walking `find Sources/OCCTSwift`, which reached about an eighth of the repo's
tracked Swift files and no more (both figures, as measured on the day, are in
[`static-gates`](okf/policies/static-gates.md#the-detectors-outside-gate-scripts)): `Tests/`,
`Scripts/`, `Sources/OCCTPlatform`, `Sources/OCCTTest`, `Sources/WASICompat` and `Package.swift`
were outside the step and nothing said so, because an exemption list can only exempt a file the
population already reaches.

**There is no exemption list any more.** The manifests and `check-style-manifest.py` that
grandfathered the files existing at rollout were retired once the last listed file was brought into
compliance, so there is nothing to grow back and no count to keep. A deliberate exception is written
where it occurs, as `// swift-format-ignore: <Rule>` on the declaration with the reason beside it;
`git grep swift-format-ignore` is the complete list. The real run asserts that **the selection
equals every tracked file** and plants a canary violation in every `swift-format` invocation, so a
narrowing and a silent tool are both a red gate rather than a quieter one. There is deliberately no `--fix`, for the reason
`Scripts/format-bridge.sh`'s header gives.

### Pinned-Asset Patch Check

```bash
python3 Scripts/check-pinned-asset-patches.py --require-asset   # the check, at a repin (#2190)
python3 Scripts/check-pinned-asset-patches.py --asset DIR       # ...against a locally built xcframework
python3 Scripts/check-pinned-asset-patches.py --list            # the evidence derived per patch, no asset read
python3 Scripts/check-pinned-asset-patches.py --self-test
```

**Outside `gate-scripts` too**, and for a harder reason than the snippet checker's: it reads a
157 MB static archive per slice out of a 1.3 GB xcframework that CI never checks out. It is a
**release-process step**, run at the moment `Package.swift`'s `url:`/`checksum:` move.

Every other patch count in this repo compares text against text. This one compares the patch set
against the built binary, which is the comparison nothing made until a thirty-one-patch asset
shipped under a twenty-nine-patch label (#2190). It derives, from each patch's own diff, a shipped
header line, a string literal, a `thread_local` wrapper symbol or a name the patch introduces, and
looks for it in all three slices. `--list` prints the verdict per patch, confirmed or not derivable
or absent, and the tally is read there rather than restated in prose (#2954). The not-derivable
rows are real rather than a gap: a patch that changes a comparison adds no name,
and `0033` adds a name that libc++ optimises out of existence at `-O2`, so **absence of a symbol is
never reported as absence of a patch**. A verdict the script cannot reach is printed as one it
cannot reach. Per #2098, `--require-asset` makes a run that examined nothing fail rather than pass.

A divergence with a written reason goes in its `ACKNOWLEDGED` table, keyed on the tag
`Package.swift` pins, so it expires at the next repin instead of suppressing a finding about an
asset nobody wrote it about.

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

**A signature is not a contract.** Where OCCT leaves the meaning of a result open, the answer is how
OCCT's own callers use it, not what we reason out from the callee's source: read
`ShapeProcess_OperLibrary.cxx` and the `src/Draw/` commands in `Libraries/occt-src`, do exactly what
they do, and cite the call site in the comment. The same applies to a **design** choice, not just
to a result: lifetime and ownership, what counts as a programming error, how a condition is
reported, which tolerance to use. Where OCCT has already decided, copy it. Reading `Perform()`'s own return statements, which
three merged PRs did correctly, tells you what the value is and not which value is an error; that
gap left eleven wrappers in one file with two opposite defects (#2769). The rule, where to look and
what to do when OCCT does not answer are in
[`okf/policies/follow-occt-callers.md`](okf/policies/follow-occt-callers.md).

## Architecture

```
Sources/OCCTSwift/          Swift public API (Shape, Wire, Surface, Face, Edge, Curve3D, Mesh, etc.)
Sources/OCCTBridge/include/ C function declarations: the OCCTBridge.h umbrella plus one header
                             per domain (#395)
Sources/OCCTBridge/src/     Objective-C++ implementations. A domain big enough to split becomes
                             OCCTBridge_<Domain>_<Bucket>.mm, bucketed by OCCT subsystem under one
                             shared per-domain header; the rest are a single file each, beside
                             OCCTBridge.mm itself (#396, #1378, #1380)
Libraries/OCCT.xcframework  Pre-built OCCT static library (arm64 macOS/iOS)
Tests/OCCT<Domain>Tests/    Per-domain Swift Testing targets (see "Test Layout")
Scripts/build-occt.sh       Builds OCCT.xcframework from source
```

**The file counts live in** [`docs/architecture/overview.md`](docs/architecture/overview.md) **and
`README.md`**, which both state the header and implementation totals with
`check-inventory-prose.py` holding them to the tree; this page states neither (#2954). For the
current bucketing, `ls Sources/OCCTBridge/src/` is the derivation, and
`python3 Scripts/derive-bridge-header-split.py` is what proves every declaration sits in the
header its `.mm` owns.

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
dereferences the handle, since most such entry points crash uncatchably on a null one. A
function taking an `OCCTShapeRef`/`OCCTWireRef`/`OCCTEdgeRef`/`OCCTFaceRef` guards with
`occtShapeIsPresent(x)` or `occtShapeIsType(x, TopAbs_T)` before any of the ten `TopoDS_Shape`
members that dereference `myTShape`, and before any OCCT entry point measured to
dereference the shape for you (`BRep_Tool::Curve` and family, the `BRepAdaptor_Curve` constructors,
`ShapeFix_Shape::Perform`). Both populations, and the sweep that measured each, are on the policy
page below rather than here (#2959). The guard returns the refusal the function already gives a
wrong-typed input, never a value that reads as a measurement. `check-null-handle-guards.py`
enforces both; where the guard is required, where it is noise, the alias shapes the checker knows
and the ones it is blind to are in
[`okf/policies/null-handle-guards.md`](okf/policies/null-handle-guards.md).

**Where an extracted helper lives is a correctness decision, not a style one.** A `static` helper in
a `.mm` reaches that translation unit and nothing else, so a copy of the same logic in another `.mm`
cannot converge on it. Count the sites across every file before extracting, and put the helper in
`OCCTBridge_Internal.h` as `inline` the moment more than one file holds it. That placement is why
#943's bounds entry point and #957's six document sites each lost a guard their siblings kept, the
second one inside the pass that was auditing for it. The rule, the grep that settles it, and the
case for declining a one-caller helper are in
[`okf/policies/helper-placement-by-reach.md`](okf/policies/helper-placement-by-reach.md).

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
- **Never force-unwrap in `#expect`**: Swift Testing does NOT short-circuit, so
  `#expect(result != nil); #expect(result!.isValid)` crashes the run instead of failing the test.
  **Require the value, do not escape it:**
  ```swift
  let r = try #require(result, "the operation returned nil")
  #expect(r.isValid)
  ```
  `if let r = result { #expect(r.isValid) }` also avoids the crash, and it is the wrong fix for a
  value the test needs: a nil skips every assertion and Swift Testing records a pass for a test
  that executed none. Nine tests shipped that way (#2794). Use `if let` only where nil is itself
  an acceptable outcome, and then assert something in the `else`. See
  [`okf/policies/prove-the-test-fails.md`](okf/policies/prove-the-test-fails.md) → "A setup step is
  required, not escaped".
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
- `OCC_CATCH_SIGNALS` is live inside OCCT and inert in bridge code. OCCT's own translation units
  are compiled with `OCC_CONVERT_SIGNALS`, which its CMake adds on every non-Windows target, so
  OCCT's own sites register a handler and convert a signal into a `Standard_Failure`. SwiftPM
  defines nothing for `Sources/OCCTBridge/src/*.mm`, so an `OCC_CATCH_SIGNALS` written in the
  bridge expands to nothing and registers no handler. An OS signal raised in an OCCT frame with
  none of OCCT's own sites above it is uncatchable in-process, and so is a C++ exception that
  reaches the Swift boundary (#345), which is why every `gp_Dir`/`gp_Ax*`/`Geom_Direction`
  construction from caller doubles sits inside a `try`.
  **A `try` is necessary and not sufficient, and most of OCCT's validity checks are not in the
  kernel at all (#2801).** `No_Exception` is defined for OCCT's own units, so every
  `<Exception>_Raise_if` in a `.cxx` is compiled away and only the inline ones survive. Which of
  the two a member is, nothing in its signature or its documentation says. Both populations are
  counted in
  [`occt-validation-is-compiled-out`](okf/policies/occt-validation-is-compiled-out.md), the page
  that owns them, and `Scripts/census-compiled-out-validation.py --write-table` re-derives them
  from `Libraries/occt-src`; they move at an OCCT bump and at any carried patch that adds a raise
  site, which is what #2885 was about, so they are not restated here (#2959).
  **And an inline check is live only where the bridge itself expands it**: `gp_Ax2(P, N, Vx)`
  documents ConstructionError, has no
  check of its own, and reaches one by building a `gp_Dir` inside `gp_Ax2.cxx`, so it never raises,
  measured. `Geom_Direction` returns `(nan, nan, nan)` (#2331) and `gp_Dir` throws. The largest
  class is `StdFail_NotDone`, and it is overwhelmingly out-of-line, so **test `IsDone()` or
  `Status()` before any `Value()`/`Shape()`/`Solid()`**, which otherwise hands back a null. Guard
  the value before the call, keep the `try`, and read
  [`okf/policies/occt-validation-is-compiled-out.md`](okf/policies/occt-validation-is-compiled-out.md),
  which also records the decision to leave `BUILD_RELEASE_DISABLE_EXCEPTIONS` ON.
  **Do not read that as "the process always dies", measured #2750.** Once `occtEnsureSignals()`
  has run, which any of a good many bridge entry points does once per process, OCCT's own
  `SegvHandler` reaches `Standard_ErrorHandler::Abort`, and the same fault therefore kills one
  process and comes back as a caught `Standard_Failure` in another, depending on nothing the
  caller controls. Guard the fault; never rely on either outcome. The mechanism is the `longjmp`
  branch: `OSD_signal.cxx` is the only translation unit that instantiates that template and OCCT
  compiles it with the define, so `Abort` longjmps to the nearest handler an OCCT site registered,
  or prints and calls `exit(1)` when `FindHandler()` finds none. Measured against the pinned asset
  four ways in [`Scripts/repro/2763-abort-signal-mechanism/`](Scripts/repro/2763-abort-signal-mechanism/),
  which also retires #2750's "plain `throw` with `OCC_CONVERT_SIGNALS` undefined" (#2763).
- **`BRepCheck_Analyzer` is not crash-safe on a shape it did not build.** `Perform()` calls
  `BRepCheck_Edge::InContext(face)`, which dereferences a failed `down_cast<GeomAdaptor_Curve>` on
  a non-degenerated **edge of a face** with no valid 3D curve and at least one pcurve (#2746).
  `Minimum()` reports `NoError` first, only the one owning face whose pcurve became `myCref`
  faults, and a `.brep` file round-trips the state, so an imported shape reaches it. Guarded at
  every bridge construction site by `occtShapeHasPCurveOnlyEdge` /
  `occtShapePCurveOnlyEdgeCount` in `OCCTBridge_Internal.h` (#2750): call one of them before any
  new `BRepCheck_Analyzer`, and answer "invalid" for a whole-shape question or the site's existing
  "could not determine" for a per-sub-shape one. The predicate is **not** "has a null `Curve3D`
  representation", which is false for the shape a `.brep` round trip produces and crashes anyway.
  **It faults a second time, at a different line in the same function, on a disjoint input** (#2789):
  `BRepCheck_Edge.cxx:463` dereferences the face surface it fetched untested at `:336`, in the
  `!pcurvefound` branch that a face with **no surface** always takes, since a null handle is
  handle-equal to no pcurve's. That line is outside both `if (myGctrl)` blocks, so `geometryChecks`
  does not gate it. So **both** predicates go before every analyzer: `occtShapeHasPCurveOnlyEdge`
  **and** `occtShapeHasSurfacelessFace`. Two of those sites are invisible to a grep for
  `BRepCheck_Analyzer`, because `BRepAlgoAPI_Check::Perform` builds one for you
  (`BRepAlgoAPI_Check.cxx:92`): derive the population from the class that **faults**, not the class
  the bridge writes. `BRepCheck_Face::Minimum` answers `BRepCheck_NoSurface` on the same face without
  faulting, which is the status a guarded site reports. The `OCCTBRepCheckFace*` wrappers and
  `checkSubShape`'s `Minimum()`-only checkers need no guard, measured.
- **`ShapeUpgrade_ShapeDivide::Perform()` is not crash-safe on a shape it did not build.** Its
  `TopAbs_FACE` loop hands every face to `ShapeUpgrade_FaceDivide::SplitSurface`, which calls
  `ShapeAnalysis::GetFaceUVBounds`, which dereferences `BRep_Tool::Surface(F, L)` untested in the
  branch it takes when the face has **no edges** (`ShapeAnalysis.cxx:280`, #2773). The loop's own
  `catch (Standard_Failure const&)` encodes `ShapeExtend_FAIL2` for exactly this case and fires only
  where `OSD::SetSignal` has already run, which no divide wrapper and no `.brep` import does. A
  `.brep` round trip preserves the state exactly, so an imported shape reaches it. Guarded at every
  site in `OCCTBridge_Healing_Upgrade.mm` by `occtShapeHasSurfacelessEdgelessFace` /
  `occtShapeSurfacelessEdgelessFaceCount` in `OCCTBridge_Internal.h`, answering the `nullptr` each
  already gives a genuine `ShapeExtend_FAIL`. The predicate needs **both** clauses: a surface-less
  face that carries a wire is handled correctly and must not be refused. STEP drops the face and
  `IGESControl_Writer::AddShape` faults on it, so `.brep` is the only route in.
- **The IGES writer is not crash-safe on the same face, and it needs the WIDER predicate.**
  `IGESControl_Writer::AddShape` runs `XSAlgo_ShapeProcessor::ProcessShape` before it transfers
  anything, and `InitializeMissingParameters` turns on exactly one operation, `DirectFaces`. That
  drives `BRepTools_Modifier`, whose `FillNewSurfaceInfo` calls
  `ShapeCustom_DirectModification::NewSurface` on **every** face with no edge test, and `NewSurface`
  hands `BRep_Tool::Surface(F, L)` straight into `IsIndirectSurface`'s untested `TS->IsKind(...)` at
  `ShapeCustom_DirectModification.cxx:55` (#2777). **So do not reuse
  `occtShapeHasSurfacelessEdgelessFace` here**: a surface-less face carrying a wire exits 139 exactly
  as an edgeless one does, measured. Use `occtShapeHasSurfacelessFace` /
  `occtShapeSurfacelessFaceCount` in `OCCTBridge_Internal.h`, which tests the surface alone, before
  any `IGESControl_Writer`, any `ShapeCustom::DirectFaces` and any `BRepCheck_Analyzer` on the export
  path. OCCT's own STEP writer holds exactly that test (`STEPControl_ActorWrite::hasGeometry`, surface
  clause only), which is why STEP write survives and IGES write does not, and which is the shape the
  upstream fix should take. Two adjacent faults were measured and are separately filed: the same
  shape kills `BRepCheck_Analyzer` when the face carries a wire (#2789, located and guarded, above),
  and `ShapeCustom::SweptToElementary` / `ConvertToRevolution` / `ConvertToBSpline` fault at three
  other lines, now located and guarded (#2790, below).
- **Three more `ShapeCustom` converters fault on the same face, at their own lines, and they take the
  same wider predicate.** `BRepTools_Modifier::FillNewSurfaceInfo` calls `NewSurface` on every face
  with no test of anything, so the answer per operation is whether its own `BRepTools_Modification`
  subclass tests the handle it just fetched. Three do not:
  `ShapeCustom_SweptToElementary.cxx:59`, `ShapeCustom_ConvertToRevolution.cxx:54` and
  `ShapeCustom_ConvertToBSpline.cxx:104` (#2790). Guarded by `occtShapeHasSurfacelessFace` in
  `OCCTBridge_Healing_Fix.mm` and in `OCCTBridge_Healing_Upgrade.mm`, the latter holding the sites
  that drive `BRepTools_Modifier` directly and so are invisible to a search for `ShapeCustom::`
  calls. **Two
  subclasses do hold the test**, `ShapeCustom_BSplineRestriction.cxx:430` and
  `BRepTools_TrsfModification.cxx:73`, which is why `ScaleShape` and `BSplineRestriction` are safe and
  must not acquire a guard, and is the shape the upstream fix should take. Unlike #2773 there is no
  signal disposition under which the kernel survives: `ShapeCustom::ApplyModifier` has no live
  `OCC_CATCH_SIGNALS` above the fault.
- **A NaN linear deflection passes every check `BRepMesh_IncrementalMesh` and its callers make,
  and the mesh it starts does not finish** (#2879). The floor is `Precision::Confusion()` and all
  four sites that state it use a comparison NaN cannot fail: the kernel's own
  `Deflection < Precision::Confusion()` throw (`BRepMesh_IncrementalMesh.hxx:81`), `incmesh`'s
  `std::max(value, Precision::Confusion())` (`MeshTest.cxx:208`), its `-di` refusal on `<=`
  (`:199`) and `Prs3d::GetDeflection`'s same `std::max` (`Prs3d.hxx:71`). Measured: NaN on a
  radius-10 cylinder did not return in 600 s, while 0.0, -1.0 and 1e-12 throw in under a second.
  Call `occtValidMeshDeflection` (`OCCTBridge_Internal.h`) before **any** new
  `BRepMesh_IncrementalMesh`; it is the same bound spelled `>=`. A small deflection is expensive,
  not invalid, and is not refused: the floor value itself finishes in 92 s.
  **The angular deflection beside it has the same hole and a different symptom** (#2900):
  `Angle < Precision::Angular()` at `:99`, NaN walks past, and the result is not a hang but the
  coarsest mesh the linear rule alone accepts, returned with `IsDone()` true (18 nodes for a
  cylinder where a valid angle gives 54 to 254). Call `occtValidMeshAngle` at every site that
  takes a caller angle. `AngleInterior` and `Prs3d_Drawer::DeviationAngle()` need no guard, both
  measured. Both holes are fixed in the kernel by carried patch `0047`, which respells all five of
  `initParameters`' tests; **both bridge guards stay now that it is pinned**, the `0042` exception.
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
- **A `BRepGProp_Sinert`/`Vinert`/`VinertGK` integral needs the face's own `BRepGProp_Domain`**, and
  no overload builds one for you: without it the kernel integrates the surface over its natural UV
  bounds (or, for `Sinert`'s adaptive overload, nothing at all), so a trimmed face over-reports
  (#2204, #2806). `occtLoadFaceDomain` in `OCCTBridge_Properties.mm` is the rule
  `BRepGProp::volumePropertiesFaces` and `volumePropertiesGK` apply. **`BRepGProp_Vinert`'s by-plane
  mass was always exactly 0** whatever you passed, because `BRepGProp_Gauss::convert` discarded it
  (#2827); carried patch `0043` keeps it and is pinned from `v4.0.0-kernel.3`, so the by-plane
  overload now measures the signed volume between the face and the reference plane, summing to the
  solid's volume over a closed shell for any plane. **The kernel then measured it about the plane
  mirrored through the origin** (#2873): its integrand reads `theCoeff[3]` as the right-hand side of
  `n . X = theCoeff[3]` and subtracts it, while the `gp_Pln` conversion at
  `BRepGProp_Vinert.cxx:279` (and `BRepGProp_VinertGK.cxx:219`, `:244`) filled it from
  `gp_Pln::Coefficients`' `d`, which belongs to `n . X + d = 0`. Carried patch `0048` negates the
  stored offset at all five by-plane sites and is pinned from `v4.0.0-kernel.4`, so `planeDistance`
  is an ordinary geometric offset. Until then `OCCTBRepGPropVinertPlane` built the mirrored `gp_Pln`
  itself to compensate; **that mirror was a compensation and not a guard, so the repin that pinned
  `0048` deleted it in the same change (#3015)**, or the sign flips back, which is what
  `BRepGPropVinertTests` caught on #3014. `loc` is a red herring: it cancels, which is what a
  distance to a plane has to do.
- **Retired at the `v4.0.0-kernel.1` repin**, all three, because the pinned asset now carries every
  carried patch: the datum lookup guard in `occtDocumentDatumObjectAt` (#1030, it was refusing a
  datum `0029` makes readable), the `Scripts/tsan.supp` lines for `TopoDS_TShape::myState`
  (`0030`), and the bridge-side arc-length subdivision (`occtAdaptorArcLength`, #603, redundant
  against `0021`). None of their tests could signal that they had outlived their fix, which is why
  this list existed; each now has a regression test that fails if the mitigation comes back.
- **Retired at the `v4.0.0-kernel.5` repin**: the three `OCCTSWIFT_LOCAL=1` gates on
  `Issue3003OffsetOrderTests` (`0053`), `Issue2881FilletObstacleTests` (`0054`) and
  `Issue3039BRepLibPlaneFirstUseTests` (`0056`), which left each test skipped on every default run
  once the asset carried its fix, and the two `tolerance` declarations in the #766 probes
  `766-modeling-evidence-fix` and `766-modeling-issue568-index-skip` that allowed for `0053`'s
  hash-order drift. None of them signalled that it had outlived its fix; each test now runs on
  `build-and-test`. No bridge guard mitigates any of `0053` to `0057`: the SIGSEGV and race are
  past a catch, and the GProp patches fix values nothing in the older bridge read.
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

**A new patch means regenerating `Scripts/occt-raise-if-map.txt` in the same PR.** That map is a
committed derivation of the PATCHED `Libraries/occt-src`, so a patch that adds or moves a raise
site changes it, and nothing re-derived it for two pins: `0042` put a throw in
`ShapeAnalysis::GetFaceUVBounds` and the map said `ShapeAnalysis` held no live throw while the
kernel we ship held one (#2885). `python3 Scripts/census-compiled-out-validation.py --write-table`
rewrites it from the tree `build-occt.sh` patched, and refuses a tree that does not carry every
patch on disk. `check-inventory-prose.py` fails on every PR when the map's provenance stamp and
`Scripts/patches/` disagree, and `kernel-integration.yml`, the one job with a tree, re-derives the
rows themselves.

`Scripts/patches-wasi/*.patch` are a different sequence: WASI-only, unnumbered, not upstream-bound,
and applied by `build-occt-wasm.sh` alone, **after** the carried set. One rule governs them, and
[`okf/policies/wasi-patch-base.md`](okf/policies/wasi-patch-base.md) owns it: a WASI patch is
generated by `git diff` in `Libraries/occt-src` with `Scripts/patches/` already applied, and
verified by `git apply --check` in that same state. PR #2076 authored fifteen against a pristine
`V8_0_1`, which is how nobody noticed that carried patches inject `std::mutex` into OCCT at all,
and that some of the threading-dependent files are files we patch ourselves. That page counts both
populations; this one does not (#2959).
`check-wasi-patch-base.py` holds the text-only part of that; its `--tree` mode runs the real
`git apply --check` and needs a checkout, so it is not in `gate-scripts`.

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
   then **check the asset itself, not the count**:
   `python3 Scripts/check-pinned-asset-patches.py --require-asset`. The count compares prose
   against the tree and is blind to what is baked into the binary, which is how a thirty-one-patch
   asset shipped under a twenty-nine-patch label (#2190). On the machine that built the kernel,
   which is the only one with the tree, also re-derive what the repo has committed **about** that
   tree: `python3 Scripts/census-compiled-out-validation.py --reverify-table --require-occt-src`
   and the same with `--verify-no-exception-regions`, per step 1b of
   [Shipping a rebuild](docs/guides/building-occt.md#shipping-a-rebuild). Nothing did, and
   `Scripts/occt-raise-if-map.txt` went two pins describing a kernel we had stopped shipping
   (#2885). Finally retire the bridge-side mitigations listed under Known OCCT Bugs above.
5. **Verify.** Full `swift test`, every gate with its `--self-test`, and `Scripts/tsan-stress.sh all`
   if anything touched concurrency.
6. **Counts.** `python3 Scripts/count-operations.py` must agree with README.md,
   `docs/API_REFERENCE.md` and `docs/index.md`. Never hand-edit a total to match. The headlines in
   `docs/occtswift-wrapping-gaps.md` and `docs/integration-tests.md` are outside the gate;
   re-derive them with `grep -rn 'operations' docs/ README.md`, which also finds any added since.
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
- **No counted claim about the repository lives on this page**, per #2954 and #2959. A count here
  is shared by every open PR, so a correct edit to the thing counted reds every other branch at
  merge time, and nothing re-derives it. It belongs on the `okf/` page that owns the subject, where
  a gate can read it, and this page links there.
- **A frozen number says when, or says it is frozen**, per
  [`static-gates`](okf/policies/static-gates.md#a-frozen-number-says-when). "The pinned asset holds
  thirty-one patches" and "the `v4.0.0-kernel.1` asset held thirty-one patches" are the same number
  about the same thing, and only the second is a measurement rather than a claim about today.
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
