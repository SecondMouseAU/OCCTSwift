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
        // #1979: the domain alone passed a curve built from the wrong poles. Pinned to the
        // values Geom2dEval_AHTBezierCurve reports for these inputs
        // (Scripts/repro/766-geom2d-aht-axisplacement/).
        let domain = curve.domain
        #expect(abs(domain.lowerBound) < 1e-12)
        #expect(abs(domain.upperBound - 1.0) < 1e-12)
        let mid = curve.point(at: 0.5)
        #expect(abs(mid.x - 7.72495409928) < 1e-9)
        #expect(abs(mid.y - 0.135033262487) < 1e-9)
    }
}
