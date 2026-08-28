import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtPElC Point-Line")
struct ExtremaExtPElCLinTests {
    @Test func pointToLine() {
        let results = ExtremaPointCurve.pointToLine(
            point: SIMD3(0, 5, 0),
            lineOrigin: SIMD3(0, 0, 0), lineDir: SIMD3(1, 0, 0)
        )
        #expect(results.count > 0)
        if let first = results.first {
            #expect(abs(first.squareDistance - 25) < 0.1)
        }
    }
}
