import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.52.0: BRepFill, LocOpe, Healing Utilities, 2D Curve Tools

@Suite("BRepFill Generator Tests")
struct BRepFillGeneratorTests {
    @Test("Ruled shell from two circular wires")
    func twoCircleWires() {
        let w1 = Wire.circle(radius: 10)
        let w2 = Wire.circle(radius: 5)
        if let w1, let w2 {
            let shell = Shape.ruledShell(from: [w1, w2])
            #expect(shell != nil)
            if let s = shell {
                #expect(s.isValid)
            }
        }
    }

    @Test("Ruled shell from two rectangular wires")
    func twoRectWires() {
        let w1 = Wire.rectangle(width: 10, height: 10)
        let w2 = Wire.rectangle(width: 15, height: 15)
        if let w1, let w2 {
            let shell = Shape.ruledShell(from: [w1, w2])
            #expect(shell != nil)
        }
    }

    @Test("Returns nil with fewer than 2 wires")
    func needsAtLeastTwo() {
        let w1 = Wire.rectangle(width: 10, height: 10)!
        let result = Shape.ruledShell(from: [w1])
        #expect(result == nil)
    }
}
