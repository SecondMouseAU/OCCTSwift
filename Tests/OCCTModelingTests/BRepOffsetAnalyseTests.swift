import Testing
import simd

@testable import OCCTSwift

@Suite("BRepOffset_Analyse Tests")
struct BRepOffsetAnalyseTests {

    @Test func allBoxEdgesConvex() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let types = box.analyseEdgeConcavity()
            #expect(types.count == 12)
            for t in types {
                #expect(t == .convex)
            }
        }
    }

    @Test func explodeByConvexity() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let result = box.analyseExplode(type: .convex)
            #expect(result != nil)
        }
    }

    @Test func convexEdgesOnFace() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let count = box.analyseEdgesOnFace(face, type: .convex)
                #expect(count == 4)
            }
        }
    }

    @Test func ancestorCountForEdge() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let count = box.analyseAncestorCount(edge: edge)
                #expect(count == 2)
            }
        }
    }

    @Test func tangentEdgesAtCorner() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            let verts = box.subShapes(ofType: .vertex)
            if let edge = edges.first, let v = verts.first {
                let count = box.analyseTangentEdgeCount(edge: edge, vertex: v)
                // Box corners are 90°, no tangent edges
                #expect(count == 0)
            }
        }
    }
}
