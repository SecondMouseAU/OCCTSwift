import Foundation
import Testing

@testable import OCCTSwift

// MARK: - #500: the 3D side of the point-to-curve projection family

/// #413 gave the 2D side one `Geom2dAPI_ProjectPointOnCurve` construction behind every entry point
/// that wants the nearest solution. The 3D side never got the equivalent: `Curve3D.parameterAtPoint`
/// and `Curve3D.closestParameter(to:)` each built their own `GeomAPI_ProjectPointOnCurve`, ran the
/// identical computation, and then disagreed about how to report that there wasn't one, the first
/// answering with the curve's `firstParameter`, the second with `0`.
///
/// The disagreement is invisible on the curves the old tests used, which is how it survived: both
/// answer `0` whenever `firstParameter` happens to be `0`, as it is for a line, a circle, and a
/// segment built from two points. It takes a curve trimmed to a domain that does not start at zero
/// to separate them, and then `closestParameter`'s `0` is not merely ambiguous, it is outside the
/// curve's own domain.
@Suite("Curve3D nearest-parameter entry points agree (#500)")
struct Issue500Curve3DNearestParameterTests {

    @Test("An ordinary projection returns the real parameter")
    func ordinaryProjection() throws {
        let curve = try #require(trimmedSegment())
        #expect(curve.domain == 3...8)
        #expect(curve.nearestParameter(to: SIMD3(5, 2, 0)) == 5)
        #expect(curve.nearestParameter(to: SIMD3(3, 4, 0)) == 3)  // the start point itself
        #expect(curve.nearestParameter(to: SIMD3(8, -1, 0)) == 8)  // the end point itself
    }

    /// A point beyond the ends of a bounded curve has no perpendicular foot, which is not the same
    /// as having no nearest point: the nearest point is the end it fell off.
    ///
    /// Until #615 this returned `nil` for all three, because the shared helper reported
    /// `GeomAPI_ProjectPointOnCurve`'s extrema and there are none. `projectPoint(_:precision:)`,
    /// converted by #539, answered 8 and 3 for the same curve and the same points the whole time.
    @Test("A point past the end answers with the end, not nil")
    func pastTheEndAnswersWithTheEnd() throws {
        let curve = try #require(trimmedSegment())
        #expect(curve.nearestParameter(to: SIMD3(100, 0, 0)) == 8)
        #expect(curve.nearestParameter(to: SIMD3(0, 0, 0)) == 3)
        #expect(curve.nearestParameter(to: SIMD3(-50, 3, 0)) == 3)
    }

    /// A circle's centre is equidistant from every point on it, so there is no local minimum to
    /// find, but every point on it is a nearest point, all at the radius. Since #615 that is what
    /// comes back, matching `projectPoint(_:precision:)`, which has reported it since #539.
    @Test("A circle's centre answers with a tied nearest point at the radius")
    func circleCentreAnswersAtTheRadius() throws {
        let circle = try #require(Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5))
        let parameter = try #require(circle.nearestParameter(to: .zero))
        let onCurve = circle.point(at: parameter)
        #expect(abs((onCurve.x * onCurve.x + onCurve.y * onCurve.y).squareRoot() - 5) < 1e-9)
        #expect(abs(circle.projectPoint(.zero).distance - 5) < 1e-9)
        #expect(circle.nearestParameter(to: SIMD3(3, 4, 0)) != nil)  // on the circle: fine
    }

    /// `projectPoint(_:precision:)` reaches the answer by a different route, `ShapeAnalysis_Curve`
    /// is in its candidate set and not in this one, but since #615 it is the same answer. The two
    /// used to differ on both questions a projection asks: #539 converted `projectPoint` and left
    /// this spelling reporting an extremum, so on a point past the end one said 8 and the other said
    /// there was no such point at all.
    @Test("projectPoint and nearestParameter now agree")
    func projectPointAndNearestParameterAgree() throws {
        let curve = try #require(trimmedSegment())
        let p = SIMD3<Double>(100, 0, 0)

        let projected = curve.projectPoint(p)
        #expect(projected.parameter == 8)
        #expect(projected.distance == 92)
        #expect(curve.nearestParameter(to: p) == projected.parameter)
    }
}
