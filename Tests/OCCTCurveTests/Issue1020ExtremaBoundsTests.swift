import Testing

@testable import OCCTSwift

// #1020: ExtremaPointCurve.pointToLine and .pointToParabola passed Extrema_ExtPElC a fabricated
// parameter range, -1e10 to 1e10 for the line and -1e6 to 1e6 for the parabola, four orders of
// magnitude apart with nothing saying why. Both curves are unbounded and Extrema_ExtPElC uses
// Uinf/Usup only to range-check an answer it has already computed, so the bound is a post-filter
// that could discard a correct result. Both now use the full representable range.
@Suite("Unbounded elementary curves are not parameter-clipped (#1020)")
struct Issue1020ExtremaBoundsTests {

    // The foot of the perpendicular sits at parameter 2e10 along the line, past the old 1e10
    // bound, so Extrema_ExtPElC reported not-done and the bridge returned an empty array.
    @Test("A point projecting beyond the old line bound still has an extremum")
    func pointToLineBeyondOldBound() {
        let results = ExtremaPointCurve.pointToLine(
            point: SIMD3(2e10, 3, 0),
            lineOrigin: SIMD3(0, 0, 0), lineDir: SIMD3(1, 0, 0))
        #expect(results.count == 1)
        if let r = results.first {
            #expect(abs(r.squareDistance - 9.0) < 1e-3)
            #expect(abs(r.point2.x - 2e10) < 1.0)
        }
    }

    // The same query inside the old bound, so a change that broke the ordinary case would not
    // pass this suite.
    @Test("A point projecting inside the old line bound is unchanged")
    func pointToLineInsideOldBound() {
        let results = ExtremaPointCurve.pointToLine(
            point: SIMD3(7, 4, 0),
            lineOrigin: SIMD3(0, 0, 0), lineDir: SIMD3(1, 0, 0))
        #expect(results.count == 1)
        if let r = results.first {
            #expect(abs(r.squareDistance - 16.0) < 1e-9)
            #expect(abs(r.point2.x - 7.0) < 1e-9)
        }
    }

    // Extrema_ExtPElC solves (1/4F)U^3 + (2F - X)U - 2FY = 0 for the parabola and keeps only the
    // roots inside [Uinf, Usup]. With F = 1e6 and the point 1e7 along the parabola's Y axis, the
    // cubic term dominates and the real root lands at 3.69e6 (probed; this comment said 4.3e6),
    // past the old 1e6 bound, where Extrema_ExtPElC reports done with no extremum.
    @Test("A parabola root beyond the old bound is not discarded")
    func pointToParabolaBeyondOldBound() {
        let results = ExtremaPointCurve.pointToParabola(
            point: SIMD3(0, 1e7, 0),
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), xDir: SIMD3(1, 0, 0),
            focal: 1e6)
        // #766: pinned to the kernel's single extremum (Scripts/repro/766-curve-integration-
        // extrema-law), rather than "some root past 1e6".
        #expect(results.count == 1)
        if let r = results.first {
            #expect(abs(r.point2.y - 3694838.0756654656) < 1e-3, "foot y \(r.point2.y)")
            #expect(abs(r.point2.x - 3412957.1013468201) < 1e-3, "foot x \(r.point2.x)")
            #expect(abs(r.squareDistance - 51403343067711.656) / 51403343067711.656 < 1e-9)
        }
    }

    // An ordinary parabola query well inside the old bound.
    @Test("A parabola root inside the old bound is unchanged")
    func pointToParabolaInsideOldBound() {
        let results = ExtremaPointCurve.pointToParabola(
            point: SIMD3(10, 0, 0),
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), xDir: SIMD3(1, 0, 0),
            focal: 2)
        // #766: "not empty" passed on any answer. The kernel finds three: the two symmetric feet at
        // (6, +-4sqrt(3)) at distance 8, and the vertex at distance 10.
        #expect(results.count == 3)
        let sq = results.map(\.squareDistance).sorted()
        if sq.count == 3 {
            #expect(abs(sq[0] - 64) < 1e-9 && abs(sq[1] - 64) < 1e-9 && abs(sq[2] - 100) < 1e-9)
        }
        let feet = results.map(\.point2)
        #expect(feet.contains { abs($0.x - 6) < 1e-9 && abs($0.y - 48.0.squareRoot()) < 1e-9 })
        #expect(feet.contains { abs($0.x - 6) < 1e-9 && abs($0.y + 48.0.squareRoot()) < 1e-9 })
        #expect(feet.contains { abs($0.x) < 1e-9 && abs($0.y) < 1e-9 })
    }
}
