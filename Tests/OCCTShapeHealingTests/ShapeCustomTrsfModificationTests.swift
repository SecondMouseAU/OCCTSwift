import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-construct-custom-extend/probe.mm (transcript.txt beside it).
@Suite("ShapeCustom TrsfModification")
struct ShapeCustomTrsfModificationTests {
    @Test("Scale with tolerance handling")
    func trsfModificationScale() throws {
        // #766: was a 7000..9000 volume window inside two `if let`s. Kernel: exactly 8000.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let result = try #require(box.trsfModificationScale(2.0))
        #expect(result.isValid)
        #expect(abs((result.volume ?? 0) - 8000) < 1e-6)
    }
}
