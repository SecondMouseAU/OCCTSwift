import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.113.0 - IntCS Results")
struct IntCSResultsTests {

    @Test func lineSphereIntersection() {
        if let line = Curve3D.line(through: SIMD3(-20, 0, 0), direction: SIMD3(1, 0, 0)),
            let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5)
        {
            if let intcs = IntCSResult(curve: line, surface: sphere) {
                #expect(intcs.pointCount >= 2)
                if intcs.pointCount >= 2 {
                    let p1 = intcs.point(at: 0)
                    let p2 = intcs.point(at: 1)
                    // one point at x=-5, one at x=5
                    let xs = [p1.point.x, p2.point.x].sorted()
                    #expect(abs(xs[0] + 5.0) < 0.1)
                    #expect(abs(xs[1] - 5.0) < 0.1)
                }
            }
        }
    }
}
