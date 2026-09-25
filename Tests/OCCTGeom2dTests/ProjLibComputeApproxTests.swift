import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.64.0 Tests

// #1979: every fixture failure returned silently, and the test returned at the first edge that
// projected, so it passed if none did. All three edges of the cylinder project onto its lateral
// face (measured); the seam line keeps its x = 10, z in [0, 20] extent.
@Suite("ProjLib ComputeApprox")
struct ProjLibComputeApproxTests {
    @Test("Project edge onto cylinder face")
    func projectOnCylinder() throws {
        let cyl = try #require(Shape.cylinder(radius: 10, height: 20))
        let cylFaces = cyl.subShapes(ofType: .face)
        let cylEdges = cyl.subShapes(ofType: .edge)
        try #require(cylFaces.count == 3 && cylEdges.count == 3)
        var seamSeen = false
        for edge in cylEdges {
            let result = try #require(edge.projectOntoSurface(cylFaces[0]))
            #expect(result.shapeType == .edge)
            let b = try #require(result.bounds)
            if b.max.z - b.min.z > 19 {
                seamSeen = true
                #expect(abs(b.min.x - 10) < 1e-6 && abs(b.max.x - 10) < 1e-6)
                #expect(abs(b.min.z) < 1e-6 && abs(b.max.z - 20) < 1e-6)
            }
        }
        #expect(seamSeen)
    }
}
