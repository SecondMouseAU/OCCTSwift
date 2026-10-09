import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1979: two nested `if let`s, and only `upperBound > lowerBound`, which any curve satisfies. Now
// pinned to what ProjLib_ProjectOnSurface returns (Scripts/repro/766-geom2d-projlib-wire-tbezier/):
// a B-spline on [0, 10] that starts on the cylinder at (4.0825, 2.8868, 3.5355).
//
// Not asserted, and reported on #1979: the kernel's B-spline does not stay on the cylinder. Its
// start is the projection of the line's point at t = 5, not t = 0, and from u = 5 onward it
// evaluates to (0, 0, 0), radius 0. The bridge passes that curve through unchanged.
@Suite("ProjLib_ProjectOnSurface Tests")
struct ProjLibProjectOnSurfaceTests {
    @Test func projectLineOnCylinder() throws {
        let line = try #require(Curve3D.line(through: SIMD3(5, 0, 0), direction: SIMD3(0, 1, 1)))
        let cyl = try #require(Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5.0))
        let projected = try #require(line.projectOnSurface(cyl, range: 0...10))
        let domain = projected.domain
        #expect(abs(domain.lowerBound) < 1e-12 && abs(domain.upperBound - 10) < 1e-12)
        let start = projected.point(at: domain.lowerBound)
        #expect(simd_distance(start, SIMD3(4.08248290464, 2.88675134595, 3.53553390593)) < 1e-9)
        #expect(abs(simd_length(SIMD2(start.x, start.y)) - 5) < 1e-9)
    }
}
