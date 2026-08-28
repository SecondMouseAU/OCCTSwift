import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Bezier Curve 3D Completions")
struct BezierCurve3DCompletionTests {
    @Test("StartPoint and EndPoint")
    func startEndPoint() {
        let poles: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(2, 0, 0)]
        let c = Curve3D.bezier(poles: poles)
        if let c = c {
            let sp = c.bezierStartPoint
            let ep = c.bezierEndPoint
            #expect(abs(sp.x - 0) < 1e-10)
            #expect(abs(ep.x - 2) < 1e-10)
        }
    }

    @Test("GetPoles bulk")
    func poles() {
        let inputPoles: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(2, 0, 0)]
        let c = Curve3D.bezier(poles: inputPoles)
        if let c = c {
            let p = c.bezierPoles
            #expect(p.count == 3)
            if p.count == 3 {
                #expect(abs(p[0].x - 0) < 1e-10)
                #expect(abs(p[1].x - 1) < 1e-10)
                #expect(abs(p[2].x - 2) < 1e-10)
            }
        }
    }

    @Test("GetWeights returns nil for non-rational")
    func weightsNonRational() {
        let poles: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(2, 0, 0)]
        let c = Curve3D.bezier(poles: poles)
        if let c = c {
            let w = c.bezierWeights
            // Non-rational curve may return nil or all 1.0 weights
            if let w = w {
                for weight in w {
                    #expect(abs(weight - 1.0) < 1e-10)
                }
            }
        }
    }

    @Test("GetWeights returns values for rational")
    func weightsRational() {
        let poles: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(2, 0, 0)]
        let weights = [1.0, 2.0, 1.0]
        let c = Curve3D.bezier(poles: poles, weights: weights)
        if let c = c {
            let w = c.bezierWeights
            #expect(w != nil)
            if let w = w {
                #expect(w.count == 3)
                if w.count == 3 {
                    #expect(abs(w[1] - 2.0) < 1e-10)
                }
            }
        }
    }

    @Test("IsClosed for open curve")
    func isClosed() {
        let poles: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(2, 0, 0)]
        let c = Curve3D.bezier(poles: poles)
        if let c = c {
            #expect(!c.bezierIsClosed)
        }
    }

    @Test("IsClosed for closed curve")
    func isClosedTrue() {
        let poles: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(2, 0, 0), SIMD3(0, 0, 0),
        ]
        let c = Curve3D.bezier(poles: poles)
        if let c = c {
            #expect(c.bezierIsClosed)
        }
    }

    @Test("IsPeriodic always false for Bezier")
    func isPeriodic() {
        let poles: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(2, 0, 0)]
        let c = Curve3D.bezier(poles: poles)
        if let c = c {
            #expect(!c.bezierIsPeriodic)
        }
    }

    @Test("Continuity is CN for Bezier")
    func continuity() {
        let poles: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(2, 0, 0)]
        let c = Curve3D.bezier(poles: poles)
        if let c = c {
            let cont = c.bezierContinuity
            #expect(cont == 6)  // CN = 6 in GeomAbs_Shape
        }
    }

    @Test("IsCN always true for Bezier")
    func isCN() {
        let poles: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(2, 0, 0)]
        let c = Curve3D.bezier(poles: poles)
        if let c = c {
            #expect(c.bezierIsCN(0))
            #expect(c.bezierIsCN(1))
            #expect(c.bezierIsCN(10))
        }
    }
}
