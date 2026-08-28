import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("math_TrigonometricFunctionRoots")
struct TrigRootsTests {
    @Test func sinZero() {
        // sin(x) = 0 on [0, 2pi] => x = 0, pi, 2pi
        let roots = TrigRoots.solve(d: 1, from: 0, to: 2 * .pi)
        #expect(roots.count >= 2)
    }

    @Test func cosHalf() {
        // cos(x) = 0.5 => x = pi/3, 5pi/3
        let roots = TrigRoots.solve(c: 1, e: -0.5, from: 0, to: 2 * .pi)
        #expect(roots.count >= 1)
    }

    @Test func infiniteRoots() {
        // 0 = 0 => all reals are solutions
        let inf = TrigRoots.hasInfiniteRoots(a: 0, b: 0, c: 0, d: 0, e: 0, from: 0, to: 2 * .pi)
        #expect(inf)
    }
}

