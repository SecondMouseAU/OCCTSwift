import Testing
import simd

@testable import OCCTSwift

@Suite("ProjectCurveOnSurface Tests")
struct ProjectCurveOnSurfaceTests {
    @Test("project line onto plane")
    func projectLineOnPlane() {
        // #766: the inputs sat behind `if let`, and only non-nil was checked. The plane's (u, v)
        // is (x, y), so the projected line runs (1, 2) -> (11, 2) over the trimmed range, as
        // ShapeConstruct_ProjectCurveOnSurface gives it (Scripts/repro/766-projection-trim-revolution-section/).
        let line = Curve3D.line(through: SIMD3(1, 2, 0), direction: SIMD3(1, 0, 0))
        let trimmed = line?.trimmed(from: 0, to: 10)
        let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        #expect(trimmed != nil && plane != nil)
        if let trimmed, let plane {
            let curve2d: Curve2D? = trimmed.projectOnSurface(plane)
            #expect(curve2d != nil)
            if let curve2d {
                #expect(simd_length(curve2d.point(at: 0) - SIMD2(1, 2)) < 1e-9)
                #expect(simd_length(curve2d.point(at: 10) - SIMD2(11, 2)) < 1e-9)
            }
        }
    }
}
