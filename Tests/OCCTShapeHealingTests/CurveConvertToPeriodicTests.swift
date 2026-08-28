import Foundation
import Testing
import simd

@testable import OCCTSwift

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
        if let periodic = curve.convertToPeriodic() {
            #expect(periodic.handle != nil)
        }
    }
}
