import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #972: the 2D-to-3D lifting formula lived in three places.
///
/// `Sketch.lift`, `SheetMetal.Flange.worldPoint`, and an inline `map` in
/// `FeatureReconstructor`. It is now `Placement.lift` alone.
@Suite("Issue972 2D-to-3D lifting")
struct Issue972LiftingTests {

    /// The one surviving implementation still computes what the three did.
    @Test("lift maps a 2D point through the placement's own basis")
    func liftMatchesTheFormula() {
        let p = Placement(
            origin: SIMD3(1, 2, 3),
            xAxis: SIMD3(1, 0, 0), yAxis: SIMD3(0, 1, 0), zAxis: SIMD3(0, 0, 1))
        let lifted = p.lift(SIMD2(4, 5))
        #expect(abs(lifted.x - 5) < 1e-12)
        #expect(abs(lifted.y - 7) < 1e-12)
        #expect(abs(lifted.z - 3) < 1e-12)
    }

    /// A non-axis-aligned frame, so a transposed or dropped axis cannot pass.
    @Test("lift respects a rotated basis")
    func liftRespectsARotatedBasis() {
        let s2 = 2.0.squareRoot() / 2
        let p = Placement(
            origin: .zero,
            xAxis: SIMD3(s2, s2, 0), yAxis: SIMD3(-s2, s2, 0), zAxis: SIMD3(0, 0, 1))
        let lifted = p.lift(SIMD2(1, 0))
        #expect(abs(lifted.x - s2) < 1e-12)
        #expect(abs(lifted.y - s2) < 1e-12)
        #expect(abs(lifted.z) < 1e-12)
    }

    /// Review finding on PR #997: `Flange.init` normalised `normal` into its own
    /// stored property but passed the raw parameter into `Placement(zAxis:)`, so the
    /// two disagreed for any non-unit input. `Placement` documents a unit `zAxis`.
    @Test("Flange.normal and Flange.placement.zAxis agree for a non-unit normal")
    func flangeNormalAgreesWithItsPlacement() {
        let flange = SheetMetal.Flange(
            id: "f",
            profile: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 5), SIMD2(0, 5)],
            origin: .zero,
            normal: SIMD3(0, 0, 7),  // deliberately not unit
            uAxis: SIMD3(1, 0, 0))
        #expect(abs(simd_length(flange.normal) - 1) < 1e-12)
        let d = flange.normal - flange.placement.zAxis
        #expect(simd_length(d) < 1e-12)
    }
}
