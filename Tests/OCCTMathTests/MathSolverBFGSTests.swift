import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("MathSolver BFGS v0.110")
struct MathSolverBFGSTests {
    @Test func minimizeQuadratic() {
        // f(x,y) = (x-3)^2 + (y-4)^2, minimum at (3, 4)
        if let result = MathSolver.minimize(
            variables: 2,
            startPoint: [0.0, 0.0],
            function: { x in
                let val = (x[0] - 3) * (x[0] - 3) + (x[1] - 4) * (x[1] - 4)
                let grad = [2 * (x[0] - 3), 2 * (x[1] - 4)]
                return (value: val, gradient: grad)
            }
        ) {
            #expect(abs(result.point[0] - 3.0) < 1e-4)
            #expect(abs(result.point[1] - 4.0) < 1e-4)
            #expect(abs(result.minimum) < 1e-4)
        }
    }

    @Test func minimizeRosenbrock() {
        // Rosenbrock: f(x,y) = (1-x)^2 + 100*(y-x^2)^2
        // Minimum at (1, 1) with f=0
        if let result = MathSolver.minimize(
            variables: 2,
            startPoint: [0.0, 0.0],
            tolerance: 1e-10,
            maxIterations: 1000,
            function: { x in
                let val =
                    (1 - x[0]) * (1 - x[0]) + 100 * (x[1] - x[0] * x[0]) * (x[1] - x[0] * x[0])
                let gx = -2 * (1 - x[0]) - 400 * x[0] * (x[1] - x[0] * x[0])
                let gy = 200 * (x[1] - x[0] * x[0])
                return (value: val, gradient: [gx, gy])
            }
        ) {
            #expect(abs(result.point[0] - 1.0) < 0.1)
            #expect(abs(result.point[1] - 1.0) < 0.1)
        }
    }
}

