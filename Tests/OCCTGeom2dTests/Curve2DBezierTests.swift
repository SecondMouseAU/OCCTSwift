import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: every test here nested its assertions in `if let c`, so a nil curve passed, and
// `resolution` asserted only `r > 0`. Values from Geom2d_BezierCurve for the same curve
// (Scripts/repro/766-geom2d-bezier/).
@Suite("Curve2D_Bezier_Properties")
struct Curve2DBezierTests {
    func makeBezier2D() throws -> Curve2D {
        try #require(Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(5, 10), SIMD2(10, 0)]))
    }

    @Test func degreeAndPoleCount() throws {
        let bp = try makeBezier2D().bezierProperties
        #expect(bp.degree == 2)
        #expect(bp.poleCount == 3)
    }

    @Test func getPole() throws {
        let bp = try makeBezier2D().bezierProperties
        let p = bp.pole(at: 1)
        #expect(abs(p.x) < 1e-10)
        #expect(abs(p.y) < 1e-10)
        let q = bp.pole(at: 2)
        #expect(abs(q.x - 5) < 1e-10)
        #expect(abs(q.y - 10) < 1e-10)
    }

    @Test func setPole() throws {
        let bp = try makeBezier2D().bezierProperties
        let ok = bp.setPole(at: 2, point: SIMD2(3, 7))
        #expect(ok)
        let p = bp.pole(at: 2)
        #expect(abs(p.x - 3.0) < 1e-10)
        #expect(abs(p.y - 7.0) < 1e-10)
    }

    @Test func isRational() throws {
        let bp = try makeBezier2D().bezierProperties
        #expect(!bp.isRational)
    }

    @Test func resolution() throws {
        // Geom2d_BezierCurve::Resolution(0.1) is 0.1 / 30 for these poles.
        let bp = try makeBezier2D().bezierProperties
        let r = bp.resolution(tolerance: 0.1)
        #expect(abs(r - 0.00333333333333) < 1e-12)
    }
}
