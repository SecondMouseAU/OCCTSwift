import Foundation
import Testing

@testable import OCCTSwift

/// #2972's fix stops a stepped seam from filleting the wider flange's free edge, and it can only do
/// that where it knows the run of the seam the bend occupies. That run is read off the bend
/// intersection, which exists only when the seam runs along one of the flange's own profile axes.
///
/// A seam diagonal to the flange's axes gets `intersect`'s "no split" fallback, so
/// `SheetMetal.seamExtent` returns nil and the extent filter is off. A review of the fix asked
/// whether that re-opens the original defect for a diagonal stepped seam: an upright narrower than
/// the chamfer edge it stands on, with free edge left over on the seam line.
///
/// It does not, and this suite is the measurement. The same geometry was built on `origin/main`
/// before the fix and after it:
///
/// * the **control**, the upright spanning the whole chamfer edge, builds to 968.0606173278654 on
///   both;
/// * the **stepped** case, the upright 4 wide on an 11.31 edge, throws
///   `BuildError.filletFailed` on both.
///
/// So a diagonal stepped seam refuses loudly rather than returning a volume that is silently
/// short, which is what made the axis-aligned defect worth fixing. What this suite guards is the
/// way that could change: if a later change makes the stepped case build without also giving it an
/// extent, the first test fails and says the result needs checking against the closed form.
@Suite("Issue #2972: a diagonal stepped seam refuses rather than returning a wrong volume")
struct Issue2972DiagonalSteppedSeamTests {

    /// A 20 x 20 base with a chamfered corner, and an upright standing on the chamfer edge.
    ///
    /// The chamfer edge runs from (20, 12) to (12, 20), so it is diagonal to the base's own axes,
    /// which is what puts the seam in `intersect`'s no-split fallback.
    private func build(start: Double, width: Double) throws -> Shape {
        let s = 1.0 / 2.0.squareRoot()
        let seam = SIMD3<Double>(-s, s, 0)
        let base = SheetMetal.Flange(
            id: "a",
            profile: [SIMD2(0, 0), SIMD2(20, 0), SIMD2(20, 12), SIMD2(12, 20), SIMD2(0, 20)],
            origin: SIMD3<Double>(0, 0, 0),
            normal: SIMD3<Double>(0, 0, 1),
            uAxis: SIMD3<Double>(1, 0, 0),
            vAxis: SIMD3<Double>(0, 1, 0))
        let upright = SheetMetal.Flange(
            id: "b",
            profile: [SIMD2(0, 0), SIMD2(width, 0), SIMD2(width, 10), SIMD2(0, 10)],
            origin: SIMD3<Double>(20, 12, 0) + start * seam,
            normal: SIMD3<Double>(s, s, 0),
            uAxis: seam,
            vAxis: SIMD3<Double>(0, 0, 1))
        return try SheetMetal.Builder(thickness: 2).build(
            flanges: [base, upright],
            bends: [SheetMetal.Bend(from: "a", to: "b", radius: 1.5)])
    }

    @Test("the upright spanning the whole chamfer edge builds, so the geometry is a legal bend")
    func controlBuilds() throws {
        let shape = try build(start: 0, width: 8 * 2.0.squareRoot())
        #expect(shape.isValid)
        let volume = try #require(shape.volume)
        // Measured on origin/main and on the #2972 branch alike. A change here means the diagonal
        // path moved, not that this number was wrong.
        #expect(abs(volume - 968.0606173278654) < 1e-6, "measured \(volume)")
    }

    @Test("the upright narrower than the chamfer edge refuses with filletFailed, as it always has")
    func steppedRefuses() {
        #expect(
            throws: SheetMetal.BuildError.filletFailed(fromID: "a", toID: "b", radius: 1.5)
        ) {
            _ = try build(start: 3, width: 4)
        }
    }
}
