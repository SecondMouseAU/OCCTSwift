import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepExtrema_DistanceSS")
struct BRepExtremaDistanceSSTests {
    @Test("distance between box vertices")
    func vertexDistance() {
        // Get vertices from two boxes at different positions
        if let box1 = Shape.box(width: 1, height: 1, depth: 1),
            let box2 = Shape.box(origin: SIMD3(10, 0, 0), width: 1, height: 1, depth: 1)
        {
            let verts1 = box1.subShapes(ofType: .vertex)
            let verts2 = box2.subShapes(ofType: .vertex)
            if let v1 = verts1.first, let v2 = verts2.first {
                let r = v1.distanceSS(to: v2)
                #expect(r.isDone)
                #expect(r.distance > 0)
            }
        }
    }

    @Test("distance between edge and vertex")
    func edgeVertexDistance() {
        // OCCT 8.0's low-level BRepExtrema_DistanceSS deliberately skips
        // edge-vertex pairs whose closest point lands at one of the edge's
        // endpoint-vertices (it expects the caller to pair vertices-with-
        // vertices separately). Use the high-level BRepExtrema_DistShapeShape
        // wrapper (Shape.distance(to:)) which handles all subshape pair
        // combinations including endpoint cases.
        if let box1 = Shape.box(width: 1, height: 1, depth: 1),
            let box2 = Shape.box(origin: SIMD3(5, 5, 0), width: 1, height: 1, depth: 1)
        {
            let edges1 = box1.subShapes(ofType: .edge)
            let verts2 = box2.subShapes(ofType: .vertex)
            if let e = edges1.first, let v = verts2.first {
                if let r = e.distance(to: v) {
                    #expect(r.distance > 0)
                } else {
                    Issue.record("edge-vertex distance should resolve via DistShapeShape")
                }
            }
        }
    }
}
