import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #1050: `OCCTBisectorInterPointPoint` clamped both `IntRes2d_Domain` parameter ranges to a
/// hardcoded `[-100, 100]`.
///
/// A point-point bisector is a half-line trimmed to `[0, Precision::Infinite()]`, so that window
/// spent half its width off the curve and capped the live half at 100. Any meeting point past
/// parameter 100 was dropped, and `bisectorIntersections` returned an empty array, which a caller
/// cannot tell from "these bisectors do not meet". Each domain is now built from its own bisector's
/// `FirstParameter()`/`LastParameter()`.
///
/// These tests have to separate a dropped intersection from a genuine miss, so they come in pairs:
/// a fixture whose meeting point the old window cut off and must now be found, and a fixture with
/// no reachable meeting point that must still report none. Every expected point is solved in closed
/// form from the perpendicular-bisector equations, independent of OCCT. Measurements and the
/// candidate-bound comparison are in `Scripts/repro/1050-bisector-domain/`.
///
/// Three of the seven are labelled **regression guards** rather than coverage, because they were
/// measured to be insensitive to the thing under test and none of the six injections in the
/// removal matrix turns any of them red. `Bisector_Inter::Perform` re-clips whatever domain it is
/// given to `max(IntervalFirst, MinDomain)`, so no domain choice can conjure a point where the
/// half-lines do not meet, and the coincident-points case throws before a domain is built at all.
/// They earn their place by keeping "reported nothing" meaningful, which is the whole distinction
/// this issue turns on, and a change that made one of them fail would be a regression rather than a
/// caught defect. Saying so is the point: an unlabelled test that cannot fail looks like coverage.
@Suite("Issue1050 bisector intersection domain")
struct Issue1050BisectorDomainTests {

    /// The meeting point sits at parameter 150, past the old cut-off.
    ///
    /// Bisector of A(0,0) B(0,10) is the half-line running along -x from (0,5); bisector of
    /// C(-155,0) D(-145,0) is the half-line running along +y from (-150,0). They meet at (-150, 5),
    /// at parameter 150 on the first, which the old `[-100, 100]` discarded.
    @Test("A meeting point past the old window is found")
    func meetingPointBeyondOldWindowIsFound() {
        let hits = bisectorIntersections(
            a: (0, 0), b: (0, 10),
            c: (-155, 0), d: (-145, 0))
        #expect(!hits.isEmpty)
        if let h = hits.first {
            #expect(abs(h.x - (-150)) < 1e-6)
            #expect(abs(h.y - 5) < 1e-6)
            #expect(abs(h.paramOnFirst - 150) < 1e-6)
        }
    }

    /// A meeting point well inside the old window is unchanged.
    ///
    /// So the fix widened the range the search covers rather than moving any answer it already had.
    @Test("A meeting point inside the old window is unchanged")
    func meetingPointInsideOldWindowIsUnchanged() {
        let hits = bisectorIntersections(
            a: (0, 0), b: (0, 10),
            c: (-55, 0), d: (-45, 0))
        #expect(!hits.isEmpty)
        if let h = hits.first {
            #expect(abs(h.x - (-50)) < 1e-6)
            #expect(abs(h.y - 5) < 1e-6)
            #expect(abs(h.paramOnFirst - 50) < 1e-6)
        }
    }

    /// Regression guard.
    ///
    /// Two parallel bisectors have no solution at all, and must report none.
    ///
    /// Both pairs are vertical, so both bisectors are horizontal lines, y=5 and y=50, and the
    /// closed-form solve is singular. Insensitive to the bound: all six injections in
    /// `Scripts/repro/1050-bisector-domain/matrix.sh` leave it green, which is the measured part.
    /// A symmetric `[-LastParameter, LastParameter]` domain also yields zero, but no committed
    /// probe builds one, so treat that as corroboration rather than evidence. It keeps
    /// "found nothing" meaningful, which is what the issue turns on.
    @Test("Parallel bisectors still report no intersection")
    func parallelBisectorsReportNothing() {
        let hits = bisectorIntersections(
            a: (0, 0), b: (0, 10),
            c: (0, 40), d: (0, 60))
        #expect(hits.isEmpty)
    }

