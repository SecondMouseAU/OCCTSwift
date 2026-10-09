import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtElCS Line-Plane")
struct ExtremaElCSLinPlaneTests {
    /// A line parallel to the plane is everywhere 10 from it, and has no nearest pair.
    ///
    /// OCCT computes none either: `Extrema_ExtElCS.cxx:62-68` allocates the distance array alone
    /// and leaves `myPoint1` / `myPoint2` as **null handles** while `NbExt()` returns 1, so
    /// reading a point there is an uncatchable SIGSEGV rather than a wrong value. The bridge
    /// returns before the loop; until #2993 it filled the result with zeros, and the Swift
    /// surface reported them as points. Measured in
    /// `Scripts/repro/2993-extremaelc-parallel-witnesses/`.
    @Test func parallelLinePlane() throws {
        let r = ExtremaElCS.lineToPlane(
            linePoint: SIMD3(0, 0, 10), lineDir: SIMD3(1, 0, 0),
            planePoint: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1)
        )
        #expect(r.isParallel)
        #expect(r.results.count == 1)
        let first = try #require(r.results.first)
        #expect(abs(first.squareDistance - 100) < 1e-9)
        #expect(first.isParallel, "the tuple flag and the result's own flag are the same fact")
        #expect(first.point1 == nil, "point1 is \(String(describing: first.point1))")
        #expect(first.point2 == nil, "point2 is \(String(describing: first.point2))")
    }

    @Test func intersectingLinePlane() {
        let r = ExtremaElCS.lineToPlane(
            linePoint: SIMD3(0, 0, 10), lineDir: SIMD3(0, 0, -1),
            planePoint: SIMD3(0, 0, 0), planeNormal: SIMD3(0, 0, 1)
        )
        // Not parallel since line goes through the plane
        #expect(!r.isParallel)
    }
}
