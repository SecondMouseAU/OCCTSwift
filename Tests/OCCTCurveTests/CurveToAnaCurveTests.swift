import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomConvert_CurveToAnaCurve")
struct CurveToAnaCurveTests {
    @Test("recognize line from BSpline")
    func recognizeLine() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)),
            let trimmed = line.trimmed(from: 0, to: 10),
            let bsp = trimmed.toBSpline()
        {
            let domain = bsp.domain
            if let result = bsp.toAnalytical(
                tolerance: 1e-4,
                first: domain.lowerBound,
                last: domain.upperBound)
            {
                #expect(result.gap < 1e-3)
            }
        }
    }

    @Test("recognize circle from BSpline")
    func recognizeCircle() {
        if let circ = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5),
            let trimmed = circ.trimmed(from: 0, to: .pi),
            let bsp = trimmed.toBSpline()
        {
            let domain = bsp.domain
            if let result = bsp.toAnalytical(
                tolerance: 1e-4,
                first: domain.lowerBound,
                last: domain.upperBound)
            {
                #expect(result.gap < 1e-3)
            }
        }
    }

    @Test("check points are linear")
    func checkLinear() {
        let points: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(5, 0, 0), SIMD3(10, 0, 0)]
        let (isLinear, deviation) = Curve3D.arePointsLinear(points, tolerance: 1e-6)
        #expect(isLinear)
        #expect(deviation < 1e-5)
    }
}
