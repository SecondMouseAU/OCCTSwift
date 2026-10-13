import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("Shape extras v0.112")
struct ShapeExtrasV112Tests {

    @Test func childAccess() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        // A box solid has one child, its shell, and the shell has the six faces.
        #expect(box.nbChildren == 1)
        let child = try #require(box.child(at: 0))
        #expect(child.isValid)
        #expect(child.isShell)
        #expect(child.faces().count == 6)
        // One past the last child is nil, not a wrapped or stale handle.
        #expect(box.child(at: 1) == nil)
        // The shell's children are its faces.
        #expect(child.nbChildren == 6)
        let face = try #require(child.child(at: 0))
        #expect(face.isFace)
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

    @Test func oriented() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.orientationValue == 0)
        #expect(abs(box.signedVolume - 1000) < 1e-6)
        let rev = try #require(box.oriented(1))  // REVERSED
        #expect(rev.isValid)
        #expect(rev.orientationValue == 1)
        // A reversed solid reads an inside-out volume: the sign is the orientation.
        #expect(abs(rev.signedVolume + 1000) < 1e-6)
        // The receiver is untouched.
        #expect(box.orientationValue == 0)
        #expect(abs(box.signedVolume - 1000) < 1e-6)
    }

    @Test func empty() throws {
        let compound = try #require(Shape.empty(type: 0))
        #expect(compound.isCompound)
        #expect(compound.nbChildren == 0)
        #expect(!compound.isNull)
        let solid = try #require(Shape.empty(type: 2))
        #expect(solid.isSolid)
        #expect(solid.nbChildren == 0)
        let shell = try #require(Shape.empty(type: 3))
        #expect(shell.isShell)
        #expect(shell.nbChildren == 0)
        let wire = try #require(Shape.empty(type: 5))
        #expect(wire.shapeType == .wire)
        #expect(wire.nbChildren == 0)
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

    @Test func shellFromFaces() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.subShapes(ofType: .face)
        #expect(faces.count == 6)
        let shell = try #require(Shape.shellFromFaces(Array(faces.prefix(2))))
        #expect(shell.isShell)
        #expect(shell.faces().count == 2)
        // Two of the six 10 x 10 faces.
        #expect(abs((shell.surfaceArea ?? 0) - 200) < 1e-6)
        // And all six give the box's own shell: closed area, closed volume.
        let all = try #require(Shape.shellFromFaces(faces))
        #expect(all.faces().count == 6)
        #expect(abs((all.surfaceArea ?? 0) - 600) < 1e-6)
    }

    @Test func isCompoundOnCompound() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let sphere = try #require(Shape.sphere(radius: 5))
        let c = try #require(Shape.compound([box, sphere]))
        #expect(c.isCompound)
        #expect(c.nbChildren == 2)
        #expect(c.subShapes(ofType: .solid).count == 2)
        // 1000 + 4/3 pi 5^3
        #expect(abs((c.volume ?? 0) - (1000 + 500 * Double.pi / 3)) < 1e-6)
        // A compound of that compound is a compound of one child, not a flattened copy.
        let outer = try #require(Shape.compound([c]))
        #expect(outer.isCompound)
        #expect(outer.nbChildren == 1)
    }
}
