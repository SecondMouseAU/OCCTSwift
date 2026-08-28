import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.123.0, Shape queries")
struct ShapeQueriesV123Tests {

    @Test("Shape typeName")
    func shapTypeName() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let name = b.typeName
            #expect(name == "SOLID")
        }
    }

    @Test("Shape isNotEqual")
    func shapeIsNotEqual() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)
        let box2 = Shape.box(width: 20, height: 20, depth: 20)
        if let b1 = box1, let b2 = box2 {
            #expect(b1.isNotEqual(to: b2))
        }
    }

    @Test("Shape nullified")
    func shapeNullified() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let n = b.nullified
            // Nullified shape exists but is null
            #expect(n != nil)
        }
    }

    @Test("Shape emptied")
    func shapeEmptied() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let e = b.emptied
            #expect(e != nil)
        }
    }

    @Test("Shape moved")
    func shapeMoved() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let moved = b.moved(dx: 5, dy: 5, dz: 5)
            #expect(moved != nil)
            if let m = moved {
                #expect(m.isValid)
            }
        }
    }

    @Test("Shape orientationValue")
    func shapeOrientationValue() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let orient = b.orientationValue
            // 0=FORWARD for most shapes
            #expect(orient >= 0 && orient <= 3)
        }
    }

}
