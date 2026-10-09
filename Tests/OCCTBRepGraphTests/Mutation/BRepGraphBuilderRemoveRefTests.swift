import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Builder RemoveRef")
struct BRepGraphBuilderRemoveRefTests {
    // Asserted `removed || !removed`, a tautology (#1986). Pinned to the kernel probe: the
    // box's single shell ref removes (true), is then reported removed, the ref table keeps
    // its slot (count stays 1), and a second remove of the same ref reports false.
    @Test func removeShellRef() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.shellRefCount == 1)
        #expect(!graph.isRefRemoved(.shell, refIndex: 0))
        let removed = graph.removeRef(refKind: .shell, refIndex: 0)
        #expect(removed)
        #expect(graph.isRefRemoved(.shell, refIndex: 0))
        #expect(graph.shellRefCount == 1)
        #expect(!graph.removeRef(refKind: .shell, refIndex: 0))
    }
}
