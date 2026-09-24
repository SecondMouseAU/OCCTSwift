import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-shapeanalysis/probe.mm (transcript.txt beside it).
// Before #766 every test here sat inside `if let`, silently green if the curve failed to build,
// and `lineIsPlanar` discarded its answer.
@Suite("ShapeAnalysis_Curve Static Method Tests")
struct ShapeAnalysisCurveStaticTests {
    private func circle() throws -> Curve3D {
        try #require(Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5))
    }
    private func line() throws -> Curve3D {
        try #require(Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)))
    }

    @Test func isClosedWithPrecision() throws {
        #expect(try circle().isClosedWithPrecision(1e-6))
    }

    @Test func lineIsNotClosed() throws {
        #expect(!(try line().isClosedWithPrecision(1e-6)))
    }

    @Test func isPeriodicSA() throws {
        #expect(try circle().isPeriodicSA)
    }

    @Test func lineIsNotPeriodic() throws {
        #expect(!(try line().isPeriodicSA))
    }

    @Test func circleIsPlanar() throws {
        // Kernel: planar, normal (0, 0, 1).
        let normal = try #require(try circle().planeNormal(tolerance: 1e-6))
        #expect(simd_distance(normal, SIMD3(0, 0, 1)) < 1e-12)
    }

    @Test func lineIsPlanar() throws {
        // A line lies in every plane containing it; the kernel reports planar with normal
        // (0, 0, 1) for this one.
        let normal = try #require(try line().planeNormal(tolerance: 1e-6))
        #expect(simd_distance(normal, SIMD3(0, 0, 1)) < 1e-12)
    }
}
