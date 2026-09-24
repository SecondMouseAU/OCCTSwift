import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ChFi2d_ChamferAPI Tests")
struct ChFi2dChamferAPITests {
    @Test("chamfer between two linear edges")
    func chamferEdges() throws {
        // #1979: the only assertion sat inside `if let r`, so a nil result passed, and isValid
        // passed a chamfer of any size. ChFi2d_ChamferAPI cuts 3 back along each edge, giving a
        // (7,0)-(10,3) chamfer of length 3 * sqrt(2) (Scripts/repro/766-geom2d-chfi2d-compbezier/).
        let e1 = try #require(Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(10, 0, 0)))
        let e2 = try #require(Shape.edgeFromPoints(SIMD3(10, 0, 0), SIMD3(10, 10, 0)))
        let r = try #require(Shape.chamfer2dEdges(edge1: e1, edge2: e2, d1: 3.0, d2: 3.0))
        #expect(r.chamferEdge.isValid)
        let chamfer = try #require(Edge(r.chamferEdge))
        #expect(abs(chamfer.length - 3 * 2.0.squareRoot()) < 1e-9)
        let m1 = try #require(Edge(r.modifiedEdge1))
        let m2 = try #require(Edge(r.modifiedEdge2))
        #expect(abs(m1.length - 7) < 1e-9)
        #expect(abs(m2.length - 7) < 1e-9)
    }
}
