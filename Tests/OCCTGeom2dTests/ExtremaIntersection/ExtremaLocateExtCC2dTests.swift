import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_LocateExtCC2d Tests")
struct ExtremaLocateExtCC2dTests {
    @Test func localExtremum2d() {
        if let circ = Curve2D.circleFromCenterRadius(center: SIMD2(0, 0), radius: 5.0),
            let line = Curve2D.lineFrom2Points(SIMD2(10, -10), SIMD2(10, 10))
        {
            let result = circ.locateExtremaCC(
                range1: 0...(.pi * 2), other: line,
                range2: -10...10, seedU: 0, seedV: 0)
            #expect(result.isDone)
            if result.isDone {
                let dist = result.squareDistance.squareRoot()
                #expect(abs(dist - 5.0) < 0.5)
            }
        }
    }
}
