import Testing
import simd

@testable import OCCTSwift

@Suite("v0.137 Surface.torusAxis / revolutionAxis")
struct SurfaceAxisAccessorsTests {
    @Test("Torus surface exposes axis")
    func torusSurfaceAxis() {
        let origin = SIMD3<Double>(1, 2, 3)
        let normal = SIMD3<Double>(0, 0, 1)
        guard
            let surf = Surface.torus(
                origin: origin, axis: normal,
                majorRadius: 20, minorRadius: 5)
        else {
            Issue.record("torus surface nil")
            return
        }
        if let axis = surf.torusAxis {
            #expect(abs(axis.origin.x - 1) < 1e-6)
            #expect(abs(axis.origin.y - 2) < 1e-6)
            #expect(abs(axis.origin.z - 3) < 1e-6)
            #expect(abs(axis.direction.z - 1) < 1e-6)
        } else {
            Issue.record("torus surface has no axis")
        }
    }

    @Test("Cylinder surface returns nil for torusAxis")
    func cylinderSurfaceNoTorusAxis() {
        guard let surf = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5)
        else {
            Issue.record("cylinder surface nil")
            return
        }
        #expect(surf.torusAxis == nil)
        #expect(surf.revolutionAxis == nil)
        #expect(surf.surfaceKind == .cylinder)
    }
}
