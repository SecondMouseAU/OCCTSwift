import Testing
import simd

@testable import OCCTSwift

@Suite("BOPAlgo Splitter")
struct BOPAlgoSplitterTests {
    @Test("Split box by another box")
    func splitBoxes() {
        guard let box1 = Shape.box(width: 20, height: 20, depth: 20),
            let box2 = Shape.box(origin: SIMD3(10, 0, 0), width: 20, height: 20, depth: 20)
        else {
            #expect(false, "Failed to create boxes")
            return
        }
        let result = Shape.split(objects: [box1], by: [box2])
        if let result = result {
            #expect(result.isValid)
        }
    }

    @Test("Split produces multiple solids")
    func splitProducesMultipleSolids() {
        // Two overlapping boxes: box1 from -10..10, box2 from 0..20
        guard let box1 = Shape.box(width: 20, height: 20, depth: 20),
            let box2 = Shape.box(origin: SIMD3(0, -10, -10), width: 20, height: 20, depth: 20)
        else {
            #expect(false, "Failed to create boxes")
            return
        }
        let result = Shape.split(objects: [box1], by: [box2])
        if let result = result {
            #expect(result.solidCount >= 2)
        }
    }
}
