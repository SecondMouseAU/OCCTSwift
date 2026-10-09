import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #1544: `Shape.distanceSS(to:deflection:)` defaulted `deflection` to `100.0`.
///
/// That value was forwarded verbatim as `BRepExtrema_DistanceSS`'s `theDeflection` constructor
/// argument. Per the pinned OCCT header (`BRepExtrema_DistanceSS.hxx`), that parameter is
/// "Maximum deviation of extreme distances from the minimum one (default is
/// `Precision::Confusion()`)", a numeric-tie tolerance, not a spatial search radius: after
/// finding the true minimum distance among all curve-curve extrema, the class appends to its
/// solution sequences *every* extremum within `deflection` of that minimum, not just the minimal
/// one. `distanceSS`'s ``DistanceSSResult/point1``/``DistanceSSResult/point2`` are
/// `Seq1Value().First()`/`Seq2Value().First()`, the *first-appended* solution, which need not be
/// the minimal extremum once more than one falls within `deflection`. At the old `100.0` default,
/// ``DistanceSSResult/distance`` correctly reported the true minimum while
/// ``DistanceSSResult/point1``/``DistanceSSResult/point2`` silently described a different,
/// non-minimal extremum.
///
/// Fixture: two coplanar circles, radius 10, centers 30 apart along X, each rotated by a
/// different amount around its own center (0.65 rad / 0.2 rad) so no curve-curve extremum lands
/// on either edge's closing vertex (`BRepExtrema_ExtCC` treats a closing-vertex-adjacent extremum
/// specially; ground-truth C++ probes confirmed both the raw `BRepExtrema_ExtCC` extrema list and
/// `BRepExtrema_DistanceSS`'s behavior directly against `libOCCT-macos.a` before writing this
/// test, see the issue's own reproducer). `BRepExtrema_ExtCC` on this pair reports four extrema,
/// at distances 30, 50, 10 and 30 (`ExtremaExtCCTests`-style: near side 10, far side 50, two
/// tangential sides 30 each). Only the distance-10 extremum is the true minimum.
@Suite("Issue #1544: distanceSS(to:deflection:) default near Precision::Confusion()")
struct Issue1544DistanceSSDeflectionDefaultTests {

    /// Builds the two-circle fixture edges described above.
    private func multiExtremaEdges() -> (Shape, Shape)? {
        guard
            let c1 = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 10),
            let c2 = Curve3D.circle(center: SIMD3(30, 0, 0), normal: SIMD3(0, 0, 1), radius: 10)
        else { return nil }
        // Rotate each circle around its own center so neither's closing vertex sits at a
        // curve-curve extremum; the two angles are deliberately different so the vertices don't
        // land at coincident absolute positions either.
        guard c1.rotate(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1), angle: 0.65),
            c2.rotate(axisOrigin: SIMD3(30, 0, 0), axisDirection: SIMD3(0, 0, 1), angle: 0.2)
        else { return nil }
        guard let e1 = Shape.edgeFromCurve(c1), let e2 = Shape.edgeFromCurve(c2) else {
            return nil
        }
        return (e1, e2)
    }

    @Test("default deflection: point1/point2 correspond to the true minimum, not just distance")
    func defaultDeflectionReturnsTrueMinimumPoints() throws {
        let (e1, e2) = try #require(multiExtremaEdges())

        let r = e1.distanceSS(to: e2)

        #expect(r.isDone)
        // At ~Precision::Confusion(), only the distance-10 extremum is within tolerance of
        // itself, so exactly one solution should be reported.
        #expect(r.solutionCount == 1)
        #expect(abs(r.distance - 10) < 1e-6)

        let actualPointDistance = simd_distance(r.point1, r.point2)
        #expect(abs(actualPointDistance - 10) < 1e-6)
        #expect(
            abs(r.distance - actualPointDistance) < 1e-6,
            "point1/point2 must describe the SAME extremum distance reports")
    }

    @Test("deflection: 100.0 (the old default) returns a non-minimal extremum as point1/point2")
    func explicitOldDeflectionReturnsNonMinimalExtremum() throws {
        let (e1, e2) = try #require(multiExtremaEdges())

        // Simulates the pre-#1544 default by passing it explicitly: BRepExtrema_DistanceSS is
        // asked to fold in every extremum within 100 units of the true minimum, which is all
        // four (30, 50, 10, 30), not just the minimal one.
        let r = e1.distanceSS(to: e2, deflection: 100.0)

        #expect(r.isDone)
        #expect(r.solutionCount == 3)
        // distance still correctly reports the true minimum...
        #expect(abs(r.distance - 10) < 1e-6)
        // ...but point1/point2 (the first-appended solution) describe a farther extremum,
        // demonstrably NOT the pair distance reports. This is documenting BRepExtrema_DistanceSS's
        // own (unfixed, un-fixable at the bridge layer) solution-ordering behavior for a caller
        // who explicitly opts into a wide deflection, not a regression this issue introduces.
        let actualPointDistance = simd_distance(r.point1, r.point2)
        #expect(abs(actualPointDistance - 30) < 1e-6)
        #expect(abs(actualPointDistance - r.distance) > 1)
    }
}
