import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Compound Queries")
struct BRepGraphCompoundTests {
    @Test func compoundQueriesOnCompound() {
        // Create a compound shape by fusing two boxes
        let box1 = Shape.box(width: 10, height: 10, depth: 10)
        let box2 = Shape.box(origin: SIMD3(20, 0, 0), width: 10, height: 10, depth: 10)
        if let box1, let box2 {
            let compound = Shape.compound([box1, box2])
            if let compound {
                let graph = BRepGraph(shape: compound)
                if let graph {
                    #expect(graph.compoundCount >= 1)
                    if graph.compoundCount > 0 {
                        let childCount = graph.compoundChildCount(0)
                        #expect(childCount >= 2)  // at least 2 solids
                        let parentCount = graph.compoundParentCount(0)
                        // Root compound has no parents
                        #expect(parentCount == 0)
                    }
                }
            }
        }
    }
}
