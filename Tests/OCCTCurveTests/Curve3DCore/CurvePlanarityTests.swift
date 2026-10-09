import Foundation
import Testing
import simd

@testable import OCCTSwift

// ShapeAnalysis_Curve::IsPlanar on the same curves
// (Scripts/repro/766-curve-join-length-split/transcript.txt). The earlier circle test
// force-unwrapped inside #expect, and the line test discarded its result ("just verify it doesn't
// crash"), so it could not fail (#766).
@Suite("Curve Planarity Check")
struct CurvePlanarityTests {
    @Test("Circle is planar")
    func circleIsPlanar() {
        guard let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5) else {
            Issue.record("circle not built")
            return
        }
        guard let normal = circle.planeNormal() else {
            Issue.record("circle reported non-planar")
            return
        }
        #expect(simd_distance(normal, SIMD3(0, 0, 1)) < 1e-10)
    }

    @Test("Line is planar")
    func lineIsPlanar() {
        guard let segment = Curve3D.segment(from: .zero, to: SIMD3(10, 5, 0)) else {
            Issue.record("segment not built")
            return
        }
        // A segment lies in many planes; the kernel reports it planar with normal (0, 0, 1).
        guard let normal = segment.planeNormal() else {
            Issue.record("segment reported non-planar")
            return
        }
        #expect(simd_distance(normal, SIMD3(0, 0, 1)) < 1e-10)
    }
}
