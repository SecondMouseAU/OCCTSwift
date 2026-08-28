import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Measurement & Analysis Tests (v0.7.0)

@Suite("Measurement Tests")
struct MeasurementTests {

    // MARK: - Volume Tests

    @Test("Volume of box")
    func volumeOfBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let volume = box.volume else {
            Issue.record("Failed to compute volume")
            return
        }
        // 10 × 10 × 10 = 1000 cubic units
        #expect(abs(volume - 1000.0) < 0.01)
    }

    @Test("Volume of cylinder")
    func volumeOfCylinder() {
        let cylinder = Shape.cylinder(radius: 5, height: 10)!
        guard let volume = cylinder.volume else {
            Issue.record("Failed to compute volume")
            return
        }
        // π × r² × h = π × 25 × 10 ≈ 785.4
        let expected = Double.pi * 25.0 * 10.0
        #expect(abs(volume - expected) < 0.1)
    }

    @Test("Volume of sphere")
    func volumeOfSphere() {
        let sphere = Shape.sphere(radius: 5)!
        guard let volume = sphere.volume else {
            Issue.record("Failed to compute volume")
            return
        }
        // 4/3 × π × r³ = 4/3 × π × 125 ≈ 523.6
        let expected = (4.0 / 3.0) * Double.pi * 125.0
        #expect(abs(volume - expected) < 0.1)
    }

    // MARK: - Surface Area Tests

    @Test("Surface area of box")
    func surfaceAreaOfBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let area = box.surfaceArea else {
            Issue.record("Failed to compute surface area")
            return
        }
        // 6 faces × 100 = 600 square units
        #expect(abs(area - 600.0) < 0.1)
    }

    @Test("Surface area of sphere")
    func surfaceAreaOfSphere() {
        let sphere = Shape.sphere(radius: 5)!
        guard let area = sphere.surfaceArea else {
            Issue.record("Failed to compute surface area")
            return
        }
        // 4 × π × r² = 4 × π × 25 ≈ 314.16
        let expected = 4.0 * Double.pi * 25.0
        #expect(abs(area - expected) < 0.5)
    }

    // MARK: - Center of Mass Tests

    @Test("Center of mass of box at origin")
    func centerOfMassBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let center = box.centerOfMass else {
            Issue.record("Failed to compute center of mass")
            return
        }
        // Box is created centered at origin (from -5 to +5 in each axis)
        #expect(abs(center.x) < 0.01)
        #expect(abs(center.y) < 0.01)
        #expect(abs(center.z) < 0.01)
    }

    @Test("Center of mass of translated box")
    func centerOfMassTranslatedBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
            .translated(by: SIMD3(100, 200, 300))!
        guard let center = box.centerOfMass else {
            Issue.record("Failed to compute center of mass")
            return
        }
        // Box centered at origin, then translated by (100, 200, 300)
        #expect(abs(center.x - 100.0) < 0.01)
        #expect(abs(center.y - 200.0) < 0.01)
        #expect(abs(center.z - 300.0) < 0.01)
    }

    // MARK: - Full Properties Test

    @Test("Full shape properties")
    func fullShapeProperties() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let props = box.properties(density: 2.5) else {
            Issue.record("Failed to compute properties")
            return
        }

        #expect(abs(props.volume - 1000.0) < 0.01)
        #expect(abs(props.surfaceArea - 600.0) < 0.1)
        #expect(abs(props.mass - 2500.0) < 0.1)  // 1000 × 2.5
        #expect(abs(props.centerOfMass.x) < 0.01)  // Box centered at origin
    }

    // MARK: - Distance Tests

    @Test("Distance between separated boxes")
    func distanceBetweenBoxes() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!
            .translated(by: SIMD3(20, 0, 0))!

        guard let result = box1.distance(to: box2) else {
            Issue.record("Failed to compute distance")
            return
        }
        // Gap of 10 units between boxes
        #expect(abs(result.distance - 10.0) < 0.01)
    }

    @Test("Distance between touching boxes")
    func distanceBetweenTouchingBoxes() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!
            .translated(by: SIMD3(10, 0, 0))!

        guard let result = box1.distance(to: box2) else {
            Issue.record("Failed to compute distance")
            return
        }
        // Boxes are touching
        #expect(abs(result.distance) < 0.01)
    }

    @Test("Min distance convenience method")
    func minDistanceConvenience() {
        let sphere1 = Shape.sphere(radius: 5)!
        let sphere2 = Shape.sphere(radius: 3)!.translated(by: SIMD3(15, 0, 0))!

        guard let dist = sphere1.minDistance(to: sphere2) else {
            Issue.record("Failed to compute min distance")
            return
        }
        // 15 - 5 - 3 = 7 units gap
        #expect(abs(dist - 7.0) < 0.1)
    }

    // MARK: - Intersection Tests

    @Test("Intersects - overlapping shapes")
    func intersectsOverlapping() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let sphere = Shape.sphere(radius: 3)!  // At origin, inside box

        #expect(box.intersects(sphere))
    }

    @Test("Intersects - separated shapes")
    func intersectsSeparated() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let sphere = Shape.sphere(radius: 3)!
            .translated(by: SIMD3(50, 0, 0))!  // Far away

        #expect(!box.intersects(sphere))
    }

    @Test("Intersects - touching shapes")
    func intersectsTouching() {
        // Box from -5 to +5 in each axis (centered at origin)
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Sphere of radius 5 centered at (10, 0, 0) touches box at x=5
        let sphere = Shape.sphere(radius: 5)!
            .translated(by: SIMD3(10, 0, 0))!

        // Should be touching or very close
        #expect(box.intersects(sphere, tolerance: 0.1))
    }

    // MARK: - Vertex Tests

    @Test("Vertex count of box")
    func vertexCountBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(box.vertexCount == 8)
    }

    @Test("Get all vertices")
    func getAllVertices() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let vertices = box.vertices()
        #expect(vertices.count == 8)
    }

    @Test("Get vertex at index")
    func vertexAtIndex() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let vertex = box.vertex(at: 0)
        #expect(vertex != nil)
    }

    @Test("Vertex out of bounds")
    func vertexOutOfBounds() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let vertex = box.vertex(at: 100)  // Invalid index
        #expect(vertex == nil)
    }
}
