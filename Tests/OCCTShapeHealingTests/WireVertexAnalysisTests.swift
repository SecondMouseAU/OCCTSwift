import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are ShapeAnalysis_WireVertex's own answers on the same wire, from
// Scripts/repro/766-healing-small-files/probe.mm. Before #766 the status check was
// `status != .unknown`, which six of the eight cases satisfy.
@Suite("ShapeAnalysis_WireVertex")
struct WireVertexAnalysisTests {
    @Test("Analyze wire vertices")
    func wireVertex() throws {
        let wire = try #require(
            Wire.polygon3D(
                [
                    SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0),
                ], closed: false))
        let shape = try #require(Shape.fromWire(wire))
        let analysis = shape.wireVertexAnalysis(precision: 0.01)
        #expect(analysis.isDone)
        #expect(analysis.edgeCount == 2)
        // Kernel: Status(1) = 1 (same coordinates), Status(2) = -1 (disjoined: the open end).
        #expect(shape.wireVertexStatus(precision: 0.01, index: 0) == .sameCoords)
        #expect(shape.wireVertexStatus(precision: 0.01, index: 1) == .disjoined)
    }
}
