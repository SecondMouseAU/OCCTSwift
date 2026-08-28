import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill BoundWithSurf")
struct GeomFillBoundWithSurfTests {
    @Test func boundaryWithSurface() {
        let surf = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        let curve = Curve2D.line(through: SIMD2(0, 0.5), direction: SIMD2(1, 0))
        if let surf = surf, let curve = curve {
            let result = surf.boundaryWithSurfaceEvaluate(
                curve2d: curve, first: 0, last: 1, parameter: 0.5)
            #expect(result != nil)
            if let r = result {
                // Normal should be ±Z for a plane
                #expect(abs(r.normal.z) > 0.9)
            }
        }
    }
}
