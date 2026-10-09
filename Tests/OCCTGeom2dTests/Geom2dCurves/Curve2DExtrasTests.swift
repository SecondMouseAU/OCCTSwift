import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: `reverseCurve2D` asserted only the Bool `reverse()` returns, and `copiedCurve2DIndependent`
// only that the copy is closed, so a reverse that did nothing and a "copy" sharing the original's
// geometry both passed. Values from Geom2d_Line::Reverse and Geom2d_Circle::Copy
// (Scripts/repro/766-geom2d-eval-extras/).
@Suite("Curve2D Extras v0.109")
struct Curve2DExtrasTests {
    @Test func reverseCurve2D() throws {
        let c = try #require(Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)))
        #expect(c.reverse())
        // The reversed line runs along -x: u = 1 is (-1, 0).
        #expect(simd_distance(c.point(at: 1), SIMD2(-1, 0)) < 1e-12)
    }

    @Test func copyCurve2D() throws {
        let c = try #require(Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)))
        let copy = try #require(c.copy())
        let p1 = c.point(at: 3)
        let p2 = copy.point(at: 3)
        #expect(abs(p1.x - p2.x) < 1e-6)
        #expect(abs(p1.y - p2.y) < 1e-6)
    }

    @Test func copiedCurve2DIndependent() throws {
        let c = try #require(Curve2D.circle(center: SIMD2(0, 0), radius: 5))
        let copy = try #require(c.copy())
        #expect(copy.isClosed)
        // Reversing the original must not reach the copy.
        #expect(c.reverse())
        #expect(simd_distance(c.point(at: .pi / 2), SIMD2(0, -5)) < 1e-9)
        #expect(simd_distance(copy.point(at: .pi / 2), SIMD2(0, 5)) < 1e-9)
    }
}
