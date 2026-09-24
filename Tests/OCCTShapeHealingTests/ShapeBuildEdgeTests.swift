import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - ShapeBuild_Edge

// #766: every test here returned early, silently green, if the fixture failed, and asserted only
// `shapeType == .edge` (inside `if let`), which an untouched edge also satisfies; one discarded its
// answer. Each now pins what ShapeBuild_Edge does on the same edge, from
// Scripts/repro/766-healing-shapebuild/probe.mm. The box's first mapped edge runs (-5,-5,-5) to
// (-5,-5,5) over [0, 10]. The pcurve tests use a cylinder's lateral face, because a plane
// projects a missing pcurve on demand and so cannot show one being removed (measured).
@Suite("ShapeBuild Edge")
struct ShapeBuildEdgeTests {
    private func boxEdges() throws -> [Shape] {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.subShapes(ofType: .edge)
        try #require(edges.count >= 2)
        return edges
    }

    private func bounds(_ edge: Shape) throws -> (first: Double, last: Double) {
        let e = try #require(Edge(edge))
        return try #require(e.parameterBounds)
    }

    /// The cylinder's lateral face and its first mapped edge (the top circle).
    private func cylinderEdgeAndFace() throws -> (edge: Shape, face: Shape) {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let edge = try #require(cyl.subShapes(ofType: .edge).first)
        let face = try #require(cyl.subShapes(ofType: .face).first)
        return (edge, face)
    }

    @Test("Copy edge")
    func copyEdge() throws {
        let edges = try boxEdges()
        let copied = try #require(edges[0].copyEdge(sharePCurves: true))
        #expect(copied.shapeType == .edge)
        #expect(!copied.isSame(as: edges[0]))
        #expect(EdgeAnalysis.firstVertex(copied) == SIMD3(-5, -5, -5))
        #expect(EdgeAnalysis.lastVertex(copied) == SIMD3(-5, -5, 5))
    }

    @Test("Copy edge without sharing PCurves")
    func copyEdgeNoShare() throws {
        let edges = try boxEdges()
        let copied = try #require(edges[0].copyEdge(sharePCurves: false))
        #expect(!copied.isSame(as: edges[0]))
        #expect(EdgeAnalysis.hasCurve3d(copied))
        let b = try bounds(copied)
        #expect(b.first == 0 && b.last == 10)
    }

    @Test("Copy edge replacing vertices")
    func copyEdgeReplaceVertices() throws {
        // Kernel: vertices[0] is (-5,-5,5) and vertices[1] is (-5,-5,-5); the copy runs between them.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.subShapes(ofType: .edge)
        let vertices = box.subShapes(ofType: .vertex)
        try #require(edges.count >= 1 && vertices.count >= 2)
        let result = try #require(
            edges[0].copyEdgeReplacingVertices(startVertex: vertices[0], endVertex: vertices[1]))
        #expect(EdgeAnalysis.firstVertex(result) == SIMD3(-5, -5, 5))
        #expect(EdgeAnalysis.lastVertex(result) == SIMD3(-5, -5, -5))
    }

    @Test("Set range 3d")
    func setRange3d() throws {
        let edges = try boxEdges()
        let copied = try #require(edges[0].copyEdge())
        copied.setEdgeRange3d(first: 0.0, last: 5.0)
        let b = try bounds(copied)
        #expect(b.first == 0 && b.last == 5)
    }

    @Test("Build curve 3d")
    func buildCurve3d() throws {
        // Kernel: BuildCurve3d reports success on a box edge.
        let edges = try boxEdges()
        #expect(edges[0].buildEdgeCurve3d())
    }

    @Test("Remove curve 3d")
    func removeCurve3d() throws {
        let edges = try boxEdges()
        let copied = try #require(edges[0].copyEdge())
        #expect(EdgeAnalysis.hasCurve3d(copied))
        copied.removeEdgeCurve3d()
        #expect(!EdgeAnalysis.hasCurve3d(copied))
    }

    @Test("Copy ranges between edges")
    func copyRanges() throws {
        // Every box edge spans [0, 10], so the copy is first narrowed to [0, 5]; copying edge 1's
        // ranges puts [0, 10] back (kernel).
        let edges = try boxEdges()
        let copied = try #require(edges[0].copyEdge())
        copied.setEdgeRange3d(first: 0.0, last: 5.0)
        copied.copyEdgeRanges(from: edges[1])
        let b = try bounds(copied)
        #expect(b.first == 0 && b.last == 10)
    }

    @Test("Copy PCurves between edges")
    func copyPCurves() throws {
        let (edge, face) = try cylinderEdgeAndFace()
        let copied = try #require(edge.copyEdge())
        copied.removeEdgePCurve(onFace: face)
        #expect(!EdgeAnalysis.hasPCurve(copied, face: face))
        copied.copyEdgePCurves(from: edge)
        #expect(EdgeAnalysis.hasPCurve(copied, face: face))
    }

    @Test("Remove PCurve from edge")
    func removePCurve() throws {
        let (edge, face) = try cylinderEdgeAndFace()
        let copied = try #require(edge.copyEdge())
        #expect(EdgeAnalysis.hasPCurve(copied, face: face))
        copied.removeEdgePCurve(onFace: face)
        #expect(!EdgeAnalysis.hasPCurve(copied, face: face))
    }
}
