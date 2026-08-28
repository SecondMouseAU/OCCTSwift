import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Builder AddSolid")
struct BRepGraphBuilderAddSolidTests {
    @Test func addEmptySolid() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let origSolidCount = graph.solidCount
                if let sidx = graph.addSolid() {
                    #expect(sidx >= 0)
                    #expect(graph.solidCount == origSolidCount + 1)
                }
            }
        }
    }
}
