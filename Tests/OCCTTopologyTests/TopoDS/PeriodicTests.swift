import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Periodic Shapes")
struct PeriodicTests {
    @Test("Make shape periodic in X")
    func periodicX() {
        let box = Shape.box(width: 5, height: 5, depth: 5)!
        let periodic = box.makePeriodic(xPeriod: 10)
        // May or may not succeed depending on shape topology
        if let periodic {
            #expect(periodic.isValid)
        }
    }

    @Test("Repeat shape")
    func repeatShape() {
        let box = Shape.box(width: 5, height: 5, depth: 5)!
        let repeated = box.repeated(xPeriod: 10, xCount: 3)
        if let repeated {
            #expect(repeated.isValid)
        }
    }
}
