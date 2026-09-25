import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.113.0 - IntCS Results")
struct IntCSResultsTests {

    /// The fixtures and the result are required rather than `if let`-bound: every assertion sat
    /// under three `if let`s and a count check, so a nil line, sphere or result passed with no
    /// assertion run. IntCS reports two points, (5, 0, 0) then (-5, 0, 0)
    /// (`Scripts/repro/766-intcs-inttools/`), so the count is exactly 2 and the x values are
    /// exact.
    @Test func lineSphereIntersection() throws {
        let line = try #require(Curve3D.line(through: SIMD3(-20, 0, 0), direction: SIMD3(1, 0, 0)))
        let sphere = try #require(Surface.sphere(center: SIMD3(0, 0, 0), radius: 5))
        let intcs = try #require(IntCSResult(curve: line, surface: sphere))
        try #require(intcs.pointCount == 2)
        let p1 = intcs.point(at: 0)
        let p2 = intcs.point(at: 1)
        // one point at x=-5, one at x=5
        let xs = [p1.point.x, p2.point.x].sorted()
        #expect(abs(xs[0] + 5.0) < 1e-9)
        #expect(abs(xs[1] - 5.0) < 1e-9)
    }
}
