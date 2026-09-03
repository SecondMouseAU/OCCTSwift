import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtElC Circle-Circle")
struct ExtremaElCCircCircTests {
    @Test func coplanarCircles() {
        let results = ExtremaElC.circleToCircle(
            center1: SIMD3(0, 0, 0), normal1: SIMD3(0, 0, 1), radius1: 5,
            center2: SIMD3(20, 0, 0), normal2: SIMD3(0, 0, 1), radius2: 5
        )
        #expect(results.count > 0)
    }

    /// Coaxial, coplanar (concentric) circles (#1501): `Extrema_ExtElC` reports `IsParallel()`, a
    /// degenerate case with a well-defined constant distance (the radii's absolute difference),
    /// which the bridge used to discard and return an empty array for.
    @Test func coaxialCirclesReturnRadiusDifference() {
        let results = ExtremaElC.circleToCircle(
            center1: SIMD3(0, 0, 0), normal1: SIMD3(0, 0, 1), radius1: 5,
            center2: SIMD3(0, 0, 0), normal2: SIMD3(0, 0, 1), radius2: 3
        )
        #expect(results.count == 1)
        if let first = results.first {
            #expect(abs(first.squareDistance - 4) < 1e-6)
            #expect(abs(first.squareDistance.squareRoot() - 2) < 1e-6)
        }
    }
}
