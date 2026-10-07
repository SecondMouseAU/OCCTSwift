import Testing
import simd

@testable import OCCTSwift

@Suite("Plate_Plate Solver")
struct PlateSolverTests {

    // #766: the load functions return true whatever Plate_Plate does with the constraint, so a
    // test that checks only that Bool passes a constraint that was never loaded. Each test here
    // now solves and evaluates, pinned to Plate_Plate's own answer for the same constraints
    // (SolveTI(4, 1.0)), see Scripts/repro/766-plate-solver-surface/.
    @Test func basicSolve() {
        let solver = PlateSolver()
        solver.loadPinpoint(u: 0, v: 0, position: SIMD3(0, 0, 0))
        solver.loadPinpoint(u: 1, v: 0, position: SIMD3(1, 0, 0))
        solver.loadPinpoint(u: 0, v: 1, position: SIMD3(0, 1, 0))
        solver.loadPinpoint(u: 1, v: 1, position: SIMD3(1, 1, 0))
        solver.loadPinpoint(u: 0.5, v: 0.5, position: SIMD3(0.5, 0.5, 1.0))

        #expect(solver.solve())
        #expect(solver.isDone)

        let center = solver.evaluate(u: 0.5, v: 0.5)
        #expect(simd_length(center - SIMD3(0.5, 0.5, 1)) < 1e-9)
        let corner = solver.evaluate(u: 0, v: 0)
        #expect(simd_length(corner) < 1e-9)
    }

    @Test func uvBoxAndContinuity() {
        let solver = PlateSolver()
        solver.loadPinpoint(u: 0, v: 0, position: .zero)
        solver.loadPinpoint(u: 1, v: 0, position: SIMD3(1, 0, 0))
        solver.loadPinpoint(u: 0, v: 1, position: SIMD3(0, 1, 0))
        solver.loadPinpoint(u: 1, v: 1, position: SIMD3(1, 1, 0))
        solver.solve()

        let box = solver.uvBox
        #expect(box.umin == 0 && box.umax == 1 && box.vmin == 0 && box.vmax == 1)
        // Was `>= 0`. SolveTI(order 4) gives continuity 2 * 4 - 3 = 5.
        #expect(solver.continuity == 5)
    }

    @Test func derivativeConstraint() {
        let solver = PlateSolver()
        solver.loadPinpoint(u: 0, v: 0, position: .zero)
        solver.loadPinpoint(u: 1, v: 0, position: SIMD3(1, 0, 0))
        solver.loadPinpoint(u: 0, v: 1, position: SIMD3(0, 1, 0))
        solver.loadPinpoint(u: 1, v: 1, position: SIMD3(1, 1, 0))
        solver.loadDerivativeConstraint(
            u: 0.5, v: 0.5, value: SIMD3(0, 0, 2.0),
            derivativeOrderU: 1, derivativeOrderV: 0)
        #expect(solver.solve())
        // The solution takes the imposed dF/du = (0, 0, 2) at (0.5, 0.5).
        let d = solver.evaluateDerivative(u: 0.5, v: 0.5, derivativeOrderU: 1, derivativeOrderV: 0)
        #expect(simd_length(d - SIMD3(0, 0, 2)) < 1e-9)
    }

    @Test func evaluateDerivative() {
        let solver = PlateSolver()
        solver.loadPinpoint(u: 0, v: 0, position: .zero)
        solver.loadPinpoint(u: 1, v: 0, position: SIMD3(1, 0, 0))
        solver.loadPinpoint(u: 0, v: 1, position: SIMD3(0, 1, 0))
        solver.loadPinpoint(u: 0.5, v: 0.5, position: SIMD3(0.5, 0.5, 1.0))
        solver.solve()

        let deriv = solver.evaluateDerivative(
            u: 0.5, v: 0.5,
            derivativeOrderU: 1, derivativeOrderV: 0)
        // Was `deriv.x.isFinite`.
        #expect(simd_length(deriv - SIMD3(1.4761904524850298, 0.66666673383464681, 2.0000000928637642)) < 1e-9)
    }

    @Test func gtoCConstraint() {
        let solver = PlateSolver()
        solver.loadPinpoint(u: 0, v: 0, position: .zero)
        solver.loadPinpoint(u: 1, v: 0, position: SIMD3(1, 0, 0))
        solver.loadPinpoint(u: 0, v: 1, position: SIMD3(0, 1, 0))
        solver.loadPinpoint(u: 1, v: 1, position: SIMD3(1, 1, 0))
        solver.loadGtoC(
            u: 0.5, v: 0.5,
            sourceD1: (tangentU: SIMD3(1, 0, 0), tangentV: SIMD3(0, 1, 0)),
            targetD1: (tangentU: SIMD3(1, 0, 0.1), tangentV: SIMD3(0, 1, 0.1)))
        #expect(solver.solve())
        // The G-to-C constraint tilts the flat plate: dF/du and dF/dv each gain z = 0.1.
        let du = solver.evaluateDerivative(u: 0.5, v: 0.5, derivativeOrderU: 1, derivativeOrderV: 0)
        let dv = solver.evaluateDerivative(u: 0.5, v: 0.5, derivativeOrderU: 0, derivativeOrderV: 1)
        #expect(simd_length(du - SIMD3(0, 0, 0.1)) < 1e-9)
        #expect(simd_length(dv - SIMD3(0, 0, 0.1)) < 1e-9)
    }
}
