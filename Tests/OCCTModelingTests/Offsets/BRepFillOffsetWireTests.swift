import Testing

@testable import OCCTSwift

@Suite("BRepFill OffsetWire Tests")
struct BRepFillOffsetWireTests {
    // The face of a 20 x 20 rectangle. The tests used to build this from `Shape.fromWire`, which
    // is a wire shape with no faces, so `if !faces.isEmpty` skipped the call and they passed
    // without reaching `offsetWire`.
    private func rectangleFace() throws -> Face {
        let wire = try #require(Wire.rectangle(width: 20, height: 20))
        let shape = try #require(Shape.face(from: wire))
        return try #require(shape.faces().first)
    }

    private func halfWidth(_ shape: Shape) throws -> Double {
        let bounds = try #require(shape.boundingBox)
        return (bounds.max.x - bounds.min.x) / 2
    }

    // Offset +3 gives a closed four-edge wire three away from the original (half-width 10). It is
    // the inner one, 7, on the pinned kernel (v4.0.0-kernel.6), which is the opposite of the doc
    // comment's "positive expands outward" (#3364), so the direction is the known issue and the
    // distance, closure and edge count are pinned.
    @Test("Offset planar wire outward")
    func offsetOutward() throws {
        let face = try rectangleFace()
        let result = try #require(Shape.offsetWire(face: face, offset: 3.0))
        #expect(result.shapeType == .wire)
        let edges = result.edges()
        #expect(edges.count == 4)
        let half = try halfWidth(result)
        // Three from the original half-width of 10, on either side (7 or 13).
        let distanceFromOriginal = abs(half - 10.0)
        #expect(abs(distanceFromOriginal - 3.0) < 1e-6)
        // A square of that half-width: four edges of 2 * half.
        let length = edges.reduce(0.0) { $0 + ($1.length ?? 0) }
        #expect(abs(length - 8.0 * half) < 1e-6)

        withKnownIssue("#3364: a positive offset shrinks the wire, the doc says it expands") {
            #expect(half > 10.0)
        }
    }

    // Offset -3 should be the other side of the original, at the same distance. It returns four
    // untrimmed segments 60 long that cross and run to +-30, which is not a wire (#3364). The
    // call does return a shape, and the distance and edge count are the documented contract.
    @Test("Offset planar wire inward")
    func offsetInward() throws {
        let face = try rectangleFace()
        let result = try #require(Shape.offsetWire(face: face, offset: -3.0))
        #expect(result.edges().count == 4)
        withKnownIssue("#3364: the negative offset is four untrimmed crossing segments") {
            #expect(result.shapeType == .wire)
            let half = try halfWidth(result)
            // Three from the original half-width of 10, on either side (7 or 13).
            let distanceFromOriginal = abs(half - 10.0)
            #expect(abs(distanceFromOriginal - 3.0) < 1e-6)
        }
    }
}
