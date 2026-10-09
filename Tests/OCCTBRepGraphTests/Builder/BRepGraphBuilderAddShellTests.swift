import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Builder AddShell")
struct BRepGraphBuilderAddShellTests {
    // The add is required, not optional: an `if let` around it let a builder that always
    // failed pass (#1986). Index and count pinned to the kernel probe.
    @Test func addEmptyShell() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        let origShellCount = graph.shellCount
        #expect(origShellCount == 1)
        let sidx = try #require(graph.addShell())
        #expect(sidx == 1)
        #expect(graph.shellCount == origShellCount + 1)
    }
}
