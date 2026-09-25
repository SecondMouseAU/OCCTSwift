import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("gce Transform Factory 2D Tests")
struct TransformFactory2DTests {

    @Test func pointMirror2d() {
        let t = TransformFactory2D.mirrorPoint(SIMD2(0, 0))
        let p = t.apply(to: SIMD2(3, 4))
        #expect(abs(p.x + 3) < 1e-6)
        #expect(abs(p.y + 4) < 1e-6)
    }

    @Test func rotation2d() {
        let t = TransformFactory2D.rotation(center: .zero, angle: .pi / 2)
        let p = t.apply(to: SIMD2(1, 0))
        #expect(abs(p.x) < 1e-6)
        #expect(abs(p.y - 1) < 1e-6)
    }

    @Test func scale2d() {
        let t = TransformFactory2D.scale(center: .zero, factor: 3)
        let p = t.apply(to: SIMD2(1, 2))
        #expect(abs(p.x - 3) < 1e-6)
        #expect(abs(p.y - 6) < 1e-6)
    }

    @Test func translation2d() {
        let t = TransformFactory2D.translation(SIMD2(10, 20))
        let p = t.apply(to: SIMD2(1, 2))
        #expect(abs(p.x - 11) < 1e-6)
        #expect(abs(p.y - 22) < 1e-6)  // #1979: y was never checked
    }

    @Test func direction2d() throws {
        // #1979: only the length was checked, inside `if let`; any unit vector passed. gce_MakeDir2d
        // of (3, 4) is (0.6, 0.8).
        let d = try #require(TransformFactory2D.direction(x: 3, y: 4))
        let len = sqrt(d.x * d.x + d.y * d.y)
        #expect(abs(len - 1.0) < 1e-6)
        #expect(abs(d.x - 0.6) < 1e-12)
        #expect(abs(d.y - 0.8) < 1e-12)
    }

    @Test func direction2dFromPoints() throws {
        // #1979: `!= nil` only. (0, 0) to (1, 1) is the unit diagonal.
        let d = try #require(TransformFactory2D.direction(from: SIMD2(0, 0), to: SIMD2(1, 1)))
        #expect(abs(d.x - 0.5.squareRoot()) < 1e-12)
        #expect(abs(d.y - 0.5.squareRoot()) < 1e-12)
    }
}
