import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Convert_CompBezierCurves2dToBSplineCurve2d Tests")
struct CompBezier2dToBSpline2dTests {

    @Test func singleQuadraticSegment2D() {
        // One quadratic Bezier segment: 3 control points
        let seg: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(1, 2), SIMD2(2, 0),
        ]
        if let result = CompBezierConverter.toBSpline2d(segments: [seg]) {
            #expect(result.degree == 2)
            #expect(result.poles.count == 3)
            #expect(result.knots.count >= 2)
            #expect(abs(result.poles[0].x) < 1e-10)
            #expect(abs(result.poles[0].y) < 1e-10)
            #expect(abs(result.poles.last!.x - 2.0) < 1e-10)
        }
    }

    @Test func twoCubicSegments2D() {
        let seg1: [SIMD2<Double>] = [
            SIMD2(0, 0), SIMD2(1, 1), SIMD2(2, 1), SIMD2(3, 0),
        ]
        let seg2: [SIMD2<Double>] = [
            SIMD2(3, 0), SIMD2(4, -1), SIMD2(5, -1), SIMD2(6, 0),
        ]
        if let result = CompBezierConverter.toBSpline2d(segments: [seg1, seg2]) {
            #expect(result.degree == 3)
            #expect(result.poles.count >= 4)
        }
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
