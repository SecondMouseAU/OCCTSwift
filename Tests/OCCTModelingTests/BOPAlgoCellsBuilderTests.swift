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
        // #766: this ran inside `if let builder`, so a CellsBuilder that failed to construct
        // passed, and it asserted only non-nil results, which an unchanged result satisfies after
        // `removeAllFromResult()`. Pinned to the kernel (Scripts/repro/766-modeling-bopalgo-cells-
        // builder): the boxes share the face x = 10, so AddAllToResult gives 2 solids of total
        // volume 16000, and RemoveAllFromResult leaves an empty compound.
        guard let builder = CellsBuilder(shapes: [box1, box2]) else {
            Issue.record("CellsBuilder failed to construct")
            return
        }
        builder.addAllToResult(material: 0)
        guard let r1 = builder.result() else {
            Issue.record("result after addAllToResult was nil")
            return
        }
        #expect(r1.isValid)
        #expect(r1.solids.count == 2)
        #expect(abs((r1.volume ?? 0) - 16000) < 1e-6)

        builder.removeAllFromResult()
        let result2 = builder.result()
        // After removing all, result should be empty compound
        #expect(result2 != nil)
        #expect(result2?.solids.count == 0)
    }

    @Test("RemoveInternalBoundaries")
    func removeInternalBoundaries() {
        guard let box1 = Shape.box(width: 20, height: 20, depth: 20),
            let box2 = Shape.box(origin: SIMD3(10, 0, 0), width: 20, height: 20, depth: 20)
        else {
            #expect(false, "Failed to create boxes")
            return
        }
        // #766: this asserted only `result.isValid` inside `if let builder` and `if let result`,
        // so a nil builder or result passed. And `addAllToResult(material: 1)` could not show what
        // `removeInternalBoundaries()` does: the bridge calls AddAllToResult with update = true,
        // which merges same-material cells at once, so the kernel result is already one solid
        // before the call (Scripts/repro/766-modeling-bopalgo-cells-builder). Adding each box
        // separately with `update: false` leaves 2 solids, and RemoveInternalBoundaries merges
        // them into 1 of the same 16000 volume.
        guard let builder = CellsBuilder(shapes: [box1, box2]) else {
            Issue.record("CellsBuilder failed to construct")
            return
        }
        builder.addToResult(take: [box1], material: 1, update: false)
        builder.addToResult(take: [box2], material: 1, update: false)
        #expect(builder.result()?.solids.count == 2)
        builder.removeInternalBoundaries()
        guard let result = builder.result() else {
            Issue.record("result after removeInternalBoundaries was nil")
            return
        }
        #expect(result.isValid)
        #expect(result.solids.count == 1)
        #expect(abs((result.volume ?? 0) - 16000) < 1e-6)
    }
}
