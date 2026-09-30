import Foundation
import Testing

@testable import OCCTSwift

/// The linear-deflection floor every `BRepMesh_IncrementalMesh` entry point applies (#2879).
///
/// The bound is `Precision::Confusion()`, 1e-7, and it is OCCT's: `incmesh` clamps its `LinDefl`
/// argument up to it (`MeshTest.cxx:208`), refuses `-di` below it (`MeshTest.cxx:199`),
/// `Prs3d::GetDeflection` floors the presentation path at it (`Prs3d.hxx:71`), and
/// `BRepMesh_IncrementalMesh::initParameters` throws `Standard_NumericError` below it
/// (`BRepMesh_IncrementalMesh.hxx:81`).
///
/// **What each case here can and cannot prove**, because the kernel already refuses some of them:
///
/// - **NaN is the regression.** `NaN < x` is false, so NaN passes all four of those tests. Against
///   the unguarded bridge a box meshes at an unstated deflection (24 nodes, measured) and a free
///   circular edge yields 22,216 wireframe vertices, so every NaN case below fails without the
///   guard rather than hanging.
/// - **Zero and negative are contract assertions, not regressions.** `initParameters` throws on
///   them in under a second and the bridge's own `catch` already produced the same refusal, so
///   they pass with the guard and without it. They are here to pin the documented answer. The
///   exporter cases turned out to be the same: measured against the unguarded bridge they still
///   threw, so they document the contract rather than catching the defect.
/// - **The floor value itself must be accepted**, which is what makes the guard `>=` and not `>`.
///
/// A curved solid is deliberately absent from the NaN cases. `Shape.cylinder(radius: 10, height: 5)`
/// with a NaN deflection did not return in ten minutes on the unguarded bridge, and a test that
/// stalls CI when a guard is removed is worse than one that fails. That measurement lives in
/// `Scripts/repro/2879/`, which carries its own timeout.
@Suite("Issue2879 Mesh Deflection Guard")
struct Issue2879MeshDeflectionGuardTests {

    /// A shape with planar faces only, so a degenerate deflection is cheap rather than slow.
    private func box() -> Shape? {
        Shape.box(width: 10, height: 5, depth: 3)
    }

    /// A shape with no face at all, which `BRepMesh_IncrementalMesh` still tessellates as a free
    /// edge (`IMeshTools_ShapeExplorer.cxx:71`).
    private func freeCircularEdge() -> Shape? {
        guard let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 10)
        else { return nil }
        return Shape.edgeFromCurve(circle)
    }

    @Test("A NaN deflection is refused by every mesh entry point that takes one")
    func nanIsRefused() throws {
        let shape = try #require(box())

        #expect(shape.mesh(linearDeflection: .nan) == nil)
        #expect(shape.shadedMesh(deflection: .nan) == nil)
        #expect(shape.edgeMesh(deflection: .nan) == nil)
        #expect(shape.selfIntersection(meshDeflection: .nan) == nil)
        #expect(shape.selfIntersectionPairs(deflection: .nan).isEmpty)
        #expect(shape.proximityFaces(with: shape, tolerance: 0.5, deflection: .nan).isEmpty)
        #expect(
            shape.hlrPolyEdges(direction: SIMD3(0, 0, 1), category: .visibleSharp, deflection: .nan)
                == nil)
        #expect(Drawing.projectFast(shape, direction: SIMD3(0, 0, 1), deflection: .nan) == nil)
        #expect(CoherentTriangulation.createFromMesh(shape, deflection: .nan) == nil)

        var params = MeshParameters.default
        params.deflection = .nan
        #expect(shape.mesh(parameters: params) == nil)
    }

    @Test("A NaN deflection is refused on a face-free shape, where the tessellator still runs")
    func nanIsRefusedOnAFreeEdge() throws {
        let edge = try #require(freeCircularEdge())

        // Unguarded this returns 22,216 vertices for the one edge, where a valid request gives 33.
        #expect(edge.edgeMesh(deflection: .nan) == nil)
        #expect(edge.shadedMesh(deflection: .nan) == nil)

        // The same edge at a serviceable deflection still works, so the refusal is the value's and
        // not the shape's.
        let good = edge.edgeMesh(deflection: 0.1)
        #expect(good != nil)
    }

    @Test("A NaN deflection is refused by the tessellating exporters")
    func nanIsRefusedByExporters() throws {
        let shape = try #require(box())
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("occtswift-2879-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        #expect(throws: (any Error).self) {
            try Exporter.writeSTL(shape: shape, to: dir.appendingPathComponent("a.stl"),
                                  deflection: .nan)
        }
        #expect(throws: (any Error).self) {
            try Exporter.writeOBJ(shape: shape, to: dir.appendingPathComponent("a.obj"),
                                  deflection: .nan)
        }
        #expect(throws: (any Error).self) {
            try Exporter.writeGLTF(shape: shape, to: dir.appendingPathComponent("a.glb"),
                                   deflection: .nan)
        }
    }

    @Test("Zero and negative deflections are refused, as the kernel itself already refuses them")
    func zeroAndNegativeAreRefused() throws {
        let shape = try #require(box())

        for value in [0.0, -1.0, 1e-12, 9e-8] {
            #expect(shape.mesh(linearDeflection: value) == nil, "mesh(\(value))")
            #expect(shape.shadedMesh(deflection: value) == nil, "shadedMesh(\(value))")
            #expect(shape.edgeMesh(deflection: value) == nil, "edgeMesh(\(value))")
        }
    }

    @Test("The floor value itself is accepted, so the bound is inclusive")
    func theFloorValueIsAccepted() throws {
        // A box has planar faces, so meshing at the floor costs nothing. The same request on a
        // curved solid terminates too but takes about ninety seconds; see Scripts/repro/2879/.
        let shape = try #require(box())

        #expect(shape.mesh(linearDeflection: 1e-7) != nil)
        #expect(shape.shadedMesh(deflection: 1e-7) != nil)
        #expect(shape.edgeMesh(deflection: 1e-7) != nil)
    }
}
