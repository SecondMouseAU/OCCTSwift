import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepExtrema_SelfIntersection Pair Tests")
struct SelfIntersectionPairTests {

    /// A compound of two crossing boxes, the positive fixture.
    ///
    /// Two interpenetrating boxes in one compound, never fused, so their faces cross. Box A spans
    /// -5...5, box B spans 0...10 on every axis. Measured in
    /// Scripts/repro/766-self-intersection-pair-tests/transcript.txt: six crossing face pairs,
    /// (1,8) (1,10) (3,6) (3,10) (5,6) (5,8), in BRepExtrema_SelfIntersection's own numbering.
    static func overlappingBoxes() -> Shape? {
        guard let a = Shape.box(width: 10, height: 10, depth: 10),
            let b = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10)
        else { return nil }
        return Shape.compound([a, b])
    }

    /// A single box reports no self-intersecting face pairs.
    ///
    /// The box alone has no self-intersection. The positive control is the overlapping pair: on
    /// its own `pairs.isEmpty` also passes against a bridge that never finds anything (#1757).
    @Test func noSelfIntersectionOnBox() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let overlapping = Self.overlappingBoxes()
        else {
            Issue.record("fixture construction failed")
            return
        }
        let pairs = box.selfIntersectionPairs(tolerance: 0.0)
        #expect(pairs.isEmpty, "a single box does not self-intersect, got \(pairs.count) pairs")
        #expect(!overlapping.selfIntersectionPairs(tolerance: 0.0).isEmpty, "positive control")
    }

    /// A sphere reports none, and two crossing boxes their six pairs.
    ///
    /// The version of this test before #1758 asserted `pairs.count >= 0` on an `Array`, which
    /// cannot be false. It now pins both results: the sphere reports no pairs, and the overlapping
    /// compound reports exactly its six crossing face pairs, each once, lower index first.
    @Test func selfIntersectionReturnsArray() {
        guard let sphere = Shape.sphere(radius: 5),
            let overlapping = Self.overlappingBoxes()
        else {
            Issue.record("fixture construction failed")
            return
        }
        let spherePairs = sphere.selfIntersectionPairs(tolerance: 0.0, maxPairs: 50)
        #expect(
            spherePairs.isEmpty, "a sphere does not self-intersect, got \(spherePairs.count) pairs")

        let pairs = overlapping.selfIntersectionPairs(tolerance: 0.0, maxPairs: 50)
        #expect(pairs.count == 6, "two crossing boxes meet in six face pairs, got \(pairs.count)")
        let found = Set(pairs.map { [$0.faceIndex1, $0.faceIndex2] })
        let expected: Set<[Int]> = [[1, 8], [1, 10], [3, 6], [3, 10], [5, 6], [5, 8]]
        #expect(found == expected, "got \(found.sorted { $0.lexicographicallyPrecedes($1) })")
    }
}
