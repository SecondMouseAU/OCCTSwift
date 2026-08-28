import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Builder AddShell")
struct BRepGraphBuilderAddShellTests {
    @Test func addEmptyShell() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                let origShellCount = graph.shellCount
                if let sidx = graph.addShell() {
                    #expect(sidx >= 0)
                    #expect(graph.shellCount == origShellCount + 1)
                }
            }
        }
    }
}
