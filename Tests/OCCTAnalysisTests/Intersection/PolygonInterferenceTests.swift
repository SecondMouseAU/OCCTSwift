import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Polygon Interference Tests")
struct PolygonInterferenceTests {
    @Test func crossingPolylines() {
        let result = Shape.polygonInterference(
            poly1: [SIMD2(0, 0), SIMD2(10, 10)],
            poly2: [SIMD2(0, 10), SIMD2(10, 0)])
        #expect(result.points.count == 1)
        if let pt = result.points.first {
            #expect(abs(pt.x - 5.0) < 0.5)
            #expect(abs(pt.y - 5.0) < 0.5)
        }
    }

    @Test func nonIntersecting() {
        let result = Shape.polygonInterference(
            poly1: [SIMD2(0, 0), SIMD2(1, 0), SIMD2(1, 1)],
            poly2: [SIMD2(5, 5), SIMD2(6, 5), SIMD2(6, 6)])
        #expect(result.points.count == 0)
    }

    @Test func selfIntersection() {
        let result = Shape.polygonSelfInterference(
            polygon: [SIMD2(0, 0), SIMD2(10, 10), SIMD2(10, 0), SIMD2(0, 10)])
        #expect(result.points.count >= 1)
    }
}
