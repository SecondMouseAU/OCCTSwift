---
title: Versioning (SemVer)
nav_order: 11
---

# SemVer Policy — OCCTSwift Ecosystem

This document defines how every package in the [OCCTSwift ecosystem](ecosystem.md) versions its releases. It applies to OCCTSwift itself, OCCTSwiftIO, OCCTSwiftMesh, OCCTSwiftViewport, OCCTSwiftTools, OCCTSwiftAIS, OCCTSwiftScripts, and OCCTMCP — and to any future sibling that joins the cohort.

The policy is calibrated to the [SemVer 2.0.0](https://semver.org/) spec with one extension: because OCCTSwift is a wrapper, the bundled OCCT version is part of the consumer-visible contract. An OCCT major version bump is treated as a major event for the wrapper, even if the public Swift API technically didn't break.

## Quick reference

| Bump | Trigger | Examples |
|------|---------|----------|
| **MAJOR** (`x.0.0`) | Upstream OCCT major version bump (e.g. 8.x → 9.x) | OCCTSwift v1.0.0 (pinned to OCCT 8.0 GA, after the v0.x line tracked OCCT 7.8 → 8.0 RCs) |
| **MINOR** (`x.y.0`) | xcframework rebuild against a new OCCT release **OR** additive new public Swift API | A new wrapped operation, a new type, a new bridge function exposed to Swift |
| **PATCH** (`x.y.z`) | Bug fix, internal refactor, doc-only — **no public API surface change** | A `nil`-returning regression repaired, a wrong sort-order fixed, a dependency floor bump |

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

### MAJOR — `x.0.0`

A major bump is reserved for two events, either of which alone is sufficient:

1. **OCCT major version bump.** A new OCCT major (e.g. 9.0) almost always reshapes the C++ API surface enough to force breaking changes in our Swift wrappers (renamed types, deleted classes, redesigned enums). Even when an OCCT major release coincidentally leaves our wrappers unchanged, we still bump major because the bundled binary is part of the contract — consumers are entitled to know the OCCT version changed. The whole cohort majors together.

2. **Breaking change to the public Swift API.** A removed type, a renamed method, a changed return type, a tightened parameter type, a raised platform floor — anything a consumer might have to fix on their side after pinning forward. This is rare within a major line because we promise stability there; if it happens, it triggers a major bump of the affected package (and possibly the cohort, if the change ripples downstream).

The cohort moved to v1.0.0 on 2026-05-07 alongside [OCCT 8.0.0 GA](https://github.com/Open-Cascade-SAS/OCCT/releases/tag/V8_0_0),
and to v2.0.0 under Rule 2, on the accumulated breaks recorded below. v3.0.0 is a further
Rule 2 major on a much smaller set: the kernel does not move, and the breaks are listed
immediately below.

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

- It cannot be shimmed. Swift does not overload a property on its type, so the old `Bool` spelling cannot coexist with the new one under the same name — the alternative was leaving five public properties that report `true` for a class nothing measured (a sharp 90° corner reported `isC2 == true`), which is a silent wrong answer, exactly what a SemVer promise is not meant to protect.
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
| `Shape.faces()` returns one entry per *distinct* face, not per occurrence | Nothing on any shape that shares no face. On one that does — the result of a split, an imprint, a compound of a shape with itself — the array is shorter and the surplus `Face.index` values are gone. They named faces `face(at:)` could not address, and past the duplicate they named the *wrong* face |
| `adjacentFaces(forEdge:)` / `adjacentEdges(forVertex:)` return 0-based indices | Drop the caller's own `- 1`. A caller who never subtracted was reading the neighbouring sub-shape |
| `splitByWireOnFace(_:faceIndex:)` takes 0-based, so its domain is `0..<faceCount` not `1...faceCount` | Subtract 1 from a hand-written index |
| `buildWires(faceIndex:)` takes 0-based; the "every edge" sentinel is any negative value, was `0` | Nothing if the default is used — it changed from `0` to `-1` and still means every edge. A caller passing `0` explicitly now gets face 0's edges |
| `offsetPerFace(defaultOffset:faceOffsets:)` keys are 0-based, and an out-of-range key fails the call instead of being skipped | Subtract 1 from hand-written keys. A call that silently ignored a bad key now returns `nil` |
| `EvolvingFilletEdge.edgeIndex` is 0-based; `Selector.PickResult.subShapeIndex` is 0-based with `-1`, not `0`, for the whole shape; `meshTriangleAdjacency`/`meshNodeTriangle`/`meshNodeTriangleCount` take a 0-based `faceIndex` (their triangle and node indices stay `Poly_Triangulation`-native 1-based, as do the triangle indices they return) | Subtract 1 from hand-written indices; compare `subShapeIndex` against `-1` rather than `0` |

The exception was taken because:

- **The disagreement is the bug, and it was not only cosmetic.** Measured on the pinned kernel (`Scripts/repro/541-face-index-contract/`): one `BRepAlgoAPI_Splitter` run cutting a box with a plane leaves 12 face occurrences over 11 distinct faces, and because the duplicate is not last, `faces()` and `face(at:)` named **different faces** from index 10 onwards. A caller selecting a face from `faces()` and passing it to `drafted(faces:)`, `shelled(openFaces:)` or `withoutFeatures(faces:)` — all map-backed — operated on a face it had not selected, with no error. Preserving any of the old conventions would have preserved that.
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
| `edgesInFace(at:)` and `commonEdges(with:)` return a real `Edge.index` | The `index` on every returned `Edge` changes value. It was the position in the result array, so it addressed a different edge — or none. `edgesInFace(at: 3)` on a box handed back 0, 1, 2, 3 for edges whose indices are 2, 6, 10 and 11, so all four named a different edge. A caller that used the old value as an array subscript into its *own* parallel array must switch to enumerating the result |
| `biTgteBlend(edgeIndices:radius:tolerance:nubs:)` indexes `edges()`, and refuses an unresolvable index | Both a #541-class and a #568-class change in one site. Measured on an L-bracket: no index blended the concave edge at all, and index 27 now does. An index naming no edge used to be dropped and the rest blended; the batch is refused (`nil`) now |
| `Mesh.Triangle.faceIndex` is an index into `faces()` | Nothing on a shape that shares no face. On one that does, the value changes: on a two-solid split compound the indices ran 0…11 over an 11-face shape, and both sides of the shared wall now carry the one index that names it |

The exception was taken because:

- **Every one of them is paired with a consumer on the other enumeration**, which is what makes the disagreement a wrong answer rather than a second convention. The sharpest case is `OCCTBRepExtremaExtCC`, which sits in the same file as `ExtPC`, `ExtCF` and `ClassifyPoint2D` — all converted by #541 — so `edgeIndex` meant one thing in one function and another in its neighbour. `checkEdge(at:)` disagreed with `isSubShapeValid(type: .edge, at:)`, and `splitEdge(at:)` with `splitFace(at:with:)` driving the same `LocOpe_SplitShape`.
- **The end-to-end failure is the one the API's own documentation recommends.** `Shape.filleted(edges:radius:)`'s doc snippet is `bracket.filleted(edges: bracket.concaveEdges(), radius: 3)`. With the concavity labels desynchronised `concaveEdges()` returned `[]`, so the snippet filleted an empty list and returned **`nil`** — measured, not inferred. It reported *failure*, not success; the harm is that a `nil` from a fillet is indistinguishable from an ordinary fillet failure, so nothing pointed at the selection as the cause. It now returns a shape (28034.3 mm³ against the bracket's 28000.0).
- **There is no spelling in which both survive**, for the same reason as #541 and #568: these are index *values*, so Swift cannot overload on them and a deprecation attribute has nothing to attach to.
- **On every shape that shares no sub-shape, nothing moves** for the face-indexed and mesh entry points. The edge- and vertex-indexed ones do move on ordinary solids, because every edge of every solid is shared between two faces — that is exactly the gap #613 closes, and it is why these are recorded rather than treated as internal.
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

**Three compile errors, deliberately — this exception is taken to *convert* a silent behaviour change into a break.** Recorded here before the tag is cut:

| Break | What a caller does |
|---|---|
| `Curve3D.continuityOrder` is `@available(*, unavailable)` | Replace with `continuityClass.satisfies(_:)` for a floor, `continuityClass == .cN` for the analytic fast path, or `continuity` for a raw ordinal — re-checking the constant compared against |
| `Curve2D.continuityOrder` likewise | Same |
| `Surface.surfaceContinuityOrder` likewise | Same |

The values these three reported already changed, in #485, from a hand-invented `C0=0, C1=1, C2=2, C3=3, CN=99, G1=-2, G2=-3` to the real `GeomAbs_Shape` ordinal `C0=0, G1=1, C1=2, G2=3, C2=4, C3=5, CN=6`. That change was correct and is not reverted. The exception was taken because:

- **A warning was not enough, because a warning does not stop compilation.** #485 shipped the encoding change with a deprecation attribute carrying the exact before/after in its `message:`, and `if curve.continuityOrder >= 2 { useAsC2Spline() }` still built and still ran. `2` went from meaning C2 to meaning C1, so a merely tangent-continuous curve reached a path that assumes curvature continuity — a wrong geometric answer, produced silently, in a build that succeeded. Symmetrically `continuityOrder == 99`, the analytic-geometry fast path, became unreachable: dead code rather than a wrong answer. Neither outcome is one a warning prevents.
- **There is no spelling in which both survive.** As with #541 and #568 this is a *value* contract, and Swift cannot overload on return value. But unlike those two, a name is available to attach a diagnostic to, so the break can be made loud instead of silent — which is the whole point of taking it.
- **Both replacements already exist and neither is new API.** `continuity` (raw ordinal, unchanged in value since before the refactor) and `continuityClass` (named cases, `Comparable`, with `satisfies(_:)`) both predate this change. Nothing was added; the operation count drops by 3, which is `Scripts/count-operations.py` correctly declining to count a retired spelling as a wrapped operation.
- **`unavailable` rather than deletion**, following `EvolvingFilletEdge.init(edgeIndex:)` (#520): deleting gives `value of type 'Curve3D' has no member 'continuityOrder'`, which says nothing about the encoding. The retained declaration puts the whole migration in the compiler's own error text.
- Named in [`CHANGELOG.md`](CHANGELOG.md) with the before/after table, and to be named in the release notes.

#### v2.0.0: the `wires`/`shells`/`solids` enumerations join the deduplicated map (#502)

**Six silent behaviour changes, none a compile error.** Recorded here on the #619 sweep. #541 recorded the *face* half of the explorer→`TopExp::MapShapes` conversion and #613 the last seven entry points; these six were converted by #502 and documented only in their own `///` comments, never in this file. The criterion for recording is the one this document already applies: a change a consumer can absorb without a diagnostic belongs in the table a consumer reads before upgrading blindly.

| Break | What a caller does |
|---|---|
| `Shape.solids` / `solidCount` count *distinct* solids, not occurrences | Nothing on a shape that shares no sub-shape. On one that does, the count is lower and the array shorter — `Shape.compound([box, box]).solidCount` is `1`, and was `2` |
| `Shape.shells` / `shellCount` likewise | A shell reused by two solids (what `solidFromShells` produces when handed the same shell twice) is now one shell |
| `Shape.wires` / `wireCount` likewise | A wire used to build two faces counts once, being one wire seen from two parents |

On `origin/main` each of these called its own explorer-backed bridge function (`OCCTShapeGetSolidCount` and siblings, a `TopExp_Explorer` occurrence walk); each is now a named spelling of `subShapeCount(ofType:)` / `subShapes(ofType:)`, which read `TopExp::MapShapes`. `MapShapes` keys on `TopoDS_Shape::IsSame`, which ignores orientation, so duplicate occurrences collapse and the surviving entry carries the first occurrence's orientation.

The exception was taken because:

- **The disagreement is the bug.** These six and `subShapeCount(ofType:)` answered the same question about the same shape with different numbers, neither cross-checked against the other. That is the #502 finding, and it is the same defect class as #541's face indices.
- **There is no spelling in which both survive.** As with #541 and #568 these are *values*, so Swift cannot overload on them and a deprecation attribute has nothing to attach to.
- **On every shape that shares no sub-shape, nothing moves** — primitives, booleans, sewn sheets and compsolids are unaffected.
- Documented in each property's `///` comment; recorded here so the guarantee paragraph above is complete.

#### v2.0.0: `buildCurves3d`'s default tolerance loosens (#498)

**One silent behaviour change, not a compile error.** Recorded here on the #619 sweep, which asked of every "a value changed under an unchanged signature" site whether the change was decided or merely happened:

| Break | What a caller does |
|---|---|
| `Shape.buildCurves3d(tolerance:)`'s default moves from `1e-7` to `1e-5`, a 100× loosening | Nothing, unless the tighter curve was being relied on — then pass `tolerance: 1e-7` explicitly. The value is also written onto the rebuilt edge as its tolerance, so a caller who cared about edge tolerance downstream should re-check it |

**Decision: keep `1e-5`.** The alternatives considered were reverting to `1e-7`, and removing the default outright so every caller must choose (the response #541 took for `defeature(faces:tolerance:)`). Both were rejected:

- **`1e-5` is OCCT's own default, and `1e-7` was OCCTSwift's invention.** `BRepLib::BuildCurves3d(const TopoDS_Shape&)` is literally `return BRepLib::BuildCurves3d(S, 1.0e-5);` (`BRepLib.cxx:463`), and `BRepLib::BuildCurve3d`'s header declares `Tolerance = 1.0e-5`. Reverting would restore a number no upstream API asks for.
- **The old default over-claimed.** OCCT writes this tolerance onto the edge as a floor rather than the deviation actually achieved, so `1e-7` had every rebuilt edge asserting a tightness the approximation may not hold on hard geometry. Measured on a helix, `1e-5` deviates 2.6e-6 and `1e-7` deviates 9.0e-8 — the tighter fit is real, but it costs a pole or two and it is a claim the caller should make deliberately.
- **Removing the default is disproportionate here.** Unlike the index rebases of #541/#568, the two values do not mean *different things* — both are tolerances, in the same units, ordered the obvious way. A caller reading `1e-5` is not misled about what it is; a caller reading a 0-based index as 1-based is. The break is a precision change, not a semantic one, so a recorded decision plus the doc note is the proportionate response.
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

**Six compile errors.** The following curvature getters used to return `Double`, with `0` meaning "undefined" (cusp, degenerate, etc.). They now return `Double?`, where `nil` means undefined and a value means defined. This is a compile error for any caller — the migration is to unwrap or provide a default:

| Break | Issue | What a caller does |
|---|---|---|
| `Curve2D.curvature(at:)` returns `Double?` | #595 | `if let k = curve.curvature(at: t) { … }` or `curve.curvature(at: t) ?? 0` |
| `Curve3D.curvature(at:)` returns `Double?` | #595 | `if let k = curve.curvature(at: t) { … }` or `curve.curvature(at: t) ?? 0` |
| `Curve3D.localCurvature(at:)` returns `Double?` | #595 | `if let k = curve.localCurvature(at: t) { … }` or `curve.localCurvature(at: t) ?? 0` |
| `Surface.gaussianCurvature(atU:v:)` returns `Double?` | #595 | `if let k = surface.gaussianCurvature(atU: u, v: v) { … }` or `surface.gaussianCurvature(atU: u, v: v) ?? 0` |
| `Surface.meanCurvature(atU:v:)` returns `Double?` | #595 | `if let k = surface.meanCurvature(atU: u, v: v) { … }` or `surface.meanCurvature(atU: u, v: v) ?? 0` |
| `Shape.edgeCurvatureLP(at:)` returns `Double?` | #595 | `if let k = shape.edgeCurvatureLP(at: edge) { … }` or `shape.edgeCurvatureLP(at: edge) ?? 0` |

The exception was taken because:

- **This is a correctness fix, not a cosmetic change.** The old API spelled "undefined" as `0`, which is a valid curvature (straight line, flat surface). A caller checking `k == 0` could not distinguish "flat" from "undefined at a cusp" — the two are geometrically opposite. Returning `nil` for undefined makes the distinction observable at compile time.
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
same inputs -- last-wins, silently, on a duplicated edge index -- and a caller who never calls
`blendedEdgesWithReport(_:)` sees no difference at all. This is the **MINOR**, additive Swift API
case the quick reference table already names.

Adding `overwrittenDuplicateIndices` to the existing `FilletResult` struct, rather than a second
result type, follows #639's own recommendation for this issue and the standing lesson #490 already
drew from a family of near-identical continuity mappers: one struct, extended, not a parallel
encoding of the same idea started fresh. It is a purely additive struct change: a `let` property
with a default is not exposed on Swift's synthesized memberwise init (only a `var` with a default
is), so `FilletResult` now carries an explicit `public init` with the new field defaulted to `[]`
-- every existing call site (`filletedWithReport(edges:radius:)`,
`filletedWithReport(edges:startRadius:endRadius:)`, `filletEvolvingWithReport(_:)`) compiles
unchanged and reads an empty array for a field none of the three has a duplicate axis to populate.

**The fillet/chamfer first-wins/last-wins asymmetry itself is unchanged and not addressed here.**
`Scripts/repro/cluster-b-fillet-edge-contract/` measured the wider family as internally consistent
but split in *opposite* directions (fillet last-wins, chamfer first-wins) -- converging the two onto
one direction was considered and rejected for the same reason #639 rejected reject-over-skip:
it would change what an existing call returns for every input that currently succeeds, which is a
bigger and more disruptive decision than this issue's own defect (a silent discard with no
signal). See
[`CHANGELOG.md`](CHANGELOG.md#blendededges-reports-which-duplicate-entries-were-overwritten-633)
for the full measurement and the injection matrix proving the new report.

### MINOR — `x.y.0`

A minor bump is for additive change. Two routes:

1. **xcframework rebuild against a new OCCT minor / patch / RC.** OCCT ships a stability patch, a bug-fix release, an RC, or a beta — we rebuild the xcframework, the binary URL+checksum in `Package.swift` updates, consumers re-download. This is treated as MINOR because the binary swap is a meaningful "new functionality" event even when the Swift API surface is identical.

2. **Additive new public Swift API.** A new `Shape.foo()` method, a new `Wire.bar` static factory, a new `BRepGraph.baz` field, a new `FeatureSpec` case — anything that adds to the surface without removing or changing what's there. Existing callers are unaffected; new callers can opt in.

Either case bumps minor. A release that does both (e.g. rebuilds against new OCCT *and* adds a new wrapped operation that the rebuild made available) is one minor bump, not two.

### PATCH — `x.y.z`

A patch bump is for fix-only change with **no public API surface change**:

- A method that returned `nil` when it shouldn't, now returns the right value
- A constant whose value was wrong, now correct
- A switch case that was missing (`NodeKind.product` was missing the raw value 10 — this was OCCTSwift v1.0.1)
- An internal refactor that doesn't change any public behavior
- A dependency floor bump in `Package.swift` (e.g. raising `OCCTSwiftViewport from: "0.55.2"` to `from: "1.0.1"`) — even when the bump unblocks new features downstream, the bump itself is a fix, not new functionality
- Documentation-only releases (CHANGELOG entries, README updates, doc-comment tightening)

The shape of the public Swift API is unchanged before and after a patch.

## Cohort coordination

The OCCTSwift ecosystem is a layered family. Coordination rules:

### Lockstep on MAJOR

When OCCTSwift bumps major (next event: OCCT 9.x), every package in the cohort bumps to the matching major in coordinated fashion. Pre-1.0 history showed this: ~170 OCCTSwift point releases tracked the OCCT 7.8 → 8.0 RC sequence, and the whole public cohort graduated to v1.0.0 on the same day OCCT GA tagged.

The mechanism: a single tracker issue on OCCTSwift (e.g. [#96](https://github.com/gsdali/OCCTSwift/issues/96) was the v1.0.0 inbound), referenced by per-repo tracker issues, all closed on the cohort cut day.

### Independent within a major

Within a major line, each package versions on its own cadence. OCCTSwiftTools can ship v1.0.5 the same day OCCTSwift ships v1.4.2 — there's no rule that minor / patch numbers align across packages. They share a major; that's it.

In practice this means:
- Sibling features (e.g. `PointConverter` in Tools) bump that sibling's minor without touching OCCTSwift's version.
- Bug fixes in one package don't ripple version numbers elsewhere unless those fixes change a public API the dependent reads.

### Floors in `Package.swift` and `ecosystem.md`

When a sibling ships a feature a downstream consumer needs, bump the declared dep floor in `Package.swift` of the consumer **even if SPM would resolve forward automatically under SemVer**. The bumped floor signals intent: "the consumer needs at least this version."

Same for the [compatibility matrix in `ecosystem.md`](ecosystem.md#compatibility-matrix-v100-cohort-may-2026) — keep the floors there at the latest patch each consumer should be using. A floor bump is a PATCH-level change in the consuming package (it doesn't change *its* public API).

## Examples

Drawn from the v1.0 cohort's actual history:

| Release | Bump | Why |
|---------|------|-----|
| OCCTSwift v2.0.0 | MAJOR | Rule 2: the accumulated public-API breaks listed under [v2.0.0](#v200). The OCCT 8.0.0p1 to 8.0.1 re-pin rode along and would have been MINOR on its own |
| OCCTSwift v1.0.0 | MAJOR | OCCT 8.0.0 GA pin (cohort bump from v0.x) |
| OCCTSwift v1.0.1 | PATCH | `NodeKind.product` raw-value fix — `rootNodes` had been silently returning `[]` for assembly graphs. No API change. |
| OCCTSwift v1.0.2 | (would have been MINOR going forward) | Added `unionWithFullHistory` / `subtractedWithFullHistory` / `intersectionWithFullHistory` / `splitWithFullHistory` + `ShapeHistoryRef` class + `ShapeHistoryRecord` struct. **Additive — should have bumped minor under this policy.** Tagged as patch before this policy was formalized. |
| OCCTSwift v1.0.3 | (would have been MINOR going forward) | Tier 2 modification ops + `BuildResult.histories` field. **Additive — should have bumped minor.** |
| OCCTSwift v1.0.4 | (borderline; PATCH was acceptable) | Wired `applyFillet` / `applyChamfer` through `*WithFullHistory`; `BuildResult.histories[id]` now populates for fillet / chamfer specs. The public surface didn't change — only the *behavior* of an existing field changed (more ids show up in the map than before). PATCH was defensible; under a strict reading, MINOR would have been more honest. |
| OCCTSwiftTools v1.0.1 | (would have been MINOR going forward) | Added `PointConverter.pointsToBody` — a new public type and method. Tagged as patch. |
| OCCTSwiftTools v1.0.2 | PATCH | Bumped `OCCTSwiftViewport` floor `0.55.0` → `1.0.1` and `OCCTSwift` floor `1.0.1` → `1.0.3`. Pure dep-floor bump. |
| OCCTMCP v1.1.1 | PATCH | Fixed a hard-stale Viewport pin (`from: "0.55.2"` couldn't resolve to 1.0.x). |

### Retroactive note

Releases prior to this policy (v1.0.2, v1.0.3, OCCTSwiftTools v1.0.1) under-counted minor bumps for additive Swift APIs — they shipped as patches. We don't renumber history. **Effective from this document's commit, additive public-Swift-API releases bump minor.** The next OCCTSwift release that adds new wrapped operations will be **v1.1.0**, not v1.0.5.

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

If a release combines several categories (e.g. an OCCT rebuild *and* new Swift API), pick the highest applicable bump — one release, one version increment.

If a release is ambiguous (the v1.0.4 case — behavior change with no surface change), default to PATCH and call out the behavioral delta in the changelog. If consumers might miss it without reading carefully, MINOR is more defensible.

## Tooling expectations

- `Package.swift` `from: "1.0.0"` resolves to the range `[1.0.0, 2.0.0)`. Take any minor / patch update blindly within a major line; pin `exact:` only if you have a specific reason.
- Swift Package Index updates per-package pages from each repo's tags; the policy above keeps badges accurate without manual intervention.
- The xcframework asset is attached to OCCTSwift releases that include a binary rebuild (every MAJOR and most MINORs). PATCHes typically reuse the previous binary URL — no asset attached, `Package.swift` URL/checksum unchanged.

## When in doubt

- "Will this break a consumer's build if they take it blindly?" — yes → MAJOR.
- "Is there new functionality consumers can opt into?" — yes → MINOR.
- "Is this purely a fix or floor bump?" — yes → PATCH.

Document the choice in the changelog. The point of SemVer is communication — the version number is a contract with consumers about what they'll have to do (or not do) when they update.
