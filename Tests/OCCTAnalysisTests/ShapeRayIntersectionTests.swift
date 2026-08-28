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
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        if let inter = ShapeRayIntersection(
            shape: box, originX: 5, originY: 5, originZ: -10,
            dirX: 0, dirY: 0, dirZ: 1)
        {
            if inter.hasMore {
                let hit = inter.currentHit
                #expect(hit.z >= -6 && hit.z <= 6)
                if let face = inter.currentFace {
                    #expect(face.area() > 0)
                }
            }
        }
    }
}
