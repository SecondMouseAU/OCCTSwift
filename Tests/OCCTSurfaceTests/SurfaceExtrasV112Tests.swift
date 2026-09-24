import Testing
import simd

@testable import OCCTSwift

@Suite("Surface extras v0.112")
struct SurfaceExtrasV112Tests {

    @Test func surfaceTypePlane() {
        // #766: `if let` made unconditional; GeomAdaptor_Surface::GetType is GeomAbs_Plane (0).
        let surf = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        #expect(surf != nil)
        if let surf {
            #expect(surf.surfaceType == 0)  // Plane
        }
    }

    @Test func surfaceTypeSphere() {
        let surf = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5)
        #expect(surf != nil)
        if let surf {
            #expect(surf.surfaceType == 3)  // Sphere
        }
    }
}
