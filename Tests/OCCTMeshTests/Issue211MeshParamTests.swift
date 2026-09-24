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
    func meshesWithFlag() {
        guard let sphere = Shape.sphere(radius: 5) else {
            #expect(Bool(false))
            return
        }
        var params = MeshParameters.default
        params.deflection = 0.1
        params.allowQualityDecrease = true
        guard let mesh = sphere.mesh(parameters: params) else {
            #expect(Bool(false))
            return
        }
        #expect(mesh.vertexCount > 0)
        #expect(mesh.triangleCount > 0)
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
        #expect(fineA.triangleCount == 976)
        #expect(coarseA.triangleCount == 306)

        // Control: the same re-mesh without the flag keeps the finer triangulation.
        let fineB = try #require(withoutFlag.mesh(parameters: fine))
        let coarseB = try #require(withoutFlag.mesh(parameters: coarse))
        #expect(fineB.triangleCount == 976)
        #expect(coarseB.triangleCount == 976)
    }
}
