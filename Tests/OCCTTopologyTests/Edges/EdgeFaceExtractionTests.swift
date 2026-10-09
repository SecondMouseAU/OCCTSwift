import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Edge/Face Extraction Tests")
struct EdgeFaceExtractionTests {

    @Test func extractEdgeCurve3D() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                if let result = edge.extractEdgeCurve3D() {
                    #expect(result.last > result.first || result.last == result.first)
                }
            }
        }
    }

    @Test func edgeTolerance() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let tol = edge.edgeTolerance
                #expect(tol > 0)
            }
        }
    }

    @Test func edgeIsDegenerated() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                #expect(!edge.isEdgeDegenerated)
            }
        }
    }

    @Test func extractFaceSurface() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                if let surface = face.extractFaceSurface() {
                    let _ = surface.domain
                }
            }
        }
    }

    @Test func faceTolerance() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let tol = face.faceTolerance
                #expect(tol > 0)
            }
        }
    }

    @Test func faceWireCount() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let wc = face.faceWireCount
                #expect(wc >= 1)
            }
        }
    }

    @Test func vertexTolerance() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let vertices = box.subShapes(ofType: .vertex)
            if let vertex = vertices.first {
                let tol = vertex.vertexTolerance
                #expect(tol > 0)
            }
        }
    }

    @Test func vertexPoint() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let vertices = box.subShapes(ofType: .vertex)
            if let vertex = vertices.first {
                let pt = vertex.vertexPoint
                // A vertex of a 10x10x10 box centered at origin should have coords in [-5, 5]
                #expect(abs(pt.x) <= 6)
                #expect(abs(pt.y) <= 6)
                #expect(abs(pt.z) <= 6)
            }
        }
    }

    @Test func extractEdgePCurve() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            let edges = box.subShapes(ofType: .edge)
            // Try to find an edge that has a PCurve on some face
            for face in faces {
                for edge in edges {
                    if let result = edge.extractEdgePCurve(onFace: face) {
                        #expect(result.last >= result.first)
                        return
                    }
                }
            }
        }
    }
}
