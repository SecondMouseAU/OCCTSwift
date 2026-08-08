import Testing
import simd
@testable import OCCTSwift

/// #398: the continuity vocabularies collapsed from nine enums to two shared ones plus two
/// retained specials. These pin the raw values (the unification must not move a single one),
/// the deprecated spellings, and the one order that OCCT refuses outright.
@Suite("Continuity vocabulary (#398)")
struct Issue398ContinuityTests {

    // MARK: - Raw values

    @Test("Geometric orders keep their plate-order raw values")
    func geometricOrdersKeepRawValues() {
        // These are handed to OCCT as a plate constraint order, which GeomPlate_CurveConstraint
        // validates against [-1, 2]. Renaming .c0 to .g0 must not have moved anything.
        #expect(SurfaceContinuity.g0.rawValue == 0)
        #expect(SurfaceContinuity.g1.rawValue == 1)
        #expect(SurfaceContinuity.g2.rawValue == 2)
        #expect(SurfaceContinuity.allCases.count == 3)
    }

    @Test("Parametric orders keep their GeomAbs_C0...C3 raw values")
    func parametricOrdersKeepRawValues() {
        #expect(ParametricContinuity.c0.rawValue == 0)
        #expect(ParametricContinuity.c1.rawValue == 1)
        #expect(ParametricContinuity.c2.rawValue == 2)
        #expect(ParametricContinuity.c3.rawValue == 3)
        #expect(ParametricContinuity.allCases.count == 4)
    }

    @Test("The two vocabularies are distinct types, not aliases of each other")
    func vocabulariesAreNotSubstitutable() {
        // The property this whole refactor exists to guarantee is compile-time: a G0/G1/G2
        // constraint order must never be passable where a C0...C3 continuity floor is wanted,
        // or vice versa. That cannot be asserted directly, but collapsing one into a typealias
        // of the other is the realistic way it would be lost, and this catches exactly that.
        #expect(ObjectIdentifier(SurfaceContinuity.self) != ObjectIdentifier(ParametricContinuity.self))
        #expect(ObjectIdentifier(SurfaceContinuity.self) != ObjectIdentifier(ContinuityClass.self))
        #expect(ObjectIdentifier(ParametricContinuity.self) != ObjectIdentifier(Shape.ContinuityLevel.self))

        // They agree on 0/1/2 numerically, which is precisely why the type distinction is
        // load-bearing: a raw-value mix-up would be silent.
        #expect(SurfaceContinuity.g1.rawValue == ParametricContinuity.c1.rawValue)
    }

    @Test("The result vocabulary still mirrors the real GeomAbs_Shape ordinals")
    func surfaceContinuityMirrorsGeomAbsShape() {
        // Deliberately NOT folded into either shared *request* enum: this one is a result type
        // whose raw values are GeomAbs_Shape's own ordinals, not a 0/1/2 order at all. #485
        // renamed it from Surface.Continuity to the top-level ContinuityClass and extended it
        // to Curve3D/Curve2D, which had no typed form; the raw values did not move. The former
        // Surface.Continuity alias was removed at v2.0.0 (#784); see Issue485SurfaceContinuityTests
        // for the measured values.
        #expect(ContinuityClass.c0.rawValue == 0)
        #expect(ContinuityClass.g1.rawValue == 1)
        #expect(ContinuityClass.c1.rawValue == 2)
        #expect(ContinuityClass.g2.rawValue == 3)
        #expect(ContinuityClass.c2.rawValue == 4)
        #expect(ContinuityClass.c3.rawValue == 5)
        #expect(ContinuityClass.cN.rawValue == 6)
    }

    // MARK: - Orders OCCT will not accept

    // #437 (fixed): `.g2` on a point constraint is now rejected deliberately, in Swift, before
    // any `GeomPlate_PointConstraint` is built -- see `SurfaceContinuity.isUnsupportedForPointConstraint`
    // and `Issue437PlatePointG2Tests`. The `== nil` answer below does NOT change: it was already
    // `nil` (OCCT throws, the bridge's `catch (...)` swallows it), and stays `nil` now that the
    // rejection is explicit. What changed is *why* -- these two tests alone cannot show that; see
    // `Issue437PlatePointG2Tests`'s own class comment for the guard-removal matrix that does.
    @Test("Plate point constraints reject curvature order")
    func plateThroughPointsRejectsCurvatureOrder() {
        // GeomPlate_PointConstraint throws above order 1: a bare point carries no curvature
        // to match. The throw takes down the whole build, not just that one constraint, so
        // .g2 here is always nil however good the point set is.
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(10, 0, 1), SIMD3(10, 10, 2),
            SIMD3(0, 10, 1), SIMD3(5, 5, 3)
        ]
        let curvature = Shape.plateSurface(through: points,
                                           orders: Array(repeating: .g2, count: points.count))
        #expect(curvature == nil)

        // The orders that do work, for contrast.
        let positional = Shape.plateSurface(through: points,
                                            orders: Array(repeating: .g0, count: points.count))
        #expect(positional != nil)
        let tangent = Shape.plateSurface(through: points,
                                         orders: Array(repeating: .g1, count: points.count))
        #expect(tangent != nil)
    }

    @Test("A single curvature point poisons an otherwise valid order list")
    func plateThroughPointsRejectsMixedCurvatureOrder() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(10, 0, 1), SIMD3(10, 10, 2),
            SIMD3(0, 10, 1), SIMD3(5, 5, 3)
        ]
        var orders: [SurfaceContinuity] = Array(repeating: .g0, count: points.count)
        orders[2] = .g2
        #expect(Shape.plateSurface(through: points, orders: orders) == nil)
    }
}
