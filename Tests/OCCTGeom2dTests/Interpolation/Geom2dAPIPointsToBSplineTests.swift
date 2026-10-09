import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom2dAPI PointsToBSpline Tests")
struct Geom2dAPIPointsToBSplineTests {

    @Test func basicApproximation() {
        let curve = Curve2D.approximate2D(points: [(0, 0), (1, 2), (2, 1), (3, 3), (4, 0)])
        #expect(curve != nil)
    }
}
