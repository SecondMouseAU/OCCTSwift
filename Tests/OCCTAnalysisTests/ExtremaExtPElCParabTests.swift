import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtPElC Point-Parabola")
struct ExtremaExtPElCParabTests {
    @Test func pointToParabola() {
        let results = ExtremaPointCurve.pointToParabola(
            point: SIMD3(0, 10, 0),
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), xDir: SIMD3(1, 0, 0),
            focal: 2
        )
        // One extremum, at (3.5286, 5.3131, 0), square distance 34.41825388339705
        // (`Scripts/repro/766-extrema-extcc-pelc-pels/`). `count > 0` passed any distance.
        #expect(results.count == 1)
        if let only = results.first {
            #expect(abs(only.squareDistance - 34.41825388339705) < 1e-9)
            #expect(abs(only.point2.x - 3.52859630587839) < 1e-9)
            #expect(abs(only.point2.y - 5.3130754226744346) < 1e-9)
            #expect(abs(only.point2.z) < 1e-9)
        }
    }
}
