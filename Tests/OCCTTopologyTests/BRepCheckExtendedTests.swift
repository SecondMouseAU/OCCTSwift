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

    /// Before #1981 this asserted `0 < tol < 1`, which a doubled or otherwise wrong tolerance
    /// passes. A primitive box's vertices carry Precision::Confusion(), 1e-7, which is what
    /// ShapeAnalysis_ShapeTolerance reports (Scripts/repro/766-topology-brepcheck/).
    @Test func maxTolerance() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let tol = box.maxTolerance(type: 0)  // vertex
        #expect(abs(tol - 1e-7) < 1e-15, "max vertex tolerance \(tol)")
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

    /// Before #1981 this asserted only the returned `true`, which the bridge returns whenever
    /// nothing throws, so a fixer that set no tolerance at all passed. ShapeFix_ShapeTolerance::
    /// SetTolerance(0.01) leaves every vertex and edge at exactly 0.01.
    @Test func fixTolerance() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.fixTolerance(0.01))
        #expect(abs(box.maxTolerance(type: 0) - 0.01) < 1e-15, "vertex max after fix")
        #expect(abs(box.minTolerance(type: 0) - 0.01) < 1e-15, "vertex min after fix")
        #expect(abs(box.maxTolerance(type: 1) - 0.01) < 1e-15, "edge max after fix")
    }

    /// Before #1981 this asserted `ok || !ok`. The kernel's LimitTolerance reports whether it
    /// changed anything: on a fresh box (every tolerance 1e-7, under the 0.001 cap) it returns
    /// false and changes nothing; after raising everything to 0.01 it returns true and caps
    /// vertex and edge tolerances at 0.001.
    @Test func limitMaxTolerance() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.limitMaxTolerance(0.001) == false)
        #expect(abs(box.maxTolerance(type: 0) - 1e-7) < 1e-15)
        box.fixTolerance(0.01)
        #expect(box.limitMaxTolerance(0.001) == true)
        #expect(abs(box.maxTolerance(type: 0) - 0.001) < 1e-15, "vertex max after limit")
        #expect(abs(box.maxTolerance(type: 1) - 0.001) < 1e-15, "edge max after limit")
    }
}
