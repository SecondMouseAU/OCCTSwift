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
        let curve = Curve3D.hyperbolaThreePoints(
            s1: SIMD3(5, 0, 0),
            s2: SIMD3(0, 3, 0),
            center: SIMD3(0, 0, 0)
        )
        #expect(curve != nil)
        if let c = curve {
            let dom = c.domain
            #expect(dom.upperBound > dom.lowerBound)
        }
    }
}

