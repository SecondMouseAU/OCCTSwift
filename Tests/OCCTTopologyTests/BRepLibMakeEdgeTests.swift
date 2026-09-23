import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.62.0: BRepLib, LocOpe, ShapeUpgrade/ShapeCustom, CPnts, IntCurvesFace

// Before #1981 each test asserted only non-nil and `isValid`, so an edge built from the wrong
// parameters or the wrong point passed. Each is now pinned to the length and end points
// BRepLib_MakeEdge gives in Scripts/repro/766-topology-breplib-builders/transcript.txt.
@Suite("BRepLib MakeEdge")
struct BRepLibMakeEdgeTests {
    @Test("Edge from line with parameters")
    func edgeFromLine() throws {
        let edge = try #require(
            Shape.edgeFromLine(
                origin: SIMD3(0, 0, 0),
                direction: SIMD3(1, 0, 0),
                p1: 0, p2: 10
            ))
        #expect(edge.isValid)
        #expect(abs(edge.edgeArcLength - 10) < 1e-9, "length \(edge.edgeArcLength)")
        let v = edge.vertices()
        try #require(v.count == 2)
        #expect(simd_distance(v[0], SIMD3(0, 0, 0)) < 1e-12)
        #expect(simd_distance(v[1], SIMD3(10, 0, 0)) < 1e-12)
    }

    @Test("Edge from two points")
    func edgeFromPoints() throws {
        let edge = try #require(Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(10, 5, 3)))
        #expect(edge.isValid)
        #expect(abs(edge.edgeArcLength - 11.575836902790225) < 1e-9, "length \(edge.edgeArcLength)")
        let v = edge.vertices()
        try #require(v.count == 2)
        #expect(simd_distance(v[1], SIMD3(10, 5, 3)) < 1e-12, "end \(v[1])")
    }

    @Test("Edge from circle arc")
    func edgeFromCircle() throws {
        let edge = try #require(
            Shape.edgeFromCircle(
                center: SIMD3(0, 0, 0),
                axis: SIMD3(0, 0, 1),
                radius: 5,
                p1: 0, p2: .pi
            ))
        #expect(edge.isValid)
        // Half of a radius-5 circle: 5 pi.
        #expect(abs(edge.edgeArcLength - 5 * .pi) < 1e-9, "length \(edge.edgeArcLength)")
    }
}
