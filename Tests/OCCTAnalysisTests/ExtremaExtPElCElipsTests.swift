import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtPElC Point-Ellipse")
struct ExtremaExtPElCElipsTests {
    // #1767: this asserted only `results.count > 0`, which a bridge reporting one wrong extremum, or
    // the right count at the wrong distances, passed. From (10, 0, 0) on the major axis of the
    // a = 5, b = 3 ellipse there are exactly two extrema, the two vertices on that axis, measured in
    // Scripts/repro/766-extrema-extpelc-elips/transcript.txt.
    @Test func pointToEllipse() {
        let results = ExtremaPointCurve.pointToEllipse(
            point: SIMD3(10, 0, 0),
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), xDir: SIMD3(1, 0, 0),
            majorRadius: 5, minorRadius: 3
        )
        #expect(results.count == 2)
        let sorted = results.sorted { $0.squareDistance < $1.squareDistance }
        if sorted.count == 2 {
            // Nearest: the near vertex (5, 0, 0), distance 5.
            #expect(abs(sorted[0].squareDistance - 25) < 1e-9)
            #expect(simd_length(sorted[0].point2 - SIMD3(5, 0, 0)) < 1e-9)
            // Farthest: the far vertex (-5, 0, 0), distance 15.
            #expect(abs(sorted[1].squareDistance - 225) < 1e-9)
            #expect(simd_length(sorted[1].point2 - SIMD3(-5, 0, 0)) < 1e-9)
            // point1 is the query point on every result.
            #expect(simd_length(sorted[0].point1 - SIMD3(10, 0, 0)) < 1e-12)
        }
    }
}
