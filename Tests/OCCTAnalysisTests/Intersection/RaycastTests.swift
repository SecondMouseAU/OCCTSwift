import Foundation
import Testing

@testable import OCCTSwift

// MARK: - Selection / Raycasting Tests

@Suite("Selection, Raycasting")
struct RaycastTests {
    @Test("Raycast hits box")
    func raycastBox() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        // Box is centered at origin: spans from (-5,-5,-5) to (5,5,5)
        // Shoot ray from above, downward, hitting the top face at z=5
        let hits = box.raycast(
            origin: SIMD3(0, 0, 20),
            direction: SIMD3(0, 0, -1)
        )
        #expect(!hits.isEmpty)
        if let first = hits.first {
            #expect(first.point.z > 4.9 && first.point.z < 5.1)
            #expect(first.distance > 14.9 && first.distance < 15.1)
            #expect(first.faceIndex >= 0)
        }
    }

    @Test("Raycast misses box")
    func raycastMiss() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        // Shoot ray parallel to box, should miss
        let hits = box.raycast(
            origin: SIMD3(20, 20, 5),
            direction: SIMD3(0, 0, 1)
        )
        #expect(hits.isEmpty)

        // The same direction from inside the footprint, so "always empty" cannot pass: it enters
        // the bottom face at z = -5, 15 away, and leaves through the top at z = 5, 25 away.
        let through = box.raycast(origin: SIMD3(2, 2, -20), direction: SIMD3(0, 0, 1))
        #expect(through.count == 2)
        let ds = through.map { $0.distance }.sorted()
        if ds.count == 2 {
            #expect(abs(ds[0] - 15) < 1e-9 && abs(ds[1] - 25) < 1e-9, "got \(ds)")
        }
        #expect(through.allSatisfy { abs($0.point.x - 2) < 1e-9 && abs($0.point.y - 2) < 1e-9 })
    }

    @Test("Raycast nearest returns closest hit")
    func raycastNearest() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        // Box centered: top face at z=5
        let hit = box.raycastNearest(
            origin: SIMD3(0, 0, 20),
            direction: SIMD3(0, 0, -1)
        )
        #expect(hit != nil)
        #expect(try #require(hit).point.z > 4.9)
    }

    @Test("Face count and face at index")
    func faceCountAndAccess() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.faceCount == 6)
        let face = box.face(at: 0)
        #expect(face != nil)
        #expect(try #require(face).isPlanar)
        // Out-of-bounds returns nil
        let badFace = box.face(at: 100)
        #expect(badFace == nil)
    }
}
