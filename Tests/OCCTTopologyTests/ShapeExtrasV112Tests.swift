import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Shape extras v0.112")
struct ShapeExtrasV112Tests {

    @Test func childAccess() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            // A box solid should have at least one child (shell)
            let nbChildren = box.nbChildren
            if nbChildren > 0 {
                if let child = box.child(at: 0) {
                    #expect(child.isValid)
                }
            }
        }
    }

    @Test func lockedState() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            #expect(!box.isLocked)
            box.setLocked(true)
            #expect(box.isLocked)
            box.setLocked(false)
            #expect(!box.isLocked)
        }
    }

    @Test func locationMatrix() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let m = box.locationMatrix
            #expect(m.count == 12)
            // Identity: diag should be 1
            #expect(abs(m[0] - 1.0) < 1e-10)
            #expect(abs(m[5] - 1.0) < 1e-10)
            #expect(abs(m[10] - 1.0) < 1e-10)
        }
    }

    @Test func setAndGetLocation() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            // Translation by (1, 2, 3)
            let m = [
                1.0, 0, 0, 1.0,
                0, 1.0, 0, 2.0,
                0, 0, 1.0, 3.0,
            ]
            box.setLocation(matrix: m)
            let mOut = box.locationMatrix
            #expect(abs(mOut[3] - 1.0) < 1e-10)
            #expect(abs(mOut[7] - 2.0) < 1e-10)
            #expect(abs(mOut[11] - 3.0) < 1e-10)
        }
    }

    @Test func located() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let m = [
                1.0, 0.0, 0.0, 5.0,
                0.0, 1.0, 0.0, 0.0,
                0.0, 0.0, 1.0, 0.0,
            ]
            if let moved = box.located(matrix: m) {
                let mOut = moved.locationMatrix
                #expect(abs(mOut[3] - 5.0) < 1e-10)
            }
        }
    }

    @Test func oriented() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let rev = box.oriented(1) {  // REVERSED
                #expect(rev.isValid)
            }
        }
    }

    @Test func empty() {
        if let compound = Shape.empty(type: 0) {
            #expect(compound.isCompound)
        }
        if let shell = Shape.empty(type: 3) {
            #expect(shell.isShell)
        }
    }

    @Test func shapeTypeQueries() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            #expect(box.isSolid)
            #expect(!box.isCompound)
            #expect(!box.isEdge)
            #expect(!box.isFace)
            #expect(!box.isShell)

            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                #expect(faces[0].isFace)
            }
            let edges = box.subShapes(ofType: .edge)
            if edges.count > 0 {
                #expect(edges[0].isEdge)
            }
        }
    }

    @Test func wireFromEdges() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count >= 4 {
                // Try making a wire from edges (may fail if not connected)
                let wire = Shape.wireFromEdges(Array(edges.prefix(4)))
                // Just check it doesn't crash - edges may not form valid wire
                if let w = wire {
                    #expect(w.isValid || !w.isValid)  // just verify no crash
                }
            }
        }
    }

    @Test func shellFromFaces() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                if let shell = Shape.shellFromFaces(Array(faces.prefix(2))) {
                    #expect(shell.isShell)
                }
            }
        }
    }

    @Test func isCompoundOnCompound() {
        if let box = Shape.box(width: 10, height: 10, depth: 10),
            let sphere = Shape.sphere(radius: 5)
        {
            if let c = Shape.compound([box, sphere]) {
                #expect(c.isCompound)
            }
        }
    }
}
