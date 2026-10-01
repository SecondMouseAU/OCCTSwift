import Testing
import simd

@testable import OCCTSwift

@Suite("BOPAlgo CellsBuilder")
struct BOPAlgoCellsBuilderTests {
    @Test("Create CellsBuilder")
    func createCellsBuilder() throws {
        // #2935: this asserted `builder != nil` and nothing else, so it could fail on no answer
        // and never on a wrong one. A `BOPAlgo_CellsBuilder` that constructs but drops one of its
        // arguments, or never runs the Perform() that splits them, passed.
        //
        // What construction itself produces is `GetAllParts()`, the cells the arguments were
        // split into; the result shape is still empty at that point, so nothing else observes it,
        // and neither of the other two tests in this file reads it. Measured against the pinned
        // kernel in Scripts/repro/2935-cellsbuilder-construction/: `Shape.box(20, 20, 20)` is
        // centred, so the two boxes meet at the face x = 10 without overlapping, and the split
        // gives 2 solids and 13 faces of total volume 16000. 13 because each box's facing side is
        // cut by the other's, 7 faces each, with the shared quarter counted once.
        let box1 = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let box2 = try #require(
            Shape.box(origin: SIMD3(10, 0, 0), width: 20, height: 20, depth: 20))
        let builder = try #require(CellsBuilder(shapes: [box1, box2]))

        let parts = try #require(builder.allParts(), "construction produced no split parts")
        #expect(parts.isValid)
        #expect(parts.solids.count == 2, "got \(parts.solids.count) cells, not 2")
        #expect(
            parts.subShapes(ofType: .face).count == 13,
            "got \(parts.subShapes(ofType: .face).count) faces, not the 13 the split gives")
        // One box alone is 8000, so this is what notices an argument that was dropped.
        let partsVolume = try #require(parts.volume, "cells enclose no volume")
        #expect(abs(partsVolume - 16000) < 1e-6, "cell volume \(partsVolume) != 16000")

        // And nothing has been composed into the result yet: an empty compound, not nil, holding
        // no solid. `volume` is nil rather than 0 because `occtVolumeMassProperties` reads a zero
        // mass as "nothing to measure", which is the right answer for an empty compound.
        let before = try #require(builder.result(), "result before any add was nil, not empty")
        #expect(before.solids.isEmpty)
        #expect(before.volume == nil, "an empty result reported a volume of \(before.volume ?? -1)")
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
