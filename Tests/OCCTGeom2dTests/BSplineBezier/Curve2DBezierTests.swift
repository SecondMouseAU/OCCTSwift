import Foundation
import Testing
import simd

@testable import OCCTSwift

// Every test requires the curve it measures, so a nil curve fails instead of skipping the
// assertions, and pins a value that does not come from the bridge. What `Geom2d_BezierCurve` itself
// answers for the same calls is recorded in `Scripts/repro/766-geom2d-bezier/transcript.txt` and
// `Scripts/repro/766-geom2d-curve2d-cluster/transcript.txt`.
@Suite("Curve2D_Bezier_Properties")
struct Curve2DBezierTests {
    private static let arch: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(5, 10), SIMD2(10, 0)]

    func makeBezier2D() throws -> Curve2D {
        try #require(Curve2D.bezier(poles: Self.arch))
    }

    @Test func degreeAndPoleCount() throws {
        let bp = try makeBezier2D().bezierProperties
        #expect(bp.degree == 2)
        #expect(bp.poleCount == 3)

        // A different curve gives different answers, so neither accessor is a constant.
        let cubic = try #require(
            Curve2D.bezier(poles: [SIMD2(0, 0), SIMD2(1, 2), SIMD2(3, 2), SIMD2(4, 0)]))
        #expect(cubic.bezierProperties.degree == 3)
        #expect(cubic.bezierProperties.poleCount == 4)
    }

    @Test func getPole() throws {
        let bp = try makeBezier2D().bezierProperties
        // Poles are 1-based: pole 1 is the first one given, so an off-by-one reads (5, 10) here.
        #expect(simd_distance(bp.pole(at: 1), SIMD2(0, 0)) < 1e-10)
        #expect(simd_distance(bp.pole(at: 2), SIMD2(5, 10)) < 1e-10)
        #expect(simd_distance(bp.pole(at: 3), SIMD2(10, 0)) < 1e-10)
    }

    @Test func setPole() throws {
        let bp = try makeBezier2D().bezierProperties
        let ok = bp.setPole(at: 2, point: SIMD2(3, 7))
        #expect(ok)
        let p = bp.pole(at: 2)
        #expect(abs(p.x - 3.0) < 1e-10)
        #expect(abs(p.y - 7.0) < 1e-10)
        // Only pole 2 moved.
        #expect(simd_distance(bp.pole(at: 1), SIMD2(0, 0)) < 1e-10)
        #expect(simd_distance(bp.pole(at: 3), SIMD2(10, 0)) < 1e-10)
    }

    @Test func isRational() throws {
        let bp = try makeBezier2D().bezierProperties
        #expect(!bp.isRational)

        // The control: weights that are not all equal make the same poles rational, and the curve
        // is rational in fact and not only in name: at u = 1/2 the Bernstein weights are 1/4, 1/2
        // and 1/4, and it evaluates as the weighted average of the poles. Asymmetric weights, so
        // that a reversed weight list gives a different point.
        let weights: [Double] = [1, 3, 2]
        let weighted = try #require(Curve2D.bezier(poles: Self.arch, weights: weights))
        #expect(weighted.bezierProperties.isRational)
        let bernstein: [Double] = [0.25, 0.5, 0.25]
        var numerator = SIMD2<Double>(0, 0)
        var denominator: Double = 0
        for i in 0..<3 {
            let share: Double = bernstein[i] * weights[i]
            numerator += share * Self.arch[i]
            denominator += share
        }
        #expect(simd_distance(weighted.point(at: 0.5), numerator / denominator) < 1e-12)

        // OCCT drops weights that are all equal, so unit weights are not rational.
        let unit = try #require(Curve2D.bezier(poles: Self.arch, weights: [1, 1, 1]))
        #expect(!unit.bezierProperties.isRational)
    }

    @Test func resolution() throws {
        // `BSplCLib::Resolution` bounds |C'| by the degree times the largest pole step in the L1
        // norm, |dx| + |dy|, and Geom2d_BezierCurve::Resolution is the tolerance over that bound.
        // The poles (0, 0), (5, 10), (10, 0) step by 15 each way, so the bound is 2 * 15 = 30.
        let bp = try makeBezier2D().bezierProperties
        let bound: Double = 2.0 * (5.0 + 10.0)
        #expect(abs(bp.resolution(tolerance: 0.1) - 0.1 / bound) < 1e-12)
        // It is linear in the tolerance, so the argument is used.
        #expect(abs(bp.resolution(tolerance: 0.2) - 0.2 / bound) < 1e-12)

        // And it follows an edit: (0, 0), (3, 7), (10, 0) step by 10 and 14, so the bound is 2 * 14.
        #expect(bp.setPole(at: 2, point: SIMD2(3, 7)))
        let editedBound: Double = 2.0 * (7.0 + 7.0)
        #expect(abs(bp.resolution(tolerance: 0.1) - 0.1 / editedBound) < 1e-12)
    }
}
