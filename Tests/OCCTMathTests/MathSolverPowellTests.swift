import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("MathSolver Powell v0.110")
struct MathSolverPowellTests {
    @Test func minimizeBowl() {
        // f(x,y) = (x-3)^2 + (y-4)^2
        if let result = MathSolver.minimizePowell(
            variables: 2,
            startPoint: [0.0, 0.0],
            function: { x in
                (x[0] - 3) * (x[0] - 3) + (x[1] - 4) * (x[1] - 4)
            }
        ) {
            #expect(abs(result.point[0] - 3.0) < 1e-3)
            #expect(abs(result.point[1] - 4.0) < 1e-3)
            #expect(abs(result.minimum) < 1e-3)
        }
    }
}

