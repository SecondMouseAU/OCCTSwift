import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("FunctionAllRoots")
struct FunctionAllRootsTests {
    @Test func sinRoots() {
        let roots = MathSolver.findAllRoots(in: 0.1...10.0) { x in
            (value: sin(x), derivative: cos(x))
        }
        #expect(roots.count >= 3)  // pi, 2pi, 3pi
        // A count held for roots in the wrong place. Pin them: math_FunctionRoots (this overload
        // reaches OCCTMathFunctionRoots) reports exactly pi, 2pi and 3pi on [0.1, 10] (kernel values from
        // Scripts/repro/766-math-drawing-eigen-solvers/transcript.txt).
        #expect(roots.count == 3)
        for (got, want) in zip(roots.sorted(), [Double.pi, 2 * .pi, 3 * .pi]) {
            #expect(abs(got - want) < 1e-8)
        }
    }
}

