import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeAnalysis_Edge Tests")
struct SAEdgeAnalysisTests {

    @Test func edgeHasCurve3d() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                #expect(EdgeAnalysis.hasCurve3d(edge))
            }
        }
    }

    @Test func edgeIsClosed3d() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                #expect(!EdgeAnalysis.isClosed3d(edge))
            }
        }
    }

    @Test func edgeHasPCurve() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            let edges = box.subShapes(ofType: .edge)
            if let face = faces.first, let edge = edges.first {
                // Edge may or may not have a PCurve on this particular face
                let _ = EdgeAnalysis.hasPCurve(edge, face: face)
            }
        }
    }

    @Test func edgeIsSeam() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            let edges = box.subShapes(ofType: .edge)
            if let face = faces.first, let edge = edges.first {
                let seam = EdgeAnalysis.isSeam(edge, face: face)
                #expect(!seam)  // box edges are not seam edges
            }
        }
    }

    @Test func edgeSameParameter() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let result = EdgeAnalysis.checkSameParameter(edge)
                // maxDeviation should be small for a box edge
                let _ = result
            }
        }
    }

    @Test func edgeVerticesWithCurve3d() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let _ = EdgeAnalysis.checkVerticesWithCurve3d(edge)
            }
        }
    }

    @Test func edgeVerticesWithPCurve() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            let edges = box.subShapes(ofType: .edge)
            if let face = faces.first, let edge = edges.first {
                let _ = EdgeAnalysis.checkVerticesWithPCurve(edge, face: face)
            }
        }
    }

    @Test func edgeCurve3dWithPCurve() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            let edges = box.subShapes(ofType: .edge)
            if let face = faces.first, let edge = edges.first {
                let _ = EdgeAnalysis.checkCurve3dWithPCurve(edge, face: face)
            }
        }
    }

    @Test func edgeFirstLastVertex() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let first = EdgeAnalysis.firstVertex(edge)
                let last = EdgeAnalysis.lastVertex(edge)
                // Vertices should be at box corners
                #expect(first != last || EdgeAnalysis.isClosed3d(edge))
            }
        }
    }

    @Test func edgeVertexTolerance() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            let edges = box.subShapes(ofType: .edge)
            if let face = faces.first, let edge = edges.first {
                let _ = EdgeAnalysis.checkVertexTolerance(edge, face: face)
            }
        }
    }

    @Test func edgeCheckOverlapping() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count >= 2 {
                let result = EdgeAnalysis.checkOverlapping(edges[0], edges[1])
                #expect(!result.overlapping)
            }
        }
    }

    // #1438: OCCTEdgeCheckOverlapping used to zero its own `tolOverlap` right before passing it to
    // ShapeAnalysis_Edge::CheckOverlapping, which reads it as an INPUT threshold, so the internal
    // "distance >= tolerance" test was always "distance >= 0", true for essentially any sample,
    // and the function always returned false -- even for an edge checked against itself.
    @Test func edgeCheckOverlappingDetectsRealOverlap() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let edges = box.subShapes(ofType: .edge)
        guard let edge = edges.first else { return }
        // An edge always overlaps itself.
        let result = EdgeAnalysis.checkOverlapping(edge, edge)
        #expect(result.overlapping)
        #expect(result.tolerance > 0)
    }

    @Test func edgeBoundUV() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let faceEdges = face.subShapes(ofType: .edge)
                if let edge = faceEdges.first {
                    if let bounds = EdgeAnalysis.boundUV(edge, face: face) {
                        #expect(bounds.uFirst <= bounds.uLast || bounds.vFirst <= bounds.vLast)
                    }
                }
            }
        }
    }

    @Test func edgeEndTangent2d() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let faceEdges = face.subShapes(ofType: .edge)
                if let edge = faceEdges.first {
                    if let tang = EdgeAnalysis.endTangent2d(edge, face: face, atEnd: false) {
                        // Just check it doesn't crash
                        let _ = tang
                    }
                }
            }
        }
    }

    @Test func edgePCurveRange() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let faceEdges = face.subShapes(ofType: .edge)
                if let edge = faceEdges.first {
                    let _ = EdgeAnalysis.checkPCurveRange(edge, face: face, first: 0, last: 10)
                }
            }
        }
    }

    // #1438: OCCTEdgeCheckPCurveRange used to compare [first, last] against the edge's own
    // CURRENT STORED TRIM on the face, rather than the pcurve's own underlying geometric domain
    // (ShapeAnalysis_Edge::CheckPCurveRange's real contract). Build an edge on a cylindrical
    // surface trimmed to only [0, pi/2] of a periodic (period 2*pi) circular pcurve, then query
    // [0, pi]: that's well within the pcurve's own period, so the real check accepts it, even
    // though it exceeds the edge's own [0, pi/2] trim, which is exactly what the old,
    // wrong-quantity comparison rejected.
    @Test func edgePCurveRangeChecksPCurveDomainNotEdgeTrim() {
        guard let surface = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5) else {
            Issue.record("failed to build cylindrical surface")
            return
        }
        guard let pcurve = Curve2D.circle(center: SIMD2(0, 5), radius: 3) else {
            Issue.record("failed to build periodic 2D pcurve")
            return
        }
        guard
            let edge = Shape.edgeOnSurface(pcurve: pcurve, surface: surface, u1: 0, u2: .pi / 2)
        else {
            Issue.record("failed to build edge on surface")
            return
        }
        guard let face = Shape.face(from: surface, uRange: 0...(2 * .pi), vRange: 0...10) else {
            Issue.record("failed to build face from surface")
            return
        }

        #expect(EdgeAnalysis.checkPCurveRange(edge, face: face, first: 0, last: .pi))
        // Sanity: a range exceeding the pcurve's own full period is still rejected.
        #expect(!EdgeAnalysis.checkPCurveRange(edge, face: face, first: 0, last: 2 * .pi + 0.5))
    }
}
