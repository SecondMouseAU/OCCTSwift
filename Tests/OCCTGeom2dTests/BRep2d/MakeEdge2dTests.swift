import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepBuilderAPI MakeEdge2d")
struct MakeEdge2dTests {
    @Test("Edge 2D from points")
    func edge2dFromPoints() {
        let edge = Shape.edge2d(from: SIMD2(0, 0), to: SIMD2(10, 5))
        #expect(edge != nil)
        // 2D edges lack a 3D curve, so BRepCheck_Analyzer reports them invalid — just check creation
        if let edge = edge { #expect(edge.shapeType == .edge) }
    }

    @Test("Edge 2D from circle arc")
    func edge2dFromCircle() {
        let edge = Shape.edge2dFromCircle(
            center: SIMD2(0, 0),
            direction: SIMD2(1, 0),
            radius: 5,
            p1: 0, p2: .pi
        )
        #expect(edge != nil)
        if let edge = edge { #expect(edge.shapeType == .edge) }
    }

    @Test("Edge 2D from line")
    func edge2dFromLine() {
        let edge = Shape.edge2dFromLine(
            origin: SIMD2(0, 0),
            direction: SIMD2(1, 1),
            p1: 0, p2: 10
        )
        #expect(edge != nil)
        if let edge = edge { #expect(edge.shapeType == .edge) }
    }
}
