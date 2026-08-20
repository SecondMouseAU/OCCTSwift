import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #1020: the 2D sibling of the `Extrema_ExtPElC` bounds in `OCCTBridge_Curve3D.mm`.
///
/// `OCCTExtremaExtPElC2dLin` passed a fabricated `-1e10, 1e10` parameter range to
/// `Extrema_ExtPElC2d`. A `gp_Lin2d` is unbounded, and `Uinf`/`Usup` post-filter an
/// answer Extrema has already computed, so a finite bound can only discard a correct
/// result. It now passes `RealFirst()`/`RealLast()`, matching the 3D fix in #1024.
@Suite("Issue1020 point-to-line 2D extrema bounds")
struct Issue1020Extrema2dBoundsTests {

    /// The foot of the perpendicular sits past the old cut-off.
    ///
    /// Parameter 2e10 along the line, beyond the old 1e10 bound, which discarded it.
    @Test("A point projecting beyond the old 2D line bound still has an extremum")
    func pointToLineBeyondOldBound() {
        let results = Extrema2d.distanceFromPointToLine(
            point: SIMD2(2e10, 3),
            linePoint: SIMD2(0, 0), lineDir: SIMD2(1, 0))
        #expect(!results.isEmpty)
        if let r = results.first {
            #expect(abs(r.param2 - 2e10) < 1e4)
            #expect(abs(r.squareDistance - 9) < 1e-3)
        }
    }

    /// A point well inside the old bound is unchanged.
    ///
    /// So the fix widened the accepted range rather than moving any answer.
    @Test("A point projecting inside the old 2D line bound is unchanged")
    func pointToLineInsideOldBound() {
        let results = Extrema2d.distanceFromPointToLine(
            point: SIMD2(4, 3),
            linePoint: SIMD2(0, 0), lineDir: SIMD2(1, 0))
        #expect(!results.isEmpty)
        if let r = results.first {
            #expect(abs(r.param2 - 4) < 1e-9)
            #expect(abs(r.squareDistance - 9) < 1e-9)
        }
    }
}
