import Testing
import simd

@testable import OCCTSwift

@Suite("LocOpe FindEdges Tests")
struct LocOpeFindEdgesTests {
    @Test("Find edges in face")
    func findEdgesInFace() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edges = box.edgesInFace(at: 0)
        #expect(edges.count == 4, "Box face should have 4 edges, got \(edges.count)")
    }
}
