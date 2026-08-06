import Testing
import Foundation
@testable import OCCTSwift

// #699: `AAG.buildGraph()` compared every pair of face occurrences for adjacency and convexity,
// with no notion of which solid each occurrence belongs to. `OCCTFacesAreAdjacent` and
// `OCCTEdgeGetConvexity` (`OCCTBridge_BRepGraph.mm`) test two `TopoDS_Face` values purely on their
// own edge geometry, ignoring the `shape` argument they are handed beyond a null check, so two
// faces from DIFFERENT solids in one compound that happen to share a B-Rep edge were reported
// adjacent, and the convexity of that shared edge was computed with no reference to which solid
// was asking.
//
// Found while measuring #642's own fix (Cluster A's census,
// `Scripts/repro/cluster-a-subshape-enumeration/README.md`, "Update following #642's fix"): on a
// VERTICAL two-solid split, `detectPocketsAAG().count` disagreed across compound member order
// (1 vs 2), even though #642's fix (`orientedFaces()`-based nodes) is correct and complete for
// what it claims. The two defects are independent and need different fixtures to show: #642's own
// headline needs a HORIZONTAL cut (the shared wall's normal has to be vertical to reach
// `isHorizontal()`/`isUpward()` at all); this one needs a VERTICAL cut (the shared wall borders two
// half-faces of the box's original top face, which also border EACH OTHER along the cut line, so
// one edge is common to three face occurrences: both top-face halves and both sides of the wall).
//
// ## The contract
//
// Two faces sharing a B-Rep edge but belonging to different solids in a compound are adjacent IN
// THE COMPOUND and not adjacent in EITHER solid. `AAG` and its consumers (`detectPockets()`,
// `concaveNeighbors(of:)`, `convexNeighbors(of:)`) want the solid-scoped answer: a floor face's
// candidate walls are the faces that bound the SAME body, not any face anywhere in the compound
// that happens to touch the same edge locus. `AAG.buildGraph()` now restricts its pairwise
// adjacency/convexity check to occurrence pairs sharing a solid, derived from `Shape.solids` and
// `orientedFaces()`'s own traversal order rather than a new bridge function (see
// `AAG.solidGroups(of:in:)`'s doc comment for why the existing bridge surface is enough).
//
// ## A further correction to #642's own headline measurement
//
// Restricting to same-solid pairs also changes the HORIZONTAL fixture's `detectPocketsAAG().count`
// from `2` (in both orders, #642's own fix) to `1` (in both orders). This is not a regression: #642
// was about order-AGREEMENT, and the horizontal fixture still agrees after #699 (`1` in both
// orders, was `2` in both orders). What moved is that one of the two "pockets" `detectPockets()`
// reported before #699 was itself built from a cross-solid comparison between the shared wall and
// the wrong side of a split face -- exactly the mechanism #699 fixes. See
// `Scripts/repro/cluster-a-subshape-enumeration/README.md`'s "Update following #699's fix" for the
// full measurement.
@Suite("AAG restricts adjacency and convexity to one solid (#699)")
struct Issue699AAGSolidScopedAdjacencyTests {

    // MARK: - Fixture

    /// The issue's own construction: a plain, origin-centred 10mm box split by an X-normal plane
    /// through x=4, recompounded in both member orders. A one-line change to
    /// `Issue642AAGNodeIdentityTests.horizontalSplitBoxCompound(order:)`'s normal and point, per
    /// #699's own instructions -- the two fixtures are otherwise identical in shape.
    enum Order { case asSplit, reversed }

    static func verticalSplitBoxCompound(order: Order) -> Shape? {
        guard let block = Shape.box(width: 10, height: 10, depth: 10),
              let pieces = block.split(atPlane: SIMD3(4, 0, 0), normal: SIMD3(1, 0, 0)),
              pieces.count == 2
        else { return nil }
        let ordered = order == .asSplit ? pieces : pieces.reversed()
        return Shape.compound(Array(ordered))
    }

