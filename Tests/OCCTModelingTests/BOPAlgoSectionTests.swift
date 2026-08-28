import Testing
import simd

@testable import OCCTSwift

// MARK: - BOPAlgo_Section

@Suite("BOPAlgo Section")
struct BOPAlgoSectionTests {
    @Test("Section box and sphere")
    func sectionBoxSphere() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let sphere = Shape.sphere(radius: 6)
        else { return }
        if let result = box.section(with: [sphere]) {
            let edges = result.subShapes(ofType: .edge)
            #expect(edges.count > 0)
        }
    }

    @Test("Section two overlapping boxes")
    func sectionTwoBoxes() {
        guard let box1 = Shape.box(width: 10, height: 10, depth: 10),
            let box2 = Shape.box(origin: SIMD3(5, 5, 0), width: 10, height: 10, depth: 10)
        else { return }
        if let result = box1.section(with: [box2]) {
            #expect(result.shapeType == .compound)
        }
    }

    @Test("Static section between multiple shapes")
    func staticSection() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let sphere = Shape.sphere(radius: 7)
        else { return }
        if let result = Shape.section(shapes: [box, sphere]) {
            let edges = result.subShapes(ofType: .edge)
            #expect(edges.count > 0)
        }
    }
}
