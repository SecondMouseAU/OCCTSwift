import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ChFi2d FilletAlgo Tests")
struct ChFi2dFilletAlgoTests {
    @Test("Iterative 2D fillet between two line edges")
    func filletBetweenLines() {
        // Two edges meeting at origin
        let e1Wire = Wire.line(from: .zero, to: SIMD3(10, 0, 0))
        let e2Wire = Wire.line(from: .zero, to: SIMD3(0, 10, 0))
        if let e1 = e1Wire.flatMap({ Shape.fromWire($0) }),
            let e2 = e2Wire.flatMap({ Shape.fromWire($0) })
        {
            let result = Shape.filletAlgo(edge1: e1, edge2: e2, radius: 2.0)
            #expect(result != nil)
            if let r = result {
                #expect(r.fillet.isValid)
                #expect(r.resultCount >= 1)
            }
        }
    }
}
