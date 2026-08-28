import Testing
import simd

@testable import OCCTSwift

@Suite("GeomConvert ApproxSurface Tests")
struct GeomConvertApproxSurfaceTests {
    @Test("approximate sphere as BSpline surface")
    func approxSphere() {
        if let sph = Surface.sphere(center: SIMD3(0, 0, 0), radius: 10) {
            let result = sph.approxWithDetails(tolerance: 1e-3)
            #expect(result.hasResult)
            if let surf = result.surface {
                let _ = surf
            }
        }
    }
}
