import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("NewtonRoot")
struct NewtonRootTests {
    @Test func findRoot() {
        let result = MathSolver.newtonRoot(guess: 3.0) { x in
            (value: x * x - 4.0, derivative: 2.0 * x)
        }
        #expect(result != nil)
        if let r = result { #expect(abs(r.root - 2.0) < 1e-8) }
    }
}

