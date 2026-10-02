import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Extrema_ExtElC Line-Ellipse")
struct ExtremaElCLinElipsTests {
    @Test func lineEllipseDistance() {
        let results = ExtremaElC.lineToEllipse(
            linePoint: SIMD3(0, 0, 10), lineDir: SIMD3(1, 0, 0),
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), xDir: SIMD3(1, 0, 0),
            majorRadius: 5, minorRadius: 3
        )
        // Four extrema: the ends of the major axis at square distance 100 and of the minor axis
        // at 109 (`Scripts/repro/766-edge-distance-elc/`). `count > 0` passed any distance.
        #expect(results.count == 4)
        let sq = results.map(\.squareDistance).sorted()
        let expected: [Double] = [100, 100, 109, 109]
        if sq.count == expected.count {
            for (a, b) in zip(sq, expected) { #expect(abs(a - b) < 1e-9) }
        }
    }

    /// A line coincident with the ellipse's own axis (#1501): `Extrema_ExtElC` reports
    /// `IsParallel()`, a degenerate case with a well-defined constant distance, which the bridge
    /// used to discard and return an empty array for.
    @Test func lineOnEllipseAxisReturnsDistance() {
        let results = ExtremaElC.lineToEllipse(
            linePoint: SIMD3(0, 0, 10), lineDir: SIMD3(0, 0, 1),
            center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), xDir: SIMD3(1, 0, 0),
            majorRadius: 5, minorRadius: 5
        )
        #expect(results.count == 1)
        if let first = results.first {
            #expect(abs(first.squareDistance - 25) < 1e-6)
            #expect(abs(first.squareDistance.squareRoot() - 5) < 1e-6)
        }
    }
}
