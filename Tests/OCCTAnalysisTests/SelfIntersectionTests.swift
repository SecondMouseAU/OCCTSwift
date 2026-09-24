import Foundation
import Testing
import simd

@testable import OCCTSwift

/// Each self-intersection check here asserts the overlap count the kernel reports.
///
/// The three primitive tests used to assert only that the check ran (`isDone`, which
/// `selfIntersection()` makes true by construction whenever it returns a result), so a check
/// reporting overlaps on a clean sphere passed them. Each now asserts the overlap count the kernel
/// reports, 0 in every case (`Scripts/repro/766-self-intersection/`), and the results are required
/// rather than force-unwrapped inside `#expect` (#1733 to #1736).
///
/// A count of 0 is also what a check that never looks would report, so the suite carries a
/// positive control: two overlapping boxes in one compound, where the kernel finds 6 overlapping
/// triangle pairs.
@Suite("Self-Intersection Tests")
struct SelfIntersectionTests {
    @Test("Box has no self-intersection")
    func boxNoSelfIntersection() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let result = try #require(box.selfIntersection())
        #expect(result.isDone)
        #expect(result.overlapCount == 0)
    }

    @Test("Sphere has no self-intersection")
    func sphereNoSelfIntersection() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        let result = try #require(sphere.selfIntersection())
        #expect(result.isDone)
        #expect(result.overlapCount == 0)
    }

    @Test("Cylinder has no self-intersection")
    func cylinderNoSelfIntersection() throws {
        let cyl = try #require(Shape.cylinder(radius: 3, height: 10))
        let result = try #require(cyl.selfIntersection())
        #expect(result.isDone)
        #expect(result.overlapCount == 0)
    }

    @Test("Custom tolerance and mesh deflection")
    func customParameters() throws {
        let box = try #require(Shape.box(width: 5, height: 5, depth: 5))
        let result = try #require(box.selfIntersection(tolerance: 0.01, meshDeflection: 0.1))
        #expect(result.isDone)
        #expect(result.overlapCount == 0)
    }

    @Test("Overlapping boxes in one compound report their overlaps")
    func overlappingCompoundReportsOverlaps() throws {
        let a = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let b = try #require(
            Shape.box(width: 10, height: 10, depth: 10)?.translated(by: SIMD3(5, 5, 5)))
        let pair = try #require(Shape.compound([a, b]))
        let result = try #require(pair.selfIntersection())
        #expect(result.overlapCount == 6)
    }
}
