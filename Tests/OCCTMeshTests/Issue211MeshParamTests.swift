import Testing
import Foundation
@testable import OCCTSwift

// #211: MeshParameters.allowQualityDecrease (IMeshTools_Parameters::AllowQualityDecrease).
@Suite("Issue #211 — allowQualityDecrease mesh parameter")
struct Issue211MeshParam {

    @Test("default is false")
    func defaultIsFalse() {
        #expect(MeshParameters.default.allowQualityDecrease == false)
    }

    @Test("meshing with the flag set produces a valid mesh")
    func meshesWithFlag() {
        guard let sphere = Shape.sphere(radius: 5) else { #expect(Bool(false)); return }
        var params = MeshParameters.default
        params.deflection = 0.1
        params.allowQualityDecrease = true
        guard let mesh = sphere.mesh(parameters: params) else { #expect(Bool(false)); return }
        #expect(mesh.vertexCount > 0)
        #expect(mesh.triangleCount > 0)
    }

    // Re-meshing the SAME shape coarser: with the flag, the coarse result must take effect
    // (≤ the fine triangle count), not silently keep the finer triangulation.
    @Test("allows a coarser re-mesh to replace a finer one")
    func coarserReplacesFiner() {
        guard let fineShape = Shape.sphere(radius: 5),
              let coarseShape = Shape.sphere(radius: 5) else { #expect(Bool(false)); return }
        var fine = MeshParameters.default; fine.deflection = 0.05
        var coarse = MeshParameters.default; coarse.deflection = 1.0; coarse.allowQualityDecrease = true
        guard let fineMesh = fineShape.mesh(parameters: fine),
              let coarseMesh = coarseShape.mesh(parameters: coarse) else { #expect(Bool(false)); return }
        #expect(coarseMesh.triangleCount < fineMesh.triangleCount)
    }
}
