import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtPElC Point-Circle")
struct ExtremaExtPElCCircTests {
    @Test func pointToCircle() {
        let results = ExtremaPointCurve.pointToCircle(
            point: SIMD3(10, 0, 0),
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5
        )
        // `count > 0` accepted any extremum at all, including one at the wrong place.
        // Extrema_ExtPElC's answer, measured by Scripts/repro/766-extrema-extpelc-circ/probe.mm:
        // the near point (5, 0, 0) at squared distance 25 and the far point (-5, 0, 0) at 225
        // (#1704).
        #expect(results.count == 2)
        let near = results.first { abs($0.squareDistance - 25) < 1e-9 }
        let far = results.first { abs($0.squareDistance - 225) < 1e-9 }
        #expect(near != nil)
        #expect(far != nil)
        if let near {
            #expect(simd_distance(near.point1, SIMD3(10, 0, 0)) < 1e-9)
            #expect(simd_distance(near.point2, SIMD3(5, 0, 0)) < 1e-9)
        }
        if let far {
            #expect(simd_distance(far.point2, SIMD3(-5, 0, 0)) < 1e-9)
        }
    }

    @Test func pointOnCircle() {
        let results = ExtremaPointCurve.pointToCircle(
            point: SIMD3(5, 0, 0),
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5
        )
        #expect(results.count > 0)
        if let first = results.first {
            #expect(first.squareDistance < 1e-6)
        }
    }
}
