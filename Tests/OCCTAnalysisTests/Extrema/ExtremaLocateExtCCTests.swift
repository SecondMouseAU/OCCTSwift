import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_LocateExtCC Tests")
struct ExtremaLocateExtCCTests {
    @Test func localExtremum() {
        if let circ = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5.0),
            let line = Curve3D.line(through: SIMD3(10, 0, 3), direction: SIMD3(0, 1, 0))
        {
            let result = circ.locateExtremaCC(
                range1: 0...(.pi * 2), other: line,
                range2: -10...10, seedU: 0, seedV: 0)
            #expect(result.isDone)
            if result.isDone {
                let dist = result.squareDistance.squareRoot()
                #expect(dist > 0)
            }
        }
    }
}
