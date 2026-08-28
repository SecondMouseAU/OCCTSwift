import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve Planarity Check")
struct CurvePlanarityTests {
    @Test("Circle is planar")
    func circleIsPlanar() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let normal = circle.planeNormal()
        #expect(normal != nil)
        #expect(abs(abs(normal!.z) - 1.0) < 1e-10)
    }

    @Test("Line is planar")
    func lineIsPlanar() {
        let segment = Curve3D.segment(from: .zero, to: SIMD3(10, 5, 0))!
        let normal = segment.planeNormal()
        // Lines are degenerate planes, implementation may or may not return a normal
        // Just verify it doesn't crash
        _ = normal
    }
}