    /// Regression guard.
    ///
    /// The two bisector lines cross, but not on the half-lines OCCT keeps.
    ///
    /// A stronger miss than the parallel one: the closed form has a solution here, at about
    /// (10000, 5), and it is still correct to report nothing, because the first bisector's
    /// half-line runs the other way from its midpoint. A bound wide enough to reach parameter
    /// 10000 must not start inventing an answer on the dead side of the ray. Insensitive to the
    /// bound on the same evidence as the parallel guard above, and with the same caveat about the
    /// symmetric-domain half of it.
    @Test("A crossing on the dead side of the half-line reports no intersection")
    func crossingOnDeadSideReportsNothing() {
        let hits = bisectorIntersections(
            a: (0, 0), b: (0, 10),
            c: (19.9995, 1.01), d: (20.0005, 10.99))
        #expect(hits.isEmpty)
    }

    /// The meeting point lies past any bound derived from the four points' own extent.
    ///
    /// The two bisectors cross at 10.9 degrees, the four points span 40.71, and the meeting point
    /// is at parameter 150.004, so a plausible-looking `2 * span + 1` bound of 82.42 would cut it
    /// off exactly the way the old fixed window did. C and D are solved for by
    /// `Scripts/repro/1050-bisector-domain/build-discriminating-fixture.py`. This is the case that
    /// pins the bound to the curve's own range rather than to anything computed from the input.
    @Test("A meeting point past any input-derived bound is found")
    func meetingPointBeyondInputExtentIsFound() {
        let hits = bisectorIntersections(
            a: (0, 0), b: (0, 10),
            c: (-19.0558, 25.0900), d: (-20.9442, 34.9100))
        #expect(!hits.isEmpty)
        if let h = hits.first {
            // The expected value is the closed-form solve of the ROUNDED C and D actually
            // passed, not of the construction's intended target, and OCCT agrees with it to
            // 3e-14. 1e-9 matches the rest of this file; a looser 1e-4 would not notice a
            // change that moved the crossing by 1e-5.
            #expect(abs(h.x - (-150.004_236_390_595_37)) < 1e-9)
            #expect(abs(h.y - 5) < 1e-6)
            #expect(h.paramOnFirst > 82.42)
        }
    }

    /// The circumcentre example in `docs/reference/Shape-Recognition.md`, all four orderings.
    ///
    /// The doc claims one of the four returns the circumcentre and three return nothing. A
    /// documented claim nobody executes drifts, and this one is the whole reason the half-line
    /// paragraph exists, so it is pinned here rather than left as prose.
    @Test("The documented circumcentre example holds, and its three reorderings do not")
    func documentedCircumcentreExample() {
        let hits = bisectorIntersections(a: (0, 0), b: (4, 0), c: (4, 0), d: (2, 3))
        #expect(hits.count == 1)
        if let h = hits.first {
            #expect(abs(h.x - 2) < 1e-9)
            #expect(abs(h.y - 5.0 / 6.0) < 1e-9)
        }
        #expect(bisectorIntersections(a: (4, 0), b: (0, 0), c: (4, 0), d: (2, 3)).isEmpty)
        #expect(bisectorIntersections(a: (0, 0), b: (4, 0), c: (2, 3), d: (4, 0)).isEmpty)
        #expect(bisectorIntersections(a: (4, 0), b: (0, 0), c: (2, 3), d: (4, 0)).isEmpty)
    }

    /// Regression guard.
    ///
    /// A pair of coincident points has no bisector, and the bridge refuses rather than crashing.
    ///
    /// `gp_Vec2d::Normalize()` raises `Standard_ConstructionError` on the zero-length perpendicular
    /// before any domain is built, so the bound is never reached and this cannot fail under any
    /// injection. It is here to record that the refusal survives the change.
    ///
    /// Exactly coincident is the extreme of a range, and the mechanism differs across it: a merely
    /// close pair is refused by `GccAna_NoSolution` from about `1e-10`, long before the
    /// normalisation notices anything. See `docs/reference/Shape-Recognition.md`, cause 1.
    @Test("Coincident points return no intersection rather than crashing")
    func coincidentPointsReturnNothing() {
        #expect(bisectorIntersections(a: (5, 5), b: (5, 5), c: (-55, 0), d: (-45, 0)).isEmpty)
        #expect(bisectorIntersections(a: (5, 5), b: (5, 5), c: (-3, -3), d: (-3, -3)).isEmpty)
    }
}

