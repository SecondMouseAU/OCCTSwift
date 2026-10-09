import Testing
import simd

@testable import OCCTSwift

@Suite("BRepFill AdvancedEvolved Tests")
struct BRepFillAdvancedEvolvedTests {
    @Test("Evolved solid from circular spine and rectangular profile")
    func circleSpineRectProfile() {
        let spine = Wire.circle(radius: 20)
        let profile = Wire.rectangle(width: 3, height: 3)
        if let spine, let profile {
            let result = Shape.advancedEvolved(spine: spine, profile: profile)
            #expect(result != nil)
            if let r = result {
                #expect(r.isValid)
            }
        }
    }
}
