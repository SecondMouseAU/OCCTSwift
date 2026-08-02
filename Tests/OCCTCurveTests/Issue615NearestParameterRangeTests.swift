import Testing
import Foundation
@testable import OCCTSwift

// MARK: - #615: the two point-to-curve spellings #539/#580 left disagreeing

/// #539 established that `GeomAPI_ProjectPointOnCurve::LowerDistance()` reports an extremum, which
/// on a bounded curve is neither necessarily the nearest point nor necessarily present at all, and
/// introduced `occtNearestPointOnCurveRange` — the minimum over `ShapeAnalysis_Curve`, every
/// extremum in range, and both ends. Three entry points were converted. The shared helper behind
/// `Curve3D.nearestParameter(to:)` and `Curve3D.locateNearestPoint`'s full-range fallback was not.
///
/// So the two spellings of the same question disagreed about **which** point is nearest and about
/// **whether there is one**. Measured on the geometry #539 itself used, a half circle of radius 5
/// queried from below at `(0, -6, 0)`:
///
/// | | before | after |
/// |---|---|---|
/// | `projectPoint` (converted by #539) | param 0, distance 7.8102 | unchanged |
/// | `nearestParameter` | param π/2, distance **11** | param 0, distance 7.8102 |
/// | `nearestParameter`, point past the end | **nil** | the end |
///
/// A caller seeding a trim or a split from `nearestParameter` landed on the opposite side of the arc
/// from where `projectPoint` said the nearest point was.
@Suite("nearestParameter reports the nearest point over the range (#615)")
struct Issue615NearestParameterRangeTests {

