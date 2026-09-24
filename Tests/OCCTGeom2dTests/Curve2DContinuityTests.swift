import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: both tests asserted `continuity >= 0` inside `if let`, which every GeomAbs_Shape value and
// a nil curve satisfy. Pinned to what Geom2d_Curve::Continuity() reports
// (Scripts/repro/766-geom2d-continuity-convert/).
@Suite("Curve2D Continuity Tests")
struct Curve2DContinuityTests {
    @Test func line2DContinuity() throws {
        // A line is analytic: GeomAbs_CN, raw value 6.
        let line = try #require(Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)))
        #expect(line.continuity == 6)
    }

    @Test func bspline2DContinuity() throws {
        // A cubic interpolant with simple interior knots is C2: GeomAbs_C2, raw value 4.
        let bsp = try #require(
            Curve2D.interpolate(through: [
                SIMD2(0, 0), SIMD2(1, 1),
                SIMD2(2, 0), SIMD2(3, 1),
            ]))
        #expect(bsp.continuity == 4)
    }
}
