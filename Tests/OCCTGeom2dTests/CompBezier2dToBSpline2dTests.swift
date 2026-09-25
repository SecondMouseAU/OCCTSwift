import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Convert_CompBezierCurves2dToBSplineCurve2d Tests")
struct CompBezier2dToBSpline2dTests {

    // #1979: both conversions below nested their assertions in `if let result`, so a nil result
    // passed, and the second asserted only `poles.count >= 4`. Pinned to what
    // Convert_CompBezierCurves2dToBSplineCurve2d returns (Scripts/repro/766-geom2d-chfi2d-compbezier/).
    @Test func singleQuadraticSegment2D() throws {
        // One quadratic Bezier segment: 3 control points
        let seg: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(1, 2), SIMD2(2, 0),
        ]
        let result = try #require(CompBezierConverter.toBSpline2d(segments: [seg]))
        #expect(result.degree == 2)
        try #require(result.poles.count == 3)
        #expect(zip(result.poles, seg).allSatisfy { simd_distance($0, $1) < 1e-12 })
        #expect(result.knots == [0, 1])
        #expect(result.multiplicities == [3, 3])
    }

    @Test func twoCubicSegments2D() throws {
        let seg1: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 1), SIMD2(3, 0),
        ]
        let seg2: [SIMD2<Double>] = [
            SIMD2(3, 0), SIMD2(4, -1), SIMD2(5, -1), SIMD2(6, 0),
        ]
        let result = try #require(CompBezierConverter.toBSpline2d(segments: [seg1, seg2]))
        // The segments are tangent-continuous at (3, 0), so the junction knot keeps
        // multiplicity 2 and the shared pole (3, 0) is dropped: six poles, not seven.
        #expect(result.degree == 3)
        let expected: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 1), SIMD2(4, -1), SIMD2(5, -1), SIMD2(6, 0),
        ]
        try #require(result.poles.count == 6)
        #expect(zip(result.poles, expected).allSatisfy { simd_distance($0, $1) < 1e-12 })
        try #require(result.knots.count == 3)
        #expect(abs(result.knots[1] - 0.5) < 1e-12)
        #expect(result.multiplicities == [4, 2, 4])
    }

    @Test func emptySegmentsReturnsNil2D() {
        let result = CompBezierConverter.toBSpline2d(segments: [])
        #expect(result == nil)
    }

    @Test func manySegmentsExceedingCapacityReturnsNil2D() {
        // Same overflow shape as the 3D converter's test (#1441): 60 chained cubic segments
        // grow past the fixed 100-pole/200-double and 50-knot/mult buffers regardless of
        // per-junction tangent smoothing, and the bridge must reject rather than report an
        // unclamped count against a buffer holding only a truncated prefix.
        var segments: [[SIMD2<Double>]] = []
        for i in 0..<60 {
            let x = Double(i) * 3
            segments.append([
                SIMD2(x, 0), SIMD2(x + 1, 1), SIMD2(x + 2, -1), SIMD2(x + 3, 0),
            ])
        }
        let result = CompBezierConverter.toBSpline2d(segments: segments)
        #expect(result == nil)
    }
}
