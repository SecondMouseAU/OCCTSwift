import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtElC Line-Line")
struct ExtremaElCLinLinTests {
    @Test func parallelLines() {
        let r = ExtremaElC.lineToLine(
            line1Point: SIMD3(0, 0, 0), line1Dir: SIMD3(1, 0, 0),
            line2Point: SIMD3(0, 5, 0), line2Dir: SIMD3(1, 0, 0)
        )
        #expect(r.isParallel)
        #expect(r.results.count > 0)
        if let first = r.results.first {
            #expect(abs(first.squareDistance - 25) < 0.1)
        }
    }

    @Test func intersectingLines() {
        let r = ExtremaElC.lineToLine(
            line1Point: SIMD3(0, 0, 0), line1Dir: SIMD3(1, 0, 0),
            line2Point: SIMD3(0, 0, 0), line2Dir: SIMD3(0, 1, 0)
        )
        #expect(!r.isParallel)
        if let first = r.results.first {
            #expect(first.squareDistance < 1e-6)
        }
    }

    @Test func skewLines() {
        let r = ExtremaElC.lineToLine(
            line1Point: SIMD3(0, 0, 0), line1Dir: SIMD3(1, 0, 0),
            line2Point: SIMD3(0, 0, 3), line2Dir: SIMD3(0, 1, 0)
        )
        #expect(!r.isParallel)
        if let first = r.results.first {
            #expect(abs(first.squareDistance - 9) < 0.1)
        }
    }
}
