import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// MARK: - Face Property Tests

@Suite("Face, Outer Wire and ZLevel")
struct FacePropertyTests {
    @Test("Face outer wire exists")
    func faceOuterWire() throws {
        // Every face of a 10-cube is bounded by one wire of four edges of length 10.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.faces()
        #expect(faces.count == 6)
        for face in faces {
            let wire = try #require(face.outerWire)
            let edges = wire.edges()
            #expect(edges.count == 4)
            for edge in edges { #expect(abs(edge.length - 10) < 1e-9) }
        }

        // With a hole, the outer wire is the 20x20 boundary and not the 4x4 hole: perimeter 80.
        let plate = try #require(Shape.box(origin: .zero, width: 20, height: 20, depth: 4))
        let hole = try #require(Shape.box(origin: SIMD3(8, 8, -1), width: 4, height: 4, depth: 6))
        let drilled = try #require(plate.subtracting(hole))
        let top = try #require(drilled.faces().first { ($0.zLevel ?? 0) > 3.9 })
        let outer = try #require(top.outerWire)
        #expect(outer.edges().count == 4)
        let perimeter = outer.edges().map(\.length).reduce(0, +)
        #expect(abs(perimeter - 80) < 1e-9)
    }

    @Test("Face(_:Shape) recovers a Face from a face-shape; rejects non-faces")
    func faceFromShape() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
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
    func edgeFromShape() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
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
    func wireFromShape() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
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
    func horizontalFaceZLevel() throws {
        // The box spans z in [-5, 5]: exactly the bottom and top faces are horizontal, and their
        // levels are -5 and +5. The four walls are not horizontal and have no z level.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let horizontal = box.faces().filter { $0.isHorizontal() }
        #expect(horizontal.count == 2)
        let levels = horizontal.compactMap { $0.zLevel }.sorted()
        #expect(levels.count == 2)
        if levels.count == 2 {
            #expect(abs(levels[0] + 5) < 1e-9)
            #expect(abs(levels[1] - 5) < 1e-9)
        }
        for wall in box.faces() where !wall.isHorizontal() {
            #expect(wall.zLevel == nil)
        }
    }
}