    // MARK: - The headline

    /// The defect itself, reverted: before the fix this was 1 vs 2 for identical geometry
    /// (measured directly against the tree at HEAD before this fix landed).
    ///
    /// - Note: #703 later moved the agreed count from `1` to `0`. `1` was never the geometrically
    ///   right answer: this fixture is two plain boxes glued face to face along a vertical wall,
    ///   and a plain box has no concave edges, so neither piece can contribute a pocket. The `1`
    ///   this test used to pin was `OCCTEdgeGetConvexity`'s own face1/face2 order-dependence
    ///   (`Issue703EdgeConvexityOrderTests`), not a real feature of this shape.
    @Test("detectPocketsAAG() agrees across compound member order on a vertical cut")
    func detectPocketsAgreesAcrossOrder() {
        guard let orderA = Self.verticalSplitBoxCompound(order: .asSplit),
              let orderB = Self.verticalSplitBoxCompound(order: .reversed) else {
            Issue.record("could not build the vertical split-box fixture")
            return
        }

        let pocketsA = orderA.detectPocketsAAG()
        let pocketsB = orderB.detectPocketsAAG()

        #expect(pocketsA.count == pocketsB.count)
        // Pinned to the measured value so a future change that breaks this loudly disagrees with
        // a concrete number rather than only with itself. Two boxes glued face to face have no
        // concave edges anywhere (#703), so 0 is the geometrically correct answer.
        #expect(pocketsA.count == 0)
        #expect(pocketsB.count == 0)
    }

    /// `buildAAG().nodes.count` is unaffected: #699 restricts EDGES, not the node set #642 already
    /// fixed. Both orders keep 12 occurrence nodes (6 per solid) for this fixture.
    @Test("buildAAG().nodes.count is unaffected by the adjacency fix")
    func nodeCountUnaffected() {
        guard let orderA = Self.verticalSplitBoxCompound(order: .asSplit),
              let orderB = Self.verticalSplitBoxCompound(order: .reversed) else {
            Issue.record("could not build the vertical split-box fixture")
            return
        }

        #expect(orderA.buildAAG().nodes.count == 12)
        #expect(orderB.buildAAG().nodes.count == 12)
    }

    /// Each solid, in isolation, is a plain 6-face box (12 face-adjacency edges: every face touches
    /// 4 others, 6*4/2 = 12). With adjacency correctly scoped to one solid, the compound's graph is
    /// exactly two such box graphs and nothing more: 24 edges, none of them crossing the solid
    /// boundary. Before #699 this was higher, and order-dependent, because cross-solid pairs were
    /// included too.
    @Test("the graph is exactly two independent 12-edge box graphs, no cross-solid edges")
    func edgeCountIsTwoIndependentBoxGraphs() {
        guard let orderA = Self.verticalSplitBoxCompound(order: .asSplit),
              let orderB = Self.verticalSplitBoxCompound(order: .reversed) else {
            Issue.record("could not build the vertical split-box fixture")
            return
        }

        #expect(orderA.buildAAG().edges.count == 24)
        #expect(orderB.buildAAG().edges.count == 24)
    }

