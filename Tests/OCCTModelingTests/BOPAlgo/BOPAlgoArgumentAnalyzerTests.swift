import Testing
import simd

@testable import OCCTSwift

@Suite("BOPAlgo ArgumentAnalyzer")
struct BOPAlgoArgumentAnalyzerTests {
    @Test("Valid shapes for fuse")
    func validShapesForFuse() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30),
            let sphere = Shape.sphere(radius: 5)
        else {
            #expect(false, "Failed to create shapes")
            return
        }
        let valid = Shape.analyzeBoolean(box, sphere, operation: .fuse)
        #expect(valid)
    }

    @Test("Valid shapes for cut")
    func validShapesForCut() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30),
            let sphere = Shape.sphere(radius: 5)
        else {
            #expect(false, "Failed to create shapes")
            return
        }
        let valid = Shape.analyzeBoolean(box, sphere, operation: .cut)
        #expect(valid)
    }

    @Test("BooleanOperation raw values match OCCT BOPAlgo_Operation")
    func booleanOperationRawValuesMatchOCCT() {
        // Verify Swift enum raw values match OCCT's BOPAlgo_Operation enum
        // BOPAlgo_Operation: COMMON=0, FUSE=1, CUT=2, CUT21=3, SECTION=4
        #expect(Shape.BooleanOperation.common.rawValue == 0)
        #expect(Shape.BooleanOperation.fuse.rawValue == 1)
        #expect(Shape.BooleanOperation.cut.rawValue == 2)
        #expect(Shape.BooleanOperation.cut21.rawValue == 3)
        #expect(Shape.BooleanOperation.section.rawValue == 4)
    }
}
