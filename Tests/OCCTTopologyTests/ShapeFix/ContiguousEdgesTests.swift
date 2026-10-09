import Foundation
import OCCTBridge
import Testing
import simd

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
    func contiguousEdgesCallable() {
        let sphere = Shape.sphere(radius: 5)!
        let count = sphere.contiguousEdgeCount()
        #expect(count >= 0)
    }
}
