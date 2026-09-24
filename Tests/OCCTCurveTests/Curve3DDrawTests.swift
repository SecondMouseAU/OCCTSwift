import Foundation
import Testing
import simd

@testable import OCCTSwift

// Counts are the GCPnts samplers' on the same curves at the same settings
// (Scripts/repro/766-curve-conversion-draw-eval/transcript.txt). The earlier versions accepted
// `>= 10`, `>= 4` and `>= 2`, and force-unwrapped their fixtures (#766).
@Suite("Curve3D Draw Tests")
struct Curve3DDrawTests {
    private static func circle() -> Curve3D? {
        let c = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)
        if c == nil { Issue.record("circle not built") }
        return c
    }

    @Test("Adaptive draw on circle produces points")
    func adaptiveDrawCircle() {
        guard let circle = Self.circle() else { return }
        let points = circle.drawAdaptive()
        // GCPnts_TangentialDeflection(0.1 rad, 0.01) on the r = 5 circle.
        #expect(points.count == 64)
        for p in points {
            #expect(abs(simd_length(SIMD2(p.x, p.y)) - 5) < 1e-9)
        }
    }

    @Test("Uniform draw produces exact count")
    func uniformDraw() {
        guard let circle = Self.circle() else { return }
        let points = circle.drawUniform(pointCount: 32)
        #expect(points.count == 32)
        for p in points {
            #expect(abs(simd_length(SIMD2(p.x, p.y)) - 5) < 1e-9)
        }
    }

    @Test("Deflection draw produces points")
    func deflectionDraw() {
        guard let circle = Self.circle() else { return }
        let points = circle.drawDeflection(deflection: 0.1)
        // GCPnts_UniformDeflection at 0.1.
        #expect(points.count == 17)
    }

    @Test("Adaptive draw on segment produces at least 2 points")
    func adaptiveDrawSegment() {
        guard let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 5, 3)) else {
            Issue.record("segment not built")
            return
        }
        let points = seg.drawAdaptive()
        // A straight segment needs only its two ends.
        #expect(points.count == 2)
        #expect(simd_distance(points.first ?? .zero, SIMD3(0, 0, 0)) < 1e-12)
        #expect(simd_distance(points.last ?? .zero, SIMD3(10, 5, 3)) < 1e-12)
    }
}
