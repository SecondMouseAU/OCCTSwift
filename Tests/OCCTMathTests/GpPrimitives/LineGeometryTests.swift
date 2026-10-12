import Foundation
import Testing

@testable import OCCTSwift

@Suite("LineGeometry_Operations")
struct LineGeometryTests {
    @Test func distanceToPointOnLine() {
        let d = LineGeometry.distanceToPoint(
            linePoint: SIMD3(0, 0, 0), lineDirection: SIMD3(1, 0, 0),
            point: SIMD3(5, 0, 0))
        #expect(abs(d) < 1e-10)
    }

    @Test func distanceToPointOffLine() {
        let d = LineGeometry.distanceToPoint(
            linePoint: SIMD3(0, 0, 0), lineDirection: SIMD3(1, 0, 0),
            point: SIMD3(5, 3, 0))
        #expect(abs(d - 3.0) < 1e-10)
    }

    @Test func distanceBetweenParallelLines() {
        let d = LineGeometry.distanceToLine(
            line1Point: SIMD3(0, 0, 0), line1Direction: SIMD3(1, 0, 0),
            line2Point: SIMD3(0, 4, 0), line2Direction: SIMD3(1, 0, 0))
        #expect(abs(d - 4.0) < 1e-10)
    }

    @Test func distanceBetweenIntersectingLines() {
        let d = LineGeometry.distanceToLine(
            line1Point: SIMD3(0, 0, 0), line1Direction: SIMD3(1, 0, 0),
            line2Point: SIMD3(0, 0, 0), line2Direction: SIMD3(0, 1, 0))
        #expect(abs(d) < 1e-10)
    }

    @Test func containsPointTrue() {
        let r = LineGeometry.containsPoint(
            linePoint: SIMD3(0, 0, 0), lineDirection: SIMD3(1, 0, 0),
            point: SIMD3(100, 0, 0), tolerance: 1e-7)
        #expect(r)

        // Off the axes, so a test of "is it on the x axis" cannot stand in: the line through
        // (1, 2, 3) along (1, 1, 0) holds (11, 12, 3), and the tolerance is the threshold, not
        // a constant answer: 5e-8 off is on the line, 5e-6 off is not.
        let p = SIMD3(1.0, 2.0, 3.0)
        let d = SIMD3(1.0, 1.0, 0.0)
        #expect(
            LineGeometry.containsPoint(
                linePoint: p, lineDirection: d, point: SIMD3(11, 12, 3), tolerance: 1e-7))
        #expect(
            LineGeometry.containsPoint(
                linePoint: p, lineDirection: d, point: SIMD3(11, 12, 3 + 5e-8), tolerance: 1e-7))
        #expect(
            !LineGeometry.containsPoint(
                linePoint: p, lineDirection: d, point: SIMD3(11, 12, 3 + 5e-6), tolerance: 1e-7))
        #expect(
            LineGeometry.containsPoint(
                linePoint: p, lineDirection: d, point: SIMD3(11, 12, 3 + 5e-6), tolerance: 1e-4))
    }

    @Test func containsPointFalse() {
        let r = LineGeometry.containsPoint(
            linePoint: SIMD3(0, 0, 0), lineDirection: SIMD3(1, 0, 0),
            point: SIMD3(0, 1, 0), tolerance: 1e-7)
        #expect(!r)
    }
}
