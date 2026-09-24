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

    // #766: this checked only the overlapping pair, so an `isOut` that answered `false` for
    // every input passed. The disjoint partner at x = 20 is the other polarity.
    @Test func obbOverlap() {
        let obb1 = OBB(
            center: SIMD3(0, 0, 0), xDir: SIMD3(1, 0, 0), yDir: SIMD3(0, 1, 0),
            zDir: SIMD3(0, 0, 1),
            hx: 5, hy: 5, hz: 5)
        let obb2 = OBB(
            center: SIMD3(4, 0, 0), xDir: SIMD3(1, 0, 0), yDir: SIMD3(0, 1, 0),
            zDir: SIMD3(0, 0, 1),
            hx: 3, hy: 3, hz: 3)
        let disjoint = OBB(
            center: SIMD3(20, 0, 0), xDir: SIMD3(1, 0, 0), yDir: SIMD3(0, 1, 0),
            zDir: SIMD3(0, 0, 1),
            hx: 3, hy: 3, hz: 3)
        #expect(!obb1.isOut(obb2))
        #expect(obb1.isOut(disjoint))
    }

    // #766: this asserted `squareExtent > 0`, which any non-void box satisfies, and returned
    // silently if the fixture failed. Probed in Scripts/repro/766-bndobb: `BRepBndLib::Add` on
    // the centred 10-cube widens each side by the 1e-7 tolerance, and `Bnd_OBB(Bnd_Box)` gives a
    // centre at the origin, three half-sizes of 5.0000001 and a SquareExtent (the squared full
    // diagonal, 4 * (hx^2 + hy^2 + hz^2)) of 300.000012.
    @Test func fromShape() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let obb = try #require(OBB.fromShape(box), "should create OBB from shape")
        #expect(!obb.isVoid)
        #expect(simd_length(obb.center) < 1e-12)
        #expect(abs(obb.halfSizes.x - 5.0000001) < 1e-12)
        #expect(abs(obb.halfSizes.y - 5.0000001) < 1e-12)
        #expect(abs(obb.halfSizes.z - 5.0000001) < 1e-12)
        #expect(abs(obb.squareExtent - 300.000012) < 1e-9)
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
