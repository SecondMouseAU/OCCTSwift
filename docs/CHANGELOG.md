---
title: Changelog
nav_order: 13
---

# Changelog

All notable changes to OCCTSwift.

## Current: v1.17.0

**macOS / iOS (device + simulator) | OCCT 8.0.0p1 (+ #263, #280, #298, #310, #317, #318, #319, #323, #341, #344, #348, #349, #353, #374 kernel patches)**

---

## Unreleased

### CI builds the same kernel the branch is written against

`Package.swift` now pins the [`v2.0.0-kernel.1`](https://github.com/SecondMouseAU/OCCTSwift/releases/tag/v2.0.0-kernel.1)
pre-release: upstream `V8_0_1` plus the eleven carried patches `0010`-`0012` and `0014`-`0021`. It
previously pinned v1.15.18, which is `V8_0_0_p1` + patches `0001`-`0016`.

That mismatch made `ci.yml`'s macOS job useless as a signal on this branch. Every test asserting
behaviour a newer patch fixes failed there, indistinguishably from a real regression, and **seven
suites were red for that reason alone**: `#522` approximation collapse, `#570` healing
approximations, both `#572` sweep and conversion suites, `#491` approximation parity, `#496`
cylindrical hole contracts and `#532` hole part selection. Every new correctness fix added more,
and the documented workaround was to read `kernel-integration.yml` instead (#585).

Against the new pin, with no local `Libraries/` and no `OCCTSWIFT_LOCAL`, the full suite is **5,313
tests, 0 failures**. `OCCTSWIFT_LOCAL=1` remains useful for iterating on a locally rebuilt kernel; it
is no longer required to get correct results.

The pre-release is not a library release, and is not installable as one. The v2.0.0 release commit
re-points `url:`/`checksum:` at the final asset (#512), but the pre-release itself is **kept**: every
commit in the v2.0.0 window pins it, so deleting it would take its asset with it and make those
commits unbuildable from a clean checkout, breaking `git bisect` and historical re-measurement.

Verified before publishing, per `docs/guides/building-occt.md`'s shipping checklist: `occt-src` at
exactly `V8_0_1`, all eleven patches reverse-apply, and zero modified files that no carried patch
touches, so no investigation probe is compiled in. The published asset re-downloads to the same
SHA256 it was uploaded with.

### OCCT re-pinned to 8.0.1

The source pin moves from `V8_0_0_p1` to [`V8_0_1`](https://github.com/Open-Cascade-SAS/OCCT/releases/tag/V8.0.1)
(2026-07-30), the first maintenance release in the 8.0 series. Against p1 it is a clean
fast-forward (23 commits, 74 files, nothing reverted) and it carries **no API or ABI break**:
the only public header in the whole diff is `ShapeAnalysis_FreeBounds.hxx`, changed by one comment
line. Nothing to migrate for the OCCT API itself.

**`Package.swift`'s `url:`/`checksum:` pointed at the v1.15.18 asset when this landed**, which is
p1 + patches 0001-0016, on the #512 rule that the bump belongs to the release commit. That is no
longer the case: see "CI builds the same kernel the branch is written against" above, which pins the
`v2.0.0-kernel.1` pre-release. A clean checkout with no local `Libraries/` now resolves the right
kernel, and `ci.yml`'s macOS job is a real signal. `OCCTSWIFT_LOCAL=1` remains useful for iterating
on a locally rebuilt kernel; it is no longer needed for correct results.

#### `edges()` keeps its orientation collapse: audited, no consumer needs it (#638)

Documentation only, no code change.

`Shape.edges()` has the identical `TopExp::MapShapes`/`IsSame` collapse #614 fixed for `faces()`:
an edge reachable from two owners collapses to one entry carrying whichever orientation was reached
first. Measured on a plain box, `edges().count`/`edgeCount` report 12 distinct edges while
`Shape.contents.edges` (an independent, already-documented occurrence count) reports 24: one per
(face, edge) visit.

#614 was a defect because `Face.normal(atU:v:)` reverses on `TopAbs_REVERSED`, so a face's stored
orientation changed the answer a caller got. This issue's own text refused the analogy and asked
whether the same is true for edges before assuming it. It is not: `Edge` exposes no `.orientation`
accessor at all, and every geometric query on it (`tangent(at:)`, `point(at:)`, `parameterBounds`,
`curvature(at:)`) reads the edge's underlying `Geom_Curve` through `BRep_Tool::Curve`, which is
defined independently of `TopAbs_Orientation`. A bridge-wide grep for `.Orientation() ==` across
`Sources/OCCTBridge/src/*.mm` finds 14 branching sites: 13 are face-normal logic #614 already
covers, and the fourteenth (`occtSampleWirePoints`, `OCCTBridge_Modeling.mm`) reads orientation
fresh off a `BRepTools_WireExplorer` walk of the wire it samples, never from an edge `Shape.edges()`
produced.

Verified beyond the source read: constructing the identical edge with both `TopAbs_Orientation`s
(`Shape.subShape(type:index:).reversed`) and comparing every accessor `Edge` exposes shows them
bit-for-bit identical, on both a straight and a circular edge.

**Decision: document the contract, add no `orientedEdges()`, change no behaviour.** This is the
outcome this issue's own text names as correct when no orientation-dependent consumer exists.
`Shape.edges()`/`edgeCount`'s doc comments and `docs/reference/Edge.md` now state the collapse
explicitly, matching how `Shape.faces()` documents its own. Regression tests in
`Tests/OCCTTopologyTests/Issue638EdgeOrientationContractTests.swift` pin both halves: the dedup
mechanism itself (12 distinct / 24 occurrences on a box, 20 distinct on the #614 split fixture), and
the orientation-independence of `Edge`'s per-instance accessors, verified by injecting a
hypothetical orientation-aware tangent and watching it fail before restoring it.

See [`Scripts/repro/cluster-a-subshape-enumeration/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/cluster-a-subshape-enumeration)
(#664) for the full census this decision rests on.

#### Ten carried kernel patches retired

8.0.1 ships our own upstream contributions, so `Scripts/patches/` goes from 21 files to 11.
Retired: `0001`-`0009` and `0013`, covering #263, #280, #298, #310, #317, #318, #323 (three) and
#348. Every merge commit was confirmed an **ancestor of the tag** rather than merely merged to
master, and every patch was diffed against its as-merged form before its file was deleted, because
review can change a patch between submission and merge.

Nine came back unchanged. `0001` did not: upstream's merged form also guards a *removed* face
(`anApplied.IsNull() ||`) where ours checked only the shape type, so that retirement fixes a
latent null dereference our own patch had. Per-patch verdicts are in
[`Scripts/patches/README.md`](../Scripts/patches/README.md) under "Retired patches".

Patch numbers are not reused: the carried sequence now reads 0010-0012, 0014-0021, and the gaps
are the retirements. Renumbering would have repointed every citation in `CLAUDE.md`, `docs/`,
closed issues and `Scripts/repro/` at a different fix.

#### Behaviour changes 8.0.1 brings, measured

The full suite is green on the new kernel (**5313 tests, 1400 suites, 0 failures**), but a green
suite is not evidence for two of these, because no test in the repo uses INTERNAL/EXTERNAL edge
orientation and [#645](https://github.com/SecondMouseAU/OCCTSwift/issues/645) records that the
Gordon tests assert only status ordinals. Those two were probed directly. Tracked in
[#654](https://github.com/SecondMouseAU/OCCTSwift/issues/654).

- **`GeomFill_Gordon` was returning a 5% wrong surface, and 8.0.1 fixes it.** Handed the isocurves
  of the surface it should reproduce, a rational network (quarter cylinder, r=5) deviated
  **0.251262658** from its own input while reporting `IsDone`; it is now **2.6e-15**. The 45° sample
  moves from `3.713203436` to `3.535533906`, which is exactly `5/√2`. A non-rational control was
  already exact on both kernels, so only rational networks ever moved. Affects
  `Surface.gordon(profiles:guides:tolerance:)` and `Surface.gordonReport(...)`. Evidence added to #645.
- **`Shape.sectionWiresAtZ(_:tolerance:)`, not `freeBounds*`, sees the INTERNAL/EXTERNAL skip**
  ([#655](https://github.com/SecondMouseAU/OCCTSwift/issues/655)).
  `ShapeAnalysis_FreeBounds::ConnectEdgesToWires` now skips edges oriented `.internal`/`.external`:
  a sequence of one INTERNAL edge plus a square returns 1 wire where it returned 2, and a sequence
  of nothing but INTERNAL/EXTERNAL edges returns 0 wires where it returned 1. That C++ function
  appears exactly once in this bridge, inside `OCCTShapeSectionWiresAtZ`, which backs
  `Shape.sectionWiresAtZ(_:tolerance:)`, a CAM sectioning API: in every case measured, an ordinary
  transverse cut does not produce such an edge, but a cut plane coincident with an edge a caller
  already marked `.internal`/`.external` via `Shape.setOrientation(_:)` does move, 2 wires to 1 on
  a measured fixture. The `freeBounds*` family does **not** move, but not because its call graph
  avoids the change: `Shape.freeBounds`, `freeBoundsClosedCount`, `freeBoundsClosedWires` and
  `freeBoundsOpenWires` build `ShapeAnalysis_FreeBounds`'s `(shape, tolerance)` constructor, whose own
  chainage step reaches the same skip. The reason is upstream, the edges that constructor feeds in
  come from `BRepBuilderAPI_Sewing::FreeEdge`, and in every case measured that sewing stage never
  produced an `.internal`/`.external` free edge for the skip to act on. `freeBoundsAnalysis`,
  `FreeBoundsProperties` and its four accessors take a **second** constructor at `tolerance <= 0`,
  with no sewing stage at all, so that reason does not apply to them; measured separately, the
  exclusion holds there too.
- **`BRep_Tool::CurveOnPlane` fails differently.** An out-of-domain, inverted or zero-length edge
  range now yields a null pcurve where 8.0.0p1 threw a catchable
  `Geom_TrimmedCurve::parameters out of range`. All four probed cases changed.
- **No movement** from the `BRepMesh` periodic-seam fix, the `ChFi3d_Builder::StartSol` hardening,
  or the `BRepCheck_Face`/`GeomLib_CheckCurveOnSurface` fast paths. For those three the green suite
  *is* evidence, since they are well covered.

#### Fixed: `evalAndUpdateTolerance` handed OCCT an unguarded null pcurve

`Shape.evalAndUpdateTolerance(edge:face:)` was an uncatchable SIGSEGV whenever the edge had no
pcurve on the given face and that face was not planar, which is routine for mesh-sewn topology. The bridge
guarded the 3D curve and the surface but passed the pcurve straight into
`BRepTools::EvalAndUpdateTol`, which dereferences it at `if (!C2d->IsPeriodic())`.

Fixed here rather than deferred because the re-pin **adds a second route to it**: with #1402
returning null instead of throwing, the crash became reachable on a planar face too, where 8.0.0p1
returned a safe `0.0`. Shipping the absorb without the guard would have introduced a new crash
path. [#656](https://github.com/SecondMouseAU/OCCTSwift/issues/656).

#### `build-occt.sh` could not change OCCT version

It cloned `occt-src` only when the directory was absent, so bumping `OCCT_VERSION`/`OCCT_RC` was a
silent no-op on any machine that had built before: the old tag's sources were compiled and packaged
under the new version's number. It now requires `HEAD` to be at the tag the script names and aborts
otherwise, naming the tree so a diagnostic probe left by an investigation is not destroyed silently.

### `chamfer2D` SIGSEGVs, uncatchably, on a repeated edge pair (#705)

Found by Cluster B's edge/vertex-index census (#665, `Scripts/repro/cluster-b-fillet-edge-contract/`),
which records the crash rather than running it live, since an in-process OS signal would kill the
census itself. `Shape.chamfer2D(edgePairs:distances:)` crashed the whole process, uncatchably, when
the same edge pair appeared twice:

```swift
let wire = Wire.polygon3D([SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0)], closed: true)!
let rectFace = Shape.face(from: wire)!
_ = rectFace.chamfer2D(edgePairs: [(0, 1), (0, 1)], distances: [1.0, 2.0])   // SIGSEGV, exit 139
```

Confirmed in a separate process (a temporarily-repointed `Sources/OCCTTest/main.swift`, restored
after), since an in-process crash kills the test runner rather than failing one test:

| Input | Before | After |
|---|---|---|
| `[(0, 1), (0, 1)]` | SIGSEGV, exit 139 | `nil`, exit 0 |
| `[(0, 1), (1, 0)]` (reversed, same pair) | SIGSEGV, exit 139 | `nil`, exit 0 |
| `[(0, 1), (0, 1), (0, 1)]` | SIGSEGV, exit 139 | `nil`, exit 0 |
| `[(0, 1), (1, 2)]` (one edge, two different pairs) | non-nil, unaffected | non-nil, unaffected |
| `[(0, 1), (1, 2), (2, 3), (3, 0)]` (every corner) | non-nil, unaffected | non-nil, unaffected |

The crash is inside the repeat call's own `BRepFilletAPI_MakeFillet2d::AddChamfer`, an OS signal
the bridge's `catch (...)` cannot absorb, and it is an upstream OCCT defect, not this bridge's own.
`AddChamfer(edge1, edge2, ...)` calls `ChFi2d::FindConnectedEdges` to look up the pair's shared
vertex and dereferences the two edges it returns without checking the returned status first, and
that lookup leaves both edges null on every failure path. A pair's second call fails the lookup,
because its shared vertex was already consumed chamfering the pair the first time. The sibling
overload (`AddChamfer(edge, vertex, distance, angle)`) checks the identical status correctly, which
is the precedent the upstream filing cites. Reusing one edge across two *different* pairs, i.e.
chamfering adjacent corners of a polygon, the ordinary multi-corner case, does not crash, measured
above. Only the identical pair repeated does, order-independent. A kernel patch is carried
separately, tracked in a follow-up PR; the guard below is what protects callers until it ships.

**Fixed**: `OCCTFace2DChamfer` (`OCCTBridge_Modeling.mm`) now checks each pair against every prior
pair in the same call before invoking `AddChamfer`, and rejects the whole request (returns `nullptr`)
on a match in either order. This matches `fillet2D(vertexIndices:radii:)`'s own contract for a
duplicated vertex on the same builder (#568) and the #568 idiom already used one line above in the
same function for an out-of-range index: the whole call fails rather than guessing which of two
distances to keep. #633 is open on the wider family's duplicate-index direction (fillet is
last-wins, chamfer is first-wins) and is deliberately not settled here; this fix removes a crash,
not a vote in that debate, though it is recorded as a data point for it.

This is a behaviour change on a public API with no compile error, recorded in
[`SEMVER.md`](SEMVER.md#recorded-exception-unreleased-chamfer2d-refuses-a-repeated-edge-pair-instead-of-crashing-705).
A call with no repeated pair, which includes every existing caller, is unaffected. Tests:
`Tests/OCCTModelingTests/Issue568IndexSkipTests.swift`'s `chamfer2DRejectsDuplicatePair` and
`chamfer2DAcceptsSharedEdgeAcrossDifferentPairs`, the latter proven to catch an overly broad fix by
injecting one (reject on any repeated single index rather than a repeated pair) and confirming it
turns the shared-edge test red, then restoring.

The census's own row for `chamfer2D` is updated from `CRASH (SIGSEGV, uncatchable)` to the measured
`REJECT (nil)`, now safe to run live: `swift run Censuses cluster-b` calls it directly rather than
noting it as unsafe to run.

### Pass 1b of the #377 duplication audit

#### The fillet family could not report a declined edge, only skip it silently (#639)

`BRepFilletAPI_MakeFillet::Add` does nothing, with no exception and no false return, for an edge it
cannot fillet, most commonly a free-boundary edge of an open shell, which has only one adjacent
face where a fillet needs two. `filleted(edges:radius:)`, `filleted(edges:startRadius:endRadius:)`
and `filletEvolving(_:)` have always skipped such an edge rather than rejecting the whole call
(#612), correctly, but had no way to tell a caller which edges those were, or how many. The Cluster
B census (`Scripts/repro/cluster-b-fillet-edge-contract/`) measured the gap concretely: filleting
all 12 edges of an open shell (a box with one face dropped, sewn) accepts 8 and silently declines 4
(`[6, 9, 10, 11]`), and every one of these three entry points reports plain success.

**The decision this issue asked for, made explicitly:** report, do not reject. Converging every
declining entry point onto rejecting a batch with any declined edge would change
`filleted(edges:radius:)`, `filleted(edges:startRadius:endRadius:)` and `blendedEdges(_:)` on every
open shell: a behaviour change wider than this issue, and the same mistake an earlier draft of
#633 made and withdrew. Skip stays the answer; the fix is observability, following #482's
`FillingSurface.refusedConstraintCount` precedent named in the issue.

**What OCCT can actually say, measured before designing around it:** `Add` returns nothing, and
`BRepFilletAPI_MakeFillet::NbFaultyContours()`/`BadShape()`/`StripeStatus()` describe a *contour*
that failed during `Build()`, which an edge OCCT never added to any contour never reaches. The one
signal OCCT does expose is `Contour(edge) == 0`, populated by `Add()` itself rather than by
`Build()`. So this reports **which** edges were declined (a list of indices, not just a count: the
issue's own "count is cheap, naming which is more useful" argument, taken as far as it goes), and
**not why**: no reason is reachable from this API.

**Fixed for the three entry points that genuinely had no side channel**: `filleted(edges:radius:)`
and `filleted(edges:startRadius:endRadius:)` (`OCCTShapeFilletEdges`/`OCCTShapeFilletEdgesLinear`,
sharing `occtShapeFilletEdgeList`) and `filletEvolving(_:)` (`OCCTShapeFilletEvolving`) each gained
a `WithReport` sibling, `filletedWithReport(edges:radius:)`,
`filletedWithReport(edges:startRadius:endRadius:)`, `filletEvolvingWithReport(_:)`, returning a
new `Shape.FilletResult { shape, declinedEdgeIndices }`. The bridge computes the report with a new
shared helper (`occtFilletDeclinedIndices`/`occtFilletWriteDeclined`, `OCCTBridge_Internal.h`) that
re-checks `Contour(edge)` for each requested index after every `Add()` and before `Build()`; the
three underlying bridge functions gained two nullable trailing out-parameters the existing
non-reporting call sites pass `nil` for, so nothing about their cost or behaviour changes.

**Two of the issue's own named members already carried the mechanism, measured rather than assumed
missing:** `filletedWithFullHistory(radius:edges:)`'s `ShapeHistoryRef` distinguishes a declined
edge from an accepted one via `!record.isDeleted && record.generated.isEmpty`. An edge OCCT
actually filleted is always deleted with the new fillet-boundary edges in `generated` (12/12 on the
fixture). **The first hypothesis for this recipe was wrong and caught by measuring it**: a declined
edge is not necessarily `modified.isEmpty` too. On this fixture every declined edge shows exactly
one `modified` entry, a *different* edge instance with a shorter length (10.0 to 8.0), because an
*accepted* neighbour's fillet trims the declined edge's shared endpoint. `modified` alone is not the
signal; `generated`/`isDeleted` are. Separately, `FilletBuilder.contour(for:)`, already present and
unrelated to this issue, answers the identical `Contour(edge) == 0` question directly, readable
right after `addEdge` with no `build()` required, matching the census's measured set exactly before
and after `build()`. Both are documented (`ShapeHistoryRecord`, `FilletBuilder`) with a runnable
recipe rather than given new bridge code, since there was nothing to add.

**`blendedEdges(_:)`, #633's own site, does not adopt this mechanism here.** It is the same SKIP
behaviour on the same declined-edge axis, so the same `WithReport` shape would apply, but #633 is
about a *different* axis of this contract (a duplicated edge index silently discards a radius) and
is scheduled after this PR specifically because the reporting decision made here might change what
#633 should do. Recommendation for that issue: adopt the same `FilletResult`-shaped report,
extended to also carry which duplicate indices were overwritten, since the same
"list what happened, do not change what SKIP or OVERWRITE means" principle applies to it too.

New tests: `Tests/OCCTModelingTests/Issue639FilletDeclinedEdgeReportTests.swift`, seven cases
covering all five members named in the issue (the three `WithReport` siblings, the `FilletBuilder`
recipe, the history recipe) plus two "empty on a closed solid" negative controls. Each of the five
declined-set assertions was proven to catch its own mechanism, not just some regression elsewhere:
reverting `occtFilletWriteDeclined` to report nothing fails exactly the three `WithReport` tests (the
two negative controls correctly stay green, since they expect empty anyway); separately reverting
`OCCTFilletBuilderContour` fails exactly the `FilletBuilder` test; separately reverting
`OCCTBooleanHistoryIsDeleted` fails exactly the history test.

This is additive, non-breaking Swift API (three new methods, one new struct, no existing signature
changed), recorded in [`SEMVER.md`](SEMVER.md#639-additive-fillet-decline-reporting-not-an-exception)
per #664's discipline of writing this down now rather than at tag time, even though nothing here
moves the file's own "twelve recorded exceptions" count. `Scripts/repro/cluster-b-fillet-edge-contract/`
is unchanged: the census measures the contract, this issue only adds a way to observe one axis of
it, and the measured grid itself (SKIP/REJECT per cell) does not move.

#### `AAG` rode the lossy `faces()`, so `detectPocketsAAG()` answered 2 or 1 for the same geometry depending on compound member order (#642)

`AAG.buildGraph()` built its node set from `Shape.faces()`, the `IsSame`-keyed enumeration #614
documented as orientation-insensitive by design: a face occurring both FORWARD and REVERSED
collapses to one entry, keeping whichever orientation was reached first. `AAGNode.isHorizontal`/
`isUpward`/`isDownward`/`isVertical`/`zLevel` are all derived from that entry's normal, and
`AAG.detectPockets()` selects floors on exactly those fields, so which orientation survived the
collapse silently decided the answer. #614 already fixed `horizontalFaces()`, `upwardFaces()` and
`facesByZLevel()` by routing them onto `orientedFaces()`; `AAG` was a fourth consumer that PR did
not reach, because it was never enumerated as one.

Measured on an origin-centred 10mm box cut through z=4 and recompounded in both member orders, the
exact fixture Cluster A's census (#664) confirmed reproduces this: `detectPocketsAAG().count` was
**2** in one order and **1** in the other, and the AAG upward+horizontal node set was `[2, 8]`
against `[2]`, for identical geometry. **#614's own committed fixture, a vertical rather than
horizontal cut, does not exercise this at all** (its shared wall's normal is horizontal-axis, never
reaching `isHorizontal()`): a regression test built from that fixture would have found no
order-dependence and wrongly concluded the defect did not exist. That correction came from the
census, not this issue's own text.

**Fixed** by moving `AAG.buildGraph()` onto `Shape.orientedFaces()`: a face shared between two
solids in a compound is now two nodes, one per owning solid, each carrying that solid's own normal,
rather than one node carrying whichever normal the dedup happened to keep. `AAGNode` gains
`distinctFaceIndex`, the node's position in the old `faces()` enumeration, so a caller can still
tell the two sides of a shared face apart or recover the previous one-node-per-face view.
`buildGraph()` also gained a guard skipping any pair of nodes that share a `distinctFaceIndex`:
without it, `OCCTFacesAreAdjacent` (which compares edge sets by `IsSame`, ignoring orientation)
reports every one of a shared face's own boundary edges as adjacent to itself, since both
occurrences bound the identical edge set.

Two other approaches were considered and rejected, per the precedent #614 set of naming rejected
alternatives: carrying both normals on one node per distinct face (preserves the old index model,
but pushes the "which side" ambiguity onto every caller of `isUpward`/`isHorizontal`/etc. instead of
resolving it once), and restricting `AAG` to single-solid input (never established as the only
valid use, and would not fix anything for the multi-solid case it was already used for).

**A second, different, pre-existing defect surfaced while verifying the fix, and is deliberately
not fixed here.** On the vertical-cut fixture, `detectPocketsAAG().count` moved from agreeing (1/1)
to disagreeing (1/2) across member order, confirmed by reverting `buildGraph()` alone to show the
identical asymmetry already existed before this fix and only cancelled out by coincidence in the
total count. The mechanism: `OCCTFacesAreAdjacent`/`OCCTEdgeGetConvexity` have no concept of solid
membership, so a face occurrence's adjacency and convexity are checked against every topologically
coincident neighbor, including one that belongs to a different solid than the occurrence's own
orientation. Doubling the shared wall's node count made this pre-existing ambiguity fire more
often. Recorded in `Scripts/repro/cluster-a-subshape-enumeration/README.md` rather than fixed, since
it is a different mechanism than #642's own (a graph lacking solid-membership tracking, not a
normal losing information across a dedup collapse) and out of this issue's scope.

This is a behaviour change on two public APIs (`Shape.buildAAG()`, `Shape.detectPocketsAAG()`) with
no compile error, recorded in [`SEMVER.md`](SEMVER.md#recorded-exception-unreleased-aag-builds-nodes-from-face-occurrences-642).
On every shape that shares no face, `orientedFaces()` equals `faces()` exactly, so nothing about a
single-solid shape's AAG changes. Tests:
`Tests/OCCTModelingTests/Issue642AAGNodeIdentityTests.swift`, each proven to catch its own mechanism
by reverting it alone: reverting `orientedFaces()` back to `faces()` fails 5 of 7 tests (the two
no-regression tests, on a plain box and on #614's own vertical-cut fixture, correctly still pass);
separately reverting only the `distinctFaceIndex` adjacency guard fails exactly the one test that
exists to catch it.

#### `AAG` linked faces across a solid boundary, so #642's own fix moved a second, independent order-dependence into view (#699)

Found while measuring #642's own fix. Cluster A's census (`Scripts/repro/cluster-a-subshape-enumeration/`)
re-ran after #642 landed and caught a NEW disagreement on a fixture #642 does not touch: a plain
10mm box split by an X-normal plane through x=4, recompounded in both member orders,
`detectPocketsAAG().count` was **1** in one order and **2** in the other, for identical geometry.
Confirmed with `git stash` that reverting #642 alone reproduces the identical asymmetry, so this is
not something #642 introduced: #642's fix (doubling a shared face's node count) exercised it twice
as often, which is why a previously-accidental cancellation stopped holding.

**The mechanism is different from #642's, and needs a different fixture to show.** #642 was about
node identity: which faces become graph nodes. #699 is about edges: which nodes get linked and with
what attribute. `OCCTFacesAreAdjacent` and `OCCTEdgeGetConvexity` (`OCCTBridge_BRepGraph.mm`) have
no concept of solid membership: both compare two `TopoDS_Face` values purely on their own edge
geometry, ignoring the `shape` argument they are handed beyond a null check. On a vertical two-solid
split, the shared wall borders two half-faces of the box's original top face that also border
**each other** along the cut line, so one edge is common to three face occurrences (both top-face
halves and both sides of the wall). `AAG.buildGraph()`'s pairwise loop compared all three against
each other regardless of which solid each belonged to, linking a face in one solid to a face in
another and attributing a convexity meaningless for either. #642's own fixture (a horizontal cut)
never exercises this: its shared wall's normal is horizontal-axis, so `isHorizontal()`/`isUpward()`
never reach the duplicated face at all, and conversely #642's own defect needs a horizontal cut, so
neither fixture reproduces the other's mechanism.

**The contract:** two faces sharing a B-Rep edge but belonging to different solids in a compound are
adjacent *in the compound* and not adjacent in *either* solid, and `AAG`'s consumers
(`detectPockets()`, `concaveNeighbors(of:)`, `convexNeighbors(of:)`) want the solid-scoped answer.

**Fixed** by restricting `AAG.buildGraph()`'s pairwise adjacency/convexity check to occurrence pairs
it can establish share a solid, rather than by adding solid-scoping to the bridge functions
themselves: an audit found `OCCTFacesAreAdjacent`/`OCCTEdgeGetConvexity` have exactly one Swift
call site each, both inside `buildGraph()`, so there was no other consumer a bridge-side change
could have broken, and the Swift-side fix is the smaller change either way. Solid membership per
occurrence is derived rather than looked up through a new bridge entry point: `orientedFaces()`'s
underlying `TopExp_Explorer` walk visits every occurrence under one top-level solid contiguously
before moving to the next, in the same first-encountered order `Shape.solids` itself enumerates
solids in (both are one DFS over the same shape), so the flat occurrence list partitions into
contiguous runs sized by each solid's own face-occurrence count. Confirmed against both split
fixtures (dumping every occurrence's bounds alongside each solid's own `orientedFaces()` count)
before relying on it. `AAG.buildGraph()` falls back to the pre-#699 unrestricted comparison on a
shape with zero or one solid, or if the per-solid counts don't sum to the total occurrence count.
Silently mis-partitioning would be worse than not partitioning at all, and neither case arises on
any fixture this change measures.

`OCCTEdgeGetConvexity` did not need its own solid-membership fix on top of this: once adjacency is
restricted to same-solid pairs, convexity is only ever computed for a legitimate same-solid
neighbor. (A separate, unrelated defect was found while explaining a side effect below:
`OCCTEdgeGetConvexity`'s reported concavity for a given physical edge depends on argument order,
which reproduces on a single, uncut box and has nothing to do with solid membership. Recorded in
`Scripts/repro/cluster-a-subshape-enumeration/README.md` rather than fixed here, since it was found
explaining a side effect rather than measured as this issue's own claim.)

**A further correction to #642's own headline measurement.** Restricting to same-solid pairs also
moves the HORIZONTAL fixture's `detectPocketsAAG().count` from `2` (in both orders, #642's own fix)
to `1` (in both orders). This is not a regression: #642 was about order-AGREEMENT, which survives
intact (`1` in both orders, was `2` in both orders, still equal either way). What moved is that one
of the two "pockets" reported before #699 was itself built from a cross-solid comparison between
the shared wall and the wrong side of a split face, exactly the mechanism this issue fixes.
`Tests/OCCTModelingTests/Issue642AAGNodeIdentityTests.swift`'s own pinned count moves from `2` to
`1` accordingly, with a note explaining why; the AGREEMENT assertion it exists to guard is
unchanged and still passes.

This is a further behaviour change on `Shape.detectPocketsAAG()`, recorded alongside #642's own
entry in [`SEMVER.md`](SEMVER.md#recorded-exception-unreleased-aag-adjacency-and-convexity-are-scoped-to-one-solid-699)
rather than a new one, since it is the same public API. On every shape with zero or one solid,
nothing changes. Tests: `Tests/OCCTModelingTests/Issue699AAGSolidScopedAdjacencyTests.swift`, each
proven to catch its own mechanism by reverting the fix alone (7 assertions across 3 tests fail,
reproducing the exact 1-vs-2 and 2-vs-1 disagreements measured above; the single-solid and
node-count tests correctly still pass, since #699's fix touches edges, not nodes, and never applies
to a single-solid shape).

#### Every workflow action pin moves to a Node 24 major (#648)

#625 bumped only the job it introduced, so `ci.yml` was left mixed-version: `actions/checkout@v7` in
`gate-scripts`, `actions/checkout@v4` in `build-and-test` and `ios-simulator-build`. Deprecation
annotations are emitted per **job**, not per workflow, so each remaining v4 job raised its own
"Node.js 20 is deprecated" warning.

All 17 pins across the five workflow files were enumerated rather than just the two the issue named:
`actions/checkout` v4 → v7 (six sites), `actions/cache` v4 → v6 (four sites), and
`actions/github-script` v7 → v9 (one site). `maxim-lobanov/setup-xcode@v1` is unchanged — the moving
`v1` tag already resolves to a `node24` build — as are `gate-scripts`' own `actions/checkout@v7` and
`actions/setup-python@v7`.

**Bumping `actions/checkout` alone would not have cleared the warning.** The annotation on the base
commit names two actions, not one — "the following actions target Node.js 20 ... `actions/cache@v4,
actions/checkout@v4`" — because it is emitted once per job listing every Node 20 action in that job.
Changing only the action the issue names would have left `actions/cache@v4` behind and the warning
still standing, while the diff looked like a fix.

**The target for each was read out of that action's `action.yml` at the pinned ref, not inferred from
the version number**, and one action does not follow the pattern: `actions/github-script@v7` is
`using: node20`, and node24 only arrives at v8. A sweep that made every pin say `v7` would have
produced a repo that looked consistent and left `require-issue-labels.yml` deprecated — the same
shape of defect as the mixed-version file it was fixing.

No bump changed an interface: `action.yml` at the new ref is byte-identical to the old one apart from
the `using:` line in all three cases, so `fetch-depth`, `submodules`, `persist-credentials` and
`cache-hit` keep their declared defaults. The two real behaviour changes are inert
here — checkout v6 persists credentials to a separate file rather than `.git/config` (no workflow
reads them or pushes), and checkout v7 blocks checking out a fork PR head under `pull_request_target`
or `workflow_run` (neither trigger is used; the two `pull_request` workflows are unaffected).

#### Four gate scripts documented as gating on exit status, run by nothing (#625)

`check-bridge-index.py`, `check-null-handle-guards.py`, `check-docs-defaults.py` and
`count-operations.py` were each written to gate a commit, and three said so in their own docstring.
No workflow, hook, script or Makefile invoked any of them. `CLAUDE.md` told contributors the guard
script "exits 1 on any unguarded site" — true, and it still merged green when it didn't, because
nothing ran it. The documentation described a gate that existed only as prose.

All four now run in a new `gate-scripts` job in `.github/workflows/ci.yml`, together with the three
`--self-test` batteries, on `ubuntu-latest`, in about three seconds of work.

**A separate job rather than a step in `build-and-test`, for a reason beyond speed.** The obvious
argument is that a pure-Python check should not wait ~6 minutes behind a Swift build to say a
symbol name is misspelled. The load-bearing one is the status check: `build-and-test` is red
branch-wide on any `refactor/**` branch carrying a kernel patch newer than `Package.swift`'s pinned
xcframework (#585), so a gate folded into that job would be red for a reason that has nothing to do
with it — indistinguishable from having no gate at all. Linux rather than macOS because none of the
four needs Xcode, OCCT or a build, and a macOS runner bills ten times the minutes for the identical
result. Python is pinned at 3.12 rather than taken from the image: these gates parse Swift and C++
with regexes, and a runner-image Python bump quietly changing a verdict is the exact failure mode
they exist to prevent.

**Each script's `--self-test` runs alongside its real invocation.** A detector that reports "all
clear" because it is blind looks exactly like one reporting "all clear" because the tree is clean,
and this branch shipped three gate scripts that were confidently wrong — #618 (the guard checker
saw one of the five ways this bridge reaches a handle), #624/#630 (the index checker called seven
correct entries misfiled), #626 (the drift it was written to catch was live in the tree). Two of
those had self-tests with holes. Running the fixtures in CI is what keeps the gate from rotting
into vacuity while still exiting 0.

Every step after the first carries `if: '!cancelled()'`, so one failing gate does not hide the
other three; without it a contributor fixes them one CI round trip at a time. `!cancelled()` rather
than `always()` so the workflow's `cancel-in-progress` concurrency still takes effect.

**`count-operations.py` gains the docstring line its three siblings already had.** It was always a
gate — `return 0 if (readme_n == derived and apiref_n == derived) else 1` — but nothing said so, so
it read as a release-time reporting tool, which is the only way it was ever used. Its counts had
drifted on this branch before (#625's own scope note).

It also **now exits 2 on an unrecognised option instead of silently ignoring it**. This one is a
trap this PR itself arms: the other three gates all take `--self-test`, and CI pairs each self-test
with its real run, so "seven invocations, self-test beside gate" becomes the house pattern in two
places — and the natural thing to write when extending that list is `count-operations.py
--self-test`, which was accepted, ran the ordinary report, and passed forever. The first fix was a
docstring warning, which is the wrong shape of fix for an issue whose entire premise is that prose
describing a gate is not a gate. Exit 2 matches the siblings' "cannot run" status (they use it for
a wrong working directory) so it is distinguishable from a real failure, and it also stops `--fi`
silently reporting when `--fix` was meant.

**An opt-in pre-commit hook, not an installed one.** `Scripts/git-hooks/pre-commit` runs the same
seven invocations locally, for the case `CLAUDE.md` actually addresses: a contributor mid-change,
not a reviewer. It is enabled deliberately with a symlink into `.git/hooks` (or `core.hooksPath`,
which replaces the hooks directory wholesale rather than adding to it — documented, because that
silently disables any hook a contributor already has). **The rejected alternative was
auto-installation** — a bootstrap script or SwiftPM plugin writing `.git/hooks/pre-commit` on first
build. It was rejected because it changes when a contributor's commits succeed without them asking,
and its failure mode is a commit refused by a hook they did not know existed and cannot find in the
tree. The hook runs the same seven invocations **flag for flag**. It first ran the three real gates with
`--quiet`, which is exit-status-only, so it named the failing gate and then printed nothing about
where — a fabricated index entry got you `FAIL: check-bridge-index.py` where CI names
`OCCTBridge.h:66`. The flag was redundant anyway, since the runner already buffers output and only
prints it on failure. **The reason that survived the first round of proof is worth recording**: the
hook was proven with `count-operations.py`, the one invocation that had no `--quiet` and therefore
the one case that could not exhibit the defect. A proof that exercises only the case immune to the
bug is the same shape as the vacuous self-tests this batch keeps finding — the re-proof breaks all
three of the previously-`--quiet` gates individually and confirms each now prints its site.

Three ways the hook can still diverge from CI, all documented in it rather than closed: it checks
the working tree rather than the staged snapshot, so a partially-staged commit can pass it and fail
CI; it runs whatever `python3` is on `PATH` while CI pins 3.12; and it warns and exits 0 if
`python3` is missing, so "the hook passed" can mean "the hook did nothing". All three resolve the
same way — CI decides, and it runs on every push regardless.

The install instruction was also wrong for this repo's normal working mode: `ln -s ...
.git/hooks/pre-commit` fails with "Not a directory" in a linked worktree, because a worktree's
`.git` is a file, and almost all work here happens in `.claude/worktrees/*`. The hook *body* was
already worktree-correct (`cd "$(git rev-parse --show-toplevel)"`); only the instruction was not.
Both the hook header and `CLAUDE.md` now give the worktree forms.

**Verified by breaking each condition and confirming the gate catches it.** Fabricating an index
entry (`OCCTShapeBoxNope`) took `check-bridge-index.py` 0 → 1; deleting the `IsNull()` from a
guarded bridge opener took `check-null-handle-guards.py` 0 → 1; editing a restated default in
`docs/reference/` took `check-docs-defaults.py` 0 → 1; editing README's headline count took
`count-operations.py` 0 → 1. All four returned to 0 on restore. The job is pinned to
`actions/checkout@v7` + `actions/setup-python@v7` (both `using: node24`) rather than the `@v4` its
sibling jobs use, so it does not newly introduce a Node 20 deprecation annotation — those are
emitted per job, so this job's pins decide this job's warning. Bumping the other two jobs is #648.

**What this does not do:** the repo has no branch protection and no rulesets, so a red
`gate-scripts` is a visible red X that does not block a merge. Making it a required check is #649,
and it is the one check in the repo that can be required without a caveat — unlike `build-and-test`
it needs no OCCT, no build and no xcframework, so #585's pinned-kernel mismatch cannot make it red.

#### Seven entry points indexed sub-shapes by occurrence while their consumers used the deduplicated map (#613)

#541 put sub-shape indexing on one enumeration, `TopExp::MapShapes` — one entry per *distinct*
sub-shape, `TopoDS_Shape::IsSame`, orientation ignored. Seven entry points stayed on a bare
`TopExp_Explorer`, which yields one entry per *occurrence*. A plain 10 mm box has **24 edge
occurrences over 12 edges** and **48 vertex occurrences over 8 vertices**, because every edge is
reached once per adjacent face — so the two enumerations disagree on any ordinary solid, not only
on an exotic one.

**The end-to-end failure is the composition this branch's own documentation recommends.**
`Shape.filleted(edges:radius:)` carries the snippet
`bracket.filleted(edges: bracket.concaveEdges(), radius: 3)`. `edgeConcavities()` sizes its buffer
from `edgeCount` and zips the bridge's answer against `edges()`, but the bridge filled it per
occurrence, so every label past the first repeat landed on the wrong edge. Measured on an L-bracket
(two fused boxes, inner corner at x = 10, z = 10, map edge **27**):

| | before | after |
|---|---|---|
| `bracket.concaveEdges()` | **`[]`** | `[27]` |
| `edgeConcavityCount(.concave)` | 2 (occurrences of that one edge) | 1 |
| `box.edgeConcavityCount(.convex)` on a 12-edge box | **24** | 12 |

So the recommended one-liner filleted an empty list. Measured on base, `filleted(edges: [], radius: 2)`
returns **`nil`** — it reported *failure*, not success. The harm is not a silent wrong answer but a
misattributed one: a `nil` from a fillet reads as "the fillet failed", and nothing pointed at the
edge *selection* as the cause. On the fix it returns a shape, 28034.3 mm³ against the bracket's
28000.0.

**The six named sites, plus one the issue and its audit both missed:**

| Site | Was | Measured divergence |
|---|---|---|
| `OCCTShapeAnalyzeEdgeConcavity` + `OCCTShapeCountEdgeConcavity` | result-array order, and the count | the table above |
| `OCCTBRepExtremaExtCC` | the `edgeIndex` argument | matches `edges()` to index 8, names a different edge from 9; answered for 12…23 |
| `checkSubShape` (behind `checkEdge`/`Wire`/`Shell`/`Vertex(at:)`) | the sub-shape index | `checkEdge(at: 12)` reported a valid edge although `edge(at: 12)` is `nil`; `checkVertex` answered to index 47 on an 8-vertex box |
| `OCCTLocOpeSplitShapeByVertex` | the edge-splitting index | index 9 split `edges()[4]`, index 11 split `edges()[0]`; 12 and 13 split successfully |
| `OCCTShapeCreateMesh` / `…WithParams` | triangle `faceIndex` | 12 indices emitted on an 11-face compound |
| `edgesInFace(at:)` — and its unlisted sibling `commonEdges(with:)` | the `Edge.index` handed back | result-array positions: `edgesInFace(at: 3)` returned 0, 1, 2, 3 for edges at 2, 6, 10, 11 — all four wrong, by 10.00, 12.25, 7.07 and 12.25 mm |
| **`OCCTBiTgteBlend` / `OCCTBiTgteBlendInfo_`** — named by neither the issue nor its audit | a `std::vector` filled from an explorer, subscripted by the caller's indices | **no index blended the bracket's concave edge at all**; and an unresolvable index was silently dropped rather than refusing the batch (#568) |

**Meshing is the one site where the two enumerations pull opposite ways, and it uses both.**
Triangle winding is set by the face's orientation *as it occurs in the parent*
(`if REVERSED swap(n2, n3)`), so converting it to the map would have kept only the orientation a
shared face was first seen with — #614's defect one level down. Measured on a `BRepAlgoAPI_Splitter`
cut of a 20×10×10 block at x = 10: 12 face occurrences over 11 distinct faces, exactly one face
present in both orientations, and the map stores it `FORWARD`. Meshed off the map the shared wall
emits 2 triangles wound `+x` and **0** wound `−x` — the upper solid's floor simply absent. The new
`occtForEachOrientedFace` hands out both from one traversal: the occurrence for its winding, and
that occurrence's index in the enumeration `faces()` reads. `FindIndex` is the `IsSame` lookup, so a
`REVERSED` occurrence resolves to its `FORWARD` twin's index and both sides of a shared wall carry
the one index that names it.

**`OCCTPolyMergeNodes` is deliberately NOT converted**, and is now documented and pinned as such.
It emits no index, and the `reversed` flag it derives per occurrence goes straight to
`Poly_MergeNodesTool::AddTriangulation`. Deduplicating it would add a shared wall once and lose the
other solid's side (measured: `+x` 2, `−x` 0). A regression test fails if a later sweep converts it.

**The audit's own verdicts were re-derived rather than taken on trust**, and one was overturned:
site 6 was recorded as "already on the map bridge-side", which is true of the `faceIndex` *argument*
and not of the `Edge.index` on the way out — the issue's actual complaint, and a live defect.
Sites 1-4 were confirmed safe to read off the map by measurement rather than by reading headers:
every consumer was handed both orientations of every box edge (12 pairs) and vertex (8 pairs) and
gave an identical answer, **0 differing** — `BRepOffset_Analyse::Type`'s interval list,
`BRepExtrema_ExtCC`'s `IsParallel`/`NbExt`/`SquareDistance`/`ParameterOnE1`/`PointOnE1`, the full
`BRepCheck_*` status list, and `BRep_Tool::Range` + `LocOpe_SplitShape::DescendantShapes`. That
matches what the headers predict (`BRepOffset_Analyse.hxx:173`, `LocOpe_SplitShape.hxx:89-90`,
`BiTgte_Blend.hxx:202` are all `TopTools_ShapeMapHasher`-keyed, and that hasher's equality operator
*is* `IsSame`, `TopTools_ShapeMapHasher.hxx:35-38`) — but the headers are the reason to check, not
the check.

The `BRepCheck` WIRE and SHELL spellings go through the same converted helper, and a plain box has
no wire or shell occurring twice, so the first pass could not exercise them. Six further fixtures
were built for exactly that — `compound{solid, solid.Reversed()}`, and the same for a shell, a face,
a wire, an open (invalid, non-closed) wire, and a fused two-body solid — giving **26 WIRE pairs and
4 SHELL pairs, `BRepCheck` identical across orientation in every one, 0 differing**, invalid
geometry included. Their index *domain* does move, which is the point of the conversion and is
recorded in [`SEMVER.md`](SEMVER.md): on `compound{solid, solid.Reversed()}` the WIRE enumeration
goes 12 occurrences → 6 distinct.

**This was not a complete sweep of the per-occurrence idiom at the time.** `Shape.nbEdges` /
`nbVertices` / `nbFaces` returned per-occurrence counts (a box answered **24** and **48** against
`edgeCount` 12 and `vertexCount` 8; a split compound's `nbFaces` was **12** against `faceCount` 11)
while their own published docs asserted the deduplicated answers, filed separately as **#651** and
resolved below, by deprecation rather than by repointing in place, since all three are pure
duplicates of `edgeCount`/`faceCount`/`vertexCount` with no index or orientation dimension of their
own. `OCCTShapeFixEdgeSameParameter` and `OCCTShapeFixEdgeVertexTolerance` also document "number of
edges fixed" while counting explorer occurrences; that one is source-visible but **unmeasured** (a
box returns 0 either way), so it is recorded here as a candidate rather than converted on a pattern
match.

Bridge-only plus two Swift wrappers; no kernel patch and no `OCCT.xcframework` rebuild.
`OCCTLocOpeFindEdges` and `OCCTLocOpeFindEdgesInFace` gained an optional `outIndices` parameter.
Index-value changes are recorded in [`SEMVER.md`](SEMVER.md). Tests:
`Tests/OCCTTopologyTests/Issue613IndexContractTests.swift` and
`Tests/OCCTMeshTests/Issue613MeshIndexContractTests.swift`, 25 tests, each proven to catch its own
site by reverting that site alone.

#### `nbEdges`/`nbFaces`/`nbVertices` are deprecated in favour of the counters they duplicated (#651)

`Shape.nbEdges`, `Shape.nbFaces` and `Shape.nbVertices` counted bare `TopExp_Explorer` occurrences
(`OCCTShapeNbEdges`/`NbFaces`/`NbVertices`, `OCCTBridge_Topology.mm`), the same gap #613 closed for
its seven entry points, while this project's own reference docs always documented the deduplicated
answer: `docs/reference/Document-Completions.md` asserted `box.nbEdges // 12` and
`box.nbVertices // 8`, not the 24 and 48 the implementation actually returned. Measured on a plain
10 mm box:

| | `nbEdges` | `edgeCount` | `nbVertices` | `vertexCount` | `nbFaces` | `faceCount` |
|---|---|---|---|---|---|---|
| box | **24** | 12 | **48** | 8 | 6 | 6 |

`nbFaces` agreed with `faceCount` on the box (no face is shared within one solid), and diverged only
on a shape with a shared face: 12 against 11 on a two-solid split compound, reproducing #613's own
`faceIndex` measurement.

**Confirmed by the Cluster A census (#664, `Scripts/repro/cluster-a-subshape-enumeration/`),** run
specifically to settle this question before any of #638/#642/#651 started: all three are pure
occurrence duplicates of `edgeCount`/`faceCount`/`vertexCount` in every fixture measured, with no
index, no orientation dimension, and no consumer that reads one and not the other. That is a
different shape from #613's seven sites, which addressed an *index* fed into another entry point and
had no existing correctly-valued sibling to fall back on.

**Decision: retire the duplicate spelling, not repoint it in place.** Following the precedent #536
set for `removeFeatures(faces:)`/`defeature(faces:)` (two public names driving one operation, the
newer forwarded and deprecated) rather than #541/#568/#613's own precedent (repoint the raw value,
because those sites had no existing sibling to rename to). Repointing `nbEdges`/`nbFaces`/`nbVertices`
in place and keeping both names was considered and rejected: once the value agrees there is nothing
left to distinguish the two spellings, which recreates the exact duplication #490/#491/#492 and #536
diagnosed elsewhere in this codebase.

All three are now `@available(*, deprecated, renamed:)`, forwarding to `edgeCount`/`faceCount`/
`vertexCount` respectively, so the value is correct on the way out even though the spelling is
retired. The now-orphaned bridge functions `OCCTShapeNbEdges`/`OCCTShapeNbFaces`/`OCCTShapeNbVertices`
are deleted, following #506's precedent for an orphan with no remaining Swift call site (`OCCTBridge`
is a target, not a product, so nothing depends on the C symbol surviving). Recorded as a SemVer
exception in [`SEMVER.md`](SEMVER.md), since the returned value changes even though the build does
not break.

Tests: `Tests/OCCTTopologyTests/Issue651DeprecatedCounterTests.swift`, pinning the corrected value
against `edgeCount`/`faceCount`/`vertexCount` on a box and on a shape with a shared face, each proven
to catch its own regression by reverting that one counter back to an occurrence walk.

`docs/reference/Document-Completions.md`, `Edge.md`, `Selection.md` and `Shape-Features.md` updated
to match; `docs/reference/Document-Completions.md` was the page whose own asserted contract this
issue was filed against.

#### The null-handle gate was blind to four of the five ways this bridge reaches a handle (#618)

`Scripts/check-null-handle-guards.py` printed "All bridge functions guard the geometry handle as
well as the wrapper pointer" and exited 0. Its use-detector matched `param->field` and nothing
else, so every site that reaches the handle through an indirection was invisible to it, and this
bridge uses four: a cast (`reinterpret_cast<OCCTSurface*>(ref)->surface`, `static_cast`,
`(OCCTSurface*)ref`), a pointer alias (`auto* s = (OCCTSurface*)surface; ... s->surface`), a
handle alias (`auto& surf = ...->surface;`, and the by-value `Handle(Geom_Surface) w = ...->surface;`
copy), and a shared bridge helper. Casts are now normalised away before the walk, aliases are
followed, and the detector scores 6/6 on fixtures the old one scored 1/6 on.

The fourth form cuts the other way, and is why the fix is not just "teach it the cast spelling"
(#624/#630's lesson, one issue earlier: a sibling gate that had been taught indirection badly was
confidently wrong about seven correct entries). `OCCTGeomConvertCurveToAnalytical` and
`occtSurfToAnaSurfResult` hand their handle to `occtCurveToAnalytical` / `occtSurfaceToAnalytical`,
both of which open with `if (curve.IsNull()) return false;`: checked, just one call frame away. A
detector taught forms 1-3 and not form 4 reports both as defects. It now recognises a bridge helper
that `IsNull()`-checks the parameter it is handed as a guard in its own right.

**54 candidate `(function, argument)` pairs across 39 functions (the old detector found 1), of
which 21 needed a guard and 33 were cleared by measurement.** The issue's own list of
seven suspected-unguarded sites was partly wrong, and measuring first is what caught it:
`OCCTGeomLibToolParameter3D` and `OCCTGeomLibToolParameter2D` reach `GeomLib_Tool::Parameter`,
which returns `false` on a null handle, and `OCCTApproxSameParameter` reaches
`Approx_SameParameter`, which raises a catchable `Standard_Failure` the function's own `catch (...)`
already turns into the same `false` a guard would return. Three of the seven needed nothing. The
other four did, along with eleven sites the issue never named.

Guards added to 16 functions (21 `(function, argument)` pairs): `OCCTLocalAnalysisCurveContinuity`
`{,Flags}`, `OCCTLocalAnalysisSurfaceContinuity{,Flags}`, `OCCTSplitCurve3dContinuity`,
`OCCTSplitCurve2dContinuity`, `OCCTConvertCurve2dToBezier`, `OCCTSplitSurface{Continuity,Angle,Area}`,
`OCCTGeomTools{Curve,Curve2d,Surface}SetWrite`, `OCCTProjLibProjectOnSurface`,
`OCCTGeomFillNSections{,Info}`. Each returns the fallback its surrounding `catch (...)` already
returns. The remaining 33 pairs (23 functions) are recorded in the script's `ALLOWED` table, each
with the measured reason it does not need one; four of those are not OCCT calls at all
(`OCCTBRepGraphRepSet*` store
into a bridge-owned side registry whose *else* branch deliberately stores a null handle to clear
the slot, and `BRepGraph_EditorView::SetPCurve` documents the null handle as its clear-the-binding
contract).

`OCCTGeomToolsCurveSetWrite` is the one guard here that measurement did *not* demand:
`GeomTools_CurveSet::Add` guards its own handle, so a null cannot crash it. It is guarded anyway
because the alternative was worse than noise. `Add` silently drops the null, `Write()` then emits a
set with fewer curves than the caller passed, and `Curve3D.serializeCurves`/`deserializeCurves` is a
round trip, so the surviving indices stop matching the input array. Guarding it also keeps the three
identical `GeomTools_*SetWrite` writers from diverging three ways on null handling, which is the
divergence shape this audit exists to remove.

`Scripts/repro/556-null-handle-guard-sweep` grew from 35 entry points to 57: the 22 the pre-#618
walk never reached, so nobody had measured them. 36 of 57 are now uncatchable signals (was 24 of
35). Along the way: `GeomTools_CurveSet::Add` guards with `return (C.IsNull()) ? 0 : myMap.Add(C)`
while `GeomTools_Curve2dSet` and `GeomTools_SurfaceSet` contain no `IsNull` anywhere and both
crash. An upstream inconsistency between three copies of the same writer.

The script also gains `--self-test`, matching `check-bridge-index.py`. It proves both failure
modes by injection: six fixtures that must be reported (one per indirection form, including the
plain `param->field` form, so the fix is provably additive) and six that must not (including a
guard reached only through a by-value `Handle` copy, and one only through the shared helper).
No public API change; behaviour changes only for inputs no bridge call can currently produce.

#### Breaking: `continuityOrder` is retired, because a warning did not stop the numbers changing underneath it (#619)

**Source-breaking.** `Curve3D.continuityOrder`, `Curve2D.continuityOrder` and
`Surface.surfaceContinuityOrder` are now `@available(*, unavailable)`. Any use is a compile error
carrying the migration in the diagnostic.

Nothing about the *values* changes here. They already changed, in #485:

| class | before #485 | now |
|---|---|---|
| C0 | 0 | 0 |
| G1 | −2 | 1 |
| C1 | 1 | 2 |
| G2 | −3 | 3 |
| C2 | 2 | 4 |
| C3 | 3 | 5 |
| CN | 99 | 6 |

The old scheme was OCCTSwift's own invention. It matched neither `GeomAbs_Shape` nor its own doc
comment, and disagreed with the `continuity` property on the same curve for every class except C0.
Reporting the real ordinal is right and is not reverted.

What #485 could not do with a deprecation attribute is stop the change being silent. The type stayed
`Int` and the name stayed the same, so every call site kept compiling:

```swift
// Before: `2` was C2, so this rejected a C1 curve.
// After:  `2` is C1, so a merely tangent-continuous curve reaches a path assuming curvature.
if curve.continuityOrder >= 2 { useAsC2Spline() }

// And this, the analytic fast path, became unreachable rather than wrong — silently dead code.
if curve.continuityOrder == 99 { useAnalyticFastPath() }
```

A warning does not stop compilation, and neither outcome above is one a warning prevents: the first
is a wrong geometric answer produced silently by a build that succeeded, the second is a branch that
quietly stopped being taken. Retiring the spelling turns both lines into errors that name the old
encoding, the new one, and the replacement.

**There is no error sentinel any more, and that is its own migration hazard.** The retired encoding
signalled failure out of band, returning `-1` from its `default:` branch and for a null or
unreadable handle. `continuity` returns `0` in the same situations, and `0` is an ordinary C0
measurement. So `if continuityOrder < 0 { handleError() }` migrates to a branch that can never be
taken, and an unreadable curve now reads as a genuinely C0 one. There is no in-band way to tell them
apart — check the handle before asking.

Migration — both replacements predate this change and neither is new API:

```swift
// A continuity floor. Takes the request vocabulary by type, so the mismatched
// constant cannot be written at all.
if curve.continuityClass.satisfies(.c2) { useAsC2Spline() }

// The analytic fast path.
if curve.continuityClass == .cN { useAnalyticFastPath() }

// A raw ordinal, if that is genuinely what you want — but it is the *new*
// ordinal, so re-check the constant you compare against.
let ordinal = curve.continuity
```

`continuity` is unchanged in value: it read the real ordinal before the refactor and still does.
Only its doc comment was wrong, which is what let the two spellings disagree unnoticed.

- **`unavailable` rather than deletion.** The declaration stays so the compiler can explain itself;
  deleting it outright would say only "has no member `continuityOrder`". Follows
  `EvolvingFilletEdge.init(edgeIndex:)` (#520), the same response to the same shape of hazard. The
  operation count drops by 3 (4,301 → 4,299) — `Scripts/count-operations.py` does not count a
  retired spelling as a wrapped operation, and no new API was added.
- **Tests:** `Issue619ContinuityEncodingTests` (`OCCTCurveTests`),
  `Issue619Curve2DContinuityEncodingTests` (`OCCTGeom2dTests`) and
  `Issue619SurfaceContinuityEncodingTests` (`OCCTSurfaceTests`) pin the encoding against geometry
  whose class is known by construction, and assert the trap is live: a C1 BSpline satisfies
  `continuity >= 2` while `continuityClass.satisfies(.c2)` correctly refuses it. The #485 suites had
  their `continuityOrder` assertions moved onto `continuity`/`continuityClass`.
- Recorded as a break in [`SEMVER.md`](SEMVER.md).

#### The index gate was reporting seven correct entries, because it could not read a template helper (#624)

`Scripts/check-bridge-index.py` exited 1 with `0 stale, 7 misfiled`, every one of them on the
`GCPnts_AbscissaPoint` line of `OCCTBridge.h`'s cross-reference index, and every one reported as
`no bridge function reaches this class`. The reading that fits — #477, #549, #600 and #603 did
progressively move arc-length measurement off `GCPnts_AbscissaPoint` — is that the entries had
drifted and needed re-filing. They had not.

Adjudicated per symbol, by reading each body and following the call path rather than the name:

| symbol | call path | reaches |
|---|---|---|
| `OCCTCurve3DGetLength*` | `occtAdaptorArcLength` / `occtAdaptorLengthBetween` → `occtArcConvergedLength` → `occtArcQuadrature` | `GCPnts_AbscissaPoint::Length` |
| `OCCTCurve3DParameterAtLength` | `occtAdaptorParameterAtLength` → `occtArcWalkToLength` | `GCPnts_AbscissaPoint` (constructed) |
| `OCCTCurve2DGetLength*` | same helpers, `Geom2dAdaptor_Curve` | `GCPnts_AbscissaPoint::Length` |
| `OCCTCurve2DParameterAtLength` | `occtAdaptorParameterAtLength` | `GCPnts_AbscissaPoint` (constructed) |
| `OCCTEdgeArcLength*` | same helpers, `BRepAdaptor_Curve` | `GCPnts_AbscissaPoint::Length` |
| `OCCTEdgeParameterAt*` | `occtAdaptorParameterAtLength` | `GCPnts_AbscissaPoint` (constructed) |
| `OCCTWireGetLength` | same helpers, `BRepAdaptor_CompCurve` | `GCPnts_AbscissaPoint::Length` |

All seven still reach the class. `occtArcQuadrature` (`OCCTBridge_Internal.h`) is
`singleSpan ? GCPnts_AbscissaPoint::Length(...) : CPnts_AbscissaPoint::Length(...)`, so #603 added
a second class to these functions rather than replacing the first — which is what the index already
said, on the `CPnts_AbscissaPoint` line directly beneath.

The defect was the checker's. It classifies each brace-balanced definition by searching its
signature for `struct|class|union|namespace|enum`, and a `template <class TheAdaptor>` head
satisfies that, so the helper was filed as a *type* named `TheAdaptor` instead of as a function. A
type is only ever reached by a function that names it, and none do, so the helper-indirection chain
was cut at its first template link and the class looked unreached. The tell was that
`OCCTBridge_Modeling.mm`'s one `template <typename BoolOpT>` helper parsed correctly: `typename` is
not in that alternation, `class` is. `without_template_head` now strips the head before
classification; a `template <class T> struct Foo` is still read as a type.

The nine arc-length helpers are what the misfiled entries pointed at, but they are not the whole of
it. Every `template <class ...>` definition in the bridge was affected — **15** of them, filed under
**6** bogus type names:

| bogus type | count | helpers |
|---|---|---|
| `TheAdaptor` | 9 | `occtArcQuadrature`, `occtArcConvergedLength`, `occtArcIntervals`, `occtAdaptorArcLength`, `occtArcWalkToLength`, `occtAdaptorParameterAtLength`, `occtConfineToDomain`, `occtAdaptorWindsPeriodically`, `occtAdaptorLengthBetween` |
| `AddEdge` | 2 | `occtFilletAddEdges`, `occtShapeFilletEdgeList` |
| `T` | 1 | `occtWriteKnotSplits` |
| `SplitIndexAt` | 1 | `occtWriteKnotSplitParams` |
| `Use` | 1 | `occtUseSubShapesByIndex` |
| `PointAt` | 1 | `occtFilletSetRadiusProfile` |

Across the whole bridge, 34 `OCCT`-prefixed functions' reach sets change: 31 grow, and **3 shrink**.
The shrinking direction is the one that is easy to miss — the old parser was also false-*widening*.
`types['T']` was a real bucket holding everything `occtWriteKnotSplits` reaches, and the
wrapper-type resolution step hands a function the contents of any type it names, so
`OCCTGeomFillGuideTrihedronACD0`, `OCCTGeomFillGuideTrihedronPlanD0` and `OCCTWireGetCurvePointAt`
each inherited that bucket purely for containing a local identifier `T`. Fifteen junk names apiece.
No index verdict depended on any of this — the run went `0 stale, 7 misfiled` to `0 stale,
0 misfiled` and nothing else moved — but a direction check is only as good as its reach sets, so the
record should say what actually moved rather than only the part that was being complained about.

No bridge or Swift source changed — the index entry was right, and the note added to it records
that the seven reach the class through the helpers rather than by naming it, so the next reader
greps the right thing.

Two holes in the script's own `--self-test`, both of which had to be closed for #625 to gate on it:

- `DIRECTION_TEST` did prove the misfiled mode was caught, but all four of its cases named a single
  symbol, so the entry-level rule `misfiled_entries` explicitly warns against — "at least one of
  these reaches the class", which lets one wrong symbol hide behind correct neighbours — passed the
  whole suite 16/16 when injected. A fifth case mixes a correct symbol with a wrong one and pins
  which symbol must be blamed.
- `INDIRECTION_TEST` covered the plain `inline` helper but not the template one, so nothing failed
  when the parse above broke. A case for it now asserts the `GCPnts_AbscissaPoint` line stays clean.

Both were verified by injecting the regression they describe and confirming 17/18. The suite is
18/18 and the gate exits 0.

#### A single iso-row stops being documented, accepted, and then silently refused (#620)

Three layers disagreed about the minimum count `Surface.drawMesh(uCount:vCount:)` accepts. The doc
comment said "at least 1", the Swift guard (`Sampling.gridTotal`, default `atLeast: 1`) accepted 1,
and the bridge returned 0 for anything under 2. The wrapper's `guard n == total` turned that 0 into
`SurfaceGrid.empty`, so `drawMesh(uCount: 1, vCount: 20)` — in range by its own documentation —
came back empty, and the caller had no way to tell "you asked for something unsupported" from "this
surface has no mesh".

**The bridge was the layer that was wrong**, which is not what the issue expected ("a mesh of one
row has no quads"). Measured against the kernel first: despite the name `OCCTSurfaceDrawMesh` does
not mesh anything. There is no `BRepMesh`, no triangulation and no quad, just a uniform walk of the
sampled range calling `Geom_Surface::D0`, and a single `(u, v)` is a valid OCCT evaluation — a
1 × 20 iso-row off a sphere is 20 finite points. The 2 was never OCCT's rule, it was this
function's own divisor: `i / (uCount - 1)` divides by zero at count 1. And the NaN that produces is
worse than a throw would have been, because `D0` does not throw on NaN, it returns NaN coordinates
silently. Every other member of the same U-major grid family already accepted 1 —
`OCCTSurfaceDrawGrid` guards no count at all, `EvaluateGrid` and `EvaluateGridD1` guard `<= 0` — so
`drawMesh` was the family's sole outlier. `OCCTSurfaceDrawGrid`, forty lines above in the same
file, samples the same bounds and had spelled that divisor defensively since `b1cd75d`, the commit
that introduced both functions. The bound moved to 1 rather than disappearing: below 1, and
products past `Sampling.maximumSampleCount`, are still rejected at the Swift boundary before any
allocation, which is #558's contract unchanged.

That divisor is now `occtUniformParameter` in `OCCTBridge_Internal.h`, next to
`occtSurfaceGridIndex` and for the same reason: it had been open-coded **ten** times in
`OCCTBridge_Surface.mm` in four different spellings, and #620 is what a single copy written
without the guard costs. Sharing the expression is what stops an eleventh loop re-deriving the
unguarded form.

Nine of the ten are bit-identical substitutions. **The tenth reassociates**: the Gordon network
builder's `f + (l - f) * ((double)j / (guideCount - 1))` becomes `((l - f) * j) / (guideCount - 1)`,
and across ten realistic `[FirstParameter, LastParameter]` ranges 25-33% of cases differ by 1-2 ulp
(≤ 4e-15 over the whole span, exactly 0 on this repo's own Gordon fixture). One structural
consequence beyond the magnitude: the old form always landed the last sample exactly on
`f + (l - f)`, while the new one can land 1 ulp **past** `LastParameter` (4 cases of n = 2…60 on a
0..2π profile). Harmless here, because the builder `SetNotPeriodic()`s the curves first so
`Geom_BSplineCurve::D0` does not throw just outside the range, but it is a boundary the old
expression structurally could not cross, so it is recorded at the site rather than left for
someone to rediscover.

Three open-coded lines remain, across two sites, both deliberately.
`OCCTGeomFillAppSurf`'s `(double)i / (count - 1)` is
**unguarded** — the exact #620 shape — but chasing it turned up a separate, larger defect
(`Surface.appSurf(curves:)` segfaults on a single curve regardless of the parameter value, so it
is a missing arity guard rather than a divisor bug), which is filed on its own; converting the
divisor would not fix it and would muddy that fix. `OCCTGeomFillCoonsPatchEval`'s two lines are a
different contract, not the same expression: their single-sample branch is `0.5`, the patch
midpoint, where every other site's is the low end. The helper's own doc says so, so the next
sweep does not fold them in on shape alone.

**Recorded, not fixed: the Gordon family has no behavioural test coverage at all.** All five
Gordon tests assert only nil-ness and status ordinals — not one checks a point, pole, degree or
bound — and `networkSurfaceBuildsOrReportsStatus`, the only test reaching the changed line, accepts
any status but `.notStarted`; on the repo's own `makeNetwork()` fixture the builder returns
`KnotAlignmentFailed`, so it never builds a surface. Nothing in the repo would have caught the 1-ulp
change above, or one many orders of magnitude larger. Filed separately.

**A second wrong claim, caught reviewing the first fix.** The new contract sentence said
`uCount: 1` is "the single iso-row at `uMin`". That holds only for a bounded surface: the bridge
clamps infinite bounds to ±100 **before** deriving parameters, so on a plane `domain.uMin` is about
-2e100 while the single row sits at -100. Same defect class as #620 itself — a claim true of the
fixture in front of you and false in general — so the docs now name the **sampled range** (the
domain, with infinite bounds clamped) rather than the domain, and a test pins the clamped value on
an unbounded surface. The first version of that test checked only finiteness, which passes under
either reading and so could not contradict the doc.

**The sibling site keeps its 2.** `OCCTSurfaceCreateBezier` carries a visually identical
`uCount < 2 || vCount < 2`, and that one is the kernel's: a Bezier's degree is its pole count minus
1 and must be at least 1, so `Geom_BezierSurface` raises `Standard_ConstructionError` on a
single-pole direction (measured; 2 × 2 builds a bilinear patch). `Surface.bezier(poles:weights:)`
already guarded the same bound, so that site had no three-layer mismatch at all — only a doc that
was silent about the bound rather than wrong about it. Both look-alike guards now say in a comment
which kind they are, so the two are not "made consistent" by a later sweep. The accompanying test
pins the *public* contract only, and says so: relaxing the bridge guard alone leaves it passing,
because `Surface.bezier` rejects in Swift and never reaches the bridge — and if it did, OCCT would
throw and `catch (...)` would return `nullptr`, so `nil` comes back either way. No black-box test
can separate those two layers, and claiming otherwise would be the same kind of overstatement this
entry is about.

#### The reference page that kept documenting the continuity default #491 replaced (#626)

Two pages under `docs/reference/` restate `Surface.approxWithDetails`. #491 flipped both of its
continuity defaults from C1 to C2 — so that it and `Surface.approximated` stop fitting to different
smoothness when neither is given a continuity argument — and updated `Surface.md`.
`Shape-HLR-Geom.md` went on declaring `uContinuity: ParametricContinuity = .c1, vContinuity: .c1`.

That page **is** in this branch's changed set: its `quasiUniformParameters` entry was rewritten
thirty lines below the stale default. A reader following it and omitting the arguments expects a C1
fit and gets a C2 one, which per #572 is not cosmetic — continuity is one of the inputs deciding how
far the fitted surface moves. It also reinstated, in the documentation layer, the exact divergence
#491 existed to remove.

The interesting part is not the one-line correction. A per-type reference page that restates a
signature is a **copy**, and this tree holds 3427 such restatements.
`Scripts/check-docs-defaults.py` parses every one of them, matches it to its declaration in
`Sources/OCCTSwift`, and compares them position by position: **1460 defaults compared, 2 drifted**,
both of them this one.

A default drifts in three shapes, and all three fail the run, because a gate that reports a defect
while exiting 0 is not a gate. The literals can differ. The docs can state a default the source
does not have, so a required argument reads as optional. Or the source can state one the docs omit
— which is also how a *source-side* addition hides behind an unchanged page, and it is the reason
the comparison covers restatements carrying no defaults at all rather than only the 876 that do.
(`--lenient` drops that third shape to a warning, for a tree still paying it down; the other two
fail either way.) Layout is not drift: `SIMD3(0, 0, 1)` and `SIMD3(0,0,1)` compare equal.

All of that depends on comparing against the **right** declaration, because several share one name
and label list: `writeOBJ(to:deflection:)` is both `Document.writeOBJ` (deflection 1.0) and
`Shape.writeOBJ` (0.1). Resolving that by accepting agreement with any candidate cannot invent a
failure, but it can swallow one, and it did — twice, at two different depths. First across types,
letting a page state `Shape.writeOBJ`'s default for `Document.writeOBJ` and exit 0. Then, once a
hint selected the right *type*, across the overloads within it: deprecating a method by keeping its
old signature verbatim, defaults included, is the ordinary way to deprecate, and the stale page
went on matching the retained twin. Both are the #626 shape walking through the gate built for it.

So the owning type is resolved from the nearest heading's qualifier, then outward through the
enclosing section headings (`CurveAdaptors.md` holds `## WireCurve` and `## EdgeCurve`, each with
an identically titled `### points(count:)`), then the page filename — and where that still leaves
two candidates *disagreeing* about a default, the restatement is reported as `unverified` and
fails, rather than being quietly decided by whichever one happened to match. A twin that merely
lacks a default is still disambiguated by the doc's own defaults, so the ordinary deprecation
shape stays quiet. On this tree: 2713 resolved uniquely, 504 by heading, 163 by filename, and
**0 unverified**.

Worth stating exactly, rather than leaving it implied. 129 doc sites across 67 signature groups
still hold more than one candidate after narrowing, but 108 of those are skipped upstream — neither
side states a default, so there is nothing to compare — and only **21 sites across 9 groups** reach
the ambiguity guard at all. Of those, 0 disagree on a value, 4 have a twin merely lacking one, and
17 agree outright; the 17 are protected by the rule rather than by luck, since any later divergence
between them reports `unverified`. The carve-out is narrower than "safe": a **single-sided
acquisition** — one overload gains a default, a bare twin remains, and the page states none — stays
quiet. That is the mirror of the documented twin exemption, it can only ever miss a `source_only`
-class defect, and it is strictly better than before this change, when all 108 were not examined at
all.

Exit status is 1 on any drift, on an unverified restatement, or on growth in the `unmatched`
bucket — a restatement stops being compared the moment its labels stop matching, so an unpinned
bucket there would absorb a rename silently. `--self-test` runs a 13-case battery in memory,
covering each shape above and each mechanism the gate depends on; every case was checked by
reverting the mechanism it guards and confirming the battery goes red, because a case that passes
with its subject removed is not a test. It is committed because three gate scripts on this branch
have now shipped confidently wrong, and an uncommitted battery regresses without saying so. Nothing
runs this script yet — wiring the gate scripts into CI is #625, whose own note warns against
installing a gate that passes unconditionally.

`ContinuityClass.isParametric` was flagged as the same root cause and is the same shape of miss.
#623 fixed `satisfies(_:)` and gave `derivativeOrder` an explicit warning that its `nil` means "no
parametric order", not "meets no floor", because `guard let o = derivativeOrder else { return
false }` reproduces #623 verbatim. `isParametric` is that property's structural sibling with the
identical trap — it is `false` for the geometric classes, so `guard measured.isParametric` ahead of
a `.c0` check reports a tangent-continuous curve as not even connected — and the warning was added
to only one of the two. It now carries it as well, pointing at `satisfies(_:)` the same way.

#### The one grid layout finally covers the third type holding a grid (#617)

#486 declared **U-major** (`occtSurfaceGridIndex`, `iu * vCount + iv`) THE surface-grid buffer
layout of this codebase, and gave `SurfaceGrid` / `SurfaceGridD1` an `.at(u:v:)` accessor for it,
precisely so two bridge functions could not go on writing opposite layouts while each header called
its own "row-major". A third type holding the same shape of buffer was left out of that sweep.

`BRepGraph.FaceGridSample` hands back four parallel flat buffers (positions, normals, Gaussian and
mean curvature) that `OCCTBRepGraphSampleFaceUVGrid` wrote **transposed**, `iv * uSamples + iu`.
The Swift type documented no layout and offered no accessor, so the only guidance a caller had was
the convention #486 had just declared, which was the wrong one for this one type.

Two things make this worse than a plain inconsistency. `docs/reference/BRepGraph-Editor-Identity.md`
**already documented the U-major index** (`index = u * vSamples + v`) for this type, so the bridge
was contradicting its own published reference page, not just a sibling type. And the failure is not
uniform: a caller reading with the layout-conforming stride gets a silent wrong answer at every
aspect ratio (a normal or a curvature attributed to the wrong place on the face, no trap), while
the neighbouring slip of using the wrong count as the stride (`u * uSamples + v`) stays in range on
a 3×10 grid and runs off the end of the same 30-element buffer on a 10×3 one. #617's own report has
these two expressions crossed; the arithmetic is now pinned in a test.

**Converted the bridge to U-major** rather than documenting the transpose, so the codebase keeps one
rule, and routed it through the shared `occtSurfaceGridIndex` so the formula is not re-spelled at a
third site. `FaceGridSample` gains the `.at(u:v:)` accessor its siblings have, resolving the index
through the same shared Swift-side `surfaceGridIndex`, plus an explicit layout line and worked
snippets on the type, the method and the reference page. `OCCTBridge.h`'s declaration now states the
literal index instead of being silent.

**No consumer depended on the old order.** Every in-repo caller and all three ecosystem callers
(`PadCAMEngine`'s `PadCAMMLExport`, `OCCTSwiftScripts`' `occtkit graph-ml` and `GraphML`) sample a
**square** grid and either map the arrays element-wise into a JSON payload or reduce them
order-independently (a mean position/normal face signature), so none reads a specific `(u, v)`. The
observable change is limited to the order of the flat arrays those exporters serialize, which was
never a documented contract on the emitted payload.

| API | Before | After |
|---|---|---|
| `OCCTBRepGraphSampleFaceUVGrid` buffers | V-major, `iv * uSamples + iu`, layout undocumented | U-major via `occtSurfaceGridIndex`, index stated in the header |
| `BRepGraph.FaceGridSample` | four flat arrays, no layout doc, no accessor | same arrays documented U-major, plus `at(u:v:)` |

#### A tangent-continuous surface stops being reported as not even connected (#623)

`ContinuityClass` offers two ways to ask "is this at least X", and they disagreed.
`satisfies(_:)` short-circuited on the `nil` `derivativeOrder` that the geometric classes carry,
returning `false` before it ever read the requested floor:

```swift
surface.continuityClass                  // .g1
surface.continuityClass.satisfies(.c0)   // false
surface.continuityClass >= .c0           // true
```

So a caller gating on "is this at least positionally continuous?" through the API the docs steer
them to rejected every G1 and G2 result — surfaces *smoother* than the C0 ones it accepted.

The old justification, "a `g1`/`g2` result is not a parametric guarantee at any order", is right
for C1 and above and wrong for C0. G1 entails G0 entails positional continuity, and positional
continuity is exactly what C0 is; there is no parametrisation subtlety at order zero, a curve is
either connected or it is not. The `nil` branch now floors at order 0 instead of failing
unconditionally, so `.g1`/`.g2` satisfy `.c0` and still correctly refuse `.c1` and above.
`derivativeOrder` is unchanged — it still reports `nil`, because a geometric class genuinely has
no parametric order; the floor lives in `satisfies` alone.

**Sweeping the full 7×7 matrix of `satisfies` against `>=` found one more disagreement than the
reported cell, and it is not a bug.** Of the 49 (measured, required) pairs, 28 name a
`ParametricContinuity` floor that both APIs can answer. Before: three disagreed — `(.g1, .c0)`,
`(.g2, .c0)` and `(.g2, .c1)`. After: exactly one, `(.g2, .c1)`, and it is correct. `GeomAbs_Shape`
ranks G2 (3) above C1 (2), but curvature continuity does not entail first-derivative continuity,
so the parametric floor rightly refuses what the ladder allows. That is a genuine difference in
what the two APIs are *for*, not drift, and both doc comments now say so: `satisfies(_:)` tests a
measured class against a requested parametric floor, `<`/`>=` ranks two measured classes by their
place in the ladder, and outranking is not entailing. The one exception is named in both.

A third contract in the same file, `ContinuityAnalysis.holds(_:)` and the `GeomAbs_Shape`-ordinal
junction-analysis bitmask behind it, asks exact-class membership rather than a floor or a ranking
and is deliberately untouched; a regression test pins that it stayed independent.

Both readings are OCCT's own, not an inference: `dox/user_guides/modeling_data/modeling_data.md`
says at line 1281 that C0 "is the same as G0 (geometric continuity), so the last one is not
represented by separate variable", and at line 1289 that "Geometric continuity (G1, G2) means that
the curve **can be reparametrized** to have parametric (C1, C2) continuity". The first is why a
geometric class clears the C0 floor; the second is why it clears nothing above it, since the
existence of a reparametrisation is not a promise about the parametrisation in hand. Both are now
quoted in the `satisfies(_:)` doc, and `derivativeOrder` carries an explicit warning that its `nil`
means "no parametric order", not "meets no floor" — the hand-rolled
`guard let o = derivativeOrder else { return false }` reproduces #623 verbatim.

`Issue623ContinuityFloorTests` (`Tests/OCCTSurfaceTests/`) carries the matrix sweep plus two
monotonicity directions, and the tests are explicit about which of them actually guard this bug.
Monotonicity in the *requested* order (whatever a class satisfies, it satisfies everything weaker)
holds for any implementation shaped `f(measured) >= required.rawValue`, the buggy one included, so
it guards a future rewrite that loses downward closure rather than a regression here.
Monotonicity in the *measured* class (if a weaker measurement clears a floor, a higher-ranked one
should too) is the invariant the unconditional `false` actually broke, and it does fail under the
injected bug — 4 violations against the fixed code's 1, that 1 being the documented G2/C1 cell,
which violates it too and so is pinned rather than asserted away. The soundness direction (a floor
check may be stricter than the ladder, never looser) passes vacuously under a too-strict
implementation and guards the opposite failure mode: an over-correction that has a geometric class
clear a floor the ladder never reaches. The matrix is what would have caught this; the single cell
would not have. `Issue485SurfaceContinuityTests` had pinned the old answer as correct and is
corrected.

#### Breaking: the nearest point on a curve, for the entry points #539 left behind, and the whole 2D side (#615)

#539 established that `GeomAPI_ProjectPointOnCurve::LowerDistance()` reports an *extremum*, which on
a bounded curve is neither necessarily the nearest point nor necessarily present at all, and
introduced `occtNearestPointOnCurveRange` — the minimum over `ShapeAnalysis_Curve`, every extremum
in range, and both curve ends. Three entry points were converted. The shared helper behind three
more was not, and its 2D twin was never touched.

So the two spellings of one question disagreed. Measured through the public Swift API on #539's own
repro geometry, a half circle of radius 5 over `[0, π]` queried from below at `(0, -6, 0)`:

| | before | after |
|---|---|---|
| `Curve3D.projectPoint` (converted by #539) | param 0, distance **7.8102** | unchanged |
| `Curve3D.nearestParameter` | param **π/2**, distance **11** | param 0, distance 7.8102 |
| `Curve3D.nearestParameter`, point past a `[3, 8]` segment's end | **`nil`** | param 8, distance 92 |
| `Curve2D.project(point:)` | point (0, 5), distance **11** | point (5, 0), distance 7.8102 |
| `Curve2D.project(point:)`, past the end | **`nil`** | param 8, distance 92 |
| `Point2D.distance(to:)`, past the end | **`.infinity`** | 92 |

A caller seeding a trim or a split from `nearestParameter` landed on the opposite side of the arc
from where `projectPoint` said the nearest point was. The two spellings disagreed about *which*
point is nearest **and** about *whether there is one*.

**Both defects, both dimensions, one helper each.** `occtNearestProjectionOnCurve3d` now routes
through `occtNearestPointOnCurveRange`; the new `occtNearestPointOnCurve2dRange` gives the 2D side
the equivalent treatment.

**The 2D candidate set is the extrema plus both ends, and cannot be more.** `ShapeAnalysis_Curve`
has no 2D projection — its `Project` overloads take `Geom_Curve` or `Adaptor3d_Curve` only, and its
`Geom2d_Curve` members (`FillBndBox`, `SelectForwardSeam`, `GetSamplePoints`, `IsPeriodic`) do
something else entirely. That is the "all extrema + the two ends" row #580 measured at 188/189
rather than the 189/189 the third source buys; the one case it misses is `Extrema` failing to
converge on a BSpline, where an end then wins by a fraction of a percent, and there is no 2D-*native*
second algorithm to break that tie. (A `Geom2d_Curve` could in principle be lifted into the `z = 0`
plane and run through the 3D `ShapeAnalysis_Curve`; not done, since that buys one case in 189 at the
cost of a per-call curve conversion.)

**Breaking: `nil` no longer means "no perpendicular foot".** A point past the end of a bounded curve
is nearest to that end, and a circle's centre is equidistant from every point on it; all of these
now answer with a real parameter and a true distance. `nil` (and `Point2D.distance(to:)`'s
`.infinity`) is left meaning what it means for the entry points #539 converted: no curve to answer
about. Affects `Curve3D.nearestParameter(to:)`, `Curve2D.nearestParameter(to:)`,
`Curve2D.project(point:)`, `Curve2D.project(_:)`, `Point2D.distance(to:)` and the deprecated
`parameterAtPoint`/`closestParameter` spellings, which no longer have a reachable `.nan` case on a
real curve. They stay deprecated for the reason they always were: no `Double` can carry a failure
signal, because every value is a legitimate parameter on some curve.

**`Curve2D.allProjections(of:)` still reports nothing where the other four now answer, and that is
correct.** It asks for the extrema, which has been a different question since #539, and on a bounded
curve queried from beyond its end the honest answer is that there are none. Before #615 all five
agreed only because the other four were asking the extrema question too.

**`Curve3D.locateNearestPoint`: the fallback changed, the primary search deliberately did not.** The
primary reports the **lowest-distance extremum inside a ±10% window** around `initParam`. The guess
bounds the window; it does not rank what is found in it, so the extremum returned is not necessarily
the one nearest the guess — measured on a ramped sine BSpline, a guess of 90.9114 returns param
79.9751, 10.94 away, over an extremum 0.13 away at 91.0378, because the far one is closer to the
query *point* (10.07 against 15.19); 22 of 46 multi-extremum windows behave so. The window is what
makes the answer local, and a windowed minimum can still be a global maximum: with a guess of π/2 on
the arc above it reports 11, and that is pinned by test.

Adding the window's two ends to that minimum was considered and rejected — **not** because it would
redefine `initParam`, which it would not, since the function already minimises over the window and
the ends are all the change adds. It was rejected because (1) it does not make the function correct
under its own name, answering 10.865697905689686 where the true nearest point is 7.8102 away, and
(2) a window's ends always evaluate, so the minimum would always be found and the fallback would
become **unreachable** — deleting the one path in this function that #615 fixes. Making the search
global outright would leave `initParam` meaning nothing and the function a duplicate of
`nearestParameter`.

The full-range fallback is a different matter: it fires only when the window holds no extremum, at
which point the function has already abandoned locality, so it must give the whole curve's answer.
Measured, a guess of `0` — sitting *on* the true nearest point — used to fall through and return the
point diametrically opposite it (π/2, distance 11); it now returns 0 at 7.8102. A `[3, 8]` segment
queried at `(100, 0, 0)` returned `nil` for every guess and now returns param 8, distance 92.

Bridge-only: no kernel patch, no `OCCT.xcframework` rebuild. Regression suites
`Issue615NearestParameterRangeTests` (`OCCTCurveTests`) and `Issue615Curve2DNearestPointTests`
(`OCCTGeom2dTests`), including a 2D-vs-3D cross-check on the same geometry in the `z = 0` plane —
the comparison neither side had, and the reason the 2D defect survived #539. Proved by injection:
restoring both `LowerDistance` helper bodies fails 17 of the 32 tests across the five affected
suites with 41 issues, and the test pinning the *preserved* windowed primary path keeps passing, as
it must. The 2D sweep's ground-truth anchor was separately proved non-vacuous by over-reporting the
distance in the helper: 9 failures with `abs()`, 0 without it.

#### The 21 result-buffer capacities #558's sweep never reached (#622)

#558 bounded 28 *sampling* entry points and introduced `Sampling.capacity(_:)` /
`Sampling.requested(_:atLeast:)`. A review found `Shape.raycast(origin:direction:tolerance:maxHits:)`
with the identical footgun and named three more sites. Re-running #558's own measurement against the
current tree found **21**, not 4 — and two of the four the review named do not survive it at all:
`MedialAxis.drawArc` was already bounded by #558 itself, and both quoted `Document.swift` line
numbers land on unrelated code. The named list was neither complete nor correct, which is the same
lesson #558 recorded when its census said 14 and its measurement said 28.

The reason the sweep stopped short is a scoping one, not an oversight: #558 scoped itself to
*samplers*, and these 21 are **result-buffer capacities** on picking, spatial search, projection,
intersection, hatching, text conversion and directory listing. Same mechanism throughout — a
caller-supplied number sizes a Swift allocation and is then cast to the `int32_t` the bridge takes
its capacity in, so `Array(repeating:count:)` traps on a negative and `Int32(_:)` traps past
`Int32.max`.

Measured one case per process, since a trap takes the whole harness down with it. 18 of the 21 are
drivable from a standalone binary; **all 18 failed at `Int(Int32.max) + 1`** — 2 aborted immediately
with `Fatal error: Not enough memory` and 16 ground past a 40-second timeout on an allocation
nothing can serve. **12 of the 18 also aborted on `-1`**, inside `Array(repeating:count:)`, before
any bound could be consulted. The remaining 3 (`Selector.pick`'s three overloads) need a live
selector and were converted on inspection, then covered in-process. After the fix all 18 return
their documented value at both inputs.

The sites, by owning type: `Shape.raycast`, `Shape.allDistanceSolutions`, `Shape.selfIntersectionPairs`,
`Curve3D.extrema` / `.intersections(with:maxHits:)` / `.splitAtContinuity` / `.projectPointAll`,
`Curve2D.splitAtContinuity`, `Surface.intersections(with:maxCurves:)` / `.projectPointAll`,
`KDTree.kNearest` / `.rangeSearch` / `.boxSearch`, `Selector.pick` (all three overloads),
`HatchPattern.generate`, `UnicodeUtils.convertFromUnicode`, `DirectoryIterator.list`,
`FileIterator.list`, and `LogSample.sample`.

**The contract is #558's, not a fifth one.** 20 of the 21 are capacities: the algorithm decides how
many results exist and the number only truncates, so they clamp into `0...Sampling.maximumSampleCount`
and an absurd capacity returns the *same* answer rather than an empty one. The exception is
`LogSample.sample(from:to:count:)`, whose bridge fills the buffer exactly — that is a *request*, so
it rejects outside `1...ceiling` rather than silently handing back 10 million values for a
10-billion request. Exactly the split #558 drew between `Curve3D.drawAdaptive` and
`MedialAxis.drawArc`.

```swift
let box = Shape.box(width: 10, height: 10, depth: 10)!
let ray = (origin: SIMD3(0.0, 0, 20), direction: SIMD3(0.0, 0, -1))

// A capacity is clamped, so an unservable one still returns the real answer.
box.raycast(origin: ray.origin, direction: ray.direction, maxHits: 10_000_000_000).count
    == box.raycast(origin: ray.origin, direction: ray.direction).count   // true
box.raycast(origin: ray.origin, direction: ray.direction, maxHits: -1)   // [] -- used to abort

// A request is rejected, never silently coarsened.
LogSample.sample(from: 1, to: 100, count: 16).count                      // 16
LogSample.sample(from: 1, to: 100, count: 10_000_001).count              // 0, not 10,000,000
```

**Two behaviour changes beyond "stops aborting", both at a zero-or-negative count:**

- `Shape.allDistanceSolutions(to:maxSolutions:)` returns `[]` rather than `nil` for a capacity of 0
  or less. The bridge answers `-1` for `maxSolutions <= 0` and the old `guard count >= 0` turned
  that into `nil`, so "no room was offered" was reported as "the measurement failed". Every sibling
  in this set returns its documented empty value for no capacity, and `nil` is now reserved for an
  actual failure.
- `KDTree`'s three searches gain an **effective** result ceiling of 10,000,000. The bridge returns
  `min(results.Size(), maxResults)` with no truncation flag, so a caller who previously passed a
  huge capacity against a >10-million-point cloud and got a complete answer now silently gets
  10,000,000 of them. The silence is pre-existing (there was never a "there were more" signal); the
  ceiling is new.

**A separate, pre-existing defect surfaced while building the fixture and is *not* fixed here:**
`Curve3D.extrema(with:maxCount:)` SIGSEGVs (uncatchable) on two **parallel** curves at *any*
capacity — measured at `maxCount` 2, 20, 100, 1e4, 1e6, 1e7 and `Int32.max + 1`, all signal 11,
including the method's own default of 20. The bridge's own loop is correctly bounded by
`min(NbExtrema(), maxCount)`, so the crash is inside `GeomAPI_ExtremaCurveCurve`'s construction: the
documented `BRepExtrema_ExtCC` parallel hazard, on the `GeomAPI` path. It has nothing to do with the
count bound, and the regression fixture uses skew curves deliberately so that it tests the bound
rather than the crash. Filed as
[#636](https://github.com/SecondMouseAU/OCCTSwift/issues/636).

**Also measured, also not fixed here, for the same "do not invent a contract" reason — now filed as
[#640](https://github.com/SecondMouseAU/OCCTSwift/issues/640).** The math solver/optimizer family
has the same trapping shape, at **13** entry points in `Sources/OCCTSwift/Document.swift`:
`MathSVD.solve` (`:5699`), `MathJacobi.eigenvalues` (`:5744`), `MathHouseholder.solve` (`:5919`),
`MathOptimizer`'s `solveSystem`, `minimize`, `minimizePowell`, `particleSwarm`, `globalMinimize`,
`solveSystemNewton`, `minimizeNewton` and `gaussSetIntegration`, and `MathSolver.leastSquares`
(`:14193`) and `.uzawa`.

These are problem *dimensions* that must agree with the caller's own `matrix` / `startPoint` arrays,
not sampling capacities, and clamping a dimension to 10,000,000 would hand back a garbage-dimension
solve rather than truncating a result set — so `Sampling.*` is the wrong tool and applying it would
have been precisely the fifth behaviour #622 asked to avoid.

**A consistency check against those arrays is *not* on its own the remedy**, which is where an
earlier draft of this note was wrong. A degenerate array satisfies the consistency relation exactly
and still aborts:

```swift
MathJacobi.eigenvalues(matrix: [1.0], n: -1)   // matrix.count == n*n holds exactly: 1 == 1
                                                // still aborts: Can't construct Array with count < 0
```

The same holds for `MathSVD.solve` and `MathHouseholder.solve`. A positivity bound is needed as
well. And `MathSolver.leastSquares` has **no** consistency check at all, so `Int32(rows)` /
`Int32(cols)` drive an out-of-bounds **read** of `matrix` inside the bridge — memory unsafety rather
than a clean trap, and the reason #640 is not merely a tidiness issue.

Regression suite: `Tests/OCCTMiscTests/Issue622AllocationBoundsTests.swift`, 13 tests covering all
21 entry points. They run in-process only because the fix is what lets them: before it, every
assertion in them would have aborted the test harness rather than failing. They compare
`.count == 0` rather than reading `.isEmpty`, for the reason #558 recorded — Swift Testing prints
the captured sub-expression on failure, and a regression returning 10 million results would print
all 10 million of them.

Confirmed by injection, one bound at a time: with the ceiling removed from the bound it covers (and
the lower bound left in place, so the edit still compiles and the injection is exactly "the ceiling
is gone"), **all 13 tests stopped passing** — 12 aborting with signal 5 and `raycast` dying mid-run
before it could report an assertion. Each was restored by exact reverse replacement and re-verified
afterwards.

The `raycast` case dies at the `Int32(capacity)` conversion ("Not enough bits to represent the
passed value"), *not* at the buffer allocation: `calloc` hands back lazily-zeroed pages, so the
nominally ~189 GB `[OCCTRayHit]` costs nothing until it is touched. The trapping conversion is
reached first. Worth recording, because it means the allocation size is the wrong thing to reason
about when judging which of these entry points is dangerous — the `int32_t` cast is what fires, and
it fires identically whether the element is 8 bytes or 88.

#### A fillet radius law goes to the edge's own slot, in the edge's own contour (#612)

`filletEvolving`, `filleted(edges:startRadius:endRadius:)` and `filletedVariable` all wrote their
law with `SetRadius(law, NbContours(), 1)`. Both coordinates were wrong, independently.

**The contour.** `NbContours()` is "the contour that exists after the most recent `Add`", which is
the edge's own contour only when every `Add` creates one — a tangent-continuous edge **extends** an
existing contour instead. Measured on a rounded-slot prism (two straight sides joined by two
semicircular ends, extruded 20mm), adding a top-rim edge, a bottom-rim edge, then a second top-rim
edge:

| after | `NbContours()` | `Contour(edge)` |
|---|---|---|
| add top-rim edge | 1 | 1 |
| add bottom-rim edge | 2 | 2 |
| add second top-rim edge | 2 | **1** |

The third edge's law was written to contour 2, replacing the bottom rim's own. Asking for top rim
2mm and bottom rim 5mm returned **10271.088459** — byte-identical to filleting *both* rims at 2mm —
against the intended **9899.533264**.

**The slot.** `SetRadius`'s third argument, `IinC`, is the edge's index *within* the contour and
selects a distinct per-edge slot. Hardcoding it to `1` sent every edge of a tangent chain to the
same slot, so only the last survived. On the same rim, filleting the straight side at 2mm and its
tangent arc at 5mm:

| | volume |
|---|---|
| both laws at slot 1 (the old idiom) | 9974.608333 — the arc's 5mm overwrote the line's 2mm |
| each law in its own slot | **10139.793468** — both honoured |
| `blendedEdges([(line, 2), (arc, 5)])` | **10139.793468** — byte-identical |

`Add(Radius, E)`, which backs `blendedEdges`, resolves that slot itself, so it always honoured the
very request `filletEvolving` could not express. **There was never a "one law per contour" limit to
work around** — the conflict was an artefact of the hardcoded `1`. #612's own example (a taper on
one edge, a constant on its tangent neighbour) is an ordinary request and now builds, at
10171.225408.

The slot is visible on a single edge too: a 1 → 4 taper on one added edge measures 10273.238348,
10297.711861, 10343.333856, 10402.168644 at slots 1, 2, 3, 4.

**The linear entry point was observably wrong after all.** Its batch shares one `(startRadius,
endRadius)`, so with a *constant* law two edges of a contour rewrite the same number and nothing
moves — but a genuine taper does not: two tangent-continuous edges at 1 → 4 measured
**10273.238348**, exactly what filleting the first alone produces, against **10297.711861** with
each law in its own slot. It now uses OCCT's own one-call `Add(R1, R2, E)`, which is `Add(E)` plus
the same slot resolution plus `SetRadius` — verified identical to resolving the slot by hand, and it
declines an unfilletable edge by construction. `OCCTShapeHistoryFromFilletEdgeVariable` moves to the
same overload: its `SetRadius(radii, 1, 1)` was in fact safe, because a single added edge always
lands at index 1 of its contour's spine (measured on all four edges of a tangent rim) and a
*literal* 1 is bounds-checked upstream, but the idiom is gone.

**And `filletedVariable` on such an edge did not merely pick a wrong index — it SIGSEGV'd.** When
OCCT declines an edge outright (a free-boundary edge of an open shell; 4 of the 12 edges of a box
missing one face), `Contour(E)` is 0 and `NbContours()` is 0, so the call became
`SetRadius(law, 0, 1)` — the unchecked low side of the contour index #505 measured. That is an OS
signal, uncatchable in process. Confirmed by re-injecting the old code: `swift test` exits with
signal 11. Such an edge is now resolved to no slot and skipped, which is exactly what
`Add(Radius, E)` already does with it — measured identical to the digit, **surface area
465.09733552923257** over all 12 edges of that shell, whichever entry point applies it, so the
edge-list fillet family agrees. A batch in which *every* edge is declined leaves zero contours and
fails in `Build()`, so an all-refused request still returns `nil` rather than the unfilleted input.

Measure an open shell by **area**, not volume: it is not a solid, so `BRepGProp::VolumeProperties`
fabricates a number for it — the very defect class #605/#609 exist to reject — and that number is
not even a property of the shape. It ranges 746.83 to 748.28 depending on which of the six faces is
dropped, while the surface area is 465.097 for all six.

#### A NaN parameter bound stops being a plausible arc length (#548)

`Curve3D.length(from:to:)` documents itself as the entry point that tells failure apart from a real
measurement, and #408 built the `-1.0` sentinel of `arcLength(from:to:)` / `arcLengthBetween(_:_:)`
on top of that guarantee. It held for the curve types the tests used.

`GCPnts_AbscissaPoint::Length(adaptor, u1, u2)` does not validate its bounds, and what it does with
a non-finite one depends on which of its three internal branches the curve takes. Measured against
the pinned kernel (`Scripts/repro/548-nonfinite-length-bounds/`), on a 5-point interpolated BSpline
(domain `[0, 485.39]`, length 528.75) and the analytic types:

| bounds | segment / line / circle | Bezier | multi-span BSpline |
|---|---|---|---|
| `(f, .nan)` | `nan` → `nil` | `nan` → `nil` | **`0`** — what a zero-width interval measures |
| `(.nan, l)` | `nan` → `nil` | `nan` → `nil` | **`528.75`** — the whole length |
| `(f, .infinity)` | **`+inf`** — passes `l >= 0` | `nan` → `nil` | `528.75` |

**The discriminator is not "spline" but "composite".** A 4-pole Bezier propagates NaN like a
circle; what separates the BSpline is `NbIntervals(GeomAbs_CN) == 4`, which sends it down
`GCPnts_AbscissaPoint::length`'s `GCPnts_AbsComposite` branch. That branch reduces the caller's
range with `std::min`/`std::max`, and those return their *first* argument when the comparison is
false: a NaN upper bound collapses the interval onto the start parameter (hence `0`), and a NaN
lower bound makes both bounds NaN, which turns every per-span skip test false and integrates every
span in full (hence the whole length). Not the domain clamping the issue supposed.

**Both bounds must now be finite**, checked in the bridge by `occtValidParameterRange` before any
adaptor is built, so the contract no longer depends on the integrator's own NaN handling.
`.nan` and `±.infinity` report `nil` from `Curve3D.length(from:to:)` and `Curve2D.length(from:to:)`,
and `-1.0` from `Curve3D.arcLength(from:to:)` / `arcLengthBetween(_:_:)`,
`Curve2D.arcLength(from:to:)` and `Shape.edgeArcLength(from:to:)`. Finite ranges are untouched,
including the reversed, overshooting and wholly-outside ones #506 pinned.

**`Shape.edgeArcLength` gains a failure sentinel.** It was the only member of the family with
neither an optional nor a sentinel, so a NaN bound on a straight edge returned NaN itself into
caller arithmetic. Both spellings (`edgeArcLength` and `edgeArcLength(from:to:)`) now report `-1.0`
on failure instead of `0`, matching every other arc-length function in the bridge — `0` is what a
genuine zero-width interval measures.

**Also measured here, fixed in #600 below:** the documented "parameters outside the curve's domain
are clamped to it" holds only on composite curves. A 10-long segment measures 20 over
`[f, l + span]`, and a Bezier 122.14 long measures 1002.29 — polynomial extrapolation past its
poles.

#### An out-of-domain range measures the curve, not its extrapolation (#600)

Filed out of #548's measurements. `Curve3D.length(from:to:)` documented (since #477) that
"parameters outside the curve's domain are clamped to it, so a range wholly outside measures `0`
rather than extrapolating the curve's polynomial". That was measured on an interpolated BSpline and
holds only for curves with more than one `GeomAbs_CN` interval, because
`GCPnts_AbscissaPoint::length` intersects the requested range with the curve's own knots in that
branch and in no other. Measured over `[f, l + span]`, one domain width past the end
(`Scripts/repro/600-out-of-domain-length/`):

| curve | own length | was | now |
|---|---|---|---|
| segment (trimmed line) | 10 | 20 | **10** |
| Bezier, 4 poles | 122.14 | 1002.29 | **122.14** |
| arc, half a circle | 15.71 | 31.42 | **15.71** |
| multi-span BSpline | 528.75 | 528.75 | 528.75 |
| circle | 31.42 | 62.83 | 62.83 |
| periodic BSpline | 548.51 | 548.51 | **1097.02** |

**One rule now, applied in the bridge instead of falling out of which branch a curve's type takes:
a ranged arc length measures the part of the range that lies on the curve.** A curve whose
parameter domain covers a whole period exists at every parameter, so those measure the whole range
and wind — a circle over `[0, 4π]` still travels two circumferences, which confining would have
broken.

**The last row is why "confine unless periodic" was not enough.** A closed interpolated BSpline is
periodic *and* composite, so GCPnts confined it to its knots and returned one period for a request
of two — silently answering half of what was asked, with no failure reported. Winding is computed
in `occtAdaptorLengthBetween` (whole turns × one period's length, plus the remainder wrapped into
the domain) rather than delegated. Verified against a chord-sum reference.

**Periodicity alone is not the test.** A `Geom_TrimmedCurve` over half a circle reports
`IsPeriodic() == true` with `Period() == 2π`, inheriting the basis curve's periodicity, so the
domain must cover a whole period before a range is allowed to wind. Otherwise an arc would measure
round the part of the circle its caller trimmed away, which is what it used to do.

All four ranged entry points share the measurement, so a curve, its 2D equivalent and an edge built
from it now answer an out-of-domain range identically. `Curve2D.arcLength(from:to:)` keeps its own
range check (a reversed range still fails — that is #549's decision, not this one's) but no longer
evaluates past the domain: 4771.88 for a BSpline 457.26 long, before.

**Found while measuring, filed as #603:** `GCPnts_AbscissaPoint::Length` integrates a single-span
conic with one Gauss quadrature over the whole domain and lands 0.34% high on an 8×3 ellipse
(36.4894 against a true 36.36686, confirmed by both a Richardson-extrapolated chord sum and a
2M-point Simpson quadrature of the elliptic integral), 1.49% on a 10×1 and 1.74% on a 1×0.05.
Sub-ranges are accurate to ~1e-6 and summing two equal halves of the period recovers full accuracy,
so it is the single quadrature — the #477 defect, on a curve type with no `GeomAbs_CN` boundaries
to split at. Not fixed here: an accuracy question, not a range-semantics one — fixed in the #603
entry immediately below.

#### Arc length stops being one quadrature per span (#603)

`Curve3D.length` on a full ellipse was up to 1.7% wrong, and it was the *whole-curve* measurement
that was wrong — the same ellipse's sub-ranges were exact.

`CPnts_AbscissaPoint::Length` integrates `|C'(u)|` with **one** fixed-order Gauss rule over the
whole range it is handed (order 10 for a conic, 5 for a parabola, `2 × Degree` for a Bezier).
#477 moved this family onto `GCPnts_AbscissaPoint::Length`, which splits at the `GeomAbs_CN`
interval boundaries and applies that rule per interval — but a conic has exactly one interval, so
the rule still had to cover the entire domain in one go. Measured against a 16-point composite
Gauss-Legendre quadrature over 40,000 panels, cross-checked against a Richardson-extrapolated chord
sum (`Scripts/repro/603-single-span-quadrature/`):

| curve | was | now | error |
|---|---|---|---|
| ellipse 8 × 3 | 36.489427 | **36.366863** | +0.337% → 1.7e-14 |
| ellipse 10 × 1 | 41.243158 | **40.639742** | +1.485% → 1.8e-13 |
| ellipse 1 × 0.05 | 4.089251 | **4.019426** | +1.737% → 2.9e-14 |
| parabola f=3 over `[-100, 100]` | 1638.523403 | **1690.708712** | −3.087% → 9.6e-14 |
| hyperbola 5/2 over `[-4, 4]` | 285.669841 | **285.479769** | +0.067% → 2.1e-14 |
| Bezier degree 3, whipping poles | 48.124451 | **48.215370** | −0.189% → 2.0e-14 |
| interpolated BSpline, 5 points | 110.963893 | **110.970568** | −0.0060% → 2.5e-14 |
| circle r=5, line | exact | exact | closed form, no quadrature |

**A parabola is the worst case in the family, and the only one wrong in the other direction** — it
gets the lowest order `CPnts_AbscissaPoint`'s `order()` hands out to anything curved. The issue
named it as worth measuring and had not measured it.

**It is not a conic defect, and not a "single span" defect either.** The error is set by how much
`|C'|` varies across one integration interval: the 8 × 3 ellipse is 0.337% out over `[0, 2π]`,
0.0001% over `[0, π]` and exact over `[0, π/2]`. So a *multi-span* curve is affected too wherever
its spans are wide — a 5-point interpolation is 100× worse than the 40-point curve #477 was tested
on. #477 is completed here, not superseded.

**Each `GeomAbs_CN` interval is now measured, then halved, quartered, … until two successive levels
agree to 1e-9 relative** (`occtAdaptorArcLength`, `Sources/OCCTBridge/src/OCCTBridge_Internal.h`).
Subdividing the *whole range* instead does not work and fails silently: on a uniformly-knotted
curve the domain midpoint is a knot GCPnts already splits at, so the level-2 sum repeats the level-1
sum bit for bit and a convergence test ratifies an answer that never moved (measured: 110.963893077
at both levels, truth 110.970568312).

**The inverse moved with it, and had to.** OCCT's root finder inverts the very quadrature this
replaces (`CPnts_MyRootFunction::Value` is one Gauss rule over `[u0, X]`), so before this the length
and its inverse were wrong by the same amount and `parameterAtLength(length)` still landed on the
curve's last parameter. Fixing only the length would have moved that to 6.2438 on an 8 × 3 ellipse
whose domain ends at 6.2832, and to 6.0358 on a 10 × 1 — 0.33% and 1.0% short in arc. So
`Curve3D.parameterAtLength`, `Curve2D.parameterAtLength`, `Shape.edgeParameterAtArcLength`,
`Shape.edgeParameterAtFraction`, `EdgeCurve.parameter(atAbscissa:)` and
`WireCurve.parameter(atAbscissa:)` walk the same subdivided pieces and hand the last, narrow one to
the kernel's solver, which is accurate at that width. A target longer than the curve keeps its old
answer (the kernel reports a parameter outside the curve's own domain, yet reports success; turning
that into a failure is a contract change #603 has no measurement to justify).

Every entry point in the family shares the measurement: `Curve3D.length`, `length(from:to:)`,
`totalArcLength`, `arcLength(from:to:)`, `arcLengthBetween(_:_:)`, `Curve2D.length`,
`length(from:to:)`, `arcLength(from:to:)`, `Shape.edgeArcLength` (both spellings), `Wire.length`,
`EdgeCurve.length` and `WireCurve.length`. #600's winding is computed from an accurate period, so
two turns is exactly twice one.

**Cost**: roughly 5×, with a floor of three quadratures per interval where there was one — an
8 × 3 ellipse goes 0.11 µs → 3.5 µs, a 200-span BSpline 89 µs → 452 µs. A line, a circle or a
2-pole Bezier/BSpline keeps its closed form (`GCPnts_LengthParametrized`), converges on the first
split with nothing to remove, and stays at 0.02 µs.

**Measured rather than assumed, on the two neighbours the issue lists as downstream.**
`GCPnts_UniformAbscissa` is **not** affected — on the worst ellipse its samples are uniform in true
arc to 1.9e-10, so sampling by arc length was already right and is untouched.
`BRepGProp::LinearProperties` **is** affected and is **not** fixed here: it runs its own integrator
and still reports 41.243158 for the 10 × 1 elliptical edge. `Shape.linearProperties().length`
therefore now disagrees with `Shape.edgeArcLength` on such an edge, where before both were wrong
together; reimplementing mass properties is separate work.

**The kernel fix ships too** (`Scripts/patches/0021-*`, `OCCT.xcframework` rebuilt): a new
header-only `CPnts_AdaptiveIntegration.hxx` does the same doubling, used by all four
`CPnts_AbscissaPoint::Length` overloads and by `CPnts_MyRootFunction::Value`/`Values`. Both, or
neither: the root function's `Value(X)` is the same integral, so it currently inverts exactly the
bias `Length` has — which is why `GCPnts_UniformAbscissa` spaces points uniformly in *true* arc
(2.90e-14 on an 8 × 3 ellipse) while computing a total 0.337% wrong, and why changing `Length`
alone would have broken the sampler. Measured both ways; changed together its spacing is unchanged
to the digit. `CPnts_AbscissaPoint::Length` called directly, where nothing splits at all, goes from
**1.0e-1** out on a 200-point interpolation to 2.8e-8. Kernel cost:
`GCPnts_AbscissaPoint::Length` 0.24 µs → 7.2 µs on an ellipse, 87 µs → 444 µs on a 200-span
BSpline, `GCPnts_UniformAbscissa` at 500 points 2.71 ms → 6.20 ms. Filed upstream as
[Open-Cascade-SAS/OCCT#1420](https://github.com/Open-Cascade-SAS/OCCT/pull/1420).

**The bridge subdivision stays for now, and is redundant once that binary is pinned.** `ci.yml`
resolves the pinned *released* kernel, which has no patch `0021` until a release ships the rebuild,
so removing it would fail this issue's own regression tests there. Layered on the fixed kernel it
costs almost exactly 2× (8 × 3 ellipse 3.3 µs → 6.6 µs) and changes no answer — retire it in the
release commit that bumps `Package.swift`'s `url:`/`checksum:`.

#### The 2D arc length that measured 8082 for a curve 353 long (#549)

`Curve2D.arcLength(from:to:)` and `Curve2D.length(from:to:)` answered differently on a reversed
range: the first reported `-1.0`, the second measured the span. #506 removed the 3D spelling of that
divergence and filed this one as the 2D half, a consistency question rather than a bug report, since
both behaviours were documented and each doc page was accurate about itself. Measuring the pair
first, as the issue asked, made it a correctness question as well. On a 5-point 2D interpolation
(domain `[0, 318.433]`, length 353.508):

| range | pre-bounded (`arcLength`) | ranged (`length`) |
|---|---|---|
| in domain, forward | 169.457 | 169.457 |
| in domain, reversed | raises, reported as `-1.0` | 169.457 |
| overshooting both ends by a domain width | **8082.404** | 353.508 |
| overshooting the upper end only | **2549.691** | 353.508 |
| wholly outside the domain | **1.259** | 0 |
| equal parameters, periodic seam, two full periods, unbounded sub-range | agree | agree |

The reversed-range rejection was the visible half of a pre-bounded `Geom2dAdaptor_Curve(curve, u1,
u2)`. The other half was that it evaluated a multi-span curve's polynomial past its knots and
reported the result as an ordinary success: the defect #477 removed from the 3D path, still live in
2D because the two dimensions were fixed one at a time.

`OCCTCurve2DLength` is gone, with tombstone comments naming the survivor, and
`Curve2D.arcLength(from:to:)` now delegates to `length(from:to:)`, the shape
`Curve3D.arcLength(from:to:)` has had since #408. That was the last pre-bounded arc-length call site
in the bridge. New suite `Issue549Curve2DArcLengthRangeTests` (`OCCTGeom2dTests`) pins the divergent
ranges against a chord-sum reference and checks the 2D answers against the 3D ones on the same points
in the z = 0 plane; #409's suite keeps the `-1.0`-not-`0.0` sentinel it was written for, on an input
that still fails. Proved by injection: restoring the pre-bounded call reproduces the figures above
through the public Swift API and fails 7 of the 11 tests across the two suites. Probe and full
figures at
[`Scripts/repro/549-curve2d-arclength-range-order/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/549-curve2d-arclength-range-order).

**Two things the measurement corrected on the way past.** `Curve3D.length(from:to:)` documented its
clamping unconditionally ("Parameters outside the curve's domain are clamped to it"), which holds
only for a curve with more than one `GeomAbs_CN` interval: `GCPnts_AbscissaPoint::length` intersects
each interval with the requested range there, but a line, a circle or a 2-pole spline returns
`|u2 - u1| * ratio` and a single-span Bezier integrates the range as given, both unclamped. Measured
on four curve types in both dimensions (a Bezier reports 41.256 for a range wholly outside its
domain), and the 2D and 3D wording now say so. Separately,
`Scripts/check-bridge-index.py` read the sources whole, so a *removed* function still counted as
existing as long as its tombstone comment named it, which the tombstone idiom (#500, #506) puts there
on purpose. It strips comment lines from the sources now, which surfaced three stale entries in the
`GCPnts_AbscissaPoint` index line, all three of them removed arc-length spellings. The new
`--self-test` case is exactly that: a real symbol that survives only in a tombstone.

**Noticed, not fixed.** Routing 2D onto the ranged form gives it #548's NaN hole too: on a multi-span
2D curve a NaN bound lands on a domain bound instead of poisoning the integral, so
`length(from: f, to: .nan)` reports `0` and `length(from: .nan, to: l)` the whole length. On a line,
a circle, a segment or a Bezier the NaN propagates and both spellings report failure, which is what
the new suite pins. Noted on #548 so one fix covers both dimensions.

#### Breaking: defeaturing refuses a face the shape does not have, instead of dropping it (#578)

`Shape.defeature(faces:)` inherited OCCT's own rule for a face that is not part of the input:
`BRepAlgoAPI_Defeaturing.hxx` says "those that do not belong will be ignored", and it means it. A
request mixing one of this shape's faces with another shape's succeeded, removed the one that
belonged, and raised no warning of any kind — a success indistinguishable from a real removal, handed
back on a shape still carrying the feature the caller asked to remove. The index-addressed spelling of
the same operation, `withoutFeatures(faces:)`, has failed the whole call on one bad index since #497;
#536 made `defeature(faces:)` canonical without closing that gap, because a membership rule turned out
not to be the line of validation it looks like.

**Why it needed measuring first.** `AddFaceToRemove` takes a `TopoDS_Shape`, and its own documentation
calls it "the shape to extract the faces for removal" — the argument need not be a face. Measured on
the pinned kernel: a compound holding a face, the input's own shell and the whole input solid are all
accepted and each means the faces it contains, while an edge, a vertex and an empty compound are
refused because they contain none. So a rule cannot ask that each element *be* one of this shape's
faces; it has to explore first, and then decide what a carrier mixing belonging and foreign faces
means. Two further measurements make the check implementable and exact: replacing a carrier with the
faces it explores to is the same request BREP for BREP, and the input's own `TopExp` face map hashes on
`IsSame`, so it accepts the fillet face reversed and rejects the same face measured off an
identically-built twin. Probe, full matrix and the rejected alternative at
[`Scripts/repro/578-defeature-face-membership/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/578-defeature-face-membership).

**The rule now applied**, in `occtDefeaturingFacesFromShapes` (the #497 skeleton, which now takes the
input shape so it can build that map):

> Every element of the request must name at least one face, and every face it names must be a face of
> this shape. Otherwise the whole call returns `nil` and nothing is removed.

The alternative the issue posed — accept a carrier yielding *some* belonging faces and quietly keep
those — was rejected because it preserves the exact failure mode being removed, one level further down
where it is harder to see. Exactly four kinds of request change, and all four were being partly
discarded in silence: a foreign face alongside a real one, a compound mixing the two, and an edge or an
empty compound alongside a real face. Nothing whose elements all belong behaves differently, carriers
included — the whole-solid and shell forms stay accepted, and stay a no-op, because "remove every face"
is a question about the algorithm rather than about membership and the kernel's answer to it is to hand
the input back unchanged.

Nothing is filed upstream: the kernel documents what it does and does it. The strictness is this
bridge's contract, and it is now the same contract at both spellings.

New suite `Issue578DefeatureFaceMembershipTests` (`OCCTModelingTests`) pins the whole matrix, and
`Issue536DefeaturingSpellingsTests`' two membership tests — which pinned the old behaviour — are
replaced by one that holds the two spellings to the new rule together. Proved against two injections:
restoring the pass-through fails six tests across both suites, and injecting the *rejected* alternative
fails exactly one, the mixed-carrier test that exists to pin the design decision.

#### The index entries that named a real symbol belonging to a different class (#565)

#510 fixed the 135 index entries in `OCCTBridge.h` that named symbols which never existed. This is
the second defect class in the same index: an entry naming a real symbol **from a neighbouring
class**. It passes an existence check and misleads exactly the way a fabrication does — you look up
a class, get sent to a function that has nothing to do with it, and conclude the class is wrapped
there. #501 hit it directly (`GCPnts_UniformAbscissa → OCCTCPntsUniformDeflection*`, a symbol that
exists and wraps `CPnts_UniformDeflection`).

**17 entries corrected.** Every one named a symbol that exists, so the #510 gate called them all
clean:

| entry | named | actually drives |
|---|---|---|
| `BOPAlgo_CellsBuilder` | `OCCTBOPAlgoSplit` | `BOPAlgo_Splitter` — already the entry two rows down |
| `ShapeFix_Wire` | `OCCTShapeFixWire*` | that prefix is `ShapeFix_WireVertex` + `ShapeFix_Wireframe` |
| `BRepOffsetAPI_MakePipe` | `OCCTShapePipe*` | that prefix is `BRepFeat_MakePipe` |
| `BRepFill_OffsetWire` | `OCCTWireOffset` | `BRepOffsetAPI_MakeOffset` |
| `BRepOffset_Analyse` | `OCCTEdgeGetConvexity` | nothing — convexity is computed by hand |
| `GC_MakeCircle` / `GC_MakeSegment` | `OCCTWireCreateCircle` / `OCCTWireCreateLine` | `BRepBuilderAPI_MakeEdge` from a `gp_Circ`/`gp_Lin` |
| `ShapeAnalysis_WireOrder` | `OCCTWireAnalyze` | `ShapeAnalysis_Wire` |
| `LProp_AnalyticCurInf` | `OCCTLPropAnalyticCurInf` | `LProp_CurAndInf`; the analytic scan is reimplemented inline |
| `Law_Interpol` | `OCCTLawInterpolate` | `Law_Interpolate` — a different class, one letter apart |
| `Geom2d_Direction` / `Geom2d_VectorWithMagnitude` | `OCCTDirection2D*` / `OCCTVector2D*` | `gp_Dir2d`/`gp_Vec2d`; neither `Geom2d_` class is wrapped at all |
| `ShapeUpgrade_ConvertCurve3dToBezier` (+`…SurfaceToBezierBasis`) | — | reached via `ShapeUpgrade_ShapeConvertToBezier`; now says so |
| `BRepCheck_Edge/Face/Shell/Solid` | `OCCTBRepCheckSubShapeValid` | `BRepCheck_Analyzer` |
| `BRepOffsetAPI_MakePipeShell` | `OCCTPipeShell*` | `BRepFill_PipeShell` |
| `BRepGProp` | `OCCTShapeGetCenterOfMass` | `BRepBndLib` — see below |

Six classes had **no entry at all** because a wrong one was standing in for them:
`ShapeAnalysis_Wire` (39 call sites), `BRepFill_PipeShell` (24), `BRepOffsetAPI_MakeOffsetShape`,
`BRepOffset_MakeOffset`, `Law_Interpolate`, `LProp_CurAndInf`. `Geom2d_Direction` and
`Geom2d_VectorWithMagnitude` moved to `docs/occtswift-wrapping-gaps.md` as genuinely unwrapped.

**The direction check now gates, per symbol rather than per entry.** An entry-level rule ("at least
one of these reaches the class") lets a wrong symbol hide behind its correct neighbours — which is
the whole shape of the defect, and `GCPnts_UniformAbscissa` was only caught in #501 because it
happened to be its entry's sole symbol. Two injected mistakes proved this: adding
`OCCTShapeFixWireframe` to the correct `ShapeFix_Face` entry went unreported until the rule changed.

Four forms of indirection had to be resolved first, because a check that cannot tell "wrong class"
from "reached indirectly" fails on correct entries and gets switched off: wrapper-type fields
(`XCAFDoc_ShapeTool` is `OCCTDocument::shapeTool`, 66 call sites), file-local `static` helpers
(`TDataStd_NamedData`, the near-miss that almost got its entry wrongly deleted in #510), static
facades (`ShapeCustom::SweptToElementary` is how `ShapeCustom_SweptToElementary` is reached), and
multi-class headings (`RWObj_CafReader/Writer` covers `RWObj_CafWriter`, not `RWObj_Writer`). Where
a class is genuinely reached only through *another OCCT class*, the entry carries a `(via X)` aside
— and that aside is itself checked, not a silent skip. `--self-test` grew from 5 cases to 15: five
existence shapes, four mis-attribution shapes, and six correct shapes asserted **not** reported.

**A parenthesised aside is commentary, not an attribution.** The existence check reads names inside
asides by design (that is how #508's `OCCTGCE2dMakeLine*` was caught), but the direction check must
not: `(OCCTWireOffset drives BRepOffsetAPI_MakeOffset, not this)` names a symbol precisely to say it
does *not* wrap the class.

**A tombstone comment was resurrecting two deleted symbols.** `real_symbols` stripped comments from
the header but not from the sources, so `// OCCTCurve3DLength lived here: …` — left where #506/#549
deleted the function — kept a removed symbol passing the existence check forever. Stripping source
comments too flags exactly the two names it should (`OCCTCurve3DArcLength*`, `OCCTCurve3DLength`,
both still listed under `GCPnts_AbscissaPoint`) and nothing else.

**Filed out of this, not fixed here: `Shape.centerOfMass` returns the bounding-box centre (#605).**
`OCCTShapeGetCenterOfMass` was filed under `BRepGProp` and does not use it — it takes the midpoint
of `BRepBndLib`'s bounding box, under a comment claiming `GProp_GProps::CentreOfMass()` "appears to
return (0,0,0) for some shapes". Ground truth on the pinned kernel says otherwise: for a 10-cube at
the origin plus a 2-cube 20 units away, `CentreOfMass()` returns `0.158730159`, the analytic answer
to nine digits, while both `Shape.centerOfMass` and `properties().centerOfMass` return `8.0` — the
bounding-box midpoint, off by 50x. The workaround was reading a *correct* zero (a box centred at the
origin) as the bug it was working around; every existing test uses a box, where the two coincide.

Comment-only change to `OCCTBridge.h` (index block) plus `Scripts/check-bridge-index.py` and
`docs/occtswift-wrapping-gaps.md`; no declaration, no `.mm`, no kernel patch, no xcframework rebuild.

#### The approximation consumers did move when #522 landed, and at the continuity that was supposed to be safe (#572)

Patch `0019` (#522) fixed `AdvApp2Var_ApproxF2var::mma2ce1_` filling both Jacobi-maxima buffers from
the V slot, which made every interior truncation error the surface approximator computed evaluate to
exactly zero. #572 asked whether the five kernel classes that construct a `GeomConvert_ApproxSurface`
and never re-check `MaxError()` moved with it, expecting that they could not have taken a wrong shape
because they run at C1 or C2, above the collapse.

They took a wrong shape. Measured on the real wrapper paths, against a stock and a `0019` kernel
built as matching `-O0` single-TU override links:

| request | before `0019` | after |
|---|---|---|
| the sweep's forced-C1 conversion, tol 1e-4 | reported 1.28e-5 with `isDone`, really **0.876** out | reports 2.547 with `isDone` false, **0.176** out |
| `Surface.toBSpline()` on a trimmed offset, tol 1e-4 | reported 2.09e-5 with `isDone`, really **0.104** out | reports 0.341 with `isDone` false, **0.038** out |
| `GeomLib::ExtendSurfByLength` on a C0-generatrix revolution, tol 1e-7 | reported 9.04e-9 with `isDone`, really **0.626** out | reports 1.887 with `isDone` false, **0.391** out |

Every path that moved moved toward its tolerance, by 1.6x to 5x, and every path that did not move was
already meeting it. None of the three reaches its tolerance even now: they cap out at degree 14 and 16
or 24 segments. What changed is that the degree search climbs to that cap instead of stopping at the
`NDMINU` floor with every candidate scoring zero, and that the caller is now told.

**Continuity was the wrong axis to predict on.** The zeroed error does not only lower the degree
floor, it disables the subdivision decision: `mma2ce2_`'s tolerance test can never fire on a patch
interior, so the fit neither raises its degree nor cuts the patch at any continuity. And C0 *is*
reachable at `GeomConvert_1.cxx:960`, which derives its request from the surface rather than
hardcoding one (`Geom_OffsetSurface` reports `IsCNu(N)` as its basis surface's `IsCNu(N + 1)`, so an
offset of a B-spline that is C1 but not C2 in U asks for C0) and does not collapse there. The axis
that predicts movement is whether the site allows subdivision and whether the input needs any.

Three rows of the issue's own site table did not survive measurement, which a backtrace probe in
`GeomConvert_ApproxSurface::Approximate` settled rather than a source reading:

- **`Shape.sweep` cannot reach `GeomFill_Sweep.cxx:296`.** It uses the two-argument
  `BRepOffsetAPI_MakePipe`, and `ForceApproxC1` is only on the five-argument one.
  `PipeShellBuilder.setForceApproxC1(true)` is the sole lever, and it additionally needs the spine's
  tangent break to sit inside one edge, since `BRepFill_Sweep` splits the sweep at spine vertices.
- **`BRepOffset_Offset.cxx:1626` is dead.** It sits inside `if (Polynomial)`, that argument defaults
  to `false` on every `Init` overload, and the one in-tree caller takes the default. Neither
  `Shape.offset` at any join type nor `Shape.thickSolid` constructs it.
- **`GeomLib.cxx:1517` has no OCCTSwift entry point.** Its reachable-from list is wider than the
  issue recorded (fillets through `ChFi3d`, plus `BRepFill_Sweep`, `BRepOffset_Tool` and `BRepLib`,
  not just "GeomLib conversions"), but every one of those hands it a surface that is already a
  B-spline, which is the branch above the construction.

`ShapeUpgrade_UnifySameDomain.cxx:3629` needs a base surface that closes in a direction it is not
periodic in and is not already a B-spline, which no `BRepPrimAPI` primitive produces (`Uperiod` comes
from `IsUPeriodic()`). An extrusion of a closed but clamped B-spline curve reaches it, and its fit is
exact on both kernels.

Two regression suites pin the paths that moved, both checked against the released pre-`0019` kernel
with `OCCTSWIFT_REMOTE=1`. No production code changes. Reproducer, both transcripts and the probe
census: [`Scripts/repro/572-approx-consumer-sweep/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/572-approx-consumer-sweep).

#### `faces()` dropped a shared face's second orientation, inverting normals on split solids (#614)

#541/#502 converged every face accessor onto one enumeration, `TopExp::MapShapes`. That map
compares with `TopoDS_Shape::IsSame` — "same TShape with the same Locations. Orientations may
differ" (`TopoDS_Shape.hxx:265-271`) — and `NCollection_IndexedMap::addImpl` returns the existing
index and leaves the stored key untouched on a repeat (`NCollection_IndexedMap.hxx:684-710`). So a
face occurring in one shape both `FORWARD` and `REVERSED` collapsed to a single entry carrying
whichever orientation was reached **first**.

That is correct for an index and wrong for a normal, because `OCCTFaceGetNormalAtUV` reverses the
surface normal exactly when the face reads `REVERSED`. Measured on the pinned kernel — a
`BRepAlgoAPI_Splitter` cutting an origin-centred 10mm box (`Shape.box` spans −5..5) with the z=4
plane, the plainest two-body result there is:

| | before |
|---|---|
| face occurrences (`TopExp_Explorer`) | 12 |
| distinct faces (`TopExp::MapShapes`) | 11 |
| shared wall stored as | `FORWARD` (lower solid visited first) |
| its centre / normal | `(0, 0, 4)` / `(0, 0, 1)` |
| dot vs lower solid interior `(0, 0, −0.5)` | **+4.5** — outward |
| dot vs upper solid interior `(0, 0, 4.5)` | **−0.5** — *inward* |

The two occurrences are `IsSame` and not `IsEqual`. A renderer or CAM pass building outward normals
by walking `faces()` got an inward-facing wall for the second body, and any per-face accumulation
silently lost a facet.

That second half was reachable through public API, not just in principle. The face-list CAM helpers
filter on normal-derived predicates, so they inherited the collapse — on the same compound:

| | before | after |
|---|---|---|
| `horizontalFaces()` | **3** | 4 |
| `facesByZLevel()` at z=4 | **1** (upward only) | 2 (one per owning solid) |
| `upwardFaces()` | 2 | 2 (unchanged — opposed normals cannot both face up) |

The upper solid's floor was simply absent.

**Fixed by following the split OCCT itself draws, rather than inventing one.** The kernel already
separates these two jobs and this bridge now matches it:

- **Index → orientation-insensitive.** `TopExp::MapShapes(S, T, M)` is the only type-filtered
  mapping function OCCT publishes and it accepts only the `IsSame` hasher's map — there is no
  oriented overload (`TopExp.hxx:57-60`). Upstream's own canonical stable sub-shape index, the one
  BREP file persistence writes, is that same map (`TopTools_ShapeSet.hxx:192`). `Shape.faces()`
  stays on it, so **no index moves** and #541 is untouched.
- **Normal → orientation-sensitive, read off the traversal.** `BRepGProp::VolumeProperties`, where
  a face's orientation sets the sign of the volume integral, takes it from `ex.Current()`
  (`BRepGProp.cxx:322-325`); and where it deduplicates, it keeps one `IsSame` map *per
  orientation* (`aFwdFMap`/`aRvsFMap`, `BRepGProp.cxx:318-338`) so a shared wall's two sides both
  survive. The oriented indexed map (`NCollection_IndexedMap<TopoDS_Shape>`, deprecated alias
  `TopTools_IndexedMapOfOrientedShape`) is used upstream only for internal algorithm bookkeeping —
  `TopOpeBRepBuild`, `TopOpeBRepTool`, `BOPAlgo_Builder`, `BRepCheck_Wire`, `ChFi3d`,
  `BRepTools_ReShape` — never as
  a public sub-shape enumeration.

New API, all additive:

- **`Shape.orientedFaces() -> [Face]`** — the geometry enumeration: one entry per *occurrence*,
  each carrying the orientation it has in its parent. A shared wall appears twice, once per owner,
  each time with the orientation that makes `Face.normal(atU:v:)` point *out* of that owner. An
  entry's array position is an occurrence number, not a face index, but each `Face` still carries
  the correct `Face.index` into `faces()` — so an occurrence stays addressable by every
  face-index-taking method, and entries sharing an `index` are the sides of one shared face. On any
  shape that shares no face this returns exactly `faces()`, same order, same indices.
- **`Face.orientation -> Shape.Orientation`** — the flag the normal reverses on, so the two sides
  of a shared wall can be told apart.
- Bridge: `OCCTShapeGetOrientedFaces`, `OCCTShapeGetFaceOccurrenceCount`, `OCCTFaceGetOrientation`.
- **`horizontalFaces()`, `upwardFaces()` and `facesByZLevel()` now read `orientedFaces()`** — they
  select on the face normal, so they are geometry consumers. **Contract change:** all three select
  over *occurrences* and so can return two `Face` values carrying the same `Face.index`; dedupe on
  `index` (or use `faces()`) if you need one entry per distinct face. On any shape whose faces are
  not shared all three are unchanged, entry for entry.

  These three are **not** the complete set of normal-derived consumers of `faces()`.
  `AAG.buildGraph()` (`FeatureRecognition.swift:96`) also derives `normal`, `isHorizontal`,
  `isUpward`, `isDownward`, `isVertical` and `zLevel` from `faces()`, and `AAG.detectPockets()`
  selects on them — both public via `Shape.buildAAG()` and `Shape.detectPocketsAAG()`. It is
  **not** fixed here: `faceIndex` and `adjacencyList` are array positions, so moving that graph to
  the occurrence enumeration changes its identity model. Measured on the z=4 split compound,
  `detectPocketsAAG()` returns 2 or 1 depending only on the order the halves were compounded in
  (upward+horizontal nodes `[2, 8]` vs `[2]`), while `upwardFaces()` correctly returns 2 either
  way. Tracked as #642.

  One correction to an earlier draft of this entry: `upwardFaces()` was described as unable to
  repeat an index, on the reasoning that a shared wall's two sides have opposed normals. That
  reasoning holds only when the repeats come from parents bounding *opposite* sides. Reached twice
  through parents imposing the *same* orientation, both entries qualify —
  `Shape.compound([box, box]).upwardFaces()` returns indices `[5, 5]`. Separately,
  `isUpwardFacing` tests `n.z > cos(tolerance)`, so at `tolerance >= π/2` the threshold is
  non-positive and admits faces that do not point up at all, including both sides of a vertical
  shared wall: `upwardFaces(tolerance: 1.6)` returns 10 entries over 9 distinct indices on a
  two-solid split. Both are pinned by tests.

`Shape.faces()`'s own behaviour is unchanged; its documentation now states which of the two
contracts it holds. Per-solid enumeration (`compound.solids` then `.faces()`) was already correct
and is pinned by a regression test so the compound-level fix cannot regress it.

#### The third "closest point on an edge" entry point, and the edge it was measuring to (#580)

`Shape.pointEdgeExtrema(point:edgeIndex:)` makes the same promise `Curve3D.projectPoint` and
`Edge.project(point:)` make, and #539 fixed those two while leaving this one open on a contract
question. That question is now measured, and the answer carried two defects rather than one.

**It reported the minimum over `BRepExtrema_ExtPC`'s extrema, which is not the minimum over the
edge.** Extrema are perpendicular feet, so they exclude the edge's own two ends, and the one in
range can be a *maximum*:

| edge | query point | was | truth |
|---|---|---|---|
| half circle r=5, `[0, π]` | `(0, -6, 0)` | **11** (the far side) | 7.81025 |
| half circle r=5, `[0, π]` | `(3, -4, 0)` (on the circle, off the arc) | **10** | 4.47214 |
| segment `[3, 8]` along +X | `(100, 0, 0)` | `nil` | 92 |
| segment `[3, 8]` along +X | `(0, 0, 0)` | `nil` | 3 |

Over 189 edge/point combinations against a dense brute-force reference, it was right 101 times,
wrong 34 and silent 54. The measured trap: filtering the extrema to the `IsMin` ones scores 101 —
*exactly what it already scored* — because the cases that filter drops are the ones it then leaves
with no candidate at all. Adding the ends is what fixes it.

It now routes through #539's `occtNearestPointOnCurveRange`, so all three entry points reach one
implementation and cannot disagree about the same edge and the same point: 189/189. Repairing in
place with `BRepExtrema_ExtPC::TrimmedSquareDistances` was the smaller diff and tops out at 188 —
`Extrema_ExtPC` does not converge on a BSpline queried from `(2, 0, 0)`, leaving the nearer end to
answer 2 against a truth of 1.996434, where `GeomAPI_ProjectPointOnCurve` finds the interior
minimum.

**`solutionCount` keeps its meaning, its source and its value; the `nil` guard is what changed.**
OCCT models the extrema and the ends as separate things on one object, so "how many extrema were
found" was never the wrong number — the ends were simply never consulted. It is no longer a success
flag: zero now travels to the caller as the informative state it is (the nearest point is an end)
instead of erasing the answer. Note that a *non-zero* count does not mean the nearest point is one
of those feet — the half-circle row above reports `solutionCount == 1`, and that one extremum is the
maximum it used to answer with.

**And the second defect, found while fixing the first.** `edgeIndex` walked a bare
`TopExp_Explorer`, which counts one entry per *occurrence*: a box's 12 edges are 24 occurrences,
since each belongs to two faces. Measured on the pinned kernel, that diverges from the enumeration
`Shape.edges()` and `Shape.edge(at:)` read (#541's contract) **from index 9 onwards** — `edgeIndex:
9` measured to the edge through `(10, 0, 5)` where every other entry point names the one through
`(5, 0, 10)`. Not a shared-sub-shape curiosity like #541's splitter fixture: a plain box.

**Behaviour changes for callers.** `nil` now means only "no such edge index, or an edge with no 3D
curve", matching what #539 settled for `Edge.project(point:)`. `solutionCount` is no longer usable
as a success test — it never was, since the guard made `solutionCount > 0` unfalsifiable for any
non-`nil` result. `edgeIndex` 9 and above name different edges on any shape whose edges are shared
between faces, which is every solid.

New suite `Issue580PointEdgeExtremaTests` (`OCCTAnalysisTests`), 8 tests, plus the pre-existing
`BRepExtremaExtPCTests.pointToEdge` rewritten — its "loop until we find one that gives a valid
extremum" was itself a workaround for this defect, and its `#expect(result.solutionCount > 0)` was
unfalsifiable under the guard it was testing. Proved rather than assumed: reinstating the old
implementation fails 7 of the 10, and the 3 that pass are exactly the deliberately-unchanged ones
(a point with a perpendicular foot, an out-of-range index, and the pre-existing in-range case).
Bridge-only — no kernel patch, no `OCCT.xcframework` rebuild.

#### Five knot-splitting spellings collapse onto two, and the "strictly weaker" duplicate turned out to be the stronger one (#562)

`GeomConvert_BSplineSurfaceKnotSplitting` and `Geom2dConvert_BSplineCurveKnotSplitting` were each
wrapped twice, by two families added three releases apart: `Surface.knotSplitting` and
`Curve2D.splitIndicesAtDiscontinuities` (canonical), and a v0.105.0 set of five
(`Surface.bsplineKnotSplitsU`/`bsplineKnotSplitsV`/`bsplineKnotSplitValues`,
`Curve2D.bsplineKnotSplits`/`bsplineKnotSplitValues`). All five are now deprecated and forward to
their canonical sibling; their five bridge functions are deleted.

**The premise that the five were strictly weaker did not survive measurement.**
`Curve2D.bsplineKnotSplitValues` sized its buffer from the analyzer's own count, where
`splitIndicesAtDiscontinuities` read a fixed 256 entries and took whatever came back — and the
bridge returned the count it had *written*, so truncation was indistinguishable from a curve with
exactly 256 splits. On a cubic with 300 interior knots at multiplicity 3 (302 splits):

| call | before | now |
|---|---|---|
| `splitIndicesAtDiscontinuities(continuity: .c1)` | 256 indices, last `256` | 302 indices, last `302` |
| `bsplineKnotSplitValues(continuity: .c1)` | 302 | 302 |

Forwarding without fixing that would have regressed the deprecated spelling, so
`OCCTCurve2DSplitAtDiscontinuities` now reports the true count and the Swift caller re-reads at it —
the #481 contract every other member of this family already shared. That is a **C-layer contract
change**: a direct bridge caller that treated the return as "how many were written" must now clamp
it. `OCCTBridge` is not an SPM product, so no Swift package is affected.

**What the deleted family carried that the canonical calls did not: the raw knot-table indices.**
The analyzer reports indices and `OCCTSurfaceKnotSplitting` converted them to parameters, so the raw
form was reachable only through `bsplineKnotSplitValues` — which constructed the analyzer three more
times to get it, once per count call and once for the values. `KnotSplitResult` now carries
`uSplitIndices`/`vSplitIndices` alongside the parameters, from the one construction that was already
happening, with `uSplitParams[i] == bsplineUKnot(index: uSplitIndices[i])` by construction. That
answers the issue's open question about whether the index-returning form was worth keeping: the
information was, the three extra entry points were not.

Both deleted values functions also took no buffer capacity at all — each wrote `NbSplits()` entries
into a buffer the caller had sized from a *separate* call, which was only safe because the analyzer
is deterministic. Recorded in the bridge header so it is not reintroduced.

`OCCTBridge.h`'s cross-reference index named none of the three `*KnotSplitting` conversion classes,
which is half of why the double-wrap went unnoticed for three releases — the index is the map used
to find every call site of a class (#510). It gains `GeomConvert_BSplineCurveKnotSplitting`,
`GeomConvert_BSplineSurfaceKnotSplitting`, and a `--- Geom2dConvert ---` section that did not exist
at all, censused by call site across its six classes.

Tests: `Issue562Curve2DKnotSplitDuplicateTests` (`OCCTGeom2dTests`, 4 tests) and
`Issue562SurfaceKnotSplitDuplicateTests` (`OCCTSurfaceTests`, 5 tests). Expectations are absolute —
the fixture's own knot indices and knot table — rather than agreement between the two spellings,
which stopped being evidence the moment one started forwarding to the other. Three injected defects
(written-count truncation, 0-based indices, V continuity collapsed onto U) each fail the tests that
should catch them; the last is caught by the new suite alone and by none of the existing #403 or
#480 coverage.

#### The healing conversions were returning a straight chord through an offset sphere (#570)

[#522](https://github.com/SecondMouseAU/OCCTSwift/issues/522) fixed the kernel writing the U Jacobi
maxima into the V workspace slot, which zeroed every patch's **interior** truncation error, so
`GeomConvert_ApproxSurface::MaxError()` only ever described the boundary iso-curves. That established
the number was wrong. Three kernel healing sites make an accept/reject decision on it, which is where
a zero stops being a wrong diagnostic and becomes a wrong shape — and nobody had checked them, because
every existing test of those entry points uses a box or a cylinder.

Measured against a stock and a patched kernel across ten fixtures, **two of the three returned a
materially wrong surface**:

| entry point | before | after |
|---|---|---|
| `ShapeCustom::ConvertToBSpline` | degree 1, 2 poles, **deviating by 24** | degree 13x10, 14x11 poles, deviating 1.2e-7 |
| `ShapeCustom::BSplineRestriction` | degree 1x7, **one pole in U**, deviating 23.9999 | degree 9x7, 9x8 poles, deviating 5.1e-4 |

The fixture is a face on an offset sphere over its full domain. 24 is the offset sphere's own
diameter: the fit was a straight chord across the full 2π of longitude, accepted as meeting a
`Precision::Approximation()` tolerance of 1e-6. The restriction result was worse — a single pole in a
periodic direction is the whole U direction collapsed to a point, accepted against a 0.01 tolerance
it missed by three orders of magnitude — and it was **identical at C0, C1 and C2**, because the
degree-priority loop degrades continuity toward 0 whenever the requested one cannot meet the tolerance
within `maxDegree`. Requesting C2 was not protection.

Six public entry points reached it, all confirmed against the released kernel:
`Shape.convertedToBSpline()`, `Shape.withSurfacesAsBSpline(offset:)`,
`Shape.convertToBSplineAdvanced(_:offsetMode:)` and all three `bsplineRestriction*` overloads.

**The third site is why the other two were reachable at all.** `ShapeCustom_ConvertToBSpline` does not
build an approximation itself — it calls `ShapeConstruct::ConvertSurfaceToBSpline`, forcing
`GeomAbs_C0` for any offset surface (`ShapeCustom_ConvertToBSpline.cxx:148`, a 1999 workaround for a
hang). So that path did not degrade into the collapsing continuity; it started there. Requesting the
offset surface's own continuity instead returns identical results before and after the patch — the
collapse never reaches C2/C3.

**No code changed.** Patch `0019` already fixes every row above, so what this issue ships is the
measurement, the reproducer at
[`Scripts/repro/570-healing-approx-accept/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/570-healing-approx-accept),
and seven regression tests pinning the corrected values. Run against the last released kernel, six of
the seven fail with exactly the figures above and the seventh — an offset sphere trimmed clear of its
poles, which was never affected — passes.

**The 1999 workaround stays.** Timed on both kernels, the request it suppresses completes in under
5 ms on all seven offset fixtures with no hang, and its results are identical either side of `0019`.
That is not evidence the hang is gone; it is no evidence the hang ever existed for these inputs. The
comment blames a hang, #522 is not a hang, and retiring a hang guard needs a reproduction of the hang.
Post-`0019` the workaround also costs nothing measurable — forced C0 returns a slightly coarser fit
(1.2e-7 against 1.4e-8) that is comfortably inside tolerance either way.

#### Breaking: plate surfaces honour the tolerance they were given (#571)

Six bridge functions build a surface with `GeomPlate_MakeApprox` — `Shape.plateSurface(through:)`,
`plateSurface(constrainedBy:)`, `plateSurface(through:orders:)`, `plateSurface(through:curves:)`,
`plateSurface(points:)` and `Surface.plateThrough(_:)`. Five of them passed `Nbmax = 1` and
`dmax = tolerance * 10`, and between them those two arguments made `tolerance` unenforceable.

`Nbmax` caps the number of Bezier patches, and **1 is the one value that disarms the algorithm**.
`AdvApp2Var_ApproxAFunc2Var::ComputePatches` derives its cut decision from that cap; at 1 every
branch leaves it at "do not cut", so `AdvApp2Var_Patch::CutSense` returns the same answer whether or
not the G0 criterion was satisfied. The criterion is still evaluated and still reported through
`CriterionError()` — it simply cannot act. Measured on a 25-point wavy plate at `tolerance: 0.01`:
the criterion came back at `0.098` against its own `0.01` threshold, violated, and the surface was
returned unchanged. `Nbmax = 2` or more fits the same plate to `0.0044`.

`dmax` sets that threshold, as `seuil = max(Tol3d, 10 * dmax)`. `tolerance * 10` therefore asked the
criterion to accept **100x the tolerance the caller requested** — and it is not merely dead weight
once subdivision is allowed: at `Nbmax = 20` that value reproduces the bad single-patch answer
exactly, while `tolerance * 0.1` gives the good one. `tolerance * 0.1` makes `10 * dmax == Tol3d`,
so the threshold is the caller's own tolerance. It is the value the sixth site already used.

All six now share one helper (`occtPlateApproxSurface`) with one contract. What changes for callers:

| | before | after |
|---|---|---|
| worst deviation, 25-point wavy plate at `tolerance: 0.01` | `0.0724` (7.2x the request) | `0.0032` |
| control points in U | 9 (a single degree-8 patch) | 16 |
| `plateSurface(through:)` vs `plateSurface(points:)`, same input | 22x apart on accuracy | identical |

Surfaces from these six entry points therefore **move**, and callers who stored derived geometry
should regenerate it. Two related contracts are now explicit rather than implicit:

- **`maxSegments: 1` is clamped to 2.** `Shape.plateSurface(points:maxSegments:)` is the one entry
  point that exposes the cap, and 1 there is not a coarser request but the value that voids
  `tolerance` entirely.
- **The approximation's continuity is passed explicitly, and stays `GeomAbs_C1`.** It is the
  continuity of the joins *between* patches, a different axis from the constraint order handed to
  `GeomPlate_PointConstraint`/`GeomPlate_CurveConstraint` — so `plateSurface(constrainedBy:continuity:)`
  still applies the caller's `.g0`/`.g1`/`.g2` to the boundary constraints only, and does not forward
  it to the fit. Only `C0`, `C1` and `C2` are accepted there at all: `G1`, `G2`, `C3` and `CN` each
  throw `AdvApp2Var_ApproxAFunc2Var : UContinuity Error` (measured), which is why
  `occtGeomAbsFromSurfaceContinuity` — whose order-1 answer is `GeomAbs_G1` — must not feed it.

**This is not fallout from [#522](https://github.com/SecondMouseAU/OCCTSwift/issues/522), though
that is what prompted the audit.** `GeomPlate_MakeApprox` is the one consumer of the defective
approximator that does not go through `GeomConvert_ApproxSurface`, so it took #522's always-zero
interior error without appearing in any census built by grepping for that class. Fingerprinting the
control net of 54 plate fits either side of the `0019` patch — a stock override-link against the
patched kernel — shows **every one identical**. Only the reported `ApproxError()` moved, rising
1.03x to 5.37x as the interior contribution is counted for the first time. At the implicit `C1`
default the degree floor is already 8, so #522's collapse could not reach these sites, exactly as
#571 predicted.

Two plate suites carrying `.disabled("Plate surface operations cause segfault in OCCT")` are
re-enabled: 18 tests, 13 consecutive clean runs, and they pass against the pre-fix arguments too, so
the annotation was stale rather than describing something this change cured. They cover two of the
six sites. Reproducers and both transcripts: [`Scripts/repro/571-plate-approx-contract/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/571-plate-approx-contract).

#### The cross-reference index stops naming 135 symbols that never existed (#510)

`OCCTBridge.h` opens with a hand-maintained index mapping each wrapped OCCT class to the bridge
symbols that wrap it. It is the map you use to find every call site of a class, and 135 of its
symbol references named nothing at all — so a re-audit by symbol name returned zero hits and read as
"no call sites, nothing to check". That is not hypothetical: it is how #484's fourth, still-unpatched
`ShapeFix_Face` call site was missed. Every one is now rewritten against a measured census of which
bridge functions actually reference the class, or removed where no wrap exists:

| shape of the staleness | example | resolution |
|---|---|---|
| renamed symbol | `BRepFeat_Builder → OCCTBRepFeatFuse/Cut` | `OCCTBRepFeatBuilderFuse`, `OCCTBRepFeatBuilderCut` |
| wrong prefix convention | `XCAFDoc_ShapeTool → OCCTXCAFShape*` | the `OCCTDocument*` assembly surface — 66 call sites, and no `OCCTXCAFShape*` symbol has ever existed |
| named one of many | `GeomLProp_CLProps → OCCTGeomLPropCurve` | `OCCTGeomLPropCLProps` plus the ten curvature/tangent/normal functions that share the class |
| aspirational | `ShapeFix_Shell → OCCTShapeFixShell` | entry removed; the gap is recorded in [`docs/occtswift-wrapping-gaps.md`](occtswift-wrapping-gaps.md) |

`ShapeFix_Shell` was the only entry with no wrap behind it. `TDataStd_NamedData → OCCTLabelNamedData*`
looked identical — no such symbol, no obvious neighbour — but is wrapped, as `OCCTDocumentNamedData*`,
through two lowercase static helpers. A census that only attributes a class to the enclosing
`OCCT`-prefixed function cannot see that, so "no call site found" is a prompt to grep by hand, not a
verdict.

**The checker that was supposed to prevent this could only see 129 of the 135.** `check-bridge-index.py`
split each entry on commas and slashes and required every piece to be a bare symbol. Anything else was
skipped without a word: continuation lines of a wrapped entry, headings naming several classes at once
(`RWObj_CafReader/Writer`), and any name carrying an annotation (`OCCTShapeFill* (Shape.fill)`). It now
checks every `OCCT`-prefixed name anywhere in an entry, which raised what it actually inspects from 454
symbols to 660 and turned up the remaining six — including
`TDataStd_Integer/Real/AsciiString → OCCTLabel{Set,Get}Integer/Real/AsciiString` and
`TDataStd_IntegerArray/RealArray → OCCTLabel*Array*`, naming an `OCCTLabel*` family that does not exist
anywhere in the bridge, and `XCAFDoc_ColorTool → OCCTXCAFShape*Color*`, a second sighting of the
`OCCTXCAFShape*` prefix that has never named anything. `--self-test` injects a fabricated name in each
of the five shapes an entry can take and asserts it is reported; the parser this replaces catches one of
the five and calls the other four clean. The sixth is #508's `GC_MakeLine2d → OCCTGCE2dMakeLine*`, whose
real wrappers (`OCCTCurve2DMakeLineThroughPoints`, `OCCTCurve2DMakeLineParallel`) were already two lines
away in the same file.

A second defect class remains, filed as #565: the checker verifies that a named symbol *exists*,
not that it wraps the class the entry files it under. A mis-attributed entry that happens to name a real
symbol from a neighbouring class is still invisible, and it misleads exactly the way a fabricated one
does.
#### The cylindrical-hole drill selected parts of the cut result, not parts of its tool (#532)

Kernel patch `0020`. Every `BRepFeat_MakeCylindricalHole` mode that chooses which piece of the
drilling tool to keep — `PerformThruNext`, `PerformUntilEnd`, the ranged `Perform(Radius, PFrom, PTo)`
and `PerformBlind` — drove `BRepFeat_Builder` with `SetOperation(Fuse)`, i.e. `BOPAlgo_CUT`, and then
called `PartsOfTool()`. That method collects the solids of the builder's shape, which holds the tool
split by the object only after the **COMMON** pass; after a CUT it is the finished workpiece. So the
selection loops compared barycentres of bored plates and registered those plates as "kept parts of the
tool", and `PerformResult()` then took the kept-parts path with a keep set containing no tool part at
all. The caller got the input back with the cylinder's faces imprinted on it — reported as
`BRepFeat_NoError` throughout.

`BRepFeat_Form` and `BRepFeat_RibSlot`, the kernel's other two users of the same builder, both call
the two-argument `SetOperation(myFuse, bFlag)` with `bFlag` true. The patch is that call at the four
part-selecting sites. `Perform(Radius)` selects no parts and is untouched, which is why `.throughAll`
was the one extent that already drilled a stack correctly, and why the defect read as "multi-body"
rather than "part selection".

Two corrections to how #532 was originally scoped. **`PerformBlind` is affected too** — it was not
named because the report came out of #496, which had newly wrapped only the other two extents. And
the trigger is not "more than one body": it is "the cut result has two solids", which **a single
solid reaches** — an 8mm bar drilled at r = 5 is severed by its own bore, and every part-selecting
mode then removed nothing from it.

Measured on a compound of two 50 × 50 × 20 plates on the drill axis, where one bore removes
1570.7963:

| call | before | after |
|---|---|---|
| `.throughAll` | 3141.5927 | 3141.5927 |
| `.untilEnd` | **0.0000** | 3141.5927 |
| `.thruNext` | 1570.7963 | 1570.7963 |
| `.blind(depth: 20)` | **0.0000** | 1178.0972 |
| `.range(from: 0, to: 70)` | **0.0000** | 3141.5927 |
| `.range(from: 0, to: 30)` | 1570.7963 | 1570.7963 |

A single plate is byte-identical before and after — its cut result was one solid, so the branch never
ran. A channel and a hollow box, both one solid with two spans on the axis, give the same answer
before and after while the selection loop goes from one part to two real tool parts.

**One behaviour change beyond the bug.** A radius so large the bore swallows the whole solid used to
be `.invalidPlacement` for `.untilEnd` and `.thruNext`: under CUT the oversized tool emptied the
builder's shape, so `nbparts` was 0 and the "the tool meets nothing" guard fired. Under COMMON
`nbparts` is 1 and both extents now return the empty result `.throughAll` and
`drilled(at:direction:radius:depth:)` always returned. The #496 divergence "through-all status is a
false green for the thru-next drill" was that accident, not a contract, and its test now pins the
converged answer.

`Issue532CylindricalHolePartSelectionTests` (`Tests/OCCTModelingTests`), 7 tests, three of which
deliberately cover geometry the fix must not disturb. Run against the last released kernel first: the
four that pin the defect fail there and the three non-regression tests pass, which is the proof the
suite is measuring the patch. Reproducer and full before/after tables in
[`Scripts/repro/532-cylindrical-hole-part-selection/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/532-cylindrical-hole-part-selection);
a second, unreachable-as-written defect in `PerformThruNext`'s fallback brace nesting is reported
there rather than changed.

#### One edge-index contract and one radius law for all five fillet entry points (#520)

The five `BRepFilletAPI_MakeFillet` edge-list functions disagreed on what an edge index means, on
what an unresolvable one does, and two validated no radius at all. Settling those three questions
turned up two defects the issue did not know were there.

**`filletedVariable` never applied its radius profile.** It mapped each relative parameter onto the
edge's own curve parameter range and called `SetRadius(radii[i], param, 1)`. There is no
`(Real, Real, Integer)` overload of `SetRadius`, so `param` was truncated to an `int` and taken as
the *contour* index; the profile was discarded and the caller got a constant radius. Measured on a
20mm box, edge 0:

| call | before | now |
|---|---|---|
| `filletedVariable(edgeIndex: 0, radiusProfile: [(0, 1.0), (1, 3.0)])` | volume 7995.707963, **exactly** the constant-1.0 result | 7981.047467, the profile OCCT was asked for |
| `filletedVariable(edgeIndex: 0, radiusProfile: [(0, 1.0), (0.5, 4.0), (1, 1.0)])` (30mm box) | 26993.561945, exactly the constant-1.0 result | 26947.284023 |

**Two live SIGSEGV paths.** A contour added by the law-taking `Add(edge)` overload that never
receives a radius crashes `Build()`. It is an OS signal, so the bridge's `catch (...)` never saw it
and no `nil` could come back. Both routes were reachable from Swift: `filletEvolving` with an empty
`radiusPoints` (the old code took neither of its two branches for a count of 0), and
`filletedVariable` on any edge whose curve parameter range does not start at 0, where every
truncated contour index exceeded `NbElements()` and every `SetRadius` was silently dropped. Box
edges all start at 0, which is why the existing tests never saw it; the edges a boolean cut
produces do not (6 of the 21 edges of one box cut by another).

Both radius-law entry points now resolve their edges through `occtFilletAddEdges` and apply their
profile through the new `occtFilletSetRadiusProfile` (`OCCTBridge_Internal.h`), the same
`SetRadius(UandR, contour, 1)` call `OCCTShapeHistoryFromFilletEdgeVariable` was already making
correctly two functions away. So the same profile now gives the same shape through either entry
point, which is pinned by a test.

**Three contract changes.**

*Radius and parameter validation on the two radius-law functions.* Neither inspected a single
element before. This is not the redundant guard #489 measured for `Add(radius, edge)`: through the
profile overload a negative radius is not caught by OCCT at all, reporting `IsDone() == 1` and
handing back a shape `BRepCheck_Analyzer` rejects. The parameters are checked against the `[0, 1]`
contract both doc comments already stated, and required to strictly increase, because OCCT
renormalises a 3+ point profile with `(U - Uf) / (Ul - Uf)`: equal parameters divide by zero, and
descending ones silently reverse the law (7960.426609 against 7963.730821 for the ascending
equivalent).

*An index that names no edge of the shape rejects the call.* Three of the five skipped it and
reported success, filleting fewer edges than the caller asked for — a request honoured in part,
presented as honoured in full, the same defect class as #439/#442/#443. The other two already
rejected, so this is what makes the family agree.

| call | before | now |
|---|---|---|
| `blendedEdges([(0, 2.0), (99999, 2.0)])` | edge 0 filleted, reported as success | `nil` |
| `filleted(edges: [ownEdge, edgeOfAnotherShape], radius: 1.0)` | `ownEdge` filleted, reported as success | `nil` |
| `filletedWithFullHistory(radius: 1.0, edges: [0, 99999])` | edge 0 filleted, reported as success | `nil` |

*`EvolvingFilletEdge.edgeIndex` is 0-based*, matching `Edge.index` and every sibling; it was the
one 1-based edge index in the family. Reinterpreting the same numbers would have quietly filleted
the neighbouring edge for every existing caller, so the old spelling is
`@available(*, unavailable)` instead: `init(edgeIndex:radiusPoints:)` fails to build with a message
naming the base change, and `init(edge:radiusPoints:)` takes the `Edge` itself, the idiom
`filleted(edges:radius:)` already uses. The four call sites in this repo's own tests failed exactly
that way and were migrated.

Ground truth for all of the above is in
[`Scripts/repro/520-fillet-edge-index-contracts/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/520-fillet-edge-index-contracts).
The new `Issue520FilletContractTests` suite was run against unmodified code first (#489's lesson):
10 of its 13 then-runnable cases failed, 1 took the test process down with a SIGSEGV, and 2 passed —
one of those for the wrong reason, since a 0-based index was out of range under the 1-based
contract. Each guard was then re-checked by injecting the mistake back: the index guard fails 3
tests, the radius guard 2, the parameter guards 2, the empty-law guard SIGSEGVs 3 runs out of 3, and
restoring the truncating loop both fails the profile test and SIGSEGVs the re-parameterised-edge
test.

Bridge-only: no kernel patch, no xcframework rebuild, nothing filed upstream — passing a `double`
where OCCT's signature takes an `int` is our defect, not OCCT's. `Scripts/count-operations.py` now
skips `@available(*, unavailable)` declarations, which are retired spellings rather than entry
points; the total stays 4295. The skip-an-out-of-range-index idiom survives outside this family, in
`OCCTShapeHistoryFromChamferEdges`, `OCCTShapeOffsetPerFace` and the 2D fillet/chamfer vertex
functions; those are a separate family and are left for their own issue rather than widened into
this one.

#### Breaking: one meaning for a face index (#541)

A face index in this API is now one thing: **a 0-based position in the enumeration
`Shape.faces()`, `Shape.faceCount` and `Shape.face(at:)` all read** — `TopExp::MapShapes`, one
entry per distinct face (`TopoDS_Shape::IsSame`). It used to be three things, and the three
disagreed.

`Shape.faces()` drove its own bare `TopExp_Explorer`, one entry per **occurrence** in the topology
tree, and wrote the array position into `Face.index`. `faceCount` / `face(at:)` and most
index-taking entry points read the deduplicated map. A handful read that map **1-based**.

This is the case #502 (Pass 1b's sub-shape traversal fix) deliberately left, because face indices
are an addressing token the API hands out and takes back, and auditing every consumer is not a
one-line change.

**The defect was worse than #541 reported.** Measured on the pinned kernel
([`Scripts/repro/541-face-index-contract/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/541-face-index-contract)),
fifteen fixtures walked both ways. The issue's reproduction is a hand-built
`Shape.compound([face, face])`, but **one ordinary modelling operation produces the divergence**: a
single `BRepAlgoAPI_Splitter` run cutting a box with a plane leaves two solids sharing the one cut
face — 12 occurrences over 11 distinct faces. And because that duplicate is not the last
occurrence, every index after it is shifted:

| index | `faces()` | `face(at:)` |
|---|---|---|
| 0–9 | the same face | the same face |
| **10** | **one face** | **a different face** |
| 11 | a face | `nil` |

So a caller selecting a face from `faces()` and handing it to `drafted(faces:)`,
`shelled(openFaces:)` or `withoutFeatures(faces:)` — all map-backed — drafted, opened or deleted **a
face it had not selected**, with no error. #541's reported symptom (`face(at:)` returning `nil` for
an index `faces()` handed out) turns out to be the milder half.

The control matters as much: across the ten fixtures that share no face — primitives, a hollow
solid, both booleans, a compsolid, a sewn sheet, two placements of one body — the two enumerations
are **identical at every index**, compared face-by-face rather than by count. Converging them moves
nothing on any shape that does not share a sub-shape.

**What changed.** `OCCTShapeGetFaces` reads `occtMapSubShapes`. The fourteen entry points that
walked their own explorer to resolve an index (`OCCTShapeClassifyPoint2D`,
`OCCTShapeFaceDomainEdgeCount`, `OCCTShapeBuildLoops`, `OCCTShapeDraftModification`, the three
`BRepExtrema_Ext*F` extrema, the three `LocOpe` splitters, three `ShapeFix`/`BRepAlgo` healers and
`OCCTBRepCheckSubShapeValid`) read `occtFaceAt` / `occtEdgeAt` / `occtSubShapeAt` instead. The
1-based entry points and index outputs moved to 0-based. Two new helpers in
`OCCTBridge_Internal.h` carry the contract in one place.

**Six silent behaviour changes**, each recorded in [`SEMVER.md`](SEMVER.md) with its migration:

```swift
// faces() no longer double-counts a shared face
let pieces = block.split(by: knife)!            // one splitter run
let assembly = Shape.compound(pieces)!
assembly.faces().count      // was 12, now 11 — and now equal to assembly.faceCount
assembly.faces().allSatisfy { assembly.face(at: $0.index) != nil }   // was false, now true

// adjacency indices are 0-based, so they index face(at:) directly
for i in box.adjacentFaces(forEdge: edge) {
    box.face(at: i)!        // was box.face(at: i - 1)
}

// the buildWires sentinel moved off 0, which is a real face
box.buildWires(faceIndex: -1)   // every edge of the shape (was 0)
box.buildWires(faceIndex: 0)    // face 0's edges (was rejected)
```

Also 0-based now: `splitByWireOnFace(_:faceIndex:)`, `offsetPerFace`'s `faceOffsets` keys (where an
out-of-range key now fails the call instead of being silently skipped — the same silent-success
failure #497 fixed for defeaturing), `EvolvingFilletEdge.edgeIndex` (the one fillet/chamfer entry
point in the file that was 1-based), the `Poly_Connect` mesh family's `faceIndex` (their triangle
and node indices stay `Poly_Triangulation`-native 1-based, as do the triangle indices they return),
and `Selector.PickResult.subShapeIndex`, whose "whole shape" sentinel moved from `0` to `-1`.

**`Shape.contents` was left counting what it counts, and is now documented as doing so.**
`ShapeAnalysis_ShapeContents` is a fourth answer and a fifth: `NbFaces` tracks the explorer, while
`contentsExtended()`'s `nbSharedFaces` strips the location before deduplicating, so unlike `IsSame`
it also collapses two placements of one face. On a compound of a box with a `moved(dx:dy:dz:)` copy
of itself the three read 12 / 12 / 6. It answers a different question — a complexity metric — and
its docs now say so, with the warning that none of its numbers is an index bound.

Regression tests in `Tests/OCCTTopologyTests/Issue541FaceIndexContractTests.swift`; run against the
unfixed bridge, seven of the ten failed and the three controls passed. Full suite green (4880
tests); the only fallout was one existing test whose helper subtracted 1 from
`adjacentFaces(forEdge:)`, and the selector tests that asserted the old sentinel.

Not an upstream defect — both OCCT primitives behave exactly as documented, and the kernel is not
involved in the base convention at all. No kernel patch, no xcframework rebuild.

#### Every sampling entry point now bounds the count a caller can supply (#558)

#479 bounded two entry points and recorded that "the same shape is live at fourteen other sampling
entry points". Measuring the family before fixing it found **twenty-eight**, not fourteen: a caller
supplies a count, it sizes a Swift allocation, and it is then cast to the `int32_t` the bridge takes
its count in. `[Double](repeating:count:)` traps on a negative and `Int32(_:)` traps past
`Int32.max`, so both ends abort the process rather than returning the documented empty value.

Measured one case per process, since a trap takes the whole harness down with it. Every one of the
28 either trapped or ground on an unservable allocation past 30 s at `Int(Int32.max) + 1`, and 20 of
them trapped on `-1`. The fourteen the issue did not name are `Edge.quasiUniformParameters(count:)`
(the same method, on the same `GCPnts_QuasiUniformAbscissa`, as the `Curve3D` one that *was* named),
`Curve3D.samplePoints(first:last:maxPoints:)`, `Surface.drawGrid(uLineCount:vLineCount:pointsPerLine:)`,
`Shape`'s `edgePolyline`, `allEdgePolylines`, `edgePoints`, `contourPoints`, `uIsoCurvePoints`,
`vIsoCurvePoints` and `coonsAlgPatch`, `Wire.orderedEdgePoints(at:maxPoints:)`, both `MedialAxis`
drawers, and `QuadricIntersection.coneSpherePoints`.

The ceiling moves out of `ArcLengthCurveAdaptor` into **`Sampling.maximumSampleCount`**, still
10,000,000 and still the measured number #479 justified. `EdgeCurve.maximumSampleCount` /
`WireCurve.maximumSampleCount` keep working and resolve to it, so nothing #479 shipped breaks.

The bound is not one rule, because the parameters do not mean one thing:

| kind | parameter | decision | why |
|---|---|---|---|
| **request** | `count`, `pointCount`, `sampleCount` | rejected outside `2...ceiling` (empty / `nil`) | the caller asked for exactly this many; returning fewer is the silent-coarsening defect #501 found |
| **capacity** | `maxPoints` on an adaptive sampler | clamped into `0...ceiling` | the deflection criterion decides the count and the capacity only truncates, so clamping returns the *same* points, not coarser ones |
| **grid** | `uCount`×`vCount`, `evalU`×`evalV`, `(uLineCount + vLineCount)`×`pointsPerLine` | the **product** is bounded, and each factor checked on its own | see below |

Two things the measurement changed about the fix as the issue specified it:

- **The issue recorded `Surface.drawMesh` as returning `.empty` for a negative count. It does, but
  only when the negative goes to both factors.** `(-1) * (-1)` is `1`, a perfectly plausible total,
  so the allocation succeeds and the bridge rejects the counts on its own. `drawMesh(uCount: -1,
  vCount: 3)` is `-3` and aborts the process. Bounding only the product would have left that live,
  so each factor is checked individually as well. Confirmed by injection: with the per-factor check
  removed, the new suite aborts with `Fatal error: Can't construct Array with count < 0` at exactly
  that case. The same masking applies to `Surface.drawGrid` and `MedialAxis.drawAll`.
- **`MedialAxis.drawArc`'s parameter is named `maxPoints`, but it is a request.** The bridge does
  `numPoints = maxPoints` and fills the buffer exactly, so it returns precisely the count asked for
  (and nothing at all below 2), unlike the genuinely adaptive samplers that share the name. It was
  written as a capacity first; the verification sweep caught it returning a full 10,000,000 points
  for a clamped absurd input, which is the coarsening the clamp was supposed to be immune to. It
  rejects instead.

The multiplications are overflow-checked rather than assumed in range: `Int` wraps into a trap of
its own well before the ceiling is reached, and `drawGrid`'s two line counts are bounded before
being added for the same reason.

Regression suite: `Tests/OCCTCurveTests/Issue558SamplingCountBoundsTests.swift`, 21 tests. They run
in-process only because the fix is what lets them: before it, every assertion in them would have
aborted the test harness rather than failing. They compare `.count == 0` rather than reading
`.isEmpty` because Swift Testing prints the captured sub-expression on failure, and a regression
returning 10 million points would print all 10 million (measured at over 5 GB while injecting a
deliberate bug to confirm the suite catches it; #479 hit the same hazard at 880 MB).

#### The closest point on a curve is now on the curve (#539)

`Curve3D.projectPoint(_:precision:)`, `Curve3D.distance(to:precision:)`, `Edge.project(point:)` and
`Edge.distance(to:)` all promise the closest point, and none of them delivered it. They had picked a
different OCCT call each, and each call is wrong in its own way about a curve that has ends:

| | `ShapeAnalysis_Curve::Project` (was behind `Curve3D`) | `GeomAPI_ProjectPointOnCurve`, ranged (was behind `Edge`) |
|---|---|---|
| segment trimmed to `[3, 8]`, point `(100, 0, 0)` | parameter 100, **distance 0** | no answer (`nil`) |
| half circle r=5, point `(0, -6, 0)` | **distance 1** (the far half) | **distance 11** (the far side) |
| point on the full circle, off the arc | **distance 1.6e-15** | **distance 10** |
| parabola over `[0, 2]`, point `(20, 0, 0)` | **distance 20** (the vertex) | **distance 20** |

Truth for those four rows: 92, 7.81, 4.47, 19.60. A `distance < tolerance` proximity test read the
first three as "the point lies on the curve".

Three distinct defects, not one. `ShapeAnalysis_Curve::Project` solves on the *basis* curve for an
analytic type, so a parameter outside the domain comes back as though it were on the curve — passing
the range does not help, the 7-argument overload documents itself as *extending* it, and its
`AdjustToEnds` flag changed no measured answer either way. `GeomAPI_ProjectPointOnCurve` honours the
range but returns extrema rather than minima, so the only extremum in range can be a maximum, and it
finds nothing at all when the nearest point is an end. And on a parabola or hyperbola both answered
with the worst point in range — the defect a parameter clamp, which is what the issue proposed,
would not have touched.

Both entry points now share one `occtNearestPointOnCurveRange`, which takes the minimum over three
candidate sources: `ShapeAnalysis_Curve`'s answer where it landed inside the range, every extremum
`GeomAPI` finds inside the range, and the range's own ends. Correct on all 51 curve/point
combinations swept against a dense brute-force reference (line, circle, ellipse, parabola,
hyperbola, Bezier, BSpline and offset curves, trimmed and not), where `ShapeAnalysis_Curve` alone
was right on 37 and `GeomAPI` alone on 25. Periodic bases need no special handling and get none:
`Geom_TrimmedCurve` normalises its own domain and `Project` returns the representative nearest it,
verified over ten seam-crossing and beyond-one-period cases.

**Behaviour changes for callers.** `Edge.project(point:)` and `Edge.distance(to:)` stop returning
`nil` for a point with no perpendicular foot — every one of a box's twelve edges used to answer
`nil` for a corner probe outside the box. `nil` now means what the documentation always said it
meant: an edge with no 3D curve. Ordinary in-range projections, unbounded curves and closed curves
are unchanged, which is why no pre-existing test moved: every one of them queried a point that has a
perpendicular foot.

`Curve3D.nearestParameter(to:)` (#500) is deliberately untouched and still reports `nil` for the
points above. The two are different questions — the nearest point, which exists for every query
point, versus the nearest perpendicular foot, which does not — and `Issue500Curve3DNearestParameterTests`
pins the distinction, updated here to the corrected answer it recorded as-is.

**Measured here, fixed in #580.** `Shape.pointEdgeExtrema(point:edgeIndex:)` (`BRepExtrema_ExtPC`) is
a third entry point documented as finding "the closest point on the edge" with the same defect: 11
for the half-circle query above, and `IsDone()` false for both trimmed-segment queries. It was left
out of this change because fixing it meant first deciding what its `solutionCount`, the extrema
count it deliberately exposes, should say when the answer is an end — so that decision was measured
here rather than left open, and acted on in #580 above, in the same release.

New suite `Issue539NearestPointOnCurveTests` (`OCCTCurveTests`), 12 tests. Proved rather than
assumed: reinstating the two original implementations fails 9 of the 12, and the 3 that still pass
are exactly the three asserting what was meant to stay the same.

#### One defeaturing operation, not one per OCCT layer (#536)

`Shape.removeFeatures(faces:)` and `Shape.defeature(faces:)` took the same arguments, returned the
same type, and neither doc comment mentioned the other. They were the same operation: `defeature`
drove `BRepAlgoAPI_Defeaturing`, `removeFeatures` drove `BOPAlgo_RemoveFeatures`, and
`BRepAlgoAPI_Defeaturing::Build` is a 30-line forwarder that hands its shape, its faces, its history
flag and its parallel flag to a `BOPAlgo_RemoveFeatures` member and returns that member's result —
with `Modified`, `Generated`, `IsDeleted`, `HasModified`, `HasGenerated`, `HasDeleted` and `History`
all one-line delegations to the same member. The bridge had wrapped both layers of one algorithm and
given each its own Swift name. This is the sixth spelling of the operation #497 consolidated, left
out of that pass because it reached a different OCCT class.

**Measured, not read off the source.** A deprecation has to answer "is there any input on which they
can differ", not "do they agree on a box", so both paths were driven exactly the way their bridge
wrappers drove them — including the different completion tests, `IsDone()` against `!HasErrors()` —
over every face of a filleted box in turn, a through hole, a boss, two holes at once, and the
requests that fail (no faces, a face from another shape, a mixed request, an input that is not a
solid, the same face twice). Identical in every case, compared as full BREP serialisations rather
than volumes. The option defaults the forwarding depends on match too (`myFillHistory` true on both
constructors, `myRunParallel` false from the shared `BOPAlgo_Options` base), which is what made the
two unconfigured objects the same object. Probe and full output at
[`Scripts/repro/536-defeature-removefeatures-unify/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/536-defeature-removefeatures-unify).

`defeature(faces:)` survives — it is the class OCCT documents for application use, it is where the
history-carrying sibling already lives, and since #497 it shares one bridge skeleton with the rest of
the family. `removeFeatures(faces:)` is deprecated and forwards to it, with a `renamed:` fix-it.
`OCCTBOPAlgoRemoveFeatures` is deleted rather than kept for a future caller: `OCCTBridge` is a
target, not a product, so nothing outside this package can link it, and #506 measured what keeping an
orphan costs — it freezes whatever contract it had, and this one had drifted already, silently
skipping a null entry in the faces array where the surviving path fails the call. That particular
drift was not reachable from Swift, since `[Shape]` has no null elements; it is what an orphaned copy
looks like after one side gets a fix, which is the argument against keeping it.

**Not fixed, and now written down.** A face that is not part of the input is dropped from the request
rather than refused: a request mixing one real face with one foreign face succeeds, removes the real
one, and emits no warning at all, while a request of nothing but foreign faces fails because nothing
is left to remove. That is more forgiving than the index-addressed `withoutFeatures(faces:)`, which
since #497 fails the whole call on one bad index. Making the two agree is not a line of validation:
`AddFaceToRemove` takes a `TopoDS_Shape` and its own documentation calls it "the shape to extract the
faces for removal", and the kernel duly accepts a compound, a shell or the whole input solid as a
face carrier — measured. Deciding what a membership rule does with those is its own question, so it
was filed separately as #578 and settled there; the behaviour was documented on `defeature(faces:)`
in the meantime, along with the fact that membership is identity, not geometry (a face measured off a
separately built but identical shape is foreign).

New suite `Issue536DefeaturingSpellingsTests` (`OCCTModelingTests`) compares the two spellings face
by face on three fixtures, pins all four spellings of one removal against each other, and pins the
membership contract above. Proved against three injections rather than assumed: a forwarder that
returns its input unchanged, one that drops the last requested face, and a `defeature` that reports
failure as the input shape each fail the tests that cover them, and only those.

#### Breaking: one resolution behind the adaptor-backed local properties too, and the raycast normal it was quietly erasing (#529)

#494 converged all 28 `GeomLProp_SLProps` / `GeomLProp_CLProps` / `GeomLProp_CLProps2d` constructions
in the bridge onto `Precision::Confusion()` and recorded the `BRepLProp_*` half as a separate job on
the grounds that it is "a different class family". It is not. In OCCT 8.0 `BRepLProp_SLProps.hxx` is
nine lines long:

```cpp
using BRepLProp_SLProps = GeomLProp_SLPropsBase<BRepAdaptor_Surface>;
```

The same header-only template `GeomLProp_SLProps` aliases, over an adaptor instead of a
`Geom_Surface` handle. Same `Resolution` argument, same meaning, so the 18 sites passing a literal
`1e-6` were asking whether a quantity exists at a threshold a decade looser than the sites they sit
beside. Measured on the pinned kernel, that decade is exactly where they disagreed: on a cone face
approaching its apex, `Shape.faceLPropMeanCurvature(u: 0, v: 1e-6)` returned `0` — its spelling of
"undefined" — where `Face.meanCurvature(atU: 0, v: 1e-6)` returned `-8.66e5` for the same point of
the same face, and the disagreement ran down to `v = 3e-7`. All 18 now build through
`occtFaceLocalProps` / `occtEdgeLocalProps`, alongside #494's `occtSurfaceLocalProps` and friends.

**The census in the issue was three counts off**, in the direction of more work rather than less:

| the issue says | measured |
|---|---|
| 19 literal-`1e-6` sites, 16 in `OCCTBridge_Properties.mm` | 18, of which 15 are in `Properties.mm` |
| a different class family, so #494's factories are not reusable | the same two templates, one adaptor argument apart |
| all three `Topology.mm` sites decide face *orientation*, not reported values | one of them is `OCCTFaceGetNormal`, which backs `Face.normal` and every `isHorizontal` / `isUpwardFacing` / `isVertical` predicate |
| `OCCTShapeRaycast`'s caller-supplied tolerance is "not obviously wrong" | it is the worst site of the 19 (below) |

**`raycast(tolerance:)` was erasing its own normals.** `OCCTShapeRaycast` forwarded the caller's
tolerance twice: to `IntCurvesFace_ShapeIntersector::Load`, where it is the intersection distance it
is documented as, and to `BRepLProp_SLProps`, where it becomes the resolution — which
`CSLib::Normal` uses as a **sine** tolerance on the angle between the two parametric directions.
That quantity is dimensionless and saturates. Measured: `raycast(tolerance: 1.0)` against a sphere
reported no normal for either hit, so both fell back to `(0, 0, 1)`; at `5.0` a box's *downward*
face came back pointing up. The intersection tolerance now stops at `Load`. `RayHit` also gains
`normalDefined`, because the `(0, 0, 1)` fallback is otherwise indistinguishable from a real upward
normal at a genuinely singular hit point. (Additive: `RayHit`'s memberwise initialiser is internal,
so no caller constructs one.)

**The curvature-inversion defect #494 found is on this side too, and `1e-6` made its window a decade
wider.** `LProp_CurveUtils::Curvature()` returns `RealLast()` to mean infinite curvature at a cusp,
on a path that never assigns the `myCurvature` field; `CentreOfCurvature()` tests only
`|Curvature()| <= resolution`, which the sentinel passes, and then divides by that unassigned field.
`Normal()` rejects the sentinel by name and throws; `CentreOfCurvature()` hands back a point of
`(nan, inf, nan)` as a success. Both edge entry points that invert a curvature now gate on
`occtCurveCurvatureIsInvertible`, the predicate #494 added. Measured on a cubic Bezier whose first
two poles sit a controlled distance apart, at `u = 0`:

| pole spacing | at `1e-6` (before) | at `Precision::Confusion()` (after) |
|---|---|---|
| 1e-3 … 1e-6 | real centre | real centre |
| 3e-7 | `(nan, inf, nan)` reported as a point | real centre `(0, 1.35e-13, 0)` |
| 1e-7 | `(inf, inf, nan)` reported as a point | real centre `(2.8e-30, 1.5e-14, 0)` |
| 1e-8 … 1e-12 | `(nan, inf, nan)` reported as a point | `nil` — no centre of curvature at a cusp |
| 0 (exactly coincident) | `(0, 0, 0)`, from the absorbed throw | `nil` |

**Source-breaking, in four places**, all of them entry points that could not previously say "there
is nothing here": `Shape.edgeNormalLP(at:)` and `Shape.edgeCentreOfCurvature(at:)` return
`SIMD3<Double>?` rather than `SIMD3<Double>` (they returned `(0, 0, 0)` — not a direction, not a
point — where the quantity does not exist), and `Shape.edgeLPropD1(at:)` joins them. Not a signature
change but a behaviour one: `Shape.edgeLPropValue(at:)` was already declared optional and never
returned `nil`; now it does.

**Two of the three `Topology.mm` sites were orphans and are deleted rather than converged.**
`OCCTShapeGetHorizontalFaces` and `OCCTShapeGetUpwardFaces` reimplemented `Face.isHorizontal` /
`Face.isUpwardFacing` over the same midpoint normal, and nothing called them: `Shape.horizontalFaces`
and `Shape.upwardFaces` filter `faces()` through the `Face` predicates. Same reasoning as #506 —
`OCCTBridge` is a target, not a product, and an orphan freezes whatever contract it had when it was
orphaned, so leaving them would have meant maintaining a second `1e-6` behind a symbol with no
callers.

**The surviving `Topology.mm` site's change is inert, and that is a measurement, not an assumption.**
`CSLib::Normal` tests the two first derivatives for nullity against `gp::Resolution()` — a fixed
~1e-300 epsilon, not the caller's value — and uses the caller's value only as the sine tolerance
above. A surface whose derivatives merely shrink keeps a defined normal all the way down, which is
why tightening the value changes nothing for the normal-only sites. Swept over every face of a box,
cylinder, sphere, apex cone, frustum, torus, hemisphere, a fully filleted box and the 662 faces of
`unify-crash-mmd-kiha10-body5.brep`: zero faces changed definedness, zero changed direction, and the
horizontal (18) and upward (9) counts on the real fixture are identical before and after. The one
geometry that does move is a nearly *singular parameterisation* — a linear extrusion skewed by 5e-7
radians, whose normal is undefined at `1e-6` and defined at `Precision::Confusion()`.

New suites `AdaptorLocalPropsParityTests` and `AdaptorNormalDecisionTests` (`OCCTAnalysisTests`), 11
tests, following #494's `LocalPropsParityTests` pattern: each adaptor-backed entry point is asserted
to agree with its `Geom_`-backed counterpart about definedness exactly, and about value to a
relative tolerance — not bit for bit, because a `BRepAdaptor_Curve` evaluates a Bezier or BSpline
through a cache the raw handle does not use, which moves the last ULP (measured: 0.67461923686773151
against 0.6746192368677314 for the same curvature). Proved against three separate injections rather
than assumed: restoring the `1e-6` resolution fails 4 tests, removing the two invertibility gates
fails 1 (on the `(nan, inf, nan)` centre), and restoring the raycast tolerance forwarding fails 2.
Four tests are controls and pass under all three.

Probes and full figures at
[`Scripts/repro/529-breplprop-resolution/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/529-breplprop-resolution).
Bridge-only: no kernel patch, no `OCCT.xcframework` rebuild.

**Noticed, and fixed separately.** The face-side curvature getters (`faceLPropMaxCurvature` and its
four siblings) still spelled "undefined" as `0`, where the `Face` counterparts return `nil`: the
silent-zero class #486 and #494 have both hit, and more source-breaking signatures on top of the
four here. Filed as #583 rather than folded in; see the next entry.

#### Breaking: a curvature of zero and no curvature at all stop being the same answer (#583)

`Shape.faceLPropMaxCurvature(u:v:)` and its four siblings returned the value bare and used `0` (or
`(0, 0, 0)` for `faceLPropValue(u:v:)`) to mean three different things at once: the curvature is
undefined at this point, the handle was null, and this `Shape` is not a face. #529 had just made
them agree with `Face.meanCurvature(atU:v:)` and friends about *whether* a quantity exists; they
still had no way to say so.

That encoding has no spare value to spend, which is a measurement rather than a style objection.
Read through the same `BRepLProp_SLProps` the bridge builds:

| geometry | `IsCurvatureDefined()` | what came back |
|---|---|---|
| cylinder, **any** point | true | Gaussian and maximum curvature both exactly `0` |
| cone, any point | true | the same two, exactly `0` |
| plane, any point | true | all four scalars exactly `0`; at `(0, 0)` of a plane through the origin, a point of `(0, 0, 0)` too |
| cone apex, sphere pole | **false** | `0` / `(0, 0, 0)` |
| a `Shape` that is not a face | n/a | `0` / `(0, 0, 0)` |

So the sentinel collided with the answer across whole faces of the two commonest solids in the test
suite, not at some pathological parameter; and `faceLPropIsUmbilic(u:v:)` answered `false`, "the
principal curvatures differ here", at points with no principal curvatures to compare.

**Source-breaking, in six places.** The five the issue names return an optional:
`Shape.faceLPropValue(u:v:)` → `SIMD3<Double>?`, and `faceLPropMaxCurvature(u:v:)`,
`faceLPropMinCurvature(u:v:)`, `faceLPropMeanCurvature(u:v:)`, `faceLPropGaussianCurvature(u:v:)` →
`Double?`. **The census turned up a sixth in the same block**: `faceLPropIsUmbilic(u:v:)` →
`Bool?`, whose `false` was the same conflation one type down. `faceLPropValue` is the one whose
contract narrows rather than changes: the point does not depend on the curvature gate, so it is
still reported at a cone apex and a sphere pole, and `nil` there means only "not a face".

Migration is `if let` at the call site; the previous behaviour is `?? 0`, which is what every caller
that ignored the distinction was already getting.

New suite `AdaptorCurvatureDefinednessTests` (`OCCTAnalysisTests`), 4 tests, and the three
`AdaptorLocalPropsParityTests` workarounds come out: the parity claim is now
`(adaptor != nil) == (geom != nil)` on every sampled point, the way the edge half of that suite
already asserted it, instead of comparing values only where the `Geom_` side happened to report one.
Proved against two injections rather than assumed: making the curvature gate unreportable (undefined
comes back as a successful `0`) fails 2 tests, and making the `catch` unreportable (a non-face
`Shape` comes back as a successful `0`) fails 1. Seventeen and eighteen tests respectively are
controls and pass under both.

**Not changed here, and fixed as #595 (next entry).** Six entry points on other types keep the same bare
double: `Curve3D.curvature(at:)`, `Curve3D.localCurvature(at:)`, `Curve2D.curvature(at:)`,
`Shape.edgeCurvatureLP(at:)`, `Surface.gaussianCurvature(atU:v:)` and `Surface.meanCurvature(atU:v:)`.
The last two disagree with both `Face.gaussianCurvature(atU:v:)`/`meanCurvature(atU:v:)` and with
their own neighbour `Surface.principalCurvatures(atU:v:)`, which is already optional. A straight
edge's curvature is genuinely `0` and a fully degenerate curve's is undefined, so the collision is
identical; each is a separate public type with its own break surface, so folding them in would have
repeated exactly the mistake this issue exists to avoid.

Probe and full figures at
[`Scripts/repro/583-lprop-zero-sentinel/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/583-lprop-zero-sentinel).
Bridge-only: no kernel patch, no `OCCT.xcframework` rebuild.

#### Breaking: the same zero, on four more public types (#595)

The follow-up #583 filed. Nine entry points now report whether there is a curvature to report,
instead of answering `0` when there is not:

| Swift | was | now |
|---|---|---|
| `Curve3D.curvature(at:)` | `Double` | `Double?` |
| `Curve3D.torsion(at:)` | `Double` | `Double?` |
| `Curve2D.curvature(at:)` | `Double` | `Double?` |
| `Shape.edgeCurvatureLP(at:)` | `Double` | `Double?` |
| `Surface.gaussianCurvature(atU:v:)` | `Double` | `Double?` |
| `Surface.meanCurvature(atU:v:)` | `Double` | `Double?` |
| `Surface.curvatures(u:v:)` | `(gaussian: Double, mean: Double)` | `(gaussian: Double, mean: Double)?` |
| `Wire.curvature(at:)` | `Double?` | unchanged signature, see below |
| `Curve3D.localCurvature(at:)` | `Double` | **deprecated** onto `curvature(at:)` |

Migration is `if let`; the previous behaviour is `?? 0`.

**The census was six and measured nine.** Three decide "undefined" with a hand-rolled magnitude gate
rather than an OCCT predicate, so a grep for `Is*Defined()` — which is how the issue's list was
built — cannot see them:

- **`Curve3D.torsion(at:)`** answered `0` where the first two derivatives are parallel and there is
  no osculating plane to twist out of. A **planar** curve's torsion is genuinely `0`, and every
  circle and ellipse is planar, so the collision runs the other way from the curvature rows and is
  just as ordinary. It sits four lines below `curvature(at:)` on the same type; leaving it would
  have broken `Curve3D`'s source compatibility twice for one defect.
- **`Surface.curvatures(u:v:)`** returned a bare `(0, 0)`. Its own documented contract is that it
  agrees with `gaussianCurvature(atU:v:)` and `meanCurvature(atU:v:)` "including on whether
  curvature is defined at all" — which it shares one `GeomLProp_SLProps` with, and could not say.
- **`Wire.curvature(at:)`** already returned `Double?`, but only its `-1.0` error path reached that
  optional. The null-derivative branch — a cusp, where the formula divides by zero — returned `0.0`,
  a straight wire's real answer. No signature change; the branch stops lying. It has no infinity
  sentinel to offer instead: `BRepAdaptor_CompCurve` computes the formula directly rather than
  through `GeomLProp_CLProps`, so nothing is the honest answer.

**The collisions are ordinary geometry, not constructed pathologies.** Measured through the same
kernel classes the bridge builds:

| entry point | the real `0` | the `0` that meant "no answer" |
|---|---|---|
| `Curve3D` / `Curve2D.curvature(at:)` | any straight curve | a Bezier with all poles coincident |
| `Shape.edgeCurvatureLP(at:)` | any straight edge | **a sphere's degenerate pole edge** |
| `Surface.gaussianCurvature(atU:v:)` | **every point of every plane, cylinder and cone** | a cone apex, a sphere pole |
| `Surface.meanCurvature(atU:v:)` | every point of every plane | the same |
| `Curve3D.torsion(at:)` | every planar curve | any straight stretch |

The edge row is the one worth reading twice: a sphere carries a degenerate edge at each pole, that
edge has no 3D curve at all, and `Shape.edge*` traversal does not skip it.

**A cusp is not an absence and is unchanged.** OCCT reports `RealLast()` there, meaning infinite
curvature, and `Double.greatestFiniteMagnitude` still comes through as a value. It is a real, distinct
answer that a `Double?` has no room for, and it is why the curve half of this family looked better
covered than it was.

**`Curve3D.localCurvature(at:)` is deprecated onto `curvature(at:)`, and
`OCCTCurve3DLocalCurvature` is deleted.** #494 converged their resolutions, after which the two built
the same `GeomLProp_CLProps` at the same `occtLocalPropsResolution()` and gated on the same
`IsTangentDefined()`. Per #562's rule, the axis to check before collapsing is the one nobody listed:
here that is the null-handle guard, and it is unreachable from Swift since both wrappers pass a live
handle. Measured over the same four curves, including both degenerate rows, the two spellings
disagreed on **0** of them.

`OCCTWireGetCurvatureAt`, `OCCTCurve2DGetCurvature`, `OCCTCurve3DGetCurvature`,
`OCCTCurve3DGetTorsion`, `OCCTEdgeLPropCurvature`, `OCCTSurfaceGetGaussianCurvature`,
`OCCTSurfaceGetMeanCurvature` and `OCCTSurfaceCurvatures` return `bool` with the value as an
out-parameter, the shape `OCCTFaceGetMeanCurvature` and (since #583) `OCCTFaceLPropMeanCurvature`
already use. C-layer contract change; `OCCTBridge` is not an SPM product (#486).

**Deliberately excluded.** `Edge.dihedralAngle(between:and:at:)` has the same hand-rolled shape but
returns `-1`, outside its documented `0...2π` range, and its wrapper already maps that to `nil` — a
distinguishable sentinel that already reaches the caller as an absence. The `Local*`/`GeomLProp*`
families already carry an `isDefined` out-parameter (#494).

**Banked, not changed.** Two thresholds stay exactly where they are, because this pass changes how an
absence is *spelled*, not where the boundary between presence and absence falls:
`OCCTCurve3DGetTorsion` compares a **squared** magnitude against the linear `Precision::Confusion()`
(an effective gate of `3.16e-4` on `|d1 x d2|`), and `OCCTWireGetCurvatureAt` keeps its literal
`1e-10` on `|d1|`, the last hand-rolled resolution in the local-properties family after #494 and #529
converged the rest.

New suite `Issue595CurvatureDefinednessTests` (`OCCTAnalysisTests`), 9 tests. Proved against two
injections: making every definedness gate unreportable fails 8 of the 9 (the cusp test is the
control, correctly, since a cusp is not gated); making every `catch` unreportable fails 1, the
not-an-edge case, with 8 controls.

Probe and full figures at
[`Scripts/repro/595-curvature-zero-sentinel/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/595-curvature-zero-sentinel).
Bridge-only: no kernel patch, no `OCCT.xcframework` rebuild.

#### The `PrecisCode` census counted a commented-out call site and missed a live one (#573)

`OCCTBridge_Surface.mm` carries a census of how OCCT itself splits on `GeomConvert_ApproxSurface`'s
`PrecisCode` argument. It is load-bearing: it is the stated justification for #491 settling both
surface approximation entry points on `0`. It was built by grepping for the class rather than by
reading each hit, so it counted `BRepFill_Sweep.cxx:1162`, which sits inside a `/* */` block
spanning `:1064` to `:1179` and is not compiled, and it missed `BRepOffset_Offset.cxx:1626` and the
second `GeomConvert_1` site (`:960`) entirely. The live set is 2 sites passing `0` and 6 passing
`1`:

| passes `0`, re-checks `MaxError()` | passes `1`, never reads `MaxError()` |
|---|---|
| `ShapeCustom_BSplineRestriction.cxx:852` | `GeomConvert_1.cxx:786`, `:960` |
| `ShapeConstruct.cxx:265` | `ShapeUpgrade_UnifySameDomain.cxx:3629` |
| | `GeomFill_Sweep.cxx:296` |
| | `GeomLib.cxx:1517` |
| | `BRepOffset_Offset.cxx:1626` |

**#491's conclusion is unchanged, but its stated reason was slightly wrong.** The split is not
"caller's tolerance versus hardcoded internal tolerance": `BRepOffset_Offset` takes the caller's
`TolApp` and still passes `1`, because it gates on `IsDone()` and never checks the fit against the
tolerance it was given. What the two groups actually divide on is whether the site verifies the
result, which is the property that puts this bridge in the `0` group. The comment now records that,
names both commented-out mentions so the next reader does not re-add them, and says why the two
Draw/QA harness sites and `GeomPlate_MakeApprox` (which drives `AdvApp2Var_ApproxAFunc2Var` directly
and has no `PrecisCode`, see #571) are outside the list.

Comment-only, no behaviour change. The same correction is applied to
[`Scripts/repro/491-approx-wrapper-drift/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/491-approx-wrapper-drift)
and to #491's entry below; #522's own notes had already been corrected. The eight other bridge
comments that cite OCCT source (13 line references between them) were checked the same way and all
point at live code that says what the comment claims, including the one that correctly describes
`AdvApprox_ApproxAFunction.cxx:550` as commented out upstream.

#### Breaking: the last five entry points that quietly dropped an unresolvable index (#568)

A sub-shape index naming nothing now rejects the request everywhere, not just in the fillet family.
#520 settled that for the five `BRepFilletAPI_MakeFillet` edge-list functions and #541 for
`Shape.offsetPerFace`; five sites in the neighbouring families still skipped the entry and built
from whatever resolved.

| entry point | index | before | now |
|---|---|---|---|
| `Shape.drafted(faces:direction:angle:neutralPlane:)` | face | drafts the faces that resolve | `nil` |
| `Shape.shelled(thickness:openFaces:)` | face | opens the faces that resolve | `nil` |
| `Shape.chamferedWithFullHistory(distance:edges:)` | edge | chamfers the edges that resolve | `nil` |
| `Shape.fillet2D(vertexIndices:radii:)` | vertex | rounds the corners that resolve | `nil` |
| `Shape.chamfer2D(edgePairs:distances:)` | edge (either half of a pair) | cuts the pairs that resolve | `nil` |

**Why this is not tidiness.** Measured on the pinned kernel
([`Scripts/repro/568-index-skip-idiom/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/568-index-skip-idiom)),
every builder behind these sites reports an ordinary success for a batch it was never told was
short. The partial result is `IsDone`, non-null and `BRepCheck_Analyzer`-valid; it differs from the
complete one only in geometry the caller has no reason to re-measure:

| builder, on a 20mm box | whole request | partial request |
|---|---|---|
| `BRepFilletAPI_MakeChamfer`, 3 edges | volume 7885.333333 | 2 of 3: volume 7922.666667, valid |
| `BRepOffsetAPI_DraftAngle`, 4 faces | volume 6681.349269 | 2 of 4: volume 7299.820338, valid |
| `BRepOffsetAPI_MakeThickSolid`, 2 open faces | volume 2880.000000 | 1 of 2: volume 3392.000000, valid |
| `BRepFilletAPI_MakeFillet2d`, 4 vertices | area 1178.539816 | 2 of 4: area 1189.269908, valid |

**`Shape.drafted` was the worst of the five, and only the measurement showed it.** Handed *no*
faces at all, `BRepOffsetAPI_DraftAngle` still reports `IsDone()` and returns the input shape
unchanged (volume 8000 for the same box). So a draft naming only faces the shape does not have (the
ordinary result of passing `Face` values taken from a different shape) succeeded and drafted
nothing. The other four at least fail an empty batch (`MakeChamfer` throws "There are no suitable
edges for chamfer or fillet"; `MakeFillet2d` fails `IsDone`), and `Shape.shelled` had its own empty
check, which is why for those the *mixed* batch was the only case that escaped.

**The census the issue filed was three ways off**, each found by measuring rather than reading:

- `Shape.offsetPerFace` was on the list but had already been fixed by #541, which also settled the
  "is a dictionary of overrides different?" question the issue asked: an override naming no face is
  an invalid request, not an absent override.
- Two entries were filed against `OCCTWireFilletAll2D` / `OCCTWireChamferAll2D`, which take no
  indices at all. Their line numbers pointed at `OCCTFace2DFillet` / `OCCTFace2DChamfer`, which do,
  and those are what is fixed here. Same failure mode as #565's own mis-filing: trust the line, not
  the name.
- Two sites the issue did not list, `OCCTShapeDraft` and `OCCTShapeShellWithOpenFaces`, spell the
  skip as an `if (idx >= 0 && idx < map.Extent()) { … }` wrap rather than a `continue`, so a census
  grepping for the `continue` spelling missed them, including the draft, the most severe of the
  five.

**One resolution helper, not five loops** (the issue's second question). `occtUseSubShapesByIndex`
and `occtMappedSubShapeAt` (`OCCTBridge_Internal.h`) resolve a caller's index array through
`occtMapSubShapes`, the enumeration #502 and #541 already made canonical, and refuse on the first
index that names nothing. `occtFilletAddEdges` is now a five-line wrapper over it, since only the
`TopoDS_Edge` cast was ever fillet-specific, so the fillet family and these five share one
statement of the contract rather than agreeing by coincidence. `OCCTFace2DChamfer` is the one site
whose entries name two sub-shapes each, so it reads the map through `occtMappedSubShapeAt` directly.

Bridge-only: no kernel patch, no `OCCT.xcframework` rebuild. No operation count change.

**Migration.** A call that used to succeed by dropping indices now returns `nil`. Filter your own
indices against `Shape.faces().count` / `Shape.edges().count` / `face.vertices().count` if you want
the old best-effort behaviour. The difference is that you now choose it.

#### Three orphaned arc-length bridge functions deleted, and they were not spare copies (#506)

`OCCTCurve3DArcLength`, `OCCTCurve3DArcLengthBetween` and `OCCTCurve3DLength` are gone. #408 routed
`totalArcLength`, `arcLength(from:to:)` and `arcLengthBetween(_:_:)` through `length` /
`length(from:to:)`, which call `OCCTCurve3DGetLength` / `OCCTCurve3DGetLengthBetween`, leaving all
three declared, compiled, and unreachable from Swift. #461 kept them "for C-ABI stability". That
rationale does not survive contact with the packaging: `OCCTBridge` is a target, not a product, so
nothing outside this package can link those symbols through SwiftPM. The layer's actual stability
contract is now written down rather than asserted per PR, in
[`docs/architecture/overview.md`](architecture/overview.md) under design decision 6.

Keeping them was not free. Retaining an orphan freezes whatever contract it had when it was
orphaned, and these three were frozen before two separate fixes. All three returned `0` on failure,
the collapse of "the computation failed" into "the curve is genuinely zero length" that #408 fixed.
`OCCTCurve3DLength` also measured through a pre-bounded `GeomAdaptor_Curve(curve, u1, u2)` instead
of passing the range to `GCPnts_AbscissaPoint::Length(adaptor, u1, u2)`, and the two forms disagree
wherever the range is not an ordinary in-domain interval. Measured against the pinned kernel on a
5-point interpolated BSpline, 360.99 long:

| range | pre-bounded (deleted) | ranged (live) |
|---|---|---|
| in domain, forward | 173.76 | 173.76 |
| in domain, reversed | raises, reported as `0` | 173.76 |
| overshooting both ends by a domain width | 8489.78 | 360.99 |
| wholly outside the domain | 1.34 | 0 |
| equal parameters, periodic seam, unbounded sub-range | agree | agree |

So the "dead copy" still extrapolated a BSpline's polynomial past its knots, the behaviour #477
removed from every reachable path, and still read a reversed range as zero length. One rewire or one
copy-paste and both defects were back, with no test anywhere to catch it. Probe and full figures at
[`Scripts/repro/506-arclength-adaptor-divergence/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/506-arclength-adaptor-divergence).

New suite `Issue506ArcLengthBridgeContractTests` (`OCCTCurveTests`) pins the surviving behaviour on
exactly the four ranges where the forms diverge, with the clamping assertions checked against a
chord-sum reference rather than against the implementation's own answer for the whole domain. Proved
against two injections rather than assumed: restoring the pre-#408 wiring fails the cross-spelling
test on all three divergent ranges (0 against 173.76, 8489.78 against 360.99, 1.34 against 0), and
rewiring `length(from:to:)` itself onto the pre-bounded form, the accidental-rewire case, fails all
four tests.

**Noticed, not fixed.** `length(from:to:)`'s NaN handling is curve-type dependent: a NaN bound
reports `nil` on a line, a segment and a circle, but on a BSpline `GCPnts_AbscissaPoint::Length`
returns a plausible number (`0` for a NaN upper bound, the whole length for a NaN lower bound), so
the failure-versus-zero distinction #408 established holds for the curve types its own tests use and
not for BSplines (#548). Separately, `Curve2D.arcLength(from:to:)` measured through the 2D
pre-bounded adaptor deliberately, documented as range-checked, so the 2D and 3D spellings of the same
call differed on a reversed range (#549, fixed above in this same release once the 2D form turned out
to extrapolate as well). Both are #408/#409 contract questions rather than duplication, so they were
filed rather than folded in here.

#### The PointsToBSpline index entry, and the controls it hid that do nothing (#507)

`OCCTBridge.h`'s cross-reference index credited `GeomAPI_PointsToBSpline` to a single function,
`OCCTCurve3DFit`, which does not exist anywhere in the repo. A census of what actually constructs
that class found five call sites, not one: `OCCTCurve3DFitPoints` (the real name behind the index
entry), `OCCTPointsToBSplineWithParams`, `OCCTPointsToBSplineWithParameters`, the 14-function
`OCCTBSplineApproxInterp*` family, and `OCCTWireCreateBSpline`, which the issue's own site list did
not have either. All five are now indexed.

Two neighbouring entries were wrong in the same way and are corrected with them.
`GeomAPI_PointsToBSplineSurface` credited `OCCTSurfacePlateThrough`, which does not use that class
at all (it is `GeomPlate_BuildPlateSurface` plus `GeomPlate_MakeApprox`, and is now indexed there
instead), and omitted `OCCTPointsToSurfaceBSpline` and four of the five `OCCTSurfaceNLPlate*`
functions. `Geom2dAPI_PointsToBSpline` had no index entry at all despite backing three functions.
The `GeomAPI_PointsToBSpline expansion` section header covered four functions across three
different OCCT classes; it now names all three.

The larger find was behind the mis-attribution. `Approx_BSplineApproxInterp` was removed in OCCT
8.0.0p1 and its 14-function bridge family was reimplemented on `GeomAPI_PointsToBSpline`, but the
header, the Swift wrapper and `docs/reference/GeometrySolvers.md` still documented the removed
solver's controls as live. Five of them do nothing: `interpolatePoint(_:withKink:)`,
`setParametrizationAlpha(_:)`, `setMinPivot(_:)`, `setClosedTolerance(_:)` and
`setKnotInsertionTolerance(_:)`. `performOptimal(maxIterations:)` is `perform()` with the iteration
count discarded. `nbControlPoints` and `continuousIfClosed` are advisory. `setConvergenceTolerance`
and `setProjectionTolerance` are one shared tolerance, not two knobs, and the projection one can
only tighten it. The reference page also attributed `maxError` to `GeomAPI_PointsToBSpline::MaxError`,
a method that class does not have: the bridge computes it by projecting each input point back onto
the fitted curve with `GeomAPI_ProjectPointOnCurve`.

Every one of those claims is now a test. The existing four tests asserted only `isDone`, which is
why the drift went unnoticed, so `BSplineApproxInterpContractTests` pins each contract by comparing
densely sampled fits for exact agreement, with a control test proving the comparison does register
a real change when the fit tolerance moves. Checked against a deliberate reimplementation of
`SetAlpha` on `Approx_ParametrizationType`: the no-op test fails and the other six stay green. The
deviation that injection produced was 2.2e-14, so exact equality rather than a tolerance is what
catches it.

No behaviour changed.

#### The 12 bridge symbols that never said "OCCT", and the index entry for a symbol that never existed (#508)

Of ~1161 bridge function declarations, twelve began `OCT` rather than `OCCT` — the whole
`GC_MakeCircle2d`/`Ellipse2d`/`Hyperbola2d`/`Parabola2d` family, consistently misspelled across the
header, the `.mm`, and the Swift call site since v0.105.0. Nothing was broken; the mismatch was
internally consistent end to end, which is exactly why it survived.

The obvious fix was to insert the missing `C`. Instead the family is now `OCCTCurve2DMake*`,
matching `OCCTCurve2DMakeLineThroughPoints`/`OCCTCurve2DMakeLineParallel` — the `GC_MakeLine2d`
wrappers declared two lines away, the direct sibling of these four classes. The old name was a
second inaccuracy layered on the first: `GCE2d` is a *different* OCCT package, and v0.156.0 already
moved these implementations off it when OCCT 8.0.0 deprecated `GCE2d_X` into a `using` alias for
`GC_X2d`. That release deliberately kept the C names for ABI reasons that no longer apply, so a
grep for the package these functions were named after led away from the code, not to it.

The header's cross-reference index carried a matching but distinct error: its one `GC 2D` entry
read `GC_MakeLine2d → OCCTGCE2dMakeLine* (bridge symbols retain GCE2d historical name)`. That
prefix has zero occurrences anywhere in the repo — it named neither the conic family nor the line
functions it claimed to describe. All five `GC_Make*2d` families are now indexed under their real
symbols.

`Scripts/check-bridge-index.py`, written for #484/#510 to catch precisely this, could not see the
entry: it stripped only a `(vX.Y.Z)` suffix, so the trailing prose aside left the symbol glued to
the annotation and the entry was silently skipped rather than reported stale. It now strips any
parenthetical, which also un-hides two further entries that were being skipped for the same reason
(both resolve). The stale count is unchanged at 135 — the #510 backlog, untouched here.

Documentation for this family named a *fourth* variant, `gce_MakeCirc2d`/`gce_MakeElips2d`/
`gce_MakeHypr2d` — a real OCCT package, but not the one these twelve call. Corrected to the actual
`GC_Make*2d` classes, along with two rows elsewhere in `API_REFERENCE.md` left stale by the same
v0.156.0 migration (`Curve2D.segment` is `GC_MakeSegment2d`; `Curve2D.ellipse` constructs
`Geom2d_Ellipse` directly and never went through `GCE2d_MakeEllipse`).

Four tests close the coverage hole the audit found alongside the naming drift:
`gceCircleParallel`, `gceEllipse(s1:s2:center:)` and `gceHyperbola(s1:s2:center:)` had no test at
all. They assert measured geometry rather than non-nil, and were verified to fail against injected
defects — a flipped parallel-offset sign, and swapped `S1`/`S2` apex points. No public Swift API
changed; `OCCTBridge` is not an SPM product, so the C-layer rename reaches no consumer.

#### The 2D solvers' circle radius: measured per family, guarded in all of them (#553)

The last unresolved part of the 2D circle-radius family, split out of #514. About 25 sites in
`OCCTBridge_Geom2d.mm` build a `gp_Circ2d` from caller-supplied doubles as an **input** to a
tangency, bisector, intersection or extrema solver rather than as geometry being returned. #514
stopped there on purpose: a zero-radius circle handed to such a solver is geometrically a point, and
several of them have a documented answer for a point argument, so guarding blindly could have
removed a query some callers were legitimately making.

So it was measured, per family, against OCCT's own point overload of the same query. The probe is at
[`Scripts/repro/553-gcc-zero-radius-circle/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/553-gcc-zero-radius-circle).
**No family answers the point question:**

| family | a zero-radius argument gives | OCCT's own point overload gives |
|---|---|---|
| `GccAna_Circ2dBisec` | 4 solutions, each duplicated; with **both** radii 0, two of the three are hyperbolas of **major radius 0** | `GccAna_CircPnt2dBisec` gives 2; `GccAna_Pnt2dBisec` gives the perpendicular bisector line |
| `GccAna_CircPnt2dBisec` | 2 hyperbolas of **major radius 0** | a **line** — so the returned *type* is wrong, not merely duplicated |
| `GccAna_CircLin2dBisec` | the point overload's parabola, twice | it once |
| `GccAna_Lin2dTanPar` / `Lin2dTanPer` | the point overload's line, twice | it once |
| `GccAna_Lin2d2Tan` | the point overload's line, twice | it once |
| `GccAna_Circ2d3Tan`, three circles | 8 solutions: the point overload's 4, each twice | 4, tangency residuals < 1e-14 |
| `GccAna_Circ2d3Tan`, one circle + two points | **0 solutions** | the circle circumscribing the three positions |
| `Extrema_ExtPElC2d` | **0 extrema** — the distance is lost outright | — |
| `Extrema_ExtElC2d` | the right distance, twice | — |
| `IntAna2d_AnaIntersection` | the right point, with `ParamOnSecond()` **NaN**, written straight into the caller's `param2` | — |

The duplication has a cause worth recording: tangency to a circle of radius 0 satisfies the
enclosing and the outside qualifier at once, so the solver enumerates each solution twice. And the
hyperbolas of major radius 0 are the same degenerate conic `occtValidHyperbolaRadii` refuses to
construct on the other side of this file, so the bisector families were handing back curves the
construction API would not accept.

Every one of those families already has a point entry point in the same API — `GccAnaBisector.ofPoints`,
`ofLineAndPoint`, `Curve2DGcc.lineParallelThrough`, `linePerpendicularThrough`,
`Shape.circleThrough3Points`, the point/point line solvers, and the mixed circle/point overloads.
Naming a point as a point already has a spelling, and a degenerate circle is not it. **Guard, in
every family** — a decision reached per family, which converged.

**Negative was never the gap.** `gp_Circ2d`'s constructor is `constexpr` in the header, so its
`Standard_ConstructionError_Raise_if(theRadius < 0.0, …)` does run in a bridge translation unit —
the same finding #514 made for `gp_Elips2d` — and the existing `catch` already turned it into an
empty result. `GC_MakeCircle2d` reports `gce_NegativeRadius`, a status rather than a macro, so
`No_Exception` does not void that either. The new guards change what **zero** does, nothing else.

Two more radius contracts in the same file were converged onto the same predicate while the family
was open:

- **The radius of the circle a solver must find.** `OCCTGccCircle2d2TanRad`,
  `OCCTGccCircle2dTanPtRad` and `OCCTGccCircle2d2PtRad` each spelled `radius <= 0` inline; four
  siblings did not check at all. Measured, `GccAna_Circ2d2TanRad` and `GccAna_Circ2dTanOnRad` asked
  for radius 0 return solution circles of radius 0. All seven now share `occtValidCircleRadius`.
- **Four producer sites #514 did not reach.** `BRepBuilderAPI_MakeEdge2d` reports `IsDone()` for a
  zero-radius arc and returns a zero-length edge with both vertices at the centre;
  `GC_MakeCircle2d(ax, 0)` succeeds. `Curve2D.gceCircleParallel` needed the offset checked as well:
  measured, `GC_MakeCircle2d` takes the **absolute value** of `radius + dist`, so radius 5 offset by
  -5 gives radius 0 and by -6 gives radius 1 — a circle the caller did not ask for, not a refusal.

Every affected Swift entry point now documents its radius contract with a runnable snippet; none of
them mentioned it before. A rejected radius returns an empty array (or `nil` for the producers),
which is what these entry points already returned for "no solutions", so no call site has to move.

22 tests in `Tests/OCCTGeom2dTests/Issue553GccZeroRadiusTests.swift`, run against a build with the
zero rejection removed: **16 fail**, and the 6 that do not are the four valid-input controls, the
negative-radius test, and the two cases where OCCT's own wrong answer is itself an empty set
(`circleTangentCircle2Points` and `distanceFromPointToCircle`), which no assertion can discriminate.
Both are noted as such in the test file.

Not changed: `extractBisecSolution`'s `default` branch writes `(0, 0)` for a `GccInt_Pnt` solution
instead of its coordinates. Section 13 of the probe hunts for one — identical, concentric,
externally tangent, internally tangent and crossing circles, a point on the circle, a point at the
centre — and none of them, nor any zero-radius case, produces one. Left alone rather than fixed
speculatively.

#### The nine 2D conic sites that took a dimension and never checked it (#514)

Split out of #487, which fixed the three `gce_Make*2d` factories and converged the four conic
dimension predicates onto one definition. The rest of the 2D family builds a conic from
caller-supplied dimensions at nine more places, and none of them checked. All nine now use the
same shared predicates: `occtValidCircleRadius`, `occtValidEllipseRadii`, `occtValidHyperbolaRadii`,
`occtValidParabolaFocal`.

**The gap was the zero boundary specifically, not "no precondition at all".** The issue's premise
was that `gp_Elips2d`'s own `Standard_ConstructionError_Raise_if` is compiled out. That is true of a
call made from **inside** OCCT, where `No_Exception` is defined, and it is what #487 measured for
`gce_MakeElips2d`. These nine sites construct the `gp_*2d` themselves, in a bridge translation unit,
where the constructor is `constexpr` in the header and the check does run: `gp_Elips2d(ax, 5, -3)`,
`(3, 5)` and `gp_Parab2d(ax, -2)` all raise today and are already caught. What the check never
covered is zero, which every downstream algorithm then accepts:

| construction | measured result on the degenerate input |
|---|---|
| `Convert_EllipseToBSplineCurve`, radii `(0, 0)` | 5 poles, degree 2, evaluates to the centre at every parameter |
| `Convert_EllipseToBSplineCurve`, radii `(5, 0)` | collapses onto the major axis: `(5,0) → (0,0) → (-5,0)` |
| `Convert_HyperbolaToBSplineCurve`, radii `(5, 0)` | a straight ray |
| `Convert_ParabolaToBSplineCurve`, focal `0` | 3 poles, degree 2, **every pole NaN** |
| `BRepLib_MakeEdge2d`, ellipse `(0, 0)` | `IsDone()`, zero-length edge, both vertices at the centre |
| `BRepLib_MakeEdge2d`, ellipse `(5, 0)` | `IsDone()`, a segment doubled back along the major axis |
| `IntAna2d_Conic`, ellipse `(0, 0)` | all six coefficients 0 |

**`Conic2D` gains a way to say the conic does not exist.** All-zero coefficients cannot carry it:
the equation `0 = 0` holds at every point of the plane, so they read as a conic, and they were also
what the `catch` block already wrote. The three bridge functions return `bool`; in Swift there are
three new factories that return `Conic2D?`:

```swift
// new
if let e = Conic2D.ellipse(center: .zero, direction: SIMD2(1, 0),
                           majorRadius: 5, minorRadius: 3) { … }

// old spelling, still compiles, now deprecated
let e = Conic2D.fromEllipse(center: .zero, direction: SIMD2(1, 0),
                            majorRadius: 5, minorRadius: 3)
```

`fromCircle` / `fromLine` / `fromEllipse` are `@available(*, deprecated, renamed:)` and forward,
returning the all-zero struct where the new spelling returns `nil`. **Not a breaking change**: no
existing call site has to move, and no signature changed.

`Conic2D`'s documented equation was wrong. It named `a·x² + b·x·y + c·y² + d·x + e·y + f = 0`;
OCCT's `IntAna2d_Conic::Coefficients` returns `a·x² + b·y² + 2c·x·y + 2d·x + 2e·y + f = 0`, so `b`
is the `y²` term and `c` the cross term, and the cross and linear terms carry a factor of 2. A
caller who built a conic from the documented order got a different curve. The values themselves
never changed; a regression test now pins the order against a radius-5 circle (`1, 1, 0, 0, 0, -25`).

Scope: the three circle siblings sitting in the same three code blocks
(`OCCTMakeEdge2dFullCircle`, `OCCTConvertCircleToBSpline2D`, `OCCTConic2dFromCircle`) are included,
along with `OCCTConic2dLineCircleIntersect`, which shares the same `gp_Circ2d` construction and
would otherwise have been the one entry point in its own block still accepting radius 0. The ~25
remaining 2D circle sites are `Geom2dGcc` tangency-solver *inputs*, a different question, filed
separately. The 3D equivalents are unsurveyed, as #514 noted.

18 tests in `Tests/OCCTGeom2dTests/Issue514Conic2dDegenerateTests.swift`. They were run against a
build with every guard stripped back out: the 10 rejection tests fail, and the 8 that pin valid
input (including "a hyperbola may have minor > major" and the coefficient order) still pass.

#### The 3D conic sites that took a dimension and never checked it (#554)

The 3D counterparts of #514, which surveyed only the 2D side. Twenty-two sites across
`OCCTBridge_Curve3D.mm` and `OCCTBridge_Modeling.mm` build a 3D conic from a caller-supplied
dimension, or rewrite one on a live curve, and none of them checked it. All twenty-two now use the
same four shared predicates: 11 ellipse, 6 hyperbola, 4 parabola, 1 circle. #399's earlier pass
covered the `Curve3D` *factories* only.

**The census is wider than the issue's nine `gp_Elips` sites**, because three separate families
have the same gap by three different mechanisms, and OCCT's own checks survive this build to three
different degrees:

| family | sites | what OCCT still rejects | what gets through |
|---|---|---|---|
| `gp_Elips`/`gp_Hypr`/`gp_Parab` constructed in a bridge TU | 11 | negatives and inverted ellipse radii: the constructor is `constexpr` in the header, so its `Standard_ConstructionError_Raise_if` runs here | zero |
| `GC_MakeEllipse`/`GC_MakeHyperbola` | 5 | negatives and inverted radii, via the maker's own status (`!IsDone()`) rather than the macro, which `No_Exception` deletes inside OCCT | zero |
| `Geom_Ellipse`/`Geom_Hyperbola`/`Geom_Parabola`/`Geom_Circle` setters | 6 | negatives, and an ellipse major below its own minor: these are a hand-written `if (...) throw`, not a macro, so `No_Exception` never touched them | zero |

That third row refines #487's rule rather than restating it: `No_Exception` voids the *macro*, not
every OCCT precondition. `Geom_Ellipse::SetMajorRadius` throws from inside OCCT's own translation
unit because the check is spelled by hand.

Zero satisfies every check any of the three writes (`minor < 0 || major < minor` is false for
`(0, 0)`), which is why it is the one degenerate input that arrived intact by every route.

**The sharpest case is `GC_MakeArcOfEllipse`'s two-point form**, where `IsDone()` is not merely
insufficient but actively misleading. That form inverts each endpoint back to a parameter, which
divides by the minor radius; at zero both bounds come back `NaN` and the maker still reports
success. The `if (!maker.IsDone()) return nullptr` line the bridge relied on therefore passed, and
`Curve3D.arcOfEllipse(…, from:to:)` returned a live curve whose parameter range was `[nan, nan]`
and whose every evaluation was `NaN`. Measured against the pinned kernel, with the identical call
on a healthy `(5, 3)` ellipse as the control:

| radii | `IsDone()` | resulting parameter range |
|---|---|---|
| `(5, 3)` | true | `[0, 3.14159]` |
| `(5, 0)` | true | `[nan, nan]` |
| `(0, 0)` | true | `[nan, nan]` |

**Every site was placed by asking #553's question, not by which OCCT class it calls.** #553 settled
whether a degenerate conic can be a meaningful *query* rather than a broken construction, and
answered it by probing whether OCCT actually returns the degenerate answer. Applied here the same
question splits this family in two, and the split does not follow the "pure query" line it looks
like it should:

- **The three `Extrema` entry points are guarded**, because OCCT does not answer the degenerate
  question: `Extrema_ExtPElC` reports `NbExt() == 0` against a `(0, 0)` ellipse rather than the one
  extremum at its centre, and `Extrema_ExtElC` reports `IsParallel()` regardless of what the line
  does. Same failure shape #553 measured across the `Gcc` families, and the same conclusion.
- **`BndLib` and `ElCLib` are excluded**, because they do answer it. `ElCLib::Value(1.0,
  gp_Elips(ax, 5, 0))` is `(2.70151, 0, 0)`, a point on the collapsed segment, which is exactly
  what that curve is; `BndLib::Add` returns the true box of it. Both are also `void` with nowhere
  to report a rejection, so guarding them would mean widening a signature in order to refuse an
  input OCCT handles correctly.

The second bullet is the one worth stating explicitly, because "it is only a query" is not the
reason — #553 has already shown that a query can be exactly where the wrong answer hides.

Also excluded, and pinned by a test so the exclusion stays deliberate: the four `GC_Make*`
three-point forms. They take no dimension at all, and OCCT's own status already rejects a
degenerate point triple (measured: coincident points, and an `S2` lying on the major axis, both
report `!IsDone()`).

No API signature changed, and nothing that used to succeed on valid input now fails. Every
affected entry point already had somewhere to say no: `nil` for the 13 factory and edge builders,
`false` for the 6 setters, and the existing `-1` error return for the 3 `Extrema` functions, which
the Swift layer already maps to `[]`.

26 tests in `Tests/OCCTCurveTests/Issue554Conic3dDegenerateTests.swift`. They were run against a
build with every guard stripped back out: 19 fail, and the 7 that pass are exactly the controls —
valid input still accepted, the negative and inverted cases OCCT already rejected, the three-point
forms, the ellipse major setter that `Geom_Ellipse`'s own `throw` already covered, and the
`BndLib`/`ElCLib` exclusion.

#### The null-handle guard, swept across the whole geometry-wrapper surface (#478)

#416 added the missing `IsNull()` guard to `OCCTCurve3DTransform` and #488 to
`OCCTSurfaceTransform`; #478 asked whether the same shape existed elsewhere rather than fixing a
third site alone. It did, in **14 bridge functions**, found by walking every function that takes an
`OCCTCurve3DRef` / `OCCTCurve2DRef` / `OCCTSurfaceRef` and dereferences the handle it carries:

| file | functions |
|---|---|
| `OCCTBridge_Curve3D.mm` | `StartPoint`, `EndPoint`, `Reverse`, `Copy`, `Period`, `FirstParameter`, `LastParameter` |
| `OCCTBridge_Geom2d.mm` | `Reverse`, `Copy`, `Transform` |
| `OCCTBridge_Surface.mm` | `Bounds`, `Copy`, `UPeriod`, `VPeriod` |

Each checked the wrapper pointer and then dereferenced the `Handle` inside it. Their own siblings,
in the same files, check both. `OCCTCurve3DStartPoint` and `OCCTCurve3DEndPoint` had no guard at
all, not even the wrapper. All 14 now open with `if (!x || x->handle.IsNull())`. These are
uncatchable: the enclosing `catch (...)` cannot intercept a signal, and the kernel's own
`Standard_NullObject` preconditions are compiled out of this `No_Exception` build.

**Still latent, and now measured rather than assumed.** All **228** sites that bind a handle into an
`OCCTCurve3D` / `OCCTCurve2D` / `OCCTSurface` wrapper were classified:

| how the handle is obtained | sites |
|---|---|
| a local the same function already `IsNull()`-checked | 97 |
| a maker result behind `IsDone()` | 58 |
| `new Geom_*` / `new GeomEval_*` / `new Bisector_*` (never null) | 50 |
| a `Copy()` / `Reversed()` down-cast | 18 |
| OCCT contract, built from an input already checked | 5 |

The last five are `GeomConvert_BSplineCurveToBezierCurve::Arc` (twice),
`GeomConvert_CompCurveToBSplineCurve::BSplineCurve`, `Geom2dConvert_ApproxArcsSegments::GetResult`
and `Geom_TrimmedCurve::BasisCurve`: each is constructed from a handle the caller checked, so none
can return null there, but that rests on the class's contract rather than a check at the site. No
bridge call hands back a wrapper carrying a null handle, so nothing here closes a reachable crash.
The cost asymmetry is the argument: one condition against a SIGSEGV.

The sweep also found a **second, larger class it does not fix**: 49 functions guard the wrapper and
then pass the unchecked handle to an OCCT API that dereferences it internally, 28 of them without
even the wrapper check (`Geom2dAdaptor_Curve adaptor(c->curve)`, `new Geom_TrimmedCurve(basis->curve,
...)`, and so on). Same crash, one hop further out, equally latent. Filed separately rather than
folded in here.

**Curve2D's two transform families now share one `buildTrsf2D`**, which is why its dispatcher had
drifted in the first place. It was the last of the three geometry types still duplicating the
construction, after `Curve3D` (#416) and `Surface` (#488). The five immutable functions
(`OCCTCurve2DTranslate`, `Rotate`, `Scale`, `MirrorAxis`, `MirrorPoint`) reached it through
`Geom2d_Geometry`'s per-operation convenience methods while the in-place `OCCTCurve2DTransform`
built its own `gp_Trsf2d`, composing the scale case by hand as
`SetScaleFactor(S)` + `SetTranslationPart(C * (1 - S))` where the other family used
`gp_Trsf2d::SetScale(C, S)`. Verified equivalent before switching, over factors
`{2.5, 0.25, 1, -1, -3, 0, 1e-9, 1e9}` against three centres including `(1e6, 1e-6)`: identical
scale factor, identical translation part, identical transformed coordinates, to the bit. They
disagree only on the internal `gp_TrsfForm` tag at `S = 1` and `S = -1`, which is a dispatch hint,
not a result.

Two new suites in `Tests/OCCTGeom2dTests`, because one is not enough. `Issue478Curve2DTransform`
`ParityTests` holds the two families together across all five kinds, on a segment and on a Bezier.
`Issue478Curve2DTransformGeometryTests` checks each transform against coordinates computed in
Swift, with no bridge call in the expectation. Both were run against injected defects: a
one-family drift fails the parity suite, while a defect inside the shared `buildTrsf2D` moves both
families identically and leaves the parity suite entirely green, failing only the geometry suite.
A parity assertion stops being evidence the moment the thing it compares becomes shared.

#### The other half of the null-handle sweep, and a checker so it stays swept (#556)

#478 fixed the 14 bridge functions that guard the wrapper pointer and then **dereference** the
`Handle` it carries. #556 is the class it deliberately left behind: functions that guard the wrapper
and then **pass** the unchecked handle to an OCCT API which dereferences it internally.

**60 functions, 73 (function, argument) pairs**, all now opening with
`if (!x || x->handle.IsNull())`:

| file | functions |
|---|---|
| `OCCTBridge_Surface.mm` | 22 |
| `OCCTBridge_Curve3D.mm` | 17 |
| `OCCTBridge_Geom2d.mm` | 14 |
| `OCCTBridge_Modeling.mm` | 4 |
| `OCCTBridge_Topology.mm` | 2 |
| `OCCTBridge_ProjLib_NLPlate.mm` | 1 |

The issue counted 49 functions across 5 files; the same walk, run again, finds 61 across 6.

**The issue's headline example is a false positive, twice over.** #556 opens with
`makeQualifiedCurve` (`Geom2dAdaptor_Curve adaptor(c->curve)`, "no guard at all"), and argues from
`Geom2dAdaptor_Curve.cxx:272` that `load` "has **no** null precondition at all [...] it is an
unconditional dereference in every build configuration". Lowercase `load` is private. Every caller
reaches it through the public `Load`, header-inline at `Geom2dAdaptor_Curve.hxx:108`, which opens
with a bare `if (theCurve.IsNull()) throw Standard_NullObject();`, not macro-guarded, so unlike the
kernel's precompiled `.cxx` preconditions it is *not* compiled out by `No_Exception`, which only
ever applied to the Release kernel build and never to bridge translation units. And all 12 of
`makeQualifiedCurve`'s call sites, across 7 functions, already reject both the null pointer and the
null handle before calling it. It is the one site in the whole sweep left unguarded, now with a
comment saying why: its return type (`Geom2dGcc_QualifiedCurve`, by value) has no null-safe
fallback, so the precondition has to live in the callers.

**The class is worse than "latent" elsewhere, though.**
[`Scripts/repro/556-null-handle-guard-sweep/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/556-null-handle-guard-sweep)
drives a null handle into all **35** distinct OCCT entry points these 60 functions call, each in a
forked child: **24 crash with an uncatchable signal**, 5 raise a catchable `Standard_Failure`, 6
return normally. `Geom2dAdaptor_Curve` is in the mild group. `new Geom_TrimmedCurve`,
`new Geom_OffsetCurve`, `new Geom_RectangularTrimmedSurface`, `ShapeAnalysis_Curve::IsPeriodic`,
`BRepLib_MakeEdge2d`, `GeomConvert::CurveToBSplineCurve`, `BRepAlgoAPI_Section` and
`ShapeConstruct_Curve::ConvertToBSpline` are not. `ShapeAnalysis_Surface` is the one to remember:
constructing it from a null handle returns normally and the crash lands at the first `ValueOfUV`, so
a probe that only constructed it would have cleared that entire 11-function family.

**Three findings the issue's own reproduction recipe could not reach**, because it walks scalar
parameters only:

- `OCCTCurve2DPointAt` is a **dereference** site (`curve->curve->D0(t, pt)`, with no guard at all)
  that #478's sweep missed outright. Fixed here rather than left for a third pass.
- Five functions take an *array* of wrappers. `OCCTGeomFillGordon` and `OCCTGeomFillGordonReport`
  checked `!profiles[i]` and passed the handle unchecked; `OCCTConcatenateCurves3D`,
  `OCCTConcatenateCurves2D` and `OCCTCurve3DJoinCurves` checked `curves[i]` inside the loop but
  never `curves[0]`, the element every one of them handles separately to seed the accumulator.
- `OCCTBridge_ProjLib_NLPlate.mm` was not in the issue's file list at all.

**The deliverable is the invariant, so it is now checked rather than remembered.**
`Scripts/check-null-handle-guards.py` is the same walk that produced both #478's list and this one,
committed alongside `check-bridge-index.py` and gating on exit status. Verified against two injected
regressions: reverting one guard, and adding a new function that checks only the pointer. It reports
both, and reports nothing on the fixed tree. `DownCast(x->handle)` is excluded as a use, since
down-casting a null handle returns null and every such site checks the cast result. Without that
exclusion the walk reports several hundred false positives.

Still latent: #478's classification of all 228 wrapper-producing sites holds, so no bridge call can
hand back a wrapper carrying a null handle today. What changed is the measured cost of weakening
that invariant later.

#### Fix: arc-length sampling aborted the process on a sample count it could not allocate (#479)

`EdgeCurve`/`WireCurve` `points(spacing:)` derived its sample count from the caller's spacing with a
lower clamp only, `max(2, Int((length / spacing).rounded()) + 1)`, and `points(count:)` then
allocated `count * 3` doubles from it. Neither end of that had an upper bound, and both failure
modes are a process abort rather than an empty array or a clamped result. Measured on a 200-unit
wire, one case per process:

| call | before |
|---|---|
| `points(spacing: 1e-9)` | count 2e11 + 1, i.e. a ~4.8 TB allocation |
| `points(spacing: 1e-18)` | `Fatal error: Double value cannot be converted to Int because the result would be greater than Int.max` |
| `points(spacing: 5e-324)` | same trap |
| `points(count: Int(Int32.max) + 1)` | trap: `Int32(count)` overflows the bridge's own count type |
| `points(count: Int.max)` | trap: `count * 3` overflows |

The last two need no spacing at all, so the bound belongs on `points(count:)`, where the allocation
is, and `points(spacing:)` has to derive its count without ever converting an out-of-range `Double`.
Both are now bounded by **`ArcLengthCurveAdaptor.maximumSampleCount`, 10 million points**, declared
once and shared by both types; the derivation stays in `Double` until it is known to be in range.
Anything past the ceiling returns an empty array, matching what `spacing <= 0`, a NaN spacing, a
zero-length curve and `count < 2` already did. There is deliberately no clamping: a request the
ceiling cannot honour fails visibly rather than coming back silently coarser than what was asked
for, which is the defect #501 found in the one sampler that did clamp.

The ceiling is a bound on the allocation, not on what is useful (one sample costs 24 bytes in the
packed bridge buffer plus 32 in the returned array), and it is honoured exactly, not aspirational:
at the ceiling, 10,000,000 points come back in 46 s at 624 MB resident, and 10,000,001 returns
empty. It is also two orders of magnitude below the `int32_t` the bridge takes its count in.

The hazard was pre-existing and duplicated: `EdgeCurve` and `WireCurve` each had their own copy of
the body until #422 moved it verbatim into the shared extension. Both `points(count:)`
implementations now delegate their allocation, count contract and unpacking to one
`sampledPoints(count:_:)` skeleton, which also brings them onto `unpackSIMD3` (#419), the two sites
the shared unpack helper had never reached.

**The same shape is live at fourteen other sampling entry points** across `Curve3D`, `Curve2D`,
`Edge`, `Surface`, `Shape` and `BRepGraph`: every one of them traps at `Int(Int32.max) + 1`, and the
eight `Curve2D`/`Curve3D` ones trap on a *negative* count too, inside `[Double](repeating:count:)`
itself, despite documenting "must be at least 2, else empty". Measured one case per process, not
assumed. Filed as #558 rather than widened into this fix: `maxPoints` on an adaptive algorithm is a
capacity rather than a request, and `uSamples`/`vSamples` bound a product, so those need a contract
decision per parameter rather than this one's ceiling applied uniformly.

> **Corrected by #558**: the family is twenty-eight entry points, not fourteen — this census missed
> half of it, including `Edge.quasiUniformParameters(count:)`, the same method on the same OCCT
> class as the `Curve3D` one it did name. The `drawMesh` row of its table is also wrong: a negative
> count only survives when it is passed to *both* factors, where the two negatives multiply to a
> plausible positive total. See the #558 entry above.

#### The knot-splitting continuity cap, on the four fifths of the family #398 did not reach (#480)

#398 established that a knot-splitting continuity documented as `0=C0, 1=C1, 2=C2` lists every
value that does nothing on ordinary cubic geometry: the analyzers split a knot only when
`degree - multiplicity < ContinuityRange`, and a cubic with simple interior knots is already C2
there. It widened `Curve3D.continuityBreaks` to `ParametricContinuity`, whose `.c3` is reachable.
The rest of the family kept the cap, and a census by OCCT class rather than by the issue's site
list found more of it than the issue named: **four** analyzers, **nine** public Swift entry points,
eight still typed `Int` and still documenting the range that does nothing.

All of them now take `ParametricContinuity`:

| API | was | now |
|---|---|---|
| `Surface.knotSplitting(uContinuity:vContinuity:)` | `Int = 1, Int = 1` | `.c1, .c1` |
| `LawFunction.knotSplitting(continuityOrder:)` | `Int = 2` | `.c1` |
| `LawFunction.knotSplitParameters(continuityOrder:)` | `Int = 2` | `.c1` |
| `Curve2D.splitIndicesAtDiscontinuities(continuity:)` | `Int = 1` | `.c1` |
| `Surface.bsplineKnotSplitsU/V(continuity:)`, `Surface.bsplineKnotSplitValues(continuity:)` | `Int` | `ParametricContinuity` |
| `Curve2D.bsplineKnotSplits(continuity:)`, `Curve2D.bsplineKnotSplitValues(continuity:)` | `Int` | `ParametricContinuity` |

**Source-breaking:** callers passing integer literals need the spelled case (`0` → `.c0`). That is
the point: the raw `Int` is what let a documented range consisting entirely of no-ops go unnoticed
for five releases.

The defaults were revisited and deliberately left at `.c1`, now uniform across the family (the two
law methods moved from 2). Measured on a cubic with four interior knots: at `.c1` a
multiplicity-3 knot (a genuine kink) is reported and nothing else is; at `.c3` *every* interior
knot is reported, which is a Bezier decomposition rather than a discontinuity report. So `.c1`
answers "where does this actually kink", which is the question a default should answer, and the
fix for the issue is that `.c3` is now spellable, not that it is now the default.

Also measured, and now documented rather than left implicit: all four analyzers
(`GeomConvert_BSplineCurveKnotSplitting`, `Geom2dConvert_BSplineCurveKnotSplitting`,
`GeomConvert_BSplineSurfaceKnotSplitting`, `Law_BSplineKnotSplitting`) run a byte-identical
algorithm and agree on every count; the useful domain is `0...degree` and saturates there, so on a
degree-5 BSpline nothing below `.c5` reaches a simple interior knot and `.c3` is the strictest
question this vocabulary can ask (`toBezierSegments()`/`toBezierPatches()` is the dedicated API for
the every-knot split at the far end of that ladder); and a negative range throws
`Standard_RangeError` through an explicit `throw` rather than a `*_Raise_if` macro, so unlike most
OCCT preconditions it survives this kernel's `No_Exception` build and reaches the bridge's
`catch(...)`.

Two doc corrections found on the way: `Surface.knotSplitting` was attributed to
`BSplSLib::KnotSplitting`, which is not what it calls, and the bridge header still documented the
`0=C0, 1=C1, 2=C2` range on `OCCTCurve3DBSplineKnotSplits`, the one function #398 had already
fixed on the Swift side.

New tests pin the measured contract in all three affected domains rather than the signature, so
they also catch the opposite mistake of decoding the enum to a `GeomAbs_Shape` first: `GeomAbs_C2`
is ordinal 4, which would split at every knot where `.c2` must split at none. Both mistakes were
injected and confirmed to fail the new cases.

#### One pipe shell, and the sweep mode it was quietly discarding (#503)

Four bridge functions each built their own single-profile `BRepOffsetAPI_MakePipeShell`, and each
was `OCCTShapeCreatePipeShellMultiSection` with `profileCount = 1` and some arguments nailed shut.
Confirmed rather than assumed: OCCT's `Add(profile)` is `Add(profile, false, false)` by default
argument, and the two spellings produce byte-identical BREP. All four are gone. Every `Add()`-based
pipe sweep is now one function, and the workaround comment `SetIsBuildHistory(false) // avoid SEGV
on closed spine+profile` went from six pasted copies to one.

Two of the four accepted an `OCCTPipeMode` they could not express. Their mode switch had a case for
`FixedBinormal` and `Auxiliary` that fell through to `SetMode(Standard_False)`, plain Frenet, and
returned the resulting solid as a success. At the C level that branch was unreachable from Swift,
but the same defect had already surfaced in the public API:
`Shape.pipeShellWithTransition(mode: .fixed(binormal:))` swept Frenet. Measured on an S-curve spine
with a 5×3 rectangular section: 180.287 requested as a fixed binormal, where the fixed binormal
builds 149.999. **A straight spine will not show this**: with no torsion the modes coincide
exactly, which is how it survived a suite that only ever swept straight lines and gentle arcs.

A mode whose own argument is unusable now fails the call instead of substituting a different mode:
`.fixed(binormal: .zero)` and an auxiliary spine OCCT rejects both return `nil`.

Three things became reachable that were not, all of which change the output rather than being
inert knobs:

| control | was | measured effect |
|---|---|---|
| `transition:` on a multi-section sweep | single-profile only | 113.05 / 256.65 / 240.53 for transformed / rightCorner / roundCorner |
| `withContact:` / `withCorrection:` on a single-profile sweep | multi-section only | correction re-orthogonalises a tilted section: 205.208 → 251.327 |
| `.auxiliary(spine:)` with one profile | untested, no coverage anywhere | builds, and differs from Frenet |

**API changes.** `Shape.pipeShell` gains `transition:`, `withContact:` and `withCorrection:`;
`Shape.pipeShellMultiSection` gains `transition:`. All default to the previous behaviour, so no call
site changes. `Shape.pipeShellWithTransition` is **deprecated** (it is now `pipeShell` with one
argument set) and forwards, honouring every mode. `Shape.pipeShellWithLaw` keeps its own entry
point, since `SetLaw` is not an `Add()` sweep and OCCT's header warns against combining the two; it
shares the build tail.

Verified by capturing every pipe-shell call path's volume, area and face count before the change and
re-running after: every figure is identical except `pipeShellWithTransition(mode: .fixed(...))`,
which moved to the value its non-transition sibling already produced. The new tests were also run
against a deliberately reintroduced fall-through: 4 of 8 fail, naming the substituted mode.

#### Breaking: the junction analysers now say what they measured, and stop reporting what they did not (#495)

**Source-breaking, in one place:** `Curve3D.ContinuityAnalysis` and `Surface.ContinuityAnalysis`
expose `isC0`/`isG1`/`isC1`/`isG2`/`isC2` as `Bool?` rather than `Bool`. `nil` means "the order you
asked for never measured this class". [`SEMVER.md`](SEMVER.md#recorded-exception-v1170-2026-07-29)
records the exception; a shim is impossible, because Swift does not overload a property on its type.

`LocalAnalysis_CurveContinuity` and `LocalAnalysis_SurfaceContinuity` run exactly one branch of a
switch on the order they are constructed with, and only that branch's quantities are ever computed.
Every other predicate then compared a member still at its `0.0` initialiser against a tolerance and
answered `true` whatever the geometry did. A sharp 90° corner analysed at order C0 reported
`isC2 == true`, with `c2Angle == 0.0` — a perfect second-derivative match — to go with it. The five
branches are cumulative only along their own ladder, and **no order measures all five**, not even
the `.c2` default, which never looks at G1 or G2:

| order | measures |
|---|---|
| `.c0` | C0 |
| `.g1` | C0, G1 |
| `.c1` | C0, C1 |
| `.g2` | C0, G1, G2 |
| `.c2` | C0, C1, C2 |

```swift
// Before — compiles, and lies. The .c2 default never computes G1.
if analysis.isG1 { … }

// After — ask for what you want measured, and nil says when you did not.
let a = c1.continuityWith(c2, u1: e1, u2: s2, order: .g1)!
a.holds(.g1)   // Optional(true)
a.holds(.c1)   // nil — .g1 does not measure C1
a.measured     // [.c0, .g1]
```

The angle and ratio outputs are gated the same way: an unmeasured class now reports `-1` (the
"not applicable" value those fields already used) instead of `0.0`. `flags` is masked to the
measured set, and `measured`/`holds(_:)` are the new way to read it.

Three more things fell out of the same audit, none of them source-breaking:

- **`ContinuityAnalysis.status` was never a measurement.** `ContinuityStatus()` returns the order
  the analyser was constructed with, verbatim. It is now `order: ContinuityClass`, documented as
  the request after saturation, which is the one thing it can honestly report; `status` remains as
  a deprecated `Int` shim. Every test that touched it asserted `status >= 0`, which is why the echo
  went unnoticed.
- **`order:` is typed.** `Curve3D.continuityWith` and `Surface.continuityWith` took a raw
  `Int = 4`, the last two continuity parameters #398/PR#436 did not reach — a caller could pass
  `5`, `-1` or a value borrowed from an unrelated continuity enum and be clamped without being
  told. Both now take a `ContinuityClass = .c2`, with a deprecated `Int` overload that decodes
  identically.
- **`Shape.continuityOfFaces` documented its own return values wrong.** Its comment said
  `5=CN`; CN is ordinal 6, and 5 (C3) is a value `BRepLib::ContinuityOfFaces` cannot return at all.
  The function was always right — it casts the enum straight through, so there was no lookup table
  for the comment to be describing — but a caller matching `5` for "smooth" never matched anything,
  and one receiving `6` had no documented meaning for it. Same wrong string had been copied into
  the bridge header and the Swift doc comment.
  `continuityClassOfFaces(edge:face1:face2:tolerance:) -> ContinuityClass?` is the typed
  replacement; the `Int` spelling is deprecated, not changed.

Measured, not inferred: a box edge reports `.c0`, a filleted box's blend joins report `.g1`, a
cylinder seam reports `.cN` (ordinal 6), and `.c3` appears nowhere. Also pinned by test, since the
default order walks straight into it: the `.c2` branch needs a non-zero second derivative in both
parametric directions, so `Surface.continuityWith` at the default returns `nil` for a plane (none in
either direction) and for a cylinder (none along its axis) — ask for `.c1` or `.g1` on planar or
ruled geometry. Six pre-existing tests across three targets asserted nothing at all because of
these two facts together, and now assert the measurements.

Bridge and Swift only: no kernel patch, no `OCCT.xcframework` rebuild.

#### The point-to-curve projection family finally has one answer for "there isn't one" (#500)

`Curve2D.parameterAtPoint(_:)` was a fifth `Geom2dAPI_ProjectPointOnCurve` construction that #413's
unification never reached, and it had invented a third failure convention, worse than either of
the two #413 replaced. Where a point has no projection at all (one beyond the ends of a bounded
curve, or a circle's centre, which is equidistant from every point on it), it returned the curve's
own `firstParameter`: a real parameter inside the curve's own domain, indistinguishable from a
genuine result. Whether that was right depended only on which end you fell off.

The 3D side turned out to be worse, and the audit's own "adjacent, systemic" note undersold it.
`Curve3D.parameterAtPoint(_:)` and `Curve3D.closestParameter(to:)` are two public spellings of the
same computation, each with its own `GeomAPI_ProjectPointOnCurve`, and they *disagree*: one answers
`firstParameter`, the other `0`. On a curve trimmed to `[3, 8]`, `0` is not even in the domain.
Both old tests used a curve starting at parameter 0, where the two answers coincide, which is how
the disagreement survived. There was no shared 3D helper at all: the 2D side got one in #413, the
3D side never did.

```swift
let seg = Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0))!.trimmed(from: 3, to: 8)!

// Before: same question, three answers, none of them sayable as "no projection".
seg.parameterAtPoint(SIMD3(100, 0, 0))     // 3.0  the far end of the curve
seg.closestParameter(to: SIMD3(100, 0, 0)) // 0.0  outside the domain entirely

// After.
seg.nearestParameter(to: SIMD3(100, 0, 0)) // nil
seg.nearestParameter(to: SIMD3(5, 2, 0))   // 5.0
```

**Not source-breaking.** `Curve2D.nearestParameter(to:)` and `Curve3D.nearestParameter(to:)` are
new and return `Double?`; all three old spellings remain as deprecated shims. Their *behaviour*
changes in the no-projection case only: they now return `.nan`, the one `Double` that is not a
legitimate parameter on some curve, instead of three different plausible-looking values. Code that
was reading a real answer reads the same real answer.

Bridge-side, `OCCTCurve2DParameterAtPoint` now routes through `occtNearestProjectionOnCurve2d`
(five entry points, one construction), and the 3D side gains the `occtNearestProjectionOnCurve3d`
it never had, shared by `OCCTCurve3DNearestParameter` and `OCCTExtremaLocateOnCurve`'s full-range
fallback. `OCCTCurve3DClosestParameter` is gone.

`Curve3D.projectPoint(_:precision:)` is deliberately *not* folded in: it runs
`ShapeAnalysis_Curve::Project`, a different algorithm that always answers by adjusting to the
curve's ends. A test now pins that distinction so a later pass does not "unify" two things that
genuinely compute differently.

Three cross-reference index entries in `OCCTBridge.h` were corrected along the way. The staleness
the audit blamed for the miss was real, and worse than reported. `Geom2dAPI_ProjectPointOnCurve`
listed four of its five entry points; `GeomAPI_ProjectPointOnCurve` listed exactly one function,
which does not use it (`OCCTCurve3DProjectPoint` calls `ShapeAnalysis_Curve`), and none of the five
that do; and `ShapeAnalysis_Curve` named three functions that do not exist under those names.

Bridge and Swift only: no kernel patch, no `OCCT.xcframework` rebuild.

#### One free-bounds analyser, and the double-`perform()` bug the second one hid (#504)

`ShapeAnalysis_FreeBoundsProperties` was wrapped twice. The v0.49.0 family behind `Shape`'s five
`…FreeBound…` methods rebuilt the whole analyser and re-ran `Perform()` on every single call, so
a per-bound report cost one full free-bound search *per bound*; the v0.114.0 family behind
`FreeBoundsProperties` analysed once and answered every query from that result. The two also took
opposite index bases in the C layer, 0-based on one side and 1-based on the other for the same
conceptual parameter, with neither declaration saying the other existed. Both Swift wrappers
compensated correctly, so nothing was visibly broken; a third caller written against either C
function by analogy with the other would have been off by one with no diagnostic.

Consolidating them turned up a real bug that only the newer family could reach. OCCT's `Perform()`
*appends* to its two result sequences and never clears them, and `Init()` does not clear them
either; only the constructors allocate them. `FreeBoundsProperties.perform()` is public and
`@discardableResult`, so calling it twice doubled every count and every notch:

```swift
let props = FreeBoundsProperties(shape: opened, tolerance: 1e-3)!
props.perform(); props.closedCount   // 2
props.perform(); props.closedCount   // 4   (before #504)
props.perform(); props.closedCount   // 6
```

The stateless family could not hit it, because each of its calls built a fresh analyser. It is
latched in the bridge now, and `perform()` is optional as well as idempotent: every accessor runs
the analysis on demand, so forgetting it no longer reads as "this shape has no free bounds".

**Not source-breaking.** `Shape.freeBoundsAnalysis(tolerance:)`, `closedFreeBoundInfo`,
`openFreeBoundInfo`, `closedFreeBoundWire` and `openFreeBoundWire` keep their signatures and now
run on the shared analyser. `FreeBoundsProperties` keeps all eight of its accessors and gains
`totalCount`, `info(_:at:)` and `wire(_:at:)`, which take a `BoundKind` (`.closed` / `.open`) and
give the open side the `ratio`, `width` and `notchCount` only the closed side used to expose.

An out-of-range index is now a real answer rather than a guess. `Shape`'s info methods used to
infer it from `perimeter > 0`, so a genuine zero-perimeter bound would have read as "no such
bound", and the `FreeBoundsProperties` accessors did not range-check at all, letting the index reach
`NCollection_Sequence::Value` and come back 0 from a catch-all. Both are checked in the bridge
against the sequence length, and both report it as `nil` (or `0`, for the `Double` accessors).

Two OCCT behaviours are documented and pinned by tests, having been found while measuring this:

- **`ratio` is an aspect ratio**, contour length over contour width: 2 for a 20×10 bound. Both
  `OCCTBridge.h` and `Shape.FreeBoundInfo` called it `area / perimeter²`, which for that bound is
  0.0556. OCCT solves it from the area and the perimeter, and leaves *both* `ratio` and `width` at
  0 when that solve has no real root, which an exactly **square** bound hits by one ulp, sitting
  precisely on the branch boundary. So 0 means "not solvable", not "degenerate contour", and a
  square is the one fixture that must not be used to test either field.
- **`Perform()` is not a success signal.** It returns
  `DispatchBounds() | CheckNotches() | CheckContours()`, and `CheckNotches()` returns `true`
  unconditionally, so it is `true` for a shape with no free bounds at all and for one that was
  never loaded, the opposite of its documented "False if fail or no free bounds are found".
  `IsLoaded()` is what the bridge checks instead.

The C family is 18 functions down to 6. `OCCTBridge.h`'s cross-reference index entry for the class
named `OCCTShapeFreeBoundsAnalysis*`, a prefix that has never existed anywhere in the codebase; it
names the real family now. `ShapeAnalysis_FreeBounds` (the similarly-named sibling class behind
`Shape.freeBoundsClosedWires` and friends, easy to conflate and genuinely different) gains the
index entry it never had.

Bridge and Swift only: no kernel patch, no `OCCT.xcframework` rebuild.

#### One continuity decoder per vocabulary, not nineteen (#490)

Continuity reached OCCT as a plain integer through 19 separate decoders: seven independently-named
`static` helpers (14 copies across five `.mm` files), six switches written inline in the function
that needed them, and one dead copy kept alive only so a stub could take its address to silence an
unused-static warning. They disagreed, and not hypothetically — #433 already shipped a broken fill
from exactly this, and two more pairs were still live:

- **`Shape.bsplineRestrictionAdvanced` vs `Shape.bsplineRestriction`.** Both drive a
  `ShapeCustom_BSplineRestriction` through `BRepTools_Modifier` (the static
  `ShapeCustom::BSplineRestriction` the plain entry point calls is itself just that), but the
  advanced one read its argument as a `GeomAbs_Shape` ordinal, so `2` asked for C1 where its
  sibling asked for C2. Worse than a mismatch: of the seven values that reading advertised, only
  0, 2 and 4 ever worked — `ShapeCustom_BSplineRestriction` returns a null shape for G1, G2, C3 and
  CN, so `continuity3d: 1` silently failed every call. The parameters are now
  `ParametricContinuity`, matching the sibling exactly, with a deprecated `Int` overload that
  decodes the same way and says so.
- **`Surface.splitSurfaceByContinuity` vs `Surface.splitByContinuity`** (found while auditing this
  issue, not named in it). Both wrap `ShapeUpgrade_SplitSurfaceContinuity`; `criterion: 2` asked
  one for C1 and the other for C2, an observable difference in the returned split counts.

There are exactly three vocabularies, each now decoded in exactly one place
(`OCCTBridge_Internal.h`) and named after the Swift enum that feeds it: `SurfaceContinuity`
(geometric constraint order, 0=G0/1=G1/2=G2), `ParametricContinuity` (0=C0…3=C3) and the analysis
order the `LocalAnalysis_*` junction analysers speak in both directions (a `GeomAbs_Shape` ordinal,
0=C0/1=G1/2=C1/3=G2/4=C2). All three saturate at the top of their own vocabulary, replacing three
different out-of-range fallbacks (`GeomAbs_CN`, `GeomAbs_C2`, `GeomAbs_C1`) — the same invalid
integer used to mean different things depending only on which entry point received it. The
analysis-order ceiling is measured, not arbitrary: asking `LocalAnalysis_*` for C3 or CN leaves
every predicate reporting true, so C2 is the strictest question those classes can answer.

One user-visible consequence beyond the three divergences, for callers passing a raw `Int` outside
the documented range: that input used to land on whatever fallback the local copy happened to
carry, which for most of them was a valid, working continuity (usually C2), so an out-of-contract
call quietly succeeded. It now saturates to CN, and the `Approx*` consumers fail on CN, so
`Curve3D/Curve2D/Surface.approximated(continuity: 99)` returns `nil` where it previously returned a
C2 approximation. Deliberate — a request the operation cannot honour should not silently become a
different request — and covered by test. Values inside each documented domain are unaffected.

Also from this pass, all measured against the pinned kernel and now documented and tested rather
than left to be rediscovered: the `GeomConvert`/`Geom2dConvert` `Approx*` family accepts C0/C1/C2
only (`AdvApprox` throws above C2, surfacing as `nil`), while the `PointsToBSpline` family accepts
the whole ladder without failing; `Curve3D.approximate(points:)`'s reference page documented the
wrong vocabulary entirely (the analysis order, which that call has never used); and
`BRepGraph.setEdgeRegularity` is a stub that always returns `false` and never reads its continuity
argument — its only test discarded the result and asserted nothing, so that had gone unnoticed since
the OCCT 8.0.0 GA upgrade. Now asserted, documented, and tracked for resolution in #513.

Bridge-only plus doc/signature changes: no kernel patch, no `OCCT.xcframework` rebuild.

#### Two upstream OCCT null-context SIGSEGVs, patched and filed (#484)

Auditing every `ShapeFix_Face` call site turned up two unpatched, never-filed crashes of the same
class as #317: `ShapeFix_ComposeShell::Perform()`, `ShapeFix_ComposeShell::SplitEdges()` and
`ShapeUpgrade_WireDivide::Perform()` dereference their `ShapeBuild_ReShape` context
unconditionally, and that context is null unless the caller made an optional `SetContext()` call. A
plain 4-edge planar square face crashes both classes 100% of the time. Both are the odd ones out in
their own package: `ShapeUpgrade_FaceDivide::Perform()`, their only in-kernel driver, self-creates a
context and hands it down, and nine other healing classes carry the same guard.

Carried as `Scripts/patches/0017-*` and filed upstream as
[OCCT#1409](https://github.com/Open-Cascade-SAS/OCCT/issues/1409) (repro) /
[OCCT#1410](https://github.com/Open-Cascade-SAS/OCCT/pull/1410) (fix). Verified via the override-link
technique: both no-context cases SIGSEGV before and complete after, and the with-context path is
byte-identical before and after (BREP dump hash plus topology counts, planar and cylindrical). Takes
effect at the next xcframework rebuild; nothing regresses in the interim because the bridge already
sets a context at both call sites. Reproducer and writeup:
[`Scripts/repro/484-null-reshape-context/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/484-null-reshape-context).

#### `Face.fixed(tolerance:)` now heals what it claims to (#484)

`OCCTFaceFix` was the fourth `ShapeFix_Face` construction in the bridge and the only one the #317
pass missed — it built a bare fixer with no context, so the fixes that record replacements silently
did nothing (and on any kernel without `Scripts/patches/0005` it was exposed to the #317 null-deref).
On the raw #317 shape, no context yields a `BRepCheck`-invalid face with no apex edge; with a context
it is valid. Well-formed faces are unaffected.

#### `Shape.connectedFaces(tolerance:)`: every shell, not just the first (#484)

The function had **zero** test coverage repo-wide. Writing it surfaced a first-of-N defect of the
#439/#442/#443 family: only the first shell an explorer yielded was connected and the rest were
dropped, so a compound of two boxes came back with 6 faces instead of 12. Every shell is now
processed and the results reassembled through the shared `occtSolidBodiesToShape` helper — a
single-shell input still returns a bare shell, and the nil-on-failure contract is unchanged.

#### Two stale cross-reference index entries corrected (#484)

`OCCTBridge.h`'s index mapped `ShapeFix_Face → OCCTShapeFixFace` and
`ShapeFix_FaceConnect → OCCTShapeFixConnect*`. Neither symbol exists anywhere in the codebase, so
anyone using the index to find every `ShapeFix_Face` call site for a #317-class re-audit got zero
hits — which is how the unpatched fourth site above went unnoticed. They now name the real symbols:
`OCCTFaceFix`, `OCCTFaceFixer*` and the two `OCCTShapeCreateFaceFromSurfaceWire*` functions; and
`OCCTShapeFixFaceConnect`, a single function rather than a family.

New `Scripts/check-bridge-index.py` checks every index entry against the real symbols and exits 1 on
any mismatch. Its first run showed the two #484 entries are not isolated: **139 of the index's 418
symbol references name symbols that exist nowhere in `Sources/`**. Filed as #510 rather than fixed
here — each stale entry needs its real call site identified, and inventing a plausible name for a
class that has no wrap would be worse than leaving the entry visibly broken.

#### Analytical conversion: one path per converter class, and the result no longer aliases its input (#492)

`GeomConvert_CurveToAnaCurve` and `GeomConvert_SurfToAnaSurf` each had two wrapper families, added
eight releases apart, making the identical OCCT call and then disagreeing about the answer. The
v0.30.0 curve wrapper hardcoded the curve's own parameter range and discarded `newFirst`/`newLast`/
`Gap()`; the v0.30.0 surface wrapper carried an "already analytical" guard its v0.78 sibling never
grew. Five bridge functions now reach two shared helpers, `occtCurveToAnalytical` and
`occtSurfaceToAnalytical` (`OCCTBridge_Internal.h`), and `OCCTCurve3DToAnalytical` /
`OCCTSurfaceToAnalytical` are gone.

**The behaviour fix, which the issue did not predict.** Probing both converters against the pinned
kernel showed they do opposite things with an already-analytical input, and only one wrapper family
had been written for either. `GeomConvert_SurfToAnaSurf` always allocates
(`GeomConvert_SurfToAnaSurf.cxx:791-807`), so the surface guard was dead code. But
`GeomConvert_CurveToAnaCurve` returns **the input handle itself** — `ComputeLine` and `ComputeCircle`
down-cast the input and return it — and for a `Geom_TrimmedCurve` it returns the basis curve the trim
still holds. Both curve wrappers handed that shared curve to Swift as a separate `Curve3D`, so the
two aliased one `Geom_Curve` and `Curve3D.translate` is in-place: translating the result of
`Curve3D.circle(...).toAnalytical()` by 100 moved the source circle by exactly 100. Both helpers now
detach the result with `Copy()`, so the guarantee holds for both classes rather than depending on
which branch of which kernel version happens to allocate. The results are line/circle/ellipse and
plane/cylinder/cone/sphere/torus, so the copy costs nothing.

The contract is now stated once and identical on both sides: an already-analytical input **converts**
(`gap == 0` exactly) rather than being rejected, the result is independent of the input, and null
input, unrecognisable input and OCCT's own throw (the bounded overload raises
`Geom_BSplineSurface::Segment` on inverted UV bounds) are one failure outcome.

New: `Curve3D.toAnalyticalWithGap(tolerance:)`, the full-range curve spelling that reports the gap —
the counterpart of `Surface.toAnalyticalWithGap(tolerance:)`, previously missing, which is why
getting a curve's gap meant switching wrapper families. No other public Swift signature changed.

New `AnalyticalConversionContractTests` (`Tests/OCCTCurveTests`) pins all of it: 12 tests, of which
the two aliasing cases fail by exactly 100.0 against the pre-#492 bridge. It also gives
`toAnalyticalWithGap(tolerance:uMin:uMax:vMin:vMax:)` its first coverage of any kind. Probe and
writeup: [`Scripts/repro/492-analytical-conversion/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/492-analytical-conversion).
`GeomConvert_CurveToAnaCurve` and `GeomConvert_SurfToAnaSurf` also gained the cross-reference index
entries they never had.

#### The 2D conic factories reject degenerate dimensions, like their siblings already did (#487)

**Behaviour change.** `Curve2D.ellipseFromCenterDir`, `Curve2D.hyperbolaFromCenterDir` and
`Curve2D.parabolaFromCenterDir` now return `nil` for dimensions that cannot describe the curve they
name, matching the direct factories (`Curve2D.ellipse`, `Curve2D.hyperbola`, `Curve2D.parabola`) they
are geometrically identical to. Previously they had no precondition at all and returned a live,
degenerate curve:

| call | before | now |
|---|---|---|
| `ellipseFromCenterDir(majorRadius: 0, minorRadius: 0)` | ellipse whose every point is its centre | `nil` |
| `ellipseFromCenterDir(majorRadius: 8, minorRadius: 0)` | ellipse with a zero minor radius | `nil` |
| `ellipseFromCenterDir(majorRadius: 5, minorRadius: -3)` | ellipse reporting `MinorRadius() == -3` | `nil` |
| `hyperbolaFromCenterDir(majorRadius: 0, minorRadius: 0)` | degenerate hyperbola | `nil` |
| `hyperbolaFromCenterDir(majorRadius: 6, minorRadius: 0)` | degenerate hyperbola | `nil` |
| `parabolaFromCenterDir(focal: 0)` | parabola collapsed to a line | `nil` |

Valid input is unaffected: both families still build the same curve, verified pointwise. Equal
ellipse radii stay valid, and a hyperbola with its minor radius larger than its major stays valid,
since neither is degenerate.

This is the same gap #399 closed for the four 3D conics and #411 closed for the 2D circle. Neither
pass reached the 2D ellipse, hyperbola or parabola, because the predicate had been copied rather than
shared: #399 left four `static inline` helpers in `OCCTBridge_Curve3D.mm`, #411 added a
byte-equivalent fifth (`occtValidCircle2dRadius`) in `OCCTBridge_Geom2d.mm`, and the 2D direct
factories spelled the same conditions inline in six more places. All twelve now call one of four
definitions in `OCCTBridge_Internal.h`. A conic's radii do not depend on whether it lives in a plane
or in space, so there is nothing for a 2D copy to say differently.

Worth recording for future audits of this kind: **no precondition inside the OCCT library is
load-bearing in this build.** Every one is written as a `*_Raise_if` macro, and the pinned
`OCCT.xcframework` is a Release build, where OCCT's own `BUILD_RELEASE_DISABLE_EXCEPTIONS` (default
ON) defines `No_Exception` and expands all of them to nothing inside OCCT's translation units. That
is why `gce_MakeElips2d(ax, 5, -3)` reports `gce_Done`: its own two checks do not cover that input,
and `gp_Elips2d`'s check, which does, is not compiled. The bridge's `.mm` files are built without
that macro, so the identical constructor called from the bridge does throw. For the hyperbola and
parabola cases the divergence was never an OCCT accept/reject asymmetry at all: OCCT accepts
`(0, 0)` and `focal == 0` through both routes, and rejecting them is entirely this bridge's contract.

Six more `OCCTBridge_Geom2d.mm` sites build a 2D conic from caller dimensions with no precondition
(`OCCTConvertEllipseToBSpline2D`, `OCCTConvertHyperbolaToBSpline2D`, `OCCTConvertParabolaToBSpline2D`,
`OCCTMakeEdge2dEllipse`, `OCCTMakeEdge2dEllipseArc`, `OCCTConic2dFromEllipse`) and none of their
downstream algorithms self-reject: a zero-radius ellipse yields a 5-pole BSpline, an edge reporting
`IsDone()`, and six zero conic coefficients respectively. Filed as #514 rather than swept in here;
two of them have no nil channel to report a rejection through and each needs its own contract
decision.

#### One result vocabulary for measured continuity, not three encodings (#485)

`OCCTCurve3DContinuity` / `OCCTCurve2DContinuity` / `OCCTSurfaceContinuity` and their
`*GetContinuity` siblings wrapped the identical `Geom*::Continuity()` call but reported it
through two incompatible numeric schemes. **C0 was the only class the two agreed on:**

| class | `GetContinuity` (real `GeomAbs_Shape`) | `Continuity` (hand-written switch) |
|-------|---------------------------------------|------------------------------------|
| C0 | 0 | 0 |
| G1 | 1 | −2 |
| C1 | 2 | 1 |
| G2 | 3 | −3 |
| C2 | 4 | 2 |
| C3 | 5 | 3 |
| CN | 6 | 99 |

Neither doc comment described either scheme correctly. `GetContinuity`'s claimed
`0=C0, 1=C1, 2=C2, 3=C3, 4=CN, 5=G1, 6=G2`, which is not what a `static_cast` of
`GeomAbs_Shape` produces; `Continuity`'s omitted its own `−2`/`−3`/`99` values entirely. Both
wrong comments had been copy-pasted into the Swift layer.

**Behaviour change.** `Curve3D.continuityOrder`, `Curve2D.continuityOrder` and
`Surface.surfaceContinuityOrder` now report the real `GeomAbs_Shape` ordinal. A C2 curve that
answered `2` answers `4`; a CN curve that answered `99` answers `6`; a G1 curve that answered
`−2` answers `1`. All three are deprecated in favour of `continuityClass`. Any threshold check
of the form `continuityOrder >= someOrder` needs revisiting — that idiom compared two different
encodings, which is the defect this family invited.

**Behaviour change (C API only).** `OCCTCurve3DContinuity`, `OCCTCurve2DContinuity` and
`OCCTSurfaceContinuity` returned `-1` for a null argument and now return `0`, matching the
`*GetContinuity` convention they delegate to. `0` is not distinguishable from a genuine C0
measurement; a caller needing to tell "null" from "C0" must null-check before calling. This
follows the family's existing convention rather than inventing a fourth sentinel, and all three
declare `_Nonnull` arguments, so passing null was already a contract violation. No Swift API is
affected — `Curve3D`/`Curve2D`/`Surface` cannot hold a null handle reference.

- **Bridge:** the three `switch` bodies were byte-identical to each other and each duplicated
  its `GetContinuity` sibling's one-line body. All three now delegate to that sibling, which
  also picks up the `.IsNull()` handle guard the `Continuity` family was missing: they checked
  only the wrapper pointer, then dereferenced the inner `Handle`, which the wrapper's own
  default constructor (`OCCTCurve3D() {}`) leaves null — so this was reachable, not theoretical,
  and a null `Handle` deref is an OS signal the surrounding `catch (...)` cannot intercept. The
  C declarations are retained for ABI compatibility.
- **Swift:** new top-level `ContinuityClass` is the shared result vocabulary — the third
  contract `Continuity.swift` already documented after #398 but had only half-implemented.
  `Surface.Continuity` becomes a deprecated alias of it (raw values unchanged), and `Curve3D` /
  `Curve2D` gain `continuityClass`; they previously had no typed form at all.
  `ContinuityClass` is `Comparable` by increasing smoothness, and adds `derivativeOrder` and
  `satisfies(_:)` so a continuity floor can be checked without comparing raw values across
  vocabularies. `g1`/`g2` correctly satisfy no parametric order.
- **Tests:** 17 across `OCCTCurveTests`, `OCCTGeom2dTests` and `OCCTSurfaceTests`. The
  pre-existing coverage only ever asserted `>= 0` against CN-continuous primitives, which both
  encodings satisfy, so none of it could catch this. The new tests pin the real ordinals,
  compare the two properties on the same object, and reach the G1 class no earlier test could —
  an offset curve over a C0-but-tangent-continuous BSpline basis, which is the only route to a
  G1 measurement in the `Geom` hierarchy (`Geom_BSplineCurve` itself only ever reports C0…C3
  or CN, so `GeomAbs_Shape.hxx`'s own "G2: for BSpline curves only" comment is also wrong).

#### One batch grid-evaluation family, not three generations per type (#486)

`Curve3D`, `Curve2D` and `Surface` each had **three** generations of "evaluate at N parameters"
bridge functions, 15 in total, no shared helper between any of them, each hand-rolling its own
parameter-pack loop and its own result-unpack loop. The two Surface entry points had drifted onto
**opposite UV layouts** as a direct result:

| | wrote | its header comment said |
|---|---|---|
| `OCCTSurfaceEvaluateGrid` (v0.29.0) | `outXYZ[(iv * uCount + iu) * 3]`, V-major | "row-major (u varies fastest)" |
| `OCCTGridEvalSurfaceD0` (v0.111.0) | `xs[iu * vCount + iv]`, U-major | "row-major" |

"Row-major" says nothing about a UV grid, where either parameter can be the row. Nine duplicate
bridge functions are removed, and the surviving six
(`OCCTCurve3DEvaluateGrid`/`D1`, `OCCTCurve2DEvaluateGrid`/`D1`, `OCCTSurfaceEvaluateGrid`/`D1`)
now share one parameter-packing helper and one definition of the surface grid index
(`occtSurfaceGridIndex`, U-major), so the layouts cannot drift apart again.

**New: `Surface.evaluateGridD1(uParameters:vParameters:)` and `SurfaceGridD1`.** This finishes for
the D1 path what [#404](https://github.com/SecondMouseAU/OCCTSwift/issues/404) did for D0: results
are indexed `.at(u:v:)` instead of arriving as a flat array whose major order you have to know.

```swift
let grid = surface.evaluateGridD1(uParameters: us, vParameters: vs)
let sample = grid.at(u: 2, v: 0)
let normal = simd_normalize(simd_cross(sample.d1u, sample.d1v))
```

**Deprecated (all still work, each forwarding to its canonical sibling):**

| Deprecated | Use instead |
|---|---|
| `Curve3D.evalBatchD0(params:)`, `Curve3D.gridEvalD0(params:)` | `Curve3D.evaluateGrid(_:)` |
| `Curve3D.evalBatchD1(params:)`, `Curve3D.gridEvalD1(params:)` | `Curve3D.evaluateGridD1(_:)` |
| `Curve2D.evalBatchD0(params:)`, `Curve2D.gridEvalD0(params:)` | `Curve2D.evaluateGrid(_:)` |
| `Curve2D.evalBatchD1(params:)`, `Curve2D.gridEvalD1(params:)` | `Curve2D.evaluateGridD1(_:)` |
| `Surface.gridEvalD0(uParams:vParams:)` | `Surface.evaluateGrid(uParameters:vParameters:)` |
| `Surface.gridEvalD1(uParams:vParams:)` | `Surface.evaluateGridD1(uParameters:vParameters:)` |

The `evaluateGridD1` spellings label the derivative `tangent`, where the deprecated ones labelled
it `d1`. No public API is removed and no signature changes, so no source break.

**Behaviour change: a failed evaluation returns an empty result, not zeroes.** The v0.110/v0.111
bridge functions returned `void`: on a failure their Swift callers could not detect (null or
unsupported geometry, an exception inside the evaluator) they wrote nothing, and the wrapper
returned a full-length array of default-initialised `SIMD3(0, 0, 0)` as if evaluation had
succeeded. All six survivors return the number of points written, and every wrapper now returns an
empty array or an empty grid instead.

**Behaviour change: `evalBatchD0`/`evalBatchD1` now use the batch evaluator.** Those four methods
had regressed to calling `Geom_Curve::EvalD0`/`EvalD1` (and the 2D equivalents) once per
parameter, bypassing the `GeomGridEval_Curve` batch path that `evaluateGrid` had used since
v0.29.0. They now forward there, so results can differ from the old per-point loop by ~1e-13 on a
BSpline (measured against a ground-truth C++ comparison; analytic curves such as circles agree
exactly).

**Behaviour change (C API only).** `OCCTSurfaceEvaluateGrid` now writes a U-major buffer
(`outXYZ[(iu * vCount + iv) * 3]`), matching `OCCTSurfaceDrawMesh`, `OCCTSurfaceEvaluateGridD1`
and the Swift `SurfaceGrid`. `Surface.evaluateGrid` used to transpose the old V-major buffer while
unpacking and no longer does, so its `SurfaceGrid` output is byte-for-byte unchanged, but any
direct consumer of the C bridge must swap its index formula. `OCCTGridEvalSurfaceD1` was renamed
`OCCTSurfaceEvaluateGridD1` and reshaped to the family's interleaved-triple buffers.

#### `Surface`'s two transform families now share one `gp_Trsf` builder (#488)

`OCCTBridge_Surface.mm` carried the same `gp_Trsf`-construction switch seven times: once inline in
each of the six immutable functions (`OCCTSurfaceTranslate`, `Rotate`, `Scale`, `MirrorPlane`,
`MirrorPoint`, `MirrorAxis`) and once more as a standalone `buildTrsf3D` that only the in-place
`OCCTSurfaceTransform` dispatcher used. All seven now route through the one `buildTrsf3D`, matching
what #416 did for `Curve3D`, which that issue explicitly flagged for `Surface` and never applied.

The triplication had already caused a divergence. `OCCTSurfaceTransform` guarded only
`if (!surface)` and then dereferenced `surface->surface` unconditionally, while all six of its
siblings in the same file check `s->surface.IsNull()` first. That is the identical gap #416 fixed on
`OCCTCurve3DTransform`. It now guards both. No live path reaches it with a null internal handle
today (every call site null-checks the OCCT maker result before assigning), so this is a latent
crash closed, not an observed one; a null `Handle` deref here would be an uncatchable SIGSEGV per the
#345 precedent, not a caught C++ exception.

New `SurfaceTransformFamilyParityTests` (`Tests/OCCTSurfaceTests`) asserts the two families produce
identical geometry for identical input across all six transform kinds, on a sphere and on a Bezier
surface. The Bezier case matters because the analytic surfaces all take
`Geom_ElementarySurface::Transform`, which just moves an axis placement, while a Bezier transforms
every pole. Nothing had checked the two families agreed before, for `Surface` or, until #416, for
`Curve3D`.

Writing that suite turned up a dead test: `SurfaceTransformTests.transformBezierSurface`
(`Tests/OCCTMathTests`) built its surface from `Curve3D.line`, but `OCCTSurfaceBezierFill2`
down-casts its inputs to `Geom_BezierCurve` and returns `nullptr` for anything else, so the test got
`nil` back and skipped its entire body through `if let` without ever calling `translate`. It now uses
real Bezier boundaries and asserts the surface actually moved.

#### One skeleton behind the three edge-list fillet entry points, and the radius precondition one of them never had (#489)

**Behaviour change, one call shape.** `Shape.blendedEdges(_:)` now returns `nil` when any radius in
the batch is non-positive or NaN, which is the contract `filleted(edges:radius:)` and
`filleted(edges:startRadius:endRadius:)` already applied to theirs:

| call | before | now |
|---|---|---|
| `blendedEdges([(0, 2.0), (99999, -5.0)])` | shape filleted on edge 0 only, reported as success | `nil` |
| `blendedEdges([(0, 0.0)])` | `nil` | `nil` |
| `blendedEdges([(0, -5.0)])` | `nil` | `nil` |
| `blendedEdges([(0, 2.0), (1, 0.0)])` | `nil` | `nil` |

Only the first row changes, and measuring that is what narrowed the finding: a non-positive radius
that reached OCCT was already reported as failure, because `BRepFilletAPI_MakeFillet::Add(r, edge)`
with `r` of 0, a negative `r`, or NaN does not throw and does not build a wrong shape, it fails
`IsDone()` (ground truth in
[`Scripts/repro/489-fillet-radius-validation/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/489-fillet-radius-validation)).
The case that escaped was a bad radius paired with an out-of-range edge index: the bounds check
dropped the pair before the radius was ever used, so the batch built from the remaining edges and
reported success for a request that was never fully honoured. Valid input is unaffected, pinned by a
test that a uniform per-edge radius list produces the same volume as the uniform entry point. An
out-of-range index with a valid radius is still skipped, unchanged.

`OCCTShapeFilletEdges` and `OCCTShapeFilletEdgesLinear` (`OCCTBridge_Modeling.mm`) and
`OCCTShapeBlendEdges` (`OCCTBridge_Healing.mm`) were three hand-maintained copies of one loop:
same `TopExp::MapShapes` edge map, same 0-based index bounds check, same `Build`/`IsDone`/`Shape`
triad, same `catch (...)`, differing only in the radius each edge gets. That is how the guard came to
exist in two of them and not the third. All three now share `occtShapeFilletEdgeList` and the
`occtValidFilletRadius` / `occtValidFilletRadii` predicates in `OCCTBridge_Internal.h`, so the next
piece of hardening this family needs lands once. `OCCTShapeFilletEdges` also picks up the null-result
check the blend function already had.

A fourth copy of the same loop turned up in `OCCTShapeHistoryFromFilletEdges`, which the finding did
not name: it cannot use the full skeleton, because it keeps its builder alive to hand back a
`BRepTools_History` over it, so the loop is split out as `occtFilletAddEdges` and shared at that
level. It had no radius precondition either, nor does its single-edge sibling
`OCCTShapeHistoryFromFilletEdgeVariable`; both now apply the same one, as do their Swift wrappers
`Shape.filletedWithFullHistory(radius:edges:)` and
`Shape.filletedWithFullHistory(edge:startRadius:endRadius:)`. No observable change for either: both
take a single radius (or radius pair) that is either valid or rejected outright, with no per-element
pairing for an index skip to hide.

Bridge-only: no kernel patch, no xcframework rebuild, nothing filed upstream, since `Add()` reporting
failure through `IsDone()` is OCCT's documented `BRepBuilderAPI_MakeShape` contract.

The cross-reference index entry for `BRepFilletAPI_MakeFillet` named only the `OCCTShapeFillet*`
prefix, so four of its call sites were unreachable from the index: `OCCTShapeBlendEdges` (the one this
issue is about), `OCCTShapeFuseAndBlend`, `OCCTShapeCutAndBlend` and the `OCCTFilletBuilder*` family.
That is the #484 failure mode again, an audit by symbol name finding fewer sites than exist, and it is
how this family's copies stayed out of view. The entry now names all of them;
`Scripts/check-bridge-index.py` still reports the same 139 pre-existing stale entries (#510), none of
them new.

Two family-level inconsistencies were found and deliberately left alone, filed as #520: the other two
`BRepFilletAPI_MakeFillet` edge-list functions disagree with these three about what an edge index
means and what an invalid one does. `OCCTShapeFilletEvolving` takes 1-based indices (documented as
such on `EvolvingFilletEdge.edgeIndex`) and rejects an out-of-range one, and
`OCCTShapeFilletVariable` takes a 0-based index and also rejects. Reconciling them changes public
API behaviour and needs its own decision, not a drive-by in a dedup fix.

#### One `GeomConvert_Approx*` run per type, not two that disagree (#491)

`Curve3D` and `Surface` each wrapped the same OCCT approximation class twice — `approximated`
returning the fitted BSpline, `approxWithDetails` returning it plus OCCT's own diagnostics — and each
pair had drifted. Both now run through one shared bridge helper per type, so the detailed entry point
differs from the plain one only by carrying `maxError`/`isDone`/`hasResult`.

Three divergences resolved, plus one that turned out to be paper-only:

- **`Surface`: `PrecisCode` 0 vs 1.** `OCCTSurfaceApproximate` passed `0` as
  `GeomConvert_ApproxSurface`'s eighth constructor argument and `OCCTGeomConvertApproxSurface` passed
  `1`, with no comment either side. It is a real algorithm knob, not a reserved value: it reaches
  `AdvApp2Var_Context`'s `iprecis`, where `lesparam` turns it into the Jacobi degree and the initial
  per-axis sample count that seed the fit. Both now pass `0`. Chosen on measurement over 72 bounded
  cases (8 surface families x 6 tolerances, plus C0/C1 and `maxDegree` 10 variants): the two codes
  never disagreed on `IsDone` and produced the same knot/pole layout in 71 of 72, but a different
  `maxError` in all 72 — smaller with `0` in 64 of them — and in the one layout-differing case (an
  offset sphere at tolerance `1e-5`) `0` met the requested tolerance with 27x15 poles where `1`
  needed 27x23. A caller who states a tolerance wants the lightest surface that meets it. OCCT itself
  splits along that same line: the two sites that re-check `MaxError()` against a tolerance they must
  honour pass `0` (`ShapeCustom_BSplineRestriction`, `ShapeConstruct`), and the six that never look
  at it pass `1` (`GeomConvert_1` twice, `ShapeUpgrade_UnifySameDomain`, `GeomFill_Sweep`, `GeomLib`,
  `BRepOffset_Offset`). That census is #573's correction of this one, which listed a commented-out
  `BRepFill_Sweep` site and missed `BRepOffset_Offset`.
- **`Surface`: default continuity C2 vs C1.** `Surface.approxWithDetails` defaulted `uContinuity` and
  `vContinuity` to `.c1` while `Surface.approximated` defaulted to C2, so the two
  no-continuity-argument calls fitted to different smoothness and returned different surfaces (15 vs
  16 U poles on a sphere at `1e-3`). Both now default to C2.
- **Both: the null-handle guard.** `OCCTGeomConvertApproxCurve`/`Surface` checked only the outer
  wrapper pointer, while their plain counterparts also checked the OCCT handle inside it. A null
  `Geom_Curve`/`Geom_Surface` reaching `GeomAdaptor_*` is an uncatchable SIGSEGV in this Release
  kernel, where OCCT's own `Standard_NullObject` precondition is compiled out. Both now check both.
- **`Curve3D`: `IsDone()` vs `HasResult()` — the audit's headline claim, and it does not reproduce.**
  The header documents these as different questions, so `OCCTCurve3DApproximate`'s `IsDone()` gate
  looked like it would reject a completed-but-over-tolerance fit that `OCCTGeomConvertApproxCurve`'s
  `HasResult()` gate returns. It cannot: `GeomConvert_ApproxCurve` copies both flags off
  `AdvApprox_ApproxAFunction`, whose only `HasResult`-without-`IsDone` path is an `ErrorCode = -1`
  assignment upstream has commented out (`AdvApprox_ApproxAFunction.cxx:550`, `// for now
  ErrorCode=-1;`). With that line dead the two accessors are equal for every input, which is why
  gating on `IsDone()` never actually rejected anything — a circle fitted with one segment at degree
  3 against a `1e-9` tolerance reports `maxError` 5.1 and `isDone` true. The gate is unified on
  `HasResult()` anyway: it is what OCCT's own curve-conversion sites use (`GeomConvert.cxx`,
  `GeomToIGES_GeomCurve.cxx`, `GeomFill_Profiler.cxx`), what both surface entry points already used,
  and the only gate under which `approxWithDetails`' `isDone: false` diagnostic means anything.

So `Curve3D.approximated` is unchanged in behaviour and `Surface.approximated` is unchanged in
output; what changes observably is `Surface.approxWithDetails`, which now returns the same surface
`Surface.approximated` does instead of a slightly different one. Neither divergence had any test
coverage in either direction — no test anywhere called both entry points on the same input. New
`Issue491Curve3DApproxParityTests` (`Tests/OCCTCurveTests`) and `Issue491SurfaceApproxParityTests`
(`Tests/OCCTSurfaceTests`) assert success, geometry, pole/degree counts and reported `maxError` agree
across both entry points on 9 curve and 12 surface requests spanning the starved, over-tolerance and
unreachable-tolerance cases.

Each `.mm` also had two copies of the request-side `int32_t` → `GeomAbs_Shape` mapping (a `static
intToContinuity` for the detailed entry point, the identical `switch` spelled inline in the plain
one); each file now has one. The wider census of that conversion across the bridge is #513's, not
this issue's.

Building the parity tests surfaced an unrelated upstream defect, filed as
[#522](https://github.com/SecondMouseAU/OCCTSwift/issues/522): `GeomConvert_ApproxSurface` asked for
`GeomAbs_C0` can collapse a direction to degree 1 and return a surface deviating by the input's own
diameter while reporting `IsDone()` and a `maxError` five orders of magnitude too small (a full
sphere at C0 comes back as a straight line across its longitude). It predates #491, both entry points
hit it identically, and unifying them neither causes nor fixes it. The surface parity suite keeps C0
in its request set — both entry points must still return the *same* surface there, and they do — but
excludes it from the "reported error describes the returned surface" assertion, with a comment to
drop that exclusion when #522 is fixed.

#### `Curve3D.interpolatePeriodic` delegates instead of reimplementing, and gains `tolerance:` (#493)

**Behaviour change.** `Curve3D.interpolatePeriodic(points:)` with exactly 2 points used to return
`nil`; it now returns a valid out-and-back periodic loop. `OCCTInterpolatePeriodic` was a second,
independent `GeomAPI_Interpolate` call site alongside `OCCTCurve3DInterpolate`, and the two had
drifted: the periodic one rejected `count < 3` where the general one rejects only `count < 2`, so
the same 2-point input reached OCCT through `interpolate(points:closed:tolerance:)` with
`closed: true` and not through `interpolatePeriodic`. Confirmed by running it, not by inspection: the
general entry point returns a closed, periodic curve over `0...20` for two points, and OCCT builds it
without complaint.

This is #412's fix, applied to the 3D sibling it never touched. The 2D pair was fixed in v1.17.0 and
the 3D pair was left with the defect verbatim, including the fix comment's own description of it.
`OCCTInterpolatePeriodic` is now `return OCCTCurve3DInterpolate(points, count, true, 1e-6);`. The C
ABI is unchanged, and `Curve3D.interpolatePeriodic` delegates to
`interpolate(points:closed:tolerance:)` rather than flattening its own buffer.

Additive: `Curve3D.interpolatePeriodic(points:tolerance:)` gains a `tolerance:` parameter defaulted
to the `1e-6` it used to hardcode, so the bare call is unchanged. The tolerance was previously
unreachable, and it is not decorative: OCCT treats points closer together than the tolerance as
coincident and refuses the interpolation, so with two points `1e-3` apart the default succeeds and
`tolerance: 1e-2` returns `nil`. That case is now asserted rather than assumed.

New `Curve3DInterpolatePeriodicParityTests` (`Tests/OCCTCurveTests`) ports the 2D suite #427 added
(default-tolerance parity, tolerance reachability, the 2-point floor, single-point rejection) and
adds the tolerance-changes-the-outcome case and a non-planar loop, which checks the shared path is
not flattening z. The 2-point test was run against the unfixed code first and fails there, so it
covers the defect rather than describing it. The only pre-existing coverage of the 3D function was a
4-point square asserting `!= nil` (`Tests/OCCTMiscTests`) plus one use as a fixture for an unrelated
test, which is why the drift survived #412.

#### One defeaturing skeleton, and the fuzzy tolerance that never existed (#497)

Five bridge functions ran `BRepAlgoAPI_Defeaturing`, each with its own copy of the same
`SetShape`/`AddFaceToRemove`/`Build`/`IsDone` sequence, and the copies had drifted apart on every
precondition: one silently skipped an out-of-range face index while another failed the call, one
dereferenced its faces array with no null check (a crash no `catch (...)` could have caught), and
only two checked the result shape for null. `OCCTBridge.h`'s own cross-reference index listed one of
the five, so a maintainer using the index to find the existing wrap would have found a third of it.

Two of the five were the same function twice: `OCCTShapeDefeature` (v0.118.0) and
`OCCTDefeatureWithTolerance` (v0.114.0) differed only in that the older one called `SetFuzzyValue`.
On the Swift side both were spelled `defeature(faces:)`-callable — `defeature(faces:)` and
`defeature(faces:tolerance: Double = 0)` — and Swift's overload resolution sends a call site that
omits `tolerance:` to the exact-arity overload every time, so the fuzzy path was unreachable without
naming the argument. Confirmed against this package, not argued from the rules: deprecating one
overload and rebuilding showed the existing test at `OCCTModelingTests.swift:4134` binding to it.

**The tolerance it was hiding does nothing.** `BRepAlgoAPI_Defeaturing::Build` forwards the input
shape, the faces to remove, the history flag and the parallel flag to the `BOPAlgo_RemoveFeatures`
that does the work, and nothing else; the fuzzy value inherited from `BOPAlgo_Options` is stored,
readable back through `FuzzyValue()`, and never consulted. Its own header says so in the class
comment ("the other options of the base class are not supported here and will have no effect").
Measured as well as read: identical BREP output at every fuzzy value from `1e-7` to `100`, against a
`BRepAlgoAPI_Cut` control that the same magnitudes collapse to an empty shape — see
[`Scripts/repro/497-defeaturing-fuzzy-inert/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/497-defeaturing-fuzzy-inert).
Not an upstream defect, so nothing to file or patch; the wrapper was `OCCTShapeDefeature` under
another name and is gone.

The four remaining entry points — `withoutFeatures(faces:)`, `defeature(faces:)`,
`defeaturedWithFullHistory(faces:)` and `withoutSmallFaces(minArea:)` — now share one skeleton and
one set of preconditions, and the index names all four.

**Behaviour change.** A face index that does not belong to the shape now fails
`withoutFeatures(faces:)` instead of being dropped from the request. Dropping it returned a shape
that still carried the feature the caller asked to remove, indistinguishable from a successful
removal; the two index-addressed siblings already failed on it. `defeature(faces:tolerance:)` is
deprecated (it forwards, and its tolerance was never read); calls that omit `tolerance:` were
already reaching the tolerance-free path and are unaffected.
#### Fix: four arc-length samplers wrote past the end of the caller's buffer (#501)

`GCPnts_UniformAbscissa` sizes its own parameter array at `nbPoints + 5` and fills it as far as the
arc-length walk runs, so `NbPoints()` is not bounded by the count that was asked for, and
`GCPnts_QuasiUniformAbscissa` inherits that for every curve which is neither Bezier nor BSpline,
because it forwards to `GCPnts_UniformAbscissa` for those. Four bridge functions were handed a
buffer sized from the requested count and then filled it with `NbPoints()` values:
`OCCTCurve3DQuasiUniformAbscissa` (`Curve3D.quasiUniformParameters(count:)`),
`OCCTCurve3DDrawUniform` (`Curve3D.drawUniform(pointCount:)`), `OCCTCurve2DDrawUniform`
(`Curve2D.drawUniform(pointCount:)`) and `sampleAdaptorUniform`
(`CompCurve`/`EdgeCurve` `sampleUniform(count:)`).

Reproduced against the shipped functions with sentinel-guarded buffers: on an ellipse with major
radius 1e6 and minor radius 1e-3, 22 of the first 59 point counts overshoot by one, for **48
overflowing calls** across the three curve entry points. The trigger is rounding: the walk stops
~1.6e-8 in parameter short of the end against an epsilon of ~1e-13, so the sampler takes one more
step. Well-conditioned geometry does not do it, which is why this survived from v0.31.0: a line, a
circle at radii from 1e-6 to 1e7, a 5x2 ellipse, hyperbola, parabola, Bezier, BSpline, offset and
trimmed curves were all clean across counts 2..200.

The two `drawUniform` entry points did not corrupt memory quietly. They **crashed the process**.
Their Swift wrappers unpack the buffer by index using the count the bridge returned, so a returned
`pointCount + 1` reads three (or two) elements past the end of the Swift `Array` and hits its bounds
check: `Fatal error: Index out of range`. `quasiUniformParameters` uses `prefix(n)`, which clamps,
so there the only symptom was the heap write itself.

Clamping alone would not have been the fix. The surplus point *is* the curve's end parameter, so
truncating the tail leaves the distribution stopping short of the curve, which is precisely what
`OCCTGCPntsQuasiUniform` (`Edge.quasiUniformParameters(count:)`), the one member of the family that
already clamped, had been doing silently on every overshooting call. The shared
`occtSamplerKept`/`occtSamplerIndex` helpers keep the first `capacity - 1` samples and the sampler's
own last one.

Also fixed: **`Shape.uniformAbscissa(pointCount: 0)` returned five parameters** instead of `nil`.
Both samplers document `nbPoints >= 2` and enforce it with a `Raise_if`, which the Release kernel
compiles out (`No_Exception`, #487), and `OCCTUniformAbscissaByCount`/`ByCountRange` had no count
precondition of their own. Below 2 the algorithms misbehave rather than fail:
`GCPnts_QuasiUniformAbscissa(bezier_or_bspline, 0)` builds an `NCollection_HArray1` over the empty
range `(1, 0)` and writes element 1 of it: an uncatchable SIGSEGV, one missing guard away on three
of the six entry points. `occtValidSampleCount` is now applied at all of them, so `count`/
`pointCount` below 2 returns empty rather than reaching OCCT.

Reproducer and the full measured tables: [`Scripts/repro/501-quasiuniform-buffer-overflow/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/501-quasiuniform-buffer-overflow).

#### The orphaned duplicate the index was hiding, and eight corrected entries (#501)

`OCCTBridge.h`'s index mapped `GCPnts_QuasiUniformAbscissa → OCCTCurve3DQuasiUniformParams`, a
symbol that has never existed. Chasing the real one turned up two: `OCCTCurve3DQuasiUniformAbscissa`
(v0.31.0) and `OCCTGCPntsQuasiUniformCurve` (v0.75), byte-for-byte the same sampling of the same
`Curve3D` through the same two OCCT classes. The v0.75 one had no caller in Swift or in the tests
and never had; it is removed. Its `maxParams` bound (the one thing the older spelling lacked, and
the reason the older spelling was overflowing) is folded into the survivor. No Swift API changes:
`OCCTGCPntsQuasiUniformCurve` was C-level only and never reachable.

Index entries corrected alongside it: the whole `GCPnts` block (`UniformAbscissa` and
`UniformDeflection` both pointed at `OCCTCPntsUniformDeflection*`, which wraps a **different OCCT
class**, `CPnts_UniformDeflection`, now given its own entry; `AbscissaPoint` named one 2D function
out of eleven; `TangentialDeflection` had no entry at all), `BRepGProp` (two of three symbols
missing their `Get`), `ShapeCustom_DirectModification` (missing its `Custom`), and
`BRepOffset_SimpleOffset`, which named `OCCTShapeSimpleOffset` (a function that wraps
`BRepOffset_MakeSimpleOffset`, a different class, now indexed separately) while the real
`OCCTBRepOffsetSimpleOffset` was absent. `Scripts/check-bridge-index.py` goes from 139 stale entries
to 134; the remaining 134 are #510.

Worth noting for #510: the two `GCPnts_Uniform*` entries **passed** the checker. It verifies that a
named symbol exists, not that it wraps the class the entry claims, so a mis-attributed entry is
invisible to it. 139 is a floor, not the count.

#### One `BRepLib::BuildCurves3d` entry point, not three, and one default instead of two (#498)

**Behaviour change.** `Shape.buildCurves3d(tolerance:)`'s default moved from `1e-7` to `1e-5`.
Callers who pass a tolerance explicitly are unaffected; callers who omit it get OCCT's own default
for the operation. Pass `tolerance: 1e-7` to keep the old value.

The bridge had three C entry points for one operation. Two of them —
`OCCTBRepLibBuildCurves3dForShape` (v0.114.0) and `OCCTBRepLibBuildCurves3dAll` (v0.122.0), declared
~1700 header lines apart — had byte-identical bodies: the same overload, the same two arguments. The
third, `void OCCTShapeBuildCurves3d`, wrapped `BuildCurves3d`'s no-tolerance overload, which
[turns out to be](../Scripts/repro/498-buildcurves3d-triplication/) `return BuildCurves3d(S, 1.0e-5);`
and nothing else — so it was the same call again, with the success flag discarded. All three now go
through `OCCTBRepLibBuildCurves3dForShape`.

Nothing connected the two Swift wrappers written over the duplicate symbols, so their defaults
drifted 100x apart, and the cost was real. On a pcurve-only edge on a cylinder:

```swift
// Before — same operation, same input, no arguments, two different curves.
edge.buildCurves3d()      // edge tolerance 1e-07, 8 poles
edge.buildCurves3dAll()   // edge tolerance 1e-05, 7 poles, curve up to 2.6e-6 away

// After — one call behind both names.
edge.buildCurves3d()      // edge tolerance 1e-05
edge.buildCurves3d(tolerance: 1e-7)   // the tighter curve, asked for
```

`1e-5` was chosen over `1e-7` because it is OCCT's own default for both the parameter and the
no-tolerance overload, it is what two of the three entry points already used, and the tolerance is
not only an approximation bound: `BRepLib::BuildCurve3d` also makes it the rebuilt edge's tolerance
**floor**, using the requested value rather than the deviation it achieved (the line that would have
used the measured deviation is commented out in the kernel). `1e-7` therefore claims an accuracy the
approximator is asked but not required to deliver.

- `Shape.buildCurves3dAll(tolerance:)` is deprecated and forwards to `buildCurves3d(tolerance:)`.
- `Shape.allEdgePolylinesIndexed(deflection:maxPointsPerEdge:)` now spells its `1e-5` out, which is
  exactly what the no-tolerance overload it used to call did. Its behaviour is unchanged.
- `buildCurves3d` returning `false` is documented for the first time: it means "at least one edge
  failed", and the edges that succeeded are still modified. The `void` entry point discarded that
  signal, on the one path (bulk discretisation of arbitrary imported shapes) where partial failure
  is likeliest.

Both pre-existing tests called the operation on a box, where every edge already has a 3D curve, so
OCCT returns `true` at its first line and computes nothing — a tolerance of 42 passes them just as
`1e-7` did, which is why the drift survived. One is now an explicit early-return test (asserting the
edge tolerances and curves are untouched, with tolerance 42); the other is the deprecated-spelling
guard. New `BuildCurves3dTests` (`Tests/OCCTTopologyTests`) covers the case where the operation
actually works: an edge carrying only a pcurve on a cylinder. Run against the unfixed code first,
the default-value and cross-wrapper-agreement tests fail there, so they cover the defect rather
than describing it.

#### One sub-shape enumeration, not one per accessor (#502)

`Shape.solids`/`solidCount`, `shells`/`shellCount` and `wires`/`wireCount` walked a bare
`TopExp_Explorer`, which yields one entry per **occurrence** in the topology tree.
`subShapes(ofType:)`/`subShapeCount(ofType:)`, along with `faceCount`, `edgeCount`, `vertexCount`,
`uniqueSubShapeCount(ofType:)` and the `face(at:)`/`edge(at:)` indexed accessors, built a
`TopTools_IndexedMapOfShape` through `TopExp::MapShapes`, which keeps one entry per **distinct**
sub-shape. Two answers to one question, in two hand-written traversals, with no test anywhere
comparing them.

The two are not independent primitives: `TopExp::MapShapes(S, T, M)` *is* a `TopExp_Explorer` walk
piped into the map (`TopExp.cxx:34-45`), so the deduplicated sequence is the explorer's sequence
with later repeats removed: same order, no index moved. Every sub-shape accessor in the bridge now
reads one enumeration (`occtMapSubShapes`), and the six `TopExp_Explorer` entry points behind the
typed accessors are gone, along with a seventh (`OCCTShapeGetEdgeCount`) that had no caller and
disagreed with `OCCTShapeGetTotalEdgeCount` two declarations away.

**Behaviour change, in the deduplicating direction.** `solidCount`/`shellCount`/`wireCount` and
`solids`/`shells`/`wires` now count distinct sub-shapes. Measured against the pinned kernel
([`Scripts/repro/502-subshape-traversal-dedup/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/502-subshape-traversal-dedup)),
the old and new answers are identical for every ordinary shape tried (the primitives, a hollow
solid's two shells, two distinct bodies, two *placements* of one body, a sewn stack, a compsolid),
and differ only where one sub-shape is reachable from two parents:

| shape | before | after |
|---|---|---|
| `Shape.compound([box, box])` (the same `Shape` twice) | 2 solids | 1 solid |
| the same shell handed to two `solidFromShells` calls | 2 shells | 1 shell |
| one wire used to build two faces | 2 wires | 1 wire |
| a face and its own reverse in one shell | 2 faces | 1 face |

Deduplication is by `TopoDS_Shape::IsSame`, which compares the **location** as well as the
geometry, so two placements of one body are still two solids and instanced assemblies are not
collapsed. It ignores orientation, so a sub-shape embedded forward in one parent and reversed in
another is one sub-shape.

Two illustrations of why this is the answer the whole API should have been giving: a plain 10mm box
has 24 edge *occurrences* over 12 edges and 48 vertex occurrences over 8 vertices, and `edgeCount`
already reported 12; and `Shape.faces()` (still an explorer walk, see #541) can hand back a face
`face(at:)` cannot address, because their indices came from different enumerations.

#### One tolerance behind every local-properties entry point, and a cusp that returned NaN (#494)

`GeomLProp_SLProps`/`GeomLProp_CLProps`/`GeomLProp_CLProps2d` take a `Resolution` argument their own
headers describe as "the linear tolerance (it is used to test if a vector is null)". It is not a
comparison tolerance: it decides whether a derivative counts as null, and so whether the tangent,
normal and curvature exist at all at a point. The bridge passed **three different values** across 28
construction sites — `Precision::Confusion()` (`1e-7`) from the canonical `Surface`/`Curve3D`/`Face`/
`Edge`/`Curve2D` entry points, `1e-10` from the `Local*` family, and `1e-6` from
`OCCTGeomLProp{CL,SL}Props`. #405/PR #425 fixed this for three `Surface` entry points; its audit was
Surface-only and never inventoried the `Local*` family or the `Curve3D` side, so the same defect
survived in the siblings. All 28 now construct through shared helpers in `OCCTBridge_Internal.h`
(`occtLocalPropsResolution`, `occtSurfaceLocalProps`, `occtCurveLocalProps`,
`occtCurve2dLocalProps`), so the value is stated once and no site can drift again.

Note the direction, which #405's own framing had backwards for this case: a *smaller* resolution is
the more **permissive** one, because the null test is
`derivative.SquareMagnitude() > resolution * resolution`. The `Local*` family's `1e-10` was three
decades more willing to call a degenerate point well-conditioned than the canonical family, not less.

Measured divergences, all now gone. On a cubic Bezier whose first two poles sit `1e-8` apart, at
`u = 0`:

- `Curve3D.localCurvature(at:)` returned `6.7e15` where `curvature(at:)` returned
  `Double.greatestFiniteMagnitude` (OCCT's infinite-curvature sentinel) — 293 orders of magnitude
  apart.
- `localTangent(at:)` returned `(1, 0, 0)` where `tangentDirection(at:)` returned
  `(0.707, 0.707, 0)`. Not a precision difference: the two resolutions disagree about which
  derivative is the first significant one, and OCCT derives the tangent from that one, so the two
  reported genuinely different directions.
- `localNormal(at:)` returned a vector where `normal(at:)` returned `nil`.

On a cone with `radius: 0` at `v = 1e-8`, `Surface.localCurvatures(u:v:)` reported a defined mean
curvature of `-8.66e7` at a point `curvatures(u:v:)`, `gaussianCurvature(atU:v:)`,
`meanCurvature(atU:v:)` and `principalCurvatures(atU:v:)` all reported undefined. Same for a sphere
approaching its pole. `Shape.curveLocalProperties`/`surfaceLocalProperties` (the `1e-6` pair)
disagreed with `Edge.curvature3D(at:)` and `Face`'s curvature entry points the same way.

**A separate live defect found while probing those gates**, affecting the canonical family too:
OCCT returns `RealLast()` from `Curvature()` to mean *infinite* curvature, at a cusp — where the
first significant derivative has order 2, e.g. a Bezier whose first two poles coincide.
`IsTangentDefined()` is still true there, and the sentinel trivially passes any "is the curvature
big enough to invert" test, so it flowed straight into `CentreOfCurvature()`. That is worse than an
exception: `LProp_CurveUtils::Curvature()` returns the sentinel *without* assigning the curvature
field `ComputeCentreOfCurvature` then divides by, leaving it `0.0`, so the caller got
`(nan, inf, nan)` reported as a successfully computed point. `Curve3D.centerOfCurvature(at:)`,
`localCentreOfCurvature(at:)`, `Curve2D.centerOfCurvature(at:)`, `Edge.centerOfCurvature3D(at:)` and
`Shape.curveLocalProperties` were all affected; each now returns `nil`/no centre, via a shared
`occtCurveCurvatureIsInvertible` predicate that rejects the sentinel as well as a below-resolution
curvature. `Normal()` was never exposed — it rejects the sentinel explicitly and raises.

Also hardened while in these functions: the six `Local*` bridge entry points dereferenced their
`Geom_Curve`/`Geom_Surface` handle without a null check their canonical siblings all make (an
uncatchable SIGSEGV in this Release kernel, where OCCT's own precondition is compiled out), and
three functions called `Curvature()` before establishing `IsTangentDefined()`, relying on a raise
that goes through `LProp_NotDefined_Raise_if` — live in the bridge's own translation units, compiled
out inside the OCCT build. Neither is reachable through today's Swift API; both are now consistent
with the rest of the family.

New `LocalPropsParityTests` (`Tests/OCCTAnalysisTests`, 11 tests) asserts definedness *and* value
agreement between each entry point and its counterpart across well-conditioned points, the old
`1e-10`-vs-`1e-7` window, and genuinely degenerate points, plus the cusp regression and a blanket
"no local-properties entry point ever returns a non-finite number" sweep. Each was run against the
pre-fix bridge to check it discriminates the fix rather than merely passing alongside it: 5 fail
there (both `1e-10` window tests, the cusp regression, the non-finite sweep, and the cusped-edge
test that covers the `1e-6` pair), and 6 pass both before and after as intended controls. The
issue's own review of existing coverage was accurate — no test anywhere compared a `Local*`
function against its sibling, and none drove a degenerate parameter through one.

Two API additions fell out of writing those tests, both exposing state the bridge already had:
`OCCTCurveLocalProps` gains `curvatureInvertible`, because `Shape.curveLocalProps(at:)` decided
whether its `normal`/`centerOfCurvature` were filled in by re-testing `curvature > 1e-10` in
Swift — a copy of a bridge-side literal that no longer exists, and one that would have gone stale
in the other direction after this change. `SurfaceLocalProperties` gains `curvatureDefined`, which
the bridge struct has always carried but the Swift wrapper dropped: its four curvature values are
non-optional and all zero where curvature is undefined, so a caller had no way to tell a cone's
apex from a flat point. Both are additive; neither struct has a public memberwise initializer.

One documentation correction fell out of writing the parity tests, unrelated to the tolerance:
`Surface.localCurvatureDirections(u:v:)` was documented as returning `nil` "for umbilic points
(where curvature is constant)", which reads as covering a sphere. OCCT's umbilic test is
`|maxCurv - minCurv| < Epsilon(maxCurv)` — one ULP, not a geometric tolerance. A plane always
qualifies (both curvatures are exactly zero), but an analytically-umbilic sphere qualifies only
where the two computed values round to the same `Double`: on a sphere of radius 3 it does at
`v = 0`, `0.3`, `0.5` and `-0.7` and does not at `v = 1`, where they differ by exactly one ULP.
Nothing changed here — `IsUmbilic()` takes no resolution — but the docs now say what it does, and
the test asserts the asymmetry on a plane rather than on a sphere, where it would be flaky.

Bridge-only: no kernel patch, no `OCCT.xcframework` rebuild. Probes and full writeup at
[`Scripts/repro/494-lprop-resolution/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/494-lprop-resolution).

Not changed, and tracked separately as
[#529](https://github.com/SecondMouseAU/OCCTSwift/issues/529): 19 `BRepLProp_SLProps`/
`BRepLProp_CLProps` constructions still pass a literal `1e-6`. They are a different, adaptor-based
class family asking the same question of a face rather than a surface, and several feed face
orientation decisions rather than curvature reporting, so they need their own validation.

#### One path parser, not two that disagree on what an extension is (#499)

`PathParser` wrapped `TDocStd_PathParser` and `OSDPath` wrapped `OSD_Path`: two OCCT classes
answering the same questions behind identically-named Swift methods, each with its own test pinning
its own format and neither comparing itself to the other. `PathParser` now forwards to `OSDPath`,
whose bridge family is the single path-parsing implementation; `TDocStd_PathParser` is no longer
wrapped, and its four bridge functions are deleted.

**Silent behaviour change, in two places**, prompted by a deprecation warning at every call site
rather than a compile error. [`SEMVER.md`](SEMVER.md#recorded-exception-unreleased-pathparser-forwards-to-osdpath-499)
records the exception:

```swift
PathParser.fileExtension("model.step")     // was "step"        now ".step"
PathParser.trek("/home/user/model.step")   // was "/home/user"  now "/home/user/"
```

The formats were the *reported* divergence. Measuring both classes across 19 inputs
([`Scripts/repro/499-path-parsing-divergence/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/499-path-parsing-divergence))
found four cases where `TDocStd_PathParser` was not differently formatted but wrong, all of which
the forwarding fixes:

| input | `PathParser`, before | now (= `OSDPath`) |
|---|---|---|
| `/home/user/model` | name `""`, directory `""` (`Parse()` returns early when there is no dot) | name `"model"`, directory `"/home/user/"` |
| `/home/user/.config` | `nil` from every accessor (`Split` past the end of the string, caught by the bridge) | ext `".config"`, directory `"/home/user/"` |
| `/home/a.b/model` | name `"a"`, ext `"b/model"` (the last dot anywhere wins, separators ignored) | name `"model"`, ext `""` |
| `/home/üser/mødel.step` | name `"mÃ¸del"` | name `"mødel"` |

The issue predicted the opposite of that last row: that `OSD_Path`'s documented
`ConstructionError` for characters outside `' '...'~'` would make every `OSDPath` method return
`nil` for a non-ASCII path, while `TDocStd_PathParser`'s `TCollection_ExtendedString` handled it.
`OSD_Path.cxx` never throws that error (the header documents a constraint the implementation does
not enforce), and the mangling was on the `TDocStd_PathParser` side, in the bridge:
`TCollection_ExtendedString(const char*)` defaults to `theIsMultiByte = false`, so UTF-8 input was
read one byte per character and re-encoded on the way out.

**`OSDPath.trek(_:)` is not a filesystem path.** `OSD_Path::Trek()` returns OCCT's portable
directory syntax, where `/` becomes `|` and `..` becomes `^`. `/home/user/m.step` gives
`"|home|user|"`, and `../up/f.txt` gives `"^|up|"`. The Swift doc comment said only "Get the
directory trek from a path", and the method had no test of any kind. It now says what it returns and
points at the new **`OSDPath.folder(_:)`**, which gives the real directory (`"/home/user/"`) and is
what `PathParser.trek` forwards to. `folder`/`file` recompose to the input; `trek` never could.

Also: `OSD_Path` and `OSD_Environment` gained the cross-reference index entries neither ever had,
and the four `OCCTOSDPath*` string accessors, four copies of construct-read-`strdup`, share one
helper.

#### One skeleton behind the cylindrical-hole family, one set of drilling preconditions — and the two drills kept apart on purpose (#496)

The audit read `Shape.drilled(at:direction:radius:depth:)` (`BRepPrimAPI_MakeCylinder` +
`BRepAlgoAPI_Cut`, with a bounding-box-diagonal length for through holes) as a cruder
reimplementation of the `BRepFeat_MakeCylindricalHole` family, and proposed folding the first into
the second. **Measuring both against the pinned kernel says that would not be a refactor**
([`Scripts/repro/496-drill-hole-contracts/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/496-drill-hole-contracts)):
six of thirteen probed requests change answer, all in the direction of losing work that currently
succeeds.

- **`Perform` is an *infinite* cylinder, both ways along the axis.** The origin anchors the axis; it
  is not where the hole starts. Drilling "down" from a plate's own midplane, the boolean path removes
  the 10mm below the origin and `Perform` removes all 20.
- **`PerformUntilEnd` is not forward-only either**, despite documenting itself as "every hole located
  after the origin". It uses `LocalizeAfter(0.)` only to pick the starting intersection and then
  resets backwards to the entry face.
- **`PerformBlind` refuses a depth that leaves the stock** (`BRepFeat_HoleTooLong`) where the boolean
  path treats the overshoot as harmless and drills through. Passing a depth comfortably past the far
  face is a normal way to drill through without computing the thickness.
- **The feature drill wants a solid.** A shell or a face is `InvalidPlacement` for every mode but
  `Perform`.

So the two stay. What they now share is the one thing they genuinely should — the preconditions on a
drilling request — and `drilled`'s documentation says plainly which to reach for and why.

**The precondition that was missing from both.** `OCCTShapeDrillHole` guarded `radius <= 0`; the
feature family guarded nothing. Neither caught a *positive but sub-tolerance* radius, and the kernel
is a Release build, so its own `*_Raise_if` checks are compiled out by `No_Exception` (#487). Measured:
a radius of 0 or 1e-14 makes every `BRepFeat_MakeCylindricalHole` mode report `BRepFeat_NoError` and
return a shape identical to the input — same volume, same six faces, no material removed. Both
families now share `occtValidDrillRadius` (must exceed `Precision::Confusion`) and
`occtValidDrillDirection`; the latter is the guard #496 flagged, which the feature family had only by
accident, via `gp_Dir`'s throw landing in its own `catch (...)`.

**Four bodies to one.** The four `OCCTBRepFeatCylindricalHole*` functions were the same
Init/Perform\*/Status/Build body four times, three differing by a single `Perform*` line and the
fourth being the third with the `Build` deleted. They are now one `occtBRepFeatCylindricalHole`
skeleton in `OCCTBridge_Internal.h` behind two bridge entry points (6 → 2 C functions), which is also
what makes the status honest.

**New: `Shape.CylindricalHoleExtent`, and a status query that answers about the extent you asked
for.** `cylindricalHoleStatus` wrapped `Perform` no matter what the caller was about to drill, so it
was a false green: a radius wider than the whole solid is `.noError` for through-all and
`.invalidPlacement` for thru-next. And `BRepFeat_HoleTooLong` is written in exactly two places in the
kernel, both inside `PerformBlind` — so `.holeTooLong` was a Swift enum case **no public spelling
could produce**. `cylindricalHole(axisOrigin:axisDirection:radius:extent:)` and
`cylindricalHoleStatus(axisOrigin:axisDirection:radius:extent:)` take the extent; status is
`.noError` if and only if the matching drill returns a shape.

The extent enum also fills the two unwrapped modes: `.untilEnd` (`PerformUntilEnd` — the
stock-bounded through hole callers reach for `.throughAll` expecting) and `.range(from:to:)` (the
ranged `Perform`). The four v0.71.0 methods are unchanged in behaviour and now forward onto the
unified spelling; no existing call site needs editing.

**A wrong answer found and documented, not fixed here.** `PerformUntilEnd` and the ranged `Perform`
both end in an `nbparts >= 2` branch that keeps exactly one part of the cutting tool. Across a stack
of two solids the kept part can be one that intersects nothing, and the operation then reports
`BRepFeat_NoError` while removing **no material at all**, having only imprinted the cylinder's faces.
`Perform` and the boolean drill both cut every body. Kernel behaviour and out of scope here, filed as
#532 and **since fixed** — see the entry below. The
ranged overload's parameters were also measured rather than assumed: the window selects **which
entry/exit face pair** bounds the hole, it does not trim the cut, so a window strictly inside one body
still drills through all of it.

`Issue496CylindricalHoleTests` (`Tests/OCCTModelingTests`), 13 tests. Seven were run against the
unmodified bridge first (the #489 lesson) and five of those already passed — the divergences the fix
documents rather than repairs. Both repairs were confirmed by injecting the old behaviour back and
watching the suite fail. A thirteenth, added during review, sweeps blind depths tight around the
plate's exact exit-face parameter: the status query short-circuits before `Build()` runs, so it can
only ever see `PerformBlind`'s a priori `HoleTooLong` check, never `Validate()`'s post-hoc one — the
two are independent computations that could in principle disagree right at the boundary. Measured:
they agree, closing the gap rather than finding a live divergence.

#### `FilletBuilder`'s three radius laws are keyed by an edge, and now check that they are (#505)

**Behaviour change, and it is a bug fix.** `FilletBuilder.getBounds(contour:edge:)`,
`getLaw(contour:edge:)` and `setLaw(contour:edge:law:)` used to answer about a `(contour, edge)` pair
that names nothing: a contour index of `0`, an edge from a *different* contour, an edge in no
contour at all. They now return `nil` / `false` for those.

**Not source-breaking.** `getBounds` and `getLaw` gain an `edge: Edge` spelling, and the `edge: Shape`
one they had is deprecated and forwards to it.

The audit finding was a type inconsistency: `OCCTFilletBuilderSetLaw` took an `OCCTEdgeRef` while its
two siblings took an `OCCTShapeRef`, so two of the three had to downcast with `TopoDS::Edge` while the
third did not, and a caller holding an `Edge` (the type `addEdge`, `removeEdge`, `setRadius` and
`contour(for:)` all take) had to convert it to a `Shape` to read a law and hand back the original to
write one. The pre-existing test carried the round trip and a comment about it. All three OCCT
functions take a `const TopoDS_Edge&`, so `SetLaw` was the one that had it right and the framing of
the finding (four functions in the doc group agree, `SetLaw` is the outlier) counted the wrong
majority: `Generated`/`Modified`/`IsDeleted` sit in the same group and genuinely take a
`const TopoDS_Shape&`, since any sub-shape can be asked about. They keep `OCCTShapeRef`.

Making the three identical is what surfaced the real defect. They all resolve the edge through
`ChFiDS_FilSpine::ChangeLaw(E)`, which asks `ChFiDS_Spine::Index(E)` for the edge's position in the
contour's spine, gets `0` for an edge that spine does not hold, and uses it anyway:
`ElSpine(0)` → `FirstParameter(0)` → `abscissa->Value(0 - 1)`. That read has no live bounds check,
because OCCT's `*_Raise_if` macros are compiled out of the pinned Release build, and neither does
`ChFi3d_FilBuilder`'s own `Value(IC)`. Measured on a 10×10×10 box
([`Scripts/repro/505-filletbuilder-edge-type/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/505-filletbuilder-edge-type)):

```swift
// Two contours. Before #505, every one of these answered, and reported success.
builder.getBounds(contour: 1, edge: edgeOfContour2)   // (-5, 15) and contour 1's law
builder.getBounds(contour: 1, edge: edgeInNoContour)  // (-5, 15), same
builder.getBounds(contour: 0, edge: edgeOfContour1)   // (-5, 15), same
builder.setLaw(contour: 1, edge: edgeInNoContour, law: law)   // true, and it overwrote contour 1's law

// After: nil, nil, nil, false.
```

Only the low side of the contour range leaked, since OCCT does check `IC <= NbElements()`, so `2` and `99`
already returned `false`. `Contour(E)` is the same `IsSame` walk over the same spines that `Index(E)`
is about to do, so it decides exactly this question, and `Add()` rather than `Build()` populates it,
which makes it valid before a build as well as after. One helper,
`occtFilletContourHoldsEdge`, applies it to all three.

Three things the same measurements pin, now documented on the API for the first time:

- **A constant-radius contour has no law.** OCCT throws "no law on constant edges" rather than
  handing back a flat one, so all three report no law. The old test's comment called this a "crash";
  it is a `Standard_DomainError`, and the bridge's `catch (...)` already turned it into `nil`.
- **The law needs a spine split.** Before `build()` there is nothing to read, and
  `simulate(contour:)` is the other way to get one. After it the range is the spine's own `[0, 10]`
  rather than the post-build `[-5, 15]`, which runs past both ends of the edge.
- **`setLaw` does not reach the geometry.** `getLaw` reads the new law back, but a `build()` after it
  reports `IsDone() == 1` and hands back the *unfilleted* input shape, and setting the law before the
  first build (via `simulate`) then building produces the volume the original `addEdge` radii give,
  not the one the new law asks for. Upstream behaviour; the doc comment says so.

`setLaw` had no test at all before this: the one function of the three whose type was right was also
the uncovered one. `Issue505FilletBuilderEdgeTypeTests` (`Tests/OCCTModelingTests`) covers all three
through a single `Edge` value, the round trip that used to need a conversion each way. Run with the
guard removed, the suite fails every time, but with 11 to 18 recorded issues across five runs: the
unguarded answer is whatever the out-of-bounds read finds, so it is another contour's law on one run
and a "no law on constant edges" throw on the next.

Bridge and Swift only: no kernel patch, no `OCCT.xcframework` rebuild.

#### Fix: `LawFunction.knotSplitting` reported at most 100 splits, whatever the law had (#481)

`LawFunction.knotSplitting(continuityOrder:)` read into a fixed 100-entry buffer and returned
however many entries came back, so a law with more splits than that reported exactly 100 with
nothing to say the rest had been dropped. Its sibling `knotSplitParameters(continuityOrder:)`,
added alongside it in #403 over the same `Law_BSplineKnotSplitting` analyzer and the same law,
reads the true count and retries at that size. The two therefore disagreed about how many splits
a law has: measured on a degree-3 law with 150 knots of multiplicity 3, `knotSplitting` returned
100 indices and `knotSplitParameters` returned 150 parameters.

The issue's proposed fix, applying the sibling's read-then-retry in Swift, could not work on its
own. `OCCTLawBSplineKnotSplitting` returned `min(maxIndices, nbSplits)`, the count it had
*written*, so at a 100-entry first pass a truncated result is indistinguishable from a law with
exactly 100 splits and there is nothing to size a retry from. The bridge function now reports the
true split count even when the write was truncated, and fails with `-1`, matching
`OCCTLawBSplineKnotSplitParams` in both respects. That is a **C-layer contract change**: a direct
caller of the bridge that treated the return value as "entries written" now needs to clamp it, and
one that treated `0` as failure now sees `-1`. `OCCTBridge` is not an SPM product, so no package
outside this repo can be that caller.

Both bridge functions now share one `occtWriteKnotSplits` helper, generalised from #403's
`occtWriteKnotSplitParams` (which is now a thin wrapper over it), so the two cannot drift apart on
their truncation contract again. This is the same defect and the same fix as
`Curve3D.continuityBreaks` (#398, a fixed 256-entry buffer) and `Surface.knotSplitting` (#403).

`Issue481LawKnotSplittingTruncationTests` (`Tests/OCCTCurveTests`), 4 tests, run against the
unmodified bridge first: the count-agreement test failed at 100 versus 150, which is the property
the truncation broke.

### `OCCT.xcframework` rebuilt: the #484 null-context guard is now in the kernel binary (#512)

A carried patch does nothing until the xcframework is rebuilt from source, so `0017` above was inert
on merge. The kernel is now rebuilt from `V8_0_0_p1` + all **19** carried patches:
`ShapeFix_ComposeShell::Perform()`, `ShapeFix_ComposeShell::SplitEdges()` and
`ShapeUpgrade_WireDivide::Perform()` no longer SIGSEGV when the caller never set a
`ShapeBuild_ReShape` context.

**No API change and no behaviour change through this wrapper.** Both bridge call sites already set a
context, so nothing here could reach the crash before or after; those workarounds stay in place, and
retiring them is a later follow-up (the same PR1→PR2 pattern as #298/#341/#344/#349). What the
rebuild buys is closing the crash for code that reaches those OCCT classes through a path this
package does not control.

Verified against the rebuilt binary with **no** override-linked TUs. The earlier #484 evidence was
all override-linked, which proves the patch compiles and works, not that it shipped. Both `ctx=NO`
cases in `repro_484_crash.mm` complete where they were killed by SIGSEGV before, and all four
`ctx=yes` fingerprints in `repro_484_equivalence.mm` are unchanged (now recorded as reference values
in [`Scripts/repro/484-null-reshape-context/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/484-null-reshape-context)).
Full `swift test`: 4842 tests in 1346 suites, clean. `0017` itself needs no ThreadSanitizer gate,
being a null-handle guard on a single-threaded path, but the gate did run for the `0016` redesign
below, which ships in the same rebuild.

`Package.swift`'s remote `url:`/`checksum:` pin and the kernel-patch list on the `## Current:` line
above are the **release commit's** job, not this change's: until then a consumer resolving the remote
URL still gets the previously released kernel, while this checkout and every sibling repo
path-depending on its `Libraries/OCCT.xcframework` get the new one. `docs/guides/building-occt.md`
gained a "Shipping a rebuild" section covering that sequence, which until now existed only as
hand-written checklists in issues. Patch `0016` (#374) also gained the
`Scripts/patches/README.md` entry it never got. The rebuild carries `0018` (#555) and `0019` (#522)
as well, both added after this entry was first written.

### `Storage_Schema`'s scratch state becomes a member instead of a guarded global (#518)

Patch `0016` (#374) fixed two kernel races: `Resource_Manager::Debug` became `std::atomic<bool>`, and
`Storage_Schema::ICurrentData()`, a function-local `static Handle(Storage_Data)` shared by every
`Storage_Schema` in the process, was guarded by a new recursive mutex held across `Write()` and every
internal accessor. Reviewing our upstream PR
[OCCT#1399](https://github.com/Open-Cascade-SAS/OCCT/pull/1399#issuecomment-5112586065), maintainer
gkv311 pointed out the second half should not need a lock at all: the handle can just be a
`mutable Handle(Storage_Data)` field on the class.

That holds up. **Every** `Storage_Schema` in the kernel is constructed locally by its caller and used
only there (`PCDM_StorageDriver::Write`, and `PCDM_ReadWriter_1` at three sites); none is cached or
shared, and `Storage_CallBack::Add`/`Write`/`Read` all take the driving schema as an argument, so
every callback re-entry lands back on the same instance. The state was per-instance data
masquerading as a global. `0016` now deletes the static and the mutex in favour of the field, and
also drops the `static` from `AddPersistent()`'s `TCollection_AsciiString aTypeName` scratch
variable, a smaller hazard in the same class that the mutex had covered incidentally. Both
`ICurrentData()` and `ISetCurrentData()` were private with no callers outside the class, so nothing
observable changes.

Same correction, and the same lesson, as #341 to #363: a lock is the right tool only when the state
is genuinely one shared resource. It is also strictly stronger on the failure #374 reported, since a
throwaway schema built during an unrelated `Open()` can no longer reach an in-flight `Write()`'s data
at all, where the mutex only stopped it from being a data race.

No OCCTSwift API or behaviour change, and the patch number stays `0016` (a corrected design, not a
new fix), renamed to `...-Storage_Schema-per-instance-374.patch`. Verified with the same #374
ThreadSanitizer harness the mutex version was verified against: 0 races and 0 save/load/verify
failures at 8×50, 8×30 and 10×60, plus the full `Scripts/tsan-stress.sh run` gate (10 scenarios)
clean. Ships in the same rebuild as #512 above. OCCT#1399 has since been updated to this design and
is green on all 17 upstream CI jobs.

### Two `GCPnts` point-count defects patched in the kernel (#555)

New carried patch `0018`, in the arc-length samplers behind `Curve3D.quasiUniformParameters(count:)`,
`Curve3D.drawUniform(pointCount:)`, `Curve2D.drawUniform(pointCount:)`, `Shape.uniformAbscissa` and
the `sampleUniform(count:)` family.

**`NbPoints()` was not bounded by the requested count.** `GCPnts_UniformAbscissa` sizes its parameter
array at `theNbPoints + 5` and walks until it reaches the end parameter or runs out of room, so a
caller sizing its own buffer from the request could be handed more points than it asked for.
`GCPnts_QuasiUniformAbscissa` inherited this for every curve that is neither Bezier nor BSpline. The
cause is a tolerance mismatch: the walk terminates on a parametric epsilon derived from the curve's
*largest* derivative, which on an ellipse with major radius 1e6 and minor radius 1e-3 is about nine
orders of magnitude too tight at the end, so the walk stops 1.557e-08 short, takes one more step and
appends what is measurably a duplicate point (1.175e-10 away in 3D). `Perform` now also accepts a
point that coincides with the end in 3D within the caller's tolerance. Clamping the count instead
would have dropped the exact end parameter and left the distribution stopping short of the curve.

**A point count below 2 stored out of bounds.** Both classes document `theNbPoints >= 2` and enforce
it with `Standard_ConstructionError_Raise_if`, which compiles to nothing in the shipped Release
kernel (#487). `GCPnts_QuasiUniformAbscissa`'s Bezier/BSpline branch then allocated an empty array
and unconditionally stored into index 1 of it: an uncatchable SIGSEGV, the same class as #263, #310,
#317 and #318. Both classes now leave the object not done for such a count, so a request for zero
points is answered with nothing rather than with a crash or with five parameters.

`Shape.uniformAbscissa(pointCount:)` and friends already rejected degenerate counts bridge-side after
#501, and the buffer overflow was closed there too, so **no OCCTSwift API changes behaviour here**.
What the patch buys is closing both for code that reaches those OCCT classes through a path this
package does not control.

Measured across 17 curve types and counts 2 to 200 (6766 configurations): **232 lines change and they
are exactly the 232 that were over-requesting**, every other line byte-identical, and the last
parameter still exactly the end on the changed ones. Reproducers, including the trap that a repro
built without `-DNo_Exception` measures a kernel nobody ships:
[`Scripts/repro/555-gcpnts-count-contract/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/555-gcpnts-count-contract).
Filed upstream as [OCCT#1417](https://github.com/Open-Cascade-SAS/OCCT/pull/1417).

### Surface approximation at C0 stops collapsing, and its reported error starts being true (#522)

New carried patch `0019`, behind `Surface.approximated(tolerance:continuity:)` and
`Surface.approxWithDetails(tolerance:uContinuity:vContinuity:)` — and behind a good deal of the OCCT
kernel besides.

A radius-10 sphere approximated at C0 and tolerance 1e-3 came back as a **degree-1, 2-pole-in-U
B-spline**: a straight line across the full `2*pi` of its longitude, deviating by the sphere's own
diameter of 20, while `isDone` said the tolerance was met and `maxError` said 1.07e-4. A bicubic
Bezier at C0 collapsed to a 2x2 bilinear patch reporting 4.08e-15 at every tolerance from 1e-1 down
to 1e-7 — tightening the request changed nothing.

One line in `AdvApp2Var_ApproxF2var::mma2ce1_` explains both. It partitions a single scratch
allocation into seven buffers, `ipt4` for `XMAXJU` (the maxima of the U Jacobi polynomials) and
`ipt5` for `XMAXJV`, then fills **both from `ipt5`**, leaving `XMAXJU` unwritten and in practice
zero. Every truncation error the approximator computes is
`|coefficient| * XMAXJU(i) * XMAXJV(j)`, so a zero `XMAXJU` makes the interior error of every patch
evaluate to exactly 0. From there: the tolerance test can never fire on the interior, `maxError`
only ever describes the boundary iso-curves, and the degree-reduction search — asked for the lowest
degree whose truncation error still fits — always answers with its floor, because every candidate
scores 0. C0 is where that floor is low (a full sphere's V-boundary isos are its two poles, one
coefficient each), which is why C0 collapsed and C1/C2 did not. The misreported error was never
specific to C0.

Across a 98-case sweep (7 surface families x all 9 (uContinuity, vContinuity) combinations of
C0/C1/C2, plus C0/C0 at five tolerances), results whose real deviation exceeds the reported
`maxError` by more than 10x go from **12 to 0**, and those exceeding it at all from 17 to 1 — the
survivor a Bezier reproduced exactly, reporting 9.95221e-15 against a measured 9.96978e-15. Every
reported error rises slightly, which is the interior contribution being counted for the first time.
Degrees rise only where the collapse was happening: a cylinder trimmed in V still fits at degree 1 in
V, because it *is* linear there.

`GeomConvert_ApproxSurface` is not a leaf. `GeomFill_Sweep`, `BRepOffset_Offset`, `GeomLib`,
`ShapeCustom_BSplineRestriction`, `ShapeConstruct` and `GeomConvert_1` all call it,
`ShapeCustom_ConvertToBSpline` and `ShapeUpgrade_UnifySameDomain` reach it, and
`GeomPlate_MakeApprox` drives the same approximator directly. Most request C1 or C2, so the collapse
could not reach them, but the always-zero interior error could — and the healing paths reach C0 on
purpose: `ShapeConstruct::ConvertSurfaceToBSpline` and `ShapeCustom_BSplineRestriction` both loop the
requested continuity down to 0 on failure, then accept the result on `MaxError() <= tol`, and
`ShapeCustom_ConvertToBSpline` *starts* at C0 for any offset surface
(`ShapeCustom_ConvertToBSpline.cxx:148`) before handing off to the first of those. The two remaining
mentions of the class, `BRepFill_Sweep.cxx:1162` and `BRepFill_Filling.cxx:712`, are both inside
comment blocks and are not callers. Follow-ups filed for what this means per consumer.

`Tests/OCCTSurfaceTests/Issue491SurfaceApproxParityTests.swift`'s `maxErrorDescribesTheSharedFit`
had to exclude `.c0` requests when it was written, because "sampled deviation <= reported maxError"
failed there on OCCT's own numbers. That exclusion is gone. Reproducers, the root-cause walkthrough
and the before/after sweep transcripts:
[`Scripts/repro/522-approx-c0-collapse/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/522-approx-c0-collapse).
Filed upstream as [OCCT#1418](https://github.com/Open-Cascade-SAS/OCCT/pull/1418).

### New workflow: `kernel-integration.yml` validates a carried patch against the patched kernel (#585)

`ci.yml`'s macOS check always resolves `Package.swift`'s pinned, **released** OCCT.xcframework, since
a clean checkout has no local `Libraries/`. A PR that carries a kernel patch not yet in a release
and adds a regression test for its fixed behaviour therefore fails that check indistinguishably
from a real regression: #519 (patches `0016`(redesign)/`0018`/`0019`, closing #518/#522/#555) hit
this exactly, its new #522 test reproducing the original bug's own symptom against the stale
kernel, needing a manual dig to tell "expected gap" apart from "the patch doesn't work." The old
`ci.yml` comment already named the fix and never built it: "that's `kernel-rebuild.yml`'s job,
~30-60 min" describes a workflow that never existed anywhere in this repo's history.

`kernel-integration.yml` is that workflow, finally built. It triggers only on a PR/push touching
`Scripts/patches/**` or `Scripts/build-occt.sh`, so ordinary PRs stay on the fast `ci.yml` path.
`actions/cache@v4` keys on a hash of the patch files plus the build script itself (so a pinned-OCCT
version bump also invalidates it): the first run after a patch changes pays the full rebuild, every
later run with the same patch set restores `Libraries/OCCT.xcframework` in seconds. Deliberately
caches only the **final** xcframework, never the intermediate `occt-build-*`/`occt-src` trees —
`CMakeCache.txt` bakes in the configuring checkout's absolute path, which a fresh runner never
reuses, so caching a half-built tree would just restore an unusable cache every run (the same
gotcha `docs/guides/building-occt.md` already documents for resuming an interrupted local build).
`ci.yml`'s own comment now points here instead of describing the rebuild as manual-only.

---

## Release History

### Unreleased: fix, zero-mass `BRepGProp` results were returned as successful answers (#609)

> Version and date deliberately unset; whoever tags stamps them.
>
> **This entry contains source-breaking changes.** They are held for the next major
> ([`SEMVER.md`](SEMVER.md)); do not tag this into a 1.x release.

`GProp_GProps` legitimately has zero mass: ask for volume properties of a face, or surface
properties of an edge, and there is no such quantity. OCCT's contract is that the caller checks
`Mass()`, and passes `OnlyClosed` when it wants the volume integral to refuse an open surface rather
than estimate one. The bridge never did either, across 22 user-facing entry points. #605 fixed the
first two; this is the rest.

**The wrong answer was not a recognisable zero.** `GProp_GProps` seeds itself with `gp_Pnt(0,0,0)`
transformed by the shape's *location*, so a face moved to (100,200,300) reported exactly that, and
moved again reported (200,400,600). No consumer could defend itself with `if com == .zero`:

```swift
face.centroid                            // was (0,0,0)       -> now nil
face.moved(dx: 100, dy: 200, dz: 300)!.centroid   // was (100,200,300)  -> now nil
```

**And everything derived from a zero-mass framework was an artefact, not a zero.** Measured:

```swift
sheet.radiusOfGyration(axisOrigin: .zero, direction: SIMD3(0,0,1))  // was NaN, now nil
sheet.principalAxes()      // was (0,0,1)/(1,0,0)/(0,1,0), math_Jacobi's identity basis; now nil
sheet.symmetryAxes()       // was 3 axes claiming SPHERICAL symmetry; now []
sheet.inertiaProperties()?.hasSymmetryPoint   // was true for every face, edge, wire and vertex
```

**`OnlyClosed = true` also fixes a wrong answer for closed geometry.** A compound of a 10x20x30 box
plus one loose face reported 6857.14 where the box's volume is 6000: the divergence integral runs
over whatever faces it is given.

```swift
Shape.compound([box, someFace])?.volume   // was 6857.14, now 6000
openShell.volume                          // was 4800,    now nil
```

That closes the inconsistency #605 left behind, where `open.volume` was 4800 while
`open.properties()?.volume` was nil for the same shape.

**`signedVolume` is deliberately excluded, and is now documented as an orientation signal rather
than a measurement.** Reversing a surface negates the divergence integral whether or not the surface
is closed (+4800 forward, -4800 reversed), so the sign is sound where the magnitude is not.
`Shape.sweep` produces an **open shell** and normalises it through `orientedForward()` (#170), so
routing this through the strict volume would have silently stopped normalising the exact case #170
was filed about. The full-suite run is what caught that; the ground truth is in the reproducer.

#### Behaviour changes without a compile error

| API | was | now |
|---|---|---|
| `volume` | the divergence integral over any faces given | nil unless a closed shell encloses it |
| `signedVolume` | `-1` on an internal error | `0`, so `orientedForward()` stops reading an error as "reverse me" |
| `volumeInertia`, `inertiaProperties()` | an artefact framework | nil outside the volume domain |
| `surfaceInertia`, `surfaceInertiaProperties()` | an artefact framework | nil for a shape with no faces |
| `symmetryAxes()` | 3 axes for any zero-mass shape | `[]` |

#### Source breaks

| API | was | now |
|---|---|---|
| `Shape.centroid` | `SIMD3<Double>` | `SIMD3<Double>?` |
| `Shape.linearProperties()` | `LinearProperties` | `LinearProperties?` |
| `Shape.momentOfInertia()` | `InertiaTensor` | `InertiaTensor?` |
| `Shape.principalAxes()` | `PrincipalAxes` | `PrincipalAxes?` |
| `Shape.radiusOfGyration(axisOrigin:direction:)` | `Double` | `Double?` |
| `GeometryProperties.barycentre(_:)` | `SIMD3<Double>` | `SIMD3<Double>?` |
| `GeometryProperties.lineSegment(from:to:)` | a tuple | an optional tuple, nil for coincident endpoints |
| `GeometryProperties.circularArc(...)` | a tuple | an optional tuple, nil for a zero normal |
| `GeometryProperties.pointSetCentroid(_:)`, `.weightedCentroid(points:weights:)` | `centroid: SIMD3<Double>` | `centroid: SIMD3<Double>?` |
| `CurveInertia`, `FaceSurfaceInertia`, `FaceVolumeInertia`, `MeshCinertResult`, `MeshPropsResult` | `centerX`/`centerY`/`centerZ` | `centerOfMass: SIMD3<Double>?` |
| `Shape.VinertGKResult.center` | `SIMD3<Double>` | `SIMD3<Double>?` |
| `ShapeMeasurements.faceCentroids` | `[SIMD3<Double>]` | `[SIMD3<Double>?]` |

The mass alongside each of those stays non-optional on purpose. A zero volume contribution from one
face of a shell is a real answer a caller summing the decomposition needs; only the centroid is
missing.

**That rule applies to the per-element results, not to the whole-shape queries**, and the difference
is deliberate rather than an oversight. `Face.surfaceInertia` and `Face.volumeInertia` are summands
of a decomposition, so they keep their `area` / `volume` of 0 and drop only the centroid.
`Shape.surfaceInertia`, `Shape.volumeInertia`, `inertiaProperties()` and `linearProperties()` answer
"measure this object", where a zero mass means the measure does not apply at all, so the whole result
is nil. The plain mass accessors are unaffected either way: `Shape.surfaceArea` still returns `0.0`
for an edge and `Shape.totalEdgeLength` still returns `0.0` for a vertex, because a mass with no
centroid attached to it needs no refusal.

`GeometryProperties`' analytic members keep answering for a valid element measured over an empty
range: `GProp_CelGProps` computes its centroid analytically, so an arc with `u1 == u2` has a mass of
0 and a *correct* centre. Only inputs OCCT rejects return nil there.

#### Migration

Nothing changes for a solid. Outside the volume domain, ask the measure that applies:
`surfaceInertia` for an area centroid, `linearProperties()` for a length centroid,
`vertices().first` for a vertex position. For geometry that is closed but unsewn (mesh-derived
imports, and every IGES import, which carries surfaces and no solid concept), sew before asking for
a volume:

```swift
let imported = try Shape.loadIGES(from: url)
imported.volume                                  // nil: six loose faces are not a closed shell
Shape.sew(shapes: imported.faces().compactMap { Shape.fromFace($0) })?.volume   // 3000
```

`BRep_Tool::IsClosed` counts topological edge sharing, not geometric coincidence, so this is the
one behaviour change with real teeth downstream. Both of our own IGES round-trip tests hit it.

`volume`'s nil does not distinguish "no closed shell" from "closed, but with its faces pointing
inward": a reversed solid has always returned nil there, since the accessor drops a negative. Sewing
does not help the second case. A caller that needs to tell them apart should ask `signedVolume`,
which answers for both, and normalise with `orientedForward()`:

```swift
shape.volume                          // nil for an open shell AND for a reversed solid
shape.orientedForward()?.volume       // a number for the reversed solid, still nil for the shell
```

#### Downstream, tracked before the release train

- **SecondMouseAU/OCCTReconstruct#553** (P1). Builds solids from mesh data and gates on
  `volume`/`signedVolume` at ~25 sites, including `ReconstructBuild.swift:591` where
  `thin.shape.volume != nil` guards a whole reconstruction tier with no `isValidSolid` beside it.
  `signedVolume` is unaffected by design; `volume` needs a sew on any path that does not already
  have one. A tier that stops firing will not fail a test on its own.
- **SecondMouseAU/OCCTDesignLoop#67** (P2). `ProfileLift.swift:232` and
  `PerpendicularBoolean.swift:134` do `volume ?? abs(signedVolume)`, a fallback that was nearly
  unreachable and now converts "no volume" into the exact fabricated figure this fix removes.
- **SecondMouseAU/OCCTMCP#168** (P1, already open for #605, noted there). `compute_metrics` now
  omits `volume` / `centerOfMass` for a sheet body or unsewn import rather than reporting a figure.
  No code change needed; it already propagates nil.

**Release-train checklist:**

1. Land OCCTReconstruct#553 and OCCTDesignLoop#67 before bumping either repo's OCCTSwift pin past
   this release.
2. **Rebuild `OCCTBridge.xcframework` and bump its `Package.swift` URL and checksum in the release
   commit.** Nine C symbol signatures changed in the public `OCCTBridge.h`
   (`OCCTShapeGetVolume`, `OCCTShapeLinearProperties`, `OCCTShapeMomentOfInertia`,
   `OCCTShapePrincipalAxes`, `OCCTShapeRadiusOfGyration`, `OCCTShapeCentroid`,
   `OCCTGPropLineSegment`, `OCCTGPropCircularArc`, `OCCTGPropBarycentre`), so a consumer building
   with `OCCTSWIFT_BRIDGE_PREBUILT=1` against a stale prebuilt bridge gets a wall of compile errors
   (`cannot convert value of type 'Double' to expected condition type 'Bool'`) until it is
   refreshed. `Scripts/build-occtbridge.sh` builds it. Per #512 the URL and checksum bump belongs to
   the release commit, not to this one.

No kernel patch and no `OCCT.xcframework` rebuild: the pinned OCCT binary is untouched, and only the
bridge and Swift sources changed. Reproducer and full measured output in
[`Scripts/repro/609-zero-mass/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/609-zero-mass).

Closes #609

---

### Unreleased: fix, `centerOfMass` returned the bounding-box centre (#605)

> Version and date deliberately unset; whoever tags stamps them.

`Shape.centerOfMass` and `Shape.properties().centerOfMass` computed the midpoint of
`BRepBndLib::Add`'s bounding box instead of calling `BRepGProp`, under a comment claiming
`GProp_GProps::CentreOfMass()` "appears to return (0,0,0) for some shapes". Wrong since v0.7.0
(2026-01-14) and wrong for every shape not symmetric about its bounding box: a plain cone reported
`(0, 0, 10)` where its centre of mass is `(0, 0, 5)`, and a 10-cube unioned with a 2-cube 20 units
away reported `8.0` against an analytic `0.1587`, off by a factor of 50. These were the only two
bounding-box centroids in the bridge; `centroid`, `volumeInertia`, `surfaceInertia`,
`inertiaProperties()`, `linearProperties()` and `measure().faceCentroids` were all already correct,
so the API contradicted itself: `cone.centerOfMass` and `cone.centroid` disagreed by 2x.

Fixed by following `BRepGProp` rather than inventing a dispatch OCCT does not have. Ground truth
against the pinned kernel (`Scripts/repro/605-center-of-mass/`) established three things:

- **An open shell is refused, not estimated.** `BRepGProp::VolumeProperties` defaults to
  `OnlyClosed = false`, and the divergence integral over a surface enclosing nothing returns a
  number anyway: 4800 with a centroid 2.6 units adrift, for five faces of a 10x20x30 box. Both sites
  now pass `OnlyClosed = true`, matching OCCT's own `XCAFDoc_Centroid` writer (`XDEDRAW_Props.cxx`)
  and the `c` flag on Draw's `vprops`. Closing an open shell is the caller's decision, so the API
  declines to guess one. Closedness is computed per shell by `BRep_Tool::IsClosed` rather than read
  from a cached flag, so a sewn-but-unflagged closed shell still counts, and a closed shell outside
  any solid counts too: the key is closedness, not `ShapeType() == SOLID`.
- **A zero-mass result is not a recognisable zero.** `VolumeProperties` seeds its framework with
  `gp_Pnt(0,0,0)` transformed by the shape's location, so a face at (100,200,300) reports a
  centre of mass of exactly that. `Mass()` is the only sound test, and both sites now use it: a
  face, wire, edge, vertex or open shell returns `nil` rather than a plausible-looking point.
- **The inertia tensor was never affected.** It is referenced to the centre of mass
  (`Iyy = 16666.67` for a 10-cube at x=20, against `416666.67` about the origin) and passes through
  unchanged. The defect was that `ShapeProperties` sat a COM-referenced tensor next to a field that
  was not the COM; that is now coherent.

**Behaviour change for consumers.** `centerOfMass` and `properties()` now return `nil` for shapes
that enclose no volume, where they previously returned a bounding-box centre. Callers using
`Shape.centerOfMass` as a positional key for a face, edge or vertex should move to `vertices()` for
a vertex position, `surfaceInertia` for an area centroid, or `linearProperties()` for a length
centroid, all of which were already correct. No API signature changed, so this is a change of value
rather than a compile error.

**Release train.** Two consumers are affected and are filed, not fixed here. Land
[OCCTMCP#168](https://github.com/SecondMouseAU/OCCTMCP/issues/168) *before* bumping OCCTMCP's
OCCTSwift pin past this release: four vertex sites there read `centerOfMass ?? .zero`, and the `??`
would swallow the new `nil` and collapse every vertex onto the origin without an error.
[OCCTReconstruct#552](https://github.com/SecondMouseAU/OCCTReconstruct/issues/552) is a re-run only,
no code change expected.

Nine regression tests (`Tests/OCCTAnalysisTests/CenterOfMassTests.swift`), each on a shape whose
bounding-box centre differs from its centre of mass, since every pre-existing assertion used a box
or cylinder centred at the origin where the two coincide. Verified by injecting each wrong
implementation in turn: the original bounding-box version fails 7 of the 9, `OnlyClosed = false`
fails the open-shell test with the fabricated 4800, and dropping the `Mass()` guard fails 2.

Not an OCCT bug, so nothing filed upstream. Sibling defect #609 (zero-mass results returned as
successful answers across seven other surfaces, including `Shape.volume` still reporting 4800 for
an open shell) was filed from this investigation and is not addressed here. #605.

### Unreleased: fix, a cancelled import could report `.importFailed` instead of `.cancelled` (#525)

> Version and date deliberately unset; whoever tags stamps them.

`OCCTImportSTEPRobustProgress` set `*outCancelled` only at its own explicit `UserBreak()`
checkpoints, so which error a cancelled import reported depended on which phase the cancellation
happened to land in. A break during the transfer leaves `TransferRoots` reporting zero transferred
roots, and that exit returned "failed" with the flag still false:

```swift
// Deadline expires while the transfer is still running
catch ImportError.importFailed("Failed to import: /tmp/part.step")   // was: for a readable file
catch ImportError.cancelled                                          // now
```

Found as a flake in #300's own regression test, which set its deadline at 0.75 × a wall-clock
measurement of a preceding uncancelled import: machine load, not the bridge, decided which phase
the deadline fell in, and about 1 run in 9 fell in the transfer. Any caller whose deadline expires
early reaches the same path.

Every failure exit below the indicator's construction now reports cancellation if a break was
observed — the zero-roots exit, a null shape, a non-`Done` status, and the `catch (...)` handler
(which needed the indicator hoisted out of the `try`). Applied across all twelve `*Progress` entry
points in `OCCTBridge_IO.mm`, not only the two robust importers, since they share the shape.

A second defect surfaced while probing the first: `BridgeProgressIndicator::UserBreak()` re-asked
the caller at every checkpoint and believed the latest answer, so a caller that answers `true`
**once** — a one-shot flag, an already-consumed `Task.isCancelled` — had that answer overwritten.
OCCT aborted the phase, the next poll said "no break", and the half-repaired shape came back as a
*success*. The break is now latched (`std::atomic<bool>`, since OCCT documents `UserBreak()` as
callable concurrently), which is what `ImportProgress.shouldCancel` always documented.

Both `#300` regression tests were rewritten off the clock. That the repair phase lies inside the
caller's progress range is now checked by the silence that would follow the last progress report
if it did not: measured at 1.3% (STEP) and 3.4% (IGES) of the call with the fix, 35–40% with the
#300 defect reintroduced. That a cancellation there *stops* the repair is checked against the
uncancelled run's poll count — a count of work items, not a duration, and identical on a loaded and
an idle machine. Progress *names* cannot substitute for the phase, tempting as they look: both
readers run a `ShapeFix_Shape` of their own during the transfer, so `Fixing face` / `Fixing edge` /
`Update tolerances` are already being reported from fraction ~0.09.

Bridge-only change: no OCCT kernel patch, no `OCCT.xcframework` rebuild; `OCCTBridge.xcframework`
needs one since `OCCTBridge_IO.mm` changed. The previously flaky suites ran 12/12 clean; each new
test was verified to fail against the defect it covers, re-injected one at a time.

### Unreleased: fix, a refused `FillingSurface.add` still let `build()` return a face (#482)

> Version and date deliberately unset; whoever tags stamps them.

#434 converged `FillingSurface` and `Shape.fill(constraints:)` onto one builder and one shared
`occtFillingAddConstraint`, but left them disagreeing about what a *refused* constraint means, and
the disagreement favoured the wrong outcome on the incremental API.

`occtFillingAddConstraint` refuses a constraint when a **nominated** support face carries no pcurve
for its edge, which is routine on imported or sewn shapes. It does not call `Add`, so that
constraint simply does not exist. `Shape.fill(constraints:)` has always treated that as fatal and
returned nil. `FillingSurface.add(edge:support:continuity:)` returned `false` and left the builder
usable, so `build()` went on to fit a surface to whatever constraints did make it in. Since every
`add` is `@discardableResult`, ignoring the signal was the default at the call site:

```swift
let f = FillingSurface()
f.add(edge: e1, continuity: .g0)
f.add(edge: rim, support: importedWall, continuity: .g1)   // false, silently dropped
let face = f.build()                                       // succeeded
```

That face was fitted to `e1` alone. It neither passed through nor was bounded by `rim`, the edge
the caller cared most about, and it reported a healthy G0 error (measured 2.8e-05 on the
truncated-sphere fixture) while doing so: a plausible wrong answer, not a visible failure. The
same geometry through `Shape.fill(constraints:)` returned nil.

The refusal is now **sticky**: the builder records it, and `build()` returns nil however many other
constraints succeeded, without attempting the fit at all, so `isDone` stays false and the face and
error accessors keep reporting "not built" rather than describing a surface no caller asked for.
The two entry points now answer the same for the same input, which is what the #434 convergence was
for. `@discardableResult` becomes harmless: the refusal is reported whether or not the return value
was read.

New: `FillingSurface.refusedConstraintCount` and `FillingSurface.hasRefusedConstraint`, which
separate "a constraint never made it in" from "the fit was attempted and failed". Both return nil
from `build()`:

```swift
guard let face = filling.build() else {
    print(filling.hasRefusedConstraint ? "a constraint was refused" : "the fit failed")
    return
}
```

**Source-compatible, behaviour-breaking.** No signature changed, but a caller who was relying on
`build()` succeeding after a refused `add` now gets nil. To attempt a constraint speculatively and
carry on, use `add(edge:continuity:)`, which derives the continuity reference from the edge itself
and so has nothing to refuse.

Two doc comments promised this behaviour before anything enforced it: `add(edge:support:)`'s "used
or the constraint fails" and `OCCTFillingAddEdgeWithSupport`'s "the caller should treat the whole
fill as failed". Both are now true.

Also fixed: the derived operation total in `README.md` / `docs/API_REFERENCE.md` was 4,266 against a
derived 4,268 before this change, a pre-existing two-entry-point drift unrelated to #482.
`Scripts/count-operations.py --fix` takes it to 4,270, of which two are the properties above.

### Unreleased: chore, every build of this package emitted an unhandled-file warning (#440)

> Version and date deliberately unset; whoever tags stamps them.

`swift build` emitted `found 1 file(s) which are unhandled; explicitly declare them as resources or
exclude from the target` on every build of this package.

The file was `Tests/OCCTStressTests/Fixtures/unify-crash-mmd-kiha10-body5.brep`, the 600 KB
mesh-sewn solid backing #348's null-pcurve regression test. It is read straight from the source tree
via `#filePath`, never through `Bundle.module`, so it is neither a build input nor a resource to
copy. `OCCTStressTests` now declares `exclude: ["Fixtures"]`, which is the accurate description of
what it is. Declaring it as a resource instead would have embedded 600 KB in the test bundle that
nothing reads.

**Who saw it:** builds of this package as the *root* package, which means our own dev loop and CI,
plus anyone who clones OCCTSwift and builds it directly. It did **not** reach downstream consumers.
SwiftPM does not construct test targets for non-root packages, so a consumer's build never had a
target that owned `Tests/` to diagnose. Measured on Swift 6.3.3 against a synthetic package: the
same stray file warns while its package is the root, stays silent through a path-dependency
consumer's `swift build` and `swift test`, and does propagate to that consumer once moved into a
*source* target. #440 claimed the warning reached every downstream consumer; that part of the issue
was wrong too, and the fix is worth having for the root-build noise alone.

**Correcting #440's own diagnosis:** the issue attributed the warning to
`Tests/occt_parallel_crash_portable.cpp` sitting unclaimed at the `Tests/` root. That file is not the
cause and never was: no target declares `path: "Tests"`, so SwiftPM does not scan the directory root
at all and never diagnosed it. Removing it changes nothing, and the warning names the `.brep` and
only the `.brep`. The fixture predates the issue by five days, so the misattribution was present from
filing.

The move #440 also asked for was still worth doing on its own merit, since a reproducer does not
belong in the package's test tree, but not to the suggested destination. That file is the
[OCCT#1179](https://github.com/Open-Cascade-SAS/OCCT/issues/1179) parallel-crash sweep (11
operation groups built around `Extrema_ExtElCS` and `ShapeUpgrade_FaceDivide`, committed April 2026,
three months before #342, with one boolean group out of eleven), so filing it under
`Scripts/repro/342-boolean-ops/` as "the same family of work" would have mislabelled it. It now has
its own `Scripts/repro/occt1179-parallel-crash/`, with a README covering what it sweeps, why it is
kept now that OCCT#1179 is fixed (our own [OCCT#1203](https://github.com/Open-Cascade-SAS/OCCT/pull/1203),
shipped in `V8_0_0`), and what distinguishes it from its boolean-concurrency siblings: it is the only
reproducer here driven by CI, on both Windows and macOS. The two paths in
`.github/workflows/occt-parallel-crash-test.yml` follow it.

No API change, no behaviour change, no kernel change.

### v1.17.0 (July 2026): pass 1a of the #377 duplication audit, and two source-breaking changes in a minor release

**Read this before upgrading. Two changes in this release break source compatibility, which
[`SEMVER.md`](SEMVER.md) reserves for a major bump.** The exception is deliberate and recorded
there; the major version stays reserved for OCCT 9.0. Nothing else in this release requires a
source change, and there is no binary or behavioural change to any API not named below.

#### Breaking: `Surface.drawMesh` and `Surface.evaluateGrid` return `SurfaceGrid` (#404)

Both previously returned `[[SIMD3<Double>]]`, and they nested in **opposite** orders:
`drawMesh` was `[uIndex][vIndex]`, `evaluateGrid` was `[vIndex][uIndex]`. Nothing at the type
level caught a caller mixing them up. They now share one `SurfaceGrid` type indexed by
`at(u:v:)`, so the ambiguity is gone rather than documented.

```swift
// Before
let mesh = surface.drawMesh(uCount: 30, vCount: 30)
for row in mesh { for p in row { emit(p) } }
let rows = mesh.count, cols = mesh[0].count

// After
let mesh = surface.drawMesh(uCount: 30, vCount: 30)
for u in 0..<mesh.uCount {
    for v in 0..<mesh.vCount {
        if let p = mesh.at(u: u, v: v) { emit(p) }
    }
}
let rows = mesh.uCount, cols = mesh.vCount
```

`SurfaceGrid` exposes `at(u:v:)`, `uCount`, `vCount` and `isEmpty`. It is not a `Collection` and
is not subscriptable, so the break is a compile error at every call site rather than anything
silent. **If you are migrating `evaluateGrid` specifically, check your index order**: its old
shape was `[v][u]`, so a mechanical rewrite that assumes `[u][v]` transposes the data.

No shim is possible here. Swift does not overload on return type alone, so a deprecated overload
with the old return type would be ambiguous at every call site that binds the result to a variable.

#### Breaking: `Curve3D.interpolate(points:startTangent:endTangent:)` removed (#400)

The no-`tolerance` overload shadowed its tolerance-aware sibling: Swift always prefers the exact
arity match, so the ordinary three-argument call could never reach the `tolerance:` parameter,
which was pinned at `1e-6` regardless of what a caller asked for.

```swift
// Before and after — identical source, and it now compiles against the tolerance-aware overload
let c = Curve3D.interpolate(points: pts, startTangent: t0, endTangent: t1)

// Now reachable for the first time
let c = Curve3D.interpolate(points: pts, startTangent: t0, endTangent: t1, tolerance: 1e-4)
```

In practice most call sites need no edit: the three-argument spelling still compiles and still
defaults to `1e-6`. It breaks only where the removed overload was referenced as a value
(`let f = Curve3D.interpolate(points:startTangent:endTangent:)`) or passed as a function argument.

#### Everything else

Pass 1a of the [#377](https://github.com/SecondMouseAU/OCCTSwift/issues/377) duplication audit:
27 issues, each a pair of API spellings that turned out not to mean the same thing. Eleven of
them change what an existing call returns without any compiler diagnostic, so the per-entry
sections below carry a **behaviour-change table** listing each one as was/now. If you upgrade
without reading anything else, read that table.

The individual entries follow: #477 (arc-length integrator), #433/#434 (`FillingSurface`
continuity), #398 (continuity enums), #399-#422 (the audit batch), #443 (first-of-N explorer
sites).

Consumers on the opt-in prebuilt bridge (`OCCTSWIFT_BRIDGE_PREBUILT=1`) **must** take this
release's `OCCTBridge.xcframework.zip`: the bridge's C ABI changed (`OCCTSurfaceKnotSplitting`
gained four parameters, five functions were removed), so a v1.16.1 bridge binary no longer
matches this Swift layer. `Package.swift`'s URL and checksum are bumped accordingly.
`OCCT.xcframework` is unchanged and stays pinned at its v1.15.18 asset: this release carries no
kernel patch changes.

### v1.17.0 (July 2026) — fix: Curve3D arc length was integrated as one quadrature across the whole domain (#477)

`Curve3D.length` and `Curve3D.length(from:to:)` measured arc length with
`CPnts_AbscissaPoint::Length`, a single Gauss quadrature of order ≤ 24 spanning the entire
parameter domain. That is exact for a line or a circle and wrong for anything with many spans, and
nothing signalled the difference: the call returned a plausible number. Every other arc-length call
site in the bridge (`Curve2D`, `Edge`, `WireCurve`, the property queries) already used
`GCPnts_AbscissaPoint::Length`, which splits the curve at its `GeomAbs_CN` interval boundaries and
integrates each span separately. These two were the only `CPnts_AbscissaPoint` call sites left in
the bridge, and the reference docs had already described them as `GCPnts` for some time.

Measured against a densely sampled polyline reference over the same domain, on the pinned kernel:

| curve | spans | GCPnts (now) | CPnts (before) |
|---|---|---|---|
| 40-pt interpolated BSpline, varying speed | 39 | `2.9e-7` rel. | **`5.1e-2` rel. (5% of 356 units)** |
| 60-pt interpolated helix | 59 | `4.3e-15` rel. | `3.9e-6` rel. |
| 5-pt interpolated BSpline | 4 | `6.9e-12` rel. | `2.5e-3` rel. |
| line, circle, arc | 1 | exact | exact |

(On the helix and 5-point rows the `GCPnts` figure sits at or below the reference's own residual
error, so it bounds the remaining error rather than measuring it. The first row's `2.9e-7` is
`GCPnts`'s genuine per-span quadrature residual on a sharply wiggling curve.)

The error is worst where `|C'(u)|` varies sharply along the curve, which is the ordinary case for
an interpolated toolpath or an imported spline, so a CAM step-over or a sweep spacing derived from
a curve's length was percent-level wrong. The ranged overload had the identical gap, and
`totalArcLength` / `arcLength(from:to:)` / `arcLengthBetween(_:_:)` inherit the fix as soon as they
route through `length` (#408).

**One behavioural change beyond accuracy**, on out-of-domain parameters: `GCPnts` clamps to the
curve's domain where `CPnts` extrapolated the polynomial past its knots. On the 356-unit test
curve, overshooting both ends by a full domain width used to measure 441,972; it now measures the
curve's own length. A range wholly outside the domain used to measure 865,392; it now measures `0`.
Nothing else in the failure contract moves:
probed against the pinned kernel, both integrators agree on reversed ranges, equal parameters,
zero-length curves, periodic curves, and unbounded lines, and neither throws where the other does
not.

The three bridge functions that already used the composite integrator
(`OCCTCurve3DArcLength` / `OCCTCurve3DLength` / `OCCTCurve3DArcLengthBetween`) stay exported for
direct C consumers, but they are no longer reached from Swift: #408 routed `totalArcLength`,
`arcLength(from:to:)` and `arcLengthBetween(_:_:)` through `length`/`length(from:to:)`, so every
Swift spelling now lands on `OCCTCurve3DGetLength`/`OCCTCurve3DGetLengthBetween`. Nothing in
`Sources/OCCTSwift` references the older three.
(Superseded: all three were deleted outright by #506, which also found that `OCCTCurve3DLength`'s
pre-bounded adaptor extrapolated past the knots rather than clamping, so it had not in fact
inherited this entry's fix. See the #506 entry.)

New suite `Issue477ArcLengthAccuracyTests` (`OCCTCurveTests`) pins all five Swift spellings against
an independently computed reference (a Richardson-extrapolated polyline, not the implementation's
own answer), so it fails on the old integrator rather than ratifying it. 5 of its 8 tests fail
against the previous code.

### v1.17.0 (July 2026) — fix: `FillingSurface`'s continuity mapping was wrong for both non-default orders, and it converged onto `Shape.fill`'s implementation (#433, #434)


`FillingSurface.add(edge:continuity:)`/`add(freeEdge:continuity:)` hand-mapped the plate
constraint order onto `GeomAbs_Shape` locally instead of using `occtFillingContinuityToGeomAbs`,
the helper #430 introduced for `Shape.fill`: order 1 requested `GeomAbs_C1` (curvature) instead
of `GeomAbs_G1` (tangency), and order 2 requested `GeomAbs_C2` (ordinal 4), which every
constraint class rejects — failing the whole `build()` rather than just that one constraint
(#433). `add` returned `true` regardless, since `BRepOffsetAPI_MakeFilling::Add` only appends and
never validates the order.

`FillingSurface` also held its own, separate `BRepFill_Filling` — the private implementation
class `BRepOffsetAPI_MakeFilling` (what `Shape.fill` already used) forwards to internally, and
never exposes. #434 converges the two onto one implementation: `FillingSurface` now holds the
same `BRepOffsetAPI_MakeFilling`, built through the same shared `occtFillingMakeBuilder`, and
every `add` call shares `occtFillingAddConstraint` outright rather than each having its own copy
of the same defensive logic — fixing #433 as a consequence of the convergence rather than as a
separate patch. `occtFillingAddConstraint` is no longer a template now that both callers hold the
same concrete filler type.

New: `FillingSurface.add(edge:support:continuity:)`, mirroring `FillConstraint`'s support-face
semantics — a face named here is used or the constraint fails, never silently substituted. Its
`continuity` defaults to `.g1`, not `.g0`, matching `FillConstraint`: at `.g0` there is nothing
to be tangent or curvature-continuous with, so `support` is never even read, and a `.g0` default
would make the "used or fails" guarantee false for the common zero-argument call. Covers the
boundary-edge case; `FillConstraint.isBoundary` also covers free edges with a named support
face, which this PR does not add an equivalent for.

```swift
// Tangent to the wall the rim came from
let filling = FillingSurface()
filling.add(edge: rim, support: wall, continuity: .g1)
```

Verified on the same truncated-sphere fixture #430's own tests use: `.g2` on a curved boundary,
which previously failed the whole `build()`, now succeeds and measurably bulges further than
`.g1` — matching `Shape.fill`'s own curvature-vs-tangency regression test on the other entry
point.

### v1.17.0 (July 2026) — refactor: nine continuity enums collapsed to two shared vocabularies (#398)


OCCTSwift had grown **nine** separate "continuity level" enums, each written against one bridge
call and each re-deriving its own raw-int meaning. Verified against the pinned kernel, they turn
out to express exactly **three** contracts, not one:

| contract | what OCCT receives | enums that expressed it |
|---|---|---|
| geometric constraint order, `0/1/2 = G0/G1/G2` | a plate constraint order; `GeomPlate_CurveConstraint` rejects outside `[-1, 2]` with "The continuity is not G0 G1 or G2" | `SurfaceContinuity`, `PlateConstraintOrder`, `FillingContinuity` |
| required parametric continuity, `0…3 = C0…C3` | a `GeomAbs_Shape` continuity class, or a literal derivative-order integer | `GeometricContinuity`, `ApproxContinuity`, `Shape.BSplineContinuity`, `Curve3D.ContinuityOrder` |
| a `GeomAbs_Shape` ordinal reported back | nothing; it is a *result* | `Surface.Continuity` |

Collapsed to `SurfaceContinuity` (`.g0` / `.g1` / `.g2`) and a new `ParametricContinuity`
(`.c0` … `.c3`). `Surface.Continuity` is retained as a result type, and `Shape.ContinuityLevel`
is retained as a strict superset (it adds `cn`, `g1`, `g2` cases that only
`dividedByContinuity(criterion:tolerance:)` accepts).

**No raw value moved, and no bridge code changed, so no existing call's behaviour changed.** Two
deliberate widenings, both in `Curve3D.continuityBreaks(minContinuity:)`: `.c3` becomes reachable
(below), and results past the 256th are no longer silently dropped. The latter is the only new
executable code in this PR, and the more consequential of the two for imported geometry, which is
where split counts get large. Every retired name and spelling remains as a deprecated alias, so
existing source still compiles:

```swift
@available(*, deprecated, renamed: "SurfaceContinuity")
public typealias FillingContinuity = SurfaceContinuity      // and PlateConstraintOrder
@available(*, deprecated, renamed: "ParametricContinuity")
public typealias GeometricContinuity = ParametricContinuity // and ApproxContinuity,
                                                            // Shape.BSplineContinuity,
                                                            // Curve3D.ContinuityOrder
```

`SurfaceContinuity.c0` / `.c1` / `.c2` also survive as deprecated aliases of `.g0` / `.g1` /
`.g2`. Two source-compatibility caveats, both fixed by adding a `default`:

- An *exhaustive* `switch` over any of these enums now needs one, because the old spellings are
  static properties rather than cases.
- `Curve3D.ContinuityOrder` also *widens* from three cases to four, so even a switch written with
  the correct `.c0` / `.c1` / `.c2` spellings stops being exhaustive.

Two live defects surfaced while verifying the mappings the issue had assumed correct. Both are
pre-existing, both are now pinned by tests, and neither is fixed here:

- **`Shape.plateSurface(through:orders:)` can never accept `.g2`.** A bare point carries no
  curvature to match, so `GeomPlate_PointConstraint` throws above order 1 (the header's "Order is
  not 0 or -1" doc is itself wrong; 1 is accepted). The throw fails the whole call, so a single
  `.g2` in an otherwise valid order list returns `nil`.
- **`Curve3D.ContinuityOrder`'s cap at `.c2` made every order it offered a no-op.**
  `GeomConvert_BSplineCurveKnotSplitting` splits where `degree - multiplicity < ContinuityRange`,
  and a cubic interpolation is already C2 at its interior knots. Measured: ranges 0, 1 and 2 all
  return just the two end knots; range 3 returns five parameters. Sharing `ParametricContinuity`
  makes `.c3` reachable, which fixes this as a side effect.

Also re-enabled `AdvancedPlateSurfaceTests`, disabled since v0.23.0 under the claim "Plate surface
operations cause segfault in OCCT". A C++ replica of that exact bridge path shows no segfault at
orders 0 or 1, and the suite is 8/8 clean over repeated runs. Same pattern as the #341
re-enablement: the claim was never characterised and does not hold up.

Docs: `naming-conventions.md` carried `GeometricContinuity.c0, .c1, .g1` as its worked example,
an enum/case combination that never existed.

### v1.17.0 (July 2026) - refactor + fix: the #377 duplication audit, 24 near-duplicate API pairs collapsed onto one implementation each (#399-#422)


One entry for the whole batch, since the 24 issues are one piece of work with one recurring
finding: **wherever two spellings of "the same" operation existed, they were not actually the
same.** Each pair was run against the pinned kernel before being unified rather than assumed
equivalent, and the divergences that turned up were real: a factory that accepted what its twin
rejected, a tolerance an order of magnitude apart, a parameter one spelling could not reach.
Collapsing a pair onto one implementation therefore changes behaviour on one side of it, listed
in full below.

Sibling entry: #398 (continuity enums), directly above. #433/#434 (`FillingSurface`) is the same
audit and has its own entry.

#### Behaviour changes

Each of these changes what an existing, unmodified call returns. None produces a compiler
diagnostic.

| Call | Was | Now | Issue |
|---|---|---|---|
| `Curve3D.circleFromCenterNormal(radius: 0)`, `ellipseFromCenterNormal(minorRadius: 0)`, `hyperbolaFromCenterNormal` with either radius 0, `parabolaFromCenterNormal(focal: 0)` | a live, degenerate curve (`gce_Make*` rejects only strictly-negative dimensions) | `nil`, matching the direct `circle`/`ellipse`/`parabola`/`hyperbola` factories | #399 |
| `Curve2D.circleFromCenterRadius(center:radius:)` at radius exactly 0 | a live, zero-radius curve | `nil`, matching `circle(center:radius:)` and the contract `Curve2D-Analysis.md` already documented | #411 |
| `Surface.curvatures(u:v:)` | its own `GeomLProp_SLProps` at resolution `1e-6` | the shared construction at `Precision::Confusion()` (`1e-7`), matching `gaussianCurvature(atU:v:)`/`meanCurvature(atU:v:)` | #405 |
| `Surface.normal(u:v:)` | accepted any `\|D1U × D1V\| > 1e-15` (absolute) | the same `GeomLProp_SLProps` degeneracy test `normal(atU:v:)` uses, a *relative* sine tolerance of `Precision::Confusion()`. A near-parallel-derivative point that used to yield a normal now yields `SIMD3(0, 0, 0)` | #401 |
| `Surface.approximated()` with no arguments | `tolerance: 0.01`, `maxDegree: 10` | `tolerance: 1e-3`, `maxDegree: 8`, matching `Curve3D.approximated`/`Curve2D.approximated` | #406 |
| `Curve3D.totalArcLength`, `arcLength(from:to:)`, `arcLengthBetween(_:_:)` on failure | `0.0`, indistinguishable from a genuine zero-length result | `-1.0` | #408 |
| `Curve2D.arcLength(from:to:)` on failure (e.g. reversed `u1 > u2`, which its range-checked adaptor rejects) | `0.0` | `-1.0` | #409 |
| `Point2D.distance(to: Curve2D)` with no projection (point past a bounded curve's ends, or a circle's centre) | `-1`, passed through as if it were a distance, so `distance < tolerance` read it as "touching" | `.infinity`, which such a test rejects correctly | #413 |
| `Curve2D.interpolatePeriodic(points:)` with exactly 2 points | `nil` (bridge floor `count < 3`) | a valid out-and-back periodic loop, matching `interpolate(through:closed:)`'s floor of `count < 2`, which has always allowed it | #412 |
| `Curve2D.interpolate(points:startTangent:endTangent:)` | tolerance pinned at `1e-6` with no parameter path to reach it | honours the new `tolerance:` parameter (default `1e-6`, so the bare call is unchanged) | #410 |
| `BRepGraph.sampleFaceUVGrid` | unpacked `uSamples * vSamples` points regardless of how many the bridge wrote | unpacks the written count, with `gaussianCurvatures`/`meanCurvatures` truncated to match | #419 |

Two lower-level changes with the same character:

- `Curve3D.interpolate(points:startTangent:endTangent:)` (the overload without `tolerance:`) is
  **removed**. Swift always prefers the exact-arity match, so the ordinary 3-argument call could
  never reach the tolerance-aware overload it shadowed. The 3-argument call now resolves to that
  overload with its default (#400).
- `BRepGraph`'s 12 adjacency accessors guard `count <= 0` rather than `count == 0`. The bridge
  `...Count` functions narrow through an unchecked `int32_t` cast, so a negative count now
  degrades to `[]` instead of trapping `Array(repeating:count:)` (#418).

Routing the three `arcLength` entry points through `length`/`length(from:to:)` also moved them onto
that pair's integrator, which was the less accurate of the two the bridge carried. That is fixed in
#477 (entry at the top of this file), so the accuracy the `arcLength` spellings had before #408 is
restored and `length`/`length(from:to:)` gain it as well. Note the consequence for the C bridge:
`OCCTCurve3DArcLength`, `OCCTCurve3DLength` and `OCCTCurve3DArcLengthBetween` are no longer reached
from Swift at all (nothing in `Sources/OCCTSwift` references them), though they remain exported for
direct C consumers.
(Superseded: #506 deleted all three. `OCCTBridge` is a target and not a product, so there were no
direct C consumers to export them for.)

#### Public Swift API

Source-breaking, both MAJOR-triggering under [`SEMVER.md`](SEMVER.md) and tracked on #377 so the
obligation survives the squash-merge:

- `Surface.drawMesh(uCount:vCount:)` and `Surface.evaluateGrid(uParameters:vParameters:)` return a
  new `SurfaceGrid` instead of `[[SIMD3<Double>]]`. They previously nested in *opposite* orders
  (`[u][v]` vs `[v][u]`) with nothing at the type level to catch a caller mixing them up;
  `SurfaceGrid` is indexed by `.at(u:v:)`, so the ambiguity is gone rather than documented (#404).
- `Curve3D.interpolate(points:startTangent:endTangent:)` removed, as above (#400).

Renamed, with a deprecated shim, so existing source still compiles:

- `Curve2D.approximated(first:last:toleranceU:toleranceV:maxDegree:maxSegments:)` is now
  `approximatedInRange(...)`. It wraps `Approx_Curve2d` (explicit sub-range, separate U/V
  tolerances, continuity fixed at C2), a genuinely different algorithm from
  `approximated(tolerance:continuity:maxSegments:maxDegree:)`'s `Geom2dConvert_ApproxCurve`, and
  nothing steered a caller between them (#407).

Additive:

- `Surface.mirrored(acrossPoint:)` and `Surface.mirrored(acrossAxis:direction:)`, closing the gap
  between `Surface`'s copy-returning transform family and `Curve3D`/`Curve2D`'s (#414).
- `BRepGraph.contains(uid: GraphItemUID)`, the counterpart to the existing `GraphUID`/`GraphRefUID`
  overloads (#417).
- `Surface.KnotSplitResult.uSplitParams`/`vSplitParams`, and `LawFunction.knotSplitParameters(continuityOrder:)`.
  Both back onto values their OCCT class already computed and discarded (#403).
- `ArcLengthCurveAdaptor`, a public protocol carrying the composition logic
  (`point`/`tangent(atAbscissa:)`, `points(spacing:)`) that `EdgeCurve` and `WireCurve` previously
  duplicated line for line. Both stay distinct public classes (#422).
- `tolerance:` parameters on `Curve2D.interpolatePeriodic` and
  `Curve2D.interpolate(points:startTangent:endTangent:)`, defaulted to the value each used to
  hardcode (#410, #412).

#### Bridge C API

The C surface is not covered by the Swift SemVer promise, but direct `OCCTBridge.h` consumers
are affected:

- **Signature changed:** `OCCTSurfaceKnotSplitting` takes four more arguments (`outUParams`,
  `maxUParams`, `outVParams`, `maxVParams`) and reports true counts even when writing was
  truncated, so a caller can retry with a bigger buffer (#403).
- **Removed:** `OCCTCurve3DCreateArc3Points` (#415), `OCCTGceMakeCone` and
  `OCCTGceMakeCylinderFrom3Points` (#420), `OCCTGeom2dLPropCurExt` and `OCCTGeom2dLPropCurInf`
  along with the `OCCTCurInfPoint` struct (#402). Each duplicated a sibling that survives.
- **Added:** `OCCTSurfaceMirrorPoint`, `OCCTSurfaceMirrorAxis` (#414), `OCCTBRepGraphHasItemUID`
  (#417), `OCCTLawBSplineKnotSplitParams` (#403).
- **Behaviour:** `OCCTCurve2DProjectPoint2D` returns `NaN` for the parameter on failure and
  documents `outDistance < 0` as the signal. It used to return `0.0`, which is a legitimate
  parameter: projecting a segment's own start point onto it returns exactly `0` at distance `0`
  (#413). `OCCTInterpolate2DPeriodic`, `OCCTInterpolate2DWithTangents` and
  `OCCTInterpolateWithTangents` now forward to their canonical siblings rather than holding a
  second copy, so direct C consumers get the same behaviour as Swift callers (#412, #410, #400).

#### Unified with no behaviour change

`Curve2D.curvatureExtremaDetailed()`/`inflectionPointsDetailed()` now delegate to their plain
siblings instead of re-running the same `GeomLProp_CurAndInf2d` (#402). `Curve3D.arc(through:_:_:)`
became the true alias of `arcOfCircle(start:interior:end:)` it was already documented as (#415).
`Curve3D`'s six immutable transform functions fold onto the same `buildTrsf3D` the mutating family
used, and the mutating dispatcher gained the `IsNull()` guard the immutable six already had (#416).
`BRepGraph`'s 12 count-buffer-fetch-map accessors share one helper (#418). Ten flat-buffer unpack
sites share `unpackSIMD3` (#419). `Surface.coneFrom2PointsRadii`/`cylinderFrom3Points` delegate to
their `GC_Make*`-backed counterparts (#420), as do the four overlapping plane factories (#421). The
`EdgeCurve`/`WireCurve` bridge primitives share one `Adaptor3d_Curve&` helper set; public C symbol
names are unchanged (#422).

Test coverage went up where the audit found none: `Curve3D.arc(through:_:_:)`,
`Surface.rotated(axisOrigin:axisDirection:angle:)`, `BRepGraph.rootProductIndices`,
`EdgeCurve`/`WireCurve`'s `points(spacing:)`/`parameterRange`/`point(atParameter:)`, and
degenerate-input cases across every unified factory pair had no dedicated tests before.

### v1.16.1 (July 2026): fix — unify consumed the shape it was given, so a declined merge still damaged the caller's solid (#446)

`ShapeUpgrade_UnifySameDomain` rewrites sub-shapes of the shape it is handed, and those rewrites
reach the `TShape`s the caller's `Shape` still shares. The result: the idiom every consumer writes —
take the merge if it is valid, otherwise keep what you had — silently damaged what you had. A solid
that was a clean, non-self-intersecting manifold before the call came out of it self-intersecting,
with no result ever accepted. OCCT documents the class as producing a new shape and says nothing
about the input being consumed.

**Root cause, traced in the kernel:** `TransformPCurves` (`ShapeUpgrade_UnifySameDomain.cxx:1228`
and two sibling sites) writes temporary pcurves onto the **input's** edges, against a scratch
reference face the algorithm builds for itself, and only ever removes them again if that reference
face is later replaced. `SetSafeInputMode` does not cover this path — it is unguarded, and safe mode
is OCCT's default anyway, so the reporter was already running it. Minimal reproducer: two stacked
coaxial cylinders (same-domain cylindrical faces, differently parameterised, which is what drives
that path). The input's serialized BREP grows from **1676 to 1778 bytes** across a single
`unified()` call that the caller never even used the result of.

Every unify entry point now works on a private copy (`BRepBuilderAPI_Copy`), so the caller's shape is
untouched whatever the algorithm does to its own input: `Shape.unified()`, `Shape.simplified()`, and
`UnifySameDomainBuilder`. No API change and no new parameter — the copy is unconditional, because
"the input survives" is what every call site already assumed.

**What the copy costs.** A real fraction of the call, not a rounding error: measured here at 0.6 ms
against 2.3 ms for the merge itself on an 84-face compound (28%), and review measurement on a
600-face compound put it at 18% where there is real merging to do but 64% on a nothing-to-merge input
— which matters because `unified()` is the standard post-boolean cleanup and often finds nothing.
Peak memory doubles for the duration. Unconditional anyway: a `copyInput:` flag would put the
silent-corruption path back within reach of anyone optimising a hot loop, and it can be added later
if a caller measures this as a real problem.

**And what it costs in identity.** The result now shares **no** sub-shapes with the input, even where
nothing was merged — before this change an untouched face came back `IsSame` with the one it came
from. `Shape.isSame(as:)`, `isPartner(with:)` and `isEqual(to:)` are public and consumers do map
selections and attributes across by sub-shape identity, so that code has to key off geometry instead.
This is the unavoidable price of the fix rather than a choice, but it is a behaviour change and is
pinned by a test. `UnifySameDomainBuilder.keepShape(_:)` is unaffected: it still takes the input's own
sub-shapes and maps them across for you.

**Deduplication.** Three bridge call sites constructed `ShapeUpgrade_UnifySameDomain` independently
(`OCCTShapeUnifySameDomain` and `OCCTShapeSimplify` in `OCCTBridge_Healing.mm`, the builder in
`OCCTBridge_Modeling.mm`), each with its own copy of the construct/`Build()`/null-check sequence —
which is exactly why one fix had to be written three times. They now share
`occtUnifySameDomain`/`occtUnifySameDomainInput`/`occtUnifySameDomainMapped`
(`OCCTBridge_Internal.h`). The two public Swift entry points are **not** redundant and both stay:
`Shape.unified()` is the one-shot, `UnifySameDomainBuilder` adds tolerances, `keepShape` and
internal-edge control. Their `concatBSplines` defaults disagree (`true` vs `false`) — left as-is
rather than silently changed under existing callers, but now cross-documented on both.

`UnifySameDomainBuilder.keepShape(_:)` names a sub-shape of the **caller's** shape, so working on a
copy means mapping it onto its counterpart there; without that, every `keepShape` would have quietly
kept nothing. `setSafeInputMode(_:)`'s doc comment, which claimed it "copies input shape to preserve
original", was wrong on both counts and is corrected.

**Sibling audit (so nobody files a speculative sweep):** the same input-consumption class was checked
on the same fixture for `ShapeFix_Shape` (`healed()`, `fixed(tolerance:)`), `BRepAlgoAPI_Defeaturing`
(`withoutSmallFaces(minArea:)`) and `ShapeUpgrade_ShapeDivideClosed` (`dividedClosedFaces()`). All
four leave the input byte-identical. `ShapeUpgrade_UnifySameDomain` is the outlier, not the first of
a family.

Bridge-only fix: no OCCT kernel change, no xcframework rebuild, no new operations (count unchanged at
4,258). New regression suite `Issue446UnifyInputMutationTests` (`OCCTShapeHealingTests`) asserts the
input's serialized BREP is byte-identical across all three entry points, that a declined merge leaves
the shape's validity/self-intersection/volume unchanged, that the merged result's geometry is
unmoved, that the result no longer shares sub-shapes with the input, and that `keepShape` still
blocks a merge through the copy (per-edge: the junction seam blocks it, a cap circle does not). Full
`swift test` (combined with #397 below): 4480 tests in 1292 suites, all passing.

Also fixed in passing: `docs/reference/Shape-Features.md` credited `withoutSmallFaces(minArea:)` to
`ShapeAnalysis_CheckSmallFace` + `ShapeUpgrade_UnifySameDomain`; `OCCTShapeRemoveSmallFaces` uses
neither, it collects small faces by area and removes them with `BRepAlgoAPI_Defeaturing`.

### v1.16.1 (July 2026): fix — `Shape.faceAddHole()` rejected every circular hole wire, and never oriented the ones it kept (#397)

`Shape.faceAddHole(face:wire:)` returned `nil` for **every** hole wire built from circular geometry —
`Wire.circle(origin:normal:radius:)` and a hand-joined two-arc circle alike, at any radius, in either
winding — while a polygonal hole on the same face worked. The cause was this wrapper's own
degenerate-wire guard (added for #234, which declines a zero-area hole because the invalid face it
produces goes on to SIGSEGV `ShapeFix` downstream): the guard counted the wire's **vertices**, and a
circle has one (`Wire.circle`) or two (two joined arcs), so it tripped the "fewer than 3 distinct
vertices" rejection meant for out-and-back line segments. Nothing in OCCT was rejecting these wires;
they never reached `BRepBuilderAPI_MakeFace::Add` at all.

The guard now samples points **along the wire's curves** rather than at its vertices, which is what
lets a circular hole describe the area it encloses. Sampling alone would weaken #234's protection —
an arc traversed out and back spreads its samples over a curve and so clears the collinearity test
that catches a straight out-and-back — so the loop's own vector area is checked as well, and a wire
whose mean width (area ÷ longest chord) falls below `Precision::Confusion()` is still declined.

**Fixing the `nil` exposed a second half to the same defect**, pre-existing and equally silent: the
wrapper never oriented the wire it added. `MakeFace::Add` does no reorienting of its own, so a hole
wound the same way as the face's outer boundary was added as a second **outer** loop — a 20×20 face
given a 2×2 hole came back with area 404 rather than 396, and its prism was not a valid solid. Only
callers who happened to hand in an opposite-wound wire ever got a hole. `faceAddHole` now compares the
hole's winding against the face's outer boundary in the face's plane and reverses the wire when they
match, the same rule `OCCTShapeCreateFaceWithHoles` has used since #274, with a validity-checked
retry of the other orientation for non-planar hosts where no plane can be fitted. Either winding now
cuts, and the sampler both tests share is now one helper (`occtSampleWirePoints`) rather than two
copies of the same traversal.

**One behaviour change beyond the two bugs:** when *neither* winding yields a `BRepCheck`-valid face,
`faceAddHole` now returns nil instead of the invalid face. That case is not a winding question — the
wire does not lie inside the face's boundary, and no orientation makes it a hole — and returning a
non-nil invalid face is exactly what #234 established breaks callers later. Pre-existing behaviour
(the old code never validated its result at all), tightened here because the winding retry introduced
the validity check anyway.

Bridge-only fix: no OCCT kernel change, no xcframework rebuild, no new operations (count unchanged at
4,258). New regression suite `Issue397CircularHoleTests` (`OCCTModelingTests`) covers `Wire.circle`
and two-arc holes in both windings, the extruded-solid volume, same-winding polygon holes, the
zero-area curved wire that must still be declined, and the boundary-crossing wire that no winding can
turn into a hole; `Issue234DegenerateHoleTests` passes unchanged. Full `swift test` (combined with
#446 above): 4480 tests in 1292 suites, all passing.

### v1.17.0 (July 2026) - fix: three more first-of-N `TopExp_Explorer` sites dropped most of their input (#443)

#442's audit note asked for the first-of-N `TopExp_Explorer` idiom to be grepped for across the whole
bridge before closing it, on the grounds that #439 had two instances and #442 two more, and every one
was found by someone reading the neighbouring lines rather than from a report. That sweep found **23
candidate sites**: 8 false positives, 5 where "first" is the documented contract, and 10 undocumented
silent picks. Three of those were confirmed **by measurement** to lose most of their input, and are
fixed here. The other seven are documented rather than changed: each is singular by contract, and
widening it would change what its arguments mean.

Measured against a compound of two disjoint 10 mm boxes (2 solids, 12 faces, 2000 mm³):

| call | before | after |
| --- | --- | --- |
| `Shape.solid(from:)` | 1 solid, 1000 mm³ | 2 solids, 2000 mm³ |
| `Shape.upgraded()` | 1 solid, 1000 mm³ | 2 solids, 2000 mm³ |
| `AssemblyNode.setTriangulationFromShape` | 4 nodes, 2 triangles | 48 nodes, 24 triangles |

**`Shape.solid(from:)`** (and `Shape.solidWithFullHistory(from:)`) is the sharpest of the three: its
own doc names sewing output as the expected input, and sewing two bodies yields exactly the two-shell
input it mishandled. After #442 the two sibling entry points disagreed on that same shape:
`sewn.solidFromShellFixed()` gave 2 solids / 2000 mm³ and `Shape.solid(from: sewn)` gave 1 / 1000.
Both now go through #442's `occtBodyBoundingShells`, so they agree by construction; the helper moved
to `OCCTBridge_Internal.h` for that. The history variant shares **one** `ShapeBuild_ReShape` across
the per-body `ShapeFix_Solid` runs, so the single history still covers every body:
`BRepTools_ReShape::History()` builds a fresh `BRepTools_History` from the context's whole replacement
map on each call, so earlier bodies' replacements are still in it (confirmed against `occt-src`).

**`Shape.upgraded()`** is documented as a "sew + make solid + heal pipeline" and is the call most
likely to be pointed at a raw imported mesh, where multi-body input is the norm. Its solid step now
builds one solid per body-bounding shell. Two limits inherent to sewing first are now documented
rather than silent: sewing dissolves the input's solids, so a **hollow body's cavity is filled**
(8000 mm³ for a 7000 mm³ hollow cube, unchanged from before but never stated); and the solid step
replaces the sewn shape rather than merging into it, so content sewing could not attach to a shell is
not carried through. `fixed(tolerance:)` is the call for either case, since it does not sew.

**`AssemblyNode.setTriangulationFromShape`** meshed the whole shape and then stored only the **first
face's** triangulation on the label. A 6-face box and a 12-face two-box compound both stored 4 nodes
and 2 triangles, for a doc comment reading "by meshing a shape". Arguably the worst of the three,
since the attribute is what later readers trust as the label's geometry. It now merges every meshed
face into one `Poly_Triangulation` in the shape's own coordinate system: per-face locations applied to
the nodes, reversed faces' winding and node normals flipped so the result is consistently outward
(the same rules `Shape.mesh()` applies), the worst contributing face's deflection carried over, node
normals kept only if every face has them, and per-face UV nodes dropped since they index parameter
spaces that stop meaning anything once the faces are pooled.

**A latent case in #442's own helper was found and fixed with them.** `occtBodyBoundingShells` ran its
enclosure-parity pass within each solid but added every shell belonging to *no* solid unconditionally,
on the reasoning that a free shell has no declared cavity relationship. But **sewing dissolves the
solid that carried that declaration**, and sewing is the ordinary way all of these calls are reached.
Measured on a sewn hollow box: the same two shells answered 1 body while inside a solid and 2 once
sewn, the second being the cavity as a positive solid; on `{hollow body, body inside its cavity}` it
gave 3 bodies for a 2-body part. Free shells are now one further group through the same parity pass,
so both readings agree. Containment among free shells is geometric rather than declared, so a closed
shell alone inside another is read as that one's cavity: the same reading OCCT's own solid convention
gives it, and the only one available without a declaration. A body nested inside a cavity is enclosed
twice, so it is still a body. None of #442's shipped cases change (two disjoint free shells → 2 solids;
the same free shell twice → 1).

The parity pass is O(N²) classifications in the size of one group, which was fine when a group was one
solid's 1-3 shells but is not when it is every free shell of a sewn mesh. A conservative bounding-box
pre-filter now prunes pairs before any ray cast, and skips building a classifier for a reference that
overlaps nothing: enclosure implies box containment, so no verdict changes. Measured at 200 disjoint
shells: 160 ms without it, 0.7 ms with, identical results. This is not the `Bnd_Box` rule #442
rejected; that failed as the *decision* rule, which is exactly why it is sound as a pre-filter.

> **Behaviour change for consumers:** `Shape.solid(from:)`, `Shape.solidWithFullHistory(from:)` and
> `Shape.upgraded()` now return a **compound** where they previously returned one arbitrary body's
> solid, for multi-body input only. Single-body input is untouched, down to the returned shape type.
> A caller that assumed `.solid` unconditionally should read `.solids` instead.
> `Shape.solidFromShellFixed()` returns **one** body where it returned two for a sewn hollow part,
> the second having been the cavity. `AssemblyNode.setTriangulationFromShape` stores nodes in the
> **shape's** frame rather than the first face's local frame, so a located shape's stored coordinates
> move as well as its node count.

The seven remaining undocumented picks are documented in place, in both the Swift doc comment and the
bridge, with why each stays singular: `MedialAxis.init(of:)` (a medial axis is a property of one face,
and the result type holds one graph), `Shape.halfSpace(face:referencePoint:)` (a half-space is bounded
by one face by definition), `Shape.fillet2D(vertexIndices:radii:)` and `chamfer2D(edgePairs:distances:)`
(the indices are numbered within the chosen face, so covering every face would need per-face index
lists and a different signature), `Shape.splitByWireOnFace(_:faceIndex:)` and
`locOpeSplit(wiresOnFaces:)` (the pair list is already where several wires are named), and
`Shape.solidFromShells(_:)` (the argument order *is* the outer-versus-cavity contract, so widening
each argument would make it stop meaning anything). `OCCTShapeBuildThreadCutter` is internal and
single-body by construction. `Shape.faceRestricted(by:)` and `Wire.offset(by:joinType:)` already
stated what they do and are untouched.

**Review round 3: the one item left open, `Shape.solid(from:)`/`solidWithFullHistory(from:)`'s own
`BRepBuilderAPI_MakeSolid` failure path.** Flagged unresolved in review round 2: before this PR, a
`MakeSolid` failure on the (only) shell was a hard failure for the whole call; per-body, it silently
dropped just that one body from the result compound — the exact defect class this PR exists to fix,
reopened one layer down. Checked against `occt-src` rather than assumed: `BRepLib_MakeSolid`'s
single-shell constructor (`BRepLib_MakeSolid.cxx`) unconditionally calls `Done()` after adding the
shell, with no closure or coherence check anywhere in the path — matching its own header's "a solid
under construction is always valid." Confirmed with a probe: `BRepBuilderAPI_MakeSolid` on a
5-of-6-face open shell, and on a bare empty shell, both come back `IsDone() == true` with a non-null
`Solid()` — just a geometrically invalid one (`BRepCheck_Analyzer.IsValid() == false`), not a failure.
**So the failure this review item worried about cannot occur for this call**, confirmed by re-running
the two new regression tests below against the pre-fix code: both still pass, because the code path
they exercise never reaches the branch in question either way.

Fixed anyway, for defense in depth: the dead `continue` (drop) is now `push_back` (keep the shell
as-is), matching `OCCTShapeSolidFromShell`'s identical "keeps a body rather than dropping it if that
changes" comment — same belt-and-braces contract as its #442 sibling, zero observable behaviour
change today. Two new tests (`solid(from:) keeps an open body rather than dropping it`,
`solidWithFullHistory(from:) keeps an open body rather than dropping it`) pin the guarantee that
actually matters regardless of mechanism: a closed shell alongside a disjoint 5-of-6-face open shell
still comes back as 2 bodies / 11 faces, not 1.

**Review round 4: `OCCTShapeUpgrade` had the same dead-but-inconsistent `MakeSolid` drop round 3
fixed on its siblings, and two doc passages didn't hold up.** Round 3 fixed the silent per-body drop
on `Shape.solid(from:)`/`solidWithFullHistory(from:)`, but `OCCTShapeUpgrade`'s own per-shell loop —
touched by this same PR — still had the plain `continue`-style drop, missed because it wasn't one of
the two functions round 3's own finding was about. Fixed the same way: `push_back` the unfixed shell
on `IsDone() == false` instead of dropping it, same belt-and-braces reasoning, same "dead code today"
status (verified: `BRepBuilderAPI_MakeSolid`'s single-shell constructor never fails). A new test,
`upgraded() keeps an unclosable shell's faces rather than dropping them`, pins it — on face count
rather than solid count, since `upgraded()`'s later `ShapeFix_Shape` pass reclassifies the kept body
so it no longer counts as a `TopAbs_SOLID`, unlike the round-3 siblings that don't run that pass.

Also: three existing `docs/reference/` pages covering methods documented (not changed) by this PR —
`Shape-Measurement.md` (`fillet2D`/`chamfer2D`/`solidFromShells`), `Shape-Builders-1.md`
(`splitByWireOnFace`), `Shape-Builders-2.md` (`locOpeSplit(wiresOnFaces:)`) — had the caveat added to
the Swift doc comment but not mirrored into the page; now they match. And `upgraded()`'s own doc
comment claimed "free shells each become a body," which is what this very PR's free-shell parity fix
made untrue — the next line already stated the correct, narrower rule (an even-enclosed free shell is
skipped), so the topic sentence was reworded to match rather than contradict it, reusing
`solid(from:)`'s more precise phrasing.

Bridge-only fix: no OCCT kernel change and no `OCCT.xcframework` rebuild.

### v1.16.0 (July 2026): fix — `Shape.fixSolid()`/`solidFromShellFixed()` healed only the first body (#442)

`Shape.fixSolid()` and `Shape.solidFromShellFixed()` healed the **first** solid (respectively the
first shell) a `TopExp_Explorer` yielded and discarded every other body without a signal. The return
was a well-formed `Shape` that looked like a healed version of the input, so nothing downstream could
tell that most of the part was gone: a 2000 mm³ two-box compound came back as a 1000 mm³ single solid.

Both now cover every body. `ShapeFix_Solid` cannot be handed a compound — its constructor and `Init`
take a `TopoDS_Solid`, and `TopoDS::Solid` throws on anything else — so multi-body input has to be
driven one solid at a time. **A compound result is not a new return category:** `ShapeFix_Solid::Shape()`
already hands one back when a single solid's shells resolve into several bodies, so callers that
handled `fixSolid()` correctly for a multiconnex solid already handle this.

`solidFromShellFixed()` builds one solid per **body-bounding** shell, decided by **enclosure parity**:
within each solid, a shell bounds a body iff an *even* number of the other shells enclose it, plus
every shell belonging to no solid at all (the usual shape of sewing output). A solid's *cavity* shells
are skipped: a hole is not a body, and building one as a positive solid would return a compound whose
volume double-counts the part (8000 + 1000 for a 7000 mm³ hollow box). Enclosure is decided with
`BRepClass3d_SolidClassifier`, not by shell orientation — measured, both a hollow solid's outer and
cavity shells are `FORWARD`, so orientation carries no signal here; each reference is read once with
`PerformInfinitePoint` so an inside-out shell flips the sense rather than the answer.

An **open** shell is skipped in the reference role (`BRep_Tool::IsClosed`, which for a shell is a real
edge-pairing check rather than the `Closed()` flag, so a genuine cavity shell still qualifies). Open
shells reach this code by contract — the same call accepts them and returns them as unclosed solids —
and under parity every shell is a reference, so one that cannot enclose anything would still add a
spurious ±1 to the others. Measured on `{A_outer, A_cavity, openShell wrapping both}`: without the
guard the outer shell is **dropped outright** (enclosed count 1, odd) and the cavity emitted as a
positive body.

Parity is used because **every rule that picks one reference shell and calls everything outside it a
body is wrong on some real input**, and the two obvious choices fail on different ones. Measured, on
one solid holding `{A_outer 8000, A_cavity 1000, B_outer 27000}`: picking the widest shell emits
`A_cavity` as a positive body (36000 mm³ against a correct 35000), because it is outside *B*; picking
`BRepClass3d::OuterShell` gets that case right but names the *cavity* on an inside-out hollow solid,
emitting the true outer shell as a second overlapping body (9000 mm³ for a 7000 mm³ part). Parity
assumes no single enclosing shell and needs no orientation, and it also reads a body nested inside
another body's cavity correctly — enclosed twice, so even, so a body (8064 mm³, measured). It is
O(N²) classifications in the shells of one solid, where N is 1-3 on any real input and 1 is free.

Neither call can drop a body by any path: a solid `ShapeFix_Solid` fails to heal comes back unhealed
rather than vanishing, `Shape()`'s compound is flattened by direct children so a shell it could not
close is kept rather than skipped by a `TopAbs_SOLID` explorer, and a compound holding the same free
shell twice yields one solid, not two.

> **Reading the result of `fixSolid()`:** because no body is dropped, a result body is not always a
> solid. `ShapeFix_Solid` hands back a shell it could not close, and a solid it fails to heal comes
> back unhealed. `result.solids.count` can therefore be lower than the number of input bodies with
> nothing lost. Spot an unclosed body by walking the result's **direct children**
> (`child(at:)` over `nbChildren`) — **not** `subShapes(ofType: .shell)`, which maps at every depth
> and so reports one shell per *healthy* solid as well, making it useless as a failure signal. A body
> that came back unhealed is still a solid; use `isValid` for that.

> **Behaviour change for consumers:** these two calls now return a **compound** where they previously
> returned one arbitrary body's solid, for multi-body input only. Single-body input is untouched, down
> to the returned shape type. A caller that assumed `.solid` unconditionally should read `.solids`
> instead; a caller that wants one specific body should pick it before healing.

Unlike #439, no doc comment was being violated here — the Swift docs were one-liners that said nothing
about multi-body input either way — so this is a design decision rather than a contract fix. Returning
`nil` for multi-body input (what #439 did for `outerShell`) was rejected: `outerShell` answers a
question about *one* body and has no meaningful answer for several, whereas refusing to heal a
two-body part is a capability loss with no upside. `ShapeFix_Shape` was checked as the "call the other
class" alternative the issue suggested — it does handle a multi-solid compound correctly (2 solids,
2000 mm³) and is already wrapped as `Shape.fixed(tolerance:…)`, now cross-referenced from `fixSolid()`
for callers with mixed content to preserve.

`OCCTShapeFixSolid` also gains the `if (!shape) return nullptr;` guard its siblings in the file use.
Not reachable through the Swift API, but a null deref is an uncatchable SIGSEGV rather than something
the enclosing `try` would catch.

**Documentation correction:** `solidFromShellFixed()` was previously described, before and after this
change, as returning `nil` when a shell does not close. Reading `ShapeFix_Solid.cxx`, `SolidFromShell`
does `B.MakeSolid(solid); B.Add(solid, sh);` unconditionally before any classification and returns
that even on its exception path — it never returns a null solid and never rejects an open shell. The
only `nil` is "no shells at all"; an open shell comes back as a solid that is not closed.

Bridge-only (no OCCT kernel change, no `OCCT.xcframework` rebuild). Operation count is unchanged at
4,258 — behaviour and documentation only. Source comments, `OCCTBridge.h` and the generated reference
(`docs/reference/Document-OCAF-Attributes.md`) all state the same rule.

### v1.16.0 (July 2026): fix — `Shape.outerShell` answered for the wrong body on a multi-solid compound (#439)

`Shape.outerShell` returned the **first solid's shell** on a compound holding more than one solid,
where its own doc comment specified `nil`. The result was a plausible-looking `Shape` that silently
answered for one arbitrary body, so callers guarding on `nil` never fired and every measurement
taken against it was wrong with no signal. On the reporter's 2-solid part a per-vertex sweep went
from mean 0.0131 mm / max 0.2511 mm to mean 2.3129 mm / max 18.2483 mm — output that reads as a
poorly fitted part, not as an error.

`OCCTShapeOuterShell` took the first solid a `TopExp_Explorer` yielded without ever checking whether
a second followed. `OCCTShapeInnerShells` (#212) had the identical defect and is fixed with it: a
2-solid compound reported the first solid's cavities as though they were the compound's.

Both now resolve through one `occtSoleSolid` helper that accepts a solid, or a compound/compsolid
wrapping exactly **one** solid, and returns nothing for a container of two or more. This is the
contract the doc comment already stated; it is a behaviour change only for inputs that were being
answered incorrectly.

> **Behaviour change for consumers:** a caller that passed a multi-solid compound or compsolid to
> `outerShell` and got a shell back now gets `nil`; the same input to `innerShells` now gives `[]`.
> That shell was one arbitrary body's, so any measurement against it was already wrong. Migrate to
> `outerShells` (per body), `solids.flatMap(\.innerShells)` (per body), or
> `Shape.compound(shape.subShapes(ofType: .face))` (whole boundary, cavities included).

**Added** `Shape.outerShells: [Shape]` (`OCCTShapeOuterShells`) — the outer shell of every solid, in
exploration order, so the fix is not purely subtractive. Equivalent to `solids.compactMap(\.outerShell)`
in a single traversal. Note these shells drop internal void walls by design; to measure against the
complete boundary of a multi-body part, cavities included, use
`Shape.compound(shape.subShapes(ofType: .face))`.

Bridge-only (no OCCT kernel change, no `OCCT.xcframework` rebuild). Source comment, generated
reference (`docs/reference/Shape-Measurement.md`) and `OCCTBridge.h` now state the same rule —
the generated page had been paraphrasing the contract with the parenthetical dropped.

### v1.16.0 (July 2026): fix — `Shape.fill` SIGSEGV'd on its own default parameters (#430)

`FillingParameters` defaults `continuity` to `.g1`, so the ordinary
`Shape.fill(boundaries: [wire])` call requested tangent continuity. For any boundary edge
borrowed from an existing face — the normal way to get one — that took the whole host process
down with an uncatchable SIGSEGV rather than returning `nil`.

The bridge always used `BRepFill_Filling`'s face-less `Add(edge, order)` overload. That overload
fetches the edge's pcurve *and its `[first, last]` range*, then builds its constraint from the
**untrimmed** pcurve, discarding the range it just read. For the usual `Geom2d_Line` pcurve that
means a ±2e100 parameter span instead of, say, `[0, 2π]`. The resulting constraint cannot be
projected, and `GeomPlate_BuildPlateSurface::Perform`'s projection-failure recovery branch then
dereferences its own `myGeomPlateSurface` — which `Perform` unconditionally nullifies on entry and
never assigns on that path. Both defects are upstream and present in OCCT master; neither is
reachable through the face-carrying `Add(edge, face, order)` overload, which trims correctly.

Fixed bridge-side by keeping the face-less overload out of the call path whenever continuity is
above positional: a support face is used if one is available, derived from the edge's own pcurve
surface if not, and only a boundary edge with no pcurve at all falls through to the old overload —
where OCCT's documented `Standard_Failure` makes it a clean `nil`. Verified equivalent to a
kernel-patched build: identical G0/G1 errors and identical geometry.

Two new overloads make the continuity reference explicit rather than implied:

- `Shape.fill(boundaries:supportedBy:parameters:)` — each boundary edge takes its tangency
  reference from that edge's own ancestor face in a given shape. The "cap this opening so it flows
  into the walls around it" case.
- `Shape.fill(constraints:parameters:)` with the new `FillConstraint` — per-edge support face,
  continuity order, and whether the edge bounds the face or is an internal constraint.

A face named through `FillConstraint.support` is now used or the fill fails. It previously fell
back to a face derived from the edge when the named one carried no pcurve, which answered with a
continuity reference the caller never asked for and gave no signal that their choice had been
discarded. Auto-picked faces (`supportedBy`) still degrade per edge, since nothing was chosen
there to begin with. Note a planar face is legitimately usable even with no pcurve stored, because
`BRep_Tool::CurveOnSurface` projects onto a plane on the fly.

Also corrected (#431), at both sites that had it:

- `OCCTShapeFill`'s `BRepOffsetAPI_MakeFilling` constructor call bound
  `maxDegree`/`maxSegments`/`continuity` to `Degree`/`NbPtsOnCur`/`TolAng`, leaving `MaxDeg` and
  `MaxSegments` at their defaults and making the angular tolerance the continuity ordinal. Measured
  effect on a cylinder-rim fill: G0Error 0.615 before, 0.00040 after.
- `OCCTFillingCreate` (backing `FillingSurface`) passed `maxDegree`/`maxSegments` as
  `SetResolParam`'s 3rd and 4th arguments, which are `NbIter` and `Anisotropie` — so `maxDegree`
  silently became the solver's iteration count (8 instead of 2, roughly 3x the work at the
  documented defaults) and `maxSegments` became a bool. `SetApproxParam`, the only place `MaxDeg`
  and `MaxSegments` can actually be set, was never called at all, leaving both documented
  parameters inert. `FillingSurface(maxDegree:maxSegments:)` now controls what its names say.

Continuity mapping is now explicit and documented: `BRepFill_Filling` forwards the `GeomAbs_Shape`
value to `GeomPlate_CurveConstraint` as an integer plate order and rejects anything outside
`[-1, 2]`, so `.g2` is `GeomAbs_C1` (ordinal 2). `GeomAbs_G2` (ordinal 3) always throws, despite
OCCT's header docs naming it as the curvature value.

`FillingSurface` reached the same OCCT defect through its own bridge implementation and crashed
identically (#432). The constraint helpers moved to `OCCTBridge_Internal.h` and both entry points
now share them, so that crash is fixed too.

**Note on the planar/curved split** — worth knowing before probing this family. The same face-less
call is a *catchable* `Standard_Failure` on a **planar** support surface, which rejects the ±2e100
parameters, and an uncatchable SIGSEGV on an **unbounded or periodic** one (cylinder, sphere,
cone), which accepts them. The pre-existing filling tests only ever used rectangles and polygons at
`.c0`, so neither half of the defect ever showed.

**Was open, now fixed above:** `FillingSurface`'s continuity mapping was wrong in its own way —
`.c1` requested curvature rather than tangency, and `.c2` landed on an order OCCT rejects, which
failed the entire `build()` (`add` returned `true` regardless; it only appends). Fixed as #433,
folded into #434's convergence of the two wrappers onto one implementation — see the entry above.
The kernel patch for the two upstream defects, and the upstream filing, remain deferred.

### v1.15.20 (July 2026): fix — `Edge.circleProperties` returned `nil` for every full-circle edge (#378)

`Edge.circleProperties` (`MeasurementHelpers.swift`) fits a circle through three points sampled
at `[parameterBounds.first, mid, parameterBounds.last]`. For a full circle the underlying curve
is periodic and `parameterBounds` is `(0, 2π)`, so `point(at: parameterBounds.last)` evaluates to
the same point as `point(at: parameterBounds.first)` (identical to ~1e-16) — the three-point fit
then received two coincident points and returned `nil` for every full-circle edge: a drilled
hole, a bore, a plain cylinder's cap boundary. Partial arcs (`first != last`) were unaffected.

**Fixed:** when `parameterBounds` spans a full `2π` (periodic curve), sample the third point at
2/3 of the range instead of at `bounds.last`, and the second point at 1/3 instead of the
midpoint — all three samples land at distinct, non-wrapping parameters. Partial-arc sampling
(midpoint + `bounds.last`) is unchanged. No public API surface change — same signature, same
`nil`-for-non-circular-edges contract — so this is a patch per `docs/SEMVER.md`.

**Tests:** `edgeCirclePropertiesFullCircle` (`v0.143 Circle property extraction` suite,
`OCCTCurveTests`) — a cylinder's two full-circle cap edges now yield non-nil `circleProperties`
with the correct radius and `isFullCircle == true`; confirmed it fails against the pre-fix code.

### v1.15.19 (July 2026): docs + tests — `Shape.mesh()`/`Shape.loadSTL()` winding guarantees, retract the #375 "loses winding" concern (#375)

**Not a bug — investigated and retracted, both parts.** #375 asked whether `Shape.mesh()`
(always outward for a valid solid, even after a mirror) and `Shape.loadSTL()` (reportedly
"locally inconsistent" after round-tripping a globally-reversed STL) were losing orientation
information. Both were root-caused with a ground-truth C++ test against the pinned xcframework,
independent of any Swift-side code.

1. **`Shape.mesh()` outward-normalization is genuine, intentional OCCT behavior.** A
   `BRepPrimAPI_MakeBox` box already has a mixed FORWARD/REVERSED face-orientation split (3/3)
   baked into its topology; mirroring it (`gp_Trsf::SetMirror`, a negative-determinant
   transform) through `BRepBuilderAPI_Transform` produces the **identical** 3/3 split, and both
   the original and mirrored mesh read 12/12 triangles outward. OCCT compensates a mirror
   transform by flipping face orientation flags, preserving the invariant that a valid solid's
   faces always classify consistently outward — the bridge's existing
   `face.Orientation() == TopAbs_REVERSED` check (already correct) has nothing left to get
   "wrong". There is no way, via a valid `Shape`, to get caller-controlled/"wrong-way" winding —
   that's what `Mesh(vertices:normals:indices:)` is for.

2. **`Shape.loadSTL()` preserves facet winding exactly, including a full global reversal.** A
   from-scratch, independently-verified box STL — both normally wound and uniformly, globally
   reversed — round-trips through `StlAPI_Reader` (`BRepBuilderAPI_MakeShapeOnMesh`) +
   `BRepMesh_IncrementalMesh` + the bridge's extraction as **fully consistent** in both cases (12/12
   outward, then 12/12 inward; zero shared-edge orientation conflicts either way). **The "locally
   inconsistent" result that prompted the issue traced to a bug in the reporting test's own STL
   fixture generator** (a `quad()` helper that copy-pasted the bottom face's relative vertex
   layout onto the top face without mirroring it, so the top face's own "non-reversed" baseline
   was already backwards) — confirmed by reproducing that exact fixture's geometry and finding
   the same defect independent of any `reversed` flag. Not an OCCTSwift bug; not filed upstream.

**Docs:** `Shape.mesh(linearDeflection:angularDeflection:)`, `mesh(parameters:)`, and
`loadSTL(from:)`/`loadSTL(fromPath:)` (`Sources/OCCTSwift/Shape.swift`) each gain a `- Note:`
explaining the orientation guarantee, pointing at `Mesh(vertices:normals:indices:)` for
caller-controlled winding.

**Tests:** `Issue375MeshWindingTests` (`OCCTMeshTests`) — a mirrored box still meshes 100%
outward, both `mesh()` overloads. `Issue375STLWindingTests` (`OCCTIOTests`) — a normally-wound
box STL round-trips 100% outward; a globally-reversed box STL round-trips as a clean 100% inward
(not a fraction strictly between 0 and 1, which would mean local inconsistency).

Docs + tests only, no code behavior change, no binary change — reuses the v1.15.18 xcframework
(the binaryTarget URL is unchanged).

### v1.15.18 (July 2026) — fix (kernel): Resource_Manager::Debug / Storage_Schema::ICurrentData() races (#374)

The two upstream OCCT foundation-layer races [#371](https://github.com/SecondMouseAU/OCCTSwift/issues/371)'s
confirmation harness turned up, filed as [OCCT#1398](https://github.com/Open-Cascade-SAS/OCCT/issues/1398).
Moving every document to a private `TDocStd_Application` (#371) made application/schema
*construction* itself concurrent for the first time — something the old shared singleton never
allowed — and that surfaced two previously-uncaught races.

1. `Resource_Manager::Resource_Manager(const char*, bool)` writes a file-scope `static bool Debug`
   on every construction with zero synchronization; every fresh app's first `DefineFormat()` call
   lazily constructs its own `Resource_Manager`, racing another thread's concurrent first
   construction.
2. `Storage_Schema::ICurrentData()` is a function-local static `Handle` mutated with no lock:
   `Write()` sets it for one store's duration, and *any* `Storage_Schema` construction — including
   the throwaway one `PCDM_ReadWriter_1` builds on **every** `Open()` — nulls it out from under a
   concurrent in-flight save or load.

**Fix:** `Resource_Manager::Debug` → `std::atomic<bool>`. `Storage_Schema` gets a new
`ICurrentDataMutex()` (recursive, since `Write()` re-enters `BindType()`/`AddPersistent()`/
`PersistentToAdd()` on the same thread via driver callbacks) guarding every touch point:
constructor, `Write()`'s whole body, `BindType()`, `TypeBinding()`, `AddPersistent()`,
`PersistentToAdd()`, `HasTypeBinding()`, `ISetCurrentData()`. No public API changes; bridge
untouched — only the pinned `OCCT.xcframework` kernel binary changed (`Scripts/patches/0016`).

Confirmed via a dedicated TSan reproducer (the "unguarded" variant of #371's own confirmation
harness): 13 races + SIGABRT before the fix, 0/4 clean runs after (8×30, 8×50, 10×60, 8×40). Full
`Scripts/tsan-stress.sh run` gate (10 scenarios) clean, 0 regressions on any prior scenario. Full
`swift test` clean. Filed upstream as [OCCT#1398](https://github.com/Open-Cascade-SAS/OCCT/issues/1398)
(repro, filed during #371); this fix is proposed as the corresponding kernel PR. See
`Scripts/repro/374-resource-manager-storage-schema-race/` for the full writeup.

### v1.15.17 (July 2026) — fix (bridge): stop using the XCAFApp_Application::GetApplication() singleton (#371)

Prompted by upstream maintainer feedback on [OCCT#1396](https://github.com/Open-Cascade-SAS/OCCT/issues/1396)
(our #353 repro issue): `XCAFApp_Application::GetApplication()` "exists solely for compatibility
reasons"; OCCT's own guidance since 7.1 is a private `TDocStd_Application` per caller, not a
shared singleton. Our whole #341/#344/#349/#353 race cluster traced back to every document
sharing that one singleton.

**Fix:** `OCCTDocument`'s constructor (`OCCTBridge_Internal.h`) and every other bridge call site
that grabbed the singleton (9 total, across `OCCTBridge_Document.mm`/`OCCTBridge_IO.mm`) now
build a private `new TDocStd_Application()` instead — confirmed behaviorally equivalent via a
ground-truth C++ test before touching bridge code. `CDF_Application::myDirectory`/`myReaders`/
`myWriters` and `CDM_Application::myMetaDataLookUpTable` (the state #344/#349/#353 fixed) are all
per-instance fields, so a private app per document makes that state exclusive to one document by
construction. Two latent bugs fixed along the way: `OCCTDocumentLoadOCAF`/`OCCTDocumentLoadGLTF`
each opened a document through a *different* app instance than the one stored on the returned
`OCCTDocument` — harmless only because both were the same shared singleton before this change.

**Not a clean win — a dedicated confirmation harness found two new upstream races.** Testing the
new pattern in isolation (private app per thread, zero shared state, zero serialization, run
against the real TSan-instrumented kernel) surfaced `Resource_Manager::Resource_Manager()`
(unsynchronized global `Debug`) and `Storage_Schema::ICurrentData()` (unsynchronized global
`Handle`) — both previously uncaught because every prior TSan investigation shared one
application instance, which accidentally serialized them down to "runs once, ever." Filed
upstream as [OCCT#1398](https://github.com/Open-Cascade-SAS/OCCT/issues/1398), not yet fixed in
the kernel. `ocafStoreMutex()` (the #349 bridge mitigation) is **not** redundant after this
refactor — its coverage was expanded (not removed) to also wrap `OCCTDocumentDefineFormatBin/
BinL/Xml/XmlL/BinXCAF/XmlXCAF` and `OCCTDocumentCreateWithFormat`, previously outside the lock.

**Upstream kernel PRs for #344/#349/#353 were NOT withdrawn** — they fix real bugs in the
singleton pattern OCCT's own header still calls "the only valid method"; every other OCCT
consumer following that guidance remains exposed. This change only reduces our own bridge's
exposure to those specific mechanisms.

Full `swift test` (4428 tests) clean. `Scripts/tsan-stress.sh swift` (bridge-level, 445 tests)
clean. `Scripts/tsan-stress.sh run` (kernel-level gate, 9 scenarios including the new
`371-getapplication-singleton-elimination`) clean. See `docs/thread-safety.md` and
`Scripts/repro/371-getapplication-singleton-elimination/` for the full writeup.

**Binary release** — `OCCTBridge.xcframework` (the opt-in prebuilt bridge from #339) changed, so
`Package.swift`'s URL/checksum are bumped to this release. `OCCT.xcframework` is unchanged (still
v1.15.15) — this is a bridge-only change, no kernel patch.

### v1.15.16 (July 2026) — fix (bridge): Shape.fuseAll(_:) internal parallelism caused data corruption under concurrent calls (#367)

Found continuing #342's classification pass. `OCCTShapeFuseMulti` (backs `Shape.fuseAll(_:)`) was
the only bridge call site that set `builder.SetRunParallel(true)` — internal OCCT parallelism for
a single call. Under concurrent load this was actively unsafe, not just an oversubscription
concern as #342 originally framed it: two threads' top-level `Build()` calls, each requesting
internal parallelism, submit work to the same process-wide `OSD_ThreadPool::DefaultPool()`, and
worker threads from one caller's dispatch can end up processing another caller's data.

**Evidence** (`Scripts/repro/342-boolean-ops/occt_342_boolean_stress.cpp`,
`fuse_multi_parallel` scenario): 8 threads × 50 iterations, **400/400 concurrent operations
produced wrong results** — 27 faces instead of the correct 13 (volume matched almost exactly,
consistent with duplicated/torn geometry rather than floating-point imprecision) — plus 237
ThreadSanitizer race reports across foundational topology code (`TopoDS_Builder::Add`,
`TopExp_Explorer`, `BRep_Tool::Range`, `BOPTools_AlgoTools::MakeSplitEdge`). By contrast, the
plain (non-parallel) boolean ops — `Shape.union(with:)`/`.subtracting(_:)`/`.intersecting(_:)`,
none of which ever set `SetRunParallel` — are clean: 2000 concurrent mixed operations, 0 errors,
0 wrong results, 0 races.

**Fix:** dropped `SetRunParallel(true)` entirely — `Shape.fuseAll(_:)` now runs on OCCT's safe
serial default. Removes the trigger rather than locking around a known-corrupting path. New
regression suite `Issue367FuseMultiThreadSafetyTests`. Full `swift test` (4428 tests) clean.

**Not fixed here:** the underlying mechanism looks like a genuine `OSD_ThreadPool`/
`BOPTools_Parallel` concurrency bug in OCCT's own shared-pool dispatch — more foundational than
anything else found in this project's TSan series (#298/#341/#344/#349/#353/#361 were all
specific static/global variables in narrower classes). Root-causing it properly is tracked as a
follow-up investigation in #367, out of scope for this release.

**Binary release** — `OCCTBridge.xcframework` (the opt-in prebuilt bridge from #339) changed, so
`Package.swift`'s URL/checksum are bumped to this release. `OCCT.xcframework` is unchanged (still
v1.15.15) — this is a bridge-only fix, no kernel patch.

### v1.15.15 (July 2026) — fix (kernel): #341's AutoNamingScope revised to a per-instance override after upstream review (#363)

Follow-up to #341 (v1.15.5) and its Swift-side analogue #363/#365 (v1.15.14, `TNaming_Scope` moved
to a per-`Document` field). Upstream reviewer [gkv311](https://github.com/Open-Cascade-SAS/OCCT/pull/1388)
caught something our own v1.15.5 writeup got wrong: `XCAFDoc_ShapeTool::AutoNamingScope`'s
`recursive_mutex` serialized the three known override call sites (`RWMesh_CafReader::fillDocument()`,
`RWGltf_CafReader::fillDocument()`, `XCAFDoc_Editor::Expand()`) against each other, but every *other*
read of `theAutoNaming` in `XCAFDoc_ShapeTool.cxx` (`AddShape`, `MakeReference`, `SetSHUO`) stayed
outside any scope — an unrelated, unscoped caller on another thread could still observe another
thread's temporary override. Making the flag `std::atomic<bool>` closed the memory-safety gap, not
the logical one; our own "the flag is deliberately global" framing at the time was the mistake.

**Fix:** `theAutoNaming` was never meant to express per-document intent — the three overriding call
sites each want to suppress naming for their own document's build, and `XCAFDoc_ShapeTool` is
already one instance per document, so the override belongs there. `XCAFDoc_ShapeTool::OwnAutoNamingScope`
replaces `AutoNamingScope`: a per-instance `myOwnAutonaming` field (-1 inherits the process-wide
default, 0/1 is a local override), with `OwnAutoNaming()`/`SetOwnAutoNaming()`/`UnsetOwnAutoNaming()`
accessors. No locking needed at all — independent documents never touch each other's state.
`XCAFDoc_Editor::Expand()`'s self-recursion (the reason the old fix needed a *recursive* mutex) still
composes correctly: `OwnAutoNamingScope` saves and restores whatever override state the instance had
on entry, not an unconditional reset, so nesting on the same instance works the same way the old
recursive lock did — just without a lock. `theAutoNaming` itself stays `std::atomic<bool>`;
`SetAutoNaming()`/`AutoNaming()` remain callable concurrently from any thread at any time.

**Verified:** same TSan stress as the original fix (10 threads × 200 iterations,
`obj_roundtrip_unique`) — zero races, matching the prior result. New `isolation` scenario
(`Scripts/repro/363-own-autonaming/occt_363_isolation.cpp`) directly checks the property the mutex
fix couldn't guarantee: half the threads locally override via `OwnAutoNamingScope` on their own
document while the other half do plain unscoped `AddShape()` on independent documents relying on the
process-wide default, concurrently — 3000 operations, zero leaks. Patch `0011` updated in place
(same fix, corrected design, not a new patch number). Full production `OCCT.xcframework` rebuild
(macOS, iOS device, iOS simulator); full `swift test` clean.

Upstream: [OCCT#1388](https://github.com/Open-Cascade-SAS/OCCT/pull/1388) updated to the new design
and re-reviewed — CI green across all 3 platforms, every build/GTest/regression/test job.

### v1.15.14 (July 2026) — fix (bridge): naming scope moved to a per-Document field instead of a shared instance + mutex (#363)

Follow-up to #361, prompted by upstream reviewer feedback on #341's analogous fix
([OCCT#1388](https://github.com/Open-Cascade-SAS/OCCT/pull/1388) review comment: "a mutex is not
the right tool here... usage remains unprotected"). v1.15.13's `docNamingScopeMutex()` made
concurrent access to the shared `TNaming_Scope` instance memory-safe, but left the underlying
design bug in place: every `Document` still shared the *same* `TNaming_Scope`, so one document's
valid-label set could leak into another's regardless of locking — a correctness bug, not just a
race, that predates #361's fix.

**Fix:** `TNaming_Scope` moved from a shared process-wide static to a field on `OCCTDocument`
itself (`doc->namingScope`, `OCCTBridge_Internal.h`). No lock needed at all — two threads working
on two different `Document` instances no longer touch anything shared. `docNamingScopeMutex()` was
removed entirely; the six `OCCTDocumentNamingScope*` bridge functions now read/write
`doc->namingScope` directly (two of the six, `OCCTDocumentNamingScopeClear`/`ValidCount`, gained a
null-check on `doc` they'd never had — a symptom of the same bug, since the old implementation
ignored the `doc` parameter entirely and touched the shared global instead).

New test `namingScopesAreIsolatedAcrossDocuments` in `Issue361SharedSingletonThreadSafetyTests`
directly verifies the correctness property (two documents' valid-label sets and counts stay
independent) — a deterministic, single-threaded assertion, not a race-dependent exerciser. Full
`swift test` (4427 tests) clean, both source and `OCCTSWIFT_BRIDGE_PREBUILT=1` build paths.

`Font_FontMgr`'s font-list cache (`fontListMutex()`, also from #361) is unaffected — that mutex
stays, since the system font registry is genuinely one process-wide resource by OCCT's own design,
unlike `TNaming_Scope`. See `docs/thread-safety.md`'s updated section for the general lesson this
draws: a mutex is the right tool only when state is *meant* to be shared; when it was wrongly made
global in the first place, the fix is relocating ownership, not locking access to the wrong owner.

**Binary release** — `OCCTBridge.xcframework` (the opt-in prebuilt bridge from #339) changed again,
so `Package.swift`'s URL/checksum are bumped to this release. `OCCT.xcframework` is unchanged
(still v1.15.11).

Filed as a companion to [#363](https://github.com/SecondMouseAU/OCCTSwift/issues/363), which also
tracks applying the same per-instance-override redesign to #341's upstream `AutoNamingScope` PR —
that part is deliberately deferred: prototype + test locally first, then respond to the OCCT#1388
review and update that PR, not the other way around.

### v1.15.13 (July 2026) — fix (bridge): two more unsynchronized process-global singletons — TNaming_Scope shared instance, Font_FontMgr font-list cache (#361)

Found continuing the #342 (bridge-level thread-handling contract) scoping pass that produced #359 —
an earlier survey flagged two `needs-investigation` spots as high-confidence pattern matches for the
#341/#344/#353 shape; verified both directly this release before fixing.

- **`getDocNamingScope()`** (`OCCTBridge_Document.mm`) returns one process-wide `TNaming_Scope`
  instance shared across every `OCCTDocument`. Construction is safe (C++11 magic statics), but
  `TNaming_Scope`'s own `NCollection_Map<TDF_Label> myValid` has no internal synchronization —
  two threads calling `namingScopeValid`/`IsValid`/`ValidChildren`/`Unvalid`/`ClearValid`/
  `ValidCount` on two *unrelated* documents race on that shared map.
- **`Font_FontMgr`'s font-list cache** (`OCCTBridge_Visualization.mm`): `g_fontList`/
  `g_fontListPopulated` is a classic unsynchronized check-then-act lazy-init, and the public
  `OCCTFontMgrInitDatabase()` can reassign both at any time from any thread, racing an
  in-progress iteration in any of the read-side functions.

**Fix:** bridge-only, matching the established #341/#344/#353 pattern — a dedicated
`std::mutex` per shared resource (`docNamingScopeMutex()`, `fontListMutex()`), held for the
duration of every access. No OCCT kernel change needed since both races are in bridge-owned
static state, not inside OCCT's own classes. New regression suite
`Issue361SharedSingletonThreadSafetyTests` (`Tests/OCCTThreadTests/`) — a basic exerciser, not the
authoritative verification, same honesty caveat as #341/#359's equivalent suites. Full `swift test`
(4426 tests) clean, both source and `OCCTSWIFT_BRIDGE_PREBUILT=1` build paths.

**Binary release** — `OCCTBridge.xcframework` (the opt-in prebuilt bridge from #339) changed again,
so `Package.swift`'s URL/checksum are bumped to this release. `OCCT.xcframework` is unchanged
(still v1.15.11, no kernel patch this release).

### v1.15.12 (July 2026) — fix (bridge): STEP import + 3 later-added STEP writers missing the DE mutex — #181-B's fix didn't fully hold (#359)

Found while scoping #342 (bridge-level thread-handling contract). #181-B (fixed by PR #184) found
that `STEPControl`/`STEPCAFControl`/`IGESControl` readers and writers share OCCT's process-global
`Interface_Static` parameter table, and serialized every STEP/IGES *writer* entry point on a shared
`igesMutex()` — the closing comment claimed this "serializes *all* of them." Auditing every function
in `OCCTBridge_IO.mm`/`OCCTBridge_Document.mm` that constructs a `STEPControl_Reader`/`Writer` or
`STEPCAFControl_Reader`/`Writer`, or calls `Interface_Static::Set*` directly, found that claim didn't
hold: **18 functions were missing `igesMutex()`** — every STEP import function (all added after PR
#184, across the "v0.58.0 STEP Full Coverage" and "v0.168.0 Progress" batches; the original #181-B
report was specifically about concurrent writes, so import was never in scope), plus 3 STEP export
functions added after PR #184 shipped (`OCCTExportSTEPWithName`, `OCCTExportSTEPWithModeProgress`,
`OCCTDocumentWriteSTEPWithModes`).

**Fix:** added `igesMutex()` to all 18 sites, matching the existing `#181-B` convention. Bridge-only,
no kernel change, no `OCCT.xcframework` rebuild. New regression suite
`Issue359STEPThreadSafetyTests` (`Tests/OCCTThreadTests/`) exercises concurrent STEP import/export
through the Swift API — like #341's equivalent suite, this is a basic exerciser (confirms no deadlock
and no round-trip regression), not the authoritative verification; a missing-lock bug on a
non-recursive `std::mutex` doesn't reliably manifest as an observable Swift-level failure at modest
concurrency. Full `swift test` (4424 tests) clean, both source and `OCCTSWIFT_BRIDGE_PREBUILT=1`
build paths.

Not the same issue as #280 (constructing a `STEPCAFControl_Reader` poisons subsequent STEP writes) —
confirmed during triage that #280 is a different, already-fixed mechanism (not `Interface_Static`-
related, resolved via a kernel patch in v1.10.1).

**Binary release** — `OCCTBridge.xcframework` (the opt-in prebuilt bridge from #339) changed, so
`Package.swift`'s URL/checksum are bumped to this release; consumers building with
`OCCTSWIFT_BRIDGE_PREBUILT=1` need the new release asset. `OCCT.xcframework` is unchanged (still
v1.15.11, no kernel patch this release).

### v1.15.11 (July 2026) — fix (kernel): CDM_Application::myMetaDataLookUpTable + CDM_MetaData field races under concurrent document save/close (#353)

Surfaced while validating the #349 fix: post-#349 TSan runs consistently produced one different,
previously-masked race — the "fixing one race exposes the next" pattern from #341→#344→#349
continuing. `CDM_Application::myMetaDataLookUpTable` is shared process-wide (one `CDM_Application`
singleton, since #344) with zero synchronization: `CDM_MetaData::LookUp()`'s map mutation,
`CDM_Document::SetMetaData()`'s whole-table iteration on every save, and each `CDM_MetaData`'s own
`myIsRetrieved`/`myDocument` fields all race independently. TSan confirmed the exact trace from the
issue: `SetMetaData()` reading `IsRetrieved()` racing a *different* document's destructor tearing
down its own metadata entry on another thread — 1 confirmed race + SIGABRT (exit 134) on stock
#349-fixed kernel.

**Fix:** `CDM_Application` gets a `mutable std::mutex` guarding the lookup table, threaded through
`CDM_MetaData::LookUp()` and `CDM_Document::SetMetaData()`'s iteration; `CDM_MetaData` gets its own
private mutex guarding `myIsRetrieved`/`myDocument`, independent of the table lock. TSan: 1 race +
SIGABRT → 0 races, clean exit, across 5 runs. `swift test --filter OCAFSaveLoadBinaryTests`/
`OCCTXCAFTests` and 3× full `swift test` (4423 tests) all clean. `CDM_MetaData::myDocumentVersion`
has the identical unguarded-field shape but on the reference-resolution path, not TSan-observed —
flagged as a plausible sibling, not fixed here. See
[`Scripts/repro/353-cdm-metadata-lookup-table/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/353-cdm-metadata-lookup-table)
for the reproducer and full writeup. Filed upstream as
[Open-Cascade-SAS/OCCT#1396](https://github.com/Open-Cascade-SAS/OCCT/issues/1396) (repro) /
[OCCT#1397](https://github.com/Open-Cascade-SAS/OCCT/pull/1397) (fix, CI green on all platforms).

### v1.15.10 (July 2026): ThreadSanitizer gate for concurrency-touching changes (docs/tooling)

Docs-and-tooling release; no API, bridge, or kernel changes, and no new binary assets (the
`OCCT.xcframework.zip` binary target continued to resolve from the v1.15.9 release until v1.15.11
above).

Formalizes the TSan protocol that found and validated #298/#341/#344/#349 as a routine gate
(#355, plus the #356 sysroot fix):

- `Scripts/tsan-stress.sh`: `build` produces a minimal-module ThreadSanitizer OCCT (all carried
  patches applied) into `Libraries/occt-install-tsan`; `run` compiles the `Scripts/repro/` stress
  harnesses and executes a 7-scenario gate matrix that must be race-clean; `swift` runs
  `swift test --sanitize=thread` on the concurrency-focused suites (wrapper-only coverage).
- `Scripts/tsan.supp`: curated suppressions; only confirmed-benign races or filed-and-open kernel
  findings, each with an issue link and a removal condition. The #353 entry was removed in
  v1.15.11 once that kernel patch landed.
- `docs/thread-safety.md`: new "ThreadSanitizer gate" section defining when the gate is required
  (new concurrent bridge paths, newly parallel-wrapped subsystems, mutex removals, new
  thread-safety kernel patches) and the rule that new concurrent usage patterns add a scenario.
- Verified end-to-end: gate green (7/7 scenarios, zero unsuppressed races) against the patched
  `V8_0_0_p1` kernel.

Context: upstream OCCT CI runs no sanitizers, so races this gate does not catch are caught by
nobody. See the ecosystem report `docs/occt-kernel-bug-deep-dive-2026-07.md` (SecondMouseAU/ecosystem#23).

### v1.15.9 (July 2026) — fix (kernel): PCDM_StorageDriver/PCDM_Reader driver-instance reentrancy SIGSEGV under concurrent Save/SaveAs of the same format (#349)

`CDF_Application::WriterFromFormat`/`ReaderFromFormat` cache one storage/retrieval driver instance
per document format and hand the same cached instance back to every subsequent `Store()`/
`Retrieve()` call for that format — including from different threads, different documents,
concurrently. Found while validating the #344 fix. `PCDM_StorageDriver`/`PCDM_Reader` subclasses
(`BinLDrivers_DocumentStorageDriver` et al.) are not reentrant: `Write()`/`Read()` mutate
instance-level scratch state (`myRelocTable`, `myTypesMap`, and others) with no synchronization,
so two threads calling `Write()` on the same cached instance corrupt it — a reliably reproducible
SIGSEGV (`BinMDF_ADriverTable::AssignIds` on a torn `myTypesMap`), confirmed by TSan (136 race
warnings + crash on stock kernel). Structural, not BinLDrivers-specific — `XmlLDrivers`,
`BinXCAFDrivers`/`XmlXCAFDrivers`, and `TObj` drivers all share the same base classes and pattern.

**Fix:** `PCDM_StorageDriver`/`PCDM_Reader` each get a `mutable std::mutex` guarding their own
`Write()`/`Read()`, held at the three call sites (`CDF_StoreList::Store`,
`CDF_Application::Retrieve`, `CDF_Application::Read`) that invoke a cached, possibly-shared driver
— every format driver subclass inherits the guard for free. TSan: 136 races + SIGSEGV → 0 races,
clean exit. The interim bridge-side mitigation (`ocafStoreMutex()`, shipped v1.15.6) stays in
place, same PR1→PR2 pattern as #298/#341/#344. See
[`Scripts/repro/349-ocaf-driver-reentrancy/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/349-ocaf-driver-reentrancy)
for the reproducer and full writeup. Filed upstream as
[Open-Cascade-SAS/OCCT#1393](https://github.com/Open-Cascade-SAS/OCCT/issues/1393) (repro) /
[OCCT#1394](https://github.com/Open-Cascade-SAS/OCCT/pull/1394) (fix, CI green on all platforms).

A separate, previously-masked race surfaced during validation of this fix
(`CDM_Application::myMetaDataLookUpTable`, unsynchronized) — out of scope for #349, filed as
[#353](https://github.com/SecondMouseAU/OCCTSwift/issues/353).

### v1.15.8 (July 2026) — fix (kernel): ShapeUpgrade_UnifySameDomain unguarded null-pcurve dereference SIGSEGV on mesh-sewn solids (#348)

`UnifySameDomainBuilder.build()` SIGSEGV'd (Address 0, uncatchable in-process) on a real
mesh-sewn solid — found via OCCTReconstruct#194, minimized to a standalone, deterministic
OCCTSwift-only reproducer (just load a BREP, run the builder). Root cause:
`ShapeUpgrade_UnifySameDomain::IntUnifyFaces` (and its file-local `SplitWire` helper)
disambiguate between multiple candidate next-edges at a branching vertex by comparing each
candidate's pcurve tangent direction on the current reference face; three call sites in
`IntUnifyFaces` and a structurally identical pair in `SplitWire` fetch that pcurve via
`BRep_Tool::CurveOnSurface(...)` and dereference it immediately (`->D1(...)`/`->Value(...)`)
with no `IsNull()` check — unlike every other `CurveOnSurface` call site in the same file, which
do check. `CurveOnSurface` legitimately returns a null handle when an edge has no pcurve on the
given face, routine for a raw mesh-sewn solid (`BRepBuilderAPI_Sewing` from an STL/mesh import)
at a vertex shared by more than two edges. Confirmed via a debug (`-g -O0`) single-TU
override-link + `lldb bt`: resolves precisely to `ShapeUpgrade_UnifySameDomain.cxx:4003`
(`aPCurve->D1(...)`), reached via `IntUnifyFaces` → `UnifyFaces` → `Build`. **Fixed** (kernel
patch `Scripts/patches/0013-*`, xcframework rebuilt): all five sites guard with `IsNull()`,
following the file's own established pattern — a missing pcurve on a candidate edge means "skip
it, not a rankable direction"; a missing pcurve on the current edge falls back to treating all
candidates as equally likely, same as the existing single-candidate shortcut. New regression test
`Tests/OCCTStressTests/StressNullInvalidTests.swift`'s
`unifySameDomainOnMeshSewnSolidWithMissingPCurve`. Reproducer at
[`Scripts/repro/348-unify-null-pcurve`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/348-unify-null-pcurve);
filed upstream as [OCCT#1391](https://github.com/Open-Cascade-SAS/OCCT/issues/1391) (repro) /
[OCCT#1392](https://github.com/Open-Cascade-SAS/OCCT/pull/1392) (fix). #348.

### v1.15.7 (July 2026) — fix (bridge): 49 unguarded gp_Dir/Geom_Direction constructions — the likely #345 SIGABRT (#345)

**#345's companion crash to #344**, root-caused via an audit rather than direct reproduction:
#345 was filed with essentially no evidence (`exited with unexpected signal code 6`, no test
name, no backtrace). OCCT's `gp_Dir` and `Geom_Direction` constructors throw
`Standard_ConstructionError` for a zero-length (or near-zero) direction/normal vector. **49 public
bridge functions** across 7 files constructed these directly from caller-supplied doubles (or
called a `D0`/`D1`/`D2` derivative evaluator, or a `GeomEval_*Surface` constructor — same
degenerate-input throw risk) with no try/catch anywhere in the call chain — e.g. `OCCTSurfaceD1`/
`OCCTSurfaceD2` had none, immediately next to `OCCTSurfaceGetNormal`, which already did. An
uncaught C++ exception crossing the bridge boundary into Swift-generated call frames is a
guaranteed `std::terminate()` → `abort()` (SIGABRT), leaving almost no diagnostic trail — matching
#345's profile exactly.

**Fix**: wrapped all 49 functions in `try { ... } catch (...) { <safe fallback> }`, matching each
file's existing idiom. The 3 functions returning a `_Nonnull` pointer
(`OCCTAxis1PlacementCreate`/`OCCTAxis2PlacementCreate`/`OCCTOBBCreate`) fall back to a valid default
axis rather than `nullptr`, since returning null from a `_Nonnull` contract would just relocate the
crash. Two confirmed false positives left untouched: `computePlaneForPoints` and `buildTrsf3D`
(two separately-defined `static` helpers) are both already protected by a `try` in their sole
caller.

**Validation**: 70 additional full-suite `swift test` runs (4419-4422 tests each, ~309,540
individual test executions) — zero crashes of any kind. New regression tests
(`Tests/OCCTStressTests/StressNullInvalidTests.swift`): `mirrorAxisZeroDirection`,
`mirrorPlaneZeroNormal`, `geomDirectionZeroVector`.

Bridge-only fix — no OCCT kernel change, no `OCCT.xcframework` rebuild (the prebuilt
`OCCTBridge.xcframework` opt-in artifact is rebuilt). Not an OCCT bug, so nothing filed upstream.
#345's own bar for confident closure was "100+ runs with no recurrence" — 70 clean runs plus a fix
matching the exact crash mechanism is short of that literal bar but the strongest evidence gathered
to date. #345.

### v1.15.6 (July 2026) — fix (kernel): XCAFApp_Application::GetApplication/CDF_Directory races — the SIGSEGV #341 didn't explain (#344)

**The uncatchable SIGSEGV that survived the #341 fix.** #341 (v1.15.5) fixed a real
`XCAFDoc_ShapeTool::theAutoNaming` race, but flagged a separate empirical SIGSEGV (garbage fault
address, right after two concurrent OBJ imports) as unconfirmed — filed as #344. Re-running the
parallel `swift test` stress loop 12× against v1.15.5 hit it again once: confirmed genuinely
independent of #341's fix.

**Root cause: two races in code the #341 TSan stress never reached.** That harness builds
`TDocStd_Document` directly (`new TDocStd_Document("BinXCAF")`), bypassing
`XCAFApp_Application`/`CDF_Application` entirely — but every real bridge call
(`OCCTDocumentLoadOBJ` and every other document-producing function) goes through
`XCAFApp_Application::GetApplication()->NewDocument(...)`.

1. `XCAFApp_Application::GetApplication()`'s lazy singleton init is a textbook
   double-checked-locking-without-locking bug — two threads' first concurrent call can both
   construct a new instance and race to assign the shared handle. TSan shows this is the dominant
   defect: it produces multiple concurrently-constructed `XCAFApp_Application` instances, cascading
   into races across dozens of unrelated destructors as the "losing" instances are torn down
   mid-flight.
2. `CDF_Directory::Add`/`Remove`/`Contains` mutate/read `myDocuments` (a plain `NCollection_List`)
   with zero synchronization — every `CDF_Application` is normally one process-wide instance shared
   by every caller, so its one `CDF_Directory` races on `NCollection_BaseList::PAppend` from every
   document-creating call on every thread.

**Fix**, `Scripts/patches/0012-CDF_Directory-XCAFApp_Application-thread-safety-344.patch`:
`GetApplication()` folds construction into the static local's initializer (C++11 magic statics,
thread-safe exactly once, replacing the separate `IsNull()`-guarded assignment); `CDF_Directory`
gets a private `std::mutex` guarding `Add`/`Remove`/`Contains`/`Length`/`IsEmpty`/`Last`.

**Validation:** a debug (`-O0 -g`) build with a temporary `SIGSEGV`/`SIGBUS` signal handler
(`backtrace_symbols_fd`) crashes ~50% of runs at 10 threads × 3000 barrier-synchronized rounds on
stock p1, both captured backtraces resolving to `TDocStd_Application::NewDocument ->
CDF_Application::Open`. TSan (same minimal-module protocol as #298/#319/#341) goes from 234 race
reports to 9 — all directly in `CDF_Directory::Add`/`PAppend` and all showing the *same* mutex held
on both sides of the reported conflict, consistent with a TSan/allocator-recycling artifact rather
than a genuine unaddressed race (a control program with a trivially-correct mutex pattern shows no
such warning under identical flags). The entire `GetApplication()`-driven destructor cascade —
dozens of unique signatures pre-fix — is gone entirely. New regression test
`parallelDocumentCreate` (`OCCTStressTests`, `StressConcurrentDocumentCreationTests`) exercises
`Document.create()` from 40 concurrent tasks.

**Found during validation of the fix above**: correctly making `GetApplication()` a true singleton
means every caller now genuinely shares ONE `TDocStd_Application` instance — surfacing more races
on that instance's *other* unsynchronized state, previously masked by threads sometimes getting
different (uncontended) instances. Repeated `swift test` runs hit a SIGTRAP in
`Resource_Manager::SetResource` (via `TDocStd_Application::DefineFormat`, called by the common
`Document.defineAllFormats()` test-setup path) and a SIGSEGV in `TDocStd_Application::
ReadingFormats` iterating `CDF_Application::myReaders` concurrently with a writer.
`TDocStd_Application::Resources()` has the identical lazy-init bug as `GetApplication()`;
`Resource_Manager`'s maps and `CDF_Application::myReaders`/`myWriters` have zero synchronization.
Also fixed in the same patch: a mutex for `Resources()`'s lazy-init, a `std::recursive_mutex` for
`Resource_Manager`'s accessors (with an explicit copy constructor — the new mutex broke
`ShapeProcess_Context.cxx`'s existing `new Resource_Manager(*sRC)` thread-safety workaround, whose
own comment already acknowledged this exact defect), and a mutex for `myReaders`/`myWriters`. 0/12
further `swift test` runs of `OCCTXCAFTests` reproduce either crash after the fix.

A third, architecturally different crash surfaced in the same validation
(`BinLDrivers_DocumentStorageDriver::Write` corrupting a shared, cached, non-reentrant
storage-driver instance under concurrent `Save`/`SaveAs` of the same format) — a shared worker
object, not a container needing a lock, so the kernel fix needs its own dedicated investigation;
filed separately as #349. It was severe enough alone (~60% crash rate in `OCCTXCAFTests` once the
two races above stopped masking it) that this release also ships an **interim bridge-side
mitigation**: `ocafStoreMutex()` (`OCCTBridge_Document.mm`) serializes
`OCCTDocumentSaveOCAF`/`OCCTDocumentSaveOCAFInPlace`/`OCCTDocumentLoadOCAF` — the same #298/#341
bridge-mutex-now/kernel-fix-later pattern. 0/12 further `swift test` runs of `OCCTXCAFTests` crash
after this mitigation.

Reproducer at [`Scripts/repro/344-cdf-directory/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/344-cdf-directory); filed upstream as
[Open-Cascade-SAS/OCCT#1389](https://github.com/Open-Cascade-SAS/OCCT/issues/1389) (repro) /
[OCCT#1390](https://github.com/Open-Cascade-SAS/OCCT/pull/1390) (fix, two commits). #344.

### v1.15.5 (July 2026) — fix (kernel): XCAFDoc_ShapeTool::theAutoNaming race, replacing v1.15.4's bridge mitigation (#341)

**Follow-up to v1.15.4.** That release shipped an immediate bridge-side mitigation (`meshCafMutex()`)
for the `XCAFDoc_ShapeTool::theAutoNaming` race characterized in #341. This release carries the real
kernel fix and removes the bridge lock as redundant — the #298 PR1→PR2 pattern.

**The full hazard, on closer inspection, was bigger than v1.15.4's writeup captured.** Auditing every
internal caller of `theAutoNaming` turned up two more independent save/modify/restore sites beyond
`RWMesh_CafReader::fillDocument()`: a *separate*, near-duplicate override in
`RWGltf_CafReader::fillDocument()` (not a call into the base class's version — glTF import has its
own copy of the same unsynchronized dance), and `XCAFDoc_Editor::Expand()`, which additionally
recurses into itself while the dance is in flight. Verifying the bridge mutex fix under TSan (with
the mutex removed, to test the kernel in isolation) also surfaced a second, narrower problem the
v1.15.4 characterization missed: even with the three save/restore sites serialized against each
other, an *unscoped* `XCAFDoc_ShapeTool::AddShape` call (e.g. any export building a document from an
existing shape, outside all three sites) still reads the raw `bool` with no synchronization at all —
a genuine data race independent of the "logical" interleaving bug.

**Fix, both layers**, in `Scripts/patches/0011-XCAFDoc_ShapeTool-AutoNamingScope-341.patch`:

1. `XCAFDoc_ShapeTool::AutoNamingScope` — a new RAII helper backed by a `std::recursive_mutex` held
   for its entire lifetime (not just around the individual get/set calls), so overlapping
   save/modify/restore sequences from any of the three sites serialize correctly instead of
   interleaving (recursive because `Expand()` reenters it on the same thread). All three sites now
   use it; `Expand()`'s two duplicate manual-restore-before-return call sites collapse into one
   destructor-driven restore that fires on every exit path.
2. `theAutoNaming` itself is now `std::atomic<bool>` instead of a plain `bool`, so every access
   anywhere in the file — including `AddShape`'s internal read — is well-defined, closing the
   residual gap the mutex alone doesn't reach. Not a semantic change: `SetAutoNaming`/`AutoNaming`
   remain a single global setting, exactly as documented; an unscoped reader still sees "whatever
   mode is currently active," it just now gets a real, non-torn value instead of undefined behavior.

**Verification.** The same TSan stress (10 threads × 200 concurrent OBJ round-trips, each its own
file) reports **zero** `theAutoNaming` races across 4 separate runs, down from 9-17/run before the
fix — verified with the bridge-side `meshCafMutex()` mitigation removed, testing the kernel fix in
isolation. Zero regression on the `create_fillet_boolean` (#298) and independent-meshing scenarios.
`RWGltf_CafReader`'s copy of the fix compiles cleanly and is mechanically identical to the
`RWMesh_CafReader` path that was exercised, but wasn't run under TSan directly — this repo's
minimal-module TSan build excludes `TKDEGLTF` (needs RapidJSON, disabled for build speed).

**Binary release** — both `OCCT.xcframework` (kernel patch, all 3 core slices rebuilt) and
`OCCTBridge.xcframework` (the opt-in prebuilt bridge from #339; `meshCafMutex()` removed) changed, so
`Package.swift` picks up new URLs + checksums for both.

Filed upstream as [Open-Cascade-SAS/OCCT#1387](https://github.com/Open-Cascade-SAS/OCCT/issues/1387)
(repro, filed alongside v1.15.4) / [OCCT#1388](https://github.com/Open-Cascade-SAS/OCCT/pull/1388)
(fix, draft PR, CLA-covered fork).

### v1.15.4 (July 2026) — fix: concurrent OBJ/glTF/PLY import races on an unsynchronized OCCT global; the long-claimed "NCollection race" doesn't hold up (#341)

**Background.** `CLAUDE.md`'s Known OCCT Bugs and this changelog have carried a "pre-existing
non-deterministic NCollection arm64 race under parallel execution" claim since ~v0.51.0, backing a
`swift test --no-parallel` recommendation and three permanently-`.disabled()` suites in
`Tests/OCCTStressTests/StressConcurrencyTests.swift`. The claim was never reproduced, root-caused, or
filed anywhere — it had been riding purely on observed flakes. Filed and investigated as #341
(companion #342), from an OCCTReconstruct test-contention audit that found the same doctrine costing
real CI time downstream (OCCTReconstruct#175/#309).

**Investigation.** Applied the #298 TSan protocol: a minimal-module ThreadSanitizer build of
V8_0_0_p1 (+ all 10 carried patches) covering `FoundationClasses`+`ModelingData`+
`ModelingAlgorithms`+`DataExchange`. Concurrent create/fuse/fillet and independent meshing scenarios
are clean except the already-known, benign `BOPAlgo_InitMessages` lazy-init race (see the #298 entry
below). **No NCollection race reproduced at any tested scale.** Re-enabled the three long-disabled
stress suites — 25/25 clean runs across repeated iterations — and removed their unevidenced
`.disabled()` claims permanently.

**What was actually found.** A concurrent OBJ round-trip scenario (each thread its own uniquely-named
file, so not a file-path collision) reported 9-17 ThreadSanitizer races per run, all resolving to one
root cause: `RWMesh_CafReader::fillDocument()` (the shared base of `RWObj_CafReader` and
`RWGltf_CafReader` — reachable via OBJ **and** glTF import, and PLY export via `AddShape`)
saves/mutates/restores `XCAFDoc_ShapeTool::theAutoNaming` — a process-global `static bool` — with
zero synchronization; `XCAFDoc_ShapeTool::AddShape` reads the same flag. Same failure class as #298
(an unsynchronized save/modify/restore dance on shared global state), but cosmetic (wrong
auto-naming) rather than geometric. Minimal C++ reproducer, methodology, and full writeup:
[`Scripts/repro/341-meshcaf/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/341-meshcaf).

**Fix.** Bridge-only mitigation (matches the #298 PR1 pattern — no kernel patch or `OCCT.xcframework`
rebuild needed for this release): every OBJ/glTF/PLY CAF-reader/writer bridge function now serializes
on a dedicated `meshCafMutex()` (`OCCTBridge_IO.mm`). Not yet filed upstream. New regression suite
`Issue341MeshCafThreadSafetyTests` (`OCCTThreadTests`) exercises concurrent OBJ round-trips through
the Swift API — documented honestly as a basic exerciser, not a reliable reproducer at this scale (the
race needs sanitizer instrumentation or a much larger operation count to surface without one).

**Binary release** — `OCCTBridge.xcframework` (the opt-in prebuilt bridge from #339) changed, so
`Package.swift` picks up the new URL + checksum; `OCCT.xcframework` is unchanged. Consumers building
`OCCTBridge` from source (the default) get the fix by pulling this tag; consumers on
`OCCTSWIFT_BRIDGE_PREBUILT=1` need the new release asset.

**Still open, filed separately.** Two hard crashes (SIGSEGV/SIGABRT, garbage-looking fault addresses)
were observed empirically in ~2 of 20 full-suite parallel `swift test` runs during this
investigation. Filed as #344 (SIGSEGV, right after two concurrent OBJ imports — possibly the same
`theAutoNaming` race in a rarer timing window that produces heap corruption instead of just wrong
naming, unconfirmed) and #345 (SIGABRT, essentially no localizing evidence). **Correction**: this
entry originally attributed the SIGABRT to a `BinTools`/`TopTools` "File was not written with this
version of the topology" message seen nearby in the log, and floated fixed-temp-file-path collisions
as a working theory. Both were wrong — that message is routine, expected output from two intentional
negative tests (`Tests/OCCTIOTests/OCCTIOTests.swift`'s `BREPStringSerializationTests`, exercising
`Shape.fromBREPString` on malformed input) and appears in every run including clean ones; it has no
connection to either crash, and the fixed-temp-file-path theory was speculation based on that false
premise. #342 (bridge-level thread-handling contract: per-call safety classification,
scoped/controllable internal parallelism) remains open and gets a concrete first classified entry
from this investigation — OBJ/glTF/PLY CAF operations are `exclusive` (need `meshCafMutex()`).

### v1.15.3 (July 2026) — chore: opt-in prebuilt `OCCTBridge.xcframework`, skip compiling the 62K-line Obj-C++ bridge per consumer rebuild (#339)

**Problem, from an OCCTReconstruct build-time audit (OCCTReconstruct#309):** `OCCTBridge` is 16
Objective-C++ files / ~62K lines, each including a large slice of OCCT's ~1,700 headers. SwiftPM
recompiles all 16 from source on every consumer of OCCTSwift — measured at 51.6s wall / 186.5s CPU
per rebuild in one path-dependency consumer worktree, on top of the ecosystem's [shared-xcframework
setup](../docs/guides/sharing-the-xcframework.md). A cold artifact re-extraction compounds this by
re-stamping header mtimes and invalidating every consumer's clang module cache.

**Fix.** `Scripts/build-occtbridge.sh` compiles the bridge once per platform slice (same core slices
as `OCCT.xcframework`: macOS, iOS device, iOS simulator) and packages it as `OCCTBridge.xcframework`
— compiled objects + public header, no OCCT source involved. Set **`OCCTSWIFT_BRIDGE_PREBUILT=1`**
to have `Package.swift` link this prebuilt binary (local copy if present, else the matching release
asset) instead of compiling `Sources/OCCTBridge/src/*.mm` from source.

**Default is unchanged (source build).** Every release edits the bridge source directly and tests
against those edits (see `CLAUDE.md`'s Release Process); a prebuilt binary that silently doesn't
reflect fresh edits would be a correctness trap. The prebuilt path is strictly opt-in — full details,
including the local escape hatch for bridge iteration and visionOS/tvOS (not covered by the core
prebuilt slices), in [docs/guides/prebuilt-bridge.md](../docs/guides/prebuilt-bridge.md).

**Verification.** Both paths built clean and the full test suite passed against each: the default
source build (regression check, unchanged behavior) and `OCCTSWIFT_BRIDGE_PREBUILT=1` (55/55 tests
in `OCCTThreadTests` exercising real boolean/fillet/mesh operations through the prebuilt binary,
confirming it's not just a link-success check).

**Binary release** — `OCCTBridge.xcframework.zip` ships as a new release asset alongside the
existing `OCCT.xcframework.zip`; `Package.swift`'s `occtBridgeTarget` URL + checksum point at it.

### v1.15.2 (July 2026): docs + tests — chaining `*WithFullHistory` ops across a `BRepGraph`, retract the #336 "absorbs zero records" report (#336)

**Not a bug — investigated and retracted.** #336 reported that a second `*WithFullHistory` boolean op
chained onto a prior op's live output absorbed zero history records into `add(_:absorbing:inputRoots:
operationName:)`. Verified two independent ways: probing the raw `ShapeHistoryRef` directly against the
first op's output faces (bypassing the graph and `CollectHistoryInputs`/`Absorb` entirely) showed the
same zero records, and `out1.volume == out2.volume` confirmed the second cut changed nothing
geometrically. **Root cause: the reporter's tool placement, not the absorb path.**
`Shape.box(width:height:depth:)` is centered at the origin (documented on the API itself), not
corner-anchored like raw OCCT's `BRepPrimAPI_MakeBox(w,h,d)`. The repro's first "corner" tool landed
fully *inside* the box (an interior-cavity cut) and its second "opposite corner" tool landed entirely
*outside* the box's actual bounds — the two shapes' bounding boxes don't even overlap — so the second
cut was a genuine geometric no-op. Zero absorbed records was the correct answer.

**Real gap found and closed: test coverage.** No existing test chained two `*WithFullHistory` ops
end-to-end (second op fed from the first op's live, `Compound`-wrapped output) or passed a non-root
`NodeRef` as `inputRoots` — every `GraphHistoryAbsorbTests` case only did a single hop rooted at the
graph's own top-level node. New `Issue336ChainedHistoryTests` (`OCCTBRepGraphTests`) covers both: a
genuine two-hop chain (opposite real corners) absorbing records at each hop, and a permanent regression
guard for the reporter's exact non-intersecting geometry asserting the zero-record result stays correct.

- **Docs:** `docs/reference/BRepGraph-Detail-History.md` gains a "Chaining multiple operations" section
  with a runnable multi-hop snippet and the box-centering gotcha, right where `add(_:absorbing:...)` is
  documented.
- Docs only, no code or binary change — reuses the v1.15.1 xcframework (the binaryTarget URL is
  unchanged).

### v1.15.1 (July 2026) — fix: `isSelfIntersecting(hardTimeout:)` can now actually interrupt a stuck self-interference search (#319)

**Root cause — two compounding defects** in `BOPAlgo_ArgumentAnalyzer`'s self-interference phase (`BOPAlgo_CheckerSI::CheckFaceSelfIntersection` → `IntTools_FaceFace::Perform` → `Intf_Interference::Insert`), found while independently verifying a reproducer contributed against [OCCTReconstruct#295](https://github.com/SecondMouseAU/OCCTReconstruct/issues/295): a pathological artifact ran 619s+ of CPU against a 30s `hardTimeout:` deadline and never returned.

1. `Intf_Interference::Insert` compares points between the new tangent zone and every existing zone via `Intf_TangentZone::GetPoint(Index)`, called inside a doubly-nested loop. `GetPoint` indexes the zone's backing `NCollection_Sequence` — a linked list with no O(1) random access — so each call walks from the nearest end. Profiling (independently reproduced) attributed ~80% of leaf samples to `NCollection_BaseSequence::Find`. The artifact produces an unboundedly growing *number* of distinct tangent zones, not one giant merging zone, so this alone doesn't bound wall-clock time — it just makes the per-comparison cost O(1) instead of O(n).
2. The self-interference phase never polled its cooperative progress indicator anywhere *inside* a single face's check — only between whole-face checks, which is not where the artifact gets stuck.

**Fix — both layers.** `Intf_TangentZone::Points()` builds and caches a true `NCollection_Array1` per zone in one linear pass on first use (invalidated by any mutation); `Insert()` indexes through it instead of calling `GetPoint` in the nested loop. `Intf_Interference::SetBreaker` (thread-local, RAII-scoped via `Intf_InterferenceBreakerScope`) lets `Insert()` poll a `Message_ProgressScope` every 256 calls and abort by throwing `Standard_Failure`, unwinding the `IntTools_FaceFace`/`Intf_Interference` call stack safely; `BOPAlgo_CheckerSI`'s self-intersect functor wires this up around `IntTools_FaceFace::Perform`, gated on `!myRunParallel` — an exception from an `OSD_Parallel::For` worker thread would risk `std::terminate()`, so the checkpoint is only active single-threaded. Kernel patch carried as `Scripts/patches/0010-Intf_Interference-O1-tangent-zone-checkpoint-breaker-319.patch`, xcframework rebuilt.

**Verification.** On the linked artifact, a 0.5s deadline now returns in 0.547s and a 30s deadline in 30.1s (vs. 619s+ CPU / never returning on stock p1), correct `HasFaulty()` results at every deadline tested (0.5s/1s/2s/3s/5s/30s), clean across a 10x repeated-run stress test. Zero regression on clean, overlapping, and grid self-intersection sanity cases (byte-identical output). An empty-zone edge case in `Points()` is guarded explicitly (`NCollection_Array1::Resize(1, 0, false)` throws `Standard_RangeError` for an empty range) — caught by a dedicated GTest before it could reach a real caller. New upstream GTests `Intf_TangentZone_Test.cxx`/`Intf_Interference_Test.cxx` pass on Linux/Windows/macOS in OCCT's own CI. Reproducer committed at [`Scripts/repro/319-selfintersection`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/319-selfintersection). Upstreamed as [Open-Cascade-SAS/OCCT#1385](https://github.com/Open-Cascade-SAS/OCCT/issues/1385) (repro) / [OCCT#1386](https://github.com/Open-Cascade-SAS/OCCT/pull/1386) (fix — full CI green on the first submission across clang-format, ASCII check, all 3 platform builds, and GTest); the carried patch retires once it ships in the pinned kernel. **Binary release** — the xcframework changed, so `Package.swift` picks up the new URL + checksum; remote SPM consumers get the rebuilt binary.

- **Docs:** `CLAUDE.md`'s Known OCCT Bugs entry added for #319; `Scripts/patches/README.md` and `okf/references/carried-occt-patches.md` document patch `0010`.

### v1.15.0 (July 2026) — `TopologyGraph` renamed to `BRepGraph` (closes #333)

**MINOR — additive; old name still works.** `TopologyGraph` read as too close to OCCT's own `TopoDS_*`
family (`TopoDS_Shape`, `TopoDS_Face`, ...) on a skim, without signaling that it specifically wraps the
BRepGraph durable-identity engine. Renamed to `BRepGraph`, matching both the C++ package it wraps and
this file's own name (`BRepGraph.swift`).

```swift
@available(*, deprecated, renamed: "BRepGraph")
public typealias TopologyGraph = BRepGraph
```

Existing code compiles unchanged (with a deprecation warning) under the old name. New code should use
`BRepGraph`. The typealias stays until a later release drops it per the usual deprecation policy — no
removal date set yet.

Docs move alongside the rename: `docs/reference/TopologyGraph*.md` → `BRepGraph*.md`,
`docs/guides/cookbook/topology-graph*.md` → `brep-graph*.md`. The `Tests/OCCTTopologyGraphTests` target
is renamed to `Tests/OCCTBRepGraphTests` (internal only, no consumer-visible effect).

### v1.14.0 (July 2026) — feat: `*WithFullHistory` parity for translate/rotate/scale/mirror/patterns (#331)

Extends the #290 `ShapeHistoryRef`/`add(_:absorbing:)` pattern — already shipped for booleans, fillet/
chamfer/shell/defeature (#165), and sew/quilt/heal (#327, v1.13.0) — to the last gap: transforms and
patterns. Consumers doing incremental persistent-identity tracking (OCCTMCP #91/#93) previously had to
fall back to a generation reset after any of these ops, losing continuity for `GraphUID`s minted before
the transform.

**New, all returning `(result: Shape, history: ShapeHistoryRef)`:**

- `Shape.translatedWithFullHistory(by:)`
- `Shape.rotatedWithFullHistory(axis:angle:)`
- `Shape.scaledWithFullHistory(by:)`
- `Shape.mirroredWithFullHistory(planeNormal:planeOrigin:)`
- `Shape.linearPatternWithFullHistory(direction:spacing:count:)`
- `Shape.circularPatternWithFullHistory(axisPoint:axisDirection:count:angle:)`

```swift
let hole = Shape.cylinder(radius: 3, height: 10)!
let (row, history) = hole.linearPatternWithFullHistory(direction: SIMD3(20, 0, 0), spacing: 20, count: 5)!
let copies = history.record(of: someHoleFace).modified   // 5 corresponding instance faces
graph.add(row, absorbing: history, inputRoots: [root], operationName: "linearPattern")
```

**Implementation — two different shapes, unlike the #327 batch:**

- **translate/rotate/scale/mirror** all bottom out in `BRepBuilderAPI_Transform`, which (unlike
  sewing/healing) genuinely derives from `BRepBuilderAPI_MakeShape` — so these reuse the existing
  `OCCTBooleanHistoryAsBRepToolsHistory` retained-builder/args synthesis path unchanged, the same one
  fillet/chamfer/defeature use. The plain (non-history) transform functions already construct
  `BRepBuilderAPI_Transform` with `theCopyGeom = true`, which forces
  `BRepBuilderAPI_Transform::Perform` down its `myUseModif = true` branch unconditionally (confirmed in
  `BRepBuilderAPI_Transform.cxx`) — so `Modified()`/`Generated()` always come from the real
  `BRepTools_Modifier`, never the "same TShape, just relocated" short-circuit that would otherwise
  report nothing.
- **Patterns are N:1**, not 1:1, so the single-builder synthesis path doesn't apply: each pattern
  instance is an independent `BRepBuilderAPI_Transform` run against the same source shape. History is
  built manually — one shared `BRepTools_History`, with every instance's `Modified`/`Generated` results
  for each *original* source sub-shape folded in via `AddModified`/`AddGenerated` (confirmed these
  append rather than replace, in `BRepTools_History.hxx`) — so a source sub-shape's history record
  reports all `count` corresponding instance sub-shapes, one per copy including the identity-transformed
  original at index 0.

New suite `TransformPatternFullHistoryTests` (`OCCTModelingTests`), 10 tests, including two graph-absorb
integration tests (one 1:1 transform, one N:1 pattern) proving both history shapes flow through
`OCCTBRepGraphAddWithHistory` correctly, and two zero-length-direction regression tests for the
exception-safety fix caught in review (`gp_Vec::Normalize`/`gp_Dir`'s constructor throw on a zero
vector; the pattern wrappers now guard that inside their own try/catch instead of leaving it to the
caller). No kernel change, no xcframework rebuild — reuses the v1.12.9 binary.

### v1.13.1 (July 2026) — feat: hard-bounded `isSelfIntersecting`, TSan-verified (#319)

Follow-up to #293 (closed, doc-only fix): `isSelfIntersecting(timeout:)` is cooperative — it can only
return once OCCT polls, and `BOPAlgo_ArgumentAnalyzer`'s self-interference phase has at least one long
checkpoint-free stretch (`Intf_Interference::Insert`). #319 tracked two tracks; only Track 1 ships here.

**New: `Shape.isSelfIntersecting(hardTimeout:)`** — a genuinely hard wall-clock bound. Runs the check
on a detached background thread against a `deepCopy()` (independent geometry, the standard pattern for
concurrent OCCT work), and waits on the calling thread with a real `DispatchSemaphore` deadline. If the
deadline passes first, returns `nil` immediately and the background computation is **abandoned, not
cancelled** — it keeps running orphaned until it eventually completes (burned CPU traded for a
caller-side guarantee, the same trade the #286 mesher-hang caller made). Additive: `timeout:` is
unchanged, and the two overload labels (`timeout:` / `hardTimeout:`) disambiguate cleanly.

**Prerequisite work, not skipped:** the reason this wasn't done alongside the v1.12.5 doc fix was an
open question — is `BOPAlgo_ArgumentAnalyzer` safe to run on a worker thread concurrently with
unrelated OCCT calls on other threads? That shape of concurrency (not OCCT's own internal
`SetRunParallel`, and not this project's usual "independent shapes on independent threads" pattern
either, since the *caller* keeps running) had no precedent in this codebase. Investigated with the same
method that found #298's fillet race: a minimal OCCT build (`FoundationClasses` + `ModelingData` +
`ModelingAlgorithms` only) with `-fsanitize=thread`, then a stress harness — 60 bursts × 8 threads, half
running self-intersection checks on independent self-intersecting compounds (36 overlapping boxes,
genuine interference so `Intf_Interference::Insert` does real work), half running unrelated
fuse+mesh work concurrently on independent shapes. 480 operations, zero TSan race reports, zero
wrong-but-plausible results. That's a positive signal on one stress shape and one access pattern, not
an exhaustive audit — the doc comment says so explicitly, and `isSelfIntersecting(timeout:)` stays the
default recommendation unless a caller genuinely needs the hard guarantee.

**Track 2 (upstream OCCT report: missing checkpoints + the `Intf_Interference::Insert` quadratic)
remains blocked** — still needs the minimal, un-thrashed reproducer this issue originally hoped would
fall out of a quiet-host OCCTReconstruct #208 re-run. That hasn't happened: #208 itself is closed
(2026-07-18, no linked commit — superseded by a re-scoped successor line, not resolved), and neither
it nor its successors (#252, #254, the currently-open #292) touch self-intersection or timeouts at
all. No reproducer exists anywhere in that repo as of this release. No action taken on Track 2.

New suite `Issue319HardBoundedSelfIntersection` (`OCCTModelingTests`), 3 tests. No kernel change, no
xcframework rebuild — reuses the v1.12.9 binary.

### v1.13.0 (July 2026) — feat: `*WithFullHistory` for sewing, quilting, and healing (#327)

`add(_:absorbing:inputRoots:operationName:)` (#290) solved "an operation rebuilt the shape, keep my
selection" for booleans and Tier 2 modification ops — but only when the operation hands back a
`ShapeHistoryRef`, and the operations at the heart of a mesh-to-B-Rep pipeline (sew → heal → solid)
returned a bare `Shape?` with nothing to absorb.

**New, all returning `(result: Shape, history: ShapeHistoryRef)`:**

- `Shape.sewWithFullHistory(shapes:tolerance:)`, `.sewnWithFullHistory(with:tolerance:)`,
  `.sewnWithFullHistory(tolerance:)` (self-sew)
- `Shape.quiltWithFullHistory(_:)`
- `Shape.healedWithFullHistory()`
- `Shape.solidWithFullHistory(from:)`

```swift
let (shell, history) = Shape.sewWithFullHistory(shapes: faces, tolerance: 1e-6)!
let record = history.record(of: someInputFace)   // .modified / .generated / .isDeleted
graph.add(shell, absorbing: history, inputRoots: [root], operationName: "sew")
```

**Implementation:** none of these algorithms derive from `BRepBuilderAPI_MakeShape`, so the existing
`OCCTBooleanHistoryAsBRepToolsHistory` template-synthesis path (built for booleans/fillet/chamfer/
thick-solid) doesn't apply directly. `OCCTBooleanHistory` (the opaque handle behind `ShapeHistoryRef`)
now optionally carries an already-built `Handle(BRepTools_History)` instead of a retained builder:

- **Sewing** (`sew`/`sewn` both directions) — `BRepBuilderAPI_Sewing` always allocates its own
  `BRepTools_ReShape` context (confirmed in `occt-src`) and records every vertex/edge merge and
  small-face removal into it via `Replace()`/`Remove()` during `Perform()`, so
  `GetContext()->History()` is complete and native — no manual walk needed.
- **Healing** (`healed`) — `ShapeFix_Shape::Init` auto-creates its `ShapeBuild_ReShape` context, so
  `Context()->History()` is likewise safe and complete without an explicit `SetContext()` call.
- **Solid from shell** (`solid(from:)`) — the one case that's the mirror image: `BRepBuilderAPI_MakeSolid`
  genuinely fits the template-synthesis path, but wrapping an already-closed shell into a solid doesn't
  modify any sub-shape, so that path would report nothing. The real history source is the
  `ShapeFix_Solid` orientation-fix pass — and unlike `ShapeFix_Shape`, `ShapeFix_Solid::Init` does
  **not** auto-create a context (verified in `occt-src`), so the bridge now calls
  `SetContext(new ShapeBuild_ReShape)` explicitly before `Perform()`.
- **Quilting** — `BRepTools_Quilt` has no `ReShape` context and no `Modified`/`Generated`/`IsDeleted`,
  only single-shape `IsCopied()`/`Copy()`, so this is the one manual per-subshape walk in the group.

**Faithfulness question answered:** the issue asked whether sewing's many-to-one merges (two coincident
input edges becoming one output edge — the *normal* case for sewing, not an edge case) are represented
cleanly. Confirmed by reading `BRepBuilderAPI_Sewing`'s vertex-merge code directly, and by a regression
test: **both merged inputs are recorded as Modified into the same output edge** — neither side is
silently dropped or marked Removed. `Shape.isSame(as:)` verifies the two records' outputs are the
identical edge.

**Not implemented: `Mesh.toShapeWithFullHistory`.** The issue's own open question floated this as a
possible answer, and it's the right one: `Mesh.toShape` builds every face from scratch out of raw
vertex/index arrays — there is no input `TopoDS_Shape` for `ShapeHistoryRef.record(of:)` to be called
with in the first place, so a `*WithFullHistory` variant would be a hollow stub that always returns
empty records. Identity for a mesh-to-B-Rep pipeline has to be established *after* the mesh-to-shape
step, not carried through it.

New suite `SewQuiltHealFullHistoryTests` (`OCCTModelingTests`), 9 tests. No kernel change, no
xcframework rebuild — reuses the v1.12.9 binary.

### v1.12.10 (July 2026): docs, BREP graph durable identity and UIDs cookbook

Docs only, no code change. Reuses the v1.12.9 binary (the binaryTarget URL is unchanged). Adds a new
cookbook, `docs/guides/cookbook/topology-graph-uids.md`, covering how UIDs are managed in the BREP
graph: the three durable-ID flavours (`GraphUID` / `GraphRefUID` / `GraphItemUID`), minting and
resolving, the one-graph-instance scope rule and `instanceID` / `graphID` provenance (#295), what
preserves identity (`copy` / `translated` / `compact`) versus mints a new one (`copyFace` / rebuild),
the deprecated always-1 `generation` counter, persistence, and how UIDs relate to history absorb
(#290). Cross-linked with the existing Topology Graph cookbook.

### v1.12.9 (July 2026) — carry three more upstream OCCT crash/hang fixes (#323)

**Not a bug we hit — a proactive audit.** Unlike #310/#317/#318, these three weren't discovered via
an OCCTSwift crash: #323 audited every OCCT PR merged or opened since our `V8_0_0_p1` baseline and
identified crash/hang fixes in code paths OCCTSwift exercises, per the `upstream-fixes-first` policy.
A fourth candidate from the same audit, OCCT#1380 (`ShapeFix_Face::FixPeriodicDegenerated`), turned
out to already be covered — it's our own patch `0005`, shipped for #317.

**`Scripts/patches/0007`** backports open (third-party) [OCCT#1331](https://github.com/Open-Cascade-SAS/OCCT/pull/1331), fixing [OCCT#1330](https://github.com/Open-Cascade-SAS/OCCT/issues/1330): `ShapeAnalysis_FreeBounds::connectWiresToWiresImpl` (the same helper `0004` patches for #310) left a stale `lwire` index when a skipped-loop candidate wire turned out to have zero edges — e.g. a wire wrapping a single internal-orientation edge — so the outer loop's `lwire == -1` termination check never fired and it read invalid memory. Validated by translating the upstream TCL test to C++: a closed triangle wire plus one internal-orientation edge SIGSEGVs 100% of the time on stock p1 + patches `0001`–`0006`, returns a valid wire after the patch.

**`Scripts/patches/0008`** backports merged [OCCT#1329](https://github.com/Open-Cascade-SAS/OCCT/pull/1329), fixing [OCCT#1288](https://github.com/Open-Cascade-SAS/OCCT/issues/1288) ("Boolean operation 'section' hangs-up for a pair of cylindrical shapes"): `Geom_BSplineCurve::PeriodicNormalization` used an O(N) `while`-loop to bring an out-of-range parameter into a periodic curve's range — a genuine infinite loop once the parameter's magnitude vastly exceeds the period (`Parameter -= Period` becomes a floating-point no-op). Rewritten to O(1). Validated: `PeriodicNormalization(1e17)` on a normal periodic curve (period ≈ 6.12) hangs indefinitely on stock p1 (wall-clock timeout) and returns instantly after the patch; a 9-case sanity sweep of in-range/near-boundary/several-periods-off values is byte-identical before and after.

**`Scripts/patches/0009`** backports open (maintainer) [OCCT#1318](https://github.com/Open-Cascade-SAS/OCCT/pull/1318): `StepData_StepWriter::AddString` looped forever writing a single unbroken raw string longer than the 72-character line buffer — no amount of flushing ever made room for text that can't fit in a full, empty line either. Fixed by splitting the token across as many lines as needed. Validated: a 200-character unbroken name via the public `StartEntity`/`SendString` path hangs indefinitely on stock p1 and returns instantly after the patch, correctly split across continuation lines with the text intact; normal-length fields are byte-identical before and after. New regression test `STEPWriterOversizedNameTests` (`OCCTIOTests`), reachable directly from `Shape.writeSTEP(to:name:)` with a >72-char name.

All three (and the existing `0001`–`0006`) verified via the fast override-link technique (patched `.o` linked ahead of `libOCCT-macos.a`, no full rebuild needed for validation) before committing to the xcframework rebuild. Two of the three are open, third-party or maintainer PRs — pinned to a specific commit SHA in each patch's header; re-verify if the PR changes in review before the next repin. **Binary release** — the xcframework changed, so `Package.swift` picks up the new URL + checksum.

- **Docs:** `CLAUDE.md`'s Known OCCT Bugs entry added for `0007`–`0009`; `Scripts/patches/README.md` and `okf/references/carried-occt-patches.md` document all three.

### v1.12.8 (July 2026) — fix: `Shape.analyze(tolerance:)` no longer crashes on a degenerate curve-on-surface edge (#318)

**Root cause.** `BRepGProp_EdgeTool::IntegrationOrder` — invoked from `BRepGProp::LinearProperties`, which backs `Shape.analyze(tolerance:)`'s small-edge scan — reads an edge's pole count to pick a numeric-integration order. For a Bezier/BSpline-type curve, it correctly identifies the type via `BAC.GetType()` (a `BRepAdaptor_Curve`, whose `GeomAdaptor_TransformedCurve::GetType()` override correctly handles the curve-on-surface case), but then re-derives the pole count by hand via a completely different, non-virtual path: `BAC.Curve().Curve()`, down-cast to `Geom_BezierCurve`/`Geom_BSplineCurve`. `BAC.Curve()` returns the base `GeomAdaptor_Curve` sub-object, which holds the 3D-curve representation only — never `Load()`ed when the edge has no 3D curve (only a curve-on-surface pcurve), so the handle is null, the down-cast returns null, and `->NbPoles()` dereferences it. This is exactly the shape of a degenerate edge `BRepBuilderAPI_Sewing` produces reconciling near-coincident vertices between two faces that don't share an edge outright — surfaced sewing two real mesh-derived planar candidate faces (`kof_ii_engine_cover.stl`, regions 10 + 64) via a diagnostic dump added to OCCTReconstruct's plane-select spike, then isolated with a custom `SIGSEGV` handler (`lldb`/core dumps unavailable in the diagnosing sandbox) that pinned the crash to `IntegrationOrder`. A from-scratch synthetic degenerate edge (`BRep_Builder` + a hand-built `Geom2d_BSplineCurve` pcurve on a plane, no 3D curve) reproduces the identical crash trace — the mechanism doesn't depend on the specific fixture.

**Fix — both layers.** Bridge (`OCCTShapeAnalyze`'s small-edge scan) now skips degenerate edges outright — closes the crash immediately, on any xcframework, and is also a correctness fix: a degenerate edge's zero 3D extent isn't a "small edge" defect to flag. Kernel patch also carried (`Scripts/patches/0006-BRepGProp_EdgeTool-use-adaptor-NbPoles-curve-on-surface-318.patch`, xcframework rebuilt): `IntegrationOrder` now calls the adaptor's own, correctly-dispatching `BAC.NbPoles()` (`GeomAdaptor_TransformedCurve` already has this override right next to `GetType()`) instead of manually re-deriving the pole count — no behaviour change for edges that do have a 3D curve.

**Verification.** The real sewn fixture and the synthetic degenerate edge both SIGSEGV 100% of the time on stock p1 and complete cleanly after the patch. New regression test `Issue318DegenerateCurveOnSurfaceEdgeTests` (`OCCTShapeHealingTests`), embedding the real sewn shape as a BREP fixture. Upstreamed as [Open-Cascade-SAS/OCCT#1381](https://github.com/Open-Cascade-SAS/OCCT/issues/1381) (repro) / [OCCT#1382](https://github.com/Open-Cascade-SAS/OCCT/pull/1382) (fix, with a GTest); the carried patch retires once it ships in the pinned kernel. **Binary release** — the xcframework changed, so `Package.swift` picks up the new URL + checksum; remote SPM consumers get the rebuilt binary.

- **Docs:** `CLAUDE.md`'s Known OCCT Bugs entry added for #318; `Scripts/patches/README.md` documents patch `0006`.

### v1.12.7 (July 2026) — fix: `Shape.face(from:boundary:)` no longer crashes on a single closed wire belting a cone (#317)

**Root cause.** `ShapeFix_Face::FixPeriodicDegenerated()` — invoked whenever a face's sole boundary wire is a single closed edge belting a `Geom_ConicalSurface`'s full 2π period, apex outside the wire's V range (a rivet/boss-rim seam fit as one periodic curve is the common source) — builds a degenerate apex edge and finalizes with an unconditional `Context()->Replace(myFace, myResult)`. Every *other* `Context()->Replace` call site in that OCCT source file — eleven of them — guards a null `Context()` first; this one didn't. `Context()` is left null by `ShapeFix_Root`'s base constructor and set only by an explicit `SetContext()` call, which the ordinary `ShapeFix_Face fixer(face); fixer.Perform();` (including ours, before this release) never makes — so any caller healing this exact wire shape null-derefs. Diagnosed with a custom `backtrace_symbols_fd` `SIGSEGV` handler (`lldb`/core dumps unavailable in the diagnosing sandbox) pinpointing the crash to `FixPeriodicDegenerated`; `-O0` single-TU override-link tracing confirmed every prior statement in the function completes and the fault is specifically that call. A standalone `wireFromEdges`-only repro is negative — the crash needs the wire trimmed to a periodic surface via `face(from:boundary:)`, which the original title's suspicion of `Wire.wireFromEdges` itself never exercised.

**Fix — both layers.** Bridge (`OCCTShapeCreateFaceFromSurfaceWire[WithHoles]`, `OCCTFaceFixerCreate`) now calls `fixer.SetContext(new ShapeBuild_ReShape)` before `Perform()` — closes the crash immediately, on any xcframework. Kernel patch also carried (`Scripts/patches/0005-ShapeFix_Face-guard-null-context-FixPeriodicDegenerated-317.patch`, xcframework rebuilt): restores the same `if (!Context().IsNull())` guard used at every other call site in the file.

**Verification.** A synthetic 8-point closed periodic curve edge trimmed to a cone, healed with a bare `ShapeFix_Face`, SIGSEGVs 100% of the time on stock p1 and survives (valid healed face) after the patch; a 10-point curve fit through real mesh-derived rivet-rim points (the fixture this was originally surfaced from, `railsim_581_lead.stl`) behaves identically. New regression test `Issue317PeriodicConicalSingleWireTests` (`OCCTSurfaceTests`). Upstreamed as [Open-Cascade-SAS/OCCT#1378](https://github.com/Open-Cascade-SAS/OCCT/issues/1378) (repro) / [OCCT#1380](https://github.com/Open-Cascade-SAS/OCCT/pull/1380) (fix, with a GTest); the carried patch retires once it ships in the pinned kernel. **Binary release** — the xcframework changed, so `Package.swift` picks up the new URL + checksum; remote SPM consumers get the rebuilt binary.

- **Docs:** `CLAUDE.md`'s Known OCCT Bugs entry added for #317; `Scripts/patches/README.md` documents patch `0005`.

### v1.12.6 (July 2026) — fix: `ShapeAnalysis_FreeBounds` no longer crashes on disjoint free-boundary components (#310)

**The real fix lands in the kernel.** v1.12.5 documented the crash risk in `freeBoundsClosedWires`/`freeBoundsClosedCount`/`freeBoundsOpenWires` (and, it turns out, `freeBounds` too — same underlying constructor) because no reliable guard existed at the wrapper level. This release removes the risk entirely.

**Root cause (found with AddressSanitizer).** `ShapeAnalysis_FreeBounds::SplitWire` finds each wire's closed sub-loops, then hands whatever edges weren't consumed to `ConnectEdgesToWires` to chain into the "open" result. When a wire's edges are **entirely** consumed by closed-loop detection, that hand-off is an empty (but non-null) sequence. The call chain `ConnectEdgesToWires` → `ConnectWiresToWires` → `connectWiresToWiresImpl` starts with `if (iwires.IsNull() || !iwires->Length()) { return; }` — for empty input this returns **without ever assigning its `owires` out-parameter**. Every caller in the file starts from a freshly-defaulted (null) handle, so the null propagates back through `SplitWire`'s `open` parameter into `ShapeAnalysis_FreeBounds::SplitWires`'s `open->Append(tmpopen)`, dereferencing a null handle — an uncatchable SIGSEGV. Not a data-volume threshold: it depends only on whether *any* single free-boundary component happens to close with nothing left over, so a shape with 150+ loops can be fine while a 2-loop shape crashes (and vice versa) — which is exactly why the #310 report's own minimization (150-face fixture, sew ladder) came up empty while the real trigger, one call later in the pipeline, was easy to hit.

**Fix.** `Scripts/patches/0004-ShapeAnalysis_FreeBounds-init-owires-empty-input-310.patch`: the one-line contract restoration `connectWiresToWiresImpl`'s own non-empty path already follows a few lines down (`owires = new NCollection_HSequence<TopoDS_Shape>;` before populating it) — "nothing to connect" now produces a valid **empty** result instead of an untouched out-parameter. The xcframework was rebuilt with the patch.

**Verification.** AddressSanitizer (macOS arm64, `ModelingAlgorithms`+`ModelingData`+`FoundationClasses`, `RelWithDebInfo`, `MMGT_OPT=0`): two disjoint planar faces in one compound crashed 100% of the time on stock p1 — same function, same `NCollection_Sequence::Append` call, same `0xfffffffffffffff8` fault address at both `-O2` and `-O0` — and now returns the correct `2 closed, 0 open`. On the real #310 fixture (150-face analytic compound): `tol=0.05` gives `152 closed/0 open` byte-identical before and after (no behavior change on the working path); `tol=0.10` crashed on stock p1 and now returns `144 closed/0 open`. New regression test `issue310DisjointFacesFreeBounds` (`OCCTShapeHealingTests`). Upstreamed as [Open-Cascade-SAS/OCCT#1377](https://github.com/Open-Cascade-SAS/OCCT/pull/1377) (with a GTest), superseding the repro-only [OCCT#1376](https://github.com/Open-Cascade-SAS/OCCT/issues/1376); the carried patch is retired once it ships in the pinned kernel. **Binary release** — the xcframework changed, so `Package.swift` picks up the new URL + checksum; remote SPM consumers get the rebuilt binary.

- **Docs:** removed the now-obsolete "can crash" warnings from `freeBoundsClosedWires`/`freeBoundsClosedCount`/`freeBoundsOpenWires` (doc comments + `docs/reference/Document-Analysis-Builders.md`); `CLAUDE.md`'s Known OCCT Bugs entry updated to record the fix.

### v1.12.5 (July 2026) — docs: correct #310's crash diagnosis + `isSelfIntersecting(timeout:)` cooperative-bound wording (#310, #293)

**PATCH — docs only, no code change.** #310 reported `Shape.sew`/`.healed()`/`.fixed(tolerance:)`
SIGSEGV-ing on a loose analytic-face compound, reproducing in a full pipeline but not via a standalone
BREP replay. Investigation found the original diagnosis was off on two points, and root-caused the
real defect:

- **Not `Shape.sew`/`.healed()`/`.fixed()`.** The crash is one call later: `Shape.freeBoundsClosedWires`/
  `freeBoundsClosedCount` (`ShapeAnalysis_FreeBounds`), called by the reporting pipeline immediately
  after a successful `sew` to print the free-boundary loop count. It only *looked* like the next `sew`
  call because that's the next thing that runs.
- **Not process-state-dependent.** The standalone probe that failed to reproduce it never called
  `freeBoundsClosedWires`/`freeBoundsClosedCount` — it only replayed `sew`/`healed`/`fixed`, so it never
  exercised the crashing function. Confirmed in pure C++ (no OCCTSwift) against the exact committed
  fixture, and reduced further to two disjoint planar faces in one compound with no shared geometry at
  all — not data-volume-dependent either (a shape with 150+ free-boundary loops can be fine while a
  2-loop shape crashes).
- **Root cause** (via a `-O0` single-TU override-link of `ShapeAnalysis_FreeBounds.cxx`, same technique
  as #263): the uncatchable SIGSEGV is inside `NCollection_HSequence<TopoDS_Shape>::Append`, called
  from `SplitWires`'s per-wire result accumulation, with a valid (non-null) target handle — consistent
  with heap corruption originating earlier in the same function rather than a null-handle deref at the
  `Append` site. Not covered by the #298 fillet patch (checked: neither the sew/heal/fix path nor
  `ShapeAnalysis_FreeBounds` reference `TopOpeBRepBuild`/`BlendFunc`), and not a concurrency bug (the
  reporting ladder is single-threaded).

**Fix.** No wrapper-side guard is possible yet — there's no reliable predicate distinguishing safe
input from crashing input, so a defensive check would either miss the real trigger or reject valid
shapes. Documented the crash risk on `freeBoundsClosedWires`/`freeBoundsClosedCount`/`freeBoundsOpenWires`
(doc comments + `docs/reference/Document-Analysis-Builders.md` + `CLAUDE.md`'s Known OCCT Bugs list).
Filed upstream as [Open-Cascade-SAS/OCCT#1376](https://github.com/Open-Cascade-SAS/OCCT/issues/1376)
with both a minimal 2-face repro and the real-fixture repro; possibly related to the still-open
[OCCT#1330](https://github.com/Open-Cascade-SAS/OCCT/issues/1330) (a different function in the same
file, same "re-chaining free-boundary components" symptom family).

**Also in this release (#293) — `isSelfIntersecting(timeout:)`'s bound is cooperative, not a hard
deadline.** `Shape.isSelfIntersecting(timeout:)` documented its `timeout` as a wall-clock bound, but
the mechanism (`OCCTBoolTimeoutBreaker`, a `Message_ProgressIndicator` whose `UserBreak()` trips past
the deadline) can only fire when the running OCCT algorithm *polls* — `BOPAlgo_ArgumentAnalyzer`'s
self-interference phase has at least one long checkpoint-free stretch (observed 20+ minutes past a
30s bound on a pathological B-spline solid), during which the calling thread is blocked inside the
call with no way to return early. The boolean ops' own timeout (#206) is unaffected — their polled
path is verified to interrupt correctly; this is specific to the self-interference check. Corrected
the doc comment (`Shape.swift`), `docs/reference/Shape-Features.md`, and
`docs/guides/cookbook/healing-and-validity.md` to state the bound is cooperative and can overrun
arbitrarily in an un-polled phase, with process-level isolation as the only true hard bound. No API
or behavior change.

### v1.12.4 (July 2026) — fix: `drilled` honours its direction; `face(outer:holes:)` respects hole winding; docs audit made type-aware

Two behaviour bugfixes and a documentation-coverage pass. No public API change (derived operation count unchanged at 4,241).

**`drilled(at:direction:radius:depth:)` now bores along `direction` (#272).** The bridge built the drill cutter via a +Z-hardcoded cylinder (`OCCTShapeCreateCylinderAt`), so drilling along any non-Z axis silently bored straight up Z — often removing nothing when the repositioned base fell outside the shape. It now uses `OCCTShapeCreateCylinderOriented`, whose `gp_Ax2(entryPoint, direction)` orients the bore along the requested (normalized) axis; a zero-length direction returns `nil`.

**`face(outer:holes:)` no longer double-flips an already-opposite hole (#274).** Every hole wire was reversed unconditionally before `BRepBuilderAPI_MakeFace.Add` — but `Add` does not normalise hole orientation, so a hole passed already wound opposite the outer (the correct winding) was flipped back to *wrong*, yielding an invalid face or an added-instead-of-subtracted hole. Reversal is now conditional: the outer's plane is found, an arc-aware signed area decides each wire's winding, and a hole is reversed only when it winds the *same* way as the outer. Per-hole, so mixed-winding hole sets work too; falls back to the legacy reverse when no plane can be determined.

**`Scripts/count-operations.py --audit` is now type-aware (#294).** The old matcher compared a counted entry point's bare name against doc headings with no notion of the owning type, so it over-reported generic names (`get`, `cols`, `z`, …) that *were* documented, and missed multi-symbol headings (`` ### `isCylinder`, `isCone`, `isSphere` ``) entirely — capturing only the first name. Of the 37 it flagged, **26 were false positives**; the matcher now carries a `Type.name` identity on both sides and parses multi-span headings. The **11 genuine gaps** (oriented bounding box, `OSD_Environment` accessors, and `LocalizedError.errorDescription` on seven error enums) are now documented — `--audit` reports **0**.

### v1.12.3 (July 2026) — fix: concurrent fillet/chamfer fixed in the kernel; serialization lock removed (#298)

**The real fix for #298 lands in the pinned OCCT, and the interim bridge lock is gone — concurrent fillet/chamfer run in parallel again.** v1.12.1 stopped the corruption by serialising every 3D fillet/chamfer build behind a bridge mutex (`occtFilletMutex`); that was correct but cost the parallelism. This release fixes the root cause in the kernel and drops the lock.

**Root cause (found with ThreadSanitizer).** `BRepFilletAPI_MakeFillet` reconstructs its result solid through OCCT's legacy `TopOpeBRepBuild` boolean engine (`ChFi3d_Builder::Compute` → `TopOpeBRepBuild_HBuilder::MergeSolid` → `TopOpeBRepBuild_Builder::SplitSolid`), which passed state between methods through a file-scope `static`, `STATIC_SOLIDINDEX`: `SplitSolid` sets it to 1/2 to tell `FillSolid` which operand it is splitting, and `FillSolid` reads it back to pick the operand shape. Two fillet builds on independent shapes on separate threads clobbered each other's flag, so `FillSolid` mis-classified faces and returned a wrong-but-plausible solid (one solid, positive volume, fails `BRepCheck`). This is *not* the `BlendFunc` scratch the v1.12.1 notes first suspected — those statics do race, but benignly; `STATIC_SOLIDINDEX` alone accounts for the corruption.

**Fix.** `Scripts/patches/0003-TopOpeBRep-non-reentrant-globals-fillet-298.patch` converts the fillet-path statics to `thread_local` (each thread keeps its own copy; single-thread behaviour is unchanged): `STATIC_SOLIDINDEX` and `STATIC_lastVPind` (functional), plus the `BlendFunc_ConstRad`/`EvolRad` and `ChFi3d_Builder` `checkcurve` scratch (benign, converted so the path is TSan-clean). The xcframework was rebuilt with the patch, so the kernel is reentrant and the `occtFilletMutex` guard (16 bridge call sites) was removed. Upstreamed as [Open-Cascade-SAS/OCCT#1374](https://github.com/Open-Cascade-SAS/OCCT/pull/1374); the carried patch is retired once it ships in the pinned kernel.

**Verification.** Pure-C++ 8-thread stress: 0/1600 concurrent fillet builds invalid with a single correct volume (was ~15–20% corrupt), and ThreadSanitizer reports the fillet path clean. `Issue298FilletThreadSafetyTests` now passes with the lock removed. **Binary release** — the xcframework changed, so `Package.swift` picks up the new URL + checksum; remote SPM consumers get the rebuilt binary.

### v1.12.2 (July 2026) — fix: graph construction now runs OCCT's `Clear()` rebuild boundary (#303)

**Every graph OCCTSwift built reported `generation == 0` and an all-zero `GraphGUID`.** The bridge
built a graph with the constructor plus `Shapes().Add(shape)`, and never called `BRepGraph::Clear()`
— which upstream treats as *the* rebuild boundary (PR #1237) and is the only call that stamps a
graph's identity (`IncrementGeneration()` + `SetGraphGUID(random)`). Skipping it left the kernel's
own version-stamp machinery unarmed on our path: `GraphGUID` stayed the default all-zeros, so
`BRepGraph_VersionStamp::ToGUID` — documented as making per-node GUIDs *"globally unique across
different graph instances"* — would have hashed in the zero GUID and returned identical GUIDs for
different graphs. Nothing user-visible broke (none of `GraphGUID` / `StampOf` / `IsStale` / `ToGUID`
is wrapped), but it was a live trap for whoever wraps that surface next.

Surfaced while fixing #295, and verified independent of it: giving graphs real GUIDs does **not** stop
a foreign UID resolving, because `BRepGraph_UID` is `(Kind, Counter)` and carries no GUID for
`NodeIdFrom` to compare. #295's `instanceID` provenance check is still needed and unchanged.

**Fix.** `OCCTBRepGraphCreate` and `OCCTBRepGraphCopyFace` now call `graph.Clear()` before ingesting
the shape, matching upstream's declared lifecycle. `copy()` / `translated()` deliberately do not:
`BRepGraph_Copy`/`_Transform::Perform` transplant the source's whole identity (generation + GUID)
into the target, so a pre-`Clear()` would just be overwritten — the inheritance is what we want.
`copyFace()` does get a `Clear()`: it is a fresh build with counters restarting at 1, and
ground truth on the pinned 8.0.0p1 kernel confirms `CopyNode` does **not** transplant the source
GUID, so the fresh stamp survives and matches the graph's fresh `instanceID`.

**Verified safe first** (the issue's load-bearing unknown): `Clear()` calls
`LayerRegistry::ClearAll()`, which the header documents as clearing layer data *"without
unregistering services"* — so the `BRepGraph_LayerHistory` layer the constructor registers, which
#290's `add(_:absorbing:…)` depends on, survives. Ground-truth-confirmed against the pinned kernel:
after `Clear()`-then-`Add()`, the history layer is still registered and recording works; the #290
history-absorb suite and the #295 provenance suite both stay green.

- **Changed:** `TopologyGraph.generation` is now a constant **1** (was 0). Still deprecated and still
  useless as identity — it is the same 1 for every graph. Use `instanceID` to compare graph identity.

### v1.12.1 (July 2026) — fix: concurrent 3D fillet/chamfer builds no longer corrupt each other (#298)

**Filleting a shape on two threads at once returned wrong-but-plausible geometry.** Reported as
`SheetMetal.Builder.build` returning an invalid solid under parallel test execution (~8 of 10 runs),
but the root cause is upstream and independent of the wrapper. `BRepFilletAPI_MakeFillet`'s
constant- and evolutive-radius blend solvers (`BlendFunc_ConstRad`, `BlendFunc_EvolRad`) and the
shared `ChFi3d_Builder` curve checker keep their geometric work variables in function-local
`static`s — process-global state, "to avoid systematic reallocation". Two threads filleting at once
interleave writes to those statics, the solver converges on a corrupted surface, and the result is a
solid with one shell and a positive volume that nonetheless fails `BRepCheck` — silent bad geometry,
not a crash and not a thrown error.

Reproduced in **pure OCCT with no OCCTSwift code involved**: a fuse-then-fillet on eight threads
produced BRepCheck-invalid solids with volumes scattered across several wrong values, while the same
build on one thread was bit-for-bit deterministic and correct. A plain box fillet (which takes OCCT's
analytic `ChFiKPart` fast path, not the numerical blend) is unaffected; only filleting a boolean
result, which needs the general path, trips it.

The issue's own diagnosis was corrected on three points: the result is *not* an empty shape (so the
suggested "reject empty results" guard would not have caught it), the boolean is *not* implicated
(the fuse is thread-safe and returns the correct shape every time), and it is unrelated to the
NCollection arm64 SEGV.

**Fix.** The bridge now serialises every 3D fillet and chamfer build under a dedicated recursive
mutex (`occtFilletMutex`), distinct from `OCCTSerial`. Fillet/chamfer are now always safe to call
concurrently with no caller-side lock; booleans, meshing, sweeps, and everything else stay fully
parallel — only fillet/chamfer builds serialise against each other. 2D fillets
(`BRepFilletAPI_MakeFillet2d`, the analytic `ChFi2d` toolkit) have no such statics and are not
guarded. Verified: the originally-failing `OCCTMiscTests` target passes 8/8 parallel runs, and a new
`Issue298FilletThreadSafetyTests` regression fails reliably without the lock and passes with it.

This is a mitigation. The permanent fix de-statics the work variables in OCCT itself so the lock can
be dropped and fillet/chamfer become genuinely parallel — tracked as a follow-up `occt-src` patch
and an upstream report. See `docs/thread-safety.md` for the full write-up.

### v1.12.0 (July 2026) — fix: a `GraphUID` no longer resolves against a graph that didn't mint it (#295)

**`node(forUID:)` returned a wrong node instead of `nil` for a UID from an unrelated graph.**
`GraphUID` carried no graph identity: it is a `(kind, counter)` pair, and every `TopologyGraph`
allocates counters from 1 independently. A UID minted from a box therefore landed inside a cylinder
graph's valid counter range and resolved cleanly — to an unrelated face. `contains(uid:)` returned
`true`. No error, no `nil`, just a plausible wrong answer:

```swift
let boxUID = boxGraph.uid(ofNodeKind: 2, index: 2)!   // a face of the BOX
cylGraph.node(forUID: boxUID)     // was: Optional((kind: 2, index: 2))  — now: nil
cylGraph.contains(uid: boxUID)    // was: true                           — now: false
```

The documented safeguard could never have caught it. `generation` is a **constant 0**, and the
staleness recipe the docs gave compared it against `storedOwnGen`, a per-entity mesh field that was
never the same counter.

**Fix.** Every graph carries an `instanceID`, and every UID it mints records it as `graphID`.
`node(forUID:)` / `contains(uid:)` / `ref(forUID:)` / `item(forUID:)` reject a UID from any other
graph. The id follows the same lifecycle rules as OCCT's own graph identity (`GraphGUID`), which
OCCTSwift cannot read because the kernel only populates it in `BRepGraph::Clear()` — a call our build
path skips (see #303).

**Identity follows the kernel's rule** — whether an operation transplants the UID counter space:

| Operation | Identity | UIDs |
|---|---|---|
| `compact()`, node removal, `add(_:absorbing:…)` | same instance | keep resolving |
| `copy()`, `translated()` | inherited | keep resolving, naming the same nodes |
| `copyFace()` | fresh | source UIDs now return `nil` (they returned a **wrong face** before) |
| a new graph over any shape, incl. a rebuild | fresh | source UIDs now return `nil` |

`copy()` and `translated()` are **unaffected**: `BRepGraph_Copy`/`_Transform::Perform` transplant the
counter space, Generation and GraphGUID into the target, so a copy genuinely is the same identity and
every source UID resolves to the same node. Only `copyFace()` — which lifts one face into an empty
graph, restarting counters at 1 — aliased, and it is now rejected.

- **New:** `TopologyGraph.instanceID`; `graphID` on `GraphUID`, `GraphRefUID`, `GraphItemUID`.
- **Deprecated:** `TopologyGraph.generation` — always 0, guards nothing. Also the hand-built
  `GraphUID(kind:counter:)` initializers: a UID with no provenance resolves in no graph, so mint them
  with `uid(ofNodeKind:index:)`.
- **Immutable fields:** `kind` / `counter` / `domain` are now `let`. A mutable counter beside an
  immutable `graphID` let a caller forge provenance — mutate a minted UID's counter and it would
  resolve to an arbitrary node, the exact bug this release closes. Mutating a UID was never coherent
  and no code in the ecosystem did it, but this is technically source-breaking for anyone who did.
- **Persistence:** a UID does not survive a rebuild, and never legitimately did — it only appeared to,
  because rebuilding the same shape re-allocates counters identically, with nothing checking it was
  the same shape. Store `(kind, index)` with the shape and re-mint after rebuilding. This matches
  OCCT's model, where a UID is an anchor into a *persisted graph model*; OCCT does not yet expose a
  graph serializer, and its `GraphGUID` is regenerated on every rebuild by design.
- **Codable:** payloads written before this release have no `graphID` and decode as unstamped
  (`graphID == 0`), which resolves nowhere rather than failing the load.
- **Equality:** `graphID` participates in `Hashable`/`Equatable`, so UIDs from unrelated graphs no
  longer compare equal or collapse together in a `Set`. Within one graph (and across a copy),
  equality is unchanged.

Unchanged: a UID still survives compaction and node removal within its own graph — that is what it is
for, and it is now the property the tests actually check. The previous `foreignUIDDoesNotResolve` test
only fabricated an *out-of-range* counter, which the reverse-index rejected anyway; a genuinely
foreign UID is in-range. Surfaced while investigating #290.
### v1.11.3 (July 2026) — fix: robust importers silently dropped all but the first body (#302)

**A multibody file lost every body after the first.** Ten boxes in, one box out — no error, no
diagnostic, and a perfectly valid solid returned. Found while sweeping the robust import paths for
#300; it is a data-loss defect rather than a progress one, so it was filed and fixed separately.

Every robust importer sewed and then took **the first shell only**:

```cpp
TopExp_Explorer shellExp(sewedShape, TopAbs_SHELL);
if (shellExp.More()) {                                    // <-- first shell, no loop
    BRepBuilderAPI_MakeSolid makeSolid(TopoDS::Shell(shellExp.Current()));
    if (makeSolid.IsDone()) resultShape = makeSolid.Solid();
}
```

Measured on a 10-box compound (10 solids, 60 faces), through the public API:

| API | before | after |
|---|---|---|
| `Shape.loadRobust` (STEP) | 1 solid, 6 faces | **10 solids, 60 faces** |
| `Shape.loadSTLRobust` | 1 solid, 12 faces | **10 solids** |
| `Shape.loadWithDiagnostics` | 1 solid, 6 faces | **10 solids**, `solidsCreated == 10` |

The sewing was never at fault — `BRepBuilderAPI_Sewing` returns one shell per body, and the bridge
discarded nine of them. `Shape.load` / `loadSTL` (the plain loaders) were never affected, and
`loadIGESRobust` is not either: the IGES path only transfers and heals, so it has no `MakeSolid`
step to truncate.

**Behaviour change — the return type now follows the file.** A multibody import returns a
**compound of solids**; a single-body import still returns a plain **solid**, exactly as before, so
existing single-body callers are untouched. Callers that handle both must not assume `.solid`.

**`ImportResult.solidsCreated: Int`** (new) reports how many shells became solids, alongside the
existing `solidCreated: Bool`. The count is precisely the fact that was silently wrong.

Shells that `MakeSolid` rejects are now carried through as shells rather than dropped — losing them
quietly is the defect being fixed.

The fix walks a compound's **immediate children** rather than exploring for shells, because an
explorer descends *into* solids: a hollow body owns an outer shell plus one per void, and
solidifying those separately would split one body into two — trading data loss for corruption. A
regression test covers it (a box with an internal spherical void survives with both shells and its
exact volume).

Regression tests assert on **body count**, not validity. That distinction is the point: a truncated
import returned a well-formed solid and `isValid` was true throughout, which is why this shipped
unnoticed. Same lesson as #286/#300 — assert the property that was actually broken.

### v1.11.2 (July 2026) — fix: robust-import healing ran outside the caller's progress range (#300)

**`Shape.loadIGESRobust` now honours a deadline during healing.** The sweep of the remaining
`*Progress` entry points that #299 called for found the #286 *constructor* pattern does not recur —
the other entry points all hand the range to a range-taking method. But it found the same *family* of
defect: `OCCTImportIGESRobustProgress` gave `TransferRoots` the entire `Message_ProgressRange` and
then ran `ShapeFix_Shape::Perform()` with **no range at all**. Healing is not a coda to a robust
import — measured at **38–50%** of transfer+heal across box/sphere/cylinder/torus compounds — so a
caller's deadline could not bound roughly half the call. `shouldCancel()` returning `true` during
healing was ignored entirely: the heal ran to completion and the import returned a **shape** rather
than reporting cancellation.

Fixed with a `Message_ProgressScope` subdividing the range: transfer takes `fraction` 0…0.5, healing
0.5…1.0. **This changes the reported `fraction` curve** — transfer previously spanned 0…1.0 and then
the import paused silently and uncancellably. The even split is what the measurements support, not a
guess; and because the scope closes out on destruction, `fraction` still reaches 1.0. Wiring a live
range into healing costs nothing measurable (−4.7%, i.e. noise, over 3 reps).

`ShapeFix_Shape::Perform(range)` and `BRepBuilderAPI_Sewing::Perform(range)` were both verified to
*honour* the break, not merely poll it — 1.85 s full heal vs 0.005 s cancelled, and a mid-flight
deadline interrupted at 0.478 s against a 0.463 s budget. Since the abort leaves a partially-healed
shape behind, the bridge now reports cancellation rather than handing that back.

The regression test asserts on **elapsed time** with the deadline set *past* the transfer, so it
lands inside healing — the part that was unreachable. Confirmed to fail against the old bridge:
*"loadIGESRobust returned a shape instead of cancelling"*. A cancel triggered on reported `fraction`
would have been a false negative: under the old bridge the transfer alone spanned 0…1.0, so any
fraction-based trigger fired while the transfer was still running and cancelled correctly even with
the bug present.

**`Shape.loadRobust` gains a `progress:` channel** (new API). `OCCTImportSTEPRobustProgress` had the
identical defect, and was fixed identically (transfer/sew/heal, with sewing taking a thin slice of the
repair half since it costs ~1% of what healing does) — but no Swift API reached it: `loadRobust` called
the non-progress bridge variant, so a robust STEP import could not be observed or cancelled **at all**.
It now routes through the progress-capable variant, mirroring its `loadIGESRobust` sibling:

```swift
let shape = try Shape.loadRobust(from: stepURL, progress: Deadline())
```

Source-compatible — `progress` defaults to `nil`, so existing `loadRobust(from:)` call sites are
unaffected. The one visible change is the failure message for the URL overload, which now carries the
full path rather than the last component (it delegates to the path overload, as `loadIGESRobust` does).

Exposing it is also what makes the STEP path **testable**: the new regression test drives it through a
convex N-gon prism, which imports as a single many-faced *solid* and so takes the SOLID branch, where
repair is ~50% of the work. That share is load-bearing — on a *compound* the same import spends only
~6% in repair, so a deadline would land in the transfer, which was already cancellable, and the test
would pass with the bug present. Confirmed to fail against an unfixed repair phase: *"loadRobust
returned a shape instead of cancelling"*.

Also in this release:
- **Docs corrected:** `loadIGESRobust` was documented as "sewing and healing". It has never called
  `BRepBuilderAPI_Sewing` — it only transfers and heals.
- **Documented OCCT limitation:** `IGESControl_Reader::ReadFile` takes no `Message_ProgressRange`
  (verified against the pinned `V8_0_0_p1` headers), so parsing happens *before* the indicator
  exists and can be neither reported nor cancelled. The same is true of `STEPControl_Reader::ReadFile`
  and the STEP/IGES writers. Stated rather than papered over, per the #286 lesson.
- **Redundant `Perform()` dropped** from `OCCTExportSTL`/`OCCTExportSTLWithMode`, whose constructor
  already meshes. Measured as redundant, *not* a 2× cost: 0.0003 s against a 1.29 s mesh.

### v1.11.1 (July 2026) — fix: `meshWithProgress` could never cancel; retract the #286 kernel story (#286)

**`Shape.meshWithProgress` now actually cancels.** The bridge used the
`BRepMesh_IncrementalMesh(shape, linDefl, isRelative, angDefl)` constructor, which calls `Perform()`
*internally* with a null `Message_ProgressRange`. The entire mesh was therefore built uninterruptibly
inside the constructor, before the range we passed to the following `Perform(range)` was ever polled —
and that second call meshed the shape a **second time**. Cancellation still *threw*, because
`UserBreak()` was checked afterwards, so the pre-existing test passed and the defect shipped. Fixed by
using the `IMeshTools_Parameters` + `Message_ProgressRange` constructor, the only one that consumes a
range. Meshing behaviour is otherwise unchanged: both constructors leave
`AngleInterior`/`MinSize`/`DeflectionInterior` at defaults, which `Perform()` resolves identically.

Measured on the #286 face (249 s to mesh in full): a 10 s deadline now throws `ImportError.cancelled`
after 10.1 s, having polled 154,898 times. Previously it ran past 400 s without cancelling.

**v1.10.2's account of #286 was wrong in every substantive claim, and is retracted.** Each was checked
by measuring or building it rather than by reading:

| Claim (v1.10.2) | Measured |
|---|---|
| `Shape.mesh` hangs unboundedly on offset surfaces | **Terminates in 249 s**, `status=0`, 1.4 M triangles. Earlier "hangs" were 120 s / 300 s timeouts set below that. |
| No in-process timeout can bound it — "measured, not inferred" | **A 10 s deadline returns in 10.1 s.** The "10 s cancel never fired" measurement was our own `meshWithProgress` bug, above — not an OCCT limitation. |
| Root cause is `BRepMesh_MeshAlgoFactory::GetAlgo` handing offsets a `BRepMesh_UndefinedRangeSplitter` | **Disproven by building it.** Routing `GeomAbs_OffsetSurface` to `BRepMesh_NURBSRangeSplitter` leaves the runtime identical. `getUndefinedIntervalNb()` is dead code here: `NbUIntervals(CN)` forwards to the basis adaptor and returns **11, not 1**, so the `if (aIntervalsNb == 1)` branch never runs and the two splitters behave identically. (`NbUPoles()` also *throws* `Standard_NoSuchObject` on an offset adaptor, so the proposed one-liner was unsafe regardless.) |
| The hang is in `BRepMesh_Delaun::createTrianglesOnNewVertices` | Stack samples put 100 % of time in `BRepMesh_DelaunayDeflectionControlMeshAlgo::optimizeMesh`. |

**Actual cause — invalid input, not an OCCT defect.** The offset surface is *self-intersecting*.
Offsetting by more than the local radius of curvature produces cusps: the #286 basis fit's minimum
principal curvature radius is `2.6e-05` against an offset of `1.27`, so **23.8 %** of its domain is
cusped and the surface normal swings by up to `π` across one. `BRepMesh` splits any triangle link whose
end normals differ by more than `AngleInterior` (= `2 × angularDeflection`), but at a normal
*discontinuity* splitting never converges — halving a link that straddles a cusp just moves the cusp
into one half. So `optimizeMesh` runs all 11 passes demanding ~80 k splits each, long after linear
deflection is satisfied (1.82 against a 2.48 target by pass 6, with linear splits at **zero** from pass
4); `MinSize` (= `linearDeflection / 10`) is the only backstop, rejecting ~200 k splits per pass.

**No upstream OCCT issue or patch is warranted** — retracting v1.10.2's "an upstream OCCT fix is being
attempted". No xcframework rebuild either: the binary is unchanged. A well-formed offset surface meshes
normally.

`Shape.mesh` and `Shape.meshWithProgress` docs and `docs/reference/Shape.md` rewritten against the
measurements, and the mitigation list now leads with the deadline that actually works. The `bounds`
pre-check remains the best first line of defence, and `isValid` still will not catch this (a
self-intersecting offset surface is a topologically valid face).

### v1.11.0 (July 2026) — feat: absorb a boolean's history into the graph, so a picked face survives it (#290)

Holding a reference to a picked face across an operation that rebuilds the shape had no supported
path. `ShapeHistoryRef` (TopoDS-level, from the `*WithFullHistory` helpers) and the `TopologyGraph`
history log were two disconnected systems: the boolean never wrote a record into the graph's log, so
`resolve(.splitOf(…))` / `.createdBy(…)` / `currentForms(of:)` had nothing to walk and callers were
left correlating `ShapeHistoryRecord.modified` back to graph nodes by hand — in practice by geometry.

OCCT 8.0.0p1 already ships the bridge; it was simply unwrapped.
`BRepGraph::ShapesView::AddWithHistory` collects the input map via `CollectHistoryInputs`, the output
map via `Options::TrackAddedNodes`, and hands both to `BRepGraph_LayerHistory::Absorb`.

**New**

- **`TopologyGraph.add(_:absorbing:inputRoots:operationName:)`** — add an operation's result to the
  graph and absorb its history. Afterwards the entities you already held resolve to their successors.
- **`TopologyGraph.historyIsDeleted(_:)`** / **`.historyDeletedNodes`** — distinguish "consumed by the
  operation" from "never touched". Absence of a record is not deletion.

```swift
let graph = TopologyGraph(shape: base)!
let root = graph.findNode(for: base)!               // topology root — NOT rootNodes (see below)
let topNode = graph.findNode(for: topFace)!         // pin the face BEFORE the cut
let pinned = TopologyGraph.NodeRef(kind: topNode.kind, index: topNode.index)

let (result, history) = base.subtractedWithFullHistory(tool)!
graph.add(result, absorbing: history,
          inputRoots: [TopologyGraph.NodeRef(kind: root.kind, index: root.index)],
          operationName: "channel-cut")

let strips = graph.currentForms(of: pinned).filter { $0.kind == .face }   // the two successors
graph.resolve(.splitOf(original: .literal(pinned), occurrence: 0))        // .success(face)
```

**One graph, not two.** `AddWithHistory` resolves its input roots against the *receiving* graph, so
the input and the result share one graph and history is NodeId-keyed. The `NodeRef`s and `GraphUID`s
a caller already holds stay valid: there is no generation boundary to cross and no cross-graph UID
resolution — which sidesteps the aliasing hazard in
[#295](https://github.com/SecondMouseAU/OCCTSwift/issues/295) entirely. Build the graph from the
operation's **input**, then hand it the result. The two-graph `Absorb` overload and the UID-keyed
record path (`RecordUid` / `HasKnownInput`) are deliberately left unwrapped: strictly more dangerous,
and no consumer.

**Works for all nine `*WithFullHistory` ops.** `OCCTBooleanHistoryAsBRepToolsHistory` synthesizes a
real `BRepTools_History` from the retained builder via the `(arguments, algo)` template constructor,
which needs only `Modified` / `Generated` / `IsDeleted` — all virtual on `BRepBuilderAPI_MakeShape`.
That matters because only the `BRepAlgoAPI_*` builders expose a native `History()`; fillet, chamfer
and thick-solid do not. `OCCTBooleanHistory` now retains its arguments, since a type-erased builder
cannot report its own inputs.

**Known edges, documented rather than papered over:**

- `currentForms(of:)` returns the cut's new section **edges** alongside the split faces, because
  `BRepGraph_LayerHistory::FindDerived` unions Modified and Generated descendants transitively.
  Filter by `.kind` when you want only faces. Existing behaviour, unchanged.
- Only **vertices, edges, faces and solids** are carried — `BRepTools_History::IsSupportedType`
  tracks nothing else, so absorbing records nothing for wires, shells or compounds.
- `TopologyGraph.rootNodes` is **Products**, and shape-built graphs set `CreateAutoProduct = false`,
  so it is always empty for them. The topology root is `findNode(for: inputShape)`. This trips people
  up; the reference page now says so.

### v1.10.3 (July 2026) — docs: canonical operation count, derived not hand-maintained (#289)

The headline operation count was stated in two places with **three numbers in play**: README said
4,313, `docs/API_REFERENCE.md`'s `Total` said 3,431, and that table's own 470 category rows summed to
3,320. Both headline figures were last written in the *same* commit, so at most one was ever right,
and both predated v1.10.0.

**Canonical rule, now written down** (`docs/API_REFERENCE.md` § How operations are counted):

> One row per distinct public Swift entry point; overloads counted separately.

An operation is any `public func`/`static func`, `public init`, `public var` **with an accessor
block**, or `public subscript` in the `OCCTSwift` module. Stored properties, types and enum cases are
data, not entry points, and are not counted. The derived count is **4,234**.

**Derived, not hand-maintained.** `Scripts/count-operations.py` computes it from source and rewrites
both figures (`--fix`), exiting 1 if they disagree — the drift class is now mechanically impossible.
`--audit` lists counted entry points with no reference page.

The 882 gap turned out to be exactly what #289 suspected: **two divergent methodologies.** README's
4,313 was ~the full entry-point surface (80 off today's derived 4,234 — stale, not wrong-in-kind),
while API_REFERENCE's rows are a curated *categorisation* covering 3,320 (~78%) of the surface. The
`Total` and the row sum were never measuring the same thing; the table now says so explicitly rather
than implying the rows should add up.

**Docs coverage audit** (the same pass): 39 counted entry points had no reference documentation. Two
were counted in API_REFERENCE's own example lists while being undocumented — `Shape.commonAll(_:)`
(Booleans) and `hollowed(removingFaces:thickness:tolerance:joinType:)` (Modifications) — both now
documented beside their siblings. The remaining 37 are tracked in #294.

### v1.10.2 (July 2026) — docs: `Shape.mesh` can hang unboundedly on offset surfaces (#286)

> **Retracted by v1.11.1.** Every substantive claim below is false: the mesh is not unbounded (249 s),
> cancellation *does* work (the failed 10 s deadline was our own bridge bug), and the splitter root
> cause was disproven by building the proposed fix. Kept for history; see v1.11.1.

Documentation only; no code change — because there is no correct in-process code change to make, and
saying so precisely is the useful output.

`Shape.mesh(linearDeflection:angularDeflection:)` can put OCCT's mesher into an effectively
non-terminating state on the `Geom_OffsetSurface` geometry that `shelled(thickness:)` / `offset(by:)`
produce. Reproduced standalone from a real fitted-then-offset B-spline panel: a **single face meshed
for >300 s without returning**, at a *coarse* deflection (2.48 against a 1583 bbox diagonal — 1/638).
A kernel pathology, not a workload cost.

**Root cause** (OCCT `V8_0_0_p1`): `BRepMesh_MeshAlgoFactory::GetAlgo` lumps `GeomAbs_OffsetSurface`
in with `GeomAbs_OtherSurface`, handing it a `BRepMesh_UndefinedRangeSplitter` whose
`getUndefinedIntervalNb()` returns a constant `1`. An offset surface therefore gets **no parametric
subdivision at all**, however wiggly its basis B-spline is, while that same B-spline meshed directly
gets `BRepMesh_NURBSRangeSplitter` (`NbUPoles()-1` intervals). The Delaunay insertion starts from a
near-empty grid and `BRepMesh_Delaun::createTrianglesOnNewVertices` blows up.

Two things this is **not**, both worth recording because both were the obvious first guesses:

- **Not fixable with a timeout — measured, not inferred.** `createTrianglesOnNewVertices` *does* poll
  (`aPS.More()`) in its outer per-vertex loop, but the hang is inside a single iteration, so the poll
  is never reached. A 10 s cancel deadline via `meshWithProgress` was measured **not to fire at all**
  (killed at 120 s). `meshWithProgress`'s docs previously implied a cancellation guarantee it cannot
  honour; they now state the checkpoint granularity explicitly.
- **Not catchable by a validity pre-check.** The offending solid reports `isValid == true`.

Mitigations documented on `mesh`, best first: sanity-check with `bounds` (a cheap `Bnd_Box` query, no
tessellation) before meshing untrusted offsets; `withSurfacesAsBSpline(offset: true)`, which converts
the offset surface to a plain B-spline and turns the hang into a bounded 125 s / 526 k verts — this
also explains *why* that mitigation works, since it routes the surface to the correct splitter (a
rescue path, not a default); or mesh out-of-process.

An upstream OCCT fix is being attempted against the root cause; see #286.

Well-formed offset solids are unaffected.

### v1.10.1 (July 2026) — OCCT rebuild carrying the #280 kernel fix; consumer builds are warning-free (#281)

**Rebuilt `OCCT.xcframework`** (all three slices) carrying a new carried patch,
`0002-STEPControl_Writer-initialize-missing-shape-processing-1334.patch` — a backport of upstream
[OCCT#1334](https://github.com/Open-Cascade-SAS/OCCT/pull/1334) (merged 2026-07-10), which lands after
our `V8_0_0_p1` pin (2026-06-16). This fixes [#280](https://github.com/SecondMouseAU/OCCTSwift/issues/280)
**in the kernel**, so the v1.9.2 bridge workaround (`repairSTEPWriterActor`, which installed a plain
controller on each of the 8 shape-level write paths) is **removed** — verified by deleting it and
confirming the regression test still passes against the rebuilt binary.

**Build warnings: 797 → 0** ([#281](https://github.com/SecondMouseAU/OCCTSwift/issues/281)).

- **684 `-Wdeprecated-declarations` → 0.** OCCT 8.0 deprecates its own legacy spellings
  (`Standard_True`, `Standard_Real`, `TopTools_*`, `TColStd_Array1Of*`, …) which this bridge still
  uses. Defining OCCT's own `OCCT_NO_DEPRECATED` opt-out on the `OCCTBridge` target silences exactly
  those attributes and nothing else. Deliberately a `.define` and not `.unsafeFlags` — SwiftPM rejects
  `unsafeFlags` in any package consumed as a dependency, which would break every downstream consumer.
  This buys quiet, not absolution: migrating the call sites off the legacy spellings is still tracked
  in #281.
- **23 `-Wshorten-64-to-32` → 0.** All 23 were the same shape — an `NCollection` container's
  `.Size()` (`size_t`) assigned to `int32_t`/`int`. Now explicit `static_cast`. To be clear, these were
  **not** latent bugs: unlike the `quantize()` Int32 overflow (OCCTSwiftViewport#30), a container with
  >2^31 elements is not reachable here. The casts document intent and stop the noise.
- **Swift hygiene.** Removed four dead bindings in `SheetMetal.swift` (`aOuter1`/`bOuter1`,
  `arcNormalCandidate`, `seamLength`) — each was leftover from a superseded approach that the
  surrounding comments already described, so the stale comments went too; none was an unfinished
  calculation. `Mesh.swift` `var`→`let`. Also fixed two warnings not listed in #281 that a cached build
  had been hiding: a deprecated `String(cString:)` in `BRepGraph.swift` (decoding now stops at the
  bridge's NUL terminator — `String(decoding:as:)` over the whole fixed 128-byte buffer would have
  carried the NUL padding into the string) and a deprecated `union(with:)` in `OCCTTest`.

Full suite: **4,359 tests, 0 failures.** Consumer builds inherit no warnings from this package.

Bumped **PATCH**: no public API change — a kernel rebuild, a workaround removal, and build hygiene.

### v1.10.0 (July 2026) — feat: `allEdgePolylinesIndexed` — bulk wireframe with pick identity (#275 follow-up)

`allEdgePolylines` is dense: when a degenerate/failed edge is skipped (a sphere's pole seams, a
scan's broken edge), every later polyline shifts down, so a polyline's position no longer equals its
edge index — consumers that round-trip wireframe back to topology (per-segment edge pick indices,
polyline → `TopoDS_Edge`) silently mis-map from the first skip onward.

**New:** `Shape.allEdgePolylinesIndexed(deflection:maxPointsPerEdge:) -> [(edgeIndex: Int, points:
[SIMD3<Double>])]` — the same single O(edges) bulk pass (#275), with each polyline carrying its
original `edgePolyline(at:)` / `edge(at:)` index. `allEdgePolylines` now delegates to it (`.map(\.points)`)
— dense output unchanged, byte-identical.

The first consumer is OCCTSwiftTools' `extractEdgePolylines` (the `shapeToBodyAndMetadata` wireframe
pass), whose per-index loop was the O(edges²) hot path that hung OCCTMCP's `render_preview` on
mesh-scale STL imports (OCCTMCP#75).

New test: sphere fixture proves indices survive a real skip (returned pairs match the per-index
accessor exactly; skipped indices are exactly those the per-index accessor rejects).

### v1.9.2 (July 2026) — fix: an XDE STEP read silently corrupted every later STEP write (#280)

Reading a STEP through `Document.loadSTEP` permanently corrupted every subsequent
`Exporter.writeSTEP` in the process. A cone frustum wrote as a **2-face solid missing its lateral
`CONICAL_SURFACE` and 63% of its volume** (408.407 → 151.844), still reporting `isValid == true`.
Read a STEP, write a STEP, geometry silently gone — an ordinary app sequence.

Upstream OCCT bug. `STEPCAFControl_Controller`'s constructor overwrites the actor its base class
just configured, without re-applying `SetShapeProcessFlags`, then `AutoRecord()`s itself under the
same `"STEP"` name the plain writer resolves by — and `STEPControl_Writer::SetWS()` unconditionally
re-runs `SelectNorm("STEP")`. So after any XDE read (a `STEPCAFControl_Reader` merely being
*constructed* is enough) every shape-level write ran with **empty** `OperationsFlags`:
`DirectFaces` never ran, and faces on indirect (left-handed) surfaces — a frustum's cone — were
dropped. That is why only the cone was affected; box/cylinder/sphere/torus have no indirect
surfaces.

Fixed upstream in OCCT PR #1334 (merged 2026-07-10), which added an `InitializeMissingParameters()`
call to `STEPControl_Writer::Transfer`. Our pinned **V8_0_0_p1** (tagged 2026-06-16) predates it —
it *defines* that method but never calls it, and it is `private`. The bridge therefore installs a
freshly-constructed plain controller on each shape-level write, restoring the flags the writer
should have had. Retire the workaround when the bundled OCCT moves past that commit.

This was also the cause of the long-standing `cone()` failure in `StressFormatRoundTripTests`, which
passed in isolation and failed in every full run purely because `OCCTIOTests` reads a STEP first. It
was never flaky — it was correctly reporting this bug. **The full suite is now green: 4,359 tests,
0 failures.**

Bumped **PATCH**: bug fix, no public API change.

### v1.9.1 (July 2026) — fix: a new Document could inherit a dead Document's construction context (#277)

`Document.constructionContext` is resolved through a side table keyed on `ObjectIdentifier(document)`
— the raw instance pointer, which is unique only among **live** objects. The entry was never removed
(a `clear(for:)` existed but was never wired to `Document.deinit`), so a context outlived its
document; the allocator then readily handed the same address to the next `Document`, which resolved
to the dead one's context and silently inherited its entities.

This was not a rare race. In a tight create/destroy loop **every** new `Document` reused the address
and accumulated its predecessors' entities monotonically (1 → 2 → 3 → …). It surfaced as an
intermittent failure in the `materializeAll()` test — 4 entities materialized where 3 were added — but
the same fault hits any app that creates and releases documents over its lifetime: fresh documents
silently carrying dead ones' construction geometry, plus an unbounded leak of every
`ConstructionContext` ever created.

`Document.deinit` now clears the association before the instance's memory can be recycled. No API
change — the documented guarantee (one context per `Document` instance, released with it) is simply
true now. `DocumentAssociatedStorage` carries a warning that owners must clear on `deinit`, since the
pattern silently reintroduces this if they don't.

Bumped **PATCH** per the cohort SemVer policy: bug fix, no public API change.

### v1.9.0 (July 2026) — perf: `allEdgePolylines` is O(edges), not O(edges²) (#275)

`Shape.allEdgePolylines` looped `edgePolyline(at:)`, and every one of those calls rebuilt the shape's
full `TopTools_IndexedMapOfShape` — so extracting a wireframe was quadratic in edge count. Measured on
a box compound: **12,288 edges went from 15.5 s to 0.017 s (~900x)**; 3,072 edges from 0.93 s to
0.004 s. The old cost curve made mesh-scale shapes effectively unusable (an STL lands one face per
facet, so a 442k-triangle scan is ~1.3M edges), which is what forced OCCTMCP to route around the
bridge in v1.13.0 (OCCTMCP#75/#77).

The bridge now discretises every edge in one pass, building the edge map once:

- **New C API** — `OCCTShapeComputeAllEdgePolylines(shape, deflection, maxPointsPerEdge)` returns an
  `OCCTEdgePolylinesRef` handle, read via `OCCTEdgePolylinesGetEdgeCount` / `…GetPointCount` /
  `…CopyPoints` and freed with `OCCTEdgePolylinesRelease`. Edge ordering matches
  `OCCTShapeGetTotalEdgeCount` / `OCCTShapeGetEdgePolyline`; failed/degenerate edges are retained as
  0-point entries so indices stay aligned with the shape's edge indices.
- The pcurve fallback's edge→face ancestor map is now also built at most once per call, instead of
  once per edge that needs it.

**No Swift API change.** `allEdgePolylines`' signature, ordering and skip-on-failure behaviour are
unchanged — output is byte-identical to the old per-index path (covered by a parity test over box and
cylinder), just dramatically faster. `edgePolyline(at:)` is unchanged and still rebuilds the map per
call; it is now documented as one-off-lookup only. Bumped **MINOR** per the cohort SemVer policy: new
C surface, additive.

This fixes the `allEdgePolylines` hot path only — the ~24 other per-index accessors (`edge(at:)`,
face/vertex variants) still rebuild their maps per call. Caching the map on `OCCTShape` with
mutation-invalidation is the structural fix, left open on #275.

### v1.8.8 (July 2026) — feat: close the face-analysis tail (#266 follow-up, 6 ops)

Wraps the five low-value leftovers from the post-v1.8.7 face-gap re-audit — the face surface is now
complete:

- **`BRepLProp_SLProps` V tangent** (`Shape.faceLPropTangentV`) — the tangent plane is now two-sided
  (was `TangentU`-only).
- **`BRepGProp_Face` integration internals** (`Shape`): `faceIntegrationKnotsV`, `faceSurfaceIntegration`
  (precision-driven Gauss order + U/V subinterval counts), `faceBoundaryIntegration(edgeIndex:)`
  (edge-loaded boundary order/subs/knots).
- **`ShapeFix_Face` tolerance clamps** (`FaceFixer`): `setMaxTolerance`, `setMinTolerance`.

Swift-only; no xcframework change. `BRepGProp_Face::GetTKnots` remains deliberately unwrapped
(needs a loaded boundary arc and is subsumed by `faceBoundaryIntegration`).

### v1.8.7 (June 2026) — feat: face healing & validation surface (#266 follow-up)

**New APIs (~16 ops).** Rounds out the face-analysis surface flagged by the coverage audit:

- **`ShapeFix_Face` per-pass control** (`FaceFixer`): `setMode(_:_:)` toggles any of the 11 healing
  passes (wire, orientation, **addNaturalBound**, missingSeam, smallAreaWire, removeSmallAreaFace,
  intersectingWires, loopWires, splitFace, autoCorrectPrecision, periodicDegenerated) before
  `perform()`; plus `fixIntersectingWires()`, `fixPeriodicDegenerated()`, `fixWiresTwoCoincEdges()`,
  `fixLoopWire()`, `result` (Face **or** Shell), and `status(_:)`. Previously `perform()` ran with
  hardcoded defaults — e.g. no way to turn off the natural-bound pass that can balloon a trimmed face.
- **`BRepCheck_Face` per-wire diagnostics** (`Shape`): `checkFaceIntersectingWires`,
  `checkFaceWireImbrication`, `checkFaceWireOrientation` — the specific `BRepCheck_Status` per check.
- **`ShapeAnalysis_Surface` extras** (`Surface`): `uvFromIso`, `singularity(_:)` (full pole/iso
  detail), `projectDegenerated`, and domain-restricted `projectPoint(_:uDomain:vDomain:)`.
- **`BRepGProp_Face`** (`Shape`): `faceIntegrationOrders`, `faceIntegrationKnotsU()`.

Swift-only; no xcframework change. The audit's "rebound a face on its own surface" and "3D point
classifier" candidates were verified **already wrapped** (`faceAddHole` and `OCCTClassifyPointOnFace`)
and not duplicated.

### v1.8.6 (June 2026) — feat: face-from-surface with interior holes (#266)

**New API.** `Shape.face(from: surface, outer: Wire, innerWires: [Wire])` builds a single trimmed
face that has **interior openings** (windows / cutouts) — a parametric surface trimmed by an outer
boundary with N inner-wire holes. Wraps `BRepBuilderAPI_MakeFace(surface, outer)` + `.Add(hole)` per
hole + `ShapeFix_Face` to project pcurves; hole winding is normalized automatically (tries holes
reversed, falls back to as-given, returns the valid build). Until now every face-from-surface builder
took a single outer loop, so a panel with holes couldn't be one trimmed face.

Motivating case: OCCTReconstruct carbody side-panel surfacing — a fitted B-spline panel with
window/door cutouts now surfaces cleanly instead of the surface ballooning over the windows
(SecondMouseAU/OCCTReconstruct #133). Swift-only; no xcframework change.

### v1.8.5 (June 2026) — chore: slim xcframework to the core slices (≈57% smaller download)

**Packaging only — identical kernel/source to v1.8.4.** The shipped `OCCT.xcframework` now contains
just the slices the ecosystem actually builds against — **macOS arm64, iOS arm64, iOS-arm64-simulator**
— dropping the visionOS and tvOS device/simulator slices. Result: download **344 MB → ~149 MB**,
extracted **~1.3 GB → ~594 MB**. Each shipped slice keeps its own `Headers/` (SwiftPM auto-exposes
per-slice headers to the C++ bridge — they cannot be de-duplicated to a single copy without breaking
remote/URL consumers), so the header reduction comes from shipping 3 slices instead of 7.

**Need visionOS / tvOS?** Rebuild the full set with `BUILD_ALL_PLATFORMS=1 Scripts/build-occt.sh`
(the package still declares those platforms). The build script defaults to the 3 core slices.

No API or behaviour change; the #263 ShapeFix kernel patch from v1.8.4 is retained.

### v1.8.4 (June 2026) — fix: OCCT kernel patch for ShapeFix_Face heap corruption (#263)

**Binary release.** Rebuilds `OCCT.xcframework` carrying a one-function OCCT source patch
(`Scripts/patches/0001-ShapeFix_Face-guard-non-face-context-replacement-263.patch`) that fixes the
upstream crash behind #263 at the kernel level.

`ShapeFix_Face::Perform` cast `Context()->Apply(myFace)` to `TopoDS_Face` without a type check; when
an earlier fix in the shared `ShapeBuild_ReShape` context had replaced the face with a compound (a
self-intersecting face split into several faces), the cast built an invalid face handle over a
compound `TShape` and corrupted the heap (`ShapeFix_Face::FixOrientation` → `BRep_Tool::Curve` →
`BRep_TEdge::EmptyCopy`, SIGSEGV/SIGBUS). The patch guards the entry of `Perform`: if the applied
shape is not a face, return — the replacement is already recorded in the context. Submitted upstream
as [Open-Cascade-SAS/OCCT#1323](https://github.com/Open-Cascade-SAS/OCCT/pull/1323) (CI green) and
will be dropped from `Scripts/patches/` once it ships in an OCCT release.

With this binary, a self-intersecting prism now *heals to a valid solid* instead of crashing; the
v1.8.3 in-wrapper `occtHasSelfIntersectingWire` guard remains as defence-in-depth. **xcframework
rebuilt** — remote SPM consumers get the new binary via the bumped `Package.swift` URL + checksum.

### v1.8.3 (June 2026) — fix: guard prism/heal against self-intersecting profiles (#263)

**Bug fix.** A self-intersecting mesh-derived outline (`BRepCheck` `SelfIntersectingWire`) extruded
into a prism and then healed by OCCT's `ShapeFix_Shape` corrupts the heap and aborts the process with
an uncatchable OS signal — the exact #263 fault (`ShapeFix_Face::FixOrientation` → `BRep_Tool::Curve`
→ `BRep_TEdge::EmptyCopy`). Isolated to a **pure-OCCT** reproducer (a 4-point "bowtie" face: extrude
succeeds, healing the prism crashes 3/3) and reported upstream as
[Open-Cascade-SAS/OCCT#1322](https://github.com/Open-Cascade-SAS/OCCT/issues/1322).

`OCC_CATCH_SIGNALS` is inert in this build, so the signal cannot be caught once raised. The fix
**prevents** it: a cheap, no-meshing `BRepCheck_Analyzer` guard (`occtHasSelfIntersectingWire`) makes
`Shape.extrude` / `Shape.extruded(by:)` / `Shape.healed()` return `nil` for a self-intersecting
profile instead of building/healing the crashing solid (such a profile can never form a valid
extruded solid). Consumers (e.g. OCCTReconstruct `reify`) now degrade gracefully instead of aborting.

**Swift-only — no xcframework rebuild.** New `SelfIntersectingProfileGuard263` suite + full Modeling
(409) and ShapeHealing (208) domains green. Closes #263.

### v1.8.2 (June 2026) — feat: smooth multi-start `threadedShaft` direct build (#257)

**Feature.** Multi-start threads (`threadedShaft(starts: N)`, N > 1) now build via the smooth,
boolean-free **direct** path instead of falling to the faceted boolean cut (which produced
disconnected notches, #254). The single-start cam-slice loft is generalised to **N teeth tiling the
turn at lead = N·pitch**, giving a continuous interleaved multi-helix — a low-face-count,
BRepCheck-valid solid with the crest exactly at the nominal major radius. Partial-length multi-start
(thread + plain shank) closes via per-start shoulder faces; full-length is the lofted solid directly.

Covers the piecewise-linear forms the direct build already supports (ISO/Unified, trapezoidal/ACME,
square, buttress). Rounded (knuckle / rounded Whitworth), tapered (NPT/BSPT), and non-cylinder
targets still use the cut path.

Key detail: the loft samples **per pitch** (not per lead) — sampling per turn under-samples each
tooth at N > 1 and the `ruled:false` loft balloons the crest radially past nominal. Swift-only — no
xcframework rebuild. Verified: 2-/3-start crest = nominal by mesh vertices; start count = N.

### v1.8.1 (June 2026) — fix: single-start `threadedShaft` is always a smooth helix; deprecate `.boolean` (#254)

**Fix.** `threadedShaft(build: .boolean)` produced a *faceted, disconnected* thread — a helical
scatter of rectangular notches rather than a continuous groove — because it forced the screw-loft
boolean cut path, whose tightly-wound helical cutter is the classic OCCT BOP failure (cf. #213/#225).
The solid was `isValid` with roughly the right volume, so only rendering exposed it.

`.boolean` only ever existed to clamp a supposed crest "overshoot" from #222 — but #232 established
that overshoot is a `Bnd_Box` control-hull **artifact** (verified here: the direct build's crest
measures **exactly nominal** by both `boundingBoxOptimal()` and mesh vertices, while `.bounds`
over-reads +14–21%). With no remaining reason to prefer it, **single-start coaxial-cylinder threads
now take the smooth, boolean-free direct build (#213) for every build mode**, and `ThreadBuild.boolean`
is **deprecated** (now treated as `.auto`). Use `.auto` or `.direct`.

`.auto` / `.direct` single-start behaviour is unchanged (they already built direct). Swift-only change —
no xcframework rebuild.

**Known limitation:** multi-start threads (`starts > 1`) and non-cylinder targets still use the
faceted cut path, which can come out as disconnected notches — a smooth multi-start/internal direct
build is a tracked gap.

### v1.8.0 (June 2026) — feat: `Exporter.writeBREP(allowInvalid:)`

**Feature (additive).** `Exporter.writeBREP` (and the `Shape.writeBREP` instance wrapper) gain an
`allowInvalid: Bool = false` parameter. When `true`, the `shape.isValid` pre-check is skipped and the
shape is serialized as-is. BREP is OCCT's lossless native format and `BRepTools::Write` does not
require a topologically valid shape, so an in-progress reconstruction — a compound of loose analytic
faces, possibly with a few invalid faces — can be persisted and later reloaded for measurement /
diagnostics (`Shape.loadBREP` already does not gate on validity). Default `false` preserves the
existing validity gate, matching the other exporters. Enables OCCTMCP #41 (measure an imperfect
reconstruction without forcing it through the validity gate). No xcframework change.

### v1.7.11 (June 2026) — fix: `fromPointGrid` degree clamp prevents a BRepMesh hang (#244)

**Bug fix.** `Surface.fromPointGrid` now clamps the B-spline fit degree to `min(uCount, vCount) − 1`.
Passing a `degMax` higher than the grid supports (e.g. the default `degMax: 8` on a 7×7 grid)
over-parameterised the fit — a degree-8 surface from only 7 samples/direction oscillates (Runge
phenomenon) and can self-overlap in 3D. The face was *topologically* valid (`BRepCheck` passes) but
geometrically rippling, so `BRepMesh`'s adaptive refinement never converged — an in-process,
uninterruptible hang (the OCCTReconstruct blocker). Clamping the degree keeps the fit well-posed; the
7×7 case now meshes in ~40 ms.

Prevention is the fix: a watchdog-based bounded mesh was prototyped and **rejected** — BRepMesh does
not poll `UserBreak` during heavy meshing (verified: a fine sphere ran ~13 min / 5 GB ignoring a
0.01s deadline), so an in-process time bound can't be made both reliable and safe. No xcframework change.

### v1.7.10 (June 2026) — crash fix: degenerate hole wires (#234); housekeeping (#178, #210)

**Bug fix + docs.**

- **#234 — `faceAddHole` rejects degenerate hole wires.** A 2-vertex / zero-area / collinear hole
  wire was accepted, producing an invalid face whose extruded prism **SIGSEGV'd** OCCT's `ShapeFix`
  (`healed()`) — an uncatchable OS signal. `OCCTMakeFaceAddHole` now returns `nil` for a hole wire
  with < 3 distinct vertices or all-collinear points, breaking the crash chain at the source. (The
  general "`healed()` never crashes on any invalid input" can't be defended in-process — the fault
  is inside OCCT's uncatchable `ShapeFix`.)
- **#178 — loft polar-iterator fix is upstream.** The `BRepFill_CompatibleWires` guard (#176) shipped
  in OCCT 8.0.0p1; the carried `Scripts/patches/0001-*` was dropped. Corrected the stale CLAUDE.md
  note + #176 regression test comment (the test passes against the unpatched p1 xcframework).
- **#210 — context7.** Runnable-snippet doc comments on the core ops (primitives + booleans) and a
  CLAUDE.md doc-standards rule ("document with a runnable Swift snippet so context7 indexes it"). The
  Swift API is now indexed and queryable on context7 (`/gsdali/occtswift`).

No new operations; no xcframework change.

### v1.7.9 (June 2026) — face from surface bounded by a wire / UV polygon (#233)

**Additive, source-compatible.** Trim a curved analytic surface (cylinder / cone / sphere /
B-spline) to a **non-rectangular** region, instead of only a rectangular UV patch.

- **`Surface.toFace(uvBoundary: [SIMD2<Double>])`** — a closed UV-space boundary polygon becomes 2D
  edges with pcurves on the surface → `BRepBuilderAPI_MakeFace(surface, wire)` + `BuildCurves3d`.
- **`Shape.face(from: Surface, boundary: Wire)`** — a 3D boundary wire: exact `MakeFace` +
  `ShapeFix_Face` when the wire lies on the surface, else a fallback that projects the wire's ordered
  points to UV and trims by that polygon (handles sampled boundary polylines; a seam-crossing
  boundary isn't handled by the fallback).

Bridge: `OCCTShapeCreateFaceFromSurfaceUVPolygon`, `OCCTShapeCreateFaceFromSurfaceWire`. Surfaces
86→88, total **4,290** operations. No xcframework change.

Also lands the #232 investigation (doc + tests, no behavior change): `Shape.bounds` over-reports for
B-spline/faceted geometry (control-hull artifact) — threaded solids are bounded *exactly* to
`length`/`depth`; `Issue232BoundsTests` asserts the true (mesh-vertex) extent.

### v1.7.8 (June 2026) — cookbook: surfaces from points + working with meshes (#230, #231)

**Documentation only — no code, API, or xcframework change.** Two new cookbook pages; snippets
compile-checked against the shipped API.

- **Surfaces from Points** (#230) — fit a B-spline `Surface` through 3D points: a regular grid via
  `Surface.fromPointGrid` (`GeomAPI_PointsToBSplineSurface`), a scattered cloud via
  `Surface.plateThrough` (`GeomPlate`), and deform-an-existing-surface-to-targets via
  `nlPlateDeformed` (NLPlate). With a which-to-use table (vs. `Surface.gordon` for curve networks).
- **Working with Meshes** (#231) — operating on the `Mesh` value type (distinct from Meshing &
  Export): build from vertex/index arrays, inspect, triangle ↔ B-Rep face picking
  (`trianglesWithFaces`), mesh-level booleans, `toShape`, and SceneKit / RealityKit / Metal interop.

### v1.7.7 (June 2026) — cookbook: Gordon surfaces (#229)

**Documentation only — no code, API, or xcframework change.** New cookbook page on **Gordon
surfaces** — skinning a surface through a network of crossing profile + guide curves via
`Surface.gordon` / `Surface.gordonReport` (`GeomFill_Gordon`). Covers the grid-closure requirement,
build diagnostics (`GordonResultStatus`, `allowApproximateFallback`), the lower-level `networkSurface`
(`GeomFill_NetworkSurface`) and its knot-alignment caveat, and a Gordon-vs-loft-vs-fill decision table.
Snippets compile-checked against the shipped API; figure rendered from the same network the page shows.

### v1.7.6 (June 2026) — cookbook complete: healing, meshing, XCAF, topology (#210, #228)

**Documentation only — no code, API, or xcframework change.** Adds the final four cookbook areas,
completing the issue #210 area list (the Swift-API counterpart to OCCT's own user guides). Every
snippet was compile- and run-checked against the shipped API.

- **Healing & Validity** — `isValid` / `isValidSolid` / `isSelfIntersecting`, `analyze`,
  `signedVolume` + `orientedForward`, the repair ops (`healed` / `fixed` / `unified` / `upgraded`),
  sewing, and free-boundary gap finding/closing.
- **Meshing & Export** — `mesh(linearDeflection:)` + `MeshParameters`, the `Mesh` type, `mesh.toShape`,
  a deflection table, and STL / OBJ / PLY / STEP / IGES / BREP / glTF export + import with a round-trip.
- **XCAF Assemblies** — `Document` trees, components & instancing, names / colors / materials, and
  structured STEP / GLB round-trip (with a two-colour assembly figure).
- **Topology Graph** — `TopologyGraph` node counts, adjacency / shared edges / `sameDomainFaces`,
  durable `GraphUID`s (vs ephemeral `NodeRef`), and history tracking through operations.

### v1.7.5 (June 2026) — `threadedRod` from a custom profile + helical-sweeps cookbook (#225)

**Additive, source-compatible.** New `Shape.threadedRod(customProfile:nominalDiameter:pitch:cutDepth:length:…)`
builds a smooth worm/screw from a **custom radial tooth profile** directly — composing the helicoid
with the core by sewing, with **no boolean** — yielding a BRepCheck-valid, analytic solid (a handful
of B-spline faces → a sub-MB STEP).

This addresses #225: `helicalSweep` + `union`/`subtract` against a coaxial cylinder produces an
invalid (union) or collapsed-to-zero (subtract) result that no fuzzy value or heal pass recovers —
OCCT's BOP can't resolve the coincident/tangent helicoid faces (consistent with #213, #181). The
boolean compose path was never the way; the direct build is. The custom-profile direct build already
existed under `threadedShaft(spec:)` with a `ThreadSpec(customProfile:)` — `threadedRod` makes it a
discoverable one-liner and never silently falls back to an invalid boolean (returns `nil` instead).

- `ThreadProfile.supportsSmoothRodBuild` — public predicate (real crest flat, ≤ 2 flanks) for whether
  a custom profile can take the direct build.
- `Shape.helicalSweep(…)` doc now warns against the boolean-compose anti-pattern and points to `threadedRod`.
- **Cookbook: Helical Sweeps** — new page (`helicalSweep` helicoids vs. `threadedRod` worms, and why
  the boolean compose fails), with rendered figures.

### v1.7.4 (June 2026) — docs: cookbook lofting & sweeps, context7 onboarding

**Documentation only — no code, API, or xcframework change.**

- **Cookbook: Lofting & Sweeps** (#226) — new example-rich page covering extrude, revolve,
  sweep-along-path, loft (square→round, ruled vs smooth, point-capped cones), and multi-section
  pipe shells, with a "loft vs multi-section sweep — which?" decision section. Every snippet is
  compile- and run-checked against the shipped API; four figures (pipe elbow, frustum, cone, vase)
  rendered headlessly as PNG posters + interactive `<model-viewer>` GLB models.
- **context7 onboarding** (#224) — added `context7.json` scoping context7's crawl to the Swift API
  (`docs/`, `Sources/OCCTSwift`) with usage rules, so the Swift surface becomes queryable on
  context7 (issue #210).
- **WebAssembly feasibility plan** (#223) — `docs/wasm-feasibility.md`: analysis + phased plan for
  reusing the OCCTSwift API in a SwiftWasm app (deferred; the wasi-sdk-vs-Emscripten ABI split is
  the central obstacle).

### v1.7.3 (June 2026) — smooth fine-pitch internal threads (#219)

**Bug fix.** `threadedHole` on a fine-pitch internal thread (e.g. 3/8-16 UNC, M10×1.5) came out
**faceted**. The `ruled:false` smooth helical cutter self-intersects in a degenerate band around the
default ~14 sections/turn — the axial step per section is far smaller than the groove's axial
half-width, so consecutive sections overlap many-deep and the lofted B-spline pinches, making the
boolean a no-op that silently fell back to the faceted cutter. The cut path now builds the smooth
*internal* cutter at a denser, escalating section count (24→36/turn) and takes the first sound cut;
the faceted cutter remains the fallback for genuinely awkward composite bodies. Fine-pitch internal
threads now cut smooth (the wing-nut cookbook bore drops from ~247 faces to ~15). No API change.

### v1.7.2 (June 2026) — thread envelope fix (#222)

**Additive, source-compatible.** `Shape.threadedShaft(…)` gains a `build: ThreadBuild = .auto`
parameter. At coarse pitch / wide crest flats the smooth direct rod build (#213) bows the crest
**past** the nominal major radius (+14–21% measured: M12×1.75 → r 6.85 vs 6.0; Tr12×3 → 7.28),
which oversizes headless single-start parts (lead screws, studs, worms). `build: .boolean` forces
the boolean cut path — cutter subtracted from a cylinder of radius exactly `nominalDiameter / 2`,
so the crest is clamped in-envelope (≤ nominal, ~1% tessellation margin). `.auto` (default) and
`.direct` keep the original smooth build. No existing call sites change.

### v1.7.1 (June 2026) — p1 follow-ups + xcframework header hygiene

**Additive + a packaging fix.** New p1 operations and a corrected xcframework (no stale headers).

#### New operations
- **BRepGraph durable identity** — `TopologyGraph` UID/RefUID/ItemUID accessors (`uid(ofNodeKind:index:)`,
  `node(forUID:)`, `contains(uid:)`, ref/item variants, `generation`) over `BRepGraph::UIDsView`, giving
  persist-safe identifiers (the migration note's `UID`/`RefUID`/`ItemUID`, vs the non-durable NodeId/RefId).
- **`Surface.networkSurface(profiles:guides:tolerance:)`** — wraps the new `GeomFill_NetworkSurface`
  low-level Gordon builder, with a `NetworkSurfaceStatus`.
- **`Surface.gordonReport(…)`** — exposes `GeomFill_Gordon`'s new `Status()`/`IsApproximate()` and the
  `ExactOnly`/approximate-fallback `ApproximationMode` (`GordonResult` + `GordonResultStatus`).
- **`Polygon2D.copy()`, `PolygonOnTriangulation.copy()/setNodes()/setParameters()`** — the new
  `Poly_*` copy/mutator APIs.
- **BRepGraph reads, now real:** `faceSameDomain(of:)` (derived from edge-incidence + surface equality),
  face/edge adjacency & shared-edges (derived from first-class reverse relations), `faceIsNaturalRestriction`
  (`Tool::Face::NbWires == 0`).
- **BRepGraph vertex-supplement:** `faceAddVertex`/`edgeAddInternalVertex`/`faceRemoveVertex`/`faceNbVertexRefs`
  now back onto the `BRepGraph_LayerTopoSupplement` layer (uid/shape-based; the v1.7.0 stubs were no-ops).

#### Packaging fix — stale headers removed from the xcframework
`build-occt.sh` reused the CMake install prefix across builds; `cmake --install` adds headers but never
deletes removed ones, so **18 OCCT 8.0.0-GA headers** that p1 removed/renamed (e.g.
`Approx_BSplineApproxInterp.hxx`, `BRepGraph_Builder/History/RepId/MeshCache/LayerRegularity.hxx`,
`GeomFill_GordonBuilder.hxx`) **leaked into the v1.7.0 framework**, where they masqueraded as current
API (their symbols were never in the library). The build script now wipes the install prefixes each run,
and the v1.7.1 xcframework contains **only real p1 headers**. (Functionally harmless in v1.7.0 — the
phantom headers had no symbols — but misleading.)

> Note on edge regularity/continuity: one of those phantom headers (`BRepGraph_LayerRegularity`) made it
> look like a graph-level regularity API existed in p1. It does not (p1 ships `BRepGraph_LayerParametric`
> instead); `TopologyGraph.edgeMaxContinuity`/`setEdgeRegularity` remain no-ops. Use `Shape.maxContinuity`
> (`BRep_Tool::MaxContinuity`) for edge continuity.

### v1.7.0 (June 2026) — OCCT 8.0.0p1 upgrade; BRepGraph realigned to its redesigned model

**MINOR — dependency upgrade with API-behaviour changes confined to the BRepGraph domain.** OCCT
shipped **8.0.0p1** as a hot patch on top of 8.0.0. OCCTSwift now pins it (`V8_0_0_p1`). Everything
outside BRepGraph is a transparent upgrade; BRepGraph itself was comprehensively redesigned upstream
and our wrapper has been realigned to the new model rather than shimmed back to the old one.

#### Upstream fix landed
Our `BRepFill_CompatibleWires::SameNumberByPolarMethod()` polar-iterator guard (OCCTSwift #176 — the
loft/ThruSections SIGSEGV on mismatched closed profiles) **shipped in 8.0.0p1**. The source patch we
carried (`Scripts/patches/0001-…`) is therefore removed; `build-occt.sh` pins `OCCT_RC="p1"`.

#### Removed/changed OCCT classes migrated (non-BRepGraph)
- **`Approx_BSplineApproxInterp` (removed)** → `BSplineApproxInterp` is reimplemented on
  `GeomAPI_PointsToBSpline` (the documented replacement). The C/Swift ABI is unchanged, but
  `nbControlPoints` is now **advisory** (the approximator chooses the pole count to meet tolerance)
  and `interpolatePoint(_:withKink:)` is a **no-op** (no per-point exact-interpolation/kink control
  in the replacement). `maxError` is computed by projecting the inputs onto the fitted curve.
- **`GeomFill_Gordon` (reworked)** — API remained source-compatible; no wrapper change.
- **`BRepGraph_RepId`** moved to the `BRepGraphInc` subpackage (header `BRepGraphInc_RepId.hxx`).

#### p1 crash fixes (OS-signal null-derefs that `catch(...)` cannot trap)
- **`Extrema_ExtElCS` (line ∥ cylinder axis)** — infinite/degenerate extrema crash. `ExtremaElCS.lineToCylinder`
  now returns 0 when the line is parallel to the cylinder axis.
- **`ShapeUpgrade_WireDivide` / `ShapeFix_ComposeShell`** — p1 made the `ShapeBuild_ReShape` context
  mandatory; `Perform()` null-derefs without one. Both bridges now set a context (plus WireDivide
  guards a wire whose edges have no pcurve on the target face).
- **`Wire.rectangle`** with sub-`Precision::Confusion()` dimensions made degenerate edges that crashed
  downstream; such dimensions are now rejected (returns nil).

#### BRepGraph realigned to the 8.0.x model
BRepGraph is OCCT's explicit graph-oriented topology model (see
[Open-Cascade-SAS/OCCT discussion #1291](https://github.com/Open-Cascade-SAS/OCCT/discussions/1291)).
8.0.0p1 reworked it around nine separated concerns — topology **definitions** vs **references/usages**,
**geometry reps**, **mesh reps**, **products/occurrences**, persistent **UIDs**, metadata **layers**,
modification **stamps** (version counters, *not* booleans), and self-invalidating **caches**. The
wrapper was rewritten to that model. Upstream notes the interface "will change slightly in 8.1 and in
development versions after 8.0," so expect further churn here.

Concretely:
- **Shape ingestion**: `BRepGraph_Builder` removed → `BRepGraph::ShapesView::Add()`.
- **History**: `BRepGraph::History()` removed → the registered `BRepGraph_LayerHistory` layer
  (`LayerRegistry().FindLayer<>()` / `.Ensure<>()`); records are `Event`s.
- **Topology queries** moved across views: counts to `Topo().Geometry().NbFaceSurfaces()` etc.;
  `IsBoundary`/`IsManifold`/`FindCoEdgeId` to `BRepGraph_Tool::Edge`; `SameParameter`/`SameRange` to
  `BRepGraph_Tool::CoEdge` (per-coedge, derived). Edge→faces / vertex→edges are first-class reverse
  relations (`FacesOf`, `VertexOps::Edges`); **face/edge adjacency and shared-edges are derived from
  them** (no direct adjacency call survived, but the data does).
- **Mesh + geometry representations are handle-based**: integer "rep ids" are gone. The wrapper keeps
  its rep-id Swift API working via a per-graph handle registry that backs the new
  `Mesh().Editor().Faces().SetCachedTriangulation(face, handle)` / persistent-rep setters. Mesh cache
  inspection reads `Mesh().Cache().*.Entry()` (each holds a single handle + a `MeshGeneration` stamp).
- **Edge start/end vertex** now resolves a `VertexRefId` (a per-edge use) to its vertex definition.
- **Root products** require explicit `AppendDocumentRoot()` after creation.

##### Deliberately-removed concepts (now no-ops or derived-getter-only — by design, not breakage)
These reflect BRepGraph's intent; the *capability* lives elsewhere in the new model:
- **Flags are derived from geometry, not stored** → `SameParameter`/`SameRange`/`Degenerated`/`IsClosed`
  setters are no-ops; the **getters return the live derived value**.
- **Regularity/ownership are controlled layers**, not inline flags → the old `SetEdgeRegularity` /
  `EdgeMaxContinuity` inline path is gone.
- **Natural-bound faces are normalized away** (explicit topology is required below a bounded face) →
  `…NaturalRestriction` get/set no longer apply.
- **Locations live on assembly references** (occurrence/child), not per-subshape → the per-vertex/edge/
  wire/face/shell/solid/coedge `…RefLocalLocation` setters are gone; occurrence/child placement setters
  remain.
- **Coedges are first-class** (a coedge *is* the edge-on-face use, carrying orientation/pcurve/seam) →
  the coedge-as-separate-reference setters are gone; `NbCoEdgeRefs` reports the coedge count.
- **Vertices are references with reverse relations** → face/edge vertex add/remove mutators are gone
  (population builds them); query via the reverse relations instead.

#### Test/behaviour notes
- `GC_MakeHyperbola` (3-point) is stricter in p1: a collinear `S2` (zero minor radius) is rejected;
  the test now uses a valid off-axis `S2`.
- Run the suite with `swift test --no-parallel` — the pre-existing non-deterministic NCollection
  arm64 race makes the parallel run flaky (unrelated to p1).

### v1.6.3 (June 2026) — buttress trued to DIN 513; Whitworth & knuckle finished

**PATCH — geometry corrections, non-breaking.** The last two medium-confidence thread forms are
trued to their standards:

- **`.buttress` → DIN 513** (German *Sägengewinde*): asymmetric **3° load / 30° clearance** flanks
  (33° total) at depth **0.86777·P** (so the bolt core `d3 = d − 2·0.86777·P`, verified against the
  DIN 513 table — e.g. S 10 × 2 → d3 = 6.528). Previously it used a reconstructed ANSI 7°/45° profile
  at 0.66271·P, which matched no German standard.
- **`.whitworth` / `.bspParallel`** confirmed at the correct 55° / **0.640327·P** and kept as the
  standard BS 84 **flat-truncation** (crest = root flat = P/6). A fully *rounded* crest makes the deep
  tooth's `ruled:false` loft spike past the nominal radius (a thin outward flap, OCCTSwift #213), so
  the truncation is the form that builds smooth and dimensionally exact.
- **`.knuckle`** now routes through the **faceted cut path** for the external build. The previous
  rounded-crest direct loft was both slow (~28 s) and bulged ~6% past the nominal crest; the cut path
  keeps the crest exactly at the nominal radius and builds in ~1 s. (Rounded profiles — those with
  more than two straight flanks — are now detected and sent to the cut path generally.)

Buttress cookbook figure re-rendered with the DIN 513 profile.

### v1.6.2 (June 2026) — knuckle thread trued to DIN 405

**PATCH — geometry correction, non-breaking.** The `.knuckle` form now matches DIN 405: depth
**0.55·P** (so the bolt minor `d3 = d − 1.1·P`, verified against the standard dimension table — e.g.
Rd 8 × 1/10″ → d3 = 5.460) and a proper **30°-included (15° per side)** flank with circular-arc
rounded crest and root (the rounding radius is solved for flank tangency). Previously it used a
cosine profile at 0.5·P (≈60°-included flanks). A small crest/root land is retained so the smooth
direct build still applies.

### v1.6.1 (June 2026) — smooth internal threads

**PATCH — quality improvement, non-breaking.** `threadedHole` now produces **smooth** internal
threads instead of faceted ones. An interior helix is cut into a *thick wall* (not a thin shaft), so
OCCT's boolean subtracts a smooth (`ruled=false`) helical cutter robustly — verified valid across all
orientations. (The external fallback is unchanged: subtracting a smooth cutter from a thin external
cylinder is the unreliable case from #213, so non-cylinder/tapered external cuts stay faceted.)
Cookbook nut / wing-nut / lead-screw figures re-rendered with the smooth bore threads.

### v1.6.0 (June 2026) — thread forms + custom profiles

**MINOR — additive, non-breaking** (existing `ThreadSpec`/`threadedShaft` calls are unchanged).

The thread feature now covers the common standard forms beyond the 60° V, and can thread a cylinder
with **any** cross-section:

- **New `ThreadForm` cases**: `.whitworth` / `.bspParallel` (55°), `.acme` (29°) / `.trapezoidal`
  (metric Tr, 30°), `.square`, `.buttress` (7°/45°), `.knuckle` (rounded), `.nptTapered` /
  `.bsptTapered` (60°/55° on a 1:16 taper), and `.custom`. (UNF/UNC, metric-fine, and SAE remain
  pitch/standards variants of the existing 60° forms — no new cases needed.)
- **`ThreadProfile`** — a public, `Codable` normalized tooth cross-section (vertices of
  `axial` 0…1 × `depth` 0 = crest … 1 = root). `ThreadSpec(customProfile:nominalDiameter:pitch:cutDepth:)`
  threads a cylinder with an arbitrary shape. Built-in form profiles are exposed too
  (`.iso60V()`, `.acme29`, `.square`, …).
- **Geometry is now form-dependent**: `ThreadSpec.cutDepth` / `profile` / `taperRatio` switch on the
  form. ISO/Unified compute identically to before (5H/8, P/8 crest, P/4 root, 30° flanks).
- **All forms work external and internal**: external cylinders use the smooth, BRepCheck-valid direct
  build (#213) — a handful of faces; internal threads (`threadedHole`), non-cylinder targets, and the
  tapered pipe forms use the robust faceted cut path. The OCCT bridge is unchanged (a thin wrapper);
  all new geometry is composed in Swift.
- **Parser** recognises `Tr40x7[LH]`, `1.5-4 ACME`, `G1/2` (BSP), `R…`/`Rc…` (BSPT), `W1/2` / `1/2 BSW`
  (Whitworth), and `1/2-14 NPT`, alongside the existing metric/Unified designations.

Cookbook: the [Threads](https://gsdali.github.io/OCCTSwift/guides/cookbook/threads.html) page gains a
forms gallery and a custom-profile example.

### v1.5.3 (June 2026) — smooth, valid ISO V-threads built without booleans (closes #213)

**PATCH — additive, non-breaking** (same `threadedShaft` API; smoother/valid result).

`Shape.threadedShaft(form: .iso68)` produced a near-square groove (~6.6° flanks) instead of a true
60° V (30° flanks): the cutter's flank offsets used the crest/root *truncation* flats and omitted
the `cutDepth·tan(30°)` flank term. Fixing the profile, however, exposed a deeper limit — OCCT's
boolean engine **cannot reliably subtract a smooth helical V-thread cutter** from a cylinder (it
under-cuts / no-ops on ~half of all orientations, unfixable by bleed / fuzzy / cone / extend; only
the faceted screw-loft is robust, because its planar facets cross the shaft transversally).

So `threadedShaft` now **builds the threaded rod directly, with no boolean**, when the target is a
plain cylinder coaxial with the axis (the common case):

- The thread region is a `ruled=false` ThruSections loft of the thread's true cross-section
  ("cam": root arc → flank spiral → crest arc → flank spiral) at z-slices rotated by the helix —
  one BSpline face per cam edge (**~9 faces, not hundreds of facets**), flat caps, solid-to-axis.
- Any unthreaded margin is closed by **pure sewing** — a single-loop shoulder face + plain
  cylinder + end disk — not a fuse (a fuse is robust here but **6–71 s**; sewing is ~0.3 s).

Because the kernel's BOP is never invoked, the result is **orientation-robust AND BRepCheck-valid**
where the old cut path was faceted or failed. The boolean cut path remains the fallback for
non-cylinder targets, internal threads (`threadedHole`), and multi-start. The whole construction is
composed in Swift from already-wrapped primitives (`Shape.loft(ruled:)`, `Wire.arc`/`.interpolate`,
`Shape.face(from:)`, `Shape.sew`, `Shape.solidFromShell`), so the OCCT bridge stays a thin wrapper —
no thread-specific bridge code.

> Note: the smooth thread is a BSpline solid, so its default `Bnd_Box` is the control-pole hull and
> overshoots the true surface by ~13% (a pole artifact, not a bulge); use `boundingBoxOptimal()` for
> the real extent (the crest sits exactly at the nominal radius).

### v1.5.2 (June 2026) — reconstruction wrapping gaps: outer shell, mesh quality flag, wire arc-length adaptor (closes #211)

**PATCH — additive, non-breaking.** Closes the confirmed gaps from the mesh→CAD reconstruction
coverage audit (#211):

- **`Shape.outerShell` → `Shape?`** (`BRepClass3d::OuterShell`) — the outer body shell of a solid,
  distinguishing it from internal void shells. `nil` for non-solids. Decomposes a part into
  outer-body + cavities.
- **`MeshParameters.allowQualityDecrease`** (`IMeshTools_Parameters::AllowQualityDecrease`, default
  `false`) — the one missing mesh knob. Lets a re-mesh at a different deflection actually replace an
  existing finer triangulation (e.g. a deviation re-measure), instead of OCCT silently keeping the
  coarser/finer mesh.
- **`WireCurve`** (`BRepAdaptor_CompCurve`) — treats a multi-edge wire as one **arc-length**
  curve: `length`, `point(atAbscissa:)` / `tangent(atAbscissa:)` (walk across edge boundaries),
  `points(count:)` / `points(spacing:)` for **even arc-length sampling** (`GCPnts_UniformAbscissa`),
  plus native `parameterRange` / `point(atParameter:)` / `tangent(atParameter:)`. Replaces ad-hoc
  per-edge sampling when placing sections along a measured wire.
- **`EdgeCurve`** (`BRepAdaptor_Curve`) — the single-edge sibling of `WireCurve`: adds the
  arc-length side (`length`, `point(atAbscissa:)`, `points(count:/spacing:)`) that `Edge`'s native
  `point(at parameter:)` lacked.
- **`Shape.innerShells`** — the void/cavity shells of a solid (every shell except `outerShell`);
  pairs with `outerShell` to fully decompose a part into outer body + cavities.

Also from #211, verified and **not** needing changes: `Shape.minDistance(to:) -> Double?` already
exists; and a "scattered point-cloud" `GeomAPI_PointsToBSplineSurface` fit is **not** an OCCT
capability — every constructor is grid-based (`Array2`); a cloud fit means resampling to a grid
(already wrapped via `Surface.fromPointGrid`) or `GeomPlate` / `BRepOffsetAPI_MakeFilling` (already
wrapped). Source-only (no xcframework change).

### v1.5.1 (June 2026) — `Shape.isSelfIntersecting(timeout:)` — bounded self-intersection check (closes #208)

**PATCH — additive, non-breaking.** Follow-up to #206. `isValidSolid` is a topology-level check
(`BRepCheck_Analyzer`) that **misses global self-intersection** — a self-intersecting B-spline solid
from `loft(ruled: false)` can report `isValidSolid == true` yet poison downstream booleans. New:

```swift
func isSelfIntersecting(timeout: Double = 30) -> Bool?   // true / false / nil(=indeterminate)
```

Backed by `BOPAlgo_ArgumentAnalyzer`'s self-interference test (stop-on-first-faulty), wrapped in the
same wall-clock watchdog as the #206 booleans so it can't hang: returns `true` (self-intersects),
`false` (clean), or `nil` if it couldn't finish within `timeout` (**indeterminate** — treat as
"unknown", not "clean"). The test is **expensive** (seconds on B-spline solids), so it's opt-in.
Verified on the #206 operands: `nurbs_env` → `true` (the actual culprit), and the docs give the
validate-at-source recipe (`orientedForward()` + `isSelfIntersecting() == false`).

**Why not a cheap volume/`isValidSolid` guard (the issue's other options):** investigation showed
the reported `env` operand passes `BRepCheck`, sits within its bounding box, and has positive volume
— nothing cheap flags it. And a `volume <= 0` reject would false-positive on legitimately
*reversed-orientation* solids (a known, `orientedForward()`-fixable case), so it isn't sound.
`isValidSolid`'s doc now spells out the topology-vs-self-intersection distinction. Source-only.

### v1.5.0 (June 2026) — boolean ops are time-bounded; never hang indefinitely (closes #206)

**MINOR — additive param + a default-behavior change.** `Shape.union` / `subtracting` /
`intersection` could **hang indefinitely** on a self-intersecting / inside-out operand — e.g. a
B-spline solid from `loft(ruled: false)` that reports `isValidSolid == true` yet poisons the
boolean. `BRepAlgoAPI_Cut` on the reported operands spun for >5 min on a 66-face input.

The boolean ops now run under a **wall-clock watchdog** (OCCT's `Message_ProgressRange` +
`UserBreak`) and return `nil` at a deadline instead of spinning forever:

```swift
func union(_ other: Shape, fuzzyValue: Double = 0, glue: BooleanGlue = .off,
           timeout: Double = Shape.defaultBooleanTimeout) -> Shape?   // and subtracting / intersection
```

- **`timeout`** — seconds; default `Shape.defaultBooleanTimeout` (**120s**). `0`/negative = unbounded
  (the prior behavior). Verified to interrupt the real #206 operands (was an infinite hang → now `nil`).
- **Default-behavior change:** a boolean that genuinely runs longer than 120s now returns `nil`
  instead of completing/blocking. Pathological hangs are bounded; raise `timeout` (or pass `0`) for
  legitimately heavy booleans.

**Why a timeout and not an operand pre-check:** the cheap detectors don't catch the reported
`env` operand — `BRepCheck_Analyzer` reports it *valid* and its volume sits within its bounding box;
only `BOPAlgo_ArgumentAnalyzer` flags it, and that itself ran >50s on the input. The watchdog is the
only general, bounded guard. (The separate `cav` operand has negative volume, so a downstream
`volume > 0 && analyzeValidity(geometryChecks:)` gate remains a useful cheap fast-fail and is still
recommended.) Source-only (no xcframework change).

### v1.4.7 (June 2026) — boolean fuzzy value + glue options (closes #202)

**PATCH — additive, non-breaking.** `Shape.union` / `subtracting` / `intersection` now expose the two
`BRepAlgoAPI_BooleanOperation` robustness levers OCCT provides for **coincident / near-tangent faces**,
where the default boolean can silently under-subtract or inflate volume:

```swift
func union(_ other: Shape, fuzzyValue: Double = 0, glue: BooleanGlue = .off) -> Shape?
// same trailing parameters on subtracting(_:) and intersection(_:)
```

- `fuzzyValue` → `SetFuzzyValue` (tolerance-based fuzzy boolean; `0` keeps OCCT's default, negatives ignored).
- `glue` → `SetGlue` — new `Shape.BooleanGlue` enum: `.off` (default), `.shift` (`BOPAlgo_GlueShift`),
  `.full` (`BOPAlgo_GlueFull`). Gluing hardens & speeds up unions/cuts of solids known to share
  coincident faces (e.g. consecutive analytic loft chunks, thin-wall shells).

Defaults reproduce prior behavior exactly. Implemented via a shared templated bridge driver
(`OCCTShapeUnionEx`/`SubtractEx`/`IntersectEx`) over the common `BRepAlgoAPI_BooleanOperation` base.
Source-only (no xcframework change).

### v1.4.6 (June 2026) — instanced-assembly STEP writer (closes #173)

**PATCH — additive, non-breaking.** New `Exporter.writeSTEPAssembly(_ document: Document, to url:)`
writes an XCAF `Document` as a **product-structured STEP assembly**: each unique part label
becomes one STEP product, referenced by its located component occurrences
(`NEXT_ASSEMBLY_USAGE_OCCURRENCE` + each component's `TopLoc_Location`). A part placed N times
stores **one** `MANIFOLD_SOLID_BREP`, not N copies — file size scales with unique parts, and the
result opens as an editable assembly in standard CAD viewers (AP214). Names/colors set on the
document are preserved.

The underlying capability already existed (`Document.writeSTEP` transfers the XCAF doc via
`STEPCAFControl_Writer`, and full rotation+translation placement landed in #174); this adds the
named, documented, throwing convenience entry point #173 asked for, plus instancing + round-trip
tests.

### v1.4.5 (June 2026) — mesh→shape weld tolerance is caller-tunable (#197)

**PATCH — additive, non-breaking.** `Mesh.toShape()` sewed its triangles into a shell at a
**hardcoded `1e-6`** weld tolerance. That tolerance must scale with the mesh's coordinate
magnitude — too small for a large-coordinate (or imprecise, imported) mesh leaves shared edges
unmerged and silently yields an open shell. It now takes `weldTolerance: Double = 1e-6` (the
default reproduces prior output); non-positive values return `nil`. From the #197 hardcoded-constant
sweep — the audit (see issue) found this the one remaining genuine knob; the rest of the `1e-X`
literals are internal correctness epsilons left as-is.

### v1.4.4 (June 2026) — mesh deflection is caller-tunable on auto-meshing utilities (#197)

**PATCH — additive, non-breaking.** Several utility functions auto-triangulated their input at a
**hardcoded `0.1` mm** deflection, leaving callers no control over fidelity/speed. Each now takes a
`deflection: Double = 0.1` parameter (the default reproduces prior output). First slice of the #197
hardcoded-constant sweep — the *mesh deflection* area:

- `Shape.writeSTLBinary(to:deflection:)` / `writeSTLAscii(to:deflection:)` — STL export resolution.
- `Shape.proximityFaces(with:tolerance:deflection:)` — proximity triangulation.
- `Shape.selfIntersectionPairs(tolerance:maxPairs:deflection:)` — self-intersection triangulation.
- `CoherentTriangulation.createFromMesh(_:deflection:)`.

(The primary STL path `Exporter.writeSTL(shape:to:deflection:)` already exposed this.) Source-only;
remaining #197 areas — tolerances, sampling counts — tracked in the issue.

### v1.4.3 (June 2026) — fast 2D drawings of threaded solids via polyhedral HLR (closes #196)

**PATCH — additive + guidance.** The v1.4.1 smooth analytic thread helicoid is HLR-hostile under
OCCT's **exact** HLR (`hlrEdges` / `HLRBRep_Algo`): projecting its BSpline faces computes analytic
helical silhouettes and blows up — a downstream 2D-drawing pipeline measured **~19× slower** vs the
v1.4.0 faceted thread.

**The fix is not to change the solid.** OCCT's **polyhedral** HLR (`hlrPolyEdges` / `HLRBRep_PolyAlgo`,
already wrapped) projects the shape's *triangulation*, so it is fast on any surface — **measured ~48×
faster** than exact HLR on an analytic M10 thread (337 ms vs 16.4 s, side view) — while the one
analytic solid stays smooth for STEP. **Prefer `hlrPolyEdges` for 2D drawings of threaded / curved
solids; reserve exact `hlrEdges` for analytically simple shapes.**

`hlrPolyEdges(direction:category:deflection:)` now exposes the internal mesh **`deflection`** (mm,
default `0.1`) so drawing pipelines can trade fidelity (more, shorter edges) for speed. Non-breaking —
the default reproduces prior output. (No GPU offload needed; the polyhedral CPU path already recovers
the speed. The broader hardcoded-constant sweep this surfaced is tracked in #197.)

### v1.4.2 (June 2026) — long full-length threads return a usable solid, not nil (closes #193)

**PATCH — regression fix.** A long full-length thread (`threadedShaft` over tens of turns, e.g. an
ISO 4017 M10×50 full-thread shank ≈ 49 turns) came back **`nil`**. No API change.

**Cause.** v1.4.1's soundness gate required `Shape.isValid`. For a long thread, the two cutter paths
both fail that gate: the smooth analytic cutter is BRepCheck-valid but, when wound over ~40+ turns,
OCCT's boolean degenerates to a near-no-op (the result keeps ~the full blank volume — *no groove cut*);
the faceted screw-loft fallback *does* cut the groove correctly but trips `BRepCheck` on a benign facet
self-intersection (`isValid == false`) — exactly the #193 symptom. With both rejected, the method
returned `nil`.

**Fix.** Soundness is now judged on **geometry, not `BRepCheck`**: the cut must stay inside the blank
(tight/optimal envelope) and remove a sane fraction of the volume. `isValid` is no longer a gate. The
analytic no-op is still rejected (it removes ~0 material → fails the volume check), so a long thread
falls through to the faceted screw-loft and is returned — dimensionally correct and STEP-exportable,
as the downstream reporter confirmed. Short/medium threads still get the smooth analytic helicoid and
remain `isValid == true`; only the long faceted fallback is allowed to be invalid-but-usable.

### v1.4.1 (June 2026) — smooth analytic thread helicoid, with screw-loft fallback (#187)

**PATCH — geometry quality, no API change.** `threadedShaft` / `threadedHole` now emit a **smooth
analytic helicoid** instead of v1.4.0's faceted ruled loft. Same signatures, same in-envelope
result; the difference is surface quality and face count.

**What changed.** v1.4.0 swept the V-profile through ~14 screw-transformed sections per turn and
ruled-lofted them — correct and in-envelope, but **faceted** (hundreds of flank facets) and ~1 s per
thread. The cutter is now built analytically (new bridge op `OCCTShapeBuildThreadCutter`): the four
ISO-68 V-corners each trace a single BSpline helix (`GeomAPI_Interpolate`), and the solid is bounded
by four ruled faces between consecutive corner-helices plus two V end caps — sewn, made solid, and
`BRepLib::OrientClosedSolid`-corrected. That's **~6 faces, no faceting**, regardless of turn count.

**Automatic fallback.** OCCT's boolean chokes on the *tightly-wound* cutter of small, fine-pitch
threads (e.g. M5×0.8 — 22.5 turns at radius 2.5): the subtraction comes back BRepCheck-"valid" but
with *more* volume than the blank. The cut is validated (optimal/tight bounding box stays inside the
blank **and** volume strictly decreases by a sane amount); if the analytic result fails, it silently
falls back to v1.4.0's robust screw-loft. So M6/M8/M10/M12 and coarse worm pitches get the smooth
helicoid, while pathological small-fine-pitch threads still build via the faceted-but-robust path.

**Why the envelope is measured on the optimal box.** The smooth helicoid's *default* `Bnd_Box`
(`BRepBndLib::Add`) is the BSpline **convex hull**, which overshoots the real surface by ~0.1–0.35 mm
— a control-pole artifact, not escaped material (`AddOptimal` returns the blank's exact extent).
Both the fallback check and the #181-C regression test now use the tight optimal box; a strict
tolerance there still catches the real >1 mm balloon the guard exists for.

**Migration.** None required. Thread mesh/STEP geometry differs again (smoother) — byte-exact
snapshot consumers must rebaseline; everything else is unchanged.

### v1.4.0 (June 2026) — correct, in-envelope thread geometry (closes #187)

**MINOR — BEHAVIOUR CHANGE to `threadedShaft` / `threadedHole`.** The thread output geometry changes:
both now produce a **correct, in-envelope helicoid** for every pitch, including coarse worm pitches
that previously returned `nil` or garbage.

**Why it changed.** The cutter was a `BRepOffsetAPI_MakePipeShell` sweep of a V-profile along the
helix. That sweep re-frames the section with the helix lead, so it **bulged the thread outward**
(~1.25× cut depth for fasteners, ~3.1× for worm pitches → a self-intersecting ≈2×-radius balloon that
crashed STEP export — #181-C/#185). The cutter is now built by a **screw-motion sweep**: the axial
V-profile is transported by a pure rotate-about-axis + translate-along-axis motion (every section
stays in its own axial plane), ruled-lofted, and subtracted. The result's crest sits at the nominal
radius (within ~0.1 mm tessellation), deterministically.

**Migration.** No API change (same signatures, still `Shape?`). But:
- the produced thread **mesh / STEP geometry differs** — snapshot/byte-exact consumers must rebaseline;
- threads that returned `nil` at coarse/worm pitch now return a valid solid;
- the V-form is faceted (ruled loft, ~14 sections/turn) rather than a smooth pipe surface;
- **performance:** ~1 s per thread (loft + boolean over the section facets). For many threads, expect
  it to dominate; a true analytic helical surface (future work) would remove the faceting/cost trade.

The #181-C envelope guard is retained as a thin safety net (now 1× cut depth) but effectively never
trips on the in-envelope result.

### v1.3.6 (June 2026) — fix: thread envelope guard rejected valid fastener threads (closes #189)

**PATCH — regression fix.** The #181-C envelope guard added in v1.3.4 used a tolerance
(`1e-3 · extent`) far tighter than the bounding-box overrun of a *valid* `threadedShaft` /
`threadedHole` result, so it returned **`nil` for ordinary bolts/screws** (M5–M10, ISO 4762/4014/…)
that built in v1.3.3 — breaking 37 downstream fastener generators.

The guard's tolerance is now `2 · cutDepth`. Measured overruns (relative to the thread cut depth,
which scales the corrected-Frenet sweep's directional bulge) are ~1.25× for valid fastener threads
and ~3.1× for the coarse-worm-pitch garbage the guard is meant to catch (#181-C, which balloons to
~2× radius and crashes STEP export). `2 · cutDepth` sits cleanly between them — valid threads build
again, the catastrophic balloon is still rejected. (The proper fix — a cutter that doesn't bulge at
all — is tracked in #187.)

### v1.3.5 (June 2026) — `Shape.helicalSweep` worm/screw-thread helicoid (closes #185)

**PATCH — additive convenience API.** Adds `Shape.helicalSweep(profile:axisOrigin:axisDirection:radius:pitch:turns:clockwise:solid:)`
(and a multi-profile overload), the turnkey form of the #180 auxiliary-spine sweep for the helical
case. It builds the helix spine **and** a correctly-spanning central-axis auxiliary spine internally,
with the orientation flags (`CurvilinearEquivalence = false`, no contact) that keep the swept section
radial — producing a worm/screw-thread helicoid in one call:

```swift
Shape.helicalSweep(profile: rib, axisOrigin: .zero, axisDirection: SIMD3(0,0,1),
                   radius: 5, pitch: .pi, turns: 4.77)   // crest stays radial (~Ø12), not nil
```

Hand-rolling this with `pipeShell(mode: .auxiliary(...))` reliably returned nil because (a) `Wire.helix`
runs toward +Z or −Z depending on handedness and (b) the auxiliary spine must span the helix's full
axial extent or the section planes never intersect it. The helper handles both. (Investigation: the
correct OCCT recipe was confirmed empirically — `SetMode(axisLine, CurvilinearEquivalence=false,
NoContact)`; `CurvilinearEquivalence=true` and the contact modes fail to build for a helix spine.)

### v1.3.4 (June 2026) — assembly/export robustness (#181 B & C)

**PATCH — robustness fixes, no API change.**

- **STEP writer serialization (#181-B).** Concurrent `writeSTEP` calls could SIGSEGV because
  OCCT's `STEPCAFControl`/`STEPControl` writers share non-thread-safe `Interface_Static` globals
  with IGES. All STEP/IGES write entry points now serialize on the shared data-exchange mutex, so
  parallel exports queue instead of crashing. (The crash is an uncatchable signal, so internal
  serialization — not documentation — is the fix.)
- **`threadedShaft` envelope guard (#181-C).** At coarse pitch / steep lead (and, observed here,
  even at bolt pitch) the helical V-cutter self-intersects and the boolean subtract returns a
  non-deterministic solid that BRepCheck reports "valid" yet extends well outside the blank
  (≈Ø22 on a Ø12 blank) — which then crashed downstream STEP export. A thread cut can only remove
  material, so `threadedShaft` now returns `nil` when the result escapes the blank envelope rather
  than handing back garbage. Callers should fall back (e.g. a smooth-cylinder worm body).

Note on #181-A (XCAF `setColor`/`setName` on auto-created component labels): could not reproduce as
an OCCT or bridge fault — `XCAFDoc_ColorTool::SetColor` on auto-created/reference component labels is
robust in isolation, and the bridge already fails safe on unregistered labels. Left open pending a
minimal reproducer.

### v1.3.3 (June 2026) — multi-section pipe shell (closes #180)

**PATCH — additive API.** Adds `Shape.pipeShellMultiSection(spine:profiles:mode:withContact:withCorrection:solid:)`,
the multi-section form of `pipeShell`. Several profiles positioned along the spine are swept into a
single variable cross-section solid/shell via repeated `BRepOffsetAPI_MakePipeShell::Add`. Supports
all orientation modes including `.auxiliary(spine:)`, so a thread rib can ramp from a runout to full
crest along a helix while staying radial — the worm-thread case that single-profile `pipeShellWithLaw`
(Frenet-only, degenerates on near-zero scaling) could not express.

```swift
Shape.pipeShellMultiSection(spine: helix, profiles: [fullRib, runoutRib], mode: .auxiliary(spine: axis))
```

### v1.3.2 (June 2026) — fix loft (ThruSections) SIGSEGV on mismatched profiles (closes #176)

**PATCH — robustness fix, no API change.** `Shape.loft` (and any `BRepOffsetAPI_ThruSections`
path) could SIGSEGV and abort the host process on mismatched closed profiles — e.g. machine-generated
profile sets with differing vertex counts. The crash is an upstream OCCT null dereference in
`BRepFill_CompatibleWires::SameNumberByPolarMethod` (unguarded correspondence-list iterator
over-advance); because it surfaces as an OS signal, the bridge's `catch(...)` could not intercept it.

Fixed by carrying a minimal source patch
(`Scripts/patches/0001-BRepFill_CompatibleWires-guard-polar-iterator.patch`, applied by
`build-occt.sh`) and rebuilding the xcframework. Loft now fails gracefully (`nil`) on such inputs.
Reported and fixed upstream: OpenCASCADE/OCCT issue #1297, PR #1298.

Note: the `OCC_CATCH_SIGNALS` guards added in v1.2.1/v1.2.2 are inert in this build (OCCT is not
compiled with `OCC_CONVERT_SIGNALS`) and do not provide signal safety; this patch addresses the
crash at its source instead.

### v1.3.1 (June 2026) — feature-aware patterning, sweep orientation, geometric edge selection (closes #169, #170, #171)

**PATCH — additive helpers + one orientation fix.** Three ergonomics gaps surfaced building the
OCCTSwiftScripts cookbook recipes (pipe-flange, helical-spring, mounting-bracket). No C++ bridge
change — everything composes existing tested primitives.

- **#169 — feature-level circular pattern.** `circularPattern` duplicates the *body*, so the
  bolt-circle intent ("drill one hole, repeat it around the axis") produced overlapping flange
  copies with the holes filled in. New `Shape.circularPatternCut(tool:axisPoint:axisDirection:count:angle:)`
  patterns the *tool* and subtracts the compound in one call; `circularPattern`'s doc now warns it
  patterns the body, not features.

  ```swift
  let flange = blank.circularPatternCut(tool: hole, axisPoint: .zero,
                                        axisDirection: SIMD3(0,0,1), count: 8)
  ```

- **#170 — sweep orientation.** `Shape.sweep` (`BRepOffsetAPI_MakePipe`) could yield an
  inward-oriented (negative-volume) solid depending on the section wire's sense vs. the path
  tangent — a hazard for booleans and `volume > 0` checks. `sweep` now orientation-normalises its
  result. New `Shape.orientedForward()` applies the same fix explicitly, and `Shape.signedVolume`
  exposes the signed `BRepGProp` mass for orientation diagnostics (unlike `volume`, which masks
  negatives as `nil`).

- **#171 — geometric edge selection.** Picking fillet edges by raw `edges()` index is fragile —
  the index shifts with parameters. New selectors return edges that feed straight into
  `filleted(edges:radius:)`: `concaveEdges()` / `convexEdges()` (classified via `BRepOffset_Analyse`),
  `edges(where:)`, `edges(parallelTo:tolerance:)`, and `edges(inBounds:_:)`.

  ```swift
  let rounded = bracket.filleted(edges: bracket.concaveEdges(), radius: 3)
  ```


### v1.3.0 (June 2026) — full 4×4 XCAF component locations (closes #174)

**MINOR — additive new public API.** XCAF assembly components could previously only be placed by a
translation, so true instanced assemblies (shared geometry under arbitrary rigid transforms) lost
their rotations. `Document.addComponent(matrix:)` now accepts a full 4×4 placement (row-major 12),
and shape-driven instancing via `Shape.located(matrix:)` + `addShape(makeAssembly: true)` dedupes by
shared `TShape` so each unique solid is written once with N located occurrences.

### v1.2.2 (June 2026) — broaden OCC signal guards (#175)

**PATCH — robustness.** Extended `OSD::SetSignal` + `OCC_CATCH_SIGNALS` coverage to the validity,
volume, boolean, extrude, and revolve bridge paths (on top of v1.2.1's loft/mesh/transform guards),
so more degenerate-input failures surface as caught errors rather than aborting the process. Note:
`OCC_CATCH_SIGNALS` is a no-op unless `OCC_CONVERT_SIGNALS` is defined, and converting via
setjmp/longjmp bypasses C++ unwinding — so this hardens, but does not fully tame, deterministic
SIGSEGVs on degenerate machine-generated geometry (see #176).

### v1.2.1 (June 2026) — OCC signal handling on loft/mesh/transform (#175)

**PATCH — robustness.** Installed `OSD::SetSignal` and wrapped the loft (ThruSections), mesh, and
transform bridge entry points in `OCC_CATCH_SIGNALS` so OCCT hardware-signal faults on those paths
convert to catchable failures instead of crashing the caller.

### v1.2.0 (June 2026) — TopologyGraph attribute store + Codable snapshot (closes #168)

**MINOR — additive new public API.** `TopologyGraph` nodes were bare `(kind, index)` pairs with
no payload, and the type had no serialization (it wraps an opaque C++ handle). This adds a pure
Swift-side sidecar so callers can attach arbitrary typed metadata to any `NodeRef` and round-trip
it. No C++ bridge change — the store never touches the C++ graph.

```swift
extension TopologyGraph {
    public var attributes: NodeAttributeStore            // per-node typed metadata
    public func attribute(_ key: String, for: NodeRef) -> AttrValue?
    public func setAttribute(_ key: String, _ value: AttrValue, for: NodeRef)
    public func snapshot() throws -> GraphSnapshot        // export attributes + source shape
    public convenience init(snapshot: GraphSnapshot) throws  // rebuild + reattach
}
```

- `AttrValue` — closed Codable enum: `bool` / `int` / `double` / `string` / `ints` / `doubles`
  (`ints` for mesh-region index sets, `doubles` for fitted-surface params).
- `NodeAttributeStore` — Codable, keyed by `NodeRef`, encodes as sorted arrays so element order
  is deterministic; pair with `GraphSnapshot.canonicalEncoder()` (`.sortedKeys`) for byte-stable,
  diffable output.
- `GraphSnapshot` — Codable round-trip. The graph *structure* is not serialized; it is re-derived
  by rebuilding from the source shape's BREP (captured at construction). Rebuild pins
  `parallel: false`; a determinism test verifies `NodeRef` indexing is stable across rebuilds.
- `NodeKind` and `NodeRef` gained `Codable`.

Foundation for the [OCCTReconstruct](https://github.com/gsdali/OCCTReconstruct) mesh-to-solid
pipeline (per-node fit residual / confidence / provenance + session persistence) and for OCCTMCP's
planned `reconstruct_*` read/write graph tools ([OCCTMCP #33](https://github.com/gsdali/OCCTMCP/issues/33)).

### v1.1.0 (May 2026) — TopologyGraph history disambiguation (closes #167)

**First MINOR bump under the [cohort SemVer policy](SEMVER.md).** Two new methods on `TopologyGraph` resolve the ambiguity in `findDerived`'s empty-result case:

```swift
extension TopologyGraph {
    /// True iff any history record names `original` as a key.
    public func hasHistoryRecord(for original: NodeRef) -> Bool

    /// findDerived if non-empty; else [] for explicitly-deleted nodes;
    /// else [original] for untouched nodes (still at the same index).
    public func findDerivedOrSelf(of original: NodeRef) -> [NodeRef]
}
```

`findDerived` returned `[]` for both "untouched" and "explicitly deleted" — selection-remap consumers couldn't tell which. `findDerivedOrSelf` is the typical "where did this node end up?" lookup: a single deterministic call that returns derivatives, `[]` for deleted, or `[original]` for untouched. `hasHistoryRecord` is the lower-level disambiguator for callers that want to handle the cases differently at the call site.

Implementation is a Swift-side scan over `historyRecords` — O(records × originals-per-record), which is fine for typical scenes. A bridge-side accelerator can land later if profiling ever justifies it.

**Downstream impact:** [OCCTMCP v1.3.0](https://github.com/gsdali/OCCTMCP/releases/tag/v1.3.0) currently works around this with an `isIdentityPreserving` flag on its `HistoryRegistry` for `transform_body` / `heal_shape`. Once OCCTMCP picks up this OCCTSwift bump, it can drop the flag for ops that record explicit modify/delete records and use per-node resolution.

**Op count: 4,284 → 4,286** (+2). xcframework binary unchanged from v1.0.0.

### v1.0.4 (May 2026) — wire applyFillet / applyChamfer through *WithFullHistory (closes #166)

Closes the explicit follow-up to v1.0.3: `FeatureReconstructor.BuildResult.histories[id]` now also covers `FeatureSpec.Fillet` and `FeatureSpec.Chamfer` with non-nil ids — every spec kind now resolves through OCCT's recorded history instead of the centroid-distance heuristic on the consumer side.

**Behavior changes:**

- `applyFillet` for all three `EdgeSelector` cases (`.all`, `.nearPoint`, `.onFeature`) now uses `Shape.filletedWithFullHistory(radius:edges:)` and records the returned `ShapeHistoryRef` in `ctx.histories[id]`.
- `applyChamfer` does the same via `Shape.chamferedWithFullHistory(distance:edges:)`. **Chamfer's `.nearPoint` and `.onFeature` selectors are now wired up** — they were stubbed to `recordSkip(.unsupported)` in v1.0.3 and earlier.
- Each path falls back to the index-less primitive (`filleted(radius:)` / `chamfered(distance:)`) on builder-nil to preserve existing back-compat semantics. Specs without ids continue to land directly on the non-history path.

**Internals:** the per-selector helpers now return `[Int]?` matching-edge-index lists instead of pre-cooked `Shape?` results. This consolidates the resolution machinery between fillet and chamfer (chamfer used to duplicate fillet's `.all`-only path because it had no shared resolver). The OCCTSwiftIO and OCCTMCP-side consumers that read `BuildResult.histories[id]` get fillet / chamfer coverage without any code change.

**Out of scope:** variable-radius fillet via `FeatureSpec` (the `filletedWithFullHistory(edge:startRadius:endRadius:)` Tier 2 variant) — `FeatureSpec.Fillet` only carries one `radius`. Variable-radius would be a new spec variant.

### v1.0.3 (May 2026) — full per-input history Tier 2 & Tier 3 (issue #165)

Completes [#165](https://github.com/gsdali/OCCTSwift/issues/165). Builds on the boolean-history surface in v1.0.2 by extending it to modification ops and threading history capture through `FeatureReconstructor`.

**Tier 2 — modification ops with full history (+5 ops):**

```swift
extension Shape {
    func filletedWithFullHistory(radius: Double, edges: [Int])
        -> (result: Shape, history: ShapeHistoryRef)?
    func filletedWithFullHistory(edge: Int, startRadius: Double, endRadius: Double)
        -> (result: Shape, history: ShapeHistoryRef)?
    func chamferedWithFullHistory(distance: Double, edges: [Int])
        -> (result: Shape, history: ShapeHistoryRef)?
    func shelledWithFullHistory(facesToRemove: [Int], thickness: Double, tolerance: Double = 1e-3)
        -> (result: Shape, history: ShapeHistoryRef)?
    func defeaturedWithFullHistory(faces: [Int])
        -> (result: Shape, history: ShapeHistoryRef)?
}
```

All five reuse the existing `OCCTBooleanHistory` opaque handle (the underlying type stores a `unique_ptr<BRepBuilderAPI_MakeShape>`, which is the common base of every OCCT modification builder). For consumers, the API matches Tier 1 — `history.record(of: inputSubShape)` returns the `ShapeHistoryRecord` of `Modified` / `Generated` / `IsDeleted` lookups.

**Tier 3 — `FeatureReconstructor.BuildResult.histories`:**

```swift
public struct BuildResult: Sendable {
    // … existing fields …
    public let histories: [String: ShapeHistoryRef]
}
```

Per-feature `ShapeHistoryRef` keyed by the feature id. Populated when:
- A boolean spec (`FeatureSpec.Boolean`) with non-nil id resolves successfully — captured from `unionWithFullHistory` / `subtractedWithFullHistory` / `intersectionWithFullHistory`
- A hole spec (`FeatureSpec.Hole`) with non-nil id — captured from the underlying subtract
- An additive feature (revolve/extrude/sheet-metal) with non-nil id whose `absorbAdditive` step fuses into a non-empty `current` — captured from the union

Features without an id aren't keyed, and the existing `applyFillet` / `applyChamfer` paths still go through the non-history primitives (those cases need edge/face index computation that's tracked as a separate refinement).

This unblocks [OCCTMCP](https://github.com/gsdali/OCCTMCP)'s `remap_selection` for the `apply_feature` tool: instead of falling back to centroid-distance heuristics on splits / merges / deletions, the consumer can now walk `BuildResult.histories[feature_id].record(of: subshape)` for the exact OCCT-recorded mapping.

**Op count: 4,279 → 4,284** (+5 Tier 2 entry points). xcframework binary unchanged from v1.0.0; SPM consumers continue to resolve against the v1.0.0 asset.

### v1.0.2 (May 2026) — per-input boolean history (issue #165 Tier 1)

**Additive feature for selection-remapping consumers** ([#165](https://github.com/gsdali/OCCTSwift/issues/165)). Adds a per-input-subshape history lookup surface to the four `BRepAlgoAPI` boolean ops, addressing OCCTMCP's `remap_selection` need to walk selection IDs across boolean / split mutations exactly (instead of the centroid-distance heuristic that loses on splits / merges / deletions):

```swift
extension Shape {
    func unionWithFullHistory(_ other: Shape) -> (result: Shape, history: ShapeHistoryRef)?
    func subtractedWithFullHistory(_ tool: Shape) -> (result: Shape, history: ShapeHistoryRef)?
    func intersectionWithFullHistory(_ other: Shape) -> (result: Shape, history: ShapeHistoryRef)?
    func splitWithFullHistory(by tool: Shape) -> (pieces: [Shape], history: ShapeHistoryRef)?
}

public final class ShapeHistoryRef: @unchecked Sendable {
    func record(of inputSubShape: Shape) -> ShapeHistoryRecord  // .modified / .generated / .isDeleted
}
```

The `ShapeHistoryRef` retains the OCCT builder so `Modified` / `Generated` / `IsDeleted` stay queryable after the operation completes. Existing `BooleanResult` / `BooleanHistoryResult` callers are unchanged — pure additive surface.

**Bug fix on the way.** While building the history-handle plumbing I found that the new probe-then-fill helpers returned `0` when called with `maxCount=0` (or `outRefs=null`), breaking the Swift-side count-then-allocate idiom. Fixed: the new bridge functions now always return the full count and only stop *writing* when `count >= maxCount`. Existing callers were unaffected (none used the probe path).

xcframework binary unchanged from v1.0.0 (no OCCT version change). SPM consumers continue to resolve against the v1.0.0 asset.

**Out of scope for this release** (will land in follow-ups under #165 Tiers 2 / 3): `filletedWithFullHistory` / `chamferedWithFullHistory` / `shelledWithFullHistory` / `defeaturedWithFullHistory`, and `FeatureReconstructor.BuildResult.history`.

### v1.0.1 (May 2026) — TopologyGraph.rootNodes fix + test repair

**Bug fix.** `TopologyGraph.NodeKind` was missing `product = 10` and `occurrence = 11` cases, so `rootNodes` silently returned `[]` even when products were present (`compactMap { NodeKind(rawValue: 10) }` filtered every entry out as `nil`). After OCCT 8.0.0 beta1 reshaped root iteration to "Products only", every `rootNodes` consumer hit this. Fixed by extending the enum to cover the full `BRepGraph_NodeId::Kind` range (topology 0–8, assembly 10–11; slot 9 reserved upstream).

**Tests.** The four pre-existing failures shipped with v1.0.0 are repaired:

- `hasRoots` and `childExplorer` now wrap the box's solid in a Product via `linkProductToTopology` before querying `rootNodes` (matches OCCT 8.0 GA assembly semantics).
- `edgeVertexDistance` switched from low-level `BRepExtrema_DistanceSS` (which deliberately skips edge-vertex pairs whose closest point is at an endpoint, expecting the caller to also pair vertices-with-vertices) to high-level `Shape.distance(to:)` backed by `BRepExtrema_DistShapeShape`, which orchestrates all subshape combinations including endpoint cases.
- `edgeSelectorFeatureUnsupported` deleted — it asserted `Fillet.onFeature` was unsupported, contradicting the newer `filletOnFeature` test that asserts the opposite. `.onFeature` is wired up in `FeatureReconstructor`.

xcframework binary is unchanged from v1.0.0; SPM consumers continue resolving against the v1.0.0 asset.

### v1.0.0 (May 2026) — OCCT 8.0.0 GA — SemVer-stable

**OCCTSwift reaches SemVer-stable v1.0.0**, pinned to **OpenCASCADE Technology 8.0.0 GA** (released 2026-05-07, commit `d3056ef8` on `Open-Cascade-SAS/OCCT`). After eight months of pre-1.0 development across 170+ point releases — wrapping ~4,275 OCCT operations across 1,160+ test suites — the public Swift API is stable from this point on. Pin to `from: "1.0.0"` in `Package.swift`.

**OCCT 8.0.0 GA highlights since rc5** (per [OCCT discussion #1275](https://github.com/Open-Cascade-SAS/OCCT/discussions/1275)):

- BRepGraph (graph-based topology) and Gordon Surfaces shipped in their final shape
- TKHelix toolkit (geometric helix with B-spline approximation)
- ExtremaPC specialized point-to-curve extrema with variant dispatching
- STEP read/write thread safety: "safe under the contract of one reader or writer per thread"
- Multiple SEGV fixes in chamfer, fillet, and pipe-shell operations
- BSpline evaluation bugs corrected; geometry hashing implementations completed
- C++17 minimum (already required by Swift 6); `Standard_Failure` inherits `std::exception`

**Beta2 → GA breaking changes absorbed in this release:**

- **`PointSetLib` removed.** OCCT introduced `PointSetLib_Props` / `PointSetLib_Equation` in 8.0.0 beta1 (rc5/PCA point-cloud analysis) and removed them before GA. The Swift `PointSetLib` enum and bridge wrappers were deleted to follow upstream. If you depended on `PointSetLib.properties / barycentre / inertiaMatrix / equation`, port to your own NumPy/Accelerate implementation; the OCCT primitives are no longer available at any layer.
- **CoEdge continuity setters consolidated into `setEdgeRegularity`.** OCCT 8.0.0 GA moved continuity from per-coedge to per-`(edge, face1, face2)` (in `BRepGraph_LayerRegularity`). The pre-GA `setCoEdgeContinuity` / `setCoEdgeSeamContinuity` / `setCoEdgeSeamPairId` are replaced by a single `TopologyGraph.setEdgeRegularity(_:face1:face2:continuity:) -> Bool`. For seam continuity, pass the same face index as `face1` and `face2`. Explicit seam-pair-id is gone — seam-pair-id is structural in GA (two coedges on the same edge/face with opposite orientations); query via the existing `coedgeSeamPair` accessor.

**Removed deprecated:**

- **`TopologyGraph.occurrenceParentOccurrence(_:)`** — deprecated in v0.157.0 when OCCT 8.0.0 beta1 reshaped assembly topology to `Product → Occurrence → Product`. Use `occurrenceParentProduct(_:)`.

**Looking ahead:** OCCTSwift now moves to a **work-on-branch strategy** for upstream OCCT changes; `main` stays release-quality. Future OCCT releases land in feature branches and graduate to a tagged OCCTSwift release only when the upstream is GA.

### v0.171.0 (May 2026) — ML-export hoist to OCCTSwiftIO

**Breaking change.** The consumption-side ML repacking layer added in v0.136.0 (`TopologyGraph.GraphExport`, `exportForML()`, `exportJSON()`) has been removed and lifted to [OCCTSwiftIO](https://github.com/gsdali/OCCTSwiftIO) v0.2.0 per [OCCTSwiftIO#1](https://github.com/gsdali/OCCTSwiftIO/issues/1) (supersedes [OCCTSwift#71](https://github.com/gsdali/OCCTSwift/issues/71)). It's pure batch / headless workflow with no Viewport dependency — fits the OCCTSwiftIO charter, doesn't need to live in the kernel.

**What stays in the kernel** (and why): `FaceGridSample`, `sampleFaceUVGrid(faceIndex:uSamples:vSamples:)`, and `sampleEdgeCurve(edgeIndex:count:)`. Their implementations call C bridge functions on `TopologyGraph.handle`, which is `internal` to this module. Lifting them would require widening visibility — explicitly out of scope per the partial-lift decision recorded on the issue.

**Consumer migration:** direct callers of `exportForML` / `exportJSON` must add `import OCCTSwiftIO` alongside `import OCCTSwift`. Symbol resolution otherwise unchanged. Known external callers swept: `OCCTSwiftScripts/Sources/occtkit/Commands/GraphML.swift`, `OCCTSwiftScripts/Sources/GraphML/main.swift`.

**Net deltas:** −124 LOC in `BRepGraph.swift`, −76 LOC in `ShapeTests.swift`. xcframework binary unchanged (no bridge changes).

### v0.170.1 (May 2026) — ShapeMeasurements kernel hoist + OCCTBridge.mm split complete

**ShapeMeasurements moved to kernel** ([#100](https://github.com/gsdali/OCCTSwift/issues/100), [PR #163](https://github.com/gsdali/OCCTSwift/pull/163)). `ShapeMeasurements` (per-face areas / centroids / perimeters + per-edge lengths) and `Shape.measure(linearTolerance:)` are now part of `OCCTSwift` itself, no longer requiring a dependency on `OCCTSwiftTools`. Pure Swift relocation — no bridge changes. Existing `OCCTSwiftTools.ShapeMeasurements` callers should re-target to `import OCCTSwift` once `OCCTSwiftTools` ships its dep bump (tracked in [OCCTSwiftTools#13](https://github.com/gsdali/OCCTSwiftTools/issues/13)).

**OCCTBridge.mm split — DONE** ([#99](https://github.com/gsdali/OCCTSwift/issues/99), PRs #160-#162). The monolithic `OCCTBridge.mm` is now **393 lines** of pure foundation (header includes, global mutex, `OCCTSewing` struct, `Internal.h` import) — down from 58,168 lines pre-split (−99.3%). All 4,281 operations live in 15 per-OCCT-module translation units (`OCCTBridge_Modeling.mm`, `OCCTBridge_Topology.mm`, `OCCTBridge_Healing.mm`, `OCCTBridge_Properties.mm`, `OCCTBridge_Geom2d.mm`, `OCCTBridge_Surface.mm`, `OCCTBridge_Curve3D.mm`, `OCCTBridge_Document.mm`, `OCCTBridge_IO.mm`, `OCCTBridge_Mesh.mm`, `OCCTBridge_Spatial.mm`, `OCCTBridge_BRepGraph.mm`, `OCCTBridge_AIS.mm`, `OCCTBridge_Visualization.mm`, `OCCTBridge_ProjLib_NLPlate.mm`). Net-zero behavior change throughout; public C surface unchanged. The xcframework binary is identical to v0.170.0 (no OCCT changes), so SPM consumers can continue using the v0.170.0 binary URL.

### v0.170.0 (May 2026) — OCCT 8.0.0-beta2 ingest

xcframework rebuilt against `V8_0_0_beta2`. No public API changes — beta2 is a small follow-up to beta1 with no API breakage. Final 8.0.0 release remains targeted for May 7, 2026.

Upstream changes that landed in beta2:

- **Thread-safe STEP write + STEP/IGES read** ([OCCT #1259](https://github.com/Open-Cascade-SAS/OCCT/pull/1259)) — fixes `libmalloc` double-free under concurrent `STEPControl_Writer::Transfer` and intermittent crashes in concurrent STEP/IGES readers. Contract: one reader/writer per thread; STEP read + write safe under that contract; IGES read still requires explicit serialization. OCCTSwift already serializes IGES via `igesMutex()` and STEP via `occtGlobalMutex()`, so the upstream fix is a net safety improvement without requiring bridge changes.
- **CPU grid path restored** ([OCCT #1252](https://github.com/Open-Cascade-SAS/OCCT/pull/1252)) — the classical `Graphic3d_Structure`-based grid removed in beta1 is back as a coexisting backend. Doesn't surface in OCCTSwift (no grid API exposed).
- **Documentation refresh + samples directory + CI warning cleanup** — internal to upstream; no impact on consumers.

OCCTSwift surface unchanged: 4,281 wrapped operations, 3,393 tests, 1,178 suites, identical Swift `OCCTSwift.*` API.

### v0.169.0 (May 2026) — Mesh + export progress (issue #98 follow-up)

Extends the `ImportProgress` channel from v0.168 to two more long-running OCCT operations called out as out-of-scope in the original issue: `BRepMesh_IncrementalMesh::Perform` and the STEP / IGES writers. Same protocol, same cancellation contract.

**New Swift API**:

```swift
extension Shape {
    /// Run BRepMesh_IncrementalMesh with progress + cooperative cancellation.
    /// Throws ImportError.cancelled if cancelled.
    @discardableResult
    public func meshWithProgress(
        linearDeflection: Double = 0.1,
        angularDeflection: Double = 0.5,
        progress: ImportProgress? = nil
    ) throws -> Shape
}

extension Exporter {
    /// Export a shape to STEP with progress + cancellation.
    /// Throws ExportError.cancelled if cancelled.
    public static func writeSTEP(shape: Shape, to url: URL, progress: ImportProgress?) throws

    /// Export a shape to IGES with progress + cancellation.
    public static func writeIGES(shape: Shape, to url: URL, progress: ImportProgress?) throws
}

extension Document {
    /// Write the document to a STEP file with progress + cancellation.
    /// Throws ImportError.cancelled if cancelled.
    public func writeSTEP(to url: URL, progress: ImportProgress?) throws
}

extension ExportError {
    case cancelled
}
```

**Bridge plumbing**: 5 new entry points (`OCCTShapeIncrementalMeshProgress`, `OCCTExportSTEPProgress`, `OCCTExportSTEPWithModeProgress`, `OCCTExportIGESProgress`, `OCCTDocumentWriteSTEPProgress`) reusing the existing `BridgeProgressIndicator` from v0.168. `BRepMesh_IncrementalMesh::Perform(Message_ProgressRange&)`, `STEPControl_Writer::Transfer(...range)`, `IGESControl_Writer::AddShape(...range)`, and `STEPCAFControl_Writer::Transfer(...range)` all accept the indicator's progress range.

**Why `ImportProgress` is the type for export too**: it's the same channel — progress + cancel. Adding parallel `ExportProgress`/`MeshProgress` protocols would multiply types without functional benefit. The protocol name reads slightly oddly in export contexts; pre-1.0 we accept that, and v1.0 will likely rename to `OperationProgress`.

6 new tests cover meshing progress + cancellation, STEP/IGES export with `progress: nil` (back-compat), STEP export progress fires, and `Document.writeSTEP(to:progress:)` round-trip.

### v0.168.0 (May 2026) — STEP/IGES import progress + cancellation (issue #98)

Wraps OCCT's `Message_ProgressIndicator` so callers of `Shape.loadSTEP / loadIGES / loadIGESRobust` and `Document.load / loadSTEP` can observe progress and cooperatively cancel long-running imports.

**New Swift API**:

```swift
public protocol ImportProgress: AnyObject, Sendable {
    func progress(fraction: Double, step: String)
    func shouldCancel() -> Bool   // default: false
}

extension ImportError {
    case cancelled
}

extension Shape {
    public static func loadSTEP(from url: URL, progress: ImportProgress? = nil) throws -> Shape
    public static func loadSTEP(from url: URL, unitInMeters: Double, progress: ImportProgress? = nil) throws -> Shape
    public static func loadIGES(from url: URL, progress: ImportProgress? = nil) throws -> Shape
    public static func loadIGESRobust(from url: URL, progress: ImportProgress? = nil) throws -> Shape
}

extension Document {
    public static func load(from url: URL, progress: ImportProgress? = nil) throws -> Document
    public static func loadSTEP(from url: URL, progress: ImportProgress? = nil) throws -> Document
    public static func loadSTEP(from url: URL, modes: STEPReaderModes, progress: ImportProgress?) throws -> Document
}
```

`progress: nil` (the default) keeps existing call sites source-compatible — no behavioural change for callers that haven't opted in.

**Bridge plumbing**: 7 new `*Progress` C entry points in `OCCTBridge` plus an internal `BridgeProgressIndicator` subclass of `Message_ProgressIndicator` that forwards `Show()` to a Swift callback (via opaque `userData` + `@convention(c)` trampoline) and reports `UserBreak() == true` when the Swift `shouldCancel()` returns true. `STEPControl_Reader::TransferRoots`, `IGESControl_Reader::TransferRoots`, and `STEPCAFControl_Reader::Transfer` all accept the indicator's progress range.

**Cancellation contract**: `shouldCancel()` is polled at OCCT's progress checkpoints (typically once per transferred entity). Returning `true` causes the loader to throw `ImportError.cancelled` at the next boundary. The shape / document is not partially constructed.

4 new tests cover (1) progress callback fires for a round-tripped STEP file, (2) `progress: nil` back-compat path still works, (3) cancellation flag honored, (4) `Document.load` progress.

**Driver**: unblocks [OCCTSwiftTools](https://github.com/gsdali/OCCTSwiftTools) v0.4.0 — its `CADFileLoader.load(from:format:)` async API can now pass `progress` straight through, giving OCCTSwiftAIS' file-open dialog a real progress bar and cancel button "for free".

### v0.167.0 (May 2026) — visionOS + tvOS support

OCCT.xcframework now ships **seven slices**:

| Platform | Slice |
|---|---|
| macOS 12+ arm64 | `macos-arm64` |
| iOS 15+ device arm64 | `ios-arm64` |
| iOS 15+ Simulator arm64 | `ios-arm64-simulator` |
| visionOS 1+ device arm64 | `xros-arm64` (new) |
| visionOS 1+ Simulator arm64 | `xros-arm64-simulator` (new) |
| tvOS 15+ device arm64 | `tvos-arm64` (new) |
| tvOS 15+ Simulator arm64 | `tvos-arm64-simulator` (new) |

`Package.swift` declares `.visionOS(.v1)` and `.tvOS(.v15)` alongside the existing `.iOS(.v15)` / `.macOS(.v12)`. The xcframework asset attached to this release is ~341 MB (up from 148 MB at v0.165.0; quadruples the slice count).

**Build script changes** (`Scripts/build-occt.sh`) — required to make OCCT 8 cross-compile cleanly to visionOS and tvOS SDKs:

- Added four new build blocks (`visionOS device`, `visionOS Simulator`, `tvOS device`, `tvOS Simulator`).
- Each new block sets `-DCMAKE_SIZEOF_VOID_P=8` to bypass OCCT's `OCCT_MAKE_COMPILER_BITNESS` cmake macro, which couldn't autodetect pointer size on the visionOS SDK (`32 + 32*(/8)` syntax error from an empty `CMAKE_C_SIZEOF_DATA_PTR`).
- Removed explicit `-mtargetos=` / `-m*-version-min=` flags from the C/CXX flags — clang rejects them when CMake already sets `--target=arm64-apple-xros1.0` from the SDK + deployment target. Letting CMake derive the target is the correct path.
- xcframework creation step now conditionally includes each platform slice: if a slice fails to build (empty `.a`), the xcframework is built without it instead of aborting the whole script.

`OCCT.xcframework.zip` checksum: `5147b7d65cd9af5a6c3af1b38a1492365e645ed5c76a663bf9311c2f54043d87`.

### v0.166.1 (May 2026) — Platform plan refinement

Metadata-only patch revising the v1.0.0 platform expansion plan:

- **Dropped Intel Mac (`macOS x86_64`).** Apple is winding down Intel macOS support; not worth the build slot.
- **visionOS confirmed for v1.0.0.** Device + simulator slices.
- **tvOS reduced to "if cheap".** Will only add if it falls out of the visionOS work without extra effort.
- **Linux / Windows / Android — moved to "under review"** with a full analysis in [docs/platform-expansion.md](../docs/platform-expansion.md). Headline: Linux is the strongest non-Apple candidate (~2 weeks of focused work), Windows is medium-risk, Android should wait for Swift-on-Android packaging to stabilize. The prerequisite for any non-Apple port is the OCCTBridge `.mm` → `.cpp` audit, which is independently useful.

### v0.166.0 (May 2026) — Swift Package Index readiness

Preparation for a public listing on [Swift Package Index](https://swiftpackageindex.com) alongside v1.0.0. No code changes; metadata only.

**Added:**

- `.spi.yml` — SPI build matrix declaration:
  - macOS via SPM on Swift 6.0, 6.1, 6.2, 6.3
  - iOS on Swift 6.3
  - DocC documentation target: `OCCTSwift`
- `CODE_OF_CONDUCT.md` — short pointer to Contributor Covenant 2.1 with reports email.
- README:
  - SPI shields.io badges (Swift versions, platforms) — activate once the package is added to SPI.
  - Updated install snippet from stale `from: "0.128.0"` to current `from: "0.165.0"`.
  - "Supported Platforms" table covering current support and v1.0.0 expansion plan (Intel Mac, visionOS).
  - Documented Swift 6.1+ verified clean against 6.1 / 6.2 / 6.3 toolchains.

**Submission gating:** waiting until v1.0.0 ships (May 7, 2026, alongside OCCT 8.0.0 GA) before submitting to SPI. v0.166 makes the repo submission-ready.

### v0.165.0 (May 2026) — Fix SPM xcframework URL (issue #97)

`Package.swift` had its remote `binaryTarget(url:)` hardcoded to the **v0.131.0** xcframework — predating OCCT 8 by months. SPM consumers pinning `from: "0.157.0"` resolved the version correctly but the build failed at compile-time with `'BRepGraph_MeshView.hxx' file not found` because the v0.131.0 binary was built against rc-era OCCT and didn't ship the beta1 headers that the v0.157+ wrappers reference. Local-path consumers were unaffected (the auto-detect picks up `Libraries/OCCT.xcframework`).

This release:

1. Attaches the current beta1 xcframework as a release asset (`OCCT.xcframework.zip`, ~148 MB).
2. Updates `Package.swift`'s remote URL to point at the v0.165.0 release and bumps the SPM checksum to `99bba63c0e686195512cfaa4f3f46f9f11c8b6cd89e8fe5b8aed872a48978003`.

After this release, `from: "0.165.0"` resolves cleanly for remote-pin consumers and the v0.157.0 → v0.164.0 wrapper surface (MeshView, MeshCache, EditorView mutation, ProductOps, RepOps + cache inspection) becomes usable downstream. Downstream Package.swift consumers should bump their pin to `from: "0.165.0"`.

No new ops; this is purely a packaging fix.

### v0.164.0 (May 2026) — RepOps non-guard setters & cache entry inspection (21 ops)

Final wrapping pass for OCCT 8.0.0 beta1 BRepGraph surface. After this release, the public surface of `BRepGraph::EditorView` and `BRepGraph::MeshView` is exhaustively wrapped on `TopologyGraph`.

**RepOps non-guard setters** — swap geometry / mesh content bound to an existing rep id without recreating the rep:

```swift
graph.repSetSurface(repId, surface: newSurface)
graph.repSetCurve3D(repId, curve: newCurve3D)
graph.repSetCurve2D(repId, curve: newCurve2D)
graph.repSetTriangulation(repId, triangulation: newTri)
graph.repSetPolygon3D(repId, polygon: newPoly3D)
graph.repSetPolygon2D(repId, polygon: newPoly2D)
graph.repSetPolygonOnTri(repId, polygon: newPolyOnTri)
graph.repSetPolygonOnTriTriangulationId(polyOnTriRepId, triRepId: newTriRepId)
```

**Cache entry inspection** — detailed access to the algorithm-derived cache tier for diagnostics and non-destructive mesh tooling:

```swift
graph.cachedFaceMeshIsPresent(0)              // Bool
graph.cachedFaceMeshTriRepCount(0)            // Int
graph.cachedFaceMeshActiveIndex(0)            // Int (-1 if absent)
graph.cachedFaceMeshStoredOwnGen(0)           // UInt32 (cache freshness gen)
graph.cachedFaceMeshTriRepId(0, repIndex: 0)  // Int? (active or specific entry)

graph.cachedEdgeMeshIsPresent(0)
graph.cachedEdgeMeshPolygon3DRepId(0)
graph.cachedEdgeMeshStoredOwnGen(0)

graph.cachedCoEdgeMeshIsPresent(0)
graph.cachedCoEdgeMeshPolygon2DRepId(0)
graph.cachedCoEdgeMeshPolygonOnTriRepCount(0)
graph.cachedCoEdgeMeshPolygonOnTriRepId(0, repIndex: 0)
graph.cachedCoEdgeMeshStoredOwnGen(0)
```

The `StoredOwnGen` accessors expose the cache freshness generation — pair with the entity's current OwnGen (via existing readers) to detect stale cache entries.

3 new tests cover fresh-graph absence, post-`appendCachedTriangulation` state readback, and edge/coedge cache absence.

### v0.163.0 (May 2026) — EditorView ProductOps assembly building (5 ops)

Closes the **EditorView mutation surface**. With v0.163.0 the public mutation API of `BRepGraph::EditorView` is fully wrapped on `TopologyGraph`.

```swift
let parent = graph.createEmptyProduct()!
let child = graph.linkProductToTopology(
    shapeRootKind: 0, shapeRootIndex: 0,
    placement: TopologyGraph.identityLocationMatrix)!
let linked = graph.linkProducts(
    parentProductIndex: parent,
    referencedProductIndex: child,
    placement: TopologyGraph.identityLocationMatrix)!
// linked.occurrenceIndex, linked.occurrenceRefIndex

graph.productRemoveOccurrence(parent, occurrenceRefIndex: linked.occurrenceRefIndex)
graph.productRemoveShapeRoot(child)
```

`linkProductToTopology` accepts `placement: nil` for an identity placement. `linkProducts` takes a `parentOccurrenceIndex: Int?` (nil for unparented).

2 new tests cover the create/link path and remove-with-bogus-ids no-crash safety.

### v0.162.0 (May 2026) — EditorView geometric setters, location setters, PCurve API (16 ops)

Closes the EditorView wrapping started in v0.159.0. With v0.162.0 the public mutation surface of `BRepGraph::EditorView` is fully wrapped on `TopologyGraph`.

**CoEdge geometric setters:**
- `setCoEdgeUVBox(_:u1:v1:u2:v2:)`
- `setCoEdgeContinuity` / `setCoEdgeSeamContinuity` (GeomAbs_Shape: 0=C0, 1=C1, 2=C2, 3=C3, 4=CN)
- `setCoEdgeSeamPairId`

**Face geometric setter:**
- `setFaceTriangulationRep(_:triRepId:)` — bind the active triangulation to a face's persistent tier (vs `appendCachedTriangulation` for the cache tier)

**CoEdge PCurve API** (uses existing `Curve2D` Swift type):
- `coEdgeCreateCurve2DRep(_ curve2D:)` → rep id
- `coEdgeSetPCurve(_ coedgeIndex:curve2D:)` (pass nil to clear)
- `coEdgeAddPCurve(edgeIndex:faceIndex:curve2D:first:last:orientation:)`

**Location setters via 12-double 3x4 matrix** (`gp_Trsf::SetValues` row-major convention):
- `setVertexRefLocalLocation`, `setCoEdgeRefLocalLocation`, `setWireRefLocalLocation`
- `setFaceRefLocalLocation`, `setShellRefLocalLocation`, `setSolidRefLocalLocation`
- `setOccurrenceRefLocalLocation`, `setChildRefLocalLocation`
- Convenience: `TopologyGraph.identityLocationMatrix` returns the 3x4 identity

3 new tests cover CoEdge geometric setters on real coedges, identity-matrix location setters on real refs, and face-triangulation binding with MeshView readback.

### v0.161.0 (May 2026) — EditorView Add / Remove / Ref setters (41 ops)

Continues the EditorView wrapping started in v0.159.0 with the structural-mutation surface:

**Add operations** (return ref id or nil):
- `edgeAddInternalVertex(_:vertexIndex:orientation:)`
- `faceAddVertex(_:vertexIndex:orientation:)`
- `shellAddChild(_:childKind:childIndex:orientation:)`
- `solidAddChild(_:childKind:childIndex:orientation:)`
- `compoundAddChild(_:childKind:childIndex:orientation:)`
- `compSolidAddSolid(_:solidIndex:orientation:)`

**Remove operations** (return Bool indicating active-usage removal):
- `edgeRemoveVertex`, `edgeReplaceVertex` (returns new ref id)
- `wireRemoveCoEdge`, `faceRemoveVertex`, `faceRemoveWire`
- `shellRemoveFace`, `shellRemoveChild`
- `solidRemoveShell`, `solidRemoveChild`
- `compoundRemoveChild`, `compSolidRemoveSolid`
- `removeRep(repKind:repIndex:)` — generic representation removal

**Ref setters** (entity-ref → entity-def rebinding, orientation, rep-id binding):
- Vertex: `setVertexRefOrientation`, `setVertexRefVertexDefId`
- Edge: `setEdgeStartVertexRefId`, `setEdgeEndVertexRefId`, `setEdgeCurve3DRepId`, `setEdgePolygon3DRepId`
- CoEdge: `setCoEdgeRefCoEdgeDefId`, `setCoEdgeEdgeDefId`, `setCoEdgeFaceDefId`, `setCoEdgeCurve2DRepId`, `setCoEdgePolygon2DRepId`, `setCoEdgePolygonOnTriRepId`, `clearCoEdgePCurveBinding`
- Wire: `setWireRefIsOuter`, `setWireRefOrientation`, `setWireRefWireDefId`
- Face: `setFaceSurfaceRepId`, `setFaceRefOrientation`, `setFaceRefFaceDefId`
- Shell: `setShellRefOrientation`, `setShellRefShellDefId`
- Solid: `setSolidRefOrientation`, `setSolidRefSolidDefId`
- Occurrence: `setOccurrenceChildDefId`, `setOccurrenceRefOccurrenceDefId`
- Generic: `setChildRefOrientation`, `setChildRefChildDefId`

Setters that need `TopLoc_Location` or `Bnd_Box2d` (e.g. `*RefLocalLocation`, `CoEdge.SetUVBox`, `CoEdge.SetContinuity`) are deferred until a 12-double / 4-double calling convention lands in the bridge.

3 new tests cover Add no-crash safety, Remove returning false on bogus ref ids, and Ref setters operating on real box ids without crashing.

### v0.160.0 (May 2026) — MeshCache write API + new `Triangulation` type

Completes the OCCT 8.0.0 beta1 two-tier mesh storage wrapping started in v0.158.0. The cache write side — `BRepGraph_Tool::Mesh` static helpers — is now exposed on `TopologyGraph`, and a new `Triangulation` Swift class wraps `Handle<Poly_Triangulation>` for input.

**New `Triangulation` class** (mirrors the existing `Polygon3D` / `PolygonOnTriangulation` pattern):

```swift
let tri = Triangulation.create(
    nodes: [SIMD3(0,0,0), SIMD3(1,0,0), SIMD3(0,1,0), SIMD3(1,1,0)],
    triangles: [0,1,2, 1,3,2]
)!
tri.nodeCount        // 4
tri.triangleCount    // 2
tri.node(at: 0)      // SIMD3(0, 0, 0)
tri.triangle(at: 0)  // (0, 1, 2)
tri.deflection = 0.01
```

Vertex indices are 0-based on the Swift boundary; the bridge handles OCCT's 1-based convention internally.

**MeshCache write API** on `TopologyGraph`:

```swift
let triRepId = graph.createTriangulationRep(tri)!
graph.appendCachedTriangulation(faceIndex: 0, triRepId: triRepId)
graph.setCachedActiveIndex(faceIndex: 0, activeIndex: 0)

let polyRepId = graph.createPolygon3DRep(polygon3d)!
graph.setCachedPolygon3D(edgeIndex: 0, polyRepId: polyRepId)

let polyOnTriRepId = graph.createPolygonOnTriRep(polygonOnTri, triRepId: triRepId)!
graph.appendCachedPolygonOnTri(coedgeIndex: 0, polyRepId: polyOnTriRepId)
graph.setCachedPolygon2D(coedgeIndex: 0, poly2DRepId: ...)
```

This unblocks downstream tooling (OCCTMCP, OCCTSwiftScripts) that wants to populate algorithm-derived mesh data on a graph without touching the persistent (STEP-imported) tier — important for non-destructive meshing workflows.

4 new tests cover Triangulation construction round-trip, malformed-input rejection, and rep-creation + face/edge binding with subsequent MeshView readback.

### v0.159.0 (May 2026) — EditorView field setters

OCCT 8.0.0 beta1's `BRepGraph::EditorView` exposes per-entity `Ops` classes with `Set*` methods that mutate field-level data on existing graph entities (without requiring a full topology rebuild). v0.159.0 wraps the simple-value subset (scalars, bools, orientations) on the `TopologyGraph` Swift type:

**VertexOps** — `setVertexPoint(_:x:y:z:)`, `setVertexTolerance(_:tolerance:)`

**EdgeOps** — `setEdgeTolerance`, `setEdgeParamRange(_:first:last:)`, `setEdgeSameParameter`, `setEdgeSameRange`, `setEdgeDegenerate`, `setEdgeIsClosed`

**CoEdgeOps** — `setCoEdgeParamRange`, `setCoEdgeOrientation` (Forward/Reversed/Internal/External as Int 0–3)

**WireOps** — `setWireIsClosed`

**FaceOps** — `setFaceTolerance`, `setFaceNaturalRestriction`

**ShellOps** — `setShellIsClosed`

All 14 setters are pass-through to the corresponding `g.Editor().<Entity>().Set*(...)` on the OCCT side. Invalid ids are no-ops (try/catch in bridge). Setters that require new opaque types — `SetPCurve`, `SetSurfaceRepId`, `SetTriangulationRep`, `Mut*` RAII guards — are deferred. Same with `Add*` / `Remove*` mutation methods that aren't already wrapped via the Builder bridge functions.

Driver: lets headless tooling (OCCTMCP, OCCTSwiftScripts) tweak field-level data after constructing a graph (e.g. relax a tolerance, mark an edge degenerate) without round-tripping through `TopoDS_Shape` rebuilds.

4 new tests cover set-then-read-back where a getter exists, plus no-crash safety on the readback-less setters.

### v0.158.0 (May 2026) — MeshView two-tier mesh storage (read API)

OCCT 8.0.0 beta1 introduced a two-tier mesh storage model: an algorithm-derived **cache** (populated by `BRepGraphMesh`) and the **persistent** tier (mesh data imported from STEP, stored in topology definitions). v0.158.0 wraps the read-side of this model — `BRepGraph::MeshView` queries — exposing it on the existing `TopologyGraph` Swift type:

- Counts: `polygon2DCount`, `polygonOnTriCount`, `activeTriangulationCount`, `activePolygon3DCount`, `activePolygon2DCount`, `activePolygonOnTriCount`. Pairs with the existing `triangulationCount` / `polygon3DCount` from v0.133.0.
- Per-entity cache-first queries:
  - `meshFaceActiveTriangulationRepId(_ faceIndex:)` → optional rep id (cache-first, persistent fallback)
  - `meshEdgePolygon3DRepId(_ edgeIndex:)` → optional rep id (cache-first, persistent fallback)
  - `meshCoEdgeHasMesh(_ coedgeIndex:)` → bool (cache-only)

The Swift API is unchanged for existing call sites. Driver: prep for future BRepGraphMesh-driven workflows in OCCTMCP / OCCTSwiftScripts that want to introspect mesh state without invalidating the persistent tier.

The mesh **write** API (`BRepGraph_Tool::Mesh::CreateTriangulationRep` etc.) is intentionally not yet wrapped — it requires marshaling `Handle<Poly_Triangulation>` from Swift, which is a larger lift. Targeted for v0.159 or v1.0.

### v0.157.0 (May 2026) — OCCT 8.0.0 beta1 support (final pre-1.0 release)

xcframework rebuilt against `V8_0_0_beta1`. v1.0.0 will follow on May 7, 2026 pinned to the OCCT 8.0.0 GA tag.

Bridge migrations driven by upstream API churn since rc5:

- **`BRepGraph_BuilderView` removed** ([OCCT #1237](https://github.com/Open-Cascade-SAS/OCCT/pull/1237)) → migrated all 22 mutation entry points to `BRepGraph_EditorView`. Old: `g.Builder().AddVertex(p, t)`; new: `g.Editor().Vertices().Add(p, t)`. Swift API surface unchanged.
- **`NCollection_Vector` deprecated** ([OCCT #1230](https://github.com/Open-Cascade-SAS/OCCT/pull/1230)) → switched 4 internal sites to `NCollection_DynamicArray`, including the `BRepGraph_History::Record` mapping container.
- **`Builder().AppendFlattenedShape` / `AppendFullShape` consolidated** → both now route through the static `BRepGraph_Builder::Add(graph, shape, options)`. The `Flatten` and `CreateAutoProduct` options preserve the pre-beta1 distinction.
- **`Builder().ClearFaceMesh` / `ClearEdgePolygon3D` moved** → now `BRepGraph_Tool::Mesh::ClearFaceCache` / `ClearEdgeCache`. Semantic shift: clears only the new cached-mesh tier, not persistent (STEP-imported) mesh data.
- **`graph.Build(shape, parallel)` removed** → wrapper now calls the static `BRepGraph_Builder::Add(graph, shape, opts)` with `CreateAutoProduct = false` to preserve the historical "no auto Product wrap" behaviour.
- **`graph.RootNodeIds()` → `graph.RootProductIds()`** — root iteration is now Products only.
- **`BRepGraph_Copy::CopyFace` → `CopyNode`** — single-node deep copy now takes any NodeId kind.
- **`Topo().Occurrences().ParentOccurrence` removed** — beta1 model is `Product → Occurrence → Product`; an occurrence has no parent occurrence. Wrapper retained as `-1` sentinel for ABI; will be removed in v1.0.
- **`BRepGraph_ChildExplorer::Current()` returns `BRepGraphInc::NodeInstance`** (was `NodeUsage`); field accessor unchanged.
- **`BRepGraph_Tool::Edge::StartVertex` / `EndVertex` renamed** to `StartVertexId` / `EndVertexId`; return type simplified from a `VertexRef` struct to `BRepGraph_VertexId`.
- **`Topo().Poly().Nb*` moved to `Mesh().Poly().Nb*`** — triangulation/polygon counts live on the new MeshView, paired with the two-tier mesh storage.

New beta1 surface (`BRepGraph_MeshCache`, `BRepGraph_MeshView` read-side, `EditorView` per-entity Ops methods, `BRepGraph_Tool::Mesh` cache-write API) is **deferred to v0.158 / v1.0** — kept v0.157 minimal to preserve the soak window.

The 1300+ existing tests continue to pass under serial execution (`OCCT_SERIAL=1` with `--num-workers 1`); the pre-existing parallel-execution NCollection arm64 race remains the same as v0.156.

### v0.156.3 (Apr 2026) — `Document.node(at:)` warms up the labelId registry (issue #95)

The `Document.node(at:)` lookup added in v0.156.1 returned `nil` on a freshly-loaded STEP document if `rootNodes` hadn't been walked first. Cause: the bridge's labelId-to-`TDF_Label` registry is populated lazily via `registerLabel(...)` calls — `OCCTDocumentLabelIsNull(0)` reports null because `labels[0]` doesn't exist yet. `rootNodes` warms it up because `OCCTDocumentGetRootLabelId(handle, i)` calls `registerLabel`, but `OCCTDocumentGetRootCount` alone doesn't.

`node(at:)` now eagerly iterates root indices to register top-level labels before the IsNull check:

```swift
public func node(at labelId: Int64) -> AssemblyNode? {
    let rootCount = OCCTDocumentGetRootCount(handle)
    for i in 0..<rootCount { _ = OCCTDocumentGetRootLabelId(handle, i) }
    guard !OCCTDocumentLabelIsNull(handle, labelId) else { return nil }
    return AssemblyNode(document: self, labelId: labelId)
}
```

Deep-child labelIds aren't registered by this warmup — those are expected to have been registered earlier by an explicit traversal (e.g. via `node.children`). The contract docstring spells this out.

`mainLabel` was checked for the same lazy-init quirk and is fine as-is — `OCCTDocumentGetMainLabel` calls `registerLabel(main)` itself.

Driver: [OCCTSwiftScripts#23](https://github.com/gsdali/OCCTSwiftScripts/issues/23)'s `set-metadata` verb. The downstream workaround (`_ = document.rootNodes.count` before `node(at:)`) can be removed.

One new regression test: load a STEP doc, look up `node(at: 0)` *without* touching `rootNodes` first, expect a non-nil node with `labelId == 0`.

### v0.156.2 (Apr 2026) — Public `Mesh(vertices:normals:indices:)` constructor (issue #94)

`Mesh` had `internal init(handle:)` and no public way to construct from raw vertex/index arrays. This blocked sibling packages (notably [OCCTSwiftMesh](https://github.com/gsdali/OCCTSwiftMesh)) from returning `Mesh` instances produced by mesh-domain algorithms (decimation, smoothing, repair, remeshing) that operate purely on vertex/index buffers and have no B-Rep state.

```swift
let mesh = Mesh(
    vertices: [SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0)],
    indices: [0, 1, 2]
)
```

Optional `normals: [SIMD3<Float>]?` parameter — when nil, per-vertex normals are computed by averaging the face normals of adjacent triangles (smooth shading default). Per-triangle normals are always computed from the geometry. `faceIndices` is set to `-1` for every triangle (no B-Rep source).

Failable initializer rejects: empty inputs, index count not divisible by 3, indices out of range, mismatched normals count.

Bridge: one new symbol `OCCTMeshCreateFromArrays(vertices, vertexCount, normals, indices, indexCount) -> OCCTMeshRef?` — caller releases via the existing `OCCTMeshRelease`. Unblocks [OCCTSwiftMesh#1](https://github.com/gsdali/OCCTSwiftMesh/issues/1) (v0.1.0 — `Mesh.simplified(_:)` via vendored meshoptimizer).

7 new tests covering round-trip, computed-normals correctness, supplied-normals preservation, and all four invalid-input rejection paths.

### v0.156.1 (Apr 2026) — Public `AssemblyNode.labelId` + `Document.node(at:)` lookup (issue #93)

`AssemblyNode.labelId` was `internal` even though every other `Document` API works in terms of `Int64` labelIds (`removeShape(labelId:)`, `componentLabelId(...)`, `expandShape(labelId:)`, etc.). Consumers walking the assembly via `Document.rootNodes → AssemblyNode.children` couldn't read each node's `labelId` to identify it across calls. Driver: [OCCTSwiftScripts#23](https://github.com/gsdali/OCCTSwiftScripts/issues/23) (`occtkit inspect-assembly` / `set-metadata`) needs stable IDs that round-trip.

Two tiny additive changes:

```swift
// 1. labelId is now public
public let labelId: Int64

// 2. New lookup on Document
public func node(at labelId: Int64) -> AssemblyNode?
```

`node(at:)` validates the labelId via `OCCTDocumentLabelIsNull` (O(1), consistent with the rest of the int64-based Document API) and returns `nil` for unknown labelIds. LabelIds are stable within a single `Document` instance — round-trips with `rootNodes` traversal in the same session.

No bridge changes. Two new tests covering the round-trip and rejection of nonexistent labelIds.

### v0.156.0 (Apr 2026) — Quality release: drop deprecated `GCE2d_*` symbols

OCCT 8.0.0 deprecated the entire `GCE2d_Make*` family of 2D geometry constructors in favour of the canonical `GC_Make*2d` names — each old class is now literally a `using GCE2d_X = GC_X2d` typedef alias. This release migrates all internal C++ uses inside `OCCTBridge.mm` to the canonical names so we're no longer building against deprecated identifiers.

```
GCE2d_MakeArcOfCircle   → GC_MakeArcOfCircle2d
GCE2d_MakeArcOfEllipse  → GC_MakeArcOfEllipse2d
GCE2d_MakeArcOfHyperbola → GC_MakeArcOfHyperbola2d
GCE2d_MakeArcOfParabola → GC_MakeArcOfParabola2d
GCE2d_MakeCircle        → GC_MakeCircle2d
GCE2d_MakeEllipse       → GC_MakeEllipse2d
GCE2d_MakeHyperbola     → GC_MakeHyperbola2d
GCE2d_MakeLine          → GC_MakeLine2d
GCE2d_MakeMirror        → GC_MakeMirror2d
GCE2d_MakeParabola      → GC_MakeParabola2d
GCE2d_MakeRotation      → GC_MakeRotation2d
GCE2d_MakeScale         → GC_MakeScale2d
GCE2d_MakeSegment       → GC_MakeSegment2d
GCE2d_MakeTranslation   → GC_MakeTranslation2d
```

14 `#include` directives + ~30 internal symbol uses migrated. Bridge ABI unchanged: the bridge's own C function names (`OCTGCE2dMake*`) are preserved so Swift wrappers continue to call them by their existing names — this is a **non-breaking** internal hygiene release.

Operation count, test count, and suite count are unchanged — same OCCT objects, just constructed via canonical names. The `@Suite("GCE2d_MakeLine")` test label was renamed to `@Suite("GC_MakeLine2d")` for consistency. Source comments and `// MARK:` headers in `Sources/OCCTSwift/Curve2D.swift` and `Sources/OCCTSwift/Document.swift` were updated similarly.

This was the cleanup-half of a rescoped v0.156.0 plan. The OCAF/Message data introspection scope originally pencilled in for v0.156.0 was abandoned after a full audit revealed the project is at the asymptote of useful OCCT public surface — most flagged "missing" classes were already wrapped via the established `OCCTDocumentRef` + `int64_t labelId` pattern, and the genuinely unwrapped classes (~25 ops total: `gp_Vec2f/3f`, `GeomConvert_FuncCone/Cylinder/SphereLSDist`) are too small to justify a 100-op release on their own.

### v0.155.1 (Apr 2026) — `Wire(_:Shape)` convenience initializer (issue #91)

Completes the v0.154.0 trio. Recovers a typed `Wire` from a generic `Shape` that wraps a `TopoDS_Wire`, returning nil on type mismatch. Mirrors `Face(_:Shape)` and `Edge(_:Shape)`.

```swift
let box = Shape.box(width: 10, height: 10, depth: 10)!
let wireShapes = box.subShapes(ofType: .wire)
if let wire = Wire(wireShapes[0]) {
    // typed Wire recovered from a wire-typed Shape
}
```

Unblocks face-rebuild flows where existing inner wires (returned as `[Shape]` from `Shape.wires` or `subShapes(ofType: .wire)`) need to be passed back into `Shape.face(outer:holes:)` — previously those wires were stuck as `Shape` because the `Wire(handle:)` initializer was internal. Concrete motivating case: preserving both bore and chamfer outlines on the same mid-face when extracting countersink mid-surfaces in [UnfoldEngine](https://github.com/gsdali/UnfoldEngine).

Bridge: one new symbol `OCCTWireFromShape(OCCTShapeRef) -> OCCTWireRef?`.

### v0.155.0 (Apr 2026) — `SheetMetal.Builder`: convex bends (issue #89)

The v0.151–v0.153 builder only supported **concave** bends (L-bracket-style, where the two flanges' bodies overlap in volume around the seam). **Convex** bends — Z-section middle bends, offset brackets, gusseted brackets where one flange folds back on the opposite side — failed with `BuildError.filletFailed` because the seam edge is non-manifold (a kiss point with four boundary faces meeting at one line, which `BRepFilletAPI_MakeFillet` rejects).

v0.155 adds first-class convex bend support:

- **Auto-detected direction.** Each bend is classified concave or convex from the relative position of the two flanges' body centroids. No caller change needed; the existing v0.151–v0.153 fixtures (L, U, stepped Z) continue to build identically because they're all concave.

- **Convex bend material.** Convex bends build a **curved-triangle prism** that bridges the two flanges' outer-corner edges with a cylindrical fillet on the outside surface, then boolean-fuses with the flanges. The "kiss point" stays sharp on the inside (which is the natural CAD interpretation when the user's flange placements don't leave room for an inside cylinder); the outside is rounded to the bend radius.

- **`Bend` struct expanded** with optional explicit controls:
  - `angle: Double?` — bend angle in radians, signed (positive = concave, negative = convex). Nil means auto-infer from flange positions. Sign convention follows OCCT's right-hand rule: angles are CCW-positive about the bend axis derived from `cross(fromFlange.normal, toFlange.normal)`, with concave-positive matching how a CAD designer thinks about bends.
  - `insideRadius: Double` — replaces the legacy single `radius` (which still works as a convenience init).
  - `outsideRadius: Double?` — independent control of the outside fillet radius. Defaults to nil = match insideRadius for convex builds.
  - `materialThicknessAtBend: Double?` — allow thinner material in the bend region than the flange thickness, common in etched parts where a thinned bend line allows tighter folds without cracking.
  - `direction: BendDirection` — `.auto` (default), `.concave`, or `.convex` for explicit override.

- **The legacy `Bend(from:to:radius:)` initializer is unchanged.** All v0.151–v0.153 callers continue to work without modification.

The 93-face inside-corner-reinforcing-bracket from #89 (Z-section with both same-direction and convex bends) now builds cleanly. Test fixtures from the issue: symmetric Z, offset L with very short web, channel-with-flange, all pass.

Bridge: one new symbol `OCCTWireCreateArcThroughPoints(s, m, e)` for 3-point arc-wire construction (avoids the `gp_Ax2` X-direction ambiguity of the angle-based arc API). Exposed as `Wire.arc(start:midpoint:end:)`.

### v0.154.0 (Apr 2026) — `Face(_:Shape)` and `Edge(_:Shape)` convenience initializers

Two tiny additive bridge symbols and their Swift conveniences. Recovers a typed `Face` or `Edge` from a generic `Shape` that wraps a `TopoDS_Face` / `TopoDS_Edge` (returns nil on type mismatch). Useful when a method gives back a `Shape` (e.g. `subShapes(ofType: .face)`) and you want the typed wrapper to call methods like `area()`, `outerWire`, `length`, etc., directly.

```swift
let box = Shape.box(width: 10, height: 10, depth: 10)!
let faceShapes = box.subShapes(ofType: .face)
if let face = Face(faceShapes[0]) {
    print(face.area())   // 100
}
```

Bridge: `OCCTFaceFromShape(OCCTShapeRef) -> OCCTFaceRef?` and `OCCTEdgeFromShape(OCCTShapeRef) -> OCCTEdgeRef?`. Both return NULL when the shape's `ShapeType()` doesn't match. Unblocks the upcoming `UnfoldEngine` package, which builds on these.

### v0.153.0 (Apr 2026) — `SheetMetal.Builder` step-aware bends (issue #86)

The v0.151 `SheetMetal.Builder` implementation extruded each flange at its full profile, fused them, then filleted the seam edge. That works when both flanges have matching extents along the seam direction, but fails on **stepped seams** — flanges that meet along less than their full extent (a narrow tab on a wider base, a U-channel with sides narrower than the spine). OCCT can't cleanly fillet an edge that terminates at a free-face boundary, so the v0.151 builder reported `BuildError.filletFailed` and the downstream `OCCTDesignLoop` pipeline padded the narrower flange to match — both expensive and incorrect.

v0.153 lifts that limitation:

- `SheetMetal.Builder.build(flanges:bends:)` now computes the seam intersection between each pair of flanges in a bend and **splits the wider flange** at the intersection endpoints before extruding. The matched-extent middle piece carries the bend; the outer pieces stay flat. The fillet machinery from v0.151 runs unchanged on the matched-extent piece, where it's always well-formed.
- For matched-extent inputs (where v0.151 already worked), the result is identical: the splitting step is a no-op.
- Two new error cases: `BuildError.seamsDoNotOverlap(fromID:toID:)` if the two flanges' seam edges don't actually intersect along the seam line; `BuildError.nonRectangularStepFlange(id:)` if a flange would need to be split but its profile isn't axis-aligned-rectangular (rectangular profiles cover the issue's three test fixtures and the common cases; non-rectangular stepped seams are deferred).

The three reference fixtures from issue #86 all build cleanly:

- **L-bracket** with 80×40 base + 20×30 centred mounting tab.
- **Z-bracket** with 50×30 base + full-seam mid + 20×30 stepped top tab.
- **U-channel** with 100×40 spine + 80×15 stepped side flanges (narrower than the spine in the seam direction).

OCCTDesignLoop's `eval/describer_to_features.py` can drop its seam-padding workaround and emit actual described flange dimensions; the existing typed `SheetMetal.Flange` / `SheetMetal.Bend` API and the JSON envelope are unchanged.

The unrelated v0.151 limitation about the bend axis being on the *outside* corner (sharp inner corner, filleted outer corner) still applies — that's a different construction (real inside-radius + outside-radius bend) and is filed separately.

### v0.152.1 (Apr 2026) — `FeatureReconstructor.buildJSON` decodes `boolean` (issue #88)

`FeatureSpec.boolean` (with `op` ∈ `union | subtract | intersect`, `leftID`, `rightID`) has been wired through `applyBoolean` since the typed Swift API landed, and v0.152's `inputBody` makes it useful for cuts that reference the seeded body via `@input`. But the JSON decoder never picked it up — `FeatureEntry.init(from:)` had no `case "boolean":` branch, so JSON entries with `"kind": "boolean"` fell into the `default:` clause and were silently dropped.

- **Adds the `case "boolean":` decoder branch.** Reads `op` (string), `left`, `right`, optional `id`. Coding keys for these were already declared.
- **Bad `op` rawValue surfaces as a recordable skip** with reason `unsupported("boolean(op:smush)")` rather than throwing — matches the rest of the reconstructor's "graceful degradation" policy.
- **Unknown `kind` strings now also surface as `Skipped` entries** when the JSON entry carries an `id`. Reason: `unsupported("unknown JSON kind: …")`. Stage: `additive`. Without this, typos in `kind` and version-drift schemas were silently swallowed; now they're visible. Entries without an id continue to be silently ignored, matching the rest of `FeatureReconstructor` (the kernel only records skips when there's an id to attach them to).

Together these mean the `inputBody → boolean(@input, slot)` chain that v0.152 implies should work, actually does work end-to-end from JSON.

### v0.152.0 (Apr 2026) — `FeatureReconstructor.inputBody` for chained composition (issue #87)

`FeatureReconstructor.build(from:)` previously always started from an empty `BuildContext.current`, with the in-progress shape grown purely from additive feature entries. That blocks **chaining** — composing a body via one kernel API (e.g. `SheetMetal.Builder` from v0.151) and then cutting / finishing into it via the reconstructor. v0.152 makes the kernel itself accept a starting body.

- **Optional `inputBody` parameter on both build entry points:** `FeatureReconstructor.build(from: specs, inputBody: Shape? = nil)` and `FeatureReconstructor.buildJSON(_:inputBody:)`. When non-nil, `BuildContext.current` is seeded with the input and the input is registered in `namedShapes` under the sentinel id `@input`. When nil, behaviour is byte-for-byte identical to v0.151.
- **`FeatureReconstructor.inputBodySentinel`** — the literal string `@input`, exposed as a public constant so JSON envelopes and Swift callers share one source of truth. Boolean `leftID` / `rightID`, `Fillet.edgeSelector.onFeature`, and `Chamfer.edgeSelector.onFeature` all resolve `@input` via the standard `namedShapes` lookup — no separate code path. Last-write-wins semantics: a feature with `id == "@input"` shadows the seed, which is the obvious behaviour.
- **No JSON schema change.** Downstream callers using `buildJSON` pass `inputBody:` from Swift; the JSON envelope itself is unchanged. Within the envelope, references to `@input` are just regular id strings.
- **Stage ordering preserved.** Additive features still union onto whatever `current` is at the start of stage 1 (input or empty). Subtractive / finishing / annotation stages run with the same dispatch as v0.151. The existing `Skipped` reporting (under-determined / OCCT failure / unresolved-ref / unsupported) is unchanged.

The immediate driver is the sheet-metal → reconstructor chain referenced by [OCCTSwiftScripts#13](https://github.com/gsdali/OCCTSwiftScripts/issues/13): build a bent bracket via `SheetMetal.Builder`, then drill mounting holes into it with the reconstructor's hole-placement and `Skipped` machinery. The verb-side wiring downstream is one line — `FeatureReconstructor.buildJSON(envelope, inputBody: try GraphIO.loadBREP(at: path))`.

This is also the primitive the planned `Skipped` resume-from-last-good-shape behaviour will need: "given a partially-built shape, continue applying remaining specs" reduces to an `inputBody`-aware build.

**Out of scope:** multi-body input lists (use `Shape.compound` upstream), round-tripping face / edge tags from prior history (gone after BREP serialisation), reverse decomposition (`Shape → [FeatureSpec]`).

### v0.151.0 (Apr 2026) — Sheet-metal composition API (issue #85)

OCCT has no sheet-metal bend primitive and is not expected to grow one — CATIA / SolidWorks / FreeCAD all compose bends from extrude + union + fillet. v0.151 adds the canonical Swift-level composition so downstream consumers (OCCTDesignLoop's VLM reconstructor, scripts, MCP tooling) do not each reinvent it.

- **`SheetMetal.Flange`** — a closed 2D profile positioned in world space by explicit `(origin, uAxis, vAxis, normal)`. All three axes are independent so left-handed world placements (e.g. a flange normal along +Y with the profile reading +X / +Z) are expressible without handedness surprises. `vAxis` defaults to `cross(normal, uAxis)` when omitted.
- **`SheetMetal.Bend`** — names two flanges + an inside radius. No geometric data; the builder resolves the seam edge from the flange placements.
- **`SheetMetal.Builder.build(flanges:bends:)`** — extrudes each flange along its normal by `thickness`, fuses the bodies in order, then for each bend finds the seam edge(s) and applies `Shape.filleted(edges:radius:)`. Seam finding walks the fused shape's edges, keeps only those parallel to `cross(nA, nB)`, and selects the one whose midpoint lies on each flange's face that points *toward* the other flange — which uniquely identifies the bend and rejects the coincidental convex back corner.
- **`SheetMetal.BuildError`** — named cases for invalid thickness, empty flange list, duplicate/unknown IDs, invalid profile, extrusion/union/fillet failures, parallel flanges (no seam direction), and missing seam edge. `CustomStringConvertible` for direct logging.

**Known limitation:** stepped seams (flanges meeting along less than their full seam-direction extent, e.g. a narrow upright on a wider base) surface as `BuildError.filletFailed`. OCCT cannot cleanly round an edge that terminates at a free-face boundary; downstream callers should match flange widths along the seam or split the wider flange. Reverse-direction unwrap (bent BRep → flat cutting pattern) is the planned next addition to this namespace.

### v0.150.0 (Apr 2026) — Pure-Swift PDF + SVG export + BOM + balloons

Second half of the v0.149 → v0.150 drawing-automation arc. Drawings now have three readable output formats (DXF for engineering tools, PDF for humans, SVG for the web) plus the assembly-drawing primitives that make BOM-driven output a one-call operation.

- **`PDFWriter` + `Exporter.writePDF(drawing:to:pageSize:)` / `writePDF(sheet:body:to:)`** — pure-Swift PDF 1.4 writer. No UIKit / AppKit / Core Graphics dependency; works on macOS, iOS, and Linux. Helvetica font, one page per file, content stream installs a mm→pts CTM so staged geometry stays in drawing units. Per-layer ISO 128-20 stroke weights (0.5 mm VISIBLE / OUTLINE, 0.25 mm HIDDEN / CENTER / DIMENSION / TEXT, 0.18 mm HATCH) with dashed / chain patterns on HIDDEN / CENTER. Circles rendered as four cubic Bézier segments; arcs split into ≤90° Bézier chunks.
- **`SVGWriter` + `Exporter.writeSVG(drawing:to:)` / `writeSVG(sheet:body:to:)`** — pure-Swift SVG 1.1 writer. One `<g>` group per layer with stroke / stroke-width / stroke-dasharray attributes. Arcs emitted as native SVG `<path d="M… A …"/>`. ViewBox explicit or computed from content bounds. Drawing's mathematical Y (up) mapped to SVG's screen Y (down) via a group-level `scale(1,-1)`; each `<text>` carries its own counter-transform so glyphs read right-side up.
- **`DrawingAnnotation.balloon(Balloon)`** — new case carrying `itemNumber` + `centre` + `radius` + optional `leaderTo`. Rendered in every writer (DXF / PDF / SVG) as a circle + number text + optional leader line that exits the circle at the point nearest the target. `Drawing.addBalloon(itemNumber:at:leaderTo:radius:id:)` is the convenience entry point.
- **`BillOfMaterials`** — pure-Swift `Codable` value type. Seven-column table (ITEM / PART NO / DESCRIPTION / QTY / MAT / MASS / NOTES) with per-column default widths; caller populates `[Item]` and calls `render(into: DXFWriter, at:)`. Origin is the **bottom-right** anchor so the table grows up and to the left (idiomatic placement above a title block). `Sheet.renderBOM(_:into:at:)` convenience places the BOM right-aligned to the inner frame's top edge.
- **`DrawingDispatch.swift`** — shared internal annotation + dimension dispatcher used by `PDFWriter` and `SVGWriter`. `DrawingPrimitiveOps` struct bundles the five drawing primitives (addLine / addPolyline / addCircle / addArc / addText) as closures; a single dispatch path handles every `DrawingAnnotation` case (centreline, centermark, textLabel, hatch, cuttingPlaneLine, balloon) and every `DrawingDimension` case including tolerance rendering. `DXFWriter` continues to use its own inline logic — not because it couldn't be ported, but to keep its test coverage load-bearing and avoid regression risk.
- **`Exporter.pdfA3Landscape` / `pdfA4Landscape`** — named pts-space page-size constants. Also `PDFWriter.addDimension(_:)` / `SVGWriter.addDimension(_:)` mirror the DXF-side method added in v0.149 for ad-hoc dimension staging without a `Drawing`.

After v0.150, the only substantive drawing-layer gap is native DXF `DIMENSION` entities (still exploded LINE+TEXT), which remains demand-gated.

### v0.149.0 (Apr 2026) — Sheet automation + tolerance + ordinate dimensioning

First of a two-release arc closing the last substantive drawing-automation gaps: one-call multi-view layout, typed tolerance data on every dimension, and ISO 129-1 §9.3 ordinate dimensioning.

- **`Sheet.standardLayout(of:scale:margin:includeIso:)`** — composes front / top / side / optional isometric views of a `Shape` onto the sheet's inner frame as a 2x2 grid. Arrangement follows the sheet's `ProjectionAngle`: first-angle places top below front, third-angle places top above. Uniform scale is computed to fit the widest projected view; callers can pass a smaller `DrawingScale` to override. Returns a `StandardLayout` whose `PlacedView`s hold the original Drawings (attach dimensions per view before calling `render(into:)`).
- **`Drawing.addAutoDimensions(from:viewDirection:minRadius:dimensionOffset:bounds:)`** — heuristic dimensioner: adds a linear dimension for the projected X and Y extents of the shape's bounding box, plus a diameter dimension on every visible circular edge. Edge-on circles are skipped (mirrors the `addAutoCentermarks` detection); `minRadius` filters noise holes.
- **`DrawingTolerance`** — typed, `Codable` enum carried as `tolerance: DrawingTolerance` on every `DrawingDimension` payload (Linear, Radial, Diameter, Angular, Ordinate). Cases: `.none`, `.symmetric(Double)`, `.bilateral(plus:minus:)`, `.unilateral(Double)`, `.fitClass(String)`, `.limits(lower:upper:)`. Inline cases fold into the nominal label; multi-value cases render as stacked upper/lower TEXT in DXF at ~55% height, placed perpendicular to each dimension's text baseline.
- **`DrawingDimension.ordinate(Ordinate)`** — shared-origin X+Y dimensioning for CNC reference-datum workflows. Each feature carries its own position plus optional custom label; a single `tolerance` applies across all features. DXF emit draws a small origin cross, per-feature extension lines with ticks at the origin baseline, and offset labels perpendicular to each line. `Drawing.addOrdinateDimensions(origin:features:tolerance:id:)` is the convenience entry point. `DrawingDimension.Ordinate` + `Feature` are `Codable` for JSON-driven pipelines.
- **`DXFWriter.addDimension(_:)`** — public single-entity dispatch over every `DrawingDimension` case; useful for tests and for scripts that compose DXFs from dimension values without going through a `Drawing`.

### v0.148.0 (Apr 2026) — Drawing.append(_:) unified dispatcher

Small release closing #83 and #84 — both asked for the same thing: a public `Drawing.append(_:)` that dispatches every `DrawingAnnotation` case without the consumer-side switch blind spot.

- **`Drawing.append(_ annotation: DrawingAnnotation)`** — appends any `DrawingAnnotation` case (centreline, centermark, textLabel, hatch, cuttingPlaneLine). When new cases land, the dispatcher updates in one place, not in every consumer.
- **`Drawing.append(contentsOf: [DrawingAnnotation])`** — for factory output like `DrawingAnnotation.surfaceFinish(...)`, `.featureControlFrame(...)`, `.datumFeature(...)`, `.breakLine(...)`, `.cosmeticThreadSideView(...)` which all return arrays.
- **`Drawing.append(_ dimension: DrawingDimension)`** / `append(contentsOf: [DrawingDimension])` — symmetric for dimensions.

Downstream `replay(...)` helpers (OCCTSwiftScripts, OCCTSwiftPartsAgent) collapse to one-line `drawing.append(contentsOf: DrawingAnnotation.surfaceFinish(...))`. The existing `addCentreLine` / `addCentermark` / `addTextLabel` / `addHatch` / `addCuttingPlaneLine` typed factories continue to work unchanged; they're now a thin convenience over `append(_:)` conceptually (though the storage path is identical either way).

### v0.147.0 (Apr 2026) — Drawing + FeatureSpec consumer polish

Closes four small follow-up issues (#79, #80, #81, #82) that downstream consumers (OCCTSwiftScripts, OCCTDesignLoop, MCP tooling) asked for to remove boilerplate and unblock JSON-driven workflows.

- **#80 `Edge.curve3D`**: Direct `Edge → Curve3D` bridge. Ensures the 3D curve is built via `BRepLib::BuildCurves3d` for pcurve-only edges. Returns the raw `Geom_Curve` so consumers can call `curve.circleProperties` / `lineProperties` / etc. without DownCast gymnastics.
- **#79 `Drawing.addAutoCentermarks(from:viewDirection:extent:minRadius:bounds:)`**: symmetric to `addAutoCentrelines`. Walks circular edges, projects each centre into the view plane, adds `.centermark` annotations. Skips edges whose circle plane is parallel to the view (edge-on). `minRadius` filters small holes; `bounds` filters centermarks outside the view.
- **#81 `DrawingAnnotation.CuttingPlaneLine` + `Drawing.addCuttingPlaneLine`**: typed ISO 128-40 cutting-plane line. Computes trace in view 2D from cutting plane normal × view direction. DXFWriter renders heavy-chain ends, thin-chain middle, perpendicular arrows, and label letters at both ends.
- **#82 `FeatureSpec` Codable conformance**: `FeatureSpec` + all nested types (`Revolve`, `Extrude`, `Hole`, `Thread`, `EdgeSelector`, `Fillet`, `Chamfer`, `Boolean`) now `Codable`. Unblocks `FeatureReconstructor.buildJSON` + Python / MCP driven reconstruction pipelines without each consumer mirroring the types in their own schema.

### v0.146.0 (Apr 2026) — ISO drawings III: cosmetic threads, surface finish, GD&T symbols, detail views

Closes the ISO drawings arc (#78). Final release ships cosmetic threads (#77), ISO 1302 surface finish, ISO 1101 GD&T symbols, and compressed-view conventions (detail + break lines).

- **#77 `DrawingAnnotation.cosmeticThreadSideView` / `cosmeticThreadEndView`**: ISO 6410 cosmetic thread representation. Side view: two parallel lines at minor diameter spanning the thread length, optional callout text. End view: 3/4 broken arc set (0–90° / 90–180° / 180–315° with a 45° gap). `Drawing.addCosmeticThreadSide(...)` and `DXFWriter.addCosmeticThreadEndView(...)` convenience wrappers.
- **ISO 1302 surface finish**: `SurfaceFinishSymbol` enum (`.any` / `.machiningRequired` / `.machiningProhibited`). `DrawingAnnotation.surfaceFinish(at:leaderTo:ra:symbol:method:)` produces the check-mark geometry with Ra value label, horizontal bar for machiningRequired, optional production-method text, and leader line to the target feature.
- **ISO 1101 GD&T symbols**: `GDTSymbol` enum covering all 15 ASME/ISO geometric characteristics (straightness, flatness, circularity, cylindricity, profile of line/surface, perpendicularity, parallelism, angularity, position, concentricity, symmetry, coaxiality, circular runout, total runout). `DrawingAnnotation.featureControlFrame(at:symbol:tolerance:datums:leaderTo:)` emits the classic `[⌖] [0.1] [A] [B] [C]` rectangular frame. `DrawingAnnotation.datumFeature(label:at:pointingTo:)` emits the boxed letter + triangle pointer.
- **Detail views**: `Drawing.detailView(at:scale:)` returns a `TransformedDrawing` suitable for placing a scaled-up region of the parent drawing at a specific sheet location.
- **Break lines**: `DrawingAnnotation.breakLine(from:to:amplitude:)` emits ISO 128-30 compressed-length zigzag marker as 5 line segments.

### v0.145.0 (Apr 2026) — ISO drawings II: sheet templates, title blocks, projection symbols

Second release in the ISO drawings arc (#78). Closes #76 — adds ISO 5457 trimmed-sheet templates, ISO 7200 title blocks, and ISO 5456-2 projection symbols as first-class OCCTSwift API.

- **`PaperSize`**: `A0` / `A1` / `A2` / `A3` / `A4` with `.size(in: .landscape)` / `.portrait` returning ISO 5457 trimmed dimensions in mm.
- **`Orientation`**: `.landscape` / `.portrait`.
- **`ProjectionAngle`**: `.first` (ISO / Europe) / `.third` (ANSI / USA).
- **`TitleBlock`**: ISO 7200 mandatory + optional fields (title, drawingNumber, owner, creator, approver, documentType, dateOfIssue, revision, sheetNumber, language, material, weight, scale).
- **`Sheet`**: ties PaperSize + Orientation + ProjectionAngle + TitleBlock together. `render(into: DXFWriter)` emits border + ISO 5457 inner frame with correct margins (20 mm binding left, 10 mm other edges on A0–A3), centring marks at edge midpoints, and the title block in the bottom-right. `innerFrame` property exposes the drawable rectangle for layout.
- **`ProjectionSymbol`**: `ProjectionSymbol.render(.first, at:, into:)` emits the ISO 5456-2 truncated-cone + circle pair at the correct relative position for first / third angle.
- DXFWriter gets two new layers: `BORDER` and `TITLE`.

### v0.144.0 (Apr 2026) — ISO drawings I: section views, hatch, multi-view, style foundations

First of a three-release ISO-drawings arc (tracked in #78). Closes #73, #74, #75 and adds the ISO 128-20 / 3098 / 5455 style primitives every downstream sheet producer needs.

- **#75 `Drawing.transformed(translate:scale:)` + `Drawing.bounds`**: new `TransformedDrawing` wrapper and `DXFWriter.collectFromDrawing(_ transformed:)` overload. `Drawing.bounds(deflection:includeAnnotations:)` returns the drawing's 2D axis-aligned bounding box. Unblocks multi-view sheet composition: `writer.collectFromDrawing(view.transformed(translate: offset, scale: 0.5))`.
- **#73 `Shape.section2D(planeOrigin:planeNormal:planeU:deflection:)`** + `Shape.section2DView(...)`: slice a shape with a plane, return a `Drawing` in the plane's own 2D frame (not world space). `section2DView` wraps the contour with automatic ISO 128-40 hatching at 45° and an optional "A-A" label.
- **#74 `Drawing.addHatch(boundary:angle:spacing:islands:)`**: ISO 128-50 sectional-view fill. DXFWriter tessellates into line segments at the specified angle and spacing with island (hole) subtraction via even-odd rule scanlines. Adds `HATCH` + `SECTION` XCAF layers.
- **G1 ISO 128-20 line widths + ISO 128-21 arrows + ISO 3098 text heights**: `DrawingLineWidth` enum (w013 → w200, ISO 1:1.4 series), `DrawingTextHeight` enum (h25 → h200) with `.recommended(forPaper:)` and `.snap(_:)`, `DrawingArrowStyle` (filledClosed / openClosed90 / openClosed30 / tick), `DrawingLineStyle.defaultWidth` / `.boldWidth` per style.
- **G2 ISO 5455 `DrawingScale`**: enum cases `.one` / `.reduction(Int)` / `.enlargement(Int)` / `.custom(Double)` with `.factor` and `.label` accessors. `DrawingScale.preferred` returns the ISO-standard scale series (50:1 down to 1:1000).

### v0.143.0 (Apr 2026) — Measurement ergonomics + clearing v0.142 deferrals

Small-but-broad release that sands the measurement papercuts surfaced by the v0.143 audit and retires every deferral the v0.142 release notes flagged. Roughly 40 ops: 4 measurement additions, 5 deferral clearings.

**Measurement ergonomics (M1–M4):**

- **`Shape.volume` / `Shape.surfaceArea`** — verified already wrapped as optional properties (audit had missed them); no new code, just confirmation.
- **`Curve3D.distance(to: SIMD3)` / `Edge.distance(to: SIMD3)`** — one-liner point-to-curve distance when you don't need the projected point / parameter.
- **Angle helpers**: `Edge.angle(to:)`, `Edge.isParallel(to:tolerance:)`, `Edge.isPerpendicular(to:tolerance:)`, `Face.angle(to:)`, `Face.isParallel(to:)`, `Face.isPerpendicular(to:)`, `Face.isCoplanar(with:tolerance:)`. Plus `ConstructionAxis.angle(to:in:)`, `ConstructionPlane.angle(to:in:)`. `unsignedAngle(between:and:)` free function for SIMD3 pairs.
- **Circle / revolution property extraction**: `Edge.circleProperties` returns `(center, radius, axis, isFullCircle, startAngle, endAngle)?` for circular edges (three-point circle fit). `Face.revolutionProperties` returns `(axis, radius)?` for cylindrical / conical / spherical / toroidal / surface-of-revolution faces.

**Deferral clearings (from v0.142 release notes):**

- **Constructionspeak persistence (D1)**: `Document.addConstructionShape(_:)` tags a shape with the `CONSTRUCTION` XCAF layer; `Document.constructionShapeLabels` enumerates on reload. `ConstructionContext.materialize(in:graph:options:)` resolves every plane/axis/point recipe and creates a finite representative shape (rectangular face for planes, bounded edge for axes, vertex for points) on the layer. STEP export preserves layer tags; import produces layer-marked shapes but not the typed recipes. Matches FreeCAD's long-standing ceiling.
- **Arc / circle tessellation in `Sketch.buildProfile` (D2)**: `SketchElement.CurveKind.tessellate2D(segmentsPerRadian:)` for all four curve kinds (line / polyline / arc / circle). `Sketch.buildProfile` now lifts tessellated samples through the host plane's frame. D-shaped and circular profiles now produce wires.
- **Named-shape registry for `FeatureSpec.Boolean` (D3)**: Each feature with a non-nil `id` registers its produced shape in an internal dict; `Boolean.leftID` / `rightID` look up by id. `.union` / `.subtract` / `.intersect` all supported. Missing-id cases report `.unresolvedRef`.
- **Multi-leaf `.createdBy` disambiguation (D4)**: new `leafOccurrence: Int? = 0` parameter on `TopologyRef.createdBy` — pick the Nth leaf when a creation has split into multiple live descendants. `TopologyGraph.currentForms(of:)` returns all leaves. `leafOccurrence: nil` disables forward-walk.
- **FeatureReconstructor ↔ TopologyGraph coupling for `EdgeSelector` (D5)**: `.nearPoint(point, tolerance)` resolves edges by midpoint-distance within the target shape. `.onFeature(featureID)` looks up the source feature's shape via the named-shape registry and heuristically matches target edges whose midpoints coincide with the source's edges. `.all` for uniform fillet/chamfer still works. (v1 heuristic; full graph-history dispatch remains available if consumers need per-op edge identity.)

Scope cuts: chamfer per-edge selector still requires a per-edge distance array the bridge doesn't yet expose — falls through to `.unsupported` for `.nearPoint` / `.onFeature` on chamfer specifically. Uniform chamfer (`.all`) works. Flagged as a v0.144 candidate.

### v0.142.0 (Apr 2026) — Construction geometry, sketches, FeatureReconstructor

Second release in the v0.141 → v0.143 arc — ships Phases 2–6 from #72 plus #62 in one go. With this release, OCCTSwift has the full construction-geometry vocabulary that agentic modelling needs: recipe-based references (v0.141) → typed construction entities → document context → sketches → declarative feature reconstruction.

- **`ConstructionPlane` / `ConstructionAxis` / `ConstructionPoint`** (#72 Phase 2): Fusion-style recipe enums carrying `TopologyRef`s. 7 plane variants (absolute, offsetFromFace, throughAxis, tangentToFace, midPlane, byThreePoints, normalToEdge), 5 axis variants (absolute, alongEdge, normalToFace, throughPoints, intersectionOfPlanes), 6 point variants (absolute, atVertex, midpointOfEdge, centroidOfFace, atEdgeParameter, intersectionOfAxisAndPlane). Resolvers compute `Placement` / `(origin, direction)` / `SIMD3<Double>` against a `TopologyGraph`. Typed `ConstructionResolutionError`.
- **`TopologyRef.containedIn` now resolves** (#72 Phase 2 unblock): new `OCCTBRepGraphChildIndices` bridge + `TopologyGraph.childIndices(rootKind:rootIndex:targetKind:)` Swift wrapper.
- **`ConstructionContext`** (#72 Phase 3): Document-level collection with typed opaque IDs (`PlaneID` / `AxisID` / `PointID`), named entities, per-entity resolution against a graph, and `allBroken(in:)` diagnostic returning every entity that fails to resolve. `Document.constructionContext` is a lazy per-document property.
- **`Sketch` + `SketchElement`** (#72 Phase 4): `Sketch` is hosted on a `ConstructionPlane` ID, carries an array of `SketchElement`s with per-element `isConstruction` flag. `buildProfile(in:graph:)` is the **single filter site** (FreeCAD-inspired) — construction elements are excluded when assembling the profile wire. Elements: `.line`, `.polyline`, `.arc`, `.circle` (arcs/circles tessellation comes later).
- **`FeatureReconstructor`** (#62): Declarative `FeatureSpec` tagged union (revolve / extrude / hole / thread / fillet / chamfer / boolean). `FeatureReconstructor.build(from:)` with staged additive → subtractive → finishing → annotation dispatch. `EdgeSelector` enum with `.all`, `.nearPoint`, `.onFeature` — `.onFeature` currently reports `.unsupported` pending full TopologyGraph-integrated dispatcher; `.all` works today for uniform fillet/chamfer. `FeatureReconstructor.buildJSON(_:)` front end parses the OCCTDesignLoop-compatible schema.
- **`Placement`** shared value type (origin + orthonormal basis) with ergonomic `init(origin:normal:)` that picks deterministic x/y axes.

Scope of what the v1 implementation deliberately does **not** do (deferred to later iterations as concrete consumers surface):
- Constraint solving in `Sketch` — explicit non-goal (see #72).
- Named-shape registry for `FeatureSpec.Boolean` with id-based left/right selection.
- `.onFeature` / `.nearPoint` edge resolution in fillet/chamfer dispatch — requires coupling `FeatureReconstructor` to a live `TopologyGraph`, which is the natural next iteration once agents drive it.
- XCAF `CONSTRUCTION` layer persistence — recipes live in-memory; STEP round-trip drops them (matches FreeCAD's 20-year limitation documented in #72).
- Multi-leaf `.createdBy` disambiguation when a single creation splits into many live descendants.

### v0.141.0 (Apr 2026) — Construction-geometry foundation: BRepGraph history readback + TopologyRef

First release in the v0.141 → v0.143 "Construction Geometry" arc (tracked in #72). Builds the substrate for recipe-based topology references that survive mutations — the prerequisite for agent-driven CAD where construction planes / axes / points stay attached to model features through edits.

- **BRepGraph history record readback (#72 Phase 0)**: Exposes the old→new node mappings that the OCCT kernel was already recording. `TopologyGraph.historyRecord(at:)`, `.historyRecords`, `.findOriginal(of:)`, `.findDerived(of:)`, `.recordHistory(operationName:original:replacements:)`. New `TopologyGraph.NodeRef` value type (kind + index) and `HistoryRecord` with full mapping.
- **`TopologyRef` recipe type (#72 Phase 1)**: Indirect enum expressing topology references as *recipes evaluated against the current graph*, not as indices (Onshape FeatureScript-inspired). Cases: `.literal(NodeRef)`, `.createdBy(operationName:kind:occurrence:)`, `.containedIn(parent:kind:occurrence:)`, `.splitOf(original:occurrence:)`. Typed `TopologyResolutionError` enum for failure modes.
- **`TopologyGraph.resolve(_:)`**: Evaluates recipes by walking history records, returns `Result<NodeRef, TopologyResolutionError>`. `.createdBy` picks up newly-introduced replacements by operation name and walks forward to the current form; `.splitOf` picks the Nth replacement of a split original; ancestor-resolution failures surface as `.ancestorMissing`.

Scope: `.containedIn` returns `.noCurrentDescendant` until Phase 2 adds child-at-index accessors. `.createdBy` current-form walk picks the first leaf in deterministic order; multi-leaf disambiguation (useful when a single creation splits into many live descendants) comes in later phases.

### v0.140.0 (Apr 2026) — GD&T write path + typed dimension/tolerance enums

Completes the read-only GD&T support shipped in v0.21.0 with a write path. Downstream callers can now author `XCAFDoc_Dimension` / `XCAFDoc_GeomTolerance` / `XCAFDoc_Datum` attributes, attach them to shape labels, and round-trip through STEP AP242. Typed Swift enums replace the raw `Int32` type codes from v0.21.0 for the full list of XCAFDimTolObjects types.

- **Typed enums**: `Document.DimensionType` (all 32 `XCAFDimTolObjects_DimensionType` cases — Location_Linear, Size_Diameter, Size_Radius, toroidal variants, etc.) and `Document.GeomToleranceType` (all 16 — flatness, perpendicularity, position, profileOfLine, etc.).
- **Typed value types**: `Document.Dimension`, `Document.GeomTolerance`, `Document.Datum`. Accessors: `typedDimension(at:)`, `typedGeomTolerance(at:)`, `typedDatum(at:)`, `typedDimensions`, `typedGeomTolerances`, `typedDatums`.
- **Write path**: `Document.createDimension(on:type:value:lowerTolerance:upperTolerance:)`, `createGeomTolerance(on:type:value:)`, `createDatum(name:)`, `setDimensionTolerance(at:lower:upper:)`. Returns the new attribute's index or nil on failure.
- **Bridge additions**: `OCCTDocumentCreateDimension`, `OCCTDocumentCreateGeomTolerance`, `OCCTDocumentCreateDatum`, `OCCTDocumentSetDimensionTolerance`.

Scope: full modifier / qualifier / grade sequences (`XCAFDimTolObjects_DimensionModif`, `GeomToleranceModif`, `DatumSingleModif` etc.) remain partial wrapping — added on demand. This release covers the 90%-case authoring path.

### v0.139.0 (Apr 2026) — Thread Form v2 + cleanup

Replaces v0.138's circular-sweep thread placeholder with a real truncated V-profile following ISO-68 / UN conventions. Also folds in two quality-of-life cleanups (#68 boolean arg labels, #69 versioned MARK headers).

**Behaviour change**: callers of v0.138's `Shape.threadedHole` / `threadedShaft` will now receive geometry that actually looks like a thread in HLR reprojection (alternating diagonal edges at pitch spacing) rather than a helical groove. API signatures unchanged; new default parameters (`starts: 1`, `runout: .none`) preserve single-start no-runout behaviour.

- **Thread Form v2 (#66 follow-up)**: `ThreadCutterProfile` builds a truncated trapezoidal cross-section with 30° flanks (60° included), H/8 crest flat, H/4 root flat. Swept along a helical spine with `BRepOffsetAPI_MakePipeShell` (correctedFrenet mode) and boolean-cut against the target. New `crestFlat` / `rootFlat` / `minorDiameter` accessors on `ThreadSpec`. New `RunoutStyle` enum (`.none` / `.filleted(radius:)` / `.tapered(turns:)`). New `starts: Int` parameter on `threadedHole` / `threadedShaft` for multi-start threads.
- **Boolean op labels (#68)**: `Shape.union(_:)`, `Shape.intersection(_:)`, `Shape.section(_:)` now match `Shape.subtracting(_:)` — all unlabelled, consistent with `Set.union(_:)` / `Set.intersection(_:)`. Deprecated `with:`-labelled shims kept for backwards compatibility.
- **MARK header refactor (#69)**: 32 versioned grab-bag MARK headers (`// MARK: - v0.X.Y: A, B, C`) renamed to feature-first format (`// MARK: - A, B, C (v0.X.Y)`). Xcode jump-to-section and grep-for-feature now work; OCCTMCP's MARK-based API-reference generator can categorise without a regex fallback.

Tapered-runout law-based pipe-shell is tracked as a follow-up — the `.tapered` case falls back to `.filleted` until `BRepOffsetAPI_MakePipeShell::SetLaw` is wrapped.

### v0.138.0 (Apr 2026) — Engineering Drawings II: DXF export + thread features

Second release in the v0.137 → v0.139 arc. Closes #63 (DXF export) and #66 (ISO thread features). ~50 ops.

- **DXF 2D writer (#63)**: Custom pure-Swift DXF R12 ASCII writer (OCCT ships no DXF support — confirmed by audit). `Exporter.writeDXF(drawing:to:deflection:)` walks a `Drawing`'s visible / hidden / outline edges through `Shape.allEdgePolylines` and emits LINE / LWPOLYLINE / CIRCLE / ARC / TEXT entities. Layers: VISIBLE / HIDDEN / OUTLINE / CENTER / DIMENSION / TEXT, with appropriate linetypes (CONTINUOUS / DASHED / CHAIN). Dimensions from v0.137's `DrawingDimension` are emitted as exploded LINE+TEXT geometry (universally readable). `Exporter.writeDXF(shape:to:viewDirection:)` convenience combines projection and write. Public `DXFWriter` for callers composing DXF manually.
- **Thread features (#66)**: `ThreadForm` enum (iso68 / unified); `ThreadSpec` struct with `parse("M5x0.8")`, `parse("1/4-20 UNC")`, metric-coarse-pitch table, theoretical and cut depth accessors, minor-diameter computation. `Shape.threadedHole(axisOrigin:axisDirection:spec:depth:)` and `Shape.threadedShaft(axisOrigin:axisDirection:spec:length:)` produce helical cut / boss geometry via `BRepOffsetAPI_MakePipeShell` sweep of a circular profile. Integrates with #62's `FeatureReconstructor` — `FeatureSpec.Thread` can now route through real geometry instead of annotation-only.

Scope decisions: v1 threads use a circular sweep cross-section rather than full 60° flank triangle — produces correct handedness, pitch, diameter, and depth for reprojection diff and visualisation; manufacturing-accurate flanks land in a follow-up release. Multi-start threads, ACME / BSP / NPT forms, and full BRepOffsetAPI_MakePipeShell option wrapping (SetForceApproxC1, multi-profile Add()) deferred. GLTF Shape-level export, PLY import, STEP/IGES option completeness dropped from v0.138 — Document-level GLTF already ships, and the remaining gaps are low priority vs. closed-loop pipeline needs.

### v0.137.0 (Apr 2026) — Engineering Drawings I: axes, dimensions, centrelines

Keystone release for the v0.137 → v0.139 "Engineering Drawings" series (tracked in #67). Adds axis extraction from shapes (#65), a pure-Swift value-type dimensioning API on `Drawing` (#64), and auto-centreline generation bridging the two. ~60 ops.

- **Axis extraction (#65)**: `Face.primaryAxis`, `Shape.revolutionAxes(tolerance:)`, `Shape.symmetryAxes(fractionalTolerance:)`, `Surface.torusAxis`, `Surface.revolutionAxis`. New `ShapeAxis` value type with `.cylinder`/`.cone`/`.sphere`/`.torus`/`.revolution`/`.extrusion`/`.symmetry` kinds. Bridge: `OCCTSurfaceTorusAxis`, `OCCTSurfaceRevolutionAxis`, `OCCTSurfaceRevolutionLocation`, `OCCTFaceGetPrimaryAxis`, `OCCTShapeRevolutionAxes`, `OCCTShapeSymmetryAxes`.
- **Surface introspection completeness**: typed `Surface.SurfaceType` + `Surface.surfaceKind`; `Surface.Continuity` + `Surface.continuityClass`; type-predicate conveniences `isPlane` / `isCylinder` / `isCone` / `isSphere` / `isTorus` / `isBezier` / `isBSpline` / `isSurfaceOfRevolution` / `isSurfaceOfExtrusion` / `isOffsetSurface`.
- **Drawing dimensioning API (#64)**: `DrawingDimension` tagged union (linear / radial / diameter / angular) + `DrawingAnnotation` tagged union (centreline / centremark / text label). `DrawingLineStyle` enum. Methods on `Drawing`: `addLinearDimension`, `addRadialDimension`, `addDiameterDimension`, `addAngularDimension`, `addCentreLine`, `addCentermark`, `addTextLabel`, `clearAnnotations`, plus `dimensions` / `annotations` accessors. Pure-Swift value types — XDE round-trip deferred to v0.139 (#67).
- **Auto-centreline generation (#64 ↔ #65)**: `Drawing.addAutoCentrelines(from:viewDirection:overshoot:tolerance:bounds:)` projects a shape's revolution axes into the drawing's view plane and emits chain-pattern centrelines; axes parallel to the view direction are returned in `.skipped`.

Scope decisions (see #67 for rationale): Full PrsDim display-dimension completeness (MaxRadius / MinRadius / Chamf2d / Chamf3d) and PrsDim geometric-relation wrapping (Concentric / Parallel / etc.) were cut from v0.137 — they are AIS display objects with low marginal value compared to the Swift value-type API that drives the closed-loop drawing workflow.

### v0.132.0 - v0.136.0 (Apr 2026) — BRepGraph Topology Graph

Wraps OCCT's new BRepGraph API — graph-based B-Rep topology with cache-friendly traversal, O(1) upward navigation, and parallel geometry extraction. 163 operations across 5 releases.

- **v0.136.0**: ML-friendly graph export (COO adjacency, node features, JSON), UV-grid face sampling (positions/normals/curvatures), edge curve sampling — for GNN/UV-Net/BRepNet pipelines
- **v0.135.0**: Builder mutations — AddVertex/Shell/Solid, AddFaceToShell/ShellToSolid, AddCompound, RemoveNode/Subgraph, AppendShape, deferred invalidation, SplitEdge, ReplaceEdgeInWire
- **v0.134.0**: Product/Occurrence assembly queries, RefsView per-kind counts and entry access, edge start/end vertices, shell closure, compound hierarchy
- **v0.133.0**: Shape reconstruction from graph nodes, BRepGraph_Tool vertex/edge/face geometry access, CoEdge half-edge queries, history tracking, graph copy/transform, poly counts
- **v0.132.0**: Core graph — build from shape, topology/geometry counts, face adjacency, shared edges, edge boundary/manifold, child/parent explorers, validate, compact, deduplicate, stats

### v0.129.0 - v0.131.0 (Apr 2026) — RC5 New APIs

- **v0.131.0**: Approx_BSplineApproxInterp, GeomEval TBezier/AHTBezier curves+surfaces, GeomAdaptor_TransformedCurve
- **v0.130.0**: GeomEval analytical curves (helix, sine wave), analytical surfaces (ellipsoid, hyperboloid, paraboloid, helicoid), Geom2dEval spirals, GeomFill_Gordon, PointSetLib, ExtremaPC
- **v0.129.0**: IGES mutex serialization (thread safety fix per OCCT #1179)

### v0.120.0 - v0.128.0 (Apr 2026) — Completion & Polish

Final method-level coverage of all user-facing OCCT classes.

- **v0.128.0**: v0.128.0 release (3333 ops total)
- **v0.125.0**: BSplineSurface deep (20), Geom2d_BSpline (20), BezierCurve (8), BezierSurface (12)
- **v0.124.0**: ChamferBuilder (20), FilletBuilder (16), WireAnalyzer (18)
- **v0.123.0**: ThruSections/CellsBuilder/PipeShell/UnifySameDomain/Section extensions
- **v0.122.0**: WireFixer, ShapeFix_Edge, BRepTools/BRepLib statics, History, Sewing extensions
- **v0.121.0**: GLTF import/export (xcframework rebuilt with RapidJSON), FilletBuilder, ChamferBuilder
- **v0.120.0**: IsCN, ReversedParameter, ParametricTransformation, gp extras, surface reversed copies

### v0.110.0 - v0.119.0 (Mar-Apr 2026) — Constraint Solvers & Serialization

- **v0.119.0**: BREP serialization, gp_Pln/gp_Lin distance/contains, BezierSurface queries
- **v0.118.0**: BRepBndLib, ShapeAnalysis tolerance, BRepAlgoAPI_Check/Defeaturing
- **v0.116.0**: Helix construction, gp_Ax3/GTrsf2d/Mat2d, quaternion interpolation
- **v0.115.0**: Interpolation expansion, ThruSections builder, Triangulation queries
- **v0.114.0**: TopoDS_Builder, ShapeContents, FreeBoundsProperties, WireBuilder
- **v0.113.0**: MakeEdge completions, multi-result projections, DistShapeShape full results
- **v0.112.0**: RWMesh iterators, Intf_Tool, BRepAlgo_AsDes, BiTgte, wire/shell construction
- **v0.111.0**: PSO, GlobOptMin, FunctionRoots, GaussIntegration, BRepLProp
- **v0.110.0**: Constraint solver infrastructure — C callback adapters for OCCT math solvers

### v0.100.0 - v0.109.0 (Mar 2026) — Geometry Factories & Extrema

- **v0.109.0**: Extrema elementary distances, TrigRoots, IntAna2d, BRepAlgo_NormalProjection
- **v0.108.0**: Complete Geom_ and Geom2d_ method coverage — all conic/surface property methods
- **v0.107.0**: BSpline manipulation (3D/2D/surface), Bezier methods, BRepTools, Sewing, Hatch
- **v0.106.0**: GC surface factories, ShapeAnalysis_Wire/Edge, BRepLib_MakeEdge2d
- **v0.105.0**: GC/GCE2d geometry factories, GCPnts uniform sampling, CompCurveToBSpline (90 ops)
- **v0.104.0**: BndLib analytic bounding, OSD_Host/PerfMeter, IntAna_IntQuadQuad
- **v0.103.0**: gce transform factories, GProp element properties, Plate constraints
- **v0.102.0**: TopExp adjacency, Poly_Connect mesh adjacency, BRepOffset_Analyse
- **v0.101.0**: Geom_TrimmedCurve, BRepLib_FindSurface, ShapeAnalysis_Surface, Resource_Manager
- **v0.100.0**: RWStl I/O, ShapeAnalysis_Curve statics, BRepExtrema_SelfIntersection

### v0.90.0 - v0.99.0 (Mar 2026) — OCAF Extensions & Math

- **v0.99.0**: Convert_CompBezierCurves, Geom_OffsetSurface, OSD_File, ShapeFix_Wireframe
- **v0.98.0**: IntAna analytic intersections, OSD_Chronometer/Process, Draft_Modification
- **v0.97.0**: BRepAlgo_Loop, Bnd_BoundSortBox, BRepGProp_Domain, TNaming_Naming, Precision
- **v0.96.0**: XCAFDoc_AssemblyItemRef, BRepAlgo_Image, OSD_Path, BRepClass_FClassifier
- **v0.95.0**: Convert ellipse/hyperbola/parabola/cylinder/cone/torus to BSpline
- **v0.94.0**: math_Matrix/Gauss/SVD/PolynomialRoots/Jacobi, Convert circle/sphere to BSpline
- **v0.93.0**: OSD_MemInfo, ShapeFix_EdgeProjAux, Geom2dAPI_Interpolate, BRepAlgo_FaceRestrictor
- **v0.92.0**: Bnd_OBB, Bnd_Range, BRepClass3d point-in-solid, TDataXtd_Constraint
- **v0.91.0**: ElCLib curve evaluation, ElSLib surface evaluation, gp_Quaternion, OSD_Timer
- **v0.90.0**: TDF_ChildIDIterator, TDocStd_PathParser, TFunction_DriverTable, TNaming extensions

### v0.80.0 - v0.89.0 (Mar 2026) — Extrema, Color Science & OCAF Deep

- **v0.89.0**: TDF_Transaction/Delta, TDF_ComparisonTool, TDocStd_XLinkTool
- **v0.88.0**: TNaming extensions, TDataStd_IntPackedMap, TDataStd_NoteBook
- **v0.87.0**: TDataStd_Tick/Current, ShapeAnalysis_Shell, CanonicalRecognition
- **v0.86.0**: TDataStd extended attributes (BooleanArray, ByteArray, IntegerList, etc.)
- **v0.85.0**: UnitsAPI, BinTools binary I/O, Message_Messenger/Report
- **v0.84.0**: VrmlAPI_Writer, TDataStd_Directory/Variable, TDocStd_XLink
- **v0.83.0**: XCAFDoc attributes, Notes, ClippingPlaneTool, AssemblyGraph (97 ops)
- **v0.82.0**: Quantity_Period/Date, Font_FontMgr, Image_AlienPixMap (39 ops)
- **v0.81.0**: Quantity_Color, Quantity_ColorRGBA, Graphic3d materials (24 ops)
- **v0.80.0**: Extrema 3D/2D, GeomTools persistence, ProjLib, gce factories (35 ops)

### v0.70.0 - v0.79.0 (Mar 2026) — TKBool, TKFillet, TKHlr & Geometry Deep

- **v0.79.0**: Poly_CoherentTriangulation, BRepFill_Evolved, BRepExtrema_DistanceSS, GeomFill
- **v0.78.0**: BRepTools modifications, ShapeUpgrade_SplitSurface, GeomConvert, Poly_Polygon
- **v0.77.0**: GeomLib utilities, GccAna circle/line solvers, Approx_SameParameter
- **v0.76.0**: Geom_CartesianPoint, Geom_Direction, Axis1/2Placement, ShapeConstruct_Curve (41 ops)
- **v0.75.0**: BiTgte_Blend, GeomConvert_ApproxCurve/Surface, GCPnts, BRepGProp
- **v0.74.0**: TKMesh/TKOffset/TKPrim/TKShHealing/TKTopAlgo gap closure
- **v0.73.0**: Extended HLR edges, HLRAppli_ReflectLines, Intrv_Interval (29 ops)
- **v0.72.0**: LocOpe_Gluer, ChFi2d_Builder/ChamferAPI/FilletAPI, FilletSurf_Builder
- **v0.71.0**: IntTools_BeanFaceIntersector, BOPAlgo_WireSplitter, BRepFeat_SplitShape
- **v0.70.0**: IntTools EdgeEdge/EdgeFace/FaceFace, BOPAlgo BuilderFace/BuilderSolid

### v0.60.0 - v0.69.0 (Mar 2026) — Data Exchange & TKGeomAlgo

- **v0.69.0**: NLPlate G2/G3, Plate_Plate solver, GeomPlate, GeomFill Generator (20 ops)
- **v0.68.0**: TopTrans_CurveTransition, GeomFill trihedrons, GccAna_Circ2d3Tan (18 ops)
- **v0.67.0**: FairCurve, LocalAnalysis, TopTrans SurfaceTransition (8 ops)
- **v0.66.0**: Full TkG2d — Point2D, Transform2D, AxisPlacement2D, Vector2D (44 ops)
- **v0.65.0**: BOPAlgo RemoveFeatures/Section, ShapeBuild, ShapeExtend, ShapeUpgrade (24 ops)
- **v0.64.0**: ProjLib, BRepOffset_Offset, Adaptor3d_IsoCurve (9 ops)
- **v0.63.0**: GeomLProp, BRepOffset_SimpleOffset, GeomInt_IntSS, Contap_Contour (17 ops)
- **v0.62.0**: BRepLib topology, MakeEdge2d, ShapeCustom, LocOpe, CPnts (22 ops)
- **v0.61.0**: Approx, Contap, BOPAlgo, IntCurvesFace, BRepMesh, GeomPlate (19 ops)
- **v0.60.0**: XDE/XCAF Full Coverage (42 ops)

### v0.50.0 - v0.59.0 (Feb-Mar 2026) — OCAF & Data Exchange

- **v0.59.0**: IGES/OBJ/PLY Full Coverage (23 ops)
- **v0.58.0**: STEP Full Coverage (25 ops)
- **v0.57.0**: OCAF Persistence (17 ops)
- **v0.56.0**: TDataXtd + TFunction (29 ops)
- **v0.55.0**: TDataStd Attributes (25 ops)
- **v0.54.0**: TDF Core + TDocStd (31 ops)
- v0.50.0-v0.53.0: Various additions

### v0.38.0 - v0.49.0 (Feb 2026) — Audit & Gap Closure

Systematic OCCT test suite audit rounds (7 rounds total), closing gaps in primitives, sweeps, booleans, modifications, healing, measurement, and topology.

### v0.27.0 - v0.37.0 (Feb 2026) — RC4 Upgrade & Feature Expansion

- OCCT 8.0.0-rc3 → rc4 upgrade
- Feature-based modeling, pattern operations, shape editing
- Topological naming (TNaming), OCAF framework
- TDataStd/TDataXtd attributes, TFunction framework

### v0.16.0 - v0.26.0 (Feb 2026) — Parametric Geometry

- 2D/3D parametric curves (Geom2d, Geom) with Metal draw methods
- Parametric surfaces with curvature analysis
- Law functions for variable-section sweeps
- Medial axis transform
- Camera, selection, presentation mesh
- Color science, materials

### v0.6.0 - v0.15.0 (Jan 2026) — XDE & Annotations

- XDE document support (assembly, colors, materials, GD&T)
- Annotations (dimensions, text labels, point clouds)
- KD-tree spatial queries
- Polynomial solver, hatch patterns

### v0.1.0 - v0.5.0 (Dec 2025 - Jan 2026) — Foundation

- Basic primitives, booleans, transforms
- Wire creation, sweep operations
- Mesh generation, STL/STEP import/export
- Shape validation and healing
- STEP optimization
