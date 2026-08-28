import Foundation
import Testing

@testable import OCCTSwift

// MARK: - v0.140: XCAFDoc GD&T write path

@Suite("v0.140 Document GD&T write path")
struct DocumentGDTTests {

    /// Review finding: `setDimensionBounds` returned `true` on a plus/minus dimension.
    ///
    /// `SetLowerBound`/`SetUpperBound` branch on `myVal->Length() > 1`. From a length-3
    /// plus/minus array they write in place, so the requested upper bound landed in the
    /// lower tolerance slot, the stale upper tolerance survived, the dimension stayed
    /// plus/minus, and the call reported success. The sibling `setDimensionTolerance`
    /// had a readback check for the opposite conversion and this one did not.
    @Test("setDimensionBounds refuses a plus/minus dimension instead of corrupting it")
    func setDimensionBoundsRefusesPlusMinus() throws {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil")
            return
        }
        let labelId = doc.addShape(box, makeAssembly: false)
        guard
            let idx = doc.createDimension(
                on: labelId, type: .sizeDiameter, value: 20.0,
                lowerTolerance: -0.3, upperTolerance: 0.7)
        else {
            Issue.record("createDimension nil")
            return
        }
        #expect(doc.setDimensionBounds(at: idx, lower: 10.0, upper: 12.0) == false)
        if let dim = doc.dimension(at: idx) {
            #expect(dim.bounds == .plusMinus(lowerTolerance: -0.3, upperTolerance: 0.7))
            #expect(dim.value == 20.0)
        }
    }

    /// The simple-to-range conversion the mutator is for still works.
    @Test("setDimensionBounds still converts a simple dimension to a range")
    func setDimensionBoundsConvertsSimple() throws {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil")
            return
        }
        let labelId = doc.addShape(box, makeAssembly: false)
        guard let idx = doc.createDimension(on: labelId, type: .sizeDiameter, value: 20.0)
        else {
            Issue.record("createDimension nil")
            return
        }
        #expect(doc.setDimensionBounds(at: idx, lower: 10.0, upper: 12.0) == true)
        if let dim = doc.dimension(at: idx) {
            #expect(dim.bounds == .range(lower: 10.0, upper: 12.0))
        }
    }
    @Test("Create dimension on a box shape and read it back")
    func createAndReadDimension() throws {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        guard let box = Shape.box(width: 100, height: 50, depth: 25) else {
            Issue.record("box nil")
            return
        }
        let labelId = doc.addShape(box, makeAssembly: false)
        #expect(labelId >= 0)

        let idx = doc.createDimension(
            on: labelId,
            type: .sizeRadius,
            value: 25.0,
            lowerTolerance: -0.1,
            upperTolerance: 0.1)
        #expect(idx == 0)
        #expect(doc.dimensionCount == 1)

        if let dim = doc.dimension(at: 0) {
            #expect(dim.type == .sizeRadius)
            #expect(dim.value.map { abs($0 - 25.0) < 1e-9 } == true)
            #expect(dim.bounds == .plusMinus(lowerTolerance: -0.1, upperTolerance: 0.1))
            #expect(dim.lowerTolerance.map { abs($0 - (-0.1)) < 1e-9 } == true)
            #expect(dim.upperTolerance.map { abs($0 - 0.1) < 1e-9 } == true)
        } else {
            Issue.record("dimension nil")
        }
    }

    @Test("Create geometric tolerance (flatness) on a shape")
    func createTolerance() throws {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil")
            return
        }
        let labelId = doc.addShape(box, makeAssembly: false)
        let idx = doc.createGeomTolerance(on: labelId, type: .flatness, value: 0.01)
        #expect(idx == 0)
        if let tol = doc.geomTolerance(at: 0) {
            #expect(tol.type == .flatness)
            #expect(abs(tol.value - 0.01) < 1e-9)
        } else {
            Issue.record("geomTolerance nil")
        }
    }

    @Test("Create datum A")
    func createDatum() throws {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        let idx = doc.createDatum(name: "A")
        #expect(idx == 0)
        if let datum = doc.datum(at: 0) {
            #expect(datum.name == "A")
        } else {
            Issue.record("datum nil")
        }
    }

    @Test("Full authoring: box + 3 dimensions + 2 tolerances + 2 datums")
    func fullAuthoring() throws {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        guard let box = Shape.box(width: 100, height: 50, depth: 25) else {
            Issue.record("box nil")
            return
        }
        let shapeId = doc.addShape(box, makeAssembly: false)
        doc.createDimension(on: shapeId, type: .sizeDiameter, value: 10.0)
        doc.createDimension(on: shapeId, type: .locationLinearDistance, value: 50.0)
        doc.createDimension(on: shapeId, type: .sizeRadius, value: 5.0)
        doc.createGeomTolerance(on: shapeId, type: .flatness, value: 0.01)
        doc.createGeomTolerance(on: shapeId, type: .perpendicularity, value: 0.05)
        doc.createDatum(name: "A")
        doc.createDatum(name: "B")

        #expect(doc.dimensionCount == 3)
        #expect(doc.geomToleranceCount == 2)
        #expect(doc.datumCount == 2)
        #expect(doc.dimensions.count == 3)
        #expect(doc.dimensions.map(\.type).contains(.sizeDiameter))
        #expect(doc.geomTolerances.map(\.type).contains(.perpendicularity))
        #expect(doc.datums.map(\.name).sorted() == ["A", "B"])
    }

    @Test("DimensionType enum covers all 32 cases")
    func dimensionTypeEnumComplete() {
        #expect(Document.DimensionType.allCases.count == 32)
    }

    @Test("GeomToleranceType enum covers all 16 cases")
    func geomToleranceTypeEnumComplete() {
        #expect(Document.GeomToleranceType.allCases.count == 16)
    }
}
