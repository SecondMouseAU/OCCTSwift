import Foundation
import OCCTSwift
import Testing

@Suite("Issue #1051: GD&T Table Unification")
struct Issue1051GDTTableUnificationTests {

    @Test("Swift API datum visible to both datumCount and dimTolToolToleranceCount")
    func swiftDatumVisibleToBothCounts() {
        let doc = Document.create()!
        let idx = doc.createDatum(name: "DatumA")!
        #expect(idx == 0)
        #expect(doc.datumCount == 1)
        // dimTolToolToleranceCount counts tolerances, not datums, so should be 0
        #expect(doc.dimTolToolToleranceCount == 0)
    }

    @Test("Datum + GeomTolerance: both counts work")
    func datumAndGeomToleranceCounts() {
        let doc = Document.create()!
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let shapeLabel = doc.addShape(box)
        let datumIdx = doc.createDatum(name: "DatumB")!
        let tolIdx = doc.createGeomTolerance(on: shapeLabel, type: .flatness, value: 0.01)!
        #expect(datumIdx == 0)
        #expect(tolIdx == 0)
        #expect(doc.datumCount == 1)
        #expect(doc.geomToleranceCount == 1)
        #expect(doc.dimTolToolToleranceCount == 1)
    }

    @Test("Multiple datums counted correctly")
    func multipleDatums() {
        let doc = Document.create()!
        _ = doc.createDatum(name: "Datum1")
        _ = doc.createDatum(name: "Datum2")
        _ = doc.createDatum(name: "Datum3")
        #expect(doc.datumCount == 3)
        #expect(doc.datums.count == 3)
        let names = doc.datums.map { $0.name }.sorted()
        #expect(names == ["Datum1", "Datum2", "Datum3"])
    }

    @Test("Datum mutators work through unified lookup")
    func datumMutatorsWork() {
        let doc = Document.create()!
        let idx = doc.createDatum(name: "DatumMut")!
        #expect(doc.setDatumPosition(at: idx, 2))
        #expect(doc.setDatumModifiers(at: idx, [.basic]))
        let datum = doc.datum(at: idx)!
        #expect(datum.position == 2)
        #expect(datum.modifiers.contains(.basic))
    }

    @Test("Datum name round-trips through unified lookup")
    func datumNameRoundTrip() {
        let doc = Document.create()!
        let idx = doc.createDatum(
            name:
                "VeryLongDatumNameThatExceedsTheOld64ByteBufferLimit1234567890")!
        let datum = doc.datum(at: idx)!
        #expect(datum.name == "VeryLongDatumNameThatExceedsTheOld64ByteBufferLimit1234567890")
    }

    @Test("Datum target operations work through unified lookup")
    func datumTargetOperations() {
        let doc = Document.create()!
        let idx = doc.createDatum(name: "DatumTarget")!
        #expect(doc.setDatumTarget(at: idx, type: .point, number: 1))
        #expect(
            doc.setDatumTargetPlacement(
                at: idx,
                location: SIMD3(1, 2, 3),
                normal: SIMD3(0, 0, 1),
                reference: SIMD3(1, 0, 0),
                length: 30,
                width: 18))
        let datum = doc.datum(at: idx)!
        #expect(datum.target != nil)
        #expect(datum.target?.type == .point)
        #expect(datum.target?.number == 1)
    }
}
