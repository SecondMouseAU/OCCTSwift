import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Oriented Bounding Box Tests (v0.38.0)

@Suite("Oriented Bounding Box")
struct OrientedBoundingBoxTests {

    @Test("OBB of axis-aligned box")
    func obbAlignedBox() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        let obb = box.orientedBoundingBox()
        #expect(obb != nil)
        // OBB volume should be close to box volume (10 * 5 * 3 = 150)
        #expect(abs(obb!.volume - 150.0) < 1.0)
        // Dimensions sorted should be roughly {3, 5, 10}
        let dims = [obb!.dimensions.x, obb!.dimensions.y, obb!.dimensions.z].sorted()
        #expect(abs(dims[0] - 3.0) < 0.1)
        #expect(abs(dims[1] - 5.0) < 0.1)
        #expect(abs(dims[2] - 10.0) < 0.1)
    }

    @Test("OBB of rotated box is tighter than AABB")
    func obbTighterThanAABB() {
        // Rotate a box 45 degrees around Z. AABB will be larger, OBB should stay tight
        let box = Shape.box(width: 10, height: 2, depth: 2)!.rotated(
            axis: SIMD3(0, 0, 1), angle: .pi / 4)!
        let obb = box.orientedBoundingBox()
        #expect(obb != nil)
        // OBB volume should be close to original volume (10 * 2 * 2 = 40)
        #expect(obb!.volume < 60.0)  // Some tolerance
        // AABB would be much larger for a 45° rotated shape
        let aabb = box.bounds!
        let aabbVolume =
            (aabb.max.x - aabb.min.x) * (aabb.max.y - aabb.min.y) * (aabb.max.z - aabb.min.z)
        #expect(obb!.volume < aabbVolume)
    }

    @Test("OBB corners count")
    func obbCorners() {
        let sphere = Shape.sphere(radius: 5)!
        let corners = sphere.orientedBoundingBoxCorners()
        #expect(corners != nil)
        #expect(corners!.count == 8)
    }

    @Test("OBB of sphere")
    func obbSphere() {
        let sphere = Shape.sphere(radius: 5)!
        let obb = sphere.orientedBoundingBox()
        #expect(obb != nil)
        // Sphere OBB should be roughly a cube with side ~10
        let dims = [obb!.dimensions.x, obb!.dimensions.y, obb!.dimensions.z].sorted()
        #expect(dims[0] > 9.0 && dims[0] < 11.0)
    }

    @Test("Optimal OBB")
    func obbOptimal() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        let obb = box.orientedBoundingBox(optimal: true)
        #expect(obb != nil)
        #expect(abs(obb!.volume - 150.0) < 1.0)
    }
}
