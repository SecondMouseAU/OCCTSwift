import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom2dEval TBezier 2D Curve")
struct TBezierCurve2DTests {

    @Test func createAndEval() {
        let poles: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0),
        ]
        guard let curve = Curve2D.tBezier(poles: poles, alpha: 1.0) else {
            #expect(Bool(false), "Failed to create 2D TBezier curve")
            return
        }
        let domain = curve.domain
        #expect(domain.lowerBound >= 0)
        #expect(domain.upperBound > 0)
    }
}