/// #1085: `bisectorIntersections` does not return for non-finite or near-1e300 coordinates.
///
/// The underlying OCCT bisector computation can hang or exhibit undefined behaviour when given
/// NaN, infinity, or extremely large coordinate values. This suite verifies that the Swift wrapper
/// validates all eight input coordinates and returns an empty array immediately for any non-finite
/// value or any value exceeding the safe magnitude threshold (1e150), avoiding the hang.
@Suite("Issue1085 bisector non-finite coordinates")
struct Issue1085BisectorNonFiniteTests {

    /// NaN in any coordinate position returns empty rather than hanging.
    @Test("NaN in first point returns empty")
    func nanInFirstPoint() {
        #expect(bisectorIntersections(a: (Double.nan, 0), b: (0, 10), c: (-55, 0), d: (-45, 0)).isEmpty)
        #expect(bisectorIntersections(a: (0, Double.nan), b: (0, 10), c: (-55, 0), d: (-45, 0)).isEmpty)
    }

    @Test("NaN in second point returns empty")
    func nanInSecondPoint() {
        #expect(bisectorIntersections(a: (0, 0), b: (Double.nan, 10), c: (-55, 0), d: (-45, 0)).isEmpty)
        #expect(bisectorIntersections(a: (0, 0), b: (0, Double.nan), c: (-55, 0), d: (-45, 0)).isEmpty)
    }

    @Test("NaN in third point returns empty")
    func nanInThirdPoint() {
        #expect(bisectorIntersections(a: (0, 0), b: (0, 10), c: (Double.nan, 0), d: (-45, 0)).isEmpty)
        #expect(bisectorIntersections(a: (0, 0), b: (0, 10), c: (-55, Double.nan), d: (-45, 0)).isEmpty)
    }

    @Test("NaN in fourth point returns empty")
    func nanInFourthPoint() {
        #expect(bisectorIntersections(a: (0, 0), b: (0, 10), c: (-55, 0), d: (Double.nan, 0)).isEmpty)
        #expect(bisectorIntersections(a: (0, 0), b: (0, 10), c: (-55, 0), d: (-45, Double.nan)).isEmpty)
    }

    /// +Infinity in any coordinate position returns empty rather than hanging.
    @Test("Positive infinity in first point returns empty")
    func positiveInfinityInFirstPoint() {
        #expect(bisectorIntersections(a: (Double.infinity, 0), b: (0, 10), c: (-55, 0), d: (-45, 0)).isEmpty)
        #expect(bisectorIntersections(a: (0, Double.infinity), b: (0, 10), c: (-55, 0), d: (-45, 0)).isEmpty)
    }

    @Test("Positive infinity in second point returns empty")
    func positiveInfinityInSecondPoint() {
        #expect(bisectorIntersections(a: (0, 0), b: (Double.infinity, 10), c: (-55, 0), d: (-45, 0)).isEmpty)
        #expect(bisectorIntersections(a: (0, 0), b: (0, Double.infinity), c: (-55, 0), d: (-45, 0)).isEmpty)
    }

    @Test("Positive infinity in third point returns empty")
    func positiveInfinityInThirdPoint() {
        #expect(bisectorIntersections(a: (0, 0), b: (0, 10), c: (Double.infinity, 0), d: (-45, 0)).isEmpty)
        #expect(bisectorIntersections(a: (0, 0), b: (0, 10), c: (-55, Double.infinity), d: (-45, 0)).isEmpty)
    }

    @Test("Positive infinity in fourth point returns empty")
    func positiveInfinityInFourthPoint() {
        #expect(bisectorIntersections(a: (0, 0), b: (0, 10), c: (-55, 0), d: (Double.infinity, 0)).isEmpty)
        #expect(bisectorIntersections(a: (0, 0), b: (0, 10), c: (-55, 0), d: (-45, Double.infinity)).isEmpty)
    }

    /// -Infinity in any coordinate position returns empty rather than hanging.
    @Test("Negative infinity in first point returns empty")
    func negativeInfinityInFirstPoint() {
        #expect(bisectorIntersections(a: (-Double.infinity, 0), b: (0, 10), c: (-55, 0), d: (-45, 0)).isEmpty)
        #expect(bisectorIntersections(a: (0, -Double.infinity), b: (0, 10), c: (-55, 0), d: (-45, 0)).isEmpty)
    }

