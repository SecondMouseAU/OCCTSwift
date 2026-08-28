import Foundation
import Testing

@testable import OCCTSwift

// MARK: - #996: one GD&T read surface, and OCCT's dimension kinds

@Suite("GD&T unified read surface (#996)")
struct GDTUnifiedReadTests {
    /// Author a box with a dimension, a tolerance and a datum, then read the SAME populated
    /// document through every accessor of the one read family. Before #996 there were two families
    /// whose coverage was exactly complementary: `GDTDocumentTests` tested the untyped one only
    /// where it returned nothing, `DocumentGDTTests` the typed one only where it returned
    /// something, so nothing would have caught them diverging.
    @Test("A populated document reads back through counts, singulars and plurals alike")
    func populatedDocumentReadsThroughOneFamily() {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        guard let box = Shape.box(width: 100, height: 50, depth: 25) else {
            Issue.record("box nil")
            return
        }
        let shapeId = doc.addShape(box, makeAssembly: false)
        doc.createDimension(
            on: shapeId, type: .sizeDiameter, value: 20.0,
            lowerTolerance: -0.3, upperTolerance: 0.7)
        doc.createGeomTolerance(on: shapeId, type: .perpendicularity, value: 0.05)
        doc.createDatum(name: "A")

        #expect(doc.dimensionCount == 1)
        #expect(doc.geomToleranceCount == 1)
        #expect(doc.datumCount == 1)
        #expect(doc.dimensions.count == doc.dimensionCount)
        #expect(doc.geomTolerances.count == doc.geomToleranceCount)
        #expect(doc.datums.count == doc.datumCount)

        // The plural accessor and the singular one describe the same entry, which is the property
        // two separate families could not be held to.
        if let single = doc.dimension(at: 0), let first = doc.dimensions.first {
            #expect(single == first)
            #expect(single.index == 0)
            #expect(single.type == .sizeDiameter)
        } else {
            Issue.record("dimension nil")
        }
        if let single = doc.geomTolerance(at: 0), let first = doc.geomTolerances.first {
            #expect(single == first)
            #expect(single.index == 0)
            #expect(single.type == .perpendicularity)
        } else {
            Issue.record("geomTolerance nil")
        }
        if let single = doc.datum(at: 0), let first = doc.datums.first {
            #expect(single == first)
            #expect(single.index == 0)
            #expect(single.name == "A")
        } else {
            Issue.record("datum nil")
        }
    }

    /// A range dimension (`IsDimWithRange()`, values array of length 2) used to read back as its
    /// lower bound mislabelled as the value, with both tolerances a fabricated 0, so it was
    /// indistinguishable from a plain 10 with no tolerance. Measured against the pinned kernel in
    /// `Scripts/repro/996-gdt-read-surface/`.
    @Test("A 10..12 range dimension reads back as a range, not as a plain 10")
    func rangeDimensionKeepsItsBounds() {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        guard let box = Shape.box(width: 100, height: 50, depth: 25) else {
            Issue.record("box nil")
            return
        }
        let shapeId = doc.addShape(box, makeAssembly: false)
        guard let idx = doc.createDimension(on: shapeId, type: .sizeDiameter, value: 10.0) else {
            Issue.record("createDimension nil")
            return
        }
        #expect(doc.setDimensionBounds(at: idx, lower: 10.0, upper: 12.0))

        guard let dim = doc.dimension(at: idx) else {
            Issue.record("dimension nil")
            return
        }
        #expect(dim.bounds == .range(lower: 10.0, upper: 12.0))
        #expect(dim.lowerBound == 10.0)
        #expect(dim.upperBound == 12.0)
        // OCCT's own GetValue() is the midpoint for a range, not the first array slot. This is the
        // assertion the pre-#996 bridge failed: it reported 10.
        #expect(dim.value.map { abs($0 - 11.0) < 1e-9 } == true)
        // The two tolerance accessors do not apply to a range, and now say so instead of returning
        // a 0 a caller cannot tell from a real zero tolerance.
        #expect(dim.lowerTolerance == nil)
        #expect(dim.upperTolerance == nil)
    }

    /// The tolerance pair is asymmetric on purpose. A symmetric -0.1/+0.1 cannot tell a correct
    /// accessor from a swapped one, and the pinned header's doc comments on
    /// `GetLowerTolValue`/`GetUpperTolValue` are swapped upstream. The functions are not; measured
    /// two ways in `Scripts/repro/996-gdt-read-surface/`.
    @Test("A plus/minus dimension keeps lower and upper tolerance the right way round")
    func plusMinusDimensionKeepsToleranceOrder() {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil")
            return
        }
        let shapeId = doc.addShape(box, makeAssembly: false)
        guard
            let idx = doc.createDimension(
                on: shapeId, type: .sizeRadius, value: 20.0,
                lowerTolerance: -0.3, upperTolerance: 0.7)
        else {
            Issue.record("createDimension nil")
            return
        }

