import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GCPnts QuasiUniform Tests")
struct GCPntsQuasiUniformTests {
    // GCPnts_QuasiUniformAbscissa(10) on the straight 10-long box edge gives 10 * i / 9
    // (Scripts/repro/766-curve-gcpnts-approx/transcript.txt). The earlier version checked only that
    // the parameters increase, inside `if let`, so a non-uniform spacing passed (#766).
    @Test("quasi-uniform on edge")
    func quasiUniformEdge() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10), let edge = box.edges().first
        else {
            Issue.record("box edge unavailable")
            return
        }
        let params = edge.quasiUniformParameters(count: 10)
        #expect(params.count == 10)
        for (i, p) in params.enumerated() {
            #expect(abs(p - 10 * Double(i) / 9) < 1e-9)
        }
    }
}
