import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1038: `setDatumTargetPlacement` returned true for a call that persisted nothing.
// `XCAFDoc_Datum::SetObject` nests its whole axis/length/width/number block inside
// `if (theObject->IsDatumTarget())`, and inside that takes an `Area` branch that writes no
// placement. So on a datum that has had no `setDatumTarget(at:type:number:)` applied, or whose type
// is `.area`, every value handed to the call was set on the in-memory object and then dropped when
// the attribute was written, while the call reported success.
@Suite("Datum target placement states its precondition (#1038)")
struct Issue1038DatumTargetPlacementTests {

    private func documentWithDatum() -> (Document, Int)? {
        guard let doc = Document.create() else { return nil }
        guard let index = doc.createDatum(name: "A") else { return nil }
        return (doc, index)
    }

    private func placement(_ doc: Document, _ index: Int, length: Double, width: Double) -> Bool {
        doc.setDatumTargetPlacement(
            at: index,
            location: SIMD3(1, 2, 3),
            normal: SIMD3(0, 0, 1),
            reference: SIMD3(1, 0, 0),
            length: length,
            width: width)
    }

    @Test("A datum that is not a target refuses the placement instead of reporting success")
    func placementOnANonTargetIsRefused() {
        guard let (doc, index) = documentWithDatum() else {
            Issue.record("document nil")
            return
        }
        // No setDatumTarget first. Unfixed this returned true, and datum(at:).target stayed nil,
        // so the caller was told the length and width were stored and could then read back neither.
        #expect(!placement(doc, index, length: 30, width: 18))
        #expect(doc.datum(at: index)?.target == nil)
    }

    @Test("An area target refuses the placement, because OCCT stores a shape there instead")
    func placementOnAnAreaTargetIsRefused() {
        guard let (doc, index) = documentWithDatum() else {
            Issue.record("document nil")
            return
        }
        #expect(doc.setDatumTarget(at: index, type: .area, number: 1))
        // The Area branch of SetObject writes the target's own shape, never a placement, so length
        // and width have nowhere to land however well formed they are.
        #expect(!placement(doc, index, length: 30, width: 18))
        let target = doc.datum(at: index)?.target
        #expect(target?.type == .area)
        #expect(target?.length == nil)
        #expect(target?.width == nil)
    }

    @Test("A rectangle target in the documented order still stores length and width")
    func placementOnARectangleTargetStillWorks() {
        guard let (doc, index) = documentWithDatum() else {
            Issue.record("document nil")
            return
        }
        // The order the docs now prescribe: mark the target first, then place it. This is the
        // control that keeps the refusals above from passing by refusing everything.
        #expect(doc.setDatumTarget(at: index, type: .rectangle, number: 1))
        #expect(placement(doc, index, length: 30, width: 18))
        let target = doc.datum(at: index)?.target
        #expect(target?.type == .rectangle)
        #expect(target?.number == 1)
        #expect(target?.length == 30)
        #expect(target?.width == 18)
    }

    @Test("Clearing the target mark makes a later placement refuse again")
    func placementAfterClearingTheTargetIsRefused() {
        guard let (doc, index) = documentWithDatum() else {
            Issue.record("document nil")
            return
        }
        #expect(doc.setDatumTarget(at: index, type: .rectangle, number: 1))
        #expect(placement(doc, index, length: 30, width: 18))
        #expect(doc.clearDatumTarget(at: index))
        // The precondition is read from the stored object each call, not cached from the first one.
        #expect(!placement(doc, index, length: 44, width: 22))
        #expect(doc.datum(at: index)?.target == nil)
    }
}
