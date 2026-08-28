import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Active Geometry")
struct BRepGraphActiveGeometryTests {
    @Test func activeGeometryCounts() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                #expect(graph.activeSurfaceCount == 6)
                #expect(graph.activeCurve3DCount == 12)
                #expect(graph.activeCurve2DCount > 0)
            }
        }
    }
}
