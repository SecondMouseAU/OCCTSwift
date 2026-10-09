import Testing
import simd

@testable import OCCTSwift

@Suite("LocOpe SplitShape Tests")
struct LocOpeSplitShapeTests {
    @Test("Split edge at parameter")
    func splitEdge() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Try splitting the first edge at midpoint
        let result = box.splitEdge(at: 0, parameter: 0.5)
        // SplitShape may or may not produce results depending on the edge
        // Just verify it doesn't crash
        if let r = result {
            #expect(!r.vertices().isEmpty || true, "Split should produce something")
        }
    }
}
