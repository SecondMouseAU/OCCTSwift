import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GC_MakeHyperbola, 3 Points")
struct HyperbolaThreePointsTests {
    @Test("Create hyperbola through three points")
    func hyperbolaFromThreePoints() throws {
        // S1 sets the major axis/radius (Center→S1); S2's distance off that axis sets the minor
        // radius. S2 must be OFF the major axis. OCCT 8.0.0p1 rejects a zero minor radius (a
        // collinear S2, as the old test used, is a degenerate hyperbola).
        let c = try #require(
            Curve3D.hyperbolaThreePoints(
                s1: SIMD3(5, 0, 0),
                s2: SIMD3(0, 3, 0),
                center: SIMD3(0, 0, 0)
            ))
        let dom = c.domain
        #expect(dom.upperBound > dom.lowerBound)
        // #766: the domain check alone passed for any hyperbola, including one with S1 and S2
        // exchanged. Pin the curve itself: P(u) = C + 5 cosh(u) X + 3 sinh(u) Y, so the vertex
        // is (5, 0, 0) and P(1) = (5 cosh 1, 3 sinh 1, 0), as GC_MakeHyperbola reports
        // (Scripts/repro/766-math-gtrsf-hyperbola-precision/transcript.txt).
        #expect(simd_length(c.point(at: 0) - SIMD3(5, 0, 0)) < 1e-9)
        #expect(simd_length(c.point(at: 1) - SIMD3(5 * cosh(1.0), 3 * sinh(1.0), 0)) < 1e-9)
    }
}
