import Testing
import simd

@testable import OCCTSwift

@Suite("BOPAlgo CellsBuilder")
struct BOPAlgoCellsBuilderTests {
    @Test("Create CellsBuilder")
    func createCellsBuilder() {
        guard let box1 = Shape.box(width: 20, height: 20, depth: 20),
            let box2 = Shape.box(origin: SIMD3(10, 0, 0), width: 20, height: 20, depth: 20)
        else {
            #expect(false, "Failed to create boxes")
            return
        }
        let builder = CellsBuilder(shapes: [box1, box2])
        #expect(builder != nil)
    }

    @Test("AddAll and RemoveAll")
    func addRemoveAll() {
        guard let box1 = Shape.box(width: 20, height: 20, depth: 20),
            let box2 = Shape.box(origin: SIMD3(10, 0, 0), width: 20, height: 20, depth: 20)
        else {
            #expect(false, "Failed to create boxes")
            return
        }
        if let builder = CellsBuilder(shapes: [box1, box2]) {
            builder.addAllToResult(material: 0)
            let result1 = builder.result()
            #expect(result1 != nil)
            if let r = result1 { #expect(r.isValid) }

            builder.removeAllFromResult()
            let result2 = builder.result()
            // After removing all, result should be empty compound
            #expect(result2 != nil)
        }
    }

    @Test("RemoveInternalBoundaries")
    func removeInternalBoundaries() {
        guard let box1 = Shape.box(width: 20, height: 20, depth: 20),
            let box2 = Shape.box(origin: SIMD3(10, 0, 0), width: 20, height: 20, depth: 20)
        else {
            #expect(false, "Failed to create boxes")
            return
        }
        if let builder = CellsBuilder(shapes: [box1, box2]) {
            builder.addAllToResult(material: 1)
            builder.removeInternalBoundaries()
            let result = builder.result()
            if let result = result {
                #expect(result.isValid)
            }
        }
    }
}
