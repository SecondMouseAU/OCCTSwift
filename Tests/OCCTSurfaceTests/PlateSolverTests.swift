import Testing
import simd

@testable import OCCTSwift

@Suite("Plate_Plate Solver")
struct PlateSolverTests {
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
        #expect(abs(center.z - 1.0) < 0.01)

        let corner = solver.evaluate(u: 0, v: 0)
        #expect(abs(corner.z) < 0.01)
    }

    @Test func uvBoxAndContinuity() {
        let solver = PlateSolver()
        solver.loadPinpoint(u: 0, v: 0, position: .zero)
        solver.loadPinpoint(u: 1, v: 0, position: SIMD3(1, 0, 0))
        solver.loadPinpoint(u: 0, v: 1, position: SIMD3(0, 1, 0))
        solver.loadPinpoint(u: 1, v: 1, position: SIMD3(1, 1, 0))
        solver.solve()

        let box = solver.uvBox
        #expect(box.umin <= 0.0)
        #expect(box.umax >= 1.0)
        #expect(solver.continuity >= 0)
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
        // Just verify it returns something reasonable
        #expect(deriv.x.isFinite)
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
    }
}
