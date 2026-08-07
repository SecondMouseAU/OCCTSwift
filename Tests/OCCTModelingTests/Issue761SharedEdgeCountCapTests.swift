import Testing
import Foundation
@testable import OCCTSwift

// #761: investigating whether AAG's hand-rolled pairwise face/edge adjacency
// (`OCCTFacesAreAdjacent`/`OCCTFaceGetSharedEdges`/`OCCTEdgeGetConvexity`) duplicates
// `BRepGraph`'s own `adjacentFaces(of:)`/`sharedEdges(between:and:)` found the two are NOT the
// same question wherever a face is shared across solids: `BRepGraph`'s face-node identity is
// `IsSame`-deduplicated (the same collapse #642 moved AAG's own node set away from), so a shared
// face is ONE `BRepGraph` node whose adjacency merges both solids -- measured directly via
// `Scripts/repro/761-aag-brepgraph-adjacency/`, which is the census this issue asks for. A naive
// per-pair swap onto `BRepGraph.sharedEdges(between:and:)` was also measured to be 2-8x slower
// (and getting worse with model size) than AAG's current direct bridge calls, so `AAG.buildGraph()`
// keeps its own pairwise design rather than routing through `BRepGraph`.
//
// One genuine, independent correctness bug DID fall out of the comparison, and is what this suite
// covers: `AAGEdge.sharedEdgeCount` used to come from `OCCTFaceGetSharedEdges(..., maxEdges: 10)`,
// a hardcoded cap with no relationship to how many edges two faces actually share. `BRepGraph`'s
// `sharedEdges(between:and:)` has no such cap (an unbounded `std::vector` on the bridge side), and
// used as the second, independent construction this policy asks for, it disagreed with AAG's own
// answer on a fixture built specifically to share more than 10 edges between two faces: BRepGraph
// reported 12, AAG reported 10 (silently truncated). Fixed by sizing the buffer from a new
// `OCCTFaceGetSharedEdgeCount` bridge call first, in `AAG.buildGraph()` itself -- same O(e1 * e2)
// cost as before (each face's own small edge set, never the whole shape), not by routing through
// BRepGraph (which the same census measured to be a real performance regression for this specific
// call shape).
@Suite("AAG.buildGraph()'s sharedEdgeCount is not capped at 10 (#761)")
struct Issue761SharedEdgeCountCapTests {

    // MARK: - Fixture

    /// A 100mm box with 11 small notches cut across the top/front edge, so the remaining top face
    /// and front face share more than 10 separate boundary-edge segments. Each notch is a small
    /// box straddling both the z=50 (top) and y=-50 (front) planes near x=x0, removing a bite from
    /// both faces and splitting their shared edge there. Matches
    /// `Scripts/repro/761-aag-brepgraph-adjacency/`'s own `manySharedEdgesFixture()` -- kept as a
    /// second, independent construction here (a fresh build in the test target) rather than a
    /// shared helper, since the point is to catch a regression in either copy.
    static func manySharedEdgesFixture() -> Shape? {
        guard var shape = Shape.box(width: 100, height: 100, depth: 100) else { return nil }
        for x0 in stride(from: -45.0, through: 45.0, by: 9.0) {
            guard let notch = Shape.box(origin: SIMD3(x0 - 3, -52, 48), width: 6, height: 4, depth: 4),
                  let cut = shape.subtracting(notch) else { return nil }
            shape = cut
        }
        return shape
    }

    /// Finds the largest occurrence matching a predicate on its `AAGNode`, by area. Used to locate
    /// the top and front faces without depending on their (unpredictable, since the notches add
    /// several small new faces) index position.
    private static func largestFace(_ aag: AAG, occ: [Face], where predicate: (AAGNode) -> Bool) -> Int? {
        aag.nodes.indices.filter { predicate(aag.nodes[$0]) }.max { occ[$0].area() < occ[$1].area() }
    }

    /// The floor/wall pair this suite measures: the box's top face and front face, both still
    /// single connected faces after the notch cuts, sharing 12 edges (11 notches split the shared
    /// boundary into 12 remaining segments).
    private static func topAndFrontFaces(in shape: Shape) -> (aag: AAG, topIndex: Int, frontIndex: Int)? {
        let occ = shape.orientedFaces()
        let aag = shape.buildAAG()
        guard let topIndex = largestFace(aag, occ: occ, where: { $0.isUpward && $0.isHorizontal }),
              let frontIndex = largestFace(aag, occ: occ, where: { $0.isVertical && ($0.normal?.y ?? 0) < -0.9 })
        else { return nil }
        return (aag, topIndex, frontIndex)
    }

