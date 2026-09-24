import Foundation
import Testing
import simd

@testable import OCCTSwift

// Values are Geom_Curve::EvalD0..D3 on the same interpolated curve at the same parameter
// (Scripts/repro/766-curve-conversion-draw-eval/transcript.txt). The earlier evalD2 and evalD3
// ended in `#expect(true)` and could not fail, evalD1 checked the derivative only for being
// non-zero, and every body sat inside `if let` (#766).
@Suite("Curve3D Evaluation v0.110")
struct Curve3DEvalTests {
    private static func curve() -> Curve3D? {
        let c = Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 3, 0), SIMD3(5, 5, 0), SIMD3(8, 3, 0), SIMD3(10, 0, 0),
        ])
        if c == nil { Issue.record("interpolated curve not built") }
        return c
    }

    private static let mid = 7.2111025509279782
    private static let p = SIMD3<Double>(5, 5, 0)
    private static let d1 = SIMD3<Double>(0.8782753106899468, 0, 0)
    private static let d2 = SIMD3<Double>(0, -0.44230769230769207, 0)
    private static let d3 = SIMD3<Double>(-0.0213346229317402, 0.11200677039163265, 0)

    @Test func evalD0BSpline() {
        guard let curve = Self.curve() else { return }
        let p = curve.evalD0(at: curve.domain.lowerBound)
        #expect(simd_length(p) < 1e-12)
    }

    @Test func evalD1BSpline() {
        guard let curve = Self.curve() else { return }
        let mid = (curve.domain.lowerBound + curve.domain.upperBound) / 2
        #expect(abs(mid - Self.mid) < 1e-12)
        let r = curve.evalD1(at: mid)
        // The point half must agree with the independently-tested point(at:) accessor
        // (a different bridge call, OCCTCurve3DGetPoint vs. OCCTCurve3DEvalD1), which
        // catches a point/tangent swap that a magnitude-only check on d1 alone would miss.
        #expect(simd_distance(r.point, curve.point(at: mid)) < 1e-9)
        #expect(simd_distance(r.point, Self.p) < 1e-12)
        #expect(simd_distance(r.d1, Self.d1) < 1e-12)
    }

    @Test func evalD2BSpline() {
        guard let curve = Self.curve() else { return }
        let r = curve.evalD2(at: Self.mid)
        #expect(simd_distance(r.point, Self.p) < 1e-12)
        #expect(simd_distance(r.d1, Self.d1) < 1e-12)
        #expect(simd_distance(r.d2, Self.d2) < 1e-12)
    }

    @Test func evalD3BSpline() {
        guard let curve = Self.curve() else { return }
        let r = curve.evalD3(at: Self.mid)
        #expect(simd_distance(r.point, Self.p) < 1e-12)
        #expect(simd_distance(r.d2, Self.d2) < 1e-12)
        #expect(simd_distance(r.d3, Self.d3) < 1e-12)
    }

    @Test func evalD0Circle() {
        guard let curve = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5)
        else {
            Issue.record("circle not built")
            return
        }
        #expect(curve.evalD0(at: 0) == SIMD3(5, 0, 0))
    }
}
