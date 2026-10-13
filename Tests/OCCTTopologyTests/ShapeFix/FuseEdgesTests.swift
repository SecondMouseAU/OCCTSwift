import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("Fuse Edges")
struct FuseEdgesTests {
    @Test("Fuse edges on boolean result")
    func fuseAfterBoolean() throws {
        let box1 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let box2 = try #require(
            Shape.box(width: 10, height: 10, depth: 10)?
                .translated(by: SIMD3(10, 0, 0)))
        let combined = box1 + box2
        #expect(combined != nil)
        let fused = try #require(combined).fusedEdges()
        #expect(fused != nil)
        if let f = fused {
            #expect(f.isValid)
            // Fused shape should have fewer edges
            #expect(try f.edges().count <= #require(combined).edges().count)
        }
    }
}
