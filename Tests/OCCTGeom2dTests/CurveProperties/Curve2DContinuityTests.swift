import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve2D Continuity Tests")
struct Curve2DContinuityTests {

    @Test func line2DContinuity() {
        if let line = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)) {
            let c = line.continuity
            #expect(c >= 0)
        }
    }

    @Test func bspline2DContinuity() {
        if let bsp = Curve2D.interpolate(through: [
            SIMD2(0, 0), SIMD2(1, 1),
            SIMD2(2, 0), SIMD2(3, 1),
        ]) {
            let c = bsp.continuity
            #expect(c >= 0)
        }
    }
}
