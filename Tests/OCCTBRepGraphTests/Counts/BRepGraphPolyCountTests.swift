import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Poly Counts")
struct BRepGraphPolyCountTests {
    // Both expectations were `>= 0` on an Int, true for any value (#1986). An unmeshed box has
    // no triangulation and no 3D polygon; meshed, each of its 6 faces has a triangulation and,
    // being planar, its edges still carry no 3D polygon (Scripts/repro/766-brepgraph-products-refs).
    @Test func polyCounts() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.triangulationCount == 0)
        #expect(graph.polygon3DCount == 0)
        let meshed = try #require(Shape.box(width: 10, height: 10, depth: 10))
        _ = meshed.mesh(linearDeflection: 0.1)
        let mg = try #require(BRepGraph(shape: meshed))
        #expect(mg.triangulationCount == 6)
        #expect(mg.polygon3DCount == 0)
    }
}
