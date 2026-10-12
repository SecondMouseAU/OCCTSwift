import Foundation
import Testing

@testable import OCCTSwift

/// The ellipse converter's parameter range, which the kernel states and does not check.
///
/// #2884: the arc constructor of `Convert_EllipseToBSplineCurve` states its only precondition,
/// `0 < ULast - UFirst <= 2*pi + PConfusion()`, as a `Standard_DomainError_Raise_if` whose two
/// condition locals sit inside the `#ifndef No_Exception` region with it. The pinned Release
/// kernel defines `No_Exception`, so nothing is left of either. The constructor
/// hands the range to `Convert_ConicToBSplineCurve::BuildCosAndSin`, which derives
/// `num_spans = trunc(1.2 * delta / pi) + 1` and `num_poles = 2 * num_spans + 1` from it. Measured
/// in `Scripts/repro/2884`, one process per case:
///
/// - `delta <= -5*pi/3` gives a negative pole count and SIGSEGVs inside the constructor.
///   `u1: 2 * .pi, u2: 0` is in that band, so swapping two adjacent arguments on a full ellipse
///   took the process down.
/// - `2*pi + PConfusion() < delta` returned a non-nil curve that winds past a full turn and
///   overlaps itself; at `delta = 1e9` it asked for 763,943,729 poles and never came back.
/// - `delta` of NaN returned a curve whose every pole was NaN, and OCCT's own predicate would not
///   have refused it either, because both of its comparisons are false on a NaN.
///
/// `Curve2D.fromCircleArc` is the control: `Convert_CircleToBSplineCurve.cxx:129` writes the same
/// precondition as a literal `throw`, which no macro gates.
@Suite("#2884: ellipse converter parameter range")
struct Issue2884EllipseConverterRangeTests {

    private static func ellipse(_ u1: Double, _ u2: Double) -> Curve2D? {
        Curve2D.fromEllipseArc(
            centerX: 0, centerY: 0, majorRadius: 5, minorRadius: 3, u1: u1, u2: u2)
    }

    @Test("an in-range sweep still converts, including exactly one full turn")
    func inRangeStillConverts() throws {
        // Converting is not the claim: each curve is the arc asked for, so its end points are
        // the ellipse's at u1 and u2 (x = 5 cos u, y = 3 sin u) and the middle sample is on it.
        for (u1, u2) in [(0.0, Double.pi), (0.0, 2 * Double.pi), (-1.0, 1.0)] {
            let c = try #require(Self.ellipse(u1, u2), "(\(u1), \(u2)) converts")
            let d = c.domain
            let p0 = c.point(at: d.lowerBound)
            let p1 = c.point(at: d.upperBound)
            #expect(abs(p0.x - 5 * cos(u1)) < 1e-9 && abs(p0.y - 3 * sin(u1)) < 1e-9, "start \(p0)")
            #expect(abs(p1.x - 5 * cos(u2)) < 1e-9 && abs(p1.y - 3 * sin(u2)) < 1e-9, "end \(p1)")
            for k in 1..<4 {
                let t = d.lowerBound + (d.upperBound - d.lowerBound) * Double(k) / 4
                let p = c.point(at: t)
                let r = (p.x * p.x) / 25 + (p.y * p.y) / 9
                #expect(abs(r - 1) < 1e-6, "sample \(p) is off the ellipse, x2/25 + y2/9 = \(r)")
            }
        }
    }

    @Test("every out-of-range sweep is refused")
    func outOfRangeRefused() {
        // Written as one test walking a list rather than @Test(arguments:), because an argument
        // element pairing a reference-counted member with a 32-byte builtin vector cannot be
        // written at all (swiftlang/swift#91639, see CLAUDE.md).
        let bad: [(Double, Double)] = [
            (2 * .pi, 0),  // the swapped-argument SIGSEGV
            (6, 0),  // just past -5*pi/3, the other side of the same fault
            (100, 0),  // far into it
            (.pi, 0),  // -5*pi/3 < delta < 0: refused by the kernel today, by luck
            (1, 1),  // delta == 0, the `delta <= 0` half of the condition
            (0, 6.2831863071795864),  // 2*pi + 1e-6, just past the tolerance
            (0, 12),  // a curve that winds past a full turn and overlaps itself
            (0, 1e9),  // 763,943,729 poles, and the process does not come back
            (0, .nan),  // OCCT's own predicate is false here too
            (.nan, 0),
            (0, .infinity),
        ]
        for (u1, u2) in bad {
            #expect(
                Self.ellipse(u1, u2) == nil,
                "fromEllipseArc(u1: \(u1), u2: \(u2)) returned a curve")
        }
    }

    @Test("the control: the circle converter's literal throw always refused the same input")
    func circleControl() {
        #expect(Curve2D.fromCircleArc(centerX: 0, centerY: 0, radius: 5, u1: 0, u2: 12) == nil)
        #expect(Curve2D.fromCircleArc(centerX: 0, centerY: 0, radius: 5, u1: 0, u2: .pi) != nil)
    }
}
