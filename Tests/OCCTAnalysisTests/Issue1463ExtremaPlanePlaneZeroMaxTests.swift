import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

/// #1463: `OCCTExtremaElSSPlanePlane`'s parallel-plane branch
/// (`OCCTBridge_Surface_Extrema.mm`) decoupled the buffer write from the returned count. Every
/// other branch/function in the file follows `for (...; count < max; ...) { write; count++; }
/// return count;`, gating the write and the count on the same condition. The parallel branch
/// instead gated only the write on `max > 0` and returned `1` unconditionally, so a caller
/// passing `max: 0` (an empty/zero-capacity buffer, the ordinary "query capacity first" idiom)
/// was told "1 extremum available" while `out[0]` was never touched.
///
/// `ExtremaElSS.planeToPlane` (`ExtremaTypes.swift`), the only Swift-level caller, always
/// allocates a 10-element buffer and passes `max: 10`, so the defect was latent, unreachable
/// through the public Swift API. This suite calls `OCCTExtremaElSSPlanePlane` directly, matching
/// `Issue761SharedEdgeCountCapTests` and `Issue900BoundingBoxOutParamZeroingTests`'s precedent for
/// exercising a bridge function's buffer-count contract directly rather than through the wrapper.
///
/// Fixture: two parallel planes (z=0 and z=10, both normal (0,0,1)), the same pair
/// `ExtremaElSSPlanePlaneTests.parallelPlanes` already exercises at `max: 10`.
@Suite("Issue #1463: OCCTExtremaElSSPlanePlane's parallel branch honors max == 0")
struct Issue1463ExtremaPlanePlaneZeroMaxTests {

    /// A recognizable, non-zero pattern the fix could never produce by chance, distinct from the
    /// all-zero `out[0]` the (still-latent, `max > 0`) success path writes.
    private static let sentinel = OCCTExtremaElResult(
        squareDistance: -999, x1: -999, y1: -999, z1: -999, x2: -999, y2: -999, z2: -999)

    private func isSentinel(_ r: OCCTExtremaElResult) -> Bool {
        r.squareDistance == -999 && r.x1 == -999 && r.y1 == -999 && r.z1 == -999 && r.x2 == -999
            && r.y2 == -999 && r.z2 == -999
    }

    @Test("max: 0 on parallel planes returns 0, not 1, and writes nothing")
    func zeroMaxReturnsZeroOnParallelPlanes() {
        var isParallel = false
        // A single sentinel-filled slot: max: 0 means the function must never touch it, even
        // though the header declares `out` `_Nonnull` so the pointer itself must still be valid.
        var buf = [OCCTExtremaElResult](repeating: Self.sentinel, count: 1)

        let n = OCCTExtremaElSSPlanePlane(
            0, 0, 0, 0, 0, 1,
            0, 0, 10, 0, 0, 1,
            &isParallel, &buf, 0
        )

        #expect(isParallel)
        #expect(n == 0, "max: 0 must report 0 extrema written, not the OCCT-side NbExt() of 1")
        #expect(isSentinel(buf[0]), "out[0] must be untouched when max: 0")
    }

    @Test("max > 0 on parallel planes still returns 1 and writes the distance, unchanged")
    func nonZeroMaxStillReturnsOneOnParallelPlanes() {
        var isParallel = false
        var buf = [OCCTExtremaElResult](repeating: Self.sentinel, count: 10)

        let n = OCCTExtremaElSSPlanePlane(
            0, 0, 0, 0, 0, 1,
            0, 0, 10, 0, 0, 1,
            &isParallel, &buf, 10
        )

        #expect(isParallel)
        #expect(n == 1)
        #expect(abs(buf[0].squareDistance - 100) < 0.1)
    }

    @Test("max: 0 on intersecting (non-parallel) planes already returned 0 before this fix")
    func zeroMaxReturnsZeroOnIntersectingPlanes() {
        var isParallel = false
        var buf = [OCCTExtremaElResult](repeating: Self.sentinel, count: 1)

        let n = OCCTExtremaElSSPlanePlane(
            0, 0, 0, 0, 0, 1,
            0, 0, 0, 1, 0, 0,
            &isParallel, &buf, 0
        )

        #expect(!isParallel)
        #expect(n == 0)
        #expect(isSentinel(buf[0]))
    }
}
