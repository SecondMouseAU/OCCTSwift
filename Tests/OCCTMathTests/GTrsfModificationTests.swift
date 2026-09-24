import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepTools_GTrsfModification")
struct GTrsfModificationTests {
    // #766: this asserted only `result.isValid` inside three `if let`s, so a matrix the bridge
    // ignored (or a nil at any step) passed. It now requires every step and pins the volume the
    // X-by-2 scale gives: 10 x 10 x 10 becomes 20 x 10 x 10, 2000
    // (Scripts/repro/766-math-gtrsf-hyperbola-precision/transcript.txt).
    @Test("non-uniform scale")
    func nonUniformScale() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        // First convert to NURBS for non-uniform scaling
        let nurbs = try #require(box.convertedToNURBS())
        // Scale X by 2
        let result = try #require(
            Shape.gtrsfModification(
                nurbs,
                a11: 2, a12: 0, a13: 0, a14: 0,
                a21: 0, a22: 1, a23: 0, a24: 0,
                a31: 0, a32: 0, a33: 1, a34: 0))
        #expect(result.isValid)
        let volume = try #require(result.volume)
        #expect(abs(volume - 2000.0) < 1e-6)
    }
}
