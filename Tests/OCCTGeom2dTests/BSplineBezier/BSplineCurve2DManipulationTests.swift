import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: these tests used to nest every assertion in `if let bsp = ...` and assert bounds like
// `knotCount > 0`, `degree >= 1` or nothing at all (`let _ = ...`), so a wrong count, a no-op edit
// or a nil curve all passed. Each now pins what Geom2d_BSplineCurve reports for the same
// Geom2dAPI_Interpolate curve (Scripts/repro/766-geom2d-bspline-manipulation/): a cubic with
// knots [0, 5, 9.472135955, 13.0776872305], multiplicities [4, 1, 1, 4] and six poles.
@Suite("BSpline Curve 2D Manipulation Tests")
struct BSplineCurve2DManipulationTests {

    private func makeCurve() throws -> Curve2D {
        try #require(
            Curve2D.interpolate(through: [
                SIMD2(0, 0), SIMD2(3, 4), SIMD2(7, 2), SIMD2(10, 0),
            ]))
    }

    @Test func knotCount() throws {
        let bsp = try makeCurve()
        #expect(bsp.bspline.knotCount == 4)
    }

    @Test func poleCount() throws {
        let bsp = try makeCurve()
        #expect(bsp.bspline.poleCount == 6)
    }

    @Test func degree() throws {
        let bsp = try makeCurve()
        #expect(bsp.bspline.degree == 3)
    }

    @Test func isRational() throws {
        let bsp = try makeCurve()
        #expect(!bsp.bspline.isRational)
    }

    @Test func setPole() throws {
        let bsp = try makeCurve()
        let ok = bsp.bspline.setPole(at: 2, to: SIMD2(3, 6))
        #expect(ok)
        let p = bsp.bspline.pole(at: 2)
        #expect(abs(p.x - 3.0) < 1e-12)
        #expect(abs(p.y - 6.0) < 1e-12)
        // Moving pole 2 moves the curve's midpoint from (4.3237, 3.6390) to here.
        let mid = bsp.point(at: 6.53884361523)
        #expect(simd_distance(mid, SIMD2(4.48048559535, 3.8185952988)) < 1e-9)
    }

    @Test func resolution() throws {
        let bsp = try makeCurve()
        let res = bsp.bspline.resolution(tolerance: 0.001)
        #expect(abs(res - 0.000456398889492) < 1e-12)
    }

    @Test func insertKnot() throws {
        let bsp = try makeCurve()
        let d = bsp.domain
        let mid = (d.lowerBound + d.upperBound) / 2.0
        let ok = bsp.bspline.insertKnot(u: mid)
        #expect(ok)
        #expect(bsp.bspline.knotCount == 5)
        #expect(abs(bsp.bsplineKnot(index: 3) - mid) < 1e-12)
        #expect(bsp.bspline.poleCount == 7)
        // Knot insertion does not change the shape.
        #expect(simd_distance(bsp.point(at: mid), SIMD2(4.32365835512, 3.63901574245)) < 1e-9)
    }

    @Test func segment() throws {
        let bsp = try makeCurve()
        let d = bsp.domain
        let u1 = d.lowerBound + (d.upperBound - d.lowerBound) * 0.25
        let u2 = d.lowerBound + (d.upperBound - d.lowerBound) * 0.75
        let ok = bsp.bspline.segment(u1: u1, u2: u2)
        #expect(ok)
        #expect(abs(bsp.domain.lowerBound - u1) < 1e-12)
        #expect(abs(bsp.domain.upperBound - u2) < 1e-12)
        #expect(simd_distance(bsp.point(at: u1), SIMD2(1.68164527884, 3.67817687899)) < 1e-9)
        #expect(simd_distance(bsp.point(at: u2), SIMD2(7.30384225384, 1.78034673468)) < 1e-9)
    }

    @Test func increaseDegree() throws {
        let bsp = try makeCurve()
        let oldDeg = bsp.bspline.degree
        let ok = bsp.bspline.increaseDegree(to: oldDeg + 1)
        #expect(ok)
        #expect(bsp.bspline.degree == oldDeg + 1)
        #expect(bsp.bsplineMultiplicities == [5, 2, 2, 5])
        #expect(bsp.bspline.poleCount == 9)
    }

    @Test func setWeight() throws {
        // Setting a weight other than 1 makes a non-rational BSpline rational.
        let bsp = try makeCurve()
        #expect(bsp.bspline.setWeight(at: 1, to: 2.0))
        #expect(bsp.bspline.isRational)
    }

    @Test func removeKnot() throws {
        // With tolerance 1.0 the kernel removes interior knot 2 (u = 5) outright.
        let bsp = try makeCurve()
        #expect(bsp.bspline.removeKnot(at: 2, multiplicity: 0, tolerance: 1.0))
        #expect(bsp.bspline.knotCount == 3)
        #expect(abs(bsp.bsplineKnot(index: 2) - 9.472135955) < 1e-9)
        #expect(bsp.bspline.poleCount == 5)
    }
}
