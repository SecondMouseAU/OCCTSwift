import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// #1031: five casts in OCCTBridge_Document.mm turned a caller-supplied int32_t straight into an
// OCCT GD&T enum with no range check, so a value naming no enumerator was appended, stored and read
// back verbatim. Every neighbouring setter added in the same commits already validated, so this was
// an inconsistency inside one commit rather than a missing convention.
//
// These tests call the bridge directly rather than going through `Document`'s Swift API, because
// the Swift enums (`DimensionModifier`, `FormVariance`, `Grade`, ...) are complete typed enums and
// no Swift caller can express an out-of-range value. The defect only exists at the C boundary, so
// that is where it has to be tested. `handle` is the bridge document pointer, reached through
// `@testable import`.
@Suite("GD&T setters reject values that name no enumerator (#1031)")
struct Issue1031GDTEnumRangeTests {

    private func documentWithDimension() -> (Document, Int)? {
        guard let doc = Document.create() else { return nil }
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return nil }
        let shapeId = doc.addShape(box, makeAssembly: false)
        guard let index = doc.createDimension(on: shapeId, type: .sizeDiameter, value: 10) else {
            return nil
        }
        return (doc, index)
    }

    private func documentWithTolerance() -> (Document, Int)? {
        guard let doc = Document.create() else { return nil }
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return nil }
        let shapeId = doc.addShape(box, makeAssembly: false)
        guard let index = doc.createGeomTolerance(on: shapeId, type: .position, value: 0.1) else {
            return nil
        }
        return (doc, index)
    }

    private func documentWithDatum() -> (Document, Int)? {
        guard let doc = Document.create() else { return nil }
        guard let index = doc.createDatum(name: "A") else { return nil }
        return (doc, index)
    }

    @Test("A dimension modifier outside the enum is refused, and the sequence stays untouched")
    func dimensionModifierOutOfRangeIsRefused() {
        guard let (doc, index) = documentWithDimension() else {
            Issue.record("document nil")
            return
        }
        // Seed a real sequence so the refusal has something to preserve. Unfixed, 9999 was stored
        // and `dimension(at:)` read it back through a failing DimensionModifier(rawValue:), so the
        // sequence silently lost the element instead of the call being refused.
        let valid: [Int32] = [2, 19]
        let stored = valid.withUnsafeBufferPointer {
            OCCTDocumentSetDimensionModifiers(
                doc.handle, Int32(index), $0.baseAddress, Int32($0.count))
        }
        #expect(stored)
        #expect(doc.dimension(at: index)?.modifiers == [.statisticalTolerance, .anyCrossSection])

        // XCAFDimTolObjects_DimensionModif runs 0 through 23 (_Between).
        for bad in [Int32(24), Int32(9999), Int32(-1)] {
            let rejected = [bad].withUnsafeBufferPointer {
                OCCTDocumentSetDimensionModifiers(doc.handle, Int32(index), $0.baseAddress, 1)
            }
            #expect(!rejected, "value \(bad) was accepted")
        }
        // A rejected array must leave the previous sequence in place, not half-written.
        #expect(doc.dimension(at: index)?.modifiers == [.statisticalTolerance, .anyCrossSection])

        // One bad value poisons the whole array, including the good ones beside it.
        let mixed: [Int32] = [2, 9999, 19]
        let mixedRejected = mixed.withUnsafeBufferPointer {
            OCCTDocumentSetDimensionModifiers(
                doc.handle, Int32(index), $0.baseAddress, Int32($0.count))
        }
        #expect(!mixedRejected)
        #expect(doc.dimension(at: index)?.modifiers == [.statisticalTolerance, .anyCrossSection])
    }

    @Test("A class of tolerance outside the enum is refused rather than reported as present")
    func classOfToleranceOutOfRangeIsRefused() {
        guard let (doc, index) = documentWithDimension() else {
            Issue.record("document nil")
            return
        }
        // IsDimWithClassOfTolerance() is a bare test against _None, so an out-of-range formVariance
        // made it true: unfixed, the reader reported hasClassOfTolerance while classOfTolerance
        // decoded to nil, which is a dimension carrying a tolerance class nobody can name.
        // FormVariance runs 0 through 28 (_ZC), Grade 0 through 19 (_IT18).
        #expect(!OCCTDocumentSetDimensionClassOfTolerance(doc.handle, Int32(index), true, 29, 7))
        #expect(!OCCTDocumentSetDimensionClassOfTolerance(doc.handle, Int32(index), true, 9999, 7))
        #expect(!OCCTDocumentSetDimensionClassOfTolerance(doc.handle, Int32(index), true, -1, 7))
        #expect(!OCCTDocumentSetDimensionClassOfTolerance(doc.handle, Int32(index), true, 11, 20))
        #expect(!OCCTDocumentSetDimensionClassOfTolerance(doc.handle, Int32(index), true, 11, -1))
        #expect(doc.dimension(at: index)?.classOfTolerance == nil)

        // The in-range pair still works, so the guard rejects the regime rather than the feature.
        // Ordinal 11 of FormVariance is _H. Ordinal 7 of Grade is _IT6, not IT7: the enum opens
        // with IT01 and IT0, so the ITn names run two ahead of their own ordinals from IT1 on.
        #expect(OCCTDocumentSetDimensionClassOfTolerance(doc.handle, Int32(index), true, 11, 7))
        let readBack = doc.dimension(at: index)?.classOfTolerance
        #expect(readBack?.formVariance == .h)
        #expect(readBack?.grade == .it6)
    }

    @Test("A geometric tolerance modifier outside the enum is refused")
    func geomToleranceModifierOutOfRangeIsRefused() {
        guard let (doc, index) = documentWithTolerance() else {
            Issue.record("document nil")
            return
        }
        let valid: [Int32] = [3, 15]
        let stored = valid.withUnsafeBufferPointer {
            OCCTDocumentSetGeomToleranceModifiers(
                doc.handle, Int32(index), $0.baseAddress, Int32($0.count))
        }
        #expect(stored)
        #expect(doc.geomTolerance(at: index)?.modifiers.count == 2)

        // XCAFDimTolObjects_GeomToleranceModif runs 0 through 16 (_All_Over).
        for bad in [Int32(17), Int32(9999), Int32(-1)] {
            let rejected = [bad].withUnsafeBufferPointer {
                OCCTDocumentSetGeomToleranceModifiers(doc.handle, Int32(index), $0.baseAddress, 1)
            }
            #expect(!rejected, "value \(bad) was accepted")
        }
        #expect(doc.geomTolerance(at: index)?.modifiers.count == 2)
    }

    @Test("A datum modifier outside the enum is refused")
    func datumModifierOutOfRangeIsRefused() {
        guard let (doc, index) = documentWithDatum() else {
            Issue.record("document nil")
            return
        }
        let valid: [Int32] = [2, 3]
        let stored = valid.withUnsafeBufferPointer {
            OCCTDocumentSetDatumModifiers(
                doc.handle, Int32(index), $0.baseAddress, Int32($0.count))
        }
        #expect(stored)
        #expect(doc.datum(at: index)?.modifiers == [.basic, .contactingFeature])

        // XCAFDimTolObjects_DatumSingleModif runs 0 through 21 (_Translation).
        for bad in [Int32(22), Int32(9999), Int32(-1)] {
            let rejected = [bad].withUnsafeBufferPointer {
                OCCTDocumentSetDatumModifiers(doc.handle, Int32(index), $0.baseAddress, 1)
            }
            #expect(!rejected, "value \(bad) was accepted")
        }
        #expect(doc.datum(at: index)?.modifiers == [.basic, .contactingFeature])
    }

    @Test("Clearing a sequence with count 0 still works, so the guard did not break the empty case")
    func emptyModifierArrayStillClears() {
        guard let (doc, index) = documentWithDatum() else {
            Issue.record("document nil")
            return
        }
        let valid: [Int32] = [2, 3]
        _ = valid.withUnsafeBufferPointer {
            OCCTDocumentSetDatumModifiers(
                doc.handle, Int32(index), $0.baseAddress, Int32($0.count))
        }
        #expect(doc.datum(at: index)?.modifiers.count == 2)
        #expect(OCCTDocumentSetDatumModifiers(doc.handle, Int32(index), nil, 0))
        #expect(doc.datum(at: index)?.modifiers.isEmpty == true)
    }
}
