import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.125.0: BSpline/Bezier deep method completion tests

@Suite("BSplineSurface Local Evaluation")
struct BSplineSurfaceLocalEvalTests {

    // #766: every test sat inside `if let bs`, so a missing BSpline passed silently, and each
    // evaluation sat behind a further span check, and four checked only a non-zero length. GeomConvert's BSpline form of
    // the radius-5 sphere is 6x5 poles on [0, 2 pi] x [-pi/2, pi/2], U knots 0, 2pi/3, 4pi/3, 2pi
    // (x2 each, non-uniform) and V knots -pi/2, 0, pi/2 (x3, x2, x3, piecewise Bezier). Values are
    // Geom_BSplineSurface's own, see Scripts/repro/766-bspline-knots-local-eval/.
    private func sphereBSpline() -> Surface? {
        let bs = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0)?.toBSpline()
        #expect(bs != nil, "sphere BSpline")
        return bs
    }

    // The midpoint (pi, 0) lies in U span (2, 3) and on V knot 2.
    private func spans(_ bs: Surface) -> (u: Double, v: Double, i1: Int, i2: Int, j1: Int, j2: Int) {
        let b = bs.bsplineBounds
        let u = (b.u1 + b.u2) / 2, v = (b.v1 + b.v2) / 2
        let us = bs.bsplineLocateU(u: u, paramTol: 1e-10)
        let vs = bs.bsplineLocateV(v: v, paramTol: 1e-10)
        #expect(us.i1 == 2 && us.i2 == 3 && vs.i1 == 2 && vs.i2 == 2)
        return (u, v, us.i1, us.i2, vs.i1, vs.i2)
    }
    @Test("LocalD0 matches global D0")
    func localD0() {
        if let bs = sphereBSpline() {
            let s = spans(bs)
            let localPt = bs.bsplineLocalD0(u: s.u, v: s.v, fromUK1: s.i1, toUK2: s.i2, fromVK1: s.j1, toVK2: s.j2)
            let globalPt = bs.point(atU: s.u, v: s.v)
            #expect(simd_length(localPt - globalPt) < 1e-10)
            #expect(simd_length(localPt - SIMD3(-5, 0, 0)) < 1e-12)
        }
    }

    @Test("LocalD1 returns point and derivatives")
    func localD1() {
        if let bs = sphereBSpline() {
            let s = spans(bs)
            let r = bs.bsplineLocalD1(u: s.u, v: s.v, fromUK1: s.i1, toUK2: s.i2, fromVK1: s.j1, toVK2: s.j2)
            // Was `|d1u| > 0` and `|d1v| > 0`. The rational parameterisation makes |D1U| 5.513,
            // not the radius.
            #expect(simd_length(r.d1u - SIMD3(0, -5.5132889542179191, 0)) < 1e-9)
            #expect(simd_length(r.d1v - SIMD3(0, 0, 4.5015815807855297)) < 1e-9)
        }
    }

    @Test("LocalD2 returns second derivatives")
    func localD2() {
        if let bs = sphereBSpline() {
            let s = spans(bs)
            let r = bs.bsplineLocalD2(u: s.u, v: s.v, fromUK1: s.i1, toUK2: s.i2, fromVK1: s.j1, toVK2: s.j2)
            #expect(simd_length(r.point - SIMD3(-5, 0, 0)) < 1e-9)
            #expect(simd_length(r.d2u - SIMD3(6.0792710185402647, 0, 0)) < 1e-9)
            #expect(simd_length(r.d2v - SIMD3(4.0528473456935101, 0, -1.6787443368140527)) < 1e-9)
            #expect(simd_length(r.d2uv) < 1e-9)
        }
    }

    @Test("LocalD3 returns third derivatives")
    func localD3() {
        if let bs = sphereBSpline() {
            let s = spans(bs)
            let r = bs.bsplineLocalD3(u: s.u, v: s.v, fromUK1: s.i1, toUK2: s.i2, fromVK1: s.j1, toVK2: s.j2)
            #expect(simd_length(r.point - SIMD3(-5, 0, 0)) < 1e-9)
            #expect(simd_length(r.d3u - SIMD3(0, 10.055033326864551, 0)) < 1e-9)
            #expect(simd_length(r.d3v - SIMD3(-4.5342027512700955, 0, -4.5342027512700929)) < 1e-9)
        }
    }

    @Test("LocalDN derivative")
    func localDN() {
        if let bs = sphereBSpline() {
            let s = spans(bs)
            let v = bs.bsplineLocalDN(
                u: s.u, v: s.v, fromUK1: s.i1, toUK2: s.i2, fromVK1: s.j1, toVK2: s.j2, nu: 1, nv: 0)
            // DN(1, 0) is D1U.
            #expect(simd_length(v - SIMD3(0, -5.5132889542179191, 0)) < 1e-9)
        }
    }

    @Test("LocalValue matches global")
    func localValue() {
        if let bs = sphereBSpline() {
            let s = spans(bs)
            let localPt = bs.bsplineLocalValue(u: s.u, v: s.v, fromUK1: s.i1, toUK2: s.i2, fromVK1: s.j1, toVK2: s.j2)
            let globalPt = bs.point(atU: s.u, v: s.v)
            #expect(simd_length(localPt - globalPt) < 1e-10)
            #expect(simd_length(localPt - SIMD3(-5, 0, 0)) < 1e-12)
        }
    }
}
