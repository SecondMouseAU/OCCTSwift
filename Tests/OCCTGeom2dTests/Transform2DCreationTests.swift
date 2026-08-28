import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Transform2D Creation")
struct Transform2DCreationTests {
    @Test func identity() {
        guard let t = Transform2D.identity() else { return }
        #expect(abs(t.scaleFactor - 1.0) < 1e-10)
        #expect(t.isNegative == false)
    }

    @Test func translation() {
        guard let t = Transform2D.translation(dx: 3, dy: 4) else { return }
        let result = t.apply(to: SIMD2(0, 0))
        #expect(abs(result.x - 3.0) < 1e-10)
        #expect(abs(result.y - 4.0) < 1e-10)
    }

    @Test func rotation() {
        guard let t = Transform2D.rotation(center: SIMD2(0, 0), angle: .pi / 2) else { return }
        let result = t.apply(to: SIMD2(1, 0))
        #expect(abs(result.x) < 1e-10)
        #expect(abs(result.y - 1.0) < 1e-10)
    }

    @Test func scale() {
        guard let t = Transform2D.scale(center: SIMD2(0, 0), factor: 3.0) else { return }
        #expect(abs(t.scaleFactor - 3.0) < 1e-10)
        let result = t.apply(to: SIMD2(1, 2))
        #expect(abs(result.x - 3.0) < 1e-10)
        #expect(abs(result.y - 6.0) < 1e-10)
    }

    @Test func mirrorPoint() {
        guard let t = Transform2D.mirrorPoint(SIMD2(0, 0)) else { return }
        let result = t.apply(to: SIMD2(1, 2))
        #expect(abs(result.x + 1.0) < 1e-10)
        #expect(abs(result.y + 2.0) < 1e-10)
    }

    @Test func mirrorAxis() {
        guard
            let t = Transform2D.mirrorAxis(
                origin: SIMD2(0, 0),
                direction: SIMD2(1, 0))
        else { return }
        #expect(t.isNegative == true)
        let result = t.apply(to: SIMD2(1, 2))
        #expect(abs(result.x - 1.0) < 1e-10)
        #expect(abs(result.y + 2.0) < 1e-10)
    }
}
