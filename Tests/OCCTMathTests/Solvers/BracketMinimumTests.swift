import Foundation
import Testing

@testable import OCCTSwift

@Suite("BracketMinimum")
struct BracketMinimumTests {
    @Test func bracketQuadratic() throws {
        let r = try #require(MathSolver.bracketMinimum(a: -5.0, b: 2.0) { x in x * x })
        #expect(r.fb <= r.fa && r.fb <= r.fc)
    }
}
