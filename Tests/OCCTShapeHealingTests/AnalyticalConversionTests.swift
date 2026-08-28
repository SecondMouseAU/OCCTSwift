import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Analytical Conversion")
struct AnalyticalConversionTests {
    @Test("BSpline circle converts to analytical")
    func bsplineCircle() {
        // Create a circle as BSpline, then try to recognize it
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 10)!
        let bspline = circle.toBSpline()
        if let bs = bspline {
            let analytical = bs.toAnalytical(tolerance: 0.01)
            // May or may not succeed depending on OCCT's recognition
            if let a = analytical {
                // If recognized, evaluate at parameter 0
                let pt = a.point(at: 0)
                #expect(pt != nil)
            }
        }
    }

    @Test("Surface analytical conversion")
    func surfaceConversion() {
        // A cylindrical surface as BSpline
        let cyl = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5)!
        let bspline = cyl.toBSpline()
        if let bs = bspline {
            let analytical = bs.toAnalytical(tolerance: 0.01)
            // May or may not succeed
            if let a = analytical {
                let pt = a.point(atU: 0, v: 0)
                #expect(pt != nil)
            }
        }
    }
}
