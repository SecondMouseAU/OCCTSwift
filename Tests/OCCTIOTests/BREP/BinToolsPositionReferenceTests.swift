import Foundation
import Testing

@testable import OCCTSwift

// The binary shape reader (`BinTools_ShapeReader`, behind `Shape.fromBinaryData` and
// `Shape.loadBinary`) reads a shape, location, curve, surface, polygon or triangulation either
// inline or from a position earlier in the file, and trusted that position and the byte after it:
//
//  - a delta that reached past the start of the stream wrapped to a position near 2^64;
//  - a reference to a shape that was still being read was read again from inside itself, and a
//    compound that referred to the compound holding it recursed until the stack ended;
//  - a reference to a null shape returned a null that the caller took for the end of its list;
//  - the byte after a shape reference was cast to an orientation without a range check, and a shape
//    with the orientation 255 faulted in `TopExp_Explorer`;
//  - a record of another kind in a location, curve or surface slot was read as an empty one, which
//    kept the rest of the file in step with a structure the writer never wrote.
//
// Carried patch `0076` refuses each. The streams below are written by hand from the format of
// `BinTools_ShapeWriter`, where a record is a type byte, a location, a byte of flags and its
// sub-shapes up to an end byte, and a reference is a type byte, a delta back to the start of the
// record it names, a location and an orientation:
//
//     C8 07 00 ...  a forward compound with no location and no flags, then its sub-shapes
//     C7            the end of a sub-shape list
//     01 dd 07 oo   a reference `dd` bytes back, no location, orientation `oo`
//
// They are gated on `OCCTSWIFT_LOCAL=1` while the pinned asset lacks `0076`;
// `kernel-integration.yml` runs them. The gate comes off at the repin that pins it. The stream
// that is read back whole is the control: a reader that refused every reference would pass the
// rest.
@Suite("BinTools shape reader keeps to the stream", .serialized)
struct BinToolsPositionReferenceTests {

    private static let isLocalKernel = ProcessInfo.processInfo.environment["OCCTSWIFT_LOCAL"] == "1"

    private static let compound: [UInt8] = [0xC8, 0x07, 0x00]
    private static let end: UInt8 = 0xC7

    /// A compound of one empty compound and a reference to it that ends in `orientation`.
    private static func compoundWithReference(orientation: UInt8) -> Data {
        // 0..2 root, 3..6 the empty compound, 7..10 the reference to 3, 11 the end of the root.
        Data(compound + compound + [end] + [0x01, 0x04, 0x07, orientation] + [end])
    }

    private static func read(_ bytes: [UInt8]) -> Shape? {
        Shape.fromBinaryData(Data(bytes))
    }

