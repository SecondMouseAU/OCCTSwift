import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.111.1 Tests

@Suite("math_NewtonMinimum Tests")
struct NewtonMinimumTests {

    @Test func minimizeQuadratic() {
        // f(x,y) = (x-3)^2 + (y-4)^2, min at (3,4)
        let result = MathSolver.minimizeNewton(variables: 2, startPoint: [0, 0]) { x in
            let fx = (x[0] - 3) * (x[0] - 3) + (x[1] - 4) * (x[1] - 4)
            let gx = [2 * (x[0] - 3), 2 * (x[1] - 4)]
            let hx = [2.0, 0.0, 0.0, 2.0]  // identity Hessian
            return (fx, gx, hx)
        }
        #expect(result != nil)
        if let r = result {
            #expect(abs(r.point[0] - 3.0) < 1e-4)
            #expect(abs(r.point[1] - 4.0) < 1e-4)
            #expect(abs(r.minimum) < 1e-6)
        }
    }

    @Test func minimizeRosenbrock() {
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
        #expect(result != nil)
        if let r = result {
            #expect(abs(r.point[0] - 1.0) < 0.1)
            #expect(abs(r.point[1] - 1.0) < 0.1)
        }
    }
}

