import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: the three segment tests nested their assertions in `if let c`, so a nil segment passed;
// `reversedParameter` asserted only `rp.isFinite`, and both MaxDegree tests `>= 25`. Values from
// Geom2d_TrimmedCurve and the two MaxDegree() statics (Scripts/repro/766-geom2d-continuity-convert/).
@Suite("Curve2D Continuity Queries v0.120.0")
struct Curve2DContinuityQueriesTests {
    @Test func segmentContinuityClass() throws {
        let c = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(1, 0)))
        // A trimmed 2D line reports its basis line's continuity, which is analytic.
        #expect(c.continuityClass == .cN)
        #expect(c.continuityClass.satisfies(.c2))
    }

    @Test func isCN() throws {
        let c = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(1, 0)))
        #expect(c.isCN(0))
        #expect(c.isCN(1))
        #expect(c.isCN(2))
    }

    @Test func reversedParameter() throws {
        let c = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(1, 0)))
        // Geom2d_TrimmedCurve::ReversedParameter delegates to the basis line, whose reversal is
        // u -> -u; it is not First + Last - u. So 0.2 maps to -0.2, not 0.8.
        #expect(abs(c.reversedParameter(0.2) + 0.2) < 1e-15)
        #expect(abs(c.reversedParameter(0.5) + 0.5) < 1e-15)
    }

    @Test func bezierMaxDegree() {
        #expect(Curve2D.bezierMaxDegree == 25)
    }

    @Test func bsplineMaxDegree() {
        #expect(Curve2D.bsplineMaxDegree == 25)
    }
}
