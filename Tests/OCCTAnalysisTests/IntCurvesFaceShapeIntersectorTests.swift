import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntCurvesFace ShapeIntersector")
struct IntCurvesFaceShapeIntersectorTests {
    @Test("Ray intersects box")
    func rayIntersectsBox() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let results = try #require(
            box.rayIntersect(
                origin: SIMD3(5, 5, -20),
                direction: SIMD3(0, 0, 1)
            ))
        // The ray runs along the box's x = 5, y = 5 edge and meets the two end faces:
        // (5, 5, -5) and (5, 5, 5) (`Scripts/repro/766-intcs-inttools/`).
        #expect(results.count == 2)
    }

    @Test("Ray nearest intersection with sphere")
    func rayNearestSphere() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        let nearest = try #require(
            sphere.rayIntersectNearest(
                origin: SIMD3(0, 0, -20),
                direction: SIMD3(0, 0, 1)
            ))
        // The kernel gives (0, 0, -5) exactly, at parameter 15 (`Scripts/repro/766-intcs-inttools/`).
        #expect(abs(nearest.point.x) < 1e-9)
        #expect(abs(nearest.point.y) < 1e-9)
        #expect(abs(nearest.point.z - (-5)) < 1e-9)
    }

    @Test("Ray misses shape")
    func rayMissesShape() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let results = box.rayIntersect(
            origin: SIMD3(100, 100, -20),
            direction: SIMD3(0, 0, 1)
        )
        // No hits is reported as nil today: the bridge returns false when NbPnt is 0 and the
        // wrapper maps that to nil. An empty array would mean the same, so both are accepted by
        // design; only a non-empty result, a hit that is not there, fails.
        #expect(results?.isEmpty ?? true)
    }
}
