import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ChFi2d_Builder Tests")
struct ChFi2dBuilderTests {
    func makeRectFace() -> Shape? {
        guard let wire = Wire.rectangle(width: 10, height: 10) else { return nil }
        return Shape.face(from: wire)
    }

    @Test("add fillet at vertex")
    func addFillet() {
        if let face = makeRectFace() {
            let result = face.addFillet2d(vertexIndex: 0, radius: 2.0)
            if let r = result {
                // Fillet adds an arc edge, so edge count should increase
                let origEdges = face.subShapes(ofType: .edge).count
                let newEdges = r.subShapes(ofType: .edge).count
                #expect(newEdges > origEdges)
            }
        }
    }

    @Test("add chamfer between edges")
    func addChamfer() {
        if let face = makeRectFace() {
            let result = face.addChamfer2d(edge1Index: 0, edge2Index: 1, d1: 2.0, d2: 2.0)
            if let r = result {
                let origEdges = face.subShapes(ofType: .edge).count
                let newEdges = r.subShapes(ofType: .edge).count
                #expect(newEdges > origEdges)
            }
        }
    }

    @Test("add chamfer with angle")
    func addChamferAngle() {
        if let face = makeRectFace() {
            let result = face.addChamfer2dAngle(
                edgeIndex: 0, vertexIndex: 0, distance: 2.0, angle: .pi / 4)
            if let r = result {
                let origEdges = face.subShapes(ofType: .edge).count
                let newEdges = r.subShapes(ofType: .edge).count
                #expect(newEdges > origEdges)
            }
        }
    }
}
