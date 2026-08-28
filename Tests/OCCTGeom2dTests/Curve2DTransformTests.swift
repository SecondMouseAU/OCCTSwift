import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve2D Transform")
struct Curve2DTransformTests {

    @Test("Translate 2D curve")
    func translate2D() {
        let curve = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0))
        if let c = curve {
            let ok = c.translate(dx: 5, dy: 3)
            #expect(ok)
        }
    }

    @Test("Rotate 2D curve")
    func rotate2D() {
        let curve = Curve2D.line(through: SIMD2(1, 0), direction: SIMD2(1, 0))
        if let c = curve {
            let ok = c.rotate(center: SIMD2(0, 0), angle: .pi / 2)
            #expect(ok)
        }
    }

    @Test("Scale 2D curve")
    func scale2D() {
        let curve = Curve2D.line(through: SIMD2(1, 0), direction: SIMD2(1, 0))
        if let c = curve {
            let ok = c.scale(center: SIMD2(0, 0), factor: 2)
            #expect(ok)
        }
    }

    @Test("Mirror 2D curve through point")
    func mirrorPoint2D() {
        let curve = Curve2D.line(through: SIMD2(1, 0), direction: SIMD2(1, 0))
        if let c = curve {
            let ok = c.mirrorPoint(SIMD2(0, 0))
            #expect(ok)
        }
    }

    @Test("Mirror 2D curve through axis")
    func mirrorAxis2D() {
        let curve = Curve2D.line(through: SIMD2(1, 1), direction: SIMD2(1, 0))
        if let c = curve {
            let ok = c.mirrorAxis(origin: SIMD2(0, 0), direction: SIMD2(1, 0))
            #expect(ok)
        }
    }
}
