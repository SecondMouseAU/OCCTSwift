import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Fuse Edges")
struct FuseEdgesTests {
    @Test("Fuse edges on boolean result")
    func fuseAfterBoolean() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!
            .translated(by: SIMD3(10, 0, 0))!
        let combined = box1 + box2
        #expect(combined != nil)
        let fused = combined!.fusedEdges()
        #expect(fused != nil)
        if let f = fused {
            #expect(f.isValid)
            // Fused shape should have fewer edges
            #expect(f.edges().count <= combined!.edges().count)
        }
    }
}
