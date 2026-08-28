import Foundation
import Testing

@testable import OCCTSwift

@Suite("GD&T dimension accessors (#1004)")
struct GDTDimensionAccessorTests {
    /// A box with one dimension on it, which is the smallest document that can carry an accessor.
    private func documentWithDimension(
        type: Document.DimensionType = .sizeDiameter,
        value: Double = 20.0
    ) -> (Document, Int)? {
        guard let doc = Document.create(), let box = Shape.box(width: 100, height: 50, depth: 25)
        else { return nil }
        let shapeId = doc.addShape(box, makeAssembly: false)
        guard let index = doc.createDimension(on: shapeId, type: type, value: value) else {
            return nil
        }
        return (doc, index)
    }

    /// The qualifier changes what the number means: 20 nominal and 20 maximum are different
    /// dimensions, and before #1004 both read back identically because the accessor was unwrapped.
    @Test("A qualifier written on a dimension reads back, and an unqualified one reads .none")
    func qualifierRoundTrips() {
        guard let (doc, index) = documentWithDimension() else {
            Issue.record("document nil")
            return
        }

        // A dimension nobody qualified is nominal. This is also the assertion that holds
        // OCCTDocumentCreateDimension to handing OCCT a neutral qualifier rather than whatever
        // its uninitialised member happened to hold.
        if let fresh = doc.dimension(at: index) {
            #expect(fresh.qualifier == .none)
        } else {
            Issue.record("dimension nil before qualifier")
        }

        #expect(doc.setDimensionQualifier(at: index, .max))
        if let qualified = doc.dimension(at: index) {
            #expect(qualified.qualifier == .max)
            // The qualifier is independent of the magnitude, so nothing else may move with it.
            #expect(qualified.value == 20.0)
            #expect(qualified.bounds == .simple)
        } else {
            Issue.record("dimension nil after qualifier")
        }

        #expect(doc.setDimensionQualifier(at: index, .none))
        // Spelled out rather than as `?.qualifier == .none`: through an optional chain that `.none`
        // resolves to `Optional.none`, so the comparison would pass for a nil dimension too.
        #expect(doc.dimension(at: index)?.qualifier == Document.DimensionQualifier.none)
    }

    @Test("An angular qualifier round-trips independently of the dimension qualifier")
    func angularQualifierRoundTrips() {
        guard let (doc, index) = documentWithDimension(type: .sizeAngular, value: 45.0) else {
            Issue.record("document nil")
            return
        }
        #expect(doc.dimension(at: index)?.angularQualifier == Document.AngularQualifier.none)

        #expect(doc.setDimensionQualifier(at: index, .min))
        #expect(doc.setDimensionAngularQualifier(at: index, .large))
        if let both = doc.dimension(at: index) {
            // Two separate OCCT members, so the pair proves neither accessor is reading the other.
            #expect(both.qualifier == .min)
            #expect(both.angularQualifier == .large)
        } else {
            Issue.record("dimension nil")
        }
    }

    /// OCCT answers a flat (0, 0) from GetNbOfDecimalPlaces for a dimension that never had a pair,
    /// which is indistinguishable from a real (0, 0) request. The stored/not-stored condition is
    /// the only thing that separates them, so `decimalPlaces` is nil rather than a fabricated zero.
    @Test("Decimal places read back as written, and as nil when never written")
    func decimalPlacesDistinguishAbsenceFromZero() {
        guard let (doc, index) = documentWithDimension() else {
            Issue.record("document nil")
            return
        }
        #expect(doc.dimension(at: index)?.decimalPlaces == nil)

        #expect(doc.setDimensionDecimalPlaces(at: index, left: 2, right: 3))
        if let places = doc.dimension(at: index)?.decimalPlaces {
            // Asymmetric on purpose: 2 and 3 tell a correct pair from a swapped one.
            #expect(places.left == 2)
            #expect(places.right == 3)
        } else {
            Issue.record("decimalPlaces nil after writing (2, 3)")
        }

        // A zero on one side only is still a stored pair, since OCCT keeps it when either is
        // positive. This is the case a "nil when either is zero" rule would get wrong.
        #expect(doc.setDimensionDecimalPlaces(at: index, left: 0, right: 4))
        if let places = doc.dimension(at: index)?.decimalPlaces {
            #expect(places.left == 0)
            #expect(places.right == 4)
        } else {
            Issue.record("decimalPlaces nil after writing (0, 4)")
        }

        #expect(doc.setDimensionDecimalPlaces(at: index, left: 0, right: 0))
        #expect(doc.dimension(at: index)?.decimalPlaces == nil)
    }

