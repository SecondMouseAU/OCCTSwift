import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.115.0 - Interpolation Expansion 2D")
struct InterpolationExpansion2DTests {

    @Test func interpolate2DWithTangents() {
        let points = [SIMD2(0.0, 0.0), SIMD2(5.0, 5.0), SIMD2(10.0, 0.0)]
        let curve = Curve2D.interpolate(
            points: points,
            startTangent: SIMD2(1, 1),
            endTangent: SIMD2(1, -1))
        #expect(curve != nil)
    }

    @Test func interpolate2DPeriodic() {
        let points = [
            SIMD2(0.0, 0.0), SIMD2(10.0, 0.0),
            SIMD2(10.0, 10.0), SIMD2(0.0, 10.0),
        ]
        let curve = Curve2D.interpolatePeriodic(points: points)
        #expect(curve != nil)
    }
}
