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

    @Test func singleShapeValid() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            #expect(b.isBooleanValid())
        }
    }

    @Test func sphereValid() {
        let sphere = Shape.sphere(radius: 5)
        if let s = sphere {
            #expect(s.isBooleanValid())
        }
    }

    @Test func pairShapesValidForFuse() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        let sphere = Shape.sphere(radius: 5)
        if let b = box, let s = sphere {
            // operation 2 is BOPAlgo_CUT, not BOPAlgo_FUSE (#1540); named for historical
            // continuity, box/sphere are both dimensionally homogeneous solids so every
            // BOPAlgo_Operation's type-compatibility check passes on this pair regardless.
            #expect(b.isBooleanValidWith(s, operation: 2))
        }
    }

    @Test func pairShapesValidForCut() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        let sphere = Shape.sphere(radius: 5)
        if let b = box, let s = sphere {
            // operation 3 is BOPAlgo_CUT21, not BOPAlgo_CUT (#1540); see pairShapesValidForFuse
            // above for why box/sphere can't distinguish the real operation either way.
            #expect(b.isBooleanValidWith(s, operation: 3))
        }
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

    @Test func singleShapeNoSelfInterference() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            #expect(b.isBooleanValid(testSmallEdges: false, testSelfInterference: true))
        }
    }

    // #1297: isValidForBoolean/isValidForBoolean(with:) forward onto isBooleanValid()/
    // isBooleanValidWith(_:) at their implicit defaults (testSmallEdges: true,
    // testSelfInterference: true, operation: 5 = BOPAlgo_UNKNOWN, #1540). These two tests pin that
    // parity: if the forwarding default ever drifted from the fuller call's own default, either
    // test would catch it (proved by temporarily changing `isValidForBoolean`'s forwarded
    // defaults away from true/true and confirming both fail, then restoring).
    @Test("isValidForBoolean agrees with isBooleanValid at matching defaults")
    func singleShapeParityWithBooleanValid() {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let sphere = Shape.sphere(radius: 5)!
        #expect(box.isValidForBoolean == box.isBooleanValid())
        #expect(sphere.isValidForBoolean == sphere.isBooleanValid())
    }

    @Test("isValidForBoolean(with:) agrees with isBooleanValidWith at matching defaults")
    func pairParityWithBooleanValidWith() {
        let box = Shape.box(width: 10, height: 20, depth: 30)!
        let sphere = Shape.sphere(radius: 5)!
        #expect(box.isValidForBoolean(with: sphere) == box.isBooleanValidWith(sphere))
    }
}
