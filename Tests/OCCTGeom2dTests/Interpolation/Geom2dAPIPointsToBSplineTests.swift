import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: `curve != nil` only. Geom2dAPI_PointsToBSpline with its defaults gives a quartic with 5
// poles through both end points (Scripts/repro/766-geom2d-gce-geom2dapi/).
@Suite("Geom2dAPI PointsToBSpline Tests")
struct Geom2dAPIPointsToBSplineTests {
    @Test func basicApproximation() throws {
        let curve = try #require(
            Curve2D.approximate2D(points: [(0, 0), (1, 2), (2, 1), (3, 3), (4, 0)]))
        #expect(curve.degree == 4)
        #expect(curve.poleCount == 5)
        #expect(simd_distance(curve.startPoint, SIMD2(0, 0)) < 1e-9)
        #expect(simd_distance(curve.endPoint, SIMD2(4, 0)) < 1e-9)
    }
}
