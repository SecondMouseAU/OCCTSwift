import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BracketedRoot")
struct BracketedRootTests {
    @Test func findRoot() {
        let result = MathSolver.bracketedRoot(in: 0...5) { x in
            (value: x * x - 4.0, derivative: 2.0 * x)
        }
        #expect(result != nil)
        if let r = result { #expect(abs(r.root - 2.0) < 1e-8) }
    }

    @Test func findSinRoot() {
        let result = MathSolver.bracketedRoot(in: 2...4) { x in
            (value: sin(x), derivative: cos(x))
        }
        #expect(result != nil)
        if let r = result { #expect(abs(r.root - .pi) < 1e-8) }
    }
}

