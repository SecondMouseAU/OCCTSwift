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

    @Test("Surface.Continuity still mirrors the real GeomAbs_Shape ordinals")
    func surfaceContinuityMirrorsGeomAbsShape() {
        // Deliberately NOT folded into either shared enum: this one is a result type whose
        // raw values are GeomAbs_Shape's own ordinals, which are not a 0/1/2 order at all.
        #expect(Surface.Continuity.c0.rawValue == 0)
        #expect(Surface.Continuity.g1.rawValue == 1)
        #expect(Surface.Continuity.c1.rawValue == 2)
        #expect(Surface.Continuity.g2.rawValue == 3)
        #expect(Surface.Continuity.c2.rawValue == 4)
        #expect(Surface.Continuity.c3.rawValue == 5)
        #expect(Surface.Continuity.cN.rawValue == 6)
    }

    // MARK: - Source compatibility

    @available(*, deprecated, message: "exercises the deprecated spellings on purpose")
    @Test("Retired names and spellings still resolve to the same values")
    func retiredSpellingsStillResolve() {
        #expect(FillingContinuity.g0 == SurfaceContinuity.g0)
        #expect(PlateConstraintOrder.g1 == SurfaceContinuity.g1)
        #expect(SurfaceContinuity.c0 == SurfaceContinuity.g0)
        #expect(SurfaceContinuity.c1 == SurfaceContinuity.g1)
        #expect(SurfaceContinuity.c2 == SurfaceContinuity.g2)

        #expect(GeometricContinuity.c2 == ParametricContinuity.c2)
        #expect(ApproxContinuity.c3 == ParametricContinuity.c3)
        #expect(Shape.BSplineContinuity.c1 == ParametricContinuity.c1)
        #expect(Curve3D.ContinuityOrder.c0 == ParametricContinuity.c0)
    }

    // MARK: - Orders OCCT will not accept

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
