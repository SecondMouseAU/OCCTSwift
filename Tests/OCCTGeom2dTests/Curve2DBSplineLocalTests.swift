import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: every test here returned early, green, when the span could not be located, and three
// could not fail at all: `simd_length(r.v1) > 0`, `simd_length(r.point) > 0 || ... == 0` and
// `simd_length(dn) > 0` pass a wrong derivative. The span is now required and each derivative is
// pinned to what Geom2d_BSplineCurve::LocalD1/D2/D3/DN return for the same curve and span
// (Scripts/repro/766-geom2d-bspline-local-and-factories/).
@Suite("Curve2D BSpline Local Evaluation")
struct Curve2DBSplineLocalTests {
    /// Builds a 2D BSpline via interpolation, locates the local span around the midpoint of its
    /// first and last knot indices, and returns the curve plus that span.
    private func locateLocalSpan(_ pts: [SIMD2<Double>]) throws
        -> (curve: Curve2D, u: Double, fromK1: Int, toK2: Int)
    {
        let c = try #require(Curve2D.interpolate(through: pts))
        let fk = c.bsplineFirstUKnotIndex
        let lk = c.bsplineLastUKnotIndex
        try #require(fk > 0 && lk > fk)
        let u = (c.bsplineKnot(index: fk) + c.bsplineKnot(index: lk)) / 2.0
        let span = c.bsplineLocateU(u: u, paramTol: 1e-10)
        try #require(span.i1 > 0 && span.i2 > 0)
        return (c, u, span.i1, span.i2)
    }

    @Test("LocalD0 matches global")
    func localD0() throws {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0), SIMD2(3, 1)]
        let (c, u, k1, k2) = try locateLocalSpan(pts)
        let local = c.bsplineLocalD0(u: u, fromK1: k1, toK2: k2)
        let global = c.point(at: u)
        let dist = simd_length(local - global)
        #expect(dist < 1e-10)
        #expect(simd_distance(local, SIMD2(1.5, 0.5)) < 1e-9)
    }

    @Test("LocalD1 returns derivative")
    func localD1() throws {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)]
        let (c, u, k1, k2) = try locateLocalSpan(pts)
        let r = c.bsplineLocalD1(u: u, fromK1: k1, toK2: k2)
        #expect(simd_distance(r.point, SIMD2(1, 1)) < 1e-9)
        #expect(simd_distance(r.v1, SIMD2(0.707106781187, 0)) < 1e-9)
    }

    @Test("LocalD2 returns second derivative")
    func localD2() throws {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 2), SIMD2(2, 0), SIMD2(3, 2)]
        let (c, u, k1, k2) = try locateLocalSpan(pts)
        let r = c.bsplineLocalD2(u: u, fromK1: k1, toK2: k2)
        #expect(simd_distance(r.point, SIMD2(1.5, 1)) < 1e-9)
        #expect(simd_distance(r.v1, SIMD2(0.4472135955, -1.0434983895)) < 1e-9)
        // The midpoint is the inflection of this symmetric zigzag: zero second derivative.
        #expect(simd_length(r.v2) < 1e-9)
    }

    @Test("LocalD3 and LocalDN")
    func localD3DN() throws {
        let pts: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(1, 2), SIMD2(2, 0), SIMD2(3, 2), SIMD2(4, 0),
        ]
        let (c, u, k1, k2) = try locateLocalSpan(pts)
        let d3 = c.bsplineLocalD3(u: u, fromK1: k1, toK2: k2)
        #expect(simd_distance(d3.v2, SIMD2(0, 1.73333333333)) < 1e-9)
        #expect(simd_distance(d3.v3, SIMD2(0, 1.2521980674)) < 1e-9)
        let dn = c.bsplineLocalDN(u: u, fromK1: k1, toK2: k2, n: 1)
        #expect(simd_distance(dn, SIMD2(0.4472135955, 0)) < 1e-9)
    }

    @Test("LocalValue matches global")
    func localValue() throws {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)]
        let (c, u, k1, k2) = try locateLocalSpan(pts)
        let local = c.bsplineLocalValue(u: u, fromK1: k1, toK2: k2)
        let global = c.point(at: u)
        let dist = simd_length(local - global)
        #expect(dist < 1e-10)
        #expect(simd_distance(local, SIMD2(1, 1)) < 1e-9)
    }
}
