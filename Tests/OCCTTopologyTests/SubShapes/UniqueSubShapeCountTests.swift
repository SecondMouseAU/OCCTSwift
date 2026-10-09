import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.114.0 - Unique SubShape Counts")
struct UniqueSubShapeCountTests {

    @Test func boxUniqueCounts() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            #expect(box.uniqueFaceCount == 6)
            #expect(box.uniqueEdgeCount == 12)
            #expect(box.uniqueVertexCount == 8)
        }
    }

    @Test func sphereUniqueCounts() {
        if let sphere = Shape.sphere(radius: 5) {
            #expect(sphere.uniqueFaceCount >= 1)
            #expect(sphere.uniqueEdgeCount >= 1)
        }
    }

    @Test func uniqueSubShapeCountByType() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            #expect(box.uniqueSubShapeCount(ofType: .solid) == 1)
            #expect(box.uniqueSubShapeCount(ofType: .shell) == 1)
            #expect(box.uniqueSubShapeCount(ofType: .face) == 6)
        }
    }
}
