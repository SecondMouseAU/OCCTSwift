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
            #expect(result.minimum < 1.0)
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
            #expect(result.minimum < 10.0)
        }
    }
}

