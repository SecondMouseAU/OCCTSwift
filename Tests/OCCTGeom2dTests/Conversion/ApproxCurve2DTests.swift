import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Approx Curve2D Tests")
struct ApproxCurve2DTests {
    @Test("Approximate 2D circle as BSpline")
    func approxCircle() {
        if let circle = Curve2D.circle(center: .zero, radius: 10) {
            let d = circle.domain
            let result = circle.approximatedInRange(
                first: d.lowerBound, last: d.upperBound,
                toleranceU: 1e-6, toleranceV: 1e-6)
            #expect(result != nil)
            if let r = result {
                let rd = r.domain
                #expect(rd.upperBound > rd.lowerBound)
            }
        }
    }
}
