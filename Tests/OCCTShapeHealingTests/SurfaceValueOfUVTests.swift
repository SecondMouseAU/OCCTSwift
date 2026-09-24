import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are ShapeAnalysis_Surface's own answers on the same surfaces and points,
// from Scripts/repro/766-healing-small-files/probe.mm. Before #766 these used tolerances of 0.1
// and 0.5 around exact answers, force-unwrapped the fixture, and the sphere test checked only
// the gap.
@Suite("ShapeAnalysis Surface ValueOfUV Tests")
struct SurfaceValueOfUVTests {
    @Test("Project point onto plane, UV and gap")
    func projectOntoPlane() throws {
        let plane = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        let proj = plane.valueOfUV(point: SIMD3(5, 3, 2))
        #expect(abs(proj.uv.x - 5.0) < 1e-9)
        #expect(abs(proj.uv.y - 3.0) < 1e-9)
        #expect(abs(proj.gap - 2.0) < 1e-9)
    }

    @Test("Project point onto sphere")
    func projectOntoSphere() throws {
        // Kernel: (0,0,10) projects to the pole, UV (0, pi/2), gap 5 (10 - radius).
        let sphere = try #require(Surface.sphere(center: .zero, radius: 5))
        let proj = sphere.valueOfUV(point: SIMD3(0, 0, 10))
        #expect(abs(proj.gap - 5.0) < 1e-9)
        #expect(abs(proj.uv.y - .pi / 2) < 1e-9)
    }

    @Test("Next value of UV, iterative projection")
    func nextValueOfUV() throws {
        let plane = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        let proj1 = plane.valueOfUV(point: SIMD3(5, 3, 0))
        let proj2 = plane.nextValueOfUV(previousUV: proj1.uv, point: SIMD3(5.5, 3.5, 0))
        #expect(abs(proj2.uv.x - 5.5) < 1e-9)
        #expect(abs(proj2.uv.y - 3.5) < 1e-9)
        #expect(abs(proj2.gap) < 1e-9)
    }
}
