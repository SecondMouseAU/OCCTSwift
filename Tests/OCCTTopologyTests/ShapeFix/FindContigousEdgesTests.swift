import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("FindContigousEdges Tests")
struct FindContigousEdgesTests {
    @Test func findOnBox() throws {
        // A solid's edges are already shared, so nothing is left to find, and no shape is
        // degenerated. Two side-by-side squares share one coincident edge: that is found.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let result = box.findContigousEdges()
        #expect(result.contigousEdgeCount == 0)
        #expect(result.degeneratedShapeCount == 0)

        let outline = try #require(Wire.rectangle(width: 10, height: 10))
        let left = try #require(Shape.face(from: outline))
        let right = try #require(left.translated(by: SIMD3(10, 0, 0)))
        let pair = try #require(Shape.compound([left, right]))
        let found = pair.findContigousEdges()
        #expect(found.contigousEdgeCount == 1)
        #expect(found.degeneratedShapeCount == 0)
    }

    @Test func findWithTolerance() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        let result = sphere.findContigousEdges(tolerance: 0.001)
        #expect(result.contigousEdgeCount == 0)
        #expect(result.degeneratedShapeCount == 0)

        // The tolerance is what pairs a 0.0005 gap: found at 1e-3, not at 1e-6.
        let outline = try #require(Wire.rectangle(width: 10, height: 10))
        let left = try #require(Shape.face(from: outline))
        let nearly = try #require(left.translated(by: SIMD3(10.0005, 0, 0)))
        let pair = try #require(Shape.compound([left, nearly]))
        #expect(pair.findContigousEdges(tolerance: 1e-6).contigousEdgeCount == 0)
        #expect(pair.findContigousEdges(tolerance: 1e-3).contigousEdgeCount == 1)
    }
}