    @Test("Negative infinity in second point returns empty")
    func negativeInfinityInSecondPoint() {
        #expect(bisectorIntersections(a: (0, 0), b: (-Double.infinity, 10), c: (-55, 0), d: (-45, 0)).isEmpty)
        #expect(bisectorIntersections(a: (0, 0), b: (0, -Double.infinity), c: (-55, 0), d: (-45, 0)).isEmpty)
    }

    @Test("Negative infinity in third point returns empty")
    func negativeInfinityInThirdPoint() {
        #expect(bisectorIntersections(a: (0, 0), b: (0, 10), c: (-Double.infinity, 0), d: (-45, 0)).isEmpty)
        #expect(bisectorIntersections(a: (0, 0), b: (0, 10), c: (-55, -Double.infinity), d: (-45, 0)).isEmpty)
    }

    @Test("Negative infinity in fourth point returns empty")
    func negativeInfinityInFourthPoint() {
        #expect(bisectorIntersections(a: (0, 0), b: (0, 10), c: (-55, 0), d: (-Double.infinity, 0)).isEmpty)
        #expect(bisectorIntersections(a: (0, 0), b: (0, 10), c: (-55, 0), d: (-45, -Double.infinity)).isEmpty)
    }

    /// Extremely large finite coordinates (exceeding 1e150) return empty rather than hanging or
    /// producing garbage. These values are within Double's finite range but can cause numerical
    /// issues in the OCCT bisector computation. The threshold matches the `maxSafeMagnitude` in
    /// `BisectorResult.swift`.
    @Test("Large finite coordinates exceeding 1e150 return empty")
    func largeFiniteCoordinatesReturnEmpty() {
        let large = 1e200  // Exceeds the BisectorIntersection.maxSafeMagnitude threshold
        #expect(bisectorIntersections(a: (large, 0), b: (0, 10), c: (-55, 0), d: (-45, 0)).isEmpty)
        #expect(bisectorIntersections(a: (0, large), b: (0, 10), c: (-55, 0), d: (-45, 0)).isEmpty)
        #expect(bisectorIntersections(a: (0, 0), b: (large, 10), c: (-55, 0), d: (-45, 0)).isEmpty)
        #expect(bisectorIntersections(a: (0, 0), b: (0, large), c: (-55, 0), d: (-45, 0)).isEmpty)
        #expect(bisectorIntersections(a: (0, 0), b: (0, 10), c: (large, 0), d: (-45, 0)).isEmpty)
        #expect(bisectorIntersections(a: (0, 0), b: (0, 10), c: (-55, large), d: (-45, 0)).isEmpty)
        #expect(bisectorIntersections(a: (0, 0), b: (0, 10), c: (-55, 0), d: (large, 0)).isEmpty)
        #expect(bisectorIntersections(a: (0, 0), b: (0, 10), c: (-55, 0), d: (-45, large)).isEmpty)
        #expect(bisectorIntersections(a: (-large, 0), b: (0, 10), c: (-55, 0), d: (-45, 0)).isEmpty)
        #expect(bisectorIntersections(a: (0, -large), b: (0, 10), c: (-55, 0), d: (-45, 0)).isEmpty)
    }

    /// Coordinates just below the threshold (1e100) should still work normally.
    /// Using 1e100 instead of 1e149 because Double precision at 1e149 cannot represent the +5 offset (ULP ≈ 2e133).
    @Test("Coordinates near but below threshold still work")
    func coordinatesBelowThresholdWork() {
        let nearThreshold = 1e100  // Below the BisectorIntersection.maxSafeMagnitude threshold
        // This should compute normally - using a simple case that has a known intersection
        let hits = bisectorIntersections(
            a: (0, 0), b: (0, 10),
            c: (-nearThreshold, 0), d: (-nearThreshold + 10, 0))
        // The bisectors should meet at x = -nearThreshold + 5, y = 5
        #expect(!hits.isEmpty)
        if let h = hits.first {
            #expect(abs(h.x - (-nearThreshold + 5)) < 1e-6)
            #expect(abs(h.y - 5) < 1e-6)
        }
    }
}
