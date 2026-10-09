import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Surface Bounding Box")
struct SurfaceBoundingBoxTests {
    @Test("Sphere bounding box")
    func sphereBoundingBox() {
        let r: Double = 5
        let sphere = Surface.sphere(center: SIMD3(10, 0, 0), radius: r)!
        let bb = sphere.boundingBox
        #expect(bb != nil)
        if let bb = bb {
            #expect(bb.min.x < 10 - r + 0.1)
            #expect(bb.max.x > 10 + r - 0.1)
            #expect(bb.min.y < -r + 0.1)
            #expect(bb.max.y > r - 0.1)
        }
    }

    @Test("Bezier surface bounding box")
    func bezierBoundingBox() {
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(10, 0, 0)],
            [SIMD3(0, 10, 5), SIMD3(10, 10, 5)],
        ]
        let bez = Surface.bezier(poles: poles)!
        let bb = bez.boundingBox
        #expect(bb != nil)
        if let bb = bb {
            #expect(bb.min.x < 0.1)
            #expect(bb.max.x > 9.9)
            #expect(bb.max.z > 4.9)
        }
    }
}
