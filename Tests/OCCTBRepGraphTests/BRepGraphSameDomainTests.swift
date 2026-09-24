import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph SameDomain")
struct BRepGraphSameDomainTests {
    // A box alone passes a query that always answers empty (#1986). Two boxes fused side by
    // side leave coplanar faces that share the seam edge, and those are same-domain pairs:
    // face 1 with face 5 in the fused graph (Scripts/repro/766-brepgraph-products-refs).
    @Test func boxNoSameDomain() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        // Box faces are all distinct, no same-domain
        #expect(graph.sameDomainFaces(of: 0).isEmpty)

        let a = try #require(Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10))
        let b = try #require(Shape.box(origin: SIMD3(10, 0, 0), width: 10, height: 10, depth: 10))
        let union: Shape? = a + b
        let fused = try #require(union)
        let fg = try #require(BRepGraph(shape: fused))
        #expect(fg.faceCount == 10)
        #expect(fg.sameDomainFaces(of: 1) == [5])
        #expect(fg.sameDomainFaces(of: 0).isEmpty)
    }
}
