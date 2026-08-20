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
    // cubic term dominates and the real root lands near 4.3e6, past the old 1e6 bound.
    @Test("A parabola root beyond the old bound is not discarded")
    func pointToParabolaBeyondOldBound() {
        let results = ExtremaPointCurve.pointToParabola(
            point: SIMD3(0, 1e7, 0),
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), xDir: SIMD3(1, 0, 0),
            focal: 1e6)
        #expect(!results.isEmpty)
        if let r = results.first {
            #expect(abs(r.point2.y) > 1e6)
            #expect(r.squareDistance.isFinite)
        }
    }

    // An ordinary parabola query well inside the old bound.
    @Test("A parabola root inside the old bound is unchanged")
    func pointToParabolaInsideOldBound() {
        let results = ExtremaPointCurve.pointToParabola(
            point: SIMD3(10, 0, 0),
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), xDir: SIMD3(1, 0, 0),
            focal: 2)
        #expect(!results.isEmpty)
    }
}
