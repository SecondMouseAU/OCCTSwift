import Foundation
import Testing
import simd

@testable import OCCTSwift

// Pinned to GeomConvert_CurveToAnaCurve on the same BSplines
// (Scripts/repro/766-curve-toana-cuttingplane/transcript.txt). The earlier recognition tests
// nested their one check in `if let result`, so a conversion that failed passed with nothing
// checked (#766).
@Suite("GeomConvert_CurveToAnaCurve")
struct CurveToAnaCurveTests {
    @Test("recognize line from BSpline")
    func recognizeLine() {
        guard let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)),
            let trimmed = line.trimmed(from: 0, to: 10),
            let bsp = trimmed.toBSpline()
        else {
            Issue.record("BSpline line not built")
            return
        }
        let domain = bsp.domain
        guard
            let result = bsp.toAnalytical(
                tolerance: 1e-4,
                first: domain.lowerBound,
                last: domain.upperBound)
        else {
            Issue.record("line not recognized")
            return
        }
        #expect(result.gap < 1e-3)
        #expect(result.curve.curveType == 0)  // Line
        #expect(abs(result.newFirst) < 1e-12)
        #expect(abs(result.newLast - 10) < 1e-12)
    }

    @Test("recognize circle from BSpline")
    func recognizeCircle() {
        guard let circ = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5),
            let trimmed = circ.trimmed(from: 0, to: .pi),
            let bsp = trimmed.toBSpline()
        else {
            Issue.record("BSpline half circle not built")
            return
        }
        let domain = bsp.domain
        guard
            let result = bsp.toAnalytical(
                tolerance: 1e-4,
                first: domain.lowerBound,
                last: domain.upperBound)
        else {
            Issue.record("circle not recognized")
            return
        }
        #expect(result.gap < 1e-3)
        #expect(result.curve.curveType == 1)  // Circle
        #expect(abs(result.newLast - 3.1415926535897922) < 1e-12)
    }

    @Test("check points are linear")
    func checkLinear() {
        let points: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(5, 0, 0), SIMD3(10, 0, 0)]
        let (isLinear, deviation) = Curve3D.arePointsLinear(points, tolerance: 1e-6)
        #expect(isLinear)
        #expect(deviation == 0)
    }
}
