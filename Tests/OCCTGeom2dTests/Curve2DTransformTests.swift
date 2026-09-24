import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: every test asserted only the Bool the in-place transform returned, inside `if let`, so a
// transform that reported success and moved nothing passed. Each now pins where the line's u = 0
// point lands, from gp_Trsf2d on the same line (Scripts/repro/766-geom2d-projection-simplify-transform/).
@Suite("Curve2D Transform")
struct Curve2DTransformTests {
    @Test("Translate 2D curve")
    func translate2D() throws {
        let c = try #require(Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)))
        #expect(c.translate(dx: 5, dy: 3))
        #expect(simd_distance(c.point(at: 0), SIMD2(5, 3)) < 1e-12)
    }

    @Test("Rotate 2D curve")
    func rotate2D() throws {
        let c = try #require(Curve2D.line(through: SIMD2(1, 0), direction: SIMD2(1, 0)))
        #expect(c.rotate(center: SIMD2(0, 0), angle: .pi / 2))
        #expect(simd_distance(c.point(at: 0), SIMD2(0, 1)) < 1e-12)
        #expect(simd_distance(c.point(at: 1), SIMD2(0, 2)) < 1e-12)
    }

    @Test("Scale 2D curve")
    func scale2D() throws {
        let c = try #require(Curve2D.line(through: SIMD2(1, 0), direction: SIMD2(1, 0)))
        #expect(c.scale(center: SIMD2(0, 0), factor: 2))
        #expect(simd_distance(c.point(at: 0), SIMD2(2, 0)) < 1e-12)
    }

    @Test("Mirror 2D curve through point")
    func mirrorPoint2D() throws {
        let c = try #require(Curve2D.line(through: SIMD2(1, 0), direction: SIMD2(1, 0)))
        #expect(c.mirrorPoint(SIMD2(0, 0)))
        #expect(simd_distance(c.point(at: 0), SIMD2(-1, 0)) < 1e-12)
        #expect(simd_distance(c.point(at: 1), SIMD2(-2, 0)) < 1e-12)
    }

    @Test("Mirror 2D curve through axis")
    func mirrorAxis2D() throws {
        let c = try #require(Curve2D.line(through: SIMD2(1, 1), direction: SIMD2(1, 0)))
        #expect(c.mirrorAxis(origin: SIMD2(0, 0), direction: SIMD2(1, 0)))
        #expect(simd_distance(c.point(at: 0), SIMD2(1, -1)) < 1e-12)
    }
}
