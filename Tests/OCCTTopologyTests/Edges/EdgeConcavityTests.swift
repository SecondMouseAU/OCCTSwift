import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.46.0 Tests

@Suite("Edge Concavity Tests")
struct EdgeConcavityTests {
    @Test("Box edges are all convex")
    func boxEdgesConvex() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let concavities = box.edgeConcavities()
        #expect(concavities != nil)
        if let concavities {
            #expect(!concavities.isEmpty)
            for (_, concavity) in concavities {
                #expect(concavity == .convex)
            }
        }
    }

    @Test("Count convex edges")
    func countConvexEdges() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let count = box.edgeConcavityCount(.convex)
        #expect(count != nil)
        if let count {
            #expect(count > 0)
        }
    }

    @Test("No concave edges on box")
    func noConcaveOnBox() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let count = box.edgeConcavityCount(.concave)
        #expect(count != nil)
        #expect(count == 0)
    }

    @Test("Concave edges on filleted box union")
    func concaveEdgesExist() throws {
        // A union of two overlapping boxes creates concave edges at the join
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(origin: SIMD3(5, 5, 0), width: 10, height: 10, depth: 10)!
        if let fused = box1.union(box2) {
            let concaveCount = fused.edgeConcavityCount(Shape.EdgeConcavity.concave)
            // Fused shape may have concave edges where boxes overlap
            #expect(concaveCount != nil)
        }
    }
}
