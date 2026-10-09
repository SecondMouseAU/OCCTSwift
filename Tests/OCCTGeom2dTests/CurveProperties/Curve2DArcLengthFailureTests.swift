import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #409: arcLength(from:to:) no longer collapses failure into 0.0

/// `arcLength(from:to:)` used to collapse failure into `0.0`, indistinguishable from a genuine
/// zero-length interval. #409 made it an unambiguous `-1.0` sentinel, keeping the non-optional
/// signature (matching #408's `Curve3D.arcLength(from:to:)` shape) and leaving `length(from:to:)`
/// as the optional, failure-distinguishing sibling for callers who want `nil`.
///
/// #409 kept the two entry points on separate bridge calls, because they built their adaptor
/// differently: `arcLength(from:to:)` pre-bounded it (`Geom2dAdaptor_Curve(curve, u1, u2)`,
/// which raises on `u1 > u2`), `length(from:to:)` passed the range to `Length(adaptor, u1, u2)`,
/// which does not, and a reversed range was read as the one thing that difference bought. #549
/// measured the rest of it: the pre-bounded form also extrapolated past a multi-span curve's
/// knots, so the two spellings are one bridge call now and a reversed range measures the span.
/// The sentinel this suite is about is unchanged; `Issue549Curve2DArcLengthRangeTests` covers
/// which inputs still reach it.
@Suite("Curve2D.arcLength(from:to:) distinguishes failure from zero (#409)")
struct Curve2DArcLengthFailureTests {

    private static let bezier = Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(5, 5), SIMD2(10, 0)])!

    @Test("A genuine failure is reported as -1.0, not 0.0")
    func genuineFailureIsNotZero() {
        // A NaN bound poisons the quadrature on a single-span curve; before #409 the bridge
        // reported that as 0.0, the same value a zero-width interval reports.
        let len = Self.bezier.arcLength(from: 0, to: .nan)
        #expect(len == -1.0)
        #expect(len != 0.0)
    }

    @Test("Equal bounds are a genuine zero-length result, not the failure sentinel")
    func equalBoundsAreGenuinelyZero() {
        let len = Self.bezier.arcLength(from: 0.3, to: 0.3)
        #expect(abs(len) < 1e-9)
        #expect(len != -1.0)
    }

    @Test("Both spellings tolerate a reversed range and agree on it")
    func bothSpellingsTolerateReversedRange() {
        let forward = Self.bezier.length(from: 0.2, to: 0.8)
        let reversed = Self.bezier.length(from: 0.8, to: 0.2)
        #expect(forward != nil)
        #expect(reversed != nil)
        if let forward, let reversed {
            #expect(abs(forward - reversed) < 1e-9)
            #expect(abs(Self.bezier.arcLength(from: 0.8, to: 0.2) - reversed) < 1e-9)
        }
    }
}
