import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtElC Line-Line")
struct ExtremaElCLinLinTests {
    /// Two parallel lines have a real gap and no nearest pair.
    ///
    /// No pair of points is the extremum, so OCCT computes none: `Extrema_ExtElC.cxx:341-344`
    /// sets the square distance and the count and leaves `myPoint` default-constructed. Until
    /// #2993 the bridge passed that through as `SIMD3(0, 0, 0)` for both, a pair 0 apart beside
    /// a distance of 5.
    @Test func parallelLines() throws {
        let r = ExtremaElC.lineToLine(
            line1Point: SIMD3(0, 0, 0), line1Dir: SIMD3(1, 0, 0),
            line2Point: SIMD3(0, 5, 0), line2Dir: SIMD3(1, 0, 0)
        )
        #expect(r.isParallel)
        #expect(r.results.count == 1)
        let first = try #require(r.results.first)
        #expect(abs(first.squareDistance - 25) < 1e-9)
        #expect(first.isParallel, "the tuple flag and the result's own flag are the same fact")
        #expect(first.point1 == nil, "point1 is \(String(describing: first.point1))")
        #expect(first.point2 == nil, "point2 is \(String(describing: first.point2))")
    }

    @Test func intersectingLines() throws {
        let r = ExtremaElC.lineToLine(
            line1Point: SIMD3(0, 0, 0), line1Dir: SIMD3(1, 0, 0),
            line2Point: SIMD3(0, 0, 0), line2Dir: SIMD3(0, 1, 0)
        )
        #expect(!r.isParallel)
        let first = try #require(r.results.first)
        #expect(first.squareDistance < 1e-6)
        // Crossing lines have a witness pair, and it is the crossing point on both (#2993).
        #expect(!first.isParallel)
        #expect(simd_length(try #require(first.point1)) < 1e-9)
        #expect(simd_length(try #require(first.point2)) < 1e-9)
    }

    @Test func skewLines() throws {
        let r = ExtremaElC.lineToLine(
            line1Point: SIMD3(0, 0, 0), line1Dir: SIMD3(1, 0, 0),
            line2Point: SIMD3(0, 0, 3), line2Dir: SIMD3(0, 1, 0)
        )
        #expect(!r.isParallel)
        let first = try #require(r.results.first)
        #expect(abs(first.squareDistance - 9) < 1e-9)
        // The common perpendicular runs from the origin straight up to (0, 0, 3), so the pair is
        // present and its own separation is the reported distance (#2993).
        #expect(!first.isParallel)
        let p1 = try #require(first.point1)
        let p2 = try #require(first.point2)
        #expect(abs(simd_distance_squared(p1, p2) - first.squareDistance) < 1e-9)
    }
}
