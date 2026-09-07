import Testing
import simd

@testable import OCCTSwift

/// The 2D analytic evaluators refuse degenerate arguments instead of aborting the process (#1407).
///
/// `Geom2dEval_SineWaveCurve`, `Geom2dEval_CircleInvoluteCurve` and
/// `Geom2dEval_ArchimedeanSpiralCurve` validate their arguments and raise
/// `Standard_ConstructionError` on ordinary caller values: amplitude 0, radius 0, growth rate 0.
/// Uncaught, that reaches Swift-generated frames with no unwind personality routine and aborts.
///
/// These assertions are about survival, not about the values: the functions have no success flag,
/// so a refused call is indistinguishable from a real answer at zero. Giving them one is #1646.
@Suite("Issue #1407, 2D evaluator guards")
struct Issue1407EvaluatorGuardTests {

    @Test("A zero-amplitude sine wave does not abort")
    func zeroAmplitudeSineWave() {
        let p = Geom2dEval.sineWaveD0(amplitude: 0, omega: 1, phase: 0, u: 0.5)
        #expect(p.x.isFinite && p.y.isFinite)
    }

    @Test("A zero-radius circle involute does not abort")
    func zeroRadiusInvolute() {
        let p = Geom2dEval.circleInvoluteD0(radius: 0, u: 0.5)
        #expect(p.x.isFinite && p.y.isFinite)
    }

    @Test("A zero-growth Archimedean spiral does not abort")
    func zeroGrowthSpiral() {
        let p = Geom2dEval.archimedeanSpiralD0(initialRadius: 1, growthRate: 0, u: 0.5)
        #expect(p.x.isFinite && p.y.isFinite)
    }
}
