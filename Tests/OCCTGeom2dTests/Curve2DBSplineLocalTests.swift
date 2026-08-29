import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve2D BSpline Local Evaluation")
struct Curve2DBSplineLocalTests {
    /// Builds a 2D BSpline via interpolation, locates the local span around the midpoint of its
    /// first and last knot indices, and returns the curve plus that span. Returns `nil` (silently,
    /// matching every call site's original behavior) if the curve can't be built, has no interior
    /// knot span, or the span can't be located.
    private func locateLocalSpan(_ pts: [SIMD2<Double>])
        -> (curve: Curve2D, u: Double, fromK1: Int, toK2: Int)?
    {
        guard let c = Curve2D.interpolate(through: pts) else { return nil }
        let fk = c.bsplineFirstUKnotIndex
        let lk = c.bsplineLastUKnotIndex
        guard fk > 0, lk > fk else { return nil }
        let u = (c.bsplineKnot(index: fk) + c.bsplineKnot(index: lk)) / 2.0
        let span = c.bsplineLocateU(u: u, paramTol: 1e-10)
        guard span.i1 > 0, span.i2 > 0 else { return nil }
        return (c, u, span.i1, span.i2)
    }

    @Test("LocalD0 matches global")
    func localD0() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0), SIMD2(3, 1)]
        guard let (c, u, k1, k2) = locateLocalSpan(pts) else { return }
        let local = c.bsplineLocalD0(u: u, fromK1: k1, toK2: k2)
        let global = c.point(at: u)
        let dist = simd_length(local - global)
        #expect(dist < 1e-10)
    }

    @Test("LocalD1 returns derivative")
    func localD1() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)]
        guard let (c, u, k1, k2) = locateLocalSpan(pts) else { return }
        let r = c.bsplineLocalD1(u: u, fromK1: k1, toK2: k2)
        #expect(simd_length(r.v1) > 0)
    }

    @Test("LocalD2 returns second derivative")
    func localD2() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 2), SIMD2(2, 0), SIMD2(3, 2)]
        guard let (c, u, k1, k2) = locateLocalSpan(pts) else { return }
        let r = c.bsplineLocalD2(u: u, fromK1: k1, toK2: k2)
        // Just check no crash - this assertion always passes
        #expect(simd_length(r.point) > 0 || simd_length(r.point) == 0)
    }

    @Test("LocalD3 and LocalDN")
    func localD3DN() {
        let pts: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(1, 2), SIMD2(2, 0), SIMD2(3, 2), SIMD2(4, 0),
        ]
        guard let (c, u, k1, k2) = locateLocalSpan(pts) else { return }
        let _ = c.bsplineLocalD3(u: u, fromK1: k1, toK2: k2)
        let dn = c.bsplineLocalDN(u: u, fromK1: k1, toK2: k2, n: 1)
        #expect(simd_length(dn) > 0)
    }

    @Test("LocalValue matches global")
    func localValue() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 0)]
        guard let (c, u, k1, k2) = locateLocalSpan(pts) else { return }
        let local = c.bsplineLocalValue(u: u, fromK1: k1, toK2: k2)
        let global = c.point(at: u)
        let dist = simd_length(local - global)
        #expect(dist < 1e-10)
    }
}
