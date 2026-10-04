import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.131.0: BSplineApproxInterp, TBezier/AHTBezier, TransformedCurve

@Suite("BSplineApproxInterp, Constrained Least-Squares Fitting")
struct BSplineApproxInterpTests {

    /// A unit helix, approximated and then measured against the helix.
    ///
    /// The `if let curve` block used to hold one assertion, `#expect(domain != nil)` on a
    /// non-optional `ClosedRange<Double>`, so the branch tested nothing and the compiler said so
    /// (#3018). What the solver owes its caller is a curve that follows the data, which is what is
    /// asserted now: unit radius about the Z axis, and the z of the sample the parameter
    /// corresponds to.
    @Test func basicApproximation() throws {
        var points: [SIMD3<Double>] = []
        for i in 0..<20 {
            let t = Double(i) / 19.0 * 2.0 * .pi
            points.append(SIMD3(cos(t), sin(t), 0.1 * t))
        }
        let solver = try #require(BSplineApproxInterp(points: points, nbControlPoints: 10))
        solver.perform()
        #expect(solver.isDone)
        #expect(solver.maxError >= 0)
        // 20 samples of a smooth helix on 10 control points: measured 2.2e-4.
        #expect(solver.maxError < 2e-3)

        let curve = try #require(solver.curve)
        let domain = curve.domain
        #expect(domain.upperBound > domain.lowerBound)
        // The ends are interpolated, so they are the first and last input points.
        #expect(simd_distance(curve.startPoint, points[0]) < 2e-3)
        #expect(simd_distance(curve.endPoint, points[points.count - 1]) < 2e-3)
        // And in between, the curve is still on the helix: radius 1 about Z, rising 0.1 per radian
        // of turn, so z = 0.2 * pi at the far end of a normalised parameter.
        for k in 0...8 {
            let f = Double(k) / 8.0
            let p = curve.point(at: domain.lowerBound + (domain.upperBound - domain.lowerBound) * f)
            #expect(abs(simd_length(SIMD2(p.x, p.y)) - 1.0) < 2e-3)
            #expect(abs(p.z - 0.2 * Double.pi * f) < 2e-3)
        }
    }

    @Test func withInterpolationConstraints() {
        var points: [SIMD3<Double>] = []
        for i in 0..<30 {
            let t = Double(i) / 29.0
            points.append(SIMD3(t, sin(.pi * t), 0))
        }
        guard let solver = BSplineApproxInterp(points: points, nbControlPoints: 15) else { return }
        solver.interpolatePoint(0)
        solver.interpolatePoint(29)
        solver.interpolatePoint(14, withKink: true)
        solver.perform()
        #expect(solver.isDone)
        #expect(solver.maxError < 0.1)
    }

    /// A planar parabola, approximated by the optimising solver and then measured against y = x^2.
    ///
    /// Same empty `if let` as `basicApproximation` before #3018. The fixture is deliberately planar
    /// so that one of the assertions is exact rather than toleranced: every input z is 0, so every
    /// control point's z is 0, so every point on the curve has z = 0.
    @Test func performOptimal() throws {
        var points: [SIMD3<Double>] = []
        for i in 0..<20 {
            let t = Double(i) / 19.0
            points.append(SIMD3(t, t * t, 0))
        }
        let solver = try #require(BSplineApproxInterp(points: points, nbControlPoints: 8))
        solver.performOptimal(maxIterations: 5)
        #expect(solver.isDone)
        // 20 samples of y = x^2 on 8 control points: measured 4.5e-4.
        #expect(solver.maxError < 2e-3)

        let curve = try #require(solver.curve)
        let domain = curve.domain
        #expect(domain.upperBound > domain.lowerBound)
        #expect(simd_distance(curve.startPoint, SIMD3(0, 0, 0)) < 2e-3)
        #expect(simd_distance(curve.endPoint, SIMD3(1, 1, 0)) < 2e-3)
        for k in 0...8 {
            let f = Double(k) / 8.0
            let p = curve.point(at: domain.lowerBound + (domain.upperBound - domain.lowerBound) * f)
            #expect(p.z == 0)
            #expect(abs(p.y - p.x * p.x) < 2e-3)
        }
    }

    @Test func setters() {
        var points: [SIMD3<Double>] = []
        for i in 0..<10 {
            points.append(SIMD3(Double(i + 1), 0, 0))
        }
        guard let solver = BSplineApproxInterp(points: points, nbControlPoints: 6) else { return }
        solver.setParametrizationAlpha(1.0)
        solver.setMinPivot(1e-15)
        solver.setClosedTolerance(1e-10)
        solver.setKnotInsertionTolerance(1e-3)
        solver.setConvergenceTolerance(1e-4)
        solver.setProjectionTolerance(1e-7)
        solver.perform()
        #expect(solver.isDone)
    }
}
