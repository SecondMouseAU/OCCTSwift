import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("FunctionAllRoots")
struct FunctionAllRootsTests {
    @Test func sinRoots() {
        let roots = MathSolver.findAllRoots(in: 0.1...10.0) { x in
            (value: sin(x), derivative: cos(x))
        }
        #expect(roots.count >= 3)  // pi, 2pi, 3pi
    }
}

