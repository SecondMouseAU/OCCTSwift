import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill BoundWithSurf")
struct GeomFillBoundWithSurfTests {
    @Test func boundaryWithSurface() {
        let surf = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        let curve = Curve2D.line(through: SIMD2(0, 0.5), direction: SIMD2(1, 0))
        // #766: the inputs sat behind `if let`, the point was never checked, and `|n.z| > 0.9`
        // passed either orientation. GeomFill_BoundWithSurf gives (0.5, 0.5, 0) and normal
        // (0, 0, 1) at 0.5, see Scripts/repro/766-geomfill-a/.
        #expect(surf != nil && curve != nil)
        if let surf = surf, let curve = curve {
            let result = surf.boundaryWithSurfaceEvaluate(
                curve2d: curve, first: 0, last: 1, parameter: 0.5)
            #expect(result != nil)
            if let r = result {
                #expect(simd_length(r.point - SIMD3(0.5, 0.5, 0)) < 1e-12)
                #expect(simd_length(r.normal - SIMD3(0, 0, 1)) < 1e-12)
            }
        }
    }
}
