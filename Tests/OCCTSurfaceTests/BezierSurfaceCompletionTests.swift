import Testing
import simd

@testable import OCCTSwift

@Suite("Bezier Surface Completions")
struct BezierSurfaceCompletionTests {

    // #766: every test here sat inside `if let s`, so a nil surface passed silently; each now
    // asserts the surface exists first. Where a test only checked "non-nil" or a count, it now
    // also checks the value, pinned to Geom_BezierSurface's own answer on the same poles, see
    // Scripts/repro/766-bezier-surface-queries/.
    @Test("UIso and VIso return curves")
    func isoCurves() {
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 2, 0)],
            [SIMD3(1, 0, 1), SIMD3(1, 1, 1), SIMD3(1, 2, 1)],
            [SIMD3(2, 0, 0), SIMD3(2, 1, 0), SIMD3(2, 2, 0)],
        ]
        let s = Surface.bezier(poles: poles)
        #expect(s != nil)
        if let s = s {
            let uIso = s.bezierUIso(u: 0.5)
            let vIso = s.bezierVIso(v: 0.5)
            #expect(uIso != nil)
            #expect(vIso != nil)
            // The U-iso at u = 0.5 is the surface's v-curve there, and the V-iso the u-curve.
            if let uIso, let vIso {
                #expect(simd_length(uIso.point(at: 0.3) - s.point(atU: 0.5, v: 0.3)) < 1e-12)
                #expect(simd_length(uIso.point(at: 0.3) - SIMD3(1, 0.6, 0.5)) < 1e-12)
                #expect(simd_length(vIso.point(at: 0.3) - s.point(atU: 0.3, v: 0.5)) < 1e-12)
                #expect(simd_length(vIso.point(at: 0.3) - SIMD3(0.6, 1, 0.42)) < 1e-12)
            }
        }
    }

    @Test("IsUClosed and IsVClosed")
    func closedQueries() {
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 1, 0)],
            [SIMD3(1, 0, 1), SIMD3(1, 1, 1)],
        ]
        let s = Surface.bezier(poles: poles)
        #expect(s != nil)
        if let s = s {
            #expect(!s.bezierIsUClosed)
            #expect(!s.bezierIsVClosed)
        }
        // And the positive case, which "always false" passed: a first row equal to the last row
        // closes the surface in U only, a first column equal to the last closes it in V only.
        let uClosed = Surface.bezier(poles: [
            [SIMD3(0, 0, 0), SIMD3(0, 1, 0)], [SIMD3(1, 0, 1), SIMD3(1, 1, 1)], [SIMD3(0, 0, 0), SIMD3(0, 1, 0)],
        ])
        let vClosed = Surface.bezier(poles: [
            [SIMD3(0, 0, 0), SIMD3(0, 1, 1), SIMD3(0, 0, 0)], [SIMD3(1, 0, 0), SIMD3(1, 1, 1), SIMD3(1, 0, 0)],
        ])
        #expect(uClosed != nil && vClosed != nil)
        if let uClosed, let vClosed {
            #expect(uClosed.bezierIsUClosed && !uClosed.bezierIsVClosed)
            #expect(!vClosed.bezierIsUClosed && vClosed.bezierIsVClosed)
        }
    }

    @Test("IsUPeriodic and IsVPeriodic always false")
    func periodicQueries() {
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 1, 0)],
            [SIMD3(1, 0, 1), SIMD3(1, 1, 1)],
        ]
        let s = Surface.bezier(poles: poles)
        #expect(s != nil)
        if let s = s {
            #expect(!s.bezierIsUPeriodic)
            #expect(!s.bezierIsVPeriodic)
        }
    }

    @Test("Continuity is CN")
    func continuity() {
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 1, 0)],
            [SIMD3(1, 0, 1), SIMD3(1, 1, 1)],
        ]
        let s = Surface.bezier(poles: poles)
        #expect(s != nil)
        if let s = s {
            #expect(s.bezierContinuity == 6)  // CN = 6 in GeomAbs_Shape
        }
    }

    @Test("IsCNu and IsCNv always true")
    func isCN() {
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 1, 0)],
            [SIMD3(1, 0, 1), SIMD3(1, 1, 1)],
        ]
        let s = Surface.bezier(poles: poles)
        #expect(s != nil)
        if let s = s {
            #expect(s.bezierIsCNu(0))
            #expect(s.bezierIsCNu(10))
            #expect(s.bezierIsCNv(0))
            #expect(s.bezierIsCNv(10))
        }
    }

    @Test("GetPoles bulk")
    func poles() {
        let inputPoles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 1, 0)],
            [SIMD3(1, 0, 1), SIMD3(1, 1, 1)],
        ]
        let s = Surface.bezier(poles: inputPoles)
        #expect(s != nil)
        if let s = s {
            let p = s.bezierPoles
            #expect(p.count == 4)  // 2x2
            // Row-major, u rows then v columns: exactly the input, not its transpose.
            #expect(p == inputPoles.flatMap { $0 })
        }
    }

    @Test("GetWeights for non-rational returns nil")
    func weightsNonRational() {
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 1, 0)],
            [SIMD3(1, 0, 1), SIMD3(1, 1, 1)],
        ]
        let s = Surface.bezier(poles: poles)
        #expect(s != nil)
        if let s = s {
            // Non-rational: Geom_BezierSurface::Weights() is null, and `bezierWeights` documents
            // nil for that. The old "nil or all 1.0" accepted an invented array of ones.
            #expect(s.bezierWeights == nil)
        }
    }

    @Test("Bounds returns [0,1]x[0,1]")
    func bounds() {
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 1, 0)],
            [SIMD3(1, 0, 1), SIMD3(1, 1, 1)],
        ]
        let s = Surface.bezier(poles: poles)
        #expect(s != nil)
        if let s = s {
            let b = s.bezierBounds
            #expect(abs(b.u1 - 0) < 1e-10)
            #expect(abs(b.u2 - 1) < 1e-10)
            #expect(abs(b.v1 - 0) < 1e-10)
            #expect(abs(b.v2 - 1) < 1e-10)
        }
    }
}
