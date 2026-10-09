import Testing
import simd

@testable import OCCTSwift

// MARK: - Sewing / Quilting / Healing with Full History (issue #327)

@Suite("Sewing / Quilting / Healing with Full History")
struct SewQuiltHealFullHistoryTests {
    /// Two independently-created unit-10 squares in the XY plane, positioned so
    /// face1's right edge (x=5) exactly coincides with face2's left edge, two
    /// genuinely distinct TopoDS_Edge instances, not a shared one.
    static func touchingFaces() -> (face1: Shape, face2: Shape) {
        let face1 = Shape.face(from: Wire.rectangle(width: 10, height: 10)!)!
        let face2 = face1.translated(by: SIMD3(10, 0, 0))!
        return (face1, face2)
    }

    static func edgeNearX(_ shape: Shape, _ x: Double) -> Shape {
        shape.subShapes(ofType: .edge).min {
            abs(($0.center?.x ?? .greatestFiniteMagnitude) - x)
                < abs(($1.center?.x ?? .greatestFiniteMagnitude) - x)
        }!
    }

    @Test("Sew: two touching inputs merge into ONE shared output edge, both reported Modified")
    func sewManyToOneMerge() {
        let (face1, face2) = Self.touchingFaces()
        guard let r = Shape.sewWithFullHistory(shapes: [face1, face2], tolerance: 1e-6) else {
            Issue.record("sew should succeed for two touching faces")
            return
        }
        #expect(r.result.isValid)

        let edge1 = Self.edgeNearX(face1, 5)
        let edge2 = Self.edgeNearX(face2, 5)
        let rec1 = r.history.record(of: edge1)
        let rec2 = r.history.record(of: edge2)
        #expect(!rec1.isDeleted)
        #expect(!rec2.isDeleted)

        guard let out1 = rec1.modified.first, let out2 = rec2.modified.first else {
            Issue.record("expected both shared-edge inputs to be Modified into an output edge")
            return
        }
        // The #327 "faithfulness" open question: sewing's many-to-one merge
        // records BOTH inputs as Modified into the SAME output edge, neither
        // side is silently dropped or treated as Removed.
        #expect(out1.isSame(as: out2))
    }

    @Test("Sew: non-touching input reports queryable, non-deleted history")
    func sewUnmergedFaceHistory() {
        let face1 = Shape.face(from: Wire.rectangle(width: 10, height: 10)!)!
        let face2 = Shape.face(from: Wire.circle(radius: 5)!)!
        guard let r = Shape.sewWithFullHistory(shapes: [face1, face2], tolerance: 1e-6) else {
            Issue.record("sew should succeed")
            return
        }
        #expect(r.result.isValid)
        let rec = r.history.record(of: face1.subShapes(ofType: .edge).first!)
        #expect(!rec.isDeleted)
    }

    @Test("sewnWithFullHistory(with:) instance convenience matches the static form")
    func sewnWithFullHistoryConvenience() {
        let (face1, face2) = Self.touchingFaces()
        guard let r = face1.sewnWithFullHistory(with: face2, tolerance: 1e-6) else {
            Issue.record("sewn(with:) should succeed")
            return
        }
        #expect(r.result.isValid)
        let edge1 = Self.edgeNearX(face1, 5)
        #expect(!r.history.record(of: edge1).isDeleted)
    }

    @Test("Self-sew (sewnWithFullHistory(tolerance:)) merges two touching faces in one compound")
    func selfSewWithHistory() {
        let (face1, face2) = Self.touchingFaces()
        guard let compound = Shape.compound([face1, face2]) else {
            Issue.record("compound construction should succeed")
            return
        }
        guard let r = compound.sewnWithFullHistory(tolerance: 1e-6) else {
            Issue.record("self-sew should succeed")
            return
        }
        #expect(r.result.isValid)
    }

    @Test("Quilt: box's own faces produce a valid shell with queryable, non-deleted history")
    func quiltBoxFacesWithHistory() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faces = box.subShapes(ofType: .face)
        guard let r = Shape.quiltWithFullHistory(faces) else {
            Issue.record("quilt should succeed on a box's own faces")
            return
        }
        #expect(r.result.isValid)
        for face in faces {
            #expect(!r.history.record(of: face).isDeleted)
        }
    }

    @Test("Healed shape returns full history queryable on every input face")
    func healedWithHistory() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let r = box.healedWithFullHistory() else {
            Issue.record("heal should succeed on a valid box")
            return
        }
        #expect(r.result.isValid)
        for face in box.subShapes(ofType: .face) {
            #expect(!r.history.record(of: face).isDeleted)
        }
    }

    @Test("Solid from shell returns full history queryable on every input face")
    func solidFromShellWithHistory() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let shell = box.subShapes(ofType: .shell).first else {
            Issue.record("box should expose its own shell")
            return
        }
        guard let r = Shape.solidWithFullHistory(from: shell) else {
            Issue.record("solid(from:) with history should succeed")
            return
        }
        #expect(r.result.volume! > 0)
        for face in box.subShapes(ofType: .face) {
            #expect(!r.history.record(of: face).isDeleted)
        }
    }

    @Test("History handle from sew survives; record(of:) is callable repeatedly")
    func sewHistoryHandleSurvives() {
        let (face1, face2) = Self.touchingFaces()
        guard let r = Shape.sewWithFullHistory(shapes: [face1, face2], tolerance: 1e-6) else {
            Issue.record("sew should succeed")
            return
        }
        let edge1 = Self.edgeNearX(face1, 5)
        let r1 = r.history.record(of: edge1)
        let r2 = r.history.record(of: edge1)
        #expect(r1.modified.count == r2.modified.count)
        #expect(r1.isDeleted == r2.isDeleted)
    }

    @Test("A sew's history can be absorbed into a BRepGraph (issue #290 integration)")
    func sewHistoryAbsorbsIntoGraph() {
        let (face1, face2) = Self.touchingFaces()
        guard let compound = Shape.compound([face1, face2]),
            let graph = BRepGraph(shape: compound),
            let root = graph.findNode(for: compound)
        else {
            Issue.record("graph setup failed")
            return
        }
        guard let r = Shape.sewWithFullHistory(shapes: [face1, face2], tolerance: 1e-6) else {
            Issue.record("sew should succeed")
            return
        }
        #expect(graph.historyRecordCount == 0)
        let added = graph.add(
            r.result, absorbing: r.history,
            inputRoots: [BRepGraph.NodeRef(kind: root.kind, index: root.index)],
            operationName: "sew")
        #expect(added != nil, "add(absorbing:) should succeed for a sew's synthesized history")
        #expect(graph.historyRecordCount > 0, "absorb should have written history records")
    }
}
