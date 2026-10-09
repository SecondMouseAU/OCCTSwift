import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GccAna Lin2d2Tan Tests")
struct GccAnaLin2d2TanTests {
    @Test("line through two points")
    func throughPoints() {
        let result = lineThroughPoints(SIMD2(0, 0), SIMD2(1, 1))
        #expect(result != nil)
        if let r = result {
            #expect(abs(abs(r.direction.x) - abs(r.direction.y)) < 1e-6)
        }
    }

    @Test("lines tangent to circle through point")
    func tangentCircle() {
        let results = linesTangentToCircleThroughPoint(
            circleCenter: SIMD2(0, 0), circleRadius: 1.0,
            point: SIMD2(3, 0))
        #expect(results.count >= 1)
    }
}
