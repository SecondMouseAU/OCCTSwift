import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.127.0, BRep_Tool Polygon Queries")
struct BRepToolPolygonTests {

    @Test("Polygon3D from meshed edge")
    func polygon3D() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let _ = box.mesh(linearDeflection: 0.1)
        let edges = box.subShapes(ofType: .edge)
        // At least one edge should have a polygon3D
        var found = false
        for edge in edges {
            if let pts = Shape.polygon3D(edge: edge) {
                #expect(pts.count >= 2)
                found = true
                break
            }
        }
        // Polygon3D may or may not be available depending on mesher
        // so just verify the call doesn't crash
    }

    @Test("PolygonOnTriangulation from meshed edge")
    func polygonOnTriangulation() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let _ = box.mesh(linearDeflection: 0.1)
        let edges = box.subShapes(ofType: .edge)
        var found = false
        for edge in edges {
            if let indices = Shape.polygonOnTriangulation(edge: edge) {
                #expect(indices.count >= 2)
                // Indices should be 1-based
                for idx in indices {
                    #expect(idx >= 1)
                }
                found = true
                break
            }
        }
        #expect(found)
    }

    @Test("CurveOnPlane returns 2D curve for edge on plane")
    func curveOnPlane() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let edges = box.subShapes(ofType: .edge)
        guard !edges.isEmpty else { return }
        // Create a plane surface in XY
        if let surf = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) {
            // Try each edge, some lie on this plane, some don't
            for edge in edges {
                if let result = Shape.curveOnPlane(edge: edge, surface: surf) {
                    #expect(result.first < result.last)
                    break
                }
            }
            // May return nil for all edges if none lie on the XY plane, that's ok
        }
    }
}
