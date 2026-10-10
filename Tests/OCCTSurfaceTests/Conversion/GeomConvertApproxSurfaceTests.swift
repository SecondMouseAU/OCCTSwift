import Testing
import simd

@testable import OCCTSwift

@Suite("GeomConvert ApproxSurface Tests")
struct GeomConvertApproxSurfaceTests {
    @Test("approximate sphere as BSpline surface")
    func approxSphere() {
        // #766: the sphere sat behind `if let` and the surface was bound and discarded, so only
        // `hasResult` was checked; an approximation at 1000x the tolerance passed. Pinned to
        // GeomConvert_ApproxSurface's own MaxError on the same call, see
        // Scripts/repro/766-geomeval-approx/.
        let sph = Surface.sphere(center: SIMD3(0, 0, 0), radius: 10)
        #expect(sph != nil)
        if let sph {
            let result = sph.approxWithDetails(tolerance: 1e-3)
            #expect(result.hasResult)
            #expect(result.isDone)
            #expect(abs(result.maxError - 0.00020644039516730319) < 1e-12)
            #expect(result.surface != nil)
            if let surf = result.surface {
                #expect(abs(simd_length(surf.point(atU: 1.0, v: 0.5)) - 10) < 1e-3)
            }
        }
    }
}
