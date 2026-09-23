import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph Active Geometry")
struct BRepGraphActiveGeometryTests {
    // A box has 6 face surfaces, 12 edge curves and 24 pcurves (one per coedge, 4 per face).
    // Pinned to the kernel's NbActiveFaceSurfaces / NbActiveEdgeCurves3D /
    // NbActiveCoEdgeCurves2D (Scripts/repro/766-brepgraph-builder-add): the 2D count was
    // `> 0`, which accepted any miscount (#1986).
    @Test func activeGeometryCounts() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let graph = try #require(BRepGraph(shape: box))
        #expect(graph.activeSurfaceCount == 6)
        #expect(graph.activeCurve3DCount == 12)
        #expect(graph.activeCurve2DCount == 24)
    }
}
