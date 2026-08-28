import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("MathSolver GlobOptMin v0.111")
struct MathSolverGlobOptMinTests {
    @Test func globalMinBowl() {
        // f(x,y) = (x-3)^2 + (y-4)^2, global minimum at (3, 4) with value 0
        if let result = MathSolver.globalMinimize(
            variables: 2,
            lower: [-10.0, -10.0],
            upper: [10.0, 10.0],
            function: { x in
                (x[0] - 3) * (x[0] - 3) + (x[1] - 4) * (x[1] - 4)
            }
        ) {
            #expect(result.minimum < 1.0)
            #expect(abs(result.point[0] - 3.0) < 1.0)
            #expect(abs(result.point[1] - 4.0) < 1.0)
        }
    }

    @Test func globalMin1D() {
        if let result = MathSolver.globalMinimize(
            variables: 1,
            lower: [-5.0],
            upper: [5.0],
            function: { x in (x[0] - 2) * (x[0] - 2) + 1 }
        ) {
            #expect(abs(result.minimum - 1.0) < 0.5)
        }
    }
}

