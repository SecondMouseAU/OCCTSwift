import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Wire.edgePolyline") struct WireEdgePolylineTests {
    @Test("Wire.edgePolyline returns points for single edge")
    func singleEdge() {
        guard let wire = Wire.rectangle(width: 10, height: 5) else {
            Issue.record("rectangle was nil")
            return
        }
        guard let polyline = wire.edgePolyline(at: 0) else {
            Issue.record("edgePolyline(at: 0) was nil")
            return
        }
        // Pinned to GCPnts_TangentialDeflection on the same edge
        // (Scripts/repro/766-curve-final-sampling/transcript.txt): the first edge of the centred
        // 10x5 rectangle is the straight bottom side, sampled at its two ends.
        #expect(polyline.count == 2)
        guard polyline.count == 2 else { return }
        #expect(simd_distance(polyline[0], SIMD3(-5, -2.5, 0)) < 1e-9)
        #expect(simd_distance(polyline[1], SIMD3(5, -2.5, 0)) < 1e-9)
    }
}
