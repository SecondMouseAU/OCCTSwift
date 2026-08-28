import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BndLib Extra Tests")
struct BndLibExtraTests {

    @Test func ellipseBounds() {
        let b = BndLib.ellipse(
            center: .zero, normal: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0),
            majorRadius: 10, minorRadius: 5)
        #expect(abs(b.min.x + 10) < 0.1)
        #expect(abs(b.max.x - 10) < 0.1)
        #expect(abs(b.min.y + 5) < 0.1)
        #expect(abs(b.max.y - 5) < 0.1)
    }

    @Test func coneBounds() {
        let b = BndLib.cone(
            center: .zero, axis: SIMD3(0, 0, 1),
            semiAngle: .pi / 6, refRadius: 5, vmin: 0, vmax: 10)
        #expect(b.max.z >= b.min.z)
    }

    @Test func circleArcBounds() {
        let b = BndLib.circleArc(
            center: .zero, normal: SIMD3(0, 0, 1),
            radius: 5, u1: 0, u2: .pi / 2)
        #expect(b.max.x >= b.min.x)
        #expect(b.max.y >= b.min.y)
    }

    @Test func ellipseArcBounds() {
        let b = BndLib.ellipseArc(
            center: .zero, normal: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0),
            majorRadius: 10, minorRadius: 5, u1: 0, u2: .pi / 2)
        #expect(b.max.x >= b.min.x)
    }

    @Test func parabolaArcBounds() {
        let b = BndLib.parabolaArc(
            center: .zero, normal: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0),
            focalDistance: 2, u1: -1, u2: 1)
        #expect(b.max.x >= b.min.x)
    }

    @Test func hyperbolaArcBounds() {
        let b = BndLib.hyperbolaArc(
            center: .zero, normal: SIMD3(0, 0, 1), xDirection: SIMD3(1, 0, 0),
            majorRadius: 5, minorRadius: 3, u1: -1, u2: 1)
        #expect(b.max.x >= b.min.x)
    }
}
