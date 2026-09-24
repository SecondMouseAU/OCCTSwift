import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepExtrema_Poly")
struct PolyhedralDistanceTests {
    /// Polyhedral distance between two meshed spheres, bounded by the deflection.
    ///
    /// Two r = 5 spheres 20 apart, each meshed at a linear deflection of 0.1. The exact gap is
    /// 10. `BRepExtrema_Poly` measures between the triangulations, and a mesh lies inside its
    /// sphere by at most the deflection, so the polyhedral distance is at least 10 and at most
    /// 10 + 2 x 0.1. The kernel returns 10.123940560713 for this input
    /// (Scripts/repro/766-polyhedral-distance-tests/transcript.txt). The version of this test
    /// before #1882 accepted anything in 8...12, which a distance off by 1.9 in either direction
    /// passed.
    @Test("Polyhedral distance between two shapes")
    func polyDist() throws {
        let s1 = try #require(Shape.sphere(radius: 5.0))
        _ = s1.mesh(linearDeflection: 0.1)
        let s2 = try #require(Shape.sphere(radius: 5.0)?.translated(by: SIMD3(20, 0, 0)))
        _ = s2.mesh(linearDeflection: 0.1)
        let result = try #require(s1.polyhedralDistance(to: s2))
        #expect(
            result.distance >= 10.0,
            "a mesh inscribed in each sphere cannot be closer than 10, got \(result.distance)")
        #expect(
            result.distance <= 10.2, "each mesh is within 0.1 of its sphere, got \(result.distance)"
        )

        // The closest points are mesh points of each sphere: within the deflection of radius 5
        // from their own centre, and 'distance' apart.
        let r1 = simd_length(result.point1)
        let r2 = simd_distance(result.point2, SIMD3(20, 0, 0))
        #expect(r1 <= 5 + 1e-9 && r1 >= 4.9, "point1 lies on sphere 1's mesh, radius \(r1)")
        #expect(r2 <= 5 + 1e-9 && r2 >= 4.9, "point2 lies on sphere 2's mesh, radius \(r2)")
        #expect(abs(simd_distance(result.point1, result.point2) - result.distance) < 1e-9)
    }

    /// Without triangulation `BRepExtrema_Poly::Distance` returns false, and the wrapper nil.
    @Test("Polyhedral distance needs a mesh")
    func polyDistUnmeshed() {
        guard let s1 = Shape.sphere(radius: 5.0),
            let s2 = Shape.sphere(radius: 5.0)?.translated(by: SIMD3(20, 0, 0))
        else {
            Issue.record("fixture construction failed")
            return
        }
        #expect(s1.polyhedralDistance(to: s2) == nil)
    }
}
