import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeRayIntersection Tests")
struct ShapeRayIntersectionTests {
    /// The box is centred (-5...5 on every axis), so this ray runs down the x = 5, y = 5 edge.
    ///
    /// Measured against `BRepIntCurveSurface_Inter` directly
    /// (`Scripts/repro/766-shape-ray-intersection/`), the kernel reports exactly two hits
    /// there, at z = -5 and z = 5.
    ///
    /// The version before #766's redo wrapped everything in `if let inter`, so a bridge that
    /// returned no intersector at all (`OCCTCurveSurfaceInterCreateLine` returning nullptr)
    /// left it green. The construction is now unconditional.
    @Test("line intersection with box")
    func lineBoxIntersection() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("Shape.box returned nil")
            return
        }
        guard
            let inter = ShapeRayIntersection(
                shape: box, originX: 5, originY: 5, originZ: -10,
                dirX: 0, dirY: 0, dirZ: 1)
        else {
            Issue.record("ShapeRayIntersection returned nil for a ray along a box edge")
            return
        }
        let hits = inter.allHits()
        #expect(hits.count == 2, "the kernel reports 2 hits along this edge, got \(hits.count)")
        #expect(hits.allSatisfy { $0.x == 5 && $0.y == 5 }, "every hit lies on the x = y = 5 edge")
        let zs = hits.map(\.z).sorted()
        #expect(zs == [-5, 5], "hits at the two box ends, got \(zs)")
    }

    /// A line up the z axis enters and leaves a radius-5 sphere through its two poles.
    ///
    /// The kernel reports two hits, at z = 5 and z = -5 (in that order, not sorted by parameter).
    /// Unconditional for the same reason as above: the old `if let line` / `if let inter`
    /// nesting passed on a bridge that returned no intersector.
    @Test("curve intersection with sphere")
    func curveSphereIntersection() {
        guard let sphere = Shape.sphere(radius: 5),
            let line = Curve3D.line(through: SIMD3(0, 0, -10), direction: SIMD3(0, 0, 1))
        else {
            Issue.record("could not build the sphere or the line")
            return
        }
        guard let inter = ShapeRayIntersection(shape: sphere, curve: line) else {
            Issue.record("ShapeRayIntersection returned nil for a line through a sphere")
            return
        }
        let hits = inter.allHits()
        #expect(hits.count == 2, "a line through both poles hits twice, got \(hits.count)")
        let zs = hits.map(\.z).sorted()
        #expect(
            zs.count == 2 && abs(zs[0] + 5) < 1e-9 && abs(zs[1] - 5) < 1e-9,
            "poles at z = -5 and 5, got \(zs)")
    }

    @Test("hit face access")
    func hitFaceAccess() {
        // `Shape.box` is centred, so this box spans -5...5 on every axis and a +Z ray
        // through the middle enters at z = -5 through a 10x10 cap face.
        //
        // Every assertion here is unconditional. The version before #2199 nested them
        // inside `if let inter`, `if inter.hasMore` and `if let face`, which made the
        // test pass on a bridge reporting no hits at all: returning false from
        // `OCCTCurveSurfaceInterMore` left it green while both sibling tests went red.
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("Shape.box returned nil")
            return
        }
        guard
            let inter = ShapeRayIntersection(
                shape: box,
                originX: 0, originY: 0, originZ: -10,
                dirX: 0, dirY: 0, dirZ: 1)
        else {
            Issue.record("ShapeRayIntersection returned nil for a ray through a box")
            return
        }
        #expect(inter.hasMore, "a ray through the middle of a box hits it")

        // Read `currentHit` before `allHits()`: the iterator is consumed, and reading it
        // afterwards yields an all-zero Hit that the old `z >= -6 && z <= 6` accepted.
        let hit = inter.currentHit
        #expect(hit.x == 0)
        #expect(hit.y == 0)
        #expect(abs(hit.z - (-5)) < 1e-9, "entry face is the z = -5 cap, got z=\(hit.z)")

        guard let face = inter.currentFace else {
            Issue.record("a hit has a face")
            return
        }
        #expect(
            abs(face.area() - 100) < 1e-6,
            "the 10x10 cap has area 100, got \(face.area())")
    }
}
