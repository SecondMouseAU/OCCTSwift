import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - ShapeBuild_Edge

@Suite("ShapeBuild Edge")
struct ShapeBuildEdgeTests {
    @Test("Copy edge")
    func copyEdge() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let edges = box.subShapes(ofType: .edge)
        guard !edges.isEmpty else { return }
        if let copied = edges[0].copyEdge(sharePCurves: true) {
            #expect(copied.shapeType == .edge)
        }
    }

    @Test("Copy edge without sharing PCurves")
    func copyEdgeNoShare() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let edges = box.subShapes(ofType: .edge)
        guard !edges.isEmpty else { return }
        if let copied = edges[0].copyEdge(sharePCurves: false) {
            #expect(copied.shapeType == .edge)
        }
    }

    @Test("Copy edge replacing vertices")
    func copyEdgeReplaceVertices() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let edges = box.subShapes(ofType: .edge)
        let vertices = box.subShapes(ofType: .vertex)
        guard edges.count >= 1, vertices.count >= 2 else { return }
        if let result = edges[0].copyEdgeReplacingVertices(
            startVertex: vertices[0], endVertex: vertices[1])
        {
            #expect(result.shapeType == .edge)
        }
    }

    @Test("Set range 3d")
    func setRange3d() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let edges = box.subShapes(ofType: .edge)
        guard !edges.isEmpty else { return }
        if let copied = edges[0].copyEdge() {
            copied.setEdgeRange3d(first: 0.0, last: 5.0)
            // Verify it doesn't crash
            #expect(copied.shapeType == .edge)
        }
    }

    @Test("Build curve 3d")
    func buildCurve3d() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let edges = box.subShapes(ofType: .edge)
        guard !edges.isEmpty else { return }
        // Just verify it runs without crashing
        let _ = edges[0].buildEdgeCurve3d()
    }

    @Test("Remove curve 3d")
    func removeCurve3d() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let edges = box.subShapes(ofType: .edge)
        guard !edges.isEmpty else { return }
        if let copied = edges[0].copyEdge() {
            copied.removeEdgeCurve3d()
            #expect(copied.shapeType == .edge)
        }
    }

    @Test("Copy ranges between edges")
    func copyRanges() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let edges = box.subShapes(ofType: .edge)
        guard edges.count >= 2 else { return }
        if let copied = edges[0].copyEdge() {
            copied.copyEdgeRanges(from: edges[1])
            #expect(copied.shapeType == .edge)
        }
    }

    @Test("Copy PCurves between edges")
    func copyPCurves() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let edges = box.subShapes(ofType: .edge)
        guard edges.count >= 2 else { return }
        if let copied = edges[0].copyEdge() {
            copied.copyEdgePCurves(from: edges[1])
            #expect(copied.shapeType == .edge)
        }
    }

    @Test("Remove PCurve from edge")
    func removePCurve() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let edges = box.subShapes(ofType: .edge)
        let faces = box.subShapes(ofType: .face)
        guard !edges.isEmpty, !faces.isEmpty else { return }
        if let copied = edges[0].copyEdge() {
            copied.removeEdgePCurve(onFace: faces[0])
            #expect(copied.shapeType == .edge)
        }
    }
}
