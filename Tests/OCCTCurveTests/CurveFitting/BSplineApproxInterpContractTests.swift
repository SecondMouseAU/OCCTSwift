import Foundation
import Testing
import simd

@testable import OCCTSwift

/// Pins the behaviour `BSplineApproxInterp`'s doc comments claim, so that wiring any of the
/// no-op setters back up to a real `GeomAPI_PointsToBSpline` control fails here and forces the
/// docs to be updated with it. Before #507 the docs described the removed
/// `Approx_BSplineApproxInterp` solver's controls as live, and nothing caught the drift because
/// every existing test asserted only `isDone`.

@Suite("BSplineApproxInterp: documented no-op / advisory contracts (#507)")
struct BSplineApproxInterpContractTests {

    private static func helix(_ count: Int = 24) -> [SIMD3<Double>] {
        (0..<count).map { i in
            let t = Double(i) / Double(count - 1) * 2.0 * .pi
            return SIMD3(cos(t), sin(t), 0.1 * t)
        }
    }

    /// Samples a fitted curve densely enough that two fits differing at all disagree here.
    private static func fitSignature(_ solver: BSplineApproxInterp) -> [SIMD3<Double>]? {
        guard solver.isDone, let curve = solver.curve else { return nil }
        let d = curve.domain
        return (0...32).map { i in
            curve.point(at: d.lowerBound + (d.upperBound - d.lowerBound) * Double(i) / 32.0)
        }
    }

    private static func maxDeviation(_ a: [SIMD3<Double>], _ b: [SIMD3<Double>]) -> Double {
        guard a.count == b.count else { return .infinity }
        return zip(a, b).reduce(0.0) { max($0, simd_distance($1.0, $1.1)) }
    }

    /// Control for every "…produces the same curve" test below: the fit tolerance is a knob that
    /// genuinely moves the result, so agreement elsewhere means the setter did nothing, not that
    /// this comparison is blind.
    @Test("The 3D fit tolerance does change the fitted curve")
    func fitToleranceIsObservable() {
        let pts = Self.helix()
        guard let loose = BSplineApproxInterp(points: pts, nbControlPoints: 10),
            let tight = BSplineApproxInterp(points: pts, nbControlPoints: 10)
        else { return }
        loose.setConvergenceTolerance(1e-1)
        tight.setConvergenceTolerance(1e-8)
        loose.perform()
        tight.perform()
        if let a = Self.fitSignature(loose), let b = Self.fitSignature(tight) {
            #expect(Self.maxDeviation(a, b) > 1e-9)
        }
    }

    @Test(
        "setParametrizationAlpha / setMinPivot / setClosedTolerance / setKnotInsertionTolerance are no-ops"
    )
    func tuningSettersAreNoOps() {
        let pts = Self.helix()
        guard let plain = BSplineApproxInterp(points: pts, nbControlPoints: 10),
            let tuned = BSplineApproxInterp(points: pts, nbControlPoints: 10)
        else { return }
        tuned.setParametrizationAlpha(1.0)  // chord-length, vs the 0.5 centripetal default
        tuned.setMinPivot(1e-3)
        tuned.setClosedTolerance(1.0)
        tuned.setKnotInsertionTolerance(1.0)
        plain.perform()
        tuned.perform()
        if let a = Self.fitSignature(plain), let b = Self.fitSignature(tuned) {
            #expect(Self.maxDeviation(a, b) == 0.0)
        }
    }

    @Test("interpolatePoint is a no-op, with or without a kink")
    func interpolatePointIsANoOp() {
        let pts = Self.helix()
        guard let plain = BSplineApproxInterp(points: pts, nbControlPoints: 10),
            let constrained = BSplineApproxInterp(points: pts, nbControlPoints: 10)
        else { return }
        constrained.interpolatePoint(0)
        constrained.interpolatePoint(pts.count - 1)
        constrained.interpolatePoint(pts.count / 2, withKink: true)
        plain.perform()
        constrained.perform()
        if let a = Self.fitSignature(plain), let b = Self.fitSignature(constrained) {
            #expect(Self.maxDeviation(a, b) == 0.0)
        }
    }

