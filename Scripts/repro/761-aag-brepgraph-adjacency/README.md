# #761: does AAG duplicate BRepGraph's adjacency, and can it converge onto it?

The census `docs/v2.0.0-plan.md`'s census-once rule asks for, built before touching any
production code. `AAG` (`Sources/OCCTSwift/FeatureRecognition.swift`) maintains its own hand-rolled
face/edge adjacency (`OCCTFacesAreAdjacent`/`OCCTFaceGetSharedEdges`/`OCCTEdgeGetConvexity`), and
`BRepGraph` (`Sources/OCCTSwift/BRepGraph.swift`) already exposes `adjacentFaces(of:)`/
`sharedEdges(between:and:)` as first-class operations over a `BRepGraph_Tool`-backed graph. The
issue asked whether these are the same question, drifted, or genuinely different, and to
consolidate onto whichever is correct if they converge.

**Method**: build both an `AAG` and a `BRepGraph` from the same `Shape`, map every AAG face
occurrence (`Shape.orientedFaces()`-indexed, #642) onto its `BRepGraph` face node via
`BRepGraph.findNode(for:)`, then measure what each side reports for the same questions, on a
spread of fixtures. Executable, committed artifact: `swift run Censuses issue-761`, source at
`Scripts/repro/censuses/Issue761.swift`, registered in `Scripts/repro/censuses/CensusRunner.swift`.
This directory keeps only this README, per the convention `cluster-a-subshape-enumeration/`
established (#694): SwiftPM only needs to see the Swift source under `Scripts/repro/censuses/`.

## Headline finding: not the same question, once a face is shared across solids

`BRepGraph::ShapesView::FindNode` hashes on `TopTools_ShapeMapHasher`
(`Sources/.../TopTools_ShapeMapHasher.hxx`), whose `operator()(S1, S2)` is `S1.IsSame(S2)` --
same underlying `TShape` and `Location`, orientation ignored. That is the *identical* collapse
rule `Shape.faces()` uses, and the one #642's own fix moved `AAG`'s node set away from
(`orientedFaces()`, one node per occurrence, not per distinct face) specifically because it lost
information for whichever occurrence didn't survive the dedup.

Measured directly (Part 1 of the census): on both two-solid split fixtures, `AAG.nodes.count` is
12 (one per occurrence) while `BRepGraph.faceCount` is 11 (deduplicated) -- the same 12-vs-11 gap
`Shape.orientedFaces().count` vs `Shape.faces().count` shows for the identical fixture. Mapping
every occurrence to its `BRepGraph` node via `findNode(for:)` confirms why: the shared wall's two
occurrences (opposite orientation, same `TShape`) always resolve to the **same** `BRepGraph` node
index (Part 2: "shared-face occurrence pairs... of which BRepGraph collapses to ONE node: 1", on
both split fixtures).

That collapse is not just a different index space -- it changes what `adjacentFaces(of:)` can
answer. Part 3 queries that single collapsed wall node's neighbors directly:

```
vertical split fixture:
  BRepGraph.adjacentFaces(of: wallNode=5) = 8 faces, spanning solid groups [0, 1]
horizontal split fixture:
  BRepGraph.adjacentFaces(of: wallNode=2) = 8 faces, spanning solid groups [0, 1]
```

`BRepGraph` cannot tell "the wall as solid A sees it" apart from "the wall as solid B sees it" --
there is only one node, and its neighbor list is the union of both solids' faces. That is exactly
the cross-solid contamination #699 fixed on the `AAG` side by restricting `buildGraph()`'s pairwise
loop to same-solid pairs, a fix that is only *expressible* because `AAG` keeps the two occurrences
as separate nodes. Part 2's pairwise comparison confirms the practical consequence: on each split
fixture, 12 of the 35 cross-solid pairs are pairs `BRepGraph.sharedEdges` reports as genuinely
sharing an edge (real, structural topology), while `AAG`, correctly per its own #699 contract,
refuses to ever call them adjacent. Neither number is "wrong" -- they are answers to different
questions (compound-wide topological incidence vs. per-solid boundary adjacency), and #699 is the
reason `AAG` needs the *latter*.

**Same-solid pairs agree completely.** Where no cross-solid identity is in play, `AAG`'s adjacency
test and shared-edge count agree with `BRepGraph`'s exactly: 0 disagreements across every same-solid
pair on every fixture (plain box: 15 pairs; each split fixture: 30 pairs; three disjoint boxes: 45
pairs). The divergence is entirely and only about cross-solid shared identity, not about the
underlying edge-sharing computation itself, which both sides compute correctly and identically.

## A real, independent correctness bug: the 10-edge cap

`AAG.buildGraph()` called `OCCTFaceGetSharedEdges(shape, face1, face2, &buffer, 10)` with a
hardcoded `maxEdges` of 10, so `AAGEdge.sharedEdgeCount` silently truncated on any face pair
sharing more than 10 edges -- #753's own doc comment predicted this ("plausible after healing
splits a boundary into segments") but it had never been measured. `BRepGraph.sharedEdges(between:and:)`
has no such cap (`bgSharedEdges` in `OCCTBridge_BRepGraph.mm` appends to an unbounded
`std::vector`), which is exactly the second, independent construction
[`measure-dont-assume.md`](../../../okf/policies/measure-dont-assume.md) asks for, and it caught a
real disagreement.

`manySharedEdgesFixture()` (a 100mm box with 11 small notches carved across the top/front edge, each
notch straddling both planes and splitting the shared boundary) measures 12 real shared edges
between the top and front faces:

```
--- Part 4: the 10-edge cap ---
  fixture face occurrences: 50
  top face occurrence index 2, area 9868.0
  front face occurrence index 1, area 9868.0
  AAG.edge(between:).sharedEdgeCount = Optional(12)
  BRepGraph.sharedEdges(between:and:).count = 12
  FIXED: AAG's sharedEdgeCount (12) now agrees with BRepGraph past the old 10-cap threshold
```

(Before the fix below, the first line read `Optional(10)` -- confirmed by reverting the fix locally
and re-running.) This is a real, narrow, independent bug: nothing about it depends on cross-solid
identity, shared faces, or compounds. It reproduces on a single ordinary solid.

## Can AAG converge onto BRepGraph for the cap fix? Measured: no, it would regress performance

The natural fix reading the issue's own framing ("that alone is a correctness reason to prefer
[BRepGraph]") is to route `sharedEdgeCount` through `BRepGraph.sharedEdges(between:and:)` instead.
Measured before implementing anything, on a plate with a grid of drilled holes (`holedPlate(gridSize:)`,
the same shape of fixture #703's own performance measurement used):

```
--- Part 7: cost of a naive per-pair BRepGraph.sharedEdges swap ---
  grid 4x4 (22 occurrences, 231 pairs, 60 graph edges):
    AAG.buildGraph() today (direct bridge calls): 1.2 / 1.1 / 1.1 ms
    via BRepGraph.sharedEdges, all pairs:          2.1 / 2.3 / 2.1 ms
  grid 8x8 (70 occurrences, 2415 pairs, 204 graph edges):
    AAG.buildGraph() today (direct bridge calls): 11.0 / 10.9 / 11.0 ms
    via BRepGraph.sharedEdges, all pairs:          70.8 / 69.5 / 73.3 ms
```

2.4x slower at 22 occurrences, 8x slower (and climbing) at 70. This is not a constant-factor
regression: `OCCTFaceGetSharedEdges` is O(e1 * e2), each face's own small (typically 4-6) edge set,
independent of the shape's total size. `bgSharedEdges` (`OCCTBridge_BRepGraph.mm`) is O(E), a linear
scan of every edge in the whole graph, per call -- OCCT 8.0.0p1 dropped `TopoView::FaceOps`'s direct
face-face helpers, so there is no indexed face-to-face incidence to query instead, only this
derived, unindexed one. Swapping the inner call while keeping `AAG.buildGraph()`'s O(n^2) outer
loop turns O(n^2 * small-constant) into O(n^2 * E), and E grows with n for a bounded-degree face
graph, so the ratio gets worse as models get bigger, not better.

**A smarter hybrid was also measured, and still lost.** Restricting the BRepGraph-routed lookup to
only the pairs *already confirmed adjacent* by the existing cheap direct call (a roughly
linear-sized subset, not O(n^2)):

```
--- Part 8: cost of fixing the cap ONLY for already-adjacent pairs ---
  grid 4x4 (22 occurrences, 44 confirmed-adjacent pairs):
    extra: sharedEdges on confirmed-adjacent pairs only: 0.97 / 0.86 / 0.81 ms
  grid 8x8 (70 occurrences, 140 confirmed-adjacent pairs):
    extra: sharedEdges on confirmed-adjacent pairs only: 7.84 / 7.90 / 7.65 ms
```

Compare against Part 6's own `AAG.buildGraph() alone` row for the same fixtures (1.1ms / 10.9ms):
the "smart" hybrid's *extra* cost alone is comparable to `buildGraph()`'s entire current running
time, before even counting the one-time cost of building the `BRepGraph` and the occurrence-to-node
map (Part 6: `BRepGraph(shape:) alone`, another 0.6-2.3ms). Total cost roughly doubles. `bgSharedEdges`'s
per-call scan cost (governed by the whole graph's edge count) is simply too close to
`buildGraph()`'s *entire* current O(n^2) probe's cost to make routing even a subset of it through
BRepGraph a win.

## The fix that was actually made

Neither consolidation path pays for itself. The bug is real and worth fixing at its root instead:
a new bridge function, `OCCTFaceGetSharedEdgeCount(shape, face1, face2)` (`OCCTBridge_BRepGraph.h`/
`.mm`), returns the true, uncapped count. `AAG.buildGraph()` now calls it first to size its buffer
exactly, then calls `OCCTFaceGetSharedEdges` with that exact size -- no cap, no BRepGraph involved,
same asymptotic cost as before (the O(e1 * e2) comparison over each face's own small edge set,
never the whole shape, now runs twice per pair instead of once). Measured after the fix:
`AAG.buildGraph()` alone on the 8x8 grid fixture is 10.8-10.9ms, statistically indistinguishable
from the 9.5-11.0ms range measured before this change.

**Review round (PR #776): the two functions must not carry two independent copies of that
comparison.** The first version of this fix gave `OCCTFaceGetSharedEdgeCount` its own copy of the
nested `IsSame` loop, alongside the existing one in `OCCTFaceGetSharedEdges` -- which is precisely
the shape of bug this whole issue is about: one implementation silently drifting from another that
answers the same question. Two independent copies of the same face-pair edge comparison is exactly
what let the original 10-cap bug go unnoticed, since nothing forced the two functions to agree.
Fixed by factoring the comparison into one internal `static` helper, `countOrCollectSharedEdges`
(`OCCTBridge_BRepGraph.mm`), that both public functions call: it walks the pair once and either
counts (uncapped, `outEdges == nullptr`) or collects up to `maxEdges` (the existing
`OCCTFaceGetSharedEdges` contract, `outEdges != nullptr`), so there is exactly one place the
`IsSame` identity test lives. A future change to that test (e.g. tolerance-aware instead of exact
`IsSame`) now cannot be applied to one call and not the other.

Pinned with a dedicated test
(`Tests/OCCTModelingTests/Issue761SharedEdgeCountCapTests.swift`,
`bridgeFunctionsShareOneComparison`) that calls both bridge functions directly on the same
top/front pair: `OCCTFaceGetSharedEdgeCount` returns 12, `OCCTFaceGetSharedEdges` with
`maxEdges: 10` returns 10, and `OCCTFaceGetSharedEdges` with `maxEdges: 12` returns all 12. The two
disagree on the returned count only because of the buffer, never because of the comparison itself.
Removal-matrix proof: reintroducing an independent, drifted second copy inside
`OCCTFaceGetSharedEdgeCount` (capped at an arbitrary 7, simulating exactly the class of bug this
refactor prevents) makes this test fail (`trueCount → 7 == 12`), along with the two headline tests
above; restoring the shared helper turns all of them green again.

## The enclosure test (#735/#753's second half) is a different case, not fixed here

The issue also named `PocketFeature.isOpen`'s enclosure test (`isEdgeCoveredByAWall`,
`Edge.adjacentFaces(in:)` + a hand-rolled `facesAreSame`) as a second, independent instance of the
same pattern. Measured for correctness on two fixtures (a blind cylindrical pocket, 1 floor edge;
a blind rectangular pocket, 4 floor edges): `Face.outerWire?.edges().count` agrees exactly with
`BRepGraph.outerWire(of:)` + `wireCoEdgeCount`, and every boundary edge's face-count from
`Edge.adjacentFaces(in:)` agrees exactly with `BRepGraph.faces(of:)` once mapped across. Unlike the
face-to-face case above, this is genuinely the same computation reachable two ways, because
`BRepGraph`'s edge-to-face incidence (`OCCTBRepGraphEdgeFaceIndices`, backing `faces(of:)`) is a
real indexed structure populated once at graph construction, not a derived linear scan --
`OCCTBRepGraphEdgeNbFaces` reads `Topo().Edges().NbFaces(...)` directly.

That indexing shows up as a real, measured **performance difference in BRepGraph's favor**:
`Edge.adjacentFaces(in:)` (`OCCTEdgeGetAdjacentFaces`) rebuilds a whole-shape
`TopExp::MapShapesAndAncestors` edge-to-face map from scratch on *every call*:

```
--- Part 5: PocketFeature.isOpen's enclosure test vs BRepGraph ---
  blind cylindrical pocket (1 floor edge):
    per-edge cost, Edge.adjacentFaces(in:):        4.9 / 5.0 / 4.1 us/edge
    per-edge cost, BRepGraph.faces(of:) (mapped):  2.0 / 1.1 / 1.0 us/edge
  blind rectangular pocket (4 floor edges):
    per-edge cost, Edge.adjacentFaces(in:):        5.8 / 5.8 / 5.8 us/edge
    per-edge cost, BRepGraph.faces(of:) (mapped):  0.7 / 0.7 / 0.7 us/edge
```

Consolidating this specific piece onto `BRepGraph` looks like a genuine win, not a regression --
the opposite conclusion from the face-to-face case above, and worth remembering as a reason "not
the same question" cannot be generalized from one half of this issue to the other. **Not
implemented in this PR**: it touches the public `detectPockets()` code path for a performance gain
rather than a correctness fix (the two constructions already agree on every case measured), and
building it out (constructing a `BRepGraph` for this specific call path, handling the case where a
floor face itself doesn't map cleanly, re-verifying `#753`'s own removal-matrix tests still pass
against a different code path) is a separable piece of work. Left as a well-evidenced follow-up
rather than folded into this issue's scope.

## Reproduce

```bash
swift run Censuses issue-761
swift test --filter Issue761SharedEdgeCountCapTests
```
