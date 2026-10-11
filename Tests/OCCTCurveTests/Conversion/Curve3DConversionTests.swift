import Foundation
import Testing
import simd

@testable import OCCTSwift

// Pinned to the same OCCT conversions on the same curves
// (Scripts/repro/766-curve-conversion-draw-eval/transcript.txt). The earlier versions checked
// `!= nil`, `> 0` or `>= 2` inside `if let`, and ended points to 0.1, so a conversion that raised
// the degree, dropped an arc, or an approximation that strayed from the arc, passed (#766). The
// fixtures were force-unwrapped; they now record an issue instead.
@Suite("Curve3D Conversion Tests")
struct Curve3DConversionTests {
    private static func circle() -> Curve3D? {
        let c = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)
        if c == nil { Issue.record("circle not built") }
        return c
    }

    @Test("Circle to BSpline")
    func circleToBSpline() {
        guard let circle = Self.circle() else { return }
        guard let b = circle.toBSpline() else {
            Issue.record("toBSpline returned nil")
            return
        }
        // GeomConvert::CurveToBSplineCurve: rational periodic quadratic, 6 poles.
        #expect(b.poleCount == 6)
        #expect(b.degree == 2)
        #expect(b.isPeriodic)
    }

    @Test("BSpline to Bezier segments")
    func bsplineToBeziers() {
        guard let circle = Self.circle() else { return }
        guard let segs = circle.toBezierSegments() else {
            Issue.record("toBezierSegments returned nil")
            return
        }
        #expect(segs.count == 3)
    }

    @Test("Join two segments into BSpline")
    func joinCurves() {
        guard let seg1 = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(5, 0, 0)),
            let seg2 = Curve3D.segment(from: SIMD3(5, 0, 0), to: SIMD3(10, 5, 0))
        else {
            Issue.record("segments not built")
            return
        }
        guard let j = Curve3D.join([seg1, seg2]) else {
            Issue.record("join returned nil")
            return
        }
        #expect(simd_distance(j.startPoint, SIMD3(0, 0, 0)) < 1e-12)
        #expect(simd_distance(j.endPoint, SIMD3(10, 5, 0)) < 1e-12)
        #expect(abs(j.domain.upperBound - (5 + 50.0.squareRoot())) < 1e-9)
    }

    @Test("Join returns nil rather than silently dropping a disconnected curve")
    func joinRejectsDisconnectedCurve() {
        // seg2 starts 4 units away from seg1's end, far past the default 1e-6 tolerance, so
        // GeomConvert_CompCurveToBSplineCurve::Add() must fail (no G0 continuity). The join
        // must fail too, not silently hand back seg1 alone with seg2 dropped (#1441).
        guard let seg1 = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(1, 0, 0)),
            let seg2 = Curve3D.segment(from: SIMD3(5, 0, 0), to: SIMD3(6, 0, 0))
        else {
            Issue.record("segments not built")
            return
        }
        #expect(Curve3D.join([seg1, seg2]) == nil)
    }

    @Test("Approximate curve")
    func approximateCurve() {
        guard let circle = Self.circle(), let arc = circle.trimmed(from: 0, to: .pi) else {
            Issue.record("arc not built")
            return
        }
        guard let approx = arc.approximated(tolerance: 0.01) else {
            Issue.record("approximated returned nil")
            return
        }
        // Within the 0.01 tolerance of the r = 5 half circle everywhere.
        #expect(simd_distance(approx.startPoint, SIMD3(5, 0, 0)) < 0.01)
        #expect(simd_distance(approx.endPoint, SIMD3(-5, 0, 0)) < 0.01)
        let d = approx.domain
        for i in 0...16 {
            let p = approx.point(at: d.lowerBound + (d.upperBound - d.lowerBound) * Double(i) / 16)
            #expect(abs(simd_length(p) - 5) < 0.01)
        }
    }
}
