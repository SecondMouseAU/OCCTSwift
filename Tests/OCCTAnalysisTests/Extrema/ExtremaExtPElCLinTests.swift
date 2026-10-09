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
        // since the query point is directly above it. Required rather than optional-chained:
        // since #2993 a witness point is `nil` on a parallel branch, and `Extrema_ExtPElC` has
        // none, so a `nil` here would be a real failure rather than a case to skip.
        #expect(!first.isParallel)
        let foot = try #require(first.point2, "a point-line extremum has a foot")
        #expect(simd_distance(foot, SIMD3(0, 0, 0)) < 1e-9, "foot is \(foot)")
        // `point1` is the query point echoed by the bridge rather than a kernel value, so this
        // asserts the pair is not transposed and nothing more.
        let query = try #require(first.point1)
        #expect(simd_distance(query, SIMD3(0, 5, 0)) < 1e-9, "point1 is \(query)")
    }
}
