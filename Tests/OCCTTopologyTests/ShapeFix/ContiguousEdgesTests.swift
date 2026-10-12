import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("Contiguous Edges")
struct ContiguousEdgesTests {
    @Test("Find contiguous edges count on single solid")
    func findContiguousCountOnSolid() {
        // FindContigousEdges returns 0 on a single solid because edges are
        // already topologically shared by construction. The API is designed
        // to find shared edges between separate shapes in a compound.
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let count = box.contiguousEdgeCount()
        #expect(count == 0)
    }

    @Test("Contiguous edges API is callable")
    func contiguousEdgesCallable() throws {
        // A sphere is one face; nothing to pair.
        let sphere = try #require(Shape.sphere(radius: 5))
        #expect(sphere.contiguousEdgeCount() == 0)

        // Two separate 10-squares side by side share one coincident edge (x = 10), so exactly
        // one pair is found; the same squares 50 apart share none.
        let outline = try #require(Wire.rectangle(width: 10, height: 10))
        let left = try #require(Shape.face(from: outline))
        let right = try #require(left.translated(by: SIMD3(10, 0, 0)))
        let adjacent = try #require(Shape.compound([left, right]))
        #expect(adjacent.contiguousEdgeCount() == 1)

        let farAway = try #require(left.translated(by: SIMD3(50, 0, 0)))
        let apart = try #require(Shape.compound([left, farAway]))
        #expect(apart.contiguousEdgeCount() == 0)

        // The tolerance decides it: a 0.0005 gap is outside 1e-6 and inside 1e-3.
        let nearly = try #require(left.translated(by: SIMD3(10.0005, 0, 0)))
        let gapped = try #require(Shape.compound([left, nearly]))
        #expect(gapped.contiguousEdgeCount(tolerance: 1e-6) == 0)
        #expect(gapped.contiguousEdgeCount(tolerance: 1e-3) == 1)
    }
}
