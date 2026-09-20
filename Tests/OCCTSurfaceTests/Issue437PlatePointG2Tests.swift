import Testing
import simd

@testable import OCCTSwift

/// #437: `GeomPlate_PointConstraint`'s point constructor throws above order 1, and a bare point
/// carries no curvature to match, so `.g2` can never work for a *point* constraint. Cluster D's
/// census (#513/#667) measured this as a genuine instance of the shared root: `SurfaceContinuity`'s
/// raw value is forwarded as a literal `GeomPlate_PointConstraint`/`CurveConstraint` order with no
/// `GeomAbs_Shape` decode step at all.
///
/// Fixed by rejecting `.g2` for a point constraint in Swift, before any `GeomPlate_PointConstraint`
/// is built, rather than relying on OCCT's own throw (caught by the bridge's `catch (...)`) to
/// produce the same `nil` by accident. `GeomPlate_CurveConstraint` has no such restriction (it
/// accepts order 2 directly), so only point orders are checked; curve orders are untouched.
///
/// **#1460 extended this same guard to also reject `.g1`** for a point constraint (a bare point
/// cannot carry tangent data either, and OCCT never threw for `.g1` the way it does for `.g2`, so
/// the pre-#1460 behavior was a silent G0-only build, not a diagnostic). That means several
/// assertions below that used to read "`.g1` still builds" now read "`.g1` is also rejected";
/// each is annotated where it changed. See `Issue1460PlatePointG1Tests` for that guard's own
/// dedicated coverage and prove-the-test-fails matrix. Unlike `.g2` here, the `.g1` guard is
/// NOT decorative, since OCCT's own constructor never rejects order 1.
///
/// ## Prove-the-test-fails: what actually caught the injected defects, and what didn't
///
/// Measured, not assumed (`okf/policies/prove-the-test-fails.md`): every `.g2`-on-a-point input
/// reachable through the public API was **already** `nil` before this fix, because OCCT's own
/// throw is caught by the bridge's blanket `catch (...)`. That means the public-contract tests
/// below (`allG2Rejected`, `oneG2AmongValidOrdersRejected`, `mixedPointG2RejectedAlongsideValidCurve`,
/// plus the pre-existing `Issue398ContinuityTests` pair) **stayed green when the new Swift-side
/// guard was removed and re-tested**, confirmed by literally deleting each guard clause in turn,
/// rebuilding, and re-running this suite. They still pin a real contract (the public answer must
/// stay `nil`), so they are kept, but they do not by themselves prove the new mechanism exists;
/// they are labelled below rather than counted as such. Only `pointConstraintSupport` and
/// `mixedGuardIgnoresCurveOrders`, which call the new pure-Swift guards directly, went red when
/// the guards they cover were broken.
///
/// After the automated review on PR #719 pointed out the point-order rejection check was
/// implemented twice (inline in `plateSurface(through:orders:)`, and again in
/// `plateMixedRejectsPointOrders`), both were consolidated onto one shared
/// `Shape.plateRejectsPointOrders(_:)`. `sharedPointOrderGuardIsUnified` exercises that function
/// directly and goes red when it is forced to always return `false`.
/// `mixedGuardIgnoresCurveOrders` also goes red under that same injection, transitively through
/// `plateMixedRejectsPointOrders`. `allG2Rejected`/`oneG2AmongValidOrdersRejected` do **not**:
/// forcing `plateRejectsPointOrders` to `false` only removes the Swift-side rejection, and the
/// `.g2` orders those two tests use still reach `GeomPlate_PointConstraint` and throw there,
/// caught by the bridge into the same `nil`, measured rather than assumed, same as the
/// guard-clause deletion below.
///
/// | case | guard broken | result |
/// |---|---|---|
/// | `pointConstraintSupport` | `isUnsupportedForPointConstraint` forced to `false` | **red** |
/// | `mixedGuardIgnoresCurveOrders` | same (transitively) | **red** |
/// | `mixedGuardIgnoresCurveOrders` | `plateMixedRejectsPointOrders` forced to `false` | **red** |
/// | `mixedGuardIgnoresCurveOrders` | `plateRejectsPointOrders` forced to `false` | **red** (transitively) |
/// | `sharedPointOrderGuardIsUnified` | `plateRejectsPointOrders` forced to `false` | **red** |
/// | `allG2Rejected` | `plateRejectsPointOrders` forced to `false` | green (OCCT's own throw still catches `.g2`) |
/// | `oneG2AmongValidOrdersRejected` | same | green (same reason) |
/// | `allG2Rejected` | `plateSurface(through:orders:)`'s guard clause deleted | green (decorative for this guard) |
/// | `oneG2AmongValidOrdersRejected` | same | green (decorative) |
/// | `g0StillBuilds` | same | green (never touches `.g2`, unaffected either way) |
/// | `mixedPointG2RejectedAlongsideValidCurve` | `plateSurface(pointConstraints:curveConstraints:)`'s guard clause deleted | green (decorative for this guard) |
/// | `mixedPointG0StillBuilds` | same | green (never touches `.g2`, unaffected either way) |
/// | `Issue398ContinuityTests.plateThroughPointsRejectsCurvatureOrder` | `isUnsupportedForPointConstraint` forced to `false` | green (decorative for the `.g2` half, red for the `.g1` half added by #1460) |
/// | `Issue398ContinuityTests.plateThroughPointsRejectsMixedCurvatureOrder` | same | green (decorative, pre-existing, still only exercises `.g2`) |
///
/// **#1460 note**: `pointConstraintSupport` and `mixedGuardIgnoresCurveOrders` above now assert
/// the current (post-#1460) behavior, so "forced to `false`" also catches the `.g1` half added by
/// that fix; it is one injection covering both guards because they are the same shared property.
/// `Issue1460PlatePointG1Tests` isolates the `.g1` half on its own, with an injection that reverts
/// only that half (`self == .g2`) and leaves `.g2`'s rejection intact.
@Suite("Plate point constraint G2 domain restriction (#437)")
struct Issue437PlatePointG2Tests {

