import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Transform2D Composition")
struct Transform2DCompositionTests {
    @Test func inverted() {
        guard let t = Transform2D.translation(dx: 3, dy: 4),
            let inv = t.inverted()
        else { return }
        let result = inv.apply(to: SIMD2(3, 4))
        #expect(abs(result.x) < 1e-10)
        #expect(abs(result.y) < 1e-10)
    }

    @Test func composed() {
        guard let t1 = Transform2D.translation(dx: 1, dy: 0),
            let t2 = Transform2D.translation(dx: 0, dy: 2),
            let composed = t1.composed(with: t2)
        else { return }
        let result = composed.apply(to: SIMD2(0, 0))
        #expect(abs(result.x - 1.0) < 1e-10)
        #expect(abs(result.y - 2.0) < 1e-10)
    }

    @Test func powered() {
        guard let t = Transform2D.translation(dx: 1, dy: 0),
            let p3 = t.powered(3)
        else { return }
        let result = p3.apply(to: SIMD2(0, 0))
        #expect(abs(result.x - 3.0) < 1e-10)
    }

    @Test func matrixValues() {
        guard let t = Transform2D.identity() else { return }
        let m = t.matrixValues
        #expect(abs(m.a11 - 1.0) < 1e-10)
        #expect(abs(m.a22 - 1.0) < 1e-10)
        #expect(abs(m.a12) < 1e-10)
        #expect(abs(m.a21) < 1e-10)
    }

    @Test func applyToCurve() {
        guard let t = Transform2D.translation(dx: 5, dy: 0),
            let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(1, 0)),
            let transformed = t.apply(to: seg)
        else { return }
        let pts = transformed.drawUniform(pointCount: 2)
        #expect(pts.count == 2)
        if pts.count == 2 {
            #expect(abs(pts[0].x - 5.0) < 1e-6)
        }
    }
}
