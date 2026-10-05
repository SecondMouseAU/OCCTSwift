import Foundation
import Testing
import simd

@testable import OCCTSwift

// Every test requires its curve and pins where the transformed line starts (u = 0) and which way
// it runs (u = 1), from coordinates worked out by hand, so a transform that reports success and
// moves nothing fails. Each transform is taken about the origin, where an ignored centre or axis
// origin changes nothing, and again about a centre or an axis that is not the origin, which is what
// tells the two apart. `Geom2d_Line` is unit speed, so the point at u = 1 is one unit along its
// direction; `Issue478Curve2DTransformGeometryTests` covers the same five transforms on a segment.
// The kernel's `gp_Trsf2d` answers for the origin cases are in
// `Scripts/repro/766-geom2d-projection-simplify-transform/transcript.txt` and for the rest in
// `Scripts/repro/766-geom2d-curve2d-cluster/transcript.txt`.
@Suite("Curve2D Transform")
struct Curve2DTransformTests {
    // The point at u = 0 and the point at u = 1 together say where the line starts and which way
    // it runs.
    private func expectLine(
        _ c: Curve2D, from start: SIMD2<Double>, toward next: SIMD2<Double>, _ label: String
    ) {
        let at0 = c.point(at: 0)
        let at1 = c.point(at: 1)
        #expect(simd_distance(at0, start) < 1e-12, "\(label): u = 0 is \(at0), expected \(start)")
        #expect(simd_distance(at1, next) < 1e-12, "\(label): u = 1 is \(at1), expected \(next)")
    }

    @Test("Translate 2D curve")
    func translate2D() throws {
        let c = try #require(Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)))
        #expect(c.translate(dx: 5, dy: 3))
        expectLine(c, from: SIMD2(5, 3), toward: SIMD2(6, 3), "x axis")

        // A line along (1, 1): the origin moves and the direction does not.
        let r = Double(0.5).squareRoot()
        let d = try #require(Curve2D.line(through: SIMD2(1, 2), direction: SIMD2(1, 1)))
        #expect(d.translate(dx: 5, dy: 3))
        expectLine(d, from: SIMD2(6, 5), toward: SIMD2(6 + r, 5 + r), "diagonal")
    }

    @Test("Rotate 2D curve")
    func rotate2D() throws {
        let c = try #require(Curve2D.line(through: SIMD2(1, 0), direction: SIMD2(1, 0)))
        #expect(c.rotate(center: SIMD2(0, 0), angle: .pi / 2))
        expectLine(c, from: SIMD2(0, 1), toward: SIMD2(0, 2), "about the origin")

        // About (1, 1): the offset (2, 0) of the start becomes (0, 2), and +x turns into +y.
        let about = try #require(Curve2D.line(through: SIMD2(3, 1), direction: SIMD2(1, 0)))
        #expect(about.rotate(center: SIMD2(1, 1), angle: .pi / 2))
        expectLine(about, from: SIMD2(1, 3), toward: SIMD2(1, 4), "about (1, 1)")

        // A diagonal direction turns with it: (1, 1) / sqrt(2) becomes (-1, 1) / sqrt(2), and the
        // start (1, 2), offset (0, 1) from the centre, becomes offset (-1, 0).
        let r = Double(0.5).squareRoot()
        let d = try #require(Curve2D.line(through: SIMD2(1, 2), direction: SIMD2(1, 1)))
        #expect(d.rotate(center: SIMD2(1, 1), angle: .pi / 2))
        expectLine(d, from: SIMD2(0, 1), toward: SIMD2(-r, 1 + r), "diagonal about (1, 1)")
    }

    @Test("Scale 2D curve")
    func scale2D() throws {
        // Scaling moves the line's origin and not its speed: the image of the point at u is the
        // point at 2u, so the point at u = 1 is one unit along from the new origin, (3, 0), and
        // not (4, 0).
        let c = try #require(Curve2D.line(through: SIMD2(1, 0), direction: SIMD2(1, 0)))
        #expect(c.scale(center: SIMD2(0, 0), factor: 2))
        expectLine(c, from: SIMD2(2, 0), toward: SIMD2(3, 0), "about the origin")

        // About (1, 1) by 3 the offset (2, 0) of the start becomes (6, 0), so the origin lands at
        // (7, 1). Scaling the coordinates instead would put it at (9, 3).
        let about = try #require(Curve2D.line(through: SIMD2(3, 1), direction: SIMD2(1, 0)))
        #expect(about.scale(center: SIMD2(1, 1), factor: 3))
        expectLine(about, from: SIMD2(7, 1), toward: SIMD2(8, 1), "about (1, 1)")
    }

    @Test("Mirror 2D curve through point")
    func mirrorPoint2D() throws {
        let c = try #require(Curve2D.line(through: SIMD2(1, 0), direction: SIMD2(1, 0)))
        #expect(c.mirrorPoint(SIMD2(0, 0)))
        expectLine(c, from: SIMD2(-1, 0), toward: SIMD2(-2, 0), "through the origin")

        // Through (1, 1) the start (3, 1) goes to (-1, 1) and the direction reverses.
        let through = try #require(Curve2D.line(through: SIMD2(3, 1), direction: SIMD2(1, 0)))
        #expect(through.mirrorPoint(SIMD2(1, 1)))
        expectLine(through, from: SIMD2(-1, 1), toward: SIMD2(-2, 1), "through (1, 1)")
    }

    @Test("Mirror 2D curve through axis")
    func mirrorAxis2D() throws {
        let c = try #require(Curve2D.line(through: SIMD2(1, 1), direction: SIMD2(1, 0)))
        #expect(c.mirrorAxis(origin: SIMD2(0, 0), direction: SIMD2(1, 0)))
        expectLine(c, from: SIMD2(1, -1), toward: SIMD2(2, -1), "across the x axis")

        // The Y axis flips x, and turns +x into -x.
        let acrossY = try #require(Curve2D.line(through: SIMD2(1, 1), direction: SIMD2(1, 0)))
        #expect(acrossY.mirrorAxis(origin: SIMD2(0, 0), direction: SIMD2(0, 1)))
        expectLine(acrossY, from: SIMD2(-1, 1), toward: SIMD2(-2, 1), "across the y axis")

        // The diagonal y = x swaps the coordinates, and turns +x into +y.
        let diagonal = try #require(Curve2D.line(through: SIMD2(3, 0), direction: SIMD2(1, 0)))
        #expect(diagonal.mirrorAxis(origin: SIMD2(0, 0), direction: SIMD2(1, 1)))
        expectLine(diagonal, from: SIMD2(0, 3), toward: SIMD2(0, 4), "across y = x")

        // An axis that does not pass through the origin: across y = 2, y goes to 4 - y.
        let offset = try #require(Curve2D.line(through: SIMD2(1, 5), direction: SIMD2(1, 0)))
        #expect(offset.mirrorAxis(origin: SIMD2(0, 2), direction: SIMD2(1, 0)))
        expectLine(offset, from: SIMD2(1, -1), toward: SIMD2(2, -1), "across y = 2")
    }
}
