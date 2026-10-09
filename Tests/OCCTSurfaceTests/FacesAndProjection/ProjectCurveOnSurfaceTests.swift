import Testing
import simd

@testable import OCCTSwift

@Suite("ProjectCurveOnSurface Tests")
struct ProjectCurveOnSurfaceTests {
    @Test("project line onto plane")
    func projectLineOnPlane() {
        if let line = Curve3D.line(through: SIMD3(1, 2, 0), direction: SIMD3(1, 0, 0)),
            let trimmed = line.trimmed(from: 0, to: 10),
            let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        {
            let curve2d = trimmed.projectOnSurface(plane)
            #expect(curve2d != nil)
        }
    }
}
