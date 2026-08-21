# #777: `PocketFeature.isOpen`'s enclosure test

#761 (PR #776) measured `PocketFeature.isOpen`'s enclosure test at 3x to 8x the per-edge cost of
`BRepGraph`'s indexed edge-to-face incidence, and left the fix out of scope as a separate,
well-evidenced follow-up. This directory is that follow-up's measurement.

The harness is `Scripts/repro/harnesses/PocketEnclosureTiming.swift`, one entry in the shared
`Harnesses` executable target (see `Package.swift` and `Scripts/repro/harnesses/HarnessRunner.swift`);
this directory keeps only this README and the captured output, the arrangement #694 established for
`Censuses`.

```bash
swift run Harnesses 777-pocket-isopen                      # Parts 1 to 5
swift test --filter Issue777PocketEnclosureCoveringEdgesTests
OCCTSWIFT_LOCAL=1 bash Scripts/repro/777-pocket-isopen/end-to-end-ab.sh   # section 5's table
```

**Every fixture here is sharp-cornered, so the covering set the harness uses is
`wallFaceIndices` alone**, while the shipped code uses walls UNION #762's absorbed fillet and
chamfer faces. The junction indices are not public, so a harness over the public API cannot
reproduce the wider set. That is fine for the relative comparison, since all four predicates are
handed the identical set, and it does mean no timing row here is a filleted pocket. The verdict
side of walls-UNION-junctions is covered by tests instead: injection I6 below drops the junctions
and fails 7 of the #762 suites.

`measured-output.txt` is one full run, taken on an otherwise quiet machine. Every timing row is 25
runs reported as `median (min .. max)`, all four predicates are warmed before the first sample, and
they are timed interleaved inside one process so a load spike lands on all of them rather than on
whichever ran first. That matters here: the first attempts at this measurement were taken while
eight other agents were building in the same checkout, and the max column ran 20x the min.

## What was measured

Four enclosure predicates, implemented side by side over the public API:

- **`adjacentFaces(in:)`**, what `isEdgeCoveredByAWall` did before this issue. Per floor boundary
  edge, ask the whole shape which faces bound it, then match those against the covering set by
  `IsSame`. `OCCTEdgeGetAdjacentFaces` (`OCCTBridge_BRepGraph.mm`) rebuilds a whole-shape
  `TopExp::MapShapesAndAncestors` edge-to-face map on every call, so the cost scales with the shape
  rather than with the pocket.
- **covering edges, linear scan**, and **covering edges, hash-bucketed**: the replacement. Ask each
  covering face for its own edges, then test the floor's boundary edge for membership by `IsSame`.
  The same predicate evaluated from the other end, resolved once per pocket, and never touching
  anything but the covering faces. The bucketed form is the one that shipped.
- **`BRepGraph`**, the route the issue proposed. One graph per shape (not per pocket, which is the
  arrangement most favourable to it), covering faces mapped onto its nodes, `faces(of:)` per floor
  boundary edge.

## 1. The gap is still there, and it widens with the shape

Re-measured on `main` at `456c2493`, after Pass 4a's #943 changes to `buildGraph()`/`detectHoles()`.
Whole-shape enclosure test, all of a fixture's pockets, microseconds, median of 25:

| fixture | `adjacentFaces(in:)` | covering edges, linear | covering edges, hashed | `BRepGraph` |
|---|---|---|---|---|
| blind rectangular pocket, 4 walls, 4 floor edges | 39.5 | 23.3 | 24.9 | 278.2 |
| blind cylindrical pocket, 1 wall, 1 floor edge | 7.2 | 5.7 | 6.4 | 176.9 |
| 24-sided polygonal pocket | 921.3 | 209.2 | 157.2 | 1134.8 |
| 48-sided polygonal pocket | 3247.8 | 568.8 | 305.4 | 2154.9 |
| plate with 8 open slots | 569.5 | 92.5 | 107.6 | 1271.0 |
| plate, 3x3 grid of pockets, 51 face occurrences | 1464.5 | 214.8 | 239.5 | 1639.0 |
| plate, 5x5 grid of pockets, 131 face occurrences | 11832.2 | 603.5 | 651.0 | 4478.0 |

Against the hashed form that shipped, that is **1.1x on a one-edge pocket and 18.2x on the 5x5
plate**, medians, with the min-based ratio within 2x of the median-based one on every row
(`measured-output.txt` prints both). The ratio grows with the shape because the discarded map is
rebuilt over the whole shape once per floor boundary edge: the two axes that drive it are how many
boundary edges a pocket's floor has and how big the shape is, and the polygonal and grid fixtures
scale one each.

### The open-slot row exists because the old code had one arrangement in its favour

