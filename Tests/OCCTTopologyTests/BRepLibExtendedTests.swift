import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.122.0, BRepLib Extended Statics")
struct BRepLibExtendedTests {
    @Test("Ensure normal consistency")
    func ensureNormalConsistency() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let _ = b.mesh(linearDeflection: 0.5)
            let _ = b.ensureNormalConsistency(maxAngle: 0.01)
            // Just verify no crash
            #expect(b.isValid)
        }
    }

    @Test("Update deflection")
    func updateDeflection() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let _ = b.mesh(linearDeflection: 0.5)
            b.updateDeflection()
            #expect(b.isValid)
        }
    }

    @Test("Continuity of faces")
    func continuityAcrossASharedEdge() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            let edges = b.subShapes(ofType: .edge)
            if faces.count >= 2, edges.count > 0 {
                // Try to find a shared edge between two faces. Whatever comes back must be a
                // class the vocabulary actually has, the old `>= -1` was true of every Int
                // (#495); Issue495FaceContinuityTests pins the values per geometry.
                let cont = Shape.continuityClassOfFaces(
                    edge: edges[0],
                    face1: faces[0], face2: faces[1])
                #expect(cont == nil || ContinuityClass.allCases.contains(cont!))
            }
        }
    }

    @Test("Same parameter all")
    func sameParameterAll() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            b.sameParameterAll(tolerance: 1e-5)
            #expect(b.isValid)
        }
    }
}
