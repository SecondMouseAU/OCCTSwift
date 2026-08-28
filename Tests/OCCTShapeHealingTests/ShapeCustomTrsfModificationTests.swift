import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeCustom TrsfModification")
struct ShapeCustomTrsfModificationTests {
    @Test("Scale with tolerance handling")
    func trsfModificationScale() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let result = box.trsfModificationScale(2.0)
        #expect(result != nil)
        if let result = result {
            #expect(result.isValid)
            let props = result.properties()
            if let props = props {
                // Scaled 2x → volume should be 8x (2^3)
                #expect(props.volume > 7000 && props.volume < 9000)
            }
        }
    }
}
