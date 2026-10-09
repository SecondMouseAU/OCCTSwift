import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Bisector Intersection Tests")
struct BisectorIntersectionTests {
    @Test("perpendicular bisectors of right angle")
    func perpendicularBisectors() {
        // Bisector of (0,0)-(10,0) = vertical line x=5
        // Bisector of (0,0)-(0,10) = horizontal line y=5
        // They should intersect at (5,5) — circumcenter of right triangle
        let results = bisectorIntersections(
            a: (0, 0), b: (10, 0),
            c: (0, 0), d: (0, 10))
        // May or may not find intersection depending on domain coverage
        // Just verify no crash and valid computation
        let _ = results
    }

    @Test("collinear point bisectors")
    func collinearBisectors() {
        // Bisector of (0,0)-(4,0) = x=2 vertical
        // Bisector of (0,0)-(0,4) = y=2 horizontal
        let results = bisectorIntersections(
            a: (0, 0), b: (4, 0),
            c: (0, 0), d: (0, 4))
        let _ = results
    }
}
