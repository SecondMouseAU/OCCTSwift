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
}
