import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-curve-custom/probe.mm (transcript.txt beside it).
// Before #766 the test asserted `handle != nil` inside `if let`, which no result can fail.
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
        // Kernel: the interpolated curve is closed but not periodic.
        #expect(curve.isClosed)
        #expect(!curve.isPeriodic)
        let periodic = try #require(curve.convertToPeriodic())
        #expect(periodic.isPeriodic)
        #expect(periodic.curveType == 6)  // still a BSpline
        #expect(abs(periodic.domain.upperBound - 56.568542495) < 1e-6)
        #expect(simd_distance(periodic.point(at: periodic.domain.lowerBound), SIMD3(10, 0, 0)) < 1e-9)
    }
}