    @Test("performOptimal matches perform and ignores maxIterations")
    func performOptimalMatchesPerform() {
        let pts = Self.helix()
        guard let plain = BSplineApproxInterp(points: pts, nbControlPoints: 10),
            let fewIter = BSplineApproxInterp(points: pts, nbControlPoints: 10),
            let manyIter = BSplineApproxInterp(points: pts, nbControlPoints: 10)
        else { return }
        plain.perform()
        fewIter.performOptimal(maxIterations: 1)
        manyIter.performOptimal(maxIterations: 10_000)
        if let a = Self.fitSignature(plain), let b = Self.fitSignature(fewIter) {
            #expect(Self.maxDeviation(a, b) == 0.0)
        }
        if let a = Self.fitSignature(fewIter), let b = Self.fitSignature(manyIter) {
            #expect(Self.maxDeviation(a, b) == 0.0)
        }
    }

    @Test("nbControlPoints and continuousIfClosed are advisory")
    func poleCountRequestIsAdvisory() {
        let pts = Self.helix()
        guard let few = BSplineApproxInterp(points: pts, nbControlPoints: 4),
            let many = BSplineApproxInterp(
                points: pts, nbControlPoints: 40,
                continuousIfClosed: true)
        else { return }
        few.perform()
        many.perform()
        if let a = Self.fitSignature(few), let b = Self.fitSignature(many) {
            #expect(Self.maxDeviation(a, b) == 0.0)
        }
        // The approximator picks its own pole count, so the two requests land on the same curve.
        if let a = few.curve?.poleCount, let b = many.curve?.poleCount {
            #expect(a == b)
        }
    }

    @Test("setConvergenceTolerance and setProjectionTolerance drive one shared tolerance")
    func toleranceSettersShareOneValue() {
        let pts = Self.helix()
        // Projection tolerance only ever tightens, so a looser value after a tight convergence
        // tolerance is inert, and a tight one after a loose convergence tolerance wins outright.
        guard let convergenceOnly = BSplineApproxInterp(points: pts, nbControlPoints: 10),
            let thenLoosened = BSplineApproxInterp(points: pts, nbControlPoints: 10),
            let tightenedByProjection = BSplineApproxInterp(points: pts, nbControlPoints: 10)
        else { return }
        convergenceOnly.setConvergenceTolerance(1e-8)
        thenLoosened.setConvergenceTolerance(1e-8)
        thenLoosened.setProjectionTolerance(1e-1)
        tightenedByProjection.setConvergenceTolerance(1e-1)
        tightenedByProjection.setProjectionTolerance(1e-8)
        convergenceOnly.perform()
        thenLoosened.perform()
        tightenedByProjection.perform()
        if let a = Self.fitSignature(convergenceOnly), let b = Self.fitSignature(thenLoosened) {
            #expect(Self.maxDeviation(a, b) == 0.0)
        }
        if let a = Self.fitSignature(convergenceOnly),
            let b = Self.fitSignature(tightenedByProjection)
        {
            #expect(Self.maxDeviation(a, b) == 0.0)
        }
    }

    @Test("maxError is the worst back-projection distance from an input point to the fit")
    func maxErrorIsBackProjectionDistance() {
        let pts = Self.helix()
        guard let solver = BSplineApproxInterp(points: pts, nbControlPoints: 10) else { return }
        #expect(solver.maxError == -1.0)  // not run yet
        solver.setConvergenceTolerance(1e-6)
        solver.perform()
        guard solver.isDone, let curve = solver.curve else { return }
        let d = curve.domain
        // Recompute the same quantity by dense sampling. Sampling can only over-estimate the true
        // projection distance, and by at most half the widest chord between adjacent samples, so
        // that half-chord is the tolerance rather than a hand-picked constant.
        let n = 4000
        let samples = (0...n).map { i in
            curve.point(at: d.lowerBound + (d.upperBound - d.lowerBound) * Double(i) / Double(n))
        }
        let halfChord =
            zip(samples, samples.dropFirst())
            .reduce(0.0) { max($0, simd_distance($1.0, $1.1)) } / 2.0
        let worst = pts.reduce(0.0) { acc, p in
            max(acc, samples.reduce(Double.infinity) { min($0, simd_distance($1, p)) })
        }
        #expect(solver.maxError >= 0)
        #expect(worst >= solver.maxError - 1e-9)
        #expect(worst - solver.maxError <= halfChord + 1e-9)
    }
}
