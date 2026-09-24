import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.111.0 Tests

@Suite("MathSolver PSO v0.111")
struct MathSolverPSOTests {
    @Test func minimizeBowl() {
        // f(x,y) = (x-3)^2 + (y-4)^2, minimum at (3, 4) with value 0
        if let result = MathSolver.particleSwarm(
            variables: 2,
            lower: [-10.0, -10.0],
            upper: [10.0, 10.0],
            steps: [0.5, 0.5],
            particles: 64,
            iterations: 100,
            function: { x in
                (x[0] - 3) * (x[0] - 3) + (x[1] - 4) * (x[1] - 4)
            }
        ) {
            // math_PSO reaches F = 1.4e-7 at (3.00036, 4.00008) (probe); < 1.0 passed a point
            // 0.5 away in both coordinates.
            #expect(result.minimum < 1e-5)
            #expect(abs(result.point[0] - 3.0) < 0.01)
            #expect(abs(result.point[1] - 4.0) < 0.01)
        }
    }

    @Test func minimizeRosenbrock() {
        // Rosenbrock: f(x,y) = (1-x)^2 + 100*(y-x^2)^2, min at (1,1)
        if let result = MathSolver.particleSwarm(
            variables: 2,
            lower: [-5.0, -5.0],
            upper: [5.0, 5.0],
            steps: [0.1, 0.1],
            particles: 128,
            iterations: 200,
            function: { x in
                (1 - x[0]) * (1 - x[0]) + 100 * (x[1] - x[0] * x[0]) * (x[1] - x[0] * x[0])
            }
        ) {
            // PSO may not find exact minimum, but should get close
            // Probe: F = 3.6e-8 at (1.00002, 1.00003). < 10.0 passed almost anything.
            #expect(result.minimum < 1e-5)
            #expect(abs(result.point[0] - 1.0) < 0.01)
            #expect(abs(result.point[1] - 1.0) < 0.01)
        }
    }
}

