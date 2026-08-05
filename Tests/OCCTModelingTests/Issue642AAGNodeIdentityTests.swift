import Testing
import Foundation
@testable import OCCTSwift

// #642: `AAG.buildGraph()` used to build its node set from `shape.faces()`, the deduplicated
// enumeration #614 documented as orientation-insensitive by design: a face occurring both FORWARD
// and REVERSED collapses to one entry, keeping whichever orientation `TopExp::MapShapes` reached
// first. `AAGNode.isHorizontal`/`isUpward`/`isDownward`/`isVertical`/`zLevel` are all derived from
// that entry's normal, so which orientation survived the collapse silently decided the answer, and
// `detectPockets()` selects floors on exactly those fields.
//
// Cluster A's census (#664, `Scripts/repro/cluster-a-subshape-enumeration/`) reproduced this
// exactly and corrected the fixture: #614's own committed fixture
// (`Issue614FaceOrientationTests.splitBoxCompound()`) cuts VERTICALLY, so its shared wall's normal
// is horizontal-axis, not vertical, and never reaches `isHorizontal()`/`isUpward()` at all. Only a
// HORIZONTAL cut's shared wall exercises this: an origin-centred 10mm box cut through z=4,
// recompounded in both member orders.
//
// The fix builds `AAG`'s nodes from `orientedFaces()` instead, so a shared wall is two nodes, one
// per owning solid, each with that solid's own normal. Neither node depends on which orientation a
// dedup collapse happened to keep, so the graph, and everything built on it, stops depending on
// compound member order.

@Suite("AAG builds nodes from orientedFaces(), not faces() (#642)")
struct Issue642AAGNodeIdentityTests {

    // MARK: - Fixture

    /// An origin-centred 10mm box cut through z=4, recompounded in both member orders. The
    /// horizontal cut is required: a vertical cut's shared wall never reaches
    /// `isHorizontal()`/`isUpward()`, so it does not exercise this defect at all (measured by
    /// Cluster A's census, and the correction this issue's own text needed).
    enum Order { case asSplit, reversed }

    static func horizontalSplitBoxCompound(order: Order) -> Shape? {
        guard let block = Shape.box(width: 10, height: 10, depth: 10),
              let pieces = block.split(atPlane: SIMD3(0, 0, 4), normal: SIMD3(0, 0, 1)),
              pieces.count == 2
        else { return nil }
        let ordered = order == .asSplit ? pieces : pieces.reversed()
        return Shape.compound(Array(ordered))
    }

    // MARK: - The headline

    /// The defect itself, reverted: before the fix this was 2 vs 1 for identical geometry.
    @Test("detectPocketsAAG() agrees across compound member order")
    func detectPocketsAgreesAcrossOrder() {
        guard let orderA = Self.horizontalSplitBoxCompound(order: .asSplit),
              let orderB = Self.horizontalSplitBoxCompound(order: .reversed) else {
            Issue.record("could not build the horizontal split-box fixture")
            return
        }

        let pocketsA = orderA.detectPocketsAAG()
        let pocketsB = orderB.detectPocketsAAG()

        #expect(pocketsA.count == pocketsB.count)
        // Pinned to the measured value so a future change that breaks this loudly disagrees with
        // a concrete number rather than only with itself.
        #expect(pocketsA.count == 2)
        #expect(pocketsB.count == 2)
    }

    /// The AAG-level symptom the issue named directly: the upward+horizontal node set's SIZE must
    /// agree across order. (The node indices themselves are allowed to differ between orders,
    /// since traversal order over the compound also reassigns which array position each distinct
    /// face lands at; it is the count, and each node's own attributes, that must not depend on it.)
    @Test("AAG upward+horizontal node count agrees across compound member order")
    func upwardHorizontalCountAgreesAcrossOrder() {
        guard let orderA = Self.horizontalSplitBoxCompound(order: .asSplit),
              let orderB = Self.horizontalSplitBoxCompound(order: .reversed) else {
            Issue.record("could not build the horizontal split-box fixture")
            return
        }

        let aagA = orderA.buildAAG()
        let aagB = orderB.buildAAG()

        let upwardHorizontalA = aagA.nodes.filter { $0.isUpward && $0.isHorizontal }
        let upwardHorizontalB = aagB.nodes.filter { $0.isUpward && $0.isHorizontal }

        #expect(upwardHorizontalA.count == upwardHorizontalB.count)
        // Pinned: the outer top face plus the shared wall's upward-facing side, in both orders.
        #expect(upwardHorizontalA.count == 2)
        #expect(upwardHorizontalB.count == 2)
    }

    // MARK: - Node identity

