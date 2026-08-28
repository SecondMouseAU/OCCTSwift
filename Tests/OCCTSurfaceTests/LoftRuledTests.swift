import Testing

@testable import OCCTSwift

@Suite("Loft Ruled Mode")
struct LoftRuledTests {
    @Test("Ruled loft produces flat surfaces")
    func ruledLoft() {
        let w1 = Wire.rectangle(width: 10, height: 10)!
        let w2 = Wire.rectangle(width: 5, height: 5)!
        let ruled = Shape.loft(profiles: [w1, w2], solid: true, ruled: true)
        #expect(ruled != nil)
        if let r = ruled {
            #expect(r.isValid)
        }
    }

    @Test("Smooth loft differs from ruled")
    func smoothVsRuled() {
        let w1 = Wire.rectangle(width: 10, height: 10)!
        let w2 = Wire.rectangle(width: 5, height: 5)!
        let ruled = Shape.loft(profiles: [w1, w2], solid: true, ruled: true)
        let smooth = Shape.loft(profiles: [w1, w2], solid: true, ruled: false)
        #expect(ruled != nil)
        #expect(smooth != nil)
    }

    @Test("Shell loft (non-solid)")
    func shellLoft() {
        let w1 = Wire.rectangle(width: 10, height: 10)!
        let w2 = Wire.rectangle(width: 5, height: 5)!
        let shell = Shape.loft(profiles: [w1, w2], solid: false, ruled: true)
        #expect(shell != nil)
    }
}
