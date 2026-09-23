import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtPElS Point-Torus")
struct ExtremaExtPElSTorusTests {
    @Test func pointToTorus() {
        let results = ExtremaPointSurface.pointToTorus(
            point: SIMD3(20, 0, 0),
            center: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1),
            majorRadius: 10, minorRadius: 3
        )
        // Four extrema on the X axis, at x = 13, 7, -7, -13: square distances 49, 169, 729,
        // 1089 (`Scripts/repro/766-extrema-extcc-pelc-pels/`). `count > 0` passed any distance.
        #expect(results.count == 4)
        let sq = results.map(\.squareDistance).sorted()
        let expected: [Double] = [49, 169, 729, 1089]
        if sq.count == expected.count {
            for (a, b) in zip(sq, expected) { #expect(abs(a - b) < 1e-9) }
        }
        if let near = results.min(by: { $0.squareDistance < $1.squareDistance }) {
            #expect(abs(near.point2.x - 13) < 1e-9)
        }
    }
}
