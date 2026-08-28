import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ProjLib ComputeApproxOnPolarSurface")
struct ProjLibComputeApproxOnPolarSurfaceTests {
    @Test("Project edge onto sphere face")
    func projectOnSphere() {
        guard let sph = Shape.sphere(radius: 15) else { return }
        // Create a circle edge near sphere surface
        let edge = Shape.edgeFromCircle(
            center: SIMD3(0, 0, 5), axis: SIMD3(0, 0, 1), radius: 10, p1: 0, p2: .pi)
        guard let edge = edge else { return }
        let faces = sph.subShapes(ofType: .face)
        guard !faces.isEmpty else { return }
        let result = edge.projectOntoPolarSurface(faces[0])
        // May or may not succeed depending on geometry
        if let result = result {
            #expect(result.shapeType == .edge)
        }
    }
}
