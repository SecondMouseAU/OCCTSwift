import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: only `lowerBound >= 0` and `upperBound > 0`. Now pinned to Geom2dEval_TBezierCurve:
// domain [0, pi], and with alpha = 1 the trigonometric basis does not interpolate the end poles:
// the curve runs (2, 0) -> (1, 1) -> (-2, 0) (Scripts/repro/766-geom2d-projlib-wire-tbezier/).
@Suite("Geom2dEval TBezier 2D Curve")
struct TBezierCurve2DTests {

    @Test func createAndEval() throws {
        let poles: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0),
        ]
        let curve = try #require(Curve2D.tBezier(poles: poles, alpha: 1.0))
        let domain = curve.domain
        #expect(abs(domain.lowerBound) < 1e-12)
        #expect(abs(domain.upperBound - .pi) < 1e-12)
        #expect(simd_distance(curve.point(at: 0), SIMD2(2, 0)) < 1e-9)
        #expect(simd_distance(curve.point(at: .pi / 2), SIMD2(1, 1)) < 1e-9)
        #expect(simd_distance(curve.point(at: .pi), SIMD2(-2, 0)) < 1e-9)
    }
}
