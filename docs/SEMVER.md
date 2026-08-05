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

The load-bearing guarantee is the SemVer guarantee: **no breaking change without a major bump**. Within a major line, all minor and patch updates are safe to take blindly, with **twelve** recorded exceptions. Three of them **do not compile** until the caller acts, so an upgrade cannot silently absorb them:

- [v1.17.0](#recorded-exception-v1170-2026-07-29) breaks source compatibility in two named places.
- [#495](#recorded-exception-unreleased--junction-analysis-flags-become-optional-495) in one, making junction-analysis flags optional.
- [#619](#recorded-exception-unreleased-continuityorder-is-retired-rather-than-reinterpreted-619) retires `Curve3D.continuityOrder`, `Curve2D.continuityOrder` and `Surface.surfaceContinuityOrder` outright — deliberately, to convert a change that had already happened to their *values* into one a caller cannot miss.

The other nine change behaviour **without breaking the build**, which is the set to read before upgrading blindly:

- [#499](#recorded-exception-unreleased-pathparser-forwards-to-osdpath-499) changes what two deprecated `PathParser` methods return.
- [#541](#recorded-exception-unreleased-one-meaning-for-a-face-index-541) moves six sub-shape index conventions onto one.
- [#568](#recorded-exception-unreleased-an-unresolvable-sub-shape-index-refuses-the-call-568) makes five more entry points refuse an index they used to skip.
- [#613](#recorded-exception-unreleased-the-last-seven-entry-points-join-the-one-sub-shape-enumeration-613) moves the last seven entry points off the per-occurrence walk onto that same enumeration.
- [#498](#recorded-exception-unreleased-buildcurves3ds-default-tolerance-loosens-498) loosens `buildCurves3d`'s default tolerance 100×.
- [#502](#recorded-exception-unreleased-the-wiresshellssolids-enumerations-join-the-deduplicated-map-502) collapses the `wires`/`shells`/`solids` enumerations onto the deduplicated sub-shape map.
- [#642](#recorded-exception-unreleased-aag-builds-nodes-from-face-occurrences-642) moves `AAG`'s node set from distinct faces to face occurrences, so `detectPocketsAAG()` and `buildAAG().nodes` can return more entries on a shape with a shared face.
- [#651](#recorded-exception-unreleased-nbedgesnbfacesnbvertices-are-deprecated-and-forward-to-the-deduplicated-count-651) deprecates `Shape.nbEdges`/`nbFaces`/`nbVertices` in favour of `edgeCount`/`faceCount`/`vertexCount`, and changes what the deprecated three return on the way.
- [#699](#recorded-exception-unreleased-aag-adjacency-and-convexity-are-scoped-to-one-solid-699) restricts `AAG`'s adjacency/convexity checks to same-solid face pairs, further changing what `detectPocketsAAG()` can return on a multi-solid compound: the same public API #642 already named, corrected further rather than a new one opened.

A thirteenth was **not** taken: [#609](#held-for-the-next-major-v200)'s twelve breaks are held for v2.0.0 instead.

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

#### Recorded exception: Unreleased, `nbEdges`/`nbFaces`/`nbVertices` are deprecated and forward to the deduplicated count (#651)

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

#### Recorded exception: Unreleased, `continuityOrder` is retired rather than reinterpreted (#619)

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

#### Recorded exception: Unreleased, the `wires`/`shells`/`solids` enumerations join the deduplicated map (#502)

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

#### Recorded exception: Unreleased, `buildCurves3d`'s default tolerance loosens (#498)

**One silent behaviour change, not a compile error.** Recorded here on the #619 sweep, which asked of every "a value changed under an unchanged signature" site whether the change was decided or merely happened:

| Break | What a caller does |
|---|---|
| `Shape.buildCurves3d(tolerance:)`'s default moves from `1e-7` to `1e-5`, a 100× loosening | Nothing, unless the tighter curve was being relied on — then pass `tolerance: 1e-7` explicitly. The value is also written onto the rebuilt edge as its tolerance, so a caller who cared about edge tolerance downstream should re-check it |

**Decision: keep `1e-5`.** The alternatives considered were reverting to `1e-7`, and removing the default outright so every caller must choose (the response #541 took for `defeature(faces:tolerance:)`). Both were rejected:

- **`1e-5` is OCCT's own default, and `1e-7` was OCCTSwift's invention.** `BRepLib::BuildCurves3d(const TopoDS_Shape&)` is literally `return BRepLib::BuildCurves3d(S, 1.0e-5);` (`BRepLib.cxx:463`), and `BRepLib::BuildCurve3d`'s header declares `Tolerance = 1.0e-5`. Reverting would restore a number no upstream API asks for.
- **The old default over-claimed.** OCCT writes this tolerance onto the edge as a floor rather than the deviation actually achieved, so `1e-7` had every rebuilt edge asserting a tightness the approximation may not hold on hard geometry. Measured on a helix, `1e-5` deviates 2.6e-6 and `1e-7` deviates 9.0e-8 — the tighter fit is real, but it costs a pole or two and it is a claim the caller should make deliberately.
- **Removing the default is disproportionate here.** Unlike the index rebases of #541/#568, the two values do not mean *different things* — both are tolerances, in the same units, ordered the obvious way. A caller reading `1e-5` is not misled about what it is; a caller reading a 0-based index as 1-based is. The break is a precision change, not a semantic one, so a recorded decision plus the doc note is the proportionate response.
- Named in [`CHANGELOG.md`](CHANGELOG.md) with the measurement, and to be named in the release notes.

#### Recorded exception: Unreleased, AAG builds nodes from face occurrences (#642)

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

#### Recorded exception: Unreleased, AAG adjacency and convexity are scoped to one solid (#699)

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
