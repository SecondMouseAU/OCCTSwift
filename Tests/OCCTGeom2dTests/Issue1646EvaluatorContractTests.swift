import Foundation
import Testing
import simd

@testable import OCCTSwift

/// A refused 2D evaluation is `nil`, and a returned value is a measurement (#1646).
///
/// PR #1629 stopped the ten `Geom2dEval_*` bridge evaluators aborting the process, but they were
/// `void` functions writing out-parameters, so a caught throw left the caller's pre-zeroed buffer
/// untouched and a refusal was spelled exactly like a real answer at the origin. Every one of
/// these curves passes through or near the origin for some argument, so that is not a spelling a
/// caller can disambiguate.
///
/// Three separate things produce a non-answer, measured against the pinned kernel in
/// `Scripts/repro/1646-evaluator-contract/probe_geom2deval_contract.mm`, and only the first is a
/// throw:
///
///   1. An argument the OCCT constructor rejects (amplitude 0, radius 0, growth rate 0).
///   2. A non-finite argument, which walks past OCCT's own `<= 0` validation because every
///      comparison against NaN is false, and evaluates to a NaN point.
///   3. A finite argument whose evaluation overflows: the logarithmic spiral is `exp(b*t)`.
///
/// So each rejecting shape gets a row, and each is paired with a nearby accepted call, because a
/// contract that returned `nil` for everything would satisfy the refusals on its own.
@Suite("Issue #1646, 2D evaluator contract")
struct Issue1646EvaluatorContractTests {

    // MARK: Arguments the OCCT constructor rejects

