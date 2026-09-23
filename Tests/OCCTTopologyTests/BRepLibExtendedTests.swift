import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// Before #1981 none of these four tests could fail: three asserted only `isValid` after a call
// that cannot make a valid box invalid, and the continuity test accepted nil or any class. Each
// is now pinned to what the BRepLib static reports in
// Scripts/repro/766-topology-brepclass-breplib/transcript.txt.
@Suite("v0.122.0, BRepLib Extended Statics")
struct BRepLibExtendedTests {
    /// BRepMesh_IncrementalMesh(0.5) leaves a box's triangulation normals inconsistent across
    /// faces as far as BRepLib::EnsureNormalConsistency(0.01) is concerned, so the call reports
    /// that it changed them: true.
    @Test("Ensure normal consistency")
    func ensureNormalConsistency() throws {
        let b = try #require(Shape.box(width: 10, height: 10, depth: 10))
        _ = try #require(b.mesh(linearDeflection: 0.5))
        #expect(b.ensureNormalConsistency(maxAngle: 0.01) == true)
        #expect(b.isValid)
    }

    /// BRepLib::UpdateDeflection rewrites each triangulation's recorded deflection, which
    /// Face.bounds reads back as its enlargement (BRepBndLib::Add with triangulation). After
    /// BRepMesh the recorded value is already the measured one, so the kernel leaves the
    /// sphere's bounds at x -5.2377... to 5.2772... (deflection 0.31368...). The box is pinned
    /// after the call: a bridge that dropped the triangulation or wrote another deflection moves
    /// it. A bridge that skipped the call entirely cannot be told apart here, since the value it
    /// would rewrite is already the measured one.
    @Test("Update deflection")
    func updateDeflection() throws {
        let s = try #require(Shape.sphere(radius: 5))
        _ = try #require(s.mesh(linearDeflection: 0.5))
        s.updateDeflection()
        let face = try #require(s.faces().first)
        let bounds = try #require(face.bounds)
        #expect(abs(bounds.min.x - -5.2377188899960334) < 1e-9, "min.x \(bounds.min.x)")
        #expect(abs(bounds.max.x - 5.2772244954252638) < 1e-9, "max.x \(bounds.max.x)")
    }

    /// Edge 0 of the box runs along x = -5, y = -5 and is shared by faces 0 (x = -5) and 2
    /// (y = -5), a sharp 90 degree join: C0. (The old test paired faces 0 and 1, which are
    /// opposite sides and share no edge, and accepted any answer.)
    @Test("Continuity of faces")
    func continuityAcrossASharedEdge() throws {
        let b = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = b.subShapes(ofType: .face)
        let edges = b.subShapes(ofType: .edge)
        try #require(faces.count == 6 && edges.count == 12)
        let cont = Shape.continuityClassOfFaces(edge: edges[0], face1: faces[0], face2: faces[2])
        #expect(cont == .c0)
    }

    /// Clearing edge 0's SameParameter flag makes the box invalid (BRepCheck flags it);
    /// BRepLib::SameParameter recomputes the edge and sets the flag again, so the box is valid
    /// after the call. A no-op sameParameterAll leaves it invalid.
    @Test("Same parameter all")
    func sameParameterAll() throws {
        let b = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = b.edges()
        try #require(edges.count == 12)
        OCCTEdgeSetSameParameter(edges[0].handle, false)
        #expect(b.isValid == false, "a cleared SameParameter flag should fail BRepCheck")
        b.sameParameterAll(tolerance: 1e-5)
        #expect(b.isValid)
    }
}
