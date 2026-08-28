import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Geom2dAPI Interpolate Tests")
struct Geom2dAPIInterpolateTests {

    @Test func basicInterpolation() {
        let curve = Curve2D.interpolate2D(points: [(0, 0), (1, 1), (2, 0), (3, 1)])
        #expect(curve != nil)
    }

    @Test func periodicInterpolation() {
        let curve = Curve2D.interpolate2D(
            points: [(0, 0), (1, 1), (2, 0), (1, -1)], periodic: true)
        #expect(curve != nil)
    }
}
