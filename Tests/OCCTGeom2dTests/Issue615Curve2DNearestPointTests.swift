import Foundation
import Testing

@testable import OCCTSwift

// MARK: - #615: the 2D twin that #539/#580 never touched

/// #539 established that `GeomAPI_ProjectPointOnCurve::LowerDistance()` reports an extremum, which
/// on a bounded curve is neither necessarily the nearest point nor necessarily present at all, and
/// converted the 3D entry points onto a helper that takes the minimum over `ShapeAnalysis_Curve`,
/// every extremum in range, and both ends. The 2D twin was never touched at all, so every 2D
/// spelling, `Curve2D.project(point:)`, `Curve2D.project(_ point: Point2D)`,
/// `Point2D.distance(to:)` and `Curve2D.nearestParameter(to:)`, was wrong in both of the ways the
/// 3D side used to be. They agreed with each other, and with nothing else.
///
/// Measured on the 2D twin of #539's own repro geometry, a half circle of radius 5 queried from
/// below at `(0, -6)`:
///
/// | | before | after |
/// |---|---|---|
/// | `project(point:)` | point (0, 5), distance **11** | point (5, 0), distance 7.8102 |
/// | `project(point:)`, past the end of a segment | **nil** | the end |
/// | `Point2D.distance(to:)`, past the end | **`.infinity`** | the true distance |
///
/// There is no `ShapeAnalysis_Curve` in the 2D candidate set because OCCT has no 2D projection in
/// that class, its `Project` overloads take `Geom_Curve` or `Adaptor3d_Curve` only. So the 2D
/// helper is the extrema plus both ends, which is the row #580 measured at 188/189 rather than the
/// 189/189 the third source buys.
@Suite("Curve2D reports the nearest point over the range (#615)")
struct Issue615Curve2DNearestPointTests {

    /// A half circle of radius 5 over `[0, π]`: parameter `t` is the point `(5 cos t, 5 sin t)`.
    private static func halfCircle() -> Curve2D? {
        Curve2D.circle(center: .zero, radius: 5)?.trimmed(from: 0, to: .pi)
    }

    /// Domain `[3, 8]` along +X: the point at parameter `t` is `(t, 0)`.
    private static func trimmedSegment() -> Curve2D? {
        Curve2D.line(through: .zero, direction: SIMD2(1, 0))?.trimmed(from: 3, to: 8)
    }

    private static func distance(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let d = a - b
        return (d.x * d.x + d.y * d.y).squareRoot()
    }

    /// Defect 1, through all four spellings: the far side of the arc reported as the nearest point.
    ///
    /// The sole in-range extremum is the top of the arc at π/2, 11 away. The nearest point is the
    /// arc's own start at `(5, 0)`, 7.8102 away, and no extremum search will find it: it is an end.
    @Test("A half circle queried from below answers with the near end, not the far side")
    func halfCircleFromBelowAnswersTheNearEnd() throws {
        let arc = try #require(Self.halfCircle())
        let query = SIMD2<Double>(0, -6)
        let point2D = try #require(Point2D(x: query.x, y: query.y))
        let truth = 61.0.squareRoot()  // hypot(5, 6) = 7.810249675906654

        let projected = try #require(arc.project(point: query))
        #expect(abs(projected.distance - truth) < 1e-9)
        #expect(abs(projected.parameter - 0) < 1e-9)
        #expect(Self.distance(projected.point, SIMD2(5, 0)) < 1e-9)

        // Before #615 every one of these was 11, at point (0, 5) and parameter π/2.
        #expect(abs(point2D.distance(to: arc) - truth) < 1e-9)
        let asTuple = try #require(arc.project(point2D))
        #expect(abs(asTuple.distance - truth) < 1e-9)
        let scalar = try #require(arc.nearestParameter(to: query))
        #expect(abs(Self.distance(arc.point(at: scalar), query) - truth) < 1e-9)
    }

    /// A point on the full circle but not on this half of it. The extremum is the mirrored point at
    /// distance 10; the truth is the arc's start at 4.4721.
    @Test("A point on the circle but off the arc answers with the arc's end")
    func pointOnTheCircleButOffTheArc() throws {
        let arc = try #require(Self.halfCircle())
        let query = SIMD2<Double>(3, -4)

        let projected = try #require(arc.project(point: query))
        #expect(abs(projected.distance - 4.47213595499958) < 1e-9)
        #expect(Self.distance(projected.point, SIMD2(5, 0)) < 1e-9)
    }

