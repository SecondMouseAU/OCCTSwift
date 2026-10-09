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
    func qualifierRoundTrips() throws {
        let (doc, index) = try #require(documentWithDimension(), "document nil")

        // A dimension nobody qualified is nominal. This is also the assertion that holds
        // OCCTDocumentCreateDimension to handing OCCT a neutral qualifier rather than whatever
        // its uninitialised member happened to hold.
        let fresh = try #require(doc.dimension(at: index), "dimension nil before qualifier")
        #expect(fresh.qualifier == .none)
        #expect(fresh.angularQualifier == Document.AngularQualifier.none)
        // What was created: a diameter of 20, not some other type or value.
        #expect(fresh.type == .sizeDiameter)
        #expect(fresh.value == 20.0)

        #expect(doc.setDimensionQualifier(at: index, .max))
        let qualified = try #require(doc.dimension(at: index), "dimension nil after qualifier")
        #expect(qualified.qualifier == .max)
        // The qualifier is independent of the magnitude, so nothing else may move with it,
        // and in particular the other qualifier does not follow it.
        #expect(qualified.value == 20.0)
        #expect(qualified.bounds == .simple)
        #expect(qualified.type == .sizeDiameter)
        #expect(qualified.angularQualifier == Document.AngularQualifier.none)

        #expect(doc.setDimensionQualifier(at: index, .none))
        // Spelled out rather than as `?.qualifier == .none`: through an optional chain that `.none`
        // resolves to `Optional.none`, so the comparison would pass for a nil dimension too.
        #expect(doc.dimension(at: index)?.qualifier == Document.DimensionQualifier.none)
    }

    @Test("An angular qualifier round-trips independently of the dimension qualifier")
    func angularQualifierRoundTrips() throws {
        let (doc, index) = try #require(
            documentWithDimension(type: .sizeAngular, value: 45.0), "document nil")
        #expect(doc.dimension(at: index)?.angularQualifier == Document.AngularQualifier.none)
        #expect(doc.dimension(at: index)?.type == .sizeAngular)

        // Each alone first, so a write that lands on the other member is seen in isolation.
        #expect(doc.setDimensionAngularQualifier(at: index, .large))
        let onlyAngular = try #require(doc.dimension(at: index))
        #expect(onlyAngular.angularQualifier == .large)
        #expect(onlyAngular.qualifier == Document.DimensionQualifier.none)
        #expect(doc.setDimensionAngularQualifier(at: index, .none))
        #expect(doc.setDimensionQualifier(at: index, .min))
        let onlyQualifier = try #require(doc.dimension(at: index))
        #expect(onlyQualifier.qualifier == .min)
        #expect(onlyQualifier.angularQualifier == Document.AngularQualifier.none)

        #expect(doc.setDimensionAngularQualifier(at: index, .large))
        let both = try #require(doc.dimension(at: index))
        // Two separate OCCT members, so the pair proves neither accessor is reading the other.
        #expect(both.qualifier == .min)
        #expect(both.angularQualifier == .large)
        #expect(both.type == .sizeAngular)
        #expect(both.value == 45.0)
    }

    /// OCCT answers a flat (0, 0) from GetNbOfDecimalPlaces for a dimension that never had a pair,
    /// which is indistinguishable from a real (0, 0) request.
    ///
    /// The stored/not-stored condition is
    /// the only thing that separates them, so `decimalPlaces` is nil rather than a fabricated zero.
    @Test("Decimal places read back as written, and as nil when never written")
    func decimalPlacesDistinguishAbsenceFromZero() throws {
        let (doc, index) = try #require(documentWithDimension(), "document nil")
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

        // And the mirror of it: a zero on the right only is stored too.
        #expect(doc.setDimensionDecimalPlaces(at: index, left: 3, right: 0))
        if let places = doc.dimension(at: index)?.decimalPlaces {
            #expect(places.left == 3)
            #expect(places.right == 0)
        } else {
            Issue.record("decimalPlaces nil after writing (3, 0)")
        }

        #expect(doc.setDimensionDecimalPlaces(at: index, left: 0, right: 0))
        #expect(doc.dimension(at: index)?.decimalPlaces == nil)
    }

    @Test("A modifier sequence round-trips in order, and clears")
    func modifiersRoundTripInOrder() throws {
        let (doc, index) = try #require(documentWithDimension(), "document nil")
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
    /// presentation types.
    ///
    /// Asked of OCCT rather than of a hand-written case list.
    @Test("The dimension type classifiers agree with OCCT for a location, a size and neither")
    func typeClassifiersMatchOCCT() {
        #expect(Document.DimensionType.locationLinearDistance.isDimensionalLocation)
        #expect(!Document.DimensionType.locationLinearDistance.isDimensionalSize)

        #expect(Document.DimensionType.sizeDiameter.isDimensionalSize)
        #expect(!Document.DimensionType.sizeDiameter.isDimensionalLocation)

        // commonLabel is neither, which is the reading a two-way partition would get wrong.
        #expect(!Document.DimensionType.commonLabel.isDimensionalLocation)
        #expect(!Document.DimensionType.commonLabel.isDimensionalSize)

        // Every case, against the two predicates as OCCT writes them
        // (XCAFDimTolObjects_DimensionObject.cxx, IsDimensionalLocation / IsDimensionalSize), as
        // ordinals of the enum in XCAFDimTolObjects_DimensionType.hxx: a location is Location_None
        // through Location_LinearDistance_FromInnerToInner (0...10) and Location_Oriented (12); a
        // size is Size_CurveLength through Size_Thickness (14...27). The four types in neither are
        // Location_Angular (11), Location_WithPath (13), Size_Angular (28) and Size_WithPath (29),
        // plus CommonLabel (30) and DimensionPresentation (31). The 32 cases are all the enum has.
        // That the Swift raw values are those ordinals is not assumed here: `derive-gdt-enums.py
        // --verify` (a required static gate) checks every member against the pinned header.
        #expect(Document.DimensionType.allCases.count == 32)
        for type in Document.DimensionType.allCases {
            let ordinal = Int(type.rawValue)
            let isLocation = (0...10).contains(ordinal) || ordinal == 12
            let isSize = (14...27).contains(ordinal)
            #expect(type.isDimensionalLocation == isLocation, "\(type) as a location")
            #expect(type.isDimensionalSize == isSize, "\(type) as a size")
        }
        #expect(!Document.DimensionType.locationAngular.isDimensionalLocation)
        #expect(!Document.DimensionType.locationWithPath.isDimensionalLocation)
        #expect(!Document.DimensionType.sizeAngular.isDimensionalSize)
        #expect(!Document.DimensionType.sizeWithPath.isDimensionalSize)
        #expect(Document.DimensionType.locationOriented.isDimensionalLocation)
        #expect(Document.DimensionType.sizeThickness.isDimensionalSize)
    }

    /// The accessors are per-dimension, so a document with two of them must not report one's
    /// answers for the other.
    @Test("Two dimensions on one document keep their own accessor values")
    func accessorsAreNotSharedBetweenDimensions() throws {
        let doc = try #require(Document.create(), "document nil")
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let shapeId = doc.addShape(box, makeAssembly: false)
        let first = try #require(doc.createDimension(on: shapeId, type: .sizeDiameter, value: 20.0))
        let second = try #require(doc.createDimension(on: shapeId, type: .sizeRadius, value: 5.0))

        #expect(doc.setDimensionQualifier(at: first, .max))
        #expect(doc.setDimensionModifiers(at: first, [.square]))
        #expect(doc.setDimensionDecimalPlaces(at: second, left: 1, right: 1))

        let a = try #require(doc.dimension(at: first))
        let b = try #require(doc.dimension(at: second))
        // Each is what it was created as, so one read for the other shows in the type and value.
        #expect(a.type == .sizeDiameter)
        #expect(a.value == 20.0)
        #expect(a.qualifier == .max)
        #expect(a.modifiers == [.square])
        #expect(a.decimalPlaces == nil)

        #expect(b.type == .sizeRadius)
        #expect(b.value == 5.0)
        #expect(b.qualifier == Document.DimensionQualifier.none)
        #expect(b.modifiers.isEmpty)
        #expect(b.decimalPlaces?.left == 1)
        #expect(b.decimalPlaces?.right == 1)
    }

    /// An out-of-range index answers nothing rather than reading a neighbouring dimension, and the
    /// mutators refuse rather than reporting a write nobody made.
    @Test("Out-of-range indices are refused by both the accessors and the mutators")
    func outOfRangeIndicesAreRefused() throws {
        let (doc, _) = try #require(documentWithDimension(), "document nil")
        // Control: index 0 is a real dimension, so the refusals below are about the index.
        #expect(doc.dimension(at: 0) != nil)
        #expect(doc.dimension(at: 1) == nil)
        #expect(doc.dimension(at: -1) == nil)
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
