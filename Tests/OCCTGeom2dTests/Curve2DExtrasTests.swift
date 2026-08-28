import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve2D Extras v0.109")
struct Curve2DExtrasTests {
    @Test func reverseCurve2D() {
        if let c = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)) {
            #expect(c.reverse())
        }
    }

    @Test func copyCurve2D() {
        if let c = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)) {
            if let copy = c.copy() {
                let p1 = c.point(at: 0)
                let p2 = copy.point(at: 0)
                #expect(abs(p1.x - p2.x) < 1e-6)
                #expect(abs(p1.y - p2.y) < 1e-6)
            }
        }
    }

    @Test func copiedCurve2DIndependent() {
        if let c = Curve2D.circle(center: SIMD2(0, 0), radius: 5) {
            if let copy = c.copy() {
                #expect(copy.isClosed)
            }
        }
    }
}
