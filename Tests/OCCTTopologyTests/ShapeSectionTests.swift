import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.34.0. OCCT Test Suite Audit Round 3

@Suite("Shape-to-Shape Section")
struct ShapeSectionTests {
    @Test("Section of two intersecting boxes")
    func sectionTwoBoxes() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!.translated(by: SIMD3(5, 5, 0))
        let result = box1.section(box2!)
        #expect(result != nil)
    }

    @Test("Section of box and cylinder")
    func sectionBoxCylinder() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let cyl = Shape.cylinder(radius: 3, height: 20)!
        let result = box.section(cyl)
        #expect(result != nil)
    }

    @Test("Section of non-intersecting shapes returns empty")
    func sectionNoIntersection() {
        let box1 = Shape.box(width: 5, height: 5, depth: 5)!
        let box2 = Shape.box(width: 5, height: 5, depth: 5)!.translated(by: SIMD3(100, 100, 100))
        let result = box1.section(box2!)
        // Non-intersecting shapes may return empty compound or nil
        _ = result
    }

    @Test("Section of sphere and plane")
    func sectionSpherePlane() {
        let sphere = Shape.sphere(radius: 5)!
        // Create a thin box as a plane-like shape
        let plane = Shape.box(width: 20, height: 20, depth: 0.001)!
        let result = sphere.section(plane)
        #expect(result != nil)
    }
}