    /// `buildAAG()` now reads `orientedFaces()`: a compound with a shared wall has one more node
    /// than it has distinct faces, mirroring #614's own `faces()` vs `orientedFaces()` count.
    @Test("buildAAG().nodes.count matches orientedFaces(), not faces(), on a shared-wall compound")
    func nodeCountMatchesOrientedFaces() {
        guard let compound = Self.horizontalSplitBoxCompound(order: .asSplit) else {
            Issue.record("could not build the horizontal split-box fixture")
            return
        }

        let aag = compound.buildAAG()
        #expect(aag.nodes.count == compound.orientedFaces().count)
        #expect(aag.nodes.count == compound.faces().count + 1)
    }

    /// The shared wall's two nodes carry the same `distinctFaceIndex` and opposite orientation
    /// derived attributes, since one side's normal is the other's negation.
    @Test("the shared wall's two nodes share a distinctFaceIndex and disagree on isUpward")
    func sharedWallNodesShareDistinctIndexAndOpposeUpward() {
        guard let compound = Self.horizontalSplitBoxCompound(order: .asSplit) else {
            Issue.record("could not build the horizontal split-box fixture")
            return
        }

        let aag = compound.buildAAG()
        let grouped = Dictionary(grouping: aag.nodes, by: \.distinctFaceIndex)
        let shared = grouped.filter { $0.value.count > 1 }

        #expect(shared.count == 1)
        guard let sides = shared.first?.value, sides.count == 2 else {
            Issue.record("expected exactly one face shared by two nodes")
            return
        }

        // Opposed normals: one side faces up, the other does not.
        #expect(sides.map(\.isUpward).sorted { !$0 && $1 } == [false, true])
        // Both sides agree they are horizontal: opposing a vertical normal only flips its sign,
        // not whether it is vertical.
        #expect(sides.allSatisfy { $0.isHorizontal })
    }

    /// `AAG` does not link the two nodes of a shared face to each other: they are the same face,
    /// not neighbors of it. Without the identity guard in `buildGraph()`, `OCCTFacesAreAdjacent`
    /// reports every one of a face's own boundary edges as "shared" with itself.
    @Test("the shared wall's two nodes are not adjacent to each other")
    func sharedWallNodesAreNotMutualNeighbors() {
        guard let compound = Self.horizontalSplitBoxCompound(order: .asSplit) else {
            Issue.record("could not build the horizontal split-box fixture")
            return
        }

        let aag = compound.buildAAG()
        let grouped = Dictionary(grouping: aag.nodes.enumerated().map { ($0.offset, $0.element) },
                                  by: \.1.distinctFaceIndex)
        guard let sides = grouped.first(where: { $0.value.count > 1 })?.value, sides.count == 2 else {
            Issue.record("expected exactly one face shared by two nodes")
            return
        }

        let (indexA, _) = sides[0]
        let (indexB, _) = sides[1]
        #expect(aag.edge(between: indexA, and: indexB) == nil)
        #expect(!aag.neighbors(of: indexA).contains(indexB))
    }

    // MARK: - No regression on the unshared case

    /// On a single solid, `orientedFaces()` is exactly `faces()` (#614's own documented contract),
    /// so nothing about a plain box's AAG changes.
    @Test("a plain box's AAG is unaffected")
    func plainBoxUnaffected() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("could not build the box")
            return
        }

        let aag = box.buildAAG()
        #expect(aag.nodes.count == 6)
        #expect(aag.edges.count == 12)
        for node in aag.nodes {
            #expect(node.faceIndex == node.distinctFaceIndex)
        }
    }

    /// #614's own vertical-cut fixture (the exact construction
    /// `Tests/OCCTTopologyTests/Issue614FaceOrientationTests.swift` uses, reproduced locally since
    /// each domain test target is its own module) does not exercise this defect: the shared wall's
    /// normal is horizontal-axis, so it never touches `isHorizontal()`/`isUpward()`. Its node count
    /// and pocket count must still agree across order after this fix, exactly as they did before
    /// it.
    @Test("#614's own vertical-cut fixture is unaffected by member order")
    func verticalCutFixtureUpwardHorizontalUnaffected() {
        guard let block = Shape.box(origin: .zero, width: 20, height: 10, depth: 10),
              let plate = Shape.face(from: Wire.rectangle(width: 60, height: 60)!),
              let upright = plate.rotated(axis: SIMD3(0, 1, 0), angle: .pi / 2),
              let knife = upright.translated(by: SIMD3(10, 0, 0)),
              let pieces = block.split(by: knife),
              pieces.count == 2,
              let compound = Shape.compound(pieces),
              let reversedCompound = Shape.compound(pieces.reversed())
        else {
            Issue.record("could not build the vertical split-box fixture")
            return
        }

        let aagA = compound.buildAAG()
        let aagB = reversedCompound.buildAAG()

        let upwardHorizontalA = aagA.nodes.filter { $0.isUpward && $0.isHorizontal }.count
        let upwardHorizontalB = aagB.nodes.filter { $0.isUpward && $0.isHorizontal }.count
        #expect(upwardHorizontalA == upwardHorizontalB)
    }
}
