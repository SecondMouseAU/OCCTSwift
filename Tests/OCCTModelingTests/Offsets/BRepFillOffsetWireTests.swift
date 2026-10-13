import Foundation
import Testing

@testable import OCCTSwift

// `Shape.offsetWire(face:offset:)` follows `BRepOffsetAPI_MakeOffset`'s own use of
// `BRepFill_OffsetWire`: positive offset is outward, negative inward, and each side is built on
// the domain MakeOffset builds for it (#3364). Before that it handed the face straight to
// `BRepFill_OffsetWire::Perform`, which only offsets to the inside of the face it is given, so
// +3 shrank a rectangle and -3 returned four untrimmed crossing segments.
@Suite("BRepFill OffsetWire Tests")
struct BRepFillOffsetWireTests {
    // The face of a 20 x 20 rectangle. The tests used to build this from `Shape.fromWire`, which
    // is a wire shape with no faces, so `if !faces.isEmpty` skipped the call and they passed
    // without reaching `offsetWire`.
    private func rectangleFace(width: Double = 20, height: Double = 20) throws -> Face {
        let wire = try #require(Wire.rectangle(width: width, height: height))
        let shape = try #require(Shape.face(from: wire))
        return try #require(shape.faces().first)
    }

    private func halfWidth(_ shape: Shape) throws -> Double {
        let bounds = try #require(shape.boundingBox)
        return (bounds.max.x - bounds.min.x) / 2
    }

    private func totalLength(_ shape: Shape) -> Double {
        shape.edges().reduce(0.0) { $0 + $1.length }
    }

    // Offset +3 is the outer wire: four lines 20 long, each moved 3 out, joined by four arcs of
    // radius 3 (the Arc join), so half-width 13 and length 4 * 20 + 2 pi 3.
    @Test("Offset planar wire outward")
    func offsetOutward() throws {
        let face = try rectangleFace()
        let result = try #require(Shape.offsetWire(face: face, offset: 3.0))
        #expect(result.shapeType == .wire)
        #expect(result.edges().count == 8)
        #expect(abs(try halfWidth(result) - 13.0) < 1e-6)
        #expect(abs(totalLength(result) - (80.0 + 2.0 * Double.pi * 3.0)) < 1e-6)
    }

    // Offset -3 is the inner wire: a closed 14 x 14 square, not the four untrimmed segments
    // 60 long that ran to +-30.
    @Test("Offset planar wire inward")
    func offsetInward() throws {
        let face = try rectangleFace()
        let result = try #require(Shape.offsetWire(face: face, offset: -3.0))
        #expect(result.shapeType == .wire)
        #expect(result.edges().count == 4)
        #expect(abs(try halfWidth(result) - 7.0) < 1e-6)
        #expect(abs(totalLength(result) - 56.0) < 1e-6)
        let bounds = try #require(result.boundingBox)
        #expect(bounds.max.x - bounds.min.x < 20.0)
        #expect(bounds.max.y - bounds.min.y < 20.0)
    }

    // The sign matches `offsetWireOnPlane`, which is `BRepOffsetAPI_MakeOffset` on the wire:
    // the same outline at the same distance for both signs and a non-square face.
    @Test("Both signs agree with BRepOffsetAPI_MakeOffset on the wire")
    func agreesWithMakeOffset() throws {
        let wire = try #require(Wire.rectangle(width: 10, height: 6))
        let wireShape = try #require(Shape.fromWire(wire))
        let face = try rectangleFace(width: 10, height: 6)
        for distance in [2.0, 0.5, -0.5, -2.0] {
            let viaFace = try #require(Shape.offsetWire(face: face, offset: distance))
            let viaWire = try #require(wireShape.offsetWireOnPlane(distance: distance))
            let a = try #require(viaFace.boundingBox)
            let b = try #require(viaWire.boundingBox)
            #expect(abs(a.min.x - b.min.x) < 1e-6, "offset \(distance)")
            #expect(abs(a.max.x - b.max.x) < 1e-6, "offset \(distance)")
            #expect(abs(a.min.y - b.min.y) < 1e-6, "offset \(distance)")
            #expect(abs(a.max.y - b.max.y) < 1e-6, "offset \(distance)")
            #expect(abs(totalLength(viaFace) - totalLength(viaWire)) < 1e-6, "offset \(distance)")
        }
    }

    // A large outward offset trims the same way: half-width 10 + 12.
    @Test("Large outward offset")
    func largeOutward() throws {
        let face = try rectangleFace()
        let result = try #require(Shape.offsetWire(face: face, offset: 12.0))
        #expect(result.shapeType == .wire)
        #expect(abs(try halfWidth(result) - 22.0) < 1e-6)
    }

    // Zero is not a side: it takes the `Offset <= 0` branch of BRepOffsetAPI_MakeOffset, the
    // inward one, and answers the face's own outline.
    @Test("Zero offset answers the outline unchanged")
    func zeroOffset() throws {
        let face = try rectangleFace()
        let result = try #require(Shape.offsetWire(face: face, offset: 0.0))
        #expect(result.edges().count == 4)
        #expect(abs(try halfWidth(result) - 10.0) < 1e-6)
        #expect(abs(totalLength(result) - 80.0) < 1e-6)
    }

    // An inward offset past the inradius collapses the face (the 20 x 20 rectangle's inradius is
    // 10, the offset here is -12). OCCT reports done with an empty
    // compound there (BRepOffsetAPI_MakeOffset does the same); the wrapper refuses it, since an
    // empty compound is no wire and read as a successful offset.
    @Test("Inward offset of 12 past the inradius of 10 is refused")
    func collapsedIsRefused() throws {
        let face = try rectangleFace()
        #expect(Shape.offsetWire(face: face, offset: -12.0) == nil)
    }

    @Test("Non-finite offset is refused")
    func nonFiniteIsRefused() throws {
        let face = try rectangleFace()
        #expect(Shape.offsetWire(face: face, offset: .nan) == nil)
        #expect(Shape.offsetWire(face: face, offset: .infinity) == nil)
    }

    // A face with a hole. Outward is the direction of the material: the outer wire grows and the
    // hole shrinks, so the hole's circle goes from radius 5 to 3 for +2 and to 7 for -2.
    @Test("Face with a hole offsets outer wire and hole in opposite senses")
    func faceWithHole() throws {
        let outer = try #require(Wire.rectangle(width: 40, height: 40))
        let hole = try #require(Wire.circle(radius: 5))
        let shape = try #require(Shape.face(outer: outer, holes: [hole]))
        let face = try #require(shape.faces().first)

        let grown = try #require(Shape.offsetWire(face: face, offset: 2.0))
        #expect(grown.subShapes(ofType: .wire).count == 2)
        #expect(abs(try halfWidth(grown) - 22.0) < 1e-6)
        // Outer: 4 * 40 + 2 pi 2; hole: 2 pi 3.
        let expectedGrown = 160.0 + 2.0 * Double.pi * 2.0 + 2.0 * Double.pi * 3.0
        #expect(abs(totalLength(grown) - expectedGrown) < 1e-6)

        let shrunk = try #require(Shape.offsetWire(face: face, offset: -2.0))
        #expect(shrunk.subShapes(ofType: .wire).count == 2)
        #expect(abs(try halfWidth(shrunk) - 18.0) < 1e-6)
        // Outer: 4 * 36; hole: 2 pi 7.
        let expectedShrunk = 144.0 + 2.0 * Double.pi * 7.0
        #expect(abs(totalLength(shrunk) - expectedShrunk) < 1e-6)
    }
}
