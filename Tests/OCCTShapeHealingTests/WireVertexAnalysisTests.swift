import Foundation
import Testing
import simd

@testable import OCCTSwift

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
        let status = shape.wireVertexStatus(precision: 0.01, index: 0)
        #expect(status != .unknown)
    }
}
