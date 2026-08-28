import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("MathSolver FunctionRoots v0.111")
struct MathSolverFunctionRootsTests {
    @Test func findAllRootsQuadratic() {
        // f(x) = x^2 - 4, roots at x = -2 and x = 2
        let roots = MathSolver.findAllRoots(in: -5.0...5.0, samples: 20) { x in
            (value: x * x - 4, derivative: 2 * x)
        }
        #expect(roots.count == 2)
        if roots.count >= 2 {
            let sorted = roots.sorted()
            #expect(abs(sorted[0] + 2.0) < 0.1)
            #expect(abs(sorted[1] - 2.0) < 0.1)
        }
    }

    @Test func findAllRootsSin() {
        // f(x) = sin(x), roots at 0, pi, 2*pi in [−0.5, 6.5]
        let roots = MathSolver.findAllRoots(in: -0.5...6.5, samples: 30) { x in
            (value: sin(x), derivative: cos(x))
        }
        #expect(roots.count >= 2)
    }
}

