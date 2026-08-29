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
            // operation 2 = BOPAlgo_FUSE
            #expect(b.isBooleanValidWith(s, operation: 2))
        }
    }

    @Test func pairShapesValidForCut() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        let sphere = Shape.sphere(radius: 5)
        if let b = box, let s = sphere {
            // operation 3 = BOPAlgo_CUT
            #expect(b.isBooleanValidWith(s, operation: 3))
        }
    }

    @Test func singleShapeNoSelfInterference() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            #expect(b.isBooleanValid(testSmallEdges: false, testSelfInterference: true))
        }
    }

    // #1297: isValidForBoolean/isValidForBoolean(with:) forward onto isBooleanValid()/
    // isBooleanValidWith(_:) at their implicit defaults (testSmallEdges: true,
    // testSelfInterference: true, operation: 0 = BOPAlgo_UNKNOWN). These two tests pin that
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
