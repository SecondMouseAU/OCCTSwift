import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_LocateExtCC2d Tests")
struct ExtremaLocateExtCC2dTests {
    @Test func localExtremum2d() throws {
        // #1979: nested in `if let` with 0.5 of slack. Extrema_LocateExtCC2d from seed (0, 0)
        // finds (5, 0) on the circle and (10, 0) on the line, exactly 5 apart
        // (Scripts/repro/766-geom2d-extrema-fillet2d/).
        let circ = try #require(Curve2D.circleFromCenterRadius(center: SIMD2(0, 0), radius: 5.0))
        let line = try #require(Curve2D.lineFrom2Points(SIMD2(10, -10), SIMD2(10, 10)))
        let result = circ.locateExtremaCC(
            range1: 0...(.pi * 2), other: line,
            range2: -10...10, seedU: 0, seedV: 0)
        #expect(result.isDone)
        #expect(abs(result.squareDistance.squareRoot() - 5.0) < 1e-9)
    }
}