    /// #539's own repro geometry: a half circle of radius 5 over `[0, π]`, so parameter `t` is the
    /// point `(5 cos t, 5 sin t, 0)`. The arc lies in the upper half plane; a query from below has
    /// its nearest point at an end, and its only extremum at the far side.
    private static func halfCircle() -> Curve3D? {
        Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)?.trimmed(from: 0, to: .pi)
    }

    /// Domain `[3, 8]` along +X: the point at parameter `t` is `(t, 0, 0)`.
    private static func trimmedSegment() -> Curve3D? {
        Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0))?.trimmed(from: 3, to: 8)
    }

    private static func distance(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let d = a - b
        return (d.x * d.x + d.y * d.y + d.z * d.z).squareRoot()
    }

    /// Defect 1: the far side of the arc reported as the nearest point.
    ///
    /// The sole in-range extremum is the top of the arc at π/2, 11 away. The nearest point is the
    /// arc's own start at `(5, 0, 0)`, 7.8102 away, and no extremum search will ever find it because
    /// it is an end.
    @Test("A half circle queried from below answers with the near end, not the far side")
    func halfCircleFromBelowAnswersTheNearEnd() throws {
        let arc = try #require(Self.halfCircle())
        let query = SIMD3<Double>(0, -6, 0)
        let truth = 61.0.squareRoot()   // hypot(5, 6) = 7.810249675906654

        let parameter = try #require(arc.nearestParameter(to: query))
        #expect(abs(parameter - 0) < 1e-9)
        #expect(abs(Self.distance(arc.point(at: parameter), query) - truth) < 1e-9)

        // Before #615 this was π/2, whose point is 11 away — further from the query than the far
        // end of the arc is, and on the opposite side of it.
        #expect(Self.distance(arc.point(at: parameter), query) < 11)
    }

    /// The second row of #580's table, on the curve rather than the edge: a point that lies on the
    /// full circle but not on this half of it. The extremum is the mirrored point at distance 10.
    @Test("A point on the circle but off the arc answers with the arc's end")
    func pointOnTheCircleButOffTheArc() throws {
        let arc = try #require(Self.halfCircle())
        let query = SIMD3<Double>(3, -4, 0)

        let parameter = try #require(arc.nearestParameter(to: query))
        #expect(abs(Self.distance(arc.point(at: parameter), query) - 4.47213595499958) < 1e-9)
    }

    /// Defect 2: `nil` where the converted sibling answers.
    ///
    /// A point past the end of a bounded curve has no perpendicular foot, so no extremum — but it
    /// does have a nearest point, and `projectPoint` has reported it since #539.
    @Test("A point past the end is answered, not refused")
    func pastTheEndIsAnswered() throws {
        let segment = try #require(Self.trimmedSegment())

        #expect(segment.nearestParameter(to: SIMD3(100, 0, 0)) == 8)
        #expect(segment.nearestParameter(to: SIMD3(0, 0, 0)) == 3)
        #expect(segment.nearestParameter(to: SIMD3(-50, 3, 0)) == 3)
    }

    /// The property the issue is actually about: the two spellings must not disagree. Swept over
    /// both defect geometries plus an ordinary interior projection, an unbounded line and a full
    /// circle, so a future change that fixes one entry point and not the other fails here.
    @Test("nearestParameter and projectPoint agree on every query")
    func theTwoSpellingsAgree() throws {
        let arc = try #require(Self.halfCircle())
        let segment = try #require(Self.trimmedSegment())
        let circle = try #require(Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5))
        let line = try #require(Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0)))

        let cases: [(Curve3D, SIMD3<Double>, String)] = [
            (arc, SIMD3(0, -6, 0), "half circle from below"),
            (arc, SIMD3(3, -4, 0), "on the circle, off the arc"),
            (arc, SIMD3(0, 7, 0), "above the arc, an ordinary foot"),
            (segment, SIMD3(5, 2, 0), "an ordinary foot"),
            (segment, SIMD3(100, 0, 0), "past the end"),
            (segment, SIMD3(0, 0, 0), "before the start"),
            (circle, SIMD3(10, 0, 0), "outside a closed curve"),
            (line, SIMD3(5, 3, 0), "an unbounded line"),
        ]

        for (curve, query, label) in cases {
            let projected = curve.projectPoint(query)
            let parameter = try #require(curve.nearestParameter(to: query), "\(label)")

            // Same point, so same distance. Compared by distance rather than by parameter because a
            // tie (a closed curve queried from its centre) is free to name either of two parameters.
            #expect(abs(Self.distance(curve.point(at: parameter), query) - projected.distance) < 1e-9,
                    "\(label): nearestParameter \(parameter) vs projectPoint \(projected.parameter)")

            // And it is a real answer over the curve's own domain, not over its basis curve.
            #expect(curve.domain.contains(parameter), "\(label): \(parameter) outside \(curve.domain)")
        }
    }

    /// `Curve3D.locateNearestPoint(_:initParam:tolerance:)` shares the helper, and its full-range
    /// fallback inherited both defects. The fallback fires when the ±10% window around the guess
    /// holds no extremum — which is exactly the situation the guess was closest to being right in.
    ///
    /// Before #615, a guess sitting *on* the true nearest point returned the point diametrically
    /// opposite it.
    @Test("The locate-from-a-guess fallback answers over the whole curve, correctly")
    func locateFallbackIsCorrect() throws {
        let arc = try #require(Self.halfCircle())
        let query = SIMD3<Double>(0, -6, 0)
        let truth = 61.0.squareRoot()

        // Guess 0 is the true answer; the window [0, 0.314] holds no extremum, so this falls back.
        let atStart = try #require(arc.locateNearestPoint(query, initParam: 0))
        #expect(abs(atStart.parameter - 0) < 1e-9)
        #expect(abs(atStart.distance - truth) < 1e-9)

        // A bounded segment queried past its end has no extremum anywhere, so every guess falls
        // back. Before #615 the fallback found none either and the whole call returned nil.
        let segment = try #require(Self.trimmedSegment())
        for guess in [3.0, 5.5, 8.0] {
            let located = try #require(segment.locateNearestPoint(SIMD3(100, 0, 0), initParam: guess),
                                       "guess \(guess)")
            #expect(located.parameter == 8, "guess \(guess)")
            #expect(located.distance == 92, "guess \(guess)")
        }
    }

    /// The other half of that decision, pinned so it is not "fixed" by accident: the PRIMARY search
    /// is deliberately still windowed, and a windowed minimum can be a global maximum.
    ///
    /// It reports the lowest-distance extremum *inside* the ±10% window, not the extremum nearest
    /// the guess — `initParam` bounds the window, it does not rank what is found in it. With a guess
    /// of π/2 the window holds the far side of the arc, and that is what comes back: 11, not the
    /// global nearest 7.8102.
    ///
    /// Adding the window's ends to that minimum would answer 10.8657, still not 7.8102, and would
    /// make the fallback above unreachable, since a window's ends always evaluate. Making the search
    /// global outright would leave `initParam` meaning nothing and the function a duplicate of
    /// `nearestParameter(to:)`.
    @Test("The locate-from-a-guess primary search stays local, maxima included")
    func locatePrimarySearchStaysLocal() throws {
        let arc = try #require(Self.halfCircle())

        let atFarSide = try #require(arc.locateNearestPoint(SIMD3(0, -6, 0), initParam: .pi / 2))
        #expect(abs(atFarSide.parameter - .pi / 2) < 1e-9)
        #expect(abs(atFarSide.distance - 11) < 1e-9)
    }
}
