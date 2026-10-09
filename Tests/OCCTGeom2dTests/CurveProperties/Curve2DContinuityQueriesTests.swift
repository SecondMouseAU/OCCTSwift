import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve2D Continuity Queries v0.120.0")
struct Curve2DContinuityQueriesTests {

    @Test func segmentContinuityClass() {
        if let c = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(1, 0)) {
            // A trimmed 2D line reports its basis line's continuity, which is analytic.
            #expect(c.continuityClass == .cN)
            #expect(c.continuityClass.satisfies(.c2))
        }
    }

    @Test func isCN() {
        if let c = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(1, 0)) {
            #expect(c.isCN(0))
            #expect(c.isCN(1))
            #expect(c.isCN(2))
        }
    }

    @Test func reversedParameter() {
        if let c = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(1, 0)) {
            let u = 0.5
            let rp = c.reversedParameter(u)
            // Just verify it returns a finite value
            #expect(rp.isFinite)
        }
    }

    @Test func bezierMaxDegree() {
        let md = Curve2D.bezierMaxDegree
        #expect(md >= 25)
    }

    @Test func bsplineMaxDegree() {
        let md = Curve2D.bsplineMaxDegree
        #expect(md >= 25)
    }
}
