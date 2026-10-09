import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ChFi2d_ChamferAPI Tests")
struct ChFi2dChamferAPITests {
    @Test("chamfer between two linear edges")
    func chamferEdges() {
        let e1 = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(10, 0, 0))
        let e2 = Shape.edgeFromPoints(SIMD3(10, 0, 0), SIMD3(10, 10, 0))
        if let e1, let e2 {
            let result = Shape.chamfer2dEdges(edge1: e1, edge2: e2, d1: 3.0, d2: 3.0)
            if let r = result {
                #expect(r.chamferEdge.isValid)
            }
        }
    }
}
