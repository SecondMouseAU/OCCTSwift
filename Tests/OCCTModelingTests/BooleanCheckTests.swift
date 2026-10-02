import Testing
import simd

@testable import OCCTSwift

// #1297: merges the former BRepAlgoCheckTests, which tested `isBooleanValid`/`isBooleanValidWith`
// under the belief they reached a different bridge implementation than `isValidForBoolean`/
// `isValidForBoolean(with:)`. Both pairs reach the same `BRepAlgoAPI_Check`; see
// `Shape.isBooleanValid`'s doc comment (`Shape+Modeling.swift`).
@Suite("Boolean Pre-Validation")
struct BooleanCheckTests {
    @Test("Valid box passes boolean check")
    func validBoxCheck() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(box.isValidForBoolean)
    }

    @Test("Two boxes valid for boolean together")
    func twoBoxesValid() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.sphere(radius: 5)!
        #expect(box1.isValidForBoolean(with: box2))
    }

    @Test("Cylinder valid for boolean")
    func cylinderValid() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        #expect(cyl.isValidForBoolean)
    }

    // #766: singleShapeValid, sphereValid, pairShapesValidForFuse, pairShapesValidForCut and
    // singleShapeNoSelfInterference asserted inside `if let` on their fixtures, so a shape that
    // failed to build skipped the test and it passed; they take the fixtures through try #require.
    @Test func singleShapeValid() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        #expect(box.isBooleanValid())
    }

    @Test func sphereValid() throws {
        let sphere = try #require(Shape.sphere(radius: 5))
        #expect(sphere.isBooleanValid())
    }

    @Test func pairShapesValidForFuse() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let sphere = try #require(Shape.sphere(radius: 5))
        // operation 2 is BOPAlgo_CUT, not BOPAlgo_FUSE (#1540); named for historical
        // continuity, box/sphere are both dimensionally homogeneous solids so every
        // BOPAlgo_Operation's type-compatibility check passes on this pair regardless.
        #expect(box.isBooleanValidWith(sphere, operation: 2))
    }

    @Test func pairShapesValidForCut() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let sphere = try #require(Shape.sphere(radius: 5))
        // operation 3 is BOPAlgo_CUT21, not BOPAlgo_CUT (#1540); see pairShapesValidForFuse
        // above for why box/sphere can't distinguish the real operation either way.
        #expect(box.isBooleanValidWith(sphere, operation: 3))
    }

    // #1540: box/sphere above are both solids (dimension 3), so BOPAlgo_ArgumentAnalyzer's
    // type-compatibility check (BOPAlgo_ArgumentAnalyzer.cxx's TestTypes(), reached because
    // BRepAlgoAPI_Check::Perform sets ArgumentTypeMode() = true unconditionally) never trips
    // regardless of which real operation the `operation:` code actually selects, which is
    // exactly how the mapping bug went undetected. A solid (dimension 3) and a face (dimension
    // 2) DO distinguish real BOPAlgo_CUT from real BOPAlgo_CUT21, in opposite directions:
    //   CUT   (S1 - S2, real ordinal 2): faulty iff iDimMax[0] > iDimMin[1], i.e. 3 > 2 → bad.
    //   CUT21 (S2 - S1, real ordinal 3): faulty iff iDimMin[0] < iDimMax[1], i.e. 3 < 2 → fine.
    // So solid.isBooleanValidWith(face, operation: 2) must be false and operation: 3 must be
    // true; a mapping that had them swapped (or shifted by one, as the pre-fix doc table was)
    // would flip one or both. testSmallEdges/testSelfInterference are turned off so the result
    // reflects only the type-compatibility check this test targets.
    @Test("Solid vs. face: real CUT and CUT21 disagree (#1540)")
    func solidVsFaceCutAndCut21Disagree() {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let face = Shape.fromFace(box.faces()[0])!

        // Real BOPAlgo_CUT (ordinal 2): solid minus face is a dimension downgrade, bad type.
        #expect(
            !box.isBooleanValidWith(
                face, operation: 2, testSmallEdges: false, testSelfInterference: false))

        // Real BOPAlgo_CUT21 (ordinal 3): face minus solid, tool (solid) dimension >= object
        // (face) dimension, fine.
        #expect(
            box.isBooleanValidWith(
                face, operation: 3, testSmallEdges: false, testSelfInterference: false))
    }

    @Test func singleShapeNoSelfInterference() throws {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        #expect(box.isBooleanValid(testSmallEdges: false, testSelfInterference: true))
    }

    // #1297: isValidForBoolean/isValidForBoolean(with:) forward onto isBooleanValid()/
    // isBooleanValidWith(_:) at their implicit defaults (testSmallEdges: true,
    // testSelfInterference: true, operation: 5 = BOPAlgo_UNKNOWN, #1540). These two tests pin that
    // parity against the kernel's own BOPAlgo_ArgumentAnalyzer, which Shape.analyzeBoolean reaches
    // through a bridge function of its own (OCCTBOPAlgoAnalyzeArguments) with every mode on.
    //
    // #766: they used to compare the wrapper with the call it forwards to, which is one bridge
    // function called twice, on a box and a sphere for which every setting of the small-edge and
    // self-interference tests answers true. So the comment that used to stand here, that changing
    // the forwarded defaults away from true/true fails both tests, was false: neither could see
    // drift. Two more fixtures now give the verdict false, each to exactly one of the two tests
    // the wrapper turns on, so a forwarded default that drifts to false flips the wrapper's answer
    // against the analyzer's:
    //   thin box: 5e-7 deep, so its short edges trip the small-edge test and nothing else
    //   overlapping compound: two overlapping cubes in one compound, tripping only self-interference
    // The unit shapes are re-checked with one test turned off, which proves each fault belongs to
    // the test the fixture is named for.
    private struct CheckFixtures {
        let box: Shape
        let sphere: Shape
        let thinBox: Shape
        let overlappingCompound: Shape
    }

    private func checkFixtures() throws -> CheckFixtures {
        let box = try #require(Shape.box(width: 10, height: 20, depth: 30))
        let sphere = try #require(Shape.sphere(radius: 5))
        let thinBox = try #require(Shape.box(origin: .zero, width: 10, height: 10, depth: 5e-7))
        let cube1 = try #require(Shape.box(origin: .zero, width: 10, height: 10, depth: 10))
        let cube2 = try #require(
            Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10))
        let overlappingCompound = try #require(Shape.compound([cube1, cube2]))
        return CheckFixtures(
            box: box, sphere: sphere, thinBox: thinBox, overlappingCompound: overlappingCompound)
    }

    @Test("isValidForBoolean agrees with isBooleanValid at matching defaults")
    func singleShapeParityWithBooleanValid() throws {
        let f = try checkFixtures()
        let cases: [(name: String, shape: Shape, valid: Bool)] = [
            ("box", f.box, true),
            ("sphere", f.sphere, true),
            ("thin box", f.thinBox, false),
            ("overlapping compound", f.overlappingCompound, false),
        ]
        for c in cases {
            // The sphere is a valid second argument, so the analyzer's verdict is c.shape's own.
            let analyzer = Shape.analyzeBoolean(c.shape, f.sphere, operation: .fuse)
            #expect(analyzer == c.valid, "BOPAlgo_ArgumentAnalyzer on the \(c.name)")
            #expect(c.shape.isValidForBoolean == analyzer, "isValidForBoolean on the \(c.name)")
            #expect(
                c.shape.isValidForBoolean == c.shape.isBooleanValid(),
                "isBooleanValid() on the \(c.name)")
        }
        // Each fault belongs to one test: with it turned off the shape is valid.
        #expect(f.thinBox.isBooleanValid(testSmallEdges: false, testSelfInterference: true))
        #expect(
            f.overlappingCompound.isBooleanValid(testSmallEdges: true, testSelfInterference: false))
    }

    @Test("isValidForBoolean(with:) agrees with isBooleanValidWith at matching defaults")
    func pairParityWithBooleanValidWith() throws {
        let f = try checkFixtures()
        let cases: [(name: String, first: Shape, second: Shape, valid: Bool)] = [
            ("box and sphere", f.box, f.sphere, true),
            ("thin box and sphere", f.thinBox, f.sphere, false),
            ("box and overlapping compound", f.box, f.overlappingCompound, false),
            ("overlapping compound and sphere", f.overlappingCompound, f.sphere, false),
        ]
        for c in cases {
            let analyzer = Shape.analyzeBoolean(c.first, c.second, operation: .fuse)
            #expect(analyzer == c.valid, "BOPAlgo_ArgumentAnalyzer on the \(c.name)")
            #expect(
                c.first.isValidForBoolean(with: c.second) == analyzer,
                "isValidForBoolean(with:) on the \(c.name)")
            #expect(
                c.first.isValidForBoolean(with: c.second) == c.first.isBooleanValidWith(c.second),
                "isBooleanValidWith on the \(c.name)")
        }
        // Each fault belongs to one test: with it turned off the pair is valid.
        #expect(
            f.thinBox.isBooleanValidWith(
                f.sphere, testSmallEdges: false, testSelfInterference: true))
        #expect(
            f.box.isBooleanValidWith(
                f.overlappingCompound, testSmallEdges: true, testSelfInterference: false))
    }
}
