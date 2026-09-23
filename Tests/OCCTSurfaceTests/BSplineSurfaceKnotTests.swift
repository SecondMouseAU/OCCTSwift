import Testing
import simd

@testable import OCCTSwift

@Suite("BSplineSurface Knot Queries")
struct BSplineSurfaceKnotTests {

    // #766: every test sat inside `if let bs`, so a missing BSpline passed silently, and most
    // checked only a sign or a range (`> 0`, `isFinite`, `uc || !uc`). GeomConvert's BSpline form of
    // the radius-5 sphere is 6x5 poles on [0, 2 pi] x [-pi/2, pi/2], U knots 0, 2pi/3, 4pi/3, 2pi
    // (x2 each, non-uniform) and V knots -pi/2, 0, pi/2 (x3, x2, x3, piecewise Bezier). Values are
    // Geom_BSplineSurface's own, see Scripts/repro/766-bspline-knots-local-eval/.
    private func sphereBSpline() -> Surface? {
        let bs = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0)?.toBSpline()
        #expect(bs != nil, "sphere BSpline")
        return bs
    }
    @Test("LocateU returns valid span")
    func locateU() {
        if let bs = sphereBSpline() {
            let bounds = bs.bsplineBounds
            let uMid = (bounds.u1 + bounds.u2) / 2.0
            let span = bs.bsplineLocateU(u: uMid, paramTol: 1e-10)
            // u = pi lies strictly inside the second span [2pi/3, 4pi/3].
            #expect(span.i1 == 2)
            #expect(span.i2 == 3)
        }
    }

    @Test("LocateV returns valid span")
    func locateV() {
        if let bs = sphereBSpline() {
            let bounds = bs.bsplineBounds
            let vMid = (bounds.v1 + bounds.v2) / 2.0
            let span = bs.bsplineLocateV(v: vMid, paramTol: 1e-10)
            // v = 0 is knot 2 itself, so both ends of the span are 2.
            #expect(span.i1 == 2)
            #expect(span.i2 == 2)
        }
    }

    @Test("UKnot and VKnot return values")
    func knotValues() {
        if let bs = sphereBSpline() {
            // First knot is always index 1
            let uk = bs.bsplineUKnot(index: 1)
            let vk = bs.bsplineVKnot(index: 1)
            #expect(uk == 0)
            #expect(vk == -Double.pi / 2)
        }
    }

    @Test("UMultiplicity and VMultiplicity")
    func multiplicity() {
        if let bs = sphereBSpline() {
            let um = bs.bsplineUMultiplicity(index: 1)
            let vm = bs.bsplineVMultiplicity(index: 1)
            #expect(um == 2)
            #expect(vm == 3)
        }
    }

    @Test("UKnotDistribution and VKnotDistribution")
    func knotDistribution() {
        if let bs = sphereBSpline() {
            let ud = bs.bsplineUKnotDistribution
            let vd = bs.bsplineVKnotDistribution
            #expect(ud == 0)  // GeomAbs_NonUniform
            #expect(vd == 3)  // GeomAbs_PiecewiseBezier
        }
    }

    @Test("Bounds returns valid range")
    func bounds() {
        if let bs = sphereBSpline() {
            let b = bs.bsplineBounds
            #expect(b.u1 == 0 && b.u2 == 2 * Double.pi)
            #expect(b.v1 == -Double.pi / 2 && b.v2 == Double.pi / 2)
        }
    }

    @Test("IsUClosed and IsVClosed")
    func closedQueries() {
        if let bs = sphereBSpline() {
            // Was `uc || !uc`, true for any answer. The sphere closes in U (a full revolution);
            // in V its two ends are the poles, distinct points, so it is not V-closed.
            #expect(bs.bsplineIsUClosed)
            #expect(!bs.bsplineIsVClosed)
        }
    }

    @Test("BSpline GetPoles bulk")
    func getPoles() {
        if let bs = sphereBSpline() {
            let poles = bs.bsplinePoles
            let expected = bs.uPoleCount * bs.vPoleCount
            #expect(poles.count == expected)
            #expect(expected == 30)
            // Row-major: poles[k] is pole(1, k + 1). The first is the south pole (0, 0, -5).
            let grid = bs.bsplineSurface
            #expect(poles.count == 30)
            if poles.count == 30 {
                #expect(simd_length(poles[0] - SIMD3(0, 0, -5)) < 1e-12)
                #expect((0..<5).allSatisfy { poles[$0] == grid.pole(uIndex: 1, vIndex: $0 + 1) })
                #expect(poles[5] == grid.pole(uIndex: 2, vIndex: 1))
            }
        }
    }
}
