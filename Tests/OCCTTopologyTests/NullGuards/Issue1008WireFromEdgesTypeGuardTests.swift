import Foundation
import Testing

@testable import OCCTSwift

/// #1008: `Shape.wireFromEdges(_:)` and `Shape.shellFromFaces(_:)` cast every element they are
/// handed with `TopoDS::Edge` / `TopoDS::Face` and hand the result to a builder.
///
/// `TopoDS::Edge`'s own guard reads `theShape.IsNull() ? false : theShape.ShapeType() !=
/// TopAbs_EDGE`, so it refuses a wrong-typed shape and passes a NULL one straight through.
/// `TopoDS_Shape::ShapeType()` is `myTShape->ShapeType()` with no null test, so the builder then
/// dereferences a null handle: a SIGSEGV, which no `catch (...)` on the bridge side can absorb.
/// `Shape.nullified` is a public property returning exactly such a shape, so both entry points
/// were reachable from Swift alone.
///
/// The wrong-typed cases below are a contract pin rather than a proof: they pass against the
/// unfixed bridge too, because two independent kernel guards already refuse them, one of which
/// (`TopoDS_Builder::Add`'s compatibility table) is an unconditional `throw` rather than a macro.
/// `Scripts/repro/1008-topods-cast-guard/` measures all of that.
@Suite("wireFromEdges and shellFromFaces refuse a shape of the wrong type (#1008)")
struct Issue1008WireFromEdgesTypeGuard {

    private func makeBox() -> Shape? {
        Shape.box(width: 10, height: 10, depth: 10)
    }

    // MARK: - The null shape, the case that crashed

    @Test("wireFromEdges refuses a nullified shape instead of dereferencing it")
    func wireFromEdgesRefusesANullifiedShape() throws {
        let box = try #require(makeBox())
        let nullShape = try #require(box.nullified)
        #expect(Shape.wireFromEdges([nullShape]) == nil)
    }

    @Test("shellFromFaces refuses a nullified shape instead of dereferencing it")
    func shellFromFacesRefusesANullifiedShape() throws {
        let box = try #require(makeBox())
        let nullShape = try #require(box.nullified)
        #expect(Shape.shellFromFaces([nullShape]) == nil)
    }

    @Test("A nullified shape after a real edge is refused, not skipped")
    func wireFromEdgesRefusesANullifiedShapeAfterARealEdge() throws {
        let box = try #require(makeBox())
        let edges = box.subShapes(ofType: .edge)
        try #require(!edges.isEmpty)
        let nullShape = try #require(box.nullified)
        #expect(Shape.wireFromEdges([edges[0], nullShape]) == nil)
    }

    // MARK: - The wrong-typed shapes, pinned rather than proven

    @Test("wireFromEdges refuses a wire, a face, a solid and a vertex")
    func wireFromEdgesRefusesEveryNonEdge() throws {
        let box = try #require(makeBox())
        let wires = box.subShapes(ofType: .wire)
        let faces = box.subShapes(ofType: .face)
        let vertices = box.subShapes(ofType: .vertex)
        try #require(!wires.isEmpty)
        try #require(!faces.isEmpty)
        try #require(!vertices.isEmpty)

        #expect(Shape.wireFromEdges([wires[0]]) == nil)
        #expect(Shape.wireFromEdges([faces[0]]) == nil)
        #expect(Shape.wireFromEdges([box]) == nil)
        #expect(Shape.wireFromEdges([vertices[0]]) == nil)
    }

    @Test("shellFromFaces refuses an edge, a wire, a solid and a vertex")
    func shellFromFacesRefusesEveryNonFace() throws {
        let box = try #require(makeBox())
        let edges = box.subShapes(ofType: .edge)
        let wires = box.subShapes(ofType: .wire)
        let vertices = box.subShapes(ofType: .vertex)
        try #require(!edges.isEmpty)
        try #require(!wires.isEmpty)
        try #require(!vertices.isEmpty)

        #expect(Shape.shellFromFaces([edges[0]]) == nil)
        #expect(Shape.shellFromFaces([wires[0]]) == nil)
        #expect(Shape.shellFromFaces([box]) == nil)
        #expect(Shape.shellFromFaces([vertices[0]]) == nil)
    }

    // MARK: - The guard did not swallow the supported input

    @Test("A real edge still builds a wire, and a real face still builds a shell")
    func theSupportedInputsStillWork() throws {
        let box = try #require(makeBox())
        let edges = box.subShapes(ofType: .edge)
        let faces = box.subShapes(ofType: .face)
        try #require(!edges.isEmpty)
        try #require(!faces.isEmpty)

        let wire = try #require(Shape.wireFromEdges([edges[0]]))
        #expect(wire.shapeType == .wire)
        #expect(wire.subShapes(ofType: .edge).count == 1)

        let shell = try #require(Shape.shellFromFaces([faces[0]]))
        #expect(shell.shapeType == .shell)
        #expect(shell.subShapes(ofType: .face).count == 1)
    }
}
