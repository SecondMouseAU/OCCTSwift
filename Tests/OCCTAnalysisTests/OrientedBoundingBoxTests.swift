import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Oriented Bounding Box Tests (v0.38.0)

// Expected values are BRepBndLib::AddOBB's on the same shapes; see
// Scripts/repro/766-obb-point-classification/transcript.txt. Every half-size carries OCCT's 1e-7
// enlargement, so a 10x5x3 box's OBB volume is 150.000019, not 150.
@Suite("Oriented Bounding Box")
struct OrientedBoundingBoxTests {

    @Test("OBB of axis-aligned box")
    func obbAlignedBox() throws {
        let box = try #require(Shape.box(width: 10, height: 5, depth: 3))
        let obb = try #require(box.orientedBoundingBox())
        // OBB volume should be close to box volume (10 * 5 * 3 = 150)
        #expect(abs(obb.volume - 150.0) < 1e-3)
        // Dimensions sorted should be {3, 5, 10}
        let dims = [obb.dimensions.x, obb.dimensions.y, obb.dimensions.z].sorted()
        #expect(abs(dims[0] - 3.0) < 1e-6)
        #expect(abs(dims[1] - 5.0) < 1e-6)
        #expect(abs(dims[2] - 10.0) < 1e-6)
    }

    @Test("OBB of rotated box is tighter than AABB")
    func obbTighterThanAABB() throws {
        // Rotate a box 45 degrees around Z. AABB will be larger, OBB should stay tight
        let box = try #require(
            Shape.box(width: 10, height: 2, depth: 2)?.rotated(
                axis: SIMD3(0, 0, 1), angle: .pi / 4))
        let obb = try #require(box.orientedBoundingBox())
        // OBB volume is the original volume (10 * 2 * 2 = 40); the AABB's is 144.
        #expect(abs(obb.volume - 40.0) < 1e-3)
        let aabb = try #require(box.bounds)
        let aabbVolume =
            (aabb.max.x - aabb.min.x) * (aabb.max.y - aabb.min.y) * (aabb.max.z - aabb.min.z)
        #expect(obb.volume < aabbVolume)
    }

    @Test("OBB corners count")
    func obbCorners() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        let obb = try #require(sphere.orientedBoundingBox())
        let corners = try #require(sphere.orientedBoundingBoxCorners())
        #expect(corners.count == 8)
        // The sphere's OBB is a cube of half-size 5, so every corner is 5 * sqrt(3) from the
        // centre and the eight are distinct.
        for c in corners {
            #expect(abs(simd_distance(c, obb.center) - 5 * 3.0.squareRoot()) < 1e-5)
        }
        for i in 0..<corners.count {
            for j in (i + 1)..<corners.count {
                #expect(simd_distance(corners[i], corners[j]) > 9.9)
            }
        }
    }

    @Test("OBB of sphere")
    func obbSphere() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        let obb = try #require(sphere.orientedBoundingBox())
        // Sphere OBB is a cube with side 10
        let dims = [obb.dimensions.x, obb.dimensions.y, obb.dimensions.z].sorted()
        #expect(abs(dims[0] - 10.0) < 1e-6)
        #expect(abs(dims[2] - 10.0) < 1e-6)
    }

    @Test("Optimal OBB")
    func obbOptimal() throws {
        let box = try #require(Shape.box(width: 10, height: 5, depth: 3))
        let obb = try #require(box.orientedBoundingBox(optimal: true))
        #expect(abs(obb.volume - 150.0) < 1e-3)
    }
}
