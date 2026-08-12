import Testing
import Foundation
@testable import OCCTSwift

/// #885: `ShapeMeasurements.totalFaceArea` (N independently-toleranced per-face
/// `BRepGProp::SurfaceProperties(face, props, Eps)` integrals, summed by `Shape.measure(linearTolerance:)`)
/// and `Shape.surfaceArea` / `Shape.surfaceInertiaProperties()?.mass` / `Shape.surfaceInertia?.area`
/// (one untunable, whole-shape `BRepGProp::SurfaceProperties(shape, props)` integral, shared by
/// all three) answer "total surface area" through two different OCCT overloads. The audit's own
/// question was whether to unify `totalFaceArea` onto the aggregate call or keep both, clearly
/// documented; this repo kept both (see the PR body for the tradeoffs) and pinned the measured
/// behavior here so the decision stays evidenced rather than assumed.
@Suite("Total surface area: two BRepGProp overloads can disagree (#885)")
struct Issue885TotalAreaDivergenceTests {

    /// A radius-10 sphere: one curved face, so `linearTolerance` has real integration work to do.
    /// A box's flat faces integrate exactly either way and would not discriminate the two paths.
    private func sphere() throws -> Shape {
        try #require(Shape.sphere(radius: 10))
    }

    // MARK: - The three whole-shape aggregates are one computation, not three

    /// `surfaceArea`, `surfaceInertiaProperties()?.mass` and `surfaceInertia?.area` all read the
    /// same `BRepGProp::SurfaceProperties(shape, props)` call (directly, or through the shared
    /// `occtSurfaceMassProperties` bridge helper), so they should be bit-identical. This is the
    /// premise every doc comment that says "these three are one number, `totalFaceArea` is a
    /// different one" relies on.
    @Test("surfaceArea, surfaceInertiaProperties, and surfaceInertia are the same number")
    func theThreeWholeShapeAggregatesAgree() throws {
        let s = try sphere()
        let sa = try #require(s.surfaceArea)
        let sip = try #require(s.surfaceInertiaProperties()?.mass)
        let si = try #require(s.surfaceInertia?.area)
        #expect(sa == sip)
        #expect(sa == si)
    }

    // MARK: - totalFaceArea and the aggregate diverge once linearTolerance leaves the adaptive regime

    /// At the default `linearTolerance` the two paths agree to double-precision noise on an
    /// ordinary shape. This is what makes the divergence easy to miss in normal use.
    @Test("at the default tolerance the two totals agree closely")
    func defaultToleranceAgreesClosely() throws {
        let s = try sphere()
        let total = s.measure().totalFaceArea
        let aggregate = try #require(s.surfaceArea)
        #expect(abs(total - aggregate) < 1e-6)
    }

    /// `BRepGProp::SurfaceProperties`'s own header documents that `Eps > 0.001` makes its adaptive
    /// integration "perform non-adaptive integration" instead. Past that boundary,
    /// `Face.area(tolerance:)` -- and so `ShapeMeasurements.totalFaceArea` -- can land on a
    /// meaningfully different number than the untunable aggregate, which never moves at all.
    /// Measured on this fixture: `totalFaceArea(linearTolerance: 0.5)` is ~1216.31 against the
    /// aggregate's fixed ~1256.64 (~3.2% apart) -- a real divergence, not floating-point noise.
    @Test("loosening past the adaptive/non-adaptive boundary makes the two totals genuinely diverge")
    func looseToleranceGenuinelyDiverges() throws {
        let s = try sphere()
        let total = s.measure(linearTolerance: 0.5).totalFaceArea
        let aggregate = try #require(s.surfaceArea)
        let diff = abs(total - aggregate)
        // 1.0 is a wide margin under the measured ~40.3 and far above any FP rounding.
        #expect(diff > 1.0)
    }

    /// `totalFaceArea` moves with `linearTolerance`; the three aggregates cannot, since none of
    /// them takes a tolerance parameter. A caller "fixing" a totalFaceArea/surfaceArea mismatch by
    /// tightening `linearTolerance` makes the two disagree *more*, not less, on any shape where
    /// they were not already exactly equal -- tightening only ever moves this one number.
    @Test("totalFaceArea itself moves with linearTolerance")
    func totalFaceAreaVariesWithTolerance() throws {
        let s = try sphere()
        let tight = s.measure(linearTolerance: 1e-9).totalFaceArea
        let loose = s.measure(linearTolerance: 0.5).totalFaceArea
        #expect(tight != loose)
    }
}
