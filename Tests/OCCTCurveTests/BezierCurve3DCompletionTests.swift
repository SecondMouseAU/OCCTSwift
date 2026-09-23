import Foundation
import Testing
import simd

@testable import OCCTSwift

// Every value is Geom_BezierCurve's for the same poles
// (Scripts/repro/766-curve-bezier-curve3d/transcript.txt). The earlier versions wrapped each
// test body in `if let`, so a nil curve passed with nothing checked, and several checked one
// coordinate of one point, so start and end swapped, or a pole's y wrong, passed (#766).
@Suite("Bezier Curve 3D Completions")
struct BezierCurve3DCompletionTests {
    private static let open: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(2, 0, 0)]

    private static func openCurve() -> Curve3D? {
        let c = Curve3D.bezier(poles: open)
        if c == nil { Issue.record("Bezier curve not built") }
        return c
    }

    @Test("StartPoint and EndPoint")
    func startEndPoint() {
        guard let c = Self.openCurve() else { return }
        #expect(simd_distance(c.bezierStartPoint, SIMD3(0, 0, 0)) < 1e-10)
        #expect(simd_distance(c.bezierEndPoint, SIMD3(2, 0, 0)) < 1e-10)
    }

    @Test("GetPoles bulk")
    func poles() {
        guard let c = Self.openCurve() else { return }
        let p = c.bezierPoles
        #expect(p == Self.open)
    }

    @Test("GetWeights returns nil for non-rational")
    func weightsNonRational() {
        guard let c = Self.openCurve() else { return }
        // Geom_BezierCurve::Weights() is null for a non-rational curve, so the wrapper says nil.
        #expect(c.bezierWeights == nil)
    }

    @Test("GetWeights returns values for rational")
    func weightsRational() {
        guard let c = Curve3D.bezier(poles: Self.open, weights: [1.0, 2.0, 1.0]) else {
            Issue.record("rational Bezier curve not built")
            return
        }
        #expect(c.bezierWeights == [1.0, 2.0, 1.0])
    }

    @Test("IsClosed for open curve")
    func isClosed() {
        guard let c = Self.openCurve() else { return }
        #expect(!c.bezierIsClosed)
    }

    @Test("IsClosed for closed curve")
    func isClosedTrue() {
        guard
            let c = Curve3D.bezier(poles: [
                SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(2, 0, 0), SIMD3(0, 0, 0),
            ])
        else {
            Issue.record("closed Bezier curve not built")
            return
        }
        #expect(c.bezierIsClosed)
    }

    @Test("IsPeriodic always false for Bezier")
    func isPeriodic() {
        guard let c = Self.openCurve() else { return }
        #expect(!c.bezierIsPeriodic)
    }

    @Test("Continuity is CN for Bezier")
    func continuity() {
        guard let c = Self.openCurve() else { return }
        #expect(c.bezierContinuity == 6)  // CN = 6 in GeomAbs_Shape
    }

    @Test("IsCN always true for Bezier")
    func isCN() {
        guard let c = Self.openCurve() else { return }
        #expect(c.bezierIsCN(0))
        #expect(c.bezierIsCN(1))
        #expect(c.bezierIsCN(10))
    }
}
