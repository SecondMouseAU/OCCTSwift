import Foundation
import Testing

@testable import OCCTSwift

// Every test requires its point and its result, and pins coordinates worked out by hand. Each
// transform is taken about the origin, where an ignored centre or axis origin changes nothing, and
// again about a centre or an axis that is not the origin, which is what tells the two apart. The
// origin cases are the ones `gp_Trsf2d` was measured on in
// `Scripts/repro/766-geom2d-point-matrix-polygon/transcript.txt`, and the rest are in
// `Scripts/repro/766-geom2d-curve2d-cluster/transcript.txt`.
@Suite("Point2D Transforms")
struct Point2DTransformTests {
    @Test func translate() throws {
        let p = try #require(Point2D(x: 1, y: 2))
        let t = try #require(p.translated(dx: 3, dy: 4))
        #expect(abs(t.x - 4.0) < 1e-10)
        #expect(abs(t.y - 6.0) < 1e-10)

        // dx and dy are not interchangeable, and a negative step goes the other way.
        let back = try #require(p.translated(dx: -1.5, dy: 0.5))
        #expect(abs(back.x + 0.5) < 1e-10)
        #expect(abs(back.y - 2.5) < 1e-10)
    }

    @Test func rotate() throws {
        let p = try #require(Point2D(x: 1, y: 0))
        let r = try #require(p.rotated(center: SIMD2(0, 0), angle: .pi / 2))
        #expect(abs(r.x) < 1e-10)
        #expect(abs(r.y - 1.0) < 1e-10)

        // About (1, 1) a quarter turn takes the offset (2, 0) to (0, 2), so (3, 1) goes to (1, 3).
        // Counter-clockwise for a positive angle, and about the centre given.
        let q = try #require(Point2D(x: 3, y: 1))
        let quarter = try #require(q.rotated(center: SIMD2(1, 1), angle: .pi / 2))
        #expect(abs(quarter.x - 1.0) < 1e-10)
        #expect(abs(quarter.y - 3.0) < 1e-10)

        // A half turn about the same centre mirrors the offset: (3, 1) goes to (-1, 1).
        let half = try #require(q.rotated(center: SIMD2(1, 1), angle: .pi))
        #expect(abs(half.x + 1.0) < 1e-10)
        #expect(abs(half.y - 1.0) < 1e-10)
    }

    @Test func scale() throws {
        let p = try #require(Point2D(x: 2, y: 3))
        let s = try #require(p.scaled(center: SIMD2(0, 0), factor: 2.0))
        #expect(abs(s.x - 4.0) < 1e-10)
        #expect(abs(s.y - 6.0) < 1e-10)

        // About (1, 1) the offset (2, 4) triples to (6, 12), so (3, 5) goes to (7, 13). Scaling the
        // coordinates instead would give (9, 15), which is what a bridge that ignored the centre
        // returns.
        let q = try #require(Point2D(x: 3, y: 5))
        let tripled = try #require(q.scaled(center: SIMD2(1, 1), factor: 3.0))
        #expect(abs(tripled.x - 7.0) < 1e-10)
        #expect(abs(tripled.y - 13.0) < 1e-10)

        // A factor of -1 about (1, 1) sends the offset (2, 4) to (-2, -4).
        let flipped = try #require(q.scaled(center: SIMD2(1, 1), factor: -1.0))
        #expect(abs(flipped.x + 1.0) < 1e-10)
        #expect(abs(flipped.y + 3.0) < 1e-10)
    }

    @Test func mirrorPoint() throws {
        let p = try #require(Point2D(x: 1, y: 0))
        let m = try #require(p.mirrored(point: SIMD2(0, 0)))
        #expect(abs(m.x + 1.0) < 1e-10)
        #expect(abs(m.y) < 1e-10)

        // Through (1, 1) the offset (2, 0) becomes (-2, 0), so (3, 1) goes to (-1, 1).
        let q = try #require(Point2D(x: 3, y: 1))
        let through = try #require(q.mirrored(point: SIMD2(1, 1)))
        #expect(abs(through.x + 1.0) < 1e-10)
        #expect(abs(through.y - 1.0) < 1e-10)
    }