    @Test(.enabled(if: BinToolsPositionReferenceTests.isLocalKernel))
    func aShapeThatTheWriterWroteReadsBack() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let moved = try #require(box.translated(by: SIMD3(40, 0, 0)))
        // The shared sub-shapes and the located copy are references and locations in the file.
        let both = try #require(Shape.compound([box, moved, box]))
        let data = try #require(both.toBinaryData())
        let back = try #require(Shape.fromBinaryData(data))
        #expect(back.isValid)
        #expect(back.subShapeCount(ofType: .solid) == both.subShapeCount(ofType: .solid))
        #expect(back.subShapeCount(ofType: .face) == both.subShapeCount(ofType: .face))
        let volume = try #require(back.volume)
        #expect(abs(volume - 18000) < 1e-6)
    }

    @Test(.enabled(if: BinToolsPositionReferenceTests.isLocalKernel))
    func aReferenceToAShapeAlreadyReadIsTheSameShape() throws {
        let shape = try #require(Self.read(Array(Self.compoundWithReference(orientation: 0))))
        #expect(shape.shapeType == .compound)
        // The orientations the enumeration has: forward, reversed, internal, external.
        for orientation: UInt8 in 0...3 {
            #expect(
                Shape.fromBinaryData(Self.compoundWithReference(orientation: orientation)) != nil,
                "orientation \(orientation)")
        }
    }

    /// The byte after a reference is an orientation; 4 and above are not one.
    @Test(.enabled(if: BinToolsPositionReferenceTests.isLocalKernel))
    func anOrientationThatTheEnumerationLacksIsRefused() {
        for orientation: UInt8 in [4, 5, 0x7F, 0x80, 0xFF] {
            #expect(
                Shape.fromBinaryData(Self.compoundWithReference(orientation: orientation)) == nil,
                "orientation \(orientation)")
        }
    }

    /// A compound whose sub-shape is a reference to the compound itself: 0..2 root, 3..4 the
    /// reference (delta 3 from the byte after its type reaches 0), 5..6 its location and
    /// orientation, 7 the end.
    @Test(.enabled(if: BinToolsPositionReferenceTests.isLocalKernel))
    func aReferenceToTheShapeThatHoldsItIsRefused() {
        #expect(Self.read(Self.compound + [0x01, 0x03, 0x07, 0x00, Self.end]) == nil)
    }

    /// The same cycle one level down: the reference names the compound that holds the compound
    /// that holds the reference.
    @Test(.enabled(if: BinToolsPositionReferenceTests.isLocalKernel))
    func aReferenceToAnEnclosingShapeTwoLevelsUpIsRefused() {
        // 0..2 root, 3..5 inner compound, 6..9 reference to 0 (the byte after the type is 7, so
        // the delta is 6), 10 the end of the inner, 11 the end of the root.
        let bytes = Self.compound + Self.compound + [0x01, 0x06, 0x07, 0x00, Self.end, Self.end]
        #expect(Self.read(bytes) == nil)
    }

    /// A delta larger than the position of the reference, which reaches before the start of the
    /// stream: it wrapped to a position near 2^64.
    @Test(.enabled(if: BinToolsPositionReferenceTests.isLocalKernel))
    func aReferenceBeforeTheStartOfTheStreamIsRefused() {
        for delta: UInt8 in [4, 9, 0x80, 0xFF] {
            let bytes = Self.compound + [0x01, delta, 0x07, 0x00, Self.end]
            #expect(Self.read(bytes) == nil, "delta \(delta)")
        }
        // A zero delta names the reference itself.
        #expect(Self.read(Self.compound + [0x01, 0x00, 0x07, 0x00, Self.end]) == nil)
    }

    /// A chain of references to references recurses once per link; the writer never writes one.
    @Test(.enabled(if: BinToolsPositionReferenceTests.isLocalKernel))
    func aReferenceToAReferenceIsRefused() {
        // 0..2 root, 3..6 the empty compound, 7..10 a reference to 3, 11..14 a reference to 7.
        let bytes =
            Self.compound + Self.compound + [Self.end] + [0x01, 0x04, 0x07, 0x00]
            + [0x01, 0x04, 0x07, 0x00, Self.end]
        #expect(Self.read(bytes) == nil)
    }

    /// A reference to the end byte of a list returned a null that closed the list of the caller.
    @Test(.enabled(if: BinToolsPositionReferenceTests.isLocalKernel))
    func aReferenceToTheEndOfAListIsRefused() {
        // 0..2 root, 3..6 the empty compound with its end byte at 6, 7..10 a reference to 6.
        let bytes =
            Self.compound + Self.compound + [Self.end] + [0x01, 0x01, 0x07, 0x00, Self.end]
        #expect(Self.read(bytes) == nil)
    }

    /// A record type that belongs to another slot is not an empty location.
    @Test(.enabled(if: BinToolsPositionReferenceTests.isLocalKernel))
    func aLocationSlotHoldingAnotherKindOfRecordIsRefused() {
        // 0x09 is the type byte of a curve.
        #expect(Self.read([0xC8, 0x09, 0x00, Self.end]) == nil)
        // The control: the same compound with the empty location it should have.
        #expect(Self.read([0xC8, 0x07, 0x00, Self.end]) != nil)
    }
}
