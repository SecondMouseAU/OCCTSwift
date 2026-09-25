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
        // #766: this asserted only inside `if let result`, so a split that returned nil passed.
        // box2 spans x = 10...30 and box1 -10...10, so they share only the face x = 10 and the
        // kernel returns box1 whole: 1 valid solid of volume 8000
        // (Scripts/repro/766-modeling-bopalgo-splitter).
        guard let result = Shape.split(objects: [box1], by: [box2]) else {
            Issue.record("split returned nil")
            return
        }
        #expect(result.isValid)
        #expect(result.solidCount == 1)
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
        // #766: this asserted only inside `if let result`, so a split that returned nil passed.
        // The kernel splits box1 into exactly 2 solids (Scripts/repro/766-modeling-bopalgo-splitter).
        guard let result = Shape.split(objects: [box1], by: [box2]) else {
            Issue.record("split returned nil")
            return
        }
        #expect(result.solidCount == 2)
    }
}
