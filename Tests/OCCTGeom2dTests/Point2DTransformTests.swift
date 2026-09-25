import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Point2D Transforms")
struct Point2DTransformTests {
    @Test func translate() throws {
        let p = try #require(Point2D(x: 1, y: 2))  // #1979: was `guard ... else { return }`
        let t = try #require(p.translated(dx: 3, dy: 4))  // #1979: was `if let`
        #expect(abs(t.x - 4.0) < 1e-10)
        #expect(abs(t.y - 6.0) < 1e-10)
    }

    @Test func rotate() throws {
        let p = try #require(Point2D(x: 1, y: 0))  // #1979: was `guard ... else { return }`
        let r = try #require(p.rotated(center: SIMD2(0, 0), angle: .pi / 2))  // #1979: was `if let`
        #expect(abs(r.x) < 1e-10)
        #expect(abs(r.y - 1.0) < 1e-10)
    }

    @Test func scale() throws {
        let p = try #require(Point2D(x: 2, y: 3))  // #1979: was `guard ... else { return }`
        let s = try #require(p.scaled(center: SIMD2(0, 0), factor: 2.0))  // #1979: was `if let`
        #expect(abs(s.x - 4.0) < 1e-10)
        #expect(abs(s.y - 6.0) < 1e-10)
    }

    @Test func mirrorPoint() throws {
        let p = try #require(Point2D(x: 1, y: 0))  // #1979: was `guard ... else { return }`
        let m = try #require(p.mirrored(point: SIMD2(0, 0)))  // #1979: was `if let`
        #expect(abs(m.x + 1.0) < 1e-10)
        #expect(abs(m.y) < 1e-10)
    }

    @Test func mirrorAxis() throws {
        let p = try #require(Point2D(x: 1, y: 1))  // #1979: was `guard ... else { return }`
        // Mirror across X axis
        let m = try #require(p.mirrored(axisOrigin: SIMD2(0, 0), axisDirection: SIMD2(1, 0)))  // #1979: was `if let`
        #expect(abs(m.x - 1.0) < 1e-10)
        #expect(abs(m.y + 1.0) < 1e-10)
    }

    @Test func transformedByTransform2D() throws {
        let p = try #require(Point2D(x: 1, y: 0))  // #1979: was `guard ... else { return }`
        let trsf = try #require(Transform2D.translation(dx: 5, dy: 3))
        let result = try #require(p.transformed(by: trsf))  // #1979: was `if let`
        #expect(abs(result.x - 6.0) < 1e-10)
        #expect(abs(result.y - 3.0) < 1e-10)
    }
}
