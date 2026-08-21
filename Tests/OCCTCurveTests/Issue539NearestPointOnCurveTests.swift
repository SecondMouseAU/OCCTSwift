import Testing
import Foundation
import simd
@testable import OCCTSwift

// MARK: - #539: the closest point on the curve you actually have

/// `Curve3D.projectPoint(_:precision:)` and `Edge.project(point:)` both promise the closest point,
/// and neither delivered it. They had picked a different OCCT call each, and each call is wrong in
/// its own way about a curve with ends:
///
/// - `ShapeAnalysis_Curve::Project`, behind the `Curve3D` side, solves on the *basis* curve for an
///   analytic type and reports a parameter outside the domain as though it were on the curve. A
///   segment trimmed to `[3, 8]` called `(100, 0, 0)` distance **0**, 92 units off the curve, and
///   a point on the full circle but off an arc read as distance 0 too. Passing the range explicitly
///   changed nothing: the 7-argument overload documents itself as *extending* the range.
///
/// - `GeomAPI_ProjectPointOnCurve`, behind the `Edge` side, honours the range but returns extrema
///   rather than minima. On a half circle the only extremum in range can be the far side, reported
///   as `LowerDistance`, and it finds nothing at all whenever the nearest point is an end, so a
///   point beyond the end of a straight edge came back `nil`.
///
/// Both now take the minimum over three candidate sources: whatever `ShapeAnalysis_Curve` found if
/// it landed inside the range, every extremum inside the range, and the ends themselves. Measured
/// correct on all 51 curve/point combinations swept for #539, against a dense brute-force sample.
///
/// A `distance < tolerance` proximity test was the caller this broke: every case below used to read
/// as "the point lies on the curve" or as no answer at all.
@Suite("The nearest point is on the curve, not on its basis (#539)")
struct Issue539NearestPointOnCurveTests {

