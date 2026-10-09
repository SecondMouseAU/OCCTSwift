import Testing
import simd

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

    @Test("Point in face")
    func pointInFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            if let face = faces.first {
                let point = face.pointInFace()
                #expect(point != nil)
            }
        }
    }

    @Test("IsEmptyShape")
    func isEmptyShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            #expect(!b.isEmpty)
        }
        let empty = Shape.compound([])
        if let e = empty {
            #expect(e.isEmpty)
        }
    }
}
