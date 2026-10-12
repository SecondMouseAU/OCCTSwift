import Foundation
import Testing

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

        // A plane that is not a coordinate plane, and the tolerance as the threshold: the plane
        // through (1, 2, 3) with normal (0, 0, 1) is z = 3, so 5e-8 above it is on the plane,
        // 5e-6 above is not, and a wider tolerance takes it back.
        let o = SIMD3(1.0, 2.0, 3.0)
        let n = SIMD3(0.0, 0.0, 1.0)
        #expect(
            PlaneGeometry.containsPoint(
                planeOrigin: o, planeNormal: n, point: SIMD3(-40, 7, 3), tolerance: 1e-7))
        #expect(
            PlaneGeometry.containsPoint(
                planeOrigin: o, planeNormal: n, point: SIMD3(-40, 7, 3 + 5e-8), tolerance: 1e-7))
        #expect(
            !PlaneGeometry.containsPoint(
                planeOrigin: o, planeNormal: n, point: SIMD3(-40, 7, 3 + 5e-6), tolerance: 1e-7))
        #expect(
            PlaneGeometry.containsPoint(
                planeOrigin: o, planeNormal: n, point: SIMD3(-40, 7, 3 + 5e-6), tolerance: 1e-4))
    }

    @Test func containsPointFalse() {
        let r = PlaneGeometry.containsPoint(
            planeOrigin: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1),
            point: SIMD3(0, 0, 1), tolerance: 1e-7)
        #expect(!r)
    }
}
