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
        guard let result = CompBezierConverter.toBSpline(segments: [seg]) else {
            Issue.record("single cubic segment did not convert")
            return
        }
        // Convert_CompBezierCurvesToBSplineCurve keeps a lone cubic as is: its own four poles,
        // knots [0, 1] at multiplicity 4 (Scripts/repro/766-curve-circle-compbezier/transcript.txt).
        #expect(result.degree == 3)
        #expect(result.poles == seg)
        #expect(result.knots == [0, 1])
        #expect(result.multiplicities == [4, 4])
    }

    @Test func twoCubicSegments3D() {
        // Two C0-connected cubic Bezier segments (second starts where first ends)
        let seg1: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(1, 1, 0), SIMD3(2, 1, 0), SIMD3(3, 0, 0),
        ]
        let seg2: [SIMD3<Double>] = [
            SIMD3(3, 0, 0), SIMD3(4, -1, 0), SIMD3(5, -1, 0), SIMD3(6, 0, 0),
        ]
        guard let result = CompBezierConverter.toBSpline(segments: [seg1, seg2]) else {
            Issue.record("two cubic segments did not convert")
            return
        }
        // The shared junction pole is merged: 6 poles, knots [0, 0.5, 1] with multiplicities
        // [4, 2, 4]. The earlier `poles.count >= 4` passed a result that dropped a segment (#766).
        #expect(result.degree == 3)
        #expect(
            result.poles == [
                SIMD3(0, 0, 0), SIMD3(1, 1, 0), SIMD3(2, 1, 0),
                SIMD3(4, -1, 0), SIMD3(5, -1, 0), SIMD3(6, 0, 0),
            ])
        #expect(result.knots == [0, 0.5, 1])
        #expect(result.multiplicities == [4, 2, 4])
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

    @Test func manySegmentsExceedingCapacityReturnsNil() {
        // 60 chained cubic segments grow the composite curve's pole count to at least
        // 2*60+2 = 122 (over the fixed 100-pole/300-double buffer) and its knot count to
        // exactly 60+1 = 61 (over the fixed 50-knot/mult buffer), regardless of how the
        // junction-tangent smoothing inside Perform() classifies each junction. The bridge
        // must reject this rather than report an unclamped nbPoles/nbKnots against a buffer
        // that only ever holds a truncated prefix (#1441).
        var segments: [[SIMD3<Double>]] = []
        for i in 0..<60 {
            let x = Double(i) * 3
            segments.append([
                SIMD3(x, 0, 0), SIMD3(x + 1, 1, 0), SIMD3(x + 2, -1, 0), SIMD3(x + 3, 0, 0),
            ])
        }
        let result = CompBezierConverter.toBSpline(segments: segments)
        #expect(result == nil)
    }
}
