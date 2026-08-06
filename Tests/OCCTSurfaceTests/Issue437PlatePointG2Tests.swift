import Testing
import simd
@testable import OCCTSwift

/// #437: `GeomPlate_PointConstraint`'s point constructor throws above order 1 -- a bare point
/// carries no curvature to match, so `.g2` can never work for a *point* constraint. Cluster D's
/// census (#513/#667) measured this as a genuine instance of the shared root: `SurfaceContinuity`'s
/// raw value is forwarded as a literal `GeomPlate_PointConstraint`/`CurveConstraint` order with no
/// `GeomAbs_Shape` decode step at all.
///
/// Fixed by rejecting `.g2` for a point constraint in Swift, before any `GeomPlate_PointConstraint`
/// is built, rather than relying on OCCT's own throw (caught by the bridge's `catch (...)`) to
/// produce the same `nil` by accident. `GeomPlate_CurveConstraint` has no such restriction (it
/// accepts order 2 directly), so only point orders are checked -- curve orders are untouched.
///
/// ## Prove-the-test-fails: what actually caught the injected defects, and what didn't
///
/// Measured, not assumed (`okf/policies/prove-the-test-fails.md`): every `.g2`-on-a-point input
/// reachable through the public API was **already** `nil` before this fix, because OCCT's own
/// throw is caught by the bridge's blanket `catch (...)`. That means the public-contract tests
/// below (`allG2Rejected`, `oneG2AmongValidOrdersRejected`, `mixedPointG2RejectedAlongsideValidCurve`,
/// plus the pre-existing `Issue398ContinuityTests` pair) **stayed green when the new Swift-side
/// guard was removed and re-tested** -- confirmed by literally deleting each guard clause in turn,
/// rebuilding, and re-running this suite. They still pin a real contract (the public answer must
/// stay `nil`), so they are kept, but they do not by themselves prove the new mechanism exists;
/// they are labelled below rather than counted as such. Only `pointConstraintSupport` and
/// `mixedGuardIgnoresCurveOrders`, which call the new pure-Swift guards directly, went red when
/// the guards they cover were broken.
///
/// | case | guard broken | result |
/// |---|---|---|
/// | `pointConstraintSupport` | `isUnsupportedForPointConstraint` forced to `false` | **red** |
/// | `mixedGuardIgnoresCurveOrders` | same (transitively) | **red** |
/// | `mixedGuardIgnoresCurveOrders` | `plateMixedRejectsPointOrders` forced to `false` | **red** |
/// | `allG2Rejected` | `plateSurface(through:orders:)`'s guard clause deleted | green (decorative for this guard) |
/// | `oneG2AmongValidOrdersRejected` | same | green (decorative) |
/// | `g0AndG1StillBuild` | same | green (never touches `.g2`, unaffected either way) |
/// | `mixedPointG2RejectedAlongsideValidCurve` | `plateSurface(pointConstraints:curveConstraints:)`'s guard clause deleted | green (decorative for this guard) |
/// | `mixedPointG0G1StillBuild` | same | green (never touches `.g2`, unaffected either way) |
/// | `Issue398ContinuityTests.plateThroughPointsRejectsCurvatureOrder` | `isUnsupportedForPointConstraint` forced to `false` | green (decorative, pre-existing) |
/// | `Issue398ContinuityTests.plateThroughPointsRejectsMixedCurvatureOrder` | same | green (decorative, pre-existing) |
@Suite("Plate point constraint G2 domain restriction (#437)")
struct Issue437PlatePointG2Tests {

    private let pentagon: [SIMD3<Double>] = [
        SIMD3(0, 0, 0), SIMD3(10, 0, 1), SIMD3(10, 10, 2), SIMD3(0, 10, 1), SIMD3(5, 5, 3)
    ]

    private var rectangleWire: Wire {
        Wire.path([SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0)],
                  closed: true)!
    }

    // MARK: - The guards themselves -- these are the tests that actually prove the mechanism

    @Test("g0 and g1 are supported for a point constraint; g2 is not")
    func pointConstraintSupport() {
        #expect(!SurfaceContinuity.g0.isUnsupportedForPointConstraint)
        #expect(!SurfaceContinuity.g1.isUnsupportedForPointConstraint)
        #expect(SurfaceContinuity.g2.isUnsupportedForPointConstraint)
    }

    // `GeomPlate_CurveConstraint` (unlike the point constructor) accepts order 2 directly, so a
    // curve .g2 constraint must never be rejected by this guard. Proving that by actually
    // building a curve .g2 plate surface would conflate two different questions: whether the
    // guard inspected `curves` (an encoding question, #437's own claim) and whether
    // `GeomPlate_BuildPlateSurface`'s solver converges at G2 on a given wire (a tolerance/geometry
    // question the census already found separate and fixture-dependent -- measured nil on both a
    // circle and this suite's own rectangle wire when tried here). So this tests
    // `plateMixedRejectsPointOrders` directly: its signature takes no `curves` parameter at all,
    // which makes "curve orders cannot affect this decision" a fact about the function's shape,
    // not its convergence luck.
    @Test("The mixed-constraint guard's decision depends only on point orders")
    func mixedGuardIgnoresCurveOrders() {
        #expect(!Shape.plateMixedRejectsPointOrders([]))
        #expect(!Shape.plateMixedRejectsPointOrders([(point: SIMD3(0, 0, 0), order: .g0)]))
        #expect(!Shape.plateMixedRejectsPointOrders([(point: SIMD3(0, 0, 0), order: .g1)]))
        #expect(Shape.plateMixedRejectsPointOrders([(point: SIMD3(0, 0, 0), order: .g2)]))

        // One g2 among several otherwise-valid points still poisons the batch.
        let mixed: [(point: SIMD3<Double>, order: SurfaceContinuity)] = [
            (point: SIMD3(0, 0, 0), order: .g0),
            (point: SIMD3(1, 0, 0), order: .g1),
            (point: SIMD3(0, 1, 0), order: .g2)
        ]
        #expect(Shape.plateMixedRejectsPointOrders(mixed))
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

    @Test("g0 and g1 orders still build")
    func g0AndG1StillBuild() {
        let g0 = Shape.plateSurface(through: pentagon, orders: Array(repeating: .g0, count: pentagon.count))
        let g1 = Shape.plateSurface(through: pentagon, orders: Array(repeating: .g1, count: pentagon.count))
        #expect(g0 != nil)
        #expect(g1 != nil)
    }

    // MARK: - Public contract: plateSurface(pointConstraints:curveConstraints:)
    //
    // Same labelling as the section above: contract tests, not proof of the mechanism.

    @Test("A g2 point constraint is rejected even alongside otherwise-valid curve constraints")
    func mixedPointG2RejectedAlongsideValidCurve() {
        let shape = Shape.plateSurface(
            pointConstraints: [(point: SIMD3(5, 5, 3), order: .g2)],
            curveConstraints: [(wire: rectangleWire, order: .g0)]
        )
        #expect(shape == nil)
    }

    @Test("g0/g1 point constraints alongside a curve constraint still build")
    func mixedPointG0G1StillBuild() {
        let g0 = Shape.plateSurface(
            pointConstraints: [(point: SIMD3(5, 5, 3), order: .g0)],
            curveConstraints: [(wire: rectangleWire, order: .g0)]
        )
        #expect(g0 != nil)
    }
}
