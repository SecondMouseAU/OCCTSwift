import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepLib_MakeWire, Wire From Edges")
struct WireFromEdgesTests {
    @Test("Create wire from box edges")
    func wireFromEdges() throws {
        // Get edges from a box face (a planar face has 4 edges forming a loop)
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.edges()
        #expect(edges.count >= 4)
        // Take the first 4 edges (from one face) and build a wire
        let subset = Array(edges.prefix(4))
        let wire = Wire.wireFromEdges(subset)
        #expect(wire != nil)
        if let w = wire {
            let info = w.curveInfo
            #expect(info != nil)
        }
    }
}