Every other fixture here is an **enclosed** pocket, and that is the arrangement that flatters the
replacement. The old test was `contains { !covered }`, which short-circuits on the **first**
uncovered edge, so an open pocket could in principle be decided after a single whole-shape map build
while the replacement always indexes the entire covering set first. The pre-PR review raised this as
an untested path, correctly: without a row for it, the table would only ever have measured the case
where the old code has to visit every edge anyway.

Measured, the short-circuit does not save it: **569.5 us against 107.6 us, still 5.3x**. One
whole-shape `MapShapesAndAncestors` build costs more than indexing the handful of faces covering a
slot, so even the best case for the old arrangement loses.

## 2. The route the issue proposed is not the one to take

#777's stated hypothesis was that edge-to-face incidence, unlike #761's face-to-face case, could
route through `BRepGraph`. Measured, it is the wrong answer twice.

**On cost.** `BRepGraph`'s per-edge lookup is genuinely indexed, and #761's 3x-to-8x figure for it
is real. It is also not the quantity that decides anything: a caller of `detectPockets()` has no
graph in hand, and standing one up costs more than the whole test it would accelerate on **five of
the seven** fixtures. The two exceptions are the 48-sided pocket (2154.9 against 3247.8) and the 5x5
plate (4478.0 against 11832.2), where the old route is so expensive that even paying for a graph
beats it. Against the route that shipped, `BRepGraph` loses on all seven rows, by 6.8x to 27.6x.
This is `measure-dont-assume.md`'s "the adjacent number reads as the one you need" exactly: the
per-edge ratio was measured correctly, of the wrong thing.

**On the answer.** Part 4 of the harness asks all three constructions, for every edge of five
fixtures, which faces bound it. On two solids sharing one cut face, the covering-edge scan reports
4 face occurrences for each of the 4 shared edges, `adjacentFaces(in:)` resolves to **3** of them
(it returns at most two faces, but the shared cut face expands to two occurrences under `IsSame`),
and `BRepGraph` reports **3** for a different reason: `ShapesView::FindNode` hashes on
`TopTools_ShapeMapHasher` and collapses that shared face's two occurrences into one node. Three
constructions, three different senses of what a face is. That collapse is #642's and #699's
cross-solid contamination, the same reason #761 kept AAG's adjacency off `BRepGraph`. It turns out
to apply to the edge-to-face half as well, which the issue explicitly flagged as a hypothesis rather
than a finding.

## 3. The verdict is unchanged, and the divergence is one-directional

The replacement is not a drop-in just because both constructions are correct on a box, so Part 4
compares the face **sets**, not counts, over every edge of a plain box, a cylinder (seam edge on a
periodic surface), a cone (degenerate zero-length apex edge), a sphere (a seam and two degenerate
pole edges) and the split compound above. The predicate asks "is a covering index in this set", so
set containment is what decides whether a verdict can move and in which direction.

```
edges where A is a STRICT subset of B (B sees a face A cannot): 4 (all on the split compound)
edges where A is NOT a subset of B (B loses a face A had):      0 (every fixture)
```

