import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Selection / Raycasting Tests

@Suite("Selection, Raycasting")
struct RaycastTests {
    @Test("Raycast hits box")
    func raycastBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
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
    func raycastMiss() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Shoot ray parallel to box, should miss
        let hits = box.raycast(
            origin: SIMD3(20, 20, 5),
            direction: SIMD3(0, 0, 1)
        )
        #expect(hits.isEmpty)
    }

    @Test("Raycast nearest returns closest hit")
    func raycastNearest() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Box centered: top face at z=5
        let hit = box.raycastNearest(
            origin: SIMD3(0, 0, 20),
            direction: SIMD3(0, 0, -1)
        )
        #expect(hit != nil)
        #expect(hit!.point.z > 4.9)
    }

    @Test("Face count and face at index")
    func faceCountAndAccess() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(box.faceCount == 6)
        let face = box.face(at: 0)
        #expect(face != nil)
        #expect(face!.isPlanar)
        // Out-of-bounds returns nil
        let badFace = box.face(at: 100)
        #expect(badFace == nil)
    }
}
