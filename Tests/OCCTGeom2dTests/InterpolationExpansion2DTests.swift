import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.115.0 - Interpolation Expansion 2D")
struct InterpolationExpansion2DTests {

    @Test func interpolate2DWithTangents() throws {
        let points = [SIMD2(0.0, 0.0), SIMD2(5.0, 5.0), SIMD2(10.0, 0.0)]
        let curve = Curve2D.interpolate(
            points: points,
            startTangent: SIMD2(1, 1),
            endTangent: SIMD2(1, -1))
        // #1979: `!= nil` only. Pinned to Geom2dAPI_Interpolate with the tangents loaded
        // (Scripts/repro/766-geom2d-curveset-intana-misc/).
        let c = try #require(curve)
        #expect(c.poleCount == 5)
        #expect(simd_distance(c.point(at: 2), SIMD2(1.84960461481, 2.06475180106)) < 1e-9)
    }

    @Test func interpolate2DPeriodic() throws {
        let points = [
            SIMD2(0.0, 0.0), SIMD2(10.0, 0.0),
            SIMD2(10.0, 10.0), SIMD2(0.0, 10.0),
        ]
        let curve = Curve2D.interpolatePeriodic(points: points)
        // #1979: `!= nil` only. Periodic on [0, 40], through (10, 10) at u = 20.
        let c = try #require(curve)
        #expect(c.isPeriodic)
        #expect(abs(c.domain.upperBound - 40) < 1e-12)
        #expect(simd_distance(c.point(at: 20), SIMD2(10, 10)) < 1e-9)
    }
}
