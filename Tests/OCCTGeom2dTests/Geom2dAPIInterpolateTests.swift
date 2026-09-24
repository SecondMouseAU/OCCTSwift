import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: both asserted only `curve != nil`. Pinned to Geom2dAPI_Interpolate
// (Scripts/repro/766-geom2d-gce-geom2dapi/).
@Suite("Geom2dAPI Interpolate Tests")
struct Geom2dAPIInterpolateTests {
    @Test func basicInterpolation() throws {
        let curve = try #require(Curve2D.interpolate2D(points: [(0, 0), (1, 1), (2, 0), (3, 1)]))
        // Chord-length parametrised: (1, 1) at u = sqrt 2, 6 poles, domain [0, 3 sqrt 2].
        #expect(curve.poleCount == 6)
        #expect(abs(curve.domain.upperBound - 3 * 2.0.squareRoot()) < 1e-9)
        #expect(simd_distance(curve.point(at: 2.0.squareRoot()), SIMD2(1, 1)) < 1e-9)
    }

    @Test func periodicInterpolation() throws {
        let curve = try #require(
            Curve2D.interpolate2D(
                points: [(0, 0), (1, 1), (2, 0), (1, -1)], periodic: true))
        #expect(curve.isPeriodic)
        #expect(curve.poleCount == 5)
        #expect(abs(curve.domain.upperBound - 4 * 2.0.squareRoot()) < 1e-9)
    }
}
