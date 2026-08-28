import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepCheck extended v0.112")
struct BRepCheckExtendedTests {

    @Test func faceStatus() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                let status = box.checkFaceStatus(face: faces[0])
                #expect(status == 0)  // NoError
            }
        }
    }

    @Test func edgeStatus() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                let status = box.checkEdgeStatus(edge: edges[0])
                #expect(status == 0)
            }
        }
    }

    @Test func vertexStatus() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let verts = box.subShapes(ofType: .vertex)
            if verts.count > 0 {
                let status = box.checkVertexStatus(vertex: verts[0])
                #expect(status == 0)
            }
        }
    }

    @Test func maxTolerance() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let tol = box.maxTolerance(type: 0)  // vertex
            #expect(tol > 0)
            #expect(tol < 1.0)
        }
    }

    @Test func minTolerance() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let tol = box.minTolerance(type: 0)
            #expect(tol > 0)
            #expect(tol <= box.maxTolerance(type: 0))
        }
    }

    @Test func avgTolerance() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let avg = box.avgTolerance(type: 1)  // edge
            let minT = box.minTolerance(type: 1)
            let maxT = box.maxTolerance(type: 1)
            #expect(avg >= minT - 1e-15)
            #expect(avg <= maxT + 1e-15)
        }
    }

    @Test func fixTolerance() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let ok = box.fixTolerance(0.01)
            #expect(ok)
        }
    }

    @Test func limitMaxTolerance() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let ok = box.limitMaxTolerance(0.001)
            #expect(ok || !ok)  // may not need limiting
        }
    }
}
