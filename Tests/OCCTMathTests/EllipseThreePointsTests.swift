import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GC_MakeEllipse, 3 Points")
struct EllipseThreePointsTests {
    @Test("Create ellipse through three points")
    func ellipseFromThreePoints() throws {
        // S1 and S2 are points on ellipse, center is the center
        let curve = Curve3D.ellipseThreePoints(
            s1: SIMD3(10, 0, 0),
            s2: SIMD3(0, 5, 0),
            center: SIMD3(0, 0, 0)
        )
        #expect(curve != nil)
        if let c = curve {
            let dom = c.domain
            #expect(dom.upperBound > dom.lowerBound)
        }
    }
}

