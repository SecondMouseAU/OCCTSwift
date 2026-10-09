import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.64.0 Tests

@Suite("ProjLib ComputeApprox")
struct ProjLibComputeApproxTests {
    @Test("Project edge onto cylinder face")
    func projectOnCylinder() {
        guard let cyl = Shape.cylinder(radius: 10, height: 20) else { return }
        let cylFaces = cyl.subShapes(ofType: .face)
        let cylEdges = cyl.subShapes(ofType: .edge)
        guard !cylFaces.isEmpty, !cylEdges.isEmpty else { return }
        // Try projecting each edge onto the cylindrical face
        for edge in cylEdges {
            if let result = edge.projectOntoSurface(cylFaces[0]) {
                #expect(result.shapeType == .edge)
                return
            }
        }
    }
}
