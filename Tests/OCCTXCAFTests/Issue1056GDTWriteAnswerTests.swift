import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// #1056: two GD&T write paths answered for a request the document did not take.
//
// `createDimension(on:type:value:lowerTolerance:upperTolerance:)` created the dimension first and
// then threw away `OCCTDocumentSetDimensionTolerance`'s `Bool`, so a tolerance pair the document
// refused still produced an index for a `.simple` dimension. The tolerance is now applied to the
// object before any label exists, so the refusal is the whole call's refusal and nothing is created.
//
// `setGeomToleranceZoneModifier(at:_:value:)` wrote the value unconditionally, with no reference to
// the modifier it had just set, so `.none` with a value left a projected-zone length on a tolerance
// with no projected zone. The datum sibling four hundred lines below already cleared its value; this
// one now does the same.
@Suite("GD&T write paths answer for what the document took (#1056)")
struct Issue1056GDTWriteAnswerTests {

    private func documentWithBox() -> (Document, Int64)? {
        guard let doc = Document.create() else { return nil }
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return nil }
        return (doc, doc.addShape(box, makeAssembly: false))
    }

    // MARK: - Site 1, createDimension's discarded tolerance result

    /// NaN is the cheapest trigger: the bridge's readback is an exact `==` against both stored
    /// values, and NaN never equals itself. The dimension count is the load-bearing assertion, since
    /// `nil` alone would also be satisfied by a fix that created the dimension and then reported
    /// failure.
    @Test(
        "A tolerance the document will not take refuses the whole call",
        arguments: [
            (Double.nan, 0.5),
            (-0.3, Double.nan),
            (Double.nan, Double.nan),
        ])
    func nonStorableToleranceRefusesTheCreate(lower: Double, upper: Double) throws {
        guard let (doc, labelId) = documentWithBox() else {
            Issue.record("fixture nil")
            return
        }
        let index = doc.createDimension(
            on: labelId, type: .sizeDiameter, value: 20.0,
            lowerTolerance: lower, upperTolerance: upper)
        #expect(index == nil)
        #expect(doc.dimensionCount == 0)
    }

    /// The control, and the assertion that the refusal above is about the tolerance rather than
    /// about `createDimension` having stopped creating anything.
    @Test("A storable tolerance pair still creates the dimension and applies both bounds")
    func storableToleranceStillApplies() throws {
        guard let (doc, labelId) = documentWithBox() else {
            Issue.record("fixture nil")
            return
        }
        guard
            let index = doc.createDimension(
                on: labelId, type: .sizeDiameter, value: 20.0,
                lowerTolerance: -0.3, upperTolerance: 0.7)
        else {
            Issue.record("createDimension nil")
            return
        }
        #expect(doc.dimensionCount == 1)
        if let dim = doc.dimension(at: index) {
            #expect(dim.bounds == .plusMinus(lowerTolerance: -0.3, upperTolerance: 0.7))
            #expect(dim.value == 20.0)
        } else {
            Issue.record("dimension nil")
        }
    }

    /// Omitting both bounds is the other half of the same signature and takes the path that never
    /// touches a tolerance at all, so it stays a `.simple` dimension.
    @Test("Omitting both bounds still creates a simple dimension")
    func noToleranceStillCreatesASimpleDimension() throws {
        guard let (doc, labelId) = documentWithBox() else {
            Issue.record("fixture nil")
            return
        }
        guard let index = doc.createDimension(on: labelId, type: .sizeDiameter, value: 20.0) else {
            Issue.record("createDimension nil")
            return
        }
        #expect(doc.dimensionCount == 1)
        #expect(doc.dimension(at: index)?.bounds == .simple)
    }

    /// `setDimensionTolerance(at:lower:upper:)` reported this correctly all along, and still does:
    /// the two spellings of the operation now agree on the same refusal.
    @Test("The standalone setter refuses the same pair, and leaves the dimension alone")
    func standaloneSetterRefusesTheSamePair() throws {
        guard let (doc, labelId) = documentWithBox() else {
            Issue.record("fixture nil")
            return
        }
        guard let index = doc.createDimension(on: labelId, type: .sizeDiameter, value: 20.0) else {
            Issue.record("createDimension nil")
            return
        }
        #expect(doc.setDimensionTolerance(at: index, lower: .nan, upper: 0.5) == false)
        #expect(doc.dimension(at: index)?.bounds == .simple)
    }

    // MARK: - Site 2, a zone-modifier value under a cleared modifier

    private func documentWithTolerance() -> (Document, Int)? {
        guard let (doc, labelId) = documentWithBox() else { return nil }
        guard let index = doc.createGeomTolerance(on: labelId, type: .position, value: 0.1) else {
            return nil
        }
        return (doc, index)
    }

    /// The issue's own measurement: `.none` with a value, on a tolerance that never had a modifier.
    @Test("A value passed with .none is not stored")
    func noneModifierStoresNoValue() throws {
        guard let (doc, index) = documentWithTolerance() else {
            Issue.record("fixture nil")
            return
        }
        #expect(doc.setGeomToleranceZoneModifier(at: index, .none, value: 15.0) == true)
        if let tol = doc.geomTolerance(at: index) {
            #expect(tol.zoneModifier == Document.GeomToleranceZoneModifier.none)
            #expect(tol.zoneModifierValue == nil)
        } else {
            Issue.record("geomTolerance nil")
        }
    }

    /// The same defect reached the other way: a real projected zone, then cleared. The first clear
    /// carries a value, which is what the old `value > 0.0` gate let through; the second carries
    /// none, which the old code already cleared correctly and which is kept here as a regression
    /// guard rather than as a probe of the defect.
    @Test("Clearing a modifier clears its value, whether or not one is passed with the clear")
    func clearingAModifierClearsItsValue() throws {
        guard let (doc, index) = documentWithTolerance() else {
            Issue.record("fixture nil")
            return
        }
        #expect(doc.setGeomToleranceZoneModifier(at: index, .projected, value: 15.0) == true)
        #expect(doc.geomTolerance(at: index)?.zoneModifierValue == 15.0)

        #expect(doc.setGeomToleranceZoneModifier(at: index, .none, value: 7.5) == true)
        if let tol = doc.geomTolerance(at: index) {
            #expect(tol.zoneModifier == Document.GeomToleranceZoneModifier.none)
            #expect(tol.zoneModifierValue == nil)
        } else {
            Issue.record("geomTolerance nil")
        }

        #expect(doc.setGeomToleranceZoneModifier(at: index, .projected, value: 15.0) == true)
        #expect(doc.setGeomToleranceZoneModifier(at: index, .none) == true)
        #expect(doc.geomTolerance(at: index)?.zoneModifierValue == nil)
    }

    /// The control: a modifier that is not `.none` keeps its value, so the clearing above is about
    /// `.none` and not about the setter having stopped storing anything.
    @Test("A real zone modifier still stores its value")
    func realModifierStillStoresItsValue() throws {
        guard let (doc, index) = documentWithTolerance() else {
            Issue.record("fixture nil")
            return
        }
        #expect(doc.setGeomToleranceZoneModifier(at: index, .projected, value: 15.0) == true)
        if let tol = doc.geomTolerance(at: index) {
            #expect(tol.zoneModifier == .projected)
            #expect(tol.zoneModifierValue == 15.0)
        } else {
            Issue.record("geomTolerance nil")
        }
    }

    /// The datum sibling's answer for the same call shape, which is the behaviour the tolerance
    /// setter was brought into line with.
    ///
    /// This does NOT guard the sibling against losing its own `none ? 0.0 : value` clearing, and
    /// nothing in this package can: `datum(at:)` only surfaces `modifierWithValue` when the
    /// modifier is not `.none`, and `OCCTDocumentGetDatumInfo` already zeroes `modifierValue` under
    /// `_None` before that, so the stored number is invisible through two independent gates. What
    /// it does guard is the reported answer, which is what a caller sees.
    @Test("The datum sibling reports nothing for a cleared modifier")
    func datumSiblingReportsNothingForAClearedModifier() throws {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        guard let index = doc.createDatum(name: "A") else {
            Issue.record("createDatum nil")
            return
        }
        #expect(doc.setDatumModifierWithValue(at: index, .none, value: 15.0) == true)
        #expect(doc.datum(at: index)?.modifierWithValue == nil)
    }
}
