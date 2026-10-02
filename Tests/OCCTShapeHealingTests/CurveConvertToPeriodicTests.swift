import Foundation
import Testing
import simd

@testable import OCCTSwift

/// `ShapeCustom_Curve::ConvertToPeriodic`, asserted on the periodicity it was called for.
///
/// The body used to be `if let periodic = ... { #expect(periodic.handle != nil) }`, always true for
/// a non-optional `OCCTCurve3DRef`, so a conversion that returned the input unchanged, or returned
/// nothing at all, read as a pass (#3018). The conversion has exactly one job and one risk: make
/// the curve periodic, without moving it. Both are now measured, and the input's own
/// `isPeriodic == false` is the control that makes the first of them mean something.
@Suite("ShapeCustom_Curve ConvertToPeriodic")
struct CurveConvertToPeriodicTests {
    @Test("Convert closed BSpline to periodic")
    func convertToPeriodic() throws {
        let curve = try #require(
            Curve3D.interpolate(points: [
                SIMD3(10, 0, 0), SIMD3(0, 10, 0),
                SIMD3(-10, 0, 0), SIMD3(0, -10, 0),
                SIMD3(10, 0, 0),
            ]))
        // The control. An interpolation through a repeated first point is closed but not periodic,
        // so there is something for the conversion to change.
        #expect(curve.isClosed)
        #expect(curve.isPeriodic == false)

        let periodic = try #require(curve.convertToPeriodic())
        #expect(periodic.isPeriodic)
        #expect(periodic.isClosed)

        // And it is the same curve. ConvertToPeriodic re-knots rather than re-fits, so the domain
        // and every point on it survive, which is what makes the result a drop-in replacement.
        #expect(abs(periodic.domain.lowerBound - curve.domain.lowerBound) < 1e-9)
        #expect(abs(periodic.domain.upperBound - curve.domain.upperBound) < 1e-9)
        for k in 0...8 {
            let f = Double(k) / 8.0
            let span = curve.domain.upperBound - curve.domain.lowerBound
            let u = curve.domain.lowerBound + span * f
            #expect(simd_distance(periodic.point(at: u), curve.point(at: u)) < 1e-7)
        }
    }
}
