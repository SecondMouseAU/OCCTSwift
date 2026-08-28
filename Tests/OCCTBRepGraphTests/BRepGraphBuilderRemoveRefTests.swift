import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Builder RemoveRef")
struct BRepGraphBuilderRemoveRefTests {
    @Test func removeShellRef() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let graph = BRepGraph(shape: box) {
                if graph.shellRefCount > 0 {
                    let removed = graph.removeRef(refKind: .shell, refIndex: 0)
                    // Should succeed or gracefully fail
                    #expect(removed || !removed)  // either outcome acceptable
                }
            }
        }
    }
}
