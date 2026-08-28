import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Builder AddCompound")
struct BRepGraphBuilderAddCompoundTests {
    @Test func addCompoundFromSolids() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let origCompoundCount = graph.compoundCount
                if graph.solidCount > 0 {
                    let children: [(kind: BRepGraph.NodeKind, index: Int)] = [
                        (.solid, 0)
                    ]
                    if let cidx = graph.addCompound(children: children) {
                        #expect(cidx >= 0)
                        #expect(graph.compoundCount == origCompoundCount + 1)
                    }
                }
            }
        }
    }
}
