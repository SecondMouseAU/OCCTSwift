import Foundation
import Testing
import simd

@testable import OCCTSwift

// #2941: this pinned `count > 0` where the answer is exactly one, put a 0.1 window on a square
// distance that is exactly 25, and read its only value behind an `if let` that skipped the
// assertion when there was nothing to read. The values are the kernel's own, from
// `Scripts/repro/766-extrema-extcc-pelc-pels/transcript.txt`.
@Suite("Extrema_ExtPElC Point-Line")
struct ExtremaExtPElCLinTests {
    @Test func pointToLine() throws {
        let results = ExtremaPointCurve.pointToLine(
            point: SIMD3(0, 5, 0),
            lineOrigin: SIMD3(0, 0, 0), lineDir: SIMD3(1, 0, 0)
        )
        // A point and a line have exactly one extremum, the foot of the perpendicular.
        #expect(results.count == 1, "expected exactly one extremum, got \(results.count)")
        let first = try #require(results.first)
        #expect(
            abs(first.squareDistance - 25.0) < 1e-9,
            "square distance \(first.squareDistance) != 25")
        // The foot itself, `Extrema_ExtPElC::Point(1)`, which nothing pinned before: the origin,
        // since the query point is directly above it.
        #expect(simd_distance(first.point2, SIMD3(0, 0, 0)) < 1e-9, "foot is \(first.point2)")
        // `point1` is the query point echoed by the bridge rather than a kernel value, so this
        // asserts the pair is not transposed and nothing more.
        #expect(simd_distance(first.point1, SIMD3(0, 5, 0)) < 1e-9, "point1 is \(first.point1)")
    }
}
