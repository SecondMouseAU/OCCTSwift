import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// MARK: - Face Property Tests

@Suite("Face, Outer Wire and ZLevel")
struct FacePropertyTests {
    @Test("Face outer wire exists")
    func faceOuterWire() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faces = box.faces()
        guard let face = faces.first else {
            Issue.record("Box should have faces")
            return
        }
        let wire = face.outerWire
        #expect(wire != nil)
    }

    @Test("Face(_:Shape) recovers a Face from a face-shape; rejects non-faces")
    func faceFromShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faceShapes = box.subShapes(ofType: .face)
        guard let fs = faceShapes.first else {
            Issue.record("Box should have face subshapes")
            return
        }
        // A face subshape converts to a Face whose area is 100 (10×10).
        let face = Face(fs)
        #expect(face != nil)
        if let f = face {
            #expect(abs(f.area() - 100) < 1e-6)
        }
        // The whole box is a TopoDS_Solid, not a Face, must reject.
        #expect(Face(box) == nil)
    }

    @Test("Edge(_:Shape) recovers an Edge from an edge-shape; rejects non-edges")
    func edgeFromShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edgeShapes = box.subShapes(ofType: .edge)
        guard let es = edgeShapes.first else {
            Issue.record("Box should have edge subshapes")
            return
        }
        let edge = Edge(es)
        #expect(edge != nil)
        if let e = edge {
            #expect(abs(e.length - 10) < 1e-6)
        }
        // The whole box is a TopoDS_Solid, not an Edge, must reject.
        #expect(Edge(box) == nil)
    }

    @Test("Wire(_:Shape) recovers a Wire from a wire-shape; rejects non-wires")
    func wireFromShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let wireShapes = box.subShapes(ofType: .wire)
        guard let ws = wireShapes.first else {
            Issue.record("Box should have wire subshapes")
            return
        }
        let wire = Wire(ws)
        #expect(wire != nil)
        // The whole box is a TopoDS_Solid, not a Wire, must reject.
        #expect(Wire(box) == nil)

        // Round-trip: Wire → Shape → Wire produces a wire that builds the
        // same face as the original.
        guard let original = Wire.rectangle(width: 4, height: 6) else {
            Issue.record("rectangle wire creation failed")
            return
        }
        guard let asShape = Shape.fromWire(original),
            let recovered = Wire(asShape)
        else {
            Issue.record("Wire round-trip via Shape failed")
            return
        }
        let originalFace = Shape.face(from: original)
        let recoveredFace = Shape.face(from: recovered)
        if let a = originalFace, let b = recoveredFace {
            // Same rectangle area.
            let fa = Face(a)
            let fb = Face(b)
            if let fa, let fb {
                #expect(abs(fa.area() - fb.area()) < 1e-6)
                #expect(abs(fa.area() - 24) < 1e-6)
            }
        } else {
            Issue.record("Face construction from wires failed")
        }
    }

    @Test("Horizontal face zLevel")
    func horizontalFaceZLevel() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let horizontal = box.faces().filter { $0.isHorizontal() }
        #expect(!horizontal.isEmpty)
        // At least one should have a defined zLevel
        let withZ = horizontal.compactMap { $0.zLevel }
        #expect(!withZ.isEmpty)
    }
}
