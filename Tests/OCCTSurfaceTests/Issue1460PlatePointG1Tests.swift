import Testing
import simd

@testable import OCCTSwift

/// #1460: `.g1` on a *point* constraint was a silent no-op, not a diagnostic. Extends #437's fix
/// (which rejected `.g2` for a bare point constraint) to also reject `.g1`, in
/// `SurfaceContinuity.isUnsupportedForPointConstraint`, so `isUnsupportedForPointConstraint`
/// now reads `self != .g0` instead of `self == .g2`.
///
/// Verified directly against the pinned `V8_0_1` sources before writing this fix (not just the
/// header docs):
///
/// - `GeomPlate_PointConstraint.cxx`'s point-only constructor (`GeomPlate_PointConstraint(const
///   gp_Pnt&, const int, const double)`) throws only for `myOrder > 1` or `myOrder < -1`, so
///   `myOrder == 1` (`.g1`) passes straight through. Its member-init list never touches
///   `myD11`/`myD12` (the fields `D1()` returns), so they default to `gp_Vec()`, i.e.
///   `(0,0,0)`. Contrast with the two-argument-surface constructor a few lines below, which does
///   set them via `Surf->D2(...)`; the point-only overload simply has no surface to evaluate a
///   tangent from.
/// - `GeomPlate_BuildPlateSurface.cxx`'s `LoadPoint` reads `Tang = min(Order(), OrderMax)`, and
///   for `Tang == 1` calls `myPntCont->Value(i)->D1(PP, V1, V2)`, which for a point-only
///   constraint just returns `myD11`/`myD12`, the zero vectors above, then builds a
///   `Plate_GtoCConstraint(P2d.XY(), D1init, D1final)` from them.
/// - `Plate_GtoCConstraint.cxx`'s constructor computes `gp_XYZ normale = D1T.Du ^ D1T.Dv;` (a
///   zero cross product for a zero `D1final`), sees `normale.Modulus() < NORMIN` and returns
///   immediately, leaving `nb_PPConstraints == 0`. The tangent request never reaches the solver,
///   and nothing anywhere in the chain reports it: `plateBuilder.IsDone()` is still `true`, the
///   returned surface is real, and it is silently G0-only.
///
/// A bare point structurally cannot carry tangent data any more than it can carry curvature: the
/// only OCCT overload that can (`GeomPlate_PointConstraint(U, V, Surf, Order, ...)`) evaluates
/// `Surf->D2(...)` at a parametric location on a *reference surface*, and neither
/// `OCCTShapePlatePointsAdvanced` nor `OCCTShapePlateMixed` (the two bridge entry points behind
/// `Shape.plateSurface(through:orders:...)` and `Shape.plateSurface(pointConstraints:curveConstraints:...)`)
/// has one in its signature. So, like #437's `.g2` fix, this is fixed by rejecting the order in
/// Swift before any `GeomPlate_PointConstraint` is built, not by trying to synthesize a surface.
///
/// ## Prove-the-test-fails: `.g1` is NOT decorative, unlike `.g2`
///
/// This is the interesting contrast with #437's own matrix (`Issue437PlatePointG2Tests`). There,
/// every `.g2`-on-a-point contract test stayed green when the Swift-side guard was deleted,
/// because OCCT's own constructor throw (`myOrder > 1`) produced the same `nil` via the bridge's
/// `catch (...)` regardless. `.g1` (`myOrder == 1`) does not throw, so the same experiment here
/// is genuinely different: reverting `isUnsupportedForPointConstraint` to its pre-#1460 form
/// (`self == .g2`, i.e. #437's fix alone) makes every contract test below observe a real,
/// non-nil, geometrically-degraded surface instead of the expected `nil`, measured, not
/// assumed, by making exactly that edit, rebuilding, and re-running this suite.
///
/// | case | guard broken | result |
/// |---|---|---|
/// | `allG1Rejected` | `isUnsupportedForPointConstraint` reverted to `self == .g2` | **red** (a real surface comes back; OCCT never threw for `.g1`) |
/// | `oneG1AmongValidOrdersRejected` | same | **red** |
/// | `mixedPointG1RejectedAlongsideValidCurve` | same | **red** |
/// | `g1AloneAndAlongsideG2BothRejected` | same | **red** on the g1-only case; the g1+g2 case stays red for a different reason (g2 still throws), so it alone would be decorative, kept for the contract, not for proof |
/// | `curveG1IsUnaffected` | `plateMixedRejectsPointOrders` forced to `false` | **red** (would wrongly stop rejecting a `.g1` point too) |
@Suite("Plate point constraint G1 domain restriction (#1460)")
struct Issue1460PlatePointG1Tests {

