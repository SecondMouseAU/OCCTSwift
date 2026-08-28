import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.62.0: BRepLib, LocOpe, ShapeUpgrade/ShapeCustom, CPnts, IntCurvesFace

@Suite("BRepLib MakeEdge")
struct BRepLibMakeEdgeTests {
    @Test("Edge from line with parameters")
    func edgeFromLine() {
        let edge = Shape.edgeFromLine(
            origin: SIMD3(0, 0, 0),
            direction: SIMD3(1, 0, 0),
            p1: 0, p2: 10
        )
        #expect(edge != nil)
        if let edge = edge { #expect(edge.isValid) }
    }

    @Test("Edge from two points")
    func edgeFromPoints() {
        let edge = Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(10, 5, 3))
        #expect(edge != nil)
        if let edge = edge { #expect(edge.isValid) }
    }

    @Test("Edge from circle arc")
    func edgeFromCircle() {
        let edge = Shape.edgeFromCircle(
            center: SIMD3(0, 0, 0),
            axis: SIMD3(0, 0, 1),
            radius: 5,
            p1: 0, p2: .pi
        )
        #expect(edge != nil)
        if let edge = edge { #expect(edge.isValid) }
    }
}
