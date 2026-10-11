import Foundation
import Testing

@testable import OCCTSwift

@Suite("Extrema_ExtPElS Point-Sphere")
struct ExtremaExtPElSSphereTests {
    @Test func pointToSphere() throws {
        let results = ExtremaPointSurface.pointToSphere(
            point: SIMD3(20, 0, 0),
            center: SIMD3(0, 0, 0), radius: 5
        )
        // Two extrema on the X axis: (5, 0, 0) at square distance 225 and (-5, 0, 0) at 625
        // (`Scripts/repro/766-extrema-extcc-pelc-pels/`). `count > 0` passed any distance.
        #expect(results.count == 2)
        let sq = results.map(\.squareDistance).sorted()
        if sq.count == 2 {
            #expect(abs(sq[0] - 225) < 1e-9)
            #expect(abs(sq[1] - 625) < 1e-9)
        }
        let near = try #require(results.min(by: { $0.squareDistance < $1.squareDistance }))
        // `Extrema_ExtPElS` has no parallel branch, so #2993's `nil` witness never appears here.
        #expect(!near.isParallel)
        let p = try #require(near.point2, "a point-sphere extremum has a witness point")
        #expect(abs(p.x - 5) < 1e-9)
        #expect(abs(p.y) < 1e-9)
    }
}
