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

    /// Two parallel bisectors have no solution at all, and must report none.
    ///
    /// Both pairs are vertical, so both bisectors are horizontal lines, y=5 and y=50. The
    /// closed-form solve is singular. This is the control that keeps "found nothing" meaningful:
    /// a domain wide enough to admit every answer must still admit no answer here.
    @Test("Parallel bisectors still report no intersection")
    func parallelBisectorsReportNothing() {
        let hits = bisectorIntersections(
            a: (0, 0), b: (0, 10),
            c: (0, 40), d: (0, 60))
        #expect(hits.isEmpty)
    }

    /// The two bisector lines cross, but not on the half-lines OCCT keeps.
    ///
    /// A stronger miss than the parallel one: the closed form has a solution here, at about
    /// (10000, 5), and it is still correct to report nothing, because the first bisector's
    /// half-line runs the other way from its midpoint. A bound wide enough to reach parameter
    /// 10000 must not start inventing an answer on the dead side of the ray.
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
            #expect(abs(h.x - (-150.004_236_390_595_37)) < 1e-4)
            #expect(abs(h.y - 5) < 1e-6)
            #expect(h.paramOnFirst > 82.42)
        }
    }

    /// A pair of coincident points has no bisector, and the bridge refuses rather than crashing.
    ///
    /// `gp_Vec2d::Normalize()` raises `Standard_ConstructionError` on the zero-length perpendicular
    /// before any domain is built, so this is unaffected by the bound and is here to record that
    /// the refusal survives the change.
    @Test("Coincident points return no intersection rather than crashing")
    func coincidentPointsReturnNothing() {
        #expect(bisectorIntersections(a: (5, 5), b: (5, 5), c: (-55, 0), d: (-45, 0)).isEmpty)
        #expect(bisectorIntersections(a: (5, 5), b: (5, 5), c: (-3, -3), d: (-3, -3)).isEmpty)
    }
}
