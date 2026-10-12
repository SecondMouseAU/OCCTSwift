import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

/// Basic tests for Shape creation and operations.
///
/// Every value is pinned against the closed form of the shape (volume, area, bounds), since a
/// test that only reads `isValid` passes on any shape the kernel hands back.
@Suite("Shape Tests")
struct ShapeTests {

    @Test("Create box primitive")
    func createBox() throws {
        let box = try #require(Shape.box(width: 10, height: 5, depth: 3))
        #expect(box.isValid)
        #expect(box.faces().count == 6)
        #expect(abs((box.volume ?? 0) - 150) < 1e-9)
        #expect(abs((box.surfaceArea ?? 0) - 190) < 1e-9)
        // Centred on the origin: width along X, height along Y, depth along Z.
        let bounds = try #require(box.boundingBox)
        #expect(vectorLength(bounds.min - SIMD3(-5, -2.5, -1.5)) < 1e-5)
        #expect(vectorLength(bounds.max - SIMD3(5, 2.5, 1.5)) < 1e-5)
    }

    @Test("Create cylinder primitive")
    func createCylinder() throws {
        let cylinder = try #require(Shape.cylinder(radius: 5, height: 10))
        #expect(cylinder.isValid)
        #expect(cylinder.faces().count == 3)
        // pi r^2 h, and 2 pi r h + 2 pi r^2
        #expect(abs((cylinder.volume ?? 0) - 250 * Double.pi) < 1e-6)
        #expect(abs((cylinder.surfaceArea ?? 0) - 150 * Double.pi) < 1e-6)
        // Standing on the XY plane, axis along +Z.
        let bounds = try #require(cylinder.boundingBox)
        #expect(vectorLength(bounds.min - SIMD3(-5, -5, 0)) < 1e-5)
        #expect(vectorLength(bounds.max - SIMD3(5, 5, 10)) < 1e-5)
    }

    @Test("Create sphere primitive")
    func createSphere() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        #expect(sphere.isValid)
        // 4/3 pi r^3 and 4 pi r^2
        #expect(abs((sphere.volume ?? 0) - 500 * Double.pi / 3) < 1e-6)
        #expect(abs((sphere.surfaceArea ?? 0) - 100 * Double.pi) < 1e-6)
        let bounds = try #require(sphere.boundingBox)
        #expect(vectorLength(bounds.min - SIMD3(-5, -5, -5)) < 1e-5)
        #expect(vectorLength(bounds.max - SIMD3(5, 5, 5)) < 1e-5)
    }

    @Test("Boolean union")
    func booleanUnion() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let sphere = try #require(Shape.sphere(radius: 3))
        let sum: Shape? = box + sphere
        let union = try #require(sum)
        #expect(union.isValid)
        // The radius-3 sphere sits wholly inside the 10-box centred on the same point, so the
        // union is the box: volume 1000, and only the box's six faces are left.
        #expect(abs((union.volume ?? 0) - 1000) < 1e-6)
        #expect(union.faces().count == 6)

        // A sphere centred at x = 7 pokes 1 out through the x = 5 face: the union adds the sphere
        // less the cap inside the box, V = 36 pi - pi h^2 (3 r - h) / 3 with h = 1, r = 3.
        let outside = try #require(Shape.sphere(radius: 3))
        let moved = try #require(outside.translated(by: SIMD3(7, 0, 0)))
        let pokes: Shape? = box + moved
        let both = try #require(pokes)
        #expect(both.isValid)
        #expect(abs((both.volume ?? 0) - (1000 + 36 * Double.pi - 8 * Double.pi / 3)) < 1e-4)
    }

    @Test("Boolean subtraction")
    func booleanSubtraction() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        // The cylinder stands on z = 0 and runs 15 up, so it cuts the box from its mid-plane
        // to the top: a radius-2 hole 5 deep.
        let cylinder = try #require(Shape.cylinder(radius: 2, height: 15))
        let difference: Shape? = box - cylinder
        let result = try #require(difference)
        #expect(result.isValid)
        // 1000 - pi r^2 h = 1000 - 20 pi
        #expect(abs((result.volume ?? 0) - (1000 - 20 * Double.pi)) < 1e-6)
        // 600 - top hole (4 pi) + wall (2 pi r h = 20 pi) + floor (4 pi)
        #expect(abs((result.surfaceArea ?? 0) - (600 + 20 * Double.pi)) < 1e-6)
        #expect(result.faces().count == 8)
    }

    @Test("Translation")
    func translation() throws {
        let box = try #require(Shape.box(width: 10, height: 5, depth: 3))
        let moved = try #require(box.translated(by: SIMD3(10, 20, 30)))
        #expect(moved.isValid)
        #expect(abs((moved.volume ?? 0) - 150) < 1e-9)
        // (-5..5, -2.5..2.5, -1.5..1.5) + (10, 20, 30)
        let bounds = try #require(moved.boundingBox)
        #expect(vectorLength(bounds.min - SIMD3(5, 17.5, 28.5)) < 1e-5)
        #expect(vectorLength(bounds.max - SIMD3(15, 22.5, 31.5)) < 1e-5)
    }

    @Test("Rotation")
    func rotation() throws {
        let box = try #require(Shape.box(width: 10, height: 5, depth: 3))
        let rotated = try #require(box.rotated(axis: SIMD3(0, 0, 1), angle: .pi / 4))
        #expect(rotated.isValid)
        #expect(abs((rotated.volume ?? 0) - 150) < 1e-9)
        // A 10 x 5 rectangle turned 45 degrees spans (10 + 5) / sqrt 2 in X and in Y; Z is
        // untouched.
        let half = 15 / (2 * 2.0.squareRoot())
        let bounds = try #require(rotated.boundingBox)
        #expect(vectorLength(bounds.min - SIMD3(-half, -half, -1.5)) < 1e-5)
        #expect(vectorLength(bounds.max - SIMD3(half, half, 1.5)) < 1e-5)
    }

    @Test("Fillet")
    func fillet() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let filleted = try #require(box.filleted(radius: 1))
        #expect(filleted.isValid)
        // A box with all twelve edges rounded is the 8-cube grown by r = 1:
        //   s^3 + 6 s^2 r + 3 pi s r^2 + 4/3 pi r^3 with s = 8
        let volume = 512.0 + 384.0 + 24.0 * Double.pi + 4.0 / 3.0 * Double.pi
        #expect(abs((filleted.volume ?? 0) - volume) < 1e-6)
        // 6 s^2 + 12 (pi/2) r s + 4 pi r^2
        let area = 384.0 + 48.0 * Double.pi + 4.0 * Double.pi
        #expect(abs((filleted.surfaceArea ?? 0) - area) < 1e-6)
        // 6 flats + 12 edge blends + 8 corner blends
        #expect(filleted.faces().count == 26)
    }
}
