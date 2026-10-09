import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.71.0: TKBool remainder + TKFeat

// #2943: both tests here used to sit inside an `if let` chain with no `else`, so a nil face, a nil
// edge or a nil result ran no assertion at all, and what they did assert could not fail:
// `minSquareDistance >= 0.0` is true of the `RealLast()` sentinel the kernel actually returns, and
// `ranges.count >= 1` with `last >= first` is true of the zero-length `[0, 0]` the bridge was
// handing back for an edge lying in the face.
//
// PR #2942 bound the fixtures with `try #require` first and pinned what the bridge then did: no
// range at all for the crossing edge, one range of unasserted length for the edge in the face.
// Both were the defect's output rather than the kernel's answer about these edges, which is what
// #2943 was filed to settle. Every value below is the kernel's own, measured in
// `Scripts/repro/2943-beanface-bean-parameters/`.
@Suite("IntTools_BeanFaceIntersector Tests")
struct IntToolsBeanFaceIntersectorTests {
    /// The `u, v` in `[-10, 10]` plane face at the origin with normal `+Z`, which all three tests
    /// intersect against.
    private func planeFace() throws -> Shape {
        let plane = try #require(Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)))
        return try #require(Shape.face(from: plane, uRange: -10...10, vRange: -10...10))
    }

    @Test("edge crossing face")
    func edgeCrossingFace() throws {
        let face = try planeFace()
        // Parameterised by arc length from (0, 0, -5), so the edge spans [0, 10] and pierces the
        // plane at 5.
        let edge = try #require(Shape.edgeFromPoints(SIMD3(0, 0, -5), SIMD3(0, 0, 5)))
        let result = try #require(Shape.beanFaceIntersect(edge: edge, face: face))

        // One range, a confusion-wide band around the single piercing point. Before #2943 the
        // bridge searched the empty interval [0, 0] and found no range at all here, which #2942
        // pinned as `ranges.isEmpty`: that was the empty search reported back, not an answer
        // about this edge.
        #expect(result.ranges.count == 1)
        let hit = try #require(result.ranges.first)
        #expect(abs(hit.first - 5.0) < 1e-4, "range start \(hit.first) is not the piercing point")
        #expect(abs(hit.last - 5.0) < 1e-4, "range end \(hit.last) is not the piercing point")
        #expect(hit.last > hit.first, "a piercing point should give a non-degenerate band")
        #expect(
            hit.last - hit.first < 1e-3, "the band should be confusion-wide, not the whole edge")

        // The kernel evaluates no distance on this path and leaves its minimum at RealLast(); the
        // bridge reports that as "not measured" rather than handing 1.797e308 back as a number.
        #expect(result.minSquareDistance == nil)
    }

    @Test("edge lying on face - coincident ranges")
    func edgeOnFace() throws {
        let face = try planeFace()
        // Arc length from (-3, 0, 0), so the edge spans [0, 6] and all of it lies in the plane.
        let edge = try #require(Shape.edgeFromPoints(SIMD3(-3, 0, 0), SIMD3(3, 0, 0)))
        let result = try #require(Shape.beanFaceIntersect(edge: edge, face: face))

        // The whole edge is coincident, so the one range is the edge's whole parameter span.
        // `[0, 0]` is what this returned before #2943, and it is the length that distinguishes
        // them: pinning only the count, or only `last >= first`, accepts both.
        #expect(result.ranges.count == 1)
        let r = try #require(result.ranges.first)
        #expect(
            abs(r.first - 0.0) < 1e-9, "range start \(r.first) is not the edge's first parameter")
        #expect(abs(r.last - 6.0) < 1e-9, "range end \(r.last) is not the edge's last parameter")
        #expect(result.minSquareDistance == nil)
    }

    @Test("edge parallel to the face but clear of it finds nothing")
    func edgeOffFace() throws {
        // The control for the two above: setting the bean parameters makes the kernel search the
        // whole edge, and this test is what says it still answers "no coincidence" when there is
        // none, rather than reporting a range for every input.
        let face = try planeFace()
        let edge = try #require(Shape.edgeFromPoints(SIMD3(-3, 0, 4), SIMD3(3, 0, 4)))
        let result = try #require(Shape.beanFaceIntersect(edge: edge, face: face))
        #expect(result.ranges.isEmpty)
        #expect(result.minSquareDistance == nil)
    }
}
