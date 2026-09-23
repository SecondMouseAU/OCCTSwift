import Testing
import simd

@testable import OCCTSwift

// MARK: - BOPAlgo_Section

@Suite("BOPAlgo Section")
struct BOPAlgoSectionTests {
    // #766: each test used to assert only inside `if let result`, so a section that returned nil
    // passed all three. The counts below are the kernel's own (Scripts/repro/766-modeling-bopalgo-
    // section): BOPAlgo_Section of the centred 10mm box with a sphere of radius 6 or 7 gives 7
    // edges; the second "overlapping" box starts at (5, 5, 0), so it only touches box1 along the
    // line x = y = 5 and the section is 1 edge.
    @Test("Section box and sphere")
    func sectionBoxSphere() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let sphere = Shape.sphere(radius: 6)
        else { return }
        guard let result = box.section(with: [sphere]) else {
            Issue.record("section returned nil")
            return
        }
        let edges = result.subShapes(ofType: .edge)
        #expect(edges.count == 7)
    }

    @Test("Section two overlapping boxes")
    func sectionTwoBoxes() {
        guard let box1 = Shape.box(width: 10, height: 10, depth: 10),
            let box2 = Shape.box(origin: SIMD3(5, 5, 0), width: 10, height: 10, depth: 10)
        else { return }
        guard let result = box1.section(with: [box2]) else {
            Issue.record("section returned nil")
            return
        }
        #expect(result.shapeType == .compound)
        #expect(result.subShapes(ofType: .edge).count == 1)
    }

    @Test("Static section between multiple shapes")
    func staticSection() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let sphere = Shape.sphere(radius: 7)
        else { return }
        guard let result = Shape.section(shapes: [box, sphere]) else {
            Issue.record("section returned nil")
            return
        }
        let edges = result.subShapes(ofType: .edge)
        #expect(edges.count == 7)
    }
}
