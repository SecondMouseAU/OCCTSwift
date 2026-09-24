import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("MathSolver BrentMinimum v0.110")
struct MathSolverBrentTests {
    @Test func minimizeQuadratic() {
        // f(x) = x^2 - 4, minimum at x=0 with f=-4
        if let result = MathSolver.minimizeBrent(ax: -1.0, bx: 1.0, cx: 5.0) { x in
            (value: x * x - 4, derivative: 2 * x)
        } {
            // math_BrentMinimum at tolerance 1e-8 lands within 1e-8 of 0 (probe: -1e-8).
            #expect(abs(result.location) < 1e-6)
            #expect(abs(result.minimum + 4.0) < 1e-9)
        }
    }

    @Test func minimizeSine() {
        // f(x) = sin(x), minimum near x = 3*pi/2 ~ 4.712 with f=-1
        // Bracket: [3, 5, 6]
        if let result = MathSolver.minimizeBrent(ax: 3.0, bx: 5.0, cx: 6.0) { x in
            (value: sin(x), derivative: cos(x))
        } {
            // Probe: location 4.7123889804110037, 3e-11 from 3*pi/2; minimum -1.
            #expect(abs(result.location - 3 * Double.pi / 2) < 1e-6)
            #expect(abs(result.minimum + 1.0) < 1e-9)
        }
    }
}

