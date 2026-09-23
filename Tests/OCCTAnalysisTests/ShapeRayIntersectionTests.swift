import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeRayIntersection Tests")
struct ShapeRayIntersectionTests {
    @Test("line intersection with box")
    func lineBoxIntersection() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        if let inter = ShapeRayIntersection(
            shape: box, originX: 5, originY: 5, originZ: -10,
            dirX: 0, dirY: 0, dirZ: 1)
        {
            let hits = inter.allHits()
            #expect(hits.count >= 2)
        }
    }

    @Test("curve intersection with sphere")
    func curveSphereIntersection() {
        let sphere = Shape.sphere(radius: 5)!
        if let line = Curve3D.line(through: SIMD3(0, 0, -10), direction: SIMD3(0, 0, 1)) {
            if let inter = ShapeRayIntersection(shape: sphere, curve: line) {
                let hits = inter.allHits()
                #expect(hits.count >= 2)
            }
        }
    }

    @Test("hit face access")
    func hitFaceAccess() {
        // `Shape.box` is centred, so this box spans -5...5 on every axis and a +Z ray
        // through the middle enters at z = -5 through a 10x10 cap face.
        //
        // Every assertion here is unconditional. The version before #2199 nested them
        // inside `if let inter`, `if inter.hasMore` and `if let face`, which made the
        // test pass on a bridge reporting no hits at all: returning false from
        // `OCCTCurveSurfaceInterMore` left it green while both sibling tests went red.
        guard
            let inter = ShapeRayIntersection(
                shape: Shape.box(width: 10, height: 10, depth: 10)!,
                originX: 0, originY: 0, originZ: -10,
                dirX: 0, dirY: 0, dirZ: 1)
        else {
            Issue.record("ShapeRayIntersection returned nil for a ray through a box")
            return
        }
        #expect(inter.hasMore, "a ray through the middle of a box hits it")

        // Read `currentHit` before `allHits()`: the iterator is consumed, and reading it
        // afterwards yields an all-zero Hit that the old `z >= -6 && z <= 6` accepted.
        let hit = inter.currentHit
        #expect(hit.x == 0)
        #expect(hit.y == 0)
        #expect(abs(hit.z - -5) < 1e-9, "entry face is the z = -5 cap, got z=\(hit.z)")

        guard let face = inter.currentFace else {
            Issue.record("a hit has a face")
            return
        }
        #expect(
            abs(face.area() - 100) < 1e-6,
            "the 10x10 cap has area 100, got \(face.area())")
    }
}
