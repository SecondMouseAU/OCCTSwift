import Testing
import Foundation
@testable import OCCTSwift

// MARK: - #500: the 3D side of the point-to-curve projection family

/// #413 gave the 2D side one `Geom2dAPI_ProjectPointOnCurve` construction behind every entry point
/// that wants the nearest solution. The 3D side never got the equivalent: `Curve3D.parameterAtPoint`
/// and `Curve3D.closestParameter(to:)` each built their own `GeomAPI_ProjectPointOnCurve`, ran the
/// identical computation, and then disagreed about how to report that there wasn't one — the first
/// answering with the curve's `firstParameter`, the second with `0`.
///
/// The disagreement is invisible on the curves the old tests used, which is how it survived: both
/// answer `0` whenever `firstParameter` happens to be `0`, as it is for a line, a circle, and a
/// segment built from two points. It takes a curve trimmed to a domain that does not start at zero
/// to separate them — and then `closestParameter`'s `0` is not merely ambiguous, it is outside the
/// curve's own domain.
@Suite("Curve3D nearest-parameter entry points agree (#500)")
struct Issue500Curve3DNearestParameterTests {

    /// Domain `[3, 8]` along +X: the point at parameter `t` is `(t, 0, 0)`.
    private static func trimmedSegment() -> Curve3D? {
        Curve3D.line(through: .zero, direction: SIMD3(1, 0, 0))?.trimmed(from: 3, to: 8)
    }

    @Test("An ordinary projection returns the real parameter")
    func ordinaryProjection() throws {
        let curve = try #require(Self.trimmedSegment())
        #expect(curve.domain == 3...8)
        #expect(curve.nearestParameter(to: SIMD3(5, 2, 0)) == 5)
        #expect(curve.nearestParameter(to: SIMD3(3, 4, 0)) == 3)     // the start point itself
        #expect(curve.nearestParameter(to: SIMD3(8, -1, 0)) == 8)    // the end point itself
    }

    /// A point beyond the ends of a bounded curve has no extremum, so no projection. This is the
    /// case the two old spellings answered differently, and neither answer was reportable.
    @Test("No projection is nil, not a parameter from either old convention")
    func noProjectionIsNil() throws {
        let curve = try #require(Self.trimmedSegment())
        for p in [SIMD3<Double>(100, 0, 0), SIMD3(0, 0, 0), SIMD3(-50, 3, 0)] {
            #expect(curve.nearestParameter(to: p) == nil, "\(p)")
        }
    }

    /// A circle's centre is equidistant from every point on it, so there is no local minimum to
    /// find. The 2D parity suite uses the same case (#413).
    @Test("A circle's centre has no projection")
    func circleCentreHasNoProjection() throws {
        let circle = try #require(Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5))
        #expect(circle.nearestParameter(to: .zero) == nil)
        #expect(circle.nearestParameter(to: SIMD3(3, 4, 0)) != nil)   // on the circle: fine
    }

    /// Both deprecated spellings now route through the one implementation, so they agree with each
    /// other and with `nearestParameter(to:)` — including on the no-projection case, where they
    /// report `.nan`. `.nan` is the only `Double` that is not a legitimate parameter on some curve.
    @Test("The two deprecated spellings agree with each other and with nearestParameter")
    @available(*, deprecated, message: "exercises the deprecated spellings on purpose")
    func deprecatedSpellingsAgree() throws {
        let curve = try #require(Self.trimmedSegment())

        // Where there is a projection, all three give the same real parameter.
        #expect(curve.nearestParameter(to: SIMD3(5, 2, 0)) == 5)
        #expect(curve.parameterAtPoint(SIMD3(5, 2, 0)) == 5)
        #expect(curve.closestParameter(to: SIMD3(5, 2, 0)) == 5)

        // Where there is none, the scalar spellings say so instead of inventing a parameter.
        // Before #500: parameterAtPoint returned 3 (firstParameter) and closestParameter
        // returned 0 — a value not even inside this curve's [3, 8] domain.
        for p in [SIMD3<Double>(100, 0, 0), SIMD3(0, 0, 0)] {
            #expect(curve.nearestParameter(to: p) == nil, "\(p)")
            #expect(curve.parameterAtPoint(p).isNaN, "\(p)")
            #expect(curve.closestParameter(to: p).isNaN, "\(p)")
        }
    }

    /// `projectPoint(_:precision:)` is deliberately *not* part of this family, and asks a different
    /// question: the nearest point on the curve, which exists for every point, rather than the
    /// nearest *perpendicular foot*, which does not. Pinned here so a later pass does not "unify"
    /// two entry points that genuinely compute different things.
    ///
    /// When #500 shipped, its answer here was parameter 100, distance 0 — it projected onto the
    /// curve's underlying unbounded line, recorded as-is rather than asserted correct. #539 fixed
    /// that: the answer is now the curve's own end. The contracts still differ, but only in whether
    /// a point with no perpendicular foot gets an answer, not in whether the answer is true.
    @Test("projectPoint runs a different algorithm and keeps its own contract")
    func projectPointIsADifferentAlgorithm() throws {
        let curve = try #require(Self.trimmedSegment())
        let p = SIMD3<Double>(100, 0, 0)

        #expect(curve.nearestParameter(to: p) == nil)

        // It answers where nearestParameter does not, with the end of the curve (#539).
        let projected = curve.projectPoint(p)
        #expect(projected.parameter == 8)
        #expect(projected.distance == 92)
    }
}