    /// Defect 2: `nil` and `.infinity` where there is a perfectly good answer.
    ///
    /// A point past the end of a bounded curve has no perpendicular foot, so no extremum, but the
    /// end is right there, 92 away.
    @Test("A point past the end is answered, not refused")
    func pastTheEndIsAnswered() throws {
        let segment = try #require(Self.trimmedSegment())

        let beyond = try #require(segment.project(point: SIMD2(100, 0)))
        #expect(beyond.parameter == 8)
        #expect(beyond.distance == 92)
        #expect(Self.distance(beyond.point, SIMD2(8, 0)) < 1e-9)

        let before = try #require(segment.project(point: SIMD2(0, 0)))
        #expect(before.parameter == 3)
        #expect(before.distance == 3)

        #expect(segment.nearestParameter(to: SIMD2(100, 0)) == 8)
        #expect(segment.nearestParameter(to: SIMD2(0, 0)) == 3)

        // Point2D.distance(to:) mapped the bridge's negative sentinel to `.infinity`, so a point 92
        // units from a segment measured as infinitely far from it.
        let past = try #require(Point2D(x: 100, y: 0))
        #expect(past.distance(to: segment) == 92)
    }

    /// The property the issue is about, swept: the four spellings must not diverge from each other,
    /// and must land inside the curve's own domain rather than on its unbounded basis curve.
    @Test("All four nearest-point spellings agree on every query")
    func theFourSpellingsAgree() throws {
        let arc = try #require(Self.halfCircle())
        let segment = try #require(Self.trimmedSegment())
        let circle = try #require(Curve2D.circle(center: .zero, radius: 5))
        let line = try #require(Curve2D.line(through: .zero, direction: SIMD2(1, 0)))

        let cases: [(Curve2D, SIMD2<Double>, String)] = [
            (arc, SIMD2(0, -6), "half circle from below"),
            (arc, SIMD2(3, -4), "on the circle, off the arc"),
            (arc, SIMD2(0, 7), "above the arc, an ordinary foot"),
            (segment, SIMD2(5, 2), "an ordinary foot"),
            (segment, SIMD2(100, 0), "past the end"),
            (segment, SIMD2(0, 0), "before the start"),
            (circle, SIMD2(10, 0), "outside a closed curve"),
            (circle, SIMD2(0, 0), "a closed curve's centre, tied everywhere"),
            (line, SIMD2(5, 3), "an unbounded line"),
        ]

        for (curve, query, label) in cases {
            let point2D = try #require(Point2D(x: query.x, y: query.y), "\(label)")
            let projected = try #require(curve.project(point: query), "\(label)")
            let asTuple = try #require(curve.project(point2D), "\(label)")
            let scalar = try #require(curve.nearestParameter(to: query), "\(label)")

            #expect(projected.parameter == asTuple.parameter, "\(label)")
            #expect(projected.distance == asTuple.distance, "\(label)")
            #expect(projected.distance == point2D.distance(to: curve), "\(label)")
            #expect(scalar == projected.parameter, "\(label)")

            // The reported distance is the distance to the reported point, and the reported point is
            // where the reported parameter says it is. This is the sweep's only ground-truth anchor:
            // the four spellings above share one bridge path, so they would agree with each other
            // even if all four were wrong. It needs abs() for that reason, without it the
            // comparison is one-sided and passes for any reported distance LARGER than the truth,
            // which is the exact direction every defect in this issue erred in.
            #expect(
                abs(Self.distance(projected.point, query) - projected.distance) < 1e-9, "\(label)")
            #expect(Self.distance(curve.point(at: scalar), projected.point) < 1e-9, "\(label)")
            #expect(curve.domain.contains(scalar), "\(label): \(scalar) outside \(curve.domain)")
        }
    }

    /// The 2D answer must be the 3D answer for the same geometry in the z = 0 plane. This is the
    /// cross-check the two sides never had, and the reason the 2D defect survived #539: nothing
    /// compared them.
    @Test("The 2D and 3D answers match for the same geometry")
    func twoDAndThreeDMatch() throws {
        let arc2 = try #require(Self.halfCircle())
        let arc3 = try #require(
            Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)?.trimmed(
                from: 0, to: .pi))

        for query in [SIMD2<Double>(0, -6), SIMD2(3, -4), SIMD2(0, 7), SIMD2(-8, -1)] {
            let flat = try #require(arc2.project(point: query), "\(query)")
            let solid = arc3.projectPoint(SIMD3(query.x, query.y, 0))
            #expect(abs(flat.distance - solid.distance) < 1e-9, "\(query)")
            #expect(abs(flat.parameter - solid.parameter) < 1e-9, "\(query)")
        }
    }
}
