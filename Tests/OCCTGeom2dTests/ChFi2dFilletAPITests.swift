import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ChFi2d_FilletAPI Tests")
struct ChFi2dFilletAPITests {
    @Test("fillet between two edges")
    func filletEdges() {
        let e1 = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(10, 0, 0))
        let e2 = Shape.edgeFromPoints(SIMD3(10, 0, 0), SIMD3(10, 10, 0))
        if let e1, let e2 {
            let result = Shape.fillet2dEdges(
                edge1: e1, edge2: e2,
                planeNormal: SIMD3(0, 0, 1), radius: 2.0,
                nearPoint: SIMD3(10, 0, 0))
            if let r = result {
                #expect(r.solutionCount >= 1)
            }
        }
    }
}
