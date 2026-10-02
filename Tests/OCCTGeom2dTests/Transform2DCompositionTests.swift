import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Transform2D Composition")
struct Transform2DCompositionTests {
    @Test func inverted() throws {
        let t = try #require(Transform2D.translation(dx: 3, dy: 4))  // #1979: was `guard ... else { return }`
        let inv = try #require(t.inverted())
        let result = inv.apply(to: SIMD2(3, 4))
        #expect(abs(result.x) < 1e-10)
        #expect(abs(result.y) < 1e-10)
    }

    @Test func composed() throws {
        let t1 = try #require(Transform2D.translation(dx: 1, dy: 0))  // #1979: was `guard ... else { return }`
        let t2 = try #require(Transform2D.translation(dx: 0, dy: 2))
        let composed = try #require(t1.composed(with: t2))
        let result = composed.apply(to: SIMD2(0, 0))
        #expect(abs(result.x - 1.0) < 1e-10)
        #expect(abs(result.y - 2.0) < 1e-10)
    }

    @Test func powered() throws {
        let t = try #require(Transform2D.translation(dx: 1, dy: 0))  // #1979: was `guard ... else { return }`
        let p3 = try #require(t.powered(3))
        let result = p3.apply(to: SIMD2(0, 0))
        #expect(abs(result.x - 3.0) < 1e-10)
    }

    @Test func matrixValues() throws {
        let t = try #require(Transform2D.identity())  // #1979: was `guard ... else { return }`
        let m = t.matrixValues
        #expect(abs(m.a11 - 1.0) < 1e-10)
        #expect(abs(m.a22 - 1.0) < 1e-10)
        #expect(abs(m.a12) < 1e-10)
        #expect(abs(m.a21) < 1e-10)
    }

    @Test func applyToCurve() throws {
        let t = try #require(Transform2D.translation(dx: 5, dy: 0))  // #1979: was `guard ... else { return }`
        let seg = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(1, 0)))
        let transformed = try #require(t.apply(to: seg))
        let pts = transformed.drawUniform(pointCount: 2)
        #expect(pts.count == 2)
        if pts.count == 2 {
            #expect(abs(pts[0].x - 5.0) < 1e-6)
            #expect(abs(pts[1].x - 6.0) < 1e-6)  // #1979: the far end was never checked
        }
    }
}
