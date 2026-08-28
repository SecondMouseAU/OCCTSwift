import Foundation
import Testing
import simd

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
    }

    @Test func containsPointFalse() {
        let r = LineGeometry.containsPoint(
            linePoint: SIMD3(0, 0, 0), lineDirection: SIMD3(1, 0, 0),
            point: SIMD3(0, 1, 0), tolerance: 1e-7)
        #expect(!r)
    }
}

