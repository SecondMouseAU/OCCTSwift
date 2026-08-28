import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.99.0 Tests

@Suite("Convert_CompBezierCurvesToBSplineCurve Tests")
struct CompBezierToBSplineTests {

    @Test func singleCubicSegment3D() {
        // One cubic Bezier segment: 4 control points
        let seg: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 2, 0), SIMD3(2, 2, 0), SIMD3(3, 0, 0),
        ]
        if let result = CompBezierConverter.toBSpline(segments: [seg]) {
            #expect(result.degree == 3)
            #expect(result.poles.count == 4)
            #expect(result.knots.count >= 2)
            // First pole should match first control point
            #expect(abs(result.poles[0].x) < 1e-10)
            #expect(abs(result.poles[0].y) < 1e-10)
            // Last pole should match last control point
            #expect(abs(result.poles.last!.x - 3.0) < 1e-10)
        }
    }

    @Test func twoCubicSegments3D() {
        // Two C0-connected cubic Bezier segments (second starts where first ends)
        let seg1: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 1, 0), SIMD3(2, 1, 0), SIMD3(3, 0, 0),
        ]
        let seg2: [SIMD3<Double>] = [
            SIMD3(3, 0, 0), SIMD3(4, -1, 0), SIMD3(5, -1, 0), SIMD3(6, 0, 0),
        ]
        if let result = CompBezierConverter.toBSpline(segments: [seg1, seg2]) {
            #expect(result.degree == 3)
            // Two cubic segments joined → at least 4 poles
            #expect(result.poles.count >= 4)
            #expect(result.knots.count >= 2)
        }
    }

    @Test func emptySegmentsReturnsNil() {
        let result = CompBezierConverter.toBSpline(segments: [])
        #expect(result == nil)
    }

    @Test func mismatchedSegmentSizesReturnsNil() {
        let seg1: [SIMD3<Double>] = [SIMD3(0, 0, 0), SIMD3(1, 0, 0)]
        let seg2: [SIMD3<Double>] = [SIMD3(1, 0, 0), SIMD3(2, 0, 0), SIMD3(3, 0, 0)]
        let result = CompBezierConverter.toBSpline(segments: [seg1, seg2])
        #expect(result == nil)
    }
}
