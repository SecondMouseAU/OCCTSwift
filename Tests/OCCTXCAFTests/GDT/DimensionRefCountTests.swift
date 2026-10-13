import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// #1481: `occtDocumentCreateDimensionImpl`'s single-shape dimension path called
// `XCAFDoc_DimTolTool::SetDimension(shapeSeq, shapeSeq, dimLabel)`, the 3-sequence overload, with
// the *same* one-element sequence for both `theFirstLS` and `theSecondLS`. That double-registers
// the shape as both the `DimensionRefFirstGUID` and `DimensionRefSecondGUID` graph-node father of
// the dimension, so a shape that carries one dimension reports it twice via
// `XCAFDoc_DimTolTool::GetRefDimensionLabels` (and the public `XCAFDimTolObjects_Tool` read API the
// issue's own reproducer used). The fix calls the dedicated single-shape overload,
// `SetDimension(theL, theDimTolL)`, which forwards to the 3-label overload with a null second
// label and only ever appends to the first sequence.
@Suite("Single-shape dimension registers once, not twice (#1481)")
struct Issue1481DimensionRefCountTests {

    @Test("A single-shape dimension appears exactly once in GetRefDimensionLabels")
    func singleShapeDimensionRegistersOnce() throws {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil")
            return
        }
        let labelId = doc.addShape(box, makeAssembly: false)
        #expect(labelId >= 0)

        guard let idx = doc.createDimension(on: labelId, type: .sizeDiameter, value: 20.0) else {
            Issue.record("createDimension nil")
            return
        }
        #expect(idx == 0)

        // The defect: this shape was registered as BOTH the first and second ref-label sequence
        // for the same dimension, so the pre-fix count here was 2, not 1.
        #expect(doc.refDimensionCount(for: labelId) == 1)
    }

    @Test("A single-shape dimension created with a tolerance also registers once")
    func singleShapeDimensionWithToleranceRegistersOnce() throws {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil")
            return
        }
        let labelId = doc.addShape(box, makeAssembly: false)

        // OCCTDocumentCreateDimensionWithTolerance shares occtDocumentCreateDimensionImpl with the
        // plain path above, so this exercises the same SetDimension call.
        guard
            let idx = doc.createDimension(
                on: labelId, type: .sizeDiameter, value: 20.0,
                lowerTolerance: -0.1, upperTolerance: 0.1)
        else {
            Issue.record("createDimension nil")
            return
        }
        #expect(idx == 0)
        #expect(doc.refDimensionCount(for: labelId) == 1)
    }

    @Test("Two shapes each carrying one dimension report one ref each, not two")
    func twoShapesEachRegisterOnce() throws {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        guard let box1 = Shape.box(width: 10, height: 10, depth: 10),
            let box2 = Shape.box(width: 20, height: 20, depth: 20)
        else {
            Issue.record("box nil")
            return
        }
        let label1 = doc.addShape(box1, makeAssembly: false)
        let label2 = doc.addShape(box2, makeAssembly: false)

        #expect(doc.createDimension(on: label1, type: .sizeDiameter, value: 5.0) != nil)
        #expect(doc.createDimension(on: label2, type: .sizeDiameter, value: 15.0) != nil)

        #expect(doc.dimensionCount == 2)
        #expect(doc.refDimensionCount(for: label1) == 1)
        #expect(doc.refDimensionCount(for: label2) == 1)
    }
}
