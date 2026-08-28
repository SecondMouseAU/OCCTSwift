import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GC_MakeTranslation")
struct ShapeTranslateByPointsTests {
    @Test("Translate box from point to point")
    func translateByPoints() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let translated = box.translated(from: SIMD3(0, 0, 0), to: SIMD3(20, 0, 0))
        #expect(translated != nil)
        if let t = translated {
            #expect(t.isValid)
            let bb = t.bounds!
            // Box centered at origin (-5..5) translated by (20,0,0) → (15..25)
            #expect(abs(bb.min.x - 15) < 0.5)
            #expect(abs(bb.max.x - 25) < 0.5)
        }
    }
}

