import Foundation
import Testing

@testable import OCCTSwift

/// #553: the 2D solver entry points that take a circle as a centre and a radius.
///
/// Split out of #514, which guarded the conic *construction* sites and stopped there because a
/// zero-radius circle handed to a tangency solver is geometrically a point, and several of these
/// solvers have a documented answer for a point argument. The probe in
/// `Scripts/repro/553-gcc-zero-radius-circle` ran every family against a zero-radius argument and
/// against OCCT's own point overload of the same query. None of them answers the point question:
/// the answer comes back duplicated, or as a conic this bridge's own construction guards reject,
/// or with a NaN parameter, or not at all. Every family already has a point entry point in the
/// same API, so rejecting the degenerate circle costs the caller no query.
///
/// Each rejection test names the measured wrong answer it replaces, and each family also pins a
/// valid case so the guard cannot be silently over-broad.
@Suite("Issue553 zero-radius circle solver arguments")
struct Issue553GccZeroRadiusTests {

    // MARK: - GccAna bisectors

    /// Measured: 4 solutions where the point overload gives 2, each one duplicated. With both
    /// radii 0, two of the three solutions are hyperbolas of major radius 0, which is exactly the
    /// degenerate conic `occtValidHyperbolaRadii` refuses to construct.
    @Test func circleBisectorRejectsZeroRadius() {
        #expect(
            GccAnaBisector.ofCircles(
                center1: SIMD2(0, 0), radius1: 0,
                center2: SIMD2(10, 0), radius2: 2
            ).isEmpty)
        #expect(
            GccAnaBisector.ofCircles(
                center1: SIMD2(0, 0), radius1: 3,
                center2: SIMD2(10, 0), radius2: 0
            ).isEmpty)
        #expect(
            GccAnaBisector.ofCircles(
                center1: SIMD2(0, 0), radius1: 0,
                center2: SIMD2(10, 0), radius2: 0
            ).isEmpty)
    }

    @Test func circleBisectorAcceptsValidRadii() {
        let solutions = GccAnaBisector.ofCircles(
            center1: SIMD2(0, 0), radius1: 3,
            center2: SIMD2(10, 0), radius2: 2)
        #expect(solutions.count == 4)
    }

    /// The point/point question has its own entry point, and it answers correctly where the
    /// zero-radius circle does not: measured, `ofCircleAndPoint` with radius 0 returns two
    /// hyperbolas of major radius 0, while the perpendicular bisector is a line at x = 3.
    @Test func pointBisectorAnswersWhatZeroRadiusCannot() {
        #expect(
            GccAnaBisector.ofCircleAndPoint(
                center: SIMD2(0, 0), radius: 0,
                point: SIMD2(6, 0)
            ).isEmpty)
        if let line = GccAnaBisector.ofPoints(SIMD2(0, 0), SIMD2(6, 0)) {
            #expect(abs(line.point.x - 3) < 1e-9)
            #expect(abs(line.direction.x) < 1e-9)
        } else {
            Issue.record("the two-point bisector should have a solution")
        }
    }

    @Test func circlePointBisectorAcceptsValidRadius() {
        #expect(
            GccAnaBisector.ofCircleAndPoint(
                center: SIMD2(0, 0), radius: 2,
                point: SIMD2(6, 0)
            ).count == 2)
    }

    /// Measured: the point overload's single parabola, returned twice.
    @Test func circleLineBisectorRejectsZeroRadius() {
        #expect(
            GccAnaBisector.ofCircleAndLine(
                center: SIMD2(0, 5), radius: 0,
                linePoint: SIMD2(0, 0),
                lineDir: SIMD2(1, 0)
            ).isEmpty)
        #expect(
            GccAnaBisector.ofCircleAndLine(
                center: SIMD2(0, 5), radius: 2,
                linePoint: SIMD2(0, 0),
                lineDir: SIMD2(1, 0)
            ).count == 2)
    }

    // MARK: - GccAna tangent lines

    /// Measured: the point overload's single line, returned twice.
    @Test func tangentParallelLinesRejectZeroRadius() {
        #expect(
            Curve2DGcc.linesTangentParallel(
                circleCenter: SIMD2(0, 0), circleRadius: 0,
                parallelTo: SIMD2(0, 0),
                lineDir: SIMD2(1, 0)
            ).isEmpty)
        #expect(
            Curve2DGcc.linesTangentParallel(
                circleCenter: SIMD2(0, 0), circleRadius: 4,
                parallelTo: SIMD2(0, 0),
                lineDir: SIMD2(1, 0)
            ).count == 2)
    }

    @Test func tangentPerpendicularLinesRejectZeroRadius() {
        #expect(
            Curve2DGcc.linesTangentPerpendicular(
                circleCenter: SIMD2(0, 0), circleRadius: 0,
                perpendicularTo: SIMD2(0, 0),
                lineDir: SIMD2(1, 0)
            ).isEmpty)
        #expect(
            Curve2DGcc.linesTangentPerpendicular(
                circleCenter: SIMD2(0, 0), circleRadius: 4,
                perpendicularTo: SIMD2(0, 0),
                lineDir: SIMD2(1, 0)
            ).count == 2)
    }

    /// Measured: the line through the centre, returned twice, where `linesTangentToPoint`'s own
    /// entry point returns it once.
    @Test func tangentLineThroughPointRejectsZeroRadius() {
        #expect(
            linesTangentToCircleThroughPoint(
                circleCenter: SIMD2(0, 0), circleRadius: 0,
                point: SIMD2(10, 0)
            ).isEmpty)
        #expect(
            linesTangentToCircleThroughPoint(
                circleCenter: SIMD2(0, 0), circleRadius: 3,
                point: SIMD2(10, 0)
            ).count == 2)
    }

    // MARK: - GccAna_Circ2d3Tan

    /// Measured: 8 solutions where the point overload gives 4, each one duplicated.
    @Test func circleTangentToThreeCirclesRejectsZeroRadius() {
        #expect(
            Shape.circleTangent3Circles(
                c1Center: SIMD2(0, 0), c1Radius: 0,
                c2Center: SIMD2(10, 0), c2Radius: 2,
                c3Center: SIMD2(5, 8), c3Radius: 2
            ).isEmpty)
        #expect(
            Shape.circleTangent3Circles(
                c1Center: SIMD2(0, 0), c1Radius: 2,
                c2Center: SIMD2(10, 0), c2Radius: 2,
                c3Center: SIMD2(5, 8), c3Radius: 2
            ).count == 8)
    }

    /// Measured: 4 solutions holding only 2 distinct circles, one of them repeated three times.
    @Test func circleTangentToTwoCirclesAndPointRejectsZeroRadius() {
        #expect(
            Shape.circleTangent2CirclesPoint(
                c1Center: SIMD2(0, 0), c1Radius: 0,
                c2Center: SIMD2(10, 0), c2Radius: 2,
                point: SIMD2(5, 8)
            ).isEmpty)
        #expect(
            !Shape.circleTangent2CirclesPoint(
                c1Center: SIMD2(0, 0), c1Radius: 2,
                c2Center: SIMD2(10, 0), c2Radius: 2,
                point: SIMD2(5, 8)
            ).isEmpty)
    }

    /// The sharpest case measured: with a zero-radius circle the solver finds nothing at all,
    /// while the all-points entry point finds the circle circumscribing the same three positions.
    /// Reading the degenerate circle as a point would have to produce that circle; it produces
    /// an empty set instead.
    ///
    /// This is one of two tests here that cannot discriminate: because OCCT's own wrong answer is
    /// already an empty set, the assertion holds with or without the guard. Verified by running
    /// the suite against a build with the zero rejection removed, where 16 of these 22 tests fail
    /// and this one does not. It is kept because it pins the contract, not because it catches a
    /// regression in it.
    @Test func circleTangentToCircleAndTwoPointsRejectsZeroRadius() {
        #expect(
            Shape.circleTangentCircle2Points(
                circleCenter: SIMD2(0, 0), circleRadius: 0,
                p1: SIMD2(10, 0), p2: SIMD2(5, 8)
            ).isEmpty)
        #expect(
            !Shape.circleTangentCircle2Points(
                circleCenter: SIMD2(0, 0), circleRadius: 2,
                p1: SIMD2(10, 0), p2: SIMD2(5, 8)
            ).isEmpty)
    }

    // MARK: - IntAna2d

    /// Measured: the intersection point is right, but `ParamOnSecond()` on a zero-radius circle is
    /// NaN and the bridge writes it straight into `param2`.
    @Test func lineCircleIntersectionRejectsZeroRadius() {
        #expect(
            IntAna2d.intersectLineCircle(
                linePoint: SIMD2(0, 0), lineDir: SIMD2(1, 0),
                circleCenter: SIMD2(0, 0), circleRadius: 0
            ).isEmpty)
        let valid = IntAna2d.intersectLineCircle(
            linePoint: SIMD2(0, 0), lineDir: SIMD2(1, 0),
            circleCenter: SIMD2(0, 0), circleRadius: 3)
        #expect(valid.count == 2)
        #expect(valid.allSatisfy { !$0.param2.isNaN })
    }

    @Test func circleCircleIntersectionRejectsZeroRadius() {
        #expect(
            IntAna2d.intersectCircles(
                center1: SIMD2(0, 0), radius1: 0,
                center2: SIMD2(3, 0), radius2: 3
            ).isEmpty)
        #expect(
            IntAna2d.intersectCircles(
                center1: SIMD2(0, 0), radius1: 3,
                center2: SIMD2(4, 0), radius2: 3
            ).count == 2)
    }

    // MARK: - Extrema 2D

    /// Measured: the right distance, returned twice.
    @Test func lineCircleExtremaRejectZeroRadius() {
        #expect(
            Extrema2d.distanceBetweenLineAndCircle(
                linePoint: SIMD2(0, 10),
                lineDir: SIMD2(1, 0),
                circleCenter: SIMD2(0, 0),
                circleRadius: 0
            ).isEmpty)
        #expect(
            Extrema2d.distanceBetweenLineAndCircle(
                linePoint: SIMD2(0, 10),
                lineDir: SIMD2(1, 0),
                circleCenter: SIMD2(0, 0),
                circleRadius: 3
            ).count == 2)
    }

    /// Measured: no extremum at all, so the distance the point reading asks for is lost outright.
    /// The other of the two non-discriminating tests, for the same reason as
    /// ``circleTangentToCircleAndTwoPointsRejectsZeroRadius()``: OCCT already returns nothing here,
    /// so only the valid-radius half of this test can fail.
    @Test func pointCircleExtremaRejectZeroRadius() {
        #expect(
            Extrema2d.distanceFromPointToCircle(
                point: SIMD2(0, 10),
                circleCenter: SIMD2(0, 0),
                circleRadius: 0
            ).isEmpty)
        #expect(
            Extrema2d.distanceFromPointToCircle(
                point: SIMD2(0, 10),
                circleCenter: SIMD2(0, 0),
                circleRadius: 3
            ).count == 2)
    }

    // MARK: - The requested solution radius

    /// A radius of 0 here does not describe an argument, it asks the solver to find a circle that
    /// is a point. Measured, `GccAna_Circ2d2TanRad` and `GccAna_Circ2dTanOnRad` oblige and hand
    /// back solution circles of radius 0. Three sibling entry points already rejected it inline;
    /// these four were the ones that did not.
    @Test func requestedRadiusOfZeroIsRejected() {
        #expect(
            circlesTangentToLines(
                SIMD2(0, 0), SIMD2(1, 0),
                SIMD2(0, 0), SIMD2(0, 1), radius: 0
            ).isEmpty)
        #expect(circlesThroughPointsWithRadius(SIMD2(0, 0), SIMD2(4, 0), radius: 0).isEmpty)
        #expect(
            Curve2DGcc.circlesTangentToLineOnLineWithRadius(
                linePoint: SIMD2(0, 0), lineDir: SIMD2(1, 0),
                centerOnPoint: SIMD2(0, 0), centerOnDir: SIMD2(1, 1), radius: 0
            ).isEmpty)
    }

    @Test func requestedRadiusOfZeroIsRejectedOnCurves() {
        guard let line = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)),
            let centerOn = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 1))
        else {
            Issue.record("could not build the two 2D lines")
            return
        }
        #expect(
            Curve2DGcc.circlesTangentOnCurveWithRadius(
                line, centerOn: centerOn,
                radius: 0
            ).isEmpty)
    }

    @Test func requestedRadiusAcceptsValidValues() {
        #expect(
            circlesTangentToLines(
                SIMD2(0, 0), SIMD2(1, 0),
                SIMD2(0, 0), SIMD2(0, 1), radius: 2
            ).count == 4)
        #expect(!circlesThroughPointsWithRadius(SIMD2(0, 0), SIMD2(4, 0), radius: 3).isEmpty)
        #expect(
            !Curve2DGcc.circlesTangentToLineOnLineWithRadius(
                linePoint: SIMD2(0, 0), lineDir: SIMD2(1, 0),
                centerOnPoint: SIMD2(0, 0), centerOnDir: SIMD2(1, 1), radius: 2
            ).isEmpty)
    }

    // MARK: - The producers #514 did not reach

    /// Measured: `BRepBuilderAPI_MakeEdge2d` reports `IsDone()` for a zero-radius arc and hands
    /// back a zero-length edge with both vertices at the centre, the same shape of answer #514
    /// refused for `OCCTMakeEdge2dFullCircle`.
    @Test func circleEdgeRejectsZeroRadius() {
        #expect(
            Shape.edge2dFromCircle(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                radius: 0, p1: 0, p2: .pi) == nil)
        #expect(
            Shape.edge2dFromCircle(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                radius: 3, p1: 0, p2: .pi) != nil)
    }

    /// `GC_MakeCircle2d` rejects a negative radius through `gce_NegativeRadius` but accepts 0.
    @Test func gceCircleFactoriesRejectZeroRadius() {
        #expect(Curve2D.gceCircle(center: SIMD2(0, 0), radius: 0) == nil)
        #expect(Curve2D.gceCircle(center: SIMD2(0, 0), radius: 3) != nil)
        #expect(
            Curve2D.gceCircle(
                axisCenter: SIMD2(0, 0), axisDirection: SIMD2(1, 0),
                radius: 0) == nil)
        #expect(
            Curve2D.gceCircle(
                axisCenter: SIMD2(0, 0), axisDirection: SIMD2(1, 0),
                radius: 3) != nil)
    }

    /// The parallel factory needs the offset checked as well as the radius. Measured, radius 5
    /// offset by -5 gives radius 0 and by -6 gives radius 1: `GC_MakeCircle2d` takes the absolute
    /// value rather than refusing an offset that reaches or passes the centre, so a caller asking
    /// for a circle 6 units inside a radius-5 one silently gets a radius-1 circle.
    @Test func parallelCircleRejectsCollapsingOffset() {
        #expect(
            Curve2D.gceCircleParallel(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                radius: 0, distance: 3) == nil)
        #expect(
            Curve2D.gceCircleParallel(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                radius: 5, distance: -5) == nil)
        #expect(
            Curve2D.gceCircleParallel(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                radius: 5, distance: -6) == nil)
        if let c = Curve2D.gceCircleParallel(
            center: SIMD2(0, 0), direction: SIMD2(1, 0),
            radius: 5, distance: -2)
        {
            #expect(abs(c.circleProperties.radius - 3) < 1e-9)
        } else {
            Issue.record("an offset that stays inside the base circle should still build")
        }
    }

    // MARK: - Negative radius was never the gap

    /// `gp_Circ2d`'s constructor is `constexpr` in the header, so its
    /// `Standard_ConstructionError_Raise_if` runs in a bridge translation unit and the existing
    /// catch already turned a negative radius into an empty result. These pin that the new guards
    /// did not change what a negative radius does, only what zero does.
    @Test func negativeRadiusWasAlreadyRejected() {
        #expect(
            GccAnaBisector.ofCircles(
                center1: SIMD2(0, 0), radius1: -1,
                center2: SIMD2(10, 0), radius2: 2
            ).isEmpty)
        #expect(
            IntAna2d.intersectCircles(
                center1: SIMD2(0, 0), radius1: -1,
                center2: SIMD2(3, 0), radius2: 3
            ).isEmpty)
        #expect(
            Extrema2d.distanceFromPointToCircle(
                point: SIMD2(0, 10),
                circleCenter: SIMD2(0, 0),
                circleRadius: -1
            ).isEmpty)
        #expect(Curve2D.gceCircle(center: SIMD2(0, 0), radius: -1) == nil)
        #expect(
            Shape.edge2dFromCircle(
                center: SIMD2(0, 0), direction: SIMD2(1, 0),
                radius: -1, p1: 0, p2: .pi) == nil)
    }
}
