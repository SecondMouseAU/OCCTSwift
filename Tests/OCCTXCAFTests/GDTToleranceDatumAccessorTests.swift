import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GD&T tolerance and datum accessors (#1004)")
struct GDTToleranceDatumAccessorTests {
    /// A box with one geometric tolerance on it.
    private func documentWithTolerance() -> (Document, Int)? {
        guard let doc = Document.create(), let box = Shape.box(width: 100, height: 50, depth: 25)
        else { return nil }
        let shapeId = doc.addShape(box, makeAssembly: false)
        guard let index = doc.createGeomTolerance(on: shapeId, type: .position, value: 0.1) else {
            return nil
        }
        return (doc, index)
    }

    private func documentWithDatum(name: String = "A") -> (Document, Int)? {
        guard let doc = Document.create() else { return nil }
        guard let index = doc.createDatum(name: name) else { return nil }
        return (doc, index)
    }

    // MARK: - Geometric tolerance

    /// The value type is what makes 0.1 a zone width or a zone diameter, so a tolerance read
    /// without it is read at half or twice its meaning.
    @Test("A tolerance's value type, material requirement and zone modifier round-trip")
    func toleranceSemanticsRoundTrip() {
        guard let (doc, index) = documentWithTolerance() else {
            Issue.record("document nil")
            return
        }

        // A tolerance nobody qualified. This also holds OCCTDocumentCreateGeomTolerance to handing
        // OCCT neutral values rather than whatever its uninitialised members happened to hold.
        if let fresh = doc.geomTolerance(at: index) {
            #expect(fresh.valueType == Document.GeomToleranceValueType.none)
            #expect(fresh.materialRequirement == Document.MaterialRequirement.none)
            #expect(fresh.zoneModifier == Document.GeomToleranceZoneModifier.none)
            #expect(fresh.zoneModifierValue == nil)
            #expect(fresh.maxValueModifier == nil)
            #expect(fresh.modifiers.isEmpty)
        } else {
            Issue.record("tolerance nil before writes")
        }

        #expect(doc.setGeomToleranceValueType(at: index, .diameter))
        #expect(doc.setGeomToleranceMaterialRequirement(at: index, .m))
        #expect(doc.setGeomToleranceZoneModifier(at: index, .projected, value: 15.0))
        #expect(doc.setGeomToleranceMaxValueModifier(at: index, 0.25))

        if let tol = doc.geomTolerance(at: index) {
            // Three separate OCCT members, all read in one call, so the trio proves none of the
            // three accessors is reading another's storage.
            #expect(tol.valueType == .diameter)
            #expect(tol.materialRequirement == .m)
            #expect(tol.zoneModifier == .projected)
            #expect(tol.zoneModifierValue == 15.0)
            #expect(tol.maxValueModifier == 0.25)
            // The tolerance's own value is untouched by any of them.
            #expect(tol.value == 0.1)
            #expect(tol.type == .position)
        } else {
            Issue.record("tolerance nil after writes")
        }
    }

    /// OCCT stores a zone value and a max value only when positive, so a zero is what an unstored
    /// one reads back as. Reporting either as 0.0 would be the defect #996 existed to fix.
    @Test("A zero zone value and a zero max value read back as nil, not as a measured zero")
    func toleranceZeroValuesAreAbsence() {
        guard let (doc, index) = documentWithTolerance() else {
            Issue.record("document nil")
            return
        }
        #expect(doc.setGeomToleranceZoneModifier(at: index, .projected, value: 15.0))
        #expect(doc.setGeomToleranceMaxValueModifier(at: index, 0.25))
        #expect(doc.geomTolerance(at: index)?.zoneModifierValue == 15.0)

        #expect(doc.setGeomToleranceZoneModifier(at: index, .projected, value: 0))
        #expect(doc.setGeomToleranceMaxValueModifier(at: index, 0))
        if let tol = doc.geomTolerance(at: index) {
            #expect(tol.zoneModifierValue == nil)
            #expect(tol.maxValueModifier == nil)
            // The modifier itself is gated separately, on its own `_None` member, and survives.
            #expect(tol.zoneModifier == .projected)
        } else {
            Issue.record("tolerance nil")
        }
    }

    @Test("A tolerance modifier sequence round-trips in order, and clears")
    func toleranceModifiersRoundTripInOrder() {
        guard let (doc, index) = documentWithTolerance() else {
            Issue.record("document nil")
            return
        }
        #expect(doc.geomTolerance(at: index)?.modifiers.isEmpty == true)

        // Deliberately not in the enum's own order, so a sequence rebuilt by sorting reads back
        // differently from what was written.
        let written: [Document.GeomToleranceModifier] = [.allAround, .commonZone, .freeState]
        #expect(doc.setGeomToleranceModifiers(at: index, written))
        #expect(doc.geomTolerance(at: index)?.modifiers == written)

        #expect(doc.setGeomToleranceModifiers(at: index, []))
        #expect(doc.geomTolerance(at: index)?.modifiers.isEmpty == true)
    }

    // MARK: - Datum

    /// A datum's position is what makes A|B|C an ordered frame rather than a set. It is 1-based,
    /// so 0 is absence rather than a first place.
    @Test("A datum position round-trips, and reads nil when it has no place in a frame")
    func datumPositionRoundTrips() {
        guard let (doc, index) = documentWithDatum() else {
            Issue.record("document nil")
            return
        }
        #expect(doc.datum(at: index)?.position == nil)

        #expect(doc.setDatumPosition(at: index, 2))
        #expect(doc.datum(at: index)?.position == 2)

        #expect(doc.setDatumPosition(at: index, 0))
        #expect(doc.datum(at: index)?.position == nil)
    }

    @Test("A datum modifier sequence round-trips in order, and the valued modifier is separate")
    func datumModifiersRoundTrip() {
        guard let (doc, index) = documentWithDatum() else {
            Issue.record("document nil")
            return
        }
        if let fresh = doc.datum(at: index) {
            #expect(fresh.modifiers.isEmpty)
            #expect(fresh.modifierWithValue == nil)
        } else {
            Issue.record("datum nil")
        }

        let written: [Document.DatumModifier] = [.translation, .basic, .contactingFeature]
        #expect(doc.setDatumModifiers(at: index, written))
        #expect(doc.setDatumModifierWithValue(at: index, .projected, value: 12.5))

        if let datum = doc.datum(at: index) {
            #expect(datum.modifiers == written)
            #expect(datum.modifierWithValue?.modifier == .projected)
            #expect(datum.modifierWithValue?.value == 12.5)
        } else {
            Issue.record("datum nil")
        }

        // Clearing the valued modifier leaves the sequence alone: two separate OCCT members.
        #expect(doc.setDatumModifierWithValue(at: index, .none))
        if let datum = doc.datum(at: index) {
            #expect(datum.modifierWithValue == nil)
            #expect(datum.modifiers == written)
        } else {
            Issue.record("datum nil")
        }

        #expect(doc.setDatumModifiers(at: index, []))
        #expect(doc.datum(at: index)?.modifiers.isEmpty == true)
    }

    /// A rectangle target keeps both dimensions, a line keeps only the length, and a point keeps
    /// neither, matching OCCT's own nesting. Reporting length and width unconditionally would
    /// surface the object's unassigned members as measurements.
    @Test("A datum target's length and width follow the target type, not the write")
    func datumTargetDimensionsFollowTheType() {
        guard let (doc, index) = documentWithDatum(name: "B") else {
            Issue.record("document nil")
            return
        }
        #expect(doc.datum(at: index)?.target == nil)

        // Asymmetric length and width on purpose, so one reported as the other is visible.
        func placeTarget(_ type: Document.DatumTargetType) {
            #expect(doc.setDatumTarget(at: index, type: type, number: 4))
            #expect(
                doc.setDatumTargetPlacement(
                    at: index,
                    location: SIMD3(1, 2, 3),
                    normal: SIMD3(0, 0, 1),
                    reference: SIMD3(1, 0, 0),
                    length: 30,
                    width: 18))
        }

        placeTarget(.rectangle)
        if let target = doc.datum(at: index)?.target {
            #expect(target.type == .rectangle)
            #expect(target.number == 4)
            #expect(target.length == 30)
            #expect(target.width == 18)
        } else {
            Issue.record("rectangle target nil")
        }

        placeTarget(.line)
        if let target = doc.datum(at: index)?.target {
            #expect(target.type == .line)
            #expect(target.length == 30)
            #expect(target.width == nil)
        } else {
            Issue.record("line target nil")
        }

        placeTarget(.point)
        if let target = doc.datum(at: index)?.target {
            #expect(target.type == .point)
            #expect(target.length == nil)
            #expect(target.width == nil)
        } else {
            Issue.record("point target nil")
        }

        #expect(doc.clearDatumTarget(at: index))
        #expect(doc.datum(at: index)?.target == nil)
    }

    /// The placement is one call because each of OCCT's three setters raises the same
    /// HasDatumTargetParams flag. A degenerate axis is refused rather than crossing into OCCT.
    @Test("A degenerate datum target placement axis is refused")
    func degenerateDatumTargetAxisIsRefused() {
        guard let (doc, index) = documentWithDatum(name: "C") else {
            Issue.record("document nil")
            return
        }
        #expect(doc.setDatumTarget(at: index, type: .line, number: 1))
        #expect(
            !doc.setDatumTargetPlacement(
                at: index,
                location: SIMD3(0, 0, 0),
                normal: SIMD3(0, 0, 0),
                reference: SIMD3(1, 0, 0),
                length: 10,
                width: 0))
        // Refused, so nothing was stored and the target reports no length.
        #expect(doc.datum(at: index)?.target?.length == nil)
    }

    // MARK: - Isolation and bounds

    @Test("Two tolerances and two datums on one document keep their own accessor values")
    func accessorsAreNotSharedBetweenEntries() {
        guard let doc = Document.create(), let box = Shape.box(width: 10, height: 10, depth: 10)
        else {
            Issue.record("document nil")
            return
        }
        let shapeId = doc.addShape(box, makeAssembly: false)
        guard let tolA = doc.createGeomTolerance(on: shapeId, type: .position, value: 0.1),
            let tolB = doc.createGeomTolerance(on: shapeId, type: .flatness, value: 0.05),
            let datumA = doc.createDatum(name: "A"),
            let datumB = doc.createDatum(name: "B")
        else {
            Issue.record("create nil")
            return
        }

        #expect(doc.setGeomToleranceValueType(at: tolA, .diameter))
        #expect(doc.setGeomToleranceModifiers(at: tolB, [.allOver]))
        #expect(doc.setDatumPosition(at: datumA, 1))
        #expect(doc.setDatumTarget(at: datumB, type: .circle, number: 7))

        if let a = doc.geomTolerance(at: tolA), let b = doc.geomTolerance(at: tolB) {
            #expect(a.valueType == .diameter)
            #expect(a.modifiers.isEmpty)
            #expect(b.valueType == Document.GeomToleranceValueType.none)
            #expect(b.modifiers == [.allOver])
        } else {
            Issue.record("tolerance nil")
        }
        if let a = doc.datum(at: datumA), let b = doc.datum(at: datumB) {
            #expect(a.name == "A")
            #expect(a.position == 1)
            #expect(a.target == nil)
            #expect(b.name == "B")
            #expect(b.position == nil)
            #expect(b.target?.type == .circle)
            #expect(b.target?.number == 7)
        } else {
            Issue.record("datum nil")
        }
    }

    @Test("Out-of-range tolerance and datum indices are refused")
    func outOfRangeIndicesAreRefused() {
        guard let (doc, _) = documentWithTolerance() else {
            Issue.record("document nil")
            return
        }
        #expect(doc.geomTolerance(at: 5) == nil)
        #expect(!doc.setGeomToleranceValueType(at: 5, .diameter))
        #expect(!doc.setGeomToleranceMaterialRequirement(at: 5, .m))
        #expect(!doc.setGeomToleranceZoneModifier(at: 5, .projected, value: 1))
        #expect(!doc.setGeomToleranceMaxValueModifier(at: 5, 1))
        #expect(!doc.setGeomToleranceModifiers(at: 5, [.allOver]))

        #expect(doc.datum(at: 0) == nil)
        #expect(!doc.setDatumPosition(at: 0, 1))
        #expect(!doc.setDatumModifiers(at: 0, [.basic]))
        #expect(!doc.setDatumModifierWithValue(at: 0, .projected, value: 1))
        #expect(!doc.setDatumTarget(at: 0, type: .point, number: 0))
        #expect(!doc.clearDatumTarget(at: 0))
        #expect(
            !doc.setDatumTargetPlacement(
                at: 0,
                location: SIMD3(0, 0, 0),
                normal: SIMD3(0, 0, 1),
                reference: SIMD3(1, 0, 0),
                length: 1,
                width: 1))
    }
}
