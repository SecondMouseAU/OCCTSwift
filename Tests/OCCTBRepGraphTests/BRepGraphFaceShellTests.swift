import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Face Shells")
struct BRepGraphFaceShellTests {
    @Test func faceShells() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                for i in 0..<graph.faceCount {
                    let count = graph.faceShellCount(i)
                    #expect(count >= 1)
                    let shells = graph.faceShells(i)
                    #expect(shells.count == count)
                    for s in shells {
                        #expect(s >= 0 && s < graph.shellCount)
                    }
                }
            }
        }
    }

    @Test func faceCompoundCount() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Box faces are not in compounds
                for i in 0..<graph.faceCount {
                    #expect(graph.faceCompoundCount(i) == 0)
                }
            }
        }
    }
}
