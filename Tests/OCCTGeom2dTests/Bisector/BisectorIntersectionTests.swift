import Foundation
import Testing

@testable import OCCTSwift

// #1979: both tests used to discard the result (`let _ = results`) and so could not fail. They
// now pin what Bisector_Inter reports (Scripts/repro/766-geom2d-batch-bisector/). Each bisector is
// a half-line from the pair's midpoint along the pair's direction rotated +90 degrees, so the
// order of each pair decides which way its half-line runs.
@Suite("Bisector Intersection Tests")
struct BisectorIntersectionTests {
    @Test("perpendicular bisectors of right angle")
    func perpendicularBisectors() throws {
        // Bisector of (0,0)-(10,0): x = 5 running +y. Bisector of (0,10)-(0,0): y = 5 running +x.
        // They meet at (5, 5), the circumcentre of the right triangle, 5 along each half-line.
        let results = bisectorIntersections(
            a: (0, 0), b: (10, 0),
            c: (0, 10), d: (0, 0))
        try #require(results.count == 1)
        #expect(abs(results[0].x - 5) < 1e-9)
        #expect(abs(results[0].y - 5) < 1e-9)
        #expect(abs(results[0].paramOnFirst - 5) < 1e-9)
        #expect(abs(results[0].paramOnSecond - 5) < 1e-9)
    }

    @Test("collinear point bisectors")
    func collinearBisectors() {
        // Bisector of (0,0)-(4,0): x = 2 running +y. Bisector of (0,0)-(0,4): y = 2 running -x.
        // The half-lines diverge, so there is no crossing, although the full lines meet at (2, 2).
        let results = bisectorIntersections(
            a: (0, 0), b: (4, 0),
            c: (0, 0), d: (0, 4))
        #expect(results.isEmpty)

        // The control: the same two pairs with the second one reversed run +x instead of -x, so
        // the half-lines now cross at (2, 2), 2 along each. Without it an
        // `bisectorIntersections` that always answered nothing passes the diverging case.
        let crossing = bisectorIntersections(
            a: (0, 0), b: (4, 0),
            c: (0, 4), d: (0, 0))
        #expect(crossing.count == 1)
        if let hit = crossing.first {
            #expect(abs(hit.x - 2) < 1e-9)
            #expect(abs(hit.y - 2) < 1e-9)
            #expect(abs(hit.paramOnFirst - 2) < 1e-9)
            #expect(abs(hit.paramOnSecond - 2) < 1e-9)
        }
    }
}
