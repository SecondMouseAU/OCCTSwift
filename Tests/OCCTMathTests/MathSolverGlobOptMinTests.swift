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
            // math_GlobOptMin lands on (3, 4) with F about 1e-29 (probe); a tolerance of 1.0
            // passed a point 0.3 away in both coordinates.
            #expect(result.minimum < 1e-12)
            #expect(abs(result.point[0] - 3.0) < 1e-6)
            #expect(abs(result.point[1] - 4.0) < 1e-6)
        }
    }

    @Test func globalMin1D() {
        if let result = MathSolver.globalMinimize(
            variables: 1,
            lower: [-5.0],
            upper: [5.0],
            function: { x in (x[0] - 2) * (x[0] - 2) + 1 }
        ) {
            // Probe: point 1.9999999976, F = 1. A tolerance of 0.5 passed F = 1.3.
            #expect(abs(result.minimum - 1.0) < 1e-9)
            #expect(abs(result.point[0] - 2.0) < 1e-6)
        }
    }
}