    @Test("Every D0 evaluator refuses the argument its OCCT constructor rejects")
    func constructorRejectionsD0() {
        #expect(Geom2dEval.sineWaveD0(amplitude: 0, omega: 1, phase: 0, u: 0.5) == nil)
        #expect(Geom2dEval.sineWaveD0(amplitude: 1, omega: 0, phase: 0, u: 0.5) == nil)
        #expect(Geom2dEval.circleInvoluteD0(radius: 0, u: 0.5) == nil)
        #expect(
            Geom2dEval.archimedeanSpiralD0(initialRadius: 1, growthRate: 0, u: 0.5) == nil)
        #expect(
            Geom2dEval.archimedeanSpiralD0(initialRadius: -1, growthRate: 0.1, u: 0.5) == nil)
        #expect(Geom2dEval.logarithmicSpiralD0(scale: 0, growthExponent: 0.2, u: 0.5) == nil)
        #expect(Geom2dEval.logarithmicSpiralD0(scale: 1, growthExponent: 0, u: 0.5) == nil)
    }

    @Test("Every D1 evaluator refuses the argument its OCCT constructor rejects")
    func constructorRejectionsD1() {
        #expect(Geom2dEval.sineWaveD1(amplitude: 0, omega: 1, phase: 0, u: 0.5) == nil)
        #expect(Geom2dEval.circleInvoluteD1(radius: 0, u: 0.5) == nil)
        #expect(
            Geom2dEval.archimedeanSpiralD1(initialRadius: 1, growthRate: 0, u: 0.5) == nil)
        #expect(Geom2dEval.logarithmicSpiralD1(scale: 0, growthExponent: 0.2, u: 0.5) == nil)
    }

    @Test("The same evaluators answer the accepted argument beside each rejected one")
    func acceptedArgumentsAnswer() throws {
        // #1979: each answer was checked only for being finite, which any wrong point is. Now
        // pinned to the Geom2dEval_* curve's own EvalD0/EvalD1 on the same arguments
        // (Scripts/repro/766-geom2d-evaluator-contract/).
        let sine = try #require(Geom2dEval.sineWaveD0(amplitude: 1, omega: 1, phase: 0, u: 0.5))
        #expect(simd_distance(sine, SIMD2(0.5, 0.479425538604)) < 1e-9)
        let involute = try #require(Geom2dEval.circleInvoluteD0(radius: 1, u: 0.5))
        #expect(simd_distance(involute, SIMD2(1.11729533119, 0.040634257659)) < 1e-9)
        let spiral = try #require(
            Geom2dEval.archimedeanSpiralD0(initialRadius: 1, growthRate: 0.1, u: 0.5))
        #expect(simd_distance(spiral, SIMD2(0.921461689985, 0.503396815534)) < 1e-9)
        let log = try #require(
            Geom2dEval.logarithmicSpiralD0(scale: 1, growthExponent: 0.2, u: 0.5))
        #expect(simd_distance(log, SIMD2(0.969878725612, 0.529847162648)) < 1e-9)
        let sineD1 = try #require(Geom2dEval.sineWaveD1(amplitude: 1, omega: 1, phase: 0, u: 0.5))
        #expect(simd_distance(sineD1.d1, SIMD2(1, 0.87758256189)) < 1e-9)
    }

    // MARK: The origin is an answer, not a refusal

    /// The row this whole contract exists for. `sineWaveD0(amplitude: 1, omega: 1, phase: 0, u: 0)`
    /// evaluates to exactly `(0, 0)`, and under the old `void` signature that is byte-identical to
    /// what a refused call left in the caller's buffer.
    @Test("A legitimate evaluation at the origin is a value, not a refusal")
    func originIsAnAnswer() throws {
        let p = try #require(Geom2dEval.sineWaveD0(amplitude: 1, omega: 1, phase: 0, u: 0))
        #expect(p.x == 0.0)
        #expect(p.y == 0.0)
        #expect(Geom2dEval.sineWaveD0(amplitude: 0, omega: 1, phase: 0, u: 0) == nil)
    }

    // MARK: Non-finite arguments, which OCCT's own validation does not reject

    @Test("A NaN argument is refused, not answered with a NaN point")
    func nonFiniteArgumentsRefused() {
        #expect(Geom2dEval.sineWaveD0(amplitude: .nan, omega: 1, phase: 0, u: 0.5) == nil)
        #expect(Geom2dEval.sineWaveD0(amplitude: 1, omega: .nan, phase: 0, u: 0.5) == nil)
        #expect(Geom2dEval.sineWaveD0(amplitude: .infinity, omega: 1, phase: 0, u: 0.5) == nil)
        #expect(Geom2dEval.circleInvoluteD0(radius: .nan, u: 0.5) == nil)
        #expect(
            Geom2dEval.archimedeanSpiralD0(initialRadius: .nan, growthRate: 0.1, u: 0.5) == nil)
        #expect(Geom2dEval.logarithmicSpiralD0(scale: .nan, growthExponent: 0.2, u: 0.5) == nil)
        #expect(Geom2dEval.sineWaveD1(amplitude: .nan, omega: 1, phase: 0, u: 0.5) == nil)
    }

    @Test("A NaN parameter is refused, and EvalD0 never raises on one")
    func nonFiniteParameterRefused() {
        #expect(Geom2dEval.sineWaveD0(amplitude: 1, omega: 1, phase: 0, u: .nan) == nil)
        #expect(Geom2dEval.sineWaveD0(amplitude: 1, omega: 1, phase: 0, u: .infinity) == nil)
        #expect(Geom2dEval.circleInvoluteD1(radius: 1, u: .nan) == nil)
    }

    // MARK: An overflow from arguments the constructor accepted

    /// `Geom2dEval_LogarithmicSpiralCurve(ax, 1, 1).EvalD0(1000)` is `(nan, nan)`: nothing threw
    /// and every argument is finite, so a flag taken from the constructor alone would call this a
    /// measurement. It is the row that forces the check onto the outputs.
    @Test("A finite argument whose evaluation overflows is refused")
    func overflowRefused() throws {
        #expect(Geom2dEval.logarithmicSpiralD0(scale: 1, growthExponent: 1, u: 1000) == nil)
        let near = try #require(Geom2dEval.logarithmicSpiralD0(scale: 1, growthExponent: 1, u: 1))
        #expect(simd_distance(near, SIMD2(1.46869393992, 2.28735528718)) < 1e-9)  // #1979: was isFinite
    }

    // MARK: The two placement overloads

    @Test("The placement overloads refuse a bad radius, direction, or non-finite argument")
    func placementRefusals() {
        #expect(
            Geom2dEval.circleInvoluteD0(
                origin: .zero, direction: SIMD2(1, 0), radius: 0, u: 1.0) == nil)
        #expect(
            Geom2dEval.circleInvoluteD1(
                origin: .zero, direction: SIMD2(1, 0), radius: 0, u: 1.0) == nil)
        #expect(
            Geom2dEval.circleInvoluteD0(
                origin: .zero, direction: SIMD2(0, 0), radius: 2.0, u: 1.0) == nil)
        #expect(
            Geom2dEval.circleInvoluteD1(
                origin: .zero, direction: SIMD2(0, 0), radius: 2.0, u: 1.0) == nil)
        // hypot(NaN, NaN) is NaN, and `NaN > 1e-12` is false, so the length guard written as an
        // acceptance rejects it. Written as `!(dirLen < 1e-12)` it does not, but this row still
        // passes: the finite-output check catches what gets past it. It takes both injections to
        // fail this line, which is what says the Swift guard is the one holding it.
        #expect(
            Geom2dEval.circleInvoluteD0(
                origin: .zero, direction: SIMD2(.nan, .nan), radius: 2.0, u: 1.0) == nil)
        // A NaN radius clears `radius <= 0.0`, since that comparison is false for NaN, so this one
        // is refused by the finite-output check rather than by a precondition.
        #expect(
            Geom2dEval.circleInvoluteD0(
                origin: .zero, direction: SIMD2(1, 0), radius: .nan, u: 1.0) == nil)
        #expect(
            Geom2dEval.circleInvoluteD0(
                origin: SIMD2(.nan, 0), direction: SIMD2(1, 0), radius: 2.0, u: 1.0) == nil)
    }

    @Test("The placement overloads answer a well-formed call")
    func placementAnswers() throws {
        let p = try #require(
            Geom2dEval.circleInvoluteD0(
                origin: SIMD2(10, 20), direction: SIMD2(1, 0), radius: 2.0, u: 0.0))
        #expect(abs(p.x - 12.0) < 1e-10)
        #expect(abs(p.y - 20.0) < 1e-10)
        let r = try #require(
            Geom2dEval.circleInvoluteD1(
                origin: SIMD2(10, 20), direction: SIMD2(1, 0), radius: 2.0, u: 1.0))
        // #1979: was `isFinite` on one component of each; now both pinned to the kernel.
        #expect(simd_distance(r.point, SIMD2(12.7635465814, 20.6023373579)) < 1e-9)
        #expect(simd_distance(r.d1, SIMD2(1.08060461174, 1.68294196962)) < 1e-9)
    }
}