    @Test func mirrorAxis() throws {
        let p = try #require(Point2D(x: 1, y: 1))
        // Mirror across X axis
        let m = try #require(p.mirrored(axisOrigin: SIMD2(0, 0), axisDirection: SIMD2(1, 0)))
        #expect(abs(m.x - 1.0) < 1e-10)
        #expect(abs(m.y + 1.0) < 1e-10)

        // The Y axis flips x instead, so the direction given is the one that is used.
        let acrossY = try #require(p.mirrored(axisOrigin: SIMD2(0, 0), axisDirection: SIMD2(0, 1)))
        #expect(abs(acrossY.x + 1.0) < 1e-10)
        #expect(abs(acrossY.y - 1.0) < 1e-10)

        // The diagonal y = x, given as the non-unit direction (1, 1), swaps the coordinates.
        let q = try #require(Point2D(x: 2, y: 0))
        let diagonal = try #require(q.mirrored(axisOrigin: SIMD2(0, 0), axisDirection: SIMD2(1, 1)))
        #expect(abs(diagonal.x) < 1e-10)
        #expect(abs(diagonal.y - 2.0) < 1e-10)

        // An axis that does not pass through the origin: across y = 2, y goes to 4 - y.
        let r = try #require(Point2D(x: 1, y: 5))
        let offset = try #require(r.mirrored(axisOrigin: SIMD2(0, 2), axisDirection: SIMD2(1, 0)))
        #expect(abs(offset.x - 1.0) < 1e-10)
        #expect(abs(offset.y + 1.0) < 1e-10)

        // Both at once: across y = x - 1, (x, y) goes to (y + 1, x - 1), so (3, 0) goes to (1, 2).
        let s = try #require(Point2D(x: 3, y: 0))
        let both = try #require(s.mirrored(axisOrigin: SIMD2(1, 0), axisDirection: SIMD2(1, 1)))
        #expect(abs(both.x - 1.0) < 1e-10)
        #expect(abs(both.y - 2.0) < 1e-10)
    }

    @Test func transformedByTransform2D() throws {
        let p = try #require(Point2D(x: 1, y: 0))
        let trsf = try #require(Transform2D.translation(dx: 5, dy: 3))
        let result = try #require(p.transformed(by: trsf))
        #expect(abs(result.x - 6.0) < 1e-10)
        #expect(abs(result.y - 3.0) < 1e-10)

        // A transform that is not a translation, about a centre that is not the origin: the
        // quarter turn about (1, 1) that sent (3, 1) to (1, 3) above.
        let q = try #require(Point2D(x: 3, y: 1))
        let turn = try #require(Transform2D.rotation(center: SIMD2(1, 1), angle: .pi / 2))
        let turned = try #require(q.transformed(by: turn))
        #expect(abs(turned.x - 1.0) < 1e-10)
        #expect(abs(turned.y - 3.0) < 1e-10)
    }

    @Test func transformsReturnNewPointsAndLeaveTheReceiverAlone() throws {
        let p = try #require(Point2D(x: 1, y: 2))
        _ = try #require(p.translated(dx: 3, dy: 4))
        _ = try #require(p.rotated(center: SIMD2(0, 0), angle: .pi / 2))
        _ = try #require(p.scaled(center: SIMD2(0, 0), factor: 2.0))
        _ = try #require(p.mirrored(point: SIMD2(0, 0)))
        _ = try #require(p.mirrored(axisOrigin: SIMD2(0, 0), axisDirection: SIMD2(1, 0)))
        let trsf = try #require(Transform2D.translation(dx: 5, dy: 3))
        _ = try #require(p.transformed(by: trsf))
        #expect(p.x == 1)
        #expect(p.y == 2)
    }
}
