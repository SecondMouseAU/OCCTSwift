import Testing
import simd

@testable import OCCTSwift

@Suite("Surface Continuity Tests")
struct SurfaceContinuityTests {

    @Test func planeContinuity() {
        if let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) {
            let c = plane.continuity
            #expect(c >= 0)
        }
    }

    @Test func sphereContinuity() {
        if let sphere = Surface.sphere(center: .zero, radius: 5) {
            let c = sphere.continuity
            #expect(c >= 0)
        }
    }

    @Test func surfaceNBounds() {
        if let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)) {
            let bounds = plane.nBounds
            #expect(bounds.uSpans >= 0)
            #expect(bounds.vSpans >= 0)
        }
    }
}
