import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Shell Queries")
struct BRepGraphShellQueryTests {
    @Test func shellSolids() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                let count = graph.shellSolidCount(0)
                #expect(count == 1)
                let solids = graph.shellSolids(0)
                #expect(solids.count == 1)
                #expect(solids[0] == 0)
            }
        }
    }
}
