import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: both asserted only `upperBound > lowerBound` inside `if let`, which any circle, and a nil
// result, satisfies. Pinned to gce_MakeCirc2d (Scripts/repro/766-geom2d-gce-geom2dapi/).
@Suite("gce_MakeCirc2d Tests")
struct GceMakeCirc2dTests {
    @Test func circleFromCenterRadius() throws {
        let circ = try #require(Curve2D.circleFromCenterRadius(center: SIMD2(0, 0), radius: 5.0))
        #expect(abs(circ.domain.upperBound - 2 * .pi) < 1e-12)
        #expect(simd_distance(circ.point(at: 0), SIMD2(5, 0)) < 1e-12)
        #expect(simd_distance(circ.point(at: .pi / 2), SIMD2(0, 5)) < 1e-12)
    }

    @Test func circleThrough3Points() throws {
        let circ = try #require(Curve2D.circleThrough3Points(SIMD2(5, 0), SIMD2(0, 5), SIMD2(-5, 0)))
        // The circumcircle is centred on the origin with radius 5, starting at (5, 0).
        #expect(simd_distance(circ.point(at: 0), SIMD2(5, 0)) < 1e-9)
        #expect(simd_distance(circ.point(at: 1), SIMD2(2.70151152934, 4.20735492404)) < 1e-9)
    }
}
