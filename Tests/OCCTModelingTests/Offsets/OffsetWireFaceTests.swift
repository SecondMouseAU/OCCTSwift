import Testing

@testable import OCCTSwift

@Suite("v0.114.0 - Offset Wire/Face")
struct OffsetWireFaceTests {

    private func length(of shape: Shape) -> Double {
        shape.edges().reduce(0.0) { $0 + $1.length }
    }

    // Arc join: four 10 mm edges and four quarter arcs of radius 2, so eight edges and
    // 40 + 2 pi * 2 = 52.566..., reaching +-7.
    @Test func offsetWire() throws {
        let rect = try #require(Wire.rectangle(width: 10, height: 10))
        let wireShape = try #require(Shape.fromWire(rect))
        let offset = try #require(wireShape.offsetWireOnPlane(distance: 2.0))
        #expect(offset.shapeType == .wire)
        #expect(offset.edges().count == 8)
        #expect(abs(length(of: offset) - (40.0 + 4.0 * Double.pi)) < 1e-6)
        let bounds = try #require(offset.boundingBox)
        #expect(abs(bounds.max.x - 7.0) < 1e-5 && abs(bounds.min.x + 7.0) < 1e-5)
        #expect(abs(bounds.max.y - 7.0) < 1e-5 && abs(bounds.min.y + 7.0) < 1e-5)
    }

    // Intersection join keeps the corners sharp: a 12 x 12 square, four edges, length 48.
    @Test func offsetWireIntersection() throws {
        let rect = try #require(Wire.rectangle(width: 10, height: 10))
        let wireShape = try #require(Shape.fromWire(rect))
        let offset = try #require(
            wireShape.offsetWireOnPlane(distance: 1.0, joinType: .intersection))
        #expect(offset.shapeType == .wire)
        #expect(offset.edges().count == 4)
        #expect(abs(length(of: offset) - 48.0) < 1e-6)
        let bounds = try #require(offset.boundingBox)
        #expect(abs(bounds.max.x - 6.0) < 1e-5 && abs(bounds.min.x + 6.0) < 1e-5)
    }

    // `offsetFace(distance:)` with no join type resolves to `BRepOffset`'s offset of the face
    // along its normal, not to the in-plane outline offset: the face is moved to z = 2, keeping
    // its 20 x 20 extent and 400 of area. The in-plane outline offset is the `joinType:` overload
    // below it, pinned too (an eight-edge wire reaching +-12).
    @Test func offsetFace() throws {
        let rect = try #require(Wire.rectangle(width: 20, height: 20))
        let face = try #require(Shape.face(from: rect))

        let lifted = try #require(face.offsetFace(distance: 2.0))
        #expect(lifted.shapeType == .face)
        #expect(abs((lifted.surfaceArea ?? -1) - 400.0) < 1e-6)
        let liftedBounds = try #require(lifted.boundingBox)
        #expect(abs(liftedBounds.min.z - 2.0) < 1e-5 && abs(liftedBounds.max.z - 2.0) < 1e-5)
        #expect(abs(liftedBounds.max.x - 10.0) < 1e-5)

        let outline = try #require(face.offsetFace(distance: 2.0, joinType: .arc))
        #expect(outline.shapeType == .wire)
        #expect(outline.edges().count == 8)
        #expect(abs(length(of: outline) - (80.0 + 4.0 * Double.pi)) < 1e-6)
        let outlineBounds = try #require(outline.boundingBox)
        #expect(abs(outlineBounds.max.x - 12.0) < 1e-5 && abs(outlineBounds.min.x + 12.0) < 1e-5)
    }
}
