import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: `throughPoints` checked `|dx| == |dy|` inside `if let`, and `tangentCircle` `count >= 1`.
@Suite("GccAna Lin2d2Tan Tests")
struct GccAnaLin2d2TanTests {
    @Test("line through two points")
    func throughPoints() throws {
        let r = try #require(lineThroughPoints(SIMD2(0, 0), SIMD2(1, 1)))
        // Direction (1, 1)/sqrt 2, sign included, through the origin.
        let s = 0.5.squareRoot()
        #expect(simd_distance(r.direction, SIMD2(s, s)) < 1e-9)
        #expect(abs(r.origin.x - r.origin.y) < 1e-9)
    }

    @Test("lines tangent to circle through point")
    func tangentCircle() throws {
        let results = linesTangentToCircleThroughPoint(
            circleCenter: SIMD2(0, 0), circleRadius: 1.0,
            point: SIMD2(3, 0))
        // Two tangents from (3, 0) to the unit circle, touching at (1/3, -+sqrt(8)/3)
        // (GccAna_Lin2d2Tan; Scripts/repro/766-geom2d-gccana-circ3tan-lines/).
        try #require(results.count == 2)
        let ys = results.map(\.origin.y).sorted()
        #expect(results.allSatisfy { abs($0.origin.x - 1.0 / 3.0) < 1e-9 })
        #expect(abs(ys[0] + 0.942809041582) < 1e-9)
        #expect(abs(ys[1] - 0.942809041582) < 1e-9)
    }
}
