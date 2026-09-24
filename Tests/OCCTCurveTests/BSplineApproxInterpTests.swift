import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.131.0: BSplineApproxInterp, TBezier/AHTBezier, TransformedCurve

// BSplineApproxInterp is GeomAPI_PointsToBSpline(points, 3, 8, C2, tol3D) since OCCT 8.0.0p1
// removed Approx_BSplineApproxInterp, and its maxError is the largest distance from an input point
// to the fit. Every value below is that call's on the same points
// (Scripts/repro/766-curve-bitgte-pcurve-approx/transcript.txt). The earlier versions checked
// `isDone`, `maxError >= 0` and `domain != nil` (a non-optional range, always true), so a fit that
// ran but missed the points passed (#766). interpolatePoint is a documented no-op, so the second
// test's name describes constraints the fit does not apply; it pins what the fit does produce.
@Suite("BSplineApproxInterp, Constrained Least-Squares Fitting")
struct BSplineApproxInterpTests {

    @Test func basicApproximation() {
        var points: [SIMD3<Double>] = []
        for i in 0..<20 {
            let t = Double(i) / 19.0 * 2.0 * .pi
            points.append(SIMD3(cos(t), sin(t), 0.1 * t))
        }
        guard let solver = BSplineApproxInterp(points: points, nbControlPoints: 10) else {
            Issue.record("solver not created")
            return
        }
        solver.perform()
        #expect(solver.isDone)
        #expect(abs(solver.maxError - 0.00022151330264909389) < 1e-9)
        guard let curve = solver.curve else {
            Issue.record("no curve after perform()")
            return
        }
        #expect(curve.domain == 0...1)
        #expect(simd_distance(curve.startPoint, SIMD3(1, 0, 0)) < 1e-9)
        #expect(simd_distance(curve.endPoint, SIMD3(1, 0, 0.2 * .pi)) < 1e-9)
    }

    @Test func withInterpolationConstraints() {
        var points: [SIMD3<Double>] = []
        for i in 0..<30 {
            let t = Double(i) / 29.0
            points.append(SIMD3(t, sin(.pi * t), 0))
        }
        guard let solver = BSplineApproxInterp(points: points, nbControlPoints: 15) else {
            Issue.record("solver not created")
            return
        }
        solver.interpolatePoint(0)
        solver.interpolatePoint(29)
        solver.interpolatePoint(14, withKink: true)
        solver.perform()
        #expect(solver.isDone)
        #expect(solver.maxError < 0.1)
        #expect(abs(solver.maxError - 0.00027501864739553364) < 1e-9)
    }

    @Test func performOptimal() {
        var points: [SIMD3<Double>] = []
        for i in 0..<20 {
            let t = Double(i) / 19.0
            points.append(SIMD3(t, t * t, 0))
        }
        guard let solver = BSplineApproxInterp(points: points, nbControlPoints: 8) else {
            Issue.record("solver not created")
            return
        }
        solver.performOptimal(maxIterations: 5)
        #expect(solver.isDone)
        #expect(abs(solver.maxError - 0.00045471476354564305) < 1e-9)
        guard let curve = solver.curve else {
            Issue.record("no curve after performOptimal()")
            return
        }
        #expect(simd_distance(curve.startPoint, SIMD3(0, 0, 0)) < 1e-9)
        #expect(simd_distance(curve.endPoint, SIMD3(1, 1, 0)) < 1e-9)
    }

    @Test func setters() {
        var points: [SIMD3<Double>] = []
        for i in 0..<10 {
            points.append(SIMD3(Double(i + 1), 0, 0))
        }
        guard let solver = BSplineApproxInterp(points: points, nbControlPoints: 6) else {
            Issue.record("solver not created")
            return
        }
        solver.setParametrizationAlpha(1.0)
        solver.setMinPivot(1e-15)
        solver.setClosedTolerance(1e-10)
        solver.setKnotInsertionTolerance(1e-3)
        solver.setConvergenceTolerance(1e-4)
        solver.setProjectionTolerance(1e-7)
        solver.perform()
        #expect(solver.isDone)
        // Collinear points: the fit is the line itself.
        #expect(solver.maxError < 1e-12)
        guard let curve = solver.curve else {
            Issue.record("no curve after perform()")
            return
        }
        #expect(simd_distance(curve.startPoint, SIMD3(1, 0, 0)) < 1e-9)
        #expect(simd_distance(curve.endPoint, SIMD3(10, 0, 0)) < 1e-9)
    }
}
