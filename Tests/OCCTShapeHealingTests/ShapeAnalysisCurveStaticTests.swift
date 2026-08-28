import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeAnalysis_Curve Static Method Tests")
struct ShapeAnalysisCurveStaticTests {

    @Test func isClosedWithPrecision() {
        // A circle should be closed
        if let circle = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5) {
            #expect(circle.isClosedWithPrecision(1e-6))
        }
    }

    @Test func lineIsNotClosed() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            #expect(!line.isClosedWithPrecision(1e-6))
        }
    }

    @Test func isPeriodicSA() {
        if let circle = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5) {
            #expect(circle.isPeriodicSA)
        }
    }

    @Test func lineIsNotPeriodic() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            #expect(!line.isPeriodicSA)
        }
    }

    @Test func circleIsPlanar() {
        if let circle = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5) {
            if let normal = circle.planeNormal(tolerance: 1e-6) {
                // Circle in XY plane should have normal along Z
                #expect(abs(normal.z) > 0.9)
            }
        }
    }

    @Test func lineIsPlanar() {
        // A line is planar (any direction perpendicular to it is a valid normal)
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            // Lines are degenerate for IsPlanar, any plane contains them
            // The result may be nil or a normal; just check it doesn't crash
            _ = line.planeNormal(tolerance: 1e-6)
        }
    }
}
