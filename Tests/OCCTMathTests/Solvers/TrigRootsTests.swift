import Foundation
import Testing

@testable import OCCTSwift

@Suite("math_TrigonometricFunctionRoots")
struct TrigRootsTests {
    @Test func sinZero() {
        // sin(x) = 0 on [0, 2pi]. Probed (Scripts/repro/766-math-transform-factory-trig): the
        // kernel reports exactly 0 and pi; 2pi is the same angle as 0 and is not repeated.
        let roots = TrigRoots.solve(d: 1, from: 0, to: 2 * .pi)
        #expect(roots.count == 2)
        #expect(zip(roots, [0.0, Double.pi]).allSatisfy { abs($0 - $1) < 1e-12 })
    }

    @Test func cosHalf() {
        // cos(x) = 0.5 => x = pi/3, 5pi/3
        let roots = TrigRoots.solve(c: 1, e: -0.5, from: 0, to: 2 * .pi)
        // Probed: exactly pi/3 and 5pi/3.
        #expect(roots.count == 2)
        #expect(zip(roots, [Double.pi / 3, 5 * Double.pi / 3]).allSatisfy { abs($0 - $1) < 1e-12 })
    }

    @Test func infiniteRoots() {
        // 0 = 0 => all reals are solutions
        let inf = TrigRoots.hasInfiniteRoots(a: 0, b: 0, c: 0, d: 0, e: 0, from: 0, to: 2 * .pi)
        #expect(inf)
        // Controls requiring the opposite answer (probed false): a nonzero cos term or a
        // nonzero constant leaves isolated or no roots, so the verdict is not a constant true.
        #expect(!TrigRoots.hasInfiniteRoots(a: 0, b: 0, c: 1, d: 0, e: 0, from: 0, to: 2 * .pi))
        #expect(!TrigRoots.hasInfiniteRoots(a: 0, b: 0, c: 0, d: 0, e: 1, from: 0, to: 2 * .pi))
    }
}
