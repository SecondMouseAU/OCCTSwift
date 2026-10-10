import Foundation
import Testing

@testable import OCCTSwift

@Suite("Extrema_ExtPElC Point-Parabola")
struct ExtremaExtPElCParabTests {
    @Test func pointToParabola() throws {
        let results = ExtremaPointCurve.pointToParabola(
            point: SIMD3(0, 10, 0),
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), xDir: SIMD3(1, 0, 0),
            focal: 2
        )
        // One extremum, at (3.5286, 5.3131, 0), square distance 34.41825388339705
        // (`Scripts/repro/766-extrema-extcc-pelc-pels/`). `count > 0` passed any distance.
        #expect(results.count == 1)
        let only = try #require(results.first)
        #expect(abs(only.squareDistance - 34.41825388339705) < 1e-9)
        // `Extrema_ExtPElC` has no parallel branch, so #2993's `nil` witness never appears here.
        #expect(!only.isParallel)
        let p = try #require(only.point2, "a point-parabola extremum has a witness point")
        #expect(abs(p.x - 3.52859630587839) < 1e-9)
        #expect(abs(p.y - 5.3130754226744346) < 1e-9)
        #expect(abs(p.z) < 1e-9)
    }
}
