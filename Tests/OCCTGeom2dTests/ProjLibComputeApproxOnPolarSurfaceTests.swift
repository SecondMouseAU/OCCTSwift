import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: "may or may not succeed", so nothing was asserted when it did not. It does succeed
// (measured): the half circle of radius 10 at z = 5 lands on the radius-15 sphere along the rays
// from the centre, at radius 15 * 10 / sqrt(125) = 13.416 and height 15 * 5 / sqrt(125) = 6.708.
@Suite("ProjLib ComputeApproxOnPolarSurface")
struct ProjLibComputeApproxOnPolarSurfaceTests {
    @Test("Project edge onto sphere face")
    func projectOnSphere() throws {
        let sph = try #require(Shape.sphere(radius: 15))
        let edge = try #require(
            Shape.edgeFromCircle(
                center: SIMD3(0, 0, 5), axis: SIMD3(0, 0, 1), radius: 10, p1: 0, p2: .pi))
        let faces = sph.subShapes(ofType: .face)
        try #require(!faces.isEmpty)
        let result = try #require(edge.projectOntoPolarSurface(faces[0]))
        #expect(result.shapeType == .edge)
        let b = try #require(result.bounds)
        let r = 150 / 125.0.squareRoot()
        let h = 75 / 125.0.squareRoot()
        #expect(abs(b.max.x - r) < 0.05 && abs(b.min.x + r) < 0.05)
        #expect(b.min.z > h - 0.05 && b.max.z < h + 0.05)
    }
}
