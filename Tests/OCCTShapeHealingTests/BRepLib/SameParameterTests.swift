import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Same Parameter")
struct SameParameterTests {
    @Test("Same parameter on box")
    func sameParameterBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.sameParameter()
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
        }
    }

    @Test("Same parameter on cylinder")
    func sameParameterCylinder() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let result = cyl.sameParameter()
        #expect(result != nil)
    }

    @Test("Same parameter preserves volume")
    func sameParameterPreservesVolume() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.sameParameter()!
        #expect(abs(result.volume! - 1000.0) < 1.0)
    }
}