    private let pentagon: [SIMD3<Double>] = [
        SIMD3(0, 0, 0), SIMD3(10, 0, 1), SIMD3(10, 10, 2), SIMD3(0, 10, 1), SIMD3(5, 5, 3),
    ]

    // `try #require` rather than force-unwrap: a nil here should fail the one test that asked
    // for it, not abort the whole `swift test` binary and silently discard every other suite's
    // results in the same run.
    private func rectangleWire() throws -> Wire {
        try #require(
            Wire.path(
                [SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0)],
                closed: true))
    }

    // MARK: - The guards themselves: these are the tests that actually prove the mechanism

    // #1460: only g0 is supported for a point constraint now; g1 joined g2 as rejected (a bare
    // point cannot carry tangent data any more than it can carry curvature).
    @Test("Only g0 is supported for a point constraint; g1 and g2 are not")
    func pointConstraintSupport() {
        #expect(!SurfaceContinuity.g0.isUnsupportedForPointConstraint)
        #expect(SurfaceContinuity.g1.isUnsupportedForPointConstraint)
        #expect(SurfaceContinuity.g2.isUnsupportedForPointConstraint)
    }

    // `GeomPlate_CurveConstraint` (unlike the point constructor) accepts order 2 directly, so a
    // curve .g2 constraint must never be rejected by this guard. Proving that by actually
    // building a curve .g2 plate surface would conflate two different questions: whether the
    // guard inspected `curves` (an encoding question, #437's own claim) and whether
    // `GeomPlate_BuildPlateSurface`'s solver converges at G2 on a given wire (a tolerance/geometry
    // question the census already found separate and fixture-dependent, measured nil on both a
    // circle and this suite's own rectangle wire when tried here). So this tests
    // `plateMixedRejectsPointOrders` directly: its signature takes no `curves` parameter at all,
    // which makes "curve orders cannot affect this decision" a fact about the function's shape,
    // not its convergence luck.
    @Test("The mixed-constraint guard's decision depends only on point orders")
    func mixedGuardIgnoresCurveOrders() {
        #expect(!Shape.plateMixedRejectsPointOrders([]))
        #expect(!Shape.plateMixedRejectsPointOrders([(point: SIMD3(0, 0, 0), order: .g0)]))
        // #1460: g1 joined g2 as rejected for a point constraint.
        #expect(Shape.plateMixedRejectsPointOrders([(point: SIMD3(0, 0, 0), order: .g1)]))
        #expect(Shape.plateMixedRejectsPointOrders([(point: SIMD3(0, 0, 0), order: .g2)]))

        // One g2 among several otherwise-valid (g0) points still poisons the batch.
        let mixed: [(point: SIMD3<Double>, order: SurfaceContinuity)] = [
            (point: SIMD3(0, 0, 0), order: .g0),
            (point: SIMD3(1, 0, 0), order: .g0),
            (point: SIMD3(0, 1, 0), order: .g2),
        ]
        #expect(Shape.plateMixedRejectsPointOrders(mixed))
    }

    // Both entry points' rejection checks (`plateSurface(through:orders:)`'s inline guard and
    // `plateMixedRejectsPointOrders`, above) now defer to this one function rather than each
    // re-testing `isUnsupportedForPointConstraint` independently, which is the consolidation
    // the automated review on PR #719 asked for. Exercised directly, and against a plain array
    // (`plateSurface(through:orders:)`'s shape) rather than the tuple array
    // `plateMixedRejectsPointOrders` covers above, so this is not just a copy of that test.
    @Test("The shared point-order guard is the one implementation both entry points defer to")
    func sharedPointOrderGuardIsUnified() {
        #expect(!Shape.plateRejectsPointOrders([SurfaceContinuity]()))
        #expect(!Shape.plateRejectsPointOrders([SurfaceContinuity.g0, .g0]))
        // #1460: g1 alone (no g2 present) is now enough to poison the batch too.
        #expect(Shape.plateRejectsPointOrders([SurfaceContinuity.g0, .g1]))
        #expect(Shape.plateRejectsPointOrders([SurfaceContinuity.g0, .g2, .g1]))
    }

    // MARK: - Public contract: plateSurface(through:orders:)
    //
    // These pin the observable answer (still `nil` for a point .g2, as it was before this PR),
    // labelled per the class comment above: measured to stay green with the new guard deleted,
    // because OCCT's own throw is already caught by the bridge. Kept as contract tests, not as
    // proof of the new mechanism.

    @Test("All-g2 orders are rejected")
    func allG2Rejected() {
        let orders = Array(repeating: SurfaceContinuity.g2, count: pentagon.count)
        #expect(Shape.plateSurface(through: pentagon, orders: orders) == nil)
    }

    @Test("A single g2 among otherwise-valid orders poisons the whole call")
    func oneG2AmongValidOrdersRejected() {
        var orders: [SurfaceContinuity] = Array(repeating: .g0, count: pentagon.count)
        orders[2] = .g2
        #expect(Shape.plateSurface(through: pentagon, orders: orders) == nil)
    }

    // #1460 renamed this from `g0AndG1StillBuild`: g1 no longer builds for a point constraint,
    // see `Issue1460PlatePointG1Tests` for that half.
    @Test("g0 orders still build")
    func g0StillBuilds() {
        let g0 = Shape.plateSurface(
            through: pentagon, orders: Array(repeating: .g0, count: pentagon.count))
        #expect(g0 != nil)
    }

    // MARK: - Public contract: plateSurface(pointConstraints:curveConstraints:)
    //
    // Same labelling as the section above: contract tests, not proof of the mechanism.

    @Test("A g2 point constraint is rejected even alongside otherwise-valid curve constraints")
    func mixedPointG2RejectedAlongsideValidCurve() throws {
        let shape = Shape.plateSurface(
            pointConstraints: [(point: SIMD3(5, 5, 3), order: .g2)],
            curveConstraints: [(wire: try rectangleWire(), order: .g0)]
        )
        #expect(shape == nil)
    }

    // #1460 renamed this from `mixedPointG0G1StillBuild`: its body only ever built a g0 point (a
    // g1 point alongside the curve constraint is now covered by `Issue1460PlatePointG1Tests`
    // instead, where it belongs).
    @Test("A g0 point constraint alongside a curve constraint still builds")
    func mixedPointG0StillBuilds() throws {
        let g0 = Shape.plateSurface(
            pointConstraints: [(point: SIMD3(5, 5, 3), order: .g0)],
            curveConstraints: [(wire: try rectangleWire(), order: .g0)]
        )
        #expect(g0 != nil)
    }
}
