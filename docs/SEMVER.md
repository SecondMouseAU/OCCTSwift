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

The load-bearing guarantee is the SemVer guarantee: **no breaking change without a major bump**. Within a major line, all minor and patch updates are safe to take blindly, with six recorded exceptions: [v1.17.0](#recorded-exception-v1170-2026-07-29) breaks source compatibility in two named places, [#495](#recorded-exception-unreleased--junction-analysis-flags-become-optional-495) in one, [#499](#recorded-exception-unreleased-pathparser-forwards-to-osdpath-499) changes what two deprecated `PathParser` methods return without breaking the build, [#541](#recorded-exception-unreleased-one-meaning-for-a-face-index-541) moves six sub-shape index conventions onto one, also without breaking the build, [#568](#recorded-exception-unreleased-an-unresolvable-sub-shape-index-refuses-the-call-568) makes five more entry points refuse an index they used to skip, and [#613](#recorded-exception-unreleased-the-last-seven-entry-points-join-the-one-sub-shape-enumeration-613) moves the last seven entry points off the per-occurrence walk onto that same enumeration. A seventh was **not** taken: [#609](#held-for-the-next-major-v200)'s twelve breaks are held for v2.0.0 instead.

## Rules

### MAJOR — `x.0.0`

A major bump is reserved for two events, either of which alone is sufficient:

1. **OCCT major version bump.** A new OCCT major (e.g. 9.0) almost always reshapes the C++ API surface enough to force breaking changes in our Swift wrappers (renamed types, deleted classes, redesigned enums). Even when an OCCT major release coincidentally leaves our wrappers unchanged, we still bump major because the bundled binary is part of the contract — consumers are entitled to know the OCCT version changed. The whole cohort majors together.

2. **Breaking change to the public Swift API.** A removed type, a renamed method, a changed return type, a tightened parameter type, a raised platform floor — anything a consumer might have to fix on their side after pinning forward. This is rare within a major line because we promise stability there; if it happens, it triggers a major bump of the affected package (and possibly the cohort, if the change ripples downstream).

The cohort moved to v1.0.0 on 2026-05-07 alongside [OCCT 8.0.0 GA](https://github.com/Open-Cascade-SAS/OCCT/releases/tag/V8_0_0).

#### Held for the next major: v2.0.0

The exceptions recorded below were each taken on the same terms: one or a few breaks, none
shimmable, each named with its migration before the tag. **Some changes are too broad for that**,
and rather than stretch the exception mechanism to cover them they are held for **v2.0.0**.

**What makes it a major is Rule 2 above**, the accumulated breaking changes to the public Swift API,
not the OCCT version. Nothing in the trigger table changes: an 8.0.0 to 8.0.1 re-pin is a MINOR on
its own, and no single held entry forces a major on its own either.

v2.0.0 is not scheduled by a date. In practice it will be cut once the in-flight correctness work is
finished, and the OCCT 8.0.1 re-pin is expected to ride along with it rather than to trigger it. A
major for an OCCT major (8.x to 9.x) remains a separate, independently sufficient trigger.

**A release cut before then must not include a `CHANGELOG.md` entry marked as containing source
breaks.** Those entries name every break with its migration up front, which is the same treatment an
exception gets at tag time.

Currently held:

| Entry | Breaks | Why held rather than taken as an exception |
|---|---|---|
| [#609](CHANGELOG.md#unreleased-fix-zero-mass-brepgprop-results-were-returned-as-successful-answers-609), zero-mass `BRepGProp` results | 12 named signature changes across the mass-property surface, all compile errors, all with a documented migration | Scale. The four exceptions below cover one to six call-site shapes each; this one moves the whole mass-property surface at once, and a consumer measuring geometry would meet it everywhere rather than at a named method |

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

#### Recorded exception: Unreleased — junction-analysis flags become optional (#495)

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

#### Recorded exception: Unreleased, `PathParser` forwards to `OSDPath` (#499)

**Two behaviour changes, and unlike the two exceptions above these are *not* compile errors.** Recorded here before the tag is cut:

| Break | Issue | What a caller does |
|---|---|---|
| `PathParser.fileExtension(_:)` returns `".step"`, not `"step"` | #499 | Drop the caller's own dot, or strip the leading `.` |
| `PathParser.trek(_:)` returns `"/home/user/"`, not `"/home/user"` | #499 | Nothing, if the result is joined with a separator; otherwise trim the trailing `/` |

Both spellings still compile and still return a value; the deprecation attribute on each method raises a warning at every call site naming the exact format change, and `renamed:` points at the `OSDPath` method that now does the work. The exception was taken because:

- The disagreement *is* the bug. `PathParser.fileExtension` and `OSDPath.fileExtension` answered the same question in two formats, each pinned by its own test, neither compared to the other. Keeping both formats (by having `PathParser` strip what `OSDPath` returns) would have deduplicated the implementation while preserving the divergence the issue was filed about.
- The same forwarding fixes four cases where `TDocStd_PathParser` was wrong rather than differently formatted: an extension-less path parsed to an empty name *and* empty directory, a dotfile inside a directory returned `nil` from every accessor, a dot in a directory name was read as the file's extension, and non-ASCII paths came back mangled. Those four are ordinary PATCH-class fixes ("a method that returned `nil` when it shouldn't"); only the two formats above are a break.
- A warning, not an error, is the weaker prompt, stated plainly here rather than claimed otherwise. It is what the API allows: Swift cannot overload on return *value*, only on type, so there is no spelling in which the old format survives alongside the new one.
- Named in [`CHANGELOG.md`](CHANGELOG.md) with before/after code, and to be named in the release notes.

#### Recorded exception: Unreleased, one meaning for a face index (#541)

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

#### Recorded exception: Unreleased, an unresolvable sub-shape index refuses the call (#568)

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

#### Recorded exception: Unreleased, the last seven entry points join the one sub-shape enumeration (#613)

**Eight silent behaviour changes, none a compile error.** #541 put sub-shape indexing on the deduplicated `TopExp::MapShapes` enumeration and #568 settled what an unresolvable index does; seven entry points were left counting `TopExp_Explorer` *occurrences*. A plain 10 mm box has **24 edge occurrences over 12 edges** and **48 vertex occurrences over 8 vertices**, so each of these answered for indices `edge(at:)` refuses, and named a different sub-shape past the first repeat:

| Break | What a caller does |
|---|---|
| `edgeConcavities(angle:)` labels are realigned onto `edges()` | Nothing to change, but the answers move. Measured on an L-bracket: the one concave edge (index 27) was labelled convex and `concaveEdges()` returned `[]`. It now returns `[27]`. A caller who had worked around the old labels by hand should drop the workaround |
| `edgeConcavityCount(_:angle:)` counts edges, not occurrences | Expect roughly half the previous number. A 12-edge box reported **24** convex edges and now reports 12. A caller comparing it against `edgeCount` was always failing |
| `edgeEdgeExtrema(edgeIndex1:other:edgeIndex2:)` indexes `edges()` | Nothing on indices `0..<edgeCount` up to the first repeat; past it the answer now describes the edge the caller named. Indices `edgeCount..<24` return `nil` instead of an answer about some other edge |
| `checkEdge(at:)`, `checkWire(at:)`, `checkShell(at:)`, `checkVertex(at:)` | Same domain as `edge(at:)` / `subShapeCount(ofType:)` now. `checkEdge(at: 12)` on a box reported a valid edge and now reports invalid, matching `isSubShapeValid(type:at:)`, which has been map-backed since #541 |
| `splitEdge(at:parameter:)` splits the edge `edges()` names | Indices `0..<9` on a box are unchanged; 9, 10 and 11 now split the edge asked for rather than a different one, and 12…23 return `nil` |
| `edgesInFace(at:)` and `commonEdges(with:)` return a real `Edge.index` | The `index` on every returned `Edge` changes value. It was the position in the result array, so it addressed a different edge — or none. `edgesInFace(at: 3)` on a box handed back 0, 1, 2, 3 for edges whose indices are 2, 8, 10 and 11. A caller that used the old value as an array subscript into its *own* parallel array must switch to enumerating the result |
| `biTgteBlend(edgeIndices:radius:tolerance:nubs:)` indexes `edges()`, and refuses an unresolvable index | Both a #541-class and a #568-class change in one site. Measured on an L-bracket: no index blended the concave edge at all, and index 27 now does. An index naming no edge used to be dropped and the rest blended; the batch is refused (`nil`) now |
| `Mesh.Triangle.faceIndex` is an index into `faces()` | Nothing on a shape that shares no face. On one that does, the value changes: on a two-solid split compound the indices ran 0…11 over an 11-face shape, and both sides of the shared wall now carry the one index that names it |

The exception was taken because:

- **Every one of them is paired with a consumer on the other enumeration**, which is what makes the disagreement a wrong answer rather than a second convention. The sharpest case is `OCCTBRepExtremaExtCC`, which sits in the same file as `ExtPC`, `ExtCF` and `ClassifyPoint2D` — all converted by #541 — so `edgeIndex` meant one thing in one function and another in its neighbour. `checkEdge(at:)` disagreed with `isSubShapeValid(type: .edge, at:)`, and `splitEdge(at:)` with `splitFace(at:with:)` driving the same `LocOpe_SplitShape`.
- **The end-to-end failure is the one the API's own documentation recommends.** `Shape.filleted(edges:radius:)`'s doc snippet is `bracket.filleted(edges: bracket.concaveEdges(), radius: 3)`. With the concavity labels desynchronised that rounded nothing and reported success.
- **There is no spelling in which both survive**, for the same reason as #541 and #568: these are index *values*, so Swift cannot overload on them and a deprecation attribute has nothing to attach to.
- **On every shape that shares no sub-shape, nothing moves** for the face-indexed and mesh entry points. The edge- and vertex-indexed ones do move on ordinary solids, because every edge of every solid is shared between two faces — that is exactly the gap #613 closes, and it is why these are recorded rather than treated as internal.
- **One site was deliberately NOT converted.** `OCCTPolyMergeNodes` walks face occurrences to set per-face triangle winding; deduplicating it would drop a shared wall's second side. It is unchanged, documented as such, and pinned by a test that fails if a later sweep converts it.
- Named in [`CHANGELOG.md`](CHANGELOG.md) with the measurements, and to be named in the release notes.

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
