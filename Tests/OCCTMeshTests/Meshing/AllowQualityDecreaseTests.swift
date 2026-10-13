import Foundation
import Testing

@testable import OCCTSwift

// #211: MeshParameters.allowQualityDecrease (IMeshTools_Parameters::AllowQualityDecrease).
@Suite("Issue #211, allowQualityDecrease mesh parameter")
struct Issue211MeshParam {

    @Test("default is false")
    func defaultIsFalse() {
        #expect(MeshParameters.default.allowQualityDecrease == false)
    }

    @Test("meshing with the flag set produces a valid mesh")
    func meshesWithFlag() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        var params = MeshParameters.default
        params.deflection = 0.1
        params.allowQualityDecrease = true
        let mesh = try #require(sphere.mesh(parameters: params))
        #expect(mesh.vertexCount > 0)
        #expect(mesh.triangleCount > 0)

        // "Valid" is a claim about the surface: every node of the radius 5 sphere lies on it
        // (the shape is exact there, the deflection only chords between nodes).
        for v in mesh.vertices {
            let r = Double(v.x * v.x + v.y * v.y + v.z * v.z).squareRoot()
            #expect(abs(r - 5) < 1e-4, "node \(v) is \(r) from the centre")
        }

        // The flag is about a re-mesh replacing a finer one, so on a first mesh it changes
        // nothing: the same sphere without it gives the same node and triangle counts.
        let plain = try #require(Shape.sphere(radius: 5))
        var control = MeshParameters.default
        control.deflection = 0.1
        let expected = try #require(plain.mesh(parameters: control))
        #expect(mesh.vertexCount == expected.vertexCount)
        #expect(mesh.triangleCount == expected.triangleCount)
    }

    // Re-meshing the SAME shape coarser: with the flag, the coarse result must take effect, and
    // without it the finer triangulation is kept. The previous version of this test meshed two
    // separate fresh spheres, so the flag played no part and a bridge that dropped it still
    // passed. Counts are what BRepMesh_IncrementalMesh gives the same inputs
    // (Scripts/repro/766-mesh-issue211/transcript.txt).
    @Test("allows a coarser re-mesh to replace a finer one")
    func coarserReplacesFiner() throws {
        let withFlag = try #require(Shape.sphere(radius: 5))
        let withoutFlag = try #require(Shape.sphere(radius: 5))
        var fine = MeshParameters.default
        fine.deflection = 0.05
        var coarse = MeshParameters.default
        coarse.deflection = 1.0
        var coarseAllowed = coarse
        coarseAllowed.allowQualityDecrease = true

        let fineA = try #require(withFlag.mesh(parameters: fine))
        let coarseA = try #require(withFlag.mesh(parameters: coarseAllowed))
        // Within 1 percent and not exact: the wasm build's libm meshes the fine sphere to 978.
        #expect(abs(fineA.triangleCount - 976) <= 10, "fine \(fineA.triangleCount), expected ~976")
        #expect(
            abs(coarseA.triangleCount - 306) <= 3, "coarse \(coarseA.triangleCount), expected ~306")

        // Control: the same re-mesh without the flag keeps the finer triangulation.
        let fineB = try #require(withoutFlag.mesh(parameters: fine))
        let coarseB = try #require(withoutFlag.mesh(parameters: coarse))
        #expect(abs(fineB.triangleCount - 976) <= 10)
        #expect(
            coarseB.triangleCount == fineB.triangleCount, "without the flag the finer mesh stays")
    }
}
