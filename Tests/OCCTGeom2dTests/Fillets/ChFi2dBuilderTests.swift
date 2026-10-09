import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: all three tests nested their only assertion inside `if let face` and `if let r`, so a
// nil result passed, and `newEdges > origEdges` passed a corner cut of any size. Each now pins the
// face ChFi2d_Builder returns for the same 10 x 10 square centred on the origin
// (Scripts/repro/766-geom2d-chfi2d-compbezier/): one extra edge, and the area the cut removes.
@Suite("ChFi2d_Builder Tests")
struct ChFi2dBuilderTests {
    func makeRectFace() throws -> Shape {
        let wire = try #require(Wire.rectangle(width: 10, height: 10))
        return try #require(Shape.face(from: wire))
    }

    @Test("add fillet at vertex")
    func addFillet() throws {
        let face = try makeRectFace()
        let r = try #require(face.addFillet2d(vertexIndex: 0, radius: 2.0))
        // Fillet adds an arc edge. A radius-2 round on a 90-degree corner removes 4 - pi.
        #expect(face.subShapes(ofType: .edge).count == 4)
        #expect(r.subShapes(ofType: .edge).count == 5)
        let area = try #require(r.surfaceArea)
        #expect(abs(area - (96 + Double.pi)) < 1e-6)
    }

    @Test("add chamfer between edges")
    func addChamfer() throws {
        let face = try makeRectFace()
        let r = try #require(face.addChamfer2d(edge1Index: 0, edge2Index: 1, d1: 2.0, d2: 2.0))
        // A 2 x 2 chamfer removes a right triangle of area 2.
        #expect(r.subShapes(ofType: .edge).count == 5)
        let area = try #require(r.surfaceArea)
        #expect(abs(area - 98) < 1e-6)
    }

    @Test("add chamfer with angle")
    func addChamferAngle() throws {
        let face = try makeRectFace()
        let r = try #require(
            face.addChamfer2dAngle(edgeIndex: 0, vertexIndex: 0, distance: 2.0, angle: .pi / 4))
        // Distance 2 at 45 degrees is the same 2 x 2 cut as above.
        #expect(r.subShapes(ofType: .edge).count == 5)
        let area = try #require(r.surfaceArea)
        #expect(abs(area - 98) < 1e-6)
    }
}
