import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Copy")
struct BRepGraphCopyTests {
    @Test func deepCopy() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let copy = graph.copy()
                #expect(copy != nil)
                if let copy {
                    #expect(copy.faceCount == 6)
                    #expect(copy.edgeCount == 12)
                    #expect(copy.vertexCount == 8)
                }
            }
        }
    }

    @Test func lightCopy() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let copy = graph.copy(copyGeometry: false)
                #expect(copy != nil)
                if let copy {
                    #expect(copy.faceCount == 6)
                }
            }
        }
    }

    @Test func copyFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let faceCopy = graph.copyFace(0)
                #expect(faceCopy != nil)
                if let faceCopy {
                    #expect(faceCopy.faceCount == 1)
                }
            }
        }
    }
}