    private let pentagon: [SIMD3<Double>] = [
        SIMD3(0, 0, 0), SIMD3(10, 0, 1), SIMD3(10, 10, 2), SIMD3(0, 10, 1), SIMD3(5, 5, 3),
    ]

    private func rectangleWire() throws -> Wire {
        try #require(
            Wire.path(
                [SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0)],
                closed: true))
    }

    // MARK: - Public contract: plateSurface(through:orders:)

    @Test("All-g1 orders are rejected for a point constraint")
    func allG1Rejected() {
        let orders = Array(repeating: SurfaceContinuity.g1, count: pentagon.count)
        #expect(Shape.plateSurface(through: pentagon, orders: orders) == nil)
    }

    @Test("A single g1 among otherwise-g0 orders poisons the whole call")
    func oneG1AmongValidOrdersRejected() {
        var orders: [SurfaceContinuity] = Array(repeating: .g0, count: pentagon.count)
        orders[2] = .g1
        #expect(Shape.plateSurface(through: pentagon, orders: orders) == nil)
    }

    // MARK: - Public contract: plateSurface(pointConstraints:curveConstraints:)

    @Test("A g1 point constraint is rejected even alongside otherwise-valid curve constraints")
    func mixedPointG1RejectedAlongsideValidCurve() throws {
        let shape = Shape.plateSurface(
            pointConstraints: [(point: SIMD3(5, 5, 3), order: .g1)],
            curveConstraints: [(wire: try rectangleWire(), order: .g0)]
        )
        #expect(shape == nil)
    }

    @Test("g1 alone, and g1 alongside g2, are both rejected for a point constraint")
    func g1AloneAndAlongsideG2BothRejected() {
        let g1Only = Shape.plateSurface(
            through: pentagon, orders: Array(repeating: .g1, count: pentagon.count))
        #expect(g1Only == nil)

        var mixed: [SurfaceContinuity] = Array(repeating: .g0, count: pentagon.count)
        mixed[1] = .g1
        mixed[3] = .g2
        #expect(Shape.plateSurface(through: pentagon, orders: mixed) == nil)
    }

    // MARK: - The guard did not overreach onto curve constraints

    // `GeomPlate_CurveConstraint` has no analogue of the point-only constructor's problem: it is
    // built from an `Adaptor3d_Curve`, which can always supply a tangent, so `.g1` (and `.g2`)
    // stay fully supported for a *curve* constraint. This is the same distinction #437 already
    // drew for `.g2`. Deliberately not exercised here by actually building a curve `.g1` plate
    // surface: `Issue437PlatePointG2Tests`'s own class comment already measured that this
    // conflates two different questions (whether the guard inspected `curves`, an encoding
    // question, versus whether `GeomPlate_BuildPlateSurface`'s solver converges at a given order
    // on a given wire, a tolerance/geometry question, found nil on both a circle and this suite's
    // own rectangle wire when tried at `.g2`), and re-measuring here for `.g1` reproduces the
    // same solver non-convergence on the rectangle fixture, unrelated to this guard. So the claim
    // is tested the same way #437 tested it: directly against `plateMixedRejectsPointOrders`,
    // whose signature has no `curves` parameter at all, which makes "curve orders cannot affect
    // this decision" a fact about the function's shape, not its convergence luck. This is the one
    // function that decides whether the whole mixed call, any accompanying curve constraint
    // included, is rejected before anything is built at all, so re-confirming a `.g1` point still
    // (correctly) trips it, and a `.g0` point still doesn't, is the right level for #1460
    // specifically to pin, rather than only trusting #437's own coverage of the same function.
    @Test("The point-order guard's decision is unaffected by an accompanying g1 curve order")
    func curveG1IsUnaffected() {
        #expect(!Shape.plateMixedRejectsPointOrders([(point: SIMD3(5, 5, 3), order: .g0)]))
        #expect(Shape.plateMixedRejectsPointOrders([(point: SIMD3(5, 5, 3), order: .g1)]))
    }
}
