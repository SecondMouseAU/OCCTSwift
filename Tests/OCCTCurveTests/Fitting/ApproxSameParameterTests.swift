import Foundation
import Testing

@testable import OCCTSwift

@Suite("Approx SameParameter Tests")
struct ApproxSameParameterTests {
    @Test("same parameter on line/plane")
    func sameParamLinePlane() throws {
        // Bounded segments, not the infinite `line(through:)` this test used to build:
        // `Approx_SameParameter` samples over the curve's own first and last parameter, which for
        // a `Geom_Line` is +-2e100, and it then reports `isSameParameter == true` with a reached
        // tolerance of 1.5e50, for a 2D line of twice the speed as well. Nothing was read.
        let line3d = try #require(Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)))
        let line2d = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0)))
        let plane = try #require(Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)))

        // The plane's (u, v) is (x, y), so the 2D segment along u is the 3D segment along x at
        // unit speed: same parameter, reached at the confusion floor.
        let r = try #require(line3d.checkSameParameter(curve2D: line2d, surface: plane))
        #expect(r.isSameParameter)
        #expect(r.toleranceReached <= 1e-6, "got \(r.toleranceReached)")

        // Controls. A 2D segment covering half the 3D one's length runs at half the speed, so
        // the pair is computed and is not the same parameter.
        let half = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(5, 0)))
        let slow = try #require(line3d.checkSameParameter(curve2D: half, surface: plane))
        #expect(!slow.isSameParameter)

        // A 2D segment along v does not lie on the 3D curve at all, so there is no result.
        let along = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(0, 10)))
        #expect(line3d.checkSameParameter(curve2D: along, surface: plane) == nil)
    }
}
