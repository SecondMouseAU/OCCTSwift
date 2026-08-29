import Testing
import simd

@testable import OCCTSwift

@Suite("BRepAlgoAPI_Check")
struct BRepAlgoCheckTests {
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
}