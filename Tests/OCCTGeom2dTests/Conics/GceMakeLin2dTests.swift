import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: `upperBound > lowerBound` inside `if let` passed any line and a nil one.
@Suite("gce_MakeLin2d Tests")
struct GceMakeLin2dTests {
    @Test func lineFrom2Points() throws {
        let line = try #require(Curve2D.lineFrom2Points(SIMD2(0, 0), SIMD2(1, 0)))
        #expect(simd_distance(line.point(at: 0), SIMD2(0, 0)) < 1e-12)
        #expect(simd_distance(line.point(at: 3), SIMD2(3, 0)) < 1e-12)
    }

    @Test func lineFromEquation() throws {
        // x - 5 = 0: the vertical line x = 5, from (5, 0) upward.
        let line = try #require(Curve2D.lineFromEquation(a: 1, b: 0, c: -5))
        #expect(simd_distance(line.point(at: 0), SIMD2(5, 0)) < 1e-12)
        #expect(simd_distance(line.point(at: 3), SIMD2(5, 3)) < 1e-12)
    }
}
