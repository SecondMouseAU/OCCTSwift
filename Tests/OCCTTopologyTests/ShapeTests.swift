import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

/// Basic tests for Shape creation and operations.
///
/// Note: These tests will pass with stub implementations but produce
/// empty/invalid shapes. Once OCCT is built, they will produce real geometry.
@Suite("Shape Tests")
struct ShapeTests {

    @Test("Create box primitive")
    func createBox() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        // With stubs, isValid returns true (placeholder)
        // With real OCCT, this creates actual geometry
        #expect(box.isValid)
    }

    @Test("Create cylinder primitive")
    func createCylinder() {
        let cylinder = Shape.cylinder(radius: 5, height: 10)!
        #expect(cylinder.isValid)
    }

    @Test("Create sphere primitive")
    func createSphere() {
        let sphere = Shape.sphere(radius: 5)!
        #expect(sphere.isValid)
    }

    @Test("Boolean union")
    func booleanUnion() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let sphere = Shape.sphere(radius: 3)!

        let union = (box + sphere)!
        #expect(union.isValid)
    }

    @Test("Boolean subtraction")
    func booleanSubtraction() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let cylinder = Shape.cylinder(radius: 2, height: 15)!

        let result = (box - cylinder)!
        #expect(result.isValid)
    }

    @Test("Translation")
    func translation() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        let moved = box.translated(by: SIMD3(10, 20, 30))!
        #expect(moved.isValid)
    }

    @Test("Rotation")
    func rotation() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        let rotated = box.rotated(axis: SIMD3(0, 0, 1), angle: .pi / 4)!
        #expect(rotated.isValid)
    }

    @Test("Fillet")
    func fillet() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let filleted = box.filleted(radius: 1)!
        #expect(filleted.isValid)
    }
}
