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
            // math_FunctionRoots returns -2 and 2 exactly (probe); 0.1 passed a root off by 0.09.
            #expect(abs(sorted[0] + 2.0) < 1e-6)
            #expect(abs(sorted[1] - 2.0) < 1e-6)
        }
    }

    @Test func findAllRootsSin() {
        // f(x) = sin(x), roots at 0, pi, 2*pi in [−0.5, 6.5]
        let roots = MathSolver.findAllRoots(in: -0.5...6.5, samples: 30) { x in
            (value: sin(x), derivative: cos(x))
        }
        #expect(roots.count >= 2)
        // A count says nothing about where the roots are. The kernel finds exactly the three
        // roots in range, 0, pi and 2*pi (Scripts/repro/766-math-functionroots-gaussintegrate).
        #expect(roots.count == 3)
        for (got, want) in zip(roots.sorted(), [0.0, Double.pi, 2 * Double.pi]) {
            #expect(abs(got - want) < 1e-6)
        }
    }
}

