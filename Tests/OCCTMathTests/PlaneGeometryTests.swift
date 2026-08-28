import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("PlaneGeometry_Operations")
struct PlaneGeometryTests {
    @Test func distanceToPointOnPlane() {
        let d = PlaneGeometry.distanceToPoint(
            planeOrigin: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1),
            point: SIMD3(5, 5, 0))
        #expect(abs(d) < 1e-10)
    }

    @Test func distanceToPointAbovePlane() {
        let d = PlaneGeometry.distanceToPoint(
            planeOrigin: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1),
            point: SIMD3(0, 0, 7))
        #expect(abs(d - 7.0) < 1e-10)
    }

    @Test func distanceToParallelLine() {
        let d = PlaneGeometry.distanceToLine(
            planeOrigin: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1),
            linePoint: SIMD3(0, 0, 5), lineDirection: SIMD3(1, 0, 0))
        #expect(abs(d - 5.0) < 1e-10)
    }

    @Test func distanceToIntersectingLine() {
        let d = PlaneGeometry.distanceToLine(
            planeOrigin: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1),
            linePoint: SIMD3(0, 0, 5), lineDirection: SIMD3(0, 0, 1))
        #expect(abs(d) < 1e-10)
    }

    @Test func containsPointTrue() {
        let r = PlaneGeometry.containsPoint(
            planeOrigin: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1),
            point: SIMD3(100, 200, 0), tolerance: 1e-7)
        #expect(r)
    }

    @Test func containsPointFalse() {
        let r = PlaneGeometry.containsPoint(
            planeOrigin: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1),
            point: SIMD3(0, 0, 1), tolerance: 1e-7)
        #expect(!r)
    }
}