    /// The shared wall's two occurrences (same `distinctFaceIndex`, opposite orientation) are each
    /// adjacent only to faces on their OWN solid's side. Neither wall occurrence is adjacent to the
    /// other (that guard predates #699, see `Issue642AAGNodeIdentityTests`), and -- the #699 part --
    /// neither is adjacent to the OTHER solid's half of the split top face either, even though that
    /// half shares the wall's own top boundary edge.
    @Test("the shared wall's two occurrences are not adjacent to the other solid's split top-face half")
    func wallOccurrencesDoNotCrossSolidBoundary() {
        guard let compound = Self.verticalSplitBoxCompound(order: .asSplit) else {
            Issue.record("could not build the vertical split-box fixture")
            return
        }

        let aag = compound.buildAAG()
        let grouped = Dictionary(grouping: aag.nodes.enumerated().map { ($0.offset, $0.element) },
                                  by: \.1.distinctFaceIndex)
        guard let wallSides = grouped.first(where: { $0.value.count > 1 })?.value, wallSides.count == 2 else {
            Issue.record("expected exactly one face shared by two nodes (the cut wall)")
            return
        }

        // Every neighbor of each wall occurrence must be a face that is ALSO a neighbor of, or
        // equal to, one of the two wall occurrences' own solid-mates -- concretely: no neighbor of
        // wallSides[0] should be adjacent to wallSides[1] and vice versa, which is what "different
        // solids never touch" implies for a shape where each solid is a single connected box.
        let (indexA, _) = wallSides[0]
        let (indexB, _) = wallSides[1]
        let neighborsA = Set(aag.neighbors(of: indexA))
        let neighborsB = Set(aag.neighbors(of: indexB))

        // If solid-scoping were absent, the two wall sides (which are geometrically coincident)
        // would share every neighbor, since anything adjacent to one side's edge loop is adjacent
        // to the other's too. Scoped to one solid each, their neighbor sets are disjoint.
        #expect(neighborsA.isDisjoint(with: neighborsB))
        #expect(!neighborsA.contains(indexB))
        #expect(!neighborsB.contains(indexA))
    }

    // MARK: - No regression on the unshared case

