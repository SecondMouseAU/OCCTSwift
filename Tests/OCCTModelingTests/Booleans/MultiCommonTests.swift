import Testing
import simd

@testable import OCCTSwift

@Suite("Multi-Tool Boolean Common")
struct MultiCommonTests {
    @Test("Common of three overlapping boxes")
    func commonThreeBoxes() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!.translated(by: SIMD3(3, 0, 0))!
        let box3 = Shape.box(width: 10, height: 10, depth: 10)!.translated(by: SIMD3(0, 3, 0))!
        let result = Shape.commonAll([box1, box2, box3])
        #expect(result != nil)
        if let r = result {
            #expect(r.volume! > 0)
            // Common should be smaller than any individual box
            #expect(r.volume! < 1000.0)
        }
    }

    @Test("Common with less than 2 shapes returns nil")
    func commonTooFew() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(Shape.commonAll([box]) == nil)
    }

    @Test("Common of non-overlapping shapes")
    func commonNoOverlap() {
        let box1 = Shape.box(width: 5, height: 5, depth: 5)!
        let box2 = Shape.box(width: 5, height: 5, depth: 5)!.translated(by: SIMD3(20, 20, 20))!
        let result = Shape.commonAll([box1, box2])
        // Non-overlapping common may return empty or nil. When it returns an empty compound there
        // is no closed shell in it, so `volume` is nil rather than 0 (#609). Force-unwrapping here
        // used to work only because the old volume path answered 0 for a shape with no volume at
        // all, which is the confusion this issue removed.
        if let r = result {
            #expect(r.volume == nil, "an empty common result encloses no volume")
            #expect(r.signedVolume == 0)
        }
    }
}
