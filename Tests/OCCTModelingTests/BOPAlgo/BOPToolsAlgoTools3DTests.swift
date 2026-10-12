import Foundation
import Testing

@testable import OCCTSwift

@Suite("BOPTools_AlgoTools3D Tests")
struct BOPToolsAlgoTools3DTests {
    @Test("Normal to face on edge")
    func normalOnEdge() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            if let face = faces.first {
                let edges = face.subShapes(ofType: .edge)
                if let edge = edges.first {
                    let normal = Shape.normalOnEdge(edge: edge, face: face)
                    #expect(normal != nil)
                    if let n = normal {
                        let len = sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
                        #expect(abs(len - 1.0) < 1e-6)
                    }
                }
            }
        }
    }

    // #3332: the old test took the FIRST face and asserted only `pointInFace() != nil`, so a
    // point anywhere in space passed. Each face of the centred 10 mm cube is checked: the point
    // lies ON the face (distance 0), on the face's own plane coordinate, and strictly inside its
    // boundary (measured: 0.6786 from the centre along each in-plane axis; PointInFace returns
    // an interior point, not the centre).
    @Test("Point in face")
    func pointInFace() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.subShapes(ofType: .face)
        #expect(faces.count == 6)
        for face in faces {
            let centre = try #require(face.center)
            let point = try #require(face.pointInFace())
            // The face's own plane: the axis along which its centre is +-5.
            let axis = (0..<3).max(by: { abs(centre[$0]) < abs(centre[$1]) }) ?? 0
            #expect(abs(abs(centre[axis]) - 5) < 1e-6)
            #expect(abs(point[axis] - centre[axis]) < 1e-6, "on the face plane \(centre)")
            for other in 0..<3 where other != axis {
                #expect(abs(point[other]) < 5 - 0.1, "strictly inside the face \(centre)")
            }
            let vertex = try #require(Shape.vertex(at: point))
            let distance = try #require(face.distance(to: vertex))
            #expect(distance.distance < 1e-6)
        }
    }

    // #3332: `Shape.compound([])` is nil (an empty compound is refused), so the old test's
    // `if let e = empty { #expect(e.isEmpty) }` never ran its one assertion and the whole test
    // reduced to `!box.isEmpty`. The empty shapes here come from operations that really produce
    // one: a CellsBuilder before anything is added to its result, and the common of two disjoint
    // boxes. Both are compounds with no sub-shape.
    @Test("IsEmptyShape")
    func isEmptyShape() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(!box.isEmpty)

        let vertex = try #require(Shape.vertex(at: .zero))
        #expect(!vertex.isEmpty)
        let wrapped = try #require(Shape.compound([box]))
        #expect(!wrapped.isEmpty)

        let neighbour = try #require(
            Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10))
        let builder = try #require(CellsBuilder(shapes: [box, neighbour]))
        let untouched = try #require(builder.result())
        #expect(untouched.shapeType == .compound)
        #expect(untouched.subShapes(ofType: .solid).isEmpty)
        #expect(untouched.isEmpty)

        let far = try #require(
            Shape.box(origin: SIMD3(100, 100, 100), width: 1, height: 1, depth: 1))
        let common = try #require(box.intersection(far))
        #expect(common.subShapes(ofType: .solid).isEmpty)
        #expect(common.isEmpty)
    }
}