    @Test("A modifier sequence round-trips in order, and clears")
    func modifiersRoundTripInOrder() {
        guard let (doc, index) = documentWithDimension() else {
            Issue.record("document nil")
            return
        }
        #expect(doc.dimension(at: index)?.modifiers.isEmpty == true)

        // Three, in an order that is not the enum's own, so a sequence rebuilt by sorting or by
        // raw value rather than by position reads back differently from what was written.
        let written: [Document.DimensionModifier] = [
            .anyCrossSection, .square, .statisticalTolerance,
        ]
        #expect(doc.setDimensionModifiers(at: index, written))
        #expect(doc.dimension(at: index)?.modifiers == written)

        #expect(doc.setDimensionModifiers(at: index, []))
        #expect(doc.dimension(at: index)?.modifiers.isEmpty == true)
    }

    /// The two static classifiers partition most of DimensionType, and neither holds for the two
    /// presentation types. Asked of OCCT rather than of a hand-written case list.
    @Test("The dimension type classifiers agree with OCCT for a location, a size and neither")
    func typeClassifiersMatchOCCT() {
        #expect(Document.DimensionType.locationLinearDistance.isDimensionalLocation)
        #expect(!Document.DimensionType.locationLinearDistance.isDimensionalSize)

        #expect(Document.DimensionType.sizeDiameter.isDimensionalSize)
        #expect(!Document.DimensionType.sizeDiameter.isDimensionalLocation)

        // commonLabel is neither, which is the reading a two-way partition would get wrong.
        #expect(!Document.DimensionType.commonLabel.isDimensionalLocation)
        #expect(!Document.DimensionType.commonLabel.isDimensionalSize)

        // Every case answers something, and no case answers both.
        for type in Document.DimensionType.allCases {
            #expect(!(type.isDimensionalLocation && type.isDimensionalSize))
        }
    }

    /// The accessors are per-dimension, so a document with two of them must not report one's
    /// answers for the other.
    @Test("Two dimensions on one document keep their own accessor values")
    func accessorsAreNotSharedBetweenDimensions() {
        guard let doc = Document.create(), let box = Shape.box(width: 10, height: 10, depth: 10)
        else {
            Issue.record("document nil")
            return
        }
        let shapeId = doc.addShape(box, makeAssembly: false)
        guard let first = doc.createDimension(on: shapeId, type: .sizeDiameter, value: 20.0),
            let second = doc.createDimension(on: shapeId, type: .sizeRadius, value: 5.0)
        else {
            Issue.record("createDimension nil")
            return
        }

        #expect(doc.setDimensionQualifier(at: first, .max))
        #expect(doc.setDimensionModifiers(at: first, [.square]))
        #expect(doc.setDimensionDecimalPlaces(at: second, left: 1, right: 1))

        if let a = doc.dimension(at: first), let b = doc.dimension(at: second) {
            #expect(a.qualifier == .max)
            #expect(a.modifiers == [.square])
            #expect(a.decimalPlaces == nil)

            #expect(b.qualifier == .none)
            #expect(b.modifiers.isEmpty)
            #expect(b.decimalPlaces?.left == 1)
            #expect(b.decimalPlaces?.right == 1)
        } else {
            Issue.record("dimension nil")
        }
    }

    /// An out-of-range index answers nothing rather than reading a neighbouring dimension, and the
    /// mutators refuse rather than reporting a write nobody made.
    @Test("Out-of-range indices are refused by both the accessors and the mutators")
    func outOfRangeIndicesAreRefused() {
        guard let (doc, _) = documentWithDimension() else {
            Issue.record("document nil")
            return
        }
        #expect(doc.dimension(at: 5) == nil)
        #expect(!doc.setDimensionQualifier(at: 5, .max))
        #expect(!doc.setDimensionAngularQualifier(at: 5, .large))
        #expect(!doc.setDimensionDecimalPlaces(at: 5, left: 1, right: 1))
        #expect(!doc.setDimensionModifiers(at: 5, [.square]))

        // A negative count cannot be expressed through the Swift API, but a negative place count
        // can, and OCCT would otherwise store it.
        #expect(!doc.setDimensionDecimalPlaces(at: 0, left: -1, right: 0))
    }
}
