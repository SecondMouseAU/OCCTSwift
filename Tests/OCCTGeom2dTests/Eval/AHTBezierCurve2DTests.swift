import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom2dEval AHTBezier 2D Curve")
struct AHTBezierCurve2DTests {

    @Test func createAndEval() {
        // algDeg=0, alpha=1.0, beta=1.0 => 5 poles
        var poles: [SIMD2<Double>] = []
        for i in 0..<5 {
            poles.append(SIMD2(Double(i), 0.5 * sin(Double(i + 1))))
        }
        guard let curve = Curve2D.ahtBezier(poles: poles, algDegree: 0, alpha: 1.0, beta: 1.0)
        else {
            #expect(Bool(false), "Failed to create 2D AHTBezier curve")
            return
        }
        let domain = curve.domain
        #expect(domain.lowerBound >= 0)
        #expect(domain.upperBound > 0)
    }
}
