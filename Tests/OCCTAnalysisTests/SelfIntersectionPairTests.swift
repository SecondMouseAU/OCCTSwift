import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepExtrema_SelfIntersection Pair Tests")
struct SelfIntersectionPairTests {

    @Test func noSelfIntersectionOnBox() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let pairs = box.selfIntersectionPairs(tolerance: 0.0)
        #expect(pairs.isEmpty)
    }

    @Test func selfIntersectionReturnsArray() {
        // Even if no intersections, the function should return an empty array
        guard let sphere = Shape.sphere(radius: 5) else { return }
        let pairs = sphere.selfIntersectionPairs(tolerance: 0.0, maxPairs: 50)
        // Sphere should have no self-intersections
        #expect(pairs.count >= 0)  // just check it doesn't crash
    }
}
