import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: both tests asserted only `line != nil`, which a line anywhere satisfies. Pinned to what
// GC_MakeLine2d gives (Scripts/repro/766-geom2d-tangents-islinear-line/).
@Suite("GC_MakeLine2d")
struct Curve2DLineTests {
    @Test("Create 2D line through two points")
    func lineThroughPoints() throws {
        let line = try #require(Curve2D.lineThroughPoints(SIMD2(0, 0), SIMD2(10, 10)))
        // Location (0, 0), direction (1, 1)/sqrt 2: u = sqrt 200 reaches (10, 10).
        #expect(simd_distance(line.point(at: 0), SIMD2(0, 0)) < 1e-12)
        #expect(simd_distance(line.point(at: 200.0.squareRoot()), SIMD2(10, 10)) < 1e-9)
    }

    @Test("Create 2D line parallel to direction at distance")
    func lineParallel() throws {
        // GC_MakeLine2d(lin, 5) offsets to the left of +x: the line y = 5 from (0, 5).
        let line = try #require(
            Curve2D.lineParallel(point: SIMD2(0, 0), direction: SIMD2(1, 0), distance: 5.0))
        #expect(simd_distance(line.point(at: 0), SIMD2(0, 5)) < 1e-12)
        #expect(simd_distance(line.point(at: 3), SIMD2(3, 5)) < 1e-12)
    }
}
