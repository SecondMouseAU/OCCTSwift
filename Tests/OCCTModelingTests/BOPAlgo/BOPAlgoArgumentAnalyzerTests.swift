import Testing

@testable import OCCTSwift

@Suite("BOPAlgo ArgumentAnalyzer")
struct BOPAlgoArgumentAnalyzerTests {
    // #3332: both tests asserted `analyzeBoolean(box, sphere)` is true. Every other argument pair
    // also answers true for a box and a sphere (two solids, dimension 3, nothing small, nothing
    // self-interfering), so a function that returned `true` unconditionally passed them. Each
    // now carries the verdicts the analyzer gives where it must say false, measured on the
    // pinned kernel and explained by BOPAlgo_ArgumentAnalyzer's own checks:
    //   thin box        a 5e-7 deep solid trips the small-edge test, whatever the operation
    //   overlap compound  two overlapping cubes in one compound trip the self-interference test
    //   solid + face    FUSE needs equal dimensions (3 against 2 is refused); CUT refuses a
    //                   higher-dimension object over a lower-dimension tool (3 > 2) and CUT21,
    //                   its mirror, accepts it. See also BooleanCheckTests' (#1540) cases.
    @Test("Valid shapes for fuse")
    func validShapesForFuse() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let sphere = try #require(Shape.sphere(radius: 5))
        let thin = try #require(Shape.box(origin: .zero, width: 10, height: 10, depth: 5e-7))
        let cubeA = try #require(Shape.box(origin: .zero, width: 10, height: 10, depth: 10))
        let cubeB = try #require(
            Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10))
        let overlap = try #require(Shape.compound([cubeA, cubeB]))
        let firstFace = try #require(box.faces().first)
        let face = try #require(Shape.fromFace(firstFace))

        #expect(Shape.analyzeBoolean(box, sphere, operation: .fuse))
        #expect(Shape.analyzeBoolean(sphere, box, operation: .fuse))
        #expect(!Shape.analyzeBoolean(thin, sphere, operation: .fuse))
        #expect(!Shape.analyzeBoolean(overlap, sphere, operation: .fuse))
        #expect(!Shape.analyzeBoolean(box, face, operation: .fuse))
        #expect(!Shape.analyzeBoolean(face, box, operation: .fuse))
    }

    @Test("Valid shapes for cut")
    func validShapesForCut() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let sphere = try #require(Shape.sphere(radius: 5))
        let thin = try #require(Shape.box(origin: .zero, width: 10, height: 10, depth: 5e-7))
        let firstFace = try #require(box.faces().first)
        let face = try #require(Shape.fromFace(firstFace))

        #expect(Shape.analyzeBoolean(box, sphere, operation: .cut))
        #expect(Shape.analyzeBoolean(box, sphere, operation: .cut21))
        #expect(!Shape.analyzeBoolean(sphere, thin, operation: .cut))
        // box - face is a dimension downgrade (refused); face - box is fine, and CUT21 is the
        // mirror of CUT, so each pair's two operations answer in opposite directions.
        #expect(!Shape.analyzeBoolean(box, face, operation: .cut))
        #expect(Shape.analyzeBoolean(box, face, operation: .cut21))
        #expect(Shape.analyzeBoolean(face, box, operation: .cut))
        #expect(!Shape.analyzeBoolean(face, box, operation: .cut21))
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
