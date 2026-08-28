import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #413/#500: the five point-to-curve projection entry points

/// The same `Geom2dAPI_ProjectPointOnCurve` computation is reachable five ways:
/// `Curve2D.project(point:)`, `Curve2D.allProjections(of:)`, `Curve2D.project(_ point: Point2D)`,
/// `Point2D.distance(to:)` and `Curve2D.nearestParameter(to:)`. They were five independent
/// constructions with five different failure conventions bolted on separately, including one
/// (`Point2D.distance(to:)`) that leaked the bridge's raw `-1` sentinel to callers as though it
/// were a distance, and one (`Curve2D.parameterAtPoint(_:)`, now deprecated) that #413 missed
/// entirely and that answered with the curve's own `firstParameter`. They now share one bridge
/// path and agree on both the values and on when there is no projection.
@Suite("Curve2D projection entry points agree (#413)")
struct Curve2DProjectionParityTests {

    private static let segment = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!

    @Test("All five entry points agree for an ordinary projection")
    func successAgreesAcrossAllFive() {
        let cases: [(Curve2D, SIMD2<Double>)] = [
            (Self.segment, SIMD2(5, 3)),
            (Self.segment, SIMD2(0.5, -2)),
            (Curve2D.circle(center: .zero, radius: 5)!, SIMD2(10, 0)),
            (Curve2D.circle(center: .zero, radius: 5)!, SIMD2(3, 4)),
        ]
        for (curve, p) in cases {
            guard let point2D = Point2D(x: p.x, y: p.y) else { continue }
            let comment: Comment = "\(p)"

            let nearest = curve.project(point: p)
            let asTuple = curve.project(point2D)
            let distance = point2D.distance(to: curve)
            let all = curve.allProjections(of: p)
            let scalar = curve.nearestParameter(to: p)

            #expect(nearest != nil, comment)
            #expect(asTuple != nil, comment)
            #expect(scalar != nil, comment)
            guard let nearest, let asTuple else { continue }

            #expect(nearest.parameter == asTuple.parameter, comment)
            #expect(nearest.distance == asTuple.distance, comment)
            #expect(nearest.distance == distance, comment)
            #expect(scalar == nearest.parameter, comment)

            // The nearest solution must be the smallest of the full solution set.
            #expect(!all.isEmpty, comment)
            if let smallest = all.map(\.distance).min() {
                #expect(abs(smallest - nearest.distance) < 1e-9, comment)
            }
        }
    }

    /// A point with no *perpendicular foot* — one beyond the ends of a bounded curve, or a circle's
    /// centre (equidistant everywhere, so no local minimum) — still has a nearest point, and since
    /// #615 the four nearest-point spellings all report it rather than reporting nothing.
    ///
    /// `allProjections(of:)` is the one that still reports nothing, and correctly: it asks for the
    /// extrema, which is a different question, and here there are none. Before #615 all five agreed
    /// only because the other four were asking the extrema question too.
    @Test("The four nearest-point entry points agree where there is no perpendicular foot")
    func noPerpendicularFootAgreesAcrossTheFour() throws {
        let cases: [(Curve2D, SIMD2<Double>, Double)] = [
            (Self.segment, SIMD2(100, 0), 90),  // past the end, nearest is (10, 0)
            // Before the start, nearest is (0, 0)
            (Self.segment, SIMD2(-50, 3), 2509.0.squareRoot()),
            (Curve2D.circle(center: .zero, radius: 5)!, SIMD2(0, 0), 5),  // centre: tied at r
        ]
        for (curve, p, truth) in cases {
            let point2D = try #require(Point2D(x: p.x, y: p.y))
            let comment: Comment = "\(p)"

            let nearest = try #require(curve.project(point: p), comment)
            let asTuple = try #require(curve.project(point2D), comment)
            let scalar = try #require(curve.nearestParameter(to: p), comment)
            let distance = point2D.distance(to: curve)

            #expect(abs(nearest.distance - truth) < 1e-4, comment)
            #expect(nearest.parameter == asTuple.parameter, comment)
            #expect(nearest.distance == asTuple.distance, comment)
            #expect(nearest.distance == distance, comment)
            #expect(scalar == nearest.parameter, comment)

            // Never the old sentinels: `.infinity` from Point2D.distance(to:) was a real distance
            // thrown away, and -1 underneath it reads as "touching" to a `distance < tolerance` test.
            #expect(distance.isFinite, comment)
            #expect(distance > 0, comment)

            // The extrema question is genuinely unanswerable here, and still says so.
            #expect(curve.allProjections(of: p).isEmpty, comment)
        }
    }

    /// Parameter 0 is a legitimate success value, which is why no entry point may signal failure
    /// through the parameter alone. Projecting a segment's own start point onto it returns
    /// exactly 0 at distance 0.
    @Test("Parameter zero is a success, not a failure signal")
    func parameterZeroIsASuccess() {
        guard let start = Point2D(x: 0, y: 0) else { return }
        let asTuple = Self.segment.project(start)
        #expect(asTuple != nil)
        if let asTuple {
            #expect(asTuple.parameter == 0)
            #expect(asTuple.distance == 0)
        }
        let nearest = Self.segment.project(point: SIMD2(0, 0))
        #expect(nearest?.parameter == 0)
        #expect(nearest?.distance == 0)
        #expect(start.distance(to: Self.segment) == 0)
        #expect(Self.segment.nearestParameter(to: SIMD2(0, 0)) == 0)
    }
}
