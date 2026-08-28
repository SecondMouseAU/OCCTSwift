import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve2D ConvertToLine Tests")
struct Curve2DConvertToLineTests {
    @Test("Convert linear BSpline to line")
    func convertLinearBSpline() {
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(10, 0)]
        if let curve = Curve2D.interpolate(through: pts) {
            let d = curve.domain
            let result = curve.convertToLine(
                first: d.lowerBound, last: d.upperBound, tolerance: 1e-3)
            #expect(result != nil)
        }
    }
}
