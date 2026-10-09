import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: every test here opened with `guard let t = ... else { return }`, so a nil factory result
// skipped every assertion and the test passed. Each factory is now `try #require`d, and
// `mirrorAxis`'s multi-line guard was missed by the first pass over this file.
@Suite("Transform2D Creation")
struct Transform2DCreationTests {
    @Test func identity() throws {
        let t = try #require(Transform2D.identity())
        #expect(abs(t.scaleFactor - 1.0) < 1e-10)
        #expect(t.isNegative == false)
    }

    @Test func translation() throws {
        let t = try #require(Transform2D.translation(dx: 3, dy: 4))
        let result = t.apply(to: SIMD2(0, 0))
        #expect(abs(result.x - 3.0) < 1e-10)
        #expect(abs(result.y - 4.0) < 1e-10)
    }

    @Test func rotation() throws {
        let t = try #require(Transform2D.rotation(center: SIMD2(0, 0), angle: .pi / 2))
        let result = t.apply(to: SIMD2(1, 0))
        #expect(abs(result.x) < 1e-10)
        #expect(abs(result.y - 1.0) < 1e-10)
    }

    @Test func scale() throws {
        let t = try #require(Transform2D.scale(center: SIMD2(0, 0), factor: 3.0))
        #expect(abs(t.scaleFactor - 3.0) < 1e-10)
        let result = t.apply(to: SIMD2(1, 2))
        #expect(abs(result.x - 3.0) < 1e-10)
        #expect(abs(result.y - 6.0) < 1e-10)
    }

    @Test func mirrorPoint() throws {
        let t = try #require(Transform2D.mirrorPoint(SIMD2(0, 0)))
        let result = t.apply(to: SIMD2(1, 2))
        #expect(abs(result.x + 1.0) < 1e-10)
        #expect(abs(result.y + 2.0) < 1e-10)
    }

    @Test func mirrorAxis() throws {
        // The multi-line guard here was missed by #1979's first pass over this file, so a nil
        // factory result passed silently.
        let t = try #require(
            Transform2D.mirrorAxis(
                origin: SIMD2(0, 0),
                direction: SIMD2(1, 0)))
        #expect(t.isNegative == true)
        let result = t.apply(to: SIMD2(1, 2))
        #expect(abs(result.x - 1.0) < 1e-10)
        #expect(abs(result.y + 2.0) < 1e-10)
    }
}
