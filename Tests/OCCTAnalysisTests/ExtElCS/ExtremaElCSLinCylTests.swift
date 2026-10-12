import Foundation
import Testing

@testable import OCCTSwift

@Suite("Extrema_ExtElCS Line-Cylinder")
struct ExtremaElCSLinCylTests {
    /// Line against cylinder extrema, pinned to the distances rather than to a count.
    ///
    /// The earlier body asserted `count >= 0`, which an unsigned count cannot fail. A line
    /// parallel to the axis has an equidistant family rather than isolated extrema, and the bridge
    /// answers no extrema for it (`OCCTExtremaElCSLinCylinder` returns early, because OCCT
    /// dereferences a null there). The measurable case is a line along +y through (20, 0, 0)
    /// against a radius 5 cylinder on the z axis: a nearest extremum at (5, 0, 0), 15 away, and
    /// a farthest at (-5, 0, 0), 25 away.
    @Test func lineCylinderDistance() throws {
        let results = ExtremaElCS.lineToCylinder(
            linePoint: SIMD3(20, 0, 0), lineDir: SIMD3(0, 1, 0),
            cylCenter: SIMD3(0, 0, 0), cylAxis: SIMD3(0, 0, 1), cylRadius: 5
        )
        try #require(results.count == 2)
        let sorted = results.sorted { $0.squareDistance < $1.squareDistance }
        #expect(abs(sorted[0].squareDistance - 225.0) < 1e-9)
        #expect(abs(sorted[1].squareDistance - 625.0) < 1e-9)
        let near1 = try #require(sorted[0].point1)
        let near2 = try #require(sorted[0].point2)
        #expect(abs(near1.x - 20) < 1e-9 && abs(near1.y) < 1e-9 && abs(near1.z) < 1e-9)
        #expect(abs(near2.x - 5) < 1e-9 && abs(near2.y) < 1e-9 && abs(near2.z) < 1e-9)
        let far2 = try #require(sorted[1].point2)
        #expect(abs(far2.x + 5) < 1e-9 && abs(far2.y) < 1e-9)

        // Parallel to the axis: no isolated extremum is reported.
        let parallel = ExtremaElCS.lineToCylinder(
            linePoint: SIMD3(20, 0, 0), lineDir: SIMD3(0, 0, 1),
            cylCenter: SIMD3(0, 0, 0), cylAxis: SIMD3(0, 0, 1), cylRadius: 5)
        #expect(parallel.isEmpty)
    }
}
