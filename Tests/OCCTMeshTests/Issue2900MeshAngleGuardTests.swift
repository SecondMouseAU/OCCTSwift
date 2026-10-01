import Foundation
import Testing

@testable import OCCTSwift

/// The angular-deflection floor every `BRepMesh_IncrementalMesh` entry point applies (#2900).
///
/// The bound is `Precision::Angular()`, 1e-12, and it is OCCT's:
/// `BRepMesh_IncrementalMesh::initParameters` throws `Standard_NumericError` on
/// `myParameters.Angle < Precision::Angular()` (`BRepMesh_IncrementalMesh.hxx:99`), the same
/// literal `throw` beside the linear one #2879 guards, one field along.
///
/// **What each case here can and cannot prove**, measured in `Scripts/repro/2900/` across 36
/// cases on a cylinder and a box through both constructors:
///
/// - **NaN is the regression.** `NaN < x` is false, so NaN passes that test. It does not throw and
///   it does not hang: it returns in about a second with `IsDone() == 1`, no status flag, and a
///   mesh built as though there were no angular criterion at all. On a radius-10 cylinder at a
///   linear deflection of 10.0, where the angle is the criterion that decides, a valid angle gives
///   254 nodes (0.05), 254 (0.2), 106 (0.5) or 54 (1.0), and NaN gives **18**. So every NaN case
///   below returns a `Mesh` rather than `nil` without the guard, and none of them stalls CI.
/// - **Zero, negative and just-below-the-floor are contract assertions, not regressions.**
///   `initParameters` throws on all three in under a second, on both shapes and through both
///   constructors, and the bridge's own `catch` already produced the same refusal. They pin the
///   documented answer.
/// - **The floor value itself must be accepted**, which is what makes the guard `>=` and not `>`.
///
/// `angleInterior` deliberately has no guard of its own, and the last test here is why: the
/// bridge only forwards it through `params.angleInterior > 0`, a test NaN fails, so a NaN interior
/// angle never reaches the kernel and the mesh is built from `angle` instead.
///
/// The two `DisplayDrawer` entry points are measured here too, and they turned out not to need
/// the guard at all; see `nanOnTheDrawerIsAbsorbedByPrs3dDrawer`.
@Suite("Issue2900 Mesh Angle Guard")
struct Issue2900MeshAngleGuardTests {

    /// A curved solid, where the angular deflection is the parameter that decides the
    /// tessellation at all. Cheap at every value here, because none of them subdivides finely.
    private func cylinder() -> Shape? {
        Shape.cylinder(radius: 10, height: 5)
    }

    /// A planar solid, where the angular deflection changes nothing about the result. The refusal
    /// must still be the value's and not the geometry's.
    private func box() -> Shape? {
        Shape.box(width: 10, height: 5, depth: 3)
    }

    @Test("A NaN angle is refused by every mesh entry point that takes one")
    func nanIsRefused() throws {
        for shape in [try #require(cylinder()), try #require(box())] {
            #expect(shape.mesh(linearDeflection: 0.1, angularDeflection: .nan) == nil)

            var params = MeshParameters.default
            params.angle = .nan
            #expect(shape.mesh(parameters: params) == nil)
        }
    }

    /// The two presentation entry points read their angle from `Prs3d_Drawer::DeviationAngle()`,
    /// which is `myDeviationAngle > 0.0 ? myDeviationAngle : 20 degrees`
    /// (`Prs3d_Drawer.hxx:243-248`). `NaN > 0.0` is false, so the drawer answers 20 degrees and a
    /// NaN never reaches `initParameters`. #2900 named those sites from a reading of
    /// `SetDeviationAngle`; this is the measurement that closed them, and it is here so that a
    /// later change to `DeviationAngle()`'s fallback is a red test rather than a silent hole.
    @Test("A NaN on the drawer is absorbed by OCCT's own accessor, not passed to the mesher")
    func nanOnTheDrawerIsAbsorbedByPrs3dDrawer() throws {
        let shape = try #require(box())

        let nanDrawer = DisplayDrawer()
        nanDrawer.deviationAngle = .nan
        #expect(nanDrawer.deviationAngle == 20.0 * Double.pi / 180.0)

        let defaultDrawer = DisplayDrawer()
        let viaNaN = try #require(shape.shadedMesh(drawer: nanDrawer))
        let viaDefault = try #require(shape.shadedMesh(drawer: defaultDrawer))
        #expect(viaNaN.vertices.count == viaDefault.vertices.count)
        #expect(try #require(shape.edgeMesh(drawer: nanDrawer)).vertices.count
            == #require(shape.edgeMesh(drawer: defaultDrawer)).vertices.count)

        // A positive angle below the floor is not absorbed: it reaches initParameters, which
        // throws, and the bridge's own catch answers nil. No guard of ours is involved.
        let tinyDrawer = DisplayDrawer()
        tinyDrawer.deviationAngle = 9e-13
        #expect(shape.shadedMesh(drawer: tinyDrawer) == nil)
        #expect(shape.edgeMesh(drawer: tinyDrawer) == nil)
    }

    @Test("A NaN angle is refused by meshWithProgress, leaving the shape untriangulated")
    func nanIsRefusedByMeshWithProgress() throws {
        // meshWithProgress returns `self` whether or not it meshed, so the refusal is observable
        // only as the absence of a triangulation on the shape it was asked to mesh.
        let shape = try #require(cylinder())
        _ = try shape.meshWithProgress(linearDeflection: 0.1, angularDeflection: .nan)
        for face in shape.subShapes(ofType: .face) {
            #expect(face.triangulationNodeCount == 0)
        }

        // The same shape at a serviceable angle does mesh, so the refusal is the value's.
        let ok = try #require(cylinder())
        _ = try ok.meshWithProgress(linearDeflection: 0.1, angularDeflection: 0.5)
        #expect(ok.subShapes(ofType: .face).contains { $0.triangulationNodeCount > 0 })
    }

    @Test("Zero, negative and sub-floor angles are refused, as the kernel itself refuses them")
    func zeroNegativeAndSubFloorAreRefused() throws {
        let shape = try #require(cylinder())

        for value in [0.0, -1.0, 9e-13] {
            #expect(shape.mesh(linearDeflection: 0.1, angularDeflection: value) == nil, "\(value)")

            var params = MeshParameters.default
            params.angle = value
            #expect(shape.mesh(parameters: params) == nil, "parameters.angle \(value)")
        }
    }

    @Test("The floor value itself is accepted, so the bound is inclusive")
    func theFloorValueIsAccepted() throws {
        // A box at Precision::Angular(): planar faces, so an angular floor costs nothing. The same
        // request on the cylinder is the expensive one and is deliberately not made here.
        let shape = try #require(box())

        #expect(shape.mesh(linearDeflection: 0.1, angularDeflection: 1e-12) != nil)
    }

    @Test("A NaN angleInterior needs no guard: the bridge's `> 0` test already drops it")
    func nanAngleInteriorIsNotForwarded() throws {
        let shape = try #require(cylinder())

        var params = MeshParameters.default
        params.angle = 0.5
        params.angleInterior = .nan
        let mesh = try #require(shape.mesh(parameters: params))

        // `params.angleInterior > 0` is false for NaN, so IMeshTools_Parameters::AngleInterior is
        // set from `angle` and the result is the mesh `angle` alone describes.
        var control = MeshParameters.default
        control.angle = 0.5
        control.angleInterior = 0
        let expected = try #require(shape.mesh(parameters: control))
        #expect(mesh.vertexCount == expected.vertexCount)
        #expect(mesh.triangleCount == expected.triangleCount)
    }
}
