import Foundation
import OCCTBridge
import Testing

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
    func shapeNullified() throws {
        let b = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(!b.isNull)
        let n = try #require(b.nullified)
        // A null shape, and not the receiver emptied or copied.
        #expect(n.isNull)
        #expect(n.nbChildren == 0)
        // The receiver keeps its content.
        #expect(!b.isNull)
        #expect(b.faces().count == 6)
        #expect(abs((b.volume ?? 0) - 1000) < 1e-6)
    }

    @Test("Shape emptied")
    func shapeEmptied() throws {
        let b = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let e = try #require(b.emptied)
        // EmptyCopied keeps the type and drops the content: a solid with no shell.
        #expect(!e.isNull)
        #expect(e.shapeType == .solid)
        #expect(e.nbChildren == 0)
        #expect(e.faces().isEmpty)
        // The receiver keeps its content.
        #expect(b.nbChildren == 1)
        #expect(b.faces().count == 6)
    }

    @Test("Shape moved")
    func shapeMoved() throws {
        let b = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let m = try #require(b.moved(dx: 5, dy: 6, dz: 7))
        #expect(m.isValid)
        // The box centred on the origin, shifted by (5, 6, 7).
        let box = try #require(m.boundingBox)
        #expect(vectorLength(box.min - SIMD3(0, 1, 2)) < 1e-5)
        #expect(vectorLength(box.max - SIMD3(10, 11, 12)) < 1e-5)
        #expect(abs((m.volume ?? 0) - 1000) < 1e-6)
        // The receiver stays where it was.
        let orig = try #require(b.boundingBox)
        #expect(vectorLength(orig.min - SIMD3(-5, -5, -5)) < 1e-5)
        #expect(vectorLength(orig.max - SIMD3(5, 5, 5)) < 1e-5)
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
