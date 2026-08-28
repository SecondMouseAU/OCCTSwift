import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtCC Tests")
struct ExtremaExtCCTests {
    @Test func curveCurveDistance() {
        // Two perpendicular lines at distance 5
        if let line1 = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)),
            let line2 = Curve3D.line(through: SIMD3(0, 5, 0), direction: SIMD3(0, 0, 1))
        {
            let result = line1.extremaCC(range1: -10...10, other: line2, range2: -10...10)
            #expect(result.isDone)
            #expect(result.count >= 1)
            if result.count >= 1 {
                let pp = line1.extremaCCPoint(
                    range1: -10...10, other: line2, range2: -10...10, index: 1)
                let dist = pp.squareDistance.squareRoot()
                #expect(abs(dist - 5.0) < 1e-3)
            }
        }
    }

    @Test func parallelCurves() {
        if let line1 = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)),
            let line2 = Curve3D.line(through: SIMD3(0, 3, 0), direction: SIMD3(1, 0, 0))
        {
            let result = line1.extremaCC(range1: -10...10, other: line2, range2: -10...10)
            #expect(result.isDone)
            #expect(result.isParallel)
        }
    }
}
