import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Approx Curve2D Tests")
struct ApproxCurve2DTests {
    @Test("Approximate 2D circle as BSpline")
    func approxCircle() throws {
        // #1979: `upperBound > lowerBound` passed an approximation of any sub-range of the
        // circle. Approx_Curve2d keeps the requested range [0, 2pi] and stays on the radius-10
        // circle within its reported 6.9e-8 error (Scripts/repro/766-geom2d-aht-axisplacement/).
        let circle = try #require(Curve2D.circle(center: .zero, radius: 10))
        let d = circle.domain
        let r = try #require(
            circle.approximatedInRange(
                first: d.lowerBound, last: d.upperBound,
                toleranceU: 1e-6, toleranceV: 1e-6))
        let rd = r.domain
        #expect(abs(rd.lowerBound) < 1e-12)
        #expect(abs(rd.upperBound - 2 * Double.pi) < 1e-12)
        let p = r.point(at: Double.pi / 3)
        #expect(abs(p.x - 5.0) < 1e-6)
        #expect(abs(p.y - 8.66025403784) < 1e-6)
    }
}
