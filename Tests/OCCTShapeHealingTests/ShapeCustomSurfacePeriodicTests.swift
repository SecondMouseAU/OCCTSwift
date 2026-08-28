import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeCustom Surface Periodic Tests")
struct ShapeCustomSurfacePeriodicTests {
    @Test("convert to periodic")
    func convertToPeriodic() {
        if let surf = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5) {
            // Cylinder surface is already periodic, result may be nil
            let _ = surf.convertToPeriodic()
            // Just verify no crash
        }
    }

    @Test("conversion gap")
    func conversionGap() {
        if let surf = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5) {
            let gap = surf.conversionGap
            #expect(gap >= 0)
        }
    }
}
