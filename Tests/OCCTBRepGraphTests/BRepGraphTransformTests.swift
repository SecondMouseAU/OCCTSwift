import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Transform")
struct BRepGraphTransformTests {
    @Test func translateGraph() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let translated = graph.translated(dx: 100, dy: 200, dz: 300)
                #expect(translated != nil)
                if let translated {
                    #expect(translated.faceCount == 6)
                    #expect(translated.edgeCount == 12)
                    #expect(translated.vertexCount == 8)
                    // Check that vertex moved
                    let origPt = graph.vertexPoint(0)
                    let newPt = translated.vertexPoint(0)
                    #expect(abs(newPt.x - origPt.x - 100) < 1e-6)
                    #expect(abs(newPt.y - origPt.y - 200) < 1e-6)
                    #expect(abs(newPt.z - origPt.z - 300) < 1e-6)
                }
            }
        }
    }

    @Test func translateLightCopy() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let translated = graph.translated(dx: 10, dy: 0, dz: 0, copyGeometry: false)
                #expect(translated != nil)
                if let translated {
                    #expect(translated.faceCount == 6)
                }
            }
        }
    }
}
