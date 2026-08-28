import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #849: ShapeFixStatus, the real ShapeExtend_Status ordinals, shared by ShapeFixer/FaceFixer

/// `ShapeFixer.status(Int)` used to expose only 3 of `ShapeExtend_Status`'s 19 ordinals, and
/// `FaceFixer`'s own local `Status` enum (independently) shifted everything from `.fail1` through
/// `.done` by one ordinal, because it never accounted for the combined `ShapeExtend_DONE` flag
/// OCCT places between `DONE8` and `FAIL1` (`.done` actually queried `ShapeExtend_FAIL8`). Both
/// now share one corrected type, `ShapeFixStatus`. This suite pins the real ordinals directly
/// (verified against `ShapeExtend_Status.hxx`, pinned V8_0_1) so a regression to either the old
/// 1/2/3 remap or the old off-by-one shift is caught immediately, without needing a shape that
/// happens to fire a specific fix pass.
@Suite("#849 - ShapeFixStatus real OCCT ordinals")
struct Issue849ShapeFixStatusTests {

    /// The real `ShapeExtend_Status` ordinals, exactly as declared in `ShapeExtend_Status.hxx`:
    /// OK=0, DONE1...DONE8=1...8, the combined DONE=9, FAIL1...FAIL8=10...17, the combined FAIL=18.
    @Test func rawValuesMatchTheRealOCCTEnum() {
        #expect(ShapeFixStatus.ok.rawValue == 0)
        #expect(ShapeFixStatus.done1.rawValue == 1)
        #expect(ShapeFixStatus.done2.rawValue == 2)
        #expect(ShapeFixStatus.done3.rawValue == 3)
        #expect(ShapeFixStatus.done4.rawValue == 4)
        #expect(ShapeFixStatus.done5.rawValue == 5)
        #expect(ShapeFixStatus.done6.rawValue == 6)
        #expect(ShapeFixStatus.done7.rawValue == 7)
        #expect(ShapeFixStatus.done8.rawValue == 8)
        #expect(ShapeFixStatus.done.rawValue == 9)  // combined DONE, sits BEFORE fail1, not after fail8
        #expect(ShapeFixStatus.fail1.rawValue == 10)
        #expect(ShapeFixStatus.fail2.rawValue == 11)
        #expect(ShapeFixStatus.fail3.rawValue == 12)
        #expect(ShapeFixStatus.fail4.rawValue == 13)
        #expect(ShapeFixStatus.fail5.rawValue == 14)
        #expect(ShapeFixStatus.fail6.rawValue == 15)
        #expect(ShapeFixStatus.fail7.rawValue == 16)
        #expect(ShapeFixStatus.fail8.rawValue == 17)
        #expect(ShapeFixStatus.fail.rawValue == 18)  // combined FAIL, last ordinal
    }

    /// `FaceFixer.Status` is a typealias for `ShapeFixStatus` (#849), same cases, same raw
    /// values, unlike before, when it was an independent enum with its own (wrong) raw values.
    @Test func faceFixerStatusIsTheSharedType() {
        #expect(FaceFixer.Status.self == ShapeFixStatus.self)
        #expect(FaceFixer.Status.done.rawValue == 9)
        #expect(FaceFixer.Status.fail1.rawValue == 10)
        #expect(FaceFixer.Status.fail8.rawValue == 17)
    }

    /// `ShapeFixer`'s legacy `status(Int)` overload already mapped its 3 supported values to the
    /// CORRECT OCCT constants (`ShapeExtend_OK`/`DONE`/`FAIL`), only its exposed granularity was
    /// the bug, not those three answers, so it doubles as a live oracle for the new
    /// `status(ShapeFixStatus)` overload on the same three cases, end to end through the real,
    /// new `OCCTShapeFixerStatusFlag` bridge call (wiring, not just the Swift-side constant).
    /// Measured, not assumed: `ShapeFix_Shape::Perform()` on a plain box already sets the combined
    /// `DONE` flag (there is always some tolerance-level bookkeeping to do), so this genuinely
    /// discriminates the old off-by-one `.done` (which read `ShapeExtend_FAIL8`, false here) from
    /// the fix, proven directly: reverting `ShapeFixStatus` to the pre-#849 encoding fails this
    /// test's `.done` comparison (`fixer.status(2) → true` vs `fixer.status(.done) → false`), not
    /// just the raw-value test above.
    @Test func legacyAndTypeSafeOverloadsAgree() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("setup: box")
            return
        }
        let fixer = ShapeFixer(shape: box)
        _ = fixer.perform()

        #expect(fixer.status(1) == fixer.status(.ok))
        #expect(fixer.status(2) == fixer.status(.done))
        #expect(fixer.status(3) == fixer.status(.fail))
    }

    /// The legacy overload's own documented, narrow contract: silently `false` outside `1...3`.
    /// Pinned so nobody "fixes" it into forwarding raw ordinals directly, which would be a real
    /// behavior change to already-shipped public API (the type-safe overload above is the
    /// additive replacement for that).
    @Test func legacyOverloadStaysNarrow() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("setup: box")
            return
        }
        let fixer = ShapeFixer(shape: box)
        _ = fixer.perform()

        #expect(!fixer.status(0))
        #expect(!fixer.status(4))
        #expect(!fixer.status(9))
        #expect(!fixer.status(18))
    }
}
