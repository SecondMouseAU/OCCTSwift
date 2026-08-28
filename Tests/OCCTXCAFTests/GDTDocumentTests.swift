import Foundation
import Testing

@testable import OCCTSwift

// MARK: - v0.21.0 GD&T Tests

@Suite("GD&T Document Tests")
struct GDTDocumentTests {
    @Test("Empty document has zero dimensions")
    func emptyDocDimensions() {
        guard let doc = Document.create() else {
            Issue.record("Could not create document")
            return
        }
        #expect(doc.dimensionCount == 0)
        #expect(doc.dimensions.isEmpty)
    }

    @Test("Empty document has zero geometric tolerances")
    func emptyDocTolerances() {
        guard let doc = Document.create() else {
            Issue.record("Could not create document")
            return
        }
        #expect(doc.geomToleranceCount == 0)
        #expect(doc.geomTolerances.isEmpty)
    }

    @Test("Empty document has zero datums")
    func emptyDocDatums() {
        guard let doc = Document.create() else {
            Issue.record("Could not create document")
            return
        }
        #expect(doc.datumCount == 0)
        #expect(doc.datums.isEmpty)
    }

    @Test("Dimension at invalid index returns nil")
    func dimensionInvalidIndex() {
        guard let doc = Document.create() else {
            Issue.record("Could not create document")
            return
        }
        #expect(doc.dimension(at: 0) == nil)
        #expect(doc.dimension(at: -1) == nil)
        #expect(doc.dimension(at: 999) == nil)
    }

    @Test("Geom tolerance at invalid index returns nil")
    func toleranceInvalidIndex() {
        guard let doc = Document.create() else {
            Issue.record("Could not create document")
            return
        }
        #expect(doc.geomTolerance(at: 0) == nil)
        #expect(doc.geomTolerance(at: -1) == nil)
    }

    @Test("Datum at invalid index returns nil")
    func datumInvalidIndex() {
        guard let doc = Document.create() else {
            Issue.record("Could not create document")
            return
        }
        #expect(doc.datum(at: 0) == nil)
        #expect(doc.datum(at: -1) == nil)
    }
}
