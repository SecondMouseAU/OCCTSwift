import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.131.0: BSplineApproxInterp, TBezier/AHTBezier, TransformedCurve

@Suite("BSplineApproxInterp, Constrained Least-Squares Fitting")
struct BSplineApproxInterpTests {

    @Test func basicApproximation() {
        var points: [SIMD3<Double>] = []
        for i in 0..<20 {
            let t = Double(i) / 19.0 * 2.0 * .pi
            points.append(SIMD3(cos(t), sin(t), 0.1 * t))
        }
        guard let solver = BSplineApproxInterp(points: points, nbControlPoints: 10) else { return }
        solver.perform()
        #expect(solver.isDone)
        if let curve = solver.curve {
            let domain = curve.domain
            #expect(domain != nil)
        }
        #expect(solver.maxError >= 0)
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

    @Test func performOptimal() {
        var points: [SIMD3<Double>] = []
        for i in 0..<20 {
            let t = Double(i) / 19.0
            points.append(SIMD3(t, t * t, 0))
        }
        guard let solver = BSplineApproxInterp(points: points, nbControlPoints: 8) else { return }
        solver.performOptimal(maxIterations: 5)
        #expect(solver.isDone)
        if let curve = solver.curve {
            let domain = curve.domain
            #expect(domain != nil)
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
