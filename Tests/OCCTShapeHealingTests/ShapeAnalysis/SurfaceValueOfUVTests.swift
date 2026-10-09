import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeAnalysis Surface ValueOfUV Tests")
struct SurfaceValueOfUVTests {
    @Test("Project point onto plane, UV and gap")
    func projectOntoPlane() throws {
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
        let proj = plane.valueOfUV(point: SIMD3(5, 3, 2))
        #expect(abs(proj.uv.x - 5.0) < 0.1)
        #expect(abs(proj.uv.y - 3.0) < 0.1)
        #expect(abs(proj.gap - 2.0) < 0.1)
    }

    @Test("Project point onto sphere")
    func projectOntoSphere() throws {
        let sphere = Surface.sphere(center: .zero, radius: 5)!
        let proj = sphere.valueOfUV(point: SIMD3(0, 0, 10))
        // Gap should be 5 (10 - radius)
        #expect(abs(proj.gap - 5.0) < 0.5)
    }

    @Test("Next value of UV, iterative projection")
    func nextValueOfUV() throws {
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
        let proj1 = plane.valueOfUV(point: SIMD3(5, 3, 0))
        let proj2 = plane.nextValueOfUV(previousUV: proj1.uv, point: SIMD3(5.5, 3.5, 0))
        #expect(abs(proj2.uv.x - 5.5) < 0.1)
        #expect(abs(proj2.uv.y - 3.5) < 0.1)
    }
}
