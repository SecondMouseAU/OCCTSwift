import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.122.0, ShapeFix_Edge Extended")
struct ShapeFixEdgeExtendedTests {
    @Test("Add and remove 3D curve")
    func addRemoveCurve3d() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let edges = b.subShapes(ofType: .edge)
            #expect(edges.count > 0)
            if edges.count > 0 {
                let edge = edges[0]
                // Edge already has a 3D curve, remove it then add back
                let removed = Shape.fixEdgeRemoveCurve3d(edge)
                // May or may not succeed depending on edge type
                if removed {
                    let added = Shape.fixEdgeAddCurve3d(edge)
                    #expect(added)
                }
            }
        }
    }

    @Test("Add PCurve to edge on face")
    func addPCurve() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            let edges = b.subShapes(ofType: .edge)
            if faces.count > 0, edges.count > 0 {
                // PCurve may already exist; this should be safe to call
                let _ = Shape.fixEdgeAddPCurve(edges[0], face: faces[0], isSeam: false)
                // Just verify it doesn't crash
            }
        }
    }

    @Test("Remove PCurve from edge on face")
    func removePCurve() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            let edges = b.subShapes(ofType: .edge)
            if faces.count > 0, edges.count > 0 {
                let _ = Shape.fixEdgeRemovePCurve(edges[0], face: faces[0])
                // Just verify it doesn't crash
            }
        }
    }

    @Test("Fix reversed 2D curve")
    func fixReversed2d() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            let edges = b.subShapes(ofType: .edge)
            if faces.count > 0, edges.count > 0 {
                let _ = Shape.fixEdgeReversed2d(edges[0], face: faces[0])
                // Just verify it doesn't crash
            }
        }
    }
}