    /// A single solid has no cross-solid pair to restrict: `AAG.solidGroups(of:in:)` returns `nil`
    /// for `Shape.solids.count <= 1`, so `buildGraph()` falls back to comparing every pair exactly
    /// as it did before #699. A plain box's graph is unchanged.
    @Test("a plain box's AAG is unaffected")
    func plainBoxUnaffected() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("could not build the box")
            return
        }

        let aag = box.buildAAG()
        #expect(aag.nodes.count == 6)
        #expect(aag.edges.count == 12)
    }

    // MARK: - No regression on #642's own fixture (order-agreement survives, though the count moved)

    /// #642's own horizontal-cut fixture must still agree across compound member order after #699.
    /// The exact count moved from `2` to `1` (see the suite's own doc comment and
    /// `Scripts/repro/cluster-a-subshape-enumeration/README.md`'s "Update following #699's fix"),
    /// and #703 later moved it again, from `1` to `0`: two plain boxes glued face to face have no
    /// concave edges anywhere, so `0` is the geometrically right answer, not `1`. What must never
    /// regress is the AGREEMENT itself, which is what #642 was about and what this fixture is
    /// uniquely positioned to catch since the vertical fixture above never reaches
    /// `isHorizontal()`/`isUpward()` at all.
    @Test("#642's horizontal-cut fixture still agrees across order, at the corrected count")
    func horizontalFixtureStillAgreesAtCorrectedCount() {
        guard let block = Shape.box(width: 10, height: 10, depth: 10),
              let pieces = block.split(atPlane: SIMD3(0, 0, 4), normal: SIMD3(0, 0, 1)),
              pieces.count == 2,
              let orderA = Shape.compound(pieces),
              let orderB = Shape.compound(pieces.reversed())
        else {
            Issue.record("could not build the horizontal split-box fixture")
            return
        }

        let pocketsA = orderA.detectPocketsAAG()
        let pocketsB = orderB.detectPocketsAAG()

        #expect(pocketsA.count == pocketsB.count)
        #expect(pocketsA.count == 0)
        #expect(pocketsB.count == 0)
    }

    // MARK: - The two fallback branches (review follow-up)

    /// `solidGroups` returns `nil` when the per-solid occurrence counts do not sum to the total, and
    /// `buildGraph()` then compares every pair as it did before #699. A compound of two solids plus
    /// a free face is that case: 6 + 6 occurrences against 13 in the shape.
    ///
    /// **This case is not proven by removing the guard, and saying so is the point.** I expected it
    /// to be: `groups` looked like it would be sized 12 and indexed to 12. It is not. It is sized
    /// from `occurrenceCount` (13) and the fill loop covers only 0...11, leaving the free face at
    /// the sentinel `-1`, which compares unequal to every real group and so is simply never adjacent
    /// to anything. Measured: with the guard removed this test still passes. I also tried making the
    /// free face coincident with the box's top face to give it an adjacency worth losing, and it
    /// still has zero neighbours, because a separately built face carries its own `TopoDS` edges
    /// rather than the solid's.
    ///
    /// So the guard is **defensive**, not load-bearing on any fixture reachable through the public
    /// API today. It stays because the sentinel being harmless is a property of this partitioning,
    /// not a guarantee. What this test does pin is that the branch is reached and yields a complete
    /// graph over every occurrence, which is worth having even though a removal check cannot
    /// distinguish it. Per `okf/policies/prove-the-test-fails.md`, a case that survives its guard's
    /// removal is labelled, not counted as coverage.
    ///
    /// Note the shape the review suggested for this, `Shape.compound([box, freeFace])`, does not
    /// reach here: one solid exits at the earlier `bodies.count <= 1` guard. Two solids are needed
    /// before the sum can disagree.
    @Test("A compound mixing solids with a free face falls back instead of mis-partitioning")
    func countMismatchFallsBackToUnrestrictedComparison() {
        guard let a = Shape.box(width: 10, height: 10, depth: 10),
              let b = Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10),
              let wire = Wire.polygon3D(
                  [SIMD3(40, 0, 0), SIMD3(50, 0, 0), SIMD3(50, 10, 0), SIMD3(40, 10, 0)], closed: true),
              let freeFace = Shape.face(from: wire),
              let mixed = Shape.compound([a, b, freeFace])
        else {
            Issue.record("could not build the solids-plus-free-face fixture")
            return
        }

        // The fixture must actually reach the branch, or this proves nothing.
        let total = mixed.orientedFaces().count
        let perSolid = mixed.solids.map { $0.orientedFaces().count }
        #expect(mixed.solids.count > 1, "need more than one solid to get past the first guard")
        #expect(perSolid.reduce(0, +) != total,
                "fixture must make the counts disagree: perSolid \(perSolid), total \(total)")

        // Falling back is a complete, non-crashing graph over every occurrence.
        let aag = mixed.buildAAG()
        #expect(aag.nodes.count == total)
        // Pinned `2` before #703 (one false-positive pocket per disjoint box, the same
        // order-dependent `OCCTEdgeGetConvexity` defect measured on a single plain box). Neither
        // box has a real concave edge, and the two are too far apart to be adjacent to each other
        // or to the free face, so the geometrically right count is 0.
        #expect(mixed.detectPocketsAAG().count == 0)
    }

    /// Both other fixtures are exactly two solids, so the partition loop is only ever exercised
    /// pairwise. Three disjoint boxes walk it past that, and permuting them must not move anything.
    @Test("The partition generalises past two solids")
    func threeSolidCompoundPartitions() {
        func compound(_ order: [Int]) -> Shape? {
            let boxes = (0..<3).compactMap {
                Shape.box(origin: SIMD3(Double($0) * 20, 0, 0), width: 10, height: 10, depth: 10)
            }
            guard boxes.count == 3 else { return nil }
            return Shape.compound(order.map { boxes[$0] })
        }
        guard let straight = compound([0, 1, 2]), let permuted = compound([2, 0, 1]) else {
            Issue.record("could not build the three-solid fixture")
            return
        }
        #expect(straight.solids.count == 3)
        #expect(straight.buildAAG().nodes.count == 18)
        #expect(straight.buildAAG().nodes.count == permuted.buildAAG().nodes.count)
        #expect(straight.detectPocketsAAG().count == permuted.detectPocketsAAG().count)
    }
}
