import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtElC Line-Circle")
struct ExtremaElCLinCircTests {
    @Test func lineCircleDistance() {
        let results = ExtremaElC.lineToCircle(
            linePoint: SIMD3(0, 0, 10), lineDir: SIMD3(1, 0, 0),
            circleCenter: SIMD3(0, 0, 0), circleNormal: SIMD3(0, 0, 1), radius: 5
        )
        #expect(results.count > 0)
    }

    @Test func lineCircleCoplanar() {
        let results = ExtremaElC.lineToCircle(
            linePoint: SIMD3(10, 0, 0), lineDir: SIMD3(0, 1, 0),
            circleCenter: SIMD3(0, 0, 0), circleNormal: SIMD3(0, 0, 1), radius: 5
        )
        #expect(results.count > 0)
        if let first = results.first {
            #expect(abs(first.squareDistance - 25) < 1)
        }
    }

    /// A line coincident with the circle's own axis (#1501): `Extrema_ExtElC` reports
    /// `IsParallel()`, a degenerate case with a well-defined constant distance (the circle's own
    /// radius), which the bridge used to discard and return an empty array for.
    @Test func lineOnCircleAxisReturnsRadius() {
        let results = ExtremaElC.lineToCircle(
            linePoint: SIMD3(0, 0, 10), lineDir: SIMD3(0, 0, 1),
            circleCenter: SIMD3(0, 0, 0), circleNormal: SIMD3(0, 0, 1), radius: 5
        )
        #expect(results.count == 1)
        if let first = results.first {
            #expect(abs(first.squareDistance - 25) < 1e-6)
            #expect(abs(first.squareDistance.squareRoot() - 5) < 1e-6)
        }
    }
}
