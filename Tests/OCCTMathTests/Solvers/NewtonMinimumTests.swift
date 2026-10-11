import Foundation
import Testing

@testable import OCCTSwift

// MARK: - v0.111.1 Tests

@Suite("math_NewtonMinimum Tests")
struct NewtonMinimumTests {

    @Test func minimizeQuadratic() throws {
        // f(x,y) = (x-3)^2 + (y-4)^2, min at (3,4)
        let result = MathSolver.minimizeNewton(variables: 2, startPoint: [0, 0]) { x in
            let fx = (x[0] - 3) * (x[0] - 3) + (x[1] - 4) * (x[1] - 4)
            let gx = [2 * (x[0] - 3), 2 * (x[1] - 4)]
            let hx = [2.0, 0.0, 0.0, 2.0]  // identity Hessian
            return (fx, gx, hx)
        }
        let r = try #require(result)
        try #require(r.point.count == 2)
        // Probed: a quadratic is solved in one Newton step, to exactly (3, 4) and 0.
        #expect(abs(r.point[0] - 3.0) < 1e-9)
        #expect(abs(r.point[1] - 4.0) < 1e-9)
        #expect(abs(r.minimum) < 1e-9)
    }

    @Test func minimizeRosenbrock() throws {
        // f(x,y) = (1-x)^2 + 100*(y-x^2)^2, min at (1,1)
        let result = MathSolver.minimizeNewton(
            variables: 2, startPoint: [0, 0], maxIterations: 100
        ) { x in
            let fx = (1 - x[0]) * (1 - x[0]) + 100 * (x[1] - x[0] * x[0]) * (x[1] - x[0] * x[0])
            let gx0 = -2 * (1 - x[0]) + 100 * 2 * (x[1] - x[0] * x[0]) * (-2 * x[0])
            let gx1 = 100 * 2 * (x[1] - x[0] * x[0])
            let h00 = 2 + 100 * (12 * x[0] * x[0] - 4 * x[1])
            let h01 = -400 * x[0]
            let h10 = -400 * x[0]
            let h11 = 200.0
            return (fx, [gx0, gx1], [h00, h01, h10, h11])
        }
        let r = try #require(result)
        try #require(r.point.count == 2)
        // Probed: the pinned kernel converges to (1, 1) with a minimum of 0 to the last printed
        // digit. The old window (0.1 on a minimum at 1) swallowed a one-iteration stall.
        #expect(abs(r.point[0] - 1.0) < 1e-6)
        #expect(abs(r.point[1] - 1.0) < 1e-6)
        #expect(abs(r.minimum) < 1e-9)
    }
}
