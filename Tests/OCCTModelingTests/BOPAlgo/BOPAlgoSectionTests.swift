import Testing
import simd

@testable import OCCTSwift

// MARK: - BOPAlgo_Section

@Suite("BOPAlgo Section")
struct BOPAlgoSectionTests {
    // #766: each test used to assert only inside `if let result`, so a section that returned nil
    // passed all three, and then returned silently (`guard ... else { return }`) when a fixture
    // failed to build. Both are `try #require` now. The counts below are the kernel's own
    // (Scripts/repro/766-modeling-bopalgo-section): BOPAlgo_Section of the centred 10mm box with
    // a sphere of radius 6 or 7 gives 7 edges; the second "overlapping" box starts at (5, 5, 0),
    // so it only touches box1 along the line x = y = 5 and the section is 1 edge.
    @Test("Section box and sphere")
    func sectionBoxSphere() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let sphere = try #require(Shape.sphere(radius: 6))
        let result = try #require(box.section(with: [sphere]))
        let edges = result.subShapes(ofType: .edge)
        #expect(edges.count == 7)
    }

    @Test("Section two overlapping boxes")
    func sectionTwoBoxes() throws {
        let box1 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let box2 = try #require(
            Shape.box(origin: SIMD3(5, 5, 0), width: 10, height: 10, depth: 10))
        let result = try #require(box1.section(with: [box2]))
        #expect(result.shapeType == .compound)
        #expect(result.subShapes(ofType: .edge).count == 1)
    }

    @Test("Static section between multiple shapes")
    func staticSection() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let sphere = try #require(Shape.sphere(radius: 7))
        let result = try #require(Shape.section(shapes: [box, sphere]))
        let edges = result.subShapes(ofType: .edge)
        #expect(edges.count == 7)
    }
}