    // MARK: - The headline

    @Test("sharedEdgeCount reports the true count, not a value capped at 10")
    func sharedEdgeCountIsNotCappedAtTen() {
        guard let shape = Self.manySharedEdgesFixture(),
              let (aag, topIndex, frontIndex) = Self.topAndFrontFaces(in: shape) else {
            Issue.record("could not build the many-shared-edges fixture")
            return
        }

        guard let edge = aag.edge(between: topIndex, and: frontIndex) else {
            Issue.record("expected the top and front faces to be adjacent")
            return
        }

        // Pinned to the measured value (Scripts/repro/761-aag-brepgraph-adjacency/README.md):
        // 11 notches leave 12 shared boundary segments. Before this fix this was 10 (the old
        // hardcoded cap), not a geometric fact about the fixture.
        #expect(edge.sharedEdgeCount == 12)
        #expect(edge.sharedEdgeCount > 10, "the whole point of this fixture is to exceed the old cap")
    }

    /// The second, independent construction the measurement policy asks for: `BRepGraph`'s own
    /// `sharedEdges(between:and:)`, mapped to the same two occurrences via `findNode(for:)`, has
    /// no such cap (an unbounded `std::vector` on the bridge side, `bgSharedEdges` in
    /// `OCCTBridge_BRepGraph.mm`). It must agree with AAG's own count exactly now that AAG is no
    /// longer capped -- this is precisely the disagreement this issue's census found before the fix.
    @Test("agrees with BRepGraph's own uncapped sharedEdges count")
    func agreesWithBRepGraphsUncappedCount() {
        guard let shape = Self.manySharedEdgesFixture(),
              let (aag, topIndex, frontIndex) = Self.topAndFrontFaces(in: shape) else {
            Issue.record("could not build the many-shared-edges fixture")
            return
        }
        guard let aagEdge = aag.edge(between: topIndex, and: frontIndex) else {
            Issue.record("expected the top and front faces to be adjacent")
            return
        }

        let occ = shape.orientedFaces()
        guard let graph = BRepGraph(shape: shape),
              let topFaceShape = Shape.fromFace(occ[topIndex]),
              let frontFaceShape = Shape.fromFace(occ[frontIndex]),
              let topNode = graph.findNode(for: topFaceShape), topNode.kind == .face,
              let frontNode = graph.findNode(for: frontFaceShape), frontNode.kind == .face
        else {
            Issue.record("could not map the top/front faces into BRepGraph")
            return
        }

        let graphShared = graph.sharedEdges(between: topNode.index, and: frontNode.index)
        #expect(aagEdge.sharedEdgeCount == graphShared.count)
    }

    // MARK: - No regression on the ordinary case

    /// A plain box shares no more than one edge between any two adjacent faces. The fix must not
    /// change this -- it only changes how the buffer is SIZED, not the comparison itself.
    @Test("a plain box's adjacent faces still share exactly one edge")
    func plainBoxUnaffected() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("could not build the box")
            return
        }
        let aag = box.buildAAG()
        for i in 0..<aag.nodes.count {
            for j in (i + 1)..<aag.nodes.count {
                if let edge = aag.edge(between: i, and: j) {
                    #expect(edge.sharedEdgeCount == 1)
                }
            }
        }
    }

    /// Convexity classification (which reads only the FIRST shared edge, unaffected by how the
    /// count is sized) still resolves. This fixture's top/front pair should classify convex like
    /// any ordinary box corner -- the notches remove material, they do not add a concave junction
    /// at the corner itself.
    @Test("convexity still resolves for the many-shared-edges pair")
    func convexityStillResolves() {
        guard let shape = Self.manySharedEdgesFixture(),
              let (aag, topIndex, frontIndex) = Self.topAndFrontFaces(in: shape) else {
            Issue.record("could not build the many-shared-edges fixture")
            return
        }
        guard let edge = aag.edge(between: topIndex, and: frontIndex) else {
            Issue.record("expected the top and front faces to be adjacent")
            return
        }
        #expect(edge.convexity == .convex)
    }
}
