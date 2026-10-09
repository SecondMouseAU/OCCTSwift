import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomConvert ApproxCurve Tests")
struct GeomConvertApproxCurveTests {
    @Test("approximate circle as BSpline")
    func approxCircle() {
        if let circle = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 10) {
            let result = circle.approxWithDetails(tolerance: 1e-3)
            #expect(result.hasResult)
            #expect(result.curve != nil)
            if result.isDone {
                #expect(result.maxError < 1e-3)
            }
        }
    }

    @Test("approximate line as BSpline")
    func approxLine() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 1, 0)) {
            let trimmed = line.trimmed(from: 0, to: 10)
            if let t = trimmed {
                let result = t.approxWithDetails(tolerance: 1e-6, continuity: .c1)
                #expect(result.isDone)
            }
        }
    }
}
