import Testing
import simd

@testable import OCCTSwift

@Suite("Multi-Edge Blend Tests")
struct MultiEdgeBlendTests {

    @Test("Blend multiple edges with different radii")
    func blendMultipleEdges() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!

        // Fillet three edges with different radii
        let blended = box.blendedEdges([
            (0, 1.0),
            (1, 2.0),
            (2, 1.5),
        ])

        #expect(blended != nil)
        if let blended = blended {
            #expect(blended.isValid)
        }
    }

    @Test("Blend single edge")
    func blendSingleEdge() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let blended = box.blendedEdges([(0, 1.0)])

        #expect(blended != nil)
        if let blended = blended {
            #expect(blended.isValid)
        }
    }

    @Test("Blend with empty array returns nil")
    func blendEmptyArray() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let blended = box.blendedEdges([])

        #expect(blended == nil)
    }
}
