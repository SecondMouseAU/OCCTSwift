import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GCPnts QuasiUniform Tests")
struct GCPntsQuasiUniformTests {
    @Test("quasi-uniform on edge")
    func quasiUniformEdge() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edges = box.edges()
        if let edge = edges.first {
            let params = edge.quasiUniformParameters(count: 10)
            #expect(params.count == 10)
            // Parameters should be monotonically increasing
            for i in 1..<params.count {
                #expect(params[i] > params[i - 1])
            }
        }
    }
}