    /// Domain `[3, 8]` along +X: the point at parameter `t` is `(t, 0, 0)`. The basis is an
    /// unbounded `Geom_Line`, which is what the old implementation answered about.
    private static func trimmedSegment() -> Curve3D? {
        Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0))?.trimmed(from: 3, to: 8)
    }

    /// Half of a circle of radius 5 in the XY plane, domain `[0, pi]`.
    private static func halfArc() -> Curve3D? {
        Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)?.trimmed(from: 0, to: .pi)
    }

    // MARK: The trimmed-range defect the issue was filed on

    @Test("A point past the end projects to the end, not onto the basis line")
    func pastTheEndProjectsToTheEnd() throws {
        let curve = try #require(Self.trimmedSegment())
        #expect(curve.domain == 3...8)

        // Was: parameter 100, distance 0.
        let beyond = curve.projectPoint(SIMD3(100, 0, 0))
        #expect(abs(beyond.parameter - 8) < 1e-9)
        #expect(abs(beyond.distance - 92) < 1e-9)
        #expect(simd_distance(beyond.point, SIMD3(8, 0, 0)) < 1e-9)

        // Was: parameter 0, distance 0. Parameter 0 is not even inside this curve's domain.
        let before = curve.projectPoint(.zero)
        #expect(abs(before.parameter - 3) < 1e-9)
        #expect(abs(before.distance - 3) < 1e-9)
        #expect(simd_distance(before.point, SIMD3(3, 0, 0)) < 1e-9)

        // Off to one side and past the start: the answer is the start point, not the perpendicular
        // foot at parameter -50. Was: distance 3.
        let offAxis = curve.projectPoint(SIMD3(-50, 3, 0))
        #expect(abs(offAxis.parameter - 3) < 1e-9)
        #expect(abs(offAxis.distance - (53 * 53 + 9).squareRoot()) < 1e-9)
    }

    /// The failure is not confined to points far away: a hair past the end used to read as exactly
    /// on the curve, which is the reading a proximity test acts on.
    @Test("A point just past the end is that far past it, not on the curve")
    func justPastTheEnd() throws {
        let curve = try #require(Self.trimmedSegment())
        let projected = curve.projectPoint(SIMD3(8.001, 0, 0))
        #expect(abs(projected.distance - 0.001) < 1e-9)   // was 0
        #expect(abs(projected.parameter - 8) < 1e-9)
    }

    /// An arc has the same defect in a form that needs no trimming to a strange domain to hit: any
    /// point on the underlying circle but outside the arc's own span read as distance 0.
    @Test("A point on the circle but off the arc is not on the arc")
    func onTheCircleButOffTheArc() throws {
        let arc = try #require(Self.halfArc())

        // (3, -4, 0) is exactly on the radius-5 circle, and exactly not on the upper half of it.
        // Was: distance 1.6e-15, i.e. reported as lying on the arc.
        let onCircle = arc.projectPoint(SIMD3(3, -4, 0))
        // The nearest point on the arc is its start, (5, 0, 0): sqrt(2^2 + 4^2) = 4.47214.
        #expect(abs(onCircle.distance - (2 * 2 + 4 * 4).squareRoot()) < 1e-6)
        #expect(abs(onCircle.parameter) < 1e-6)

        // Below the arc entirely: the nearest point is an end, 7.81 away. Was: distance 1, the
        // distance to the far half of the circle.
        let below = arc.projectPoint(SIMD3(0, -6, 0))
        #expect(abs(below.distance - (25.0 + 36.0).squareRoot()) < 1e-6)        // 7.81025
    }

    // MARK: The in-range maximum, which no clamp would have fixed

    /// On a parabola or hyperbola the one extremum inside the domain can be a *maximum*, so both
    /// old implementations answered with the worst point in range rather than the best. Nothing
    /// about the parameter is out of range here, this is why the fix takes a minimum over
    /// candidates rather than clamping the parameter into the domain.
    @Test("An in-range extremum that is a maximum does not win")
    func inRangeMaximumDoesNotWin() throws {
        // P(u) = (u^2/8, u, 0) over [0, 2]; from (20, 0, 0) the vertex at u=0 is a local maximum.
        let parabola = try #require(Curve3D.parabola(center: .zero, normal: SIMD3(0, 0, 1),
                                                     focal: 2))
        let arc = try #require(parabola.trimmed(from: 0, to: 2))
        let projected = arc.projectPoint(SIMD3(20, 0, 0))
        #expect(abs(projected.distance - 19.6023) < 1e-3)   // was 20, the distance to the vertex
        #expect(abs(projected.parameter - 2) < 1e-6)

        let hyperbola = try #require(Curve3D.hyperbola(center: .zero, normal: SIMD3(0, 0, 1),
                                                       majorRadius: 3, minorRadius: 2))
        let branch = try #require(hyperbola.trimmed(from: 0, to: 1))
        let far = branch.projectPoint(SIMD3(30, 0, 0))
        #expect(abs(far.distance - 25.4794) < 1e-3)         // was 27
    }

    // MARK: What deliberately did not change

    /// An ordinary projection onto a point that has a perpendicular foot inside the domain is the
    /// case every pre-#539 test used, and it answers exactly as it did.
    @Test("An ordinary in-range projection is unchanged")
    func ordinaryProjectionUnchanged() throws {
        let curve = try #require(Self.trimmedSegment())
        let projected = curve.projectPoint(SIMD3(5, 2, 0))
        #expect(abs(projected.parameter - 5) < 1e-9)
        #expect(abs(projected.distance - 2) < 1e-9)
        #expect(simd_distance(projected.point, SIMD3(5, 0, 0)) < 1e-9)

        let arc = try #require(Self.halfArc())
        let above = arc.projectPoint(SIMD3(0, 6, 0))
        #expect(abs(above.distance - 1) < 1e-6)
        #expect(abs(above.parameter - .pi / 2) < 1e-6)
    }

    /// A circle's centre has no perpendicular foot at all. `projectPoint` still answers, and the
    /// radius it answers with was already right, because the whole domain is in range.
    ///
    /// `nearestParameter(to:)` reported `nil` here until #615 routed it through the same helper;
    /// it now names one of the infinitely many tied nearest points, all at the radius.
    @Test("A closed curve, and a point with no perpendicular foot, still answer")
    func closedCurveStillAnswers() throws {
        let circle = try #require(Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5))
        let tied = try #require(circle.nearestParameter(to: .zero))
        #expect(abs(simd_length(circle.point(at: tied)) - 5) < 1e-9)

        let centre = circle.projectPoint(.zero)
        #expect(abs(centre.distance - 5) < 1e-9)
        #expect(abs(simd_length(centre.point) - 5) < 1e-9)

        let outside = circle.projectPoint(SIMD3(6, 0, 0))
        #expect(abs(outside.distance - 1) < 1e-9)
    }

    /// An unbounded curve has no ends to fall back on, and OCCT reports its domain as +/-2e100.
    /// Those sentinels must not be evaluated as candidate parameters.
    @Test("An unbounded curve projects as it always did")
    func unboundedCurveUnchanged() throws {
        let line = try #require(Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0)))
        let projected = line.projectPoint(SIMD3(100, 7, 0))
        #expect(abs(projected.parameter - 100) < 1e-9)
        #expect(abs(projected.distance - 7) < 1e-9)
        #expect(simd_distance(projected.point, SIMD3(100, 0, 0)) < 1e-9)
    }

    /// `distance(to:)` is a one-liner over `projectPoint`, so it inherits the fix rather than
    /// needing one of its own. Pinned because it is the spelling a proximity test reaches for.
    @Test("Curve3D.distance inherits the corrected projection")
    func curveDistanceInheritsTheFix() throws {
        let curve = try #require(Self.trimmedSegment())
        #expect(abs(curve.distance(to: SIMD3(100, 0, 0)) - 92) < 1e-9)   // was 0
        #expect(abs(curve.distance(to: .zero) - 3) < 1e-9)               // was 0
        #expect(abs(curve.distance(to: SIMD3(5, 2, 0)) - 2) < 1e-9)      // unchanged
    }

    // MARK: The Edge half, which had the same promise and the other defect

    private static func straightEdge() throws -> Edge {
        let wire = try #require(Wire.line(from: SIMD3(3, 0, 0), to: SIMD3(8, 0, 0)))
        return try #require(wire.edges().first)
    }

    private static func arcEdge() throws -> Edge {
        let wire = try #require(Wire.arc(center: .zero, radius: 5, startAngle: 0, endAngle: .pi))
        return try #require(wire.edges().first)
    }

    /// `Edge.project(point:)` used to return `nil` here, `isValid` false, because there is no
    /// perpendicular foot. Its own documentation reserves `nil` for an edge with no 3D curve.
    @Test("A point past the end of an edge gets the end, not nil")
    func edgePastTheEndIsNotNil() throws {
        let edge = try Self.straightEdge()

        let beyond = try #require(edge.project(point: SIMD3(100, 0, 0)))
        #expect(abs(beyond.distance - 92) < 1e-9)
        #expect(simd_distance(beyond.point, SIMD3(8, 0, 0)) < 1e-9)

        let before = try #require(edge.project(point: .zero))
        #expect(abs(before.distance - 3) < 1e-9)
        #expect(simd_distance(before.point, SIMD3(3, 0, 0)) < 1e-9)

        // The one-liner over it stops returning nil for the same reason.
        #expect(abs(try #require(edge.distance(to: SIMD3(100, 0, 0))) - 92) < 1e-9)
    }

    /// The extremum an edge-ranged `GeomAPI_ProjectPointOnCurve` finds on a half circle is the far
    /// side of it, and it was reported as the nearest point.
    @Test("An edge reports its nearest point, not its farthest extremum")
    func edgeReportsNearestNotFarthest() throws {
        let edge = try Self.arcEdge()

        let below = try #require(edge.project(point: SIMD3(0, -6, 0)))
        #expect(abs(below.distance - (25.0 + 36.0).squareRoot()) < 1e-6)   // 7.81025, was 11

        let insideBelow = try #require(edge.project(point: SIMD3(0, -1, 0)))
        #expect(abs(insideBelow.distance - (25.0 + 1.0).squareRoot()) < 1e-6)   // 5.09902, was 6

        // Still right where it was right.
        let above = try #require(edge.project(point: SIMD3(0, 6, 0)))
        #expect(abs(above.distance - 1) < 1e-6)
    }

    /// The two entry points promise the same thing about the same geometry, so they answer the same
    /// number. Before #539 they disagreed on every case above, in opposite directions.
    @Test("Curve3D and Edge agree on the same geometry")
    func curveAndEdgeAgree() throws {
        let edge = try Self.arcEdge()
        let arc = try #require(Self.halfArc())

        for point in [SIMD3<Double>(0, -6, 0), SIMD3(0, 6, 0), SIMD3(3, -4, 0),
                      SIMD3(0, -1, 0), SIMD3(6, 0, 0), .zero] {
            let viaEdge = try #require(edge.project(point: point), "\(point)")
            let viaCurve = arc.projectPoint(point)
            #expect(abs(viaEdge.distance - viaCurve.distance) < 1e-6, "\(point)")
            #expect(simd_distance(viaEdge.point, viaCurve.point) < 1e-6, "\(point)")
        }
    }

    /// An edge with no 3D curve is the one case `nil` is still for. Nothing in this suite's
    /// geometry produces one, so the contract is stated rather than exercised here; the closest
    /// available check is that every edge that does have a curve now answers.
    @Test("Every edge with a 3D curve answers")
    func everyEdgeWithACurveAnswers() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let probe = SIMD3<Double>(100, 100, 100)
        for edge in box.edges() {
            let projected = edge.project(point: probe)
            #expect(projected != nil)
            if let projected { #expect(projected.distance > 0) }
        }
    }
}
