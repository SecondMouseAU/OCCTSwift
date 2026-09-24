import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-curve-custom/probe.mm (transcript.txt beside it).
@Suite("ShapeAnalysis Curve Project Tests")
struct CurveProjectTests {
    @Test("Project point onto line segment")
    func projectOntoLine() throws {
        let seg = try #require(Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)))
        let proj = seg.projectPoint(SIMD3(5, 3, 0))
        #expect(abs(proj.distance - 3.0) < 1e-9)
        #expect(abs(proj.parameter - 5.0) < 1e-9)
        #expect(simd_distance(proj.point, SIMD3(5, 0, 0)) < 1e-9)
    }

    @Test("Project point onto circle")
    func projectOntoCircle() throws {
        let circle = try #require(Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5))
        // Point at (10, 0, 0), closest circle point at (5, 0, 0), distance 5, parameter 0
        let proj = circle.projectPoint(SIMD3(10, 0, 0))
        #expect(abs(proj.distance - 5.0) < 1e-9)
        #expect(abs(proj.parameter) < 1e-9)
        #expect(simd_distance(proj.point, SIMD3(5, 0, 0)) < 1e-9)
    }
}
