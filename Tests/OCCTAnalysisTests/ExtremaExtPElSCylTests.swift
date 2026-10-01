import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtPElS Point-Cylinder")
struct ExtremaExtPElSCylTests {
    @Test func pointToCylinder() {
        let results = ExtremaPointSurface.pointToCylinder(
            point: SIMD3(20, 0, 0),
            center: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5
        )
        // Two extrema on the X axis: (5, 0, 0) at square distance 225 and (-5, 0, 0) at 625
        // (`Scripts/repro/766-extrema-extcc-pelc-pels/`). `count > 0` passed any distance.
        #expect(results.count == 2)
        let sq = results.map(\.squareDistance).sorted()
        if sq.count == 2 {
            #expect(abs(sq[0] - 225) < 1e-9)
            #expect(abs(sq[1] - 625) < 1e-9)
        }
        if let near = results.min(by: { $0.squareDistance < $1.squareDistance }) {
            #expect(abs(near.point2.x - 5) < 1e-9)
            #expect(abs(near.point2.y) < 1e-9)
        }
    }
}
