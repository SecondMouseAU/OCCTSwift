import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// Before #1981 none of these four tests could fail: three asserted only `isValid` after a call
// that cannot make a valid box invalid, and the continuity test accepted nil or any class.
// Three of them are now pinned to what the BRepLib static reports in
// Scripts/repro/766-topology-brepclass-breplib/transcript.txt.
//
// `ensureNormalConsistency` was the exception and is now pinned too, to the values
// `Scripts/repro/2905/` measures against this kernel rather than to the `== true` the v5
// execution branch wrote. #2337 made `occtAppendFaceTriangulation` call
// `BRepLib_ToolTriangulatedShape::ComputeNormals` on every face it walks, so `Shape.mesh` leaves
// each triangulation carrying surface-derived normals and `BRepLib::EnsureNormalConsistency` has
// nothing left to add on a box. See #2905.
@Suite("v0.122.0, BRepLib Extended Statics")
struct BRepLibExtendedTests {
    /// `BRepLib::EnsureNormalConsistency` returns true when it **wrote** a normal, in either of
    /// the two things it does: adding surface-derived normals to a triangulated face that has
    /// none, and averaging the two normals at a shared node whose dot product exceeds
    /// `cos(maxAngle)`.
    ///
    /// So the answer depends on both the shape and how it was triangulated, and the three cases
    /// here are the three answers, all measured in `Scripts/repro/2905/`:
    ///
    /// - a box through `Shape.mesh` is `false`, because the normals are already there and a
    ///   90 degree join is nowhere near `cos(0.01)`;
    /// - a box triangulated without normals is `true` once and `false` after that;
    /// - a cylinder is `true` every time, because its seam nodes are smooth and get re-averaged.
    @Test("Ensure normal consistency")
    func ensureNormalConsistency() throws {
        let meshed = try #require(Shape.box(width: 10, height: 10, depth: 10))
        _ = try #require(meshed.mesh(linearDeflection: 0.5))
        #expect(meshed.ensureNormalConsistency(maxAngle: 0.01) == false)
        #expect(meshed.isValid)

        // CoherentTriangulation.createFromMesh triangulates without computing normals, so here
        // the call has the first of its two jobs to do.
        let bare = try #require(Shape.box(width: 10, height: 10, depth: 10))
        _ = try #require(CoherentTriangulation.createFromMesh(bare, deflection: 0.5))
        #expect(bare.subShapes(ofType: .face).allSatisfy { !$0.triangulationHasNormals })
        #expect(bare.ensureNormalConsistency(maxAngle: 0.01) == true)
        #expect(bare.subShapes(ofType: .face).allSatisfy { $0.triangulationHasNormals })
        #expect(bare.ensureNormalConsistency(maxAngle: 0.01) == false)

        // A curved solid has the second job to do, on every pass, because the seam normals stay
        // within the tolerance of each other after averaging.
        let curved = try #require(Shape.cylinder(radius: 10, height: 5))
        _ = try #require(curved.mesh(linearDeflection: 0.5))
        #expect(curved.ensureNormalConsistency(maxAngle: 0.01) == true)
        #expect(curved.ensureNormalConsistency(maxAngle: 0.01) == true)
    }

    /// BRepLib::UpdateDeflection rewrites each triangulation's recorded deflection, which
    /// Face.bounds reads back as its enlargement (BRepBndLib::Add with triangulation).
    ///
    /// After
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

    /// Edge 0 of the box is shared by faces 0 and 2, a sharp 90 degree join, so the class is C0.
    ///
    /// The edge runs along x = -5, y = -5; face 0 is the x = -5 plane and face 2 the y = -5
    /// plane. The old test paired faces 0 and 1, which are opposite sides and share no edge,
    /// and accepted any answer.
    @Test("Continuity of faces")
    func continuityAcrossASharedEdge() throws {
        let b = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = b.subShapes(ofType: .face)
        let edges = b.subShapes(ofType: .edge)
        try #require(faces.count == 6 && edges.count == 12)
        let cont = Shape.continuityClassOfFaces(edge: edges[0], face1: faces[0], face2: faces[2])
        #expect(cont == .c0)
    }

    /// Clearing edge 0's SameParameter flag makes the box invalid (BRepCheck flags it).
    ///
    /// BRepLib::SameParameter recomputes the edge and sets the flag again, so the box is valid
    /// after the call. A no-op sameParameterAll leaves it invalid.
    @Test("Same parameter all")
    func sameParameterAll() throws {
        let b = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = b.edges()
        try #require(edges.count == 12)
        // `withHandle`, not `edges[0].handle`: the bare form lets an optimised build free the
        // array's `Edge` before the setter runs, so the flag is never cleared (#3130, #2929; measured
        // on release wasm, where a fresh edge walk read all 12 flags still true. Debug builds extend
        // lifetimes to scope end, which is why Apple's debug run passed).
        edges[0].withHandle { OCCTEdgeSetSameParameter($0, false) }
        let cleared = b.edges().first.flatMap { OCCTShapeFromEdge($0.handle) }
            .map { Shape(handle: $0).edgeSameParameter }
        #expect(cleared == false, "the setter must reach the TShape the box shares")
        #expect(b.isValid == false, "a cleared SameParameter flag should fail BRepCheck")
        b.sameParameterAll(tolerance: 1e-5)
        #expect(b.isValid)
    }
}
