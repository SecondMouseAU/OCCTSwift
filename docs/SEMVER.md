---
title: Versioning (SemVer)
nav_order: 11
---

# SemVer Policy. OCCTSwift Ecosystem

This document defines how every package in the [OCCTSwift ecosystem](ecosystem.md) versions its releases. It applies to OCCTSwift itself, OCCTSwiftIO, OCCTSwiftMesh, OCCTSwiftViewport, OCCTSwiftTools, OCCTSwiftAIS, OCCTSwiftScripts, and OCCTMCP, and to any future sibling that joins the cohort.

The policy is calibrated to the [SemVer 2.0.0](https://semver.org/) spec with one extension: because OCCTSwift is a wrapper, the bundled OCCT version is part of the consumer-visible contract. An OCCT major version bump is treated as a major event for the wrapper, even if the public Swift API technically didn't break.

## Quick reference

| Bump | Trigger | Examples |
|------|---------|----------|
| **MAJOR** (`x.0.0`) | Upstream OCCT major version bump (e.g. 8.x → 9.x) | OCCTSwift v1.0.0 (pinned to OCCT 8.0 GA, after the v0.x line tracked OCCT 7.8 → 8.0 RCs) |
| **MINOR** (`x.y.0`) | xcframework rebuild against a new OCCT release **OR** additive new public Swift API | A new wrapped operation, a new type, a new bridge function exposed to Swift |
| **PATCH** (`x.y.z`) | Bug fix, internal refactor, doc-only, **no public API surface change** | A `nil`-returning regression repaired, a wrong sort-order fixed, a dependency floor bump |

The load-bearing guarantee is the SemVer guarantee: **no breaking change without a major bump**.
Within a major line, all minor and patch updates are safe to take blindly, with **one** recorded
exception: [v1.17.0](#recorded-exception-v1170-2026-07-29), which breaks source compatibility in two
named places.

**v2.0.0 is a major, so its breaks are not exceptions.** Twelve entries stood in this list as
"recorded exception, Unreleased" while the work was in flight. Every one of them ships in v2.0.0,
where a breaking change needs no exception at all, so they are now [v2.0.0's break
set](#v200) rather than exceptions to anything. That reclassification is the assembly step
[`semver-at-release.md`](../okf/policies/semver-at-release.md) exists to force: the ledger had
grown to thirteen entries of which twelve were about a major that permits breaks outright, and
reviewers had begun faulting PRs for not adding to it.

Read [v2.0.0](#v200) before upgrading from a v1.x. It lists every break in one table, marked as a
compile error or a silent value change, each linked to its measurement and migration.


## Rules

### MAJOR, `x.0.0`

A major bump is reserved for two events, either of which alone is sufficient:

1. **OCCT major version bump.** A new OCCT major (e.g. 9.0) almost always reshapes the C++ API surface enough to force breaking changes in our Swift wrappers (renamed types, deleted classes, redesigned enums). Even when an OCCT major release coincidentally leaves our wrappers unchanged, we still bump major because the bundled binary is part of the contract, consumers are entitled to know the OCCT version changed. The whole cohort majors together.

2. **Breaking change to the public Swift API.** A removed type, a renamed method, a changed return type, a tightened parameter type, a raised platform floor, anything a consumer might have to fix on their side after pinning forward. This is rare within a major line because we promise stability there; if it happens, it triggers a major bump of the affected package (and possibly the cohort, if the change ripples downstream).

The cohort moved to v1.0.0 on 2026-05-07 alongside [OCCT 8.0.0 GA](https://github.com/Open-Cascade-SAS/OCCT/releases/tag/V8_0_0),
and to v2.0.0 under Rule 2, on the accumulated breaks recorded below. v3.0.0 is a further
Rule 2 major on a much smaller set: the kernel does not move, and the breaks are listed
below. v4.0.0 is a third Rule 2 major, on the breaks tabulated under it below, and is in
pre-release as `v4.0.0-beta.5`.

#### v4.0.0

**A major by Rule 2, on a much larger set than v3.0.0.** OCCT does not move: the kernel stays at
`V8_0_1`, rebuilt as `v4.0.0-kernel.4` to carry every patch in `Scripts/patches/` where the v3.0.0
asset carried seventeen. A kernel rebuild is a MINOR trigger at most and forces nothing on its own.
What forces the major is Rule 2, carried by the breaking changes tabulated below.

**The kernel pin of `v4.0.0-beta.5`, a frozen measurement of 2026-10-03.** `Package.swift` pins
`v4.0.0-kernel.4` (#3031). That release carries thirty-nine patches in the native asset and the same
thirty-nine in the wasm asset, with the eleven WASI-only source changes on top of the wasm one, and
`Scripts/check-wasm-kernel-parity.py` reports the two clean with no acknowledgement standing.
`ls Scripts/patches/*.patch | wc -l` and that script re-derive it, and
[`okf/references/carried-occt-patches.md`](../okf/references/carried-occt-patches.md) is where the
inventory is kept.

Many of these breaks share one shape, and it is worth naming because it explains the release:
**a function that could not fail, and did, gains the ability to say so.**
`SAWireAnalysis.checkOuterBound` returns `Bool?` where it returned `Bool`, because a refused check
and a clean verdict were the same answer. `BoundSortBox.compare` returned indices that were off by
one against its own documented contract. `featFuse` and `featCut` silently returned the wrong shape
for every call ever made, and `dividedByNumber` always returned `nil`. None of these had a correct
behaviour to preserve, which is why several have no migration beyond reading the new answer.

`v4.0.0-beta.5` adds more of the same shape, from the hunt for values that read as measurements and
were never computed (#726). A witness point that was a zero where the kernel produced none becomes
`nil` (`Shape.FaceFaceExtrema`, `Shape.CommonPart`, `ExtremaResult`), a `Double` read from outside an
array's range becomes `Double?` (`MathMatrix`, `IntfTool`), and a `Bool` that could not say "not
checked" becomes `Bool?` (`Shape.isSubShapeValid`). Each was a wrong answer a caller could not tell
from a right one, which is the case for making the type say so.

**Two of the breaks recorded through beta.4 were not declared by the PR that made them**, and were
re-derived from the diff while assembling this section, which is the failure mode
[`semver-at-release.md`](../okf/policies/semver-at-release.md) names and accepts. They are marked
below. One of them, `PaperSize`, had also gone undetected in the documentation for months; the gate
that now catches that class is #2145.

**And one declared MAJOR is not in this list, because the change never landed.** #1138's body says
"Consumers calling any of the 14 `SAWireAnalysis` check functions must now handle the optional
return". Its merged diff is nine lines of comment in `OCCTBridge_Healing.mm` plus a census document,
it touches no header and no Swift file, and `checkOrder` and its thirteen siblings return plain
`Bool` today exactly as they did before. Only `checkOuterBound` returns `Bool?`, from #1096.

Checking the claim against the diff is the reviewer's job under that policy and it did not happen
here, so the release assembly is where it surfaced. Every other MAJOR recorded through beta.4 was
then verified against the current source rather than taken from its PR body: all but this one held.
Documenting it would have told consumers to change working code.

**One MINOR is not internal, and is the largest addition in the line: a new platform.** As of
`v4.0.0-beta.4` the package builds and runs on **`wasm32-unknown-wasip1`** (#1689, #2762).

**The wasm work itself is additive by construction**: its edits to `Sources/` are either a header
include that is a no-op where Foundation already supplied it, or guarded behind `os(WASI)` /
`isWASI`, which is what #2762 states and what the full suite passing unchanged demonstrates. That is
a claim about the wasm work, not about the release: twenty-nine `Sources/` files changed since
beta.3 and most did so for unrelated reasons, including the Apple-platform behaviour changes
recorded under #2186 below.

On wasm the surface is the whole public API **except
`Shape.isSelfIntersecting(hardTimeout:)`**, whose contract is a hard wall-clock deadline enforced
from a second thread and which therefore cannot exist on a single-threaded target. A caller wanting
a bound there uses `isSelfIntersecting(timeout:)`, which exists on every platform and whose bound is
cooperative. That difference is the one thing a cross-platform consumer discovers at compile time,
and the decision about it is open (#2760).

Two things a consumer should know before pinning beta.4 or later for wasm. The kernel is a **separate
release asset**, `libOCCT-wasm.tar.gz`, fetched by `Scripts/fetch-occt-wasm.sh` rather than resolved
by SwiftPM, because there is no `binaryTarget` for a bare static library; and the build needs a
consumer-side toolset, which `Scripts/make-wasi-toolset.py` writes. The recipe is
[`guides/wasm-consumer-setup.md`](guides/wasm-consumer-setup.md). **Module size was unaddressed at
beta.4**, at about 27 MB brotli; see the beta.5 paragraph below for what #2839 changed.

**A second MINOR, on Apple platforms**, from retiring three mitigations the kernel repin made
obsolete (#2186): `Document.datum(at:)` and the datum mutators now succeed on a datum carrying an
annotation point with no annotation plane where they returned `nil`/`false`, `dimTolToolToleranceCount`
returns the real count where it returned `0`, and `rescaleGeometry` no longer refuses such a
document. Each is a wrong or withheld answer becoming a correct one, so nothing that worked stops
working, but a caller asserting on the old refusal will see the new value.

**What `v4.0.0-beta.5` adds to the picture.** Its breaks are in
[their own table](#new-in-v400-beta5-every-break-and-what-a-caller-does) below, each with a
migration, and nothing was removed. The other kinds of change are not compile errors and are listed
here, because a consumer upgrading from beta.4 should read them.

**Additive API, MINOR.**

- `BRepGraph.occurrences(of:from:)` and `occurrences(ofNode:from:)`, with `BRepGraph.Occurrence` and
  `BRepGraph.UsagePathStep`: an occurrence-aware lookup that wraps usage paths (#2835).
- `Surface.minDistance(to:uvBounds1:uvBounds2:)`, the distance between parallel surfaces, which
  `Surface.extrema(to:)` still declines to report (#2876).
- `Surface.bezierFill(_:_:_:style:)` and a `Surface.bsplineFill(curves:style:)` taking a triple, the
  three-curve `GeomFill` constructors (#2841, #2842).
- `Messenger.capturingDefaultOutput(_:)`, `Messenger.silencingDefaultOutput(_:)`,
  `Messenger.defaultPrinterCount` and `Messenger.isDefaultOutputCaptured` (#3021).
- `Shape.CommonPart.vertexParameter1` and `vertexParameter2`, the parameters at which OCCT places the
  new vertex of a `.vertex` part (#3012).
- `IntfTool.segmentCount` and `MathMatrix.isSquare`, and a `@discardableResult Bool` return on
  `MathMatrix.setValue(row:col:value:)`, `MathMatrix.transpose()` and
  `GeomDirection.setCoordinates(x:y:z:)` (#2857, #2860, #2331).
- In the C bridge, `OCCTBridgeRefusedReleaseCount` (#2952) and `OCCTTObjApplicationRefCount` (#2897),
  diagnostics for a release the bridge refused, beside the functions behind the Swift additions
  above. A new internal target, `OCCTPlatform`, is neither a product nor re-exported (#2839).

**Values, MINOR: a wrong or fabricated answer becomes a measurement.** No signature moves in any of
these, so nothing stops compiling, and a caller that compensated for the old number will see the
change.

- `Mesh.normals` returns real surface normals where it returned `(0, 0, 1)` at every vertex (#2337).
  The three mesh Booleans, `union(with:deflection:)`, `subtracting(_:deflection:)` and
  `intersection(with:deflection:)`, are documented for what they always did, Booleans on the sewn
  surfaces rather than on volumes (#2301); `Shape.solid(from:)` is the route to the volume answer.
- `Face.surfaceInertia(epsilon:)` returns a real area and centre of mass where it returned `0` and
  `nil`, and `Face.surfaceInertia` returns the trimmed area where it returned the untrimmed patch's:
  a 20 x 20 face with a radius-3 hole moves from 400 to 371.7256661176920 (#2204).
- `Face.volumeInertia` and `Shape.vinertGK(location:tolerance:computeCG:)` integrate the trimmed
  face, so the per-face contributions of a holed plate sum to `Shape.volume` where they overshot it
  by 6 pi (#2806).
- `Face.volumeInertia(planeNormal:planeDistance:)` returns the signed column volume about the plane
  at `planeDistance`, where it returned a fabricated `0.0` with a `nil` centre of mass on both
  platforms at beta.4 (#2827, #2873; carried patches `0043` and `0048`).
- `GeometryProperties.coneSurfaceArea(semiAngle:refRadius:height:)` and `coneVolume(...)` return the
  closed forms. The area was low by a factor of `cos(semiAngle)`, and the volume carried a spurious
  `sin(semiAngle)` and collapsed to zero as the cone approached a cylinder (#2992; carried patches
  `0050` and `0051`).
- `SheetMetal.Builder.build()` returns the correct solid for a stepped seam. It filleted the free
  edge of the wider flange and came out below the flange volume by `r^2 (1 - pi/4)` times the
  surplus length (#2972).
- `BRepGraph.findNode(for:)` and `hasNode(for:)` resolve the sub-shapes of a placed instance to the
  definition node it instantiates, where they returned `nil` and `false` (#2650).

**Refusals, MINOR: input that was answered with garbage is refused.** The return type already
allowed the refusal in each case, so nothing stops compiling.

- The eight `isCN` wrappers, `Curve3D.isCN(_:)`, `Curve3D.bezierIsCN(_:)`, `Curve2D.isCN(_:)`,
  `Curve2D.bsplineIsCN(_:)`, `Surface.isCNu(_:)`, `Surface.isCNv(_:)`, `Surface.bezierIsCNu(_:)` and
  `Surface.bezierIsCNv(_:)`, return `false` for a negative order where they returned `true` (#2862).
- `bezierInsertPoleAfter`, `bezierRemovePole`, `bezierIncreaseDegree`, `setPole(at:point:)` and
  `setWeight(at:weight:)` return `false` where they returned `true` after corrupting the heap.
  `Surface.fromCylinder` and `fromCone` return `nil` for `u2 < u1` or a span past a full turn, where
  they returned a fabricated surface or crashed. `Edge.tangentialDeflectionPoints`,
  `Curve3D.drawAdaptive` and `Curve2D.drawAdaptive` return an empty array for a deflection below the
  kernel's floor, where they returned a fraction of the curve labelled as the whole (#2859, #2861).
- `Document.setBooleanArray(tag:values:)`, `setByteArray`, `setExtStringArray` and
  `setReferenceArray` return `false` for an empty array where they returned `true` and created an
  attribute that could not be reloaded. The PR that did this invited a MAJOR; it is recorded MINOR
  because no input that produced a working result changed (#2866).
- `AssemblyNode.setIntegerArrayValue(at:value:)` and `setRealArrayValue(at:value:)` return `false`
  outside the array's own range, where they wrote out of bounds and returned `true`, and
  `initIntegerArray(lower:upper:)` and `initRealArray(lower:upper:)` refuse `upper < lower` (#2855).
- Every mesh, tessellating-export, proximity, self-intersection, poly-HLR and coherent-triangulation
  entry point refuses a NaN linear deflection, and the meshing entry points refuse a NaN angular
  deflection, each with that call's own documented refusal: `nil`, an empty result, or a thrown
  `ExportError`. A NaN linear deflection started a tessellation that did not return, and a NaN angle
  returned the coarsest mesh with `IsDone()` true. A value below the floor (`1e-7` linear, `1e-12`
  angular) or negative was already refused by the kernel's own throw, so only NaN changes what a
  consumer sees (#2879, #2900).
- `Shape.edgePolyline(at:deflection:maxPoints:)` returns `nil`, and `Shape.allEdgePolylines` and
  `allEdgePolylinesIndexed` return `[]`, for a deflection below `Precision::Confusion()`, where they
  returned a truncated leading sliver of each edge labelled as the whole (#2872).
- `Curve2D.fromEllipseArc` returns `nil` for a sweep of zero or less, past a full turn or with a
  non-finite bound, `CurveProfiler.perform()` returns `false` on an empty profiler where it did not
  return at all, and `CurveProfiler.poles(curveIndex:)` returns `[]` outside `1...n` (#2884).
- `BRepGraph.translated(dx:dy:dz:copyGeometry:)` with `copyGeometry: false` and a non-zero
  translation returns `nil`, where it returned a graph that had not moved (#2913).
- `MathMatrix.invert()` and `transpose()` on a non-square matrix return `false`,
  `MathSolver.uzawa(...)` returns `nil` for more constraints than variables,
  `Shape.scaledAboutPoint(_:factor:)` returns `nil` for a zero factor where it returned a zero-volume
  solid, and `Shape.trsfModification(...)` returns `nil` for a singular 3x3 where it applied a `nan`
  transform (#2860).
- `Curve2D.bezierInsertPoleAfter(_:point:)` and the 3D `insertPoleAfter(index:point:)` accept one
  pole more before refusing, `MaxDegree() + 1`, the count the constructors already allow. That
  arrives with the kernel, as carried patch `0045` (#2875, #3013).

**Crash to refusal, PATCH.** Calls that killed the process on malformed input now return their
documented refusal: the `ShapeCustom` converters on a face with no surface (#2790), four `BRep_Tool`
wrappers on a null shape (#2812), `Surface.bsplineFill(curves:style:)` and
`bezierFill(_:_:_:_:style:)` on four boundary curves that do not close a loop (#2829),
`Surface.extrema(to:)` on two parallel surfaces (#2831), `SewingBuilder.deletedFace(at:)` (#2856),
and four `Document` TNaming lookups on a document that never recorded naming (#766). A crash is not
a contract a caller can have depended on.

**WebAssembly.** `Exporter.writeDXF` and `Exporter.writeSVG` work on `wasm32-unknown-wasip1`, where
every export threw (#2793). The module is about 37 percent smaller: #2839 moved the Swift layer to
`FoundationEssentials` and took it from 26.98 MB to about 16.9 MB brotli, a frozen measurement of
2026-09-29 with byte-identical geometry output. The saving is all or nothing per linked module, so a
consumer keeps it only by making the same import change in its own sources, and the checklist is in
[`guides/wasm-consumer-setup.md`](guides/wasm-consumer-setup.md). The consumer-visible API is
unchanged on every platform, which was checked rather than assumed.

**How the beta.5 set was checked.** Every stated impact was read, and every MAJOR and MINOR was read
against its diff. The public Swift declarations (`Sources/OCCTSwift`) and the C declarations
(`Sources/OCCTBridge/include`) were also parsed at `v4.0.0-beta.4` and at the release commit and
compared, keyed by container, name and argument labels, so that a break nobody declared would show
as a changed declaration with no MAJOR attached. No declaration was removed and no enum case was
added or removed, `SheetMetal.BuildError` included, and every changed Swift declaration traces to a
MAJOR below, apart from the second `bsplineFill` overload (#2888), which is additive. That
comparison is a screen over declarations and not a `swift-api-digester` run, and
it cannot see a changed value behind an unchanged signature: those are the PRs' own statements, read
against their diffs.

**What the C comparison found that the PR bodies did not say.** Several bridge functions changed
signature in PRs that state only their Swift half, and the C structs behind three results gained
fields. They are tabulated at the end of the beta.5 breaks. `OCCTBridge` is a target and not a
product, and it is reachable anyway (#967), so they are breaks for a direct caller and not for one
that goes through `OCCTSwift`.

**Where the assembly disagreed with a PR's own grade.** PRs #2836 (per-face volume integrals),
#2834 (`findNode` on a placed instance), #2868 (the OCAF array setters), #3017 (cone area and
volume), #3022 (a stepped sheet-metal seam) and #3031 (the repin, whose effects are the by-plane,
cone and Bezier bullets above) stated PATCH for a change a caller can observe in a returned value.
They are recorded above as MINOR, because the same shape (#2845, #2808, #2870, #2877) was stated
MINOR by its own authors and one shape should not carry two grades; #2836 said so itself ("MINOR
would be defensible"). A PR that states PATCH for an additive public C function (#2953) is recorded
with #2969, which states MINOR for the same thing. None of this moves the version, since v4.0.0 is a
major already.

**Pull requests with no `## SemVer impact` section.** #2883, #2886, #2922, #2942, #2955, #2973,
#2980, #3001, #3016 and #3023 carry none, and no statement was written for their authors. Each was
read against its diff instead. All but #2886 change no public declaration and nothing a consumer can
reach: a bridge-internal deletion (#2883), documentation, policy and CI only (#2922, #2955, #2973,
#2980, #3001, #3023), tests only (#2942), and two kernel patches (#3016) that #3031 has since
pinned, whose effect reaches a consumer through the repin and is recorded there. #2886 changes
behaviour: its body grades the change MINOR under a "Behaviour change" heading and not under the
required one, and it is recorded above as the `edgePolyline` refusal (issue #2872).

Everything else in this release is internal: the bridge and Swift correctness sweeps (#1413,
#1551), the data-exchange thread-safety series (#1403), the #766 test-quality lift, and the gate
work. Read the entries in [`CHANGELOG.md`](CHANGELOG.md) marked "Internal only" as exactly that.

##### Every break, and what a caller does

| Break | Kind | Detail |
|---|---|---|
| `SAWireAnalysis.checkOuterBound(wire:face:)` returns `Bool?` | compile error | [#1096](#v400-a-refused-check-is-no-longer-a-clean-verdict-1096) |
| `Edge.adjacentFaces(in:)` returns `[Face]?`, was `(Face, Face?)?` | compile error | [#1116](#v400-edgeadjacentfacesin-returns-every-adjacent-face-1116) **undeclared** |
| `PaperSize` cases renamed `.A0`...`.A4` to `.a0`...`.a4` | compile error | [#1103](#v400-papersize-cases-are-lowercased-1103) **undeclared** |
| `WireOrder.Status` drops `.closed`/`.open`/`.gaps`, adds four | compile error | [#1607](#v400-wireorderstatus-reports-what-the-kernel-actually-returns-1607) |
| `AssemblyGraph.NodeType` case names and raw values change | compile error, and wrong data if raw values were stored | [#1604](#v400-two-enums-raw-values-now-match-the-occt-enum-they-mirror-1604-1605) |
| `ViewObject.ProjectionType` raw values change meaning | wrong data if raw values were stored | [#1605](#v400-two-enums-raw-values-now-match-the-occt-enum-they-mirror-1604-1605) |
| `Surface.extremaSSPoint(other:index:)` returns a new type | compile error | [#1530](#v400-extremasspoint-stops-discarding-the-v-parameter-1530) |
| `bsplineMovePointAndTangent(...poleRange:)` retyped on `Curve2D` and `Curve3D` | compile error | [#1561](#v400-bsplinemovepointandtangents-polerange-was-mislabelled-1561) |
| `Shape.fixSmallCurves(tolerance:)` and `.fixSmallBezierCurves(tolerance:)` removed | compile error | [#1526](#v400-two-no-op-entry-points-are-removed-1526) |
| `EdgeCurve` and `WireCurve` lose `@unchecked Sendable` | compile error across a concurrency boundary | [#1406](#v400-edgecurve-and-wirecurve-lose-unchecked-sendable-1406) |
| `OCCTDatumInfo.name` removed from the C header | compile error, C consumers only | [#1084](#v400-the-datum-names-length-is-answerable-1084) |
| GD&T tables move to the `0:1:4` document label | data written by an older version is unreadable | [#1112](#v400-gdt-tables-move-to-the-document-tool-label-1112) |
| `Shape.featFuse(with:)` and `.featCut(with:)` return real geometry | different result, no signature change | [#1467](#v400-four-functions-stop-returning-a-wrong-answer-1467-1471-1526) |
| `BoundSortBox.compare(...)` returns 0-based indices | different result, no signature change | [#1471](#v400-four-functions-stop-returning-a-wrong-answer-1467-1471-1526) |
| `Shape.dividedByNumber(_:)` divides, where it always returned `nil` | different result, no signature change | [#1526](#v400-four-functions-stop-returning-a-wrong-answer-1467-1471-1526) |

##### v4.0.0: a refused check is no longer a clean verdict (#1096)

`SAWireAnalysis.checkOuterBound(wire:face:)` returned `Bool`, and returned `false` both when the
wire was clean and when the check could not be evaluated at all. Those are different answers and a
caller could not tell them apart. It now returns `Bool?`, where `nil` means refused.

The other fourteen `SAWireAnalysis` checks still return plain `Bool` and are unaffected, despite
what #1138's body claims. See the note above.

**Migration.** `if check(...)` no longer compiles. Decide what the call should do for `nil`, which
is new information rather than a renamed old answer:

```swift
// before
if SAWireAnalysis.checkOuterBound(wire: w, face: f) { … }

// after, handling refusal explicitly
switch SAWireAnalysis.checkOuterBound(wire: w, face: f) {
case true?:  // a problem was found
case false?: // no problem
case nil:    // the check could not be evaluated
}

// after, reproducing the old conflation deliberately rather than by accident
if SAWireAnalysis.checkOuterBound(wire: w, face: f) ?? false { … }
```

##### v4.0.0: `Edge.adjacentFaces(in:)` returns every adjacent face (#1116)

**Undeclared by its PR and re-derived from the diff.** The return type changes from
`(Face, Face?)?` to `[Face]?`. The tuple could express at most two faces, and an edge in a
non-manifold shape has more.

**Migration.** Destructuring stops compiling; index or iterate instead.

```swift
// before
if let (a, b) = edge.adjacentFaces(in: shape) { … }

// after
if let faces = edge.adjacentFaces(in: shape) {
    let a = faces.first
    let b = faces.count > 1 ? faces[1] : nil
}
```

##### v4.0.0: `PaperSize` cases are lowercased (#1103)

**Undeclared by its PR and re-derived from the diff.** `PaperSize.A0` through `.A4` are renamed
`.a0` through `.a4`, matching Swift's lower-camel convention for enum cases.

This one is worth reading as a process finding as well as a break. The rename landed inside a merge
PR with no `## SemVer impact` statement, and `docs/reference/Drawing.md` went on restating the old
spelling for months, which seeded seven wrong examples. Nothing caught either half until #2145 added
a gate comparing a restated enum's case list against its declaration.

**Migration.** Lowercase the case name. The raw values are unchanged, so persisted data is not
affected.

##### v4.0.0: `WireOrder.Status` reports what the kernel actually returns (#1607)

`.closed`, `.open` and `.gaps` are removed; `.unchanged`, `.reordered`, `.reversed` and `.shifted`
are added. The old cases were a misreading of `ShapeAnalysis_WireOrder`'s status codes, so an
exhaustive `switch` was switching on meanings the kernel never had.

**Migration.** An exhaustive `switch` over `WireOrder.Status` stops compiling. There is no mapping
from the old cases, because they did not correspond to real states.

##### v4.0.0: two enums' raw values now match the OCCT enum they mirror (#1604, #1605)

`AssemblyGraph.NodeType` changes both case names and raw values. `ViewObject.ProjectionType`
changes raw values only. Both previously disagreed with the OCCT enum they mirror.

**This is the one break in this release that can corrupt data rather than fail a build.** A raw
value persisted by an earlier version, or exchanged with another tool, means something different
now. A caller that only passes the enum around is unaffected.

**Migration.** Re-read any stored raw values through the current API rather than trusting the
number. For `NodeType`, update case names at the call site.

##### v4.0.0: `extremaSSPoint` stops discarding the V parameter (#1530)

`Surface.extremaSSPoint(other:index:)` returned `Curve3D.ExtremaPointPair`, which carries one
parameter per point. A point on a surface needs two, so the V parameter was being dropped. It now
returns `Surface.ExtremaSurfacePointPair`.

**Migration.** `.param1` becomes `.u1`, `.param2` becomes `.u2`, and `.v1` and `.v2` are now
available. An explicit type annotation of `Curve3D.ExtremaPointPair` must change.

##### v4.0.0: `bsplineMovePointAndTangent`'s `poleRange` was mislabelled (#1561)

On both `Curve2D` and `Curve3D`, `poleRange:` is replaced by `startingCondition: Int,
endingCondition: Int`. The two values were never a pole range: they are OCCT's independent
condition codes, and the label was wrong rather than merely unclear.

**Migration.** Same two values, same positions, corrected labels:

```swift
// before
curve.bsplineMovePointAndTangent(…, poleRange: a...b)

// after
curve.bsplineMovePointAndTangent(…, startingCondition: a, endingCondition: b)
```

##### v4.0.0: two no-op entry points are removed (#1526)

`Shape.fixSmallCurves(tolerance:)` and `Shape.fixSmallBezierCurves(tolerance:)` are removed. Both
were confirmed no-ops, so there is no correct behaviour to lose.

**Migration.** Use `Shape.fixSmallEdges(tolerance:dropSmall:limitAngle:)`.

##### v4.0.0: `EdgeCurve` and `WireCurve` lose `@unchecked Sendable` (#1406)

The claim was audited against what the types actually hold and did not survive. Removing it is
source-breaking for any consumer capturing either type across a concurrency boundary: a `Task {}`,
an `async` call, or storage in another `Sendable` type.

**Migration.** There is none beyond the pattern that was already correct: construct one instance per
thread or task, or serialise access with `OCCTSerial.withLock { }`. Code that compiled before was
relying on an unchecked claim, not a checked guarantee.

##### v4.0.0: the datum name's length is answerable (#1084)

C consumers only; no public Swift signature moves. The `name` field is removed from
`OCCTDatumInfo`, because a fixed buffer cannot report that it truncated.

**Migration.** `OCCTDocumentGetDatumName(doc, index, buffer, sizeof(buffer))` returns the length of
the whole identifier, so `>= sizeof(buffer)` means the copy is a prefix and is also the size to
allocate for a second call. `NULL` with `0` asks for the length alone.

Two behaviours change for a Swift consumer, both a wrong answer becoming a correct one. `Datum.name`
returns identifiers longer than 63 characters whole, so code that adapted to the truncation sees
longer strings. `createDimension(...)` returns `nil` for a tolerance pair the document will not
store, where it used to return an index, so a caller that force-unwrapped it now traps instead of
proceeding with a dimension whose tolerance was silently dropped.

##### v4.0.0: GD&T tables move to the document tool label (#1112)

Datums, dimensions and tolerances move from the `0:1` label to `0:1:4`. **Datums in an OCAF document
written by an earlier version of this package become unreadable by the new write path.** The read
path searches both labels, so existing documents stay readable, but anything written now is on the
new label only.

**Migration.** Re-save affected documents with this version to move their datums onto the new label.

##### v4.0.0: four functions stop returning a wrong answer (#1467, #1471, #1526)

No signature changes, so nothing stops compiling. Each returns a different value than it did:

- `Shape.featFuse(with:)` and `.featCut(with:)` never called `BRepFeat_Builder::Perform()`, so every
  call in the library's history silently returned an empty result or the unchanged input. They now
  return the real union and difference.
- `BoundSortBox.compare(...)` returned OCCT's native 1-based indices against a documented 0-based
  contract, which was off by one everywhere and out of bounds for the highest-indexed box. It could
  also truncate silently past 1000 hits. **A caller working around the off-by-one must remove the
  workaround.**
- `Shape.dividedByNumber(_:)` always returned `nil` and now divides.

These are listed as breaks because a caller's output changes, not because their code stops
compiling. There was no correct behaviour to depend on in any of the four.

##### New in v4.0.0-beta.5: every break, and what a caller does

Breaks recorded after beta.4. The table above is unchanged. Each row links to its section.

| Break | Kind | Detail |
|---|---|---|
| `Shape.FaceFaceExtrema`: `face1UV`, `face2UV`, `pointOnFace1` and `pointOnFace2` become Optional, and `isParallel` is added | compile error | [#2249](#v400-three-results-stop-reporting-zeros-as-witness-points-2249-2251-2993) |
| `Shape.CommonPart.point` becomes Optional, and its value changes | compile error, and a different value | [#2251](#v400-three-results-stop-reporting-zeros-as-witness-points-2249-2251-2993) |
| `ExtremaResult.point1` and `.point2` become Optional, and `isParallel` is added | compile error | [#2993](#v400-three-results-stop-reporting-zeros-as-witness-points-2249-2251-2993) |
| `Shape.CommonPart.param1Range` and `param2Range` change value for a `.vertex` part | silent value change | [#3012](#v400-commonpartparam1range-and-param2range-keep-the-kernels-ranges-for-a-vertex-part-3012) |
| `Shape.isSubShapeValid(type:at:)` returns `Bool?` | compile error | [#2755](#v400-shapeissubshapevalidtypeat-can-say-it-did-not-check-2755) |
| `Shape.computeNormals()` returns `Int?` | compile error where the result is a condition | [#2905](#v400-shapecomputenormals-reports-what-it-computed-2905) |
| `GeomDirection.init(x:y:z:)` and `init(simd:)` are failable | compile error | [#2331](#v400-geomdirection-refuses-a-vector-it-cannot-normalise-2331) |
| `MathMatrix.value(row:col:)`, `MathMatrix.determinant`, `IntfTool.beginParam(segment:)` and `endParam(segment:)` become Optional | compile error | [#2857, #2860](#v400-four-accessors-gain-a-refusal-channel-2857-2860) |
| `EdgeAnalysis.checkSameParameter` and `checkVertexTolerance` rename a tuple element | compile error for a caller reading the label | [#2901](#v400-two-tuple-labels-were-the-opposite-of-what-they-said-2901) |
| `Shape.BeanFaceIntersection.minSquareDistance` becomes Optional, and the ranges change | compile error, and a different result | [#2943](#v400-beanfaceintersectionminsquaredistance-is-nil-when-nothing-was-measured-2943) |
| `Document.layerCount` and `layerNames` read the real layer table | silent value change | [#2413](#v400-documentlayercount-and-layernames-read-the-real-layer-table-2413) |
| Bridge functions change signature or nullability | compile error, direct callers of `OCCTBridge` only | [#2331, #2755, #2857, #2860, #2905, #2943](#v400-the-bridge-signatures-that-moved-with-them-2331-2755-2857-2860-2905-2943) |

##### v4.0.0: three results stop reporting zeros as witness points (#2249, #2251, #2993)

Three result types carried values that read as measurements and were never computed. The fields are
now `Optional`, and `nil` is the kernel saying it computed none. The changes are PR #2805
(`FaceFaceExtrema` and `CommonPart`) and PR #3020 (`ExtremaResult`).

- **`Shape.FaceFaceExtrema`** (#2249): `face1UV`, `face2UV`, `pointOnFace1` and `pointOnFace2` become
  optional and the struct gains `isParallel`. `BRepExtrema_ExtFF` appends a square distance and no
  points when the two surfaces are parallel, and the bridge handed the half-written struct over, so
  the four fields arrived as zeros beside a real `distance`. `distance` is kept, because OCCT's own
  callers read it, and on that branch it is the distance between the underlying surfaces rather than
  between the trimmed faces; `minDistance(to:)` answers for the trimmed region.
- **`Shape.CommonPart.point`** (#2251) becomes `SIMD3<Double>?`, **and its value changes.** It was the
  midpoint of `IntTools_CommonPrt::BoundingPoints`, which only `IntTools_EdgeFace` ever sets, so every
  part from `edgeEdgeIntersection(with:)` reported `(0, 0, 0)` and an edge part from
  `edgeFaceIntersection(with:)` reported the chord midpoint, which for a semicircular overlap is the
  circle's centre. It is now the first edge's curve at the representative parameter of `param1Range`,
  a point on the intersection. The `nil` case is a part with no first edge, which neither entry point
  produces today.
- **`ExtremaResult`** (#2993): `point1` and `point2` become `SIMD3<Double>?` and the struct gains
  `isParallel`, on every entry point of `ExtremaElC`, `ExtremaElCS`, `ExtremaPointCurve` and
  `ExtremaPointSurface` that returns it. `Extrema_ExtElC`'s parallel branches set a distance and no
  points, and the zeros that stood in for them were, for a line along a circle's own axis, the
  circle's centre, a point a radius away from every point of the circle. `squareDistance` is real on
  every branch.

**Migration.** Bind the optionals. `nil` means "no witness point for this pair", which the old zeros
were standing in for, and `isParallel` says why:

```swift
// before
let p = result.point1

// after, where the pair cannot be parallel and a nil should stop the program
let p = result.point1!

// after, where it can
if let p = result.point1 { … } else if result.isParallel { /* the gap is result.squareDistance */ }
```

A caller that worked around the zeros must remove the workaround. The C structs behind these gain
matching fields, listed under the bridge signatures below.

##### v4.0.0: `CommonPart.param1Range` and `param2Range` keep the kernel's ranges for a vertex part (#3012)

PR #3043. On a `.vertex` part the bridge overwrote `IntTools_CommonPrt::Range1()` and `Ranges2()(1)` with
`VertexParameter1()` and `VertexParameter2()`, so `param1Range` and `param2Range` reported `(t, t)`
whatever the kernel held. A transversal crossing lost the tolerance window OCCT puts round it, and a
tangential overlap that `IntTools_EdgeEdge::MergeSolutions` types `.vertex` (#2994) lost the overlap
itself: two arcs of one circle sharing a quarter of it reported a single point, `(3pi/4, 3pi/4)`, where
the kernel held `(pi/2, pi)`. **No signature changes and the values do.** Both ranges are now the
kernel's own, for either part type, and the window is not small: 3e-7 across for two lines at right
angles, 3.4e-5 at one degree, 3.4e-3 at one hundredth of a degree.

`CommonPart` also gains `vertexParameter1` and `vertexParameter2`, the parameters at which OCCT places
the new vertex of a `.vertex` part, resolved the way `BOPAlgo_PaveFiller::PerformEE` and `PerformEF`
resolve them. They are `nil` for an `.edge` part, which OCCT never gives one, and always `nil` for the
second edge of an edge-face part, where `param2Range` stays the documented `(0, 0)` (#1399). `point`
follows them, and moves by 8.7e-4 along the curve in one measured corner, a tangent contact at a
closed edge's seam.

**Migration.** A caller that read `param1Range.first` as the crossing parameter of a `.vertex` part
reads `vertexParameter1` instead:

```swift
// before
let t = part.param1Range.first

// after
if part.type == .vertex, let t = part.vertexParameter1 { … }
```

`param1Range` is now the true overlap, or the crossing window, under either part type, which is what
#2994's documentation already claimed.

##### v4.0.0: `Shape.isSubShapeValid(type:at:)` can say it did not check (#2755)

The return type changes from `Bool` to `Bool?` (PR #2837). `BRepCheck_Analyzer::Perform()` walks the
whole parent shape whichever sub-shape the caller asks after, so a parent carrying one of the two
shapes the analyzer cannot survive, a face edge with no valid 3D curve and a pcurve (#2746) or a face
with no surface that carries a wire (#2789), has to be refused before the analyzer is built. The old
`false` for that refusal claimed the sub-shape was invalid, which nothing had measured. `nil` is that
case and only that case; an index that names no sub-shape of that type still answers `false`.

**Migration.** `if shape.isSubShapeValid(type: .edge, at: 0)` stops compiling. For a caller that wanted
a verdict and does not care about the distinction it is one comparison, `== true`, which is what three
call sites in this repository's own tests became.

##### v4.0.0: `Shape.computeNormals()` reports what it computed (#2905)

The return type changes from `Bool` to `Int?` (PR #2920) and `@discardableResult` stays. The `Bool`
was `true` whenever any face carried a triangulation, whether or not the call computed anything, and
since #2337 every face the package meshes already carries normals, so it was unconditionally `true` on
any shape a caller could reach it with. The `Int` is the number of faces whose triangulation gained
normals in this call: `0` is a success that found nothing to do, and `nil` is an empty shape or an OCCT
failure.

**Migration.** A call whose result is discarded compiles unchanged. A caller using the result as a
condition stops compiling: `if shape.computeNormals()` becomes `if let n = shape.computeNormals(), n > 0`
to ask "did it write anything", or `shape.computeNormals() != nil` to ask "did it run". The old `true`
answered neither.

##### v4.0.0: `GeomDirection` refuses a vector it cannot normalise (#2331)

`GeomDirection.init(x:y:z:)` and `init(simd:)` become failable (PR #2799). A zero vector used to
succeed and hand back `(nan, nan, nan)`, because `Geom_Direction`'s zero-length check is an
out-of-line kernel member that the Release kernel compiles away. The refusal and both thresholds are
OCCT's own, from its STEP importer (`StepToGeom::MakeDirection`): a component at or beyond `1e100`,
which takes in `NaN` and infinity, or a squared magnitude at or below `gp::Resolution()` squared.
`setCoordinates(x:y:z:)` now returns a `@discardableResult Bool` and leaves the direction untouched
when it refuses, so existing calls compile unchanged, and `crossed(with:)` on a parallel pair returns
the `nil` it has always been documented to return.

**Migration.** Every construction site unwraps:

```swift
// before
let d = GeomDirection(x: 1, y: 0, z: 0)

// after
guard let d = GeomDirection(x: 1, y: 0, z: 0) else { return }
```

No correct behaviour is removed: the value it used to return for a zero vector was `NaN`. One input
that used to give a usable direction is refused as well, a component at or beyond `1e100`, because
OCCT's own importer refuses it.

##### v4.0.0: four accessors gain a refusal channel (#2857, #2860)

PR #2871. Each returned a bare `Double` that could not say "out of range" or "no answer", and every
`Double` in range is a legitimate value, so no sentinel could have been added without lying.

- `MathMatrix.value(row:col:)` returns `Double?`. An out-of-range 1-based index was an uncatchable
  SIGABRT.
- `MathMatrix.determinant` returns `Double?`. A non-square matrix has no determinant, and the old
  answers were a confident `-1` for a 3x2 and `nan` with the heap corrupted behind it for a 100x1. A
  0x0 is refused too, because OCCT reports its determinant as 1.
- `IntfTool.beginParam(segment:)` and `endParam(segment:)` return `Double?`, `nil` outside
  `1...segmentCount`. On a one-segment clip, `segment: 7` returned segment 1's end parameter as the
  begin parameter of a segment that does not exist, and a large index was a SIGBUS or SIGSEGV.

**Migration.** `m.value(row: r, col: c)` becomes `m.value(row: r, col: c) ?? <your fallback>`, or an
`if let`, and the other three take the same shape. There is no non-breaking form: `0`, the bridge's
old refusal for a null handle, is also a legitimate curve parameter, which was the defect, and #640
settled the same argument for `MathGauss.determinant`.

##### v4.0.0: two tuple labels were the opposite of what they said (#2901)

`EdgeAnalysis.checkSameParameter(_:)` returned `(ok:, maxDeviation:)` and
`EdgeAnalysis.checkVertexTolerance(_:face:)` returned `(ok:, toler1:, toler2:)` (PR #2925). In both,
`true` meant a problem was found, which is `ShapeAnalysis_Edge`'s own convention (its methods end in
`return Status(ShapeExtend_DONE)`, and `DONE` on a `ShapeAnalysis_*` class means a defect was
detected), so `ok` read as the reverse of the truth. The elements are now `problemFound` and
`needsIncrease`. **No value changes.**

**Migration.** Positional destructuring compiles unchanged. A caller reading the label stops
compiling, and was reading it backwards, so the corrected condition is the same expression under the
new name:

```swift
// before
let result = EdgeAnalysis.checkSameParameter(edge)
if result.ok { … }              // meant "a problem was found"

// after
let result = EdgeAnalysis.checkSameParameter(edge)
if result.problemFound { … }    // and checkVertexTolerance's element is `needsIncrease`
```

##### v4.0.0: `BeanFaceIntersection.minSquareDistance` is `nil` when nothing was measured (#2943)

`Shape.BeanFaceIntersection.minSquareDistance` becomes `Double?` (PR #2971).
`IntTools_BeanFaceIntersector` initialises its minimum to `RealLast()` and leaves it there on every
path that never evaluates a distance, which on the pinned kernel is every path, so callers were handed
`1.797e308` as a measurement. **The ranges `Shape.beanFaceIntersect(edge:face:)` returns also change,
for every input:** the search covered an empty interval, and now covers the edge's own parameter range,
which both of OCCT's own callers pass.

**Migration.** Bind the distance; `nil` is what `1.797e308` already meant. The ranges have nothing to
migrate to, because the old ones came from searching nothing.

##### v4.0.0: `Document.layerCount` and `layerNames` read the real layer table (#2413)

No signature moves, and the answer changes for every document (PR #2799). Both read a layer tool
attached to the document's `Main()` label, which enumerates the nine XCAF tool labels as though they
were layers, while the six write-side functions use the layer table at `0:1:3`. So both were wrong for
every document: a fresh one reported nine layers named after tool labels, a layer that had been set
never appeared, and the count depended on which tool labels happened to exist. They now read the table
the write side writes: `0` and `[]` for a fresh document, and the real layers for one that has them.

**Migration.** There is none, because the old list held no layers and code reading it was reading
something else. A caller that branched on `layerCount > 0` or displayed `layerNames` sees different
behaviour with no compiler warning, which is why this is listed as a break.

##### v4.0.0: the bridge signatures that moved with them (#2331, #2755, #2857, #2860, #2905, #2943)

`OCCTBridge` is a target and not a product, and it is reachable all the same (`import OCCTBridge`
compiles in a consumer, #967), so a C or Swift caller of the bridge directly sees these. **None of the
PRs that made them said so**: each states its Swift half only, and #2837 mentions
`OCCTBRepCheckSubShapeValid` alone. They were found by comparing the C headers at `v4.0.0-beta.4` and
at the release commit.

| Function | Was | Is |
|---|---|---|
| `OCCTGeomDirectionCreate` | returns a non-null `OCCTGeomDirectionRef` | returns `_Nullable`, null for a vector it cannot normalise |
| `OCCTGeomDirectionSetCoord` | `void` | `bool`, `false` when it refused |
| `OCCTBRepCheckSubShapeValid` | `bool` | `int32_t`, an `OCCTSubShapeValidity`: `1` valid, `0` invalid, `-1` not checked |
| `OCCTBRepLibComputeNormals` | `bool` | `int32_t`, the faces that gained normals, `-1` on failure; **a C caller testing it as a condition now reads `-1` as true** |
| `OCCTIntToolsBeanFaceIntersect` | five parameters | gains a sixth, `bool* outHasMinSquareDist` |
| `OCCTMathMatrixGetValue`, `OCCTMathMatrixDeterminant` | return `double` | return `bool`, the value through a trailing `double*` |
| `OCCTMathMatrixSetValue`, `OCCTMathMatrixTranspose` | `void` | `bool` |
| `OCCTIntfToolBeginParam`, `OCCTIntfToolEndParam` | return `double` | return `bool`, the value through a trailing `double*` |

`OCCTCommonPart` gains `hasPoint`, `vertexParam1`, `vertexParam2`, `hasVertexParam1` and
`hasVertexParam2`, and `OCCTFaceFaceExtremaResult` and `OCCTExtremaElResult` gain `hasWitnessPoints`
and `isParallel`. That is additive for a reader of the struct, and a Swift caller that builds one
with its imported memberwise initialiser gains parameters.

**Migration.** Read the new return and the out-parameter. The Swift wrappers in `Sources/OCCTSwift` are
the worked examples.

#### v3.0.0

**A major by Rule 2, on a much smaller set than v2.0.0.** OCCT does not move in this release: the
kernel stays at `V8_0_1`, rebuilt as `v3.0.0-kernel.1` to carry two patches the v2.0.0 asset was
missing (#905, #913), which is a MINOR trigger at most and forces nothing. What forces the major is
Rule 2, carried by two changes: an enum rename (#844) and six bounding-box accessors becoming
Optional (#943). The second is the one a consumer is most likely to hit, because `bounds`, `size`
and `center` are read casually.

Almost everything else in this release is internal: duplication passes, refman-coverage audits, and
bridge deduplication, all of which are deliberately non-breaking. Read the entries in
[`CHANGELOG.md`](CHANGELOG.md) marked "Internal only" as exactly that.

##### Every break, and what a caller does

| Break | Kind | Detail |
|---|---|---|
| `Selector.SubShapeType.compsolid` renamed `.compSolid` | compile error | [#844](#v300-selectorsubshapetypecompsolid-is-renamed-compsolid-844) |
| `Shape.ShapeFilterType.RawValue` changes `Int32` → `Int` | compile error *if* the raw type is named | [#844](#v300-selectorsubshapetypecompsolid-is-renamed-compsolid-844) |
| `Shape.bounds`, `Shape.size`, `Shape.center`, `Wire.bounds`, `Edge.bounds`, `Face.bounds` become Optional | compile error | [#943](#v300-bounds-size-and-center-become-optional-943) |

##### v3.0.0: `Selector.SubShapeType.compsolid` is renamed `.compSolid` (#844)

Four independent Swift mirrors of `TopAbs_ShapeEnum` existed with no shared source of truth, and
their casing had already drifted: `ShapeType` spelled it `compSolid`, `Selector.SubShapeType`
spelled it `compsolid`. Consolidating them onto `ShapeType` picks one spelling, and `.compsolid` is
the one that goes.

`Shape.ShapeFilterType` becomes a `ShapeType` typealias in the same change, so its `RawValue` moves
from `Int32` to `Int`. Code that only passes the enum around is unaffected; code that names the raw
type, or stores it, is not.

**Migration.** Rename `.compsolid` to `.compSolid`. If you depend on `ShapeFilterType`'s raw value
being `Int32`, convert explicitly at the boundary:

```swift
// before
let raw: Int32 = filterType.rawValue

// after
let raw = Int32(filterType.rawValue)
```

A third consolidated type, `Shape.TopAbs_ShapeEnum`, is **not** a break: it was briefly deleted
outright, which the aggregate review caught as inconsistent with the compatibility path the other
three got, and it now stands as
`@available(*, deprecated, renamed: "ShapeType") public typealias TopAbs_ShapeEnum = ShapeType`.
Existing code compiles with a warning.

##### v3.0.0: `bounds`, `size` and `center` become Optional (#943)

Six accessors fabricated `(0,0,0)-(0,0,0)` for a shape with no bounding box, which is
indistinguishable from a genuine zero-size shape sitting at the world origin. `Shape.boundingBox`
never had this defect, so the two disagreed about the same `Bnd_Box`.

They now return `nil`, and the verdict is OCCT's own `Bnd_Box::IsVoid()` carried across the bridge
as a `Bool` rather than inferred from the coordinates. Inferring it would have been the same
fabrication relocated: a vertex at the world origin measures exactly `(0,0,0)-(0,0,0)` through
`BRepBndLib::AddOptimal`, so a value-based test cannot tell it from void.

| accessor | was | is |
|---|---|---|
| `Shape.bounds` | `(min: SIMD3<Double>, max: SIMD3<Double>)` | `(min: SIMD3<Double>, max: SIMD3<Double>)?` |
| `Shape.size` | `SIMD3<Double>` | `SIMD3<Double>?` |
| `Shape.center` | `SIMD3<Double>` | `SIMD3<Double>?` |
| `Wire.bounds` | `(min:max:)` | `(min:max:)?` |
| `Edge.bounds` | `(min:max:)` | `(min:max:)?` |
| `Face.bounds`, `Face.exactBounds` | `(min:max:)` | `(min:max:)?` |

**Migration.** Unwrap at the call site:

```swift
// before
let span = shape.bounds.max - shape.bounds.min

// after
guard let b = shape.bounds else { return nil }   // or `shape.bounds?.max`
let span = b.max - b.min
```

`Shape.boundingBox` and `boundingBoxOptimal(_:)` already returned Optional and are unchanged, so
code already using them needs nothing. `AAG` now drops a face with no bounding box instead of
force-unwrapping it, which is a behaviour change only for input that previously crashed.

##### Deliberately not breaks

Recorded because each looks like one and is not, and because answering that question is what this
file is for.

- **`ThruSectionsBuilder.setCriteriumWeight(w1:w2:w3:)` returns `Bool` where it returned `Void`
  (#919).** The method is `@discardableResult`, so existing call sites compile unchanged with no
  warning. Only a code path that forms a reference to the method itself
  (`let f = builder.setCriteriumWeight`) sees a different type, which no shipped consumer does.
- **Three bridge orientation setters stop relying on undefined behaviour (#793).** `OCCTShapeSetOrientation`,
  `OCCTShapeComposed` and `OCCTShapeOriented` used to `static_cast` the caller's raw `Int` to
  `TopAbs_Orientation`, so a value outside `0...3` produced an out-of-range enum. They now saturate
  to `TopAbs_FORWARD`. This changes behaviour only for input that was previously undefined, and the
  Swift surface does not expose a way to pass such a value.
- **`OCCTShapeClean`/`OCCTShapeUpdate` and their `BRepTools`-named twins (#792).** Both names in each
  pair survive; one now forwards to the other. Nothing calling either changes.

#### v2.0.0

**A major by Rule 2, not by Rule 1.** OCCT moved 8.0.0p1 to 8.0.1 in this release, which is a MINOR
trigger on its own and does not force a major (#654). What forces it is the accumulated set of
breaking changes to the public Swift API, listed here in full.

This section replaces the "Held for the next major" list that stood while the work was in flight.
Nothing was deferred out of the release: every entry that was held is below, and the entries that
were taken as recorded exceptions inside the branch are now simply part of the major.

##### Every break, and what a caller does

| Break | Kind | Detail |
|---|---|---|
| 51 public declarations removed, every one previously `@available(*, deprecated)` | compile error | [#784](#v200-51-deprecated-declarations-removed-784) |
| The whole mass-property surface: 12 named signature changes | compile error | #609, [CHANGELOG](CHANGELOG.md) |
| `VinertGKResult.absoluteError` removed | compile error | [#732](#v200-three-fields-removed-rather-than-given-a-second-wrong-value-732-763-771) |
| `ShapeAnalysisResult.selfIntersectionCount` removed | compile error | [#763](#v200-three-fields-removed-rather-than-given-a-second-wrong-value-732-763-771) |
| `BisectorPoint` removed | compile error | [#771](#v200-three-fields-removed-rather-than-given-a-second-wrong-value-732-763-771) |
| `PathParser` removed; `fileExtension`/`trek` had already changed format | compile error | [#499, #784](#v200-pathparser-forwards-to-osdpath-then-is-removed-499-784) |
| `nbEdges`/`nbFaces`/`nbVertices` removed; their values had already been corrected | compile error | [#651, #784](#v200-nbedgesnbfacesnbvertices-forward-to-the-deduplicated-count-then-are-removed-651-784) |
| `continuityOrder` / `surfaceContinuityOrder` are `@available(*, unavailable)` | compile error | [#619](#v200-continuityorder-is-retired-rather-than-reinterpreted-619) |
| `ContinuityAnalysis`'s `isC0`/`isG1`/`isC1`/`isG2`/`isC2` become `Bool?` | compile error | [#495](#v200-junction-analysis-flags-become-optional-495) |
| One meaning for a face index: 0-based, deduplicated, across seven entry points | silent value change | [#541](#v200-one-meaning-for-a-face-index-541) |
| Seven more entry points join the one sub-shape enumeration | silent value change | [#613](#v200-the-last-seven-entry-points-join-the-one-sub-shape-enumeration-613) |
| `wires`/`shells`/`solids` and their counts deduplicate | silent value change | [#502](#v200-the-wiresshellssolids-enumerations-join-the-deduplicated-map-502) |
| An unresolvable sub-shape index refuses the call instead of skipping it | behaviour change, `nil` | [#568](#v200-an-unresolvable-sub-shape-index-refuses-the-call-568) |
| `buildCurves3d`'s default tolerance loosens | silent value change | [#498](#v200-buildcurves3ds-default-tolerance-loosens-498) |
| AAG builds nodes from face occurrences | silent value change | [#642](#v200-aag-builds-nodes-from-face-occurrences-642) |
| AAG adjacency and convexity are scoped to one solid | silent value change | [#699](#v200-aag-adjacency-and-convexity-are-scoped-to-one-solid-699) |
| `chamfer2D` refuses a repeated edge pair instead of crashing | behaviour change, `nil` | [#705](#v200-chamfer2d-refuses-a-repeated-edge-pair-instead-of-crashing-705) |

Each row has its own section below with the measurement and the migration. Additive changes are not
listed here; they are in [`CHANGELOG.md`](CHANGELOG.md).

##### One thing assembly changed about the record

**Two entries below were softened inside the branch and then hardened again by #784.** #499
(`PathParser`) and #651 (`nbEdges`/`nbFaces`/`nbVertices`) were each recorded as a *deprecation*:
both spellings compiled, the call site got a warning naming the change, and `renamed:` pointed at
the replacement. #798 then removed every `@available(*, deprecated)` symbol in the package, those
among them. **As released they are compile errors, and no released version ever contained the
warning.**

This is exactly what [`semver-at-release.md`](../okf/policies/semver-at-release.md) predicts and why
the assessment is made here rather than per PR: a PR cannot see the release it lands in, and neither
of those two PRs was wrong at the time. Their reasoning is kept in place, with a supersession note,
rather than rewritten to match the outcome.

##### v2.0.0: 51 deprecated declarations removed (#784)

Every `@available(*, deprecated)` symbol in `Sources/OCCTSwift` was adjudicated and removed: 51
public declarations, covering 61 deprecated symbols once typealiases and an enum case that were not
independently counted are included, plus one internal bridge function with no Swift-visible surface.

Each carried a `renamed:` or a message with its migration, so a consumer on an older release sees a
compile error naming the replacement rather than a silent behaviour change. The migration table is
in [`CHANGELOG.md`](CHANGELOG.md#61-deprecated-symbols-plus-one-bridge-deprecation-adjudicated-and-removed-784).

Verified as shipped: `grep -r '@available(\*, deprecated' Sources/OCCTSwift` matches nothing. The
four `@available(*, unavailable)` markers that remain are #619's, and they are deliberate: they turn
a retired spelling into an error carrying its migration rather than an unresolved-symbol message.

##### v2.0.0: three fields removed rather than given a second wrong value (#732, #763, #771)

Three public declarations were removed outright rather than repaired, because in each case there was
no correct value to give them:

| Removed | Was | Why not repaired |
|---|---|---|
| `VinertGKResult.absoluteError` | always `0.0`, never computed | A plausible replacement (`errorReached * mass`) reproduces it in the common case and returns the wrong number in OCCT's own near-zero-mass branch. `errorReached` stays, and now carries a real value instead of `0.0` |
| `ShapeAnalysisResult.selfIntersectionCount` | always `0`, never computed | There is no value to migrate to. Use `isSelfIntersecting(timeout:)` for a real check, or delete the read. `analyze(tolerance:selfIntersectionTimeout:)` adds the check opt-in (#772) |
| `BisectorPoint` | a public struct with no public initializer and no in-package factory | No consumer could hold or construct one. Use `bisectorIntersections(a:b:c:d:)` / `BisectorIntersection` |

All three are compile errors for any source naming them. This is the "silent zero" class this
codebase tracks under #605/#609/#522/#726: a value returned as a measurement that was never
measured. Removing it is preferred to inventing a replacement, which is [#726](https://github.com/SecondMouseAU/OCCTSwift/issues/726)'s
whole finding.

#### v2.0.0: junction-analysis flags become optional (#495)

**One source break, taken under the same terms as v1.17.0 above and recorded here before the tag is cut:**

| Break | Issue | What a caller does |
|---|---|---|
| `Curve3D.ContinuityAnalysis` / `Surface.ContinuityAnalysis` expose `isC0`/`isG1`/`isC1`/`isG2`/`isC2` as `Bool?`, not `Bool` | #495 | Compare explicitly (`if a.isG1 == true`), or use `holds(_:)`. Then check the *order*: the value was only ever meaningful for the classes that order measured, and `nil` is now how the API says so |

It is a compile error at every call site, never silent. The exception was taken because:

- It cannot be shimmed. Swift does not overload a property on its type, so the old `Bool` spelling cannot coexist with the new one under the same name, the alternative was leaving five public properties that report `true` for a class nothing measured (a sharp 90° corner reported `isC2 == true`), which is a silent wrong answer, exactly what a SemVer promise is not meant to protect.
- The compile error is the migration prompt. A caller reading `isG1` at the default `.c2` order was reading an uninitialised member; being made to write `== true` is the moment they find out the order has to ask for G1.
- The major version stays reserved for OCCT 9.0.
- Named in [`CHANGELOG.md`](CHANGELOG.md) with before/after code, and to be named in the release notes.

Also in #495, and *not* breaking: `continuityWith`'s `order:` parameter and `Shape.continuityOfFaces` both changed type, and both kept a deprecated overload with the old signature.

#### v2.0.0: `PathParser` forwards to `OSDPath`, then is removed (#499, #784)

> **Superseded at assembly.** The reasoning below describes the state this change shipped in
> *within the branch*: a deprecation, a warning at each call site, and both spellings still
> compiling. **#784/#798 then removed every `@available(*, deprecated)` symbol in the package,
> `PathParser` among them.** As released, this is a compile error, not a warning, and the migration
> is to `OSDPath` directly rather than to a forwarder. The two format changes below are still the
> substance of what a caller must adjust; only the prompt changed, from a warning naming the format
> to an error naming the type. Kept rather than rewritten because the reasoning is the record of why
> the softer option was chosen at the time, and #798 unmade the premise rather than the argument.

**Two behaviour changes, and at the time these were *not* compile errors.** Recorded before the tag was cut:

| Break | Issue | What a caller does |
|---|---|---|
| `PathParser.fileExtension(_:)` returns `".step"`, not `"step"` | #499 | Drop the caller's own dot, or strip the leading `.` |
| `PathParser.trek(_:)` returns `"/home/user/"`, not `"/home/user"` | #499 | Nothing, if the result is joined with a separator; otherwise trim the trailing `/` |

Both spellings still compile and still return a value; the deprecation attribute on each method raises a warning at every call site naming the exact format change, and `renamed:` points at the `OSDPath` method that now does the work. The exception was taken because:

- The disagreement *is* the bug. `PathParser.fileExtension` and `OSDPath.fileExtension` answered the same question in two formats, each pinned by its own test, neither compared to the other. Keeping both formats (by having `PathParser` strip what `OSDPath` returns) would have deduplicated the implementation while preserving the divergence the issue was filed about.
- The same forwarding fixes four cases where `TDocStd_PathParser` was wrong rather than differently formatted: an extension-less path parsed to an empty name *and* empty directory, a dotfile inside a directory returned `nil` from every accessor, a dot in a directory name was read as the file's extension, and non-ASCII paths came back mangled. Those four are ordinary PATCH-class fixes ("a method that returned `nil` when it shouldn't"); only the two formats above are a break.
- A warning, not an error, is the weaker prompt, stated plainly here rather than claimed otherwise. It is what the API allows: Swift cannot overload on return *value*, only on type, so there is no spelling in which the old format survives alongside the new one.
- Named in [`CHANGELOG.md`](CHANGELOG.md) with before/after code, and to be named in the release notes.

#### v2.0.0: one meaning for a face index (#541)

**Six silent behaviour changes, none a compile error.** Every one moves an index toward the single contract now stated on `Shape.faceCount`: a sub-shape index into a shape is a 0-based position in the enumeration `faces()` / `faceCount` / `face(at:)` all read. Recorded here before the tag is cut:

| Break | What a caller does |
|---|---|
| `Shape.faces()` returns one entry per *distinct* face, not per occurrence | Nothing on any shape that shares no face. On one that does, the result of a split, an imprint, a compound of a shape with itself, the array is shorter and the surplus `Face.index` values are gone. They named faces `face(at:)` could not address, and past the duplicate they named the *wrong* face |
| `adjacentFaces(forEdge:)` / `adjacentEdges(forVertex:)` return 0-based indices | Drop the caller's own `- 1`. A caller who never subtracted was reading the neighbouring sub-shape |
| `splitByWireOnFace(_:faceIndex:)` takes 0-based, so its domain is `0..<faceCount` not `1...faceCount` | Subtract 1 from a hand-written index |
| `buildWires(faceIndex:)` takes 0-based; the "every edge" sentinel is any negative value, was `0` | Nothing if the default is used, it changed from `0` to `-1` and still means every edge. A caller passing `0` explicitly now gets face 0's edges |
| `offsetPerFace(defaultOffset:faceOffsets:)` keys are 0-based, and an out-of-range key fails the call instead of being skipped | Subtract 1 from hand-written keys. A call that silently ignored a bad key now returns `nil` |
| `EvolvingFilletEdge.edgeIndex` is 0-based; `Selector.PickResult.subShapeIndex` is 0-based with `-1`, not `0`, for the whole shape; `meshTriangleAdjacency`/`meshNodeTriangle`/`meshNodeTriangleCount` take a 0-based `faceIndex` (their triangle and node indices stay `Poly_Triangulation`-native 1-based, as do the triangle indices they return) | Subtract 1 from hand-written indices; compare `subShapeIndex` against `-1` rather than `0` |

The exception was taken because:

- **The disagreement is the bug, and it was not only cosmetic.** Measured on the pinned kernel (`Scripts/repro/541-face-index-contract/`): one `BRepAlgoAPI_Splitter` run cutting a box with a plane leaves 12 face occurrences over 11 distinct faces, and because the duplicate is not last, `faces()` and `face(at:)` named **different faces** from index 10 onwards. A caller selecting a face from `faces()` and passing it to `drafted(faces:)`, `shelled(openFaces:)` or `withoutFeatures(faces:)`, all map-backed, operated on a face it had not selected, with no error. Preserving any of the old conventions would have preserved that.
- **There is no spelling in which both survive.** These are index *values*, not types or names, so Swift cannot overload on them and a deprecation attribute has nothing to attach to. The alternative to changing them is documenting that five different meanings of "face index" coexist and leaving callers to track which is which per method.
- **On every shape that shares no sub-shape, nothing moves.** The probe checks the enumeration order face-by-face rather than by count across ten such fixtures: identical at every index. The `faces()` change is invisible to a caller whose shapes are primitives, booleans, sewn sheets or compsolids.
- Named in [`CHANGELOG.md`](CHANGELOG.md) with the measurement, and to be named in the release notes.

#### v2.0.0: an unresolvable sub-shape index refuses the call (#568)

**Five silent behaviour changes, none a compile error.** A sub-shape index naming nothing now rejects the whole request, finishing the sweep #520 began for the fillet family and #541 for `offsetPerFace`:

| Break | What a caller does |
|---|---|
| `drafted(faces:direction:angle:neutralPlane:)` returns `nil` when a `Face.index` names no face of the receiver | Pass only faces taken from this shape, or filter against `faces().count`. A call that drafted the faces that resolved now returns `nil` |
| `shelled(thickness:openFaces:)` likewise | Same. A call that opened fewer faces than asked for now returns `nil` |
| `chamferedWithFullHistory(distance:edges:)` returns `nil` on an edge index outside `0..<edges().count` | Same as `filletedWithFullHistory`, which already behaved this way after #520 |
| `fillet2D(vertexIndices:radii:)` returns `nil` on a vertex index the first face does not have | Filter against that face's `vertices().count` |
| `chamfer2D(edgePairs:distances:)` returns `nil` when *either* half of a pair is out of range | Filter against that face's `edgeCount` |

The exception was taken because:

- **The old answer was unobservable.** Measured on the pinned kernel (`Scripts/repro/568-index-skip-idiom/`), every builder behind these five reports an ordinary success for a batch it was never told was short: `IsDone`, non-null, `BRepCheck_Analyzer`-valid. A partial chamfer of a 20mm box measures 7922.666667 against the complete 7885.333333, and nothing but re-measuring the geometry distinguishes them.
- **One of the five did not honour any of the request.** `BRepOffsetAPI_DraftAngle` handed no faces at all still reports `IsDone()` and returns the input unchanged, so `drafted(faces:)` with a list of foreign faces succeeded and drafted nothing.
- **There is no spelling in which both survive.** As with #541, this is a *value* contract, not a type or a name: Swift cannot overload on it and a deprecation attribute has nothing to attach to. A caller who wants the old best-effort behaviour can filter its own indices, which is the same work done deliberately instead of silently.
- **A request naming only valid indices is unaffected**, which is pinned by a positive-control test per entry point.
- Named in [`CHANGELOG.md`](CHANGELOG.md) with the measurements, and to be named in the release notes.

#### v2.0.0: the last seven entry points join the one sub-shape enumeration (#613)

**Eight silent behaviour changes, none a compile error.** #541 put sub-shape indexing on the deduplicated `TopExp::MapShapes` enumeration and #568 settled what an unresolvable index does; seven entry points were left counting `TopExp_Explorer` *occurrences*. A plain 10 mm box has **24 edge occurrences over 12 edges** and **48 vertex occurrences over 8 vertices**, so each of these answered for indices `edge(at:)` refuses, and named a different sub-shape past the first repeat:

| Break | What a caller does |
|---|---|
| `edgeConcavities(angle:)` labels are realigned onto `edges()` | Nothing to change, but the answers move. Measured on an L-bracket: the one concave edge (index 27) was labelled convex and `concaveEdges()` returned `[]`. It now returns `[27]`. A caller who had worked around the old labels by hand should drop the workaround |
| `edgeConcavityCount(_:angle:)` counts edges, not occurrences | Expect roughly half the previous number. A 12-edge box reported **24** convex edges and now reports 12. A caller comparing it against `edgeCount` was always failing |
| `edgeEdgeExtrema(edgeIndex1:other:edgeIndex2:)` indexes `edges()` | Nothing on indices `0..<edgeCount` up to the first repeat; past it the answer now describes the edge the caller named. Indices `edgeCount..<24` return `nil` instead of an answer about some other edge |
| `checkEdge(at:)`, `checkWire(at:)`, `checkShell(at:)`, `checkVertex(at:)` | Same domain as `edge(at:)` / `subShapeCount(ofType:)` now. `checkEdge(at: 12)` on a box reported a valid edge and now reports invalid, matching `isSubShapeValid(type:at:)`, which has been map-backed since #541 |
| `splitEdge(at:parameter:)` splits the edge `edges()` names | Indices `0..<9` on a box are unchanged; 9, 10 and 11 now split the edge asked for rather than a different one, and 12…23 return `nil` |
| `edgesInFace(at:)` and `commonEdges(with:)` return a real `Edge.index` | The `index` on every returned `Edge` changes value. It was the position in the result array, so it addressed a different edge, or none. `edgesInFace(at: 3)` on a box handed back 0, 1, 2, 3 for edges whose indices are 2, 6, 10 and 11, so all four named a different edge. A caller that used the old value as an array subscript into its *own* parallel array must switch to enumerating the result |
| `biTgteBlend(edgeIndices:radius:tolerance:nubs:)` indexes `edges()`, and refuses an unresolvable index | Both a #541-class and a #568-class change in one site. Measured on an L-bracket: no index blended the concave edge at all, and index 27 now does. An index naming no edge used to be dropped and the rest blended; the batch is refused (`nil`) now |
| `Mesh.Triangle.faceIndex` is an index into `faces()` | Nothing on a shape that shares no face. On one that does, the value changes: on a two-solid split compound the indices ran 0…11 over an 11-face shape, and both sides of the shared wall now carry the one index that names it |

The exception was taken because:

- **Every one of them is paired with a consumer on the other enumeration**, which is what makes the disagreement a wrong answer rather than a second convention. The sharpest case is `OCCTBRepExtremaExtCC`, which sits in the same file as `ExtPC`, `ExtCF` and `ClassifyPoint2D`, all converted by #541, so `edgeIndex` meant one thing in one function and another in its neighbour. `checkEdge(at:)` disagreed with `isSubShapeValid(type: .edge, at:)`, and `splitEdge(at:)` with `splitFace(at:with:)` driving the same `LocOpe_SplitShape`.
- **The end-to-end failure is the one the API's own documentation recommends.** `Shape.filleted(edges:radius:)`'s doc snippet is `bracket.filleted(edges: bracket.concaveEdges(), radius: 3)`. With the concavity labels desynchronised `concaveEdges()` returned `[]`, so the snippet filleted an empty list and returned **`nil`**, measured, not inferred. It reported *failure*, not success; the harm is that a `nil` from a fillet is indistinguishable from an ordinary fillet failure, so nothing pointed at the selection as the cause. It now returns a shape (28034.3 mm³ against the bracket's 28000.0).
- **There is no spelling in which both survive**, for the same reason as #541 and #568: these are index *values*, so Swift cannot overload on them and a deprecation attribute has nothing to attach to.
- **On every shape that shares no sub-shape, nothing moves** for the face-indexed and mesh entry points. The edge- and vertex-indexed ones do move on ordinary solids, because every edge of every solid is shared between two faces, that is exactly the gap #613 closes, and it is why these are recorded rather than treated as internal.
- **One site was deliberately NOT converted.** `OCCTPolyMergeNodes` walks face occurrences to set per-face triangle winding; deduplicating it would drop a shared wall's second side. It is unchanged, documented as such, and pinned by a test that fails if a later sweep converts it.
- **This did not finish the idiom on its own.** `Shape.nbEdges` / `nbVertices` / `nbFaces` still returned per-occurrence counts (**24** and **48** on a box against `edgeCount` 12 and `vertexCount` 8) and were filed as **#651**. That gap is closed below.
- Named in [`CHANGELOG.md`](CHANGELOG.md) with the measurements, and to be named in the release notes.

#### v2.0.0: `nbEdges`/`nbFaces`/`nbVertices` forward to the deduplicated count, then are removed (#651, #784)

> **Superseded at assembly.** As with #499 above, this shipped inside the branch as a deprecation
> with a `renamed:` forwarder, and **#784/#798 then removed all three symbols outright**. As
> released, `Shape.nbEdges`/`nbFaces`/`nbVertices` do not exist: a caller naming one gets a compile
> error pointing at `edgeCount`/`faceCount`/`vertexCount`, and never observes the corrected value
> through the old spelling at all. The whole "the exception was taken over `unavailable` because the
> risk is lower" argument below is therefore about a state no released version contains. It is kept
> because it records why the value was repointed rather than the name left in place, which is still
> the decision that shaped the replacement API.

**One silent behaviour change, not a compile error, layered on a deprecation.** `Shape.nbEdges`,
`Shape.nbFaces` and `Shape.nbVertices` counted bare `TopExp_Explorer` occurrences, exactly the gap
#613 closed for its seven entry points, but these three name no index and drive no consumer: each is
a pure duplicate of `edgeCount`/`faceCount`/`vertexCount`, confirmed by the Cluster A census
(`Scripts/repro/cluster-a-subshape-enumeration/`) across every fixture it measured. This project's
own reference docs already documented the deduplicated answer for all three (`box.nbEdges // 12`,
`box.nbVertices // 8`), so the contract and the implementation disagreed from the day these shipped:

| Break | What a caller does |
|---|---|
| `Shape.nbEdges` returns `edgeCount`'s value, not a `TopExp_Explorer` occurrence count | A box now reports 12, not 24. Deprecated, `renamed: "edgeCount"` |
| `Shape.nbFaces` returns `faceCount`'s value | Nothing on a shape that shares no face (a plain box agreed already, 6 either way). On a shape with a shared face, 11 instead of 12. Deprecated, `renamed: "faceCount"` |
| `Shape.nbVertices` returns `vertexCount`'s value | A box now reports 8, not 48. Deprecated, `renamed: "vertexCount"` |

The decision was to retire the duplicate spelling rather than repoint its implementation and leave
both names standing, following the precedent #536 set for `removeFeatures(faces:)`/`defeature(faces:)`
(two public names driving one operation, the newer one deprecated with a forwarding body) rather than
#541/#568/#613's own precedent (repoint the value in place, because those sites address an index with
no existing correctly-named sibling to forward to). The alternative considered and rejected:

- **Repointing `nbEdges`/`nbFaces`/`nbVertices` in place, keeping both names.** This was rejected
  because, unlike #613's seven sites, there is nothing left to distinguish the two names once the
  value agrees: no index, no orientation, no consumer that reads one and not the other. Two API
  entry points answering the identical question forever is the exact duplication #490/#491/#492 and
  #536 diagnosed and fixed elsewhere in this codebase; leaving it here after having just fixed the
  value would recreate the pattern this SemVer document's own #536 entry retired.
- **The exception was taken (over `unavailable`, #619's approach) because the risk is lower.**
  #619 forced a compile error because a silently reinterpreted ordinal fed a comparison
  (`continuityOrder >= 2`) that would silently take the wrong geometric branch. A raw count has no
  such branch to mislead: a caller comparing it to `edgeCount` was already failing before this
  change (the two never agreed), and a caller using it as a scale factor gets a smaller, still
  plausible number, the same shape of change #613 already recorded above as a warning rather than a
  break.
- **There is a name to forward to**, unlike #613's index values, so `@available(*, deprecated,
  renamed:)` has somewhere to point: matching #499's `PathParser` precedent (deprecated, and the
  value changes on the way) rather than #541/#568/#613's (no spelling survives).
- The now-orphaned bridge functions `OCCTShapeNbEdges`/`OCCTShapeNbFaces`/`OCCTShapeNbVertices` are
  deleted rather than kept, following #506's precedent for an orphan with no remaining Swift call
  site (`OCCTBridge` is a target, not a product, so there is no external ABI to hold stable).
- Named in [`CHANGELOG.md`](CHANGELOG.md) with the measurements, and to be named in the release notes.

#### v2.0.0: `continuityOrder` is retired rather than reinterpreted (#619)

**Three compile errors, deliberately, this exception is taken to *convert* a silent behaviour change into a break.** Recorded here before the tag is cut:

| Break | What a caller does |
|---|---|
| `Curve3D.continuityOrder` is `@available(*, unavailable)` | Replace with `continuityClass.satisfies(_:)` for a floor, `continuityClass == .cN` for the analytic fast path, or `continuity` for a raw ordinal, re-checking the constant compared against |
| `Curve2D.continuityOrder` likewise | Same |
| `Surface.surfaceContinuityOrder` likewise | Same |

The values these three reported already changed, in #485, from a hand-invented `C0=0, C1=1, C2=2, C3=3, CN=99, G1=-2, G2=-3` to the real `GeomAbs_Shape` ordinal `C0=0, G1=1, C1=2, G2=3, C2=4, C3=5, CN=6`. That change was correct and is not reverted. The exception was taken because:

- **A warning was not enough, because a warning does not stop compilation.** #485 shipped the encoding change with a deprecation attribute carrying the exact before/after in its `message:`, and `if curve.continuityOrder >= 2 { useAsC2Spline() }` still built and still ran. `2` went from meaning C2 to meaning C1, so a merely tangent-continuous curve reached a path that assumes curvature continuity, a wrong geometric answer, produced silently, in a build that succeeded. Symmetrically `continuityOrder == 99`, the analytic-geometry fast path, became unreachable: dead code rather than a wrong answer. Neither outcome is one a warning prevents.
- **There is no spelling in which both survive.** As with #541 and #568 this is a *value* contract, and Swift cannot overload on return value. But unlike those two, a name is available to attach a diagnostic to, so the break can be made loud instead of silent, which is the whole point of taking it.
- **Both replacements already exist and neither is new API.** `continuity` (raw ordinal, unchanged in value since before the refactor) and `continuityClass` (named cases, `Comparable`, with `satisfies(_:)`) both predate this change. Nothing was added; the operation count drops by 3, which is `Scripts/count-operations.py` correctly declining to count a retired spelling as a wrapped operation.
- **`unavailable` rather than deletion**, following `EvolvingFilletEdge.init(edgeIndex:)` (#520): deleting gives `value of type 'Curve3D' has no member 'continuityOrder'`, which says nothing about the encoding. The retained declaration puts the whole migration in the compiler's own error text.
- Named in [`CHANGELOG.md`](CHANGELOG.md) with the before/after table, and to be named in the release notes.

#### v2.0.0: the `wires`/`shells`/`solids` enumerations join the deduplicated map (#502)

**Six silent behaviour changes, none a compile error.** Recorded here on the #619 sweep. #541 recorded the *face* half of the explorer→`TopExp::MapShapes` conversion and #613 the last seven entry points; these six were converted by #502 and documented only in their own `///` comments, never in this file. The criterion for recording is the one this document already applies: a change a consumer can absorb without a diagnostic belongs in the table a consumer reads before upgrading blindly.

| Break | What a caller does |
|---|---|
| `Shape.solids` / `solidCount` count *distinct* solids, not occurrences | Nothing on a shape that shares no sub-shape. On one that does, the count is lower and the array shorter, `Shape.compound([box, box]).solidCount` is `1`, and was `2` |
| `Shape.shells` / `shellCount` likewise | A shell reused by two solids (what `solidFromShells` produces when handed the same shell twice) is now one shell |
| `Shape.wires` / `wireCount` likewise | A wire used to build two faces counts once, being one wire seen from two parents |

On `origin/main` each of these called its own explorer-backed bridge function (`OCCTShapeGetSolidCount` and siblings, a `TopExp_Explorer` occurrence walk); each is now a named spelling of `subShapeCount(ofType:)` / `subShapes(ofType:)`, which read `TopExp::MapShapes`. `MapShapes` keys on `TopoDS_Shape::IsSame`, which ignores orientation, so duplicate occurrences collapse and the surviving entry carries the first occurrence's orientation.

The exception was taken because:

- **The disagreement is the bug.** These six and `subShapeCount(ofType:)` answered the same question about the same shape with different numbers, neither cross-checked against the other. That is the #502 finding, and it is the same defect class as #541's face indices.
- **There is no spelling in which both survive.** As with #541 and #568 these are *values*, so Swift cannot overload on them and a deprecation attribute has nothing to attach to.
- **On every shape that shares no sub-shape, nothing moves**: primitives, booleans, sewn sheets and compsolids are unaffected.
- Documented in each property's `///` comment; recorded here so the guarantee paragraph above is complete.

#### v2.0.0: `buildCurves3d`'s default tolerance loosens (#498)

**One silent behaviour change, not a compile error.** Recorded here on the #619 sweep, which asked of every "a value changed under an unchanged signature" site whether the change was decided or merely happened:

| Break | What a caller does |
|---|---|
| `Shape.buildCurves3d(tolerance:)`'s default moves from `1e-7` to `1e-5`, a 100× loosening | Nothing, unless the tighter curve was being relied on, then pass `tolerance: 1e-7` explicitly. The value is also written onto the rebuilt edge as its tolerance, so a caller who cared about edge tolerance downstream should re-check it |

**Decision: keep `1e-5`.** The alternatives considered were reverting to `1e-7`, and removing the default outright so every caller must choose (the response #541 took for `defeature(faces:tolerance:)`). Both were rejected:

- **`1e-5` is OCCT's own default, and `1e-7` was OCCTSwift's invention.** `BRepLib::BuildCurves3d(const TopoDS_Shape&)` is literally `return BRepLib::BuildCurves3d(S, 1.0e-5);` (`BRepLib.cxx:463`), and `BRepLib::BuildCurve3d`'s header declares `Tolerance = 1.0e-5`. Reverting would restore a number no upstream API asks for.
- **The old default over-claimed.** OCCT writes this tolerance onto the edge as a floor rather than the deviation actually achieved, so `1e-7` had every rebuilt edge asserting a tightness the approximation may not hold on hard geometry. Measured on a helix, `1e-5` deviates 2.6e-6 and `1e-7` deviates 9.0e-8, the tighter fit is real, but it costs a pole or two and it is a claim the caller should make deliberately.
- **Removing the default is disproportionate here.** Unlike the index rebases of #541/#568, the two values do not mean *different things*, both are tolerances, in the same units, ordered the obvious way. A caller reading `1e-5` is not misled about what it is; a caller reading a 0-based index as 1-based is. The break is a precision change, not a semantic one, so a recorded decision plus the doc note is the proportionate response.
- Named in [`CHANGELOG.md`](CHANGELOG.md) with the measurement, and to be named in the release notes.

#### v2.0.0: AAG builds nodes from face occurrences (#642)

**One silent behaviour change, not a compile error.** Shares its root mechanism with #614 and the
Cluster A census (#664): a value derived from a face's normal loses information across `faces()`'s
dedup collapse, here `AAG`'s node set rather than `horizontalFaces()`/`upwardFaces()`. Recorded here
before the tag is cut:

| Break | What a caller does |
|---|---|
| `Shape.buildAAG().nodes` and `Shape.detectPocketsAAG()` can return more entries on a shape with a face shared between two solids in a compound | Nothing on a shape that shares no face, which includes every single-solid shape. On one that does, `nodes.count` matches `orientedFaces().count` rather than `faces().count`, and `detectPocketsAAG()` can report an additional pocket for the shared face's other side. A caller indexing `AAGNode.faceIndex` against `Shape.faces()` should index `Shape.orientedFaces()` instead, or read the new `AAGNode.distinctFaceIndex` field to recover the old, distinct-face identity |
| `PocketFeature.floorFaceIndex`, `PocketFeature.wallFaceIndices` and `AAG.detectHoles()`'s `faceIndex` now index `orientedFaces()` too | These are built from node array positions, so they inherited the change without their own code edit, which is why they are called out separately. `detectPocketsAAG()` returns `PocketFeature`, so this is the output type of the API the headline break is about: a caller doing `shape.faces()[pocket.floorFaceIndex]` on a shared-face compound gets the wrong face or an out-of-range index, silently. Use `shape.orientedFaces()[...]`, or `aag.nodes[pocket.floorFaceIndex].distinctFaceIndex` for the old identity |

Before this fix, `AAG.buildGraph()` read `Shape.faces()`, the deduplicated enumeration that keeps
only the first orientation a shared face is reached in. `AAGNode.isHorizontal`/`isUpward`/
`isDownward`/`isVertical`/`zLevel` are all derived from that node's normal, so which orientation
survived the collapse silently decided the answer: the same compound, compounded in the opposite
member order, produced a different node set and a different `detectPocketsAAG()` result for
identical geometry. Measured on an origin-centred 10mm box cut through z=4 and recompounded in both
member orders: `detectPocketsAAG().count` was 2 in one order and 1 in the other, for the same shape.

The exception was taken because:

- **The disagreement is the bug, and it produced a different answer for identical geometry
  depending only on argument order to `Shape.compound(_:)`.** That is a correctness defect, not a
  second convention to document alongside the first.
- **There is no spelling in which both survive.** As with #502 and #613, `AAG`'s node identity is a
  design choice about what a node *means*, not a value that can be deprecated in place: a node
  built from `faces()` and one built from `orientedFaces()` disagree about how many nodes a shared
  face contributes at all, which no overload or default parameter can paper over.
- **On every shape that shares no face, nothing moves.** Every single-solid shape, and every
  compound whose members share nothing, produces the identical node set before and after, since
  `orientedFaces()` is documented to equal `faces()` exactly whenever nothing is shared.
- **`AAGNode.distinctFaceIndex` is new, additive API** that gives a caller who needs the old,
  one-node-per-distinct-face view a way back to it, without reintroducing the order-dependence.
- Named in [`CHANGELOG.md`](CHANGELOG.md) with the measurement, and to be named in the release
  notes.

#### v2.0.0: AAG adjacency and convexity are scoped to one solid (#699)

**One further silent behaviour change on the same public APIs #642 already named, not a compile
error.** Found measuring #642's own fix: `AAG.buildGraph()`'s pairwise adjacency check had no
concept of solid membership, so two face occurrences from *different* solids in a compound that
happened to share a B-Rep edge were reported adjacent, and the convexity of that shared edge was
computed with no reference to which solid was asking. Recorded here before the tag is cut:

| Break | What a caller does |
|---|---|
| `Shape.buildAAG().edges`, `AAG.neighbors(of:)`, `AAG.concaveNeighbors(of:)` and `AAG.convexNeighbors(of:)` no longer report a cross-solid pair as adjacent | Nothing on a shape with zero or one solid, which includes every single-solid shape. On a multi-solid compound, a caller relying on a cross-solid adjacency edge (there is no documented use for one: every consumer wants same-solid adjacency) sees fewer edges and fewer neighbors |
| `Shape.detectPocketsAAG()` can return a different count on a multi-solid compound, in **both** directions from before this fix: a spurious cross-solid pocket disappears, or two orders that used to disagree now agree at a value neither order reported before | Nothing on a single-solid shape. On a multi-solid compound, re-measure rather than assume the pre-#699 count: #642's own horizontal-cut fixture moved from `2` (agreeing across order) to `1` (agreeing across order, at a lower count), because one of the two pockets `2` counted was itself built from the cross-solid mechanism #699 removes |

Before this fix, `AAG.buildGraph()`'s pairwise loop tested every pair of face occurrences with
`OCCTFacesAreAdjacent`/`OCCTEdgeGetConvexity`, neither of which has any notion of solid membership:
both compare two `TopoDS_Face` values purely on their own edge geometry. On a vertical two-solid
split, the shared wall borders two half-faces of the box's original top face that also border each
other along the cut line, so one edge is common to three face occurrences; the pairwise loop
compared all three regardless of which solid each belonged to. Measured on a plain 10mm box split
by an X-normal plane through x=4: `detectPocketsAAG().count` was `1` in one compound member order
and `2` in the other, for identical geometry: the same class of order-dependence #642 fixed, from
a different mechanism, on a fixture #642's own does not exercise (its shared wall's normal is
horizontal-axis, never reaching `isHorizontal()`/`isUpward()`).

The exception was taken because:

- **The disagreement is the bug, and it produced a different answer for identical geometry
  depending only on argument order to `Shape.compound(_:)`**, the same standard #642's own
  exception was taken under, for a different mechanism.
- **There is no spelling in which both survive.** A graph edge either represents same-solid
  adjacency or it doesn't; there is no default parameter or overload that lets a caller opt into
  the old, solid-blind comparison, and no consumer of this library was found wanting one (an audit
  of `OCCTFacesAreAdjacent`/`OCCTEdgeGetConvexity` found exactly one Swift call site each, both
  inside `AAG.buildGraph()`, so no other caller could be relying on the unscoped behavior).
- **On every shape with zero or one solid, nothing moves.** `AAG.buildGraph()` falls back to the
  pre-#699 unrestricted comparison whenever there is no cross-solid pair to restrict, so a single
  solid's own graph, and every test built on one, is byte-for-byte unaffected.
- **This is a correction to #642's own recorded exception, not a new consumer-visible surface.**
  `Shape.detectPocketsAAG()` and `Shape.buildAAG()` are the identical two APIs #642 already listed;
  #699 changes what they return further rather than opening a second name for the same contract.
- Named in [`CHANGELOG.md`](CHANGELOG.md) with the measurement, and to be named in the release
  notes.

#### v2.0.0: `chamfer2D` refuses a repeated edge pair instead of crashing (#705)

**One behaviour change, not a compile error, and not really a break at all: the old answer was an
uncatchable process crash.** `chamfer2D(edgePairs:distances:)` SIGSEGVs when the same edge pair
appears twice, confirmed in a separate process before this fix (raw exit code 139), because of an
upstream OCCT defect: `BRepFilletAPI_MakeFillet2d::AddChamfer` looks up the pair's shared vertex and
dereferences the edges that lookup returns without checking its status first, and the repeat call's
lookup fails because that vertex was already consumed chamfering the pair the first time. Recorded
here before the tag is cut:

| Break | What a caller does |
|---|---|
| `chamfer2D(edgePairs:distances:)` returns `nil` when the same pair (in either order) appears more than once in `edgePairs` | Nothing on a call with no repeated pair, which includes chamfering every corner of a polygon (adjacent pairs legitimately share one edge, e.g. `(0, 1), (1, 2)`; only the identical pair repeated is refused). A caller building `edgePairs` from a selection or a loop that can produce an exact duplicate now gets `nil` instead of a crash, and should dedupe before calling |

The exception was taken because:

- **This is a crash fix, not a contract redesign.** There was no prior "answer" to disagree with:
  the process went down. `nil` is strictly more information than a SIGSEGV, and every existing
  caller that never produced a duplicate pair is unaffected.
- **It matches the sibling contract already on this builder.** `fillet2D(vertexIndices:radii:)`,
  the other entry point on the same `BRepFilletAPI_MakeFillet2d`, already rejects a duplicated
  vertex index (#568) rather than doing anything with it. `chamfer2D` could not fail the same
  incidental way, since its duplicate crashes inside OCCT before `Build()`/`IsDone()` ever run, so
  an explicit guard was required either way, and reject is the answer already established one call
  away.
- **Reject, not first-wins or last-wins.** #633 is open on the wider fillet/chamfer family's
  duplicate-index direction (fillet is last-wins, chamfer is first-wins, measured by
  `Scripts/repro/cluster-b-fillet-edge-contract/`), and this entry point is deliberately left out
  of that debate: picking a "wins" direction here would still require silently discarding one of
  two distances with no signal to the caller, the same ambiguity #568 already refused to resolve
  by guessing. This is a data point for #633, not an attempt to settle it.
- **Reusing one edge across two different pairs is unaffected**, which is pinned by a positive
  test chamfering every corner of a rectangle (`(0, 1), (1, 2), (2, 3), (3, 0)`, each edge shared
  by two pairs) that must keep succeeding.
- Named in [`CHANGELOG.md`](CHANGELOG.md) with the measurement, and to be named in the release
  notes.

#### v2.0.0: six curvature getters return `Double?` instead of `Double` (#595)

**Six compile errors.** The following curvature getters used to return `Double`, with `0` meaning "undefined" (cusp, degenerate, etc.). They now return `Double?`, where `nil` means undefined and a value means defined. This is a compile error for any caller, the migration is to unwrap or provide a default:

| Break | Issue | What a caller does |
|---|---|---|
| `Curve2D.curvature(at:)` returns `Double?` | #595 | `if let k = curve.curvature(at: t) { … }` or `curve.curvature(at: t) ?? 0` |
| `Curve3D.curvature(at:)` returns `Double?` | #595 | `if let k = curve.curvature(at: t) { … }` or `curve.curvature(at: t) ?? 0` |
| `Curve3D.localCurvature(at:)` returns `Double?` | #595 | `if let k = curve.localCurvature(at: t) { … }` or `curve.localCurvature(at: t) ?? 0` |
| `Surface.gaussianCurvature(atU:v:)` returns `Double?` | #595 | `if let k = surface.gaussianCurvature(atU: u, v: v) { … }` or `surface.gaussianCurvature(atU: u, v: v) ?? 0` |
| `Surface.meanCurvature(atU:v:)` returns `Double?` | #595 | `if let k = surface.meanCurvature(atU: u, v: v) { … }` or `surface.meanCurvature(atU: u, v: v) ?? 0` |
| `Shape.edgeCurvatureLP(at:)` returns `Double?` | #595 | `if let k = shape.edgeCurvatureLP(at: edge) { … }` or `shape.edgeCurvatureLP(at: edge) ?? 0` |

The exception was taken because:

- **This is a correctness fix, not a cosmetic change.** The old API spelled "undefined" as `0`, which is a valid curvature (straight line, flat surface). A caller checking `k == 0` could not distinguish "flat" from "undefined at a cusp", the two are geometrically opposite. Returning `nil` for undefined makes the distinction observable at compile time.
- **There is no spelling in which both survive.** Swift cannot overload on return type alone (`Double` vs `Double?`); a deprecation attribute has nothing to attach to. The break is unavoidable and loud, which is the intended outcome.
- **The default fallback `?? 0` preserves the old numeric behaviour exactly** for callers who want it. A caller who knows their geometry never produces undefined curvature (e.g. circles, ellipses, cylinders) can coalesce `nil` to `0` without semantic change.
- **This completed a family sweep.** #495, #490, #520 and #639 already moved related geometry queries to optionals; #595 was the last batch. The milestone `v2.0.0` on the issue confirms it was intended for this release.
- Named in [`CHANGELOG.md`](CHANGELOG.md) with the before/after table, and to be named in the release notes.

#### Recorded exception: v1.17.0 (2026-07-29)

**v1.17.0 is a minor release that breaks source compatibility in two places.** It is the only exception to the rule above, and it is recorded here rather than left for a consumer to discover at the compiler:

| Break | Issue | What a caller does |
|---|---|---|
| `Surface.drawMesh` / `Surface.evaluateGrid` return `SurfaceGrid`, not `[[SIMD3<Double>]]` | #404 | Index via `at(u:v:)`; check index order when migrating `evaluateGrid`, whose old shape was `[v][u]` |
| `Curve3D.interpolate(points:startTangent:endTangent:)` overload removed | #400 | Nothing, unless the overload was referenced as a value: the three-argument call now resolves to the tolerance-aware sibling with the same `1e-6` default |

Both are compile errors, never silent. The decision was to take the exception rather than spend the major version, because:

- Neither break can be shimmed into an additive change. Swift does not overload on return type alone, so a deprecated `drawMesh` returning the old type is ambiguous at every call site that binds the result. Preserving compatibility would have meant reverting #404 outright and reintroducing the `[u][v]` vs `[v][u]` hazard it removed.
- The major version stays reserved for OCCT 9.0, so the cohort does not have to major together for a two-call-site change in one package.
- Both are named at the top of [`CHANGELOG.md`](CHANGELOG.md)'s v1.17.0 entry with before/after code, and in the GitHub release notes.

This exception does not amend the rule. A breaking change still triggers a major bump by default; taking an exception requires the same treatment given here, which is naming every break with a migration, in the release notes and in this file, before the tag is cut.

#### #639: additive fillet decline reporting, not an exception

**Recorded here per #664's own rule of writing a public-API change down in this file before the
tag, not because this one is a recorded exception.** `filleted(edges:radius:)`,
`filleted(edges:startRadius:endRadius:)` and `filletEvolving(_:)` each gained a `WithReport`
sibling (`filletedWithReport(edges:radius:)`, `filletedWithReport(edges:startRadius:endRadius:)`,
`filletEvolvingWithReport(_:)`) returning a new `Shape.FilletResult`: the edges OCCT declined to
fillet, alongside the shape, for a caller who wants to know (#639).

This does **not** move the recorded-exceptions count above (checked against the current count of
thirteen at the time of this edit, re-verified rather than assumed, since it has drifted before):
no existing method's signature or behaviour changed. `filleted(edges:radius:)` and its two
siblings still return exactly what they always did, for exactly the same inputs; a caller who
never calls the three new methods sees no difference at all. This is the **MINOR**, additive Swift
API, case the quick reference table already names, not the MAJOR-avoided,
compile-error-or-silent-behaviour-change case every entry above it is. It is recorded here anyway,
rather than left to the release's own `CHANGELOG.md` entry, because #664 asks for every public-API
change in this cluster of work to be written down at the same time it lands, and distinguishing
"additive, no exception" from "exception" is itself information a reviewer of this file benefits
from having next to the ones that are.

Two of the issue's own named members (`filletedWithFullHistory(radius:edges:)`,
`FilletBuilder.contour(for:)`) needed no new API at all: both already carry a way to answer the
same question, documented in this PR with a runnable recipe rather than given new bridge code. See
[`CHANGELOG.md`](CHANGELOG.md#the-fillet-family-could-not-report-a-declined-edge-only-skip-it-silently-639)
for the full measurement and the reasoning against converging fillet's SKIP behaviour onto reject.

#### #633: additive blend-duplicate reporting, not an exception

**Recorded here for the same reason #639 immediately above is: a public-API change written down
now, not because this one is a recorded exception.** `blendedEdges(_:)` gained a `WithReport`
sibling, `blendedEdgesWithReport(_:)`, returning the same `Shape.FilletResult` #639 introduced,
now carrying a second field: `overwrittenDuplicateIndices`, the 0-based edge indices whose radius a
later entry in the same request silently overwrote (#633).

This does **not** move the "thirteen recorded exceptions" count above, checked and confirmed
unchanged by this entry, for the same reason #639's did not: no existing method's signature or
behaviour changed. `blendedEdges(_:)` still returns exactly what it always did, for exactly the
same inputs (last-wins, silently, on a duplicated edge index), and a caller who never calls
`blendedEdgesWithReport(_:)` sees no difference at all. This is the **MINOR**, additive Swift API
case the quick reference table already names.

Adding `overwrittenDuplicateIndices` to the existing `FilletResult` struct, rather than a second
result type, follows #639's own recommendation for this issue and the standing lesson #490 already
drew from a family of near-identical continuity mappers: one struct, extended, not a parallel
encoding of the same idea started fresh. It is a purely additive struct change: a `let` property
with a default is not exposed on Swift's synthesized memberwise init (only a `var` with a default
is), so `FilletResult` now carries an explicit `public init` with the new field defaulted to `[]`,
and every existing call site (`filletedWithReport(edges:radius:)`,
`filletedWithReport(edges:startRadius:endRadius:)`, `filletEvolvingWithReport(_:)`) compiles
unchanged and reads an empty array for a field none of the three has a duplicate axis to populate.

**The fillet/chamfer first-wins/last-wins asymmetry itself is unchanged and not addressed here.**
`Scripts/repro/cluster-b-fillet-edge-contract/` measured the wider family as internally consistent
but split in *opposite* directions (fillet last-wins, chamfer first-wins). Converging the two onto
one direction was considered and rejected for the same reason #639 rejected reject-over-skip:
it would change what an existing call returns for every input that currently succeeds, which is a
bigger and more disruptive decision than this issue's own defect (a silent discard with no
signal). See
[`CHANGELOG.md`](CHANGELOG.md#blendededges-reports-which-duplicate-entries-were-overwritten-633)
for the full measurement and the injection matrix proving the new report.

### MINOR, `x.y.0`

A minor bump is for additive change. Two routes:

1. **xcframework rebuild against a new OCCT minor / patch / RC.** OCCT ships a stability patch, a bug-fix release, an RC, or a beta, we rebuild the xcframework, the binary URL+checksum in `Package.swift` updates, consumers re-download. This is treated as MINOR because the binary swap is a meaningful "new functionality" event even when the Swift API surface is identical.

2. **Additive new public Swift API.** A new `Shape.foo()` method, a new `Wire.bar` static factory, a new `BRepGraph.baz` field, a new `FeatureSpec` case, anything that adds to the surface without removing or changing what's there. Existing callers are unaffected; new callers can opt in.

Either case bumps minor. A release that does both (e.g. rebuilds against new OCCT *and* adds a new wrapped operation that the rebuild made available) is one minor bump, not two.

### PATCH, `x.y.z`

A patch bump is for fix-only change with **no public API surface change**:

- A method that returned `nil` when it shouldn't, now returns the right value
- A constant whose value was wrong, now correct
- A switch case that was missing (`NodeKind.product` was missing the raw value 10, this was OCCTSwift v1.0.1)
- An internal refactor that doesn't change any public behavior
- A dependency floor bump in `Package.swift` (e.g. raising `OCCTSwiftViewport from: "0.55.2"` to `from: "1.0.1"`), even when the bump unblocks new features downstream, the bump itself is a fix, not new functionality
- Documentation-only releases (CHANGELOG entries, README updates, doc-comment tightening)

The shape of the public Swift API is unchanged before and after a patch.

## Cohort coordination

The OCCTSwift ecosystem is a layered family. Coordination rules:

### Lockstep on MAJOR

When OCCTSwift bumps major (next event: OCCT 9.x), every package in the cohort bumps to the matching major in coordinated fashion. Pre-1.0 history showed this: ~170 OCCTSwift point releases tracked the OCCT 7.8 → 8.0 RC sequence, and the whole public cohort graduated to v1.0.0 on the same day OCCT GA tagged.

The mechanism: a single tracker issue on OCCTSwift (e.g. [#96](https://github.com/gsdali/OCCTSwift/issues/96) was the v1.0.0 inbound), referenced by per-repo tracker issues, all closed on the cohort cut day.

### Independent within a major

Within a major line, each package versions on its own cadence. OCCTSwiftTools can ship v1.0.5 the same day OCCTSwift ships v1.4.2, there's no rule that minor / patch numbers align across packages. They share a major; that's it.

In practice this means:
- Sibling features (e.g. `PointConverter` in Tools) bump that sibling's minor without touching OCCTSwift's version.
- Bug fixes in one package don't ripple version numbers elsewhere unless those fixes change a public API the dependent reads.

### Floors in `Package.swift` and `ecosystem.md`

When a sibling ships a feature a downstream consumer needs, bump the declared dep floor in `Package.swift` of the consumer **even if SPM would resolve forward automatically under SemVer**. The bumped floor signals intent: "the consumer needs at least this version."

Same for the [compatibility matrix in `ecosystem.md`](ecosystem.md#compatibility-matrix-v100-cohort-may-2026), keep the floors there at the latest patch each consumer should be using. A floor bump is a PATCH-level change in the consuming package (it doesn't change *its* public API).

## Examples

Drawn from the v1.0 cohort's actual history:

| Release | Bump | Why |
|---------|------|-----|
| OCCTSwift v2.0.0 | MAJOR | Rule 2: the accumulated public-API breaks listed under [v2.0.0](#v200). The OCCT 8.0.0p1 to 8.0.1 re-pin rode along and would have been MINOR on its own |
| OCCTSwift v1.0.0 | MAJOR | OCCT 8.0.0 GA pin (cohort bump from v0.x) |
| OCCTSwift v1.0.1 | PATCH | `NodeKind.product` raw-value fix, `rootNodes` had been silently returning `[]` for assembly graphs. No API change. |
| OCCTSwift v1.0.2 | (would have been MINOR going forward) | Added `unionWithFullHistory` / `subtractedWithFullHistory` / `intersectionWithFullHistory` / `splitWithFullHistory` + `ShapeHistoryRef` class + `ShapeHistoryRecord` struct. **Additive, should have bumped minor under this policy.** Tagged as patch before this policy was formalized. |
| OCCTSwift v1.0.3 | (would have been MINOR going forward) | Tier 2 modification ops + `BuildResult.histories` field. **Additive, should have bumped minor.** |
| OCCTSwift v1.0.4 | (borderline; PATCH was acceptable) | Wired `applyFillet` / `applyChamfer` through `*WithFullHistory`; `BuildResult.histories[id]` now populates for fillet / chamfer specs. The public surface didn't change, only the *behavior* of an existing field changed (more ids show up in the map than before). PATCH was defensible; under a strict reading, MINOR would have been more accurate. |
| OCCTSwiftTools v1.0.1 | (would have been MINOR going forward) | Added `PointConverter.pointsToBody`, a new public type and method. Tagged as patch. |
| OCCTSwiftTools v1.0.2 | PATCH | Bumped `OCCTSwiftViewport` floor `0.55.0` → `1.0.1` and `OCCTSwift` floor `1.0.1` → `1.0.3`. Pure dep-floor bump. |
| OCCTMCP v1.1.1 | PATCH | Fixed a hard-stale Viewport pin (`from: "0.55.2"` couldn't resolve to 1.0.x). |

### Retroactive note

Releases prior to this policy (v1.0.2, v1.0.3, OCCTSwiftTools v1.0.1) under-counted minor bumps for additive Swift APIs, they shipped as patches. We don't renumber history. **Effective from this document's commit, additive public-Swift-API releases bump minor.** The next OCCTSwift release that adds new wrapped operations will be **v1.1.0**, not v1.0.5.

## Decision flow

```
        ┌─────────────────────────────────┐
        │  What changed in this release?  │
        └────────────┬────────────────────┘
                     │
         ┌───────────┼───────────┬────────────────┐
         ▼           ▼           ▼                ▼
   OCCT major     OCCT minor /  Public Swift     Bug fix
   bump           patch / RC    API: added      only / dep
   (e.g. 9.0)     rebuild       a method,       floor bump
                                type, etc.
         │           │           │                │
         ▼           ▼           ▼                ▼
       MAJOR       MINOR       MINOR            PATCH
       (cohort)
```

If a release combines several categories (e.g. an OCCT rebuild *and* new Swift API), pick the highest applicable bump, one release, one version increment.

If a release is ambiguous (the v1.0.4 case, behavior change with no surface change), default to PATCH and call out the behavioral delta in the changelog. If consumers might miss it without reading carefully, MINOR is more defensible.

## Tooling expectations

- `Package.swift` `from: "1.0.0"` resolves to the range `[1.0.0, 2.0.0)`. Take any minor / patch update blindly within a major line; pin `exact:` only if you have a specific reason.
- Swift Package Index updates per-package pages from each repo's tags; the policy above keeps badges accurate without manual intervention.
- The xcframework asset is attached to OCCTSwift releases that include a binary rebuild (every MAJOR and most MINORs). PATCHes typically reuse the previous binary URL, no asset attached, `Package.swift` URL/checksum unchanged.

## When in doubt

- "Will this break a consumer's build if they take it blindly?", yes → MAJOR.
- "Is there new functionality consumers can opt into?", yes → MINOR.
- "Is this purely a fix or floor bump?", yes → PATCH.

Document the choice in the changelog. The point of SemVer is communication, the version number is a contract with consumers about what they'll have to do (or not do) when they update.
