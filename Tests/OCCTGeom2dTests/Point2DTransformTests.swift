import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Point2D Transforms")
struct Point2DTransformTests {
    @Test func translate() {
        guard let p = Point2D(x: 1, y: 2) else { return }
        if let t = p.translated(dx: 3, dy: 4) {
            #expect(abs(t.x - 4.0) < 1e-10)
            #expect(abs(t.y - 6.0) < 1e-10)
        }
    }

    @Test func rotate() {
        guard let p = Point2D(x: 1, y: 0) else { return }
        if let r = p.rotated(center: SIMD2(0, 0), angle: .pi / 2) {
            #expect(abs(r.x) < 1e-10)
            #expect(abs(r.y - 1.0) < 1e-10)
        }
    }

    @Test func scale() {
        guard let p = Point2D(x: 2, y: 3) else { return }
        if let s = p.scaled(center: SIMD2(0, 0), factor: 2.0) {
            #expect(abs(s.x - 4.0) < 1e-10)
            #expect(abs(s.y - 6.0) < 1e-10)
        }
    }

    @Test func mirrorPoint() {
        guard let p = Point2D(x: 1, y: 0) else { return }
        if let m = p.mirrored(point: SIMD2(0, 0)) {
            #expect(abs(m.x + 1.0) < 1e-10)
            #expect(abs(m.y) < 1e-10)
        }
    }

    @Test func mirrorAxis() {
        guard let p = Point2D(x: 1, y: 1) else { return }
        // Mirror across X axis
        if let m = p.mirrored(axisOrigin: SIMD2(0, 0), axisDirection: SIMD2(1, 0)) {
            #expect(abs(m.x - 1.0) < 1e-10)
            #expect(abs(m.y + 1.0) < 1e-10)
        }
    }

    @Test func transformedByTransform2D() {
        guard let p = Point2D(x: 1, y: 0),
            let trsf = Transform2D.translation(dx: 5, dy: 3)
        else { return }
        if let result = p.transformed(by: trsf) {
            #expect(abs(result.x - 6.0) < 1e-10)
            #expect(abs(result.y - 3.0) < 1e-10)
        }
    }
}
