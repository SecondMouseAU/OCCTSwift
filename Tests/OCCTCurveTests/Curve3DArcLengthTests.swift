import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Curve3D Arc Length

@Suite("Curve3D Arc Length")
struct Curve3DArcLengthTests {
    // Pinned to GCPnts_AbscissaPoint on the same curves
    // (Scripts/repro/766-curve-arc-bezier-bspline/transcript.txt). The earlier versions used
    // tolerances of 0.01 to 0.1 inside `if let`, loose enough to pass a length off by 0.1% (#766).
    private static func segment() -> Curve3D? {
        let c = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))
        if c == nil { Issue.record("segment not built") }
        return c
    }
    @Test func totalArcLength() {
        guard let line = Self.segment() else { return }
        #expect(abs(line.totalArcLength - 10.0) < 1e-12)
    }

    @Test func arcLengthBetween() {
        guard let line = Self.segment() else { return }
        let d = line.domain
        let half = line.arcLengthBetween(d.lowerBound, (d.lowerBound + d.upperBound) / 2)
        #expect(abs(half - 5.0) < 1e-12)
    }

    @Test func parameterAtLength() {
        guard let line = Self.segment() else { return }
        let midParam = line.parameterAtLength(5.0)
        #expect(abs(midParam - 5.0) < 1e-9)
        #expect(simd_distance(line.point(at: midParam), SIMD3(5, 0, 0)) < 1e-9)
    }

    @Test func parameterAtLengthCircle() {
        guard let circle = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 10)
        else {
            Issue.record("circle not built")
            return
        }
        let circumference = circle.totalArcLength
        #expect(abs(circumference - 2 * Double.pi * 10) < 1e-9)
        // Quarter arc length gives parameter pi/2, the point (0, 10, 0).
        let param = circle.parameterAtLength(circumference / 4)
        #expect(abs(param - Double.pi / 2) < 1e-9)
        #expect(simd_distance(circle.point(at: param), SIMD3(0, 10, 0)) < 1e-8)
    }
}
