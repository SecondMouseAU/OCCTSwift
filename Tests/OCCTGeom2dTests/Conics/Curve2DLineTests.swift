import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GC_MakeLine2d")
struct Curve2DLineTests {
    @Test("Create 2D line through two points")
    func lineThroughPoints() {
        let line = Curve2D.lineThroughPoints(SIMD2(0, 0), SIMD2(10, 10))
        #expect(line != nil)
    }

    @Test("Create 2D line parallel to direction at distance")
    func lineParallel() {
        let line = Curve2D.lineParallel(point: SIMD2(0, 0), direction: SIMD2(1, 0), distance: 5.0)
        #expect(line != nil)
    }
}
