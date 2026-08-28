import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntCurvesFace ShapeIntersector")
struct IntCurvesFaceShapeIntersectorTests {
    @Test("Ray intersects box")
    func rayIntersectsBox() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let results = box.rayIntersect(
            origin: SIMD3(5, 5, -20),
            direction: SIMD3(0, 0, 1)
        )
        #expect(results != nil)
        if let results = results {
            #expect(results.count >= 2)
        }
    }

    @Test("Ray nearest intersection with sphere")
    func rayNearestSphere() {
        guard let sphere = Shape.sphere(radius: 5) else { return }
        let nearest = sphere.rayIntersectNearest(
            origin: SIMD3(0, 0, -20),
            direction: SIMD3(0, 0, 1)
        )
        #expect(nearest != nil)
        if let nearest = nearest {
            #expect(abs(nearest.point.z - (-5)) < 0.1)
        }
    }

    @Test("Ray misses shape")
    func rayMissesShape() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let results = box.rayIntersect(
            origin: SIMD3(100, 100, -20),
            direction: SIMD3(0, 0, 1)
        )
        // Should return nil (no hits) or empty
        if let results = results {
            #expect(results.isEmpty)
        }
    }
}
