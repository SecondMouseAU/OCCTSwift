import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Ref Entry Queries")
struct BRepGraphRefEntryTests {
    @Test func refChildNode() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Check face ref 0 child node
                if graph.faceRefCount > 0 {
                    let kind = graph.refChildNodeKind(.face, refIndex: 0)
                    #expect(kind != nil)
                    if let kind {
                        #expect(kind == .face)
                    }
                    let idx = graph.refChildNodeIndex(.face, refIndex: 0)
                    #expect(idx >= 0)
                }
            }
        }
    }

    @Test func refNotRemoved() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                if graph.faceRefCount > 0 {
                    #expect(!graph.isRefRemoved(.face, refIndex: 0))
                }
                if graph.shellRefCount > 0 {
                    #expect(!graph.isRefRemoved(.shell, refIndex: 0))
                }
            }
        }
    }

    @Test func refOrientation() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                if graph.faceRefCount > 0 {
                    let ori = graph.refOrientation(.face, refIndex: 0)
                    // TopAbs_FORWARD=0, REVERSED=1, INTERNAL=2, EXTERNAL=3
                    #expect(ori >= 0 && ori <= 3)
                }
            }
        }
    }
}
