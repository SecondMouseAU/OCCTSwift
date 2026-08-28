import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BracketMinimum")
struct BracketMinimumTests {
    @Test func bracketQuadratic() {
        let result = MathSolver.bracketMinimum(a: -5.0, b: 2.0) { x in x * x }
        #expect(result != nil)
        if let r = result { #expect(r.fb <= r.fa && r.fb <= r.fc) }
    }
}

