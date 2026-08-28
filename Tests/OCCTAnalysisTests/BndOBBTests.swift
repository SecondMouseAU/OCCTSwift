import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Bnd OBB Tests")
struct BndOBBTests {

    @Test func createAndQuery() {
        let obb = OBB(
            center: SIMD3(0, 0, 0), xDir: SIMD3(1, 0, 0), yDir: SIMD3(0, 1, 0),
            zDir: SIMD3(0, 0, 1),
            hx: 5, hy: 3, hz: 2)
        #expect(!obb.isVoid)
        #expect(abs(obb.center.x) < 1e-10)
        #expect(abs(obb.halfSizes.x - 5.0) < 1e-10)
    }

    @Test func pointInOut() {
        let obb = OBB(
            center: SIMD3(0, 0, 0), xDir: SIMD3(1, 0, 0), yDir: SIMD3(0, 1, 0),
            zDir: SIMD3(0, 0, 1),
            hx: 5, hy: 5, hz: 5)
        #expect(!obb.isOut(point: SIMD3(1, 1, 1)))
        #expect(obb.isOut(point: SIMD3(10, 10, 10)))
    }

    @Test func obbOverlap() {
        let obb1 = OBB(
            center: SIMD3(0, 0, 0), xDir: SIMD3(1, 0, 0), yDir: SIMD3(0, 1, 0),
            zDir: SIMD3(0, 0, 1),
            hx: 5, hy: 5, hz: 5)
        let obb2 = OBB(
            center: SIMD3(4, 0, 0), xDir: SIMD3(1, 0, 0), yDir: SIMD3(0, 1, 0),
            zDir: SIMD3(0, 0, 1),
            hx: 3, hy: 3, hz: 3)
        #expect(!obb1.isOut(obb2))
    }

    @Test func fromShape() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        guard let obb = OBB.fromShape(box) else {
            #expect(Bool(false), "should create OBB from shape")
            return
        }
        #expect(!obb.isVoid)
        #expect(obb.squareExtent > 0)
    }

    @Test func enlarge() {
        let obb = OBB(
            center: SIMD3(0, 0, 0), xDir: SIMD3(1, 0, 0), yDir: SIMD3(0, 1, 0),
            zDir: SIMD3(0, 0, 1),
            hx: 1, hy: 1, hz: 1)
        obb.enlarge(by: 2.0)
        #expect(abs(obb.halfSizes.x - 3.0) < 1e-10)
    }
}
