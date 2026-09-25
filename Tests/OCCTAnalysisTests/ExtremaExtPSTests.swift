import Foundation
import Testing
import simd

@testable import OCCTSwift

// Expected values are Extrema_ExtPS's own answers for a radius-5 sphere at the origin and the
// point (0, 0, 10), measured by Scripts/repro/766-extrema-extps/probe.mm (transcript.txt beside
// it): two extrema, the near pole at squared distance 25 and the far pole at 225. The sphere is
// `try #require`d rather than built under `if let`, and pointOnSurfaceParams no longer hides
// behind `if result.isDone && result.count >= 1` (#1888, #1889).
@Suite("Extrema_ExtPS Tests")
struct ExtremaExtPSTests {
    @Test func pointSurfaceDistance() throws {
        // Point above sphere
        let sphere = try #require(Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0))
        let result = sphere.extremaPS(point: SIMD3(0, 0, 10))
        #expect(result.isDone)
        #expect(result.count == 2)
        // Find minimum distance
        var minDist = Double.infinity
        for i in 1...max(result.count, 1) {
            let ps = sphere.extremaPSPoint(point: SIMD3(0, 0, 10), index: i)
            let d = ps.squareDistance.squareRoot()
            if d < minDist { minDist = d }
        }
        #expect(abs(minDist - 5.0) < 1e-9)
    }

    @Test func pointOnSurfaceParams() throws {
        let sphere = try #require(Surface.sphere(center: SIMD3(0, 0, 0), radius: 5.0))
        let result = sphere.extremaPS(point: SIMD3(0, 0, 10))
        #expect(result.isDone)
        #expect(result.count == 2)
        let ps = sphere.extremaPSPoint(point: SIMD3(0, 0, 10), index: 1)
        // Extremum 1 is the near pole: on the sphere, at (0, 0, 5), parameters (u 0, v pi/2).
        let r = (ps.point.x * ps.point.x + ps.point.y * ps.point.y + ps.point.z * ps.point.z)
            .squareRoot()
        #expect(abs(r - 5.0) < 1e-9)
        #expect(simd_distance(ps.point, SIMD3(0, 0, 5)) < 1e-9)
        #expect(abs(ps.squareDistance - 25) < 1e-9)
        #expect(abs(ps.v - Double.pi / 2) < 1e-9)
    }
}
