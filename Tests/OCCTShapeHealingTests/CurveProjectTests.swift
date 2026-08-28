import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeAnalysis Curve Project Tests")
struct CurveProjectTests {
    @Test("Project point onto line segment")
    func projectOntoLine() throws {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let proj = seg.projectPoint(SIMD3(5, 3, 0))
        #expect(abs(proj.distance - 3.0) < 0.1)
        #expect(abs(proj.parameter - 5.0) < 0.1)
        #expect(simd_distance(proj.point, SIMD3(5, 0, 0)) < 0.1)
    }

    @Test("Project point onto circle")
    func projectOntoCircle() throws {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        // Point at (10, 0, 0), closest circle point at (5, 0, 0), distance 5
        let proj = circle.projectPoint(SIMD3(10, 0, 0))
        #expect(abs(proj.distance - 5.0) < 0.1)
        #expect(simd_distance(proj.point, SIMD3(5, 0, 0)) < 0.5)
    }
}
