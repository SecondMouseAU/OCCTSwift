import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("FRPR Minimizer")
struct FRPRTests {
    @Test func minimizeQuadratic() {
        let result = MathSolver.minimizeFRPR(startPoint: [10.0, 10.0]) { x in
            let fx = (x[0] - 1.0) * (x[0] - 1.0) + (x[1] - 2.0) * (x[1] - 2.0)
            let gx = [2.0 * (x[0] - 1.0), 2.0 * (x[1] - 2.0)]
            return (value: fx, gradient: gx)
        }
        #expect(result != nil)
        if let r = result {
            #expect(abs(r.location[0] - 1.0) < 0.01)
            #expect(abs(r.location[1] - 2.0) < 0.01)
        }
    }
}

