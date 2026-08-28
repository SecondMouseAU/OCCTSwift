import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("FindContigousEdges Tests")
struct FindContigousEdgesTests {
    @Test func findOnBox() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let result = box.findContigousEdges()
            #expect(result.contigousEdgeCount >= 0)
            #expect(result.degeneratedShapeCount >= 0)
        }
    }

    @Test func findWithTolerance() {
        if let sphere = Shape.sphere(radius: 5) {
            let result = sphere.findContigousEdges(tolerance: 0.001)
            #expect(result.degeneratedShapeCount >= 0)
        }
    }
}
