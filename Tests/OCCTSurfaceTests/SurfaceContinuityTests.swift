import Testing
import simd

@testable import OCCTSwift

@Suite("Surface Continuity Tests")
struct SurfaceContinuityTests {

    // #766: each test was `c >= 0` / `spans >= 0` inside `if let`, true for any answer. Analytic
    // surfaces are GeomAbs_CN (6) in the kernel, and a plane's bounds are non-empty both ways, so
    // the bridge reports one span each. See Scripts/repro/766-surface-continuity/.
    @Test func planeContinuity() {
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        #expect(plane != nil)
        if let plane {
            #expect(plane.continuity == 6)
        }
    }

    @Test func sphereContinuity() {
        let sphere = Surface.sphere(center: .zero, radius: 5)
        #expect(sphere != nil)
        if let sphere {
            #expect(sphere.continuity == 6)
        }
    }

    @Test func surfaceNBounds() {
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        #expect(plane != nil)
        if let plane {
            let bounds = plane.nBounds
            #expect(bounds.uSpans == 1)
            #expect(bounds.vSpans == 1)
        }
    }
}
