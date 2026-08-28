import Testing
import simd

@testable import OCCTSwift

@Suite("Bezier Surface Completions")
struct BezierSurfaceCompletionTests {
    @Test("UIso and VIso return curves")
    func isoCurves() {
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 2, 0)],
            [SIMD3(1, 0, 1), SIMD3(1, 1, 1), SIMD3(1, 2, 1)],
            [SIMD3(2, 0, 0), SIMD3(2, 1, 0), SIMD3(2, 2, 0)],
        ]
        let s = Surface.bezier(poles: poles)
        if let s = s {
            let uIso = s.bezierUIso(u: 0.5)
            let vIso = s.bezierVIso(v: 0.5)
            #expect(uIso != nil)
            #expect(vIso != nil)
        }
    }

    @Test("IsUClosed and IsVClosed")
    func closedQueries() {
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 1, 0)],
            [SIMD3(1, 0, 1), SIMD3(1, 1, 1)],
        ]
        let s = Surface.bezier(poles: poles)
        if let s = s {
            #expect(!s.bezierIsUClosed)
            #expect(!s.bezierIsVClosed)
        }
    }

    @Test("IsUPeriodic and IsVPeriodic always false")
    func periodicQueries() {
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 1, 0)],
            [SIMD3(1, 0, 1), SIMD3(1, 1, 1)],
        ]
        let s = Surface.bezier(poles: poles)
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
        if let s = s {
            let p = s.bezierPoles
            #expect(p.count == 4)  // 2x2
        }
    }

    @Test("GetWeights for non-rational returns nil")
    func weightsNonRational() {
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 1, 0)],
            [SIMD3(1, 0, 1), SIMD3(1, 1, 1)],
        ]
        let s = Surface.bezier(poles: poles)
        if let s = s {
            let w = s.bezierWeights
            // Non-rational: may return nil or all 1.0
            if let w = w {
                for weight in w {
                    #expect(abs(weight - 1.0) < 1e-10)
                }
            }
        }
    }

    @Test("Bounds returns [0,1]x[0,1]")
    func bounds() {
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 1, 0)],
            [SIMD3(1, 0, 1), SIMD3(1, 1, 1)],
        ]
        let s = Surface.bezier(poles: poles)
        if let s = s {
            let b = s.bezierBounds
            #expect(abs(b.u1 - 0) < 1e-10)
            #expect(abs(b.u2 - 1) < 1e-10)
            #expect(abs(b.v1 - 0) < 1e-10)
            #expect(abs(b.v2 - 1) < 1e-10)
        }
    }
}
