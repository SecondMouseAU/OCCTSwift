import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve2D ConvertToLine Tests")
struct Curve2DConvertToLineTests {
    @Test("Convert linear BSpline to line")
    func convertLinearBSpline() throws {
        // #1979: `result != nil` inside `if let curve` passed a line anywhere. ShapeCustom_Curve2d::
        // ConvertToLine2d keeps the parameter range [0, 10] with zero deviation and runs along +x
        // from the origin (Scripts/repro/766-geom2d-eval-extras/).
        let pts: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(10, 0)]
        let curve = try #require(Curve2D.interpolate(through: pts))
        let d = curve.domain
        let r = try #require(
            curve.convertToLine(first: d.lowerBound, last: d.upperBound, tolerance: 1e-3))
        #expect(abs(r.newFirst) < 1e-12)
        #expect(abs(r.newLast - 10) < 1e-12)
        #expect(r.deviation < 1e-12)
        #expect(simd_distance(r.line.point(at: r.newLast), SIMD2(10, 0)) < 1e-12)
    }
}