        guard let dim = doc.dimension(at: idx) else {
            Issue.record("dimension nil")
            return
        }
        #expect(dim.bounds == .plusMinus(lowerTolerance: -0.3, upperTolerance: 0.7))
        #expect(dim.lowerTolerance == -0.3)
        #expect(dim.upperTolerance == 0.7)
        #expect(dim.value.map { abs($0 - 20.0) < 1e-9 } == true)
        // A plus/minus dimension is not a range, and the bound accessors say so.
        #expect(dim.lowerBound == nil)
        #expect(dim.upperBound == nil)
    }

    /// A dimension with no tolerance of any kind: one values slot, and every inapplicable accessor
    /// nil rather than 0.
    @Test("A simple dimension reports .simple and no bounds or tolerances")
    func simpleDimensionHasNoBoundsOrTolerances() {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil")
            return
        }
        let shapeId = doc.addShape(box, makeAssembly: false)
        guard let idx = doc.createDimension(on: shapeId, type: .sizeThickness, value: 3.5) else {
            Issue.record("createDimension nil")
            return
        }

        guard let dim = doc.dimension(at: idx) else {
            Issue.record("dimension nil")
            return
        }
        #expect(dim.bounds == .simple)
        #expect(dim.value.map { abs($0 - 3.5) < 1e-9 } == true)
        #expect(dim.lowerBound == nil)
        #expect(dim.upperBound == nil)
        #expect(dim.lowerTolerance == nil)
        #expect(dim.upperTolerance == nil)
        #expect(dim.classOfTolerance == nil)
    }

    /// The third kind, an ISO 286 class of tolerance, set independently of the values array
    /// (`IsDimWithClassOfTolerance()` reads the form variance, not the array length).
    @Test("An H7 hole dimension reports its ISO 286 class of tolerance")
    func classOfToleranceIsReadBack() {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil")
            return
        }
        let shapeId = doc.addShape(box, makeAssembly: false)
        guard let idx = doc.createDimension(on: shapeId, type: .sizeDiameter, value: 20.0) else {
            Issue.record("createDimension nil")
            return
        }
        #expect(
            doc.setDimensionClassOfTolerance(at: idx, isHole: true, formVariance: .h, grade: .it7))

        guard let dim = doc.dimension(at: idx) else {
            Issue.record("dimension nil")
            return
        }
        guard let cls = dim.classOfTolerance else {
            Issue.record("classOfTolerance nil")
            return
        }
        #expect(cls.isHole)
        #expect(cls.formVariance == .h)
        #expect(cls.grade == .it7)
        // A class of tolerance leaves the values array alone, so this is still a simple value.
        #expect(dim.bounds == .simple)
    }

    /// A class of tolerance is orthogonal to the values array, so a range dimension can carry one.
    /// This is the second construction for `classOfToleranceIsReadBack`: same class, different
    /// bounds, which is what proves the two are independent rather than the class implying
    /// `.simple`.
    @Test("A range dimension can also carry a class of tolerance")
    func rangeDimensionCanCarryAClassOfTolerance() {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil")
            return
        }
        let shapeId = doc.addShape(box, makeAssembly: false)
        guard let idx = doc.createDimension(on: shapeId, type: .sizeDiameter, value: 10.0) else {
            Issue.record("createDimension nil")
            return
        }
        #expect(doc.setDimensionBounds(at: idx, lower: 10.0, upper: 12.0))
        #expect(
            doc.setDimensionClassOfTolerance(at: idx, isHole: false, formVariance: .js, grade: .it9)
        )

        guard let dim = doc.dimension(at: idx) else {
            Issue.record("dimension nil")
            return
        }
        #expect(dim.bounds == .range(lower: 10.0, upper: 12.0))
        #expect(dim.classOfTolerance?.isHole == false)
        #expect(dim.classOfTolerance?.formVariance == .js)
        #expect(dim.classOfTolerance?.grade == .it9)
    }

    /// OCCT refuses to convert a range dimension to a plus/minus one, returning false from both
    /// setters and leaving the dimension untouched. The bridge used to discard those returns and
    /// report success for a call that changed nothing.
    @Test("Setting a tolerance on a range dimension is refused, not silently ignored")
    func toleranceOnARangeDimensionIsRefused() {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box nil")
            return
        }
        let shapeId = doc.addShape(box, makeAssembly: false)
        guard let idx = doc.createDimension(on: shapeId, type: .sizeDiameter, value: 10.0) else {
            Issue.record("createDimension nil")
            return
        }
        #expect(doc.setDimensionBounds(at: idx, lower: 10.0, upper: 12.0))
        #expect(doc.setDimensionTolerance(at: idx, lower: -0.3, upper: 0.7) == false)
        // Refused means unchanged, not partly applied.
        #expect(doc.dimension(at: idx)?.bounds == .range(lower: 10.0, upper: 12.0))
    }

    /// Every mutator declines an index no dimension occupies, rather than reporting success.
    @Test("The dimension mutators reject an out-of-range index")
    func mutatorsRejectAnOutOfRangeIndex() {
        guard let doc = Document.create() else {
            Issue.record("doc nil")
            return
        }
        #expect(doc.setDimensionTolerance(at: 0, lower: -0.1, upper: 0.1) == false)
        #expect(doc.setDimensionBounds(at: 0, lower: 1.0, upper: 2.0) == false)
        #expect(
            doc.setDimensionClassOfTolerance(
                at: 0, isHole: true, formVariance: .h, grade: .it7) == false)
        #expect(doc.setDimensionBounds(at: -1, lower: 1.0, upper: 2.0) == false)
    }

    @Test("DimensionFormVariance enum covers all 29 cases")
    func formVarianceEnumComplete() {
        #expect(Document.DimensionFormVariance.allCases.count == 29)
    }

    @Test("DimensionGrade enum covers all 20 cases")
    func gradeEnumComplete() {
        #expect(Document.DimensionGrade.allCases.count == 20)
    }
}