**A is a subset of B on all 41 edges.** The truncation that causes it is filed as
[#1087](https://github.com/SecondMouseAU/OCCTSwift/issues/1087), since `Edge.adjacentFaces(in:)`
remains public and other callers can still meet it. That subset relation is structural, not just
observed:
`OCCTEdgeGetAdjacentFaces` builds `TopExp::MapShapesAndAncestors` and then stops at two
(`it.More() && count < 2`), and that map is the inverse of the per-face `TopExp::MapShapes` the new
code reads, so the old set is a truncation of the new one. The replacement can therefore only ever
move a verdict from open to enclosed, never from enclosed to open. The one place the two differ is
an edge bounded by more than two faces, where `adjacentFaces(in:)` structurally cannot report the
rest.

The seam and degenerate cases look like divergences on counts alone and are not.
`MapShapesAndAncestors` visits a seam edge twice from the same face, so `adjacentFaces(in:)` hands
back that one face as both `face1` and `face2`; as a set that is one occurrence, which is what the
edge scan reports too.

### Why no pocket fixture turns that into a changed verdict, and the case where it could

The extra faces the scan sees on the split compound belong to the *other* solid of the compound, and
#699 restricts `wallIndices` to same-solid neighbours, so they were never candidates for the
covering set. Part 5 runs the pocket verdicts on the boundary fixtures and all three constructions
agree on every one, including both halves of the split compound, whose floors each carry one
>2-face boundary edge. That case is pinned by
`Issue777PocketEnclosureCoveringEdgesTests.multiFaceBoundaryEdgeDoesNotFakeAnEnclosure`.

**That restriction is conditional, and the pre-PR review was right to push on it.**
`AAG.solidGroups` (`FeatureRecognition.swift`) returns `nil` when the per-solid occurrence counts do
not sum to the occurrence total, which its own doc names as a compound mixing solids with free
shells or faces, and `buildGraph()` then compares every pair cross-solid. On such a shape a face
from another body can legitimately reach `wallIndices`, and the >2-face divergence can then move a
verdict from open to enclosed. So the correct claim is narrower than "unreachable": it is
**unreachable whenever solid membership can be established**, which is every fixture in this repo's
suite. Where it is not established, the flip lands on the answer that is arguably the better one,
since the covering face genuinely does bound that edge and the old answer depended on which two
ancestors the map happened to list first, the same order dependence #753 wrote a suite about.

**That case is argued here and not measured, so it is filed as
[#1089](https://github.com/SecondMouseAU/OCCTSwift/issues/1089)** rather than left as a paragraph.
Building the fixture needs a compound that makes `solidGroups` return nil and still presents a
pocket, and making the OLD answer come out "open" depends on `MapShapesAndAncestors` ancestor
ordering, which would be a flaky test rather than a characterization. That is a reason to track it,
not a reason to treat the argument as evidence.

### One boundary case the verdict sweep does not reach

Part 5's conical fixture reports "no pocket detected", so the degenerate-edge case never reaches a
pocket verdict at all. Its coverage is Part 4's incidence sweep only (cone and sphere rows, where A
and B agree exactly), not a verdict comparison.

## 4. Linear scan or hash bucket

Both were measured rather than argued. The linear scan is `O(floor edges x covering edges)`, which
is invisible on a four-wall pocket and real on a 48-wall one; the bucket is `O(floor edges +
covering edges)` at the cost of building a dictionary per pocket.

**The bucket loses on five of the seven rows and wins on two**, and the two it wins are the ones
that decide it. Full accounting, microseconds, hashed against linear:

| fixture | linear | hashed | hashed is |
|---|---|---|---|
| blind rectangular pocket | 23.3 | 24.9 | 7% slower |
| blind cylindrical pocket | 5.7 | 6.4 | 12% slower |
| 24-sided polygonal pocket | 209.2 | 157.2 | **1.3x faster** |
| 48-sided polygonal pocket | 568.8 | 305.4 | **1.9x faster** |
| plate with 8 open slots | 92.5 | 107.6 | 16% slower |
| plate, 3x3 grid | 214.8 | 239.5 | 11% slower |
| plate, 5x5 grid | 603.5 | 651.0 | 8% slower |

Every loss is a fixture with few covering faces per pocket, where the dictionary is built and
thrown away without amortizing; every win is a pocket with many. In absolute terms the five losses
total about 90 microseconds and the two wins about 315.

That accounting alone is close enough to be arguable, so the tiebreaker is the shape of the two
curves rather than the seven measurements: the linear scan is `O(floor edges x covering edges)` and
degrades without bound as a pocket gains walls, while the bucket is `O(floor edges + covering
edges)`. A 7% to 16% penalty on a test already costing single-digit-to-double-digit microseconds
buys a bound on the case that has no ceiling, so the bucket ships. Both forms stay in the harness
because the choice is close, and a later change to either should be re-measured rather than
inherited.

`Shape.hashCode` is a safe key rather than a heuristic: `OCCTShapeHashCode` is
`std::hash<TopoDS_Shape>` **masked to 31 bits** (`OCCTBridge_Topology.mm`), and that hash is the one
`TopTools_ShapeMapHasher` pairs with `IsSame` (read in
`Libraries/OCCT.xcframework/*/Headers/TopTools_ShapeMapHasher.hxx`, not assumed), combining TShape
and Location with no orientation term. So two `IsSame` shapes always land in the same bucket and a
bucket miss is a definite non-match. The mask can only add collisions, never remove a match, which
is exactly why the `IsSame` confirmation on a hash hit is load-bearing rather than decorative, and
why injection I2 below removes something real even though no fixture makes it fire.

## 5. End to end

`detectPocketsAAG()` builds the whole attributed adjacency graph before it detects anything, and
that `O(n^2)` face-pair loop is the other large term, so the end-to-end saving is smaller than the
ratios above. Measured by running the same harness against `origin/main`'s
`FeatureRecognition.swift` and against this branch's, alternating, three rounds each, same build
tree, microseconds, minimum over the three rounds.

Parts 1 to 5 run inside one process and `swift run Harnesses 777-pocket-isopen` reproduces them on
its own; this table does not, because it compares two builds. `end-to-end-ab.sh` in this directory
is that swap loop, and `end-to-end-ab.txt` is the transcript the table below was read off, so both
the method and its output are committed rather than described.

| fixture | before | after | saving |
|---|---|---|---|
| blind rectangular pocket | 442.5 | 349.9 | 21% |
| blind cylindrical pocket | 237.0 | 193.5 | 18% |
| 24-sided polygonal pocket | 3829.1 | 2288.1 | 40% |
| 48-sided polygonal pocket | 11156.5 | 6832.3 | 39% |
| plate with 8 open slots | 3995.4 | 3192.4 | 20% |
| plate, 3x3 grid | 5787.0 | 4649.3 | 20% |
| plate, 5x5 grid | 36385.6 | 25983.5 | 29% |

**Minimum, not median, and here is why that is not cherry-picking.** A cross-build comparison cannot
be interleaved the way Part 2's four predicates are, so it has no protection against a load spike
landing on one side, and one did: round 1's "after" run reports a 5x5 median of 137626 against the
same round's "before" median of 82902, which inverts the result outright, while rounds 2 and 3
(quieter) agree with the table above on every row. The minimum over runs is the usual robust
estimator for "how fast can this run" under contention. The in-process Part 2 comparison is the
primary evidence for this change; this table is context for what share of the whole call it is.

## 6. Removal matrix

`okf/policies/prove-the-test-fails.md` asks for the injection run, not just the green one. Eight
injections, each applied alone, against the four tests in
`Issue777PocketEnclosureCoveringEdgesTests` plus the 24 pre-existing pocket tests in
`Issue735PocketEnclosureTests`, `Issue753PocketBossWireScopeTests`,
`Issue753OffCenterPocketEnclosureTests`, `Issue753FilletedJunctionDetectedTests` and
`Issue762FilletedPocketDetectionTests`. 28 tests in 15 suites throughout.

| # | injection | tests failing, of 28 |
|---|---|---|
| I0 | none (baseline) | 0 |
| I1 | `contains` matches with `isEqual` (orientation-sensitive) instead of `isSame` | 15 |
| I2 | `contains` trusts the hash bucket, no `IsSame` confirmation | **0, see below** |
| I3 | `CoveringEdges` indexes every face occurrence, not just the covering set | 11 |
| I4 | `CoveringEdges` records nothing, so membership always fails | 15 (same set as I1) |
| I5 | `CoveringEdges` reads only each covering face's outer wire | **0, see below** |
| I6 | covering set drops #762's absorbed junction faces | 7, all filleted or chamfered |
| I7 | `membershipIgnoresOrientation`'s own pairing uses `isEqual` | 1: its `pairsFound == 4` guard |
| I8 | `multiFaceBoundaryEdge...`'s fixture check raised past any real face count | 1: its `multiFaceEdges >= 1` guard |

I1 and I4 produce the identical failure set, so neither distinguishes "wrong identity rule" from "no
index at all"; that is worth saying rather than counting twice. I3 is disjoint from both, failing
the open-pocket tests (scope lost, everything looks covered) where I1 and I4 fail the enclosed ones
(nothing looks covered), so scope and identity are genuinely separated rather than backstopping each
other.

**The first run of this matrix was against an earlier revision of the suite, and re-running it found
a real hole.** Under I1 that revision failed 14 tests, and `membershipIgnoresOrientation` was not
among them: it measured the fixture's orientation property and never constructed a `CoveringEdges`,
so it could not fail when the identity rule was swapped. It was the premise without the conclusion.
The pre-PR review caught it by running the same injection independently. The test now puts each
orientation-flipped edge through `CoveringEdges.contains` as well, which is why I1 and I4 fail 15
here and not 14.

### Two guards no test can currently fail on

Reported rather than counted as covered.

- **I2, the `IsSame` confirmation after a hash hit.** Removing it leaves everything green, because
  no fixture produces a `Shape.hashCode` collision between a covering face's edge and a floor
  boundary edge that is not the same edge. The confirmation stays: it is what makes correctness
  independent of hash quality rather than dependent on it. No colliding pair was constructed.
- **I5, reading all of a covering face's edges rather than only its outer wire.** Also leaves
  everything green. This is a genuine behavioural narrowing rather than an equivalent spelling:
  `Shape.subShapes(ofType: .edge)` bottoms out in `occtMapSubShapes`
  (`Sources/OCCTBridge/src/OCCTBridge_Internal.h`), which is `TopExp::MapShapes(face, TopAbs_EDGE)`,
  a full explorer walk of every wire the face carries, outer and inner. The case that would separate
  them is a floor boundary edge lying on a covering face's inner wire, and none was constructed.
  Reading all edges is kept because it is the complete answer to "does this face bound this edge",
  which is what the predicate means.
